class_name TrainerLook
extends RefCounted
## Town trainers. Your own trainer is stacked from layers (tools/make_trainer_sheets.py):
## hair behind, bottoms, shoes, top, head, hair, hat, each painted in its colour,
## then dark lines where a layer sits on top of another and round the whole
## figure. Fixed looks (trainers in town, staff, Team Rocket) come ready-made in
## assets/trainers/looks/ (tools/build_outfits.py, which stacks them the same way).
## Sheets: 3 rows (facing down, up, right) x 6 frames: 2 idle (breathing), then
## 4 walking (left foot, passing, right foot, passing).

const DIR := "res://assets/trainers/"
const CELL := Vector2i(32, 40)
const FRAMES := 6
const PARTS := ["skin", "hair", "main", "trim", "dark", "white", "red", "eye", "mouth", "blush", "gold"]
const FIXED := {
	"dark": Color("#28262f"), "white": Color("#f5f5f5"), "red": Color("#dc2830"), "eye": Color("#282030"),
	"mouth": Color("#b03038"), "blush": Color("#f07878"), "gold": Color("#e1be5a"),
}
## Hats over the top of the head: the hair under them leaves its top off.
const COVERING := ["cap", "cap_back", "beanie", "sun_hat", "straw_hat", "hood", "swim_cap", "rocket_cap", "bandana"]
const CONTOUR := 0.55
const OUTLINE := 0.25

static var _sources := {}
static var _painted := {}


## Your own trainer, as dressed at the Outfitter (`outfit` overrides it: try-ons).
static func player_sheet(outfit: Dictionary = {}) -> Texture2D:
	return compose(Town.look_of(outfit if not outfit.is_empty() else Town.outfit()))


## A trainer class's look (wandering trainers, trainer cards).
static func npc_sheet(class_id: String) -> Texture2D:
	return _ready_made("class_" + class_id)


## People working in the buildings: nurse, elder, clerk, dealer, guide, stylist.
static func staff_sheet(who: String) -> Texture2D:
	return _ready_made(who)


## Team Rocket: "rocket_grunt" or "rocket_executive".
static func rocket_sheet(kind := "rocket_grunt") -> Texture2D:
	return _ready_made(kind)


static func _ready_made(id: String) -> Texture2D:
	var path := DIR + "looks/" + id + ".png"
	return load(path) if ResourceLoader.exists(path) else compose(Town.look_of(Town.default_outfit()))


## Stacks and paints a look: { skin, hair, hair_color, hat: [item, Color] or null,
## top / bottom / shoes: [item, Color] }. Cached.
static func compose(look: Dictionary) -> Texture2D:
	var key := JSON.stringify(look, "", true)
	if _painted.has(key):
		return _painted[key]
	var hat: Variant = look.get("hat")
	var hair := str(look.get("hair", "short"))
	var layers: Array = [["hairback_" + hair, null], ["bottom_" + str(look["bottom"][0]), look["bottom"][1]],
		["shoes_" + str(look["shoes"][0]), look["shoes"][1]], ["top_" + str(look["top"][0]), look["top"][1]],
		["head_girl" if str(look.get("gender", "boy")) == "girl" else "head", null],
		["hair_%s%s" % [hair, "_under" if hat is Array and str(hat[0]) in COVERING else ""], null]]
	if hat is Array:
		layers.append(["hat_" + str(hat[0]), hat[1]])
	var base := _source("head")
	if base == null:
		return null
	var w := base.get_width()
	var h := base.get_height()
	var n := w * h
	var part := PackedByteArray()
	part.resize(n)
	part.fill(255)
	var shade := PackedByteArray()
	shade.resize(n)
	var owner := PackedByteArray()
	owner.resize(n)
	for li in layers.size():
		var img := _source(str(layers[li][0]))
		if img == null:
			continue
		var data := img.get_data()
		for i in n:
			if data[i * 4 + 3] > 127:
				part[i] = roundi(data[i * 4] / 20.0)
				shade[i] = data[i * 4 + 1]
				owner[i] = li
	var colors := []  # Per layer: [main, trim].
	for layer: Array in layers:
		var c: Color = _color(layer[1]) if layer[1] != null else Color.WHITE
		colors.append([c, _trim(c)])
	var skin := _color(look.get("skin", "#fcd8b0"))
	var hair_color := _color(look.get("hair_color", "#704020"))
	var detail := [PARTS.find("eye"), PARTS.find("mouth"), PARTS.find("blush")]
	var no_line := detail + [PARTS.find("white"), PARTS.find("red")]
	var out := PackedByteArray()
	out.resize(n * 4)
	for i in n:
		var p := part[i]
		if p == 255:
			continue
		var x := i % w
		var y := i / w
		var k := shade[i] / 100.0
		if p not in detail:
			# A darker line where a layer in front starts.
			for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nx: int = x + d[0]
				var ny: int = y + d[1]
				if nx < 0 or ny < 0 or nx >= w or ny >= h or nx / CELL.x != x / CELL.x or ny / CELL.y != y / CELL.y:
					continue
				var j := ny * w + nx
				if part[j] != 255 and owner[j] > owner[i] and part[j] != p and part[j] not in no_line:
					k = CONTOUR
					break
		var name: String = PARTS[p]
		var c: Color
		match name:
			"main": c = colors[owner[i]][0]
			"trim": c = colors[owner[i]][1]
			"skin": c = skin
			"hair": c = hair_color
			_: c = FIXED.get(name, Color.MAGENTA)
		out[i * 4] = mini(255, int(c.r8 * k))
		out[i * 4 + 1] = mini(255, int(c.g8 * k))
		out[i * 4 + 2] = mini(255, int(c.b8 * k))
		out[i * 4 + 3] = 255
	# A dark outline round the figure.
	var final := out.duplicate()
	for i in n:
		if out[i * 4 + 3] != 0:
			continue
		var x := i % w
		var y := i / w
		for d in [[0, 1], [1, 0], [-1, 0], [0, -1]]:
			var nx: int = x + d[0]
			var ny: int = y + d[1]
			if nx < 0 or ny < 0 or nx >= w or ny >= h or nx / CELL.x != x / CELL.x or ny / CELL.y != y / CELL.y:
				continue
			var j := (ny * w + nx) * 4
			if out[j + 3] != 0:
				final[i * 4] = int(out[j] * OUTLINE)
				final[i * 4 + 1] = int(out[j + 1] * OUTLINE)
				final[i * 4 + 2] = int(out[j + 2] * OUTLINE)
				final[i * 4 + 3] = 255
				break
	var tex := ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, final))
	_painted[key] = tex
	return tex


static func _color(v: Variant) -> Color:
	return v if v is Color else Color.html(str(v))


## A lighter shade of an item's colour (a darker one for white or very light items).
static func _trim(c: Color) -> Color:
	return c * 0.8 if c.r + c.g + c.b > 2.35 else c.lerp(Color.WHITE, 0.35)


static func _source(layer: String) -> Image:
	if not _sources.has(layer):
		var path := DIR + layer + ".png"
		var img: Image = null
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			img = tex.get_image() if tex else null
			if img and img.is_compressed():
				img.decompress()
			if img:
				img.convert(Image.FORMAT_RGBA8)
		_sources[layer] = img
	return _sources[layer]


## One frame as its own texture (UI previews). row: 0 down, 1 up, 2 right.
static func frame(tex: Texture2D, row := 0, col := 0) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col * CELL.x, row * CELL.y, CELL.x, CELL.y)
	return a
