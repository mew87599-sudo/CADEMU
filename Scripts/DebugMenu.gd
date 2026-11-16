extends CanvasLayer
## Autoload. Debug menu, toggled with Shift+F12. Meant for testing: jump to any point of the
## story, teleport to a room, flip individual story flags and a few helpers.
## To ship without it, remove DebugMenu from Project > Project Settings > Autoload (or set ENABLED = false).

const ENABLED := true
const FLAGS := [
	"console_opened", "status_report", "sleepy", "dream_seen", "mc_briefing",
	"samples_retrieved", "samples_delivered", "samples_prepared", "samples_examined",
	"report_submitted", "recheck_requested", "sample4_rechecked", "second_uploaded",
]
const SKIP_ROOMS := ["main"]

var _panel: Panel
var _info: Label
var _flag_boxes := {}
var _room_pick: OptionButton
var _boxes_on := false
var _rooms: Array = []


func _ready() -> void:
	layer = 40   # above everything, including the room transition cover
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ENABLED:
		set_process_input(false)
		return
	_build()
	_panel.visible = false
	Objectives.changed.connect(_refresh)
	RoomManager.room_changed.connect(_on_room_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12 and event.shift_pressed:
		_panel.visible = not _panel.visible
		if _panel.visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = LabUI.panel(self, Vector2(6, 6), Vector2(318, 348), Color(0.9, 0.3, 0.3))
	LabUI.label(_panel, "DEBUG  (Shift+F12 to close)", Vector2(10, 6), Vector2(260, 16), 11, Color(1.0, 0.5, 0.45))
	LabUI.button(_panel, "X", Vector2(286, 4), Vector2(24, 20), _hide, 10)
	_info = LabUI.label(_panel, "", Vector2(10, 26), Vector2(298, 40), 9, LabUI.DIM)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(6, 68)
	scroll.size = Vector2(306, 274)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(290, 0)
	box.add_theme_constant_override("separation", 3)
	scroll.add_child(box)

	_header(box, "JUMP TO PROGRESS")
	for i in Mission.STAGES.size():
		var st: Dictionary = Mission.STAGES[i]
		_button(box, "%d. %s" % [i, st.label], _jump.bind(String(st.id)))

	_header(box, "ROOM")
	_room_pick = OptionButton.new()
	_room_pick.focus_mode = Control.FOCUS_NONE
	_room_pick.add_theme_font_size_override("font_size", 10)
	for file in DirAccess.get_files_at("res://Rooms/"):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tscn") and not SKIP_ROOMS.has(file.get_basename().to_lower()):
			_rooms.append(file.get_basename())
	_rooms.sort_custom(func(a, b): return String(a).to_lower() < String(b).to_lower())
	for r in _rooms:
		_room_pick.add_item(String(r))
	box.add_child(_room_pick)
	_button(box, "Go to selected room", _go_room)

	_header(box, "STORY FLAGS")
	for f in FLAGS:
		var cb := CheckBox.new()
		cb.text = String(f)
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_font_size_override("font_size", 10)
		cb.toggled.connect(_toggle_flag.bind(String(f)))
		box.add_child(cb)
		_flag_boxes[f] = cb

	_header(box, "TOOLS")
	var reveal := _check(box, "Reveal the whole map", func(on: bool): Tablet.set_reveal_all(on))
	reveal.button_pressed = Tablet.reveal_all
	var hot := _check(box, "Show hotspot boxes", _set_boxes)
	hot.button_pressed = _boxes_on
	var trans := _check(box, "Room transitions (fade + steps)", func(on: bool): RoomManager.transitions = on)
	trans.button_pressed = RoomManager.transitions
	_button(box, "Complete all repairs", func(): Subsystems.debug_set_progress(5))
	_button(box, "Reset repairs", func(): Subsystems.debug_reset_all())
	_button(box, "Open tablet", _open_tablet)
	_button(box, "Test Mission Control message", func(): Mission.send_comms("Test message from Mission Control."))
	_button(box, "Test story message", func(): Story.say("Test message."))


func _hide() -> void:
	_panel.visible = false


func _open_tablet() -> void:
	_panel.visible = false
	Tablet.open_tablet()


func _header(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	parent.add_child(l)


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 10)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(parent: Node, text: String, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 10)
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _jump(stage_id: String) -> void:
	Mission.jump_to(stage_id)
	_refresh()


func _go_room() -> void:
	if _room_pick.selected < 0:
		return
	Overlay.close()
	RoomManager.go_to(String(_rooms[_room_pick.selected]))


func _toggle_flag(on: bool, flag_name: String) -> void:
	if on:
		Objectives.flag(flag_name)
	else:
		Objectives.clear_flag(flag_name)


func _refresh() -> void:
	if _panel == null or not _panel.visible:
		return
	_info.text = "Room: %s\nObjective: %s" % [RoomManager.current_id, Objectives.current()]
	for f in _flag_boxes:
		(_flag_boxes[f] as CheckBox).set_pressed_no_signal(Objectives.has_flag(String(f)))


func _set_boxes(on: bool) -> void:
	_boxes_on = on
	_apply_boxes(get_tree().root)


func _on_room_changed(_id: String) -> void:
	if _boxes_on:
		_apply_boxes.call_deferred(get_tree().root)
	_refresh()


func _apply_boxes(node: Node) -> void:
	if node is Hotspot:
		(node as Hotspot).show_in_game = _boxes_on
		node.queue_redraw()
	for c in node.get_children():
		_apply_boxes(c)
