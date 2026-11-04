class_name TownWalker
extends CharacterBody3D
## Someone walking round town: your trainer (move_input from the stick / keys), a
## wandering trainer (stands about, turns to face you), or your partner Pokémon
## (follows you). Trainers use the town sheets (TrainerLook: rows down / up /
## right, 3 frames); the partner uses its PMD walk animation.

const TRAINER_PIXEL := 0.05
const SPEED := 5.5

## -1..1 on each axis; y is "up the screen" (away from the camera) when negative.
var move_input := Vector2.ZERO
var speed := SPEED
## Partner Pokémon: who to follow.
var follow: Node3D
var facing := Vector3(0, 0, 1)
var sprite: Sprite3D
var species: SpeciesData
var _anim_time := 0.0
var _tilt := 0.0
var _pmd_cols := 1
var _pmd_rows := 1
var _durations: Array = []


static func trainer(sheet: Texture2D, pitch_degrees: float) -> TownWalker:
	var w := TownWalker.new()
	w._tilt = -deg_to_rad(pitch_degrees)
	w._setup_body()
	w.sprite.texture = sheet
	w.sprite.hframes = 3
	w.sprite.vframes = 3
	w.sprite.pixel_size = TRAINER_PIXEL
	w.sprite.offset = Vector2(0, TrainerLook.CELL.y * 0.5 - 1)
	w._add_shadow(0.42)
	return w


static func pokemon(s: SpeciesData, pitch_degrees: float, shiny := false) -> TownWalker:
	var w := TownWalker.new()
	w.species = s
	w._tilt = -deg_to_rad(pitch_degrees)
	w._setup_body()
	w.collision_layer = 0
	w.collision_mask = 0
	var a: Dictionary = s.pmd.get("walk", {})
	w.sprite.texture = s.pmd_texture("walk", shiny)
	w._pmd_cols = int(a.get("cols", 1))
	w._pmd_rows = int(a.get("rows", 1))
	w._durations = a.get("durations", [0.2])
	w.sprite.hframes = w._pmd_cols
	w.sprite.vframes = w._pmd_rows
	w.sprite.pixel_size = clampf(1.15 / maxf(8.0, float(a.get("height", 24))), 0.02, 0.06)
	w.sprite.offset = Vector2(0, float(a.get("feet", float(a.get("fh", 32)) * 0.25)))
	w.speed = SPEED * 1.05
	w._add_shadow(0.36)
	return w


func _setup_body() -> void:
	collision_layer = 0
	collision_mask = Arena.WORLD_LAYER | Arena.WATER_LAYER
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.0
	shape.shape = capsule
	shape.position.y = 0.5
	add_child(shape)
	sprite = Sprite3D.new()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.rotation.x = _tilt
	add_child(sprite)


func _add_shadow(radius: float) -> void:
	var disc := CylinderMesh.new()
	disc.radial_segments = 20
	disc.rings = 1
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.scale = Vector3(1, 1, 0.6)
	mi.position = Vector3(0, 0.03, -0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Turn to look at a point (wandering trainers greet you).
func look_toward(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0.0
	if d.length() > 0.01:
		facing = d.normalized()


func _physics_process(delta: float) -> void:
	var want := Vector3(move_input.x, 0, move_input.y)
	if follow:
		# Partner: stay a step behind, catch up faster when far away.
		var to := follow.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		want = to.normalized() * clampf((dist - 1.1) / 1.2, 0.0, 1.6) if dist > 1.1 else Vector3.ZERO
		if dist > 8.0:
			global_position = follow.global_position - to.normalized() * 1.2
	if want.length() > 1.0:
		want = want.normalized()
	velocity = want * speed
	if want.length() > 0.05:
		facing = want.normalized()
	if collision_mask != 0:
		move_and_slide()
	else:
		global_position += velocity * delta
	_animate(delta, want.length() > 0.05)


func _animate(delta: float, moving: bool) -> void:
	if species:
		_anim_time += delta if moving else 0.0
		var total := 0.0
		for d in _durations:
			total += float(d)
		var t := fmod(_anim_time, maxf(0.01, total))
		var col := 0
		var acc := 0.0
		for i in _durations.size():
			acc += float(_durations[i])
			if t < acc:
				col = i
				break
		var row := posmod(roundi(rad_to_deg(atan2(facing.x, facing.z)) / 45.0), 8)
		sprite.frame = mini(row, _pmd_rows - 1) * _pmd_cols + mini(col, _pmd_cols - 1)
		return
	# Trainer sheet: rows down / up / right (flipped for left), frames stand / left / right.
	var row := 0
	if absf(facing.x) > absf(facing.z):
		row = 2
		sprite.flip_h = facing.x < 0.0
	else:
		row = 0 if facing.z >= 0.0 else 1
		sprite.flip_h = false
	var frame := 0
	if moving:
		_anim_time += delta
		frame = [1, 0, 2, 0][int(_anim_time / 0.13) % 4]
	else:
		_anim_time = 0.0
	sprite.frame = row * 3 + frame
