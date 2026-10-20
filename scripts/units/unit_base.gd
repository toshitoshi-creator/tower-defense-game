class_name UnitBase
extends Combatant
## Player-side unit. Positioning depends on UnitData.role (see UnitData.Role):
## - ASSAULT (soldier): fights whatever is in aggro range; otherwise goes out to meet the
##   nearest enemy that has crossed the front line (layout.assault_limit_y);
##   with nothing to fight it returns to the rally point in front of the base.
## - GUARD (shield): holds a post on the defense line (posts are spread evenly across
##   the width); engages enemies near its post or enemies attacking a nearby ally.
## - SUPPORT (archer, mage, healer): stands behind the assault line and acts only on
##   what is in range; it never steps forward to chase. Healers target hurt allies.

## Guards engage enemies this close to their post...
const GUARD_RADIUS := 110.0
## ...or enemies attacking an ally this close to the guard...
const PROTECT_RADIUS := 150.0
## ...but never chase further than this from the post.
const GUARD_LEASH := 190.0
## Support units stand this far behind the engaged assault units.
const SUPPORT_BEHIND := 70.0
## How much of their idle spread archers keep while gathered behind a fight.
const SUPPORT_SPREAD := 0.35
const ARRIVE_DISTANCE := 3.0
## A role's idle line splits into two staggered rows above this many units.
const MAX_PER_ROW := 8
const ROW_GAP := 20.0

## Character level bonus (gacha duplicates), multiplied into HP and attack.
var level_bonus: float = 1.0

var _hunting: bool = false
## Where this unit stands when it has nothing in reach (refreshed at retarget time).
var _station: Vector2 = Vector2.ZERO


func setup_ally(unit_data: UnitData, battle_layout: BattleLayout, effects_layer: Node,
		hp_multiplier: float = 1.0, attack_multiplier: float = 1.0, character_bonus: float = 1.0) -> void:
	level_bonus = character_bonus
	setup(unit_data, Team.ALLY, battle_layout, effects_layer,
			hp_multiplier * level_bonus, attack_multiplier * level_bonus)


func get_station() -> Vector2:
	return _station


func set_stat_multipliers(hp_multiplier: float, attack_multiplier: float) -> void:
	super.set_stat_multipliers(hp_multiplier * level_bonus, attack_multiplier * level_bonus)


func is_healer() -> bool:
	return data.attack_type == UnitData.AttackType.HEAL


func _find_target() -> Combatant:
	_station = _compute_station()
	match data.role:
		UnitData.Role.GUARD:
			_hunting = false
			return _find_guard_target()
		UnitData.Role.SUPPORT:
			_hunting = false
			return _find_heal_target() if is_healer() else _find_nearest_opponent()
	var local := _find_nearest_opponent()
	_hunting = local == null
	if local != null:
		return local
	return _find_nearest_past_front_line()


func _is_valid_target(candidate: Combatant) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive():
		return false
	match data.role:
		UnitData.Role.GUARD:
			return candidate.global_position.distance_to(_station) <= GUARD_LEASH
		UnitData.Role.SUPPORT:
			if is_healer():
				return candidate.team == Team.ALLY and candidate.hp < candidate.max_hp \
						and global_position.distance_to(candidate.global_position) <= data.aggro_range * 1.25
			return super._is_valid_target(candidate)
	if _hunting:
		return candidate.position.y >= layout.assault_limit_y - 40.0
	return super._is_valid_target(candidate)


## Support units hold their line instead of walking into melee.
func _approach(other: Combatant, delta: float) -> void:
	if data.role == UnitData.Role.SUPPORT:
		_go_to(_station, delta)
	else:
		super._approach(other, delta)


func _advance(delta: float) -> void:
	_go_to(_station, delta)


func _go_to(point: Vector2, delta: float) -> void:
	var to_point := point - position
	if to_point.length() <= ARRIVE_DISTANCE:
		_set_state(State.IDLE)
		return
	_set_state(State.MOVE)
	position += to_point.limit_length(data.move_speed * delta)


## Idle positions: every role spreads evenly across the width on its own line
## (soldiers in front, then shields, archers nearest the wall).
func _compute_station() -> Vector2:
	var slot := _line_slot()
	match data.role:
		UnitData.Role.GUARD:
			return Vector2(slot.x, layout.guard_y + slot.y)
		UnitData.Role.SUPPORT:
			var line := _engaged_assault_center()
			if is_nan(line.y):
				return Vector2(slot.x, layout.archer_home_y + slot.y)
			# Gather behind the fighting soldiers (concentrated fire), keeping each
			# archer's left-to-right order from its line slot so they don't stack.
			return Vector2(layout.clamp_x(line.x + (slot.x - layout.center_x()) * SUPPORT_SPREAD, 16.0),
					clampf(line.y + SUPPORT_BEHIND, layout.archer_limit_y, layout.archer_home_y))
	return Vector2(slot.x, layout.rally_y + slot.y)


## Average position of assault allies currently fighting, or (NAN, NAN) when none are.
func _engaged_assault_center() -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for node in get_tree().get_nodes_in_group(&"allies"):
		var ally := node as UnitBase
		if ally != null and ally.is_alive() and ally.data.role == UnitData.Role.ASSAULT \
				and ally.target != null:
			total += ally.position
			count += 1
	return total / count if count > 0 else Vector2(NAN, NAN)


## This unit's place on its role's line: x spread evenly across the width (ordered by
## creation), y offset for a second staggered row when the line gets crowded.
func _line_slot() -> Vector2:
	var index := 0
	var count := 0
	for node in get_tree().get_nodes_in_group(&"allies"):
		var ally := node as UnitBase
		if ally == null or not ally.is_alive() or ally.data.role != data.role:
			continue
		if ally.get_instance_id() < get_instance_id():
			index += 1
		count += 1
	var rows := 2 if count > MAX_PER_ROW else 1
	var row := index % rows
	var columns := ceili(float(count) / rows)
	var column := floori(float(index) / rows)
	var width := layout.right - layout.left
	var x := layout.left + width * (column + 1) / (columns + 1)
	if rows == 2 and row == 1:
		x += width / (columns + 1) * 0.5  # Stagger the back row between the front ones.
	return Vector2(layout.clamp_x(x, 16.0), (row - (rows - 1) * 0.5) * ROW_GAP)


func _find_guard_target() -> Combatant:
	var best: Combatant = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(get_opponent_group()):
		var enemy := node as Combatant
		if enemy == null or not enemy.is_alive():
			continue
		var from_post := enemy.global_position.distance_to(_station)
		if from_post > GUARD_LEASH:
			continue
		var threat := from_post <= GUARD_RADIUS + enemy.data.body_radius
		if not threat and enemy.target != null and is_instance_valid(enemy.target) \
				and enemy.target.is_alive() and enemy.target.team == Team.ALLY:
			threat = enemy.target.global_position.distance_to(global_position) <= PROTECT_RADIUS
		if not threat:
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


## The most hurt ally (by HP ratio) within aggro range, including itself.
func _find_heal_target() -> Combatant:
	var best: Combatant = null
	var best_ratio := 1.0
	for node in get_tree().get_nodes_in_group(&"allies"):
		var ally := node as Combatant
		if ally == null or not ally.is_alive() or ally.hp >= ally.max_hp:
			continue
		if global_position.distance_to(ally.global_position) > data.aggro_range:
			continue
		var ratio := float(ally.hp) / float(ally.max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best


## The enemy closest to this unit among those that crossed the front line, so a
## spread-out line answers threats on its own side instead of converging on one.
func _find_nearest_past_front_line() -> Combatant:
	var best: Combatant = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group(get_opponent_group()):
		var other := node as Combatant
		if other == null or not other.is_alive() or other.position.y < layout.assault_limit_y:
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist < best_dist:
			best_dist = dist
			best = other
	return best
