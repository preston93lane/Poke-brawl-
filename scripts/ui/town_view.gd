class_name TownView
extends Control
## The home screen: the walkable town (TownWorld, in its own 3D viewport) with
## your trainer card and shortcuts on top, a stick to walk with and the
## ENTER / TALK button when you're next to a door or a trainer.

var menu: Node
var world: TownWorld
var stick: VirtualJoystick
var action: Button


static func make(p_menu: Node) -> TownView:
	var v := TownView.new()
	v.menu = p_menu
	return v


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	Quality.apply_viewport(viewport)
	container.add_child(viewport)
	world = TownWorld.new()
	viewport.add_child(world)
	world.prompt_changed.connect(_on_prompt)
	world.enter_requested.connect(func(id: String) -> void: menu.enter_building(id))
	world.talk_requested.connect(func(t: Dictionary) -> void: menu.show_trainer(t))
	NatureKit.warm.call_deferred(get_tree())

	stick = VirtualJoystick.new()
	stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	stick.anchor_right = 0.55
	stick.rest_anchor = Vector2(0, 1)
	stick.rest_offset = Vector2(200, -170)
	add_child(stick)

	_top_bar()

	action = UiKit.button("", func() -> void: world.interact(), 28)
	action.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	action.offset_left = -420
	action.offset_top = -230
	action.offset_right = -60
	action.offset_bottom = -140
	action.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.7, 0.35), 20, 12))
	action.visible = false
	add_child(action)
	var battle := UiKit.button("BATTLE", menu.show_battle_modes, 40)
	battle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	battle.offset_left = -330
	battle.offset_top = -120
	battle.offset_right = -60
	battle.offset_bottom = -30
	battle.add_theme_stylebox_override("normal", UiKit.box(Color(0.95, 0.6, 0.15), 20, 12))
	battle.add_theme_stylebox_override("hover", UiKit.box(Color(1.0, 0.68, 0.2), 20, 12))
	add_child(battle)


func _top_bar() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.45), 16, 10))
	card.position = Vector2(56, 16)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.add_child(UiKit.label("TRAINER LV %d" % Profile.total_level(), 22, Color(1, 0.88, 0.35)))
	col.add_child(UiKit.label("%d ₽   ·   %d coins" % [Profile.money(), Town.coins()], 18))
	card.add_child(col)
	add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_right = -56
	row.offset_top = 16
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var left := 0
	for t: Dictionary in Profile.dailies():
		if not bool(t["done"]):
			left += 1
	for entry in [["CHALLENGES", menu.show_challenges, Color(0.45, 0.3, 0.75), "challenges"],
			["BAG", menu.show_bag.bind([] as Array[Dictionary]), Color(0.25, 0.55, 0.45), "bag"],
			["POKéDEX", menu.show_pokedex.bind("", "mine"), Color(0.75, 0.3, 0.3), "pokedex"],
			["☰", menu.show_overview, Color(0.35, 0.38, 0.5), ""]]:
		var b := UiKit.button(entry[0], entry[1], 18)
		b.custom_minimum_size = Vector2(64 if entry[0] == "☰" else 140, 52)
		b.add_theme_stylebox_override("normal", UiKit.box(entry[2], 14, 8))
		if entry[3] != "" and Profile.has_news(entry[3]):
			UiKit.news_dot(b, Profile.count_balls() if entry[3] == "bag" else 0)
		elif entry[3] == "challenges" and left > 0:
			UiKit.news_dot(b, left)
		row.add_child(b)
	add_child(row)


var _stick_was_active := false


func _process(_delta: float) -> void:
	if is_instance_valid(world) and world.player:
		var active := stick.is_active() or stick.output != Vector2.ZERO
		if active:
			world.player.move_input = stick.output
		elif _stick_was_active:
			world.player.move_input = Vector2.ZERO  # Let go: stop.
		_stick_was_active = active


func _on_prompt(text: String) -> void:
	action.text = text
	action.visible = text != ""
	if action.visible:
		action.pivot_offset = action.size * 0.5
		action.scale = Vector2(0.8, 0.8)
		create_tween().tween_property(action, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
