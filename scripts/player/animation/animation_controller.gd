extends AnimationTree
@onready var manager : Node     = $"../../PlayerManager"
@onready var blocker : Node3D   = $"../AnimationBlocker"
@onready var playback: AnimationNodeStateMachinePlayback = get("parameters/playback")

var was_grounded     := true
var last_air_vel_y   := 0.0
var block_animations := false
var current_anim     := ""

var fall_distance_accumulator := 0.0

# Umbrales proporcionales a body_height (calculados en _ready)
var thresh_land      := 0.30   # Distancia mínima de caída para activar animación de aterrizaje
var thresh_fall_anim := 0.80   # Distancia de caída para mostrar animación de caída en el aire
var thresh_land_vel  := -2.43  # Velocidad equivalente a caer thresh_land en caída libre

func _ready() -> void:
	active = true
	_travel_to("idle", true)
	manager.window_focus_changed.connect(_go_idle)
	# Proporcional a la altura del personaje
	var bh: float = manager.body_height
	thresh_land      = bh * 0.19                        # ≈ 0.30 m con bh=1.59
	thresh_fall_anim = bh * 0.50                        # ≈ 0.80 m con bh=1.59
	thresh_land_vel  = -sqrt(2.0 * 9.8 * thresh_land)   # Velocidad de caída libre desde thresh_land

func _go_idle(status: bool) -> void:
	block_animations = !status
	if block_animations and manager.is_grounded:
		_travel_to("idle")

func _process(delta: float) -> void:
	var grounded: bool = manager.is_grounded

	# Acumular distancia de caída sólo al descender
	if not grounded:
		last_air_vel_y = manager.velocity_y
		if manager.velocity_y < 0.0:
			fall_distance_accumulator += abs(manager.velocity_y) * delta

	# Aterrizaje: evaluar ANTES de resetear el acumulador
	var landed := grounded and not was_grounded
	was_grounded = grounded

	if landed:
		var fd := fall_distance_accumulator
		fall_distance_accumulator = 0.0
		if fd > thresh_land or last_air_vel_y < thresh_land_vel or last_air_vel_y > 0.1:
			_travel_to("land")
			return

	if grounded:
		fall_distance_accumulator = 0.0  # Reset de seguridad en frames sostenidos en suelo

	# Esperar a que termine la animación de aterrizaje
	if current_anim == "land":
		if not grounded:
			if not (manager.is_stepping or manager.is_stepping_down):
				_travel_air()
		else:
			var length := playback.get_current_length()
			if length > 0.0 and playback.get_current_play_position() >= length - 0.05:
				_travel_to(_ground_anim())
		return

	# Selección de animación aire / suelo
	if not grounded:
		if manager.velocity_y > 0.1 or current_anim in ["jump", "fall"]:
			# Subiendo (salto) o continuando una animación aérea ya activa
			_travel_air()
		elif fall_distance_accumulator >= thresh_fall_anim:
			# Caída suficientemente larga para mostrar animación aérea
			_travel_air()
		else:
			# Caída pequeña: mantener animación de suelo
			_travel_to(_ground_anim())
	else:
		_travel_to(_ground_anim())

	_sync_state(current_anim)

func _travel_air() -> void:
	if manager.is_stepping or manager.is_stepping_down:
		return
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
	if block_animations:
		return "idle"
	if manager.has_horizontal_input:
		return "run" if manager.is_running else "walk"
	return "idle"

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
