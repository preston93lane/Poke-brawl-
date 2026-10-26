class_name TouchButton
extends Control
## Round multi-touch button with a cooldown sweep. Used for melee.

signal pressed

@export var label := "MELEE"
@export var color := Color(1.0, 0.55, 0.15)

var enabled := true
var _touch_index := -1
var _cooldown := 0.0


static func any_contains(screen_pos: Vector2) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	for node in tree.get_nodes_in_group("touch_buttons"):
		var button := node as TouchButton
		if button and button.is_visible_in_tree() and button.contains_screen_point(screen_pos):
			return true
	return false


func _ready() -> void:
	add_to_group("touch_buttons")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	_touch_index = -1


## ratio: 1 = just used, 0 = ready.
func set_cooldown(ratio: float) -> void:
	if not is_equal_approx(ratio, _cooldown):
		_cooldown = ratio
		queue_redraw()


func contains_screen_point(screen_pos: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	return local.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5


func _input(event: InputEvent) -> void:
	if not enabled or not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and _touch_index == -1 and contains_screen_point(touch.position):
		_touch_index = touch.index
		pressed.emit()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var is_ready := _cooldown <= 0.0
	var fill := color if is_ready else color.darkened(0.55)
	if _touch_index != -1:
		fill = fill.lightened(0.25)
	draw_circle(center, r, Color(fill, 0.85))
	if not is_ready:
		# Sweep showing how much cooldown is left.
		draw_arc(center, r - 5.0, -PI / 2, -PI / 2 + TAU * _cooldown, 48, Color(1, 1, 1, 0.8), 6.0, true)
	draw_arc(center, r, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 3.0, true)
	var font := ThemeDB.fallback_font
	var font_size := 22 if label.length() <= 8 else 16
	var text_pos := Vector2(0, center.y + font_size * 0.35)
	draw_string_outline(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 6, Color(0, 0, 0, 0.8))
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)
