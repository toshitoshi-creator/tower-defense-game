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
## >0: also damages every member of splash_group within this radius of the impact.
var splash_radius: float = 0.0
var splash_group: StringName = &""

var _aim_point: Vector2
var _lifetime: float = 0.0
var _done: bool = false


func _ready() -> void:
	add_to_group(&"projectiles")


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
		# The shooter may have died (and been freed) while the arrow was in flight.
		var shooter: Node = source if is_instance_valid(source) else null
		target.take_damage(damage, shooter)
		if splash_radius > 0.0:
			_splash(shooter)
	queue_free()


func _splash(shooter: Node) -> void:
	PixelBurst.spawn(get_parent(), global_position, Color(0.75, 0.5, 1.0), 10, 90.0, 3.0, 0.3)
	for node in get_tree().get_nodes_in_group(splash_group):
		var other := node as Combatant
		if other != null and other != target and other.is_alive() \
				and other.global_position.distance_to(global_position) <= splash_radius + other.data.body_radius:
			other.take_damage(damage, shooter)


func _draw() -> void:
	if splash_radius > 0.0:  # Magic bolt.
		draw_rect(Rect2(-4, -4, 8, 8), Color(0.45, 0.2, 0.8))
		draw_rect(Rect2(-2, -2, 4, 4), Color(0.95, 0.85, 1.0))
		return
	draw_line(Vector2(-LENGTH, 0), Vector2(0, 0), Color(0.55, 0.36, 0.18), 2.0)
	draw_rect(Rect2(-LENGTH - 1, -2, 3, 4), Color(0.92, 0.92, 0.92))
	draw_rect(Rect2(0, -1.5, 3, 3), Color(0.86, 0.9, 0.95))
