class_name GameCatalog
extends RefCounted
## Every rule and table of the meta game (outside battles) in one place:
## stages, characters, gacha, clear roulette, rank, permanent upgrades and shop.

const STAGES := [
	"res://resources/stages/stage_1.tres",
	"res://resources/stages/stage_2.tres",
]

const CHARACTERS := {
	"soldier": "res://resources/units/soldier.tres",
	"archer": "res://resources/units/archer.tres",
	"shield": "res://resources/units/shield.tres",
	"spearman": "res://resources/units/spearman.tres",
	"knight": "res://resources/units/knight.tres",
	"heavy": "res://resources/units/heavy.tres",
	"mage": "res://resources/units/mage.tres",
	"healer": "res://resources/units/healer.tres",
}
const STARTER_CHARACTERS := ["soldier", "archer", "shield"]
const DECK_SIZE := 3
const MAX_CHARACTER_LEVEL := 10
## Each character level above 1 adds this much HP and attack.
const LEVEL_BONUS_PER_LEVEL := 0.08

## Battle upgrades; the permanent upgrade screen levels the same items.
const UPGRADES := [
	"res://resources/upgrades/summon_speed.tres",
	"res://resources/upgrades/summon_count.tres",
	"res://resources/upgrades/ally_attack.tres",
	"res://resources/upgrades/ally_hp.tres",
	"res://resources/upgrades/base_hp.tres",
	"res://resources/upgrades/coin_gain.tres",
]
## Permanent price = round(base_cost * PERMANENT_COST_FACTOR * PERMANENT_COST_GROWTH ^ level).
const PERMANENT_COST_FACTOR := 5.0
const PERMANENT_COST_GROWTH := 1.6

## Gacha. Weights are percentages and are shown to the player as drop rates.
const GACHA_SINGLE_COST := 50
const GACHA_TEN_COST := 450
const GACHA_POOL := [
	{"id": "soldier", "rarity": "N", "weight": 20},
	{"id": "archer", "rarity": "N", "weight": 20},
	{"id": "shield", "rarity": "N", "weight": 20},
	{"id": "spearman", "rarity": "R", "weight": 12},
	{"id": "heavy", "rarity": "R", "weight": 10},
	{"id": "knight", "rarity": "R", "weight": 8},
	{"id": "mage", "rarity": "SR", "weight": 5},
	{"id": "healer", "rarity": "SR", "weight": 5},
]
## A duplicate of a max-level character turns into coins instead.
const DUPLICATE_OVERFLOW_COINS := 200

## Clear roulette segments. Coins are multiplied by the stage's roulette_coin_multiplier.
const ROULETTE := [
	{"coins": 100, "orbs": 0, "weight": 30},
	{"coins": 200, "orbs": 0, "weight": 25},
	{"coins": 300, "orbs": 0, "weight": 20},
	{"coins": 500, "orbs": 0, "weight": 12},
	{"coins": 1000, "orbs": 0, "weight": 6},
	{"coins": 0, "orbs": 30, "weight": 7},
]

## Orb packs. Prices are placeholders until real store products exist.
const SHOP_PRODUCTS := [
	{"id": "orbs_60", "orbs": 60, "price": "¥120"},
	{"id": "orbs_300", "orbs": 300, "price": "¥490"},
	{"id": "orbs_1000", "orbs": 1000, "price": "¥1,480"},
]


static func load_stage(stage_id: String) -> StageData:
	for path in STAGES:
		var stage := load(path) as StageData
		if stage.id == stage_id:
			return stage
	return null


static func stage_ids() -> Array[String]:
	var ids: Array[String] = []
	for path in STAGES:
		ids.append((load(path) as StageData).id)
	return ids


static func load_character(id: String) -> UnitData:
	return load(CHARACTERS[id]) as UnitData if CHARACTERS.has(id) else null


static func load_upgrades() -> Array[UpgradeData]:
	var list: Array[UpgradeData] = []
	for path in UPGRADES:
		list.append(load(path) as UpgradeData)
	return list


static func level_bonus(level: int) -> float:
	return 1.0 + LEVEL_BONUS_PER_LEVEL * (clampi(level, 1, MAX_CHARACTER_LEVEL) - 1)


static func exp_to_next_rank(rank: int) -> int:
	return 100 + 50 * (rank - 1)


## What reaching `new_rank` pays out.
static func rank_up_reward(new_rank: int) -> Dictionary:
	return {"coins": 200 + 50 * new_rank, "orbs": 50}


## Permanent levels stop at half the battle maximum, so in-battle upgrades still matter.
static func permanent_max_level(upgrade: UpgradeData) -> int:
	return maxi(1, floori(upgrade.max_level / 2.0))


static func permanent_cost(upgrade: UpgradeData, current_level: int) -> int:
	return roundi(upgrade.base_cost * PERMANENT_COST_FACTOR * pow(PERMANENT_COST_GROWTH, current_level))


static func pick_weighted(table: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for entry in table:
		total += int(entry["weight"])
	var roll := rng.randi_range(1, total)
	for i in table.size():
		roll -= int(table[i]["weight"])
		if roll <= 0:
			return i
	return table.size() - 1
