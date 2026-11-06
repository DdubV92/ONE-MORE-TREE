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
##                  x skill (Phase 16 cutting skill, <= MAX_SKILL 1.35)
##                  x helmet (1.02/1.04/1.06)
##   cadence      = AXE_CYCLE / gloves (1.02/1.04/1.06)
##   then x fatigue (Phase 16 player restedness, 0.80..1.00) on work per
##   contact ONLY - never also on cadence, so it is applied once.
## Hard-working lives on OUTPUT (work per contact / saw rate), never on the
## animation speed, so it can't be applied twice.
## Chainsaw (per second of valid loaded contact at full chain speed):
##   rate = SAW_RATE x Hard-working x skill x fatigue   (helmet: axes only)
##   gloves shorten the start pull (handling), never the loaded cut rate.
## Walking: controller base x boots (1.03/1.06/1.09) x restedness walk
## (0.85..1.00, player only) x load x slope/water (controller's own).
## One item per slot, so each factor appears at most once; totals are also
## clamped (MAX_* below) in case a future source adds another factor.
## Phase 24: the shared Woodcutting skill (level 0-50, `wc_level`) adds
##   damage x(1 + 0.01 L) on work per contact / saw work per strike, and
##   speed  x(1 + 0.01 L) as an ACTION RATE: the axe cycle is divided by it
##   and the saw's strikes per second are multiplied by it.
## It replaces the Phase 16 merit cutting factor (`skill` is now 1.0 for
## cutting), so the two never stack. Stacking order (all multiplicative,
## rounded nowhere - work is a float; only XP and money are integers):
##   axe  work/contact = BASE x tier x Hard-working x WC damage x helmet x fatigue
##        cycle        = AXE_CYCLE / gloves / WC speed
##   saw  rate/s       = SAW_RATE x Hard-working x WC damage x WC speed x fatigue

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
## Phase 16: combined skill effect on any one action (career level adds
## nothing on top).
const MAX_SKILL := 1.35


## `who`: {"tool": "axe"|"chainsaw", "tier": axe tier, "hard_working": bool,
##         "boots": "", "gloves": "", "helmet": "", "skill": 1.0, "fatigue": 1.0}
static func breakdown(who: Dictionary) -> Dictionary:
	var tool := str(who.get("tool", "axe"))
	var tier := str(who.get("tier", "small"))
	var hw := HARD_WORKING if bool(who.get("hard_working", false)) else 1.0
	var skill := clampf(float(who.get("skill", 1.0)), 1.0, MAX_SKILL)
	var fatigue := clampf(float(who.get("fatigue", 1.0)), 0.5, 1.0)
	var rest_walk := clampf(float(who.get("rest_walk", 1.0)), 0.5, 1.0)
	var helmet := minf(1.0 + float(GearCatalog.HELMET_WORK.get(str(who.get("helmet", "")), 0.0)), MAX_HELMET)
	var gloves := minf(1.0 + float(GearCatalog.GLOVES_CADENCE.get(str(who.get("gloves", "")), 0.0)), MAX_CADENCE)
	var boots := minf(1.0 + float(GearCatalog.BOOTS_WALK.get(str(who.get("boots", "")), 0.0)), MAX_WALK)
	var wcl := clampi(int(who.get("wc_level", 0)), 0, Woodcutting.MAX_LEVEL)
	var wc_dmg := Woodcutting.damage_factor(wcl)
	var wc_spd := Woodcutting.speed_factor(wcl)
	var out := {
		"tool": tool, "tier": tier,
		"factors": {"tier": float(AXE_TIER.get(tier, 1.0)) if tool == "axe" else 1.0, "hard_working": hw, "skill": skill, "helmet": helmet if tool == "axe" else 1.0, "gloves": gloves, "fatigue": fatigue, "boots": boots, "rest_walk": rest_walk, "wc_level": wcl, "wc_damage": wc_dmg, "wc_speed": wc_spd},
		"walk_mult": boots * rest_walk,
	}
	if tool == "chainsaw":
		var rate := SAW_RATE * hw * skill * wc_dmg * wc_spd * fatigue
		out["saw_rate"] = rate
		out["work_per_second"] = rate
		out["start_s"] = SAW_START_S / gloves
		out["cycle_s"] = 0.0
		out["work_per_contact"] = rate * SAW_TICK
		out["vs_hatchet"] = rate / (BASE_WORK / AXE_CYCLE)
	else:
		var wpc := BASE_WORK * float(AXE_TIER.get(tier, 1.0)) * hw * skill * wc_dmg * helmet * fatigue
		var cyc := AXE_CYCLE / gloves / wc_spd
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
		if float(f.skill) != 1.0:
			lines.append("  x%.2f cutting skill" % float(f.skill))
		if int(f.get("wc_level", 0)) > 0:
			lines.append("  x%.2f Woodcutting %d damage, x%.2f speed" % [float(f.wc_damage), int(f.wc_level), float(f.wc_speed)])
		if float(f.fatigue) != 1.0:
			lines.append("  x%.2f tiredness (restedness)" % float(f.fatigue))
		lines.append("  start pull %.2f s%s" % [float(b.start_s), (" (gloves x%.2f quicker)" % float(f.gloves)) if float(f.gloves) > 1.0 else ""])
		lines.append("  helmet: no effect on the saw")
	else:
		lines.append("%s axe: %.2f work per hit, one hit every %.2f s = %.2f work/s (%.2fx hatchet)" % [str(b.tier).capitalize(), float(b.work_per_contact), float(b.cycle_s), float(b.work_per_second), float(b.vs_hatchet)])
		lines.append("  tier x%.2f%s%s%s%s%s%s" % [float(f.tier), ("  · Hard-working x%.2f" % float(f.hard_working)) if float(f.hard_working) != 1.0 else "", ("  · cutting skill x%.2f" % float(f.skill)) if float(f.skill) != 1.0 else "", ("  · Woodcutting %d: x%.2f dmg, x%.2f speed" % [int(f.wc_level), float(f.wc_damage), float(f.wc_speed)]) if int(f.get("wc_level", 0)) > 0 else "", ("  · helmet x%.2f" % float(f.helmet)) if float(f.helmet) != 1.0 else "", ("  · gloves cadence x%.2f" % float(f.gloves)) if float(f.gloves) != 1.0 else "", ("  · tired x%.2f" % float(f.fatigue)) if float(f.fatigue) != 1.0 else ""])
	if float(f.boots) != 1.0:
		lines.append("  boots: walking x%.2f" % float(f.boots))
	if float(f.rest_walk) != 1.0:
		lines.append("  tired: walking x%.2f" % float(f.rest_walk))
	return lines
