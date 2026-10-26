class_name PlayerController
extends Node
## Drives the parent Brawler from the on-screen sticks / melee button.
## Keyboard fallback for desktop testing: WASD move, F shoot, Space melee.

## How far a tap on MELEE looks for a target to auto-aim at.
const MELEE_AUTO_AIM_RANGE := 4.0

var move_stick: VirtualJoystick
var aim_stick: VirtualJoystick
var melee_button: TouchButton

@onready var brawler: Brawler = get_parent()


func _ready() -> void:
	aim_stick.released.connect(_on_aim_released)
	melee_button.pressed.connect(_do_melee)


func _physics_process(_delta: float) -> void:
	var move := move_stick.output
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if keys != Vector2.ZERO:
		move = keys.normalized()
	brawler.move_input = move

	if aim_stick.output != Vector2.ZERO:
		brawler.show_aim(_to_world(aim_stick.output))
	else:
		brawler.hide_aim()
	melee_button.set_cooldown(brawler.melee_cooldown_ratio())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F:
			_auto_shoot()
		KEY_SPACE:
			_do_melee()


func _on_aim_released(output: Vector2, was_tap: bool) -> void:
	if output != Vector2.ZERO:
		brawler.use_ranged(_to_world(output))
	elif was_tap:
		_auto_shoot()
	# Otherwise the player dragged back to the centre: cancel the shot.


## Fire at where the nearest visible enemy is standing (any distance).
func _auto_shoot() -> void:
	var target := brawler.find_nearest_enemy()
	var dir := brawler.facing
	if target:
		dir = target.global_position - brawler.global_position
	brawler.use_ranged(dir)


func _do_melee() -> void:
	var dir := brawler.facing
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
	else:
		var reach := maxf(MELEE_AUTO_AIM_RANGE, brawler.melee_move.effective_reach())
		var target := brawler.find_nearest_enemy(reach)
		if target:
			dir = target.global_position - brawler.global_position
	brawler.use_melee(dir)


## The camera never rotates around Y, so screen right = +X and screen down = +Z.
static func _to_world(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y)
