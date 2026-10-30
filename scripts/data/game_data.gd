extends Node
## Autoload "GameData": loads every JSON file under res://data at startup and
## answers questions about species, moves, types and rules.
##
## Add a Pokémon by dropping a new file into data/brawlers/, a move by adding
## an entry to any file in data/moves/, and an arena by adding data/arenas/<id>.json.
## data/moves/generated.json and the brawler files are written by tools/build_roster.py.

const DATA_DIR := "res://data"

var rules: Dictionary = {}
## id -> SpeciesData
var species: Dictionary = {}
## id -> MoveData
var moves: Dictionary = {}
## id -> the raw Dictionary each move was loaded from (for scaled copies).
var move_dicts: Dictionary = {}
var _scaled_moves: Dictionary = {}
## id -> raw arena Dictionary
var arenas: Dictionary = {}
## Item pickups (data/items.json): id -> Dictionary, plus "spawn" settings.
var items: Dictionary = {}
var item_spawn: Dictionary = {}
## Play styles (data/styles.json): id -> { "label", "like", "desc" }.
var styles: Dictionary = {}
## Progression (data/economy.json, progression.json, unlocks.json): rewards and
## prices; TMs, TM supers and HMs per line; the Kanto unlock order.
var economy: Dictionary = {}
var progression: Dictionary = {}
var unlocks: Dictionary = {}
## Gym gauntlets (data/gyms.json) and the run in progress ({} = none; see GymMode).
var gyms: Dictionary = {}
var gym_run: Dictionary = {}
var stab := 1.1
## Overall type multiplier limits (after dual types multiply).
var type_range := Vector2(0.75, 1.3)
## Team whose point of view decides what's hidden in tall grass.
var local_team := 0
## Set by the menu before loading the match scene; read by main.gd. Empty = use the
## Main node's Inspector values (handy when running main.tscn straight from the editor).
var match_settings: Dictionary = {}
## The brawler the person is controlling (for blindness and the camera).
var local_player: Brawler
## Player settings (control layout, aim assist...), saved to SETTINGS_PATH.
var settings: Dictionary = {}
const SETTINGS_PATH := "user://settings.json"

var _type_colors: Dictionary = {}
## attacking type -> { defending type: multiplier }
var _chart: Dictionary = {}


const GAME_FONT := "res://assets/fonts/lilita-one.woff"


func _ready() -> void:
	_install_font()
	load_all()
	load_settings()


## Use Lilita One (chunky, Brawl Stars-like) everywhere: menus, HUD, damage numbers.
## Characters it doesn't have fall back to Godot's built-in font.
func _install_font() -> void:
	if not ResourceLoader.exists(GAME_FONT):
		return
	var font: FontFile = load(GAME_FONT)
	if font == null:
		return
	font.fallbacks = [ThemeDB.fallback_font]
	ThemeDB.fallback_font = font


func load_all() -> void:
	rules = _load_json(DATA_DIR + "/rules.json")
	_load_types(_load_json(DATA_DIR + "/types.json"))

	styles = _load_json(DATA_DIR + "/styles.json")
	economy = _load_json(DATA_DIR + "/economy.json")
	progression = _load_json(DATA_DIR + "/progression.json")
	unlocks = _load_json(DATA_DIR + "/unlocks.json")
	gyms = _load_json(DATA_DIR + "/gyms.json")
	moves.clear()
	var extras := _load_json(DATA_DIR + "/move_extras.json")
	for move_file in _json_files(DATA_DIR + "/moves"):
		var move_defs := _load_json(DATA_DIR + "/moves/" + move_file)
		for move_id: String in move_defs:
			if move_id.begins_with("_"):
				continue
			if moves.has(move_id):
				push_error("GameData: move '%s' is defined twice (%s)" % [move_id, move_file])
			move_dicts[move_id] = _with_extras(move_defs[move_id], extras)
			var move := MoveData.from_dict(move_id, move_dicts[move_id])
			_check_type(move.type, "moves/%s → %s" % [move_file, move_id])
			moves[move_id] = move

	species.clear()
	for file in _json_files(DATA_DIR + "/brawlers"):
		var species_id := file.get_basename()
		var s := SpeciesData.from_dict(species_id, _load_json(DATA_DIR + "/brawlers/" + file))
		for t in s.types:
			_check_type(t, "brawlers/%s" % file)
		if s.sprite == null:
			s.sprite = make_placeholder_sprite(type_color(s.types[0]))
		s.hp *= float(rule("hp_multiplier", 1.0))
		species[species_id] = s
	_link_species()

	arenas.clear()
	for file in _json_files(DATA_DIR + "/arenas"):
		arenas[file.get_basename()] = _load_json(DATA_DIR + "/arenas/" + file)
	_load_custom_arenas()

	var item_data := _load_json(DATA_DIR + "/items.json")
	items = item_data.get("items", {})
	item_spawn = item_data.get("spawn", {})
	for item_id: String in items:
		var path := str(items[item_id].get("sprite", ""))
		items[item_id]["texture"] = load(path) if ResourceLoader.exists(path) else null

	print("GameData: %d species, %d moves, %d arenas" % [species.size(), moves.size(), arenas.size()])


# --- Custom maps (map maker) -------------------------------------------------

## Maps made or edited in the map maker live here; a file with a built-in map's
## id replaces that map until it's reverted.
const CUSTOM_ARENA_DIR := "user://arenas"
## Ids of the built-in maps (so the map maker knows what can be reverted).
var builtin_arenas: Array[String] = []


func _load_custom_arenas() -> void:
	builtin_arenas.clear()
	for id: String in arenas:
		builtin_arenas.append(id)
	if not DirAccess.dir_exists_absolute(CUSTOM_ARENA_DIR):
		return
	for file in DirAccess.get_files_at(CUSTOM_ARENA_DIR):
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_ARENA_DIR + "/" + file))
		if parsed is Dictionary and (parsed as Dictionary).has("map"):
			arenas[file.get_basename()] = parsed


func is_custom_arena(arena_id: String) -> bool:
	return FileAccess.file_exists("%s/%s.json" % [CUSTOM_ARENA_DIR, arena_id])


func save_custom_arena(arena_id: String, def: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(CUSTOM_ARENA_DIR)
	var f := FileAccess.open("%s/%s.json" % [CUSTOM_ARENA_DIR, arena_id], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(def, "\t"))
		f.close()
	arenas[arena_id] = def


## Deletes a custom map, or puts an edited built-in map back the way it shipped.
func delete_custom_arena(arena_id: String) -> void:
	DirAccess.remove_absolute("%s/%s.json" % [CUSTOM_ARENA_DIR, arena_id])
	if arena_id in builtin_arenas:
		arenas[arena_id] = _load_json(DATA_DIR + "/arenas/" + arena_id + ".json")
	else:
		arenas.erase(arena_id)


# --- Settings --------------------------------------------------------------

func setting(key: String, default_value: Variant) -> Variant:
	return settings.get(key, default_value)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()


## Where the on-screen controls sit, as fractions of the screen (x right, y down),
## plus a size multiplier. "swapped" puts the move stick on the right.
const DEFAULT_LAYOUT := {
	"move": [0.18, 0.74], "aim": [0.82, 0.74], "gadget": [0.69, 0.86], "super": [0.67, 0.6], "hm": [0.93, 0.5],
	"scale": 1.0, "swapped": false,
}


func control_layout() -> Dictionary:
	var layout: Dictionary = DEFAULT_LAYOUT.duplicate(true)
	var saved: Variant = settings.get("layout", {})
	if saved is Dictionary:
		for key: String in saved:
			if layout.has(key):
				layout[key] = saved[key]
	return layout


func load_settings() -> void:
	settings = {}
	if FileAccess.file_exists(SETTINGS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if parsed is Dictionary:
			settings = parsed


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))


# --- Lookups ---------------------------------------------------------------

func get_species(species_id: String) -> SpeciesData:
	if not species.has(species_id):
		push_error("GameData: unknown species '%s'" % species_id)
		return null
	return species[species_id]


## data/move_extras.json adds fields to every move with a given name, by slot
## ("main", "super", "any"), so the generated move files can be rebuilt freely.
func _with_extras(d: Dictionary, extras: Dictionary) -> Dictionary:
	var by_name: Dictionary = extras.get(str(d.get("name", "")), {})
	if by_name.is_empty():
		return d
	var merged := d.duplicate(true)
	for key: String in ["any", str(d.get("slot", ""))]:
		var add: Dictionary = by_name.get(key, {})
		for field: String in add:
			merged[field] = add[field]
	return merged


func get_move(move_id: String) -> MoveData:
	return moves.get(move_id)


## A copy of a move with its power (and damage over time) multiplied by `scale`, cached.
func scaled_move(move_id: String, scale: float) -> MoveData:
	if is_equal_approx(scale, 1.0) or not move_dicts.has(move_id):
		return get_move(move_id)
	var key := "%s@%.2f" % [move_id, scale]
	if not _scaled_moves.has(key):
		var d: Dictionary = (move_dicts[move_id] as Dictionary).duplicate(true)
		d["power"] = float(d.get("power", 0.0)) * scale
		_scaled_moves[key] = MoveData.from_dict(move_id, d)
	return _scaled_moves[key]


## TM supers by type: type -> [base id] (tmsuper_fire_blast...).
func tm_supers_of_type(type_name: String) -> Array[String]:
	var result: Array[String] = []
	for tm: Dictionary in progression.get("tms", {}).values():
		var id := str(tm.get("super", ""))
		if id != "" and moves.has(id) and (moves[id] as MoveData).type == type_name:
			result.append(id)
	result.sort()
	return result


## Play style -> TM super shape.
const STYLE_SHAPES := {
	"shotgun": "burst", "brawler": "burst", "assassin": "burst", "spinner": "burst", "lasher": "burst", "stream": "burst",
	"tank_wave": "burst", "thrower": "lob", "zone": "lob", "healer": "lob", "sniper": "beam", "piercer": "beam",
}


## Reads a nested rule such as "evolution/kills_to_evolve".
func rule(path: String, default_value: Variant) -> Variant:
	var node: Variant = rules
	for key in path.split("/"):
		if not node is Dictionary or not (node as Dictionary).has(key):
			return default_value
		node = node[key]
	return node


## First-stage species: the ones you pick before a match. Pokédex order by
## default, or A-Z by name.
func base_species(alphabetical := false) -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	var ids := _sorted_ids()
	if alphabetical:
		ids.sort_custom(func(a: String, b: String) -> bool:
			return species[a].display_name.naturalnocasecmp_to(species[b].display_name) < 0)
	for id: String in ids:
		if species[id].stage == 1 and not species[id].legendary:
			result.append(species[id])
	return result


## Base form of `species_id`'s evolution line (Charizard → Charmander).
func family_root(species_id: String) -> String:
	var id := species_id
	for i in 8:
		var s: SpeciesData = species.get(id)
		if s == null or s.evolves_from == "" or not species.has(s.evolves_from):
			break
		id = s.evolves_from
	return id


## Every species ordered by evolution line (base form, then its evolutions), legendaries last.
func species_by_line() -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for base in base_species():
		_append_line(base, result)
	for id: String in _sorted_ids():
		if species[id].legendary:
			result.append(species[id])
	return result


func _append_line(s: SpeciesData, result: Array[SpeciesData]) -> void:
	result.append(s)
	for next_id in s.evolutions:
		if species.has(next_id) and species[next_id] not in result:
			_append_line(species[next_id], result)


## Display info for a play style id.
func style_info(style_id: String) -> Dictionary:
	return styles.get(style_id, { "label": style_id.capitalize(), "like": "", "desc": "" })


## A random item id, weighted by each item's "weight".
func random_item_id() -> String:
	var total := 0.0
	for item_id: String in items:
		total += float(items[item_id].get("weight", 1.0))
	var roll := randf() * total
	for item_id: String in items:
		roll -= float(items[item_id].get("weight", 1.0))
		if roll <= 0.0:
			return item_id
	return items.keys()[0] if not items.is_empty() else ""


## [base, ..., final] for the line containing `species_id` (every branch for Eevee).
func evolution_line(species_id: String) -> Array[SpeciesData]:
	var s: SpeciesData = species.get(species_id)
	if s == null:
		return []
	while s.evolves_from != "" and species.has(s.evolves_from):
		s = species[s.evolves_from]
	var line: Array[SpeciesData] = []
	_append_line(s, line)
	return line


func all_types() -> Array[String]:
	var result: Array[String] = []
	for t: String in _chart:
		result.append(t)
	return result


## Arenas that support a mode: King of the Hill needs Z tiles, Brawl Ball needs G goals,
## and an arena's optional "modes" list limits it to those modes.
func arenas_for_mode(mode: String) -> Array[String]:
	var result: Array[String] = []
	var ids: Array = arenas.keys()
	ids.sort()
	for id: String in ids:
		var allowed: Array = arenas[id].get("modes", [])
		if not allowed.is_empty() and mode not in allowed:
			continue
		var text := "".join(PackedStringArray(arenas[id].get("map", [])))
		if mode == "king_of_the_hill" and "Z" not in text:
			continue
		if mode == "brawl_ball" and "G" not in text:
			continue
		result.append(id)
	return result


## Species ids in National Pokédex order.
func _sorted_ids() -> Array:
	var ids: Array = species.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: int = species[a].dex
		var db: int = species[b].dex
		return da < db if da != db else a < b)
	return ids


func type_color(type_name: String) -> Color:
	return _type_colors.get(type_name, Color.GRAY)


## Damage multiplier of an attack type against a (possibly dual-typed) defender.
func effectiveness(attack_type: String, defender_types: Array[String]) -> float:
	var row: Dictionary = _chart.get(attack_type, {})
	var result := 1.0
	for t in defender_types:
		result *= float(row.get(t, 1.0))
	return clampf(result, type_range.x, type_range.y)


## False for lines too strong to be random bots (Mewtwo, Mew): rules.json no_bots.
func bot_allowed(species_id: String) -> bool:
	return family_root(species_id) not in (rule("no_bots", ["mewtwo", "mew"]) as Array)


## Raw chart multiplier of one type attacking another (2, 1, 0.5 or 0).
func type_matchup(attack_type: String, defender_type: String) -> float:
	return float((_chart.get(attack_type, {}) as Dictionary).get(defender_type, 1.0))


## damage = power * attack / defense * STAB * type effectiveness * crit
func calc_damage(move: MoveData, attacker: Brawler, defender: Brawler, multiplier := 1.0) -> Dictionary:
	var type_mult := effectiveness(move.type, defender.species.types)
	var stab_mult := stab if attacker.species.has_type(move.type) else 1.0
	var crit := randf() < move.crit_chance
	var crit_mult: float = rule("crit_multiplier", 1.5) if crit else 1.0
	var amount := move.power * multiplier * (attacker.get_attack() / maxf(1.0, defender.get_defense())) \
			* stab_mult * type_mult * crit_mult * float(rule("damage_scale", 1.0))
	return { "amount": amount, "effectiveness": type_mult, "crit": crit }


# --- Loading helpers -------------------------------------------------------

func _load_types(data: Dictionary) -> void:
	stab = float(data.get("stab", 1.1))
	var limits: Array = data.get("total_range", [0.0, 100.0])
	type_range = Vector2(float(limits[0]), float(limits[1]))
	var mults: Dictionary = data.get("multipliers", {})
	var categories := {
		"super_effective": float(mults.get("super_effective", 2.0)),
		"not_very_effective": float(mults.get("not_very_effective", 0.5)),
		"immune": float(mults.get("immune", 0.0)),
	}
	_type_colors.clear()
	var colors: Dictionary = data.get("colors", {})
	for t: String in colors:
		_type_colors[t] = Color.html(str(colors[t]))
	_chart.clear()
	var chart: Dictionary = data.get("chart", {})
	for attack_type: String in chart:
		var row := {}
		var entry: Dictionary = chart[attack_type]
		for category: String in categories:
			for defend_type in entry.get(category, []):
				row[str(defend_type)] = categories[category]
		_chart[attack_type] = row


func _link_species() -> void:
	for s: SpeciesData in species.values():
		for next_id in s.evolutions.duplicate():
			if not species.has(next_id):
				push_error("GameData: %s evolves_to unknown species '%s'" % [s.id, next_id])
				s.evolutions.erase(next_id)
		s.evolves_to = s.evolutions[0] if not s.evolutions.is_empty() else ""
		# Walk back to the base form for stage number and (if needed) the learnset.
		var source := s
		var guard := 0
		while source.raw_moves.is_empty() and source.evolves_from != "" and species.has(source.evolves_from) and guard < 8:
			source = species[source.evolves_from]
			guard += 1
		var base := s
		s.stage = 1
		while base.evolves_from != "" and species.has(base.evolves_from) and s.stage < 8:
			base = species[base.evolves_from]
			s.stage += 1
		for entry in source.raw_moves:
			var move_id := str(entry.get("move", ""))
			if not moves.has(move_id):
				push_error("GameData: %s learns unknown move '%s'" % [source.id, move_id])
				continue
			s.learnset.append({ "move": moves[move_id], "level": int(entry.get("level", 1)), "tm": str(entry.get("tm", "")) })
		if s.default_move("main", 99) == null:
			push_error("GameData: %s needs at least one main attack (slot \"main\")" % s.id)
		var source_gadget := s
		guard = 0
		while source_gadget.raw_gadget == "" and source_gadget.evolves_from != "" and species.has(source_gadget.evolves_from) and guard < 8:
			source_gadget = species[source_gadget.evolves_from]
			guard += 1
		s.gadget_move = moves.get(source_gadget.raw_gadget)
		if s.gadget_move == null or s.gadget_move.slot != "gadget":
			push_error("GameData: %s needs a \"gadget\" that is a move with slot \"gadget\" (got '%s')" % [s.id, source_gadget.raw_gadget])
		var super_move: MoveData = moves.get(s.raw_super)
		if super_move == null or super_move.slot != "super":
			push_error("GameData: %s needs a \"super\" that is a move with slot \"super\" (got '%s')" % [s.id, s.raw_super])
		s.super_move = super_move


func _check_type(type_name: String, where: String) -> void:
	if not _chart.has(type_name):
		push_error("GameData: unknown type '%s' in %s" % [type_name, where])


func _json_files(dir_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".json"):
			result.append(file)
	result.sort()
	return result


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: could not read %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("GameData: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("GameData: %s must contain a JSON object" % path)
		return {}
	return json.data


## Round blob in the given colour, used when a brawler JSON has no sprite yet.
static func make_placeholder_sprite(color: Color) -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(15.5, 17.5)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)
			if d <= 12.0:
				img.set_pixel(x, y, color if d < 11.0 else Color(0.15, 0.12, 0.15))
	for eye_x in [11, 19]:
		img.fill_rect(Rect2i(eye_x, 13, 2, 3), Color(0.15, 0.12, 0.15))
	return ImageTexture.create_from_image(img)
