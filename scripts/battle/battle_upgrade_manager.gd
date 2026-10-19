class_name BattleUpgradeManager
extends Node
## All in-battle upgrades: levels, costs and how each level is applied.
## Levels live in the battle scene, so every new battle (and retry) starts at 0.

signal upgraded(index: int, level: int)
signal upgrade_rejected(index: int, reason: Reason)

enum Reason { OK, BATTLE_OVER, NOT_ENOUGH_COINS, MAX_LEVEL, INVALID }

const REASON_TEXT := {
	Reason.BATTLE_OVER: "戦闘は終了しています",
	Reason.NOT_ENOUGH_COINS: "コインが足りません",
	Reason.MAX_LEVEL: "これ以上強化できません",
	Reason.INVALID: "強化できません",
}

@export var upgrades: Array[UpgradeData] = []

var active: bool = false

var _levels: Array[int] = []
var _wallet: CoinWallet
var _summoner: SummonManager
var _base: BaseController


func setup(wallet: CoinWallet, summoner: SummonManager, base: BaseController) -> void:
	_wallet = wallet
	_summoner = summoner
	_base = base
	_levels.resize(upgrades.size())
	_levels.fill(0)


## Permanent upgrades: the battle begins with these levels already applied (free).
## `levels` maps upgrade id -> level.
func apply_starting_levels(levels: Dictionary) -> void:
	for i in upgrades.size():
		var target := mini(int(levels.get(str(upgrades[i].id), 0)), upgrades[i].max_level)
		while _levels[i] < target:
			_levels[i] += 1
			_apply(i)


func start() -> void:
	active = true


func stop() -> void:
	active = false


## The single place where upgrade prices are computed.
static func cost_for_level(upgrade: UpgradeData, current_level: int) -> int:
	return roundi(upgrade.base_cost * pow(upgrade.cost_growth, current_level))


func get_level(index: int) -> int:
	return _levels[index] if _is_valid(index) else 0


func is_maxed(index: int) -> bool:
	return _is_valid(index) and _levels[index] >= upgrades[index].max_level


## Price of the next level, or -1 when maxed.
func get_next_cost(index: int) -> int:
	if not _is_valid(index) or is_maxed(index):
		return -1
	return cost_for_level(upgrades[index], _levels[index])


func check_upgrade(index: int) -> Reason:
	if not _is_valid(index):
		return Reason.INVALID
	if not active:
		return Reason.BATTLE_OVER
	if is_maxed(index):
		return Reason.MAX_LEVEL
	if not _wallet.can_afford(get_next_cost(index)):
		return Reason.NOT_ENOUGH_COINS
	return Reason.OK


func try_upgrade(index: int) -> Reason:
	var reason := check_upgrade(index)
	if reason == Reason.OK and not _wallet.spend(get_next_cost(index)):
		reason = Reason.NOT_ENOUGH_COINS
	if reason != Reason.OK:
		upgrade_rejected.emit(index, reason)
		return reason
	_levels[index] += 1
	_apply(index)
	upgraded.emit(index, _levels[index])
	return Reason.OK


func _apply(index: int) -> void:
	var upgrade := upgrades[index]
	var level := _levels[index]
	match upgrade.effect:
		UpgradeData.Effect.SUMMON_INTERVAL:
			_summoner.interval_multiplier = _interval_multiplier(upgrade, level)
		UpgradeData.Effect.SUMMON_COUNT:
			_summoner.set_count_per_summon(1 + roundi(upgrade.value_per_level * level))
		UpgradeData.Effect.ALLY_ATTACK:
			_summoner.set_ally_multipliers(_summoner.ally_hp_multiplier, 1.0 + upgrade.value_per_level * level)
		UpgradeData.Effect.ALLY_HP:
			_summoner.set_ally_multipliers(1.0 + upgrade.value_per_level * level, _summoner.ally_attack_multiplier)
		UpgradeData.Effect.BASE_HP:
			# Adds to both max and current durability (one level's worth per purchase).
			_base.add_max_hp(roundi(upgrade.value_per_level))
		UpgradeData.Effect.COIN_GAIN:
			_wallet.reward_multiplier = 1.0 + upgrade.value_per_level * level


static func _interval_multiplier(upgrade: UpgradeData, level: int) -> float:
	return maxf(0.05, 1.0 - upgrade.value_per_level * level)


## Short player-facing description of the effect at `level`.
func describe_level(index: int, level: int) -> String:
	var upgrade := upgrades[index]
	match upgrade.effect:
		UpgradeData.Effect.SUMMON_INTERVAL:
			var seconds := maxf(SummonManager.MIN_INTERVAL,
					_summoner.base_interval * _interval_multiplier(upgrade, level))
			return "間隔%.1f秒" % seconds
		UpgradeData.Effect.SUMMON_COUNT:
			return "%d体ずつ" % mini(1 + roundi(upgrade.value_per_level * level), SummonManager.MAX_COUNT_PER_SUMMON)
		UpgradeData.Effect.ALLY_ATTACK, UpgradeData.Effect.ALLY_HP, UpgradeData.Effect.COIN_GAIN:
			return "+%d%%" % roundi(upgrade.value_per_level * level * 100.0)
		UpgradeData.Effect.BASE_HP:
			return "+%d" % roundi(upgrade.value_per_level * level)
	return ""


## Message shown right after buying a level, e.g. "攻撃力 Lv2：+30%".
func describe_purchase(index: int) -> String:
	return "%s Lv%d：%s" % [upgrades[index].display_name, _levels[index],
			describe_level(index, _levels[index])]


func _is_valid(index: int) -> bool:
	return index >= 0 and index < upgrades.size() and upgrades[index] != null
