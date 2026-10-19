class_name BossSpawn
extends Resource
## One scheduled boss appearance.

## Battle time (seconds) at which the boss appears.
@export var time: float = 60.0
@export var unit_data: UnitData
## HP/attack multiplier for this appearance (later mid-bosses are tougher).
@export var stat_multiplier: float = 1.0
## Defeating the final boss wins the battle.
@export var is_final: bool = false
## Banner text shown when the boss appears.
@export var announce_text: String = "中ボス出現！"
