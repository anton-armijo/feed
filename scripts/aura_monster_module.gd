extends Node

@export var max_step_up := 0.5
@export var step_check_iterations := 6
@export var min_horizontal_motion := 0.001

var player: CharacterBody3D
var was_grounded := true
var is_grounded := true
var is_stepping := false
var is_stepping_down := false

func _ready() -> void:
	player = get_parent() as CharacterBody3D

func update_grounded() -> void: 
	was_grounded = is_grounded
	is_grounded = player.is_on_floor()

func step_up(horizontal_motion: Vector3) -> void:
	is_stepping = false
	horizontal_motion.y = 0.0
	if not player.is_on_floor():
		return

	if horizontal_motion.length_squared() < min_horizontal_motion * min_horizontal_motion:
		return

	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()

	# First, confirm the forward motion is blocked at current height.
	params.from = player.global_transform
	params.motion = horizontal_motion
	params.margin = 0.001

	if not PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
		return

	for i in range(1, step_check_iterations + 1):
		var step_height := max_step_up * float(i) / float(step_check_iterations)

		# 1) Check that we can move upward without hitting a ceiling/overhang.
		params.from = player.global_transform
		params.motion = Vector3.UP * step_height

		if PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
			continue

		# 2) Check that from the lifted position, moving forward is clear.
		var lifted_transform := player.global_transform.translated(Vector3.UP * step_height)

		params.from = lifted_transform
		params.motion = horizontal_motion

		if PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
			continue

		# 3) Optional but recommended: make sure there is floor to land on.
		params.from = lifted_transform.translated(horizontal_motion)
		params.motion = Vector3.DOWN * (max_step_up + 0.1)

		if not PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
			continue

		player.global_position = lifted_transform.origin
		player.velocity.y = 0.0
		is_stepping = true
		return

func step_down() -> void:
	is_stepping_down = false
	if player.velocity.y > 0.0:
		return
	if not was_grounded:
		return

	is_stepping_down = true
	player.apply_floor_snap()
