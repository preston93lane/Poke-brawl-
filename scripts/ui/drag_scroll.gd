class_name DragScroll
extends ScrollContainer
## Vertical scroll list that works with a finger: drag anywhere (even on top of
## buttons) to scroll, with a little momentum; a tap that didn't drag presses
## the button under it. Buttons inside are set to ignore the mouse so they can't
## grab the touch and stop the list from scrolling, and so a drag never ends up
## selecting whatever was under the finger.

## Pixels a touch has to move before it counts as a drag instead of a tap.
const DRAG_THRESHOLD := 14.0
const FRICTION := 4.0

var _tracking := false
var _dragging := false
var _start := Vector2.ZERO
var _last_y := 0.0
var _velocity := 0.0
var _fling := 0.0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	get_tree().node_added.connect(_on_node_added)
	_adopt(self)


func _adopt(node: Node) -> void:
	for child in node.get_children():
		_on_node_added(child)
		_adopt(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and is_ancestor_of(node):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _tracking or absf(_fling) < 5.0:
		return
	scroll_vertical = int(scroll_vertical - _fling * delta)
	_fling = move_toward(_fling, 0.0, absf(_fling) * FRICTION * delta + 20.0 * delta)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# Touches arrive twice: as touch events and as emulated mouse events. We act on the
	# touch events and swallow the left-button mouse copies inside the list.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and (_tracking or _inside(mb.position)):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if _tracking:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index != 0:
			return
		if touch.pressed and _inside(touch.position):
			_tracking = true
			_dragging = false
			_start = touch.position
			_last_y = touch.position.y
			_velocity = 0.0
			_fling = 0.0
			get_viewport().set_input_as_handled()
		elif not touch.pressed and _tracking:
			_tracking = false
			if _dragging:
				_fling = _velocity
			else:
				_tap(touch.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _tracking:
		var drag := event as InputEventScreenDrag
		if drag.index != 0:
			return
		if not _dragging and absf(drag.position.y - _start.y) > DRAG_THRESHOLD:
			_dragging = true
			_last_y = drag.position.y
		if _dragging:
			var dy := drag.position.y - _last_y
			_last_y = drag.position.y
			scroll_vertical = int(scroll_vertical - dy)
			var dt := maxf(get_process_delta_time(), 0.001)
			_velocity = lerpf(_velocity, dy / dt, 0.4)
		get_viewport().set_input_as_handled()


func _inside(screen_pos: Vector2) -> bool:
	return get_global_rect().has_point(screen_pos)


## Press the (enabled, visible) button under the finger, as if it had been clicked.
func _tap(screen_pos: Vector2) -> void:
	var button := _button_at(self, screen_pos)
	if button == null:
		return
	if button.toggle_mode:
		if button.button_group and button.button_pressed:
			button.pressed.emit()  # Re-tapping the selected option still counts.
			return
		button.button_pressed = not button.button_pressed
		if button.button_pressed or button.button_group == null:
			button.pressed.emit()
	else:
		button.pressed.emit()


func _button_at(node: Node, screen_pos: Vector2) -> BaseButton:
	for i in range(node.get_child_count() - 1, -1, -1):
		var child := node.get_child(i)
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		var found := _button_at(child, screen_pos)
		if found:
			return found
		if child is BaseButton:
			var b := child as BaseButton
			if not b.disabled and b.get_global_rect().has_point(screen_pos):
				return b
	return null
