class_name PlayerController
extends Node
## Drives the parent Brawler from the on-screen sticks / melee / super buttons.
## Keyboard fallback for desktop testing: WASD move, F shoot (hold for streams),
## Space melee, E super.

## How far a tap on MELEE looks for a target to auto-aim at.
const MELEE_AUTO_AIM_RANGE := 4.0
## A tap that can't fire yet (attack delay, reloading) is retried for this long.
const INPUT_BUFFER := 0.35
## A tap on the aim stick with a stream move fires it for this long.
const AUTO_STREAM_TIME := 0.7

var move_stick: VirtualJoystick
var aim_stick: VirtualJoystick
var melee_button: TouchButton
var super_button: TouchButton

var _buffered := ""
var _buffer_time := 0.0
var _auto_stream_time := 0.0
var _aim_flash_time := 0.0
var _aim_flash_dir := Vector3.ZERO

@onready var brawler: Brawler = get_parent()


func _ready() -> void:
	aim_stick.released.connect(_on_aim_released)
	melee_button.pressed.connect(func() -> void: _try("melee"))
	super_button.pressed.connect(func() -> void: _try("super"))


func _physics_process(delta: float) -> void:
	var move := move_stick.output
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if keys != Vector2.ZERO:
		move = keys.normalized()
	brawler.move_input = move

	var streaming_move := brawler.ranged_move.kind == "stream"
	if aim_stick.output != Vector2.ZERO:
		var dir := _to_world(aim_stick.output)
		brawler.show_aim(dir)
		if streaming_move:
			brawler.stream(dir)  # Streams fire while the stick is held.
		_auto_stream_time = 0.0
	elif _aim_flash_time > 0.0:
		_aim_flash_time -= delta
		brawler.show_aim(_aim_flash_dir)
	else:
		brawler.hide_aim()

	if streaming_move and (_auto_stream_time > 0.0 or Input.is_physical_key_pressed(KEY_F)):
		_auto_stream_time -= delta
		brawler.stream(_auto_aim(brawler.ranged_move))

	if _buffer_time > 0.0:
		_buffer_time -= delta
		if _perform(_buffered):
			_buffer_time = 0.0

	melee_button.set_cooldown(brawler.melee_cooldown_ratio())
	super_button.set_charge(brawler.super_charge)
	super_button.label = brawler.species.super_move.display_name.to_upper()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F:
			if brawler.ranged_move.kind != "stream":
				_try("ranged")
		KEY_SPACE:
			_try("melee")
		KEY_E:
			_try("super")


func _on_aim_released(output: Vector2, was_tap: bool) -> void:
	if brawler.ranged_move.kind == "stream":
		if was_tap:
			_auto_stream_time = AUTO_STREAM_TIME
		return
	if output != Vector2.ZERO:
		brawler.use_ranged(_to_world(output))
	elif was_tap:
		_try("ranged")
	# Otherwise the player dragged back to the centre: cancel the shot.


## Do an auto-aimed action now, or keep retrying it briefly if it isn't ready
## (so a tap during the attack delay still fires instead of being ignored).
func _try(action: String) -> void:
	if not _perform(action):
		_buffered = action
		_buffer_time = INPUT_BUFFER


func _perform(action: String) -> bool:
	match action:
		"ranged":
			var dir := _auto_aim(brawler.ranged_move)
			if brawler.use_ranged(dir):
				_aim_flash_dir = dir
				_aim_flash_time = 0.25
				return true
		"melee":
			return _do_melee()
		"super":
			return _do_super()
	return false


## Direction toward the best visible target for `move`: the nearest enemy in
## range with a clear shot, else the nearest visible enemy. Leads moving targets.
func _auto_aim(move: MoveData) -> Vector3:
	var target := _auto_target(move.effective_reach())
	if target == null:
		return brawler.facing
	var to := target.global_position - brawler.global_position
	if move.kind == "projectile":
		var travel := Vector2(to.x, to.z).length() / maxf(1.0, move.speed)
		to += target.velocity * travel * 0.8
	return to


func _auto_target(reach: float) -> Brawler:
	var best: Brawler = null
	var best_dist := INF
	for enemy in brawler.enemies():
		if not brawler.can_see(enemy):
			continue
		var dist := brawler.global_position.distance_to(enemy.global_position)
		# Strongly prefer targets we can actually hit from here.
		if dist > reach * 1.15 or not brawler.has_line_of_sight_to(enemy):
			dist += 100.0
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _do_melee() -> bool:
	var dir := brawler.facing
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
	else:
		var reach := maxf(MELEE_AUTO_AIM_RANGE, brawler.melee_move.effective_reach())
		var target := brawler.find_nearest_enemy(reach)
		if target:
			dir = target.global_position - brawler.global_position
	return brawler.use_melee(dir)


## Aimed with the right stick if it's held, otherwise at the best visible enemy.
func _do_super() -> bool:
	var dir := brawler.facing
	var distance := -1.0
	var move := brawler.species.super_move
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
		distance = aim_stick.output.length() * move.reach
	else:
		var target := _auto_target(move.effective_reach())
		if target:
			dir = target.global_position - brawler.global_position
			distance = Vector2(dir.x, dir.z).length()
			if move.blink > 0.0:
				dir = -dir  # Teleport away from danger by default.
	return brawler.use_super(dir, distance)


## The camera never rotates around Y, so screen right = +X and screen down = +Z.
static func _to_world(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y)
