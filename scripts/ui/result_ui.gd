class_name ResultUI
extends CanvasLayer
## End-of-battle screen. Phase 1 shows the outcome, time, kills and a retry button.

signal retry_requested

@onready var panel: Control = $Dim
@onready var title_label: Label = $Dim/Center/Panel/Column/TitleLabel
@onready var time_label: Label = $Dim/Center/Panel/Column/TimeLabel
@onready var kills_label: Label = $Dim/Center/Panel/Column/KillsLabel
@onready var boss_label: Label = $Dim/Center/Panel/Column/BossLabel
@onready var retry_button: Button = $Dim/Center/Panel/Column/RetryButton

var shown_count: int = 0


func _ready() -> void:
	panel.visible = false
	retry_button.pressed.connect(retry_requested.emit)


func show_result(victory: bool, stats: Dictionary) -> void:
	shown_count += 1
	title_label.text = "勝利！" if victory else "敗北…"
	title_label.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.4, 0.35))
	time_label.text = "戦闘時間  %s" % BattleClock.format_time(stats.get("time", 0.0))
	kills_label.text = "撃破数  %d" % stats.get("kills", 0)
	boss_label.text = "ボス撃破  %d" % stats.get("bosses_defeated", 0)
	panel.visible = true
