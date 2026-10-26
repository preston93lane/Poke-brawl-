class_name MoveData
extends RefCounted
## One attack, loaded from data/moves.json. See docs/DATA.md for field meanings.

var id := ""
var display_name := ""
var type := "normal"
## "melee" (MELEE button, cooldown), "ranged" (right stick, ammo) or "super" (SUPER button).
var slot := "melee"
## "melee" (arc swipe), "dash" (lunge), "projectile", "area" (strike a circle) or "self" (no attack).
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
## Seconds before any attack can be used again; < 0 means use the rules.json default.
var delay := -1.0
## Dash keeps going through enemies, hitting each once.
var dash_pierce := false

# Area (kind "area")
var area_radius := 2.5
var area_delay := 0.0

# Extras usable by any super
## Fraction of damage dealt that heals the user.
var drain := 0.0
## Fraction of max HP healed on use (self), and for allies within support_radius.
var heal := 0.0
var team_heal := 0.0
var support_radius := 0.0
## { "attack"/"defense"/"speed": bonus fraction, "duration": s, "allies": bool }
var buff: Dictionary = {}
## Teleport this many metres in the aim direction.
var blink := 0.0
## { "radius": m, "duration": s } blinds enemies that can see the user.
var blind: Dictionary = {}
## Remove burn, poison, slow and blind from the user.
var cleanse := false
## Damage needed to fill the super meter; < 0 = rules.super_charge_damage.
var charge := -1.0


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
	m.delay = float(d.get("delay", m.delay))
	m.dash_pierce = bool(d.get("dash_pierce", m.dash_pierce))
	m.area_radius = float(d.get("area_radius", m.area_radius))
	m.area_delay = float(d.get("area_delay", m.area_delay))
	m.drain = float(d.get("drain", m.drain))
	m.heal = float(d.get("heal", m.heal))
	m.team_heal = float(d.get("team_heal", m.team_heal))
	m.support_radius = float(d.get("support_radius", m.support_radius))
	var buff_value: Variant = d.get("buff", {})
	m.buff = buff_value if buff_value is Dictionary else {}
	m.blink = float(d.get("blink", m.blink))
	var blind_value: Variant = d.get("blind", {})
	m.blind = blind_value if blind_value is Dictionary else {}
	m.cleanse = bool(d.get("cleanse", m.cleanse))
	m.charge = float(d.get("charge", m.charge))
	return m


## Lockout after using this move, in seconds.
func attack_delay() -> float:
	if delay >= 0.0:
		return delay
	var key := "attack_delay" if slot == "ranged" else "melee_attack_delay"
	return float(GameData.rule(key, 0.4))


## Furthest distance this move can hit from, used for aiming and AI.
func effective_reach() -> float:
	match kind:
		"dash":
			return dash_distance
		"projectile":
			return reach + explode_radius
		"area":
			return reach + area_radius
		"self":
			return maxf(blink, float(blind.get("radius", 0.0)))
	return reach


## Damage needed (with regular moves) to fill the super meter when this is the super.
func charge_damage() -> float:
	return charge if charge > 0.0 else float(GameData.rule("super_charge_damage", 3200.0))
