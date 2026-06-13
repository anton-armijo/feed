extends Node

const DEFAULT_PORT := 4242
const CONNECT_TIMEOUT := 5.0

static var is_dedicated_server := false
static var connect_ip: String = ""
static var pending_host: bool = false
static var last_error: String = ""

var _connecting := false
var _connect_ip: String = ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()

	print("[NetworkManager] Args recibidos: ", args)

	if args.has("--server"):
		is_dedicated_server = true
		_start_server()
		call_deferred("_load_main")
		return

func _load_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _load_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_main_scene_loaded(loading_screen: Node) -> void:
	if connect_ip != "":
		var ip := connect_ip
		connect_ip = ""
		last_error = ""

		loading_screen.set_status("Estableciendo conexion...")

		if not _start_client(ip):
			last_error = "No se pudo conectar a %s" % ip
			_load_menu()
			return

		_connecting = true
		_connect_ip = ip
		multiplayer.connection_failed.connect(_on_connection_failed.bind(loading_screen), CONNECT_ONE_SHOT)
		multiplayer.connected_to_server.connect(_on_connected.bind(loading_screen), CONNECT_ONE_SHOT)
		var timer := get_tree().create_timer(CONNECT_TIMEOUT)
		timer.timeout.connect(_on_connect_timeout.bind(loading_screen, ip))

	elif pending_host:
		pending_host = false
		last_error = ""
		_start_server()
		loading_screen.start_fade_out()

func _on_connected(loading_screen: Node) -> void:
	_connecting = false
	loading_screen.set_status("Conectado")
	loading_screen.start_fade_out()

func _on_connection_failed(loading_screen: Node) -> void:
	_connecting = false
	last_error = "Conexion rechazada por el servidor"
	_cleanup_peer()
	_load_menu()

func _on_connect_timeout(loading_screen: Node, ip: String) -> void:
	if _connect_ip != ip:
		return
	if not _connecting:
		return
	_connecting = false
	last_error = "Tiempo de conexion agotado"
	_cleanup_peer()
	_load_menu()

func _cleanup_peer() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_connect_ip = ""
	_connecting = false

func cleanup_peer() -> void:
	_cleanup_peer()

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
