## Project-specific audio helpers (moved out of the old PlayerManager).
class_name PlayerAudio
extends Node

## Plays a positional one-shot sound in the world.
func play_sound(sound: AudioStream, sound_position: Vector3) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = sound
	player.position = sound_position
	player.top_level = true
	get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

## Plays a non-positional one-shot sound for the local player.
func play_local_sound(sound: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = sound
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player
