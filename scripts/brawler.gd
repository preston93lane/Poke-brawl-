class_name Brawler
extends CharacterBody3D
## A Pokémon brawler. Controllers (player or bot) drive it by setting
## move_input and calling shoot() / melee().

signal died(brawler: Brawler)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
## Horizontal hit radius used by melee checks (matches the collision capsule).
const BODY_RADIUS := 0.5
## Seconds without attacking or taking damage before health regenerates.
const REGEN_DELAY := 3.0
## Fraction of max health regenerated per second once regen kicks in.
const REGEN_RATE := 0.13
const SPRITE_HEIGHT := 1.0

@export var data: BrawlerData
@export var team := 0
@export var is_player := false

var health := 0.0
var ammo := 0.0
## Desired movement in screen space (x = right, y = down), length 0..1.
var move_input := Vector2.ZERO
var facing := Vector3.FORWARD
var is_dead := false

var _melee_timer := 0.0
var _regen_timer := 0.0
var _flash_timer := 0.0
var _bob_time := 0.0
var _melee_material: StandardMaterial3D
var _melee_tween: Tween

@onready var sprite: Sprite3D = $Sprite
@onready var shadow: MeshInstance3D = $Shadow
@onready var team_ring: MeshInstance3D = $TeamRing
@onready var aim_pivot: Node3D = $AimPivot
@onready var aim_indicator: MeshInstance3D = $AimPivot/AimIndicator
@onready var melee_fx: MeshInstance3D = $MeleeFx


func _ready() -> void:
	add_to_group("brawlers")
	health = data.max_health
	ammo = data.max_ammo
	sprite.texture = data.portrait
	_build_visuals()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_melee_timer = maxf(0.0, _melee_timer - delta)
	if ammo < data.max_ammo:
		ammo = minf(data.max_ammo, ammo + delta / data.reload_time)
	_regen_timer += delta
	if _regen_timer >= REGEN_DELAY and health < data.max_health:
		health = minf(data.max_health, health + data.max_health * REGEN_RATE * delta)

	var dir := Vector3(move_input.x, 0.0, move_input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * data.move_speed
	if dir.length_squared() > 0.01:
		facing = dir.normalized()
	move_and_slide()

	_update_sprite(delta, dir.length_squared() > 0.01)


# --- Attacks ---------------------------------------------------------------

func can_shoot() -> bool:
	return not is_dead and ammo >= 1.0


func shoot(direction: Vector3) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or not can_shoot():
		return false
	direction = direction.normalized()
	ammo -= 1.0
	_regen_timer = 0.0
	facing = direction

	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.setup(self, direction)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0, 0.8, 0) + direction * 0.6
	return true


func melee_ready() -> bool:
	return not is_dead and _melee_timer <= 0.0


## 0 when melee is ready, 1 right after using it.
func melee_cooldown_ratio() -> float:
	return _melee_timer / data.melee_cooldown


func melee(direction: Vector3) -> bool:
	if not melee_ready():
		return false
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = facing
	direction = direction.normalized()
	_melee_timer = data.melee_cooldown
	_regen_timer = 0.0
	facing = direction
	_show_melee_fx(direction)

	var half_arc := deg_to_rad(data.melee_arc_degrees) * 0.5
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other == null or other == self or other.team == team or other.is_dead:
			continue
		var to := other.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > data.melee_range + BODY_RADIUS:
			continue
		if dist > 0.01 and direction.angle_to(to / dist) > half_arc:
			continue
		other.take_damage(data.melee_damage)
	return true


func find_nearest_enemy(max_range: float = INF) -> Brawler:
	var best: Brawler = null
	var best_dist := max_range
	for node in get_tree().get_nodes_in_group("brawlers"):
		var other := node as Brawler
		if other == null or other == self or other.team == team or other.is_dead:
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best = other
			best_dist = dist
	return best


# --- Damage ----------------------------------------------------------------

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	_regen_timer = 0.0
	_flash_timer = 0.12
	_spawn_damage_number(amount)
	if health <= 0.0:
		_die()


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	hide_aim()
	team_ring.visible = false
	var tween := create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector3(1.4, 0.05, 1.0), 0.35)
	tween.tween_property(shadow, "scale", Vector3.ZERO, 0.35)
	died.emit(self)


# --- Aim indicator ---------------------------------------------------------

func show_aim(direction: Vector3) -> void:
	if is_dead or direction.length_squared() < 0.0001:
		hide_aim()
		return
	aim_pivot.rotation.y = atan2(-direction.x, -direction.z)
	aim_indicator.visible = true
	var mat := aim_indicator.material_override as StandardMaterial3D
	mat.albedo_color.a = 0.45 if can_shoot() else 0.15


func hide_aim() -> void:
	aim_indicator.visible = false


# --- Visuals ---------------------------------------------------------------

func _build_visuals() -> void:
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.55
	shadow_mesh.bottom_radius = 0.55
	shadow_mesh.height = 0.02
	shadow.mesh = shadow_mesh
	shadow.material_override = _flat_material(Color(0, 0, 0, 0.35))
	shadow.position.y = 0.02

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.72
	team_ring.mesh = ring_mesh
	team_ring.scale = Vector3(1, 0.1, 1)
	team_ring.position.y = 0.04
	var ring_color := Color(0.25, 0.6, 1.0, 0.9) if is_player else Color(1.0, 0.25, 0.25, 0.9)
	team_ring.material_override = _flat_material(ring_color)

	# Aim line pointing along -Z (forward); the pivot rotates it.
	var aim_mesh := PlaneMesh.new()
	aim_mesh.size = Vector2(0.7, data.projectile_range)
	aim_indicator.mesh = aim_mesh
	aim_indicator.position = Vector3(0, 0.05, -data.projectile_range * 0.5 - 0.6)
	aim_indicator.material_override = _flat_material(Color(1, 1, 1, 0.45))
	aim_indicator.visible = false

	melee_fx.mesh = _build_fan_mesh(data.melee_range + BODY_RADIUS, deg_to_rad(data.melee_arc_degrees))
	_melee_material = _flat_material(Color(1, 1, 1, 0.0))
	melee_fx.material_override = _melee_material
	melee_fx.position.y = 0.08
	melee_fx.visible = false


func _update_sprite(delta: float, moving: bool) -> void:
	if moving:
		_bob_time += delta * 12.0
		sprite.position.y = SPRITE_HEIGHT + absf(sin(_bob_time)) * 0.12
	else:
		_bob_time = 0.0
		sprite.position.y = lerpf(sprite.position.y, SPRITE_HEIGHT, 0.3)
	if absf(facing.x) > 0.2:
		sprite.flip_h = facing.x < 0.0
	_flash_timer = maxf(0.0, _flash_timer - delta)
	sprite.modulate = Color(1, 0.45, 0.45) if _flash_timer > 0.0 else Color.WHITE


func _show_melee_fx(direction: Vector3) -> void:
	melee_fx.rotation.y = atan2(-direction.x, -direction.z)
	melee_fx.visible = true
	if _melee_tween:
		_melee_tween.kill()
	_melee_material.albedo_color.a = 0.6
	_melee_tween = create_tween()
	_melee_tween.tween_property(_melee_material, "albedo_color:a", 0.0, 0.2)
	_melee_tween.tween_callback(func() -> void: melee_fx.visible = false)


func _spawn_damage_number(amount: float) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 72
	label.outline_size = 18
	label.pixel_size = 0.008
	label.modulate = Color(1, 1, 1)
	label.outline_modulate = Color(0.6, 0, 0)
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 2.0, 0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 1.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.tween_property(label, "outline_modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)


static func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	return mat


static func _build_fan_mesh(radius: float, arc: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 16
	for i in segments:
		var a0 := -arc * 0.5 + arc * float(i) / segments
		var a1 := -arc * 0.5 + arc * float(i + 1) / segments
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * radius)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * radius)
	return st.commit()
