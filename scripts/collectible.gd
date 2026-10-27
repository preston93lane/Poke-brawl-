class_name Collectible
extends Node3D
## A Rare Candy or power cube on the ground. Pops out in a little arc to
## `land_at`, then the first Pokémon to walk over it collects it.

signal collected(collectible: Collectible, by: Brawler)

const PICKUP_RADIUS := 0.85
const FLIGHT_TIME := 0.45
const ICONS := {
	"rare_candy": "res://assets/items/rare_candy.png",
	"power_cube": "res://assets/items/power_cube.png",
}

var kind := "rare_candy"
var land_at := Vector3.ZERO

var _from := Vector3.ZERO
var _flight := 0.0
var _sprite: Sprite3D
var _time := 0.0


func setup(p_kind: String, from: Vector3, p_land_at: Vector3) -> void:
	kind = p_kind
	_from = from
	land_at = p_land_at
	position = from


func _ready() -> void:
	add_to_group("collectibles")
	_sprite = Sprite3D.new()
	_sprite.texture = load(ICONS.get(kind, ICONS["rare_candy"]))
	_sprite.pixel_size = 0.012
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	add_child(_sprite)


func _process(delta: float) -> void:
	_time += delta
	if _flight < FLIGHT_TIME:
		_flight = minf(FLIGHT_TIME, _flight + delta)
		var t := _flight / FLIGHT_TIME
		var ground := _from.lerp(land_at, t)
		global_position = Vector3(ground.x, 4.0 * 1.4 * t * (1.0 - t), ground.z)
	_sprite.position.y = 0.6 + sin(_time * 3.5) * 0.1


func is_landed() -> bool:
	return _flight >= FLIGHT_TIME


func _physics_process(_delta: float) -> void:
	if not is_landed():
		return
	for node in get_tree().get_nodes_in_group("brawlers"):
		var b := node as Brawler
		if b == null or b.is_dead or b.is_legendary:
			continue
		var offset := b.global_position - global_position
		offset.y = 0.0
		if offset.length() <= PICKUP_RADIUS:
			collected.emit(self, b)
			Vfx.burst(get_parent(), global_position + Vector3(0, 0.6, 0), "water" if kind == "rare_candy" else "grass", 12, 0.3, 2.0)
			queue_free()
			return
