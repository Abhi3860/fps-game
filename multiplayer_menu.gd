extends Control

@onready var ip_input: LineEdit = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer/IPInput

func _on_host_button_pressed() -> void:
	var code = ip_input.text
	if code == "":
		code = "XYZ12" 
		
	NetworkManager.host_room(code)

func _on_join_button_pressed() -> void:
	var code = ip_input.text
	if code == "":
		code = "XYZ12" 
	
	NetworkManager.join_room(code)
