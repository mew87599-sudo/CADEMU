class_name NavButton
extends Button
## Plain GUI button that changes room. Set `target_room` (a key of RoomManager.ROOMS).

@export var target_room := ""


func _ready() -> void:
	pressed.connect(func(): RoomManager.go_to(target_room))
