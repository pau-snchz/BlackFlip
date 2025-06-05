extends Control

@onready var hand_container = $HandContainer
@onready var draw_button = $DrawButton
@onready var flip_button = $FlipButton
@onready var total_value_label = $TotalValueLabel

var card_scene = preload("res://Scenes/Card.tscn")
var BACK_IMAGE = preload("res://Assets/Back.png")

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
var flip_index = 0
var total_flipped_value = 0

func _ready():
	flip_button.visible = false

func build_deck():
	var new_deck = []
	for card_info in card_deck_data:
		for i in range(card_info["count"]):
			new_deck.append(card_info)
	return new_deck

func _on_draw_pressed():
	# Clear old hand
	for child in hand_container.get_children():
		child.queue_free()
	hand_cards.clear()
	flip_index = 0
	total_flipped_value = 0
	flip_button.visible = false

	# Reset UI label
	total_value_label.text = "Total Value: 0"

	# Build and shuffle deck
	deck = build_deck()
	deck.shuffle()

	# Draw 5 cards
	var draw_count = min(5, deck.size())
	for i in range(draw_count):
		var card_info = deck.pop_back()
		var card = card_scene.instantiate()
		card.front_texture = card_info["texture"]
		card.back_texture = BACK_IMAGE
		card.card_value = card_info["value"]
		hand_container.add_child(card)
		hand_cards.append(card)

	if draw_count > 0:
		flip_button.visible = true

func _on_flip_pressed():
	if flip_index < hand_cards.size():
		var card = hand_cards[flip_index]
		card.flip()
		total_flipped_value += card.card_value
		flip_index += 1
		print("Total flipped value:", total_flipped_value)

		# Update label text
		total_value_label.text = "Total Value: %d" % total_flipped_value
	else:
		flip_button.visible = false
