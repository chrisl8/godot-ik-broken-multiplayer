extends Node

signal reset
signal close_popup

enum Message { PLAYER_JOINED, PLAYER_START_GAME, SHUTDOWN_SERVER }

#@export var player_spawn_point: Vector2 = Vector2(0, 0)

var ws: WebSocketPeer = WebSocketPeer.new()
var ready_to_connect: bool = false
var peers: Dictionary
var peer_count: int = -1
var peers_have_connected: bool = false
var network_initialized: bool = false
var game_scene_initialize_in_progress: bool = false
var game_scene_initialized: bool = false
var network_connection_initiated: bool = false

var player_character_template: PackedScene = preload("res://player/player.tscn")

var websocket_multiplayer_peer: WebSocketMultiplayerPeer


func _process(_delta: float) -> void:
	if not ready_to_connect:
		return

	if not network_connection_initiated:
		network_connection_initiated = true
		init_network()

	if not network_initialized:
		return

	if peers.size() != peer_count:
		peer_count = peers.size()
		if peer_count > 0:
			peers_have_connected = true
		Helpers.log_print(str("New peer count is: ", peer_count), "cyan")

	if not Globals.is_server:
		# Only server proceeds past this point,
		# adding and removing objects, etc.
		return

	# In Debug mode, exit server if everyone disconnects in order to speed up debugging sessions (less windows to close)
	if (
		OS.is_debug_build()
		and peers_have_connected
		and peer_count < 1
		and !Globals.shutdown_in_progress
	):
		Helpers.log_print(
			"Closing server due to all clients disconnecting and this running in Debug mode.",
			"cyan"
		)
		Helpers.quit_gracefully()

	# Initialize the Map if it isn't yet
	if not game_scene_initialized:
		game_scene_initialized = true
		close_popup.emit()


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)


func _peer_connected(id: int) -> void:
	Helpers.log_print(str("Peer ", id, " connected."), "cyan")
	peers[id] = {}


func _peer_disconnected(id: int) -> void:
	Helpers.log_print(str("Peer ", id, " Disconnected."), "cyan")
	if peers.has(id):
		peers.erase(id)
	if not Globals.is_server:
		return

	var player_spawner_node: Node = get_node_or_null("../Main/Players")
	if player_spawner_node and player_spawner_node.has_node(str(id)):
		var player: Node = player_spawner_node.get_node(str(id))
		print_rich(
			"[color=blue]",
			"Server: Player ",
			id,
			" disconnected while at position ",
			player.position,
			" rotation ",
			player.rotation,
			"[/color]"
		)
		player.queue_free()


func _connected_to_server() -> void:
	Helpers.log_print("I connected to the server!", "cyan")

	# Server does not spawn our player until we send a "join" message
	send_data_to(1, Message.PLAYER_JOINED, "")


func _connection_failed() -> void:
	Helpers.log_print("My connection failed. =(", "cyan")
	Globals.connection_failed_message = "Connection Failed!"
	reset_connection()


func _server_disconnected() -> void:
	Helpers.log_print("Server Disconnected", "cyan")
	Globals.connection_failed_message = "Connection Interrupted!"
	reset_connection()


func shutdown_server() -> void:
	if Globals.is_server and peers.size() > 0:
		for key: int in peers:
			print_rich("[color=blue]Telling ", key, " to disconnect[/color]")
			websocket_multiplayer_peer.disconnect_peer(key)


func reset_connection() -> void:
	Helpers.log_print("Resetting Connection", "cyan")
	ready_to_connect = false
	network_connection_initiated = false
	network_initialized = false
	game_scene_initialized = false
	game_scene_initialize_in_progress = false
	multiplayer.multiplayer_peer = null
	websocket_multiplayer_peer = null
	peer_count = -1
	peers.clear()
	reset.emit(5)


func init_network() -> void:
	Helpers.log_print("Init Network", "cyan")
	websocket_multiplayer_peer = WebSocketMultiplayerPeer.new()
	# This is a client/server setup, NOT a Mesh.
	if Globals.is_server:
		websocket_multiplayer_peer.create_server(9091)
	else:
		var error: int = websocket_multiplayer_peer.create_client(Globals.url)  # WebSocket
		if error:
			Helpers.log_print(str("Websocket Error: ", error), "cyan")
	get_tree().get_multiplayer().multiplayer_peer = websocket_multiplayer_peer
	network_initialized = true


func send_data_to(id: int, msg_type: Message, data: String) -> void:
	var send_data: String = (
		JSON
		. stringify(
			{
				"type": msg_type,
				"data": data,
			}
		)
	)
	rpc_id(id, "data_received", send_data)


@rpc("any_peer")
func data_received(data: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	var json: JSON = JSON.new()
	var error: int = json.parse(data)
	if error != OK:
		printerr(
			"JSON Parse Error: ",
			json.get_error_message(),
			" in ",
			data,
			" at line ",
			json.get_error_line(),
			" from ",
			sender_id
		)
		return

	var parsed_message: Variant = json.data
	if (
		typeof(parsed_message) != TYPE_DICTIONARY
		or not parsed_message.has("type")
		or not parsed_message.has("data")
	):
		printerr("Data error in: ", parsed_message, " from ", sender_id)
		return

	if parsed_message.type == Message.PLAYER_JOINED:
		player_joined(sender_id)
		return

	if parsed_message.type == Message.PLAYER_START_GAME:
		close_popup.emit()
		return

	printerr(
		"Unknown Message Type ", parsed_message.type, " in: ", parsed_message, " from ", sender_id
	)


func player_joined(id: int) -> void:
	if Globals.is_server and id > 1:  # I'm not sure this check is necessary
		var character: Node = player_character_template.instantiate()
		character.player = id  # Set player id.

		character.position = Vector2((randf() - 0.5) * 2.0 * 400.0, 10 + randf() * 1000.0)

		character.name = str(id)
		get_node("../Main/Players").add_child(character, true)
		character.set_multiplayer_authority(character.player)

		send_data_to(id, Message.PLAYER_START_GAME, "")
