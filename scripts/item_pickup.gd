class_name ItemPickup
extends Node3D
## A floating item (Potion, vitamins, PP Up, HP Up) that any Pokémon on either
## team picks up by walking over it. Legendaries can't take items.

const PICKUP_RADIUS := 0.9

var item_id := ""
var item: Dictionary = {}

var _sprite: Sprite3D
var _glow: MeshInstance3D
var _time := 0.0


func setup(p_item_id: String) -> void:
	item_id = p_item_id
	item = GameData.items.get(item_id, {})


func _ready() -> void:
	add_to_group("items")
	_sprite = Sprite3D.new()
	_sprite.texture = item.get("texture")
	_sprite.pixel_size = 0.014
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	add_child(_sprite)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.38
	ring.outer_radius = 0.5
	_glow = MeshInstance3D.new()
	_glow.mesh = ring
	_glow.scale = Vector3(1, 0.1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1, 0.95, 0.6, 0.8)
	_glow.material_override = mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.position.y = 0.05
	add_child(_glow)
	Vfx.ring(get_parent(), global_position, 0.6, "fairy", 20)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = 0.75 + sin(_time * 3.0) * 0.12
	_glow.rotation.y = _time * 1.5
	var pulse := 1.0 + sin(_time * 4.0) * 0.08
	_glow.scale = Vector3(pulse, 0.1, pulse)


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group("brawlers"):
		var b := node as Brawler
		if b == null or b.is_dead or b.is_legendary:
			continue
		var offset := b.global_position - global_position
		offset.y = 0.0
		if offset.length() <= PICKUP_RADIUS:
			b.pickup(item)
			queue_free()
			return
