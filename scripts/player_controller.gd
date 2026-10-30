class_name PlayerController
extends Node
## Drives the parent Brawler from the on-screen sticks and the gadget / super buttons.
## Keyboard fallback for desktop testing: WASD move, F attack (hold for streams),
## Space gadget, E super, Q HM.

## How much of a target's movement auto-aim leads (1 = perfect prediction).
const LEAD := 0.9
## Dragged shots within this many degrees of an enemy bend onto it.
const ASSIST_DEGREES := 11.0
## A tap that can't fire yet (attack delay, reloading) is retried for this long.
const INPUT_BUFFER := 0.35
## A tap on the aim stick with a stream attack fires it for this long.
const AUTO_STREAM_TIME := 0.7

var move_stick: VirtualJoystick
var aim_stick: VirtualJoystick
var gadget_button: TouchButton
var hm_button: TouchButton
var super_button: TouchButton
var z_button: TouchButton

var _buffered := ""
var _buffer_time := 0.0
var _auto_stream_time := 0.0
var _aim_flash_time := 0.0
var _aim_flash_dir := Vector3.ZERO

@onready var brawler: Brawler = get_parent()


func _ready() -> void:
	aim_stick.released.connect(_on_aim_released)
	gadget_button.pressed.connect(func() -> void: _try("gadget"))
	super_button.pressed.connect(func() -> void: _try("super"))
	super_button.aimable = true
	super_button.aim_released.connect(_on_super_aimed)
	if hm_button:
		hm_button.pressed.connect(func() -> void: _try("hm"))
	if z_button:
		z_button.pressed.connect(func() -> void: _try("zmove"))


func _physics_process(delta: float) -> void:
	var move := move_stick.output
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if keys != Vector2.ZERO:
		move = keys.normalized()
	brawler.move_input = move

	var streaming_move := _is_stream()
	if aim_stick.output != Vector2.ZERO:
		var dir := _to_world(aim_stick.output)
		brawler.show_aim(dir, aim_stick.output.length() * brawler.main_move.reach)
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
		brawler.stream(_auto_aim(brawler.main_move))

	if _buffer_time > 0.0:
		_buffer_time -= delta
		if _perform(_buffered):
			_buffer_time = 0.0

	gadget_button.set_cooldown(brawler.gadget_cooldown_ratio())
	gadget_button.uses = brawler.gadget_uses
	super_button.set_charge(brawler.super_charge)
	# Dragging the super button previews where it will land.
	if super_button.aim_output != Vector2.ZERO and brawler.current_super().kind != "self":
		brawler.show_super_aim(_to_world(super_button.aim_output), super_button.aim_output.length())
	else:
		brawler.hide_super_aim()
	super_button.label = brawler.current_super().display_name.to_upper()
	if hm_button and hm_button.visible:
		hm_button.set_cooldown(brawler.hm_cooldown_ratio())
	if z_button:
		z_button.visible = brawler.z_available()
		if z_button.visible:
			z_button.set_charge(brawler.z_charge)
			z_button.label = "Z-MOVE" if brawler.z_charge < 1.0 or brawler.super_charge >= 1.0 else "Z: NEED SUPER"


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F:
			if not _is_stream():
				_try("main")
		KEY_SPACE:
			_try("gadget")
		KEY_E:
			_try("super")
		KEY_Q:
			_try("hm")
		KEY_R:
			_try("zmove")


## Streams fire while held, except while carrying the Brawl Ball (then it's a kick).
func _is_stream() -> bool:
	return brawler.main_move.kind == "stream" and brawler.ball == null


func _on_aim_released(output: Vector2, was_tap: bool) -> void:
	if _is_stream():
		if was_tap:
			_auto_stream_time = AUTO_STREAM_TIME
		return
	if output != Vector2.ZERO:
		var dir := _assist(_to_world(output), brawler.main_move)
		brawler.use_main(dir, output.length() * brawler.main_move.reach)
	elif was_tap:
		_try("main")
	# Otherwise the player dragged back to the centre: cancel the shot.


## Do an auto-aimed action now, or keep retrying it briefly if it isn't ready
## (so a tap during the attack delay still fires instead of being ignored).
func _try(action: String) -> void:
	if not _perform(action):
		_buffered = action
		_buffer_time = INPUT_BUFFER


func _perform(action: String) -> bool:
	match action:
		"main":
			var aim := _auto_aim_with_distance(brawler.main_move)
			var dir: Vector3 = aim[0]
			if brawler.use_main(dir, aim[1]):
				_aim_flash_dir = dir
				_aim_flash_time = 0.25
				return true
		"gadget":
			return _do_gadget()
		"super":
			return _do_super()
		"hm":
			return _do_hm()
		"zmove":
			return _do_super(true)
	return false


## Direction toward the best visible target for `move`: the nearest enemy in
## range with a clear shot, else the nearest visible enemy. Leads moving targets.
func _auto_aim(move: MoveData) -> Vector3:
	return _auto_aim_with_distance(move)[0]


## [direction, distance to the (predicted) target or -1 when there's none].
func _auto_aim_with_distance(move: MoveData) -> Array:
	var target := _auto_target(move.effective_reach())
	if target == null:
		return [brawler.facing, -1.0]
	var to := _predict(target, move)
	return [to, to.length()]


## Offset from us to where `target` will be when `move` reaches it (solves the
## intercept a few times, since a further point takes longer to reach).
func _predict(target: Brawler, move: MoveData) -> Vector3:
	var to := target.global_position - brawler.global_position
	to.y = 0.0
	var speed := 0.0
	match move.kind:
		"projectile":
			speed = move.speed
		"dash":
			speed = move.dash_speed
	if speed <= 0.0:
		return to
	var aim := to
	var velocity := Vector3(target.velocity.x, 0, target.velocity.z)
	for i in 3:
		var t := aim.length() / speed + (0.05 if move.lob else 0.0)
		aim = to + velocity * t * LEAD
	if move.lob:
		aim = aim.limit_length(move.reach)
	return aim


## Aim assist: a dragged shot that's close to an enemy bends onto it.
func _assist(dir: Vector3, move: MoveData) -> Vector3:
	if not bool(GameData.setting("aim_assist", true)) or move.kind == "stream":
		return dir
	var best: Vector3 = dir
	var best_angle := deg_to_rad(ASSIST_DEGREES)
	for enemy in brawler.enemies():
		if not brawler.can_see(enemy):
			continue
		var to := enemy.global_position - brawler.global_position
		to.y = 0.0
		if to.length() > move.effective_reach() * 1.1:
			continue
		var angle := dir.angle_to(to)
		if angle < best_angle and (move.lob or brawler.has_line_of_sight_to(enemy)):
			best_angle = angle
			best = _predict(enemy, move)
	if best == dir:
		return dir
	return dir.normalized().slerp(best.normalized(), 0.75) * dir.length()


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


## Gadgets aim with the right stick if it's held; teleports go away from the nearest enemy.
func _do_gadget() -> bool:
	var move := brawler.gadget_move
	if move == null:
		return false
	var dir := brawler.facing
	var distance := -1.0
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
		distance = aim_stick.output.length() * move.reach
	elif move.blink > 0.0:
		var threat := brawler.find_nearest_enemy(10.0)
		if threat:
			dir = brawler.global_position - threat.global_position
	elif move.kind != "self":
		var target := _auto_target(move.effective_reach())
		if target:
			dir = _predict(target, move)
			distance = Vector2(dir.x, dir.z).length()
	return brawler.use_gadget(dir, distance)


## HMs aim with the right stick if it's held, else at the nearest enemy (Fly and
## Flash: the way you're facing / around you).
func _do_hm() -> bool:
	var dir := brawler.facing
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
	elif brawler.hm_id not in ["fly", "flash"]:
		var target := brawler.find_nearest_enemy(6.0)
		if target:
			dir = target.global_position - brawler.global_position
	return brawler.use_hm(dir)


## Released after dragging the super button: fire it that way, that far.
func _on_super_aimed(output: Vector2) -> void:
	var move := brawler.current_super()
	if move.kind == "self":
		_try("super")
		return
	var reach := move.dash_distance if move.kind == "dash" else move.reach
	brawler.use_super(_to_world(output), output.length() * reach)
	brawler.hide_super_aim()


## Aimed with the right stick if it's held, otherwise at the best visible enemy.
func _do_super(z := false) -> bool:
	var dir := brawler.facing
	var distance := -1.0
	var move := GameData.z_move(brawler.current_super()) if z else brawler.current_super()
	if aim_stick.output != Vector2.ZERO:
		dir = _to_world(aim_stick.output)
		distance = aim_stick.output.length() * move.reach
	else:
		var target := _auto_target(move.effective_reach())
		if target:
			dir = _predict(target, move)
			distance = Vector2(dir.x, dir.z).length()
			if move.blink > 0.0:
				dir = -dir  # Teleport away from danger by default.
	return brawler.use_zmove(dir, distance) if z else brawler.use_super(dir, distance)


## The camera never rotates around Y, so screen right = +X and screen down = +Z.
static func _to_world(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y)
