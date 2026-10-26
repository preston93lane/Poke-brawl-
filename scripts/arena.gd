class_name Arena
extends Node3D
## Builds an arena from an ASCII tile map in data/arenas/<id>.json.
##
## Legend: . floor   , path   " tall grass (hide)   T tree   # rock wall
##         B boulder   ~ water (blocks walking, not shots)   1/2 team spawns
##         Z king-of-the-hill zone

const TILE := 1.0
const WALL_HEIGHT := 1.2
const TREE_COLLIDER_HEIGHT := 2.0
const GRASS_HEIGHT := 0.75
const TREE_SPRITE_SIZE := Vector2(1.4, 1.75)
const WORLD_LAYER := 1
const WATER_LAYER := 8
const TILE_DIR := "res://assets/tiles/"

var arena_name := ""
var width := 0
var height := 0
var rows := PackedStringArray()
var spawns := { 0: Vector3(0, 0, 10), 1: Vector3(0, 0, -10) }
var zone_center := Vector3.ZERO

var _zone_cells := {}
var _zone_material: StandardMaterial3D


func build(arena_id: String, sprite_tilt_degrees: float) -> void:
	var def: Dictionary = GameData.arenas.get(arena_id, {})
	if def.is_empty():
		push_error("Arena: unknown arena '%s'" % arena_id)
		return
	arena_name = str(def.get("name", arena_id))
	rows = PackedStringArray(def.get("map", []))
	height = rows.size()
	for row in rows:
		width = maxi(width, row.length())
	var floor_tile := str(def.get("floor", "grass"))

	var floors := {}  # texture name -> Array[Transform3D]
	var rocks: Array[Transform3D] = []
	var boulders: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var zone: Array[Transform3D] = []
	var walls := StaticBody3D.new()
	walls.collision_layer = WORLD_LAYER
	walls.collision_mask = 0
	add_child(walls)
	var water := StaticBody3D.new()
	water.collision_layer = WATER_LAYER
	water.collision_mask = 0
	add_child(water)

	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(sprite_tilt_degrees))
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			var c := _char_at(cell)
			var center := cell_center(cell)
			var floor_name := floor_tile
			if c == ",":
				floor_name = "path"
			elif c == "~":
				floor_name = "water"
			if not floors.has(floor_name):
				floors[floor_name] = []
			floors[floor_name].append(Transform3D(Basis(), center))
			match c:
				"T":
					_add_collider(walls, center, Vector3(TILE, TREE_COLLIDER_HEIGHT, TILE))
					# Upright sprite tilted to face the fixed camera; base sits at the tile's front edge.
					var base := center + Vector3(0, 0, TILE * 0.35)
					trees.append(Transform3D(tilt, base + tilt.y * TREE_SPRITE_SIZE.y * 0.5))
				"#":
					_add_collider(walls, center, Vector3(TILE, WALL_HEIGHT, TILE))
					rocks.append(Transform3D(Basis(), center + Vector3(0, WALL_HEIGHT * 0.5, 0)))
				"B":
					_add_collider(walls, center, Vector3(TILE, WALL_HEIGHT, TILE))
					boulders.append(Transform3D(Basis(), center + Vector3(0, WALL_HEIGHT * 0.5, 0)))
				"~":
					_add_collider(water, center, Vector3(TILE, 1.0, TILE))
				"\"":
					grass.append(Transform3D(Basis(), center + Vector3(0, GRASS_HEIGHT * 0.5, 0)))
				"1":
					spawns[0] = center
				"2":
					spawns[1] = center
				"Z":
					_zone_cells[cell] = true
					zone.append(Transform3D(Basis(), center + Vector3(0, 0.02, 0)))

	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(TILE, TILE)
	for floor_name: String in floors:
		_add_multimesh(floor_plane, _tile_material(floor_name), floors[floor_name])

	var block := BoxMesh.new()
	block.size = Vector3(TILE, WALL_HEIGHT, TILE)
	_add_multimesh(block, _tile_material("rock", true), rocks)
	_add_multimesh(block, _tile_material("boulder", true), boulders)

	var grass_box := BoxMesh.new()
	grass_box.size = Vector3(TILE, GRASS_HEIGHT, TILE)
	_add_multimesh(grass_box, _tile_material("tall_grass", true, true), grass)

	var tree_quad := QuadMesh.new()
	tree_quad.size = TREE_SPRITE_SIZE
	var tree_mat := _tile_material("tree", false, true)
	tree_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_multimesh(tree_quad, tree_mat, trees, false)

	if not zone.is_empty():
		_zone_material = _tile_material("zone", false, false)
		_zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_add_multimesh(floor_plane, _zone_material, zone, false)
		var sum := Vector3.ZERO
		for t in zone:
			sum += t.origin
		zone_center = Vector3(sum.x, 0, sum.z) / zone.size()
		set_zone_owner(-1)

	# Dark ground outside the map so the edge of the world isn't empty.
	var outside_mat := StandardMaterial3D.new()
	outside_mat.albedo_color = Color(0.18, 0.3, 0.16)
	var outside_plane := PlaneMesh.new()
	outside_plane.size = Vector2(160, 160)
	var outside := MeshInstance3D.new()
	outside.mesh = outside_plane
	outside.material_override = outside_mat
	outside.position.y = -0.03
	add_child(outside)


func has_zone() -> bool:
	return not _zone_cells.is_empty()


func is_tall_grass(world_pos: Vector3) -> bool:
	return _char_at(world_to_cell(world_pos)) == "\""


func is_in_zone(world_pos: Vector3) -> bool:
	return _zone_cells.has(world_to_cell(world_pos))


## -1 = nobody, -2 = contested, otherwise the controlling team.
func set_zone_owner(owner_team: int) -> void:
	if _zone_material == null:
		return
	var color := Color(1, 1, 1, 0.9)
	if owner_team == -2:
		color = Color(1, 0.85, 0.3, 0.9)
	elif owner_team >= 0:
		color = Color(0.35, 0.65, 1.0, 0.95) if owner_team == GameData.local_team else Color(1, 0.35, 0.35, 0.95)
	_zone_material.albedo_color = color


## Arena size in world units (x = width, y = depth).
func world_size() -> Vector2:
	return Vector2(width, height) * TILE


func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE + width * 0.5), floori(world_pos.z / TILE + height * 0.5))


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5 - width * 0.5) * TILE, 0.0, (cell.y + 0.5 - height * 0.5) * TILE)


func _char_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= height or cell.x < 0 or cell.x >= rows[cell.y].length():
		return "."
	return rows[cell.y][cell.x]


func _add_collider(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = center + Vector3(0, size.y * 0.5, 0)
	body.add_child(shape)


func _add_multimesh(mesh: Mesh, material: Material, transforms: Array, shadows := true) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


## Pixel-art material: nearest filtering, one 16px tile per world unit.
func _tile_material(tile_name: String, triplanar := false, alpha_cut := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TILE_DIR + tile_name + ".png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	if triplanar:
		mat.uv1_triplanar = true
	if alpha_cut:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
