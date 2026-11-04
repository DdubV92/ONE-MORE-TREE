class_name Notifications
extends RefCounted
## Phase 9: the single prioritized notification queue behind the HUD
## message line. Deadlines and safety beat worker warnings, which beat
## routine info, which beats minor work chatter. A lower-priority message
## never replaces a higher one that is still being read; repeats coalesce
## ("x3") instead of stacking; everything is kept in a short log (Journal ->
## Help & log). Text never relies on colour alone: each line has a tag.

enum P { MINOR, INFO, WARNING, CRITICAL }
const TAGS := ["", "", "[!] ", "[!!] "]
const MIN_READ := 2.5          # seconds a message is shown before an equal one may replace it
const LOG_MAX := 80

var current := ""
var current_p := -1
var current_left := 0.0
var _shown_for := 0.0
var _repeat := 1
var queue: Array = []          # [text, seconds, priority]
var log: Array = []            # {"text", "p", "day", "t", "count"}
var dropped := 0


static func classify(text: String) -> int:
	var t := text.to_lower()
	for k in ["dusk", "night falls", "final warning", "minute until night", "contract", "deadline", "company has left", "rescue", "ship"]:
		if t.contains(k):
			return P.CRITICAL
	for k in ["wage", "unpaid", "arrears", "owed", "leav", "quit", "refus", "biscuit", "dog", "fired", "depart", "can't", "cannot", "no seat", "full"]:
		if t.contains(k):
			return P.WARNING
	for k in ["chop", "notch", "swing"]:
		if t.contains(k):
			return P.MINOR
	return P.INFO


## Returns true when the text should go on screen now.
func push(text: String, seconds: float, p := -1) -> bool:
	if text.strip_edges() == "":
		return false
	if p < 0:
		p = classify(text)
	_log(text, p)
	if text == current:
		_repeat += 1
		current_left = maxf(current_left, seconds)
		return true
	for q in queue:
		if str(q[0]) == text:
			return false
	var busy := current != "" and current_left > 0.0
	if busy and (p < current_p or (p == current_p and _shown_for < MIN_READ)):
		if p == P.MINOR:
			dropped += 1
			return false
		queue.append([text, seconds, p])
		queue.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
		if queue.size() > 6:
			queue.pop_back()
			dropped += 1
		return false
	_show(text, seconds, p)
	return true


func _show(text: String, seconds: float, p: int) -> void:
	current = text
	current_p = p
	current_left = maxf(seconds, MIN_READ)
	_shown_for = 0.0
	_repeat = 1


## Advances timers; returns the line to display ("" when nothing).
func tick(delta: float) -> String:
	if current != "":
		current_left -= delta
		_shown_for += delta
		if current_left <= 0.0:
			current = ""
			current_p = -1
	if current == "" and not queue.is_empty():
		var q: Array = queue.pop_front()
		_show(str(q[0]), float(q[1]), int(q[2]))
	if current == "":
		return ""
	return TAGS[current_p] + current + ((" (x%d)" % _repeat) if _repeat > 1 else "")


func _log(text: String, p: int) -> void:
	var day := 0
	var t := 0.0
	if Game.campaign and Game.campaign.clock:
		day = Game.campaign.clock.day
		t = Game.campaign.clock.t
	if not log.is_empty() and str(log.back().text) == text:
		log.back().count = int(log.back().count) + 1
		return
	log.append({"text": text, "p": p, "day": day, "t": t, "count": 1})
	if log.size() > LOG_MAX:
		log.pop_front()


func recent(n := 30) -> Array:
	return log.slice(maxi(log.size() - n, 0))
