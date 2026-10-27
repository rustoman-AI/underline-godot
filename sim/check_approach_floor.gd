extends SceneTree

## P63 Approach Floor. The capital order strip shows Approach only while can_approach()
## is true. One click queues the existing order; resolving it runs _order_approach once.
##   godot --headless --path . -s res://sim/check_approach_floor.gd

const BALANCE_SHA := "ec806cef4cc9a61a490db1082827bf94ca56c9a4710a5e7185293e4dc5903864"
const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const EN := {
	"approach.label": "Approach the Floor",
	"approach.tip": "Papers in hand. The tunnel is open.",
	"approach.need": "Need papers and the Floor tunnel.",
	"approach.done": "The Floor asks who speaks for Coney.",
}
const RU := {
	"approach.label": "Подойти к Этажу",
	"approach.tip": "Бумаги при себе. Туннель открыт.",
	"approach.need": "Нужны бумаги и туннель к Этажу.",
	"approach.done": "Этаж спрашивает, кто говорит за Coney.",
}


class HostStub extends Node:
	var game
	var toasts: Array = []
	var confirmed := false
	var net_guide := false
	var net_guide_sid := ""
	var shot_mode := true
	var motion_in_shots := false

	func _toast(text: String, _hold: float = 1.8) -> void:
		toasts.append(text)

	func _refresh() -> void:
		pass

	func note_spend(_cost: Dictionary) -> void:
		pass

	func _open_combat_confirm(_kind: String, _sid: String) -> void:
		confirmed = true


var failed := false


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	if not _check_balance():
		failed = true
	if not _check_formula(catalog):
		failed = true
	if not _check_hide(catalog):
		failed = true
	if not _check_click(catalog):
		failed = true
	if not _check_met(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_block(catalog):
		failed = true
	if failed:
		print("APPROACH FLOOR FAIL")
		quit(1)
		return
	print("APPROACH FLOOR OK")
	quit(0)


func _expect(ok: bool, good: String, bad: String) -> bool:
	if ok:
		print(good + ": ok")
		return true
	failed = true
	print("FAIL " + bad)
	return false


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _arm(game: Game) -> void:
	game.artifacts.papers = 1
	var tunnel := game._tunnel_by_id("to_floor")
	tunnel.dug = true


func _soft(game: Game) -> Dictionary:
	return {
		"rumor": game.flags.get("rumor_dawn", null),
		"border": game.flags.get("border_dawn_new", null),
		"rail": game.flags.get("heard_rail", null),
		"home_pending": game.flags.get("home_pending", null),
		"home_dawn": game.flags.get("home_dawn", null),
		"kind": game.flags.get("dawn_soft_kind", null),
	}


func _view(game: Game) -> NetworkView:
	var view := NetworkView.new()
	var stub := HostStub.new()
	stub.game = game
	view.host = stub
	## Build the sheet without entering the tree, so the gate does not draw the map.
	view._build_sheet()
	view._build_council()
	view._build_zoom_bar()
	return view


func _approach_buttons(view: NetworkView) -> Array:
	var found: Array = []
	if view._sheet_body == null:
		return found
	for node in view._sheet_body.find_children("*", "Button", true, false):
		if node.is_queued_for_deletion():
			continue
		if node.has_meta("order_kind") and str(node.get_meta("order_kind")) == "approach":
			found.append(node)
	return found


func _open(view: NetworkView, sid: String) -> void:
	view.open_sheet(sid)


func _foreign(game: Game) -> String:
	for sid in game.stations:
		if str(sid) != str(game.capital_id):
			return str(sid)
	return ""


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/approach_floor.json"))
	if not (pack is Dictionary) or not (pack.get("by_key", null) is Dictionary):
		print("FAIL strings pack")
		return false
	var rows: Dictionary = pack.by_key
	if rows.size() != 4:
		print("FAIL strings count %d" % rows.size())
		return false
	for key in EN:
		var row = rows.get(key, null)
		if not (row is Dictionary) or str(row.get("en", "")) != str(EN[key]) or str(row.get("ru", "")) != str(RU[key]):
			print("FAIL strings row ", key)
			return false
		if str(row.get("ru", "")).contains("Пол"):
			print("FAIL Floor RU Пол ", key)
			return false
	for key in ["approach.label", "approach.need", "approach.done"]:
		if not str(RU[key]).contains("Этаж"):
			print("FAIL Floor RU Этаж ", key)
			return false
	Copy.set_lang("en")
	var approach_keys := 0
	for key in Copy.keys:
		if str(key).begins_with("approach."):
			approach_keys += 1
	if approach_keys != 4:
		print("FAIL loaded approach keys %d" % approach_keys)
		return false
	for key in EN:
		if Copy.t(key) != str(EN[key]):
			print("FAIL en ", key, " ", Copy.t(key))
			return false
	Copy.set_lang("ru")
	for key in RU:
		if Copy.t(key) != str(RU[key]):
			print("FAIL ru ", key, " ", Copy.t(key))
			return false
	Copy.set_lang("en")
	var ui := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var sim := FileAccess.get_file_as_string("res://sim/game.gd")
	if ui.contains("approach.need") or station.contains("approach.need") or sim.contains("approach.need"):
		print("FAIL approach.need used in MVP")
		return false
	if not station.contains("while not game.notices.is_empty()") or not station.contains("func _toast("):
		print("FAIL toast drain")
		return false
	if not station.contains("func _map_toast_face("):
		print("FAIL map toast plate")
		return false
	var done := Copy.clip(Copy.t("approach.done"), 72)
	if done != str(EN["approach.done"]) or done.length() > 72:
		print("FAIL clip ", done)
		return false
	print("Strings: ok")
	return true


func _check_balance() -> bool:
	var hash := FileAccess.get_sha256("res://data/balance.json")
	return _expect(hash == BALANCE_SHA, "Balance", "balance.json changed " + hash)


func _check_formula(catalog: Catalog) -> bool:
	var game := _game(catalog)
	if game.can_approach():
		print("FAIL week-1 can_approach")
		return false
	game.artifacts.papers = 1
	if game.can_approach():
		print("FAIL papers without tunnel")
		return false
	game.artifacts.papers = 0
	var tunnel := game._tunnel_by_id("to_floor")
	if tunnel.is_empty():
		print("FAIL no to_floor tunnel")
		return false
	tunnel.dug = true
	if game.can_approach():
		print("FAIL tunnel without papers")
		return false
	if game._order_approach():
		print("FAIL approach ran while not ready")
		return false
	_arm(game)
	if not game.can_approach():
		print("FAIL ready can_approach")
		return false
	var before := game.hope
	var soft := _soft(game)
	if not game._order_approach():
		print("FAIL _order_approach")
		return false
	if not game.floor_met or game.hope != before + 2:
		print("FAIL effects floor %s hope %d -> %d" % [game.floor_met, before, game.hope])
		return false
	if game.notices.size() != 1 or str(game.notices[0]) != Copy.t("approach.done"):
		print("FAIL notice ", game.notices)
		return false
	var logged := false
	for row in game.log:
		if str(row.get("text", "")) == "The Floor is still holding a meeting. They ask who speaks for Coney Island.":
			logged = true
	if not logged:
		print("FAIL log line")
		return false
	var again_hope := game.hope
	if game._order_approach() or game.hope != again_hope or game.notices.size() != 1:
		print("FAIL second approach")
		return false
	if game.can_approach() or _soft(game) != soft or game.over != "":
		print("FAIL after approach gate/dawn/ending")
		return false
	print("Formula: ok")
	return true


func _check_hide(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var view := _view(game)
	var capital := str(game.capital_id)
	_open(view, capital)
	if view._sheet_body == null:
		print("FAIL sheet missing")
		return false
	if not _approach_buttons(view).is_empty():
		print("FAIL week-1 button")
		return false
	for node in view._sheet_body.find_children("*", "Label", true, false):
		var text := str(node.text)
		if text.contains("Approach the Floor") or text.contains("approach.need") or text.contains("Need papers"):
			print("FAIL week-1 tease ", text)
			return false
	_arm(game)
	var other := _foreign(game)
	if other == "":
		print("FAIL no foreign station")
		return false
	_open(view, other)
	if not _approach_buttons(view).is_empty():
		print("FAIL foreign strip shows Approach")
		return false
	game.stations[other].owner = game.player
	_open(view, other)
	if not _approach_buttons(view).is_empty():
		print("FAIL outpost strip shows Approach")
		return false
	_open(view, capital)
	var buttons := _approach_buttons(view)
	if buttons.size() != 1:
		print("FAIL ready buttons %d" % buttons.size())
		return false
	var button: Button = buttons[0]
	if button.get_parent() != view._sheet_body:
		print("FAIL button not on the order strip")
		return false
	if button.disabled or str(button.tooltip_text) != Copy.t("approach.tip"):
		print("FAIL tip ", button.tooltip_text, " disabled ", button.disabled)
		return false
	var caption: Label = button.get_meta("order_caption")
	if caption == null or caption.text != Copy.t("approach.label"):
		print("FAIL label ", caption.text if caption != null else "missing")
		return false
	if button.pressed.get_connections().is_empty():
		print("FAIL button has no click")
		return false
	print("Hide: ok")
	return true


func _check_click(catalog: Catalog) -> bool:
	var game := _game(catalog)
	_arm(game)
	var view := _view(game)
	var stub: HostStub = view.host
	var capital := str(game.capital_id)
	_open(view, capital)
	var buttons := _approach_buttons(view)
	if buttons.size() != 1:
		print("FAIL click setup")
		return false
	var hope := game.hope
	var soft := _soft(game)
	buttons[0].pressed.emit()
	if stub.confirmed or not stub.toasts.is_empty():
		print("FAIL confirm or queue toast ", stub.confirmed, stub.toasts)
		return false
	if game.floor_met or game.queued_orders.size() != 1:
		print("FAIL queue ", game.queued_orders.size(), " met ", game.floor_met)
		return false
	var queued: Dictionary = game.queued_orders[0]
	if str(queued.get("kind", "")) != "approach":
		print("FAIL queued kind ", queued.get("kind", ""))
		return false
	game._resolve_queued()
	if not game.floor_met or game.hope != hope + 2 or game.over != "":
		print("FAIL resolve floor %s hope %d over %s" % [game.floor_met, game.hope, game.over])
		return false
	if game.notices.size() != 1 or str(game.notices[0]) != Copy.clip(Copy.t("approach.done"), 72):
		print("FAIL success toast ", game.notices)
		return false
	if _soft(game) != soft or game.dawn_soft_stack() != STACK:
		print("FAIL soft dawn ", _soft(game), game.dawn_soft_stack())
		return false
	_open(view, capital)
	if not _approach_buttons(view).is_empty() or game.can_approach():
		print("FAIL button stayed after floor_met")
		return false
	print("Click: ok")
	return true


func _check_met(catalog: Catalog) -> bool:
	var game := _game(catalog)
	_arm(game)
	game.floor_met = true
	var view := _view(game)
	_open(view, str(game.capital_id))
	if game.can_approach() or not _approach_buttons(view).is_empty():
		print("FAIL load with floor_met still shows the button")
		return false
	print("Met: ok")
	return true


func _check_dawn(catalog: Catalog) -> bool:
	if Game.DAWN_SOFT_STACK != STACK:
		print("FAIL dawn stack ", Game.DAWN_SOFT_STACK)
		return false
	var game := _game(catalog)
	if game.dawn_soft_stack() != STACK:
		print("FAIL dawn_soft_stack")
		return false
	print("Dawn: ok")
	return true


func _check_block(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var blocked := game.order_block("approach")
	var missing := game.order_block("no_such_approach_order")
	if blocked == "" or blocked == "No such order." or blocked == Copy.t("No such order."):
		print("FAIL unready block ", blocked)
		return false
	if missing != "No such order.":
		print("FAIL missing-kind control ", missing)
		return false
	_arm(game)
	if game.order_block("approach") != "":
		print("FAIL ready block ", game.order_block("approach"))
		return false
	print("Block: ok")
	return true
