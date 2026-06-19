shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// Dedicated fade shader with a Bayer dither pattern.
// Applied as MeshInstance3D.material_override by CharacterPresenter only while
// fading, so the original toon/material is left untouched.

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float fade_alpha : hint_range(0.0, 1.0) = 1.0;

const mat4 BAYER_MATRIX = mat4(
	vec4(0.0, 0.5, 0.125, 0.625),
	vec4(0.75, 0.25, 0.875, 0.375),
	vec4(0.1875, 0.6875, 0.0625, 0.5625),
	vec4(0.9375, 0.4375, 0.8125, 0.3125)
);

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;

	int x = int(FRAGCOORD.x) % 4;
	int y = int(FRAGCOORD.y) % 4;
	float threshold = BAYER_MATRIX[x][y];

	// Bayer dither discard: more pixels survive as fade_alpha approaches 1.0.
	// Uses <= instead of < so that fade_alpha = 0.0 discards 100% of pixels.
	if (fade_alpha <= threshold) {
		discard;
	}
}

void light() {
	float d = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	DIFFUSE_LIGHT += LIGHT_COLOR * ALBEDO * d;
}
