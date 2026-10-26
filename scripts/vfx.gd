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
	"fire": { "colors": ["#fff6b0", "#ffa030", "#d8381a"], "gravity": Vector3(0, 2.8, 0), "size": 0.42, "life": 0.45, "add": true, "core": "#ffd060" },
	"water": { "colors": ["#f0faff", "#68b8ff", "#2a70d8"], "gravity": Vector3(0, -7.0, 0), "size": 0.24, "life": 0.5, "add": false, "core": "#7cc4ff" },
	"electric": { "colors": ["#ffffff", "#fff46a", "#ffc800"], "gravity": Vector3.ZERO, "size": 0.17, "life": 0.18, "add": true, "core": "#fff8a0", "jitter": 0.09 },
	"grass": { "colors": ["#e0ffb8", "#72d24c", "#2f8a2a"], "gravity": Vector3(0, -1.5, 0), "size": 0.24, "life": 0.6, "add": false, "core": "#8fe060" },
	"poison": { "colors": ["#f4d0ff", "#b45ee0", "#5a2080"], "gravity": Vector3(0, 1.0, 0), "size": 0.3, "life": 0.7, "add": false, "core": "#c070f0" },
	"psychic": { "colors": ["#ffe8f4", "#ff70b8", "#b03080"], "gravity": Vector3(0, 0.5, 0), "size": 0.34, "life": 0.5, "add": true, "core": "#ff90c8" },
	"ghost": { "colors": ["#e0c8ff", "#7a52c0", "#1c0c30"], "gravity": Vector3(0, 0.8, 0), "size": 0.45, "life": 0.8, "add": false, "core": "#9070d8" },
	"dragon": { "colors": ["#f0e4ff", "#9060ff", "#3a20a0"], "gravity": Vector3(0, 0.6, 0), "size": 0.36, "life": 0.5, "add": true, "core": "#a080ff" },
	"ice": { "colors": ["#ffffff", "#c0f2ff", "#64c4e8"], "gravity": Vector3(0, -2.0, 0), "size": 0.2, "life": 0.55, "add": true, "core": "#d8f8ff" },
	"rock": { "colors": ["#e8dcc0", "#a08462", "#5e4a34"], "gravity": Vector3(0, -9.0, 0), "size": 0.24, "life": 0.55, "add": false, "core": "#9a8264", "solid": true },
	"ground": { "colors": ["#f0e0b8", "#c8a068", "#7a5a30"], "gravity": Vector3(0, -6.0, 0), "size": 0.34, "life": 0.6, "add": false, "core": "#b89060", "solid": true },
	"fighting": { "colors": ["#fff0d8", "#ff8a50", "#b02a20"], "gravity": Vector3.ZERO, "size": 0.3, "life": 0.3, "add": true, "core": "#ffa070" },
	"steel": { "colors": ["#ffffff", "#c8ccd8", "#707888"], "gravity": Vector3(0, -6.0, 0), "size": 0.14, "life": 0.3, "add": true, "core": "#dde2ee" },
	"dark": { "colors": ["#c8b8d8", "#4a3858", "#100818"], "gravity": Vector3(0, 0.5, 0), "size": 0.4, "life": 0.6, "add": false, "core": "#5a4868" },
	"flying": { "colors": ["#ffffff", "#d0d8ff", "#a0b0e8"], "gravity": Vector3.ZERO, "size": 0.3, "life": 0.4, "add": false, "core": "#e0e8ff" },
	"normal": { "colors": ["#ffffff", "#e8e4d8", "#b0a890"], "gravity": Vector3(0, -1.0, 0), "size": 0.26, "life": 0.35, "add": false, "core": "#f4f0e4" },
	"bug": { "colors": ["#f4ffc0", "#b8d030", "#607010"], "gravity": Vector3(0, -2.0, 0), "size": 0.2, "life": 0.45, "add": false, "core": "#c8e050" },
	"fairy": { "colors": ["#ffffff", "#ffc0e0", "#f080c0"], "gravity": Vector3(0, 0.6, 0), "size": 0.26, "life": 0.6, "add": true, "core": "#ffd0ec" },
}

static var _materials := {}
static var _gradients := {}
static var _dot: Texture2D
static var _quad: QuadMesh
static var _shrink: Curve


static func style(type_name: String) -> Dictionary:
	return STYLES.get(type_name, STYLES["normal"])


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
	return p


static func _spawn_one_shot(parent: Node, p: CPUParticles3D, pos: Vector3) -> void:
	parent.add_child(p)
	p.global_position = pos
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
	mat.albedo_texture = _dot_texture()
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


## Soft round dot used for every particle.
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
