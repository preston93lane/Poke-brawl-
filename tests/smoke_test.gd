extends Node
## Headless smoke test: validates data, damage maths and evolution, then plays
## a Duel and a King of the Hill match with every brawler's level-3 moves.
## Run: godot --headless --path . res://tests/smoke_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MENU_SCENE := preload("res://scenes/menu.tscn")

var failures := 0


func _ready() -> void:
	await get_tree().process_frame
	_check_data()
	await _check_duel()
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
	expect(GameData.species.size() >= 11, "species loaded (%d)" % GameData.species.size())
	expect(GameData.moves.size() >= 20, "moves loaded (%d)" % GameData.moves.size())
	expect(GameData.arenas.has("route_1") and GameData.arenas.has("boulder_gym"), "arenas loaded")
	var grass: Array[String] = ["grass"]
	var ground: Array[String] = ["ground"]
	var grass_poison: Array[String] = ["grass", "poison"]
	expect(is_equal_approx(GameData.effectiveness("fire", grass), 1.5), "fire is super effective on grass")
	expect(is_equal_approx(GameData.effectiveness("electric", ground), 0.4), "electric is resisted hard by ground")
	expect(is_equal_approx(GameData.effectiveness("grass", grass_poison), 0.67 * 0.67), "dual types multiply")
	for s: SpeciesData in GameData.species.values():
		expect(s.sprite != null, "%s has a sprite" % s.id)
		for level in range(1, 4):
			expect(s.default_move("melee", level) != null and s.default_move("ranged", level) != null,
					"%s has melee + ranged moves at level %d" % [s.id, level])
	expect(GameData.get_species("charizard").stage == 3, "charizard is stage 3")
	expect(GameData.get_species("charizard").learnset.size() == 6, "evolutions inherit the learnset")


func _start_match(arena_id: String, mode: String, player_species: String, enemy_species: String) -> Node:
	var main := MAIN_SCENE.instantiate()
	main.arena_id = arena_id
	main.mode = mode
	main.player_species = player_species
	main.enemy_species = enemy_species
	add_child(main)
	await get_tree().physics_frame
	return main


func _check_duel() -> void:
	print("Duel")
	var main := await _start_match("route_1", "duel", "charmander", "bulbasaur")
	var player: Brawler = main.player
	var enemy: Brawler = main.enemy
	expect(player.melee_move.id == "scratch" and player.ranged_move.id == "ember", "level 1 charmander has scratch + ember")
	expect(main.arena.is_tall_grass(Vector3(-7.5, 0, -13.5)), "tall grass tile detected")

	var before := enemy.health
	enemy.take_hit(player, GameData.get_move("ember"))
	var dealt := before - enemy.health
	var expected := 600.0 * player.attack / enemy.defense * 1.2 * 1.5 * float(GameData.rule("damage_scale", 1.0))
	expect(dealt > expected * 0.99, "ember on bulbasaur gets STAB + super effective (%d)" % dealt)

	player.register_kill()
	player.register_kill()
	player.respawn(main.arena.spawns[0])
	expect(player.evolve_kills == 2, "KOs toward evolving are kept after fainting")
	player.register_kill()
	expect(player.species.id == "charmeleon", "3 total KOs evolve charmander into charmeleon")
	expect(player.evolve_kills == 0, "evolving resets the KO count")
	player.respawn(main.arena.spawns[0])
	expect(player.species.id == "charmander", "fainting devolves one stage")

	# Every base form at level 3 fires both moves at the bot.
	for species_id in ["charmander", "squirtle", "bulbasaur", "pikachu"]:
		var b: Brawler = main._spawn(species_id, 3, 0, false)
		b.position = enemy.position + Vector3(0, 0, 3)
		await get_tree().physics_frame
		expect(b.use_ranged(Vector3.FORWARD), "%s fires %s" % [species_id, b.ranged_move.id])
		expect(not b.use_ranged(Vector3.FORWARD), "%s can't fire again during the attack delay" % species_id)
		await get_tree().create_timer(b.ranged_move.attack_delay() + 0.1, false, true).timeout
		expect(b.use_melee(Vector3.FORWARD), "%s uses %s after the delay" % [species_id, b.melee_move.id])

	Engine.time_scale = 4.0
	await get_tree().create_timer(6.0).timeout
	Engine.time_scale = 1.0
	expect(is_instance_valid(player) and is_instance_valid(enemy), "match ran for 24 game-seconds")
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
	menu.show_pokedex("charizard")
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
		"melee": "tackle", "ranged": "bubble_beam", "enemy": "random", "enemy_level": 2,
	}
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().physics_frame
	expect(main.mode == "king_of_the_hill" and main.arena.has_zone(), "route 1 has a zone in king of the hill")
	expect(main.player.species.id == "squirtle" and main.player.level == 2, "menu choice of pokémon and level applied")
	expect(main.player.melee_move.id == "tackle" and main.player.ranged_move.id == "bubble_beam", "menu loadout applied")
	expect(main.enemy_species != "random", "random opponent resolved (%s)" % main.enemy_species)
	GameData.match_settings = {}
	main.queue_free()
	await get_tree().process_frame


func _check_king_of_the_hill() -> void:
	print("King of the hill")
	var main := await _start_match("boulder_gym", "king_of_the_hill", "pikachu", "squirtle")
	expect(main.mode == "king_of_the_hill", "boulder gym supports king of the hill")
	expect(main.arena.has_zone(), "zone tiles found")
	main.player.position = main.arena.zone_center
	Engine.time_scale = 4.0
	await get_tree().create_timer(4.0).timeout
	Engine.time_scale = 1.0
	expect(main.scores[0] > 0.0 or main.scores[1] > 0.0, "zone time accumulates")
	main.queue_free()
	await get_tree().process_frame
