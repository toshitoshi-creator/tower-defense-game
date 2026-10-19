class_name UpgradeData
extends Resource
## One in-battle upgrade. Levels reset every battle (never persisted).

enum Effect { SUMMON_INTERVAL, SUMMON_COUNT, ALLY_ATTACK, ALLY_HP, BASE_HP, COIN_GAIN }

@export var id: StringName = &""
@export var display_name: String = ""
@export var effect: Effect = Effect.ALLY_ATTACK
@export var base_cost: int = 50
## Cost of the next level = round(base_cost * cost_growth ^ current_level).
@export var cost_growth: float = 1.5
@export var max_level: int = 5
## Meaning depends on effect: fraction for multipliers (0.15 = 15%), units for
## SUMMON_COUNT, durability points for BASE_HP.
@export var value_per_level: float = 0.15
