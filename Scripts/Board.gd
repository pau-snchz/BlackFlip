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

func _ready():
	flip_button.visible = false
	stay_button.visible = false
	deck = build_deck()
	deck.shuffle()
	update_deck_label()
	
	# Initialize AI thinking timer
	if not ai_thinking_timer:
		ai_thinking_timer = Timer.new()
		add_child(ai_thinking_timer)
		ai_thinking_timer.wait_time = 1.0
		ai_thinking_timer.one_shot = true

		# Connect the signal (no need for conditional check in _ready)
		ai_thinking_timer.timeout.connect(_on_ai_decision_timeout)

func update_deck_label():
	deck_count_label.text = "Deck Left: %d" % deck.size()

func update_round_start_label():
	bonus_messages = []
	status_label.text = ""
	bonus_label.text = ""
	round_score_label.text = "Round Score: 0"
	bonus_score_label.text = ""

func build_deck():
	var new_deck = []
	for card_info in card_deck_data:
		for i in range(card_info["count"]):
			new_deck.append(card_info)
	return new_deck

func _on_draw_pressed():
	update_round_start_label()
	# Return unflipped cards to deck
	for card in hand_cards:
		if not card.is_flipped:
			deck.append({
				"value": card.card_value,
				"texture": card.front_texture,
				"count": 1
			})
			
	for card in ai_hand_cards:
		if not card.is_flipped:
			deck.append({
				"value": card.card_value,
				"texture": card.front_texture,
				"count": 1
			})
			
	deck.shuffle()

	# Clear old hand
	for child in hand_container.get_children():
		child.queue_free()
	for child in ai_hand_container.get_children():
		child.queue_free()
		
	hand_cards.clear()
	ai_hand_cards.clear()
	flip_index = 0
	ai_flip_index = 0
	total_flipped_value = 0
	ai_total_flipped_value = 0
	bonus_score = 0
	ai_bonus_score = 0
	flipped_values.clear()
	ai_flipped_values.clear()
	
	draw_button.visible = true
	flip_button.visible = false
	stay_button.visible = false

	# Check if deck is empty — rebuild if needed
	if deck.is_empty():
		deck = build_deck()
		deck.shuffle()
		print("Deck was empty. Rebuilding full deck...")

	# Draw 5 cards
	var draw_count = min(5, deck.size())
	for i in range(draw_count):
		var card_info = deck.pop_back()
		var card = card_scene.instantiate()
		card.front_texture = card_info["texture"]
		card.back_texture = back_image
		card.card_value = card_info["value"]
		hand_container.add_child(card)
		hand_cards.append(card)
		
	# Draw 5 cards for AI
	draw_count = min(5, deck.size())
	for i in range(draw_count):
		var card_info = deck.pop_back()
		var card = card_scene.instantiate()
		card.front_texture = card_info["texture"]
		card.back_texture = back_image
		card.card_value = card_info["value"]
		ai_hand_container.add_child(card)
		ai_hand_cards.append(card)

	if hand_cards.size() > 0:
		flip_button.visible = true
		flip_button.disabled = false
		stay_button.disabled = false
		
	update_deck_label()

func start_ai_turn():
	if ai_flip_index >= ai_hand_cards.size():
		return  # AI has no more cards to flip
		
	ai_turn = true
	flip_button.disabled = true
	stay_button.disabled = true
	ai_status_label.text = "AI is thinking..."
	ai_thinking_timer.start()

	# Prepare game state for AI - ADD THIS BLOCK
	var ai_state = {
		"flipped_values": ai_flipped_values.duplicate(),
		"current_score": ai_total_flipped_value,
		"flipped_count": ai_flip_index,
		"busted": false,
		"deck_size": deck.size(),
		"deck": deck.duplicate(),
		"action": ""
	}

	var human_state = {
		"flipped_values": flipped_values.duplicate(),
		"current_score": total_flipped_value,
		"flipped_count": flip_index,
		"busted": false,
		"deck_size": deck.size(),
		"action": ""
	}

	# Process AI decision
	var decision = AI.make_decision(ai_state, human_state, deck.duplicate())
	
	if decision == "flip" and ai_flip_index < ai_hand_cards.size():
		_on_ai_flip()
	else:
		_on_ai_stay()

func _on_ai_flip():
	if ai_flip_index < ai_hand_cards.size():
		var card = ai_hand_cards[ai_flip_index]
		card.flip()

		# Check for bust
		if card.card_value in ai_flipped_values:
			ai_status_label.text = "AI Busted! 💥"
			ai_total_flipped_value = 0
			ai_flip_index = ai_hand_cards.size()
			ai_round_score_label.text = "AI Round Score: 0"
		else:
			ai_flipped_values.append(card.card_value)
			ai_total_flipped_value += card.card_value
			ai_round_score_label.text = "AI Round Score: %d" % ai_total_flipped_value
			ai_flip_index += 1

		# Return control to human player if AI didn't bust
		ai_turn = false
		if ai_flip_index < ai_hand_cards.size() and not (card.card_value in ai_flipped_values):
			flip_button.disabled = false
			stay_button.disabled = false

		update_deck_label()

func _on_ai_stay():
	ai_status_label.text = "AI Stays!"

	# Calculate AI bonuses
	var ai_bonus_messages = []
	ai_bonus_score = 0

	if ai_flip_index == 5:
		ai_bonus_score += 15
		ai_bonus_messages.append("5 Unique Cards! +15")

	if ai_total_flipped_value == 21:
		ai_bonus_score += 10
		ai_bonus_messages.append("Perfect 21! +10")

	if ai_bonus_messages.size() > 0:
		ai_bonus_label.text = "\n".join(ai_bonus_messages)
		ai_bonus_score_label.text = "+%d" % ai_bonus_score
	else:
		ai_bonus_label.text = ""
		ai_bonus_score_label.text = ""

	ai_total_score += ai_total_flipped_value + ai_bonus_score
	ai_total_score_label.text = "AI Total Score: %d" % ai_total_score

	# Return control to human player
	ai_turn = false
	flip_button.disabled = false
	stay_button.disabled = false

	# Check for AI win
	if ai_total_score >= 200:
		status_label.text = "🤖 AI Won!"
		flip_button.visible = false
		stay_button.visible = false
		draw_button.visible = false

func _on_ai_decision_timeout():
	ai_thinking_timer.stop()
	
	# Prepare game state for AI decision
	var ai_state = {
		"flipped_values": ai_flipped_values.duplicate(),
		"current_score": ai_total_flipped_value,
		"flipped_count": ai_flip_index,
		"busted": false,
		"deck_size": deck.size(),
		"deck": deck.duplicate(),
		"action": ""
	}
	
	var human_state = {
		"flipped_values": flipped_values.duplicate(),
		"current_score": total_flipped_value,
		"flipped_count": flip_index,
		"busted": false,
		"deck_size": deck.size(),
		"action": ""
	}
	
	# Get AI's decision
	var decision = AI.make_decision(ai_state, human_state, deck.duplicate())
	
	# Execute the decision
	if decision == "flip" and ai_flip_index < ai_hand_cards.size():
		_on_ai_flip()
	else:
		_on_ai_stay()

func _on_ai_round_complete():
	var ai_bonus_messages = []
	ai_bonus_score = 0

	if ai_flip_index == 5:
		ai_bonus_score += 15
		ai_bonus_messages.append("5 Unique Cards! +15")

	if ai_total_flipped_value == 21:
		ai_bonus_score += 10
		ai_bonus_messages.append("Perfect 21! +10")

	if ai_bonus_messages.size() > 0:
		ai_bonus_label.text = "\n".join(ai_bonus_messages)
		ai_bonus_score_label.text = "+%d" % ai_bonus_score
	else:
		ai_bonus_label.text = ""
		ai_bonus_score_label.text = ""

	ai_total_score += ai_total_flipped_value + ai_bonus_score
	ai_total_score_label.text = "AI Total Score: %d" % ai_total_score

	ai_status_label.text = "AI Round Complete!"

	# Return control to human player
	ai_turn = false
	draw_button.disabled = false

	# Check for AI win
	if ai_total_score >= 200:
		status_label.text = "🤖 AI Won!"
		flip_button.visible = false
		stay_button.visible = false
		draw_button.visible = false

func _on_flip_pressed():
	if flip_index < hand_cards.size():
		draw_button.visible = false
		var card = hand_cards[flip_index]
		card.flip()

		# Check for bust (duplicate value)
		if card.card_value in flipped_values:
			status_label.text = "You Busted! 💥"
			total_flipped_value = 0
			flip_button.visible = false
			stay_button.visible = false
			flip_index = hand_cards.size()
			round_score_label.text = "Round Score: 0"
			
			# Human busted, AI can still play
			call_deferred("start_ai_turn")
		else:
			flipped_values.append(card.card_value)
			total_flipped_value += card.card_value
			round_score_label.text = "Round Score: %d" % total_flipped_value
			flip_index += 1

			if flip_index == 1:
				stay_button.visible = true

			# Human flipped successfully, now AI's turn
			call_deferred("start_ai_turn")

		update_deck_label()

		if flip_index == hand_cards.size():
			flip_button.visible = false
			stay_button.visible = false

			if flip_index == 5:
				bonus_score += 15
				bonus_messages.append("5 Unique Cards! +15")

			if total_flipped_value == 21:
				bonus_score += 10
				bonus_messages.append("Perfect 21! +10")

			if bonus_messages.size() > 0:
				bonus_label.text = "\n".join(bonus_messages)
				bonus_score_label.text = "+%d" % bonus_score
			else:
				bonus_label.text = ""
				bonus_score_label.text = ""

			status_label.text = "Round Complete! Press Draw to continue."
			total_score += total_flipped_value + bonus_score
			total_score_label.text = "Total Score: %d" % total_score
			draw_button.visible = true

			if total_score >= 200:
				status_label.text = "🎉 You Won!"
				draw_button.visible = false
				flip_button.visible = false
				stay_button.visible = false
	else:
		flip_button.visible = false
		stay_button.visible = false

func _on_stay_pressed():
	draw_button.visible = true
	flip_button.visible = false
	stay_button.visible = false

	if total_flipped_value == 21:
		bonus_score += 10
		bonus_messages.append("Perfect 21! +10")
	
	if bonus_messages.size() > 0:
		bonus_label.text = "\n".join(bonus_messages)
		bonus_score_label.text = "+%d" % bonus_score
	else:
		bonus_label.text = ""
		bonus_score_label.text = ""

	total_score += total_flipped_value + bonus_score
	total_score_label.text = "Total Score: %d" % total_score

	if total_score >= 200:
		status_label.text = "🎉 You Won!"
	else:
		start_ai_turn()
