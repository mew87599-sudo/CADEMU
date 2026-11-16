extends CanvasLayer
## Autoload. The sequence that starts after the dream: waking up, Mission Control messages,
## sample retrieval, preparation, microscope, report, re-examination.
##
## Everything is driven by Objectives flags (set with Objectives.flag):
##   mc_briefing        the first Mission Control message arrived (sent a few seconds after the dream)
##   samples_retrieved  the right container was taken from storage (Scripts/Lab/SampleStorageMenu.gd)
##   samples_delivered  the container was placed on the examination table (LabBenchMenu)
##   samples_prepared   every specimen is on a slide under the microscope (LabBenchMenu)
##   samples_examined   every specimen was imaged and documented (LabBenchMenu)
##   report_submitted   the report was uploaded from the lab computer (LabComputerMenu)
##   recheck_requested  Mission Control asked for Sample 04 again (arrives after the report)
##   sample4_rechecked  Sample 04 was prepared and imaged again (it now looks ordinary)
##   second_uploaded    the second result was uploaded; the sequence is over
## The tablet objective list (Objectives.POST) and the yellow map dot follow these flags.
##
## Mission.send_comms("text")  shows a Mission Control message (click to continue).
## Mission.jump_to("stage")    sets all flags and state for a stage (used by the debug menu, Shift+F12).

signal sequence_complete

const MARKER_COLOR := Color(1.0, 0.85, 0.2)
# Rooms the yellow map dot points at (the map zone must be named after the room to light up).
const ROOM_STORAGE := "labinside2left"
const ROOM_BENCH := "microscopecloseup"
const ROOM_COMPUTER := "labinside2leftinto1"

const WAKE_DELAY := 4.0       # quiet seconds after waking up before the first message
const RESPONSE_DELAY := 3.0   # seconds between the report upload and Mission Control's answer
const SECOND_DELAY := 1.5
const BEEP := "res://Assets/Misc/beep.wav"

const MSG_BRIEFING := "Good morning, Cadet. One of your crewmates has just returned from an exterior survey with a batch of geological samples.\n\nThey've been deposited in the sample storage compartment. Please retrieve them and bring them to the laboratory for examination.\n\nWe need the analysis results before the next scheduled survey."
const MSG_RESPONSE := "Analysis report received. We've reviewed the results.\n\nEverything appears consistent except Sample 04. Its readings seem to be inconsistent with the rest of the collection.\n\nCould you repeat the examination and verify the results?"
const MSG_SECOND := "Second examination received. Thank you, Cadet. We'll review the discrepancy."

## The four specimens. "kind" picks how the microscope draws it (Scripts/Lab/SpecimenView.gd).
const SAMPLES := [
	{"id": 1, "name": "Basalt", "survey": "SRV-0412-A", "kind": "basalt", "note": "Dark mineral structures, crystalline formations"},
	{"id": 2, "name": "Anorthosite", "survey": "SRV-0412-B", "kind": "anorthosite", "note": "Light crystalline structures, mostly feldspar"},
	{"id": 3, "name": "Regolith", "survey": "SRV-0412-C", "kind": "regolith", "note": "Fine irregular particles, fragmented mineral grains"},
	{"id": 4, "name": "Unknown composition", "survey": "SRV-0412-D", "kind": "unknown", "note": "Unidentified structures, needs more examination"},
]
## Classifications the lab computer offers (index 0 = not chosen yet).
const CLASSES := ["- select -", "Basalt", "Anorthosite", "Regolith", "Unknown composition"]

## Progress stages for the debug menu. Each stage includes everything before it.
const STAGES := [
	{"id": "fresh", "label": "New game (nothing done)", "flags": []},
	{"id": "console", "label": "Console opened", "flags": ["console_opened"]},
	{"id": "statusreport", "label": "Status report run", "flags": ["status_report"]},
	{"id": "repaired", "label": "All 5 repairs done", "flags": []},
	{"id": "sleepy", "label": "'You are sleepy' (go to bed)", "flags": ["sleepy"]},
	{"id": "dream", "label": "Dream seen (back in your room)", "flags": ["dream_seen"]},
	{"id": "briefing", "label": "Mission Control briefing", "flags": ["mc_briefing"]},
	{"id": "retrieved", "label": "Samples retrieved", "flags": ["samples_retrieved"]},
	{"id": "delivered", "label": "Samples on the table", "flags": ["samples_delivered"]},
	{"id": "prepared", "label": "Samples prepared", "flags": ["samples_prepared"]},
	{"id": "examined", "label": "Samples examined", "flags": ["samples_examined"]},
	{"id": "reported", "label": "Report sent, recheck asked", "flags": ["report_submitted", "recheck_requested"]},
	{"id": "rechecked", "label": "Sample 04 rechecked", "flags": ["sample4_rechecked"]},
	{"id": "complete", "label": "Second result uploaded (end)", "flags": ["second_uploaded"]},
]

# Per-specimen state, shared by the three lab menus.
var prepared := {}     # id -> true once on a slide under the microscope
var examined := {}     # id -> true once documented
var captures := {}     # id -> number of images taken (Sample 04 needs two the first time)
var classified := {}   # id -> index into CLASSES chosen on the lab computer
var processed := false # the computer has run its database match
var recheck := false   # second examination of Sample 04 only
var lens_clean := false
var specimens_returned := false
var upload_failed_once := false

var _panel: Panel
var _body: RichTextLabel
var _hint: Label
var _queue: Array = []
var _showing := false
var _typing := false
var _tween: Tween
var _current_cb := Callable()
var _beep: AudioStreamPlayer
var _marked := ""


func _ready() -> void:
	layer = 23   # above menus (20) and story messages (22), below the room transition (25)
	_build_comms()
	Story.dream_finished.connect(_on_dream_finished)
	Objectives.changed.connect(_update_markers)


# --- sample state ------------------------------------------------------------------

func sample(id: int) -> Dictionary:
	for s in SAMPLES:
		if s.id == id:
			return s
	return {}


## The specimens being worked on: all four, or only Sample 04 during the re-examination.
func active_ids() -> Array:
	return [4] if recheck else [1, 2, 3, 4]


func all_prepared() -> bool:
	for id in active_ids():
		if not prepared.get(id, false):
			return false
	return true


func all_examined() -> bool:
	for id in active_ids():
		if not examined.get(id, false):
			return false
	return true


func begin_recheck() -> void:
	recheck = true
	prepared.erase(4)
	examined.erase(4)
	captures.erase(4)


func reset_state() -> void:
	prepared.clear()
	examined.clear()
	captures.clear()
	classified.clear()
	processed = false
	recheck = false
	lens_clean = false
	specimens_returned = false
	upload_failed_once = false


# --- story steps called by the menus -------------------------------------------------

func submit_report() -> void:
	Objectives.flag("report_submitted")
	await get_tree().create_timer(RESPONSE_DELAY).timeout
	if Objectives.has_flag("recheck_requested") or not Objectives.has_flag("report_submitted"):
		return
	begin_recheck()
	send_comms(MSG_RESPONSE)
	Objectives.flag("recheck_requested")


func upload_second() -> void:
	Objectives.flag("second_uploaded")
	await get_tree().create_timer(SECOND_DELAY).timeout
	if not Objectives.has_flag("second_uploaded"):
		return
	send_comms(MSG_SECOND)
	sequence_complete.emit()


func _on_dream_finished() -> void:
	if Objectives.has_flag("mc_briefing"):
		return
	await get_tree().create_timer(WAKE_DELAY).timeout
	if Objectives.has_flag("mc_briefing"):
		return
	Objectives.flag("mc_briefing")
	send_comms(MSG_BRIEFING)


# --- yellow map dot -------------------------------------------------------------------

func _target_room() -> String:
	if not Objectives.has_flag("mc_briefing") or Objectives.has_flag("second_uploaded"):
		return ""
	if not Objectives.has_flag("samples_retrieved"):
		return ROOM_STORAGE
	if not Objectives.has_flag("samples_examined"):
		return ROOM_BENCH
	if not Objectives.has_flag("report_submitted"):
		return ROOM_COMPUTER
	if Objectives.has_flag("recheck_requested") and not Objectives.has_flag("sample4_rechecked"):
		return ROOM_BENCH
	if Objectives.has_flag("sample4_rechecked"):
		return ROOM_COMPUTER
	return ""


func _update_markers() -> void:
	var room := _target_room()
	if room == _marked:
		return
	if _marked != "":
		Tablet.clear_marker(_marked)
	_marked = room
	if room != "":
		Tablet.set_marker(room, MARKER_COLOR)


# --- debug: jump to a stage --------------------------------------------------------------

func stage_index(stage_id: String) -> int:
	for i in STAGES.size():
		if STAGES[i].id == stage_id:
			return i
	return -1


func jump_to(stage_id: String) -> void:
	var idx := stage_index(stage_id)
	if idx < 0:
		push_error("Mission.jump_to: unknown stage '%s'" % stage_id)
		return
	Overlay.close()
	clear_comms()
	Story.reset()
	Objectives.flags.clear()
	reset_state()
	if _marked != "":
		Tablet.clear_marker(_marked)
		_marked = ""
	for i in range(idx + 1):
		for f in STAGES[i].flags:
			Objectives.flags[f] = true
	_apply_state(idx)
	Subsystems.debug_reset_all()
	if idx >= stage_index("repaired"):
		Subsystems.debug_set_progress(5)   # flags are set first, so Story does not repeat its messages
	if Objectives.has_flag("sleepy") and not Objectives.has_flag("dream_seen"):
		Tablet.set_marker(Story.SLEEP_ROOM, Story.MARKER_COLOR)
	Objectives.changed.emit()
	_update_markers()


func _apply_state(idx: int) -> void:
	if idx >= stage_index("prepared"):
		for s in SAMPLES:
			prepared[s.id] = true
	if idx >= stage_index("examined"):
		for s in SAMPLES:
			examined[s.id] = true
			captures[s.id] = 1
	if idx >= stage_index("reported"):
		processed = true
		for s in SAMPLES:
			classified[s.id] = s.id
		begin_recheck()
	if idx >= stage_index("rechecked"):
		prepared[4] = true
		examined[4] = true
		captures[4] = 1


# --- Mission Control message box ---------------------------------------------------------

func _build_comms() -> void:
	_panel = LabUI.panel(self, Vector2(100, 8), Vector2(440, 176), Color(1.0, 0.8, 0.3))
	_panel.visible = false
	_panel.gui_input.connect(_on_panel_input)
	LabUI.label(_panel, "MISSION CONTROL - INCOMING MESSAGE", Vector2(12, 8), Vector2(416, 16), 11, LabUI.WARN)
	_body = LabUI.rich(_panel, Vector2(12, 30), Vector2(416, 120), 10)
	_body.scroll_active = false
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = LabUI.label(_panel, "click to continue", Vector2(12, 156), Vector2(416, 14), 9, LabUI.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_beep = AudioStreamPlayer.new()
	if ResourceLoader.exists(BEEP):
		_beep.stream = load(BEEP)
	add_child(_beep)


func send_comms(text: String, on_closed: Callable = Callable()) -> void:
	_queue.append({"text": text, "cb": on_closed})
	if not _showing:
		_show_next()


func clear_comms() -> void:
	_queue.clear()
	_showing = false
	_typing = false
	if _tween:
		_tween.kill()
	_panel.visible = false


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		_panel.visible = false
		return
	_showing = true
	var m: Dictionary = _queue.pop_front()
	_current_cb = m.cb
	_body.text = m.text
	_body.visible_ratio = 0.0
	_hint.visible = false
	_panel.modulate.a = 0.0
	_panel.visible = true
	if _beep.stream != null:
		_beep.play()
	_typing = true
	var duration := maxf(1.0, String(m.text).length() * 0.02)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, 0.4)
	_tween.tween_property(_body, "visible_ratio", 1.0, duration)
	_tween.tween_callback(_finish_typing)


func _finish_typing() -> void:
	_typing = false
	_body.visible_ratio = 1.0
	_hint.visible = true


func _on_panel_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _typing:
		if _tween:
			_tween.kill()
		_panel.modulate.a = 1.0
		_finish_typing()
		return
	var cb := _current_cb
	_current_cb = Callable()
	_panel.visible = false
	if cb.is_valid():
		cb.call()
	_show_next()
