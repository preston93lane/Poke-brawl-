// Ponds and pools with round, natural edges: one plane over the whole map, cut
// to shape by a smooth mask (1 = water), with a foam (or cooled-crust, for
// lava) rim along the shore and deeper colour towards the middle.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(30.0, 42.0);
uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.08, 0.36, 0.70, 1.0);
uniform vec4 shallow : source_color = vec4(0.36, 0.78, 0.98, 1.0);
uniform vec4 rim : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform bool lava = false;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = p / map_size + 0.5;
	// A little wobble so straight shores aren't ruler-straight.
	float wob = sin(p.x * 2.3 + p.y * 1.7) * 0.025 + sin(p.y * 3.1 - p.x * 1.3) * 0.02;
	float m = texture(mask, uv).r + wob;
	if (m < 0.47) {
		discard;
	}
	float a = texture(water_tex, p * 0.35 + vec2(TIME * 0.03, TIME * 0.02)).r;
	float b = texture(water_tex, p * 0.22 - vec2(TIME * 0.025, -TIME * 0.035)).g;
	float ripple = sin(p.x * 3.1 + TIME * 1.6) * sin(p.y * 2.7 - TIME * 1.3) * 0.5 + 0.5;
	float t = clamp(a * 0.55 + b * 0.45 + ripple * 0.25 - 0.15, 0.0, 1.0);
	// Deeper away from the shore.
	float depth = smoothstep(0.5, 0.95, m);
	vec3 col = mix(shallow.rgb, deep.rgb, depth * 0.75 + (1.0 - t) * 0.25);
	// Foam band hugging the shore, gently pulsing.
	float band = 1.0 - smoothstep(0.47, 0.6 + sin(TIME * 1.5 + p.x + p.y) * 0.02, m);
	col = mix(col, rim.rgb, band * 0.85);
	if (lava) {
		EMISSION = col * (0.6 + 0.4 * (1.0 - band));
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.12, 0.6, band);
	SPECULAR = 0.7;
	float slope_x = sin(p.x * 3.1 + TIME * 1.6);
	float slope_z = sin(p.y * 2.7 - TIME * 1.3);
	NORMAL = normalize((VIEW_MATRIX * vec4(slope_x * 0.12 * (1.0 - band), 1.0, slope_z * 0.12 * (1.0 - band), 0.0)).xyz);
}
