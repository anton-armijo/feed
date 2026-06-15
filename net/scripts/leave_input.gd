## Input layer for the session: translates the "ui_cancel" (escape) action into
## a leave request while online. First Escape releases the mouse; second Escape
## (or first if the mouse is already free) leaves the session. Clicking while
## the mouse is released recaptures and cancels the leave.
class_name LeaveInput
extends Node

var _session: SessionController
var _state: NetState
var _escape_pressed := false

func setup(session: SessionController, state: NetState) -> void:
	_session = session
	_state = state

func _input(event: InputEvent) -> void:
	if _state == null or _state.is_dedicated():
		return
	if not _state.is_online():
		return

	if _escape_pressed:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			CameraRig.block_mouse_capture = false
			_escape_pressed = false
			_session.leave()
		elif event is InputEventMouseButton and event.pressed \
				and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
			CameraRig.block_mouse_capture = false
			_escape_pressed = false
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			CameraRig.block_mouse_capture = true
			_escape_pressed = true
		else:
			_session.leave()
