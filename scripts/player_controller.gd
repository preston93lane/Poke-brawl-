class_name PlayerController
extends Node
## Drives the parent Brawler from the on-screen sticks / melee button.
## Keyboard fallback for desktop testing: WASD move, F shoot, Space melee.

## How far the player auto-targets with a tap on the aim stick or melee.
const MELEE_AUTO_AIM_RANGE := 3.5

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
		brawler.shoot(_to_world(output))
	elif was_tap:
		_auto_shoot()
	# Otherwise the player dragged back to the centre: cancel the shot.


func _auto_shoot() -> void:
	var target := brawler.find_nearest_enemy(brawler.data.projectile_range + 1.0)
	var dir := brawler.facing
	if target:
		dir = target.global_position - brawler.global_position
	brawler.shoot(dir)


func _do_melee() -> void:
	var dir := brawler.facing
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
	else:
		var target := brawler.find_nearest_enemy(MELEE_AUTO_AIM_RANGE)
		if target:
			dir = target.global_position - brawler.global_position
	brawler.melee(dir)


## The camera never rotates around Y, so screen right = +X and screen down = +Z.
static func _to_world(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y)
