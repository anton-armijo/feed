extends Area3D

signal collected

@export var rotation_speed := 6
@export var rotation_interval := 0.067

@export var oscilation_amplitude := 0.2
@export var oscilation_speed := 2
@export var score_value := 1
@export var collect_sound: AudioStream

var time := 0.0
var rotation_timer := 0.0
var init_pos := Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	init_pos = position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time += delta
	rotation_timer += delta
	
	position.y = init_pos.y + sin(time * oscilation_speed) * oscilation_amplitude
	if rotation_timer >= rotation_interval:
		rotate_y(deg_to_rad(rotation_speed))
		rotation_timer = 0.0


func _on_body_entered(body: Node3D) -> void:
	if body.name.to_lower() == "player":
		collected.emit()
		
		GameManager.increment_score(score_value)
		GameManager.play_sound(collect_sound, global_position)
		
		queue_free()
