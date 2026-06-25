## Tuning data for stair step detection and resolution. Pure data.
## `max_step_up` is body_height * max_step_up_ratio — no reference height needed.
class_name StairConfig
extends Resource

@export_group("Step Up")
## Fraction of body height usable as maximum step-up height.
## Default 0.314 ≈ 0.5m step for a 1.59m character.
@export_range(0.1, 0.6, 0.001) var max_step_up_ratio := 0.314

func compute_max_step_up(body_height: float) -> float:
	return body_height * max_step_up_ratio

@export_group("Detection")
## Number of incremental height probes when attempting a step-up.
@export var step_check_iterations := 6
## Minimum horizontal motion (m) required to bother checking for a step.
@export var min_horizontal_motion := 0.001
