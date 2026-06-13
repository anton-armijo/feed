extends Control

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

const CONNECTION_TIMEOUT := 5.0

var _connecting := false

func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		return

	connect_button.pressed.connect(_on_connect)
	host_button.pressed.connect(_on_host)

func _on_connect() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"

	status_label.text = "Conectando a %s..." % ip
	connect_button.disabled = true
	host_button.disabled = true

	if not NetworkManager.start_as_client(ip):
		_show_error("No se pudo conectar a %s" % ip)
		return

	_connecting = true
	multiplayer.connected_to_server.connect(_on_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)
	var timer := get_tree().create_timer(CONNECTION_TIMEOUT)
	timer.timeout.connect(_on_timeout)

func _on_host() -> void:
	status_label.text = "Iniciando servidor..."
	connect_button.disabled = true
	host_button.disabled = true

	if not NetworkManager.start_as_host():
		_show_error("No se pudo iniciar el servidor")
		return

	await get_tree().create_timer(0.2).timeout
	_load_main()

func _on_connected() -> void:
	_connecting = false
	status_label.text = "Conectado"
	await get_tree().create_timer(0.3).timeout
	_load_main()

func _on_connection_failed() -> void:
	_connecting = false
	_cleanup_peer()
	_show_error("Conexion rechazada por el servidor")

func _on_timeout() -> void:
	if not _connecting:
		return
	_connecting = false
	_cleanup_peer()
	_show_error("Tiempo de conexion agotado")

func _cleanup_peer() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func _show_error(msg: String) -> void:
	status_label.text = msg
	connect_button.disabled = false
	host_button.disabled = false

func _load_main() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
