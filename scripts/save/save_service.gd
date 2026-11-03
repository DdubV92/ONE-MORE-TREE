class_name SaveService
extends RefCounted
## Versioned campaign persistence (JSON, atomic write). Preview/review modes
## can never write here: every write goes through Game.can_write_campaign_save().
## Schema history and migration rules: docs/ARCHITECTURE.md "Save schema".

const SCHEMA_VERSION := 3
const DEFAULT_PATH := "user://saves/campaign.json"

static var path_override := ""


static func save_path() -> String:
	return path_override if path_override != "" else DEFAULT_PATH


static func capture_state(world: Node) -> Dictionary:
	var p: Node3D = world.get("player")
	var env: Node = world.get("environment")
	var tree_service: TreeService = world.get("trees")
	var timber: TimberService = world.get("timber")
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
		# Modified original trees only, keyed by stable ID (state, notch work,
		# cut side, fall intent, felled guard, trunk pose/velocity).
		"trees": tree_service.capture() if tree_service else {},
		"equipment": {"axe_tier": p.axe.tier if p and p.get("axe") else "small"},
		# Reserved for later prompts (kept explicit so loaders know the shape):
		"campaign": {"rule_set": CampaignRules.RULE_SET_ID, "state": "CONTRACT_ACTIVE", "day": 1, "clock_running": false, "legacy": false},
		"economy": {"funds_cents": 0, "ledger": [], "workers": [], "trucks": []},
		# Phase 2 timber ledger: per-tree segment states/receipts/burn, cut
		# progress, world bodies (poses), carried bundle, queue, pit, receipts.
		"timber": timber.capture() if timber else {},
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
	# Keep the previous good save as a backup before replacing it.
	if FileAccess.file_exists(path) and not read_file_raw(path).is_empty():
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
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
	var data := read_file(save_path())
	if data.is_empty() and FileAccess.file_exists(save_path() + ".bak"):
		push_warning("SaveService: main save unreadable, using the previous good backup")
		data = read_file(save_path() + ".bak")
	return data


static func read_file_raw(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## Never deletes or overwrites an unreadable / newer save: it is ignored and
## left on disk for the player or a newer build.
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var raw := read_file_raw(path)
	if raw.is_empty():
		push_warning("SaveService: corrupt save ignored (left on disk): %s" % path)
		return {}
	return migrate(raw)


## Upgrades older saves; returns {} for unknown future schemas.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("schema", 0))
	if v > SCHEMA_VERSION:
		push_warning("SaveService: save schema %d is newer than this build (%d)" % [v, SCHEMA_VERSION])
		return {}
	if v == 0:
		# Pre-release dev saves stored only the player position.
		data = {"schema": 1, "world": {}, "player": {"position": data.get("position", [0, 0, 0]), "yaw": 0.0}, "time_of_day": 12.0, "felled_trees": [], "economy": {"funds": 0, "axe_tier": "small", "workers": []}, "timber": {"logs": [], "burned": 0}, "horror": {"exposure": 0.0}}
		v = 1
	if v == 1:
		# Phase 0 saves: free exploration, no tree states. They predate the
		# contract rule set, so they continue as a clearly labeled LEGACY
		# campaign (no deadline is started silently).
		var trees := {}
		for id in data.get("felled_trees", []):
			trees[str(int(id))] = {"id": int(id), "state": 3, "felled_committed": true}
		data["trees"] = trees
		data.erase("felled_trees")
		data["equipment"] = {"axe_tier": str(data.get("economy", {}).get("axe_tier", "small"))}
		data["campaign"] = {"rule_set": "legacy_phase0", "state": "CONTRACT_ACTIVE", "day": 1, "clock_running": false, "legacy": true}
		data["economy"] = {"funds_cents": 0, "ledger": [], "workers": [], "trucks": []}
		data["timber"] = {"segments": [], "accepted_shares": []}
		data["schema"] = 2
		v = 2
	if v == 2:
		# Phase 1 saves: fallen trunks exist only as tree poses. They are
		# adopted into timber records on load (TreeService FALLEN path); the
		# placeholder timber block carries no data.
		data["timber"] = {}
		data["schema"] = 3
	return data


static func apply_state(world: Node, data: Dictionary) -> void:
	# Timber records first (they only need the frozen world), then trees: a
	# SECTIONED tree then restores just its stump; a FALLEN (older) trunk is
	# adopted into a fresh record.
	var timber: TimberService = world.get("timber")
	if timber:
		timber.restore(data.get("timber", {}))
	var tree_service: TreeService = world.get("trees")
	if tree_service:
		tree_service.restore(data.get("trees", {}))
	if timber:
		timber.run_recovery()
	var p0: Node3D = world.get("player")
	if p0 and p0.get("axe"):
		p0.axe.equip(str(data.get("equipment", {}).get("axe_tier", "small")))
	var env: Node = world.get("environment")
	if env:
		env.call("set_time_of_day", float(data.get("time_of_day", 12.0)))
	var p: Node3D = world.get("player")
	var pos: Array = data.get("player", {}).get("position", [])
	if p and pos.size() == 3:
		var target := Vector3(pos[0], pos[1], pos[2])
		target.y = maxf(target.y, World.height_at(target.x, target.z) + 0.1)
		p.call("teleport_feet", target, float(data.player.get("yaw", 0.0)))
