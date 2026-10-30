class_name Hud
extends CanvasLayer

signal restart_requested
signal menu_requested
signal pause_requested

const SCOREBOARD := preload("res://scripts/ui/scoreboard.gd")

var _announce_tween: Tween
var _result_buttons: HBoxContainer
var _scoreboard: Control
var _summary: Control

@onready var move_stick: VirtualJoystick = $MoveStick
@onready var aim_stick: VirtualJoystick = $AimStick
@onready var gadget_button: TouchButton = $GadgetButton
@onready var super_button: TouchButton = $SuperButton
## HM ability button (made in code; hidden unless an HM is equipped).
var hm_button: TouchButton
var z_button: TouchButton
var _flash: ColorRect
@onready var matchup_label: Label = $Matchup
@onready var status_label: Label = $Status
@onready var announcement: Label = $Announcement
@onready var result: Control = $Result
@onready var result_title: Label = $Result/Title
@onready var result_hint: Label = $Result/Hint


var _rotate_overlay: ColorRect
var _blind_overlay: ColorRect


func _ready() -> void:
	result.visible = false
	announcement.modulate.a = 0.0
	if DisplayServer.is_touchscreen_available():
		$KeyboardHint.visible = false
	_scoreboard = SCOREBOARD.new()
	add_child(_scoreboard)
	move_child(_scoreboard, 1)
	matchup_label.visible = false  # The scoreboard shows teams and score now.
	status_label.visible = false
	_build_buttons()
	_build_rotate_overlay()
	apply_layout(GameData.control_layout())
	_blind_overlay = ColorRect.new()
	_blind_overlay.color = Color(1, 1, 0.92, 0.55)
	_blind_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blind_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blind_overlay.visible = false
	add_child(_blind_overlay)
	move_child(_blind_overlay, 1)


func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	_rotate_overlay.visible = size.y > size.x
	var viewer: Brawler = GameData.local_player
	var blind := is_instance_valid(viewer) and viewer.is_blind()
	_blind_overlay.visible = blind


func _build_buttons() -> void:
	hm_button = TouchButton.new()
	hm_button.label = "HM"
	hm_button.color = Color(0.6, 0.45, 0.9)
	hm_button.icon_type = "normal"
	hm_button.visible = false
	add_child(hm_button)
	move_child(hm_button, super_button.get_index() + 1)
	z_button = TouchButton.new()
	z_button.label = "Z-MOVE"
	z_button.color = Color(1.0, 0.82, 0.25)
	z_button.icon_type = "super"
	z_button.display = "charge"
	z_button.visible = false
	add_child(z_button)
	move_child(z_button, super_button.get_index() + 1)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	move_child(_flash, 0)
	var kit_theme := UiKit.make_theme()
	var menu := UiKit.button("❚❚ PAUSE", func() -> void: pause_requested.emit(), 16)
	menu.theme = kit_theme
	menu.tooltip_text = "Pause"
	menu.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0, 0, 0.45), 12, 8))
	menu.position = Vector2(56, 16)
	add_child(menu)

	_result_buttons = HBoxContainer.new()
	_result_buttons.theme = kit_theme
	_result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_buttons.add_theme_constant_override("separation", 24)
	_result_buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_result_buttons.offset_top = -200
	_result_buttons.offset_bottom = -110
	_result_buttons.offset_left = -300
	_result_buttons.offset_right = 300
	for entry in [["REMATCH", restart_requested], ["MENU", menu_requested]]:
		var sig: Signal = entry[1]
		var b := UiKit.button(entry[0], func() -> void: sig.emit(), 30)
		b.custom_minimum_size = Vector2(240, 72)
		_result_buttons.add_child(b)
	result.add_child(_result_buttons)


## Shown when the phone is held in portrait; the game is landscape-only.
func _build_rotate_overlay() -> void:
	_rotate_overlay = ColorRect.new()
	_rotate_overlay.color = Color(0.08, 0.1, 0.16, 0.92)
	_rotate_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "Rotate your phone\nto landscape ⟳"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	_rotate_overlay.add_child(label)
	add_child(_rotate_overlay)
	_rotate_overlay.visible = false


## Place the sticks and buttons from a layout (see GameData.DEFAULT_LAYOUT).
func apply_layout(layout: Dictionary) -> void:
	var scale := clampf(float(layout.get("scale", 1.0)), 0.6, 1.6)
	var swapped := bool(layout.get("swapped", false))
	_place_stick(move_stick, layout["move"], 0.5 if swapped else 0.0, scale)
	_place_stick(aim_stick, layout["aim"], 0.0 if swapped else 0.5, scale)
	for entry in [[gadget_button, layout["gadget"]], [super_button, layout["super"]], [hm_button, layout.get("hm", [0.93, 0.5])],
			[z_button, layout.get("zmove", [0.56, 0.52])]]:
		var button: TouchButton = entry[0]
		var at: Array = entry[1]
		var half := 55.0 * scale
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.anchor_left = float(at[0])
		button.anchor_right = float(at[0])
		button.anchor_top = float(at[1])
		button.anchor_bottom = float(at[1])
		button.offset_left = -half
		button.offset_right = half
		button.offset_top = -half
		button.offset_bottom = half


## A stick's touch zone is the half of the screen it's on (from 30% down); it
## rests at `at` (screen fractions).
func _place_stick(stick: VirtualJoystick, at: Array, zone_left: float, scale: float) -> void:
	stick.anchor_left = zone_left
	stick.anchor_right = zone_left + 0.5
	stick.anchor_top = 0.3
	stick.anchor_bottom = 1.0
	stick.offset_left = 0
	stick.offset_right = 0
	stick.offset_top = 0
	stick.offset_bottom = 0
	stick.rest_anchor = Vector2(clampf((float(at[0]) - zone_left) / 0.5, 0.0, 1.0), clampf((float(at[1]) - 0.3) / 0.7, 0.0, 1.0))
	stick.rest_offset = Vector2.ZERO
	stick.radius = 110.0 * scale
	stick.knob_radius = 46.0 * scale
	if stick.touch_radius > 0.0:
		stick.touch_radius = 240.0 * scale
	stick._reset()


func set_matchup(player_name: String, enemy_name: String, arena_name: String) -> void:
	matchup_label.text = "%s   vs   %s   —   %s" % [player_name.to_upper(), enemy_name.to_upper(), arena_name]


func set_status(text: String) -> void:
	status_label.text = text


## Labels, icons and colours of the controls follow the equipped moves' types.
func set_moves(main: MoveData, gadget: MoveData) -> void:
	if gadget:
		gadget_button.label = gadget.display_name.to_upper()
		gadget_button.icon_type = gadget.type
		gadget_button.color = GameData.type_color(gadget.type).lerp(Color(0.3, 0.85, 0.55), 0.45)
		gadget_button.queue_redraw()
	aim_stick.label = main.display_name.to_upper()
	aim_stick.icon_type = main.type
	aim_stick.color = GameData.type_color(main.type).lightened(0.15)
	aim_stick.queue_redraw()
	super_button.icon_type = "super"


## Shows the HM button for the equipped HM (null hides it).
func set_hm(move: MoveData) -> void:
	hm_button.visible = move != null
	if move:
		hm_button.label = move.display_name.to_upper()
		hm_button.icon_type = move.type
		hm_button.color = GameData.type_color(move.type).lerp(Color(0.6, 0.45, 0.9), 0.5)
		hm_button.queue_redraw()


## Brawl Ball: while you carry the ball the aim stick kicks it.
func set_kick(carrying: bool, main: MoveData) -> void:
	if carrying:
		aim_stick.label = "KICK"
		aim_stick.icon_type = "normal"
		aim_stick.color = Color(0.95, 0.95, 0.95)
		aim_stick.queue_redraw()
	else:
		set_moves(main, null)


func set_mode_info(info: Dictionary) -> void:
	_scoreboard.info = info


func set_teams(teams: Dictionary) -> void:
	_scoreboard.teams = teams


func set_scores(mode: String, scores: Array, target: float, time_left: float) -> void:
	_scoreboard.mode = mode
	_scoreboard.scores = scores
	_scoreboard.target = target
	_scoreboard.time_left = time_left


func set_shrine(hold: Array, need: float, cooldown: float, guardian_id: String) -> void:
	_scoreboard.shrine = { "hold": hold, "need": need, "cooldown": cooldown, "guardian": guardian_id }


func add_kill(killer: Brawler, victim: Brawler) -> void:
	_scoreboard.add_kill(killer, victim)


## A quick tinted flash over the whole screen (your Z-Move).
func flash(color: Color) -> void:
	_flash.color = Color(color, 0.35)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)


## 3, 2, 1, GO! in the middle of the screen (the match is paused meanwhile).
func countdown() -> void:
	var l := Label.new()
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 150)
	l.add_theme_constant_override("outline_size", 24)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	l.pivot_offset = get_viewport().get_visible_rect().size * 0.5
	add_child(l)
	for step in ["3", "2", "1", "GO!"]:
		l.text = step
		l.add_theme_color_override("font_color", Color(0.4, 1, 0.5) if step == "GO!" else Color(1, 0.85, 0.3))
		l.scale = Vector2.ONE * 1.6
		l.modulate.a = 1.0
		var tween := create_tween().set_parallel()
		tween.tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.55)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		await get_tree().create_timer(0.55 if step == "GO!" else 0.8, true).timeout
		if not is_instance_valid(l):
			return
	l.queue_free()


func announce(text: String) -> void:
	announcement.text = text
	if _announce_tween:
		_announce_tween.kill()
	announcement.modulate.a = 1.0
	_announce_tween = create_tween()
	_announce_tween.tween_interval(1.6)
	_announce_tween.tween_property(announcement, "modulate:a", 0.0, 0.5)


## Renames the REMATCH button (gyms: "ROUND 2 ›", "RETRY GYM"...).
func set_rematch_text(text: String) -> void:
	(_result_buttons.get_child(0) as Button).text = text


## result: "victory", "defeat" or "draw". `rows` (from main.summary_rows) fill the
## match summary; `stat_name` adds a mode column (GOALS, CANDIES, CUBES).
## `rewards`: what Profile.record_match() gave (shown under the table).
func show_result(result_name: String, rows: Array[Dictionary] = [], stat_name := "", subtitle := "", rewards := {}) -> void:
	move_stick.set_enabled(false)
	aim_stick.set_enabled(false)
	gadget_button.set_enabled(false)
	super_button.set_enabled(false)
	hm_button.set_enabled(false)
	z_button.set_enabled(false)
	result_title.text = { "victory": "VICTORY!", "defeat": "DEFEAT", "draw": "DRAW" }.get(result_name, "DRAW")
	result_title.modulate = { "victory": Color(1.0, 0.85, 0.2), "defeat": Color(1.0, 0.35, 0.3) }.get(result_name, Color(0.8, 0.85, 1.0))
	result_hint.visible = subtitle != ""
	result_hint.text = subtitle
	if not rows.is_empty():
		# Title at the top, summary table in the middle.
		result_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		result_title.offset_top = 6
		result_title.offset_bottom = 110
		result_title.add_theme_font_size_override("font_size", 72)
		result_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
		result_hint.offset_top = 92
		result_hint.offset_bottom = 132
		result_hint.add_theme_font_size_override("font_size", 26)
		_summary = _build_summary(rows, stat_name, rewards)
		result.add_child(_summary)
	_result_buttons.visible = false
	result.visible = true
	# Short pause so a finger still on the screen doesn't hit a button by accident.
	await get_tree().create_timer(0.8).timeout
	_result_buttons.visible = true


func _build_summary(rows: Array[Dictionary], stat_name: String, rewards := {}) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.06, 0.07, 0.13, 0.88), 16, 12))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	var headers := ["", "POKéMON", "KOs", "FAINTED", "DAMAGE", "HEALING"]
	if stat_name != "":
		headers.append(stat_name)
	var showdown := not rows.is_empty() and int(rows[0].get("placement", 0)) > 0
	if showdown:
		headers.insert(0, "#")
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	for h: String in headers:
		grid.add_child(UiKit.label(h, 15, Color(1, 0.85, 0.4)))
	for row in rows:
		var team_color := Color(0.55, 0.75, 1.0) if int(row["team"]) == GameData.local_team else Color(1.0, 0.6, 0.6)
		if row["is_player"]:
			team_color = Color(0.55, 1.0, 0.6)
		if showdown:
			grid.add_child(UiKit.label("#%d" % int(row["placement"]), 20, team_color))
		var icon := TextureRect.new()
		icon.texture = row["sprite"]
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(icon)
		var name_text := str(row["name"]) + ("  (YOU)" if row["is_player"] else "")
		if row["mvp"]:
			name_text = "★ MVP  " + name_text
		grid.add_child(UiKit.label(name_text, 19, Color(1, 0.85, 0.3) if row["mvp"] else team_color))
		for key in ["kills", "deaths", "damage", "healing"]:
			grid.add_child(UiKit.label(str(row[key]), 19))
		if stat_name != "":
			grid.add_child(UiKit.label(str(row["stat"]), 19))
	# Rows slide in one after another under the header.
	var cells := grid.get_children()
	for i in range(headers.size(), cells.size()):
		var cell := cells[i] as Control
		cell.modulate.a = 0.0
		var row_index := floori(float(i) / headers.size())
		var t := cell.create_tween()
		t.tween_property(cell, "modulate:a", 1.0, 0.2).set_delay(0.15 + row_index * 0.09)
	var box := VBoxContainer.new()
	box.add_child(grid)
	if not rewards.is_empty():
		box.add_child(_rewards_panel(rewards))
	panel.add_child(box)
	# Centre it once its size is known.
	panel.resized.connect(func() -> void:
		panel.position = (get_viewport().get_visible_rect().size - panel.size) * Vector2(0.5, 0.5) + Vector2(0, -12))
	return panel


## Rewards under the summary: the line's XP bar filling up (with a LEVEL UP! pop
## for each level gained), then each reward popping in one after another.
func _rewards_panel(r: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size.x = 640
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var family := str(r.get("family", ""))
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 10)
	xp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	if GameData.species.has(family):
		xp_row.add_child(UiKit.sprite(GameData.species[family].sprite, 40))
	var level_label := UiKit.label("Lv %d" % int(r.get("level_before", 1)), 22, Color(1, 0.95, 0.7))
	level_label.custom_minimum_size.x = 70
	xp_row.add_child(level_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(320, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxi(1, Profile.xp_needed(int(r.get("level_before", 1))))
	bar.value = int(r.get("xp_before", 0))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.78, 0.2)
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", back)
	xp_row.add_child(bar)
	var xp_label := UiKit.label("+%d XP%s" % [int(r["xp"]), "  ×2 FIRST WIN" if r.get("first_win", false) else ""], 20, Color(1, 0.9, 0.45))
	xp_row.add_child(xp_label)
	v.add_child(xp_row)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	for chip in _reward_chips(r):
		chip.modulate.a = 0.0
		chips.add_child(chip)
	v.add_child(chips)
	_play_rewards.call_deferred(r, bar, level_label, chips)
	return v


func _reward_chips(r: Dictionary) -> Array[Control]:
	var out: Array[Control] = []
	out.append(_chip("+%d ₽" % int(r["money"]), Color(0.75, 0.6, 0.15)))
	var balls := {}
	for ball: String in r.get("balls", []):
		balls[ball] = int(balls.get(ball, 0)) + 1
	for ball: String in balls:
		out.append(_chip("%s%s" % [Profile.item_name(ball), " ×%d" % balls[ball] if int(balls[ball]) > 1 else ""], Color(0.3, 0.4, 0.75), ball))
	for family: String in r.get("pokemon", []):
		out.append(_chip("NEW: %s!" % GameData.species[family].display_name, Color(0.25, 0.6, 0.35)))
	if str(r.get("shiny", "")) != "":
		out.append(_chip("✦ SHINY %s UNLOCKED! ✦" % GameData.species[str(r["shiny"])].display_name.to_upper(), Color(0.8, 0.5, 0.15)))
	for m: String in r.get("milestones", []):
		out.append(_chip("Milestone: %s" % m, Color(0.55, 0.35, 0.8)))
	for e: String in r.get("extras", []):
		out.append(_chip(e, Color(0.35, 0.38, 0.5)))
	for d: String in r.get("dailies", []):
		out.append(_chip(d, Color(0.45, 0.3, 0.75)))
	return out


func _chip(text: String, color: Color, ball := "") -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(color, 12, 6))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if ball != "":
		var icon := TrainerScreens.BallIcon.new()
		icon.kind = ball
		icon.custom_minimum_size = Vector2(24, 24)
		row.add_child(icon)
	row.add_child(UiKit.label(text, 18))
	chip.add_child(row)
	return chip


func _play_rewards(r: Dictionary, bar: ProgressBar, level_label: Label, chips: Container) -> void:
	await get_tree().create_timer(0.5, true).timeout
	var level := int(r.get("level_before", 1))
	for i in int(r.get("levels", 0)):
		if not is_instance_valid(bar):
			return
		await _fill_bar(bar, bar.max_value, 0.55)
		level += 1
		_level_up_pop(level_label, level)
		bar.max_value = maxi(1, Profile.xp_needed(level))
		bar.value = 0
		await get_tree().create_timer(0.45, true).timeout
	if not is_instance_valid(bar):
		return
	await _fill_bar(bar, int(r.get("xp_after", bar.value)), 0.5)
	for chip in chips.get_children():
		if not is_instance_valid(chip):
			return
		var c := chip as Control
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(0.5, 0.5)
		var pop := c.create_tween().set_parallel()
		pop.tween_property(c, "modulate:a", 1.0, 0.12)
		pop.tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.22, true).timeout


func _fill_bar(bar: ProgressBar, to: float, seconds: float) -> void:
	var tween := bar.create_tween()
	tween.tween_property(bar, "value", to, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


## "LEVEL UP!" bursts out of the level number, which ticks up.
func _level_up_pop(level_label: Label, level: int) -> void:
	if not is_instance_valid(level_label):
		return
	level_label.text = "Lv %d" % level
	level_label.pivot_offset = level_label.size * 0.5
	level_label.scale = Vector2(1.6, 1.6)
	level_label.add_theme_color_override("font_color", Color(0.5, 1, 0.55))
	var t := level_label.create_tween()
	t.tween_property(level_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var burst := UiKit.label("LEVEL UP!", 34, Color(1, 0.9, 0.3))
	burst.add_theme_constant_override("outline_size", 8)
	burst.top_level = true
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.add_child(burst)
	burst.global_position = level_label.global_position + Vector2(-30, -40)
	burst.pivot_offset = Vector2(80, 20)
	burst.scale = Vector2(0.4, 0.4)
	var b := burst.create_tween().set_parallel()
	b.tween_property(burst, "scale", Vector2(1.1, 1.1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.tween_property(burst, "position:y", burst.position.y - 34, 1.1)
	b.tween_property(burst, "modulate:a", 0.0, 0.35).set_delay(0.8)
	b.chain().tween_callback(burst.queue_free)
	# A ring of little stars flying out.
	for i in 8:
		var star := UiKit.label("✦", 20, Color(1, 0.85, 0.3))
		star.top_level = true
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.add_child(star)
		var from := level_label.global_position + level_label.size * 0.5 - Vector2(8, 12)
		star.global_position = from
		var dir := Vector2.RIGHT.rotated(TAU * i / 8.0)
		var s := star.create_tween().set_parallel()
		s.tween_property(star, "global_position", from + dir * 70.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		s.tween_property(star, "modulate:a", 0.0, 0.6)
		s.chain().tween_callback(star.queue_free)
