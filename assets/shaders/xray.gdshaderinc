// See-through obstacles: anything between the camera and your Pokémon fades
// to about 85% transparent (a fine dither pattern, so it stays in the cheap
// opaque pipeline) inside a circle around your Pokémon on screen.
// main.gd sets player_xray to your Pokémon's position every frame.
global uniform vec3 player_xray;

const float XRAY_RADIUS = 0.2;
const float XRAY_FADE = 0.85;

// True if this fragment should be cut away. `view_vertex` is VERTEX in fragment().
bool xray_cut(vec3 view_vertex, mat4 view, mat4 proj, vec2 viewport, vec2 frag) {
	vec4 pv = view * vec4(player_xray, 1.0);
	// Only things nearer the camera than the Pokémon (view space looks down -z).
	if (view_vertex.z < pv.z + 0.35) {
		return false;
	}
	vec4 pc = proj * pv;
	vec4 fc = proj * vec4(view_vertex, 1.0);
	vec2 d = (fc.xy / fc.w - pc.xy / pc.w) * vec2(viewport.x / viewport.y, 1.0);
	float r = length(d);
	if (r > XRAY_RADIUS) {
		return false;
	}
	float fade = XRAY_FADE * (1.0 - smoothstep(XRAY_RADIUS * 0.75, XRAY_RADIUS, r));
	float bayer[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };
	int ix = int(mod(frag.x, 4.0));
	int iy = int(mod(frag.y, 4.0));
	return (bayer[ix + iy * 4] + 0.5) / 16.0 < fade;
}
