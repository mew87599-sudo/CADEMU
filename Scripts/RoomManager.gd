extends Node
## Autoload. Swaps whole room *scenes* inside the Main scene's RoomHost.
##
## go_to("name") finds the room in this order:
##   1. the ROOMS table below (optional, for short ids or rooms outside res://Rooms/)
##   2. a scene in res://Rooms/ whose file name matches, ignoring upper/lower case
##      ("commandcenter" finds Rooms/commandcenter.tscn, "livingmodule" finds LivingModule.tscn)
##   3. a full path such as "res://Rooms/Sub/Thing.tscn"
## So a new room scene saved in Rooms/ works right away, no code edit needed.
## go_to_scene(packed_scene) is what a Hotspot's "Target Scene" slot uses.

signal room_changed(id: String)

## Quick room-to-room transition: fade to black, swap the room, play the footsteps sound while it
## is black, fade back in. It is skipped when leaving or entering one of NO_TRANSITION (those
## screens have their own fades) and when `transitions` is false.
const STEPS := "res://Assets/Misc/steps.wav"
const NO_TRANSITION := ["login", "title", "intro", "dream"]
const FADE_OUT := 0.15
const HOLD := 0.75      # seconds it stays black after the swap (the steps play meanwhile)
const FADE_IN := 0.35

const ROOMS_DIR := "res://Rooms/"
const ROOMS := {
	"title": "res://Rooms/Title.tscn",
	"hall": "res://Rooms/Hall.tscn",
	"lab": "res://Rooms/TurtleLab.tscn",
	"console": "res://Rooms/Console.tscn",
	"wiring": "res://Rooms/Wiring.tscn",
	"basefrontoutside": "res://Rooms/BaseFrontOutside.tscn",
	"livingmodule": "res://Rooms/LivingModule.tscn",
	"livingmodulehall": "res://Rooms/LivingModuleHall.tscn",
	"livingmodulehallroom": "res://Rooms/LivingModuleHallRoom.tscn",
	"biomodule": "res://Rooms/BioModule.tscn",
	"hatch": "res://Rooms/Hatch.tscn",
}

var current_id := ""
var _host: Node
var _current: Node

var transitions := true
var _busy := false
var _cover: ColorRect
var _sfx: AudioStreamPlayer


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25   # above rooms (0), BackArrow (10), Overlay (20)
	add_child(layer)
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.size = Vector2(640, 360)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.modulate.a = 0.0
	layer.add_child(_cover)
	_sfx = AudioStreamPlayer.new()
	if ResourceLoader.exists(STEPS):
		_sfx.stream = load(STEPS)
	_sfx.volume_db = -2.0
	add_child(_sfx)


func register_host(host: Node) -> void:
	_host = host


func go_to(id: String) -> void:
	var path := _resolve(id)
	if path == "":
		push_error("RoomManager: no room named '%s'. Save a scene with that name in res://Rooms/ "
			% id + "or add it to ROOMS.")
		return
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("RoomManager: could not load '%s'" % path)
		return
	# Deferred: the click that triggered this is still being processed.
	_request.call_deferred(scene, id)


func go_to_scene(scene: PackedScene) -> void:
	if scene == null:
		push_error("RoomManager: go_to_scene got no scene")
		return
	_request.call_deferred(scene, scene.resource_path.get_file().get_basename().to_lower())


func _resolve(id: String) -> String:
	if ROOMS.has(id):
		return ROOMS[id]
	if id.begins_with("res://"):
		return id if ResourceLoader.exists(id) else ""
	for file in DirAccess.get_files_at(ROOMS_DIR):
		file = file.trim_suffix(".remap")  # exported builds list scenes as *.tscn.remap
		if file.ends_with(".tscn") and file.get_basename().to_lower() == id.to_lower():
			return ROOMS_DIR + file
	return ""


func _is_special(id: String) -> bool:
	return NO_TRANSITION.has(id.get_file().get_basename().to_lower())


func _request(scene: PackedScene, id: String) -> void:
	if _busy:
		return   # a transition is already running; ignore extra clicks
	if not transitions or _current == null or _is_special(current_id) or _is_special(id):
		_swap(scene, id)
		return
	_busy = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks while it runs
	var out := create_tween()
	out.tween_property(_cover, "modulate:a", 1.0, FADE_OUT)
	await out.finished
	_swap(scene, id)
	if _sfx.stream != null:
		_sfx.play()
	await get_tree().create_timer(HOLD).timeout
	var back := create_tween()
	back.tween_property(_cover, "modulate:a", 0.0, FADE_IN)
	await back.finished
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _swap(scene: PackedScene, id: String) -> void:
	if _current:
		_current.queue_free()
		_current = null
	_current = scene.instantiate()
	_host.add_child(_current)
	current_id = id
	room_changed.emit(id)
