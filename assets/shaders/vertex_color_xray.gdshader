// Vertex-coloured models (Let's Go trees and rocks), matte, see-through when
// they hide your Pokémon (xray.gdshaderinc).
shader_type spatial;

#include "res://assets/shaders/xray.gdshaderinc"

void fragment() {
	if (xray_cut(VERTEX, VIEW_MATRIX, PROJECTION_MATRIX, VIEWPORT_SIZE, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
