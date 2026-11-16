extends LabMenu
## The sample storage compartment (fridge in the lab). Shelf of labeled containers: read the label,
## check the survey number in the database, look at the condition, open it, then take the right one
## (the latest survey, SRV-0412). Taking it sets the Objectives flag "samples_retrieved".
##
## Small inconsistencies are on purpose and never explained: one older container has a damaged
## label, and Sample 04 is registered twice in the database.

const CONTAINERS := [
	{
		"name": "Container 1",
		"label": "SRV-0398 / GEO-A",
		"survey": "SRV-0398 - returned 41 days ago",
		"cond": "Seal intact. A film of dust on the lid.",
		"contents": "3 specimens, archived.",
		"right": false,
	},
	{
		"name": "Container 2",
		"label": "SRV-04?? / ??O-B   [label torn, partly unreadable]",
		"survey": "SRV-0405 - returned 9 days ago",
		"cond": "Lid scratched. The label has peeled off at one corner.",
		"contents": "2 specimens, already analyzed.",
		"right": false,
	},
	{
		"name": "Container 3",
		"label": "SRV-0412 / GEO-A",
		"survey": "SRV-0412 - returned today (CDT-07). LATEST SURVEY.",
		"cond": "Seal intact. Still cold from the airlock.",
		"contents": "4 specimens: S01, S02, S03, S04.",
		"right": true,
	},
	{
		"name": "Container 4",
		"label": "SRV-0391 / GEO-C",
		"survey": "SRV-0391 - returned 60 days ago",
		"cond": "Seal intact.",
		"contents": "5 specimens, archived.",
		"right": false,
	},
]
const DB_ROWS := "S01   SRV-0412   CDT-07\nS02   SRV-0412   CDT-07\nS03   SRV-0412   CDT-07\nS04   SRV-0412   CDT-07\nS04   SRV-0412   CDT-07"

var _sel := -1
var _out: RichTextLabel
var _buttons: Array = []
var _actions: Array = []
var _status: Label


func _build() -> void:
	var panel := LabUI.panel(self, Vector2(60, 36), Vector2(520, 288))
	LabUI.label(panel, "SAMPLE STORAGE", Vector2(14, 8), Vector2(300, 18), 13)
	_status = LabUI.label(panel, "", Vector2(250, 10), Vector2(256, 14), 9, LabUI.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in CONTAINERS.size():
		var b := LabUI.button(panel, CONTAINERS[i].name, Vector2(14, 40 + i * 46), Vector2(130, 38), _select.bind(i), 11)
		_buttons.append(b)

	_out = LabUI.rich(panel, Vector2(158, 40), Vector2(348, 170), 10)
	_out.text = "[color=#8899aa]Select a container on the left.[/color]"

	var names := ["Read label", "Survey no.", "Condition", "Open"]
	for i in names.size():
		var b := LabUI.button(panel, names[i], Vector2(158 + i * 88, 218), Vector2(82, 24), _inspect.bind(i), 10)
		_actions.append(b)
	LabUI.button(panel, "Take container", Vector2(158, 250), Vector2(120, 26), _take, 11)
	LabUI.button(panel, "Close", Vector2(446, 250), Vector2(60, 26), _close, 10)
	_refresh()


func _refresh() -> void:
	var taken := Objectives.has_flag("samples_retrieved")
	_status.text = "Latest survey: SRV-0412" if not taken else "Container SRV-0412 retrieved"
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.text = CONTAINERS[i].name
		if taken and CONTAINERS[i].right:
			b.text = "Container 3 (empty)"
		b.disabled = false
	for b in _actions:
		(b as Button).disabled = _sel < 0


func _select(i: int) -> void:
	_sel = i
	var c: Dictionary = CONTAINERS[i]
	var empty: bool = Objectives.has_flag("samples_retrieved") and c.right
	_out.text = "[b]%s[/b]\n%s" % [c.name, "[color=#8899aa]The compartment is empty.[/color]" if empty else "[color=#8899aa]Use the buttons below to inspect it.[/color]"]
	_refresh()


func _inspect(which: int) -> void:
	if _sel < 0:
		return
	var c: Dictionary = CONTAINERS[_sel]
	match which:
		0:
			_out.text = "[b]%s - label[/b]\n%s" % [c.name, c.label]
		1:
			var text: String = "[b]%s - database[/b]\nSurvey: %s" % [c.name, c.survey]
			if c.right:
				text += "\n\n[color=#8899aa]REGISTERED SPECIMENS[/color]\n" + DB_ROWS
			_out.text = text
		2:
			_out.text = "[b]%s - condition[/b]\n%s" % [c.name, c.cond]
		3:
			var shown: String = c.contents
			if Objectives.has_flag("samples_retrieved") and c.right:
				shown = "Empty."
			_out.text = "[b]%s - opened[/b]\n%s" % [c.name, shown]


func _take() -> void:
	if _sel < 0:
		Story.say("Select a container first.")
		return
	var c: Dictionary = CONTAINERS[_sel]
	if Objectives.has_flag("samples_retrieved"):
		Story.say("You already have the samples.")
		return
	if not c.right:
		_out.text = "[color=#ff9966]This is not from the latest survey (SRV-0412).[/color]"
		return
	Objectives.flag("samples_retrieved")
	Story.say("Container SRV-0412 retrieved.")
	Overlay.close()
