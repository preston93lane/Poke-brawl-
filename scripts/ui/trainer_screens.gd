class_name TrainerScreens
extends RefCounted
## Menu screens for progression: picking a starter, the bag (open Poké Balls,
## see items and TMs) and the daily store. Each returns a Control for the
## menu's _set_screen(); `menu` is the menu (for going back and refreshing).

const RARITY_COLORS := {
	"common": Color(0.35, 0.38, 0.5), "uncommon": Color(0.25, 0.5, 0.35),
	"rare": Color(0.3, 0.4, 0.75), "featured": Color(0.7, 0.5, 0.15),
}


## First launch: choose one of the four starters (Pidgey and Rattata come free).
static func starter(menu: Node) -> Control:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	var title := UiKit.label("CHOOSE YOUR STARTER", 56, Color(1, 0.85, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var free: Array[String] = []
	for id: String in GameData.unlocks.get("free", []):
		free.append(GameData.species[id].display_name)
	var hint := UiKit.label("%s come with it. The other starters unlock at trainer levels 20, 40 and 60." % " and ".join(PackedStringArray(free)), 20, Color(0.8, 0.85, 1))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for id: String in GameData.unlocks.get("starters", []):
		var s: SpeciesData = GameData.species[id]
		var b := UiKit.button(s.display_name, func() -> void:
			Profile.choose_starter(id)
			menu.show_home(), 24)
		b.icon = s.sprite
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(190, 210)
		row.add_child(b)
	v.add_child(row)
	return v


static func _top(menu: Node, title: String) -> HBoxContainer:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.button("‹ BACK", menu.show_home))
	var label := UiKit.label(title, 30, Color(1, 0.85, 0.25))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	top.add_child(UiKit.label("%d ₽" % Profile.money(), 28, Color(1, 0.95, 0.6)))
	return top


## Bag: Poké Balls to open, then everything else you're carrying.
static func bag(menu: Node, last_prizes: Array[Dictionary] = []) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(_top(menu, "BAG"))
	if not last_prizes.is_empty():
		var got := PackedStringArray()
		for p in last_prizes:
			got.append(str(p["text"]))
		var panel := UiKit.panel(UiKit.label("You got:  " + "   ·   ".join(got), 22, Color(1, 0.9, 0.45)))
		v.add_child(panel)
	v.add_child(UiKit.label("POKé BALLS", 22, Color(0.8, 0.85, 1)))
	var balls := HFlowContainer.new()
	balls.add_theme_constant_override("h_separation", 10)
	for ball in Profile.BALLS:
		var n := Profile.count(ball)
		var b := UiKit.button("OPEN %s  (%d)" % [Profile.item_name(ball).to_upper(), n], func() -> void:
			var prizes := Profile.open_ball(ball)
			menu.play_ball_opening(ball, prizes), 20)
		b.disabled = n <= 0
		balls.add_child(b)
	v.add_child(balls)
	v.add_child(UiKit.label("ITEMS  (use Rare Candy, Vitamins and HMs on a Pokémon from its select screen)", 22, Color(0.8, 0.85, 1)))
	var items := PackedStringArray()
	for item: String in Profile.data.get("inventory", {}):
		if item not in Profile.BALLS and Profile.count(item) > 0:
			items.append("%s ×%d" % [Profile.item_name(item), Profile.count(item)])
	items.sort()
	var item_label := UiKit.label("   ·   ".join(items) if not items.is_empty() else "Nothing yet. Win matches to earn Poké Balls!", 20)
	item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(item_label)
	var tms: Array = Profile.data.get("tms", [])
	v.add_child(UiKit.label("TMs  (%d of %d; a TM teaches its move to every Pokémon that can learn it)" % [tms.size(), GameData.progression.get("tms", {}).size()], 22, Color(0.8, 0.85, 1)))
	var tm_names := PackedStringArray()
	for tm_id: String in tms:
		tm_names.append(Profile.item_name(tm_id).trim_prefix("TM "))
	tm_names.sort()
	var tm_label := UiKit.label(", ".join(tm_names) if not tm_names.is_empty() else "None yet.", 18, Color(0.85, 0.9, 1))
	tm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tm_label)
	return UiKit.scroll(v)


## Store: six slots that change every day, with daily limits per kind of item.
static func store(menu: Node, message := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(_top(menu, "POKé MART  ·  new stock every day"))
	if message != "":
		v.add_child(UiKit.label(message, 22, Color(0.6, 1, 0.6)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for slot: Dictionary in Profile.store_slots():
		var item := str(slot["item"])
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(250, 150)
		var rarity := str(slot["rarity"])
		card.add_child(UiKit.label(rarity.to_upper(), 14, Color(1, 1, 1, 0.7)))
		var name_label := UiKit.label(Profile.item_name(item), 24)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(name_label)
		var category := Profile.item_category(item)
		card.add_child(UiKit.label("Bought today %d / %d" % [Profile.bought_today(category), Profile.daily_cap(category)], 14, Color(0.85, 0.9, 1)))
		var why := Profile.cant_buy(item)
		var buy := UiKit.button("BUY  %d ₽" % Profile.item_price(item) if why == "" else "%d ₽ · %s" % [Profile.item_price(item), why.to_upper()], func() -> void:
			if Profile.buy(item):
				menu.show_store("Bought %s!" % Profile.item_name(item)), 20)
		buy.disabled = why != ""
		card.add_child(buy)
		var panel := UiKit.panel(card)
		panel.add_theme_stylebox_override("panel", UiKit.box(RARITY_COLORS.get(rarity, Color(0.3, 0.3, 0.4)), 14, 12))
		grid.add_child(panel)
	v.add_child(grid)
	var caps := PackedStringArray()
	for category: String in Profile.econ("store/daily_caps", {}):
		caps.append("%s %d" % [category.replace("_", " "), Profile.daily_cap(category)])
	v.add_child(UiKit.label("Daily limits: " + ", ".join(caps), 16, Color(0.75, 0.8, 0.9)))
	return UiKit.scroll(v)


## Account: sign in with an emailed code (or the emailed link) to save progress
## to the cloud; playing signed out keeps it on this device only.
static func account(menu: Node, message := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.add_child(_top(menu, "ACCOUNT"))
	if Cloud.signed_in():
		v.add_child(UiKit.label("Signed in as %s" % Cloud.email(), 26))
		var status := UiKit.label(Cloud.status, 18, Color(0.75, 0.85, 1))
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(status)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiKit.button("SYNC NOW", func() -> void:
			await Cloud.pull()
			menu.show_account(Cloud.status), 22))
		row.add_child(UiKit.button("SIGN OUT", func() -> void:
			await Cloud.sign_out()
			menu.show_account(Cloud.status), 22))
		v.add_child(row)
		return UiKit.scroll(v)
	var intro := UiKit.label("Sign in to save your progress online and play on any device. No password: we email you a 6-digit code (or tap the link in the email). You can keep playing without an account; progress then stays on this device.", 20, Color(0.85, 0.9, 1))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(intro)
	var email := LineEdit.new()
	email.placeholder_text = "you@example.com"
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	email.add_theme_font_size_override("font_size", 24)
	email.custom_minimum_size = Vector2(420, 56)
	email.text = str(menu.get_meta("account_email", ""))
	UiKit.web_typable(email, "Your email address")
	var code := LineEdit.new()
	code.placeholder_text = "6-digit code"
	code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code.add_theme_font_size_override("font_size", 24)
	code.custom_minimum_size = Vector2(240, 56)
	UiKit.web_typable(code, "The 6-digit code from the email")
	var feedback := UiKit.label(message, 20, Color(1, 0.85, 0.5))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	row1.add_child(email)
	row1.add_child(UiKit.button("EMAIL ME A CODE", func() -> void:
		menu.set_meta("account_email", email.text)
		feedback.text = "Sending..."
		var err: String = await Cloud.send_code(email.text)
		feedback.text = err if err != "" else "Check your email for the code (and the spam folder).", 20))
	v.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	row2.add_child(code)
	row2.add_child(UiKit.button("SIGN IN", func() -> void:
		feedback.text = "Signing in..."
		var err: String = await Cloud.verify_code(email.text, code.text)
		if err == "":
			menu.show_account(Cloud.status)
		else:
			feedback.text = err, 22))
	v.add_child(row2)
	v.add_child(feedback)
	return UiKit.scroll(v)


## Challenges: the trainer road (lines unlocked by trainer level), every
## challenge with its progress, the Master Ball milestones, and what's left in
## Poké Balls.
static func challenges(menu: Node) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_top(menu, "TRAINER LV %d  ·  CHALLENGES" % Profile.total_level()))
	var hint := UiKit.label("Trainer level = all your unlocked Pokémon's levels added up.", 18, Color(0.8, 0.85, 1))
	v.add_child(hint)
	var unlocked: Array = Profile.data.get("unlocked", [])

	v.add_child(_heading("TRAINER ROAD  (unlocked by trainer level)"))
	var road: Array = []
	var starter_levels: Array = GameData.unlocks.get("starter_levels", [20, 40, 60])
	var waiting: Array[String] = []
	for id: String in GameData.unlocks.get("starters", []):
		if id not in unlocked:
			waiting.append(id)
	var given := starter_levels.size() - waiting.size()
	for i in starter_levels.size():
		var label := "One of the starters you didn't pick"
		if i >= given and i - given < waiting.size():
			label = "Starter: " + GameData.species[waiting[i - given]].display_name
		road.append([int(starter_levels[i]), label, i < given, ""])
	for entry: Dictionary in GameData.unlocks.get("order", []):
		if entry.has("trainer_level"):
			var family: String = entry["family"]
			road.append([int(entry["trainer_level"]), GameData.species[family].display_name, family in unlocked, str(entry["area"])])
	road.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	for r in road:
		var done: bool = r[2]
		var color := Color(0.6, 1, 0.6) if done else (Color(1, 0.9, 0.5) if Profile.total_level() < int(r[0]) else Color.WHITE)
		grid.add_child(UiKit.label("LV %d" % int(r[0]), 18, color))
		grid.add_child(UiKit.label(str(r[1]), 18, color))
		grid.add_child(UiKit.label(str(r[3]), 16, Color(0.75, 0.8, 0.9)))
		grid.add_child(UiKit.label("✓ UNLOCKED" if done else "%d to go" % maxi(0, int(r[0]) - Profile.total_level()), 16, color))
	v.add_child(grid)

	v.add_child(_heading("CHALLENGES  (each unlocks a Pokémon and gives a Great Ball)"))
	for entry: Dictionary in GameData.unlocks.get("order", []):
		if not entry.has("challenge"):
			continue
		var family: String = entry["family"]
		var c: Dictionary = entry["challenge"]
		var done := family in unlocked
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiKit.sprite(GameData.species[family].sprite, 40))
		var name_label := UiKit.label(GameData.species[family].display_name, 19, Color(0.6, 1, 0.6) if done else Color.WHITE)
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
		var text := UiKit.label(str(c["text"]), 17, Color(0.85, 0.9, 1))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.x = 380
		row.add_child(text)
		row.add_child(_progress(Profile.challenge_progress(c), Profile.challenge_goal(c), done))
		v.add_child(row)
		if c.get("type", "") == "all" and not done:
			for part: Dictionary in c.get("parts", []):
				var sub := HBoxContainer.new()
				sub.add_theme_constant_override("separation", 12)
				var spacer := Control.new()
				spacer.custom_minimum_size.x = 202
				sub.add_child(spacer)
				var part_text := UiKit.label("• " + str(part["text"]), 15, Color(0.75, 0.8, 0.9))
				part_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				part_text.custom_minimum_size.x = 380
				sub.add_child(part_text)
				sub.add_child(_progress(Profile.challenge_progress(part), Profile.challenge_goal(part), Profile.challenge_done(part)))
				v.add_child(sub)

	v.add_child(_heading("MILESTONES  (a Master Ball each, once)"))
	var done_list: Array = Profile.data.get("milestones", [])
	var milestones := PackedStringArray()
	for lvl in Profile.econ("milestones/total_levels", []):
		milestones.append(("✓ " if "total_%d" % int(lvl) in done_list else "") + "Trainer level %d" % int(lvl))
	for gym: String in Profile.econ("milestones/gyms", []):
		milestones.append(("✓ " if "gym_" + gym in done_list else "") + "Win on Hard: %s" % str(GameData.arenas.get(gym, {}).get("name", gym)))
	var m_label := UiKit.label("   ·   ".join(milestones), 17)
	m_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(m_label)

	v.add_child(_heading("IN POKé BALLS  (the next one in Kanto order comes from a ball)"))
	var left := PackedStringArray()
	for entry: Dictionary in GameData.unlocks.get("order", []):
		if not entry.has("challenge") and not entry.has("trainer_level") and entry["family"] not in unlocked:
			left.append(GameData.species[entry["family"]].display_name)
	var ball_label := UiKit.label(("Next: %s   ·   still to find: %s" % [left[0], ", ".join(left.slice(1))]) if not left.is_empty() else "You've found them all!", 17)
	ball_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ball_label)
	return UiKit.scroll(v)


static func _heading(text: String) -> Label:
	var l := UiKit.label(text, 22, Color(1, 0.85, 0.4))
	l.add_theme_constant_override("outline_size", 3)
	return l


static func _progress(value: int, goal: int, done: bool) -> Control:
	var box := HBoxContainer.new()
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, goal)
	bar.value = mini(value, goal)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 16)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)
	var label := UiKit.label(" ✓ DONE" if done else " %d / %d" % [mini(value, goal), goal], 16, Color(0.6, 1, 0.6) if done else Color.WHITE)
	label.custom_minimum_size.x = 90
	box.add_child(label)
	return box
