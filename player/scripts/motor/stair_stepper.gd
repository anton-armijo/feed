## Detects and resolves stair steps via shape test motions.
## Self-contained: publishes its results through is_stepping /
## is_stepping_down instead of writing into a shared manager.
class_name StairStepper
extends Node

## True the frame the body was teleported up a step.
var is_stepping := false
## True while snapping down onto a step below (kept briefly to avoid flicker).
var is_stepping_down := false

var _body: CharacterBody3D
var _config: ResolvedPlayerConfig.Stair
var _was_grounded := true
var _is_grounded_raw := true
var _step_down_timer := 0.0

func setup(body: CharacterBody3D, config: ResolvedPlayerConfig.Stair) -> void:
	_body = body
	_config = config

## Must run once per physics frame, before the FSM ticks.
func update_grounded(delta: float) -> void:
	_was_grounded = _is_grounded_raw
	_is_grounded_raw = _body.is_on_floor()

	# Small delay prevents grounded-state flicker when stepping down.
	if _step_down_timer > 0.0:
		_step_down_timer -= delta
		return

	if _is_grounded_raw or not _was_grounded:
		is_stepping_down = false

func step_up(horizontal_motion: Vector3) -> void:
	is_stepping = false
	if not _body.is_on_floor():
		return
	if horizontal_motion.length_squared() < _config.min_horizontal_motion * _config.min_horizontal_motion:
		return

	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	params.margin = 0.001

	# Only attempt a step if the horizontal motion is actually blocked.
	params.from = _body.global_transform
	params.motion = horizontal_motion
	if not PhysicsServer3D.body_test_motion(_body.get_rid(), params, result):
		return

	for i in range(1, _config.step_check_iterations + 1):
		var step_height := _config.max_step_up * float(i) / float(_config.step_check_iterations)

		# 1) Is there headroom to lift the body?
		params.from = _body.global_transform
		params.motion = Vector3.UP * step_height
		if PhysicsServer3D.body_test_motion(_body.get_rid(), params, result):
			continue

		# 2) Does the horizontal motion fit once lifted?
		var lifted := _body.global_transform.translated(Vector3.UP * step_height)
		params.from = lifted
		params.motion = horizontal_motion
		if PhysicsServer3D.body_test_motion(_body.get_rid(), params, result):
			continue

		# 3) Is there a floor to land on after the step?
		params.from = lifted.translated(horizontal_motion)
		params.motion = Vector3.DOWN * (_config.max_step_up + 0.1)
		if not PhysicsServer3D.body_test_motion(_body.get_rid(), params, result):
			continue

		_body.global_position = lifted.origin
		_body.velocity.y = maxf(_body.velocity.y, 0.0)  # preserve an active jump
		is_stepping = true
		return

func step_down() -> void:
	if _body.velocity.y > 0.0 or not _was_grounded:
		return
	if _body.velocity.y < -0.5:
		return
	if _body.is_on_floor():
		return  # already snapped, nothing to do
	is_stepping_down = true
	_step_down_timer = 0.1
	_body.apply_floor_snap()
