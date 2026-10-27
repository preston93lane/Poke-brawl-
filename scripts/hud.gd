class_name Hud
extends CanvasLayer

signal restart_requested
signal menu_requested

const SCOREBOARD := preload("res://scripts/ui/scoreboard.gd")

var _announce_tween: Tween
var _result_buttons: HBoxContainer
var _scoreboard: Control

@onready var move_stick: VirtualJoystick = $MoveStick
@onready var aim_stick: VirtualJoystick = $AimStick
@onready var gadget_button: TouchButton = $GadgetButton
@onready var super_button: TouchButton = $SuperButton
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
	var kit_theme := UiKit.make_theme()
	var menu := UiKit.button("MENU", func() -> void: menu_requested.emit(), 16)
	menu.theme = kit_theme
	menu.tooltip_text = "Back to menu"
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


func announce(text: String) -> void:
	announcement.text = text
	if _announce_tween:
		_announce_tween.kill()
	announcement.modulate.a = 1.0
	_announce_tween = create_tween()
	_announce_tween.tween_interval(1.6)
	_announce_tween.tween_property(announcement, "modulate:a", 0.0, 0.5)


## result: "victory", "defeat" or "draw".
func show_result(result_name: String) -> void:
	move_stick.set_enabled(false)
	aim_stick.set_enabled(false)
	gadget_button.set_enabled(false)
	super_button.set_enabled(false)
	result_title.text = { "victory": "VICTORY!", "defeat": "DEFEAT", "draw": "DRAW" }.get(result_name, "DRAW")
	result_title.modulate = { "victory": Color(1.0, 0.85, 0.2), "defeat": Color(1.0, 0.35, 0.3) }.get(result_name, Color(0.8, 0.85, 1.0))
	result_hint.visible = false
	_result_buttons.visible = false
	result.visible = true
	# Short pause so a finger still on the screen doesn't hit a button by accident.
	await get_tree().create_timer(0.8).timeout
	_result_buttons.visible = true
