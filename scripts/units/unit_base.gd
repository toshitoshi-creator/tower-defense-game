class_name UnitBase
extends Combatant
## Player-side unit. Marches upward and holds at the top of the field.
## With nothing in aggro range it hunts the enemy closest to the base, so enemies
## that slipped past the front line are chased down instead of ignored.

var _hunting: bool = false


func setup_ally(unit_data: UnitData, battle_layout: BattleLayout, effects_layer: Node) -> void:
	setup(unit_data, Team.ALLY, battle_layout, effects_layer)


func _find_target() -> Combatant:
	var local := _find_nearest_opponent()
	_hunting = local == null
	return local if local != null else _find_most_advanced_enemy()


func _is_valid_target(candidate: Combatant) -> bool:
	if _hunting:
		return candidate != null and is_instance_valid(candidate) and candidate.is_alive()
	return super._is_valid_target(candidate)


func _find_most_advanced_enemy() -> Combatant:
	var best: Combatant = null
	for node in get_tree().get_nodes_in_group(get_opponent_group()):
		var other := node as Combatant
		if other != null and other.is_alive() and (best == null or other.position.y > best.position.y):
			best = other
	return best


func _advance(delta: float) -> void:
	if position.y <= layout.ally_stop_y:
		_set_state(State.IDLE)
		return
	_set_state(State.MOVE)
	position.y = maxf(layout.ally_stop_y, position.y - data.move_speed * delta)
