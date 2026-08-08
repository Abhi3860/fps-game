extends CanvasLayer

@onready var dash_container: HBoxContainer = $MarginContainer/VBoxContainer/DashContainer
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var ammo_label: Label = $MarginContainer2/AmmoLabel

var dash_pips: Array = []

func _ready() -> void:
	var player = get_parent()
	
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
	ammo_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8)) # Make it dim gray
func _on_player_health_updated(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
