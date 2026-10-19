class_name CombatantVisual
extends Node2D
## Visual for a Combatant: an AnimatedSprite2D playing idle / move / attack / hurt / death.
## Frames come from UnitData.sprite_frames when real art exists, otherwise from the
## generated pixel-art placeholder (PixelArt.build_sprite_frames). Lunges, flashes and
## the death fade are tweens, so nothing here runs per frame.

const HP_BAR_WIDTH := 22.0
const HP_BAR_HEIGHT := 3.0

var _sprite: AnimatedSprite2D
var _hp_bar: _HpBar
## Looping animation to return to after attack/hurt (idle or move).
var _base_anim: StringName = PixelArt.ANIM_IDLE
var _dying: bool = false
var _action_tween: Tween
var _flash_tween: Tween


func setup(data: UnitData, is_enemy: bool) -> void:
	_sprite = AnimatedSprite2D.new()
	if data.sprite_frames != null:
		_sprite.sprite_frames = data.sprite_frames
	else:
		_sprite.sprite_frames = PixelArt.build_sprite_frames(data)
		_sprite.scale = Vector2.ONE * maxi(1, data.pixel_scale)
	_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_sprite)
	_play(PixelArt.ANIM_IDLE)
	# Desynchronise identical units so a crowd doesn't breathe in unison.
	_sprite.frame = randi() % maxi(1, _sprite.sprite_frames.get_frame_count(PixelArt.ANIM_IDLE))

	_hp_bar = _HpBar.new()
	_hp_bar.fill_color = Color(0.95, 0.3, 0.25) if is_enemy else Color(0.35, 0.9, 0.4)
	# Bigger units (bosses) get a wider bar placed above their sprite.
	_hp_bar.width = maxf(HP_BAR_WIDTH, data.body_radius * 2.0)
	var half_height := maxf(data.body_radius,
			PixelArt.get_size(data.placeholder_pattern, maxi(1, data.pixel_scale)).y * 0.5)
	_hp_bar.position = Vector2(-_hp_bar.width * 0.5, -half_height - 6.0)
	add_child(_hp_bar)


func get_current_animation() -> StringName:
	return _sprite.animation


func set_hp_ratio(ratio: float) -> void:
	_hp_bar.ratio = clampf(ratio, 0.0, 1.0)
	_hp_bar.visible = ratio < 1.0 and ratio > 0.0
	_hp_bar.queue_redraw()


func set_moving(moving: bool) -> void:
	_base_anim = PixelArt.ANIM_MOVE if moving else PixelArt.ANIM_IDLE
	# Don't cut a running attack/hurt short; it returns to the base anim when done.
	if _sprite.animation == PixelArt.ANIM_IDLE or _sprite.animation == PixelArt.ANIM_MOVE:
		_play(_base_anim)


func play_attack(direction: Vector2) -> void:
	_play(PixelArt.ANIM_ATTACK)
	if _action_tween != null:
		_action_tween.kill()
	_sprite.position = Vector2.ZERO
	_action_tween = create_tween()
	_action_tween.tween_property(_sprite, "position", direction * 5.0, 0.07)
	_action_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.12)


func play_hurt() -> void:
	_play(PixelArt.ANIM_HURT)
	if _flash_tween != null:
		_flash_tween.kill()
	_sprite.modulate = Color(2.0, 0.6, 0.6)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func play_death(on_finished: Callable) -> void:
	_dying = true
	for t in [_action_tween, _flash_tween]:
		if t != null:
			(t as Tween).kill()
	_sprite.modulate = Color.WHITE
	_hp_bar.visible = false
	_play(PixelArt.ANIM_DEATH)
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(on_finished)


func _play(anim: StringName) -> void:
	if _dying and anim != PixelArt.ANIM_DEATH:
		return
	if _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
	elif anim != _base_anim and _sprite.sprite_frames.has_animation(_base_anim):
		_sprite.play(_base_anim)


func _on_animation_finished() -> void:
	if not _dying:
		_play(_base_anim)


class _HpBar extends Node2D:
	var ratio: float = 1.0
	var fill_color: Color = Color.GREEN
	var width: float = CombatantVisual.HP_BAR_WIDTH

	func _draw() -> void:
		var w := width
		var h := CombatantVisual.HP_BAR_HEIGHT
		draw_rect(Rect2(-1, -1, w + 2, h + 2), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(0, 0, w * ratio, h), fill_color)
