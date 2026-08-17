extends Control

func _on_play_button_pressed() -> void:
	NetworkManager.reset_to_singleplayer()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/settings_menu.tscn")


func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/multiplayer_menu.tscn")
