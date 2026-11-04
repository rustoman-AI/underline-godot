extends SceneTree

const Ledger = preload("res://sim/outpost_ledger.gd")

## P85 Outpost Ledger gate.
##   godot --headless --path . -s res://sim/check_outpost_ledger.gd
## Visit glance only. No map mark. No soft dawn chip. No balance edit.
## Careful loss on seeds 1–60 must stay on the master baseline of 2/60.

class Host extends Node:
	var game
	var shot_mode := false
	var motion_in_shots := false
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)

	func _ui_click() -> void:
		pass


var _failed := false
const BASELINE_LOST := 2


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("LEDGER FAIL catalog")
		quit(1)
		return
	var balance_text := FileAccess.get_file_as_string("res://data/balance.json")
	if not _check_strings():
		_failed = true
	if not _check_ledger(catalog):
		_failed = true
	if not await _check_visit(catalog):
		_failed = true
	if not _check_dawn():
		_failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_text:
		_bad("balance.json changed")
	if _failed:
		print("LEDGER FAIL")
		quit(1)
		return
	var lost := _careful_loss(catalog)
	print("Careful loss: %d/60 (master baseline %d/60)" % [lost, BASELINE_LOST])
	if lost != BASELINE_LOST:
		_bad("careful loss %d/60 moved off the measured %d/60 baseline" % [lost, BASELINE_LOST])
		print("LEDGER FAIL")
		quit(1)
		return
	print("LEDGER OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("Ledger: FAIL " + msg)


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/outpost_ledger.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P85":
		_bad("pack roadmap")
		return false
	var rows = pack.get("by_key", {})
	if not (rows is Dictionary) or rows.size() != 8:
		_bad("pack key count")
		return false
	var want := ["ledger.name", "ledger.tip", "ledger.first", "ledger.status", "ledger.empty", "ledger.mats", "ledger.food", "ledger.goods"]
	for key in want:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		if str(key).begins_with("wall."):
			_bad("wall key")
			return false
	Copy.set_lang("en")
	for key in rows:
		if Copy.t(str(key)) != str(rows[key].get("en", "")):
			_bad("EN %s got %s" % [str(key), Copy.t(str(key))])
			return false
	Copy.set_lang("ru")
	for key in rows:
		if Copy.t(str(key)) != str(rows[key].get("ru", "")):
			_bad("RU %s got %s" % [str(key), Copy.t(str(key))])
			return false
	if Copy.t("ledger.status").contains("мат.") and not Copy.t("ledger.status").contains("матер."):
		_bad("old brief ru abbrev")
		return false
	if Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}) != "На складе: 4 матер. · 0 еды · 7 товара":
		_bad("ru status fill " + Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}))
		return false
	if Copy.fill("ledger.mats", {"n": 4}) != "4 матер.":
		_bad("ru mats")
		return false
	Copy.set_lang("en")
	if Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}) != "Holds: 4 mats · 0 food · 7 goods":
		_bad("en status fill")
		return false
	if Copy.t("ledger.empty") != "Holds nothing counted." or Copy.t("ledger.first") != "The outpost keeps a ledger.":
		_bad("en empty/first")
		return false
	if Copy.t("ledger.tip") != "Outpost Ledger. What this station holds.":
		_bad("en tip")
		return false
	for key in rows:
		if str(key).begins_with("wall"):
			_bad("wall key in ledger pack")
			return false
	print("Strings: ok")
	return true


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


func _pair(game: Game) -> Array:
	var owned := ""
	var foreign := ""
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(sid) == str(game.capital_id):
			continue
		if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
			continue
		if owned == "":
			owned = str(sid)
		elif foreign == "":
			foreign = str(sid)
			break
	return [owned, foreign]


func _check_ledger(catalog: Catalog) -> bool:
	if Ledger.map_mark() or Ledger.joins_soft_dawn():
		_bad("mark or dawn helper")
		return false
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	if sid == "":
		_bad("no outpost")
		return false
	game.stations[sid].owner = game.player
	game.stations[sid].known = true
	game.stations[sid].hidden = false
	var before_keys: Array = game.stations[sid].keys()
	var row: Dictionary = Ledger.amounts(game, sid)
	if game.stations[sid].keys() != before_keys:
		_bad("amounts wrote a station field")
		return false
	var bits: PackedStringArray = []
	for key in ["mats", "food", "goods"]:
		if bool(row.get(key + "_exposed", false)):
			bits.append("%s=%d via %s" % [key, int(row[key]), str(row.get(key + "_field", ""))])
		else:
			bits.append("%s not exposed (bound 0)" % key)
	print("Ledger fields: " + ", ".join(bits))
	if not Ledger.is_empty(row) or Ledger.status_text(row) != Copy.t("ledger.empty"):
		_bad("unexposed station did not read empty")
		return false
	var shipped: Dictionary = game.catalog.station_goods(sid)
	if int(shipped.get("food", 0)) + int(shipped.get("materials", 0)) > 0 and (int(row.food) != 0 or int(row.mats) != 0):
		_bad("shipment table was read as a holding")
		return false
	game.stations[sid].materials = 4
	game.stations[sid].food = 0
	game.stations[sid].goods = 7
	row = Ledger.amounts(game, sid)
	if int(row.mats) != 4 or int(row.food) != 0 or int(row.goods) != 7 or Ledger.is_empty(row):
		_bad("bound fields " + str(row))
		return false
	if Ledger.status_text(row) != "Holds: 4 mats · 0 food · 7 goods":
		_bad("status with a zero " + Ledger.status_text(row))
		return false
	game.stations[sid].erase("materials")
	game.stations[sid].erase("food")
	game.stations[sid].erase("goods")
	game.stations[sid].stock = {"materials": 1, "food": 2, "goods": 0}
	row = Ledger.amounts(game, sid)
	if int(row.mats) != 1 or int(row.food) != 2 or int(row.goods) != 0 or str(row.mats_field) != "stock.materials":
		_bad("nested stock " + str(row))
		return false
	game.stations[sid].erase("stock")
	if Ledger.shows(game, game.capital_id):
		_bad("home shows")
		return false
	var foreign := str(pair[1])
	if Ledger.shows(game, foreign):
		_bad("foreign shows")
		return false
	game.stations[sid].hidden = true
	if Ledger.shows(game, sid):
		_bad("hidden shows")
		return false
	game.stations[sid].hidden = false
	game.stations[sid].owner = "neutral"
	if Ledger.shows(game, sid):
		_bad("unowned shows")
		return false
	print("Ledger: ok")
	return true


func _gone(node: Node) -> bool:
	var here: Node = node
	while here != null:
		if here.is_queued_for_deletion():
			return true
		here = here.get_parent()
	return false


func _meta(node: Node, key: String) -> Array:
	var found: Array = []
	if node == null:
		return found
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if _gone(here):
			continue
		if here.has_meta(key):
			found.append(here)
		for child in here.get_children():
			stack.append(child)
	return found


func _row(view: NetworkView) -> Node:
	var found := _meta(view.visit, "ledger_row")
	if found.size() != 1:
		return null
	return found[0]


func _lines(row: Node) -> Array:
	var found: Array = []
	if row == null:
		return found
	for child in row.get_children():
		if child.has_meta("ledger_line"):
			found.append(child)
	return found


func _check_visit(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	var foreign := str(pair[1])
	if sid == "" or foreign == "":
		_bad("visit pair")
		return false
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.hidden = false
	var stock0 := {
		"food": int(game.stock.food),
		"materials": int(game.stock.materials),
		"air": int(game.stock.air),
		"tokens": int(game.stock.tokens),
		"influence": int(game.stock.influence),
	}
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var orders0 := int(game.orders_left)
	var dawn0 := str(game.flags.get("dawn_soft_kind", ""))
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.size = Vector2(1280, 720)
	root.add_child(view)
	view.host = host
	Settings.reduced()
	Settings.reduce_motion = true
	view.open_visit(game.capital_id)
	if _row(view) != null or bool(game.flags.get(Ledger.FLAG, false)):
		_bad("capital visit")
		return false
	view.close_visit()
	view.open_visit(foreign)
	if _row(view) != null or bool(game.flags.get(Ledger.FLAG, false)):
		_bad("foreign visit")
		return false
	view.close_visit()
	st.hidden = true
	view.open_visit(sid)
	if _row(view) != null or bool(game.flags.get(Ledger.FLAG, false)):
		_bad("hidden visit")
		return false
	view.close_visit()
	st.hidden = false
	view.open_sheet(sid)
	if not _meta(view._sheet_body, "ledger_row").is_empty() or bool(game.flags.get(Ledger.FLAG, false)):
		_bad("sheet showed the ledger")
		return false
	view.close_sheet()
	view.open_visit(sid)
	var row := _row(view)
	if row == null or str(row.get_meta("ledger_kind")) != "empty":
		_bad("empty kind")
		return false
	if row.get_index() != row.get_parent().get_child_count() - 1 or not bool(row.get_meta("ledger_last", false)):
		_bad("ledger is not the last status row")
		return false
	var lines := _lines(row)
	if lines.size() != 1 or str(lines[0].text) != "Holds nothing counted.":
		_bad("empty text")
		return false
	var ink: Color = lines[0].get_theme_color("font_color")
	if not ink.is_equal_approx(NetworkView.MUTED):
		_bad("empty ink " + str(ink))
		return false
	if str(row.tooltip_text) != "Outpost Ledger. What this station holds." or str(lines[0].tooltip_text) != row.tooltip_text:
		_bad("tip")
		return false
	if not bool(game.flags.get(Ledger.FLAG, false)):
		_bad("flag")
		return false
	if view._ledger_float == null or not view._ledger_float.visible or view._ledger_float.text != "The outpost keeps a ledger.":
		_bad("first float")
		return false
	if not bool(view._ledger_float.get_meta("ledger_float_static", false)):
		_bad("float moved under reduce-motion")
		return false
	var y := view._ledger_float.position.y
	var alpha := view._ledger_float.modulate.a
	for _i in 3:
		await process_frame
	if not is_equal_approx(view._ledger_float.position.y, y) or not is_equal_approx(view._ledger_float.modulate.a, alpha):
		_bad("float was not static")
		return false
	if st.has("materials") or st.has("food") or st.has("goods") or st.has("mats"):
		_bad("visit invented a stock field")
		return false
	for key in stock0:
		if int(game.stock[key]) != int(stock0[key]):
			_bad("visit moved " + key)
			return false
	if int(game.hope) != hope0 or int(game.discontent) != dis0 or int(game.orders_left) != orders0:
		_bad("visit moved hope or orders")
		return false
	if str(game.flags.get("dawn_soft_kind", "")) != dawn0 or game.outpost_ledger_dawn_chip():
		_bad("visit joined dawn")
		return false
	view.close_visit()
	view.open_visit(sid)
	if view._ledger_float != null and view._ledger_float.visible:
		_bad("second visit floated again")
		return false
	st.materials = 4
	st.food = 0
	st.goods = 7
	view.visit.size = Vector2(1280, 720)
	view._size_visit()
	view._fill_visit(sid)
	row = _row(view)
	if row == null or str(row.get_meta("ledger_kind")) != "status":
		_bad("status kind " + (str(row.get_meta("ledger_kind")) if row != null else "missing"))
		return false
	lines = _lines(row)
	if lines.size() != 1 or str(lines[0].text) != "Holds: 4 mats · 0 food · 7 goods":
		_bad("status text " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		return false
	ink = lines[0].get_theme_color("font_color")
	if not ink.is_equal_approx(NetworkView.INK):
		_bad("status ink")
		return false
	if row.get_index() != row.get_parent().get_child_count() - 1:
		_bad("status row is not last")
		return false
	view.visit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var narrow := 520
	while narrow > 160:
		view.visit_sheet.custom_minimum_size = Vector2(0, 0)
		view.visit.size = Vector2(narrow, 720)
		view._size_visit()
		if not view._ledger_fits("Holds: 4 mats · 0 food · 7 goods"):
			break
		narrow -= 40
	view._fill_visit(sid)
	row = _row(view)
	if row == null or str(row.get_meta("ledger_kind")) != "stack":
		_bad("narrow kind %s at %d avail %.0f" % [str(row.get_meta("ledger_kind")) if row != null else "missing", narrow, view._ledger_avail()])
		return false
	lines = _lines(row)
	var stacked: PackedStringArray = []
	for line in lines:
		stacked.append(str(line.text))
	if stacked != PackedStringArray(["4 mats", "0 food", "7 goods"]):
		_bad("narrow lines " + str(stacked))
		return false
	Copy.set_lang("ru")
	view.visit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.visit_sheet.custom_minimum_size = Vector2(0, 0)
	view.visit.size = Vector2(1280, 720)
	view._size_visit()
	view._fill_visit(sid)
	row = _row(view)
	lines = _lines(row) if row != null else []
	if lines.is_empty() or str(lines[0].text) != "На складе: 4 матер. · 0 еды · 7 товара":
		_bad("ru status " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	if _meta(view, "ledger_map").size() != 0:
		_bad("map mark node")
		return false
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	if int(snap.schema) != 14 or Game.SAVE_SCHEMA != 14:
		_bad("schema bumped")
		return false
	var loaded := _fresh(catalog)
	if not loaded.import_state(snap):
		_bad("save " + loaded.load_error)
		return false
	if not bool(loaded.flags.get(Ledger.FLAG, false)):
		_bad("load lost the flag")
		return false
	if int(loaded.stock.food) != int(stock0.food) or int(loaded.stock.materials) != int(stock0.materials):
		_bad("load stock")
		return false
	print("Visit: ok")
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.find("\nfunc ", at + 4)
	if next < 0:
		next = src.length()
	return src.substr(at, next - at)


func _check_dawn() -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var game := Game.new()
	if game.outpost_ledger_dawn_chip():
		_bad("dawn chip")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("ledger") >= 0 or picker.find("outpost_ledger") >= 0:
		_bad("dawn picker knows the ledger")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _fn(view, "_draw_pin")
	if pin == "" or pin.find("ledger") >= 0 or pin.find("Ledger") >= 0:
		_bad("pin draws a ledger mark")
		return false
	for draw_name in ["_draw_pins", "_draw_soft_marks", "_draw_ink"]:
		var body := _fn(view, draw_name)
		if body.find("ledger") >= 0 or body.find("Ledger") >= 0:
			_bad(draw_name + " draws a ledger mark")
			return false
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if balance.find("ledger") >= 0:
		_bad("balance mentions ledger")
		return false
	print("Dawn: ok")
	return true


func _careful_loss(catalog: Catalog) -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		if str(game.over) != "time":
			lost += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost
