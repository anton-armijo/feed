## Input layer: translates device input into an InputIntent once per physics
## frame. This is the ONLY gameplay script allowed to read Input for movement.
## It owns the jump buffer and the window-focus gate; it never touches
## velocity, state or animation. Swap this node out for a network/AI driver
## and the rest of the controller keeps working untouched.
class_name InputCollector
extends Node

var intent := InputIntent.new()

## When non-null, replaces device input entirely (cutscenes, AI, remote peer).
## Set via PlayerApi.inject_intent(). While set, collect() does NOT read Input.
var injected_intent: InputIntent = null

var _bb: PlayerBlackboard
var _jump_buffer_time := 0.1

func setup(blackboard: PlayerBlackboard, resolved: ResolvedPlayerConfig) -> void:
	_bb = blackboard
	_jump_buffer_time = resolved.jump.jump_buffer_time
	get_window().focus_exited.connect(_on_focus_changed.bind(false))
	get_window().focus_entered.connect(_on_focus_changed.bind(true))

## Called by the Player coordinator at the start of every physics frame.
func collect(delta: float) -> void:
	intent.tick(delta)

	if injected_intent != null:
		intent.move_dir = injected_intent.move_dir
		intent.wish_dir = injected_intent.wish_dir
		intent.run_held = injected_intent.run_held
		intent.jump_held = injected_intent.jump_held
		if injected_intent.has_buffered_jump():
			intent.buffer_jump(_jump_buffer_time)
			injected_intent.consume_jump()
		return

	if not _bb.input_enabled:
		intent.clear()
		return

	intent.move_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)

	intent.wish_dir = Vector3.ZERO
	if intent.move_dir.length_squared() > 0.001:
		intent.wish_dir = Vector3(intent.move_dir.x, 0.0, intent.move_dir.y) \
			.rotated(Vector3.UP, _bb.camera_yaw).normalized()

	intent.run_held = Input.is_action_pressed("run")
	intent.jump_held = Input.is_action_pressed("jump")

	if Input.is_action_just_pressed("jump"):
		intent.buffer_jump(_jump_buffer_time)

func _on_focus_changed(focused: bool) -> void:
	_bb.input_enabled = focused
