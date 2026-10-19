class_name EnemyBase
extends Combatant
## Enemy-side unit. Marches downward; on reaching the base line it attacks the base.

## Emitted exactly once, when this enemy dies. Carries the reward for the kill.
signal defeated(enemy: EnemyBase, reward: int)

var _base: BaseController = null


func setup_enemy(unit_data: UnitData, battle_layout: BattleLayout, effects_layer: Node,
		base: BaseController, stat_multiplier: float = 1.0) -> void:
	_base = base
	setup(unit_data, Team.ENEMY, battle_layout, effects_layer, stat_multiplier, stat_multiplier)
	if unit_data.is_boss:
		z_index = 1  # Draw above the crowd so the boss is always readable.


func is_at_base() -> bool:
	return position.y >= layout.base_line_y


func _advance(delta: float) -> void:
	if not is_at_base():
		super._advance(delta)
		position.y = minf(position.y, layout.base_line_y)
		return
	_set_state(State.ATTACK)
	if _attack_cooldown <= 0.0 and _base != null and not _base.is_destroyed():
		_attack_cooldown = data.attack_interval
		_visual.play_attack(Vector2.DOWN)
		_base.take_damage(attack_power)


func _die(killer: Node) -> void:
	if state == State.DEAD:
		return
	super._die(killer)
	defeated.emit(self, data.reward)
