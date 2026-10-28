extends Control
## Title screen → pick a mode → pick your Pokémon, level, main attack, team and
## arena → start. Also hosts the Pokédex.

const MAIN_SCENE := "res://scenes/main.tscn"
const MODES := {
	"duel": { "button": "BATTLE", "title": "BATTLE 3v3", "blurb": "Most KOs in 2:30 wins — or first to 25." },
	"king_of_the_hill": { "button": "KING OF THE HILL", "title": "KING OF THE HILL 3v3", "blurb": "Hold the zone with only your team in it." },
	"brawl_ball": { "button": "BRAWL BALL", "title": "BRAWL BALL 3v3", "blurb": "Kick the Poké Ball into their goal. First to 2." },
	"candy_rush": { "button": "RARE CANDY RUSH", "title": "RARE CANDY RUSH 3v3", "blurb": "Grab 10 Rare Candies from the mine and hold them for 10 s." },
	"showdown": { "button": "SHOWDOWN", "title": "SHOWDOWN", "blurb": "Everyone for themselves. Smash crates for power cubes. Last one standing wins." },
}

var _screen: Control
var _mode := "duel"
var _species: SpeciesData
var _level := 1
var _main := ""
## Branch for Eevee-style split lines ("" = random).
var _evolution := ""
var _shiny := false
## Species list filters: "" = all.
var _type_filter := ""
var _style_filter := ""
## "dex" (Pokédex number, default) or "name".
var _sort := "dex"
var _grid: GridContainer
var _group: ButtonGroup
## Chosen bot teammates / opponents; empty slots are filled randomly.
var _allies: Array[String] = []
var _enemies: Array[String] = []
var _arena := ""
var _difficulty := "normal"
var _details: VBoxContainer
var _details_scroll: ScrollContainer


func _ready() -> void:
	theme = UiKit.make_theme()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.16, 0.3, 0.62))
	gradient.set_color(1, Color(0.05, 0.07, 0.16))
	var bg_texture := GradientTexture2D.new()
	bg_texture.gradient = gradient
	bg_texture.fill_from = Vector2(0.5, 0)
	bg_texture.fill_to = Vector2(0.5, 1)
	var bg := TextureRect.new()
	bg.texture = bg_texture
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_restore_last_choices()
	show_home()


# --- Screens ---------------------------------------------------------------

func show_home() -> void:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	var title := UiKit.label("POKé BRAWL", 84, Color(1, 0.85, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	v.add_child(title)

	var starters := HBoxContainer.new()
	starters.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in ["bulbasaur", "charmander", "squirtle", "pikachu", "eevee", "gastly", "dratini"]:
		if GameData.species.has(id):
			starters.add_child(UiKit.sprite(GameData.species[id].sprite, 96))
	v.add_child(starters)
	var count := UiKit.label("%d Pokémon · %d play styles" % [GameData.species_by_line().size(), GameData.styles.size()], 20, Color(0.8, 0.85, 1))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(count)

	var modes := GridContainer.new()
	modes.columns = 3
	modes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modes.add_theme_constant_override("h_separation", 14)
	modes.add_theme_constant_override("v_separation", 14)
	for mode_id: String in MODES:
		var b := UiKit.button(MODES[mode_id]["button"], show_select.bind(mode_id), 24)
		b.custom_minimum_size = Vector2(300, 64)
		modes.add_child(b)
	var dex := UiKit.button("POKéDEX", show_pokedex.bind(""), 24)
	dex.custom_minimum_size = Vector2(300, 64)
	dex.add_theme_stylebox_override("normal", UiKit.box(Color(0.75, 0.3, 0.3)))
	modes.add_child(dex)
	for entry in [["MAP MAKER", show_map_editor], ["SETTINGS", show_settings]]:
		var extra := UiKit.button(entry[0], entry[1], 24)
		extra.custom_minimum_size = Vector2(300, 64)
		extra.add_theme_stylebox_override("normal", UiKit.box(Color(0.35, 0.38, 0.5)))
		modes.add_child(extra)
	v.add_child(modes)
	_set_screen(v)


func show_select(mode: String) -> void:
	_mode = mode
	if _species == null:
		_species = GameData.base_species()[0]
	var arenas: Array[String] = GameData.arenas_for_mode(mode)
	if _arena not in arenas:
		_arena = arenas[0]

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_home))
	var title := UiKit.label("%s  —  %s" % [MODES[mode]["title"], MODES[mode]["blurb"]], 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long blurbs shorten with "…" instead of pushing the START button off screen.
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 80
	top.add_child(title)
	var start := UiKit.button("START ›", _start_match, 30)
	start.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.7, 0.35)))
	start.add_theme_stylebox_override("hover", UiKit.box(Color(0.3, 0.78, 0.4)))
	top.add_child(start)
	root.add_child(top)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var left_box := VBoxContainer.new()
	left_box.add_child(_filter_row("TYPE", _type_options(), func() -> String: return _type_filter,
			func(value: String) -> void: _type_filter = value))
	left_box.add_child(_filter_row("STYLE", _style_options(), func() -> String: return _style_filter,
			func(value: String) -> void: _style_filter = value))
	left_box.add_child(_filter_row("SORT", [["dex", "No."], ["name", "A–Z"]], func() -> String: return _sort,
			func(value: String) -> void: _sort = value))
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_group = ButtonGroup.new()
	left_box.add_child(UiKit.scroll(_grid))
	var left := UiKit.panel(left_box)
	left.custom_minimum_size.x = 400
	body.add_child(left)
	_fill_species_grid()

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 10)
	_details_scroll = UiKit.scroll(_details)
	var right := UiKit.panel(_details_scroll)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	root.add_child(body)
	_set_screen(root)
	_refresh_select_details()


const LAYOUT_EDITOR := preload("res://scripts/ui/layout_editor.gd")
const MAP_EDITOR := preload("res://scripts/ui/map_editor.gd")


## Settings: drag the controls where you want them; size, sides, aim assist.
func show_settings() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var editor = LAYOUT_EDITOR.new()
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 8)
	top.add_child(UiKit.button("‹ SAVE & BACK", func() -> void:
		editor.save()
		show_home()))
	top.add_child(UiKit.label("  CONTROLS  ", 26))
	var size_label := UiKit.label("", 20)
	var update_size := func() -> void:
		size_label.text = "SIZE %d%%" % roundi(float(editor.layout["scale"]) * 100.0)
	top.add_child(UiKit.button("SIZE −", func() -> void:
		editor.change_scale(-0.1)
		update_size.call()))
	top.add_child(size_label)
	top.add_child(UiKit.button("SIZE +", func() -> void:
		editor.change_scale(0.1)
		update_size.call()))
	top.add_child(UiKit.button("SWAP SIDES", func() -> void: editor.swap_sides()))
	top.add_child(UiKit.button("RESET", func() -> void:
		editor.reset()
		update_size.call()))
	var assist := Button.new()
	assist.toggle_mode = true
	assist.button_pressed = bool(GameData.setting("aim_assist", true))
	assist.text = "AIM ASSIST: ON" if assist.button_pressed else "AIM ASSIST: OFF"
	assist.add_theme_font_size_override("font_size", 20)
	assist.toggled.connect(func(on: bool) -> void:
		GameData.set_setting("aim_assist", on)
		assist.text = "AIM ASSIST: ON" if on else "AIM ASSIST: OFF")
	top.add_child(assist)
	root.add_child(top)
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editor)
	_set_screen(root)
	update_size.call()


func show_map_editor() -> void:
	var editor = MAP_EDITOR.new()
	editor.menu = self
	_set_screen(editor)


func show_pokedex(selected_id: String) -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_home))
	var title := UiKit.label("POKéDEX", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)
	root.add_child(top)

	var all: Array[SpeciesData] = GameData.species_by_line()
	var selected: SpeciesData = GameData.species.get(selected_id, all[0])
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var list := VBoxContainer.new()
	var group := ButtonGroup.new()
	for s in all:
		var b := Button.new()
		b.text = "#%03d  %s" % [s.dex, s.display_name]
		b.icon = s.sprite
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s == selected
		b.add_theme_constant_override("icon_max_width", 48)
		b.pressed.connect(_show_dex_entry.bind(s))
		list.add_child(b)
	var left := UiKit.panel(UiKit.scroll(list))
	left.custom_minimum_size.x = 320
	body.add_child(left)

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 10)
	_details_scroll = UiKit.scroll(_details)
	var right := UiKit.panel(_details_scroll)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	root.add_child(body)
	_set_screen(root)
	_show_dex_entry(selected)


# --- Species list & filters ------------------------------------------------

func _fill_species_grid() -> void:
	_clear(_grid)
	for s in GameData.base_species(_sort == "name"):
		if not _matches_filters(s):
			continue
		var card := _species_button(s, _group, s == _species)
		card.pressed.connect(func() -> void:
			_species = s
			_main = ""
			_evolution = ""
			_refresh_select_details())
		_grid.add_child(card)
	if _grid.get_child_count() == 0:
		_grid.add_child(UiKit.label("No match", 18))


## Matches the Pokémon's own type(s): dual types show up under both.
func _matches_filters(s: SpeciesData) -> bool:
	if _style_filter != "" and s.style != _style_filter:
		return false
	return _type_filter == "" or s.has_type(_type_filter)


func _type_options() -> Array:
	var result := [["", "ALL"]]
	for t in GameData.all_types():
		result.append([t, t.to_upper()])
	return result


func _style_options() -> Array:
	var ids: Array = GameData.styles.keys()
	ids.sort()
	var result := [["", "ALL"]]
	for id: String in ids:
		if not id.begins_with("_"):
			result.append([id, str(GameData.style_info(id).get("label", id)).to_upper()])
	return result


## "TYPE ‹ FIRE ›" cycler: arrows step through `options` ([[value, text]...]).
func _filter_row(title: String, options: Array, getter: Callable, setter: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(UiKit.label(title, 16, Color(1, 0.85, 0.4)))
	var value_label := UiKit.label("", 18)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var refresh := func() -> void:
		for option: Array in options:
			if option[0] == getter.call():
				value_label.text = option[1]
	var step := func(by: int) -> void:
		var index := 0
		for i in options.size():
			if options[i][0] == getter.call():
				index = i
		setter.call(options[posmod(index + by, options.size())][0])
		refresh.call()
		_fill_species_grid()
	var prev := UiKit.button("‹", step.bind(-1), 20)
	var next := UiKit.button("›", step.bind(1), 20)
	prev.custom_minimum_size = Vector2(52, 40)
	next.custom_minimum_size = Vector2(52, 40)
	row.add_child(prev)
	row.add_child(value_label)
	row.add_child(next)
	refresh.call()
	return row


# --- Select screen details -------------------------------------------------

func _refresh_select_details() -> void:
	var keep_scroll := _details_scroll.scroll_vertical
	_clear(_details)
	var s := _species
	_details.add_child(_species_header(s, 112))
	for stat in ["hp", "attack", "defense", "speed"]:
		_details.add_child(UiKit.stat_bar(stat, _stat(s, stat)))

	_details.add_child(_style_box(s))

	if s.shiny_sheet:
		var shiny_row := HBoxContainer.new()
		var shiny_button := Button.new()
		shiny_button.text = "SHINY: ON" if _shiny else "SHINY: OFF"
		shiny_button.toggle_mode = true
		shiny_button.button_pressed = _shiny
		shiny_button.add_theme_font_size_override("font_size", 20)
		shiny_button.pressed.connect(func() -> void:
			_shiny = not _shiny
			_refresh_select_details())
		shiny_row.add_child(shiny_button)
		shiny_row.add_child(UiKit.label("  Play with shiny colours", 16, Color(0.75, 0.8, 0.9)))
		_details.add_child(shiny_row)

	_details.add_child(_section("LEVEL"))
	var levels := HBoxContainer.new()
	var level_group := ButtonGroup.new()
	for level in range(1, int(GameData.rule("level/max", 3)) + 1):
		var b := _toggle("Lv %d" % level, level_group, level == _level)
		b.pressed.connect(func() -> void:
			_level = level
			_refresh_select_details())
		levels.add_child(b)
	levels.add_child(UiKit.label("  Each level unlocks another attack (+5% stats, +4% attack power)", 16, Color(0.75, 0.8, 0.9)))
	_details.add_child(levels)

	_main = _valid_move("main", _main)
	_details.add_child(_section("MAIN ATTACK  (right stick: drag to aim, tap to auto-aim)"))
	var row := HFlowContainer.new()
	var move_group := ButtonGroup.new()
	for move in s.moves_for("main", 99):
		var unlock := s.unlock_level(move)
		var text := move.display_name if unlock <= _level else "%s (Lv%d)" % [move.display_name, unlock]
		var b := _toggle(text, move_group, move.id == _main)
		b.disabled = unlock > _level
		b.pressed.connect(func() -> void:
			_main = move.id
			_refresh_select_details())
		row.add_child(b)
	_details.add_child(row)
	_details.add_child(UiKit.move_card(GameData.get_move(_main)))

	if s.gadget_move:
		_details.add_child(_section("GADGET  (%d uses per match)" % int(GameData.rule("gadget/uses", 3))))
		_details.add_child(UiKit.move_card(s.gadget_move))

	_details.add_child(_section("SUPER  (charges as you deal damage; each stage has its own)"))
	for stage in GameData.evolution_line(s.id):
		var card := UiKit.move_card(stage.super_move)
		card.tooltip_text = stage.display_name
		var super_row := HBoxContainer.new()
		super_row.add_child(UiKit.sprite(stage.sprite, 48))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		super_row.add_child(card)
		_details.add_child(super_row)

	if s.evolutions.size() > 1:
		_details.add_child(_section("EVOLVES INTO"))
		var branches := HFlowContainer.new()
		var branch_group := ButtonGroup.new()
		var random_button := _toggle("RANDOM", branch_group, _evolution == "")
		random_button.pressed.connect(func() -> void: _evolution = "")
		branches.add_child(random_button)
		for branch_id in s.evolutions:
			var branch: SpeciesData = GameData.species[branch_id]
			var b := _toggle(branch.display_name, branch_group, _evolution == branch_id)
			b.icon = branch.sprite
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 36)
			b.pressed.connect(func() -> void: _evolution = branch_id)
			branches.add_child(b)
		_details.add_child(branches)

	var team_size := int(GameData.rule("team_size", 3))
	if _mode == "showdown":
		var rivals := int(GameData.rule("modes/showdown/players", 6)) - 1
		_details.add_child(_section("OPPONENTS  (pick up to %d, the rest are random)" % rivals))
		_details.add_child(_team_picker(_enemies, rivals))
	else:
		_details.add_child(_section("TEAMMATES  (pick up to %d, the rest are random)" % (team_size - 1)))
		_details.add_child(_team_picker(_allies, team_size - 1))
		_details.add_child(_section("OPPONENTS  (pick up to %d, the rest are random)" % team_size))
		_details.add_child(_team_picker(_enemies, team_size))

	_details.add_child(_section("BOT DIFFICULTY"))
	var difficulty_row := HBoxContainer.new()
	var difficulty_group := ButtonGroup.new()
	for level in ["easy", "normal", "hard"]:
		var b := _toggle(level.to_upper(), difficulty_group, level == _difficulty)
		b.pressed.connect(func() -> void: _difficulty = level)
		difficulty_row.add_child(b)
	_details.add_child(difficulty_row)

	_details.add_child(_section("ARENA"))
	var arenas := HFlowContainer.new()
	var arena_group := ButtonGroup.new()
	for arena_id in GameData.arenas_for_mode(_mode):
		var b := _toggle(str(GameData.arenas[arena_id].get("name", arena_id)), arena_group, arena_id == _arena)
		b.pressed.connect(func() -> void: _arena = arena_id)
		arenas.add_child(b)
	_details.add_child(arenas)

	await get_tree().process_frame
	if is_instance_valid(_details_scroll):
		_details_scroll.scroll_vertical = keep_scroll


## Multi-select row of Pokémon; tapping toggles, capped at `max_count`.
func _team_picker(chosen: Array[String], max_count: int) -> HFlowContainer:
	var row := HFlowContainer.new()
	for s in GameData.base_species():
		var b := Button.new()
		b.text = s.display_name
		b.toggle_mode = true
		b.button_pressed = s.id in chosen
		b.icon = s.sprite
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_constant_override("icon_max_width", 36)
		b.add_theme_font_size_override("font_size", 20)
		b.toggled.connect(func(on: bool) -> void:
			if on and s.id not in chosen:
				if chosen.size() >= max_count:
					b.set_pressed_no_signal(false)
					return
				chosen.append(s.id)
			elif not on:
				chosen.erase(s.id))
		row.add_child(b)
	return row


func _valid_move(slot: String, move_id: String) -> String:
	for move in _species.moves_for(slot, _level):
		if move.id == move_id:
			return move_id
	return _species.default_move(slot, _level).id


func _start_match() -> void:
	GameData.match_settings = {
		"mode": _mode,
		"arena": _arena,
		"species": _species.id,
		"level": _level,
		"main": _main,
		"evolution": _evolution,
		"shiny": _shiny,
		"allies": _allies.duplicate(),
		"enemies": _enemies.duplicate(),
		"bot_level": _level,
		"difficulty": _difficulty,
	}
	get_tree().change_scene_to_file(MAIN_SCENE)


func _restore_last_choices() -> void:
	var last: Dictionary = GameData.match_settings
	if last.is_empty():
		return
	_mode = str(last.get("mode", _mode))
	_species = GameData.species.get(str(last.get("species", "")))
	_level = int(last.get("level", 1))
	_main = str(last.get("main", ""))
	_evolution = str(last.get("evolution", ""))
	_shiny = bool(last.get("shiny", false))
	for id in last.get("allies", []):
		_allies.append(str(id))
	for id in last.get("enemies", []):
		_enemies.append(str(id))
	_arena = str(last.get("arena", ""))
	_difficulty = str(last.get("difficulty", "normal"))


# --- Pokédex details -------------------------------------------------------

func _show_dex_entry(s: SpeciesData) -> void:
	_clear(_details)
	_details.add_child(_species_header(s, 144, true))
	for stat in ["hp", "attack", "defense", "speed"]:
		_details.add_child(UiKit.stat_bar(stat, _stat(s, stat)))
	_details.add_child(_style_box(s))

	_details.add_child(_section("EVOLUTION  (every 3 KOs in a match; fainting drops one stage)"))
	var line := HFlowContainer.new()
	var chain: Array[SpeciesData] = GameData.evolution_line(s.id)
	for i in chain.size():
		if i > 0:
			line.add_child(UiKit.label("›", 36))
		var stage := chain[i]
		var b := Button.new()
		b.text = stage.display_name
		b.icon = stage.sprite
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_constant_override("icon_max_width", 40)
		b.disabled = stage == s
		b.pressed.connect(show_pokedex.bind(stage.id))
		line.add_child(b)
	_details.add_child(line)

	var weak := HFlowContainer.new()
	var resist := HFlowContainer.new()
	for t in GameData.all_types():
		var e: float = GameData.effectiveness(t, s.types)
		if absf(e - 1.0) < 0.01:
			continue
		var chip := UiKit.type_chip(t, 16, "%s ×%s" % [t.to_upper(), _fmt(e)])
		(weak if e > 1.0 else resist).add_child(chip)
	_details.add_child(_section("WEAK TO"))
	_details.add_child(weak if weak.get_child_count() > 0 else UiKit.label("Nothing", 18))
	_details.add_child(_section("RESISTS"))
	_details.add_child(resist if resist.get_child_count() > 0 else UiKit.label("Nothing", 18))

	_details.add_child(_section("SUPER  (this stage's own)"))
	_details.add_child(UiKit.move_card(s.super_move))
	if s.gadget_move:
		_details.add_child(_section("GADGET"))
		_details.add_child(UiKit.move_card(s.gadget_move))
	_details.add_child(_section("MAIN ATTACKS  (one more unlocks at each level)"))
	for entry in s.learnset:
		_details.add_child(UiKit.move_card(entry["move"], int(entry["level"])))
	_details_scroll.scroll_vertical = 0


# --- Helpers ---------------------------------------------------------------

## Every label added to the menu is checked so long text can't make a row wider than
## the screen: long labels in a row wrap onto more lines instead.
func _on_node_added(node: Node) -> void:
	if node is Label and is_ancestor_of(node):
		UiKit.fit_label.call_deferred(node)


func _set_screen(content: Control) -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if _screen:
		_screen.queue_free()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Extra side margin keeps buttons clear of the iPhone notch in landscape.
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(content)
	_screen = margin
	add_child(margin)


## `both_colours` shows the shiny next to the normal one (Pokédex).
func _species_header(s: SpeciesData, sprite_size: float, both_colours := false) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var shown := s.shiny_sprite if _shiny and s.shiny_sprite and not both_colours else s.sprite
	header.add_child(UiKit.sprite(shown, sprite_size))
	if both_colours and s.shiny_sprite:
		header.add_child(UiKit.sprite(s.shiny_sprite, sprite_size * 0.7))
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UiKit.label(s.display_name, 40))
	info.add_child(UiKit.type_row(s.types))
	var names: Array[String] = []
	for stage in GameData.evolution_line(s.id):
		names.append(stage.display_name)
	if s.legendary:
		info.add_child(UiKit.label("LEGENDARY  ·  raid boss in Battle, shrine guardian in King of the Hill", 18, Color(1, 0.85, 0.35)))
	else:
		info.add_child(UiKit.label("Stage %d  ·  %s" % [s.stage, " › ".join(names)], 18, Color(0.75, 0.8, 0.9)))
	header.add_child(info)
	return header


func _species_button(s: SpeciesData, group: ButtonGroup, selected: bool) -> Button:
	var b := _toggle(s.display_name, group, selected)
	b.icon = s.sprite
	b.expand_icon = true
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(112, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	b.clip_text = true
	var number := UiKit.label("#%03d" % s.dex, 12, Color(1, 1, 1, 0.75))
	number.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	number.position = Vector2(-40, 4)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(number)
	# Type chips in the top corner (both types for dual-type Pokémon).
	var chips := VBoxContainer.new()
	chips.add_theme_constant_override("separation", 2)
	chips.position = Vector2(4, 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in s.types:
		var chip := UiKit.type_chip(t, 10, t.substr(0, 3).to_upper())
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(chip)
	b.add_child(chips)
	return b


## "Plays like Poco / Byron: waves that hurt enemies and heal teammates."
func _style_box(s: SpeciesData) -> Control:
	var info := GameData.style_info(s.style)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0.22, 0.2, 0.36), 10, 8))
	var v := VBoxContainer.new()
	var like := str(info.get("like", ""))
	v.add_child(UiKit.label("PLAY STYLE: %s%s" % [str(info.get("label", s.style)).to_upper(),
			"  ·  plays like %s" % like if like != "" else ""], 20, Color(0.75, 0.9, 1)))
	var desc := UiKit.label(str(info.get("desc", "")), 16, Color(0.85, 0.88, 0.95))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	card.add_child(v)
	return card


func _toggle(text: String, group: ButtonGroup, pressed: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.add_theme_font_size_override("font_size", 20)
	return b


func _section(text: String) -> Label:
	var l := UiKit.label(text, 18, Color(1, 0.85, 0.4))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _stat(s: SpeciesData, stat: String) -> float:
	match stat:
		"hp":
			return s.hp
		"attack":
			return s.attack
		"defense":
			return s.defense
	return s.speed


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func _fmt(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
