extends Node2D
## Wiring panel ("second screen" of the console). Everything is drawn in _draw from PowerGrid.
## Left click uses the held tool; clicking a tool picks it up / puts it down; right click
## puts it down.

enum Tool { HAND, SCISSORS, IRON, TIN }

const TOOL_NAMES := {Tool.HAND: "Hand", Tool.SCISSORS: "Scissors", Tool.IRON: "Solder iron", Tool.TIN: "Tin"}
const BG := Color(0.12, 0.13, 0.16)
const INK := Color(0.85, 0.85, 0.82)
const COPPER := Color(0.88, 0.52, 0.2)
const SOLDER := Color(0.78, 0.8, 0.84)
const HILITE := Color(1.0, 1.0, 0.4)
const TRAY := Color(0.2, 0.21, 0.25)

var tool: int = Tool.HAND
var selected_end := -1
var message := ""

var _font: Font
var _tools := {}  # Tool -> {"poly": PackedVector2Array, "center": Vector2, "label": String}


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_tools = {
		Tool.IRON: {"poly": _diamond(Vector2(100, 290), 80, 15), "center": Vector2(100, 290), "label": "Solder iron"},
		Tool.SCISSORS: {"poly": _heart(Vector2(267, 288), 2.4), "center": Vector2(262, 284), "label": "scissors"},
		Tool.TIN: {"poly": _hexagon(Vector2(406, 292), 43, 29), "center": Vector2(406, 292), "label": "tin"},
	}
	$Reset.pressed.connect(_on_reset)
	PowerGrid.changed.connect(_on_grid_changed)
	message = "Click a tool to pick it up. Right click puts it down."


func _process(_delta: float) -> void:
	queue_redraw()  # heat glow and tool cursor


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		tool = Tool.HAND
		selected_end = -1
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if PowerGrid.failed:
		message = "System halted. Press Reset."
		return

	var m := get_local_mouse_position()
	for t in _tools:
		if Geometry2D.is_point_in_polygon(m, _tools[t]["poly"]):
			tool = Tool.HAND if tool == t else t
			selected_end = -1
			message = "Holding: %s" % TOOL_NAMES[tool]
			return

	var sp: int = PowerGrid.hit_splice(m)
	if sp != -1:
		_use_on_splice(sp)
		return
	var e: int = PowerGrid.hit_end(m)
	if e != -1:
		_use_on_end(e)
		return
	var w: Dictionary = PowerGrid.hit_wire(m)
	if not w.is_empty():
		_use_on_wire(w["seg"], w["t"])
		return
	selected_end = -1


func _use_on_splice(id: int) -> void:
	match tool:
		Tool.HAND: message = PowerGrid.twist(id)
		Tool.SCISSORS: message = PowerGrid.unsplice(id)
		Tool.IRON: message = PowerGrid.heat(id)
		Tool.TIN: message = PowerGrid.solder(id)


func _use_on_end(id: int) -> void:
	match tool:
		Tool.SCISSORS:
			message = PowerGrid.strip(id)
		Tool.HAND:
			if PowerGrid.ends[id]["state"] != "stripped":
				message = "The insulation is still on. Strip it with the scissors."
			elif selected_end == -1:
				selected_end = id
				message = "Now click another stripped end to splice them."
			elif selected_end == id:
				selected_end = -1
				message = "Let go of the wire."
			else:
				message = PowerGrid.make_splice(selected_end, id)
				selected_end = -1
		_:
			message = "Splice two stripped ends together first (hand)."


func _use_on_wire(sid: int, t: float) -> void:
	selected_end = -1
	if tool == Tool.SCISSORS:
		message = PowerGrid.cut(sid, t)
	else:
		message = "A wire. The scissors would cut it."


func _on_reset() -> void:
	PowerGrid.reset()
	selected_end = -1
	tool = Tool.HAND
	message = "Panel reset."


func _on_grid_changed() -> void:
	if not PowerGrid.ends.has(selected_end):
		selected_end = -1
	queue_redraw()


# --- drawing ---------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), BG)
	draw_string(_font, Vector2(56, 18), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK)

	draw_rect(Rect2(1, 30, 49, 199), INK, false, 1.0)
	draw_rect(Rect2(482, 46, 92, 186), INK, false, 1.0)
	for s in PowerGrid.SOURCES:
		var p: Vector2 = PowerGrid.SOURCE_POS[s]
		draw_string(_font, Vector2(5, p.y + 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		draw_circle(p, 2.0, INK)
	for d in PowerGrid.DEVICES:
		var p: Vector2 = PowerGrid.DEVICE_POS[d]
		draw_string(_font, Vector2(486, p.y + 3), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, INK)
		draw_circle(p, 2.0, INK)

	for sid in PowerGrid.segments:
		var seg: Dictionary = PowerGrid.segments[sid]
		draw_polyline(PowerGrid.samples(seg["p"], 40), seg["color"], 2.0)

	for eid in PowerGrid.ends:
		var e: Dictionary = PowerGrid.ends[eid]
		if e["kind"] != "free" or e["state"] == "spliced":
			continue
		var p: Vector2 = PowerGrid.end_pos(eid)
		if e["state"] == "stripped":
			draw_circle(p, 2.5, COPPER)
		else:
			var c: Color = PowerGrid.segments[e["seg"]]["color"]
			draw_circle(p, 2.5, c.darkened(0.5))
		if eid == selected_end:
			draw_arc(p, 6.0, 0.0, TAU, 20, HILITE, 1.0)

	for id in PowerGrid.splices:
		var sp: Dictionary = PowerGrid.splices[id]
		var c: Vector2 = sp["pos"]
		var h: float = sp["heat"]
		if h > 0.0:
			draw_circle(c, 8.0, Color(1.0, 0.45, 0.1, 0.6 * h))
		if sp["soldered"]:
			draw_circle(c, 5.0, SOLDER)
		else:
			draw_circle(c, 3.0, COPPER)
			for i in int(sp["wraps"]):
				var x: float = -6.0 + i * 2.0
				draw_line(c + Vector2(x, -4), c + Vector2(x + 1.5, 4), COPPER.lightened(0.3), 1.0)
			if sp["wraps"] < PowerGrid.WRAPS_NEEDED:
				draw_string(_font, c + Vector2(-8, -8), "%d/%d" % [sp["wraps"], PowerGrid.WRAPS_NEEDED],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)

	for t in _tools:
		var poly: PackedVector2Array = _tools[t]["poly"]
		draw_colored_polygon(poly, TRAY)
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, HILITE if t == tool else INK, 2.0 if t == tool else 1.0)
		var center: Vector2 = _tools[t]["center"]
		draw_string(_font, center + Vector2(-50, 4), _tools[t]["label"], HORIZONTAL_ALIGNMENT_CENTER, 100, 11, INK)

	if PowerGrid.solved:
		draw_string(_font, Vector2(486, 222), "ALL NOMINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.4, 1.0, 0.5))
	if PowerGrid.failed:
		draw_rect(Rect2(0, 0, 640, 360), Color(0.6, 0.0, 0.0, 0.35))
		draw_string(_font, Vector2(0, 180), "SYSTEM HALTED", HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color.WHITE)

	if tool != Tool.HAND:
		draw_string(_font, get_local_mouse_position() + Vector2(8, -6), TOOL_NAMES[tool],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, HILITE)


func _diamond(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(-hw, 0), c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh)])


func _hexagon(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-hw, 0), c + Vector2(-hw / 2, -hh), c + Vector2(hw / 2, -hh),
		c + Vector2(hw, 0), c + Vector2(hw / 2, hh), c + Vector2(-hw / 2, hh),
	])


func _heart(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y - 2.5) * s)
	return pts
