class_name SoundEvents
extends RefCounted
## Shared spatial sound-event registry (Phase 5). Real world one-shots that
## actually play (logging, footsteps, dog, vehicles) announce themselves here
## with their stream, world position and category. Listeners - currently the
## camera-wall microphones - may re-sample them. Sounds produced BY the TV are
## never announced, so the relay can never feed back into itself.

static var _listeners: Array[Callable] = []
static var emitted := 0
## Last emission positions (ring of 64) - lets tests prove TV output never
## re-enters the registry.
static var recent: Array[Vector3] = []


static func listen(c: Callable) -> void:
	if not _listeners.has(c):
		_listeners.append(c)


static func unlisten(c: Callable) -> void:
	_listeners.erase(c)


## Phase 15 hop rule: only ORIGIN "world" sounds reach microphones. Relay,
## recording, UI, music and internal cues are refused here, so desk/TV
## output can never be re-captured into an escalating loop.
static var refused := 0


static func emit(stream: AudioStream, pos: Vector3, volume_db := 0.0, category := "world", label := "", origin := "world") -> void:
	if stream == null:
		return
	if origin != "world":
		refused += 1
		return
	emitted += 1
	recent.append(pos)
	if recent.size() > 64:
		recent.pop_front()
	for c in _listeners.duplicate():
		if c.is_valid():
			c.call(stream, pos, volume_db, category, label)
		else:
			_listeners.erase(c)
