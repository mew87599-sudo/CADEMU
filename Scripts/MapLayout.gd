@tool
class_name MapLayout
extends Control
## The tablet map: one picture (child TextureRect "MapImage") with MapRoom zones on top.
## Layout space = the picture's pixels (set this node's size to the picture size). The tablet scales
## the whole layout to fit its map view, so any picture size works. Place zones in picture pixels.


func _ready() -> void:
	clip_contents = true


func find_room(id: String) -> MapRoom:
	for child in get_children():
		if child is MapRoom and child.has_room(id):
			return child
	return null
