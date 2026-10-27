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
	Engine.time_scale = 1.0
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
	expect(is_equal_approx(GameData.get_species("charmander").hp, 3100.0 * float(GameData.rule("hp_multiplier", 1.0))), "hp_multiplier raises health")
	expect(ThemeDB.fallback_font.resource_path.ends_with("lilita-one.woff"), "game font installed")
	for line_base in ["geodude", "bellsprout", "gastly", "mankey"]:
		expect(GameData.evolution_line(line_base).size() == 3, "%s line has 3 stages" % line_base)
	expect(GameData.arenas.size() >= 3, "arenas loaded (%d)" % GameData.arenas.size())
	var grass: Array[String] = ["grass"]
	var ground: Array[String] = ["ground"]
	var grass_poison: Array[String] = ["grass", "poison"]
	expect(is_equal_approx(GameData.effectiveness("fire", grass), 1.5), "fire is super effective on grass")
	expect(is_equal_approx(GameData.effectiveness("electric", ground), 0.4), "electric is resisted hard by ground")
	expect(is_equal_approx(GameData.effectiveness("grass", grass_poison), 0.67 * 0.67), "dual types multiply")
	var supers := {}
	for s: SpeciesData in GameData.species.values():
		expect(s.sprite != null and s.super_move != null, "%s has a sprite and super (%s)" % [s.id, s.super_move.id if s.super_move else "none"])
		supers[s.super_move] = true
		if s.moves_for("main", 1).size() != 1 or s.moves_for("main", 3).size() != 3:
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
	var expected := ember.power * player.attack / enemy.defense * 1.2 * 1.5 * float(GameData.rule("damage_scale", 1.0))
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
	expect(GameData.arenas_for_mode("brawl_ball") == ["pallet_pitch"], "only goal arenas offer Brawl Ball")
	expect("viridian_forest" in GameData.arenas_for_mode("showdown") and "viridian_forest" not in GameData.arenas_for_mode("duel"), "Viridian Forest is Showdown-only")
	for mode_id in ["brawl_ball", "candy_rush", "showdown"]:
		menu.show_select(mode_id)
		await get_tree().process_frame
	expect(menu._arena in GameData.arenas_for_mode("king_of_the_hill"), "king of the hill only offers arenas with a zone")
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
	var shiny_bot: Brawler = main._spawn("charizard", 1, 1, false)
	shiny_bot.shiny = true
	shiny_bot._apply_species()
	expect(shiny_bot.sprite.texture == shiny_bot.species.shiny_sheet, "shiny Pokémon use the shiny sheet")
	shiny_bot.queue_free()
	for case: Array in [[Vector3(1, 0, 0), 1, false], [Vector3(-1, 0, 0), 1, true], [Vector3(0, 0, -1), 2, false], [Vector3(0, 0, 1), 0, false]]:
		player.facing = case[0]
		await get_tree().process_frame
		await get_tree().process_frame
		expect(player.sprite.frame == case[1] and player.sprite.flip_h == case[2], "facing %s shows view %d (flipped=%s)" % case)

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
			ally.take_damage(800.0, enemy)
			expect(is_equal_approx(ally.health, ally_hp) and ally.flying, "the legendary ally can't be hurt and flies")
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

	# Lob: Seed Bomb arcs over the rock wall (row 8) and lands on the target behind it.
	shooter.position = arena.cell_center(Vector2i(17, 10))
	_reset_target(target, arena.cell_center(Vector2i(17, 6)))
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
	await get_tree().create_timer(0.6, false, true).timeout
	expect(target.health < target.max_health and second.health < second.max_health, "chain lightning hits a second enemy")
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

	# Homing: aimed 30° off, Shadow Orbs curve into the target.
	_reset_target(target, base + forward * 5.0)
	await get_tree().physics_frame
	shooter._perform(GameData.get_move("gastly_main1"), forward.rotated(Vector3.UP, deg_to_rad(30)), -1.0)
	await get_tree().create_timer(1.0, false, true).timeout
	expect(target.health < target.max_health, "homing shots curve into targets")

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
	shooter.position = arena.cell_center(Vector2i(2, 30))
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

	# Dragon's Den: the one-tile gap between the pond (11,19) and the boulder (13,20).
	player.position = arena.cell_center(Vector2i(12, 17))
	await get_tree().physics_frame
	player.move_input = Vector2(0, 1)
	await get_tree().create_timer(1.6, false, true).timeout
	player.move_input = Vector2.ZERO
	expect(arena.world_to_cell(player.global_position).y >= 21, "walkers fit through the gap between the water and the boulder (reached row %d)" % arena.world_to_cell(player.global_position).y)

	# Walkers stop at water; Water and Flying types go across it.
	player.position = arena.cell_center(Vector2i(7, 18))
	await get_tree().physics_frame
	player.move_input = Vector2(1, 0)
	await get_tree().create_timer(1.0, false, true).timeout
	player.move_input = Vector2.ZERO
	expect(not arena.is_water(player.global_position) and not player.can_swim, "charmander can't walk into water")
	for swimmer_id in ["squirtle", "pidgey"]:
		var swimmer: Brawler = main._spawn(swimmer_id, 1, 0, false)
		swimmer.position = arena.cell_center(Vector2i(7, 18))
		await get_tree().physics_frame
		swimmer.move_input = Vector2(1, 0)
		await get_tree().create_timer(0.7, false, true).timeout
		swimmer.move_input = Vector2.ZERO
		expect(swimmer.can_swim and arena.is_water(swimmer.global_position), "%s walks out onto the water" % swimmer_id)
		swimmer.queue_free()
	var swim_path: PackedVector3Array = arena.find_path(arena.cell_center(Vector2i(7, 18)), arena.cell_center(Vector2i(12, 18)), true)
	var walk_path: PackedVector3Array = arena.find_path(arena.cell_center(Vector2i(7, 18)), arena.cell_center(Vector2i(12, 18)))
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
	expect(wall.take_attack(player, player.species.super_move), "supers smash breakable walls")
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
		main.queue_free()
		await get_tree().process_frame
