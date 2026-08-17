extends Node

const PORT = 9999
var peer = ENetMultiplayerPeer.new()

var player_scene = preload("res://Scenes/char.tscn")
var is_multiplayer: bool = false
func host_room() -> void:
	is_multiplayer = true
	
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_add_player)
	
	get_tree().change_scene_to_file("res://Scenes/main.tscn") 
	
	await get_tree().create_timer(0.5).timeout
	_add_player(multiplayer.get_unique_id())

func join_room(ip_address: String) -> void:
	is_multiplayer = true
	
	peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = peer
	
	multiplayer.connected_to_server.connect(_on_connection_success, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

func _on_connection_success() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_connection_failed() -> void:
	reset_to_singleplayer()
	print("Could not connect to Host! Invalid IP or no server running.")

func _add_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	await get_tree().create_timer(1.0).timeout 
		
	var spawn_node = get_tree().current_scene.get_node_or_null("SpawnedPlayers")
	if not spawn_node:
		push_error("Could not find SpawnedPlayers node in the level!")
		return
		
	var player = player_scene.instantiate()
	player.name = str(peer_id) 

	spawn_node.add_child(player)
	
func reset_to_singleplayer() -> void:
	is_multiplayer = false
	

	multiplayer.multiplayer_peer = null
