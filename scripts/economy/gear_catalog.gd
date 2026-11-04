class_name GearCatalog
extends RefCounted
## Phase 14: every durable item the camp supplier stocks. Pure data, shared
## by the supplier app, the equipment screens, ToolEffects, orders and
## tests. Prices are PROVISIONAL (see docs/PHASE14_NOTES.md for how they
## were chosen against measured income and payroll).
##
## Kinds and slots:
##   axe       -> "tool" slot   tiers small / medium / large
##   chainsaw  -> "tool" slot   tier  saw
##   boots     -> "boots"       tiers t1 / t2 / t3   (+3/+6/+9 % walking)
##   gloves    -> "gloves"      tiers t1 / t2 / t3   (+2/+4/+6 % axe cadence,
##                                                    shorter saw start)
##   helmet    -> "helmet"      tiers t1 / t2 / t3   (+2/+4/+6 % axe work per hit)
## One item per slot; a higher tier REPLACES a lower one (never stacks).

const SLOTS := ["tool", "boots", "gloves", "helmet"]
const KINDS := ["axe", "chainsaw", "boots", "gloves", "helmet"]
## Per kind: at most one per human in camp (boss + five employees).
const STOCK_LIMIT := 6

const ITEMS := {
	"axe:small": {"kind": "axe", "tier": "small", "slot": "tool", "name": "Hatchet", "price": 0, "order": 0,
		"blurb": "Starting hatchet. x1.00 work per hit."},
	"axe:medium": {"kind": "axe", "tier": "medium", "slot": "tool", "name": "Felling axe", "price": 80000, "order": 1,
		"blurb": "x1.40 work per hit at the same swing cadence."},
	"axe:large": {"kind": "axe", "tier": "large", "slot": "tool", "name": "Heavy felling axe", "price": 180000, "order": 2,
		"blurb": "x1.96 work per hit at the same swing cadence. Slower wind-up, heavier bite."},
	"chainsaw:saw": {"kind": "chainsaw", "tier": "saw", "slot": "tool", "name": "Timberline 46 chainsaw", "price": 280000, "order": 3,
		"blurb": "Cuts continuously while the running chain is in the wood: about 4x a hatchet while cutting, about 3x over whole trees (start, spin-up). No fuel to buy."},
	"boots:t1": {"kind": "boots", "tier": "t1", "slot": "boots", "name": "Work boots", "price": 9000, "order": 10, "blurb": "+3 % walking speed."},
	"boots:t2": {"kind": "boots", "tier": "t2", "slot": "boots", "name": "Logger boots", "price": 20000, "order": 11, "blurb": "+6 % walking speed."},
	"boots:t3": {"kind": "boots", "tier": "t3", "slot": "boots", "name": "Caulked logger boots", "price": 40000, "order": 12, "blurb": "+9 % walking speed."},
	"gloves:t1": {"kind": "gloves", "tier": "t1", "slot": "gloves", "name": "Work gloves", "price": 5000, "order": 20, "blurb": "+2 % axe swing cadence; quicker saw start."},
	"gloves:t2": {"kind": "gloves", "tier": "t2", "slot": "gloves", "name": "Lined leather gloves", "price": 12000, "order": 21, "blurb": "+4 % axe swing cadence; quicker saw start."},
	"gloves:t3": {"kind": "gloves", "tier": "t3", "slot": "gloves", "name": "Anti-vibration gloves", "price": 25000, "order": 22, "blurb": "+6 % axe swing cadence; quicker saw start."},
	"helmet:t1": {"kind": "helmet", "tier": "t1", "slot": "helmet", "name": "Hard hat", "price": 7000, "order": 30, "blurb": "+2 % axe work per hit (camp morale bonus; axes only)."},
	"helmet:t2": {"kind": "helmet", "tier": "t2", "slot": "helmet", "name": "Forestry helmet", "price": 16000, "order": 31, "blurb": "+4 % axe work per hit (camp morale bonus; axes only)."},
	"helmet:t3": {"kind": "helmet", "tier": "t3", "slot": "helmet", "name": "Helmet with visor and muffs", "price": 32000, "order": 32, "blurb": "+6 % axe work per hit (camp morale bonus; axes only)."},
}

## Gear factors (fractions). Applied once each, see ToolEffects.
const BOOTS_WALK := {"": 0.0, "t1": 0.03, "t2": 0.06, "t3": 0.09}
const GLOVES_CADENCE := {"": 0.0, "t1": 0.02, "t2": 0.04, "t3": 0.06}
const HELMET_WORK := {"": 0.0, "t1": 0.02, "t2": 0.04, "t3": 0.06}


static func key(kind: String, tier: String) -> String:
	return "%s:%s" % [kind, tier]


static func def(k: String) -> Dictionary:
	return ITEMS.get(k, {})


static func slot_of(kind: String) -> String:
	return "tool" if kind in ["axe", "chainsaw"] else kind


static func price(kind: String, tier: String) -> int:
	return int(def(key(kind, tier)).get("price", 0))


static func display_name(kind: String, tier: String) -> String:
	return str(def(key(kind, tier)).get("name", "%s %s" % [tier, kind]))


## Tier rank for "better than" comparisons inside one kind.
static func rank(kind: String, tier: String) -> int:
	if kind == "axe":
		return ["small", "medium", "large"].find(tier)
	if kind == "chainsaw":
		return 10
	return ["t1", "t2", "t3"].find(tier)


## Supplier listing in display order.
static func listing() -> Array:
	var out := []
	for k in ITEMS:
		if int(ITEMS[k].price) > 0:
			out.append(k)
	out.sort_custom(func(a: String, b: String) -> bool: return int(ITEMS[a].order) < int(ITEMS[b].order))
	return out
