class_name LabMenu
extends Control
## Base of the lab menus (storage, bench, computer). Right click closes, like every menu.
## Subclasses override _build() and add their controls.


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		Overlay.close()
		get_viewport().set_input_as_handled()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	pass


func _close() -> void:
	Overlay.close()
