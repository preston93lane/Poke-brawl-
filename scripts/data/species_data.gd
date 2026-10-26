class_name SpeciesData
extends RefCounted
## One Pokémon (one evolution stage), loaded from data/brawlers/<id>.json.

var id := ""
var display_name := ""
var types: Array[String] = []
var sprite: Texture2D
var sprite_scale := 1.0
var hp := 3000.0
var attack := 100.0
var defense := 100.0
var speed := 100.0
var evolves_to := ""
var evolves_from := ""
## 1 for base forms, 2 for first evolutions, and so on.
var stage := 1
## [{ "move": MoveData, "level": int }]. Evolutions inherit the base form's list.
var learnset: Array[Dictionary] = []
## Raw "moves" entries from JSON, resolved by GameData once all moves are loaded.
var raw_moves: Array = []


static func from_dict(species_id: String, d: Dictionary) -> SpeciesData:
	var s := SpeciesData.new()
	s.id = species_id
	s.display_name = str(d.get("name", species_id.capitalize()))
	for t in d.get("types", ["normal"]):
		s.types.append(str(t))
	s.sprite_scale = float(d.get("sprite_scale", 1.0))
	var stats: Dictionary = d.get("stats", {})
	s.hp = float(stats.get("hp", s.hp))
	s.attack = float(stats.get("attack", s.attack))
	s.defense = float(stats.get("defense", s.defense))
	s.speed = float(stats.get("speed", s.speed))
	s.evolves_to = str(d.get("evolves_to", ""))
	s.evolves_from = str(d.get("evolves_from", ""))
	s.raw_moves = d.get("moves", [])
	var sprite_path := str(d.get("sprite", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		s.sprite = load(sprite_path)
	return s


## Moves usable in `slot` ("melee"/"ranged") at `level`, in unlock order.
func moves_for(slot: String, level: int) -> Array[MoveData]:
	var result: Array[MoveData] = []
	for entry in learnset:
		var move: MoveData = entry["move"]
		if move.slot == slot and int(entry["level"]) <= level:
			result.append(move)
	return result


## Newest move unlocked for the slot, or null if none.
func default_move(slot: String, level: int) -> MoveData:
	var options := moves_for(slot, level)
	return options.back() if not options.is_empty() else null


## Level at which this species can first use `move` (0 if it can't learn it).
func unlock_level(move: MoveData) -> int:
	for entry in learnset:
		if entry["move"] == move:
			return int(entry["level"])
	return 0


func has_type(type_name: String) -> bool:
	return type_name in types
