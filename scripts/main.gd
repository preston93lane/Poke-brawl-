extends Node3D
## Sets up a 1v1 round: player-controlled brawler vs a bot.

const BRAWLER_SCENE := preload("res://scenes/brawler.tscn")

@export var player_data: BrawlerData = preload("res://data/pikachu.tres")
@export var enemy_data: BrawlerData = preload("res://data/charmander.tres")

var player: Brawler
var enemy: Brawler
var round_over := false

@onready var arena: Arena = $Arena
@onready var camera: FollowCamera = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	player = _spawn(player_data, 0, arena.player_spawn, true)
	enemy = _spawn(enemy_data, 1, arena.enemy_spawn, false)

	var player_controller := PlayerController.new()
	player_controller.move_stick = hud.move_stick
	player_controller.aim_stick = hud.aim_stick
	player_controller.melee_button = hud.melee_button
	player.add_child(player_controller)

	var bot := BotController.new()
	bot.target = player
	enemy.add_child(bot)

	camera.target = player
	camera.snap_to_target()
	hud.set_matchup(player_data.display_name, enemy_data.display_name)
	hud.restart_requested.connect(func() -> void: get_tree().reload_current_scene())


func _spawn(data: BrawlerData, team: int, spawn_position: Vector3, is_player: bool) -> Brawler:
	var brawler: Brawler = BRAWLER_SCENE.instantiate()
	brawler.data = data
	brawler.team = team
	brawler.is_player = is_player
	brawler.position = spawn_position
	arena.add_child(brawler)
	brawler.died.connect(_on_brawler_died)
	return brawler


func _on_brawler_died(brawler: Brawler) -> void:
	if round_over:
		return
	round_over = true
	hud.show_result(brawler != player)
