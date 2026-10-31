// Stadium crowd: every spectator is one copy in a MultiMesh. The copy's custom
// data picks its look (INSTANCE_CUSTOM.r = row in trainers.png) and its own
// rhythm (.g), so they bob and throw their arms up out of step with each other.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float looks = 16.0;
uniform float excitement = 1.0;

varying flat float row;
varying flat float cheer;

void vertex() {
	row = round(INSTANCE_CUSTOM.r);
	float phase = INSTANCE_CUSTOM.g * 6.2831;
	float beat = TIME * (2.0 + INSTANCE_CUSTOM.b * 2.5) + phase;
	cheer = step(0.55 - 0.25 * excitement, sin(beat * 0.5));
	VERTEX.y += abs(sin(beat)) * 0.06 * excitement;
}

void fragment() {
	vec2 uv = vec2((UV.x + cheer) * 0.5, (UV.y + row) / looks);
	vec4 c = texture(atlas, uv);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
}
