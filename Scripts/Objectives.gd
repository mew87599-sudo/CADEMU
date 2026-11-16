extends Node
## Autoload. The objective list shown on the tablet: a scripted sequence plus the subsystem repairs.
##
## STORY is an ordered list. Step N is only shown once step N-1 is done, so the player never
## sees later objectives early. A step is done when its flag has been set with Objectives.flag().
## Once every STORY step is done, one "Repair ..." objective per subsystem appears (live from
## Subsystems), then "Outpost powered".
##
## To add a story step: add an entry to STORY and call Objectives.flag("your_flag") from
## wherever the event happens (a menu opening, a command running, a room being entered...).
##
## Flags currently set by the game:
##   console_opened   TerminalMenu opens
##   status_report    the player runs `systemscfg /statusreport`
##   sleepy           set by Story when every subsystem is repaired (the player should go to bed)
##   dream_seen       the dream sequence ended
##   (post-dream flags: see Mission.gd and the POST list below)

signal changed

const STORY := [
	{"text": "Reach the command center and check the console", "flag": "console_opened"},
	{"text": "Run the status report: systemscfg /statusreport", "flag": "status_report"},
]

## The sequence after the dream (see Mission.gd). Same rules as STORY; "needs" is a flag that must be
## set before the step shows up at all.
const POST := [
	{"text": "Retrieve the geological samples", "flag": "samples_retrieved", "needs": "mc_briefing"},
	{"text": "Transport the samples to the laboratory", "flag": "samples_delivered"},
	{"text": "Prepare the samples for microscopic examination", "flag": "samples_prepared"},
	{"text": "Examine and document all four samples", "flag": "samples_examined"},
	{"text": "Submit the analysis report to Mission Control", "flag": "report_submitted"},
	{"text": "Repeat the examination of Sample 04", "flag": "sample4_rechecked", "needs": "recheck_requested"},
	{"text": "Upload the second result", "flag": "second_uploaded"},
]

var flags := {}


func _ready() -> void:
	Subsystems.status_changed.connect(func(_id: String): changed.emit())


func flag(key: String) -> void:
	if flags.get(key, false):
		return
	flags[key] = true
	changed.emit()


func clear_flag(key: String) -> void:
	if flags.erase(key):
		changed.emit()


func has_flag(key: String) -> bool:
	return flags.get(key, false)


## Visible objectives, in order: [{"text": String, "done": bool}, ...]
func entries() -> Array:
	var out: Array = []
	var story_done := true
	for step in STORY:
		var done: bool = has_flag(step.flag)
		out.append({"text": step.text, "done": done})
		if not done:
			story_done = false
			break
	if story_done:
		for r in Subsystems.rows():
			out.append({"text": "Repair %s (%s)" % [r[0], r[1]], "done": r[2] == "ONLINE"})
		if Subsystems.powered:
			out.append({"text": "Outpost powered", "done": true})
		if has_flag("sleepy") or has_flag("dream_seen"):
			out.append({"text": "Go to sleep in your room", "done": has_flag("dream_seen")})
		if has_flag("dream_seen"):
			for step in POST:
				if step.has("needs") and not has_flag(step.needs):
					break
				var done: bool = has_flag(step.flag)
				out.append({"text": step.text, "done": done})
				if not done:
					break
			if has_flag("second_uploaded"):
				out.append({"text": "Sample analysis complete", "done": true})
	return out


## Text of the first unfinished objective.
func current() -> String:
	for e in entries():
		if not e.done:
			return e.text
	return "All objectives complete"


func debug_unlock_all_steps() -> void:
	for step in STORY:
		flag(step.flag)
