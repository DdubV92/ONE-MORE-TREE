class_name TreeWorkConfig
extends Resource
## Centralized felling tuning. Work is measured in "swing units": one valid
## contact with the small axe at rate 1.00 does exactly 1 unit. Larger tools
## and traits change work per SECOND (rate), never by stacking percentages.

## Axe tier cutting-speed multipliers (work per second relative to small).
@export var tier_rates := {"small": 1.0, "medium": 1.4, "large": 1.96}
## Phase 14: one common legal swing cycle for every axe (s). Gains come
## from work per valid hit (1.00/1.40/1.96); work per second is unchanged
## from Phases 1-13 (the old per-tier cycles were compensated in
## work_per_contact). ToolEffects.AXE_CYCLE is the same value.
@export var tier_cycle := {"small": 0.95, "medium": 0.95, "large": 0.95}
## Contact moment as a fraction of the cycle (damage only lands here).
@export var contact_fraction := 0.46
## Reference: small-axe units to fell a 0.5 m diameter pine.
@export var reference_units := 8.0
@export var reference_diameter := 0.5
@export var diameter_exponent := 1.8
## Species hardness multipliers: pine, spruce, birch.
@export var species_hardness := [1.0, 0.92, 0.78]
## Hard-working trait: applied exactly once to the effective rate.
@export var hard_working_multiplier := 1.25
## Notch geometry.
@export var cut_height := 0.75        # m above the grounded base
@export var max_notch_depth := 0.62   # fraction of diameter at release
@export var max_lean_deg := 25.0      # natural lean blended into fall direction


func effective_rate(tier: String, hard_working: bool = false) -> float:
	return float(tier_rates.get(tier, 1.0)) * (hard_working_multiplier if hard_working else 1.0)


## Work units added by ONE valid contact. Over a full cycle this gives
## work/second = rate / cycle_small, independent of frame rate.
func work_per_contact(tier: String, hard_working: bool = false) -> float:
	var base_cycle: float = tier_cycle["small"]
	return effective_rate(tier, hard_working) * float(tier_cycle.get(tier, base_cycle)) / base_cycle


func work_per_second(tier: String, hard_working: bool = false) -> float:
	return work_per_contact(tier, hard_working) / float(tier_cycle.get(tier, 1.0))


func required_units(species: int, radius: float) -> float:
	var d := radius * 2.0
	return reference_units * float(species_hardness[clampi(species, 0, 2)]) * pow(d / reference_diameter, diameter_exponent)
