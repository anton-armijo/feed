extends Area3D

@export var reset_to_spawn := true
@export var custom_reset_position := Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	
	var target := Vector3.ZERO
	if reset_to_spawn:
		var spawn := _find_spawn_point()
		if spawn:
			target = spawn.global_position + Vector3.UP * 0.5
		else:
			target = Vector3(0, 2, 0)
	else:
		target = custom_reset_position + Vector3.UP * 0.5
	
	body.global_position = target
	if body.velocity:
		body.velocity = Vector3.ZERO
	print("[WorldBoundary] Player %s reset to %s" % [body.name, target])

func _find_spawn_point() -> Node3D:
	var spawners := get_tree().get_nodes_in_group("player_spawner")
	for spawner in spawners:
		var point := spawner.get_node_or_null("SpawnPoint")
		if point and point is Node3D:
			return point
	
	for node in get_tree().get_nodes_in_group("spawn_point"):
		if node is Node3D:
			return node
	
	return null
