class_name TeamDuel
extends MatchMode
## One-on-one trainer battles, like the games (Team Rocket Hideout, Elite Four):
## each side brings a team, only one each is on the field. You see their team and
## choose your lead. When a Pokémon faints its trainer picks who goes next: you
## choose from the ones you have left, the trainer sends whichever has the best
## type match-up against yours. The one still standing keeps its HP and heals a
## little. Faint all of theirs to win; lose all of yours and you lose.
## Subclasses give your picks, the trainer's name and the timings, and dress up
## the trainer's Pokémon (prepare_enemies).

signal next_chosen(b: Brawler)

## The trainer's strongest, sent out last (null = none).
var ace: Brawler
## True while you're choosing who goes next (the match is paused).
var choosing := false
var _picker: Node
## Who's on the field for each team.
var active := { 0: null, 1: null }


## Your team: picks from the select screen ({ species, main, hm, evolution, shiny }).
## The first is already on the field when the match starts.
func picks() -> Array:
	return []


func foe_name() -> String:
	return str(main.trainer.get("name", "The trainer"))


## Share of max HP the one still standing gets back when the other side switches.
func between_heal() -> float:
	return 0.2


## Seconds between a faint and the next Pokémon coming out.
func switch_delay() -> float:
	return 1.2


func time_limit() -> float:
	return 240.0


## Toughens the trainer's team (shadows, the ace). `theirs` is in send-out order.
func prepare_enemies(_theirs: Array) -> void:
	pass


func start() -> void:
	main.time_left = time_limit()
	var team := picks()
	for i in range(1, team.size()):
		main.bench(main.spawn_pick(team[i]))
	var theirs: Array = main.teams.get(1, [])
	prepare_enemies(theirs)
	for i in range(1, theirs.size()):
		main.bench(theirs[i])
	active[0] = main.player
	active[1] = theirs[0] if not theirs.is_empty() else null
	main.hud.set_teams(main.teams)


## Makes `b` the trainer's ace: bigger, tougher, played hard.
static func make_ace(b: Brawler, size_scale: float, hp_mult: float) -> void:
	b.size_scale = size_scale
	b.hp_scale *= hp_mult
	b.refresh_stats()
	b.health = b.max_health
	for child in b.get_children():
		if child is BotController:
			(child as BotController).set_difficulty("hard")


## Before the banners: you've seen their team, now pick who leads.
func before_intro() -> void:
	var options := waiting(0)
	options.push_front(main.player)
	var lead: Brawler = await _choose(options, "CHOOSE YOUR LEAD", "Their team: " + _names(main.teams[1]))
	if lead != main.player:
		var old: Brawler = main.player
		main.send_out(lead)
		main.bench(old)
		active[0] = lead


## Pokémon of `team` that haven't been out yet or are waiting (benched, not fainted).
func waiting(team: int) -> Array[Brawler]:
	var out: Array[Brawler] = []
	for b: Brawler in main.teams.get(team, []):
		if is_instance_valid(b) and not b.is_dead and main.is_benched(b):
			out.append(b)
	return out


## How many Pokémon `team` has left (on the field or waiting).
func left(team: int) -> int:
	var n := 0
	for b: Brawler in main.teams.get(team, []):
		if is_instance_valid(b) and not b.is_dead:
			n += 1
	return n


func on_died(victim: Brawler, _killer: Brawler) -> bool:
	var scoring := 1 - victim.team
	main.scores[scoring] += 1.0
	_replace(victim)
	return true  # Nobody respawns: the next one comes out instead.


func _replace(victim: Brawler) -> void:
	var team := victim.team
	if left(team) <= 0:
		main.end_round("defeat" if team == main.player.team else "victory")
		return
	await main.get_tree().create_timer(switch_delay(), false).timeout
	if main.round_over or not is_instance_valid(victim):
		return
	var next: Brawler
	var options := waiting(team)
	if options.is_empty():
		return
	var foe: Brawler = active[1 - team]
	if team == main.player.team:
		next = options[0] if options.size() == 1 else await _choose(options, "WHO'S NEXT?",
				"vs. " + (foe.species.display_name.to_upper() if is_instance_valid(foe) else ""))
	else:
		next = best_counter(options, foe)
	if main.round_over:
		return
	main.bench(victim)
	main.send_out(next)
	active[team] = next
	# The one still standing gets its breath back.
	if is_instance_valid(foe) and not foe.is_dead:
		foe.health = minf(foe.max_health, foe.health + foe.max_health * between_heal())
	main.hud.set_teams(main.teams)
	var who := foe_name()
	main.hud.announce(("Go, %s!" if team == main.player.team else who + " sends out %s!") % next.species.display_name.to_upper())


## Rocket's pick: the waiting Pokémon whose types hit `foe` hardest and take the
## least back from it.
static func best_counter(options: Array[Brawler], foe: Brawler) -> Brawler:
	if foe == null or not is_instance_valid(foe):
		return options[0]
	var best: Brawler = options[0]
	var best_score := -INF
	for b in options:
		var score := matchup(b.species.types, foe.species.types)
		if score > best_score + 0.001:
			best_score = score
			best = b
	return best


## How good `mine` is against `theirs`: my best hit on them minus their best hit on me.
static func matchup(mine: Array[String], theirs: Array[String]) -> float:
	var attack := 0.0
	for t in mine:
		attack = maxf(attack, GameData.effectiveness(t, theirs))
	var defend := 0.0
	for t in theirs:
		defend = maxf(defend, GameData.effectiveness(t, mine))
	return attack - defend


## Pauses the match and asks you to pick one of `options`. Tests answer with choose().
func _choose(options: Array[Brawler], title: String, subtitle: String) -> Brawler:
	choosing = true
	main.get_tree().paused = true
	_picker = _picker_panel(options, title, subtitle)
	main.hud.add_child(_picker)
	var b: Brawler = await next_chosen
	if is_instance_valid(_picker):
		_picker.queue_free()
	choosing = false
	main.get_tree().paused = false
	return b


## Answers the picker (its buttons, or tests).
func choose(b: Brawler) -> void:
	if choosing:
		next_chosen.emit(b)


func _picker_panel(options: Array[Brawler], title: String, subtitle: String) -> Node:
	# Its own layer, over the sticks and buttons.
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiKit.make_theme()
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var head := UiKit.label(title, 52, Color(1, 0.85, 0.3))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var sub := UiKit.label(subtitle, 22, Color(1, 0.8, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	# Their side: who's out, and who's waiting.
	var foes := HBoxContainer.new()
	foes.alignment = BoxContainer.ALIGNMENT_CENTER
	foes.add_theme_constant_override("separation", 10)
	for f: Brawler in main.teams.get(1, []):
		var icon := PmdIcon.make(f.species, 56)
		icon.modulate = Color(0.3, 0.3, 0.3) if f.is_dead else Color(0.75, 0.6, 0.95)
		foes.add_child(icon)
	v.add_child(foes)
	var foe: Brawler = active[1]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16 if options.size() <= 3 else 8)
	for b in options:
		var card := VBoxContainer.new()
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(UiKit.sprite(b.portrait(), 110 if options.size() <= 3 else 80))
		var hint := ""
		if is_instance_valid(foe) and not foe.is_dead and title != "CHOOSE YOUR LEAD":
			var m := matchup(b.species.types, foe.species.types)
			hint = "\nGOOD MATCH-UP" if m > 0.3 else ("\nBAD MATCH-UP" if m < -0.3 else "")
		var types := " / ".join(b.species.types).to_upper()
		var btn := UiKit.button("%s\n%s%s" % [b.species.display_name.to_upper(), types, hint], func() -> void: choose(b), 22 if options.size() <= 3 else 17)
		btn.custom_minimum_size = Vector2(230 if options.size() <= 3 else 180, 0)
		var color := Color(0.2, 0.55, 0.3) if hint.contains("GOOD") else (Color(0.6, 0.22, 0.25) if hint.contains("BAD") else Color(0.25, 0.4, 0.75))
		btn.add_theme_stylebox_override("normal", UiKit.box(color))
		btn.add_theme_stylebox_override("hover", UiKit.box(color.lightened(0.12)))
		btn.add_theme_stylebox_override("pressed", UiKit.box(color.darkened(0.15)))
		card.add_child(btn)
		row.add_child(card)
	v.add_child(row)
	return layer


static func _names(team: Array) -> String:
	var names: Array[String] = []
	for b: Brawler in team:
		names.append(b.species.display_name.to_upper())
	return ", ".join(names)


## Time's up: more Pokémon left wins, then more HP on the field; a full tie goes
## to the trainer you're challenging (they're on home ground).
func time_up() -> String:
	var mine := left(0)
	var theirs := left(1)
	if mine != theirs:
		return "victory" if mine > theirs else "defeat"
	var a: Brawler = active[0]
	var b: Brawler = active[1]
	var hp_a := a.health / a.max_health if is_instance_valid(a) and not a.is_dead else 0.0
	var hp_b := b.health / b.max_health if is_instance_valid(b) and not b.is_dead else 0.0
	return "victory" if hp_a > hp_b + 0.001 else "defeat"


func scoreboard_info() -> Dictionary:
	return { "goal": "1 vs 1  ·  %d LEFT vs %d" % [left(0), left(1)] }
