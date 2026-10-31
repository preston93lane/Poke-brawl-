class_name ChainBolt
extends Node3D
## A chaining shot after its first hit (Thunder Shock, Thunderbolt...), like
## Belle's: the spark sticks to the enemy it hit, crackling, then jumps to the
## nearest other enemy within the move's chain_range and flies over to it,
## hitting a little softer each time. Ends when it runs out of jumps or nobody
## else is in range.

## Seconds the spark clings to each target before jumping.
const STICK_TIME := 0.4
## How fast it flies between enemies (m/s).
const JUMP_SPEED := 13.0
const FALLOFF := 0.8

var shooter: Brawler
var move: MoveData
var team := 0

var _current: Brawler
var _next: Brawler
var _struck: Array[Brawler] = []
var _jumps_left := 0
var _mult := 1.0
var _stick := 0.0
var _spark: Sprite3D
var _trail: CPUParticles3D
var _anchor := Vector3.ZERO


## Starts the chain on `first`, which the shot has just hit.
static func start(p_shooter: Brawler, p_move: MoveData, first: Brawler) -> void:
	if p_move.chain <= 0 or not is_instance_valid(first) or first.get_parent() == null:
		return
	var bolt := ChainBolt.new()
	bolt.shooter = p_shooter
	bolt.move = p_move
	bolt.team = p_shooter.team
	bolt._current = first
	bolt._struck = [first]
	bolt._jumps_left = p_move.chain
	first.get_parent().add_child(bolt)
	bolt.global_position = first.global_position + Vector3(0, 0.9, 0)


func _ready() -> void:
	var look := MoveLook.of(move)
	_spark = Vfx.core_sprite(move.type, maxf(0.3, move.radius), look)
	if _spark:
		add_child(_spark)
	_trail = Vfx.trail(move.type, 0.25, look)
	_trail.emitting = false
	add_child(_trail)
	_stick = STICK_TIME


func _physics_process(delta: float) -> void:
	if not is_instance_valid(shooter) or shooter.is_dead:
		_end()
		return
	if _next == null:
		_cling(delta)
	else:
		_fly(delta)


## Crackling on the current target, then pick who to jump to.
func _cling(delta: float) -> void:
	if is_instance_valid(_current) and not _current.is_dead:
		_anchor = _current.global_position
	global_position = _anchor + Vector3(randf_range(-0.15, 0.15), 0.9 + randf_range(-0.1, 0.2), randf_range(-0.15, 0.15))
	if _spark:
		_spark.rotation.z = randf_range(-0.8, 0.8)
		_spark.flip_h = randf() < 0.5
	_stick -= delta
	if _stick > 0.0:
		return
	_next = _pick_next()
	if _next == null:
		_end()
		return
	_trail.emitting = true


func _pick_next() -> Brawler:
	var best: Brawler = null
	var best_dist := move.chain_range
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other == null or other.team == team or other.is_dead or other in _struck:
			continue
		var offset := other.global_position - _anchor
		offset.y = 0.0
		if offset.length() <= best_dist and Brawler.clear_between(self, _anchor, other.global_position):
			best_dist = offset.length()
			best = other
	return best


## Flying to the next target (it follows them if they move).
func _fly(delta: float) -> void:
	if not is_instance_valid(_next) or _next.is_dead:
		_next = null
		_end()
		return
	var goal := _next.global_position + Vector3(0, 0.9, 0)
	var to := goal - global_position
	var step := JUMP_SPEED * delta
	if to.length() > step:
		global_position += to.normalized() * step
		if _spark:
			_spark.rotation.z = randf_range(-0.6, 0.6)
		return
	# Arrived: hit, and cling to this one next.
	global_position = goal
	_mult *= FALLOFF
	_next.take_hit(shooter, move, _mult)
	Vfx.burst(get_parent(), goal, move.type, 10, 0.25, 3.0)
	_struck.append(_next)
	_current = _next
	_anchor = _next.global_position
	_next = null
	_trail.emitting = false
	_jumps_left -= 1
	if _jumps_left <= 0:
		_end()
		return
	_stick = STICK_TIME


func _end() -> void:
	set_physics_process(false)
	if get_parent():
		Vfx.burst(get_parent(), global_position, move.type, 5, 0.15, 2.0)
	if _spark:
		_spark.visible = false
	_trail.emitting = false
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_callback(queue_free)
