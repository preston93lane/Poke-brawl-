// Let's Go style ground: one surface for the whole map. Grass colour drifts in
// big soft patches with fine blade streaks; dirt paths, shorelines and the
// shade under walls and tall grass come from a per-map "splat" texture
// (R = path, G = water, B = solid, A = tall grass), with wobbly noise edges.
shader_type spatial;

uniform sampler2D splat : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(36.0, 48.0);
uniform vec3 grass_a : source_color = vec3(0.38, 0.62, 0.19);
uniform vec3 grass_b : source_color = vec3(0.52, 0.72, 0.24);
uniform vec3 grass_dark : source_color = vec3(0.22, 0.42, 0.14);
uniform vec3 dirt : source_color = vec3(0.82, 0.62, 0.38);
uniform vec3 dirt_edge : source_color = vec3(0.56, 0.40, 0.24);
uniform vec3 shore : source_color = vec3(0.80, 0.70, 0.50);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 uv = (p + map_size * 0.5) / map_size;
	vec2 warp = (vec2(fbm(p * 0.8), fbm(p * 0.8 + 17.3)) - 0.5) * 0.7 / map_size;
	vec4 s = texture(splat, uv + warp);
	// Water tiles are drawn underneath; cutting the ground away there gives the pond a round shore.
	if (s.g > 0.6) {
		discard;
	}
	float big = fbm(p * 0.11);
	float mid = fbm(p * 0.55 + 3.1);
	float fine = noise(p * 9.0);
	float streak = noise(vec2(p.x * 22.0, p.y * 4.0));

	vec3 g = mix(grass_a, grass_b, smoothstep(0.3, 0.72, big));
	g = mix(g, grass_dark, smoothstep(0.55, 0.85, mid) * 0.3);
	g *= 0.93 + 0.1 * fine + 0.08 * streak;
	g = mix(g, grass_dark * 0.85, s.a * 0.55);

	float edge = s.r + (mid - 0.5) * 0.3;
	float path = smoothstep(0.45, 0.55, edge);
	float rim = clamp(smoothstep(0.32, 0.45, edge) - path, 0.0, 1.0);
	vec3 d = dirt * (0.9 + 0.14 * fine) * (0.94 + 0.12 * fbm(p * 1.7));
	vec3 col = mix(g, d, path);
	col = mix(col, dirt_edge, rim * 0.6);
	col = mix(col, shore * (0.92 + 0.1 * fine), smoothstep(0.12, 0.35, s.g) * (1.0 - path) * 0.9);
	col = mix(col, shore * 0.7, smoothstep(0.45, 0.6, s.g));
	col *= 1.0 - smoothstep(0.1, 0.7, s.b) * 0.3;

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
