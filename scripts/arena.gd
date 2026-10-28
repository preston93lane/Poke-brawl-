class_name Arena
extends Node3D
## Builds an arena from an ASCII tile map in data/arenas/<id>.json.
##
## Legend: . floor   , path   " tall grass (hide)   T tree   # rock wall (permanent)
##         X cracked wall, B boulder, I ice block (breakable: supers smash them)
##         K gravestone (permanent)
##         ~ water (blocks walking except for Water/Flying types, not shots)   1/2 team spawns
##         (one tile per teammate)   Z king-of-the-hill zone   G Brawl Ball goal
##         S Showdown spawn   P Showdown power-cube crate
##         F fire vent (erupts every few seconds)   O warp pad (sends you to its mirror pad)
##         Map-wide "weather": "lightning" adds lightning strikes (see hazards.gd).
##
## Also builds an AStarGrid2D so bots can path around walls (find_path).

const TILE := 1.0
const WALL_HEIGHT := 1.2
const TREE_COLLIDER_HEIGHT := 2.0
const GRASS_HEIGHT := 0.95
const TREE_SPRITE_SIZE := Vector2(1.75, 2.2)
const GRASS_SHADER := preload("res://assets/shaders/grass_sway.gdshader")
const WATER_SHADER := preload("res://assets/shaders/water.gdshader")
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
var mode := "duel"
## "water" (Water and Flying types cross it) or "lava" (Fire and Flying types cross it).
var liquid := "water"
const GRAVE_SPRITE_SIZE := Vector2(1.0, 1.25)
## Brawl Ball: team -> { cell: true } of the goal that team defends.
var goal_cells := { 0: {}, 1: {} }
## Showdown spawn points (S tiles).
var showdown_spawns: Array[Vector3] = []
## Hazard tiles (built by hazards.gd): fire vents and warp pads.
var vent_cells: Array[Vector2i] = []
var warp_cells: Array[Vector2i] = []
## Map-wide hazard from the map's "weather" ("" or "lightning").
var weather := ""
## Set by main.gd when the map has hazards (bots ask it what to avoid).
var hazards: Hazards
var _crate_mesh: BoxMesh
var _crate_material: StandardMaterial3D
var _breakable_mesh: Mesh
var _crate_mesh_box: BoxMesh
## Wall styles drawn as rounded, lumpy shapes (natural things); the rest stay as blocks.
const ORGANIC_WALLS := ["rock", "hedge", "ice_block", "cracked"]

var _zone_cells := {}
var _zone_material: StandardMaterial3D
var _astar := AStarGrid2D.new()
## Same grid, but water is open (for Pokémon that swim or fly).
var _swim_astar := AStarGrid2D.new()


## Mode-specific tiles (Z zone, G goals, P crates) are plain floor in other modes.
func build(arena_id: String, sprite_tilt_degrees: float, p_mode := "duel") -> void:
	mode = p_mode
	var use_zone := mode == "king_of_the_hill"
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
	var wall_tile := str(def.get("wall", "rock"))
	var breakable_walls := bool(def.get("breakable_walls", true))
	liquid = str(def.get("liquid", "water"))
	weather = str(def.get("weather", ""))
	var graves: Array[Transform3D] = []
	var path_blobs: Array[Transform3D] = []

	var floors := {}  # texture name -> Array[Transform3D]
	var rocks: Array[Transform3D] = []
	var boulders: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var zone: Array[Transform3D] = []
	var solid_cells := {}
	var water_cells := {}
	## Breakable tiles: block paths like walls but get their own bodies.
	var breakable_cells := {}  # cell -> "cracked" / "boulder" / "crate"
	var goal_tiles: Array[Vector2i] = []

	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(sprite_tilt_degrees))
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			var c := _char_at(cell)
			if c == "Z" and not use_zone:
				c = "."
			if (c == "G" and mode != "brawl_ball") or (c == "P" and mode != "showdown"):
				c = "."
			var center := cell_center(cell)
			var floor_name := floor_tile
			if floor_tile == "grass":
				floor_name = "grass_%d" % posmod(x * 7 + y * 13 + (x * y) % 5, 3)  # Mix of variants.
			if c == ",":
				# Paths are soft round patches over the floor rather than square tiles.
				var turn := float(posmod(x * 37 + y * 11, 12)) * PI / 6.0
				var spread := 1.35 + float(posmod(x * 5 + y * 3, 4)) * 0.06
				path_blobs.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(spread, 1, spread)), center + Vector3(0, 0.008, 0)))
			elif c == "~":
				floor_name = "water"
			if not floors.has(floor_name):
				floors[floor_name] = []
			floors[floor_name].append(Transform3D(Basis(), center))
			if c == "#" and breakable_walls and x > 1 and y > 1 and x < width - 2 and y < height - 2:
				# Inner walls break to supers (like Brawl Stars); the map's edge stays solid.
				breakable_cells[cell] = "wall_style"
				c = ""
			match c:
				"T":
					solid_cells[cell] = true
					# Upright sprite tilted to face the fixed camera; base sits at the tile's front edge.
					var base := center + Vector3(0, 0, TILE * 0.35)
					trees.append(Transform3D(tilt, base + tilt.y * TREE_SPRITE_SIZE.y * 0.5))
				"#":
					solid_cells[cell] = true
					rocks.append(Transform3D(_jitter(cell) if wall_tile in ORGANIC_WALLS else Basis(), center + Vector3(0, WALL_HEIGHT * 0.5, 0)))
				"B":
					breakable_cells[cell] = "boulder"
				"X":
					breakable_cells[cell] = "cracked"
				"I":
					breakable_cells[cell] = "ice_block"
				"K":
					solid_cells[cell] = true
					var grave_base := center + Vector3(0, 0, TILE * 0.3)
					graves.append(Transform3D(tilt, grave_base + tilt.y * GRAVE_SPRITE_SIZE.y * 0.5))
				"P":
					breakable_cells[cell] = "crate"
				"G":
					goal_tiles.append(cell)
					zone.append(Transform3D(Basis(), center + Vector3(0, 0.02, 0)))
				"S":
					showdown_spawns.append(center)
				"F":
					vent_cells.append(cell)
				"O":
					warp_cells.append(cell)
				"~":
					water_cells[cell] = true
				"\"":
					var yaw := float(posmod(x * 31 + y * 17, 12)) * PI / 6.0
					var bush_scale := 0.95 + float(posmod(x * 13 + y * 7, 5)) * 0.04
					grass.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * bush_scale), center))
				"1":
					spawns[0].append(center)
				"2":
					spawns[1].append(center)
				"Z":
					_zone_cells[cell] = true
					zone.append(Transform3D(Basis(), center + Vector3(0, 0.02, 0)))

	_build_colliders(solid_cells, WORLD_LAYER, TREE_COLLIDER_HEIGHT)
	_build_colliders(water_cells, WATER_LAYER, 1.0)
	var path_blocked := solid_cells.duplicate()
	for cell: Vector2i in breakable_cells:
		path_blocked[cell] = true
	_build_pathfinding(path_blocked, water_cells)
	for team: int in spawns:
		if spawns[team].is_empty():
			spawns[team].append(Vector3(0, 0, (height * 0.5 - 3.0) * (1.0 if team == 0 else -1.0)))
	# Each goal belongs to the team whose spawn is nearer (they defend it).
	for cell in goal_tiles:
		var p := cell_center(cell)
		var team := 0 if p.distance_to(spawns[0][0]) < p.distance_to(spawns[1][0]) else 1
		goal_cells[team][cell] = true

	var floor_plane := PlaneMesh.new()
	floor_plane.size = Vector2(TILE, TILE)
	for floor_name: String in floors:
		var mat: Material = _water_material() if floor_name == "water" else _tile_material(floor_name)
		_add_multimesh(floor_plane, mat, floors[floor_name])
	_add_multimesh(floor_plane, _edge_shadow_material(), _edge_shadows(solid_cells, water_cells), false)

	if not path_blobs.is_empty():
		var blob_mat := _tile_material("path_blob", false, false)
		blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_add_multimesh(floor_plane, blob_mat, path_blobs, false)
	var block := BoxMesh.new()
	block.size = Vector3(TILE, WALL_HEIGHT, TILE)
	_crate_mesh_box = block
	var lump := lump_mesh(0.62, 0.1, 7)
	_add_multimesh(lump if wall_tile in ORGANIC_WALLS else block, _tile_material(wall_tile, true), rocks)
	_add_multimesh(block, _tile_material("boulder", true), boulders)
	_breakable_mesh = lump
	var materials := {
		"cracked": _tile_material("cracked", true),
		"boulder": _tile_material("boulder", true),
		"ice_block": _tile_material("ice_block", true),
		"wall_style": _tile_material(wall_tile, true),
		"crate": _tile_material("crate", true),
	}
	_crate_material = materials["crate"]
	for cell: Vector2i in breakable_cells:
		var kind: String = breakable_cells[cell]
		var b := _add_breakable(cell, "crate" if kind == "crate" else "wall", materials[kind])
		if kind == "wall_style" and wall_tile not in ORGANIC_WALLS:
			b.set_mesh(_crate_mesh_box, Basis())  # Brick / metal / wood walls stay blocky.

	var grass_mat := ShaderMaterial.new()
	grass_mat.shader = GRASS_SHADER
	grass_mat.set_shader_parameter("blades", load(TILE_DIR + "tall_grass.png"))
	_add_multimesh(_bush_mesh(), grass_mat, grass)

	var tree_quad := QuadMesh.new()
	tree_quad.size = TREE_SPRITE_SIZE
	var tree_mat := _tile_material("tree", false, true)
	tree_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_multimesh(tree_quad, tree_mat, trees, false)
	var grave_quad := QuadMesh.new()
	grave_quad.size = GRAVE_SPRITE_SIZE
	var grave_mat := _tile_material("gravestone", false, true)
	grave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_multimesh(grave_quad, grave_mat, graves, false)

	if not zone.is_empty():
		_zone_material = _tile_material("goal" if mode == "brawl_ball" else "zone", false, false)
		_zone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_zone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_add_multimesh(floor_plane, _zone_material, zone, false)
		var sum := Vector3.ZERO
		for t in zone:
			sum += t.origin
		zone_center = Vector3(sum.x, 0, sum.z) / zone.size()
		set_zone_owner(-1)
		if mode == "brawl_ball":
			_zone_material.albedo_color = Color(1, 1, 1, 0.9)

	# Dark ground outside the map so the edge of the world isn't empty.
	var outside_mat := _tile_material("grass_1")
	outside_mat.albedo_color = Color(0.55, 0.62, 0.5)
	outside_mat.uv1_scale = Vector3(160, 160, 1)
	var outside_plane := PlaneMesh.new()
	outside_plane.size = Vector2(160, 160)
	var outside := MeshInstance3D.new()
	outside.mesh = outside_plane
	outside.material_override = outside_mat
	outside.position.y = -0.03
	add_child(outside)


func _add_breakable(cell: Vector2i, kind: String, material: Material) -> Breakable:
	var b := Breakable.new()
	var crate := kind == "crate"
	b.setup(cell, kind, _crate_mesh_box if crate else _breakable_mesh, material, float(GameData.rule("modes/showdown/crate_hp", 3000.0)))
	b.position = cell_center(cell)
	if not crate:
		b.set_mesh_basis(_jitter(cell))
	add_child(b)
	return b


## A small random twist and size change per tile, so neighbouring rounded walls
## overlap into uneven, natural-looking ridges. Deterministic per cell.
func _jitter(cell: Vector2i) -> Basis:
	var h := posmod(cell.x * 73856093 ^ cell.y * 19349663, 1000) / 1000.0
	var h2 := posmod(cell.x * 83492791 ^ cell.y * 2654435, 1000) / 1000.0
	var spread := 1.0 + h * 0.14
	return Basis(Vector3.UP, h2 * TAU).scaled(Vector3(spread, 0.9 + h2 * 0.25, spread))


## Rounded, slightly lumpy block filling about one tile (a cube puffed toward a
## sphere, with gentle bumps), centred like the wall box so it can replace it.
## `cubeness` 0 = ball, 1 = box; `bumps` = how uneven the surface is.
static func lump_mesh(cubeness: float, bumps: float, variant: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = 10
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		var d := verts[i].normalized() if verts[i].length() > 0.0001 else Vector3.UP
		# Push toward a cube so it fills its tile, then add smooth bumps.
		var cube := d / maxf(absf(d.x), maxf(absf(d.y), absf(d.z)))
		var p := d.lerp(cube * 0.92, cubeness)
		var bump := sin(d.x * 5.1 + variant) * sin(d.z * 4.3 + variant * 1.7) + sin(d.y * 6.7 + variant * 0.3) * 0.5
		p *= 1.0 + bump * bumps
		var v := Vector3(p.x * 0.62, p.y * WALL_HEIGHT * 0.5, p.z * 0.62)
		v.y = maxf(v.y, -WALL_HEIGHT * 0.5)  # Flat bottom on the ground.
		verts[i] = v
		normals[i] = Vector3(p.x, p.y * 0.9, p.z).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Puts a power-cube crate on an open floor tile (Showdown on maps without P tiles).
func add_crate(cell: Vector2i) -> Breakable:
	_astar.set_point_solid(cell)
	_swim_astar.set_point_solid(cell)
	rows[cell.y] = rows[cell.y].substr(0, cell.x) + "P" + rows[cell.y].substr(cell.x + 1)
	return _add_breakable(cell, "crate", _crate_material)


## A breakable tile was destroyed: the ground there is open now.
func on_breakable_broken(b: Breakable) -> void:
	_astar.set_point_solid(b.cell, false)
	_swim_astar.set_point_solid(b.cell, false)
	rows[b.cell.y] = rows[b.cell.y].substr(0, b.cell.x) + "." + rows[b.cell.y].substr(b.cell.x + 1)


## Which team defends the goal at `world_pos` (-1 if it isn't in a goal).
func goal_owner(world_pos: Vector3) -> int:
	var cell := world_to_cell(world_pos)
	for team: int in goal_cells:
		if goal_cells[team].has(cell):
			return team
	return -1


## Middle of the goal `team` defends.
func goal_center(team: int) -> Vector3:
	var sum := Vector3.ZERO
	for cell: Vector2i in goal_cells[team]:
		sum += cell_center(cell)
	return sum / maxf(1.0, goal_cells[team].size())


## Spawn for Showdown player `index` of `count`: S tiles, else spread around the map.
func showdown_point(index: int, count: int) -> Vector3:
	if showdown_spawns.size() >= count:
		return showdown_spawns[index]
	var angle := TAU * index / count + 0.4
	var want := Vector3(sin(angle) * width * 0.36, 0, cos(angle) * height * 0.38)
	return nearest_open(want)


## The walkable tile centre closest to `world_pos`.
func nearest_open(world_pos: Vector3) -> Vector3:
	var start := world_to_cell(world_pos)
	for radius in range(0, 12):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := start + Vector2i(dx, dy)
				if _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell) and _char_at(cell) != "\"":
					return cell_center(cell)
	return world_pos


## Spawn point for the `index`-th member of `team`.
func spawn_point(team: int, index: int) -> Vector3:
	var points: Array = spawns[team]
	return points[index % points.size()]


## Walkable route from `from` to `to` as world positions (cell centres),
## excluding the start cell. Empty if there's no route.
## `swim` routes over water too.
func find_path(from: Vector3, to: Vector3, swim := false) -> PackedVector3Array:
	var result := PackedVector3Array()
	var grid := _swim_astar if swim else _astar
	var start := world_to_cell(from)
	var goal := world_to_cell(to)
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(goal):
		return result
	var ids := grid.get_id_path(start, goal, true)
	for i in range(1, ids.size()):
		result.append(cell_center(ids[i]))
	return result


## A random open floor tile (not a wall, water, tall grass or spawn), for item drops.
func random_open_point() -> Vector3:
	for attempt in 60:
		var cell := Vector2i(randi_range(1, width - 2), randi_range(1, height - 2))
		var c := _char_at(cell)
		if c in [".", ",", "Z", "S"] and not _astar.is_point_solid(cell):
			return cell_center(cell)
	return Vector3.ZERO


## The open tile nearest the centre (raid bosses land here).
func center_point() -> Vector3:
	var center := Vector2i(width / 2, height / 2)
	for radius in range(0, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := center + Vector2i(dx, dy)
				if _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell):
					return cell_center(cell)
	return Vector3.ZERO


func is_walkable(world_pos: Vector3, swim := false) -> bool:
	var grid := _swim_astar if swim else _astar
	var cell := world_to_cell(world_pos)
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


func is_water(world_pos: Vector3) -> bool:
	return _char_at(world_to_cell(world_pos)) == "~"


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


## A bush: three crossed upright quads of grass blades, so it looks full from any angle.
func _bush_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := TILE * 0.62
	for i in 3:
		var angle := PI / 3.0 * i
		var side := Vector3(cos(angle), 0, sin(angle)) * half
		var corners := [-side, side, side + Vector3.UP * GRASS_HEIGHT, -side + Vector3.UP * GRASS_HEIGHT]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[index])
			st.add_vertex(corners[index])
	return st.commit()


## Floor tiles next to a wall get a soft dark gradient on that side (fake ambient occlusion).
func _edge_shadows(solid_cells: Dictionary, water_cells: Dictionary) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var sides := { Vector2i(0, -1): 0.0, Vector2i(1, 0): -PI / 2.0, Vector2i(0, 1): PI, Vector2i(-1, 0): PI / 2.0 }
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if solid_cells.has(cell) or water_cells.has(cell):
				continue
			for offset: Vector2i in sides:
				if solid_cells.has(cell + offset):
					result.append(Transform3D(Basis(Vector3.UP, sides[offset]), cell_center(cell) + Vector3(0, 0.012, 0)))
	return result


func _edge_shadow_material() -> StandardMaterial3D:
	var mat := _tile_material("edge_shadow")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _water_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("water_tex", load(TILE_DIR + ("lava.png" if liquid == "lava" else "water.png")))
	return mat


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
	var walk_blocked := solid_cells.duplicate()
	walk_blocked.merge(water_cells)
	_setup_grid(_astar, walk_blocked)
	_setup_grid(_swim_astar, solid_cells)


## Blocked cells are solid; open cells touching one cost more, so routes keep a
## little away from walls instead of scraping corners.
func _setup_grid(grid: AStarGrid2D, blocked: Dictionary) -> void:
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2(TILE, TILE)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for cell: Vector2i in blocked:
		grid.set_point_solid(cell)
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if blocked.has(cell):
				continue
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
					Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if blocked.has(cell + offset):
					grid.set_point_weight_scale(cell, 1.8)
					break


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


## Tile material: one 64px texture per world unit, smooth filtering.
func _tile_material(tile_name: String, triplanar := false, alpha_cut := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TILE_DIR + tile_name + ".png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	if triplanar:
		mat.uv1_triplanar = true
	if alpha_cut:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
