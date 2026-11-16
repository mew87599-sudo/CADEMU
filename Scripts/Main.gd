extends Node
## Persistent root. Never freed; rooms live under $RoomHost.

@export var start_room := "login"   # "login" = fake login screen first (see FakeAccounts.gd); "title" skips it


func _ready() -> void:
	if not ["title", "login"].has(start_room):
		Music.set_muffled(false)  # Music starts muffled; only the login and title screens want that
	RoomManager.register_host($RoomHost)
	RoomManager.go_to(start_room)
