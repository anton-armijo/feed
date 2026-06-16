extends Node

@export var sound: AudioStream
@export var click_receiver_path: NodePath
@export var sound_delay: float = 0.5

var _receiver: Node

func _ready() -> void:
	_receiver = _find_receiver()
	if _receiver:
		_receiver.interacted.connect(_on_interacted)

func _find_receiver() -> Node:
	if not click_receiver_path.is_empty():
		return get_node_or_null(click_receiver_path)
	var parent := get_parent()
	for child in parent.get_children():
		if child != self and child.has_signal("interacted"):
			return child
	return null

func _on_interacted(_player_id: int) -> void:
	_play_sound()
	if multiplayer.multiplayer_peer != null:
		_rpc_play_sound.rpc()

func _play_sound() -> void:
	if sound == null or _receiver == null:
		return
	var pos = _receiver.global_position
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.position = pos
	player.top_level = true
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_play_sound() -> void:
	_play_sound()
