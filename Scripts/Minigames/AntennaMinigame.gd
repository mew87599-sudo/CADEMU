extends MinigameBase
## ERR-005 External terminal network: antenna alignment.
## Move the mouse over the dish map while holding the left button to aim the antenna
## (x = azimuth, y = elevation). Signal strength peaks on a hidden target that slowly drifts
## with the solar wind. Keep the signal above 80% for 6 seconds.
## Leaving the peak only rewinds the hold timer; nothing resets fully.
## Tuning: the constants below.

const MAP := Rect2(20, 30, 394, 196)
const HOLD_NEEDED := 6.0
const LOCK := 0.8
const SPREAD := 90.0          # signal falloff radius in pixels
const DRIFT := 6.0            # target drift speed, px per second
const REWIND := 1.5

var _meter: MeterBar
var _aim := Vector2(MAP.position.x + MAP.size.x / 2.0, MAP.position.y + MAP.size.y / 2.0)
var _target := Vector2.ZERO
var _tvel := Vector2.ZERO
var _aiming := false
var _signal := 0.0
var _hold := 0.0


func _configure() -> void:
	subsystem_id = "ERR-005"
	title = "Terminal network: antenna alignment"
	checklist = ["Signal above 80%", "Hold lock for 6 seconds"]


func _init_game() -> void:
	_meter = add_meter("SIGNAL", true, LOCK, 0.4)
	_randomize()
	toast("Hold the mouse button and sweep to find the signal peak")


func _randomize() -> void:
	_target = MAP.position + Vector2(randf_range(40.0, MAP.size.x - 40.0), randf_range(30.0, MAP.size.y - 30.0))
	_tvel = Vector2.from_angle(randf() * TAU) * DRIFT
	_hold = 0.0


func _tick(delta: float) -> void:
	_target += _tvel * delta
	if _target.x < MAP.position.x + 20.0 or _target.x > MAP.end.x - 20.0:
		_tvel.x = -_tvel.x
	if _target.y < MAP.position.y + 20.0 or _target.y > MAP.end.y - 20.0:
		_tvel.y = -_tvel.y
	var d := _aim.distance_to(_target)
	_signal = exp(-(d * d) / (2.0 * SPREAD * SPREAD * 0.25))
	_meter.value = _signal
	var locked := _signal >= LOCK
	set_check(0, locked)
	if locked:
		_hold += delta
	else:
		_hold = maxf(0.0, _hold - REWIND * delta)
	set_check(1, _hold >= HOLD_NEEDED)
	if _hold >= HOLD_NEEDED:
		win()


func _retry_step() -> void:
	_randomize()
	toast("Target reacquired elsewhere", "warn")


func _game_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_aiming = event.pressed
		if _aiming:
			_aim = _clamp_aim(event.position)
	elif event is InputEventMouseMotion and _aiming:
		_aim = _clamp_aim(event.position)


func _clamp_aim(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, MAP.position.x, MAP.end.x), clampf(p.y, MAP.position.y, MAP.end.y))


func _draw_game(c: Control) -> void:
	txt(c, Vector2(10, 16), "Aim: hold mouse and sweep.  Lock: %.1f / %d s" % [_hold, int(HOLD_NEEDED)], 11, ACCENT)
	c.draw_rect(MAP, Color(0.05, 0.08, 0.1))
	c.draw_rect(MAP, DIM, false, 1.0)
	for gx in range(1, 8):
		c.draw_line(Vector2(MAP.position.x + gx * MAP.size.x / 8.0, MAP.position.y),
			Vector2(MAP.position.x + gx * MAP.size.x / 8.0, MAP.end.y), Color(1, 1, 1, 0.05), 1.0)
	for gy in range(1, 4):
		c.draw_line(Vector2(MAP.position.x, MAP.position.y + gy * MAP.size.y / 4.0),
			Vector2(MAP.end.x, MAP.position.y + gy * MAP.size.y / 4.0), Color(1, 1, 1, 0.05), 1.0)
	var st := 0 if _signal >= LOCK else (1 if _signal >= 0.4 else 2)
	var col: Color = [GOOD, WARN, BAD][st]
	c.draw_arc(_aim, 14.0, 0.0, TAU, 24, col, 2.0)
	c.draw_line(_aim - Vector2(20, 0), _aim + Vector2(20, 0), col, 1.0)
	c.draw_line(_aim - Vector2(0, 20), _aim + Vector2(0, 20), col, 1.0)
	MeterBar.draw_state_icon(c, _aim + Vector2(0, -26), st, 5.0)
	txt(c, Vector2(MAP.position.x, MAP.end.y + 14), "AZIMUTH >", 9, DIM)
	txt(c, Vector2(MAP.position.x + 100, MAP.end.y + 14),
		"signal %d%%  %s" % [int(_signal * 100.0), ["LOCKED", "WEAK", "NO SIGNAL"][st]], 10, col)
