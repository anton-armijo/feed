## Presentation/navigation layer: owns scene transitions and the mouse mode
## that goes with them (mirrors CameraRig being a local-only presentation
## system). It knows nothing about transport or peers; it only swaps scenes on
## request, reading the target scenes from NetConfig.
class_name SceneFlow
extends Node

var _config: NetConfig

func setup(config: NetConfig) -> void:
	_config = config

func go_to_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_change_scene(_config.menu_scene)

func go_to_game() -> void:
	_change_scene(_config.game_scene)

func _change_scene(scene: PackedScene) -> void:
	if scene == null:
		push_error("[SceneFlow] Target scene is not configured in NetConfig.")
		return
	get_tree().change_scene_to_packed(scene)
