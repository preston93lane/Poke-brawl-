class_name UiKit
extends RefCounted
## Shared look and widgets for menus and the HUD.

const BG := Color(0.08, 0.1, 0.16)
const PANEL := Color(0.13, 0.16, 0.26, 0.95)
const ACCENT := Color(0.95, 0.3, 0.25)
const BLUE := Color(0.22, 0.48, 0.9)
const STAT_MAX := { "hp": 5000.0, "attack": 150.0, "defense": 150.0, "speed": 130.0 }
const STAT_COLORS := {
	"hp": Color(0.35, 0.85, 0.4), "attack": Color(0.95, 0.45, 0.3),
	"defense": Color(0.4, 0.65, 1.0), "speed": Color(0.95, 0.85, 0.3),
}


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	t.set_stylebox("normal", "Button", box(BLUE))
	t.set_stylebox("hover", "Button", box(BLUE.lightened(0.15)))
	t.set_stylebox("pressed", "Button", box(ACCENT))
	t.set_stylebox("hover_pressed", "Button", box(ACCENT.lightened(0.1)))
	t.set_stylebox("disabled", "Button", box(Color(0.3, 0.3, 0.35)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_constant("outline_size", "Button", 4)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.6))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 16, 16))
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0, 0, 0, 0.45)
	bar_bg.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	return t


static func box(color: Color, radius := 14, margin := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin + 4
	s.content_margin_right = margin + 4
	s.content_margin_top = margin * 0.6
	s.content_margin_bottom = margin * 0.6
	s.border_width_bottom = 5
	s.border_color = color.darkened(0.4)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s


static func label(text: String, size := 24, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, on_pressed: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(on_pressed)
	return b


static func sprite(texture: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	return r


static func type_chip(type_name: String, size := 18, text := "") -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", box(GameData.type_color(type_name), 10, 6))
	chip.add_child(label(text if text != "" else type_name.to_upper(), size))
	return chip


static func type_row(types: Array[String], size := 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for t in types:
		row.add_child(type_chip(t, size))
	return row


## "HP  ████░░  2900" style row.
static func stat_bar(stat: String, value: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := label(stat.to_upper().replace("ATTACK", "ATK").replace("DEFENSE", "DEF").replace("SPEED", "SPD"), 20)
	name_label.custom_minimum_size.x = 64
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = STAT_MAX.get(stat, 150.0)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = STAT_COLORS.get(stat, Color.WHITE)
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var value_label := label(str(roundi(value)), 20)
	value_label.custom_minimum_size.x = 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	return row


## One-line description of a move's numbers: what it's good and bad at.
static func move_summary(move: MoveData) -> String:
	var parts: Array[String] = []
	if move.kind == "stream" or move.linger > 0.0:
		parts.append("Power %d/s" % move.power)
	elif move.power > 0.0 and move.kind != "self":
		parts.append("Power %d" % move.power)
	var how := move.behaviour_text()
	if how != "" and move.kind != "self":
		parts.append(how)
	match move.kind:
		"melee":
			parts.append("Reach %.1fm" % move.reach)
			if move.arc < 300.0:
				parts.append("%d° swing" % move.arc)
		"dash":
			parts.append("Dash %.1fm" % move.dash_distance)
		"projectile":
			parts.append("Range %.1fm" % move.reach)
			if move.explode_radius > 0.0:
				parts.append("%.1fm blast" % move.explode_radius)
			if move.linger > 0.0:
				parts.append("%.1fm zone for %.0fs" % [move.linger_radius, move.linger])
		"stream":
			parts.append("hold to fire")
			parts.append("Range %.1fm" % move.reach)
			parts.append("%d° cone" % move.arc)
			parts.append("%.1fs tank, %.1fs refill" % [move.tank, move.reload])
		"area":
			parts.append("%.1fm circle %s" % [move.area_radius, "around you" if move.reach <= 0.0 else "up to %.0fm away" % move.reach])
			if move.area_delay > 0.0:
				parts.append("lands after %.1fs" % move.area_delay)
	if move.slot == "main" and move.kind != "stream":
		parts.append("%d ammo, %.1fs reload" % [move.ammo, move.reload])
	if move.heal_allies > 0.0:
		parts.append("heals allies it passes %d" % roundi(move.heal_allies))
	if move.protect > 0.0:
		parts.append("shield %.1fs" % move.protect)
	if move.drain > 0.0:
		parts.append("heals %d%% of damage" % roundi(move.drain * 100))
	if move.heal > 0.0:
		parts.append("heals you %d%%" % roundi(move.heal * 100))
	if move.team_heal > 0.0:
		parts.append("heals allies %d%% (%.0fm)" % [roundi(move.team_heal * 100), move.support_radius])
	if not move.buff.is_empty():
		var stats: Array[String] = []
		for stat in ["attack", "defense", "speed"]:
			if move.buff.has(stat):
				stats.append("+%d%% %s" % [roundi(float(move.buff[stat]) * 100), stat])
		parts.append("%s for %.0fs%s" % [", ".join(stats), float(move.buff.get("duration", 4.0)), " (team)" if move.buff.get("allies", false) else ""])
	if move.blink > 0.0:
		parts.append("teleport %.0fm" % move.blink)
	if not move.blind.is_empty():
		parts.append("blinds enemies who can see you for %.0fs (%.0fm)" % [float(move.blind.get("duration", 3.0)), float(move.blind.get("radius", 8.0))])
	if move.cleanse:
		parts.append("cures status")
	if move.crit_chance > 0.0:
		parts.append("%d%% crit" % roundi(move.crit_chance * 100))
	if not move.effect.is_empty():
		var names := { "burn": "burn", "poison": "poison", "slow": "slow", "leech": "seeds: drains HP to you",
				"stun": "stun", "blind": "blind" }
		var chance := roundi(float(move.effect.get("chance", 1.0)) * 100)
		var effect_name: String = names.get(move.effect.get("type", ""), "effect")
		parts.append(effect_name if chance >= 100 else "%d%% %s" % [chance, effect_name])
	return " · ".join(parts)


## Small card for a move: name, type, slot and stats.
static func move_card(move: MoveData, unlock_level := 0) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", box(Color(0.18, 0.21, 0.33), 10, 8))
	var v := VBoxContainer.new()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	if unlock_level > 0:
		top.add_child(label("Lv%d" % unlock_level, 18, Color(1, 0.85, 0.4)))
	top.add_child(label(move.display_name, 22))
	top.add_child(type_chip(move.type, 14))
	var slot_names := { "main": "ATTACK", "gadget": "GADGET", "super": "SUPER" }
	var slot_color: Color = { "super": Color(1, 0.85, 0.3), "gadget": Color(0.55, 1.0, 0.75) }.get(move.slot, Color(0.7, 0.8, 1))
	top.add_child(label(slot_names.get(move.slot, ""), 16, slot_color))
	v.add_child(top)
	var summary := label(move_summary(move), 16, Color(0.85, 0.88, 0.95))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(summary)
	card.add_child(v)
	return card


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


## Touch-friendly vertical scroll list (see DragScroll).
static func scroll(child: Control) -> ScrollContainer:
	var s := DragScroll.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


# --- Drawing helpers for HUD widgets ---------------------------------------

## Shaded disc: darker rim, lighter top-left, like a glossy button.
static func draw_shaded_circle(ci: CanvasItem, center: Vector2, radius: float, color: Color, alpha := 1.0) -> void:
	var steps := 9
	for i in steps:
		var t := float(i) / steps
		var r := radius * (1.0 - t * 0.85)
		var c := color.darkened(0.35 * (1.0 - t)).lerp(color.lightened(0.35), t * t)
		ci.draw_circle(center - Vector2(radius, radius) * 0.18 * t, r, Color(c, alpha))


## Soft drop shadow under a round widget.
static func draw_drop_shadow(ci: CanvasItem, center: Vector2, radius: float) -> void:
	ci.draw_circle(center + Vector2(0, radius * 0.1), radius * 1.04, Color(0, 0, 0, 0.28))
	ci.draw_circle(center + Vector2(0, radius * 0.06), radius * 1.0, Color(0, 0, 0, 0.22))


## Filled pie from 12 o'clock clockwise covering `ratio` (0..1).
static func draw_pie(ci: CanvasItem, center: Vector2, radius: float, ratio: float, color: Color) -> void:
	if ratio <= 0.0:
		return
	var points := PackedVector2Array([center])
	var segments := maxi(3, int(48 * ratio))
	for i in segments + 1:
		var a := -PI / 2.0 + TAU * ratio * float(i) / segments
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	ci.draw_colored_polygon(points, color)


## Rounded label pill with outlined text.
static func draw_pill(ci: CanvasItem, center: Vector2, text: String, font_size := 18, bg := Color(0, 0, 0, 0.55)) -> void:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 22.0
	var h := font_size + 10.0
	var pill := StyleBoxFlat.new()
	pill.bg_color = bg
	pill.set_corner_radius_all(int(h / 2))
	ci.draw_style_box(pill, Rect2(center - Vector2(w, h) / 2.0, Vector2(w, h)))
	var pos := center + Vector2(-w / 2.0, font_size * 0.36)
	ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 4, Color(0, 0, 0, 0.8))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color.WHITE)


## Simple emblem for each type (flame, droplet, bolt, leaf...), drawn in `color`.
static func draw_type_icon(ci: CanvasItem, type_name: String, c: Vector2, s: float, color := Color.WHITE) -> void:
	match type_name:
		"fire":
			_icon_poly(ci, c, s, color, [Vector2(0, -1), Vector2(0.35, -0.35), Vector2(0.6, 0.15), Vector2(0.45, 0.65), Vector2(0, 0.9),
					Vector2(-0.45, 0.65), Vector2(-0.6, 0.15), Vector2(-0.3, -0.2), Vector2(-0.1, 0.2), Vector2(0.05, -0.3)])
		"water":
			_icon_poly(ci, c, s, color, [Vector2(0, -1), Vector2(0.35, -0.35), Vector2(0.6, 0.2), Vector2(0.45, 0.65), Vector2(0, 0.85),
					Vector2(-0.45, 0.65), Vector2(-0.6, 0.2), Vector2(-0.35, -0.35)])
		"electric":
			_icon_poly(ci, c, s, color, [Vector2(0.25, -1), Vector2(-0.45, 0.1), Vector2(-0.02, 0.1), Vector2(-0.25, 1), Vector2(0.5, -0.2), Vector2(0.06, -0.2)])
		"grass", "bug":
			_icon_poly(ci, c, s, color, [Vector2(0, -0.95), Vector2(0.55, -0.35), Vector2(0.55, 0.3), Vector2(0, 0.95), Vector2(-0.55, 0.3), Vector2(-0.55, -0.35)])
			ci.draw_line(c + Vector2(0, -0.7) * s, c + Vector2(0, 0.8) * s, Color(0, 0, 0, 0.35), 2.0)
		"poison":
			for p: Vector2 in [Vector2(-0.35, 0.25), Vector2(0.35, 0.3), Vector2(0, -0.35)]:
				ci.draw_circle(c + p * s, 0.42 * s, color)
		"psychic":
			ci.draw_arc(c, 0.75 * s, 0, TAU, 32, color, 0.22 * s, true)
			ci.draw_circle(c, 0.3 * s, color)
		"ghost":
			_icon_poly(ci, c, s, color, [Vector2(-0.6, 0.9), Vector2(-0.6, -0.2), Vector2(-0.4, -0.75), Vector2(0, -0.95), Vector2(0.4, -0.75),
					Vector2(0.6, -0.2), Vector2(0.6, 0.9), Vector2(0.3, 0.6), Vector2(0, 0.9), Vector2(-0.3, 0.6)])
		"dragon", "fighting":
			_icon_poly(ci, c, s, color, [Vector2(0, -1), Vector2(0.28, -0.28), Vector2(1, 0), Vector2(0.28, 0.28), Vector2(0, 1),
					Vector2(-0.28, 0.28), Vector2(-1, 0), Vector2(-0.28, -0.28)])
		"ice":
			for a: float in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var d := Vector2(cos(a), sin(a)) * 0.9 * s
				ci.draw_line(c - d, c + d, color, 0.2 * s, true)
		"rock", "ground", "steel":
			_icon_poly(ci, c, s, color, [Vector2(-0.2, -0.85), Vector2(0.6, -0.5), Vector2(0.85, 0.3), Vector2(0.2, 0.85), Vector2(-0.7, 0.55), Vector2(-0.85, -0.2)])
		"dark":
			ci.draw_circle(c, 0.8 * s, color)
			ci.draw_circle(c + Vector2(0.35, -0.25) * s, 0.65 * s, Color(0, 0, 0, 0.55))
		"flying":
			_icon_poly(ci, c, s, color, [Vector2(-0.9, 0.4), Vector2(-0.3, -0.6), Vector2(0.9, -0.8), Vector2(0.3, 0.0), Vector2(0.7, 0.2), Vector2(-0.1, 0.6)])
		"super":
			var star: Array[Vector2] = []
			for i in 10:
				var r := 1.0 if i % 2 == 0 else 0.45
				var a := -PI / 2.0 + PI / 5.0 * i
				star.append(Vector2(cos(a), sin(a)) * r)
			_icon_poly(ci, c, s, color, star)
		_:
			ci.draw_circle(c, 0.6 * s, color)


## Filled, outlined polygon from unit-size points around `c`, scaled by `s`.
static func _icon_poly(ci: CanvasItem, c: Vector2, s: float, color: Color, points: Array) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in points:
		pts.append(c + p * s)
	ci.draw_colored_polygon(pts, color)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0, 0, 0, 0.35), 2.0, true)
