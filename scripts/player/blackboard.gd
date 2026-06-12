extends Node3D
class_name PlayerManager

enum State { IDLE, WALKING, RUNNING, JUMPING, FALLING, LANDING }

@export var body_height = 1.59

var player_id = 0
var visual_money = 0

var camera_yaw := 0.0
var shift_lock := false
var shift_lock_toggle_on := false
var first_person := false

# Datos crudos expuestos por el player
var is_grounded := true
var velocity_y := 0.0
var has_horizontal_input := false
var is_running := false
var is_stepping := false
var is_stepping_down := false

var _state: State = State.IDLE
var state: State:
	get: return _state
	set(value):
		if _state == value: return
		_state = value
		state_changed.emit(_state)

var is_window_selected := true

signal state_changed(new_state: State)
signal window_focus_changed # is window_slected: bool

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

func play_sound(sound: AudioStream, sound_position: Vector3) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.position = sound_position
	player.top_level = true
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

func play_local_sound(sound: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = sound
	add_child(player)

	player.play()
	player.finished.connect(player.queue_free)

	return player
