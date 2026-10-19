class_name EnemySpawner
extends Node
## Spawns regular enemies from the top of the field. Spawn rate, enemy count per wave
## and enemy stats grow with battle time. (Boss schedule is added in phase 4.)

signal enemy_spawned(enemy: EnemyBase)

const ENEMY_SCENE := preload("res://scenes/units/enemy_unit.tscn")

@export var grunt_data: UnitData
## When false, only explicit spawn_enemy() calls create enemies (used by tests).
@export var auto_spawn: bool = true
## Seconds between waves at 0:00.
@export var start_interval: float = 2.4
@export var min_interval: float = 0.7
@export var interval_reduction_per_minute: float = 0.6
## Enemy HP/attack multiplier added per minute (0.25 => x1.25 at 1:00).
@export var stat_growth_per_minute: float = 0.25
## One more enemy per wave every N seconds.
@export var extra_enemy_every: float = 50.0
## Hard cap on simultaneously alive enemies (performance guard).
@export var max_alive: int = 60

var active: bool = false

var _clock: BattleClock
var _layout: BattleLayout
var _units_parent: Node
var _effects: Node
var _base: BaseController
var _timer: float = 0.0


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
	return 1 + floori(_clock.elapsed / extra_enemy_every)


func current_stat_multiplier() -> float:
	return 1.0 + stat_growth_per_minute * (_clock.elapsed / 60.0)


func _physics_process(delta: float) -> void:
	if not active or not auto_spawn or grunt_data == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer += current_interval()
	for i in current_wave_size():
		spawn_enemy(grunt_data, current_stat_multiplier())


func spawn_enemy(unit_data: UnitData, stat_multiplier: float = 1.0,
		at: Vector2 = Vector2.INF) -> EnemyBase:
	if not active or get_tree().get_node_count_in_group(&"enemies") >= max_alive:
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
