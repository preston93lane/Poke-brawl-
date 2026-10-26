class_name Arena
extends Node3D
## Builds an arena from an ASCII tile map in data/arenas/<id>.json.
##
## Legend: . floor   , path   " tall grass (hide)   T tree   # rock wall
##         B boulder   ~ water (blocks walking, not shots)   1/2 team spawns
##         (one tile per teammate)   Z king-of-the-hill zone
##
## Also builds an AStarGrid2D so bots can path around walls (find_path).

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
## team -> Array[Vector3], one spawn point per teammate.
var spawns := { 0: [], 1: [] }
var zone_center := Vector3.ZERO

var _zone_cells := {}
var _zone_material: StandardMaterial3D
var _astar := AStarGrid2D.new()


## use_zone = false treats Z tiles as plain floor (modes without a zone).
func build(arena_id: String, sprite_tilt_degrees: float, use_zone := true) -> void:
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
	var solid_cells := {}
	var water_cells := {}

	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(sprite_tilt_degrees))
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			var c := _char_at(cell)
			if c == "Z" and not use_zone:
				c = "."
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
					solid_cells[cell] = true
					# Upright sprite tilted to face the fixed camera; base sits at the tile's front edge.
					var base := center + Vector3(0, 0, TILE * 0.35)
					trees.append(Transform3D(tilt, base + tilt.y * TREE_SPRITE_SIZE.y * 0.5))
				"#":
					solid_cells[cell] = true
					rocks.append(Transform3D(Basis(), center + Vector3(0, WALL_HEIGHT * 0.5, 0)))
				"B":
					solid_cells[cell] = true
					boulders.append(Transform3D(Basis(), center + Vector3(0, WALL_HEIGHT * 0.5, 0)))
				"~":
					water_cells[cell] = true
				"\"":
					grass.append(Transform3D(Basis(), center + Vector3(0, GRASS_HEIGHT * 0.5, 0)))
				"1":
					spawns[0].append(center)
				"2":
					spawns[1].append(center)
				"Z":
					_zone_cells[cell] = true
					zone.append(Transform3D(Basis(), center + Vector3(0, 0.02, 0)))

	_build_colliders(solid_cells, WORLD_LAYER, TREE_COLLIDER_HEIGHT)
	_build_colliders(water_cells, WATER_LAYER, 1.0)
	_build_pathfinding(solid_cells, water_cells)
	for team: int in spawns:
		if spawns[team].is_empty():
			spawns[team].append(Vector3(0, 0, (height * 0.5 - 3.0) * (1.0 if team == 0 else -1.0)))

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


## Spawn point for the `index`-th member of `team`.
func spawn_point(team: int, index: int) -> Vector3:
	var points: Array = spawns[team]
	return points[index % points.size()]


## Walkable route from `from` to `to` as world positions (cell centres),
## excluding the start cell. Empty if there's no route.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	var start := world_to_cell(from)
	var goal := world_to_cell(to)
	if not _astar.is_in_boundsv(start) or not _astar.is_in_boundsv(goal):
		return result
	var ids := _astar.get_id_path(start, goal, true)
	for i in range(1, ids.size()):
		result.append(cell_center(ids[i]))
	return result


func is_walkable(world_pos: Vector3) -> bool:
	var cell := world_to_cell(world_pos)
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


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


## One static body whose boxes cover `cells`, merged into rectangles. Long
## smooth walls (instead of one box per tile) let brawlers slide along them
## without catching on the seams between tiles.
func _build_colliders(cells: Dictionary, layer: int, collider_height: float) -> void:
	if cells.is_empty():
		return
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	var used := {}
	for y in height:
		for x in width:
			var start := Vector2i(x, y)
			if not cells.has(start) or used.has(start):
				continue
			var w := 1
			while cells.has(Vector2i(x + w, y)) and not used.has(Vector2i(x + w, y)):
				w += 1
			var h := 1
			while _row_free(cells, used, x, y + h, w):
				h += 1
			for yy in range(y, y + h):
				for xx in range(x, x + w):
					used[Vector2i(xx, yy)] = true
			var box := BoxShape3D.new()
			box.size = Vector3(w * TILE, collider_height, h * TILE)
			var shape := CollisionShape3D.new()
			shape.shape = box
			var corner := cell_center(start) - Vector3(TILE, 0, TILE) * 0.5
			shape.position = corner + Vector3(w * TILE * 0.5, collider_height * 0.5, h * TILE * 0.5)
			body.add_child(shape)


func _row_free(cells: Dictionary, used: Dictionary, x: int, y: int, w: int) -> bool:
	for xx in range(x, x + w):
		var c := Vector2i(xx, y)
		if not cells.has(c) or used.has(c):
			return false
	return true


func _build_pathfinding(solid_cells: Dictionary, water_cells: Dictionary) -> void:
	_astar.region = Rect2i(0, 0, width, height)
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for cell: Vector2i in solid_cells:
		_astar.set_point_solid(cell)
	for cell: Vector2i in water_cells:
		_astar.set_point_solid(cell)


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
