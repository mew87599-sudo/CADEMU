extends Node2D
## Starting sequence, played after the CADEMU title screen (TitleScreen.NEXT_ROOM = "intro").
##
##  1. black, "A memory grasps into your head..." (music goes muffled)
##  2. flash -> classroom photo, the instructor ("????") starts talking, sudden cut
##  3. photo of the test + a 3-option question (mouse). A and B are refused, C is the memory
##  4. green flash, instructor's lecture over the classroom photo
##  5. flicker, the photo dissolves into static
##  6. static resolves into the helmet cam, Mission Control voice, nod, HUD boots, objective
##  7. fade to black, then the base-from-outside room (NEXT_ROOM) fades in
##
## Everything is built in code. All text is in the constants and in _play(). Click while text is
## typing to finish the line; the Skip button jumps to NEXT_ROOM.

const CLASSROOM := preload("res://Assets/BackGrounds/intro_classroom.png")
const TEST := preload("res://Assets/BackGrounds/intro_test.png")
const BEEP := preload("res://Assets/Misc/beep.wav")
const STATIC_SND := preload("res://Assets/Misc/static.wav")
const NEXT_ROOM := "basefrontoutside"

const SCREEN := Vector2(640, 360)
const NOISE_SIZE := Vector2i(160, 90)
const NOISE_FRAMES := 6
const CHAR_TIME := 0.028   # seconds per typed character

const GREY := Color(0.8, 0.8, 0.8)
const INSTRUCTOR := Color(1.0, 0.5, 0.45)
const CONTROL_COLOR := Color(1.0, 0.8, 0.3)
const HUD_COLOR := Color(0.5, 1.0, 0.7)

const QUESTION := "If you are on a walk on the ground and a dust storm starts to stir, what do you do?"
const OPTIONS := {
	"A": "A) Seek shelter",
	"B": "B) Send an analysis of the storm",
	"C": "C) Continue your EVA and collect your samples",
}
const HUD_LINES := [
	"SUIT STATUS .... NOMINAL",
	"O2 ............. 100 %",
	"BATTERY ......... 97 %",
	"SUIT PRESS .. 29.6 kPa",
	"EXT TEMP ...... -153 C",
	"COMMS ......... LINK OK",
]
const OBJECTIVE := "[OBJECTIVE: PROCEED TO CHECK AND REPAIR ALL SUBSYSTEMS]"

signal chosen

var _timer: Timer
var _photo: Sprite2D
var _helmet: HelmetView
var _vignette: TextureRect
var _hud: Control
var _hud_lines: Array = []
var _objective: Label
var _rec: Label
var _noise: TextureRect
var _narr: Label
var _box: ColorRect
var _speaker: Label
var _line: Label
var _quiz: Panel
var _quiz_msg: Label
var _btn_c: Button
var _flash: ColorRect
var _fade: ColorRect
var _beep: AudioStreamPlayer
var _static: AudioStreamPlayer

var _type_tween: Tween
var _noise_pool: Array = []   # prebuilt noise textures, cycled (cheaper than one per frame)
var _noise_t := 0.0
var _rec_t := 0.0
var _finished := false


func _ready() -> void:
	_build()
	_play()


# --- building the scene --------------------------------------------------------------

func _rect(color: Color, pos := Vector2.ZERO, sz := SCREEN) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _label(text: String, pos: Vector2, sz: Vector2, font_size := 12, color := Color.WHITE,
		font: Font = null, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	(parent if parent else self).add_child(l)
	return l


func _build() -> void:
	var mono := MonoFont.get_font()

	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)

	_rect(Color.BLACK)

	_photo = Sprite2D.new()
	_photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_photo.position = SCREEN / 2.0
	_photo.visible = false
	add_child(_photo)

	_helmet = HelmetView.new()
	_helmet.size = SCREEN
	_helmet.visible = false
	add_child(_helmet)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.9)])
	var vig := GradientTexture2D.new()
	vig.gradient = gradient
	vig.width = 256
	vig.height = 144
	vig.fill = GradientTexture2D.FILL_RADIAL
	vig.fill_from = Vector2(0.5, 0.5)
	vig.fill_to = Vector2(1.0, 0.5)
	_vignette = TextureRect.new()
	_vignette.texture = vig
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.size = SCREEN
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	add_child(_vignette)

	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	add_child(_hud)
	for i in HUD_LINES.size():
		var l := _label(HUD_LINES[i], Vector2(24, 24 + i * 13), Vector2(220, 14), 9, HUD_COLOR, mono, _hud)
		l.visible = false
		_hud_lines.append(l)
	_objective = _label(OBJECTIVE, Vector2(0, 318), Vector2(640, 18), 10, CONTROL_COLOR, mono, _hud)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.visible = false
	_rec = _label("[REC] CAM-02  00:00:00", Vector2(430, 22), Vector2(190, 14), 9, Color(1.0, 0.45, 0.4), mono)
	_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rec.visible = false

	_noise = TextureRect.new()
	_noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_noise.stretch_mode = TextureRect.STRETCH_SCALE
	_noise.size = SCREEN
	_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise.modulate = Color(0.75, 0.75, 0.75, 0.0)
	_noise.visible = false
	add_child(_noise)
	_make_noise_pool()

	_narr = _label("", Vector2(0, 160), Vector2(640, 40), 15, GREY)
	_narr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narr.modulate.a = 0.0

	_box = _rect(Color(0, 0, 0, 0.72), Vector2(30, 278), Vector2(580, 72))
	_box.visible = false
	_speaker = _label("", Vector2(10, 4), Vector2(560, 16), 11, Color.WHITE, null, _box)
	_line = _label("", Vector2(10, 22), Vector2(560, 46), 12, Color.WHITE, null, _box)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_quiz()

	_flash = _rect(Color.WHITE)
	_flash.modulate.a = 0.0
	_fade = _rect(Color.BLACK)
	_fade.modulate.a = 0.0

	var skip := Button.new()
	skip.text = "Skip >>"
	skip.position = Vector2(572, 338)
	skip.size = Vector2(62, 18)
	skip.add_theme_font_size_override("font_size", 9)
	skip.pressed.connect(_leave)
	add_child(skip)

	_beep = AudioStreamPlayer.new()
	_beep.stream = BEEP
	_beep.volume_db = -8.0
	add_child(_beep)
	_static = AudioStreamPlayer.new()
	_static.stream = STATIC_SND
	_static.volume_db = -14.0
	_static.finished.connect(_static.play)  # loop
	add_child(_static)


func _build_quiz() -> void:
	_quiz = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.94)
	style.border_color = Color(0.75, 0.75, 0.78)
	style.set_border_width_all(1)
	_quiz.add_theme_stylebox_override("panel", style)
	_quiz.position = Vector2(332, 36)
	_quiz.size = Vector2(292, 280)
	_quiz.visible = false
	add_child(_quiz)

	var box := VBoxContainer.new()
	box.position = Vector2(10, 10)
	box.size = Vector2(272, 260)
	box.add_theme_constant_override("separation", 8)
	_quiz.add_child(box)

	var q := Label.new()
	q.text = QUESTION
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(272, 62)
	q.add_theme_font_size_override("font_size", 12)
	box.add_child(q)

	for key in OPTIONS:
		var b := Button.new()
		b.text = OPTIONS[key]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(272, 38)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_on_option.bind(key))
		box.add_child(b)
		if key == "C":
			_btn_c = b

	_quiz_msg = Label.new()
	_quiz_msg.add_theme_font_size_override("font_size", 10)
	_quiz_msg.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_quiz_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quiz_msg.custom_minimum_size = Vector2(272, 30)
	box.add_child(_quiz_msg)


func _make_noise_pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for f in NOISE_FRAMES:
		var bytes := PackedByteArray()
		bytes.resize(NOISE_SIZE.x * NOISE_SIZE.y)
		for i in bytes.size():
			bytes[i] = rng.randi() & 255
		var img := Image.create_from_data(NOISE_SIZE.x, NOISE_SIZE.y, false, Image.FORMAT_L8, bytes)
		_noise_pool.append(ImageTexture.create_from_image(img))


# --- per-frame effects -----------------------------------------------------------------

func _process(delta: float) -> void:
	if _noise.visible:
		_noise_t += delta
		if _noise_t >= 0.05:
			_noise_t = 0.0
			_noise.texture = _noise_pool[randi() % _noise_pool.size()]
	if _rec.visible:
		_rec_t += delta
		var s := int(_rec_t)
		_rec.text = "[REC] CAM-02  %02d:%02d:%02d" % [int(s / 3600.0), int((s % 3600) / 60.0), s % 60]


func _unhandled_input(event: InputEvent) -> void:
	# Click while text is typing -> finish the line at once.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _type_tween and _type_tween.is_running():
			_type_tween.custom_step(100.0)


# --- small helpers ---------------------------------------------------------------------

func _wait(t: float) -> void:
	_timer.start(maxf(t, 0.01))
	await _timer.timeout


func _fade_to(node: CanvasItem, alpha: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(node, "modulate:a", alpha, t)
	await tw.finished


func _set_noise(alpha: float) -> void:
	_noise.modulate.a = alpha
	_noise.visible = alpha > 0.0


func _show_photo(tex: Texture2D, center_x := 320.0, height := 360.0) -> void:
	_photo.texture = tex
	var s := height / float(tex.get_height())
	_photo.scale = Vector2(s, s)
	_photo.position = Vector2(center_x, 180.0)
	_photo.modulate = Color(0.85, 0.85, 0.85, 1.0)
	_photo.visible = true


func _flash_on(color: Color, peak: float, t: float) -> void:
	_flash.color = color
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", peak, t)
	await tw.finished


func _flash_off(t: float) -> void:
	await _fade_to(_flash, 0.0, t)


## Subtitle box with typewriter text. `speaker` may be "". With `cut` the box vanishes the instant
## the text has finished typing (a sudden cut), with no pause or fade.
func _say(speaker: String, text: String, color: Color, cut := false) -> void:
	_speaker.text = (speaker + ":") if speaker != "" else ""
	_speaker.add_theme_color_override("font_color", color)
	_line.text = text
	_line.visible_ratio = 0.0
	_box.modulate.a = 0.0
	_box.visible = true
	await _fade_to(_box, 1.0, 0.2)
	_type_tween = create_tween()
	_type_tween.tween_property(_line, "visible_ratio", 1.0, maxf(0.4, text.length() * CHAR_TIME))
	await _type_tween.finished
	if cut:
		_box.visible = false
		return
	await _wait(1.0 + text.length() * 0.012)
	await _fade_to(_box, 0.0, 0.25)
	_box.visible = false


func _narrate(text: String, hold: float) -> void:
	_narr.text = text
	await _fade_to(_narr, 1.0, 1.0)
	await _wait(hold)
	await _fade_to(_narr, 0.0, 0.8)


# --- the sequence ------------------------------------------------------------------------

func _play() -> void:
	await _wait(0.8)

	# 1. memory
	Music.set_muffled(true, 2.0)
	await _narrate("A memory grasps into your head…", 2.0)
	await _wait(0.4)

	# 2. flash into the classroom, instructor, sudden cut
	await _flash_on(Color.WHITE, 1.0, 0.6)
	_show_photo(CLASSROOM)
	_vignette.modulate.a = 0.6
	_vignette.visible = true
	var zoom := create_tween()
	zoom.tween_property(_photo, "scale", _photo.scale * 1.06, 8.0)
	await _flash_off(0.9)
	await _wait(0.5)
	await _say("????", "Cadets! Always remember that space ain't no colors and sunshine. You will always-", INSTRUCTOR, true)
	zoom.kill()
	_photo.visible = false
	_vignette.visible = false
	await _wait(1.0)

	# 3. the test
	_show_photo(TEST, 170.0, 340.0)
	_photo.modulate.a = 0.0
	await _fade_to(_photo, 1.0, 0.5)
	await _wait(0.6)
	_quiz.modulate.a = 0.0
	_quiz.visible = true
	await _fade_to(_quiz, 1.0, 0.5)
	await chosen

	# 4. green flash, the instructor's lecture
	await _flash_on(Color(0.2, 1.0, 0.35), 0.8, 0.08)
	_quiz.visible = false
	_show_photo(CLASSROOM)
	_vignette.modulate.a = 0.6
	_vignette.visible = true
	await _flash_off(0.7)
	await _wait(0.5)
	await _say("INSTRUCTOR", "Wrong. Cadet, you just exposed yourself and your team to a complete loss of comms, vision, and suit integrity.", INSTRUCTOR)
	await _say("INSTRUCTOR", "A lunar dust storm isn't a nuisance; it's a sandblaster. It's electrostatic. It will cling to your suit, your visor, your lungs.", INSTRUCTOR)
	await _say("INSTRUCTOR", "You don't 'collect samples.' You get inside. That mistake just cost the mission.", INSTRUCTOR)

	# 5. flicker, dissolve into static
	_static.volume_db = -14.0
	_static.play()
	for i in 7:
		_photo.visible = not _photo.visible
		_set_noise(randf_range(0.2, 0.6) if i % 2 == 0 else 0.0)
		await _wait(randf_range(0.04, 0.12))
	_photo.visible = true
	var melt := create_tween().set_parallel()
	_noise.visible = true
	melt.tween_property(_noise, "modulate:a", 1.0, 1.0)
	melt.tween_property(_photo, "modulate:a", 0.0, 1.0)
	await melt.finished
	_photo.visible = false
	_vignette.visible = false
	await _wait(1.3)

	# 6. static resolves into the helmet cam
	_helmet.position = Vector2.ZERO
	_helmet.visible = true
	_vignette.modulate.a = 1.0
	_vignette.visible = true
	_rec_t = 0.0
	_rec.visible = true
	Music.set_muffled(false, 2.5)
	var clear := create_tween().set_parallel()
	clear.tween_property(_noise, "modulate:a", 0.0, 1.2)
	clear.tween_property(_static, "volume_db", -60.0, 1.2)
	await clear.finished
	_static.stop()
	_set_noise(0.0)
	await _wait(2.0)  # silent view, the HUD is still off

	await _say("MISSION CONTROL (V.O.)", "CADEMU Base, this is Mission Control. The main console isn't responding, you need to check the console and proceed with the required repairs.", CONTROL_COLOR)
	await _nod()
	await _say("MISSION CONTROL (V.O.)", "...Welcome to the Moon. Let's not repeat old mistakes.", CONTROL_COLOR)

	await _boot_hud()
	await _wait(3.5)

	# 7. fade to black, then the base
	await _fade_to(_fade, 1.0, 1.5)
	await _wait(0.4)
	_leave()


func _nod() -> void:
	var tw := create_tween()
	tw.tween_property(_helmet, "position:y", 9.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_helmet, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await _wait(0.4)


func _boot_hud() -> void:
	_hud.visible = true
	for l in _hud_lines:
		l.visible = true
		_beep.pitch_scale = 1.0
		_beep.play()
		await _wait(0.4)
	await _wait(0.5)
	_objective.visible = true
	_beep.pitch_scale = 1.4
	_beep.play()
	for i in 3:
		_objective.modulate.a = 0.2
		await _wait(0.12)
		_objective.modulate.a = 1.0
		await _wait(0.12)


# --- quiz --------------------------------------------------------------------------------

func _on_option(key: String) -> void:
	if key == "C":
		_btn_c.modulate = Color(0.4, 1.0, 0.5)
		for b in _btn_c.get_parent().get_children():
			if b is Button:
				b.disabled = true
		chosen.emit()
		return
	# The memory can't be changed: A and B are refused.
	_quiz_msg.text = "...that is not what you answered."
	var tw := create_tween()
	tw.tween_property(_quiz, "position:x", 328.0, 0.04)
	tw.tween_property(_quiz, "position:x", 336.0, 0.06)
	tw.tween_property(_quiz, "position:x", 332.0, 0.04)


# --- leaving -----------------------------------------------------------------------------

## Goes to NEXT_ROOM with a black cover that fades out over the new room.
func _leave() -> void:
	if _finished:
		return
	_finished = true
	_static.stop()
	Music.set_muffled(false, 1.0)

	var layer := CanvasLayer.new()
	layer.layer = 30
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.size = SCREEN
	layer.add_child(cover)
	get_tree().root.add_child(layer)

	var on_changed := func(_id: String) -> void:
		var tw := layer.create_tween()
		tw.tween_property(cover, "modulate:a", 0.0, 1.2)
		tw.tween_callback(layer.queue_free)
	RoomManager.room_changed.connect(on_changed, CONNECT_ONE_SHOT)
	RoomManager.go_to(NEXT_ROOM)
