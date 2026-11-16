extends Node
## Autoload. State of the five outpost subsystems and the outpost power.
##
## Every subsystem starts OFFLINE ("flavor" is only extra text, e.g. NO CONNECTION).
## A repair minigame calls Subsystems.complete("ERR-00X") when it is won: that flips the
## subsystem to ONLINE and adds 20% to the power meter. When all five are ONLINE, `powered`
## becomes true and `outpost_powered` is emitted.
## The terminal's status report and the StatusPanelMenu read this data.
##
## Debug helpers (also available as hidden terminal commands, see TerminalMenu.gd):
##   debug_complete(id), debug_reset_all(), debug_set_progress(n), debug_mode

signal status_changed(id: String)
signal outpost_powered

const IDS := ["ERR-001", "ERR-002", "ERR-003", "ERR-004", "ERR-005"]

const START := {
	"ERR-001": {"name": "Radiation shield subsystem", "flavor": "OFFLINE"},
	"ERR-002": {"name": "Oxygen management subsystem", "flavor": "UNAVAILABLE"},
	"ERR-003": {"name": "Power collection manager", "flavor": "UNAVAILABLE"},
	"ERR-004": {"name": "Crew vital signs monitor", "flavor": "OFFLINE"},
	"ERR-005": {"name": "External terminal network", "flavor": "NO CONNECTION"},
}

var subsystems := {}
var powered := false
var debug_mode := false       # lets finished minigames be replayed
var reduced_motion := false   # accessibility: no pulses, shakes or flicker

const SOLVED_SOUND := "res://Assets/Misc/bling.wav"
var _solved_sfx: AudioStreamPlayer


func _ready() -> void:
	_reset_data()
	_solved_sfx = AudioStreamPlayer.new()
	if ResourceLoader.exists(SOLVED_SOUND):
		_solved_sfx.stream = load(SOLVED_SOUND)
	_solved_sfx.volume_db = -3.0
	add_child(_solved_sfx)


func _reset_data() -> void:
	subsystems.clear()
	for id in IDS:
		subsystems[id] = {"name": START[id].name, "status": "OFFLINE", "flavor": START[id].flavor}
	powered = false


## Accepts "ERR-002", "err_002", " ERR_002 ".
func norm(id: String) -> String:
	return id.strip_edges().to_upper().replace("_", "-")


func has_id(id: String) -> bool:
	return subsystems.has(norm(id))


func is_online(id: String) -> bool:
	return has_id(id) and subsystems[norm(id)].status == "ONLINE"


func online_count() -> int:
	var n := 0
	for id in IDS:
		if subsystems[id].status == "ONLINE":
			n += 1
	return n


func power_percent() -> int:
	return online_count() * 20


## [[id, name, status, flavor], ...] in order.
func rows() -> Array:
	var out: Array = []
	for id in IDS:
		var s: Dictionary = subsystems[id]
		out.append([id, s.name, s.status, s.flavor if s.status == "OFFLINE" else ""])
	return out


## onComplete(subsystemId)
func complete(id: String) -> void:
	id = norm(id)
	if not subsystems.has(id):
		push_error("Subsystems.complete: unknown subsystem '%s'" % id)
		return
	if subsystems[id].status == "ONLINE":
		return
	subsystems[id].status = "ONLINE"
	# The "error solved" sound: plays once per subsystem, here (not in the debug helpers that set
	# several at once). This node is an autoload, so it keeps playing after the menu closes.
	if _solved_sfx.stream != null:
		_solved_sfx.play()
	status_changed.emit(id)
	if online_count() == IDS.size() and not powered:
		powered = true
		outpost_powered.emit()


func debug_complete(id: String) -> void:
	complete(id)


func debug_reset_all() -> void:
	_reset_data()
	for id in IDS:
		status_changed.emit(id)


## First n subsystems ONLINE, the rest OFFLINE.
func debug_set_progress(n: int) -> void:
	_reset_data()
	for i in IDS.size():
		if i < clampi(n, 0, IDS.size()):
			subsystems[IDS[i]].status = "ONLINE"
	powered = online_count() == IDS.size()
	for id in IDS:
		status_changed.emit(id)
	if powered:
		outpost_powered.emit()
