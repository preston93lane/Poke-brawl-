// HD-2D touch: a light haze toward the top of the screen (the far side of the
// arena). Drawn as a see-through tint over the game. It never reads the screen
// back: copying the screen (for the old edge blur) flashed green and left black
// lines on some Android phones in the browser.
shader_type canvas_item;

uniform vec4 haze_color : source_color = vec4(0.88, 0.92, 0.97, 1.0);
// Haze amount at the very top, fading to none by `haze_end` (0 = top, 1 = bottom).
uniform float haze_top = 0.16;
uniform float haze_end = 0.55;

void fragment() {
	float haze = haze_top * (1.0 - smoothstep(0.0, haze_end, SCREEN_UV.y));
	COLOR = vec4(haze_color.rgb, haze);
}
