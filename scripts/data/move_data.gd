class_name MoveData
extends RefCounted
## One attack, loaded from data/moves.json. See docs/DATA.md for field meanings.

var id := ""
var display_name := ""
var type := "normal"
## "melee" (MELEE button, cooldown) or "ranged" (right stick, ammo).
var slot := "melee"
## "melee" (arc swipe), "dash" (lunge that hits the first enemy) or "projectile".
var kind := "melee"
var power := 0.0
var crit_chance := 0.0
var effect: Dictionary = {}

# Melee / dash
var reach := 2.0
var arc := 90.0
var cooldown := 0.8
var dash_distance := 5.0
var dash_speed := 22.0

# Projectile
var speed := 15.0
var ammo := 3
var reload := 1.5
var count := 1
var spread := 0.0
var burst_count := 1
var burst_interval := 0.08
var pierce := false
var radius := 0.3
var explode_radius := 0.0


static func from_dict(move_id: String, d: Dictionary) -> MoveData:
	var m := MoveData.new()
	m.id = move_id
	m.display_name = str(d.get("name", move_id))
	m.type = str(d.get("type", "normal"))
	m.slot = str(d.get("slot", "melee"))
	m.kind = str(d.get("kind", "melee"))
	m.power = float(d.get("power", 500))
	m.crit_chance = float(d.get("crit_chance", 0.0))
	var effect_value: Variant = d.get("effect", {})
	m.effect = effect_value if effect_value is Dictionary else {}
	m.reach = float(d.get("range", m.reach))
	m.arc = float(d.get("arc", m.arc))
	m.cooldown = float(d.get("cooldown", m.cooldown))
	m.dash_distance = float(d.get("dash_distance", m.dash_distance))
	m.dash_speed = float(d.get("dash_speed", m.dash_speed))
	m.speed = float(d.get("speed", m.speed))
	m.ammo = maxi(1, int(d.get("ammo", m.ammo)))
	m.reload = float(d.get("reload", m.reload))
	m.count = maxi(1, int(d.get("count", m.count)))
	m.spread = float(d.get("spread", m.spread))
	m.burst_count = maxi(1, int(d.get("burst_count", m.burst_count)))
	m.burst_interval = float(d.get("burst_interval", m.burst_interval))
	m.pierce = bool(d.get("pierce", m.pierce))
	m.radius = float(d.get("radius", m.radius))
	m.explode_radius = float(d.get("explode_radius", m.explode_radius))
	return m


## Furthest distance this move can hit from, used for aiming and AI.
func effective_reach() -> float:
	match kind:
		"dash":
			return dash_distance
		"projectile":
			return reach + explode_radius
	return reach
