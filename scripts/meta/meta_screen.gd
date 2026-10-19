class_name MetaScreen
extends Control
## Shared frame for the out-of-battle screens: backdrop, safe-area margins, a header
## with back button, screen title, rank bar and currencies, and a scrolling content area.
## Subclasses fill `content` in _build() and redraw in _refresh().

const HOME_SCENE := "res://scenes/title/title.tscn"
const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const GOLD := Color(1.0, 0.85, 0.3)
const ORB := Color(0.7, 0.6, 1.0)
const MUTED := Color(0.8, 0.8, 0.75)

var screen_title: String = ""
var show_back: bool = true
var content: VBoxContainer
var back_button: Button
var rank_label: Label
var rank_bar: ProgressBar
var coins_label: Label
var orbs_label: Label

var _margin: MarginContainer
var _backdrop: BattlefieldBackground


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = BattlefieldBackground.new()
	_backdrop.modulate = Color(0.45, 0.5, 0.45)
	add_child(_backdrop)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)
	column.add_child(_build_header())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_build()
	PlayerData.current.changed.connect(refresh)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	refresh()


## Override: create the screen's controls inside `content`.
func _build() -> void:
	pass


## Override: update the screen from Player data.
func _refresh() -> void:
	pass


func refresh() -> void:
	var need := GameCatalog.exp_to_next_rank(PlayerData.current.rank)
	rank_label.text = "ランク %d" % PlayerData.current.rank
	rank_bar.value = float(PlayerData.current.rank_exp) / need
	coins_label.text = "%dG" % PlayerData.current.coins
	orbs_label.text = "オーブ %d" % PlayerData.current.get_orbs()
	_refresh()


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene_path)


func _build_header() -> Control:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	header.add_child(top)
	back_button = make_button("＜ もどる", 44, 16)
	back_button.custom_minimum_size.x = 96
	back_button.visible = show_back
	back_button.pressed.connect(go_to.bind(HOME_SCENE))
	top.add_child(back_button)
	var title := make_label(screen_title, 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if not show_back else HORIZONTAL_ALIGNMENT_LEFT
	title.visible = not screen_title.is_empty()
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(title)

	var status := PanelContainer.new()
	header.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	status.add_child(row)
	var rank_box := VBoxContainer.new()
	rank_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_box.add_theme_constant_override("separation", 2)
	row.add_child(rank_box)
	rank_label = make_label("", 16)
	rank_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	rank_box.add_child(rank_label)
	rank_bar = ProgressBar.new()
	rank_bar.custom_minimum_size = Vector2(0, 8)
	rank_bar.max_value = 1.0
	rank_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.75, 1.0)
	rank_bar.add_theme_stylebox_override("fill", fill)
	rank_box.add_child(rank_bar)
	coins_label = make_label("", 18, GOLD)
	coins_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(coins_label)
	orbs_label = make_label("", 18, ORB)
	orbs_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(orbs_label)
	return header


func _relayout() -> void:
	var view := get_viewport_rect().size
	_backdrop.set_area(Rect2(Vector2.ZERO, view), 0.0, view.y)
	var m := SafeArea.get_margins(get_viewport())
	_margin.add_theme_constant_override("margin_left", int(m.left) + 14)
	_margin.add_theme_constant_override("margin_right", int(m.right) + 14)
	_margin.add_theme_constant_override("margin_top", int(m.top) + 14)
	_margin.add_theme_constant_override("margin_bottom", int(m.bottom) + 14)


static func make_label(text_value: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func make_button(text_value: String, height: int = 52, font_size: int = 20) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", font_size)
	return button


static func make_card() -> PanelContainer:
	return PanelContainer.new()


static func role_name(data: UnitData) -> String:
	if data.attack_type == UnitData.AttackType.HEAL:
		return "回復"
	return ["突撃", "守備", "支援"][data.role]
