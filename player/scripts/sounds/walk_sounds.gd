## Fully reactive footstep engine driven by animation markers and blackboard
## signals. No timer-based polling — footsteps fire exactly when the animation
## says a foot hits the ground.
##
## Architecture:
##   1. AnimationController tracks marker times → calls bb.notify_footstep()
##   2. Blackboard emits footstep(marker) signal
##   3. FootstepEngine receives it, picks a sound via shuffle bag, modulates
##      pitch/volume with Perlin noise + velocity curves + per-foot bias, and
##      plays it.
##
## Landing sounds are driven by bb.landed(fall_distance).
## Jump takeoff by bb.jumped.
## State configs are modular — new locomotion states just need a FootstepStateConfig.
class_name WalkSounds
extends Node

@onready var audio_player_2d: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D

var blackboard: PlayerBlackboard
var locomotion_config: LocomotionConfig

## Per-locomotion-state configuration. Key = locomotion_state (e.g. &"Walk")
@export var state_configs: Array[FootstepStateConfig]

## Default surface for footsteps (future: per-floor-type pools)
@export var default_surface: FootstepSurface

## Noise generator for organic pitch/volume variation
@export var noise: FastNoiseLite

## Smoothing factor for speed-driven modulation (0 = instant, <1 = smoothed)
@export_range(0.01, 1.0, 0.01) var speed_smoothing: float = 0.85

## How strongly horizontal_speed affects pitch (scaled to [0,1] range)
@export_range(0.0, 0.3, 0.01) var speed_pitch_influence: float = 0.12
## How strongly horizontal_speed affects volume in dB
@export_range(0.0, 6.0, 0.1) var speed_volume_influence_db: float = 4.0

## Perlin noise magnitude for pitch (± this range around base)
@export_range(0.0, 0.1, 0.001) var noise_pitch_range: float = 0.03
## Perlin noise magnitude for volume in dB
@export_range(0.0, 2.0, 0.1) var noise_volume_range_db: float = 0.6

## Landing sound is played if fall_distance >= this
@export var land_min_distance: float = 0.3
## Max fall distance for volume scaling (clamped at this)
@export var land_max_distance: float = 5.0
## Base landing volume in dB
@export var land_volume_base_db: float = 0.0
## Extra landing volume at max fall distance (added on top of base)
@export var land_volume_extra_db: float = 8.0

## Jump takeoff volume in dB
@export var jump_volume_db: float = -2.0

@export var min_step_interval_ms: float = 80.0

# --- Internal state ---
var _config_map: Dictionary = {}            # StringName → FootstepStateConfig
var _active_config: FootstepStateConfig
var _shuffle_bag: Array[int] = []
var _last_bag_tail: int = -1
var _bag_index: int = 0
var _noise_time: float = 0.0
var _last_footstep_time: float = 0.0
var _speed_smoothed: float = 0.0
var _is_local: bool = false
var _max_distance: float = 0.0
var _active: bool = false
var _surface: FootstepSurface
var _land_last_idx: int = -1
var _jump_last_idx: int = -1

# Per-foot bias oscillators (slowly drifting via Perlin)
var _left_bias_offset: float = 0.0
var _right_bias_offset: float = 0.0

func setup(p_blackboard: PlayerBlackboard, p_loco: LocomotionConfig, is_local: bool) -> void:
	blackboard = p_blackboard
	locomotion_config = p_loco
	_is_local = is_local
	_max_distance = audio_player_3d.max_distance

	if _is_local:
		audio_player_3d.queue_free()
	else:
		audio_player_2d.queue_free()

	_surface = default_surface

	for cfg in state_configs:
		if cfg != null and not cfg.locomotion_state.is_empty():
			_config_map[cfg.locomotion_state] = cfg

	_setup_signals()

func _setup_signals() -> void:
	blackboard.state_changed.connect(_on_state_changed)
	blackboard.footstep.connect(_on_footstep)
	blackboard.landed.connect(_on_landed)
	blackboard.jumped.connect(_on_jumped)

	if _active_config != null and _active_config.enabled:
		_active = true

func _on_state_changed(_previous: StringName, next: StringName) -> void:
	var cfg: FootstepStateConfig = _config_map.get(next, null)
	if cfg == _active_config:
		return

	_active_config = cfg
	_active = cfg != null and cfg.enabled

	if _active:
		_reset_bag()

	_speed_smoothed = 0.0

func _on_footstep(marker: StringName) -> void:
	if not _active or _active_config == null:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_footstep_time < min_step_interval_ms / 1000.0:
		return
	_last_footstep_time = now

	var pool: Array[AudioStream]
	if _surface != null and not _surface.sound_pool.is_empty():
		pool = _surface.sound_pool
	else:
		pool = _active_config.sound_pool

	if pool.is_empty():
		return

	var snd: AudioStream = _next_from_bag(pool)
	if snd == null:
		return

	var speed_fraction: float = _get_speed_fraction()
	var pitch: float = _modulate_pitch(marker, speed_fraction)
	var volume: float = _modulate_volume(marker, speed_fraction)

	_play(snd, pitch, volume)
	_advance_noise()

func _on_landed(fall_distance: float) -> void:
	if fall_distance < land_min_distance:
		return

	var clamp_dist := clampf(fall_distance, land_min_distance, land_max_distance)
	var t := inverse_lerp(land_min_distance, land_max_distance, clamp_dist)
	var volume := land_volume_base_db + lerpf(0.0, land_volume_extra_db, t)

	var sound := _get_land_sound()
	if sound == null:
		return

	_play(sound, _vary_pitch(1.0), _vary_volume_db(volume))

func _on_jumped() -> void:
	var sound := _get_jump_sound()
	if sound == null:
		return

	_play(sound, _vary_pitch(1.0), _vary_volume_db(jump_volume_db))

# --- Shuffle bag: no-repeat randomization ---

func _next_from_bag(pool: Array[AudioStream]) -> AudioStream:
	if _bag_index >= _shuffle_bag.size():
		# Record the last sound from the expiring bag for anti-repeat
		if not _shuffle_bag.is_empty():
			_last_bag_tail = _shuffle_bag[_shuffle_bag.size() - 1]
		_refill_bag(pool.size())
		_bag_index = 0

	if _shuffle_bag.is_empty():
		return null

	var idx: int = _shuffle_bag[_bag_index]
	_bag_index += 1
	return pool[idx]

func _refill_bag(pool_size: int) -> void:
	_shuffle_bag.clear()
	if pool_size == 0:
		return

	for i in pool_size:
		_shuffle_bag.append(i)

	_shuffle_bag.shuffle()

	# Anti-repeat across bag boundaries: swap first element if it matches the
	# last sound from the previous bag
	if _last_bag_tail >= 0 and _shuffle_bag.size() > 1 and _shuffle_bag[0] == _last_bag_tail:
		var swap_idx := 1 + randi() % (_shuffle_bag.size() - 1)
		var tmp := _shuffle_bag[0]
		_shuffle_bag[0] = _shuffle_bag[swap_idx]
		_shuffle_bag[swap_idx] = tmp

func _reset_bag() -> void:
	_bag_index = 0
	_shuffle_bag.clear()
	_last_bag_tail = -1

# --- Pitch & volume modulation ---

func _modulate_pitch(marker: StringName, speed_fraction: float) -> float:
	var cfg := _active_config
	var base: float = 1.0

	# Per-foot bias (step_1 vs step_2)
	var foot_bias: float = 0.0
	if marker == &"step_1":
		foot_bias = -cfg.foot_bias_strength + _left_bias_offset
	elif marker == &"step_2":
		foot_bias = cfg.foot_bias_strength + _right_bias_offset

	# Speed contribution (faster = slightly higher pitch)
	var speed_contrib := speed_fraction * speed_pitch_influence

	return _vary_pitch(base + foot_bias + speed_contrib)

func _modulate_volume(marker: StringName, speed_fraction: float) -> float:
	var cfg := _active_config
	var db: float = cfg.volume_db_base

	# Per-foot volume bias (opposite sign to pitch bias for natural feel)
	if marker == &"step_1":
		db += _left_bias_offset * 3.0
	elif marker == &"step_2":
		db += _right_bias_offset * 3.0

	# Speed contribution (faster = louder)
	db += speed_fraction * speed_volume_influence_db

	return _vary_volume_db(db)

func _vary_pitch(base: float) -> float:
	var n := _sample_noise(_noise_time * 0.7)
	return base * (1.0 + n * noise_pitch_range)

func _vary_volume_db(base_db: float) -> float:
	var n := _sample_noise(_noise_time * 0.5 + 100.0)
	return base_db + n * noise_volume_range_db

# --- Noise ---

func _sample_noise(at: float) -> float:
	if noise == null:
		return randf_range(-1.0, 1.0)
	return noise.get_noise_1d(at)

func _advance_noise() -> void:
	_noise_time += 0.7 + randf() * 0.3

	# Slowly drift foot biases
	_left_bias_offset = _sample_noise(_noise_time * 0.3 + 500.0) * 0.015
	_right_bias_offset = _sample_noise(_noise_time * 0.3 + 600.0) * 0.015

# --- Speed ---

func _get_speed_fraction() -> float:
	var max_speed := 8.0
	if locomotion_config != null:
		max_speed = locomotion_config.run_speed
	return clampf(_speed_smoothed / max_speed, 0.0, 1.0)

func _process(delta: float) -> void:
	if blackboard == null:
		return

	# Smooth horizontal speed for organic modulation curves
	var target := blackboard.horizontal_speed
	var alpha := clampf(delta * 8.0 * (1.0 - speed_smoothing + 0.05), 0.0, 1.0)
	_speed_smoothed = lerpf(_speed_smoothed, target, alpha)

# --- Audio ---

func _play(stream: AudioStream, pitch: float, volume_db: float) -> void:
	if _is_local:
		audio_player_2d.stream = stream
		audio_player_2d.pitch_scale = pitch
		audio_player_2d.volume_db = volume_db
		audio_player_2d.play()
	else:
		audio_player_3d.stream = stream
		audio_player_3d.pitch_scale = pitch
		audio_player_3d.volume_db = volume_db
		var max_speed := locomotion_config.run_speed if locomotion_config else 8.0
		audio_player_3d.max_distance = _max_distance * (1.0 + _speed_smoothed / max_speed)
		audio_player_3d.play()

# --- Sound selectors for landing / jumping ---

func _get_land_sound() -> AudioStream:
	var cfg: FootstepStateConfig = _config_map.get(&"Land", null)
	if cfg == null or cfg.sound_pool.is_empty():
		return null
	_land_last_idx = _pick_no_repeat(cfg.sound_pool, _land_last_idx)
	return cfg.sound_pool[_land_last_idx]

func _get_jump_sound() -> AudioStream:
	var cfg: FootstepStateConfig = _config_map.get(&"Jump", null)
	if cfg == null or cfg.sound_pool.is_empty():
		return null
	_jump_last_idx = _pick_no_repeat(cfg.sound_pool, _jump_last_idx)
	return cfg.sound_pool[_jump_last_idx]

func _pick_no_repeat(pool: Array[AudioStream], last: int) -> int:
	if pool.size() <= 1:
		return 0
	var idx := randi() % pool.size()
	if pool.size() > 1 and idx == last:
		idx = (idx + 1) % pool.size()
	return idx
