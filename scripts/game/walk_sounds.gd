extends Node

@export var fsm: LocomotionFSM
@export var audio_player: AudioStreamPlayer

@export_dir var footstep_folder: String = "res://sounds/sound_effects/walk/"
@export var walk_interval: float = 0.5
@export var start_delay: float = 0.3
@export var run_multiplier: float = 1.6
@export_range(0.0, 0.5, 0.01) var variance: float = 0.1

var _sounds: Array = []
var _step_timer: float = 0.0
var _delay_timer: float = 0.0
var _waiting_start: bool = false
var _was_active: bool = false
var _next_interval: float = 0.0

func _ready() -> void:
	_load_sounds()

func _process(delta: float) -> void:
	var state := fsm.current.name
	var is_walking := state == "Walk"
	var is_running  := state == "Run"
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
	var snd = _sounds[randi() % _sounds.size()] if not _sounds.is_empty() else null
	if snd:
		audio_player.stream = snd
		audio_player.pitch_scale = _vary(multiplier)
		audio_player.play()
	_next_interval = _vary(walk_interval / multiplier)
	_step_timer = 0.0

func _vary(value: float) -> float:
	return value * (1.0 + randf_range(-variance, variance))

func _load_sounds() -> void:
	_sounds.clear()
	var dir := DirAccess.open(footstep_folder)
	if not dir:
		push_warning("FootstepPlayer: no se pudo abrir '%s'" % footstep_folder)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.get_extension().to_lower() in ["wav", "ogg", "mp3"]:
			var stream: AudioStream = load(footstep_folder + fname)
			if stream:
				_sounds.append(stream)
		fname = dir.get_next()
	dir.list_dir_end()
