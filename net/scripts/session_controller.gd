## Session lifecycle logic (mirrors the LocomotionFSM): it interprets the raw
## transport signals, drives the connection lifecycle, writes the NetState
## blackboard and asks the SceneFlow to swap scenes. It owns no transport
## primitives itself — it commands NetTransport ("references down") and reacts
## to its signals ("signals up").
##
## Deferred-start flow (preserves the original behaviour):
##   host_game()/join_game() record the intent and load the game scene, the
##   actual peer is created only once the game scene reports ready via
##   enter_game(). Dedicated servers start immediately through start_dedicated().
class_name SessionController
extends Node

var _state: NetState
var _transport: NetTransport
var _scene_flow: SceneFlow
var _config: NetConfig

## Role we intend to become once the game scene is ready.
var _pending_role: NetState.Role = NetState.Role.OFFLINE
var _pending_ip := ""
var _timeout_timer: SceneTreeTimer = null

func setup(state: NetState, transport: NetTransport, scene_flow: SceneFlow, config: NetConfig) -> void:
	_state = state
	_transport = transport
	_scene_flow = scene_flow
	_config = config

	_transport.peer_connected.connect(_on_peer_connected)
	_transport.peer_disconnected.connect(_on_peer_disconnected)
	_transport.connected_to_server.connect(_on_connected_to_server)
	_transport.connection_failed.connect(_on_connection_failed)
	_transport.server_disconnected.connect(_on_server_disconnected)

# --- Public intent API (the NetSession facade forwards to these) -------------

## Become a listen server (host + local player). Loads the game scene; the
## server peer is created on enter_game().
func host_game() -> void:
	_pending_role = NetState.Role.HOST
	_pending_ip = ""
	_state.pending_role = NetState.Role.HOST
	_state.last_error = ""
	_scene_flow.go_to_game()

## Connect to a remote host. Loads the game scene; the client peer is created
## on enter_game().
func join_game(ip: String) -> void:
	_pending_role = NetState.Role.CLIENT
	_pending_ip = ip if not ip.is_empty() else _config.default_ip
	_state.pending_role = NetState.Role.CLIENT
	_state.last_error = ""
	_scene_flow.go_to_game()

## Headless server launched from the command line: starts the peer right away
## and loads the game scene.
func start_dedicated() -> void:
	if not _transport.host():
		_state.last_error = "No se pudo iniciar el servidor dedicado"
		return
	_state.role = NetState.Role.DEDICATED
	_state.status = NetState.Status.CONNECTED
	_pending_role = NetState.Role.OFFLINE
	_scene_flow.go_to_game()

## Called by the game scene once it is ready to actually create the peer.
func enter_game() -> void:
	var pending := _pending_role
	_pending_role = NetState.Role.OFFLINE
	_state.pending_role = NetState.Role.OFFLINE
	match pending:
		NetState.Role.HOST:
			if not _transport.host():
				_fail("No se pudo iniciar el servidor")
				return
			_state.role = NetState.Role.HOST
			_state.status = NetState.Status.CONNECTED
			_state.notify_session_started()
		NetState.Role.CLIENT:
			if not _transport.join(_pending_ip):
				_fail("No se pudo conectar a %s" % _pending_ip)
				return
			_state.role = NetState.Role.CLIENT
			_state.status = NetState.Status.CONNECTING
			_start_timeout(_pending_ip)
		_:
			# Dedicated server (already hosting) or re-entry: nothing to do.
			pass

## Tear down the session and return to the menu.
func leave() -> void:
	_cancel_timeout()
	_transport.close()
	_state.reset()
	_state.notify_session_ended()
	_scene_flow.go_to_menu()

# --- Transport reactions ("signals up") --------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_state.add_peer(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_state.remove_peer(peer_id)

func _on_connected_to_server() -> void:
	_cancel_timeout()
	_state.status = NetState.Status.CONNECTED
	_state.notify_session_started()

func _on_connection_failed() -> void:
	_fail("Conexion rechazada por el servidor")

func _on_server_disconnected() -> void:
	_state.last_error = "Desconectado del servidor"
	_cancel_timeout()
	_transport.close()
	_state.reset()
	_state.notify_session_ended()
	_scene_flow.go_to_menu()

# --- Timeout helpers ----------------------------------------------------------

func _start_timeout(ip: String) -> void:
	_cancel_timeout()
	_timeout_timer = get_tree().create_timer(_config.connect_timeout)
	_timeout_timer.timeout.connect(_on_connect_timeout.bind(ip))

func _cancel_timeout() -> void:
	_timeout_timer = null

func _on_connect_timeout(_ip: String) -> void:
	# Stale timer: already connected, left, or a newer attempt replaced it.
	if _timeout_timer == null:
		return
	if _state.status != NetState.Status.CONNECTING:
		return
	_fail("Tiempo de conexion agotado")

func _fail(message: String) -> void:
	_cancel_timeout()
	_state.status = NetState.Status.FAILED
	_state.last_error = message
	_transport.close()
	_state.reset()
	_scene_flow.go_to_menu()
