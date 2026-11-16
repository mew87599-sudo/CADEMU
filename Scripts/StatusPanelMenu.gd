extends Control
## Outpost status panel: the five subsystems with their live status, plus the power bus.
## A menu scene for Overlay (Hotspot > Menu Scene). It is also the natural first page of the
## future tablet. Updates live while open.

const GOOD := Color(0.35, 0.9, 0.5)
const BAD := Color(1.0, 0.4, 0.38)
const INK := Color(0.86, 0.89, 0.92)
const DIM := Color(0.5, 0.55, 0.6)

var _rows: Array = []   # per subsystem: {"icon": Label, "name": Label, "state": Label}
var _footer: Label


func _input(event: InputEvent) -> void:
	# Right click anywhere closes the menu (panels would otherwise swallow it).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Overlay.close()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.98)
	style.border_color = Color(0.4, 0.45, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(100, 50)
	panel.size = Vector2(440, 260)
	add_child(panel)

	_label(panel, "OUTPOST STATUS", Vector2(14, 10), Vector2(300, 18), 13, INK)
	var bus := PowerBus.new()
	bus.position = Vector2(14, 34)
	bus.size = Vector2(264, 38)
	panel.add_child(bus)

	for i in Subsystems.IDS.size():
		var y := 88.0 + i * 26.0
		_rows.append({
			"icon": _label(panel, "", Vector2(14, y), Vector2(30, 18), 10, INK),
			"name": _label(panel, "", Vector2(48, y), Vector2(260, 18), 10, INK),
			"state": _label(panel, "", Vector2(312, y), Vector2(120, 18), 10, INK),
		})
	_footer = _label(panel, "", Vector2(14, 224), Vector2(300, 18), 11, GOOD)

	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(366, 226)
	close.size = Vector2(60, 22)
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(func(): Overlay.close())
	panel.add_child(close)

	Subsystems.status_changed.connect(func(_id: String): _refresh())
	_refresh()


func _label(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _refresh() -> void:
	var data := Subsystems.rows()
	for i in data.size():
		var row: Array = data[i]
		var online: bool = row[2] == "ONLINE"
		var r: Dictionary = _rows[i]
		var color := GOOD if online else BAD
		r.icon.text = "[OK]" if online else "[X]"
		r.name.text = "%s  %s" % [row[0], row[1]]
		r.state.text = str(row[2]) if row[3] == "" else "%s (%s)" % [row[2], row[3]]
		for key in ["icon", "state"]:
			r[key].add_theme_color_override("font_color", color)
	if Subsystems.powered:
		_footer.text = "OUTPOST POWERED"
	else:
		_footer.text = "%d of %d subsystems online" % [Subsystems.online_count(), Subsystems.IDS.size()]
