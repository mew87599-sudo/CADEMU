extends Node2D
## Starting screen.
##   WAITING : black background, dim logo, muffled music. Waits for Enter (or a left click).
##   FLASHING: instant white flash; under it the logo swaps to the colour one, the starfield
##             appears (starting as a fast warp burst that settles) and the music un-muffles.
##   READY   : stays on the starfield. Enter / click again goes to NEXT_ROOM.

const DIM := preload("res://Assets/Menus/logo_dim.png")
const COLOR := preload("res://Assets/Menus/logo.png")
const NEXT_ROOM := "intro"

const FLASH_FADE := 0.45     # seconds for the white to fade out
const WARP_SPEED := 1800.0   # starfield speed at the flash
const CRUISE_SPEED := 90.0   # starfield speed it settles to
const WARP_SETTLE := 3.0     # seconds to settle
const MUSIC_FADE := 2.0      # seconds for the music to clear up

enum State { WAITING, FLASHING, READY }
var state := State.WAITING

@onready var logo: Sprite2D = $Logo
@onready var stars: Starfield = $Starfield
@onready var flash: ColorRect = $Flash
@onready var prompt: Label = $Prompt


func _ready() -> void:
	logo.texture = DIM
	stars.visible = false
	flash.modulate.a = 0.0
	Music.set_muffled(true)
	var blink := create_tween().set_loops()
	blink.tween_property(prompt, "modulate:a", 0.25, 0.9)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.9)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("ui_accept") and not event.is_echo()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	match state:
		State.WAITING:
			_start_transition()
		State.READY:
			RoomManager.go_to(NEXT_ROOM)


func _start_transition() -> void:
	state = State.FLASHING
	prompt.visible = false
	# Everything below happens under the full-white frame.
	flash.modulate.a = 1.0
	logo.texture = COLOR
	stars.visible = true
	stars.speed = WARP_SPEED
	Music.set_muffled(false, MUSIC_FADE)

	var tw := create_tween().set_parallel()
	tw.tween_property(flash, "modulate:a", 0.0, FLASH_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(stars, "speed", CRUISE_SPEED, WARP_SETTLE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw.finished
	state = State.READY
	prompt.text = "Press Enter"
	prompt.visible = true
