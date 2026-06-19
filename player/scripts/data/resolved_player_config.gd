## Immutable resolved configuration built from a PlayerConfig. The Player
## coordinator builds one of these once at setup time and passes it (or its
## sub-objects) to every component. Components read ONLY from the resolved
## config — never from the raw .tres / PlayerConfig in runtime.
##
## The resolved config is the place for:
##   - Cross-config derivations (e.g. weight → turn speed, body_height → step height).
##   - Centralised validation (run_speed > walk_speed, weight > 0, etc.).
##   - Passthrough of every independent knob so consumers have a single source.
##
## Runtime-derived values (speed_scale from velocity, current yaw factor, etc.)
## do NOT live here — they stay in their respective systems. The resolver only
## does static config→config derivations.
##
## Immutability is by convention: fields are set once during resolve() and
## should not be mutated afterwards. Runtime modifications (abilities changing
## speed) go through the motor's speed-modifier stack, not by mutating this.
class_name ResolvedPlayerConfig
extends RefCounted

const REFERENCE_HEIGHT := 1.59
const REFERENCE_WEIGHT := 70.0

var body_height: float
var weight: float
var locomotion: Locomotion
var jump: Jump
var camera: Camera
var camera_effects: CameraEffects
var stair: Stair
var probe: Probe
var extras: Array[Resource]

# --- Inner data classes -------------------------------------------------------


class Locomotion:
	extends RefCounted
	var walk_speed: float
	var run_speed: float
	var acceleration: float
	var friction: float
	var run_to_walk_deceleration: float
	var stopping_deceleration: float
	var reverse_velocity_damp: float
	var air_control: float
	var backwalk_speed_multiplier: float
	var min_animation_speed: float
	var max_animation_speed: float
	var animation_speed_multiplier: float
	## Weight-turn knobs (passthrough).
	var weight_turn_enabled: bool
	var weight_turn_exponent: float
	var weight_turn_scale: float
	## Derived: base_model_turn_speed * scale * pow(REFERENCE_WEIGHT/weight, exponent)
	## when weight_turn_enabled; else base_model_turn_speed.
	var model_turn_speed: float


class Jump:
	extends RefCounted
	var jump_velocity: float
	var gravity: float
	var coyote_time: float
	var jump_buffer_time: float
	var land_duration: float
	var land_anim_min_fall: float
	var fall_anim_min_fall: float


class Camera:
	extends RefCounted
	var mouse_sensitivity: float
	var pitch_max_degrees: float
	var pitch_min_degrees: float
	var pitch_sensitivity_multiplier: float
	var force_first_person: bool
	var zoom_speed: float
	var max_zoom: float
	var first_person_snap_distance: float
	var zoom_lerp_speed: float
	var height_smooth_speed: float
	var collision_mask: int
	var camera_radius: float
	var collision_return_speed: float
	var collision_approach_speed: float


class CameraEffects:
	extends RefCounted
	var enabled: bool
	var base_fov: float
	var run_fov_add: float
	var fall_fov_add: float
	var fov_lerp_speed: float
	var fall_speed_for_max_fov: float
	var land_shake_amount: float
	var land_shake_duration: float
	var fall_distance_for_max_shake: float
	var run_shake_amount: float
	var shake_frequency: float
	var fall_shake_ramp_speed: float
	var fall_shake_max: float
	var tilt_amount: float
	var tilt_frequency: float
	var land_fov_kick: float


class Stair:
	extends RefCounted
	var step_check_iterations: int
	var min_horizontal_motion: float
	## Derived: base_max_step_up * (body_height / REFERENCE_HEIGHT).
	var max_step_up: float


class Probe:
	extends RefCounted
	var short_factor: float
	var medium_factor: float
	var collision_mask: int


# --- Factory ------------------------------------------------------------------


## Builds an immutable ResolvedPlayerConfig from a PlayerConfig. Calls
## ensure_defaults() first so sub-resources are never null. Validation errors
## are pushed via push_error but do not abort — callers get a best-effort
## resolved config with the invalid values as-is.
static func resolve(cfg: PlayerConfig) -> ResolvedPlayerConfig:
	cfg.ensure_defaults()
	_validate(cfg)
	var r := ResolvedPlayerConfig.new()
	r.body_height = cfg.body_height
	r.weight = cfg.weight
	r.locomotion = _resolve_locomotion(cfg)
	r.jump = _resolve_jump(cfg)
	r.camera = _resolve_camera(cfg)
	r.camera_effects = _resolve_camera_effects(cfg)
	r.stair = _resolve_stair(cfg)
	r.probe = _resolve_probe(cfg)
	r.extras = cfg.extras.duplicate()
	return r


# --- Validation ---------------------------------------------------------------


static func _validate(cfg: PlayerConfig) -> void:
	if cfg.weight <= 0.0:
		push_error("PlayerConfig: weight must be > 0, got %f" % cfg.weight)
	if cfg.body_height <= 0.0:
		push_error("PlayerConfig: body_height must be > 0, got %f" % cfg.body_height)
	if cfg.locomotion.run_speed <= cfg.locomotion.walk_speed:
		push_error(
			(
				"PlayerConfig: run_speed (%f) must be > walk_speed (%f)"
				% [cfg.locomotion.run_speed, cfg.locomotion.walk_speed]
			)
		)
	if cfg.locomotion.min_animation_speed > cfg.locomotion.max_animation_speed:
		push_error("PlayerConfig: min_animation_speed > max_animation_speed")


# --- Sub-resolvers ------------------------------------------------------------


static func _resolve_locomotion(cfg: PlayerConfig) -> Locomotion:
	var l := Locomotion.new()
	var s := cfg.locomotion
	l.walk_speed = s.walk_speed
	l.run_speed = s.run_speed
	l.acceleration = s.acceleration
	l.friction = s.friction
	l.run_to_walk_deceleration = s.run_to_walk_deceleration
	l.stopping_deceleration = s.stopping_deceleration
	l.reverse_velocity_damp = s.reverse_velocity_damp
	l.air_control = s.air_control
	l.backwalk_speed_multiplier = s.backwalk_speed_multiplier
	l.min_animation_speed = s.min_animation_speed
	l.max_animation_speed = s.max_animation_speed
	l.animation_speed_multiplier = s.animation_speed_multiplier
	l.weight_turn_enabled = s.weight_turn_enabled
	l.weight_turn_exponent = s.weight_turn_exponent
	l.weight_turn_scale = s.weight_turn_scale
	l.model_turn_speed = _compute_model_turn_speed(s, cfg.weight)
	return l


static func _resolve_jump(cfg: PlayerConfig) -> Jump:
	var j := Jump.new()
	var s := cfg.jump
	j.jump_velocity = s.jump_velocity
	j.gravity = s.gravity
	j.coyote_time = s.coyote_time
	j.jump_buffer_time = s.jump_buffer_time
	j.land_duration = s.land_duration
	j.land_anim_min_fall = s.land_anim_min_fall
	j.fall_anim_min_fall = s.fall_anim_min_fall
	return j


static func _resolve_camera(cfg: PlayerConfig) -> Camera:
	var c := Camera.new()
	var s := cfg.camera
	c.mouse_sensitivity = s.mouse_sensitivity
	c.pitch_max_degrees = s.pitch_max_degrees
	c.pitch_min_degrees = s.pitch_min_degrees
	c.pitch_sensitivity_multiplier = s.pitch_sensitivity_multiplier
	c.force_first_person = s.force_first_person
	c.zoom_speed = s.zoom_speed
	c.max_zoom = s.max_zoom
	c.first_person_snap_distance = s.first_person_snap_distance
	c.zoom_lerp_speed = s.zoom_lerp_speed
	c.height_smooth_speed = s.height_smooth_speed
	c.collision_mask = s.collision_mask
	c.camera_radius = s.camera_radius
	c.collision_return_speed = s.collision_return_speed
	c.collision_approach_speed = s.collision_approach_speed
	return c


static func _resolve_camera_effects(cfg: PlayerConfig) -> CameraEffects:
	var e := CameraEffects.new()
	var s := cfg.camera_effects
	e.enabled = s.enabled
	e.base_fov = s.base_fov
	e.run_fov_add = s.run_fov_add
	e.fall_fov_add = s.fall_fov_add
	e.fov_lerp_speed = s.fov_lerp_speed
	e.fall_speed_for_max_fov = s.fall_speed_for_max_fov
	e.land_shake_amount = s.land_shake_amount
	e.land_shake_duration = s.land_shake_duration
	e.fall_distance_for_max_shake = s.fall_distance_for_max_shake
	e.run_shake_amount = s.run_shake_amount
	e.shake_frequency = s.shake_frequency
	e.fall_shake_ramp_speed = s.fall_shake_ramp_speed
	e.fall_shake_max = s.fall_shake_max
	e.tilt_amount = s.tilt_amount
	e.tilt_frequency = s.tilt_frequency
	e.land_fov_kick = s.land_fov_kick
	return e


static func _resolve_stair(cfg: PlayerConfig) -> Stair:
	var s := Stair.new()
	s.step_check_iterations = cfg.stair.step_check_iterations
	s.min_horizontal_motion = cfg.stair.min_horizontal_motion
	s.max_step_up = cfg.stair.base_max_step_up * (cfg.body_height / REFERENCE_HEIGHT)
	return s


static func _resolve_probe(cfg: PlayerConfig) -> Probe:
	var p := Probe.new()
	p.short_factor = cfg.probe.short_factor
	p.medium_factor = cfg.probe.medium_factor
	p.collision_mask = cfg.probe.collision_mask
	return p


# --- Derivation functions -----------------------------------------------------


## Computes the effective model turn speed from the base value and weight.
## When weight_turn_enabled, heavier characters turn more slowly:
##   base * scale * pow(REFERENCE_WEIGHT / weight, exponent)
## Reference weight is 70 kg (average human adult). Clamped to [0.2, 5.0]
## to avoid extreme values at very low/high weights.
static func _compute_model_turn_speed(s: LocomotionConfig, weight: float) -> float:
	if not s.weight_turn_enabled:
		return s.base_model_turn_speed
	var ratio := REFERENCE_WEIGHT / weight
	var factor := clampf(pow(ratio, s.weight_turn_exponent) * s.weight_turn_scale, 0.2, 5.0)
	return s.base_model_turn_speed * factor
