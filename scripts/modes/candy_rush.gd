extends MatchMode
## Rare Candy Rush (Brawl Stars' Gem Grab): a candy pops out of the mine in the
## middle every few seconds. Carry rules.candies_to_win as a team and keep the
## lead for rules.countdown seconds to win. Fainting drops every candy you hold.

var mine := Vector3.ZERO
var _spawn_timer := 0.0
## Team currently counting down (-1 = nobody) and seconds left.
var countdown_team := -1
var countdown_left := 0.0
var _mine_fx: MeshInstance3D


func start() -> void:
	var arena: Arena = main.arena
	mine = arena.zone_center if arena.has_zone() else arena.center_point()
	mine = arena.nearest_open(mine)
	_spawn_timer = 3.0
	_build_mine()


func _build_mine() -> void:
	_mine_fx = MeshInstance3D.new()
	var hole := CylinderMesh.new()
	hole.top_radius = 0.75
	hole.bottom_radius = 0.75
	hole.height = 0.06
	_mine_fx.mesh = hole
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.25)
	_mine_fx.material_override = mat
	_mine_fx.position = mine + Vector3(0, 0.03, 0)
	main.arena.add_child(_mine_fx)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.95
	rim.mesh = torus
	rim.scale = Vector3(1, 0.3, 1)
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.45, 0.6, 1.0)
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.25, 0.4, 1.0)
	rim.material_override = rim_mat
	rim.position = mine + Vector3(0, 0.06, 0)
	main.arena.add_child(rim)


func tick(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = float(rules.get("spawn_interval", 7.0))
		if get_tree().get_nodes_in_group("collectibles").size() < 29:
			var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.0, 2.4)
			spawn_candy(mine, main.arena.nearest_open(mine + offset))
	_update_countdown(delta)


func spawn_candy(from: Vector3, at: Vector3) -> Collectible:
	var candy := Collectible.new()
	candy.setup("rare_candy", from, at)
	candy.collected.connect(_on_collected)
	main.arena.add_child(candy)
	return candy


func _on_collected(_candy: Collectible, by: Brawler) -> void:
	by.candies += 1
	by.candies_collected += 1


func team_candies(team: int) -> int:
	var total := 0
	for b: Brawler in main.teams.get(team, []):
		total += b.candies
	return total


func _update_countdown(delta: float) -> void:
	var need := int(rules.get("candies_to_win", 10))
	var c0 := team_candies(0)
	var c1 := team_candies(1)
	var leader := -1
	if c0 >= need and c0 > c1:
		leader = 0
	elif c1 >= need and c1 > c0:
		leader = 1
	if leader != countdown_team:
		countdown_team = leader
		countdown_left = float(rules.get("countdown", 15.0))
		if leader >= 0:
			main.hud.announce("Hold on for %ds!" % int(countdown_left) if leader == player_team() else "Stop them! %ds!" % int(countdown_left))
		return
	if leader >= 0:
		countdown_left -= delta
		if countdown_left <= 0.0:
			main.end_round("victory" if leader == player_team() else "defeat")


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	for i in victim.candies:
		var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.6, 1.8)
		spawn_candy(victim.global_position, main.arena.nearest_open(victim.global_position + offset))
	victim.candies = 0
	return false


func time_up() -> String:
	var mine_count := team_candies(player_team())
	var theirs := team_candies(other_team(player_team()))
	return "victory" if mine_count > theirs else ("defeat" if theirs > mine_count else "draw")


func plan_for(b: Brawler) -> Dictionary:
	var my_count := team_candies(b.team)
	var their_count := team_candies(other_team(b.team))
	# Behind or they're counting down: hunt whoever carries the most.
	if countdown_team == other_team(b.team) or their_count > my_count + 2:
		var richest: Brawler = null
		for enemy in b.enemies():
			if enemy.candies > 0 and b.can_see(enemy) and (richest == null or enemy.candies > richest.candies):
				richest = enemy
		if richest:
			return { "target": richest, "go": richest.global_position }
	# Carrying a lot while winning: play it safe near home.
	if b.candies >= 4 and my_count > their_count:
		var home := spawn_position(b)
		if b.global_position.distance_to(home) > 6.0:
			return { "go": home }
		return {}
	var nearest: Collectible = null
	var best := 14.0
	for node in get_tree().get_nodes_in_group("collectibles"):
		var c := node as Collectible
		if c and c.kind == "rare_candy" and c.is_landed():
			var d := b.global_position.distance_to(c.global_position)
			if d < best:
				best = d
				nearest = c
	if nearest:
		return { "go": nearest.global_position }
	if b.find_nearest_enemy(8.0) == null:
		return { "go": mine }
	return {}


func scoreboard_info() -> Dictionary:
	return {
		"left": team_candies(0), "right": team_candies(1),
		"goal": "COLLECT %d CANDIES" % int(rules.get("candies_to_win", 10)),
		"countdown_team": countdown_team, "countdown": countdown_left,
	}


func stat_name() -> String:
	return "CANDIES"


func stat_value(b: Brawler) -> int:
	return b.candies_collected
