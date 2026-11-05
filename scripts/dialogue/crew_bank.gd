class_name CrewBank
extends RefCounted
## Phase 17: the authored crew dialogue bank (data/dialogue/crew/*.json),
## loaded once. Lines keep stable ids (Phase 18 voice production keys on
## them: res://audio/voice/<voice>/<id>.ogg). Format and the predicate
## vocabulary: docs/editorial/CREW_SCHEMA.md.

const DIR := "res://data/dialogue/crew"
const SPEAKER_VOICE := {"EMP-01": "marta", "EMP-02": "dale", "EMP-03": "priya", "EMP-04": "tomas", "EMP-05": "joan"}

static var _inst: CrewBank

var lines := {}            # id -> line dict
var openers: Array = []    # ids that may open (pair/group/self, not reply)
var boss := {}             # ask -> [ids]
var offshore := {}         # Phase 19: trigger -> [ids] (offshore beat callouts)
var problems: PackedStringArray = []
var files := 0


static func get_bank() -> CrewBank:
	if _inst == null:
		_inst = CrewBank.new()
		_inst.load_all()
	return _inst


func load_all() -> void:
	lines.clear()
	openers.clear()
	boss.clear()
	offshore.clear()
	problems.clear()
	var d := DirAccess.open(DIR)
	if d == null:
		problems.append("no dialogue directory")
		return
	var names := Array(d.get_files()).filter(func(f: String) -> bool: return f.ends_with(".json"))
	names.sort()
	for f in names:
		var txt := FileAccess.get_file_as_string(DIR + "/" + f)
		var data: Variant = JSON.parse_string(txt)
		if typeof(data) != TYPE_DICTIONARY:
			problems.append("%s: invalid JSON" % f)
			continue
		files += 1
		for ln in (data as Dictionary).get("lines", []):
			var id := str(ln.get("id", ""))
			if id == "" or lines.has(id):
				problems.append("%s: missing or duplicate id %s" % [f, id])
				continue
			lines[id] = ln
	for id in lines:
		var ln: Dictionary = lines[id]
		for r in ln.get("resp", []):
			if not lines.has(str(r)):
				problems.append("%s: response %s missing" % [id, r])
		var to := str(ln.get("to", ""))
		if str(ln.get("cat", "")) == "offshore":
			var trig := str(ln.get("trigger", "later"))
			if not offshore.has(trig):
				offshore[trig] = []
			offshore[trig].append(id)
		if to == "boss":
			var ask := str(ln.get("ask", "chat"))
			if not boss.has(ask):
				boss[ask] = []
			boss[ask].append(id)
		elif not bool(ln.get("reply", false)):
			openers.append(id)
	openers.sort()
	for k in offshore:
		(offshore[k] as Array).sort()


func line(id: String) -> Dictionary:
	return lines.get(id, {})


## Phase 18 voice profile of a worker id: the five starting workers have
## their own; any replacement hire gets one of the two replacement profiles,
## decided from the employee id (persistent: the same id always maps the
## same way, so save/load never changes a voice).
static func voice_of(eid: String) -> String:
	if SPEAKER_VOICE.has(eid):
		return str(SPEAKER_VOICE[eid])
	return "crew_f" if (hash("voice:" + eid) & 1) == 1 else "crew_m"


func count_by(field: String) -> Dictionary:
	var out := {}
	for id in lines:
		var k := str(lines[id].get(field, ""))
		out[k] = int(out.get(k, 0)) + 1
	return out
