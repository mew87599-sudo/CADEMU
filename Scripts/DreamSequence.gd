extends Node2D
## The dream sequence. A room scene: point the bed's Hotspot at it
## (Hotspot > Target Scene = Rooms/Dream.tscn) in the hall room (LivingModuleHallRoom).
##
##  1. black, a memory emerges (text, music goes muffled)
##  2. the forest behind a mesh fades in; text types in slowly and shakes
##  3. crossfade to the tree seen from the floor; it stays a few seconds, then is tinted red
##  4. on the fully red screen: "Now you remember." / "You hate earth"
##  5. "Don't bring me back" starts typing but is cut off as everything fades into RETURN_ROOM
##
## Everything is built in code; all the text and timing are the constants below.
## The Skip button leaves at once. With Subsystems.reduced_motion the text does not shake and the
## pictures do not drift.

const FOREST := preload("res://Assets/BackGrounds/dream_forest.jpg")
const TREE := preload("res://Assets/BackGrounds/dream_tree.jpg")
const HUM := preload("res://Assets/Misc/hum.wav")
const RETURN_ROOM := "livingmodulehallroom"

const SCREEN := Vector2(640, 360)
const RED := Color(0.62, 0.03, 0.03)

const LINE_1 := "Suddenly. A new memory emerges from long ago, long forgotten."
const LINE_2 := "Then, you try to remember what you did…"
const LINE_3 := "Now you remember."
const LINE_4 := "You hate earth"
const LINE_5 := "Don't bring me back"
const INTERRUPT_AT := 13        # characters of LINE_5 typed before it is cut off ("Don't bring m")

const TYPE_1 := 0.05            # seconds per typed character
const TYPE_2 := 0.075
const TYPE_3 := 0.09
const TYPE_4 := 0.1
const TYPE_5 := 0.16
const TREE_HOLD := 3.5          # seconds the tree stays untinted
const TINT_TIME := 5.0          # seconds to go fully red

var _timer: Timer
var _forest: Sprite2D
var _tree: Sprite2D
var _red: ColorRect
var _skip: Button
var _narr: Label
var _mem: Label
var _now: Label
var _hate: Label
var _last: Label
var _hum: AudioStreamPlayer

var _shake_label: Label
var _shake_base := Vector2.ZERO
var _shake_t := 0.0
var _finished := false
var _cover_color := Color.BLACK


func _ready() -> void:
	if not Objectives.has_flag("sleepy"):
		# Reached before the player is sleepy (a Hotspot without Required Flag): go straight back.
		Story.say("You are not tired.")
		RoomManager.go_to(RETURN_ROOM)
		return
	_build()
	_play()


# --- building -----------------------------------------------------------------------------

func _photo(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = SCREEN / 2.0
	var k: float = maxf(SCREEN.x / tex.get_width(), SCREEN.y / tex.get_height())
	s.scale = Vector2(k, k)
	s.modulate = Color(0.85, 0.85, 0.85, 0.0)
	add_child(s)
	return s


func _text(y: float, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = Vector2(40, y)
	l.size = Vector2(560, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.modulate.a = 0.0
	add_child(l)
	return l


func _build() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.size = SCREEN
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	_forest = _photo(FOREST)
	_tree = _photo(TREE)

	_red = ColorRect.new()
	_red.color = RED
	_red.size = SCREEN
	_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red.modulate.a = 0.0
	add_child(_red)

	_narr = _text(165.0, 15, Color(0.8, 0.8, 0.8))
	_mem = _text(262.0, 17, Color.WHITE)
	_now = _text(120.0, 22, Color.WHITE)
	_hate = _text(165.0, 22, Color.WHITE)
	_last = _text(235.0, 16, Color(1, 1, 1, 0.9))

	_skip = Button.new()
	_skip.text = "Skip >>"
	_skip.position = Vector2(572, 338)
	_skip.size = Vector2(62, 18)
	_skip.add_theme_font_size_override("font_size", 9)
	_skip.pressed.connect(_leave)
	add_child(_skip)

	_hum = AudioStreamPlayer.new()
	_hum.stream = HUM
	_hum.volume_db = -14.0
	add_child(_hum)


# --- helpers ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _shake_label != null and not Subsystems.reduced_motion:
		_shake_t -= delta
		if _shake_t <= 0.0:
			_shake_t = 0.035
			_shake_label.position = _shake_base + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5))


func _start_shake(l: Label) -> void:
	_shake_label = l
	_shake_base = l.position


func _stop_shake() -> void:
	if _shake_label != null:
		_shake_label.position = _shake_base
		_shake_label = null


func _wait(t: float) -> void:
	_timer.start(maxf(t, 0.01))
	await _timer.timeout


func _fade_to(node: CanvasItem, alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", alpha, t)
	await tw.finished


func _drift(s: Sprite2D) -> void:
	if Subsystems.reduced_motion:
		return
	var tw := create_tween()
	tw.tween_property(s, "scale", s.scale * 1.07, 16.0)


## Types `text` into the label, `chars` characters of it (-1 = all).
func _type(l: Label, text: String, per_char: float, chars := -1) -> void:
	var n: int = text.length() if chars < 0 else chars
	l.text = text
	l.visible_characters = 0
	l.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(l, "visible_characters", n, maxf(0.1, n * per_char))
	await tw.finished


# --- the sequence -------------------------------------------------------------------------

func _play() -> void:
	await _wait(1.0)
	Music.set_muffled(true, 2.0)

	# 1. a memory emerges
	await _type(_narr, LINE_1, TYPE_1)
	await _wait(2.2)
	await _fade_to(_narr, 0.0, 1.0)
	await _wait(0.6)

	# 2. the forest behind the mesh
	_drift(_forest)
	await _fade_to(_forest, 1.0, 2.5)
	await _wait(1.0)
	_start_shake(_mem)
	await _type(_mem, LINE_2, TYPE_2)
	await _wait(2.6)
	await _fade_to(_mem, 0.0, 0.8)
	_stop_shake()

	# 3. the tree from the floor, then red
	_drift(_tree)
	var cross := create_tween().set_parallel()
	cross.tween_property(_tree, "modulate:a", 1.0, 1.6)
	cross.tween_property(_forest, "modulate:a", 0.0, 1.6)
	await cross.finished
	await _wait(TREE_HOLD)
	_hum.play()
	var tint := create_tween()
	tint.tween_property(_red, "modulate:a", 1.0, TINT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tint.finished
	await _wait(1.0)

	# 4. now you remember
	await _type(_now, LINE_3, TYPE_3)
	await _wait(1.8)
	await _type(_hate, LINE_4, TYPE_4)
	await _wait(2.2)

	# 5. cut off before it finishes, fade into the room
	_last.text = LINE_5
	_last.visible_characters = 0
	_last.modulate.a = 1.0
	var typing := create_tween()
	typing.tween_property(_last, "visible_characters", INTERRUPT_AT, INTERRUPT_AT * TYPE_5)
	await _wait(INTERRUPT_AT * TYPE_5 - 0.4)
	var out := create_tween().set_parallel()
	out.tween_property(_now, "modulate:a", 0.0, 0.5)
	out.tween_property(_hate, "modulate:a", 0.0, 0.5)
	out.tween_property(_last, "modulate:a", 0.0, 0.5)
	await out.finished
	_cover_color = RED
	_leave()


# --- leaving --------------------------------------------------------------------------------

## Goes to RETURN_ROOM with a cover that fades out over the room (black when skipped).
func _leave() -> void:
	if _finished:
		return
	_finished = true
	Objectives.flag("dream_seen")
	Music.set_muffled(false, 1.5)

	var layer := CanvasLayer.new()
	layer.layer = 30
	var cover := ColorRect.new()
	cover.color = _cover_color
	cover.size = SCREEN
	layer.add_child(cover)
	get_tree().root.add_child(layer)

	var on_changed := func(_id: String) -> void:
		var tw := layer.create_tween()
		tw.tween_property(cover, "modulate:a", 0.0, 1.4)
		tw.tween_callback(layer.queue_free)
	RoomManager.room_changed.connect(on_changed, CONNECT_ONE_SHOT)
	RoomManager.go_to(RETURN_ROOM)
