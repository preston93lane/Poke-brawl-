extends Node3D
## Sets up and referees a match: 3v3 Battle (first team to N KOs), King of the
## Hill (hold the zone), Brawl Ball, Rare Candy Rush, or free-for-all Showdown.
## The last three keep their rules in scripts/modes/.
## Normally configured by the menu; running main.tscn directly uses these exports.

const BRAWLER_SCENE := preload("res://scenes/brawler.tscn")
## Team id for neutral raid bosses: an enemy to both sides.
const NEUTRAL_TEAM := 9
const MODE_SCRIPTS := {
	"brawl_ball": preload("res://scripts/modes/brawl_ball.gd"),
	"candy_rush": preload("res://scripts/modes/candy_rush.gd"),
	"showdown": preload("res://scripts/modes/showdown.gd"),
	"boss_raid": preload("res://scripts/modes/boss_raid.gd"),
	"gym": preload("res://scripts/modes/gym.gd"),
}
const MENU_SCENE := "res://scenes/menu.tscn"

@export var arena_id := "route_1"
## Team banners before the match starts (tests turn it off).
@export var show_intro := true
const MATCH_INTRO := preload("res://scripts/ui/match_intro.gd")
const MODE_TITLES := {
	"duel": "BATTLE", "king_of_the_hill": "KING OF THE HILL", "brawl_ball": "BRAWL BALL",
	"candy_rush": "RARE CANDY RUSH", "showdown": "SHOWDOWN", "boss_raid": "BOSS RAID", "gym": "GYM BATTLE",
}
@export_enum("duel", "king_of_the_hill", "brawl_ball", "candy_rush", "showdown", "boss_raid", "gym") var mode := "duel"

@export_group("Player")
@export var player_species := "charmander"
## Profile level of the line (0 = read it from the profile).
@export_range(0, 60) var player_level := 0
## Optional main attack id; blank = newest unlocked variant.
@export var player_main := ""
## Branch for lines that split (Eevee); blank = random.
@export var player_evolution := ""
@export var player_shiny := false
## Active HM ("cut", "fly"... blank = none).
@export var player_hm := ""
## Award XP, Poké Dollars and Poké Balls when the match ends.
@export var record_progress := true

@export_group("Bots")
## Your bot teammates; missing slots are filled with random Pokémon.
@export var ally_team: PackedStringArray = []
## The other team; missing slots are filled with random Pokémon.
@export var enemy_team: PackedStringArray = ["bulbasaur"]
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
## Raid boss your team won this match ("" = none), for challenges and rewards.
var raid_won := ""
var legendaries: Array[Brawler] = []
## King of the hill shrine: seconds each team has held the zone alone, uninterrupted.
var shrine_hold := [0.0, 0.0]
var shrine_cooldown := 0.0
var _item_timer := 0.0
## Rules object for Brawl Ball / Rare Candy Rush / Showdown (null for Battle and King of the Hill).
var mode_logic: MatchMode
var _hud_kick := false
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
	var hazards := Hazards.new()
	hazards.name = "Hazards"
	arena.add_child(hazards)
	hazards.setup(self, arena)
	if hazards.is_active():
		arena.hazards = hazards

	if MODE_SCRIPTS.has(mode):
		mode_logic = MODE_SCRIPTS[mode].new()
		mode_logic.main = self
		mode_logic.rules = mode_rules
		add_child(mode_logic)
	var team_size := int(GameData.rule("team_size", 3))
	if mode == "showdown":
		teams = {}
		for i in int(mode_rules.get("players", 6)):
			teams[i] = []
	if player_level <= 0:
		player_level = Profile.level_of(player_species)
	player = _spawn(player_species, player_level, 0, true, player_main)
	player.preferred_evolution = player_evolution
	GameData.local_player = player
	var player_controller := PlayerController.new()
	player_controller.move_stick = hud.move_stick
	player_controller.aim_stick = hud.aim_stick
	player_controller.gadget_button = hud.gadget_button
	player_controller.super_button = hud.super_button
	player_controller.hm_button = hud.hm_button
	hud.set_hm(player.hm_move())
	player.add_child(player_controller)

	if mode == "showdown":
		# Everyone for themselves: each opponent is its own team.
		var others := _fill_team(enemy_team, teams.size() - 1, [player_species])
		for i in others.size():
			var bot := _spawn_bot(others[i], i + 1)
			if enemy == null:
				enemy = bot
	else:
		for species_id in _fill_team(ally_team, team_size - 1, [player_species]):
			_spawn_bot(species_id, 0)
		# Boss Raid: the mode brings in the boss itself.
		for species_id in _fill_team(enemy_team, 0 if mode == "boss_raid" else team_size, []):
			var bot := _spawn_bot(species_id, 1)
			if enemy == null:
				enemy = bot
	if mode_logic:
		mode_logic.start()

	var half := arena.world_size() * 0.5
	var x_limit := maxf(0.0, half.x - 14.0)
	var z_limit := maxf(0.0, half.y - 9.0)
	camera.follow_limits = Rect2(-x_limit, -z_limit, x_limit * 2.0, z_limit * 2.0)
	camera.field_half = half.y
	camera.target = player
	camera.snap_to_target()

	time_left = float(mode_rules.get("time_limit", 150.0))
	_item_timer = float(GameData.item_spawn.get("first_after", 8.0))
	hud.set_matchup(_team_names(0), _team_names(1), arena.arena_name)
	_refresh_hud_moves()
	hud.set_teams(teams)
	hud.restart_requested.connect(func() -> void:
		if mode == "gym" and not GameData.gym_run.is_empty():
			GameData.match_settings = GymMode.settings_for(GameData.gym_run)  # Next round (or round 1 again).
		get_tree().reload_current_scene())
	hud.menu_requested.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	_update_status()
	if Profile.is_dev():
		_add_dev_buttons()
	if show_intro:
		await _play_intro()


## Dev mode: shortcuts for testing (top left, under the scoreboard's edge).
func _add_dev_buttons() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(8, 8)
	row.add_theme_constant_override("separation", 6)
	var raid := UiKit.button("RAID NOW", func() -> void:
		if raid_boss == null and not _raid_done:
			var _boss := spawn_raid_boss(), 16)
	var win := UiKit.button("WIN", func() -> void:
		if not round_over:
			end_round("victory", "Dev win"), 16)
	for b: Button in [raid, win]:
		b.modulate.a = 0.8
		row.add_child(b)
	hud.add_child(row)


## Pause everything while the team banners play.
func _play_intro() -> void:
	var allies: Array = teams[player.team]
	var others: Array = []
	for team: int in teams:
		if team != player.team:
			others.append_array(teams[team])
	var intro = MATCH_INTRO.new()
	hud.add_child(intro)
	get_tree().paused = true
	var title: String = MODE_TITLES.get(mode, mode.to_upper())
	if mode == "gym" and not GameData.gym_run.is_empty():
		title = GymMode.round_title(GameData.gym_run)
	elif mode == "boss_raid" and mode_logic.get("boss"):
		title = "BOSS RAID  ·  %s" % str(mode_logic.get("tier").get("name", "")).to_upper()
	await intro.play(allies, others, title, arena.arena_name)
	get_tree().paused = false


## Use the choices made in the menu, if we came from there.
func _apply_match_settings() -> void:
	var s: Dictionary = GameData.match_settings
	if s.is_empty():
		return
	mode = str(s.get("mode", mode))
	arena_id = str(s.get("arena", arena_id))
	player_species = str(s.get("species", player_species))
	player_level = int(s.get("level", 0))
	player_hm = str(s.get("hm", ""))
	player_main = str(s.get("main", ""))
	player_evolution = str(s.get("evolution", ""))
	player_shiny = bool(s.get("shiny", false))
	ally_team = PackedStringArray(s.get("allies", []))
	enemy_team = PackedStringArray(s.get("enemies", []))
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
		if s.id not in used and GameData.bot_allowed(s.id):
			pool.append(s.id)
	pool.shuffle()
	while result.size() < count:
		if pool.is_empty():
			var all: Array[String] = []
			for sp in GameData.base_species():
				if GameData.bot_allowed(sp.id):
					all.append(sp.id)
			result.append(all[randi() % all.size()])
		else:
			result.append(pool.pop_back())
	return result


func _spawn_bot(species_id: String, team: int) -> Brawler:
	# Bots play at your line's level, with a random unlocked main attack and as
	# many vitamins as you have active (spread at random), so it stays fair.
	var options := GameData.get_species(species_id).moves_for("main", player_level)
	var main_id: String = options.pick_random().id if not options.is_empty() else ""
	var brawler := _spawn(species_id, player_level, team, false, main_id)
	var active := {}
	for i in Profile.active_vitamin_total(player_species):
		var stat: String = Profile.STATS.pick_random()
		active[stat] = int(active.get(stat, 0)) + 1
	brawler.vitamin_bonus = Profile.vitamin_bonus_from(active)
	brawler.refresh_stats()
	var bot := BotController.new()
	bot.set_difficulty(bot_difficulty)
	if mode == "king_of_the_hill":
		bot.objective = arena.zone_center
		bot.has_objective = true
	bot.mode_logic = mode_logic
	# Stagger bots so they don't all move on the same frame.
	bot.start_delay = 1.0 + 0.15 * teams[team].size()
	brawler.add_child(bot)
	return brawler


func _spawn(species_id: String, level: int, team: int, is_player: bool, main_id := "") -> Brawler:
	var brawler: Brawler = BRAWLER_SCENE.instantiate()
	var unlocked: Array[String] = []
	if is_player:
		unlocked = Profile.unlocked_mains(species_id)
	brawler.setup(species_id, level, team, is_player, arena, main_id, unlocked)
	if is_player:
		brawler.vitamin_bonus = Profile.vitamin_bonus(species_id)
		brawler.super_choices = Profile.super_choices(species_id)
		if player_hm in Profile.learned_hms(species_id):
			brawler.hm_id = player_hm
	# The player picks shiny in the menu; bots are shiny once in a while.
	brawler.shiny = (player_shiny and Profile.has_shiny(species_id)) if is_player else randf() < float(GameData.rule("shiny_chance", 0.06))
	_spawn_index[brawler] = teams[team].size()
	teams[team].append(brawler)
	brawler.position = spawn_position(brawler)
	arena.add_child(brawler)
	brawler.protect(float(GameData.rule("spawn_protection", 2.0)))
	brawler.died.connect(_on_brawler_died)
	brawler.evolved.connect(_on_brawler_evolved)
	return brawler


func spawn_position(b: Brawler) -> Vector3:
	if mode_logic:
		return mode_logic.spawn_position(b)
	return arena.spawn_point(b.team, _spawn_index[b])


## Tells the see-through shaders where your Pokémon is (xray.gdshaderinc).
func _process(_delta: float) -> void:
	var at := Vector3(0, -100, 0)
	var size := Vector2.ZERO
	if player and not player.is_dead:
		at = player.sprite.global_position
		var h := player.visual_height()
		size = Vector2(maxf(0.35, h * 0.45), h + 0.1)
	RenderingServer.global_shader_parameter_set("player_xray", at)
	RenderingServer.global_shader_parameter_set("player_xray_size", size)


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
	if (player.ball != null) != _hud_kick:
		_hud_kick = player.ball != null
		hud.set_kick(_hud_kick, player.main_move)
	if mode_logic:
		mode_logic.tick(delta)
		_update_status()
		return
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
			end_round("victory" if holder == player.team else "defeat")
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
	if victim in legendaries:
		# A fainted legendary ally leaves for good (it counts as legendary/ally_ko_points KOs in Battle).
		if mode == "duel" and killer and killer.team in [0, 1]:
			scores[killer.team] += float(GameData.rule("legendary/ally_ko_points", 3))
			_update_status()
			if scores[killer.team] >= float(mode_rules.get("kills_to_win", 10)):
				end_round("victory" if killer.team == player.team else "defeat")
		hud.announce("%s fainted! +%d KOs" % [victim.species.display_name.to_upper(), int(GameData.rule("legendary/ally_ko_points", 3))] if mode == "duel" else "%s fainted!" % victim.species.display_name.to_upper())
		get_tree().create_timer(1.0, false).timeout.connect(_dismiss_legendary.bind(victim))
		return
	if mode_logic and mode_logic.on_died(victim, killer):
		_update_status()
		return  # Showdown: no respawns.
	if round_over:
		return
	var by_boss := killer != null and killer.team == NEUTRAL_TEAM
	if mode == "duel" and not by_boss:
		var scoring_team := 1 - victim.team
		scores[scoring_team] += 1
		_update_status()
		if scores[scoring_team] >= float(mode_rules.get("kills_to_win", 10)):
			end_round("victory" if scoring_team == player.team else "defeat")
			return
	var wait := float(mode_rules.get("respawn_time", 3.0))
	victim.respawn_left = wait
	if victim == player:
		hud.announce("Fainted! Back in %d…" % ceili(wait))
	await get_tree().create_timer(wait, false).timeout
	if not round_over and is_instance_valid(victim):
		victim.respawn(spawn_position(victim))


func _refresh_hud_moves() -> void:
	_hud_main = player.main_move
	hud.set_moves(player.main_move, player.species.gadget_move)


func _on_brawler_evolved(brawler: Brawler, from_name: String) -> void:
	if brawler.team == player.team:
		if from_name == brawler.species.display_name:
			hud.announce("%s powered up!" % from_name)
		else:
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
	boss.regenerates = false
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
	if winner == player.team:
		raid_won = boss.species.id
	boss.queue_free()
	summon_legendary(boss.species.id, winner, where)


## Brings a legendary in on `team`'s side for legendary/ally_duration seconds.
## It can't be hurt, flies over walls and fights with its own moves and super.
func summon_legendary(species_id: String, team: int, at: Vector3) -> Brawler:
	var ally: Brawler = BRAWLER_SCENE.instantiate()
	ally.setup(species_id, 3, team, false, arena)
	ally.is_legendary = true
	ally.regenerates = false
	ally.flying = true
	ally.collision_mask = 0
	ally.position = at
	arena.add_child(ally)
	# Beefy but beatable: about twice a normal Pokémon's health.
	var total := 0.0
	var count := 0
	for t: int in teams:
		for node in teams[t]:
			if is_instance_valid(node):
				total += (node as Brawler).max_health
				count += 1
	ally.max_health = (total / maxi(1, count)) * float(GameData.rule("legendary/ally_hp_multiplier", 2.0))
	ally.health = ally.max_health
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


## `subtitle` is an extra line under VICTORY/DEFEAT (e.g. your Showdown placing).
func end_round(result_name: String, subtitle := "") -> void:
	if round_over:
		return
	round_over = true
	_update_status()
	var rows := summary_rows()
	var rewards := {}
	if record_progress and player:
		var mvp := false
		for row in rows:
			if row["is_player"]:
				mvp = row["mvp"]
		rewards = Profile.record_match({
			"species": player_species, "result": result_name, "kos": player.kills, "mvp": mvp,
			"arena": arena_id, "mode": mode, "difficulty": bot_difficulty, "raid": raid_won,
			"boss": str(mode_logic.get("boss_id")) if mode == "boss_raid" and result_name == "victory" else "",
			"goals": player.goals, "supers": player.supers_used, "final_stage": player.species.stage > 1 and player.species.evolves_to == "",
			"types": player.species.types,
		})
	if mode == "gym":
		var gym_end: Dictionary = mode_logic.call("finish", result_name)
		subtitle = str(gym_end.get("subtitle", subtitle))
		hud.set_rematch_text(str(gym_end.get("next", "REMATCH")))
		var cleared: Dictionary = gym_end.get("rewards", {})
		if not cleared.is_empty() and not rewards.is_empty():
			rewards["money"] = int(rewards["money"]) + int(cleared["money"])
			(rewards["balls"] as Array).append_array(cleared["balls"])
			(rewards["pokemon"] as Array).append_array(cleared["pokemon"])
			rewards["extras"] = cleared["texts"]
	hud.show_result(result_name, rows, mode_logic.stat_name() if mode_logic else "", subtitle, rewards)


## One row per Pokémon for the match summary, with an MVP picked by score.
## The score mixes KOs, KO/faint ratio and damage (healing counts as damage), each
## as a share of the best in the match; modes with a stat (Brawl Ball goals,
## candies, cubes) weigh that in too. Weights: rules.json mvp.
func summary_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for team: int in teams:
		for node in teams[team]:
			if not is_instance_valid(node):
				continue
			var b: Brawler = node
			var stat := mode_logic.stat_value(b) if mode_logic else 0
			rows.append({
				"brawler": b, "team": team, "is_player": b.is_player, "name": b.species.display_name,
				"sprite": b.portrait(), "kills": b.kills, "deaths": b.deaths, "damage": roundi(b.damage_dealt),
				"healing": roundi(b.healing_done), "stat": stat, "score": 0.0, "placement": b.placement, "mvp": false,
			})
	var best := { "kills": 0.0, "kd": 0.0, "damage": 0.0, "stat": 0.0 }
	for row in rows:
		row["kd"] = float(row["kills"]) / maxf(1.0, float(row["deaths"]))
		row["dmg"] = float(row["damage"]) + float(row["healing"]) * 0.8
		best["kills"] = maxf(best["kills"], float(row["kills"]))
		best["kd"] = maxf(best["kd"], float(row["kd"]))
		best["damage"] = maxf(best["damage"], float(row["dmg"]))
		best["stat"] = maxf(best["stat"], float(row["stat"]))
	var with_stat := mode_logic != null and mode_logic.stat_name() != ""
	var w: Dictionary = GameData.rule("mvp/" + ("with_stat" if with_stat else "default"), {})
	for row in rows:
		var share := func(value: float, top: float) -> float: return value / top if top > 0.0 else 0.0
		row["score"] = float(w.get("kills", 0.35)) * share.call(float(row["kills"]), best["kills"]) \
				+ float(w.get("kd", 0.25)) * share.call(float(row["kd"]), best["kd"]) \
				+ float(w.get("damage", 0.4)) * share.call(float(row["dmg"]), best["damage"]) \
				+ float(w.get("stat", 0.0)) * share.call(float(row["stat"]), best["stat"])
	if mode == "showdown":
		var place := 1
		for row in rows:
			if int(row["placement"]) == 0:
				row["placement"] = place  # Still standing at the end.
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["placement"]) < int(b["placement"]))
	var top := -1
	for i in rows.size():
		if top < 0 or float(rows[i]["score"]) > float(rows[top]["score"]):
			top = i
	if top >= 0:
		rows[top]["mvp"] = true
	return rows


## Time's up: the team ahead wins; level scores are a draw.
func _end_on_time() -> void:
	if mode_logic:
		var result := mode_logic.time_up()
		if result != "":
			end_round(result, "#%d" % player.placement if mode == "showdown" else "")
			return
	var mine: float = scores[player.team]
	var theirs: float = scores[1 - player.team]
	end_round("victory" if mine > theirs else ("defeat" if theirs > mine else "draw"))


func _team_names(team: int) -> String:
	var names: Array[String] = []
	for b: Brawler in teams[team]:
		names.append(b.species.display_name)
	return " · ".join(names)


func _update_status() -> void:
	var target := float(mode_rules.get("kills_to_win", 10)) if mode == "duel" else float(mode_rules.get("hold_time", 60.0))
	if mode == "brawl_ball":
		target = float(mode_rules.get("goals_to_win", 2))
	elif mode == "candy_rush":
		target = float(mode_rules.get("candies_to_win", 10))
	hud.set_scores(mode, scores, target, time_left)
	hud.set_mode_info(mode_logic.scoreboard_info() if mode_logic else {})
	if mode_logic:
		return
	if mode == "king_of_the_hill":
		hud.set_shrine(shrine_hold, float(GameData.rule("legendary/shrine_hold", 20.0)), shrine_cooldown,
				str(GameData.arenas.get(arena_id, {}).get("guardian", "")))
	if mode == "duel":
		hud.set_status("KOs  %d – %d   (first to %d)" % [scores[0], scores[1], int(mode_rules.get("kills_to_win", 10))])
	else:
		var hold := float(mode_rules.get("hold_time", 60.0))
		hud.set_status("Zone  %d%% – %d%%" % [100.0 * scores[0] / hold, 100.0 * scores[1] / hold])
