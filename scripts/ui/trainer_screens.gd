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
	var hint := UiKit.label("%s come with it. The others unlock as you play." % " and ".join(PackedStringArray(free)), 20, Color(0.8, 0.85, 1))
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
			menu.show_bag(prizes), 20)
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
	var code := LineEdit.new()
	code.placeholder_text = "6-digit code"
	code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	code.add_theme_font_size_override("font_size", 24)
	code.custom_minimum_size = Vector2(240, 56)
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
