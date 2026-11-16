extends CanvasLayer
## Autoload. The tablet: a small icon fixed at the bottom right of the screen (hidden on the
## title and intro). Clicking it opens Rooms/Menus/TabletMenu.tscn through Overlay.
## Also remembers which rooms the player has visited, for the map.
##
##   Tablet.current_room         normalized id of the room the player is in
##   Tablet.is_revealed(id)      true if that room has been visited (or reveal_all)
##   Tablet.reveal_all           debug: show the whole map (terminal command `debug_map`)
##   Tablet.map_changed          emitted when the current room / visited list changes
## The icon shows an amber dot when the objectives changed since the tablet was last opened.

signal map_changed

const MENU_PATH := "res://Rooms/Menus/TabletMenu.tscn"
const HIDDEN_ROOMS := ["login", "title", "intro", "main", "dream"]
const ICON_POS := Vector2(588, 316)
const ICON_SIZE := Vector2(44, 36)

var current_room := ""
var visited := {}
var reveal_all := false
var markers := {}   # normalized room id -> Color: a colored dot on that room's map zone
var unread := false

var _icon: Control
var _hover := false
var _in_hidden_room := true


func _ready() -> void:
	layer = 9
	_icon = Control.new()
	_icon.position = ICON_POS
	_icon.size = ICON_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_icon.draw.connect(_draw_icon)
	_icon.gui_input.connect(_on_icon_input)
	_icon.mouse_entered.connect(_on_hover.bind(true))
	_icon.mouse_exited.connect(_on_hover.bind(false))
	add_child(_icon)
	_refresh_icon()
	RoomManager.room_changed.connect(_on_room_changed)
	Objectives.changed.connect(_on_objectives_changed)
	Overlay.opened.connect(func(_menu: Node): _refresh_icon())
	Overlay.closed.connect(_refresh_icon)


func is_revealed(id: String) -> bool:
	return reveal_all or visited.has(MapRoom.norm_id(id))


## Puts a colored dot (and lights the zone) on the map for room `id`, e.g. the yellow "go here" dot.
func set_marker(id: String, color: Color) -> void:
	markers[MapRoom.norm_id(id)] = color
	map_changed.emit()


func clear_marker(id: String) -> void:
	if markers.erase(MapRoom.norm_id(id)):
		map_changed.emit()


func set_reveal_all(on: bool) -> void:
	reveal_all = on
	map_changed.emit()


func open_tablet() -> void:
	if Overlay.current != null and Overlay.current.scene_file_path == MENU_PATH:
		Overlay.close()
		return
	unread = false
	Overlay.open(load(MENU_PATH) as PackedScene)


func _on_room_changed(id: String) -> void:
	current_room = MapRoom.norm_id(id)
	_in_hidden_room = HIDDEN_ROOMS.has(current_room)
	if not _in_hidden_room:
		visited[current_room] = true
	_refresh_icon()
	map_changed.emit()


func _on_objectives_changed() -> void:
	unread = true
	_icon.queue_redraw()


func _refresh_icon() -> void:
	_icon.visible = not _in_hidden_room and not Overlay.is_open()


func _on_hover(on: bool) -> void:
	_hover = on
	_icon.queue_redraw()


func _on_icon_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_tablet()


func _process(_delta: float) -> void:
	if unread and _icon.visible and not Subsystems.reduced_motion:
		_icon.queue_redraw()


func _draw_icon() -> void:
	var r := Rect2(Vector2.ZERO, ICON_SIZE)
	var edge: Color = Color(0.75, 0.85, 0.95) if _hover else Color(0.45, 0.52, 0.6)
	_icon.draw_rect(r, Color(0.1, 0.12, 0.15))
	_icon.draw_rect(r, edge, false, 2.0)
	var screen := r.grow(-5.0)
	_icon.draw_rect(screen, Color(0.18, 0.42, 0.55) if _hover else Color(0.12, 0.3, 0.4))
	for i in 3:
		var y: float = screen.position.y + 6.0 + i * 7.0
		var x2: float = screen.end.x - 4.0 - (i % 2) * 8.0
		_icon.draw_line(Vector2(screen.position.x + 4.0, y), Vector2(x2, y), Color(0.5, 0.9, 1.0, 0.8), 1.0)
	if unread:
		var a := 1.0
		if not Subsystems.reduced_motion:
			a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		_icon.draw_circle(Vector2(ICON_SIZE.x - 3.0, 3.0), 4.0, Color(1.0, 0.75, 0.25, a))
