class_name SummonButton
extends Button
## One summon slot: icon, name, total cost, units per summon and a cooldown shade.
## Always pressable so a refused tap can explain why (coins, cooldown, cap).

signal slot_pressed(slot: int)

const COST_OK := Color(1.0, 0.85, 0.3)
const COST_NG := Color(1.0, 0.35, 0.3)

var slot: int = -1

var _press_tween: Tween

@onready var icon_view: UnitIcon = $Icon
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel
@onready var count_label: Label = $CountLabel
@onready var cooldown_shade: ColorRect = $CooldownShade
@onready var cooldown_label: Label = $CooldownLabel


func _ready() -> void:
	pressed.connect(_on_pressed)


func configure(slot_index: int, data: UnitData) -> void:
	slot = slot_index
	icon_view.set_unit(data)
	name_label.text = data.display_name
	tooltip_text = data.description


## ratio: 1.0 just summoned -> 0.0 ready.
func refresh(cost: int, count: int, affordable: bool, cooldown_ratio: float,
		cooldown_remaining: float) -> void:
	cost_label.text = "%dG" % cost
	cost_label.add_theme_color_override("font_color", COST_OK if affordable else COST_NG)
	count_label.text = "×%d" % count
	var cooling := cooldown_remaining > 0.0
	cooldown_shade.visible = cooling
	cooldown_label.visible = cooling
	if cooling:
		cooldown_shade.anchor_top = 1.0 - cooldown_ratio
		cooldown_label.text = "%.1f" % cooldown_remaining
	modulate = Color.WHITE if affordable or cooling else Color(0.75, 0.75, 0.75)


func play_rejected() -> void:
	_restart_tween()
	_press_tween.tween_property(self, "position:x", position.x + 5.0, 0.04)
	_press_tween.tween_property(self, "position:x", position.x - 5.0, 0.06)
	_press_tween.tween_property(self, "position:x", position.x, 0.04)


func play_accepted() -> void:
	_restart_tween()
	pivot_offset = size * 0.5
	scale = Vector2(0.92, 0.92)
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.12)


func _restart_tween() -> void:
	if _press_tween != null and _press_tween.is_running():
		_press_tween.custom_step(10.0)
		_press_tween.kill()
	_press_tween = create_tween()


func _on_pressed() -> void:
	slot_pressed.emit(slot)
