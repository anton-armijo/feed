shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D custom_normal : hint_normal, filter_linear_mipmap;
uniform bool use_normal_map = false;
uniform sampler2D custom_emission : source_color, filter_linear_mipmap;
uniform bool use_emission_map = false;
uniform bool use_alpha_scissor = false;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D roughness_texture : source_color, filter_linear_mipmap;
uniform bool use_roughness_map = false;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.5;

group_uniforms Toon;
uniform float toon_offset : hint_range(0.0, 1.0) = 0.4;
uniform float toon_smoothness : hint_range(0.001, 1.0) = 0.2;
uniform float min_light : hint_range(0.0, 0.8) = 0.35;
group_uniforms;

group_uniforms Specular;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.3;
uniform float specular_size : hint_range(1.0, 512.0) = 64.0;
group_uniforms;

group_uniforms Rim;
uniform float rim_power : hint_range(0.0, 10.0) = 3.0;
uniform float rim_brightness : hint_range(0.0, 2.0) = 0.2;
group_uniforms;

group_uniforms Fade;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;

	if (use_alpha_scissor) {
		ALPHA = tex.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	} else {
		ALPHA = fade_alpha;
	}

	if (use_normal_map) {
		NORMAL_MAP = texture(custom_normal, UV).xyz;
	}

	if (use_emission_map) {
		EMISSION = texture(custom_emission, UV).rgb;
	}

	float roughness = roughness_value;
	if (use_roughness_map) {
		roughness = texture(roughness_texture, UV).r;
	}
	ROUGHNESS = roughness;
}

void light() {
	float d = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float roughness = ROUGHNESS;
	float effective_smoothness = toon_smoothness + roughness * 0.5;
	float toon_ramp = smoothstep(toon_offset, toon_offset + effective_smoothness, d);
	toon_ramp *= ATTENUATION;

	float lit = mix(min_light, 1.0, toon_ramp);
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * lit;

	vec3 H = normalize(normalize(LIGHT) + normalize(VIEW));
	float spec = pow(max(dot(normalize(NORMAL), H), 0.0), mix(specular_size, 4.0, roughness));
	spec *= 1.0 - roughness;
	DIFFUSE_LIGHT += spec * specular_strength * LIGHT_COLOR * ATTENUATION;

	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	fresnel *= 1.0 - roughness * 0.5;
	DIFFUSE_LIGHT += fresnel * rim_brightness * ALBEDO * LIGHT_COLOR * ATTENUATION;
}
