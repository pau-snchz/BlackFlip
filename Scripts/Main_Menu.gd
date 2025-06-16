extends Node2D

func _on_play_pressed() -> void:
	pass # Replace with function body.


func _on_learn_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/GameMech.tscn")
