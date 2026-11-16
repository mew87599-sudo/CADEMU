class_name Turtle
extends Node2D
## Classic turtle. Keep this node at the room origin: it draws its own trail and sprite
## in room coordinates. Heading 0 = up, clockwise positive.
##
## Programs are arrays of command dictionaries (see Architecture.md):
##   {"op": "forward", "n": 50}
##   {"op": "left" | "right", "n": 90}
##   {"op": "repeat", "n": 4, "body": [ ...commands... ]}

signal finished

@export var home := Vector2(420, 180)
@export var sprite: Texture2D = preload("res://Assets/Misc/turtle.png")
@export var sprite_scale := 2.0
@export var speed := 140.0        # pixels per second
@export var turn_speed := 360.0   # degrees per second
@export var line_color := Color.WHITE

var pos := Vector2.ZERO
var heading := 0.0
var running := false

var _stop := false
var _lines: Array = []  # each entry: [from: Vector2, to: Vector2]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reset()


func reset() -> void:
	_stop = true
	_lines.clear()
	pos = home
	heading = 0.0
	queue_redraw()


func stop() -> void:
	_stop = true


func run(program: Array) -> void:
	if running:
		return
	running = true
	_stop = false
	await _exec(program)
	running = false
	finished.emit()


func _exec(block: Array) -> void:
	for cmd in block:
		if _stop:
			return
		match cmd.op:
			"forward":
				await _move(float(cmd.n))
			"left":
				await _turn(-float(cmd.n))
			"right":
				await _turn(float(cmd.n))
			"repeat":
				for i in int(cmd.n):
					await _exec(cmd.body)
					if _stop:
						return


func _move(dist: float) -> void:
	if dist <= 0.0:
		return
	var start := pos
	var target := pos + Vector2.UP.rotated(deg_to_rad(heading)) * dist
	var line_idx := -1
	_lines.append([start, start])
	line_idx = _lines.size() - 1
	var travelled := 0.0
	while travelled < dist and not _stop:
		await get_tree().process_frame
		travelled = minf(travelled + speed * get_process_delta_time(), dist)
		pos = start.lerp(target, travelled / dist)
		if line_idx < _lines.size():
			_lines[line_idx][1] = pos
		queue_redraw()


func _turn(deg: float) -> void:
	var goal := heading + deg
	while not is_equal_approx(heading, goal) and not _stop:
		await get_tree().process_frame
		heading = move_toward(heading, goal, turn_speed * get_process_delta_time())
		queue_redraw()
	if not _stop:
		heading = fposmod(goal, 360.0)
		queue_redraw()


func _draw() -> void:
	for l in _lines:
		draw_line(l[0], l[1], line_color, 2.0)
	draw_set_transform(pos, deg_to_rad(heading), Vector2.ONE * sprite_scale)
	draw_texture(sprite, -sprite.get_size() / 2.0)
