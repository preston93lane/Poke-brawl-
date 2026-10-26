// Tall grass bushes: alpha-cut blades that sway in the wind. The top of each
// blade (UV.y = 0) moves most; the root (UV.y = 1) stays planted.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D blades : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.09;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float top = 1.0 - UV.y;
	float wave = sin(TIME * 1.7 + world.x * 0.8 + world.z * 0.55) + 0.4 * sin(TIME * 3.1 + world.z * 1.7);
	VERTEX.x += wave * sway * top * top;
	VERTEX.z += cos(TIME * 1.2 + world.x * 0.45) * sway * 0.5 * top * top;
}

void fragment() {
	vec4 c = texture(blades, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
}
