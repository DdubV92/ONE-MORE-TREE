class_name Wildlife
extends Node3D
## Phase 28: animals you can see. Gulls on the shore, crabs on the sand
## and deer in the woods, as small pixel sprites.
##
## They are scenery with one job: to be read. They are out in daylight
## only; at the start of dusk the gulls lift together and go out to sea
## and the deer slip away, which is the island telling you to go home. As
## the island stirs (NightPressure) there are fewer of them each morning,
## and none at all once the hunt begins.
##
## Nothing here is saved, nothing here is safe or unsafe, and no animal
## can be harmed: where they stand is a pure function of the island.

const GULL_SITES := 6
const GULLS_PER := 3
const CRAB_SITES := 6
const CRABS_PER := 2
const DEER_SITES := 3
const DEER_PER := 2
const DEER_FROM_CAMP := 110.0
const GULL_FLUSH := 13.0            # metres: the boss this close and they lift
const CRAB_HIDE := 4.5
const DEER_ALERT := 30.0
const DEER_BOLT := 15.0
const FAR := 170.0                  # beyond this nothing is animated

const PAL := {
	"W": Color(0.96, 0.96, 0.94), "G": Color(0.7, 0.73, 0.76), "K": Color(0.1, 0.1, 0.11), "Y": Color(0.92, 0.68, 0.16),
	"R": Color(0.78, 0.3, 0.2), "B": Color(0.56, 0.38, 0.24), "D": Color(0.34, 0.22, 0.14), "T": Color(0.8, 0.68, 0.5),
}

const ART := {
	"gull_fly": [[
		"K...........K",
		".G.........G.",
		"..GG.....GG..",
		"...WWW.WWW...",
		"....WWWWWY...",
		".....WWW.....",
		"............."], [
		".............",
		".............",
		"....WWWWWY...",
		"..GGWWWWWGG..",
		".GG..WWW..GG.",
		"K...........K",
		"............."]],
	"gull_stand": [[
		".........",
		"....WW...",
		"...WWKY..",
		"..GWWW...",
		".GGGWW...",
		"KGGGW....",
		"...Y.....",
		"...Y....."]],
	"crab": [[
		"R.......R",
		".R.KRK.R.",
		"..RRRRR..",
		".RRRRRRR.",
		"R.R...R.R"], [
		".R.....R.",
		".R.KRK.R.",
		"..RRRRR..",
		".RRRRRRR.",
		".R.R.R.R."]],
	"deer": [[                        # 0: head up
		"................D.D...",
		"................DBD...",
		"................BBBB..",
		"................BKBBK.",
		"...............BBBB...",
		"..............BBB.....",
		".............BBB......",
		".WDDDDDDDDDDDBBB......",
		"WWBBBBBBBBBBBBBB......",
		".WBBBBBBBBBBBBBB......",
		"..BBBBBBBBBBBBB.......",
		"..BBTTTTTTTTBBB.......",
		"..BB.TTTTTT..BB.......",
		"..B.B.......B.B.......",
		"..B.B.......B.B.......",
		"..D.D.......D.D.......",
		"..D.D.......D.D.......",
		"..K.K.......K.K......."], [   # 1: grazing
		"......................",
		"......................",
		"......................",
		"......................",
		"......................",
		"......................",
		"......................",
		".WDDDDDDDDDDDDD.......",
		"WWBBBBBBBBBBBBBB......",
		".WBBBBBBBBBBBBBBB.....",
		"..BBBBBBBBBBBBBBBB....",
		"..BBTTTTTTTTBBB.BBB...",
		"..BB.TTTTTT..BB..BBB..",
		"..B.B.......B.B..DBBD.",
		"..B.B.......B.B...BKB.",
		"..D.D.......D.D...BBB.",
		"..D.D.......D.D....BK.",
		"..K.K.......K.K......."], [   # 2: running, legs out
		"......................",
		"................D.D...",
		"................DBD...",
		"................BBBB..",
		"................BKBBK.",
		"W.............BBBB....",
		"WW..........BBBB......",
		".WDDDDDDDDDDBBB.......",
		".WBBBBBBBBBBBBBB......",
		"..BBBBBBBBBBBBBB......",
		"..BBBTTTTTTTBBBB......",
		".BB..TTTTTT...BBB.....",
		"BB..............BB....",
		"D................BB...",
		"K.................DK..",
		"......................",
		"......................",
		"......................"], [   # 3: running, legs gathered
		"......................",
		"......................",
		"................D.D...",
		"................DBD...",
		"................BBBB..",
		"W...............BKBBK.",
		"WW............BBBB....",
		".WDDDDDDDDDDBBBB......",
		".WBBBBBBBBBBBBBB......",
		"..BBBBBBBBBBBBBB......",
		"..BBBTTTTTTTBBBB......",
		"...BB.TTTTT.BB........",
		"....BB.....BB.........",
		".....DD...DD..........",
		"......K...K...........",
		"......................",
		"......................",
		"......................"]],
}
const PIXEL := {"gull_fly": 0.075, "gull_stand": 0.06, "crab": 0.032, "deer": 0.075}

static var _sheets := {}            # art key -> ImageTexture (frames side by side)

var animals: Array = []             # [{kind, idx, s, home, pos, st, t, ...}]
var force_out := -1                 # tests and captures: 1 = out, 0 = gone, -1 = by the clock
var _was_out := false
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


static func sheet(key: String) -> ImageTexture:
	if _sheets.has(key):
		return _sheets[key]
	var frames: Array = ART[key]
	var w := 0
	var h := 0
	for f in frames:
		h = maxi(h, (f as Array).size())
		for row in f:
			w = maxi(w, str(row).length())
	var img := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for k in frames.size():
		var f: Array = frames[k]
		for y in f.size():
			var row := str(f[y])
			for x in row.length():
				var ch := row[x]
				if PAL.has(ch):
					img.set_pixel(k * w + x, y, PAL[ch])
	var tex := ImageTexture.create_from_image(img)
	_sheets[key] = tex
	return tex


const SHORE_SURFACES := [World.Surface.SAND, World.Surface.ROCK, World.Surface.GRASS]

static var _plan := {}
static var _plan_key := ""


## Where the animals live: a pure function of the island.
static func plan() -> Dictionary:
	var key := "%s:%s:%s" % [str(World.manifest.get("world_seed", 0)), World.island_revision, World.manifest_variant]
	if _plan_key == key:
		return _plan
	_plan = _make_plan()
	_plan_key = key
	return _plan


static func _make_plan() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("wildlife:%s:%s" % [str(World.manifest.get("world_seed", 0)), World.island_revision])
	var b := IslandMap.bounds()
	var centre := b.position + b.size * 0.5
	var o := World.camp_origin()
	var gulls: Array = []
	var crabs: Array = []
	var deer: Array = []
	for i in GULL_SITES:
		var p := _shore(rng, centre, b, TAU * (float(i) + 0.2) / float(GULL_SITES))
		if p != Vector3.INF:
			gulls.append(p)
	for i in CRAB_SITES:
		var p := _shore(rng, centre, b, TAU * (float(i) + 0.7) / float(CRAB_SITES))
		if p != Vector3.INF:
			crabs.append(p)
	for i in DEER_SITES:
		var base := TAU * (float(i) + 0.5) / float(DEER_SITES)
		for attempt in 200:
			var a := base + rng.randf_range(-0.9, 0.9)
			var r := rng.randf_range(0.2, 0.8)
			var x := centre.x + cos(a) * b.size.x * 0.5 * r
			var z := centre.y + sin(a) * b.size.y * 0.5 * r
			if Vector2(x - o.x, z - o.z).length() < DEER_FROM_CAMP or not dry_ground(x, z):
				continue
			if World.surface_at(x, z) == World.Surface.SAND:
				continue
			deer.append(Vector3(x, World.height_at(x, z), z))
			break
	return {"gulls": gulls, "crabs": crabs, "deer": deer}


## A place a deer can stand: dry, fairly level, not rock, not inside a tree.
static func dry_ground(x: float, z: float) -> bool:
	if not World.in_bounds(Vector2(x, z)) or World.water_depth_at(x, z) > 0.02:
		return false
	if World.surface_at(x, z) == World.Surface.ROCK or World.normal_at(x, z).y < 0.85:
		return false
	return not IslandFinds._tree_near(x, z)


## Dry, level open shore (sand first, then rock or grass) with the sea a
## few steps away, in the sector of the island around `angle`.
static func _shore(rng: RandomNumberGenerator, centre: Vector2, b: Rect2, angle: float) -> Vector3:
	var o := World.camp_origin()
	var second := Vector3.INF
	for attempt in 1500:
		var a := angle + rng.randf_range(-0.5, 0.5)
		var r := rng.randf_range(0.45, 1.0)
		var x := centre.x + cos(a) * b.size.x * 0.5 * r
		var z := centre.y + sin(a) * b.size.y * 0.5 * r
		if not World.in_bounds(Vector2(x, z)) or World.water_depth_at(x, z) > 0.02:
			continue
		var surf := World.surface_at(x, z)
		if not surf in SHORE_SURFACES or World.normal_at(x, z).y < 0.9:
			continue
		if Vector2(x - o.x, z - o.z).length() < 45.0 or (second != Vector3.INF and surf != World.Surface.SAND):
			continue
		var wet := false
		for k in 8:
			var q := Vector2(x, z) + Vector2.RIGHT.rotated(TAU * k / 8.0) * 7.0
			if World.water_depth_at(q.x, q.y) > 0.3:
				wet = true
				break
		if not wet:
			continue
		if surf == World.Surface.SAND:
			return Vector3(x, World.height_at(x, z), z)
		second = Vector3(x, World.height_at(x, z), z)
	return second


func _ready() -> void:
	name = "Wildlife"
	add_to_group("wildlife")
	_rng.seed = 2811
	var pl := plan()
	var n := 0
	for site in pl.gulls:
		for k in GULLS_PER:
			_add("gull", n, _near(site, 2.5, false))
			n += 1
	n = 0
	for site in pl.crabs:
		for k in CRABS_PER:
			_add("crab", n, _near(site, 2.0, false))
			n += 1
	n = 0
	for site in pl.deer:
		for k in DEER_PER:
			_add("deer", n, _near(site + Vector3(3.8 * k, 0.0, 1.6 * k), 1.5, true))
			n += 1
	_was_out = out_now()
	for a in animals:
		_reset(a, _was_out)


func _near(site: Vector3, r: float, clear: bool) -> Vector3:
	for k in 12:
		var x := site.x + _rng.randf_range(-r, r)
		var z := site.z + _rng.randf_range(-r, r)
		if World.water_depth_at(x, z) > 0.02 or (clear and not dry_ground(x, z)):
			continue
		return Vector3(x, World.height_at(x, z), z)
	return site


func _add(kind: String, idx: int, home: Vector3) -> void:
	var s := Sprite3D.new()
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# Unshaded and tinted by the hour: a lit billboard takes the sky's blue
	# on its shadow side and a white gull turns blue.
	s.shaded = false
	s.double_sided = true
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.visibility_range_end = 70.0 if kind == "crab" else 260.0
	add_child(s)
	var a := {"kind": kind, "idx": idx, "s": s, "home": home, "pos": home, "st": "", "t": _rng.randf_range(0.0, 4.0), "v": Vector3.ZERO,
		"ang": _rng.randf_range(0.0, TAU), "rad": _rng.randf_range(9.0, 16.0), "h": 0.0, "dest": home, "art": ""}
	animals.append(a)
	_art(a, {"gull": "gull_stand", "crab": "crab", "deer": "deer"}[kind])


func _art(a: Dictionary, key: String) -> void:
	if str(a.art) == key:
		return
	a.art = key
	var s: Sprite3D = a.s
	var tex := sheet(key)
	s.texture = tex
	s.hframes = (ART[key] as Array).size()
	s.frame = 0
	s.pixel_size = float(PIXEL[key])
	# Feet on the ground: the picture's bottom edge at the node.
	s.offset = Vector2(0.0, tex.get_height() * 0.5)


# ------------------------------------------------------------ when and who

## Are animals out at all right now? Daylight only, and never in the hunt.
func out_now() -> bool:
	if force_out >= 0:
		return force_out == 1
	if Game.hunt and Game.hunt.mode != "none":
		return false
	var c: CampaignService = Game.campaign
	if c and c.active and c.clock:
		return c.clock.phase() == WorkdayClock.Phase.DAYLIGHT
	var h: float = Game.environment.hour if Game.environment else 12.0
	return h >= 6.5 and h < 18.0


## 0..1: how stirred the island is (previews: not at all).
func stir() -> float:
	if NightPressure.override_level >= 0.0:
		return NightPressure.island_level()
	var c: CampaignService = Game.campaign
	return NightPressure.island_level() if c and c.active else 0.0


## How many of each kind the island still has this morning.
func allowed(kind: String) -> int:
	var lvl := stir()
	match kind:
		"deer":
			return int(round(float(DEER_SITES * DEER_PER) * clampf(1.0 - lvl / 0.68, 0.0, 1.0)))
		"gull":
			return maxi(int(round(float(GULL_SITES * GULLS_PER) * (1.0 - 0.75 * lvl))), GULLS_PER)
	return CRAB_SITES * CRABS_PER


func count_out(kind: String) -> int:
	var n := 0
	for a in animals:
		if str(a.kind) == kind and not str(a.st) in ["gone", "leave", "hide"]:
			n += 1
	return n


## One line for the Journal.
func describe() -> String:
	var d := allowed("deer")
	if Game.hunt and Game.hunt.mode != "none":
		return "No birds. No deer. Nothing moves that should."
	if d >= DEER_SITES * DEER_PER:
		return "Deer in the woods, gulls on the sand. They leave at dusk; so should you."
	return "Fewer deer than there were, and fewer gulls." if d > 0 else "You have not seen a deer in days. The gulls keep to the far shore."


func _reset(a: Dictionary, out: bool) -> void:
	var s: Sprite3D = a.s
	a.pos = a.home
	a.v = Vector3.ZERO
	a.h = 0.0
	if not out or int(a.idx) >= allowed(str(a.kind)):
		a.st = "gone"
		s.visible = false
		return
	s.visible = true
	a.st = {"gull": "stand", "crab": "idle", "deer": "graze"}[str(a.kind)]
	_art(a, {"gull": "gull_stand", "crab": "crab", "deer": "deer"}[str(a.kind)])
	s.frame = 0
	if str(a.kind) == "deer" and int(a.idx) % 2 == 0:
		s.frame = 1
	else:
		a.st = "look" if str(a.kind) == "deer" else a.st
	s.modulate = day_tint()
	s.position = a.pos


## Re-reads the clock and the island (tests, captures, mornings).
func refresh() -> void:
	_was_out = out_now()
	for a in animals:
		_reset(a, _was_out)


# ------------------------------------------------------------------ motion

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	step(delta)


func step(delta: float) -> void:
	_clock += delta
	var out := out_now()
	if out != _was_out:
		_was_out = out
		if out:
			for a in animals:
				_reset(a, true)
		else:
			_flush()
	var pl := Game.player as Node3D
	var pp: Vector3 = pl.global_position if pl else Vector3(1e6, 0.0, 1e6)
	var fast := false
	if pl and pl is CharacterBody3D:
		fast = (pl as CharacterBody3D).velocity.length() > 5.0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var tint := day_tint()
	for a in animals:
		if str(a.st) == "gone":
			continue
		var pos: Vector3 = a.pos
		var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
		if d > FAR and not str(a.st) in ["leave", "bolt", "circle", "land"]:
			continue
		match str(a.kind):
			"gull":
				_gull(a, delta, pp, d)
			"crab":
				_crab(a, delta, pp, d)
			"deer":
				_deer(a, delta, pp, d, fast)
		var s: Sprite3D = a.s
		s.modulate = tint
		s.position = (a.pos as Vector3) + Vector3(0.0, float(a.h), 0.0)
		var v: Vector3 = a.v
		if cam and v.length_squared() > 0.01:
			s.flip_h = v.dot(cam.global_basis.x) < 0.0


## The colour of daylight on a sprite: full by day, warm and dim at the
## two ends of it.
func day_tint() -> Color:
	var h: float = Game.environment.hour if Game.environment else 12.0
	var low := maxf(smoothstep(16.8, 19.8, h), 1.0 - smoothstep(5.5, 7.5, h))
	return Color(0.94, 0.93, 0.9).lerp(Color(0.5, 0.36, 0.34), clampf(low, 0.0, 1.0))


## Dusk (or the hunt): everything leaves, visibly.
func _flush() -> void:
	var b := IslandMap.bounds()
	var centre := b.position + b.size * 0.5
	for a in animals:
		if str(a.st) == "gone":
			continue
		var pos: Vector3 = a.pos
		var away := Vector3(pos.x - centre.x, 0.0, pos.z - centre.y)
		away = away.normalized() if away.length() > 1.0 else Vector3(1, 0, 0)
		match str(a.kind):
			"gull":
				a.st = "leave"
				a.t = 0.0
				a.v = away * 9.0
				_art(a, "gull_fly")
				(a.s as Sprite3D).billboard = BaseMaterial3D.BILLBOARD_ENABLED
			"crab":
				a.st = "hide"
				a.t = 1e9
				(a.s as Sprite3D).visible = false
			"deer":
				# Into the trees, away from the open shore (a countdown).
				a.st = "leave"
				a.t = 7.0
				a.v = -away * 8.5


func _gull(a: Dictionary, delta: float, pp: Vector3, d: float) -> void:
	var s: Sprite3D = a.s
	a.t = float(a.t) + delta
	match str(a.st):
		"stand":
			a.v = Vector3.ZERO
			if d < GULL_FLUSH:
				a.st = "circle"
				a.t = 0.0
				_art(a, "gull_fly")
				s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		"circle", "land":
			s.frame = int(_clock * 5.0 + float(a.idx)) % 2
			a.ang = float(a.ang) + delta * 7.0 / float(a.rad)
			var home: Vector3 = a.home
			var want := home + Vector3(cos(float(a.ang)), 0.0, sin(float(a.ang))) * float(a.rad)
			var landing := str(a.st) == "land"
			if landing:
				want = home
			var pos: Vector3 = a.pos
			var to := Vector3(want.x - pos.x, 0.0, want.z - pos.z)
			var v := to.normalized() * minf(7.0, to.length() / maxf(delta, 0.001))
			a.v = v
			a.pos = pos + v * delta
			a.pos.y = home.y
			a.h = move_toward(float(a.h), 0.0 if landing else 6.0 + float(int(a.idx) % 3) * 1.5, delta * 3.0)
			if not landing and float(a.t) > 16.0 and Vector2(home.x - pp.x, home.z - pp.z).length() > GULL_FLUSH * 2.0:
				a.st = "land"
			elif landing and to.length() < 0.4 and float(a.h) < 0.05:
				a.st = "stand"
				a.pos = home
				a.h = 0.0
				_art(a, "gull_stand")
				s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		"leave":
			s.frame = int(_clock * 5.0 + float(a.idx)) % 2
			a.pos = (a.pos as Vector3) + (a.v as Vector3) * delta
			a.h = float(a.h) + delta * 2.2
			if float(a.t) > 26.0:
				a.st = "gone"
				s.visible = false
				s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y


func _crab(a: Dictionary, delta: float, pp: Vector3, d: float) -> void:
	var s: Sprite3D = a.s
	a.t = float(a.t) - delta
	match str(a.st):
		"idle":
			a.v = Vector3.ZERO
			if d < CRAB_HIDE:
				_crab_run(a, pp)
			elif float(a.t) <= 0.0:
				var ang := _rng.randf_range(0.0, TAU)
				a.v = Vector3(cos(ang), 0.0, sin(ang)) * 0.6
				a.st = "scuttle"
				a.t = _rng.randf_range(0.8, 2.0)
		"scuttle":
			s.frame = int(_clock * 8.0) % 2
			if d < CRAB_HIDE:
				_crab_run(a, pp)
				return
			var np: Vector3 = (a.pos as Vector3) + (a.v as Vector3) * delta
			if np.distance_to(a.home) > 3.0 or World.water_depth_at(np.x, np.z) > 0.05:
				a.v = -(a.v as Vector3)
			else:
				np.y = World.height_at(np.x, np.z)
				a.pos = np
			if float(a.t) <= 0.0:
				a.st = "idle"
				a.t = _rng.randf_range(2.0, 7.0)
		"run":
			s.frame = int(_clock * 14.0) % 2
			var np2: Vector3 = (a.pos as Vector3) + (a.v as Vector3) * delta
			np2.y = World.height_at(np2.x, np2.z)
			a.pos = np2
			if float(a.t) <= 0.0 or World.water_depth_at(np2.x, np2.z) > 0.12:
				a.st = "hide"
				a.t = 25.0
				s.visible = false
		"hide":
			# Back out of the sand once the boss has gone.
			if float(a.t) <= 0.0 and Vector2((a.home as Vector3).x - pp.x, (a.home as Vector3).z - pp.z).length() > CRAB_HIDE * 3.0:
				a.pos = a.home
				a.st = "idle"
				a.t = 2.0
				s.visible = true


func _crab_run(a: Dictionary, pp: Vector3) -> void:
	var pos: Vector3 = a.pos
	var away := Vector3(pos.x - pp.x, 0.0, pos.z - pp.z)
	away = away.normalized() if away.length() > 0.05 else Vector3(1, 0, 0)
	a.v = away * 2.4
	a.st = "run"
	a.t = 1.6


func _deer(a: Dictionary, delta: float, pp: Vector3, d: float, fast: bool) -> void:
	var s: Sprite3D = a.s
	a.t = float(a.t) - delta
	match str(a.st):
		"graze", "look":
			a.v = Vector3.ZERO
			if d < DEER_BOLT or (fast and d < DEER_ALERT * 0.85):
				_bolt(a, pp)
			elif d < DEER_ALERT:
				s.frame = 0             # head up, watching
				a.st = "look"
				a.t = 2.5
			elif float(a.t) <= 0.0:
				if str(a.st) == "look":
					a.st = "graze"
					s.frame = 1
					a.t = _rng.randf_range(4.0, 8.0)
				else:
					a.st = "look"
					s.frame = 0
					a.t = _rng.randf_range(3.0, 5.0)
		"bolt":
			s.frame = 2 + int(_clock * 9.0) % 2
			var pos: Vector3 = a.pos
			var dest: Vector3 = a.dest
			var to := Vector3(dest.x - pos.x, 0.0, dest.z - pos.z)
			if to.length() < 0.6:
				a.home = dest
				a.pos = dest
				a.st = "look"
				a.t = 4.0
				s.frame = 0
				return
			var v := to.normalized() * 8.5
			a.v = v
			var np := pos + v * delta
			np.y = World.height_at(np.x, np.z)
			a.pos = np
		"leave":
			s.frame = 2 + int(_clock * 9.0) % 2
			var np2: Vector3 = (a.pos as Vector3) + (a.v as Vector3) * delta
			if World.water_depth_at(np2.x, np2.z) > 0.02:
				a.t = 0.0
			else:
				np2.y = World.height_at(np2.x, np2.z)
				a.pos = np2
			if float(a.t) <= 0.0:
				a.st = "gone"
				s.visible = false


## Away from the boss to somewhere a deer can stand.
func _bolt(a: Dictionary, pp: Vector3) -> void:
	var pos: Vector3 = a.pos
	var away := Vector3(pos.x - pp.x, 0.0, pos.z - pp.z)
	away = away.normalized() if away.length() > 0.05 else Vector3(0, 0, 1)
	var o := World.camp_origin()
	var dest := Vector3.INF
	for k in 16:
		var dir := away.rotated(Vector3.UP, _rng.randf_range(-1.0, 1.0) * (0.4 + 0.08 * k))
		var q := pos + dir * _rng.randf_range(32.0, 50.0)
		if not dry_ground(q.x, q.z) or Vector2(q.x - o.x, q.z - o.z).length() < 70.0:
			continue
		dest = Vector3(q.x, World.height_at(q.x, q.z), q.z)
		break
	if dest == Vector3.INF:
		return                      # cornered: it stays and watches
	a.dest = dest
	a.st = "bolt"
	(a.s as Sprite3D).frame = 2
