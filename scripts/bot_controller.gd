class_name BotController
extends Node
## Simple AI for the parent Brawler: keeps at mid range, strafes, shoots with
## some lead and inaccuracy, and melees when the target gets close.

@export var reaction_time := 0.45
@export var aim_error_degrees := 10.0
## Seconds after the round starts before the bot begins acting.
@export var start_delay := 1.0

var target: Brawler

var _think_timer := 0.0
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _wall_flip_cooldown := 0.0

@onready var brawler: Brawler = get_parent()


func _physics_process(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		return
	if brawler.is_dead or target == null or target.is_dead:
		brawler.move_input = Vector2.ZERO
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


func _update_movement(delta: float, dir: Vector3, dist: float) -> void:
	_strafe_timer -= delta
	_wall_flip_cooldown -= delta
	if _strafe_timer <= 0.0:
		_strafe_sign = -1.0 if randf() < 0.5 else 1.0
		_strafe_timer = randf_range(0.8, 2.0)
	if brawler.is_on_wall() and _wall_flip_cooldown <= 0.0:
		_strafe_sign *= -1.0
		_wall_flip_cooldown = 0.6
		_strafe_timer = randf_range(0.8, 1.5)

	var strafe := Vector3(-dir.z, 0, dir.x) * _strafe_sign
	var data := brawler.data
	var preferred := data.projectile_range * 0.65
	var desired: Vector3
	if brawler.health < data.max_health * 0.3 and brawler.ammo < 1.0:
		desired = -dir + strafe * 0.6  # Low and empty: back off.
	elif brawler.melee_ready() and dist < data.melee_range * 2.0:
		desired = dir  # Close enough to lunge in for a melee hit.
	elif dist > preferred or not _has_line_of_sight():
		desired = dir + strafe * 0.4
	else:
		desired = strafe + dir * 0.15
	brawler.move_input = Vector2(desired.x, desired.z).normalized()


func _try_attack(dir: Vector3, dist: float) -> void:
	var data := brawler.data
	if dist <= data.melee_range + Brawler.BODY_RADIUS * 0.5 and brawler.melee_ready():
		brawler.melee(dir)
	elif dist <= data.projectile_range + 0.5 and brawler.can_shoot() and _has_line_of_sight():
		var lead := target.velocity * (dist / data.projectile_speed) * randf_range(0.2, 1.0)
		var aim := target.global_position + lead - brawler.global_position
		aim.y = 0.0
		aim = aim.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-aim_error_degrees, aim_error_degrees)))
		brawler.shoot(aim)


func _has_line_of_sight() -> bool:
	var space := brawler.get_world_3d().direct_space_state
	var from := brawler.global_position + Vector3.UP * 0.8
	var to := target.global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return space.intersect_ray(query).is_empty()
