class_name FollowCamera
extends Camera3D
## Brawl Stars style camera: fixed tilt, never rotates, smoothly follows the target.

@export_range(20.0, 85.0) var pitch_degrees := 60.0
@export var distance := 20.0
@export var follow_speed := 6.0
## Look this far ahead of the target (toward the enemy side, up the screen), so you
## stand in the bottom quarter of the screen and see more of what's in front.
## 4.9 m puts the target 25% from the bottom with the default pitch, fov and distance.
@export var lead := 3.8
## Half the arena's length (set by the match). Past the halfway line the lead swings
## the other way, so in the enemy half you sit higher on screen and can see behind you.
var field_half := 22.0
## Clamp the followed point so the camera doesn't drift past the arena edges.
@export var follow_limits := Rect2(-4, -10, 8, 20)

var target: Node3D
var _shake := 0.0
var _base_position := Vector3.ZERO


func _ready() -> void:
	rotation_degrees = Vector3(-pitch_degrees, 0, 0)


func _process(delta: float) -> void:
	if target:
		_base_position = _base_position.lerp(_desired_position(), 1.0 - exp(-follow_speed * delta))
	# Screen shake: a quick random wobble that dies away.
	_shake = maxf(0.0, _shake - delta * 1.8)
	var wobble := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * _shake
	global_position = _base_position + global_basis * wobble


## Shake the camera (0.1 = small bump, 0.5 = big hit).
func shake(strength: float) -> void:
	_shake = clampf(maxf(_shake, strength), 0.0, 0.8)


func snap_to_target() -> void:
	if target:
		_base_position = _desired_position()
		global_position = _base_position


func _desired_position() -> Vector3:
	# Own half: look ahead. Enemy half (negative z): ease the look back toward your side.
	var into_enemy := clampf(-target.global_position.z / maxf(1.0, field_half), 0.0, 1.0)
	var look := lerpf(lead, -lead * 0.6, smoothstep(0.0, 1.0, into_enemy))
	var focus := target.global_position + Vector3(0, 0, -look)
	focus.x = clampf(focus.x, follow_limits.position.x, follow_limits.end.x)
	focus.z = clampf(focus.z, follow_limits.position.y, follow_limits.end.y)
	var pitch := deg_to_rad(pitch_degrees)
	return focus + Vector3(0, sin(pitch), cos(pitch)) * distance
