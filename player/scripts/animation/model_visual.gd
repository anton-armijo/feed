## Presentation of the character's visual transform. Applies the gameplay yaw
## from the blackboard (plus the model's authoring rotation offset) and
## smooths vertical stair snaps. Runs on every peer: for remote players the
## blackboard values arrive through the MultiplayerSynchronizer.
class_name ModelVisual
extends Node3D

@export var height_smooth_speed := 14.0

var _bb: PlayerBlackboard
var _body: CharacterBody3D
var _initial_rotation_y := 0.0
var _initial_local_y := 0.0
var _smoother: YSmoother

func setup(blackboard: PlayerBlackboard, body: CharacterBody3D) -> void:
	_bb = blackboard
	_body = body
	_initial_rotation_y = rotation.y
	_initial_local_y = position.y
	_smoother = YSmoother.new(height_smooth_speed)

func teleport() -> void:
	if _smoother:
		_smoother.teleport()

func _process(delta: float) -> void:
	if _bb == null:
		return
	rotation.y = _initial_rotation_y + _bb.model_yaw
	_smoother.process_smoothing(delta, _body.global_position.y)
	global_position.y = _smoother.get_smoothed_y() + _initial_local_y
