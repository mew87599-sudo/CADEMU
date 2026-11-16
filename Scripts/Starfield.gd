class_name Starfield
extends Node2D
## Stars flying past from right to left in several depth layers (deeper = faster, dimmer).
## `speed` is a base speed in px/s that can be tweened from outside (warp burst, then settle).

@export var count := 110
@export var size := Vector2(640, 360)
var speed := 90.0

var _stars: Array = []  # each: [x, y, depth]


func _ready() -> void:
	for i in count:
		_stars.append([randf() * size.x, randf() * size.y, randf_range(0.15, 1.0)])


func _process(delta: float) -> void:
	for s in _stars:
		s[0] -= speed * s[2] * delta
		if s[0] + _streak(s) < 0.0:
			s[0] = size.x + randf() * 20.0
			s[1] = randf() * size.y
	queue_redraw()


func _streak(s: Array) -> float:
	return maxf(1.0, floorf(speed * s[2] * 0.035))


func _draw() -> void:
	for s in _stars:
		var depth: float = s[2]
		var c := Color(1, 1, 1).darkened(1.0 - depth).lerp(Color(0.75, 0.85, 1.0), 0.3)
		var thick := 2.0 if depth > 0.7 else 1.0
		draw_rect(Rect2(floorf(s[0]), floorf(s[1]), _streak(s), thick), c)
