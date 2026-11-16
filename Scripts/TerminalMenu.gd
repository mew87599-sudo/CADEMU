extends Control
## Command-center terminal, opened over the room through Overlay (Hotspot > Menu Scene).
## Left: a fake CADEMU monitor console. Right: the sticky note with the commands.
##
## Output is a queue of lines printed one by one (typewriter feel, with timestamps, progress
## bars and a boot log). Click the screen to skip the animation. The transcript and the unfinished
## queue are `static`, so closing and re-opening the terminal keeps everything where it was.
##
## Edit the text in the constants below. Commands live in _submit().

const PROMPT := "CADEMU\\MONITOR>"
const HOST := "CADEMU-MAIN-CONSOLE"
const BUILD := "7.2.114"
const UPTIME_OFFSET := 15420  # seconds added to game time so the console looks long-running
const FONT_SIZE := 9
const MAX_LINES := 300

const BASE_COLOR := Color(0.25, 0.9, 0.4)
const DIM_COLOR := Color(0.28, 0.52, 0.34)
const ERR_COLOR := Color(1.0, 0.38, 0.35)
const WARN_COLOR := Color(1.0, 0.78, 0.25)
const OK_COLOR := Color(0.6, 1.0, 0.7)
const WHITE_COLOR := Color(0.88, 1.0, 0.92)

# PLACEHOLDER data for data_diver_protocol.exe: replace with the real story data.
const DIVER_ROWS := [
	["01", "CREW-LOG", "12 KB", "PENDING UPLOAD"],
	["02", "ENV-SENSOR", "48 KB", "PENDING UPLOAD"],
	["03", "MAINT-NOTE", "1 KB", "FLAGGED"],
]

const STICKY := """[font_size=13]REMINDER![/font_size]
Don't forget the commands.
1. Check system status
[color=#14307a][url=systemscfg /statusreport]systemscfg /statusreport[/url][/color]
2. Check submitted data
Viper, run:
[color=#14307a][url=data_diver_protocol.exe]data_diver_protocol.exe[/url][/color]
Don't break anything this time.
— M."""

# Shared between opens of the terminal.
static var _transcript: Array = []   # {"ts": String, "t": String, "c": Color}
static var _queue: Array = []        # {"t", "c", "ts", "d", "replace"}
static var _history: PackedStringArray = PackedStringArray()
static var _booted := false

var _out: RichTextLabel
var _in: LineEdit
var _wait := 0.0
var _skip := false
var _busy := false
var _dirty := false
var _scroll_pending := false
var _hist_pos := 0


func _input(event: InputEvent) -> void:
	# Right click anywhere closes the menu (panels would otherwise swallow it).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Overlay.close()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Objectives.flag("console_opened")
	_build_ui()
	_hist_pos = _history.size()
	if not _booted:
		_booted = true
		_queue_boot()
	_busy = not _queue.is_empty()
	_set_input(not _busy)
	_dirty = true


# --- UI --------------------------------------------------------------------------

func _build_ui() -> void:
	var mono := MonoFont.get_font()

	var frame := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.02)
	style.border_color = Color(0.45, 0.47, 0.45)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	frame.add_theme_stylebox_override("panel", style)
	frame.position = Vector2(14, 14)
	frame.size = Vector2(396, 322)
	add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	frame.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	_out = RichTextLabel.new()
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.focus_mode = Control.FOCUS_NONE
	_out.selection_enabled = false
	_out.add_theme_font_override("normal_font", mono)
	_out.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_out.add_theme_constant_override("line_separation", 1)
	_out.gui_input.connect(_on_out_input)
	box.add_child(_out)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)

	var prompt := Label.new()
	prompt.text = PROMPT
	prompt.add_theme_font_override("font", mono)
	prompt.add_theme_font_size_override("font_size", FONT_SIZE)
	prompt.add_theme_color_override("font_color", WHITE_COLOR)
	row.add_child(prompt)

	_in = LineEdit.new()
	_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_in.max_length = 64
	_in.caret_blink = true
	_in.context_menu_enabled = false
	_in.add_theme_font_override("font", mono)
	_in.add_theme_font_size_override("font_size", FONT_SIZE)
	_in.add_theme_color_override("font_color", WHITE_COLOR)
	_in.add_theme_color_override("font_uneditable_color", DIM_COLOR)
	_in.add_theme_color_override("caret_color", WHITE_COLOR)
	for style_name in ["normal", "focus", "read_only"]:
		_in.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_in.text_submitted.connect(_submit)
	_in.gui_input.connect(_on_in_input)
	row.add_child(_in)

	var close := Button.new()
	close.text = "X"
	close.position = Vector2(606, 8)
	close.size = Vector2(26, 18)
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(func(): Overlay.close())
	add_child(close)

	var hint := Label.new()
	hint.text = "Click the screen to skip text  |  Right click or Esc: close"
	hint.position = Vector2(16, 339)
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	add_child(hint)

	var note := ColorRect.new()
	note.color = Color(1.0, 0.95, 0.1)
	note.position = Vector2(428, 44)
	note.size = Vector2(192, 172)
	note.pivot_offset = note.size / 2.0
	note.rotation = -0.035
	add_child(note)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.scroll_active = false
	text.position = Vector2(9, 8)
	text.size = Vector2(174, 158)
	text.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	text.add_theme_font_size_override("normal_font_size", 10)
	text.text = STICKY
	text.meta_clicked.connect(_on_note_link)
	note.add_child(text)


func _on_note_link(meta: Variant) -> void:
	# Clicking a command on the sticky note types it into the prompt (still needs Enter).
	_in.text = str(meta)
	_in.caret_column = _in.text.length()
	if _in.editable:
		_in.grab_focus()


func _on_out_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _busy:
			_skip = true
		else:
			_in.grab_focus()


func _on_in_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_UP and _hist_pos > 0:
		_hist_pos -= 1
		_in.text = _history[_hist_pos]
		_in.caret_column = _in.text.length()
		_in.accept_event()
	elif event.keycode == KEY_DOWN and _hist_pos < _history.size():
		_hist_pos += 1
		_in.text = _history[_hist_pos] if _hist_pos < _history.size() else ""
		_in.caret_column = _in.text.length()
		_in.accept_event()


func _set_input(on: bool) -> void:
	_in.editable = on
	if on:
		_in.grab_focus.call_deferred()


# --- printing queue --------------------------------------------------------------

func _process(delta: float) -> void:
	if _scroll_pending:
		_scroll_pending = false
		var bar := _out.get_v_scroll_bar()
		bar.value = bar.max_value

	if _queue.is_empty():
		if _busy:
			_busy = false
			_skip = false
			_set_input(true)
	else:
		if not _busy:
			_busy = true
			_set_input(false)
		_wait -= delta
		var guard := 0
		while _wait <= 0.0 and not _queue.is_empty() and guard < 500:
			var item: Dictionary = _queue.pop_front()
			_emit(item)
			_wait += 0.0 if _skip else float(item.d)
			guard += 1

	if _dirty:
		_dirty = false
		_refresh()


func _say(text := "", delay := 0.05, stamp := false, color = null) -> void:
	_queue.append({"t": text, "c": color, "ts": stamp, "d": delay, "replace": false})


## Progress bar that redraws itself in place.
func _bar(label: String, steps := 10, delay := 0.07, stamp := true) -> void:
	for i in range(steps + 1):
		var filled := int(round(20.0 * i / steps))
		var line := "%s [%s%s] %3d%%" % [label, "#".repeat(filled), ".".repeat(20 - filled), int(100.0 * i / steps)]
		_queue.append({"t": line, "c": null, "ts": stamp, "d": delay, "replace": i > 0})


func _emit(item: Dictionary) -> void:
	var text: String = item.t
	var color: Color = item.c if item.c != null else _auto_color(text)
	var entry := {"ts": _stamp() if item.ts else "", "t": text, "c": color}
	if item.replace and not _transcript.is_empty():
		_transcript[_transcript.size() - 1] = entry
	else:
		_transcript.append(entry)
	if _transcript.size() > MAX_LINES:
		_transcript.pop_front()
	_dirty = true


func _refresh() -> void:
	_out.clear()
	for e in _transcript:
		if e.ts != "":
			_out.push_color(DIM_COLOR)
			_out.add_text("[%s] " % e.ts)
			_out.pop()
		_out.push_color(e.c)
		_out.add_text(e.t)
		_out.pop()
		_out.newline()
	_scroll_pending = true


func _auto_color(s: String) -> Color:
	var u := s.to_upper()
	if u.begins_with("[NET") or u.begins_with("[WARN") or u.begins_with("[ACTION") or u.contains("DEGRADED") or u.contains("UNREACHABLE"):
		return WARN_COLOR
	if u.begins_with("[ERR") or u.contains("OFFLINE") or u.contains("UNAVAILABLE") or u.contains("NO CONNECTION") or u.contains("FAIL") or u.contains("FLAGGED"):
		return ERR_COLOR
	if u.contains(" ONLINE") or u.contains("] OK") or u.ends_with(" OK") or u.contains("COMPLETE"):
		return OK_COLOR
	return BASE_COLOR


# --- fake clock ---------------------------------------------------------------------

func _stamp() -> String:
	var d := Time.get_datetime_dict_from_system(true)
	var ms := int(fposmod(Time.get_unix_time_from_system(), 1.0) * 1000.0)
	return "%02d:%02d:%02d.%03d" % [d.hour, d.minute, d.second, ms]


func _date() -> String:
	var d := Time.get_datetime_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


@warning_ignore("integer_division")
func _uptime() -> String:
	var s := int(Time.get_ticks_msec() / 1000) + UPTIME_OFFSET
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


# --- boot sequence -----------------------------------------------------------------

func _queue_boot() -> void:
	var rule := "=".repeat(50)
	_say(rule, 0.03)
	_say("              CADEMU SYSTEM MONITOR", 0.03)
	_say("                 MAIN CONSOLE", 0.03)
	_say(rule, 0.2)
	_say("")
	_say("CADEMU-BIOS rev 4.17 (c) CADEMU Engineers", 0.08, true)
	_bar("[BOOT] Memory test 1048576K", 8, 0.06)
	_say("[BOOT] Loading kernel modules (12/12) ........ OK", 0.12, true)
	_say("[BOOT] Mounting volume C: ........ OK", 0.12, true)
	_say("[BOOT] Local terminal initialized.", 0.3, true)
	_say("[NET-001] Probing uplink interface eth0 ...", 0.4, true)
	_say("[NET-001] Retry 1/3 ... no response", 0.5, true)
	_say("[NET-001] Retry 2/3 ... no response", 0.5, true)
	_say("[NET-001] Retry 3/3 ... no response", 0.4, true)
	_say("[NET-001] Connection timed out: getsockopt", 0.25, true)
	_say("[WARN] Remote connection could not be established.", 0.4, true)
	_say("")
	# The subsystem status list is NOT printed at boot: the player has to run
	# "systemscfg /statusreport" to see it (see _cmd_systemscfg).
	_say("[ACTION REQUIRED] Manual maintenance required.", 0.25)
	_say("[ACTION REQUIRED] Remote diagnostics unavailable.", 0.4)
	_say("")
	_say("-".repeat(50), 0.05)
	_say("Local console ready.", 0.08, false, WHITE_COLOR)
	_say("Enter a command to continue.", 0.1, false, WHITE_COLOR)
	_say("")


# --- commands ----------------------------------------------------------------------

func _submit(text: String) -> void:
	var raw := text.strip_edges()
	_in.clear()
	_say(PROMPT + " " + raw, 0.0, false, WHITE_COLOR)
	if raw != "":
		_history.append(raw)
	_hist_pos = _history.size()

	var parts := raw.split(" ", false)
	var cmd := parts[0].to_lower() if parts.size() > 0 else ""
	var args := parts.slice(1)
	match cmd:
		"":
			pass
		"systemscfg", "systemscfg.exe":
			_cmd_systemscfg(args)
		"data_diver_protocol", "data_diver_protocol.exe":
			_cmd_data_diver()
		"help", "?":
			_say("This console has no help system.", 0.05)
			_say("Refer to the maintenance notes.", 0.05)
			_say("")
		"cls", "clear":
			_transcript.clear()
			_dirty = true
		"dir", "ls":
			_cmd_dir()
		"ver":
			_say("CADEMU Monitor [Version %s]" % BUILD, 0.05)
			_say("")
		"date", "time":
			_say("Current time: %s %s UTC" % [_date(), _stamp().left(8)], 0.05)
			_say("")
		"whoami":
			_say("CADEMU\\viper", 0.05)
			_say("")
		"debug_complete", "debug_reset", "debug_progress", "debug_mode", "debug_map", "debug_objectives", "debug_sleepy", "debug_story_reset":
			_cmd_debug(cmd, args)
		"exit", "quit":
			Overlay.close()
		_:
			_say("'%s' is not recognized as an internal or external command," % parts[0], 0.05)
			_say("operable program or batch file.", 0.05)
			_say("")


func _cmd_systemscfg(args: PackedStringArray) -> void:
	if args.is_empty() or args[0] == "/?":
		_say("systemscfg - CADEMU subsystem configuration utility", 0.05)
		_say("Usage: systemscfg /statusreport", 0.05)
		_say("")
		return
	if args[0].to_lower() != "/statusreport":
		_say("systemscfg: unknown switch '%s'" % args[0], 0.05)
		_say("Usage: systemscfg /statusreport", 0.05)
		_say("")
		return
	Objectives.flag("status_report")
	_say("systemscfg v3.4.0 - CADEMU subsystem configuration utility", 0.1)
	_say("[SCFG] Reading subsystem registry ... OK", 0.3, true)
	_bar("[SCFG] Polling subsystems", 10, 0.1)
	var online := Subsystems.online_count()
	var total := Subsystems.IDS.size()
	if online == total:
		_say("[SCFG] 5 of 5 subsystems reported nominal", 0.3, true, OK_COLOR)
	else:
		_say("[SCFG] %d of %d subsystems reported faults" % [total - online, total], 0.3, true, WARN_COLOR)
	_say("")
	_say("CADEMU MONITOR // STATUS REPORT", 0.1)
	_say("Generated  : %s %s UTC" % [_date(), _stamp().left(8)], 0.05)
	_say("Host       : %s   Build %s" % [HOST, BUILD], 0.05)
	_say("Uptime     : %s" % _uptime(), 0.1)
	_say("-".repeat(50), 0.05)
	_say("%-8s %-30s %s" % ["ID", "SUBSYSTEM", "STATE"], 0.1)
	for r in Subsystems.rows():
		var state: String = r[2] if r[3] == "" else "%s (%s)" % [r[2], r[3]]
		_say("%-8s %-30s %s" % [r[0], r[1], state], 0.22, false, OK_COLOR if r[2] == "ONLINE" else ERR_COLOR)
	_say("-".repeat(50), 0.05)
	_say("Self-test  : %d PASS / %d FAIL" % [online, total - online], 0.12)
	if online == total:
		_say("Last sync  : now", 0.12)
		_say("Fault code : none", 0.12)
	else:
		_say("Last sync  : never", 0.12)
		_say("Fault code : 0x8007274C (E_TIMEDOUT)", 0.12)
	_say("")


func _cmd_debug(cmd: String, args: PackedStringArray) -> void:
	# Hidden developer commands, not mentioned in the sticky note.
	match cmd:
		"debug_complete":
			if args.is_empty() or not Subsystems.has_id(args[0]):
				_say("usage: debug_complete ERR-00X", 0.03)
			else:
				Subsystems.debug_complete(args[0])
				_say("%s forced ONLINE" % Subsystems.norm(args[0]), 0.03, false, OK_COLOR)
		"debug_reset":
			Subsystems.debug_reset_all()
			_say("all subsystems reset to OFFLINE", 0.03)
		"debug_progress":
			var n := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 0
			Subsystems.debug_set_progress(n)
			_say("%d subsystems ONLINE" % Subsystems.online_count(), 0.03)
		"debug_map":
			Tablet.set_reveal_all(not Tablet.reveal_all)
			_say("tablet map: all rooms %s" % ("REVEALED" if Tablet.reveal_all else "hidden until visited"), 0.03)
		"debug_sleepy":
			Story.start_sleepy()
			_say("sleepy event started (yellow dot on the map, bed unlocked)", 0.03)
		"debug_story_reset":
			Story.reset()
			_say("sleepy / dream progress reset", 0.03)
		"debug_objectives":
			Objectives.debug_unlock_all_steps()
			_say("story objectives completed; repair objectives unlocked", 0.03)
		"debug_mode":
			Subsystems.debug_mode = not Subsystems.debug_mode
			_say("debug mode %s (finished repairs %s be replayed)" % [
				"ON" if Subsystems.debug_mode else "OFF", "can" if Subsystems.debug_mode else "cannot"], 0.03)
	_say("")


func _cmd_data_diver() -> void:
	_say("DATA DIVER PROTOCOL v1.3.2 (c) CADEMU Engineers", 0.15)
	_say("[DIVER] Mounting local submission cache ... OK", 0.3, true)
	_say("[DIVER] Contacting remote datastore ...", 0.7, true)
	_say("[DIVER] Remote datastore unreachable (E_TIMEDOUT), using local cache", 0.3, true, WARN_COLOR)
	_bar("[DIVER] Scanning cache", 14, 0.09)
	_say("[DIVER] Scan complete. Checksums verified.", 0.3, true, OK_COLOR)
	_say("")
	_say("SUBMITTED DATA (LOCAL CACHE)", 0.1)
	_say("%-4s %-14s %-8s %s" % ["#", "SOURCE", "SIZE", "STATE"], 0.1)
	for r in DIVER_ROWS:
		_say("%-4s %-14s %-8s %s" % r, 0.22)
	_say("")
	_say("[WARN] %d packets cannot be uploaded: uplink down." % DIVER_ROWS.size(), 0.1, true)
	_say("")


func _cmd_dir() -> void:
	_say(" Volume in drive C is CADEMU-MON", 0.03)
	_say(" Directory of C:\\CADEMU\\MONITOR", 0.03)
	_say("")
	var day := _date()
	_say("%s  03:58 <DIR>            ." % day, 0.03)
	_say("%s  03:58 <DIR>            .." % day, 0.03)
	_say("%s  03:58          4,096   boot.log" % day, 0.03)
	_say("%s  03:58          1,024   monitor.cfg" % day, 0.03)
	_say("%s  03:58         86,016   systemscfg.exe" % day, 0.03)
	_say("%s  03:58        212,992   data_diver_protocol.exe" % day, 0.03)
	_say("               4 File(s)        304,128 bytes", 0.03)
	_say("")
