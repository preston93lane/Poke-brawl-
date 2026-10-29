// See-through obstacles: the parts of a wall, rock or tree that are drawn over
// your Pokémon fade to about 50% (a fine dither pattern, so it stays in the cheap
// opaque pipeline). Things beside or behind it never fade.
// main.gd sets player_xray to your Pokémon's feet and player_xray_size to
// (half width, height) of its sprite every frame. The sprite is tilted to face
// the camera, so in view space it's a flat rectangle at the feet's depth.
global uniform vec3 player_xray;
global uniform vec2 player_xray_size;

const float XRAY_FADE = 0.5;
const float XRAY_FEATHER = 0.15;

// True if this fragment should be cut away. `view_vertex` is VERTEX in fragment().
bool xray_cut(vec3 view_vertex, mat4 view, mat4 proj, vec2 viewport, vec2 frag) {
	vec3 feet = (view * vec4(player_xray, 1.0)).xyz;
	// Only things nearer the camera than the sprite (view space looks down -z).
	if (view_vertex.z <= feet.z + 0.05 || feet.z >= 0.0 || view_vertex.z >= 0.0) {
		return false;
	}
	// Where this fragment's line of sight crosses the sprite's plane.
	vec2 hit = view_vertex.xy * (feet.z / view_vertex.z) - feet.xy;
	float inside = min(player_xray_size.x - abs(hit.x), min(hit.y, player_xray_size.y - hit.y));
	if (inside <= 0.0) {
		return false;
	}
	float fade = XRAY_FADE * smoothstep(0.0, XRAY_FEATHER, inside);
	float bayer[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };
	int ix = int(mod(frag.x, 4.0));
	int iy = int(mod(frag.y, 4.0));
	return (bayer[ix + iy * 4] + 0.5) / 16.0 < fade;
}
