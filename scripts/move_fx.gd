class_name MoveFx
extends RefCounted
## Move-specific effects drawn from a MoveLook: hit impacts, swipes (claws, punches,
## whips, bites, spins), charge after-images, area strikes (lightning, quakes,
## meteors, pillars, rings, novas, blooms, frost, clouds, waves, swirls, notes) and
## beam lines. Everything is short-lived sprites, simple meshes and small CPU
## particle bursts, kept brief so busy fights stay readable.


## Where a hit lands. `size` ~ the hit's radius in metres.
static func impact(parent: Node, pos: Vector3, look: Dictionary, size := 0.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var type_name := str(look.get("type", "normal"))
	var color := _color(look, 0)
	match str(look.get("impact", "burst")):
		"star":
			flash(parent, pos, "spark", Color(1, 1, 1, 0.95), size * 1.6, 0.16)
			flash(parent, pos, "ring", color, size * 2.2, 0.22)
			Vfx.burst(parent, pos, type_name, 6, 0.15, 3.5, { "shape": "chunk", "colors": ["#ffffff", look_hex(look, 1), look_hex(look, 2)] })
		"splash":
			flash(parent, pos, "ring", color, size * 2.0, 0.25)
			Vfx.burst(parent, pos, type_name, 10, 0.2, 3.0, look)
		"zap":
			flash(parent, pos, "bolt", Color(1, 1, 0.8), size * 1.8, 0.12)
			Vfx.burst(parent, pos, type_name, 8, 0.2, 4.0, look)
		"shatter":
			flash(parent, pos, "spark", color, size * 1.4, 0.14)
			Vfx.burst(parent, pos, type_name, 10, 0.2, 4.5, { "shape": "shard", "colors": look.get("colors", []) })
		"smoke":
			flash(parent, pos, "wisp", _color(look, 1), size * 2.2, 0.35)
			Vfx.burst(parent, pos, type_name, 8, 0.25, 1.8, look)
		"petals":
			flash(parent, pos, "star", color, size * 1.5, 0.2)
			Vfx.burst(parent, pos, type_name, 9, 0.2, 2.5, { "shape": "petal", "colors": look.get("colors", []), "spin": true })
		_:
			flash(parent, pos, str(look.get("shape", "spark")), color, size * 1.3, 0.14)
			Vfx.burst(parent, pos, type_name, 9, 0.2, 2.8, look)


## A shape that pops up and fades (billboarded). `size` in metres.
static func flash(parent: Node, pos: Vector3, shape: String, color: Color, size: float, time: float, grow := 1.6) -> Sprite3D:
	var s := Sprite3D.new()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.texture = Vfx.shape_texture(shape)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.modulate = color
	s.pixel_size = size / 64.0
	s.rotation.z = randf() * TAU
	parent.add_child(s)
	s.global_position = pos
	s.scale = Vector3.ONE * 0.5
	var tween := s.create_tween().set_parallel()
	tween.tween_property(s, "scale", Vector3.ONE * grow, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(s, "modulate:a", 0.0, time).set_delay(time * 0.35)
	tween.chain().tween_callback(s.queue_free)
	return s


## A flat shape lying on the ground (cracks, rings, frost), growing and fading.
static func decal(parent: Node, pos: Vector3, shape: String, color: Color, size: float, time: float, grow := 1.3) -> Sprite3D:
	var s := Sprite3D.new()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.texture = Vfx.shape_texture(shape)
	s.axis = Vector3.AXIS_Y
	s.shaded = false
	s.modulate = color
	s.pixel_size = size / 64.0
	s.rotation.y = randf() * TAU
	parent.add_child(s)
	s.global_position = Vector3(pos.x, 0.07, pos.z)
	s.scale = Vector3.ONE * 0.6
	var tween := s.create_tween().set_parallel()
	tween.tween_property(s, "scale", Vector3.ONE * grow, time * 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(s, "modulate:a", 0.0, time * 0.6).set_delay(time * 0.4)
	tween.chain().tween_callback(s.queue_free)
	return s


# --- Swipes ------------------------------------------------------------------

## Melee move effect in front of `user` toward `direction`; `hits` are the enemies struck.
static func melee(user: Brawler, direction: Vector3, move: MoveData, hits: Array[Brawler]) -> void:
	var parent := user.get_parent()
	if parent == null:
		return
	var look := MoveLook.of(move)
	var color := _color(look, 0)
	var reach := move.reach + Brawler.BODY_RADIUS
	var front := user.global_position + direction * minf(reach * 0.6, 1.8) + Vector3(0, 0.8, 0)
	var targets: Array[Vector3] = []
	for h in hits:
		targets.append(h.global_position + Vector3(0, 0.8, 0))
	if targets.is_empty():
		targets.append(front)
	match str(look.get("melee", "swipe")):
		"claw":
			for p in targets:
				for i in 3:
					var side := direction.cross(Vector3.UP).normalized() * (i - 1) * 0.22
					var mark := flash(parent, p + side, "slash", color.lightened(0.3), 1.1, 0.2, 1.2)
					mark.rotation.z = -0.6 + i * 0.05
		"punch":
			for p in targets:
				flash(parent, p, "spark", Color(1, 1, 1, 0.95), 1.0, 0.15, 1.8)
				flash(parent, p, "ring", color, 1.2, 0.22, 2.0)
		"bite":
			for p in targets:
				for top: bool in [true, false]:
					var fang := flash(parent, p + Vector3(0, 0.45 if top else -0.45, 0), "fang", Color(1, 1, 1), 0.7, 0.22, 1.0)
					fang.rotation.z = 0.0 if top else PI
					fang.create_tween().tween_property(fang, "position:y", fang.position.y + (-0.35 if top else 0.35), 0.12)
		"whip":
			_arc_line(parent, user.global_position, direction, reach, move.arc, color)
		"spin":
			for i in 6:
				var a := TAU * i / 6.0
				var at := user.global_position + Vector3(cos(a), 0, sin(a)) * minf(reach, 2.2) * 0.7 + Vector3(0, 0.7, 0)
				flash(parent, at, "slash", color.lightened(0.2), 0.9, 0.22, 1.1).rotation.z = a
		_:
			for p in targets:
				flash(parent, p, str(look.get("shape", "spark")), color, 0.8, 0.16)


## A thin curved lash along the edge of a swing (whips, vines, tongues, tails).
static func _arc_line(parent: Node, origin: Vector3, direction: Vector3, reach: float, arc_deg: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var half := deg_to_rad(maxf(arc_deg, 30.0)) * 0.5
	var segments := 12
	for i in segments + 1:
		var t := float(i) / segments
		var a := lerpf(-half, half, t)
		var r := reach * (0.75 + 0.25 * sin(t * PI))
		var w := 0.06 + 0.1 * sin(t * PI)
		st.add_vertex(Vector3(sin(a), 0, -cos(a)) * (r - w))
		st.add_vertex(Vector3(sin(a), 0, -cos(a)) * (r + w))
	var line := MeshInstance3D.new()
	line.mesh = st.commit()
	var mat := Brawler._flat_material(Color(color.lightened(0.3), 0.9))
	line.material_override = mat
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(line)
	line.global_position = origin + Vector3(0, 0.5, 0)
	line.rotation.y = atan2(-direction.x, -direction.z)
	var tween := line.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(line.queue_free)


# --- Charges -----------------------------------------------------------------

## A fading copy of the user's current sprite frame, tinted by the move (dash after-images).
static func afterimage(user: Brawler, look: Dictionary) -> void:
	var parent := user.get_parent()
	if parent == null or user.sprite.texture == null:
		return
	var ghost := Sprite3D.new()
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.texture = user.sprite.texture
	ghost.hframes = user.sprite.hframes
	ghost.vframes = user.sprite.vframes
	ghost.frame = user.sprite.frame
	ghost.flip_h = user.sprite.flip_h
	ghost.pixel_size = user.sprite.pixel_size
	ghost.offset = user.sprite.offset
	ghost.texture_filter = user.sprite.texture_filter
	ghost.shaded = false
	ghost.modulate = Color(_color(look, 0).lightened(0.2), 0.55)
	parent.add_child(ghost)
	ghost.global_transform = user.sprite.global_transform
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
	if str(look.get("dash", "")) == "drill":
		flash(parent, user.global_position + Vector3(0, 0.8, 0), "swirl", _color(look, 1), 1.0, 0.2, 1.0)


# --- Areas -------------------------------------------------------------------

## The landing of an area move at `center` with `radius` (on top of the usual ring).
static func area(parent: Node, center: Vector3, radius: float, move: MoveData) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var look := MoveLook.of(move)
	var type_name := move.type
	var color := _color(look, 0)
	var mid := _color(look, 1)
	center.y = 0.0
	match str(look.get("area", "ring")):
		"strike":
			# Bolts from the sky on the centre and a few points around it.
			for i in 4:
				var at := center if i == 0 else center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * radius * randf_range(0.4, 0.9)
				Vfx.lightning(parent, at + Vector3(randf_range(-0.4, 0.4), 6.0, 0), at + Vector3(0, 0.1, 0), type_name)
				flash(parent, at + Vector3(0, 0.3, 0), "bolt", Color(1, 1, 0.8), 1.2, 0.15)
		"quake":
			decal(parent, center, "snowflake", Color(0.25, 0.18, 0.1, 0.75), radius * 2.0, 0.9, 1.1)  # Cracks radiating out.
			Vfx.ring(parent, center, radius * 0.9, "ground", 14)
			_shake_camera(parent, 0.25)
		"meteor":
			for i in 5:
				var at := center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * radius * 0.7
				_falling(parent, at, look, i * 0.05)
		"pillar":
			_pillar(parent, center, radius, color, mid)
			Vfx.burst(parent, center + Vector3(0, 0.5, 0), type_name, 10, radius * 0.3, 4.0, look)
		"rings":
			for i in 3:
				var ring := decal(parent, center, "ring", Color(mid, 0.8), radius * 0.8, 0.5 + i * 0.12, 2.6)
				ring.position.y += 0.02 * i
		"nova":
			_nova(parent, center, radius, color)
			_shake_camera(parent, 0.35)
		"bloom":
			Vfx.ring(parent, center, radius * 0.7, type_name, 14, { "shape": str(look.get("shape", "petal")), "colors": look.get("colors", []), "spin": true })
			decal(parent, center, "star", Color(color, 0.5), radius * 1.6, 0.6, 1.2)
		"frost":
			decal(parent, center, "snowflake", Color(0.85, 0.97, 1.0, 0.6), radius * 1.6, 0.8, 1.0)
			Vfx.ring(parent, center, radius * 0.8, type_name, 14, { "shape": "snowflake", "spin": true })
		"cloud":
			for i in 5:
				var at := center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * radius * 0.6 + Vector3(0, 0.6, 0)
				flash(parent, at, "wisp", Color(mid, 0.7), radius * 0.9, 0.7, 1.4)
		"wave":
			decal(parent, center, "ring", Color(color, 0.8), radius * 1.6, 0.5, 1.4)
			Vfx.ring(parent, center, radius * 0.9, type_name, 16, look)
		"swirl":
			var sw := decal(parent, center, "swirl", Color(mid, 0.7), radius * 2.0, 0.7, 1.0)
			sw.create_tween().tween_property(sw, "rotation:y", sw.rotation.y - 6.0, 0.7)
		"notes":
			for i in 6:
				var a := TAU * i / 6.0
				var at := center + Vector3(cos(a), 0, sin(a)) * radius * 0.6 + Vector3(0, 0.8, 0)
				var note := flash(parent, at, "note", color, 0.7, 0.6, 1.2)
				note.rotation.z = 0.0
				note.create_tween().tween_property(note, "position:y", note.position.y + 0.8, 0.6)


## A rock (or ice chunk / comet) dropping in from the sky.
static func _falling(parent: Node, at: Vector3, look: Dictionary, delay: float) -> void:
	var s := Sprite3D.new()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.texture = Vfx.shape_texture(str(look.get("shape", "chunk")))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.modulate = _color(look, 1)
	s.pixel_size = 0.7 / 64.0
	parent.add_child(s)
	s.global_position = at + Vector3(0.6, 5.0, 0)
	s.visible = false
	var tween := s.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: s.visible = true)
	tween.tween_property(s, "global_position", at + Vector3(0, 0.3, 0), 0.22).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Vfx.burst(parent, at + Vector3(0, 0.3, 0), str(look.get("type", "rock")), 6, 0.2, 3.0, look)
		s.queue_free())


## A column of light or flame rising from the ground.
static func _pillar(parent: Node, center: Vector3, radius: float, bright: Color, mid: Color) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.3
	cyl.bottom_radius = radius * 0.5
	cyl.height = 2.6
	cyl.cap_top = false
	cyl.cap_bottom = false
	var fx := MeshInstance3D.new()
	fx.mesh = cyl
	var mat := Brawler._flat_material(Color(bright.lerp(mid, 0.3), 0.4))
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fx)
	fx.global_position = center + Vector3(0, 1.3, 0)
	fx.scale = Vector3(0.3, 0.2, 0.3)
	var tween := fx.create_tween().set_parallel()
	tween.tween_property(fx, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35).set_delay(0.12)
	tween.chain().tween_callback(fx.queue_free)


## A bright flash sphere and a shockwave ring (explosions, Hyper Beam).
static func _nova(parent: Node, center: Vector3, radius: float, color: Color) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = radius * 0.7
	sphere.height = radius * 1.4
	sphere.radial_segments = 16
	sphere.rings = 8
	var fx := MeshInstance3D.new()
	fx.mesh = sphere
	var mat := Brawler._flat_material(Color(1, 1, 0.95, 0.5))
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fx)
	fx.global_position = center + Vector3(0, 0.4, 0)
	fx.scale = Vector3.ONE * 0.2
	var tween := fx.create_tween().set_parallel()
	tween.tween_property(fx, "scale", Vector3.ONE, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color", Color(color, 0.0), 0.35)
	tween.chain().tween_callback(fx.queue_free)
	decal(parent, center, "ring", Color(1, 1, 1, 0.9), radius * 1.2, 0.4, 2.0)


# --- Beams -------------------------------------------------------------------

## A glowing line from where a shot was fired to where it is now (call update each frame).
class Beam:
	var mesh: MeshInstance3D
	var mat: StandardMaterial3D
	var start: Vector3

	func _init(parent: Node, from: Vector3, color: Color, width: float) -> void:
		start = from
		var box := BoxMesh.new()
		box.size = Vector3(width, width * 0.5, 1.0)
		mesh = MeshInstance3D.new()
		mesh.mesh = box
		mat = Brawler._flat_material(Color(color, 0.75))
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mesh)
		mesh.visible = false

	func update(to: Vector3) -> void:
		var length := start.distance_to(to)
		if length < 0.05 or not is_instance_valid(mesh):
			return
		mesh.visible = true
		mesh.global_position = (start + to) * 0.5
		mesh.look_at(to, Vector3.UP)
		mesh.scale = Vector3(1, 1, length)
		mat.albedo_color.a = randf_range(0.6, 0.85)

	func fade() -> void:
		if not is_instance_valid(mesh):
			return
		var tween := mesh.create_tween().set_parallel()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
		tween.tween_property(mesh, "scale:x", 0.2, 0.25)
		tween.chain().tween_callback(mesh.queue_free)


# --- Helpers -----------------------------------------------------------------

static func _color(look: Dictionary, index: int) -> Color:
	return Color.html(look_hex(look, index))


static func look_hex(look: Dictionary, index: int) -> String:
	var colors: Array = look.get("colors", [])
	if colors.size() > index:
		return str(colors[index])
	return str(Vfx.style(str(look.get("type", "normal")))["colors"][index])


static func _shake_camera(node: Node, strength: float) -> void:
	var camera := node.get_viewport().get_camera_3d() if node.is_inside_tree() else null
	if camera and camera.has_method("shake"):
		camera.call("shake", strength)
