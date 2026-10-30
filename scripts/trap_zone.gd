class_name TrapZone
extends Node3D
## A hidden trap laid by a gadget (Stealth Rock, Toxic Spikes, Sticky Web). It arms
## after a moment, springs on the first enemy that steps on it (the move's power,
## status and stat drops), then is gone. Your own team sees it faintly; enemies don't.

const ARM_TIME := 0.6

var owner_brawler: Brawler
var move: MoveData
var radius := 1.4
var _life := 15.0
var _age := 0.0
var _decal: Sprite3D


func setup(p_owner: Brawler, p_move: MoveData, center: Vector3) -> void:
	owner_brawler = p_owner
	move = p_move
	position = center
	radius = float(move.trap.get("radius", 1.4))
	_life = float(move.trap.get("life", 15.0))


func _ready() -> void:
	add_to_group("traps")
	_decal = Sprite3D.new()
	_decal.texture = Vfx.shape_texture({ "rock": "chunk", "poison": "blob", "bug": "web" }.get(move.type, "ring"))
	_decal.axis = Vector3.AXIS_Y
	_decal.shaded = false
	_decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_decal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_decal.pixel_size = radius * 1.6 / 64.0
	_decal.position.y = 0.06
	_decal.modulate = Color(GameData.type_color(move.type), 0.55)
	add_child(_decal)
	Vfx.burst(get_parent(), global_position + Vector3(0, 0.2, 0), move.type, 8, 0.4, 1.5)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _life or not is_instance_valid(owner_brawler):
		queue_free()
		return
	# Only the trap's own team can see it.
	_decal.visible = owner_brawler.team == GameData.local_team
	_decal.modulate.a = 0.35 + 0.1 * sin(_age * 4.0)
	if _age < ARM_TIME:
		return
	for node in get_tree().get_nodes_in_group("brawlers"):
		var b := node as Brawler
		if b == null or b.is_dead or b.team == owner_brawler.team or b.flying or b._ability.get("floats", false):
			continue
		if Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z).length() <= radius:
			_spring(b)
			return


func _spring(victim: Brawler) -> void:
	if not owner_brawler.is_dead:
		victim.take_hit(owner_brawler, move)
	else:
		victim._apply_effect(move.effect, null, move.type)
		victim.apply_stat_change(move.stat_change)
	var look := MoveLook.of(move)
	MoveFx.impact(get_parent(), victim.global_position + Vector3(0, 0.5, 0), look, 0.8)
	Vfx.ring(get_parent(), global_position, radius, move.type, 16, look)
	queue_free()
