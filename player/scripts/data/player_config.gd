## Aggregate configuration for a character. The Player coordinator owns one of
## these and injects the relevant sub-resources into each component.
class_name PlayerConfig
extends Resource

@export var body_height := 1.59
@export var locomotion: LocomotionConfig
@export var jump: JumpConfig
@export var camera: CameraConfig

## Guarantees every sub-resource exists so components never null-check configs.
func ensure_defaults() -> void:
	if locomotion == null:
		locomotion = LocomotionConfig.new()
	if jump == null:
		jump = JumpConfig.new()
	if camera == null:
		camera = CameraConfig.new()
