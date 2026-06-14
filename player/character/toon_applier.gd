extends Node

const TRANSPARENCY_ALPHA_SCISSOR := 2
const TRANSPARENCY_ALPHA_DEPTH_PRE_PASS := 4

@export_category("Toon")
@export var toon_offset: float = 0.4
@export var toon_smoothness: float = 0.7
@export var min_light: float = 0.25

@export_category("Specular")
@export var specular_strength: float = 0.3
@export var specular_size: float = 64.0

@export_category("Rim")
@export var rim_power: float = 3.0
@export var rim_brightness: float = 0.4

var _shader: Shader

func _ready() -> void:
	_shader = load("uid://ehnotxo15ybn")
	_apply_toon()

func _apply_toon() -> void:
	var siblings = get_parent().find_children("*", "MeshInstance3D")
	for mesh_instance: MeshInstance3D in siblings:
		var mesh = mesh_instance.mesh
		if not mesh:
			continue

		if mesh_instance.material_override:
			mesh_instance.material_override = _make_toon(mesh_instance.material_override)
			continue

		for i in range(mesh.get_surface_count()):
			var old_mat = mesh_instance.get_surface_override_material(i)
			if not old_mat:
				old_mat = mesh.surface_get_material(i)
			if not old_mat:
				continue
			mesh_instance.set_surface_override_material(i, _make_toon(old_mat))

func _make_toon(old_mat: Material) -> ShaderMaterial:
	var new_mat := ShaderMaterial.new()
	new_mat.shader = _shader

	if old_mat is StandardMaterial3D:
		var std_mat: StandardMaterial3D = old_mat
		new_mat.set_shader_parameter("albedo_texture", std_mat.albedo_texture)

		if std_mat.transparency == TRANSPARENCY_ALPHA_SCISSOR or std_mat.transparency == TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			new_mat.set_shader_parameter("use_alpha_scissor", true)
			new_mat.set_shader_parameter("alpha_scissor_threshold", std_mat.alpha_scissor_threshold)

		if std_mat.normal_enabled and std_mat.normal_texture:
			new_mat.set_shader_parameter("custom_normal", std_mat.normal_texture)
			new_mat.set_shader_parameter("use_normal_map", true)

		if std_mat.emission_enabled and std_mat.emission_texture:
			new_mat.set_shader_parameter("custom_emission", std_mat.emission_texture)
			new_mat.set_shader_parameter("use_emission_map", true)

		if std_mat.roughness_texture:
			new_mat.set_shader_parameter("roughness_texture", std_mat.roughness_texture)
			new_mat.set_shader_parameter("use_roughness_map", true)
		else:
			new_mat.set_shader_parameter("roughness_value", std_mat.roughness)
	elif old_mat.has("albedo_texture"):
		new_mat.set_shader_parameter("albedo_texture", old_mat.get("albedo_texture"))

	new_mat.set_shader_parameter("toon_offset", toon_offset)
	new_mat.set_shader_parameter("toon_smoothness", toon_smoothness)
	new_mat.set_shader_parameter("min_light", min_light)
	new_mat.set_shader_parameter("specular_strength", specular_strength)
	new_mat.set_shader_parameter("specular_size", specular_size)
	new_mat.set_shader_parameter("rim_power", rim_power)
	new_mat.set_shader_parameter("rim_brightness", rim_brightness)

	return new_mat
