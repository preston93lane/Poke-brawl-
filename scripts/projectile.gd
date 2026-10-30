class_name Projectile
extends Area3D
## A shot fired by a Brawler. Depending on the move it flies straight, arcs over
## walls (lob), bounces off walls, comes back like a boomerang, homes in, chains
## between enemies, heals teammates it passes, explodes, or leaves a damaging zone.
##
## Collision is done by hand each physics step: a ray sweeps the path for walls
## (so fast shots can't skip through a wall between frames) and brawlers are
## checked by distance in small sub-steps.

const LINGER_ZONE := preload("res://scripts/linger_zone.gd")
## Homing shots look for targets this far ahead, within this cone (degrees).
const HOMING_RANGE := 7.0
const HOMING_CONE := 75.0

var shooter: Brawler
var move: MoveData
var team := 0
var direction := Vector3.FORWARD
## Lobbed shots land this far away (clamped to the move's range).
var lob_distance := -1.0
## Exploding shots aimed at a spot (Fire Blast) burst there instead of flying full range.
var aimed_distance := -1.0

var _travelled := 0.0
var _hit: Array[Brawler] = []
var _healed: Array[Brawler] = []
var _done := false
var _trail: CPUParticles3D
var _jitter := 0.0
var _bounces_left := 0
var _returning := false
var _lob_start := Vector3.ZERO
var _lob_height := 2.0
## Breakables this shot already smashed through (supers), ignored by later rays.
var _smashed: Array[RID] = []
var _core: Sprite3D
var _spin := false
var _vortex_spawned := false
var _look: Dictionary = {}
var _beam: MoveFx.Beam
var _halo: Sprite3D

@onready var mesh: MeshInstance3D = $Mesh
@onready var shape: CollisionShape3D = $CollisionShape3D


func setup(p_shooter: Brawler, p_move: MoveData, dir: Vector3, distance := -1.0) -> void:
	shooter = p_shooter
	move = p_move
	team = p_shooter.team
	direction = dir
	lob_distance = move.reach if distance < 0.0 else clampf(distance, 1.0, move.reach)
	if distance >= 0.0 and move.explode_radius > 0.0 and not move.lob:
		aimed_distance = clampf(distance, 1.0, move.reach)
	_bounces_left = move.bounces


func _ready() -> void:
	monitoring = false
	mesh.material_override = Vfx.core_material(move.type)
	var size := move.radius / 0.3
	mesh.scale = Vector3.ONE * size * (1.3 if move.lob else 0.8)
	# Shaped core from the move's look (fireball, bone, coin, note, orb...).
	_look = MoveLook.of(move)
	var orb := bool(_look.get("orb", false)) or bool(_look.get("beam", false))
	_core = Vfx.core_sprite(move.type, move.radius * (1.3 if move.lob else 1.0) * (1.35 if orb else 1.0), _look)
	if _core:
		mesh.visible = false
		add_child(_core)
		_spin = Vfx.style(move.type).get("spin", false) or _look.get("spin", false)
		if orb:
			# A soft glow around energy balls and beam heads.
			_halo = Vfx.core_sprite(move.type, move.radius * 2.4, { "shape": "orb", "colors": _look.get("colors", []) })
			_halo.modulate.a = 0.45
			add_child(_halo)
	_jitter = float(Vfx.style(move.type).get("jitter", 0.0))
	_trail = Vfx.trail(move.type, move.radius, _look)
	add_child(_trail)
	if _look.get("beam", false) and not move.lob and get_parent():
		_beam = MoveFx.Beam.new(get_parent(), global_position, MoveFx._color(_look, 0), maxf(0.12, move.radius * 0.7))
	# The scene's shape resource is shared between projectiles, so give each its own.
	var sphere := SphereShape3D.new()
	sphere.radius = move.radius
	shape.shape = sphere
	_lob_height = clampf(lob_distance * 0.3, 1.2, 3.0)


func _process(delta: float) -> void:
	if _jitter > 0.0:  # Electric shots crackle.
		mesh.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _jitter
	if _core:
		if _jitter > 0.0:  # Lightning flickers between poses.
			_core.position = mesh.position
			if randf() < 0.4:
				_core.rotation.z = randf_range(-0.6, 0.6)
				_core.flip_h = randf() < 0.5
		elif _spin:
			_core.rotation.z += delta * 9.0
	if _halo:
		_halo.scale = Vector3.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.02))
	if _beam:
		_beam.update(global_position)


func _physics_process(delta: float) -> void:
	if _done:
		return
	# Shots fizzle out when whoever fired them faints.
	if not is_instance_valid(shooter) or shooter.is_dead:
		Vfx.burst(get_parent(), global_position, move.type, 6, 0.15, 2.0)
		_done = true
		_retire()
		return
	if move.lob:
		_fly_lob(delta)
		return
	if move.homing > 0.0 and not _returning:
		_steer(delta)
	if _returning:
		_steer_home()
	var limit := move.reach * (2.5 if move.returns else 1.0)
	if aimed_distance > 0.0:
		limit = aimed_distance
	var remaining := minf(move.speed * delta, limit - _travelled)
	var space := get_world_3d().direct_space_state
	var sub_step := maxf(0.1, move.radius)
	while remaining > 0.0001 and not _done:
		var step := minf(sub_step, remaining)
		var from := global_position
		var to := from + direction * step
		if not _returning:
			var query := PhysicsRayQueryParameters3D.create(from, to + direction * move.radius, Brawler.WALL_MASK)
			query.exclude = _smashed
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var breakable := hit.get("collider") as Breakable
				if breakable and is_instance_valid(shooter) and move.explode_radius <= 0.0:
					var broke := breakable.take_attack(shooter, move, _distance_multiplier())
					if broke and move.slot == "super":
						_smashed.append(breakable.get_rid())  # Supers smash straight through.
						continue
				_hit_wall(hit)
				return
		global_position = to
		_travelled += step
		remaining -= step
		_check_brawlers()
		if move.returns and not _returning and _travelled >= move.reach:
			_turn_back()
		if _returning and is_instance_valid(shooter) and _flat(shooter.global_position - global_position).length() < 0.7:
			_finish(false)
			return
	if not _done and _travelled >= limit - 0.0001:
		_finish()


## Arc toward the landing point, ignoring walls and brawlers until it lands.
func _fly_lob(delta: float) -> void:
	if _travelled == 0.0:
		_lob_start = global_position
	_travelled = minf(lob_distance, _travelled + move.speed * delta)
	var t := _travelled / lob_distance
	var ground := _lob_start + direction * _travelled
	global_position = Vector3(ground.x, _lob_start.y + 4.0 * _lob_height * t * (1.0 - t), ground.z)
	if t >= 1.0:
		global_position.y = 0.3
		_land()


func _land() -> void:
	if move.explode_radius > 0.0 or move.linger <= 0.0:
		var radius := move.explode_radius if move.explode_radius > 0.0 else maxf(0.8, move.radius * 2.0)
		_explode(radius)
	else:
		Vfx.burst(get_parent(), global_position, move.type, 16, 0.4, 3.0)
	_finish(false)


func _hit_wall(hit: Dictionary) -> void:
	global_position = hit["position"] - direction * move.radius
	if _bounces_left > 0:
		_bounces_left -= 1
		var normal: Vector3 = hit.get("normal", -direction)
		normal.y = 0.0
		direction = direction.bounce(normal.normalized()) if normal.length() > 0.01 else -direction
		direction.y = 0.0
		direction = direction.normalized()
		_hit.clear()  # A ricochet can hit the same enemy again.
		Vfx.burst(get_parent(), global_position, move.type, 6, 0.15, 2.0)
		return
	if move.returns and not _returning:
		_turn_back()
		return
	_finish()  # Hit a wall or obstacle.


func _turn_back() -> void:
	_returning = true
	_hit.clear()
	_steer_home()


func _steer_home() -> void:
	if not is_instance_valid(shooter) or shooter.is_dead:
		_finish(false)
		return
	var to := _flat(shooter.global_position - global_position)
	if to.length() > 0.01:
		direction = to.normalized()


## Turn toward the nearest visible enemy ahead, at `homing` radians per second.
func _steer(delta: float) -> void:
	var best: Brawler = null
	var best_dist := HOMING_RANGE
	for node in get_tree().get_nodes_in_group("brawlers"):
		var target := node as Brawler
		if target == null or target.team == team or target.is_dead or target in _hit \
				or target.is_hidden_from(team):
			continue
		var to := _flat(target.global_position - global_position)
		var dist := to.length()
		if dist < best_dist and dist > 0.01 and rad_to_deg(direction.angle_to(to / dist)) < HOMING_CONE:
			best_dist = dist
			best = target
	if best == null:
		return
	var want := _flat(best.global_position - global_position).normalized()
	var angle := direction.signed_angle_to(want, Vector3.UP)
	direction = direction.rotated(Vector3.UP, clampf(angle, -move.homing * delta, move.homing * delta)).normalized()


func _check_brawlers() -> void:
	for node in get_tree().get_nodes_in_group("brawlers"):
		var target := node as Brawler
		if target == null or target.is_dead or target == shooter:
			continue
		var offset := _flat(target.global_position - global_position)
		if offset.length() > move.radius + Brawler.BODY_RADIUS:
			continue
		if target.team == team:
			if move.heal_allies > 0.0 and target not in _healed and is_instance_valid(shooter):
				_healed.append(target)
				target.heal(move.heal_allies * shooter.power_bonus(), shooter)
			continue
		if target in _hit:
			continue
		_hit.append(target)
		if move.explode_radius > 0.0:
			_finish()
			return
		if is_instance_valid(shooter):
			target.take_hit(shooter, move, _distance_multiplier() * move.upfront_share())
			_knock(target)
			if move.chain > 0:
				_chain_from(target)
			if not _vortex_spawned:
				_vortex_spawned = true
				shooter.spawn_vortex(move, target.global_position, 2.2)
		if not move.pierce and not move.returns:
			_finish()
			return


## Snipers: more damage the further the shot has flown.
func _distance_multiplier() -> float:
	if move.distance_bonus <= 1.0:
		return 1.0
	return lerpf(1.0, move.distance_bonus, clampf(_travelled / move.reach, 0.0, 1.0))


func _knock(target: Brawler) -> void:
	if move.knockback > 0.0:
		target.knock_from(target.global_position - direction, move.knockback)
	elif move.knockback < 0.0 and is_instance_valid(shooter):
		target.knock_from(shooter.global_position, move.knockback)


## Lightning jumps to the next-nearest enemies, a little weaker each time.
func _chain_from(first: Brawler) -> void:
	var current := first
	var struck: Array[Brawler] = [first]
	var mult := 1.0
	for i in move.chain:
		var best: Brawler = null
		var best_dist := move.chain_range
		for node in get_tree().get_nodes_in_group("brawlers"):
			var other := node as Brawler
			if other == null or other.team == team or other.is_dead or other in struck:
				continue
			var dist := _flat(other.global_position - current.global_position).length()
			if dist <= best_dist and Brawler.clear_between(self, current.global_position, other.global_position):
				best_dist = dist
				best = other
		if best == null:
			return
		mult *= 0.8
		struck.append(best)
		_hit.append(best)
		_zap(current.global_position, best.global_position)
		best.take_hit(shooter, move, mult)
		current = best


func _zap(a: Vector3, b: Vector3) -> void:
	var to := b + Vector3(0, 0.9, 0)
	Vfx.lightning(get_parent(), a + Vector3(0, 0.9, 0), to, move.type)
	Vfx.burst(get_parent(), to, move.type, 8, 0.2, 2.5)


func _finish(effects := true) -> void:
	if _done:
		return
	_done = true
	if effects:
		if move.explode_radius > 0.0:
			_explode(move.explode_radius)
		else:
			Vfx.burst(get_parent(), global_position, move.type, 6, 0.2, 2.5, _look)
	if _beam:
		_beam.fade()
		_beam = null
	if move.linger > 0.0 and is_instance_valid(shooter):
		var zone: Node3D = LINGER_ZONE.new()
		zone.setup(shooter, move, Vector3(global_position.x, 0.0, global_position.z))
		get_parent().add_child(zone)
	_retire()


func _exit_tree() -> void:
	if _beam:
		_beam.fade()
		_beam = null


## Spent: hide the shot but stay until its trail has faded where it is. (Moving the
## trail to another parent would restart it, and Godot 4.3 draws a restarted
## emitter's particles as black blobs.)
func _retire() -> void:
	mesh.visible = false
	if _core:
		_core.visible = false
	if _halo:
		_halo.visible = false
	set_process(false)
	if _trail == null:
		queue_free()
		return
	_trail.emitting = false
	get_tree().create_timer(_trail.lifetime + 0.2, false).timeout.connect(queue_free)


func _explode(radius: float) -> void:
	if is_instance_valid(shooter) and move.power > 0.0:
		for node in get_tree().get_nodes_in_group("brawlers"):
			var target := node as Brawler
			if target == null or target.team == team or target.is_dead:
				continue
			var offset := _flat(target.global_position - global_position)
			if offset.length() <= radius + Brawler.BODY_RADIUS \
					and Brawler.clear_between(self, global_position, target.global_position):
				target.take_hit(shooter, move, _distance_multiplier() * move.upfront_share())
				_knock(target)
		Breakable.hit_area(get_tree(), global_position, radius, shooter, move, _distance_multiplier())
		if not _vortex_spawned:
			_vortex_spawned = true
			shooter.spawn_vortex(move, global_position, radius)
	_spawn_explosion_fx(radius)
	if move.slot == "super" or radius >= 1.8:
		MoveFx.area(get_parent(), global_position, radius, move)
	Vfx.burst(get_parent(), global_position, move.type, 18, radius * 0.35, 4.5, _look)
	Vfx.ring(get_parent(), Vector3(global_position.x, 0, global_position.z), radius, move.type)


func _spawn_explosion_fx(radius: float) -> void:
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	fx.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(GameData.type_color(move.type), 0.5)
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(fx)
	fx.global_position = global_position
	fx.scale = Vector3.ONE * 0.3
	var tween := fx.create_tween().set_parallel()
	tween.tween_property(fx, "scale", Vector3.ONE, 0.18)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.chain().tween_callback(fx.queue_free)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
