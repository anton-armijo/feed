## Small utility that smooths a vertical coordinate over time. Used by the
## presentation layers (model, camera) to hide the instant Y snaps produced by
## stair stepping. Pure math, no node dependencies.
class_name YSmoother
extends RefCounted

var smooth_speed := 14.0

var _smoothed_y := 0.0
var _first_frame := true

func _init(speed := 14.0) -> void:
	smooth_speed = speed

func process_smoothing(delta: float, target_y: float) -> void:
	if _first_frame:
		_smoothed_y = target_y
		_first_frame = false
	_smoothed_y = lerpf(_smoothed_y, target_y, smooth_speed * delta)

func get_smoothed_y() -> float:
	return _smoothed_y

## Offset between the smoothed and the real Y (useful for local-space nodes).
func get_offset(target_y: float) -> float:
	return _smoothed_y - target_y

func teleport() -> void:
	_first_frame = true
