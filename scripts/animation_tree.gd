extends AnimationTree

@onready var manager : Node     = $"../../PlayerManager"
@onready var blocker : Node3D   = $"../AnimationBlocker"
@onready var playback: AnimationNodeStateMachinePlayback = get("parameters/playback")

var was_grounded   := true
var last_air_vel_y := 0.0
var block_animations := false
var current_anim   := "" # Mantiene un registro exacto de la animación solicitada

func _ready() -> void:
	active = true
	_travel_to("idle", true)
	manager.window_focus_changed.connect(_go_idle)

func _go_idle(status: bool) -> void:
	block_animations = !status
	# Solo forzamos 'idle' si estamos en el suelo. Si estamos cayendo,
	# dejamos que la gravedad y _process sigan su curso natural.
	if block_animations and manager.is_grounded:
		_travel_to("idle")

func _process(_delta: float) -> void:
	var grounded: bool = manager.is_grounded
	if not grounded:
		last_air_vel_y = manager.velocity_y

	var landed := grounded and not was_grounded
	was_grounded = grounded  # ← siempre actualiza antes de cualquier return

	if landed:
		if last_air_vel_y < -1.0 or last_air_vel_y > 0.1:
			_travel_to("land")
			return

	if current_anim == "land":
		if not grounded:
			if not (manager.is_stepping or manager.is_stepping_down):
				_travel_air()
		else:
			var length := playback.get_current_length()
			if length > 0.0 and playback.get_current_play_position() >= length - 0.05:
				_travel_to(_ground_anim())
		return

	if not grounded:
		_travel_air()
	else:
		_travel_to(_ground_anim())
	was_grounded = grounded

	if current_anim == "land":
		if not grounded:
			if not (manager.is_stepping or manager.is_stepping_down):
				_travel_air()
		else:
			var length := playback.get_current_length()
			if length > 0.0 and playback.get_current_play_position() >= length - 0.05:
				_travel_to(_ground_anim())
		return

	# La lógica sigue fluyendo independientemente de si hay foco en la ventana o no.
	if not grounded:
		_travel_air()
	else:
		_travel_to(_ground_anim())

func _travel_air() -> void:
	if manager.is_stepping or manager.is_stepping_down:
		return

	# Usamos 0.1 para que la animación de salto se mantenga hasta llegar al ápice
	if manager.velocity_y > 0.1:
		_travel_to("jump")
		return

	if blocker.keep_current_anim():
		return

	if blocker.skip_to_land():
		if current_anim == "fall":
			_travel_to(_ground_anim())
		return

	_travel_to("fall")

func _ground_anim() -> String:
	# Si bloqueamos las animaciones, forzamos que se quede quieto al tocar el piso
	if block_animations:
		return "idle"
	if manager.has_horizontal_input:
		return "run" if manager.is_running else "walk"
	return "idle"

# Función de ayuda que evita los bucles de reinicio de transiciones
func _travel_to(anim: String, start_immediately: bool = false) -> void:
	if current_anim != anim:
		current_anim = anim
		if start_immediately:
			playback.start(anim)
		else:
			playback.travel(anim)
		_sync_state(anim)

func _sync_state(node: String) -> void:
	match node:
		"idle": manager.state = manager.State.IDLE
		"walk": manager.state = manager.State.WALKING
		"run":  manager.state = manager.State.RUNNING
		"jump": manager.state = manager.State.JUMPING
		"fall": manager.state = manager.State.FALLING
		"land": manager.state = manager.State.LANDING
