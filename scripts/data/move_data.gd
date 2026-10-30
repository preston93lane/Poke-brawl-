class_name MoveData
extends RefCounted
## One attack, loaded from data/moves/*.json. See docs/DATA.md for field meanings.

var id := ""
var display_name := ""
var type := "normal"
## "main" (right stick, uses ammo), "gadget" (GADGET button, a few uses per match)
## or "super" (SUPER button, charged by damage).
var slot := "main"
## "melee" (arc swipe), "dash" (lunge), "projectile", "stream" (continuous cone while held),
## "area" (strike a circle) or "self" (no attack).
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

# Stream (kind "stream"): power is damage per second, arc is the cone width.
## Seconds of continuous fire from a full tank; `reload` is seconds to refill it.
var tank := 2.0

# Area (kind "area")
var area_radius := 2.5
var area_delay := 0.0

# Extras usable by any super
## Fraction of damage dealt that heals the user.
var drain := 0.0
## Fraction of max HP healed on use (self), and for allies within support_radius.
var heal := 0.0
## Supers only: smashes breakable walls and rocks. Like Brawl Stars, it's the
## physical ones (charges, slams, big explosions; Rock, Ground, Fighting,
## Normal, Steel, Dragon hits) — not streams, heals or status moves. JSON
## "breaks_walls" overrides the rule.
var breaks_walls := false
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
## Seconds of invisibility (ends early if you attack).
var invisible := 0.0
## Fraction of your own max HP spent on use (never knocks you out).
var self_damage := 0.0
## Damage multiplier against targets that already have a status condition (Hex).
var bonus_vs_status := 1.0

# Attack mechanics (mostly projectiles; see docs/DATA.md)
## Arcs over walls and lands where you aim (up to range), hitting everyone around it.
var lob := false
## Times a shot ricochets off walls before it's spent.
var bounces := 0
## Flies out to full range and back to the user, hitting on both legs.
var returns := false
## Damage multiplier reached at full range (snipers hit harder far away).
var distance_bonus := 1.0
## HP healed on teammates the shot passes through (healers).
var heal_allies := 0.0
## Extra enemies the hit jumps to, each within chain_range of the last.
var chain := 0
var chain_range := 3.5
## How fast (radians / s) the shot turns toward the nearest enemy.
var homing := 0.0
## Melee: seconds the user plants and telegraphs the swing before it lands (Frank's super).
var windup := 0.0
## Super: main-attack hits that fill it, whatever their damage (Assassins: 4). 0 = by damage dealt.
var charge_hits := 0
## Seconds a damaging zone stays where the shot lands (power = damage per second then).
var linger := 0.0
var linger_radius := 0.0
## Metres targets are pushed away from you (negative pulls them in).
var knockback := 0.0
## Seconds of damage immunity for the user (Protect).
var protect := 0.0
## Lowers (negative) or raises the target's stats on hit:
## { "attack"/"defense"/"speed": fraction, "duration": s, "chance": 0-1 }.
var stat_change: Dictionary = {}
## Crowd control on hit (data/move_extras.json), by "type":
## "grab": latch on and hold the target (both stay put) for "duration" s, dealing
##   "share" of the power over that time; mashing the stick breaks free sooner.
## "tomb": a ring of rocks ("look": rock / ice) boxes the target in for "duration" s.
## "torrent": carries the target "push" m along the shot; slammed into a wall it's
##   pinned (stunned) for "pin" s and takes "pin_bonus" extra damage.
## "vortex": a whirl at the impact point that drags enemies toward its centre for
##   "duration" s ("pull" m/s), dealing "share" of the power over that time.
var control: Dictionary = {}


static func from_dict(move_id: String, d: Dictionary) -> MoveData:
	var m := MoveData.new()
	m.id = move_id
	m.display_name = str(d.get("name", move_id))
	m.type = str(d.get("type", "normal"))
	m.slot = str(d.get("slot", "main"))
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
	m.tank = float(d.get("tank", m.tank))
	m.area_radius = float(d.get("area_radius", m.area_radius))
	m.area_delay = float(d.get("area_delay", m.area_delay))
	m.drain = float(d.get("drain", m.drain))
	m.heal = float(d.get("heal", m.heal))
	var physical := m.type in ["normal", "fighting", "rock", "ground", "steel", "dragon"]
	var default_breaks := m.heal <= 0.0 and m.power > 0.0 and (m.kind in ["dash", "melee"] \
			or (m.kind in ["projectile", "area"] and (physical or m.explode_radius >= 2.5)))
	m.breaks_walls = bool(d.get("breaks_walls", default_breaks))
	m.team_heal = float(d.get("team_heal", m.team_heal))
	m.support_radius = float(d.get("support_radius", m.support_radius))
	var buff_value: Variant = d.get("buff", {})
	m.buff = buff_value if buff_value is Dictionary else {}
	m.blink = float(d.get("blink", m.blink))
	var blind_value: Variant = d.get("blind", {})
	m.blind = blind_value if blind_value is Dictionary else {}
	m.cleanse = bool(d.get("cleanse", m.cleanse))
	m.charge = float(d.get("charge", m.charge))
	m.invisible = float(d.get("invisible", m.invisible))
	m.self_damage = float(d.get("self_damage", m.self_damage))
	m.bonus_vs_status = float(d.get("bonus_vs_status", m.bonus_vs_status))
	m.lob = bool(d.get("lob", m.lob))
	m.bounces = int(d.get("bounces", m.bounces))
	m.returns = bool(d.get("returns", m.returns))
	m.distance_bonus = float(d.get("distance_bonus", m.distance_bonus))
	m.heal_allies = float(d.get("heal_allies", m.heal_allies))
	m.chain = int(d.get("chain", m.chain))
	m.chain_range = float(d.get("chain_range", m.chain_range))
	m.homing = float(d.get("homing", m.homing))
	m.windup = float(d.get("windup", m.windup))
	m.charge_hits = int(d.get("charge_hits", m.charge_hits))
	m.linger = float(d.get("linger", m.linger))
	m.linger_radius = float(d.get("linger_radius", m.linger_radius))
	m.knockback = float(d.get("knockback", m.knockback))
	m.protect = float(d.get("protect", m.protect))
	var stat_value: Variant = d.get("stat_change", {})
	m.stat_change = stat_value if stat_value is Dictionary else {}
	var control_value: Variant = d.get("control", {})
	m.control = control_value if control_value is Dictionary else {}
	return m


## Rough damage to one target, for comparing supers: every shot and pellet, plus half
## of any damage over time (burns, lingering zones), which is easier to escape.
func estimated_damage() -> float:
	if kind == "self":
		return 0.0  # Heals, buffs, teleports.
	var total := power * count * burst_count
	if linger > 0.0:
		total = power * linger * 0.5
	total += float(effect.get("dps", 0.0)) * float(effect.get("duration", 0.0)) * float(effect.get("chance", 1.0)) * 0.5
	return total


## Fraction of the power dealt on impact: grabs and vortexes deal the rest over time.
func upfront_share() -> float:
	if str(control.get("type", "")) in ["grab", "vortex"]:
		return 1.0 - float(control.get("share", 0.4))
	return 1.0


## Close-range kinds (swipes and lunges) that use the shorter attack delay.
func is_close_range() -> bool:
	return kind == "melee" or kind == "dash"


## One-line description of how the attack works, for menus.
func behaviour_text() -> String:
	var parts: Array[String] = []
	match kind:
		"melee":
			parts.append("360° spin" if arc >= 300.0 else ("long lash" if reach >= 3.0 else "close swipe"))
		"dash":
			parts.append("lunge %.0fm" % dash_distance)
		"stream":
			parts.append("hold to spray")
		"area":
			parts.append("area strike")
		"self":
			parts.append("self")
		"projectile":
			if lob:
				parts.append("lobbed over walls")
			elif count > 1:
				parts.append("%d-shot spread" % count)
			elif burst_count > 1:
				parts.append("%d-shot burst" % burst_count)
			else:
				parts.append("shot")
	if pierce:
		parts.append("pierces")
	if explode_radius > 0.0:
		parts.append("explodes")
	if bounces > 0:
		parts.append("bounces")
	if returns:
		parts.append("returns")
	if homing > 0.0:
		parts.append("homing")
	if chain > 0:
		parts.append("chains ×%d" % chain)
	if linger > 0.0:
		parts.append("leaves a zone")
	if distance_bonus > 1.0:
		parts.append("stronger far away")
	if heal_allies > 0.0:
		parts.append("heals allies")
	if knockback > 0.0:
		parts.append("knockback")
	elif knockback < 0.0:
		parts.append("pulls in")
	if drain > 0.0:
		parts.append("drains")
	if dash_pierce:
		parts.append("goes through")
	return ", ".join(parts)


## Lockout after using this move, in seconds.
func attack_delay() -> float:
	if delay >= 0.0:
		return delay
	var key := "melee_attack_delay" if is_close_range() else "attack_delay"
	return float(GameData.rule(key, 0.4))


## Furthest distance this move can hit from, used for aiming and AI.
func effective_reach() -> float:
	match kind:
		"dash":
			return dash_distance
		"projectile":
			return reach + (explode_radius if not lob else maxf(explode_radius, linger_radius) * 0.5)
		"stream":
			return reach
		"area":
			return reach + area_radius
		"self":
			return maxf(blink, maxf(float(blind.get("radius", 0.0)), support_radius))
	return reach


## Damage needed (with regular moves) to fill the super meter when this is the super.
func charge_damage() -> float:
	return charge if charge > 0.0 else float(GameData.rule("super_charge_damage", 3200.0))
