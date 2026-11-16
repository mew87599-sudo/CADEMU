extends Control
## The tablet screen (menu scene opened by Tablet through Overlay).
## Info view: current objective, notes for the room you are in, the objective list, and a round
## MAP button. Map view: Rooms/Menus/MapLayout.tscn (visited rooms only, red dot = you).
## Right click closes the tablet.

const INK := Color(0.86, 0.89, 0.92)
const DIM := Color(0.5, 0.55, 0.6)
const ACCENT := Color(0.4, 0.8, 1.0)
const MAP_PATH := "res://Rooms/Menus/MapLayout.tscn"
const INFO_PANEL := Rect2(60, 20, 520, 320)
const MAP_PANEL := Rect2(20, 12, 600, 336)

var _objective: Label
var _room: Label
var _list: Label
var _count: Label
var _map_btn: Control
var _map_hover := false
var _layout: MapLayout
var _panel: Panel
var _close: Button
var _holder: Control
var _bg: ColorRect
var _back: Button
var _legend: Label
var _here: Label
var _info_nodes: Array = []
var _map_nodes: Array = []


func _input(event: InputEvent) -> void:
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
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(60, 40)
	panel.size = Vector2(520, 280)
	add_child(panel)
	_panel = panel

	_label(panel, "CADEMU TABLET", Vector2(14, 8), Vector2(300, 18), 12, INK)
	var close := Button.new()
	close.text = "Close"
	close.position = Vector2(440, 6)
	close.size = Vector2(66, 20)
	close.add_theme_font_size_override("font_size", 10)
	close.pressed.connect(func(): Overlay.close())
	panel.add_child(close)
	_close = close

	# --- info view ---
	_info_nodes.append(_label(panel, "CURRENT OBJECTIVE", Vector2(14, 34), Vector2(300, 12), 9, DIM))
	_objective = _label(panel, "", Vector2(14, 46), Vector2(330, 36), 12, ACCENT)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_nodes.append(_objective)
	_info_nodes.append(_label(panel, "THIS ROOM", Vector2(14, 88), Vector2(300, 12), 9, DIM))
	_room = _label(panel, "", Vector2(14, 100), Vector2(330, 50), 10, INK)
	_room.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_room.clip_text = true
	_info_nodes.append(_room)
	_info_nodes.append(_label(panel, "OBJECTIVES", Vector2(14, 156), Vector2(300, 12), 9, DIM))
	# The objective list scrolls (mouse wheel) if it ever gets longer than the area.
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 168)
	scroll.size = Vector2(336, 142)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_info_nodes.append(scroll)
	_list = Label.new()
	_list.custom_minimum_size = Vector2(318, 0)
	_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_theme_font_size_override("font_size", 10)
	_list.add_theme_color_override("font_color", INK)
	scroll.add_child(_list)

	_map_btn = Control.new()
	_map_btn.position = Vector2(362, 70)
	_map_btn.size = Vector2(140, 140)
	_map_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_map_btn.draw.connect(_draw_map_btn)
	_map_btn.gui_input.connect(_on_map_btn_input)
	_map_btn.mouse_entered.connect(_on_map_hover.bind(true))
	_map_btn.mouse_exited.connect(_on_map_hover.bind(false))
	panel.add_child(_map_btn)
	_info_nodes.append(_map_btn)
	_count = _label(panel, "", Vector2(362, 218), Vector2(140, 14), 9, DIM)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_nodes.append(_count)

	# --- map view ---
	var holder := Control.new()
	holder.position = Vector2(14, 34)
	holder.size = Vector2(492, 214)
	holder.clip_contents = true
	panel.add_child(holder)
	_holder = holder
	_map_nodes.append(holder)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.1)
	bg.size = holder.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bg)
	_bg = bg
	var layout_scene := load(MAP_PATH) as PackedScene
	if layout_scene != null:
		_layout = layout_scene.instantiate() as MapLayout
		_layout.position = Vector2.ZERO
		holder.add_child(_layout)
	else:
		push_error("TabletMenu: missing %s" % MAP_PATH)
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(14, 254)
	back.size = Vector2(80, 20)
	back.add_theme_font_size_override("font_size", 10)
	back.pressed.connect(_show_map.bind(false))
	panel.add_child(back)
	_back = back
	_map_nodes.append(back)
	_legend = _label(panel, "Red dot = you are here. Dark areas are not discovered yet.",
		Vector2(104, 257), Vector2(300, 14), 9, DIM)
	_map_nodes.append(_legend)
	_here = _label(panel, "", Vector2(300, 257), Vector2(216, 14), 9, ACCENT)
	_here.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_map_nodes.append(_here)

	Objectives.changed.connect(_refresh)
	Tablet.map_changed.connect(_refresh)
	_show_map(false)
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


func _show_map(on: bool) -> void:
	for n in _info_nodes:
		n.visible = not on
	for n in _map_nodes:
		n.visible = on
	var r: Rect2 = MAP_PANEL if on else INFO_PANEL
	_panel.position = r.position
	_panel.size = r.size
	_close.position = Vector2(r.size.x - 80.0, 6.0)
	if on:
		_holder.size = Vector2(r.size.x - 28.0, r.size.y - 74.0)
		_bg.size = _holder.size
		_back.position = Vector2(14.0, r.size.y - 32.0)
		_legend.position = Vector2(104.0, r.size.y - 29.0)
		_here.position = Vector2(r.size.x - 230.0, r.size.y - 29.0)
		_fit_layout()


## The map picture can be any size: scale it to fit the holder and center it.
func _fit_layout() -> void:
	if _layout == null or _layout.size.x <= 0.0 or _layout.size.y <= 0.0:
		return
	var s: float = minf(_holder.size.x / _layout.size.x, _holder.size.y / _layout.size.y)
	_layout.scale = Vector2(s, s)
	_layout.position = (_holder.size - _layout.size * s) / 2.0


func _refresh() -> void:
	_objective.text = Objectives.current()
	var lines := PackedStringArray()
	for e in Objectives.entries():
		lines.append(("[X] " if e.done else "[ ] ") + str(e.text))
	_list.text = "\n".join(lines)
	var room: MapRoom = null
	if _layout != null:
		room = _layout.find_room(Tablet.current_room)
	if room == null:
		_room.text = "No map data for this room."
		_here.text = "You are in: unmapped area"
	else:
		var nm: String = room.display_name if room.display_name != "" else room.room_id
		var desc: String = room.description if room.description != "" else "No notes for this room yet."
		_room.text = "%s\n%s" % [nm, desc]
		_here.text = "You are in: " + nm
	_count.text = "%d rooms discovered" % Tablet.visited.size()


func _on_map_hover(on: bool) -> void:
	_map_hover = on
	_map_btn.queue_redraw()


func _on_map_btn_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.distance_to(Vector2(70, 70)) <= 56.0:
			_show_map(true)


func _draw_map_btn() -> void:
	var c := Vector2(70, 70)
	var col: Color = ACCENT if _map_hover else DIM
	_map_btn.draw_circle(c, 56.0, Color(0.08, 0.14, 0.18))
	_map_btn.draw_arc(c, 56.0, 0.0, TAU, 48, col, 3.0)
	_map_btn.draw_arc(c, 40.0, 0.0, TAU, 40, Color(col, 0.35), 1.0)
	_map_btn.draw_line(c + Vector2(-56, 0), c + Vector2(56, 0), Color(col, 0.25), 1.0)
	_map_btn.draw_line(c + Vector2(0, -56), c + Vector2(0, 56), Color(col, 0.25), 1.0)
	_map_btn.draw_string(ThemeDB.fallback_font, Vector2(0, 76), "MAP", HORIZONTAL_ALIGNMENT_CENTER, 140.0, 18, col)
