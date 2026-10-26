extends Node3D
## Sets up and referees a 1v1 match: player vs bot, in Duel (first to N KOs)
## or King of the Hill (hold the zone). Pick everything in the Inspector.

const BRAWLER_SCENE := preload("res://scenes/brawler.tscn")

@export var arena_id := "route_1"
@export_enum("duel", "king_of_the_hill") var mode := "duel"

@export_group("Player")
@export var player_species := "charmander"
@export_range(1, 3) var player_level := 1
## Optional move ids for the loadout; blank = newest unlocked move.
@export var player_melee := ""
@export var player_ranged := ""

@export_group("Bot")
@export var enemy_species := "bulbasaur"
@export_range(1, 3) var enemy_level := 1

var player: Brawler
var enemy: Brawler
var round_over := false
## Duel: KOs per team. King of the hill: seconds held per team.
var scores := [0.0, 0.0]
var mode_rules: Dictionary = {}

@onready var arena: Arena = $Arena
@onready var camera: FollowCamera = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	if not GameData.species.has(player_species) or not GameData.species.has(enemy_species):
		push_error("Main: unknown species. Available: %s" % ", ".join(GameData.species.keys()))
		return
	mode_rules = GameData.rule("modes/" + mode, {})
	arena.build(arena_id, camera.pitch_degrees)
	if mode == "king_of_the_hill" and not arena.has_zone():
		push_warning("Arena '%s' has no Z tiles; switching to duel" % arena_id)
		mode = "duel"
		mode_rules = GameData.rule("modes/duel", {})

	player = _spawn(player_species, player_level, 0, true, player_melee, player_ranged)
	enemy = _spawn(enemy_species, enemy_level, 1, false)

	var player_controller := PlayerController.new()
	player_controller.move_stick = hud.move_stick
	player_controller.aim_stick = hud.aim_stick
	player_controller.melee_button = hud.melee_button
	player.add_child(player_controller)

	var bot := BotController.new()
	bot.target = player
	if mode == "king_of_the_hill":
		bot.objective = arena.zone_center
		bot.has_objective = true
	enemy.add_child(bot)

	var half := arena.world_size() * 0.5
	camera.follow_limits = Rect2(-2, -(half.y - 6), 4, (half.y - 6) * 2)
	camera.target = player
	camera.snap_to_target()

	hud.set_matchup("%s (Lv%d)" % [player.species.display_name, player.level],
			"%s (Lv%d)" % [enemy.species.display_name, enemy.level], arena.arena_name)
	hud.set_moves(player.melee_move.display_name, player.ranged_move.display_name)
	hud.restart_requested.connect(func() -> void: get_tree().reload_current_scene())
	_update_status()


func _physics_process(delta: float) -> void:
	if round_over or mode != "king_of_the_hill" or player == null:
		return
	var teams_in_zone := {}
	for b: Brawler in [player, enemy]:
		if not b.is_dead and arena.is_in_zone(b.global_position):
			teams_in_zone[b.team] = true
	if teams_in_zone.size() == 1:
		var holder: int = teams_in_zone.keys()[0]
		scores[holder] += delta
		arena.set_zone_owner(holder)
		if scores[holder] >= float(mode_rules.get("hold_time", 45.0)):
			_end_round(holder == player.team)
	else:
		arena.set_zone_owner(-2 if teams_in_zone.size() > 1 else -1)
	_update_status()


func _spawn(species_id: String, level: int, team: int, is_player: bool, melee_id := "", ranged_id := "") -> Brawler:
	var brawler: Brawler = BRAWLER_SCENE.instantiate()
	brawler.setup(species_id, level, team, is_player, arena, melee_id, ranged_id)
	brawler.position = arena.spawns[team]
	arena.add_child(brawler)
	brawler.died.connect(_on_brawler_died)
	brawler.evolved.connect(_on_brawler_evolved)
	return brawler


func _on_brawler_died(victim: Brawler, killer: Brawler) -> void:
	if round_over:
		return
	if killer and killer != victim:
		killer.register_kill()
	if mode == "duel":
		var scoring_team := 1 - victim.team
		scores[scoring_team] += 1
		_update_status()
		if scores[scoring_team] >= float(mode_rules.get("kills_to_win", 5)):
			_end_round(scoring_team == player.team)
			return
	var wait := float(mode_rules.get("respawn_time", 3.0))
	if victim == player:
		hud.announce("Fainted! Back in %d…" % ceili(wait))
	await get_tree().create_timer(wait, false).timeout
	if not round_over:
		victim.respawn(arena.spawns[victim.team])


func _on_brawler_evolved(brawler: Brawler, from_name: String) -> void:
	hud.announce("%s evolved into %s!" % [from_name, brawler.species.display_name])


func _end_round(victory: bool) -> void:
	round_over = true
	hud.show_result(victory)


func _update_status() -> void:
	if mode == "duel":
		hud.set_status("KOs  %d – %d   (first to %d)" % [scores[0], scores[1], int(mode_rules.get("kills_to_win", 5))])
	else:
		var hold := float(mode_rules.get("hold_time", 45.0))
		hud.set_status("Zone  %d%% – %d%%" % [100.0 * scores[0] / hold, 100.0 * scores[1] / hold])
