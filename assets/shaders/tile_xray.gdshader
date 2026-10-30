// Walls, crates and blocks: the tile texture projected from three sides (like
// StandardMaterial's triplanar), see-through when they hide your Pokémon
// (xray.gdshaderinc), and shaded so they read as solid, made things rather than
// textured boxes: a lit top (or a separate cap / ledge texture), slightly darker
// sides, a soft highlight on rounded edges, a dark base where the wall meets the
// floor, and optional moss creeping up from the ground. Per-style settings come
// from arena.gd WALL_STYLES.
shader_type spatial;

#include "res://assets/shaders/xray.gdshaderinc"

// The wall texture and its variants (layer 0 = original, 1.. = _v1..).
uniform sampler2DArray albedo_layers : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// >= 0: always this layer (single walls); < 0: per copy from the MultiMesh's custom data.
uniform float fixed_layer = -1.0;
uniform vec4 tint : source_color = vec4(1.0);
// Top of the wall: its own texture (capstone, plank ends, plates...) or the wall's own.
uniform sampler2D cap_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_cap_tex = false;
uniform vec4 cap_tint = vec4(1.0);
// How far down the sides the cap texture reaches (a ledge / rim / trim band).
uniform float cap_band = 0.0;
uniform float half_height = 0.6;
uniform float top_light = 1.12;
uniform float side_light = 0.9;
uniform float edge_light = 0.18;
uniform float base_ao = 0.35;
uniform float moss = 0.0;
uniform vec4 moss_color : source_color = vec4(0.36, 0.52, 0.22, 1.0);

varying vec3 local_pos;
varying vec3 local_normal;
varying flat float layer;

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	layer = fixed_layer >= 0.0 ? fixed_layer : round(INSTANCE_CUSTOM.r);
}

vec3 wall_tex(vec2 uv) {
	return texture(albedo_layers, vec3(uv, layer)).rgb;
}

vec3 cap_side(vec2 uv) {
	return (has_cap_tex ? texture(cap_tex, uv).rgb : wall_tex(uv)) * cap_tint.rgb;
}

void fragment() {
	if (xray_cut(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE, FRAGCOORD.xy)) {
		discard;
	}
	vec3 n = normalize(local_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	// Only sample the projections that show (flat faces need just one).
	bool in_cap = local_pos.y > half_height - cap_band;
	vec3 c = vec3(0.0);
	if (w.x > 0.02) {
		c += (in_cap ? cap_side(local_pos.zy) : wall_tex(local_pos.zy)) * w.x;
	}
	if (w.z > 0.02) {
		c += (in_cap ? cap_side(local_pos.xy) : wall_tex(local_pos.xy)) * w.z;
	}
	if (w.y > 0.02) {
		c += cap_side(local_pos.xz) * w.y;
	}
	c /= max(w.x * step(0.02, w.x) + w.y * step(0.02, w.y) + w.z * step(0.02, w.z), 0.001);
	// Lit tops, darker sides, darker still under a ledge.
	c *= n.y >= 0.0 ? mix(side_light, top_light, n.y) : side_light * (1.0 + 0.45 * n.y);
	// Rounded edges catch a little extra light.
	float axis = max(abs(n.x), max(abs(n.y), abs(n.z)));
	c *= 1.0 + edge_light * (1.0 - axis) * 3.0;
	// Dark where it meets the ground.
	float h = local_pos.y + half_height;
	c *= mix(1.0 - base_ao, 1.0, smoothstep(0.0, 0.5, h));
	if (moss > 0.0) {
		vec3 m = wall_tex(vec2((local_pos.x + local_pos.z) * 0.43 + 0.3, local_pos.y * 0.61));
		float noise = dot(m, vec3(0.33));
		float amount = moss * (1.0 - smoothstep(0.05, 0.5, h)) * smoothstep(0.35, 0.55, noise) * (1.0 - w.y);
		c = mix(c, moss_color.rgb * (0.75 + 0.5 * noise), clamp(amount, 0.0, 1.0));
	}
	ALBEDO = c * tint.rgb * COLOR.rgb;  // COLOR: per-copy shade from the arena's MultiMesh.
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
