class_name MatchMode
extends Node
## Rules for a game mode that needs more than counting KOs or zone time:
## Brawl Ball, Rare Candy Rush and Showdown. Main creates one, adds it as a
## child and calls these hooks; bots ask plan_for() what the mode wants them to do.

## The match (main.gd). Untyped so modes can call its helpers.
var main: Node
var rules: Dictionary = {}


## Called once every Pokémon has spawned.
func start() -> void:
	pass


func tick(_delta: float) -> void:
	pass


## A Pokémon fainted. Return true if it must not respawn (Showdown).
func on_died(_victim: Brawler, _killer: Brawler) -> bool:
	return false


## What the mode wants a bot to do right now. Keys (all optional):
## "go": Vector3 to walk to, "target": Brawler to fight, "shoot": Vector3 point to
## attack (crates), "kick": Vector3 direction to kick the ball, "hold": true = don't attack.
func plan_for(_bot: Brawler) -> Dictionary:
	return {}


## Direction to step to get out of a mode danger zone (Boss Raid strikes), or ZERO.
func escape_from(_pos: Vector3, _b: Brawler) -> Vector3:
	return Vector3.ZERO


## Result when the clock runs out ("victory"/"defeat"/"draw"); "" = compare scores.
func time_up() -> String:
	return ""


## Extra info for the scoreboard (see scoreboard.gd).
func scoreboard_info() -> Dictionary:
	return {}


## Column on the match summary ("GOALS", "CANDIES"...); "" for none.
func stat_name() -> String:
	return ""


func stat_value(_b: Brawler) -> int:
	return 0


## Where `b` spawns / respawns.
func spawn_position(b: Brawler) -> Vector3:
	return main.arena.spawn_point(b.team, main._spawn_index[b])


func player_team() -> int:
	return main.player.team


func other_team(team: int) -> int:
	return 1 - team
