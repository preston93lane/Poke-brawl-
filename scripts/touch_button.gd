class_name TouchButton
extends Control
## Round multi-touch button (GADGET, SUPER) with a shaded body, type icon,
## cooldown sweep or charge fill, and the move name in a pill underneath.

signal pressed
## Aimable buttons (supers): released after a drag, with the drag as a stick output.
signal aim_released(output: Vector2)

@export var label := "GADGET"
@export var color := Color(1.0, 0.55, 0.15)
## Type emblem drawn in the middle ("fire", "water"...; "super" draws a star).
@export var icon_type := ""
## "cooldown" shows a dark sweep counting down; "charge" fills up and glows when full.
@export_enum("cooldown", "charge") var display := "cooldown"

## Uses left, drawn as pips around the top (-1 = unlimited, no pips).
var uses := -1:
	set(value):
		if value != uses:
			uses = value
			queue_redraw()
var enabled := true
## Drag from the button to aim, like the attack stick; a tap still emits `pressed`.
var aimable := false
var aim_radius := 110.0
## Current drag while held (length 0..1), zero when not aiming.
var aim_output := Vector2.ZERO
var _origin := Vector2.ZERO
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
	aim_output = Vector2.ZERO


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
	if not enabled:
		return
	var drag := event as InputEventScreenDrag
	if drag and aimable and drag.index == _touch_index:
		aim_output = ((drag.position - _origin) / aim_radius).limit_length(1.0)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventScreenTouch:
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and _touch_index == -1 and contains_screen_point(touch.position):
		_touch_index = touch.index
		_origin = touch.position
		aim_output = Vector2.ZERO
		if not aimable:
			pressed.emit()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif not touch.pressed and touch.index == _touch_index:
		_touch_index = -1
		if aimable:
			# A real drag aims; a short tap auto-aims.
			if aim_output.length() > 0.25:
				aim_released.emit(aim_output)
			else:
				pressed.emit()
		aim_output = Vector2.ZERO
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
	if uses >= 0:
		var total := maxi(uses, int(GameData.rule("gadget/uses", 3)))
		for i in total:
			var angle := -PI * 0.5 + (float(i) - (total - 1) * 0.5) * 0.42
			var pip := center + Vector2(cos(angle), sin(angle)) * (r + 9.0)
			draw_circle(pip, 7.0, Color(0.1, 0.1, 0.15, 0.8))
			draw_circle(pip, 5.0, Color(0.55, 1.0, 0.75) if i < uses else Color(0.35, 0.35, 0.4))
