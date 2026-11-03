// Textured nature models (Quaternius rocks, bushes, pebbles...), tinted per copy
// (COLOR), with soft top light and see-through when they hide your Pokémon.
shader_type spatial;
render_mode cull_disabled;

#include "res://assets/shaders/xray.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool cutout = false;
// Brightens upward faces a touch, like the stylised kit's own shader.
uniform float top_light = 0.18;

varying float up;

void vertex() {
	up = NORMAL.y;
}

void fragment() {
	if (xray_cut(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE, FRAGCOORD.xy)) {
		discard;
	}
	vec4 c = texture(albedo_tex, UV);
	if (cutout && c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb * COLOR.rgb * (1.0 + top_light * clamp(up, 0.0, 1.0));
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
