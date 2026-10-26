class_name SpeciesData
extends RefCounted
## One Pokémon (one evolution stage), loaded from data/brawlers/<id>.json.

var id := ""
var display_name := ""
var types: Array[String] = []
## Front view, for menus and the HUD.
var sprite: Texture2D
## Three views side by side (front, side facing right, back) for in-game; null if
## the PNG is a single image.
var sheet: Texture2D
var sprite_scale := 1.0
## Legendaries can't be picked; they show up as raid bosses and shrine guardians.
var legendary := false
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
## This stage's own super move (each evolution has a different one).
var super_move: MoveData
var raw_super := ""


static func from_dict(species_id: String, d: Dictionary) -> SpeciesData:
	var s := SpeciesData.new()
	s.id = species_id
	s.display_name = str(d.get("name", species_id.capitalize()))
	for t in d.get("types", ["normal"]):
		s.types.append(str(t))
	s.sprite_scale = float(d.get("sprite_scale", 1.0))
	s.legendary = bool(d.get("legendary", false))
	var stats: Dictionary = d.get("stats", {})
	s.hp = float(stats.get("hp", s.hp))
	s.attack = float(stats.get("attack", s.attack))
	s.defense = float(stats.get("defense", s.defense))
	s.speed = float(stats.get("speed", s.speed))
	s.evolves_to = str(d.get("evolves_to", ""))
	s.evolves_from = str(d.get("evolves_from", ""))
	s.raw_moves = d.get("moves", [])
	s.raw_super = str(d.get("super", ""))
	var sprite_path := str(d.get("sprite", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture: Texture2D = load(sprite_path)
		if texture and texture.get_width() >= texture.get_height() * 3:
			s.sheet = texture
			var front := AtlasTexture.new()
			front.atlas = texture
			front.region = Rect2(0, 0, texture.get_height(), texture.get_height())
			s.sprite = front
		else:
			s.sprite = texture
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
