class_name ToolEffects
extends RefCounted
## Phase 14: the ONE tool/gear/trait calculation. The player's axe and saw,
## every worker, the supplier comparison, the equipment screens, the debug
## breakdown and the tests all call `breakdown()`; nothing else multiplies
## cutting or walking output.
##
## Axes (per valid contact, at one common legal cadence):
##   work/contact = BASE_WORK x axe tier (1.00/1.40/1.96)
##                  x Hard-working (1.25, employees with the trait, ONCE)
##                  x skill (1.0: Phase 16 hook) x helmet (1.02/1.04/1.06)
##   cadence      = AXE_CYCLE / gloves (1.02/1.04/1.06)
##   then x fatigue (1.0: Phase 16 restedness hook) on work/contact.
## Hard-working lives on OUTPUT (work per contact / saw rate), never on the
## animation speed, so it can't be applied twice.
## Chainsaw (per second of valid loaded contact at full chain speed):
##   rate = SAW_RATE x Hard-working x skill x fatigue   (helmet: axes only)
##   gloves shorten the start pull (handling), never the loaded cut rate.
## Walking: controller base x boots (1.03/1.06/1.09) x load x slope/water
## (the controller's own factors, unchanged).
## One item per slot, so each factor appears at most once; totals are also
## clamped (MAX_* below) in case a future source adds another factor.

## Common legal swing cycle for every axe (s): the old small-axe cycle, so
## the 1.00/1.40/1.96 work per second of Phases 1-13 is preserved exactly.
const AXE_CYCLE := 0.95
const BASE_WORK := 1.0
const AXE_TIER := {"small": 1.0, "medium": 1.4, "large": 1.96}
const HARD_WORKING := 1.25
## Chainsaw loaded cutting, work units per second at full chain speed.
## 4.3 x the hatchet's continuous 1/0.95 units/s; measured over whole trees
## (spin-up per cut, start pull) it is ~3.2x (tools/tool_bench.tscn).
const SAW_RATE := 4.5
const SAW_START_S := 1.5          # pull + catch, before idle
const SAW_SPINUP_S := 0.3         # idle -> full chain speed under throttle
const SAW_SPINDOWN_S := 0.7
const SAW_STOP_S := 0.6
const SAW_REACH := 1.55           # m, camera to bar tip
const SAW_TICK := 0.1             # s: work is committed in fixed ticks
const SAW_MIN_RPM := 0.7          # chain must be at least this fast to cut
## Safety caps on the combined gear factors.
const MAX_WALK := 1.09
const MAX_CADENCE := 1.06
const MAX_HELMET := 1.06


## `who`: {"tool": "axe"|"chainsaw", "tier": axe tier, "hard_working": bool,
##         "boots": "", "gloves": "", "helmet": "", "skill": 1.0, "fatigue": 1.0}
static func breakdown(who: Dictionary) -> Dictionary:
	var tool := str(who.get("tool", "axe"))
	var tier := str(who.get("tier", "small"))
	var hw := HARD_WORKING if bool(who.get("hard_working", false)) else 1.0
	var skill := float(who.get("skill", 1.0))
	var fatigue := float(who.get("fatigue", 1.0))
	var helmet := minf(1.0 + float(GearCatalog.HELMET_WORK.get(str(who.get("helmet", "")), 0.0)), MAX_HELMET)
	var gloves := minf(1.0 + float(GearCatalog.GLOVES_CADENCE.get(str(who.get("gloves", "")), 0.0)), MAX_CADENCE)
	var boots := minf(1.0 + float(GearCatalog.BOOTS_WALK.get(str(who.get("boots", "")), 0.0)), MAX_WALK)
	var out := {
		"tool": tool, "tier": tier,
		"factors": {"tier": float(AXE_TIER.get(tier, 1.0)) if tool == "axe" else 1.0, "hard_working": hw, "skill": skill, "helmet": helmet if tool == "axe" else 1.0, "gloves": gloves, "fatigue": fatigue, "boots": boots},
		"walk_mult": boots,
	}
	if tool == "chainsaw":
		var rate := SAW_RATE * hw * skill * fatigue
		out["saw_rate"] = rate
		out["work_per_second"] = rate
		out["start_s"] = SAW_START_S / gloves
		out["cycle_s"] = 0.0
		out["work_per_contact"] = rate * SAW_TICK
		out["vs_hatchet"] = rate / (BASE_WORK / AXE_CYCLE)
	else:
		var wpc := BASE_WORK * float(AXE_TIER.get(tier, 1.0)) * hw * skill * helmet * fatigue
		var cyc := AXE_CYCLE / gloves
		out["work_per_contact"] = wpc
		out["cycle_s"] = cyc
		out["work_per_second"] = wpc / cyc
		out["vs_hatchet"] = (wpc / cyc) / (BASE_WORK / AXE_CYCLE)
	return out


## Human-readable lines for tooltips/debug: base, each factor, result.
static func describe(b: Dictionary) -> PackedStringArray:
	var f: Dictionary = b.factors
	var lines := PackedStringArray()
	if str(b.tool) == "chainsaw":
		lines.append("Chainsaw: %.2f work/s while the running chain is in the wood (%.1fx a hatchet's steady chopping)" % [float(b.saw_rate), float(b.vs_hatchet)])
		if float(f.hard_working) != 1.0:
			lines.append("  x%.2f Hard-working" % float(f.hard_working))
		lines.append("  start pull %.2f s%s" % [float(b.start_s), (" (gloves x%.2f quicker)" % float(f.gloves)) if float(f.gloves) > 1.0 else ""])
		lines.append("  helmet: no effect on the saw")
	else:
		lines.append("%s axe: %.2f work per hit, one hit every %.2f s = %.2f work/s (%.2fx hatchet)" % [str(b.tier).capitalize(), float(b.work_per_contact), float(b.cycle_s), float(b.work_per_second), float(b.vs_hatchet)])
		lines.append("  tier x%.2f%s%s%s" % [float(f.tier), ("  · Hard-working x%.2f" % float(f.hard_working)) if float(f.hard_working) != 1.0 else "", ("  · helmet x%.2f" % float(f.helmet)) if float(f.helmet) != 1.0 else "", ("  · gloves cadence x%.2f" % float(f.gloves)) if float(f.gloves) != 1.0 else ""])
	if float(f.boots) != 1.0:
		lines.append("  boots: walking x%.2f" % float(f.boots))
	return lines
