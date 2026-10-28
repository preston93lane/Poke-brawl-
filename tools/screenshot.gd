extends Node
## Renders a match and saves screenshots, for checking how a map looks:
##   godot --path . --rendering-driver opengl3 res://tools/screenshot.tscn -- <arena_id> <out_dir>
## (on a server, run under xvfb-run). Bots are frozen so the shot is repeatable.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var arena_id := args[0] if args.size() > 0 else "route_1"
	var out_dir := args[1] if args.size() > 1 else "user://shots"
	var main := MAIN_SCENE.instantiate()
	main.show_intro = false
	main.arena_id = arena_id
	main.player_species = "pikachu"
	main.enemy_team = PackedStringArray(["bulbasaur", "charmander", "squirtle"])
	add_child(main)
	for i in 10:
		await get_tree().process_frame
	for b in get_tree().get_nodes_in_group("brawlers"):
		for child in b.get_children():
			if child is BotController or child is PlayerController:
				child.queue_free()
	var cam: FollowCamera = main.camera
	var spots := { "spawn": main.player.global_position, "middle": Vector3(0, 0, 4) }
	# Just behind (north of) an inner tree or wall, to check the see-through effect.
	var arena: Arena = main.arena
	for y in range(6, arena.height - 6):
		for x in range(4, arena.width - 4):
			if arena.rows[y][x] in ["T", "#"] and arena.rows[y - 1][x] == "." and arena.rows[y + 1][x] == ".":
				spots["behind"] = arena.cell_center(Vector2i(x, y - 1))
				break
		if spots.has("behind"):
			break
	for shot: String in spots:
		main.player.global_position = spots[shot]
		cam.snap_to_target()
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out_dir, arena_id, shot])
		print("saved ", shot)
	get_tree().quit()
