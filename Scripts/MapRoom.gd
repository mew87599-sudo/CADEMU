@tool
class_name MapRoom
extends Control
## One ZONE of the tablet map. Drag/resize this node over an area of the map picture in
## Rooms/Menus/MapLayout.tscn. In the editor it shows as a tinted box with its name and a red
## crosshair where the "you are here" dot will be. In game it is invisible unless its area is
## still undiscovered (then it dims the picture there) or the player is in it (white border + dot).
##
## Room Id           RoomManager name of the room (scene file name, any case): "hatch"
## Also In Zone      more room ids that share this zone (closeups etc.); the dot shows here for them too
## Display Name      name shown on the tablet
## Description       tablet text for this room (fill in whenever)
## Dot At            where the red dot sits inside the zone: (0,0) top-left, (1,1) bottom-right
## Always Lit        never dimmed
## Undim When Visited  room ids; the zone un-dims when the player visits ANY of them.
##                   Empty = it un-dims when the player enters Room Id or one of Also In Zone.
## Undim Flag        also un-dims when this Objectives flag is set (e.g. "status_report")
## Tint              editor box color only

@export var room_id := "":
	set(v):
		room_id = v
		queue_redraw()
@export var also_in_zone: PackedStringArray = []
@export var display_name := "":
	set(v):
		display_name = v
		queue_redraw()
@export_multiline var description := ""
@export var dot_at := Vector2(0.5, 0.5):
	set(v):
		dot_at = v
		queue_redraw()
@export var always_lit := false
@export var undim_when_visited: PackedStringArray = []
@export var undim_flag := ""
@export var tint := Color(0.3, 0.6, 0.8):
	set(v):
		tint = v
		queue_redraw()


## "res://Rooms/LivingModule.tscn" and "LivingModule" both become "livingmodule".
static func norm_id(id: String) -> String:
	var s := id.strip_edges()
	if s.begins_with("res://"):
		s = s.get_file().get_basename()
	return s.to_lower()


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Engine.is_editor_hint():
		Tablet.map_changed.connect(_refresh)
		Objectives.changed.connect(_refresh)
		_refresh()


## True if `id` is this zone's room or one of its extra rooms.
func has_room(id: String) -> bool:
	var key := norm_id(id)
	if key == "":
		return false
	if key == norm_id(room_id):
		return true
	for other in also_in_zone:
		if norm_id(other) == key:
			return true
	return false


func is_lit() -> bool:
	if Engine.is_editor_hint() or always_lit or Tablet.reveal_all:
		return true
	if has_marker():
		return true
	if undim_flag != "" and Objectives.has_flag(undim_flag):
		return true
	var ids := PackedStringArray(undim_when_visited)
	if ids.is_empty():
		ids = PackedStringArray(also_in_zone)
		ids.append(room_id)
	for id in ids:
		if Tablet.visited.has(norm_id(id)):
			return true
	return false


## True while Tablet has a marker (colored dot) set on this zone's room or one of its extra rooms.
func has_marker() -> bool:
	return not Engine.is_editor_hint() and marker_color() != Color.TRANSPARENT


func marker_color() -> Color:
	if Engine.is_editor_hint():
		return Color.TRANSPARENT
	var ids := PackedStringArray(also_in_zone)
	ids.append(room_id)
	for id in ids:
		var key := norm_id(id)
		if Tablet.markers.has(key):
			return Tablet.markers[key]
	return Color.TRANSPARENT


func is_current() -> bool:
	return not Engine.is_editor_hint() and has_room(Tablet.current_room)


func _refresh() -> void:
	set_process(is_current() or has_marker())
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()   # only runs while the player is in this zone (dot pulse)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var dot := Vector2(size.x * dot_at.x, size.y * dot_at.y)
	if Engine.is_editor_hint():
		draw_rect(rect, Color(tint, 0.25))
		draw_rect(rect, tint, false, 1.0)
		var label := display_name if display_name != "" else room_id
		draw_multiline_string(ThemeDB.fallback_font, Vector2(3.0, 11.0), label + "\n[" + room_id + "]",
			HORIZONTAL_ALIGNMENT_LEFT, size.x - 6.0, 9, -1, Color(1, 1, 1, 0.9))
		draw_circle(dot, 3.0, Color(1.0, 0.2, 0.2))
		draw_line(dot - Vector2(7, 0), dot + Vector2(7, 0), Color(1.0, 0.2, 0.2), 1.0)
		draw_line(dot - Vector2(0, 7), dot + Vector2(0, 7), Color(1.0, 0.2, 0.2), 1.0)
		return
	if not is_lit():
		draw_rect(rect, Color(0.0, 0.0, 0.0, 0.78))
	if is_current():
		draw_rect(rect, Color(1, 1, 1, 0.8), false, 1.0)
		var pulse := 0.0
		if not Subsystems.reduced_motion:
			pulse = 1.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		draw_circle(dot, 4.0 + pulse, Color(1.0, 0.2, 0.2))
	elif has_marker():
		var mc := marker_color()
		var ring := 0.0
		if not Subsystems.reduced_motion:
			ring = 2.0 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0))
		draw_circle(dot, 4.0, mc)
		draw_arc(dot, 7.0 + ring, 0.0, TAU, 24, Color(mc, 0.8), 1.5)
