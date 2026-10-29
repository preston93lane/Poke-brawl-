class_name GymMode
extends MatchMode
## Gym gauntlet (data/gyms.json): full 3v3 matches in a row: two trainers, then
## the Gym Leader, whose first Pokémon is a bigger, tougher ace (a KO on it
## counts leader_kos). The Elite Four is five rounds, each with an ace, each on
## its own arena. First to kills_to_win KOs wins a round. Win them all to beat
## it; lose (or draw) any round and it's back to round 1. Gadget uses carry over.
## The run in progress lives in GameData.gym_run (see start_run / settings_for).

var run: Dictionary = {}
var ace: Brawler


## Starts a fresh run from the menu's choices; returns the first round's match settings.
static func start_run(gym_id: String, difficulty: String, team_type: String, picks: Dictionary) -> Dictionary:
	GameData.gym_run = {
		"gym": gym_id, "round": 0, "difficulty": difficulty, "team_type": team_type,
		"picks": picks, "gadget_uses": int(GameData.rule("gadget/uses", 3)),
	}
	return settings_for(GameData.gym_run)


## Match settings for the run's current round.
static func settings_for(r: Dictionary) -> Dictionary:
	var g := Profile.gym(str(r["gym"]))
	var rounds: Array = g.get("rounds", [])
	var round_data: Dictionary = rounds[clampi(int(r["round"]), 0, rounds.size() - 1)]
	var picks: Dictionary = r.get("picks", {})
	var s := picks.duplicate()
	s["mode"] = "gym"
	s["arena"] = str(round_data.get("arena", r["gym"]))
	var team: Array = []
	for id: String in round_data["team"]:
		# "rival": Blue's starter is the one that beats yours.
		team.append(str(GameData.gyms.get("rival", {}).get(str(Profile.data.get("starter", "")), "charizard")) if id == "rival" else id)
	s["enemies"] = team
	s["allies"] = team_of_type(str(r["team_type"]), str(picks.get("species", "")))
	s["difficulty"] = "hard" if str(r["difficulty"]) == "hard" else "normal"
	return s


## Two random teammates of `type_name` (none = random as usual), not your own line
## if there are enough others. Base forms first; rare types (Dragon, Ice) fill up
## with later stages.
static func team_of_type(type_name: String, player_species: String) -> Array:
	if type_name == "":
		return []
	var pool: Array[String] = []
	var extra: Array[String] = []
	for s: SpeciesData in GameData.species.values():
		if s.legendary or not GameData.bot_allowed(s.id) or not s.has_type(type_name) or GameData.family_root(s.id) == GameData.family_root(player_species):
			continue
		if s.evolves_from == "":
			pool.append(s.id)
		else:
			extra.append(s.id)
	pool.shuffle()
	extra.shuffle()
	pool.append_array(extra)
	if pool.is_empty():
		pool.append(player_species)
	while pool.size() < 2:
		pool.append(pool[0])
	return pool.slice(0, 2)


static func round_title(r: Dictionary) -> String:
	var g := Profile.gym(str(r.get("gym", "")))
	var rounds: Array = g.get("rounds", [])
	var i := clampi(int(r.get("round", 0)), 0, rounds.size() - 1)
	if str(r.get("gym", "")) == "elite_four":
		return "ELITE FOUR %d/%d  ·  %s" % [i + 1, rounds.size(), str(rounds[i]["trainer"]).to_upper()]
	if i >= rounds.size() - 1:
		return "GYM LEADER %s" % str(g.get("leader", "")).to_upper()
	return "ROUND %d/%d  ·  %s" % [i + 1, rounds.size(), str(rounds[i]["trainer"]).to_upper()]


## True if this round's first enemy is a boosted ace (the leader's round, every Elite Four round).
static func has_ace(rounds: Array, i: int) -> bool:
	return bool((rounds[i] as Dictionary).get("ace", i >= rounds.size() - 1))


func start() -> void:
	run = GameData.gym_run
	if run.is_empty():
		return
	main.player.gadget_uses = int(run.get("gadget_uses", 3))
	var rounds: Array = Profile.gym(str(run["gym"])).get("rounds", [])
	if has_ace(rounds, clampi(int(run["round"]), 0, rounds.size() - 1)) and not main.teams[1].is_empty():
		ace = main.teams[1][0]
		ace.size_scale = float(rules.get("ace_size", 1.3))
		ace.hp_scale = float(rules.get("ace_hp_hard" if str(run["difficulty"]) == "hard" else "ace_hp", 1.5))
		ace.refresh_stats()
		ace.health = ace.max_health
		for child in ace.get_children():
			if child is BotController:
				(child as BotController).set_difficulty("hard")


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	var scoring := 1 - victim.team
	main.scores[scoring] += float(rules.get("leader_kos", 2)) if victim == ace else 1.0
	if victim == ace and scoring == main.player.team:
		main.hud.announce("The leader's ace is down! +%d" % int(rules.get("leader_kos", 2)))
	if main.scores[scoring] >= float(rules.get("kills_to_win", 15)):
		main.end_round("victory" if scoring == main.player.team else "defeat")
		return true
	return false


## Called by main when the round ends: moves the run on and returns what to show
## { "subtitle", "next" (button text), "rewards" (gym clear rewards, if any) }.
func finish(result: String) -> Dictionary:
	if run.is_empty():
		return {}
	var g := Profile.gym(str(run["gym"]))
	var rounds: Array = g.get("rounds", [])
	if result != "victory":
		var lost_round := int(run["round"]) + 1
		run["round"] = 0
		run["gadget_uses"] = int(GameData.rule("gadget/uses", 3))
		return { "subtitle": "Lost round %d — the gauntlet starts over" % lost_round, "next": "RETRY GYM" }
	if int(run["round"]) < rounds.size() - 1:
		run["round"] = int(run["round"]) + 1
		run["gadget_uses"] = main.player.gadget_uses
		var next_title := "VS %s ›" % str(rounds[int(run["round"])]["trainer"]).to_upper()
		return { "subtitle": "Round %d of %d won! %d gadget use%s left" % [int(run["round"]), rounds.size(), main.player.gadget_uses, "" if main.player.gadget_uses == 1 else "s"], "next": next_title }
	var rewards := Profile.record_gym_clear(str(run["gym"]), str(run["difficulty"]), str(run["team_type"]))
	run["round"] = 0
	run["gadget_uses"] = int(GameData.rule("gadget/uses", 3))
	return { "subtitle": "You beat %s!" % str(g.get("leader", "")), "next": "AGAIN", "rewards": rewards }


func scoreboard_info() -> Dictionary:
	return { "goal": "FIRST TO %d" % int(rules.get("kills_to_win", 15)) }
