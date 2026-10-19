class_name CoinWallet
extends Node
## Battle-only coins. Lives inside the battle scene, so a retry or a new battle
## always starts from starting_coins. Never persisted.

signal coins_changed(coins: int)
## Emitted for every gain (kill rewards and passive income), after multipliers.
signal coins_earned(amount: int)

@export var starting_coins: int = 100
## Small trickle so a wiped-out army can always rebuild. 0 disables it.
@export var passive_income_per_second: float = 3.0

var coins: int = 0
var total_earned: int = 0
## Multiplier for kill rewards (coin-gain upgrade in phase 3).
var reward_multiplier: float = 1.0
var active: bool = false

var _passive_progress: float = 0.0


func _ready() -> void:
	reset()


func reset() -> void:
	coins = starting_coins
	total_earned = 0
	reward_multiplier = 1.0
	_passive_progress = 0.0
	coins_changed.emit(coins)


func can_afford(amount: int) -> bool:
	return amount >= 0 and coins >= amount


## Spends only if the full amount is available. Returns whether it was spent.
func spend(amount: int) -> bool:
	if not active or not can_afford(amount):
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


## Grants a kill reward with the current multiplier applied. Returns coins added.
func add_reward(base_reward: int) -> int:
	return _add(roundi(base_reward * reward_multiplier))


func _add(amount: int) -> int:
	if not active or amount <= 0:
		return 0
	coins += amount
	total_earned += amount
	coins_changed.emit(coins)
	coins_earned.emit(amount)
	return amount


func _physics_process(delta: float) -> void:
	if not active or passive_income_per_second <= 0.0:
		return
	_passive_progress += passive_income_per_second * delta
	if _passive_progress >= 1.0:
		var whole := floori(_passive_progress)
		_passive_progress -= whole
		_add(whole)
