extends MetaScreen
## Home: game title, the current party, and the way into every other screen.

const STAGE_SELECT_SCENE := "res://scenes/meta/stage_select.tscn"
const MENU := [
	["編成", "res://scenes/meta/deck.tscn"],
	["強化", "res://scenes/meta/upgrades.tscn"],
	["ガチャ", "res://scenes/meta/gacha.tscn"],
	["ショップ", "res://scenes/meta/shop.tscn"],
]

var start_button: Button
var menu_buttons: Dictionary = {}

var _lineup: HBoxContainer


func _init() -> void:
	show_back = false


func _build() -> void:
	var title := make_label("ピクセル防衛戦", 46, Color(1, 0.85, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	content.add_child(title)
	var subtitle := make_label("5分間 陣地を守りぬけ！", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	_lineup = HBoxContainer.new()
	_lineup.alignment = BoxContainer.ALIGNMENT_CENTER
	_lineup.add_theme_constant_override("separation", 16)
	_lineup.custom_minimum_size = Vector2(0, 60)
	content.add_child(_lineup)

	start_button = make_button("ステージ選択", 72, 30)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.78, 0.33, 0.18)
	style.set_border_width_all(3)
	style.border_width_bottom = 6
	style.border_color = Color(0.08, 0.05, 0.05)
	style.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed"]:
		start_button.add_theme_stylebox_override(state, style)
	start_button.pressed.connect(go_to.bind(STAGE_SELECT_SCENE))
	content.add_child(start_button)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	content.add_child(grid)
	for entry in MENU:
		var button := make_button(entry[0], 60, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(go_to.bind(entry[1]))
		grid.add_child(button)
		menu_buttons[entry[0]] = button

	var howto := make_label("・下のボタンで味方を召喚\n・敵を倒してコインをかせぐ\n・「強化」で軍と陣地をパワーアップ\n・5分後に現れる魔王を倒せば勝利", 15, MUTED)
	howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(howto)

	var pulse := create_tween().set_loops()
	pulse.tween_property(start_button, "modulate", Color(1.15, 1.15, 1.15), 0.6)
	pulse.tween_property(start_button, "modulate", Color.WHITE, 0.6)


func _refresh() -> void:
	for child in _lineup.get_children():
		child.queue_free()
	for data in PlayerData.current.deck_units():
		var icon := UnitIcon.new()
		icon.pixel_scale = 4
		_lineup.add_child(icon)
		icon.set_unit(data)
