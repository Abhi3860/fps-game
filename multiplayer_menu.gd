extends Control

@onready var ip_input: LineEdit = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer/IPInput

func _on_host_button_pressed() -> void:
	NetworkManager.host_room()
	# Hide the menu and load the arena

func _on_join_button_pressed() -> void:
	var ip = ip_input.text
	if ip == "":
		ip = "127.0.0.1"
		
	NetworkManager.join_room(ip)
