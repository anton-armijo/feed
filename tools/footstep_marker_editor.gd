@tool
## One-shot footstep marker authoring helper.
##
## Run from the editor: select this script in the FileSystem dock and press
## Ctrl+Shift+X (Run Script), or Editor > File > Run. It instantiates the
## character scene, samples each locomotion animation's LeftFoot / RightFoot
## global Y across one cycle, finds each foot's contact (lowest) frame and
## writes `footstep_markers` + `speed_driven` metadata back into the binary
## .res animation files.
##
## The FootIkController works WITHOUT these markers (it detects contact
## procedurally), but authored markers give crisper plant timing via the
## bb.footstep signal. Re-run after editing a walk/run cycle.
##
## Marker convention written: [{time, name:"foot_l"}, {time, name:"foot_r"}].
extends EditorScript

const SCENE_PATH := "res://player/character/character_scene.tscn"
const ANIMS := ["walk", "run", "walk_back"]
const SAMPLES := 64
const FOOT_L := "LeftFoot"
const FOOT_R := "RightFoot"


func _run() -> void:
	_author_all()


func _author_all() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("footstep_marker_editor: cannot load %s" % SCENE_PATH)
		return
	var instance := packed.instantiate()
	var tree := EditorInterface.get_base_control().get_tree()
	tree.root.add_child(instance)
	instance.owner = null  # don't pollute the edited scene.

	var skel := instance.get_node("%GeneralSkeleton") as Skeleton3D
	var player := instance.get_node("AnimationPlayer") as AnimationPlayer
	if skel == null or player == null:
		push_error("footstep_marker_editor: skeleton or AnimationPlayer missing")
		instance.queue_free()
		return

	var lib_name: StringName = player.get_animation_library_list()[0]
	var lib := player.get_animation_library(lib_name) as AnimationLibrary
	if lib == null:
		push_error("footstep_marker_editor: animation library missing")
		instance.queue_free()
		return
	for anim_name in ANIMS:
		var anim := lib.get_animation(anim_name) as Animation
		if anim == null:
			continue
		var t_l := _find_contact_time(player, skel, anim_name, anim.length, FOOT_L)
		var t_r := _find_contact_time(player, skel, anim_name, anim.length, FOOT_R)
		var markers: Array = [{"time": t_l, "name": "foot_l"}, {"time": t_r, "name": "foot_r"}]
		anim.set_meta("footstep_markers", markers)
		anim.set_meta("speed_driven", true)
		var err := ResourceSaver.save(anim, anim.resource_path)
		print(
			(
				"footstep_marker_editor: %s -> foot_l@%.3f foot_r@%.3f (save %d)"
				% [anim_name, t_l, t_r, err]
			)
		)

	instance.queue_free()


## Plays `anim_name`, samples `foot_bone`'s global Y at SAMPLES points across
## one cycle, returns the time of the lowest point (the contact frame).
func _find_contact_time(
	player: AnimationPlayer, skel: Skeleton3D, anim_name: String, length: float, foot_bone: String
) -> float:
	var idx := skel.find_bone(foot_bone)
	if idx < 0 or length <= 0.0:
		return 0.0
	player.stop()
	player.play(anim_name)
	var best_t := 0.0
	var best_y := INF
	for i in SAMPLES:
		var t := (float(i) / float(SAMPLES)) * length
		player.seek(t, true)
		var y := skel.get_bone_global_pose(idx).origin.y
		if y < best_y:
			best_y = y
			best_t = t
	player.stop()
	return best_t
