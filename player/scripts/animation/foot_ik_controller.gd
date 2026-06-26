## Procedural foot IK component that lives as a child of the character scene
## (e.g. under [TetoPresenter]). Discovered automatically by
## [CharacterPresenter._setup_child_nodes] via the [method presenter_setup]
## protocol — no manual wiring required in [Player].
##
## Reads the [PlayerBlackboard] for gameplay state and the [Skeleton3D] for
## geometry, then creates TwoBoneIK3D modifiers, BoneAttachment3D-raycasts,
## pole markers, and optional CopyTransformModifier3D foot-rotation modifiers
## at runtime. Everything is auto-calibrated by [FootIKCalibrator]; switching
## character models requires zero manual retuning.
##
## Hip lowering: instead of moving [code]visual_for_IK.position.y[/code]
## directly (which would fight [ModelVisual]), this controller publishes an
## [member ik_y_offset] that [ModelVisual] blends into its Y smoothing.
##
## Usage in a character scene (e.g. teto_presenter.tscn):
##   [code]Add a FootIKController node as a child of the presenter root.[/code]
##
## Bone-name overrides are exposed as exports so different rigs can be
## accommodated without subclassing.
class_name FootIKController
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# Exports — Bone name overrides (adjust per rig)
# ──────────────────────────────────────────────────────────────────────────────

@export_group("Bone Names")
@export var bone_left_upper_leg: StringName = &"LeftUpperLeg"
@export var bone_left_lower_leg: StringName = &"LeftLowerLeg"
@export var bone_left_foot: StringName = &"LeftFoot"
@export var bone_left_toe: StringName = &"LeftToes"
@export var bone_right_upper_leg: StringName = &"RightUpperLeg"
@export var bone_right_lower_leg: StringName = &"RightLowerLeg"
@export var bone_right_foot: StringName = &"RightFoot"
@export var bone_right_toe: StringName = &"RightToes"
@export var bone_hips: StringName = &"Hips"

@export_group("Debug")
@export var debug_config: FootIKDebugConfig

# ──────────────────────────────────────────────────────────────────────────────
# State — injected by presenter_setup
# ──────────────────────────────────────────────────────────────────────────────

var _bb: PlayerBlackboard
var _skeleton: Skeleton3D
var _presenter: CharacterPresenter
var _config: FootIKConfig

# ──────────────────────────────────────────────────────────────────────────────
# State — calibration
# ──────────────────────────────────────────────────────────────────────────────

var _calibrator: FootIKCalibrator
var _is_calibrated := false

# ──────────────────────────────────────────────────────────────────────────────
# State — runtime nodes created by this controller
# ──────────────────────────────────────────────────────────────────────────────

var _ik_leg_left: TwoBoneIK3D
var _ik_leg_right: TwoBoneIK3D
var _pole_left: Marker3D
var _pole_right: Marker3D
var _target_left: Marker3D
var _target_right: Marker3D
var _bone_attach_left: BoneAttachment3D
var _bone_attach_right: BoneAttachment3D
var _ray_front_left: RayCast3D
var _ray_back_left: RayCast3D
var _ray_front_right: RayCast3D
var _ray_back_right: RayCast3D
var _copy_rot_left: SkeletonModifier3D
var _copy_rot_right: SkeletonModifier3D
var _target_rot_left: Marker3D
var _target_rot_right: Marker3D

# ──────────────────────────────────────────────────────────────────────────────
# State — runtime IK values
# ──────────────────────────────────────────────────────────────────────────────

var _last_offset_left: float = 0.0
var _last_offset_right: float = 0.0
var _was_ik_active := false

# Per-leg ray hysteresis: keep using the last valid hit for a few frames after
# the ray loses contact, so the foot doesn't snap off a step edge mid-stride.
var _last_hit_y_left: float = 0.0
var _last_hit_y_right: float = 0.0
var _last_height_diff_left: float = 0.0
var _last_height_diff_right: float = 0.0
var _last_pos_y_left: float = 0.0
var _last_pos_y_right: float = 0.0
var _miss_frames_left := 0
var _miss_frames_right := 0

# Cached from calibrator for runtime constraints
var _left_hip_idx: int = -1
var _right_hip_idx: int = -1
var _left_leg_length: float = 0.0
var _right_leg_length: float = 0.0

## Y offset (metres) to lower the body for hip adjustment on slopes.
## [ModelVisual] reads this and blends it into its Y smoothing.
var ik_y_offset: float = 0.0
var _debug: FootIKDebug
# ──────────────────────────────────────────────────────────────────────────────
# Auto-discovery entry point
# ──────────────────────────────────────────────────────────────────────────────


## Called by [CharacterPresenter._setup_child_nodes] for auto-discovery.
## Receives the same [PlayerBlackboard] and [PlayerConfig] that every
## presenter-level component receives.
func presenter_setup(bb: PlayerBlackboard, config: PlayerConfig) -> void:
	_bb = bb
	_config = config.foot_ik

	if _bb == null or _config == null:
		push_warning("[FootIKController] Invalid Player setup")
		set_physics_process(false)
		return

	# Get the skeleton from the presenter
	_presenter = _find_presenter()
	if _presenter == null:
		push_warning("[FootIKController] No CharacterPresenter found in ancestors")
		set_physics_process(false)
		return

	_skeleton = _presenter.get_skeleton()
	if _skeleton == null:
		push_warning(
			"[FootIKController] Presenter returned null skeleton (get_skeleton not overridden?)"
		)
		set_physics_process(false)
		return

	# Setup Debug
	_debug = FootIKDebug.new()
	_debug.set_config(debug_config, _config, _presenter, _bb, _get_body())

	# Build IK nodes, calibrate, and start processing
	_build_nodes()
	_calibrate()
	set_physics_process(true)

	# Connect blackboard signals for reactive decisions
	_bb.state_changed.connect(_on_state_changed)
	_bb.grounded_changed.connect(_on_grounded_changed)
	_bb.landed.connect(_on_landed)


func _exit_tree() -> void:
	_debug._debug_cleanup()


# ──────────────────────────────────────────────────────────────────────────────
# Physics processing
# ──────────────────────────────────────────────────────────────────────────────


func _physics_process(delta: float) -> void:
	if not _is_calibrated or _bb == null or _config == null:
		return

	var should_ik := _should_ik_be_active()
	_ik_leg_left.active = should_ik
	_ik_leg_right.active = should_ik

	if should_ik:
		_update_ray_transforms()

		_ray_front_left.force_raycast_update()
		_ray_back_left.force_raycast_update()
		_ray_front_right.force_raycast_update()
		_ray_back_right.force_raycast_update()

		_last_offset_left = _process_leg_ik(
			_ray_front_left,
			_ray_back_left,
			_bone_attach_left,
			_target_left,
			_ik_leg_left,
			true,
			delta
		)
		_last_offset_right = _process_leg_ik(
			_ray_front_right,
			_ray_back_right,
			_bone_attach_right,
			_target_right,
			_ik_leg_right,
			false,
			delta
		)
		_compute_body_offset(delta)
		if _config.foot_rotation_enabled:
			_process_foot_rotation_system(delta)
	else:
		ik_y_offset = lerp(ik_y_offset, 0.0, _config.body_reset_lerp_speed * delta)
		_ik_leg_left.influence = 0.0
		_ik_leg_right.influence = 0.0
		if _config.foot_rotation_enabled:
			_update_copy_influence(delta, 0.0)

	# Transition signals
	if should_ik != _was_ik_active:
		_was_ik_active = should_ik

	_debug.debug_update(delta, ik_y_offset, _target_influence())


# ──────────────────────────────────────────────────────────────────────────────
# Decision logic — reads the blackboard
# ──────────────────────────────────────────────────────────────────────────────


func _should_ik_be_active() -> bool:
	# Stepping overrides: always IK during stair transitions, even if the
	# body briefly leaves the floor mid step-up — the feet must stay planted
	# on the steps. This must run before the grounded check below.
	if _bb.is_stepping or _bb.is_stepping_down:
		return true
	if not _bb.is_grounded:
		return false
	var anim: StringName = _bb.anim_state_override if not _bb.anim_state_override.is_empty() else _bb.anim_state
	return _entry_for_anim(anim) != null


func _target_influence() -> float:
	var anim: StringName = _bb.anim_state_override if not _bb.anim_state_override.is_empty() else _bb.anim_state
	var entry: AnimIKEntry = _entry_for_anim(anim)
	if entry != null and entry.profile != null:
		return _evaluate_profile(entry.profile, anim)
	return 0.0


func _entry_for_anim(anim: StringName) -> AnimIKEntry:
	var base := _resolve_base_anim(anim)
	for entry: AnimIKEntry in _config.animation_profiles:
		if entry and entry.animation_name == base and entry.profile != null:
			return entry
	# Fall back to the first profile as default for undefined animations
	if _config.animation_profiles.size() > 0:
		return _config.animation_profiles[0]
	return null

## Strips directional suffixes (_back, _left, _right) to resolve
## "walk_back" → "walk" etc., so directional variants use the base profile.
func _resolve_base_anim(anim: StringName) -> StringName:
	var s := String(anim)
	for suffix in ["_back", "_left", "_right"]:
		if s.ends_with(suffix):
			return StringName(s.trim_suffix(suffix))
	return anim

func _evaluate_profile(p: IKInfluenceProfile, anim: StringName) -> float:
	match p.mode:
		IKInfluenceProfile.Mode.CONSTANT:
			return p.constant_value
		IKInfluenceProfile.Mode.ZERO:
			return 0.0
		IKInfluenceProfile.Mode.FOOTSTEP:
			return _eval_footstep_profile(p, anim)
		IKInfluenceProfile.Mode.LAND:
			return _eval_land_profile(p, anim)
	return 1.0


func _eval_footstep_profile(p: IKInfluenceProfile, anim: StringName) -> float:
	var markers: Array = _bb.footstep_markers.get(anim, [])
	if markers.is_empty() or p.curve == null:
		return 1.0

	var dur: float = _bb.anim_lengths.get(anim, 1.0)
	var t: float = _bb.current_anim_time
	var n: int = markers.size()

	var best_idx: int = 0
	var best_abs: float = INF
	for i: int in n:
		var d: float = _cyc(t - markers[i].time, dur)
		if absf(d) < best_abs:
			best_abs = absf(d)
			best_idx = i

	var dt: float = _cyc(t - markers[best_idx].time, dur)
	var m_t: float = markers[best_idx].time

	var prev_idx: int = (best_idx - 1 + n) % n
	var next_idx: int = (best_idx + 1) % n
	var prev_t: float = markers[prev_idx].time
	var next_t: float = markers[next_idx].time

	if prev_idx >= best_idx:
		prev_t -= dur
	if next_idx <= best_idx:
		next_t += dur

	var half_before: float = (m_t - prev_t) * 0.5
	var half_after: float = (next_t - m_t) * 0.5

	var x: float = absf(dt) / maxf(
		half_before if dt <= 0.0 else half_after,
		1e-4
	)
	return p.curve.sample(clampf(x, 0.0, 1.0))


func _eval_land_profile(p: IKInfluenceProfile, anim: StringName) -> float:
	var markers: Array = _bb.footstep_markers.get(anim, [])
	if markers.is_empty() or p.curve == null:
		return 0.0

	var land_t: float = markers[0].time
	var t: float = _bb.current_anim_time

	if t < land_t:
		return 0.0

	var dur: float = _bb.anim_lengths.get(anim, 1.0)
	var x: float = (t - land_t) / maxf(dur - land_t, 1e-4)
	return p.curve.sample(clampf(x, 0.0, 1.0))


## Distancia con signo colapsada a (-dur/2, dur/2]
func _cyc(d: float, dur: float) -> float:
	while d > dur * 0.5:
		d -= dur
	while d <= -dur * 0.5:
		d += dur
	return d

func _current_lerp_speed() -> float:
	# Boost on landing
	if _bb.is_grounded and _bb.air_time < 0.15:
		return _config.land_lerp_speed
	return _config.normal_lerp_speed


# ──────────────────────────────────────────────────────────────────────────────
# Raycast transforms — re-pin each frame so rays cast straight DOWN in world
# space, positioned above the foot plus a horizontal front/back offset along
# the presenter's facing. This decouples ray direction from the foot bone's
# orientation (which points forward, not up).
# ──────────────────────────────────────────────────────────────────────────────


func _update_ray_transforms() -> void:
	var m := _calibrator.metrics
	var origin_h: float = m.ray_origin_height
	var front_off: float = m.ray_front_offset
	var back_off: float = m.ray_back_offset

	# Presenter forward (-Z), projected onto the horizontal plane.
	var fwd := -_presenter.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD

	var foot_l := _bone_attach_left.global_position
	var foot_r := _bone_attach_right.global_position
	var up := Vector3.UP * origin_h

	_ray_front_left.global_position = foot_l + up + fwd * front_off
	_ray_back_left.global_position = foot_l + up - fwd * back_off
	_ray_front_right.global_position = foot_r + up + fwd * front_off
	_ray_back_right.global_position = foot_r + up - fwd * back_off


# ──────────────────────────────────────────────────────────────────────────────
# Leg IK processing
# ──────────────────────────────────────────────────────────────────────────────


func _process_leg_ik(
	ray_f: RayCast3D,
	ray_b: RayCast3D,
	bone_attach: BoneAttachment3D,
	target_marker: Marker3D,
	ik: TwoBoneIK3D,
	is_left: bool,
	delta: float
) -> float:
	var f_hit := ray_f.is_colliding()
	var b_hit := ray_b.is_colliding()
	var miss_frames: int = _miss_frames_left if is_left else _miss_frames_right

	if not (f_hit or b_hit):
		# Grace period: keep the last valid height_diff so the body offset
		# doesn't snap to 0 the instant a foot leaves a step edge. Decay the
		# IK influence so the foot releases gradually.
		miss_frames += 1
		if is_left:
			_miss_frames_left = miss_frames
		else:
			_miss_frames_right = miss_frames
		if miss_frames > _config.ray_miss_grace_frames:
			ik.influence = lerpf(ik.influence, 0.0, _current_lerp_speed() * delta)
			return 0.0
		return _last_height_diff_left if is_left else _last_height_diff_right

	# Reset miss counter on a fresh hit.
	if is_left:
		_miss_frames_left = 0
	else:
		_miss_frames_right = 0

	var avg_hit_y: float
	var sole: float
	if f_hit and b_hit:
		var front_y := ray_f.get_collision_point().y
		var back_y := ray_b.get_collision_point().y
		sole = _calibrator.metrics.sole_offset
		if absf(front_y - back_y) > sole * _config.step_edge_sole_ratio:
			avg_hit_y = maxf(front_y, back_y)
		else:
			var wf := _config.front_ray_weight
			var low_y := minf(front_y, back_y)
			var high_y := maxf(front_y, back_y)
			avg_hit_y = lerpf(low_y, high_y, wf)
	elif f_hit:
		avg_hit_y = ray_f.get_collision_point().y
	else:
		avg_hit_y = ray_b.get_collision_point().y

	if is_left:
		_last_hit_y_left = avg_hit_y
	else:
		_last_hit_y_right = avg_hit_y

	var m := _calibrator.metrics
	var body := _get_body()
	if body == null:
		return 0.0

	var height_diff := avg_hit_y - body.global_position.y
	if is_left:
		_last_height_diff_left = height_diff
	else:
		_last_height_diff_right = height_diff

	var slope_thresh: float = m.slope_threshold
	sole = m.sole_offset

	# height_diff > 0  → foot is *below* body (stepping up)
	# height_diff < 0  → foot is *above* body (stepping down)
	# Maps [0, slope_thresh] → [flat, up] for positive
	# Maps [-slope_thresh, 0] → [down, flat] for negative
	var pos_y: float
	if height_diff > 0.0:
		var t := smoothstep(0.0, slope_thresh, height_diff)
		pos_y = lerp(sole, m.pos_y_height_up, t)
	elif height_diff < 0.0:
		var t := smoothstep(0.0, slope_thresh, -height_diff)
		pos_y = lerp(m.pos_y_height_down, sole, t)
	else:
		pos_y = sole

	if _bb.is_stepping or _bb.is_stepping_down:
		pos_y = _last_pos_y_left if is_left else _last_pos_y_right
	if is_left:
		_last_pos_y_left = pos_y
	else:
		_last_pos_y_right = pos_y

	# Set the target Y directly (no smoothing). The original repo does this
	# and it is what keeps the feet glued to the step without lag. Smoothing
	# the target Y introduces a multi-frame lag: the body snaps up via the
	# stair stepper while the foot trails behind, and the height_diff (measured
	# against the body) oscillates — producing the visible up/down bobbing on
	# stairs. The target is top_level, so its Y is already decoupled from the
	# skeleton/ik_y_offset feedback loop; no extra smoothing is needed.
	var target_y := avg_hit_y + pos_y
	# X/Z follow the animated foot (bone attachment). Y is the ray hit + sole
	# offset, in world space, independent of the skeleton.
	var foot_pos := bone_attach.global_position
	target_marker.global_position = Vector3(foot_pos.x, target_y, foot_pos.z)

	var hip_idx := _left_hip_idx if is_left else _right_hip_idx
	if hip_idx >= 0:
		var hip_world := _skeleton.global_transform * _skeleton.get_bone_global_rest(hip_idx).origin
		var to_target := target_marker.global_position - hip_world
		var max_xz: float = _calibrator.metrics.hip_separation * 0.55
		var xz_dist := Vector2(to_target.x, to_target.z).length()
		if xz_dist > max_xz:
			var scale: float = max_xz / xz_dist
			target_marker.global_position = Vector3(
				hip_world.x + to_target.x * scale,
				target_marker.global_position.y,
				hip_world.z + to_target.z * scale
			)

	if hip_idx >= 0:
		var hip_world := _skeleton.global_transform * _skeleton.get_bone_global_rest(hip_idx).origin
		var leg_length := _left_leg_length if is_left else _right_leg_length
		var max_reach := leg_length * 0.97
		var to_target := target_marker.global_position - hip_world
		if to_target.length() > max_reach:
			target_marker.global_position = hip_world + to_target.normalized() * max_reach

	ik.influence = lerpf(ik.influence, _target_influence(), _current_lerp_speed() * delta)

	return height_diff


# ──────────────────────────────────────────────────────────────────────────────
# Body offset (hip lowering) — published for ModelVisual to consume
# ──────────────────────────────────────────────────────────────────────────────


func _compute_body_offset(delta: float) -> void:
	# During stair transitions the ModelVisual's YSmoother already hides the
	# vertical snap. Measuring height_diff against the body (which jumps) and
	# then lowering the hips on top of the smoothing produces a double
	# correction that oscillates up/down every step. Suppress hip-lowering
	# while stepping and let the YSmoother own the vertical blend.
	if _bb.is_stepping or _bb.is_stepping_down:
		ik_y_offset = lerp(ik_y_offset, 0.0, _config.body_reset_lerp_speed * delta)
		return

	# When airborne (Jump/Fall) the rays can't hit the ground; the old
	# height_diff values would pull the body downward. Always reset during
	# airtime regardless of ik_always_on.
	if not _bb.is_grounded:
		ik_y_offset = lerp(ik_y_offset, 0.0, _config.body_reset_lerp_speed * delta)
		return

	# Only consider height diffs from feet that are actively planted
	# (influence > threshold). A foot in swing phase with influence near 0
	# can produce rapidly changing height_diff on stairs as its rays hit
	# different steps — that would oscillate the body offset every stride.
	var l_active := _ik_leg_left.influence > 0.1
	var r_active := _ik_leg_right.influence > 0.1
	var lowest: float
	if l_active and r_active:
		lowest = min(_last_offset_left, _last_offset_right)
	elif l_active:
		lowest = _last_offset_left
	elif r_active:
		lowest = _last_offset_right
	else:
		# Neither foot planted — reset offset
		ik_y_offset = lerp(ik_y_offset, 0.0, _config.body_reset_lerp_speed * delta)
		return

	var speed := _current_lerp_speed()

	if lowest < 0.0:
		ik_y_offset = lerp(ik_y_offset, lowest, speed * delta)
	else:
		ik_y_offset = lerp(ik_y_offset, 0.0, speed * delta)


# ──────────────────────────────────────────────────────────────────────────────
# Foot rotation system
# ──────────────────────────────────────────────────────────────────────────────


func _process_foot_rotation_system(delta: float) -> void:
	if _copy_rot_left == null:
		return

	_copy_rot_left.active = true
	_copy_rot_right.active = true

	if _bb.is_grounded and _should_ik_be_active():
		_process_foot_alignment(
			delta,
			_ray_front_left,
			_ray_back_left,
			_target_rot_left,
			_calibrator.metrics.foot_rot_offset_left
		)
		_process_foot_alignment(
			delta,
			_ray_front_right,
			_ray_back_right,
			_target_rot_right,
			_calibrator.metrics.foot_rot_offset_right
		)
		_update_copy_influence(delta, _target_influence())
	else:
		_update_copy_influence(delta, 0.0)


func _process_foot_alignment(
	delta: float,
	ray_front: RayCast3D,
	ray_back: RayCast3D,
	target_box: Marker3D,
	offset_quat: Quaternion
) -> void:
	var f_hit := ray_front.is_colliding()
	var b_hit := ray_back.is_colliding()
	if not (f_hit or b_hit):
		return

	var final_normal: Vector3
	var final_hit_y: float

	if f_hit and b_hit:
		final_normal = (
			(ray_front.get_collision_normal() + ray_back.get_collision_normal()).normalized()
		)
		final_hit_y = (ray_front.get_collision_point().y + ray_back.get_collision_point().y) / 2.0
	elif f_hit:
		final_normal = ray_front.get_collision_normal().normalized()
		final_hit_y = ray_front.get_collision_point().y
	else:
		final_normal = ray_back.get_collision_normal().normalized()
		final_hit_y = ray_back.get_collision_point().y

	# Target Y
	target_box.global_position.y = lerp(
		target_box.global_position.y, final_hit_y, delta * _config.foot_rot_y_lerp_speed
	)

	# Build basis aligned to the surface
	var visual_node: Node3D = _presenter
	var foot_fwd := -visual_node.global_transform.basis.z.normalized()
	var lateral := foot_fwd.cross(final_normal)

	if abs(foot_fwd.dot(final_normal)) > 0.99:
		lateral = visual_node.global_transform.basis.x.normalized()
	lateral = lateral.normalized()

	var fwd_z := lateral.cross(final_normal).normalized()
	var target_basis := Basis(lateral, final_normal, fwd_z).orthonormalized()

	# SLERP + auto-calibrated offset
	var target_q := target_basis.get_rotation_quaternion()
	var current_q := target_box.global_transform.basis.orthonormalized().get_rotation_quaternion()
	# Remove the offset to get the previous surface alignment, SLERP between
	# that and the new alignment, then re-apply the offset. Without this, the
	# SLERP blends a rotation that includes offset with one that doesn't,
	# causing the offset to fade in/out every frame.
	var prev_alignment := current_q * offset_quat.inverse()
	var smoothed_alignment := prev_alignment.slerp(target_q, _config.foot_rot_slerp_speed * delta)

	target_box.global_transform.basis = Basis(smoothed_alignment * offset_quat)


func _update_copy_influence(delta: float, target: float) -> void:
	if _copy_rot_left:
		_copy_rot_left.influence = lerpf(
			_copy_rot_left.influence, target, _config.foot_rot_lerp_speed * delta
		)
	if _copy_rot_right:
		_copy_rot_right.influence = lerpf(
			_copy_rot_right.influence, target, _config.foot_rot_lerp_speed * delta
		)


# ──────────────────────────────────────────────────────────────────────────────
# Blackboard signal reactions
# ──────────────────────────────────────────────────────────────────────────────


func _on_state_changed(_previous: StringName, next: StringName) -> void:
	if next == &"Jump" or next == &"Fall":
		# Snap IK + hip offset immediately so the model doesn't lag behind
		# the body's Y velocity while lerping to 0 (sticks to ground / pop).
		_ik_leg_left.influence = 0.0
		_ik_leg_right.influence = 0.0
		ik_y_offset = 0.0


func _on_grounded_changed(_grounded: bool) -> void:
	pass  # _should_ik_be_active() reads _bb.is_grounded each frame

func _on_landed(_fall_distance: float) -> void:
	# Hard-land influence is handled by the LAND animation profile and
	# _current_lerp_speed() checking air_time.
	pass


# ──────────────────────────────────────────────────────────────────────────────
# Node building — creates all IK nodes as children of the skeleton
# ──────────────────────────────────────────────────────────────────────────────


func _build_nodes() -> void:
	# TwoBoneIK3D
	_ik_leg_left = TwoBoneIK3D.new()
	_ik_leg_left.name = "IKLeg_L"
	_skeleton.add_child(_ik_leg_left)

	_ik_leg_right = TwoBoneIK3D.new()
	_ik_leg_right.name = "IKLeg_R"
	_skeleton.add_child(_ik_leg_right)

	# Pole markers
	_pole_left = Marker3D.new()
	_pole_left.name = "PoleKnee_L"
	_skeleton.add_child(_pole_left)

	_pole_right = Marker3D.new()
	_pole_right.name = "PoleKnee_R"
	_skeleton.add_child(_pole_right)

	# Target markers — top_level so their Y is independent of the skeleton
	# (and therefore of ik_y_offset). Otherwise the hip-lowering feedback loop
	# moves the skeleton, which moves the target, which re-aims the IK, which
	# changes the ray hit, which changes ik_y_offset — producing the vertical
	# oscillation seen on stairs. X/Z are re-pinned to the foot each frame in
	# _process_leg_ik, so top_level only decouples the vertical channel.
	_target_left = Marker3D.new()
	_target_left.name = "TargetFoot_L"
	_target_left.top_level = true
	_skeleton.add_child(_target_left)

	_target_right = Marker3D.new()
	_target_right.name = "TargetFoot_R"
	_target_right.top_level = true
	_skeleton.add_child(_target_right)

	# BoneAttachment3D + RayCasts (follow the feet during animation)
	_bone_attach_left = BoneAttachment3D.new()
	_bone_attach_left.name = "BoneAttach_L"
	_skeleton.add_child(_bone_attach_left)

	_bone_attach_right = BoneAttachment3D.new()
	_bone_attach_right.name = "BoneAttach_R"
	_skeleton.add_child(_bone_attach_right)

	# Foot raycasts — top_level with identity rotation so they always point
	# straight DOWN in world space. They are parented to the BoneAttachment3D
	# only to stay in the scene tree, but top_level decouples their transform
	# from the foot bone's orientation (which points forward, not up). Their
	# global position is re-pinned each frame in _update_ray_transforms().
	_ray_front_left = _make_foot_ray("RayFront_L")
	_bone_attach_left.add_child(_ray_front_left)

	_ray_back_left = _make_foot_ray("RayBack_L")
	_bone_attach_left.add_child(_ray_back_left)

	_ray_front_right = _make_foot_ray("RayFront_R")
	_bone_attach_right.add_child(_ray_front_right)

	_ray_back_right = _make_foot_ray("RayBack_R")
	_bone_attach_right.add_child(_ray_back_right)

	# Foot rotation modifiers
	if _config.foot_rotation_enabled:
		_target_rot_left = Marker3D.new()
		_target_rot_left.name = "TargetRotLeft"
		_target_rot_left.top_level = true
		_skeleton.add_child(_target_rot_left)

		_target_rot_right = Marker3D.new()
		_target_rot_right.name = "TargetRotRight"
		_target_rot_right.top_level = true
		_skeleton.add_child(_target_rot_right)

		_copy_rot_left = _create_copy_modifier("RotateFoot_L")
		_skeleton.add_child(_copy_rot_left)

		_copy_rot_right = _create_copy_modifier("RotateFoot_R")
		_skeleton.add_child(_copy_rot_right)

	_debug.set_nodes(
		_pole_left,
		_pole_right,
		_target_left,
		_target_right,
		_ray_front_left,
		_ray_back_left,
		_ray_front_right,
		_ray_back_right,
		_ik_leg_left,
		_ik_leg_right
	)
	# Don't process until calibration is done
	set_physics_process(false)


func _create_copy_modifier(m_name: String) -> SkeletonModifier3D:
	var modifier: SkeletonModifier3D
	modifier = ClassDB.instantiate("CopyTransformModifier3D")

	modifier.name = m_name
	return modifier


## Builds a foot raycast with top_level + identity rotation so its
## target_position (set later in _setup_ray) points straight down in world
## space regardless of the foot bone's orientation.
func _make_foot_ray(r_name: String) -> RayCast3D:
	var ray := RayCast3D.new()
	ray.name = r_name
	ray.collision_mask = _config.ray_collision_mask
	ray.top_level = true
	ray.enabled = true
	return ray


# ──────────────────────────────────────────────────────────────────────────────
# Calibration — runs once after nodes are built
# ──────────────────────────────────────────────────────────────────────────────


func _calibrate() -> void:
	var bone_names := {
		left_upper_leg = bone_left_upper_leg,
		left_lower_leg = bone_left_lower_leg,
		left_foot = bone_left_foot,
		left_toe = bone_left_toe,
		right_upper_leg = bone_right_upper_leg,
		right_lower_leg = bone_right_lower_leg,
		right_foot = bone_right_foot,
		right_toe = bone_right_toe,
		hips = bone_hips,
	}

	_calibrator = FootIKCalibrator.new()
	if not _calibrator.calibrate(_skeleton, bone_names, _config):
		push_error("[FootIKController] Calibration failed")
		set_physics_process(false)
		return

	var m := _calibrator.metrics

	# Configure the TwoBoneIK3D solvers (Godot 4.6/4.7 multi-setting API).
	# setting_count must be set BEFORE the per-index setters: they index into
	# the settings array. Each solver needs the bone chain (root→middle→end),
	# a target node (the foot reaches it) and a pole node (defines the knee
	# plane — TwoBoneIK3D requires a pole target). Target/pole paths are
	# relative to the modifier; get_path_to resolves correctly even though the
	# target markers are top_level (that only affects transform, not the tree).
	_setup_two_bone_ik(_ik_leg_left, _target_left, _pole_left, true)
	_setup_two_bone_ik(_ik_leg_right, _target_right, _pole_right, false)

	# BoneAttachments
	_bone_attach_left.bone_idx = _calibrator.bone_indices.left_foot_idx
	_bone_attach_right.bone_idx = _calibrator.bone_indices.right_foot_idx

	# Position markers. The calibrator returns rest-pose bone origins in
	# skeleton-local space; the pole markers are children of the skeleton, so
	# we assign their local `position`. The target markers are top_level, so
	# they need a world-space position (skeleton-global transform applied).
	_pole_left.position = m.pole_knee_left
	_pole_right.position = m.pole_knee_right
	_target_left.global_position = _skeleton.global_transform * m.target_foot_left
	_target_right.global_position = _skeleton.global_transform * m.target_foot_right

	# Configure raycasts — all point straight down; horizontal front/back
	# offset is applied each frame relative to the presenter's facing.
	_setup_ray(_ray_front_left, m.ray_length)
	_setup_ray(_ray_back_left, m.ray_length)
	_setup_ray(_ray_front_right, m.ray_length)
	_setup_ray(_ray_back_right, m.ray_length)

	# Exclude the player body from foot raycasts (matches GroundProbe). Without
	# this the rays can hit the character's own capsule on steep geometry.
	var body := _get_body()
	if body != null:
		for ray in [_ray_front_left, _ray_back_left, _ray_front_right, _ray_back_right]:
			ray.add_exception(body)

	# Foot rotation modifiers
	if _config.foot_rotation_enabled and _copy_rot_left:
		_setup_copy_modifiers()

	# Cache hip indices and leg lengths for runtime constraint solvers
	_left_hip_idx = _calibrator.bone_indices.get("left_upper_leg_idx", -1)
	_right_hip_idx = _calibrator.bone_indices.get("right_upper_leg_idx", -1)
	_left_leg_length = _calibrator.metrics.get("left_leg_length", 1.0)
	_right_leg_length = _calibrator.metrics.get("right_leg_length", 1.0)

	_is_calibrated = true
	set_physics_process(true)

	_debug.print_calibration(_calibrator)


## Wires a TwoBoneIK3D leg solver: bone chain + target + pole, using the
## Godot 4.6/4.7 multi-setting API. The foot (end bone) reaches `target`;
## `pole` defines the plane the knee bulges toward.
func _setup_two_bone_ik(ik: TwoBoneIK3D, target: Marker3D, pole: Marker3D, is_left: bool) -> void:
	var b := _calibrator.bone_indices
	var root_idx: int = b.left_upper_leg_idx if is_left else b.right_upper_leg_idx
	var middle_idx: int = b.left_lower_leg_idx if is_left else b.right_lower_leg_idx
	var end_idx: int = b.left_foot_idx if is_left else b.right_foot_idx

	ik.setting_count = 1
	ik.set_root_bone(0, root_idx)
	ik.set_middle_bone(0, middle_idx)
	ik.set_end_bone(0, end_idx)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.set_pole_node(0, ik.get_path_to(pole))


## Configures a foot raycast to cast straight down by `length` metres in world
## space. The horizontal front/back offset is applied at runtime in
## _update_ray_transforms() (relative to the presenter's facing), not here,
## because the ray is top_level with identity rotation.
func _setup_ray(ray: RayCast3D, length: float) -> void:
	ray.global_rotation = Vector3.ZERO
	ray.target_position = Vector3(0.0, -length, 0.0)


func _setup_copy_modifiers() -> void:
	var m := _calibrator.metrics
	_target_rot_left.global_position = _skeleton.global_transform * m.left_ankle_pos
	_target_rot_right.global_position = _skeleton.global_transform * m.right_ankle_pos
	# Initialize rotation to foot rest orientation so the first SLERP frame
	# starts from the correct state (identity surface alignment * offset).
	_target_rot_left.global_transform.basis = Basis(m.foot_rot_offset_left)
	_target_rot_right.global_transform.basis = Basis(m.foot_rot_offset_right)

	for modifier in [_copy_rot_left, _copy_rot_right]:
		if modifier == null:
			continue
		modifier.setting_count = 1
		if modifier.has_method("set_copy_flags"):
			modifier.set_copy_flags(0, 2)  # Rotation only
		if modifier.has_method("set_axis_flags"):
			modifier.set_axis_flags(0, 7)  # All axes
		if modifier.has_method("set_additive"):
			modifier.set_additive(0, false)

	var left_idx: int = _calibrator.bone_indices.left_foot_idx
	var right_idx: int = _calibrator.bone_indices.right_foot_idx

	if _copy_rot_left.has_method("set_apply_bone"):
		_copy_rot_left.set_apply_bone(0, left_idx)
	if _copy_rot_right.has_method("set_apply_bone"):
		_copy_rot_right.set_apply_bone(0, right_idx)
	# Reference a Node3D (the surface-aligned marker), not a bone. Without
	# REFERENCE_TYPE_NODE the modifier defaults to BONE and ignores the
	# reference node, so the foot never copies the surface rotation.
	if _copy_rot_left.has_method("set_reference_type"):
		_copy_rot_left.set_reference_type(0, BoneConstraint3D.REFERENCE_TYPE_NODE)
	if _copy_rot_right.has_method("set_reference_type"):
		_copy_rot_right.set_reference_type(0, BoneConstraint3D.REFERENCE_TYPE_NODE)
	if _copy_rot_left.has_method("set_reference_node"):
		_copy_rot_left.set_reference_node(0, _copy_rot_left.get_path_to(_target_rot_left))
	if _copy_rot_right.has_method("set_reference_node"):
		_copy_rot_right.set_reference_node(0, _copy_rot_right.get_path_to(_target_rot_right))


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────


func _find_presenter() -> CharacterPresenter:
	var node := get_parent()
	while node != null:
		if node is CharacterPresenter:
			return node
		node = node.get_parent()
	return null

func _get_body() -> CharacterBody3D:
	# Walk up to find the Player (CharacterBody3D)
	var node := get_parent()
	while node != null:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
