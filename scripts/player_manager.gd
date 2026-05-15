extends Node3D

enum State { IDLE, WALKING, RUNNING, JUMPING, FALLING, LANDING }

var camera_yaw := 0.0
var shift_lock := false
var shift_lock_toggle_on := false
var first_person := false

# Datos crudos expuestos por el player
var is_grounded := true
var velocity_y := 0.0
var has_horizontal_input := false
var is_running := false

# Estado lógico — ahora lo escribe el AnimationTree, no el player
var _state: State = State.IDLE
var state: State:
	get: return _state
	set(value):
		if _state == value: return
		_state = value
		state_changed.emit(_state)

var is_window_selected := true

signal state_changed(new_state: State)
signal window_focus_changed

func _ready() -> void:
	get_window().focus_exited.connect(_on_focus_lost)
	get_window().focus_entered.connect(_on_focus_gained)

func _on_focus_lost():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	is_window_selected = false
	window_focus_changed.emit(false)

func _on_focus_gained():
	is_window_selected = true
	window_focus_changed.emit(true)

func play_sound(sound: AudioStream, sound_position: Vector3):
	var player = AudioStreamPlayer3D.new()
	player.stream = sound
	player.position = sound_position
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
