class_name BrawlerData
extends Resource
## Stats and art for one Pokémon brawler. Make a new .tres in res://data to add a brawler.

@export var display_name := "Brawler"
## Placeholder art; swap the PNG for real art later.
@export var portrait: Texture2D

@export_group("Stats")
@export var max_health := 3200.0
@export var move_speed := 5.0

@export_group("Projectile attack")
@export var projectile_damage := 700.0
@export var projectile_speed := 16.0
@export var projectile_range := 9.0
@export var max_ammo := 3
## Seconds to reload one ammo bar.
@export var reload_time := 1.4
@export var projectile_color := Color(1, 0.9, 0.2)

@export_group("Melee attack")
@export var melee_damage := 1100.0
@export var melee_range := 2.2
@export var melee_arc_degrees := 110.0
@export var melee_cooldown := 0.8
