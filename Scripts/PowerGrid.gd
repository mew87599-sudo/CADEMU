extends Node
## Autoload. State and rules of the console soldering puzzle. It survives room changes, so the
## console and wiring rooms just read it and call the action functions below.
## Every action returns a short message for the player. See Architecture.md "Soldering puzzle".

signal changed

const WRAPS_NEEDED := 6        # Western Union splice: 3 wraps per side, alternating
const HEAT_SECONDS := 3.0      # how long a heated joint stays hot
const MIN_SOLDER_HEAT := 0.2   # tin only flows above this heat (0..1)

## Watts each source supplies.
const SOURCES := {"V55": 55, "V67": 67, "V22": 22, "V86": 86, "V65": 65}
## Watts each device needs to run.
const DEVICES := {"monitorlegacy01": 85, "oxygenmonitor": 60, "comms": 60, "dont-disconnect": 20}
## Devices that halt the whole system if they lose power.
const CRITICAL := ["dont-disconnect"]

## Terminal points on the wiring panel (viewport pixels, 640x360).
const SOURCE_POS := {
	"V55": Vector2(50, 45), "V67": Vector2(50, 89), "V22": Vector2(50, 132),
	"V86": Vector2(50, 176), "V65": Vector2(50, 219),
}
const DEVICE_POS := {
	"monitorlegacy01": Vector2(482, 58), "oxygenmonitor": Vector2(482, 91),
	"comms": Vector2(482, 124), "dont-disconnect": Vector2(482, 157),
}

## id -> {"color": Color, "p": [p0, c0, c1, p1] (cubic bezier), "ends": [end_id, end_id]}
var segments := {}
## id -> {"seg": int, "idx": 0|1, "kind": "source"|"device"|"free", "name": String,
##        "state": "terminal"|"insulated"|"stripped"|"spliced"}
var ends := {}
## id -> {"a": end_id, "b": end_id, "pos": Vector2, "wraps": int, "heat": float, "soldered": bool}
var splices := {}
## device -> watts currently reaching it
var watts := {}
var log_lines: Array[String] = []
var cover_removed := false
var failed := false
var solved := false

var _next_id := 1


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	for sp in splices.values():
		sp["heat"] = maxf(0.0, sp["heat"] - delta / HEAT_SECONDS)


func _start_wires() -> Array:
	# "to" = "" makes a loose wire ending at "end".
	return [
		{"from": "V55", "to": "monitorlegacy01", "color": Color(1.0, 0.92, 0.1),
			"c0": Vector2(120, 150), "c1": Vector2(380, 25)},
		{"from": "V67", "to": "comms", "color": Color(0.7, 0.9, 0.2),
			"c0": Vector2(160, 200), "c1": Vector2(380, 85)},
		{"from": "V22", "to": "dont-disconnect", "color": Color(0.6, 0.05, 0.15),
			"c0": Vector2(110, 185), "c1": Vector2(390, 85)},
		{"from": "V86", "to": "oxygenmonitor", "color": Color(1.0, 0.68, 0.78),
			"c0": Vector2(210, 80), "c1": Vector2(300, 175)},
		{"from": "V65", "to": "", "end": Vector2(355, 213), "color": Color(1.0, 0.5, 0.15),
			"c0": Vector2(200, 200), "c1": Vector2(352, 182)},
	]


func reset() -> void:
	segments.clear()
	ends.clear()
	splices.clear()
	log_lines.clear()
	failed = false
	for w in _start_wires():
		var p0: Vector2 = SOURCE_POS[w["from"]]
		var p1: Vector2 = DEVICE_POS[w["to"]] if w["to"] != "" else w["end"]
		var sid := _new_segment(w["color"], [p0, w["c0"], w["c1"], p1])
		_new_end(sid, 0, "source", w["from"])
		if w["to"] != "":
			_new_end(sid, 1, "device", w["to"])
		else:
			_new_end(sid, 1, "free", "")
	watts = _compute_watts()
	log_lines.append("[system] power rebalancing was succesful")
	for d in DEVICES:
		if watts[d] < DEVICES[d]:
			log_lines.append(_offline_msg(d, watts[d]))
	solved = _all_online(watts)
	changed.emit()


# --- player actions ------------------------------------------------------------

func cut(sid: int, t: float) -> String:
	var seg: Dictionary = segments[sid]
	var p: Array = seg["p"]
	if t < 0.06 or t > 0.94:
		return "Too close to the end of the wire to cut there."
	var gap := 4.0 / maxf(_length(p), 1.0)
	var a := _new_segment(seg["color"], sub(p, 0.0, t - gap))
	var b := _new_segment(seg["color"], sub(p, t + gap, 1.0))
	_attach(seg["ends"][0], a, 0)
	_attach(seg["ends"][1], b, 1)
	_new_end(a, 1, "free", "")
	_new_end(b, 0, "free", "")
	segments.erase(sid)
	_commit()
	return "Snip. The wire is cut in two."


func strip(eid: int) -> String:
	var e: Dictionary = ends[eid]
	if e["state"] == "stripped":
		return "Already stripped. Bare copper."
	e["state"] = "stripped"
	_commit()
	return "Stripped the insulation off that end."


func make_splice(a: int, b: int) -> String:
	if ends[a]["seg"] == ends[b]["seg"]:
		return "Those are both ends of the same piece of wire."
	if ends[a]["state"] != "stripped" or ends[b]["state"] != "stripped":
		return "Strip both ends with the scissors first."
	var pa := end_pos(a)
	var pb := end_pos(b)
	var mid := (pa + pb) / 2.0
	var dir := (pb - pa).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	# Ends overlap past each other, as in a real Western Union splice.
	_move_end(a, mid + dir * 4.0)
	_move_end(b, mid - dir * 4.0)
	ends[a]["state"] = "spliced"
	ends[b]["state"] = "spliced"
	splices[_take_id()] = {"a": a, "b": b, "pos": mid, "wraps": 0, "heat": 0.0, "soldered": false}
	_commit()
	return "Ends crossed. Click the joint to twist them together."


func twist(id: int) -> String:
	var sp: Dictionary = splices[id]
	if sp["soldered"]:
		return "It's soldered solid."
	if sp["wraps"] >= WRAPS_NEEDED:
		return "Already twisted tight. Heat it with the iron, then add tin."
	sp["wraps"] += 1
	_commit()
	if sp["wraps"] == WRAPS_NEEDED:
		return "Western Union splice twisted. Heat it with the iron, then add tin."
	var side := "left" if sp["wraps"] % 2 == 1 else "right"
	return "Wrapped the %s end around the other wire (%d/%d)." % [side, sp["wraps"], WRAPS_NEEDED]


func heat(id: int) -> String:
	var sp: Dictionary = splices[id]
	if sp["soldered"]:
		return "The joint is already soldered."
	if sp["wraps"] < WRAPS_NEEDED:
		return "Twist the splice before soldering it."
	sp["heat"] = 1.0
	return "The iron heats the joint. Feed it tin while it's hot."


func solder(id: int) -> String:
	var sp: Dictionary = splices[id]
	if sp["soldered"]:
		return "The joint is already soldered."
	if sp["wraps"] < WRAPS_NEEDED:
		return "Twist the splice before soldering it."
	if sp["heat"] < MIN_SOLDER_HEAT:
		return "The tin beads up on the cold wire. Heat the joint with the iron first."
	sp["soldered"] = true
	_commit()
	return "Tin flows into the twists. Solid joint."


func unsplice(id: int) -> String:
	var sp: Dictionary = splices[id]
	var a: int = sp["a"]
	var b: int = sp["b"]
	var c: Vector2 = sp["pos"]
	var dir := (end_pos(a) - end_pos(b)).normalized()
	_move_end(a, c - dir * 6.0)
	_move_end(b, c + dir * 6.0)
	ends[a]["state"] = "stripped"
	ends[b]["state"] = "stripped"
	var was_soldered: bool = sp["soldered"]
	splices.erase(id)
	_commit()
	return "You cut through the solder." if was_soldered else "You pull the splice apart."


# --- queries ---------------------------------------------------------------------

func end_pos(eid: int) -> Vector2:
	var e: Dictionary = ends[eid]
	var p: Array = segments[e["seg"]]["p"]
	return p[0] if e["idx"] == 0 else p[3]


func hit_splice(pos: Vector2, radius := 8.0) -> int:
	var best := -1
	for id in splices:
		var d := pos.distance_to(splices[id]["pos"])
		if d < radius:
			radius = d
			best = id
	return best


## Free (cut) ends that are not part of a splice.
func hit_end(pos: Vector2, radius := 6.0) -> int:
	var best := -1
	for eid in ends:
		var e: Dictionary = ends[eid]
		if e["kind"] != "free" or e["state"] == "spliced":
			continue
		var d := pos.distance_to(end_pos(eid))
		if d < radius:
			radius = d
			best = eid
	return best


## Returns {"seg": id, "t": float} for the nearest wire within radius, or {}.
func hit_wire(pos: Vector2, radius := 5.0) -> Dictionary:
	var best := {}
	var n := 64
	for sid in segments:
		var pts := samples(segments[sid]["p"], n)
		for i in n:
			var q := Geometry2D.get_closest_point_to_segment(pos, pts[i], pts[i + 1])
			var d := pos.distance_to(q)
			if d < radius:
				radius = d
				var piece := maxf(pts[i].distance_to(pts[i + 1]), 0.001)
				best = {"seg": sid, "t": (i + pts[i].distance_to(q) / piece) / n}
	return best


# --- bezier helpers -----------------------------------------------------------------

static func bez(p: Array, t: float) -> Vector2:
	var u := 1.0 - t
	return p[0] * (u * u * u) + p[1] * (3.0 * u * u * t) + p[2] * (3.0 * u * t * t) + p[3] * (t * t * t)


static func split(p: Array, t: float) -> Array:
	var a: Vector2 = p[0].lerp(p[1], t)
	var b: Vector2 = p[1].lerp(p[2], t)
	var c: Vector2 = p[2].lerp(p[3], t)
	var d := a.lerp(b, t)
	var e := b.lerp(c, t)
	var f := d.lerp(e, t)
	return [[p[0], a, d, f], [f, e, c, p[3]]]


## Part of the curve between ta and tb.
static func sub(p: Array, ta: float, tb: float) -> Array:
	var right: Array = split(p, ta)[1]
	if ta >= 1.0:
		return right
	return split(right, (tb - ta) / (1.0 - ta))[0]


static func samples(p: Array, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(bez(p, float(i) / n))
	return pts


# --- internals ------------------------------------------------------------------------

func _take_id() -> int:
	_next_id += 1
	return _next_id


func _new_segment(color: Color, p: Array) -> int:
	var id := _take_id()
	segments[id] = {"color": color, "p": p, "ends": [-1, -1]}
	return id


func _new_end(sid: int, idx: int, kind: String, name: String) -> int:
	var id := _take_id()
	ends[id] = {"seg": sid, "idx": idx, "kind": kind, "name": name,
		"state": "insulated" if kind == "free" else "terminal"}
	segments[sid]["ends"][idx] = id
	return id


func _attach(eid: int, sid: int, idx: int) -> void:
	ends[eid]["seg"] = sid
	ends[eid]["idx"] = idx
	segments[sid]["ends"][idx] = eid


## Moves a free end, dragging its neighbouring control point along to keep the curve's shape.
func _move_end(eid: int, to: Vector2) -> void:
	var e: Dictionary = ends[eid]
	var p: Array = segments[e["seg"]]["p"]
	var tip := 0 if e["idx"] == 0 else 3
	var ctrl := 1 if e["idx"] == 0 else 2
	var delta: Vector2 = to - p[tip]
	p[tip] = to
	p[ctrl] = p[ctrl] + delta


func _length(p: Array) -> float:
	var pts := samples(p, 24)
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


func _commit() -> void:
	var new_watts := _compute_watts()
	_log_changes(new_watts)
	watts = new_watts
	changed.emit()


## Connectivity: segments joined by *soldered* splices form one circuit.
## A device gets the sum of every source in its circuit.
func _compute_watts() -> Dictionary:
	var parent := {}
	for sid in segments:
		parent[sid] = sid
	for sp in splices.values():
		if sp["soldered"]:
			parent[_root(parent, ends[sp["a"]]["seg"])] = _root(parent, ends[sp["b"]]["seg"])
	var supply := {}
	for e in ends.values():
		if e["kind"] == "source":
			var r = _root(parent, e["seg"])
			supply[r] = supply.get(r, 0) + SOURCES[e["name"]]
	var result := {}
	for d in DEVICES:
		result[d] = 0
	for e in ends.values():
		if e["kind"] == "device":
			result[e["name"]] = supply.get(_root(parent, e["seg"]), 0)
	return result


func _root(parent: Dictionary, x):
	while parent[x] != x:
		x = parent[x]
	return x


func _log_changes(new_watts: Dictionary) -> void:
	for d in DEVICES:
		var before: int = watts.get(d, 0)
		var now: int = new_watts[d]
		if before == now:
			continue
		var need: int = DEVICES[d]
		if now >= need and before < need:
			log_lines.append("%s booted up (%dW)" % [d, now])
		elif now < need:
			log_lines.append(_offline_msg(d, now))
			if d in CRITICAL and not failed:
				failed = true
				log_lines.append("[FATAL] %s lost power. system halted." % d)
	var all_on := _all_online(new_watts)
	if all_on and not solved:
		log_lines.append("[system] all systems nominal")
	solved = all_on


func _offline_msg(d: String, w: int) -> String:
	if w == 0:
		return "[warning] %s lost power!" % d
	return "%s can't boot up! insufficient power, missing %d watts" % [d, DEVICES[d] - w]


func _all_online(w: Dictionary) -> bool:
	for d in DEVICES:
		if w[d] < DEVICES[d]:
			return false
	return true
