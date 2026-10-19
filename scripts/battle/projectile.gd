class_name Projectile
extends Node2D
## Homing projectile (arrows). Damage is applied once, on arrival, and only if the
## target is still alive; if the target dies mid-flight the arrow lands where the
## target was and disappears without effect.

const MAX_LIFETIME := 3.0
const LENGTH := 10.0

var damage: int = 0
var speed: float = 260.0
var target: Combatant
var source: Node

var _aim_point: Vector2
var _lifetime: float = 0.0
var _done: bool = false


func launch(from: Vector2, to: Combatant, raw_damage: int, flight_speed: float, shooter: Node) -> void:
	global_position = from
	target = to
	damage = raw_damage
	speed = flight_speed
	source = shooter
	_aim_point = to.global_position
	rotation = (_aim_point - from).angle()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_lifetime += delta
	if _target_alive():
		_aim_point = target.global_position
	var to_aim := _aim_point - global_position
	var step := speed * delta
	if to_aim.length() <= step or _lifetime >= MAX_LIFETIME:
		_arrive()
		return
	rotation = to_aim.angle()
	global_position += to_aim.normalized() * step


func _target_alive() -> bool:
	return target != null and is_instance_valid(target) and target.is_alive()


func _arrive() -> void:
	_done = true
	if _target_alive() and _lifetime < MAX_LIFETIME:
		target.take_damage(damage, source)
	queue_free()


func _draw() -> void:
	draw_line(Vector2(-LENGTH, 0), Vector2(0, 0), Color(0.55, 0.36, 0.18), 2.0)
	draw_rect(Rect2(-LENGTH - 1, -2, 3, 4), Color(0.92, 0.92, 0.92))
	draw_rect(Rect2(0, -1.5, 3, 3), Color(0.86, 0.9, 0.95))
