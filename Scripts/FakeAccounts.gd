class_name FakeAccounts
extends RefCounted
## Fake account database for the prototype login screen (Rooms/Login.tscn). NOT real security:
## it only exists so the game can start with a registration / login step.
##
## TURN OFF : set ENABLED = false (the login screen is skipped and goes straight to the title).
## REMOVE   : delete Rooms/Login.tscn, Scripts/LoginScreen.gd and this file, and set
##            Main.gd's start_room back to "title". Nothing else depends on them.
## DATA     : accounts are kept in a JSON file in the game's user (temporary) data folder, see PATH.
##            Passwords are stored salted + hashed, never as plain text. Set PERSIST = false to keep
##            accounts in memory only (they vanish when the game closes). The login screen also has
##            a "Clear saved accounts" button, or call FakeAccounts.wipe().
##
## After a login, FakeAccounts.current_user / current_id hold who is playing (any script can read them).

const ENABLED := true
const PERSIST := true
const PATH := "user://fake_accounts.json"

const NAME_PATTERN := "^[A-Za-z0-9_]{3,16}$"
const PASSWORD_MIN := 4
const PASSWORD_MAX := 32

static var current_user := ""
static var current_id := ""

static var _db := {}   # lower-case username -> {"name", "id", "salt", "hash"}
static var _loaded := false


static func count() -> int:
	_ensure_loaded()
	return _db.size()


## Returns "" on success (and logs the new account in), otherwise the error message to show.
static func register(user_name: String, password: String) -> String:
	_ensure_loaded()
	var err := _check(user_name, password)
	if err != "":
		return err
	var key := user_name.to_lower()
	if _db.has(key):
		return "That username is already registered."
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var salt := "%08x%08x" % [rng.randi(), rng.randi()]
	var id := "CDT-%04d" % (_db.size() + 1)
	_db[key] = {"name": user_name, "id": id, "salt": salt, "hash": _hash(salt, password)}
	_save()
	current_user = user_name
	current_id = id
	return ""


## Returns "" on success (and logs the account in), otherwise the error message to show.
static func login(user_name: String, password: String) -> String:
	_ensure_loaded()
	if user_name.strip_edges() == "" or password == "":
		return "Enter your username and password."
	var key := user_name.strip_edges().to_lower()
	var failed := "Unknown username or wrong password."
	if not _db.has(key):
		return failed
	var rec: Dictionary = _db[key]
	if _hash(str(rec.get("salt", "")), password) != str(rec.get("hash", "")):
		return failed
	current_user = str(rec.get("name", user_name))
	current_id = str(rec.get("id", "CDT-0000"))
	return ""


static func set_guest() -> void:
	current_user = "Guest"
	current_id = "CDT-GUEST"


## Deletes every saved account (and the file). Returns how many were removed.
static func wipe() -> int:
	_ensure_loaded()
	var n := _db.size()
	_db = {}
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	return n


static func _check(user_name: String, password: String) -> String:
	var re := RegEx.new()
	re.compile(NAME_PATTERN)
	if re.search(user_name) == null:
		return "Username must be 3-16 letters, numbers or _ (no spaces)."
	if password.length() < PASSWORD_MIN:
		return "Password must be at least %d characters." % PASSWORD_MIN
	if password.length() > PASSWORD_MAX:
		return "Password must be at most %d characters." % PASSWORD_MAX
	return ""


static func _hash(salt: String, password: String) -> String:
	return (salt + ":" + password).sha256_text()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not PERSIST or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_db = data


static func _save() -> void:
	if not PERSIST:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("FakeAccounts: could not write %s" % PATH)
		return
	f.store_string(JSON.stringify(_db, "\t"))
