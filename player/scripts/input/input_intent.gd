## A frame's worth of *intent*: what the controlling agent wants the character
## to do. Filled by an input source (local InputCollector today, network or AI
## driver tomorrow) and consumed by the FSM/motor. Holding intent in a plain
## data object is what keeps physical execution decoupled from device input.
class_name InputIntent
extends RefCounted

## Raw 2D move input (x = left/right, y = forward/back), unrotated.
var move_dir := Vector2.ZERO
## World-space, camera-relative, normalized move direction on the XZ plane.
var wish_dir := Vector3.ZERO
var run_held := false
var jump_held := false

var _jump_buffer := 0.0

func tick(delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)

func buffer_jump(duration: float) -> void:
	_jump_buffer = duration

## True while a recent jump press is buffered. The FSM decides whether the
## jump is actually allowed (floor / coyote validation) and then consumes it.
func has_buffered_jump() -> bool:
	return _jump_buffer > 0.0

func consume_jump() -> void:
	_jump_buffer = 0.0

func clear() -> void:
	move_dir = Vector2.ZERO
	wish_dir = Vector3.ZERO
	run_held = false
	jump_held = false
