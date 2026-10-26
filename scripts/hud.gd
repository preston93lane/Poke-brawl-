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


func _ready() -> void:
	result.visible = false
	announcement.modulate.a = 0.0


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
