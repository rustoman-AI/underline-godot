extends SceneTree

const Ledger = preload("res://sim/outpost_ledger.gd")

## P85 Outpost Ledger gate.
##   godot --headless --path . -s res://sim/check_outpost_ledger.gd
## Visit glance only. No map mark. No soft dawn chip. No balance edit.
## Schema stays 17 (flag lives in flags). Careful seeds 1–60 match master.

class Host extends Node:
	var game
	var shot_mode := false
	var motion_in_shots := false
	var net_guide := false
	var net_guide_sid := ""
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)

	func _ui_click() -> void:
		pass


var _failed := false
## Careful loss on seeds 1–60, same line as the P84 gate on this master.
const BASELINE_LOST := 20
## Outcome hash of careful seeds 1–60 on this master (over, hope, discontent, stock, pop, held outposts).
## Lost seeds: 1, 8, 11, 12, 13, 14, 23, 27, 28, 30, 33, 35, 39, 40, 41, 45, 51, 52, 56, 57.
const MASTER_HASH := [
	530485220, 1440811691, 812324724, 1813219972, 325093522, 595908171, 2008396391, 1780671410, 856785781, 158007594,
	927219026, 88326475, 1637882681, 1666385348, 109892276, 1909826692, 17422148, 1248879695, 53792616, 1638580681,
	1667606982, 225933280, 1956210069, 664024800, 910860718, 1749011044, 317060065, 247917712, 1212469253, 1368249385,
	1040415204, 699411940, 240273769, 1927554047, 1435382424, 289105020, 1555551452, 991802799, 73486466, 389179272,
	1820378459, 1369693866, 479947888, 2022586468, 14678228, 2098321440, 788241386, 462862112, 1956553458, 372817444,
	1943912010, 743372996, 2101744492, 1885192366, 1640866844, 1363718713, 230067406, 1872288106, 522666115, 82470554,
]
const LOST_SEEDS := "1,8,11,12,13,14,23,27,28,30,33,35,39,40,41,45,51,52,56,57"


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
	if Game.SAVE_SCHEMA != 21:
		_bad("schema is %s, want 21" % str(Game.SAVE_SCHEMA))
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
	if not _careful_match(catalog):
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
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	rows = rows.duplicate()
	if rows.size() != 8:
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
	var fragment = JSON.parse_string(FileAccess.get_file_as_string("res://data/outpost_ledger_ru_fragment.json"))
	if not (fragment is Dictionary):
		_bad("ru fragment")
		return false
	for key in want:
		if str(fragment.get(key, "")) != str(rows[key].get("ru", "")):
			_bad("fragment " + key)
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
	if Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}) != "За прошлую неделю: 4 матер. · 0 еды · 7 товара":
		_bad("ru status fill " + Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}))
		return false
	if Copy.fill("ledger.mats", {"n": 4}) != "4 матер.":
		_bad("ru mats")
		return false
	if Copy.t("ledger.name") != "Книга заставы":
		_bad("ru name " + Copy.t("ledger.name"))
		return false
	if Copy.t("ledger.tip") != "Книга заставы. Что ушло с этой станции за прошлую неделю.":
		_bad("ru tip " + Copy.t("ledger.tip"))
		return false
	if Copy.t("ledger.first") != "Застава ведёт книгу.":
		_bad("ru first " + Copy.t("ledger.first"))
		return false
	if Copy.t("ledger.empty") != "За прошлую неделю ничего не прошло.":
		_bad("ru empty " + Copy.t("ledger.empty"))
		return false
	Copy.set_lang("en")
	if Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}) != "Last week: 4 mats · 0 food · 7 goods":
		_bad("en status fill")
		return false
	if Copy.t("ledger.first") != "The outpost keeps a ledger.":
		_bad("en first")
		return false
	if Copy.t("ledger.tip") != "Outpost Ledger. What this station shipped last week.":
		_bad("en tip")
		return false
	if Copy.t("ledger.empty") != "Nothing came through last week.":
		_bad("en empty " + Copy.t("ledger.empty"))
		return false
	if Copy.t("ledger.name") != "Outpost Ledger":
		_bad("en name")
		return false
	for key in rows:
		if str(key).begins_with("wall"):
			_bad("wall key in ledger pack")
			return false
	var wall := FileAccess.get_file_as_string("res://data/line_wall.json")
	if wall.find("\"ledger.") >= 0:
		_bad("line wall pack gained ledger keys")
		return false
	print("Strings: ok")
	return true


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


func _linked(game: Game) -> String:
	for n in game._neighbors(game.capital_id):
		var sid := str(n)
		var st: Dictionary = game.stations[sid]
		if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
			continue
		return sid
	return ""


func _severed(game: Game, skip: String) -> String:
	for sid in game.stations:
		if str(sid) == str(game.capital_id) or str(sid) == skip:
			continue
		var st: Dictionary = game.stations[sid]
		if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
			continue
		if int(game._supply_hops(str(sid))) >= 900:
			return str(sid)
	return ""


func _manual_flow(game: Game, sid: String) -> Dictionary:
	var st: Dictionary = game.stations[sid]
	var focus := str(st.get("focus", ""))
	var gov := str(st.get("governor", ""))
	var flow := Formulas.outpost_flow(int(st.get("held_weeks", 0)), int(game._supply_hops(sid)), focus, int(game.governor_bonus(gov, focus)), int(game.governor_settle(gov)), game.catalog.station_goods(sid))
	flow = game._with_food_focus_bonus(flow, focus)
	return {
		"mats": int(flow.get("materials", 0)) - int(flow.get("upkeep_materials", 0)),
		"food": int(flow.get("food", 0)),
		"goods": int(flow.get("tokens", 0)) + int(flow.get("influence", 0)) + int(flow.get("air", 0)),
	}


func _same_flow(row: Dictionary, want: Dictionary) -> bool:
	return int(row.get("mats", 0)) == int(want.mats) and int(row.get("food", 0)) == int(want.food) and int(row.get("goods", 0)) == int(want.goods)


func _check_ledger(catalog: Catalog) -> bool:
	if Ledger.map_mark() or Ledger.joins_soft_dawn():
		_bad("mark or dawn helper")
		return false
	var src := FileAccess.get_file_as_string("res://sim/outpost_ledger.gd")
	if src.find("rand") >= 0 or src.find("held_weeks =") >= 0 or src.find("balance") >= 0:
		_bad("ledger reader rolls, writes, or reads balance")
		return false
	if src.find("wall.") >= 0:
		_bad("ledger reader mentions wall")
		return false
	print("Ledger fields: " + ", ".join(Ledger.fields_read()))
	var game := _fresh(catalog)
	var sid := _linked(game)
	if sid == "":
		_bad("no linked outpost")
		return false
	var st: Dictionary = game.stations[sid]
	var before_keys: Array = st.keys()
	st.owner = game.player
	st.known = true
	st.hidden = false
	st.materials = 9
	st.food = 9
	st.goods = 9
	if not Ledger.shows(game, sid) or not Ledger.is_empty(game, sid) or Ledger.empty_text() != Copy.t("ledger.empty"):
		_bad("held_weeks 0 did not read empty")
		return false
	st.erase("materials")
	st.erase("food")
	st.erase("goods")
	st.erase("stock")
	if st.keys() != before_keys:
		_bad("reader wrote a station field")
		return false
	st.held_weeks = 2
	st.focus = "food"
	st.governor = ""
	var young := _manual_flow(game, sid)
	var young_row: Dictionary = Ledger.amounts(game, sid)
	if not _same_flow(young_row, young):
		_bad("settle flow %s want %s" % [str(young_row), str(young)])
		return false
	var young_zero := int(young.mats) == 0 and int(young.food) == 0 and int(young.goods) == 0
	if bool(young_row.get("empty", true)) != young_zero:
		_bad("settle empty flag")
		return false
	st.held_weeks = 6
	var want := _manual_flow(game, sid)
	var row: Dictionary = Ledger.amounts(game, sid)
	if int(want.mats) == 0 and int(want.food) == 0 and int(want.goods) == 0:
		_bad("linked outpost flow is zero")
		return false
	if not _same_flow(row, want) or not Ledger.shows(game, sid) or bool(row.get("empty", true)):
		_bad("flow %s want %s" % [str(row), str(want)])
		return false
	if Ledger.status_text(row) != Copy.fill("ledger.status", want):
		_bad("status " + Ledger.status_text(row))
		return false
	if str(Ledger.status_text(row)).find("0") < 0 and (int(want.mats) == 0 or int(want.food) == 0 or int(want.goods) == 0):
		_bad("a zero was dropped")
		return false
	var cut := _severed(game, sid)
	if cut == "":
		_bad("no severed outpost")
		return false
	var far: Dictionary = game.stations[cut]
	far.owner = game.player
	far.known = true
	far.hidden = false
	far.held_weeks = 6
	far.focus = "food"
	if not Ledger.shows(game, cut) or not Ledger.is_empty(game, cut):
		_bad("cut line did not read empty")
		return false
	game.log.append({"week": int(game.week), "text": "ORDER %s focuses on air" % str(st.name), "important": false})
	if not Ledger.shows(game, sid) or not Ledger.is_empty(game, sid):
		_bad("focus changed this week did not read empty")
		return false
	game.log.pop_back()
	game.journal.append({"week": int(game.week), "kind": "governor", "station": sid})
	if not Ledger.is_empty(game, sid):
		_bad("governor changed this week did not read empty")
		return false
	game.journal.pop_back()
	if not Ledger.shows(game, sid) or Ledger.is_empty(game, sid):
		_bad("flow did not return after the inputs settled")
		return false
	if Ledger.shows(game, game.capital_id):
		_bad("home shows")
		return false
	st.owner = "neutral"
	if Ledger.shows(game, sid):
		_bad("unowned shows")
		return false
	st.owner = game.player
	st.hidden = true
	if Ledger.shows(game, sid):
		_bad("hidden shows")
		return false
	st.hidden = false
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
	var sid := _linked(game)
	if sid == "":
		_bad("visit pair")
		return false
	var foreign := ""
	for other in game.stations:
		if str(other) != sid and str(other) != str(game.capital_id) and str(game.stations[other].owner) != str(game.player):
			foreign = str(other)
			break
	if foreign == "":
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
	## _motion_off reads shot_mode before Settings.reduced(), which reloads the file and would clear an in-memory flag.
	host.shot_mode = true
	host.motion_in_shots = false
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
	if _meta(view._sheet_body, "transfer_status").is_empty():
		_bad("sheet did not open")
		return false
	if not _meta(view._sheet_body, "ledger_row").is_empty() or bool(game.flags.get(Ledger.FLAG, false)):
		_bad("sheet showed the ledger")
		return false
	view.close_sheet()
	view.open_visit(sid)
	var row := _row(view)
	if row == null or str(row.get_meta("ledger_kind")) != "empty":
		_bad("no delivery kind " + (str(row.get_meta("ledger_kind")) if row != null else "missing"))
		return false
	var lines := _lines(row)
	if lines.size() != 1 or str(lines[0].text) != "Nothing came through last week.":
		_bad("empty text " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		return false
	var ink: Color = lines[0].get_theme_color("font_color")
	if not ink.is_equal_approx(NetworkView.MUTED):
		_bad("empty ink " + str(ink))
		return false
	if str(row.tooltip_text) != Copy.t("ledger.tip") or str(lines[0].tooltip_text) != row.tooltip_text:
		_bad("empty tip")
		return false
	if row.get_index() != row.get_parent().get_child_count() - 1:
		_bad("empty row is not last")
		return false
	var transfer := _meta(row.get_parent(), "transfer_status")
	if transfer.is_empty() or int(transfer[0].get_index()) >= row.get_index():
		_bad("transfer row is not above the ledger")
		return false
	st.held_weeks = 6
	st.focus = "food"
	st.governor = ""
	var want := _manual_flow(game, sid)
	view._fill_visit(sid)
	row = _row(view)
	if row == null or str(row.get_meta("ledger_kind")) != "status":
		_bad("flow kind " + (str(row.get_meta("ledger_kind")) if row != null else "missing"))
		return false
	if row.get_index() != row.get_parent().get_child_count() - 1 or not bool(row.get_meta("ledger_last", false)):
		_bad("ledger is not the last status row")
		return false
	transfer = _meta(row.get_parent(), "transfer_status")
	if transfer.is_empty() or int(transfer[0].get_index()) >= row.get_index():
		_bad("transfer row moved")
		return false
	lines = _lines(row)
	var status := Copy.fill("ledger.status", want)
	if lines.size() != 1 or str(lines[0].text) != status:
		_bad("flow text " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		return false
	ink = lines[0].get_theme_color("font_color")
	if not ink.is_equal_approx(NetworkView.INK):
		_bad("flow ink " + str(ink))
		return false
	if str(row.tooltip_text) != Copy.t("ledger.tip") or str(lines[0].tooltip_text) != row.tooltip_text:
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
	view.visit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var narrow := 520
	var wide_line := status
	while narrow > 160:
		for child in view._visit_body.get_children():
			view._visit_body.remove_child(child)
			child.free()
		view.visit_sheet.custom_minimum_size = Vector2(0, 0)
		view.visit.size = Vector2(narrow, 720)
		view._size_visit()
		if not view._ledger_fits(wide_line):
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
	var stack_want := Ledger.stack_text(want)
	if stacked != stack_want:
		_bad("narrow lines " + str(stacked))
		return false
	if row.get_index() != row.get_parent().get_child_count() - 1:
		_bad("narrow row is not last")
		return false
	Copy.set_lang("ru")
	view.visit.set_anchors_preset(Control.PRESET_TOP_LEFT)
	view.visit_sheet.custom_minimum_size = Vector2(0, 0)
	view.visit.size = Vector2(1280, 720)
	view._size_visit()
	view._fill_visit(sid)
	row = _row(view)
	lines = _lines(row) if row != null else []
	if lines.is_empty() or str(lines[0].text) != Copy.fill("ledger.status", want):
		_bad("ru status " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var cut := _severed(game, sid)
	if cut == "":
		_bad("no severed outpost")
		return false
	var far: Dictionary = game.stations[cut]
	far.owner = game.player
	far.known = true
	far.hidden = false
	far.held_weeks = 6
	far.focus = "food"
	far.governor = ""
	view.visit.size = Vector2(1280, 720)
	view._size_visit()
	view._fill_visit(cut)
	row = _row(view)
	lines = _lines(row)
	if row == null or str(row.get_meta("ledger_kind")) != "empty" or lines.is_empty() or str(lines[0].text) != Copy.t("ledger.empty"):
		_bad("severed visit " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		return false
	if not lines[0].get_theme_color("font_color").is_equal_approx(NetworkView.MUTED):
		_bad("severed ink")
		return false
	if _meta(view, "ledger_map").size() != 0:
		_bad("map mark node")
		return false
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	if int(snap.schema) != 21 or Game.SAVE_SCHEMA != 21:
		_bad("schema bumped")
		return false
	if not bool(snap.flags.get(Ledger.FLAG, false)):
		_bad("flag missing from save")
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
	if game.outpost_ledger_dawn_chip() or Ledger.joins_soft_dawn():
		_bad("dawn chip")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("ledger") >= 0 or picker.find("outpost_ledger") >= 0:
		_bad("dawn picker knows the ledger")
		return false
	if src.find("const SAVE_SCHEMA := 21") < 0 or src.find("V19_ADDED") >= 0:
		_bad("schema bump")
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
	var visit := _fn(view, "_fill_visit")
	var transfer_at := visit.find("_add_transfer_status")
	var ledger_at := visit.find("_add_outpost_ledger")
	if transfer_at < 0 or ledger_at < 0 or ledger_at < transfer_at:
		_bad("visit order")
		return false
	if _fn(view, "_fill_sheet_body").find("_add_outpost_ledger") >= 0:
		_bad("sheet draws the ledger")
		return false
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if balance.find("ledger") >= 0:
		_bad("balance mentions ledger")
		return false
	print("Dawn: ok")
	return true


func _outcome_hash(game: Game) -> int:
	var ids: Array = game.stations.keys()
	ids.sort()
	var held := PackedStringArray()
	for sid in ids:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != str(game.player):
			continue
		held.append("%s:%s:%s" % [str(sid), str(st.get("held_weeks", 0)), str(st.get("focus", ""))])
	var line := "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(), ",".join(held)]
	var h := 5381
	for i in line.length():
		h = ((h << 5) + h) + line.unicode_at(i)
		h = h & 0x7fffffff
	return h


func _careful_match(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60 or LOST_SEEDS.split(",").size() != BASELINE_LOST:
		_bad("baseline missing")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	var printed := PackedStringArray()
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = false
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		var got := _outcome_hash(game)
		printed.append(str(got))
		var want := 0
		if run_seed - 1 < MASTER_HASH.size():
			want = int(MASTER_HASH[run_seed - 1])
		var same := got == want and MASTER_HASH.size() == 60
		if same:
			matched += 1
		else:
			_bad("seed %d hash %d master %d" % [run_seed, got, want])
		if str(game.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		print("Seed %d: %d %s %s" % [run_seed, got, str(game.over), "match" if same else "DIFF"])
	print("HASHES " + ",".join(printed))
	print("Seed outcomes: %d/60 match master" % matched)
	print("Careful loss: %d/60 (master baseline %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss %d/60 seeds %s moved off master %d/60 (%s)" % [lost, ",".join(lost_seeds), BASELINE_LOST, LOST_SEEDS])
		return false
	return matched == 60
