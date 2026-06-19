## Resets bodies that fall below a Y threshold back to a safe position.
## Uses the player's last_safe_position (published to the blackboard when
## grounded) as the primary reset target. Falls back to a raycast-upward
## grid search around the last safe position if no safe position is known.
##
## Does NOT use collision detection (Area3D body_entered) — instead it polls
## the Y coordinate of bodies in the "players" group each physics frame. This
## avoids depending on the Player class directly (character-agnostic).
extends Node3D

@export var fall_threshold_y: float = -10.0
@export var grid_search_radius: int = 5
@export var grid_step: float = 2.0
@export var raycast_up_height: float = 50.0
@export_flags_3d_physics var collision_mask: int = 1


func _physics_process(_delta: float) -> void:
	for body in get_tree().get_nodes_in_group("players"):
		if not body is CharacterBody3D:
			continue
		if body.global_position.y < fall_threshold_y:
			_reset_body(body)


func _reset_body(body: CharacterBody3D) -> void:
	var target := _find_safe_position(body)
	body.global_position = target + Vector3.UP * 0.5
	if body.velocity:
		body.velocity = Vector3.ZERO


## Primary: the last safe position published by the player to its blackboard.
## Fallback: raycast upward from grid points around the last safe position
## (or the origin if no safe position is known) to find solid ground.
func _find_safe_position(body: CharacterBody3D) -> Vector3:
	var safe := _get_last_safe_position(body)
	if safe != Vector3.ZERO:
		return safe

	# Grid search: raycast downward from above to find solid floor near origin.
	var origin := Vector3.ZERO
	for x in range(-grid_search_radius, grid_search_radius + 1):
		for z in range(-grid_search_radius, grid_search_radius + 1):
			var point := origin + Vector3(x * grid_step, raycast_up_height, z * grid_step)
			var hit := _raycast_down(point)
			if hit:
				return hit
	return Vector3(0, 2, 0)


## Reads the player's last_safe_position from its blackboard if it has one.
## Uses duck-typing (get_node_or_null) to stay character-agnostic.
func _get_last_safe_position(body: CharacterBody3D) -> Vector3:
	var bb := body.get_node_or_null("Blackboard")
	if bb == null:
		return Vector3.ZERO
	if "last_safe_position" in bb:
		return bb.last_safe_position
	return Vector3.ZERO


## Raycasts straight down from `from` and returns the hit point, or
## Vector3.ZERO if no floor is found.
func _raycast_down(from: Vector3) -> Vector3:
	var params := PhysicsRayQueryParameters3D.new()
	params.from = from
	params.to = from - Vector3.UP * (raycast_up_height + 10.0)
	params.collision_mask = collision_mask
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(params)
	if hit and hit.has("position"):
		return hit["position"]
	return Vector3.ZERO
