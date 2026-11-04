class_name TownWorld
extends Node3D
## The walkable town hub (data/town_map.json, laid out by tools/build_town_map.py):
## the ground, trees and fountain come from the arena builder; on top go the
## buildings, your trainer, your partner Pokémon and the wandering trainers.
## Walk up to a door (or a trainer) and the town view offers ENTER (or TALK);
## walking on into a door goes straight in.

signal prompt_changed(text: String)
signal enter_requested(building: String)
signal talk_requested(trainer: Dictionary)

const PITCH := 52.0
const MAP_PATH := "res://data/town_map.json"
const DOOR_RANGE := 1.3
const TALK_RANGE := 1.9

## The door you last went through (you come back out of it).
static var last_door := ""

var map_def: Dictionary = {}
var arena: Arena
var player: TownWalker
var partner: TownWalker
var camera: FollowCamera
var doors := {}  # building id -> world position just outside the door
var trainers: Array = []  # [{ "walker": TownWalker, "data": Dictionary }]
var _prompt := ""
var _target: Variant = null  # building id (String) or trainer Dictionary
var _push_time := 0.0
var _busy := false
var _keys_were_down := false


func _ready() -> void:
	map_def = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	_environment()
	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	GameData.arenas["_town"] = map_def
	arena.build("_town", PITCH, "town")
	GameData.arenas.erase("_town")
	_buildings()
	_fountain()
	_people()
	camera = FollowCamera.new()
	camera.pitch_degrees = PITCH
	camera.distance = 21.0
	camera.lead = 0.0
	camera.fov = 40.0
	var half := arena.world_size() * 0.5
	camera.follow_limits = Rect2(-half.x + 9.0, -half.y + 5.5, maxf(0.0, half.x * 2.0 - 18.0), maxf(0.0, half.y * 2.0 - 10.0))
	camera.field_half = 1000.0
	add_child(camera)
	camera.target = player
	camera.make_current()
	camera.snap_to_target()


func _environment() -> void:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.55, 0.9)
	sky_mat.sky_horizon_color = Color(0.74, 0.85, 0.96)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.9)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.transform = Transform3D(Basis(Vector3(0.8192, -0.4698, 0.329), Vector3(0, 0.5736, 0.8192), Vector3(-0.5736, -0.671, 0.4698)), Vector3(0, 10, 0))
	sun.light_color = Color(1, 0.96, 0.88)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)


func _cell_pos(x: float, y: float) -> Vector3:
	return Vector3((x - arena.width * 0.5) * Arena.TILE, 0, (y - arena.height * 0.5) * Arena.TILE)


func _buildings() -> void:
	for b: Dictionary in map_def.get("buildings", []):
		var id := str(b["id"])
		var w := int(b["w"])
		var h := int(b["h"])
		var center := _cell_pos(float(b["x"]) + w * 0.5, float(b["y"]) + h * 0.5)
		var node := TownBuildings.build(id, w, h)
		node.position = center
		add_child(node)
		var body := StaticBody3D.new()
		body.collision_layer = Arena.WORLD_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w * Arena.TILE - 0.3, 3.0, h * Arena.TILE - 0.3)
		shape.shape = box
		shape.position = center + Vector3(0, 1.5, 0)
		body.add_child(shape)
		add_child(body)
		doors[id] = center + TownBuildings.door_offset(h)
		if _has_news(id):
			var mark := Label3D.new()
			mark.text = "!"
			mark.font_size = 140
			mark.pixel_size = 0.01
			mark.modulate = Color(1, 0.3, 0.3)
			mark.outline_size = 24
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.position = center + Vector3(0, 4.6 if id != "dept" else 6.6, 0)
			add_child(mark)
			var t := mark.create_tween().set_loops()
			t.tween_property(mark, "position:y", mark.position.y + 0.35, 0.5).set_trans(Tween.TRANS_SINE)
			t.tween_property(mark, "position:y", mark.position.y, 0.5).set_trans(Tween.TRANS_SINE)


## Something new inside: fresh store stock, a Pokémon fully rested at the Center.
func _has_news(id: String) -> bool:
	match id:
		"mart":
			return Profile.has_news("store")
		"center":
			for f: String in Town.center_beds():
				if Town.energy(f) >= Town.max_energy():
					return true
		"arena":
			return Profile.has_news("challenges")
	return false


func _fountain() -> void:
	var plaza: Array = map_def.get("plaza", [18, 14])
	var f := TownBuildings.fountain()
	f.position = _cell_pos(float(plaza[0]), float(plaza[1]))
	add_child(f)


func _people() -> void:
	var plaza: Array = map_def.get("plaza", [18, 14])
	var start := _cell_pos(float(plaza[0]), float(plaza[1]) + 3.5)
	if doors.has(last_door):
		start = doors[last_door] + Vector3(0, 0, 0.6)
	player = TownWalker.trainer(TrainerLook.player_sheet(), PITCH)
	player.name = "Player"
	player.position = start
	add_child(player)
	# Your partner: the Pokémon you played last (or your favourite).
	var partner_id := str(GameData.match_settings.get("species", ""))
	if not GameData.species.has(partner_id) or not Profile.is_unlocked(partner_id):
		partner_id = Profile.favourite_family()
	if not GameData.species.has(partner_id):
		partner_id = str(Profile.data.get("starter", "pikachu"))
	if GameData.species.has(partner_id) and not (GameData.species[partner_id] as SpeciesData).pmd.is_empty():
		partner = TownWalker.pokemon(GameData.species[partner_id], PITCH)
		partner.follow = player
		partner.position = start + Vector3(-0.9, 0, 0.6)
		add_child(partner)
	# Wandering trainers stand around town (the ones you've beaten have gone home).
	var spots: Array = map_def.get("trainer_spots", [])
	var i := 0
	for t: Dictionary in Town.wandering():
		if bool(t["beaten"]) or i >= spots.size():
			i += 1
			continue
		var w := TownWalker.trainer(TrainerLook.npc_sheet(t["look"], str(t["name"])), PITCH)
		w.position = _cell_pos(float(spots[i][0]) + 0.5, float(spots[i][1]) + 0.5)
		w.facing = Vector3(0, 0, 1)
		w.collision_layer = Arena.WORLD_LAYER
		add_child(w)
		var tag := Label3D.new()
		tag.text = "%s\n%s" % [t["class_name"], "★".repeat(int(t["stars"]))]
		tag.font_size = 40
		tag.pixel_size = 0.01
		tag.outline_size = 12
		tag.modulate = Color(1, 0.92, 0.5)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 2.15, 0)
		w.add_child(tag)
		trainers.append({ "walker": w, "data": t })
		i += 1


func _process(delta: float) -> void:
	if player == null:
		return
	# Keyboard too (arrows / WASD), on top of the on-screen stick.
	var keys := Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)))
	if keys != Vector2.ZERO:
		player.move_input = keys.normalized()
	elif _keys_were_down:
		player.move_input = Vector2.ZERO
	_keys_were_down = keys != Vector2.ZERO
	# The see-through shaders fade trees and rocks in front of your trainer.
	RenderingServer.global_shader_parameter_set("player_xray", player.global_position + Vector3(0, 0.05, 0))
	RenderingServer.global_shader_parameter_set("player_xray_size", Vector2(0.4, 1.5))
	_update_prompt(delta)


func _update_prompt(delta: float) -> void:
	var best: Variant = null
	var text := ""
	var best_d := INF
	for id: String in doors:
		var d := (doors[id] as Vector3).distance_to(player.global_position)
		if d < DOOR_RANGE and d < best_d:
			best_d = d
			best = id
			text = "ENTER " + str(TownScreens.BUILDINGS[id]["title"])
	for entry: Dictionary in trainers:
		var w: TownWalker = entry["walker"]
		var d := w.global_position.distance_to(player.global_position)
		if d < 4.0:
			w.look_toward(player.global_position)
		if d < TALK_RANGE and d < best_d:
			best_d = d
			best = entry["data"]
			text = "TALK TO %s" % str(entry["data"]["class_name"]).to_upper()
	_target = best
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
	# Walking on into a door goes in, like the handheld games.
	if best is String and player.move_input.y < -0.5:
		_push_time += delta
		if _push_time > 0.2:
			_push_time = 0.0
			interact()
	else:
		_push_time = 0.0


## ENTER / TALK: whatever you're standing next to.
func interact() -> void:
	if _busy or _target == null:
		return
	_busy = true
	if _target is String:
		last_door = _target
		enter_requested.emit(_target)
	else:
		talk_requested.emit(_target)
	await get_tree().create_timer(0.3).timeout
	_busy = false
