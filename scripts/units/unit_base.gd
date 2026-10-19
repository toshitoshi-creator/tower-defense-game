class_name UnitBase
extends Combatant
## Player-side unit. Marches upward and holds at the top of the field.


func setup_ally(unit_data: UnitData, battle_layout: BattleLayout, effects_layer: Node) -> void:
	setup(unit_data, Team.ALLY, battle_layout, effects_layer)


func _advance(delta: float) -> void:
	if position.y <= layout.ally_stop_y:
		_set_state(State.IDLE)
		return
	_set_state(State.MOVE)
	position.y = maxf(layout.ally_stop_y, position.y - data.move_speed * delta)
