class_name BlockEditor
extends PanelContainer
## Mouse-only coding-block panel. Builds the program tree and hands it to a Turtle.
## UI is created in code so rooms only need to drop this node in and set `turtle`.

const DEFS := {
	"forward": {"label": "Forward", "default": 50, "step": 10, "min": 10, "max": 200, "unit": "px"},
	"left": {"label": "Left", "default": 90, "step": 15, "min": 15, "max": 180, "unit": "deg"},
	"right": {"label": "Right", "default": 90, "step": 15, "min": 15, "max": 180, "unit": "deg"},
	"repeat": {"label": "Repeat", "default": 4, "step": 1, "min": 1, "max": 36, "unit": "x"},
}

var turtle: Turtle
var program: Array = []

var _open: Array = []   # ids of repeat blocks being filled, innermost last
var _next_id := 1
var _list: VBoxContainer


func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 10
	position = Vector2.ZERO
	custom_minimum_size = Vector2(210, 360)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	add_child(margin)

	var root := VBoxContainer.new()
	margin.add_child(root)

	var palette := GridContainer.new()
	palette.columns = 3
	root.add_child(palette)
	for op in DEFS:
		_button(palette, DEFS[op].label, _add.bind(op))
	_button(palette, "End Repeat", _end_repeat)

	root.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	root.add_child(HSeparator.new())

	var controls := GridContainer.new()
	controls.columns = 4
	root.add_child(controls)
	_button(controls, "Run", func(): if turtle: turtle.run(program))
	_button(controls, "Stop", func(): if turtle: turtle.stop())
	_button(controls, "Clear", _clear_program)
	_button(controls, "Wipe", func(): if turtle: turtle.reset())

	_refresh()


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


# --- program editing ---------------------------------------------------------

func _add(op: String) -> void:
	var cmd := {"id": _next_id, "op": op, "n": DEFS[op].default}
	_next_id += 1
	if op == "repeat":
		cmd["body"] = []
	_target().append(cmd)
	if op == "repeat":
		_open.append(cmd.id)
	_refresh()


func _end_repeat() -> void:
	if not _open.is_empty():
		_open.pop_back()
	_refresh()


func _clear_program() -> void:
	program.clear()
	_open.clear()
	_refresh()


func _change(cmd: Dictionary, direction: int) -> void:
	var d: Dictionary = DEFS[cmd.op]
	cmd.n = clampi(int(cmd.n) + direction * int(d.step), int(d.min), int(d.max))
	_refresh()


func _delete(id: int) -> void:
	_remove_id(program, id)
	_open.clear()
	_refresh()


func _remove_id(arr: Array, id: int) -> bool:
	for i in arr.size():
		if arr[i].id == id:
			arr.remove_at(i)
			return true
		if arr[i].op == "repeat" and _remove_id(arr[i].body, id):
			return true
	return false


func _target() -> Array:
	if _open.is_empty():
		return program
	var body = _find_body(program, _open.back())
	return body if body != null else program


func _find_body(arr: Array, id: int):
	for c in arr:
		if c.op == "repeat":
			if c.id == id:
				return c.body
			var inner = _find_body(c.body, id)
			if inner != null:
				return inner
	return null


# --- rendering ---------------------------------------------------------------

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	_render(program, 0)


func _render(arr: Array, depth: int) -> void:
	for cmd in arr:
		var d: Dictionary = DEFS[cmd.op]
		var row := HBoxContainer.new()
		var indent := Control.new()
		indent.custom_minimum_size.x = depth * 10
		row.add_child(indent)

		var label := Label.new()
		var active: bool = cmd.op == "repeat" and not _open.is_empty() and cmd.id == _open.back()
		label.text = "%s %d%s%s" % [d.label, cmd.n, d.unit, " <" if active else ""]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		_small_button(row, "-", _change.bind(cmd, -1))
		_small_button(row, "+", _change.bind(cmd, 1))
		_small_button(row, "x", _delete.bind(cmd.id))
		_list.add_child(row)

		if cmd.op == "repeat":
			_render(cmd.body, depth + 1)


func _small_button(parent: Node, text: String, callback: Callable) -> void:
	var b := _button(parent, text, callback)
	b.custom_minimum_size.x = 18
