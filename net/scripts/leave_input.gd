## Input layer for the session: translates the "ui_cancel" (escape) action into
## a leave request while online. Isolated in its own node so the leave gesture
## can be rebound or swapped without touching session logic. Disabled on
## dedicated servers, which have no local player.
class_name LeaveInput
extends Node

var _session: SessionController
var _state: NetState

func setup(session: SessionController, state: NetState) -> void:
	_session = session
	_state = state

func _unhandled_input(event: InputEvent) -> void:
	if _state == null or _state.is_dedicated():
		return
	if not _state.is_online():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_session.leave()
