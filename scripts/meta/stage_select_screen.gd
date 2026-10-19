extends MetaScreen
## Stage list. A stage unlocks when the previous one has been cleared.

var sortie_buttons: Dictionary = {}
var status_labels: Dictionary = {}


func _init() -> void:
	screen_title = "ステージ選択"


func _build() -> void:
	var ids := GameCatalog.stage_ids()
	for i in ids.size():
		var stage := GameCatalog.load_stage(ids[i])
		var card := make_card()
		content.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		card.add_child(box)
		box.add_child(make_label("STAGE %d" % (i + 1), 14, MUTED))
		box.add_child(make_label(stage.display_name, 22, GOLD))
		box.add_child(make_label(stage.description, 15))
		var reward := make_label("クリア報酬  ランクEXP %d ・ ルーレット ×%s" % [stage.clear_exp,
				str(stage.roulette_coin_multiplier)], 14, MUTED)
		box.add_child(reward)
		var status := make_label("", 15)
		box.add_child(status)
		status_labels[stage.id] = status
		var button := make_button("出撃", 56, 22)
		button.pressed.connect(_sortie.bind(stage.id))
		box.add_child(button)
		sortie_buttons[stage.id] = button


func _refresh() -> void:
	var ids := GameCatalog.stage_ids()
	for i in ids.size():
		var id := ids[i]
		var unlocked := PlayerData.current.is_stage_unlocked(id)
		var button: Button = sortie_buttons[id]
		button.disabled = not unlocked
		button.text = "出撃" if unlocked else "ロック中"
		var status: Label = status_labels[id]
		if not unlocked:
			status.text = "ステージ%dをクリアで解放" % i
			status.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
		elif PlayerData.current.is_stage_cleared(id):
			status.text = "クリア済み"
			status.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		else:
			status.text = "未クリア"
			status.add_theme_color_override("font_color", MUTED)


func _sortie(stage_id: String) -> void:
	if not PlayerData.current.is_stage_unlocked(stage_id):
		return
	PlayerData.current.current_stage_id = stage_id
	go_to(BATTLE_SCENE)
