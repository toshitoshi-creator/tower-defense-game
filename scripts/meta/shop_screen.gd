extends MetaScreen
## Orb shop. Purchases go through PurchaseService, which is in test mode for now:
## nothing is charged and the screen says so.

var buy_buttons: Dictionary = {}
var message_label: Label
var purchases := PurchaseService.new()


func _init() -> void:
	screen_title = "ショップ"


func _build() -> void:
	if purchases.is_test_mode():
		var banner := make_card()
		content.add_child(banner)
		banner.add_child(make_label("テストモード：購入しても実際の請求は発生しません。ストア決済は未接続です。", 15,
				Color(1, 0.7, 0.5)))
	message_label = make_label("", 16, GOLD)
	content.add_child(message_label)
	for product in GameCatalog.SHOP_PRODUCTS:
		var card := make_card()
		content.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var label := make_label("オーブ %d" % product["orbs"], 20, ORB)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := make_button(product["price"], 52, 18)
		button.custom_minimum_size.x = 120
		button.pressed.connect(purchases.buy.bind(product["id"]))
		row.add_child(button)
		buy_buttons[product["id"]] = button
	content.add_child(make_label("オーブはガチャで使います。購入したオーブと無料でもらったオーブは区別して記録しています。",
			14, MUTED))
	purchases.purchase_finished.connect(_on_purchase_finished)


func _on_purchase_finished(_product_id: String, _success: bool, message: String) -> void:
	message_label.text = message
	refresh()
