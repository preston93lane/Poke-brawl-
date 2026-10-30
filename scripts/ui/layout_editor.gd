extends Control
## Settings → Controls: drag the move stick, attack stick, gadget and super
## buttons to where your thumbs like them. Saved to GameData settings and used
## by the HUD in every match.

const LABELS := { "move": "MOVE", "aim": "ATTACK", "gadget": "GADGET", "super": "SUPER", "hm": "HM", "zmove": "Z" }
const COLORS := {
	"move": Color(0.85, 0.9, 1.0), "aim": Color(1, 0.85, 0.3),
	"gadget": Color(0.4, 0.9, 0.6), "super": Color(1, 0.75, 0.15), "hm": Color(0.75, 0.6, 1.0),
	"zmove": Color(1, 0.9, 0.4),
}

var layout: Dictionary = {}
var _dragging := ""
var _grab_offset := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	layout = GameData.control_layout()


func save() -> void:
	GameData.set_setting("layout", layout)


func reset() -> void:
	layout = GameData.DEFAULT_LAYOUT.duplicate(true)
	queue_redraw()


## Left-handed: mirror everything left/right and swap which side each stick uses.
func swap_sides() -> void:
	for key: String in LABELS:
		var at: Array = layout[key]
		layout[key] = [1.0 - float(at[0]), float(at[1])]
	layout["swapped"] = not bool(layout.get("swapped", false))
	queue_redraw()


func change_scale(by: float) -> void:
	layout["scale"] = clampf(float(layout.get("scale", 1.0)) + by, 0.6, 1.6)
	queue_redraw()


func _radius(key: String) -> float:
	var scale := float(layout.get("scale", 1.0))
	return (110.0 if key in ["move", "aim"] else 55.0) * scale


func _center(key: String) -> Vector2:
	var at: Array = layout[key]
	return Vector2(float(at[0]), float(at[1])) * size


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = ""
			# Buttons sit on top of the sticks, so check them first.
			for key in ["zmove", "hm", "gadget", "super", "aim", "move"]:
				if mb.position.distance_to(_center(key)) <= _radius(key):
					_dragging = key
					_grab_offset = _center(key) - mb.position
					break
		else:
			_dragging = ""
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm and _dragging != "":
		_move(_dragging, mm.position + _grab_offset)
		accept_event()


## Keep controls on screen, and each stick on its own half.
func _move(key: String, pos: Vector2) -> void:
	var r := _radius(key)
	var frac := Vector2(clampf(pos.x, r, size.x - r) / size.x, clampf(pos.y, size.y * 0.3 + r * 0.5, size.y - r * 0.6) / size.y)
	var swapped := bool(layout.get("swapped", false))
	if key == "move":
		frac.x = clampf(frac.x, 0.5 if swapped else 0.0, 0.5 if not swapped else 1.0)
	elif key == "aim":
		frac.x = clampf(frac.x, 0.0 if swapped else 0.5, 0.5 if swapped else 1.0)
	layout[key] = [frac.x, frac.y]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.3, 0.2))
	# A hint of an arena behind the controls.
	for y in range(0, int(size.y), 64):
		for x in range(0, int(size.x), 64):
			if (x / 64 + y / 64) % 2 == 0:
				draw_rect(Rect2(x, y, 64, 64), Color(0.18, 0.34, 0.22))
	draw_line(Vector2(size.x * 0.5, size.y * 0.3), Vector2(size.x * 0.5, size.y), Color(1, 1, 1, 0.2), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, size.y * 0.3 - 10), "Drag the controls. Each stick works anywhere on its half of the screen (below this line).",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, 0.75))
	draw_line(Vector2(0, size.y * 0.3), Vector2(size.x, size.y * 0.3), Color(1, 1, 1, 0.2), 2.0)
	for key in ["move", "aim", "gadget", "super", "hm", "zmove"]:
		var c := _center(key)
		var r := _radius(key)
		var color: Color = COLORS[key]
		draw_circle(c, r + 4, Color(0, 0, 0, 0.3))
		if key in ["move", "aim"]:
			draw_circle(c, r, Color(color.darkened(0.6), 0.45))
			draw_arc(c, r, 0, TAU, 48, Color(color, 0.8), 4.0, true)
			UiKit.draw_shaded_circle(self, c, r * 0.42, color)
		else:
			UiKit.draw_shaded_circle(self, c, r, color)
		if key == _dragging:
			draw_arc(c, r + 8, 0, TAU, 48, Color.WHITE, 3.0, true)
		draw_string_outline(font, c + Vector2(-r, 6), LABELS[key], HORIZONTAL_ALIGNMENT_CENTER, r * 2, 18, 5, Color.BLACK)
		draw_string(font, c + Vector2(-r, 6), LABELS[key], HORIZONTAL_ALIGNMENT_CENTER, r * 2, 18, Color.WHITE)
