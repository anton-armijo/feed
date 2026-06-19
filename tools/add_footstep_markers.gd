@tool
extends SceneTree

## One-time migration script: writes footstep markers and speed-driven flags
## as metadata into the Animation .res files used by character_scene.tscn.
##
## Usage: godot --headless --script tools/add_footstep_markers.gd
##
## After running, AnimationDriver loads markers from the .res metadata
## instead of from hardcoded constants. This script can be deleted once the
## migration is confirmed.
const MARKERS := {
	"walk": [
		{time = 0.1069, name = &"step_1"},
		{time = 0.4746, name = &"step_2"},
	],
	"run": [
		{time = 0.0667, name = &"step_1"},
		{time = 0.3500, name = &"step_2"},
	],
	"land": [
		{time = 0.1013, name = &"landed"},
	],
}

const SPEED_DRIVEN := ["walk", "run"]

const ANIM_PATHS := [
	"res://player/character/animations/fall.res",
	"res://player/character/animations/idle.res",
	"res://player/character/animations/jump.res",
	"res://player/character/animations/land.res",
	"res://player/character/animations/run.res",
	"res://player/character/animations/walk.res",
]

func _init() -> void:
	_run()

func _run() -> void:
	for path in ANIM_PATHS:
		var anim: Animation = load(path)
		if anim == null:
			push_error("Could not load %s" % path)
			continue
		var name: String = path.get_file().get_basename()
		if MARKERS.has(name):
			anim.set_meta("footstep_markers", MARKERS[name])
			print("%s: set %d markers" % [name, MARKERS[name].size()])
		if name in SPEED_DRIVEN:
			anim.set_meta("speed_driven", true)
			print("%s: speed_driven = true" % name)
		var err := ResourceSaver.save(anim, path)
		if err != OK:
			push_error("Failed to save %s: %d" % [path, err])
	print("Migration complete.")
	quit()
