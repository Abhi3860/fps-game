extends Control

@onready var sens_slider: HSlider = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer/HSlider
@onready var jump_button: Button = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer2/JumpButton
@onready var dash_button: Button = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer3/DashButton
@onready var power_button: Button = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer4/PowerButton

@onready var reload_button: Button = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer5/ReloadButton
@onready var back_button: Button = $ColorRect/CenterContainer/VBoxContainer/BackButton
@onready var grenade_button: Button = $ColorRect/CenterContainer/VBoxContainer/HBoxContainer6/GrenadeButton

var is_remapping: bool = false
var action_to_remap: String = ""
var button_to_update: Button = null

func _ready() -> void:
	sens_slider.value = GlobalSettings.mouse_sensitivity
	_update_button_text(jump_button, "jump")

func _on_h_slider_value_changed(value: float) -> void:
	GlobalSettings.mouse_sensitivity = value

func _on_jump_button_pressed() -> void:
	start_remapping("jump", jump_button)

func _on_dash_button_pressed() -> void:
	start_remapping("dash", dash_button)

func _on_power_button_pressed() -> void:
	start_remapping("power", power_button)

func _on_reload_button_pressed() -> void:
	start_remapping("reload", reload_button)

func _on_grenade_button_pressed() -> void:
	start_remapping("throw_grenade", grenade_button)

func start_remapping(action: String, button: Button) -> void:
	is_remapping = true
	action_to_remap = action
	button_to_update = button
	button.text = "Press any key..."

func _input(event: InputEvent) -> void:
	var valid_key = event is InputEventKey and event.pressed
	var valid_mouse = event is InputEventMouseButton and event.pressed
	
	if is_remapping and (valid_key or valid_mouse):
		
		InputMap.action_erase_events(action_to_remap)
		
		InputMap.action_add_event(action_to_remap, event)
		
		_update_button_text(button_to_update, action_to_remap)
		is_remapping = false
		
		get_viewport().set_input_as_handled()

func _update_button_text(button: Button, action: String) -> void:
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		button.text = events[0].as_text().trim_suffix(" (Physical)")
	else:
		button.text = "Unassigned"

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
