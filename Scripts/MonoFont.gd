class_name MonoFont
extends RefCounted
## The monospace font of the terminal and the helmet HUD.
## Desktop: the system's own (Consolas, Courier New, ...). Web: browsers expose no system fonts, so
## the bundled DejaVu Sans Mono is used (the terminal's column alignment needs a monospace font).
## Set ALWAYS_BUNDLED = true to use the bundled font everywhere (identical look on every platform).

const BUNDLED := "res://Assets/Fonts/DejaVuSansMono.ttf"
const ALWAYS_BUNDLED := false

static var _font: Font


static func get_font() -> Font:
	if _font != null:
		return _font
	if (ALWAYS_BUNDLED or OS.has_feature("web")) and ResourceLoader.exists(BUNDLED):
		_font = load(BUNDLED)
	else:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Consolas", "Courier New", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
		_font = sys
	return _font
