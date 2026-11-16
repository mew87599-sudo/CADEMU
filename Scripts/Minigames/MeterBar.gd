class_name MeterBar
extends Control
## Generic progress / quality / timer bar. Color + a shape icon show the state (colorblind safe):
##   circle = good (green), triangle = warning (amber), square with X = failing (red).
## good_high = true : high values are good (air quality, battery). false: low is good (radiation).
## good_at is the threshold for "good" (also drawn as a white tick), bad_at for "failing".

const GOOD := Color(0.35, 0.9, 0.5)
const WARN := Color(1.0, 0.75, 0.25)
const BAD := Color(1.0, 0.4, 0.38)

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var label := ""
var value_text := ""   # shown instead of the percentage when not empty
var good_high := true
var good_at := 0.6
var bad_at := 0.3


## 0 good, 1 warning, 2 failing
func state() -> int:
	if good_high:
		if value >= good_at:
			return 0
		return 2 if value < bad_at else 1
	if value <= good_at:
		return 0
	return 2 if value >= bad_at else 1


func _draw() -> void:
	var st := state()
	var col: Color = [GOOD, WARN, BAD][st]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.11, 0.13))
	draw_rect(Rect2(0, 0, size.x * value, size.y), col.darkened(0.35))
	draw_rect(Rect2(Vector2.ZERO, size), col, false, 1.0)
	var tick_x := size.x * good_at
	draw_line(Vector2(tick_x, 0), Vector2(tick_x, size.y), Color(1, 1, 1, 0.5), 1.0)
	var shown := value_text if value_text != "" else "%d%%" % int(round(value * 100.0))
	draw_string(ThemeDB.fallback_font, Vector2(4, size.y - 5), "%s %s" % [label, shown],
		HORIZONTAL_ALIGNMENT_LEFT, size.x - 22, 9, Color(0.92, 0.94, 0.96))
	draw_state_icon(self, Vector2(size.x - 10, size.y / 2.0), st, 4.0)


## Call only while drawing on `ci`.
static func draw_state_icon(ci: CanvasItem, c: Vector2, st: int, r: float) -> void:
	match st:
		0:
			ci.draw_circle(c, r, GOOD)
		1:
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r)]), WARN)
		_:
			ci.draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), BAD)
			ci.draw_line(c - Vector2(r, r) * 0.6, c + Vector2(r, r) * 0.6, Color.BLACK, 1.0)
			ci.draw_line(c + Vector2(r, -r) * 0.6, c + Vector2(-r, r) * 0.6, Color.BLACK, 1.0)
