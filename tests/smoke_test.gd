extends Node
## Headless smoke test: validates data, damage maths, evolution, supers,
## pathfinding and wall sliding, then plays 3v3 Battle and King of the Hill
## matches and drives the menus.
## Run: godot --headless --path . res://tests/smoke_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MENU_SCENE := preload("res://scenes/menu.tscn")

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	# Start from a clean profile with every line unlocked (at level 1) so earlier runs don't matter;
	# the real one is put back at the end.
	var real_profile: Dictionary = Profile.data.duplicate(true)
	Profile.data = Profile.blank()
	for base in GameData.base_species():
		Profile.data["unlocked"].append(base.id)
	_check_data()
	await _check_battle()
	await _check_supers()
	await _check_movement()
	await _check_walls_and_streams()
	await _check_attack_mechanics()
	await _check_gadgets_and_branches()
	await _check_swimming_and_gaps()
	await _check_king_of_the_hill()
	await _check_menu()
	await _check_menu_settings()
	await _check_legendaries_and_items()
	await _check_shrine()
	await _check_breakable_walls()
	await _check_brawl_ball()
	await _check_candy_rush()
	await _check_showdown()
	await _check_settings_and_map_maker()
	await _check_all_arenas()
	await _check_fullscreen_button()
	await _check_intro()
	await _check_menu_fits()
	_check_wall_blocks()
	_check_super_scaling()
	await _check_leech_drain()
	await _check_power_ups()
	await _check_trainer_levels()
	await _check_hazards()
	await _check_progression()
	await _check_hms()
	await _check_faint_stops_attacks()
	await _check_text_boxes()
	await _check_tm_super_shapes()
	await _check_ball_goals_and_walls()
	await _check_boss_raid()
	_check_dailies()
	await _check_gyms()
	_check_starter_order()
	_check_no_mew_bots()
	await _check_mvp()
	await _check_boss_no_heal()
	await _check_slam_windup()
	_check_assassin_charge()
	_check_camera_lead()
	_check_move_looks()
	await _check_controls()
	_check_kit_data()
	await _check_kits_in_match()
	Engine.time_scale = 1.0
	Profile.data = real_profile
	Profile.save()
	print("SMOKE TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _check_data() -> void:
	print("Data")
	expect(GameData.species.size() >= 155, "species loaded (%d)" % GameData.species.size())
	for id in ["bulbasaur", "mew", "mewtwo", "ditto", "snorlax", "kangaskhan", "vaporeon", "jolteon", "flareon", "farfetchd", "mr_mime", "nidoking", "kabutops"]:
		expect(GameData.species.has(id) and not GameData.species[id].legendary, "%s is playable" % id)
	var dex := 0
	for s: SpeciesData in GameData.species.values():
		if not s.legendary:
			dex += 1
	expect(dex >= 148, "the original 151 (minus the three legendary birds) are playable (%d)" % dex)
	expect(GameData.get_species("eevee").evolutions.size() == 3, "eevee branches three ways")
	var raw_hp := float((JSON.parse_string(FileAccess.get_file_as_string("res://data/brawlers/charmander.json")) as Dictionary)["stats"]["hp"])
	expect(is_equal_approx(GameData.get_species("charmander").hp, raw_hp * float(GameData.rule("hp_multiplier", 1.0))), "hp_multiplier raises health")
	expect(ThemeDB.fallback_font.resource_path.ends_with("lilita-one.woff"), "game font installed")
	for line_base in ["geodude", "bellsprout", "gastly", "mankey"]:
		expect(GameData.evolution_line(line_base).size() == 3, "%s line has 3 stages" % line_base)
	expect(GameData.arenas.size() >= 3, "arenas loaded (%d)" % GameData.arenas.size())
	var grass: Array[String] = ["grass"]
	var ground: Array[String] = ["ground"]
	var grass_poison: Array[String] = ["grass", "poison"]
	expect(is_equal_approx(GameData.effectiveness("fire", grass), 1.2), "fire is (mildly) super effective on grass")
	expect(is_equal_approx(GameData.effectiveness("electric", ground), 0.75), "even 'immune' matchups still do most of the damage")
	expect(is_equal_approx(GameData.effectiveness("grass", grass_poison), 0.75), "dual types multiply, within limits")
	var bug: Array[String] = ["bug"]
	expect(GameData.effectiveness("fighting", bug) >= 0.85, "Hitmonlee still hurts Pinsir")
	var supers := {}
	for s: SpeciesData in GameData.species.values():
		expect(s.sprite != null and s.super_move != null, "%s has a sprite and super (%s)" % [s.id, s.super_move.id if s.super_move else "none"])
		supers[s.super_move] = true
		if s.moves_for("main", 1).size() != 1 or s.moves_for("main", 999).size() != 3:
			expect(false, "%s has one main attack variant per level" % s.id)
		if s.gadget_move == null or s.style == "" or not GameData.styles.has(s.style):
			expect(false, "%s has a gadget and a known play style ('%s')" % [s.id, s.style])
	expect(supers.size() == GameData.species.size(), "every Pokémon has its own super")
	expect(GameData.get_species("dragonite").stage == 3 and GameData.get_species("alakazam").stage == 3, "new lines are 3 stages")
	for arena_id: String in GameData.arenas:
		var rows: Array = GameData.arenas[arena_id]["map"]
		expect(rows.size() >= 40 and str(rows[0]).length() >= 30, "%s is large (%dx%d)" % [arena_id, str(rows[0]).length(), rows.size()])


## Most checks hit targets right away, so spawn protection is cleared unless asked to keep it.
func _start_match(arena_id: String, mode: String, player_species: String, enemies: PackedStringArray, keep_protection := false) -> Node:
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.arena_id = arena_id
	main.mode = mode
	main.player_species = player_species
	main.enemy_team = enemies
	add_child(main)
	await get_tree().physics_frame
	if not keep_protection:
		for team: int in [0, 1]:
			for b: Brawler in main.teams[team]:
				b._protect_time = 0.0
	return main


func _check_battle() -> void:
	print("Battle 3v3")
	var main := await _start_match("route_1", "duel", "charmander", ["bulbasaur"])
	var player: Brawler = main.player
	var enemy: Brawler = main.enemy
	expect(main.teams[0].size() == 3 and main.teams[1].size() == 3, "teams are 3v3")
	expect(enemy.species.id == "bulbasaur", "chosen opponent spawned first")
	expect(player.main_move.id == "charmander_main1" and player.main_move.kind == "stream", "level 1 charmander's main attack is its Ember stream")

	var before := enemy.health
	var ember := player.main_move
	enemy.take_hit(player, ember)
	var dealt := before - enemy.health
	var expected := ember.power * player.attack / enemy.defense * GameData.stab * GameData.effectiveness("fire", enemy.species.types) * float(GameData.rule("damage_scale", 1.0))
	expect(dealt > expected * 0.99, "ember on bulbasaur gets STAB + super effective (%d)" % dealt)
	expect(player.super_charge > 0.0, "dealing damage charges the super (%.2f)" % player.super_charge)

	player.register_kill()
	player.register_kill()
	player.respawn(main.arena.spawn_point(0, 0))
	expect(player.evolve_kills == 2, "KOs toward evolving are kept after fainting")
	player.register_kill()
	expect(player.species.id == "charmeleon", "3 total KOs evolve charmander into charmeleon")
	expect(player.species.super_move.id == "flame_charge", "evolving swaps to the new stage's super")
	player.respawn(main.arena.spawn_point(0, 0))
	expect(player.species.id == "charmander", "fainting devolves one stage")

	Engine.time_scale = 4.0
	await get_tree().create_timer(8.0).timeout
	Engine.time_scale = 1.0
	var anyone_moved := false
	for b: Brawler in main.teams[1]:
		if b.global_position.distance_to(main.arena.spawn_point(1, 0)) > 4.0:
			anyone_moved = true
	expect(anyone_moved, "bots leave their spawn and go fight")
	main.scores = [3.0, 3.0]
	main.time_left = 0.01
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(main.round_over and main.hud.result_title.text == "DRAW", "time running out with level scores is a draw")
	main.queue_free()
	await get_tree().process_frame


## Fire every Pokémon's super next to an enemy and check something happened.
func _check_supers() -> void:
	print("Supers")
	var main := await _start_match("boulder_gym", "duel", "pikachu", ["squirtle"])
	var target: Brawler = main.enemy
	for team: int in [0, 1]:
		for other: Brawler in main.teams[team]:
			if other != target:
				other.position = Vector3(0, 0, 18) if team == 0 else Vector3(0, 0, -18)
			for child in other.get_children():
				if child is BotController or child is PlayerController:
					child.queue_free()  # Everyone else stands still, far away.
	Engine.time_scale = 3.0  # 155 Pokémon: run the clock faster.
	for s: SpeciesData in GameData.species.values():
		for rock in get_tree().get_nodes_in_group("tomb_rocks"):
			rock.free()  # The last Pokémon's Rock Tomb / Sheer Cold would block this one's charge.
		var b: Brawler = main._spawn(s.id, 1, 0, false)
		b.position = target.position + Vector3(0, 0, 2.5)
		await get_tree().physics_frame
		target.respawn(target.position)
		# A huge HP pool: a KO would trigger the match's delayed respawn, which would
		# reset the target's health in the middle of the next Pokémon's check.
		target.max_health = 100000.0
		target.health = target.max_health
		target._protect_time = 0.0
		b.health = b.max_health * 0.5
		b.super_charge = 1.0
		var hp_before := b.health
		var to_target := target.global_position - b.global_position
		var used := b.use_super(to_target, Vector2(to_target.x, to_target.z).length())
		await get_tree().create_timer(1.3, false, true).timeout
		var hit := target.health < target.max_health or target.status_text() != ""
		var helped := b.health > hp_before or b.status_text() != "" or b.global_position.distance_to(target.position) > 4.0
		var allied := false
		for ally: Brawler in b.allies_within(8.0):
			if ally.status_text() != "" or ally.health > ally.max_health * 0.99:
				allied = true
		expect(used and (hit or helped or allied), "%s uses %s (used=%s target hp %d/%d status '%s' dead=%s at %s, user at %s)" % [
				s.id, s.super_move.id, used, target.health, target.max_health, target.status_text(), target.is_dead,
				target.global_position, b.global_position])
		b.queue_free()
		await get_tree().process_frame
	Engine.time_scale = 1.0
	main.queue_free()
	await get_tree().process_frame


func _check_movement() -> void:
	print("Movement")
	var main := await _start_match("route_1", "duel", "squirtle", [])
	var arena: Arena = main.arena
	for team: int in [0, 1]:
		for b: Brawler in main.teams[team]:
			if b != main.player:
				b.queue_free()
	await get_tree().physics_frame
	var player: Brawler = main.player
	for child in player.get_children():
		if child is PlayerController:
			child.queue_free()

	# Pathfinding: a route exists from one spawn to the other around obstacles.
	var path: PackedVector3Array = arena.find_path(arena.spawn_point(0, 0), arena.spawn_point(1, 0))
	expect(path.size() > 20, "bots can path across the map (%d steps)" % path.size())

	# Wall slide: push diagonally into the top border wall; we should still move sideways.
	var near_wall := arena.cell_center(Vector2i(10, 1))
	player.position = near_wall
	await get_tree().physics_frame
	var start := player.global_position
	player.move_input = Vector2(0.707, -0.707)
	await get_tree().create_timer(0.5, false, true).timeout
	player.move_input = Vector2.ZERO
	var moved := player.global_position - start
	expect(moved.x > 0.8, "diagonal into a wall slides along it (moved %.2f sideways)" % moved.x)
	main.queue_free()
	await get_tree().process_frame


## Shots, swipes and streams must not go through walls; streams drain and refill a tank.
func _check_walls_and_streams() -> void:
	print("Walls and streams")
	var main := await _start_match("boulder_gym", "duel", "charmander", ["bulbasaur"])
	var arena: Arena = main.arena
	var target: Brawler = main.enemy
	for team: int in [0, 1]:
		for other: Brawler in main.teams[team]:
			if other != target:
				other.position = Vector3(-14, 0, 18 if team == 0 else -18)
			for child in other.get_children():
				if child is BotController or child is PlayerController:
					child.queue_free()
	# The 10-wide rock wall in the north half (cells 13..22, row 8): stand south of it, target north.
	var shooter: Brawler = main._spawn("charmander", 3, 0, false, "charmander_main2")
	shooter.position = arena.cell_center(Vector2i(17, 9))
	target.position = arena.cell_center(Vector2i(17, 6))
	await get_tree().physics_frame
	await get_tree().physics_frame
	Engine.time_scale = 1.0
	shooter.use_main(Vector3.FORWARD)  # Flamethrower is a stream: hold it.
	for i in 30:
		shooter.stream(Vector3.FORWARD)
		await get_tree().physics_frame
	shooter._perform(GameData.get_move("ekans_main1"), Vector3.FORWARD, -1.0)  # A long lash.
	await get_tree().create_timer(0.6, false, true).timeout
	expect(is_equal_approx(target.health, target.max_health), "attacks don't pass through walls (target hp %d/%d)" % [target.health, target.max_health])

	var fast := MoveData.from_dict("test_bolt", { "type": "electric", "slot": "main", "kind": "projectile", "power": 500, "speed": 80, "range": 8 })
	shooter._spawn_projectile(fast, Vector3.FORWARD)
	await get_tree().create_timer(0.4, false, true).timeout
	expect(is_equal_approx(target.health, target.max_health), "very fast shots don't skip through walls")

	# Clear line: stream for a second, check damage, tank drain and refill.
	target.position = arena.cell_center(Vector2i(11, 12))
	shooter.position = arena.cell_center(Vector2i(11, 15))
	await get_tree().physics_frame
	shooter._attack_lock = 0.0
	var fuel_before := shooter.ammo
	for i in 60:
		shooter.stream(Vector3.FORWARD)
		await get_tree().physics_frame
	expect(target.health < target.max_health, "stream damages in range (%d dealt)" % (target.max_health - target.health))
	expect(shooter.ammo < fuel_before - 0.2, "stream drains its tank (%.2f -> %.2f)" % [fuel_before, shooter.ammo])
	var drained := shooter.ammo
	await get_tree().create_timer(1.5, false, true).timeout
	expect(shooter.ammo > drained + 0.1, "tank refills after you stop (%.2f -> %.2f)" % [drained, shooter.ammo])
	main.queue_free()
	await get_tree().process_frame


func _check_king_of_the_hill() -> void:
	print("King of the hill")
	for arena_id in ["boulder_gym", "dragons_den"]:
		var main := await _start_match(arena_id, "king_of_the_hill", "dratini", [])
		expect(main.mode == "king_of_the_hill" and main.arena.has_zone(), "%s supports king of the hill" % arena_id)
		Engine.time_scale = 4.0
		var reached := false
		for i in 40:  # 40 game-seconds, sampled every second.
			await get_tree().create_timer(0.25).timeout
			for team: int in [0, 1]:
				for b: Brawler in main.teams[team]:
					if b != main.player and not b.is_dead and main.arena.is_in_zone(b.global_position):
						reached = true
			if reached:
				break
		Engine.time_scale = 1.0
		expect(reached, "bots walk into the zone on %s" % arena_id)
		main.queue_free()
		await get_tree().process_frame


func _check_menu() -> void:
	print("Menu")
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_select("duel")
	await get_tree().process_frame
	menu.show_select("king_of_the_hill")
	await get_tree().process_frame
	var ball_maps: Array[String] = GameData.arenas_for_mode("brawl_ball")
	expect("pallet_pitch" in ball_maps and "vermilion_gym" in ball_maps and "route_1" not in ball_maps, "only goal arenas offer Brawl Ball (%s)" % ", ".join(ball_maps))
	expect("viridian_forest" in GameData.arenas_for_mode("showdown") and "viridian_forest" not in GameData.arenas_for_mode("duel"), "Viridian Forest is Showdown-only")
	for mode_id in ["brawl_ball", "candy_rush", "showdown"]:
		menu.show_select(mode_id)
		await get_tree().process_frame
	expect(menu._arena == "random" or menu._arena in GameData.arenas_for_mode("king_of_the_hill"), "king of the hill only offers arenas with a zone (or random)")
	menu.show_select("duel")
	menu._type_filter = "fire"
	menu._fill_species_grid()
	await get_tree().process_frame
	var all_fire: bool = menu._grid.get_child_count() >= 4
	for grid_card in menu._grid.get_children():
		var picked: SpeciesData = null
		for s in GameData.base_species():
			if grid_card is Button and (grid_card as Button).text == s.display_name:
				picked = s
		if picked == null or not menu._matches_filters(picked):
			all_fire = false
	expect(all_fire, "type filter shows only fire Pokémon (%d)" % menu._grid.get_child_count())
	menu._type_filter = "steel"
	menu._fill_species_grid()
	var steel_names: Array[String] = []
	for grid_card in menu._grid.get_children():
		if grid_card is Button:
			steel_names.append((grid_card as Button).text)
	expect("Magnemite" in steel_names and "Charmander" not in steel_names, "dual types count: Magnemite is under steel (%s)" % ", ".join(steel_names))
	menu._type_filter = ""
	menu._fill_species_grid()
	await get_tree().process_frame
	await get_tree().process_frame
	# Drag the species list with a finger: it scrolls, and the card under the finger isn't picked.
	var list: DragScroll = menu._grid.get_parent()
	var picked_before: SpeciesData = menu._species
	var rect := list.get_global_rect()
	var from := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.8)
	print("    list rect %s, scroll max %d" % [rect, list.get_v_scroll_bar().max_value])
	_touch(from, true)
	for i in 8:
		_drag(from - Vector2(0, 30 * (i + 1)), Vector2(0, -30))
	_touch(from - Vector2(0, 240), false)
	await get_tree().process_frame
	expect(list.scroll_vertical > 100, "dragging scrolls the species list (%d px)" % list.scroll_vertical)
	expect(menu._species == picked_before, "a drag doesn't pick the Pokémon under your finger")
	var card: Button = null
	for child in menu._grid.get_children():
		var b := child as Button
		if b and not b.button_pressed and b.get_global_rect().intersects(rect):
			var visible_rect := b.get_global_rect().intersection(rect)
			if visible_rect.size.y > 40:
				card = b
				break
	if card:
		var at := card.get_global_rect().intersection(rect).get_center()
		_touch(at, true)
		_touch(at, false)
		await get_tree().process_frame
		expect(menu._species != picked_before and menu._species.display_name == card.text, "a tap picks %s" % card.text)
	else:
		expect(false, "found a card to tap")
	menu.show_pokedex("alakazam")
	await get_tree().process_frame
	expect(menu._details.get_child_count() > 8, "pokédex shows an entry")
	menu.show_home()
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame


func _touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 913  # Like iPhone Safari: finger ids aren't 0.
	e.position = at
	e.pressed = pressed
	get_viewport().push_input(e, true)


func _drag(at: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 913
	e.position = at
	e.relative = relative
	get_viewport().push_input(e, true)


## Stop every bot and park everyone but the player (and `keep`) far away.
func _freeze_all(main: Node, keep: Brawler = null) -> void:
	for team: int in main.teams:
		for b: Brawler in main.teams[team]:
			for child in b.get_children():
				if child is BotController or child is PlayerController:
					child.queue_free()
			if b != main.player and b != keep:
				b.position = Vector3(-14, 0, 18 if team == 0 else -18)
			b.move_input = Vector2.ZERO
	await get_tree().physics_frame


func _check_legendaries_and_items() -> void:
	print("Legendaries, items, spawn protection, animation")
	var main := await _start_match("route_1", "duel", "charmander", ["squirtle"], true)
	await _freeze_all(main, main.enemy)
	var player: Brawler = main.player
	var enemy: Brawler = main.enemy

	expect(player.is_protected(), "players spawn with protection")
	var hp := player.health
	player.take_hit(enemy, enemy.main_move)
	expect(is_equal_approx(player.health, hp), "spawn protection blocks damage")
	player._protect_time = 0.0
	player.take_hit(enemy, enemy.main_move)
	expect(player.health < hp, "damage lands once protection ends")

	expect(player.species.sprite is AtlasTexture and player.species.sheet != null, "sprites load as front/side/back sheets")
	var missing_shiny: Array[String] = []
	for s: SpeciesData in GameData.species.values():
		if s.sheet == null or s.shiny_sheet == null or s.sheet.get_height() != 96 or s.sprite_height <= 0:
			missing_shiny.append(s.id)
	expect(missing_shiny.is_empty(), "every Pokémon has 96px normal + shiny sheets (missing: %s)" % ", ".join(missing_shiny))
	var no_anims: Array[String] = []
	for s: SpeciesData in GameData.species.values():
		if not (s.pmd.has("walk") and s.pmd.has("idle") and ResourceLoader.exists("res://assets/pmd/%s/walk.png" % s.id)):
			no_anims.append(s.id)
	expect(no_anims.is_empty(), "every Pokémon has animated walk + idle sprites (missing: %s)" % ", ".join(no_anims))
	var shiny_bot: Brawler = main._spawn("charizard", 1, 1, false)
	shiny_bot.shiny = true
	shiny_bot._apply_species()
	await get_tree().process_frame
	expect(shiny_bot.sprite.texture.resource_path.contains("/shiny/"), "shiny Pokémon use the shiny animations")
	shiny_bot.queue_free()
	# Facing picks one of the 8 direction rows: down, down-right, right, up-right, up, up-left, left, down-left.
	for case: Array in [[Vector3(1, 0, 0), 2], [Vector3(-1, 0, 0), 6], [Vector3(0, 0, -1), 4], [Vector3(0, 0, 1), 0]]:
		player.facing = case[0]
		await get_tree().process_frame
		await get_tree().process_frame
		expect(floori(float(player.sprite.frame) / player.sprite.hframes) == case[1], "facing %s shows direction row %d" % case)

	var base_attack := player.get_attack()
	var base_ammo := player.max_ammo()
	var base_hp := player.max_health
	player.health = player.max_health * 0.4
	for item_id in ["potion", "pp_up", "protein", "hp_up"]:
		main.spawn_item(item_id, player.global_position)
		await get_tree().physics_frame
		await get_tree().physics_frame
	expect(get_tree().get_nodes_in_group("items").is_empty(), "walking over items picks them up")
	expect(player.health > player.max_health * 0.5, "potion heals")
	expect(player.max_ammo() > base_ammo + 0.3, "PP Up adds ammo (a bigger tank for streams)")
	expect(player.get_attack() > base_attack * 1.15, "Protein boosts attack")
	expect(player.max_health > base_hp * 1.15, "HP Up raises max HP")
	player.respawn(main.arena.spawn_point(0, 0))
	expect(is_equal_approx(player.max_ammo(), base_ammo) and is_equal_approx(player.get_attack(), base_attack), "item boosts end when you faint")

	main.time_left = 89.0
	await get_tree().physics_frame
	var boss: Brawler = main.raid_boss
	expect(boss != null and boss.team == 9 and boss.is_legendary, "raid boss appears at 1:30 (%s)" % (boss.species.id if boss else "none"))
	if boss:
		for child in boss.get_children():
			if child is BotController:
				child.queue_free()
		boss.take_damage(1500.0, enemy)
		boss.take_damage(boss.health - 600.0, player)
		boss.take_damage(600.0, enemy)  # The red team lands the last hit...
		await get_tree().physics_frame
		expect(main.legendaries.size() == 1 and main.legendaries[0].team == 0,
				"...but blue dealt the most damage, so blue gets %s" % (main.legendaries[0].species.id if main.legendaries.size() > 0 else "nothing"))
		if main.legendaries.size() > 0:
			var ally: Brawler = main.legendaries[0]
			var ally_hp := ally.health
			expect(ally.max_health < player.max_health * 3.0 and ally.max_health > player.max_health * 1.3,
					"the legendary ally has about twice normal health (%d vs %d)" % [ally.max_health, player.max_health])
			ally.take_damage(800.0, enemy)
			expect(ally.health < ally_hp and ally.flying, "the legendary ally can be hurt, and flies")
			main._dismiss_legendary(ally)
			expect(main.legendaries.is_empty(), "the legendary leaves after its time")
	main.queue_free()
	await get_tree().process_frame


func _check_shrine() -> void:
	print("Shrine control")
	var main := await _start_match("boulder_gym", "king_of_the_hill", "geodude", [])
	await _freeze_all(main)
	main.player._protect_time = 0.0
	main.player.position = main.arena.zone_center
	Engine.time_scale = 4.0
	await get_tree().create_timer(22.0).timeout  # Game seconds (timers follow time_scale).
	Engine.time_scale = 1.0
	expect(main.legendaries.size() == 1 and main.legendaries[0].species.id == "regirock" and main.legendaries[0].team == 0,
			"holding the zone alone for 20 s awakens Regirock for your team")
	main.queue_free()
	await get_tree().process_frame


func _check_menu_settings() -> void:
	print("Menu settings")
	GameData.match_settings = {
		"mode": "king_of_the_hill", "arena": "route_1", "species": "squirtle", "level": 2,
		"main": "squirtle_main1", "allies": ["abra"], "enemies": ["dratini", "pikachu"], "bot_level": 2,
	}
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	add_child(main)
	await get_tree().physics_frame
	expect(main.mode == "king_of_the_hill" and main.arena.has_zone(), "route 1 has a zone in king of the hill")
	expect(main.player.species.id == "squirtle" and main.player.level == 2, "menu choice of pokémon and level applied")
	expect(main.player.main_move.id == "squirtle_main1", "menu main attack applied")
	expect(main.teams[0][1].species.id == "abra", "chosen teammate applied")
	expect(main.teams[1][0].species.id == "dratini" and main.teams[1][1].species.id == "pikachu", "chosen opponents applied")
	expect(main.teams[1].size() == 3, "empty slots filled randomly")
	GameData.match_settings = {}
	main.queue_free()
	await get_tree().process_frame


## A shooter and a target alone on the map, everyone else parked and frozen.
func _duel_setup(arena_id: String, shooter_id: String) -> Array:
	var main := await _start_match(arena_id, "duel", shooter_id, ["rattata"])
	await _freeze_all(main, main.enemy)
	var shooter: Brawler = main.player
	var target: Brawler = main.enemy
	target.max_health = 100000.0
	target.health = target.max_health
	return [main, shooter, target]


func _reset_target(target: Brawler, at: Vector3) -> void:
	target.position = at
	target.health = target.max_health
	target._clear_status()
	target._knock_time = 0.0
	target._protect_time = 0.0


func _check_attack_mechanics() -> void:
	print("Attack mechanics")
	var setup := await _duel_setup("boulder_gym", "bulbasaur")
	var main: Node = setup[0]
	var shooter: Brawler = setup[1]
	var target: Brawler = setup[2]
	var arena: Arena = main.arena
	var forward := Vector3.FORWARD

	# Lob: Seed Bomb arcs over the rock wall (row 14) and lands on the target behind it.
	shooter.position = arena.cell_center(Vector2i(17, 16))
	_reset_target(target, arena.cell_center(Vector2i(17, 12)))
	await get_tree().physics_frame
	shooter._perform(GameData.get_move("bulbasaur_main1"), forward, 4.0)
	await get_tree().create_timer(1.0, false, true).timeout
	expect(target.health < target.max_health, "lobbed shots fly over walls (%d dealt)" % (target.max_health - target.health))

	# Open ground for the rest: the middle of the south half.
	var base := arena.cell_center(Vector2i(17, 30))
	shooter.position = base
	await get_tree().physics_frame

	# Heal-through: Disarming Voice heals a teammate it passes and still hits the enemy behind.
	var ally: Brawler = main._spawn("geodude", 1, 0, false)
	ally.position = base + forward * 1.5
	_reset_target(target, base + forward * 4.0)
	await get_tree().physics_frame
	ally.health = ally.max_health * 0.5
	var ally_hp := ally.health
	shooter._perform(GameData.get_move("clefairy_main1"), forward, -1.0)
	await get_tree().create_timer(0.8, false, true).timeout
	expect(ally.health > ally_hp + 100.0, "healer waves heal teammates they pass (%d -> %d)" % [ally_hp, ally.health])
	expect(target.health < target.max_health, "...and hurt the enemy behind")
	ally.queue_free()

	# Chain: Thunder Shock jumps from the first enemy to a second one nearby.
	var second: Brawler = main._spawn("rattata", 1, 1, false)
	second.max_health = 100000.0
	_reset_target(target, base + forward * 3.0)
	await get_tree().physics_frame
	_reset_target(second, base + forward * 3.0 + Vector3(2.0, 0, 0))
	await get_tree().physics_frame
	shooter._perform(GameData.get_move("pikachu_main1"), forward, -1.0)
	await get_tree().create_timer(0.35, false, true).timeout
	expect(target.health < target.max_health and is_equal_approx(second.health, second.max_health),
			"chain lightning sticks to the first enemy before jumping")
	await get_tree().create_timer(0.8, false, true).timeout
	expect(second.health < second.max_health, "...then flies over to a second enemy nearby")
	second.queue_free()

	# Boomerang: goes out and comes back, hitting on both legs.
	_reset_target(target, base + forward * 3.0)
	await get_tree().physics_frame
	var boomerang := GameData.get_move("drowzee_main1")
	var one_hit: float = GameData.calc_damage(boomerang, shooter, target)["amount"]
	shooter._perform(boomerang, forward, -1.0)
	await get_tree().create_timer(1.8, false, true).timeout
	var boomerang_damage := target.max_health - target.health
	expect(boomerang_damage > one_hit * 1.5, "boomerangs hit on the way out and back (%d vs one hit %d)" % [boomerang_damage, one_hit])

	# No homing: shots aimed 30° off miss.
	var homing_moves := 0
	for id: String in GameData.moves:
		if (GameData.moves[id] as MoveData).homing > 0.0:
			homing_moves += 1
	expect(homing_moves == 0, "no attack homes in on targets")
	# Multi-shot attacks can't do much more at point blank than a normal attack.
	var worst := 0.0
	for id: String in GameData.moves:
		var m: MoveData = GameData.moves[id]
		if m.slot == "main" and m.kind == "projectile" and (m.count > 1 or m.burst_count > 1):
			worst = maxf(worst, m.power * m.count * m.burst_count)
	expect(worst <= 1300.0, "multi-shot mains top out at 1300 if every shot hits (%d)" % worst)
	var snorlax_super: MoveData = GameData.get_move("snorlax_super")
	expect(snorlax_super.kind == "melee" and is_equal_approx(snorlax_super.arc, 90.0), "Snorlax's super is an aimed 90° slam")

	# Linger: String Shot leaves a zone that keeps hurting.
	_reset_target(target, base + forward * 3.0)
	await get_tree().physics_frame
	shooter._perform(GameData.get_move("caterpie_main1"), forward, 3.0)
	await get_tree().create_timer(0.7, false, true).timeout
	var after_land := target.health
	await get_tree().create_timer(1.2, false, true).timeout
	expect(target.health < after_land, "lingering zones keep dealing damage (%d -> %d)" % [after_land, target.health])
	await get_tree().create_timer(3.0, false, true).timeout

	# Knockback and pull.
	_reset_target(target, base + forward * 1.5)
	await get_tree().physics_frame
	shooter._perform(GameData.get_move("mankey_main3"), forward, -1.0)
	await get_tree().create_timer(0.4, false, true).timeout
	var knocked := target.global_position.distance_to(shooter.global_position)
	expect(knocked > 2.3, "knockback pushes the target away (%.2f m)" % knocked)
	_reset_target(target, base + forward * 3.5)
	await get_tree().physics_frame
	shooter._perform(GameData.get_move("ekans_main2"), forward, -1.0)
	await get_tree().create_timer(0.4, false, true).timeout
	var pulled := target.global_position.distance_to(shooter.global_position)
	expect(pulled < 3.0, "pull attacks drag the target in (%.2f m)" % pulled)

	# Bounce: Pay Day ricochets off a wall instead of disappearing.
	shooter.position = arena.cell_center(Vector2i(2, 23))
	_reset_target(target, base + forward * 12.0)
	await get_tree().physics_frame
	var bouncer := GameData.get_move("meowth_main1")
	shooter._spawn_projectile(bouncer, Vector3.LEFT)
	await get_tree().create_timer(0.25, false, true).timeout
	var bounced := false
	for node in main.arena.get_children():
		var p := node as Projectile
		if p and p.move == bouncer and p._bounces_left < bouncer.bounces and p.direction.x > 0.5:
			bounced = true
	expect(bounced, "bouncing shots ricochet off walls")

	# Dash slam: Nidoran's super lunges and hits everyone around where it lands.
	shooter.position = base
	_reset_target(target, base + forward * 4.0)
	await get_tree().physics_frame
	var slam := GameData.get_move("nidoran_f_super")
	shooter._perform(slam, forward, -1.0)
	await get_tree().create_timer(0.8, false, true).timeout
	expect(target.health < target.max_health, "slam dashes hit around the landing spot")

	# Main attacks of every kind spend ammo; supers charge only from main attacks.
	shooter.ammo = shooter.max_ammo()
	shooter._attack_lock = 0.0
	var ammo_before := shooter.ammo
	expect(shooter.use_main(forward) and shooter.ammo < ammo_before, "main attacks use ammo")
	main.queue_free()
	await get_tree().process_frame


func _check_gadgets_and_branches() -> void:
	print("Gadgets and branching evolutions")
	var setup := await _duel_setup("route_1", "eevee")
	var main: Node = setup[0]
	var player: Brawler = setup[1]
	var uses := player.gadget_uses
	expect(uses == int(GameData.rule("gadget/uses", 3)), "gadgets start with %d uses" % uses)
	expect(player.use_gadget(Vector3.FORWARD) and player.gadget_uses == uses - 1, "using a gadget spends a use")
	expect(not player.use_gadget(Vector3.FORWARD), "gadgets have a cooldown")
	expect(player.is_protected(), "Protect shields you")
	for i in uses:
		player._gadget_timer = 0.0
		player.use_gadget(Vector3.FORWARD)
	expect(player.gadget_uses == 0 and not player.gadget_ready(), "gadgets run out")

	player.preferred_evolution = "jolteon"
	player.evolve()
	expect(player.species.id == "jolteon", "eevee evolves into the chosen branch")
	expect(player.main_move.id.begins_with("jolteon_main"), "the branch brings its own main attack (%s)" % player.main_move.id)
	player.respawn(main.arena.spawn_point(0, 0))
	expect(player.species.id == "eevee" and player.main_move.id.begins_with("eevee_main"), "fainting goes back to eevee's attack")

	# Every gadget does something without errors.
	var gadgets := {}
	for s: SpeciesData in GameData.species.values():
		if s.gadget_move:
			gadgets[s.gadget_move.id] = s.id
	for gadget_id: String in gadgets:
		var b: Brawler = main._spawn(gadgets[gadget_id], 1, 0, false)
		b.position = main.arena.cell_center(Vector2i(17, 30))
		await get_tree().physics_frame
		b._protect_time = 0.0
		b.health = b.max_health * 0.5
		var before_pos := b.global_position
		var hp_before := b.health
		var used := b.use_gadget(Vector3.RIGHT)
		await get_tree().physics_frame
		var did := b.health > hp_before or b.is_protected() or b.status_text() != "" or b.global_position.distance_to(before_pos) > 1.0 \
				or b.species.gadget_move.kind == "area"
		expect(used and did, "%s works (%s)" % [gadget_id, gadgets[gadget_id]])
		b.queue_free()
		await get_tree().process_frame
	main.queue_free()
	await get_tree().process_frame


func _check_swimming_and_gaps() -> void:
	print("Swimming and narrow gaps")
	var main := await _start_match("dragons_den", "duel", "charmander", [])
	await _freeze_all(main)
	var arena: Arena = main.arena
	var player: Brawler = main.player

	# Dragon's Den: the lane between the pond (columns 9-13, rows 19-20) and the middle.
	player.position = arena.cell_center(Vector2i(14, 17))
	await get_tree().physics_frame
	player.move_input = Vector2(0, 1)
	await get_tree().create_timer(1.6, false, true).timeout
	player.move_input = Vector2.ZERO
	expect(arena.world_to_cell(player.global_position).y >= 21, "walkers fit past the pond (reached row %d)" % arena.world_to_cell(player.global_position).y)

	# Walkers stop at water; Water and Flying types go across it.
	player.position = arena.cell_center(Vector2i(7, 19))
	await get_tree().physics_frame
	player.move_input = Vector2(1, 0)
	await get_tree().create_timer(1.0, false, true).timeout
	player.move_input = Vector2.ZERO
	expect(not arena.is_water(player.global_position) and not player.can_swim, "charmander can't walk into water")
	for swimmer_id in ["squirtle", "pidgey"]:
		var swimmer: Brawler = main._spawn(swimmer_id, 1, 0, false)
		swimmer.position = arena.cell_center(Vector2i(7, 19))
		await get_tree().physics_frame
		swimmer.move_input = Vector2(1, 0)
		await get_tree().create_timer(0.7, false, true).timeout
		swimmer.move_input = Vector2.ZERO
		expect(swimmer.can_swim and arena.is_water(swimmer.global_position), "%s walks out onto the water" % swimmer_id)
		swimmer.queue_free()
	var swim_path: PackedVector3Array = arena.find_path(arena.cell_center(Vector2i(10, 18)), arena.cell_center(Vector2i(10, 21)), true)
	var walk_path: PackedVector3Array = arena.find_path(arena.cell_center(Vector2i(10, 18)), arena.cell_center(Vector2i(10, 21)))
	expect(swim_path.size() > 0 and swim_path.size() < walk_path.size(), "swimmers path straight over the pond (%d vs %d steps)" % [swim_path.size(), walk_path.size()])

	# A bot can walk around the central pillars and ponds without getting stuck.
	var walker: Brawler = main._spawn("geodude", 1, 0, false)
	walker.position = arena.cell_center(Vector2i(9, 15))
	await get_tree().physics_frame
	var bot := BotController.new()
	walker.add_child(bot)
	bot.set_physics_process(false)  # Only follow the path we ask for.
	Engine.time_scale = 3.0
	var goal := arena.cell_center(Vector2i(14, 21))
	var arrived := false
	for i in 80:
		bot._go_to(goal, 0.1)
		await get_tree().create_timer(0.1, false, true).timeout
		if walker.global_position.distance_to(goal) < 1.0:
			arrived = true
			break
	Engine.time_scale = 1.0
	bot.queue_free()
	expect(arrived, "bots path through Dragon's Den's centre (ended %.1f m away)" % walker.global_position.distance_to(goal))
	main.queue_free()
	await get_tree().process_frame


func _check_breakable_walls() -> void:
	print("Breakable walls")
	var main := await _start_match("boulder_gym", "duel", "geodude", [])
	await _freeze_all(main)
	var arena: Arena = main.arena
	var wall: Breakable = null
	for node in get_tree().get_nodes_in_group("breakables"):
		if (node as Breakable).kind == "wall":
			wall = node
			break
	expect(wall != null and not arena.is_walkable(wall.global_position), "maps have breakable walls that block paths")
	var player: Brawler = main.player
	expect(not wall.take_attack(player, player.main_move), "main attacks don't break walls")
	var cell := wall.cell
	expect(not wall.take_attack(player, player.species.super_move), "self-buff supers (Defense Curl) don't break walls")
	expect(wall.take_attack(player, GameData.get_move("flame_charge")), "physical supers smash breakable walls")
	await get_tree().physics_frame
	expect(arena.is_walkable(arena.cell_center(cell)), "the smashed tile can be walked on")
	main.end_round("victory")
	await get_tree().process_frame
	expect(main.hud._summary != null and main.summary_rows().size() == 6, "the match ends on a summary of all 6 Pokémon")
	var mvps: Array = main.summary_rows().filter(func(r: Dictionary) -> bool: return r["mvp"])
	expect(mvps.size() == 1, "one MVP")
	main.queue_free()
	await get_tree().process_frame


func _check_brawl_ball() -> void:
	print("Brawl Ball")
	var main := await _start_match("pallet_pitch", "brawl_ball", "machop", [])
	await _freeze_all(main)
	var arena: Arena = main.arena
	var ball: Ball = main.mode_logic.ball
	var player: Brawler = main.player
	expect(ball != null and arena.goal_cells[0].size() > 0 and arena.goal_cells[1].size() > 0, "pitch has a ball and two goals")
	player.position = arena.cell_center(Vector2i(17, 5))
	ball.reset(player.position)
	ball._all_lock = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(ball.carrier == player and player.ball == ball, "walking onto the ball picks it up")
	player._attack_lock = 0.0
	var goal := arena.goal_center(1)
	expect(player.use_main(goal - player.global_position), "attacking while carrying kicks the ball")
	await get_tree().create_timer(1.0, false, true).timeout
	expect(main.scores[0] == 1.0 and player.goals == 1, "kicking it into their goal scores (score %s)" % [main.scores])
	expect(ball.global_position.distance_to(arena.center_point()) < 1.0, "the ball goes back to the middle")
	main.mode_logic._reset_pause = 0.0
	ball.reset(goal)
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(main.round_over and main.hud.result_title.text == "VICTORY!", "two goals wins")
	main.queue_free()
	await get_tree().process_frame


func _check_candy_rush() -> void:
	print("Rare Candy Rush")
	var main := await _start_match("route_1", "candy_rush", "pikachu", [])
	await _freeze_all(main, main.enemy)
	var logic: Node = main.mode_logic
	var player: Brawler = main.player
	var enemy: Brawler = main.enemy
	logic.spawn_candy(player.global_position, player.global_position)
	await get_tree().create_timer(0.7, false, true).timeout
	expect(player.candies == 1 and player.candies_collected == 1, "walking over a Rare Candy collects it")
	enemy.candies = 3
	enemy._protect_time = 0.0
	enemy.take_damage(1000000.0, player)
	await get_tree().physics_frame
	expect(enemy.candies == 0 and get_tree().get_nodes_in_group("collectibles").size() >= 3, "fainting drops your candies")
	player.candies = 10
	await get_tree().physics_frame
	expect(logic.countdown_team == 0, "holding 10 candies with the lead starts the countdown")
	logic.countdown_left = 0.05
	await get_tree().create_timer(0.2, false, true).timeout
	expect(main.round_over and main.hud.result_title.text == "VICTORY!", "surviving the countdown wins")
	main.queue_free()
	await get_tree().process_frame


func _check_showdown() -> void:
	print("Showdown")
	var main := await _start_match("viridian_forest", "showdown", "charmander", [])
	var logic: Node = main.mode_logic
	var player: Brawler = main.player
	expect(main.teams.size() == 6, "six Pokémon, each on its own team")
	var spawn_spread := INF
	for a: int in main.teams:
		for b: int in main.teams:
			if a < b:
				spawn_spread = minf(spawn_spread, main.teams[a][0].global_position.distance_to(main.teams[b][0].global_position))
	expect(spawn_spread > 6.0, "spawns are spread out (closest %.1f m)" % spawn_spread)
	await _freeze_all(main)
	var crate: Breakable = null
	for node in get_tree().get_nodes_in_group("breakables"):
		if (node as Breakable).kind == "crate":
			crate = node
	expect(crate != null, "the map has power-cube crates")
	var hp_before := player.max_health
	var at := crate.global_position
	for i in 40:
		player._attack_lock = 0.0
		crate.take_attack(player, player.main_move)
		if crate.is_broken:
			break
	expect(crate.is_broken, "attacks break crates")
	await get_tree().create_timer(0.6, false, true).timeout
	player.position = at
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(player.power_cubes == 1 and player.max_health > hp_before * 1.05, "power cubes add max HP (%d -> %d)" % [hp_before, player.max_health])
	player.position = main.arena.nearest_open(Vector3(0, 0, 3))
	await get_tree().physics_frame
	logic.elapsed = 200.0
	var victim: Brawler = main.teams[1][0]
	victim._protect_time = 0.0
	victim.position = main.arena.nearest_open(Vector3(-14, 0, -18))
	await get_tree().physics_frame
	var victim_hp := victim.health
	await get_tree().create_timer(1.2, false, true).timeout
	expect(victim.health < victim_hp, "the poison cloud hurts Pokémon outside the safe zone")
	player.health = player.max_health
	for team: int in main.teams:
		if team != 0:
			var b: Brawler = main.teams[team][0]
			b._protect_time = 0.0
			if not b.is_dead:
				b.take_damage(10000000.0, player)
			await get_tree().physics_frame
	await get_tree().create_timer(0.5, false, true).timeout
	expect(main.round_over and main.hud.result_title.text == "VICTORY!", "last one standing wins Showdown")
	expect(not main.teams[1][0].is_dead or main.teams[1][0].respawn_left <= 0.0, "nobody respawns")
	var rows: Array[Dictionary] = main.summary_rows()
	expect(rows[0]["is_player"] and int(rows[0]["placement"]) == 1, "the summary ranks you #1")
	main.queue_free()
	await get_tree().process_frame


func _check_settings_and_map_maker() -> void:
	print("Settings, sorting and map maker")
	expect(GameData.base_species()[0].id == "bulbasaur" and GameData.base_species(true)[0].id == "abra", "Pokémon sort by Pokédex number (A-Z optional)")
	# Control layout: swapped sides puts the move stick on the right half.
	var layout: Dictionary = GameData.DEFAULT_LAYOUT.duplicate(true)
	layout["swapped"] = true
	layout["move"] = [0.8, 0.75]
	layout["aim"] = [0.2, 0.75]
	GameData.set_setting("layout", layout)
	var main := await _start_match("route_1", "duel", "charmander", [])
	expect(is_equal_approx(main.hud.move_stick.anchor_left, 0.5) and is_equal_approx(main.hud.aim_stick.anchor_left, 0.0), "saved control layout is used in matches")
	main.queue_free()
	await get_tree().process_frame
	GameData.settings.erase("layout")
	GameData.save_settings()

	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_settings()
	await get_tree().process_frame
	menu.show_map_editor()
	await get_tree().process_frame
	var editor = menu._screen.get_child(0)
	editor.mirror = "quad"
	editor.brush = "X"
	editor.paint(Vector2i(5, 10))
	expect(editor.cell(Vector2i(30, 10)) == "X" and editor.cell(Vector2i(5, 37)) == "X" and editor.cell(Vector2i(30, 37)) == "X", "quadrant mirroring paints all four corners")
	editor.mirror = "vertical"
	editor.brush = "1"
	editor.paint(Vector2i(10, 40))
	expect(editor.cell(Vector2i(10, 7)) == "2" and editor.cell(Vector2i(25, 40)) == ".", "top/bottom mirroring flips spawns to the other team only")
	editor._name_edit.text = "Smoke Test Arena"
	editor.floor_tile = "sand"
	editor.wall_tile = "brick"
	editor.liquid = "lava"
	editor.brush = "~"
	editor.paint(Vector2i(17, 20))
	editor.brush = "K"
	editor.paint(Vector2i(8, 15))
	editor.brush = "I"
	editor.paint(Vector2i(12, 15))
	var id: String = editor.save()
	expect(GameData.is_custom_arena(id) and id in GameData.arenas_for_mode("duel"), "saved maps show up in the mode lists (%s)" % id)
	menu.queue_free()
	await get_tree().process_frame
	var custom := await _start_match(id, "duel", "charmander", [])
	var arena: Arena = custom.arena
	expect(arena.liquid == "lava" and custom.player.can_swim, "lava maps: Fire types walk on lava")
	var squirtle: Brawler = custom._spawn("squirtle", 1, 0, false)
	await get_tree().physics_frame
	expect(not squirtle.can_swim, "...and Water types don't")
	expect(not arena.is_walkable(arena.cell_center(Vector2i(8, 15))) and not arena.is_walkable(arena.cell_center(Vector2i(12, 15))), "gravestones and ice blocks block the way")
	custom.queue_free()
	await get_tree().process_frame
	GameData.delete_custom_arena(id)
	expect(not GameData.arenas.has(id), "custom maps can be deleted")


func _check_all_arenas() -> void:
	print("Every arena")
	expect(GameData.arenas.size() >= 19, "gyms, Elite Four, graveyard and Safari Zone are in (%d arenas)" % GameData.arenas.size())
	for arena_id: String in GameData.arenas:
		var allowed: Array = GameData.arenas[arena_id].get("modes", [])
		var mode: String = allowed[0] if not allowed.is_empty() else "duel"
		var main := await _start_match(arena_id, mode, "pikachu", [])
		var arena: Arena = main.arena
		var path: PackedVector3Array = arena.find_path(main.teams[0][0].global_position, main.teams[1][0].global_position)
		var ok: bool = not path.is_empty() and (mode == "showdown" or (arena.spawns[0].size() >= 3 and arena.spawns[1].size() >= 3))
		expect(ok, "%s builds with spawns and a route between teams (%d steps)" % [arena_id, path.size()])
		if arena_id == "viridian_gym":
			# Brick walls: rounded blocks, one MultiMesh per shape with the texture variant per copy.
			var walls := 0
			for child in arena.get_children():
				var mmi := child as MultiMeshInstance3D
				if mmi and mmi.multimesh.use_custom_data and mmi.multimesh.mesh is ArrayMesh:
					walls += mmi.multimesh.instance_count
			expect(walls > 100, "brick walls are rounded blocks sharing materials (%d)" % walls)
		main.queue_free()
		await get_tree().process_frame


## Every line: supers get stronger as it evolves, and TM supers hit softer on
## earlier stages (in matches and on the build screen alike).
func _check_super_scaling() -> void:
	print("Supers scale up with evolution")
	var bad: Array[String] = []
	var checked := 0
	for base in GameData.base_species():
		var line := GameData.evolution_line(base.id)
		if line.size() < 2:
			continue
		var final_stage: SpeciesData = line.back()
		for stage in line:
			if stage == final_stage or stage.evolves_to == "":
				continue
			var own := stage.super_move.estimated_damage()
			if own > 0.0 and own > final_stage.super_move.estimated_damage():
				bad.append("%s's own super (%d) beats %s's (%d)" % [stage.id, own, final_stage.id, final_stage.super_move.estimated_damage()])
			var allowed := Profile.stage_tm_supers(stage.id)
			for tm in allowed:
				if tm not in Profile.stage_tm_supers(final_stage.id):
					continue
				var early := GameData.stage_super(stage, tm, allowed)
				var late := GameData.stage_super(final_stage, tm, Profile.stage_tm_supers(final_stage.id))
				checked += 1
				if early.power >= late.power:
					bad.append("%s %s %d vs %s %d" % [stage.id, tm, early.power, final_stage.id, late.power])
	expect(bad.is_empty() and checked > 50, "every TM super is weaker on earlier stages (%d checked) %s" % [checked, ", ".join(bad.slice(0, 6))])
	var bulba := GameData.stage_super(GameData.species["bulbasaur"], "tmsuper_leaf_storm", Profile.stage_tm_supers("bulbasaur"))
	var venu := GameData.stage_super(GameData.species["venusaur"], "tmsuper_leaf_storm", Profile.stage_tm_supers("venusaur"))
	expect(bulba.power < venu.power * 0.8, "Leaf Storm: Bulbasaur %d, Venusaur %d" % [bulba.power, venu.power])
	for id in ["withdraw", "flash", "teleport", "defense_curl", "agility", "bulk_up", "hypnosis"]:
		var m := GameData.get_move(id)
		expect(m.power >= 650, "%s does real damage now (%d)" % [id, m.power])
	var seed := GameData.get_move("leech_seed")
	var seed_total := seed.power + float(seed.effect["dps"]) * float(seed.effect["duration"])
	expect(seed_total >= 1100.0, "Leech Seed: a hit plus a drain, %d in all" % seed_total)
	# Scaled TM supers that have no status effect must still scale (this used to fail silently).
	var gi := GameData.stage_super(GameData.species["pidgeotto"], "tmsuper_giga_impact", Profile.stage_tm_supers("pidgeotto"))
	expect(gi.display_name == "Giga Impact", "an equipped TM super is used on a middle stage (%s)" % gi.display_name)


func _check_leech_drain() -> void:
	print("Leech drain stacks")
	var main := await _start_match("pallet_pitch", "duel", "bulbasaur", ["squirtle"])
	var me: Brawler = main.player
	var foe: Brawler = main.teams[1][0]
	await _freeze_all(main)
	me.health = me.max_health * 0.5
	var seed := GameData.get_move("leech_seed")
	foe._apply_effect(seed.effect, me, "grass")
	foe._apply_effect(seed.effect, me, "grass")
	expect(foe.leech_stacks() == 2, "two seeds make two stacks")
	var foe_hp := foe.health
	var my_hp := me.health
	for i in 70:
		await get_tree().physics_frame
	expect(foe.health < foe_hp - 400.0 and me.health > my_hp + 300.0, "the seeds drain the target and heal the planter (%d taken, %d healed)" % [foe_hp - foe.health, me.health - my_hp])
	main.queue_free()
	await get_tree().process_frame


func _check_wall_blocks() -> void:
	print("Rounded wall blocks")
	var alone := Arena.rounded_block("brick", 0)
	var joined := Arena.rounded_block("brick", 3, 3)
	expect(alone.get_faces().size() > 300, "a lone wall block has rounded edges (%d face verts)" % alone.get_faces().size())
	expect(joined.get_faces().size() < alone.get_faces().size(), "sides against permanent walls are left out")
	var box := alone.get_aabb()
	expect(box.size.x > 1.0 and box.size.x < 1.2 and is_equal_approx(box.position.y, -Arena.WALL_HEIGHT * 0.5),
			"brick's ledge sticks out a little and the block sits on the floor (%s)" % str(box))


func _check_fullscreen_button() -> void:
	print("Full screen button")
	var fs: Node = get_node("/root/FullscreenButton")
	var view := get_viewport().get_visible_rect().size
	var rect: Rect2 = Rect2(fs._button.position, fs._button.size)
	expect(rect.end.x <= view.x and rect.position.x > view.x - 70 and rect.position.y < 20, "full screen button sits in the top-right corner (%s)" % rect)
	var main := await _start_match("route_1", "duel", "pikachu", [])
	var scoreboard_panel := Rect2(view.x * 0.5 - 150 - 3 * 54 - 12, 10, 300 + 2 * (3 * 54 + 12), 62)
	expect(not rect.intersects(scoreboard_panel), "it doesn't cover the scoreboard")
	expect(not rect.intersects(Rect2(main.hud.super_button.get_global_rect())) and not rect.intersects(Rect2(main.hud.gadget_button.get_global_rect())), "or the buttons")
	main.queue_free()
	await get_tree().process_frame


func _check_intro() -> void:
	print("Match intro")
	var main := MAIN_SCENE.instantiate()
	main.arena_id = "pewter_gym"
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var banners := 0
	for child in main.hud.get_children():
		if child.get_script() == main.MATCH_INTRO:
			banners += 1
	expect(get_tree().paused and banners == 1, "the team banners play before the match, with the game paused")
	await get_tree().create_timer(2.5, true).timeout
	expect(get_tree().paused, "the intro takes its time")
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(400, 300)
	get_viewport().push_input(tap, true)
	await get_tree().create_timer(1.5, true).timeout
	expect(get_tree().paused and main.intro_done(), "tapping skips the intro, then 3-2-1-GO plays")
	await get_tree().create_timer(3.0, true).timeout
	expect(not get_tree().paused, "the match starts after GO!")
	main.queue_free()
	await get_tree().process_frame


## Every menu screen must fit the window: nothing pushed off the right edge.
func _check_menu_fits() -> void:
	print("Menus fit the screen")
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var view := get_viewport().get_visible_rect().size
	var screens := []
	for mode_id in ["duel", "king_of_the_hill", "brawl_ball", "candy_rush", "showdown"]:
		screens.append(["select " + mode_id, func() -> void: menu.show_select(mode_id)])
	screens.append(["pokédex", func() -> void: menu.show_pokedex("mewtwo")])
	screens.append(["settings", func() -> void: menu.show_settings()])
	screens.append(["map maker", func() -> void: menu.show_map_editor()])
	screens.append(["home", func() -> void: menu.show_home()])
	screens.append(["bag", func() -> void: menu.show_bag()])
	screens.append(["store", func() -> void: menu.show_store("")])
	screens.append(["starter", func() -> void: menu._set_screen(TrainerScreens.starter(menu))])
	screens.append(["account", func() -> void: menu.show_account("")])
	screens.append(["battle modes", func() -> void: menu.show_battle_modes()])
	screens.append(["challenges", func() -> void: menu.show_challenges()])
	screens.append(["profile", func() -> void: menu.show_profile()])
	for entry in screens:
		entry[1].call()
		for i in 3:
			await get_tree().process_frame
		var width: float = menu._screen.get_combined_minimum_size().x
		expect(width <= view.x, "%s fits the screen (needs %d of %d px)" % [entry[0], width, view.x])
	menu.queue_free()
	await get_tree().process_frame


func _check_power_ups() -> void:
	print("Power Ups and evolving heals")
	var main := await _start_match("route_1", "duel", "tauros", [])
	var tauros: Brawler = main.player
	var hp := tauros.max_health
	tauros.health = tauros.max_health * 0.5
	for i in 3:
		tauros.register_kill()
	expect(tauros.power_ups == 1 and tauros.max_health > hp * 1.1, "single-stage Pokémon power up every 3 KOs (%d -> %d)" % [hp, tauros.max_health])
	expect(tauros.health < tauros.max_health * 0.9, "powering up only heals a little")
	for i in 9:
		tauros.register_kill()
	expect(tauros.power_ups == 2, "two Power Ups at most")
	tauros.respawn(main.arena.spawn_point(0, 0))
	expect(tauros.power_ups == 0, "fainting loses them")
	main.queue_free()
	await get_tree().process_frame


func _check_trainer_levels() -> void:
	print("Trainer levels and fast evolving")
	expect(GameData.get_species("charmander").evolve_level == 16 and GameData.get_species("charmeleon").evolve_level == 36, "main-series evolve levels loaded")
	expect(GameData.family_root("charizard") == "charmander", "Charizard's line is Charmander's")
	var main := await _start_match("route_1", "duel", "charmander", [])
	var p: Brawler = main.player
	expect(p.trainer_level == Profile.level_of("charmander"), "the player gets their profile level")
	p.trainer_level = 1
	expect(p.kills_needed() == 3, "a low level evolves after 3 KOs")
	p.trainer_level = 16
	expect(p.kills_needed() == 2, "level 16 Charmander evolves after 2 KOs")
	p.register_kill()
	p.register_kill()
	expect(p.species.id == "charmeleon", "evolved after 2 KOs (%s)" % p.species.id)
	expect(p.kills_needed() == 3, "Charmeleon still needs 3 below level 36")
	p.trainer_level = 36
	p.register_kill()
	p.register_kill()
	expect(p.species.id == "charizard", "level 36 evolves Charmeleon after 2 KOs")
	main.queue_free()
	await get_tree().process_frame
	main = await _start_match("route_1", "duel", "tauros", [])
	var t: Brawler = main.player
	t.trainer_level = 20
	expect(t.kills_needed() == 2, "first Power Up is fast at level 20")
	t.register_kill()
	t.register_kill()
	expect(t.power_ups == 1 and t.kills_needed() == 3, "second Power Up needs level 40")
	main.queue_free()
	await get_tree().process_frame
	var saved: Dictionary = Profile.data.duplicate(true)
	Profile.set_level("charizard", 30)
	expect(Profile.level_of("charmander") == 30, "levels are stored per evolution line")
	expect(not Profile.try_dev_code("wrong"), "a wrong dev code is refused")
	Profile.data["dev"] = true
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_dev()
	await get_tree().process_frame
	menu.show_select("duel")
	await get_tree().process_frame
	expect(menu._details.get_child_count() > 3, "dev tools and the trainer level panel open")
	menu.queue_free()
	Profile.data = saved
	Profile.save()


func _check_hazards() -> void:
	print("Hazards")
	var main := await _start_match("cinnabar_gym", "duel", "squirtle", [])
	await _freeze_all(main)
	var hazards: Hazards = main.arena.hazards
	expect(hazards != null and not main.arena.vent_cells.is_empty(), "Cinnabar has fire vents")
	var vent: Vector3 = main.arena.cell_center(main.arena.vent_cells[0])
	var p: Brawler = main.player
	p.position = vent
	p.invulnerable = false
	p.health = p.max_health
	var hp := p.health
	for i in 360:
		p.position = vent
		await get_tree().physics_frame
	expect(p.health < hp, "standing on a vent burns (%d -> %d)" % [hp, p.health])
	main.queue_free()
	await get_tree().process_frame

	main = await _start_match("saffron_gym", "duel", "squirtle", [])
	await _freeze_all(main)
	var pads: Array[Vector2i] = main.arena.warp_cells
	expect(pads.size() >= 2, "Saffron has warp pads (%d)" % pads.size())
	p = main.player
	var start: Vector3 = main.arena.cell_center(pads[0])
	p.position = start
	for i in 3:
		await get_tree().physics_frame
	expect(p.global_position.distance_to(start) > 5.0, "a warp pad sends you across the map")
	main.queue_free()
	await get_tree().process_frame

	main = await _start_match("vermilion_gym", "duel", "squirtle", [])
	await _freeze_all(main)
	expect(main.arena.weather == "lightning", "Vermilion has lightning")
	p = main.player
	p.health = p.max_health
	hp = p.health
	hazards = main.arena.hazards
	hazards._strike_timer = 0.0
	await get_tree().physics_frame
	expect(not hazards._strikes.is_empty(), "lightning warning circles appear")
	hazards._warn_strike(p.global_position)
	for i in 120:
		await get_tree().physics_frame
	expect(p.health < hp, "standing in a lightning circle gets you struck (%d -> %d)" % [hp, p.health])
	main.queue_free()
	await get_tree().process_frame
	expect(GameData.arenas.has("ss_anne"), "the S.S. Anne is a map")


func _check_progression() -> void:
	print("Progression")
	var saved: Dictionary = Profile.data.duplicate(true)
	Profile.data = Profile.blank()
	expect(Profile.needs_starter(), "a new profile picks a starter")
	Profile.choose_starter("charmander")
	expect(Profile.is_unlocked("charizard") and Profile.is_unlocked("pidgey") and not Profile.is_unlocked("bulbasaur"), "starter line and free Pokémon unlocked, others locked")
	expect(Profile.unlocked_mains("charmander") == ["charmander_main1"], "only the first main attack at level 1")
	var charmander: SpeciesData = GameData.get_species("charmander")
	expect(int(charmander.learnset[1]["level"]) == 24 and str(charmander.learnset[1]["tm"]) == "tm_flamethrower", "Flamethrower at level 24 or by TM")
	expect(Profile.super_options("charmander") == ["fire_spin"], "Charmander has only Fire Spin without a TM")
	expect(Profile.super_options("charizard").slice(0, 3) == ["blast_burn", "flame_charge", "fire_spin"], "Charizard can pick any of its line's supers")
	Profile._add_tm("tm_fire_blast")
	expect("tmsuper_fire_blast" in Profile.super_options("charmander"), "an owned TM super is an option at every stage")
	Profile._add_tm("tm_hurricane")
	Profile._add_tm("tm_hyper_beam")
	expect("tmsuper_hurricane" not in Profile.super_options("charmander") and "tmsuper_hurricane" in Profile.super_options("charizard"),
			"Flying TM supers only for Flying stages (Charizard yes, Charmander no)")
	expect("tmsuper_hyper_beam" not in Profile.super_options("charizard"), "no Hyper Beam for the Charmander line")
	for base in GameData.base_species():
		for stage in GameData.evolution_line(base.id):
			if Profile.stage_tm_supers(stage.id).size() < 2:
				expect(false, "%s has at least two TM supers to aim for" % stage.id)
	Profile.set_loadout("charizard", "super_charizard", "fire_spin")
	expect(Profile.super_choices("charmander") == { "charizard": "fire_spin" }, "picks are saved per stage")
	Profile._add_tm("tm_flamethrower")
	expect("charmander_main2" in Profile.unlocked_mains("charmander"), "the TM unlocks it early")
	var r := Profile.record_match({ "species": "charmander", "result": "victory", "kos": 4, "mvp": true, "arena": "pewter_gym", "difficulty": "normal", "raid": "" })
	expect(int(r["xp"]) == (100 + 40 + 25) * 2, "XP: win + KOs + MVP, doubled for the first win of the day (%d)" % int(r["xp"]))
	expect(int(r["money"]) == 60 + 20 and Profile.money() == 80, "Poké Dollars for winning")
	expect((r["balls"] as Array).size() >= 2, "a ball for the win plus the first-win Great Ball (%s)" % str(r["balls"]))
	expect(Profile.level_of("charmander") > 1, "levelled up (Lv %d)" % Profile.level_of("charmander"))
	expect(str(r["family"]) == "charmander" and r.has("xp_before") and int(r["xp_after"]) == Profile.xp_of("charmander"),
			"the result screen gets the XP before and after, to fill the bar")
	var st: Dictionary = Profile.data["stats"]
	expect(int(st.get("kos", 0)) >= 4 and int(st.get("mvps", 0)) >= 1 and int((st["family_matches"] as Dictionary).get("charmander", 0)) >= 1,
			"Profile stats count KOs, MVPs and matches per Pokémon")
	expect(Profile.favourite_family() == "charmander", "the most-played line is the favourite")
	Profile.data.erase("seen")
	expect(Profile.has_news("store"), "new stock shows a dot on the Poké Mart")
	Profile.mark_seen("store")
	expect(not Profile.has_news("store"), "opening the Poké Mart clears its dot")
	Profile._give("ultra_ball", 1)
	var prizes := Profile.open_ball("ultra_ball")
	expect(prizes.size() >= 2 and prizes[0]["item"] == "money", "an Ultra Ball has ₽ plus more (%d prizes)" % prizes.size())
	var candies := 0
	for i in 200:
		Profile._give("poke_ball", 1)
		for prize: Dictionary in Profile.open_ball("poke_ball"):
			if prize["item"] == "rare_candy":
				candies += 1
	expect(candies == 0, "Poké Balls never give Rare Candies (%d of 200)" % candies)
	var before := Profile.count("rare_candy")
	Profile._give("ultra_ball", 1)
	Profile.open_ball("ultra_ball")
	expect(Profile.count("rare_candy") > before, "an Ultra Ball always has a Rare Candy")
	Profile.data["shinies"] = []  # Ultra Balls can hold a shiny; the shiny checks below start from none.
	Profile._give("protein", 12)
	for i in 12:
		Profile.give_vitamin("charmander", "protein")
	expect(Profile.active_vitamin_total("charmander") == 10, "at most 10 vitamins active")
	expect(is_equal_approx(float(Profile.vitamin_bonus("charmander")["attack"]), 0.03 * 5 + 0.015 * 5), "half value after 5 in one stat")
	Profile._give("hm_fly", 1)
	expect(Profile.teach_hm("charmander", "fly") and "fly" in Profile.learned_hms("charizard"), "HMs teach one line")
	expect(not Profile.teach_hm("charmander", "surf"), "and only HMs that fit it")
	expect(not Profile.has_shiny("charmander"), "shinies start locked")
	var h := Profile.hunt()
	expect(str(h["family"]) in Profile.data["unlocked"], "the weekly hunt targets one of your Pokémon (%s)" % h["family"])
	var target := str(h["family"])
	h["kos"] = 0
	h["wins"] = 0
	for i in 14:
		Profile._track_hunt(target, 7, true)
	expect(not Profile.has_shiny(target), "not a pushover: 98 KOs and 14 wins isn't enough")
	Profile._track_hunt(target, 7, true)
	expect(Profile.has_shiny(target), "100 KOs and 15 wins with it unlocks its shiny")
	Profile.data["money"] = 100000
	Profile.data["store"]["day"] = ""
	Profile._give("master_ball", 40)
	for i in 40:
		Profile.open_ball("master_ball")
	expect((Profile.data["shinies"] as Array).size() >= 2, "Master Balls can hold shinies (%d owned)" % (Profile.data["shinies"] as Array).size())
	var slots := Profile.store_slots()
	expect(slots.size() == 6, "six store slots")
	Profile.data["store"]["slots"] = [{ "item": "protein", "rarity": "common" }]
	for i in 7:
		Profile.buy("protein")
	expect(Profile.bought_today("vitamin") == 5, "store caps vitamins at 5 a day")
	Profile.data["store"] = {}
	slots = Profile.store_slots()
	Profile.data["store"]["slots"] = [{ "item": "rare_candy", "rarity": "common" }, { "item": "great_ball", "rarity": "rare" }]
	var first_price := Profile.store_price("rare_candy")
	expect(Profile.buy("rare_candy", 0) and Profile.store_price("rare_candy") == int(round(first_price * 1.25 / 10.0) * 10), "each buy makes the next 25%% dearer (%d → %d)" % [first_price, Profile.store_price("rare_candy")])
	Profile.buy("rare_candy", 0)
	Profile.buy("rare_candy", 0)
	expect(Profile.cant_buy("rare_candy", 0) == "Sold out", "common slots sell 3 a day")
	expect(Profile.buy("great_ball", 1) and Profile.cant_buy("great_ball", 1) == "Sold out", "rare slots sell once a day")
	var main := await _start_match("route_1", "duel", "charmander", [])
	expect(main.player.attack > GameData.get_species("charmander").attack * 1.2, "vitamins boost stats in a match")
	main.queue_free()
	await get_tree().process_frame
	for i in 60:
		Profile._add_xp("charmander", 5000)
	Profile.data["stats"]["arena_mvps"]["pewter_gym"] = 10
	var found: Dictionary = Profile._check_unlocks()
	expect("geodude" in found["pokemon"] and Profile.is_unlocked("spearow") and Profile.is_unlocked("bulbasaur") and Profile.is_unlocked("squirtle"),
			"challenges, the trainer road and the starter levels unlock new lines")
	expect(not Profile.is_unlocked("mewtwo") and not Profile.is_unlocked("mew"), "Mewtwo and Mew need everything else first")
	for base in GameData.base_species():
		if base.id not in ["mewtwo", "mew"]:
			Profile.unlock(base.id)
	for boss in ["zapdos", "moltres", "articuno"]:
		Profile._stat_dict("boss_wins")[boss] = 5  # Boss Raid wins (Battle raids don't count).
	Profile._check_unlocks()
	expect(Profile.is_unlocked("mewtwo") and not Profile.is_unlocked("mew"), "Mewtwo after every other line and all raids")
	Profile.data = saved
	Profile.save()


func _check_hms() -> void:
	print("HMs")
	var main := await _start_match("route_1", "duel", "charmander", [])
	await _freeze_all(main)
	var arena: Arena = main.arena
	var p: Brawler = main.player
	# Cut: stand next to tall grass and cut it down.
	var grass_cell := Vector2i(-1, -1)
	for i in arena._grass_order.size():
		var c: Vector2i = arena._grass_order[i]
		if arena.is_walkable(arena.cell_center(c + Vector2i(0, 1))) and arena._char_at(c + Vector2i(0, 1)) == ".":
			grass_cell = c
			break
	p.position = arena.cell_center(grass_cell + Vector2i(0, 1))
	await get_tree().physics_frame
	p.hm_id = "cut"
	expect(p.use_hm(Vector3(0, 0, -1)) and not arena.is_tall_grass(arena.cell_center(grass_cell)), "Cut clears tall grass")
	expect(not p.use_hm(Vector3.FORWARD), "HMs recharge before they can be used again")
	p._hm_cooldown = 0.0
	# Rock Smash: breaks the wall in front.
	var wall: Breakable = null
	for node in get_tree().get_nodes_in_group("breakables"):
		var b := node as Breakable
		if b and arena.is_walkable(arena.cell_center(b.cell + Vector2i(0, 1))):
			wall = b
			break
	p.position = arena.cell_center(wall.cell + Vector2i(0, 1))
	await get_tree().physics_frame
	p.hm_id = "rock_smash"
	p.use_hm(Vector3(0, 0, -1))
	expect(wall.is_broken, "Rock Smash breaks the wall in front")
	p._hm_cooldown = 0.0
	# Fly: leaps across.
	p.hm_id = "fly"
	var before := p.global_position
	p.use_hm(Vector3(1, 0, 0))
	for i in 40:
		await get_tree().physics_frame
	expect(p.global_position.distance_to(before) > 3.0 and not p._flying_hm, "Fly leaps several tiles (%.1f m)" % p.global_position.distance_to(before))
	main.queue_free()
	await get_tree().process_frame
	await _check_hm_reworks()


## Each HM's core effect works on an open map with no water, boulders or walls nearby.
func _check_hm_reworks() -> void:
	var main := await _start_match("pallet_pitch", "duel", "squirtle", ["geodude"])
	await _freeze_all(main, main.enemy)
	var p: Brawler = main.player
	var t: Brawler = main.enemy
	var reset := func() -> void:
		p.global_position = main.arena.nearest_open(Vector3(0, 0, 3))
		t.global_position = main.arena.nearest_open(p.global_position + Vector3(0, 0, -1.8))
		t.health = t.max_health
		t._clear_status()
		t._debuffs.clear()
		t._cc_immune = 0.0
		t._was_controlled = false
		p._hm_cooldown = 0.0
	reset.call()
	await get_tree().physics_frame
	p.hm_id = "surf"
	p.use_hm(t.global_position - p.global_position)
	for i in 20:
		await get_tree().physics_frame
	expect(t.health < t.max_health and t._slow_time > 0.0, "Surf's wave hits and slows on a map without water")
	reset.call()
	await get_tree().physics_frame
	p.hm_id = "strength"
	var start := t.global_position
	p.use_hm(t.global_position - p.global_position)
	for i in 30:
		await get_tree().physics_frame
	expect(t.global_position.distance_to(start) > 2.5, "Strength throws the enemy (%.1f m)" % t.global_position.distance_to(start))
	reset.call()
	await get_tree().physics_frame
	p.hm_id = "rock_smash"
	var def := t.get_defense()
	p.use_hm(t.global_position - p.global_position)
	expect(t.get_defense() < def, "Rock Smash lowers Defense")
	reset.call()
	await get_tree().physics_frame
	p.hm_id = "cut"
	p.use_hm(t.global_position - p.global_position)
	expect(t._dot_kind == "bleed" and t._dot_time > 0.0, "Cut makes the target bleed")
	reset.call()
	await get_tree().physics_frame
	p.hm_id = "flash"
	var speed := p.get_speed()
	p.use_hm(Vector3.FORWARD)
	expect(p.get_speed() > speed and t.is_blind(), "Flash blinds and speeds you up")
	reset.call()
	t._blind_time = 0.0
	await get_tree().physics_frame
	p.hm_id = "fly"
	p.global_position = main.arena.nearest_open(t.global_position + Vector3(0, 0, 5.0))
	await get_tree().physics_frame
	p.use_hm(t.global_position - p.global_position)
	for i in 40:
		await get_tree().physics_frame
	expect(is_equal_approx(t.health, t.max_health) and t._slow_time > 0.0, "Fly's landing slows (no damage)")
	main.queue_free()
	await get_tree().process_frame


func _check_faint_stops_attacks() -> void:
	print("Fainting stops attacks")
	var main := await _start_match("route_1", "duel", "squirtle", [])
	await _freeze_all(main)
	var p: Brawler = main.player
	p.position = main.arena.cell_center(Vector2i(18, 30))
	await get_tree().physics_frame
	p.use_main(Vector3(0, 0, -1))
	await get_tree().physics_frame
	var count_shots := func() -> int:
		var n := 0
		for node in main.arena.get_children():
			if node is Projectile and not node.is_queued_for_deletion() and not node._done and node.shooter == p:
				n += 1
		return n
	var shots: int = count_shots.call()
	p.take_damage(p.health + 10.0)
	for i in 3:
		await get_tree().physics_frame
	var left: int = count_shots.call()
	expect(shots > 0 and left == 0, "shots in flight fizzle when you faint (%d fired, %d left)" % [shots, left])
	expect(not p.stream(Vector3.FORWARD), "can't stream while fainted")
	main.queue_free()
	await get_tree().process_frame


func _check_text_boxes() -> void:
	print("Text boxes in scroll lists")
	var menu := MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.show_account("")
	for i in 3:
		await get_tree().process_frame
	var scroll: DragScroll = null
	for node in menu.find_children("*", "DragScroll", true, false):
		scroll = node
	var first: LineEdit = null
	for node in menu.find_children("*", "LineEdit", true, false):
		first = node
		break
	expect(first != null, "the account screen has an email box")
	expect(scroll != null, "the account screen scrolls")
	if scroll and first:
		var at := first.get_global_rect().get_center()
		scroll._tap(at)
		expect(first.has_focus(), "tapping the email box in a scroll list focuses it")
	menu.queue_free()
	await get_tree().process_frame


func _check_tm_super_shapes() -> void:
	print("TM super shapes")
	var main := await _start_match("route_1", "duel", "charmander", [])
	var p: Brawler = main.player
	Profile._add_tm("tm_fire_blast")
	p.super_choices = { "charmander": "tmsuper_fire_blast" }
	var m := p.current_super()
	expect(m.kind == "area" and m.power < float(GameData.get_move("tmsuper_fire_blast_burst").power), "a stream Pokémon's Fire Blast is a close burst, weaker on a base form (%s, %d)" % [m.kind, m.power])
	main.queue_free()
	await get_tree().process_frame


func _check_ball_goals_and_walls() -> void:
	print("Brawl Ball goals and wall-breaking supers")
	expect(not GameData.get_move("fire_spin").breaks_walls and not GameData.get_move("aqua_ring").breaks_walls, "Fire Spin and Aqua Ring can't break walls")
	expect(GameData.get_move("flame_charge").breaks_walls and GameData.get_move("blast_burn").breaks_walls, "charges and big explosions can")
	var main := await _start_match("vermilion_gym", "brawl_ball", "machop", [])
	var arena: Arena = main.arena
	var blockers := 0
	for y in range(1, arena.height - 1):
		for x in range(1, arena.width - 1):
			if arena.rows[y][x] == "B" and "G" in [arena.rows[y - 1][x], arena.rows[y + 1][x], arena.rows[y][x - 1], arena.rows[y][x + 1]]:
				blockers += 1
	expect(blockers == 8, "rocks narrow both goals (2 each side, %d found)" % blockers)
	main.queue_free()
	await get_tree().process_frame


func _check_boss_raid() -> void:
	print("Boss Raid")
	GameData.match_settings = { "boss": "zapdos" }
	var wins_before := Profile.boss_wins("zapdos")
	var tier_before := Profile.boss_tier_index("zapdos")
	var main := await _start_match("vermilion_gym", "boss_raid", "pikachu", [])
	GameData.match_settings = {}
	var boss: Brawler = main.mode_logic.boss
	expect(main.teams[0].size() == 3 and main.teams[1].size() == 1, "3 of you vs. one boss")
	expect(boss.species.id == "zapdos" and boss.size_scale > 1.5, "the boss is a giant Zapdos")
	expect(boss.max_health > main.player.max_health * 8.0, "the boss has a huge health bar")
	boss.take_damage(boss.max_health * 0.4, main.player)
	for i in 3:
		await get_tree().physics_frame
	expect(main.mode_logic.phase == 2 and main.teams[1].size() == 3, "at 60% it enrages and calls 2 minions")
	main.player.global_position = Vector3.ZERO
	main.mode_logic._strike_at(Vector3.ZERO, 2.0)
	expect(main.mode_logic.escape_from(Vector3(0.5, 0, 0), main.teams[0][1]) != Vector3.ZERO, "bots know to leave the red circle")
	var hp: float = main.player.health
	main.player._protect_time = 0.0
	await get_tree().create_timer(1.6).timeout
	expect(main.player.health < hp, "the strike hits whoever stays in it")
	var lives: int = main.mode_logic.lives
	main.teams[0][1].take_damage(99999.0, boss)
	await get_tree().physics_frame
	expect(main.mode_logic.lives == lives - 1, "a faint uses a team life")
	boss.take_damage(boss.max_health, main.player)
	await get_tree().physics_frame
	expect(main.round_over, "KO the boss and you win")
	expect(Profile.boss_wins("zapdos") == wins_before + 1 and Profile.boss_tier_index("zapdos") == mini(tier_before + 1, 4), "each win moves the boss up a tier")
	var raid_challenge := { "type": "raid", "boss": "zapdos", "count": 3 }
	expect(Profile.challenge_progress(raid_challenge) == Profile.boss_wins("zapdos"), "raid challenges count Boss Raid wins")
	Profile.record_match({ "species": "pikachu", "result": "victory", "raid": "zapdos", "mode": "duel" })
	expect(Profile.challenge_progress(raid_challenge) == Profile.boss_wins("zapdos"), "a Battle-match raid doesn't count")
	main.queue_free()
	await get_tree().process_frame
	expect(Profile.boss_unlocked("moltres") and (Profile.is_dev() or not Profile.boss_unlocked("mewtwo")), "beating Zapdos opens Moltres, not Mewtwo")


func _check_dailies() -> void:
	print("Daily challenges")
	Profile.data["dailies"] = {}
	var tasks := Profile.dailies()
	expect(tasks.size() == 3, "three dailies a day")
	var stats: Array = []
	for t: Dictionary in tasks:
		expect(t["stat"] not in stats, "no two dailies track the same thing")
		stats.append(t["stat"])
	expect(Profile.reroll_daily(0) and not Profile.can_reroll_daily(), "one free reroll a day")
	var money := Profile.money()
	for t: Dictionary in tasks:
		Profile._daily_progress({ t["stat"]: 999 })
	var done := true
	for t: Dictionary in Profile.dailies():
		done = done and bool(t["done"])
	expect(done and bool(Profile.data["dailies"]["bonus"]), "finishing all three gives the bonus")
	expect(Profile.money() >= money, "rewards are paid")


func _check_gyms() -> void:
	print("Gym gauntlet")
	expect(Profile.gym_ids().size() == 8, "8 gyms")
	expect(Profile.gym_matchup("electric", "water") == "weak" and Profile.gym_matchup("electric", "ground") == "strong"
			and Profile.gym_matchup("fire", "fire") == "resisted" and Profile.gym_matchup("rock", "electric") == "neutral", "type matchups")
	var allies := GymMode.team_of_type("grass", "bulbasaur")
	expect(allies.size() == 2 and GameData.species[allies[0]].has_type("grass") and GameData.species[allies[1]].has_type("grass"), "a Grass team gets Grass teammates")
	expect(GymMode.team_of_type("dragon", "charmander").size() == 2, "rare types still fill the team")
	GameData.match_settings = GymMode.start_run("cinnabar_gym", "hard", "grass", { "species": "oddish" })
	var s1 := GameData.match_settings.duplicate()
	expect(s1["mode"] == "gym" and s1["arena"] == "cinnabar_gym" and s1["enemies"] == ["vulpix", "growlithe", "ponyta"], "round 1 is the first trainer")
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	await get_tree().physics_frame
	expect(main.mode == "gym" and main.mode_logic.ace == null, "no ace before the leader")
	for b: Brawler in main.teams[0]:
		expect(b.species.has_type("grass"), "%s is Grass" % b.species.display_name)
	main.player.gadget_uses = 1
	main.scores[0] = 14.0
	main.teams[1][0]._protect_time = 0.0
	main.teams[1][0].take_damage(999999.0, main.player)
	await get_tree().physics_frame
	expect(main.round_over and GameData.gym_run["round"] == 1 and GameData.gym_run["gadget_uses"] == 1, "winning round 1 moves on and keeps gadget uses")
	main.queue_free()
	await get_tree().process_frame
	GameData.gym_run["round"] = 2
	GameData.match_settings = GymMode.settings_for(GameData.gym_run)
	main = MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	await get_tree().physics_frame
	var ace: Brawler = main.mode_logic.ace
	expect(ace != null and ace.species.id == "arcanine" and ace.hp_scale >= 2.0, "the leader's ace is big and tough on Hard")
	expect(main.player.gadget_uses == 1, "gadget uses carried into the leader round")
	var clears := Profile.gym_clears("cinnabar_gym", "hard", "grass")
	var money := Profile.money()
	main.scores[0] = 13.0
	ace._protect_time = 0.0
	ace.take_damage(999999.0, main.player)
	await get_tree().physics_frame
	expect(main.round_over, "a KO on the ace counts 2 (13 + 2 = 15)")
	expect(Profile.gym_clears("cinnabar_gym", "hard", "grass") == clears + 1 and Profile.money() > money, "beating the leader records the clear and pays")
	expect(GameData.gym_run["round"] == 0, "the next run starts at round 1")
	main.queue_free()
	await get_tree().process_frame
	GameData.gym_run["round"] = 1
	GameData.match_settings = GymMode.settings_for(GameData.gym_run)
	main = MAIN_SCENE.instantiate()
	main.show_intro = false
	main.record_progress = false
	add_child(main)
	await get_tree().physics_frame
	main.scores[1] = 14.0
	main.player._protect_time = 0.0
	main.player.take_damage(999999.0, main.teams[1][0])
	await get_tree().physics_frame
	expect(main.round_over and GameData.gym_run["round"] == 0, "losing a round sends you back to round 1")
	main.queue_free()
	await get_tree().process_frame
	GameData.gym_run = {}
	GameData.match_settings = {}
	# Gyms open with enough Pokémon lines unlocked and the gym before beaten; the Elite Four after Giovanni with 50.
	var saved_dev := Profile.is_dev()
	var saved_unlocked: Array = (Profile.data["unlocked"] as Array).duplicate()
	var saved_gyms: Dictionary = Profile.data["gyms"].duplicate(true)
	Profile.data["dev"] = false
	Profile.data["gyms"] = {}
	Profile.data["unlocked"] = saved_unlocked.slice(0, 9)
	expect(not Profile.gym_unlocked("pewter_gym") and Profile.gym_lock_reason("pewter_gym").begins_with("Unlock 10"), "Brock needs 10 Pokémon")
	Profile.data["unlocked"] = saved_unlocked.slice(0, 14)
	expect(Profile.gym_unlocked("pewter_gym") and not Profile.gym_unlocked("cerulean_gym"), "10 opens Brock; Misty needs Brock beaten")
	Profile.gym_record("pewter_gym")["normal"] = 1
	expect(not Profile.gym_unlocked("cerulean_gym"), "Misty also needs 15 Pokémon")
	Profile.data["unlocked"] = saved_unlocked.slice(0, 15)
	expect(Profile.gym_unlocked("cerulean_gym"), "15 Pokémon + Brock opens Misty")
	for id: String in Profile.gym_ids():
		Profile.gym_record(id)["normal"] = 1
	Profile.data["unlocked"] = saved_unlocked.slice(0, 49)
	expect(not Profile.gym_unlocked("elite_four"), "the Elite Four needs 50 Pokémon")
	Profile.data["unlocked"] = saved_unlocked.slice(0, 50)
	expect(Profile.gym_unlocked("elite_four"), "all 8 gyms + 50 Pokémon opens the Elite Four")
	Profile.data["starter"] = "charmander"
	var e4 := GymMode.settings_for({ "gym": "elite_four", "round": 4, "team_type": "", "difficulty": "normal", "picks": {} })
	expect(e4["arena"] == "dragons_den" and e4["enemies"][0] == "blastoise", "Blue's ace counters your starter")
	expect(GymMode.has_ace(Profile.gym("elite_four")["rounds"], 0), "every Elite Four round has an ace")
	Profile.data["dev"] = saved_dev
	Profile.data["unlocked"] = saved_unlocked
	Profile.data["gyms"] = saved_gyms
	# Boss Raid at Master: one Great Ball a day, nothing after.
	var tiers := Profile.boss_tiers().size()
	Profile._stat_dict("boss_wins")["moltres"] = tiers + 3
	(Profile.data["daily"] as Dictionary).erase("boss_master")
	var first := Profile.record_match({ "species": "charmander", "result": "victory", "boss": "moltres", "mode": "boss_raid" })
	var second := Profile.record_match({ "species": "charmander", "result": "victory", "boss": "moltres", "mode": "boss_raid" })
	expect("great_ball" in first["balls"], "first Master win of the day: a Great Ball")
	expect(int(second["money"]) < int(first["money"]), "later Master wins that day skip the boss bonus")


func _check_starter_order() -> void:
	print("Starter unlock order")
	var saved: Dictionary = Profile.data.duplicate(true)
	Profile.data = Profile.blank()
	Profile.choose_starter("charmander")
	var order := Profile.starter_order()
	expect(order.size() == 3 and order[2] == "pikachu" and "bulbasaur" in order and "squirtle" in order, "Pikachu at 60, the others random (%s)" % ", ".join(PackedStringArray(order)))
	var road := Profile.road().filter(func(st: Dictionary) -> bool: return st["area"] == "Starter")
	expect(str(road[0]["family"]) == "" and str(road[2]["family"]) == "pikachu", "random starters stay a surprise on the road")
	Profile._add_xp("charmander", 999999)
	Profile.data["levels"]["pidgey"] = 10
	Profile._check_unlocks()
	expect(Profile.is_unlocked(str(order[0])) and str(Profile.road().filter(func(st: Dictionary) -> bool: return st["area"] == "Starter")[0]["family"]) == str(order[0]), "the level 20 starter shows once unlocked")
	Profile.data = Profile.blank()
	Profile.choose_starter("pikachu")
	order = Profile.starter_order()
	expect(order.size() == 3 and "pikachu" not in order, "picked Pikachu: all three starters random")
	Profile.data = saved


func _check_no_mew_bots() -> void:
	print("Mewtwo and Mew are never random bots")
	var main := MAIN_SCENE.instantiate()
	var seen := false
	for i in 200:
		for id in main._fill_team(PackedStringArray(), 5, []):
			if GameData.family_root(id) in ["mewtwo", "mew"]:
				seen = true
	main.free()
	expect(not seen, "no Mewtwo or Mew in 1000 random bots")
	expect(not GameData.bot_allowed("mew") and GameData.bot_allowed("pikachu"), "bot_allowed")


func _check_mvp() -> void:
	print("MVP")
	var main := await _start_match("route_1", "duel", "charmander", [])
	var all: Array[Brawler] = []
	for t: int in main.teams:
		for b: Brawler in main.teams[t]:
			b.kills = 1
			b.deaths = 3
			b.damage_dealt = 8000.0
			all.append(b)
	all[0].kills = 8
	all[0].deaths = 2
	all[0].damage_dealt = 20000.0
	all[1].kills = 2
	all[1].deaths = 5
	all[1].damage_dealt = 32000.0
	var rows: Array[Dictionary] = main.summary_rows()
	var mvp: Brawler = null
	for r in rows:
		if r["mvp"]:
			mvp = r["brawler"]
	expect(mvp == all[0], "KOs and KO ratio beat raw damage for MVP")
	main.queue_free()
	await get_tree().process_frame
	main = await _start_match("pallet_pitch", "brawl_ball", "charmander", [])
	all.clear()
	for t: int in main.teams:
		for b: Brawler in main.teams[t]:
			b.kills = 3
			b.deaths = 3
			b.damage_dealt = 15000.0
			all.append(b)
	all[2].goals = 2
	all[2].kills = 2
	rows = main.summary_rows()
	for r in rows:
		if r["mvp"]:
			mvp = r["brawler"]
	expect(mvp == all[2], "Brawl Ball goals count for MVP")
	main.queue_free()
	await get_tree().process_frame


func _check_boss_no_heal() -> void:
	print("Battle legendaries never heal")
	var main := await _start_match("route_1", "duel", "charmander", [])
	var boss: Brawler = main.spawn_raid_boss()
	await get_tree().physics_frame
	boss._protect_time = 0.0
	boss.take_damage(boss.max_health * 0.5, main.player)
	var hp := boss.health
	boss.heal(boss.max_health * 0.3, boss)
	boss._regen_timer = 10.0
	await get_tree().create_timer(0.5).timeout
	expect(is_equal_approx(boss.health, hp), "the raid boss doesn't heal or regenerate (%d → %d)" % [hp, boss.health])
	var ally: Brawler = main.summon_legendary("zapdos", 0, Vector3.ZERO)
	await get_tree().physics_frame
	ally.take_damage(ally.max_health * 0.4, main.enemy)
	hp = ally.health
	ally.use_gadget(Vector3.FORWARD)
	await get_tree().create_timer(0.3).timeout
	expect(is_equal_approx(ally.health, hp), "a legendary ally's Sitrus Berry doesn't heal it")
	expect(is_equal_approx(float(GameData.rule("legendary/ally_duration", 0)), 20.0), "legendary allies stay 20 s")
	main.queue_free()
	await get_tree().process_frame


func _check_slam_windup() -> void:
	print("Telegraphed slam")
	var setup := await _duel_setup("route_1", "snorlax")
	var main: Node = setup[0]
	var snorlax: Brawler = setup[1]
	var target: Brawler = setup[2]
	snorlax.position = Vector3(0, 0, 4)
	_reset_target(target, Vector3(0, 0, 2))
	await get_tree().physics_frame
	snorlax.super_charge = 1.0
	snorlax.use_super(Vector3.FORWARD)
	await get_tree().create_timer(0.3, false, true).timeout
	expect(target.health >= target.max_health and snorlax.get_speed() == 0.0, "the slam waits, planted, before landing")
	expect(snorlax.windup_threatens(target.global_position) and not snorlax.windup_threatens(Vector3(4, 0, 4)), "bots can tell if they're in the cone")
	await get_tree().create_timer(0.5, false, true).timeout
	expect(target.health < target.max_health, "then it lands")
	main.queue_free()
	await get_tree().process_frame


func _check_assassin_charge() -> void:
	print("Assassin super charge")
	var main := MAIN_SCENE.instantiate()
	var b: Brawler = preload("res://scenes/brawler.tscn").instantiate()
	b.setup("scyther", 20, 0, false, null)
	b.super_charge = 0.0
	for i in 3:
		b.add_super_charge(800.0)
	var after_three := b.super_charge
	b.add_super_charge(800.0)
	expect(after_three < 1.0 and b.super_charge >= 1.0, "Scyther's super takes 4 hits (%.2f after 3)" % after_three)
	expect(GameData.get_move("scyther_main1").dash_distance <= 3.3, "shorter Assassin jumps")
	b.free()
	main.free()


func _check_camera_lead() -> void:
	print("Camera lead")
	var cam := FollowCamera.new()
	var dummy := Node3D.new()
	add_child(dummy)
	add_child(cam)
	cam.target = dummy
	cam.follow_limits = Rect2(-100, -100, 200, 200)
	cam.field_half = 22.0
	dummy.global_position = Vector3(0, 0, 10)
	var own: Vector3 = cam._desired_position()
	dummy.global_position = Vector3(0, 0, -20)
	var enemy: Vector3 = cam._desired_position()
	var pitch := deg_to_rad(cam.pitch_degrees)
	var own_focus := own.z - cos(pitch) * cam.distance - 10.0
	var enemy_focus := enemy.z - cos(pitch) * cam.distance + 20.0
	expect(own_focus < 0.0 and enemy_focus > 0.0, "the camera looks ahead in your half and back toward your side in theirs (%.1f, %.1f)" % [own_focus, enemy_focus])
	cam.queue_free()
	dummy.queue_free()


func _check_move_looks() -> void:
	print("Move looks and extras")
	var missing: Array[String] = []
	for move: MoveData in GameData.moves.values():
		var shape := str(MoveLook.of(move).get("shape", "dot"))
		if shape != "dot" and not ResourceLoader.exists("res://assets/fx/%s.png" % shape):
			missing.append("%s (%s)" % [move.display_name, shape])
	expect(missing.is_empty(), "every move's look has a baked shape (missing: %s)" % ", ".join(missing))
	var extras: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/move_extras.json"))
	var names := {}
	for move: MoveData in GameData.moves.values():
		names[move.display_name] = true
	var unknown: Array[String] = []
	for key: String in extras:
		if not key.begins_with("_") and not names.has(key):
			unknown.append(key)
	expect(unknown.is_empty(), "move_extras.json only names real moves (unknown: %s)" % ", ".join(unknown))
	expect(str(GameData.get_move("tangela_super").control.get("type", "")) == "grab", "Vine Snare is a grab")
	expect(str(GameData.get_move("hydro_cannon").control.get("type", "")) == "torrent", "Hydro Cannon is a torrent")
	expect(not GameData.get_move("tmsuper_rock_tomb_shot").stat_change.is_empty(), "Rock Tomb lowers Speed")


func _check_controls() -> void:
	print("Grabs, tombs, torrents, vortexes, stat drops")
	var main := await _start_match("pallet_pitch", "duel", "tangela", ["geodude"])
	await _freeze_all(main, main.enemy)
	var player: Brawler = main.player
	var target: Brawler = main.enemy
	player.global_position = main.arena.nearest_open(Vector3(0, 0, 2))
	target.global_position = player.global_position + Vector3(0, 0, -2.5)
	await get_tree().physics_frame

	# Stat drops: Defense down makes hits land harder, and shows a down arrow.
	var def_before := target.get_defense()
	target.apply_stat_change({ "defense": -0.3, "duration": 3.0 })
	expect(target.get_defense() < def_before, "Defense drops lower defense")
	var arrow := 0
	for chip: Dictionary in target.status_chips():
		if chip["text"] == "DEF":
			arrow = int(chip["arrow"])
	expect(arrow == -1, "a lowered stat shows a down arrow")
	target._debuffs.clear()

	# Grab: both are held, the target can't attack, and it lets go after the hold.
	var grab := GameData.get_move("tangela_super")
	player._perform(grab, Vector3(0, 0, -1), -1.0)
	await get_tree().physics_frame
	expect(player.is_holding() and target.is_grabbed(), "Vine Snare grabs the target")
	expect(not target.can_shoot(), "a grabbed Pokémon can't attack")
	var hp := target.health
	for i in 30:
		await get_tree().physics_frame
	expect(target.health < hp, "the grab squeezes for damage")
	for i in 90:
		await get_tree().physics_frame
	expect(not target.is_grabbed() and not player.is_holding(), "the grab ends on its own")
	# Hitting the grabber hard frees its victim.
	target.health = target.max_health
	player._grab_target = null
	target._grabbed_by = null
	player._perform(grab, Vector3(0, 0, -1), -1.0)
	await get_tree().physics_frame
	player.take_damage(player.max_health * 0.2, target)
	expect(not target.is_grabbed(), "damaging the grabber breaks the grab")

	# Tomb: rocks ring the target.
	for i in 20:
		await get_tree().physics_frame
	target.entomb("rock", 2.5)
	await get_tree().physics_frame
	var rocks := 0
	for n in main.arena.get_children():
		if n is TombRock:
			rocks += 1
	expect(rocks >= 4, "Rock Tomb drops a ring of rocks (%d)" % rocks)

	# Torrent: swept into something solid, the target is pinned (stunned).
	target._stun_time = 0.0
	var wall_dir := Vector3.ZERO
	for d: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		if player.clear_distance(d, 30.0) < 29.0:
			wall_dir = d
			break
	target.global_position = player.global_position
	target._tomb_time = 0.0
	target._was_controlled = false
	target._cc_immune = 0.0  # Still immune from the grab above.
	target.carry(wall_dir, 40.0, 1.0, 0.2, player, GameData.get_move("hydro_cannon"))
	for i in 240:
		await get_tree().physics_frame
		if target.is_stunned():
			break
	expect(target.is_stunned(), "a torrent pins its target against a wall")

	# Vortex: drags enemies toward its centre.
	target._stun_time = 0.0
	for n in main.arena.get_children():
		if n is TombRock:
			n.queue_free()
	await get_tree().physics_frame
	target.global_position = main.arena.nearest_open(Vector3(0, 0, -2))
	var centre := target.global_position + Vector3(2.0, 0, 0)
	player.spawn_vortex(GameData.get_move("fire_spin"), centre, 2.6)
	var start := target.global_position.distance_to(centre)
	for i in 40:
		await get_tree().physics_frame
	expect(target.global_position.distance_to(centre) < start - 0.3, "Fire Spin's vortex pulls enemies in")
	main.queue_free()
	await get_tree().physics_frame


func _check_kit_data() -> void:
	print("Kits: gadgets, Abilities, Z-Moves")
	var missing: Array[String] = []
	for s: SpeciesData in GameData.base_species():
		var kit := GameData.kit(s.id)
		var gadgets: Array = kit.get("gadgets", [])
		var abilities: Array = kit.get("abilities", [])
		var ok := gadgets.size() == 2 and abilities.size() == 2
		for g in gadgets:
			var m := GameData.get_move(str(g))
			ok = ok and m != null and m.slot == "gadget"
		for a in abilities:
			ok = ok and GameData.abilities.has(str(a))
		if not ok:
			missing.append(s.id)
	expect(missing.is_empty(), "every line has two gadgets and two Abilities (bad: %s)" % ", ".join(missing))
	var z := GameData.z_move(GameData.get_species("charizard").super_move)
	expect(z.display_name == "Inferno Overdrive" and z.power > GameData.get_species("charizard").super_move.power, "Charizard's Z-Move is a stronger Inferno Overdrive")
	var old_dev: Variant = Profile.data.get("dev", false)
	Profile.data["dev"] = false
	var old_level := Profile.level_of("charmander")
	Profile.set_level("charmander", 1)
	expect(Profile.gadget_options("charmander").size() == 1 and Profile.ability_options("charmander").is_empty() and not Profile.zmove_unlocked("charmander"),
			"a level 1 line has only its default gadget")
	Profile.set_level("charmander", 30)
	expect(Profile.gadget_options("charmander").size() == 3 and Profile.ability_options("charmander").size() == 1 and not Profile.zmove_unlocked("charmander"),
			"level 30: both signature gadgets and the first Ability")
	Profile.set_level("charmander", 50)
	expect(Profile.ability_options("charmander").size() == 2 and Profile.zmove_unlocked("charmander"), "level 50: both Abilities and the Z-Move")
	expect(Profile.chosen_gadget("charmander") == "gadget_ember_charge", "the first signature gadget is picked by default once unlocked")
	Profile.set_level("charmander", old_level)
	Profile.data["dev"] = old_dev


func _check_kits_in_match() -> void:
	print("Kits in a match")
	var main := await _start_match("pallet_pitch", "duel", "charizard", ["geodude"])
	await _freeze_all(main, main.enemy)
	var p: Brawler = main.player
	var t: Brawler = main.enemy
	p.global_position = main.arena.nearest_open(Vector3(0, 0, 3))
	t.global_position = main.arena.nearest_open(p.global_position + Vector3(0, 0, -2.5))
	t.max_health = 50000.0
	t.health = t.max_health
	p.set_build("", "", false)
	t.set_build("", "", false)
	await get_tree().physics_frame

	# Crowd-control immunity: after a stun ends, another can't land right away.
	t._apply_effect({ "type": "stun", "duration": 0.3 }, p, "normal")
	for i in 30:
		await get_tree().physics_frame
	t._apply_effect({ "type": "stun", "duration": 1.0 }, p, "normal")
	expect(not t.is_stunned() and t.cc_immune(), "a second stun right after the first is blocked (immunity)")
	expect(not t.can_be_grabbed(), "immune Pokémon can't be grabbed")
	for i in 100:
		await get_tree().physics_frame
	t._apply_effect({ "type": "stun", "duration": 0.2 }, p, "normal")
	expect(t.is_stunned(), "stuns land again once immunity wears off")
	for i in 120:
		await get_tree().physics_frame

	# Abilities.
	t.set_build("", "sturdy", false)
	t.health = t.max_health * 0.5
	t.take_damage(t.max_health, p)
	expect(not t.is_dead and is_equal_approx(t.health, 1.0), "Sturdy survives a knockout hit with 1 HP")
	t._sturdy_used = false
	t.health = t.max_health * 0.1
	t.take_damage(t.max_health, p)
	expect(t.is_dead, "Sturdy doesn't save you from low health")
	t.respawn(main.arena.nearest_open(p.global_position + Vector3(0, 0, -2.5)))
	t._protect_time = 0.0
	t.max_health = 50000.0
	t.health = t.max_health
	var fire := GameData.get_move("charmander_main1")
	t.set_build("", "", false)
	var plain: float = GameData.calc_damage(fire, p, t, t.incoming_mult(fire))["amount"]
	t.set_build("", "thick_fat", false)
	var fat: float = GameData.calc_damage(fire, p, t, t.incoming_mult(fire))["amount"]
	expect(fat < plain * 0.8, "Thick Fat cuts Fire damage (%d vs %d)" % [fat, plain])
	t.set_build("", "", false)
	p.set_build("", "intimidate", false)
	var atk := t.get_attack()
	p._intimidate()
	expect(t.get_attack() < atk, "Intimidate lowers nearby enemies' Attack")
	t._debuffs.clear()
	p.set_build("", "", false)

	# Gadgets.
	p.set_build("gadget_quick_claw", "", false)
	p.ammo = 0.0
	expect(p.use_gadget(Vector3.FORWARD) and p.ammo >= p.max_ammo(), "Quick Claw refills ammo")
	p._gadget_timer = 0.0
	p.set_build("gadget_ember_charge", "", false)
	p.use_gadget(Vector3.FORWARD)
	t._clear_status()
	t.take_hit(p, p.main_move)
	expect(t._dot_kind == "burn" and t._dot_time > 0.0, "Ember Charge makes attacks burn")
	p._gadget_timer = 0.0
	t._clear_status()
	p.set_build("gadget_detect", "", false)
	p.use_gadget(Vector3.FORWARD)
	var t_pos := t.global_position
	p.take_hit(t, t.main_move)
	for i in 15:
		await get_tree().physics_frame
	expect(t.global_position.distance_to(t_pos) > 0.8, "Detect knocks back whoever hits you")
	p._protect_time = 0.0
	p._gadget_timer = 0.0
	p.gadget_uses = 3
	p.set_build("gadget_stealth_rock", "", false)
	t.global_position = main.arena.nearest_open(Vector3(4, 0, 3))
	var hp := t.health
	p.use_gadget(Vector3.FORWARD)
	for i in 45:
		await get_tree().physics_frame
	t.global_position = p.global_position
	for i in 5:
		await get_tree().physics_frame
	expect(t.health < hp, "Stealth Rock springs on an enemy that steps on it")
	t.global_position = main.arena.nearest_open(p.global_position + Vector3(0, 0, -2.5))
	await get_tree().physics_frame

	# Z-Move.
	p.set_build("", "", true)
	p.z_charge = 1.0
	p.super_charge = 1.0
	p._attack_lock = 0.0
	var super_power := p.current_super().power
	t.health = t.max_health
	expect(p.use_zmove(t.global_position - p.global_position, 2.5), "a charged Z-Move fires")
	expect(p._z_time > 0.0 and p.z_charge == 0.0 and p.super_charge == 0.0, "the Z-Move uses both meters and starts the boost")
	expect(GameData.z_move(p.current_super()).power > super_power, "the Z-Move hits harder than the super")
	var other: Brawler = main._spawn("charmander", 50, 0, false)
	other.set_build("", "", true)
	other.z_charge = 1.0
	other.super_charge = 1.0
	expect(not other.zmove_ready(), "base forms can't use Z-Moves")
	main.queue_free()
	await get_tree().physics_frame

