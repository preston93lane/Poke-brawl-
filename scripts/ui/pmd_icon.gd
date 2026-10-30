class_name PmdIcon
extends Control
## A menu Pokémon that's alive: loops its idle animation (the PMD sheets the
## battles use), facing the player, and does its attack animation when tapped or
## every so often. Falls back to the still sprite when it has no animations.

var species: SpeciesData
var shiny := false

var _anim := "idle"
var _time := 0.0
var _next_flourish := 0.0
var _textures := {}


static func make(s: SpeciesData, px: float, shiny_colours := false) -> PmdIcon:
	var icon := PmdIcon.new()
	icon.species = s
	icon.shiny = shiny_colours
	icon.custom_minimum_size = Vector2(px, px)
	return icon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Each one starts at a different point so a row of them doesn't move in step.
	_time = randf() * 2.0
	_next_flourish = randf_range(4.0, 12.0)


func _process(delta: float) -> void:
	if species == null or species.pmd.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	_next_flourish -= delta
	if _anim == "idle" and _next_flourish <= 0.0:
		_play("attack" if randf() < 0.5 else "shoot")
	elif _anim != "idle" and _time >= _length(_anim):
		_anim = "idle"
		_time = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and _anim == "idle":
		_play("attack")


func _play(anim: String) -> void:
	if not species.pmd.has(anim):
		anim = "idle"
	_anim = anim
	_time = 0.0
	_next_flourish = randf_range(6.0, 14.0)


func _length(anim: String) -> float:
	var total := 0.0
	for d in (species.pmd.get(anim, species.pmd["walk"]) as Dictionary)["durations"]:
		total += float(d)
	return maxf(total, 0.05)


func _texture(anim: String) -> Texture2D:
	if not _textures.has(anim):
		_textures[anim] = species.pmd_texture(anim, shiny)
	return _textures[anim]


func _draw() -> void:
	if species == null:
		return
	if species.pmd.is_empty():
		var still := species.shiny_sprite if shiny and species.shiny_sprite else species.sprite
		if still:
			draw_texture_rect(still, Rect2(Vector2.ZERO, size), false)
		return
	var anim := _anim if species.pmd.has(_anim) else "walk"
	var a: Dictionary = species.pmd[anim]
	var tex := _texture(anim)
	if tex == null:
		return
	var durations: Array = a["durations"]
	var t := fmod(_time, _length(anim))
	var col := 0
	var acc := 0.0
	for i in durations.size():
		acc += float(durations[i])
		if t < acc:
			col = i
			break
	col = mini(col, int(a["cols"]) - 1)
	var fw := float(a["fw"])
	var fh := float(a["fh"])
	var walk: Dictionary = species.pmd["walk"]
	# Same scale for every animation (the walk frame's Pokémon fills the box), and
	# every frame shares its centre, so feet stay put when the animation changes.
	var body := float(walk.get("height", float(walk["fh"]) * 0.6))
	var scale_px := size.y * 0.82 / maxf(body, 16.0)
	var feet := float(walk.get("feet", float(walk["fh"]) * 0.5 - float(walk["ground"])))
	var centre := Vector2(size.x * 0.5, size.y - 2.0 - feet * scale_px)
	var dest := Rect2(centre - Vector2(fw, fh) * scale_px * 0.5, Vector2(fw, fh) * scale_px)
	draw_texture_rect_region(tex, dest, Rect2(col * fw, 0, fw, fh))
