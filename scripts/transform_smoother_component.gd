extends Node
class_name TransformSmootherComponent

@export var target_node: Node3D
@export var smooth_speed := 14.0

var _smoothed_y := 0.0
var _initial_y := 0.0
var _first_frame := true

func _ready() -> void:
	pass

func process_smoothing(delta: float, follow_target_y: float) -> void:
	if _first_frame:
		_smoothed_y = follow_target_y
		_first_frame = false
		
	_smoothed_y = lerpf(_smoothed_y, follow_target_y, smooth_speed * delta)

func get_stair_offset(follow_target_y: float) -> float:
	return _smoothed_y - follow_target_y

func get_smoothed_y() -> float:
	return _smoothed_y

func teleport() -> void:
	_first_frame = true
