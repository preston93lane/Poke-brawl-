class_name SlotMachine
extends VBoxContainer
## Game Corner slots: three reels that spin and stop one after another. The
## result is decided by Town.spin() when you pull; the reels just show it.

signal coins_changed

const SYMBOL_COLORS := {
	"seven": Color(0.95, 0.2, 0.25), "bar": Color(0.2, 0.2, 0.25), "pikachu": Color(1, 0.85, 0.2),
	"poke_ball": Color(0.9, 0.25, 0.25), "magnemite": Color(0.6, 0.65, 0.75), "cherry": Color(0.85, 0.1, 0.3),
}

var _reels: Array[PanelContainer] = []
var _result: Label
var _bet := 1
var _spinning := false
var _bet_buttons: Array[Button] = []


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in 3:
		var reel := PanelContainer.new()
		reel.custom_minimum_size = Vector2(150, 150)
		reel.add_theme_stylebox_override("panel", UiKit.box(Color(0.97, 0.95, 0.88), 18, 8))
		row.add_child(reel)
		_reels.append(reel)
		_show(reel, ["seven", "pikachu", "cherry"][i])
	add_child(row)
	_result = UiKit.label("Pick a bet and pull!", 26, Color(1, 0.9, 0.5))
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_result)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	for bet in [1, 2, 3]:
		var b := UiKit.button("BET %d" % bet, func() -> void:
			_bet = bet
			_mark_bet(), 22)
		b.custom_minimum_size = Vector2(110, 60)
		_bet_buttons.append(b)
		controls.add_child(b)
	var pull := UiKit.button("PULL!", _pull, 32)
	pull.custom_minimum_size = Vector2(200, 70)
	pull.add_theme_stylebox_override("normal", UiKit.box(Color(0.9, 0.3, 0.3)))
	controls.add_child(pull)
	add_child(controls)
	var table := PackedStringArray()
	for sym: String in Town.cfg("game_corner/slots/payout", {}):
		table.append("3× %s = ×%d" % [_name(sym), int(Town.cfg("game_corner/slots/payout/" + sym, 0))])
	table.append("1 cherry ×%d, 2 cherries ×%d" % [int(Town.cfg("game_corner/slots/cherry_one", 1)), int(Town.cfg("game_corner/slots/cherry_two", 2))])
	var help := UiKit.label("  ·  ".join(table), 15, Color(0.8, 0.85, 0.95))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.custom_minimum_size.x = 640
	add_child(help)
	_mark_bet()


func _name(sym: String) -> String:
	return { "seven": "7", "bar": "BAR", "pikachu": "Pikachu", "poke_ball": "Poké Ball", "magnemite": "Magnemite", "cherry": "Cherry" }.get(sym, sym)


func _mark_bet() -> void:
	for i in _bet_buttons.size():
		_bet_buttons[i].modulate = Color.WHITE if i + 1 == _bet else Color(1, 1, 1, 0.45)


func _show(reel: PanelContainer, sym: String) -> void:
	for c in reel.get_children():
		c.queue_free()
	var node: Control
	match sym:
		"pikachu", "magnemite":
			node = PmdIcon.make(GameData.species[sym], 120) if GameData.species.has(sym) else UiKit.label(_name(sym), 40)
		"poke_ball":
			node = UiKit.sprite(UiKit.item_icon("poke_ball"), 110)
		_:
			var l := UiKit.label("7" if sym == "seven" else ("BAR" if sym == "bar" else "●●"), 80 if sym == "seven" else 50, SYMBOL_COLORS[sym])
			l.add_theme_constant_override("outline_size", 10)
			l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
			node = l
	if node is Label:
		(node as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(node as Label).vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reel.add_child(node)


func _pull() -> void:
	if _spinning:
		return
	var r := Town.spin(_bet)
	if r.is_empty():
		_result.text = "Not enough coins! Buy some at the counter."
		return
	_spinning = true
	coins_changed.emit()
	_result.text = "..."
	var symbols: Array = Town.cfg("game_corner/slots/symbols", [])
	for i in 3:
		var spins := 8 + i * 6
		for k in spins:
			_show(_reels[i], symbols[randi() % symbols.size()])
			await get_tree().create_timer(0.05).timeout
			if not is_inside_tree():
				return
		_show(_reels[i], r["reels"][i])
		var t := create_tween()
		_reels[i].pivot_offset = _reels[i].size * 0.5
		t.tween_property(_reels[i], "scale", Vector2(1.08, 1.08), 0.06)
		t.tween_property(_reels[i], "scale", Vector2.ONE, 0.1)
	_spinning = false
	var win := int(r["win"])
	_result.text = "You won %d coins!" % win if win > 0 else "No luck this time."
	if win >= 30 * _bet:
		_result.text = "JACKPOT!  %d coins!" % win
	coins_changed.emit()
