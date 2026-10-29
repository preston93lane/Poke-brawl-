extends MatchMode
## Brawl Ball: carry or kick the Poké Ball into the other team's goal. First to
## rules.goals_to_win goals wins; after each goal everyone resets to their spawns.

## Kick at the goal from this close if the shot is clear.
const SHOOT_RANGE := 8.5

var ball: Ball
var _reset_pause := 0.0


func start() -> void:
	main.arena.block_goal_sides()
	ball = Ball.new()
	main.arena.add_child(ball)
	ball.reset(main.arena.center_point())


func tick(delta: float) -> void:
	if _reset_pause > 0.0:
		_reset_pause -= delta
		return
	var owner_team: int = main.arena.goal_owner(ball.global_position)
	if owner_team < 0:
		return
	var scorer := other_team(owner_team)
	main.scores[scorer] += 1
	var by: Brawler = ball.last_touch if is_instance_valid(ball.last_touch) and ball.last_touch.team == scorer else null
	if by:
		by.goals += 1
	var who := (by.species.display_name + " scores!") if by else "Goal!"
	main.hud.announce("GOAL!  %s" % who if scorer == player_team() else "THEY SCORED…  %s" % who)
	Vfx.ring(main.arena, ball.global_position, 3.0, "electric", 80)
	if main.scores[scorer] >= float(rules.get("goals_to_win", 2)):
		main.end_round("victory" if scorer == player_team() else "defeat")
		return
	_kick_off()


## Everyone back to their spawn, healed; ball back in the middle.
func _kick_off() -> void:
	_reset_pause = 1.0
	ball.reset(main.arena.center_point())
	for team: int in main.teams:
		for b: Brawler in main.teams[team]:
			if not b.is_dead:
				b.position = spawn_position(b)
				b.velocity = Vector3.ZERO
				b.health = b.max_health
				b.protect(1.5)


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	if ball.carrier == victim:
		ball.drop()
	return false


## Bots play roles instead of all chasing the ball:
## - Carrier: pushes toward their goal, steering away from enemies in the way;
##   shoots when there's a clear shot; low on health with an enemy close, it
##   passes ahead to a teammate (or clears the ball forward) instead of dying.
## - Carrier's teammates: guard the carrier, attacking the nearest threat, or
##   run ahead on either flank (one left, one right) to open space.
## - Enemy has the ball: the nearest chaser attacks the carrier, one falls back
##   to defend the goal, the other harasses from range.
## - Loose ball: only the nearest teammate goes for it; one gets ready on a
##   flank toward their goal, the other covers their own goal.
func plan_for(b: Brawler) -> Dictionary:
	var arena: Arena = main.arena
	var their_goal := arena.goal_center(other_team(b.team))
	var my_goal := arena.goal_center(b.team)
	var mates := _teammates(b)
	var carrier := ball.carrier
	if carrier == b:
		return _carry(b, their_goal, mates)
	if carrier and is_instance_valid(carrier) and not carrier.is_dead:
		if carrier.team == b.team:
			return _support(b, carrier, their_goal, mates)
		return _defend(b, carrier, my_goal, mates)
	# Loose ball.
	var rank := _rank_by_distance(b, mates, ball.global_position)
	if rank == 0 or b.global_position.distance_to(ball.global_position) < 2.5:
		return { "go": ball.global_position }
	if rank == 1:
		var flank := _side(b, mates) * 3.5
		var spot := ball.global_position.lerp(their_goal, 0.35) + _across(ball.global_position, their_goal) * flank
		return { "go": arena.nearest_open(spot) }
	return { "go": arena.nearest_open(ball.global_position.lerp(my_goal, 0.55)) }


func _carry(b: Brawler, their_goal: Vector3, mates: Array[Brawler]) -> Dictionary:
	var to_goal := their_goal - b.global_position
	to_goal.y = 0.0
	if to_goal.length() < SHOOT_RANGE and Brawler.clear_between(b, b.global_position, their_goal):
		return { "kick": to_goal, "hold": true }
	var threat := b.find_nearest_enemy(4.5)
	if threat and b.health < b.max_health * 0.35:
		# About to go down: pass to a teammate nearer the goal, or clear it forward.
		for mate in mates:
			if mate.global_position.distance_to(their_goal) < b.global_position.distance_to(their_goal) - 1.0 \
					and Brawler.clear_between(b, b.global_position, mate.global_position):
				var to_mate := mate.global_position - b.global_position
				to_mate.y = 0.0
				return { "kick": to_mate, "hold": true }
		return { "kick": to_goal, "hold": true }
	var go := their_goal
	threat = b.find_nearest_enemy(6.0)
	if threat:
		# Swerve around the defender instead of running into it.
		var to_threat := threat.global_position - b.global_position
		to_threat.y = 0.0
		if to_threat.dot(to_goal.normalized()) > 0.0:
			var side := Vector3(-to_goal.z, 0, to_goal.x).normalized()
			if side.dot(to_threat) > 0.0:
				side = -side
			go = b.global_position + to_goal.normalized() * 3.0 + side * 3.0
	return { "go": main.arena.nearest_open(go), "hold": true }


func _support(b: Brawler, carrier: Brawler, their_goal: Vector3, mates: Array[Brawler]) -> Dictionary:
	var threat := carrier.find_nearest_enemy(7.0)
	if threat:
		# Stand between the carrier and the threat, and shoot it.
		var spot := carrier.global_position.lerp(threat.global_position, 0.5)
		return { "target": threat, "go": main.arena.nearest_open(spot) }
	var forward := (their_goal - carrier.global_position)
	forward.y = 0.0
	forward = forward.normalized()
	var ahead := carrier.global_position + forward * 3.5 + Vector3(-forward.z, 0, forward.x) * _side(b, mates) * 3.0
	return { "go": main.arena.nearest_open(ahead) }


func _defend(b: Brawler, carrier: Brawler, my_goal: Vector3, mates: Array[Brawler]) -> Dictionary:
	var rank := _rank_by_distance(b, mates, carrier.global_position)
	if rank == 0:
		return { "target": carrier, "go": carrier.global_position }
	if rank == 1:
		var guard := my_goal + (carrier.global_position - my_goal).normalized() * 3.0
		return { "target": carrier, "go": main.arena.nearest_open(guard) }
	# Harass from range: keep the carrier at shooting distance.
	var away := (b.global_position - carrier.global_position)
	away.y = 0.0
	var keep := carrier.global_position + away.normalized() * maxf(3.0, b.main_move.effective_reach() * 0.7)
	return { "target": carrier, "go": main.arena.nearest_open(keep) }


func _teammates(b: Brawler) -> Array[Brawler]:
	var result: Array[Brawler] = []
	for node in main.teams.get(b.team, []):
		var mate := node as Brawler
		if mate and mate != b and not mate.is_dead:
			result.append(mate)
	return result


## 0 = this Pokémon is its team's closest to `point`, 1 = second closest...
func _rank_by_distance(b: Brawler, mates: Array[Brawler], point: Vector3) -> int:
	var mine := b.global_position.distance_to(point)
	var rank := 0
	for mate in mates:
		var theirs := mate.global_position.distance_to(point)
		if theirs < mine or (is_equal_approx(theirs, mine) and mate.get_instance_id() < b.get_instance_id()):
			rank += 1
	return rank


## Splits teammates onto the left (-1) and right (+1) so they spread out.
func _side(b: Brawler, mates: Array[Brawler]) -> float:
	var smaller := 0
	for mate in mates:
		if mate.get_instance_id() < b.get_instance_id():
			smaller += 1
	return -1.0 if smaller % 2 == 0 else 1.0


## Unit vector across the line from `a` to `b` (for flanking).
static func _across(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	d.y = 0.0
	return Vector3(-d.z, 0, d.x).normalized()


func scoreboard_info() -> Dictionary:
	return { "goal": "FIRST TO %d GOALS" % int(rules.get("goals_to_win", 2)) }


func stat_name() -> String:
	return "GOALS"


func stat_value(b: Brawler) -> int:
	return b.goals
