extends Node
class_name StairStepperComponent

@export var max_step_up           := 0.5
@export var step_check_iterations := 6
@export var min_horizontal_motion := 0.001

@export var player_manager: PlayerManager
@export var player: CharacterBody3D

var was_grounded := true
var is_grounded  := true
var step_down_timer := 0.0

func _ready() -> void:
	if not player: player = get_parent() as CharacterBody3D
	if not player_manager: player_manager = player.get_node("PlayerManager") if player else null


func update_grounded(delta: float) -> void:
	was_grounded = is_grounded
	is_grounded  = player.is_on_floor()
	
	# Small delay to prevent animation flickering when stepping down
	if step_down_timer > 0.0:
		step_down_timer -= delta
		return
	
	if is_grounded or not was_grounded:
		player_manager.is_stepping_down = false

func step_up(horizontal_motion: Vector3) -> void:
	player_manager.is_stepping = false
	if not player.is_on_floor():
		return
	if horizontal_motion.length_squared() < min_horizontal_motion * min_horizontal_motion:
		return

	var params := PhysicsTestMotionParameters3D.new()
	var result := PhysicsTestMotionResult3D.new()
	params.margin = 0.001

	params.from   = player.global_transform
	params.motion = horizontal_motion
	if not PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
		return

	for i in range(1, step_check_iterations + 1):
		var step_height := max_step_up * float(i) / float(step_check_iterations)

		params.from   = player.global_transform
		params.motion = Vector3.UP * step_height
		if PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
			continue

		var lifted := player.global_transform.translated(Vector3.UP * step_height)
		params.from   = lifted
		params.motion = horizontal_motion
		if PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
			continue

		params.from   = lifted.translated(horizontal_motion)
		params.motion = Vector3.DOWN * (max_step_up + 0.1)
		if not PhysicsServer3D.body_test_motion(player.get_rid(), params, result):
			continue

		player.global_position = lifted.origin
		player.velocity.y      = maxf(player.velocity.y, 0.0)  # preserva salto si velocity.y > 0
		player_manager.is_stepping = true
		return

func step_down() -> void:
	if player.velocity.y > 0.0 or not was_grounded:
		return
	# Don't snap to floor when falling off a ledge (significant downward velocity)
	if player.velocity.y < -0.5:
		return
	player_manager.is_stepping_down = true
	step_down_timer = 0.1
	player.apply_floor_snap()
