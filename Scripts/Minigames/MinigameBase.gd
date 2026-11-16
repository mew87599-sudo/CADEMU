class_name MinigameBase
extends Control
## Shared shell of the repair minigames (menu scenes opened through Overlay).
## Provides: title + subsystem id, power bus, live win checklist, meters, toast messages,
## Retry-step and Exit buttons, reduced-motion toggle, win pulse + power-up sequence, pause when
## the window loses focus, and a drawing/input canvas.
##
## A minigame extends this and overrides:
##   _configure()          set subsystem_id, title, checklist (the win conditions)
##   _init_game()          create state, call add_meter() for the bars it wants
##   _tick(delta)          game logic (not called while paused / won)
##   _draw_game(canvas)    draw with canvas.draw_*(), plus helpers txt(), draw_shape()
##   _game_input(event)    mouse events in canvas coordinates (0,0)-(434,246)
##   _retry_step()         the Retry button: reset ONLY the current step/wave
## and calls toast(), set_check(i, bool), and finally win().
##
## Rules every minigame follows: wrong actions cost time/quality, never a full reset; a menu that
## is already ONLINE shows a notice instead (unless Subsystems.debug_mode).

const GOOD := Color(0.35, 0.9, 0.5)
const WARN := Color(1.0, 0.75, 0.25)
const BAD := Color(1.0, 0.4, 0.38)
const INK := Color(0.86, 0.89, 0.92)
const DIM := Color(0.5, 0.55, 0.6)
const ACCENT := Color(0.4, 0.8, 1.0)
const BEEP_PATH := "res://Assets/Misc/beep.wav"
const HUM_PATH := "res://Assets/Misc/hum.wav"

var subsystem_id := ""
var title := ""
var checklist: Array = []
var canvas: GameCanvas
var paused := false
var won := false
var clock := 0.0

var _notice := false
var _check_state: Array = []
var _check_labels: Array = []
var _meter_y := 0.0
var _panel: Panel
var _toast: Label
var _toast_t := 0.0
var _banner: ColorRect
var _banner_label: Label
var _retry: Button
var _win_t := 0.0
var _powerup := false
var _sfx: AudioStreamPlayer
var _hum: AudioStreamPlayer


# --- to override ---------------------------------------------------------------------

func _configure() -> void:
	pass


func _init_game() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _draw_game(_c: Control) -> void:
	pass


func _game_input(_event: InputEvent) -> void:
	pass


func _retry_step() -> void:
	pass


# --- shell -----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Right click anywhere closes the menu (panels would otherwise swallow it).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Overlay.close()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_configure()
	_build_shell()
	if Subsystems.is_online(subsystem_id) and not Subsystems.debug_mode:
		_notice = true
		_show_notice()
	else:
		_init_game()


func _lbl(text: String, pos: Vector2, sz: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	_panel.add_child(l)
	return l


func _build_shell() -> void:
	_panel = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.98)
	style.border_color = Color(0.4, 0.45, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(10, 8)
	_panel.size = Vector2(620, 344)
	add_child(_panel)

	_lbl("%s  %s" % [subsystem_id, title], Vector2(12, 8), Vector2(326, 18), 12, INK)
	var bus := PowerBus.new()
	bus.position = Vector2(344, 4)
	bus.size = Vector2(264, 38)
	_panel.add_child(bus)

	_lbl("WIN CHECKLIST", Vector2(12, 46), Vector2(150, 12), 9, DIM)
	for i in checklist.size():
		var l := _lbl("[ ] " + str(checklist[i]), Vector2(12, 60 + i * 30), Vector2(156, 28), 10, INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_check_labels.append(l)
		_check_state.append(false)
	_meter_y = 60.0 + checklist.size() * 30.0 + 8.0

	canvas = GameCanvas.new()
	canvas.position = Vector2(172, 44)
	canvas.size = Vector2(434, 246)
	canvas.draw_cb = _draw_game
	canvas.input_cb = _on_canvas_input
	_panel.add_child(canvas)

	_toast = _lbl("", Vector2(172, 294), Vector2(434, 18), 10, INK)

	var reduced := CheckBox.new()
	reduced.text = "Reduced motion"
	reduced.position = Vector2(8, 314)
	reduced.add_theme_font_size_override("font_size", 9)
	reduced.button_pressed = Subsystems.reduced_motion
	reduced.toggled.connect(func(on: bool): Subsystems.reduced_motion = on)
	_panel.add_child(reduced)

	_retry = Button.new()
	_retry.text = "Retry step"
	_retry.position = Vector2(404, 316)
	_retry.size = Vector2(100, 22)
	_retry.add_theme_font_size_override("font_size", 10)
	_retry.pressed.connect(_on_retry)
	_panel.add_child(_retry)

	var exit_btn := Button.new()
	exit_btn.text = "Exit"
	exit_btn.position = Vector2(512, 316)
	exit_btn.size = Vector2(92, 22)
	exit_btn.add_theme_font_size_override("font_size", 10)
	exit_btn.pressed.connect(func(): Overlay.close())
	_panel.add_child(exit_btn)

	_banner = ColorRect.new()
	_banner.color = Color(0, 0, 0, 0.82)
	_banner.size = _panel.size
	_banner.visible = false
	_panel.add_child(_banner)
	_banner_label = Label.new()
	_banner_label.position = Vector2(0, 118)
	_banner_label.size = Vector2(620, 110)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 24)
	_banner_label.add_theme_color_override("font_color", GOOD)
	_banner.add_child(_banner_label)

	_sfx = AudioStreamPlayer.new()
	if ResourceLoader.exists(BEEP_PATH):
		_sfx.stream = load(BEEP_PATH)
	_sfx.volume_db = -8.0
	add_child(_sfx)
	_hum = AudioStreamPlayer.new()
	if ResourceLoader.exists(HUM_PATH):
		_hum.stream = load(HUM_PATH)
	_hum.volume_db = -6.0
	add_child(_hum)


func _show_notice() -> void:
	canvas.draw_cb = Callable()
	_retry.disabled = true
	var l := Label.new()
	l.text = "%s is already ONLINE.\nNo repair needed." % subsystem_id
	l.position = Vector2(0, 90)
	l.size = Vector2(434, 60)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", GOOD)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(l)
	for i in checklist.size():
		set_check(i, true)


func _process(delta: float) -> void:
	clock += delta
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	if won:
		_win_logic(delta)
	elif not paused and not _notice:
		_tick(delta)
	canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		paused = true
		toast("Paused: window not focused", "warn")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		paused = false


func _on_retry() -> void:
	if won or _notice:
		return
	_retry_step()


func _on_canvas_input(event: InputEvent) -> void:
	if won or paused or _notice:
		return
	_game_input(event)


# --- services for the minigames ----------------------------------------------------------

## kind: "info", "good" (green [OK]), "warn" (amber [!]), "bad" (red [X]).
func toast(text: String, kind := "info") -> void:
	if _toast == null:
		return
	var prefix: String = {"good": "[OK] ", "warn": "[!] ", "bad": "[X] "}.get(kind, "")
	var color: Color = {"good": GOOD, "warn": WARN, "bad": BAD}.get(kind, INK)
	_toast.text = prefix + text
	_toast.add_theme_color_override("font_color", color)
	_toast_t = 3.5
	if kind != "info":
		sfx(kind)


func sfx(kind: String) -> void:
	if _sfx == null or _sfx.stream == null:
		return
	_sfx.pitch_scale = {"good": 1.5, "warn": 1.0, "bad": 0.55}.get(kind, 1.2)
	_sfx.play()


func set_check(i: int, ok: bool) -> void:
	if i < 0 or i >= _check_state.size() or _check_state[i] == ok:
		return
	_check_state[i] = ok
	var l: Label = _check_labels[i]
	l.text = ("[X] " if ok else "[ ] ") + str(checklist[i])
	l.add_theme_color_override("font_color", GOOD if ok else INK)


func add_meter(label: String, good_high: bool, good_at: float, bad_at: float) -> MeterBar:
	var m := MeterBar.new()
	m.label = label
	m.good_high = good_high
	m.good_at = good_at
	m.bad_at = bad_at
	m.position = Vector2(12, _meter_y)
	m.size = Vector2(152, 18)
	_panel.add_child(m)
	_meter_y += 26.0
	return m


## Call when every win condition is met. Flips the breaker, shows the 2-second ONLINE pulse
## (or the longer OUTPOST POWERED sequence on the fifth repair), then closes the menu.
func win() -> void:
	if won:
		return
	won = true
	for i in checklist.size():
		set_check(i, true)
	Subsystems.complete(subsystem_id)
	_powerup = Subsystems.powered
	_win_t = 5.0 if _powerup else 2.0
	_banner_label.text = "OUTPOST POWERED\nall subsystems ONLINE" if _powerup else "%s ONLINE" % subsystem_id
	_banner.visible = true
	_retry.disabled = true
	# (the "error solved" sound is played by Subsystems.complete)
	if _powerup and _hum.stream != null:
		_hum.play()


func _win_logic(delta: float) -> void:
	_win_t -= delta
	if not Subsystems.reduced_motion:
		_banner_label.modulate.a = 0.75 + 0.25 * sin(clock * 7.0)
		if _powerup and _win_t > 3.5:
			var v := 1.0 if randf() > 0.35 else 0.4  # lights flickering on
			_panel.modulate = Color(v, v, v, 1.0)
		else:
			_panel.modulate = Color.WHITE
	if _win_t <= 0.0:
		Overlay.close()


# --- drawing helpers -----------------------------------------------------------------------

static func centered(center: Vector2, sz: Vector2) -> Rect2:
	return Rect2(center - sz / 2.0, sz)


## Shortest signed difference a - b in degrees, -180..180.
static func ang_diff(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


func txt(c: Control, pos: Vector2, s: String, fs := 10, col := INK,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	c.draw_string(ThemeDB.fallback_font, pos, s, align, width, fs, col)


## kind 0 circle, 1 triangle, 2 square, 3 diamond (shapes carry meaning, not just color).
func draw_shape(c: Control, kind: int, center: Vector2, r: float, col: Color) -> void:
	match kind:
		0:
			c.draw_circle(center, r, col)
		1:
			c.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, r * 0.8), center + Vector2(-r, r * 0.8)]), col)
		2:
			c.draw_rect(Rect2(center - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), col)
		_:
			c.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)]), col)
