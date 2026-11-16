extends MinigameBase
## ERR-004 Crew vital signs: heartbeat tuning.
## Three crew monitors each show a heart rate (BPM) that drifts. Click the "-" / "+" buttons to
## pull each rate into the safe band (60-85). Keep ALL THREE in the band for 8 seconds in a row.
## Leaving the band only pauses and rewinds the hold timer a little; nothing resets fully.
## Tuning: the constants below.

const CREW := ["CDT-1", "CDT-2", "CDT-3"]
const BAND_LO := 60.0
const BAND_HI := 85.0
const HOLD_NEEDED := 8.0
const NUDGE := 5.0            # BPM per click
const DRIFT := 3.0            # BPM per second, random walk
const REWIND := 2.0           # hold seconds lost per second outside the band
const ROW_Y0 := 40.0
const ROW_H := 62.0

var _meter: MeterBar
var _bpm: Array = []
var _vel: Array = []
var _phase: Array = [0.0, 0.0, 0.0]
var _hold := 0.0
var _buttons: Array = []   # [Rect2 minus, Rect2 plus] per crew


func _configure() -> void:
	subsystem_id = "ERR-004"
	title = "Vital signs: heartbeat tuning"
	checklist = ["All 3 heart rates in 60-85 BPM", "Hold steady for 8 seconds"]


func _init_game() -> void:
	_meter = add_meter("STEADY", true, 1.0, 0.3)
	_randomize()
	for i in CREW.size():
		var y := ROW_Y0 + i * ROW_H
		_buttons.append([Rect2(330, y + 10, 38, 34), Rect2(376, y + 10, 38, 34)])
	toast("Click - / + to bring each heart rate into the band")


func _randomize() -> void:
	_bpm = [randf_range(95.0, 120.0), randf_range(40.0, 52.0), randf_range(100.0, 125.0)]
	_vel = [0.0, 0.0, 0.0]
	_hold = 0.0


func _in_band(i: int) -> bool:
	return _bpm[i] >= BAND_LO and _bpm[i] <= BAND_HI


func _tick(delta: float) -> void:
	var all_in := true
	for i in CREW.size():
		_vel[i] = clampf(_vel[i] + randf_range(-1.0, 1.0) * DRIFT * delta * 4.0, -DRIFT, DRIFT)
		_bpm[i] = clampf(_bpm[i] + _vel[i] * delta, 30.0, 150.0)
		_phase[i] += _bpm[i] / 60.0 * delta
		if not _in_band(i):
			all_in = false
	set_check(0, all_in)
	if all_in:
		_hold += delta
	else:
		_hold = maxf(0.0, _hold - REWIND * delta)
	_meter.value = _hold / HOLD_NEEDED
	_meter.value_text = "%.1f s" % _hold
	set_check(1, _hold >= HOLD_NEEDED)
	if _hold >= HOLD_NEEDED:
		win()


func _retry_step() -> void:
	_randomize()
	toast("Monitors recalibrated", "warn")


func _game_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in CREW.size():
		if _buttons[i][0].has_point(event.position):
			_bpm[i] = maxf(30.0, _bpm[i] - NUDGE)
		elif _buttons[i][1].has_point(event.position):
			_bpm[i] = minf(150.0, _bpm[i] + NUDGE)


func _draw_game(c: Control) -> void:
	txt(c, Vector2(10, 16), "Safe band: %d-%d BPM" % [int(BAND_LO), int(BAND_HI)], 11, ACCENT)
	for i in CREW.size():
		var y := ROW_Y0 + i * ROW_H
		var ok := _in_band(i)
		var col := GOOD if ok else (WARN if absf(_bpm[i] - clampf(_bpm[i], BAND_LO, BAND_HI)) < 15.0 else BAD)
		var r := Rect2(10, y, 410, ROW_H - 8.0)
		c.draw_rect(r, Color(0.08, 0.11, 0.13))
		c.draw_rect(r, col, false, 1.0)
		txt(c, Vector2(18, y + 16), CREW[i], 10, INK)
		txt(c, Vector2(18, y + 34), "%d BPM" % int(_bpm[i]), 12, col)
		MeterBar.draw_state_icon(c, Vector2(88, y + 12), 0 if ok else (1 if col == WARN else 2), 5.0)
		txt(c, Vector2(18, y + 46), "OK" if ok else ("TOO HIGH" if _bpm[i] > BAND_HI else "TOO LOW"), 8, col)
		var pts := PackedVector2Array()
		for px in range(0, 200, 3):
			var ph := fposmod(_phase[i] - px / 200.0 * 2.0, 1.0)
			var v := 0.0
			if ph < 0.06:
				v = 1.0 - absf(ph - 0.03) / 0.03
			elif ph > 0.12 and ph < 0.2:
				v = -0.25 * (1.0 - absf(ph - 0.16) / 0.04)
			pts.append(Vector2(110 + px, y + 36 - v * 22.0))
		c.draw_polyline(pts, col, 1.5)
		c.draw_rect(_buttons[i][0], Color(0.2, 0.22, 0.28))
		c.draw_rect(_buttons[i][0], INK, false, 1.0)
		txt(c, _buttons[i][0].position + Vector2(0, 22), "-", 16, INK, HORIZONTAL_ALIGNMENT_CENTER, 38.0)
		c.draw_rect(_buttons[i][1], Color(0.2, 0.22, 0.28))
		c.draw_rect(_buttons[i][1], INK, false, 1.0)
		txt(c, _buttons[i][1].position + Vector2(0, 22), "+", 16, INK, HORIZONTAL_ALIGNMENT_CENTER, 38.0)
