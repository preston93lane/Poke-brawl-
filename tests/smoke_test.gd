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
	await _check_king_of_the_hill()
	await _check_menu()
	await _check_menu_settings()
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
	expect(GameData.species.size() >= 29, "species loaded (%d)" % GameData.species.size())
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
		for level in range(1, 4):
			if s.default_move("melee", level) == null or s.default_move("ranged", level) == null:
				expect(false, "%s has melee + ranged moves at level %d" % [s.id, level])
	expect(supers.size() == GameData.species.size(), "every Pokémon has its own super")
	expect(GameData.get_species("dragonite").stage == 3 and GameData.get_species("alakazam").stage == 3, "new lines are 3 stages")
	for arena_id: String in GameData.arenas:
		var rows: Array = GameData.arenas[arena_id]["map"]
		expect(rows.size() >= 40 and str(rows[0]).length() >= 30, "%s is large (%dx%d)" % [arena_id, str(rows[0]).length(), rows.size()])


func _start_match(arena_id: String, mode: String, player_species: String, enemies: PackedStringArray) -> Node:
	var main := MAIN_SCENE.instantiate()
	main.arena_id = arena_id
	main.mode = mode
	main.player_species = player_species
	main.enemy_team = enemies
	add_child(main)
	await get_tree().physics_frame
	return main


func _check_battle() -> void:
	print("Battle 3v3")
	var main := await _start_match("route_1", "duel", "charmander", ["bulbasaur"])
	var player: Brawler = main.player
	var enemy: Brawler = main.enemy
	expect(main.teams[0].size() == 3 and main.teams[1].size() == 3, "teams are 3v3")
	expect(enemy.species.id == "bulbasaur", "chosen opponent spawned first")
	expect(player.melee_move.id == "scratch" and player.ranged_move.id == "ember", "level 1 charmander has scratch + ember")

	var before := enemy.health
	enemy.take_hit(player, GameData.get_move("ember"))
	var dealt := before - enemy.health
	var expected := GameData.get_move("ember").power * player.attack / enemy.defense * 1.2 * 1.5 * float(GameData.rule("damage_scale", 1.0))
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
	for s: SpeciesData in GameData.species.values():
		var b: Brawler = main._spawn(s.id, 1, 0, false)
		b.position = target.position + Vector3(0, 0, 2.5)
		await get_tree().physics_frame
		target.respawn(target.position)
		# A huge HP pool: a KO would trigger the match's delayed respawn, which would
		# reset the target's health in the middle of the next Pokémon's check.
		target.max_health = 100000.0
		target.health = target.max_health
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
	var shooter: Brawler = main._spawn("squirtle", 3, 0, false)
	shooter.position = arena.cell_center(Vector2i(17, 9))
	target.position = arena.cell_center(Vector2i(17, 6))
	await get_tree().physics_frame
	await get_tree().physics_frame
	Engine.time_scale = 1.0
	shooter.use_ranged(Vector3.FORWARD)  # Hydro Pump at level 3 is a stream: hold it.
	for i in 30:
		shooter.stream(Vector3.FORWARD)
		await get_tree().physics_frame
	shooter.use_melee(Vector3.FORWARD)
	await get_tree().create_timer(0.6, false, true).timeout
	expect(is_equal_approx(target.health, target.max_health), "attacks don't pass through walls (target hp %d/%d)" % [target.health, target.max_health])

	var fast := MoveData.from_dict("test_bolt", { "type": "electric", "slot": "ranged", "kind": "projectile", "power": 500, "speed": 80, "range": 8 })
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
	expect(menu._arena in GameData.arenas_for_mode("king_of_the_hill"), "king of the hill only offers arenas with a zone")
	menu.show_pokedex("alakazam")
	await get_tree().process_frame
	expect(menu._details.get_child_count() > 8, "pokédex shows an entry")
	menu.show_home()
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame


func _check_menu_settings() -> void:
	print("Menu settings")
	GameData.match_settings = {
		"mode": "king_of_the_hill", "arena": "route_1", "species": "squirtle", "level": 2,
		"melee": "tackle", "ranged": "bubble_beam", "allies": ["abra"], "enemies": ["dratini", "pikachu"], "bot_level": 2,
	}
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().physics_frame
	expect(main.mode == "king_of_the_hill" and main.arena.has_zone(), "route 1 has a zone in king of the hill")
	expect(main.player.species.id == "squirtle" and main.player.level == 2, "menu choice of pokémon and level applied")
	expect(main.player.melee_move.id == "tackle" and main.player.ranged_move.id == "bubble_beam", "menu loadout applied")
	expect(main.teams[0][1].species.id == "abra", "chosen teammate applied")
	expect(main.teams[1][0].species.id == "dratini" and main.teams[1][1].species.id == "pikachu", "chosen opponents applied")
	expect(main.teams[1].size() == 3, "empty slots filled randomly")
	GameData.match_settings = {}
	main.queue_free()
	await get_tree().process_frame
