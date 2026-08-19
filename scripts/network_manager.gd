extends Node

const PORT = 9999
var peer = ENetMultiplayerPeer.new()

var player_scene = preload("res://Scenes/char.tscn")
var is_multiplayer: bool = false
var is_ending_multiplayer_match: bool = false
func host_room() -> void:
	is_multiplayer = true
	
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	
	if not multiplayer.peer_connected.is_connected(_add_player):
		multiplayer.peer_connected.connect(_add_player)
	if not multiplayer.peer_disconnected.is_connected(_remove_player):
		multiplayer.peer_disconnected.connect(_remove_player)
	
	get_tree().change_scene_to_file("res://Scenes/main.tscn") 
	
	await get_tree().create_timer(0.5).timeout
	_add_player(multiplayer.get_unique_id())

func join_room(ip_address: String) -> void:
	is_multiplayer = true
	
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_address, PORT)
	multiplayer.multiplayer_peer = peer
	
	if not multiplayer.connected_to_server.is_connected(_on_connection_success):
		multiplayer.connected_to_server.connect(_on_connection_success, CONNECT_ONE_SHOT)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

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
	is_ending_multiplayer_match = false
	multiplayer.multiplayer_peer = null
	if peer != null:
		peer.close()

func end_multiplayer_match() -> void:
	if not is_multiplayer or is_ending_multiplayer_match:
		return
	if multiplayer.is_server():
		begin_multiplayer_death_screen.rpc()
		begin_multiplayer_death_screen()

@rpc("authority", "call_remote", "reliable")
func begin_multiplayer_death_screen() -> void:
	if is_ending_multiplayer_match:
		return
	is_ending_multiplayer_match = true
	call_deferred("_finish_multiplayer_match")

func _finish_multiplayer_match() -> void:
	is_multiplayer = false
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/deathscene.tscn")

func _remove_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var spawn_node = get_tree().current_scene.get_node_or_null("SpawnedPlayers")
	if not spawn_node:
		return
		
	var player_to_remove = spawn_node.get_node_or_null(str(peer_id))
	if player_to_remove:
		player_to_remove.queue_free()
		print("Player " + str(peer_id) + " disconnected and was removed.")
func _on_server_disconnected() -> void:
	reset_to_singleplayer()
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	print("Host disconnected. Returning to main menu.")
