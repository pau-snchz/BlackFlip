extends Control

@export var front_texture: Texture
@export var back_texture: Texture
@export var card_value := 0

var is_flipped := false

func _ready():
	$CardSprite.texture = back_texture

func flip():
	if not is_flipped:
		is_flipped = true
		$CardSprite.texture = front_texture
