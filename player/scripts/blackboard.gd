## The "vanilla state" of the character: the single public read surface.
##
## Ownership rules (write access):
##   - Player / LocomotionFSM / states -> gameplay fields (locomotion_state,
##     anim_state, is_grounded, velocity_y, model_yaw, wish_direction,
##     velocity, air_time, move_speed_multiplier, ...).
##   - InputCollector  -> input_enabled.
##   - CameraRig       -> camera_yaw, camera_pitch, first_person, shift_lock fields.
##   - Abilities       -> only whitelisted flags via AbilityContext.
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

## Gameplay yaw of the visual model (radians, without the model's authoring
## rotation offset). Applied locally by ModelVisual on every peer.
var model_yaw := 0.0

## Reserved for the Sprint ability (kept here so it is sync-ready).
var is_sprinting := false

# --- Local gameplay state (read-only for observers) --------------------------

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
var wish_direction := Vector3.ZERO
var velocity := Vector3.ZERO
var air_time := 0.0
var move_speed_multiplier := 1.0

# --- Camera-owned state -------------------------------------------------------

var camera_yaw := 0.0
var camera_pitch := 0.0
var first_person := false:
	set(value):
		if first_person == value:
			return
		first_person = value
		first_person_changed.emit(value)
var shift_lock := false
var shift_lock_toggle_on := false

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
