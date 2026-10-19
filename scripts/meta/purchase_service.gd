class_name PurchaseService
extends RefCounted
## Orb purchases. The game only talks to this class, so a real store can be plugged in
## without touching the shop screen.
##
## Right now only TEST MODE exists: a purchase completes immediately with a generated
## transaction id and nothing is charged. A real release needs the store billing
## plugins (Google Play Billing for Android, StoreKit for iOS) to replace _buy_with_store().

signal purchase_finished(product_id: String, success: bool, message: String)

var test_mode: bool = true


func is_test_mode() -> bool:
	return test_mode


func buy(product_id: String) -> void:
	if test_mode:
		var transaction := "test-%d-%d" % [Time.get_ticks_usec(), randi()]
		var ok: bool = PlayerData.current.grant_purchase(product_id, transaction)
		purchase_finished.emit(product_id, ok, "テスト購入しました（請求はありません）" if ok else "購入できませんでした")
		return
	_buy_with_store(product_id)


func _buy_with_store(product_id: String) -> void:
	purchase_finished.emit(product_id, false, "ストア決済はまだ準備中です")
