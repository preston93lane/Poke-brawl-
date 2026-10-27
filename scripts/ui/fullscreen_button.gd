extends CanvasLayer
## Autoload "FullscreenButton": a small button in the top-right corner of every
## screen that toggles full screen. In the browser it uses the Fullscreen API
## (Chrome, Android, iPad Safari); iPhone Safari doesn't allow web pages to go
## full screen, so there it explains how to add the game to the Home Screen.

const SIZE := 44.0
const MARGIN := 6.0

var _button: Control
var _toast: Label
var _toast_time := 0.0
var _full := false
var _check := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button = Control.new()
	_button.custom_minimum_size = Vector2(SIZE, SIZE)
	_button.size = Vector2(SIZE, SIZE)
	_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_button.tooltip_text = "Full screen"
	_button.gui_input.connect(_on_input)
	_button.draw.connect(_draw_icon)
	add_child(_button)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	get_viewport().size_changed.connect(_place)
	_place()


func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	_button.position = Vector2(view.x - SIZE - MARGIN, MARGIN)
	_toast.size = Vector2(minf(520.0, view.x - 40.0), 80)
	_toast.position = Vector2(view.x - _toast.size.x - MARGIN, SIZE + MARGIN * 2)


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		var now := is_fullscreen()
		if now != _full:
			_full = now
			_button.queue_redraw()
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
		_toast.visible = _toast_time > 0.0


func _on_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	# Act on release: browsers only allow full screen right after a tap or click.
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		toggle()
		_button.accept_event()


func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("!!(document.fullscreenElement || document.webkitFullscreenElement)", true))
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func toggle() -> void:
	if not OS.has_feature("web"):
		var mode := DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(mode)
		return
	var supported := bool(JavaScriptBridge.eval("!!(document.fullscreenEnabled || document.webkitFullscreenEnabled)", true))
	if not supported:
		var standalone := bool(JavaScriptBridge.eval("!!(window.navigator.standalone || window.matchMedia('(display-mode: standalone)').matches)", true))
		_show_toast("Already full screen." if standalone else
				"iPhone Safari can't make web pages full screen. Tap Share → Add to Home Screen, then open the game from its icon.")
		return
	JavaScriptBridge.eval("""
		(function () {
			var d = document, el = d.documentElement;
			if (d.fullscreenElement || d.webkitFullscreenElement) {
				(d.exitFullscreen || d.webkitExitFullscreen).call(d);
			} else {
				var p = (el.requestFullscreen || el.webkitRequestFullscreen).call(el);
				if (p && p.then) {
					p.then(function () {
						if (screen.orientation && screen.orientation.lock) { screen.orientation.lock('landscape').catch(function () {}); }
					}).catch(function () {});
				}
			}
		})();
	""", true)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_time = 5.0


## Four corner brackets: pointing out to enter full screen, in to leave it.
func _draw_icon() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(10)
	_button.draw_style_box(sb, r)
	var inset := 11.0
	var arm := 8.0
	var full := _full
	var c := Color(1, 1, 1, 0.9)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var p := Vector2(lerpf(inset, SIZE - inset, corner.x), lerpf(inset, SIZE - inset, corner.y))
		var sx := 1.0 if corner.x == 0 else -1.0
		var sy := 1.0 if corner.y == 0 else -1.0
		if full:
			# Brackets point inward: the corner sits arm-length inside.
			p += Vector2(sx, sy) * arm
			sx = -sx
			sy = -sy
		_button.draw_line(p, p + Vector2(sx * arm, 0), c, 3.0)
		_button.draw_line(p, p + Vector2(0, sy * arm), c, 3.0)
