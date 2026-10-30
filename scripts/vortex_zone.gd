class_name VortexZone
extends Node3D
## A whirl left where a vortex move lands (Fire Spin, Hurricane, Sandstorm, Leek
## Tornado): for `duration` s it drags enemies toward its centre and hits them
## every TICK for the `share` of the move's power not dealt on impact.

const TICK := 0.4

var shooter: Brawler
var move: MoveData
var radius := 2.5
var _time_left := 2.0
var _duration := 2.0
var _tick := 0.0
var _swirl: Sprite3D
var _particles: CPUParticles3D


func setup(p_shooter: Brawler, p_move: MoveData, center: Vector3, p_radius: float) -> void:
	shooter = p_shooter
	move = p_move
	radius = maxf(1.6, p_radius)
	position = Vector3(center.x, 0.0, center.z)
	_duration = float(move.control.get("duration", 2.0))
	_time_left = _duration


func _ready() -> void:
	var look := str(move.control.get("look", move.type))
	# A spiral on the ground that spins, plus a column of whirling particles.
	_swirl = Sprite3D.new()
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_swirl.texture = Vfx.shape_texture("swirl")
	_swirl.axis = Vector3.AXIS_Y
	_swirl.shaded = false
	_swirl.transparent = true
	_swirl.modulate = Color(Color.html(Vfx.style(look)["colors"][1]), 0.55)
	_swirl.pixel_size = radius * 2.0 / 64.0
	_swirl.position.y = 0.08
	add_child(_swirl)
	_particles = Vfx.whirl(look, radius)
	add_child(_particles)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0 or not is_instance_valid(shooter) or shooter.is_dead:
		_particles.emitting = false
		set_physics_process(false)
		create_tween().tween_property(_swirl, "modulate:a", 0.0, 0.3).finished.connect(queue_free)
		return
	_swirl.rotation.y -= delta * 6.0
	var pull := float(move.control.get("pull", 2.0))
	_tick -= delta
	var hit := _tick <= 0.0
	if hit:
		_tick = TICK
	for node in get_tree().get_nodes_in_group("brawlers"):
		var target := node as Brawler
		if target == null or target.team == shooter.team or target.is_dead or target.is_legendary:
			continue
		var to := global_position - target.global_position
		to.y = 0.0
		if to.length() > radius + Brawler.BODY_RADIUS:
			continue
		if to.length() > 0.3:
			# Pull in, with a little swirl around the centre.
			var tangent := to.normalized().cross(Vector3.UP)
			target._pull += (to.normalized() * pull + tangent * pull * 0.5) * minf(1.0, to.length())
		if hit:
			target.take_hit(shooter, move, float(move.control.get("share", 0.4)) * TICK / _duration)
