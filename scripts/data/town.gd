class_name Town
extends RefCounted
## The town hub's buildings, as rules on top of the saved profile (Profile.data).
## Numbers come from data/town.json.
##  - Pokémon Center: energy. Every match uses a pip; rested lines earn more, tired
##    ones less (they never fight worse). Resting at the Center heals faster.
##  - Day Care: one line earns a share of the XP you win with others.
##  - Department Store: drinks (one-match boosts) and a daily TM counter.
##  - Game Corner: coins, slots, Voltorb Flip and the prize counter.
##  - Trainer Outfitter: your trainer's look in town.
##  - Trainers: wandering challengers with wagers, and the Trainer Tower.

const PATH := "res://data/town.json"

static var _cfg: Dictionary = {}
## Tests set this to move the clock (unix seconds); 0 = the real time.
static var now_override := 0.0


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


static func now() -> float:
	return now_override if now_override > 0.0 else Time.get_unix_time_from_system()


static func _save_dict(key: String) -> Dictionary:
	if not Profile.data.has(key) or not Profile.data[key] is Dictionary:
		Profile.data[key] = {}
	return Profile.data[key]


# --- Pokémon Center: energy ----------------------------------------------------

static func max_energy() -> int:
	return int(cfg("energy/max", 5))


## Energy never runs out while you have only a few lines to choose from.
static func energy_applies() -> bool:
	return (Profile.data.get("unlocked", []) as Array).size() >= int(cfg("energy/min_lines", 4))


static func in_center(family: String) -> bool:
	return family in (_save_dict("center").get("beds", []) as Array)


static func _regen_seconds(family: String) -> float:
	return float(cfg("energy/center_minutes" if in_center(family) else "energy/regen_minutes", 60)) * 60.0


## Pips (fractions included) right now, after natural recovery.
static func energy(family: String) -> float:
	family = GameData.family_root(family)
	var e: Dictionary = _save_dict("energy").get(family, {})
	if e.is_empty():
		return float(max_energy())
	var pips := float(e.get("pips", max_energy()))
	var elapsed := maxf(0.0, now() - float(e.get("at", now())))
	return minf(float(max_energy()), pips + elapsed / _regen_seconds(family))


static func _set_energy(family: String, pips: float) -> void:
	_save_dict("energy")[GameData.family_root(family)] = { "pips": clampf(pips, 0.0, float(max_energy())), "at": now() }


static func is_tired(family: String) -> bool:
	return energy_applies() and energy(family) < 1.0


## Seconds until the next whole pip (0 when full).
static func next_pip_seconds(family: String) -> int:
	var e := energy(family)
	if e >= float(max_energy()):
		return 0
	return ceili((1.0 - fmod(e, 1.0)) * _regen_seconds(family))


## Called once per match: uses a pip and returns the reward multiplier.
static func use_energy(family: String) -> float:
	family = GameData.family_root(family)
	if not energy_applies():
		return 1.0
	var e := energy(family)
	if in_center(family):
		check_out(family)
	# Everyone resting at the Center gets a pip back while you play someone else.
	for other: String in (_save_dict("center").get("beds", []) as Array):
		if other != family:
			_set_energy(other, energy(other) + 1.0)
	if e < 1.0:
		_set_energy(family, e)
		return float(cfg("energy/tired_mult", 0.5))
	_set_energy(family, e - 1.0)
	return float(cfg("energy/rested_mult", 1.5))


static func center_beds() -> Array:
	return _save_dict("center").get("beds", [])


static func check_in(family: String) -> bool:
	family = GameData.family_root(family)
	var beds: Array = _save_dict("center").get("beds", [])
	if family in beds or beds.size() >= int(cfg("energy/center_beds", 3)) or energy(family) >= float(max_energy()):
		return false
	_set_energy(family, energy(family))  # Bank what it has before the faster rate starts.
	beds.append(family)
	_save_dict("center")["beds"] = beds
	Profile.save()
	return true


static func check_out(family: String) -> void:
	family = GameData.family_root(family)
	var beds: Array = _save_dict("center").get("beds", [])
	if family in beds:
		_set_energy(family, energy(family))
		beds.erase(family)
		Profile.save()


## Nurse Joy tops a line up straight away, for heal_price per missing pip.
static func heal_price(family: String) -> int:
	return ceili(float(max_energy()) - energy(family)) * int(cfg("energy/heal_price", 150))


static func heal_now(family: String) -> bool:
	var price := heal_price(family)
	if price <= 0 or Profile.money() < price:
		return false
	Profile.data["money"] = Profile.money() - price
	check_out(family)
	_set_energy(family, float(max_energy()))
	Profile.save()
	return true


# --- Day Care ------------------------------------------------------------------

static func daycare_slots() -> int:
	return 2 if bool(_save_dict("daycare").get("second", false)) else 1


static func daycare() -> Array:
	return _save_dict("daycare").get("pokemon", [])


static func deposit(family: String) -> bool:
	family = GameData.family_root(family)
	var list := daycare()
	if family in list or list.size() >= daycare_slots() or not Profile.is_unlocked(family):
		return false
	list.append(family)
	_save_dict("daycare")["pokemon"] = list
	_save_dict("daycare")["gained_" + family] = 0
	Profile.save()
	return true


static func withdraw(family: String) -> int:
	family = GameData.family_root(family)
	var d := _save_dict("daycare")
	var list := daycare()
	list.erase(family)
	d["pokemon"] = list
	var gained := int(d.get("gained_" + family, 0))
	d.erase("gained_" + family)
	Profile.save()
	return gained


static func daycare_gained(family: String) -> int:
	return int(_save_dict("daycare").get("gained_" + GameData.family_root(family), 0))


static func buy_second_slot() -> bool:
	var price := int(cfg("daycare/second_slot_price", 5000))
	if daycare_slots() > 1 or Profile.money() < price:
		return false
	Profile.data["money"] = Profile.money() - price
	_save_dict("daycare")["second"] = true
	Profile.save()
	return true


## Gives the Day Care lines their share of `xp` earned by `played`. Returns { family: xp }.
static func share_xp(played: String, xp: int) -> Dictionary:
	var out := {}
	var share := int(round(xp * float(cfg("daycare/share", 0.4))))
	for family: String in daycare():
		if family == GameData.family_root(played) or share <= 0:
			continue
		Profile._add_xp(family, share)
		_save_dict("daycare")["gained_" + family] = daycare_gained(family) + share
		out[family] = share
	return out


# --- Department Store ------------------------------------------------------------

static func drinks() -> Dictionary:
	var out := {}
	var all: Dictionary = cfg("drinks", {})
	for id: String in all:
		if all[id] is Dictionary:
			out[id] = all[id]
	return out


static func buy_drink(id: String) -> bool:
	var d: Dictionary = drinks().get(id, {})
	if d.is_empty() or Profile.money() < int(d["price"]):
		return false
	Profile.data["money"] = Profile.money() - int(d["price"])
	Profile._give(id)
	Profile.save()
	return true


## Takes one `id` drink from the bag; false if there's none.
static func use_drink(id: String) -> bool:
	if id == "" or Profile.count(id) <= 0:
		return false
	Profile._give(id, -1)
	Profile.save()
	return true


## Today's TM counter: TMs you don't have yet, the same all day.
static func tm_counter() -> Array[String]:
	var missing := Profile.missing_tms()
	missing.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Profile.today() + "tm_counter")
	var out: Array[String] = []
	while not missing.is_empty() and out.size() < int(cfg("tm_counter/count", 3)):
		out.append(missing.pop_at(rng.randi() % missing.size()))
	return out


static func buy_tm(tm_id: String) -> bool:
	var price := int(cfg("tm_counter/price", 4000))
	if tm_id not in tm_counter() or Profile.money() < price:
		return false
	Profile.data["money"] = Profile.money() - price
	Profile._add_tm(tm_id)
	Profile.save()
	return true


# --- Game Corner -----------------------------------------------------------------

static func coins() -> int:
	return int(Profile.data.get("coins", 0))


static func _add_coins(n: int) -> void:
	Profile.data["coins"] = maxi(0, coins() + n)


static func coins_bought_today() -> int:
	var d := _save_dict("coin_buys")
	return int(d.get("n", 0)) if str(d.get("day", "")) == Profile.today() else 0


static func buy_coins() -> bool:
	var pack := int(cfg("game_corner/coin_pack", 50))
	var price := int(cfg("game_corner/pack_price", 1000))
	if Profile.money() < price or coins_bought_today() + pack > int(cfg("game_corner/buy_cap", 500)):
		return false
	Profile.data["money"] = Profile.money() - price
	_add_coins(pack)
	Profile.data["coin_buys"] = { "day": Profile.today(), "n": coins_bought_today() + pack }
	Profile.save()
	return true


## Coins for a match: a few for a win and for MVP.
static func match_coins(won: bool, mvp: bool) -> int:
	var n := (int(cfg("game_corner/win_coins", 3)) if won else 0) + (int(cfg("game_corner/mvp_coins", 2)) if mvp else 0)
	_add_coins(n)
	return n


## One pull of the slot machine. Returns { "reels": [3 symbols], "win": coins won }.
static func spin(bet: int, rng: RandomNumberGenerator = null) -> Dictionary:
	bet = clampi(bet, 1, 3)
	if coins() < bet:
		return {}
	if rng == null:
		rng = Profile.rng
	_add_coins(-bet)
	var symbols: Array = cfg("game_corner/slots/symbols", [])
	var weights: Array = cfg("game_corner/slots/weights", [])
	var total := 0
	for w in weights:
		total += int(w)
	var reels: Array[String] = []
	for i in 3:
		var roll := rng.randi() % total
		for k in symbols.size():
			roll -= int(weights[k])
			if roll < 0:
				reels.append(symbols[k])
				break
	var payout := 0
	if reels[0] == reels[1] and reels[1] == reels[2]:
		payout = int(cfg("game_corner/slots/payout/" + reels[0], 0))
	else:
		var cherries := reels.count("cherry")
		if cherries == 2:
			payout = int(cfg("game_corner/slots/cherry_two", 4))
		elif cherries == 1:
			payout = int(cfg("game_corner/slots/cherry_one", 2))
	var stats := _save_dict("corner_stats")
	stats["spins"] = int(stats.get("spins", 0)) + 1
	if payout > 0:
		_add_coins(payout * bet)
		stats["won"] = int(stats.get("won", 0)) + payout * bet
		stats["best"] = maxi(int(stats.get("best", 0)), payout * bet)
	Profile.save()
	return { "reels": reels, "win": payout * bet }


## A Voltorb Flip board for `level` (1-based): 25 values, 0 = Voltorb.
static func voltorb_board(level: int, rng: RandomNumberGenerator = null) -> Array[int]:
	var levels: Array = cfg("game_corner/voltorb_flip/levels", [])
	var l: Dictionary = levels[clampi(level - 1, 0, levels.size() - 1)]
	var board: Array[int] = []
	for i in int(l["twos"]):
		board.append(2)
	for i in int(l["threes"]):
		board.append(3)
	for i in int(l["voltorbs"]):
		board.append(0)
	while board.size() < 25:
		board.append(1)
	if rng == null:
		rng = Profile.rng
	for i in range(board.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t := board[i]
		board[i] = board[j]
		board[j] = t
	return board


## Row / column hints for a board: [{ "sum", "voltorbs" } x 5 rows, then x 5 columns].
static func voltorb_hints(board: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line in 10:
		var sum := 0
		var v := 0
		for k in 5:
			var value := board[line * 5 + k] if line < 5 else board[k * 5 + (line - 5)]
			sum += value
			if value == 0:
				v += 1
		out.append({ "sum": sum, "voltorbs": v })
	return out


static func voltorb_level() -> int:
	return clampi(int(_save_dict("corner_stats").get("vf_level", 1)), 1, (cfg("game_corner/voltorb_flip/levels", [{}]) as Array).size())


## A finished Voltorb Flip round: `coins_won` if cleared, else 0; `flipped` = tiles
## turned before a Voltorb (they set the next level).
static func finish_voltorb(cleared: bool, coins_won: int, flipped: int) -> void:
	var stats := _save_dict("corner_stats")
	var level := voltorb_level()
	if cleared:
		_add_coins(coins_won)
		stats["won"] = int(stats.get("won", 0)) + coins_won
		stats["best"] = maxi(int(stats.get("best", 0)), coins_won)
		stats["vf_level"] = level + 1
	else:
		stats["vf_level"] = clampi(flipped, 1, level)
	Profile.save()


## Walking away from a Voltorb Flip round: keep its coins, same level.
static func quit_voltorb(coins_won: int) -> void:
	var stats := _save_dict("corner_stats")
	_add_coins(coins_won)
	stats["won"] = int(stats.get("won", 0)) + coins_won
	Profile.save()


static func prizes() -> Array:
	return cfg("game_corner/prizes", [])


## Why a prize can't be taken ("" = it can).
static func prize_block(p: Dictionary) -> String:
	if coins() < int(p["coins"]):
		return "Not enough coins"
	match str(p["kind"]):
		"pokemon":
			if Profile.is_unlocked(str(p["id"])):
				return "Already yours"
		"tm":
			if Profile.missing_tms().is_empty():
				return "You have every TM"
	return ""


## Returns what was given ("" if nothing).
static func claim_prize(index: int) -> String:
	var list := prizes()
	if index < 0 or index >= list.size():
		return ""
	var p: Dictionary = list[index]
	if prize_block(p) != "":
		return ""
	_add_coins(-int(p["coins"]))
	var given := str(p["id"])
	match str(p["kind"]):
		"pokemon":
			Profile.unlock(given)
		"item":
			Profile._give(given)
		"tm":
			var missing := Profile.missing_tms()
			given = missing[Profile.rng.randi() % missing.size()]
			Profile._add_tm(given)
	Profile.save()
	return given


# --- Trainer Outfitter -----------------------------------------------------------

static func outfit() -> Dictionary:
	var o: Dictionary = (cfg("outfitter/default", {}) as Dictionary).duplicate()
	o.merge(_save_dict("outfit"), true)
	return o


## "style:<name>" or "color:<index>".
static func owns(thing: String) -> bool:
	if thing.begins_with("style:"):
		return int(cfg("outfitter/styles/" + thing.get_slice(":", 1), 1)) == 0 or thing in (Profile.data.get("outfit_owned", []) as Array)
	if thing.begins_with("color:"):
		return int(thing.get_slice(":", 1)) < int(cfg("outfitter/free_colors", 4)) or thing in (Profile.data.get("outfit_owned", []) as Array)
	return true


static func price_of(thing: String) -> int:
	if owns(thing):
		return 0
	if thing.begins_with("style:"):
		return int(cfg("outfitter/styles/" + thing.get_slice(":", 1), 0))
	return int(cfg("outfitter/color_price", 500))


static func buy_look(thing: String) -> bool:
	var price := price_of(thing)
	if price <= 0 or Profile.money() < price:
		return false
	Profile.data["money"] = Profile.money() - price
	var owned: Array = Profile.data.get("outfit_owned", [])
	owned.append(thing)
	Profile.data["outfit_owned"] = owned
	Profile.save()
	return true


## Wear `value` in `slot` (style / skin / hair / hat / top / legs / shoes), if owned.
static func wear(slot: String, value: Variant) -> bool:
	if slot == "style" and not owns("style:" + str(value)):
		return false
	if slot in ["hat", "top", "legs", "shoes"] and not owns("color:%d" % int(value)):
		return false
	_save_dict("outfit")[slot] = value
	Profile.save()
	return true


# --- Trainers: wandering challengers and the Trainer Tower -------------------------

static func trainer_slot() -> int:
	return int(now() / (float(cfg("trainers/slot_hours", 3)) * 3600.0))


static func slot_seconds_left() -> int:
	var span := float(cfg("trainers/slot_hours", 3)) * 3600.0
	return int(span - fmod(now(), span))


## The trainers in town right now. Each: { index, class, name, stars, team, mode,
## arena, level_bonus, hp_scale, difficulty, beaten, line, look }.
static func wandering() -> Array[Dictionary]:
	var slot := trainer_slot()
	var seen := _save_dict("trainers")
	if int(seen.get("slot", -1)) != slot:
		seen["slot"] = slot
		seen["beaten"] = []
	var out: Array[Dictionary] = []
	var classes: Array = (cfg("classes", {}) as Dictionary).keys()
	classes.sort()
	# A different kind of trainer each, in a fresh order every slot.
	var order := RandomNumberGenerator.new()
	order.seed = hash("trainers:%d" % slot)
	for i in range(classes.size() - 1, 0, -1):
		var j := order.randi() % (i + 1)
		var tmp: Variant = classes[i]
		classes[i] = classes[j]
		classes[j] = tmp
	for i in int(cfg("trainers/per_slot", 4)):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("trainer:%d:%d" % [slot, i])
		var class_id: String = classes[i % classes.size()]
		var weights: Array = cfg("trainers/star_weights", [50, 35, 15])
		var roll := rng.randi() % 100
		var stars := 1
		for k in weights.size():
			roll -= int(weights[k])
			if roll < 0:
				stars = k + 1
				break
		var t := make_trainer(class_id, stars, rng)
		t["index"] = i
		t["beaten"] = i in (seen.get("beaten", []) as Array)
		out.append(t)
	return out


## A trainer of `class_id` with `stars` (1-3): team, mode and arena picked with `rng`.
static func make_trainer(class_id: String, stars: int, rng: RandomNumberGenerator) -> Dictionary:
	var c: Dictionary = cfg("classes/" + class_id, {})
	var s := clampi(stars, 1, 3) - 1
	var mode := str(c.get("mode", "duel"))
	var arenas: Array = []
	var allowed := GameData.arenas_for_mode(mode)
	for a: String in c.get("arenas", []):
		if a in allowed:
			arenas.append(a)
	if arenas.is_empty():
		arenas = allowed
	var names: Array = c.get("names", ["Trainer"])
	return {
		"class": class_id, "class_name": str(c.get("name", "Trainer")), "name": str(names[rng.randi() % names.size()]),
		"stars": s + 1, "team": _team_for(c, s + 1, rng), "mode": mode, "arena": str(arenas[rng.randi() % arenas.size()]),
		"level_bonus": int((cfg("trainers/level_bonus", [0, 2, 4]) as Array)[s]),
		"hp_scale": float((cfg("trainers/hp_scale", [1.0, 1.1, 1.25]) as Array)[s]),
		"difficulty": str((cfg("trainers/difficulty", ["normal", "hard", "hard"]) as Array)[s]),
		"line": str(c.get("line", "")), "look": c.get("look", {}), "counter": bool(c.get("counter", false)),
	}


## Three Pokémon of the class's types: base forms at 1 star, middle stages at 2,
## final stages at 3 (falling back to whatever exists for that type).
static func _team_for(c: Dictionary, stars: int, rng: RandomNumberGenerator) -> Array:
	var types: Array = c.get("types", [])
	var pool: Array[String] = []
	var fallback: Array[String] = []
	for sp: SpeciesData in GameData.species.values():
		if sp.legendary or not GameData.bot_allowed(sp.id):
			continue
		if not types.is_empty() and not types.any(func(t: String) -> bool: return sp.has_type(t)):
			continue
		var final := sp.evolves_to == ""
		var want := (sp.evolves_from == "") if stars == 1 else (final if stars == 3 else (sp.evolves_from != "" or final))
		(pool if want else fallback).append(sp.id)
	pool.sort()
	fallback.sort()
	var team := []
	while team.size() < 3 and not (pool.is_empty() and fallback.is_empty()):
		var from := pool if not pool.is_empty() else fallback
		team.append(from.pop_at(rng.randi() % from.size()))
	while team.size() < 3:
		team.append("rattata")
	return team


## Types that hit `species_id` super effectively, for the Ace Trainer's counter-picks.
static func counter_team(species_id: String, stars: int, rng: RandomNumberGenerator) -> Array:
	var sp := GameData.get_species(species_id)
	var types: Array = []
	for attacker: String in GameData._type_colors:
		if GameData.effectiveness(attacker, sp.types) > 1.0:
			types.append(attacker)
	return _team_for({ "types": types }, stars, rng)


## Bets allowed against a trainer with `stars` (after a losing streak, only the smallest).
static func stakes(stars: int) -> Array:
	var all: Array = (cfg("trainers/stakes", [[0]]) as Array)[clampi(stars, 1, 3) - 1]
	var out: Array = []
	for s in all:
		if int(s) <= Profile.money() and (not cooling_off() or int(s) <= int(all[0])):
			out.append(int(s))
	return out


static func cooling_off() -> bool:
	return now() < float(_save_dict("wagers").get("cool_until", 0.0))


## Match settings for battling a trainer (a wandering one, or tower floor `floor`).
## `picks` are the menu's usual choices (your species, main...). Takes the stake now.
static func start_trainer(t: Dictionary, picks: Dictionary, stake: int, floor := 0) -> Dictionary:
	if stake > 0:
		if stake not in stakes(int(t["stars"])):
			stake = 0
		Profile.data["money"] = Profile.money() - stake
	if bool(t.get("counter", false)):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(t.get("name", "")) + str(picks.get("species", "")))
		t["team"] = counter_team(str(picks.get("species", "rattata")), int(t["stars"]), rng)
	var s := picks.duplicate()
	s["mode"] = t["mode"]
	s["arena"] = t["arena"]
	s["enemies"] = t["team"]
	s["difficulty"] = t["difficulty"]
	s["trainer"] = { "index": int(t.get("index", -1)), "name": "%s %s" % [t["class_name"], t["name"]], "stars": int(t["stars"]),
		"stake": stake, "level_bonus": int(t["level_bonus"]), "hp_scale": float(t["hp_scale"]), "floor": floor, "class": t["class"] }
	Profile.save()
	return s


## After a trainer match. Returns { "money": paid out, "text": a line for the results, "floor": next tower floor (0 = n/a) }.
static func finish_trainer(info: Dictionary, result: String) -> Dictionary:
	var stake := int(info.get("stake", 0))
	var floor := int(info.get("floor", 0))
	var out := { "money": 0, "text": "", "floor": 0 }
	var w := _save_dict("wagers")
	if result == "victory":
		var bonus := int(cfg("trainers/bonus_per_star", 100)) * int(info.get("stars", 1)) if floor == 0 else 0
		var paid := stake * 2 + bonus
		out["money"] = paid
		w["streak"] = 0
		w["won"] = int(w.get("won", 0)) + 1
		if floor == 0:
			var seen := _save_dict("trainers")
			var beaten: Array = seen.get("beaten", [])
			if int(info.get("index", -1)) not in beaten:
				beaten.append(int(info.get("index", -1)))
			seen["beaten"] = beaten
			var cards := _save_dict("trainer_cards")
			var cls := str(info.get("class", ""))
			cards[cls] = int(cards.get(cls, 0)) + 1
			out["text"] = "Beat %s!%s" % [info.get("name", ""), "  +%d ₽" % paid if paid > 0 else ""]
		else:
			var tower := tower_reward(floor)
			out["money"] = paid + int(tower["money"])
			out["text"] = str(tower["text"])
			out["floor"] = floor + 1
	elif result == "defeat":
		if stake > 0:
			w["streak"] = int(w.get("streak", 0)) + 1
			if int(w["streak"]) >= int(cfg("trainers/loss_streak", 3)):
				w["cool_until"] = now() + float(cfg("trainers/cooloff_minutes", 120)) * 60.0
				w["streak"] = 0
		w["lost"] = int(w.get("lost", 0)) + 1
		out["text"] = "Lost to %s%s" % [info.get("name", ""), "  -%d ₽" % stake if stake > 0 else ""]
		if floor > 0:
			out["floor"] = tower_checkpoint(floor)
			_save_dict("tower")["floor"] = out["floor"]
			out["text"] = "Back to floor %d" % out["floor"]
	else:
		out["money"] = stake
		out["text"] = "A draw: your bet is returned"
		out["floor"] = floor
	Profile.data["money"] = Profile.money() + int(out["money"])
	Profile.save()
	return out


static func trainer_record() -> Dictionary:
	var w := _save_dict("wagers")
	return { "won": int(w.get("won", 0)), "lost": int(w.get("lost", 0)), "cards": _save_dict("trainer_cards") }


static func tower_floor() -> int:
	return maxi(1, int(_save_dict("tower").get("floor", 1)))


static func tower_best() -> int:
	return int(_save_dict("tower").get("best", 0))


static func tower_checkpoint(floor: int) -> int:
	var every := int(cfg("tower/checkpoint", 5))
	return (floor - 1) / every * every + 1


## The trainer on tower floor `floor`: classes take turns, it gets tougher every
## floor, and every ace_every floors an Ace Trainer.
static func tower_trainer(floor: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tower:%d" % floor)
	var classes: Array = (cfg("classes", {}) as Dictionary).keys()
	classes.sort()
	classes.erase("cooltrainer")
	var ace := floor % int(cfg("tower/ace_every", 5)) == 0
	var class_id: String = "cooltrainer" if ace else classes[(floor - 1) % classes.size()]
	var stars := clampi(1 + floor / 7, 1, 3)
	var t := make_trainer(class_id, stars, rng)
	t["level_bonus"] = mini(floor / 3, 10)
	t["hp_scale"] = minf(1.0 + 0.03 * floor, 1.6)
	t["difficulty"] = "hard" if floor >= 4 else "normal"
	t["index"] = -1
	t["floor"] = floor
	return t


## First clear of a floor pays money (and a ball on some floors); repeats pay nothing.
static func tower_reward(floor: int) -> Dictionary:
	var tower := _save_dict("tower")
	var text := "Floor %d cleared!" % floor
	var money := 0
	tower["floor"] = floor + 1
	if floor > tower_best():
		tower["best"] = floor
		money = int(cfg("tower/money_base", 40)) + int(cfg("tower/money_step", 10)) * floor
		text += "  +%d ₽" % money
		var ball := str(cfg("tower/ball_floors/%d" % floor, ""))
		if ball != "":
			Profile._give(ball)
			text += "  +1 %s" % Profile.item_name(ball)
	return { "money": money, "text": text }
