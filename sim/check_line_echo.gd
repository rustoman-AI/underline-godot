extends SceneTree

## P91 Line Echo gate.
##   godot --headless --path . -s res://sim/check_line_echo.gd
## Balance ZERO. Soft dawn none. Map mark none. Schema 22.

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
const BUNKERS := ["archive", "vault", "signal", "oldcommand"]
const KEYS := {
	"echo.said": ["{name} heard about the {kind} at {station}.", "{name} уже знает: {kind} у {station}."],
	"echo.heard": ["Word from the next platform: the {kind} at {station}.", "С соседней платформы: {kind} у {station}."],
	"echo.kind.envoy": ["envoy", "посланник"],
	"echo.kind.deal": ["deal", "сделка"],
	"echo.kind.aid": ["aid", "помощь"],
	"echo.kind.propaganda": ["leaflets", "листовки"],
	"echo.kind.probe": ["probe", "разведка"],
	"echo.kind.patrol": ["patrol", "патруль"],
	"echo.kind.raid": ["raid", "рейд"],
	"echo.first": ["The next station heard.", "Соседняя станция услышала."],
	"echo.tip": ["Neighboring platforms hear what you do.", "Соседние платформы слышат, что ты делаешь."],
}
const SHOTS := "/opt/cursor/artifacts"

var _failed := false


class Host extends Node:
	var game
	var showing_network := true
	var shot_mode := true
	var network_view = null
	var body_font: Font
	var yard_text := ""
	func _motion_off() -> bool:
		return true
	func _portrait_box(id: String, px: int) -> TextureRect:
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(px, px)
		face.set_meta("portrait_for", id)
		return face
	func _try_echo_float() -> void:
		yard_text = LineEcho.held_float


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	LineEcho.enabled = true
	LineEcho.held_float = ""
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("LINE ECHO FAIL catalog")
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 27:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _rules(catalog):
		_failed = true
	else:
		print("Rules: ok")
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
		print("LINE ECHO FAIL")
		quit(1)
		return
	var shots_only := false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--shots":
			shots_only = true
	if shots_only:
		print("LINE ECHO SHOTS")
		quit(0)
		return
	if not _careful(catalog):
		print("LINE ECHO FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("LINE ECHO FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	LineEcho.enabled = true
	print("LINE ECHO OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 6
	game.orders_left = 4
	game.stock.influence = 80
	game.stock.food = 80
	game.stock.materials = 80
	game.stock.air = 80
	game.stock.tokens = 40
	game.stock.power = 40
	return game


func _bunker(game: Game, sid: String) -> bool:
	if not game.stations.has(sid):
		return true
	var st: Dictionary = game.stations[sid]
	if bool(st.get("hidden", false)):
		return true
	if str(st.get("bunker", "")) != "" or str(st.get("owner", "")) == "bunker" or str(st.get("lean", "")) == "bunker":
		return true
	return BUNKERS.has(sid)


func _stage(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.known = true
	st.hidden = false
	st.owner = "neutral"
	st.sympathy = 30
	st.low_weeks = 3
	st.intel = 2
	st.garrison = 2
	for n in game._neighbors(sid):
		var nid := str(n)
		var nb: Dictionary = game.stations[nid]
		if _bunker(game, nid):
			nb.known = true
			continue
		nb.known = true
	if not game.borders_player(sid):
		for n in game._neighbors(sid):
			var nid := str(n)
			if not _bunker(game, nid):
				game.stations[nid].owner = game.player
				break


func _pick(game: Game) -> Dictionary:
	var home := str(game.capital_id)
	for n in game._neighbors(home):
		var sid := str(n)
		if _bunker(game, sid) or not PlatformFaces.has_face(game, sid):
			continue
		var hear := ""
		for m in game._neighbors(sid):
			var nid := str(m)
			if nid == home or _bunker(game, nid) or not PlatformFaces.has_face(game, nid):
				continue
			hear = nid
			break
		if hear == "":
			continue
		return {"sid": sid, "home": home, "hear": hear}
	return {}


func _dist(game: Game, origin: String) -> Dictionary:
	var dist := {origin: 0}
	var queue: Array = [origin]
	var qi := 0
	while qi < queue.size():
		var cur: String = queue[qi]
		qi += 1
		for n in game._neighbors(cur):
			var nid := str(n)
			if dist.has(nid):
				continue
			dist[nid] = int(dist[cur]) + 1
			queue.append(nid)
	return dist


func _meters(game: Game) -> String:
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		int(game.rng.state),
	]


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/line_echo.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P91":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 11 or KEYS.size() != 11:
		_bad("key count %d" % rows.size())
		return false
	for key in KEYS:
		if not rows.has(key) or not str(key).begins_with("echo."):
			_bad("missing " + key)
			return false
		var row: Dictionary = rows[key]
		var want: Array = KEYS[key]
		if str(row.get("en", "")) != str(want[0]) or str(row.get("ru", "")) != str(want[1]):
			_bad("drift " + key)
			return false
		if Copy.t(key) != str(want[0]):
			_bad("en copy " + key)
			return false
	for key in rows:
		if not KEYS.has(key):
			_bad("extra " + str(key))
			return false
	Copy.set_lang("ru")
	for key in KEYS:
		if Copy.t(key) != str(KEYS[key][1]):
			_bad("ru copy " + key + " " + Copy.t(key))
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	if LineEcho.dawn_chip() or LineEcho.joins_soft_dawn() or LineEcho.map_mark():
		_bad("dawn or mark")
		return false
	return true


func _rules(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var picked := _pick(game)
	if picked.is_empty():
		_bad("no 1-hop face pair")
		return false
	var sid := str(picked.sid)
	var home := str(picked.home)
	var hear := str(picked.hear)
	_stage(game, sid)
	for bunker in BUNKERS:
		if game.stations.has(bunker):
			game.stations[bunker].known = true
	var far := ""
	var dist := _dist(game, sid)
	for nid in dist:
		if int(dist[nid]) != 2 or _bunker(game, str(nid)):
			continue
		game.stations[str(nid)].known = true
		far = str(nid)
		break
	if far == "":
		_bad("no 2-hop station")
		return false
	var quiet := ""
	for n in game._neighbors(sid):
		var nid := str(n)
		if nid != home and nid != hear and not _bunker(game, nid):
			quiet = nid
			game.stations[quiet].known = false
			break
	var before := _meters(game)
	var face_before: Dictionary = PlatformFaces.line(game, hear)
	if not game._apply_order({"order": "envoy", "station": sid}):
		_bad("envoy did not resolve")
		return false
	if _meters(game) == before:
		_bad("envoy spent nothing")
		return false
	if game.echoes.has(sid) or game.echoes.has(far) or (quiet != "" and game.echoes.has(quiet)):
		_bad("self, 2-hop, or unknown heard")
		return false
	for bunker in BUNKERS:
		if game.echoes.has(bunker):
			_bad("bunker heard " + bunker)
			return false
	if not game.echoes.has(home) or not game.echoes.has(hear):
		_bad("known 1-hop missed")
		return false
	if str(game.echoes[hear].get("kind", "")) != "envoy" or str(game.echoes[hear].get("from", "")) != sid:
		_bad("envoy memory")
		return false
	if int(game.echoes[hear].get("week", 0)) != int(game.week):
		_bad("week stamp")
		return false
	if game.echoes[hear].size() != 3:
		_bad("cap fields")
		return false
	if LineEcho.line_text(game, sid) != "" or LineEcho.line_text(game, far) != "" or (quiet != "" and LineEcho.line_text(game, quiet) != ""):
		_bad("silent stations spoke")
		return false
	for bunker in BUNKERS:
		if LineEcho.line_text(game, bunker) != "":
			_bad("bunker line")
			return false
	var place := game.station_text(sid, "community")
	var heard := Copy.fill("echo.heard", {"kind": Copy.t("echo.kind.envoy"), "station": place})
	if LineEcho.line_text(game, home) != heard or LineEcho.line_text(game, hear) != heard:
		_bad("unmet line " + LineEcho.line_text(game, hear))
		return false
	PlatformFaces.meet(game, hear)
	var said := Copy.fill("echo.said", {
		"name": Copy.t("regular.%s.name" % hear),
		"kind": Copy.t("echo.kind.envoy"),
		"station": place,
	})
	if LineEcho.line_text(game, hear) != said:
		_bad("met line " + LineEcho.line_text(game, hear))
		return false
	if LineEcho.line_text(game, home) != heard:
		_bad("home grew a face")
		return false
	game.stations[hear].known = false
	if LineEcho.line_text(game, hear) != "":
		_bad("unknown kept speaking")
		return false
	var frozen := str(game.echoes.get(hear, {}))
	LineEcho.note_order(game, {"order": "aid", "station": sid})
	if str(game.echoes.get(hear, {})) != frozen or LineEcho.line_text(game, hear) != "":
		_bad("unknown station took a new echo")
		return false
	game.stations[hear].known = true
	var face_after: Dictionary = PlatformFaces.line(game, hear)
	if str(face_after.get("key", "")).begins_with("echo.") or int(face_after.get("slot", 0)) != int(face_before.get("slot", -1)):
		if int(face_before.get("slot", 0)) != 0 and int(face_after.get("slot", 0)) != int(face_before.get("slot", -1)):
			_bad("face slot moved")
			return false
	if str(PlatformFaces.line(game, hear).get("key", "")).begins_with("echo."):
		_bad("echo stole the face slot")
		return false
	if quiet != "":
		game.stations[quiet].known = true
	if not game._apply_order({"order": "propaganda", "station": sid}):
		_bad("propaganda did not resolve")
		return false
	if str(game.echoes[hear].kind) != "propaganda":
		_bad("newer echo did not overwrite")
		return false
	if quiet != "" and str(game.echoes[quiet].kind) != "propaganda":
		_bad("unknown neighbor stayed quiet after it was known")
		return false
	if LineEcho.line_text(game, hear).find("leaflets") < 0 or LineEcho.line_text(game, hear).find("propaganda") >= 0:
		_bad("kind noun " + LineEcho.line_text(game, hear))
		return false
	var stamped := int(game.echoes[hear].week)
	game.week = stamped + 1
	if LineEcho.line_text(game, hear) == "":
		_bad("gone one week early")
		return false
	game.week = stamped + 2
	if LineEcho.line_text(game, hear) != "" or not game.echoes.has(hear):
		_bad("decay")
		return false
	game.week = stamped
	if not _kinds(catalog, sid):
		return false
	if not _combat(catalog):
		return false
	var pure := _fresh(catalog)
	var again := _pick(pure)
	_stage(pure, str(again.sid))
	var meters := _meters(pure)
	var sym := int(pure.stations[str(again.sid)].sympathy)
	LineEcho.note_order(pure, {"order": "probe", "station": str(again.sid)})
	if _meters(pure) != meters or int(pure.stations[str(again.sid)].sympathy) != sym:
		_bad("echo moved a meter")
		return false
	if str(pure.echoes[str(again.hear)].kind) != "probe":
		_bad("probe kind")
		return false
	var held: Dictionary = pure.echoes.duplicate(true)
	for action in [
		{"order": "focus", "station": str(again.sid), "focus": "food"},
		{"order": "move", "dest": str(again.sid)},
		{"order": "gift", "faction": "exchange"},
		{"order": "pay", "demand": "none"},
		{"order": "tap", "faction": "exchange"},
		{"order": "breach"},
		{"order": "address"},
		{"order": "trade"},
		{"order": "expedition"},
	]:
		LineEcho.note_order(pure, action)
	if str(pure.echoes) != str(held):
		_bad("ignored order wrote an echo")
		return false
	LineEcho.enabled = false
	LineEcho.note_order(pure, {"order": "envoy", "station": str(again.sid)})
	if LineEcho.line_text(pure, str(again.hear)) != "":
		_bad("disabled still speaks")
		return false
	LineEcho.enabled = true
	if LineEcho.line_text(pure, str(again.hear)) == "":
		_bad("enabled hid a live echo")
		return false
	var queued := _fresh(catalog)
	var qp := _pick(queued)
	_stage(queued, str(qp.sid))
	queued.queued_orders = [{
		"action": {"order": "aid", "station": str(qp.sid)},
		"cost": {},
		"role": "talk",
		"name": "Ada",
		"person": "ada",
	}]
	queued._resolve_queued()
	if queued.order_reports.is_empty() or not bool(queued.order_reports.back().get("ok", false)):
		_bad("aid queue failed")
		return false
	if str(queued.echoes[str(qp.hear)].get("kind", "")) != "aid":
		_bad("queued hook")
		return false
	if str(queued.order_reports.back().get("text", "")).find("echo.") >= 0 or str(queued.order_reports.back().get("text", "")).find("next platform") >= 0:
		_bad("report row spam")
		return false
	return true


func _kinds(catalog: Catalog, sid_hint: String) -> bool:
	var want := {
		"envoy": "envoy",
		"trade": "deal",
		"aid": "aid",
		"propaganda": "propaganda",
		"probe": "probe",
		"patrol": "patrol",
		"raid": "raid",
		"assault": "raid",
	}
	for order in want:
		if LineEcho.kind_of(order) != str(want[order]):
			_bad("kind map " + order)
			return false
	for order in ["focus", "move", "gift", "pay", "tap", "breach", "address", "expedition"]:
		if LineEcho.kind_of(order) != "":
			_bad("kind leaked " + order)
			return false
	var game := _fresh(catalog)
	_stage(game, sid_hint)
	if not game._apply_order({"order": "trade", "station": sid_hint}):
		_bad("deal did not resolve")
		return false
	var hear := ""
	for nid in game.echoes:
		hear = str(nid)
		break
	if hear == "" or str(game.echoes[hear].kind) != "deal":
		_bad("deal echo")
		return false
	var patrol := _fresh(catalog)
	var dest := str(_pick(patrol).sid)
	_stage(patrol, dest)
	patrol.stations[dest].owner = "neutral"
	var sq: Dictionary = patrol.squads[patrol.player]
	sq.station = str(patrol.capital_id)
	if patrol._patrol_gate(dest) != "":
		_bad("patrol gate " + patrol._patrol_gate(dest))
		return false
	if not patrol._apply_order({"order": "patrol", "dest": dest}):
		_bad("patrol did not resolve")
		return false
	var wrote := false
	for nid in patrol.echoes:
		wrote = true
		if str(patrol.echoes[nid].kind) != "patrol":
			_bad("patrol kind")
			return false
	if not wrote or patrol.echoes.has(dest):
		_bad("patrol echo")
		return false
	return true


func _combat(catalog: Catalog) -> bool:
	for kind in ["raid", "assault"]:
		var game := _fresh(catalog)
		var dest := ""
		for n in game._neighbors(str(game.capital_id)):
			if not _bunker(game, str(n)):
				dest = str(n)
				break
		if dest == "":
			_bad("no combat neighbor")
			return false
		_stage(game, dest)
		var st: Dictionary = game.stations[dest]
		st.known = true
		st.garrison = 800
		st.fort = 4.0
		st.intel = 3
		st.low_weeks = 4
		st.owner = "neutral" if kind == "assault" else "exchange"
		var sq: Dictionary = game.squads[game.player]
		sq.station = str(game.capital_id)
		sq.away = false
		sq.returning = false
		var gate := game._raid_gate(dest) if kind == "raid" else game._assault_gate(dest)
		if gate != "":
			_bad(kind + " gate " + gate)
			return false
		if not game._apply_order({"order": kind, "dest": dest}):
			_bad(kind + " did not resolve")
			return false
		if game.order_reports.is_empty() and game.last_combat_report.is_empty():
			_bad(kind + " no report")
			return false
		var report: Dictionary = game.last_combat_report
		if report.is_empty() and not game.order_reports.is_empty():
			report = game.order_reports.back()
		if bool(report.get("win", true)):
			_bad(kind + " was not a loss")
			return false
		if game.echoes.has(dest):
			_bad(kind + " echoed at the target")
			return false
		var heard := false
		for nid in game.echoes:
			heard = true
			if str(game.echoes[nid].kind) != "raid":
				_bad(kind + " stored " + str(game.echoes[nid].kind))
				return false
		if not heard:
			_bad(kind + " neighbor silent")
			return false
		if LineEcho.line_text(game, str(game.capital_id)).find(Copy.t("echo.kind.raid")) < 0:
			_bad(kind + " line " + LineEcho.line_text(game, str(game.capital_id)))
			return false
		if LineEcho.line_text(game, str(game.capital_id)).find("assault") >= 0:
			_bad("assault noun leaked")
			return false
	return true


func _save(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var picked := _pick(game)
	_stage(game, str(picked.sid))
	LineEcho.note_order(game, {"order": "envoy", "station": str(picked.sid)})
	game.flags[LineEcho.SEEN] = true
	var data := game.export_state()
	data["schema"] = 22
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data):
		_bad("schema 22 load " + again.load_error)
		return false
	if str(again.echoes[str(picked.hear)].get("kind", "")) != "envoy" or not bool(again.flags.get(LineEcho.SEEN, false)):
		_bad("round trip")
		return false
	data.erase("echoes")
	var bare := Game.new()
	bare.catalog = catalog
	if bare.import_state(data):
		_bad("schema 22 accepted a save with no echoes")
		return false
	for old_schema in [21, 20, 18]:
		var old_data := game.export_state()
		old_data.erase("echoes")
		old_data["schema"] = old_schema
		if old_data.flags is Dictionary:
			old_data.flags.erase(LineEcho.SEEN)
		var old := Game.new()
		old.catalog = catalog
		if not old.import_state(old_data):
			_bad("schema %d load %s" % [old_schema, old.load_error])
			return false
		if not old.echoes.is_empty() or bool(old.flags.get(LineEcho.SEEN, false)):
			_bad("schema %d kept an echo" % old_schema)
			return false
		if old_schema <= 20 and not old.carry.pocket.is_empty():
			_bad("schema %d invented a note" % old_schema)
			return false
	return true


func _bounds() -> bool:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 27") < 0 or src.find("V21_ADDED") < 0 or src.find("V22_ADDED") < 0 or src.find("V23_ADDED") < 0 or src.find("V20_ADDED") < 0:
		_bad("schema source")
		return false
	if src.find("\"echoes\"") < 0 or src.find("echoes[") >= 0 or src.find("echoes.get") >= 0:
		_bad("sim reads echoes")
		return false
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("echo") >= 0 or picker.find("LineEcho") >= 0:
		_bad("dawn picker knows echoes")
		return false
	if _fn(src, "_apply_order").find("LineEcho.note_order") < 0 or _fn(src, "_resolve_queued").find("LineEcho.note_order") < 0:
		_bad("resolve hook missing")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	for draw_name in ["_draw_pin", "_draw_pins", "_draw_soft_marks", "_draw_ink"]:
		var body := _fn(view, draw_name)
		if body.find("LineEcho") >= 0 or body.find("echo.") >= 0:
			_bad(draw_name + " draws an echo mark")
			return false
	var fill := _fn(view, "_fill_visit")
	var head_at := fill.find("add_child(head)")
	var face_at := fill.find("_add_face_row")
	var echo_at := fill.find("_add_echo_line")
	var details_at := fill.find("_details_box")
	if head_at < 0 or face_at < 0 or echo_at < 0 or details_at < 0:
		_bad("visit markers")
		return false
	if not (head_at < face_at and face_at < echo_at and echo_at < details_at):
		_bad("LE-U2 placement")
		return false
	var faces := FileAccess.get_file_as_string("res://sim/platform_faces.gd")
	if faces.find("echo.") >= 0 or faces.find("LineEcho") >= 0:
		_bad("face cap reopened")
		return false
	if FileAccess.get_file_as_string("res://sim/bot.gd").find("echoes") >= 0 or FileAccess.get_file_as_string("res://sim/bot.gd").find("LineEcho") >= 0:
		_bad("bot reads echoes")
		return false
	var dir := DirAccess.open("res://sim")
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gd") and not name.begins_with("check_") and name != "line_echo.gd" and name != "game.gd":
			var body := FileAccess.get_file_as_string("res://sim/" + name)
			if body.find("echoes") >= 0 or body.find("LineEcho") >= 0:
				_bad("sim file reads echoes " + name)
				return false
		name = dir.get_next()
	for path in ["res://sim/line_echo.gd", "res://ui/network_view.gd", "res://ui/station.gd", "res://sim/game.gd"]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("kept_bonus") >= 0 or body.find("closed_bonus") >= 0:
			_bad("bonus wired in " + path)
			return false
	var logic := FileAccess.get_file_as_string("res://sim/line_echo.gd")
	for token in ["leaflets", "посланник", "balance", "rng.", "stock.", "hope ", "discontent"]:
		if logic.find(token) >= 0:
			_bad("logic touches " + token)
			return false
	var yard := _fn(FileAccess.get_file_as_string("res://ui/station.gd"), "_show_echo_yard")
	if yard.find("_tip_plate_style") < 0 or yard.find("outline_size\", 0") < 0 or yard.find("_place_yard_notice") < 0:
		_bad("yard float plate")
		return false
	if yard.find("custom_minimum_size = Vector2(420, 36)") >= 0 or yard.find("size = Vector2(420, 36)") >= 0:
		_bad("yard plate sizes before the line has a width")
		return false
	var map_fn := _fn(view, "_show_echo_float")
	if map_fn.find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	if FileAccess.get_file_as_string("res://data/balance.json").find("echo") >= 0:
		_bad("balance mentions echo")
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
	var picked := _pick(game)
	var sid := str(picked.sid)
	var hear := str(picked.hear)
	_stage(game, sid)
	for bunker in BUNKERS:
		if game.stations.has(bunker):
			game.stations[bunker].known = true
	game.flags[PlatformFaces.SEEN] = true
	game.flags[StationDays.SEEN] = true
	game.flags[CarriedWord.SEEN] = true
	PlatformFaces.meet(game, hear)
	var host := Host.new()
	host.game = game
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	root.add_child(host)
	var view := NetworkView.new()
	host.network_view = view
	view.host = host
	root.add_child(view)
	if not await _fit(view, Vector2i(1920, 1080)):
		return false
	view.open_visit(hear)
	await process_frame
	await process_frame
	if _echo(view) != null:
		_bad("echo before the order")
		return false
	if _faces(view) != 1:
		_bad("face missing before")
		return false
	await _shot(view, "%s/p91_before_visit_en.png" % SHOTS)
	Copy.set_lang("ru")
	host.body_font = load("res://assets/fonts/PTMono-Regular.ttf")
	if not await _fit(view, Vector2i(1536, 864)):
		return false
	view.open_visit(hear)
	await process_frame
	await process_frame
	await _shot(view, "%s/p91_before_visit_ru_125.png" % SHOTS)
	Copy.set_lang("en")
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	if not await _fit(view, Vector2i(1920, 1080)):
		return false
	if not game._apply_order({"order": "envoy", "station": sid}):
		_bad("ui envoy")
		return false
	view.open_visit("archive")
	await process_frame
	if _echo(view) != null:
		_bad("bunker visit")
		return false
	view.open_visit(sid)
	await process_frame
	if _echo(view) != null:
		_bad("target visit")
		return false
	view.open_visit(hear)
	await process_frame
	await process_frame
	if not await _layout(view, game, hear, "en"):
		return false
	var float_lab := _meta(view, "echo_float")
	if float_lab == null or str(float_lab.text) != Copy.t("echo.first"):
		_bad("first float")
		return false
	if int(float_lab.get_theme_constant("outline_size")) != 0:
		_bad("float outline")
		return false
	if not float_lab.get_theme_color("font_color").is_equal_approx(NetworkView.TAG_INK):
		_bad("float ink")
		return false
	var plate := float_lab.get_parent()
	if plate == null or not bool(plate.get_meta("map_float_plate", false)):
		_bad("float plate")
		return false
	if not bool(game.flags.get(LineEcho.SEEN, false)) or LineEcho.claim_first(game) != "":
		_bad("float once")
		return false
	await _shot(view, "%s/p91_after_echo_float_en.png" % SHOTS)
	if not await _fit(view, Vector2i(1536, 864)):
		return false
	view.open_visit(hear)
	await process_frame
	await process_frame
	if not await _layout(view, game, hear, "en-125"):
		return false
	await _shot(view, "%s/p91_after_echo_en_125.png" % SHOTS)
	Copy.set_lang("ru")
	host.body_font = load("res://assets/fonts/PTMono-Regular.ttf")
	game.flags.erase(LineEcho.SEEN)
	if view._echo_float != null:
		view._echo_float.visible = false
		var old_plate := view._echo_float.get_parent()
		if old_plate != null:
			old_plate.visible = false
	if not await _fit(view, Vector2i(1920, 1080)):
		return false
	view.open_visit(hear)
	await process_frame
	await process_frame
	if not await _layout(view, game, hear, "ru"):
		Copy.set_lang("en")
		return false
	var ru_float := _meta(view, "echo_float")
	if ru_float == null or str(ru_float.text) != "Соседняя станция услышала.":
		_bad("ru float")
		Copy.set_lang("en")
		return false
	await _shot(view, "%s/p91_after_echo_float_ru.png" % SHOTS)
	if not await _fit(view, Vector2i(1536, 864)):
		return false
	view.open_visit(hear)
	await process_frame
	await process_frame
	if not await _layout(view, game, hear, "ru-125"):
		Copy.set_lang("en")
		return false
	await _shot(view, "%s/p91_after_echo_ru_125.png" % SHOTS)
	Copy.set_lang("en")
	PlatformFaces.enabled = false
	view.open_visit(hear)
	await process_frame
	await process_frame
	if _faces(view) != 0 or _echo(view) == null:
		_bad("P88 off row")
		PlatformFaces.enabled = true
		return false
	var kids: Array = view._visit_body.get_children()
	var head_i := -1
	var echo_i := -1
	var detail_i := -1
	for i in kids.size():
		var child: Node = kids[i]
		if child.has_meta("visit_head"):
			head_i = i
		if child.has_meta("echo_row"):
			echo_i = i
		if child.has_meta("details_toggle"):
			detail_i = i
	if not (head_i >= 0 and echo_i == head_i + 1 and detail_i > echo_i):
		_bad("echo not under the head")
		PlatformFaces.enabled = true
		return false
	PlatformFaces.enabled = true
	var yard := _fresh(catalog)
	var yp := _pick(yard)
	_stage(yard, str(yp.sid))
	LineEcho.note_order(yard, {"order": "envoy", "station": str(yp.sid)})
	host.game = yard
	host.showing_network = false
	host.yard_text = ""
	view._note_first_echo(true)
	if host.yard_text != Copy.t("echo.first"):
		_bad("yard handoff")
		return false
	view.queue_free()
	host.queue_free()
	return true


func _layout(view: NetworkView, game: Game, hear: String, tag: String) -> bool:
	var row := _echo(view)
	var face := _face(view)
	if row == null or face == null:
		_bad(tag + " missing row")
		return false
	if _faces(view) != 1 or _echoes(view) != 1:
		_bad(tag + " cap")
		return false
	if row.get_parent() == face or face.find_child("echo_line", true, false) != null:
		_bad(tag + " inside the face")
		return false
	var quote := _meta(face, "face_line")
	if quote != null and str(quote.text) == str(row.text):
		_bad(tag + " copied into the face")
		return false
	if str(row.text) != LineEcho.line_text(game, hear):
		_bad(tag + " text " + str(row.text))
		return false
	if str(row.tooltip_text) != Copy.t("echo.tip"):
		_bad(tag + " tip")
		return false
	if row.focus_mode != Control.FOCUS_NONE or row.clip_text:
		_bad(tag + " focus or clip")
		return false
	if int(row.get_theme_font_size("font_size")) != 14:
		_bad(tag + " font")
		return false
	if not row.get_theme_color("font_color").is_equal_approx(Color("d9cbb4")):
		_bad(tag + " ink")
		return false
	if quote != null and row.get_theme_color("font_color").is_equal_approx(quote.get_theme_color("font_color")):
		_bad(tag + " same ink as the face")
		return false
	if row.get_line_count() > 2 or row.get_line_count() < 1:
		_bad(tag + " lines %d" % row.get_line_count())
		return false
	var wide := row.get_combined_minimum_size()
	if wide.x < wide.y * 3.0 or wide.x < 180.0:
		_bad(tag + " letter stack %s" % str(wide))
		return false
	var body: Control = view._visit_body
	var kids: Array = body.get_children()
	var face_i := kids.find(face)
	var echo_i := kids.find(row)
	var detail_i := -1
	for i in kids.size():
		if kids[i].has_meta("details_toggle"):
			detail_i = i
	if face_i < 0 or echo_i != face_i + 1 or detail_i < echo_i:
		_bad(tag + " order")
		return false
	var er: Rect2 = row.get_global_rect()
	var fr: Rect2 = face.get_global_rect()
	if er.size.y < 8.0 or fr.size.y < 8.0:
		_bad(tag + " zero rect")
		return false
	if er.intersects(fr) or er.position.y + 1.0 < fr.position.y + fr.size.y * 0.5:
		_bad(tag + " overlap")
		return false
	var limit := body.get_global_rect()
	if er.position.x < limit.position.x - 2.0 or er.end.x > limit.end.x + 4.0:
		_bad(tag + " clipped x")
		return false
	if view._tip(hear).find(str(row.text)) < 0:
		_bad(tag + " pin")
		return false
	if view._tip(hear) != "" and LineEcho.line_text(game, hear) != str(row.text):
		_bad(tag + " pin mismatch")
		return false
	return true


func _fit(view: NetworkView, sz: Vector2i) -> bool:
	DisplayServer.window_set_size(sz)
	root.size = sz
	view.size = Vector2(sz)
	view.position = Vector2.ZERO
	await process_frame
	view._size_visit()
	await process_frame
	return true


func _shot(view: NetworkView, path: String) -> void:
	# The envoy's one-shot need line belongs to that station. It stays up across the next Visit.
	if view._need_float != null:
		view._need_float.visible = false
	var face := _face(view)
	var echo := _echo(view)
	var scroll := view._visit_body.get_parent()
	if scroll is ScrollContainer:
		var y := 0
		if face != null:
			y = int(face.position.y)
		elif echo != null:
			y = int(echo.position.y)
		scroll.scroll_vertical = maxi(0, y - 16)
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("SHOT skipped " + path)
		return
	await RenderingServer.frame_post_draw
	var tex := view.get_viewport().get_texture()
	if tex == null:
		print("SHOT miss " + path)
		return
	var img := tex.get_image()
	if img == null:
		print("SHOT empty " + path)
		return
	DirAccess.make_dir_recursive_absolute(SHOTS)
	var err := img.save_png(path)
	print("SHOT %s %dx%d err %s" % [path, img.get_width(), img.get_height(), err])


func _echo(view: NetworkView) -> Label:
	var node := _meta(view._visit_body, "echo_line")
	return node as Label


func _face(view: NetworkView) -> Control:
	return _meta(view._visit_body, "face_row") as Control


func _faces(view: NetworkView) -> int:
	return _count_meta(view._visit_body, "face_row")


func _echoes(view: NetworkView) -> int:
	return _count_meta(view._visit_body, "echo_line")


func _count_meta(node: Node, key: String) -> int:
	var n := 0
	if node is Control and node.has_meta(key):
		n += 1
	for child in node.get_children():
		n += _count_meta(child, key)
	return n


func _meta(node: Node, key: String) -> Node:
	if node is Control and node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _meta(child, key)
		if found != null:
			return found
	return null


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		LineEcho.enabled = true
		var on := _play(catalog, run_seed)
		LineEcho.enabled = false
		var off := _play(catalog, run_seed)
		if str(on.report) != str(off.report) or str(on.rng) != str(off.rng) or int(on.hash) != int(off.hash):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		if int(off.echoes) != 0:
			_bad("seed %d off wrote echoes" % run_seed)
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
	LineEcho.enabled = true
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
	var report: Dictionary = game.report()
	var n := 0
	if game.echoes is Dictionary:
		n = game.echoes.size()
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"report": str(report.get("summary", "")),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
		"echoes": n,
	}


func _outcome_hash(game: Game) -> int:
	var ids: Array = game.stations.keys()
	ids.sort()
	var held := PackedStringArray()
	for id in ids:
		var st: Dictionary = game.stations[id]
		if str(st.owner) != str(game.player):
			continue
		held.append("%s:%s:%s" % [str(id), str(st.get("held_weeks", 0)), str(st.get("focus", ""))])
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
