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
	elif args.has("--client"):
		is_dedicated_server = false
		var idx := args.find("--client")
		var ip := "127.0.0.1"
		if idx + 1 < args.size() and not args[idx + 1].begins_with("--"):
			ip = args[idx + 1]
		_start_client(ip)
	else:
		is_dedicated_server = false
		_start_server()

func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT)
	if err != OK:
		push_error("Failed to start server on port %d (error=%d)" % [DEFAULT_PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Server iniciado en puerto %d, peer_id=%d, dedicated=%s" % [DEFAULT_PORT, multiplayer.get_unique_id(), is_dedicated_server])

func _start_client(ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, DEFAULT_PORT)
	if err != OK:
		push_error("Failed to connect to %s:%d (error=%d)" % [ip, DEFAULT_PORT, err])
		return
	multiplayer.multiplayer_peer = peer
	print("[NetworkManager] Cliente conectando a %s:%d, peer_id=%d" % [ip, DEFAULT_PORT, multiplayer.get_unique_id()])