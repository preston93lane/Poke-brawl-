extends Node
## Balance simulation: bot-only 3v3 Battles with random teams; appends one JSON
## line per Pokémon per match to the output file.
##   godot --headless --path . res://tools/sim_balance.tscn -- <matches> <out.jsonl> <seed> [level]

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var matches := int(args[0]) if args.size() > 0 else 5
	var out_path := args[1] if args.size() > 1 else "user://sim.jsonl"
	seed(int(args[2]) if args.size() > 2 else 1)
	var level := int(args[3]) if args.size() > 3 else 20
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 64
	Profile.data["dev"] = false
	var pool: Array[String] = []
	for s in GameData.base_species():
		if GameData.bot_allowed(s.id) and not s.legendary:
			pool.append(s.id)
	var arenas := GameData.arenas_for_mode("duel")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	for m in matches:
		pool.shuffle()
		GameData.match_settings = {
			"mode": "duel", "arena": arenas.pick_random(), "species": pool[0], "level": level,
			"allies": [pool[1], pool[2]], "enemies": [pool[3], pool[4], pool[5]], "difficulty": "normal",
		}
		var main := MAIN_SCENE.instantiate()
		main.show_intro = false
		main.record_progress = false
		add_child(main)
		await get_tree().physics_frame
		for c in main.player.get_children():
			if c is PlayerController:
				c.queue_free()
		var bot := BotController.new()
		bot.set_difficulty("normal")
		main.player.add_child(bot)
		var build := Profile.bot_build(main.player.species.id, level)
		main.player.set_build(str(build["gadget"]), str(build["ability"]), bool(build["z"]))
		# Everyone carries a random HM their line can learn (so HMs can be compared).
		for team: int in [0, 1]:
			for b: Brawler in main.teams[team]:
				var hms := Profile.hm_options(b.species.id)
				b.hm_id = str(hms.pick_random()) if not hms.is_empty() else ""
		main.legendaries.clear()
		main._raid_done = true  # No raid legendary: it would skew the numbers.
		var t := 0
		while not main.round_over and t < 400:
			await get_tree().create_timer(1.0, true, false, true).timeout
			t += 1
		var winner: int = 0 if main.scores[0] > main.scores[1] else (1 if main.scores[1] > main.scores[0] else -1)
		var minutes: float = (150.0 - main.time_left) / 60.0
		for team: int in [0, 1]:
			for b: Brawler in main.teams[team]:
				f.store_line(JSON.stringify({ "family": GameData.family_root(b.species.id), "damage": b.damage_dealt,
					"kills": b.kills, "deaths": b.deaths, "win": 1 if winner == team else (0 if winner == 1 - team else 0.5),
					"minutes": minutes, "final": b.species.id, "ability": b.ability_id,
					"gadget": b.gadget_move.id if b.gadget_move else "", "z": b.zmoves_used, "hm": b.hm_id }))
		f.flush()
		main.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	f.close()
	get_tree().quit()
