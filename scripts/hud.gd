class_name Hud
extends CanvasLayer

signal restart_requested

var _can_restart := false
var _announce_tween: Tween

@onready var move_stick: VirtualJoystick = $MoveStick
@onready var aim_stick: VirtualJoystick = $AimStick
@onready var melee_button: TouchButton = $MeleeButton
@onready var matchup_label: Label = $Matchup
@onready var status_label: Label = $Status
@onready var announcement: Label = $Announcement
@onready var result: Control = $Result
@onready var result_title: Label = $Result/Title
@onready var result_hint: Label = $Result/Hint


var _rotate_overlay: ColorRect


func _ready() -> void:
	result.visible = false
	announcement.modulate.a = 0.0
	if DisplayServer.is_touchscreen_available():
		$KeyboardHint.visible = false
	_build_rotate_overlay()


func _process(_delta: float) -> void:
	var size := get_viewport().get_visible_rect().size
	_rotate_overlay.visible = size.y > size.x


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
	matchup_label.text = "%s  vs  %s  ·  %s" % [player_name.to_upper(), enemy_name.to_upper(), arena_name]


func set_status(text: String) -> void:
	status_label.text = text


func set_moves(melee_name: String, ranged_name: String) -> void:
	melee_button.label = melee_name.to_upper()
	melee_button.queue_redraw()
	aim_stick.label = ranged_name.to_upper()
	aim_stick.queue_redraw()


func announce(text: String) -> void:
	announcement.text = text
	if _announce_tween:
		_announce_tween.kill()
	announcement.modulate.a = 1.0
	_announce_tween = create_tween()
	_announce_tween.tween_interval(1.6)
	_announce_tween.tween_property(announcement, "modulate:a", 0.0, 0.5)


func show_result(victory: bool) -> void:
	move_stick.set_enabled(false)
	aim_stick.set_enabled(false)
	melee_button.set_enabled(false)
	result_title.text = "VICTORY!" if victory else "DEFEAT"
	result_title.modulate = Color(1.0, 0.85, 0.2) if victory else Color(1.0, 0.35, 0.3)
	result_hint.visible = false
	result.visible = true
	await get_tree().create_timer(1.2).timeout
	result_hint.visible = true
	_can_restart = true


func _input(event: InputEvent) -> void:
	if not _can_restart:
		return
	if (event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		_can_restart = false
		restart_requested.emit()
