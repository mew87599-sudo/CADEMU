extends Node2D
## First screen: terminal that prints PowerGrid's log, plus the desk hatch.

const MAX_LINES := 18


func _ready() -> void:
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Courier New", "Liberation Mono", "monospace"])
	$TerminalText.add_theme_font_override("font", mono)
	$Restart.pressed.connect(PowerGrid.reset)
	PowerGrid.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray()
	var start := maxi(0, PowerGrid.log_lines.size() - MAX_LINES)
	for i in range(start, PowerGrid.log_lines.size()):
		lines.append(PowerGrid.log_lines[i])
	lines.append("user-console:~$")
	$TerminalText.text = "\n".join(lines)
	$Restart.visible = PowerGrid.failed
