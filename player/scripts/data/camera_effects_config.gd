## Tuning data for dynamic camera effects (FOV and shake). Pure data.
## When enabled, the CameraRig automatically adjusts FOV based on speed/fall
## and applies shake on landing/running. Manual overrides via PlayerApi
## (set_fov, add_shake) take precedence over the automatic curves.
class_name CameraEffectsConfig
extends Resource

@export_group("Toggle")
@export var enabled: bool = true

@export_group("FOV")
## Base FOV in degrees (when no speed/fall influence).
@export var base_fov: float = 75.0
## FOV increase (degrees) at full run speed.
@export_range(0.0, 30.0, 0.5) var run_fov_add: float = 8.0
## FOV increase (degrees) at maximum fall speed (terminal velocity feel).
@export_range(0.0, 30.0, 0.5) var fall_fov_add: float = 12.0
## How fast the FOV eases toward its target (lerp factor).
@export_range(1.0, 30.0, 0.5) var fov_lerp_speed: float = 6.0
## Fall speed (m/s) at which fall_fov_add reaches its full value.
@export var fall_speed_for_max_fov: float = 20.0

@export_group("Shake")
## Shake amplitude (m) at the hardest landing. Scaled by fall distance.
## Reduced from 0.08 — the wind-resistance tilt is the primary effect now.
@export_range(0.0, 1.0, 0.01) var land_shake_amount: float = 0.02
## How long the landing shake takes to decay (seconds).
@export_range(0.0, 2.0, 0.05) var land_shake_duration: float = 0.3
## Fall distance at which land_shake_amount reaches its full value.
@export var fall_distance_for_max_shake: float = 5.0
## Continuous run-shake amplitude (m) at full run speed.
@export_range(0.0, 0.1, 0.005) var run_shake_amount: float = 0.005
## Run-shake frequency (Hz).
@export_range(0.0, 30.0, 0.5) var shake_frequency: float = 12.0

@export_group("Fall Shake")
## How fast the fall shake ramps up while airborne (per second of fall).
@export_range(0.0, 2.0, 0.05) var fall_shake_ramp_speed: float = 0.3
## Maximum fall shake amplitude (m). Caps the continuous build-up.
@export_range(0.0, 0.1, 0.005) var fall_shake_max: float = 0.03

@export_group("Tilt")
## Camera tilt (degrees) at full shake — simulates wind resistance ladeo.
@export_range(0.0, 15.0, 0.5) var tilt_amount: float = 2.0
## Tilt frequency (Hz) — how fast the camera wobbles.
@export_range(0.0, 10.0, 0.5) var tilt_frequency: float = 3.0

@export_group("Land FOV Kick")
## Extra FOV (degrees) added on landing impact, decays with land_shake_duration.
@export_range(0.0, 15.0, 0.5) var land_fov_kick: float = 3.0
