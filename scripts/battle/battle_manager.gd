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

var phase: Phase = Phase.READY
var result: Result = Result.DEFEAT
var layout := BattleLayout.new()
var kills: int = 0
var bosses_defeated: int = 0

## How often summon buttons are refreshed (cooldown shade, affordability).
const UI_REFRESH_INTERVAL := 0.1

var _pending_results: Array[Result] = []
var _ui_refresh_timer: float = 0.0

@onready var clock: BattleClock = $BattleClock
@onready var wallet: CoinWallet = $CoinWallet
@onready var background: BattlefieldBackground = $Background
@onready var world: Node2D = $World
@onready var base: BaseController = $World/Base
@onready var units: Node2D = $World/Units
@onready var effects: Node2D = $World/Effects
@onready var spawner: EnemySpawner = $EnemySpawner
@onready var summoner: SummonManager = $SummonManager
@onready var battle_ui: BattleUI = $BattleUI
@onready var result_ui: ResultUI = $ResultUI


func _ready() -> void:
	get_tree().paused = false
	spawner.setup(clock, layout, units, effects, base)
	summoner.setup(wallet, layout, units, effects)
	battle_ui.setup_summon_buttons(summoner.roster)

	spawner.enemy_spawned.connect(_on_enemy_spawned)
	base.destroyed.connect(_on_base_destroyed)
	base.hp_changed.connect(battle_ui.set_base_hp)
	base.damaged.connect(_on_base_damaged)
	wallet.coins_changed.connect(_on_coins_changed)
	summoner.summoned.connect(_on_summoned)
	summoner.summon_rejected.connect(_on_summon_rejected)
	battle_ui.summon_slot_pressed.connect(request_summon)
	clock.second_elapsed.connect(func(_s: int) -> void: battle_ui.set_time(clock.elapsed))
	battle_ui.pause_requested.connect(set_paused.bind(true))
	battle_ui.resume_requested.connect(set_paused.bind(false))
	battle_ui.layout_changed.connect(_update_layout)
	result_ui.retry_requested.connect(retry)
	get_viewport().size_changed.connect(_update_layout)

	battle_ui.set_base_hp(base.hp, base.max_hp)
	battle_ui.set_coins(wallet.coins)
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
	_refresh_summon_ui()
	battle_started.emit()


func is_running() -> bool:
	return phase == Phase.RUNNING


## Hook for phase 4: called when the final boss dies.
func notify_final_boss_defeated() -> void:
	bosses_defeated += 1
	_request_end(Result.VICTORY)


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
		_resolve_end.call_deferred()


func _resolve_end() -> void:
	if phase != Phase.RESOLVING:
		return
	phase = Phase.ENDED
	result = Result.VICTORY if _pending_results.has(Result.VICTORY) else Result.DEFEAT
	_pending_results.clear()
	# Freeze every unit, attack and tween on the field.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	battle_ui.set_time(clock.elapsed)
	result_ui.show_result(result == Result.VICTORY, {
		"time": clock.elapsed,
		"kills": kills,
		"coins_earned": wallet.total_earned,
		"bosses_defeated": bosses_defeated,
	})
	battle_ended.emit(result)


## Entry point for summon taps (UI) — the summon manager validates everything.
func request_summon(slot: int) -> SummonManager.Reason:
	if phase != Phase.RUNNING:
		_on_summon_rejected(slot, SummonManager.Reason.BATTLE_OVER)
		return SummonManager.Reason.BATTLE_OVER
	return summoner.try_summon(slot)


func retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


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


func _process(delta: float) -> void:
	if phase != Phase.RUNNING:
		return
	_ui_refresh_timer -= delta
	if _ui_refresh_timer <= 0.0:
		_ui_refresh_timer = UI_REFRESH_INTERVAL
		_refresh_summon_ui()


func _refresh_summon_ui() -> void:
	for slot in summoner.roster.size():
		var cost := summoner.get_summon_cost(slot)
		battle_ui.refresh_summon_button(slot, cost, maxi(1, summoner.get_summon_count()),
				wallet.can_afford(cost), summoner.get_cooldown_ratio(slot),
				summoner.get_cooldown_remaining(slot))


func _on_base_damaged(_amount: int) -> void:
	battle_ui.flash_damage()


func _update_layout() -> void:
	var view := get_viewport_rect().size
	var top := battle_ui.get_field_top()
	var bottom := battle_ui.get_field_bottom()
	layout.left = 0.0
	layout.right = view.x
	layout.spawn_y = top + 14.0
	layout.ally_stop_y = top + 36.0
	var base_top := bottom - BaseController.HEIGHT
	layout.base_line_y = base_top - 4.0
	layout.ally_spawn_y = base_top - 14.0
	base.place(0.0, base_top, view.x)
	background.set_area(Rect2(0.0, 0.0, view.x, view.y), top, base_top)
