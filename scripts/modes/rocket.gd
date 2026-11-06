class_name RocketMode
extends TeamDuel
## A battle in the Team Rocket Hideout (scripts/data/rocket.gd has the run), with
## TeamDuel's one-on-one rules. Every Rocket Pokémon is a Shadow Pokémon (darker,
## a purple aura, more HP, hits harder). An Executive brings four, and its ace
## comes out last: bigger, and it flies into a rage when it's badly hurt.

var _raged := false


func picks() -> Array:
	return Rocket.run.get("team", [])


func foe_name() -> String:
	return str(main.trainer.get("name", "Team Rocket"))


func between_heal() -> float:
	return float(Rocket.cfg("between_heal", 0.2))


func switch_delay() -> float:
	return float(Rocket.cfg("switch_delay", 1.2))


func time_limit() -> float:
	return float(Rocket.cfg("time_limit", 240))


func prepare_enemies(theirs: Array) -> void:
	var sh: Dictionary = Rocket.cfg("shadow", {})
	var rounds: Array = Rocket.run.get("rounds", [])
	var boss := false
	if not rounds.is_empty():
		boss = bool((rounds[clampi(int(Rocket.run.get("round", 0)), 0, rounds.size() - 1)] as Dictionary).get("boss", false))
	for b: Brawler in theirs:
		make_shadow(b, sh)
	if boss and theirs.size() > 1:
		ace = theirs[theirs.size() - 1]  # Rocket.enemy_order puts the ace last.
		make_ace(ace, float(sh.get("ace_size", 1.3)), float(sh.get("ace_hp", 1.8)) / float(sh.get("hp", 1.15)))


## Shadow Pokémon: tougher and stronger, drawn dark with a purple aura.
static func make_shadow(b: Brawler, sh: Dictionary) -> void:
	b.is_shadow = true
	b.hp_scale *= float(sh.get("hp", 1.15))
	b.damage_scale *= float(sh.get("damage", 1.15))
	b.refresh_stats()
	b.health = b.max_health
	var aura := Vfx.aura("ghost")
	if aura:
		b.add_child(aura)
		aura.position.y = 0.6


func tick(_delta: float) -> void:
	# The Executive's ace flies into a rage once it's badly hurt.
	if ace and is_instance_valid(ace) and not _raged and not ace.is_dead and not main.is_benched(ace):
		var sh: Dictionary = Rocket.cfg("shadow", {})
		if ace.health < ace.max_health * float(sh.get("rage_below", 0.5)):
			_raged = true
			ace.apply_buff({ "attack": float(sh.get("rage_attack", 0.25)), "speed": float(sh.get("rage_speed", 0.15)), "duration": 999.0 })
			main.hud.announce("%s's shadow rage!" % ace.species.display_name.to_upper())
			Vfx.ring(ace.get_parent(), ace.global_position, 2.5, "ghost", 50)


## Moves the run on. Returns { subtitle, next (button text), money, texts, balls }.
func finish(result: String) -> Dictionary:
	var rounds: Array = Rocket.run.get("rounds", [])
	if rounds.is_empty():
		return {}
	var i := int(Rocket.run.get("round", 0))
	if result != "victory":
		Rocket.run["round"] = 0
		return { "subtitle": "Team Rocket wins this time... (battle %d)" % (i + 1), "next": "TRY AGAIN" }
	var pay := Rocket.round_money(i)
	Profile.data["money"] = Profile.money() + pay
	if i < rounds.size() - 1:
		Rocket.run["round"] = i + 1
		Profile.save()
		var next: Dictionary = rounds[i + 1]
		return { "subtitle": "Battle %d of %d won! +%d ₽  ·  your team is healed" % [i + 1, rounds.size(), pay],
			"next": "VS %s ›" % str(next["name"]).to_upper(), "money": pay }
	var got := Rocket.clear_rewards()
	Rocket.run["round"] = 0
	return { "subtitle": "Team Rocket is blasting off again!", "next": "AGAIN", "money": pay, "texts": got["texts"], "balls": got["balls"] }
