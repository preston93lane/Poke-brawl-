extends Node
## Autoload "Profile": the player's progress, saved on this device in
## user://profile.json (the browser's storage on the web build).
## Cloud accounts will sync this same data later.
##
## Levels are per evolution line, keyed by the base form's id (Charmander's
## level covers Charmeleon and Charizard too).
##
## Dev mode (all the testing tools) turns on with the dev code: open the game
## with ?dev=<code> on the end of its address, or type it in Settings.

const PATH := "user://profile.json"
## SHA-256 of the dev code, so the code itself isn't sitting in the game files.
const DEV_HASH := "168914d29ce1d0347e9d2087362ba12c34b24b178917987cdea6716c043c705b"

signal changed

var data: Dictionary = {}


func _ready() -> void:
	load_profile()
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		for part in query.trim_prefix("?").split("&"):
			if part.begins_with("dev="):
				try_dev_code(part.trim_prefix("dev=").uri_decode())


func load_profile() -> void:
	data = { "version": 1, "levels": {}, "dev": false }
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			data.merge(parsed, true)


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	changed.emit()


func reset() -> void:
	var dev := is_dev()
	data = { "version": 1, "levels": {}, "dev": dev }
	save()


# --- Levels ----------------------------------------------------------------

func max_level() -> int:
	return int(GameData.rule("trainer/max_level", 60))


func level_of(species_id: String) -> int:
	var levels: Dictionary = data.get("levels", {})
	return clampi(int(levels.get(GameData.family_root(species_id), 1)), 1, max_level())


func set_level(species_id: String, level: int) -> void:
	var levels: Dictionary = data.get("levels", {})
	levels[GameData.family_root(species_id)] = clampi(level, 1, max_level())
	data["levels"] = levels
	save()


func set_all_levels(level: int) -> void:
	var levels := {}
	for s in GameData.base_species():
		levels[s.id] = clampi(level, 1, max_level())
	data["levels"] = levels
	save()


# --- Dev mode --------------------------------------------------------------

func is_dev() -> bool:
	return bool(data.get("dev", false))


## Turns dev mode on if `code` is right; returns whether it was.
func try_dev_code(code: String) -> bool:
	if code.strip_edges().sha256_text() != DEV_HASH:
		return false
	data["dev"] = true
	save()
	return true


func set_dev(on: bool) -> void:
	data["dev"] = on
	save()
