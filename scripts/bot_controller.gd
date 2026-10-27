class_name BotController
extends Node
## AI for the parent Brawler, on either team. Picks a target (close, hurt, or
## weak to its moves) and fights it the way its play style wants: close-range
## styles rush in, throwers lob over walls, snipers keep their distance. Paths
## around walls (and over water if it can swim), uses its gadget and super,
## and in King of the Hill heads for the zone.

## Difficulty presets: [reaction seconds, aim error degrees, how much they lead targets 0..1,
## how hard they strafe 0..1, seconds they stand still after attacking].
## Like Brawl Stars bots, easier bots move more predictably and plant their feet to shoot.
const DIFFICULTY := {
	"easy": [0.95, 26.0, 0.0, 0.35, 0.55],
	"normal": [0.7, 17.0, 0.35, 0.6, 0.35],
	"hard": [0.5, 9.0, 0.8, 0.95, 0.15],
}

@export var reaction_time := 0.7
@export var aim_error_degrees := 17.0
## 0 = aim where the target is, 1 = fully predict where it's going.
@export var lead_skill := 0.35
## Seconds after the round starts before the bot begins acting.
@export var start_delay := 1.0

var target: Brawler
var objective := Vector3.ZERO
var has_objective := false
## Stay within leash_radius of leash_center (raid bosses guard the middle). 0 = no leash.
var leash_center := Vector3.ZERO
var leash_radius := 0.0
## Brawl Ball / Rare Candy Rush / Showdown rules; asked what to do each frame.
var mode_logic: MatchMode

var _think_timer := 0.0
var _retarget_timer := 0.0
var _strafe_sign := 1.0
## 0..1: how fast the bot sidesteps while fighting.
var strafe_amount := 0.6
## Seconds the bot stands still after an attack.
var plant_time := 0.35
var _plant := 0.0
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
var _stream_time := 0.0
var _stream_aim := Vector3.FORWARD

@onready var brawler: Brawler = get_parent()


func set_difficulty(level: String) -> void:
	var preset: Array = DIFFICULTY.get(level, DIFFICULTY["normal"])
	reaction_time = preset[0]
	aim_error_degrees = preset[1]
	lead_skill = preset[2]
	strafe_amount = preset[3]
	plant_time = preset[4]


func _physics_process(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		return
	if brawler.is_dead:
		brawler.move_input = Vector2.ZERO
		_has_last_seen = false
		_path.clear()
		_stream_time = 0.0
		return

	if _stream_time > 0.0:
		_stream_time -= delta
		if not brawler.stream(_stream_aim):
			_stream_time = 0.0

	if _unstick_timer > 0.0:
		_unstick_timer -= delta
		brawler.move_input = _unstick_dir
		return

	if leash_radius > 0.0 and _flat_distance(brawler.global_position, leash_center) > leash_radius:
		_go_to(leash_center, delta)
		return

	if mode_logic and _follow_plan(mode_logic.plan_for(brawler), delta):
		_check_stuck(delta)
		return

	var item := _wanted_item()
	if item:
		_go_to(item.global_position, delta)
		_check_stuck(delta)
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
		var main := brawler.main_move
		var can_lob := main.lob and dist <= main.reach + 0.5
		if _has_line_of_sight(target.global_position) or can_lob:
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


## Carry out a mode plan (see MatchMode.plan_for). Returns false if there's nothing
## special to do, so the bot fights as usual.
func _follow_plan(plan: Dictionary, delta: float) -> bool:
	if plan.is_empty():
		return false
	if plan.has("kick"):
		brawler.use_main(plan["kick"])
		return true
	var forced: Brawler = plan.get("target") as Brawler
	if forced and not forced.is_dead and brawler.can_see(forced):
		target = forced
		_retarget_timer = 0.5
	if not plan.has("go"):
		return false
	var goal: Vector3 = plan["go"]
	if plan.has("shoot"):
		var point: Vector3 = plan["shoot"]
		var to := point - brawler.global_position
		to.y = 0.0
		var main := brawler.main_move
		if to.length() <= main.effective_reach() + 0.6 and brawler.can_shoot():
			_think_timer -= delta
			if _think_timer <= 0.0:
				_think_timer = reaction_time * 0.6
				if main.kind == "stream":
					_stream_aim = to
					_stream_time = 0.6
				else:
					brawler.use_main(to, to.length())
			if to.length() < 2.5 or not main.is_close_range():
				brawler.move_input = Vector2.ZERO
				return true
	_go_to(goal, delta)
	# Fight back on the way unless we're carrying the ball.
	if not plan.get("hold", false):
		_retarget_timer -= delta
		if _retarget_timer <= 0.0 or target == null or not brawler.can_see(target):
			_retarget_timer = 0.5
			_pick_target()
		if target and brawler.can_see(target):
			var to_target := target.global_position - brawler.global_position
			to_target.y = 0.0
			var dist := to_target.length()
			_think_timer -= delta
			if _think_timer <= 0.0 and dist < brawler.main_move.effective_reach() + 2.0:
				_think_timer = reaction_time * randf_range(0.7, 1.3)
				_try_attack(to_target / maxf(dist, 0.01), dist)
	return true


## A nearby item worth grabbing: potions when hurt, anything else when no enemy is close.
func _wanted_item() -> Node3D:
	if brawler.is_legendary:
		return null
	var hurt := brawler.health < brawler.max_health * 0.6
	var enemy_close := target != null and not target.is_dead \
			and brawler.global_position.distance_to(target.global_position) < 6.0
	var best: Node3D = null
	var best_dist := 9.0 if hurt else 6.0
	for node in get_tree().get_nodes_in_group("items"):
		var pickup := node as ItemPickup
		if pickup == null:
			continue
		var is_potion := pickup.item.has("heal")
		if (is_potion and not hurt) or (not is_potion and enemy_close):
			continue
		var dist := brawler.global_position.distance_to(pickup.global_position)
		if dist < best_dist:
			best_dist = dist
			best = pickup
	return best


## Prefer close enemies, hurt enemies, and ones our main attack is super effective on.
func _pick_target() -> void:
	var best: Brawler = null
	var best_score := INF
	for enemy in brawler.enemies():
		if not brawler.can_see(enemy):
			continue
		var score := brawler.global_position.distance_to(enemy.global_position)
		score -= (1.0 - enemy.health / enemy.max_health) * 4.0
		score -= (GameData.effectiveness(brawler.main_move.type, enemy.species.types) - 1.0) * 6.0
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


## Distance the bot likes to fight from with its main attack.
func preferred_range() -> float:
	var main := brawler.main_move
	match main.kind:
		"melee":
			return main.reach * 0.6
		"dash":
			return main.dash_distance * 0.7
		"stream":
			return main.reach * 0.75
	if main.distance_bonus > 1.0:
		return main.reach * 0.85  # Snipers hit hardest from far away.
	return main.reach * 0.7


func _fight(delta: float, dir: Vector3, dist: float) -> void:
	_update_strafe(delta)
	var strafe := Vector3(-dir.z, 0, dir.x) * _strafe_sign * strafe_amount
	_plant -= delta
	var heading_for_objective := has_objective and not _in_objective()
	if _plant > 0.0 and not brawler.main_move.is_close_range() and not heading_for_objective:
		brawler.move_input = Vector2.ZERO  # Standing still to shoot.
		return
	var preferred := preferred_range()
	var close_range := brawler.main_move.is_close_range()
	var desired: Vector3
	if brawler.health < brawler.max_health * 0.3 and not brawler.can_shoot():
		desired = -dir + strafe * 0.6  # Low and empty: back off.
	elif close_range and dist > preferred:
		desired = dir + strafe * 0.25  # Brawlers and assassins rush in.
	elif has_objective and not _in_objective():
		_go_to(objective, delta)
		return
	elif dist > preferred:
		desired = dir + strafe * 0.4
	else:
		desired = strafe + dir * 0.15
	_path.clear()
	# Not normalized: gentle strafing means slower sidesteps.
	brawler.move_input = Vector2(desired.x, desired.z).limit_length(1.0)


## Follow a grid path to `goal`, skipping waypoints we can walk straight past.
func _go_to(goal: Vector3, delta: float) -> void:
	if brawler.arena == null:
		return
	_repath_timer -= delta
	if _path.is_empty() or _repath_timer <= 0.0 or _flat_distance(goal, _path_goal) > 1.5:
		_repath_timer = 0.5
		_path = brawler.arena.find_path(brawler.global_position, goal, brawler.can_swim)
		_path_goal = goal
	var pos := brawler.global_position
	while not _path.is_empty() and _flat_distance(pos, _path[0]) < 0.35:
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
		_strafe_timer = randf_range(1.2, 2.6)
	if brawler.is_on_wall() and _wall_flip_cooldown <= 0.0:
		_strafe_sign *= -1.0
		_wall_flip_cooldown = 0.6
		_strafe_timer = randf_range(0.8, 1.5)


func _try_attack(dir: Vector3, dist: float) -> void:
	var line_of_sight := _has_line_of_sight(target.global_position)
	if brawler.super_ready() and _try_super(dir, dist, line_of_sight):
		return
	if brawler.gadget_ready() and _try_gadget(dir, dist):
		return
	var main := brawler.main_move
	if not brawler.can_shoot():
		return
	var ammo_before := brawler.ammo
	_attack_main(main, dir, dist, line_of_sight)
	if brawler.ammo < ammo_before or _stream_time > 0.0:
		_plant = plant_time  # Only after actually firing.


func _attack_main(main: MoveData, dir: Vector3, dist: float, line_of_sight: bool) -> void:
	match main.kind:
		"melee":
			if dist <= main.reach + Brawler.BODY_RADIUS * 0.6 and line_of_sight:
				brawler.use_main(dir)
		"dash":
			if dist <= main.dash_distance + Brawler.BODY_RADIUS and line_of_sight:
				brawler.use_main(_lead_aim(main.dash_speed, dist))
		"stream":
			if dist <= main.reach + 0.3 and line_of_sight and brawler.ammo > 0.3:
				_stream_aim = _lead_aim(99.0, dist)
				_stream_time = randf_range(0.5, 1.1)
		_:
			if main.lob:
				if dist <= main.reach + 0.5:
					var aim := _lead_aim(main.speed, dist)
					brawler.use_main(aim, dist + randf_range(-0.6, 0.6))
			elif dist <= main.effective_reach() + 0.5 and line_of_sight:
				brawler.use_main(_lead_aim(main.speed, dist))
			elif main.heal_allies > 0.0:
				_heal_shot()


## Healers with nobody to shoot top up a hurt teammate in range.
func _heal_shot() -> void:
	for ally in brawler.allies_within(brawler.main_move.reach):
		if ally.health < ally.max_health * 0.8 and _has_line_of_sight(ally.global_position):
			var to := ally.global_position - brawler.global_position
			brawler.use_main(Vector3(to.x, 0, to.z))
			return


## Gadgets: shields, heals and escapes when in trouble; speed to chase; smoke up close.
func _try_gadget(dir: Vector3, dist: float) -> bool:
	var move := brawler.species.gadget_move
	var hurt := brawler.health < brawler.max_health * 0.45
	if move.protect > 0.0:
		return dist < 4.0 and hurt and brawler.use_gadget(dir)
	if move.blink > 0.0:
		return dist < 3.5 and hurt and brawler.use_gadget(-dir)
	if move.heal > 0.0 or move.team_heal > 0.0:
		return brawler.health < brawler.max_health * 0.5 and brawler.use_gadget(dir)
	if not move.buff.is_empty():
		var chasing := brawler.main_move.is_close_range() and dist > preferred_range() + 1.5 and dist < 8.0
		return (chasing or hurt) and brawler.use_gadget(dir)
	if move.kind == "area":
		return dist <= move.area_radius + 0.5 and brawler.use_gadget(dir)
	return false


func _try_super(dir: Vector3, dist: float, line_of_sight: bool) -> bool:
	var move := brawler.species.super_move
	if brawler.super_is_offensive():
		var reach_ok := dist <= move.effective_reach() + 0.5
		if reach_ok and (line_of_sight or move.lob or move.kind == "area"):
			var aim := dir if move.kind != "projectile" else _lead_aim(move.speed, dist)
			return brawler.use_super(aim, dist)
		return false
	# Heals, buffs and teleports: use when hurt, or right before a fight.
	if brawler.health < brawler.max_health * 0.55 or (move.blink <= 0.0 and dist < 6.0):
		return brawler.use_super(-dir if move.blink > 0.0 else dir)
	return false


func _lead_aim(projectile_speed: float, dist: float) -> Vector3:
	var lead := target.velocity * (dist / maxf(1.0, projectile_speed)) * lead_skill * randf_range(0.0, 1.2)
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
	var side := Vector3(-dir.z, 0, dir.x).normalized() * (Brawler.COLLIDER_RADIUS + 0.04)
	for offset in [side, -side]:
		var a: Vector3 = from + offset + Vector3.UP * 0.5
		var query := PhysicsRayQueryParameters3D.create(a, a + dir, brawler.walk_mask())
		if not space.intersect_ray(query).is_empty():
			return false
	return true


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
