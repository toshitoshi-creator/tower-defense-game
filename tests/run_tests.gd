extends SceneTree
## Headless test runner for phase 1.
## Usage: godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## --fixed-fps 60 makes every physics frame exactly 1/60 s, so frame counts == game time.
## Exit code: 0 when all tests pass, 1 otherwise.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const SOLDIER: UnitData = preload("res://resources/units/soldier.tres")
const ARCHER: UnitData = preload("res://resources/units/archer.tres")
const SHIELD: UnitData = preload("res://resources/units/shield.tres")
const GRUNT: UnitData = preload("res://resources/enemies/grunt.tres")
const SLOT_SOLDIER := 0
const SLOT_ARCHER := 1
const SLOT_SHIELD := 2
const FPS := 60

var _failures: Array[String] = []
var _current := ""
var _battle: BattleManager


func _initialize() -> void:
	# Script mode starts with a tiny headless window; use the phone reference size.
	await process_frame
	root.size = Vector2i(390, 844)
	await process_frame
	var tests: Array[String] = []
	for m in get_method_list():
		var method_name: String = m["name"]
		if method_name.begins_with("test_"):
			tests.append(method_name)
	var filter := OS.get_cmdline_user_args()
	var passed := 0
	var failed := 0
	for test_name in tests:
		if not filter.is_empty() and not filter.has(test_name):
			continue
		_current = test_name
		var before := _failures.size()
		await call(test_name)
		await _teardown()
		if _failures.size() == before:
			passed += 1
			print("  PASS  ", test_name)
		else:
			failed += 1
			print("  FAIL  ", test_name)
	print("")
	for f in _failures:
		print("    - ", f)
	print("RESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_current, message])


## Creates a battle. With manual=true, automatic enemy spawning and passive income
## are off so the test controls exactly which units and coins exist.
func _start_battle(manual: bool = true) -> BattleManager:
	_battle = BATTLE_SCENE.instantiate() as BattleManager
	if manual:
		_battle.get_node("EnemySpawner").auto_spawn = false
		_battle.get_node("CoinWallet").passive_income_per_second = 0.0
	root.add_child(_battle)
	current_scene = _battle
	await _frames(2)
	return _battle


func _teardown() -> void:
	paused = false
	if _battle != null and is_instance_valid(_battle):
		_battle.queue_free()
	_battle = null
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(s: float) -> void:
	await _frames(roundi(s * FPS))


func _enemy(at: Vector2, data: UnitData = GRUNT) -> EnemyBase:
	return _battle.spawner.spawn_enemy(data, 1.0, at)


func _ally(at: Vector2, data: UnitData = SOLDIER) -> UnitBase:
	return _battle.summoner.summon(data, at)


func _count(group: StringName) -> int:
	return get_node_count_in_group(group)


# ---------------------------------------------------------------- tests

func test_battle_starts_and_clock_advances() -> void:
	var b := await _start_battle(false)
	_check(b.phase == BattleManager.Phase.RUNNING, "battle should be running")
	await _seconds(1.0)
	_check(b.clock.elapsed > 0.9 and b.clock.elapsed < 1.2, "clock ~1s, got %f" % b.clock.elapsed)


func test_auto_spawn_creates_enemies_but_no_free_allies() -> void:
	await _start_battle(false)
	await _seconds(5.0)
	_check(_count(&"enemies") > 0, "enemies should spawn automatically")
	_check(_count(&"allies") == 0, "allies only appear when the player summons")


func test_enemy_moves_down_and_ally_moves_up() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(40, b.layout.spawn_y))
	var ally := _ally(Vector2(350, b.layout.ally_spawn_y))
	var enemy_y := enemy.position.y
	var ally_y := ally.position.y
	await _seconds(1.0)
	_check(enemy.position.y > enemy_y + 20.0, "enemy should move down (%f -> %f)" % [enemy_y, enemy.position.y])
	_check(ally.position.y < ally_y - 20.0, "ally should move up (%f -> %f)" % [ally_y, ally.position.y])


func test_ally_stops_at_top_and_enemy_stops_at_base_line() -> void:
	var b := await _start_battle()
	var ally := _ally(Vector2(60, b.layout.ally_stop_y + 30.0))
	await _seconds(2.0)
	_check(is_equal_approx(ally.position.y, b.layout.ally_stop_y), "ally should hold at top line")
	_check(ally.state == Combatant.State.IDLE, "ally idles with no enemies")
	ally.take_damage(9999)
	await _frames(2)
	var enemy := _enemy(Vector2(330, b.layout.base_line_y - 30.0))
	await _seconds(2.0)
	_check(is_equal_approx(enemy.position.y, b.layout.base_line_y), "enemy should hold at base line")


func test_allies_hunt_enemies_that_slipped_past() -> void:
	var b := await _start_battle()
	var ally := _ally(Vector2(40, b.layout.ally_stop_y))
	var enemy := _enemy(Vector2(350, b.layout.base_line_y - 10.0))
	_check(ally.global_position.distance_to(enemy.global_position) > SOLDIER.aggro_range,
			"setup: enemy starts out of aggro range")
	await _seconds(20.0)
	_check(not is_instance_valid(enemy) or not enemy.is_alive(), "ally should chase down and kill the leaker")


func test_melee_units_damage_each_other() -> void:
	var b := await _start_battle()
	var y := 400.0
	var enemy := _enemy(Vector2(195, y - 30.0))
	var ally := _ally(Vector2(195, y + 30.0))
	await _seconds(2.5)
	_check(enemy.hp < enemy.max_hp, "ally should damage enemy")
	_check(ally.hp < ally.max_hp, "enemy should damage ally")
	_check(b.base.hp == b.base.max_hp, "base untouched while enemy is blocked")


func test_ally_kills_enemy_and_kill_counted_once() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, 380))
	_ally(Vector2(195, 420))
	var defeated_count := [0]
	enemy.defeated.connect(func(_e: EnemyBase, _r: int) -> void: defeated_count[0] += 1)
	await _seconds(8.0)
	_check(defeated_count[0] == 1, "defeated emitted once, got %d" % defeated_count[0])
	_check(b.kills == 1, "kills should be 1, got %d" % b.kills)
	_check(not is_instance_valid(enemy), "dead enemy should be freed after death animation")


func test_overlapping_lethal_hits_resolve_death_once() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, 300))
	var died_count := [0]
	var defeated_count := [0]
	var reward_total := [0]
	enemy.died.connect(func(_c: Combatant, _k: Node) -> void: died_count[0] += 1)
	enemy.defeated.connect(func(_e: EnemyBase, r: int) -> void:
		defeated_count[0] += 1
		reward_total[0] += r)
	# Three lethal hits in the same frame (e.g. several soldiers striking at once).
	var dealt_1 := enemy.take_damage(9999)
	var dealt_2 := enemy.take_damage(9999)
	var dealt_3 := enemy.take_damage(50)
	_check(dealt_1 == GRUNT.max_hp, "first hit deals remaining hp, got %d" % dealt_1)
	_check(dealt_2 == 0 and dealt_3 == 0, "hits on a dead unit deal 0")
	_check(died_count[0] == 1 and defeated_count[0] == 1, "death signals fire exactly once")
	_check(reward_total[0] == GRUNT.reward, "reward reported once (%d)" % reward_total[0])
	_check(enemy.hp == 0, "hp clamps at 0")
	_check(not enemy.is_in_group(&"enemies"), "dead enemy leaves targeting group immediately")
	await _frames(1)
	_check(b.kills == 1, "kill counted once, got %d" % b.kills)


func test_dead_units_stop_and_are_not_targeted() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, 380))
	var ally := _ally(Vector2(195, 420))
	await _seconds(0.5)
	_check(ally.target == enemy, "ally should target nearby enemy")
	var pos := enemy.position
	enemy.take_damage(9999)
	await _frames(2)
	_check(ally.target != enemy, "ally should drop dead target")
	if is_instance_valid(enemy):
		_check(enemy.position == pos, "dead enemy should not move")
		_check(not enemy.is_physics_processing(), "dead enemy stops processing")
	_check(b.kills == 1, "kill counted")


func test_damage_formula_uses_defense() -> void:
	_check(Combatant.compute_damage(15, 0) == 15, "no defense")
	_check(Combatant.compute_damage(15, 5) == 10, "defense subtracts")
	_check(Combatant.compute_damage(3, 10) == 1, "minimum damage 1")


func test_enemy_at_base_damages_base() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, b.layout.base_line_y - 5.0))
	var flashes := [0]
	b.base.damaged.connect(func(_a: int) -> void: flashes[0] += 1)
	await _seconds(3.0)
	_check(enemy.is_at_base(), "enemy reached base")
	_check(b.base.hp < b.base.max_hp, "base should lose durability")
	_check(b.base.hp == b.base.max_hp - flashes[0] * GRUNT.attack,
			"base loses enemy attack per hit (hp=%d hits=%d)" % [b.base.hp, flashes[0]])
	_check(b.battle_ui.base_hp_bar.value == b.base.hp, "HUD bar follows base hp")


func test_base_zero_hp_is_defeat_and_stops_battle() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(100, 300))
	var ally := _ally(Vector2(300, 600))
	var ended := [0]
	b.battle_ended.connect(func(_r: BattleManager.Result) -> void: ended[0] += 1)
	await _seconds(0.5)
	b.base.take_damage(b.base.hp)
	_check(b.base.hp == 0 and b.base.is_destroyed(), "base destroyed")
	await _frames(2)
	_check(b.phase == BattleManager.Phase.ENDED, "battle ended")
	_check(b.result == BattleManager.Result.DEFEAT, "result is defeat")
	_check(b.result_ui.shown_count == 1 and b.result_ui.panel.visible, "result shown once")
	_check(ended[0] == 1, "battle_ended emitted once")
	# Everything must be frozen now.
	var time_at_end := b.clock.elapsed
	var enemy_pos := enemy.position
	var ally_pos := ally.position
	var enemy_hp := enemy.hp
	b.spawner.auto_spawn = true
	b.wallet.passive_income_per_second = 5.0
	var coins_at_end := b.wallet.coins
	var enemies_before := _count(&"enemies")
	var allies_before := _count(&"allies")
	await _seconds(5.0)
	_check(b.clock.elapsed == time_at_end, "clock stopped")
	_check(enemy.position == enemy_pos and ally.position == ally_pos, "units frozen")
	_check(enemy.hp == enemy_hp, "no more damage")
	_check(_count(&"enemies") == enemies_before, "no new enemies")
	_check(_count(&"allies") == allies_before, "no new allies")
	_check(b.spawner.spawn_enemy(GRUNT) == null, "explicit spawn refused after end")
	_check(b.summoner.summon(SOLDIER) == null, "explicit summon refused after end")
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.BATTLE_OVER, "tap summon refused after end")
	_check(b.wallet.coins == coins_at_end, "no coins gained or spent after end")
	b.base.take_damage(100)
	b.notify_final_boss_defeated()
	await _frames(2)
	_check(b.result == BattleManager.Result.DEFEAT and b.result_ui.shown_count == 1,
			"later end requests are ignored")


func test_idle_player_eventually_loses() -> void:
	var b := await _start_battle(false)
	var limit := 4.0 * 60.0
	while b.phase != BattleManager.Phase.ENDED and b.clock.elapsed < limit:
		await _seconds(5.0)
	_check(b.result == BattleManager.Result.DEFEAT and b.phase == BattleManager.Phase.ENDED,
			"without summons the base should fall")
	print("        idle defeat at %s" % BattleClock.format_time(b.clock.elapsed))


func test_summoning_player_holds_and_earns_coins() -> void:
	# Simple bot: tap every ready, affordable slot (shield first, then soldier, archer).
	var b := await _start_battle(false)
	var order := [SLOT_SHIELD, SLOT_SOLDIER, SLOT_ARCHER]
	var limit := 8.0 * 60.0
	var peak_allies := 0
	while b.phase != BattleManager.Phase.ENDED and b.clock.elapsed < limit:
		for slot in order:
			if b.summoner.check_summon(slot) == SummonManager.Reason.OK:
				b.request_summon(slot)
		peak_allies = maxi(peak_allies, _count(&"allies"))
		await _seconds(0.5)
	print("        bot: ended=%s at %s, kills=%d, earned=%d, peak allies=%d" % [
			b.phase == BattleManager.Phase.ENDED, BattleClock.format_time(b.clock.elapsed),
			b.kills, b.wallet.total_earned, peak_allies])
	_check(b.clock.elapsed >= 150.0, "a summoning player should outlast an idle one (%.0fs)" % b.clock.elapsed)
	_check(b.kills >= 30, "bot army should kill enemies (%d)" % b.kills)
	_check(b.wallet.total_earned > 0, "coins earned")
	_check(peak_allies <= b.summoner.max_alive, "ally cap respected")


func test_summon_each_unit_type_spends_cost() -> void:
	var b := await _start_battle()
	b.wallet.coins = 200
	var expected := 200
	for slot in [SLOT_SOLDIER, SLOT_ARCHER, SLOT_SHIELD]:
		var data: UnitData = b.summoner.roster[slot]
		var before := _count(&"allies")
		_check(b.request_summon(slot) == SummonManager.Reason.OK, "%s summon OK" % data.id)
		expected -= data.summon_cost
		_check(b.wallet.coins == expected, "%s cost %d deducted (coins=%d)" % [data.id, data.summon_cost, b.wallet.coins])
		_check(_count(&"allies") == before + 1, "%s spawned" % data.id)
		var found := false
		for u in get_nodes_in_group(&"allies"):
			found = found or (u as UnitBase).data == data
		_check(found, "%s unit present" % data.id)
	_check(SOLDIER.summon_cost == 20 and ARCHER.summon_cost == 30 and SHIELD.summon_cost == 25, "spec costs")
	_check(SOLDIER.max_hp == 100 and ARCHER.max_hp == 55 and SHIELD.max_hp == 220, "spec hp")
	_check(SOLDIER.attack == 15 and ARCHER.attack == 20 and SHIELD.attack == 6, "spec attack")
	_check(is_equal_approx(ARCHER.attack_interval, 1.3) and is_equal_approx(SHIELD.attack_interval, 1.2),
			"spec attack intervals")
	_check(ARCHER.move_speed < SOLDIER.move_speed and SHIELD.move_speed < SOLDIER.move_speed, "slower archer/shield")


func test_summon_refused_without_coins() -> void:
	var b := await _start_battle()
	b.wallet.coins = SOLDIER.summon_cost - 1
	var reasons := []
	b.summoner.summon_rejected.connect(func(_s: int, r: SummonManager.Reason) -> void: reasons.append(r))
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.NOT_ENOUGH_COINS, "refused for coins")
	_check(_count(&"allies") == 0, "no unit spawned")
	_check(b.wallet.coins == SOLDIER.summon_cost - 1, "coins untouched")
	_check(reasons == [SummonManager.Reason.NOT_ENOUGH_COINS], "rejection signalled once")
	_check(b.battle_ui.toast.visible and b.battle_ui.toast.text == "コインが足りません", "reason shown to player")
	_check(b.summoner.get_cooldown_remaining(SLOT_SOLDIER) == 0.0, "failed summon does not start cooldown")


func test_summon_cooldown_per_slot() -> void:
	var b := await _start_battle()
	b.wallet.coins = 500
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.OK, "first summon")
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.COOLDOWN, "second summon blocked by cooldown")
	_check(b.battle_ui.toast.text == "召喚待ち中", "cooldown reason shown")
	_check(b.request_summon(SLOT_ARCHER) == SummonManager.Reason.OK, "other slots have their own cooldown")
	_check(is_equal_approx(b.summoner.get_interval(), 5.0), "initial interval 5s")
	await _seconds(4.8)
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.COOLDOWN, "still cooling at 4.8s")
	await _seconds(0.3)
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.OK, "ready after 5s")
	b.summoner.interval_multiplier = 0.01
	_check(b.summoner.get_interval() == SummonManager.MIN_INTERVAL, "interval floor")


func test_multi_summon_cost_and_cap() -> void:
	var b := await _start_battle()
	b.summoner.set_count_per_summon(3)
	_check(b.summoner.get_summon_cost(SLOT_SOLDIER) == 60, "3 soldiers cost 60")
	b.wallet.coins = 59
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.NOT_ENOUGH_COINS, "partial funds refused")
	_check(_count(&"allies") == 0 and b.wallet.coins == 59, "nothing spent or spawned")
	b.wallet.coins = 60
	_check(b.request_summon(SLOT_SOLDIER) == SummonManager.Reason.OK, "full funds accepted")
	_check(_count(&"allies") == 3 and b.wallet.coins == 0, "3 spawned, 60 spent")
	b.summoner.max_alive = 5
	b.wallet.coins = 1000
	_check(b.summoner.get_summon_count() == 2, "count limited by cap")
	_check(b.request_summon(SLOT_SHIELD) == SummonManager.Reason.OK, "summon up to cap")
	_check(_count(&"allies") == 5 and b.wallet.coins == 1000 - 2 * SHIELD.summon_cost, "only spawned units paid")
	_check(b.request_summon(SLOT_ARCHER) == SummonManager.Reason.UNIT_CAP, "cap reached")
	b.summoner.set_count_per_summon(99)
	_check(b.summoner.count_per_summon == SummonManager.MAX_COUNT_PER_SUMMON, "count clamped")


func test_archer_shoots_arrows_from_range() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, 300))
	enemy.data = GRUNT.duplicate()
	enemy.data.move_speed = 0.0  # Stationary target.
	var archer := _ally(Vector2(195, 300 + 110), ARCHER)
	var saw_projectile := false
	var hits := []
	enemy.damaged.connect(func(_c: Combatant, amount: int) -> void: hits.append(amount))
	for i in 150:
		await physics_frame
		for child in b.effects.get_children():
			saw_projectile = saw_projectile or child is Projectile
	_check(saw_projectile, "archer fired a projectile")
	_check(hits.size() >= 1, "arrow hit the enemy")
	_check(hits.all(func(h: int) -> bool: return h == ARCHER.attack), "each arrow deals archer attack")
	_check(archer.position.distance_to(enemy.position) > 60.0, "archer stays at range (dist %.0f)" % archer.position.distance_to(enemy.position))


func test_arrow_in_flight_when_target_dies_does_nothing() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, 200))
	var proj := (load(Combatant.PROJECTILE_SCENE_PATH) as PackedScene).instantiate() as Projectile
	b.effects.add_child(proj)
	proj.launch(Vector2(195, 600), enemy, 999, 200.0, null)
	enemy.take_damage(9999)
	await _seconds(2.5)
	_check(not is_instance_valid(proj), "projectile cleaned up")
	_check(b.kills == 1, "kill counted once")


func test_shield_defense_reduces_damage() -> void:
	await _start_battle()
	var shield := _ally(Vector2(195, 400), SHIELD)
	_check(shield.take_damage(GRUNT.attack) == GRUNT.attack - SHIELD.defense, "defense applied")


func test_kill_reward_paid_once_with_many_attackers() -> void:
	var b := await _start_battle()
	b.wallet.coins = 0
	var enemy := _enemy(Vector2(195, 380))
	enemy.max_hp = 300
	enemy.hp = 300
	for i in 3:
		_ally(Vector2(150 + i * 40, 420))
		_ally(Vector2(150 + i * 40, 500), ARCHER)
	await _seconds(8.0)
	_check(not is_instance_valid(enemy) or not enemy.is_alive(), "enemy died")
	_check(b.kills == 1, "one kill")
	_check(b.wallet.coins == GRUNT.reward and b.wallet.total_earned == GRUNT.reward,
			"reward paid exactly once (coins=%d)" % b.wallet.coins)
	var enemy2 := _enemy(Vector2(60, 200))
	enemy2.take_damage(9999)
	await _frames(1)
	var popup := false
	for child in b.effects.get_children():
		popup = popup or (child is FloatingText and (child as Label).text == "+%d" % GRUNT.reward)
	_check(popup, "coin popup shown at the kill")


func test_coin_hud_and_reset_values() -> void:
	var b := await _start_battle()
	_check(b.wallet.coins == b.wallet.starting_coins, "battle starts with starting coins")
	_check(b.battle_ui.coin_label.text == "● %d" % b.wallet.coins, "HUD shows coins")
	b.wallet.add_reward(12)
	_check(b.battle_ui.coin_label.text == "● %d" % (b.wallet.starting_coins + 12), "HUD updates")
	b.wallet.reward_multiplier = 1.5
	_check(b.wallet.add_reward(5) == 8, "reward multiplier rounds")


func test_passive_income_and_stops_after_end() -> void:
	var b := await _start_battle()
	b.wallet.passive_income_per_second = 3.0
	var start := b.wallet.coins
	await _seconds(2.0)
	_check(b.wallet.coins - start >= 5 and b.wallet.coins - start <= 7, "~3 coins/s (got %d)" % (b.wallet.coins - start))
	b.base.take_damage(b.base.hp)
	await _frames(2)
	var at_end := b.wallet.coins
	await _seconds(2.0)
	_check(b.wallet.coins == at_end, "no income after battle end")
	_check(b.wallet.add_reward(100) == 0, "no rewards after battle end")


func test_tapping_summon_button_summons() -> void:
	var b := await _start_battle()
	await _tap(Vector2(195, 400))
	_check(_count(&"allies") == 0, "tapping the battlefield summons nothing")
	await _tap(b.battle_ui.summon_buttons[SLOT_SHIELD].get_global_rect().get_center())
	_check(_count(&"allies") == 1, "touch on shield button summons one unit")
	var unit := get_first_node_in_group(&"allies") as UnitBase
	_check(unit != null and unit.data == SHIELD, "it is a shield")


func _tap(at: Vector2) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = true
	# Goes through the same path as a real finger (touch -> emulated mouse -> Button).
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await process_frame
	var release := touch.duplicate() as InputEventScreenTouch
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await _frames(2)


func test_victory_beats_defeat_in_same_frame() -> void:
	var b := await _start_battle()
	b.base.take_damage(b.base.hp)
	b.notify_final_boss_defeated()
	await _frames(2)
	_check(b.result == BattleManager.Result.VICTORY, "victory has priority")
	_check(b.result_ui.shown_count == 1, "result shown once")
	await _teardown()
	b = await _start_battle()
	b.notify_final_boss_defeated()
	b.base.take_damage(b.base.hp)
	await _frames(2)
	_check(b.result == BattleManager.Result.VICTORY, "victory has priority (reverse order)")
	_check(b.result_ui.shown_count == 1, "result shown once (reverse order)")


func test_unit_caps() -> void:
	var b := await _start_battle()
	b.spawner.max_alive = 5
	b.summoner.max_alive = 4
	for i in 10:
		_enemy(Vector2(20 + i * 30, 120))
		_ally(Vector2(20 + i * 30, 650))
	_check(_count(&"enemies") == 5, "enemy cap, got %d" % _count(&"enemies"))
	_check(_count(&"allies") == 4, "ally cap, got %d" % _count(&"allies"))


func test_pause_on_background_and_resume() -> void:
	var b := await _start_battle(false)
	await _seconds(0.5)
	b._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(paused, "tree paused when app goes to background")
	_check(b.battle_ui.pause_overlay.visible, "pause overlay shown")
	var t := b.clock.elapsed
	await _seconds(1.0)
	_check(b.clock.elapsed == t, "clock frozen while paused")
	b.battle_ui.resume_button.pressed.emit()
	_check(not paused, "resume button unpauses")
	_check(not b.battle_ui.pause_overlay.visible, "overlay hidden")
	await _seconds(0.5)
	_check(b.clock.elapsed > t, "clock resumes")
	b.battle_ui.pause_button.pressed.emit()
	_check(paused, "pause button pauses")
	b.set_paused(false)


func test_ui_fits_various_portrait_screens() -> void:
	var sizes := [Vector2i(390, 844), Vector2i(320, 568), Vector2i(360, 640),
			Vector2i(414, 896), Vector2i(430, 932), Vector2i(768, 1024)]
	var b := await _start_battle()
	for s in sizes:
		root.size = s
		await _frames(3)
		var view := b.get_viewport_rect()
		var top := b.battle_ui.top_bar.get_global_rect()
		var bottom := b.battle_ui.bottom_panel.get_global_rect()
		var label := "%dx%d" % [s.x, s.y]
		_check(view.encloses(top) and view.encloses(bottom), "%s: bars inside screen" % label)
		_check(view.encloses(b.battle_ui.pause_button.get_global_rect()), "%s: pause button visible" % label)
		_check(b.battle_ui.pause_button.size.y >= 44.0, "%s: pause button >= 44px" % label)
		var field_h := b.layout.base_line_y - b.layout.spawn_y
		_check(field_h > view.size.y * 0.6, "%s: battlefield keeps >60%% of height (%d)" % [label, field_h])
		_check(is_equal_approx(b.layout.right, view.size.x), "%s: field spans width" % label)
		_check(b.base.position.y + BaseController.HEIGHT <= bottom.position.y + 0.5,
				"%s: base sits above bottom panel" % label)
		_check(b.battle_ui.base_hp_label.get_minimum_size().x <= b.battle_ui.base_hp_bar.size.x,
				"%s: base hp text fits" % label)
		_check(b.battle_ui.summon_buttons.size() == 3, "%s: three summon buttons" % label)
		var prev: Rect2
		for i in b.battle_ui.summon_buttons.size():
			var r := b.battle_ui.summon_buttons[i].get_global_rect()
			_check(view.encloses(r), "%s: summon button %d on screen" % [label, i])
			_check(r.size.x >= 48.0 and r.size.y >= 48.0, "%s: summon button %d >= 48px (%s)" % [label, i, r.size])
			if i > 0:
				_check(r.position.x - prev.end.x >= 6.0, "%s: buttons %d/%d spaced" % [label, i - 1, i])
			prev = r
	root.size = Vector2i(390, 844)


func test_pixel_patterns_are_rectangular() -> void:
	for key in PixelArt.PATTERNS:
		var rows: Array = PixelArt.PATTERNS[key]
		var width := (rows[0] as String).length()
		for r in rows:
			_check((r as String).length() == width, "pattern %s row '%s' width" % [key, r])
			for ch in (r as String):
				_check(ch == "." or ch == "b" or ch == "a" or PixelArt.FIXED_COLORS.has(ch),
						"pattern %s unknown key %s" % [key, ch])
	for d in [SOLDIER, ARCHER, SHIELD, GRUNT]:
		_check(PixelArt.PATTERNS.has((d as UnitData).placeholder_pattern),
				"%s placeholder exists" % (d as UnitData).id)


func test_all_res_paths_exist() -> void:
	var regex := RegEx.create_from_string("res://[A-Za-z0-9_./-]+")
	var files := _collect_files("res://", ["gd", "tscn", "tres", "godot", "cfg"])
	_check(files.size() > 10, "found project files (%d)" % files.size())
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		for m in regex.search_all(text):
			var path := m.get_string().trim_suffix(".")
			if path.ends_with("/"):
				continue
			_check(FileAccess.file_exists(path) or ResourceLoader.exists(path),
					"%s references missing %s" % [f, path])


func _collect_files(dir_path: String, exts: Array) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		if sub.begins_with("."):
			continue
		out.append_array(_collect_files(dir_path.path_join(sub), exts))
	for file in dir.get_files():
		if exts.has(file.get_extension()):
			out.append(dir_path.path_join(file))
	return out


func test_retry_reloads_fresh_battle() -> void:
	var b := await _start_battle(false)
	await _seconds(3.0)
	b.base.take_damage(b.base.hp)
	await _frames(2)
	_check(b.phase == BattleManager.Phase.ENDED, "ended before retry")
	b.result_ui.retry_button.pressed.emit()
	await _frames(3)
	var fresh := current_scene as BattleManager
	_check(fresh != null and fresh != b, "a new battle instance replaces the old one")
	if fresh == null:
		return
	_battle = fresh
	_check(not is_instance_valid(b), "old battle freed")
	_check(fresh.phase == BattleManager.Phase.RUNNING, "new battle running")
	_check(fresh.base.hp == fresh.base.max_hp and fresh.base.max_hp == 1000, "base durability reset")
	_check(fresh.kills == 0 and fresh.clock.elapsed < 0.2, "kills and clock reset")
	_check(fresh.world.process_mode == Node.PROCESS_MODE_INHERIT, "world active again")
	_check(not fresh.result_ui.panel.visible, "result screen hidden")
	_check(not paused, "tree not paused")
