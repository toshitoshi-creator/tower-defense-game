class_name ResultUI
extends CanvasLayer
## End-of-battle screen. On victory the rewards are already granted and saved by the
## BattleManager; the roulette here reveals the coin/orb prize, then rank EXP.

signal retry_requested
signal title_requested
signal stage_select_requested

var shown_count: int = 0
var victory: bool = false

var _segment: int = -1
var _rewards: Dictionary = {}

@onready var panel: Control = $Dim
@onready var title_label: Label = $Dim/Center/Panel/Column/TitleLabel
@onready var time_label: Label = $Dim/Center/Panel/Column/TimeLabel
@onready var kills_label: Label = $Dim/Center/Panel/Column/KillsLabel
@onready var coins_label: Label = $Dim/Center/Panel/Column/CoinsLabel
@onready var boss_label: Label = $Dim/Center/Panel/Column/BossLabel
@onready var reward_box: Control = $Dim/Center/Panel/Column/RewardBox
@onready var wheel: RouletteWheel = $Dim/Center/Panel/Column/RewardBox/Wheel
@onready var spin_button: Button = $Dim/Center/Panel/Column/RewardBox/SpinButton
@onready var prize_label: Label = $Dim/Center/Panel/Column/RewardBox/PrizeLabel
@onready var rank_label: Label = $Dim/Center/Panel/Column/RewardBox/RankLabel
@onready var rank_bar: ProgressBar = $Dim/Center/Panel/Column/RewardBox/RankBar
@onready var rank_up_label: Label = $Dim/Center/Panel/Column/RewardBox/RankUpLabel
@onready var defeat_hint: Label = $Dim/Center/Panel/Column/DefeatHint
@onready var stage_select_button: Button = $Dim/Center/Panel/Column/StageSelectButton
@onready var retry_button: Button = $Dim/Center/Panel/Column/Row/RetryButton
@onready var title_button: Button = $Dim/Center/Panel/Column/Row/TitleButton


func _ready() -> void:
	panel.visible = false
	retry_button.pressed.connect(retry_requested.emit)
	title_button.pressed.connect(title_requested.emit)
	stage_select_button.pressed.connect(stage_select_requested.emit)
	spin_button.pressed.connect(spin)
	wheel.spin_finished.connect(_reveal_rewards)


func show_result(is_victory: bool, stats: Dictionary, stage: StageData = null,
		roulette_segment: int = -1, rewards: Dictionary = {}) -> void:
	shown_count += 1
	victory = is_victory
	_segment = roulette_segment
	_rewards = rewards
	title_label.text = "勝利！" if victory else "敗北…"
	title_label.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.4, 0.35))
	time_label.text = "戦闘時間  %s" % BattleClock.format_time(stats.get("time", 0.0))
	kills_label.text = "撃破数  %d" % stats.get("kills", 0)
	coins_label.text = "戦闘で得たコイン  %d" % stats.get("coins_earned", 0)
	boss_label.text = "中ボス撃破  %d / %d\n最終ボス  %s" % [stats.get("mid_bosses_defeated", 0),
			stats.get("mid_bosses_total", 0), "撃破" if stats.get("final_boss_defeated", false) else "未撃破"]
	var has_rewards := victory and _segment >= 0 and not _rewards.is_empty()
	reward_box.visible = has_rewards
	defeat_hint.visible = not victory
	if has_rewards:
		wheel.coin_multiplier = stage.roulette_coin_multiplier if stage != null else 1.0
		wheel.spin = 0.0
		spin_button.disabled = false
		spin_button.text = "ルーレットを回す"
		prize_label.text = "？"
		rank_label.text = "ランク %d" % (PlayerData.current.rank - _rewards.get("rank_ups", []).size())
		rank_bar.value = 0.0
		rank_up_label.text = ""
	panel.visible = true
	# Pop the panel in.
	var box: Control = $Dim/Center/Panel
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2(0.8, 0.8)
	box.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(box, "modulate:a", 1.0, 0.15)


func spin() -> void:
	if _segment < 0 or wheel.is_spinning() or spin_button.disabled:
		return
	spin_button.disabled = true
	spin_button.text = "…"
	wheel.spin_to(_segment)


func _reveal_rewards() -> void:
	spin_button.text = "受け取りました"
	var parts: Array[String] = []
	if int(_rewards.get("coins", 0)) > 0:
		parts.append("コイン +%d" % _rewards["coins"])
	if int(_rewards.get("orbs", 0)) > 0:
		parts.append("オーブ +%d！" % _rewards["orbs"])
	prize_label.text = "  ".join(parts)
	var need := GameCatalog.exp_to_next_rank(PlayerData.current.rank)
	rank_label.text = "ランク %d   EXP +%d   (%d / %d)" % [PlayerData.current.rank, _rewards.get("exp", 0), PlayerData.current.rank_exp, need]
	rank_bar.value = float(PlayerData.current.rank_exp) / need
	var lines: Array[String] = []
	for up in _rewards.get("rank_ups", []):
		lines.append("ランク%d に上がった！ コイン +%d  オーブ +%d" % [up["rank"], up["coins"], up["orbs"]])
	if _rewards.get("first_clear", false):
		lines.append("初クリア！")
	if not str(_rewards.get("unlocked_stage", "")).is_empty():
		lines.append("「%s」が解放された！" % _rewards["unlocked_stage"])
	rank_up_label.text = "\n".join(lines)
	var pop := create_tween()
	prize_label.pivot_offset = prize_label.size * 0.5
	prize_label.scale = Vector2(1.4, 1.4)
	pop.tween_property(prize_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
