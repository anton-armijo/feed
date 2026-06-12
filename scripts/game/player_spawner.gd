extends MultiplayerSpawner

@export var player_scene: PackedScene = load("res://prefabs/player_instance.tscn")
@export var spawn_location: Node3D

func spawn_player():
	var player = player_scene.instantiate()
	spawn_location.add_child(player)

func _ready() -> void:
	if multiplayer.is_server():
		spawn_player()
