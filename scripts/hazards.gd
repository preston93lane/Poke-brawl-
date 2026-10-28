class_name Hazards
extends Node3D
## Arena hazards, added by main.gd after the arena is built:
## - Fire vents (F tiles): glow, then erupt in flames for a moment. Fire types are immune.
## - Warp pads (O tiles): step on one to come out of the pad mirrored across the map.
## - Lightning (map "weather": "lightning"): warning circles appear near Pokémon,
##   then a bolt strikes. Electric and Ground types are immune.
## Tuning lives under "hazards" in data/rules.json.

var main: Node
var arena: Arena

var _vents: Array[Dictionary] = []  # { pos, phase, disk, mat, hit }
var _vent_time := 0.0
var _warp_partner := {}  # Vector2i -> Vector2i
var _warp_ready := {}  # Brawler instance id -> time it may warp again
var _strikes: Array[Dictionary] = []  # { pos, left, disk, mat }
var _strike_timer := 0.0
var _clock := 0.0


func setup(p_main: Node, p_arena: Arena) -> void:
	main = p_main
	arena = p_arena
	for cell in arena.vent_cells:
		_add_vent(cell)
	_pair_warps()
	for cell: Vector2i in _warp_partner:
		_add_pad(cell)
	_strike_timer = float(_rule("lightning/first_after", 6.0))


func is_active() -> bool:
	return not _vents.is_empty() or not _warp_partner.is_empty() or arena.weather == "lightning"


static func _rule(path: String, default_value: Variant) -> Variant:
	return GameData.rule("hazards/" + path, default_value)


func _physics_process(delta: float) -> void:
	if main == null or main.round_over:
		return
	_clock += delta
	_tick_vents(delta)
	_tick_warps()
	if arena.weather == "lightning":
		_tick_lightning(delta)


func _brawlers() -> Array[Brawler]:
	var result: Array[Brawler] = []
	for node in get_tree().get_nodes_in_group("brawlers"):
		var b := node as Brawler
		if b and not b.is_dead and not b.is_legendary:
			result.append(b)
	return result


# --- Fire vents ----------------------------------------------------------------

func _add_vent(cell: Vector2i) -> void:
	var pos := arena.cell_center(cell)
	var disk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.48
	mesh.height = 0.08
	disk.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.12, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.05)
	mat.emission_energy_multiplier = 0.2
	disk.material_override = mat
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disk)
	disk.position = pos + Vector3(0, 0.04, 0)
	# Checkerboard groups take turns, so the room has a rhythm you can learn.
	var phase := 0.5 if (floori(cell.x / 3.0) + floori(cell.y / 3.0)) % 2 == 1 else 0.0
	_vents.append({ "pos": pos, "phase": phase, "mat": mat, "hit": 0.0, "burst": false })


func _tick_vents(delta: float) -> void:
	if _vents.is_empty():
		return
	_vent_time += delta
	var period := float(_rule("vents/period", 5.0))
	var warn := float(_rule("vents/warning", 1.2))
	var erupt := float(_rule("vents/erupt", 1.4))
	var dps := float(_rule("vents/dps", 1400.0))
	for vent in _vents:
		var t := fposmod(_vent_time + float(vent["phase"]) * period, period)
		var mat: StandardMaterial3D = vent["mat"]
		var erupting := t >= period - erupt
		var warning := not erupting and t >= period - erupt - warn
		mat.emission_energy_multiplier = 3.0 if erupting else (0.6 + 1.6 * absf(sin(_clock * 12.0)) if warning else 0.2)
		if erupting and not vent["burst"]:
			vent["burst"] = true
			Vfx.burst(self, vent["pos"] + Vector3(0, 0.3, 0), "fire", 26, 0.35, 5.0)
		if not erupting:
			vent["burst"] = false
			continue
		if int(_clock * 6.0) != int((_clock - delta) * 6.0):
			Vfx.burst(self, vent["pos"] + Vector3(0, 0.5, 0), "fire", 10, 0.3, 4.0)
		vent["hit"] = float(vent["hit"]) - delta
		if float(vent["hit"]) > 0.0:
			continue
		vent["hit"] = 0.25
		for b in _brawlers():
			if b.species.has_type("fire"):
				continue
			var p: Vector3 = vent["pos"]
			if Vector2(b.global_position.x - p.x, b.global_position.z - p.z).length() < 0.75:
				b.take_damage(dps * 0.25)


# --- Warp pads -------------------------------------------------------------------

## Each pad leads to the pad mirrored through the map's centre (top-left ↔ bottom-right);
## a pad without a mirror twin leads to the next pad in the list.
func _pair_warps() -> void:
	var cells := arena.warp_cells
	if cells.size() < 2:
		return
	for cell in cells:
		var twin := Vector2i(arena.width - 1 - cell.x, arena.height - 1 - cell.y)
		if twin in cells and twin != cell:
			_warp_partner[cell] = twin
		else:
			_warp_partner[cell] = cells[(cells.find(cell) + 1) % cells.size()]


func _add_pad(cell: Vector2i) -> void:
	var pad := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.3
	torus.outer_radius = 0.46
	pad.mesh = torus
	pad.scale = Vector3(1, 0.25, 1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.45, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.3, 1.0)
	mat.emission_energy_multiplier = 1.5
	pad.material_override = mat
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pad)
	pad.position = arena.cell_center(cell) + Vector3(0, 0.05, 0)
	var core := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.3
	disk.bottom_radius = 0.3
	disk.height = 0.02
	core.mesh = disk
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color = Color(0.9, 0.7, 1.0, 0.55)
	core.material_override = core_mat
	add_child(core)
	core.position = arena.cell_center(cell) + Vector3(0, 0.03, 0)


func _tick_warps() -> void:
	if _warp_partner.is_empty():
		return
	var cooldown := float(_rule("warp/cooldown", 2.5))
	for b in _brawlers():
		var cell := arena.world_to_cell(b.global_position)
		if not _warp_partner.has(cell) or b.is_stunned():
			continue
		var id := b.get_instance_id()
		if _clock < float(_warp_ready.get(id, 0.0)):
			continue
		var to: Vector3 = arena.cell_center(_warp_partner[cell])
		Vfx.burst(self, b.global_position + Vector3(0, 0.6, 0), "psychic", 20, 0.4, 3.0)
		b.global_position = Vector3(to.x, b.global_position.y, to.z)
		b.velocity = Vector3.ZERO
		Vfx.ring(self, to, 0.6, "psychic", 30)
		# Long enough to step off the far pad without bouncing straight back.
		_warp_ready[id] = _clock + cooldown


# --- Lightning -------------------------------------------------------------------

func _tick_lightning(delta: float) -> void:
	_strike_timer -= delta
	if _strike_timer <= 0.0:
		_strike_timer = randf_range(float(_rule("lightning/every_min", 4.0)), float(_rule("lightning/every_max", 7.0)))
		var targets := _brawlers()
		targets.shuffle()
		for i in int(_rule("lightning/strikes", 2)):
			var at := arena.random_open_point()
			if i < targets.size():
				# Lands near someone, but not dead on: you can always step out.
				var offset := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(0.0, 1.6)
				at = arena.nearest_open(targets[i].global_position + offset)
			_warn_strike(at)
	var radius := float(_rule("lightning/radius", 1.5))
	for s in _strikes.duplicate():
		s["left"] = float(s["left"]) - delta
		var mat: StandardMaterial3D = s["mat"]
		var warn := float(_rule("lightning/warning", 1.3))
		mat.albedo_color.a = 0.25 + 0.5 * (1.0 - float(s["left"]) / warn)
		if float(s["left"]) > 0.0:
			continue
		var pos: Vector3 = s["pos"]
		Vfx.lightning(self, pos + Vector3(randf_range(-0.6, 0.6), 9.0, -2.0), pos + Vector3(0, 0.1, 0))
		Vfx.burst(self, pos + Vector3(0, 0.3, 0), "electric", 24, 0.5, 4.0)
		for b in _brawlers():
			if b.species.has_type("electric") or b.species.has_type("ground"):
				continue
			if Vector2(b.global_position.x - pos.x, b.global_position.z - pos.z).length() < radius:
				b.take_damage(float(_rule("lightning/damage", 1300.0)))
		(s["disk"] as Node).queue_free()
		_strikes.erase(s)


func _warn_strike(at: Vector3) -> void:
	var disk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	var radius := float(_rule("lightning/radius", 1.5))
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	disk.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.92, 0.2, 0.25)
	disk.material_override = mat
	disk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disk)
	disk.position = at + Vector3(0, 0.04, 0)
	_strikes.append({ "pos": at, "left": float(_rule("lightning/warning", 1.3)), "disk": disk, "mat": mat })


## Bots step out of lightning circles and away from vents about to erupt:
## the direction to walk (zero when `pos` is safe for `b`).
func escape_from(pos: Vector3, b: Brawler) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	if not b.species.has_type("electric") and not b.species.has_type("ground"):
		var radius := float(_rule("lightning/radius", 1.5)) + 0.3
		for s in _strikes:
			var p: Vector3 = s["pos"]
			if flat.distance_to(Vector2(p.x, p.z)) < radius:
				return _away(pos, p)
	if not b.species.has_type("fire") and not _vents.is_empty():
		var period := float(_rule("vents/period", 5.0))
		var erupt := float(_rule("vents/erupt", 1.4))
		var warn := float(_rule("vents/warning", 1.2))
		for vent in _vents:
			var t := fposmod(_vent_time + float(vent["phase"]) * period, period)
			var p: Vector3 = vent["pos"]
			if t >= period - erupt - warn and flat.distance_to(Vector2(p.x, p.z)) < 1.0:
				return _away(pos, p)
	return Vector3.ZERO


static func _away(pos: Vector3, from: Vector3) -> Vector3:
	var dir := Vector3(pos.x - from.x, 0, pos.z - from.z)
	return dir.normalized() if dir.length() > 0.05 else Vector3.RIGHT
