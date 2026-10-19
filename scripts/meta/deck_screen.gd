extends MetaScreen
## Party (編成): choose the 3 characters that get summon buttons in battle.
## Tap an owned character to add or remove it; a full party of 3 is saved immediately.

var character_buttons: Dictionary = {}
var message_label: Label

var _selection: Array[String] = []
var _slots: HBoxContainer


func _init() -> void:
	screen_title = "編成"


func _build() -> void:
	_selection = PlayerData.current.deck.duplicate()
	content.add_child(make_label("出撃する3体（タップで入れ替え）", 15, MUTED))
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 18)
	_slots.custom_minimum_size = Vector2(0, 70)
	content.add_child(_slots)
	message_label = make_label("", 16, GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message_label)
	for id in GameCatalog.CHARACTERS:
		var data := GameCatalog.load_character(id)
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 66)
		button.pressed.connect(_toggle.bind(id))
		content.add_child(button)
		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.offset_right = -8
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var icon := UnitIcon.new()
		icon.pixel_scale = 3
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		icon.set_unit(data)
		var info := make_label("", 15)
		info.name = "Info"
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(info)
		character_buttons[id] = button


func _refresh() -> void:
	for child in _slots.get_children():
		child.queue_free()
	for id in _selection:
		var icon := UnitIcon.new()
		icon.pixel_scale = 4
		_slots.add_child(icon)
		icon.set_unit(GameCatalog.load_character(id))
	for id in character_buttons:
		var data := GameCatalog.load_character(id)
		var button: Button = character_buttons[id]
		var info: Label = button.find_child("Info", true, false)
		var owned := PlayerData.current.owns(id)
		button.disabled = not owned
		button.set_pressed_no_signal(_selection.has(id))
		if owned:
			var bonus := GameCatalog.level_bonus(PlayerData.current.character_level(id))
			info.text = "%s  Lv%d   %s・%dG\nHP %d  攻撃 %d" % [data.display_name, PlayerData.current.character_level(id),
					role_name(data), data.summon_cost, roundi(data.max_hp * bonus), roundi(data.attack * bonus)]
		else:
			info.text = "%s  未所持\nガチャで入手" % data.display_name
		button.modulate = Color.WHITE if owned else Color(0.6, 0.6, 0.6)
	if _selection.size() < GameCatalog.DECK_SIZE:
		message_label.text = "あと%d体選んでください（そろうまでは前の編成のまま）" % (GameCatalog.DECK_SIZE - _selection.size())


func _toggle(id: String) -> void:
	if not PlayerData.current.owns(id):
		return
	if _selection.has(id):
		_selection.erase(id)
	elif _selection.size() < GameCatalog.DECK_SIZE:
		_selection.append(id)
	else:
		message_label.text = "3体までです。先に1体外してください"
		refresh()
		return
	if _selection.size() == GameCatalog.DECK_SIZE and PlayerData.current.set_deck(_selection):
		message_label.text = "編成を保存しました"
	refresh()
