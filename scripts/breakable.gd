class_name Breakable
extends StaticBody3D
## One breakable tile: a cracked wall or boulder (only supers smash it) or a
## Showdown power-cube crate (any attack chips away at it). Blocks walking,
## shots and line of sight like a normal wall until it breaks.

signal broken(breakable: Breakable)

## Crates take this much more damage than a 100-defense Pokémon would.
const CRATE_DEFENSE := 100.0

var cell := Vector2i.ZERO
## "wall" (supers only) or "crate" (any attack; drops a power cube in Showdown).
var kind := "wall"
var max_hp := 3000.0
var hp := 3000.0
var is_broken := false

var _mesh: MeshInstance3D
var _shake := 0.0
## Drawn as one copy in a shared MultiMesh (Arena.batch_breakables) while it sits
## still: one draw call for every rock of the same shape instead of one each. It
## takes its own mesh back while shaking, and for good when it moves or breaks.
var _batch: MultiMesh
var _batch_index := -1


func setup(p_cell: Vector2i, p_kind: String, mesh: Mesh, material: Material, p_max_hp := 3000.0) -> void:
	cell = p_cell
	kind = p_kind
	max_hp = p_max_hp
	hp = p_max_hp
	collision_layer = Arena.WORLD_LAYER
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.material_override = material
	_mesh.position.y = Arena.WALL_HEIGHT * 0.5
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Arena.TILE, Arena.TREE_COLLIDER_HEIGHT, Arena.TILE)
	shape.shape = box
	shape.position.y = Arena.TREE_COLLIDER_HEIGHT * 0.5
	add_child(shape)


func set_mesh(mesh: Mesh, basis_value: Basis, material: Material = null) -> void:
	unbatch()
	_mesh.mesh = mesh
	_mesh.basis = basis_value
	if material:
		_mesh.material_override = material


## Twist / resize the visible mesh (the collider stays one tile).
func set_mesh_basis(basis_value: Basis) -> void:
	unbatch()
	_mesh.basis = basis_value


## The visible mesh, its material and where it sits (for batching).
func mesh_key() -> String:
	return "%d:%d" % [_mesh.mesh.get_instance_id() if _mesh.mesh else 0, _mesh.material_override.get_instance_id() if _mesh.material_override else 0]


func mesh_instance() -> MeshInstance3D:
	return _mesh


func join_batch(mm: MultiMesh, index: int) -> void:
	_batch = mm
	_batch_index = index
	mm.set_instance_transform(index, (global_transform if is_inside_tree() else transform) * _mesh.transform)
	_mesh.visible = false


## Back to drawing itself (before moving, or for good).
func unbatch() -> void:
	if _batch:
		_hide_copy()
		_batch = null
		_batch_index = -1
	if _mesh:
		_mesh.visible = true


func _hide_copy() -> void:
	if _batch and _batch_index >= 0:
		_batch.set_instance_transform(_batch_index, Transform3D(Basis.from_scale(Vector3.ZERO), global_position))


func _ready() -> void:
	add_to_group("breakables")
	set_process(false)  # Only ticks while shaking (a map has a couple of hundred of these).


func _process(delta: float) -> void:
	if _shake > 0.0:
		if _batch and not _mesh.visible:
			_hide_copy()
			_mesh.visible = true
		_shake = maxf(0.0, _shake - delta)
		_mesh.position.x = randf_range(-1, 1) * _shake * 0.4
		_mesh.position.z = randf_range(-1, 1) * _shake * 0.4
		if _shake <= 0.0:
			set_process(false)
			if _batch:
				_mesh.position.x = 0.0
				_mesh.position.z = 0.0
				join_batch(_batch, _batch_index)


## Hit by `move`. Walls only break to supers; crates lose HP to anything.
## Returns true if it broke (or was already broken).
func take_attack(attacker: Brawler, move: MoveData, multiplier := 1.0) -> bool:
	if is_broken:
		return true
	if kind != "crate":
		if move.slot == "super" and move.breaks_walls:
			smash()
			return true
		_shake = 0.12
		set_process(true)
		return false
	if not is_instance_valid(attacker) or move.power <= 0.0:
		return false
	var amount := move.power * multiplier * attacker.get_attack() / CRATE_DEFENSE \
			* float(GameData.rule("damage_scale", 1.0)) * attacker.power_bonus()
	hp -= amount
	_shake = 0.18
	set_process(true)
	if hp <= 0.0:
		smash()
		return true
	return false


func smash() -> void:
	if is_broken:
		return
	is_broken = true
	unbatch()
	collision_layer = 0
	var parent := get_parent()
	var at := global_position + Vector3(0, 0.6, 0)
	# A big, obvious burst of rubble so you can see supers breaking things.
	Vfx.burst(parent, at, "rock" if kind != "crate" else "grass", 60, 0.8, 6.0)
	Vfx.burst(parent, at + Vector3(0, 0.4, 0), "ground", 40, 0.6, 4.5)
	Vfx.ring(parent, global_position, 1.3, "ground", 40)
	broken.emit(self)
	if parent is Arena:
		(parent as Arena).on_breakable_broken(self)
	queue_free()


## Every unbroken breakable whose tile is within `radius` of `center`.
static func near(tree: SceneTree, center: Vector3, radius: float) -> Array[Breakable]:
	var result: Array[Breakable] = []
	for node in tree.get_nodes_in_group("breakables"):
		var b := node as Breakable
		if b == null or b.is_broken:
			continue
		var offset := b.global_position - center
		offset.y = 0.0
		if offset.length() <= radius + Arena.TILE * 0.6:
			result.append(b)
	return result


## Hits every breakable in a circle (explosions, area strikes, slams).
static func hit_area(tree: SceneTree, center: Vector3, radius: float, attacker: Brawler, move: MoveData, multiplier := 1.0) -> void:
	for b in near(tree, center, radius):
		b.take_attack(attacker, move, multiplier)


## Hits breakables inside a cone in front of `origin` (swipes, streams).
static func hit_cone(tree: SceneTree, origin: Vector3, direction: Vector3, reach: float, arc: float,
		attacker: Brawler, move: MoveData, multiplier := 1.0) -> void:
	var half_arc := deg_to_rad(arc) * 0.5
	for b in near(tree, origin, reach):
		var to := b.global_position - origin
		to.y = 0.0
		if to.length() < 0.01 or direction.angle_to(to.normalized()) <= half_arc + 0.5:
			b.take_attack(attacker, move, multiplier)
