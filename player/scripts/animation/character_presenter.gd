## Base class for a character's visual/animation presentation layer. Each
## character model scene (e.g. character_scene.tscn for Teto) has a script on
## its root node that extends this class. The Player coordinator finds the
## presenter by node and calls setup_presenter(); it never reaches into the
## presenter's internal node tree (AnimationTree, AnimationPlayer, etc.).
##
## This is what makes the player character-agnostic: swapping characters is
## swapping a scene that extends CharacterPresenter. The player layer does
## not know about AnimationTree paths, skeleton names, or model structure.
##
## Subclass responsibilities:
##   - Own its AnimationTree, AnimationPlayer, AnimationDriver, shaders, etc.
##   - Implement setup_presenter() to wire them with the blackboard + resolved.
##   - Implement get_skeleton() if the character has one (for future IK).
##
## Model fade: set_fade(amount) applies a dedicated dither fade shader as a
## temporary material_override on every MeshInstance3D. The original material
## is restored when fade returns to 0, so the toon shader (or any other
## material) is never overwritten or bugged. The ProximityFadeController
## (child of CameraRig) raycasts against the Area3D nodes returned by
## get_fade_areas() to decide the fade amount based on camera distance.
class_name CharacterPresenter
extends Node3D

const FADE_SHADER := preload("res://player/character/shaders/fade_dither.gdshader")

var _bb: PlayerBlackboard
var _fade_amount: float = 0.0
var _original_overrides: Dictionary = {}
var _original_visibilities: Dictionary = {}
var _fade_materials: Dictionary = {}

## Called by Player._ready() after the blackboard and resolved config are
## built. Subclasses wire their internal animation/audio nodes here, then
## call super.setup_presenter().
func setup_presenter(bb: PlayerBlackboard, _resolved: ResolvedPlayerConfig) -> void:
	_bb = bb

## The character's skeleton, or null if it has none. Used by future systems
## (procedural foot IK) that need bone access without knowing the rig.
## Override in subclasses.
func get_skeleton() -> Skeleton3D:
	return null

## Sets the model fade amount (0 = fully visible, 1 = fully invisible).
## The base implementation applies a dedicated fade shader
## (Bayer dither pattern) as MeshInstance3D.material_override only while
## fading. The original material_override is restored at fade = 0.
## It also keeps setting "fade_alpha" on any existing ShaderMaterials for
## backwards compatibility with shaders that already support it.
## Subclasses may override for custom fade behaviour.
func set_fade(amount: float) -> void:
	_fade_amount = clampf(amount, 0.0, 1.0)
	var alpha := 1.0 - _fade_amount
	for child in find_children("*", "MeshInstance3D"):
		var mi: MeshInstance3D = child
		_apply_fade_to_materials(mi, alpha)
		_apply_fade_override(mi, alpha)

## Applies the fade alpha to a MeshInstance3D's override and surface materials.
func _apply_fade_to_materials(mi: MeshInstance3D, alpha: float) -> void:
	if mi.material_override is ShaderMaterial:
		(mi.material_override as ShaderMaterial).set_shader_parameter("fade_alpha", alpha)
	for i in range(mi.get_surface_override_material_count()):
		var mat := mi.get_surface_override_material(i)
		if mat is ShaderMaterial:
			(mat as ShaderMaterial).set_shader_parameter("fade_alpha", alpha)

## Applies or removes the dedicated fade material override on the mesh.
func _apply_fade_override(mi: MeshInstance3D, alpha: float) -> void:
	if _fade_amount > 0.0:
		if not _original_overrides.has(mi):
			_original_overrides[mi] = mi.material_override
			_original_visibilities[mi] = mi.visible

		# Completely hide the mesh at 100% fade (alpha = 0.0) to prevent any
		# inner-model camera clipping and optimize rendering.
		mi.visible = _original_visibilities[mi] if alpha > 0.0 else false

		var fade_mat: ShaderMaterial = _get_or_create_fade_material(mi)
		fade_mat.set_shader_parameter("fade_alpha", alpha)
		if mi.material_override != fade_mat:
			mi.material_override = fade_mat
	else:
		if _original_overrides.has(mi):
			var original: Material = _original_overrides[mi]
			if mi.material_override == _fade_materials.get(mi):
				mi.material_override = original
			mi.visible = _original_visibilities[mi]
			_original_overrides.erase(mi)
			_original_visibilities.erase(mi)

func _get_or_create_fade_material(mi: MeshInstance3D) -> ShaderMaterial:
	if _fade_materials.has(mi):
		return _fade_materials[mi]
	var fade_mat := ShaderMaterial.new()
	fade_mat.shader = FADE_SHADER
	var tex := _extract_albedo_texture(mi)
	if tex != null:
		fade_mat.set_shader_parameter("albedo_texture", tex)
	_fade_materials[mi] = fade_mat
	return fade_mat

func _extract_albedo_texture(mi: MeshInstance3D) -> Texture2D:
	var override := mi.material_override
	if override is ShaderMaterial:
		var tex: Variant = (override as ShaderMaterial).get_shader_parameter("albedo_texture")
		if tex is Texture2D:
			return tex
	elif override is StandardMaterial3D:
		return (override as StandardMaterial3D).albedo_texture

	var mesh := mi.mesh
	if mesh == null:
		return null
	for i in range(mesh.get_surface_count()):
		var surf_mat := mesh.surface_get_material(i)
		if surf_mat is StandardMaterial3D:
			return (surf_mat as StandardMaterial3D).albedo_texture
		if surf_mat is ShaderMaterial:
			var tex: Variant = (surf_mat as ShaderMaterial).get_shader_parameter("albedo_texture")
			if tex is Texture2D:
				return tex
	return null

## Returns all Area3D children of the presenter (used by
## ProximityFadeController for raycast-based fade detection). Override in
## subclasses to return a specific subset if needed.
func get_fade_areas() -> Array[Area3D]:
	var areas: Array[Area3D] = []
	for child in find_children("*", "Area3D"):
		areas.append(child)
	return areas
