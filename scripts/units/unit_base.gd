class_name UnitBase
extends Combatant
## Player-side unit. Positioning depends on UnitData.role (see UnitData.Role):
## - ASSAULT (soldier): fights whatever is in aggro range; otherwise goes out to meet the
##   enemy closest to the base once it has crossed the front line (layout.assault_limit_y);
##   with nothing to fight it returns to the rally point in front of the base.
## - GUARD (shield): holds a post on the defense line (posts are spread evenly across
##   the width); engages enemies near its post or enemies attacking a nearby ally.
## - SUPPORT (archer): stands behind the assault line and attacks only what is in
##   range; it never steps forward to chase.

## Guards engage enemies this close to their post...
const GUARD_RADIUS := 110.0
## ...or enemies attacking an ally this close to the guard...
const PROTECT_RADIUS := 150.0
## ...but never chase further than this from the post.
const GUARD_LEASH := 190.0
## Support units stand this far behind the engaged assault units.
const SUPPORT_BEHIND := 70.0
## Units gathered at a home point spread out this much so they don't stack.
const HOME_SPREAD := 70.0
const ARRIVE_DISTANCE := 3.0

var _hunting: bool = false
var _home_offset: Vector2 = Vector2.ZERO
## Where this unit stands when it has nothing in reach (refreshed at retarget time).
var _station: Vector2 = Vector2.ZERO


func setup_ally(unit_data: UnitData, battle_layout: BattleLayout, effects_layer: Node,
		hp_multiplier: float = 1.0, attack_multiplier: float = 1.0) -> void:
	setup(unit_data, Team.ALLY, battle_layout, effects_layer, hp_multiplier, attack_multiplier)
	_home_offset = Vector2(randf_range(-HOME_SPREAD, HOME_SPREAD), randf_range(-12.0, 12.0))


func get_station() -> Vector2:
	return _station


func _find_target() -> Combatant:
	_station = _compute_station()
	match data.role:
		UnitData.Role.GUARD:
			_hunting = false
			return _find_guard_target()
		UnitData.Role.SUPPORT:
			_hunting = false
			return _find_nearest_opponent()
	var local := _find_nearest_opponent()
	_hunting = local == null
	if local != null:
		return local
	var advanced := _find_most_advanced_enemy()
	if advanced != null and advanced.position.y >= layout.assault_limit_y:
		return advanced
	return null


func _is_valid_target(candidate: Combatant) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive():
		return false
	match data.role:
		UnitData.Role.GUARD:
			return candidate.global_position.distance_to(_station) <= GUARD_LEASH
		UnitData.Role.SUPPORT:
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


func _compute_station() -> Vector2:
	var center := layout.center_x()
	match data.role:
		UnitData.Role.GUARD:
			return Vector2(_guard_post_x(), layout.guard_y)
		UnitData.Role.SUPPORT:
			var line := _engaged_assault_center()
			if is_nan(line.y):
				return Vector2(layout.clamp_x(center + _home_offset.x * 1.6, 20.0),
						layout.archer_home_y + _home_offset.y * 0.5)
			# Line up behind where the soldiers are actually fighting.
			return Vector2(layout.clamp_x(line.x + _home_offset.x * 0.6, 20.0),
					clampf(line.y + SUPPORT_BEHIND, layout.archer_limit_y, layout.archer_home_y))
	return Vector2(layout.clamp_x(center + _home_offset.x, 20.0), layout.rally_y + _home_offset.y)


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


## Guards share the defense line evenly, ordered by creation.
func _guard_post_x() -> float:
	var index := 0
	var count := 0
	for node in get_tree().get_nodes_in_group(&"allies"):
		var ally := node as UnitBase
		if ally == null or not ally.is_alive() or ally.data.role != UnitData.Role.GUARD:
			continue
		if ally.get_instance_id() < get_instance_id():
			index += 1
		count += 1
	var width := layout.right - layout.left
	return layout.left + width * (index + 1) / (count + 1)


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


func _find_most_advanced_enemy() -> Combatant:
	var best: Combatant = null
	for node in get_tree().get_nodes_in_group(get_opponent_group()):
		var other := node as Combatant
		if other != null and other.is_alive() and (best == null or other.position.y > best.position.y):
			best = other
	return best
