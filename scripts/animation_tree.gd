extends AnimationTree

@onready var manager = $"../../PlayerManager"
@onready var playback: AnimationNodeStateMachinePlayback = get("parameters/playback")

var was_grounded := true

func _ready() -> void:
	active = true
	playback.start("idle")

func _process(_delta: float) -> void:
	var grounded: bool = manager.is_grounded
	var current: String = playback.get_current_node()

	# -- Detectar aterrizaje --
	if grounded and not was_grounded:
		was_grounded = true
		if current != "land":
			playback.travel("land")
		_sync_state(current)
		return

	was_grounded = grounded

	# -- En animación de landing --
	if current == "land":
		if not grounded:
			_travel_air()
		else:
			var length := playback.get_current_length()
			if length > 0.0 and playback.get_current_play_position() >= length - 0.05:
				playback.travel(_ground_anim())
		_sync_state(current)
		return

	# -- En el aire --
	if not grounded:
		_travel_air()
		_sync_state(playback.get_current_node())
		return

	# -- En el suelo --
	var target := _ground_anim()
	if current != target:
		playback.travel(target)
	_sync_state(playback.get_current_node())

func _travel_air() -> void:
	var target := "jump" if manager.velocity_y > 0.0 else "fall"
	if playback.get_current_node() != target:
		playback.travel(target)

func _ground_anim() -> String:
	if manager.has_horizontal_input:
		return "run" if manager.is_running else "walk"
	return "idle"

func _sync_state(node: String) -> void:
	match node:
		"idle":  manager.state = manager.State.IDLE
		"walk":  manager.state = manager.State.WALKING
		"run":   manager.state = manager.State.RUNNING
		"jump":  manager.state = manager.State.JUMPING
		"fall":  manager.state = manager.State.FALLING
		"land":  manager.state = manager.State.LANDING
