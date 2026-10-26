extends Control
## Title screen → pick a mode → pick your Pokémon, level, moves, opponent and
## arena → start. Also hosts the Pokédex.

const MAIN_SCENE := "res://scenes/main.tscn"
const MODES := {
	"duel": { "title": "BATTLE 3v3", "blurb": "First team to 10 KOs wins." },
	"king_of_the_hill": { "title": "KING OF THE HILL 3v3", "blurb": "Hold the zone with only your team in it." },
}

var _screen: Control
var _mode := "duel"
var _species: SpeciesData
var _level := 1
var _melee := ""
var _ranged := ""
## Chosen bot teammates / opponents; empty slots are filled randomly.
var _allies: Array[String] = []
var _enemies: Array[String] = []
var _arena := ""
var _difficulty := "normal"
var _details: VBoxContainer
var _details_scroll: ScrollContainer


func _ready() -> void:
	theme = UiKit.make_theme()
	var bg := ColorRect.new()
	bg.color = UiKit.BG
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
	for s in GameData.base_species():
		starters.add_child(UiKit.sprite(s.sprite, 96))
	v.add_child(starters)

	for entry in [["BATTLE", show_select.bind("duel")],
			["KING OF THE HILL", show_select.bind("king_of_the_hill")],
			["POKéDEX", show_pokedex.bind("")]]:
		var b := UiKit.button(entry[0], entry[1], 30)
		b.custom_minimum_size = Vector2(440, 72)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
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
	top.add_child(title)
	var start := UiKit.button("START ›", _start_match, 30)
	start.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.7, 0.35)))
	start.add_theme_stylebox_override("hover", UiKit.box(Color(0.3, 0.78, 0.4)))
	top.add_child(start)
	root.add_child(top)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	for s in GameData.base_species():
		var card := _species_button(s, group, s == _species)
		card.pressed.connect(func() -> void:
			_species = s
			_melee = ""
			_ranged = ""
			_refresh_select_details())
		grid.add_child(card)
	var left := UiKit.panel(UiKit.scroll(grid))
	left.custom_minimum_size.x = 380
	body.add_child(left)

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 10)
	_details_scroll = UiKit.scroll(_details)
	var right := UiKit.panel(_details_scroll)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	root.add_child(body)
	_set_screen(root)
	_refresh_select_details()


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
		b.text = s.display_name
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


# --- Select screen details -------------------------------------------------

func _refresh_select_details() -> void:
	var keep_scroll := _details_scroll.scroll_vertical
	_clear(_details)
	var s := _species
	_details.add_child(_species_header(s, 112))
	for stat in ["hp", "attack", "defense", "speed"]:
		_details.add_child(UiKit.stat_bar(stat, _stat(s, stat)))

	_details.add_child(_section("LEVEL"))
	var levels := HBoxContainer.new()
	var level_group := ButtonGroup.new()
	for level in range(1, int(GameData.rule("level/max", 3)) + 1):
		var b := _toggle("Lv %d" % level, level_group, level == _level)
		b.pressed.connect(func() -> void:
			_level = level
			_refresh_select_details())
		levels.add_child(b)
	levels.add_child(UiKit.label("  Higher levels unlock moves (+5% stats each)", 16, Color(0.75, 0.8, 0.9)))
	_details.add_child(levels)

	_melee = _valid_move("melee", _melee)
	_ranged = _valid_move("ranged", _ranged)
	for slot in ["melee", "ranged"]:
		_details.add_child(_section("MELEE MOVE  (MELEE button)" if slot == "melee" else "RANGED MOVE  (right stick)"))
		var row := HFlowContainer.new()
		var move_group := ButtonGroup.new()
		var chosen := _melee if slot == "melee" else _ranged
		for move in s.moves_for(slot, 99):
			var unlock := s.unlock_level(move)
			var text := move.display_name if unlock <= _level else "%s (Lv%d)" % [move.display_name, unlock]
			var b := _toggle(text, move_group, move.id == chosen)
			b.disabled = unlock > _level
			b.pressed.connect(func() -> void:
				if slot == "melee":
					_melee = move.id
				else:
					_ranged = move.id
				_refresh_select_details())
			row.add_child(b)
		_details.add_child(row)
		_details.add_child(UiKit.move_card(GameData.get_move(chosen)))

	_details.add_child(_section("SUPER  (SUPER button — charges as you deal damage; changes when you evolve)"))
	for stage in GameData.evolution_line(s.id):
		var card := UiKit.move_card(stage.super_move)
		card.tooltip_text = stage.display_name
		var row := HBoxContainer.new()
		row.add_child(UiKit.sprite(stage.sprite, 48))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		_details.add_child(row)

	var team_size := int(GameData.rule("team_size", 3))
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
		"melee": _melee,
		"ranged": _ranged,
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
	_melee = str(last.get("melee", ""))
	_ranged = str(last.get("ranged", ""))
	for id in last.get("allies", []):
		_allies.append(str(id))
	for id in last.get("enemies", []):
		_enemies.append(str(id))
	_arena = str(last.get("arena", ""))
	_difficulty = str(last.get("difficulty", "normal"))


# --- Pokédex details -------------------------------------------------------

func _show_dex_entry(s: SpeciesData) -> void:
	_clear(_details)
	_details.add_child(_species_header(s, 144))
	for stat in ["hp", "attack", "defense", "speed"]:
		_details.add_child(UiKit.stat_bar(stat, _stat(s, stat)))

	_details.add_child(_section("EVOLUTION  (every 3 KOs in a match; fainting drops one stage)"))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
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
	_details.add_child(_section("MOVES"))
	for entry in s.learnset:
		_details.add_child(UiKit.move_card(entry["move"], int(entry["level"])))
	_details_scroll.scroll_vertical = 0


# --- Helpers ---------------------------------------------------------------

func _set_screen(content: Control) -> void:
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


func _species_header(s: SpeciesData, sprite_size: float) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.add_child(UiKit.sprite(s.sprite, sprite_size))
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UiKit.label(s.display_name, 40))
	info.add_child(UiKit.type_row(s.types))
	var names: Array[String] = []
	for stage in GameData.evolution_line(s.id):
		names.append(stage.display_name)
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
	b.custom_minimum_size = Vector2(160, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


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
