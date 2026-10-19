class_name EnemySpawner
extends Node
## Spawns enemies from the top of the field.
## - Regular waves: rate, wave size, stats and the share of strong enemies grow with time.
## - Boss schedule: each BossSpawn fires once when the clock passes its time. It does not
##   depend on regular waves (or auto_spawn) and ignores the enemy cap, so a boss always
##   appears on time; several overdue bosses (e.g. after a frame hitch) all spawn.

signal enemy_spawned(enemy: EnemyBase)
signal boss_spawned(enemy: EnemyBase, spawn: BossSpawn)

const ENEMY_SCENE := preload("res://scenes/units/enemy_unit.tscn")

@export var grunt_data: UnitData
@export var strong_data: UnitData
## Strong enemies start replacing grunts at this time...
@export var strong_start_time: float = 90.0
## ...with this much more chance per minute after that...
@export var strong_chance_per_minute: float = 0.06
## ...up to this share of a wave.
@export var strong_max_chance: float = 0.2
## Ordered by time.
@export var boss_schedule: Array[BossSpawn] = []
## When false, only explicit spawn_enemy() calls create enemies (used by tests).
@export var auto_spawn: bool = true
## Seconds between waves at 0:00.
@export var start_interval: float = 3.5
@export var min_interval: float = 1.3
@export var interval_reduction_per_minute: float = 0.35
## Enemy HP/attack multiplier added per minute (0.12 => x1.12 at 1:00).
@export var stat_growth_per_minute: float = 0.12
## One more enemy per wave every N seconds...
@export var extra_enemy_every: float = 70.0
## ...up to this many per wave.
@export var max_wave_size: int = 2
## Hard cap on simultaneously alive enemies (performance guard).
@export var max_alive: int = 60

## Stage difficulty applied to every enemy and boss (see apply_stage).
var enemy_stat_multiplier: float = 1.0
var active: bool = false

var _clock: BattleClock
var _layout: BattleLayout
var _units_parent: Node
var _effects: Node
var _base: BaseController
var _timer: float = 0.0
var _next_boss: int = 0


func setup(clock: BattleClock, layout: BattleLayout, units_parent: Node, effects: Node,
		base: BaseController) -> void:
	_clock = clock
	_layout = layout
	_units_parent = units_parent
	_effects = effects
	_base = base


func start() -> void:
	active = true
	_timer = 0.5  # First enemy shortly after start.


func stop() -> void:
	active = false


func current_interval() -> float:
	var minutes := _clock.elapsed / 60.0
	return maxf(min_interval, start_interval - interval_reduction_per_minute * minutes)


func current_wave_size() -> int:
	return mini(max_wave_size, 1 + floori(_clock.elapsed / extra_enemy_every))


## Copies a stage's enemy settings. Call before start().
func apply_stage(stage: StageData) -> void:
	enemy_stat_multiplier = stage.enemy_stat_multiplier
	start_interval = stage.start_interval
	min_interval = stage.min_interval
	interval_reduction_per_minute = stage.interval_reduction_per_minute
	stat_growth_per_minute = stage.stat_growth_per_minute
	strong_chance_per_minute = stage.strong_chance_per_minute
	strong_max_chance = stage.strong_max_chance
	max_wave_size = stage.max_wave_size
	boss_schedule = stage.boss_schedule.duplicate()


func current_stat_multiplier() -> float:
	return enemy_stat_multiplier * (1.0 + stat_growth_per_minute * (_clock.elapsed / 60.0))


func current_strong_chance() -> float:
	if strong_data == null or _clock.elapsed < strong_start_time:
		return 0.0
	return minf(strong_max_chance, strong_chance_per_minute * (_clock.elapsed - strong_start_time) / 60.0)


## The next boss still to appear, or null when all have appeared.
func get_next_boss() -> BossSpawn:
	return boss_schedule[_next_boss] if _next_boss < boss_schedule.size() else null


## Seconds until the next scheduled boss, or -1 when none is left.
func time_to_next_boss() -> float:
	if _next_boss >= boss_schedule.size():
		return -1.0
	return maxf(0.0, boss_schedule[_next_boss].time - _clock.elapsed)


func _physics_process(delta: float) -> void:
	if not active:
		return
	_spawn_due_bosses()
	if not auto_spawn or grunt_data == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer += current_interval()
	var strong_chance := current_strong_chance()
	for i in current_wave_size():
		var data := strong_data if randf() < strong_chance else grunt_data
		spawn_enemy(data, current_stat_multiplier())


func _spawn_due_bosses() -> void:
	while _next_boss < boss_schedule.size() and _clock.elapsed >= boss_schedule[_next_boss].time:
		var spawn := boss_schedule[_next_boss]
		_next_boss += 1
		var at := Vector2((_layout.left + _layout.right) * 0.5, _layout.spawn_y + spawn.unit_data.body_radius)
		var boss := spawn_enemy(spawn.unit_data, spawn.stat_multiplier * enemy_stat_multiplier, at, true)
		if boss != null:
			boss_spawned.emit(boss, spawn)


func spawn_enemy(unit_data: UnitData, stat_multiplier: float = 1.0,
		at: Vector2 = Vector2.INF, ignore_cap: bool = false) -> EnemyBase:
	if not active:
		return null
	if not ignore_cap and get_tree().get_node_count_in_group(&"enemies") >= max_alive:
		return null
	var enemy := ENEMY_SCENE.instantiate() as EnemyBase
	if at == Vector2.INF:
		at = Vector2(randf_range(_layout.left + 24.0, _layout.right - 24.0),
				_layout.spawn_y + randf_range(-6.0, 6.0))
	enemy.position = at
	enemy.setup_enemy(unit_data, _layout, _effects, _base, stat_multiplier)
	_units_parent.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy
