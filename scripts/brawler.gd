class_name Brawler
extends CharacterBody3D
## A Pokémon brawler. Controllers (player or bot) drive it by setting
## move_input and calling use_ranged() / use_melee() / use_super().
## Call setup() before adding it to the tree.

signal died(victim: Brawler, killer: Brawler)
signal evolved(brawler: Brawler, from_name: String)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
## Horizontal hit radius used by melee checks (matches the collision capsule).
const BODY_RADIUS := 0.5
const SPRITE_HEIGHT := 0.85
## World units per sprite pixel: a 32px sprite is 1.6 units tall.
const PIXEL_SIZE := 0.05
const DOT_TICK := 0.5
## Physics layers that stop walking and teleports: world + water.
const MOVE_BLOCK_MASK := 1 | 8
## Walls and obstacles (what stops shots and line of sight).
const WALL_MASK := 1
## How often a stream deals damage, and how long its tank waits before refilling.
const STREAM_TICK := 0.15
const STREAM_REFILL_DELAY := 0.5

var species: SpeciesData
var level := 1
var team := 0
var is_player := false
var arena: Arena
var melee_move: MoveData
var ranged_move: MoveData

var max_health := 3000.0
var attack := 100.0
var defense := 100.0
var move_speed := 5.0
var health := 0.0
var ammo := 0.0
## 0..1; the SUPER is ready at 1. Filled by damage dealt with regular moves.
var super_charge := 0.0
## Desired movement in screen space (x = right, y = down), length 0..1.
var move_input := Vector2.ZERO
var facing := Vector3.FORWARD
var is_dead := false
var kills := 0
## KOs toward the next evolution. Kept when fainting, reset when evolving.
var evolve_kills := 0

var _melee_timer := 0.0
## Short lockout after any attack so attacks can't be chained instantly.
var _attack_lock := 0.0
var _regen_timer := 0.0
var _reveal_timer := 0.0
var _flash_timer := 0.0
var _bob_time := 0.0
var _last_attacker: Brawler

var _dot_time := 0.0
var _dot_dps := 0.0
var _dot_tick := 0.0
## "burn", "poison" or "leech" (leech heals whoever planted it).
var _dot_kind := ""
var _dot_source: Brawler
var _slow_time := 0.0
var _slow_amount := 0.0
var _blind_time := 0.0
## stat name -> { "amount": float, "time": float }
var _buffs := {}

var _dash_time := 0.0
var _dash_dir := Vector3.ZERO
var _dash_move: MoveData
var _dash_hit: Array[Brawler] = []

var _melee_material: StandardMaterial3D
var _melee_tween: Tween

## > 0 while a controller keeps calling stream() (it must call it every frame).
var _stream_hold := 0.0
var _stream_dir := Vector3.FORWARD
var _stream_tick := 0.0
var _stream_idle := 0.0
var _stream_fx: MeshInstance3D
var _stream_material: StandardMaterial3D

@onready var sprite: Sprite3D = $Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var team_ring: MeshInstance3D = $TeamRing
@onready var aim_pivot: Node3D = $AimPivot
@onready var aim_indicator: MeshInstance3D = $AimPivot/AimIndicator
@onready var melee_fx: MeshInstance3D = $MeleeFx


func setup(species_id: String, p_level: int, p_team: int, p_is_player: bool, p_arena: Arena,
		melee_id := "", ranged_id := "") -> void:
	species = GameData.get_species(species_id)
	level = clampi(p_level, 1, int(GameData.rule("level/max", 3)))
	team = p_team
	is_player = p_is_player
	arena = p_arena
	melee_move = _pick_move("melee", melee_id)
	ranged_move = _pick_move("ranged", ranged_id)


func _ready() -> void:
	add_to_group("brawlers")
	_build_static_visuals()
	_apply_species()
	_apply_loadout_visuals()
	health = max_health
	ammo = max_ammo()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	_tick_status(delta)
	_tick_stream(delta)

	if _dash_time > 0.0:
		_process_dash(delta)
		return

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length_squared() > 0.01:
		facing = dir.normalized()
	_move_with_wall_slide(dir * get_speed(), delta)


func _process(delta: float) -> void:
	_update_sprite(delta)


## move_and_slide, plus a fallback for when it gets stuck on a corner while
## moving diagonally: try each axis of the input on its own so the brawler
## keeps sliding along the wall in the direction that's still open.
func _move_with_wall_slide(desired: Vector3, delta: float) -> void:
	velocity = desired
	var start := global_position
	move_and_slide()
	var expected := desired.length() * delta
	if expected < 0.0001 or global_position.distance_to(start) > expected * 0.3:
		return
	var axes := [Vector3(desired.x, 0, 0), Vector3(0, 0, desired.z)]
	if absf(desired.z) > absf(desired.x):
		axes.reverse()
	for axis: Vector3 in axes:
		if axis.length() < desired.length() * 0.2:
			continue
		var before := global_position
		velocity = axis
		move_and_slide()
		if global_position.distance_to(before) > axis.length() * delta * 0.3:
			return


# --- Stats -----------------------------------------------------------------

func get_attack() -> float:
	return attack * (1.0 + _buff("attack"))


func get_defense() -> float:
	return defense * (1.0 + _buff("defense"))


func get_speed() -> float:
	var slow := 1.0 - _slow_amount if _slow_time > 0.0 else 1.0
	return move_speed * (1.0 + _buff("speed")) * slow


func _buff(stat: String) -> float:
	var b: Dictionary = _buffs.get(stat, {})
	return float(b.get("amount", 0.0)) if float(b.get("time", 0.0)) > 0.0 else 0.0


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var healed := minf(amount, max_health - health)
	health += healed
	if healed >= 1.0:
		_spawn_floating_text("+%d" % roundi(healed), Color(0.5, 1.0, 0.5), 56)


# --- Loadout & species -----------------------------------------------------

## Moves the player can choose from for a slot at the current level.
func available_moves(slot: String) -> Array[MoveData]:
	return species.moves_for(slot, level)


func _pick_move(slot: String, move_id: String) -> MoveData:
	if move_id != "":
		for move in available_moves(slot):
			if move.id == move_id:
				return move
		push_warning("%s can't use '%s' at level %d; using default" % [species.display_name, move_id, level])
	return species.default_move(slot, level)


func _apply_species() -> void:
	var bonus := 1.0 + float(GameData.rule("level/stat_bonus_per_level", 0.05)) * (level - 1)
	max_health = species.hp * bonus
	attack = species.attack * bonus
	defense = species.defense * bonus
	move_speed = species.speed * float(GameData.rule("speed_to_meters", 0.05))
	sprite.texture = species.sprite
	sprite.pixel_size = PIXEL_SIZE * species.sprite_scale


## Evolve to the next stage (after enough KOs). Returns false at final stage.
func evolve() -> bool:
	if species.evolves_to == "":
		return false
	var next: SpeciesData = GameData.get_species(species.evolves_to)
	if next == null:
		return false
	var from_name := species.display_name
	var health_ratio := health / max_health
	species = next
	evolve_kills = 0
	_apply_species()
	health = max_health if GameData.rule("evolution/heal_on_evolve", true) else max_health * health_ratio
	var tween := create_tween()
	sprite.scale = Vector3.ONE * 0.3
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.25, 0.2)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.15)
	evolved.emit(self, from_name)
	return true


func can_evolve() -> bool:
	return species.evolves_to != ""


func register_kill() -> void:
	kills += 1
	if species.evolves_to == "":
		return
	evolve_kills += 1
	if evolve_kills >= int(GameData.rule("evolution/kills_to_evolve", 3)):
		evolve()


func respawn(spawn_position: Vector3) -> void:
	if GameData.rule("evolution/devolve_on_death", true) and species.evolves_from != "":
		var previous: SpeciesData = GameData.get_species(species.evolves_from)
		if previous:
			species = previous
	_apply_species()
	is_dead = false
	health = max_health
	ammo = max_ammo()
	_stream_hold = 0.0
	position = spawn_position
	velocity = Vector3.ZERO
	collision_layer = 2
	_melee_timer = 0.0
	_attack_lock = 0.0
	_dash_time = 0.0
	_clear_status()
	_buffs.clear()
	_last_attacker = null
	sprite.scale = Vector3.ONE
	shadow.scale = Vector3.ONE


# --- Attacks ---------------------------------------------------------------

## Ammo bars for projectiles; for streams, the tank (0..1).
func max_ammo() -> float:
	return 1.0 if ranged_move.kind == "stream" else float(ranged_move.ammo)


func can_shoot() -> bool:
	if is_dead or _dash_time > 0.0:
		return false
	if ranged_move.kind == "stream":
		return is_streaming() or (ammo > 0.1 and _attack_lock <= 0.0)
	return ammo >= 1.0 and _attack_lock <= 0.0


func is_streaming() -> bool:
	return _stream_hold > 0.0


## Keep a stream move firing toward `direction`. Call every physics frame
## while the trigger is held; it stops by itself when calls stop.
func stream(direction: Vector3) -> bool:
	direction.y = 0.0
	if ranged_move.kind != "stream" or direction.length_squared() < 0.0001 or not can_shoot():
		return false
	_stream_dir = direction.normalized()
	facing = _stream_dir
	if not is_streaming():
		_stream_tick = 0.0
	_stream_hold = 0.12
	_regen_timer = 0.0
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	return true


func use_ranged(direction: Vector3) -> bool:
	if ranged_move.kind == "stream":
		return stream(direction)
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or not can_shoot():
		return false
	direction = direction.normalized()
	ammo -= 1.0
	_on_attack(direction, ranged_move)
	_fire_volley(ranged_move, direction)
	return true


func melee_ready() -> bool:
	return not is_dead and _melee_timer <= 0.0 and _dash_time <= 0.0 and _attack_lock <= 0.0


## 0 when melee is ready, 1 right after using it.
func melee_cooldown_ratio() -> float:
	return _melee_timer / melee_move.cooldown


func use_melee(direction: Vector3) -> bool:
	if not melee_ready():
		return false
	direction = _flat_direction(direction)
	_melee_timer = melee_move.cooldown
	_on_attack(direction, melee_move)
	if melee_move.kind == "dash":
		_start_dash(melee_move, direction)
	else:
		_melee_swing(melee_move, direction)
	return true


func super_ready() -> bool:
	return not is_dead and super_charge >= 1.0 and _dash_time <= 0.0 and _attack_lock <= 0.0


func add_super_charge(damage_dealt: float) -> void:
	if species.super_move:
		super_charge = minf(1.0, super_charge + damage_dealt / species.super_move.charge_damage())


## `distance` is where area supers land (clamped to their range); < 0 = max range.
func use_super(direction: Vector3, distance := -1.0) -> bool:
	if not super_ready():
		return false
	var move := species.super_move
	direction = _flat_direction(direction)
	super_charge = 0.0
	_on_attack(direction, move)
	_spawn_floating_text(move.display_name.to_upper() + "!", Color(1, 0.9, 0.3), 72, 2.6)
	match move.kind:
		"projectile":
			_fire_volley(move, direction)
		"melee":
			_melee_swing(move, direction)
		"dash":
			_start_dash(move, direction)
		"area":
			var reach := move.reach if distance < 0.0 else minf(distance, move.reach)
			_area_strike(move, global_position + direction * reach)
	_apply_support(move, direction)
	return true


## True if the super hits enemies (vs. pure heals / buffs), for the bot AI.
func super_is_offensive() -> bool:
	var move := species.super_move
	return move != null and (move.kind != "self" or not move.blind.is_empty())


func _flat_direction(direction: Vector3) -> Vector3:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = facing
	return direction.normalized()


func _melee_swing(move: MoveData, direction: Vector3) -> void:
	_show_melee_fx(direction, move)
	for other in _enemies_in_cone(direction, move.reach, move.arc):
		other.take_hit(self, move)


## Enemies within `reach` and inside a cone of `arc` degrees, not behind walls.
func _enemies_in_cone(direction: Vector3, reach: float, arc: float) -> Array[Brawler]:
	var result: Array[Brawler] = []
	var half_arc := deg_to_rad(arc) * 0.5
	for other in enemies():
		var to := other.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > reach + BODY_RADIUS:
			continue
		# Widen the cone by the target's body so grazing hits count.
		var allowance := asin(minf(1.0, BODY_RADIUS / maxf(dist, BODY_RADIUS)))
		if dist > 0.01 and direction.angle_to(to / dist) > half_arc + allowance:
			continue
		if not has_line_of_sight_to(other):
			continue
		result.append(other)
	return result


func _start_dash(move: MoveData, direction: Vector3) -> void:
	_dash_move = move
	_dash_dir = direction
	_dash_time = move.dash_distance / move.dash_speed
	_dash_hit.clear()


func _fire_volley(move: MoveData, direction: Vector3) -> void:
	for burst in move.burst_count:
		if burst > 0:
			await get_tree().create_timer(move.burst_interval, false, true).timeout
			if is_dead:
				return
		for i in move.count:
			var angle := 0.0
			if move.count > 1:
				angle = lerpf(-move.spread * 0.5, move.spread * 0.5, float(i) / (move.count - 1))
			elif move.spread > 0.0:
				angle = randf_range(-move.spread * 0.5, move.spread * 0.5)
			_spawn_projectile(move, direction.rotated(Vector3.UP, deg_to_rad(angle)))


func _spawn_projectile(move: MoveData, direction: Vector3) -> void:
	var chest := global_position + Vector3(0, 0.8, 0)
	var spawn := chest + direction * 0.6
	# Standing against a wall: the shot hits the wall instead of starting past it.
	var query := PhysicsRayQueryParameters3D.create(chest, spawn + direction * move.radius, WALL_MASK)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(self, move, direction)
	get_parent().add_child(projectile)
	projectile.global_position = spawn


## Hits every enemy inside a circle, optionally after a delay (Future Sight).
func _area_strike(move: MoveData, center: Vector3) -> void:
	center.y = 0.0
	var parent := get_parent()
	var fx := _area_fx(parent, center, move)
	if move.area_delay > 0.0:
		await get_tree().create_timer(move.area_delay, false, true).timeout
	if not is_inside_tree() or not is_instance_valid(fx):
		return
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other == null or other.team == team or other.is_dead:
			continue
		var offset := other.global_position - center
		offset.y = 0.0
		if offset.length() <= move.area_radius + BODY_RADIUS and Brawler.clear_between(self, center, other.global_position):
			other.take_hit(self, move)
	var mat := fx.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.75
	var tween := fx.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(fx.queue_free)


## Heals, buffs, teleports, blinding and cleansing attached to a super.
func _apply_support(move: MoveData, direction: Vector3) -> void:
	if move.cleanse:
		_clear_status()
	if move.blink > 0.0:
		_blink(direction, move.blink)
	if move.heal > 0.0:
		heal(max_health * move.heal)
	var allies: Array[Brawler] = []
	if move.support_radius > 0.0:
		allies = allies_within(move.support_radius)
	if move.team_heal > 0.0:
		for ally: Brawler in allies:
			ally.heal(ally.max_health * move.team_heal)
	if not move.buff.is_empty():
		apply_buff(move.buff)
		if move.buff.get("allies", false):
			for ally: Brawler in allies:
				ally.apply_buff(move.buff)
	if not move.blind.is_empty():
		var radius := float(move.blind.get("radius", 8.0))
		for other in enemies():
			if other.global_position.distance_to(global_position) <= radius and has_line_of_sight_to(other):
				other.apply_blind(float(move.blind.get("duration", 3.0)))
		_flash_fx(radius)


func _blink(direction: Vector3, distance: float) -> void:
	var from := global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance, MOVE_BLOCK_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var travel := distance
	if not hit.is_empty():
		travel = maxf(0.0, from.distance_to(hit["position"]) - BODY_RADIUS - 0.1)
	global_position += direction * travel


func apply_buff(buff: Dictionary) -> void:
	var duration := float(buff.get("duration", 4.0))
	for stat in ["attack", "defense", "speed"]:
		if buff.has(stat):
			_buffs[stat] = { "amount": float(buff[stat]), "time": duration }


func apply_blind(duration: float) -> void:
	if not is_dead:
		_blind_time = maxf(_blind_time, duration)


func is_blind() -> bool:
	return _blind_time > 0.0


func _process_dash(delta: float) -> void:
	_dash_time -= delta
	velocity = _dash_dir * _dash_move.dash_speed
	move_and_slide()
	for other in enemies():
		if other in _dash_hit:
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		if to.length() <= BODY_RADIUS * 2.0 + 0.3:
			_dash_hit.append(other)
			other.take_hit(self, _dash_move)
			if not _dash_move.dash_pierce:
				_dash_time = 0.0  # Stop on the first hit.
	if is_on_wall():
		_dash_time = 0.0


func _on_attack(direction: Vector3, move: MoveData) -> void:
	_attack_lock = move.attack_delay()
	_regen_timer = 0.0
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	facing = direction


## Alive brawlers on other teams.
func enemies() -> Array[Brawler]:
	var result: Array[Brawler] = []
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other and other != self and other.team != team and not other.is_dead:
			result.append(other)
	return result


## Alive teammates (not including self) within `radius`.
func allies_within(radius: float) -> Array[Brawler]:
	var result: Array[Brawler] = []
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other and other != self and other.team == team and not other.is_dead \
				and other.global_position.distance_to(global_position) <= radius:
			result.append(other)
	return result


## Whether this brawler can currently see `other` (blindness, tall grass).
func can_see(other: Brawler) -> bool:
	return not is_blind() and not other.is_dead and not other.is_hidden_from(team)


## Nearest enemy this brawler can see.
func find_nearest_enemy(max_range: float = INF) -> Brawler:
	var best: Brawler = null
	var best_dist := max_range
	for other in enemies():
		if not can_see(other):
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best = other
			best_dist = dist
	return best


func has_line_of_sight_to(other: Brawler) -> bool:
	return Brawler.clear_between(self, global_position, other.global_position)


## No wall between two ground points (checked at chest height).
static func clear_between(node: Node3D, a: Vector3, b: Vector3) -> bool:
	var from := Vector3(a.x, 0.8, a.z)
	var to := Vector3(b.x, 0.8, b.z)
	if from.distance_to(to) < 0.01:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, to, WALL_MASK)
	return node.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## How far you can see/shoot from here toward `direction` before a wall.
func clear_distance(direction: Vector3, max_distance: float) -> float:
	var from := global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * max_distance, WALL_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return max_distance if hit.is_empty() else from.distance_to(hit["position"])


# --- Damage & status -------------------------------------------------------

## Hit by a move: applies the damage formula, type matchups and side effects.
## Regular moves charge the attacker's super; draining moves heal the attacker.
func take_hit(attacker: Brawler, move: MoveData, multiplier := 1.0) -> void:
	if is_dead:
		return
	var result: Dictionary = GameData.calc_damage(move, attacker, self, multiplier)
	var amount: float = minf(result["amount"], health)
	take_damage(result["amount"], attacker, result["effectiveness"], result["crit"])
	if is_instance_valid(attacker):
		if move.slot != "super":
			attacker.add_super_charge(amount)
		if move.drain > 0.0:
			attacker.heal(amount * move.drain)
	if not is_dead:
		_apply_effect(move.effect, attacker)


func take_damage(amount: float, source: Brawler = null, effectiveness := 1.0, crit := false) -> void:
	if is_dead:
		return
	if source:
		_last_attacker = source
	health = maxf(0.0, health - amount)
	_regen_timer = 0.0
	_reveal_timer = float(GameData.rule("tall_grass/reveal_time_after_attack", 1.0))
	_flash_timer = 0.12
	_spawn_damage_number(amount, effectiveness, crit)
	if health <= 0.0:
		_die()


func status_text() -> String:
	var parts: Array[String] = []
	if _blind_time > 0.0:
		parts.append("BLIND")
	if _dot_time > 0.0:
		parts.append({ "burn": "BRN", "poison": "PSN", "leech": "SEED" }.get(_dot_kind, "DOT"))
	if _slow_time > 0.0:
		parts.append("PAR")
	for stat in ["attack", "defense", "speed"]:
		if _buff(stat) > 0.0:
			parts.append("+" + stat.substr(0, 3).to_upper())
	return " ".join(parts)


func _apply_effect(effect: Dictionary, source: Brawler) -> void:
	if effect.is_empty() or randf() >= float(effect.get("chance", 1.0)):
		return
	var kind := str(effect.get("type", ""))
	match kind:
		"burn", "poison", "leech":
			_dot_kind = kind
			_dot_time = float(effect.get("duration", 3.0))
			_dot_dps = float(effect.get("dps", 100.0))
			_dot_source = source
		"slow":
			_slow_time = float(effect.get("duration", 1.0))
			_slow_amount = clampf(float(effect.get("amount", 0.4)), 0.0, 0.9)


func _clear_status() -> void:
	_dot_time = 0.0
	_slow_time = 0.0
	_blind_time = 0.0


func _tick_timers(delta: float) -> void:
	_melee_timer = maxf(0.0, _melee_timer - delta)
	_attack_lock = maxf(0.0, _attack_lock - delta)
	_reveal_timer = maxf(0.0, _reveal_timer - delta)
	_blind_time = maxf(0.0, _blind_time - delta)
	for stat: String in _buffs:
		_buffs[stat]["time"] = float(_buffs[stat]["time"]) - delta
	if ranged_move.kind == "stream":
		if not is_streaming() and _stream_idle >= STREAM_REFILL_DELAY:
			ammo = minf(1.0, ammo + delta / ranged_move.reload)
	elif ammo < ranged_move.ammo:
		ammo = minf(ranged_move.ammo, ammo + delta / ranged_move.reload)
	_regen_timer += delta
	if _regen_timer >= float(GameData.rule("regen_delay", 3.0)) and health < max_health:
		health = minf(max_health, health + max_health * float(GameData.rule("regen_rate", 0.13)) * delta)


func _tick_status(delta: float) -> void:
	_slow_time = maxf(0.0, _slow_time - delta)
	if _dot_time <= 0.0:
		_dot_tick = 0.0
		return
	_dot_time -= delta
	_dot_tick += delta
	if _dot_tick >= DOT_TICK:
		_dot_tick -= DOT_TICK
		var amount := minf(_dot_dps * DOT_TICK, health)
		var source := _dot_source if is_instance_valid(_dot_source) else null
		take_damage(_dot_dps * DOT_TICK, source)
		if _dot_kind == "leech" and source:
			source.heal(amount)


func _tick_stream(delta: float) -> void:
	if not is_streaming():
		_stream_idle += delta
		if _stream_fx:
			_stream_fx.visible = false
		return
	var move := ranged_move
	_stream_hold -= delta
	_stream_idle = 0.0
	_attack_lock = maxf(_attack_lock, 0.2)
	ammo = maxf(0.0, ammo - delta / move.tank)
	_stream_tick -= delta
	if _stream_tick <= 0.0:
		_stream_tick += STREAM_TICK
		for other in _enemies_in_cone(_stream_dir, move.reach, move.arc):
			other.take_hit(self, move, STREAM_TICK)
	if ammo <= 0.0:
		_stream_hold = 0.0
	# Visual: a flickering cone, cut short by walls.
	_stream_fx.visible = true
	_stream_fx.rotation.y = atan2(-_stream_dir.x, -_stream_dir.z)
	var length := clear_distance(_stream_dir, move.reach) / move.reach
	_stream_fx.scale = Vector3(length, 1, length)
	_stream_material.albedo_color.a = randf_range(0.35, 0.6)


func _die() -> void:
	is_dead = true
	_stream_hold = 0.0
	velocity = Vector3.ZERO
	_dash_time = 0.0
	set_deferred("collision_layer", 0)
	hide_aim()
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector3(1.4, 0.05, 1.0), 0.35)
	tween.tween_property(shadow, "scale", Vector3.ZERO, 0.35)
	died.emit(self, _last_attacker)


# --- Tall grass & visibility -----------------------------------------------

func is_in_grass() -> bool:
	return arena != null and arena.is_tall_grass(global_position)


## True when `viewer_team` can't see this brawler: it's in tall grass, hasn't
## attacked or been hit recently, and no viewer-team brawler is close by.
func is_hidden_from(viewer_team: int) -> bool:
	if viewer_team == team or is_dead or _reveal_timer > 0.0 or not is_in_grass():
		return false
	var reveal := float(GameData.rule("tall_grass/reveal_distance", 2.5))
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other and other.team == viewer_team and not other.is_dead \
				and other.global_position.distance_to(global_position) <= reveal:
			return false
	return true


## Whether the person playing can see this brawler on screen.
func visible_to_local_player() -> bool:
	if team == GameData.local_team:
		return true
	var viewer: Brawler = GameData.local_player
	if is_instance_valid(viewer) and viewer.is_blind():
		return false
	return not is_hidden_from(GameData.local_team)


# --- Aim indicator ---------------------------------------------------------

func show_aim(direction: Vector3) -> void:
	if is_dead or direction.length_squared() < 0.0001:
		hide_aim()
		return
	direction = Vector3(direction.x, 0, direction.z).normalized()
	aim_pivot.rotation.y = atan2(-direction.x, -direction.z)
	aim_indicator.visible = true
	# Shorten the preview where a wall would stop the attack.
	var reach := ranged_move.reach + (0.6 if ranged_move.kind == "projectile" else 0.0)
	var clip := clampf(clear_distance(direction, reach) / reach, 0.05, 1.0)
	if aim_indicator.mesh is PlaneMesh:
		aim_indicator.scale = Vector3(1, 1, clip)
		aim_indicator.position.z = -(ranged_move.reach * clip) * 0.5 - 0.6
	else:
		aim_indicator.scale = Vector3(clip, 1, clip)
	var mat := aim_indicator.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.45 if can_shoot() else 0.15


func hide_aim() -> void:
	aim_indicator.visible = false


# --- Visuals ---------------------------------------------------------------

func _build_static_visuals() -> void:
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.5
	shadow_mesh.bottom_radius = 0.5
	shadow_mesh.height = 0.02
	shadow.mesh = shadow_mesh
	shadow.material_override = _flat_material(Color(0, 0, 0, 0.35))
	shadow.position.y = 0.02

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.72
	team_ring.mesh = ring_mesh
	team_ring.scale = Vector3(1, 0.1, 1)
	team_ring.position.y = 0.04
	var ring_color := Color(1.0, 0.25, 0.25, 0.9)
	if is_player:
		ring_color = Color(0.35, 1.0, 0.45, 0.95)
	elif team == GameData.local_team:
		ring_color = Color(0.25, 0.6, 1.0, 0.9)
	team_ring.material_override = _flat_material(ring_color)

	_melee_material = _flat_material(Color(1, 1, 1, 0.0))
	melee_fx.material_override = _melee_material
	melee_fx.position.y = 0.08
	melee_fx.visible = false
	aim_indicator.material_override = _flat_material(Color(1, 1, 1, 0.45))
	aim_indicator.visible = false


## Rebuild the aim preview (and stream cone) to match the equipped ranged move.
func _apply_loadout_visuals() -> void:
	var r := ranged_move
	if r.kind == "stream":
		var cone := _build_fan_mesh(r.reach, deg_to_rad(r.arc))
		aim_indicator.mesh = cone
		aim_indicator.position = Vector3(0, 0.05, 0)
		_stream_fx = MeshInstance3D.new()
		_stream_fx.mesh = cone
		_stream_material = _flat_material(Color(GameData.type_color(r.type).lightened(0.3), 0.5))
		_stream_fx.material_override = _stream_material
		_stream_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stream_fx.position.y = 0.3
		_stream_fx.visible = false
		add_child(_stream_fx)
	elif r.count > 1 or r.spread > 0.0:
		aim_indicator.mesh = _build_fan_mesh(r.reach + 0.6, deg_to_rad(maxf(r.spread, 8.0)))
		aim_indicator.position = Vector3(0, 0.05, 0)
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(maxf(0.6, r.radius * 2.0), r.reach)
		aim_indicator.mesh = plane
		aim_indicator.position = Vector3(0, 0.05, -r.reach * 0.5 - 0.6)


func _update_sprite(delta: float) -> void:
	var hidden := not visible_to_local_player()
	sprite.visible = not hidden
	shadow.visible = not hidden
	team_ring.visible = not hidden and not is_dead
	if is_dead:
		return

	var moving := velocity.length_squared() > 0.1
	if moving:
		_bob_time += delta * 12.0
		sprite.position.y = SPRITE_HEIGHT + absf(sin(_bob_time)) * 0.12
	else:
		_bob_time = 0.0
		sprite.position.y = lerpf(sprite.position.y, SPRITE_HEIGHT, 0.3)
	if absf(facing.x) > 0.2:
		sprite.flip_h = facing.x < 0.0

	_flash_timer = maxf(0.0, _flash_timer - delta)
	var tint := Color.WHITE
	if _flash_timer > 0.0:
		tint = Color(1, 0.45, 0.45)
	elif _dot_time > 0.0:
		tint = { "burn": Color(1, 0.75, 0.55), "poison": Color(0.85, 0.65, 1), "leech": Color(0.7, 1, 0.6) }.get(_dot_kind, Color.WHITE)
	elif _slow_time > 0.0:
		tint = Color(1, 1, 0.6)
	elif _buff("defense") > 0.0:
		tint = Color(0.75, 0.9, 1.0)
	# Your own team stays visible in grass, just faded.
	tint.a = 0.55 if is_in_grass() and team == GameData.local_team else 1.0
	sprite.modulate = tint


func _show_melee_fx(direction: Vector3, move: MoveData) -> void:
	melee_fx.mesh = _build_fan_mesh(move.reach + BODY_RADIUS, deg_to_rad(move.arc))
	melee_fx.rotation.y = atan2(-direction.x, -direction.z)
	melee_fx.visible = true
	if _melee_tween:
		_melee_tween.kill()
	_melee_material.albedo_color = Color(GameData.type_color(move.type).lightened(0.4), 0.6)
	_melee_tween = create_tween()
	_melee_tween.tween_property(_melee_material, "albedo_color:a", 0.0, 0.2)
	_melee_tween.tween_callback(func() -> void: melee_fx.visible = false)


## Flat disc marking an area attack; returned so the caller can fade it.
func _area_fx(parent: Node, center: Vector3, move: MoveData) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = move.area_radius
	disc.bottom_radius = move.area_radius
	disc.height = 0.04
	var fx := MeshInstance3D.new()
	fx.mesh = disc
	fx.material_override = _flat_material(Color(GameData.type_color(move.type), 0.3))
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fx)
	fx.global_position = center + Vector3(0, 0.06, 0)
	return fx


func _flash_fx(radius: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var fx := MeshInstance3D.new()
	fx.mesh = sphere
	var mat := _flat_material(Color(1, 1, 0.85, 0.55))
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.scale = Vector3.ONE * 0.1
	var tween := fx.create_tween().set_parallel()
	tween.tween_property(fx, "scale", Vector3.ONE, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(fx.queue_free)


func _spawn_damage_number(amount: float, effectiveness: float, crit: bool) -> void:
	var text := str(roundi(amount))
	var color := Color.WHITE
	var size := 64
	if effectiveness > 1.01:
		text += "!"
		color = Color(1.0, 0.6, 0.15)
		size = 84
	elif effectiveness < 0.99:
		color = Color(0.75, 0.75, 0.75)
		size = 48
	if crit:
		text = "CRIT " + text
	_spawn_floating_text(text, color, size)


func _spawn_floating_text(text: String, color: Color, size: int, height := 2.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = size
	label.outline_size = 16
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_modulate = Color(0.15, 0.05, 0.05)
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(randf_range(-0.3, 0.3), height, 0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat


static func _build_fan_mesh(radius: float, arc: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	for i in segments:
		var a0 := -arc * 0.5 + arc * float(i) / segments
		var a1 := -arc * 0.5 + arc * float(i + 1) / segments
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * radius)
	return st.commit()
