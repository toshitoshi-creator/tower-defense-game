class_name BaseController
extends Node2D
## The player's base at the bottom of the field. Owns base durability.
## Node origin is the top-left corner of the wall; enemies stop at its top edge.

signal hp_changed(hp: int, max_hp: int)
signal damaged(amount: int)
## Emitted exactly once when durability reaches 0.
signal destroyed

const HEIGHT := 64.0
const BRICK := 4.0

@export var initial_max_hp: int = 1000

var max_hp: int = 1000
var hp: int = 1000
var width: float = 390.0

var _destroyed := false
var _flash_tween: Tween


func _ready() -> void:
	reset()


func reset() -> void:
	max_hp = initial_max_hp
	hp = max_hp
	_destroyed = false
	modulate = Color.WHITE
	hp_changed.emit(hp, max_hp)
	queue_redraw()


func place(left: float, top: float, field_width: float) -> void:
	position = Vector2(left, top)
	width = field_width
	queue_redraw()


func is_destroyed() -> bool:
	return _destroyed


## Raises max durability; current durability rises by the same amount
## (the upgrade "adds" HP rather than refilling it).
func add_max_hp(amount: int) -> void:
	if _destroyed or amount <= 0:
		return
	max_hp += amount
	hp += amount
	hp_changed.emit(hp, max_hp)


## Green pulse when durability is upgraded.
func play_upgrade_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	modulate = Color(0.7, 1.8, 0.8)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.4)


func take_damage(amount: int) -> int:
	if _destroyed or amount <= 0:
		return 0
	var dealt := mini(amount, hp)
	hp -= dealt
	hp_changed.emit(hp, max_hp)
	damaged.emit(dealt)
	_flash()
	if hp <= 0:
		_destroyed = true
		destroyed.emit()
	return dealt


func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		return
	modulate = Color(2.2, 0.7, 0.7)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.18)


func _draw() -> void:
	var stone := Color(0.46, 0.44, 0.5)
	var stone_dark := Color(0.32, 0.3, 0.36)
	var outline := Color(0.08, 0.07, 0.1)
	# Crenellations.
	var merlon := BRICK * 4.0
	var x := 0.0
	while x < width:
		draw_rect(Rect2(x, 0, merlon, BRICK * 3.0), stone)
		draw_rect(Rect2(x, 0, merlon, BRICK * 3.0), outline, false, 2.0)
		x += merlon * 2.0
	# Wall body with a brick pattern.
	var top := BRICK * 3.0
	draw_rect(Rect2(0, top, width, HEIGHT - top), stone)
	var row := 0
	var y := top
	while y < HEIGHT:
		var offset := (BRICK * 2.0) if row % 2 == 1 else 0.0
		var bx := -offset
		while bx < width:
			draw_rect(Rect2(bx, y, BRICK * 4.0, BRICK * 2.0), stone_dark, false, 1.0)
			bx += BRICK * 4.0
		y += BRICK * 2.0
		row += 1
	# Gate.
	var gate_w := BRICK * 8.0
	var gate := Rect2(width * 0.5 - gate_w * 0.5, HEIGHT - BRICK * 10.0, gate_w, BRICK * 10.0)
	draw_rect(gate, Color(0.35, 0.22, 0.12))
	draw_rect(gate, outline, false, 2.0)
	draw_line(Vector2(0, top), Vector2(width, top), outline, 2.0)
