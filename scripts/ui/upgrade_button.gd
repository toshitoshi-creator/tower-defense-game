class_name UpgradeButton
extends Button
## One upgrade: name + level, next-level cost, and current -> next effect.

signal upgrade_pressed(index: int)

const COST_OK := Color(1.0, 0.85, 0.3)
const COST_NG := Color(1.0, 0.35, 0.3)

var index: int = -1

var _tween: Tween

@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var effect_label: Label = $EffectLabel


func _ready() -> void:
	pressed.connect(func() -> void: upgrade_pressed.emit(index))


func refresh(title: String, level: int, current_effect: String, next_effect: String,
		cost: int, affordable: bool) -> void:
	name_label.text = "%s Lv%d" % [title, level]
	if cost < 0:
		cost_label.text = "MAX"
		cost_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		effect_label.text = current_effect
		modulate = Color(0.8, 0.8, 0.8)
		return
	cost_label.text = "%dG" % cost
	cost_label.add_theme_color_override("font_color", COST_OK if affordable else COST_NG)
	effect_label.text = "%s ＞ %s" % [current_effect, next_effect]
	modulate = Color.WHITE if affordable else Color(0.75, 0.75, 0.75)


func play_feedback(accepted: bool) -> void:
	if _tween != null and _tween.is_running():
		_tween.custom_step(10.0)
		_tween.kill()
	_tween = create_tween()
	if accepted:
		pivot_offset = size * 0.5
		scale = Vector2(0.94, 0.94)
		_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	else:
		var x := position.x
		_tween.tween_property(self, "position:x", x + 5.0, 0.04)
		_tween.tween_property(self, "position:x", x - 5.0, 0.06)
		_tween.tween_property(self, "position:x", x, 0.04)
