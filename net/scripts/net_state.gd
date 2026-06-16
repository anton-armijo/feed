## The "vanilla state" of the network session: the single public read surface
## (mirrors PlayerBlackboard). Everyone reads these fields or connects to the
## change signals below; nobody else writes them.
##
## Ownership rules (write access):
##   - SessionController -> role, status, last_error, peer bookkeeping.
##   - NetTransport      -> local_peer_id (on peer creation).
## UI (menu, loading screen), the spawn service and game-specific sync nodes
## are pure observers: they react to the signals and never poke the transport.
class_name NetState
extends Node

signal role_changed(role: Role)
signal status_changed(status: Status)
signal error_changed(message: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal session_started
signal session_ended
signal mouse_capture_blocked_changed(blocked: bool)

## What this process is doing in the session.
enum Role { OFFLINE, HOST, CLIENT, DEDICATED }

## Where the connection lifecycle currently sits.
enum Status { OFFLINE, CONNECTING, CONNECTED, FAILED }

var role: Role = Role.OFFLINE:
	set(value):
		if role == value:
			return
		role = value
		role_changed.emit(value)

## The role this process intends to become once the game scene is ready.
## Set the moment the user picks host/join, before the peer actually exists, so
## game scenes can branch on it during _enter_tree/_ready (e.g. the host-only
## maze size picker).
var pending_role: Role = Role.OFFLINE

var status: Status = Status.OFFLINE:
	set(value):
		if status == value:
			return
		status = value
		status_changed.emit(value)

var last_error := "":
	set(value):
		if last_error == value:
			return
		last_error = value
		error_changed.emit(value)

## Cross-cutting UI flag: when true, systems that capture the mouse (camera
## rig, loading screen) must release it and not recapture until cleared.
## Written by LeaveInput and the loading screen; read by CameraRig and any
## other mouse-capturing system. The dependency direction is correct: player
## depends on net, never the reverse.
var mouse_capture_blocked := false:
	set(value):
		if mouse_capture_blocked == value:
			return
		mouse_capture_blocked = value
		mouse_capture_blocked_changed.emit(value)

## Multiplayer unique id of this process (0 while offline).
var local_peer_id := 0

## Remote peers currently connected (server-side authority list).
var peers: PackedInt32Array = PackedInt32Array()

# --- Read helpers ------------------------------------------------------------

func is_online() -> bool:
	return role != Role.OFFLINE

func is_host() -> bool:
	return role == Role.HOST or role == Role.DEDICATED

func is_dedicated() -> bool:
	return role == Role.DEDICATED

# --- Mutators (SessionController only) ----------------------------------------

func add_peer(peer_id: int) -> void:
	if peers.has(peer_id):
		return
	peers.append(peer_id)
	peer_joined.emit(peer_id)

func remove_peer(peer_id: int) -> void:
	var index := peers.find(peer_id)
	if index == -1:
		return
	peers.remove_at(index)
	peer_left.emit(peer_id)

## Resets every field to the offline baseline (after leave / disconnect).
func reset() -> void:
	peers = PackedInt32Array()
	local_peer_id = 0
	mouse_capture_blocked = false
	pending_role = Role.OFFLINE
	role = Role.OFFLINE
	status = Status.OFFLINE

func notify_session_started() -> void:
	session_started.emit()

func notify_session_ended() -> void:
	session_ended.emit()
