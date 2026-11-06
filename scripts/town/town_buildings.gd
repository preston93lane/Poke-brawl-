class_name TownBuildings
extends RefCounted
## The town's buildings, built from soft rounded shapes (no hard cube edges):
## a body, a chunky roof, a door, windows and a sign. Each building is made in
## its own space: origin at the middle of its footprint on the ground, front
## (with the door) facing +z, towards the camera.

const SHADER := preload("res://assets/shaders/model_xray.gdshader")

static var _box_cache := {}
static var _mats := {}
static var _white: ImageTexture


## A box with every edge and corner rounded to radius `r`. Each face is a grid
## that's flat in the middle with three bands bending round each edge, so it stays
## light (about 600 triangles) but the curves look smooth.
static func soft_box(size: Vector3, r: float) -> ArrayMesh:
	var key := "%s|%.3f" % [size, r]
	if _box_cache.has(key):
		return _box_cache[key]
	r = maxf(0.001, minf(r, minf(size.x, minf(size.y, size.z)) * 0.5 - 0.001))
	var half := size * 0.5
	var inner := half - Vector3(r, r, r)
	const BANDS := 3
	var coords: Array[PackedFloat32Array] = []
	for axis in 3:
		var c := PackedFloat32Array()
		for k in range(BANDS, 0, -1):
			c.append(-(inner[axis] + r * k / BANDS))
		c.append(-inner[axis])
		c.append(inner[axis])
		for k in range(1, BANDS + 1):
			c.append(inner[axis] + r * k / BANDS)
		coords.append(c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var b := (axis + 1) % 3
		var c := (axis + 2) % 3
		for sgn in [-1.0, 1.0]:
			var grid: Array[Vector3] = []
			var norms: Array[Vector3] = []
			var nb := coords[b].size()
			var nc := coords[c].size()
			for i in nb:
				for j in nc:
					var v := Vector3.ZERO
					v[axis] = sgn * half[axis]
					v[b] = coords[b][i]
					v[c] = coords[c][j]
					var core := Vector3(clampf(v.x, -inner.x, inner.x), clampf(v.y, -inner.y, inner.y), clampf(v.z, -inner.z, inner.z))
					var out := v - core
					var n := out.normalized() if out.length() > 0.0001 else Vector3.ZERO
					if n == Vector3.ZERO:
						n[axis] = sgn
					grid.append(core + n * r)
					norms.append(n)
			for i in nb - 1:
				for j in nc - 1:
					var a := i * nc + j
					var quad := [a, a + nc, a + nc + 1, a + 1]
					var face_n := Vector3.ZERO
					face_n[axis] = sgn
					var flip := (grid[quad[1]] - grid[quad[0]]).cross(grid[quad[2]] - grid[quad[0]]).dot(face_n) > 0.0
					for tri in [[0, 1, 2], [0, 2, 3]]:
						var order: Array = tri if not flip else [tri[0], tri[2], tri[1]]
						for k in order:
							st.set_normal(norms[quad[k]])
							st.add_vertex(grid[quad[k]])
	var mesh := st.commit()
	_box_cache[key] = mesh
	return mesh


static func material(color: Color, glow := 0.0) -> Material:
	var key := color.to_html() + str(glow)
	if _mats.has(key):
		return _mats[key]
	var mat: Material
	if glow > 0.0:
		var std := StandardMaterial3D.new()
		std.albedo_color = color
		std.emission_enabled = true
		std.emission = color
		std.emission_energy_multiplier = glow
		mat = std
	else:
		if _white == null:
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.fill(Color.WHITE)
			_white = ImageTexture.create_from_image(img)
		var sm := ShaderMaterial.new()
		sm.shader = SHADER
		sm.set_shader_parameter("albedo_tex", _white)
		sm.set_shader_parameter("tint", color)
		sm.set_shader_parameter("top_light", 0.12)
		mat = sm
	_mats[key] = mat
	return mat


static func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, glow := 0.0, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, glow)
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _sign(parent: Node3D, text: String, pos: Vector3, color: Color, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/LilitaOne-Regular.ttf") if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf") else null
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.08, 0.08, 0.14)
	l.position = pos
	l.rotation.x = -deg_to_rad(25)
	parent.add_child(l)
	return l


## The front door's spot (in front of the building, where you walk in), local space.
static func door_offset(h: int) -> Vector3:
	return Vector3(0, 0, h * 0.5 + 0.45)


static func build(id: String, w: int, h: int) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var fw := float(w) * Arena.TILE
	var fd := float(h) * Arena.TILE
	match id:
		"arena":
			_arena(root, fw, fd)
		_:
			var style: Dictionary = {
				"center": { "wall": Color(0.98, 0.95, 0.9), "roof": Color(0.92, 0.25, 0.3), "height": 2.9, "sign": "POKéMON CENTER", "sign_color": Color(1, 0.55, 0.6) },
				"mart": { "wall": Color(0.96, 0.95, 0.9), "roof": Color(0.25, 0.48, 0.9), "height": 2.7, "sign": "POKé MART", "sign_color": Color(0.6, 0.8, 1) },
				"dept": { "wall": Color(0.88, 0.85, 0.92), "roof": Color(0.55, 0.38, 0.75), "height": 4.6, "sign": "DEPT. STORE", "sign_color": Color(0.85, 0.75, 1), "floors": 2 },
				"corner": { "wall": Color(0.2, 0.18, 0.28), "roof": Color(0.9, 0.2, 0.35), "height": 2.9, "sign": "GAME CORNER", "sign_color": Color(1, 0.85, 0.3), "neon": true },
				"daycare": { "wall": Color(0.82, 0.62, 0.42), "roof": Color(0.35, 0.65, 0.35), "height": 2.6, "sign": "DAY CARE", "sign_color": Color(0.75, 1, 0.65) },
				"museum": { "wall": Color(0.82, 0.8, 0.76), "roof": Color(0.5, 0.48, 0.46), "height": 3.0, "sign": "MUSEUM", "sign_color": Color(1, 0.92, 0.7), "columns": true },
				"outfitter": { "wall": Color(1, 0.88, 0.92), "roof": Color(0.3, 0.72, 0.75), "height": 2.7, "sign": "OUTFITTER", "sign_color": Color(1, 0.7, 0.85), "awning": true },
			}.get(id, { "wall": Color.WHITE, "roof": Color.GRAY, "height": 2.2, "sign": id.to_upper(), "sign_color": Color.WHITE })
			_house(root, fw, fd, style)
	return root


static func _house(root: Node3D, fw: float, fd: float, s: Dictionary) -> void:
	var hgt := float(s["height"])
	var wall: Color = s["wall"]
	var roof: Color = s["roof"]
	# Body, a little inset from the footprint, standing on a low rounded plinth.
	_part(root, soft_box(Vector3(fw - 0.1, 0.25, fd - 0.1), 0.1), wall.darkened(0.25), Vector3(0, 0.12, 0))
	_part(root, soft_box(Vector3(fw - 0.4, hgt, fd - 0.5), 0.28), wall, Vector3(0, hgt * 0.5 + 0.1, -0.05))
	# Chunky roof slab overhanging all round, with a second smaller tier on top.
	_part(root, soft_box(Vector3(fw + 0.1, 0.42, fd - 0.2), 0.2), roof, Vector3(0, hgt + 0.3, -0.2))
	_part(root, soft_box(Vector3(fw * 0.62, 0.36, fd * 0.5), 0.18), roof.lightened(0.12), Vector3(0, hgt + 0.66, -0.4))
	var front := fd * 0.5 - 0.24
	# Door with a light frame.
	_part(root, soft_box(Vector3(1.35, 1.65, 0.2), 0.12), wall.darkened(0.12) if not s.has("neon") else Color(1, 0.85, 0.3), Vector3(0, 0.95, front))
	_part(root, soft_box(Vector3(1.05, 1.45, 0.2), 0.1), Color(0.25, 0.3, 0.42), Vector3(0, 0.85, front + 0.06))
	# Windows either side of the door (two rows on tall buildings).
	var floors := int(s.get("floors", 1))
	for f in floors:
		var wy := 1.25 + f * 2.0
		for side in [-1.0, 1.0]:
			for k in int((fw - 2.4) / 1.6):
				var wx: float = side * (1.4 + k * 1.5)
				if absf(wx) > fw * 0.5 - 0.6:
					continue
				_part(root, soft_box(Vector3(1.0, 0.75, 0.16), 0.12), Color(0.75, 0.9, 1.0), Vector3(wx, wy, front + 0.02), 0.25)
	# Sign board over the door.
	_part(root, soft_box(Vector3(minf(fw - 0.8, 4.6), 0.62, 0.22), 0.18), roof.darkened(0.2), Vector3(0, hgt - 0.5, front + 0.05))
	_sign(root, str(s["sign"]), Vector3(0, hgt - 0.47, front + 0.2), s["sign_color"], 48)
	if s.has("neon"):
		# Game Corner: glowing strips down the front corners.
		for side in [-1.0, 1.0]:
			_part(root, soft_box(Vector3(0.18, hgt - 0.3, 0.18), 0.08), Color(1, 0.3, 0.7) if side < 0 else Color(0.3, 0.9, 1), Vector3(side * (fw * 0.5 - 0.35), hgt * 0.5 + 0.1, front + 0.05), 1.6, false)
	if s.has("columns"):
		for k in 4:
			var cx: float = lerpf(-fw * 0.5 + 0.7, fw * 0.5 - 0.7, k / 3.0)
			if absf(cx) < 0.9:
				continue
			var col := CylinderMesh.new()
			col.radial_segments = 20
			col.rings = 1
			col.top_radius = 0.22
			col.bottom_radius = 0.26
			col.height = hgt
			_part(root, col, Color(0.95, 0.93, 0.88), Vector3(cx, hgt * 0.5 + 0.1, front + 0.25))
	if s.has("awning"):
		# Striped awning over the shop window.
		for k in 6:
			var ax: float = lerpf(-fw * 0.5 + 0.6, fw * 0.5 - 0.6, k / 5.0)
			var stripe := Color(0.3, 0.72, 0.75) if k % 2 == 0 else Color(1, 1, 1)
			var aw := _part(root, soft_box(Vector3((fw - 1.0) / 6.0 + 0.02, 0.12, 0.9), 0.05), stripe, Vector3(ax, 1.95, front + 0.4))
			aw.rotation.x = deg_to_rad(18)


## A street lantern: a dark post with a lamp on top. Returns { node, bulb, pool, halo }
## so the town can light it up at dusk and night.
static var _pool_tex: Texture2D


static func lantern() -> Dictionary:
	var root := Node3D.new()
	var post := CylinderMesh.new()
	post.radial_segments = 8
	post.rings = 1
	post.top_radius = 0.06
	post.bottom_radius = 0.09
	post.height = 2.3
	_part(root, post, Color(0.18, 0.2, 0.24), Vector3(0, 1.15, 0), 0.0, false)
	_part(root, soft_box(Vector3(0.42, 0.12, 0.42), 0.05), Color(0.18, 0.2, 0.24), Vector3(0, 2.62, 0), 0.0, false)
	_part(root, soft_box(Vector3(0.34, 0.08, 0.34), 0.03), Color(0.18, 0.2, 0.24), Vector3(0, 2.22, 0), 0.0, false)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.86, 0.55)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.75, 0.4)
	bulb_mat.emission_energy_multiplier = 0.0
	var bulb := MeshInstance3D.new()
	bulb.mesh = soft_box(Vector3(0.28, 0.32, 0.28), 0.08)
	bulb.material_override = bulb_mat
	bulb.position = Vector3(0, 2.42, 0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bulb)
	# A soft pool of warm light on the ground, and a glow round the lamp.
	if _pool_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_pool_tex = gt
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.albedo_texture = _pool_tex
	glow_mat.albedo_color = Color(1.0, 0.7, 0.35, 0.0)
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.6, 3.6)  # A small pool: the moon lights the rest.
	var pool := MeshInstance3D.new()
	pool.mesh = plane
	pool.material_override = glow_mat
	pool.position.y = 0.05
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool)
	var halo := Sprite3D.new()
	halo.texture = _pool_tex
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.pixel_size = 1.0 / 64.0
	halo.shaded = false
	halo.modulate = Color(1.0, 0.8, 0.45, 0.0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(0, 2.42, 0)
	root.add_child(halo)
	return { "node": root, "bulb": bulb_mat, "pool": glow_mat, "halo": halo }


## The plaza's fountain centrepiece: a stone pedestal holding up a big Poké Ball.
static func fountain() -> Node3D:
	var root := Node3D.new()
	var base := CylinderMesh.new()
	base.radial_segments = 20
	base.rings = 1
	base.top_radius = 0.55
	base.bottom_radius = 0.7
	base.height = 1.0
	_part(root, base, Color(0.85, 0.83, 0.8), Vector3(0, 0.5, 0))
	var top := SphereMesh.new()
	top.radial_segments = 16
	top.rings = 8
	top.radius = 0.6
	top.height = 0.6
	top.is_hemisphere = true
	var upper := _part(root, top, Color(0.92, 0.25, 0.3), Vector3(0, 1.62, 0))
	upper.rotation.x = 0.0
	var bottom := _part(root, top, Color(0.97, 0.97, 0.95), Vector3(0, 1.62, 0))
	bottom.rotation.x = PI
	var band := CylinderMesh.new()
	band.radial_segments = 20
	band.rings = 1
	band.top_radius = 0.61
	band.bottom_radius = 0.61
	band.height = 0.1
	_part(root, band, Color(0.15, 0.15, 0.2), Vector3(0, 1.62, 0))
	var button := CylinderMesh.new()
	button.radial_segments = 20
	button.rings = 1
	button.top_radius = 0.17
	button.bottom_radius = 0.17
	button.height = 0.12
	var b := _part(root, button, Color(0.97, 0.97, 0.95), Vector3(0, 1.62, 0.6))
	b.rotation.x = PI * 0.5
	return root


## The Battle Arena: a round stadium with a big entrance arch, banners and flags.
static func _arena(root: Node3D, fw: float, fd: float) -> void:
	var bowl := CylinderMesh.new()
	bowl.radial_segments = 20
	bowl.rings = 1
	bowl.top_radius = 0.5
	bowl.bottom_radius = 0.5
	bowl.height = 3.2
	bowl.radial_segments = 40
	var body := _part(root, bowl, Color(0.92, 0.9, 0.86), Vector3(0, 1.6, -0.2))
	body.scale = Vector3(fw - 0.4, 1, fd - 0.6)
	var rim := CylinderMesh.new()
	rim.radial_segments = 20
	rim.rings = 1
	rim.top_radius = 0.5
	rim.bottom_radius = 0.5
	rim.height = 0.55
	rim.radial_segments = 40
	var r := _part(root, rim, Color(0.95, 0.55, 0.15), Vector3(0, 3.35, -0.2))
	r.scale = Vector3(fw - 0.1, 1, fd - 0.3)
	var band := _part(root, rim, Color(0.85, 0.25, 0.25), Vector3(0, 1.0, -0.2))
	band.scale = Vector3(fw - 0.3, 0.9, fd - 0.5)
	# Entrance arch at the front.
	var front := fd * 0.5 - 0.3
	_part(root, soft_box(Vector3(3.6, 2.9, 1.0), 0.35), Color(0.95, 0.6, 0.15), Vector3(0, 1.45, front))
	_part(root, soft_box(Vector3(2.4, 2.1, 1.1), 0.3), Color(0.22, 0.25, 0.35), Vector3(0, 1.05, front + 0.05))
	_sign(root, "BATTLE ARENA", Vector3(0, 3.05, front + 0.6), Color(1, 0.9, 0.4), 64)
	# Flags round the rim.
	for k in 6:
		var ang := PI * (0.15 + 0.14 * k)
		var p := Vector3(cos(ang) * (fw * 0.5 - 0.3), 3.6, -sin(ang) * (fd * 0.5 - 0.4) - 0.2)
		var pole := CylinderMesh.new()
		pole.radial_segments = 20
		pole.rings = 1
		pole.top_radius = 0.05
		pole.bottom_radius = 0.05
		pole.height = 1.6
		_part(root, pole, Color(0.85, 0.85, 0.9), p + Vector3(0, 0.8, 0), 0.0, false)
		var flag := _part(root, soft_box(Vector3(0.7, 0.45, 0.06), 0.04), [Color(0.9, 0.25, 0.3), Color(0.25, 0.5, 0.9), Color(1, 0.8, 0.2)][k % 3], p + Vector3(0.38, 1.35, 0), 0.0, false)
		flag.rotation.y = 0.1
