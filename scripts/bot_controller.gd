class_name BotController
extends Node
## Simple AI for the parent Brawler: keeps at mid range, strafes, shoots with
## some lead and inaccuracy, melees up close, loses track of you in tall
## grass, and (in King of the Hill) heads for the zone.

@export var reaction_time := 0.45
@export var aim_error_degrees := 10.0
## Seconds after the round starts before the bot begins acting.
@export var start_delay := 1.0

var target: Brawler
var objective := Vector3.ZERO
var has_objective := false

var _think_timer := 0.0
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _wall_flip_cooldown := 0.0
var _last_seen := Vector3.ZERO
var _has_last_seen := false

@onready var brawler: Brawler = get_parent()


func _physics_process(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		return
	if brawler.is_dead:
		brawler.move_input = Vector2.ZERO
		_has_last_seen = false
		return

	var can_see := target != null and not target.is_dead and not target.is_hidden_from(brawler.team)
	if can_see:
		_last_seen = target.global_position
		_has_last_seen = true
	else:
		_search(delta)
		return

	var to := target.global_position - brawler.global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to / dist if dist > 0.01 else Vector3.FORWARD
	_update_movement(delta, dir, dist)

	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = reaction_time * randf_range(0.7, 1.3)
		_try_attack(dir, dist)


## No target in sight: check where we last saw it, else go to the objective.
func _search(delta: float) -> void:
	var goal := objective if has_objective else Vector3.ZERO
	if _has_last_seen:
		goal = _last_seen
		if brawler.global_position.distance_to(_last_seen) < 1.0:
			_has_last_seen = false
	var to := goal - brawler.global_position
	to.y = 0.0
	if to.length() < 0.8:
		brawler.move_input = Vector2.ZERO
		return
	_update_strafe(delta)
	var dir := to.normalized()
	var strafe := Vector3(-dir.z, 0, dir.x) * _strafe_sign
	var desired := dir + strafe * (0.6 if brawler.is_on_wall() else 0.1)
	brawler.move_input = Vector2(desired.x, desired.z).normalized()


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


func _update_movement(delta: float, dir: Vector3, dist: float) -> void:
	_update_strafe(delta)
	var strafe := Vector3(-dir.z, 0, dir.x) * _strafe_sign
	var preferred := brawler.ranged_move.reach * 0.65
	var desired: Vector3
	if brawler.health < brawler.max_health * 0.3 and brawler.ammo < 1.0:
		desired = -dir + strafe * 0.6  # Low and empty: back off.
	elif brawler.melee_ready() and dist < brawler.melee_move.effective_reach() * 1.6:
		desired = dir  # Close enough to go in for a melee hit.
	elif has_objective and not _in_objective():
		desired = (objective - brawler.global_position).normalized() + strafe * 0.3
	elif dist > preferred or not _has_line_of_sight():
		desired = dir + strafe * 0.4
	else:
		desired = strafe + dir * 0.15
	brawler.move_input = Vector2(desired.x, desired.z).normalized()


func _try_attack(dir: Vector3, dist: float) -> void:
	var melee := brawler.melee_move
	var ranged := brawler.ranged_move
	var melee_reach := melee.effective_reach() + (0.0 if melee.kind == "dash" else Brawler.BODY_RADIUS * 0.5)
	if dist <= melee_reach and brawler.melee_ready() and _has_line_of_sight():
		brawler.use_melee(dir)
	elif dist <= ranged.effective_reach() + 0.5 and brawler.can_shoot() and _has_line_of_sight():
		var lead := target.velocity * (dist / ranged.speed) * randf_range(0.2, 1.0)
		var aim := target.global_position + lead - brawler.global_position
		aim.y = 0.0
		aim = aim.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-aim_error_degrees, aim_error_degrees)))
		brawler.use_ranged(aim)


func _in_objective() -> bool:
	return brawler.arena != null and brawler.arena.is_in_zone(brawler.global_position)


func _has_line_of_sight() -> bool:
	var space := brawler.get_world_3d().direct_space_state
	var from := brawler.global_position + Vector3.UP * 0.8
	var to := target.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return space.intersect_ray(query).is_empty()
