class_name BattleUI
extends CanvasLayer
## In-battle HUD: top bar (stage, time, coins, kills, pause) and bottom panel
## (base durability, summon buttons, upgrade drawer toggle). The upgrade drawer opens
## above the bottom panel without pausing the battle.
## Pure view: it emits requests and the BattleManager decides what happens.

signal pause_requested
signal resume_requested
signal summon_slot_pressed(slot: int)
signal upgrade_pressed(index: int)
## Emitted when the HUD's size or safe-area margins change, so the field can re-layout.
signal layout_changed

@onready var root: Control = $Root
@onready var top_bar: Control = $Root/TopBar
@onready var bottom_panel: Control = $Root/BottomPanel
@onready var time_label: Label = $Root/TopBar/Stack/Row/TimeLabel
@onready var coin_label: Label = $Root/TopBar/Stack/Row/CoinLabel
@onready var kills_label: Label = $Root/TopBar/Stack/Row/KillsLabel
@onready var pause_button: Button = $Root/TopBar/Stack/Row/PauseButton
@onready var base_hp_bar: ProgressBar = $Root/BottomPanel/Column/BaseRow/BaseHpBar
@onready var base_hp_label: Label = $Root/BottomPanel/Column/BaseRow/BaseHpBar/BaseHpLabel
@onready var summon_row: HBoxContainer = $Root/BottomPanel/Column/SummonRow
@onready var toast: Label = $Root/Toast
@onready var boss_name_label: Label = $Root/TopBar/Stack/BossRow/BossNameLabel
@onready var boss_hp_bar: ProgressBar = $Root/TopBar/Stack/BossRow/BossHpBar
@onready var banner: Label = $Root/Banner
@onready var upgrade_toggle: Button = $Root/BottomPanel/Column/BaseRow/UpgradeToggle
@onready var upgrade_panel: Control = $Root/UpgradePanel
@onready var upgrade_grid: GridContainer = $Root/UpgradePanel/Grid
@onready var damage_flash: ColorRect = $DamageFlash
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/Center/Column/ResumeButton

const SUMMON_BUTTON_SCENE := preload("res://scenes/ui/summon_button.tscn")
const UPGRADE_BUTTON_SCENE := preload("res://scenes/ui/upgrade_button.tscn")

var summon_buttons: Array[SummonButton] = []
var upgrade_buttons: Array[UpgradeButton] = []

var _flash_tween: Tween
var _toast_tween: Tween
var _banner_tween: Tween


func _ready() -> void:
	pause_button.pressed.connect(pause_requested.emit)
	resume_button.pressed.connect(resume_requested.emit)
	upgrade_toggle.toggled.connect(set_upgrade_panel_open)
	bottom_panel.resized.connect(_place_upgrade_panel)
	top_bar.resized.connect(layout_changed.emit)
	bottom_panel.resized.connect(layout_changed.emit)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	set_time(0.0)
	set_kills(0)
	set_coins(0)
	show_pause_overlay(false)
	set_upgrade_panel_open(false)
	show_boss_countdown("")


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


func setup_upgrade_buttons(upgrades: Array[UpgradeData]) -> void:
	for b in upgrade_buttons:
		b.queue_free()
	upgrade_buttons.clear()
	for i in upgrades.size():
		var button := UPGRADE_BUTTON_SCENE.instantiate() as UpgradeButton
		upgrade_grid.add_child(button)
		button.index = i
		button.upgrade_pressed.connect(upgrade_pressed.emit)
		upgrade_buttons.append(button)


## cost < 0 means max level.
func refresh_upgrade_button(index: int, title: String, level: int, current_effect: String,
		next_effect: String, cost: int, affordable: bool) -> void:
	upgrade_buttons[index].refresh(title, level, current_effect, next_effect, cost, affordable)


func show_upgrade_result(index: int, accepted: bool, message: String) -> void:
	if index >= 0 and index < upgrade_buttons.size():
		upgrade_buttons[index].play_feedback(accepted)
	show_toast(message)


func is_upgrade_panel_open() -> bool:
	return upgrade_panel.visible


func set_upgrade_panel_open(open: bool) -> void:
	upgrade_panel.visible = open
	upgrade_toggle.set_pressed_no_signal(open)
	upgrade_toggle.text = "強化 ▼" if open else "強化 ▲"
	_place_upgrade_panel()


func _place_upgrade_panel() -> void:
	upgrade_panel.offset_bottom = -bottom_panel.size.y
	upgrade_panel.offset_top = upgrade_panel.offset_bottom - upgrade_panel.get_combined_minimum_size().y


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
	var covered := bottom_panel.size.y + (upgrade_panel.size.y if upgrade_panel.visible else 0.0)
	toast.offset_bottom = -covered - 8.0
	toast.offset_top = toast.offset_bottom - 30.0
	toast.visible = true
	toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(toast.hide)


## The boss row lives inside the top bar (it never covers the field) and is always
## present, so the layout doesn't shift when a boss appears.
## Shows a living boss's HP. `ratio` is current/max HP.
func show_boss_bar(boss_name: String, ratio: float) -> void:
	boss_name_label.text = boss_name
	boss_hp_bar.value = clampf(ratio, 0.0, 1.0)
	boss_hp_bar.modulate.a = 1.0


## No boss alive: shows the time to the next boss instead (empty text = nothing).
func show_boss_countdown(text_value: String) -> void:
	boss_name_label.text = text_value
	boss_hp_bar.modulate.a = 0.0


func is_boss_bar_shown() -> bool:
	return boss_hp_bar.modulate.a > 0.0


func show_banner(text_value: String, color: Color) -> void:
	banner.text = text_value
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.modulate.a = 1.0
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(1.6, 1.6)
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_banner_tween.tween_interval(1.6)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.4)
	_banner_tween.tween_callback(banner.hide)


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
