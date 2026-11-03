class_name SaveService
extends RefCounted
## Versioned campaign persistence (JSON, atomic write). Preview/review modes
## can never write here: every write goes through Game.can_write_campaign_save().
## Schema history and migration rules: docs/ARCHITECTURE.md "Save schema".

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://saves/campaign.json"

static var path_override := ""


static func save_path() -> String:
	return path_override if path_override != "" else DEFAULT_PATH


static func capture_state(world: Node) -> Dictionary:
	var p: Node3D = world.get("player")
	var env: Node = world.get("environment")
	var felled := []
	for id in World.removed_trees.keys():
		felled.append(int(id))
	felled.sort()
	return {
		"schema": SCHEMA_VERSION,
		"world": {
			"seed": World.manifest.get("world_seed"),
			"generation_version": World.manifest.get("generation_version"),
		},
		"player": {
			"position": [p.global_position.x, p.global_position.y, p.global_position.z] if p else [0, 0, 0],
			"yaw": p.call("get_yaw") if p and p.has_method("get_yaw") else 0.0,
		},
		"time_of_day": env.get("hour") if env else 12.0,
		"felled_trees": felled,
		# Reserved for later prompts (kept explicit so loaders know the shape):
		"economy": {"funds": 0, "axe_tier": "small", "workers": []},
		"timber": {"logs": [], "burned": 0},
		"horror": {"exposure": 0.0},
		"build": Diag.version_string(),
	}


static func save_campaign(state: Dictionary) -> bool:
	if not Game.can_write_campaign_save():
		push_warning("SaveService: refused write outside campaign mode")
		return false
	return write_file(save_path(), state)


static func write_file(path: String, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state, "\t"))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


static func load_campaign() -> Dictionary:
	return read_file(save_path())


static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		push_warning("SaveService: corrupt save ignored")
		return {}
	return migrate(parsed)


## Upgrades older saves; returns {} for unknown future schemas.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("schema", 0))
	if v > SCHEMA_VERSION:
		push_warning("SaveService: save schema %d is newer than this build (%d)" % [v, SCHEMA_VERSION])
		return {}
	if v == 0:
		# Pre-release dev saves stored only the player position.
		data = {"schema": 1, "world": {}, "player": {"position": data.get("position", [0, 0, 0]), "yaw": 0.0}, "time_of_day": 12.0, "felled_trees": [], "economy": {"funds": 0, "axe_tier": "small", "workers": []}, "timber": {"logs": [], "burned": 0}, "horror": {"exposure": 0.0}}
	return data


static func apply_state(world: Node, data: Dictionary) -> void:
	for id in data.get("felled_trees", []):
		World.remove_tree(int(id))
	var env: Node = world.get("environment")
	if env:
		env.call("set_time_of_day", float(data.get("time_of_day", 12.0)))
	var p: Node3D = world.get("player")
	var pos: Array = data.get("player", {}).get("position", [])
	if p and pos.size() == 3:
		var target := Vector3(pos[0], pos[1], pos[2])
		target.y = maxf(target.y, World.height_at(target.x, target.z) + 0.1)
		p.call("teleport_feet", target, float(data.player.get("yaw", 0.0)))
