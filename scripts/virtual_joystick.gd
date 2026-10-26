class_name VirtualJoystick
extends Control
## Multi-touch on-screen stick. The Control's rect is the touch zone; the
## stick rests at rest_anchor * size + rest_offset.
## Mouse clicks work too (project setting emulate_touch_from_mouse).

signal released(output: Vector2, was_tap: bool)

## A touch shorter than this that barely moved counts as a tap (auto-aim).
const TAP_MAX_MS := 350
const TAP_MAX_DRAG := 0.5

@export var radius := 110.0
@export var knob_radius := 46.0
@export_range(0.0, 1.0) var deadzone := 0.2
## Floating sticks re-centre wherever the finger lands inside the zone.
@export var floating := true
@export var rest_anchor := Vector2(0.0, 1.0)
@export var rest_offset := Vector2(230, -190)
@export var color := Color(1, 1, 1)
## Text drawn under the stick (e.g. the equipped move's name).
@export var label := ""
## Type emblem on the knob (the aim stick shows the ranged move's type).
@export var icon_type := ""

## Current stick value, length 0..1 (zero inside the deadzone).
var output := Vector2.ZERO
var enabled := true

var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _max_drag := 0.0
var _press_ms := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset)
	_reset()


func set_enabled(value: bool) -> void:
	enabled = value
	visible = value
	_reset()


func is_active() -> bool:
	return _touch_index != -1


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var local := _to_local(touch.position)
		if touch.pressed and _touch_index == -1:
			if not Rect2(Vector2.ZERO, size).has_point(local) or TouchButton.any_contains(touch.position):
				return
			if not floating and local.distance_to(_rest_center()) > radius * 2.2:
				return
			_touch_index = touch.index
			_center = local if floating else _rest_center()
			_max_drag = 0.0
			_press_ms = Time.get_ticks_msec()
			_update_knob(local)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			var final_output := output
			var was_tap := _max_drag < deadzone or \
					(Time.get_ticks_msec() - _press_ms <= TAP_MAX_MS and _max_drag < TAP_MAX_DRAG)
			if was_tap:
				final_output = Vector2.ZERO
			_reset()
			released.emit(final_output, was_tap)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(_to_local(drag.position))
			get_viewport().set_input_as_handled()


func _update_knob(local: Vector2) -> void:
	var offset := (local - _center).limit_length(radius)
	_knob = offset
	var raw := offset / radius
	_max_drag = maxf(_max_drag, raw.length())
	output = raw if raw.length() >= deadzone else Vector2.ZERO
	queue_redraw()


func _reset() -> void:
	_touch_index = -1
	_center = _rest_center()
	_knob = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()


func _rest_center() -> Vector2:
	return size * rest_anchor + rest_offset


func _to_local(screen_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _draw() -> void:
	var active := is_active()
	var c := _center
	# Base: translucent dark well with a bright rim.
	draw_circle(c, radius + 6.0, Color(0, 0, 0, 0.18))
	for i in 6:
		var t := float(i) / 6.0
		draw_circle(c, radius * (1.0 - t * 0.5), Color(color.darkened(0.7), (0.22 if active else 0.14) * (1.0 - t * 0.5)))
	draw_arc(c, radius, 0.0, TAU, 64, Color(color, 0.75 if active else 0.4), 5.0, true)
	if active and _knob.length() > radius * 0.15:
		# Highlight the rim in the direction you're pushing.
		var a := _knob.angle()
		draw_arc(c, radius, a - 0.5, a + 0.5, 16, Color(1, 1, 1, 0.9), 7.0, true)
	# Knob: shadow, shaded body, rim, optional type icon.
	var k := c + _knob
	UiKit.draw_drop_shadow(self, k, knob_radius)
	UiKit.draw_shaded_circle(self, k, knob_radius, color, 0.95 if active else 0.75)
	draw_arc(k, knob_radius - 1.5, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 2.5, true)
	if icon_type != "":
		UiKit.draw_type_icon(self, icon_type, k, knob_radius * 0.45, Color(1, 1, 1, 0.9))
	if label != "" and not active:
		UiKit.draw_pill(self, c + Vector2(0, radius + 26), label, 17)
