## Aggregate configuration for a character. The Player coordinator owns one of
## these and injects the relevant sub-resources into each component.
class_name PlayerConfig
extends Resource

@export_group("Body")
@export var body_height := 1.59
## Character weight in kilograms. Drives derived values like model turn speed
## (heavier = slower turn). Reference weight is 70 kg (average human adult).
## Teto weighs 47 kg.
@export var weight := 47.0

@export var locomotion: LocomotionConfig
@export var jump: JumpConfig
@export var camera: CameraConfig
@export var camera_effects: CameraEffectsConfig
@export var stair: StairConfig
@export var probe: ProbeConfig
@export var components: PlayerComponentsConfig
@export var foot_ik: FootIKConfig

## Miscelaneos per-character configs for auxiliary nodes (aura effects, custom
## visual configs, etc.). Each auxiliary node searches this array for its
## config type during setup(). PlayerConfig stays agnostic of the concrete
## types — it only carries the array.
@export var extras: Array[Resource] = []

## Guarantees every sub-resource exists so components never null-check configs.
func ensure_defaults() -> void:
	if locomotion == null:
		locomotion = LocomotionConfig.new()
	if jump == null:
		jump = JumpConfig.new()
	if camera == null:
		camera = CameraConfig.new()
	if camera_effects == null:
		camera_effects = CameraEffectsConfig.new()
	if stair == null:
		stair = StairConfig.new()
	if probe == null:
		probe = ProbeConfig.new()
	if components == null:
		components = PlayerComponentsConfig.new()
	if foot_ik == null:
		foot_ik = FootIKConfig.new()
