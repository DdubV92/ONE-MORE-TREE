class_name EconomyConfig
extends Resource
## Phase 3 economy tuning (config/economy.tres). Fixed contract terms come
## from CampaignRules ($100/tree, $300 wage); everything marked PROVISIONAL
## is a review value to be measured against real delivery income.

@export var starting_cash_cents := 200000          # PROVISIONAL $2,000
@export var wage_cents := 30000                    # fixed $300 per active employee-day
@export var hire_fee_cents := 100000               # PROVISIONAL $1,000 (Phase 4)
@export var axe_price_cents := {"small": 0, "medium": 150000, "large": 450000}   # PROVISIONAL
@export var truck_price_cents := 900000            # PROVISIONAL (Phase 5)
@export var truck_unlock_tree_equivalents := 50.0  # PROVISIONAL milestone (Phase 5)
@export var max_trucks := 2
