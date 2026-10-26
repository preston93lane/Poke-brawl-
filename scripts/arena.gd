class_name Arena
extends Node3D
## Builds a simple symmetric 1v1 arena: checkered floor, border walls and a
## handful of obstacles. Tweak OBSTACLES to change the layout.

## Obstacles as [center (x, z), footprint (width, depth)]. Mirrored layouts keep it fair.
const OBSTACLES := [
	[Vector2(0, -6), Vector2(4, 1)],
	[Vector2(0, 6), Vector2(4, 1)],
	[Vector2(-6, 0), Vector2(2, 2)],
	[Vector2(6, 0), Vector2(2, 2)],
	[Vector2(-7, -10), Vector2(1.5, 1.5)],
	[Vector2(7, 10), Vector2(1.5, 1.5)],
]

@export var arena_size := Vector2(22, 30)
@export var wall_height := 1.4

var player_spawn := Vector3(0, 0, 12)
var enemy_spawn := Vector3(0, 0, -12)


func _ready() -> void:
	_build_floor()
	_build_walls()


func _build_floor() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	var light := Color(0.47, 0.74, 0.36)
	var dark := Color(0.42, 0.68, 0.32)
	img.set_pixel(0, 0, light)
	img.set_pixel(1, 1, light)
	img.set_pixel(1, 0, dark)
	img.set_pixel(0, 1, dark)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(arena_size.x / 4.0, arena_size.y / 4.0, 1)
	mat.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = arena_size
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = mat
	add_child(floor_mesh)

	# Darker ground outside the walls so the edge of the world isn't empty.
	var outside_mat := StandardMaterial3D.new()
	outside_mat.albedo_color = Color(0.25, 0.42, 0.22)
	outside_mat.roughness = 1.0
	var outside_plane := PlaneMesh.new()
	outside_plane.size = Vector2(120, 120)
	var outside := MeshInstance3D.new()
	outside.mesh = outside_plane
	outside.material_override = outside_mat
	outside.position.y = -0.02
	add_child(outside)


func _build_walls() -> void:
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.5, 0.6)
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_color = Color(0.72, 0.5, 0.3)

	var half := arena_size * 0.5
	var t := 1.0
	_add_block(Vector2(0, -half.y - t * 0.5), Vector2(arena_size.x + t * 2, t), wall_mat)
	_add_block(Vector2(0, half.y + t * 0.5), Vector2(arena_size.x + t * 2, t), wall_mat)
	_add_block(Vector2(-half.x - t * 0.5, 0), Vector2(t, arena_size.y), wall_mat)
	_add_block(Vector2(half.x + t * 0.5, 0), Vector2(t, arena_size.y), wall_mat)

	for obstacle in OBSTACLES:
		_add_block(obstacle[0], obstacle[1], crate_mat)


func _add_block(center: Vector2, footprint: Vector2, mat: Material) -> void:
	var extents := Vector3(footprint.x, wall_height, footprint.y)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = extents
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	var box_mesh := BoxMesh.new()
	box_mesh.size = extents
	var mesh := MeshInstance3D.new()
	mesh.mesh = box_mesh
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	body.position = Vector3(center.x, wall_height * 0.5, center.y)
