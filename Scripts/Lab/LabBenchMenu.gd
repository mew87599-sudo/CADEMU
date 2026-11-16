extends LabMenu
## The examination bench (the microscope room). Three phases, picked from the story flags:
##   1. DELIVER  place the sample container on the table                  (samples_delivered)
##   2. PREPARE  per specimen: place, cut a thin section (timing), mount on a slide, secure it,
##               load it under the microscope                              (samples_prepared)
##   3. EXAMINE  microscope: magnification, illumination, focus, move over the specimen, take
##               images of the interesting structures                      (samples_examined)
## During the second examination (Mission.recheck) only Sample 04 goes through phases 2 and 3.
## Sample 04 is slow to process and needs two images; the second time it looks ordinary.

const STEP_NAMES := ["Place on preparation surface", "Cut thin section", "Mount on microscope slide", "Secure the slide", "Load under microscope"]
const PROCESS_NORMAL := 1.2
const PROCESS_UNKNOWN := 4.5

var _panel: Panel
var _chips: Array = []
var _content: Control
var _sel := 0            # specimen being prepared / examined
var _step := 0           # preparation step reached for _sel
var _step_buttons: Array = []
var _prep_list: Control
var _msg: Label

# thin-section cut (timing bar)
var _cut_bar: Control
var _cut_active := false
var _cut_pos := 0.0
var _cut_dir := 1.0
var _cut_center := 0.5
const CUT_WIDTH := 0.2
const CUT_SPEED := 0.9

# microscope
var _view: SpecimenView
var _status: Label
var _clarity: ProgressBar
var _mag_label: Label
var _s_mag: HSlider
var _s_illum: HSlider
var _s_focus: HSlider
var _proc_bar: ProgressBar
var _proc_t := 0.0
var _proc_total := 0.0
var _wipe_btn: Button
var _tab_buttons: Array = []


func _build() -> void:
	_panel = LabUI.panel(self, Vector2(30, 24), Vector2(580, 312))
	LabUI.label(_panel, "EXAMINATION BENCH", Vector2(14, 8), Vector2(220, 18), 13)
	var chip_names := ["1 DELIVER", "2 PREPARE", "3 EXAMINE"]
	for i in chip_names.size():
		_chips.append(LabUI.label(_panel, chip_names[i], Vector2(250 + i * 78, 11), Vector2(76, 14), 10, LabUI.DIM))
	LabUI.button(_panel, "Close", Vector2(520, 6), Vector2(48, 22), _close, 10)
	_content = Control.new()
	_content.position = Vector2(0, 36)
	_content.size = Vector2(580, 270)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_content)
	_show_phase()


func _phase() -> int:
	if not Objectives.has_flag("samples_delivered"):
		return 0
	if not Mission.all_prepared():
		return 1
	if not Mission.all_examined():
		return 2
	return 3


func _show_phase() -> void:
	_cut_active = false
	_proc_t = 0.0
	LabUI.clear(_content)
	_step_buttons.clear()
	_tab_buttons.clear()
	var phase := _phase()
	for i in _chips.size():
		var chip: Label = _chips[i]
		var active := (phase == i or (phase == 3 and i == 2))
		chip.add_theme_color_override("font_color", LabUI.WARN if active else LabUI.DIM)
	match phase:
		0:
			_build_deliver()
		1:
			_build_prepare()
		2:
			_build_examine()
		_:
			_build_done()


# --- 1. deliver -----------------------------------------------------------------------------

func _build_deliver() -> void:
	LabUI.label(_content, "The sample container from survey SRV-0412 is ready to be unpacked.", Vector2(40, 60), Vector2(500, 36), 12)
	LabUI.label(_content, "Place it on the examination table to begin.", Vector2(40, 96), Vector2(500, 20), 10, LabUI.DIM)
	LabUI.button(_content, "Place container on the examination table", Vector2(150, 140), Vector2(280, 36), _deliver, 12)


func _deliver() -> void:
	Objectives.flag("samples_delivered")
	Story.say("Container placed on the examination table.")
	_show_phase()


# --- 2. prepare -----------------------------------------------------------------------------

func _build_prepare() -> void:
	var ids: Array = Mission.active_ids()
	if not ids.has(_sel) or Mission.prepared.get(_sel, false):
		for id in ids:
			if not Mission.prepared.get(id, false):
				_sel = id
				_step = 0
				break
	LabUI.label(_content, "SPECIMENS" if not Mission.recheck else "SPECIMEN (second examination)", Vector2(14, 4), Vector2(220, 14), 10, LabUI.DIM)
	var y := 24.0
	for id in ids:
		var done: bool = Mission.prepared.get(id, false)
		var b := LabUI.button(_content, "Sample %02d  %s" % [id, "ready" if done else "to prepare"], Vector2(14, y), Vector2(170, 30), _pick.bind(id), 10)
		b.disabled = done
		if id == _sel and not done:
			b.add_theme_color_override("font_color", LabUI.WARN)
		y += 36.0
	LabUI.label(_content, "WORKFLOW - Sample %02d" % _sel, Vector2(210, 4), Vector2(340, 14), 10, LabUI.DIM)
	for i in STEP_NAMES.size():
		var b := LabUI.button(_content, "%d. %s" % [i + 1, STEP_NAMES[i]], Vector2(210, 24 + i * 34), Vector2(230, 28), _do_step.bind(i), 10)
		_step_buttons.append(b)
	_msg = LabUI.label(_content, "", Vector2(210, 200), Vector2(340, 40), 10, LabUI.WARN)
	_cut_bar = Control.new()
	_cut_bar.position = Vector2(450, 56)
	_cut_bar.size = Vector2(110, 24)
	_cut_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cut_bar.draw.connect(_draw_cut)
	_content.add_child(_cut_bar)
	LabUI.label(_content, "Stop the blade inside the green zone.", Vector2(450, 84), Vector2(110, 40), 9, LabUI.DIM)
	_refresh_steps()


func _pick(id: int) -> void:
	_sel = id
	_step = 0
	_cut_active = false
	_build_prepare_again()


func _build_prepare_again() -> void:
	LabUI.clear(_content)
	_step_buttons.clear()
	_build_prepare()


func _refresh_steps() -> void:
	for i in _step_buttons.size():
		var b: Button = _step_buttons[i]
		b.disabled = i != _step
		var text: String = STEP_NAMES[i]
		b.text = "%d. %s%s" % [i + 1, text, "  [done]" if i < _step else ""]
	_cut_bar.queue_redraw()


func _do_step(i: int) -> void:
	if i != _step:
		return
	match i:
		1:
			if not _cut_active:
				_start_cut()
				return
			_finish_cut()
			return
		4:
			Mission.prepared[_sel] = true
			Story.say("Sample %02d is under the microscope." % _sel)
			if Mission.all_prepared():
				Objectives.flag("samples_prepared")
			_show_phase()
			return
	_step += 1
	_msg.text = ""
	_refresh_steps()


func _start_cut() -> void:
	_cut_active = true
	_cut_pos = 0.0
	_cut_dir = 1.0
	_cut_center = randf_range(0.3, 0.7)
	_msg.text = "Press the button again to cut when the blade is in the green zone."
	(_step_buttons[1] as Button).text = "2. CUT NOW"


func _finish_cut() -> void:
	_cut_active = false
	if absf(_cut_pos - _cut_center) <= CUT_WIDTH * 0.5:
		_msg.text = "Clean cut. The thin section is ready."
		_step = 2
	else:
		_msg.text = "The section cracked. Try again."
	_refresh_steps()


func _draw_cut() -> void:
	var w := _cut_bar.size.x
	var h := _cut_bar.size.y
	_cut_bar.draw_rect(Rect2(0, 0, w, h), Color(0.12, 0.13, 0.16))
	_cut_bar.draw_rect(Rect2((_cut_center - CUT_WIDTH * 0.5) * w, 0, CUT_WIDTH * w, h), Color(0.2, 0.55, 0.3, 0.8))
	if _cut_active:
		_cut_bar.draw_rect(Rect2(_cut_pos * w - 1.5, 0, 3, h), Color(1.0, 0.85, 0.3))
	_cut_bar.draw_rect(Rect2(0, 0, w, h), Color(0.5, 0.55, 0.6), false, 1.0)


# --- 3. examine (microscope) --------------------------------------------------------------------

func _build_examine() -> void:
	var ids: Array = Mission.active_ids()
	if not ids.has(_sel) or Mission.examined.get(_sel, false):
		for id in ids:
			if not Mission.examined.get(id, false):
				_sel = id
				break
	_s_mag = null   # forget the controls of an earlier build (they were freed)
	_s_illum = null
	_s_focus = null
	_status = null
	_wipe_btn = null
	_view = SpecimenView.new()
	_view.position = Vector2(14, 28)
	_view.moved.connect(_update_status)
	_content.add_child(_view)

	var x := 14.0
	for id in ids:
		var b := LabUI.button(_content, "S%02d" % id, Vector2(x, 2), Vector2(54, 22), _select_specimen.bind(id), 10)
		b.disabled = Mission.examined.get(id, false)
		_tab_buttons.append(b)
		x += 58.0
	_load_specimen()

	var cx := 270.0
	LabUI.label(_content, "Magnification", Vector2(cx, 6), Vector2(100, 14), 10, LabUI.DIM)
	_mag_label = LabUI.label(_content, "", Vector2(cx + 220, 6), Vector2(60, 14), 10, LabUI.WARN)
	_s_mag = LabUI.slider(_content, Vector2(cx, 22), 270, 0, 3, 1, 0, _on_view_changed)
	LabUI.label(_content, "Illumination", Vector2(cx, 44), Vector2(100, 14), 10, LabUI.DIM)
	_s_illum = LabUI.slider(_content, Vector2(cx, 60), 270, 0.0, 1.0, 0.01, 0.5, _on_view_changed)
	LabUI.label(_content, "Focus", Vector2(cx, 82), Vector2(100, 14), 10, LabUI.DIM)
	_s_focus = LabUI.slider(_content, Vector2(cx, 98), 270, 0.0, 1.0, 0.005, 0.1, _on_view_changed)
	LabUI.label(_content, "Clarity", Vector2(cx, 120), Vector2(60, 14), 10, LabUI.DIM)
	_clarity = ProgressBar.new()
	_clarity.position = Vector2(cx + 56, 122)
	_clarity.size = Vector2(214, 10)
	_clarity.show_percentage = false
	_clarity.max_value = 1.0
	_content.add_child(_clarity)

	LabUI.label(_content, "Move", Vector2(cx, 142), Vector2(40, 14), 10, LabUI.DIM)
	var arrows := [["<", Vector2(-1, 0)], ["^", Vector2(0, -1)], ["v", Vector2(0, 1)], [">", Vector2(1, 0)]]
	for i in arrows.size():
		LabUI.button(_content, arrows[i][0], Vector2(cx + 40 + i * 30, 138), Vector2(26, 22), _nudge.bind(arrows[i][1]), 11)
	LabUI.label(_content, "(or drag the picture)", Vector2(cx + 166, 142), Vector2(110, 14), 9, LabUI.DIM)

	LabUI.button(_content, "Capture image", Vector2(cx, 170), Vector2(130, 30), _capture, 11)
	_wipe_btn = LabUI.button(_content, "Wipe lens", Vector2(cx + 140, 170), Vector2(130, 30), _toggle_wipe, 10)
	_proc_bar = ProgressBar.new()
	_proc_bar.position = Vector2(cx, 208)
	_proc_bar.size = Vector2(270, 12)
	_proc_bar.max_value = 1.0
	_proc_bar.show_percentage = false
	_proc_bar.visible = false
	_content.add_child(_proc_bar)
	_status = LabUI.label(_content, "", Vector2(cx, 224), Vector2(280, 44), 10, LabUI.WARN)
	_on_view_changed(0.0)
	_update_status()


func _select_specimen(id: int) -> void:
	if _proc_t > 0.0:
		return
	_sel = id
	_load_specimen()


func _load_specimen() -> void:
	var s: Dictionary = Mission.sample(_sel)
	var kind: String = s.kind
	if kind == "unknown" and Mission.recheck:
		kind = "ordinary"   # the second time, Sample 04 looks like plain rock
	_view.set_specimen(_sel, kind)
	_view.wipe_mode = false
	if _s_mag != null:
		_s_mag.set_value_no_signal(0)
		_s_illum.set_value_no_signal(0.5)
		_s_focus.set_value_no_signal(0.1)
		_on_view_changed(0.0)
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		b.add_theme_color_override("font_color", LabUI.WARN if Mission.active_ids()[i] == _sel else LabUI.INK)
	_update_status()


func _on_view_changed(_v: float) -> void:
	if _view == null or _s_mag == null:
		return
	_view.set_view(int(_s_mag.value), _s_illum.value, _s_focus.value)
	_mag_label.text = SpecimenView.MAGS[int(_s_mag.value)]
	_clarity.value = _view.clarity()


func _nudge(dir: Vector2) -> void:
	_view.pan(dir * 24.0 / _view.scale_now())


func _toggle_wipe() -> void:
	_view.wipe_mode = not _view.wipe_mode
	_wipe_btn.text = "Wiping: drag on the picture" if _view.wipe_mode else "Wipe lens"
	_view.mouse_default_cursor_shape = Control.CURSOR_CROSS if _view.wipe_mode else Control.CURSOR_MOVE
	if _view.smudges.is_empty() and _view.wipe_mode:
		_view.wipe_mode = false
		_wipe_btn.text = "Lens is clean"


func _update_status() -> void:
	if _status == null or _proc_t > 0.0:
		return
	if _view.smudges.is_empty() and not Mission.lens_clean:
		Mission.lens_clean = true
		Story.say("The lens is clean.")
		if _wipe_btn != null:
			_wipe_btn.text = "Lens is clean"
	var need := _images_needed(_sel)
	var have: int = Mission.captures.get(_sel, 0)
	_status.text = "Sample %02d: %d of %d image(s) taken." % [_sel, have, need]
	_status.add_theme_color_override("font_color", LabUI.WARN)


func _images_needed(id: int) -> int:
	return 2 if (id == 4 and not Mission.recheck) else 1


func _capture() -> void:
	if _proc_t > 0.0:
		return
	var check := _view.check_image()
	if not check.ok:
		_status.text = "Capture failed: %s" % check.msg
		_status.add_theme_color_override("font_color", LabUI.BAD)
		return
	_proc_total = PROCESS_UNKNOWN if (_sel == 4 and not Mission.recheck) else PROCESS_NORMAL
	_proc_t = _proc_total
	_proc_bar.value = 0.0
	_proc_bar.visible = true
	_status.text = "Processing image..." if _proc_total < 2.0 else "Processing image... this is taking longer than expected."
	_status.add_theme_color_override("font_color", LabUI.WARN)


func _finish_capture() -> void:
	_proc_bar.visible = false
	var n: int = Mission.captures.get(_sel, 0) + 1
	Mission.captures[_sel] = n
	var need := _images_needed(_sel)
	if n < need:
		_status.text = "Image processed, but the structures are unresolved. Check focus and illumination, then image again."
		_status.add_theme_color_override("font_color", LabUI.WARN)
		return
	Mission.examined[_sel] = true
	var extra := ""
	if _sel == 4 and not Mission.recheck:
		extra = " The same structures are still visible."
	_status.text = "Sample %02d documented.%s" % [_sel, extra]
	_status.add_theme_color_override("font_color", LabUI.GOOD)
	Story.say("Sample %02d documented." % _sel)
	if Mission.all_examined():
		Objectives.flag("samples_examined")
		if Mission.recheck:
			Objectives.flag("sample4_rechecked")
		await get_tree().create_timer(1.6).timeout
		if is_inside_tree():
			_show_phase()
	else:
		await get_tree().create_timer(1.2).timeout
		if is_inside_tree():
			_show_phase()


# --- done ---------------------------------------------------------------------------------------

func _build_done() -> void:
	var text := "All specimens are documented. Record the findings on the lab computer."
	if Objectives.has_flag("second_uploaded"):
		text = "Both examinations are complete and uploaded."
	elif Objectives.has_flag("recheck_requested"):
		text = "Mission Control asked for Sample 04 to be checked again."
	LabUI.label(_content, text, Vector2(40, 70), Vector2(500, 40), 12)
	if Mission.specimens_returned:
		LabUI.label(_content, "The specimens are back in storage.", Vector2(40, 130), Vector2(500, 20), 10, LabUI.GOOD)
	else:
		LabUI.button(_content, "Return specimens to storage", Vector2(150, 130), Vector2(280, 32), _return_specimens, 11)


func _return_specimens() -> void:
	Mission.specimens_returned = true
	Story.say("Specimens returned to their storage compartments.")
	_show_phase()


func _process(delta: float) -> void:
	if _cut_active and _cut_bar != null:
		_cut_pos += _cut_dir * CUT_SPEED * delta
		if _cut_pos >= 1.0:
			_cut_pos = 1.0
			_cut_dir = -1.0
		elif _cut_pos <= 0.0:
			_cut_pos = 0.0
			_cut_dir = 1.0
		_cut_bar.queue_redraw()
	if _proc_t > 0.0:
		_proc_t -= delta
		_proc_bar.value = 1.0 - maxf(_proc_t, 0.0) / _proc_total
		if _proc_t <= 0.0:
			_proc_t = 0.0
			_finish_capture()
