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
const WALL_SHADER := preload("res://assets/shaders/tile_xray.gdshader")
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
## Tint of the distance haze (rules: arena "haze"); alpha 0 = the default light blue.
var haze_color := Color(0, 0, 0, 0)
## Map-wide hazard from the map's "weather" ("" or "lightning").
var weather := ""
## Set by main.gd when the map has hazards (bots ask it what to avoid).
var hazards: Hazards
## Tall grass instances, in the same order as their cells (so Cut can remove them).
var _grass_mm: MultiMeshInstance3D
var _grass_order: Array[Vector2i] = []
var _rock_mesh: Mesh
var _rock_material: Material
var _crate_mesh: BoxMesh
var _crate_material: Material
var _breakable_mesh: Mesh
var _crate_mesh_box: Mesh
## Textures that can be turned any way without looking wrong (no planks, bricks or grid lines).
const ROTATABLE := ["sand", "ice", "dark", "volcanic", "rock", "hedge", "boulder", "ice_block"]
## name -> number of variants (assets/tiles/<name>_v1.png...; tools/make_tile_variants.py).
var _variant_counts := {}
var _wall_materials := {}
## Wall styles drawn as rounded, lumpy shapes (natural things); the rest are
## blocks with rounded edges that join up with the walls next to them.
const ORGANIC_WALLS := ["rock", "hedge", "ice_block", "cracked"]
## How each wall texture is built and shaded (assets/shaders/tile_xray.gdshader):
## radius = how round the exposed edges are; lip / lip_h = a ledge sticking out
## round the top (how far, how tall); cap = texture on top (and on the ledge);
## cap_tint; height_var = up to this much taller per tile; top / side = light on
## the top and sides; edge = highlight on rounded edges; ao = dark base; moss.
const WALL_STYLES := {
	"brick": { "radius": 0.07, "lip": 0.045, "lip_h": 0.15, "cap": "gym_floor", "cap_tint": Color(0.74, 0.72, 0.7),
		"height_var": 0.08, "top": 1.15, "side": 0.86, "moss": 0.55 },
	"wood_wall": { "radius": 0.1, "lip": 0.03, "lip_h": 0.1, "cap": "wood", "cap_tint": Color(0.78, 0.68, 0.58),
		"height_var": 0.12, "top": 1.12, "side": 0.86 },
	"metal_wall": { "radius": 0.05, "lip": 0.025, "lip_h": 0.07, "cap": "metal", "cap_tint": Color(1.12, 1.12, 1.18),
		"height_var": 0.0, "top": 1.1, "side": 0.88, "edge": 0.35, "ao": 0.3 },
	"ice_block": { "cap_tint": Color(1.02, 1.05, 1.08), "top": 1.04, "side": 0.9, "ao": 0.22, "edge": 0.25 },
	"crate": { "radius": 0.06, "height_var": 0.0, "top": 1.1, "side": 0.9 },
	"hedge": { "cap_tint": Color(1.15, 1.22, 0.85), "top": 1.15, "side": 0.85, "ao": 0.45 },
	"rock": { "cap_tint": Color(1.08, 1.06, 1.0), "moss": 0.5 },
	"cracked": { "cap_tint": Color(1.06, 1.04, 1.0), "moss": 0.35 },
	"boulder": { "cap_tint": Color(1.08, 1.06, 1.0), "moss": 0.4 },
}
## Rounded block meshes by "style:neighbour mask".
static var _block_meshes := {}
var _layer_textures := {}
var _breakable_walls := true

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
	_breakable_walls = breakable_walls
	liquid = str(def.get("liquid", "water"))
	weather = str(def.get("weather", ""))
	haze_color = Color.html(str(def["haze"])) if def.has("haze") else Color(0, 0, 0, 0)
	# "lets_go": the 3D Let's Go look (see arena_art.gd) instead of flat tiles and sprites.
	var lets_go := str(def.get("art", "lets_go")) == "lets_go"
	# The blended Let's Go ground replaces grass floors; themed floors (gym tiles,
	# wood, ice...) keep their textures but get the 3D grass, trees and rocks.
	var art_ground := lets_go and floor_tile == "grass"
	var dark_map := floor_tile == "dark"
	var rocky := wall_tile in ["rock", "cracked"]
	var art_cells := { "path": {}, "grass": {} }
	var tree_cells: Array[Vector2i] = []
	var open_cells: Array[Vector2i] = []
	var graves: Array[Transform3D] = []
	var path_blobs: Array[Transform3D] = []

	var floors := {}  # texture name -> Array[Transform3D]
	var floor_shades := {}  # texture name -> Array[Color], one per tile
	var rocks := {}  # wall texture variant -> Array[Transform3D]
	var rock_shades := {}
	var rock_layers := {}  # shape -> Array[float], texture variant per copy
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
			var floor_name := _variant(floor_tile, cell)
			if floor_tile == "grass":
				floor_name = "grass_%d" % posmod(x * 7 + y * 13 + (x * y) % 7, 6)  # Mix of variants.
			if c == ".":
				open_cells.append(cell)
			if c == ",":
				art_cells["path"][cell] = true
				# Paths are soft round patches over the floor rather than square tiles.
				var turn := float(posmod(x * 37 + y * 11, 12)) * PI / 6.0
				var spread := 1.35 + float(posmod(x * 5 + y * 3, 4)) * 0.06
				path_blobs.append(Transform3D(Basis(Vector3.UP, turn).scaled(Vector3(spread, 1, spread)), center + Vector3(0, 0.008, 0)))
			elif c == "~":
				floor_name = "water"
			if not floors.has(floor_name):
				floors[floor_name] = []
				floor_shades[floor_name] = []
			floors[floor_name].append(Transform3D(_turn(floor_tile, cell), center))
			floor_shades[floor_name].append(_shade(cell))
			if c == "#" and breakable_walls and x > 1 and y > 1 and x < width - 2 and y < height - 2:
				# Inner walls break to supers (like Brawl Stars); the map's edge stays solid.
				breakable_cells[cell] = "wall_style"
				c = ""
			match c:
				"T":
					solid_cells[cell] = true
					tree_cells.append(cell)
					# Upright sprite tilted to face the fixed camera; base sits at the tile's front edge.
					var base := center + Vector3(0, 0, TILE * 0.35)
					trees.append(Transform3D(tilt, base + tilt.y * TREE_SPRITE_SIZE.y * 0.5))
				"#":
					solid_cells[cell] = true
					# Grouped by shape (one MultiMesh each); the texture variant goes per copy.
					var shape_key := "lump" if wall_tile in ORGANIC_WALLS else "%d:%d" % [_neighbour_mask(cell), _hidden_mask(cell)]
					if not rocks.has(shape_key):
						rocks[shape_key] = []
						rock_shades[shape_key] = []
						rock_layers[shape_key] = []
					rock_shades[shape_key].append(_shade(cell, 0.7))
					rock_layers[shape_key].append(float(_variant_index(wall_tile, cell)))
					rocks[shape_key].append(Transform3D(_jitter(cell) if wall_tile in ORGANIC_WALLS else _wall_basis(wall_tile, cell), center + Vector3(0, WALL_HEIGHT * 0.5, 0)))
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
					art_cells["grass"][cell] = true
					var yaw := float(posmod(x * 31 + y * 17, 12)) * PI / 6.0
					var bush_scale := 0.95 + float(posmod(x * 13 + y * 7, 5)) * 0.04
					grass.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * bush_scale), center))
					_grass_order.append(cell)
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
		if art_ground and floor_name != "water":
			continue
		var mat: Material = _water_material() if floor_name == "water" else _tile_material(floor_name)
		if floor_name != "water":
			(mat as StandardMaterial3D).vertex_color_use_as_albedo = true
		_add_multimesh(floor_plane, mat, floors[floor_name], true, [] if floor_name == "water" else floor_shades[floor_name])
	if lets_go and get_parent():
		ArenaArt.apply_lighting(get_parent())
	if art_ground:
		var solid_art := solid_cells.duplicate()
		solid_art.merge(breakable_cells)
		art_cells["solid"] = solid_art
		art_cells["water"] = water_cells
		var ground := ArenaArt.build_ground(self, art_cells)
		ground.position.y = 0.001
		add_child(ground)
	else:
		_add_multimesh(floor_plane, _edge_shadow_material(), _edge_shadows(solid_cells, water_cells), false)

	if not path_blobs.is_empty() and not art_ground:
		var blob_mat := _tile_material("path_blob", false, false)
		blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_add_multimesh(floor_plane, blob_mat, path_blobs, false)
	_crate_mesh_box = rounded_block("crate", 0)
	var lump := lump_mesh(0.62, 0.1, 7)
	# Let's Go maps: rock walls, cracked walls and boulders are Rock Smash rocks.
	var rock_mesh: Mesh = ArenaArt.rock_mesh(0) if lets_go else null
	var rock_mat: Material = ArenaArt.vertex_color_material() if lets_go else null
	_rock_mesh = rock_mesh
	_rock_material = rock_mat
	for shape_key: String in rocks:
		if lets_go and rocky:
			_add_multimesh(rock_mesh, rock_mat, rocks[shape_key])
		else:
			var shape: Mesh = lump if shape_key == "lump" else rounded_block(wall_tile, int(shape_key.get_slice(":", 0)), int(shape_key.get_slice(":", 1)))
			_add_multimesh(shape, _wall_material(wall_tile, true), rocks[shape_key], true, rock_shades[shape_key], rock_layers[shape_key])
	_breakable_mesh = lump
	var materials := {
		"cracked": rock_mat if lets_go else _wall_material("cracked"),
		"boulder": rock_mat if lets_go else _wall_material("boulder"),
		"ice_block": _wall_material("ice_block"),
		"wall_style": rock_mat if lets_go and rocky else _wall_material(wall_tile),
		"crate": _wall_material("crate"),
	}
	_crate_material = materials["crate"]
	var variant_of := { "cracked": "cracked", "boulder": "boulder", "ice_block": "ice_block", "wall_style": wall_tile }
	for cell: Vector2i in breakable_cells:
		var kind: String = breakable_cells[cell]
		var material: Material = materials[kind]
		if material is ShaderMaterial and (material as ShaderMaterial).shader == WALL_SHADER and variant_of.has(kind):
			material = _wall_material(_variant(str(variant_of[kind]), cell))
		var b := _add_breakable(cell, "crate" if kind == "crate" else "wall", material)
		if lets_go and (kind in ["cracked", "boulder"] or (kind == "wall_style" and rocky)):
			b.set_mesh(rock_mesh, _jitter(cell))
		elif kind == "wall_style" and wall_tile not in ORGANIC_WALLS:
			b.set_mesh(rounded_block(wall_tile, _neighbour_mask(cell)), _wall_basis(wall_tile, cell))

	if lets_go:
		var clumps: Array[Transform3D] = []
		for t: Transform3D in grass:
			clumps.append(Transform3D(t.basis.scaled(Vector3(1.12, 1.0, 1.12)), t.origin))
		_grass_mm = _add_multimesh(ArenaArt.grass_mesh(), ArenaArt.grass_material(dark_map), clumps)
		var tree_transforms: Array[Transform3D] = []
		for cell in tree_cells:
			var size := 0.95 + ArenaArt._hash(cell, 41) * 0.25
			tree_transforms.append(Transform3D(Basis(Vector3.UP, ArenaArt._hash(cell, 42) * TAU).scaled(Vector3(size, size * (0.95 + ArenaArt._hash(cell, 43) * 0.15), size)), cell_center(cell)))
		_add_multimesh(ArenaArt.tree_mesh(dark_map), ArenaArt.vertex_color_material(), tree_transforms)
		if art_ground:
			for node in ArenaArt.decorations(self, open_cells):
				add_child(node)
	else:
		var grass_mat := ShaderMaterial.new()
		grass_mat.shader = GRASS_SHADER
		grass_mat.set_shader_parameter("blades", load(TILE_DIR + "tall_grass.png"))
		_grass_mm = _add_multimesh(_bush_mesh(), grass_mat, grass)
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
	outside_mat.albedo_color = Color(0.42, 0.6, 0.3) if art_ground else Color(0.55, 0.62, 0.5)
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


## HM Cut: tall grass within `radius` of `center` is cut down for the rest of the match.
func clear_grass(center: Vector3, radius: float) -> int:
	var cut := 0
	for i in _grass_order.size():
		var cell := _grass_order[i]
		if _char_at(cell) != "\"" or cell_center(cell).distance_to(Vector3(center.x, 0, center.z)) > radius:
			continue
		rows[cell.y] = rows[cell.y].substr(0, cell.x) + "." + rows[cell.y].substr(cell.x + 1)
		if _grass_mm:
			_grass_mm.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), cell_center(cell)))
		Vfx.burst(self, cell_center(cell) + Vector3(0, 0.4, 0), "grass", 8, 0.4, 2.5)
		cut += 1
	return cut


## HM Strength: slides a boulder (or other breakable) one tile along `direction`
## if the tile there is open. Returns whether it moved.
func push_breakable(b: Breakable, direction: Vector3) -> bool:
	var step := Vector2i(roundi(direction.x), roundi(direction.z))
	if absf(direction.x) > absf(direction.z):
		step = Vector2i(signi(roundi(direction.x * 2.0)), 0)
	else:
		step = Vector2i(0, signi(roundi(direction.z * 2.0)))
	if step == Vector2i.ZERO:
		return false
	var to := b.cell + step
	if to.x < 0 or to.y < 0 or to.x >= width or to.y >= height or _char_at(to) not in [".", ","] or not is_walkable(cell_center(to)):
		return false
	for node in get_tree().get_nodes_in_group("brawlers"):
		if world_to_cell((node as Node3D).global_position) == to:
			return false
	var old := b.cell
	var old_char := _char_at(old)
	rows[old.y] = rows[old.y].substr(0, old.x) + "." + rows[old.y].substr(old.x + 1)
	rows[to.y] = rows[to.y].substr(0, to.x) + old_char + rows[to.y].substr(to.x + 1)
	_astar.set_point_solid(old, false)
	_swim_astar.set_point_solid(old, false)
	_astar.set_point_solid(to)
	_swim_astar.set_point_solid(to)
	b.cell = to
	var tween := b.create_tween()
	tween.tween_property(b, "position", cell_center(to), 0.25).set_trans(Tween.TRANS_QUAD)
	return true


## Brawl Ball: rocks narrow each goal mouth like in Brawl Stars. On the front
## row of a goal 6+ tiles wide, the outer two tiles each side become breakable
## rocks, so the opening is 4 wide until physical supers smash them.
func block_goal_sides() -> void:
	var mid := height >> 1
	for team: int in goal_cells:
		var cells: Dictionary = goal_cells[team]
		if cells.size() < 6:
			continue
		var min_x := 9999
		var max_x := -9999
		var ys := {}
		for cell: Vector2i in cells:
			min_x = mini(min_x, cell.x)
			max_x = maxi(max_x, cell.x)
			ys[cell.y] = true
		if max_x - min_x + 1 < 6:
			continue
		# The goal row closest to the middle of the map, then one step toward it.
		var front := 0
		var best := 9999
		for y: int in ys:
			if absi(y - mid) < best:
				best = absi(y - mid)
				front = y
		for x in [min_x, min_x + 1, max_x - 1, max_x]:
			var cell := Vector2i(x, front)
			if _char_at(cell) != "G" or _astar.is_point_solid(cell):
				continue
			cells.erase(cell)
			var b := _add_breakable(cell, "wall", _rock_material if _rock_material else _wall_material("boulder"))
			if _rock_mesh:
				b.set_mesh(_rock_mesh, _jitter(cell))
			rows[cell.y] = rows[cell.y].substr(0, cell.x) + "B" + rows[cell.y].substr(cell.x + 1)
			_astar.set_point_solid(cell)
			_swim_astar.set_point_solid(cell)


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


## `colors` (optional, one per transform) tints each copy: used to shade tiles.
## `layers` (optional): texture variant per copy (walls).
func _add_multimesh(mesh: Mesh, material: Material, transforms: Array, shadows := true, colors: Array = [], layers: Array = []) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.use_custom_data = not layers.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, Color(float(layers[i]), 0, 0, 0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Wall / block material: the tile texture projected from three sides, and
## see-through when it hides your Pokémon.
## `tile_name` may be a variant ("brick_v2"). `per_copy`: the variant comes from
## each MultiMesh copy instead (one material, and one draw, for every variant).
func _wall_material(tile_name: String, per_copy := false) -> ShaderMaterial:
	var key := tile_name + ("*" if per_copy else "")
	if _wall_materials.has(key):
		return _wall_materials[key]
	var base := tile_name
	var layer := 0
	var m := RegEx.create_from_string("^(.*)_v(\\d+)$").search(tile_name)
	if m:
		base = m.get_string(1)
		layer = int(m.get_string(2))
	var style: Dictionary = WALL_STYLES.get(base, {})
	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	mat.set_shader_parameter("albedo_layers", _layers(base))
	mat.set_shader_parameter("fixed_layer", -1.0 if per_copy else float(layer))
	if style.has("cap"):
		mat.set_shader_parameter("cap_tex", load(TILE_DIR + str(style["cap"]) + ".png"))
		mat.set_shader_parameter("has_cap_tex", true)
	mat.set_shader_parameter("cap_tint", style.get("cap_tint", Color(1.08, 1.08, 1.08)))
	mat.set_shader_parameter("cap_band", float(style.get("lip_h", 0.0)))
	mat.set_shader_parameter("half_height", WALL_HEIGHT * 0.5)
	mat.set_shader_parameter("top_light", float(style.get("top", 1.12)))
	mat.set_shader_parameter("side_light", float(style.get("side", 0.9)))
	mat.set_shader_parameter("edge_light", float(style.get("edge", 0.2)))
	mat.set_shader_parameter("base_ao", float(style.get("ao", 0.35)))
	mat.set_shader_parameter("moss", float(style.get("moss", 0.0)))
	_wall_materials[key] = mat
	return mat


## The texture and its variants as one texture array (layer 0 = original).
func _layers(base: String) -> Texture2DArray:
	if _layer_textures.has(base):
		return _layer_textures[base]
	var images: Array[Image] = []
	var names: Array[String] = [base]
	_variant(base, Vector2i.ZERO)  # Counts the variants.
	for i in int(_variant_counts.get(base, 0)):
		names.append("%s_v%d" % [base, i + 1])
	for n in names:
		var img := (load(TILE_DIR + n + ".png") as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if images.size() > 0 and img.get_size() != images[0].get_size():
			img.resize(images[0].get_width(), images[0].get_height())
		img.generate_mipmaps()
		images.append(img)
	var arr := Texture2DArray.new()
	arr.create_from_images(images)
	_layer_textures[base] = arr
	return arr


## Which texture variant a wall at `cell` uses (0 = the original).
func _variant_index(tile_name: String, cell: Vector2i) -> int:
	var picked := _variant(tile_name, cell)
	return 0 if picked == tile_name else int(picked.get_slice("_v", picked.get_slice_count("_v") - 1))


## Neighbours (same bits as _neighbour_mask) that are permanent walls: the sides
## against them are never seen, so the mesh leaves them out.
func _hidden_mask(cell: Vector2i) -> int:
	var mask := 0
	for entry: Array in [[Vector2i(1, 0), 1], [Vector2i(-1, 0), 2], [Vector2i(0, 1), 4], [Vector2i(0, -1), 8]]:
		var n := cell + (entry[0] as Vector2i)
		var inner := n.x > 1 and n.y > 1 and n.x < width - 2 and n.y < height - 2
		if _char_at(n) == "#" and not (_breakable_walls and inner):
			mask |= int(entry[1])
	return mask


## Which of the four neighbours are the same kind of wall: 1 east, 2 west, 4 south, 8 north.
func _neighbour_mask(cell: Vector2i) -> int:
	var own := _char_at(cell)
	var mask := 0
	for entry: Array in [[Vector2i(1, 0), 1], [Vector2i(-1, 0), 2], [Vector2i(0, 1), 4], [Vector2i(0, -1), 8]]:
		if _char_at(cell + (entry[0] as Vector2i)) == own:
			mask |= int(entry[1])
	return mask


## A little taller per tile (never shorter, so it always sits on the floor), for
## styles with height_var: brick tops step up and down, wood looks hand-built.
func _wall_basis(tile_name: String, cell: Vector2i) -> Basis:
	var vary := float((WALL_STYLES.get(tile_name, {}) as Dictionary).get("height_var", 0.0))
	return Basis.from_scale(Vector3(1.0, 1.0 + _cell_hash(cell, 53) * vary, 1.0))


## A wall block with rounded edges, except on sides that join another wall
## (`mask`: 1 east, 2 west, 4 south, 8 north), so a run of walls reads as one piece.
## Styles with a lip get a ledge sticking out round the top. Centred like a
## TILE x WALL_HEIGHT x TILE box. Cached per style and mask.
## `hidden`: sides against a wall that never breaks, which are left out.
static func rounded_block(style_name: String, mask: int, hidden := 0) -> ArrayMesh:
	var key := "%s:%d:%d" % [style_name, mask, hidden]
	if _block_meshes.has(key):
		return _block_meshes[key]
	var style: Dictionary = WALL_STYLES.get(style_name, {})
	var r := float(style.get("radius", 0.06))
	var lip := float(style.get("lip", 0.0))
	var lip_h := float(style.get("lip_h", 0.0))
	var hh := WALL_HEIGHT * 0.5
	var half := TILE * 0.5
	var lo := Vector3(-half if mask & 2 else -half + r, -hh, -half if mask & 8 else -half + r)
	var hi := Vector3(half if mask & 1 else half - r, hh - r, half if mask & 4 else half - r)
	var steps := 3
	var across := PackedFloat32Array()  # x and z grid: only the curved bands need points
	for k in steps + 1:
		across.append(-half + r * k / steps)
	for k in steps + 1:
		across.append(half - r * (steps - k) / steps)
	var up := PackedFloat32Array([-hh])
	if lip > 0.0:
		up.append(hh - lip_h - 0.004)
		up.append(hh - lip_h)
	for k in steps + 1:
		up.append(hh - r * (steps - k) / steps)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	# (normal, u axis, v axis) with u x v = normal; the floor side is never seen.
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.BACK, Vector3.RIGHT, Vector3.UP],
			[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	var side_bits := { Vector3.RIGHT: 1, Vector3.LEFT: 2, Vector3.BACK: 4, Vector3.FORWARD: 8 }
	for f: Array in faces:
		var nrm: Vector3 = f[0]
		if hidden & int(side_bits.get(nrm, 0)):
			continue
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var us := up if absf(u.y) > 0.5 else across
		var vs := up if absf(v.y) > 0.5 else across
		var depth := hh if absf(nrm.y) > 0.5 else half
		var start := verts.size()
		for i in us.size():
			for j in vs.size():
				var p := nrm * depth + u * us[i] + v * vs[j]
				var inner := p.clamp(lo, hi)
				var d := p - inner
				var n := nrm
				if d.length() > 0.00001:
					n = d.normalized()
					p = inner + n * r
				if lip > 0.0 and p.y >= hh - lip_h - 0.001:
					if not mask & 1 and p.x >= half - r - 0.001:
						p.x += lip
					if not mask & 2 and p.x <= -half + r + 0.001:
						p.x -= lip
					if not mask & 4 and p.z >= half - r - 0.001:
						p.z += lip
					if not mask & 8 and p.z <= -half + r + 0.001:
						p.z -= lip
				verts.append(p)
				normals.append(n)
		var cols := vs.size()
		for i in us.size() - 1:
			for j in cols - 1:
				var a := start + i * cols + j
				var b := a + cols
				# Clockwise seen from outside (Godot's front faces).
				indices.append_array([a, b + 1, b, a, a + 1, b + 1])
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_block_meshes[key] = mesh
	return mesh


## The texture to use for `tile_name` at `cell`: the original about 40% of the time,
## otherwise one of its variants. Fixed per cell, so a map always looks the same.
func _variant(tile_name: String, cell: Vector2i) -> String:
	if not _variant_counts.has(tile_name):
		var n := 0
		while ResourceLoader.exists("%s%s_v%d.png" % [TILE_DIR, tile_name, n + 1]):
			n += 1
		_variant_counts[tile_name] = n
	var count: int = _variant_counts[tile_name]
	if count == 0:
		return tile_name
	var h := posmod(cell.x * 73856093 ^ cell.y * 19349663, 1000)
	if h < 250:
		return tile_name
	return "%s_v%d" % [tile_name, 1 + (h - 250) * count / 750]


## How light or dark the tile at `cell` is: soft patches a few tiles across (smooth
## noise) plus a little per tile, with a faint warm/cool drift. `amount` scales it.
func _shade(cell: Vector2i, amount := 1.0) -> Color:
	var patch := _smooth_noise(Vector2(cell) / 4.5, 11) * 0.65 + _smooth_noise(Vector2(cell) / 2.0, 23) * 0.35
	var each := _cell_hash(cell, 31) - 0.5
	var k := 1.0 + ((patch - 0.5) * 0.2 + each * 0.07) * amount
	var warm := (_smooth_noise(Vector2(cell) / 6.0, 47) - 0.5) * 0.06 * amount
	return Color(k * (1.0 + warm), k, k * (1.0 - warm))


func _cell_hash(cell: Vector2i, seed: int) -> float:
	return float(posmod((cell.x + seed * 101) * 73856093 ^ (cell.y - seed * 37) * 19349663, 1009)) / 1008.0


func _smooth_noise(p: Vector2, seed: int) -> float:
	var i := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(i)
	f = f * f * (Vector2(3, 3) - f * 2.0)
	var a := _cell_hash(i, seed)
	var b := _cell_hash(i + Vector2i(1, 0), seed)
	var c := _cell_hash(i + Vector2i(0, 1), seed)
	var d := _cell_hash(i + Vector2i(1, 1), seed)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## A quarter-turn per cell for textures that look fine any way round.
func _turn(tile_name: String, cell: Vector2i) -> Basis:
	if tile_name not in ROTATABLE:
		return Basis()
	return Basis(Vector3.UP, float(posmod(cell.x * 31 + cell.y * 17 + cell.x * cell.y, 4)) * PI * 0.5)


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
