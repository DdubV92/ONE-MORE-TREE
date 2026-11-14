class_name IslandFinds
extends Node3D
## Phase 28: things the island kept. Eight small finds stand in the far
## forest and along the shore, placed from the world seed (the same places
## in every campaign on the same island). Looking closely at one writes a
## line in the Journal and marks it on the map. They tell no story and
## explain nothing: each is only what the boss saw.

signal found_changed()

const MIN_FROM_CAMP := 170.0
const SPACING := 120.0
const CLEAR_OF_TREES := 3.6

## id -> {name, prop, text}
const FINDS := [
	{"id": "stake", "name": "A survey stake", "prop": "stake",
		"text": "A company survey stake, the tape gone pale. LOT 14. The company's numbers go a good deal higher than three."},
	{"id": "old_camp", "name": "A fire ring", "prop": "ring",
		"text": "A ring of stones and a kettle rusted through. Somebody camped here before the company did. The trees growing inside the ring are not young."},
	{"id": "tally", "name": "A tally plank", "prop": "plank",
		"text": "A plank nailed to nothing, cut with tally marks in fives. Thirty-odd groups, then one mark by itself."},
	{"id": "boot", "name": "A boot", "prop": "boot",
		"text": "One work boot, laced and tied, standing upright in the moss. There is no second one. I looked."},
	{"id": "initials", "name": "A carved post", "prop": "post",
		"text": "Initials and a year cut into a post, grown grey. I read the year three times and it would not come out sensible."},
	{"id": "billboard", "name": "A sign for the park", "prop": "sign",
		"text": "A painted sign for the park. Rides, a lake, a family. COMING NEXT SUMMER. It has been standing in the weather a long time."},
	{"id": "saw", "name": "A saw in a stump", "prop": "saw",
		"text": "A two-man saw left in a cut. They got halfway through and both let go."},
	{"id": "cairn", "name": "Two cairns", "prop": "cairn",
		"text": "A stack of flat stones facing the sea. Ten paces behind it, another, facing the trees."},
]

var found := {}                     # id -> day found
var sites := {}                     # id -> Vector3
var _props := {}


func _ready() -> void:
	name = "IslandFinds"


## Chooses the places (deterministic) and builds the props.
func setup() -> void:
	for c in get_children():
		c.queue_free()
	_props.clear()
	sites = plan()
	for f in FINDS:
		var id := str(f.id)
		if not sites.has(id):
			continue
		var n := FindProp.new()
		add_child(n)
		n.setup(self, f, sites[id])
		_props[id] = n


## Where each find stands: one per sector around the island, on dry land
## well away from camp and from each other. A pure function of the island.
static func plan() -> Dictionary:
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("finds:%s:%s" % [str(World.manifest.get("world_seed", 0)), World.island_revision])
	var b := IslandMap.bounds()
	var centre := b.position + b.size * 0.5
	var o := World.camp_origin()
	var placed: Array = []
	for i in FINDS.size():
		var base := TAU * float(i) / float(FINDS.size())
		for attempt in 160:
			var a := base + rng.randf_range(-0.3, 0.3)
			var r := rng.randf_range(0.25, 0.92)
			var x := centre.x + cos(a) * b.size.x * 0.5 * r
			var z := centre.y + sin(a) * b.size.y * 0.5 * r
			if not World.in_bounds(Vector2(x, z)) or World.water_depth_at(x, z) > 0.02:
				continue
			if World.surface_at(x, z) == World.Surface.ROCK or World.normal_at(x, z).y < 0.9:
				continue
			if Vector2(x - o.x, z - o.z).length() < MIN_FROM_CAMP:
				continue
			var ok := true
			for q in placed:
				if Vector2(x - (q as Vector3).x, z - (q as Vector3).z).length() < SPACING:
					ok = false
					break
			if not ok:
				continue
			var p := Vector3(x, World.height_at(x, z), z)
			# Clear of trunks: nothing stands inside a tree. The island's
			# ORIGINAL trees, so felling never moves a find.
			if _tree_near(x, z):
				continue
			placed.append(p)
			out[str(FINDS[i].id)] = p
			break
	return out


static var _cells := {}             # Vector2i (4 m cell) -> [tree indices]
static var _cells_key := ""


static func _tree_near(x: float, z: float) -> bool:
	var key := "%s:%s:%d" % [World.island_revision, World.manifest_variant, World.tree_count()]
	if _cells_key != key:
		_cells_key = key
		_cells = {}
		for i in World.tree_count():
			var c := Vector2i(int(floor(float(World.trees.x[i]) / 4.0)), int(floor(float(World.trees.z[i]) / 4.0)))
			if not _cells.has(c):
				_cells[c] = PackedInt32Array()
			var arr: PackedInt32Array = _cells[c]
			arr.append(i)
			_cells[c] = arr
	var c0 := Vector2i(int(floor(x / 4.0)), int(floor(z / 4.0)))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for i in _cells.get(c0 + Vector2i(dx, dz), PackedInt32Array()):
				if Vector2(float(World.trees.x[i]) - x, float(World.trees.z[i]) - z).length() < CLEAR_OF_TREES:
					return true
	return false


func is_found(id: String) -> bool:
	return found.has(id)


## The boss looked closely. Returns the line to show ("" if unknown).
func discover(id: String) -> String:
	var f := def(id)
	if f.is_empty():
		return ""
	if not found.has(id):
		var c: CampaignService = Game.campaign
		found[id] = c.clock.day if c and c.clock else 0
		found_changed.emit()
		if c and c.active:
			c.notice.emit("Written down: %s. (Journal → Field notes; marked on the map.)" % str(f.name), 6.0)
	return str(f.text)


static func def(id: String) -> Dictionary:
	for f in FINDS:
		if str(f.id) == id:
			return f
	return {}


## Lines for the Journal: what has been found, in the order it was found.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	var ids := found.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(found[a]) < int(found[b]) if int(found[a]) != int(found[b]) else a < b)
	for id in ids:
		var f := def(str(id))
		if f.is_empty():
			continue
		out.append("# " + str(f.name))
		out.append(str(f.text))
		out.append("(Found on day %d.)" % int(found[id]))
	return out


func capture() -> Dictionary:
	return {"version": 1, "found": found.duplicate()}


func restore(d: Dictionary) -> void:
	found = {}
	var src: Dictionary = d.get("found", {})
	for k in src:
		if not def(str(k)).is_empty():
			found[str(k)] = int(src[k])
	found_changed.emit()
