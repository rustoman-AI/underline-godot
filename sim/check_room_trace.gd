extends SceneTree

## P95 Room Trace gate.
##   godot --headless --path . -s res://sim/check_room_trace.gd
## Glance only. No map mark. No soft dawn chip. No balance edit. Schema stays 21
## (seen_room_trace lives in flags). Careful seeds 1–60 match master, on and off.

const KEYS := [
	"trace.infirmary", "trace.quarters", "trace.radio.up", "trace.radio.blown",
	"trace.workshop", "trace.yard", "trace.first", "trace.tip",
]
const LATER := ["hydroponics", "air_filter", "generator", "meeting_hall", "platform", "listening_post"]
const SCRATCH := "user://check_room_trace"
## Careful loss on seeds 1–60, same line as the P90 gate on this master.
const BASELINE_LOST := 20
const MASTER_HASH := [
	530485220, 1440811691, 812324724, 1813219972, 325093522, 595908171, 2008396391, 1780671410, 856785781, 158007594,
	927219026, 88326475, 1637882681, 1666385348, 109892276, 1909826692, 17422148, 1248879695, 53792616, 1638580681,
	1667606982, 225933280, 1956210069, 664024800, 910860718, 1749011044, 317060065, 247917712, 1212469253, 1368249385,
	1040415204, 699411940, 240273769, 1927554047, 1435382424, 289105020, 1555551452, 991802799, 73486466, 389179272,
	1820378459, 1369693866, 479947888, 2022586468, 14678228, 2098321440, 788241386, 462862112, 1956553458, 372817444,
	1943912010, 743372996, 2101744492, 1885192366, 1640866844, 1363718713, 230067406, 1872288106, 522666115, 82470554,
]
const LOST_SEEDS := "1,8,11,12,13,14,23,27,28,30,33,35,39,40,41,45,51,52,56,57"

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var shots := OS.get_cmdline_user_args().has("--trace-shots")
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("TRACE FAIL catalog")
		quit(1)
		return
	var balance_text := FileAccess.get_file_as_string("res://data/balance.json")
	if not _check_strings():
		_failed = true
	if not _check_bounds():
		_failed = true
	if not _check_lines(catalog):
		_failed = true
	if not _check_save(catalog):
		_failed = true
	if not await _check_ui(catalog, shots):
		_failed = true
	if not await _check_fresh_plates(shots):
		_failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_text:
		_bad("balance.json changed")
	if shots:
		if _failed:
			print("TRACE FAIL")
			quit(1)
		else:
			print("TRACE SHOTS OK")
			quit(0)
		return
	if _failed:
		print("TRACE FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("TRACE FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_text:
		print("TRACE FAIL balance")
		quit(1)
		return
	print("TRACE OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("Trace: FAIL " + msg)


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/room_trace.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P95":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 8:
		_bad("pack key count %d" % rows.size())
		return false
	if rows.has("trace.radio.down"):
		_bad("trace.radio.down must stay omitted")
		return false
	for key in KEYS:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		if not str(key).begins_with("trace."):
			_bad("namespace " + key)
			return false
	for key in rows:
		if not str(key).begins_with("trace."):
			_bad("extra key " + str(key))
			return false
	var fragment = JSON.parse_string(FileAccess.get_file_as_string("res://data/room_trace_ru_fragment.json"))
	if not (fragment is Dictionary):
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
	if Copy.fill("trace.infirmary", {"n": 2}) != "2 on the cots.":
		_bad("en cots fill")
		return false
	if Copy.fill("trace.yard", {"n": 3}) != "3 piles still in the yard.":
		_bad("en yard fill")
		return false
	if Copy.t("trace.first") != "The rooms say how they are.":
		_bad("en first")
		return false
	if Copy.t("trace.tip") != "Built rooms tell you how the week left them.":
		_bad("en tip")
		return false
	if Copy.t("trace.radio.down") != "trace.radio.down":
		_bad("down key resolved")
		return false
	Copy.set_lang("ru")
	if Copy.fill("trace.infirmary", {"n": 2}) != "На койках: 2.":
		_bad("ru cots " + Copy.fill("trace.infirmary", {"n": 2}))
		return false
	if Copy.fill("trace.quarters", {"n": 1}) != "В гостевых нарах: 1.":
		_bad("ru quarters")
		return false
	if Copy.fill("trace.yard", {"n": 3}) != "Во дворе ещё куч: 3.":
		_bad("ru yard " + Copy.fill("trace.yard", {"n": 3}))
		return false
	if Copy.t("trace.radio.up") != "Пост слушает." or Copy.t("trace.radio.blown") != "Пост затих.":
		_bad("ru radio")
		return false
	if Copy.t("trace.workshop") != "На верстаке ждёт утиль.":
		_bad("ru workshop")
		return false
	if Copy.t("trace.first") != "Комнаты сами говорят, как они.":
		_bad("ru first")
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_bounds() -> bool:
	if Game.SAVE_SCHEMA != 27:
		_bad("schema is %s, want 27 (room trace stays in flags; schema 26 is not taken)" % str(Game.SAVE_SCHEMA))
		return false
	if RoomTrace.map_mark() or RoomTrace.dawn_chip() or RoomTrace.joins_soft_dawn():
		_bad("mark or dawn helper")
		return false
	var src := FileAccess.get_file_as_string("res://sim/room_trace.gd")
	if src.find("rand") >= 0 or src.find("balance") >= 0 or src.find("ledger") >= 0:
		_bad("reader rolls, reads balance, or reads the ledger")
		return false
	if src.find("hope") >= 0 or src.find("stock") >= 0:
		_bad("reader touches hope or stock")
		return false
	var game_src := FileAccess.get_file_as_string("res://sim/game.gd")
	if game_src.find("const SAVE_SCHEMA := 27") < 0 or game_src.find("V21_ADDED") < 0 or game_src.find("V22_ADDED") < 0 or game_src.find("V23_ADDED") < 0 or game_src.find("V24_ADDED") < 0:
		_bad("schema source")
		return false
	if game_src.find("const SAVE_SCHEMA := 21") >= 0 or game_src.find("const SAVE_SCHEMA := 26") >= 0:
		_bad("schema moved off 25")
		return false
	if game_src.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") < 0:
		_bad("soft dawn stack moved")
		return false
	if game_src.find("seen_room_trace") >= 0:
		_bad("game.gd grew a seen_room_trace field")
		return false
	var net := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if net.find("room_trace") >= 0 or net.find("trace.yard") >= 0 or net.find("seen_room_trace") >= 0:
		_bad("map view gained a trace")
		return false
	print("Bounds: schema 25, dawn none, map none")
	print("Trace fields: " + ", ".join(RoomTrace.fields_read()))
	return true


func _check_lines(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	if game.has_method("guest_seats_occupied"):
		_bad("P83 guest_seats_occupied is present; this draft must not import it")
		return false
	if RoomTrace.guest_occupied(game) != 0:
		_bad("guest count invented")
		return false
	var cell := _open_cell(game)
	if cell.x < 0:
		_bad("no open cell")
		return false
	game._place_room("infirmary", cell.x, cell.y)
	if RoomTrace.line_for(game, "infirmary") != "":
		_bad("empty infirmary printed " + RoomTrace.line_for(game, "infirmary"))
		return false
	if RoomTrace.cot_count(game) != 0:
		_bad("cots %d" % RoomTrace.cot_count(game))
		return false
	var sick_id := ""
	var hurt_id := ""
	for person in game.residents:
		if sick_id == "":
			sick_id = str(person.id)
			person.sick = 2
			continue
		if hurt_id == "":
			hurt_id = str(person.id)
			person.absent = 2
			person.story_events = [{"pool": "injured", "week": game.week}]
			break
	if RoomTrace.cot_count(game) != 2 or RoomTrace.line_for(game, "infirmary") != "2 on the cots.":
		_bad("cots line %s count %d" % [RoomTrace.line_for(game, "infirmary"), RoomTrace.cot_count(game)])
		return false
	if RoomTrace.line_for(game, "infirmary").contains("0"):
		_bad("zero filler")
		return false
	game.people[hurt_id].absent = 0
	game.people[sick_id].sick = 0
	if RoomTrace.line_for(game, "infirmary") != "":
		_bad("cleared cots still showing")
		return false
	## A governor who is away is not on a cot, even with an old injury note.
	game.people[hurt_id].absent = 2
	game.people[hurt_id].story_events = [{"pool": "injured", "week": game.week}]
	game.stations[game.capital_id].governor = hurt_id
	if RoomTrace.cot_count(game) != 0:
		_bad("governor counted as a cot")
		return false
	game.stations[game.capital_id].governor = ""
	game.people[hurt_id].absent = 0
	if _uid(game, "quarters") == "":
		_place(game, "quarters")
	if RoomTrace.key_for(game, "quarters") != "" or RoomTrace.line_for(game, "quarters") != "":
		_bad("P83 off still showed quarters")
		return false
	for later in LATER:
		if later != "listening_post" and _uid(game, later) == "":
			_place(game, later)
		if RoomTrace.line_for(game, later) != "":
			_bad("FLAG-later " + later)
			return false
	if RoomTrace.line_for(game, "radio") != "":
		_bad("radio without a post")
		return false
	if _place(game, "radio") == "" or _place(game, "listening_post") == "":
		_bad("could not place radio")
		return false
	if RoomTrace.radio_key(game) != "" or RoomTrace.line_for(game, "radio") != "":
		_bad("unstaffed post showed " + RoomTrace.radio_key(game))
		return false
	var post = game._listening_room()
	_staff(game, post)
	if not game.listening_active() or RoomTrace.line_for(game, "radio") != "The post is listening.":
		_bad("up line " + RoomTrace.line_for(game, "radio"))
		return false
	if RoomTrace.line_for(game, "listening_post") != "":
		_bad("listening room grew its own trace")
		return false
	post.switched_off = true
	if RoomTrace.radio_key(game) != "":
		_bad("switched off showed " + RoomTrace.radio_key(game))
		return false
	post.switched_off = false
	post.disabled = 1
	if RoomTrace.radio_key(game) != "":
		_bad("disabled without a blow showed " + RoomTrace.radio_key(game))
		return false
	game.chronicle.append({"week": game.week, "kind": "listening_blown", "weight": 2, "fields": {"station": "Jay"}})
	if RoomTrace.line_for(game, "radio") != "The post went quiet.":
		_bad("blown line " + RoomTrace.line_for(game, "radio"))
		return false
	post.disabled = 0
	if RoomTrace.radio_key(game) != "trace.radio.up" or RoomTrace.line_for(game, "radio") != "The post is listening.":
		_bad("recovered post " + RoomTrace.line_for(game, "radio"))
		return false
	if _place(game, "workshop") == "":
		_bad("no workshop")
		return false
	if RoomTrace.line_for(game, "workshop") != "Salvage is waiting on the bench.":
		_bad("workshop line " + RoomTrace.line_for(game, "workshop"))
		return false
	for room in game.rooms:
		room.upgrade = 3
	if RoomTrace.salvage_listed(game) or RoomTrace.line_for(game, "workshop") != "":
		_bad("fitted board still listed")
		return false
	if RoomTrace.yard_line(game) != "":
		_bad("empty yard " + RoomTrace.yard_line(game))
		return false
	var piled := 0
	for kind in ["rubble", "scrap", "coal"]:
		if _make_pile(game, kind).x < 0:
			break
		piled += 1
	if piled != 3 or RoomTrace.yard_count(game) != 3 or RoomTrace.yard_line(game) != "3 piles still in the yard.":
		_bad("yard %d %s" % [RoomTrace.yard_count(game), RoomTrace.yard_line(game)])
		return false
	if RoomTrace.line_for(game, "yard") != "":
		_bad("yard became a room line")
		return false
	if not RoomTrace.shows_any(game):
		_bad("shows_any")
		return false
	var first := RoomTrace.claim_first(game)
	if first != "The rooms say how they are." or not bool(game.flags.get("seen_room_trace", false)):
		_bad("first float " + first)
		return false
	if RoomTrace.claim_first(game) != "":
		_bad("first float repeated")
		return false
	if game.room_trace_dawn_chip() or game.dawn_soft_stack() != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn chip joined")
		return false
	print("Lines: ok (P83 dormant, quarters hidden)")
	return true


func _check_save(catalog: Catalog) -> bool:
	if Game.SAVE_SCHEMA != 27:
		_bad("export schema")
		return false
	var game := _fresh(catalog)
	game.sdays["kept"] = {"plaza": 4}
	game.carry["delivered"] = 3
	game.echoes = {"plaza": {"kind": "deal", "week": 2}}
	game.rival_log = {"exchange": {"kind": "bought", "week": 3, "target": "trampark"}}
	game.callers.here = "exchange"
	game.callers.why = "warm"
	game.week = 12
	game.scars = {"a|b": {"kind": "raid", "count": 1, "week": 4}}
	game.flags["seen_room_trace"] = true
	var full := game.export_state()
	full["schema"] = 25
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(full):
		_bad("schema 25 " + again.load_error)
		return false
	if not _kept_chain(again, true) or not bool(again.flags.get("seen_room_trace", false)):
		_bad("schema 25 dropped a field or the flag")
		return false
	full.flags.erase("seen_room_trace")
	var bare := Game.new()
	bare.catalog = catalog
	if not bare.import_state(full) or bool(bare.flags.get("seen_room_trace", false)):
		_bad("schema 25 missing flag")
		return false
	for ver in [20, 21, 22, 23, 24]:
		var mixed := game.export_state()
		mixed["schema"] = ver
		var mid := Game.new()
		mid.catalog = catalog
		if not mid.import_state(mixed):
			_bad("schema %d present %s" % [ver, mid.load_error])
			return false
		if not _kept_chain(mid, true) or not bool(mid.flags.get("seen_room_trace", false)):
			_bad("schema %d dropped a present field or the flag" % ver)
			return false
	var days_only := game.export_state()
	for key in ["carry", "echoes", "rival_log", "callers", "scars"]:
		days_only.erase(key)
	days_only["schema"] = 20
	var v20 := Game.new()
	v20.catalog = catalog
	if not v20.import_state(days_only):
		_bad("schema 20 " + v20.load_error)
		return false
	if int(v20.sdays.kept.get("plaza", 0)) != 4 or int(v20.carry.delivered) != 0 or not v20.echoes.is_empty() or not v20.rival_log.is_empty() or str(v20.callers.get("here", "")) != "" or not v20.scars.is_empty():
		_bad("schema 20 did not keep sdays and default the rest")
		return false
	var no_scars := game.export_state()
	no_scars.erase("scars")
	no_scars["schema"] = 24
	var old24 := Game.new()
	old24.catalog = catalog
	if not old24.import_state(no_scars) or not old24.scars.is_empty() or str(old24.callers.get("here", "")) != "exchange":
		_bad("schema 24 default scars")
		return false
	no_scars["schema"] = 25
	var refused := Game.new()
	refused.catalog = catalog
	if refused.import_state(no_scars):
		_bad("schema 25 accepted missing scars")
		return false
	var no_carry := game.export_state()
	no_carry.erase("carry")
	no_carry["schema"] = 21
	var dropped := Game.new()
	dropped.catalog = catalog
	if dropped.import_state(no_carry):
		_bad("schema 21 accepted missing carry")
		return false
	var future := game.export_state()
	future["schema"] = 26
	var too_new := Game.new()
	too_new.catalog = catalog
	if too_new.import_state(future):
		_bad("schema 26 accepted")
		return false
	print("Save: ok (schema 25 round-trip, 20-24 keep present fields, 26 rejected)")
	return true


func _kept_chain(game: Game, with_scars: bool) -> bool:
	if int(game.sdays.kept.get("plaza", 0)) != 4 or int(game.carry.delivered) != 3:
		return false
	if str(game.echoes.get("plaza", {}).get("kind", "")) != "deal":
		return false
	if str(game.rival_log.get("exchange", {}).get("kind", "")) != "bought":
		return false
	if str(game.callers.get("here", "")) != "exchange":
		return false
	if with_scars and str(game.scars.get("a|b", {}).get("kind", "")) != "raid":
		return false
	return true


func _check_ui(catalog: Catalog, shots: bool) -> bool:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 6:
		await process_frame
	if st.dim != null and st.dim.visible:
		st._close_card()
		await process_frame
	if st.game == null or st.yard == null:
		_bad("station did not boot")
		if is_instance_valid(st):
			st.free()
		return false
	var game = st.game
	var infirmary := _place(game, "infirmary")
	var quarters := _place(game, "quarters")
	var radio := _place(game, "radio")
	var _post := _place(game, "listening_post")
	var workshop := _place(game, "workshop")
	var hydro := _place(game, "hydroponics")
	if infirmary == "" or quarters == "" or radio == "" or workshop == "" or hydro == "":
		_bad("could not place rooms")
		st.free()
		return false
	for person in game.residents:
		person.sick = 0
		person.absent = 0
	Copy.set_lang("en")
	st._load_fonts()
	await _show(st, infirmary)
	if _traces(st.card_body).size() != 0:
		_bad("RT-U2 empty infirmary drew a line")
		st.free()
		return false
	_mark_sick(game, 2)
	await _show(st, infirmary)
	if not await _card_case(st, "en", Vector2i(1536, 864), "infirmary", "2 on the cots.", true):
		st.free()
		return false
	if st.trace_float == null or not st.trace_float.visible or st.trace_float_label.text != "The rooms say how they are.":
		_bad("RT-U7 float missing")
		st.free()
		return false
	if not bool(game.flags.get("seen_room_trace", false)):
		_bad("RT-U7 flag")
		st.free()
		return false
	if str(st.trace_float.get_meta("trace_yard_float", "")) != "true" and not bool(st.trace_float.get_meta("trace_yard_float", false)):
		_bad("RT-U7 float is not on the YA1 plate")
		st.free()
		return false
	var outline := int(st.trace_float_label.get_theme_constant("outline_size"))
	if outline != 0:
		_bad("float outline %d" % outline)
		st.free()
		return false
	var plate_size: Vector2 = st.trace_float.size
	if plate_size.x < 300.0 or plate_size.y < 28.0 or plate_size.y > 80.0 or plate_size.x < plate_size.y * 2.0:
		_bad("RT-U7 slab %s" % plate_size)
		st.free()
		return false
	st.trace_float.visible = false
	await _show(st, infirmary)
	if st.trace_float.visible:
		_bad("RT-U7 float repeated")
		st.free()
		return false
	await _show(st, quarters)
	if _traces(st.card_body).size() != 0:
		_bad("RT-U3 quarters line with P83 off")
		st.free()
		return false
	await _show(st, hydro)
	if _traces(st.card_body).size() != 0:
		_bad("RT-U3 hydroponics line")
		st.free()
		return false
	var post = game._listening_room()
	await _show(st, str(post.uid))
	if _traces(st.card_body).size() != 0:
		_bad("RT-N3 listening card grew a trace")
		st.free()
		return false
	_staff(game, post)
	await _show(st, radio)
	if not await _card_case(st, "en", Vector2i(1536, 864), "radio", "The post is listening.", false):
		st.free()
		return false
	post.disabled = 1
	game.chronicle.append({"week": game.week, "kind": "listening_blown", "weight": 2, "fields": {}})
	await _show(st, radio)
	var blown := _traces(st.card_body)
	if blown.size() != 1 or str(blown[0].text) != "The post went quiet.":
		_bad("RT-U radio blown ui")
		st.free()
		return false
	post.disabled = 0
	post.staff.clear()
	for person in game.residents:
		if str(person.get("post", "")) == str(post.uid):
			person.erase("post")
	await _show(st, radio)
	if _traces(st.card_body).size() != 0:
		_bad("RT-N5 down/unstaffed drew a line")
		st.free()
		return false
	for room in game.rooms:
		if str(room.type) == "workshop":
			room.upgrade = 0
	await _show(st, workshop)
	if not await _card_case(st, "en", Vector2i(1536, 864), "workshop", "Salvage is waiting on the bench.", false):
		st.free()
		return false
	if not await _reachable(st, "en workshop"):
		st.free()
		return false
	Copy.set_lang("ru")
	st._load_fonts()
	_mark_sick(game, 2)
	game.flags.erase("seen_room_trace")
	await _show(st, infirmary)
	if not await _card_case(st, "ru", Vector2i(1536, 864), "infirmary", "На койках: 2.", true):
		st.free()
		return false
	if st.trace_float == null or st.trace_float_label.text != "Комнаты сами говорят, как они.":
		_bad("RU float")
		st.free()
		return false
	await _show(st, workshop)
	if not await _card_case(st, "ru", Vector2i(1536, 864), "workshop", "На верстаке ждёт утиль.", false):
		st.free()
		return false
	if not await _reachable(st, "ru workshop"):
		st.free()
		return false
	st._close_card()
	await process_frame
	for key in game.cells:
		game.cells[key].erase("pile")
	for _i in 3:
		await process_frame
	if st.yard_trace.visible:
		_bad("RT-U2 empty yard strip")
		st.free()
		return false
	var anchor := _make_pile(game, "rubble")
	if anchor.x < 0 or _make_pile(game, "coal").x < 0:
		_bad("could not place yard piles")
		st.free()
		return false
	Copy.set_lang("en")
	st._load_fonts()
	st.yard._zoom_to(anchor.x, anchor.y)
	for _i in 4:
		await process_frame
	if not await _yard_case(st, "en", "2 piles still in the yard."):
		st.free()
		return false
	Copy.set_lang("ru")
	st._load_fonts()
	for _i in 3:
		await process_frame
	if not await _yard_case(st, "ru", "Во дворе ещё куч: 2."):
		st.free()
		return false
	if shots:
		await _shots(st, infirmary, anchor)
	st._close_card()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	st.free()
	print("UI: ok")
	return true


## Fresh station each pass. First show used to keep a one-glyph column (420×588 / 661).
## Second show on the same node must stay a short plate too. Other yard notices are up
## at the same time so the stack cannot cover them.
func _check_fresh_plates(shots: bool) -> bool:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	var views: Array = [
		[Vector2i(1920, 1080), "100"],
		[Vector2i(1536, 864), "125"],
	]
	for pass_i in 3:
		for spec in views:
			var win_size: Vector2i = spec[0]
			var tag: String = str(spec[1])
			for lang in ["en", "ru"]:
				var st = await _boot_station()
				if st == null or st.game == null:
					_bad("fresh station")
					return false
				await _resize(st, win_size)
				Copy.set_lang(str(lang))
				st._load_fonts()
				if st.dim != null and st.dim.visible:
					st._close_card()
					await process_frame
				var where := "%s %s run%d" % [tag, lang, pass_i + 1]
				_show_notice_order(st, false)
				for _i in 3:
					await process_frame
				if not _notice_stack(st, where):
					st.free()
					return false
				for key in ["regular", "sday", "carry", "echo", "rival", "caller", "scar", "trace"]:
					var plate := st.get(str(key) + "_float") as PanelContainer
					if plate != null:
						plate.visible = false
				_show_notice_order(st, false)
				for _i in 2:
					await process_frame
				if not _notice_stack(st, where + " again"):
					st.free()
					return false
				if shots and pass_i == 0:
					await _grab(st, "trace_%s_%s_stack" % [lang, tag])
				st.free()
				await process_frame
				var rev = await _boot_station()
				if rev == null:
					_bad("reverse station")
					return false
				await _resize(rev, win_size)
				Copy.set_lang(str(lang))
				rev._load_fonts()
				if rev.dim != null and rev.dim.visible:
					rev._close_card()
					await process_frame
				_show_notice_order(rev, true)
				for _i in 3:
					await process_frame
				if not _notice_stack(rev, where + " reverse"):
					rev.free()
					return false
				rev.free()
				await process_frame
	print("Fresh plates: ok")
	return true


func _boot_station():
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 5:
		await process_frame
	return st


func _show_notice_order(st, reverse: bool) -> void:
	var steps: Array = [
		["_show_regular_yard", "regular.first"],
		["_show_sday_yard", "sday.first"],
		["_show_carry_yard", "carry.first"],
		["_show_echo_yard", "echo.first"],
		["_show_rival_yard", "rival.first"],
		["_show_caller_yard", "caller.first"],
		["_show_scar_yard", "scar.first"],
		["_show_trace_float", "trace.first"],
	]
	if reverse:
		steps.reverse()
	for step in steps:
		st.call(str(step[0]), Copy.t(str(step[1])))


func _notice_stack(st, tag: String) -> bool:
	var keys := ["regular", "sday", "carry", "echo", "rival", "caller", "scar", "trace"]
	var prev := Rect2()
	var have_prev := false
	var view := Rect2(Vector2.ZERO, st.get_viewport_rect().size)
	for key in keys:
		var plate := st.get(str(key) + "_float") as PanelContainer
		var lab := st.get(str(key) + "_float_label") as Label
		if plate == null or lab == null or not plate.visible:
			_bad("%s %s missing" % [tag, key])
			return false
		var sz: Vector2 = plate.size
		var cap := 80.0 if str(key) == "trace" else 140.0
		if sz.x < 300.0 or sz.x > 520.0 or sz.y < 28.0 or sz.y > cap or sz.x < sz.y * 2.0:
			_bad("%s %s slab %s" % [tag, key, sz])
			return false
		var lines := lab.get_line_count()
		var line_cap := 1 if str(key) == "trace" else 3
		if lines < 1 or lines > line_cap:
			_bad("%s %s lines %d [%s]" % [tag, key, lines, lab.text])
			return false
		var rect: Rect2 = plate.get_global_rect()
		if not view.grow(4.0).encloses(rect):
			_bad("%s %s off %s view %s" % [tag, key, rect, view])
			return false
		if have_prev and (rect.intersects(prev) or rect.position.y < prev.end.y - 1.0):
			_bad("%s overlap %s then %s" % [tag, prev, rect])
			return false
		prev = rect
		have_prev = true
	return true


func _card_case(st, lang: String, sz: Vector2i, room_type: String, text: String, grew: bool) -> bool:
	await _resize(st, sz)
	var rows := _traces(st.card_body)
	if rows.size() != 1:
		_bad("RT-U1 %s %s lines %d" % [lang, room_type, rows.size()])
		return false
	var lab: Label = rows[0]
	if str(lab.get_meta("room_trace", "")) != room_type or str(lab.text) != text:
		_bad("RT-U6 %s %s text %s" % [lang, room_type, lab.text])
		return false
	if lab.focus_mode != Control.FOCUS_NONE:
		_bad("trace is focusable")
		return false
	if lab.clip_text or int(lab.get_theme_font_size("font_size")) != 15:
		_bad("RT-U8 clip or font %s" % lang)
		return false
	if lab.get_line_count() != 1:
		_bad("RT-U8 %s %s lines %d" % [lang, room_type, lab.get_line_count()])
		return false
	var box := lab.size
	if box.x < 8.0 or box.y < 8.0:
		box = lab.get_combined_minimum_size()
	if box.y >= box.x or lab.get_line_count() >= mini(lab.text.length(), 8):
		_bad("RT-U8 letter stack %s %s" % [lang, box])
		return false
	if lab.tooltip_text != RoomTrace.tip():
		_bad("tip %s" % lab.tooltip_text)
		return false
	var title := st.card_body.get_child(0) as Control
	var title_box := title.get_global_rect()
	var line_box := lab.get_global_rect()
	if title_box.intersects(line_box):
		_bad("RT-U8 overlap %s %s" % [title_box, line_box])
		return false
	if line_box.position.y + 1.0 < title_box.end.y:
		_bad("trace is not under the name")
		return false
	var vp := Rect2(Vector2.ZERO, Vector2(sz))
	if not vp.grow(2.0).encloses(line_box):
		_bad("RT-U8 line off screen %s" % line_box)
		return false
	if grew:
		await _settle(st)
		var tall: float = st.card.offset_bottom - st.card.offset_top
		var body_tall: float = st.card_body.size.y
		lab.visible = false
		await process_frame
		await process_frame
		st._fit_card()
		await _settle(st)
		var short: float = st.card.offset_bottom - st.card.offset_top
		var body_short: float = st.card_body.size.y
		lab.visible = true
		await process_frame
		st._fit_card()
		await _settle(st)
		if tall <= short + 1.0 and body_tall <= body_short + 1.0:
			_bad("RT-U8 card did not grow %s tall %.1f short %.1f body %.1f/%.1f" % [lang, tall, short, body_tall, body_short])
			return false
	return true


func _reachable(st, where: String) -> bool:
	var vp := Rect2(Vector2.ZERO, st.size)
	st.card_scroll.scroll_vertical = 0
	await _settle(st)
	var close := _button_text(st.card_body, Copy.t("Close"))
	if close == null or not _inside(close, vp):
		_bad("Close off screen " + where)
		return false
	for word in [Copy.t("Demolish"), Copy.t("salvage.strip")]:
		var button := _button_text(st.card_body, word)
		if button == null:
			_bad("missing %s on %s" % [word, where])
			return false
		if not await _scroll_into(st, button, vp):
			_bad("action off screen %s %s rect %s" % [where, word, button.get_global_rect()])
			return false
	st.card_scroll.scroll_vertical = 0
	await process_frame
	if not _inside(close, vp):
		_bad("Close not reachable after scroll " + where)
		return false
	return true


func _scroll_into(st, button: Button, vp: Rect2) -> bool:
	if _inside(button, vp):
		return true
	var scroll: ScrollContainer = st.card_scroll
	var view := scroll.get_global_rect()
	var rect := button.get_global_rect()
	var delta := rect.position.y - (view.position.y + 12.0)
	scroll.scroll_vertical = maxi(0, int(float(scroll.scroll_vertical) + delta))
	await process_frame
	await process_frame
	return _inside(button, vp)


func _inside(ctrl: Control, vp: Rect2) -> bool:
	var rect := ctrl.get_global_rect()
	return rect.size.y > 8.0 and rect.size.x > 8.0 and vp.grow(8.0).encloses(rect)


func _yard_case(st, lang: String, text: String) -> bool:
	await _resize(st, Vector2i(1536, 864))
	if st.dim != null and st.dim.visible:
		_bad("yard opened a card " + lang)
		return false
	if st.yard_trace == null or not st.yard_trace.visible:
		_bad("yard strip hidden " + lang)
		return false
	if st.yard_trace.get_parent() == st.card_body:
		_bad("yard strip is on a card")
		return false
	var lab: Label = st.yard_trace_label
	if lab.text != text or lab.clip_text or lab.get_line_count() != 1:
		_bad("yard text %s lines %d '%s'" % [lang, lab.get_line_count(), lab.text])
		return false
	if int(lab.get_theme_font_size("font_size")) != 14:
		_bad("yard font")
		return false
	var box: Rect2 = st.yard_trace.get_global_rect()
	if box.size.y >= box.size.x:
		_bad("yard letter stack %s" % box)
		return false
	var vp := Rect2(Vector2.ZERO, st.size)
	if not vp.grow(2.0).encloses(box):
		_bad("yard strip off screen %s %s" % [lang, box])
		return false
	var tip: String = str(st.yard._get_tooltip(st.yard.trace_rect.get_center()))
	if tip != RoomTrace.tip():
		_bad("yard tip " + tip)
		return false
	for child in st.yard_trace.find_children("*", "Button", true, false):
		_bad("yard strip has a button")
		return false
	return true


func _shots(st, infirmary: String, anchor: Vector2i) -> void:
	var game = st.game
	Copy.set_lang("en")
	st._load_fonts()
	for key in game.cells:
		game.cells[key].erase("pile")
	for person in game.residents:
		person.sick = 0
		person.absent = 0
	game.flags.erase("seen_room_trace")
	if st.trace_float != null:
		st.trace_float.visible = false
	await _resize(st, Vector2i(1536, 864))
	await _show(st, infirmary)
	await _grab(st, "trace_en_125_room_before")
	_mark_sick(game, 3)
	await _show(st, infirmary)
	await _grab(st, "trace_en_125_room_after")
	st._close_card()
	await process_frame
	st.yard._zoom_to(anchor.x, anchor.y)
	for _i in 3:
		await process_frame
	await _grab(st, "trace_en_125_yard_before")
	_make_pile(game, "rubble")
	_make_pile(game, "scrap")
	for _i in 4:
		await process_frame
	await _grab(st, "trace_en_125_yard_after")
	Copy.set_lang("ru")
	st._load_fonts()
	for key in game.cells:
		game.cells[key].erase("pile")
	for person in game.residents:
		person.sick = 0
	game.flags.erase("seen_room_trace")
	if st.trace_float != null:
		st.trace_float.visible = false
	await _show(st, infirmary)
	await _grab(st, "trace_ru_125_room_before")
	_mark_sick(game, 3)
	await _show(st, infirmary)
	await _grab(st, "trace_ru_125_room_after")
	st._close_card()
	for _i in 2:
		await process_frame
	await _grab(st, "trace_ru_125_yard_before")
	_make_pile(game, "rubble")
	_make_pile(game, "coal")
	for _i in 4:
		await process_frame
	await _grab(st, "trace_ru_125_yard_after")


func _grab(st, shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = st.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/%s.png" % shot_name
	var err: Error = img.save_png(path)
	print("SHOT %s %dx%d err %s" % [shot_name, img.get_width(), img.get_height(), err])


func _resize(st, sz: Vector2i) -> void:
	var win: Window = st.get_window()
	if win != null:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_factor = 1.0
		win.size = sz
	root.size = Vector2(sz)
	st.set_anchors_preset(Control.PRESET_TOP_LEFT)
	st.position = Vector2.ZERO
	st.size = Vector2(sz)
	await process_frame
	if st.has_method("_layout"):
		st._layout()
	if st.dim != null and st.dim.visible:
		st._fit_card()
	await _settle(st)


func _show(st, uid: String) -> void:
	st._show_room(uid)
	await _settle(st)


func _settle(st) -> void:
	for _i in 8:
		await process_frame
		if st.card_fit_queued:
			continue
		await process_frame
		if not st.card_fit_queued:
			return


func _traces(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	for lab in node.find_children("*", "Label", true, false):
		if str(lab.get_meta("room_trace", "")) != "":
			out.append(lab)
	return out


func _button_text(node: Node, text: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if str(button.text) == text and button.visible:
			return button
	return null


func _mark_sick(game, n: int) -> void:
	var left := n
	for person in game.residents:
		person.sick = 0
		if left <= 0:
			continue
		person.sick = 2
		left -= 1


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		var on := _play(catalog, run_seed, true)
		var off := _play(catalog, run_seed, false)
		if str(on.summary) != str(off.summary) or str(on.rng) != str(off.rng) or str(on.snap) != str(off.snap):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		if bool(on.flag) or bool(off.flag):
			_bad("seed %d careful set seen_room_trace" % run_seed)
			return false
		var got := int(on.hash)
		var want := int(MASTER_HASH[run_seed - 1])
		if got == want:
			matched += 1
		else:
			_bad("seed %d hash %d master %d" % [run_seed, got, want])
		if str(on.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		if run_seed % 10 == 0:
			print("Seed %d: %d %s" % [run_seed, got, "match" if got == want else "DIFF"])
	print("Careful loss: %d/60 (master %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master, on/off identical" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss moved")
		return false
	return matched == 60 and not _failed


func _play(catalog: Catalog, run_seed: int, on: bool) -> Dictionary:
	RoomTrace.enabled = on
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		bot._act(game)
		game.end_week()
		if on:
			RoomTrace.yard_line(game)
			for room_type in RoomTrace.ROOMS:
				RoomTrace.line_for(game, room_type)
			for later in LATER:
				RoomTrace.line_for(game, later)
	RoomTrace.enabled = true
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"snap": _snap(game),
		"summary": str(game.report().get("summary", "")),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
		"flag": bool(game.flags.get("seen_room_trace", false)),
	}


func _snap(game: Game) -> String:
	return "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(),
		int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state),
		int(game.story_rng.state), int(game.crunch_rng.state),
	]


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


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	return game


func _place(game, type: String) -> String:
	var have := _uid(game, type)
	if have != "":
		return have
	var cell := _force_open(game)
	if cell.x < 0:
		return ""
	game._place_room(type, cell.x, cell.y)
	return _uid(game, type)


func _force_open(game) -> Vector2i:
	var open := _open_cell(game)
	if open.x >= 0:
		return open
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if str(spot.get("room", "")) != "" or bool(spot.get("flooded", false)):
			continue
		spot.dug = true
		spot.pile = ""
		if game._cell_buildable(spot):
			return Vector2i(int(spot.level), int(spot.cell))
	return Vector2i(-1, -1)


func _make_pile(game, kind: String) -> Vector2i:
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if str(spot.get("room", "")) != "" or bool(spot.get("flooded", false)):
			continue
		if str(spot.get("pile", "")) != "":
			continue
		if not bool(spot.get("dug", false)):
			spot.dug = true
		if not game._cell_buildable(spot) and str(spot.get("room", "")) != "":
			continue
		spot.pile = kind
		return Vector2i(int(spot.level), int(spot.cell))
	return Vector2i(-1, -1)


func _uid(game, type: String) -> String:
	for room in game.rooms:
		if str(room.type) == type:
			return str(room.uid)
	return ""


func _open_cell(game) -> Vector2i:
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if game._cell_buildable(spot):
			return Vector2i(int(spot.level), int(spot.cell))
	return Vector2i(-1, -1)


func _staff(game, room) -> void:
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or str(person.get("post", "")) != "":
			continue
		room.staff.append(str(person.id))
		person["post"] = str(room.uid)
		return


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir():
			_wipe(sub)
			dir.remove(name)
		else:
			dir.remove(name)
		name = dir.get_next()
