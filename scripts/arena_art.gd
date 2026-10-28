class_name ArenaArt
extends RefCounted
## "Let's Go" art style for outdoor maps (an arena with "art": "lets_go"):
## one blended ground with soft dirt paths and shorelines, leafy 3D tall grass,
## rounded 3D trees, chunky faceted Rock Smash rocks, flowers and grass tufts.
## Everything is built from code (no imported models) and coloured with vertex
## colours, so it stays light enough for phones.

const GROUND_SHADER := preload("res://assets/shaders/ground_lets_go.gdshader")
const LEAFY_SHADER := preload("res://assets/shaders/leafy_grass.gdshader")
const MODEL_SHADER := preload("res://assets/shaders/vertex_color_xray.gdshader")
## Splat texture pixels per tile (upscaled smoothly, so edges come out soft and round).
const SPLAT_RES := 4


## The whole floor as one plane. `cells` maps a layer name ("path", "water",
## "solid", "grass") to a Dictionary of Vector2i cells.
static func build_ground(arena: Arena, cells: Dictionary) -> MeshInstance3D:
	# One pixel per tile, then a smooth (cubic) upscale: soft, rounded edges
	# without blurring pixel by pixel in script, which would be slow on phones.
	var img := Image.create(arena.width, arena.height, false, Image.FORMAT_RGBA8)
	var layers := ["path", "water", "solid", "grass"]
	for y in arena.height:
		for x in arena.width:
			var c := Color(0, 0, 0, 0)
			for i in layers.size():
				var layer_cells: Dictionary = cells.get(layers[i], {})
				if layer_cells.has(Vector2i(x, y)):
					c[i] = 1.0
			img.set_pixel(x, y, c)
	img.resize(arena.width * SPLAT_RES, arena.height * SPLAT_RES, Image.INTERPOLATE_CUBIC)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("splat", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("map_size", arena.world_size())
	var plane := PlaneMesh.new()
	plane.size = arena.world_size()
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ground


## Warm, sunny lighting to go with the art: less blue sky light, so dirt stays
## tan and rocks stay brown. Works on a copy, so other maps keep the default.
static func apply_lighting(main: Node) -> void:
	var world := main.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		var env := world.environment.duplicate() as Environment
		env.ambient_light_color = Color(1.0, 0.96, 0.88)
		env.ambient_light_sky_contribution = 0.3
		env.ambient_light_energy = 0.75
		env.adjustment_saturation = 1.05
		world.environment = env
	var sun := main.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		sun.light_color = Color(1.0, 0.95, 0.84)
		sun.light_energy = 1.15


static func _hash(cell: Vector2i, salt: int) -> float:
	return posmod(cell.x * 73856093 ^ cell.y * 19349663 ^ salt * 83492791, 1000) / 1000.0


# --- Tall grass ------------------------------------------------------------------

## A clump of broad, pointed leaves filling about one tile.
static func grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var root_color := Color(0.08, 0.24, 0.1)
	for i in 34:
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * 0.46
		var base := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var out_dir := Vector3(cos(angle), 0, sin(angle)) if dist > 0.05 else Vector3(cos(angle + 1.0), 0, sin(angle + 1.0))
		var height := rng.randf_range(0.62, 0.98)
		var lean := rng.randf_range(0.12, 0.3)
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0, sin(facing)) * rng.randf_range(0.09, 0.13)
		var mid := base + out_dir * lean * 0.45 + Vector3(0, height * 0.55, 0)
		var tip := base + out_dir * lean + Vector3(0, height, 0)
		var shade := rng.randf_range(0.85, 1.1)
		var tip_color := Color(0.36, 0.64, 0.22) * shade
		var mid_color := root_color.lerp(tip_color, 0.6)
		var normal := (Vector3.UP * 1.5 + out_dir).normalized()
		# Root → widest point → tip: two quads' worth of triangles.
		var verts := [base - side * 0.6, base + side * 0.6, mid - side, mid + side, tip]
		var colors := [root_color, root_color, mid_color, mid_color, tip_color]
		var vs := [1.0, 1.0, 0.45, 0.45, 0.0]
		for tri in [[0, 1, 3], [0, 3, 2], [2, 3, 4]]:
			for k: int in tri:
				st.set_color(colors[k])
				st.set_normal(normal)
				st.set_uv(Vector2(0.5, vs[k]))
				st.add_vertex(verts[k])
	return st.commit()


## `dark`: the gloomier grass of the graveyard and crypt.
static func grass_material(dark := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = LEAFY_SHADER
	if dark:
		mat.set_shader_parameter("tint", Color(0.42, 0.5, 0.55))
	return mat


## Short tufts and little flowers scattered over open grass, for texture.
static func decorations(arena: Arena, open_cells: Array[Vector2i]) -> Array[Node3D]:
	var tufts: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var palette := [Color(0.95, 0.3, 0.25), Color(1.0, 0.75, 0.2), Color(1, 1, 0.95), Color(0.95, 0.5, 0.7)]
	for cell in open_cells:
		var center := arena.cell_center(cell)
		if _hash(cell, 1) < 0.2:
			var offset := Vector3(_hash(cell, 2) - 0.5, 0, _hash(cell, 3) - 0.5) * 0.7
			tufts.append(Transform3D(Basis(Vector3.UP, _hash(cell, 4) * TAU).scaled(Vector3(0.38, 0.26, 0.38)), center + offset))
		if _hash(cell, 5) < 0.07:
			var color: Color = palette[int(_hash(cell, 6) * palette.size()) % palette.size()]
			for k in 3 + int(_hash(cell, 7) * 3.0):
				var a := _hash(cell, 10 + k) * TAU
				var r := 0.12 + _hash(cell, 20 + k) * 0.25
				flowers.append(Transform3D(Basis().scaled(Vector3.ONE * (0.8 + _hash(cell, 30 + k) * 0.4)), center + Vector3(cos(a) * r, 0.0, sin(a) * r)))
				flower_colors.append(color)
	var nodes: Array[Node3D] = []
	if not tufts.is_empty():
		nodes.append(_multimesh(grass_mesh(), grass_material(), tufts, [], false))
	if not flowers.is_empty():
		var flower_mat := StandardMaterial3D.new()
		flower_mat.vertex_color_use_as_albedo = true
		flower_mat.roughness = 0.8
		nodes.append(_multimesh(_flower_mesh(), flower_mat, flowers, flower_colors, false))
	return nodes


## A tiny flower: green stem, five petals around a yellow centre. Petal colour
## comes from the instance colour (white in the mesh so it tints cleanly).
static func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color(0.2, 0.45, 0.15)
	var top := 0.16
	st.set_normal(Vector3.UP)
	for tri in [[Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0), Vector3(0, top, 0)]]:
		for v: Vector3 in tri:
			st.set_color(stem)
			st.add_vertex(v)
	for i in 5:
		var a := TAU * i / 5.0
		var b := a + TAU / 10.0
		var c := a - TAU / 10.0
		for v in [Vector3(0, top, 0), Vector3(cos(c) * 0.07, top + 0.01, sin(c) * 0.07), Vector3(cos(b) * 0.07, top + 0.01, sin(b) * 0.07)]:
			st.set_color(Color.WHITE)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	for i in 4:
		var a := TAU * i / 4.0
		var b := TAU * (i + 1) / 4.0
		for v in [Vector3(0, top + 0.02, 0), Vector3(cos(a) * 0.022, top + 0.015, sin(a) * 0.022), Vector3(cos(b) * 0.022, top + 0.015, sin(b) * 0.022)]:
			st.set_color(Color(1.4, 1.2, 0.2))
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


# --- Trees ---------------------------------------------------------------------

## A round, bushy tree: short trunk under a few lumpy canopy balls, darker
## underneath and sunlit on top.
static func tree_mesh(dark := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_cylinder(st, Vector3.ZERO, 0.13, 0.17, 0.75, Color(0.45, 0.3, 0.18))
	var balls := [
		[Vector3(0, 1.25, 0), 0.62], [Vector3(-0.32, 1.05, 0.12), 0.45], [Vector3(0.33, 1.05, 0.1), 0.45],
		[Vector3(0.05, 1.7, -0.02), 0.45], [Vector3(0.0, 1.05, 0.36), 0.42], [Vector3(0.05, 1.1, -0.34), 0.42],
	]
	for i in balls.size():
		# Gentle shading only: a strong top-to-bottom gradient made the sunlit side glare.
		var low := Color(0.13, 0.33, 0.13) if not dark else Color(0.1, 0.2, 0.18)
		var high := Color(0.26, 0.5, 0.2) if not dark else Color(0.2, 0.32, 0.27)
		var shade := 0.92 + 0.08 * float(i % 3)
		_add_blob(st, balls[i][0], balls[i][1], i, low * shade, high * shade)
	return st.commit()


static func _add_cylinder(st: SurfaceTool, base: Vector3, r_top: float, r_bottom: float, height: float, color: Color) -> void:
	var sides := 8
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		var p0 := base + Vector3(cos(a) * r_bottom, 0, sin(a) * r_bottom)
		var p1 := base + Vector3(cos(b) * r_bottom, 0, sin(b) * r_bottom)
		var p2 := base + Vector3(cos(b) * r_top, height, sin(b) * r_top)
		var p3 := base + Vector3(cos(a) * r_top, height, sin(a) * r_top)
		var n := Vector3(cos((a + b) * 0.5), 0, sin((a + b) * 0.5))
		for v in [p0, p1, p2, p0, p2, p3]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)


## Lumpy ball with smooth normals and a bottom-to-top colour gradient.
static func _add_blob(st: SurfaceTool, center: Vector3, radius: float, variant: int, low: Color, high: Color) -> void:
	var rings := 7
	var segs := 12
	var points := []
	for r in rings + 1:
		var row := []
		var phi := PI * r / rings
		for s in segs:
			var theta := TAU * s / segs
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var bump := 1.0 + 0.09 * sin(theta * 3.0 + variant * 1.3) * sin(phi * 4.0 + variant)
			row.append(d * bump)
		points.append(row)
	for r in rings:
		for s in segs:
			var quad := [points[r][s], points[r][(s + 1) % segs], points[r + 1][(s + 1) % segs], points[r + 1][s]]
			for k in [0, 1, 2, 0, 2, 3]:
				var d: Vector3 = quad[k]
				var world := center + d * radius
				var light := clampf(d.y * 0.5 + 0.5, 0.0, 1.0)
				st.set_color(low.lerp(high, light))
				st.set_normal(d.normalized())
				st.add_vertex(world)


## Matte, no shine, and see-through when it hides your Pokémon.
static func vertex_color_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MODEL_SHADER
	return mat


# --- Rocks ---------------------------------------------------------------------

## Chunky faceted boulder (Rock Smash rock), centred like the wall box so it can
## replace it: flat faces, grey-brown with darker cracks between facets.
static func rock_mesh(variant: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Displace each unique position the same way so the seams stay closed.
	var moved := {}
	for i in verts.size():
		var key := Vector3i((verts[i] * 1000.0).round())
		if not moved.has(key):
			var d := verts[i].normalized() if verts[i].length() > 0.0001 else Vector3.UP
			var cube := d / maxf(absf(d.x), maxf(absf(d.y), absf(d.z)))
			var p := d.lerp(cube * 0.9, 0.45)
			var n := sin(d.x * 7.3 + variant * 2.1) * sin(d.z * 6.1 + variant) * 0.5 + sin(d.y * 5.0 + d.x * 3.0 + variant) * 0.5
			p *= 1.0 + n * 0.12
			var v := Vector3(p.x * 0.6, p.y * Arena.WALL_HEIGHT * 0.52, p.z * 0.6)
			v.y = maxf(v.y, -Arena.WALL_HEIGHT * 0.5)
			moved[key] = v
		verts[i] = moved[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + variant
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		var n := (b - a).cross(c - a)
		if n.length() < 0.000001:
			continue
		n = -n.normalized()
		var shade := rng.randf_range(0.85, 1.08)
		var up := clampf(n.y * 0.5 + 0.5, 0.0, 1.0)
		var color := Color(0.4, 0.35, 0.31).lerp(Color(0.68, 0.62, 0.53), up) * shade
		for v in [a, b, c]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


static func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D], colors: Array[Color], shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
