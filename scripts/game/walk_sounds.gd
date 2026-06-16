extends Node

## Reads the replicated locomotion state from the blackboard (not the FSM
## directly): the FSM only runs on the local peer, but the blackboard is synced
## to every peer, so footsteps play correctly for remote players too.
@export var blackboard: PlayerBlackboard
@export var audio_player_2d: AudioStreamPlayer
@export var audio_player_3d: AudioStreamPlayer3D

@export var footstep_sounds: Array[AudioStream]
@export var walk_interval: float = 0.5
@export var start_delay: float = 0.3
@export var run_multiplier: float = 1.6
@export_range(0.0, 0.5, 0.01) var variance: float = 0.1

var _step_timer: float = 0.0
var _delay_timer: float = 0.0
var _waiting_start: bool = false
var _was_active: bool = false
var _next_interval: float = 0.0
var _is_local := false

func _ready() -> void:
	var player := get_parent()
	var owner_id := player.get_multiplayer_authority()
	_is_local = owner_id == multiplayer.get_unique_id() or player.name == str(multiplayer.get_unique_id())

	if _is_local:
		audio_player_3d.queue_free()
	else:
		audio_player_2d.queue_free()

func _process(delta: float) -> void:
	if blackboard == null:
		return
	var state := blackboard.locomotion_state
	var is_walking := state == &"Walk"
	var is_running  := state == &"Run"
	var is_active   := is_walking or is_running
	var multiplier  := run_multiplier if is_running else 1.0

	if is_active:
		if not _was_active:
			_waiting_start = true
			_delay_timer = _vary(start_delay)

		if _waiting_start:
			_delay_timer -= delta
			if _delay_timer <= 0.0:
				_waiting_start = false
				_play_step(multiplier)
		else:
			_step_timer += delta
			if _step_timer >= _next_interval:
				_play_step(multiplier)
	else:
		_waiting_start = false
		_step_timer = 0.0

	_was_active = is_active

func _play_step(multiplier: float) -> void:
	var snd = footstep_sounds[randi() % footstep_sounds.size()] if not footstep_sounds.is_empty() else null
	if snd:
		var player = audio_player_2d if _is_local else audio_player_3d
		player.stream = snd
		player.pitch_scale = _vary(multiplier)
		player.play()
	_next_interval = _vary(walk_interval / multiplier)
	_step_timer = 0.0

func _vary(value: float) -> float:
	return value * (1.0 + randf_range(-variance, variance))
