// Let's Go style tall grass: broad pointed leaves coloured by vertex colour
// (dark at the root, bright at the tip) that sway in the wind. UV.y is 1 at the
// root and 0 at the tip, so the tips move most.
shader_type spatial;
render_mode cull_disabled;

uniform float sway = 0.08;
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float top = 1.0 - UV.y;
	float wave = sin(TIME * 1.7 + world.x * 0.8 + world.z * 0.55) + 0.4 * sin(TIME * 3.1 + world.z * 1.7);
	VERTEX.x += wave * sway * top * top;
	VERTEX.z += cos(TIME * 1.2 + world.x * 0.45) * sway * 0.5 * top * top;
}

void fragment() {
	ALBEDO = COLOR.rgb * tint.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
