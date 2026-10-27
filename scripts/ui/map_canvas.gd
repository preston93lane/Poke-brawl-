extends Control
## The map maker's grid: draws every tile and turns drags into painting (or
## panning the view when zoomed in).

## The map_editor.gd that owns the map data.
var editor
var zoom := 1.0
var pan := Vector2.ZERO
var _held := false
var _last := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, 1.0, 3.0)
	if is_equal_approx(zoom, 1.0):
		pan = Vector2.ZERO
	queue_redraw()


func _cell_size() -> float:
	return minf(size.x / editor.width, size.y / editor.height) * zoom


func _origin() -> Vector2:
	var map_size := Vector2(editor.width, editor.height) * _cell_size()
	return (size - map_size) * 0.5 + pan


func cell_at(local: Vector2) -> Vector2i:
	var c := (local - _origin()) / _cell_size()
	return Vector2i(floori(c.x), floori(c.y))


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(0.25)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(-0.25)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_held = mb.pressed
			_last = mb.position
			if mb.pressed and editor.paint_tool == "paint":
				editor.paint(cell_at(mb.position))
			if not mb.pressed:
				editor._refresh()
		accept_event()
	var mm := event as InputEventMouseMotion
	if mm and _held:
		if editor.paint_tool == "paint":
			# Paint every cell along the drag so fast strokes don't leave gaps.
			var steps := maxi(1, ceili(_last.distance_to(mm.position) / maxf(2.0, _cell_size() * 0.5)))
			for i in steps:
				editor.paint(cell_at(_last.lerp(mm.position, float(i + 1) / steps)))
		else:
			pan += mm.position - _last
			queue_redraw()
		_last = mm.position
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.14))
	var cs := _cell_size()
	var origin := _origin()
	var floor_tex: Texture2D = editor.texture("grass_0" if editor.floor_tile == "grass" else editor.floor_tile)
	var wall_tex: Texture2D = editor.texture(editor.wall_tile)
	var liquid_tex: Texture2D = editor.texture("lava" if editor.liquid == "lava" else "water")
	var textures := {
		"#": wall_tex, "X": editor.texture("cracked"), "B": editor.texture("boulder"), "I": editor.texture("ice_block"),
		"~": liquid_tex, "P": editor.texture("crate"), ",": editor.texture("path"),
	}
	var colors := {}
	for entry: Array in editor.palette:
		colors[entry[0]] = entry[2]
	for y in editor.height:
		for x in editor.width:
			var r := Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs))
			if not r.intersects(Rect2(Vector2.ZERO, size)):
				continue
			var tile: String = editor.rows[y][x]
			if floor_tex:
				draw_texture_rect(floor_tex, r, false)
			var tex: Texture2D = textures.get(tile)
			if tex:
				draw_texture_rect(tex, r, false)
			elif tile != ".":
				var c: Color = colors.get(tile, Color.MAGENTA)
				draw_rect(r.grow(-cs * 0.08), c)
				if tile in ["T", "K"]:
					draw_circle(r.get_center(), cs * 0.32, c.darkened(0.3))
			if tile in ["1", "2", "S"] and cs > 9.0:
				draw_string(ThemeDB.fallback_font, r.position + Vector2(0, cs * 0.75), tile, HORIZONTAL_ALIGNMENT_CENTER, cs, int(cs * 0.7), Color.WHITE)
	# Grid lines and the mirror axes.
	var grid := Color(0, 0, 0, 0.18)
	for x in editor.width + 1:
		draw_line(origin + Vector2(x * cs, 0), origin + Vector2(x * cs, editor.height * cs), grid)
	for y in editor.height + 1:
		draw_line(origin + Vector2(0, y * cs), origin + Vector2(editor.width * cs, y * cs), grid)
	var axis := Color(1, 0.9, 0.3, 0.7)
	if editor.mirror in ["vertical", "quad"]:
		draw_line(origin + Vector2(0, editor.height * cs * 0.5), origin + Vector2(editor.width * cs, editor.height * cs * 0.5), axis, 2.0)
	if editor.mirror == "quad":
		draw_line(origin + Vector2(editor.width * cs * 0.5, 0), origin + Vector2(editor.width * cs * 0.5, editor.height * cs), axis, 2.0)
