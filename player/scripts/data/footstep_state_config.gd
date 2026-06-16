class_name FootstepStateConfig
extends Resource

@export var locomotion_state: StringName = &""
@export var sound_pool: Array[AudioStream] = []
@export var base_interval_ms: float = 500.0
@export var pitch_range: Vector2 = Vector2(0.95, 1.05)
@export var volume_db_base: float = -2.0
@export var foot_bias_strength: float = 0.03
@export var groove_swing: float = 0.02
@export var enabled: bool = true
