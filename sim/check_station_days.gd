extends SceneTree

## P89 Station Days gate.
##   godot --headless --path . -s res://sim/check_station_days.gd
## Balance ZERO. Soft dawn none. Map mark none. Schema 20. kept sympathy bump unwired.

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
const OFFSETS := {
	"riverside": 1, "chapel": 1,
	"northgate": 2, "observatory": 2, "quarry": 2,
	"market": 3, "stadium": 3,
	"plaza": 4, "eastwater": 4, "mill": 4,
	"brickworks": 5, "harbor": 5,
	"foundry": 6, "library": 6, "dockyard": 6,
	"westfield": 7, "garden": 7,
	"central": 8, "trampark": 8, "clocktower": 8,
}
const BUNKERS := ["archive", "vault", "signal", "oldcommand"]

var _failed := false


class Host extends Node:
	var game
	var showing_network := true
	var network_view = null
	var body_font: Font
	func _motion_off() -> bool:
		return true
	func _ui_click() -> void:
		pass
	func _portrait_box(id: String, px: int) -> TextureRect:
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(px, px)
		face.size = Vector2(px, px)
		face.set_meta("portrait_for", id)
		return face
	func _close_observer() -> void:
		pass
	func _toggle_network() -> void:
		showing_network = true
	func _map_toast_face() -> StyleBoxFlat:
		var face := StyleBoxFlat.new()
		face.bg_color = Color("efe4c8")
		face.border_color = Color("2b2118")
		face.set_border_width_all(1)
		face.set_content_margin_all(8)
		return face
	func _tip_plate_style() -> StyleBoxFlat:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.07, 0.06, 0.05, 0.97)
		plate.border_color = Color(0.93, 0.78, 0.42, 0.9)
		plate.set_border_width_all(1)
		plate.set_content_margin_all(8)
		return plate


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	StationDays.enabled = true
	StationDays.held_float = ""
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("STATION DAYS FAIL catalog")
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 23:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _wheel(catalog):
		_failed = true
	else:
		print("Wheel: ok")
	if not _memory(catalog):
		_failed = true
	else:
		print("Memory: ok")
	if not _save(catalog):
		_failed = true
	else:
		print("Save: ok")
	if not _bounds():
		_failed = true
	else:
		print("Bounds: ok")
	if not await _ui(catalog):
		_failed = true
	else:
		print("UI: ok")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if _failed:
		print("STATION DAYS FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("STATION DAYS FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("STATION DAYS FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	StationDays.enabled = true
	print("STATION DAYS OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _fresh(catalog: Catalog, run_seed: int = 4) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.week = 6
	return game


func _touch(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.known = true
	st.sympathy = 10
	st.owner = "neutral"
	st.hidden = false


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/station_days.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P89":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	var frag = JSON.parse_string(FileAccess.get_file_as_string("res://data/station_days_ru_fragment.json"))
	if rows.size() != 71 or not (frag is Dictionary) or frag.size() != 71:
		_bad("key count %s / %s" % [rows.size(), frag.size() if frag is Dictionary else "bad"])
		return false
	var days: Dictionary = pack.get("_days", {})
	if days.size() != 20:
		_bad("day rows %d" % days.size())
		return false
	for sid in OFFSETS:
		if int(days.get(sid, {}).get("offset", -1)) != int(OFFSETS[sid]):
			_bad("offset " + str(sid))
			return false
		for part in ["name", "desc", "kept"]:
			var key := "sday.%s.%s" % [str(sid), part]
			if not rows.has(key):
				_bad("missing " + key)
				return false
	for key in ["sday.today", "sday.soon", "sday.soon_one", "sday.quiet", "sday.kept_report", "sday.intruded_report", "sday.intruded", "sday.kept_kit", "sday.count", "sday.first", "sday.tip"]:
		if not rows.has(key):
			_bad("missing " + key)
			return false
	for key in rows:
		if not str(key).begins_with("sday."):
			_bad("namespace " + str(key))
			return false
		if str(key).begins_with("feast."):
			_bad("feast namespace")
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty " + str(key))
			return false
		if str(row.get("ru", "")) != str(frag.get(key, "")):
			_bad("ru drift " + str(key))
			return false
	if str(rows["sday.soon"].ru) != "{day} — через {n} нед.":
		_bad("soon ru form")
		return false
	if str(rows["sday.soon_one"].en).find("1 week") >= 0:
		_bad("soon_one says 1 week")
		return false
	var parked = pack.get("_flag_later", {})
	if not (parked is Dictionary) or int(parked.get("kept_bonus", -1)) != 0:
		_bad("parked flag missing")
		return false
	Copy.set_lang("ru")
	if Copy.t("sday.first") != "У станций свои дни. Кто-то записывает, кто приходит.":
		_bad("first ru")
		return false
	if Copy.fill("sday.soon", {"day": "День показа", "n": 2}) != "День показа — через 2 нед.":
		_bad("soon fill")
		return false
	if Copy.fill("sday.soon_one", {"day": "День показа"}) != "День показа — на следующей неделе.":
		_bad("soon_one ru")
		return false
	Copy.set_lang("en")
	if Copy.t("sday.today") != "{day} — this week.":
		_bad("today en")
		return false
	if Copy.t("sday.kept_kit") != "You wore it on {day}. They noticed.":
		_bad("kit en")
		return false
	return true


func _wheel(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	if StationDays.ids().size() != 20:
		_bad("id count")
		return false
	var faces := PlatformFaces.face_ids()
	if faces.size() != 20:
		_bad("face roster")
		return false
	var per := {}
	for sid in OFFSETS:
		if not faces.has(str(sid)) or StationDays.offset_of(str(sid)) != int(OFFSETS[sid]):
			_bad("roster " + str(sid))
			return false
		if not StationDays.has_day(game, str(sid)):
			_bad("has_day " + str(sid))
			return false
		per[int(OFFSETS[sid])] = int(per.get(int(OFFSETS[sid]), 0)) + 1
		var hits := 0
		for week in range(1, 41):
			var on := (week - int(OFFSETS[sid])) % 8 == 0
			game.week = week
			if StationDays.day_week(game, str(sid)) != on:
				_bad("day week %s %d" % [sid, week])
				return false
			if on:
				hits += 1
				if StationDays.weeks_to(game, str(sid)) != 0:
					_bad("weeks_to today %s" % sid)
					return false
		if hits != 5:
			_bad("hits %s %d" % [sid, hits])
			return false
	for off in per:
		if int(per[off]) > 3:
			_bad("crowd week %s" % str(off))
			return false
	if StationDays.has_day(game, str(game.capital_id)):
		_bad("home day")
		return false
	for bunker in BUNKERS:
		if StationDays.has_day(game, bunker) or StationDays.offset_of(bunker) != 0:
			_bad("bunker day " + bunker)
			return false
	game.week = 4
	if StationDays.weeks_to(game, "brickworks") != 1:
		_bad("soon one %d" % StationDays.weeks_to(game, "brickworks"))
		return false
	game.week = 3
	if StationDays.weeks_to(game, "brickworks") != 2:
		_bad("soon two")
		return false
	game.week = 6
	if StationDays.weeks_to(game, "brickworks") != 7:
		_bad("far")
		return false
	if StationDays.dawn_chip() or StationDays.map_mark() or StationDays.joins_soft_dawn() or game.station_days_dawn_chip():
		_bad("dawn or map")
		return false
	return true


func _memory(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var sid := "brickworks"
	game.week = 5
	if StationDays.on_order(game, "envoy", sid) != "":
		_bad("unknown kept")
		return false
	_touch(game, sid)
	if StationDays.row_text(game, sid) == "" or StationDays.tip_line(game, sid) != StationDays.row_text(game, sid):
		_bad("today row")
		return false
	if StationDays.row_text(game, sid) != Copy.fill("sday.today", {"day": Copy.t("sday.brickworks.name")}):
		_bad("today text")
		return false
	if StationDays.row_text(game, sid).find("1 week") >= 0:
		_bad("today wording")
		return false
	var kept := StationDays.on_order(game, "envoy", sid)
	if kept.find("Lamp Night") < 0 or kept.find(game.station_text(sid, "community")) < 0:
		_bad("kept report " + kept)
		return false
	if StationDays.on_order(game, "probe", sid) != "":
		_bad("second order counted")
		return false
	if StationDays.count(game) != 1:
		_bad("count %d" % StationDays.count(game))
		return false
	var missed := _fresh(catalog)
	_touch(missed, sid)
	missed.week = 5
	if not missed.sdays.get("kept", {}).is_empty() or not missed.sdays.get("intruded", {}).is_empty():
		_bad("missed stored")
		return false
	var intrude := _fresh(catalog)
	_touch(intrude, sid)
	intrude.week = 5
	var hard := StationDays.on_order(intrude, "probe", sid)
	if hard.find("Lamp Night") < 0 or StationDays.count(intrude) != 0:
		_bad("intrude " + hard)
		return false
	if str(StationDays.face_line(intrude, sid).get("key", "")) != "sday.intruded":
		_bad("intrude face")
		return false
	intrude.week = 7
	if not StationDays.face_line(intrude, sid).is_empty():
		_bad("face lingered")
		return false
	var owned := _fresh(catalog)
	_touch(owned, "plaza")
	owned.week = 4
	owned.stations.plaza.owner = owned.player
	if StationDays.on_order(owned, "focus", "plaza") == "":
		_bad("owned focus")
		return false
	var foreign := _fresh(catalog)
	_touch(foreign, "plaza")
	foreign.week = 4
	if StationDays.on_order(foreign, "focus", "plaza") != "":
		_bad("unowned focus")
		return false
	var quiet := _fresh(catalog)
	_touch(quiet, sid)
	quiet.week = 5
	StationDays.note_capture(quiet, sid, quiet.player, true)
	var struck := StationDays.on_order(quiet, "assault", sid)
	if struck == "" or StationDays.count(quiet) != 0:
		_bad("capture order lost")
		return false
	quiet.week = 13
	if StationDays.on_order(quiet, "envoy", sid) != "" or StationDays.row_text(quiet, sid).find("No one keeps") < 0:
		_bad("quiet did not hold")
		return false
	if StationDays.tip_line(quiet, sid) != "":
		_bad("quiet hover")
		return false
	quiet.week = 9
	if StationDays.weeks_to(quiet, sid) <= 3:
		_bad("fixture week")
		return false
	if StationDays.row_text(quiet, sid) != Copy.fill("sday.quiet", {"day": Copy.t("sday.brickworks.name")}):
		_bad("quiet off window")
		return false
	StationDays.note_capture(quiet, sid, "enemy", true)
	if not StationDays.is_quiet(quiet, sid):
		_bad("enemy capture cleared quiet")
		return false
	var peace := _fresh(catalog)
	_touch(peace, sid)
	peace.week = 5
	StationDays.note_capture(peace, sid, peace.player, false)
	if StationDays.is_quiet(peace, sid):
		_bad("peace quieted")
		return false
	var kit := _fresh(catalog)
	_touch(kit, sid)
	kit.week = 5
	StationDays.on_order(kit, "envoy", sid)
	PlatformFaces.meet(kit, sid)
	if str(StationDays.face_line(kit, sid).get("key", "")) != "sday.brickworks.kept":
		_bad("kept face")
		return false
	kit.obs.kit_worn.lamp = "carbide"
	if str(StationDays.face_line(kit, sid).get("key", "")) != "sday.kept_kit":
		_bad("kit face")
		return false
	kit.week = 6
	if str(StationDays.face_line(kit, sid).get("key", "")) != "sday.kept_kit":
		_bad("kit face week 2")
		return false
	kit.week = 7
	if not StationDays.face_line(kit, sid).is_empty():
		_bad("kit face week 3")
		return false
	var spoken: Dictionary = PlatformFaces.line(kit, sid)
	if int(spoken.get("slot", 0)) == 5:
		_bad("slot 5 after the window")
		return false
	kit.week = 5
	# Face memory, not the station dict. Slot 4 must still beat slot 5.
	var mem: Dictionary = kit.regulars[sid]
	mem.last_kind = "envoy"
	mem.last_week = 5
	var slot: Dictionary = PlatformFaces.line(kit, sid)
	if int(slot.get("slot", 0)) != 4:
		_bad("slot 4 lost to the day %s" % str(slot.get("key", "")))
		return false
	game.week = 4
	_touch(game, sid)
	var soon := StationDays.row_text(game, sid)
	if soon != Copy.fill("sday.soon_one", {"day": Copy.t("sday.brickworks.name")}) or soon.find("1 week") >= 0:
		_bad("soon_one " + soon)
		return false
	game.week = 3
	var two := StationDays.row_text(game, sid)
	if two != Copy.fill("sday.soon", {"day": Copy.t("sday.brickworks.name"), "n": 2}) or two.find("1 week") >= 0:
		_bad("soon " + two)
		return false
	Copy.set_lang("ru")
	if StationDays.row_text(game, sid) != "Ночь фонарей — через 2 нед.":
		_bad("ru soon " + StationDays.row_text(game, sid))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	if not _report(catalog):
		return false
	return true


func _report(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 3)
	var sid := ""
	var at := 0
	for id in game.stations:
		var key := str(id)
		if not game.borders_player(key) or not StationDays.has_day(game, key):
			continue
		sid = key
		at = StationDays.offset_of(key)
		break
	if sid == "":
		_bad("no bordering day")
		return false
	_touch(game, sid)
	game.week = at + 1
	game.stock.influence = 40
	game.queued_orders.append({
		"action": {"order": "envoy", "station": sid},
		"role": "voice",
		"person": "ida",
		"name": "Ida Cole",
		"cost": {},
		"home": game.capital_id,
		"target": sid,
		"kind": "envoy",
		"prev_address": -99,
	})
	var before := int(game.stock.influence)
	game._resolve_queued()
	if game.order_reports.is_empty():
		_bad("no report")
		return false
	var row: Dictionary = game.order_reports[0]
	var text := str(row.get("text", ""))
	var want := Copy.fill("sday.kept_report", {"day": Copy.t("sday.%s.name" % sid), "station": game.station_text(sid, "community")})
	if text.find(want) < 0:
		_bad("report line missing %s" % want)
		return false
	if int(game.sdays.kept.get(sid, []).size()) != 1 or int(game.sdays.kept[sid][0]) != at:
		_bad("queued week")
		return false
	if int(game.stock.influence) >= before:
		_bad("envoy did not spend")
		return false
	return true


func _save(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	_touch(game, "riverside")
	game.week = 1
	StationDays.on_order(game, "envoy", "riverside")
	game.flags[StationDays.SEEN] = true
	var data := game.export_state()
	data["schema"] = 20
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data):
		_bad("schema 20 load " + again.load_error)
		return false
	if int(again.sdays.kept.get("riverside", []).size()) != 1 or not bool(again.flags.get(StationDays.SEEN, false)):
		_bad("round trip")
		return false
	var old := game.export_state()
	old.erase("sdays")
	old["schema"] = 19
	var migrated := Game.new()
	migrated.catalog = catalog
	if not migrated.import_state(old):
		_bad("schema 19 load " + migrated.load_error)
		return false
	if not migrated.sdays.get("kept", {}).is_empty() or not migrated.sdays.get("intruded", {}).is_empty() or not migrated.sdays.get("quiet", {}).is_empty():
		_bad("schema 19 kept days")
		return false
	var older := game.export_state()
	older.erase("sdays")
	older["schema"] = 16
	var back := Game.new()
	back.catalog = catalog
	if not back.import_state(older):
		_bad("schema 16 load " + back.load_error)
		return false
	if not back.sdays.get("kept", {}).is_empty():
		_bad("schema 16 kept days")
		return false
	var bare := game.export_state()
	bare.erase("sdays")
	bare["schema"] = 20
	var refused := Game.new()
	refused.catalog = catalog
	if refused.import_state(bare):
		_bad("schema 20 accepted a save with no sdays")
		return false
	return true


func _bounds() -> bool:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 23") < 0 or src.find("V19_ADDED") < 0 or src.find("V20_ADDED") < 0:
		_bad("schema source")
		return false
	if src.find("\"sdays\"") < 0:
		_bad("persist missing")
		return false
	if src.find("sdays[") >= 0 or src.find("sdays.get") >= 0:
		_bad("sim reads sdays")
		return false
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("sday") >= 0 or picker.find("StationDays") >= 0:
		_bad("dawn picker knows days")
		return false
	var ticker := _fn(src, "ticker_rows")
	if ticker.find("sday") >= 0 or ticker.find("StationDays") >= 0:
		_bad("ticker knows days")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _fn(view, "_draw_pin")
	if pin.find("StationDays") >= 0 or pin.find("sday") >= 0:
		_bad("map pin knows days")
		return false
	for draw_name in ["_draw_pins", "_draw_soft_marks", "_draw_ink"]:
		var body := _fn(view, draw_name)
		if body.find("StationDays") >= 0 or body.find("sday") >= 0:
			_bad(draw_name + " draws a day mark")
			return false
	if FileAccess.get_file_as_string("res://sim/bot.gd").find("sdays") >= 0 or FileAccess.get_file_as_string("res://sim/bot.gd").find("StationDays") >= 0:
		_bad("bot reads days")
		return false
	var dir := DirAccess.open("res://sim")
	if dir == null:
		_bad("sim dir")
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gd") and not name.begins_with("check_") and name != "station_days.gd" and name != "game.gd":
			var body := FileAccess.get_file_as_string("res://sim/" + name)
			if body.find("sdays") >= 0:
				_bad("sim file reads sdays " + name)
				return false
		name = dir.get_next()
	for path in ["res://sim/station_days.gd", "res://sim/game.gd", "res://ui/network_view.gd", "res://ui/observer_panel.gd", "res://ui/station.gd"]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("kept_bonus") >= 0 or body.find("closed_bonus") >= 0:
			_bad("bonus wired in " + path)
			return false
	var days := FileAccess.get_file_as_string("res://sim/station_days.gd")
	if days.find("feast.") >= 0:
		_bad("feast namespace")
		return false
	var fill := _fn(view, "_fill_visit")
	var perk_at := fill.find("_add_perk_good")
	var day_at := fill.find("_add_station_day")
	var transfer_at := fill.find("_add_transfer_status")
	var toll_at := fill.find("_add_quiet_toll")
	var ledger_at := fill.find("_add_outpost_ledger")
	if perk_at < 0 or day_at < 0 or transfer_at < 0 or toll_at < 0 or ledger_at < 0:
		_bad("row calls missing")
		return false
	if not (perk_at < day_at and day_at < transfer_at and transfer_at < toll_at and toll_at < ledger_at):
		_bad("SD-U2 row order")
		return false
	var yard := _fn(FileAccess.get_file_as_string("res://ui/station.gd"), "_show_sday_yard")
	if yard.find("_tip_plate_style") < 0 or yard.find("outline_size\", 0") < 0 or yard.find("outline_size\", 6") >= 0:
		_bad("yard float plate")
		return false
	var map_fn := _fn(view, "_show_sday_float")
	if map_fn.find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	return true


func _fn(src: String, fname: String) -> String:
	var at := src.find("func " + fname)
	if at < 0:
		return ""
	var next := src.find("\nfunc ", at + 4)
	if next < 0:
		next = src.length()
	return src.substr(at, next - at)


func _ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	game.week = 5
	_touch(game, "brickworks")
	_touch(game, "chapel")
	game.stations.chapel.known = false
	var host := Host.new()
	host.game = game
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	root.add_child(host)
	var view := NetworkView.new()
	host.network_view = view
	view.host = host
	view.size = Vector2(1280, 720)
	view.visible = true
	root.add_child(view)
	await process_frame
	view.open_visit("chapel")
	await process_frame
	if _row(view) != null:
		_bad("unknown row")
		return false
	view.close_visit()
	view.open_visit("brickworks")
	await process_frame
	await process_frame
	var row := _row(view)
	if row == null:
		_bad("missing today row")
		return false
	if row.focus_mode != Control.FOCUS_NONE:
		_bad("row focusable")
		return false
	var line := _meta(row, "sday_line")
	if line == null or line.clip_text or int(line.get_theme_font_size("font_size")) != 15:
		_bad("SD-N1 style")
		return false
	if str(line.text) != StationDays.row_text(game, "brickworks"):
		_bad("row text")
		return false
	if line.get_theme_color("font_color") != NetworkView.INK:
		_bad("row ink")
		return false
	var tip: Control = row._make_custom_tooltip(row.tooltip_text)
	var width := float(tip.get_meta("sday_tip_width", 999))
	var tip_lab := _meta(tip, "sday_tip_line")
	if width > 360.0 or tip_lab == null or str(tip_lab.text).find("\n") < 0:
		_bad("SD-N3 tip")
		return false
	if str(tip_lab.text).find(Copy.t("sday.brickworks.desc")) < 0 or str(tip_lab.text).find(Copy.t("sday.tip")) < 0:
		_bad("tip lines")
		return false
	if _glyph(row) != null:
		var glyph: Control = _glyph(row)
		if glyph.custom_minimum_size != Vector2(16, 16) or glyph.modulate != NetworkView.INK:
			_bad("glyph")
			return false
	if not _ordered(view):
		return false
	var hover := view._tip("brickworks")
	if hover.find(str(line.text)) < 0:
		_bad("SD-U3 tip")
		return false
	var plate := view._float_plate(view._sday_float) if view._sday_float != null else null
	if view._sday_float == null or not view._sday_float.visible or str(view._sday_float.text) != Copy.t("sday.first"):
		_bad("first float")
		return false
	if plate == null or not bool(plate.get_meta("map_float_plate", false)):
		_bad("X1 plate")
		return false
	if int(view._sday_float.get_theme_constant("outline_size")) != 0:
		_bad("float outline")
		return false
	view.close_visit()
	view.open_visit("brickworks")
	await process_frame
	if view._sday_float != null and view._sday_float.visible and str(view._sday_float.text) == Copy.t("sday.first") and not bool(game.flags.get(StationDays.SEEN, false)):
		_bad("first float repeated")
		return false
	view.size = Vector2(1920, 1080)
	view._fill_visit("brickworks")
	await process_frame
	line = _meta(_row(view), "sday_line")
	if line == null or line.clip_text or int(line.get_theme_font_size("font_size")) != 15:
		_bad("125 font")
		return false
	Copy.set_lang("ru")
	view._fill_visit("clocktower")
	await process_frame
	# clocktower is not known yet
	_touch(game, "clocktower")
	game.week = 8
	view._fill_visit("clocktower")
	await process_frame
	var ru_line := _meta(_row(view), "sday_line")
	if ru_line == null or ru_line.clip_text or str(ru_line.text) != "День показа — на этой неделе.":
		_bad("ru today " + (str(ru_line.text) if ru_line != null else "missing"))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	game.week = 5
	StationDays.note_capture(game, "brickworks", game.player, true)
	view._fill_visit("brickworks")
	await process_frame
	var quiet := _meta(_row(view), "sday_line")
	if quiet == null or str(quiet.text).find("No one keeps") < 0:
		_bad("quiet row")
		return false
	if view._tip("brickworks").find(str(quiet.text)) >= 0:
		_bad("quiet on the pin")
		return false
	if not await _tally(host, game):
		return false
	return true


func _ordered(view: NetworkView) -> bool:
	var row := _row(view)
	if row == null or row.get_parent() == null:
		_bad("row parent")
		return false
	var kids: Array = row.get_parent().get_children()
	var day_i := kids.find(row)
	var perk_i := -1
	var transfer_i := -1
	var toll_i := -1
	var ledger_i := -1
	for i in kids.size():
		var child: Node = kids[i]
		if child.has_meta("perk_line") or child.has_meta("good_line"):
			perk_i = i
		if child.has_meta("transfer_status"):
			transfer_i = i
		if child.has_meta("toll_row"):
			toll_i = i
		if child.has_meta("ledger_row"):
			ledger_i = i
	if perk_i >= 0 and not (perk_i < day_i):
		_bad("perk after the day")
		return false
	if transfer_i >= 0 and not (day_i < transfer_i):
		_bad("day after transfer")
		return false
	if toll_i >= 0 and transfer_i >= 0 and not (transfer_i < toll_i):
		_bad("transfer after toll")
		return false
	if ledger_i >= 0 and not (day_i < ledger_i):
		_bad("day after ledger")
		return false
	if ledger_i >= 0 and toll_i >= 0 and not (toll_i < ledger_i):
		_bad("toll after ledger")
		return false
	return true


func _tally(host: Node, game: Game) -> bool:
	var panel := ObserverPanel.new()
	panel.size = Vector2(800, 720)
	root.add_child(panel)
	await process_frame
	panel.present(host)
	await process_frame
	var zero := _find_meta(panel, "sday_count")
	if zero == null or str(zero.text) != "Days kept: 0" or zero.focus_mode != Control.FOCUS_NONE:
		_bad("empty tally")
		return false
	if _find_meta(panel, "sday_tally") != null:
		_bad("empty tally focusable")
		return false
	game.sdays.kept = {
		"riverside": [1, 9, 17, 25, 33],
		"chapel": [1, 9, 17, 25],
	}
	panel.present(host)
	await process_frame
	var tally := _find_meta(panel, "sday_tally")
	if tally == null or tally.focus_mode != Control.FOCUS_ALL or int(tally.get_meta("sday_rows", 0)) != 9:
		_bad("tally rows")
		return false
	if str(tally.text) != "Days kept: 9":
		_bad("tally text " + str(tally.text))
		return false
	var focus: StyleBoxFlat = tally.get_theme_stylebox("focus")
	if focus == null or focus.get_border_width(SIDE_LEFT) != 1:
		_bad("tally focus rim")
		return false
	var tip: Control = tally._make_custom_tooltip(tally.tooltip_text)
	var scroll := _find_meta(tip, "sday_tally_scroll")
	if scroll == null or int(scroll.get_meta("sday_tally_cap", 0)) != 8:
		_bad("SD-N4 scroll")
		return false
	var grab: StyleBox = scroll.theme.get_stylebox("grabber", "VScrollBar")
	if grab is StyleBoxFlat and (grab as StyleBoxFlat).bg_color.is_equal_approx(Color(0.7, 0.7, 0.7)):
		_bad("grey scroll")
		return false
	var lines := _metas(tip, "sday_tally_line")
	if lines.size() != 9:
		_bad("tally list %d" % lines.size())
		return false
	if str(lines[0].text).find(" · ") < 0:
		_bad("tally shape")
		return false
	return true


func _row(view: NetworkView) -> Control:
	return _find_meta(view, "sday_row")


func _glyph(row: Node) -> Node:
	return _find_meta(row, "sday_glyph")


func _meta(node: Node, key: String) -> Node:
	if node is Control and node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _meta(child, key)
		if found != null:
			return found
	return null


func _find_meta(node: Node, key: String) -> Node:
	return _meta(node, key)


func _metas(node: Node, key: String) -> Array:
	var out: Array = []
	if node is Control and node.has_meta(key):
		out.append(node)
	for child in node.get_children():
		out.append_array(_metas(child, key))
	return out


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		StationDays.enabled = true
		var on := _play(catalog, run_seed)
		StationDays.enabled = false
		var off := _play(catalog, run_seed)
		if str(on.summary) != str(off.summary) or str(on.rng) != str(off.rng) or str(on.snap) != str(off.snap):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		if int(off.days) != 0:
			_bad("seed %d off wrote days" % run_seed)
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
		print("Seed %d: %d %s %s" % [run_seed, got, str(on.over), "match" if got == want else "DIFF"])
	StationDays.enabled = true
	print("Careful loss: %d/60 (master %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master, on/off identical" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss moved")
		return false
	return matched == 60 and not _failed


func _play(catalog: Catalog, run_seed: int) -> Dictionary:
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
	var kept := 0
	if game.sdays.get("kept", {}) is Dictionary:
		kept = game.sdays.kept.size()
	if game.sdays.get("intruded", {}) is Dictionary:
		kept += game.sdays.intruded.size()
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"snap": _snap(game),
		"summary": str(game.report().get("summary", "")),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
		"days": kept,
	}


func _snap(game: Game) -> String:
	var dead := 0
	for row in game.departed:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("how", "")) == "died":
			dead += 1
	var night := 0
	if game.flags.get("night_runs", null) is Dictionary:
		night = int(game.flags.night_runs.get("deaths", 0))
	return "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(), dead, night,
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
