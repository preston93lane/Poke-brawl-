extends Node
## Autoload "Cloud": accounts and cloud saves through Supabase.
##
## Sign in with your email: Supabase emails a 6-digit code (type it in) and a
## link (tap it to open the game signed in). Once signed in, your profile is
## loaded from the cloud and every change is saved back a few seconds later,
## so progress follows you between devices. Playing without signing in keeps
## progress on this device only.
##
## The database table and rules are in tools/supabase_setup.sql. The dev
## account's "is_dev" flag is set there and turns on dev mode when it signs in.

const URL := "https://jspnmcweqzzeliqiznxb.supabase.co"
## Publishable key: safe to ship in the game (row security protects the data).
const KEY := "sb_publishable_cae3KiTtABkKza2cuLvF8A_6piOwHTT"
const SITE := "https://preston93lane.github.io/Poke-brawl-/"
const SESSION_PATH := "user://session.json"
## Wait this long after the last change before uploading (saves batch up).
const PUSH_DELAY := 3.0

signal status_changed(text: String)

var session: Dictionary = {}
var status := ""
var _push_timer := -1.0
var _pulling := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_session()
	Profile.changed.connect(_on_profile_changed)
	if OS.has_feature("web"):
		_read_link_tokens()
	if signed_in():
		await _refresh_if_needed()
		await pull()


func signed_in() -> bool:
	return session.has("access_token") and session.has("user")


func email() -> String:
	return str(session.get("user", {}).get("email", ""))


func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)


func _process(delta: float) -> void:
	if _push_timer > 0.0:
		_push_timer -= delta
		if _push_timer <= 0.0:
			push()


func _on_profile_changed() -> void:
	if signed_in() and not _pulling:
		_push_timer = PUSH_DELAY


# --- Sign in ---------------------------------------------------------------------

## Emails a sign-in code and link. Returns "" on success, else an error message.
func send_code(address: String) -> String:
	var res := await _request("/auth/v1/otp?redirect_to=" + SITE.uri_encode(), HTTPClient.METHOD_POST,
			{ "email": address.strip_edges(), "create_user": true }, false)
	if int(res["code"]) >= 200 and int(res["code"]) < 300:
		_set_status("Code sent to %s" % address.strip_edges())
		return ""
	return _error_text(res)


## Signs in with the 6-digit code from the email.
func verify_code(address: String, code: String) -> String:
	var res := await _request("/auth/v1/verify", HTTPClient.METHOD_POST,
			{ "type": "email", "email": address.strip_edges(), "token": code.strip_edges() }, false)
	if int(res["code"]) == 200 and res["body"] is Dictionary and (res["body"] as Dictionary).has("access_token"):
		_take_session(res["body"])
		await pull(true)
		return ""
	return _error_text(res)


func sign_out() -> void:
	if signed_in():
		await _request("/auth/v1/logout", HTTPClient.METHOD_POST, {}, true)
	session = {}
	DirAccess.remove_absolute(SESSION_PATH)
	_set_status("Signed out. Progress now saves on this device only.")


## The emailed link opens the game with #access_token=...&refresh_token=... in the address.
func _read_link_tokens() -> void:
	var hash_text := str(JavaScriptBridge.eval("window.location.hash", true)).trim_prefix("#")
	if "access_token=" not in hash_text:
		return
	var params := {}
	for part in hash_text.split("&"):
		var kv := part.split("=", true, 1)
		if kv.size() == 2:
			params[kv[0]] = kv[1].uri_decode()
	JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname + window.location.search)", true)
	session = { "access_token": params.get("access_token", ""), "refresh_token": params.get("refresh_token", ""),
			"expires_at": Time.get_unix_time_from_system() + float(params.get("expires_in", "3600")) }
	var res := await _request("/auth/v1/user", HTTPClient.METHOD_GET, null, true)
	if int(res["code"]) == 200 and res["body"] is Dictionary:
		session["user"] = res["body"]
		_save_session()
		await pull(true)
	else:
		session = {}


func _take_session(body: Dictionary) -> void:
	session = {
		"access_token": body.get("access_token", ""), "refresh_token": body.get("refresh_token", ""),
		"expires_at": Time.get_unix_time_from_system() + float(body.get("expires_in", 3600)),
		"user": body.get("user", {}),
	}
	_save_session()


func _refresh_if_needed() -> void:
	if not signed_in() or Time.get_unix_time_from_system() < float(session.get("expires_at", 0)) - 120.0:
		return
	var res := await _request("/auth/v1/token?grant_type=refresh_token", HTTPClient.METHOD_POST,
			{ "refresh_token": session.get("refresh_token", "") }, false)
	if int(res["code"]) == 200 and res["body"] is Dictionary:
		_take_session(res["body"])
	elif int(res["code"]) in [400, 401, 403]:
		session = {}
		DirAccess.remove_absolute(SESSION_PATH)
		_set_status("Please sign in again.")


# --- Sync --------------------------------------------------------------------------

## Loads the cloud save. On first sign-in on a device (`first`), keeps whichever
## save has played more matches; afterwards the newer one wins.
func pull(first := false) -> void:
	if not signed_in():
		return
	await _refresh_if_needed()
	_pulling = true
	var uid := str(session["user"].get("id", ""))
	var res := await _request("/rest/v1/profiles?id=eq.%s&select=data,is_dev" % uid, HTTPClient.METHOD_GET, null, true)
	if int(res["code"]) != 200 or not res["body"] is Array:
		_pulling = false
		_set_status("Couldn't reach the cloud save (%s)" % _error_text(res))
		return
	var rows: Array = res["body"]
	if rows.is_empty():
		_pulling = false
		_set_status("Signed in as %s. Uploading your progress..." % email())
		await push()
		await _pull_dev_flag()
		return
	var row: Dictionary = rows[0]
	var remote: Dictionary = row.get("data", {}) if row.get("data") is Dictionary else {}
	var local := Profile.data
	var remote_matches := int(remote.get("stats", {}).get("matches", 0))
	var local_matches := int(local.get("stats", {}).get("matches", 0))
	var take_remote := remote_matches >= local_matches if first else float(remote.get("updated", 0)) > float(local.get("updated", 0))
	var dev := Profile.is_dev() or bool(row.get("is_dev", false))
	if take_remote and not remote.is_empty():
		Profile.replace_data(remote, false)
	Profile.data["dev"] = dev
	Profile.save()
	_pulling = false
	if not take_remote:
		await push()
	_set_status("Signed in as %s%s · progress saved to the cloud" % [email(), "  (dev)" if dev else ""])


func _pull_dev_flag() -> void:
	var uid := str(session["user"].get("id", ""))
	var res := await _request("/rest/v1/profiles?id=eq.%s&select=is_dev" % uid, HTTPClient.METHOD_GET, null, true)
	if int(res["code"]) == 200 and res["body"] is Array and not (res["body"] as Array).is_empty():
		if bool((res["body"] as Array)[0].get("is_dev", false)) and not Profile.is_dev():
			_pulling = true
			Profile.set_dev(true)
			_pulling = false
	_set_status("Signed in as %s%s · progress saved to the cloud" % [email(), "  (dev)" if Profile.is_dev() else ""])


func push() -> void:
	_push_timer = -1.0
	if not signed_in():
		return
	await _refresh_if_needed()
	if not signed_in():
		return
	var body := { "id": str(session["user"].get("id", "")), "data": Profile.data }
	var res := await _request("/rest/v1/profiles", HTTPClient.METHOD_POST, body, true,
			["Prefer: resolution=merge-duplicates,return=minimal"])
	if int(res["code"]) >= 300:
		_set_status("Cloud save failed (%s); will retry" % _error_text(res))
		_push_timer = 30.0


# --- HTTP ----------------------------------------------------------------------------

## Returns { "code": int, "body": Variant }.
func _request(path: String, method: int, body: Variant, auth: bool, extra_headers: Array = []) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["apikey: " + KEY, "Content-Type: application/json"])
	if auth and session.has("access_token"):
		headers.append("Authorization: Bearer " + str(session["access_token"]))
	for h in extra_headers:
		headers.append(str(h))
	var err := http.request(URL + path, headers, method, JSON.stringify(body) if body != null else "")
	if err != OK:
		http.queue_free()
		return { "code": 0, "body": "request failed (%d)" % err }
	var result: Array = await http.request_completed
	http.queue_free()
	var text := (result[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return { "code": int(result[1]), "body": parsed if parsed != null else text }


static func _error_text(res: Dictionary) -> String:
	var body: Variant = res.get("body")
	if body is Dictionary:
		for key in ["msg", "message", "error_description", "error"]:
			if (body as Dictionary).has(key):
				return str(body[key])
	if int(res.get("code", 0)) == 0:
		return "no connection"
	return "error %d" % int(res.get("code", 0))


func _load_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
		if parsed is Dictionary:
			session = parsed


func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(session))
		f.close()
