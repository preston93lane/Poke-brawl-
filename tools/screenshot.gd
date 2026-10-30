extends Node
## Renders a match and saves screenshots, for checking how a map looks:
##   godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- <arena_id> <out_dir>
## or, for a menu screen: -- menu:<select|store|bag|battle|challenges|home> <out_dir>
## (on a server, run under xvfb-run). Bots are frozen so the shot is repeatable.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var arena_id := args[0] if args.size() > 0 else "route_1"
	var out_dir := args[1] if args.size() > 1 else "user://shots"
	if arena_id.begins_with("menu:"):
		await _menu_shot(arena_id.trim_prefix("menu:"), out_dir)
		return
	if arena_id.begins_with("showcase"):
		await _showcase(out_dir, arena_id.trim_prefix("showcase").trim_prefix(":").split(",", false))
		return
	if arena_id.begins_with("move:"):
		await _move_demo(arena_id.trim_prefix("move:"), out_dir)
		return
	if arena_id.begins_with("record:"):
		await _record(arena_id.trim_prefix("record:"), out_dir)
		return
	if arena_id.begins_with("gym:"):
		await _gym_shot(arena_id.trim_prefix("gym:"), out_dir)
		return
	if arena_id.begins_with("boss:"):
		await _boss_shot(arena_id.trim_prefix("boss:"), out_dir)
		return
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.arena_id = arena_id
	main.player_species = "pikachu"
	main.enemy_team = PackedStringArray(["bulbasaur", "charmander", "squirtle"])
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	for b in get_tree().get_nodes_in_group("brawlers"):
		for child in b.get_children():
			if child is BotController or child is PlayerController:
				child.queue_free()
	var cam: FollowCamera = main.camera
	var spots := { "spawn": main.player.global_position, "middle": Vector3(0, 0, 4) }
	# Just behind (north of) an inner tree or wall, to check the see-through effect.
	var arena: Arena = main.arena
	for y in range(6, arena.height - 6):
		for x in range(4, arena.width - 4):
			if arena.rows[y][x] in ["T", "#"] and arena.rows[y - 1][x] == ".":
				spots["behind"] = arena.cell_center(Vector2i(x, y - 1))
				break
		if spots.has("behind"):
			break
	# Right beside a wall and just in front of (south of) one: neither should fade.
	for y in range(6, arena.height - 6):
		for x in range(4, arena.width - 4):
			if not spots.has("beside") and arena.rows[y][x] == "." and arena.rows[y][x - 1] == "#" and arena.rows[y - 1][x] == "." and arena.rows[y + 1][x] == ".":
				spots["beside"] = arena.cell_center(Vector2i(x, y))
			if not spots.has("front") and arena.rows[y][x] == "." and arena.rows[y - 1][x] in ["T", "#"] and arena.rows[y + 1][x] == ".":
				spots["front"] = arena.cell_center(Vector2i(x, y))
	for shot: String in spots:
		main.player.global_position = spots[shot]
		cam.snap_to_target()
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out_dir, arena_id, shot])
		print("saved ", shot)
	get_tree().quit()


## Close-up of the animated sprites: a row of Pokémon walking in a circle, then
## attacking, shooting, using a special and getting hurt (frames for a clip).
## showcase:a,b,c,d,e,f picks the six Pokémon (your team first).
func _showcase(out_dir: String, ids: PackedStringArray) -> void:
	if ids.size() != 6:
		ids = PackedStringArray(["pikachu", "charmander", "squirtle", "onix", "charizard", "snorlax"])
	GameData.match_settings = { "mode": "duel", "arena": "pallet_pitch", "species": ids[0], "level": 20,
			"allies": [ids[1], ids[2]], "enemies": [ids[3], ids[4], ids[5]], "difficulty": "normal" }
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	await get_tree().physics_frame
	var all: Array[Brawler] = []
	for t: int in [0, 1]:
		for b: Brawler in main.teams[t]:
			for c in b.get_children():
				if c is BotController or c is PlayerController:
					c.queue_free()
			all.append(b)
	main._raid_done = true
	main.time_left = 9999.0
	var cam: FollowCamera = main.camera
	cam.distance = 13.0
	for i in all.size():
		all[i].global_position = Vector3(-6.0 + i * 2.4, 0, 0)
		all[i].invulnerable = true
	cam.target = all[2]
	cam.lead = 0.0
	cam.snap_to_target()
	var f := 0
	for step in 360:
		await get_tree().physics_frame
		var ang := step * 0.035
		for b in all:
			if step < 140:
				b.move_input = Vector2(cos(ang), sin(ang)) * 0.4
				b.facing = Vector3(cos(ang), 0, sin(ang))
			else:
				b.move_input = Vector2.ZERO
				b.velocity = Vector3.ZERO
		if step in [150, 210, 270, 320]:
			var anim: String = ["attack", "shoot", "special", "hurt"][[150, 210, 270, 320].find(step)]
			for b in all:
				b.facing = Vector3(0, 0, 1)
				b._play_anim(anim, 1.0)
		if step % 2 == 0:
			get_viewport().get_texture().get_image().save_png("%s/frame_%04d.png" % [out_dir, f])
			f += 1
	print("saved showcase")
	get_tree().quit()


## A live bot match, every other frame saved as frame_0000.png... (turn into a clip with ffmpeg).
## Arg: <arena>[,player,ally,ally,enemy,enemy,enemy][,frames]
func _record(spec: String, out_dir: String) -> void:
	var parts := spec.split(",")
	var team: Array = parts.slice(1, 7) if parts.size() >= 7 else ["pikachu", "charmander", "squirtle", "onix", "geodude", "pidgeotto"]
	var frames := int(parts[7]) if parts.size() > 7 else 240
	GameData.match_settings = { "mode": "duel", "arena": parts[0], "species": team[0], "level": 20,
			"allies": [team[1], team[2]], "enemies": [team[3], team[4], team[5]], "difficulty": "normal" }
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	await get_tree().physics_frame
	for c in main.player.get_children():
		if c is PlayerController:
			c.queue_free()
	main.player.add_child(BotController.new())
	main._raid_done = true
	for i in 90:
		await get_tree().process_frame
	for i in frames:
		await get_tree().process_frame
		if i % 2 == 0:
			get_viewport().get_texture().get_image().save_png("%s/frame_%04d.png" % [out_dir, i / 2])
	print("saved record")
	get_tree().quit()


## One move used on a frozen target standing just in front of a wall (so pins
## and tombs show): move:<attacker>,<move id>[,<target>[,<arena>]]. Saves frames.
func _move_demo(spec: String, out_dir: String) -> void:
	var parts := spec.split(",")
	var move := GameData.get_move(parts[1])
	var target_id := parts[2] if parts.size() > 2 else "geodude"
	GameData.match_settings = { "mode": "duel", "arena": parts[3] if parts.size() > 3 else "pewter_gym", "species": parts[0], "level": 20,
			"allies": ["pikachu", "pikachu"], "enemies": [target_id, "pikachu", "pikachu"], "difficulty": "normal" }
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	await get_tree().physics_frame
	main._raid_done = true
	main.time_left = 9999.0
	var arena: Arena = main.arena
	var wall_front := Vector3.ZERO
	for y in range(8, arena.height - 8):
		for x in range(5, arena.width - 5):
			if wall_front == Vector3.ZERO and arena.rows[y - 1][x] == "#" and arena.rows[y][x] == "." \
					and arena.rows[y + 1][x] == "." and arena.rows[y + 2][x] == "." and arena.rows[y + 3][x] == "." and arena.rows[y + 4][x] == ".":
				wall_front = arena.cell_center(Vector2i(x, y))
	var player: Brawler = main.player
	var target: Brawler = main.teams[1][0]
	for b: Brawler in main.teams[0] + main.teams[1]:
		for c in b.get_children():
			if c is BotController or c is PlayerController:
				c.queue_free()
		b._protect_time = 0.0
		if b != player and b != target:
			b.global_position = Vector3(30, 0, 30)  # Out of the way.
	target.global_position = wall_front + Vector3(0, 0, 0.6)
	player.global_position = wall_front + Vector3(0, 0, 3.6)
	player.facing = Vector3(0, 0, -1)
	main.camera.snap_to_target()
	for i in 20:
		await get_tree().physics_frame
	var f := 0
	for step in 200:
		if step == 10:
			player._on_attack(Vector3(0, 0, -1), move)
			player._perform(move, Vector3(0, 0, -1), 3.0)
			player._apply_support(move, Vector3(0, 0, -1))
		await get_tree().physics_frame
		if step % 3 == 0:
			get_viewport().get_texture().get_image().save_png("%s/frame_%04d.png" % [out_dir, f])
			f += 1
	print("saved move demo")
	get_tree().quit()


## A gym's leader round (round 3), a few seconds in.
func _gym_shot(gym_id: String, out_dir: String) -> void:
	GymMode.start_run(gym_id, "normal", "", { "species": "squirtle" })
	GameData.gym_run["round"] = 2
	GameData.match_settings = GymMode.settings_for(GameData.gym_run)
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	for i in 120:
		await get_tree().process_frame
	main.player.global_position = main.mode_logic.ace.global_position + Vector3(0, 0, 4)
	main.camera.snap_to_target()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/gym_%s.png" % [out_dir, gym_id])
	print("saved gym")
	get_tree().quit()


## A Boss Raid a few seconds in, with a telegraphed strike on the way.
func _boss_shot(boss_id: String, out_dir: String) -> void:
	GameData.match_settings = { "mode": "boss_raid", "boss": boss_id, "species": "pikachu",
			"arena": str(GameData.rule("modes/boss_raid/bosses/%s/arena" % boss_id, "route_1")) }
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	for i in 200:
		await get_tree().process_frame
	main.player.global_position = main.mode_logic.boss.global_position + Vector3(0, 0, 5)
	main.camera.snap_to_target()
	main.mode_logic._strike_at(main.player.global_position, 2.2)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/boss_%s.png" % [out_dir, boss_id])
	print("saved boss")
	get_tree().quit()


func _menu_shot(screen: String, out_dir: String) -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	match screen:
		"select":
			menu.show_select("duel")
			for i in 5:
				await get_tree().process_frame
			menu._details_scroll.scroll_vertical = 900
		"store":
			menu.show_store("")
		"bag":
			menu.show_bag()
		"battle":
			menu.show_battle_modes()
		"challenges":
			menu.show_challenges()
		"ball":
			var prizes: Array[Dictionary] = [{ "item": "money", "text": "512 ₽" }, { "item": "rare_candy", "text": "Rare Candy ×3" },
					{ "item": "protein", "text": "Protein" }, { "item": "tm_flamethrower", "text": "TM Flamethrower" },
					{ "item": "pokemon", "text": "A new Pokémon?!" }]
			menu.show_bag()
			menu.play_ball_opening("ultra_ball", prizes)
			for t in [40, 110, 170, 140]:
				for i in t:
					await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("%s/menu_ball_%d.png" % [out_dir, t])
		"bosses":
			menu.show_bosses()
		"select_locked":
			Profile.data["dev"] = false
			menu._species = GameData.species["charmander"]
			menu.show_select("duel")
			for i in 5:
				await get_tree().process_frame
			menu._details_scroll.scroll_vertical = 700
		"dex_mine", "dex_all":
			Profile.data["dev"] = false
			Profile.data["unlocked"] = ["charmander", "pidgey", "rattata", "geodude"]
			menu.show_pokedex("charmander", "mine" if screen == "dex_mine" else "all")
			if screen == "dex_all":
				for i in 3:
					await get_tree().process_frame
				menu._show_dex_entry(GameData.species["scyther"])
		"select_lockedmon":
			Profile.data["dev"] = false
			Profile.data["unlocked"] = ["charmander", "pidgey", "rattata"]
			menu.show_select("duel")
			for i in 3:
				await get_tree().process_frame
			menu._species = GameData.species["scyther"]
			menu._refresh_select_details()
		"dex_build":
			Profile.data["dev"] = false
			Profile.data["unlocked"] = ["charmander", "pidgey", "rattata", "geodude"]
			menu.show_pokedex("charmander", "mine")
			for i in 3:
				await get_tree().process_frame
			menu._details_scroll.scroll_vertical = 800
		"about":
			menu.show_about()
		"gyms":
			menu.show_gyms()
		"gym":
			menu._gym_type = "water"
			menu.show_gym("vermilion_gym")
		"reveal":
			Profile.reveals.append("geodude")
			menu.show_home()
			for t in [30, 60, 100, 120, 150]:
				for i in t:
					await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("%s/menu_reveal_%d.png" % [out_dir, t])
		_:
			menu.show_home()
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [out_dir, screen])
	print("saved ", screen)
	get_tree().quit()
