extends SceneTree

const Toll = preload("res://sim/quiet_toll.gd")

## P86 Quiet Toll gate.
##   godot --headless --path . -s res://sim/check_quiet_toll.gd
## Tip and Visit only. The skim line is not wired. No map tick. No soft dawn chip.
## Schema stays 17 (flag lives in flags). Careful seeds 1–60 match master.

class Host extends Node:
	var game
	var shot_mode := true
	var motion_in_shots := false
	var net_guide := false
	var net_guide_sid := ""
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)

	func _ui_click() -> void:
		pass


var _failed := false
## Careful loss on seeds 1–60, same line as the P85 gate on this master.
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
const KEYS := ["toll.name", "toll.tip", "toll.first", "toll.skim", "toll.status", "toll.status_none", "toll.need_duty", "toll.quiet"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("TOLL FAIL catalog")
		quit(1)
		return
	var balance_text := FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 23:
		_bad("schema is %s, want 23" % str(Game.SAVE_SCHEMA))
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _tip(catalog):
		_failed = true
	else:
		print("Tip: ok")
	if not await _visit(catalog):
		_failed = true
	else:
		print("Visit: ok")
	if not _dawn():
		_failed = true
	else:
		print("Dawn: ok")
	if not _skim():
		_failed = true
	else:
		print("Skim: unwired")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_text:
		_bad("balance.json changed")
	if _failed:
		print("TOLL FAIL")
		quit(1)
		return
	if not _careful_match(catalog):
		print("TOLL FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_text:
		print("TOLL FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	print("TOLL OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/quiet_toll.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P86":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != KEYS.size():
		_bad("key count %d" % rows.size())
		return false
	for key in KEYS:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		if not str(key).begins_with("toll."):
			_bad("namespace " + key)
			return false
		for banned in ["duty.", "flow.", "ledger.", "transfer."]:
			if str(key).begins_with(banned):
				_bad("banned namespace " + key)
				return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty " + key)
			return false
	var fragment = JSON.parse_string(FileAccess.get_file_as_string("res://data/quiet_toll_ru_fragment.json"))
	if not (fragment is Dictionary) or fragment.size() != KEYS.size():
		_bad("ru fragment")
		return false
	for key in KEYS:
		if str(fragment.get(key, "")) != str(rows[key].get("ru", "")):
			_bad("fragment " + key)
			return false
	Copy.set_lang("en")
	for key in KEYS:
		if Copy.t(key) != str(rows[key].get("en", "")):
			_bad("EN %s got %s" % [key, Copy.t(key)])
			return false
	Copy.set_lang("ru")
	for key in KEYS:
		if Copy.t(key) != str(rows[key].get("ru", "")):
			_bad("RU %s got %s" % [key, Copy.t(key)])
			return false
	Copy.set_lang("en")
	if Copy.t("toll.name") != "Quiet Toll":
		_bad("en name")
		return false
	if Copy.t("toll.tip") != "Quiet Toll. Duty watches foreign goods.":
		_bad("en tip")
		return false
	if Copy.t("toll.first") != "Duty watches what passes.":
		_bad("en first")
		return false
	if Copy.t("toll.need_duty") != "Post Duty to watch the flow.":
		_bad("en need_duty")
		return false
	if Copy.t("toll.quiet") != "No foreign goods this week.":
		_bad("en quiet")
		return false
	if Copy.t("toll.status") != "Quiet Toll watching.":
		_bad("en status")
		return false
	if Copy.t("toll.status_none") != "No Quiet Toll.":
		_bad("en status_none")
		return false
	if Copy.t("toll.skim") != "Quiet Toll. A few mats off the flow.":
		_bad("en skim")
		return false
	Copy.set_lang("ru")
	if Copy.t("toll.first") != "Дозор следит за тем, что идёт мимо.":
		_bad("ru first " + Copy.t("toll.first"))
		return false
	if Copy.t("toll.need_duty") != "Поставь дозор следить за потоком.":
		_bad("ru need_duty " + Copy.t("toll.need_duty"))
		return false
	if Copy.t("toll.skim") != "Тихая пошлина. Немного материалов с потока.":
		_bad("ru skim " + Copy.t("toll.skim"))
		return false
	if Copy.t("toll.status") != "Тихая пошлина действует.":
		_bad("ru status")
		return false
	Copy.set_lang("en")
	var src := FileAccess.get_file_as_string("res://sim/copy.gd")
	if src.find("res://data/quiet_toll.json") < 0:
		_bad("pack not merged")
		return false
	for path in ["res://data/transfer_hubs.json", "res://data/outpost_ledger.json", "res://data/line_wall.json", "res://data/events.json", "res://data/balance.json"]:
		var text := FileAccess.get_file_as_string(path)
		if text.find("\"toll.") >= 0:
			_bad("toll key leaked into " + path)
			return false
	if FileAccess.file_exists("res://sim/passage_duty.gd") or FileAccess.file_exists("res://sim/passage_flow.gd"):
		_bad("this PR added Duty chrome or a flow tick script")
		return false
	return true


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 8
	return game


func _pair(game: Game) -> Array:
	for sid in game.stations:
		var id := str(sid)
		if id == str(game.capital_id):
			continue
		var st: Dictionary = game.stations[id]
		if str(st.get("bunker", "")) != "" or bool(st.get("ruin", false)):
			continue
		if str(st.get("owner", "")) in ["bunker", "ruin"]:
			continue
		for other in game._neighbors(id):
			var far := str(other)
			if far == str(game.capital_id):
				continue
			if game.station_good(far).is_empty():
				continue
			var fst: Dictionary = game.stations[far]
			if str(fst.get("bunker", "")) != "" or bool(fst.get("ruin", false)):
				continue
			if str(fst.get("owner", "")) in ["bunker", "ruin"]:
				continue
			return [id, far]
	return ["", ""]


func _own(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.hidden = false
	st.passage = true


func _silence(game: Game, keep: String) -> void:
	for sid in game.stations:
		var id := str(sid)
		if id == keep:
			continue
		var st: Dictionary = game.stations[id]
		if str(st.get("owner", "")) == str(game.player):
			continue
		st.passage = false


func _flow(game: Game, far: String, on: bool) -> void:
	var other: Dictionary = game.stations[far]
	other.hidden = false
	if str(other.get("owner", "")) == str(game.player):
		other.owner = "neutral"
	if on:
		other.known = true
		other.passage = true
		other.deals = maxi(1, int(other.get("deals", 0)))
	else:
		other.passage = false
		other.deals = 0


func _clear_duty(game: Game) -> void:
	for person in game.residents:
		if person.has("duty_edge_id"):
			person.erase("duty_edge_id")


func _post_duty(game: Game, sid: String) -> void:
	_clear_duty(game)
	if game.residents.is_empty():
		return
	game.residents[0]["duty_edge_id"] = Toll.edge_id(str(game.capital_id), sid)


func _stock(game: Game) -> Dictionary:
	return {
		"food": int(game.stock.food),
		"materials": int(game.stock.materials),
		"air": int(game.stock.air),
		"tokens": int(game.stock.tokens),
		"influence": int(game.stock.influence),
		"hope": int(game.hope),
		"discontent": int(game.discontent),
		"orders": int(game.orders_left),
	}


func _last(text: String) -> String:
	var parts := text.split("\n")
	if parts.is_empty():
		return ""
	return str(parts[parts.size() - 1])


func _tip(catalog: Catalog) -> bool:
	if Toll.draws_map_tick() or Toll.skim_wired() or Toll.joins_soft_dawn():
		_bad("toll flags")
		return false
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	var far := str(pair[1])
	if sid == "" or far == "":
		_bad("no passage pair")
		return false
	var host := Host.new()
	host.game = game
	var view := NetworkView.new()
	view.host = host
	_silence(game, far)
	_own(game, sid)
	_flow(game, far, false)
	_clear_duty(game)
	if Toll.station_state(game, sid) != "" or Toll.edge_state(game, sid, far) != "" or Toll.tip_line(game, sid) != "":
		_bad("idle tip " + Toll.station_state(game, sid))
		return false
	if Toll.visit_kind(game, sid) != "":
		_bad("idle visit row")
		return false
	if Toll.tip_line(game, far) != "" or Toll.tip_line(game, str(game.capital_id)) != "":
		_bad("foreign or capital tip")
		return false
	_flow(game, far, true)
	if not Toll.foreign_display(game, far):
		_bad("foreign display did not light on " + far)
		return false
	if Toll.edge_state(game, sid, far) != "need_duty" or Toll.station_state(game, sid) != "need_duty":
		_bad("need_duty state " + Toll.edge_state(game, sid, far) + " / " + Toll.station_state(game, sid))
		return false
	if Toll.visit_kind(game, sid) != "":
		_bad("need_duty drew a visit kind")
		return false
	var lined := view._tip(sid)
	if _last(lined) != Copy.t("toll.need_duty"):
		_bad("need_duty tip [" + lined + "]")
		return false
	if lined.find(Copy.t("toll.tip")) >= 0 or lined.find(Copy.t("toll.quiet")) >= 0 or lined.find(Copy.t("toll.skim")) >= 0:
		_bad("need_duty showed another toll line")
		return false
	if lined.find(Copy.t("toll.name")) >= 0:
		_bad("need_duty used the title")
		return false
	if bool(game.flags.get(Toll.FLAG, false)) or Toll.note(game) != "":
		_bad("need_duty floated")
		return false
	if not game.residents.is_empty():
		game.residents[0]["duty_edge_id"] = Toll.edge_id("no-such", "seat")
		if Toll.station_state(game, sid) != "need_duty":
			_bad("wrong seat counted as Duty")
			return false
	var before := _stock(game)
	_post_duty(game, sid)
	if Toll.edge_state(game, sid, far) != "qualifies" or Toll.station_state(game, sid) != "qualifies":
		_bad("qualifies state")
		return false
	if Toll.visit_kind(game, sid) != "status":
		_bad("qualifies visit kind")
		return false
	var qualified := view._tip(sid)
	if _last(qualified) != Copy.t("toll.tip"):
		_bad("qualifies tip " + qualified)
		return false
	if qualified.split("\n").count(Copy.t("toll.tip")) != 1:
		_bad("tip line repeated")
		return false
	var first := Toll.note(game)
	if first != Copy.t("toll.first") or not bool(game.flags.get(Toll.FLAG, false)):
		_bad("first float " + first)
		return false
	if Toll.note(game) != "":
		_bad("second float")
		return false
	var tunnel: Dictionary = game._edge(sid, far)
	var was_until := int(tunnel.get("closed_until", 0))
	tunnel.closed_until = int(game.week) + 4
	if Toll.foreign_display(game, far) != true:
		_bad("closing the tunnel changed the flow display")
		tunnel.closed_until = was_until
		return false
	if Toll.edge_state(game, sid, far) != "" or Toll.station_state(game, sid) != "quiet":
		_bad("closed edge still tolled " + Toll.edge_state(game, sid, far) + " / " + Toll.station_state(game, sid))
		tunnel.closed_until = was_until
		return false
	tunnel.closed_until = was_until
	if Toll.edge_state(game, sid, far) != "qualifies":
		_bad("reopened edge did not return")
		return false
	_flow(game, far, false)
	if Toll.foreign_display(game, far):
		_bad("flow display stayed on")
		return false
	if Toll.station_state(game, sid) != "quiet" or Toll.visit_kind(game, sid) != "none":
		_bad("quiet state " + Toll.station_state(game, sid))
		return false
	if _last(view._tip(sid)) != Copy.t("toll.quiet"):
		_bad("quiet tip " + view._tip(sid))
		return false
	var seat: Dictionary = game.stations[sid]
	seat.passage = false
	if Toll.station_state(game, sid) != "" or Toll.tip_line(game, sid) != "" or Toll.visit_kind(game, sid) != "":
		_bad("closed passage still tolled")
		return false
	seat.passage = true
	seat.hidden = true
	seat.known = false
	if Toll.owned_seat(game, sid) or Toll.tip_line(game, sid) != "":
		_bad("hidden seat tolled")
		return false
	seat.hidden = false
	seat.known = true
	if _stock(game) != before:
		_bad("tip moved stock or hope")
		return false
	Copy.set_lang("ru")
	_flow(game, far, true)
	if _last(view._tip(sid)) != "Тихая пошлина. Дозор следит за чужим товаром.":
		_bad("ru tip " + _last(view._tip(sid)))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	if int(snap.schema) != 23:
		_bad("schema bumped")
		return false
	if not bool(snap.flags.get(Toll.FLAG, false)):
		_bad("flag missing from save")
		return false
	var loaded := Game.new()
	loaded.catalog = catalog
	if not loaded.import_state(snap):
		_bad("save " + loaded.load_error)
		return false
	if not bool(loaded.flags.get(Toll.FLAG, false)):
		_bad("load lost seen_quiet_toll")
		return false
	if str(loaded.residents[0].get("duty_edge_id", "")) != Toll.edge_id(str(game.capital_id), sid):
		_bad("save dropped duty_edge_id")
		return false
	if int(loaded.stock.materials) != int(before.materials) or int(loaded.hope) != int(before.hope):
		_bad("load stock")
		return false
	return true


func _meta(node: Node, key: String) -> Array:
	var found: Array = []
	if node == null:
		return found
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here == null or not is_instance_valid(here) or here.is_queued_for_deletion():
			continue
		if here.has_meta(key):
			found.append(here)
		for child in here.get_children():
			stack.append(child)
	return found


func _before_ledger(row: Node) -> String:
	var parent := row.get_parent()
	if parent == null:
		return "no parent"
	if row.get_index() != parent.get_child_count() - 2:
		return "not directly above the last row"
	var nxt := parent.get_child(row.get_index() + 1)
	if not nxt.has_meta("ledger_row") or not bool(nxt.get_meta("ledger_last", false)):
		return "next row is not the ledger"
	if nxt.get_index() != parent.get_child_count() - 1:
		return "ledger is not last"
	return ""


func _visit(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	var far := str(pair[1])
	if sid == "" or far == "":
		_bad("visit pair")
		return false
	var host := Host.new()
	host.game = game
	host.shot_mode = true
	host.motion_in_shots = false
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	root.add_child(view)
	if view.has_method("_draw_flow_tick") or view.has_method("_draw_toll_tick"):
		_bad("map tick method")
		return false
	_silence(game, far)
	_own(game, sid)
	_flow(game, far, true)
	_clear_duty(game)
	game.flags.erase(Toll.FLAG)
	var before := _stock(game)
	view.open_visit(sid)
	if not _meta(view.visit, "toll_row").is_empty():
		_bad("need_duty drew a visit row")
		return false
	var ledgers := _meta(view.visit, "ledger_row")
	if ledgers.size() != 1 or ledgers[0].get_index() != ledgers[0].get_parent().get_child_count() - 1:
		_bad("ledger did not stay last without a toll row")
		return false
	if view._toll_float != null and view._toll_float.visible:
		_bad("need_duty floated")
		return false
	view.open_visit(str(game.capital_id))
	if not _meta(view.visit, "toll_row").is_empty():
		_bad("capital visit row")
		return false
	view.open_visit(far)
	if not _meta(view.visit, "toll_row").is_empty():
		_bad("foreign visit row")
		return false
	view.close_visit()
	view.open_sheet(sid)
	if _meta(view._sheet_body, "transfer_status").is_empty():
		_bad("sheet did not open")
		return false
	if not _meta(view._sheet_body, "toll_row").is_empty():
		_bad("sheet drew a toll row")
		return false
	view.close_sheet()
	_post_duty(game, sid)
	_flow(game, far, false)
	view.open_visit(sid)
	var muted := _meta(view.visit, "toll_row")
	if muted.size() != 1 or str(muted[0].get_meta("toll_kind")) != "none" or not bool(muted[0].get_meta("toll_muted")):
		_bad("status_none")
		return false
	if str(muted[0].text) != Copy.t("toll.status_none"):
		_bad("status_none text " + str(muted[0].text))
		return false
	if not muted[0].get_theme_color("font_color").is_equal_approx(NetworkView.MUTED):
		_bad("status_none ink")
		return false
	var why := _before_ledger(muted[0])
	if why != "":
		_bad("status_none " + why)
		return false
	var transfer := _meta(view.visit, "transfer_status")
	if transfer.is_empty() or transfer[0].get_index() >= muted[0].get_index():
		_bad("transfer hub is not above the toll row")
		return false
	if view._toll_float != null and view._toll_float.visible:
		_bad("quiet floated")
		return false
	_flow(game, far, true)
	game.flags.erase(Toll.FLAG)
	view.open_visit(sid)
	var row := _meta(view.visit, "toll_row")
	if row.size() != 1 or str(row[0].get_meta("toll_kind")) != "status" or bool(row[0].get_meta("toll_muted")):
		_bad("status row")
		return false
	if str(row[0].text) != Copy.t("toll.status"):
		_bad("status text " + str(row[0].text))
		return false
	if not row[0].get_theme_color("font_color").is_equal_approx(NetworkView.INK):
		_bad("status ink")
		return false
	why = _before_ledger(row[0])
	if why != "":
		_bad("status " + why)
		return false
	transfer = _meta(view.visit, "transfer_status")
	if transfer.is_empty() or transfer[0].get_index() >= row[0].get_index():
		_bad("transfer hub dropped below the toll row")
		return false
	if view._toll_float == null or not view._toll_float.visible or view._toll_float.text != Copy.t("toll.first"):
		_bad("visit float")
		return false
	if not bool(view._toll_float.get_meta("toll_float_static", false)):
		_bad("float moved under reduce-motion")
		return false
	var y := view._toll_float.position.y
	var alpha := view._toll_float.modulate.a
	for _i in 3:
		await process_frame
	if not view._toll_float.visible or not is_equal_approx(view._toll_float.position.y, y) or not is_equal_approx(view._toll_float.modulate.a, alpha):
		_bad("float was not static")
		return false
	if Toll.note(game) != "":
		_bad("visit floated twice")
		return false
	if _stock(game) != before:
		_bad("visit moved stock or hope")
		return false
	if str(game.dawn_soft_chip().get("kind", "")) == "toll" or game.quiet_toll_dawn_chip():
		_bad("visit joined dawn")
		return false
	Copy.set_lang("ru")
	view._fill_visit(sid)
	row = _meta(view.visit, "toll_row")
	if row.size() != 1 or str(row[0].text) != "Тихая пошлина действует.":
		_bad("ru visit " + (str(row[0].text) if not row.is_empty() else "missing"))
		Copy.set_lang("en")
		return false
	if _before_ledger(row[0]) != "":
		_bad("ru row left the ledger")
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.find("\nfunc ", at + 4)
	if next < 0:
		next = src.length()
	return src.substr(at, next - at)


func _dawn() -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var game := Game.new()
	if game.quiet_toll_dawn_chip() or game.dawn_soft_stack().has("toll") or game.dawn_soft_stack().has("quiet_toll"):
		_bad("dawn chip")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("toll") >= 0 or picker.find("quiet_toll") >= 0:
		_bad("dawn picker knows the toll")
		return false
	if src.find("const SAVE_SCHEMA := 23") < 0 or src.find("V19_ADDED") < 0 or src.find("V20_ADDED") < 0:
		_bad("schema bump")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	for draw_name in ["_draw_passage_edges", "_draw_ink", "_draw_pins", "_draw_pin"]:
		var body := _fn(view, draw_name)
		if body.find("QuietToll") >= 0 or body.find("toll_float") >= 0 or body.find("_add_quiet_toll") >= 0:
			_bad(draw_name + " draws a toll mark")
			return false
	if view.find("func _draw_flow_tick") >= 0 or view.find("func _draw_toll_tick") >= 0:
		_bad("tick function added")
		return false
	var visit := _fn(view, "_fill_visit")
	var transfer_at := visit.find("_add_transfer_status")
	var toll_at := visit.find("_add_quiet_toll")
	var ledger_at := visit.find("_add_outpost_ledger")
	if transfer_at < 0 or toll_at < 0 or ledger_at < 0 or not (transfer_at < toll_at and toll_at < ledger_at):
		_bad("visit order")
		return false
	var rest := visit.substr(toll_at + "_add_quiet_toll".length(), ledger_at - toll_at - "_add_quiet_toll".length())
	if rest.find("_add_") >= 0:
		_bad("a row was inserted between Quiet Toll and the ledger")
		return false
	if _fn(view, "_fill_sheet_body").find("_add_quiet_toll") >= 0:
		_bad("sheet draws the toll")
		return false
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if balance.find("quiet_toll") >= 0 or balance.find("toll.skim") >= 0 or balance.find("seen_quiet_toll") >= 0:
		_bad("balance mentions the toll")
		return false
	return true


func _skim() -> bool:
	for path in ["res://sim/quiet_toll.gd", "res://ui/network_view.gd", "res://sim/game.gd", "res://ui/station.gd", "res://sim/copy.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.find("toll.skim") >= 0:
			_bad("skim key wired in " + path)
			return false
		if src.find("skim_once") >= 0:
			_bad("skim_once in " + path)
			return false
		if src.find("stock.materials") >= 0 and path.ends_with("quiet_toll.gd"):
			_bad("toll reader touches materials")
			return false
	if Toll.skim_wired():
		_bad("skim flag")
		return false
	var reader := FileAccess.get_file_as_string("res://sim/quiet_toll.gd")
	if reader.find("balance") >= 0 or reader.find(".stock") >= 0:
		_bad("toll reader touches balance or stock")
		return false
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
	var need_duty := 0
	var qualifies := 0
	var quiet := 0
	var line_seeds := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = false
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var saw := {"need_duty": false, "qualifies": false, "quiet": false}
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
			for sid in game.stations:
				var state := Toll.station_state(game, str(sid))
				if saw.has(state):
					saw[state] = true
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
		if bool(saw.need_duty) or bool(saw.qualifies) or bool(saw.quiet):
			line_seeds += 1
		if bool(saw.need_duty):
			need_duty += 1
		if bool(saw.qualifies):
			qualifies += 1
		if bool(saw.quiet):
			quiet += 1
		if bool(saw.qualifies) or bool(saw.quiet):
			_bad("seed %d posted Duty without a seat" % run_seed)
		print("Seed %d: %d %s %s" % [run_seed, got, str(game.over), "match" if same else "DIFF"])
	print("Play: careful toll line on %d/60 seeds (need_duty %d, qualifies %d, quiet %d)" % [line_seeds, need_duty, qualifies, quiet])
	print("Careful loss: %d/60 (master baseline %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss %d/60 seeds %s moved off master %d/60 (%s)" % [lost, ",".join(lost_seeds), BASELINE_LOST, LOST_SEEDS])
		return false
	return matched == 60 and not _failed
