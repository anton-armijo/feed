## Analiza un [Skeleton3D] y calcula automáticamente todas las posiciones
## y métricas necesarias para el Foot IK: leg lengths, sole offset, pole-knee
## positions, foot-rotation offsets, raycast configuration.
##
## Se ejecuta una sola vez durante [FootIKController.presenter_setup].
## Los resultados se almacenan en [member metrics] como un diccionario plano
## que [FootIKController] consume en tiempo de ejecución.
##
## Derivación automática — reemplaza toda la configuración manual del
## repositorio original (TweakContainer, PoleKnee, TargetFoot, pos_y_height_*).
class_name FootIKCalibrator
extends RefCounted

# ──────────────────────────────────────────────────────────────────────────────
# Resultado público
# ──────────────────────────────────────────────────────────────────────────────

## Diccionario con todas las métricas calculadas. Claves:
##   left_leg_length, right_leg_length, avg_leg_length,
##   left_foot_length, right_foot_length, avg_foot_length,
##   sole_offset, hip_height, hip_separation,
##   slope_threshold,
##   pos_y_height_flat, pos_y_height_up, pos_y_height_down,
##   pole_knee_left, pole_knee_right,
##   target_foot_left, target_foot_right,
##   foot_rot_offset_left, foot_rot_offset_right,
##   ray_origin_height, ray_length, ray_back_offset, ray_front_offset,
##   left_ankle_pos, right_ankle_pos, ...
var metrics: Dictionary = {}

## Índices de huesos cacheados.
var bone_indices: Dictionary = {}

# ──────────────────────────────────────────────────────────────────────────────
# API
# ──────────────────────────────────────────────────────────────────────────────


## Ejecuta la calibración completa. Devuelve [code]true[/code] si tuvo éxito.
func calibrate(
	skeleton: Skeleton3D, bone_names: Dictionary, config: ResolvedPlayerConfig.FootIK
) -> bool:
	if skeleton == null:
		push_error("[FootIKCalibrator] skeleton es null")
		return false

	# 1. Resolver índices de huesos
	if not _resolve_bones(skeleton, bone_names):
		return false

	# 2. Leer posiciones de reposo
	var p := _read_rest_positions(skeleton)
	if p.is_empty():
		return false

	# 3. Calcular métricas de pierna
	_compute_leg_metrics(p, config)

	# 4. Calcular offsets de rotación de pie
	_compute_foot_rotation_offsets(skeleton)

	# 5. Calcular configuración de raycasts
	_compute_raycast_config(config)

	# 6. Calcular posiciones de pole knees
	_compute_pole_knee_positions(p, config)

	# 7. Calcular posiciones iniciales de targets
	_compute_target_positions(p)

	# 8. Convertir las métricas aplicadas en espacio mundo a unidades de mundo.
	#    Todas las posiciones de hueso provienen de get_bone_global_rest() en
	#    espacio LOCAL del skeleton (sin escala). Si el modelo está escalado
	#    (p. ej. el nodo Model con scale 0.55), las distancias verticales y los
	#    raycasts deben escalarse o las piernas se sobreextienden.
	_apply_world_scale(skeleton)

	return true


## Uniform world scale of the skeleton (e.g. 0.55 when the Model node scales
## the rig). Bone rest positions are scale-1 local; world-applied offsets must
## be multiplied by this.
func _world_scale(skeleton: Skeleton3D) -> float:
	var s := skeleton.global_transform.basis.get_scale()
	return (absf(s.x) + absf(s.y) + absf(s.z)) / 3.0


## Scales every metric that [FootIKController] applies in WORLD space (ray
## origin/length, horizontal ray offsets, sole/pos_y vertical offsets, slope
## threshold). Skeleton-local metrics (pole, target rest positions, leg
## lengths) are left untouched — they inherit the skeleton transform.
func _apply_world_scale(skeleton: Skeleton3D) -> void:
	var ws := _world_scale(skeleton)
	metrics.world_scale = ws
	if is_equal_approx(ws, 1.0):
		return
	for key in [
		"sole_offset",
		"pos_y_height_flat",
		"pos_y_height_up",
		"pos_y_height_down",
		"slope_threshold",
		"ray_origin_height",
		"ray_length",
		"ray_back_offset",
		"ray_front_offset",
	]:
		metrics[key] = metrics[key] * ws


# ──────────────────────────────────────────────────────────────────────────────
# Interno — Resolución de huesos
# ──────────────────────────────────────────────────────────────────────────────


func _resolve_bones(skeleton: Skeleton3D, bone_names: Dictionary) -> bool:
	var mapping := {
		left_hip_idx = bone_names.get("left_upper_leg", &"LeftUpLeg"),
		left_upper_leg_idx = bone_names.get("left_upper_leg", &"LeftUpLeg"),
		left_lower_leg_idx = bone_names.get("left_lower_leg", &"LeftLeg"),
		left_foot_idx = bone_names.get("left_foot", &"LeftFoot"),
		left_toe_idx = bone_names.get("left_toe", &"LeftToeBase"),
		right_hip_idx = bone_names.get("right_upper_leg", &"RightUpLeg"),
		right_upper_leg_idx = bone_names.get("right_upper_leg", &"RightUpLeg"),
		right_lower_leg_idx = bone_names.get("right_lower_leg", &"RightLeg"),
		right_foot_idx = bone_names.get("right_foot", &"RightFoot"),
		right_toe_idx = bone_names.get("right_toe", &"RightToeBase"),
		hips_idx = bone_names.get("hips", &"Hips"),
	}

	for key in mapping:
		var bone_name: StringName = mapping[key]
		var idx: int = skeleton.find_bone(bone_name)
		if idx == -1:
			push_error("[FootIKCalibrator] Hueso no encontrado: %s (clave %s)" % [bone_name, key])
			return false
		bone_indices[key] = idx

	return true


func _read_rest_positions(skeleton: Skeleton3D) -> Dictionary:
	var pos_map := {
		left_hip = "left_upper_leg_idx",
		left_knee = "left_lower_leg_idx",
		left_ankle = "left_foot_idx",
		left_toe = "left_toe_idx",
		right_hip = "right_upper_leg_idx",
		right_knee = "right_lower_leg_idx",
		right_ankle = "right_foot_idx",
		right_toe = "right_toe_idx",
		hips = "hips_idx",
	}
	var p := {}
	for pos_key in pos_map:
		var idx_key: String = pos_map[pos_key]
		if not bone_indices.has(idx_key):
			return {}
		p[pos_key] = skeleton.get_bone_global_rest(bone_indices[idx_key]).origin
	return p


func _compute_leg_metrics(p: Dictionary, config: ResolvedPlayerConfig.FootIK) -> void:
	var l_thigh: float = p.left_hip.distance_to(p.left_knee)
	var l_shin: float = p.left_knee.distance_to(p.left_ankle)
	var l_leg: float = l_thigh + l_shin
	var l_foot: float = p.left_ankle.distance_to(p.left_toe)

	var r_thigh: float = p.right_hip.distance_to(p.right_knee)
	var r_shin: float = p.right_knee.distance_to(p.right_ankle)
	var r_leg: float = r_thigh + r_shin
	var r_foot: float = p.right_ankle.distance_to(p.right_toe)

	var avg_leg := (l_leg + r_leg) * 0.5
	var avg_foot := (l_foot + r_foot) * 0.5

	# Sole offset: distancia vertical ankle → toe
	var l_sole := absf(p.left_ankle.y - p.left_toe.y)
	var r_sole := absf(p.right_ankle.y - p.right_toe.y)
	var avg_sole := (l_sole + r_sole) * 0.5
	if avg_sole < 0.001:
		avg_sole = avg_foot * 0.15  # Fallback

	var hip_h = p.hips.y
	var hip_sep = p.left_hip.distance_to(p.right_hip)

	(
		metrics
		. merge(
			{
				left_thigh_length = l_thigh,
				left_shin_length = l_shin,
				left_leg_length = l_leg,
				left_foot_length = l_foot,
				left_sole_offset = l_sole,
				right_thigh_length = r_thigh,
				right_shin_length = r_shin,
				right_leg_length = r_leg,
				right_foot_length = r_foot,
				right_sole_offset = r_sole,
				avg_leg_length = avg_leg,
				avg_foot_length = avg_foot,
				sole_offset = avg_sole,
				hip_height = hip_h,
				hip_separation = hip_sep,
				left_hip_pos = p.left_hip,
				left_knee_pos = p.left_knee,
				left_ankle_pos = p.left_ankle,
				left_toe_pos = p.left_toe,
				right_hip_pos = p.right_hip,
				right_knee_pos = p.right_knee,
				right_ankle_pos = p.right_ankle,
				right_toe_pos = p.right_toe,
				# Derivados automáticos (reemplazan los exports mágicos)
				slope_threshold = avg_leg * config.slope_threshold_ratio,
				pos_y_height_flat = avg_sole,
				pos_y_height_up = avg_sole * config.sole_offset_up_ratio,
				pos_y_height_down = avg_sole * config.sole_offset_down_ratio,
			}
		)
	)


func _compute_foot_rotation_offsets(skeleton: Skeleton3D) -> void:
	# The offset is simply the foot bone's rest rotation. The modifier
	# replaces the bone rotation with surface_alignment * offset. For flat
	# ground surface_alignment=identity, so the foot ends up at its rest
	# orientation. For slopes the surface_alignment rotates the foot
	# relative to rest.
	var l_rest := skeleton.get_bone_global_rest(bone_indices.left_foot_idx).basis
	var r_rest := skeleton.get_bone_global_rest(bone_indices.right_foot_idx).basis
	metrics.foot_rot_offset_left = l_rest.orthonormalized().get_rotation_quaternion()
	metrics.foot_rot_offset_right = r_rest.orthonormalized().get_rotation_quaternion()


func _compute_raycast_config(config: ResolvedPlayerConfig.FootIK) -> void:
	var avg_sole: float = metrics.sole_offset
	var avg_foot: float = metrics.avg_foot_length
	var hip_h: float = metrics.hip_height

	var ray_origin_h := hip_h * config.ray_origin_height_ratio
	var ray_len := ray_origin_h + avg_sole + config.ray_ground_margin

	metrics.ray_origin_height = ray_origin_h
	metrics.ray_length = ray_len
	metrics.ray_back_offset = avg_foot * config.ray_back_foot_ratio
	metrics.ray_front_offset = avg_foot * config.ray_front_foot_ratio


func _compute_pole_knee_positions(p: Dictionary, config: ResolvedPlayerConfig.FootIK) -> void:
	var fwd_scale: float = metrics.avg_leg_length * config.pole_forward_ratio

	# Derive the character's forward direction from the foot bones (ankle →
	# toe). This works regardless of whether the rig uses Godot (-Z) or
	# Blender/Unity (+Z) forward convention.
	var l_foot_fwd = p.left_toe - p.left_ankle
	var r_foot_fwd = p.right_toe - p.right_ankle
	l_foot_fwd.y = 0.0
	r_foot_fwd.y = 0.0
	var char_fwd = ((l_foot_fwd + r_foot_fwd) * 0.5).normalized()
	if char_fwd.length_squared() < 0.0001:
		char_fwd = Vector3(0, 0, -1)

	metrics.pole_knee_left = _single_pole_knee(
		p.left_hip, p.left_knee, p.left_ankle, fwd_scale, config.pole_y_offset, char_fwd
	)
	metrics.pole_knee_right = _single_pole_knee(
		p.right_hip, p.right_knee, p.right_ankle, fwd_scale, config.pole_y_offset, char_fwd
	)


func _single_pole_knee(
	hip_pos: Vector3,
	knee_pos: Vector3,
	ankle_pos: Vector3,
	forward_offset: float,
	y_offset: float,
	char_fwd: Vector3
) -> Vector3:
	var leg_dir := (ankle_pos - hip_pos).normalized()
	# Project the character's forward direction onto the plane perpendicular to
	# the leg. This keeps the pole in front of the knee regardless of how the
	# rest-pose legs are rotated, avoiding the sideways-pole problem from the
	# old cross-product derivation.
	var knee_fwd := (char_fwd - leg_dir * char_fwd.dot(leg_dir)).normalized()
	var pole := knee_pos + knee_fwd * forward_offset
	pole.y += y_offset
	return pole


func _compute_target_positions(p: Dictionary) -> void:
	metrics.target_foot_left = p.left_ankle
	metrics.target_foot_right = p.right_ankle
