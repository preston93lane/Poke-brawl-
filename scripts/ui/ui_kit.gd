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
	s.border_width_bottom = 4
	s.border_color = color.darkened(0.35)
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
	parts.append("Power %d" % move.power)
	match move.kind:
		"melee":
			parts.append("Reach %.1fm" % move.reach)
			parts.append("%d° swing" % move.arc)
			parts.append("%.1fs cooldown" % move.cooldown)
		"dash":
			parts.append("Dash %.1fm" % move.dash_distance)
			parts.append("%.1fs cooldown" % move.cooldown)
		"projectile":
			parts.append("Range %.1fm" % move.reach)
			parts.append("%d ammo, %.1fs reload" % [move.ammo, move.reload])
			if move.count > 1:
				parts.append("%d shots" % move.count)
			if move.burst_count > 1:
				parts.append("%d-hit stream" % move.burst_count)
			if move.pierce:
				parts.append("pierces")
			if move.explode_radius > 0.0:
				parts.append("%.1fm blast" % move.explode_radius)
	if move.crit_chance > 0.0:
		parts.append("%d%% crit" % roundi(move.crit_chance * 100))
	if not move.effect.is_empty():
		var names := { "burn": "burn", "poison": "poison", "slow": "paralyze" }
		parts.append("%d%% %s" % [roundi(float(move.effect.get("chance", 1.0)) * 100), names.get(move.effect.get("type", ""), "effect")])
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
	top.add_child(label("MELEE" if move.slot == "melee" else "RANGED", 16, Color(0.7, 0.8, 1)))
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


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s
