class_name TouchButton
extends Control
## Round multi-touch button (MELEE, SUPER) with a shaded body, type icon,
## cooldown sweep or charge fill, and the move name in a pill underneath.

signal pressed

@export var label := "MELEE"
@export var color := Color(1.0, 0.55, 0.15)
## Type emblem drawn in the middle ("fire", "water"...; "super" draws a star).
@export var icon_type := ""
## "cooldown" shows a dark sweep counting down; "charge" fills up and glows when full.
@export_enum("cooldown", "charge") var display := "cooldown"

var enabled := true
var _touch_index := -1
var _cooldown := 0.0
var _charge := 0.0


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


## ratio: 0 = empty, 1 = ready.
func set_charge(ratio: float) -> void:
	if not is_equal_approx(ratio, _charge):
		_charge = ratio
		queue_redraw()


func _process(_delta: float) -> void:
	if display == "charge" and _charge >= 1.0:
		queue_redraw()  # Pulse while ready.


func contains_screen_point(screen_pos: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	return local.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.55


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
	var held := _touch_index != -1
	var center := size * 0.5 + (Vector2(0, 3) if held else Vector2.ZERO)
	var r := minf(size.x, size.y) * 0.5
	var is_ready := _cooldown <= 0.0 if display == "cooldown" else _charge >= 1.0

	if display == "charge" and is_ready:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		draw_circle(center, r + 8.0 + pulse * 6.0, Color(color, 0.18 + pulse * 0.15))
		draw_circle(center, r + 4.0, Color(color.lightened(0.4), 0.5))
	UiKit.draw_drop_shadow(self, center, r)
	var body := color if is_ready else color.darkened(0.5).lerp(Color(0.35, 0.37, 0.45), 0.5)
	UiKit.draw_shaded_circle(self, center, r, body)

	if display == "charge" and not is_ready:
		# Gold fills clockwise as you deal damage.
		UiKit.draw_pie(self, center, r * 0.92, _charge, Color(color, 0.85))
	elif display == "cooldown" and not is_ready:
		UiKit.draw_pie(self, center, r * 0.92, _cooldown, Color(0, 0, 0, 0.45))

	draw_arc(center, r - 1.5, 0.0, TAU, 48, Color(1, 1, 1, 0.85 if is_ready else 0.4), 3.0, true)
	draw_arc(center, r * 0.82, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.35), 3.0, true)
	var icon := icon_type if icon_type != "" else ("super" if display == "charge" else "normal")
	UiKit.draw_type_icon(self, icon, center, r * 0.42, Color(1, 1, 1, 0.95 if is_ready else 0.55))
	UiKit.draw_pill(self, Vector2(size.x * 0.5, size.y + 14.0), label, 15 if label.length() > 10 else 17)
