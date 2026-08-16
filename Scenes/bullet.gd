extends Area3D

@export var speed: float = 90.0
@export var lifetime: float = 3.0
@export var damage: float = 25.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		return
		
	if body.has_method("take_damage"):
		body.take_damage(damage)
		get_tree().call_group("hud", "show_hitmarker")
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			var player = players[0]
			if player.is_lifesteal_active:
				player.heal(damage * 0.5)
		
	queue_free()
