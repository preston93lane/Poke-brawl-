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
			if arena.rows[y][x] in ["T", "#"] and arena.rows[y - 1][x] == "." and arena.rows[y + 1][x] == ".":
				spots["behind"] = arena.cell_center(Vector2i(x, y - 1))
				break
		if spots.has("behind"):
			break
	for shot: String in spots:
		main.player.global_position = spots[shot]
		cam.snap_to_target()
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out_dir, arena_id, shot])
		print("saved ", shot)
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
