## The "vanilla state" of the character: the single public read surface.
##
## Ownership rules (write access):
##   - Player / LocomotionFSM / states -> gameplay fields (locomotion_state,
##     anim_state, is_grounded, velocity_y, model_yaw, wish_direction,
##     velocity, air_time, move_speed_multiplier, ...).
##   - InputCollector  -> input_enabled.
##   - CameraRig       -> camera_yaw, camera_pitch, camera_zoom, first_person, lock_on_character, lock_mouse.
##   - Abilities       -> verbs via PlayerApi (speed modifiers, state requests, ...).
## Everyone else reads, or connects to the change signals below.
##
## All flat/synced properties live on this single node so a
## MultiplayerSynchronizer can replicate them with simple NodePaths.
## On remote peers the synchronizer writes these properties directly, the
## setters fire the same signals, and presentation layers react identically.
class_name PlayerBlackboard
extends Node

signal state_changed(previous: StringName, next: StringName)
signal anim_state_changed(anim: StringName)
signal anim_state_override_changed(anim: StringName)
signal grounded_changed(grounded: bool)
signal landed(fall_distance: float)
signal jumped
signal footstep(marker: StringName)
signal input_enabled_changed(enabled: bool)
signal first_person_changed(enabled: bool)

# --- Synced gameplay state (referenced by the MultiplayerSynchronizer) -------

## Current locomotion FSM state id (node name of the state, e.g. &"Idle").
var locomotion_state: StringName = &"Idle":
	set(value):
		if locomotion_state == value:
			return
		var previous := locomotion_state
		locomotion_state = value
		state_changed.emit(previous, value)

## Current presentation state (AnimationTree state machine node name).
var anim_state: StringName = &"idle":
	set(value):
		if anim_state == value:
			return
		anim_state = value
		anim_state_changed.emit(value)

## When non-empty, the AnimationController plays this instead of anim_state.
## Set via PlayerApi.override_anim_state() by cutscenes/emote abilities; the
## FSM keeps writing anim_state underneath, so clearing this resumes cleanly.
var anim_state_override: StringName = &"":
	set(value):
		if anim_state_override == value:
			return
		anim_state_override = value
		anim_state_override_changed.emit(value)

## Gameplay yaw of the visual model (radians, without the model's authoring
## rotation offset). Applied locally by ModelVisual on every peer.
var model_yaw := 0.0

## True when on floor. Referenced by FootIKController, StairStepper, etc.
var is_grounded := true:
	set(value):
		if is_grounded == value:
			return
		is_grounded = value
		grounded_changed.emit(value)

var velocity_y := 0.0
var horizontal_speed := 0.0
var has_move_input := false
var last_fall_distance := 0.0
var body_height := 1.59
## True when the body was teleported up a step this frame. Published by StairStepper.
var is_stepping := false
## True while snapping down onto a step below (kept briefly to avoid flicker). Published by StairStepper.
var is_stepping_down := false
## Height delta (meters) of the last successful step up. Published by StairStepper.
var step_height_delta := 0.0
var wish_direction := Vector3.ZERO
var velocity := Vector3.ZERO
var air_time := 0.0
var move_speed_multiplier := 1.0
## Last known grounded position on solid floor (published by Player when
## is_grounded && is_on_floor). Used by WorldBoundary to reset to the
## nearest safe spot instead of the spawnpoint.
var last_safe_position := Vector3.ZERO

## Current time (seconds) within the currently playing animation.
## Published every frame by AnimationDriver. Read surface for effects, IK, audio, etc.
var current_anim_time: float = 0.0

# --- Camera-owned state -------------------------------------------------------

var camera_yaw := 0.0
var camera_pitch := 0.0
## Current camera zoom distance (0.0 = first person, max_zoom = furthest).
var camera_zoom := 0.0
var first_person := false:
	set(value):
		if first_person == value:
			return
		first_person = value
		first_person_changed.emit(value)
## When true, the model is locked to face the camera direction (backpedaling
## active). Toggled by the LockOnCharacter ability (F3) or via PlayerApi.
var lock_on_character := false
## When true, the mouse is captured for camera orbit. Controlled by right-click
## (inverts the configured default) or set directly by PlayerApi/cutscenes.
var lock_mouse := false


## Returns the current lock_mouse mode as a StringName for API consumers.
## &"always_on" when lock_mouse is true, &"always_off" when false.
func get_lock_mouse_mode() -> StringName:
	return &"always_on" if lock_mouse else &"always_off"

# --- Facing-locked presentation queries ---------------------------------------
# Filled by the CharacterPresenter at setup time with the directional anim
# state names its AnimationTree exposes (e.g. &"walk_back"). The player layer
# stays character-agnostic: the FSM asks resolve_anim() and the blackboard only
# routes to a directional clip if the presenter advertised it here.
var directional_anim_states: Array[StringName] = []

## Per-animation footstep marker data, populated by AnimationDriver at setup.
## {anim_name: [{time: float, name: StringName}]}
var footstep_markers: Dictionary = {}

## Per-animation cycle length in seconds, populated by AnimationDriver at setup.
## {anim_name: float}
var anim_lengths: Dictionary = {}


## True when the model is locked to camera facing (first person or
## lock_on_character). In this mode the character backpedals instead of
## turning toward its move direction, so reverse-velocity damp and backwalk
## tuning apply. Derived read over existing camera-owned state — no signal.
func is_facing_locked() -> bool:
	return first_person or lock_on_character


## Coarse move sector relative to the model facing: &"back", &"left", &"right"
## or &"" (forward / no input). The full rear semi-plane (z > 0 in model space)
## collapses to &"back" so back-diagonal counts as backpedaling.
## Returns &"" when wish_dir is zero or the model is not facing-locked.
func move_sector(wish_dir: Vector3) -> StringName:
	if not is_facing_locked() or wish_dir == Vector3.ZERO:
		return &""
	# model_yaw is the gameplay yaw of the visual model (it faces -Z at yaw 0).
	# Rotate wish_dir into model space and inspect the resulting forward axis.
	var local := wish_dir.rotated(Vector3.UP, -model_yaw)
	# Small epsilon absorbs floating-point error at the z=0 boundary (a 90°
	# rotation yields z ≈ 4e-8 instead of exactly 0). Without it, pure sideways
	# input would be misclassified as "back".
	const BACK_EPSILON := 0.0001
	if local.z > BACK_EPSILON:
		return &"back"
	if abs(local.x) > abs(local.z):
		return &"left" if local.x < 0.0 else &"right"
	return &""


## True when the character is moving into its rear semi-plane while the facing
## is locked to the camera (backpedaling).
func is_backpedaling(wish_dir: Vector3) -> bool:
	return move_sector(wish_dir) == &"back"


## Resolves a base anim state (&"walk", &"run", &"idle", ...) to a directional
## variant if the presenter advertised one for the current sector. The
## convention is `<base>_<sector>` (e.g. &"walk_back"). Falls back to `base`
## when no directional clip exists or the sector is empty.
func resolve_anim(base: StringName, wish_dir: Vector3) -> StringName:
	var sector := move_sector(wish_dir)
	if sector.is_empty():
		return base
	var candidate := StringName("%s_%s" % [base, sector])
	if candidate in directional_anim_states:
		return candidate
	return base


# --- Input-layer-owned state --------------------------------------------------

var input_enabled := true:
	set(value):
		if input_enabled == value:
			return
		input_enabled = value
		input_enabled_changed.emit(value)

# --- Notification helpers (gameplay writers only) -----------------------------


func notify_jumped() -> void:
	jumped.emit()


func notify_landed(fall_distance: float) -> void:
	last_fall_distance = fall_distance
	landed.emit(fall_distance)


func notify_footstep(marker: StringName) -> void:
	footstep.emit(marker)
