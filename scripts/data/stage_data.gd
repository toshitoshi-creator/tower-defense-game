class_name StageData
extends Resource
## One stage: enemy pressure, boss schedule and clear rewards.

@export var id: String = "stage_1"
@export var display_name: String = "ステージ1"
@export_multiline var description: String = ""

@export_group("Enemies")
## Applied to every enemy and boss on top of the time-based growth.
@export var enemy_stat_multiplier: float = 1.0
@export var start_interval: float = 3.5
@export var min_interval: float = 1.3
@export var interval_reduction_per_minute: float = 0.35
@export var stat_growth_per_minute: float = 0.12
@export var strong_chance_per_minute: float = 0.06
@export var strong_max_chance: float = 0.2
@export var max_wave_size: int = 2
@export var boss_schedule: Array[BossSpawn] = []

@export_group("Rewards")
@export var clear_exp: int = 120
## Multiplies the coin segments of the clear roulette.
@export var roulette_coin_multiplier: float = 1.0

@export_group("Look")
@export var ground_tint: Color = Color.WHITE
