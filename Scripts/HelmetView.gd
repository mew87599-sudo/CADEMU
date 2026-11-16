class_name HelmetView
extends Control
## Placeholder art: a procedural grey lunar landscape seen through a helmet camera
## (black sky with stars, far ridge, two ground bands, craters, rocks). It is drawn a little
## larger than the 640x360 screen so the intro can sway/nod it without showing edges.
## Replace it with a real helmet-cam image by swapping the node for a Sprite2D in Intro.

var _stars := PackedVector2Array()
var _star_alpha := PackedFloat32Array()
var _ridge := PackedVector2Array()
var _craters: Array = []  # each: [center: Vector2, rx: float, ry: float]
var _rocks: Array = []    # each: PackedVector2Array


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		_stars.append(Vector2(rng.randf_range(-10.0, 650.0), rng.randf_range(-10.0, 190.0)))
		_star_alpha.append(rng.randf_range(0.25, 1.0))
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.01
	for x in range(-20, 681, 10):
		_ridge.append(Vector2(float(x), 186.0 + noise.get_noise_1d(float(x)) * 26.0))
	for i in 16:
		var rx := rng.randf_range(14.0, 70.0)
		var center := Vector2(rng.randf_range(0.0, 640.0), rng.randf_range(250.0, 345.0))
		_craters.append([center, rx, rx * rng.randf_range(0.18, 0.3)])
	for i in 12:
		var c := Vector2(rng.randf_range(0.0, 640.0), rng.randf_range(240.0, 350.0))
		var s := rng.randf_range(4.0, 12.0)
		_rocks.append(PackedVector2Array([
			c + Vector2(-s, 0.0), c + Vector2(-s * 0.4, -s * 0.8),
			c + Vector2(s * 0.6, -s * 0.6), c + Vector2(s, 0.0)]))


func _draw() -> void:
	draw_rect(Rect2(-30, -30, 700, 440), Color.BLACK)
	for i in _stars.size():
		draw_rect(Rect2(_stars[i], Vector2(1, 1)), Color(1, 1, 1, _star_alpha[i]))

	var far := PackedVector2Array(_ridge)
	far.append(Vector2(690, 420))
	far.append(Vector2(-30, 420))
	draw_colored_polygon(far, Color(0.30, 0.30, 0.31))
	draw_polyline(_ridge, Color(0.5, 0.5, 0.52), 1.0)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, 226), Vector2(180, 214), Vector2(420, 222), Vector2(690, 212),
		Vector2(690, 420), Vector2(-30, 420)]), Color(0.42, 0.42, 0.43))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, 275), Vector2(250, 262), Vector2(690, 270),
		Vector2(690, 420), Vector2(-30, 420)]), Color(0.52, 0.52, 0.53))

	for c in _craters:
		var center: Vector2 = c[0]
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(center + Vector2(cos(a) * float(c[1]), sin(a) * float(c[2])))
		draw_colored_polygon(pts, Color(0.33, 0.33, 0.34))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.66, 0.66, 0.68), 1.0)

	for r in _rocks:
		draw_colored_polygon(r, Color(0.25, 0.25, 0.26))

	draw_rect(Rect2(-30, 300, 700, 110), Color(0, 0, 0, 0.22))
