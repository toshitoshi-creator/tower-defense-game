class_name Combatant
extends Node2D
## Shared battle logic for every ally and enemy: targeting, movement,
## attack timing, damage, death. Subclasses only define direction and
## what happens when no opponent is in reach (see _advance()).

signal died(combatant: Combatant, killer: Node)
signal damaged(combatant: Combatant, amount: int)

enum Team { ALLY, ENEMY }
enum State { IDLE, MOVE, ATTACK, DEAD }

const GROUP_BY_TEAM := {Team.ALLY: &"allies", Team.ENEMY: &"enemies"}
## Re-scanning for targets every frame is wasteful; this keeps it cheap on phones.
const RETARGET_INTERVAL := 0.2
## Loaded lazily (not preloaded): projectile.gd references Combatant, and a preload
## here would make the two scripts load each other.
const PROJECTILE_SCENE_PATH := "res://scenes/battle/projectile.tscn"

var data: UnitData
var team: Team = Team.ALLY
var layout: BattleLayout
var max_hp: int = 1
var hp: int = 1
var attack_power: int = 0
var defense: int = 0
var state: State = State.IDLE
var target: Combatant = null

var _attack_cooldown: float = 0.0
var _retarget_timer: float = 0.0
var _effects_layer: Node = null
var _visual: CombatantVisual = null


## Multipliers scale the UnitData base stats (enemy difficulty growth, ally upgrades).
func setup(unit_data: UnitData, unit_team: Team, battle_layout: BattleLayout,
		effects_layer: Node, hp_multiplier: float = 1.0, attack_multiplier: float = 1.0) -> void:
	data = unit_data
	team = unit_team
	layout = battle_layout
	_effects_layer = effects_layer
	max_hp = maxi(1, roundi(data.max_hp * hp_multiplier))
	hp = max_hp
	attack_power = maxi(0, roundi(data.attack * attack_multiplier))
	defense = data.defense
	# Small random offset so groups don't attack in perfect lockstep.
	_attack_cooldown = randf_range(0.0, data.attack_interval * 0.3)
	_retarget_timer = randf_range(0.0, RETARGET_INTERVAL)
	add_to_group(GROUP_BY_TEAM[team])
	_visual = CombatantVisual.new()
	_visual.name = "Visual"
	add_child(_visual)
	_visual.setup(data, team == Team.ENEMY)
	_visual.set_hp_ratio(1.0)


## Re-applies stat multipliers to a living unit. A higher max HP raises current HP
## by the same amount (no full heal); a lower one never kills the unit.
func set_stat_multipliers(hp_multiplier: float, attack_multiplier: float) -> void:
	if state == State.DEAD or data == null:
		return
	var new_max := maxi(1, roundi(data.max_hp * hp_multiplier))
	hp = clampi(hp + new_max - max_hp, 1, new_max)
	max_hp = new_max
	attack_power = maxi(0, roundi(data.attack * attack_multiplier))
	_visual.set_hp_ratio(float(hp) / float(max_hp))


func is_alive() -> bool:
	return state != State.DEAD and is_inside_tree()


func get_opponent_group() -> StringName:
	return GROUP_BY_TEAM[Team.ENEMY if team == Team.ALLY else Team.ALLY]


func _physics_process(delta: float) -> void:
	if state == State.DEAD or data == null:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_retarget_timer -= delta
	if not _is_valid_target(target) or _retarget_timer <= 0.0:
		_retarget_timer = RETARGET_INTERVAL
		var found := _find_target()
		if found != null:
			target = found
		elif not _is_valid_target(target):
			target = null

	if target != null and _is_in_attack_range(target):
		_set_state(State.ATTACK)
		if _attack_cooldown <= 0.0:
			_attack(target)
	elif target != null:
		_set_state(State.MOVE)
		_move_toward(target.global_position, delta)
	else:
		_advance(delta)


## Called when no opponent is in aggro range. Default: walk forward.
func _advance(delta: float) -> void:
	_set_state(State.MOVE)
	position.y += _forward_sign() * data.move_speed * delta


func _forward_sign() -> float:
	return -1.0 if team == Team.ALLY else 1.0


func _is_valid_target(candidate: Combatant) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive():
		return false
	return global_position.distance_to(candidate.global_position) <= data.aggro_range * 1.25


## Target selection hook. Default: nearest opponent within aggro range.
func _find_target() -> Combatant:
	return _find_nearest_opponent()


func _find_nearest_opponent() -> Combatant:
	var best: Combatant = null
	var best_dist := data.aggro_range
	for node in get_tree().get_nodes_in_group(get_opponent_group()):
		var other := node as Combatant
		if other == null or not other.is_alive():
			continue
		var dist := global_position.distance_to(other.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = other
	return best


func _is_in_attack_range(other: Combatant) -> bool:
	var reach := data.attack_range + data.body_radius + other.data.body_radius
	return global_position.distance_to(other.global_position) <= reach


func _move_toward(point: Vector2, delta: float) -> void:
	var to_point := point - global_position
	var step := data.move_speed * delta
	if to_point.length() <= step:
		return
	position += to_point.normalized() * step
	if layout != null:
		position.x = layout.clamp_x(position.x, data.body_radius)


func _attack(other: Combatant) -> void:
	_attack_cooldown = data.attack_interval
	_visual.play_attack((other.global_position - global_position).normalized())
	match data.attack_type:
		UnitData.AttackType.MELEE:
			other.take_damage(attack_power, self)
		UnitData.AttackType.RANGED:
			_fire_projectile(other)


func _fire_projectile(other: Combatant) -> void:
	if _effects_layer == null:
		return
	var projectile := (load(PROJECTILE_SCENE_PATH) as PackedScene).instantiate() as Projectile
	_effects_layer.add_child(projectile)
	projectile.launch(global_position + Vector2(0, -6), other, attack_power, data.projectile_speed, self)


static func compute_damage(raw_attack: int, target_defense: int) -> int:
	return maxi(1, raw_attack - target_defense)


## Returns the damage actually dealt. Safe to call on an already-dead unit (returns 0),
## so overlapping hits can never trigger death or rewards twice.
func take_damage(raw_attack: int, source: Node = null) -> int:
	if state == State.DEAD:
		return 0
	var amount := mini(compute_damage(raw_attack, defense), hp)
	hp -= amount
	_visual.set_hp_ratio(float(hp) / float(max_hp))
	_visual.play_hurt()
	FloatingText.spawn(_effects_layer, global_position + Vector2(0, -data.body_radius - 8), str(amount),
			FloatingText.COLOR_DAMAGE_TO_ALLY if team == Team.ALLY else FloatingText.COLOR_DAMAGE_TO_ENEMY)
	damaged.emit(self, amount)
	if hp <= 0:
		_die(source)
	return amount


func _die(killer: Node) -> void:
	if state == State.DEAD:
		return
	_set_state(State.DEAD)
	hp = 0
	target = null
	# Leave the group immediately so nobody targets a corpse.
	remove_from_group(GROUP_BY_TEAM[team])
	set_physics_process(false)
	died.emit(self, killer)
	_visual.play_death(queue_free)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	_visual.set_moving(state == State.MOVE)
