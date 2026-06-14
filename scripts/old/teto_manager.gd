extends Node3D

@export var click_sound: AudioStreamMP3

@export var base_scale: float = 0.05
@export var progress_scale_bonus: float = 1.3
@export var size_per_percentage: float = 3.0

#signal state_updated(state: LevelData)
#func get_state() -> LevelData:
	#return LevelData.new(level, progress, required_points, percentage, total_points)

var owner_id: int

var level: int = 1
var progress: float = 0
var percentage: float:
	get:
		if required_points <= 0.0:
			return 0.0
		return round((float(progress) / required_points) * 10000.0) / 10000.0
var absoule_percentage: float:
	get: return percentage + level

func points_for_level(value: int) -> float:
	return pow(3.0, value)
	
var required_points: float:
	get: return points_for_level(level)
var total_points: float:
	get:
		var total := progress
		for i in range(1, level):
			total += points_for_level(i)
		return total

var god_mode = true
var print_factor: bool = false
func _input(event):
	if not god_mode:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: set_level(10)
			KEY_2: set_level(20)
			KEY_3: set_level(30)
			KEY_4: set_level(40)
			KEY_5: set_level(50)
			KEY_6: set_level(60)
			KEY_7: set_level(70)
			KEY_8: set_level(80)
			KEY_9: set_level(90)
			KEY_0: set_level(1)


func set_level(new_level: int):
	level = new_level
	progress = 0
	print_factor = true
	#state_updated.emit(get_state())

	print("Level set to: ", level)

func _scale(value: float):
	scale = Vector3(value, value, value)

func update_scale():
	var factor := 1.0 + 0.01 * pow(total_points, 0.25)
	_scale(base_scale * factor)
	if print_factor:
		print(base_scale * factor)
		print_factor = false
 #* progress_scale_bonus * (1 - (float(progress) / required_points))
func _ready() -> void:
	pass

func _process(delta: float) -> void:
	update_scale()

func sv_interact(player_id: int) -> void:
	if not _validate_interact(player_id):
		return
	progress += 1
	if progress >= required_points:
		progress = progress - required_points
		level += 1
	_cl_sync_state(level, progress)

func _validate_interact(_player_id: int) -> bool:
	return true

func _cl_sync_state(new_level: int, new_progress: int) -> void:
	level = new_level
	progress = new_progress
	#state_updated.emit(get_state())
