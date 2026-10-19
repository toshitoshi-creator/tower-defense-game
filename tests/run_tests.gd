extends SceneTree
## Headless test runner for phase 1.
## Usage: godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
## --fixed-fps 60 makes every physics frame exactly 1/60 s, so frame counts == game time.
## Exit code: 0 when all tests pass, 1 otherwise.

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const SOLDIER: UnitData = preload("res://resources/units/soldier.tres")
const GRUNT: UnitData = preload("res://resources/enemies/grunt.tres")
const FPS := 60

var _failures: Array[String] = []
var _current := ""
var _battle: BattleManager


func _initialize() -> void:
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


## Creates a battle. With manual=true, automatic spawning/deploying is off so the
## test controls exactly which units exist.
func _start_battle(manual: bool = true) -> BattleManager:
	_battle = BATTLE_SCENE.instantiate() as BattleManager
	if manual:
		_battle.get_node("EnemySpawner").auto_spawn = false
		_battle.get_node("SummonManager").auto_deploy = false
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


func test_auto_spawn_creates_enemies_and_allies() -> void:
	await _start_battle(false)
	await _seconds(5.0)
	_check(_count(&"enemies") > 0, "enemies should spawn automatically")
	_check(_count(&"allies") > 0, "allies should deploy automatically (phase 1)")


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
	var enemy := _enemy(Vector2(330, b.layout.base_line_y - 30.0))
	await _seconds(3.0)
	_check(is_equal_approx(ally.position.y, b.layout.ally_stop_y), "ally should hold at top line")
	_check(is_equal_approx(enemy.position.y, b.layout.base_line_y), "enemy should hold at base line")


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
	b.summoner.auto_deploy = true
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
	b.base.take_damage(100)
	b.notify_final_boss_defeated()
	await _frames(2)
	_check(b.result == BattleManager.Result.DEFEAT and b.result_ui.shown_count == 1,
			"later end requests are ignored")


func test_natural_battle_eventually_ends_in_defeat() -> void:
	# No player input in phase 1: enemy scaling must overwhelm the auto-deployed allies.
	var b := await _start_battle(false)
	var limit := 8.0 * 60.0
	while b.phase != BattleManager.Phase.ENDED and b.clock.elapsed < limit:
		await _seconds(5.0)
	_check(b.phase == BattleManager.Phase.ENDED, "battle should end within %d s" % int(limit))
	_check(b.result == BattleManager.Result.DEFEAT, "result should be defeat")
	_check(b.kills > 0, "allies should have killed enemies")
	print("        natural defeat at %s, kills=%d, peak counts ok" % [BattleClock.format_time(b.clock.elapsed), b.kills])
	_check(_count(&"enemies") <= b.spawner.max_alive, "enemy cap respected")
	_check(_count(&"allies") <= b.summoner.max_alive, "ally cap respected")


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
	root.size = Vector2i(390, 844)


func test_pixel_patterns_are_rectangular() -> void:
	for key in CombatantVisual.PATTERNS:
		var rows: Array = CombatantVisual.PATTERNS[key]
		var width := (rows[0] as String).length()
		for r in rows:
			_check((r as String).length() == width, "pattern %s row '%s' width" % [key, r])
			for ch in (r as String):
				_check(ch == "." or ch == "b" or ch == "a" or CombatantVisual.FIXED_COLORS.has(ch),
						"pattern %s unknown key %s" % [key, ch])
	for d in [SOLDIER, GRUNT]:
		_check(CombatantVisual.PATTERNS.has((d as UnitData).placeholder_pattern),
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
