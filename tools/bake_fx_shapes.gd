extends SceneTree
## Draws every particle / shot shape once and saves it to assets/fx/<shape>.png, so
## the game loads them instead of drawing them pixel by pixel (slow on phones):
##   godot --headless --path . -s res://tools/bake_fx_shapes.gd

const SHAPES := ["flame", "drop", "bolt", "leaf", "chunk", "shard", "ring", "bubble", "wisp", "crescent",
		"star", "spark", "blast", "swirl", "petal", "coin", "bone", "needle", "orb", "note", "egg", "seed",
		"snowflake", "blob", "web", "fang", "slash"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/fx"))
	for shape: String in SHAPES:
		var tex := Vfx.draw_shape(shape)
		tex.get_image().save_png("res://assets/fx/%s.png" % shape)
	print("baked %d shapes" % SHAPES.size())
	quit()
