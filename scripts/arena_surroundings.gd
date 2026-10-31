class_name ArenaSurroundings
extends RefCounted
## Decorations outside the play area, so the edges of the screen show a place
## instead of empty ground (arena "surroundings" in data/arenas/*.json):
## - "stadium" (gyms, Elite Four): tiered stands round the map in the gym's type
##   colour, packed with a cheering crowd (one MultiMesh, assets/shaders/crowd.gdshader;
##   our own spectators plus fan-made ones, packed by tools/make_crowd.py).
## - "ship" (S.S. Anne): white railings on the deck's edge, the hull dropping to
##   the sea, a pointed bow, and a wooden dock alongside.
## Nothing here blocks or collides: it's all looks.

const CROWD_SHADER := preload("res://assets/shaders/crowd.gdshader")
const CROWD_TEXTURE := preload("res://assets/crowd/trainers.png")
## Each look is one row of CROWD_CELL-pixel frames (tools/make_crowd.py); one
## sprite pixel is 5 cm in the world, so fans stand about as tall as a Pokémon.
const CROWD_CELL := Vector2(28, 34)
const SPECTATOR_SIZE := CROWD_CELL * 0.05

## Stand tiers: how many, how deep and how much higher each one is.
const TIERS := 3
const TIER_DEPTH := 1.5
const TIER_RISE := 0.7
## Gap between the map's edge and the first tier.
const STAND_GAP := 0.7

## Elite Four rooms and other non-gym arenas: their stands' colours by type.
const ARENA_TYPES := { "lorelei_chamber": "ice", "bruno_dojo": "fighting", "agatha_crypt": "ghost",
		"lance_hall": "dragon", "dragons_den": "dragon", "boulder_gym": "rock" }

const RAIL_WHITE := Color(0.95, 0.95, 0.92)
const HULL_DARK := Color(0.12, 0.16, 0.3)
const HULL_STRIPE := Color(0.75, 0.15, 0.15)

static var _railings := {}
static var _painted: StandardMaterial3D


static func build(arena: Arena, arena_id: String, tilt: Basis, railings: Array[Vector2i]) -> void:
	match arena.surroundings:
		"stadium":
			_stadium(arena, arena_id, tilt)
		"ship":
			_ship(arena, railings)


# --- Stadium -----------------------------------------------------------------

static func _stadium(arena: Arena, arena_id: String, tilt: Basis) -> void:
	var type_name := str(ARENA_TYPES.get(arena_id, ""))
	var gym: Dictionary = (GameData.gyms.get("gyms", {}) as Dictionary).get(arena_id, {})
	if type_name == "":
		type_name = str(gym.get("type", "normal"))
	var seat := GameData.type_color(type_name)
	var half := arena.world_size() * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var concrete := Color(0.55, 0.56, 0.6)
	var spots: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(arena_id)
	# Four sides: (outward direction, length along the side).
	for side: Array in [[Vector3.FORWARD, half.x], [Vector3.BACK, half.x], [Vector3.LEFT, half.y], [Vector3.RIGHT, half.y]]:
		var out: Vector3 = side[0]
		var along := Vector3(absf(out.z), 0, absf(out.x))  # Runs along the side.
		var edge := half.y if absf(out.z) > 0.5 else half.x
		for i in TIERS:
			var near := edge + STAND_GAP + i * TIER_DEPTH
			var top := (i + 1) * TIER_RISE
			var reach: float = float(side[1]) + STAND_GAP + (i + 1) * TIER_DEPTH  # Overlaps at the corners.
			var centre := out * (near + TIER_DEPTH * 0.5)
			var size := along * reach * 2.0 + Vector3(absf(out.x), 0, absf(out.z)) * TIER_DEPTH
			_box(st, centre + Vector3(0, top * 0.5, 0), Vector3(size.x, top, size.z), concrete.darkened(0.06 * i))
			# Seats: a coloured strip on each step, alternating shades.
			var seat_size := Vector3(size.x, 0.08, size.z) - Vector3(absf(out.x), 0, absf(out.z)) * TIER_DEPTH * 0.45
			_box(st, centre + out * TIER_DEPTH * 0.12 + Vector3(0, top + 0.04, 0), seat_size, seat.darkened(0.25 if i % 2 else 0.0))
			# Spectators along the step (most seats taken).
			var count := int(reach * 2.0 / 0.9)
			for k in count:
				if rng.randf() > 0.72:
					continue
				var t := -reach + (k + 0.5) * (reach * 2.0 / count) + rng.randf_range(-0.12, 0.12)
				var at := along * t + out * (near + TIER_DEPTH * 0.55) + Vector3(0, top + 0.08 + SPECTATOR_SIZE.y * 0.5, 0)
				spots.append(Transform3D(tilt, at))
		# A wall behind the top tier closes the stands off.
		var back := edge + STAND_GAP + TIERS * TIER_DEPTH + 0.15
		var wall_len := float(side[1]) + STAND_GAP + TIERS * TIER_DEPTH + 0.3
		var wall_size := along * wall_len * 2.0 + Vector3(absf(out.x), 0, absf(out.z)) * 0.3
		var wall_h := TIERS * TIER_RISE + 0.9
		_box(st, out * back + Vector3(0, wall_h * 0.5, 0), Vector3(wall_size.x, wall_h, wall_size.z), seat.darkened(0.55))
		# The low barrier in front of the first row.
		var front := edge + STAND_GAP * 0.5
		var barrier := along * (float(side[1]) + STAND_GAP) * 2.0 + Vector3(absf(out.x), 0, absf(out.z)) * 0.12 + Vector3(0, 0.44, 0)
		_box(st, out * front + Vector3(0, 0.22, 0), barrier, seat.darkened(0.1))
	st.generate_normals()
	var stands := MeshInstance3D.new()
	stands.mesh = st.commit()
	stands.material_override = _vertex_color_material()
	arena.add_child(stands)
	_crowd(arena, spots, rng)


## The spectators: one MultiMesh of quads, each with its own look and rhythm.
static func _crowd(arena: Arena, spots: Array[Transform3D], rng: RandomNumberGenerator) -> void:
	if spots.is_empty():
		return
	var looks := maxi(1, int(CROWD_TEXTURE.get_height() / CROWD_CELL.y))
	var quad := QuadMesh.new()
	quad.size = SPECTATOR_SIZE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
		mm.set_instance_custom_data(i, Color(float(rng.randi_range(0, looks - 1)), rng.randf(), rng.randf(), 0))
	var mat := ShaderMaterial.new()
	mat.shader = CROWD_SHADER
	mat.set_shader_parameter("atlas", CROWD_TEXTURE)
	mat.set_shader_parameter("looks", float(looks))
	mat.set_shader_parameter("excitement", 0.6)
	var crowd := MultiMeshInstance3D.new()
	crowd.name = "Crowd"
	crowd.multimesh = mm
	crowd.material_override = mat
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(crowd)


## The crowd goes wild for a moment (a KO, a goal).
static func cheer(arena: Arena) -> void:
	if arena == null:
		return
	var crowd := arena.get_node_or_null("Crowd") as MultiMeshInstance3D
	if crowd == null:
		return
	var mat := crowd.material_override as ShaderMaterial
	var tween := crowd.create_tween()
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("excitement", v), 1.0, 1.0, 1.6)
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("excitement", v), 1.0, 0.6, 0.8)


# --- Ship --------------------------------------------------------------------

static func _ship(arena: Arena, railings: Array[Vector2i]) -> void:
	# Railings on the permanent edge (breakable ones already wear a railing mesh).
	var by_mask := {}
	for cell in railings:
		var b := false
		for node in arena.get_children():
			if node is Breakable and (node as Breakable).cell == cell:
				b = true
				break
		if b:
			continue
		var mask := arena._railing_mask(cell)
		if not by_mask.has(mask):
			by_mask[mask] = []
		(by_mask[mask] as Array).append(Transform3D(Basis(), arena.cell_center(cell) + Vector3(0, Arena.WALL_HEIGHT * 0.5, 0)))
	for mask: int in by_mask:
		arena._add_multimesh(railing_mesh(mask), painted_material(), by_mask[mask])
	# The hull: from the deck's edge down into the sea, wherever deck meets water.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drop := arena.water_drop + 0.5
	var sea := func(c: Vector2i) -> bool:
		if c.x < 0 or c.y < 0 or c.x >= arena.width or c.y >= arena.height:
			return true
		var ch := arena._char_at(c)
		return ch == "~" or arena._ship_edge(c) == "hidden"
	for cell in railings:
		var centre := arena.cell_center(cell)
		for entry: Array in [[Vector2i(1, 0), Vector3.RIGHT], [Vector2i(-1, 0), Vector3.LEFT], [Vector2i(0, 1), Vector3.BACK], [Vector2i(0, -1), Vector3.FORWARD]]:
			if not sea.call(cell + (entry[0] as Vector2i)):
				continue
			var out: Vector3 = entry[1]
			var side := Vector3(out.z, 0, -out.x) * Arena.TILE * 0.5
			var base := centre + out * Arena.TILE * 0.5
			_quad(st, base - side, base + side, -0.04, -0.16, out, HULL_STRIPE)
			_quad(st, base - side, base + side, -0.16, -drop, out, HULL_DARK)
			_quad(st, base - side, base + side, 0.0, -0.04, out, RAIL_WHITE)
	_bow(arena, st)
	st.generate_normals()
	var hull := MeshInstance3D.new()
	hull.mesh = st.commit()
	hull.material_override = _vertex_color_material()
	arena.add_child(hull)
	_dock(arena)
	_buoys(arena)


## The bow: a pointed deck past the far end, with railings down both sides.
static func _bow(arena: Arena, hull: SurfaceTool) -> void:
	var deck := _deck_span(arena)
	if deck.y <= deck.x:
		return
	var z := -arena.world_size().y * 0.5
	var left := Vector3(deck.x, 0, z)
	var right := Vector3(deck.y, 0, z)
	var tip := Vector3((deck.x + deck.y) * 0.5, 0, z - (deck.y - deck.x) * 0.45)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load(Arena.TILE_DIR + "wood.png")
	wood.uv1_triplanar = true
	wood.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for p in [left, tip, right]:
		st.add_vertex(p + Vector3(0, -0.01, 0))
	var bow := MeshInstance3D.new()
	bow.mesh = st.commit()
	bow.material_override = wood
	arena.add_child(bow)
	var drop := arena.water_drop + 0.5
	for edge: Array in [[left, tip], [tip, right]]:
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var out := (b - a).cross(Vector3.UP).normalized() * -1.0
		_quad(hull, a, b, -0.04, -0.16, out, HULL_STRIPE)
		_quad(hull, a, b, -0.16, -drop, out, HULL_DARK)
		_quad(hull, a, b, 0.0, -0.04, out, RAIL_WHITE)
		# Railing posts and a top rail along the bow.
		var length := a.distance_to(b)
		var dir := (b - a) / length
		var posts := int(length / 0.9)
		var rail := SurfaceTool.new()
		rail.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in posts + 1:
			var p := a + dir * (k * length / posts) - out * 0.1
			_box(rail, p + Vector3(0, 0.45, 0), Vector3(0.1, 0.9, 0.1), RAIL_WHITE)
		var mid := (a + b) * 0.5 - out * 0.1
		var basis := Basis.looking_at(dir, Vector3.UP)
		for h in [0.88, 0.5]:
			_box_basis(rail, mid + Vector3(0, h, 0), Vector3(0.07, 0.07, length), basis, RAIL_WHITE)
		rail.generate_normals()
		var rails := MeshInstance3D.new()
		rails.mesh = rail.commit()
		rails.material_override = _vertex_color_material()
		arena.add_child(rails)


## x range of the deck (inside its edge railings) at the far end of the map.
static func _deck_span(arena: Arena) -> Vector2:
	var first := -1
	var last := -1
	for x in arena.width:
		if arena._ship_edge(Vector2i(x, 0)) == "railing":
			if first < 0:
				first = x
			last = x
	if first < 0:
		return Vector2.ZERO
	return Vector2(arena.cell_center(Vector2i(first, 0)).x - 0.5, arena.cell_center(Vector2i(last, 0)).x + 0.5)


## A wooden dock alongside the left of the ship: planks on posts, bollards, crates.
static func _dock(arena: Arena) -> void:
	var half := arena.world_size() * 0.5
	var x0 := -half.x - 0.6
	var length := minf(half.y * 1.2, 22.0)
	var width := 5.0
	var top := -arena.water_drop + 0.2
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plank := Color(0.55, 0.38, 0.22)
	var post := Color(0.35, 0.24, 0.15)
	var count := int(length / 0.45)
	for k in count:
		var z := -length * 0.5 + (k + 0.5) * length / count
		_box(st, Vector3(x0 - width * 0.5, top - 0.06, z), Vector3(width, 0.12, length / count - 0.05), plank.darkened(0.08 * (k % 3)))
	for zi in 6:
		for xi in 2:
			var p := Vector3(x0 - 0.2 - xi * (width - 0.4), top - 0.6, -length * 0.5 + zi * length / 5.0)
			_box(st, p, Vector3(0.28, 1.2, 0.28), post)
	for zi in 4:  # Bollards on the edge by the ship.
		_box(st, Vector3(x0 - 0.45, top + 0.18, -length * 0.4 + zi * length * 0.27), Vector3(0.3, 0.36, 0.3), Color(0.2, 0.2, 0.22))
	st.generate_normals()
	var dock := MeshInstance3D.new()
	dock.mesh = st.commit()
	dock.material_override = _vertex_color_material()
	arena.add_child(dock)
	# Cargo crates waiting to be loaded.
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_texture = load(Arena.TILE_DIR + "crate.png")
	crate_mat.uv1_triplanar = true
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.9, 0.9)
	var crates: Array[Transform3D] = []
	for p: Vector3 in [Vector3(-2.6, 0, -3.0), Vector3(-3.5, 0, -3.1), Vector3(-3.0, 0.9, -3.0), Vector3(-2.8, 0, 4.2), Vector3(-3.9, 0, 6.5)]:
		crates.append(Transform3D(Basis(Vector3.UP, p.z * 0.3), Vector3(x0 + p.x, top + 0.45 + p.y, p.z)))
	arena._add_multimesh(box, crate_mat, crates)


## A few red-and-white buoys out at sea on the other side.
static func _buoys(arena: Arena) -> void:
	var half := arena.world_size() * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-14.0, -2.0, 11.0]:
		var p := Vector3(half.x + 3.5 + absf(z) * 0.08, -arena.water_drop, z)
		_box(st, p + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, 0.5), Color(0.85, 0.15, 0.15))
		_box(st, p + Vector3(0, 0.4, 0), Vector3(0.36, 0.2, 0.36), RAIL_WHITE)
		_box(st, p + Vector3(0, 0.6, 0), Vector3(0.12, 0.25, 0.12), Color(0.85, 0.15, 0.15))
	st.generate_normals()
	var buoys := MeshInstance3D.new()
	buoys.mesh = st.commit()
	buoys.material_override = _vertex_color_material()
	arena.add_child(buoys)


## One railing tile: a post in the middle and rails out to each joined neighbour
## (1 east, 2 west, 4 south, 8 north), centred like a wall block.
static func railing_mesh(mask: int) -> ArrayMesh:
	if _railings.has(mask):
		return _railings[mask]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var floor_y := -Arena.WALL_HEIGHT * 0.5
	_box(st, Vector3(0, floor_y + 0.47, 0), Vector3(0.12, 0.94, 0.12), RAIL_WHITE)
	var any := false
	for entry: Array in [[1, Vector3.RIGHT], [2, Vector3.LEFT], [4, Vector3.BACK], [8, Vector3.FORWARD]]:
		if not mask & int(entry[0]):
			continue
		any = true
		var d: Vector3 = entry[1]
		var size := Vector3(0.5 if absf(d.x) > 0.5 else 0.07, 0.07, 0.5 if absf(d.z) > 0.5 else 0.07)
		for h in [0.9, 0.5]:
			_box(st, d * 0.25 + Vector3(0, floor_y + h, 0), size, RAIL_WHITE)
		_box(st, d * 0.25 + Vector3(0, floor_y + 0.06, 0), Vector3(size.x, 0.12, size.z) + Vector3(0.04, 0, 0.04) * Vector3(absf(d.z), 0, absf(d.x)), Color(0.55, 0.4, 0.25))
	if not any:
		_box(st, Vector3(0, floor_y + 0.9, 0), Vector3(0.5, 0.07, 0.07), RAIL_WHITE)
	st.generate_normals()
	var mesh := st.commit()
	_railings[mask] = mesh
	return mesh


static func painted_material() -> StandardMaterial3D:
	if _painted == null:
		_painted = _vertex_color_material()
	return _painted


static func _vertex_color_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Hand-built boxes: never mind which way they're wound.
	return mat


# --- Geometry helpers ----------------------------------------------------------

static func _box(st: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	_box_basis(st, centre, size, Basis(), color)


static func _box_basis(st: SurfaceTool, centre: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		var c := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		corners.append(centre + basis * c)
	# Faces as corner indices, wound clockwise seen from outside.
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	st.set_color(color)
	for f: Array in faces:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var c: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		for p in [a, b, c, a, c, d]:
			st.add_vertex(p)


## A vertical strip from `a` to `b` (on the ground plane) between heights y0 and
## y1, facing `out`.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, y0: float, y1: float, out: Vector3, color: Color) -> void:
	var p := [a + Vector3(0, y0, 0), b + Vector3(0, y0, 0), b + Vector3(0, y1, 0), a + Vector3(0, y1, 0)]
	# Wind so the front faces `out`.
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if n.dot(out) > 0.0:
		p = [p[0], p[3], p[2], p[1]]
	st.set_color(color)
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(p[i])
