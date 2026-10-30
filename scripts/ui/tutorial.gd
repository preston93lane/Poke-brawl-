class_name Tutorial
extends Control
## How to Play: a short slideshow (controls, Pokémon moves, the menus, bag and
## store). Shown once on first launch, and from Settings, the home screen's ?
## button and the pause menu. Each page has a small picture drawn from the game's
## own sprites and button colours, so it stays in step with the real thing.

signal closed

## [title, picture, bullet points]
const PAGES := [
	["WELCOME TO POKé BRAWL", "team", [
		"3v3 real-time battles: pick a Pokémon, two bots join your team.",
		"Knock out the other team to win. KOs also make your Pokémon evolve mid-match.",
		"Every match earns XP for that Pokémon's line, money (₽) and often a Poké Ball.",
	]],
	["MOVING AND ATTACKING", "sticks", [
		"Left stick: move. Hide in tall grass to vanish from enemies' view.",
		"Right stick: drag to aim your main attack and let go to fire. Tap it to auto-aim at the nearest enemy.",
		"The orange bars under your health are ammo; they refill by themselves.",
		"On a keyboard: WASD to move, F to attack, E super, Space gadget, Q HM, R Z-Move, Esc pause.",
	]],
	["SUPER, GADGET, HM AND Z", "buttons", [
		"SUPER (gold): fills as you deal damage. Drag it to aim, tap to auto-aim.",
		"GADGET (green): 3 uses a match, with a short cooldown.",
		"HM (purple): optional, recharges every 10 s. Teach one from the bag.",
		"Z-MOVE: final evolutions at line level 50. Fill the Z meter, then fire a powered-up super.",
	]],
	["YOUR POKéMON'S MOVES", "moves", [
		"Main attack: pick one of three in the build editor; more unlock with level or a TM.",
		"Super: each stage has its own, and can use an earlier stage's or a TM super.",
		"Ability: a passive bonus (unlocks at Lv 20 and 40). Gadgets unlock at Lv 10 and 30.",
		"Types matter: super-effective hits deal more and show '!'. Status and stat drops show next to the health bar.",
	]],
	["FINDING YOUR WAY AROUND", "home", [
		"BATTLE: every mode: Battle, King of the Hill, Brawl Ball, Rare Candy Rush, Showdown, Gyms, Boss Raids.",
		"CHALLENGES: daily tasks and the weekly shiny hunt.",
		"POKéDEX: your Pokémon. Tap one to edit its build (moves, super, gadget, Ability, HM, vitamins).",
		"PROFILE: your stats, favourite Pokémon and gym badges. ACCOUNT saves to the cloud; SETTINGS has the controls.",
		"A red dot on a button means something new is waiting there.",
	]],
	["THE BAG", "bag", [
		"Poké Balls from matches: open them for money, Rare Candy, vitamins, TMs, HMs and even new Pokémon.",
		"Great, Ultra and Master Balls hold better prizes.",
		"Rare Candy levels a line up. Vitamins (HP Up, Protein, Iron, Carbos) give a Pokémon small stat boosts.",
		"TMs unlock main attacks and supers; HMs teach a line its HM.",
	]],
	["THE POKé MART", "store", [
		"New stock every day: balls, Rare Candy, vitamins, TMs and sometimes a shiny.",
		"Each item can only be bought a few times a day, and costs 25% more each time.",
		"Earn ₽ by playing; wins, MVPs and challenges pay the most.",
	]],
	["READY!", "ready", [
		"Start with BATTLE → Battle 3v3 to learn the ropes.",
		"You can open this guide again from Settings or the pause menu.",
		"Have fun!",
	]],
]

var _page := 0
var _body: VBoxContainer
var _dots: HBoxContainer
var _back: Button
var _next: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 90
	panel.offset_right = -90
	panel.offset_top = 40
	panel.offset_bottom = -30
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	v.add_child(_body)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	_back = UiKit.button("‹ BACK", func() -> void: _show(_page - 1), 22)
	nav.add_child(_back)
	_dots = HBoxContainer.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	nav.add_child(_dots)
	var skip := UiKit.button("SKIP", _close, 18)
	skip.add_theme_stylebox_override("normal", UiKit.box(Color(0.35, 0.38, 0.5)))
	nav.add_child(skip)
	_next = UiKit.button("NEXT ›", func() -> void: _show(_page + 1), 22)
	_next.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.65, 0.35)))
	nav.add_child(_next)
	v.add_child(nav)
	_show(0)


func _show(index: int) -> void:
	if index >= PAGES.size():
		_close()
		return
	_page = clampi(index, 0, PAGES.size() - 1)
	for c in _body.get_children():
		c.queue_free()
	for c in _dots.get_children():
		c.queue_free()
	var page: Array = PAGES[_page]
	var title := UiKit.label(str(page[0]), 34, Color(1, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pic := _picture(str(page[1]))
	pic.custom_minimum_size = Vector2(340, 300)
	row.add_child(pic)
	var points := VBoxContainer.new()
	points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points.alignment = BoxContainer.ALIGNMENT_CENTER
	points.add_theme_constant_override("separation", 14)
	for text: String in page[2]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var dot := UiKit.label("●", 16, Color(1, 0.85, 0.3))
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(dot)
		var l := UiKit.label(text, 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		points.add_child(line)
	row.add_child(points)
	_body.add_child(row)
	for i in PAGES.size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(12, 12)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		d.color = Color(1, 0.85, 0.3) if i == _page else Color(1, 1, 1, 0.25)
		_dots.add_child(d)
	_back.disabled = _page == 0
	_next.text = "LET'S GO!" if _page == PAGES.size() - 1 else "NEXT ›"


func _close() -> void:
	Profile.data["tutorial_seen"] = true
	Profile.save()
	closed.emit()
	queue_free()


## A small illustration for each page.
func _picture(kind: String) -> Control:
	var pic := TutorialPicture.new()
	pic.kind = kind
	return pic


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_RIGHT, KEY_ENTER, KEY_SPACE:
			_show(_page + 1)
		KEY_LEFT:
			_show(_page - 1)
		KEY_ESCAPE:
			_close()
	get_viewport().set_input_as_handled()
