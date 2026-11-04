class_name Quality
extends RefCounted
## Graphics quality (Settings → GRAPHICS): "low", "medium", "high", or "auto"
## (medium on phones and tablets, high on computers). Everything that costs
## frame time asks here.
##
##              shadows            grass     detail   particles  3D resolution  bots think
##   high       2 cascades, 50 m   swaying   full     100%       100%           every 2nd frame
##   medium     1 pass, 35 m       still     full     75%        100%           every 2nd frame
##   low        off (blob shadows) still     simpler  50%        75%            every 3rd frame

const LEVELS := ["auto", "low", "medium", "high"]


static func choice() -> String:
	var c := str(GameData.setting("graphics", "auto"))
	return c if c in LEVELS else "auto"


static func level() -> String:
	var c := choice()
	if c != "auto":
		return c
	var phone := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	return "medium" if phone else "high"


static func is_low() -> bool:
	return level() == "low"


static func shadows() -> bool:
	return level() != "low"


static func grass_sways() -> bool:
	return level() == "high"


static func particle_mult() -> float:
	return { "low": 0.5, "medium": 0.75 }.get(level(), 1.0)


static func render_scale() -> float:
	return 0.75 if level() == "low" else 1.0


static func bot_think_every() -> int:
	return 3 if level() == "low" else 2


## The sun's shadows for this level (none on low: Pokémon keep their blob shadows).
static func apply_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	match level():
		"low":
			sun.shadow_enabled = false
		"medium":
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 35.0
		_:
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 50.0


## Resolution and anti-aliasing for a viewport showing the 3D world.
static func apply_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	vp.scaling_3d_scale = render_scale()
	vp.msaa_3d = Viewport.MSAA_DISABLED if is_low() else Viewport.MSAA_2X


static func label() -> String:
	return "GRAPHICS: AUTO (%s)" % level().to_upper() if choice() == "auto" else "GRAPHICS: " + level().to_upper()


## A button that steps AUTO → LOW → MEDIUM → HIGH. Shadows and resolution change
## straight away (mid-match too); grass and trees on the next map.
static func cycle_button(font_size := 20) -> Button:
	var b := Button.new()
	b.text = label()
	b.add_theme_font_size_override("font_size", font_size)
	b.tooltip_text = "Lower = smoother on slower phones. LOW turns off shadows and draws fewer effects."
	b.pressed.connect(func() -> void:
		var next: String = LEVELS[(LEVELS.find(choice()) + 1) % LEVELS.size()]
		GameData.set_setting("graphics", next)
		b.text = label()
		var tree := b.get_tree()
		if tree and tree.current_scene:
			apply_sun(tree.current_scene.get_node_or_null("Sun") as DirectionalLight3D)
			apply_viewport(tree.root))
	return b


## Which things cast real shadows: everything solid on high; on medium only walls,
## rocks and the Pokémon (trees and bushes are the heaviest shapes to redraw for
## shadows); none on low (the sun's shadows are off).
static func casts_shadow(kind: String) -> bool:
	match level():
		"high":
			return kind != "grass"
		"medium":
			return kind in ["wall", "rock", "pokemon", "prop"]
	return false
