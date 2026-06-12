## Base class for per-ability tuning data. Concrete abilities define their own
## subclass (e.g. SprintConfig with a speed multiplier).
class_name AbilityConfig
extends Resource

## Whether the ability starts enabled when registered.
@export var enabled_by_default := true
