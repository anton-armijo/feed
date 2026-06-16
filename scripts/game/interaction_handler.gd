## Project-specific click-to-interact raycaster for the multiplayer system.
## Lives in the GameLayer and runs only on the local (authority) peer.
## Reads the player through the blackboard and exported references.
extends GameLayer

@export var blackboard: PlayerBlackboard
@export var player_body: CharacterBody3D
@export var interaction_distance: float = 500.0

@export var draw_debug: bool = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			interact()

func interact() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos := Vector2()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_pos = get_viewport().size / 2
	else:
		mouse_pos = get_viewport().get_mouse_position()

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * interaction_distance

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _collect_player_rids()

	var result := get_viewport().get_world_3d().direct_space_state.intersect_ray(query)

	var debug_ray_color: Color = Color.GREEN
	if result.is_empty():
		debug_ray_color = Color.RED
	elif result.collider.has_method("sv_interact"):
		debug_ray_color = Color.REBECCA_PURPLE
		interact_with(result.collider)

	if draw_debug:
		_draw_debug_ray(from, to, debug_ray_color)

func interact_with(object: Node) -> void:
	var peer_id := multiplayer.get_unique_id()

	if multiplayer.is_server():
		object.sv_interact(peer_id)

	if multiplayer.multiplayer_peer != null:
		object._rpc_interact.rpc(peer_id)

func _collect_player_rids() -> Array:
	var rids: Array = []
	for player in get_tree().get_nodes_in_group("players"):
		if player is CollisionObject3D:
			rids.append(player.get_rid())
	return rids

func _draw_debug_ray(from: Vector3, to: Vector3, color: Color, duration: float = 1.0) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.top_level = true
	line.global_transform = Transform3D.IDENTITY

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	line.material_override = material

	get_tree().current_scene.add_child(line)

	await get_tree().create_timer(duration).timeout
	line.queue_free()
