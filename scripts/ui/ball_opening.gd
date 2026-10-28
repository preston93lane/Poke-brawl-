class_name BallOpening
extends Control
## Full-screen Poké Ball opening: the ball drops in, wobbles three times, pops
## open in a flash, the prizes fly out one by one, then the full list shows.
## Tap to skip ahead. Emits `finished` when closed.

signal finished

const BALL_COLORS := {
	"poke_ball": Color(0.9, 0.15, 0.15), "great_ball": Color(0.2, 0.45, 0.95),
	"ultra_ball": Color(0.15, 0.15, 0.18), "master_ball": Color(0.55, 0.2, 0.75),
}
const ICON_DIR := "res://assets/items/"

var ball := "poke_ball"
var prizes: Array[Dictionary] = []
var _t := 0.0
var _phase := "drop"  # drop → wobble → open → prizes → list
var _shown := 0
var _next_prize := 0.0
var _list: Control


func setup(p_ball: String, p_prizes: Array[Dictionary]) -> void:
	ball = p_ball
	prizes = p_prizes


func _ready() -> void:
	add_to_group("modal_overlay")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		"drop":
			if _t > 0.6:
				_go("wobble")
		"wobble":
			if _t > 1.5:
				_go("open")
		"open":
			if _t > 0.45:
				_go("prizes")
		"prizes":
			_next_prize -= delta
			if _next_prize <= 0.0:
				if _shown < prizes.size():
					_shown += 1
					_next_prize = 0.45
				elif _t > 0.6:
					_show_list()
	if _list:
		_list.position = (size - _list.size) * 0.5
	queue_redraw()


func _go(phase: String) -> void:
	_phase = phase
	_t = 0.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		accept_event()
		if _phase == "list":
			return
		if _phase == "prizes":
			_shown = prizes.size()
			_show_list()
		else:
			_go("prizes")


func _ball_center() -> Vector2:
	var drop := clampf(_t / 0.6, 0.0, 1.0) if _phase == "drop" else 1.0
	var bounce := (1.0 - drop) * (1.0 - drop)
	return Vector2(size.x * 0.5, size.y * 0.42 - bounce * size.y * 0.5)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var c := _ball_center()
	var r := 70.0
	var color: Color = BALL_COLORS.get(ball, BALL_COLORS["poke_ball"])
	if _phase in ["drop", "wobble"]:
		var tilt := 0.0
		if _phase == "wobble":
			# Three wobbles, like catching a Pokémon.
			var k := fmod(_t, 0.5) / 0.5
			tilt = sin(k * TAU) * 0.35 * (1.0 - k)
		draw_set_transform(c, tilt, Vector2.ONE)
		_draw_ball(Vector2.ZERO, r, color, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Opening: the top half lifts away, light bursts out.
	var lift := clampf(_t / 0.45, 0.0, 1.0) if _phase == "open" else 1.0
	var glow := 1.0 - absf(lift - 0.6)
	draw_circle(c, r * (1.4 + lift * 1.2), Color(1, 1, 0.85, 0.35 * glow))
	_draw_ball(c, r, color, lift)
	if _phase == "open":
		return
	# Prizes fly up and out in a fan.
	var n := maxi(1, prizes.size())
	for i in _shown:
		var p := prizes[i]
		var angle := lerpf(-1.1, 1.1, (i + 0.5) / n) if n > 1 else 0.0
		var target := c + Vector2(sin(angle) * 380.0, -cos(angle) * 150.0 - 60.0 + (i % 2) * 70.0)
		var age := clampf((float(_shown - i) * 0.45 - _next_prize) / 0.35, 0.0, 1.0)
		var pos := c.lerp(target, ease(age, 0.4))
		_draw_prize(pos, p, age)


func _draw_ball(c: Vector2, r: float, _color: Color, open: float) -> void:
	draw_ball(self, c, r, ball, open)


## A Poké Ball of kind `kind` (poke/great/ultra/master), `open` 0..1 lifts the top.
static func draw_ball(ci: CanvasItem, c: Vector2, r: float, kind: String, open := 0.0) -> void:
	var color: Color = BALL_COLORS.get(kind, BALL_COLORS["poke_ball"])
	var ball := kind
	var top := c - Vector2(0, open * 70.0)
	# Bottom (white) half-disc; whole while closed so there's no gap.
	if open < 0.05:
		ci.draw_circle(c, r, Color(0.96, 0.96, 0.96))
	else:
		var bottom := PackedVector2Array()
		for i in 33:
			var a := PI * i / 32.0
			bottom.append(c + Vector2(cos(a), sin(a)) * r)
		ci.draw_colored_polygon(bottom, Color(0.96, 0.96, 0.96))
	# Top half: a half-disc in the ball colour.
	var pts := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		pts.append(top + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)
	if ball == "master_ball":
		ci.draw_circle(top + Vector2(-r * 0.45, -r * 0.45), r * 0.16, Color(1, 0.45, 0.7))
		ci.draw_circle(top + Vector2(r * 0.45, -r * 0.45), r * 0.16, Color(1, 0.45, 0.7))
		ci.draw_string(ThemeDB.fallback_font, top + Vector2(-14, -r * 0.28), "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	elif ball == "ultra_ball":
		ci.draw_rect(Rect2(top + Vector2(-r * 0.62, -r * 0.8), Vector2(r * 0.28, r * 0.6)), Color(1, 0.85, 0.2))
		ci.draw_rect(Rect2(top + Vector2(r * 0.34, -r * 0.8), Vector2(r * 0.28, r * 0.6)), Color(1, 0.85, 0.2))
	elif ball == "great_ball":
		ci.draw_circle(top + Vector2(-r * 0.5, -r * 0.45), r * 0.2, Color(0.95, 0.25, 0.25))
		ci.draw_circle(top + Vector2(r * 0.5, -r * 0.45), r * 0.2, Color(0.95, 0.25, 0.25))
	ci.draw_arc(top, r, PI, TAU, 32, Color.BLACK, 4.0, true)
	ci.draw_arc(c, r, 0, PI, 32, Color.BLACK, 4.0, true)
	ci.draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color.BLACK, 8.0)
	if open < 0.05:
		ci.draw_circle(c, r * 0.24, Color.BLACK)
		ci.draw_circle(c, r * 0.16, Color.WHITE)


func _draw_prize(pos: Vector2, p: Dictionary, alpha: float) -> void:
	var item := str(p.get("item", ""))
	var s := 34.0
	if item == "money":
		draw_meowth_coin(self, pos, s, alpha)
	elif item in ["pokemon", "shiny"] and GameData.species.has(str(p.get("family", ""))):
		var sp: SpeciesData = GameData.species[str(p["family"])]
		var tex: Texture2D = sp.shiny_sprite if item == "shiny" and sp.shiny_sprite else sp.sprite
		if item == "shiny":
			draw_circle(pos, s * 1.5, Color(1, 0.9, 0.4, 0.35 * alpha))
		draw_texture_rect(tex, Rect2(pos - Vector2(s, s) * 1.4, Vector2(s, s) * 2.8), false, Color(1, 1, 1, alpha))
	else:
		var path := ICON_DIR + item + ".png"
		if ResourceLoader.exists(path):
			draw_texture_rect(load(path), Rect2(pos - Vector2(s, s), Vector2(s, s) * 2), false, Color(1, 1, 1, alpha))
		else:
			# TMs and HMs: a little disc.
			var disc := Color(0.55, 0.6, 1.0) if item.begins_with("tm_") else Color(0.75, 0.6, 1.0)
			draw_circle(pos, s * 0.9, Color(disc, alpha))
			draw_circle(pos, s * 0.25, Color(0.15, 0.15, 0.2, alpha))
			draw_string(ThemeDB.fallback_font, pos + Vector2(-16, s * 0.65), "TM" if item.begins_with("tm_") else "HM",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, alpha))
	var text := str(p.get("text", ""))
	draw_string(ThemeDB.fallback_font, pos + Vector2(-90, s + 26), text, HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Color(1, 1, 1, alpha))


## Meowth's Pay Day coin: gold, a raised rim, and the oval charm in the middle.
static func draw_meowth_coin(ci: CanvasItem, pos: Vector2, r: float, alpha := 1.0) -> void:
	ci.draw_circle(pos + Vector2(2, 3), r, Color(0, 0, 0, 0.3 * alpha))
	ci.draw_circle(pos, r, Color(0.78, 0.55, 0.1, alpha))
	ci.draw_circle(pos, r * 0.86, Color(1.0, 0.82, 0.25, alpha))
	ci.draw_arc(pos, r * 0.86, 0, TAU, 40, Color(0.8, 0.58, 0.12, alpha), 2.0, true)
	# The charm: an upright oval with a darker centre, like Meowth's forehead coin.
	var oval := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		oval.append(pos + Vector2(cos(a) * r * 0.32, sin(a) * r * 0.48))
	ci.draw_colored_polygon(oval, Color(0.85, 0.6, 0.12, alpha))
	var inner := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		inner.append(pos + Vector2(cos(a) * r * 0.16, sin(a) * r * 0.26))
	ci.draw_colored_polygon(inner, Color(1.0, 0.9, 0.45, alpha))
	ci.draw_circle(pos + Vector2(-r * 0.35, -r * 0.35), r * 0.12, Color(1, 1, 0.85, 0.8 * alpha))


func _show_list() -> void:
	if _phase == "list":
		return
	_go("list")
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.08, 0.1, 0.2, 0.95), 18, 18))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var title := UiKit.label("%s CONTENTS" % Profile.item_name(ball).to_upper(), 30, Color(1, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	for p in prizes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon := PrizeIcon.new()
		icon.prize = p
		icon.custom_minimum_size = Vector2(40, 40)
		row.add_child(icon)
		row.add_child(UiKit.label(str(p.get("text", "")), 24))
		v.add_child(row)
	var ok := UiKit.button("OK", func() -> void:
		finished.emit()
		queue_free(), 26)
	v.add_child(ok)
	panel.add_child(v)
	add_child(panel)
	_list = panel


## Small icon for one prize row in the list.
class PrizeIcon extends Control:
	var prize: Dictionary = {}

	func _draw() -> void:
		var item := str(prize.get("item", ""))
		var c := size * 0.5
		if item == "money":
			BallOpening.draw_meowth_coin(self, c, 17.0)
		elif item in ["pokemon", "shiny"] and GameData.species.has(str(prize.get("family", ""))):
			var sp: SpeciesData = GameData.species[str(prize["family"])]
			if item == "shiny":
				draw_circle(c, size.x * 0.5, Color(1, 0.9, 0.4, 0.4))
			draw_texture_rect(sp.shiny_sprite if item == "shiny" and sp.shiny_sprite else sp.sprite, Rect2(Vector2.ZERO, size), false)
		elif ResourceLoader.exists("res://assets/items/" + item + ".png"):
			draw_texture_rect(load("res://assets/items/" + item + ".png"), Rect2(Vector2.ZERO, size), false)
		else:
			draw_circle(c, 16, Color(0.55, 0.6, 1.0) if item.begins_with("tm_") else Color(0.75, 0.6, 1.0))
			draw_circle(c, 5, Color(0.15, 0.15, 0.2))
