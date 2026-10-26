class_name FollowCamera
extends Camera3D
## Brawl Stars style camera: fixed tilt, never rotates, smoothly follows the target.

@export_range(20.0, 85.0) var pitch_degrees := 60.0
@export var distance := 19.0
@export var follow_speed := 6.0
## Clamp the followed point so the camera doesn't drift past the arena edges.
@export var follow_limits := Rect2(-4, -10, 8, 20)

var target: Node3D


func _ready() -> void:
	rotation_degrees = Vector3(-pitch_degrees, 0, 0)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(_desired_position(), 1.0 - exp(-follow_speed * delta))


func snap_to_target() -> void:
	if target:
		global_position = _desired_position()


func _desired_position() -> Vector3:
	var focus := target.global_position
	focus.x = clampf(focus.x, follow_limits.position.x, follow_limits.end.x)
	focus.z = clampf(focus.z, follow_limits.position.y, follow_limits.end.y)
	var pitch := deg_to_rad(pitch_degrees)
	return focus + Vector3(0, sin(pitch), cos(pitch)) * distance
