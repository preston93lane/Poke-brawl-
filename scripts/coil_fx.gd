extends Node3D
## Rings wrapped around a grabbed Pokémon (Wrap, Bind, Vine Snare, Onix's coil):
## they slowly turn and tighten with each squeeze. Added as a child of the target.

const LOOKS := {
	"tentacle": [Color(0.55, 0.45, 0.95), Color(0.85, 0.3, 0.45)],
	"coil": [Color(0.62, 0.38, 0.75), Color(0.95, 0.8, 0.3)],
	"vine": [Color(0.25, 0.65, 0.25), Color(0.5, 0.85, 0.35)],
	"tongue": [Color(1.0, 0.55, 0.65), Color(0.95, 0.4, 0.5)],
	"rock_coil": [Color(0.55, 0.55, 0.6), Color(0.42, 0.42, 0.48)],
}

var _rings: Array[MeshInstance3D] = []
var _squeeze := 0.0


func setup(look: String, height: float) -> void:
	var colors: Array = LOOKS.get(look, LOOKS["coil"])
	var width := clampf(height * 0.42, 0.35, 0.8)
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = width * 0.84
		torus.outer_radius = width
		torus.rings = 12
		torus.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mat.roughness = 1.0
		mat.metallic_specular = 0.0
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = height * (0.18 + 0.3 * i)
		# Tilted a little each way, like loops of a coil.
		ring.rotation = Vector3(0.25 * (1 if i % 2 == 0 else -1), i * 1.1, 0.15)
		add_child(ring)
		_rings.append(ring)
	scale = Vector3.ONE * 1.6
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func squeeze() -> void:
	_squeeze = 1.0


func _process(delta: float) -> void:
	_squeeze = maxf(0.0, _squeeze - delta * 5.0)
	var k := 1.0 - 0.15 * _squeeze
	for i in _rings.size():
		_rings[i].rotation.y += delta * (1.5 if i % 2 == 0 else -1.5)
		_rings[i].scale = Vector3(k, 1.0, k)
