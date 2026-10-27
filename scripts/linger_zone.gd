extends Node3D
## A patch of lingering damage left where a shot lands (String Shot, Sludge,
## Sticky Web...). Hits enemies inside it every TICK seconds for `linger`
## seconds; the move's power is its damage per second.

const TICK := 0.5

var shooter: Brawler
var move: MoveData
var _time_left := 0.0
var _tick := 0.0
var _material: StandardMaterial3D


func setup(p_shooter: Brawler, p_move: MoveData, center: Vector3) -> void:
	shooter = p_shooter
	move = p_move
	position = center
	_time_left = move.linger


func _ready() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = move.linger_radius
	disc.bottom_radius = move.linger_radius
	disc.height = 0.04
	var fx := MeshInstance3D.new()
	fx.mesh = disc
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(GameData.type_color(move.type), 0.35)
	fx.material_override = _material
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.position.y = 0.07
	add_child(fx)
	Vfx.ring(get_parent(), position, move.linger_radius, move.type, 40)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0 or not is_instance_valid(shooter):
		queue_free()
		return
	_material.albedo_color.a = 0.22 + 0.1 * sin(Time.get_ticks_msec() * 0.008) if _time_left > 0.5 else 0.3 * _time_left
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	for node in get_tree().get_nodes_in_group("brawlers"):
		var target := node as Brawler
		if target == null or target.team == shooter.team or target.is_dead:
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() <= move.linger_radius + Brawler.BODY_RADIUS * 0.5:
			target.take_hit(shooter, move, TICK)
	Breakable.hit_area(get_tree(), global_position, move.linger_radius, shooter, move, TICK)
	Vfx.burst(get_parent(), global_position + Vector3(0, 0.2, 0), move.type, 6, move.linger_radius * 0.6, 1.2)
