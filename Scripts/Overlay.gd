extends CanvasLayer
## Autoload. Shows a menu scene ON TOP of the current room (terminal, tablet, notes...).
##
## Overlay.open(packed_scene)   shows the scene's root Control full-screen over a dimmer
## Overlay.close()              removes it again
## While a menu is open the dimmer swallows mouse clicks, so hotspots in the room underneath
## can't be pressed. Closing: the menu's own close button, right click on the dimmer, or Esc.
## Changing room also closes the menu.
##
## Menu scenes: any scene whose root is a Control (it is stretched to the full 640x360 view).
## Put the scene in Rooms/Menus/ and hook it up with a Hotspot's "Menu Scene" slot, or call
## Overlay.open(preload("res://Rooms/Menus/Thing.tscn")) from any script.

signal opened(menu: Node)
signal closed

var current: Node

var _dim: ColorRect
var _holder: Control


func _ready() -> void:
	layer = 20  # above rooms (0) and the BackArrow layer (10)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)

	RoomManager.room_changed.connect(func(_id: String): close())


func is_open() -> bool:
	return current != null


func open(scene: PackedScene) -> void:
	if scene == null:
		push_error("Overlay.open: no scene given")
		return
	close()
	current = scene.instantiate()
	_holder.add_child(current)
	if current is Control:
		current.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	opened.emit(current)


func close() -> void:
	if current == null:
		return
	current.queue_free()
	current = null
	_dim.visible = false
	closed.emit()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if current and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
