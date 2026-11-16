extends Node2D
## Fake registration / login screen, shown before the CADEMU title screen
## (Main.gd start_room = "login"). Accounts live in FakeAccounts (see that file for how to turn
## this off or remove it). Keyboard typing is used here (text fields); everything else is mouse.
##
## Log in / Register tabs, "Continue as guest", and "Clear saved accounts". After success it
## shows a welcome line, fades to black and goes to NEXT_ROOM ("title", which starts on black).

const NEXT_ROOM := "title"
const SCREEN := Vector2(640, 360)

const GOOD := Color(0.35, 0.9, 0.5)
const WARN := Color(1.0, 0.75, 0.25)
const BAD := Color(1.0, 0.4, 0.38)
const INK := Color(0.86, 0.89, 0.92)
const DIM := Color(0.5, 0.55, 0.6)
const ACCENT := Color(0.4, 0.8, 1.0)

enum Mode { LOGIN, REGISTER }

var _mode := Mode.LOGIN
var _busy := false
var _timer: Timer
var _user: LineEdit
var _pass: LineEdit
var _confirm: LineEdit
var _submit: Button
var _status: Label
var _tab_login: Button
var _tab_register: Button
var _guest: Button
var _clear: Button
var _fade: ColorRect


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.size = SCREEN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if not FakeAccounts.ENABLED:
		RoomManager.go_to(NEXT_ROOM)
		return
	_build()
	_set_mode(Mode.LOGIN)
	_user.grab_focus.call_deferred()


# --- building ------------------------------------------------------------------------------

func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _field(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.max_length = 32
	e.custom_minimum_size = Vector2(292, 26)
	e.add_theme_font_size_override("font_size", 11)
	e.text_submitted.connect(func(_t: String): _on_submit())
	return e


func _button(text: String, flat := false) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = flat
	b.add_theme_font_size_override("font_size", 10)
	return b


func _build() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)

	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.98)
	style.border_color = Color(0.4, 0.45, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(160, 24)
	panel.size = Vector2(320, 312)
	add_child(panel)

	var box := VBoxContainer.new()
	box.position = Vector2(14, 12)
	box.size = Vector2(292, 290)
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	box.add_child(_label("CADEMU PERSONNEL ACCESS", 14, ACCENT))
	box.add_child(_label("Lunar Base Operations Network", 9, DIM))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	_tab_login = _button("Log in")
	_tab_register = _button("Register")
	for t in [_tab_login, _tab_register]:
		t.toggle_mode = true
		t.button_group = group
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(t)
	_tab_login.button_pressed = true
	_tab_login.pressed.connect(_set_mode.bind(Mode.LOGIN))
	_tab_register.pressed.connect(_set_mode.bind(Mode.REGISTER))
	box.add_child(tabs)

	_user = _field("Username")
	_pass = _field("Password", true)
	_confirm = _field("Confirm password", true)
	box.add_child(_user)
	box.add_child(_pass)
	box.add_child(_confirm)

	_submit = _button("Log in")
	_submit.custom_minimum_size = Vector2(292, 28)
	_submit.pressed.connect(_on_submit)
	box.add_child(_submit)

	_status = _label("", 10, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(292, 40)
	box.add_child(_status)

	_guest = _button("Continue as guest", true)
	_guest.pressed.connect(_on_guest)
	box.add_child(_guest)

	var foot := "Prototype login. Accounts are kept in temporary local data and can be removed."
	if not FakeAccounts.PERSIST:
		foot = "Prototype login. Accounts are kept in memory only (erased when the game closes)."
	var note := _label(foot, 8, DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(292, 22)
	box.add_child(note)
	_clear = _button("Clear saved accounts", true)
	_clear.pressed.connect(_on_clear)
	box.add_child(_clear)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.size = SCREEN
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


# --- behavior ------------------------------------------------------------------------------

func _set_mode(mode: Mode) -> void:
	_mode = mode
	_confirm.visible = mode == Mode.REGISTER
	_submit.text = "Log in" if mode == Mode.LOGIN else "Create account"
	_pass.clear()
	_confirm.clear()
	_status.text = ""


func _say(text: String, kind := "info") -> void:
	var prefix: String = {"good": "[OK] ", "warn": "[!] ", "bad": "[X] "}.get(kind, "")
	var color: Color = {"good": GOOD, "warn": WARN, "bad": BAD}.get(kind, INK)
	_status.text = prefix + text
	_status.add_theme_color_override("font_color", color)


func _set_enabled(on: bool) -> void:
	for e in [_user, _pass, _confirm]:
		e.editable = on
	for b in [_submit, _tab_login, _tab_register, _guest, _clear]:
		b.disabled = not on


func _on_submit() -> void:
	if _busy:
		return
	var user_name := _user.text.strip_edges()
	var password := _pass.text
	if _mode == Mode.REGISTER and password != _confirm.text:
		_say("Passwords do not match.", "bad")
		return
	_busy = true
	_set_enabled(false)
	_say("Contacting CADEMU personnel server...")
	_timer.start(randf_range(0.6, 1.1))
	await _timer.timeout
	var err := ""
	if _mode == Mode.REGISTER:
		err = FakeAccounts.register(user_name, password)
	else:
		err = FakeAccounts.login(user_name, password)
	if err != "":
		_say(err, "bad")
		_busy = false
		_set_enabled(true)
		_pass.clear()
		_confirm.clear()
		_pass.grab_focus()
		return
	var line := "ACCESS GRANTED. Welcome, Cadet %s (ID %s)." % [FakeAccounts.current_user, FakeAccounts.current_id]
	if _mode == Mode.REGISTER:
		line = "Account created. " + line
	_finish(line)


func _on_guest() -> void:
	if _busy:
		return
	_busy = true
	_set_enabled(false)
	FakeAccounts.set_guest()
	_finish("Guest access granted.")


func _on_clear() -> void:
	if _busy:
		return
	var n := FakeAccounts.wipe()
	_say("Saved accounts cleared (%d removed)." % n, "warn")


## Shows the welcome line, fades to black and goes to NEXT_ROOM.
func _finish(line: String) -> void:
	_say(line, "good")
	_timer.start(1.8)
	await _timer.timeout
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.8)
	await tw.finished
	RoomManager.go_to(NEXT_ROOM)
