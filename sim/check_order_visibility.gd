extends SceneTree

## P39 map order toasts. Names the verb on a successful queue and keeps the 72-character clip.
##   godot --headless --path . -s res://sim/check_order_visibility.gd

const CITE := {
	"order.toast_garrison": {"en": "Garrison → {station}", "ru": "Гарнизон → {station}"},
	"order.toast_expedition": {"en": "Expedition queued · {station}", "ru": "Экспедиция в очереди · {station}"},
	"order.toast_expedition_plain": {"en": "Expedition queued", "ru": "Экспедиция в очереди"},
	"order.toast_gift": {"en": "Gift → {faction} · Opinion ~+{n}", "ru": "Подарок → {faction} · Мнение ~+{n}"},
	"order.toast_aid": {"en": "Aid → {station} · {need} improves", "ru": "Помощь → {station} · {need} лучше"},
	"order.toast_pay": {"en": "Pay → {faction} · Opinion ~+{n}", "ru": "Оплата → {faction} · Мнение ~+{n}"},
	"order.toast_cancel": {"en": "Order cancelled · {role}", "ru": "Приказ отменён · {role}"},
}


class HostStub extends Node:
	var game


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	var game := Game.new()
	game.setup(catalog, 1, 40)
	Copy.set_lang("en")
	var canal := _named(game, "Canal St")
	if canal == "":
		print("Place: FAIL no Canal St")
		failed = true
	else:
		var view := _view(game)
		if not _check_toasts(game, view, canal):
			failed = true
		if not _check_marks(game, view, canal):
			failed = true
		if not _check_reports(game):
			failed = true
		if not _check_plate():
			failed = true
	if failed:
		print("ORDER VISIBILITY FAIL")
		quit(1)
		return
	print("ORDER VISIBILITY OK")
	quit(0)


func _named(game: Game, want: String) -> String:
	for sid in game.stations:
		if str(game.stations[sid].get("name", "")) == want:
			return str(sid)
	return ""


func _view(game: Game) -> NetworkView:
	var view := NetworkView.new()
	var stub := HostStub.new()
	stub.game = game
	view.host = stub
	return view


func _check_strings() -> bool:
	Copy.set_lang("en")
	var en := {
		"order.toast_patrol": "Patrol → {station}",
		"order.toast_raid": "Raid → {station}",
		"order.toast_assault": "Assault → {station}",
	}
	for key in en:
		if Copy.t(key) != str(en[key]):
			print("Strings: FAIL en ", key, " ", Copy.t(key))
			return false
	Copy.set_lang("ru")
	var ru := {
		"order.toast_patrol": "Патруль → {station}",
		"order.toast_raid": "Рейд → {station}",
		"order.toast_assault": "Штурм → {station}",
	}
	for key in ru:
		if Copy.t(key) != str(ru[key]):
			print("Strings: FAIL ru key ", key, " ", Copy.t(key))
			return false
	for sentence in en:
		var line := str(en[sentence])
		if Copy.t(line) != str(ru[sentence]):
			print("Strings: FAIL ru.json ", line, " ", Copy.t(line))
			return false
	Copy.set_lang("en")
	var long := Copy.clip("x".repeat(80))
	if long.length() != 72 or not long.ends_with("…"):
		print("Strings: FAIL clip ", long.length())
		return false
	print("Strings: ok")
	return true


func _hold(key: String) -> bool:
	if Copy.keys.has(key):
		return false
	Copy.keys[key] = CITE[key]
	return true


func _drop(key: String, added: bool) -> void:
	if added:
		Copy.keys.erase(key)


func _check_toasts(game: Game, view: NetworkView, canal: String) -> bool:
	var generic := Copy.t("Order sent. The result comes at next dawn.")
	var patrol := view._order_queue_toast("patrol", canal, {})
	if patrol != "Patrol → Canal St":
		print("Toast: FAIL patrol ", patrol)
		return false
	if view._order_queue_toast("move", canal, {}) != "Patrol → Canal St":
		print("Toast: FAIL foreign move")
		return false
	if view._player_station(game, canal):
		print("Toast: FAIL Canal St is owned")
		return false
	var raid := view._order_queue_toast("raid", canal, {})
	var assault := view._order_queue_toast("assault", canal, {})
	if raid != "Raid → Canal St" or assault != "Assault → Canal St":
		print("Toast: FAIL combat ", raid, " ", assault)
		return false
	var missing := view._order_queue_toast("raid", "no-such-station", {})
	if missing != Copy.t("combat.toast_sent"):
		print("Toast: FAIL missing raid ", missing)
		return false
	if view._order_queue_toast("assault", "", {}) != Copy.t("combat.toast_sent"):
		print("Toast: FAIL missing assault")
		return false
	var preview := game.sympathy_preview(canal)
	var prop := Copy.fill("order.toast_propaganda", {"station": "Canal St", "preview": preview})
	if view._order_queue_toast("propaganda", canal, {}) != Copy.clip(prop):
		print("Toast: FAIL propaganda")
		return false
	var prev: Dictionary = game.envoy_preview(canal)
	var envoy := Copy.fill("order.toast_envoy", {
		"station": "Canal St",
		"gain": int(prev.get("gain", 0)),
		"need": Copy.t(str(prev.get("need_id", ""))),
	})
	if view._order_queue_toast("envoy", canal, {}) != Copy.clip(envoy):
		print("Toast: FAIL envoy ", view._order_queue_toast("envoy", canal, {}))
		return false
	var deal := Copy.fill("order.toast_deal", {"station": "Canal St", "n": game.deal_preview(canal)})
	if view._order_queue_toast("trade", canal, {}) != Copy.clip(deal):
		print("Toast: FAIL deal")
		return false
	if view._order_queue_toast("trade", "", {}) != generic:
		print("Toast: FAIL faction trade")
		return false
	if view._order_queue_toast("approach", "", {}) != generic:
		print("Toast: FAIL unknown")
		return false
	var home := str(game.capital_id)
	if not Copy.keys.has("order.toast_garrison") and view._order_queue_toast("move", home, {}) != generic:
		print("Toast: FAIL garrison fallback before the key exists")
		return false
	var garrison_added := _hold("order.toast_garrison")
	var named := view._order_queue_toast("move", home, {})
	var want := "Garrison → %s" % view._order_place(game, home)
	_drop("order.toast_garrison", garrison_added)
	if garrison_added and named != want:
		print("Toast: FAIL garrison ", named, " want ", want)
		return false
	if not garrison_added and not named.begins_with("Garrison → "):
		print("Toast: FAIL owned move ", named)
		return false
	var plain_added := _hold("order.toast_expedition_plain")
	var exp_added := _hold("order.toast_expedition")
	if view._order_queue_toast("expedition", "", {}) != "Expedition queued":
		print("Toast: FAIL expedition plain")
		_drop("order.toast_expedition_plain", plain_added)
		_drop("order.toast_expedition", exp_added)
		return false
	if game.stations.has("vault"):
		var vault_name := view._order_place(game, "vault")
		var exp := view._order_queue_toast("expedition", "", {"target": "vault"})
		if exp != "Expedition queued · %s" % vault_name:
			print("Toast: FAIL expedition ", exp)
			_drop("order.toast_expedition_plain", plain_added)
			_drop("order.toast_expedition", exp_added)
			return false
	_drop("order.toast_expedition_plain", plain_added)
	_drop("order.toast_expedition", exp_added)
	var gift_added := _hold("order.toast_gift")
	var aid_added := _hold("order.toast_aid")
	var pay_added := _hold("order.toast_pay")
	var gift := view._order_queue_toast("gift", "", {"faction": "Exchange", "n": 12})
	var aid := view._order_queue_toast("aid", canal, {"need": "Food"})
	var pay := view._order_queue_toast("pay", "", {"faction": "Exchange", "n": 5})
	if gift != "Gift → Exchange · Opinion ~+12" or aid != "Aid → Canal St · Food improves" or pay != "Pay → Exchange · Opinion ~+5":
		print("Toast: FAIL soft ", gift, " | ", aid, " | ", pay)
		_drop("order.toast_gift", gift_added)
		_drop("order.toast_aid", aid_added)
		_drop("order.toast_pay", pay_added)
		return false
	_drop("order.toast_gift", gift_added)
	_drop("order.toast_aid", aid_added)
	_drop("order.toast_pay", pay_added)
	if not Copy.keys.has("order.toast_cancel") and view._cancel_toast("marshal") != "":
		print("Toast: FAIL cancel showed a raw key")
		return false
	var cancel_added := _hold("order.toast_cancel")
	var cancelled := view._cancel_toast("marshal")
	_drop("order.toast_cancel", cancel_added)
	if cancelled != "Order cancelled · Marshal":
		print("Toast: FAIL cancel ", cancelled)
		return false
	var saved: String = str(game.stations[canal].get("name", ""))
	game.stations[canal]["name"] = "N".repeat(90)
	var clipped := view._order_queue_toast("patrol", canal, {})
	game.stations[canal]["name"] = saved
	if clipped.length() != 72 or not clipped.ends_with("…") or clipped == generic:
		print("Toast: FAIL clip ", clipped.length(), " ", clipped)
		return false
	for sample in [patrol, raid, assault, prop, envoy, deal]:
		if str(sample).length() > 72:
			print("Toast: FAIL length ", sample)
			return false
	print("Toasts: ok")
	return true


func _check_marks(game: Game, view: NetworkView, canal: String) -> bool:
	var home := str(game.capital_id)
	if not view._queued_mark(game, {"kind": "envoy", "home": home, "target": canal}):
		print("Trail: FAIL envoy")
		return false
	if view._queued_mark(game, {"kind": "gift", "home": home, "target": canal}):
		print("Trail: FAIL gift")
		return false
	if view._queued_mark(game, {"kind": "pay", "home": home, "target": canal}):
		print("Trail: FAIL pay")
		return false
	if view._queued_mark(game, {"kind": "expedition", "home": home, "target": ""}):
		print("Trail: FAIL expedition without station")
		return false
	if game.stations.has("vault"):
		var vault_row := {"kind": "expedition", "home": home, "target": "vault"}
		var marked := view._queued_mark(game, vault_row)
		if view._secret(game.stations["vault"]):
			if marked:
				print("Trail: FAIL secret expedition")
				return false
		elif not marked:
			print("Trail: FAIL expedition with station")
			return false
	if view._queued_mark(game, {"kind": "patrol", "home": home, "target": "missing"}):
		print("Trail: FAIL unresolved target")
		return false
	print("Trails: ok")
	return true


func _check_reports(game: Game) -> bool:
	var st = load("res://ui/station.gd").new()
	st.game = game
	if st._order_report_body({"text": "already rich", "ok": true, "before_sympathy": 1, "after_sympathy": 2, "gain": 1}) != "already rich":
		print("Report: FAIL preferred text")
		return false
	var thin := "The squad reaches Canal St."
	if st._order_report_body({"text": thin, "ok": true, "kind": "move"}) != thin:
		print("Report: FAIL thin move")
		return false
	var rich: Dictionary = {
		"text": "",
		"ok": true,
		"kind": "propaganda",
		"name": "Jonah",
		"community": "Canal St",
		"before_sympathy": 20,
		"after_sympathy": 32,
		"gain": 12,
		"need_id": "",
		"need_before": 0.0,
		"need_after": 0.0,
		"deals": 0,
		"joined": false,
	}
	var body := str(st._order_report_body(rich))
	if not body.contains("Sympathy 20 → 32 (+12)."):
		print("Report: FAIL structured ", body)
		return false
	var failed := str(st._order_report_body({"text": "", "ok": false, "kind": "raid"}))
	if failed != Copy.t("The order failed."):
		print("Report: FAIL failure ", failed)
		return false
	print("Reports: ok")
	return true


func _check_plate() -> bool:
	var st = load("res://ui/station.gd").new()
	var motion := Settings.reduce_motion
	Settings.reduce_motion = true
	st.showing_network = true
	st._toast("Patrol → Canal St")
	if st.toast_label == null or st.toast_label.text != "Patrol → Canal St" or not st.toast_label.visible:
		print("Plate: FAIL map toast")
		Settings.reduce_motion = motion
		return false
	if st.toast_plate == null or not st.toast_plate.visible or st.toast_label.get_parent() != st.toast_plate:
		print("Plate: FAIL map plate")
		Settings.reduce_motion = motion
		return false
	st.showing_network = false
	st._toast("Order sent. The result comes at next dawn.")
	if st.toast_plate.visible or st.toast_label.get_parent() != st:
		print("Plate: FAIL station toast")
		Settings.reduce_motion = motion
		return false
	Settings.reduce_motion = motion
	st.queue_free()
	print("Plate: ok")
	return true
