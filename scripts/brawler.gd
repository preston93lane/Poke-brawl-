class_name Brawler
extends CharacterBody3D
## A Pokémon brawler. Controllers (player or bot) drive it by setting
## move_input and calling use_ranged() / use_melee().
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
var _dot_kind := ""
var _dot_source: Brawler
var _slow_time := 0.0
var _slow_amount := 0.0

var _dash_time := 0.0
var _dash_dir := Vector3.ZERO
var _dash_move: MoveData
var _dash_hit: Array[Brawler] = []

var _melee_material: StandardMaterial3D
var _melee_tween: Tween

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
	ammo = ranged_move.ammo


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_tick_timers(delta)
	_tick_status(delta)

	if _dash_time > 0.0:
		_process_dash(delta)
		return

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var slow := 1.0 - _slow_amount if _slow_time > 0.0 else 1.0
	velocity = dir * move_speed * slow
	if dir.length_squared() > 0.01:
		facing = dir.normalized()
	move_and_slide()


func _process(delta: float) -> void:
	_update_sprite(delta)


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


## Evolve to the next stage (called after a KO streak). Returns false at final stage.
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


func register_kill() -> void:
	kills += 1
	if species.evolves_to == "":
		return
	evolve_kills += 1
	if evolve_kills >= int(GameData.rule("evolution/kills_to_evolve", 3)):
		evolve()


func can_evolve() -> bool:
	return species.evolves_to != ""


func respawn(spawn_position: Vector3) -> void:
	if GameData.rule("evolution/devolve_on_death", true) and species.evolves_from != "":
		var previous: SpeciesData = GameData.get_species(species.evolves_from)
		if previous:
			species = previous
	_apply_species()
	is_dead = false
	health = max_health
	ammo = ranged_move.ammo
	position = spawn_position
	velocity = Vector3.ZERO
	collision_layer = 2
	_melee_timer = 0.0
	_attack_lock = 0.0
	_dash_time = 0.0
	_dot_time = 0.0
	_slow_time = 0.0
	_last_attacker = null
	sprite.scale = Vector3.ONE
	shadow.scale = Vector3.ONE


# --- Attacks ---------------------------------------------------------------

func can_shoot() -> bool:
	return not is_dead and ammo >= 1.0 and _dash_time <= 0.0 and _attack_lock <= 0.0


func use_ranged(direction: Vector3) -> bool:
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
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = facing
	direction = direction.normalized()
	_melee_timer = melee_move.cooldown
	_on_attack(direction, melee_move)

	if melee_move.kind == "dash":
		_dash_move = melee_move
		_dash_dir = direction
		_dash_time = melee_move.dash_distance / melee_move.dash_speed
		_dash_hit.clear()
		return true

	_show_melee_fx(direction)
	var half_arc := deg_to_rad(melee_move.arc) * 0.5
	for other in enemies():
		var to := other.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > melee_move.reach + BODY_RADIUS:
			continue
		if dist > 0.01 and direction.angle_to(to / dist) > half_arc:
			continue
		other.take_hit(self, melee_move)
	return true


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
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(self, move, direction)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 0.8, 0) + direction * 0.6


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


## Nearest enemy this brawler's team can see.
func find_nearest_enemy(max_range: float = INF) -> Brawler:
	var best: Brawler = null
	var best_dist := max_range
	for other in enemies():
		if other.is_hidden_from(team):
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best = other
			best_dist = dist
	return best


# --- Damage & status -------------------------------------------------------

## Hit by a move: applies the damage formula, type matchups and side effects.
func take_hit(attacker: Brawler, move: MoveData, multiplier := 1.0) -> void:
	if is_dead:
		return
	var result: Dictionary = GameData.calc_damage(move, attacker, self, multiplier)
	take_damage(result["amount"], attacker, result["effectiveness"], result["crit"])
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
	if _dot_time > 0.0:
		return "BRN" if _dot_kind == "burn" else "PSN"
	if _slow_time > 0.0:
		return "PAR"
	return ""


func _apply_effect(effect: Dictionary, source: Brawler) -> void:
	if effect.is_empty() or randf() >= float(effect.get("chance", 1.0)):
		return
	var kind := str(effect.get("type", ""))
	match kind:
		"burn", "poison":
			_dot_kind = kind
			_dot_time = float(effect.get("duration", 3.0))
			_dot_dps = float(effect.get("dps", 100.0))
			_dot_source = source
		"slow":
			_slow_time = float(effect.get("duration", 1.0))
			_slow_amount = clampf(float(effect.get("amount", 0.4)), 0.0, 0.9)


func _tick_timers(delta: float) -> void:
	_melee_timer = maxf(0.0, _melee_timer - delta)
	_attack_lock = maxf(0.0, _attack_lock - delta)
	_reveal_timer = maxf(0.0, _reveal_timer - delta)
	if ammo < ranged_move.ammo:
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
		take_damage(_dot_dps * DOT_TICK, _dot_source)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	_dash_time = 0.0
	set_deferred("collision_layer", 0)
	hide_aim()
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector3(1.4, 0.05, 1.0), 0.35)
	tween.tween_property(shadow, "scale", Vector3.ZERO, 0.35)
	died.emit(self, _last_attacker)


# --- Tall grass ------------------------------------------------------------

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


# --- Aim indicator ---------------------------------------------------------

func show_aim(direction: Vector3) -> void:
	if is_dead or direction.length_squared() < 0.0001:
		hide_aim()
		return
	aim_pivot.rotation.y = atan2(-direction.x, -direction.z)
	aim_indicator.visible = true
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
	var ring_color := Color(0.25, 0.6, 1.0, 0.9) if team == GameData.local_team else Color(1.0, 0.25, 0.25, 0.9)
	team_ring.material_override = _flat_material(ring_color)

	_melee_material = _flat_material(Color(1, 1, 1, 0.0))
	melee_fx.material_override = _melee_material
	melee_fx.position.y = 0.08
	melee_fx.visible = false
	aim_indicator.material_override = _flat_material(Color(1, 1, 1, 0.45))
	aim_indicator.visible = false


## Rebuild the aim preview and melee swipe to match the equipped moves.
func _apply_loadout_visuals() -> void:
	var r := ranged_move
	if r.count > 1 or r.spread > 0.0:
		aim_indicator.mesh = _build_fan_mesh(r.reach + 0.6, deg_to_rad(maxf(r.spread, 8.0)))
		aim_indicator.position = Vector3(0, 0.05, 0)
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(maxf(0.6, r.radius * 2.0), r.reach)
		aim_indicator.mesh = plane
		aim_indicator.position = Vector3(0, 0.05, -r.reach * 0.5 - 0.6)
	if melee_move.kind == "melee":
		melee_fx.mesh = _build_fan_mesh(melee_move.reach + BODY_RADIUS, deg_to_rad(melee_move.arc))


func _update_sprite(delta: float) -> void:
	var hidden := is_hidden_from(GameData.local_team)
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
		tint = Color(1, 0.75, 0.55) if _dot_kind == "burn" else Color(0.85, 0.65, 1)
	elif _slow_time > 0.0:
		tint = Color(1, 1, 0.6)
	# Your own team stays visible in grass, just faded.
	tint.a = 0.55 if is_in_grass() and team == GameData.local_team else 1.0
	sprite.modulate = tint


func _show_melee_fx(direction: Vector3) -> void:
	melee_fx.rotation.y = atan2(-direction.x, -direction.z)
	melee_fx.visible = true
	if _melee_tween:
		_melee_tween.kill()
	_melee_material.albedo_color.a = 0.6
	_melee_tween = create_tween()
	_melee_tween.tween_property(_melee_material, "albedo_color:a", 0.0, 0.2)
	_melee_tween.tween_callback(func() -> void: melee_fx.visible = false)


func _spawn_damage_number(amount: float, effectiveness: float, crit: bool) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.outline_size = 16
	label.pixel_size = 0.008
	label.outline_modulate = Color(0.25, 0.05, 0.05)
	if effectiveness > 1.01:
		label.text += "!"
		label.modulate = Color(1.0, 0.6, 0.15)
		label.font_size = 84
	elif effectiveness < 0.99:
		label.modulate = Color(0.75, 0.75, 0.75)
		label.font_size = 48
	if crit:
		label.text = "CRIT " + label.text
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.0, 0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.6).set_delay(0.2)
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
