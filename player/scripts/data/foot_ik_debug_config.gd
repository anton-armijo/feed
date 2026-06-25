class_name FootIKDebugConfig
extends Resource

@export var debug_print_calibration := false
@export var debug_draw_rays := false
@export var debug_draw_targets := false
@export var debug_draw_poles := false
@export var debug_log_frame := false
## Minimum seconds between frame logs (0 = every frame).
@export_range(0.0, 5.0, 0.05) var debug_log_interval := 0.0
@export var debug_detect_oscillation := false
@export_range(3, 60) var debug_oscillation_history_size := 20
@export_range(0.001, 0.5, 0.001) var debug_oscillation_threshold := 0.03
@export var debug_oscillation_min_frames := 6
