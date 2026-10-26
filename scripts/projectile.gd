class_name Projectile
extends Area3D
## A straight-flying shot. Damages the first enemy brawler it touches and
## disappears on walls or after travelling its max range.

var team := 0
var direction := Vector3.FORWARD
var speed := 16.0
var damage := 700.0
var max_distance := 9.0
var color := Color.YELLOW

var _travelled := 0.0

@onready var mesh: MeshInstance3D = $Mesh


func setup(shooter: Brawler, dir: Vector3) -> void:
	team = shooter.team
	direction = dir
	speed = shooter.data.projectile_speed
	damage = shooter.data.projectile_damage
	max_distance = shooter.data.projectile_range
	color = shooter.data.projectile_color


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material_override = mat


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var brawler := body as Brawler
	if brawler:
		if brawler.team == team or brawler.is_dead:
			return
		brawler.take_damage(damage)
	queue_free()
