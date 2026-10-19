class_name BattleUI
extends CanvasLayer
## In-battle HUD: top bar (stage, time, coins, kills, pause) and bottom panel
## (base durability, summon buttons).
## Pure view: it emits requests and the BattleManager decides what happens.

signal pause_requested
signal resume_requested
signal summon_slot_pressed(slot: int)
## Emitted when the HUD's size or safe-area margins change, so the field can re-layout.
signal layout_changed

@onready var root: Control = $Root
@onready var top_bar: Control = $Root/TopBar
@onready var bottom_panel: Control = $Root/BottomPanel
@onready var time_label: Label = $Root/TopBar/Row/TimeLabel
@onready var coin_label: Label = $Root/TopBar/Row/CoinLabel
@onready var kills_label: Label = $Root/TopBar/Row/KillsLabel
@onready var pause_button: Button = $Root/TopBar/Row/PauseButton
@onready var base_hp_bar: ProgressBar = $Root/BottomPanel/Column/BaseRow/BaseHpBar
@onready var base_hp_label: Label = $Root/BottomPanel/Column/BaseRow/BaseHpBar/BaseHpLabel
@onready var summon_row: HBoxContainer = $Root/BottomPanel/Column/SummonRow
@onready var toast: Label = $Root/Toast
@onready var damage_flash: ColorRect = $DamageFlash
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/Center/Column/ResumeButton

const SUMMON_BUTTON_SCENE := preload("res://scenes/ui/summon_button.tscn")

var summon_buttons: Array[SummonButton] = []

var _flash_tween: Tween
var _toast_tween: Tween


func _ready() -> void:
	pause_button.pressed.connect(pause_requested.emit)
	resume_button.pressed.connect(resume_requested.emit)
	top_bar.resized.connect(layout_changed.emit)
	bottom_panel.resized.connect(layout_changed.emit)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	set_time(0.0)
	set_kills(0)
	set_coins(0)
	show_pause_overlay(false)


func get_field_top() -> float:
	return top_bar.get_global_rect().end.y


func get_field_bottom() -> float:
	return bottom_panel.get_global_rect().position.y


func set_time(seconds: float) -> void:
	time_label.text = BattleClock.format_time(seconds)


func set_coins(coins: int) -> void:
	coin_label.text = "● %d" % coins


func setup_summon_buttons(roster: Array[UnitData]) -> void:
	for b in summon_buttons:
		b.queue_free()
	summon_buttons.clear()
	for i in roster.size():
		var button := SUMMON_BUTTON_SCENE.instantiate() as SummonButton
		summon_row.add_child(button)
		button.configure(i, roster[i])
		button.slot_pressed.connect(summon_slot_pressed.emit)
		summon_buttons.append(button)


func refresh_summon_button(slot: int, cost: int, count: int, affordable: bool,
		cooldown_ratio: float, cooldown_remaining: float) -> void:
	summon_buttons[slot].refresh(cost, count, affordable, cooldown_ratio, cooldown_remaining)


func show_summon_result(slot: int, accepted: bool, message: String = "") -> void:
	if slot >= 0 and slot < summon_buttons.size():
		if accepted:
			summon_buttons[slot].play_accepted()
		else:
			summon_buttons[slot].play_rejected()
	if not message.is_empty():
		show_toast(message)


func show_toast(message: String) -> void:
	toast.text = message
	toast.offset_bottom = -bottom_panel.size.y - 8.0
	toast.offset_top = toast.offset_bottom - 30.0
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(toast.hide)


func set_kills(count: int) -> void:
	kills_label.text = "撃破 %d" % count


func set_base_hp(hp: int, max_hp: int) -> void:
	base_hp_bar.max_value = max_hp
	base_hp_bar.value = hp
	base_hp_label.text = "陣地 %d / %d" % [hp, max_hp]


func flash_damage() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		return
	damage_flash.color.a = 0.22
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.25)


func show_pause_overlay(visible_now: bool) -> void:
	pause_overlay.visible = visible_now


func _apply_safe_area() -> void:
	var m := SafeArea.get_margins(get_viewport())
	root.offset_left = m.left
	root.offset_top = m.top
	root.offset_right = -m.right
	root.offset_bottom = -m.bottom
	layout_changed.emit()
