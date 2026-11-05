class_name TownTime
extends RefCounted
## The town follows your clock: sunrise from about 5:30, day from 8, sunset from
## 17:00 and night from about 20:00, blended smoothly. The sun crosses the sky
## from east (right) to west (left), so shadows swing from the left in the
## morning to the right in the evening. At night the moon lights the town, the
## lanterns come on and the windows glow.

## Tests and screenshots set this (0-24); below 0 = your clock.
static var hour_override := -1.0

## [hour, sun colour, sun energy, ambient colour, ambient energy, sky top, sky horizon, sprite tint, night 0-1]
const KEYS := [
	[0.0, Color(0.6, 0.68, 1.0), 0.18, Color(0.3, 0.33, 0.5), 0.25, Color(0.02, 0.04, 0.13), Color(0.1, 0.13, 0.28), Color(0.58, 0.64, 0.9), 1.0],
	[5.0, Color(0.6, 0.68, 1.0), 0.18, Color(0.3, 0.33, 0.5), 0.25, Color(0.02, 0.04, 0.13), Color(0.1, 0.13, 0.28), Color(0.58, 0.64, 0.9), 1.0],
	[6.5, Color(1.0, 0.72, 0.52), 0.85, Color(1.0, 0.8, 0.74), 0.5, Color(0.42, 0.45, 0.78), Color(1.0, 0.68, 0.52), Color(1.0, 0.86, 0.8), 0.45],
	[8.0, Color(1.0, 0.95, 0.86), 0.8, Color(1.0, 0.97, 0.92), 0.5, Color(0.32, 0.55, 0.9), Color(0.74, 0.85, 0.96), Color(1, 1, 1), 0.0],
	[17.0, Color(1.0, 0.95, 0.86), 0.8, Color(1.0, 0.97, 0.92), 0.5, Color(0.32, 0.55, 0.9), Color(0.74, 0.85, 0.96), Color(1, 1, 1), 0.0],
	[18.5, Color(1.0, 0.58, 0.36), 0.85, Color(0.96, 0.7, 0.64), 0.48, Color(0.32, 0.26, 0.56), Color(1.0, 0.5, 0.34), Color(1.0, 0.8, 0.72), 0.55],
	[20.0, Color(0.6, 0.68, 1.0), 0.18, Color(0.3, 0.33, 0.5), 0.25, Color(0.02, 0.04, 0.13), Color(0.1, 0.13, 0.28), Color(0.58, 0.64, 0.9), 1.0],
	[24.0, Color(0.6, 0.68, 1.0), 0.18, Color(0.3, 0.33, 0.5), 0.25, Color(0.02, 0.04, 0.13), Color(0.1, 0.13, 0.28), Color(0.58, 0.64, 0.9), 1.0],
]


static func hour() -> float:
	if hour_override >= 0.0:
		return fmod(hour_override, 24.0)
	var t := Time.get_datetime_dict_from_system()
	return float(t["hour"]) + float(t["minute"]) / 60.0


## "night", "dawn", "day" or "dusk" (for labels).
static func phase(h := -1.0) -> String:
	if h < 0.0:
		h = hour()
	if h < 5.5 or h >= 19.5:
		return "night"
	if h < 8.0:
		return "dawn"
	if h < 17.0:
		return "day"
	return "dusk"


## The light at hour `h`: { sun_color, sun_energy, ambient, ambient_energy, sky_top,
## sky_horizon, tint (for sprites), night (0 day .. 1 night), sun_from (unit vector
## pointing at the sun or moon) }.
static func light(h := -1.0) -> Dictionary:
	if h < 0.0:
		h = hour()
	var a: Array = KEYS[0]
	var b: Array = KEYS[KEYS.size() - 1]
	for i in KEYS.size() - 1:
		if h >= float(KEYS[i][0]) and h <= float(KEYS[i + 1][0]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t := 0.0 if float(b[0]) == float(a[0]) else (h - float(a[0])) / (float(b[0]) - float(a[0]))
	t = smoothstep(0.0, 1.0, t)
	var out := {
		"sun_color": (a[1] as Color).lerp(b[1], t), "sun_energy": lerpf(a[2], b[2], t),
		"ambient": (a[3] as Color).lerp(b[3], t), "ambient_energy": lerpf(a[4], b[4], t),
		"sky_top": (a[5] as Color).lerp(b[5], t), "sky_horizon": (a[6] as Color).lerp(b[6], t),
		"tint": (a[7] as Color).lerp(b[7], t), "night": lerpf(a[8], b[8], t),
	}
	# The sun from the east (right) at 6:00, high to the south at noon, west (left) at 19:00.
	var day := clampf((h - 6.0) / 13.0, 0.0, 1.0)
	# Never straight overhead: a slanting sun keeps the town from washing out and shadows visible.
	var sun := Vector3(cos(day * PI) * 0.9, 0.3 + sin(day * PI) * 0.28, 0.6).normalized()
	var moon := Vector3(-0.45, 0.85, 0.45).normalized()
	out["sun_from"] = sun.lerp(moon, float(out["night"])).normalized()
	return out
