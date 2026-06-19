## Centralised verb surface for the character. Companion to PlayerBlackboard
## (nouns/state) — this is the action layer external systems use to influence
## the player. Lives as a Node child of Player (discoverable in the scene,
## @onready) and is built once during Player._ready().
##
## Relationship with the blackboard:
##   - PlayerBlackboard holds STATE (nouns) + change signals. It is the sync
##     surface for the MultiplayerSynchronizer and the read surface for
##     presentation layers. It stays "dumb".
##   - PlayerApi holds VERBS (actions). It forwards to the right subsystem
##     (motor, fsm, input, camera, animation, ability manager) and is the
##     "blessed path" for external actors (abilities, game layer, cutscenes,
##     AI). It does NOT replicate and does NOT own state.
## They are deliberately separate: merging would complicate replication and
## couple presentation layers to logic they don't need.
##
## Ownership is documented per verb (## comments), not enforced at runtime.
## When adding new behaviour to the player, consider whether it belongs here:
##   - If it is an ACTION external systems should trigger → add a verb.
##   - If it is STATE others should read/watch → add a field/signal to the
##     blackboard.
##   - If it is an internal mechanism of a single subsystem → keep it there.
##
## Tier 1 (core): speed/gravity/velocity/fsm/input/abilities — covers ability
##                 and game-layer needs.
## Tier 2 (feel):  intent injection, camera verbs, animation override — for
##                 cutscenes/AI/abilities that need to drive presentation.
## Tier 3 (ext):   register_verb/call_verb — lets auxiliary nodes publish
##                 their own verbs without PlayerApi knowing about them.
class_name PlayerApi
extends Node

var _bb: PlayerBlackboard
var _motor: MovementMotor
var _fsm: LocomotionFSM
var _input: InputCollector
var _camera_rig: CameraRig
var _presenter: CharacterPresenter
var _resolved: ResolvedPlayerConfig
var _ability_mgr: AbilityManager

# Tier 3: extension verbs registered by auxiliary nodes.
var _verbs: Dictionary = {}  # StringName -> Callable


func setup(
	blackboard: PlayerBlackboard,
	motor: MovementMotor,
	fsm: LocomotionFSM,
	input_collector: InputCollector,
	camera_rig: CameraRig,
	presenter: CharacterPresenter,
	resolved: ResolvedPlayerConfig,
	ability_mgr: AbilityManager
) -> void:
	_bb = blackboard
	_motor = motor
	_fsm = fsm
	_input = input_collector
	_camera_rig = camera_rig
	_presenter = presenter
	_resolved = resolved
	_ability_mgr = ability_mgr


# --- Reads --------------------------------------------------------------------


## The character's state surface (nouns + signals). Read-only for api callers.
func blackboard() -> PlayerBlackboard:
	return _bb


## The immutable resolved config. Read-only.
func resolved() -> ResolvedPlayerConfig:
	return _resolved


# --- Tier 1: core verbs -------------------------------------------------------
# Subsystem: MovementMotor. Abilities and game layer may use these freely.


## Stack a speed multiplier (multiplicative with all others). Identified so
## the same caller can remove it later. Owner: any external system.
func add_speed_modifier(id: StringName, multiplier: float) -> void:
	_motor.add_speed_modifier(id, multiplier)


## Remove a previously stacked speed modifier. Owner: the same caller that added it.
func remove_speed_modifier(id: StringName) -> void:
	_motor.remove_speed_modifier(id)


## Current effective speed multiplier (product of all stacked modifiers).
func speed_multiplier() -> float:
	return _motor.speed_multiplier()


## Toggle gravity processing. Owner: abilities (e.g. Climb disables gravity).
func set_gravity_enabled(enabled: bool) -> void:
	_motor.set_gravity_enabled(enabled)


func is_gravity_enabled() -> bool:
	return _motor.gravity_enabled


## Instant vertical impulse (jumping / ability launch). Owner: JumpState and
## abilities that provide their own vertical motion. Use sparingly — prefer
## speed modifiers for sustained changes.
func launch_vertical(vertical_speed: float) -> void:
	_motor.launch_vertical(vertical_speed)


## Direct velocity write for ability-provided states (Climb, Glide, ...).
## Owner: abilities that fully own the body's motion. Bypasses the motor's
## acceleration model.
func set_velocity(velocity: Vector3) -> void:
	_motor.set_velocity(velocity)


func get_velocity() -> Vector3:
	return _bb.velocity


# --- Tier 1: FSM verbs --------------------------------------------------------
# Subsystem: LocomotionFSM. External actors request; the FSM may refuse.


## Request a state transition. Returns false if the FSM (or either state)
## refuses. Owner: abilities, game layer, cutscenes.
func request_state(id: StringName) -> bool:
	return _fsm.request_transition(id)


func current_state() -> StringName:
	return _fsm.current.state_id() if _fsm.current else &""


func has_state(id: StringName) -> bool:
	return _fsm.has_state(id)


## Register an ability-provided state (e.g. ClimbState). Owner: abilities.
func register_state(state: LocomotionState) -> void:
	_fsm.register_state(state)


func unregister_state(id: StringName) -> void:
	_fsm.unregister_state(id)


# --- Tier 1: input verbs ------------------------------------------------------
# Subsystem: PlayerBlackboard + InputCollector.


## Enable/disable gameplay input. Owner: game layer (cutscenes, menus),
## networking (focus loss). The InputCollector clears intent when disabled.
func set_input_enabled(enabled: bool) -> void:
	_bb.input_enabled = enabled


func is_input_enabled() -> bool:
	return _bb.input_enabled


# --- Tier 1: ability verbs ----------------------------------------------------
# Subsystem: AbilityManager. Forwarded.


func register_ability(ability: Ability) -> void:
	if _ability_mgr:
		_ability_mgr.register(ability)


func unregister_ability(id: StringName) -> void:
	if _ability_mgr:
		_ability_mgr.unregister(id)


func get_ability(id: StringName) -> Ability:
	return _ability_mgr.get_ability(id) if _ability_mgr else null


func has_ability(id: StringName) -> bool:
	return _ability_mgr.has_ability(id) if _ability_mgr else false


# --- Tier 2: intent injection (cutscenes/AI) ----------------------------------
# Subsystem: InputCollector. When set, replaces device input entirely.


## Replace device input with a scripted intent (cutscene, AI driver). Pass
## null to restore device input. Owner: cutscenes, AI, networking (remote
## peer input). While injected, InputCollector does NOT read Input.
func inject_intent(intent: InputIntent) -> void:
	if _input:
		_input.injected_intent = intent


## The intent currently driving the character (device or injected).
func get_intent() -> InputIntent:
	return _input.intent if _input else null


# --- Tier 2: camera verbs -----------------------------------------------------
# Subsystem: CameraRig. These are REQUESTS — the rig honours them in its loop.


## Force first-person view (or release the force). Owner: cutscenes, abilities.
func set_first_person(forced: bool) -> void:
	if _camera_rig:
		_camera_rig.set_first_person_forced(forced)


## Set camera zoom distance (0 = first person). Owner: cutscenes, abilities.
func set_zoom(distance: float) -> void:
	if _camera_rig:
		_camera_rig.target_zoom = clampf(distance, 0.0, _camera_rig.config.max_zoom)


func is_first_person() -> bool:
	return _bb.first_person


## True when the model is locked to camera facing (first person or shift-lock
## toggle). Read verb; canonical method lives on the blackboard. Owner: any
## external system that needs to know whether backpedaling/backwalk applies.
func is_facing_locked() -> bool:
	return _bb.is_facing_locked()


## lock_mouse default mode: "always_on" (mouse locked by default, right-click
## releases) or "always_off" (mouse free by default, right-click locks).
## Owner: game layer / config initialization.
func set_lock_mouse_default(mode: StringName) -> void:
	if _camera_rig:
		_camera_rig.set_lock_mouse_default(mode)


## Current lock_mouse mode from the blackboard. Returns &"always_on" or
## &"always_off" based on the current lock_mouse state.
func get_lock_mouse_mode() -> StringName:
	return _bb.get_lock_mouse_mode()


## Scripted camera yaw (radians). Puts the rig in scripted mode: it stops
## overwriting camera_yaw from mouse input. Owner: cutscenes.
func set_camera_yaw(rad: float) -> void:
	if _camera_rig:
		_camera_rig.set_scripted_yaw(rad)


func get_camera_yaw() -> float:
	return _bb.camera_yaw


func get_camera_pitch() -> float:
	return _bb.camera_pitch


# --- Tier 2: camera effects (FOV + shake) -------------------------------------
# Subsystem: CameraRig. Automatic curves run by default; manual verbs override.


## Manual FOV override (degrees). Pass -1.0 to clear and return to auto.
## Owner: cutscenes, abilities.
func set_fov(deg: float) -> void:
	if _camera_rig:
		_camera_rig.set_fov(deg)


## Adds a shake impulse (0..1) on top of any existing trauma.
## Owner: cutscenes, abilities, game layer.
func add_shake(amount: float) -> void:
	if _camera_rig:
		_camera_rig.add_shake(amount)


## Enables/disables the automatic FOV and shake curves.
## Owner: game layer (cutscenes may disable auto while controlling manually).
func set_effects_enabled(enabled: bool) -> void:
	if _camera_rig:
		_camera_rig.set_effects_enabled(enabled)


# --- Tier 2: model fade (dithered transparency) ---------------------------------
# Subsystem: CharacterPresenter (via CameraRig for proximity fade, or direct).


## Manual model fade (0 = visible, 1 = invisible). Owner: cutscenes, abilities.
## The automatic proximity fade (camera close) is normally handled by CameraRig;
## this verb allows manual control for scripted sequences.
func set_model_fade(amount: float) -> void:
	if _presenter != null:
		_presenter.set_fade(amount)


# --- Tier 2: animation override -----------------------------------------------
# Subsystem: PlayerBlackboard + AnimationController. While set, the
# AnimationController plays the override instead of the FSM's anim_state.
# The FSM keeps writing anim_state underneath; clearing the override resumes
# it without a hitch.


## Force a specific AnimationTree state (e.g. &"wave"). Owner: cutscenes,
## emote abilities. Pass &"" to clear and return control to the FSM.
func override_anim_state(anim: StringName) -> void:
	_bb.anim_state_override = anim


func clear_anim_override() -> void:
	_bb.anim_state_override = &""


func get_anim_state() -> StringName:
	return _bb.anim_state


# --- Tier 3: extension verbs --------------------------------------------------
# Auxiliary nodes can publish their own verbs without PlayerApi knowing about
# them. Register a Callable; other systems call it via call_verb.


## Register an extension verb. Owner: any auxiliary node that wants to expose
## an action through the central api surface. Unregister on free().
func register_verb(name: StringName, callable: Callable) -> void:
	_verbs[name] = callable


func unregister_verb(name: StringName) -> void:
	_verbs.erase(name)


func has_verb(name: StringName) -> bool:
	return _verbs.has(name)


## Call an extension verb. args is a flat Array passed positionally.
## Returns the Callable's result, or null if the verb is not registered.
func call_verb(name: StringName, args: Array = []) -> Variant:
	if not _verbs.has(name):
		return null
	return _verbs[name].callv(args)
