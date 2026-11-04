class_name TrainerLook
extends RefCounted
## Paints the town trainer sheets (tools/make_trainer_sheets.py) in an outfit's
## colours. A sheet's red channel says which part a pixel is (PARTS order) and
## green how lit it is (100 = the plain colour). Painted sheets are cached.
## Sheets: 3 rows (facing down, up, right) x 3 frames (stand, left foot, right foot).

const DIR := "res://assets/trainers/"
const CELL := Vector2i(24, 32)
const PARTS := ["skin", "hair", "hat", "top", "trim", "legs", "shoes", "eye", "mouth", "white", "blush"]
const FIXED := { "eye": Color(0.16, 0.13, 0.19), "mouth": Color(0.69, 0.19, 0.22), "white": Color(0.97, 0.97, 0.97), "blush": Color(0.94, 0.47, 0.47) }

static var _sources := {}
static var _painted := {}


## Colours for every part from an outfit (indices into data/town.json's outfitter lists).
static func colors_of(outfit: Dictionary) -> Dictionary:
	var pick := func(list_name: String, i: Variant) -> Color:
		if i is Color:
			return i
		var list: Array = Town.cfg("outfitter/" + list_name, ["#ffffff"])
		return Color.html(str(list[clampi(int(i), 0, list.size() - 1)]))
	var c := {
		"skin": pick.call("skins", outfit.get("skin", 0)),
		"hair": pick.call("hair", outfit.get("hair", 0)),
		"hat": pick.call("colors", outfit.get("hat", 0)),
		"top": pick.call("colors", outfit.get("top", 1)),
		"legs": pick.call("colors", outfit.get("legs", 9)),
		"shoes": pick.call("colors", outfit.get("shoes", 0)),
	}
	c["trim"] = (c["hat"] as Color).lightened(0.25)
	return c


## Your own trainer, as dressed at the Outfitter.
static func player_sheet() -> Texture2D:
	var o := Town.outfit()
	return sheet(str(o.get("style", "cap")), colors_of(o))


## A wandering trainer: their class's clothes, skin and hair picked from their name.
static func npc_sheet(look: Dictionary, seed_text: String) -> Texture2D:
	var o := look.duplicate()
	var h := absi(hash(seed_text))
	if not o.has("skin"):
		o["skin"] = h % (Town.cfg("outfitter/skins", [0]) as Array).size()
	if not o.has("hair"):
		o["hair"] = (h / 7) % (Town.cfg("outfitter/hair", [0]) as Array).size()
	if not o.has("shoes"):
		o["shoes"] = (h / 13) % 4
	return sheet(str(o.get("style", "cap")), colors_of(o))


## People working in the buildings.
static func staff_sheet(who: String) -> Texture2D:
	match who:
		"nurse":
			return sheet("nurse", colors_of({ "skin": 0, "hair": Color(0.96, 0.55, 0.7), "top": Color(0.98, 0.72, 0.8),
				"hat": Color(0.98, 0.72, 0.8), "legs": Color(0.98, 0.98, 0.98), "shoes": Color(0.97, 0.97, 0.97) }))
		"elder":
			return sheet("elder", colors_of({ "skin": 1, "hair": Color(0.85, 0.85, 0.88), "top": Color(0.55, 0.42, 0.3),
				"hat": Color(0.4, 0.3, 0.2), "legs": Color(0.3, 0.28, 0.25), "shoes": 10 }))
		"clerk":
			return sheet("cap", colors_of({ "skin": 2, "hair": 0, "top": Color(0.2, 0.45, 0.85), "hat": Color(0.2, 0.45, 0.85),
				"legs": 10, "shoes": 10 }))
		"dealer":
			return sheet("short", colors_of({ "skin": 1, "hair": 4, "top": Color(0.12, 0.12, 0.16), "hat": Color(0.85, 0.15, 0.2),
				"legs": 10, "shoes": 10 }))
		"guide":
			return sheet("bun", colors_of({ "skin": 3, "hair": 6, "top": Color(0.55, 0.3, 0.6), "hat": Color(0.9, 0.75, 0.3),
				"legs": 9, "shoes": 10 }))
		"stylist":
			return sheet("long", colors_of({ "skin": 0, "hair": 3, "top": Color(0.95, 0.45, 0.65), "hat": Color(0.3, 0.75, 0.75),
				"legs": 10, "shoes": 0 }))
		_:
			return sheet("short", colors_of({}))


static func sheet(style: String, colors: Dictionary) -> Texture2D:
	var key := style
	for part: String in ["skin", "hair", "hat", "top", "trim", "legs", "shoes"]:
		key += ":" + (colors.get(part, Color.WHITE) as Color).to_html(false)
	if _painted.has(key):
		return _painted[key]
	var src := _source(style)
	if src == null:
		return null
	var img := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
	for y in src.get_height():
		for x in src.get_width():
			var p := src.get_pixel(x, y)
			if p.a < 0.5:
				continue
			var part: String = PARTS[clampi(roundi(p.r8 / 20.0), 0, PARTS.size() - 1)]
			var base: Color = FIXED[part] if FIXED.has(part) else colors.get(part, Color.WHITE)
			var k := p.g8 / 100.0
			img.set_pixel(x, y, Color(minf(1.0, base.r * k), minf(1.0, base.g * k), minf(1.0, base.b * k), 1.0))
	var tex := ImageTexture.create_from_image(img)
	_painted[key] = tex
	return tex


static func _source(style: String) -> Image:
	if not _sources.has(style):
		var tex := load(DIR + style + ".png") as Texture2D
		var img := tex.get_image() if tex else null
		if img and img.is_compressed():
			img.decompress()
		if img:
			img.convert(Image.FORMAT_RGBA8)
		_sources[style] = img
	return _sources[style]


## One frame as its own texture (UI previews). row: 0 down, 1 up, 2 right.
static func frame(tex: Texture2D, row := 0, col := 0) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col * CELL.x, row * CELL.y, CELL.x, CELL.y)
	return a
