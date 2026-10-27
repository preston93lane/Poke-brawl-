class_name Ball
extends Node3D
## The Brawl Ball (a Poké Ball). Rolls with friction and bounces off walls; any
## Pokémon that touches it picks it up and carries it in front of them. The
## carrier's attack kicks it; fainting or being stunned drops it.

const RADIUS := 0.35
const PICKUP_RADIUS := 0.85
const FRICTION := 1.7
const MIN_KICK := 6.0
const MAX_KICK := 17.0
## A kicker can't catch their own kick for this long.
const KICKER_LOCK := 0.45

var velocity := Vector3.ZERO
var carrier: Brawler
## Last Pokémon to carry or kick it (gets credit for a goal).
var last_touch: Brawler

var _locks := {}  # Brawler -> seconds before it may pick the ball up again
var _all_lock := 0.0
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D


func _ready() -> void:
	add_to_group("ball")
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _poke_ball_texture()
	mat.roughness = 0.35
	_mesh.material_override = mat
	add_child(_mesh)
	_shadow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	_shadow.mesh = disc
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0, 0, 0, 0.35)
	_shadow.material_override = shadow_mat
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


func _physics_process(delta: float) -> void:
	_all_lock = maxf(0.0, _all_lock - delta)
	for b in _locks.keys():
		_locks[b] = float(_locks[b]) - delta
		if float(_locks[b]) <= 0.0:
			_locks.erase(b)
	if carrier:
		if not is_instance_valid(carrier) or carrier.is_dead or carrier.is_stunned():
			drop()
		else:
			global_position = carrier.global_position + carrier.facing * 0.55 + Vector3(0, RADIUS, 0)
			_mesh.rotation.x += delta * 6.0
			_shadow.global_position = Vector3(global_position.x, 0.02, global_position.z)
			return
	_roll(delta)
	_shadow.global_position = Vector3(global_position.x, 0.02, global_position.z)
	if _all_lock <= 0.0:
		_try_pickup()


func _roll(delta: float) -> void:
	if velocity.length_squared() < 0.0025:
		velocity = Vector3.ZERO
		return
	var step := velocity * delta
	var dir := velocity.normalized()
	var from := global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + step + dir * RADIUS, Brawler.WALL_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = from + step
	else:
		var normal: Vector3 = hit.get("normal", -dir)
		normal.y = 0.0
		global_position = hit["position"] - dir * RADIUS
		velocity = velocity.bounce(normal.normalized()) * 0.65 if normal.length() > 0.01 else -velocity * 0.65
		velocity.y = 0.0
	velocity *= exp(-FRICTION * delta)
	# Roll the ball's texture around the axis perpendicular to travel.
	var axis := Vector3(dir.z, 0, -dir.x)
	if axis.length() > 0.01:
		_mesh.rotate(axis.normalized(), step.length() / RADIUS)


func _try_pickup() -> void:
	var best: Brawler = null
	var best_dist := PICKUP_RADIUS
	for node in get_tree().get_nodes_in_group("brawlers"):
		var b := node as Brawler
		if b == null or b.is_dead or b.is_legendary or b.is_stunned() or _locks.has(b) or b.ball != null:
			continue
		var offset := b.global_position - global_position
		offset.y = 0.0
		if offset.length() < best_dist:
			best_dist = offset.length()
			best = b
	if best:
		carrier = best
		last_touch = best
		best.ball = self
		velocity = Vector3.ZERO


## Kick from `from` toward `direction`; `distance` (if > 0) sets how far it rolls.
func kick(from: Brawler, direction: Vector3, distance := -1.0) -> void:
	if carrier == from:
		from.ball = null
		carrier = null
	last_touch = from
	_locks[from] = KICKER_LOCK
	var speed := MAX_KICK if distance < 0.0 else clampf(distance * FRICTION + 2.0, MIN_KICK, MAX_KICK)
	velocity = direction.normalized() * speed
	var start := from.global_position + Vector3(0, RADIUS, 0)
	var ahead := start + direction.normalized() * 0.6
	var query := PhysicsRayQueryParameters3D.create(start, ahead, Brawler.WALL_MASK)
	global_position = start if not get_world_3d().direct_space_state.intersect_ray(query).is_empty() else ahead


func drop() -> void:
	if carrier and is_instance_valid(carrier):
		carrier.ball = null
		_locks[carrier] = KICKER_LOCK
	carrier = null
	velocity = Vector3.ZERO
	global_position.y = RADIUS


## Back to the kick-off spot, nobody can grab it for a moment.
func reset(at: Vector3) -> void:
	drop()
	_locks.clear()
	global_position = at + Vector3(0, RADIUS, 0)
	_all_lock = 1.2
	last_touch = null


static func _poke_ball_texture() -> ImageTexture:
	var w := 64
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := Color(0.92, 0.15, 0.15) if y < h / 2 else Color(0.97, 0.97, 0.97)
			if absi(y - h / 2) <= 1:
				c = Color(0.1, 0.1, 0.12)
			# Button on the front (u = 0.25).
			var d := Vector2((x - w * 0.25) * 0.5, y - h * 0.5).length()
			if d < 4.5:
				c = Color(0.1, 0.1, 0.12) if d > 3.0 else Color(1, 1, 1)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
