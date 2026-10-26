class_name BotController
extends Node
## AI for the parent Brawler, on either team. Picks a target (close, hurt, or
## weak to its moves), fights it at mid range with strafing, paths around
## walls when it can't see it, uses its super, and in King of the Hill
## heads for the zone.

@export var reaction_time := 0.45
@export var aim_error_degrees := 10.0
## Seconds after the round starts before the bot begins acting.
@export var start_delay := 1.0

var target: Brawler
var objective := Vector3.ZERO
var has_objective := false

var _think_timer := 0.0
var _retarget_timer := 0.0
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _wall_flip_cooldown := 0.0
var _last_seen := Vector3.ZERO
var _has_last_seen := false

var _path := PackedVector3Array()
var _path_goal := Vector3.ZERO
var _repath_timer := 0.0
var _stuck_check_timer := 0.0
var _stuck_from := Vector3.ZERO
var _unstick_timer := 0.0
var _unstick_dir := Vector2.ZERO

@onready var brawler: Brawler = get_parent()


func _physics_process(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		return
	if brawler.is_dead:
		brawler.move_input = Vector2.ZERO
		_has_last_seen = false
		_path.clear()
		return

	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		brawler.move_input = _unstick_dir
		return

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or target == null or not brawler.can_see(target):
		_retarget_timer = 0.5
		_pick_target()

	if target and brawler.can_see(target):
		_last_seen = target.global_position
		_has_last_seen = true
		var to := target.global_position - brawler.global_position
		to.y = 0.0
		var dist := to.length()
		var dir := to / dist if dist > 0.01 else Vector3.FORWARD
		if _has_line_of_sight(target.global_position):
			_fight(delta, dir, dist)
		else:
			_go_to(target.global_position, delta)
		_think_timer -= delta
		if _think_timer <= 0.0:
			_think_timer = reaction_time * randf_range(0.7, 1.3)
			_try_attack(dir, dist)
	else:
		_search(delta)
	_check_stuck(delta)


## Prefer close enemies, hurt enemies, and ones our ranged move is super effective on.
func _pick_target() -> void:
	var best: Brawler = null
	var best_score := INF
	for enemy in brawler.enemies():
		if not brawler.can_see(enemy):
			continue
		var score := brawler.global_position.distance_to(enemy.global_position)
		score -= (1.0 - enemy.health / enemy.max_health) * 4.0
		score -= (GameData.effectiveness(brawler.ranged_move.type, enemy.species.types) - 1.0) * 6.0
		if score < best_score:
			best_score = score
			best = enemy
	target = best


## Can't see anyone: check where we last saw them, else the zone, else head
## toward the closest enemy so bots never stand around.
func _search(delta: float) -> void:
	var goal := Vector3.ZERO
	if _has_last_seen:
		goal = _last_seen
		if _flat_distance(brawler.global_position, _last_seen) < 1.0:
			_has_last_seen = false
	elif has_objective and not _in_objective():
		goal = objective
	else:
		var nearest: Brawler = null
		for enemy in brawler.enemies():
			if nearest == null or brawler.global_position.distance_to(enemy.global_position) \
					< brawler.global_position.distance_to(nearest.global_position):
				nearest = enemy
		if nearest == null:
			brawler.move_input = Vector2.ZERO
			return
		goal = nearest.global_position
	_go_to(goal, delta)


func _fight(delta: float, dir: Vector3, dist: float) -> void:
	_update_strafe(delta)
	var strafe := Vector3(-dir.z, 0, dir.x) * _strafe_sign
	var preferred := brawler.ranged_move.reach * 0.7
	var desired: Vector3
	if brawler.health < brawler.max_health * 0.3 and brawler.ammo < 1.0:
		desired = -dir + strafe * 0.6  # Low and empty: back off.
	elif brawler.melee_ready() and dist < brawler.melee_move.effective_reach() * 1.6:
		desired = dir  # Close enough to go in for a melee hit.
	elif has_objective and not _in_objective():
		_go_to(objective, delta)
		return
	elif dist > preferred:
		desired = dir + strafe * 0.4
	else:
		desired = strafe + dir * 0.15
	_path.clear()
	brawler.move_input = Vector2(desired.x, desired.z).normalized()


## Follow a grid path to `goal`, skipping waypoints we can walk straight past.
func _go_to(goal: Vector3, delta: float) -> void:
	if brawler.arena == null:
		return
	_repath_timer -= delta
	if _path.is_empty() or _repath_timer <= 0.0 or _flat_distance(goal, _path_goal) > 1.5:
		_repath_timer = 0.5
		_path = brawler.arena.find_path(brawler.global_position, goal)
		_path_goal = goal
	var pos := brawler.global_position
	while not _path.is_empty() and _flat_distance(pos, _path[0]) < 0.45:
		_path.remove_at(0)
	while _path.size() > 1 and _clear_walk(pos, _path[1]):
		_path.remove_at(0)
	var next := _path[0] if not _path.is_empty() else goal
	var to := next - pos
	to.y = 0.0
	if to.length() < 0.3:
		brawler.move_input = Vector2.ZERO
		return
	brawler.move_input = Vector2(to.x, to.z).normalized()


## Barely moved for a while despite trying: repath and sidestep briefly.
func _check_stuck(delta: float) -> void:
	_stuck_check_timer -= delta
	if _stuck_check_timer > 0.0:
		return
	_stuck_check_timer = 0.7
	var moved := _flat_distance(brawler.global_position, _stuck_from)
	_stuck_from = brawler.global_position
	if brawler.move_input.length() > 0.5 and moved < 0.4:
		_path.clear()
		_unstick_dir = brawler.move_input.rotated(PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
		_unstick_timer = 0.35


func _update_strafe(delta: float) -> void:
	_strafe_timer -= delta
	_wall_flip_cooldown -= delta
	if _strafe_timer <= 0.0:
		_strafe_sign = -1.0 if randf() < 0.5 else 1.0
		_strafe_timer = randf_range(0.8, 2.0)
	if brawler.is_on_wall() and _wall_flip_cooldown <= 0.0:
		_strafe_sign *= -1.0
		_wall_flip_cooldown = 0.6
		_strafe_timer = randf_range(0.8, 1.5)


func _try_attack(dir: Vector3, dist: float) -> void:
	var line_of_sight := _has_line_of_sight(target.global_position)
	if brawler.super_ready() and _try_super(dir, dist, line_of_sight):
		return
	var melee := brawler.melee_move
	var ranged := brawler.ranged_move
	var melee_reach := melee.effective_reach() + (0.0 if melee.kind == "dash" else Brawler.BODY_RADIUS * 0.5)
	if dist <= melee_reach and brawler.melee_ready() and line_of_sight:
		brawler.use_melee(dir)
	elif dist <= ranged.effective_reach() + 0.5 and brawler.can_shoot() and line_of_sight:
		brawler.use_ranged(_lead_aim(ranged.speed, dist))


func _try_super(dir: Vector3, dist: float, line_of_sight: bool) -> bool:
	var move := brawler.species.super_move
	if brawler.super_is_offensive():
		if line_of_sight and dist <= move.effective_reach() + 0.5:
			var aim := dir if move.kind != "projectile" else _lead_aim(move.speed, dist)
			return brawler.use_super(aim, dist)
		return false
	# Heals, buffs and teleports: use when hurt, or right before a fight.
	if brawler.health < brawler.max_health * 0.55 or (move.blink <= 0.0 and dist < 6.0):
		return brawler.use_super(-dir if move.blink > 0.0 else dir)
	return false


func _lead_aim(projectile_speed: float, dist: float) -> Vector3:
	var lead := target.velocity * (dist / maxf(1.0, projectile_speed)) * randf_range(0.2, 1.0)
	var aim := target.global_position + lead - brawler.global_position
	aim.y = 0.0
	return aim.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-aim_error_degrees, aim_error_degrees)))


func _in_objective() -> bool:
	return brawler.arena != null and brawler.arena.is_in_zone(brawler.global_position)


func _has_line_of_sight(to_pos: Vector3) -> bool:
	var space := brawler.get_world_3d().direct_space_state
	var from := brawler.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, to_pos + Vector3.UP * 0.8, 1)
	return space.intersect_ray(query).is_empty()


## True if the bot's whole body width can walk straight from `from` to `to`
## (two rays at the capsule's edges, blocked by walls and water).
func _clear_walk(from: Vector3, to: Vector3) -> bool:
	var space := brawler.get_world_3d().direct_space_state
	var dir := to - from
	dir.y = 0.0
	if dir.length() < 0.01:
		return true
	var side := Vector3(-dir.z, 0, dir.x).normalized() * (Brawler.BODY_RADIUS - 0.05)
	for offset in [side, -side]:
		var a: Vector3 = from + offset + Vector3.UP * 0.5
		var query := PhysicsRayQueryParameters3D.create(a, a + dir, Brawler.MOVE_BLOCK_MASK)
		if not space.intersect_ray(query).is_empty():
			return false
	return true


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
