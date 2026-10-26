class_name Hud
extends CanvasLayer

signal restart_requested

var _can_restart := false

@onready var move_stick: VirtualJoystick = $MoveStick
@onready var aim_stick: VirtualJoystick = $AimStick
@onready var melee_button: TouchButton = $MeleeButton
@onready var matchup_label: Label = $Matchup
@onready var result: Control = $Result
@onready var result_title: Label = $Result/Title
@onready var result_hint: Label = $Result/Hint


func _ready() -> void:
	result.visible = false


func set_matchup(player_name: String, enemy_name: String) -> void:
	matchup_label.text = "%s  vs  %s" % [player_name.to_upper(), enemy_name.to_upper()]


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
