class_name NatureKit
extends RefCounted
## Stylised nature models from Quaternius' Stylized Nature MegaKit (CC0, see
## tools/import_nature_models.py): soft round rocks for rock walls and boulders,
## leafy bushes for hedges, pebbles, mushrooms and flowers to scatter about.
## Each is baked into one ArrayMesh, centred and scaled to fit a wall tile, with
## textured see-through materials, and cached.

const DIR := "res://assets/models/nature/"
const SHADER := preload("res://assets/shaders/model_xray.gdshader")
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const BUSHES := ["Bush_Common", "Bush_Common_Flowers"]
const PEBBLES := ["Pebble_Round_1", "Pebble_Round_2", "Pebble_Round_3"]

static var _cache := {}
## Loaded model files, kept so later arenas don't load them again.
static var _scenes := {}


## Loads every model ahead of time, one per frame (the town does this while you
## walk about, so the first battle starts quicker).
static func warm(tree: SceneTree) -> void:
	for name: String in ROCKS + BUSHES:
		if not _scenes.has(name):
			_scenes[name] = load(DIR + name + ".gltf")
			await tree.process_frame


## The model `name`, its base on y = `base_y`, centred, scaled so its footprint
## is `width` across and (if `height` > 0) it is `height` tall.
static func mesh(name: String, width: float, height := 0.0, base_y := 0.0, tint := Color.WHITE) -> ArrayMesh:
	var key := "%s|%.3f|%.3f|%.3f|%s" % [name, width, height, base_y, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".gltf")
	var scene := _scenes[name] as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var out := ArrayMesh.new()
	var parts: Array[MeshInstance3D] = []
	_collect(root, parts)
	var box := AABB()
	var first := true
	for mi in parts:
		var b := _local(mi) * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := width / maxf(0.001, maxf(box.size.x, box.size.z))
	var sy := height / maxf(0.001, box.size.y) if height > 0.0 else s
	var centre := box.get_center()
	var fit := Transform3D(Basis.from_scale(Vector3(s, sy, s)), Vector3(-centre.x * s, base_y - box.position.y * sy, -centre.z * s))
	for mi in parts:
		for i in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, i, fit * _local(mi))
			var surface := st.commit()
			var src := mi.mesh.surface_get_material(i)
			if mi.get_surface_override_material(i):
				src = mi.get_surface_override_material(i)
			surface.surface_set_material(0, _material(src, tint))
			var arrays := surface.surface_get_arrays(0)
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			out.surface_set_material(out.get_surface_count() - 1, surface.surface_get_material(0))
	root.free()
	_cache[key] = out
	return out


static func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


## The node's transform relative to the scene root (the scene isn't in the tree).
static func _local(node: Node3D) -> Transform3D:
	var t := node.transform
	var p := node.get_parent()
	while p is Node3D and p.get_parent() != null:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


static func _material(src: Material, tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tint", tint)
	var std := src as BaseMaterial3D
	if std and std.albedo_texture:
		mat.set_shader_parameter("albedo_tex", std.albedo_texture)
		# Leaf and petal cards have see-through edges.
		var tex_path := std.albedo_texture.resource_path.get_file()
		mat.set_shader_parameter("cutout", std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				or tex_path.begins_with("Leaves") or tex_path.begins_with("Flowers"))
	return mat
