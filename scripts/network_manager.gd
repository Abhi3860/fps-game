extends Node

# CHANGE THIS to your Python server's URL. Keep 127.0.0.1 for local testing.
# When you upload to itch.io, this will be your hosted wss:// URL!
const SIGNALING_URL = "ws://127.0.0.1:8000/ws/" 

var ws := WebSocketPeer.new()
var rtc_mp := WebRTCMultiplayerPeer.new()
var rtc_peer := WebRTCPeerConnection.new()

var player_scene = preload("res://Scenes/char.tscn")
var is_multiplayer: bool = false
var is_ending_multiplayer_match: bool = false
var is_host: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	
	rtc_peer.session_description_created.connect(_on_sdo_created)
	rtc_peer.ice_candidate_created.connect(_on_ice_candidate)

func host_room(room_code: String) -> void:
	is_multiplayer = true
	is_host = true
	ws.connect_to_url(SIGNALING_URL + room_code)
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func join_room(room_code: String) -> void:
	is_multiplayer = true
	is_host = false
	ws.connect_to_url(SIGNALING_URL + room_code)

func _process(_delta: float) -> void:
	ws.poll()
	var state = ws.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		while ws.get_available_packet_count():
			var data = ws.get_packet().get_string_from_utf8()
			var dict = JSON.parse_string(data)
			_handle_signaling(dict)
			
	elif state == WebSocketPeer.STATE_CLOSED and is_multiplayer:
		push_error("Disconnected from matchmaking server.")

func _handle_signaling(data: Dictionary) -> void:
	var type = data.get("type")
	
	if type == "id":
		var my_id = data["id"]
		if is_host:
			rtc_mp.create_server()
			multiplayer.multiplayer_peer = rtc_mp
			await get_tree().create_timer(0.5).timeout
			_add_player(1)
		else:
			rtc_mp.create_client(my_id)
			multiplayer.multiplayer_peer = rtc_mp
			
			rtc_peer.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
			rtc_mp.add_peer(rtc_peer, 1)
			rtc_peer.create_offer()
			
			get_tree().change_scene_to_file("res://Scenes/main.tscn")
			
	elif type == "offer":
		rtc_peer.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]})
		rtc_mp.add_peer(rtc_peer, 2)
		
		rtc_peer.set_remote_description("offer", data["sdp"])
		
	elif type == "answer":
		rtc_peer.set_remote_description("answer", data["sdp"])
		
	elif type == "ice":
		rtc_peer.add_ice_candidate(data["mid"], data["index"], data["sdp"])
		
	elif type == "peer_disconnected":
		_on_server_disconnected()

func _on_sdo_created(type: String, sdp: String) -> void:
	rtc_peer.set_local_description(type, sdp)
	ws.send_text(JSON.stringify({"type": type, "sdp": sdp}))

func _on_ice_candidate(media: String, index: int, sdp_name: String) -> void:
	ws.send_text(JSON.stringify({
		"type": "ice",
		"mid": media,
		"index": index,
		"sdp": sdp_name
	}))

func _on_server_disconnected() -> void:
	reset_to_singleplayer()
	get_tree().change_scene_to_file("res://Scenes/multiplayer_menu.tscn")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _add_player(peer_id: int) -> void:
	if not multiplayer.is_server(): return
		
	await get_tree().create_timer(1.0).timeout 
		
	var spawn_node = get_tree().current_scene.get_node_or_null("SpawnedPlayers")
	if not spawn_node: return
		
	var player = player_scene.instantiate()
	player.name = str(peer_id) 
	spawn_node.add_child(player)
	
func reset_to_singleplayer() -> void:
	is_multiplayer = false
	is_ending_multiplayer_match = false
	multiplayer.multiplayer_peer = null
	
	rtc_peer.close()
	ws.close()
	rtc_mp = WebRTCMultiplayerPeer.new()
	rtc_peer = WebRTCPeerConnection.new()

func end_multiplayer_match() -> void:
	if not is_multiplayer or is_ending_multiplayer_match: return
	if multiplayer.is_server():
		begin_multiplayer_death_screen.rpc()
		begin_multiplayer_death_screen()

@rpc("authority", "call_remote", "reliable")
func begin_multiplayer_death_screen() -> void:
	if is_ending_multiplayer_match: return
	is_ending_multiplayer_match = true
	call_deferred("_finish_multiplayer_match")

func _finish_multiplayer_match() -> void:
	is_multiplayer = false
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://Scenes/deathscene.tscn")

func _remove_player(peer_id: int) -> void:
	if not multiplayer.is_server(): return
		
	var spawn_node = get_tree().current_scene.get_node_or_null("SpawnedPlayers")
	if not spawn_node: return
		
	var player_to_remove = spawn_node.get_node_or_null(str(peer_id))
	if player_to_remove:
		player_to_remove.queue_free()
