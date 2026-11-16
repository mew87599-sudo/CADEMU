class_name LabUI
extends RefCounted
## Small helpers to build the lab menus in code (panels, labels, buttons) in one consistent style.

const INK := Color(0.86, 0.89, 0.92)
const DIM := Color(0.5, 0.55, 0.6)
const GOOD := Color(0.35, 0.9, 0.5)
const BAD := Color(1.0, 0.4, 0.38)
const WARN := Color(1.0, 0.8, 0.3)
const PANEL_BG := Color(0.07, 0.08, 0.1, 0.98)
const PANEL_LINE := Color(0.4, 0.45, 0.5)


static func panel(parent: Node, pos: Vector2, sz: Vector2, line: Color = PANEL_LINE) -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = line
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", style)
	p.position = pos
	p.size = sz
	parent.add_child(p)
	return p


static func label(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int = 10, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, pos: Vector2, sz: Vector2, callback: Callable, font_size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


static func rich(parent: Node, pos: Vector2, sz: Vector2, font_size: int = 10) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.position = pos
	r.size = sz
	r.add_theme_font_size_override("normal_font_size", font_size)
	r.add_theme_font_size_override("bold_font_size", font_size)
	r.add_theme_color_override("default_color", INK)
	parent.add_child(r)
	return r


static func slider(parent: Node, pos: Vector2, width: float, lo: float, hi: float, step: float, value: float, callback: Callable) -> HSlider:
	var s := HSlider.new()
	s.position = pos
	s.size = Vector2(width, 16)
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(callback)
	parent.add_child(s)
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
