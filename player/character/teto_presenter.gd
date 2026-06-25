## Teto character presenter. Owns the AnimationTree (AnimationController),
## AnimationDriver, and ToonApplier for the Kasane Teto model. The player
## layer calls setup_presenter() and never touches the internal node paths.
class_name TetoPresenter
extends CharacterPresenter

@onready var _anim_controller: AnimationController = $AnimationTree
@onready var _anim_driver: AnimationDriver = $AnimationDriver


func setup_presenter(bb: PlayerBlackboard, config: PlayerConfig) -> void:
	_scan_directional_states(bb)
	super.setup_presenter(bb, config)


## Scans the AnimationTree's root state machine for state names containing "_"
## and publishes them to the blackboard. The FSM's resolve_anim() uses this set
## to route to directional clips (e.g. &"walk_back") without knowing the
## character's rig. Start/End pseudo-states are excluded.
func _scan_directional_states(bb: PlayerBlackboard) -> void:
	var root: AnimationNode = _anim_controller.tree_root
	if root is AnimationNodeStateMachine:
		var sm: AnimationNodeStateMachine = root
		var found: Array[StringName] = []
		for node_name: StringName in sm.get_node_list():
			if node_name == &"Start" or node_name == &"End":
				continue
			if String(node_name).contains("_"):
				found.append(node_name)
		bb.directional_anim_states = found


func get_skeleton() -> Skeleton3D:
	return $Armature/GeneralSkeleton
