class_name GameCanvas
extends Control
## The drawing and input surface of a minigame. The minigame provides the two callbacks:
##   draw_cb(canvas)   called from _draw, so it may call canvas.draw_*()
##   input_cb(event)   mouse events in canvas coordinates

var bg_color := Color(0.03, 0.04, 0.05)
var draw_cb: Callable
var input_cb: Callable


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), bg_color)
	if draw_cb.is_valid():
		draw_cb.call(self)


func _gui_input(event: InputEvent) -> void:
	if input_cb.is_valid():
		input_cb.call(event)
