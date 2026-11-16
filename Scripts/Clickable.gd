class_name Clickable
extends Area2D
## Base for any room object reacted to with the mouse. Needs a CollisionShape2D child.
## Override _activate() in subclasses, or connect to `clicked`.

signal clicked


func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(func(): modulate = Color(1.25, 1.25, 1.25))
	mouse_exited.connect(func(): modulate = Color.WHITE)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		_activate()


func _activate() -> void:
	pass
