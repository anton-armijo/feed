extends Node

const DEFAULT_PORT := 4242

static var is_dedicated_server := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	print("[NetworkManager] Args recibidos: ", args)

	if args.has("--server"):
		is_dedicated_server = true
		_start_server()
		return

	call_deferred("_load_menu")

func _load_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func start_as_host() -> bool:
	is_dedicated_server = false
	return _start_server()

func start_as_client(ip: String) -> bool:
	is_dedicated_server = false
	if ip.is_empty() or ip.contains(" "):
		push_error("Invalid IP address: \"%s\"" % ip)
		return false
	return _start_client(ip)

func _start_server() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT)
	if err != OK:
		push_error("Failed to start server on port %d (error=%d)" % [DEFAULT_PORT, err])
		peer.close()
		return false
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Server iniciado en puerto %d, peer_id=%d, dedicated=%s" % [DEFAULT_PORT, multiplayer.get_unique_id(), is_dedicated_server])
	return true

func _start_client(ip: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		push_error("Failed to connect to %s:%d (error=%d)" % [ip, DEFAULT_PORT, err])
		peer.close()
		return false
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Cliente conectando a %s:%d, peer_id=%d" % [ip, DEFAULT_PORT, multiplayer.get_unique_id()])
	return true
