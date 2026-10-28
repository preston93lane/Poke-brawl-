// Textured walls, crates and blocks: the tile texture projected from three
// sides (like StandardMaterial's triplanar), see-through when they hide your
// Pokémon (xray.gdshaderinc).
shader_type spatial;

#include "res://assets/shaders/xray.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);

varying vec3 local_pos;
varying vec3 local_normal;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	if (xray_cut(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE, FRAGCOORD.xy)) {
		discard;
	}
	vec3 w = pow(abs(normalize(local_normal)), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 c = texture(albedo_tex, local_pos.zy).rgb * w.x
			+ texture(albedo_tex, local_pos.xz).rgb * w.y
			+ texture(albedo_tex, local_pos.xy).rgb * w.z;
	ALBEDO = c * tint.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
