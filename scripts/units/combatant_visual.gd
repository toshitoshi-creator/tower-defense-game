class_name CombatantVisual
extends Node2D
## Visual for a Combatant. Uses UnitData.sprite_frames when provided; otherwise draws a
## procedural pixel-art placeholder (PixelArt). Animations (move bob, attack lunge,
## hurt flash, death fade) are tweens, so nothing here runs per frame.

const HP_BAR_WIDTH := 22.0
const HP_BAR_HEIGHT := 3.0

var _body: Node2D
var _hp_bar: _HpBar
var _sprite: AnimatedSprite2D
var _move_tween: Tween
var _action_tween: Tween
var _flash_tween: Tween


func setup(data: UnitData, is_enemy: bool) -> void:
	if data.sprite_frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = data.sprite_frames
		_body = _sprite
		_play_anim(&"idle")
	else:
		var pixel_body := _PixelBody.new()
		pixel_body.configure(data)
		_body = pixel_body
	add_child(_body)
	_hp_bar = _HpBar.new()
	_hp_bar.fill_color = Color(0.95, 0.3, 0.25) if is_enemy else Color(0.35, 0.9, 0.4)
	_hp_bar.position = Vector2(-HP_BAR_WIDTH * 0.5, -data.body_radius - 10.0)
	add_child(_hp_bar)


func set_hp_ratio(ratio: float) -> void:
	_hp_bar.ratio = clampf(ratio, 0.0, 1.0)
	_hp_bar.visible = ratio < 1.0 and ratio > 0.0
	_hp_bar.queue_redraw()


func set_moving(moving: bool) -> void:
	if _move_tween != null:
		_move_tween.kill()
		_move_tween = null
	_body.rotation = 0.0
	if not moving:
		_play_anim(&"idle")
		return
	_play_anim(&"move")
	_move_tween = create_tween().set_loops()
	_move_tween.tween_property(_body, "rotation", 0.08, 0.18)
	_move_tween.tween_property(_body, "rotation", -0.08, 0.18)


func play_attack(direction: Vector2) -> void:
	_play_anim(&"attack")
	if _action_tween != null:
		_action_tween.kill()
	_body.position = Vector2.ZERO
	_action_tween = create_tween()
	_action_tween.tween_property(_body, "position", direction * 5.0, 0.07)
	_action_tween.tween_property(_body, "position", Vector2.ZERO, 0.12)


func play_hurt() -> void:
	_play_anim(&"hurt")
	if _flash_tween != null:
		_flash_tween.kill()
	_body.modulate = Color(2.0, 0.6, 0.6)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_body, "modulate", Color.WHITE, 0.15)


func play_death(on_finished: Callable) -> void:
	for t in [_move_tween, _action_tween, _flash_tween]:
		if t != null:
			(t as Tween).kill()
	_hp_bar.visible = false
	_play_anim(&"death")
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_property(self, "scale", Vector2(1.3, 0.3), 0.35)
	tween.chain().tween_callback(on_finished)


func _play_anim(anim: StringName) -> void:
	if _sprite != null and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)


class _PixelBody extends Node2D:
	var _data: UnitData

	func configure(data: UnitData) -> void:
		_data = data
		queue_redraw()

	func _draw() -> void:
		PixelArt.draw_unit(self, _data, Vector2.ZERO, maxi(1, _data.pixel_scale))


class _HpBar extends Node2D:
	var ratio: float = 1.0
	var fill_color: Color = Color.GREEN

	func _draw() -> void:
		var w := CombatantVisual.HP_BAR_WIDTH
		var h := CombatantVisual.HP_BAR_HEIGHT
		draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(0, 0, w * ratio, h), fill_color)
