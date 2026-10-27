extends Node3D
## Sets up and referees a 3v3 match: you plus bot teammates vs a bot team, in
## Battle (first team to N KOs) or King of the Hill (hold the zone).
## Normally configured by the menu; running main.tscn directly uses these exports.

const BRAWLER_SCENE := preload("res://scenes/brawler.tscn")
## Team id for neutral raid bosses: an enemy to both sides.
const NEUTRAL_TEAM := 2
const MENU_SCENE := "res://scenes/menu.tscn"

@export var arena_id := "route_1"
@export_enum("duel", "king_of_the_hill") var mode := "duel"

@export_group("Player")
@export var player_species := "charmander"
@export_range(1, 3) var player_level := 1
## Optional main attack id; blank = newest unlocked variant.
@export var player_main := ""
## Branch for lines that split (Eevee); blank = random.
@export var player_evolution := ""

@export_group("Bots")
## Your bot teammates; missing slots are filled with random Pokémon.
@export var ally_team: PackedStringArray = []
## The other team; missing slots are filled with random Pokémon.
@export var enemy_team: PackedStringArray = ["bulbasaur"]
@export_range(1, 3) var bot_level := 1
@export_enum("easy", "normal", "hard") var bot_difficulty := "normal"

var player: Brawler
## First member of the other team (handy for tests and debugging).
var enemy: Brawler
var teams := { 0: [], 1: [] }
var round_over := false
## Battle: KOs per team. King of the hill: seconds held per team.
var scores := [0.0, 0.0]
var mode_rules: Dictionary = {}
var time_left := 150.0
var _spawn_index := {}
## Raid boss (Battle) and active legendary allies (both modes).
var raid_boss: Brawler
var _raid_done := false
var legendaries: Array[Brawler] = []
## King of the hill shrine: seconds each team has held the zone alone, uninterrupted.
var shrine_hold := [0.0, 0.0]
var shrine_cooldown := 0.0
var _item_timer := 0.0
var _hud_main: MoveData

@onready var arena: Arena = $Arena
@onready var camera: FollowCamera = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	_apply_match_settings()
	if not GameData.species.has(player_species):
		push_error("Main: unknown species '%s'. Available: %s" % [player_species, ", ".join(GameData.species.keys())])
		return
	mode_rules = GameData.rule("modes/" + mode, {})
	arena.build(arena_id, camera.pitch_degrees, mode)
	if mode == "king_of_the_hill" and not arena.has_zone():
		push_warning("Arena '%s' has no Z tiles; switching to battle" % arena_id)
		mode = "duel"
		mode_rules = GameData.rule("modes/duel", {})

	var team_size := int(GameData.rule("team_size", 3))
	player = _spawn(player_species, player_level, 0, true, player_main)
	player.preferred_evolution = player_evolution
	GameData.local_player = player
	var player_controller := PlayerController.new()
	player_controller.move_stick = hud.move_stick
	player_controller.aim_stick = hud.aim_stick
	player_controller.gadget_button = hud.gadget_button
	player_controller.super_button = hud.super_button
	player.add_child(player_controller)

	for species_id in _fill_team(ally_team, team_size - 1, [player_species]):
		_spawn_bot(species_id, 0)
	for species_id in _fill_team(enemy_team, team_size, []):
		var bot := _spawn_bot(species_id, 1)
		if enemy == null:
			enemy = bot

	var half := arena.world_size() * 0.5
	var x_limit := maxf(0.0, half.x - 14.0)
	var z_limit := maxf(0.0, half.y - 9.0)
	camera.follow_limits = Rect2(-x_limit, -z_limit, x_limit * 2.0, z_limit * 2.0)
	camera.target = player
	camera.snap_to_target()

	time_left = float(mode_rules.get("time_limit", 150.0))
	_item_timer = float(GameData.item_spawn.get("first_after", 8.0))
	hud.set_matchup(_team_names(0), _team_names(1), arena.arena_name)
	_refresh_hud_moves()
	hud.set_teams(teams)
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
	player_main = str(s.get("main", ""))
	player_evolution = str(s.get("evolution", ""))
	ally_team = PackedStringArray(s.get("allies", []))
	enemy_team = PackedStringArray(s.get("enemies", []))
	bot_level = int(s.get("bot_level", player_level))
	bot_difficulty = str(s.get("difficulty", bot_difficulty))


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
	# Bots pick a random unlocked variant of their main attack.
	var options := GameData.get_species(species_id).moves_for("main", bot_level)
	var main_id: String = options.pick_random().id if not options.is_empty() else ""
	var brawler := _spawn(species_id, bot_level, team, false, main_id)
	var bot := BotController.new()
	bot.set_difficulty(bot_difficulty)
	if mode == "king_of_the_hill":
		bot.objective = arena.zone_center
		bot.has_objective = true
	# Stagger bots so they don't all move on the same frame.
	bot.start_delay = 1.0 + 0.15 * teams[team].size()
	brawler.add_child(bot)
	return brawler


func _spawn(species_id: String, level: int, team: int, is_player: bool, main_id := "") -> Brawler:
	var brawler: Brawler = BRAWLER_SCENE.instantiate()
	brawler.setup(species_id, level, team, is_player, arena, main_id)
	_spawn_index[brawler] = teams[team].size()
	teams[team].append(brawler)
	brawler.position = arena.spawn_point(team, _spawn_index[brawler])
	arena.add_child(brawler)
	brawler.protect(float(GameData.rule("spawn_protection", 2.0)))
	brawler.died.connect(_on_brawler_died)
	brawler.evolved.connect(_on_brawler_evolved)
	return brawler


func _physics_process(delta: float) -> void:
	if round_over or player == null:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_on_time()
		return
	_tick_items(delta)
	if player.main_move != _hud_main:
		_refresh_hud_moves()  # Evolving or devolving swaps in that stage's version.
	if mode != "king_of_the_hill":
		_tick_raid()
		_update_status()
		return
	var teams_in_zone := {}
	for team: int in teams:
		for b: Brawler in teams[team]:
			if not b.is_dead and arena.is_in_zone(b.global_position):
				teams_in_zone[team] = true
	_tick_shrine(delta, teams_in_zone)
	if teams_in_zone.size() == 1:
		var holder: int = teams_in_zone.keys()[0]
		scores[holder] += delta
		arena.set_zone_owner(holder)
		if scores[holder] >= float(mode_rules.get("hold_time", 60.0)):
			_end_round("victory" if holder == player.team else "defeat")
	else:
		arena.set_zone_owner(-2 if teams_in_zone.size() > 1 else -1)
	_update_status()


func _on_brawler_died(victim: Brawler, killer: Brawler) -> void:
	if round_over:
		return
	if victim == raid_boss:
		_on_raid_boss_defeated(killer)
		return
	if killer and killer != victim:
		killer.register_kill()
	hud.add_kill(killer, victim)
	var by_boss := killer != null and killer.team == NEUTRAL_TEAM
	if mode == "duel" and not by_boss:
		var scoring_team := 1 - victim.team
		scores[scoring_team] += 1
		_update_status()
		if scores[scoring_team] >= float(mode_rules.get("kills_to_win", 10)):
			_end_round("victory" if scoring_team == player.team else "defeat")
			return
	var wait := float(mode_rules.get("respawn_time", 3.0))
	victim.respawn_left = wait
	if victim == player:
		hud.announce("Fainted! Back in %d…" % ceili(wait))
	await get_tree().create_timer(wait, false).timeout
	if not round_over and is_instance_valid(victim):
		victim.respawn(arena.spawn_point(victim.team, _spawn_index[victim]))


func _refresh_hud_moves() -> void:
	_hud_main = player.main_move
	hud.set_moves(player.main_move, player.species.gadget_move)


func _on_brawler_evolved(brawler: Brawler, from_name: String) -> void:
	if brawler.team == player.team:
		hud.announce("%s evolved into %s!" % [from_name, brawler.species.display_name])


# --- Items -----------------------------------------------------------------

func _tick_items(delta: float) -> void:
	_item_timer -= delta
	if _item_timer > 0.0:
		return
	_item_timer = float(GameData.item_spawn.get("interval", 12.0))
	if get_tree().get_nodes_in_group("items").size() >= int(GameData.item_spawn.get("max_on_map", 4)):
		return
	spawn_item(GameData.random_item_id(), arena.random_open_point())


func spawn_item(item_id: String, at: Vector3) -> ItemPickup:
	if item_id == "":
		return null
	var pickup := ItemPickup.new()
	pickup.setup(item_id)
	pickup.position = at
	arena.add_child(pickup)
	return pickup


# --- Legendaries -------------------------------------------------------------

## Battle: the arena's raid boss lands in the middle when the clock reaches raid_time_left.
func _tick_raid() -> void:
	if _raid_done or raid_boss != null:
		return
	if time_left <= float(GameData.rule("legendary/raid_time_left", 90.0)):
		spawn_raid_boss()


func spawn_raid_boss() -> Brawler:
	var boss_id := str(GameData.arenas.get(arena_id, {}).get("raid_boss", ""))
	if not GameData.species.has(boss_id):
		_raid_done = true
		return null
	var boss: Brawler = BRAWLER_SCENE.instantiate()
	boss.setup(boss_id, 3, NEUTRAL_TEAM, false, arena)
	boss.is_legendary = true
	boss.position = arena.center_point()
	arena.add_child(boss)
	boss.max_health *= float(GameData.rule("legendary/boss_hp_multiplier", 3.5))
	boss.health = boss.max_health
	boss.died.connect(_on_brawler_died)
	var bot := BotController.new()
	bot.set_difficulty("normal")
	bot.leash_center = boss.position
	bot.leash_radius = 7.0
	boss.add_child(bot)
	raid_boss = boss
	Vfx.ring(arena, boss.position, 3.0, boss.species.types[0], 80)
	hud.announce("A wild %s appeared! Most damage wins it!" % boss.species.display_name.to_upper())
	return boss


func _on_raid_boss_defeated(killer: Brawler) -> void:
	var boss := raid_boss
	_raid_done = true
	raid_boss = null
	var dealt_0 := float(boss.damage_by_team.get(0, 0.0))
	var dealt_1 := float(boss.damage_by_team.get(1, 0.0))
	var winner := 0 if dealt_0 > dealt_1 else 1
	if is_equal_approx(dealt_0, dealt_1) and killer:
		winner = clampi(killer.team, 0, 1)
	var where := boss.global_position
	boss.queue_free()
	summon_legendary(boss.species.id, winner, where)


## Brings a legendary in on `team`'s side for legendary/ally_duration seconds.
## It can't be hurt, flies over walls and fights with its own moves and super.
func summon_legendary(species_id: String, team: int, at: Vector3) -> Brawler:
	var ally: Brawler = BRAWLER_SCENE.instantiate()
	ally.setup(species_id, 3, team, false, arena)
	ally.is_legendary = true
	ally.invulnerable = true
	ally.flying = true
	ally.collision_mask = 0
	ally.position = at
	arena.add_child(ally)
	ally.died.connect(_on_brawler_died)
	ally.evolved.connect(_on_brawler_evolved)
	var bot := BotController.new()
	bot.set_difficulty("hard")
	bot.start_delay = 0.5
	if mode == "king_of_the_hill":
		bot.objective = arena.zone_center
		bot.has_objective = true
	ally.add_child(bot)
	legendaries.append(ally)
	Vfx.ring(arena, at, 2.5, ally.species.types[0], 80)
	var side := "Your team" if team == player.team else "The enemy team"
	hud.announce("%s summoned %s!" % [side, ally.species.display_name.to_upper()])
	var duration := float(GameData.rule("legendary/ally_duration", 25.0))
	ally.legendary_time_left = duration
	get_tree().create_timer(duration, false).timeout.connect(_dismiss_legendary.bind(ally))
	return ally


func _dismiss_legendary(ally: Brawler) -> void:
	if not is_instance_valid(ally):
		return
	legendaries.erase(ally)
	Vfx.burst(arena, ally.global_position + Vector3(0, 1, 0), ally.species.types[0], 40, 0.8, 4.0)
	ally.queue_free()


## King of the hill: hold the zone alone for legendary/shrine_hold seconds straight
## to awaken the arena's guardian for your team.
func _tick_shrine(delta: float, teams_in_zone: Dictionary) -> void:
	shrine_cooldown = maxf(0.0, shrine_cooldown - delta)
	var need := float(GameData.rule("legendary/shrine_hold", 20.0))
	if teams_in_zone.size() != 1 or shrine_cooldown > 0.0:
		shrine_hold = [0.0, 0.0]
		return
	var holder: int = teams_in_zone.keys()[0]
	shrine_hold[holder] += delta
	shrine_hold[1 - holder] = 0.0
	if shrine_hold[holder] >= need:
		shrine_hold = [0.0, 0.0]
		shrine_cooldown = float(GameData.rule("legendary/ally_duration", 25.0)) + float(GameData.rule("legendary/shrine_cooldown", 30.0))
		var guardian := str(GameData.arenas.get(arena_id, {}).get("guardian", ""))
		if GameData.species.has(guardian):
			summon_legendary(guardian, holder, arena.zone_center)


func _end_round(result_name: String) -> void:
	round_over = true
	_update_status()
	hud.show_result(result_name)


## Time's up: the team ahead wins; level scores are a draw.
func _end_on_time() -> void:
	var mine: float = scores[player.team]
	var theirs: float = scores[1 - player.team]
	_end_round("victory" if mine > theirs else ("defeat" if theirs > mine else "draw"))


func _team_names(team: int) -> String:
	var names: Array[String] = []
	for b: Brawler in teams[team]:
		names.append(b.species.display_name)
	return " · ".join(names)


func _update_status() -> void:
	var target := float(mode_rules.get("kills_to_win", 10)) if mode == "duel" else float(mode_rules.get("hold_time", 60.0))
	hud.set_scores(mode, scores, target, time_left)
	if mode == "king_of_the_hill":
		hud.set_shrine(shrine_hold, float(GameData.rule("legendary/shrine_hold", 20.0)), shrine_cooldown,
				str(GameData.arenas.get(arena_id, {}).get("guardian", "")))
	if mode == "duel":
		hud.set_status("KOs  %d – %d   (first to %d)" % [scores[0], scores[1], int(mode_rules.get("kills_to_win", 10))])
	else:
		var hold := float(mode_rules.get("hold_time", 60.0))
		hud.set_status("Zone  %d%% – %d%%" % [100.0 * scores[0] / hold, 100.0 * scores[1] / hold])
