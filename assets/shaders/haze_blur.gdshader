// HD-2D touch: a light haze toward the top of the screen (the far side of the
// arena) and a soft blur at the top and bottom edges, like a shallow depth of
// field. Only the edge bands are blurred, so the middle costs one texture read.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec4 haze_color : source_color = vec4(0.88, 0.92, 0.97, 1.0);
// Haze amount at the very top, fading to none by `haze_end` (0 = top, 1 = bottom).
uniform float haze_top = 0.16;
uniform float haze_end = 0.55;
// Heights of the blurred bands (fractions of the screen) and the blur's reach in pixels.
uniform float blur_top = 0.2;
uniform float blur_bottom = 0.1;
uniform float blur_pixels = 2.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen, uv).rgb;
	float edge = max(1.0 - smoothstep(0.0, blur_top, uv.y), smoothstep(1.0 - blur_bottom, 1.0, uv.y));
	if (edge > 0.02) {
		vec2 px = SCREEN_PIXEL_SIZE * blur_pixels * edge;
		vec3 sum = c * 0.2;
		sum += texture(screen, uv + vec2(px.x, 0.0)).rgb * 0.1;
		sum += texture(screen, uv - vec2(px.x, 0.0)).rgb * 0.1;
		sum += texture(screen, uv + vec2(0.0, px.y)).rgb * 0.1;
		sum += texture(screen, uv - vec2(0.0, px.y)).rgb * 0.1;
		sum += texture(screen, uv + px * 1.5).rgb * 0.1;
		sum += texture(screen, uv - px * 1.5).rgb * 0.1;
		sum += texture(screen, uv + vec2(px.x, -px.y) * 1.5).rgb * 0.1;
		sum += texture(screen, uv + vec2(-px.x, px.y) * 1.5).rgb * 0.1;
		c = sum;
	}
	float haze = haze_top * (1.0 - smoothstep(0.0, haze_end, uv.y));
	c = mix(c, haze_color.rgb, haze);
	COLOR = vec4(c, 1.0);
}
