extends Node3D

@export var camera_controller: CameraController
@export var interaction_distance: float = 500.0

const draw_debug: bool = false

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			interact()

func _process(delta: float) -> void:
	pass

func interact():
	if camera_controller.is_first_person():
		return
	var viewport := get_viewport()
	var mouse_pos := Vector2()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_pos = viewport.size / 2
	else:
		mouse_pos = viewport.get_mouse_position()

	var from: Vector3 = camera_controller.camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera_controller.camera.project_ray_normal(mouse_pos) * interaction_distance 

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var player := get_parent()
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	var debug_ray_color: Color = Color.GREEN
	if result.is_empty():
		debug_ray_color = Color.RED
	elif result.collider.get_parent().has_method("sv_interact"):
		debug_ray_color = Color.REBECCA_PURPLE
		interact_with(result.collider.get_parent(), get_parent())
			
	if draw_debug:
		_draw_debug_ray(from, to, debug_ray_color)


func interact_with(object: Node, player: Player) -> void:
	GameBridge.request_interact(object, player.player_manager.player_id)
	player.player_manager.play_local_sound(object.click_sound)


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
