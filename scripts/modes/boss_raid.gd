extends MatchMode
## Boss Raid: your team of three against one giant legendary. It has a huge
## health bar and three phases; at 66% and 33% it calls in a wave of minions of
## its type (KO them to evolve) and its telegraphed strikes come faster and in
## bigger numbers. Your team shares a pool of lives: when it runs out, fainted
## Pokémon stay down. KO the boss before time runs out to win.
## Bosses and their arenas: rules.json modes/boss_raid/bosses.

const STRIKE_WARN := 1.4

var boss_id := ""
var boss: Brawler
var lives := 6
## This fight's difficulty (rules.json modes/boss_raid/tiers): set from your wins against this boss.
var tier: Dictionary = {}
var phase := 1
var _strike_timer := 4.0
var _minions: Array[Brawler] = []
## Strikes on the way: [Vector3 centre, radius].
var _pending: Array = []


static func bosses() -> Dictionary:
	return GameData.rule("modes/boss_raid/bosses", {})


func start() -> void:
	boss_id = str(GameData.match_settings.get("boss", ""))
	if not GameData.species.has(boss_id):
		boss_id = str(bosses().keys()[0])
	tier = Profile.boss_tier(boss_id)
	lives = maxi(1, int(rules.get("team_lives", 6)) + int(tier.get("lives", 0)))
	var team_hp := 0.0
	for b: Brawler in main.teams[0]:
		team_hp += b.max_health
	boss = main._spawn(boss_id, main.player_level, 1, false)
	boss.is_legendary = true
	boss.flying = true
	boss.size_scale = float(rules.get("boss_size", 2.2))
	boss.refresh_stats()
	boss.collision_mask = 0
	boss.regenerates = false
	boss.damage_scale = float(bosses().get(boss_id, {}).get("boss_damage", rules.get("boss_damage", 0.4))) * float(tier.get("damage", 1.0))
	var capsule := (boss.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	capsule.radius = Brawler.COLLIDER_RADIUS * boss.size_scale
	capsule.height = maxf(capsule.height, capsule.radius * 2.0 + 0.2)
	boss.max_health = team_hp / maxf(1.0, main.teams[0].size()) * float(rules.get("boss_hp", 14.0)) * float(tier.get("hp", 1.0))
	boss.health = boss.max_health
	boss.position = main.arena.center_point()
	var bot := BotController.new()
	bot.set_difficulty(str(tier.get("bot", "hard")))
	bot.leash_center = boss.position
	bot.leash_radius = float(rules.get("leash", 6.0))
	bot.start_delay = 2.0
	boss.add_child(bot)
	main.enemy = boss
	main.scores = [float(lives), 100.0]


func tick(delta: float) -> void:
	if boss == null or main.round_over:
		return
	var ratio := boss.health / boss.max_health
	main.scores = [float(lives), ceilf(ratio * 100.0)]
	var new_phase := 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if new_phase > phase:
		phase = new_phase
		main.hud.announce("%s is enraged!" % boss.species.display_name.to_upper())
		boss.apply_buff({ "attack": float(rules.get("enrage_attack", 0.1)) * (phase - 1), "speed": 0.1, "duration": 999.0 })
		_call_minions(phase)
	_strike_timer -= delta
	if _strike_timer <= 0.0:
		_strike_timer = [6.0, 4.5, 3.2][phase - 1] * float(tier.get("strike_gap", 1.0))
		_strikes(phase)


## Telegraphed area strikes: a red circle under some of your team, then a hit.
func _strikes(count: int) -> void:
	var targets: Array[Brawler] = []
	for b: Brawler in main.teams[0]:
		if not b.is_dead:
			targets.append(b)
	targets.shuffle()
	var radius := float(rules.get("strike_radius", 2.2))
	for i in mini(count, targets.size()):
		var at := targets[i].global_position
		at.y = 0.0
		_strike_at(at, radius)
	if phase == 3:
		_strike_at(main.arena.random_open_point(), radius * 1.3)


func _strike_at(at: Vector3, radius: float) -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	disc.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.15, 0.1, 0.25)
	mat.no_depth_test = true
	disc.material_override = mat
	disc.position = at + Vector3(0, 0.06, 0)
	disc.add_to_group("boss_strikes")
	_pending.append([at, radius])
	main.arena.add_child(disc)
	var tween := disc.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.6, STRIKE_WARN)
	tween.tween_callback(_land_strike.bind(disc, at, radius))


func _land_strike(disc: Node3D, at: Vector3, radius: float) -> void:
	disc.queue_free()
	_pending.remove_at(0)
	if main.round_over or boss == null or boss.is_dead:
		return
	var type_name: String = boss.species.types[0]
	Vfx.ring(main.arena, at, radius, type_name, 60)
	Vfx.burst(main.arena, at + Vector3(0, 0.5, 0), type_name, 30, 0.6, 5.0)
	for b: Brawler in main.teams[0]:
		if not b.is_dead and Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length() <= radius:
			b.take_damage(b.max_health * float(rules.get("strike_damage", 0.3)) * float(tier.get("damage", 1.0)), boss)


## Minions of the boss's type (base forms): fodder to KO and evolve on.
func _call_minions(p: int) -> void:
	var pool: Array[String] = []
	for s in GameData.base_species():
		if not s.legendary and GameData.bot_allowed(s.id) and s.evolves_to != "" and s.has_type(boss.species.types[0]):
			pool.append(s.id)
	if pool.is_empty():
		return
	for i in p:
		var m: Brawler = main._spawn_bot(pool.pick_random(), 1)
		m.position = main.arena.nearest_open(boss.global_position + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
		m.max_health *= float(rules.get("minion_hp", 0.6))
		m.health = m.max_health
		m.damage_scale = float(rules.get("minion_damage", 0.7))
		_minions.append(m)
	main.hud.set_teams(main.teams)


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	if victim == boss:
		for node in main.get_tree().get_nodes_in_group("boss_strikes"):
			node.queue_free()
		main.end_round("victory")
		return true
	if victim in _minions:
		_minions.erase(victim)
		main.teams[1].erase(victim)
		victim.get_tree().create_timer(0.6, false).timeout.connect(victim.queue_free)
		main.hud.set_teams(main.teams)
		return true
	if victim.team == 0:
		if lives > 0:
			lives -= 1
			return false
		for b: Brawler in main.teams[0]:
			if not b.is_dead:
				return true
		main.end_round("defeat")
		return true
	return false


## Your team's bots step out of the red circles.
func escape_from(pos: Vector3, b: Brawler) -> Vector3:
	if b.team != 0:
		return Vector3.ZERO
	for p: Array in _pending:
		var away: Vector3 = pos - (p[0] as Vector3)
		away.y = 0.0
		if away.length() < float(p[1]) + 0.4:
			return away.normalized() if away.length() > 0.05 else Vector3.RIGHT
	return Vector3.ZERO


func time_up() -> String:
	return "defeat"


func scoreboard_info() -> Dictionary:
	return { "goal": "%s · %s" % [boss.species.display_name.to_upper() if boss else "BOSS", str(tier.get("name", "")).to_upper()] }


func spawn_position(b: Brawler) -> Vector3:
	if b.team == 0:
		return main.arena.spawn_point(0, main._spawn_index[b])
	return main.arena.center_point()
