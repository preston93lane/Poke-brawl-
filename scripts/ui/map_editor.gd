extends VBoxContainer
## Map maker: paint an arena tile by tile, pick its floor, walls and liquid,
## mirror as you paint (top/bottom or all four quadrants), then name and save it
## (or edit and save over a built-in map). Saved maps show up in every mode
## they support and can be tested straight away.

const WIDTH := 36
const HEIGHT := 48
## [char, label, colour on the editor grid]
const PALETTE := [
	[".", "FLOOR", Color(0, 0, 0, 0)],
	[",", "PATH", Color(0.85, 0.72, 0.5)],
	["\"", "TALL GRASS", Color(0.2, 0.62, 0.22)],
	["#", "WALL", Color(0.52, 0.5, 0.5)],
	["X", "CRACKED WALL", Color(0.75, 0.56, 0.36)],
	["B", "BOULDER", Color(0.6, 0.52, 0.42)],
	["I", "ICE BLOCK", Color(0.7, 0.88, 0.98)],
	["T", "TREE", Color(0.12, 0.4, 0.16)],
	["K", "GRAVESTONE", Color(0.62, 0.62, 0.7)],
	["~", "WATER / LAVA", Color(0.2, 0.45, 0.85)],
	["1", "BLUE SPAWN", Color(0.25, 0.55, 1.0)],
	["2", "RED SPAWN", Color(1.0, 0.3, 0.3)],
	["Z", "ZONE / MINE", Color(1, 1, 1, 0.65)],
	["G", "GOAL", Color(1, 0.95, 0.4)],
	["S", "SHOWDOWN SPAWN", Color(0.8, 0.4, 1.0)],
	["P", "CRATE", Color(0.55, 0.8, 0.3)],
	["F", "FIRE VENT", Color(1.0, 0.45, 0.1)],
	["O", "WARP PAD", Color(0.75, 0.35, 0.95)],
]
const FLOORS := ["grass", "gym_floor", "sand", "wood", "metal", "pool", "ice", "dark", "psychic", "volcanic", "path"]
const WALLS := ["rock", "metal_wall", "brick", "hedge", "ice_block", "wood_wall", "cracked"]
const LIQUIDS := ["water", "lava"]
## Map-wide hazards (warp pads and fire vents are tiles instead).
const WEATHER := ["none", "lightning"]
const MIRRORS := [["off", "OFF"], ["vertical", "TOP ↔ BOTTOM"], ["quad", "QUADRANTS"]]
const TEST_MODES := [["duel", "BATTLE"], ["king_of_the_hill", "KING OF THE HILL"], ["brawl_ball", "BRAWL BALL"],
		["candy_rush", "CANDY RUSH"], ["showdown", "SHOWDOWN"]]

## Copies of the constants for map_canvas.gd (which only holds an untyped reference).
var width := WIDTH
var height := HEIGHT
var palette := PALETTE
## The menu that opened us (to go back or start a test match).
var menu: Node
var arena_id := ""
var rows: Array[String] = []
var floor_tile := "grass"
var wall_tile := "rock"
var liquid := "water"
var extra: Dictionary = {}
var brush := "#"
var mirror := "vertical"
var paint_tool := "paint"
var test_mode := "duel"

## The map grid (map_canvas.gd).
var _canvas
var _panel: VBoxContainer
var _name_edit: LineEdit
var _status: Label
var _textures := {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.add_child(UiKit.button("‹ BACK", func() -> void: menu.show_battle_modes(), 20))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Map name"
	_name_edit.custom_minimum_size = Vector2(260, 48)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.web_typable(_name_edit, "Map name")
	top.add_child(_name_edit)
	top.add_child(UiKit.button("NEW", new_map, 20))
	top.add_child(UiKit.button("OPEN", _show_open_list, 20))
	var save_button := UiKit.button("SAVE", func() -> void: save(), 20)
	save_button.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.6, 0.35)))
	top.add_child(save_button)
	top.add_child(UiKit.button("TEST ›", _test, 20))
	add_child(top)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_canvas = preload("res://scripts/ui/map_canvas.gd").new()
	_canvas.editor = self
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_canvas)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 6)
	var side := UiKit.panel(UiKit.scroll(_panel))
	side.custom_minimum_size.x = 330
	body.add_child(side)
	add_child(body)
	_status = UiKit.label("", 16, Color(0.85, 0.9, 1.0))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	new_map()


# --- Map data ----------------------------------------------------------------

func new_map() -> void:
	arena_id = ""
	_name_edit.text = ""
	floor_tile = "grass"
	wall_tile = "rock"
	liquid = "water"
	extra = { "raid_boss": "zapdos", "guardian": "celebi" }
	rows.clear()
	for y in HEIGHT:
		var row := ""
		for x in WIDTH:
			row += "#" if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1 else "."
		rows.append(row)
	# Default spawns so a fresh map is playable right away.
	for i in 3:
		_set_cell(Vector2i(15 + i * 3, HEIGHT - 4), "1", false)
		_set_cell(Vector2i(15 + i * 3, 3), "2", false)
	_show_tools()
	_refresh()


func load_map(id: String) -> void:
	var def: Dictionary = GameData.arenas.get(id, {})
	if def.is_empty():
		return
	arena_id = id
	_name_edit.text = str(def.get("name", id))
	floor_tile = str(def.get("floor", "grass"))
	wall_tile = str(def.get("wall", "rock"))
	liquid = str(def.get("liquid", "water"))
	extra = {}
	for key in ["raid_boss", "guardian", "modes", "weather"]:
		if def.has(key):
			extra[key] = def[key]
	rows.clear()
	var src: Array = def.get("map", [])
	for y in HEIGHT:
		var line := str(src[y]) if y < src.size() else ""
		line = line.substr(0, WIDTH)
		while line.length() < WIDTH:
			line += "."
		rows.append(line)
	_show_tools()
	_refresh()


func to_def() -> Dictionary:
	var def := {
		"name": _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "My Map",
		"floor": floor_tile, "wall": wall_tile, "liquid": liquid, "map": rows.duplicate(),
	}
	def.merge(extra)
	# A built-in map limited to one mode (Pallet Pitch) stays limited only while it can still do that mode.
	return def


## Saves under the current id (a built-in map's id keeps it in place), or a new id from the name.
func save() -> String:
	if arena_id == "":
		var slug := _name_edit.text.strip_edges().to_lower().replace(" ", "_").validate_filename()
		if slug == "":
			slug = "map"
		arena_id = "custom_" + slug
		var n := 2
		while GameData.arenas.has(arena_id) and GameData.is_custom_arena(arena_id):
			arena_id = "custom_%s_%d" % [slug, n]
			n += 1
	GameData.save_custom_arena(arena_id, to_def())
	_status.text = "Saved \"%s\". %s" % [to_def()["name"], _summary()]
	return arena_id


func cell(c: Vector2i) -> String:
	return rows[c.y][c.x]


## Paint one cell, plus its mirror images. Mirrored to the other half, team
## spawns swap colour so both teams get the same layout.
func paint(c: Vector2i) -> void:
	if c.x < 0 or c.y < 0 or c.x >= WIDTH or c.y >= HEIGHT:
		return
	_set_cell(c, brush, false)
	if mirror == "vertical" or mirror == "quad":
		_set_cell(Vector2i(c.x, HEIGHT - 1 - c.y), brush, true)
	if mirror == "quad":
		_set_cell(Vector2i(WIDTH - 1 - c.x, c.y), brush, false)
		_set_cell(Vector2i(WIDTH - 1 - c.x, HEIGHT - 1 - c.y), brush, true)
	_canvas.queue_redraw()


func _set_cell(c: Vector2i, tile: String, flipped: bool) -> void:
	if flipped:
		tile = { "1": "2", "2": "1" }.get(tile, tile)
	var row := rows[c.y]
	rows[c.y] = row.substr(0, c.x) + tile + row.substr(c.x + 1)


func count(tile: String) -> int:
	var n := 0
	for row in rows:
		n += row.count(tile)
	return n


## Which modes the map can host, and what's missing for the others.
func _summary() -> String:
	var notes: Array[String] = []
	var blue := count("1")
	var red := count("2")
	if blue < 3 or red < 3:
		notes.append("Team modes need 3 blue and 3 red spawns (have %d / %d)." % [blue, red])
	if count("Z") == 0:
		notes.append("No zone: King of the Hill is off (Candy Rush uses the middle).")
	if count("G") == 0:
		notes.append("No goals: Brawl Ball is off.")
	if count("S") < 6:
		notes.append("Showdown spawns will be placed automatically.")
	return " ".join(notes) if not notes.is_empty() else "Ready for every mode."


func _refresh() -> void:
	_canvas.queue_redraw()
	_status.text = _summary()


func texture(tile_name: String) -> Texture2D:
	if not _textures.has(tile_name):
		var path := "res://assets/tiles/%s.png" % tile_name
		_textures[tile_name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[tile_name]


# --- Side panel ----------------------------------------------------------------

func _show_tools() -> void:
	_clear(_panel)
	_panel.add_child(_section("MIRROR WHILE PAINTING"))
	_panel.add_child(_choice_row(MIRRORS, mirror, func(v: String) -> void: mirror = v))
	_panel.add_child(_section("TOOL"))
	var tools := HFlowContainer.new()
	var group := ButtonGroup.new()
	for entry in [["paint", "PAINT"], ["pan", "MOVE VIEW"]]:
		var b := _toggle(entry[1], group, paint_tool == entry[0])
		b.pressed.connect(func() -> void: paint_tool = entry[0])
		tools.add_child(b)
	tools.add_child(UiKit.button("ZOOM −", func() -> void: _canvas.zoom_by(-0.5), 18))
	tools.add_child(UiKit.button("ZOOM +", func() -> void: _canvas.zoom_by(0.5), 18))
	_panel.add_child(tools)
	_panel.add_child(_section("TILES"))
	var palette := GridContainer.new()
	palette.columns = 2
	var tile_group := ButtonGroup.new()
	for entry in PALETTE:
		var b := _toggle(entry[1], tile_group, brush == entry[0])
		b.add_theme_font_size_override("font_size", 15)
		b.icon = _swatch(entry[0], entry[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: brush = entry[0])
		palette.add_child(b)
	_panel.add_child(palette)
	_panel.add_child(_section("FLOOR"))
	_panel.add_child(_cycler(FLOORS, func() -> String: return floor_tile, func(v: String) -> void: floor_tile = v))
	_panel.add_child(_section("WALLS"))
	_panel.add_child(_cycler(WALLS, func() -> String: return wall_tile, func(v: String) -> void: wall_tile = v))
	_panel.add_child(_section("LIQUID  (water: Water/Flying cross it · lava: Fire/Flying)"))
	_panel.add_child(_cycler(LIQUIDS, func() -> String: return liquid, func(v: String) -> void: liquid = v))
	_panel.add_child(_section("WEATHER  (lightning strikes; Electric/Ground are immune)"))
	_panel.add_child(_cycler(WEATHER, func() -> String: return str(extra.get("weather", "none")),
			func(v: String) -> void:
				if v == "none":
					extra.erase("weather")
				else:
					extra["weather"] = v))
	_panel.add_child(_section("TEST IN"))
	_panel.add_child(_choice_row(TEST_MODES, test_mode, func(v: String) -> void: test_mode = v))
	if arena_id != "" and GameData.is_custom_arena(arena_id):
		var label := "REVERT TO ORIGINAL" if arena_id in GameData.builtin_arenas else "DELETE MAP"
		var delete := UiKit.button(label, _delete_current, 18)
		delete.add_theme_stylebox_override("normal", UiKit.box(Color(0.7, 0.25, 0.25)))
		_panel.add_child(delete)


func _delete_current() -> void:
	GameData.delete_custom_arena(arena_id)
	if GameData.arenas.has(arena_id):
		load_map(arena_id)
	else:
		new_map()


func _show_open_list() -> void:
	_clear(_panel)
	_panel.add_child(UiKit.button("‹ BACK TO TOOLS", _show_tools, 18))
	_panel.add_child(_section("OPEN A MAP"))
	var ids: Array = GameData.arenas.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(GameData.arenas[a].get("name", a)) < str(GameData.arenas[b].get("name", b)))
	for id: String in ids:
		var tag := ""
		if GameData.is_custom_arena(id):
			tag = "  (edited)" if id in GameData.builtin_arenas else "  (yours)"
		var b := UiKit.button(str(GameData.arenas[id].get("name", id)) + tag, load_map.bind(id), 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_panel.add_child(b)


func _test() -> void:
	var id := save()
	if id not in GameData.arenas_for_mode(test_mode):
		_status.text = "This map can't host %s yet. %s" % [test_mode.replace("_", " "), _summary()]
		return
	menu._arena = id
	menu.show_select(test_mode)


func _section(text: String) -> Label:
	return UiKit.label(text, 15, Color(1, 0.85, 0.4))


func _toggle(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.add_theme_font_size_override("font_size", 17)
	return b


func _choice_row(options: Array, current: String, on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	var group := ButtonGroup.new()
	for entry: Array in options:
		var b := _toggle(entry[1], group, current == entry[0])
		b.pressed.connect(on_pick.bind(entry[0]))
		row.add_child(b)
	return row


## "‹ SAND ›" style picker that redraws the map preview.
func _cycler(options: Array, getter: Callable, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := UiKit.label(str(getter.call()).replace("_", " ").to_upper(), 18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var step := func(by: int) -> void:
		var index := maxi(0, options.find(getter.call()))
		var value: String = options[posmod(index + by, options.size())]
		setter.call(value)
		label.text = value.replace("_", " ").to_upper()
		_canvas.queue_redraw()
	row.add_child(UiKit.button("‹", step.bind(-1), 20))
	row.add_child(label)
	row.add_child(UiKit.button("›", step.bind(1), 20))
	return row


func _swatch(tile: String, color: Color) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(color if color.a > 0.0 else Color(0.55, 0.75, 0.45))
	for i in 24:
		img.set_pixel(i, 0, Color.BLACK)
		img.set_pixel(i, 23, Color.BLACK)
		img.set_pixel(0, i, Color.BLACK)
		img.set_pixel(23, i, Color.BLACK)
	return ImageTexture.create_from_image(img)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
