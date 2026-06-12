extends Node3D

@export var spawn_area: CollisionShape3D
@export var collectible_scene: PackedScene
@export var bread_amount := 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for a in bread_amount:
		spawn_collectible()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func spawn_collectible():
	var collectible = collectible_scene.instantiate()

	collectible.global_position = (
		spawn_area.global_position +
		get_random_position()
	)

	add_child(collectible)

	collectible.collected.connect(_on_collectible_collected)


func get_random_position() -> Vector3:
	var shape = spawn_area.shape

	# BOX
	if shape is BoxShape3D:
		var size = shape.size

		return Vector3(
			randf_range(-size.x / 2, size.x / 2),
			randf_range(-size.y / 2, size.y / 2),
			randf_range(-size.z / 2, size.z / 2)
		)

	# CYLINDER
	elif shape is CylinderShape3D:
		var radius = shape.radius
		var height = shape.height

		var angle = randf() * TAU
		var distance = sqrt(randf()) * radius

		return Vector3(
			cos(angle) * distance,
			randf_range(-height / 2, height / 2),
			sin(angle) * distance
		)

	# Fallback
	return Vector3.ZERO


func _on_collectible_collected():
	spawn_collectible()
