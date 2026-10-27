class_name SpeciesData
extends RefCounted
## One Pokémon (one evolution stage), loaded from data/brawlers/<id>.json.

var id := ""
var display_name := ""
## National Pokédex number (sorting and display).
var dex := 0
var types: Array[String] = []
## Front view, for menus and the HUD (cropped close around the Pokémon).
var sprite: Texture2D
## Shiny colours: sheet and front view (null if there's no shiny art).
var shiny_sheet: Texture2D
var shiny_sprite: Texture2D
## Height of the Pokémon inside a sheet frame, in pixels (0 = unknown).
var sprite_height := 0
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
## Next stage when evolving ("" at the final stage). Branching lines (Eevee) list
## every option in `evolutions`; evolves_to is the first of them.
var evolves_to := ""
var evolutions: Array[String] = []
var evolves_from := ""
## Play style id from data/styles.json ("brawler", "sniper"...): which Brawl Stars
## archetype the attacks are modelled on.
var style := ""
## 1 for base forms, 2 for first evolutions, and so on.
var stage := 1
## [{ "move": MoveData, "level": int }]. Evolutions inherit the base form's list.
var learnset: Array[Dictionary] = []
## Raw "moves" entries from JSON, resolved by GameData once all moves are loaded.
var raw_moves: Array = []
## This stage's own super move (each evolution has a different one).
var super_move: MoveData
var raw_super := ""
## Limited-use extra (Protect, Teleport, Sitrus Berry...), shared by the whole line.
var gadget_move: MoveData
var raw_gadget := ""


static func from_dict(species_id: String, d: Dictionary) -> SpeciesData:
	var s := SpeciesData.new()
	s.id = species_id
	s.display_name = str(d.get("name", species_id.capitalize()))
	s.dex = int(d.get("dex", 0))
	for t in d.get("types", ["normal"]):
		s.types.append(str(t))
	s.sprite_scale = float(d.get("sprite_scale", 1.0))
	s.sprite_height = int(d.get("sprite_height", 0))
	s.legendary = bool(d.get("legendary", false))
	var stats: Dictionary = d.get("stats", {})
	s.hp = float(stats.get("hp", s.hp))
	s.attack = float(stats.get("attack", s.attack))
	s.defense = float(stats.get("defense", s.defense))
	s.speed = float(stats.get("speed", s.speed))
	var next: Variant = d.get("evolves_to", "")
	if next is Array:
		for option in next:
			s.evolutions.append(str(option))
	elif str(next) != "":
		s.evolutions.append(str(next))
	s.evolves_to = s.evolutions[0] if not s.evolutions.is_empty() else ""
	s.style = str(d.get("style", ""))
	s.raw_gadget = str(d.get("gadget", ""))
	s.evolves_from = str(d.get("evolves_from", ""))
	s.raw_moves = d.get("moves", [])
	s.raw_super = str(d.get("super", ""))
	var sprite_path := str(d.get("sprite", ""))
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture: Texture2D = load(sprite_path)
		if texture and texture.get_width() >= texture.get_height() * 3:
			s.sheet = texture
			s.sprite = s._front_icon(texture)
		else:
			s.sprite = texture
	# Shiny sheets live next to the normal ones: assets/brawlers/shiny/<id>.png.
	var shiny_path := sprite_path.get_base_dir() + "/shiny/" + sprite_path.get_file()
	if sprite_path != "" and s.sheet and ResourceLoader.exists(shiny_path):
		s.shiny_sheet = load(shiny_path)
		s.shiny_sprite = s._front_icon(s.shiny_sheet)
	return s


## Front view cropped to a square around the Pokémon (feet at the bottom), so
## small Pokémon don't look tiny in menus.
func _front_icon(sheet_texture: Texture2D) -> AtlasTexture:
	var frame := float(sheet_texture.get_height())
	var side := frame
	if sprite_height > 0:
		side = clampf(sprite_height + 6.0, 36.0, frame)
	var icon := AtlasTexture.new()
	icon.atlas = sheet_texture
	icon.region = Rect2((frame - side) * 0.5, frame - side, side, side)
	return icon


## Moves usable in `slot` ("main") at `level`, in unlock order.
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
