extends Node
## Autoload. Plays the looping background track on its own "Music" bus, so it keeps playing
## across room changes. A steep low-pass filter on that bus gives the "muffled" sound.
## Swap the track by replacing Assets/Misc/ambient_placeholder.wav or changing TRACK.
## The game starts MUFFLED (so nothing clear leaks before the title screen loads);
## call set_muffled(false) to open it up.

const TRACK := "res://Assets/Misc/ambient_placeholder.wav"
const MUFFLED_HZ := 280.0   # lower = more muffled
const CLEAR_HZ := 20500.0
const MUFFLED_DB := -8.0

var _player: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter
var _tween: Tween


func _ready() -> void:
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "Music")
	_filter = AudioEffectLowPassFilter.new()
	_filter.db = AudioEffectFilter.FILTER_24DB  # steep: 6 dB/oct is barely audible on most music
	_filter.resonance = 0.5
	_filter.cutoff_hz = MUFFLED_HZ
	AudioServer.add_bus_effect(idx, _filter)

	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	_player.volume_db = MUFFLED_DB
	if ResourceLoader.exists(TRACK):
		_player.stream = load(TRACK)
	_player.finished.connect(_player.play)  # loop
	add_child(_player)
	_player.play()


## fade = 0 jumps instantly, otherwise eases over `fade` seconds.
## The cutoff moves in log-frequency, so the change is spread evenly over the whole fade
## (a linear Hz fade would be over in the first few frames).
func set_muffled(on: bool, fade := 0.0) -> void:
	var hz := MUFFLED_HZ if on else CLEAR_HZ
	var db := MUFFLED_DB if on else 0.0
	if _tween:
		_tween.kill()
	if fade <= 0.0:
		_filter.cutoff_hz = hz
		_player.volume_db = db
		return
	var from_hz := _filter.cutoff_hz
	var from_db := _player.volume_db
	_tween = create_tween().set_parallel()
	_tween.tween_method(func(t: float):
		_filter.cutoff_hz = exp(lerpf(log(from_hz), log(hz), t))
		_player.volume_db = lerpf(from_db, db, t), 0.0, 1.0, fade)
