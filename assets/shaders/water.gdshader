// Animated water: two scrolling layers of the water texture, moving ripples and
// a glossy surface that catches the sun.
shader_type spatial;

uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.10, 0.32, 0.62, 1.0);
uniform vec4 shallow : source_color = vec4(0.42, 0.74, 0.95, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float a = texture(water_tex, p * 0.35 + vec2(TIME * 0.03, TIME * 0.02)).r;
	float b = texture(water_tex, p * 0.22 - vec2(TIME * 0.025, -TIME * 0.035)).g;
	float ripple = sin(p.x * 3.1 + TIME * 1.6) * sin(p.y * 2.7 - TIME * 1.3) * 0.5 + 0.5;
	float m = clamp(a * 0.55 + b * 0.45 + ripple * 0.25 - 0.15, 0.0, 1.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, m);
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	float slope_x = sin(p.x * 3.1 + TIME * 1.6);
	float slope_z = sin(p.y * 2.7 - TIME * 1.3);
	NORMAL = normalize((VIEW_MATRIX * vec4(slope_x * 0.12, 1.0, slope_z * 0.12, 0.0)).xyz);
}
