class_name PlayerData
extends Node
## Autoload "Player": the player's persistent progress, saved as JSON under user://.
## Game code reaches it as PlayerData.current (not through the autoload name, which
## isn't a compile-time identifier for scripts loaded before autoloads start).
## Battle-only state (battle coins, battle upgrades) never lives here.
##
## Currencies: coins (permanent upgrades) and orbs (gacha). Orbs are tracked as free
## (rewards) and paid (purchases) separately; spending uses free orbs first.

signal changed

static var current: PlayerData

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"

var save_path: String = DEFAULT_SAVE_PATH
var rank: int = 1
var rank_exp: int = 0
var coins: int = 0
var orbs_free: int = 0
var orbs_paid: int = 0
var cleared_stages: Array[String] = []
## Character id -> level (owned characters only).
var characters: Dictionary = {}
var deck: Array[String] = []
## Upgrade id -> permanent level.
var permanent: Dictionary = {}
## Purchase transaction ids already granted (a purchase is never granted twice).
var granted_transactions: Array[String] = []

## Not saved: the stage chosen on the stage select screen.
var current_stage_id: String = "stage_1"
var rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	current = self


func _ready() -> void:
	rng.randomize()
	load_game()


# ---------------------------------------------------------------- storage

## Switches to another save file (tests use their own) and loads it.
func use_storage(path: String) -> void:
	save_path = path
	load_game()


func reset_progress() -> void:
	_set_defaults()
	save_game()


func load_game() -> void:
	_set_defaults()
	if not FileAccess.file_exists(save_path):
		return
	var json := JSON.new()
	var ok := json.parse(FileAccess.get_file_as_string(save_path)) == OK
	var parsed: Variant = json.data if ok else null
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("[save] Save data unreadable; starting fresh.")
		return
	var d: Dictionary = parsed
	rank = maxi(1, int(d.get("rank", 1)))
	rank_exp = maxi(0, int(d.get("rank_exp", 0)))
	coins = maxi(0, int(d.get("coins", 0)))
	orbs_free = maxi(0, int(d.get("orbs_free", 0)))
	orbs_paid = maxi(0, int(d.get("orbs_paid", 0)))
	for id in d.get("cleared_stages", []):
		if str(id) in GameCatalog.stage_ids() and not cleared_stages.has(str(id)):
			cleared_stages.append(str(id))
	var saved_chars: Dictionary = d.get("characters", {}) if d.get("characters") is Dictionary else {}
	for id in saved_chars:
		if GameCatalog.CHARACTERS.has(str(id)):
			characters[str(id)] = clampi(int(saved_chars[id]), 1, GameCatalog.MAX_CHARACTER_LEVEL)
	var saved_perm: Dictionary = d.get("permanent", {}) if d.get("permanent") is Dictionary else {}
	for upgrade in GameCatalog.load_upgrades():
		permanent[str(upgrade.id)] = clampi(int(saved_perm.get(str(upgrade.id), 0)), 0,
				GameCatalog.permanent_max_level(upgrade))
	for t in d.get("granted_transactions", []):
		granted_transactions.append(str(t))
	var saved_deck: Array[String] = []
	for id in d.get("deck", []):
		saved_deck.append(str(id))
	if not set_deck(saved_deck, false):
		deck = _default_deck()


func save_game() -> void:
	var d := {
		"version": SAVE_VERSION,
		"rank": rank,
		"rank_exp": rank_exp,
		"coins": coins,
		"orbs_free": orbs_free,
		"orbs_paid": orbs_paid,
		"cleared_stages": cleared_stages,
		"characters": characters,
		"deck": deck,
		"permanent": permanent,
		"granted_transactions": granted_transactions,
	}
	# Write a temp file and rename it, so a crash mid-write never corrupts the save.
	var tmp := save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		printerr("[save] Could not write save data (%s)." % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(d))
	file.close()
	DirAccess.rename_absolute(tmp, save_path)
	changed.emit()


func _set_defaults() -> void:
	rank = 1
	rank_exp = 0
	coins = 0
	orbs_free = 0
	orbs_paid = 0
	cleared_stages.clear()
	characters.clear()
	for id in GameCatalog.STARTER_CHARACTERS:
		characters[id] = 1
	permanent.clear()
	for upgrade in GameCatalog.load_upgrades():
		permanent[str(upgrade.id)] = 0
	granted_transactions.clear()
	deck = _default_deck()


func _default_deck() -> Array[String]:
	var d: Array[String] = []
	d.assign(GameCatalog.STARTER_CHARACTERS)
	return d


# ---------------------------------------------------------------- currencies

func get_orbs() -> int:
	return orbs_free + orbs_paid


func add_coins(amount: int) -> void:
	coins += maxi(0, amount)


func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	return true


func add_orbs(amount: int, paid: bool = false) -> void:
	if paid:
		orbs_paid += maxi(0, amount)
	else:
		orbs_free += maxi(0, amount)


## Spends free orbs first. All or nothing.
func spend_orbs(amount: int) -> bool:
	if amount < 0 or get_orbs() < amount:
		return false
	var from_free := mini(orbs_free, amount)
	orbs_free -= from_free
	orbs_paid -= amount - from_free
	return true


# ---------------------------------------------------------------- rank and stages

## Adds rank EXP and pays rank-up rewards. Returns one {rank, coins, orbs} per rank gained.
func add_rank_exp(amount: int) -> Array[Dictionary]:
	var ups: Array[Dictionary] = []
	rank_exp += maxi(0, amount)
	while rank_exp >= GameCatalog.exp_to_next_rank(rank):
		rank_exp -= GameCatalog.exp_to_next_rank(rank)
		rank += 1
		var reward := GameCatalog.rank_up_reward(rank)
		add_coins(reward["coins"])
		add_orbs(reward["orbs"])
		ups.append({"rank": rank, "coins": reward["coins"], "orbs": reward["orbs"]})
	return ups


func is_stage_unlocked(stage_id: String) -> bool:
	var ids := GameCatalog.stage_ids()
	var index := ids.find(stage_id)
	if index <= 0:
		return index == 0
	return cleared_stages.has(ids[index - 1])


func is_stage_cleared(stage_id: String) -> bool:
	return cleared_stages.has(stage_id)


func current_stage() -> StageData:
	var stage := GameCatalog.load_stage(current_stage_id)
	return stage if stage != null else GameCatalog.load_stage("stage_1")


## Picks a roulette segment (the result is applied with grant_clear_rewards).
func spin_roulette() -> int:
	return GameCatalog.pick_weighted(GameCatalog.ROULETTE, rng)


func roulette_prize(segment: int, stage: StageData) -> Dictionary:
	var entry: Dictionary = GameCatalog.ROULETTE[segment]
	return {
		"coins": roundi(int(entry["coins"]) * stage.roulette_coin_multiplier),
		"orbs": int(entry["orbs"]),
	}


## Everything a victory pays, applied and saved at once. Returns
## {coins, orbs, exp, rank_ups, first_clear, unlocked_stage}.
func grant_clear_rewards(stage: StageData, roulette_segment: int) -> Dictionary:
	var prize := roulette_prize(roulette_segment, stage)
	add_coins(prize["coins"])
	add_orbs(prize["orbs"])
	var first_clear := not cleared_stages.has(stage.id)
	if first_clear:
		cleared_stages.append(stage.id)
	var ups := add_rank_exp(stage.clear_exp)
	save_game()
	var ids := GameCatalog.stage_ids()
	var next_index := ids.find(stage.id) + 1
	var unlocked := ""
	if first_clear and next_index < ids.size():
		unlocked = GameCatalog.load_stage(ids[next_index]).display_name
	return {"coins": prize["coins"], "orbs": prize["orbs"], "exp": stage.clear_exp,
			"rank_ups": ups, "first_clear": first_clear, "unlocked_stage": unlocked}


# ---------------------------------------------------------------- characters and deck

func owns(id: String) -> bool:
	return characters.has(id)


func character_level(id: String) -> int:
	return int(characters.get(id, 0))


## HP/attack multiplier per deck unit id, for the summon manager.
func level_bonuses() -> Dictionary:
	var out := {}
	for id in characters:
		out[StringName(id)] = GameCatalog.level_bonus(characters[id])
	return out


## Needs exactly DECK_SIZE different owned characters.
func set_deck(ids: Array[String], save: bool = true) -> bool:
	if ids.size() != GameCatalog.DECK_SIZE:
		return false
	var seen := {}
	for id in ids:
		if not owns(id) or seen.has(id):
			return false
		seen[id] = true
	deck = ids.duplicate()
	if save:
		save_game()
	return true


func deck_units() -> Array[UnitData]:
	var list: Array[UnitData] = []
	for id in deck:
		list.append(GameCatalog.load_character(id))
	return list


## Draws `count` characters if enough orbs. Each result: {id, rarity, new, level, coins}.
## Returns [] (and spends nothing) when orbs are short.
func draw_gacha(count: int) -> Array[Dictionary]:
	var cost := GameCatalog.GACHA_TEN_COST if count == 10 else GameCatalog.GACHA_SINGLE_COST * count
	var results: Array[Dictionary] = []
	if count <= 0 or not spend_orbs(cost):
		return results
	for i in count:
		var entry: Dictionary = GameCatalog.GACHA_POOL[GameCatalog.pick_weighted(GameCatalog.GACHA_POOL, rng)]
		var id: String = entry["id"]
		var result := {"id": id, "rarity": entry["rarity"], "new": false, "level": 1, "coins": 0}
		if not owns(id):
			characters[id] = 1
			result["new"] = true
		elif characters[id] < GameCatalog.MAX_CHARACTER_LEVEL:
			characters[id] += 1
		else:
			add_coins(GameCatalog.DUPLICATE_OVERFLOW_COINS)
			result["coins"] = GameCatalog.DUPLICATE_OVERFLOW_COINS
		result["level"] = characters[id]
		results.append(result)
	save_game()
	return results


# ---------------------------------------------------------------- permanent upgrades

func permanent_level(upgrade_id: String) -> int:
	return int(permanent.get(upgrade_id, 0))


## Price of the next permanent level, or -1 when maxed.
func permanent_next_cost(upgrade: UpgradeData) -> int:
	var level := permanent_level(str(upgrade.id))
	if level >= GameCatalog.permanent_max_level(upgrade):
		return -1
	return GameCatalog.permanent_cost(upgrade, level)


func buy_permanent(upgrade: UpgradeData) -> bool:
	var cost := permanent_next_cost(upgrade)
	if cost < 0 or not spend_coins(cost):
		return false
	permanent[str(upgrade.id)] = permanent_level(str(upgrade.id)) + 1
	save_game()
	return true


# ---------------------------------------------------------------- purchases

## Grants a completed store purchase once per transaction id. Returns false for
## unknown products or transactions already granted.
func grant_purchase(product_id: String, transaction_id: String) -> bool:
	if transaction_id.is_empty() or granted_transactions.has(transaction_id):
		return false
	for product in GameCatalog.SHOP_PRODUCTS:
		if product["id"] == product_id:
			add_orbs(int(product["orbs"]), true)
			granted_transactions.append(transaction_id)
			save_game()
			return true
	return false
