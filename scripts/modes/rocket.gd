class_name RocketMode
extends MatchMode
## A round of the Team Rocket Hideout (scripts/data/rocket.gd has the run): 3v3,
## first to kills_to_win KOs. Every Rocket Pokémon is a Shadow Pokémon (darker,
## a purple aura, more HP, hits harder). An Executive's first Pokémon is a big
## shadow ace that flies into a rage when it's hurt. Your Pokémon has a few lives
## for the whole run: faint that many times and the run is over.

var ace: Brawler
var _raged := false


func start() -> void:
	var sh: Dictionary = Rocket.cfg("shadow", {})
	var rounds: Array = Rocket.run.get("rounds", [])
	var boss := false
	if not rounds.is_empty():
		boss = bool((rounds[clampi(int(Rocket.run.get("round", 0)), 0, rounds.size() - 1)] as Dictionary).get("boss", false))
	for b: Brawler in main.teams.get(1, []):
		make_shadow(b, sh)
	if boss and not (main.teams.get(1, []) as Array).is_empty():
		ace = main.teams[1][0]
		ace.size_scale = float(sh.get("ace_size", 1.3))
		ace.hp_scale *= float(sh.get("ace_hp", 1.8)) / float(sh.get("hp", 1.15))
		ace.refresh_stats()
		ace.health = ace.max_health
		for child in ace.get_children():
			if child is BotController:
				(child as BotController).set_difficulty("hard")
	main.hud.announce("Lives: %d" % lives_left())


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


func lives_left() -> int:
	return maxi(0, Rocket.lives(str(Rocket.run.get("difficulty", "normal"))) - int(Rocket.run.get("faints", 0)))


func tick(_delta: float) -> void:
	# The Executive's ace flies into a rage once it's badly hurt.
	if ace and is_instance_valid(ace) and not _raged and not ace.is_dead:
		var sh: Dictionary = Rocket.cfg("shadow", {})
		if ace.health < ace.max_health * float(sh.get("rage_below", 0.5)):
			_raged = true
			ace.apply_buff({ "attack": float(sh.get("rage_attack", 0.25)), "speed": float(sh.get("rage_speed", 0.15)), "duration": 999.0 })
			main.hud.announce("%s's shadow rage!" % ace.species.display_name.to_upper())
			Vfx.ring(ace.get_parent(), ace.global_position, 2.5, "ghost", 50)


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	if victim == main.player:
		Rocket.run["faints"] = int(Rocket.run.get("faints", 0)) + 1
		if lives_left() <= 0:
			main.hud.announce("Out of lives!")
			main.end_round("defeat")
			return true
		main.hud.announce("%d %s left" % [lives_left(), "life" if lives_left() == 1 else "lives"])
	var scoring := 1 - victim.team
	main.scores[scoring] += 1.0
	if main.scores[scoring] >= float(Rocket.cfg("kills_to_win", 8)):
		main.end_round("victory" if scoring == main.player.team else "defeat")
		return true
	return false


## Time's up: more KOs wins; a tie goes to Team Rocket (they're on home ground).
func time_up() -> String:
	return "victory" if main.scores[main.player.team] > main.scores[1 - main.player.team] else "defeat"


## Moves the run on. Returns { subtitle, next (button text), rewards }.
func finish(result: String) -> Dictionary:
	var rounds: Array = Rocket.run.get("rounds", [])
	if rounds.is_empty():
		return {}
	var i := int(Rocket.run.get("round", 0))
	if result != "victory":
		Rocket.run["round"] = 0
		Rocket.run["faints"] = 0
		return { "subtitle": "Team Rocket wins this time... (round %d)" % (i + 1), "next": "TRY AGAIN" }
	var pay := int(Rocket.cfg("rewards/round_money", 150)) * (i + 1)
	Profile.data["money"] = Profile.money() + pay
	if i < rounds.size() - 1:
		Rocket.run["round"] = i + 1
		Profile.save()
		var next: Dictionary = rounds[i + 1]
		return { "subtitle": "Round %d of %d won! +%d ₽  ·  %d %s left" % [i + 1, rounds.size(), pay, lives_left(), "life" if lives_left() == 1 else "lives"],
			"next": "VS %s ›" % str(next["name"]).to_upper(), "money": pay }
	var got := Rocket.clear_rewards()
	Rocket.run["round"] = 0
	Rocket.run["faints"] = 0
	return { "subtitle": "Team Rocket is blasting off again!", "next": "AGAIN", "money": pay, "texts": got["texts"], "balls": got["balls"] }


func scoreboard_info() -> Dictionary:
	return { "goal": "FIRST TO %d  ·  %d ♥" % [int(Rocket.cfg("kills_to_win", 8)), lives_left()] }
