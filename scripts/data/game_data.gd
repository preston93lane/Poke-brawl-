extends Node
## Autoload "GameData": loads every JSON file under res://data at startup and
## answers questions about species, moves, types and rules.
##
## Add a Pokémon by dropping a new file into data/brawlers/, a move by adding
## an entry to data/moves.json, and an arena by adding data/arenas/<id>.json.

const DATA_DIR := "res://data"

var rules: Dictionary = {}
## id -> SpeciesData
var species: Dictionary = {}
## id -> MoveData
var moves: Dictionary = {}
## id -> raw arena Dictionary
var arenas: Dictionary = {}
var stab := 1.2
## Team whose point of view decides what's hidden in tall grass.
var local_team := 0
## Set by the menu before loading the match scene; read by main.gd. Empty = use the
## Main node's Inspector values (handy when running main.tscn straight from the editor).
var match_settings: Dictionary = {}

var _type_colors: Dictionary = {}
## attacking type -> { defending type: multiplier }
var _chart: Dictionary = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	rules = _load_json(DATA_DIR + "/rules.json")
	_load_types(_load_json(DATA_DIR + "/types.json"))

	moves.clear()
	var move_defs := _load_json(DATA_DIR + "/moves.json")
	for move_id: String in move_defs:
		if move_id.begins_with("_"):
			continue
		var move := MoveData.from_dict(move_id, move_defs[move_id])
		_check_type(move.type, "moves.json → %s" % move_id)
		moves[move_id] = move

	species.clear()
	for file in _json_files(DATA_DIR + "/brawlers"):
		var species_id := file.get_basename()
		var s := SpeciesData.from_dict(species_id, _load_json(DATA_DIR + "/brawlers/" + file))
		for t in s.types:
			_check_type(t, "brawlers/%s" % file)
		if s.sprite == null:
			s.sprite = make_placeholder_sprite(type_color(s.types[0]))
		species[species_id] = s
	_link_species()

	arenas.clear()
	for file in _json_files(DATA_DIR + "/arenas"):
		arenas[file.get_basename()] = _load_json(DATA_DIR + "/arenas/" + file)

	print("GameData: %d species, %d moves, %d arenas" % [species.size(), moves.size(), arenas.size()])


# --- Lookups ---------------------------------------------------------------

func get_species(species_id: String) -> SpeciesData:
	if not species.has(species_id):
		push_error("GameData: unknown species '%s'" % species_id)
		return null
	return species[species_id]


func get_move(move_id: String) -> MoveData:
	return moves.get(move_id)


## Reads a nested rule such as "evolution/kills_to_evolve".
func rule(path: String, default_value: Variant) -> Variant:
	var node: Variant = rules
	for key in path.split("/"):
		if not node is Dictionary or not (node as Dictionary).has(key):
			return default_value
		node = node[key]
	return node


## First-stage species, sorted by id: the ones you pick before a match.
func base_species() -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for id: String in _sorted_ids():
		if species[id].stage == 1:
			result.append(species[id])
	return result


## Every species ordered by evolution line (base form, then its evolutions).
func species_by_line() -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for base in base_species():
		var current := base
		while current:
			result.append(current)
			current = species.get(current.evolves_to)
	return result


## [base, ..., final] for the line containing `species_id`.
func evolution_line(species_id: String) -> Array[SpeciesData]:
	var s: SpeciesData = species.get(species_id)
	if s == null:
		return []
	while s.evolves_from != "" and species.has(s.evolves_from):
		s = species[s.evolves_from]
	var line: Array[SpeciesData] = []
	while s:
		line.append(s)
		s = species.get(s.evolves_to)
	return line


func all_types() -> Array[String]:
	var result: Array[String] = []
	for t: String in _chart:
		result.append(t)
	return result


## Arenas that support a mode ("king_of_the_hill" needs Z tiles).
func arenas_for_mode(mode: String) -> Array[String]:
	var result: Array[String] = []
	var ids: Array = arenas.keys()
	ids.sort()
	for id: String in ids:
		var has_zone := false
		for row in arenas[id].get("map", []):
			if "Z" in str(row):
				has_zone = true
		if mode != "king_of_the_hill" or has_zone:
			result.append(id)
	return result


func _sorted_ids() -> Array:
	var ids: Array = species.keys()
	ids.sort()
	return ids


func type_color(type_name: String) -> Color:
	return _type_colors.get(type_name, Color.GRAY)


## Damage multiplier of an attack type against a (possibly dual-typed) defender.
func effectiveness(attack_type: String, defender_types: Array[String]) -> float:
	var row: Dictionary = _chart.get(attack_type, {})
	var result := 1.0
	for t in defender_types:
		result *= float(row.get(t, 1.0))
	return result


## damage = power * attack / defense * STAB * type effectiveness * crit
func calc_damage(move: MoveData, attacker: Brawler, defender: Brawler, multiplier := 1.0) -> Dictionary:
	var type_mult := effectiveness(move.type, defender.species.types)
	var stab_mult := stab if attacker.species.has_type(move.type) else 1.0
	var crit := randf() < move.crit_chance
	var crit_mult: float = rule("crit_multiplier", 1.5) if crit else 1.0
	var amount := move.power * multiplier * (attacker.attack / maxf(1.0, defender.defense)) \
			* stab_mult * type_mult * crit_mult * float(rule("damage_scale", 1.0))
	return { "amount": amount, "effectiveness": type_mult, "crit": crit }


# --- Loading helpers -------------------------------------------------------

func _load_types(data: Dictionary) -> void:
	stab = float(data.get("stab", 1.2))
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
		if s.evolves_to != "" and not species.has(s.evolves_to):
			push_error("GameData: %s evolves_to unknown species '%s'" % [s.id, s.evolves_to])
			s.evolves_to = ""
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
			s.learnset.append({ "move": moves[move_id], "level": int(entry.get("level", 1)) })
		if s.default_move("melee", 99) == null or s.default_move("ranged", 99) == null:
			push_error("GameData: %s needs at least one melee and one ranged move" % s.id)


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
