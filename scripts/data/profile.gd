extends Node
## Autoload "Profile": the player's progress, saved on this device in
## user://profile.json (the browser's storage on the web build) and synced to
## the cloud account when signed in (see Cloud).
##
## Everything per Pokémon is per evolution line, keyed by the base form's id
## (Charmander's level, vitamins and HMs cover Charmeleon and Charizard too).
## Tuning lives in data/economy.json; the unlock order in data/unlocks.json.
##
## Dev mode (all the testing tools, everything unlocked) turns on with the dev
## code: open the game with ?dev=<code> on the end of its address, type it in
## Settings, or sign in with the dev account.

const PATH := "user://profile.json"
## SHA-256 of the dev code, so the code itself isn't sitting in the game files.
const DEV_HASH := "168914d29ce1d0347e9d2087362ba12c34b24b178917987cdea6716c043c705b"
const VERSION := 2
const BALLS := ["poke_ball", "great_ball", "ultra_ball", "master_ball"]
const HM_IDS := ["cut", "fly", "surf", "strength", "flash", "rock_smash"]
const STATS := ["hp", "attack", "defense", "speed"]

## Emitted after every save (the cloud sync listens).
signal changed

## Lines unlocked since the menu last played their reveal (not saved).
var reveals: Array[String] = []

var data: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	load_profile()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&"):
			if part.begins_with("dev="):
				try_dev_code(part.trim_prefix("dev=").uri_decode())


static func blank() -> Dictionary:
	return {
		"version": VERSION, "levels": {}, "xp": {}, "dev": false, "money": 0, "unlocked": [], "starter": "",
		"inventory": {}, "tms": [], "hms": {}, "vitamins": {}, "loadout": {},
		"stats": { "matches": 0, "wins": 0, "arena_wins": {}, "arena_mvps": {}, "raid_wins": {}, "mode_wins": {}, "boss_wins": {} },
		"milestones": [], "since_ultra": 0, "store": {}, "daily": {}, "updated": 0, "shinies": [], "hunt": {}, "dailies": {},
	}


func load_profile() -> void:
	data = blank()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			replace_data(parsed, false)


## Takes a saved profile (from disk or the cloud), filling in anything missing.
func replace_data(saved: Dictionary, save_now := true) -> void:
	var fresh := blank()
	for key: String in saved:
		fresh[key] = saved[key]
	var stats: Dictionary = blank()["stats"]
	stats.merge(fresh.get("stats", {}), true)
	fresh["stats"] = stats
	fresh["version"] = VERSION
	data = fresh
	if save_now:
		save()


func save() -> void:
	data["updated"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	changed.emit()


func reset() -> void:
	var dev := is_dev()
	data = blank()
	data["dev"] = dev
	save()


static func today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]


static func econ(path: String, default_value: Variant) -> Variant:
	var node: Variant = GameData.economy
	for key in path.split("/"):
		if not node is Dictionary or not (node as Dictionary).has(key):
			return default_value
		node = node[key]
	return node


func _dict(key: String) -> Dictionary:
	if not data.get(key) is Dictionary:
		data[key] = {}
	return data[key]


func _stat_dict(key: String) -> Dictionary:
	var stats: Dictionary = data["stats"]
	if not stats.get(key) is Dictionary:
		stats[key] = {}
	return stats[key]


# --- Unlocks -----------------------------------------------------------------

func needs_starter() -> bool:
	return not is_dev() and (data.get("unlocked", []) as Array).is_empty()


func choose_starter(family: String) -> void:
	var list: Array = [family]
	for id in GameData.unlocks.get("free", []):
		if id not in list:
			list.append(id)
	data["unlocked"] = list
	data["starter"] = family
	save()


func is_unlocked(species_id: String) -> bool:
	return is_dev() or GameData.family_root(species_id) in (data.get("unlocked", []) as Array)


func unlock(family: String) -> bool:
	var list: Array = data.get("unlocked", [])
	if family in list:
		return false
	list.append(family)
	data["unlocked"] = list
	reveals.append(family)
	return true


## How to unlock a locked line, for the select screen.
func unlock_hint(species_id: String) -> String:
	var family := GameData.family_root(species_id)
	var starters: Array = GameData.unlocks.get("starters", [])
	if family in starters:
		return "Reach trainer level %d" % next_starter_level()
	var entry := unlock_entry(family)
	if entry.has("challenge"):
		var c: Dictionary = entry["challenge"]
		return "Challenge: %s (%d/%d)" % [c["text"], challenge_progress(c), challenge_goal(c)]
	if entry.has("trainer_level"):
		return "Reach trainer level %d" % int(entry["trainer_level"])
	return "Found in Poké Balls"


func unlock_entry(family: String) -> Dictionary:
	for entry: Dictionary in GameData.unlocks.get("order", []):
		if entry["family"] == family:
			return entry
	return {}


## Trainer level that unlocks the next of the starters you didn't pick (0 = none left).
func next_starter_level() -> int:
	var waiting := 0
	for id in GameData.unlocks.get("starters", []):
		if id not in (data["unlocked"] as Array):
			waiting += 1
	var levels: Array = GameData.unlocks.get("starter_levels", [20, 40, 60])
	var index := levels.size() - waiting
	return int(levels[index]) if index >= 0 and index < levels.size() else 0


func challenge_goal(c: Dictionary) -> int:
	match str(c.get("type", "")):
		"all":
			return (c.get("parts", []) as Array).size()
		"all_unlocked":
			return _families_except(c.get("except", [])).size()
	return int(c.get("count", 1))


func _families_except(skip: Array) -> Array[String]:
	var result: Array[String] = []
	for s in GameData.base_species():
		if s.id not in skip:
			result.append(s.id)
	return result


func challenge_progress(c: Dictionary) -> int:
	var stats: Dictionary = data["stats"]
	match str(c.get("type", "")):
		"mvp":
			return int(_stat_dict("arena_mvps").get(c.get("arena", ""), 0))
		"win":
			return int(_stat_dict("arena_wins").get(c.get("arena", ""), 0))
		"raid":
			return int(_stat_dict("raid_wins").get(c.get("boss", ""), 0))
		"mode_win":
			return int(_stat_dict("mode_wins").get(c.get("mode", ""), 0))
		"wins":
			return int(stats.get("wins", 0))
		"total_level":
			return total_level()
		"gyms_hard":
			var done := 0
			for m in data.get("milestones", []):
				if str(m).begins_with("gym_"):
					done += 1
			return done
		"all_unlocked":
			var have := 0
			for family in _families_except(c.get("except", [])):
				if family in (data["unlocked"] as Array):
					have += 1
			return have
		"all":
			var done := 0
			for part: Dictionary in c.get("parts", []):
				if challenge_done(part):
					done += 1
			return done
	return 0


func challenge_done(c: Dictionary) -> bool:
	return challenge_progress(c) >= challenge_goal(c)


## Unlocks every line whose requirement is met; returns { "pokemon": [...], "challenges": n }.
func _check_unlocks() -> Dictionary:
	var found: Array[String] = []
	var challenges := 0
	if needs_starter():
		return { "pokemon": found, "challenges": 0 }
	var total := total_level()
	# The starters you didn't pick, one at each starter level.
	var waiting: Array[String] = []
	for id: String in GameData.unlocks.get("starters", []):
		if id not in (data["unlocked"] as Array):
			waiting.append(id)
	var levels: Array = GameData.unlocks.get("starter_levels", [20, 40, 60])
	var given := levels.size() - waiting.size()
	for i in range(maxi(0, given), levels.size()):
		if total >= int(levels[i]) and not waiting.is_empty() and unlock(waiting[0]):
			found.append(waiting.pop_front())
	# Repeat: unlocking one can complete "unlock everything" challenges (Mewtwo, Mew).
	var again := true
	while again:
		again = false
		for entry: Dictionary in GameData.unlocks.get("order", []):
			var family: String = entry["family"]
			if family in (data["unlocked"] as Array):
				continue
			var ready := false
			if entry.has("challenge"):
				ready = challenge_done(entry["challenge"])
				if ready:
					challenges += 1
			elif entry.has("trainer_level"):
				ready = total >= int(entry["trainer_level"])
			if ready and unlock(family):
				found.append(family)
				again = true
	return { "pokemon": found, "challenges": challenges }


## Lines that only come from Poké Balls and aren't unlocked yet.
func ball_pokemon_left() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in GameData.unlocks.get("order", []):
		if not entry.has("challenge") and not entry.has("trainer_level") and entry["family"] not in (data["unlocked"] as Array):
			result.append(entry["family"])
	return result


## A random line a Poké Ball can give (no challenge or trainer level attached), or "".
func next_ball_pokemon() -> String:
	var left := ball_pokemon_left()
	return left[rng.randi() % left.size()] if not left.is_empty() else ""


## The trainer road in level order: [{ "level", "family" ("" = a starter not
## known yet), "area", "unlocked" }] — the other starters, then one line per area.
func road() -> Array[Dictionary]:
	var unlocked: Array = data.get("unlocked", [])
	var result: Array[Dictionary] = []
	var levels: Array = GameData.unlocks.get("starter_levels", [20, 40, 60])
	var waiting: Array[String] = []
	for id: String in GameData.unlocks.get("starters", []):
		if id not in unlocked:
			waiting.append(id)
	var given := levels.size() - waiting.size()
	for i in levels.size():
		var family := ""
		if i >= given and i - given < waiting.size():
			family = waiting[i - given]
		result.append({ "level": int(levels[i]), "family": family, "area": "Starter", "unlocked": i < given })
	for entry: Dictionary in GameData.unlocks.get("order", []):
		if entry.has("trainer_level"):
			result.append({ "level": int(entry["trainer_level"]), "family": entry["family"], "area": str(entry["area"]),
					"unlocked": entry["family"] in unlocked })
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) < int(b["level"]))
	return result


# --- Levels and XP -----------------------------------------------------------

func max_level() -> int:
	return int(GameData.rule("trainer/max_level", 60))


func level_of(species_id: String) -> int:
	var levels: Dictionary = data.get("levels", {})
	return clampi(int(levels.get(GameData.family_root(species_id), 1)), 1, max_level())


func set_level(species_id: String, level: int) -> void:
	var levels: Dictionary = _dict("levels")
	levels[GameData.family_root(species_id)] = clampi(level, 1, max_level())
	_dict("xp").erase(GameData.family_root(species_id))
	save()


func set_all_levels(level: int) -> void:
	var levels := {}
	for s in GameData.base_species():
		levels[s.id] = clampi(level, 1, max_level())
	data["levels"] = levels
	data["xp"] = {}
	save()


func xp_of(species_id: String) -> int:
	return int(_dict("xp").get(GameData.family_root(species_id), 0))


## XP from `level` to the next one.
func xp_needed(level: int) -> int:
	var tiers: Array = econ("xp/level_tiers", [])
	var pick: Dictionary = {}
	for tier: Dictionary in tiers:
		if level >= int(tier["from"]):
			pick = tier
	if pick.is_empty():
		return int(econ("xp/level_base", 50)) + int(econ("xp/level_step", 10)) * level
	return int(pick["base"]) + int(pick["step"]) * (level - int(pick["from"]))


## Adds XP to a line; returns how many levels it gained. Doesn't save.
func _add_xp(family: String, amount: int) -> int:
	var level := level_of(family)
	var xp := xp_of(family) + amount
	var gained := 0
	while level < max_level() and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		gained += 1
	if level >= max_level():
		xp = 0
	_dict("levels")[family] = level
	_dict("xp")[family] = xp
	return gained


## Trainer level: every unlocked line's level added up.
func total_level() -> int:
	var total := 0
	for family in data.get("unlocked", []):
		total += level_of(family)
	return total


# --- Money and items ---------------------------------------------------------

func money() -> int:
	return int(data.get("money", 0))


func count(item: String) -> int:
	return int(_dict("inventory").get(item, 0))


func _give(item: String, amount := 1) -> void:
	var inv := _dict("inventory")
	inv[item] = int(inv.get(item, 0)) + amount
	if int(inv[item]) <= 0:
		inv.erase(item)


func item_name(item: String) -> String:
	if item.begins_with("shiny_") and GameData.species.has(item.trim_prefix("shiny_")):
		return "Shiny " + GameData.species[item.trim_prefix("shiny_")].display_name
	if item.begins_with("tm_"):
		return str(GameData.progression.get("tms", {}).get(item, {}).get("name", item))
	return str(econ("items/%s/name" % item, item.capitalize()))


func has_tm(tm_id: String) -> bool:
	return is_dev() or tm_id in (data.get("tms", []) as Array)


func _add_tm(tm_id: String) -> bool:
	var tms: Array = data.get("tms", [])
	if tm_id in tms:
		return false
	tms.append(tm_id)
	data["tms"] = tms
	return true


func missing_tms() -> Array[String]:
	var result: Array[String] = []
	for tm_id: String in GameData.progression.get("tms", {}):
		if tm_id not in (data.get("tms", []) as Array):
			result.append(tm_id)
	return result


func use_rare_candy(species_id: String) -> bool:
	var family := GameData.family_root(species_id)
	if count("rare_candy") <= 0 or level_of(family) >= max_level():
		return false
	_give("rare_candy", -1)
	_add_xp(family, xp_needed(level_of(family)) - xp_of(family))
	_check_unlocks()
	save()
	return true


# --- Moves, supers, HMs, vitamins --------------------------------------------

## Main attack variants this line can use: levelled up to, or unlocked by a TM.
func unlocked_mains(species_id: String) -> Array[String]:
	var result: Array[String] = []
	var s: SpeciesData = GameData.species.get(species_id)
	if s == null:
		return result
	var level := level_of(species_id)
	for entry in s.learnset:
		var move: MoveData = entry["move"]
		if move.slot == "main" and (is_dev() or int(entry["level"]) <= level or (str(entry["tm"]) != "" and has_tm(str(entry["tm"])))):
			result.append(move.id)
	return result


## TM supers a stage can use: those of its own types (owned or not).
func stage_tm_supers(stage_id: String) -> Array[String]:
	var result: Array[String] = []
	var s: SpeciesData = GameData.species.get(stage_id)
	if s:
		for t in s.types:
			result.append_array(GameData.tm_supers_of_type(t))
	return result


## TM supers any stage of this line could use (owned or not).
func tm_super_options(species_id: String) -> Array[String]:
	var result: Array[String] = []
	for stage in GameData.evolution_line(species_id):
		for id in stage_tm_supers(stage.id):
			if id not in result:
				result.append(id)
	return result


## Supers a stage can use: its own, any earlier stage's (Charizard can pick
## Fire Spin or Flame Charge), and TM supers the line can learn that you own.
func super_options(stage_id: String) -> Array[String]:
	var result: Array[String] = []
	var id := stage_id
	for i in 8:
		var s: SpeciesData = GameData.species.get(id)
		if s == null:
			break
		if s.super_move and s.super_move.id not in result:
			result.append(s.super_move.id)
		if s.evolves_from == "":
			break
		id = s.evolves_from
	for tm_super in stage_tm_supers(stage_id):
		if owns_tm_super(tm_super):
			result.append(tm_super)
	return result


## The super picked for a stage ("" = its own).
func chosen_super(stage_id: String) -> String:
	var pick := str(loadout(stage_id).get("super_" + stage_id, ""))
	return pick if pick in super_options(stage_id) else ""


## { stage id: super id } for every stage of the line with a pick.
func super_choices(species_id: String) -> Dictionary:
	var result := {}
	for stage in GameData.evolution_line(species_id):
		var pick := chosen_super(stage.id)
		if pick != "":
			result[stage.id] = pick
	return result


func owns_tm_super(super_id: String) -> bool:
	return has_tm("tm_" + super_id.trim_prefix("tmsuper_"))


func hm_options(species_id: String) -> Array[String]:
	var result: Array[String] = []
	for hm in GameData.progression.get("hms", {}).get(GameData.family_root(species_id), []):
		result.append(str(hm))
	return result


func learned_hms(species_id: String) -> Array[String]:
	if is_dev():
		return hm_options(species_id)
	var result: Array[String] = []
	for hm in _dict("hms").get(GameData.family_root(species_id), []):
		result.append(str(hm))
	return result


## Uses one HM item on a line (HMs teach one line each). Returns false if it can't learn it.
func teach_hm(species_id: String, hm: String) -> bool:
	var family := GameData.family_root(species_id)
	if hm not in hm_options(family) or hm in learned_hms(family) or count("hm_" + hm) <= 0:
		return false
	_give("hm_" + hm, -1)
	var list: Array = _dict("hms").get(family, [])
	list.append(hm)
	_dict("hms")[family] = list
	if loadout(family).get("hm", "") == "":
		set_loadout(family, "hm", hm)
	save()
	return true


## Vitamins given to a line ("given") and how many of each are switched on ("active").
func vitamins(species_id: String) -> Dictionary:
	var family := GameData.family_root(species_id)
	var v: Dictionary = _dict("vitamins").get(family, {})
	if v.is_empty():
		v = { "given": {}, "active": {} }
		_dict("vitamins")[family] = v
	return v


func give_vitamin(species_id: String, item: String) -> bool:
	var stat := str(econ("vitamins/items/" + item, ""))
	if stat == "" or count(item) <= 0:
		return false
	_give(item, -1)
	var v := vitamins(species_id)
	var given: Dictionary = v["given"]
	given[stat] = int(given.get(stat, 0)) + 1
	if active_vitamin_total(species_id) < int(econ("vitamins/max_active", 10)):
		var active: Dictionary = v["active"]
		active[stat] = int(active.get(stat, 0)) + 1
	save()
	return true


func active_vitamin_total(species_id: String) -> int:
	var total := 0
	for stat: String in vitamins(species_id)["active"]:
		total += int(vitamins(species_id)["active"][stat])
	return total


## Switches one vitamin of `stat` on (+1) or off (-1), within what was given and the cap.
func change_active_vitamin(species_id: String, stat: String, by: int) -> bool:
	var v := vitamins(species_id)
	var active: Dictionary = v["active"]
	var now := int(active.get(stat, 0))
	var target := now + by
	if target < 0 or target > int(v["given"].get(stat, 0)):
		return false
	if by > 0 and active_vitamin_total(species_id) >= int(econ("vitamins/max_active", 10)):
		return false
	active[stat] = target
	save()
	return true


## Stat bonuses from the active vitamins: { stat: fraction }.
static func vitamin_bonus_from(active: Dictionary) -> Dictionary:
	var per := float(econ("vitamins/per_vitamin", 0.03))
	var full := int(econ("vitamins/full_value", 5))
	var reduced := float(econ("vitamins/reduced", 0.015))
	var bonus := {}
	for stat in STATS:
		var n := int(active.get(stat, 0))
		bonus[stat] = per * mini(n, full) + reduced * maxi(0, n - full)
	return bonus


func vitamin_bonus(species_id: String) -> Dictionary:
	return vitamin_bonus_from(vitamins(species_id)["active"])


func loadout(species_id: String) -> Dictionary:
	return _dict("loadout").get(GameData.family_root(species_id), {})


func set_loadout(species_id: String, key: String, value: String) -> void:
	var family := GameData.family_root(species_id)
	var l: Dictionary = _dict("loadout").get(family, {})
	l[key] = value
	_dict("loadout")[family] = l
	save()


# --- Match rewards -------------------------------------------------------------

## Called when a match ends. `info`: species, result ("victory"/"defeat"/"draw"),
## kos, mvp, arena, mode, difficulty, raid (boss id your team won, or "").
## Returns what was earned, for the results screen.
func record_match(info: Dictionary) -> Dictionary:
	var family := GameData.family_root(str(info.get("species", "")))
	var result := str(info.get("result", "draw"))
	var won := result == "victory"
	var kos := mini(int(info.get("kos", 0)), int(econ("xp/max_kos", 10)))
	var mvp := bool(info.get("mvp", false))
	var arena := str(info.get("arena", ""))
	var stats: Dictionary = data["stats"]
	stats["matches"] = int(stats.get("matches", 0)) + 1
	var daily := _dict("daily")
	if daily.get("day", "") != today():
		daily.clear()
		daily["day"] = today()
	var first_win := won and not bool(daily.get("won", false))
	if won:
		daily["won"] = true
		stats["wins"] = int(stats.get("wins", 0)) + 1
		var aw := _stat_dict("arena_wins")
		aw[arena] = int(aw.get(arena, 0)) + 1
		var mw := _stat_dict("mode_wins")
		var mode := str(info.get("mode", ""))
		mw[mode] = int(mw.get(mode, 0)) + 1
	if mvp:
		var am := _stat_dict("arena_mvps")
		am[arena] = int(am.get(arena, 0)) + 1
	var boss := str(info.get("boss", ""))
	if boss != "":
		var bw := _stat_dict("boss_wins")
		bw[boss] = int(bw.get(boss, 0)) + 1
		var rw0 := _stat_dict("raid_wins")  # Counts for the "win the X raid" challenges too.
		rw0[boss] = int(rw0.get(boss, 0)) + 1
	var raid := str(info.get("raid", ""))
	if raid != "":
		var rw := _stat_dict("raid_wins")
		rw[raid] = int(rw.get(raid, 0)) + 1

	var xp := int(econ("xp/" + ({ "victory": "win", "defeat": "loss" }.get(result, "draw") as String), 40))
	xp += kos * int(econ("xp/per_ko", 10)) + (int(econ("xp/mvp", 25)) if mvp else 0)
	if first_win:
		xp *= int(econ("xp/first_win_multiplier", 2))
	var levels_before := level_of(family)
	var gained := _add_xp(family, xp)
	var cash := int(econ("money/" + ({ "victory": "win", "defeat": "loss" }.get(result, "draw") as String), 15)) + kos * int(econ("money/per_ko", 5))
	if boss != "":
		cash += int(econ("money/boss_win", 800))
	data["money"] = money() + cash

	var balls: Array[String] = []
	if won:
		var roll := rng.randf()
		balls.append("ultra_ball" if roll < float(econ("drops/ultra_on_win", 0.03)) else ("great_ball" if roll < float(econ("drops/ultra_on_win", 0.03)) + float(econ("drops/great_on_win", 0.2)) else "poke_ball"))
	elif rng.randf() < float(econ("drops/loss_chance", 0.35)):
		balls.append("poke_ball")
	if first_win:
		balls.append(str(econ("drops/first_win", "great_ball")))
	if raid != "":
		balls.append(str(econ("drops/raid", "ultra_ball")))
	if boss != "":
		# First win against each boss: an Ultra Ball; after that a Great Ball.
		balls.append("ultra_ball" if int(_stat_dict("boss_wins")[boss]) == 1 else "great_ball")
	var progress := {
		"matches": 1, "wins": 1 if won else 0, "kos": int(info.get("kos", 0)), "mvp": 1 if mvp else 0,
		"supers": int(info.get("supers", 0)), "final_stage": 1 if info.get("final_stage", false) else 0,
		"goals": int(info.get("goals", 0)), "mode_" + str(info.get("mode", "")): 1, "boss_win": 1 if boss != "" else 0,
	}
	if won:
		for t: String in info.get("types", []):
			progress["win_type_" + t] = 1
	var daily_done := _daily_progress(progress)
	for reward: Dictionary in daily_done["rewards"]:
		if reward.has("money"):
			cash += int(reward["money"])
		elif str(reward.get("item", "")).ends_with("_ball"):
			balls.append(str(reward["item"]))
	
	var shiny_won := _track_hunt(family, int(info.get("kos", 0)), won)
	var unlocked := _check_unlocks()
	for i in int(unlocked["challenges"]):
		balls.append(str(econ("drops/challenge", "great_ball")))
	var milestones := _check_milestones(arena if won and str(info.get("difficulty", "")) == "hard" else "")
	for i in milestones.size():
		balls.append("master_ball")
	balls = _apply_ball_luck(balls)
	for ball in balls:
		_give(ball)
	save()
	return {
		"xp": xp, "first_win": first_win, "levels": gained, "level": level_of(family), "level_before": levels_before,
		"money": cash, "balls": balls, "pokemon": unlocked["pokemon"], "milestones": milestones, "shiny": shiny_won,
		"dailies": daily_done["texts"],
	}


## Master Ball upgrades and the Ultra Ball pity timer.
func _apply_ball_luck(balls: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for ball in balls:
		var b := ball
		if b != "master_ball" and rng.randf() < float(econ("drops/master_upgrade", 0.003)):
			b = "master_ball"
		if b in ["ultra_ball", "master_ball"]:
			data["since_ultra"] = 0
		else:
			data["since_ultra"] = int(data.get("since_ultra", 0)) + 1
			if int(data["since_ultra"]) >= int(econ("drops/ultra_pity", 25)):
				b = "ultra_ball"
				data["since_ultra"] = 0
		out.append(b)
	return out


## Total-level and gym milestones not reached before; returns their names.
func _check_milestones(gym_won_on_hard: String) -> Array[String]:
	var done: Array = data.get("milestones", [])
	var new_ones: Array[String] = []
	for lvl in econ("milestones/total_levels", []):
		var key := "total_%d" % int(lvl)
		if key not in done and total_level() >= int(lvl):
			done.append(key)
			new_ones.append("Total level %d" % int(lvl))
	if gym_won_on_hard in econ("milestones/gyms", []):
		var key := "gym_" + gym_won_on_hard
		if key not in done:
			done.append(key)
			new_ones.append("Beat %s" % str(GameData.arenas.get(gym_won_on_hard, {}).get("name", gym_won_on_hard)))
	data["milestones"] = done
	return new_ones


## Opens a ball from the bag; returns [{ "item", "count", "text" }] of what was inside.
func open_ball(ball: String) -> Array[Dictionary]:
	var prizes: Array[Dictionary] = []
	if count(ball) <= 0:
		return prizes
	_give(ball, -1)
	var spec: Dictionary = econ("balls/" + ball, {})
	var cash_range: Array = spec.get("money", [0, 0])
	var cash := rng.randi_range(int(cash_range[0]), int(cash_range[1]))
	data["money"] = money() + cash
	prizes.append({ "item": "money", "count": cash, "text": "%d ₽" % cash })
	var candy: Array = spec.get("candy", [0, 0, 0])
	if rng.randf() < float(candy[0]):
		var n := rng.randi_range(int(candy[1]), int(candy[2]))
		_give("rare_candy", n)
		prizes.append({ "item": "rare_candy", "count": n, "text": "Rare Candy ×%d" % n })
	var vit: Array = spec.get("vitamin", [0, 0])
	var vitamin_count := int(vit[1]) if rng.randf() < float(vit[0]) else 0
	if vitamin_count > 0 and rng.randf() < float(spec.get("extra_vitamin", 0.0)):
		vitamin_count += 1
	var vitamin_items: Array = (econ("vitamins/items", {}) as Dictionary).keys()
	for i in vitamin_count:
		var item: String = vitamin_items[rng.randi() % vitamin_items.size()]
		_give(item)
		prizes.append({ "item": item, "count": 1, "text": item_name(item) })
	if rng.randf() < float(spec.get("hm", 0.0)):
		var hm := "hm_" + str(HM_IDS[rng.randi() % HM_IDS.size()])
		_give(hm)
		prizes.append({ "item": hm, "count": 1, "text": item_name(hm) })
	if rng.randf() < float(spec.get("shiny", 0.0)):
		var options := shiny_candidates()
		if not options.is_empty():
			var family: String = options[rng.randi() % options.size()]
			_give_shiny(family)
			prizes.append({ "item": "shiny", "count": 1, "text": "SHINY %s!" % GameData.species[family].display_name, "family": family })
	var daily_done := _daily_progress({ "open_ball": 1 })
	for reward: Dictionary in daily_done["rewards"]:
		_give_reward(reward)
	var tm_rolls := 1 if rng.randf() < float(spec.get("tm", 0.0)) else 0
	if rng.randf() < float(spec.get("pokemon", 0.0)):
		var family := next_ball_pokemon()
		if family != "" and unlock(family):
			prizes.append({ "item": "pokemon", "count": 1, "text": "NEW: " + GameData.species[family].display_name, "family": family })
		else:
			tm_rolls += 1  # Everything's unlocked: a TM instead.
	for i in tm_rolls:
		var missing := missing_tms()
		if missing.is_empty():
			data["money"] = money() + 1000
			prizes.append({ "item": "money", "count": 1000, "text": "1000 ₽ (you have every TM)" })
		else:
			var tm_id: String = missing[rng.randi() % missing.size()]
			_add_tm(tm_id)
			prizes.append({ "item": tm_id, "count": 1, "text": item_name(tm_id) })
	_check_unlocks()
	save()
	return prizes


# --- Daily challenges ---------------------------------------------------------

## Today's tasks: [{ "id", "text", "stat", "goal", "progress", "done", "reward" }].
func dailies() -> Array:
	var d := _dict("dailies")
	if d.get("day", "") != today() or not d.get("tasks") is Array:
		d["day"] = today()
		d["rerolled"] = false
		d["bonus"] = false
		d["tasks"] = []
		for i in int(econ("dailies/count", 3)):
			var t := _roll_daily(d["tasks"])
			if not t.is_empty():
				(d["tasks"] as Array).append(t)
		save()
	return d["tasks"]


func _roll_daily(taken: Array) -> Dictionary:
	var used: Array = []
	for t: Dictionary in taken:
		used.append(t["id"])
		used.append(t["stat"])
	var types: Array[String] = []
	for family in data.get("unlocked", []):
		for t: String in GameData.species[family].types:
			if t not in types:
				types.append(t)
	var pool: Array = []
	for spec: Dictionary in econ("dailies/tasks", []):
		if spec["id"] in used or spec["stat"] in used:
			continue
		if spec["id"] == "boss" and not boss_unlocked(str(GameData.rule("modes/boss_raid/bosses", {}).keys()[0])):
			continue
		if spec["id"] == "win_type" and types.is_empty():
			continue
		pool.append(spec)
	if pool.is_empty():
		return {}
	var spec: Dictionary = pool[rng.randi() % pool.size()]
	var t := spec.duplicate(true)
	if t["id"] == "win_type":
		var type_name: String = types[rng.randi() % types.size()]
		t["stat"] = "win_type_" + type_name
		t["text"] = str(t["text"]).replace("{type}", type_name.capitalize())
	t["progress"] = 0
	t["done"] = false
	return t


## Adds match (or ball) progress; returns { "rewards": [...], "texts": [...] } for tasks just finished.
func _daily_progress(progress: Dictionary) -> Dictionary:
	var rewards: Array[Dictionary] = []
	var texts: Array[String] = []
	var tasks := dailies()
	for t: Dictionary in tasks:
		if bool(t["done"]) or not progress.has(t["stat"]):
			continue
		t["progress"] = mini(int(t["goal"]), int(t["progress"]) + int(progress[t["stat"]]))
		if int(t["progress"]) >= int(t["goal"]):
			t["done"] = true
			rewards.append(t["reward"])
			texts.append("Daily ✓ %s (%s)" % [t["text"], reward_text(t["reward"])])
	var d := _dict("dailies")
	var all_done := not tasks.is_empty()
	for t: Dictionary in tasks:
		all_done = all_done and bool(t["done"])
	if all_done and not bool(d.get("bonus", false)):
		d["bonus"] = true
		var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
		d["streak"] = int(d.get("streak", 0)) + 1 if d.get("last_full", "") == yesterday else 1
		d["last_full"] = today()
		rewards.append({ "item": econ("dailies/all_done", "great_ball") })
		texts.append("All dailies done! (%s)" % item_name(str(econ("dailies/all_done", "great_ball"))))
		if int(d["streak"]) % int(econ("dailies/streak_days", 7)) == 0:
			rewards.append({ "item": econ("dailies/streak_reward", "ultra_ball") })
			texts.append("%d-day streak! (%s)" % [int(d["streak"]), item_name(str(econ("dailies/streak_reward", "ultra_ball")))])
	# Balls and money are handed out by the caller; other items go straight in the bag.
	var out: Array[Dictionary] = []
	for r in rewards:
		if r.has("money") or str(r.get("item", "")).ends_with("_ball"):
			out.append(r)
		else:
			_give_reward(r)
	return { "rewards": out, "texts": texts }


func _give_reward(r: Dictionary) -> void:
	if r.has("money"):
		data["money"] = money() + int(r["money"])
	elif r.has("item"):
		_give(str(r["item"]), int(r.get("count", 1)))


func reward_text(r: Dictionary) -> String:
	if r.has("money"):
		return "%d ₽" % int(r["money"])
	return item_name(str(r.get("item", "")))


func daily_streak() -> int:
	var d := _dict("dailies")
	var yesterday := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	return int(d.get("streak", 0)) if d.get("last_full", "") in [today(), yesterday] else 0


func can_reroll_daily() -> bool:
	dailies()
	return not bool(_dict("dailies").get("rerolled", false))


## Swaps an unfinished task for a new one (once a day).
func reroll_daily(index: int) -> bool:
	var tasks := dailies()
	if not can_reroll_daily() or index < 0 or index >= tasks.size() or bool(tasks[index]["done"]):
		return false
	var others: Array = tasks.duplicate()
	var t := _roll_daily(others)
	if t.is_empty():
		return false
	tasks[index] = t
	_dict("dailies")["rerolled"] = true
	save()
	return true


## Seconds until the dailies reset (local midnight).
static func day_seconds_left() -> int:
	var d := Time.get_time_dict_from_system()
	return 86400 - (int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"]))


# --- Boss raids ----------------------------------------------------------------

## The first boss opens at trainer level modes/boss_raid/first_level; each next one once you beat the one before.
func boss_unlocked(boss_id: String) -> bool:
	if is_dev():
		return true
	var order: Array = (GameData.rule("modes/boss_raid/bosses", {}) as Dictionary).keys()
	var i := order.find(boss_id)
	if i < 0:
		return false
	if i == 0:
		return total_level() >= int(GameData.rule("modes/boss_raid/first_level", 10))
	return boss_wins(str(order[i - 1])) > 0


func boss_wins(boss_id: String) -> int:
	return int(_stat_dict("boss_wins").get(boss_id, 0))


# --- Shinies -------------------------------------------------------------------

func has_shiny(species_id: String) -> bool:
	return is_dev() or GameData.family_root(species_id) in (data.get("shinies", []) as Array)


func _give_shiny(family: String) -> bool:
	var list: Array = data.get("shinies", [])
	if family in list:
		return false
	list.append(family)
	data["shinies"] = list
	return true


## Unlocked lines whose shiny you don't have yet.
func shiny_candidates() -> Array[String]:
	var result: Array[String] = []
	for family in data.get("unlocked", []):
		var s: SpeciesData = GameData.species.get(family)
		if s and s.shiny_sheet and family not in (data.get("shinies", []) as Array):
			result.append(str(family))
	return result


static func week_key() -> String:
	# Weeks start on Monday.
	var now := Time.get_unix_time_from_system()
	var weekday := int(Time.get_datetime_dict_from_unix_time(int(now))["weekday"])  # 0 = Sunday
	var monday := int(now) - ((weekday + 6) % 7) * 86400
	return Time.get_date_string_from_unix_time(monday)


## Seconds until the weekly hunt resets (next Monday, local midnight-ish).
static func week_seconds_left() -> int:
	var now := int(Time.get_unix_time_from_system())
	var d := Time.get_datetime_dict_from_unix_time(now)
	var weekday := int(d["weekday"])
	var into_day := int(d["hour"]) * 3600 + int(d["minute"]) * 60 + int(d["second"])
	var days_left := (8 - weekday) % 7
	if days_left == 0:
		days_left = 7
	return days_left * 86400 - into_day


## This week's shiny hunt: { "week", "family", "kos", "wins", "done" } ("" family = nothing to hunt).
func hunt() -> Dictionary:
	var h: Dictionary = _dict("hunt")
	if h.get("week", "") != week_key():
		h.clear()
		h["week"] = week_key()
		var options := shiny_candidates()
		var roll := RandomNumberGenerator.new()
		roll.seed = hash(week_key() + str(data.get("starter", "")))
		h["family"] = options[roll.randi() % options.size()] if not options.is_empty() else ""
		h["kos"] = 0
		h["wins"] = 0
		h["done"] = false
	return h


func _track_hunt(family: String, kos: int, won: bool) -> String:
	var h := hunt()
	if h["family"] != family or bool(h["done"]):
		return ""
	h["kos"] = int(h["kos"]) + kos
	if won:
		h["wins"] = int(h["wins"]) + 1
	if int(h["kos"]) >= int(econ("shiny/hunt_kos", 100)) and int(h["wins"]) >= int(econ("shiny/hunt_wins", 15)):
		h["done"] = true
		if _give_shiny(family):
			return family
	return ""


# --- Store ---------------------------------------------------------------------

func item_price(item: String) -> int:
	if item.begins_with("shiny_"):
		return int(econ("shiny/price", 15000))
	if item.begins_with("tm_"):
		var kind := str(GameData.progression.get("tms", {}).get(item, {}).get("kind", "main"))
		return int(econ("tm_prices/" + ("main" if kind == "main" else "super"), 2500))
	return int(econ("items/%s/price" % item, 1000))


func item_category(item: String) -> String:
	if item.begins_with("shiny_"):
		return "shiny"
	if item.begins_with("tm_"):
		return "tm"
	return str(econ("items/%s/category" % item, item))


## Today's six slots: [{ "item", "rarity" }], rolled once a day.
func store_slots() -> Array:
	var store := _dict("store")
	if store.get("day", "") == today() and store.get("slots") is Array:
		return store["slots"]
	var roll := RandomNumberGenerator.new()
	roll.seed = hash(today() + str(data.get("starter", "")))
	var slots: Array = []
	var missing := missing_tms()
	for slot: Dictionary in econ("store/slots", []):
		var pool: Dictionary = slot["pool"]
		var total := 0.0
		for key: String in pool:
			total += float(pool[key])
		var pick := roll.randf() * total
		var item := ""
		for key: String in pool:
			pick -= float(pool[key])
			if pick <= 0.0:
				item = key
				break
		if item == "":
			item = pool.keys()[0]
		if item == "hm":
			item = "hm_" + str(HM_IDS[roll.randi() % HM_IDS.size()])
		elif item == "tm":
			item = missing[roll.randi() % missing.size()] if not missing.is_empty() else "ultra_ball"
		if str(slot["rarity"]) == "featured" and roll.randf() < float(econ("shiny/store_chance", 0.1)):
			var options := shiny_candidates()
			if not options.is_empty():
				item = "shiny_" + options[roll.randi() % options.size()]
		slots.append({ "item": item, "rarity": slot["rarity"] })
	store.clear()
	store["day"] = today()
	store["slots"] = slots
	store["bought"] = {}
	save()
	return slots


func bought_today(category: String) -> int:
	store_slots()
	return int(_dict("store").get("bought", {}).get(category, 0))


func daily_cap(category: String) -> int:
	return int(econ("store/daily_caps/" + category, 99))


## "" if it can be bought now, else why not.
func cant_buy(item: String) -> String:
	var category := item_category(item)
	if item.begins_with("tm_") and has_tm(item):
		return "Owned"
	if item.begins_with("shiny_") and has_shiny(item.trim_prefix("shiny_")):
		return "Owned"
	if bought_today(category) >= daily_cap(category):
		return "Daily limit"
	if money() < item_price(item):
		return "Not enough ₽"
	return ""


func buy(item: String) -> bool:
	if cant_buy(item) != "":
		return false
	data["money"] = money() - item_price(item)
	var bought: Dictionary = _dict("store").get("bought", {})
	var category := item_category(item)
	bought[category] = int(bought.get(category, 0)) + 1
	_dict("store")["bought"] = bought
	if item.begins_with("tm_"):
		_add_tm(item)
	elif item.begins_with("shiny_"):
		_give_shiny(item.trim_prefix("shiny_"))
	else:
		_give(item)
	save()
	return true


# --- Dev mode --------------------------------------------------------------

func is_dev() -> bool:
	return bool(data.get("dev", false))


## Turns dev mode on if `code` is right; returns whether it was.
func try_dev_code(code: String) -> bool:
	if code.strip_edges().sha256_text() != DEV_HASH:
		return false
	data["dev"] = true
	save()
	return true


func set_dev(on: bool) -> void:
	data["dev"] = on
	save()


## Dev tools: fill the bag for testing.
func dev_grant() -> void:
	data["money"] = money() + 50000
	for ball in BALLS:
		_give(ball, 10)
	_give("rare_candy", 50)
	for item: String in econ("vitamins/items", {}):
		_give(item, 20)
	for hm in HM_IDS:
		_give("hm_" + hm, 5)
	save()
