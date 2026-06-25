## Per-animation IK influence profile. Defines how Foot IK strength varies
## over time for a specific animation clip.
##
## Modes:
##   CONSTANT  — fixed value (idle)
##   ZERO      — always 0 (jump, fall)
##   FOOTSTEP  — curve evaluated relative to footstep markers (walk, run)
##              X=0 at the nearest footstep (max influence),
##              X=1 at the midpoint between footsteps (min influence)
##   LAND      — ramp from 0→1 after the landing marker (land)
class_name IKInfluenceProfile
extends Resource

enum Mode {
	CONSTANT,
	ZERO,
	FOOTSTEP,
	LAND,
}

@export var mode: Mode = Mode.CONSTANT

## Only for Mode.CONSTANT
@export_range(0.0, 1.0) var constant_value: float = 1.0

## Curve sampled over [0, 1]:
##   FOOTSTEP → X=0 at footstep, X=1 at midpoint between footsteps
##   LAND     → X=0 just after landing marker, X=1 at animation end
@export var curve: Curve
