@tool
class_name Hotspot
extends Area2D
## Invisible click area (the game's "hot button"). Left click opens a menu over the room
## (Menu Scene) or changes room (Target Scene / Target Room).
##
## Set it up in the editor, per instance, in the Inspector:
##   Position      = CENTER of the area (just drag the node in the 2D view)
##   Size          = width/height of the area in pixels
##   Menu Scene    = drag a menu scene (.tscn, root Control) here to open it OVER the room
##                   (see Overlay.gd). If set, it wins over the two targets below.
##   Target Scene  = drag a room scene (.tscn) from the FileSystem dock into this slot (easiest)
##   Target Room   = or type a room name: a file in Rooms/ ("hatch" finds Hatch.tscn) or a
##                   key of RoomManager.ROOMS. Target Scene wins if both are set.
## In the editor the area is drawn as a colored box with the target name, so you can see it.
## In game it is invisible; it only gets a faint outline and a hand cursor on hover.
##   Required Flag = optional Objectives flag that must be set before the click does anything
##                   (e.g. the bed needs "sleepy"). Until then Locked Message is shown instead.
## Turn on `show_in_game` to see every box while playing (or Debug > Visible Collision Shapes).

signal clicked

@export var target_room := "":
	set(value):
		target_room = value
		queue_redraw()
@export var menu_scene: PackedScene:
	set(value):
		menu_scene = value
		queue_redraw()
@export var target_scene: PackedScene:
	set(value):
		target_scene = value
		queue_redraw()
@export var size := Vector2(80, 80):
	set(value):
		size = value.max(Vector2(4, 4))
		_apply_size()
@export var color := Color(0.25, 0.85, 1.0)
@export var show_in_game := false
@export var required_flag := ""
@export var locked_message := "Not now."

var _hover := false


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _exit_tree() -> void:
	if _hover and not Engine.is_editor_hint():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Resizes the CollisionShape2D child named "Shape" (its shape is local to each instance).
func _apply_size() -> void:
	var node := get_node_or_null("Shape") as CollisionShape2D
	if node and node.shape is RectangleShape2D:
		node.shape.size = size
	queue_redraw()


func _set_hover(on: bool) -> void:
	_hover = on
	modulate = Color(1.3, 1.3, 1.3) if on else Color.WHITE
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
	queue_redraw()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if required_flag != "" and not Objectives.has_flag(required_flag):
			if locked_message != "":
				Story.say(locked_message)
			return
		clicked.emit()
		if menu_scene:
			Overlay.open(menu_scene)
		elif target_scene:
			RoomManager.go_to_scene(target_scene)
		elif target_room != "":
			RoomManager.go_to(target_room)


func _draw() -> void:
	var rect := Rect2(-size / 2.0, size)
	if Engine.is_editor_hint() or show_in_game:
		draw_rect(rect, Color(color, 0.18))
		draw_rect(rect, Color(color, 0.9), false, 1.0)
		var label := "(no target)"
		if menu_scene:
			label = "menu: " + menu_scene.resource_path.get_file().get_basename()
		elif target_scene:
			label = target_scene.resource_path.get_file().get_basename()
		elif target_room != "":
			label = target_room
		if required_flag != "":
			label += "  [needs: %s]" % required_flag
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(3, 11), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color.lightened(0.5))
	elif _hover:
		draw_rect(rect, Color(1, 1, 1, 0.08))
		draw_rect(rect, Color(1, 1, 1, 0.5), false, 1.0)
