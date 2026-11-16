extends Node2D
## Turtle lab room: wires the block editor to the turtle.


func _ready() -> void:
	$BlockEditor.turtle = $Turtle
