extends Control

@onready var draw_button = $DrawButton
@onready var flip_button = $FlipButton
@onready var stay_button = $StayButton
@onready var deck_count_label = $DeckCountLabel

@onready var hand_container = $HumanPlayer/HandContainer
@onready var round_score_label = $HumanPlayer/RoundScoreLabel
@onready var bonus_score_label = $HumanPlayer/BonusScoreLabel
@onready var total_score_label = $HumanPlayer/TotalScoreLabel
@onready var status_label = $HumanPlayer/StatusLabel
@onready var bonus_label = $HumanPlayer/BonusLabel

@onready var ai_hand_container = $AIPlayer/HandContainer
@onready var ai_round_score_label = $AIPlayer/RoundScoreLabel
@onready var ai_bonus_score_label = $AIPlayer/BonusScoreLabel
@onready var ai_total_score_label = $AIPlayer/TotalScoreLabel
@onready var ai_status_label = $AIPlayer/StatusLabel
@onready var ai_bonus_label = $AIPlayer/BonusLabel

var AI = preload("res://Scripts/AI.gd").new()
var card_scene = preload("res://Scenes/Card.tscn")
var back_image = preload("res://Assets/Back.png")
var card_deck_data = [
	{"value": 0, "texture": preload("res://Assets/Card 0.png"), "count": 1},
	{"value": 1, "texture": preload("res://Assets/Card 1.png"), "count": 1},
	{"value": 2, "texture": preload("res://Assets/Card 2.png"), "count": 2},
	{"value": 3, "texture": preload("res://Assets/Card 3.png"), "count": 3},
	{"value": 4, "texture": preload("res://Assets/Card 4.png"), "count": 4},
	{"value": 5, "texture": preload("res://Assets/Card 5.png"), "count": 5},
	{"value": 6, "texture": preload("res://Assets/Card 6.png"), "count": 6},
	{"value": 7, "texture": preload("res://Assets/Card 7.png"), "count": 7},
	{"value": 8, "texture": preload("res://Assets/Card 8.png"), "count": 8},
	{"value": 9, "texture": preload("res://Assets/Card 9.png"), "count": 9},
	{"value": 10, "texture": preload("res://Assets/Card 10.png"), "count": 10}
]

var deck = []
var hand_cards = []
var flipped_values = []
var bonus_messages = []
var flip_index = 0
var total_flipped_value = 0
var bonus_score = 0
var total_score = 0

var ai_hand_cards = []
var ai_flipped_values = []
var ai_flip_index = 0
var ai_total_flipped_value = 0
var ai_bonus_score = 0
var ai_total_score = 0
var ai_turn = false
var ai_thinking_timer = Timer.new()

# State flags for round logic
var human_busted_this_round = false
var human_stayed_this_round = false
var ai_busted_this_round = false
var ai_stayed_this_round = false # New flag

func _ready():
	add_child(ai_thinking_timer)
	ai_thinking_timer.wait_time = 1.0 
	ai_thinking_timer.one_shot = true
	if not ai_thinking_timer.timeout.is_connected(_on_ai_decision_timeout):
		ai_thinking_timer.timeout.connect(_on_ai_decision_timeout)

	flip_button.visible = false
	stay_button.visible = false
	deck = build_deck()
	deck.shuffle()
	update_deck_label()
	# Consider calling _on_draw_pressed() here or via a "Start Game" button
	# to initialize the first round automatically.

func update_deck_label():
	deck_count_label.text = "Deck Left: %d" % deck.size()

func update_round_start_labels():
	bonus_messages.clear()
	status_label.text = ""
	bonus_label.text = ""
	round_score_label.text = "Round Score: 0"
	bonus_score_label.text = ""
	
	ai_status_label.text = "Waiting..."
	ai_bonus_label.text = ""
	ai_round_score_label.text = "AI Round Score: 0"
	ai_bonus_score_label.text = ""

func build_deck():
	var new_deck = []
	for card_info in card_deck_data:
		for i in range(card_info["count"]):
			new_deck.append(card_info)
	return new_deck

func _on_draw_pressed():
	update_round_start_labels()
	
	for card_node in hand_cards:
		if not card_node.is_flipped:
			deck.append({"value": card_node.card_value, "texture": card_node.front_texture})
	for card_node in ai_hand_cards:
		if not card_node.is_flipped:
			deck.append({"value": card_node.card_value, "texture": card_node.front_texture})
	deck.shuffle()

	for child in hand_container.get_children(): child.queue_free()
	for child in ai_hand_container.get_children(): child.queue_free()
		
	hand_cards.clear(); flipped_values.clear(); flip_index = 0; total_flipped_value = 0; bonus_score = 0
	ai_hand_cards.clear(); ai_flipped_values.clear(); ai_flip_index = 0; ai_total_flipped_value = 0; ai_bonus_score = 0
	
	human_busted_this_round = false
	human_stayed_this_round = false
	ai_busted_this_round = false
	ai_stayed_this_round = false # Reset new flag
	ai_turn = false

	if deck.is_empty():
		deck = build_deck()
		deck.shuffle()
		print("Deck was empty. Rebuilding full deck...")

	for _i in range(min(5, deck.size())):
		if deck.is_empty(): break
		var card_info = deck.pop_back()
		var card = card_scene.instantiate()
		card.front_texture = card_info["texture"]; card.back_texture = back_image; card.card_value = card_info["value"]
		hand_container.add_child(card); hand_cards.append(card)
		
	for _i in range(min(5, deck.size())):
		if deck.is_empty(): break
		var card_info = deck.pop_back()
		var card = card_scene.instantiate()
		card.front_texture = card_info["texture"]; card.back_texture = back_image; card.card_value = card_info["value"]
		ai_hand_container.add_child(card); ai_hand_cards.append(card)

	draw_button.visible = false
	if hand_cards.size() > 0:
		flip_button.visible = true; flip_button.disabled = false
		stay_button.visible = true; stay_button.disabled = true
		status_label.text = "Your turn. Flip a card."
	else:
		flip_button.visible = false; stay_button.visible = false
		status_label.text = "You have no cards."
		if ai_hand_cards.is_empty():
			status_label.text += " AI has no cards. Press Draw."
			draw_button.visible = true
		else:
			status_label.text += " AI plays."
			call_deferred("start_ai_turn")

	if ai_hand_cards.is_empty():
		ai_status_label.text = "AI has no cards this round."
		
	update_deck_label()

# --- Human Player Actions ---
func _on_flip_pressed():
	if flip_index >= hand_cards.size(): return

	draw_button.visible = false
	var card = hand_cards[flip_index]
	card.flip()

	if card.card_value in flipped_values: # Human Busts
		status_label.text = "You Busted! 💥 Round Score: 0"
		total_flipped_value = 0 # Score is 0 if busted
		round_score_label.text = "Round Score: 0"
		bonus_label.text = ""; bonus_score_label.text = "" # No bonus if busted
		
		flip_button.disabled = true; stay_button.disabled = true
		human_busted_this_round = true
		_calculate_human_final_round_score() # Update total score (adds 0 for round)
		if _check_human_win(): return # Check win after score update
		call_deferred("start_ai_turn")
	else: # Human flips successfully
		flipped_values.append(card.card_value)
		total_flipped_value += card.card_value
		round_score_label.text = "Round Score: %d" % total_flipped_value
		flip_index += 1

		if flip_index == 1 and hand_cards.size() > 0:
			stay_button.disabled = false
		
		status_label.text = "Flipped %d. Score: %d." % [card.card_value, total_flipped_value]

		var human_done_this_round = false
		if flip_index == hand_cards.size(): # Human flipped all cards
			human_done_this_round = true
			_calculate_human_final_round_score()
			flip_button.disabled = true; stay_button.disabled = true
			if _check_human_win(): return
		
		call_deferred("start_ai_turn") # AI's turn after human's single action
	update_deck_label()

func _on_stay_pressed():
	flip_button.disabled = true; stay_button.disabled = true
	human_stayed_this_round = true
	_calculate_human_final_round_score()
	status_label.text = "You stayed. Final Round Score: %d" % total_flipped_value
	if _check_human_win(): return
	start_ai_turn() # Use direct call if it's safe, or call_deferred

func _calculate_human_final_round_score():
	bonus_messages.clear(); bonus_score = 0
	if not human_busted_this_round: # Only calculate bonus if not busted
		if (human_stayed_this_round or flip_index == 5) and flip_index == 5 : # 5 unique cards if stayed or flipped all 5
			bonus_score += 15
			bonus_messages.append("5 Unique Cards! +15")
		if total_flipped_value == 21:
			bonus_score += 10
			bonus_messages.append("Perfect 21! +10")
	else: # Busted
		total_flipped_value = 0 # Ensure round score is 0 for total calculation
		round_score_label.text = "Round Score: 0"

	if bonus_messages.size() > 0 and not human_busted_this_round:
		bonus_label.text = "\n".join(bonus_messages)
		bonus_score_label.text = "+%d" % bonus_score
	else:
		bonus_label.text = ""; bonus_score_label.text = ""
	
	if not human_busted_this_round:
		total_score += total_flipped_value + bonus_score
	# If busted, total_score doesn't change for this round (total_flipped_value = 0, bonus_score = 0)
	total_score_label.text = "Total Score: %d" % total_score

func _check_human_win() -> bool:
	if total_score >= 200:
		status_label.text = "🎉 You Won!"
		_end_game_buttons()
		return true
	return false

# --- AI Turn Logic ---
func start_ai_turn():
	# Check if AI's participation in the round is already over
	var ai_round_participation_is_over = ai_busted_this_round or \
										ai_stayed_this_round or \
										(ai_flip_index >= ai_hand_cards.size() and ai_hand_cards.size() > 0)

	if ai_round_participation_is_over:
		# AI cannot make any more moves this round. Pass control appropriately.
		_determine_next_player_or_end_round()
		return

	if ai_hand_cards.is_empty(): # AI has no cards to play this round
		ai_stayed_this_round = true # Treat as stayed
		ai_status_label.text = "AI has no cards this turn."
		_calculate_ai_final_round_score() # Calculate score (will be 0)
		if _check_ai_win(): return
		_determine_next_player_or_end_round()
		return

	ai_turn = true
	flip_button.disabled = true
	stay_button.disabled = true
	ai_status_label.text = "AI is thinking..."
	ai_thinking_timer.start()

func _on_ai_decision_timeout():
	ai_thinking_timer.stop()
	if not ai_turn: return

	var ai_current_score = ai_total_flipped_value
	if ai_busted_this_round: ai_current_score = 0

	var ai_state = {
		"flipped_values": ai_flipped_values.duplicate(), "current_score": ai_current_score,
		"flipped_count": ai_flip_index, "busted": ai_busted_this_round,
		"deck_size": deck.size(), "deck": deck.duplicate(true), "action": ""
	}
	
	var human_current_score = total_flipped_value
	if human_busted_this_round: human_current_score = 0

	var human_state = {
		"flipped_values": flipped_values.duplicate(), "current_score": human_current_score,
		"flipped_count": flip_index, "busted": human_busted_this_round,
		"deck_size": deck.size(), "action": ""
	}
	
	var decision = AI.make_decision(ai_state, human_state, deck.duplicate(true))
	
	if decision == "flip" and ai_flip_index < ai_hand_cards.size():
		_process_ai_flip_decision()
	else: # Stay or invalid flip attempt
		_process_ai_stay_decision()

func _process_ai_flip_decision():
	if ai_flip_index >= ai_hand_cards.size(): # Should not happen if decision was "flip"
		_process_ai_stay_decision() 
		return

	var card = ai_hand_cards[ai_flip_index]
	card.flip()

	if card.card_value in ai_flipped_values: # AI Busts
		ai_busted_this_round = true
		ai_status_label.text = "AI Busted! 💥 Round Score: 0"
		ai_total_flipped_value = 0 # Score is 0
		ai_round_score_label.text = "AI Round Score: 0"
		_calculate_ai_final_round_score() # AI's round participation is over
		if _check_ai_win(): return
	else: # AI flips successfully
		ai_flipped_values.append(card.card_value)
		ai_total_flipped_value += card.card_value
		ai_round_score_label.text = "AI Round Score: %d" % ai_total_flipped_value
		ai_flip_index += 1
		ai_status_label.text = "AI flipped %d. Score: %d" % [card.card_value, ai_total_flipped_value]

		if ai_flip_index >= ai_hand_cards.size(): # AI flipped all cards
			# This is an implicit stay; AI's round participation is over.
			ai_status_label.text = "AI flipped all cards. Final Score: %d" % ai_total_flipped_value
			_calculate_ai_final_round_score()
			if _check_ai_win(): return
		# Else: AI flipped, has more cards, but its single action for this turn is done.
		# Do NOT calculate final score here. Do NOT restart timer.
	
	update_deck_label()
	_determine_next_player_or_end_round() # AI's single action is complete

func _process_ai_stay_decision():
	ai_stayed_this_round = true # AI chooses to stay
	ai_status_label.text = "AI Stays! Final Round Score: %d" % ai_total_flipped_value
	_calculate_ai_final_round_score() # AI's round participation is over
	if _check_ai_win(): return
	_determine_next_player_or_end_round() # AI's single action is complete

func _calculate_ai_final_round_score():
	var current_ai_bonus = 0
	var current_ai_bonus_messages = []

	if not ai_busted_this_round: # Only calculate bonus if not busted
		if (ai_stayed_this_round or ai_flip_index == 5) and ai_flip_index == 5: # 5 unique if stayed or flipped all 5
			current_ai_bonus += 15
			current_ai_bonus_messages.append("5 Unique Cards! +15")
		if ai_total_flipped_value == 21:
			current_ai_bonus += 10
			current_ai_bonus_messages.append("Perfect 21! +10")
	else: # Busted
		ai_total_flipped_value = 0 # Ensure round score is 0
		ai_round_score_label.text = "AI Round Score: 0"


	if current_ai_bonus_messages.size() > 0 and not ai_busted_this_round:
		ai_bonus_label.text = "\n".join(current_ai_bonus_messages)
		ai_bonus_score_label.text = "+%d" % current_ai_bonus
	else:
		ai_bonus_label.text = ""; ai_bonus_score_label.text = ""
	
	ai_bonus_score = current_ai_bonus # Store this round's bonus
	if not ai_busted_this_round:
		ai_total_score += ai_total_flipped_value + ai_bonus_score
	ai_total_score_label.text = "AI Total Score: %d" % ai_total_score

func _check_ai_win() -> bool:
	if ai_total_score >= 200:
		ai_status_label.text = "🤖 AI Won!"
		_end_game_buttons()
		return true
	return false

# --- Turn Management & Round End ---
func _determine_next_player_or_end_round():
	ai_turn = false # Current AI action is complete

	var human_can_play_this_round = not (human_busted_this_round or \
										human_stayed_this_round or \
										(flip_index >= hand_cards.size() and hand_cards.size() > 0))

	var ai_can_play_this_round = not (ai_busted_this_round or \
									ai_stayed_this_round or \
									(ai_flip_index >= ai_hand_cards.size() and ai_hand_cards.size() > 0))

	if _check_human_win() or _check_ai_win(): # If game already won, no more turns
		return

	if human_can_play_this_round:
		status_label.text = "Your turn."
		if not ai_status_label.text.contains("Won!") and not ai_status_label.text.contains("Busted!") and not ai_stayed_this_round and not (ai_flip_index >= ai_hand_cards.size() and ai_hand_cards.size() > 0):
			# Clear AI status if it just took a normal flip and didn't end its round
			if not ai_status_label.text.contains("AI flipped"): # Don't overwrite "AI flipped X" immediately
				ai_status_label.text = "AI acted. Waiting for Human."


		flip_button.disabled = false
		stay_button.disabled = (flip_index == 0) # Enable stay only if human has flipped at least once
		draw_button.visible = false
	elif ai_can_play_this_round: # Human is done, but AI can still take more single-action turns
		status_label.text = "Human player finished actions for round."
		call_deferred("start_ai_turn") # Let AI take its next turn
	else: # Both players are done with actions for this round
		status_label.text += "\nRound Complete! Press Draw."
		if not ai_status_label.text.contains("Won!") and not ai_status_label.text.contains("Busted!") and not ai_stayed_this_round :
			ai_status_label.text = "AI finished round." # Or show final AI round score
		draw_button.visible = true
		flip_button.disabled = true; stay_button.disabled = true
	
	update_deck_label()

func _end_game_buttons():
	draw_button.visible = false
	flip_button.disabled = true 
	stay_button.disabled = true  
