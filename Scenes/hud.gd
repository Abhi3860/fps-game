extends CanvasLayer

@onready var dash_container: HBoxContainer = $MarginContainer/VBoxContainer/DashContainer
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var ammo_label: Label = $MarginContainer2/VBoxContainer/AmmoLabel
@onready var hitmarker: Control = $Hitmarker
@onready var power_label: Label = $PowerLabel

var dash_pips: Array = []

func _ready() -> void:
	var player = get_parent()
	# A player scene is instantiated for every peer. Only the locally controlled
	# player should contribute a screen-space HUD on this client.
	if NetworkManager.is_multiplayer and not player.is_multiplayer_authority():
		hide()
		remove_from_group("hud")
		return
	
	player.dashes_updated.connect(_on_player_dashes_updated)
	setup_pips(player.max_dashes)
	player.ammo_updated.connect(_on_player_ammo_updated)
	player.weapon_reloading.connect(_on_player_weapon_reloading)
	player.health_updated.connect(_on_player_health_updated)

#dash ui
func setup_pips(max_dashes: int) -> void:
	for i in range(max_dashes):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(40, 8) 
		dash_container.add_child(pip)
		dash_pips.append(pip)

func _on_player_dashes_updated(current: int, maximum: int) -> void:
	for i in range(maximum):
		if i < current:
			dash_pips[i].color = Color(0.0, 1.0, 1.0, 1.0) 
		else:
			dash_pips[i].color = Color(0.2, 0.2, 0.2, 0.5)

#ammo ui
func _on_player_ammo_updated(current: int, maximum: int) -> void:
	ammo_label.text = str(current) + " / " + str(maximum)
	#fancy colours cuz fancy
	if current <= (maximum * 0.25):
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	else:
		ammo_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

func _on_player_weapon_reloading() -> void:
	ammo_label.text = "Reloading..."
	ammo_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
func _on_player_health_updated(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	
func show_hitmarker() -> void:
	if hitmarker:
		hitmarker.flash()

@onready var grenade_label: Label = $MarginContainer2/VBoxContainer/GrenadeLabel

func update_grenades(current: int, maximum: int) -> void:
	grenade_label.text = "Grenades: " + str(current) + " / " + str(maximum)

@onready var wave_label: Label = $WaveLabel

func update_wave_text(wave: int) -> void:
	wave_label.text = "WAVE " + str(wave)
func update_countdown_text(time_left: int) -> void:
	wave_label.text = "NEXT WAVE IN: " + str(time_left)
func update_power_text(new_text: String) -> void:
	power_label.text = new_text
@onready var death_panel: ColorRect = $DeathOverlay


func show_death_screen() -> void:
	death_panel.show()


func _on_restart_button_pressed() -> void:
	death_panel.hide()
	if get_parent().has_method("respawn"):
		get_parent().respawn()

#pause menu
@onready var pause_panel: ColorRect = $PausePanel

func _unhandled_input(event: InputEvent) -> void:
	# Ignore pause inputs if the player is dead (assuming you added the is_dead variable!)
	if get_parent().get("is_dead"):
		return
		
	# Usually mapped to the Escape key in Project Settings -> Input Map
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	if pause_panel.visible:
		pause_panel.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		if not NetworkManager.is_multiplayer:
			get_tree().paused = false
	else:
		pause_panel.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		if not NetworkManager.is_multiplayer:
			get_tree().paused = true

func _on_resume_button_pressed() -> void:
	toggle_pause()

func _on_menu_button_pressed() -> void:
	
	get_tree().paused = false 
	
	NetworkManager.reset_to_singleplayer()
	
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
