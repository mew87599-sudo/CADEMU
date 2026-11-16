extends MinigameBase
## ERR-002 Oxygen management: filter swap.
##   Phase A: hold the mouse on each clogged filter to remove it (air quality drains slowly).
##   Phase B: drag the replacement filters, in order, into the highlighted slot. The slot's
##            outline color AND the faint shape inside tell you which filter it needs.
##            A wrong filter goes back to the tray and the air drains faster for 2 s.
##   Then the scrubbers recover the air; win when air quality is above 50%.
## Soft fail: air at 0% resets only the current sequence (removed filters stay removed).
## Tuning: the constants below.

const COLORS := [Color(0.35, 0.65, 1.0), Color(1.0, 0.6, 0.2), Color(0.75, 0.45, 1.0), Color(1.0, 0.9, 0.3)]
const NAMES := ["circle", "triangle", "square", "diamond"]
const N := 4
const HOLD_TIME := 0.5          # seconds to hold on a clogged filter
const AIR_START := 0.75
const DRAIN_PER_CLOG := 0.004   # air quality lost per second, per clogged filter
const DRAIN_BASE := 0.004       # during phase B
const DRAIN_PENALTY := 0.03     # extra per second for 2 s after a wrong filter
const RECOVER := 0.05           # per second once everything is installed
const RESET_AIR := 0.45
const FILTER_SIZE := Vector2(58, 76)
const SLOT_SIZE := Vector2(76, 76)

var _air_meter: MeterBar
var _air := AIR_START
var _phase := 0               # 0 remove, 1 replace, 2 recover
var _clogged: Array = [true, true, true, true]
var _hold := -1
var _hold_t := 0.0
var _order: Array = []        # _order[slot] = filter type that slot needs
var _tray: Array = []         # {"type", "home", "pos", "placed"}
var _installed: Array = []
var _next := 0
var _drag := -1
var _drag_off := Vector2.ZERO
var _penalty := 0.0


func _configure() -> void:
	subsystem_id = "ERR-002"
	title = "Oxygen: filter swap"
	checklist = ["All clogged filters removed", "Replacement filters installed in order", "Air quality above 50%"]


func _init_game() -> void:
	_air_meter = add_meter("AIR QUALITY", true, 0.5, 0.25)
	_air_meter.value = _air
	toast("Hold the mouse on each clogged filter to remove it")


func _filter_pos(i: int) -> Vector2:
	return Vector2(62.0 + i * 103.0, 120.0)


func _slot_pos(i: int) -> Vector2:
	return Vector2(62.0 + i * 103.0, 72.0)


func _tray_home(i: int) -> Vector2:
	return Vector2(62.0 + i * 103.0, 186.0)


# --- logic -------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	var drain := 0.0
	match _phase:
		0:
			drain = DRAIN_PER_CLOG * _clogged.count(true)
			if _hold >= 0:
				_hold_t += delta
				if _hold_t >= HOLD_TIME:
					_remove_filter(_hold)
		1:
			drain = DRAIN_BASE + (DRAIN_PENALTY if _penalty > 0.0 else 0.0)
		2:
			drain = -RECOVER
	_penalty = maxf(0.0, _penalty - delta)
	_air = clampf(_air - drain * delta, 0.0, 1.0)
	_air_meter.value = _air
	if _phase < 2 and _air <= 0.0:
		_soft_fail()
	if _phase == 2:
		set_check(2, _air > 0.5)
		if _air > 0.5:
			win()


func _remove_filter(i: int) -> void:
	_clogged[i] = false
	_hold = -1
	_hold_t = 0.0
	toast("Filter removed", "good")
	if not _clogged.has(true):
		set_check(0, true)
		_phase = 1
		_make_sequence()
		toast("Now drag each filter into the highlighted slot")


func _make_sequence() -> void:
	_order = [0, 1, 2, 3]
	_order.shuffle()
	var types := [0, 1, 2, 3]
	types.shuffle()
	_tray.clear()
	for i in N:
		_tray.append({"type": types[i], "home": _tray_home(i), "pos": _tray_home(i), "placed": false})
	_installed = [false, false, false, false]
	_next = 0
	_drag = -1
	_penalty = 0.0


func _soft_fail() -> void:
	_air = RESET_AIR
	_hold = -1
	_hold_t = 0.0
	toast("Air scrubber reset", "warn")
	if _phase == 1:
		_make_sequence()


func _retry_step() -> void:
	match _phase:
		0:
			_hold = -1
			_hold_t = 0.0
			toast("Remove the remaining filters")
		1:
			_make_sequence()
			toast("Replacement sequence reset", "warn")


func _finish_installing() -> void:
	_phase = 2
	set_check(1, true)
	toast("Scrubbers running: air recovering", "good")


# --- input -------------------------------------------------------------------------------

func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion:
		_motion(event.position)


func _press(p: Vector2) -> void:
	if _phase == 0:
		for i in N:
			if _clogged[i] and centered(_filter_pos(i), FILTER_SIZE).has_point(p):
				_hold = i
				_hold_t = 0.0
	elif _phase == 1:
		for i in N:
			var t: Dictionary = _tray[i]
			if not t.placed and centered(t.pos, FILTER_SIZE).has_point(p):
				_drag = i
				_drag_off = t.pos - p
				break


func _motion(p: Vector2) -> void:
	if _phase == 0 and _hold >= 0:
		if not centered(_filter_pos(_hold), FILTER_SIZE).has_point(p):
			_hold = -1
			_hold_t = 0.0
	elif _phase == 1 and _drag >= 0:
		_tray[_drag].pos = p + _drag_off


func _release() -> void:
	if _phase == 0:
		_hold = -1
		_hold_t = 0.0
	elif _phase == 1 and _drag >= 0:
		_drop()


func _drop() -> void:
	var t: Dictionary = _tray[_drag]
	var center: Vector2 = t.pos
	_drag = -1
	t.pos = t.home
	for s in N:
		if centered(_slot_pos(s), SLOT_SIZE).has_point(center):
			if s != _next:
				toast("That slot is not ready yet", "warn")
			elif t.type != _order[s]:
				_penalty = 2.0
				toast("Wrong filter: air drains faster", "bad")
			else:
				t.placed = true
				_installed[s] = true
				_next += 1
				toast("Filter locked in", "good")
				if _next >= N:
					_finish_installing()
			return


# --- drawing -----------------------------------------------------------------------------

func _draw_game(c: Control) -> void:
	var heading: String = ["PHASE A   Remove the clogged filters (hold the mouse)",
		"PHASE B   Drag each filter into the highlighted slot", "Scrubbers running..."][_phase]
	txt(c, Vector2(10, 16), heading, 11, ACCENT)
	if _phase == 0:
		_draw_remove(c)
	else:
		_draw_replace(c)
	if _penalty > 0.0:
		MeterBar.draw_state_icon(c, Vector2(412, 16), 2, 6.0)
		txt(c, Vector2(300, 36), "AIR DRAINING FAST", 9, BAD, HORIZONTAL_ALIGNMENT_RIGHT, 124.0)


func _draw_remove(c: Control) -> void:
	for i in N:
		var r := centered(_filter_pos(i), FILTER_SIZE)
		if _clogged[i]:
			c.draw_rect(r, Color(0.28, 0.2, 0.12))
			c.draw_rect(r, Color(0.7, 0.5, 0.3), false, 2.0)
			c.draw_line(r.position + Vector2(8, 10), r.end - Vector2(8, 10), Color(0.1, 0.07, 0.04), 3.0)
			c.draw_line(Vector2(r.end.x - 8, r.position.y + 10), Vector2(r.position.x + 8, r.end.y - 10),
				Color(0.1, 0.07, 0.04), 3.0)
			MeterBar.draw_state_icon(c, Vector2(r.get_center().x, r.position.y - 10), 2, 5.0)
			txt(c, Vector2(r.position.x - 10, r.end.y + 14), "CLOGGED", 9, BAD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20)
			if _hold == i:
				var bar := Rect2(r.position + Vector2(0, r.size.y + 22), Vector2(r.size.x, 6))
				c.draw_rect(bar, Color(0.15, 0.15, 0.15))
				c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hold_t / HOLD_TIME, bar.size.y)), WARN)
		else:
			c.draw_rect(r, GOOD, false, 1.0)
			MeterBar.draw_state_icon(c, Vector2(r.get_center().x, r.position.y - 10), 0, 5.0)
			txt(c, Vector2(r.position.x - 10, r.end.y + 14), "REMOVED", 9, GOOD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 20)


func _draw_replace(c: Control) -> void:
	for s in N:
		var r := centered(_slot_pos(s), SLOT_SIZE)
		var need: int = _order[s]
		c.draw_rect(r, Color(0.1, 0.12, 0.15))
		if _installed[s]:
			c.draw_rect(r, Color(0.2, 0.5, 0.3, 0.45))
			c.draw_rect(r, GOOD, false, 3.0)
			draw_shape(c, need, r.get_center(), 14.0, COLORS[need])
			MeterBar.draw_state_icon(c, r.position + Vector2(r.size.x - 9, 9), 0, 5.0)
		else:
			var is_next := s == _next
			c.draw_rect(r, COLORS[need] if is_next else DIM, false, 3.0 if is_next else 1.0)
			if is_next:
				draw_shape(c, need, r.get_center(), 14.0, Color(COLORS[need], 0.35))
		txt(c, r.position + Vector2(5, 14), str(s + 1), 11, INK)
	for pass_index in 2:   # second pass draws the dragged filter on top
		for i in _tray.size():
			var t: Dictionary = _tray[i]
			if t.placed or (pass_index == 1) != (i == _drag):
				continue
			var r2 := centered(t.pos, FILTER_SIZE)
			c.draw_rect(r2, Color(0.16, 0.18, 0.22))
			c.draw_rect(r2, COLORS[t.type], false, 2.0)
			draw_shape(c, t.type, r2.get_center(), 14.0, COLORS[t.type])
			txt(c, Vector2(r2.position.x - 10, r2.end.y + 12), NAMES[t.type], 8, DIM, HORIZONTAL_ALIGNMENT_CENTER, r2.size.x + 20)
