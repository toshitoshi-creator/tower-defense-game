class_name BattleManager
extends Node2D
## Owns the battle lifecycle and the win/lose decision. Child systems never reference
## this node; they emit signals and this node wires them together.
##
## End-of-battle priority: all end requests raised during the same frame are collected
## and resolved once at the end of that frame. VICTORY beats DEFEAT (if the final boss
## dies in the same frame the base falls, the player wins). The result is shown once.

signal battle_started
signal battle_ended(result: Result)

enum Result { VICTORY, DEFEAT }
enum Phase { READY, RUNNING, RESOLVING, ENDED }

var stage: StageData
## Victory rewards already granted to the player (empty on defeat).
var clear_rewards: Dictionary = {}
var roulette_segment: int = -1
var phase: Phase = Phase.READY
var result: Result = Result.DEFEAT
var layout := BattleLayout.new()
var kills: int = 0
var bosses_defeated: int = 0
var mid_bosses_defeated: int = 0
var final_boss_defeated: bool = false
var bosses_spawned: int = 0
## Living bosses, oldest first. The HUD bar tracks the final boss if present, else the oldest.
var active_bosses: Array[EnemyBase] = []

## How often summon buttons are refreshed (cooldown shade, affordability).
const UI_REFRESH_INTERVAL := 0.1
const TITLE_SCENE := "res://scenes/title/title.tscn"
const STAGE_SELECT_SCENE := "res://scenes/meta/stage_select.tscn"

## Pause between the deciding moment and the result panel, so the final explosion
## (or the base falling) is visible. Battle logic is already frozen during it.
@export var result_delay: float = 1.2

var _pending_results: Array[Result] = []
var _ui_refresh_timer: float = 0.0
var _shake_tween: Tween

@onready var clock: BattleClock = $BattleClock
@onready var wallet: CoinWallet = $CoinWallet
@onready var background: BattlefieldBackground = $Background
@onready var world: Node2D = $World
@onready var base: BaseController = $World/Base
@onready var units: Node2D = $World/Units
@onready var effects: Node2D = $World/Effects
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var summoner: SummonManager = $SummonManager
@onready var upgrades: BattleUpgradeManager = $BattleUpgradeManager
@onready var battle_ui: BattleUI = $BattleUI
@onready var result_ui: ResultUI = $ResultUI


func _ready() -> void:
	get_tree().paused = false
	stage = PlayerData.current.current_stage()
	spawner.apply_stage(stage)
	spawner.setup(clock, layout, units, effects, base)
	summoner.roster = PlayerData.current.deck_units()
	summoner.unit_level_bonus = PlayerData.current.level_bonuses()
	summoner.setup(wallet, layout, units, effects)
	upgrades.setup(wallet, summoner, base)
	upgrades.apply_starting_levels(PlayerData.current.permanent)
	background.modulate = stage.ground_tint
	battle_ui.set_stage_name("STAGE %d" % (GameCatalog.stage_ids().find(stage.id) + 1))
	battle_ui.setup_summon_buttons(summoner.roster)
	battle_ui.setup_upgrade_buttons(upgrades.upgrades)

	spawner.enemy_spawned.connect(_on_enemy_spawned)
	spawner.boss_spawned.connect(_on_boss_spawned)
	base.destroyed.connect(_on_base_destroyed)
	base.hp_changed.connect(battle_ui.set_base_hp)
	base.damaged.connect(_on_base_damaged)
	wallet.coins_changed.connect(_on_coins_changed)
	summoner.summoned.connect(_on_summoned)
	summoner.summon_rejected.connect(_on_summon_rejected)
	battle_ui.summon_slot_pressed.connect(request_summon)
	battle_ui.upgrade_pressed.connect(request_upgrade)
	upgrades.upgraded.connect(_on_upgraded)
	upgrades.upgrade_rejected.connect(_on_upgrade_rejected)
	clock.second_elapsed.connect(_on_second_elapsed)
	battle_ui.pause_requested.connect(set_paused.bind(true))
	battle_ui.resume_requested.connect(set_paused.bind(false))
	battle_ui.layout_changed.connect(_update_layout)
	result_ui.retry_requested.connect(retry)
	result_ui.title_requested.connect(go_to_title)
	result_ui.stage_select_requested.connect(go_to_stage_select)
	battle_ui.title_requested.connect(go_to_title)
	get_viewport().size_changed.connect(_update_layout)

	battle_ui.set_base_hp(base.hp, base.max_hp)
	battle_ui.set_coins(wallet.coins)
	_refresh_boss_countdown()
	_update_layout()
	start_battle()


func start_battle() -> void:
	if phase != Phase.READY:
		return
	phase = Phase.RUNNING
	clock.start()
	wallet.active = true
	spawner.start()
	summoner.start()
	upgrades.start()
	_refresh_summon_ui()
	battle_ui.show_banner("戦闘開始！", Color(1.0, 1.0, 0.9))
	battle_started.emit()


func is_running() -> bool:
	return phase == Phase.RUNNING


## Requests victory. Called when the final boss dies (also accepted during the
## frame the base falls, so a simultaneous kill still wins).
func notify_final_boss_defeated() -> void:
	_request_end(Result.VICTORY)


func _on_second_elapsed(_seconds: int) -> void:
	battle_ui.set_time(clock.elapsed)
	if active_bosses.is_empty():
		_refresh_boss_countdown()


func _on_boss_spawned(boss: EnemyBase, spawn: BossSpawn) -> void:
	bosses_spawned += 1
	active_bosses.append(boss)
	shake(5.0 if spawn.is_final else 3.0, 0.4)
	boss.damaged.connect(func(_c: Combatant, _a: int) -> void: _refresh_boss_bar())
	boss.defeated.connect(_on_boss_defeated.bind(spawn))
	battle_ui.show_banner(spawn.announce_text,
			Color(1.0, 0.8, 0.25) if spawn.is_final else Color(1.0, 0.4, 0.35))
	_refresh_boss_bar()


func _on_boss_defeated(boss: EnemyBase, _reward: int, spawn: BossSpawn) -> void:
	active_bosses.erase(boss)
	_refresh_boss_bar()
	if phase != Phase.RUNNING and phase != Phase.RESOLVING:
		return
	bosses_defeated += 1
	shake(6.0, 0.5)
	if spawn.is_final:
		final_boss_defeated = true
		notify_final_boss_defeated()
	else:
		mid_bosses_defeated += 1
		battle_ui.show_banner("中ボス撃破！", Color(0.6, 1.0, 0.6))


func _refresh_boss_bar() -> void:
	var shown: EnemyBase = null
	for boss in active_bosses:
		if is_instance_valid(boss) and boss.is_alive() and (shown == null or boss.data.max_hp > shown.data.max_hp):
			shown = boss
	if shown == null:
		_refresh_boss_countdown()
	else:
		battle_ui.show_boss_bar(shown.data.display_name, float(shown.hp) / float(shown.max_hp))


func _on_base_destroyed() -> void:
	_request_end(Result.DEFEAT)


func _request_end(requested: Result) -> void:
	if phase != Phase.RUNNING and phase != Phase.RESOLVING:
		return
	_pending_results.append(requested)
	if phase == Phase.RUNNING:
		phase = Phase.RESOLVING
		# Stop new spawns right away; the rest stops when the frame's requests resolve.
		clock.stop()
		wallet.active = false
		spawner.stop()
		summoner.stop()
		upgrades.stop()
		_resolve_end.call_deferred()


func _resolve_end() -> void:
	if phase != Phase.RESOLVING:
		return
	phase = Phase.ENDED
	result = Result.VICTORY if _pending_results.has(Result.VICTORY) else Result.DEFEAT
	_pending_results.clear()
	if result == Result.VICTORY:
		# Decided and saved now; the roulette on the result screen only shows it.
		roulette_segment = PlayerData.current.spin_roulette()
		clear_rewards = PlayerData.current.grant_clear_rewards(stage, roulette_segment)
	_freeze_field()
	battle_ui.set_upgrade_panel_open(false)
	battle_ui.set_time(clock.elapsed)
	battle_ui.show_banner("勝利！" if result == Result.VICTORY else "陣地陥落…",
			Color(1.0, 0.85, 0.3) if result == Result.VICTORY else Color(1.0, 0.4, 0.35))
	battle_ended.emit(result)
	# A tween (not a SceneTree timer) so a pending delay dies with this node.
	var delay := create_tween()
	delay.tween_interval(result_delay)
	delay.tween_callback(_show_result)


func _show_result() -> void:
	result_ui.show_result(result == Result.VICTORY, {
		"time": clock.elapsed,
		"kills": kills,
		"coins_earned": wallet.total_earned,
		"bosses_defeated": bosses_defeated,
		"mid_bosses_defeated": mid_bosses_defeated,
		"mid_bosses_total": _count_scheduled_bosses(false),
		"final_boss_defeated": final_boss_defeated,
	}, stage, roulette_segment, clear_rewards)


## Stops every unit and projectile, but lets death fades, popups and flashes finish
## (disabling the whole World would freeze them mid-animation).
func _freeze_field() -> void:
	for node in get_tree().get_nodes_in_group(&"projectiles"):
		node.queue_free()
	for node in get_tree().get_nodes_in_group(&"allies"):
		(node as Combatant).freeze()
	for node in get_tree().get_nodes_in_group(&"enemies"):
		if result == Result.VICTORY:
			(node as Combatant).vanish()  # The army routs once its king falls.
		else:
			(node as Combatant).freeze()
	base.settle(result == Result.DEFEAT)


func shake(strength: float, duration: float = 0.25) -> void:
	if _shake_tween != null and _shake_tween.is_running():
		return
	_shake_tween = create_tween()
	var steps := 6
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var offset := Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * strength * falloff
		_shake_tween.tween_callback(_set_shake_offset.bind(offset))
		_shake_tween.tween_interval(duration / steps)
	_shake_tween.tween_callback(_set_shake_offset.bind(Vector2.ZERO))


func _set_shake_offset(offset: Vector2) -> void:
	world.position = offset
	background.position = offset


func _refresh_boss_countdown() -> void:
	var next := spawner.get_next_boss()
	if next == null:
		battle_ui.show_boss_countdown("")
		return
	battle_ui.show_boss_countdown("%sまで %s" % ["最終ボス" if next.is_final else "中ボス",
			BattleClock.format_time(ceilf(spawner.time_to_next_boss()))])


func _count_scheduled_bosses(final: bool) -> int:
	var n := 0
	for spawn in spawner.boss_schedule:
		if spawn.is_final == final:
			n += 1
	return n


## Entry point for summon taps (UI) — the summon manager validates everything.
func request_summon(slot: int) -> SummonManager.Reason:
	if phase != Phase.RUNNING:
		_on_summon_rejected(slot, SummonManager.Reason.BATTLE_OVER)
		return SummonManager.Reason.BATTLE_OVER
	return summoner.try_summon(slot)


## Entry point for upgrade taps (UI) — the upgrade manager validates everything.
func request_upgrade(index: int) -> BattleUpgradeManager.Reason:
	if phase != Phase.RUNNING:
		_on_upgrade_rejected(index, BattleUpgradeManager.Reason.BATTLE_OVER)
		return BattleUpgradeManager.Reason.BATTLE_OVER
	return upgrades.try_upgrade(index)


func retry() -> void:
	get_tree().paused = false
	# Deferred: this runs from a button press, which must finish before its scene goes.
	get_tree().reload_current_scene.call_deferred()


func go_to_stage_select() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(STAGE_SELECT_SCENE)


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)


func set_paused(paused: bool) -> void:
	if paused and phase != Phase.RUNNING:
		return
	get_tree().paused = paused
	battle_ui.show_pause_overlay(paused)


func _notification(what: int) -> void:
	# Going to background (home button, incoming call, window focus loss) pauses the battle.
	# The player resumes explicitly, so time never jumps forward unnoticed.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_inside_tree() and phase == Phase.RUNNING:
			set_paused(true)


func _on_enemy_spawned(enemy: EnemyBase) -> void:
	enemy.defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy: EnemyBase, reward: int) -> void:
	if phase != Phase.RUNNING:
		return
	kills += 1
	battle_ui.set_kills(kills)
	var gained := wallet.add_reward(reward)
	if gained > 0:
		FloatingText.spawn(effects, enemy.global_position + Vector2(0, -28), "+%d" % gained,
				FloatingText.COLOR_COIN, 16)


func _on_coins_changed(coins: int) -> void:
	battle_ui.set_coins(coins)
	_refresh_summon_ui()


func _on_summoned(slot: int, _count: int) -> void:
	battle_ui.show_summon_result(slot, true)
	_refresh_summon_ui()


func _on_summon_rejected(slot: int, reason: SummonManager.Reason) -> void:
	battle_ui.show_summon_result(slot, false, SummonManager.REASON_TEXT.get(reason, ""))


func _on_upgraded(index: int, _level: int) -> void:
	battle_ui.show_upgrade_result(index, true, upgrades.describe_purchase(index))
	match upgrades.upgrades[index].effect:
		UpgradeData.Effect.ALLY_ATTACK, UpgradeData.Effect.ALLY_HP:
			# Show the boost on every ally it reached (FloatingText caps the count).
			for node in get_tree().get_nodes_in_group(&"allies"):
				FloatingText.spawn(effects, (node as Node2D).global_position + Vector2(0, -30), "UP",
						FloatingText.COLOR_UPGRADE)
		UpgradeData.Effect.BASE_HP:
			base.play_upgrade_flash()
	_refresh_summon_ui()


func _on_upgrade_rejected(index: int, reason: BattleUpgradeManager.Reason) -> void:
	battle_ui.show_upgrade_result(index, false, BattleUpgradeManager.REASON_TEXT.get(reason, ""))


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	_ui_refresh_timer -= delta
	if _ui_refresh_timer <= 0.0:
		_ui_refresh_timer = UI_REFRESH_INTERVAL
		_refresh_summon_ui()


func _refresh_summon_ui() -> void:
	for i in upgrades.upgrades.size():
		var level := upgrades.get_level(i)
		var cost := upgrades.get_next_cost(i)
		battle_ui.refresh_upgrade_button(i, upgrades.upgrades[i].display_name, level,
				upgrades.describe_level(i, level), upgrades.describe_level(i, level + 1),
				cost, cost >= 0 and wallet.can_afford(cost))
	for slot in summoner.roster.size():
		var cost := summoner.get_summon_cost(slot)
		battle_ui.refresh_summon_button(slot, cost, maxi(1, summoner.get_summon_count()),
				wallet.can_afford(cost), summoner.get_cooldown_ratio(slot),
				summoner.get_cooldown_remaining(slot))


func _on_base_damaged(_amount: int) -> void:
	battle_ui.flash_damage()
	shake(2.0, 0.15)


func _update_layout() -> void:
	var view := get_viewport_rect().size
	var top := battle_ui.get_field_top()
	var bottom := battle_ui.get_field_bottom()
	layout.left = 0.0
	layout.right = view.x
	layout.spawn_y = top + 14.0
	var base_top := bottom - BaseController.HEIGHT
	layout.base_line_y = base_top - 4.0
	layout.ally_spawn_y = base_top - 14.0
	layout.archer_home_y = layout.base_line_y - 30.0
	layout.guard_y = layout.base_line_y - 75.0
	layout.rally_y = layout.base_line_y - 125.0
	layout.archer_limit_y = layout.guard_y - 170.0
	layout.assault_limit_y = layout.guard_y - 300.0
	base.place(0.0, base_top, view.x)
	background.set_area(Rect2(0.0, 0.0, view.x, view.y), top, base_top)
