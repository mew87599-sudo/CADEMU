class_name SpecimenView
extends Control
## The microscope's round field of view. Draws a procedural "thin section" for each specimen kind:
##   basalt       dark laths with brown and green grains
##   anorthosite  big light feldspar crystals with fine stripes
##   regolith     fine irregular grains, glass beads, dark clumps
##   unknown      dark grains plus branching, cell-like structures (Sample 04)
##   ordinary     plain dark rock (what Sample 04 looks like in the second examination)
## The picture is blurred by focus error and darkened / washed out by the illumination.
## Drag with the mouse to move across the specimen (or to wipe the lens in wipe mode).

signal moved

const WORLD := 480.0                       # the specimen is a 480 x 480 world
const SCALES := [0.5, 1.0, 2.0, 3.5]       # world -> screen scale for x40 / x100 / x200 / x400
const MAGS := ["x40", "x100", "x200", "x400"]
const VIEW := 240.0
const POI_RADIUS := 90.0                   # world units at x100; the allowed distance shrinks as you zoom in

var kind := "basalt"
var center := Vector2(WORLD / 2.0, WORLD / 2.0)
var mag_idx := 0
var illum := 0.5
var focus := 0.1
var opt_focus := 0.5
var pois: Array = []
var smudges: Array = []
var wipe_mode := false

var _elements: Array = []   # {t, c, r, pts/a/b, col, w}


func _init() -> void:
	custom_minimum_size = Vector2(VIEW, VIEW)
	size = Vector2(VIEW, VIEW)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE


## `id` seeds the picture (the same specimen always looks the same).
func set_specimen(id: int, new_kind: String) -> void:
	kind = new_kind
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + id * 131 + (7 if new_kind == "ordinary" else 0)
	_elements.clear()
	pois.clear()
	match kind:
		"basalt", "ordinary":
			_make_basalt(rng)
		"anorthosite":
			_make_anorthosite(rng)
		"regolith":
			_make_regolith(rng)
		"unknown":
			_make_unknown(rng)
	if pois.is_empty():
		for i in 3:
			pois.append(Vector2(rng.randf_range(110.0, 370.0), rng.randf_range(110.0, 370.0)))
	opt_focus = rng.randf_range(0.3, 0.8)
	center = Vector2(WORLD / 2.0, WORLD / 2.0)
	mag_idx = 0
	illum = 0.5
	focus = 0.1
	smudges.clear()
	if not Mission.lens_clean:
		for i in 4:
			smudges.append(Vector2(rng.randf_range(20.0, VIEW - 20.0), rng.randf_range(20.0, VIEW - 20.0)))
	queue_redraw()


func scale_now() -> float:
	return SCALES[mag_idx]


func focus_error() -> float:
	return absf(focus - opt_focus)


func clarity() -> float:
	return 1.0 - clampf(focus_error() / 0.4, 0.0, 1.0)


func poi_in_view() -> bool:
	for p in pois:
		if (p as Vector2).distance_to(center) <= POI_RADIUS / maxf(scale_now(), 1.0):
			return true
	return false


## {"ok": bool, "msg": String}: can a usable image be taken right now?
func check_image() -> Dictionary:
	if focus_error() > 0.12:
		return {"ok": false, "msg": "Image is out of focus."}
	if illum < 0.3:
		return {"ok": false, "msg": "Image is too dark."}
	if illum > 0.88:
		return {"ok": false, "msg": "Image is overexposed."}
	if mag_idx < 2:
		return {"ok": false, "msg": "Magnification too low to resolve the structures."}
	if not poi_in_view():
		return {"ok": false, "msg": "Nothing of interest in the field of view."}
	return {"ok": true, "msg": ""}


func set_view(new_mag: int, new_illum: float, new_focus: float) -> void:
	mag_idx = clampi(new_mag, 0, SCALES.size() - 1)
	illum = new_illum
	focus = new_focus
	queue_redraw()


func pan(delta_world: Vector2) -> void:
	center = (center + delta_world).clamp(Vector2(30, 30), Vector2(WORLD - 30.0, WORLD - 30.0))
	queue_redraw()
	moved.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if wipe_mode:
			_wipe(event.position)
		else:
			pan(-event.relative / scale_now())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and wipe_mode:
		_wipe(event.position)


func _wipe(p: Vector2) -> void:
	var before := smudges.size()
	var keep: Array = []
	for s in smudges:
		if (s as Vector2).distance_to(p) > 26.0:
			keep.append(s)
	smudges = keep
	if smudges.size() != before:
		queue_redraw()
		moved.emit()


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	var s := scale_now()
	var half := Vector2(VIEW, VIEW) / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), _background())
	var err := focus_error()
	var blur := clampf(err * 14.0, 0.0, 6.0)
	var copies := 1 + int(blur * 1.2)
	var alpha_mul := 1.0 if copies == 1 else 1.4 / float(copies)
	for k in copies:
		var off := Vector2.ZERO
		if k > 0:
			off = Vector2.from_angle(float(k) * 2.4) * blur * (0.6 + 0.15 * float(k))
		for e in _elements:
			_draw_element(e, s, half, off, alpha_mul)
	# lens smudges
	for sm in smudges:
		draw_circle(sm, 16.0, Color(1, 1, 1, 0.07))
		draw_circle(sm, 9.0, Color(1, 1, 1, 0.07))
	# illumination
	if illum < 0.5:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, clampf((0.5 - illum) * 1.7, 0.0, 0.88)))
	elif illum > 0.8:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, clampf((illum - 0.8) * 3.2, 0.0, 0.7)))
	# round lens mask
	draw_arc(half, 150.0, 0.0, TAU, 72, Color(0, 0, 0, 1), 62.0)
	draw_arc(half, 120.0, 0.0, TAU, 72, Color(0.5, 0.55, 0.6, 0.6), 1.5)
	draw_line(half + Vector2(-6, 0), half + Vector2(6, 0), Color(1, 1, 1, 0.25), 1.0)
	draw_line(half + Vector2(0, -6), half + Vector2(0, 6), Color(1, 1, 1, 0.25), 1.0)


func _background() -> Color:
	match kind:
		"anorthosite":
			return Color(0.76, 0.76, 0.78)
		"regolith":
			return Color(0.22, 0.21, 0.2)
		"unknown":
			return Color(0.12, 0.13, 0.11)
		"ordinary":
			return Color(0.13, 0.13, 0.14)
	return Color(0.1, 0.1, 0.12)


func _to_screen(p: Vector2, s: float, half: Vector2, off: Vector2) -> Vector2:
	return (p - center) * s + half + off


func _draw_element(e: Dictionary, s: float, half: Vector2, off: Vector2, alpha_mul: float) -> void:
	var c: Vector2 = e.c
	var r: float = e.r
	var sc := _to_screen(c, s, half, off)
	if sc.distance_to(half) > 175.0 + r * s:
		return   # outside the view
	var col: Color = e.col
	col.a *= alpha_mul
	match int(e.t):
		0:
			var src: PackedVector2Array = e.pts
			var pts := PackedVector2Array()
			for p in src:
				pts.append(_to_screen(p, s, half, off))
			draw_colored_polygon(pts, col)
		1:
			draw_circle(sc, maxf(r * s, 0.8), col)
		2:
			draw_line(_to_screen(e.a, s, half, off), _to_screen(e.b, s, half, off), col, maxf(float(e.w) * s, 0.8))
		3:
			draw_arc(sc, maxf(r * s, 1.0), 0.0, TAU, 20, col, maxf(float(e.w) * s, 0.8))


# --- procedural specimens --------------------------------------------------------------------

func _rot_rect(c: Vector2, length: float, width: float, angle: float) -> PackedVector2Array:
	var d := Vector2.from_angle(angle) * length * 0.5
	var n := Vector2.from_angle(angle + PI / 2.0) * width * 0.5
	return PackedVector2Array([c - d - n, c + d - n, c + d + n, c - d + n])


func _add_poly(pts: PackedVector2Array, col: Color, c: Vector2, r: float) -> void:
	_elements.append({"t": 0, "c": c, "r": r, "pts": pts, "col": col})


func _add_circle(c: Vector2, r: float, col: Color) -> void:
	_elements.append({"t": 1, "c": c, "r": r, "col": col})


func _add_line(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	_elements.append({"t": 2, "c": (a + b) * 0.5, "r": a.distance_to(b) * 0.5 + w, "a": a, "b": b, "w": w, "col": col})


func _add_ring(c: Vector2, r: float, w: float, col: Color) -> void:
	_elements.append({"t": 3, "c": c, "r": r + w, "w": w, "col": col})


func _rand_pos(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(rng.randf_range(0.0, WORLD), rng.randf_range(0.0, WORLD))


func _make_basalt(rng: RandomNumberGenerator) -> void:
	for i in 190:
		var c := _rand_pos(rng)
		var g := rng.randf_range(0.22, 0.5)
		var len_ := rng.randf_range(10.0, 30.0)
		_add_poly(_rot_rect(c, len_, rng.randf_range(3.0, 8.0), rng.randf_range(-0.5, 0.5) + (0.0 if i % 3 else 1.2)),
			Color(g, g, g + 0.04, 1.0), c, len_)
	for i in 50:
		_add_circle(_rand_pos(rng), rng.randf_range(3.0, 7.0), Color(0.45, 0.34, 0.24, 1.0))
	for i in 22:
		_add_circle(_rand_pos(rng), rng.randf_range(3.0, 6.0), Color(0.5, 0.66, 0.36, 1.0))


func _make_anorthosite(rng: RandomNumberGenerator) -> void:
	for i in 64:
		var c := _rand_pos(rng)
		var len_ := rng.randf_range(40.0, 92.0)
		var wid := rng.randf_range(14.0, 30.0)
		var ang := rng.randf_range(-0.4, 0.4) + (0.0 if i % 2 else 1.1)
		var g := rng.randf_range(0.84, 0.97)
		_add_poly(_rot_rect(c, len_, wid, ang), Color(g, g, g, 1.0), c, len_)
		for k in 4:   # fine stripes across the crystal
			var o := Vector2.from_angle(ang + PI / 2.0) * (float(k) - 1.5) * wid * 0.22
			_add_line(c + o - Vector2.from_angle(ang) * len_ * 0.5, c + o + Vector2.from_angle(ang) * len_ * 0.5, 1.2, Color(0.3, 0.3, 0.34, 0.28))
	for i in 26:
		var c := _rand_pos(rng)
		_add_circle(c, rng.randf_range(3.0, 7.0), Color(0.35, 0.35, 0.4, 0.8))


func _make_regolith(rng: RandomNumberGenerator) -> void:
	for i in 340:
		var c := _rand_pos(rng)
		var r := rng.randf_range(2.0, 9.0)
		var pts := PackedVector2Array()
		var n := 5 + rng.randi() % 3
		for k in n:
			var a := TAU * float(k) / float(n) + rng.randf_range(-0.25, 0.25)
			pts.append(c + Vector2.from_angle(a) * r * rng.randf_range(0.65, 1.1))
		var g := rng.randf_range(0.15, 0.62)
		_add_poly(pts, Color(g * 1.05, g, g * 0.92, 1.0), c, r * 1.2)
	for i in 28:
		var c := _rand_pos(rng)
		var r := rng.randf_range(3.0, 8.0)
		_add_circle(c, r, Color(0.2, 0.28, 0.3, 1.0))
		_add_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(0.7, 0.85, 0.9, 0.8))
	for i in 12:
		_add_circle(_rand_pos(rng), rng.randf_range(12.0, 22.0), Color(0.08, 0.07, 0.07, 0.9))


func _make_unknown(rng: RandomNumberGenerator) -> void:
	for i in 70:   # ordinary dark grains underneath
		var c := _rand_pos(rng)
		var g := rng.randf_range(0.16, 0.3)
		var len_ := rng.randf_range(8.0, 22.0)
		_add_poly(_rot_rect(c, len_, rng.randf_range(3.0, 6.0), rng.randf_range(-1.0, 1.0)), Color(g, g, g, 1.0), c, len_)
	var roots := [Vector2(140, 230), Vector2(330, 150), Vector2(250, 340)]
	pois = roots.duplicate()
	for root in roots:
		_branch(rng, root, rng.randf_range(0.0, TAU), 34.0, 6, 3.2)
		for i in 7:   # cell-like rings around each root
			var p: Vector2 = root + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 46.0)
			_add_ring(p, rng.randf_range(3.5, 7.0), 1.2, Color(0.45, 0.7, 0.4, 0.8))
			_add_circle(p, rng.randf_range(1.0, 2.0), Color(0.6, 0.85, 0.5, 0.9))


func _branch(rng: RandomNumberGenerator, from: Vector2, angle: float, length: float, depth: int, width: float) -> void:
	if depth <= 0 or length < 4.0:
		return
	var to := from + Vector2.from_angle(angle) * length
	var shade := 0.35 + 0.08 * float(depth)
	_add_line(from, to, width, Color(0.3 * shade, 0.7 * shade, 0.28 * shade, 0.95))
	var kids := 2 + (rng.randi() % 2)
	for k in kids:
		var a := angle + rng.randf_range(-0.8, 0.8)
		_branch(rng, to, a, length * rng.randf_range(0.66, 0.8), depth - 1, maxf(width * 0.72, 0.8))
