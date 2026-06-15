## Transport layer: the ONLY script allowed to create/destroy the
## ENetMultiplayerPeer and write `multiplayer.multiplayer_peer` (mirrors the
## MovementMotor being the single physics write). It owns no lifecycle policy:
## it just creates peers and re-emits the raw multiplayer signals upward so the
## SessionController can interpret them. Swap this node out for a WebSocket /
## Steam transport and the rest of the session keeps working untouched.
class_name NetTransport
extends Node

## Re-emitted multiplayer signals (server side).
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

## Re-emitted multiplayer signals (client side).
signal connected_to_server
signal connection_failed
signal server_disconnected

var _state: NetState
var _config: NetConfig

func setup(state: NetState, config: NetConfig) -> void:
	_state = state
	_config = config
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Starts an ENet server. Returns false (and leaves no peer) on failure.
func host() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_config.port, _config.max_clients)
	if err != OK:
		push_error("[NetTransport] create_server failed on port %d (error=%d)" % [_config.port, err])
		peer.close()
		return false
	multiplayer.multiplayer_peer = peer
	_state.local_peer_id = multiplayer.get_unique_id()
	print("[NetTransport] Server up on port %d, peer_id=%d" % [_config.port, _state.local_peer_id])
	return true

## Starts an ENet client connecting to `ip`. Returns false on bad input or
## immediate failure; success only means the handshake has begun.
func join(ip: String) -> bool:
	if ip.is_empty() or ip.contains(" "):
		push_error("[NetTransport] Invalid IP address: \"%s\"" % ip)
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, _config.port)
	if err != OK:
		push_error("[NetTransport] create_client failed for %s:%d (error=%d)" % [ip, _config.port, err])
		peer.close()
		return false
	multiplayer.multiplayer_peer = peer
	_state.local_peer_id = multiplayer.get_unique_id()
	print("[NetTransport] Client connecting to %s:%d, peer_id=%d" % [ip, _config.port, _state.local_peer_id])
	return true

## Tears down the active peer (idempotent).
func close() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

func has_peer() -> bool:
	return multiplayer.multiplayer_peer != null

# --- Raw signal forwarding ("signals up") ------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)

func _on_connected_to_server() -> void:
	connected_to_server.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()

func _on_server_disconnected() -> void:
	server_disconnected.emit()
