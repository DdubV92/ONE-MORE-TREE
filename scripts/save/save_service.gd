class_name SaveService
extends RefCounted
## Versioned campaign persistence (JSON, atomic write). Preview/review modes
## can never write here: every write goes through Game.can_write_campaign_save().
## Schema history and migration rules: docs/ARCHITECTURE.md "Save schema".

const SCHEMA_VERSION := 8
const DEFAULT_PATH := "user://saves/campaign.json"   # pre-Phase-3 single save
const SLOTS := 3

static var path_override := ""
static var slot := 1


## Campaign slots (Phase 3): user://saves/slot_N.json. Settings live in
## their own file (Settings autoload), never in a slot.
static func slot_path(n: int) -> String:
	return "user://saves/slot_%d.json" % clampi(n, 1, SLOTS)


static func save_path() -> String:
	return path_override if path_override != "" else slot_path(slot)


## One-line description of a slot for the title screen ("" if empty).
static func slot_summary(n: int) -> Dictionary:
	var path := slot_path(n)
	if not FileAccess.file_exists(path) and n == 1 and FileAccess.file_exists(DEFAULT_PATH):
		path = DEFAULT_PATH
	if not FileAccess.file_exists(path):
		return {}
	var d := read_file(path)
	if d.is_empty():
		return {"corrupt": true}
	var c: Dictionary = d.get("campaign", {})
	var cash := int(d.get("economy", {}).get("wallet", {}).get("cash", 0))
	return {"day": int(c.get("day", 1)), "rule_set": str(c.get("rule_set", "?")), "state": str(c.get("state", "")), "cash": cash, "pre_contract": not bool(c.get("phase3", false)), "legacy_file": path == DEFAULT_PATH}


## Where the player's body is saved: a seated player is saved standing
## at a verified spot (beside the truck door / in front of the couch), with
## the seat recorded so a couch load re-seats them in the real camper.
static func _player_record(p: Node3D) -> Dictionary:
	if p == null:
		return {"position": [0, 0, 0], "yaw": 0.0}
	var pos := p.global_position
	var seat := ""
	var seat_index := -1
	var veh: Node3D = p.get("vehicle")
	var couch: Node3D = p.get("couch")
	if veh is Truck:
		pos = (veh as Truck).door_point(-1.0)
		seat = "truck"
	elif p.get("hiding") != null:
		var hs: HideSpot = p.get("hiding")
		pos = hs.exit_point
		seat = "hide"
	elif couch:
		var fwd := -couch.global_basis.z
		fwd.y = 0.0
		pos = couch.global_position + fwd.normalized() * 0.6
		pos.y = couch.global_position.y - 0.55
		seat = "couch"
		seat_index = p.get_tree().get_nodes_in_group("couch_seat").find(couch)
	return {"position": [pos.x, pos.y, pos.z], "yaw": p.call("get_yaw") if p.has_method("get_yaw") else 0.0, "seat": seat, "seat_index": seat_index}


static func _phase5_record(world: Node) -> Dictionary:
	var out := {}
	for k in ["dog", "tv", "comfort", "arcade", "dock_site"]:
		var n: Object = world.get(k)
		if n and n.has_method("capture"):
			out[k] = n.call("capture")
	return out


static func _phase6_record(world: Node) -> Dictionary:
	var out := {}
	for k in ["director", "threat", "dog_rescue", "hunt"]:
		var n: Object = world.get(k)
		if n and n.has_method("capture"):
			out[k] = n.call("capture")
	return out


static func capture_state(world: Node) -> Dictionary:
	var p: Node3D = world.get("player")
	var env: Node = world.get("environment")
	var tree_service: TreeService = world.get("trees")
	var timber: TimberService = world.get("timber")
	var campaign: CampaignService = world.get("campaign")
	return {
		"schema": SCHEMA_VERSION,
		"world": {
			"seed": World.manifest.get("world_seed"),
			"generation_version": World.manifest.get("generation_version"),
		},
		"player": _player_record(p),
		# Phase 5: dog (identity, routine, pose), TV wall (mode, quad set,
		# scheduler, focus, volume/mute), camper comfort (lights, curtains),
		# arcade high scores, dock beacon state. Trucks live in campaign.vehicles.
		"phase5": _phase5_record(world),
		# Phase 6: director pacing/profile/history/source memory, ordinary
		# exposure, the once-only dog rescue state, and the hunt (mode, day,
		# continuous clock, dead/escaped people, Foreman pose/state/evidence,
		# ship). Dog identity/refuge lives in phase5.dog; worker life in payroll.
		"phase6": _phase6_record(world),
		# Phase 8: weather is a pure function of seed + day + clock; only the
		# seed and the smoothed cosmetic wetness are stored (no reroll on load).
		"phase8": {"weather": (world.get("weather") as Node).call("capture") if world.get("weather") else {}},
		"time_of_day": env.get("hour") if env else 12.0,
		# Modified original trees only, keyed by stable ID (state, notch work,
		# cut side, fall intent, felled guard, trunk pose/velocity).
		"trees": tree_service.capture() if tree_service else {},
		"equipment": {"axe_tier": p.axe.tier if p and p.get("axe") else "small"},
		# Reserved for later prompts (kept explicit so loaders know the shape):
		# Phase 3: clock, contract outcome, day stats and reports; wallet,
		# transaction ledger, payroll and owned equipment.
		"campaign": campaign.capture_campaign() if campaign else {"rule_set": CampaignRules.RULE_SET_ID, "state": "CONTRACT_ACTIVE", "day": 1, "clock_running": false, "legacy": false},
		"economy": campaign.capture_economy() if campaign else {"funds_cents": 0, "ledger": [], "workers": [], "trucks": []},
		# Phase 2 timber ledger: per-tree segment states/receipts/burn, cut
		# progress, world bodies (poses), carried bundle, queue, pit, receipts.
		"timber": timber.capture() if timber else {},
		"horror": {"exposure": 0.0},
		"build": Diag.version_string(),
	}


## Checkpoints (Phase 6) live beside the slot and never replace manual
## saves: "morning" (written each contract morning) and "survival" (each
## hunt dawn). Loading one copies it over the slot, an explained rollback.
static func checkpoint_path(kind: String) -> String:
	return save_path().get_basename() + ".%s.json" % kind


static func write_checkpoint(kind: String, state: Dictionary) -> bool:
	if not Game.can_write_campaign_save():
		return false
	return write_file(checkpoint_path(kind), state)


static func has_checkpoint(kind: String) -> bool:
	return FileAccess.file_exists(checkpoint_path(kind))


## Rolls the slot back to the checkpoint (the current slot is kept as .bak).
static func restore_checkpoint(kind: String) -> bool:
	var d := read_file(checkpoint_path(kind))
	if d.is_empty():
		return false
	return write_file(save_path(), d)


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
	if path_override == "" and slot == 1 and not FileAccess.file_exists(save_path()) and FileAccess.file_exists(DEFAULT_PATH):
		# The single pre-slot save becomes slot 1 (the old file is kept).
		DirAccess.make_dir_recursive_absolute(save_path().get_base_dir())
		DirAccess.copy_absolute(ProjectSettings.globalize_path(DEFAULT_PATH), ProjectSettings.globalize_path(save_path()))
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
		v = 3
	if v == 3:
		# Phase 2 saves: untimed, entitlements tracked but never paid. The
		# economy block is normalised; CampaignService credits each genuine
		# receipt once (marker: migrated_phase2_delivery) and asks the player
		# to pick legacy continuation or the new contract rules.
		var old_c: Dictionary = data.get("campaign", {})
		data["campaign"] = {"rule_set": str(old_c.get("rule_set", "pre_contract")), "state": "CONTRACT_ACTIVE", "day": 1, "phase3": false, "legacy": bool(old_c.get("legacy", false))}
		data["economy"] = {"wallet": {"cash": 0, "transactions": [], "credited": {}}, "payroll": {}, "equipment": {"axes": [], "equipped": ""}, "phase2_migrated": false, "legacy_axe_tier": str(data.get("equipment", {}).get("axe_tier", "small"))}
		data["schema"] = 4
		v = 4
	if v == 4:
		# Phase 3 saves: the crew block is added on load. Pending starting
		# employees are activated once by CrewService.migrate_pending (same
		# identities; wages only from days they actually work).
		data["schema"] = 5
		v = 5
	if v == 5:
		# Phase 4 saves: no trucks, dog/TV/comfort/arcade state. Defaults
		# apply (no trucks owned, dog in the yard, TV quad 1-4, high scores 0).
		data["phase5"] = {}
		data["schema"] = 6
		v = 6
	if v == 6:
		# Phase 5 saves: no director/rescue/hunt state yet. A save that is
		# sitting at the day-30 abandonment outcome enters the hunt on load
		# (rules card first), exactly once.
		data["phase6"] = {}
		data["schema"] = 7
		v = 7
	if v == 7:
		# Phase 7 saves: no weather block; the schedule is reconstructed from
		# the world seed and the restored clock, surfaces start dry.
		data["phase8"] = {}
		data["schema"] = 8
	return data


## Keeps an untouched copy of a pre-contract save before its first rules
## choice rewrites it.
static func backup_pre_contract() -> void:
	var path := save_path()
	var bak := path.get_basename() + ".pre_contract.json"
	if FileAccess.file_exists(path) and not FileAccess.file_exists(bak):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(bak))


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
	var campaign: CampaignService = world.get("campaign")
	if campaign and (Game.mode == Game.Mode.CAMPAIGN or campaign.test_route):
		if Game.mode == Game.Mode.CAMPAIGN and not bool(data.get("campaign", {}).get("phase3", false)):
			backup_pre_contract()
		campaign.restore(data.get("campaign", {}), data.get("economy", {}))
	var env: Node = world.get("environment")
	if env:
		env.call("set_time_of_day", float(data.get("time_of_day", 12.0)))
	var p: Node3D = world.get("player")
	var pos: Array = data.get("player", {}).get("position", [])
	if p and pos.size() == 3:
		var target := Vector3(pos[0], pos[1], pos[2])
		target.y = maxf(target.y, World.height_at(target.x, target.z) + 0.1)
		p.call("teleport_feet", target, float(data.player.get("yaw", 0.0)))
	# Phase 5/6 systems restore once they exist (crew/dock/TV/comfort/arcade).
	var p5: Dictionary = data.get("phase5", {})
	var p6: Dictionary = data.get("phase6", {})
	var p8: Dictionary = data.get("phase8", {})
	var hunt_n: Object = world.get("hunt")
	if hunt_n and str((p6.get("hunt", {}) as Dictionary).get("mode", "none")) != "none":
		hunt_n.set("pending_restore", true)
	var seat := str(data.get("player", {}).get("seat", ""))
	var seat_index := int(data.get("player", {}).get("seat_index", -1))
	if world.has_method("when_systems_ready"):
		world.call("when_systems_ready", func() -> void:
			for k in ["dog", "tv", "comfort", "arcade", "dock_site"]:
				var n: Object = world.get(k)
				if n and n.has_method("restore") and p5.has(k):
					n.call("restore", p5[k])
			for k in ["director", "threat", "hunt", "dog_rescue"]:
				var n6: Object = world.get(k)
				if n6 and n6.has_method("restore") and p6.has(k):
					n6.call("restore", p6[k])
			var wn: Object = world.get("weather")
			if wn and p8.has("weather"):
				wn.call("restore", p8["weather"])
			if seat == "couch" and p and p.has_method("sit_on_couch"):
				var seats := world.get_tree().get_nodes_in_group("couch_seat")
				if seat_index >= 0 and seat_index < seats.size():
					p.call("sit_on_couch", seats[seat_index]))
