## Tuning data for stair step detection and resolution. Pure data.
## `base_max_step_up` is an independent knob; the resolved config scales it
## proportionally to the character's body height (see ResolvedPlayerConfig).
class_name StairConfig
extends Resource

@export_group("Step Up")
## Maximum height the body can step up in a single shape-test iteration.
## Scaled by body_height at resolve time (reference height = 1.59m).
@export var base_max_step_up := 0.5

@export_group("Detection")
## Number of incremental height probes when attempting a step-up.
@export var step_check_iterations := 6
## Minimum horizontal motion (m) required to bother checking for a step.
@export var min_horizontal_motion := 0.001
