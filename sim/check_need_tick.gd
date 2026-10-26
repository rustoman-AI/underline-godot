extends SceneTree

const Tick = preload("res://sim/need_tick.gd")
const Dust = preload("res://sim/leaflet_dust.gd")
const Marks = preload("res://sim/deal_marks.gd")

## P49 need tick. An envoy resolve that improves a need leaves a two-week mark.
## Propaganda, deal, aid, and drift never spawn it. No soft dawn chip. No balance drift.
##   godot --headless --path . -s res://sim/check_need_tick.gd

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
	if not _check_spawn(catalog):
		failed = true
	if not _check_others(catalog):
		failed = true
	if not _check_clear(catalog):
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
		print("NEED TICK FAIL")
		quit(1)
		return
	print("NEED TICK OK")
	quit(0)


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _neighbor(game: Game) -> String:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != "neutral":
			continue
		if str(st.get("bunker", "")) != "" or bool(st.get("hidden", false)):
			continue
		if game.borders_player(str(sid)):
			return str(sid)
	return ""


func _silence(game: Game) -> void:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		Tick.clear_station(st)
		Dust.clear_station(st)
		if str(sid) == str(game.capital_id):
			continue
		st.known = false
		st.intel = 0
		st.hidden = false
		st.erase("visited")
		st.erase("joined")
		st.erase("captured")


func _arm_ready(game: Game, sid: String, sympathy: int) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = "neutral"
	st.known = true
	st.sympathy = sympathy
	st.intel = 1
	st.hidden = false
	st.deals = 0
	st.passage = false
	st.erase("joined")
	st.erase("captured")
	Tick.clear_station(st)
	for need in st.needs:
		need.fill = 0.4
	game.stock.influence = 40
	game.stock.food = 40
	game.stock.materials = 40
	game.stock.air = 40
	game.need_ticks = []


func _has_tick(st: Dictionary) -> bool:
	return str(st.get("need_tick_id", "")) != "" or int(st.get("need_tick_until_week", 0)) > 0


func _lowest(game: Game, st: Dictionary) -> String:
	return str(game._lowest_need(st))


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("need.tick") != "Still easing.":
		print("Strings: FAIL en tip ", Copy.t("need.tick"))
		return false
	if Copy.t("need.label") != "Easing":
		print("Strings: FAIL en label ", Copy.t("need.label"))
		return false
	if Copy.t("need.first") != "That need is still soft.":
		print("Strings: FAIL en first ", Copy.t("need.first"))
		return false
	if Copy.t("need.gone") != "The ease wore off.":
		print("Strings: FAIL en gone ", Copy.t("need.gone"))
		return false
	if Copy.t("need.reduce") != "Easing.":
		print("Strings: FAIL en reduce ", Copy.t("need.reduce"))
		return false
	Copy.set_lang("ru")
	if Copy.t("need.tick") != "Ещё смягчается.":
		print("Strings: FAIL ru tip ", Copy.t("need.tick"))
		return false
	if Copy.t("need.label") != "Смягчение":
		print("Strings: FAIL ru label ", Copy.t("need.label"))
		return false
	if Copy.t("need.first") != "Эта нужда ещё мягкая.":
		print("Strings: FAIL ru first ", Copy.t("need.first"))
		return false
	if Copy.t("need.gone") != "Облегчение сошло.":
		print("Strings: FAIL ru gone ", Copy.t("need.gone"))
		return false
	if Copy.t("need.reduce") != "Смягчение.":
		print("Strings: FAIL ru reduce ", Copy.t("need.reduce"))
		return false
	var ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/ru.json"))
	if typeof(ru) != TYPE_DICTIONARY:
		print("Strings: FAIL ru.json")
		return false
	var want := {
		"Still easing.": "Ещё смягчается.",
		"Easing": "Смягчение",
		"That need is still soft.": "Эта нужда ещё мягкая.",
		"The ease wore off.": "Облегчение сошло.",
		"Easing.": "Смягчение.",
	}
	for key in want:
		if str(ru.get(key, "")) != str(want[key]):
			print("Strings: FAIL ru.json ", key)
			return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_spawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Spawn: FAIL no neighbor")
		return false
	_silence(game)
	_arm_ready(game, sid, 20)
	var st: Dictionary = game.stations[sid]
	if st.needs.size() < 1:
		print("Spawn: FAIL no needs")
		return false
	var need_id := _lowest(game, st)
	var fills := {}
	for need in st.needs:
		fills[str(need.id)] = float(need.fill)
	if Tick.shows(game, sid) or Tick.note(game) != "" or _has_tick(st):
		print("Spawn: FAIL before envoy")
		return false
	var week := int(game.week)
	var held := int(game.stock.influence)
	if not game._order_envoy(sid):
		print("Spawn: FAIL order ", game._envoy_block(sid))
		return false
	if str(st.get("need_tick_id", "")) != need_id or int(st.get("need_tick_until_week", 0)) != week + 2:
		print("Spawn: FAIL ttl ", st.get("need_tick_id", ""), " ", st.get("need_tick_until_week", 0))
		return false
	if not Tick.shows(game, sid) or not Tick.shows_need(game, sid, need_id):
		print("Spawn: FAIL hidden")
		return false
	for need in st.needs:
		var id := str(need.id)
		if id == need_id:
			if not is_equal_approx(float(need.fill), clampf(float(fills[id]) + 0.2, 0.0, 1.0)):
				print("Spawn: FAIL bump ", id, " ", need.fill)
				return false
			continue
		if not is_equal_approx(float(need.fill), float(fills[id])):
			print("Spawn: FAIL other need moved ", id)
			return false
		if Tick.shows_need(game, sid, id):
			print("Spawn: FAIL tick on ", id)
			return false
	if int(game.stock.influence) != held - 3 or int(game.order_cost("envoy", sid).get("influence", 0)) != 3:
		print("Spawn: FAIL cost ", game.stock.influence)
		return false
	if not game.need_ticks.is_empty():
		print("Spawn: FAIL aid bar tick")
		return false
	var full := Tick.lines(game, sid, false)
	var compact := Tick.lines(game, sid, true)
	if full.size() != 2 or full[0] != "Easing" or full[1] != "Still easing.":
		print("Spawn: FAIL tip ", full)
		return false
	if compact.size() != 1 or compact[0] != "Easing.":
		print("Spawn: FAIL compact ", compact)
		return false
	if Tick.tip(false) != "Still easing." or Tick.caption(false) != "Easing":
		print("Spawn: FAIL row copy")
		return false
	if Tick.tip(true) != "Easing." or Tick.caption(true) != "Easing.":
		print("Spawn: FAIL row reduce")
		return false
	var blob := " ".join(full) + " " + Tick.tip(false) + " " + Tick.caption(false)
	if blob.find("+") >= 0 or blob.find("0.2") >= 0:
		print("Spawn: FAIL delta ", blob)
		return false
	st.known = false
	if Tick.shows(game, sid) or not _has_tick(st):
		print("Spawn: FAIL unknown should hide and keep ttl")
		return false
	st.known = true
	if not Tick.shows_need(game, sid, need_id):
		print("Spawn: FAIL known again")
		return false
	for need in st.needs:
		need.fill = 1.0
	Tick.clear_station(st)
	game.stock.influence = 40
	if not game._order_envoy(sid):
		print("Spawn: FAIL full order")
		return false
	if _has_tick(st) or Tick.shows(game, sid):
		print("Spawn: FAIL full need still ticked")
		return false
	print("Spawn: ok")
	return true


func _check_others(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Others: FAIL no neighbor")
		return false
	_silence(game)
	_arm_ready(game, sid, 10)
	var st: Dictionary = game.stations[sid]
	var need_id := _lowest(game, st)
	if not game._order_propaganda(sid):
		print("Others: FAIL propaganda ", game._propaganda_block(sid))
		return false
	if _has_tick(st) or Tick.shows(game, sid):
		print("Others: FAIL propaganda spawned")
		return false
	_arm_ready(game, sid, 69)
	if not game._order_propaganda(sid):
		print("Others: FAIL ready propaganda")
		return false
	if int(st.sympathy) < 70 or _has_tick(st) or Tick.shows(game, sid):
		print("Others: FAIL leaflet path spawned a tick ", st.sympathy)
		return false
	_arm_ready(game, sid, 40)
	var before := game._need_fill(st, need_id)
	if not game._order_deal(sid):
		print("Others: FAIL deal ", game._deal_block(sid))
		return false
	if int(st.deals) != 1 or _has_tick(st) or Tick.shows(game, sid):
		print("Others: FAIL deal spawned ", st.deals)
		return false
	if game._need_fill(st, need_id) <= before:
		print("Others: FAIL deal did not ease")
		return false
	_arm_ready(game, sid, 30)
	before = game._need_fill(st, need_id)
	if not game._order_aid(sid):
		print("Others: FAIL aid")
		return false
	if _has_tick(st) or Tick.shows(game, sid) or game._need_fill(st, need_id) <= before:
		print("Others: FAIL aid spawned or did not ease")
		return false
	_arm_ready(game, sid, 15)
	game._bump_need(st, need_id, 0.2)
	for need in st.needs:
		need.fill = clampf(float(need.fill) + 0.05, 0.0, 1.0)
	if _has_tick(st) or Tick.shows(game, sid):
		print("Others: FAIL drift spawned")
		return false
	_arm_ready(game, sid, 12)
	if not game._order_envoy(sid):
		print("Others: FAIL envoy")
		return false
	var kept_id := str(st.get("need_tick_id", ""))
	var kept_until := int(st.get("need_tick_until_week", 0))
	game.stock.influence = 40
	if not game._order_propaganda(sid) or not game._order_deal(sid):
		print("Others: FAIL follow-up")
		return false
	if str(st.get("need_tick_id", "")) != kept_id or int(st.get("need_tick_until_week", 0)) != kept_until:
		print("Others: FAIL follow-up retargeted the tick")
		return false
	if not Tick.shows_need(game, sid, kept_id):
		print("Others: FAIL follow-up cleared the tick")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var envoy := _body(src, "func _order_envoy(")
	var prop := _body(src, "func _order_propaganda(")
	var deal := _body(src, "func _order_deal(")
	var aid := _body(src, "func _order_aid(")
	var bump := _body(src, "func _bump_need(")
	if envoy.find("NeedTick.arm") < 0 or envoy.find("need_before") < 0:
		print("Others: FAIL envoy does not arm")
		return false
	if envoy.find("stock.influence = int(stock.influence) - 3") < 0:
		print("Others: FAIL envoy cost changed")
		return false
	for part in [prop, deal, aid, bump]:
		if part.find("NeedTick") >= 0 or part.find("need_tick") >= 0:
			print("Others: FAIL spawn outside envoy")
			return false
	var tick_src := FileAccess.get_file_as_string("res://sim/need_tick.gd")
	var arm := _body(tick_src, "static func arm(")
	if arm.find("need_tick_id") < 0 or arm.find("need_tick_until_week") < 0 or arm.find("TTL_WEEKS") < 0:
		print("Others: FAIL arm does not store ttl")
		return false
	if arm.find("after <= before") < 0:
		print("Others: FAIL arm ignores a flat need")
		return false
	var dawn := _body(src, "func _pick_dawn_soft_chip(")
	if dawn.find("need_tick") >= 0 or dawn.find("NeedTick") >= 0 or dawn.find("need.first") >= 0 or dawn.find("need.tick") >= 0:
		print("Others: FAIL dawn stack")
		return false
	print("Others: ok")
	return true


func _check_clear(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Clear: FAIL no neighbor")
		return false
	_silence(game)
	game.week = 5
	_arm_ready(game, sid, 20)
	if not game._order_envoy(sid):
		print("Clear: FAIL order")
		return false
	var st: Dictionary = game.stations[sid]
	var need_id := str(st.get("need_tick_id", ""))
	var until := int(st.get("need_tick_until_week", 0))
	if until != 7 or not Tick.shows_need(game, sid, need_id):
		print("Clear: FAIL missing tick ", until)
		return false
	game.week = until - 1
	if not Tick.shows_need(game, sid, need_id) or int(st.get("need_tick_until_week", 0)) != until:
		print("Clear: FAIL early week")
		return false
	game.week = until
	if Tick.shows(game, sid) or _has_tick(st):
		print("Clear: FAIL ttl ", game.week, " ", st.get("need_tick_until_week", 0))
		return false
	game.week = 5
	_arm_ready(game, sid, 20)
	if not game._order_envoy(sid):
		print("Clear: FAIL rearm")
		return false
	until = int(st.get("need_tick_until_week", 0))
	need_id = str(st.get("need_tick_id", ""))
	st.sympathy = 99
	game.stock.influence = 40
	if not game._order_envoy(sid):
		print("Clear: FAIL join order ", game._envoy_block(sid))
		return false
	if str(st.owner) != str(game.player) or Tick.shows(game, sid) or _has_tick(st):
		print("Clear: FAIL join kept tick ", st.owner, " ", st.get("need_tick_id", ""), " ", st.sympathy)
		return false
	game.week = 6
	_silence(game)
	_arm_ready(game, sid, 25)
	if not game._order_envoy(sid):
		print("Clear: FAIL flag arm")
		return false
	st.joined = true
	if Tick.shows(game, sid) or _has_tick(st):
		print("Clear: FAIL joined flag")
		return false
	_arm_ready(game, sid, 25)
	if not game._order_envoy(sid):
		print("Clear: FAIL capture arm")
		return false
	st.captured = true
	if Tick.shows(game, sid) or _has_tick(st):
		print("Clear: FAIL captured flag")
		return false
	_arm_ready(game, sid, 25)
	if not game._order_envoy(sid):
		print("Clear: FAIL owner arm")
		return false
	st.owner = str(game.player)
	if Tick.shows(game, sid) or _has_tick(st):
		print("Clear: FAIL owner")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var cap := _body(src, "func _capture(")
	if cap.find("NeedTick.clear_station") < 0:
		print("Clear: FAIL capture does not clear")
		return false
	var week_fn := _body(src, "func end_week(")
	var bumped := week_fn.find("week += 1")
	var settled := week_fn.find("NeedTick.settle_all")
	if bumped < 0 or settled < bumped:
		print("Clear: FAIL week settle order")
		return false
	print("Clear: ok")
	return true


func _check_float(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	_silence(game)
	_arm_ready(game, sid, 20)
	if Tick.note(game) != "" or bool(game.flags.get("seen_need_tick", false)):
		print("Float: FAIL empty fired")
		return false
	if not game._order_envoy(sid):
		print("Float: FAIL order")
		return false
	var line := Tick.note(game)
	if line != "That need is still soft." or not bool(game.flags.get("seen_need_tick", false)):
		print("Float: FAIL first ", line)
		return false
	if line.find("+") >= 0 or line.find("0.2") >= 0:
		print("Float: FAIL delta")
		return false
	if Tick.note(game) != "":
		print("Float: FAIL second")
		return false
	game.flags.erase("seen_need_tick")
	game.week = int(game.stations[sid].get("need_tick_until_week", 0))
	if Tick.note(game) != "" or bool(game.flags.get("seen_need_tick", false)):
		print("Float: FAIL expired fired")
		return false
	print("Float: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	_silence(game)
	_arm_ready(game, sid, 18)
	if not game._order_envoy(sid):
		print("Save: FAIL order")
		return false
	var st0: Dictionary = game.stations[sid]
	var until := int(st0.get("need_tick_until_week", 0))
	var need_id := str(st0.get("need_tick_id", ""))
	if Tick.note(game) != "That need is still soft.":
		print("Save: FAIL float")
		return false
	var data := game.export_state()
	var loaded := Game.new()
	loaded.setup(catalog, 4, 40)
	if not loaded.import_state(data):
		print("Save: FAIL import ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_need_tick", false)):
		print("Save: FAIL flag dropped")
		return false
	if Tick.note(loaded) != "":
		print("Save: FAIL float after load")
		return false
	var st: Dictionary = loaded.stations[sid]
	if str(st.get("need_tick_id", "")) != need_id or int(st.get("need_tick_until_week", 0)) != until:
		print("Save: FAIL ttl dropped ", st.get("need_tick_id", ""), " ", st.get("need_tick_until_week", 0))
		return false
	if not Tick.shows_need(loaded, sid, need_id):
		print("Save: FAIL tick after load")
		return false
	loaded.flags.erase("seen_need_tick")
	if Tick.note(loaded) != "That need is still soft.":
		print("Save: FAIL flag was not the latch")
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
		"sympathy": int(game.stations[_neighbor(game)].sympathy),
	}


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	_silence(game)
	_arm_ready(game, sid, 16)
	if not game._order_envoy(sid):
		print("Dawn: FAIL order")
		return false
	var until := int(game.stations[sid].get("need_tick_until_week", 0))
	var need_id := str(game.stations[sid].get("need_tick_id", ""))
	var before := _dawn_snapshot(game)
	var line := Tick.note(game)
	if line != "That need is still soft.":
		print("Dawn: FAIL float")
		return false
	var after := _dawn_snapshot(game)
	var flags_before: Dictionary = before.flags
	var flags_after: Dictionary = after.flags.duplicate(true)
	flags_after.erase("seen_need_tick")
	if flags_before != flags_after:
		print("Dawn: FAIL flags changed")
		return false
	if before.notices != after.notices or before.reports != after.reports:
		print("Dawn: FAIL queued a report")
		return false
	if str(after.chip.get("kind", "")) != str(before.chip.get("kind", "")):
		print("Dawn: FAIL chip kind ", before.chip, " ", after.chip)
		return false
	var kind := str(after.chip.get("kind", ""))
	if kind == "need" or kind.find("need") >= 0 or str(after.home) != str(before.home):
		print("Dawn: FAIL need chip ", after.chip, " ", after.home)
		return false
	if int(after.sympathy) != int(before.sympathy):
		print("Dawn: FAIL sympathy")
		return false
	if int(game.stations[sid].get("need_tick_until_week", 0)) != until or str(game.stations[sid].get("need_tick_id", "")) != need_id:
		print("Dawn: FAIL ttl moved")
		return false
	if bool(game.flags.get("rumor_dawn", false)) or bool(game.flags.get("border_dawn_new", false)):
		print("Dawn: FAIL higher chip armed")
		return false
	if bool(game.flags.get("rail_dawn", false)) or bool(game.flags.get("home_pending", false)) or bool(game.flags.get("heard_home", false)):
		print("Dawn: FAIL stack flag")
		return false
	print("Dawn: ok")
	return true


func _body(src: String, name: String) -> String:
	var at := src.find(name)
	if at < 0:
		return ""
	var body := src.substr(at)
	var next := body.find("\nfunc ")
	if next >= 0:
		body = body.substr(0, next)
	return body


func _check_draw() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _body(src, "func _draw_pin(")
	var warm := pin.find("_draw_warmth_ring")
	var border := pin.find("_draw_border_tick")
	var leaf := pin.find("_draw_leaflet_chip")
	var need := pin.find("_draw_need_tick")
	if warm < 0 or border < warm or leaf < border or need < leaf:
		print("Draw: FAIL order ", warm, " ", border, " ", leaf, " ", need)
		return false
	var ink := _body(src, "func _draw_ink(")
	var pins_at := ink.find("_draw_pins")
	var pips_at := ink.find("_draw_deal_pips")
	var flags_at := ink.find("_draw_flags")
	if pins_at < 0 or pips_at < pins_at or flags_at < pips_at:
		print("Draw: FAIL pips or flags")
		return false
	var chip := _body(src, "func _draw_need_tick(")
	if chip.find("NeedTick.slot") < 0 or chip.find("NeedTick.tick_points") < 0:
		print("Draw: FAIL slot")
		return false
	if chip.find("sin(") >= 0 or chip.find("_anim_t") >= 0 or chip.find("create_tween") >= 0 or chip.find("bounce") >= 0:
		print("Draw: FAIL pin motion")
		return false
	var paint := _body(src, "func _paint_ease_tick(")
	var box := _body(src, "func _ease_tick_box(")
	if paint.find("sin(") >= 0 or paint.find("create_tween") >= 0 or paint.find("_anim_t") >= 0:
		print("Draw: FAIL row motion")
		return false
	if box.find("NeedTick.tip") < 0 or box.find("NeedTick.caption") < 0 or box.find("+0.2") >= 0 or box.find("create_tween") >= 0:
		print("Draw: FAIL row copy")
		return false
	var bar := _body(src, "func _need_bar(")
	if bar.find("NeedTick.shows_need") < 0 or bar.find("_ease_tick_box") < 0:
		print("Draw: FAIL visit row")
		return false
	if Tick.bounces():
		print("Draw: FAIL bounces")
		return false
	var once := Tick.tick_points(Vector2.ZERO, 16.0)
	var again := Tick.tick_points(Vector2.ZERO, 16.0)
	if once.size() != 3 or once != again:
		print("Draw: FAIL points moved")
		return false
	var at := Vector2(40, 80)
	for pin_r in [10.08, 16.0]:
		var radius := float(pin_r)
		for crowded in [false, true]:
			var mark := Tick.slot(at, radius, crowded)
			var leaf_at := Dust.slot(at, radius, crowded)
			if mark.distance_to(leaf_at) < 14.0:
				print("Draw: FAIL leaflet overlap ", radius, " ", crowded, " ", mark, " ", leaf_at)
				return false
			for i in 3:
				var pip := Marks.pip_slot(at, radius, i)
				if mark.distance_to(pip) < 14.0:
					print("Draw: FAIL pip overlap ", radius, " ", crowded, " ", mark, " ", pip)
					return false
	var px := Tick.mark_px(16.0)
	if px < 6.0 or px > 8.0:
		print("Draw: FAIL size ", px)
		return false
	if src.find("need_lines(game, sid, _motion_off())") < 0 or src.find("note_need_tick") < 0:
		print("Draw: FAIL tip or float wiring")
		return false
	var visit := _body(src, "func _fill_visit(")
	if visit.find("_note_first_need") < 0:
		print("Draw: FAIL visit float")
		return false
	var sheet := _body(src, "func _fill_sheet(")
	var sheet_body := _body(src, "func _fill_sheet_body(")
	var refresh := _body(src, "func refresh(")
	if sheet.find("_note_first_need") >= 0 or sheet_body.find("_note_first_need") >= 0 or refresh.find("_note_first_need") >= 0:
		print("Draw: FAIL float off the visit")
		return false
	if refresh.find("open_visit") >= 0:
		print("Draw: FAIL auto-open")
		return false
	var note_fn := _body(src, "func _note_first_need(")
	if note_fn.find("present_dawn_soft_chip") >= 0 or note_fn.find("guide_layer") >= 0 or note_fn.find("open_visit") >= 0 or note_fn.find("ModalDeck") >= 0:
		print("Draw: FAIL dawn from float")
		return false
	if note_fn.find("NeedTick.shows") < 0:
		print("Draw: FAIL float without a tick")
		return false
	var float_fn := _body(src, "func _show_need_float(")
	if float_fn.find("_motion_off()") < 0 or float_fn.find("tween_interval") < 0:
		print("Draw: FAIL reduce-motion float")
		return false
	if src.find("need.gone") >= 0 or FileAccess.get_file_as_string("res://sim/need_tick.gd").find("need.gone") >= 0:
		print("Draw: FAIL clear toast")
		return false
	if FileAccess.get_file_as_string("res://sim/game.gd").find("need.gone") >= 0:
		print("Draw: FAIL gone in sim")
		return false
	print("Draw: ok")
	return true


func _check_balance() -> bool:
	var now := FileAccess.get_file_as_string("res://data/balance.json")
	if now != balance_text:
		print("Balance: FAIL file changed")
		return false
	if now.contains("seen_need_tick") or now.contains("need_tick") or now.contains("need.tick") or now.contains("need.first"):
		print("Balance: FAIL mentions need tick")
		return false
	var parsed = JSON.parse_string(now)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Balance: FAIL parse")
		return false
	if int(parsed.get("hope_drift", 0)) != -1 or float(parsed.get("sympathy_base", 0)) != 12.0:
		print("Balance: FAIL drift")
		return false
	if int(parsed.get("propaganda_influence", 0)) != 6 or int(parsed.get("join_hope", 1)) != 0 or int(parsed.get("join_discontent", 0)) != -3:
		print("Balance: FAIL join band")
		return false
	print("Balance: ok")
	return true
