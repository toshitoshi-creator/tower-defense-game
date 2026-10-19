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
const BRUTE: UnitData = preload("res://resources/enemies/brute.tres")
const OGRE: UnitData = preload("res://resources/enemies/ogre.tres")
const DEMON_KING: UnitData = preload("res://resources/enemies/demon_king.tres")
const SLOT_SOLDIER := 0
const SLOT_ARCHER := 1
const SLOT_SHIELD := 2
const UP_SPEED := 0
const UP_COUNT := 1
const UP_ATTACK := 2
const UP_HP := 3
const UP_BASE := 4
const UP_COIN := 5
const FPS := 60

const TEST_SAVE := "user://test_save.json"
const STAGE_1: StageData = preload("res://resources/stages/stage_1.tres")
const STAGE_2: StageData = preload("res://resources/stages/stage_2.tres")
const SPEARMAN: UnitData = preload("res://resources/units/spearman.tres")
const MAGE: UnitData = preload("res://resources/units/mage.tres")
const HEALER: UnitData = preload("res://resources/units/healer.tres")

## The Player autoload (not a compile-time name inside a -s script).
var P: Node
var _failures: Array[String] = []
var _current := ""
var _battle: BattleManager


func _initialize() -> void:
	# Script mode starts with a tiny headless window; use the phone reference size.
	await process_frame
	root.size = Vector2i(390, 844)
	await process_frame
	P = root.get_node("Player")
	P.use_storage(TEST_SAVE)  # Never touch the real save.
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
		P.reset_progress()
		P.current_stage_id = "stage_1"
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
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


func _wait_result(b: BattleManager) -> void:
	await _seconds(b.result_delay + 0.3)


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
	var enemy := _enemy(Vector2(40, b.layout.assault_limit_y + 10.0))  # Past the front line.
	var ally := _ally(Vector2(350, b.layout.ally_spawn_y))
	var enemy_y := enemy.position.y
	var ally_y := ally.position.y
	await _seconds(1.0)
	_check(enemy.position.y > enemy_y + 20.0, "enemy should move down (%f -> %f)" % [enemy_y, enemy.position.y])
	_check(ally.position.y < ally_y - 20.0, "ally should move up (%f -> %f)" % [ally_y, ally.position.y])


func test_soldier_returns_to_rally_point_when_field_is_clear() -> void:
	var b := await _start_battle()
	var soldier := _ally(Vector2(60, b.layout.spawn_y + 60.0))
	await _seconds(12.0)
	var rally := Vector2(b.layout.center_x(), b.layout.rally_y)
	_check(soldier.position.distance_to(rally) <= UnitBase.HOME_SPREAD + 15.0,
			"soldier gathers near the base center (%s vs %s)" % [soldier.position, rally])
	_check(soldier.state == Combatant.State.IDLE, "soldier idles once home")
	# It goes out to fight, then comes back.
	var far_enemy := _enemy(Vector2(195, b.layout.spawn_y + 10.0))
	far_enemy.data = GRUNT.duplicate()
	far_enemy.data.move_speed = 0.0
	await _seconds(2.0)
	_check(soldier.position.distance_to(rally) <= UnitBase.HOME_SPREAD + 15.0,
			"soldier waits while the enemy is beyond the front line")
	far_enemy.take_damage(9999)
	var enemy := _enemy(Vector2(195, b.layout.assault_limit_y + 30.0))
	await _seconds(3.0)
	_check(soldier.position.y < rally.y - 100.0, "soldier advances to meet an enemy past the front line")
	enemy.take_damage(9999)
	await _seconds(12.0)
	_check(soldier.position.distance_to(rally) <= UnitBase.HOME_SPREAD + 15.0, "soldier returns after the kill")


func test_enemy_stops_at_base_line() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(330, b.layout.base_line_y - 30.0))
	await _seconds(2.0)
	_check(is_equal_approx(enemy.position.y, b.layout.base_line_y), "enemy should hold at base line")


func test_shields_hold_evenly_spread_posts_on_the_defense_line() -> void:
	var b := await _start_battle()
	var shields: Array[UnitBase] = []
	for i in 3:
		shields.append(_ally(Vector2(195, b.layout.ally_spawn_y), SHIELD))
	_enemy(Vector2(195, b.layout.spawn_y + 20.0))  # Far up the field: not the shields' business.
	await _seconds(8.0)
	var xs := []
	for sh in shields:
		_check(absf(sh.position.y - b.layout.guard_y) < 4.0, "shield stays on the defense line (y=%.0f)" % sh.position.y)
		xs.append(roundi(sh.position.x))
	xs.sort()
	var w := b.layout.right - b.layout.left
	_check(absf(xs[0] - w * 0.25) < 4 and absf(xs[1] - w * 0.5) < 4 and absf(xs[2] - w * 0.75) < 4,
			"posts at 1/4, 1/2, 3/4 of the width: %s" % [xs])


func test_shield_engages_enemies_near_base_and_returns() -> void:
	var b := await _start_battle()
	var shield := _ally(Vector2(195, b.layout.guard_y), SHIELD)
	await _seconds(1.0)
	var post := shield.get_station()
	var enemy := _enemy(Vector2(post.x + 70.0, b.layout.base_line_y - 10.0))
	await _seconds(1.5)
	_check(shield.target == enemy, "shield engages an enemy near the base")
	_check(enemy.hp < enemy.max_hp, "and hits it")
	enemy.take_damage(9999)
	await _seconds(4.0)
	_check(shield.position.distance_to(post) < 4.0, "shield returns to its post")


func test_shield_protects_ally_under_attack() -> void:
	var b := await _start_battle()
	var shield := _ally(Vector2(195, b.layout.guard_y), SHIELD)
	await _seconds(1.0)
	# An archer a little ahead of the line is attacked by an enemy outside the guard radius.
	var archer := _ally(Vector2(195, b.layout.guard_y - 140.0), ARCHER)
	var enemy := _enemy(Vector2(195, b.layout.guard_y - 175.0))
	enemy.data = GRUNT.duplicate()
	enemy.data.move_speed = 0.0
	await _seconds(1.0)
	_check(enemy.target == archer, "setup: the enemy is attacking the archer (%s)" % [enemy.target])
	_check(shield.target == enemy, "shield moves in to protect the archer")


func test_archers_stay_behind_engaged_soldiers() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, b.layout.rally_y - 220.0))
	enemy.data = GRUNT.duplicate()
	enemy.data.move_speed = 0.0
	enemy.max_hp = 100000
	enemy.hp = 100000
	enemy._attack_cooldown = 1000.0
	var soldier := _ally(Vector2(195, enemy.position.y + 40.0))
	var archer := _ally(Vector2(160, b.layout.ally_spawn_y), ARCHER)
	await _seconds(6.0)
	_check(soldier.target == enemy, "soldier engages")
	_check(archer.position.y >= soldier.position.y + 50.0,
			"archer stands behind the soldier (archer y %.0f, soldier y %.0f)" % [archer.position.y, soldier.position.y])
	_check(archer.position.y >= b.layout.archer_limit_y - 1.0, "archer never passes its forward limit")
	_check(archer.state == Combatant.State.ATTACK, "archer shoots from behind")


func test_archer_does_not_chase_out_of_range() -> void:
	var b := await _start_battle()
	var archer := _ally(Vector2(195, b.layout.ally_spawn_y), ARCHER)
	await _seconds(5.0)  # Walk to its spread-out home spot first.
	var home := archer.position
	var enemy := _enemy(Vector2(195, b.layout.spawn_y + 20.0))
	enemy.data = GRUNT.duplicate()  # Never edit the shared resource.
	enemy.data.move_speed = 0.0
	await _seconds(3.0)
	_check(archer.position.distance_to(home) < 4.0, "archer holds its position without soldiers to cover it")


func test_allies_hunt_enemies_that_slipped_past() -> void:
	var b := await _start_battle()
	var ally := _ally(Vector2(40, b.layout.spawn_y + 40.0))
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
	_check(ended[0] == 1, "battle_ended emitted once")
	_check(not b.result_ui.panel.visible, "result panel waits so the moment is visible")
	await _wait_result(b)
	_check(b.result_ui.shown_count == 1 and b.result_ui.panel.visible, "result shown once")
	_check(b.base.modulate == Color(0.5, 0.45, 0.45), "fallen wall settles darkened, not stuck mid-flash")
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
	var enemy := _enemy(Vector2(195, b.layout.rally_y - 200.0))
	enemy.data = GRUNT.duplicate()
	enemy.data.move_speed = 0.0  # Stationary target.
	enemy.max_hp = 100000
	enemy.hp = 100000
	_ally(Vector2(195, enemy.position.y + 40.0))  # A soldier to stand behind.
	var archer := _ally(Vector2(195, b.layout.ally_spawn_y), ARCHER)
	var saw_projectile := false
	var hits := []
	enemy.damaged.connect(func(_c: Combatant, amount: int) -> void: hits.append(amount))
	for i in 360:
		await physics_frame
		for child in b.effects.get_children():
			saw_projectile = saw_projectile or child is Projectile
	_check(saw_projectile, "archer fired a projectile")
	_check(hits.has(ARCHER.attack), "an arrow hit for the archer's attack (%s)" % [hits])
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


func test_arrow_still_hits_after_shooter_is_freed() -> void:
	var b := await _start_battle()
	var enemy := _enemy(Vector2(195, 200))
	var shooter := _ally(Vector2(195, 600), ARCHER)
	var proj := (load(Combatant.PROJECTILE_SCENE_PATH) as PackedScene).instantiate() as Projectile
	b.effects.add_child(proj)
	proj.launch(Vector2(195, 600), enemy, 20, 200.0, shooter)
	shooter.free()
	var hp_before := enemy.hp
	await _seconds(2.5)
	_check(not is_instance_valid(proj), "projectile cleaned up")
	_check(enemy.hp == hp_before - 20, "arrow damage still applied (hp %d -> %d)" % [hp_before, enemy.hp])


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
	_check(b.battle_ui.coin_label.text == "%dG" % b.wallet.coins, "HUD shows coins")
	b.wallet.add_reward(12)
	_check(b.battle_ui.coin_label.text == "%dG" % (b.wallet.starting_coins + 12), "HUD updates")
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


func test_upgrade_cost_formula() -> void:
	var b := await _start_battle()
	var speed: UpgradeData = b.upgrades.upgrades[UP_SPEED]
	var costs := []
	for lv in 4:
		costs.append(BattleUpgradeManager.cost_for_level(speed, lv))
	_check(costs == [50, 75, 113, 169], "50 * 1.5^lv rounded, got %s" % [costs])
	var expected_base := {UP_SPEED: 50, UP_COUNT: 100, UP_ATTACK: 40, UP_HP: 40, UP_BASE: 60, UP_COIN: 80}
	for i in expected_base:
		_check(b.upgrades.get_next_cost(i) == expected_base[i], "initial cost of %s" % b.upgrades.upgrades[i].id)
	b.wallet.coins = 1000
	b.request_upgrade(UP_ATTACK)
	_check(b.wallet.coins == 960 and b.upgrades.get_next_cost(UP_ATTACK) == 60, "cost rises after purchase")


func test_upgrade_refused_without_coins_or_at_max() -> void:
	var b := await _start_battle()
	b.wallet.coins = 39
	_check(b.request_upgrade(UP_ATTACK) == BattleUpgradeManager.Reason.NOT_ENOUGH_COINS, "refused")
	_check(b.upgrades.get_level(UP_ATTACK) == 0 and b.wallet.coins == 39, "nothing applied or spent")
	_check(b.summoner.ally_attack_multiplier == 1.0, "effect not applied")
	_check(b.battle_ui.toast.text == "コインが足りません", "reason shown")
	b.wallet.coins = 10000
	for i in 3:
		_check(b.request_upgrade(UP_COUNT) == BattleUpgradeManager.Reason.OK, "count level %d" % (i + 1))
	var coins := b.wallet.coins
	_check(b.request_upgrade(UP_COUNT) == BattleUpgradeManager.Reason.MAX_LEVEL, "max level refused")
	_check(b.wallet.coins == coins and b.upgrades.get_level(UP_COUNT) == 3, "no charge at max")
	_check(b.upgrades.get_next_cost(UP_COUNT) == -1, "maxed cost is -1")
	await _frames(8)
	_check(b.battle_ui.upgrade_buttons[UP_COUNT].cost_label.text == "MAX", "button shows MAX")


func test_summon_speed_upgrade() -> void:
	var b := await _start_battle()
	b.wallet.coins = 10000
	b.request_upgrade(UP_SPEED)
	_check(is_equal_approx(b.summoner.get_interval(), 4.25), "lv1 interval 4.25s, got %f" % b.summoner.get_interval())
	b.request_summon(SLOT_SOLDIER)
	_check(is_equal_approx(b.summoner.get_cooldown_remaining(SLOT_SOLDIER), 4.25), "new cooldown uses upgraded interval")
	for i in 4:
		b.request_upgrade(UP_SPEED)
	_check(b.upgrades.is_maxed(UP_SPEED), "speed maxed at 5")
	_check(b.summoner.get_interval() >= SummonManager.MIN_INTERVAL, "never below the floor")
	_check(is_equal_approx(b.summoner.get_interval(), 1.25), "lv5 interval 1.25s, got %f" % b.summoner.get_interval())


func test_summon_count_upgrade_applies_from_next_summon() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	b.request_summon(SLOT_SOLDIER)
	_check(_count(&"allies") == 1, "one before upgrade")
	b.request_upgrade(UP_COUNT)
	_check(_count(&"allies") == 1, "upgrade does not spawn extra units")
	_check(b.summoner.get_summon_cost(SLOT_ARCHER) == 60, "2 archers cost 60")
	var coins := b.wallet.coins
	b.request_summon(SLOT_ARCHER)
	_check(_count(&"allies") == 3 and b.wallet.coins == coins - 60, "2 archers summoned for 60")
	await _frames(8)
	_check(b.battle_ui.summon_buttons[SLOT_SOLDIER].count_label.text == "×2", "button shows ×2")
	_check(b.battle_ui.summon_buttons[SLOT_SOLDIER].cost_label.text == "40G", "button shows total cost")


func test_attack_upgrade_reaches_living_and_new_allies() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	var old_unit := _ally(Vector2(100, 600))
	_check(old_unit.attack_power == 15, "base attack 15")
	b.request_upgrade(UP_ATTACK)
	_check(old_unit.attack_power == 17, "living soldier 15 * 1.15 -> 17, got %d" % old_unit.attack_power)
	var ups := 0
	for child in b.effects.get_children():
		if child is FloatingText and (child as Label).text == "UP":
			ups += 1
	_check(ups == 1, "an UP popup marks the boosted ally (%d)" % ups)
	var new_unit := _ally(Vector2(300, 600))
	_check(new_unit.attack_power == 17, "new soldier gets it too")
	var enemy := _enemy(Vector2(100, 560))
	var hits := []
	enemy.damaged.connect(func(_c: Combatant, amount: int) -> void: hits.append(amount))
	await _seconds(1.5)
	_check(hits.size() > 0 and hits[0] == 17, "upgraded hit deals 17 (%s)" % [hits])


func test_hp_upgrade_raises_living_allies_without_full_heal() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	var unit := _ally(Vector2(100, 600))
	unit.take_damage(40)
	_check(unit.hp == 60, "damaged to 60/100")
	b.request_upgrade(UP_HP)
	_check(unit.max_hp == 115 and unit.hp == 75, "max 115, hp 60+15=75, got %d/%d" % [unit.hp, unit.max_hp])
	var fresh := _ally(Vector2(300, 600), SHIELD)
	_check(fresh.max_hp == 253 and fresh.hp == 253, "new shield 220*1.15=253, got %d" % fresh.max_hp)


func test_base_upgrade_adds_max_and_current() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	b.base.take_damage(100)
	b.request_upgrade(UP_BASE)
	_check(b.base.max_hp == 1200 and b.base.hp == 1100, "900/1000 -> 1100/1200, got %d/%d" % [b.base.hp, b.base.max_hp])
	_check(b.battle_ui.base_hp_label.text == "陣地 1100 / 1200", "HUD shows new durability")
	_check(b.battle_ui.toast.text.begins_with("陣地耐久 Lv1"), "effect announced: %s" % b.battle_ui.toast.text)


func test_coin_gain_upgrade_raises_kill_rewards() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	b.request_upgrade(UP_COIN)
	var before := b.wallet.coins
	_enemy(Vector2(100, 300)).take_damage(9999)
	await _frames(1)
	_check(b.wallet.coins - before == 6, "5 * 1.2 = 6 coins, got %d" % (b.wallet.coins - before))


func test_upgrade_refused_after_battle_end() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	b.base.take_damage(b.base.hp)
	await _frames(2)
	_check(b.request_upgrade(UP_ATTACK) == BattleUpgradeManager.Reason.BATTLE_OVER, "refused after end")
	_check(b.upgrades.get_level(UP_ATTACK) == 0, "level unchanged")
	_check(not b.battle_ui.is_upgrade_panel_open(), "drawer closed on result screen")


func test_upgrade_drawer_by_touch() -> void:
	var b := await _start_battle()
	b.wallet.coins = 1000
	_check(not b.battle_ui.is_upgrade_panel_open(), "drawer starts closed")
	await _tap(b.battle_ui.upgrade_toggle.get_global_rect().get_center())
	_check(b.battle_ui.is_upgrade_panel_open(), "tap opens drawer")
	await _frames(2)
	var view := b.get_viewport_rect()
	var bottom := b.battle_ui.bottom_panel.get_global_rect()
	for button in b.battle_ui.upgrade_buttons:
		var r := button.get_global_rect()
		_check(view.encloses(r), "upgrade button on screen")
		_check(r.size.y >= 48.0, "upgrade button >= 48px tall")
		_check(r.end.y <= bottom.position.y + 0.5, "drawer sits above the bottom panel")
	await _tap(b.battle_ui.upgrade_buttons[UP_ATTACK].get_global_rect().get_center())
	_check(b.upgrades.get_level(UP_ATTACK) == 1, "tap on upgrade buys it")
	_check(b.phase == BattleManager.Phase.RUNNING and not paused, "battle keeps running with drawer open")
	await _tap(b.battle_ui.upgrade_toggle.get_global_rect().get_center())
	_check(not b.battle_ui.is_upgrade_panel_open(), "tap closes drawer")


## A reasonable player: keeps a mixed army (about half soldiers, then archers, a few
## shields), always summons, and buys the cheapest upgrade when at the unit cap or
## holding 150+ coins.
func _play_balanced(b: BattleManager, limit: float) -> int:
	var bought := 0
	while b.phase != BattleManager.Phase.ENDED and b.clock.elapsed < limit:
		if b.summoner.get_free_capacity() < 3 or b.wallet.coins >= 150:
			var best := -1
			for i in b.upgrades.upgrades.size():
				var c := b.upgrades.get_next_cost(i)
				if c > 0 and (best < 0 or c < b.upgrades.get_next_cost(best)):
					best = i
			if best >= 0 and b.request_upgrade(best) == BattleUpgradeManager.Reason.OK:
				bought += 1
		# Target mix ~ 50% soldiers, 30% archers, 20% shields.
		var counts := {SOLDIER: 0, ARCHER: 0, SHIELD: 0}
		for u in get_nodes_in_group(&"allies"):
			counts[(u as UnitBase).data] += 1
		var n := _count(&"allies") + 1
		var want := [[SLOT_SOLDIER, counts[SOLDIER] / (0.5 * n)], [SLOT_ARCHER, counts[ARCHER] / (0.3 * n)],
				[SLOT_SHIELD, counts[SHIELD] / (0.2 * n)]]
		want.sort_custom(func(x: Array, y: Array) -> bool: return x[1] < y[1])
		# Buy what's under its share; never over-buy just because it's affordable.
		for w in want:
			if (w[1] < 1.0 or w == want[0]) and b.summoner.check_summon(w[0]) == SummonManager.Reason.OK:
				b.request_summon(w[0])
		await _seconds(0.5)
	return bought


func test_full_battle_reaches_final_boss() -> void:
	# A player after a few clears: one permanent level in attack, HP and summon speed.
	for id in ["ally_attack", "ally_hp", "summon_speed"]:
		P.permanent[id] = 1
	var b := await _start_battle(false)
	var bought := await _play_balanced(b, 8.0 * 60.0)
	print("        balanced bot: %s at %s, kills=%d, upgrades=%d, mid bosses %d/4, final %s" % [
			["VICTORY", "DEFEAT"][b.result] if b.phase == BattleManager.Phase.ENDED else "running",
			BattleClock.format_time(b.clock.elapsed), b.kills, bought, b.mid_bosses_defeated,
			"defeated" if b.final_boss_defeated else "alive"])
	_check(bought >= 5, "bot bought upgrades (%d)" % bought)
	_check(b.bosses_spawned == 5, "all 5 bosses appeared (%d)" % b.bosses_spawned)
	_check(b.mid_bosses_defeated >= 3, "army handles mid bosses (%d)" % b.mid_bosses_defeated)
	_check(b.phase == BattleManager.Phase.ENDED, "battle is decided")
	_check((b.result == BattleManager.Result.VICTORY) == b.final_boss_defeated,
			"victory iff final boss defeated")


func test_regular_spawn_curve() -> void:
	var b := await _start_battle()
	var sp := b.spawner
	b.clock.elapsed = 0.0
	_check(is_equal_approx(sp.current_interval(), sp.start_interval) and sp.current_wave_size() == 1, "start: 1 enemy per wave")
	_check(sp.current_strong_chance() == 0.0, "no strong enemies at start")
	b.clock.elapsed = 89.0
	_check(sp.current_strong_chance() == 0.0, "no strong enemies before 1:30")
	b.clock.elapsed = 150.0
	_check(sp.current_interval() < sp.start_interval and sp.current_wave_size() == 2, "faster, bigger waves later")
	_check(sp.current_strong_chance() > 0.0, "strong enemies mixed in after 1:30")
	_check(sp.current_stat_multiplier() > 1.25, "stats grow")
	b.clock.elapsed = 600.0
	_check(sp.current_interval() == sp.min_interval and sp.current_wave_size() == sp.max_wave_size, "curve capped")
	_check(sp.current_strong_chance() == sp.strong_max_chance, "strong share capped")
	_check(GRUNT.reward == 5 and BRUTE.reward == 12 and OGRE.reward == 100 and DEMON_KING.reward == 300, "spec rewards")


func _boss_count(data: UnitData) -> int:
	var n := 0
	for e in get_nodes_in_group(&"enemies"):
		if (e as EnemyBase).data == data:
			n += 1
	return n


func test_mid_bosses_appear_on_schedule() -> void:
	var b := await _start_battle()
	for i in 4:
		var t := 60.0 * (i + 1)
		b.clock.elapsed = t - 0.3
		await _frames(6)
		_check(b.bosses_spawned == i, "no boss before %ds" % int(t))
		await _frames(20)
		_check(b.bosses_spawned == i + 1, "boss %d appears at %ds (t=%.2f)" % [i + 1, int(t), b.clock.elapsed])
		_check(b.battle_ui.banner.visible and b.battle_ui.banner.text == "中ボス出現！", "mid boss banner")
		_check(b.battle_ui.is_boss_bar_shown(), "boss HP bar shown")
	_check(_boss_count(OGRE) == 4, "four ogres on the field")
	var mults := []
	for e in b.active_bosses:
		mults.append(e.max_hp)
	_check(mults == [900, 1170, 1440, 1710], "later mid bosses are tougher: %s" % [mults])
	_check(_boss_count(DEMON_KING) == 0, "no final boss before 5:00")


func test_boss_spawn_ignores_regular_spawning_and_cap() -> void:
	var b := await _start_battle()
	b.spawner.max_alive = 0
	_check(b.spawner.spawn_enemy(GRUNT) == null, "regular enemies blocked by cap")
	b.clock.elapsed = 250.0  # Four boss times already passed (e.g. after a long hitch).
	await _frames(2)
	_check(b.bosses_spawned == 4, "all overdue bosses spawn, despite cap and auto_spawn=false (%d)" % b.bosses_spawned)
	await _frames(10)
	_check(b.bosses_spawned == 4, "each boss spawns only once")


func test_final_boss_at_five_minutes_and_time_alone_does_not_win() -> void:
	var b := await _start_battle()
	b.clock.elapsed = 299.7
	await _frames(6)
	_check(_boss_count(DEMON_KING) == 0, "not yet at 4:59.8")
	await _frames(20)
	_check(_boss_count(DEMON_KING) == 1, "final boss appears at 5:00")
	_check(b.battle_ui.banner.text == "最終ボス出現！", "final boss banner")
	_check(b.battle_ui.boss_name_label.text == DEMON_KING.display_name, "boss bar shows the final boss")
	await _seconds(3.0)
	_check(b.phase == BattleManager.Phase.RUNNING, "reaching 5:00 is not a victory")
	_check(b.clock.elapsed > 300.0, "clock keeps running after 5:00")


func test_mid_boss_kill_rewards_but_does_not_win() -> void:
	var b := await _start_battle()
	b.clock.elapsed = 60.0
	await _frames(2)
	var boss: EnemyBase = b.active_bosses[0]
	var coins := b.wallet.coins
	boss.take_damage(int(boss.max_hp * 0.5))
	await _frames(1)
	_check(is_equal_approx(b.battle_ui.boss_hp_bar.value, 0.5), "boss bar at half (%f)" % b.battle_ui.boss_hp_bar.value)
	boss.take_damage(99999)
	boss.take_damage(99999)
	await _frames(2)
	_check(b.wallet.coins - coins == 100, "mid boss pays 100 once (%d)" % (b.wallet.coins - coins))
	_check(b.mid_bosses_defeated == 1 and b.bosses_defeated == 1, "counted once")
	_check(b.phase == BattleManager.Phase.RUNNING, "mid boss kill is not a victory")
	_check(not b.battle_ui.is_boss_bar_shown(), "boss HP bar hidden when no boss is alive")
	await _seconds(1.1)
	_check(b.battle_ui.boss_name_label.text.begins_with("中ボスまで"), "countdown to next boss: %s" % b.battle_ui.boss_name_label.text)
	_check(b.battle_ui.banner.text == "中ボス撃破！", "mid boss defeat banner")


func test_killing_final_boss_wins_and_stops_battle() -> void:
	var b := await _start_battle()
	b.spawner.auto_spawn = true
	b.clock.elapsed = 300.0
	await _frames(2)
	var boss: EnemyBase
	for e in b.active_bosses:
		if e.data == DEMON_KING:
			boss = e
	_check(boss != null, "final boss present")
	if boss == null:
		return
	var coins := b.wallet.coins
	var ally := _ally(Vector2(60, 500))
	boss.take_damage(99999, ally)
	await _frames(2)
	_check(b.phase == BattleManager.Phase.ENDED and b.result == BattleManager.Result.VICTORY, "victory")
	_check(b.final_boss_defeated, "final boss recorded")
	_check(b.wallet.coins - coins == 300, "final boss pays 300 (%d)" % (b.wallet.coins - coins))
	_check(_count(&"enemies") == 0, "remaining enemies rout after the final boss falls")
	_check(b.wallet.coins - coins == 300 and b.kills == 1, "routing enemies give no coins or kills")
	await _wait_result(b)
	_check(b.result_ui.shown_count == 1 and b.result_ui.title_label.text == "勝利！", "victory screen once")
	_check(b.result_ui.boss_label.text.contains("最終ボス  撃破"), "result lists final boss defeated: %s" % b.result_ui.boss_label.text)
	var enemies := _count(&"enemies")
	var t := b.clock.elapsed
	var c := b.wallet.coins
	await _seconds(3.0)
	_check(_count(&"enemies") == enemies and b.clock.elapsed == t and b.wallet.coins == c,
			"spawning, clock and coins stop after victory")


func test_final_boss_cleave_hits_clustered_allies() -> void:
	var b := await _start_battle()
	var boss := b.spawner.spawn_enemy(DEMON_KING, 1.0, Vector2(195, 300), true)
	var group: Array[UnitBase] = []
	for i in 3:
		group.append(_ally(Vector2(185 + i * 10, 300 + DEMON_KING.body_radius + 12)))
	var far := _ally(Vector2(40, 300), SHIELD)
	await _seconds(2.0)
	var hurt := 0
	for u in group:
		if u.hp < u.max_hp:
			hurt += 1
	_check(hurt == 3, "cleave hits every clustered ally (%d/3)" % hurt)
	_check(far.hp == far.max_hp or far.position.distance_to(boss.position) < 90.0, "allies far away are not hit")


func test_allies_target_big_units_by_edge_distance() -> void:
	var b := await _start_battle()
	var boss := b.spawner.spawn_enemy(OGRE, 1.0, Vector2(195, 300), true)
	boss.data = OGRE.duplicate()
	boss.data.move_speed = 0.0
	# From the ally: grunt center 50px (edge 36), ogre center 60px (edge 34).
	var grunt := _enemy(Vector2(195 + 50, 360))
	grunt.data = GRUNT.duplicate()
	grunt.data.move_speed = 0.0
	var ally := _ally(Vector2(195, 360))
	await _frames(20)
	_check(ally.target == boss, "ally attacks the ogre whose edge is closer")


func test_battle_end_lets_animations_finish() -> void:
	var b := await _start_battle()
	var dying := _enemy(Vector2(100, 300))
	var survivor := _ally(Vector2(300, 600))
	_ally(Vector2(100, 340), ARCHER)
	await _seconds(0.8)
	dying.take_damage(9999)
	b.base.take_damage(b.base.hp)
	await _frames(2)
	_check(_count(&"projectiles") == 0, "arrows in flight are removed at the end")
	await _seconds(1.0)
	_check(not is_instance_valid(dying), "a unit that was dying finishes its death and is freed")
	_check(is_instance_valid(survivor) and survivor.state == Combatant.State.IDLE, "survivors stand idle")
	_check(not survivor.is_physics_processing(), "survivors no longer act")


func test_generated_sprites_have_every_animation() -> void:
	for data in [SOLDIER, ARCHER, SHIELD, GRUNT, BRUTE, OGRE, DEMON_KING]:
		var frames := PixelArt.build_sprite_frames(data)
		for anim in [&"idle", &"move", &"attack", &"hurt", &"death"]:
			_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0,
					"%s has %s" % [(data as UnitData).id, anim])
		_check(frames.get_animation_loop(&"move") and not frames.get_animation_loop(&"death"), "loop flags")
		_check(PixelArt.build_sprite_frames(data) == frames, "frames are cached per unit look")
		var tex := frames.get_frame_texture(&"idle", 0)
		var rows := PixelArt.get_rows((data as UnitData).placeholder_pattern)
		_check(tex.get_width() == (rows[0] as String).length() + 2 and tex.get_height() == rows.size() + 2,
				"%s texture is 1 texel per pattern pixel + margin" % (data as UnitData).id)


func test_unit_animation_follows_state() -> void:
	var b := await _start_battle()
	var ally := _ally(Vector2(195, b.layout.ally_spawn_y))
	await _frames(5)
	_check(ally._visual.get_current_animation() == &"move", "walking unit plays move")
	var enemy := _enemy(Vector2(195, b.layout.ally_spawn_y - 40))
	enemy.data = GRUNT.duplicate()
	enemy.data.move_speed = 0.0
	# Keep the goblin from swinging: its hit would replace the attack anim with hurt.
	enemy._attack_cooldown = 1000.0
	var saw_attack := false
	for i in 90:
		await physics_frame
		saw_attack = saw_attack or ally._visual.get_current_animation() == &"attack"
	_check(saw_attack, "attacking unit plays attack")
	enemy.take_damage(9999)
	await _frames(2)
	_check(enemy._visual.get_current_animation() == &"death", "dead unit plays death")


func test_effects_are_capped() -> void:
	var b := await _start_battle()
	for i in 200:
		PixelBurst.spawn(b.effects, Vector2(100, 100), Color.WHITE)
		FloatingText.spawn(b.effects, Vector2(100, 100), "1", Color.WHITE)
	var bursts := 0
	var texts := 0
	for child in b.effects.get_children():
		bursts += 1 if child is PixelBurst else 0
		texts += 1 if child is FloatingText else 0
	_check(bursts <= PixelBurst.MAX_ACTIVE and texts <= FloatingText.MAX_ACTIVE,
			"bursts %d / texts %d within caps" % [bursts, texts])


func test_title_screen_starts_battle_and_result_returns_to_title() -> void:
	# Real scene flow: home -> stage select -> battle -> result -> home.
	change_scene_to_file("res://scenes/title/title.tscn")
	await _frames(3)
	var title := current_scene
	_check(title != null and title.name == "Title", "home scene loaded")
	var start: Button = title.start_button
	_check(get_root().get_visible_rect().encloses(start.get_global_rect()), "stage select button on screen")
	_check(start.size.y >= 48.0, "stage select button is a big tap target")
	await _tap(start.get_global_rect().get_center())
	await _frames(3)
	_check(current_scene.name == "StageSelect", "home opens stage select")
	await _tap(current_scene.sortie_buttons["stage_1"].get_global_rect().get_center())
	await _frames(3)
	var b := current_scene as BattleManager
	_check(b != null and b.phase == BattleManager.Phase.RUNNING, "tapping 出撃 begins a battle")
	if b == null:
		return
	_battle = b
	b.base.take_damage(b.base.hp)
	await _frames(2)
	await _wait_result(b)
	await _tap(b.result_ui.title_button.get_global_rect().get_center())
	await _frames(3)
	_check(current_scene != null and current_scene.name == "Title", "result screen returns home")
	_check(not paused, "home is not paused")
	_battle = null
	current_scene.queue_free()
	await _frames(2)


func test_pause_menu_can_return_to_title() -> void:
	var b := await _start_battle()
	b.set_paused(true)
	b.battle_ui.title_button.pressed.emit()
	await _frames(3)
	_check(current_scene != null and current_scene.name == "Title", "pause menu returns to title")
	_check(not paused, "tree unpaused after leaving")
	_battle = null
	current_scene.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- meta game

func test_save_round_trip_and_corrupt_file() -> void:
	P.add_coins(1234)
	P.add_orbs(70)
	P.add_orbs(30, true)
	P.characters["mage"] = 3
	P.set_deck(["mage", "soldier", "shield"] as Array[String], false)
	P.cleared_stages.append("stage_1")
	P.permanent["ally_attack"] = 2
	P.save_game()
	P.use_storage(TEST_SAVE)
	_check(P.coins == 1234 and P.orbs_free == 70 and P.orbs_paid == 30, "currencies persist")
	_check(P.character_level("mage") == 3, "characters persist")
	_check(P.deck == (["mage", "soldier", "shield"] as Array[String]), "deck persists: %s" % [P.deck])
	_check(P.is_stage_cleared("stage_1") and P.permanent_level("ally_attack") == 2, "progress persists")
	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	P.use_storage(TEST_SAVE)
	_check(P.coins == 0 and P.rank == 1 and P.deck.size() == 3, "corrupt save falls back to a fresh start")
	f = FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"coins": -50, "characters": {"mage": 99, "hacker": 5}, "deck": ["mage", "mage", "x"]}))
	f.close()
	P.use_storage(TEST_SAVE)
	_check(P.coins == 0, "negative coins clamped")
	_check(P.character_level("mage") == GameCatalog.MAX_CHARACTER_LEVEL and not P.owns("hacker"), "levels clamped, unknown ids dropped")
	_check(P.deck == (GameCatalog.STARTER_CHARACTERS as Array[String]) or P.deck.size() == 3, "invalid deck replaced")


func test_rank_up_pays_coins_and_orbs() -> void:
	_check(GameCatalog.exp_to_next_rank(1) == 100 and GameCatalog.exp_to_next_rank(2) == 150, "rank table")
	var ups: Array[Dictionary] = P.add_rank_exp(120)
	_check(P.rank == 2 and P.rank_exp == 20, "rank 2 with 20 exp (rank %d exp %d)" % [P.rank, P.rank_exp])
	_check(ups.size() == 1 and ups[0]["coins"] == 300 and ups[0]["orbs"] == 50, "rank-up reward %s" % [ups])
	_check(P.coins == 300 and P.get_orbs() == 50, "reward paid")
	ups = P.add_rank_exp(1000)
	_check(ups.size() >= 3 and P.rank == 2 + ups.size(), "several rank-ups at once (%d)" % ups.size())


func test_roulette_odds_and_prizes() -> void:
	P.rng.seed = 12345
	var counts := {}
	var n := 20000
	for i in n:
		var seg: int = P.spin_roulette()
		counts[seg] = counts.get(seg, 0) + 1
	var total := 0
	for e in GameCatalog.ROULETTE:
		total += int(e["weight"])
	for i in GameCatalog.ROULETTE.size():
		var expected := float(GameCatalog.ROULETTE[i]["weight"]) / total
		var got := float(counts.get(i, 0)) / n
		_check(absf(got - expected) < 0.012, "segment %d: %.3f vs %.3f" % [i, got, expected])
	var orb_seg := GameCatalog.ROULETTE.size() - 1
	_check(GameCatalog.ROULETTE[orb_seg]["orbs"] > 0 and GameCatalog.ROULETTE[orb_seg]["weight"] <= 10, "orbs are a rare segment")
	_check(P.roulette_prize(0, STAGE_1)["coins"] == 100 and P.roulette_prize(0, STAGE_2)["coins"] == 150,
			"stage 2 multiplies roulette coins")


func test_wheel_lands_on_the_decided_segment() -> void:
	var b := await _start_battle()
	var wheel: RouletteWheel = b.result_ui.wheel
	for seg in GameCatalog.ROULETTE.size():
		wheel.spin = randf() * TAU
		wheel.spin_to(seg, 0.2)
		await _seconds(0.35)
		_check(wheel.segment_at_pointer() == seg, "wheel stops on segment %d (got %d)" % [seg, wheel.segment_at_pointer()])


func test_victory_grants_rewards_once_and_unlocks_stage_2() -> void:
	_check(not P.is_stage_unlocked("stage_2"), "stage 2 starts locked")
	var b := await _start_battle()
	b.notify_final_boss_defeated()
	await _frames(2)
	var r: Dictionary = b.clear_rewards
	_check(not r.is_empty() and b.roulette_segment >= 0, "rewards decided at victory")
	_check(P.is_stage_cleared("stage_1") and P.is_stage_unlocked("stage_2"), "stage 2 unlocked")
	_check(r["first_clear"] and r["exp"] == STAGE_1.clear_exp, "first clear exp")
	_check(r["unlocked_stage"] == STAGE_2.display_name, "names the unlocked stage")
	var prize: Dictionary = P.roulette_prize(b.roulette_segment, STAGE_1)
	var rank_coins := 0
	var rank_orbs := 0
	for up in r["rank_ups"]:
		rank_coins += up["coins"]
		rank_orbs += up["orbs"]
	_check(P.coins == prize["coins"] + rank_coins and P.get_orbs() == prize["orbs"] + rank_orbs,
			"coins/orbs = roulette + rank-ups (coins %d orbs %d)" % [P.coins, P.get_orbs()])
	var saved_coins: int = P.coins
	P.use_storage(TEST_SAVE)
	_check(P.coins == saved_coins and P.is_stage_cleared("stage_1"), "rewards were saved immediately")
	await _wait_result(b)
	_check(b.result_ui.reward_box.visible, "roulette shown on victory")
	await _tap(b.result_ui.spin_button.get_global_rect().get_center())
	await _seconds(3.0)
	_check(b.result_ui.wheel.segment_at_pointer() == b.roulette_segment, "wheel shows the granted segment")
	_check(b.result_ui.prize_label.text != "？", "prize revealed: %s" % b.result_ui.prize_label.text)
	_check(b.result_ui.rank_up_label.text.contains("解放"), "unlock announced: %s" % b.result_ui.rank_up_label.text)
	b.result_ui.spin_button.pressed.emit()
	b.notify_final_boss_defeated()
	await _frames(2)
	_check(P.coins == saved_coins, "no second grant")


func test_defeat_grants_nothing() -> void:
	var b := await _start_battle()
	b.base.take_damage(b.base.hp)
	await _frames(2)
	await _wait_result(b)
	_check(P.coins == 0 and P.rank_exp == 0 and not P.is_stage_cleared("stage_1"), "no rewards on defeat")
	_check(not b.result_ui.reward_box.visible and b.result_ui.defeat_hint.visible, "defeat hint instead of roulette")


func test_stage_2_battle_uses_stage_settings() -> void:
	P.current_stage_id = "stage_2"
	var b := await _start_battle()
	_check(b.stage == STAGE_2, "stage 2 loaded")
	_check(is_equal_approx(b.spawner.enemy_stat_multiplier, STAGE_2.enemy_stat_multiplier), "enemy multiplier")
	_check(b.battle_ui.stage_label.text == "STAGE 2", "HUD shows the stage")
	var grunt := b.spawner.spawn_enemy(GRUNT, b.spawner.current_stat_multiplier())
	_check(grunt.max_hp == roundi(GRUNT.max_hp * STAGE_2.enemy_stat_multiplier), "enemies are tougher (%d)" % grunt.max_hp)
	b.clock.elapsed = 60.0
	await _frames(2)
	_check(b.active_bosses.size() == 1 and b.active_bosses[0].max_hp == roundi(OGRE.max_hp * STAGE_2.enemy_stat_multiplier),
			"bosses are tougher too")


func test_stage_select_locks_and_starts_battles() -> void:
	change_scene_to_file("res://scenes/meta/stage_select.tscn")
	await _frames(3)
	var screen := current_scene
	var b1: Button = screen.sortie_buttons["stage_1"]
	var b2: Button = screen.sortie_buttons["stage_2"]
	_check(not b1.disabled and b2.disabled, "only stage 1 is open")
	_check(screen.status_labels["stage_2"].text == "ステージ1をクリアで解放", "lock reason shown")
	P.cleared_stages.append("stage_1")
	P.save_game()
	await _frames(1)
	_check(not b2.disabled, "stage 2 opens once stage 1 is cleared")
	await _tap(b2.get_global_rect().get_center())
	await _frames(3)
	var b := current_scene as BattleManager
	_check(b != null and b.stage == STAGE_2, "tapping 出撃 starts stage 2")
	_battle = b


func test_home_menu_opens_every_screen() -> void:
	for entry in [["ステージ選択", "StageSelect"], ["編成", "Deck"], ["強化", "Upgrades"], ["ガチャ", "Gacha"], ["ショップ", "Shop"]]:
		change_scene_to_file("res://scenes/title/title.tscn")
		await _frames(3)
		var home := current_scene
		var button: Button = home.start_button if entry[0] == "ステージ選択" else home.menu_buttons[entry[0]]
		_check(get_root().get_visible_rect().encloses(button.get_global_rect()) and button.size.y >= 48.0,
				"%s button on screen and tappable" % entry[0])
		await _tap(button.get_global_rect().get_center())
		await _frames(3)
		_check(current_scene != null and current_scene.name == entry[1], "%s opens (%s)" % [entry[0], current_scene.name])
		if current_scene is MetaScreen:
			var back: Button = current_scene.back_button
			await _tap(back.get_global_rect().get_center())
			await _frames(3)
			_check(current_scene.name == "Title", "back returns home from %s (now %s, paused=%s)" % [entry[1], current_scene.name, paused])
	current_scene.queue_free()
	await _frames(2)


func test_gacha_new_duplicate_and_costs() -> void:
	_check(P.draw_gacha(1).is_empty() and P.get_orbs() == 0, "no orbs: nothing drawn, nothing spent")
	var total := 0
	for e in GameCatalog.GACHA_POOL:
		total += int(e["weight"])
		_check(GameCatalog.CHARACTERS.has(e["id"]), "pool entry %s exists" % e["id"])
	_check(total == 100, "rates add up to 100%")
	P.add_orbs(30)
	P.add_orbs(1000, true)
	P.rng.seed = 7
	var results: Array[Dictionary] = P.draw_gacha(10)
	_check(results.size() == 10, "ten results")
	_check(P.get_orbs() == 1030 - GameCatalog.GACHA_TEN_COST and P.orbs_free == 0, "450 spent, free orbs first")
	for r in results:
		_check(P.owns(r["id"]) and P.character_level(r["id"]) >= 1, "%s in collection" % r["id"])
	# Duplicates level up; past max they become coins.
	P.characters["soldier"] = GameCatalog.MAX_CHARACTER_LEVEL - 1
	var lv_before: int = P.character_level("soldier")
	var dup := 0
	for i in 200:
		P.add_orbs(GameCatalog.GACHA_SINGLE_COST)
		var one: Dictionary = P.draw_gacha(1)[0]
		if one["id"] == "soldier":
			dup += 1
			if dup == 1:
				_check(P.character_level("soldier") == lv_before + 1, "duplicate levels up")
			elif dup == 2:
				_check(one["coins"] == GameCatalog.DUPLICATE_OVERFLOW_COINS, "max level duplicate turns into coins")
				break
	_check(dup >= 2, "drew soldier twice in 200 pulls")


func test_deck_rules_and_level_bonus_in_battle() -> void:
	_check(not P.set_deck(["soldier", "soldier", "shield"] as Array[String]), "no duplicates in deck")
	_check(not P.set_deck(["soldier", "mage", "shield"] as Array[String]), "unowned character refused")
	_check(not P.set_deck(["soldier", "shield"] as Array[String]), "deck needs 3")
	P.characters["mage"] = 1
	P.characters["soldier"] = 5
	_check(P.set_deck(["mage", "soldier", "shield"] as Array[String]), "valid deck saved")
	var b := await _start_battle()
	_check(b.summoner.roster[0] == MAGE, "battle uses the deck")
	_check(b.battle_ui.summon_buttons[0].name_label.text == MAGE.display_name, "summon buttons follow the deck")
	var unit: UnitBase = b.summoner.summon(SOLDIER, Vector2(195, 600))
	var bonus := GameCatalog.level_bonus(5)
	_check(unit.max_hp == roundi(SOLDIER.max_hp * bonus) and unit.attack_power == roundi(SOLDIER.attack * bonus),
			"Lv5 soldier gets +32%% (hp %d atk %d)" % [unit.max_hp, unit.attack_power])
	b.wallet.coins = 1000
	b.request_upgrade(UP_ATTACK)
	_check(unit.attack_power == roundi(SOLDIER.attack * 1.15 * bonus), "battle upgrades stack with level bonus")


func test_deck_screen_by_touch() -> void:
	P.characters["knight"] = 2
	change_scene_to_file("res://scenes/meta/deck.tscn")
	await _frames(3)
	var screen := current_scene
	await _tap(screen.character_buttons["archer"].get_global_rect().get_center())
	_check(P.deck.size() == 3 and screen.message_label.text.begins_with("あと1体"), "removing one asks for another")
	var knight_button: Button = screen.character_buttons["knight"]
	var scroll := knight_button.get_parent().get_parent() as ScrollContainer
	scroll.ensure_control_visible(knight_button)
	await _frames(2)
	await _tap(knight_button.get_global_rect().get_center())
	_check(P.deck.has("knight") and not P.deck.has("archer"), "knight replaces archer: %s" % [P.deck])
	_check(screen.character_buttons["mage"].disabled, "unowned characters can't be chosen")
	current_scene.queue_free()
	await _frames(2)


func test_permanent_upgrades() -> void:
	var ups := GameCatalog.load_upgrades()
	var atk: UpgradeData = ups[UP_ATTACK]
	_check(P.permanent_next_cost(atk) == roundi(atk.base_cost * 5.0), "first permanent level costs base x5")
	_check(not P.buy_permanent(atk), "refused without coins")
	P.add_coins(100000)
	for i in 10:
		P.buy_permanent(atk)
	_check(P.permanent_level("ally_attack") == GameCatalog.permanent_max_level(atk), "stops at the permanent max")
	_check(P.permanent_next_cost(atk) == -1, "maxed")
	P.buy_permanent(ups[UP_BASE])
	var b := await _start_battle()
	_check(b.upgrades.get_level(UP_ATTACK) == GameCatalog.permanent_max_level(atk), "battle starts at the permanent level")
	_check(is_equal_approx(b.summoner.ally_attack_multiplier, 1.0 + atk.value_per_level * GameCatalog.permanent_max_level(atk)),
			"its effect is active")
	_check(b.base.max_hp == 1200 and b.base.hp == 1200, "base durability starts higher")
	_check(b.upgrades.get_next_cost(UP_ATTACK) > atk.base_cost, "further in-battle levels cost more")


func test_shop_test_purchases() -> void:
	var service := PurchaseService.new()
	_check(service.is_test_mode(), "shop is in test mode")
	var results := []
	service.purchase_finished.connect(func(_id: String, ok: bool, _m: String) -> void: results.append(ok))
	service.buy("orbs_300")
	_check(results == [true] and P.orbs_paid == 300 and P.orbs_free == 0, "purchase grants paid orbs")
	_check(not P.grant_purchase("orbs_300", P.granted_transactions[0]), "same transaction is never granted twice")
	_check(not P.grant_purchase("orbs_999", "t-x"), "unknown product refused")
	_check(P.orbs_paid == 300, "no extra orbs")


func test_mage_splash_and_spear_reach() -> void:
	var b := await _start_battle()
	var a := _enemy(Vector2(195, 300))
	var c := _enemy(Vector2(215, 300))
	var far := _enemy(Vector2(340, 300))
	for e in [a, c, far]:
		e.data = GRUNT.duplicate()
		e.data.move_speed = 0.0
		e._attack_cooldown = 1000.0
	var proj := (load(Combatant.PROJECTILE_SCENE_PATH) as PackedScene).instantiate() as Projectile
	b.effects.add_child(proj)
	proj.launch(Vector2(195, 500), a, 30, 400.0, null)
	proj.splash_radius = MAGE.splash_radius
	proj.splash_group = &"enemies"
	await _seconds(1.0)
	_check(a.hp < a.max_hp and c.hp < c.max_hp, "splash hits the target and its neighbour")
	_check(far.hp == far.max_hp, "splash does not reach far enemies")
	var spear := _ally(Vector2(100, 450), SPEARMAN)
	var t := _enemy(Vector2(100, 450 - 28 - 18))
	t.data = GRUNT.duplicate()
	t.data.move_speed = 0.0
	await _seconds(1.5)
	_check(t.hp < t.max_hp and spear.position.distance_to(t.position) > 40.0, "spear hits from further away")


func test_healer_heals_allies_and_never_attacks() -> void:
	var b := await _start_battle()
	# Only healers on the field, so any damage to the enemy would have to come from them.
	var hurt := _ally(Vector2(195, b.layout.archer_home_y), HEALER)
	var healer := _ally(Vector2(230, b.layout.archer_home_y), HEALER)
	var enemy := _enemy(Vector2(230, b.layout.archer_home_y - 60.0))
	enemy.data = GRUNT.duplicate()
	enemy.data.move_speed = 0.0
	enemy._attack_cooldown = 1000.0
	await _seconds(0.5)
	hurt.take_damage(40)
	var hp := hurt.hp
	var targeted_enemy := false
	for i in 180:
		await physics_frame
		targeted_enemy = targeted_enemy or (healer.target != null and healer.target.team == Combatant.Team.ENEMY)
	_check(hurt.hp > hp, "healer restores HP (%d -> %d)" % [hp, hurt.hp])
	_check(hurt.hp <= hurt.max_hp, "never above max")
	_check(enemy.hp == enemy.max_hp, "healer does not attack enemies")
	_check(not targeted_enemy, "healer never targets an enemy")
	_check(b.summoner.summon(SOLDIER) != null, "setup sanity")


func test_victory_beats_defeat_in_same_frame() -> void:
	var b := await _start_battle()
	b.base.take_damage(b.base.hp)
	b.notify_final_boss_defeated()
	await _frames(2)
	_check(b.result == BattleManager.Result.VICTORY, "victory has priority")
	await _wait_result(b)
	_check(b.result_ui.shown_count == 1, "result shown once")
	await _teardown()
	b = await _start_battle()
	b.notify_final_boss_defeated()
	b.base.take_damage(b.base.hp)
	await _frames(2)
	_check(b.result == BattleManager.Result.VICTORY, "victory has priority (reverse order)")
	await _wait_result(b)
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


func test_bundled_font_has_every_displayed_character() -> void:
	# Web builds have no system-font fallback: a glyph missing from the bundled font
	# shows as a box. Scan every string the game can display.
	var font := load("res://assets/fonts/DotGothic16-Japanese.woff2") as FontFile
	var files := _collect_files("res://scripts", ["gd"])
	files.append_array(_collect_files("res://scenes", ["tscn"]))
	files.append_array(_collect_files("res://resources", ["tres"]))
	var missing := {}
	var checked := 0
	for f in files:
		for line in FileAccess.get_file_as_string(f).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for i in line.length():
				var code := line.unicode_at(i)
				if code > 127:
					checked += 1
					if not font.has_char(code):
						missing[line[i]] = f
	_check(checked > 100, "scanned displayed text (%d chars)" % checked)
	_check(missing.is_empty(), "glyphs missing from the font: %s" % [missing])


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
			_check(FileAccess.file_exists(path) or ResourceLoader.exists(path) or DirAccess.dir_exists_absolute(path),
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
	b.wallet.coins = 5000
	for i in b.upgrades.upgrades.size():
		b.request_upgrade(i)
	b.request_summon(SLOT_SOLDIER)
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
	for i in fresh.upgrades.upgrades.size():
		_check(fresh.upgrades.get_level(i) == 0, "upgrade %d reset" % i)
	_check(fresh.summoner.count_per_summon == 1 and fresh.summoner.interval_multiplier == 1.0, "summon upgrades reset")
	_check(fresh.summoner.ally_attack_multiplier == 1.0 and fresh.summoner.ally_hp_multiplier == 1.0, "ally upgrades reset")
	_check(fresh.wallet.reward_multiplier == 1.0, "coin upgrade reset")
	_check(fresh.wallet.coins == fresh.wallet.starting_coins, "coins reset")
	_check(_count(&"allies") == 0, "no allies carried over")
