class_name TownScreens
extends RefCounted
## Inside each town building: who works there on the left (with what they say),
## what you can do on the right. Rules live in scripts/data/town.gd.

const BUILDINGS := {
	"center": { "title": "POKéMON CENTER", "color": Color(0.85, 0.3, 0.35), "staff": "nurse",
		"hello": "Welcome to the Pokémon Center! Leave your tired Pokémon with us and Chansey and I will have them back on their feet in no time." },
	"mart": { "title": "POKé MART", "color": Color(0.3, 0.45, 0.8), "staff": "clerk",
		"hello": "Hi there! May I help you? New stock comes in every day." },
	"dept": { "title": "DEPARTMENT STORE", "color": Color(0.55, 0.4, 0.75), "staff": "clerk",
		"hello": "Welcome to the Department Store! Refreshing drinks on the rooftop, and our TM counter has new TMs every day." },
	"corner": { "title": "GAME CORNER", "color": Color(0.85, 0.2, 0.3), "staff": "dealer",
		"hello": "Welcome! Coins for the slots and Voltorb Flip are at the counter. Big winners take home prizes... even rare Pokémon!" },
	"daycare": { "title": "DAY CARE", "color": Color(0.85, 0.6, 0.3), "staff": "elder",
		"hello": "I'm the Day Care man. Leave a Pokémon with me and it'll learn from watching your other battles." },
	"museum": { "title": "PEWTER MUSEUM", "color": Color(0.5, 0.45, 0.4), "staff": "guide",
		"hello": "Welcome to the museum! Every exhibit here is from your own journey." },
	"outfitter": { "title": "TRAINER OUTFITTER", "color": Color(0.9, 0.45, 0.6), "staff": "stylist",
		"hello": "Darling! Whole outfits from every kind of trainer, or mix and match pieces. Tap a colour to try it on!" },
	"rocket": { "title": "TEAM ROCKET HIDEOUT", "color": Color(0.55, 0.12, 0.18), "staff": "",
		"hello": "Hah! You found our hideout. Our Shadow Pokémon will crush you... Three of us, then the Executives. Prepare for trouble!" },
	"arena": { "title": "BATTLE ARENA", "color": Color(0.95, 0.6, 0.15), "staff": "clerk",
		"hello": "This is the Battle Arena! Quick battles, Gyms, Raids... and the Trainer Tower. How high can you climb?" },
}


## The common frame: title bar, the staff member with a speech bubble, and `content`.
static func frame(menu: Node, building: String, content: Control, extra_top: Control = null, speech := "") -> Control:
	var b: Dictionary = BUILDINGS[building]
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.button("‹ TOWN", menu.show_home))
	var title := UiKit.label(str(b["title"]), 32, Color(1, 0.88, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if extra_top:
		top.add_child(extra_top)
	top.add_child(UiKit.label("%d ₽" % Profile.money(), 28, Color(1, 0.95, 0.6)))
	v.add_child(top)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var staff := VBoxContainer.new()
	staff.custom_minimum_size.x = 168
	staff.add_theme_constant_override("separation", 8)
	var portrait := HBoxContainer.new()
	portrait.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(trainer_picture(TrainerLook.rocket_sheet() if building == "rocket" else TrainerLook.staff_sheet(str(b["staff"])), 120))
	if building == "center" and GameData.species.has("chansey"):
		portrait.add_child(PmdIcon.make(GameData.species["chansey"], 70))
	staff.add_child(portrait)
	var bubble := UiKit.label(speech if speech != "" else str(b["hello"]), 17, Color(0.15, 0.15, 0.2))
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bubble_panel := PanelContainer.new()
	bubble_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.98, 0.97, 0.92), 16, 12))
	bubble_panel.add_child(bubble)
	staff.add_child(bubble_panel)
	var staff_panel := UiKit.panel(staff)
	staff_panel.add_theme_stylebox_override("panel", UiKit.box((b["color"] as Color).darkened(0.35), 16, 12))
	body.add_child(staff_panel)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	v.add_child(body)
	return v


## A trainer sheet's front-facing frame, scaled up crisply.
static func trainer_picture(sheet: Texture2D, height: float, row := 0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = TrainerLook.frame(sheet, row, 0)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(height * 0.8, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _pips(family: String, size := 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var e := Town.energy(family)
	for i in Town.max_energy():
		var fill := clampf(e - i, 0.0, 1.0)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(size, size)
		dot.color = Color(0.35, 0.9, 0.5) if fill >= 1.0 else (Color(0.9, 0.8, 0.3) if fill > 0.0 else Color(1, 1, 1, 0.18))
		row.add_child(dot)
	return row


static func _time(seconds: int) -> String:
	if seconds >= 3600:
		return "%dh %02dm" % [seconds / 3600, (seconds / 60) % 60]
	return "%dm %02ds" % [seconds / 60, seconds % 60]


static func _mode_title(mode: String) -> String:
	return { "duel": "Battle 3v3", "king_of_the_hill": "King of the Hill", "brawl_ball": "Brawl Ball", "candy_rush": "Rare Candy Rush",
		"showdown": "Showdown" }.get(mode, mode.capitalize())


static func _card(color: Color, child: Control) -> PanelContainer:
	var p := UiKit.panel(child)
	p.add_theme_stylebox_override("panel", UiKit.box(color, 14, 12))
	return p


static func _families() -> Array[SpeciesData]:
	var out: Array[SpeciesData] = []
	for s in GameData.base_species():
		if Profile.is_unlocked(s.id):
			out.append(s)
	return out


# --- Pokémon Center ----------------------------------------------------------------

static func center(menu: Node, message := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	if message != "":
		v.add_child(UiKit.label(message, 20, Color(0.6, 1, 0.6)))
	if not Town.energy_applies():
		var l := UiKit.label("Your Pokémon never tire while you have only a few. Once you have %d lines, each match uses energy: rested Pokémon earn ×%.1f XP and money, tired ones ×%.1f." % [
				int(Town.cfg("energy/min_lines", 4)), float(Town.cfg("energy/rested_mult", 1.5)), float(Town.cfg("energy/tired_mult", 0.5))], 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	v.add_child(UiKit.section_title("RESTING  (%d / %d beds)  ·  heals 1 energy every %d min, and 1 for each match you play with someone else" % [
			Town.center_beds().size(), int(Town.cfg("energy/center_beds", 3)), int(Town.cfg("energy/center_minutes", 15))]))
	var beds := HBoxContainer.new()
	beds.add_theme_constant_override("separation", 10)
	for family: String in Town.center_beds():
		var col := VBoxContainer.new()
		col.add_child(PmdIcon.make(GameData.species[family], 80))
		col.add_child(_pips(family, 14))
		col.add_child(UiKit.label("full in " + _time(int((Town.max_energy() - Town.energy(family)) * float(Town.cfg("energy/center_minutes", 15)) * 60.0)), 14))
		col.add_child(UiKit.button("PICK UP", func() -> void:
			Town.check_out(family)
			menu.show_center(), 16))
		beds.add_child(_card(Color(0.95, 0.85, 0.88, 0.25), col))
	if Town.center_beds().is_empty():
		beds.add_child(UiKit.label("No one resting right now.", 18, Color(1, 1, 1, 0.6)))
	v.add_child(beds)
	v.add_child(UiKit.section_title("YOUR POKéMON  ·  %d energy each, one per match" % Town.max_energy()))
	var list := _families()
	list.sort_custom(func(a: SpeciesData, b: SpeciesData) -> bool: return Town.energy(a.id) < Town.energy(b.id))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for s in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(PmdIcon.make(s, 54))
		var info := VBoxContainer.new()
		info.custom_minimum_size.x = 120
		info.add_child(UiKit.label(s.display_name, 18))
		info.add_child(_pips(s.id))
		var next := Town.next_pip_seconds(s.id)
		info.add_child(UiKit.label("TIRED" if Town.is_tired(s.id) else ("+1 in " + _time(next) if next > 0 else "Full of energy"), 13,
				Color(1, 0.5, 0.4) if Town.is_tired(s.id) else Color(0.8, 0.9, 1)))
		row.add_child(info)
		var family := s.id
		var rest := UiKit.button("REST", func() -> void:
			if Town.check_in(family):
				menu.show_center("%s is resting." % GameData.species[family].display_name), 16)
		rest.disabled = Town.in_center(family) or Town.energy(family) >= Town.max_energy() or Town.center_beds().size() >= int(Town.cfg("energy/center_beds", 3))
		row.add_child(rest)
		var price := Town.heal_price(family)
		var heal := UiKit.button("HEAL %d ₽" % price if price > 0 else "HEAL", func() -> void:
			if Town.heal_now(family):
				menu.show_center("%s is fully healed!" % GameData.species[family].display_name), 16)
		heal.disabled = price <= 0 or Profile.money() < price
		row.add_child(heal)
		grid.add_child(_card(Color(1, 1, 1, 0.06), row))
	v.add_child(grid)
	return frame(menu, "center", UiKit.scroll(v))


# --- Poké Mart (the daily store) ---------------------------------------------------

static func mart(menu: Node, message := "") -> Control:
	return frame(menu, "mart", TrainerScreens.store(menu, message, true), null)


# --- Department Store ----------------------------------------------------------------

static func dept(menu: Node, message := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	if message != "":
		v.add_child(UiKit.label(message, 20, Color(0.6, 1, 0.6)))
	v.add_child(UiKit.section_title("ROOFTOP VENDING MACHINE  ·  pick one before a match"))
	var drinks := HBoxContainer.new()
	drinks.add_theme_constant_override("separation", 12)
	var colors := { "fresh_water": Color(0.3, 0.6, 0.9), "soda_pop": Color(0.85, 0.45, 0.3), "lemonade": Color(0.85, 0.75, 0.25) }
	for id: String in Town.drinks():
		var d: Dictionary = Town.drinks()[id]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(230, 0)
		col.add_child(UiKit.label(str(d["name"]), 26))
		var desc := UiKit.label(str(d["desc"]), 16)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
		col.add_child(UiKit.label("In your bag: %d" % Profile.count(id), 15, Color(0.85, 0.95, 1)))
		var buy := UiKit.button("BUY  %d ₽" % int(d["price"]), func() -> void:
			if Town.buy_drink(id):
				menu.show_dept("Bought a %s!" % d["name"]), 20)
		buy.disabled = Profile.money() < int(d["price"])
		col.add_child(buy)
		drinks.add_child(_card(colors.get(id, Color(0.3, 0.3, 0.4)), col))
	v.add_child(drinks)
	v.add_child(UiKit.section_title("TM COUNTER  ·  new TMs every day"))
	var tms := HBoxContainer.new()
	tms.add_theme_constant_override("separation", 12)
	var price := int(Town.cfg("tm_counter/price", 4000))
	for tm_id in Town.tm_counter():
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(230, 0)
		var name_label := UiKit.label(Profile.item_name(tm_id), 22)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(name_label)
		var buy := UiKit.button("BUY  %d ₽" % price, func() -> void:
			if Town.buy_tm(tm_id):
				menu.show_dept("Got %s!" % Profile.item_name(tm_id)), 20)
		buy.disabled = Profile.money() < price
		col.add_child(buy)
		tms.add_child(_card(Color(0.35, 0.3, 0.55), col))
	if Town.tm_counter().is_empty():
		tms.add_child(UiKit.label("You already have every TM!", 20))
	v.add_child(tms)
	return frame(menu, "dept", UiKit.scroll(v))


# --- Game Corner ---------------------------------------------------------------------

static func corner(menu: Node, tab := "slots", message := "") -> Control:
	var coin_label := UiKit.label("%d COINS" % Town.coins(), 28, Color(1, 0.85, 0.3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for t in [["slots", "SLOTS"], ["voltorb", "VOLTORB FLIP"], ["prizes", "PRIZES"], ["coins", "BUY COINS"]]:
		var b := UiKit.button(t[1], menu.show_corner.bind(t[0], ""), 20)
		b.custom_minimum_size = Vector2(180, 54)
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.85, 0.2, 0.3) if t[0] == tab else Color(0.3, 0.25, 0.35)))
		tabs.add_child(b)
	v.add_child(tabs)
	if message != "":
		v.add_child(UiKit.label(message, 20, Color(0.6, 1, 0.6)))
	var refresh := func() -> void: coin_label.text = "%d COINS" % Town.coins()
	match tab:
		"slots":
			var s := SlotMachine.new()
			s.coins_changed.connect(refresh)
			v.add_child(s)
		"voltorb":
			var vf := VoltorbFlip.new()
			vf.coins_changed.connect(refresh)
			v.add_child(vf)
		"prizes":
			var grid := GridContainer.new()
			grid.columns = 3
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			var list := Town.prizes()
			for i in list.size():
				var p: Dictionary = list[i]
				var col := VBoxContainer.new()
				col.custom_minimum_size = Vector2(190, 0)
				var title := ""
				match str(p["kind"]):
					"pokemon":
						title = GameData.species[p["id"]].display_name if GameData.species.has(p["id"]) else str(p["id"])
						if GameData.species.has(p["id"]):
							col.add_child(PmdIcon.make(GameData.species[p["id"]], 64))
					"tm":
						title = "A random TM"
					_:
						title = Profile.item_name(str(p["id"]))
						col.add_child(UiKit.sprite(UiKit.item_icon(str(p["id"])), 56))
				col.add_child(UiKit.label(title, 22))
				var why := Town.prize_block(p)
				var take := UiKit.button("%d COINS" % int(p["coins"]) if why == "" else "%d · %s" % [int(p["coins"]), why.to_upper()], func() -> void:
					var got := Town.claim_prize(i)
					if got != "":
						menu.show_corner("prizes", "You got %s!" % (GameData.species[got].display_name if GameData.species.has(got) else Profile.item_name(got))), 18)
				take.disabled = why != ""
				col.add_child(take)
				grid.add_child(_card(Color(0.4, 0.2, 0.3), col))
			v.add_child(UiKit.scroll(grid))
		"coins":
			var pack := int(Town.cfg("game_corner/coin_pack", 50))
			var price := int(Town.cfg("game_corner/pack_price", 1000))
			var cap := int(Town.cfg("game_corner/buy_cap", 500))
			v.add_child(UiKit.label("%d coins for %d ₽  ·  up to %d coins a day (%d bought today)" % [pack, price, cap, Town.coins_bought_today()], 22))
			var buy := UiKit.button("BUY %d COINS" % pack, func() -> void:
				if Town.buy_coins():
					menu.show_corner("coins", "Bought %d coins!" % pack), 26)
			buy.disabled = Profile.money() < price or Town.coins_bought_today() + pack > cap
			buy.custom_minimum_size = Vector2(320, 70)
			v.add_child(buy)
			v.add_child(UiKit.label("You also earn %d coins for every win and %d for MVP." % [int(Town.cfg("game_corner/win_coins", 3)), int(Town.cfg("game_corner/mvp_coins", 2))], 18, Color(0.85, 0.9, 1)))
			v.add_child(UiKit.label("Coins are only ever won or bought with Pokédollars from playing. No real money, ever.", 16, Color(1, 1, 1, 0.6)))
	return frame(menu, "corner", v, coin_label)


# --- Day Care ------------------------------------------------------------------------

static func daycare(menu: Node, message := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	if message != "":
		v.add_child(UiKit.label(message, 20, Color(0.6, 1, 0.6)))
	v.add_child(UiKit.section_title("STAYING HERE  ·  gets %d%% of the XP you earn with other Pokémon" % roundi(float(Town.cfg("daycare/share", 0.4)) * 100)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for family: String in Town.daycare():
		var col := VBoxContainer.new()
		col.add_child(PmdIcon.make(GameData.species[family], 90))
		col.add_child(UiKit.label("%s  ·  Lv %d" % [GameData.species[family].display_name, Profile.level_of(family)], 18))
		col.add_child(UiKit.label("+%d XP so far" % Town.daycare_gained(family), 16, Color(0.7, 1, 0.7)))
		col.add_child(UiKit.button("TAKE BACK", func() -> void:
			var xp := Town.withdraw(family)
			menu.show_daycare("%s learned %d XP while it was here!" % [GameData.species[family].display_name, xp]), 18))
		row.add_child(_card(Color(0.5, 0.4, 0.25), col))
	for i in Town.daycare_slots() - Town.daycare().size():
		var empty := UiKit.label("Empty spot", 20, Color(1, 1, 1, 0.5))
		empty.custom_minimum_size = Vector2(180, 150)
		row.add_child(_card(Color(0.5, 0.4, 0.25, 0.4), empty))
	if Town.daycare_slots() < 2:
		var price := int(Town.cfg("daycare/second_slot_price", 5000))
		var buy := UiKit.button("SECOND SPOT\n%d ₽" % price, func() -> void:
			if Town.buy_second_slot():
				menu.show_daycare("There's room for two now!"), 18)
		buy.disabled = Profile.money() < price
		row.add_child(buy)
	v.add_child(row)
	if Town.daycare().size() < Town.daycare_slots():
		v.add_child(UiKit.section_title("LEAVE A POKéMON"))
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		for s in _families():
			if s.id in Town.daycare():
				continue
			var b := Button.new()
			b.custom_minimum_size = Vector2(96, 110)
			b.tooltip_text = s.display_name
			var icon := PmdIcon.make(s, 72)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.position = Vector2(12, 4)
			b.add_child(icon)
			var lv := UiKit.label("Lv %d" % Profile.level_of(s.id), 14)
			lv.position = Vector2(26, 82)
			b.add_child(lv)
			var family := s.id
			b.pressed.connect(func() -> void:
				if Town.deposit(family):
					menu.show_daycare("I'll take good care of %s!" % GameData.species[family].display_name))
			grid.add_child(b)
		v.add_child(grid)
	return frame(menu, "daycare", UiKit.scroll(v))


# --- Pewter Museum -------------------------------------------------------------------

static func museum(menu: Node) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var exhibits := HFlowContainer.new()
	exhibits.add_theme_constant_override("h_separation", 10)
	exhibits.add_theme_constant_override("v_separation", 10)
	var rec := Town.trainer_record()
	var corner: Dictionary = Profile.data.get("corner_stats", {})
	for e in [
		["TRAINER TOWER", "Highest floor: %d" % Town.tower_best(), Color(0.6, 0.35, 0.2)],
		["TRAINER BATTLES", "%d won  ·  %d lost" % [int(rec["won"]), int(rec["lost"])], Color(0.3, 0.45, 0.7)],
		["GAME CORNER", "Biggest win: %d coins\nCoins won: %d" % [int(corner.get("best", 0)), int(corner.get("won", 0))], Color(0.7, 0.25, 0.35)],
		["BADGES", "%d / 8" % Profile.badges().size(), Color(0.65, 0.55, 0.2)],
		["TEAM ROCKET", "Hideouts cleared: %d" % Rocket.clears(), Color(0.55, 0.15, 0.2)],
	]:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(250, 0)
		col.add_child(UiKit.label(e[0], 18, Color(1, 0.9, 0.6)))
		col.add_child(UiKit.label(e[1], 22))
		exhibits.add_child(_card(e[2], col))
	v.add_child(exhibits)
	# Trainer cards: every kind of trainer you've beaten.
	v.add_child(UiKit.section_title("TRAINER CARDS"))
	var cards := HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	var beaten: Dictionary = rec["cards"]
	var classes: Dictionary = Town.cfg("classes", {})
	for id: String in classes:
		var c: Dictionary = classes[id]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(130, 0)
		var pic := trainer_picture(TrainerLook.npc_sheet(id), 90)
		if not beaten.has(id):
			pic.modulate = Color(0, 0, 0, 0.6)
		col.add_child(pic)
		col.add_child(UiKit.label(str(c["name"]), 15))
		col.add_child(UiKit.label("×%d" % int(beaten.get(id, 0)) if beaten.has(id) else "???", 14, Color(1, 1, 1, 0.7)))
		cards.add_child(_card(Color(0.25, 0.25, 0.3), col))
	v.add_child(cards)
	var profile := UiKit.button("TRAINER PROFILE ›  career stats, favourite Pokémon, badges", menu.show_profile, 22)
	profile.custom_minimum_size.y = 64
	v.add_child(profile)
	return frame(menu, "museum", UiKit.scroll(v))


# --- Trainer Outfitter ---------------------------------------------------------------
# Tabs: whole outfits (each trainer class in several colourways), then hats, tops,
# bottoms, shoes, and hair & skin (free). Tapping a colour tries it on in the
# preview; buy it, or wear it if it's yours.

const OUTFIT_TABS := [["sets", "OUTFITS"], ["hat", "HATS"], ["top", "TOPS"], ["bottom", "BOTTOMS"], ["shoes", "SHOES"], ["hair", "HAIR & SKIN"]]


static func outfitter(menu: Node, message := "") -> Control:
	var tab: String = menu.outfit_tab
	var trying: Dictionary = Town.outfit()
	trying.merge(menu.outfit_try, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	# Left: what you'd look like, from the front, side and back.
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 150
	var sheet := TrainerLook.player_sheet(trying)
	for r in [0, 2]:
		left.add_child(trainer_picture(sheet, 130, r))
	var trying_on: bool = not (menu.outfit_try as Dictionary).is_empty()
	left.add_child(UiKit.label("TRYING ON" if trying_on else "WEARING", 16, Color(1, 0.85, 0.4) if trying_on else Color(0.7, 1, 0.75)))
	if trying_on:
		left.add_child(UiKit.button("TAKE OFF", func() -> void:
			menu.outfit_try = {}
			menu.show_outfitter(), 16))
	row.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	for t: Array in OUTFIT_TABS:
		var b := UiKit.button(t[1], func() -> void:
			menu.outfit_tab = t[0]
			menu.show_outfitter(), 16)
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.9, 0.45, 0.6) if t[0] == tab else Color(0.32, 0.3, 0.42), 12, 8))
		tabs.add_child(b)
	right.add_child(tabs)
	if message != "":
		right.add_child(UiKit.label(message, 17, Color(0.6, 1, 0.6)))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	match tab:
		"sets":
			for s: Dictionary in Town.sets():
				list.add_child(_set_card(menu, s))
		"hair":
			list.add_child(_free_row(menu, "STYLE", "hair", Town.outfits().get("hairs", []), true))
			list.add_child(_free_row(menu, "HAIR COLOUR", "hair_color", Town.outfits().get("hair_colors", []), false))
			list.add_child(_free_row(menu, "SKIN", "skin", Town.outfits().get("skins", []), false))
		_:
			if tab == "hat":
				var none := UiKit.button("NO HAT" + ("  ✓" if (trying.get("hat", []) as Array).is_empty() else ""), func() -> void:
					Town.wear("hat", "")
					menu.outfit_try.erase("hat")
					menu.show_outfitter(), 16)
				none.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				list.add_child(none)
			var items: Dictionary = (Town.outfits().get("items", {}) as Dictionary).get(tab, {})
			for id: String in items:
				list.add_child(_item_card(menu, tab, id, items[id], trying))
	var scroll := UiKit.scroll(list)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	row.add_child(right)
	return frame(menu, "outfitter", row)


static func _swatch(color_hex: String, chosen: bool, owned: bool, on_press: Callable) -> Button:
	var sw := Button.new()
	sw.custom_minimum_size = Vector2(42, 42)
	var c := Color.html(color_hex)
	sw.add_theme_stylebox_override("normal", UiKit.box(c, 8 if chosen else 21, 4))
	sw.add_theme_stylebox_override("hover", UiKit.box(c.lightened(0.15), 8 if chosen else 21, 4))
	if owned:
		sw.text = "✓"
		sw.add_theme_color_override("font_color", Color.BLACK if c.get_luminance() > 0.6 else Color.WHITE)
	sw.pressed.connect(on_press)
	return sw


## One clothing item: its colours (✓ = yours); the chosen one can be bought or worn.
static func _item_card(menu: Node, slot: String, id: String, it: Dictionary, trying: Dictionary) -> Control:
	var colors: Array = Town.outfits().get("colors", [])
	var current: Array = trying.get(slot, [])
	var picked := int(current[1]) if current.size() == 2 and str(current[0]) == id else -1
	var col := VBoxContainer.new()
	var top := HBoxContainer.new()
	var title := UiKit.label(str(it["name"]), 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if it.has("unlock"):
		top.add_child(UiKit.label("ROCKET HIDEOUT REWARD", 14, Color(1, 0.5, 0.5)))
	else:
		top.add_child(UiKit.label("%d ₽ each colour" % int(it["price"]), 15, Color(1, 0.95, 0.6)))
	col.add_child(top)
	var swatches := HFlowContainer.new()
	swatches.add_theme_constant_override("h_separation", 6)
	for c: int in it.get("colors", []):
		swatches.add_child(_swatch(str(colors[c]), c == picked, Town.owns_item(slot, id, c), func() -> void:
			menu.outfit_try[slot] = [id, c]
			menu.show_outfitter()))
	col.add_child(swatches)
	if picked >= 0:
		var worn: Array = Town.outfit().get(slot, [])
		var is_worn := worn.size() == 2 and str(worn[0]) == id and int(worn[1]) == picked
		var why := Town.cant_buy_item(slot, id, picked)
		var b: Button
		if Town.owns_item(slot, id, picked):
			b = UiKit.button("WEARING" if is_worn else "WEAR", func() -> void:
				Town.wear(slot, id, picked)
				menu.outfit_try.erase(slot)
				menu.show_outfitter(), 18)
			b.disabled = is_worn
		else:
			b = UiKit.button("BUY  %d ₽" % int(it["price"]) if why == "" else why.to_upper(), func() -> void:
				if Town.buy_item(slot, id, picked):
					Town.wear(slot, id, picked)
					menu.outfit_try.erase(slot)
					menu.show_outfitter("Bought the %s!" % it["name"]), 18)
			b.disabled = why != ""
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(b)
	return _card(Color(0.3, 0.28, 0.4), col)


## A whole outfit: its colourways, try one on, buy it (cheaper than the pieces) or wear it.
static func _set_card(menu: Node, s: Dictionary) -> Control:
	var col := VBoxContainer.new()
	var top := HBoxContainer.new()
	var title := UiKit.label(str(s["name"]), 21, Color(1, 0.9, 0.6))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var pieces := PackedStringArray()
	for i in Town.SLOTS.size():
		if str(s["pieces"][i]) != "":
			pieces.append(str(Town.item(Town.SLOTS[i], str(s["pieces"][i])).get("name", "")))
	top.add_child(UiKit.label(" + ".join(pieces), 13, Color(0.85, 0.9, 1)))
	col.add_child(top)
	var ways := HFlowContainer.new()
	ways.add_theme_constant_override("h_separation", 8)
	var colors: Array = Town.outfits().get("colors", [])
	for vi in (s["variants"] as Array).size():
		var v: Dictionary = s["variants"][vi]
		var owned := Town.owns_set(s["id"], vi)
		var b := Button.new()
		b.text = ("✓ " if owned else "") + str(v["name"])
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_stylebox_override("normal", UiKit.box(Color.html(str(colors[int(v["colors"][1])])).darkened(0.25), 12, 8))
		b.pressed.connect(func() -> void:
			var t := {}
			for p: Array in Town.set_pieces(s["id"], vi):
				t[p[0]] = [p[1], p[2]]
			if str(s["pieces"][0]) == "":
				t["hat"] = []
			menu.outfit_try = t
			menu.outfit_set = [s["id"], vi]
			menu.show_outfitter())
		ways.add_child(b)
		if menu.outfit_set == [s["id"], vi]:
			var act: Button
			if s.has("unlock") and not owned:
				act = UiKit.button("EARNED IN THE ROCKET HIDEOUT", func() -> void: pass, 15)
				act.disabled = true
			elif owned:
				act = UiKit.button("WEAR", func() -> void:
					Town.wear_set(s["id"], vi)
					menu.outfit_try = {}
					menu.show_outfitter("Looking sharp!"), 16)
			else:
				var price := Town.set_price(s["id"], vi)
				act = UiKit.button("BUY OUTFIT  %d ₽" % price, func() -> void:
					if Town.buy_set(s["id"], vi):
						Town.wear_set(s["id"], vi)
						menu.outfit_try = {}
						menu.show_outfitter("The %s outfit is yours!" % s["name"]), 16)
				act.disabled = Profile.money() < price
			act.add_theme_stylebox_override("normal", UiKit.box(Color(0.25, 0.6, 0.35), 12, 8))
			ways.add_child(act)
	col.add_child(ways)
	return _card(Color(0.35, 0.22, 0.32) if s.has("unlock") else Color(0.28, 0.3, 0.42), col)


static func _free_row(menu: Node, title: String, key: String, values: Array, names: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_child(UiKit.label(title + "  (free)", 18))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	var current: Variant = Town.outfit().get(key)
	for i in values.size():
		var value: Variant = values[i] if names else i
		var chosen := str(current) == str(value)
		if names:
			var b := UiKit.button(str(values[i]).to_upper() + ("  ✓" if chosen else ""), func() -> void:
				Town.set_free(key, value)
				menu.show_outfitter(), 16)
			flow.add_child(b)
		else:
			flow.add_child(_swatch(str(values[i]), chosen, chosen, func() -> void:
				Town.set_free(key, value)
				menu.show_outfitter()))
	col.add_child(flow)
	return _card(Color(0.3, 0.28, 0.4), col)


# --- Team Rocket Hideout ---------------------------------------------------------------

static func rocket(menu: Node) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	if not Rocket.is_open():
		var days := Rocket.days_until_open()
		v.add_child(UiKit.label("The hideout is quiet... Team Rocket is out on a job.", 24))
		v.add_child(UiKit.label("They're back in %d day%s. They turn up every weekend and on a couple of random weekdays." % [days, "" if days == 1 else "s"], 18, Color(0.85, 0.9, 1)))
		v.add_child(_rocket_rewards())
		return frame(menu, "rocket", UiKit.scroll(v), null, "Hmph. Nobody's here. Come back when the boss's orders come in.")
	v.add_child(UiKit.section_title("TODAY'S HIDEOUT  ·  pick one Pokémon, first to %d KOs each round, every enemy a Shadow Pokémon" % int(Rocket.cfg("kills_to_win", 8))))
	var line := HFlowContainer.new()
	line.add_theme_constant_override("h_separation", 8)
	line.add_theme_constant_override("v_separation", 8)
	var rounds := Rocket.line_up()
	for i in rounds.size():
		var r: Dictionary = rounds[i]
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 160
		col.add_child(UiKit.label("%d · %s" % [i + 1, str(r["name"]).to_upper()], 15, Color(1, 0.6, 0.6) if bool(r["boss"]) else Color(1, 0.9, 0.7)))
		if r.has("title"):
			col.add_child(UiKit.label(str(r["title"]), 13, Color(0.85, 0.85, 0.9)))
		var team := HBoxContainer.new()
		for id: String in r["team"]:
			if GameData.species.has(id):
				var icon := PmdIcon.make(GameData.species[id], 44)
				icon.modulate = Color(0.75, 0.6, 0.95)
				team.add_child(icon)
		col.add_child(team)
		line.add_child(_card(Color(0.45, 0.1, 0.16) if bool(r["boss"]) else Color(0.25, 0.14, 0.2), col))
	v.add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for d: String in ["normal", "hard"]:
		var info: Dictionary = Rocket.cfg("difficulties/" + d, {})
		var b := UiKit.button("%s\n%d lives · Rocket level +%d" % [str(info.get("name", d)).to_upper(), int(info.get("lives", 3)), int(info.get("level_bonus", 2))], func() -> void:
			menu.rocket_difficulty = d
			menu.show_select("rocket"), 20)
		b.custom_minimum_size = Vector2(260, 80)
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.75, 0.2, 0.25) if d == "hard" else Color(0.55, 0.25, 0.3)))
		row.add_child(b)
	v.add_child(row)
	v.add_child(_rocket_rewards())
	return frame(menu, "rocket", UiKit.scroll(v))


## What a clear gives, and how much of each Rocket uniform you've earned.
static func _rocket_rewards() -> Control:
	var col := VBoxContainer.new()
	col.add_child(UiKit.label("REWARDS", 18, Color(1, 0.85, 0.4)))
	for d: String in ["normal", "hard"]:
		var c: Dictionary = Rocket.cfg("rewards/clear/" + d, {})
		var set_id := str(Rocket.cfg("rewards/outfit/" + d, ""))
		var owned := 0
		var pieces := Town.set_pieces(set_id, 0)
		for p: Array in pieces:
			if Town.owns_item(p[0], p[1], p[2]):
				owned += 1
		var line := UiKit.label("%s clear: %d ₽, %d coins, %d Rare Candy, %d Ultra Ball%s  ·  %s: %d/%d pieces (one per day)" % [
				d.capitalize(), int(c.get("money", 0)), int(c.get("coins", 0)), int(c.get("candies", 0)), (c.get("balls", []) as Array).size(),
				"" if (c.get("balls", []) as Array).size() == 1 else "s", str(Town.find_set(set_id).get("name", "")), owned, pieces.size()], 15)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)
	col.add_child(UiKit.label("First Hard clear ever: a Master Ball.  ·  Hideouts cleared: %d" % Rocket.clears(), 15, Color(0.85, 0.9, 1)))
	return _card(Color(0.22, 0.16, 0.22), col)


# --- Battle Arena: battles, Trainer Tower and the trainers in town ---------------------

static func arena(menu: Node) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var battle := UiKit.button("BATTLE\nquick matches · gyms · raids", menu.show_battle_modes, 30)
	battle.custom_minimum_size = Vector2(420, 150)
	battle.add_theme_stylebox_override("normal", UiKit.box(Color(0.95, 0.6, 0.15)))
	battle.add_theme_stylebox_override("hover", UiKit.box(Color(1.0, 0.68, 0.2)))
	row.add_child(battle)
	var floor := Town.tower_floor()
	var t := Town.tower_trainer(floor)
	var tower := VBoxContainer.new()
	tower.add_child(UiKit.label("TRAINER TOWER", 28, Color(1, 0.88, 0.4)))
	tower.add_child(UiKit.label("Floor %d  ·  best %d  ·  checkpoints every %d floors" % [floor, Town.tower_best(), int(Town.cfg("tower/checkpoint", 5))], 17))
	tower.add_child(UiKit.label("Next: %s %s  (%s)" % [t["class_name"], t["name"], _mode_title(str(t["mode"]))], 17, Color(0.85, 0.9, 1)))
	var climb := UiKit.button("CLIMB ›", func() -> void: menu.start_trainer_battle(t, 0, floor), 26)
	climb.add_theme_stylebox_override("normal", UiKit.box(Color(0.6, 0.35, 0.2)))
	tower.add_child(climb)
	row.add_child(_card(Color(0.35, 0.22, 0.15), tower))
	v.add_child(row)
	var rocket := UiKit.button("TEAM ROCKET HIDEOUT  ·  OPEN NOW! ›" if Rocket.is_open() else "TEAM ROCKET HIDEOUT  ·  back in %d day%s" % [Rocket.days_until_open(), "" if Rocket.days_until_open() == 1 else "s"], menu.show_rocket, 22)
	rocket.add_theme_stylebox_override("normal", UiKit.box(Color(0.6, 0.12, 0.2) if Rocket.is_open() else Color(0.3, 0.2, 0.24)))
	v.add_child(rocket)
	v.add_child(UiKit.section_title("TRAINERS IN TOWN  ·  new ones in %s" % _time(Town.slot_seconds_left())))
	v.add_child(trainer_list(menu))
	return frame(menu, "arena", UiKit.scroll(v))


static func trainer_list(menu: Node) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	for t: Dictionary in Town.wandering():
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(200, 0)
		col.add_child(trainer_picture(TrainerLook.npc_sheet(str(t["class"])), 100))
		col.add_child(UiKit.label("%s %s" % [t["class_name"], t["name"]], 17))
		col.add_child(UiKit.label("★".repeat(int(t["stars"])) + "☆".repeat(3 - int(t["stars"])), 20, Color(1, 0.85, 0.3)))
		var b := UiKit.button("BEATEN ✓" if t["beaten"] else "CHALLENGE", menu.show_trainer.bind(t), 18)
		b.disabled = bool(t["beaten"])
		col.add_child(b)
		flow.add_child(_card(Color(0.25, 0.3, 0.4), col))
	return flow


## Talking to a trainer: who they are, their team, and how much to bet.
static func trainer(menu: Node, t: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.button("‹ TOWN", menu.show_home))
	var title := UiKit.label("%s %s  %s" % [str(t["class_name"]).to_upper(), str(t["name"]).to_upper(), "★".repeat(int(t["stars"]))], 32, Color(1, 0.88, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UiKit.label("%d ₽" % Profile.money(), 28, Color(1, 0.95, 0.6)))
	v.add_child(top)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.add_child(trainer_picture(TrainerLook.npc_sheet(str(t["class"])), 260))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	var line := UiKit.label("\"%s\"" % t["line"], 24)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 560
	right.add_child(line)
	right.add_child(UiKit.label("%s  ·  %s" % [_mode_title(str(t["mode"])), str(GameData.arenas.get(t["arena"], {}).get("name", t["arena"]))], 20, Color(0.85, 0.9, 1)))
	var team := HBoxContainer.new()
	team.add_theme_constant_override("separation", 8)
	if bool(t.get("counter", false)):
		team.add_child(UiKit.label("Picks a team to beat yours!", 20, Color(1, 0.6, 0.5)))
	else:
		for id: String in t["team"]:
			team.add_child(PmdIcon.make(GameData.species[id], 90))
	right.add_child(team)
	right.add_child(UiKit.label("Their Pokémon: +%d levels over yours, %d%% HP" % [int(t["level_bonus"]), roundi(float(t["hp_scale"]) * 100)], 17))
	right.add_child(UiKit.section_title("YOUR BET  ·  win and it comes back double, plus %d ₽" % (int(Town.cfg("trainers/bonus_per_star", 100)) * int(t["stars"]))))
	var stakes := HBoxContainer.new()
	stakes.add_theme_constant_override("separation", 10)
	var options := Town.stakes(int(t["stars"]))
	for stake: int in options:
		var b := UiKit.button("FRIENDLY" if stake == 0 else "BET %d ₽" % stake, func() -> void: menu.start_trainer_battle(t, stake, 0), 22)
		b.custom_minimum_size = Vector2(170, 64)
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.3, 0.6, 0.35) if stake == 0 else Color(0.75, 0.55, 0.2)))
		stakes.add_child(b)
	if options.is_empty():
		stakes.add_child(UiKit.label("You can't cover this trainer's bet yet.", 20, Color(1, 0.6, 0.5)))
	right.add_child(stakes)
	if Town.cooling_off():
		right.add_child(UiKit.label("After three lost bets in a row, only small bets for a while. Take a breather!", 16, Color(1, 0.75, 0.5)))
	body.add_child(right)
	v.add_child(body)
	return v
