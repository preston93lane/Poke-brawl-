class_name TrainerRoad
extends Control
## The trainer road as a path: a stop for each Pokémon unlocked by trainer
## level, joined by a track that fills up to your trainer level. Unlocked stops
## are in colour, the next one glows, later ones are dark silhouettes.
## `window` > 0 shows only that many stops around the next one (home screen).

var window := 0
var _stops: Array[Dictionary] = []


func _ready() -> void:
	_stops = Profile.road()
	if window > 0:
		var next := _next_index()
		var start := clampi(next - floori(window / 2.0), 0, maxi(0, _stops.size() - window))
		_stops = _stops.slice(start, start + window)
	custom_minimum_size.y = 118
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _next_index() -> int:
	for i in _stops.size():
		if not _stops[i]["unlocked"]:
			return i
	return _stops.size() - 1


func _draw() -> void:
	if _stops.is_empty():
		return
	var n := _stops.size()
	var margin := 40.0
	var step := (size.x - margin * 2.0) / maxf(1.0, n - 1)
	var y := 44.0
	var level := Profile.total_level()
	var font := ThemeDB.fallback_font
	# Track: grey, then gold up to your trainer level.
	draw_line(Vector2(margin, y), Vector2(size.x - margin, y), Color(1, 1, 1, 0.18), 8.0)
	var filled := margin
	for i in n:
		var x := margin + step * i
		var lvl := int(_stops[i]["level"])
		if level >= lvl:
			filled = x
		elif i > 0:
			var prev := int(_stops[i - 1]["level"])
			if level > prev:
				filled = lerpf(x - step, x, float(level - prev) / float(lvl - prev))
			break
		elif level > 0:
			filled = lerpf(margin - step * 0.5, x, float(level) / float(lvl))
	draw_line(Vector2(margin, y), Vector2(filled, y), Color(1, 0.8, 0.2), 8.0)
	var next := _next_index()
	for i in n:
		var stop: Dictionary = _stops[i]
		var x := margin + step * i
		var unlocked: bool = stop["unlocked"]
		var is_next := i == next and not unlocked
		var r := 26.0 if is_next else 21.0
		if is_next:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.005)
			draw_circle(Vector2(x, y), r + 6.0 + pulse * 3.0, Color(1, 0.85, 0.3, 0.35))
		draw_circle(Vector2(x, y), r, Color(1, 0.8, 0.2) if unlocked else (Color(0.95, 0.95, 1) if is_next else Color(0.2, 0.22, 0.35)))
		draw_circle(Vector2(x, y), r - 3.0, Color(0.12, 0.14, 0.25))
		var family := str(stop["family"])
		if family != "" and GameData.species.has(family):
			var tex: Texture2D = GameData.species[family].sprite
			var tint := Color.WHITE if unlocked or is_next else Color(0, 0, 0, 0.75)
			draw_texture_rect(tex, Rect2(Vector2(x, y) - Vector2(r, r) * 1.15, Vector2(r, r) * 2.3), false, tint)
		else:
			draw_string(font, Vector2(x - 20, y + 9), "?", HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color(1, 1, 1, 0.8))
		var label := "LV %d" % int(stop["level"])
		draw_string(font, Vector2(x - 40, y + r + 20), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 15,
				Color(1, 0.9, 0.5) if is_next else Color(1, 1, 1, 0.75))
		if is_next:
			var who: String = GameData.species[family].display_name if family != "" else "Starter"
			draw_string(font, Vector2(x - 70, y + r + 38), "NEXT: " + who.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 14, Color(1, 0.9, 0.5))


func _process(_delta: float) -> void:
	queue_redraw()  # The next stop pulses.
