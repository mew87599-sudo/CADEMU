extends MinigameBase
## ERR-001 Radiation shield: solar flare defense.
## Five shield segments cover the base. Flares are announced by a warning marker above a segment
## (1.4 s). Click that segment to raise its shield for 2 s (then 1.5 s cooldown). An unshielded
## flare raises radiation. Survive 30 seconds with radiation below 40%.
## Soft fail: radiation at 100% resets only the survival timer and lowers radiation.
## Tuning: the constants below.

const SEGMENTS := 5
const SEG_W := 74.0
const SEG_X0 := 22.0
const SEG_Y := 190.0
const SEG_H := 36.0
const WARN_TIME := 1.4
const SHIELD_TIME := 2.0
const COOLDOWN := 1.5
const SURVIVE := 30.0
const HIT_RAD := 0.22
const DECAY := 0.02            # radiation lost per second
const SPAWN_START := 2.0
const SPAWN_END := 0.9         # spawn interval shrinks as time passes
const WIN_RAD := 0.4
const RESET_RAD := 0.4

var _meter: MeterBar
var _rad := 0.0
var _time := 0.0
var _next_spawn := 1.5
var _seg: Array = []      # {"shield": float, "cool": float}
var _flares: Array = []   # {"seg": int, "t": float}
var _ever_over := false


func _configure() -> void:
	subsystem_id = "ERR-001"
	title = "Radiation shield: flare defense"
	checklist = ["Survive 30 seconds", "Radiation below 40%"]


func _init_game() -> void:
	_meter = add_meter("RADIATION", false, WIN_RAD, 0.7)
	for i in SEGMENTS:
		_seg.append({"shield": 0.0, "cool": 0.0})
	toast("Click the segment under a warning to raise its shield")


func _seg_rect(i: int) -> Rect2:
	return Rect2(SEG_X0 + i * (SEG_W + 6.0), SEG_Y, SEG_W, SEG_H)


func _tick(delta: float) -> void:
	_time += delta
	for s in _seg:
		s.shield = maxf(0.0, s.shield - delta)
		s.cool = maxf(0.0, s.cool - delta)
	for f in _flares.duplicate():
		f.t -= delta
		if f.t <= 0.0:
			_flares.erase(f)
			if _seg[f.seg].shield > 0.0:
				toast("Flare blocked", "good")
			else:
				_rad += HIT_RAD
				toast("Radiation spike", "bad")
	_next_spawn -= delta
	if _next_spawn <= 0.0 and _time < SURVIVE - WARN_TIME:
		var k := clampf(_time / SURVIVE, 0.0, 1.0)
		_next_spawn = lerpf(SPAWN_START, SPAWN_END, k)
		_flares.append({"seg": randi() % SEGMENTS, "t": WARN_TIME})
	_rad = clampf(_rad - DECAY * delta, 0.0, 1.0)
	_meter.value = _rad
	if _rad >= 1.0:
		_soft_fail()
		return
	set_check(0, _time >= SURVIVE)
	set_check(1, _time >= SURVIVE and _rad < WIN_RAD)
	if _time >= SURVIVE and _flares.is_empty():
		if _rad < WIN_RAD:
			win()
		else:
			_rad = maxf(0.0, _rad - 0.1 * delta)   # keep scrubbing until under the limit


func _soft_fail() -> void:
	_rad = RESET_RAD
	_time = 0.0
	_flares.clear()
	_next_spawn = 1.5
	toast("Radiation critical: timer restarted", "bad")


func _retry_step() -> void:
	_rad = minf(_rad, RESET_RAD)
	_time = 0.0
	_flares.clear()
	_next_spawn = 1.5
	for s in _seg:
		s.shield = 0.0
		s.cool = 0.0
	toast("Defense restarted", "warn")


func _game_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in SEGMENTS:
		if _seg_rect(i).grow(6.0).has_point(event.position):
			var s: Dictionary = _seg[i]
			if s.shield > 0.0 or s.cool > 0.0:
				toast("Shield recharging", "warn")
			else:
				s.shield = SHIELD_TIME
				s.cool = SHIELD_TIME + COOLDOWN
			return


func _draw_game(c: Control) -> void:
	txt(c, Vector2(10, 16), "SURVIVE  %d / %d s" % [int(minf(_time, SURVIVE)), int(SURVIVE)], 11, ACCENT)
	c.draw_rect(Rect2(10, 24, 414.0 * clampf(_time / SURVIVE, 0.0, 1.0), 4), ACCENT)
	for i in SEGMENTS:
		var r := _seg_rect(i)
		var s: Dictionary = _seg[i]
		c.draw_rect(r, Color(0.14, 0.17, 0.22))
		if s.shield > 0.0:
			c.draw_rect(r, Color(0.2, 0.6, 0.9, 0.5))
			c.draw_rect(r, ACCENT, false, 3.0)
			c.draw_arc(r.get_center() + Vector2(0, 6), 28.0, PI, TAU, 16, ACCENT, 2.0)
			txt(c, r.position + Vector2(0, r.size.y + 12), "SHIELD", 8, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		elif s.cool > 0.0:
			c.draw_rect(r, DIM, false, 1.0)
			txt(c, r.position + Vector2(0, r.size.y + 12), "RECHARGE", 8, DIM, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			c.draw_rect(r, GOOD, false, 2.0)
			txt(c, r.position + Vector2(0, r.size.y + 12), "READY", 8, GOOD, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	for f in _flares:
		var r2 := _seg_rect(f.seg)
		var x := r2.get_center().x
		var y := lerpf(r2.position.y - 8.0, 44.0, f.t / WARN_TIME)
		c.draw_line(Vector2(x, 36), Vector2(x, r2.position.y - 6.0), Color(WARN, 0.35), 1.0)
		c.draw_circle(Vector2(x, y), 9.0, WARN)
		MeterBar.draw_state_icon(c, Vector2(x, 38), 1, 6.0)
		txt(c, Vector2(x - 30, 58), "FLARE", 8, WARN, HORIZONTAL_ALIGNMENT_CENTER, 60.0)
