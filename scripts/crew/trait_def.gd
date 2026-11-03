class_name TraitDef
extends Resource
## One worker personality trait (data only; behaviour arrives in Prompt 4).
## Modifiers are compact and capped; combinations are one primary plus one
## secondary. No hidden multiplicative soup.

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var cut_rate_multiplier := 1.0       # hard-working: 1.25 (applied once)
@export var carry_multiplier := 1.0          # stronger: 1.5 (proposed)
@export var fear_tolerance := 1.0            # timid < 1
@export var fear_recovery := 1.0             # level-headed > 1
@export var dusk_return_bias_minutes := 0.0  # timid: leave earlier
@export var evidence_threshold := 1.0        # skeptical > 1
@export var perception := 1.0                # observant > 1 (within real limits)
@export var comfort_aura := 0.0              # sociable
@export var driving_smoothness := 1.0        # reliable driver
