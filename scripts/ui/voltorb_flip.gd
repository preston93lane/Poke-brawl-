class_name VoltorbFlip
extends HBoxContainer
## Game Corner Voltorb Flip: a 5x5 board of 1s, 2s, 3s and Voltorbs. Each row and
## column says what its tiles add up to and how many Voltorbs hide in it. Flip
## tiles: your coins this round multiply by each number; find every 2 and 3 to
## win them. Hit a Voltorb and the round's coins are lost. Quit any time to keep
## what you have.

signal coins_changed

var _board: Array[int] = []
var _flipped: Array[bool] = []
var _tiles: Array[Button] = []
var _round_coins := 0
var _flips := 0
var _over := false
var _grid: GridContainer
var _status: Label
var _round_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 24)
	alignment = BoxContainer.ALIGNMENT_CENTER
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	add_child(_grid)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	side.custom_minimum_size.x = 300
	_round_label = UiKit.label("", 26, Color(1, 0.9, 0.5))
	side.add_child(_round_label)
	_status = UiKit.label("", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_status)
	side.add_child(UiKit.button("QUIT & KEEP COINS", _quit, 20))
	side.add_child(UiKit.button("NEW BOARD", _new_board, 20))
	var how := UiKit.label("Each row and column shows its total and how many Voltorbs (●) it hides. Find every 2 and 3 to clear the level and climb to bigger boards.", 15, Color(0.8, 0.85, 0.95))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(how)
	add_child(side)
	_new_board()


func _new_board() -> void:
	_board = Town.voltorb_board(Town.voltorb_level())
	_flipped.clear()
	_flipped.resize(25)
	_flipped.fill(false)
	_round_coins = 0
	_flips = 0
	_over = false
	for c in _grid.get_children():
		c.queue_free()
	_tiles.clear()
	var hints := Town.voltorb_hints(_board)
	for y in 6:
		for x in 6:
			if y < 5 and x < 5:
				var i := y * 5 + x
				var b := Button.new()
				b.custom_minimum_size = Vector2(72, 72)
				b.add_theme_stylebox_override("normal", UiKit.box(Color(0.2, 0.55, 0.4), 10, 4))
				b.add_theme_font_size_override("font_size", 34)
				b.pressed.connect(_flip.bind(i))
				_grid.add_child(b)
				_tiles.append(b)
			elif y < 5 or x < 5:
				var h: Dictionary = hints[y] if x == 5 else hints[5 + x]
				var p := PanelContainer.new()
				p.custom_minimum_size = Vector2(72, 72)
				p.add_theme_stylebox_override("panel", UiKit.box([Color(0.85, 0.35, 0.3), Color(0.35, 0.7, 0.35), Color(0.9, 0.6, 0.2),
						Color(0.3, 0.5, 0.85), Color(0.65, 0.4, 0.8)][(y if x == 5 else x) % 5], 10, 4))
				var l := UiKit.label("%02d\n● %d" % [int(h["sum"]), int(h["voltorbs"])], 18)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				p.add_child(l)
				_grid.add_child(p)
			else:
				_grid.add_child(Control.new())
	_update()


func _flip(i: int) -> void:
	if _over or _flipped[i]:
		return
	_flipped[i] = true
	_flips += 1
	var v := _board[i]
	_show_tile(i)
	if v == 0:
		_over = true
		Town.finish_voltorb(false, 0, _flips - 1)
		_status.text = "KABOOM! A Voltorb. The round's coins are lost."
		_reveal_all()
		coins_changed.emit()
		return
	_round_coins = v if _round_coins == 0 else _round_coins * v
	var left := 0
	for k in 25:
		if _board[k] >= 2 and not _flipped[k]:
			left += 1
	if left == 0:
		_over = true
		Town.finish_voltorb(true, _round_coins, _flips)
		_status.text = "Cleared! +%d coins. Next board is a level up." % _round_coins
		_reveal_all()
		coins_changed.emit()
	_update()


func _quit() -> void:
	if _over or _round_coins <= 0:
		_new_board()
		return
	Town.quit_voltorb(_round_coins)
	_over = true
	_status.text = "Kept %d coins." % _round_coins
	_reveal_all()
	coins_changed.emit()


func _show_tile(i: int) -> void:
	var b := _tiles[i]
	var v := _board[i]
	b.text = "●" if v == 0 else str(v)
	b.add_theme_stylebox_override("normal", UiKit.box(Color(0.85, 0.25, 0.25) if v == 0 else Color(0.95, 0.92, 0.8), 10, 4))
	b.add_theme_stylebox_override("disabled", UiKit.box(Color(0.85, 0.25, 0.25, 0.8) if v == 0 else Color(0.95, 0.92, 0.8, 0.8), 10, 4))
	b.add_theme_color_override("font_color", Color.WHITE if v == 0 else Color(0.2, 0.2, 0.3))
	b.add_theme_color_override("font_disabled_color", Color.WHITE if v == 0 else Color(0.25, 0.25, 0.35))


func _reveal_all() -> void:
	for k in 25:
		_show_tile(k)
		_tiles[k].disabled = true
	_update()


func _update() -> void:
	_round_label.text = "LEVEL %d   ·   THIS ROUND: %d" % [Town.voltorb_level(), _round_coins]
	if not _over and _status.text == "":
		_status.text = "Flip a tile to start."
