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
## Outcome hash of careful seeds 1–60 on master (over, hope, discontent, stock, pop, held outposts).
## Seeds 20 and 52 are the two losses.
const MASTER_HASH := [
	685489853, 2077930714, 724780967, 1800880849, 1595480338, 1657721342, 42879747, 1295760337, 1179903042, 1933464561,
	1712488965, 1434185768, 211814834, 188380414, 21704523, 1921330802, 2048561698, 335701857, 2012426658, 1813892606,
	14076918, 1150753745, 1229728296, 608757856, 985255655, 1484892223, 1591467274, 561092536, 1331711175, 404484709,
	426068196, 1959047610, 245661988, 250596865, 336801062, 2026160392, 1246035434, 1127915952, 1979973131, 2037238125,
	979147680, 1146496327, 555322251, 1917007878, 62025254, 844289426, 1547701616, 1966069534, 438401470, 255897303,
	634966363, 540671440, 409203915, 746034854, 1727047236, 847580214, 368059940, 861220846, 291082730, 714422925,
]


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
	var rows: Dictionary = pack.get("by_key", {})
	rows = rows.duplicate()
	rows.erase("ledger.empty")
	if rows.size() != 7:
		_bad("pack key count")
		return false
	var want := ["ledger.name", "ledger.tip", "ledger.first", "ledger.status", "ledger.mats", "ledger.food", "ledger.goods"]
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
	if Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}) != "За прошлую неделю: 4 матер. · 0 еды · 7 товара":
		_bad("ru status fill " + Copy.fill("ledger.status", {"mats": 4, "food": 0, "goods": 7}))
		return false
	if Copy.fill("ledger.mats", {"n": 4}) != "4 матер.":
		_bad("ru mats")
		return false
	if Copy.t("ledger.tip") != "Книга форпоста. Что ушло с этой станции за прошлую неделю.":
		_bad("ru tip " + Copy.t("ledger.tip"))
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


func _check_ledger(catalog: Catalog) -> bool:
	if Ledger.map_mark() or Ledger.joins_soft_dawn():
		_bad("mark or dawn helper")
		return false
	var src := FileAccess.get_file_as_string("res://sim/outpost_ledger.gd")
	if src.find("rand") >= 0 or src.find("held_weeks =") >= 0 or src.find("ledger.empty") >= 0:
		_bad("ledger reader rolls, writes, or shows the empty line")
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
	if Ledger.shows(game, sid):
		_bad("held_weeks 0 showed a row")
		return false
	st.erase("materials")
	st.erase("food")
	st.erase("goods")
	st.erase("stock")
	if st.keys() != before_keys:
		_bad("reader wrote a station field")
		return false
	st.held_weeks = 6
	st.focus = "food"
	st.governor = ""
	var want := _manual_flow(game, sid)
	var row: Dictionary = Ledger.amounts(game, sid)
	if int(want.mats) == 0 and int(want.food) == 0 and int(want.goods) == 0:
		_bad("linked outpost flow is zero")
		return false
	if int(row.mats) != int(want.mats) or int(row.food) != int(want.food) or int(row.goods) != int(want.goods) or not Ledger.shows(game, sid):
		_bad("flow %s want %s" % [str(row), str(want)])
		return false
	if Ledger.status_text(row) != Copy.fill("ledger.status", want):
		_bad("status " + Ledger.status_text(row))
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
	if Ledger.shows(game, cut):
		_bad("cut line showed a row")
		return false
	game.log.append({"week": int(game.week), "text": "ORDER %s focuses on air" % str(st.name), "important": false})
	if Ledger.shows(game, sid):
		_bad("focus changed this week still showed")
		return false
	game.log.pop_back()
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


func _visit_text(view: NetworkView) -> String:
	var bits: PackedStringArray = []
	for line in _meta(view.visit, "ledger_line"):
		bits.append(str(line.text))
	return "\n".join(bits)


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
	if _row(view) != null or bool(game.flags.get(Ledger.FLAG, false)):
		_bad("no delivery still showed a row")
		return false
	st.held_weeks = 6
	st.focus = "food"
	st.governor = ""
	var want := _manual_flow(game, sid)
	view._fill_visit(sid)
	var row := _row(view)
	if row == null or str(row.get_meta("ledger_kind")) != "status":
		_bad("flow kind " + (str(row.get_meta("ledger_kind")) if row != null else "missing"))
		return false
	if row.get_index() != row.get_parent().get_child_count() - 1 or not bool(row.get_meta("ledger_last", false)):
		_bad("ledger is not the last status row")
		return false
	var lines := _lines(row)
	var status := Copy.fill("ledger.status", want)
	if lines.size() != 1 or str(lines[0].text) != status:
		_bad("flow text " + (str(lines[0].text) if not lines.is_empty() else "missing"))
		return false
	var ink: Color = lines[0].get_theme_color("font_color")
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
	if _row(view) != null:
		_bad("severed visit showed a row")
		return false
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
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
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
		var got := _outcome_hash(game)
		var want := int(MASTER_HASH[run_seed - 1])
		var same := got == want
		if same:
			matched += 1
		else:
			_bad("seed %d hash %d master %d" % [run_seed, got, want])
		if str(game.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		print("Seed %d: %d %s %s" % [run_seed, got, str(game.over), "match" if same else "DIFF"])
	print("Seed outcomes: %d/60 match master" % matched)
	print("Careful loss: %d/60 (master baseline %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	if lost != BASELINE_LOST or lost_seeds != PackedStringArray(["20", "52"]):
		_bad("careful loss %d/60 seeds %s moved off master 2/60 (20,52)" % [lost, ",".join(lost_seeds)])
		return false
	return matched == 60
