class_name Rocket
extends RefCounted
## Team Rocket Hideout (data/rocket.json): when it's open, today's line-up, the
## run in progress (your team of three through three Grunts and two Executives,
## one-on-one like a real trainer battle) and the rewards. The fighting is RocketMode.

const PATH := "res://data/rocket.json"

static var _cfg: Dictionary = {}
## The run in progress: { difficulty, round, team: [3 picks], rounds: [...] }.
## A pick is the select screen's settings for one Pokémon: { species, main, hm, evolution, shiny }.
static var run: Dictionary = {}


static func cfg(path: String, default_value: Variant = null) -> Variant:
	if _cfg.is_empty():
		_cfg = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var node: Variant = _cfg
	for key in path.split("/"):
		if node is Dictionary and (node as Dictionary).has(key):
			node = node[key]
		else:
			return default_value
	return node


static func _day(offset_days := 0) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(Town.now()) + offset_days * 86400)


static func _day_key(d: Dictionary) -> String:
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


## Open every weekend, and on a couple of weekdays each week (the same for everyone).
static func open_on(d: Dictionary) -> bool:
	var weekday := int(d["weekday"])  # 0 = Sunday.
	if weekday == 0 or weekday == 6:
		return true
	# Which weekdays this week: a fixed shuffle of Monday-Friday from the week's Monday.
	var monday_unix := int(Time.get_unix_time_from_datetime_dict(d)) - (weekday - 1) * 86400
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rocket:" + _day_key(Time.get_datetime_dict_from_unix_time(monday_unix)))
	var days := [1, 2, 3, 4, 5]
	for i in range(days.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: int = days[i]
		days[i] = days[j]
		days[j] = t
	return weekday in days.slice(0, int(cfg("weekday_days", 2)))


static func is_open() -> bool:
	return open_on(_day())


## Days until it opens next (0 = open now).
static func days_until_open() -> int:
	for i in 8:
		if open_on(_day(i)):
			return i
	return 7


## Today's opponents: three grunt teams, then two executives (the same all day).
static func line_up() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rocket_lineup:" + _day_key(_day()))
	var grunts: Array = (cfg("grunts", []) as Array).duplicate()
	var execs: Array = (cfg("executives", []) as Array).duplicate()
	var out := []
	for i in 3:
		if grunts.is_empty():
			break
		var g: Dictionary = (grunts.pop_at(rng.randi() % grunts.size()) as Dictionary).duplicate()
		g["boss"] = false
		out.append(g)
	for i in 2:
		if execs.is_empty():
			break
		var e: Dictionary = (execs.pop_at(rng.randi() % execs.size()) as Dictionary).duplicate()
		e["boss"] = true
		out.append(e)
	return out


## How many Pokémon you take in.
const TEAM_SIZE := 3


## Starts a run with your team of three (each a pick from the select screen;
## `extra` = settings shared by the run, like a drink).
static func start_run(difficulty: String, team: Array, extra: Dictionary = {}) -> Dictionary:
	run = { "difficulty": difficulty, "round": 0, "team": team.duplicate(true), "extra": extra.duplicate(), "rounds": line_up() }
	return settings_for_round()


## The trainer's Pokémon for this run's round, in the order they'd lead with:
## an Executive's ace (first in its team list) always comes out last.
static func enemy_order(r: Dictionary) -> Array:
	var team: Array = (r["team"] as Array).duplicate()
	if bool(r.get("boss", false)) and team.size() > 1:
		team.push_back(team.pop_front())
	return team


## Average profile level of your team (the Rocket Pokémon are a few levels above it).
static func team_level(team: Array) -> int:
	var total := 0
	for pick: Dictionary in team:
		total += Profile.level_of(str(pick.get("species", "")))
	return maxi(1, roundi(float(total) / maxf(1.0, team.size())))


## Match settings for the run's current round: your first pick leads (you choose
## your lead again on the field, once you've seen their team).
static func settings_for_round() -> Dictionary:
	var rounds: Array = run.get("rounds", [])
	var r: Dictionary = rounds[clampi(int(run["round"]), 0, rounds.size() - 1)]
	var team: Array = run.get("team", [])
	var s: Dictionary = (run.get("extra", {}) as Dictionary).duplicate()
	s.merge(team[0] if not team.is_empty() else {}, true)
	s["mode"] = "rocket"
	s["arena"] = str(r["arena"])
	s["enemies"] = enemy_order(r)
	s["allies"] = []
	s["difficulty"] = str(cfg("difficulties/%s/bot" % str(run["difficulty"]), "normal"))
	var d := str(run["difficulty"])
	var bonus := int(cfg("difficulties/%s/%s" % [d, "boss_level_bonus" if bool(r["boss"]) else "level_bonus"], 2))
	s["trainer"] = { "name": str(r["name"]), "stars": 3 if bool(r["boss"]) else 2, "stake": 0, "floor": 0, "class": "rocket",
		"level_bonus": bonus, "level": mini(team_level(team) + bonus, Profile.max_level()), "hp_scale": 1.0, "rocket": true }
	return s


static func round_title() -> String:
	var rounds: Array = run.get("rounds", [])
	var i := clampi(int(run.get("round", 0)), 0, maxi(0, rounds.size() - 1))
	if rounds.is_empty():
		return "TEAM ROCKET"
	var r: Dictionary = rounds[i]
	return "ROCKET HIDEOUT %d/%d  ·  %s" % [i + 1, rounds.size(), str(r["name"]).to_upper()]


## Whether you've already cleared difficulty `d` today (later runs pay less).
static func cleared_today(d: String) -> bool:
	return str(Town._save_dict("rocket_stats").get("last_" + d, "")) == Profile.today()


## Money and coins multiplier for the run's difficulty: 1 until today's first
## clear, then repeat_share (so the Hideout can't be farmed for cash).
static func pay_share(d := "") -> float:
	if d == "":
		d = str(run.get("difficulty", "normal"))
	return float(cfg("rewards/repeat_share", 0.15)) if cleared_today(d) else 1.0


## Money for winning round `i` (0-based) of the run, after the repeat cut.
static func round_money(i: int) -> int:
	return roundi(float(cfg("rewards/round_money", 150)) * (i + 1) * pay_share())


## After a full clear: pays out and returns { texts, balls }.
static func clear_rewards() -> Dictionary:
	var d := str(run.get("difficulty", "normal"))
	var c: Dictionary = cfg("rewards/clear/" + d, {})
	var texts: Array[String] = []
	var balls: Array = []
	var share := pay_share(d)
	var money := roundi(int(c.get("money", 0)) * share)
	var coins := roundi(int(c.get("coins", 0)) * share)
	Profile.data["money"] = Profile.money() + money
	Profile.data["coins"] = Town.coins() + coins
	texts.append("+%d ₽  ·  +%d coins" % [money, coins])
	if share < 1.0:
		texts.append("Repeat clear today: reduced pay, full rewards again tomorrow")
		var stats_r := Town._save_dict("rocket_stats")
		stats_r["clears_" + d] = int(stats_r.get("clears_" + d, 0)) + 1
		Profile.save()
		return { "texts": texts, "balls": balls }
	if int(c.get("candies", 0)) > 0:
		Profile._give("rare_candy", int(c["candies"]))
		texts.append("+%d Rare Candy (purified shadow energy)" % int(c["candies"]))
	for ball: String in c.get("balls", []):
		Profile._give(ball)
		balls.append(ball)
	var stats := Town._save_dict("rocket_stats")
	stats["clears_" + d] = int(stats.get("clears_" + d, 0)) + 1
	# First clear of the day at this difficulty: the next uniform piece.
	var today := Profile.today()
	if str(stats.get("last_" + d, "")) != today:
		stats["last_" + d] = today
		var piece := _next_piece(d)
		if not piece.is_empty():
			Town.unlock_item(piece[0], piece[1], piece[2])
			texts.append("NEW: %s %s!" % [str(Town.find_set(str(cfg("rewards/outfit/" + d, ""))).get("name", "")), str(Town.item(piece[0], piece[1]).get("name", ""))])
		else:
			var extra := str(cfg("rewards/complete_ball", "ultra_ball"))
			Profile._give(extra)
			balls.append(extra)
	if d == "hard" and not bool(stats.get("hard_bonus", false)):
		stats["hard_bonus"] = true
		var mb := str(cfg("rewards/first_hard_clear", "master_ball"))
		Profile._give(mb)
		balls.append(mb)
		texts.append("First Hard clear: a Master Ball!")
	Profile.save()
	return { "texts": texts, "balls": balls }


## The next uniform piece not yet earned at this difficulty: [slot, item, colour], or [].
static func _next_piece(d: String) -> Array:
	var set_id := str(cfg("rewards/outfit/" + d, "rocket_grunt"))
	var pieces := Town.set_pieces(set_id, 0)
	for slot: String in cfg("rewards/piece_order", ["hat", "top", "bottom", "shoes"]):
		for p: Array in pieces:
			if p[0] == slot and not Town.owns_item(p[0], p[1], p[2]):
				return p
	return []


static func clears() -> int:
	var stats := Town._save_dict("rocket_stats")
	return int(stats.get("clears_normal", 0)) + int(stats.get("clears_hard", 0))
