class_name LoggingTest
extends RefCounted
## Preview Tour "Logging Test": cycles through real island trees near camp
## that cover the review cases (flat ground, slope, rock contact, a close
## neighbour trunk, small birch, large pine, closest-to-camp). Teleports to a
## valid cutting stand facing the trunk. In Preview mode nothing is saved
## and every change resets when you leave the world.

const CASES := ["flat", "slope", "rock", "neighbour", "small", "large", "camp_edge"]
static var _case_i := -1
static var _cache := {}


static func next(world: Node, restart: bool) -> String:
	if restart:
		_case_i = -1
	_case_i = (_case_i + 1) % CASES.size()
	var case_name: String = CASES[_case_i]
	var i := find(case_name)
	if i < 0:
		return "No tree found for case '%s'" % case_name
	var stands := PlacementValidator.cut_stands(i, PlacementValidator._tree_hash(), PlacementValidator._rock_hash()) if not _cache.has("hashes") else PlacementValidator.cut_stands(i, _cache.hashes[0], _cache.hashes[1])
	var base := World.tree_position(i)
	var stand := stands[0] if not stands.is_empty() else base + Vector3(1.4, 0, 0)
	var p: Node3D = Game.player
	if p:
		var eye := stand + Vector3(0, 1.65, 0)
		p.teleport(eye, base + Vector3(0, 1.1, 0))
		if Game.vegetation:
			Game.vegetation.update_collision_around(stand)
	const NAMES := ["pine", "spruce", "birch"]
	return "Logging test %d/%d: %s - %s, %.2f m trunk, %.1f m tall (tree #%d)" % [_case_i + 1, CASES.size(), case_name.replace("_", " "), NAMES[int(World.trees.species[i])], float(World.trees.radius[i]) * 2.0, float(World.trees.height[i]), int(World.trees.id[i])]


## Deterministic choice of a standing tree within ~260 m of camp for a case.
static func find(case_name: String) -> int:
	if _cache.has(case_name):
		var c: int = _cache[case_name]
		if Game.trees == null or Game.trees.state_of(int(World.trees.id[c])) == TreeService.State.STANDING:
			return c
	if not _cache.has("hashes"):
		_cache.hashes = [PlacementValidator._tree_hash(), PlacementValidator._rock_hash()]
	var camp := World.camp_origin()
	var best := -1
	var best_score := -INF
	for i in World.tree_count():
		var p := Vector2(World.trees.x[i], World.trees.z[i])
		var d := p.distance_to(Vector2(camp.x, camp.z))
		if d > 260.0:
			continue
		if Game.trees and Game.trees.state_of(int(World.trees.id[i])) != TreeService.State.STANDING:
			continue
		var n := World.normal_at(p.x, p.y)
		var slope := 1.0 - n.y
		var score := -d * 0.01
		match case_name:
			"flat": score += -slope * 50.0
			"slope": score += -absf(slope - 0.18) * 40.0
			"rock":
				var near := 99.0
				for ri in _cache.hashes[1].get(PlacementValidator._key(p.x, p.y, 8.0), []):
					near = minf(near, p.distance_to(Vector2(World.rocks.x[ri], World.rocks.z[ri])) - float(World.rocks.scale[ri]) * 0.5)
				score += -near * 4.0
			"neighbour":
				var near_t := 99.0
				for j in _cache.hashes[0].get(PlacementValidator._key(p.x, p.y, 8.0), []):
					if j != i:
						near_t = minf(near_t, p.distance_to(Vector2(World.trees.x[j], World.trees.z[j])))
				score += -absf(near_t - 3.0) * 4.0
			"small": score += (1.0 if int(World.trees.species[i]) == 2 else 0.0) * 10.0 - float(World.trees.radius[i]) * 40.0
			"large": score += float(World.trees.radius[i]) * 40.0 + (5.0 if int(World.trees.species[i]) == 0 else 0.0)
			"camp_edge": score += -d * 1.0
		if PlacementValidator.cut_stands(i, _cache.hashes[0], _cache.hashes[1]).is_empty():
			continue
		if score > best_score:
			best_score = score
			best = i
	if best >= 0:
		_cache[case_name] = best
	return best
