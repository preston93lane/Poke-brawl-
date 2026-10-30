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
	"gym": { "button": "GYMS", "title": "GYM", "blurb": "Beat two trainers, then the Gym Leader, three matches in a row." },
	"boss_raid": { "button": "BOSS RAID", "title": "BOSS RAID", "blurb": "Team up against a giant legendary. Dodge the red circles!" },
}

var _screen: Control
var _mode := "duel"
var _species: SpeciesData
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
## Boss Raid: the boss picked on the boss screen.
var _boss := ""
## Pokédex tab: "mine" (default) or "all"; silhouettes cache for locked Pokémon.
var _dex_tab := "mine"
## What the build editor redraws after a change (select screen or Pokédex entry).
var _editor_refresh: Callable
var _silhouettes := {}
## Gym gauntlet choices (gym screen).
var _gym := ""
var _gym_difficulty := "normal"
var _gym_type := ""
var _difficulty := "normal"
var _details: VBoxContainer
var _details_scroll: ScrollContainer
var _start_button: Button
## Equipped HM for the selected line.
var _hm := ""


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
	if Profile.needs_starter():
		_set_screen(TrainerScreens.starter(self))
	else:
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
			starters.add_child(UiKit.sprite(GameData.species[id].sprite, 72))
	v.add_child(starters)

	# Trainer card: level, money, Pokémon unlocked; opens the challenges.
	var card := UiKit.button("TRAINER LV %d   ·   %d ₽   ·   %d / %d POKéMON" % [Profile.total_level(), Profile.money(),
			_unlocked_count(), GameData.base_species().size()], show_challenges, 22)
	card.add_theme_stylebox_override("normal", UiKit.box(Color(0.2, 0.25, 0.45)))
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(760, 56)
	v.add_child(card)
	var road := TrainerRoad.new()
	road.window = 7
	road.custom_minimum_size.x = 760
	road.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(road)

	var main_row := HBoxContainer.new()
	main_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_row.add_theme_constant_override("separation", 16)
	var challenges := UiKit.button("CHALLENGES", show_challenges, 36)
	challenges.custom_minimum_size = Vector2(380, 104)
	challenges.add_theme_stylebox_override("normal", UiKit.box(Color(0.45, 0.3, 0.75)))
	challenges.add_theme_stylebox_override("hover", UiKit.box(Color(0.52, 0.36, 0.82)))
	var left := 0
	for t: Dictionary in Profile.dailies():
		if not bool(t["done"]):
			left += 1
	if left > 0:
		var badge := UiKit.label("%d DAILIES LEFT" % left, 15, Color(1, 0.9, 0.4))
		badge.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		badge.offset_top = -26
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		challenges.add_child(badge)
	main_row.add_child(challenges)
	var battle := UiKit.button("BATTLE", show_battle_modes, 48)
	battle.custom_minimum_size = Vector2(560, 104)
	battle.add_theme_stylebox_override("normal", UiKit.box(Color(0.95, 0.6, 0.15)))
	battle.add_theme_stylebox_override("hover", UiKit.box(Color(1.0, 0.68, 0.2)))
	main_row.add_child(battle)
	v.add_child(main_row)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for entry in [["POKéDEX", show_pokedex.bind("", "mine"), Color(0.75, 0.3, 0.3)], ["BAG", show_bag.bind([] as Array[Dictionary]), Color(0.25, 0.55, 0.45)],
			["POKé MART", show_store.bind(""), Color(0.3, 0.45, 0.8)], ["ACCOUNT", show_account.bind(""), Color(0.35, 0.38, 0.5)],
			["SETTINGS", show_settings, Color(0.35, 0.38, 0.5)]]:
		var b := UiKit.button(entry[0], entry[1], 22)
		b.custom_minimum_size = Vector2(196, 64)
		b.add_theme_stylebox_override("normal", UiKit.box(entry[2]))
		row.add_child(b)
	v.add_child(row)
	_set_screen(v)


## BATTLE: every game mode, plus the map maker.
func show_battle_modes() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_home))
	top.add_child(UiKit.label("   CHOOSE A MODE", 34, Color(1, 0.85, 0.25)))
	v.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for mode_id: String in MODES:
		if mode_id == "gym":
			grid.add_child(_mode_card("GYMS", MODES[mode_id]["blurb"], show_gyms, Color(0.85, 0.5, 0.15)))
			continue
		if mode_id == "boss_raid":
			grid.add_child(_mode_card("BOSS RAID", MODES[mode_id]["blurb"], show_bosses, Color(0.75, 0.25, 0.3)))
			continue
		grid.add_child(_mode_card(MODES[mode_id]["button"], MODES[mode_id]["blurb"], show_select.bind(mode_id), Color(0.22, 0.48, 0.9)))
	grid.add_child(_mode_card("MAP MAKER", "Design your own arenas and test them.", show_map_editor, Color(0.35, 0.38, 0.5)))
	v.add_child(grid)
	_set_screen(v)


## The eight Kanto gyms, opening one after another.
func show_gyms() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_battle_modes))
	top.add_child(UiKit.label("   GYMS  ·  win 3 matches in a row to beat the leader", 30, Color(1, 0.85, 0.25)))
	v.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	var order := Profile.gym_ids()
	for i in order.size():
		var id: String = order[i]
		var g := Profile.gym(id)
		var open := Profile.gym_unlocked(id)
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		var ace: SpeciesData = GameData.species[str(g["rounds"][-1]["team"][0])]
		var pic := UiKit.sprite(ace.sprite, 72)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		if not open:
			pic.modulate = Color(0, 0, 0, 0.8)
		card.add_child(pic)
		var b := UiKit.button(str(g["leader"]).to_upper() if open else "LOCKED", show_gym.bind(id), 22)
		b.disabled = not open
		b.custom_minimum_size = Vector2(250, 56)
		b.add_theme_stylebox_override("normal", UiKit.box(GameData.type_color(str(g["type"])).darkened(0.25)))
		card.add_child(b)
		var status := "%s  ·  %s" % [str(GameData.arenas.get(id, {}).get("name", id)), str(g["type"]).capitalize()]
		if Profile.gym_clears(id, "hard") > 0:
			status += "  ·  ★ GOLD"
		elif Profile.gym_clears(id, "normal") > 0:
			status += "  ·  ★"
		elif not open:
			status = Profile.gym_lock_reason(id)
		var l := UiKit.label(status, 15, Color(1, 1, 1, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
		grid.add_child(card)
	v.add_child(grid)
	# The Elite Four: five rounds back to back after the last gym.
	var e4_open := Profile.gym_unlocked("elite_four")
	var e4 := UiKit.button("ELITE FOUR  ·  5 rounds back to back" if e4_open else "ELITE FOUR  ·  LOCKED", show_gym.bind("elite_four"), 26)
	e4.disabled = not e4_open
	e4.custom_minimum_size = Vector2(620, 64)
	e4.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e4.add_theme_stylebox_override("normal", UiKit.box(Color(0.55, 0.25, 0.7)))
	v.add_child(e4)
	var e4_info := "Beaten: Normal ×%d · Hard ×%d" % [Profile.gym_clears("elite_four", "normal"), Profile.gym_clears("elite_four", "hard")] if e4_open else Profile.gym_lock_reason("elite_four")
	var e4_label := UiKit.label(e4_info, 16, Color(1, 1, 1, 0.8))
	e4_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(e4_label)
	_set_screen(v)


## One gym: its three rounds, difficulty, and an optional one-type team for bigger rewards.
func show_gym(id: String) -> void:
	_gym = id
	var g := Profile.gym(id)
	var gym_type := str(g["type"])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_gyms))
	var place := "ELITE FOUR" if id == "elite_four" else str(GameData.arenas.get(id, {}).get("name", id)).to_upper()
	var title := UiKit.label("   %s  ·  %s" % [place, str(g["leader"]).to_upper()], 28, Color(1, 0.85, 0.25))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var next := UiKit.button("CHOOSE POKéMON ›", func() -> void:
		_type_filter = _gym_type
		show_select("gym"), 26)
	next.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.7, 0.35)))
	top.add_child(next)
	v.add_child(top)
	var rounds_row := HBoxContainer.new()
	rounds_row.add_theme_constant_override("separation", 26)
	var rounds: Array = g["rounds"]
	for i in rounds.size():
		var box := VBoxContainer.new()
		var ace := GymMode.has_ace(rounds, i)
		var heading := "%d · %s" % [i + 1, str(rounds[i]["trainer"])] if id == "elite_four" else (
				("ROUND %d  ·  %s" % [i + 1, str(rounds[i]["trainer"])]) if i < rounds.size() - 1 else "ROUND %d  ·  LEADER %s" % [i + 1, str(g["leader"]).to_upper()])
		box.add_child(UiKit.label(heading, 17, Color(1, 0.9, 0.6) if ace else Color.WHITE))
		var team := HBoxContainer.new()
		var enemies: Array = GymMode.settings_for({ "gym": id, "round": i, "team_type": "", "difficulty": "normal", "picks": {} })["enemies"]
		for j in enemies.size():
			var sp: SpeciesData = GameData.species[str(enemies[j])]
			team.add_child(UiKit.sprite(sp.sprite, 60 if ace and j == 0 else 44))
		box.add_child(team)
		rounds_row.add_child(box)
	v.add_child(rounds_row)
	var how := UiKit.label("First to %d KOs wins a round; a KO on the leader's big ace counts %d. Lose a round and it's back to round 1. Gadget uses carry over." % [int(GameData.rule("modes/gym/kills_to_win", 15)), int(GameData.rule("modes/gym/leader_kos", 2))], 16, Color(0.8, 0.85, 1))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)

	v.add_child(_section("DIFFICULTY"))
	var diff_row := HBoxContainer.new()
	var diff_group := ButtonGroup.new()
	for d in ["normal", "hard"]:
		var b := _toggle(d.to_upper(), diff_group, d == _gym_difficulty)
		b.pressed.connect(func() -> void: _gym_difficulty = d)
		diff_row.add_child(b)
	var done := UiKit.label("   Beaten: Normal ×%d · Hard ×%d" % [Profile.gym_clears(id, "normal"), Profile.gym_clears(id, "hard")], 16, Color(0.8, 0.85, 1))
	diff_row.add_child(done)
	v.add_child(diff_row)

	if gym_type == "":
		_gym_type = ""  # The Elite Four mixes types: no team-type bonus.
	v.add_child(_section("TEAM TYPE  (your whole team is one type: weaker types pay more)") if gym_type != "" else Control.new())
	var info := UiKit.label("", 17, Color(1, 0.9, 0.5))
	var describe := func() -> void:
		var m := Profile.gym_matchup(gym_type, _gym_type)
		var words := { "": "Any team: normal rewards.", "strong": "Strong against %s: normal rewards.", "neutral": "Neutral vs %s: rewards ×1.5.",
				"resisted": "Resisted by %s: rewards ×2 (+ a Great Ball the first time).", "weak": "Weak to %s: rewards ×3 (+ an Ultra Ball the first time)!" }
		info.text = str(words[m]) % gym_type.capitalize() if m != "" else str(words[m])
	var types := HFlowContainer.new()
	var type_group := ButtonGroup.new()
	var any := _toggle("ANY", type_group, _gym_type == "")
	any.pressed.connect(func() -> void:
		_gym_type = ""
		describe.call())
	types.add_child(any)
	for t in GameData.all_types():
		if not _type_has_pokemon(t):
			continue
		var b := _toggle(t.to_upper(), type_group, t == _gym_type)
		b.add_theme_color_override("font_color", GameData.type_color(t).lightened(0.35))
		b.pressed.connect(func() -> void:
			_gym_type = t
			describe.call())
		types.add_child(b)
	v.add_child(types)
	describe.call()
	v.add_child(info)
	types.visible = gym_type != ""
	info.visible = gym_type != ""
	for entry: Dictionary in GameData.unlocks.get("order", []):
		var c: Dictionary = entry.get("challenge", {})
		if str(c.get("type", "")) == "gym_clear" and str(c.get("gym", "")) == id:
			var have := Profile.is_unlocked(str(entry["family"]))
			v.add_child(UiKit.label("%s Challenge: %s → unlocks %s" % ["DONE ·" if have else "★", str(c["text"]), GameData.species[str(entry["family"])].display_name], 17, Color(0.6, 1, 0.6) if have else Color(1, 0.85, 0.4)))
	_set_screen(UiKit.scroll(v))


## Boss Raid: pick a legendary. They open one by one (see Profile.boss_unlocked).
func show_bosses() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_battle_modes))
	top.add_child(UiKit.label("   BOSS RAID  ·  3 of you vs. a giant legendary", 30, Color(1, 0.85, 0.25)))
	v.add_child(top)
	var tip := UiKit.label("Each win makes that boss harder: Easy → Medium → Hard → Expert → Master (better rewards each step). At 66% and 33% health it calls in minions (KO them to evolve) and strikes faster.", 18, Color(0.8, 0.85, 1))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var order: Array = (GameData.rule("modes/boss_raid/bosses", {}) as Dictionary).keys()
	for i in order.size():
		var boss_id: String = order[i]
		var s: SpeciesData = GameData.species[boss_id]
		var open := Profile.boss_unlocked(boss_id)
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		var pic := UiKit.sprite(s.sprite, 120)
		if not open:
			pic.modulate = Color(0, 0, 0, 0.8)
		card.add_child(pic)
		var wins := Profile.boss_wins(boss_id)
		var next_tier := str(Profile.boss_tier(boss_id).get("name", "")).to_upper()
		var info := ("Beaten ×%d · Next: %s" % [wins, next_tier] if wins > 0 else "Next: %s" % next_tier) if open else (
				("Trainer LV %d" % int(GameData.rule("modes/boss_raid/first_level", 10)) if i == 0 else "Beat %s first" % GameData.species[order[i - 1]].display_name))
		var b := UiKit.button(s.display_name.to_upper() if open else "LOCKED", func() -> void:
			_boss = boss_id
			show_select("boss_raid"), 24)
		b.disabled = not open
		b.custom_minimum_size = Vector2(220, 64)
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.75, 0.25, 0.3)))
		card.add_child(b)
		var l := UiKit.label(info, 16, Color(1, 1, 1, 0.8))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
		row.add_child(card)
	v.add_child(row)
	_set_screen(v)


func _mode_card(title: String, blurb: String, on_pressed: Callable, color: Color) -> Button:
	var b := UiKit.button(title, on_pressed, 28)
	b.custom_minimum_size = Vector2(340, 150)
	b.add_theme_stylebox_override("normal", UiKit.box(color))
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var text := UiKit.label(blurb, 16, Color(1, 1, 1, 0.85))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	text.offset_top = -52
	text.offset_bottom = -10
	text.offset_left = 12
	text.offset_right = -12
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(text)
	return b


func show_challenges() -> void:
	_set_screen(TrainerScreens.challenges(self))


func show_bag(prizes: Array[Dictionary] = []) -> void:
	_set_screen(TrainerScreens.bag(self, prizes))


## Plays the ball opening over the bag, then shows the bag with what came out.
func play_ball_opening(ball: String, prizes: Array[Dictionary]) -> void:
	var anim := BallOpening.new()
	anim.setup(ball, prizes)
	anim.finished.connect(show_bag.bind(prizes))  # The bag then plays any unlock reveals.
	add_child(anim)


func show_account(message := "") -> void:
	_set_screen(TrainerScreens.account(self, message))


func show_store(message := "") -> void:
	_set_screen(TrainerScreens.store(self, message))


func _unlocked_count() -> int:
	var n := 0
	for s in GameData.base_species():
		if Profile.is_unlocked(s.id):
			n += 1
	return n


func show_select(mode: String) -> void:
	if mode == "boss_raid" and not GameData.species.has(_boss):
		show_bosses()
		return
	if mode == "gym" and Profile.gym(_gym).is_empty():
		show_gyms()
		return
	_mode = mode
	if _species == null or not Profile.is_unlocked(_species.id):
		_species = GameData.base_species()[0]
		for s in GameData.base_species():
			if Profile.is_unlocked(s.id):
				_species = s
				break
	var arenas: Array[String] = GameData.arenas_for_mode(mode)
	if _arena not in arenas:
		_arena = "random"

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	var back: Callable = show_battle_modes
	if mode == "boss_raid":
		back = show_bosses
	elif mode == "gym":
		back = show_gym.bind(_gym)
	top.add_child(UiKit.button("‹ BACK", back))
	var title := UiKit.label("%s  —  %s" % [MODES[mode]["title"], MODES[mode]["blurb"]], 26)
	if mode == "boss_raid":
		title.text = "BOSS RAID  —  vs. %s  (%s)" % [GameData.species[_boss].display_name.to_upper(), str(Profile.boss_tier(_boss).get("name", "")).to_upper()]
	elif mode == "gym":
		title.text = "%s  —  %s%s" % [str(GameData.arenas.get(_gym, {}).get("name", _gym)).to_upper(), _gym_difficulty.to_upper(),
				"  ·  pick a %s type" % _gym_type.capitalize() if _gym_type != "" else ""]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long blurbs shorten with "…" instead of pushing the START button off screen.
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.custom_minimum_size.x = 80
	top.add_child(title)
	var start := UiKit.button("START ›", _start_match, 30)
	_start_button = start
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
## Settings → About & Legal: credits and the fan-project notice (also in README.md).
const CREDITS := [
	["Made with", "Godot Engine 4 (MIT license)."],
	["Battle sprites", "Animated Pokémon Mystery Dungeon sprites from PMD SpriteCollab (sprites.pmdcollab.org), CC BY-NC 4.0. Original sprites © Spike Chunsoft; artists listed below."],
	["Menu pictures", "Pokémon Black/White sprites from the PokeAPI sprites collection (© Nintendo / Creatures Inc. / GAME FREAK inc.)."],
	["Fonts", "Lilita One by Juan Montoreano, SIL Open Font License 1.1."],
	["Everything else", "Maps, 3D models, effects, item icons and sounds are made for this game (procedurally generated)."]
]
const LEGAL := "Pokémon and all related names, characters, sprites, music and other assets are © Nintendo, Creatures Inc. and GAME FREAK inc. Pokémon Mystery Dungeon © Spike Chunsoft. Poké Brawl is a free, non-commercial fan project. It is not affiliated with or endorsed by Nintendo, Creatures Inc., GAME FREAK inc., The Pokémon Company or Spike Chunsoft. It is not for sale, no money is made from it, and it contains no ads or purchases with real money. If you are a rights holder and want something removed, open an issue on the GitHub repository and it will be taken down."


func show_about() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_settings))
	top.add_child(UiKit.label("   ABOUT & LEGAL", 32, Color(1, 0.85, 0.25)))
	v.add_child(top)
	v.add_child(_section("CREDITS"))
	for c: Array in CREDITS:
		var l := UiKit.label("%s: %s" % [c[0], c[1]], 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var artists := {}
	if FileAccess.file_exists("res://assets/pmd/credits.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pmd/credits.json"))
		if parsed is Dictionary:
			for names in (parsed as Dictionary).values():
				for n in names:
					artists[str(n)] = true
	if not artists.is_empty():
		var list: Array = artists.keys()
		list.sort_custom(func(a: String, b: String) -> bool: return a.to_lower() < b.to_lower())
		var who := UiKit.label("Sprite artists: " + ", ".join(PackedStringArray(list)), 16, Color(0.8, 0.85, 1))
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(who)
	v.add_child(_section("LEGAL"))
	var legal := UiKit.label(LEGAL, 18, Color(0.85, 0.9, 1))
	legal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(legal)
	_set_screen(UiKit.scroll(v))


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
	top.add_child(UiKit.button("ABOUT & LEGAL", func() -> void:
		editor.save()
		show_about()))
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
	var haze := Button.new()
	haze.toggle_mode = true
	haze.button_pressed = bool(GameData.setting("haze_blur", true))
	haze.text = "HAZE & BLUR: ON" if haze.button_pressed else "HAZE & BLUR: OFF"
	haze.add_theme_font_size_override("font_size", 20)
	haze.toggled.connect(func(on: bool) -> void:
		GameData.set_setting("haze_blur", on)
		haze.text = "HAZE & BLUR: ON" if on else "HAZE & BLUR: OFF")
	top.add_child(haze)
	if Profile.is_dev():
		top.add_child(UiKit.button("DEV TOOLS", show_dev))
	if not Profile.is_dev():
		var code := LineEdit.new()
		code.placeholder_text = "Dev code"
		code.secret = true
		code.custom_minimum_size.x = 160
		code.add_theme_font_size_override("font_size", 20)
		code.text_submitted.connect(func(text: String) -> void:
			if Profile.try_dev_code(text):
				show_dev()
			else:
				code.text = ""
				code.placeholder_text = "Wrong code")
		UiKit.web_typable(code, "Dev code", func(text: String) -> void: code.text_submitted.emit(text))
		top.add_child(code)
	root.add_child(top)
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(editor)
	_set_screen(root)
	update_size.call()


## Dev tools (dev mode only): set profile levels to test fast evolving, reset progress.
func show_dev() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_child(UiKit.button("‹ BACK", show_home))
	top.add_child(UiKit.label("  DEV TOOLS", 30, Color(1, 0.85, 0.25)))
	v.add_child(top)
	v.add_child(_section("SET EVERY POKéMON'S LEVEL"))
	var all_row := HFlowContainer.new()
	for level in [1, 16, 25, 32, 40, Profile.max_level()]:
		all_row.add_child(UiKit.button("ALL Lv %d" % level, func() -> void:
			Profile.set_all_levels(level)
			show_dev(), 20))
	v.add_child(all_row)
	var picked := _species if _species else GameData.base_species()[0]
	v.add_child(_section("SELECTED: %s  (pick another on any mode's select screen)" % picked.display_name.to_upper()))
	v.add_child(_trainer_level_box(picked))
	v.add_child(_section("PROGRESS"))
	var reset_row := HFlowContainer.new()
	reset_row.add_child(UiKit.button("FILL BAG (₽, balls, candy, vitamins, HMs)", func() -> void:
		Profile.dev_grant()
		show_dev(), 20))
	var reset := UiKit.button("RESET PROFILE", func() -> void:
		Profile.reset()
		show_dev(), 20)
	reset.add_theme_stylebox_override("normal", UiKit.box(Color(0.7, 0.25, 0.25)))
	reset_row.add_child(reset)
	reset_row.add_child(UiKit.button("TURN DEV MODE OFF", func() -> void:
		Profile.set_dev(false)
		show_home(), 20))
	v.add_child(reset_row)
	v.add_child(UiKit.label("In a match, dev mode adds RAID NOW and WIN buttons at the top left.", 18, Color(0.75, 0.8, 0.9)))
	_set_screen(UiKit.scroll(v))


## Profile level of the line and how many KOs each growth takes in a match.
func _trainer_level_box(s: SpeciesData) -> VBoxContainer:
	var box := VBoxContainer.new()
	var level := Profile.level_of(s.id)
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("TRAINER LEVEL %d" % level, 22, Color(1, 0.85, 0.25)))
	if Profile.is_dev():
		for step in [-10, -1, 1, 10]:
			head.add_child(UiKit.button("%+d" % step, func() -> void:
				Profile.set_level(s.id, Profile.level_of(s.id) + step)
				if is_instance_valid(_details) and _details.is_inside_tree():
					_refresh_select_details()
				else:
					show_dev(), 18))
	box.add_child(head)
	if level < Profile.max_level():
		var xp_row := HBoxContainer.new()
		var bar := ProgressBar.new()
		bar.max_value = Profile.xp_needed(level)
		bar.value = Profile.xp_of(s.id)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 18)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		xp_row.add_child(bar)
		xp_row.add_child(UiKit.label("  %d / %d XP to Lv %d  " % [Profile.xp_of(s.id), Profile.xp_needed(level), level + 1], 15, Color(0.8, 0.85, 0.95)))
		var candy := UiKit.button("RARE CANDY (%d)" % Profile.count("rare_candy"), func() -> void:
			Profile.use_rare_candy(s.id)
			if is_instance_valid(_details) and _details.is_inside_tree():
				_refresh_select_details(), 15)
		candy.disabled = Profile.count("rare_candy") <= 0 or not Profile.is_unlocked(s.id)
		xp_row.add_child(candy)
		box.add_child(xp_row)
	var fast := int(GameData.rule("trainer/fast_kills", 2))
	var slow := int(GameData.rule("evolution/kills_to_evolve", 3))
	var power_levels: Array = GameData.rule("trainer/power_up_levels", [20, 40])
	var steps: Array[String] = []
	for stage in GameData.evolution_line(s.id):
		if stage.evolutions.is_empty():
			continue
		var need := stage.evolve_level if stage.evolve_level > 0 else 25
		var next: SpeciesData = GameData.species[stage.evolves_to]
		steps.append("%s → %s: %d KOs%s" % [stage.display_name, next.display_name if stage.evolutions.size() == 1 else "evolution",
				fast if level >= need else slow, " (fast)" if level >= need else "  (%d at Lv %d)" % [fast, need]])
	var final_stage := GameData.evolution_line(s.id).back() as SpeciesData
	if final_stage and final_stage.evolutions.is_empty():
		for i in maxi(0, 3 - final_stage.stage):
			var need := int(power_levels[clampi(final_stage.stage - 1 + i, 0, power_levels.size() - 1)])
			steps.append("Power Up %d: %d KOs%s" % [i + 1, fast if level >= need else slow, " (fast)" if level >= need else "  (%d at Lv %d)" % [fast, need]])
	var text := UiKit.label("\n".join(PackedStringArray(steps)), 16, Color(0.8, 0.85, 0.95))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	return box


func show_map_editor() -> void:
	var editor = MAP_EDITOR.new()
	editor.menu = self
	_set_screen(editor)


## Two tabs: MY POKéMON (default: only lines you've unlocked, with your levels,
## shinies, TMs, HMs and vitamins) and FULL POKéDEX (every Pokémon; ones you
## haven't unlocked are silhouettes with their stats and move details hidden).
func show_pokedex(selected_id: String, tab := "") -> void:
	if tab != "":
		_dex_tab = tab
	var mine := _dex_tab == "mine"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UiKit.button("‹ BACK", show_home))
	var tabs := ButtonGroup.new()
	var mine_tab := _toggle("MY POKéMON", tabs, mine)
	mine_tab.pressed.connect(show_pokedex.bind(selected_id, "mine"))
	top.add_child(mine_tab)
	var all_tab := _toggle("FULL POKéDEX", tabs, not mine)
	all_tab.pressed.connect(show_pokedex.bind(selected_id, "all"))
	top.add_child(all_tab)
	var have := 0
	for base in GameData.base_species():
		if Profile.is_unlocked(base.id):
			have += 1
	var count := UiKit.label("   %d / %d lines  ·  %d shinies" % [have, GameData.base_species().size(), (Profile.data.get("shinies", []) as Array).size()], 20, Color(1, 0.85, 0.4))
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(count)
	root.add_child(top)

	var shown: Array[SpeciesData] = []
	for s in GameData.species_by_line():
		if not mine or Profile.is_unlocked(s.id):
			shown.append(s)
	var selected: SpeciesData = GameData.species.get(selected_id)
	if selected == null or selected not in shown:
		selected = shown[0] if not shown.is_empty() else null
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	var list := VBoxContainer.new()
	var group := ButtonGroup.new()
	for s in shown:
		var known := Profile.is_unlocked(s.id)
		var b := Button.new()
		b.text = "#%03d  %s%s" % [s.dex, s.display_name, "  ✦" if known and Profile.has_shiny(s.id) and s.shiny_sprite else ""]
		b.icon = s.sprite if known else _silhouette(s.sprite)
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s == selected
		b.add_theme_constant_override("icon_max_width", 48)
		if not known:
			b.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		b.pressed.connect(_show_dex_entry.bind(s))
		list.add_child(b)
	var left := UiKit.panel(UiKit.scroll(list))
	left.custom_minimum_size.x = 340
	body.add_child(left)

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 10)
	_details_scroll = UiKit.scroll(_details)
	var right := UiKit.panel(_details_scroll)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	root.add_child(body)
	_set_screen(root)
	if selected:
		_show_dex_entry(selected)


## A black silhouette of a sprite (cached), for Pokémon you haven't unlocked.
func _silhouette(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _silhouettes.has(tex):
		return _silhouettes[tex]
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var a := img.get_pixel(x, y).a
			img.set_pixel(x, y, Color(0.06, 0.07, 0.12, a))
	var out := ImageTexture.create_from_image(img)
	_silhouettes[tex] = out
	return out


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
	var known := Profile.is_unlocked(s.id)
	if known:
		_shiny = Profile.has_shiny(s.id) and str(Profile.loadout(s.id).get("shiny", "")) != ""
		_details.add_child(_species_header(s, 112))
		for stat in ["hp", "attack", "defense", "speed"]:
			_details.add_child(UiKit.stat_bar(stat, _stat(s, stat)))
	else:
		# Locked: a silhouette, how to get it, and no stats or moves until then.
		_details.add_child(_locked_header(s, 112))
		_details.add_child(UiKit.label("Stats and moves: ??? (unlock it to see them)", 17, Color(1, 1, 1, 0.5)))
	_details.add_child(_style_box(s))
	if known:
		_details.add_child(_trainer_level_box(s))
	if is_instance_valid(_start_button):
		_start_button.disabled = not Profile.is_unlocked(s.id) or (_mode == "gym" and _gym_type != "" and not _line_has_type(s, _gym_type))
	if not Profile.is_unlocked(s.id):
		return  # Locked: no build to edit (and its stats stay hidden).
	_editor_refresh = _refresh_select_details
	_build_editor(s)

	# Teammates and opponents are always random.
	_allies.clear()
	_enemies.clear()

	if _mode != "gym":  # Gyms use the difficulty picked on the gym screen.
		_details.add_child(_section("BOT DIFFICULTY"))
		var difficulty_row := HBoxContainer.new()
		var difficulty_group := ButtonGroup.new()
		for level in ["easy", "normal", "hard"]:
			var b := _toggle(level.to_upper(), difficulty_group, level == _difficulty)
			b.pressed.connect(func() -> void: _difficulty = level)
			difficulty_row.add_child(b)
		_details.add_child(difficulty_row)

	if _mode not in ["boss_raid", "gym"]:  # The boss / gym picks the arena.
		_details.add_child(_section("ARENA  (random by default; pick one to play a challenge's map)"))
		var arenas := HFlowContainer.new()
		var arena_group := ButtonGroup.new()
		var random_arena := _toggle("RANDOM", arena_group, _arena == "random")
		random_arena.pressed.connect(func() -> void: _arena = "random")
		arenas.add_child(random_arena)
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


## `move_id` if it's an unlocked main attack of `s`'s line, else its newest unlocked one.
func _valid_move(s: SpeciesData, move_id: String) -> String:
	var unlocked := Profile.unlocked_mains(s.id)
	if move_id in unlocked:
		return move_id
	return unlocked.back() if not unlocked.is_empty() else s.default_move("main", 1).id


const HM_INFO := {
	"cut": "slash in front and clear the tall grass there",
	"fly": "leap over walls and water",
	"surf": "a wave that pushes enemies back, and swim for a few seconds",
	"strength": "a heavy shove; pushes boulders",
	"flash": "reveal and blind enemies around you",
	"rock_smash": "break the wall or rock in front of you",
}


## The build editor shared by the battle select screen and My Pokémon in the
## Pokédex: shiny, main attack, super per stage, HM, vitamins and evolution
## branch. Every choice is saved per line (Profile.loadout) so it carries over.
func _build_editor(s: SpeciesData) -> void:
	var loadout := Profile.loadout(s.id)
	_shiny = Profile.has_shiny(s.id) and str(loadout.get("shiny", "")) != ""
	_evolution = str(loadout.get("evolution", "")) if str(loadout.get("evolution", "")) in s.evolutions else ""
	if s.shiny_sheet and not Profile.has_shiny(s.id):
		_shiny = false
		var how := UiKit.label("✦ Shiny locked: win it in the weekly shiny hunt, find it in Ultra/Master Balls, or buy it when it's in the Poké Mart", 15, Color(0.75, 0.8, 0.9))
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(how)
	elif s.shiny_sheet:
		var shiny_row := HBoxContainer.new()
		var shiny_button := Button.new()
		shiny_button.text = "SHINY: ON" if _shiny else "SHINY: OFF"
		shiny_button.toggle_mode = true
		shiny_button.button_pressed = _shiny
		shiny_button.add_theme_font_size_override("font_size", 20)
		shiny_button.pressed.connect(func() -> void:
			_shiny = not _shiny
			Profile.set_loadout(s.id, "shiny", "1" if _shiny else "")
			_editor_refresh.call())
		shiny_row.add_child(shiny_button)
		shiny_row.add_child(UiKit.label("  Play with shiny colours", 16, Color(0.75, 0.8, 0.9)))
		_details.add_child(shiny_row)

	_main = _valid_move(s, str(loadout.get("main", "")))
	_hm = str(loadout.get("hm", ""))

	_details.add_child(_section("MAIN ATTACK  (right stick: drag to aim, tap to auto-aim)"))
	var row := HFlowContainer.new()
	var move_group := ButtonGroup.new()
	var unlocked := Profile.unlocked_mains(s.id)
	for entry in s.learnset:
		var move: MoveData = entry["move"]
		if move.slot != "main":
			continue
		var text := move.display_name
		if move.id not in unlocked:
			var tm := str(entry["tm"])
			text = "%s (Lv %d%s)" % [move.display_name, int(entry["level"]), " or its TM" if tm != "" else ""]
		var b := _toggle(text, move_group, move.id == _main)
		b.disabled = move.id not in unlocked
		b.pressed.connect(func() -> void:
			_main = move.id
			Profile.set_loadout(s.id, "main", move.id)
			_editor_refresh.call())
		row.add_child(b)
	_details.add_child(row)
	_details.add_child(UiKit.move_card(GameData.get_move(_main)))

	if s.gadget_move:
		_details.add_child(_section("GADGET  (%d uses per match)" % int(GameData.rule("gadget/uses", 3))))
		_details.add_child(UiKit.move_card(s.gadget_move))

	_details.add_child(_section("SUPER  (pick per stage: its own, an earlier one, or a TM super)"))
	for stage in GameData.evolution_line(s.id):
		var super_row := HBoxContainer.new()
		super_row.add_child(UiKit.sprite(stage.sprite, 48))
		var choices := HFlowContainer.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var group := ButtonGroup.new()
		var picked := Profile.chosen_super(stage.id)
		for option in Profile.super_options(stage.id):
			var move: MoveData = GameData.get_move(option)
			var b := _toggle(move.display_name, group, option == picked or (picked == "" and option == stage.super_move.id))
			b.pressed.connect(func() -> void:
				Profile.set_loadout(stage.id, "super_" + stage.id, "" if option == stage.super_move.id else option)
				_editor_refresh.call())
			choices.add_child(b)
		# TM supers this stage could use but you don't own yet: shown locked.
		for tm_super in Profile.stage_tm_supers(stage.id):
			if Profile.owns_tm_super(tm_super) or not GameData.moves.has(tm_super):
				continue
			var locked := Button.new()
			locked.text = "TM %s" % GameData.get_move(tm_super).display_name
			locked.disabled = true
			locked.tooltip_text = "Buy this TM in the Poké Mart or find it in a Poké Ball to use it."
			locked.add_theme_font_size_override("font_size", 18)
			choices.add_child(locked)
		super_row.add_child(choices)
		_details.add_child(super_row)
		var card := UiKit.move_card(GameData.get_move(picked) if picked != "" else stage.super_move)
		_details.add_child(card)
	var tm_note := UiKit.label("Greyed-out TM supers: buy the TM in the Poké Mart or find it in a Poké Ball. Each type's TMs work for Pokémon of that type (per stage).", 15, Color(0.75, 0.8, 0.9))
	tm_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_child(tm_note)

	_details.add_child(_hm_picker(s))
	_details.add_child(_vitamin_box(s))

	if s.evolutions.size() > 1:
		_details.add_child(_section("EVOLVES INTO"))
		var branches := HFlowContainer.new()
		var branch_group := ButtonGroup.new()
		var random_button := _toggle("RANDOM", branch_group, _evolution == "")
		random_button.pressed.connect(func() -> void:
			_evolution = ""
			Profile.set_loadout(s.id, "evolution", ""))
		branches.add_child(random_button)
		for branch_id in s.evolutions:
			var branch: SpeciesData = GameData.species[branch_id]
			var b := _toggle(branch.display_name, branch_group, _evolution == branch_id)
			b.icon = branch.sprite
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 36)
			b.pressed.connect(func() -> void:
				_evolution = branch_id
				Profile.set_loadout(s.id, "evolution", branch_id))
			branches.add_child(b)
		_details.add_child(branches)



## HMs: one or two per line; teach with an HM item, then pick the one to bring.
func _hm_picker(s: SpeciesData) -> Control:
	var box := VBoxContainer.new()
	box.add_child(_section("HM  (one at a time, recharges in 10 s)"))
	var row := HFlowContainer.new()
	var group := ButtonGroup.new()
	var learned := Profile.learned_hms(s.id)
	var none := _toggle("NONE", group, _hm == "")
	none.pressed.connect(func() -> void:
		Profile.set_loadout(s.id, "hm", "")
		_editor_refresh.call())
	row.add_child(none)
	for hm in Profile.hm_options(s.id):
		var label := hm.replace("_", " ").to_upper()
		if hm in learned:
			var b := _toggle(label, group, _hm == hm)
			b.tooltip_text = HM_INFO.get(hm, "")
			b.pressed.connect(func() -> void:
				Profile.set_loadout(s.id, "hm", hm)
				_editor_refresh.call())
			row.add_child(b)
		else:
			var teach := UiKit.button("TEACH %s (%d in bag)" % [label, Profile.count("hm_" + hm)], func() -> void:
				Profile.teach_hm(s.id, hm)
				_editor_refresh.call(), 16)
			teach.disabled = Profile.count("hm_" + hm) <= 0 or not Profile.is_unlocked(s.id)
			row.add_child(teach)
	box.add_child(row)
	var info := PackedStringArray()
	for hm in Profile.hm_options(s.id):
		info.append("%s: %s" % [hm.replace("_", " ").capitalize(), HM_INFO.get(hm, "")])
	var info_label := UiKit.label(" · ".join(info), 15, Color(0.75, 0.8, 0.9))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_label)
	return box


const VITAMIN_NAMES := { "hp": "HP Up", "attack": "Protein", "defense": "Iron", "speed": "Carbos" }


## Vitamins: give them from the bag, switch up to 10 on.
func _vitamin_box(s: SpeciesData) -> Control:
	var box := VBoxContainer.new()
	var max_active := int(Profile.econ("vitamins/max_active", 10))
	box.add_child(_section("VITAMINS  %d / %d ON  (+3%% each, half after 5 in a stat)" % [Profile.active_vitamin_total(s.id), max_active]))
	var bonus := Profile.vitamin_bonus(s.id)
	var v := Profile.vitamins(s.id)
	for stat in Profile.STATS:
		var row := HBoxContainer.new()
		var item: String = { "hp": "hp_up", "attack": "protein", "defense": "iron", "speed": "carbos" }[stat]
		var label := UiKit.label("%s  %d on / %d given  (+%d%%)" % [VITAMIN_NAMES[stat], int(v["active"].get(stat, 0)), int(v["given"].get(stat, 0)),
				roundi(float(bonus[stat]) * 100.0)], 17)
		label.custom_minimum_size.x = 330
		row.add_child(label)
		row.add_child(UiKit.button("−", func() -> void:
			Profile.change_active_vitamin(s.id, stat, -1)
			_editor_refresh.call(), 16))
		row.add_child(UiKit.button("+", func() -> void:
			Profile.change_active_vitamin(s.id, stat, 1)
			_editor_refresh.call(), 16))
		var give := UiKit.button("GIVE (%d in bag)" % Profile.count(item), func() -> void:
			Profile.give_vitamin(s.id, item)
			_editor_refresh.call(), 16)
		give.disabled = Profile.count(item) <= 0 or not Profile.is_unlocked(s.id)
		row.add_child(give)
		box.add_child(row)
	return box


func _start_match() -> void:
	GameData.match_settings = {
		"mode": _mode,
		"arena": GameData.arenas_for_mode(_mode).pick_random() if _arena == "random" else _arena,
		"arena_choice": _arena,
		"species": _species.id,
		"main": _main,
		"hm": _hm,
		"evolution": _evolution,
		"shiny": _shiny,
		"allies": _allies.duplicate(),
		"enemies": _enemies.duplicate(),
		"difficulty": _difficulty,
	}
	if _mode == "gym":
		GameData.match_settings = GymMode.start_run(_gym, _gym_difficulty, _gym_type, GameData.match_settings)
	if _mode == "boss_raid":
		GameData.match_settings["boss"] = _boss
		GameData.match_settings["arena"] = str(GameData.rule("modes/boss_raid/bosses/%s/arena" % _boss, "route_1"))
	get_tree().change_scene_to_file(MAIN_SCENE)


func _restore_last_choices() -> void:
	var last: Dictionary = GameData.match_settings
	if last.is_empty():
		return
	_mode = str(last.get("mode", _mode))
	_species = GameData.species.get(str(last.get("species", "")))
	_main = str(last.get("main", ""))
	_evolution = str(last.get("evolution", ""))
	_shiny = bool(last.get("shiny", false))
	for id in last.get("allies", []):
		_allies.append(str(id))
	for id in last.get("enemies", []):
		_enemies.append(str(id))
	_arena = str(last.get("arena_choice", "random"))
	_difficulty = str(last.get("difficulty", "normal"))
	_boss = str(last.get("boss", ""))


# --- Pokédex details -------------------------------------------------------

func _show_dex_entry(s: SpeciesData, keep_scroll := false) -> void:
	var scroll := _details_scroll.scroll_vertical
	_clear(_details)
	if not Profile.is_unlocked(s.id):
		_show_locked_dex_entry(s)
		return
	_details.add_child(_species_header(s, 144, true))
	if not s.legendary:
		_details.add_child(_dex_progress(s))
	for stat in ["hp", "attack", "defense", "speed"]:
		_details.add_child(UiKit.stat_bar(stat, _stat(s, stat)))
	_details.add_child(_style_box(s))

	_details.add_child(_section("EVOLUTION  (every 3 KOs in a match; fainting drops one stage)"))
	_details.add_child(_dex_line(s, true))
	_dex_matchups(s)

	if not s.legendary:
		# Your build, edited here the same way as on the battle screen; it carries into battle.
		var base: SpeciesData = GameData.species[GameData.family_root(s.id)]
		var heading := UiKit.label("YOUR BUILD  (saved, and used when you pick %s for battle)" % base.display_name, 22, Color(0.6, 1, 0.6))
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(heading)
		_editor_refresh = func() -> void: _show_dex_entry(s, true)
		_build_editor(base)
		await get_tree().process_frame
		if keep_scroll and is_instance_valid(_details_scroll):
			_details_scroll.scroll_vertical = scroll
		return
	_details.add_child(_section("SUPER  (this stage's own)"))
	_details.add_child(UiKit.move_card(s.super_move))
	if s.gadget_move:
		_details.add_child(_section("GADGET"))
		_details.add_child(UiKit.move_card(s.gadget_move))
	_details.add_child(_section("MAIN ATTACKS"))
	var have := Profile.unlocked_mains(s.id)
	for entry in s.learnset:
		var move: MoveData = entry["move"]
		var tm := str(entry.get("tm", ""))
		var state := "UNLOCKED" if move.id in have else ("Lv %d%s" % [int(entry["level"]), (" or " + Profile.item_name(tm)) if tm != "" else ""])
		_details.add_child(UiKit.label(state, 15, Color(0.6, 1, 0.6) if move.id in have else Color(1, 0.85, 0.5)))
		_details.add_child(UiKit.move_card(move, int(entry["level"])))
	if not s.legendary:
		_dex_gear(s)
	_details_scroll.scroll_vertical = 0


## Level, XP and shiny for a line you own.
func _dex_progress(s: SpeciesData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var level := Profile.level_of(s.id)
	row.add_child(UiKit.label("LV %d" % level, 26, Color(1, 0.85, 0.3)))
	if level < Profile.max_level():
		var bar := ProgressBar.new()
		bar.max_value = maxi(1, Profile.xp_needed(level))
		bar.value = Profile.xp_of(s.id)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 16)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		row.add_child(UiKit.label("%d / %d XP" % [Profile.xp_of(s.id), Profile.xp_needed(level)], 16))
	if s.shiny_sprite:
		row.add_child(UiKit.label("✦ Shiny unlocked" if Profile.has_shiny(s.id) else "Shiny: not yet", 16, Color(1, 0.9, 0.5) if Profile.has_shiny(s.id) else Color(1, 1, 1, 0.5)))
	return row


## TMs, HMs and vitamins this line has.
func _dex_gear(s: SpeciesData) -> void:
	_details.add_child(_section("YOUR TMs, HMs & VITAMINS"))
	var tm_supers: Array[String] = []
	for id in Profile.tm_super_options(s.id):
		if Profile.owns_tm_super(id) and GameData.moves.has(id):
			tm_supers.append(GameData.get_move(id).display_name)
	_details.add_child(UiKit.label("TM supers: " + (", ".join(tm_supers) if not tm_supers.is_empty() else "none yet (Poké Mart or Poké Balls)"), 17))
	var hms: Array[String] = []
	for hm in Profile.learned_hms(s.id):
		hms.append(Profile.item_name("hm_" + hm))
	_details.add_child(UiKit.label("HMs learned: " + (", ".join(hms) if not hms.is_empty() else "none (it can learn %s)" % ", ".join(Profile.hm_options(s.id))), 17))
	var v: Dictionary = Profile.vitamins(s.id)
	var parts: Array[String] = []
	for stat in Profile.STATS:
		var n := int((v["active"] as Dictionary).get(stat, 0))
		if n > 0:
			parts.append("%s ×%d" % [str(VITAMIN_NAMES[stat]), n])
	_details.add_child(UiKit.label("Vitamins active: " + (", ".join(parts) if not parts.is_empty() else "none"), 17))


## The evolution line as buttons; `reveal` false shows unknown stages as silhouettes.
func _dex_line(s: SpeciesData, reveal: bool) -> HFlowContainer:
	var line := HFlowContainer.new()
	var chain: Array[SpeciesData] = GameData.evolution_line(s.id)
	for i in chain.size():
		if i > 0:
			line.add_child(UiKit.label("›", 36))
		var stage := chain[i]
		var b := Button.new()
		b.text = stage.display_name
		b.icon = stage.sprite if reveal else _silhouette(stage.sprite)
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_constant_override("icon_max_width", 40)
		b.disabled = stage == s
		b.pressed.connect(show_pokedex.bind(stage.id))
		line.add_child(b)
	return line


func _dex_matchups(s: SpeciesData) -> void:
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


## Silhouette, number, name, types and how to unlock it.
func _locked_header(s: SpeciesData, sprite_size: float) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	header.add_child(UiKit.sprite(_silhouette(s.sprite), sprite_size))
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(UiKit.label("#%03d  %s" % [s.dex, s.display_name], 40 if sprite_size > 120 else 32))
	info.add_child(UiKit.type_row(s.types))
	var how := UiKit.label("LEGENDARY  ·  raid boss and shrine guardian" if s.legendary else "LOCKED  ·  " + Profile.unlock_hint(s.id), 18, Color(1, 0.6, 0.45))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(how)
	header.add_child(info)
	return header


## Full Pokédex entry for a line you haven't unlocked: silhouette, name, types,
## play style, how to get it and its move names; stats and move details stay hidden.
func _show_locked_dex_entry(s: SpeciesData) -> void:
	_details.add_child(_locked_header(s, 144))
	_details.add_child(_style_box(s))
	_details.add_child(_section("EVOLUTION"))
	_details.add_child(_dex_line(s, false))
	_dex_matchups(s)
	_details.add_child(_section("MOVES  (details revealed when you unlock it)"))
	var moves := VBoxContainer.new()
	var rows: Array = [["SUPER", s.super_move]]
	if s.gadget_move:
		rows.append(["GADGET", s.gadget_move])
	for entry in s.learnset:
		rows.append(["MAIN", entry["move"]])
	for r: Array in rows:
		var move: MoveData = r[1]
		if move == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var slot := UiKit.label(str(r[0]), 15, Color(1, 1, 1, 0.6))
		slot.custom_minimum_size.x = 80
		row.add_child(slot)
		row.add_child(UiKit.label(move.display_name, 19))
		row.add_child(UiKit.type_chip(move.type, 14))
		row.add_child(UiKit.label("Power ???  ·  Range ???", 15, Color(1, 1, 1, 0.45)))
		moves.add_child(row)
	_details.add_child(moves)
	_details.add_child(UiKit.label("Base stats: ???", 17, Color(1, 1, 1, 0.5)))
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
	_play_reveals()


## Plays the "you unlocked ..." reveal for each newly unlocked line, one at a time.
func _play_reveals() -> void:
	if Profile.reveals.is_empty() or not get_tree().get_nodes_in_group("modal_overlay").is_empty():
		return
	var family: String = Profile.reveals.pop_front()
	if not GameData.species.has(family):
		_play_reveals()
		return
	var reveal := UnlockReveal.new()
	reveal.species = GameData.species[family]
	reveal.finished.connect(_play_reveals)
	add_child(reveal)


## `both_colours` shows the shiny next to the normal one (Pokédex).
func _species_header(s: SpeciesData, sprite_size: float, both_colours := false) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	var shown := s.shiny_sprite if _shiny and s.shiny_sprite and Profile.has_shiny(s.id) and not both_colours else s.sprite
	header.add_child(UiKit.sprite(shown, sprite_size))
	if both_colours and s.shiny_sprite and Profile.has_shiny(s.id):
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
	if not Profile.is_unlocked(s.id):
		b.modulate = Color(0.45, 0.45, 0.5)
		var lock := UiKit.label("LOCKED", 13, Color(1, 0.75, 0.5))
		lock.set_anchors_preset(Control.PRESET_CENTER_TOP)
		lock.position = Vector2(-24, 40)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lock)
	else:
		var lvl := UiKit.label("Lv %d" % Profile.level_of(s.id), 13, Color(1, 0.9, 0.5))
		lvl.position = Vector2(76, 22)
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lvl)
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


## True if some playable base form is of `type_name` (no Dark/Steel/Fairy in Kanto).
func _type_has_pokemon(type_name: String) -> bool:
	for s in GameData.base_species():
		if not s.legendary and s.has_type(type_name):
			return true
	return false


## True if the base form `s` is of `type_name` (gym type teams pick by the base form's types).
func _line_has_type(s: SpeciesData, type_name: String) -> bool:
	return s.has_type(type_name)


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
