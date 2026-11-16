extends MinigameBase
## ERR-003 Power collection manager: micrometeorite battery repair.
## A 4x3 battery bank is hit by micrometeorites in 3 waves. A hit is announced by a target mark
## (1.2 s warning); when it lands the cell becomes DAMAGED and leaks charge. Click a damaged
## cell to patch it. Clicking a cell during the warning shields it (one shield per cell).
## Win: all 3 waves survived, every cell patched, charge above 60%.
## Soft fail: charge at 0% restarts only the current wave (patched cells stay patched).
## Tuning: the constants below.

const COLS := 4
const ROWS := 3
const CELL := Vector2(86, 62)
const ORIGIN := Vector2(26, 44)
const GAP := Vector2(12, 14)
const WAVES := [4, 6, 8]            # impacts per wave
const WARN_TIME := 1.2
const SPAWN_EVERY := [1.6, 1.3, 1.0]
const CHARGE_START := 0.8
const LEAK_PER_CELL := 0.025        # per second per damaged cell
const RECOVER := 0.03               # per second when nothing is damaged
const RESET_CHARGE := 0.5
const WIN_CHARGE := 0.6

var _meter: MeterBar
var _charge := CHARGE_START
var _wave := 0
var _spawned := 0
var _next_spawn := 1.5
var _cells: Array = []   # {"state": 0 ok, 1 warning, 2 damaged, "t": float, "shield": bool}
var _done := false


func _configure() -> void:
	subsystem_id = "ERR-003"
	title = "Power collection: battery repair"
	checklist = ["Survive 3 meteorite waves", "All cells patched", "Charge above 60%"]


func _init_game() -> void:
	_meter = add_meter("CHARGE", true, WIN_CHARGE, 0.3)
	_meter.value = _charge
	for i in COLS * ROWS:
		_cells.append({"state": 0, "t": 0.0, "shield": false})
	toast("Patch damaged cells. Click a marked cell to shield it first")


func _cell_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	return Rect2(ORIGIN + Vector2(col * (CELL.x + GAP.x), row * (CELL.y + GAP.y)), CELL)


func _damaged_count() -> int:
	var n := 0
	for c in _cells:
		if c.state == 2:
			n += 1
	return n


func _tick(delta: float) -> void:
	for c in _cells:
		if c.state == 1:
			c.t -= delta
			if c.t <= 0.0:
				if c.shield:
					c.state = 0
					c.shield = false
					toast("Shield absorbed the hit", "good")
				else:
					c.state = 2
					toast("Cell damaged: click to patch", "warn")
	var dmg := _damaged_count()
	if dmg > 0:
		_charge -= LEAK_PER_CELL * dmg * delta
	elif _spawned >= WAVES[mini(_wave, WAVES.size() - 1)] or _done:
		_charge += RECOVER * delta
	_charge = clampf(_charge, 0.0, 1.0)
	_meter.value = _charge
	if _charge <= 0.0:
		_soft_fail()
		return
	if not _done:
		_run_wave(delta)
	set_check(1, _done and dmg == 0)
	set_check(2, _charge > WIN_CHARGE)
	if _done and dmg == 0 and _charge > WIN_CHARGE:
		win()


func _run_wave(delta: float) -> void:
	var total: int = WAVES[_wave]
	if _spawned < total:
		_next_spawn -= delta
		if _next_spawn <= 0.0:
			_next_spawn = SPAWN_EVERY[_wave]
			_spawn_hit()
	else:
		var busy := false
		for c in _cells:
			if c.state != 0:
				busy = true
		if not busy:
			_wave += 1
			_spawned = 0
			_next_spawn = 2.0
			if _wave >= WAVES.size():
				_done = true
				set_check(0, true)
				toast("All waves survived: stabilize the charge", "good")
			else:
				toast("Wave %d of %d incoming" % [_wave + 1, WAVES.size()], "warn")


func _spawn_hit() -> void:
	var free: Array = []
	for i in _cells.size():
		if _cells[i].state == 0:
			free.append(i)
	_spawned += 1
	if free.is_empty():
		return
	var c: Dictionary = _cells[free[randi() % free.size()]]
	c.state = 1
	c.t = WARN_TIME
	c.shield = false


func _soft_fail() -> void:
	_charge = RESET_CHARGE
	_spawned = 0
	_next_spawn = 2.0
	for c in _cells:
		if c.state == 1:
			c.state = 0
	toast("Charge collapsed: wave restarted", "bad")


func _retry_step() -> void:
	_spawned = 0
	_next_spawn = 2.0
	_charge = maxf(_charge, RESET_CHARGE)
	for c in _cells:
		c.state = 0
		c.shield = false
	toast("Wave restarted", "warn")


func _game_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in _cells.size():
		if not _cell_rect(i).has_point(event.position):
			continue
		var c: Dictionary = _cells[i]
		if c.state == 2:
			c.state = 0
			toast("Cell patched", "good")
		elif c.state == 1 and not c.shield:
			c.shield = true
			toast("Shield up")
		return


func _draw_game(c: Control) -> void:
	txt(c, Vector2(10, 16), "WAVE %d / %d" % [mini(_wave + 1, WAVES.size()), WAVES.size()], 11, ACCENT)
	for i in _cells.size():
		var r := _cell_rect(i)
		var cell: Dictionary = _cells[i]
		c.draw_rect(r, Color(0.12, 0.16, 0.2))
		match cell.state:
			0:
				c.draw_rect(r, GOOD, false, 1.0)
				MeterBar.draw_state_icon(c, r.position + Vector2(r.size.x - 9, 9), 0, 4.0)
			1:
				c.draw_rect(r, WARN, false, 2.0)
				var ctr := r.get_center()
				var rad: float = 8.0 + (cell.t / WARN_TIME) * 10.0
				c.draw_arc(ctr, rad, 0.0, TAU, 20, WARN, 2.0)
				c.draw_line(ctr - Vector2(rad + 4, 0), ctr + Vector2(rad + 4, 0), WARN, 1.0)
				c.draw_line(ctr - Vector2(0, rad + 4), ctr + Vector2(0, rad + 4), WARN, 1.0)
				MeterBar.draw_state_icon(c, r.position + Vector2(r.size.x - 9, 9), 1, 4.0)
				if cell.shield:
					c.draw_rect(r.grow(-4), ACCENT, false, 2.0)
			_:
				c.draw_rect(r, Color(0.35, 0.1, 0.1))
				c.draw_rect(r, BAD, false, 2.0)
				c.draw_line(r.position + Vector2(10, 10), r.end - Vector2(10, 10), BAD, 2.0)
				c.draw_line(Vector2(r.end.x - 10, r.position.y + 10), Vector2(r.position.x + 10, r.end.y - 10), BAD, 2.0)
				MeterBar.draw_state_icon(c, r.position + Vector2(r.size.x - 9, 9), 2, 4.0)
		txt(c, r.position + Vector2(4, r.size.y - 4), "CELL %02d" % (i + 1), 8, DIM)
	txt(c, Vector2(10, 238), "amber target = incoming (click to shield)   red X = damaged (click to patch)",
		9, DIM)
