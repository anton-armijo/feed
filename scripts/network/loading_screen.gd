## Loading overlay: a self-driven observer of the session. It reacts to NetState
## (status text + fade-out when the session goes live) instead of being poked by
## the network code. The hold/release API lets a sibling (the maze size picker)
## delay the fade until the host has chosen the maze size.
extends CanvasLayer

signal pre_fade
signal fade_completed

@export var delay := 1.5
@export var fade_duration := 0.5

var _label: Label = null
var _fade_timer: SceneTreeTimer = null
var _hold_count: int = 0
var _fade_pending: bool = false

func _ready() -> void:
	if NetSession.state.is_dedicated():
		queue_free()
		return

	CameraRig.block_mouse_capture = true

	_label = $ColorRect/Label

	NetSession.state.status_changed.connect(_on_status_changed)
	NetSession.state.session_started.connect(start_fade_out)
	_on_status_changed(NetSession.state.status)

func _on_status_changed(status: NetState.Status) -> void:
	match status:
		NetState.Status.CONNECTING:
			set_status("Estableciendo conexion...")
		NetState.Status.CONNECTED:
			set_status("Conectado")

func set_status(text: String) -> void:
	if _label:
		_label.text = text

func hold() -> void:
	_hold_count += 1

func release() -> void:
	_hold_count -= 1
	if _hold_count <= 0:
		_hold_count = 0
		if _fade_pending:
			_fade_pending = false
			_start_fade_timer()

func start_fade_out() -> void:
	pre_fade.emit()
	if _hold_count > 0:
		_fade_pending = true
		return
	_start_fade_timer()

func _start_fade_timer() -> void:
	if _fade_timer:
		return
	_fade_timer = get_tree().create_timer(delay)
	_fade_timer.timeout.connect(_fade_out)

func _fade_out() -> void:
	CameraRig.block_mouse_capture = false
	var rect: ColorRect = $ColorRect
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, fade_duration)
	tween.tween_callback(func(): fade_completed.emit(); queue_free())
