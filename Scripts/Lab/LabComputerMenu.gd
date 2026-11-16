extends LabMenu
## The laboratory computer (the PC in the lab). What it shows depends on the story flags:
##   no images yet            the sample registry only
##   samples_examined         enter the four classifications, run the database match, submit the report
##   report_submitted         waiting for Mission Control
##   recheck_requested        Sample 04 has to be examined again at the microscope
##   sample4_rechecked        upload the second result
##   second_uploaded          everything is synchronized
## Sample 04 always comes back as "UNKNOWN ORGANIC COMPOUND", and for a moment the reference
## database reads EARTH. The first upload attempt of the report fails once (retry), as a small
## "data synchronization" chore.

const OBSERVATIONS := {
	1: "Dark mineral structures, crystalline formations",
	2: "Lighter crystalline structures, mostly feldspar",
	3: "Fine, irregular particles and mineral grains",
	4: "Unidentified structures (unresolved)",
}

var _panel: Panel
var _content: Control
var _row_buttons := {}
var _out: RichTextLabel
var _status: Label
var _submit: Button
var _process_btn: Button
var _busy := false


func _build() -> void:
	_panel = LabUI.panel(self, Vector2(40, 24), Vector2(560, 312))
	LabUI.label(_panel, "CADEMU LAB - SAMPLE DATABASE", Vector2(14, 8), Vector2(360, 18), 13)
	LabUI.button(_panel, "Close", Vector2(498, 6), Vector2(48, 22), _close, 10)
	_content = Control.new()
	_content.position = Vector2(0, 36)
	_content.size = Vector2(560, 270)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content)
	_show_page()


func _show_page() -> void:
	LabUI.clear(_content)
	_row_buttons.clear()
	_out = null
	_status = null
	_submit = null
	_process_btn = null
	if Objectives.has_flag("second_uploaded"):
		_simple("All records are synchronized.", "Sample 04: no significant anomalies.", LabUI.GOOD)
	elif Objectives.has_flag("sample4_rechecked"):
		_build_second()
	elif Objectives.has_flag("recheck_requested"):
		_simple("Mission Control requested a second examination of Sample 04.", "Prepare and image it again at the microscope.", LabUI.WARN)
	elif Objectives.has_flag("report_submitted"):
		_simple("Report uploaded.", "Waiting for Mission Control...", LabUI.INK)
	elif Objectives.has_flag("samples_examined"):
		_build_report()
	else:
		_build_registry_only()


func _simple(line1: String, line2: String, color: Color) -> void:
	LabUI.label(_content, line1, Vector2(30, 70), Vector2(500, 40), 12, color)
	LabUI.label(_content, line2, Vector2(30, 112), Vector2(500, 40), 10, LabUI.DIM)


func _registry(y0: float) -> void:
	LabUI.label(_content, "ID", Vector2(14, y0), Vector2(30, 14), 9, LabUI.DIM)
	LabUI.label(_content, "SURVEY", Vector2(48, y0), Vector2(90, 14), 9, LabUI.DIM)
	LabUI.label(_content, "COLLECTED BY", Vector2(140, y0), Vector2(90, 14), 9, LabUI.DIM)
	LabUI.label(_content, "PREVIOUS OBSERVATIONS", Vector2(236, y0), Vector2(180, 14), 9, LabUI.DIM)


func _build_registry_only() -> void:
	LabUI.label(_content, "No new microscopy images to record.", Vector2(14, 4), Vector2(500, 16), 11, LabUI.WARN)
	_registry(28.0)
	var y := 46.0
	for s in Mission.SAMPLES:
		LabUI.label(_content, "%02d" % s.id, Vector2(14, y), Vector2(30, 16), 10)
		LabUI.label(_content, String(s.survey), Vector2(48, y), Vector2(90, 16), 10)
		LabUI.label(_content, "CDT-07", Vector2(140, y), Vector2(90, 16), 10)
		LabUI.label(_content, "-", Vector2(236, y), Vector2(180, 16), 10, LabUI.DIM)
		y += 22.0
	LabUI.label(_content, "Sync status: idle. Nothing to upload.", Vector2(14, 160), Vector2(400, 16), 10, LabUI.DIM)


func _build_report() -> void:
	LabUI.label(_content, "Enter the classification of each specimen, then run the database match.", Vector2(14, 4), Vector2(530, 16), 10, LabUI.WARN)
	LabUI.label(_content, "ID", Vector2(14, 26), Vector2(30, 14), 9, LabUI.DIM)
	LabUI.label(_content, "SURVEY", Vector2(40, 26), Vector2(80, 14), 9, LabUI.DIM)
	LabUI.label(_content, "IMAGING NOTES", Vector2(122, 26), Vector2(250, 14), 9, LabUI.DIM)
	LabUI.label(_content, "CLASSIFICATION (click to change)", Vector2(372, 26), Vector2(180, 14), 9, LabUI.DIM)
	var y := 42.0
	for s in Mission.SAMPLES:
		var id: int = s.id
		LabUI.label(_content, "%02d" % id, Vector2(14, y + 4), Vector2(24, 16), 10)
		LabUI.label(_content, String(s.survey), Vector2(40, y + 4), Vector2(80, 16), 9)
		LabUI.label(_content, String(OBSERVATIONS[id]), Vector2(122, y + 1), Vector2(246, 24), 9, LabUI.DIM)
		var b := LabUI.button(_content, "", Vector2(372, y), Vector2(172, 24), _cycle.bind(id), 10)
		_row_buttons[id] = b
		y += 30.0
	_out = LabUI.rich(_content, Vector2(14, 168), Vector2(530, 62), 10)
	_process_btn = LabUI.button(_content, "Run database match", Vector2(14, 236), Vector2(160, 28), _run_match, 11)
	_submit = LabUI.button(_content, "Submit report to Mission Control", Vector2(190, 236), Vector2(230, 28), _upload_report, 11)
	_status = LabUI.label(_content, "", Vector2(430, 234), Vector2(120, 32), 9, LabUI.WARN)
	_refresh_rows()
	if Mission.processed:
		_out.text = _result_text()
	_submit.disabled = not Mission.processed
	_process_btn.disabled = Mission.processed


func _refresh_rows() -> void:
	for id in _row_buttons:
		var b: Button = _row_buttons[id]
		var idx: int = Mission.classified.get(id, 0)
		b.text = String(Mission.CLASSES[idx])
		b.disabled = Mission.processed or _busy


func _cycle(id: int) -> void:
	var idx: int = Mission.classified.get(id, 0)
	Mission.classified[id] = (idx + 1) % Mission.CLASSES.size()
	_refresh_rows()


func _result_text() -> String:
	return "[color=#59e680]01 Basalt - MATCH\n02 Anorthosite - MATCH\n03 Regolith - MATCH[/color]\n[color=#ff6655]04 Unknown composition - NO MATCH[/color]\n[color=#8899aa]Sample 04 left unresolved.[/color]"


func _run_match() -> void:
	if _busy or Mission.processed:
		return
	# every specimen needs a classification, and 1-3 have to agree with the imaging notes
	for s in Mission.SAMPLES:
		var id: int = s.id
		var idx: int = Mission.classified.get(id, 0)
		if idx == 0:
			_status.text = "Sample %02d has no classification." % id
			return
		if idx != id:
			_status.text = "Sample %02d: entry does not match the imaging data." % id
			return
	_busy = true
	_refresh_rows()
	_process_btn.disabled = true
	_out.text = "[color=#8899aa]Matching against the geological reference database...[/color]"
	await _wait(1.2)
	if not is_inside_tree():
		return
	_out.text = _result_text().split("\n[color=#ff6655]")[0] + "\n[color=#8899aa]Matching Sample 04...[/color]"
	await _wait(1.4)
	if not is_inside_tree():
		return
	_out.text = "[color=#59e680]01 Basalt - MATCH\n02 Anorthosite - MATCH\n03 Regolith - MATCH[/color]\n[color=#ff6655]04 Unknown composition - NO MATCH\n\n[b]ANALYSIS INCONSISTENCY[/b]\n[b]UNKNOWN ORGANIC COMPOUND[/b][/color]"
	await _wait(2.2)
	if not is_inside_tree():
		return
	_out.text = "[color=#8899aa]Attempting to classify the specimen again...[/color]"
	await _wait(1.4)
	if not is_inside_tree():
		return
	_out.text = "[color=#ffcc33][b]REFERENCE DATABASE: EARTH[/b][/color]"
	await _wait(1.0)
	if not is_inside_tree():
		return
	Mission.processed = true
	_busy = false
	_out.text = _result_text()
	_status.text = ""
	_refresh_rows()
	_submit.disabled = false


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _upload_report() -> void:
	if _busy or not Mission.processed:
		return
	if not Mission.upload_failed_once:
		Mission.upload_failed_once = true
		_status.text = "SYNC FAILED - connection timed out. Try again."
		_submit.text = "Retry upload"
		return
	_status.text = "Uploading..."
	_busy = true
	await _wait(1.0)
	_busy = false
	Mission.submit_report()
	if is_inside_tree():
		_show_page()


func _build_second() -> void:
	LabUI.label(_content, "SAMPLE 04 - SECOND EXAMINATION", Vector2(14, 4), Vector2(400, 16), 11, LabUI.WARN)
	LabUI.label(_content, "Imaging: dark crystalline structures.\nComputer: no significant anomalies.", Vector2(14, 34), Vector2(500, 40), 11, LabUI.GOOD)
	LabUI.label(_content, "The result is ready to be sent to Mission Control.", Vector2(14, 90), Vector2(500, 20), 10, LabUI.DIM)
	LabUI.button(_content, "Upload second result", Vector2(14, 130), Vector2(220, 30), _upload_second, 11)


func _upload_second() -> void:
	Mission.upload_second()
	_show_page()
