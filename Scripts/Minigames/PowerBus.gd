class_name PowerBus
extends Control
## Five breakers (one per subsystem) and the 0-100% outpost power meter, driven by Subsystems.
## A breaker flashes when its subsystem goes ONLINE; the meter rises smoothly (instantly with
## reduced motion).

const GOOD := Color(0.35, 0.9, 0.5)
const BAD := Color(1.0, 0.4, 0.38)
const INK := Color(0.86, 0.89, 0.92)

var _shown := 0.0
var _flash := {}   # subsystem id -> remaining flash time


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shown = float(Subsystems.power_percent())
	Subsystems.status_changed.connect(func(id: String): _flash[id] = 1.0)


func _process(delta: float) -> void:
	var target := float(Subsystems.power_percent())
	if Subsystems.reduced_motion:
		_shown = target
	else:
		_shown = move_toward(_shown, target, 40.0 * delta)
	for id in _flash.keys():
		_flash[id] -= delta * 1.5
		if _flash[id] <= 0.0:
			_flash.erase(id)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in Subsystems.IDS.size():
		var id: String = Subsystems.IDS[i]
		var on := Subsystems.is_online(id)
		var r := Rect2(i * 26.0, 3.0, 22.0, 30.0)
		draw_rect(r, Color(0.12, 0.13, 0.16))
		draw_rect(r, GOOD if on else BAD, false, 1.0)
		var lever := Rect2(r.position.x + 5.0, r.position.y + (3.0 if on else 17.0), 12.0, 10.0)
		draw_rect(lever, GOOD if on else BAD)
		draw_string(font, Vector2(r.position.x + 7.0, r.position.y + (26.0 if on else 12.0)),
			"I" if on else "O", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
		if _flash.has(id):
			draw_rect(r.grow(2.0), Color(1, 1, 1, clampf(_flash[id], 0.0, 1.0)), false, 2.0)
	var bx := 138.0
	draw_rect(Rect2(bx, 6.0, size.x - bx, 12.0), Color(0.1, 0.11, 0.13))
	draw_rect(Rect2(bx, 6.0, (size.x - bx) * _shown / 100.0, 12.0), GOOD.darkened(0.2))
	draw_rect(Rect2(bx, 6.0, size.x - bx, 12.0), INK, false, 1.0)
	var label := "OUTPOST POWERED" if Subsystems.powered else "OUTPOST POWER  %d%%" % int(round(_shown))
	draw_string(font, Vector2(bx, 31.0), label, HORIZONTAL_ALIGNMENT_LEFT, size.x - bx, 9, INK)
