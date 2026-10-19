extends MetaScreen
## Character gacha with orbs. New characters join the collection; duplicates raise the
## character's level. Drop rates are shown on this screen.

var single_button: Button
var ten_button: Button
var message_label: Label
var results_grid: GridContainer


func _init() -> void:
	screen_title = "ガチャ"


func _build() -> void:
	content.add_child(make_label("新しいキャラクターを仲間にできます。同じキャラが出るとレベルアップ（最大Lv%d）。" %
			GameCatalog.MAX_CHARACTER_LEVEL, 15, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	single_button = make_button("1回\nオーブ %d" % GameCatalog.GACHA_SINGLE_COST, 66, 18)
	single_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	single_button.pressed.connect(_draw_gacha.bind(1))
	row.add_child(single_button)
	ten_button = make_button("10回\nオーブ %d" % GameCatalog.GACHA_TEN_COST, 66, 18)
	ten_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ten_button.pressed.connect(_draw_gacha.bind(10))
	row.add_child(ten_button)
	message_label = make_label("", 16, GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message_label)
	results_grid = GridContainer.new()
	results_grid.columns = 5
	results_grid.add_theme_constant_override("h_separation", 6)
	results_grid.add_theme_constant_override("v_separation", 6)
	content.add_child(results_grid)

	var rates := make_card()
	content.add_child(rates)
	var rates_box := VBoxContainer.new()
	rates.add_child(rates_box)
	rates_box.add_child(make_label("提供割合", 18, GOLD))
	var by_rarity := {}
	for entry in GameCatalog.GACHA_POOL:
		by_rarity[entry["rarity"]] = by_rarity.get(entry["rarity"], 0) + int(entry["weight"])
	rates_box.add_child(make_label("SR %d%%   R %d%%   N %d%%" % [by_rarity.get("SR", 0), by_rarity.get("R", 0),
			by_rarity.get("N", 0)], 16))
	var lines: Array[String] = []
	for entry in GameCatalog.GACHA_POOL:
		lines.append("[%s] %s  %d%%" % [entry["rarity"], GameCatalog.load_character(entry["id"]).display_name,
				int(entry["weight"])])
	rates_box.add_child(make_label("\n".join(lines), 14, MUTED))


func _refresh() -> void:
	single_button.disabled = PlayerData.current.get_orbs() < GameCatalog.GACHA_SINGLE_COST
	ten_button.disabled = PlayerData.current.get_orbs() < GameCatalog.GACHA_TEN_COST


func _draw_gacha(count: int) -> void:
	var results := PlayerData.current.draw_gacha(count)
	for child in results_grid.get_children():
		child.queue_free()
	if results.is_empty():
		message_label.text = "オーブが足りません（ショップ・ランクアップ・ルーレットで入手）"
		refresh()
		return
	var news := 0
	for r in results:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		results_grid.add_child(cell)
		var icon := UnitIcon.new()
		icon.pixel_scale = 3
		cell.add_child(icon)
		icon.set_unit(GameCatalog.load_character(r["id"]))
		var tag := "NEW!" if r["new"] else ("+%dG" % r["coins"] if r["coins"] > 0 else "Lv%d" % r["level"])
		var label := make_label("%s\n%s" % [r["rarity"], tag], 13,
				Color(1, 0.5, 0.4) if r["new"] else Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(label)
		news += 1 if r["new"] else 0
	message_label.text = "新しい仲間 %d体！" % news if news > 0 else "仲間がレベルアップしました"
	refresh()
