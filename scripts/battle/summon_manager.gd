class_name SummonManager
extends Node
## Creates allied units in front of the base.
## Phase 1: allies deploy automatically on a timer (no coins yet).
## Phase 2 replaces auto-deploy with tap-to-summon, cost and per-unit cooldowns.

signal unit_summoned(unit: UnitBase)

const ALLY_SCENE := preload("res://scenes/units/ally_unit.tscn")

@export var auto_deploy_data: UnitData
## When false, only explicit summon() calls create allies (used by tests).
@export var auto_deploy: bool = true
@export var auto_deploy_interval: float = 2.6
## Hard cap on simultaneously alive allies (performance guard).
@export var max_alive: int = 40

var active: bool = false

var _layout: BattleLayout
var _units_parent: Node
var _effects: Node
var _timer: float = 0.0


func setup(layout: BattleLayout, units_parent: Node, effects: Node) -> void:
	_layout = layout
	_units_parent = units_parent
	_effects = effects


func start() -> void:
	active = true
	_timer = 0.3


func stop() -> void:
	active = false


func _physics_process(delta: float) -> void:
	if not active or not auto_deploy or auto_deploy_data == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer += auto_deploy_interval
		summon(auto_deploy_data)


func summon(unit_data: UnitData, at: Vector2 = Vector2.INF) -> UnitBase:
	if not active or get_tree().get_node_count_in_group(&"allies") >= max_alive:
		return null
	var unit := ALLY_SCENE.instantiate() as UnitBase
	if at == Vector2.INF:
		at = Vector2(randf_range(_layout.left + 30.0, _layout.right - 30.0), _layout.ally_spawn_y)
	unit.position = at
	unit.setup_ally(unit_data, _layout, _effects)
	_units_parent.add_child(unit)
	unit_summoned.emit(unit)
	return unit
