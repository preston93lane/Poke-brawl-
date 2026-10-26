extends Node3D
## Sets up and referees a 3v3 match: you plus bot teammates vs a bot team, in
## Battle (first team to N KOs) or King of the Hill (hold the zone).
## Normally configured by the menu; running main.tscn directly uses these exports.

const BRAWLER_SCENE := preload("res://scenes/brawler.tscn")
const MENU_SCENE := "res://scenes/menu.tscn"

@export var arena_id := "route_1"
@export_enum("duel", "king_of_the_hill") var mode := "duel"

@export_group("Player")
@export var player_species := "charmander"
@export_range(1, 3) var player_level := 1
## Optional move ids for the loadout; blank = newest unlocked move.
@export var player_melee := ""
@export var player_ranged := ""

@export_group("Bots")
## Your bot teammates; missing slots are filled with random Pokémon.
@export var ally_team: PackedStringArray = []
## The other team; missing slots are filled with random Pokémon.
@export var enemy_team: PackedStringArray = ["bulbasaur"]
@export_range(1, 3) var bot_level := 1

var player: Brawler
## First member of the other team (handy for tests and debugging).
var enemy: Brawler
var teams := { 0: [], 1: [] }
var round_over := false
## Battle: KOs per team. King of the hill: seconds held per team.
var scores := [0.0, 0.0]
var mode_rules: Dictionary = {}
var _spawn_index := {}

@onready var arena: Arena = $Arena
@onready var camera: FollowCamera = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	_apply_match_settings()
	if not GameData.species.has(player_species):
		push_error("Main: unknown species '%s'. Available: %s" % [player_species, ", ".join(GameData.species.keys())])
		return
	mode_rules = GameData.rule("modes/" + mode, {})
	arena.build(arena_id, camera.pitch_degrees, mode == "king_of_the_hill")
	if mode == "king_of_the_hill" and not arena.has_zone():
		push_warning("Arena '%s' has no Z tiles; switching to battle" % arena_id)
		mode = "duel"
		mode_rules = GameData.rule("modes/duel", {})

	var team_size := int(GameData.rule("team_size", 3))
	player = _spawn(player_species, player_level, 0, true, player_melee, player_ranged)
	GameData.local_player = player
	var player_controller := PlayerController.new()
	player_controller.move_stick = hud.move_stick
	player_controller.aim_stick = hud.aim_stick
	player_controller.melee_button = hud.melee_button
	player_controller.super_button = hud.super_button
	player.add_child(player_controller)

	for species_id in _fill_team(ally_team, team_size - 1, [player_species]):
		_spawn_bot(species_id, 0)
	for species_id in _fill_team(enemy_team, team_size, []):
		var bot := _spawn_bot(species_id, 1)
		if enemy == null:
			enemy = bot

	var half := arena.world_size() * 0.5
	var x_limit := maxf(0.0, half.x - 11.0)
	var z_limit := maxf(0.0, half.y - 7.0)
	camera.follow_limits = Rect2(-x_limit, -z_limit, x_limit * 2.0, z_limit * 2.0)
	camera.target = player
	camera.snap_to_target()

	hud.set_matchup(_team_names(0), _team_names(1), arena.arena_name)
	hud.set_moves(player.melee_move.display_name, player.ranged_move.display_name)
	hud.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	hud.menu_requested.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	_update_status()


## Use the choices made in the menu, if we came from there.
func _apply_match_settings() -> void:
	var s: Dictionary = GameData.match_settings
	if s.is_empty():
		return
	mode = str(s.get("mode", mode))
	arena_id = str(s.get("arena", arena_id))
	player_species = str(s.get("species", player_species))
	player_level = int(s.get("level", player_level))
	player_melee = str(s.get("melee", ""))
	player_ranged = str(s.get("ranged", ""))
	ally_team = PackedStringArray(s.get("allies", []))
	enemy_team = PackedStringArray(s.get("enemies", []))
	bot_level = int(s.get("bot_level", player_level))


## `chosen` padded to `count` with random base forms not already on the team.
func _fill_team(chosen: PackedStringArray, count: int, taken: Array) -> Array[String]:
	var result: Array[String] = []
	var used := taken.duplicate()
	for id in chosen:
		if result.size() < count and GameData.species.has(id):
			result.append(id)
			used.append(id)
	var pool: Array[String] = []
	for s in GameData.base_species():
		if s.id not in used:
			pool.append(s.id)
	pool.shuffle()
	while result.size() < count:
		if pool.is_empty():
			var all: Array[SpeciesData] = GameData.base_species()
			result.append(all[randi() % all.size()].id)
		else:
			result.append(pool.pop_back())
	return result


func _spawn_bot(species_id: String, team: int) -> Brawler:
	var brawler := _spawn(species_id, bot_level, team, false)
	var bot := BotController.new()
	if mode == "king_of_the_hill":
		bot.objective = arena.zone_center
		bot.has_objective = true
	# Stagger bots so they don't all move on the same frame.
	bot.start_delay = 1.0 + 0.15 * teams[team].size()
	brawler.add_child(bot)
	return brawler


func _spawn(species_id: String, level: int, team: int, is_player: bool, melee_id := "", ranged_id := "") -> Brawler:
	var brawler: Brawler = BRAWLER_SCENE.instantiate()
	brawler.setup(species_id, level, team, is_player, arena, melee_id, ranged_id)
	_spawn_index[brawler] = teams[team].size()
	teams[team].append(brawler)
	brawler.position = arena.spawn_point(team, _spawn_index[brawler])
	arena.add_child(brawler)
	brawler.died.connect(_on_brawler_died)
	brawler.evolved.connect(_on_brawler_evolved)
	return brawler


func _physics_process(delta: float) -> void:
	if round_over or mode != "king_of_the_hill" or player == null:
		return
	var teams_in_zone := {}
	for team: int in teams:
		for b: Brawler in teams[team]:
			if not b.is_dead and arena.is_in_zone(b.global_position):
				teams_in_zone[team] = true
	if teams_in_zone.size() == 1:
		var holder: int = teams_in_zone.keys()[0]
		scores[holder] += delta
		arena.set_zone_owner(holder)
		if scores[holder] >= float(mode_rules.get("hold_time", 60.0)):
			_end_round(holder == player.team)
	else:
		arena.set_zone_owner(-2 if teams_in_zone.size() > 1 else -1)
	_update_status()


func _on_brawler_died(victim: Brawler, killer: Brawler) -> void:
	if round_over:
		return
	if killer and killer != victim:
		killer.register_kill()
	if mode == "duel":
		var scoring_team := 1 - victim.team
		scores[scoring_team] += 1
		_update_status()
		if scores[scoring_team] >= float(mode_rules.get("kills_to_win", 10)):
			_end_round(scoring_team == player.team)
			return
	var wait := float(mode_rules.get("respawn_time", 3.0))
	if victim == player:
		hud.announce("Fainted! Back in %d…" % ceili(wait))
	await get_tree().create_timer(wait, false).timeout
	if not round_over and is_instance_valid(victim):
		victim.respawn(arena.spawn_point(victim.team, _spawn_index[victim]))


func _on_brawler_evolved(brawler: Brawler, from_name: String) -> void:
	if brawler.team == player.team:
		hud.announce("%s evolved into %s!" % [from_name, brawler.species.display_name])


func _end_round(victory: bool) -> void:
	round_over = true
	hud.show_result(victory)


func _team_names(team: int) -> String:
	var names: Array[String] = []
	for b: Brawler in teams[team]:
		names.append(b.species.display_name)
	return " · ".join(names)


func _update_status() -> void:
	if mode == "duel":
		hud.set_status("KOs  %d – %d   (first to %d)" % [scores[0], scores[1], int(mode_rules.get("kills_to_win", 10))])
	else:
		var hold := float(mode_rules.get("hold_time", 60.0))
		hud.set_status("Zone  %d%% – %d%%" % [100.0 * scores[0] / hold, 100.0 * scores[1] / hold])
