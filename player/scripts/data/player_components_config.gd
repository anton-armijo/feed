## Toggles every optional component and FSM state inside the Player prefab.
## Owned by PlayerConfig; consumed by PlayerAssembler (_ready()) and
## Player._ready() wiring.
class_name PlayerComponentsConfig
extends Resource

@export_group("Nodes")
@export var enable_input := true
@export var enable_stair_stepper := true
@export var enable_camera := true
@export var enable_model := true
@export var enable_footsteps := true
@export var enable_abilities := true
@export var enable_multiplayer_sync := true

@export_group("FSM states")
@export var enable_sprint := true
@export var enable_jump := true
