extends Control

@onready var hand_container = $HandContainer
@onready var draw_button = $DrawButton
@onready var flip_button = $FlipButton
@onready var stay_button = $StayButton
@onready var round_score_label = $RoundScoreLabel
@onready var bonus_score_label = $BonusScoreLabel
@onready var total_score_label = $TotalScoreLabel
@onready var deck_count_label = $DeckCountLabel
@onready var status_label = $StatusLabel
@onready var bonus_label = $BonusLabel

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

func _ready():
	flip_button.visible = false
	stay_button.visible = false
	status_label.text = ""
	round_score_label.text = "Round Score: 0"
	total_score_label.text = "Total Score: 0"
	deck = build_deck()
	deck.shuffle()
	update_deck_label()

func update_deck_label():
	deck_count_label.text = "Deck Left: %d" % deck.size()

func update_round_start_label():
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
	deck.shuffle()

	# Clear old hand
	for child in hand_container.get_children():
		child.queue_free()
	hand_cards.clear()
	flip_index = 0
	total_flipped_value = 0
	bonus_score = 0
	flipped_values.clear()
	flip_button.visible = false

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

	if draw_count > 0:
		flip_button.visible = true
		stay_button.visible = true
		
	update_deck_label()


func _on_flip_pressed():
	if flip_index < hand_cards.size():
		draw_button.visible = false
		var bust_indicator = 0
		var card = hand_cards[flip_index]
		card.flip()

		# Check for bust (duplicate value)
		if card.card_value in flipped_values:
			status_label.text = "You Busted! 💥"
			total_flipped_value = 0
			flip_button.visible = false
			stay_button.visible = false
			flip_index = hand_cards.size() 
			bust_indicator = 1
			round_score_label.text = "Round Score: 0"
		else:
			flipped_values.append(card.card_value)
			total_flipped_value += card.card_value
			round_score_label.text = "Round Score: %d" % total_flipped_value
			flip_index += 1

		update_deck_label()

		if flip_index == hand_cards.size():
			flip_button.visible = false
			stay_button.visible = false

			if bust_indicator == 0:
				if flip_index == 5:
					bonus_score += 15
					bonus_messages.append("5 Unique Cards! +15")

				if total_flipped_value == 21:
					bonus_score += 10
					bonus_messages.append("Perfect 21! +10")

				if bonus_messages.size() > 0:
					bonus_label.text = " & ".join(bonus_messages)
					bonus_score_label.text = "+%d" % bonus_score
				else:
					bonus_label.text = ""
					bonus_score_label.text = ""

				status_label.text = "Round Complete! Press Draw to continue."

			if bonus_score > 0:
				bonus_score_label.text = "+%d" % bonus_score

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

	if total_flipped_value == 21:
		bonus_score += 10
		bonus_messages.append("Perfect 21! +10")
	
	if bonus_messages.size() > 0:
		bonus_label.text = " & ".join(bonus_messages)
		bonus_score_label.text = "+%d" % bonus_score
	else:
		bonus_label.text = ""
		bonus_score_label.text = ""

	total_score += total_flipped_value + bonus_score
	total_score_label.text = "Total Score: %d" % total_score

	flip_button.visible = false
	stay_button.visible = false

	if total_score >= 200:
		status_label.text = "🎉 You Won!"
