extends SceneTree

const Flow = preload("res://sim/passage_flow.gd")
const Marks = preload("res://sim/deal_marks.gd")

## P58 passage flow. Tick from the live passage thread plus good_flowing.
## Held sources stay on the pin goods pip. First float once. No soft dawn. No balance drift.
##   godot --headless --path . -s res://sim/check_passage_flow.gd

var failed := false
var balance_text := ""


func _init() -> void:
	Copy.set_lang("en")
	balance_text = FileAccess.get_file_as_string("res://data/balance.json")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	if not _check_show(catalog):
		failed = true
	if not _check_tint():
		failed = true
	if not _check_float(catalog):
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_draw():
		failed = true
	if not _check_balance():
		failed = true
	if failed:
		print("PASSAGE FLOW FAIL")
		quit(1)
		return
	print("PASSAGE FLOW OK")
	quit(0)


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	_quiet(game)
	return game


func _quiet(game: Game) -> void:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		st.deals = 0
		st.passage = false


func _arm(game: Game, sid: String, deals: int, passage: bool, owner: String, known: bool, hidden: bool = false) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = owner
	st.known = known
	st.hidden = hidden
	st.deals = deals
	st.passage = passage
	st.erase("joined")


func _good_sid(game: Game) -> String:
	for sid in ["quarry", "riverside", "mill", "market", "brickworks", "eastwater", "clocktower"]:
		if game.stations.has(sid) and str(sid) != str(game.capital_id) and not game.station_good(sid).is_empty():
			return sid
	return ""


func _barren_sid(game: Game) -> String:
	for sid in game.stations:
		if str(sid) == str(game.capital_id):
			continue
		if game.station_good(str(sid)).is_empty():
			return str(sid)
	return ""


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/passage_flow.json"))
	if typeof(pack) != TYPE_DICTIONARY or not (pack.get("by_key", {}) is Dictionary):
		print("Strings: FAIL pack")
		return false
	var rows: Dictionary = pack.by_key
	if rows.has("flow.quiet") or pack.get("_omit_mvp", []).find("flow.quiet") < 0:
		print("Strings: FAIL quiet shipped")
		return false
	var keys: Array = rows.keys()
	keys.sort()
	if keys != ["flow.first", "flow.good", "flow.tip"]:
		print("Strings: FAIL keys ", keys)
		return false
	Copy.set_lang("en")
	if Copy.t("flow.tip") != "Goods ride the passage.":
		print("Strings: FAIL tip en ", Copy.t("flow.tip"))
		return false
	if Copy.t("flow.first") != "Goods ride the open passage.":
		print("Strings: FAIL first en ", Copy.t("flow.first"))
		return false
	if Copy.fill("flow.good", {"good": "Copper"}) != "Copper":
		print("Strings: FAIL good en")
		return false
	if Copy.t("flow.quiet") != "flow.quiet":
		print("Strings: FAIL quiet en ", Copy.t("flow.quiet"))
		return false
	if Copy.t("good.copper.name") != "Copper" or Copy.t("good.seeds.name") != "Seeds":
		print("Strings: FAIL good names")
		return false
	if Copy.t("good.air.name") != "Air coupons":
		print("Strings: FAIL air name ", Copy.t("good.air.name"))
		return false
	Copy.set_lang("ru")
	if Copy.t("flow.tip") != "Товар идёт по проходу.":
		print("Strings: FAIL tip ru ", Copy.t("flow.tip"))
		return false
	if Copy.t("flow.first") != "Товар идёт по открытому проходу.":
		print("Strings: FAIL first ru ", Copy.t("flow.first"))
		return false
	if Copy.fill("flow.good", {"good": "Медь"}) != "Медь":
		print("Strings: FAIL good ru")
		return false
	if Copy.t("good.copper.name") != "Медь":
		print("Strings: FAIL copper ru ", Copy.t("good.copper.name"))
		return false
	Copy.set_lang("en")
	var src := FileAccess.get_file_as_string("res://sim/copy.gd")
	if src.find("res://data/passage_flow.json") < 0:
		print("Strings: FAIL pack not merged")
		return false
	print("Strings: ok")
	return true


func _check_show(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _good_sid(game)
	if sid == "":
		print("Show: FAIL no good station")
		return false
	var barren := _barren_sid(game)
	_arm(game, sid, 0, false, "neutral", true)
	if Flow.shows(game, sid) or not Flow.tip_lines(game, sid).is_empty():
		print("Show: FAIL closed ticked")
		return false
	_arm(game, sid, 1, false, "neutral", true)
	if Flow.shows(game, sid) or game.good_flowing(sid):
		print("Show: FAIL deal without passage")
		return false
	_arm(game, sid, 0, true, "neutral", true)
	if Flow.shows(game, sid) or not Marks.shows_thread(game, sid):
		print("Show: FAIL quiet passage ticked")
		return false
	if not Flow.tip_lines(game, sid).is_empty():
		print("Show: FAIL tip without tick")
		return false
	_arm(game, sid, 1, true, "neutral", true)
	if not Flow.shows(game, sid) or not game.good_flowing(sid):
		print("Show: FAIL passage+deal")
		return false
	var lines := Flow.tip_lines(game, sid)
	var want_name := Copy.t(str(game.station_good(sid).get("name_key", "")))
	if lines.size() != 2 or lines[0] != "Goods ride the passage." or lines[1] != want_name:
		print("Show: FAIL tip ", lines, " ", want_name)
		return false
	_arm(game, sid, 1, true, "neutral", false)
	if Flow.shows(game, sid) or Marks.shows_thread(game, sid):
		print("Show: FAIL unknown thread")
		return false
	_arm(game, sid, 1, true, "neutral", false, true)
	if Flow.shows(game, sid):
		print("Show: FAIL secret")
		return false
	_arm(game, sid, 1, true, str(game.player), true)
	if Flow.shows(game, sid) or Marks.shows_thread(game, sid) or not game.good_flowing(sid):
		print("Show: FAIL held still edged")
		return false
	if not Flow.tip_lines(game, sid).is_empty():
		print("Show: FAIL held tip")
		return false
	_arm(game, str(game.capital_id), 1, true, str(game.player), true)
	if Flow.shows(game, str(game.capital_id)):
		print("Show: FAIL capital")
		return false
	if barren != "":
		_arm(game, barren, 1, true, "neutral", true)
		if Flow.shows(game, barren) or game.good_flowing(barren):
			print("Show: FAIL barren ", barren)
			return false
	_quiet(game)
	_arm(game, sid, 0, true, "neutral", true)
	var other := ""
	for candidate in game.stations:
		if str(candidate) != sid:
			other = str(candidate)
			break
	if other == "":
		print("Show: FAIL need a second station")
		return false
	_arm(game, other, 1, false, "neutral", true)
	if game.deal_count() < 1 or not Flow.shows(game, sid):
		print("Show: FAIL deal elsewhere did not open flow ", game.deal_count())
		return false
	var a := Vector2(0, 0)
	var b := Vector2(40, 80)
	var mid := Flow.midpoint(a, b)
	if not is_equal_approx(mid.x, 20.0) or not is_equal_approx(mid.y, 40.0):
		print("Show: FAIL midpoint ", mid)
		return false
	if Flow.ticks_slide() or Flow.TICK_PX < 10.0 or Flow.TICK_PX > 12.0:
		print("Show: FAIL motion or size")
		return false
	print("Show: ok")
	return true


func _check_tint() -> bool:
	if Flow.tint_of("seeds").to_html(false) != "7dba6a":
		return _tint_fail("seeds")
	if Flow.tint_of("pork").to_html(false) != "7dba6a" or Flow.tint_of("salt").to_html(false) != "7dba6a":
		return _tint_fail("food")
	if Flow.tint_of("copper").to_html(false) != "c4a574" or Flow.tint_of("junk").to_html(false) != "c4a574":
		return _tint_fail("metal")
	if Flow.tint_of("water").to_html(false) != "6f8494" or Flow.tint_of("air").to_html(false) != "6f8494":
		return _tint_fail("air")
	if Flow.tint_of("air_coupons").to_html(false) != "6f8494":
		return _tint_fail("coupons")
	var heat := Flow.tint_of("heat")
	if heat.to_html(false) != "e2a63a" or not is_equal_approx(heat.a, 1.0):
		return _tint_fail("heat")
	var brass := Flow.tint_of("")
	if brass.to_html(false) != "e2a63a" or not is_equal_approx(brass.a, 0.9):
		return _tint_fail("fallback")
	if Flow.CARD_INK.to_html(false) != "2b2118":
		return _tint_fail("ink")
	print("Tint: ok")
	return true


func _tint_fail(kind: String) -> bool:
	print("Tint: FAIL ", kind)
	return false


func _check_float(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _good_sid(game)
	_arm(game, sid, 0, true, "neutral", true)
	if Flow.note(game) != "" or bool(game.flags.get("seen_passage_flow", false)):
		print("Float: FAIL quiet fired")
		return false
	_arm(game, sid, 1, true, "neutral", true)
	var line := Flow.note(game)
	if line != "Goods ride the open passage." or not bool(game.flags.get("seen_passage_flow", false)):
		print("Float: FAIL first ", line)
		return false
	if Flow.note(game) != "":
		print("Float: FAIL second")
		return false
	print("Float: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _good_sid(game)
	_arm(game, sid, 1, true, "neutral", true)
	if Flow.note(game) != "Goods ride the open passage.":
		print("Save: FAIL float")
		return false
	var data := game.export_state()
	var loaded := Game.new()
	loaded.setup(catalog, 4, 40)
	if not loaded.import_state(data):
		print("Save: FAIL import ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_passage_flow", false)):
		print("Save: FAIL flag dropped")
		return false
	_arm(loaded, sid, 1, true, "neutral", true)
	if Flow.note(loaded) != "":
		print("Save: FAIL float after load")
		return false
	if not Flow.shows(loaded, sid):
		print("Save: FAIL tick did not load")
		return false
	print("Save: ok")
	return true


func _dawn_snapshot(game: Game) -> Dictionary:
	return {
		"flags": game.flags.duplicate(true),
		"notices": game.notices.duplicate(true),
		"reports": game.order_reports.duplicate(true),
		"chip": game.dawn_soft_chip().duplicate(true),
		"home": game.home_chip_line(false),
	}


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _good_sid(game)
	_arm(game, sid, 1, true, "neutral", true)
	var before := _dawn_snapshot(game)
	var line := Flow.note(game)
	if line != "Goods ride the open passage.":
		print("Dawn: FAIL float")
		return false
	var after := _dawn_snapshot(game)
	var flags_before: Dictionary = before.flags
	var flags_after: Dictionary = after.flags.duplicate(true)
	flags_after.erase("seen_passage_flow")
	if flags_before != flags_after:
		print("Dawn: FAIL flags changed")
		return false
	if before.notices != after.notices or before.reports != after.reports:
		print("Dawn: FAIL queued a report")
		return false
	if str(after.chip.get("kind", "")) != str(before.chip.get("kind", "")):
		print("Dawn: FAIL chip kind")
		return false
	if str(after.chip.get("kind", "")) == "flow" or str(after.home) != "":
		print("Dawn: FAIL flow chip")
		return false
	if bool(game.flags.get("rumor_dawn", false)) or bool(game.flags.get("border_dawn_new", false)):
		print("Dawn: FAIL higher chip")
		return false
	if bool(game.flags.get("rail_dawn", false)) or bool(game.flags.get("home_pending", false)) or bool(game.flags.get("heard_home", false)):
		print("Dawn: FAIL stack flag")
		return false
	var body := FileAccess.get_file_as_string("res://sim/passage_flow.gd")
	if body.find("dawn_soft") >= 0 or body.find("guide_layer") >= 0 or body.find("ModalDeck") >= 0 or body.find("flow.quiet") >= 0:
		print("Dawn: FAIL module mentions a chip")
		return false
	print("Dawn: ok")
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name + "(")
	if at < 0:
		return ""
	var rest := src.substr(at)
	var next := rest.find("\nfunc ")
	if next < 0:
		return rest
	return rest.substr(0, next)


func _check_draw() -> bool:
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var ink := _fn(view, "_draw_ink")
	var order := ["_draw_passage_edges", "_draw_pins", "_draw_deal_pips"]
	var at := -1
	for name in order:
		var found := ink.find(name, at + 1)
		if found < 0:
			print("Draw: FAIL order ", name)
			return false
		at = found
	var edges := _fn(view, "_draw_passage_edges")
	var pin := _fn(view, "_draw_pin")
	var flow := _fn(view, "_queue_passage_flow") + _fn(view, "_paint_passage_flow")
	if edges.find("_queue_passage_flow") < 0 or edges.find("_paint_passage_flow") < 0:
		print("Draw: FAIL tick not on the thread pass")
		return false
	if edges.find("length < 1.0") < 0 or edges.find("_queue_passage_flow") < edges.find("length < 1.0"):
		print("Draw: FAIL tick can invent a stroke")
		return false
	if pin.find("_queue_passage_flow") >= 0 or pin.find("_paint_passage_flow") >= 0 or pin.find("PassageFlow") >= 0:
		print("Draw: FAIL tick on the pin")
		return false
	if pin.find("_draw_good_pip") < 0 or pin.find("_draw_need_tick") < 0 or pin.find("_draw_leaflet_chip") < 0:
		print("Draw: FAIL pin adornments moved")
		return false
	if pin.find("_draw_warmth_ring") > pin.find("_draw_leaflet_chip"):
		print("Draw: FAIL warmth order")
		return false
	var siege := _fn(view, "_draw_siege")
	if siege.find("_draw_pressure_ring") < 0:
		print("Draw: FAIL pressure ring")
		return false
	if flow == "" or flow.find("PassageFlow.midpoint") < 0 or flow.find("draw_circle") < 0:
		print("Draw: FAIL disc")
		return false
	if flow.find("CARD_INK") < 0 or flow.find("tint_for") < 0 or flow.find("TICK_PX") < 0:
		print("Draw: FAIL ink or tint")
		return false
	if flow.find("_anim_t") >= 0 or flow.find("create_tween") >= 0 or flow.find("sin(") >= 0:
		print("Draw: FAIL tick moves")
		return false
	if view.find("Vector2(-r * 0.35") >= 0:
		print("Draw: FAIL focus letter slot")
		return false
	var pip := _fn(view, "_draw_good_pip")
	if pip.find("r * 0.62") < 0 or pip.find("good_flowing") < 0:
		print("Draw: FAIL goods pip")
		return false
	if not is_equal_approx(Marks.PIP_R, 2.8) or not is_equal_approx(Marks.PIP_GAP, 7.0):
		print("Draw: FAIL deal pip geometry")
		return false
	var tip := _fn(view, "_tip")
	if tip.find("PassageFlow.tip_lines") < 0:
		print("Draw: FAIL station tip")
		return false
	if view.find("func _note_first_passage_flow") < 0 or view.find("PassageFlow.note") < 0:
		print("Draw: FAIL first float hook")
		return false
	if not FileAccess.get_file_as_string("res://sim/passage_flow.gd").contains("seen_passage_flow"):
		print("Draw: FAIL flag")
		return false
	var shown := _fn(view, "_show_flow_float")
	if shown.find("_motion_off") < 0 or shown.find("guide_layer") >= 0 or shown.find("dawn") >= 0:
		print("Draw: FAIL float family")
		return false
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	if station.find("seen_passage_flow") >= 0 or station.find("flow.first") >= 0 or station.find("flow.tip") >= 0:
		print("Draw: FAIL station dawn copy")
		return false
	var deliver := _fn(FileAccess.get_file_as_string("res://sim/game.gd"), "_deliver_goods")
	if deliver.find("food_week") < 0 or deliver.find("seen_passage_flow") >= 0 or deliver.find("flow.tip") >= 0:
		print("Draw: FAIL delivery math")
		return false
	var formulas := FileAccess.get_file_as_string("res://sim/formulas.gd")
	if formulas.find("static func outpost_flow") < 0 or formulas.find("seen_passage_flow") >= 0:
		print("Draw: FAIL outpost flow")
		return false
	if view.find("flow.quiet") >= 0:
		print("Draw: FAIL quiet tip")
		return false
	print("Draw: ok")
	return true


func _check_balance() -> bool:
	var now := FileAccess.get_file_as_string("res://data/balance.json")
	if now != balance_text:
		print("Balance: FAIL file changed")
		return false
	if now.contains("seen_passage_flow") or now.contains("flow.tip") or now.contains("passage_flow"):
		print("Balance: FAIL mentions passage flow")
		return false
	var parsed = JSON.parse_string(now)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Balance: FAIL parse")
		return false
	if int(parsed.get("hope_drift", 0)) != -1 or float(parsed.get("sympathy_base", 0)) != 12.0:
		print("Balance: FAIL drift")
		return false
	print("Balance: ok")
	return true
