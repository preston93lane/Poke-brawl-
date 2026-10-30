class_name TombRock
extends StaticBody3D
## One rock (or ice block) of a Rock Tomb / Avalanche ring. It drops in from above,
## blocks walking (not shots or sight: Brawler.TOMB_LAYER) and crumbles after a while.

var look := "rock"
var _life := 2.5
var _delay := 0.0
var _mesh: MeshInstance3D


func setup(p_look: String, life: float, delay: float) -> void:
	look = p_look
	_life = life
	_delay = delay


func _ready() -> void:
	add_to_group("tomb_rocks")
	collision_layer = Brawler.TOMB_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 1.0, 0.7)
	shape.shape = box
	shape.position.y = 0.5
	add_child(shape)
	_mesh = MeshInstance3D.new()
	if look == "ice":
		var cube := BoxMesh.new()
		cube.size = Vector3(0.62, 0.8, 0.62)
		_mesh.mesh = cube
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.75, 0.93, 1.0, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.15
		mat.metallic_specular = 0.9
		_mesh.material_override = mat
		_mesh.position.y = 0.4
	else:
		_mesh.mesh = ArenaArt.rock_mesh(randi() % 3)
		_mesh.material_override = ArenaArt.vertex_color_material()
		_mesh.scale = Vector3(0.72, 0.8, 0.72)
		_mesh.position.y = 0.0
	_mesh.rotation.y = randf() * TAU
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh)
	# Drop in from above with a thud of dust.
	var rest := _mesh.position.y
	_mesh.position.y = rest + 3.0
	_mesh.visible = false
	var tween := create_tween()
	tween.tween_interval(_delay)
	tween.tween_callback(func() -> void: _mesh.visible = true)
	tween.tween_property(_mesh, "position:y", rest, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		Vfx.burst(get_parent(), global_position + Vector3(0, 0.2, 0), "ice" if look == "ice" else "ground", 8, 0.3, 2.0))
	tween.tween_interval(maxf(0.1, _life - _delay - 0.5))
	tween.tween_property(_mesh, "scale", _mesh.scale * 0.2, 0.25)
	tween.tween_callback(_crumble)


func _crumble() -> void:
	Vfx.burst(get_parent(), global_position + Vector3(0, 0.3, 0), "ice" if look == "ice" else "rock", 10, 0.3, 2.5)
	queue_free()
