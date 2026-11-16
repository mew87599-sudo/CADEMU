extends Clickable
## Desk hatch. First click takes the (already unscrewed) cover off, next click opens the room.

@export var target_room := "wiring"


func _ready() -> void:
	super._ready()
	_sync()


func _activate() -> void:
	if not PowerGrid.cover_removed:
		PowerGrid.cover_removed = true
		_sync()
	else:
		RoomManager.go_to(target_room)


func _sync() -> void:
	$Cover.visible = not PowerGrid.cover_removed
	$Hole.visible = PowerGrid.cover_removed
