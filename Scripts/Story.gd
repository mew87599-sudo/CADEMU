extends CanvasLayer
## Autoload. Story events and the on-screen message line.
##
##   Story.say("text")        shows a short message near the bottom of the screen (fades in/out)
##   Story.start_sleepy()     the "you are sleepy" event (normally started by itself, see below)
##   Story.dream_finished     emitted when the player is back in the hall room after the dream
##                            (hook for the next sequence)
##
## The sleepy event: when the last subsystem is repaired (Subsystems.outpost_powered) and its menu
## has closed, "You are sleepy. Go to sleep." is shown, the Objectives flag "sleepy" is set, and a
## yellow dot appears on the tablet map on the player's room (SLEEP_ROOM). The bed Hotspot in
## that room has Required Flag = "sleepy", so the dream can only be started from then on.
## After the dream (Objectives flag "dream_seen") the dot goes away and the flag is cleared again.

signal dream_finished

const SLEEP_ROOM := "livingmodulehallroom"
const SLEEPY_TEXT := "You are sleepy. Go to sleep."
const MARKER_COLOR := Color(1.0, 0.85, 0.2)
const DELAY_AFTER_MENU := 0.8   # seconds between the repair menu closing and the message
const MSG_FADE_IN := 0.5
const MSG_HOLD := 3.5
const MSG_FADE_OUT := 0.8

var _box: ColorRect
var _label: Label
var _tween: Tween
var _dream_handled := false
var _dream_done := false


func _ready() -> void:
	layer = 22   # above rooms and menus, below the room transition cover (25)
	_box = ColorRect.new()
	_box.color = Color(0, 0, 0, 0.72)
	_box.position = Vector2(100, 276)
	_box.size = Vector2(440, 44)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	_label = Label.new()
	_label.size = _box.size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 14)
	_box.add_child(_label)

	Subsystems.outpost_powered.connect(_on_powered)
	Objectives.changed.connect(_on_objectives_changed)
	RoomManager.room_changed.connect(_on_room_changed)


func say(text: String) -> void:
	_label.text = text
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_box, "modulate:a", 1.0, MSG_FADE_IN)
	_tween.tween_interval(MSG_HOLD)
	_tween.tween_property(_box, "modulate:a", 0.0, MSG_FADE_OUT)


func start_sleepy() -> void:
	if Objectives.has_flag("sleepy") or Objectives.has_flag("dream_seen"):
		return
	Objectives.flag("sleepy")
	Tablet.set_marker(SLEEP_ROOM, MARKER_COLOR)
	say(SLEEPY_TEXT)


## Debug: forget the sleepy / dream progress (terminal command `debug_story_reset`).
func reset() -> void:
	Objectives.flags.erase("sleepy")
	Objectives.flags.erase("dream_seen")
	Tablet.clear_marker(SLEEP_ROOM)
	_dream_handled = false
	_dream_done = false
	Objectives.changed.emit()


func _on_powered() -> void:
	if Objectives.has_flag("sleepy") or Objectives.has_flag("dream_seen"):
		return
	if Overlay.is_open():
		await Overlay.closed
	await get_tree().create_timer(DELAY_AFTER_MENU).timeout
	start_sleepy()


func _on_objectives_changed() -> void:
	if Objectives.has_flag("dream_seen") and not _dream_handled:
		_dream_handled = true
		Tablet.clear_marker(SLEEP_ROOM)
		Objectives.clear_flag("sleepy")   # the bed is locked again


func _on_room_changed(id: String) -> void:
	if _dream_handled and not _dream_done and MapRoom.norm_id(id) == SLEEP_ROOM:
		_dream_done = true
		dream_finished.emit()
