extends MetaScreen
## Permanent upgrades: each level makes battles start with that upgrade already at
## that level (bought with coins from clear roulettes and rank-ups).

var buy_buttons: Array[Button] = []
var message_label: Label

var _upgrades: Array[UpgradeData] = []
var _level_labels: Array[Label] = []


func _init() -> void:
	screen_title = "強化"


func _build() -> void:
	_upgrades = GameCatalog.load_upgrades()
	content.add_child(make_label("レベルを上げると、戦闘がそのレベルから始まります。", 15, MUTED))
	message_label = make_label("", 16, GOLD)
	content.add_child(message_label)
	for i in _upgrades.size():
		var card := make_card()
		content.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var info := make_label("", 16)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_level_labels.append(info)
		var button := make_button("", 52, 18)
		button.custom_minimum_size.x = 110
		button.pressed.connect(_buy.bind(i))
		row.add_child(button)
		buy_buttons.append(button)


func _refresh() -> void:
	for i in _upgrades.size():
		var upgrade := _upgrades[i]
		var level := PlayerData.current.permanent_level(str(upgrade.id))
		var max_level := GameCatalog.permanent_max_level(upgrade)
		_level_labels[i].text = "%s\n開始時 Lv%d / %d" % [upgrade.display_name, level, max_level]
		var cost := PlayerData.current.permanent_next_cost(upgrade)
		var button := buy_buttons[i]
		if cost < 0:
			button.text = "MAX"
			button.disabled = true
		else:
			button.text = "%dG" % cost
			button.disabled = false
			button.modulate = Color.WHITE if PlayerData.current.coins >= cost else Color(0.7, 0.7, 0.7)


func _buy(index: int) -> void:
	var upgrade := _upgrades[index]
	if PlayerData.current.buy_permanent(upgrade):
		message_label.text = "%s を Lv%d にしました" % [upgrade.display_name, PlayerData.current.permanent_level(str(upgrade.id))]
	elif PlayerData.current.permanent_next_cost(upgrade) < 0:
		message_label.text = "これ以上強化できません"
	else:
		message_label.text = "コインが足りません（ステージクリアやランクアップでもらえます）"
	refresh()
