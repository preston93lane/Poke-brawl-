extends MatchMode
## Brawl Ball: carry or kick the Poké Ball into the other team's goal. First to
## rules.goals_to_win goals wins; after each goal everyone resets to their spawns.

## Kick at the goal from this close if the shot is clear.
const SHOOT_RANGE := 8.5

var ball: Ball
var _reset_pause := 0.0


func start() -> void:
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


func plan_for(b: Brawler) -> Dictionary:
	var arena: Arena = main.arena
	var their_goal := arena.goal_center(other_team(b.team))
	var my_goal := arena.goal_center(b.team)
	if ball.carrier == b:
		var to_goal := their_goal - b.global_position
		to_goal.y = 0.0
		if to_goal.length() < SHOOT_RANGE and Brawler.clear_between(b, b.global_position, their_goal):
			return { "kick": to_goal, "hold": true }
		return { "go": their_goal, "hold": true }
	var carrier := ball.carrier
	if carrier and is_instance_valid(carrier):
		if carrier.team != b.team:
			return { "target": carrier, "go": carrier.global_position }
		# A teammate has it: run ahead of them toward the goal to cover them.
		var ahead := carrier.global_position + (their_goal - carrier.global_position).normalized() * 3.0
		return { "go": ahead }
	# Loose ball: the closest Pokémon on each team goes for it, the rest guard the goal side.
	var closest := true
	var mine := b.global_position.distance_to(ball.global_position)
	for mate: Brawler in main.teams[b.team]:
		if mate != b and not mate.is_dead and mate.global_position.distance_to(ball.global_position) < mine - 0.5:
			closest = false
	if closest or mine < 5.0:
		return { "go": ball.global_position }
	return { "go": ball.global_position.lerp(my_goal, 0.4) }


func scoreboard_info() -> Dictionary:
	return { "goal": "FIRST TO %d GOALS" % int(rules.get("goals_to_win", 2)) }


func stat_name() -> String:
	return "GOALS"


func stat_value(b: Brawler) -> int:
	return b.goals
