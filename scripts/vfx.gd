class_name Vfx
extends RefCounted
## Type-themed particle effects: projectile trails, hit sparks, explosions,
## area rings, streams and status auras. Fire rises and glows, water drips,
## electricity crackles, rock throws debris, ghost leaves dark smoke...
## Uses CPU particles so it also runs in the web build.

## colors: bright -> mid -> dark; gravity in m/s²; size in metres; life in seconds;
## add = glowing (additive) instead of solid; core = projectile core colour;
## solid = the projectile core is a lit lump (rocks) rather than a glow; jitter = crackle.
const STYLES := {
	"fire": { "colors": ["#ffc23a", "#ff4e14", "#a8160a"], "gravity": Vector3(0, 2.8, 0), "size": 0.42, "life": 0.45, "add": false, "core": "#ff5a1e", "shape": "flame" },
	"water": { "colors": ["#9cd2ff", "#2c7ce6", "#103c98"], "gravity": Vector3(0, -7.0, 0), "size": 0.24, "life": 0.5, "add": false, "core": "#3a8cff", "shape": "drop" },
	"electric": { "colors": ["#fff8a0", "#ffe014", "#e8a000"], "gravity": Vector3.ZERO, "size": 0.3, "life": 0.2, "add": true, "core": "#ffe83a", "jitter": 0.09, "shape": "bolt", "spin": true },
	"grass": { "colors": ["#b4ee6c", "#48b438", "#1c661c"], "gravity": Vector3(0, -1.5, 0), "size": 0.26, "life": 0.6, "add": false, "core": "#58c446", "shape": "leaf", "spin": true },
	"poison": { "colors": ["#e0a4ff", "#9638cc", "#46106c"], "gravity": Vector3(0, 1.0, 0), "size": 0.3, "life": 0.7, "add": false, "core": "#9e4ade", "shape": "bubble" },
	"psychic": { "colors": ["#ffaad8", "#ee4698", "#961864"], "gravity": Vector3(0, 0.5, 0), "size": 0.36, "life": 0.5, "add": false, "core": "#ff52ae", "shape": "ring" },
	"ghost": { "colors": ["#ae96ee", "#56389a", "#140828"], "gravity": Vector3(0, 0.8, 0), "size": 0.45, "life": 0.8, "add": false, "core": "#6644b4", "shape": "wisp" },
	"dragon": { "colors": ["#c4a4ff", "#6638ee", "#281284"], "gravity": Vector3(0, 0.6, 0), "size": 0.38, "life": 0.5, "add": false, "core": "#764cff", "shape": "flame" },
	"ice": { "colors": ["#eafcff", "#98e2ff", "#3aa2d4"], "gravity": Vector3(0, -2.0, 0), "size": 0.24, "life": 0.55, "add": false, "core": "#b8eeff", "shape": "shard", "spin": true },
	"rock": { "colors": ["#e0d2b4", "#9a7e5c", "#5a4630"], "gravity": Vector3(0, -9.0, 0), "size": 0.26, "life": 0.55, "add": false, "core": "#9a8264", "solid": true, "shape": "chunk", "spin": true },
	"ground": { "colors": ["#e8d4a4", "#c09658", "#74542a"], "gravity": Vector3(0, -6.0, 0), "size": 0.34, "life": 0.6, "add": false, "core": "#b89060", "solid": true, "shape": "chunk", "spin": true },
	"fighting": { "colors": ["#ffc28a", "#ee5a2c", "#9c1c12"], "gravity": Vector3.ZERO, "size": 0.34, "life": 0.3, "add": false, "core": "#f0663a", "shape": "spark", "spin": true },
	"steel": { "colors": ["#eef0f6", "#a6aebe", "#58606e"], "gravity": Vector3(0, -6.0, 0), "size": 0.2, "life": 0.3, "add": false, "core": "#c4cad8", "shape": "shard", "spin": true },
	"dark": { "colors": ["#a898b8", "#40304e", "#0c0614"], "gravity": Vector3(0, 0.5, 0), "size": 0.4, "life": 0.6, "add": false, "core": "#4a3858", "shape": "wisp" },
	"flying": { "colors": ["#ffffff", "#c4d0f6", "#8a9cd6"], "gravity": Vector3.ZERO, "size": 0.34, "life": 0.4, "add": false, "core": "#dde6ff", "shape": "crescent", "spin": true },
	"normal": { "colors": ["#fff8ec", "#dad2be", "#a0967c"], "gravity": Vector3(0, -1.0, 0), "size": 0.26, "life": 0.35, "add": false, "core": "#f0eadc", "shape": "spark", "spin": true },
	"bug": { "colors": ["#e4f69a", "#a4bc1e", "#526406"], "gravity": Vector3(0, -2.0, 0), "size": 0.22, "life": 0.45, "add": false, "core": "#b4d030", "shape": "leaf", "spin": true },
	"fairy": { "colors": ["#ffd2ec", "#ff82c2", "#cc4a92"], "gravity": Vector3(0, 0.6, 0), "size": 0.3, "life": 0.6, "add": false, "core": "#ff9cd2", "shape": "star", "spin": true },
}

static var _materials := {}
static var _gradients := {}
static var _dot: Texture2D
## shape name -> ImageTexture (white mask; particles are tinted by their colour ramp)
static var _shapes := {}
static var _quad: QuadMesh
static var _shrink: Curve


static func style(type_name: String) -> Dictionary:
	return STYLES.get(type_name, STYLES["normal"])


## Shaped sprite for a projectile's core (flame, bolt, droplet, leaf...), tinted with the
## type's core colour. Rock and ground keep their solid 3D lump instead (returns null).
static func core_sprite(type_name: String, radius: float) -> Sprite3D:
	var s := style(type_name)
	if s.get("solid", false):
		return null
	var sprite := Sprite3D.new()
	sprite.texture = shape_texture(str(s.get("shape", "dot")))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.modulate = Color.html(s["core"])
	sprite.pixel_size = maxf(0.5, radius * 2.8) / 64.0
	sprite.no_depth_test = false
	return sprite


## A jagged lightning bolt between two points (chain lightning), fading out fast.
static func lightning(parent: Node, from: Vector3, to: Vector3, type_name := "electric") -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var color := Color.html(style(type_name)["core"])
	var points: Array[Vector3] = [from]
	var segments := 6
	var side := (to - from).cross(Vector3.UP).normalized()
	for i in range(1, segments):
		var t := float(i) / segments
		points.append(from.lerp(to, t) + side * randf_range(-0.35, 0.35) + Vector3(0, randf_range(-0.2, 0.2), 0))
	points.append(to)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, 0.09, a.distance_to(b) + 0.05)
		seg.mesh = box
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(seg)
		seg.global_position = (a + b) * 0.5
		if a.distance_to(b) > 0.01:
			seg.look_at(b, Vector3.UP)
		parent.get_tree().create_timer(0.22, false).timeout.connect(seg.queue_free)
	var tween := parent.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)


## Glowing (or solid, for rock types) projectile core.
static func core_material(type_name: String) -> StandardMaterial3D:
	var s := style(type_name)
	var mat := StandardMaterial3D.new()
	var color := Color.html(s["core"])
	if s.get("solid", false):
		mat.albedo_color = color
		mat.roughness = 0.9
	else:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color.lightened(0.25)
	return mat


## Continuous trail that stays behind a moving projectile.
static func trail(type_name: String, radius: float) -> CPUParticles3D:
	var s := style(type_name)
	var p := _base(type_name, 22, s["life"])
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.6
	p.spread = 180.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.9
	var k := clampf(radius / 0.3, 0.8, 2.5)
	p.scale_amount_min *= k
	p.scale_amount_max *= k
	if s.has("jitter"):
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
	p.emitting = true
	return p


## One-off spray of particles (hit sparks, explosions, heals...).
static func burst(parent: Node, pos: Vector3, type_name: String, amount := 14, radius := 0.35, speed := 3.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := style(type_name)
	var p := _base(type_name, amount, s["life"])
	p.one_shot = true
	p.explosiveness = 0.92
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	_spawn_one_shot(parent, p, pos)


## Expanding ring of particles on the ground (area attacks, supers).
static func ring(parent: Node, pos: Vector3, radius: float, type_name: String, amount := 40) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := style(type_name)
	var p := _base(type_name, amount, s["life"] * 1.3)
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	_spawn_one_shot(parent, p, pos + Vector3(0, 0.15, 0))


## Emitter for stream moves; the owner aims it and sets its speed each frame.
static func stream(type_name: String) -> CPUParticles3D:
	var s := style(type_name)
	var p := _base(type_name, 70, 0.35)
	p.local_coords = false
	p.direction = Vector3(0, 0, -1)
	p.gravity = s["gravity"] * 0.3
	p.scale_amount_min *= 1.3
	p.scale_amount_max *= 1.6
	p.emitting = false
	return p


## Little particles around a brawler showing a status (burn, poison, sleep...).
static func aura(type_name: String) -> CPUParticles3D:
	var p := _base(type_name, 10, 0.7)
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.4, 0.6, 0.4)
	p.position = Vector3(0, 0.9, 0)
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.emitting = false
	return p


static func _base(type_name: String, amount: int, lifetime: float) -> CPUParticles3D:
	var s := style(type_name)
	var p := CPUParticles3D.new()
	if _quad == null:
		_quad = QuadMesh.new()
	p.mesh = _quad
	p.material_override = _material(type_name)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount = amount
	p.lifetime = lifetime
	p.gravity = s["gravity"]
	p.color_ramp = _gradient(type_name)
	p.scale_amount_min = s["size"] * 0.7
	p.scale_amount_max = s["size"] * 1.2
	p.scale_amount_curve = _shrink_curve()
	p.damping_min = 1.0
	p.damping_max = 3.0
	if s.get("spin", false):
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -240.0
		p.angular_velocity_max = 240.0
	return p


static func _spawn_one_shot(parent: Node, p: CPUParticles3D, pos: Vector3) -> void:
	# Particles emit as soon as they enter the tree: place them first, or the
	# first burst pops out at the middle of the map.
	p.emitting = false
	if parent is Node3D and (parent as Node3D).is_inside_tree():
		p.position = (parent as Node3D).to_local(pos)
	parent.add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.4, false).timeout.connect(p.queue_free)


static func _material(type_name: String) -> StandardMaterial3D:
	if _materials.has(type_name):
		return _materials[type_name]
	var s := style(type_name)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if s["add"]:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = shape_texture(str(s.get("shape", "dot")))
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials[type_name] = mat
	return mat


static func _gradient(type_name: String) -> Gradient:
	if _gradients.has(type_name):
		return _gradients[type_name]
	var colors: Array = style(type_name)["colors"]
	var g := Gradient.new()
	g.set_color(0, Color.html(colors[0]))
	g.set_color(1, Color(Color.html(colors[2]), 0.0))
	g.add_point(0.4, Color.html(colors[1]))
	_gradients[type_name] = g
	return g


## White mask of a particle shape, drawn once and cached. Shapes are defined in
## [-1, 1] coordinates (y down) by _shape_alpha.
static func shape_texture(shape: String) -> Texture2D:
	if shape == "dot":
		return _dot_texture()
	if _shapes.has(shape):
		return _shapes[shape]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			# 2x2 supersampling for smooth edges.
			var a := 0.0
			for sy in 2:
				for sx in 2:
					var u := ((x + 0.25 + sx * 0.5) / size) * 2.0 - 1.0
					var v := ((y + 0.25 + sy * 0.5) / size) * 2.0 - 1.0
					a += _shape_alpha(shape, u, v)
			a *= 0.25
			# Slightly darker rim gives the shape some body.
			var shade := 1.0 - 0.25 * clampf(Vector2(x - 32, y - 32).length() / 32.0, 0, 1)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	var tex := ImageTexture.create_from_image(img)
	_shapes[shape] = tex
	return tex


static func _shape_alpha(shape: String, u: float, v: float) -> float:
	var r := Vector2(u, v).length()
	match shape:
		"flame", "drop":
			# Teardrop pointing up: round bottom, tapering tip.
			var body := 0.5 if shape == "flame" else 0.55
			var cy := 0.35
			if Vector2(u, v - cy).length() < body:
				return 1.0
			if v < cy and v > -0.95:
				var t := (v + 0.95) / (cy + 0.95)
				var half := body * pow(t, 1.4 if shape == "flame" else 1.8)
				if shape == "flame":
					u += sin(v * 5.0) * 0.08  # A little flicker in the outline.
				return 1.0 if absf(u) < half else 0.0
			return 0.0
		"bolt":
			var bolt := PackedVector2Array([Vector2(-0.1, -1), Vector2(0.5, -1), Vector2(0.12, -0.18),
					Vector2(0.48, -0.18), Vector2(-0.4, 1), Vector2(-0.06, 0.12), Vector2(-0.42, 0.12)])
			return 1.0 if Geometry2D.is_point_in_polygon(Vector2(u, v), bolt) else 0.0
		"leaf":
			var lu := (u + v) * 0.7071
			var lv := (v - u) * 0.7071
			var inside := (lu / 0.92) * (lu / 0.92) + (lv / 0.42) * (lv / 0.42) < 1.0
			return (0.55 if absf(lv) < 0.05 else 1.0) if inside else 0.0
		"chunk":
			var rock := PackedVector2Array([Vector2(-0.7, -0.3), Vector2(-0.2, -0.8), Vector2(0.5, -0.6),
					Vector2(0.85, 0.05), Vector2(0.45, 0.75), Vector2(-0.35, 0.8), Vector2(-0.85, 0.3)])
			return 1.0 if Geometry2D.is_point_in_polygon(Vector2(u, v), rock) else 0.0
		"shard":
			return 1.0 if absf(u) / 0.32 + absf(v) / 0.95 < 1.0 else 0.0
		"ring":
			return 1.0 if r > 0.5 and r < 0.88 else 0.0
		"bubble":
			if r > 0.62 and r < 0.85:
				return 1.0
			return 0.35 if r <= 0.62 else 0.0
		"wisp":
			return clampf(1.0 - smoothstep(0.2, 0.95, r), 0.0, 1.0) * 0.85
		"crescent":
			return 1.0 if r < 0.85 and Vector2(u - 0.38, v + 0.1).length() > 0.72 else 0.0
		"star", "spark":
			var points := 5 if shape == "star" else 4
			var angle := atan2(v, u) + PI * 0.5
			var k := cos(points * angle * 0.5)
			var outer := 0.95 if shape == "star" else 1.0
			var inner := 0.42 if shape == "star" else 0.22
			var limit := lerpf(inner, outer, absf(k) * absf(k))
			return 1.0 if r < limit else 0.0
	return clampf(1.0 - smoothstep(0.45, 1.0, r), 0.0, 1.0)


## Soft round dot used for particles without a shape.
static func _dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.85))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot


static func _shrink_curve() -> Curve:
	if _shrink == null:
		_shrink = Curve.new()
		_shrink.add_point(Vector2(0, 1))
		_shrink.add_point(Vector2(1, 0.25))
	return _shrink
