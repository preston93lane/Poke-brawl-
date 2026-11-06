class_name EliteFourMode
extends TeamDuel
## The Elite Four: five one-on-one trainer battles in a row (TeamDuel's rules),
## Lorelei, Bruno, Agatha, Lance, then Champion Blue. Each brings six Pokémon and
## sends its ace out last (bigger, tougher, with its line's first Ability and a
## Z-Move half charged). You bring six on Easy, five on Normal, four on Hard.
## Your team is healed between battles; lose all yours and it's back to Lorelei.
## The run lives in GameData.gym_run (GymMode.start_run / settings_for).

var run: Dictionary = {}


func picks() -> Array:
	return GameData.gym_run.get("team", [])


func time_limit() -> float:
	return float(GameData.rule("modes/gym/elite_time_limit", 300.0))


func prepare_enemies(theirs: Array) -> void:
	run = GameData.gym_run
	if theirs.size() < 2:
		return
	var rules_gym: Dictionary = GameData.rule("modes/gym", {})
	ace = theirs[theirs.size() - 1]
	make_ace(ace, float(rules_gym.get("ace_size", 1.3)),
			float(rules_gym.get("ace_hp_hard" if str(run.get("difficulty", "")) == "hard" else "ace_hp", 1.5)))
	var abilities: Array = GameData.kit(ace.species.id).get("abilities", [])
	ace.set_build("", str(abilities[0]) if not abilities.is_empty() else "", true)
	ace.z_any_stage = true
	ace.z_charge = float(rules_gym.get("ace_z_charge", 0.5))


## Moves the run on: { subtitle, next (button text), rewards (the clear, if any) }.
func finish(result: String) -> Dictionary:
	if run.is_empty():
		return {}
	var g := Profile.gym("elite_four")
	var rounds: Array = g.get("rounds", [])
	var i := int(run["round"])
	if result != "victory":
		run["round"] = 0
		return { "subtitle": "%s wins — the Elite Four starts over" % str(rounds[i]["trainer"]), "next": "RETRY" }
	if i < rounds.size() - 1:
		run["round"] = i + 1
		return { "subtitle": "%s beaten! (%d of %d)  ·  your team is healed" % [str(rounds[i]["trainer"]), i + 1, rounds.size()],
			"next": "VS %s ›" % str(rounds[i + 1]["trainer"]).to_upper() }
	var rewards := Profile.record_gym_clear("elite_four", str(run["difficulty"]), "")
	run["round"] = 0
	return { "subtitle": "You beat %s! You're the Champion!" % str(g.get("leader", "")), "next": "AGAIN", "rewards": rewards }
