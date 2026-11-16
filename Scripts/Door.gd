class_name Door
extends Clickable
## Click to change room. Set `target_room` (a key of RoomManager.ROOMS) per instance.

@export var target_room := ""


func _activate() -> void:
	RoomManager.go_to(target_room)
