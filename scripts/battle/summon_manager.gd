class_name SummonManager
extends Node
## Player summoning: one slot per unit type in `roster`, each with its own cooldown.
## A summon succeeds only if the battle is running, the slot is off cooldown, there is
## room under the unit cap, and the wallet can pay cost x count in full.

signal unit_summoned(unit: UnitBase)
## Emitted after a successful summon of `count` units from slot `slot`.
signal summoned(slot: int, count: int)
signal summon_rejected(slot: int, reason: Reason)

enum Reason { OK, BATTLE_OVER, COOLDOWN, NOT_ENOUGH_COINS, UNIT_CAP, INVALID_SLOT }

const ALLY_SCENE := preload("res://scenes/units/ally_unit.tscn")
## Interval never drops below this, whatever the upgrades.
const MIN_INTERVAL := 1.0
const MAX_COUNT_PER_SUMMON := 5
const REASON_TEXT := {
	Reason.BATTLE_OVER: "戦闘は終了しています",
	Reason.COOLDOWN: "召喚待ち中",
	Reason.NOT_ENOUGH_COINS: "コインが足りません",
	Reason.UNIT_CAP: "味方の数が上限です",
	Reason.INVALID_SLOT: "召喚できません",
}

@export var roster: Array[UnitData] = []
@export var base_interval: float = 5.0
## Hard cap on simultaneously alive allies (performance guard).
@export var max_alive: int = 40

var active: bool = false
## Upgrade hooks (phase 3). Use set_count_per_summon() to change the count.
var interval_multiplier: float = 1.0
var count_per_summon: int = 1
## Ally stat upgrades. Use set_ally_multipliers() so living allies update too.
var ally_hp_multiplier: float = 1.0
var ally_attack_multiplier: float = 1.0
## Character level bonus per unit id (from the player's collection), e.g. {&"soldier": 1.16}.
var unit_level_bonus: Dictionary = {}

var _wallet: CoinWallet
var _layout: BattleLayout
var _units_parent: Node
var _effects: Node
var _cooldowns: Array[float] = []


func setup(wallet: CoinWallet, layout: BattleLayout, units_parent: Node, effects: Node) -> void:
	_wallet = wallet
	_layout = layout
	_units_parent = units_parent
	_effects = effects
	_cooldowns.resize(roster.size())
	_cooldowns.fill(0.0)


func start() -> void:
	active = true


func stop() -> void:
	active = false


func get_interval() -> float:
	return maxf(MIN_INTERVAL, base_interval * interval_multiplier)


func set_count_per_summon(count: int) -> void:
	count_per_summon = clampi(count, 1, MAX_COUNT_PER_SUMMON)


## Applies to future summons and to every ally already on the field.
func set_ally_multipliers(hp_multiplier: float, attack_multiplier: float) -> void:
	ally_hp_multiplier = hp_multiplier
	ally_attack_multiplier = attack_multiplier
	for node in get_tree().get_nodes_in_group(&"allies"):
		(node as Combatant).set_stat_multipliers(ally_hp_multiplier, ally_attack_multiplier)


func get_cooldown_remaining(slot: int) -> float:
	return _cooldowns[slot] if _is_valid_slot(slot) else 0.0


## 1.0 right after summoning, 0.0 when ready.
func get_cooldown_ratio(slot: int) -> float:
	return clampf(get_cooldown_remaining(slot) / get_interval(), 0.0, 1.0)


func get_free_capacity() -> int:
	return maxi(0, max_alive - get_tree().get_node_count_in_group(&"allies"))


## How many units the next summon from this slot would create.
func get_summon_count() -> int:
	return mini(count_per_summon, get_free_capacity())


## Total coins the next summon from this slot would cost.
func get_summon_cost(slot: int) -> int:
	if not _is_valid_slot(slot):
		return 0
	return roster[slot].summon_cost * maxi(1, get_summon_count())


func check_summon(slot: int) -> Reason:
	if not _is_valid_slot(slot):
		return Reason.INVALID_SLOT
	if not active:
		return Reason.BATTLE_OVER
	if _cooldowns[slot] > 0.0:
		return Reason.COOLDOWN
	if get_summon_count() <= 0:
		return Reason.UNIT_CAP
	if not _wallet.can_afford(get_summon_cost(slot)):
		return Reason.NOT_ENOUGH_COINS
	return Reason.OK


func try_summon(slot: int) -> Reason:
	var reason := check_summon(slot)
	if reason != Reason.OK:
		summon_rejected.emit(slot, reason)
		return reason
	var count := get_summon_count()
	if not _wallet.spend(roster[slot].summon_cost * count):
		summon_rejected.emit(slot, Reason.NOT_ENOUGH_COINS)
		return Reason.NOT_ENOUGH_COINS
	_cooldowns[slot] = get_interval()
	var center_x := randf_range(_layout.left + 40.0, _layout.right - 40.0)
	for i in count:
		var offset := (i - (count - 1) * 0.5) * 26.0
		summon(roster[slot], Vector2(_layout.clamp_x(center_x + offset, 16.0),
				_layout.ally_spawn_y + randf_range(-4.0, 4.0)))
	summoned.emit(slot, count)
	return Reason.OK


## Low-level spawn without cost or cooldown. Still refuses after the battle ends
## or when the unit cap is reached.
func summon(unit_data: UnitData, at: Vector2 = Vector2.INF) -> UnitBase:
	if not active or get_free_capacity() <= 0:
		return null
	var unit := ALLY_SCENE.instantiate() as UnitBase
	if at == Vector2.INF:
		at = Vector2(randf_range(_layout.left + 30.0, _layout.right - 30.0), _layout.ally_spawn_y)
	unit.position = at
	unit.setup_ally(unit_data, _layout, _effects, ally_hp_multiplier, ally_attack_multiplier,
			unit_level_bonus.get(unit_data.id, 1.0))
	_units_parent.add_child(unit)
	unit_summoned.emit(unit)
	return unit


func _physics_process(delta: float) -> void:
	if not active:
		return
	for i in _cooldowns.size():
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < roster.size() and roster[slot] != null
