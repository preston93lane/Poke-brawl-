class_name Projectile
extends Area3D
## A straight-flying shot fired by a Brawler's ranged move. Can pierce
## through enemies and/or explode for area damage, depending on the move.
##
## Collision is done by hand each physics step: a ray sweeps the path for walls
## (so fast shots can't skip through a wall between frames) and enemies are
## checked by distance in small sub-steps.

var shooter: Brawler
var move: MoveData
var team := 0
var direction := Vector3.FORWARD

var _travelled := 0.0
var _hit: Array[Brawler] = []
var _done := false
var _trail: CPUParticles3D
var _jitter := 0.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var shape: CollisionShape3D = $CollisionShape3D


func setup(p_shooter: Brawler, p_move: MoveData, dir: Vector3) -> void:
	shooter = p_shooter
	move = p_move
	team = p_shooter.team
	direction = dir


func _ready() -> void:
	monitoring = false
	mesh.material_override = Vfx.core_material(move.type)
	var size := move.radius / 0.3
	mesh.scale = Vector3.ONE * size * 0.8
	_jitter = float(Vfx.style(move.type).get("jitter", 0.0))
	_trail = Vfx.trail(move.type, move.radius)
	add_child(_trail)
	# The scene's shape resource is shared between projectiles, so give each its own.
	var sphere := SphereShape3D.new()
	sphere.radius = move.radius
	shape.shape = sphere


func _process(_delta: float) -> void:
	if _jitter > 0.0:  # Electric shots crackle.
		mesh.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _jitter


func _physics_process(delta: float) -> void:
	if _done:
		return
	var remaining := minf(move.speed * delta, move.reach - _travelled)
	var space := get_world_3d().direct_space_state
	var sub_step := maxf(0.1, move.radius)
	while remaining > 0.0001 and not _done:
		var step := minf(sub_step, remaining)
		var from := global_position
		var to := from + direction * step
		var query := PhysicsRayQueryParameters3D.create(from, to + direction * move.radius, Brawler.WALL_MASK)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit["position"] - direction * move.radius
			_finish()  # Hit a wall or obstacle.
			return
		global_position = to
		_travelled += step
		remaining -= step
		_check_brawlers()
	if not _done and _travelled >= move.reach - 0.0001:
		_finish()


func _check_brawlers() -> void:
	for node in get_tree().get_nodes_in_group("brawlers"):
		var target := node as Brawler
		if target == null or target.team == team or target.is_dead or target in _hit:
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() > move.radius + Brawler.BODY_RADIUS:
			continue
		_hit.append(target)
		if move.explode_radius > 0.0:
			_finish()
			return
		if is_instance_valid(shooter):
			target.take_hit(shooter, move)
		if not move.pierce:
			_finish()
			return


func _finish() -> void:
	if _done:
		return
	_done = true
	if move.explode_radius > 0.0:
		_explode()
	else:
		Vfx.burst(get_parent(), global_position, move.type, 10, 0.2, 2.5)
	_detach_trail()
	queue_free()


## Let the trail fade out on its own instead of vanishing with the projectile.
func _detach_trail() -> void:
	if _trail == null or get_parent() == null:
		return
	var at := _trail.global_position
	remove_child(_trail)
	get_parent().add_child(_trail)
	_trail.global_position = at
	_trail.emitting = false
	get_tree().create_timer(_trail.lifetime + 0.2, false).timeout.connect(_trail.queue_free)


func _explode() -> void:
	if is_instance_valid(shooter):
		for node in get_tree().get_nodes_in_group("brawlers"):
			var target := node as Brawler
			if target == null or target.team == team or target.is_dead:
				continue
			var offset := target.global_position - global_position
			offset.y = 0.0
			if offset.length() <= move.explode_radius + Brawler.BODY_RADIUS \
					and Brawler.clear_between(self, global_position, target.global_position):
				target.take_hit(shooter, move)
	_spawn_explosion_fx()
	Vfx.burst(get_parent(), global_position, move.type, 36, move.explode_radius * 0.4, 5.0)
	Vfx.ring(get_parent(), Vector3(global_position.x, 0, global_position.z), move.explode_radius, move.type)


func _spawn_explosion_fx() -> void:
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = move.explode_radius
	sphere.height = move.explode_radius * 2.0
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
