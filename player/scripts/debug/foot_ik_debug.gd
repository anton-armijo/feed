class_name FootIKDebug
extends Resource

var _config: FootIKDebugConfig
var _ik_config: ResolvedPlayerConfig.FootIK

var _ik_leg_left: TwoBoneIK3D
var _ik_leg_right: TwoBoneIK3D
var _pole_left: Marker3D
var _pole_right: Marker3D
var _target_left: Marker3D
var _target_right: Marker3D
var _ray_front_left: RayCast3D
var _ray_back_left: RayCast3D
var _ray_front_right: RayCast3D
var _ray_back_right: RayCast3D

var _debug_timer := 0.0
var _debug_oscillation_history: Array[float] = []
var _debug_oscillation_frame_count := 0
var _debug_root: Node3D

var _presenter: CharacterPresenter
var _bb: PlayerBlackboard
var _body: CharacterBody3D
var _ik_y_offset: float

func set_config(
	config: FootIKDebugConfig, ik_config: ResolvedPlayerConfig.FootIK,
	presenter: CharacterPresenter, bb: PlayerBlackboard, body: CharacterBody3D
	) -> void:
	_config = config
	_ik_config = ik_config
	_presenter = presenter
	_bb = bb
	_body = body

func set_nodes(
	pole_left: Marker3D, pole_right: Marker3D,
	target_left: Marker3D, target_right: Marker3D,
	ray_front_left: RayCast3D, ray_back_left: RayCast3D,
	ray_front_right: RayCast3D, ray_back_right: RayCast3D,
	ik_leg_left: TwoBoneIK3D, ik_leg_right: TwoBoneIK3D
	):
	_pole_left = pole_left
	_pole_right = pole_right
	_target_left = target_left
	_target_right = target_right
	_ray_front_left = ray_front_left
	_ray_back_left = ray_back_left
	_ray_front_right = ray_front_right
	_ray_back_right =ray_back_right
	_ik_leg_left = ik_leg_left
	_ik_leg_right = ik_leg_right

func debug_update(delta: float, ik_y_offset: float) -> void:
	_ik_y_offset = ik_y_offset
	if _config.debug_draw_rays or _config.debug_draw_targets or _config.debug_draw_poles:
		_debug_ensure_root()
		_debug_draw()
	if _config.debug_log_frame:
		_debug_log(delta)
	if _config.debug_detect_oscillation:
		_debug_check_oscillation()


func print_calibration(calibrator: FootIKCalibrator) -> void:
	if not _config.debug_print_calibration:
		return
	var m := calibrator.metrics
	print("[FootIKController] Calibración completada:")
	print("  Pierna izq: %.3fm | der: %.3fm" % [m.left_leg_length, m.right_leg_length])
	print("  Sole offset: %.3fm | Slope thresh: %.4f" % [m.sole_offset, m.slope_threshold])
	print("  Ray: origen=%.2fm, longitud=%.2fm" % [m.ray_origin_height, m.ray_length])
	print("  Pole L: %s | Pole R: %s" % [m.pole_knee_left, m.pole_knee_right])


func _debug_ensure_root() -> void:
	if _debug_root != null and is_instance_valid(_debug_root):
		return
	if _presenter == null:
		return
	_debug_root = Node3D.new()
	_debug_root.name = "FootIKDebug"
	_debug_root.top_level = true
	_presenter.add_child(_debug_root)


func _debug_draw() -> void:
	if _config.debug_draw_rays:
		_debug_draw_leg_rays(_ray_front_left, _ray_back_left, "L")
		_debug_draw_leg_rays(_ray_front_right, _ray_back_right, "R")
	if _config.debug_draw_targets:
		_debug_draw_target(_target_left, "L", Color.CYAN)
		_debug_draw_target(_target_right, "R", Color.CYAN)
	if _config.debug_draw_poles:
		_debug_draw_sphere("PoleL", _pole_left.global_position, 0.04, Color.MAGENTA)
		_debug_draw_sphere("PoleR", _pole_right.global_position, 0.04, Color.MAGENTA)


func _debug_draw_leg_rays(ray_f: RayCast3D, ray_b: RayCast3D, suffix: String) -> void:
	_debug_draw_ray("RayF" + suffix, ray_f)
	_debug_draw_ray("RayB" + suffix, ray_b)


func _debug_draw_ray(name: String, ray: RayCast3D) -> void:
	var origin := ray.global_position
	var end := origin + ray.global_transform.basis * ray.target_position
	var hit := ray.is_colliding()
	var color := Color.GREEN if hit else Color.RED
	_debug_draw_line(name, origin, end, color)
	if hit:
		_debug_draw_sphere("Hit" + name, ray.get_collision_point(), 0.025, Color.YELLOW)


func _debug_draw_target(marker: Marker3D, suffix: String, color: Color) -> void:
	_debug_draw_sphere("Target" + suffix, marker.global_position, 0.035, color)


func _debug_log(delta: float) -> void:
	if _config.debug_log_interval > 0.0:
		_debug_timer += delta
		if _debug_timer < _config.debug_log_interval:
			return
		_debug_timer -= _config.debug_log_interval

	print(
		(
			"[FootIK] active=%s state=%s grounded=%s stepping=%s/%s y_offset=%.4f infl=L%.2f/R%.2f body_y=%.3f"
			% [
				_should_ik_be_active(),
				_bb.locomotion_state,
				_bb.is_grounded,
				_bb.is_stepping,
				_bb.is_stepping_down,
			_ik_y_offset,
			_ik_leg_left.influence if _ik_leg_left != null else 0.0,
				_ik_leg_right.influence if _ik_leg_right != null else 0.0,
				_body.global_position.y if _body != null else 0.0,
			]
		)
	)
	_debug_log_ray("L-F", _ray_front_left)
	_debug_log_ray("L-B", _ray_back_left)
	_debug_log_ray("R-F", _ray_front_right)
	_debug_log_ray("R-B", _ray_back_right)


func _debug_log_ray(label: String, ray: RayCast3D) -> void:
	var hit := ray.is_colliding()
	var point := ray.get_collision_point() if hit else Vector3.ZERO
	print(
		(
			"  ray %s hit=%s y=%.3f norm=%s"
			% [
				label,
				hit,
				point.y,
				str(ray.get_collision_normal()) if hit else "-",
			]
		)
	)


func _debug_check_oscillation() -> void:
	_debug_oscillation_history.append(_ik_y_offset)
	if _debug_oscillation_history.size() > _config.debug_oscillation_history_size:
		_debug_oscillation_history.remove_at(0)
	if _debug_oscillation_history.size() < _config.debug_oscillation_history_size:
		return

	var direction_changes := 0
	var prev_sign := signf(_debug_oscillation_history[1] - _debug_oscillation_history[0])
	for i in range(2, _debug_oscillation_history.size()):
		var cur_sign := signf(_debug_oscillation_history[i] - _debug_oscillation_history[i - 1])
		if cur_sign != 0.0 and prev_sign != 0.0 and cur_sign != prev_sign:
			direction_changes += 1
		prev_sign = cur_sign if cur_sign != 0.0 else prev_sign

	var min_y := _debug_oscillation_history[0]
	var max_y := _debug_oscillation_history[0]
	for v in _debug_oscillation_history:
		min_y = minf(min_y, v)
		max_y = maxf(max_y, v)
	var range_y := max_y - min_y

	if direction_changes >= _config.debug_oscillation_min_frames and range_y > _config.debug_oscillation_threshold:
		_debug_oscillation_frame_count += 1
		push_warning(
			(
				"[FootIK] Oscilación detectada: cambios=%d rango=%.4f en %d frames (conteo=%d)"
				% [
					direction_changes,
					range_y,
					_debug_oscillation_history.size(),
					_debug_oscillation_frame_count
				]
			)
		)
	else:
		_debug_oscillation_frame_count = 0


func _debug_draw_line(name: String, a: Vector3, b: Vector3, color: Color) -> void:
	var node_name := "DebugLine_" + name
	var mi := _debug_root.get_node_or_null(node_name) as MeshInstance3D
	var mesh: ImmediateMesh
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = node_name
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_debug_root.add_child(mi)
		mesh = ImmediateMesh.new()
		mi.mesh = mesh
	else:
		mesh = mi.mesh as ImmediateMesh
		mesh.clear_surfaces()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)
	mesh.surface_end()


func _debug_draw_sphere(name: String, pos: Vector3, radius: float, color: Color) -> void:
	var node_name := "DebugSphere_" + name
	var mi := _debug_root.get_node_or_null(node_name) as MeshInstance3D
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = node_name
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sphere := SphereMesh.new()
		sphere.radius = radius
		sphere.height = radius * 2.0
		mi.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.alpha_scissor_threshold = 0.1
		mi.material_override = mat
		_debug_root.add_child(mi)
	mi.global_position = pos

func _debug_cleanup() -> void:
	if _debug_root != null and is_instance_valid(_debug_root):
		_debug_root.queue_free()
		_debug_root = null

func _should_ik_be_active() -> bool:
	if _ik_config.ik_always_on:
		return true
	# Stepping overrides: always IK during stair transitions, even if the
	# body briefly leaves the floor mid step-up — the feet must stay planted
	# on the steps. This must run before the grounded check below.
	if _bb.is_stepping or _bb.is_stepping_down:
		return true
	if not _bb.is_grounded:
		return false
	return _active_for_state(_bb.locomotion_state)


func _active_for_state(state: StringName) -> bool:
	match state:
		&"Idle":
			return true
		&"Walk", &"Land":
			return _ik_config.ik_during_walk
		&"Run":
			return _ik_config.ik_during_run
		_:
			return false
