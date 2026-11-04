class_name Keys
extends RefCounted
## Phase 9: live key names for prompts and help, and the remappable action
## table. Prompts call Keys.label("interact") so a rebound key shows up
## everywhere at once; nothing in the UI hardcodes a key.

## Remappable gameplay actions, in the order the Settings list shows them.
## (Debug/dev keys stay fixed and are not offered.)
const REMAPPABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["jump", "Jump"], ["sprint", "Sprint (hold)"], ["crouch", "Crouch"], ["interact", "Interact / use"],
	["attack", "Swing axe / chainsaw throttle (hold)"], ["set_down", "Set load down"], ["drop_load", "Drop load"],
	["tool_small", "Small axe"], ["tool_medium", "Medium axe"], ["tool_large", "Large axe"], ["tool_saw", "Chainsaw"], ["saw_engine", "Chainsaw: start / stop engine"],
	["toggle_journal", "Journal"], ["toggle_help", "Controls / help"], ["headlights", "Truck headlights"],
	["quick_save", "Quick save"], ["pause", "Pause / back"],
]
## Actions that must always keep a binding (the only way out of a menu).
const PROTECTED := ["pause"]

static var _defaults := {}


## Readable name of the first binding of `action` ("E", "Left mouse", ...).
static func label(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		var t := event_text(ev)
		if t != "":
			return t
	return "unbound"


## "[E]"-style prompt fragment.
static func tag(action: String) -> String:
	return "[%s]" % label(action)


static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		# Layout-aware name on real displays (e.g. AZERTY shows "Z" for the
		# physical W key); headless has no keyboard layout, so use the code.
		if k.physical_keycode != 0 and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Left mouse"
			MOUSE_BUTTON_RIGHT: return "Right mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle mouse"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return ""


static func remember_defaults() -> void:
	if not _defaults.is_empty():
		return
	for a in REMAPPABLE:
		_defaults[a[0]] = InputMap.action_get_events(a[0]).duplicate()


## Binds `ev` as the primary event of `action`. If another remappable action
## already uses the same input, the two swap (so nothing is left unbound and
## no two actions fight over one key). Returns the action that was swapped
## with, or "".
static func rebind(action: String, ev: InputEvent) -> String:
	remember_defaults()
	var swapped := ""
	var old_primary: InputEvent = null
	var evs := InputMap.action_get_events(action)
	if not evs.is_empty():
		old_primary = evs[0]
	for a in REMAPPABLE:
		var other: String = a[0]
		if other == action:
			continue
		for oe in InputMap.action_get_events(other):
			if _same(oe, ev):
				InputMap.action_erase_event(other, oe)
				if old_primary:
					InputMap.action_add_event(other, old_primary)
				swapped = other
	if old_primary:
		InputMap.action_erase_event(action, old_primary)
	var rest := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for r in rest:
		if not _same(r, ev):
			InputMap.action_add_event(action, r)
	return swapped


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var pa := ka.physical_keycode if ka.physical_keycode != 0 else ka.keycode
		var pb := kb.physical_keycode if kb.physical_keycode != 0 else kb.keycode
		return pa == pb
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


static func reset_defaults() -> void:
	remember_defaults()
	for a in _defaults:
		InputMap.action_erase_events(a)
		for ev in _defaults[a]:
			InputMap.action_add_event(a, ev)


## Serializable form of the current remappable bindings (primary only).
static func capture() -> Dictionary:
	var out := {}
	for a in REMAPPABLE:
		var evs := InputMap.action_get_events(a[0])
		if evs.is_empty():
			continue
		var ev: InputEvent = evs[0]
		if ev is InputEventKey:
			var k := ev as InputEventKey
			out[a[0]] = {"k": k.physical_keycode if k.physical_keycode != 0 else k.keycode, "phys": k.physical_keycode != 0}
		elif ev is InputEventMouseButton:
			out[a[0]] = {"m": (ev as InputEventMouseButton).button_index}
	return out


static func apply_saved(d: Dictionary) -> void:
	remember_defaults()
	for action in d:
		if not InputMap.has_action(action):
			continue
		var e: Dictionary = d[action]
		var ev: InputEvent
		if e.has("m"):
			var mb := InputEventMouseButton.new()
			mb.button_index = int(e.m)
			ev = mb
		elif e.has("k"):
			var k := InputEventKey.new()
			if bool(e.get("phys", true)):
				k.physical_keycode = int(e.k)
			else:
				k.keycode = int(e.k)
			ev = k
		if ev:
			rebind(action, ev)
