@tool
class_name BackArrow
extends CanvasLayer
## The back arrow. It lives on its own CanvasLayer, so it is glued to the SCREEN: it stays at
## the same spot no matter where a room's camera is or how it moves, and it is drawn above the
## room. Its place is set once, in Rooms/Objects/BackArrow.tscn (the `Hotspot` node's position,
## default bottom center), so every room gets the same spot.
## Per room, only set where it goes: Target Room (name) or Target Scene (drag a .tscn).

@export var target_room := "hatch":
	set(value):
		target_room = value
		_push()
@export var target_scene: PackedScene:
	set(value):
		target_scene = value
		_push()


func _ready() -> void:
	_push()


func _push() -> void:
	var hotspot := get_node_or_null("Hotspot") as Hotspot
	if hotspot:
		hotspot.target_room = target_room
		hotspot.target_scene = target_scene
