extends SceneTree

## P92 Rival Desk gate.
##   godot --headless --path . -s res://sim/check_rival_desk.gd
## Balance ZERO. Soft dawn none. Map mark none. Schema 23. Schema 22 stays reserved.

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
const KEYS := ["rival.title", "rival.bought", "rival.marched", "rival.held", "rival.preached", "rival.took", "rival.quiet", "rival.first", "rival.tip"]
const EN := {
	"rival.title": "Rivals",
	"rival.bought": "Bought goodwill at {station} (week {n}).",
	"rival.marched": "Marched on {station} (week {n}).",
	"rival.held": "Held {station} (week {n}).",
	"rival.preached": "Preached at {station} (week {n}).",
	"rival.took": "Took {station} (week {n}).",
	"rival.quiet": "No word yet.",
	"rival.first": "You started keeping their moves.",
	"rival.tip": "The last thing each faction did, before it faded off the map.",
}
const RU := {
	"rival.title": "Чужие",
	"rival.bought": "Купили расположение на {station} (неделя {n}).",
	"rival.marched": "Выступили на {station} (неделя {n}).",
	"rival.held": "Удержали {station} (неделя {n}).",
	"rival.preached": "Проповедовали на {station} (неделя {n}).",
	"rival.took": "Взяли {station} (неделя {n}).",
	"rival.quiet": "Пока тихо.",
	"rival.first": "Их ходы теперь в журнале.",
	"rival.tip": "Последнее, что сделала каждая сторона, пока это не стёрлось с карты.",
}

var _failed := false


class Host extends Node:
	var game
	var showing_network := true
	var network_view = null
	var body_font: Font
	var display_font: Font
	func _motion_off() -> bool:
		return true
	func _ui_click() -> void:
		pass
	func _close_observer() -> void:
		pass
	func _toggle_network() -> void:
		showing_network = true


class Sink extends Node:
	var opened := ""
	func open_visit(sid: String) -> void:
		opened = sid


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	RivalDesk.enabled = true
	RivalDesk.pending_id = 0
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("RIVAL DESK FAIL catalog")
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
		print("RIVAL DESK FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("RIVAL DESK FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("RIVAL DESK FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	RivalDesk.enabled = true
	print("RIVAL DESK OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 12)
	game.week = 8
	RivalDesk.pending_id = 0
	return game


func _wipe(game: Game) -> void:
	game.rival_log = {}
	game.flags.erase(RivalDesk.SEEN)
	RivalDesk.pending_id = 0


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/rival_desk.json"))
	var frag = JSON.parse_string(FileAccess.get_file_as_string("res://data/rival_desk_ru_fragment.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P92":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 9 or not (frag is Dictionary) or frag.size() != 9:
		_bad("key count %s / %s" % [rows.size(), frag.size() if frag is Dictionary else "bad"])
		return false
	for key in KEYS:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) != str(EN[key]) or str(row.get("ru", "")) != str(RU[key]):
			_bad("copy drift " + key)
			return false
		if str(row.get("ru", "")) != str(frag.get(key, "")):
			_bad("ru drift " + key)
			return false
		if str(row.en).find("!") >= 0 or str(row.ru).find("!") >= 0:
			_bad("exclamation " + key)
			return false
	for key in rows:
		if not str(key).begins_with("rival."):
			_bad("namespace " + str(key))
			return false
	if rows.has("rival.exchange") or rows.has("rival.directorate") or rows.has("rival.synod"):
		_bad("invented faction short key")
		return false
	Copy.set_lang("ru")
	if Copy.t("rival.title") != "Чужие" or Copy.t("rival.quiet") != "Пока тихо." or Copy.t("rival.first") != "Их ходы теперь в журнале.":
		_bad("ru lookup")
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	if Copy.t("rival.title") != "Rivals" or Copy.t("rival.tip") != str(EN["rival.tip"]):
		_bad("en lookup")
		return false
	return true


func _rules(catalog: Catalog) -> bool:
	if RivalDesk.dawn_chip() or RivalDesk.map_mark() or RivalDesk.joins_soft_dawn():
		_bad("RD-U6 dawn or mark")
		return false
	var game := _fresh(catalog)
	if game.rival_desk_dawn_chip() or game.dawn_soft_stack().has("rival"):
		_bad("RD-U6 game dawn")
		return false
	var capital := str(catalog.factions.exchange.capital)
	_wipe(game)
	game.stations.plaza.owner = "neutral"
	game.stations.plaza.rival_symp.exchange = 0
	game._resolve_intent({"faction": "exchange", "kind": "buy", "station": "plaza", "hidden": false})
	var bought: Dictionary = game.rival_log.get("exchange", {})
	if str(bought.get("kind", "")) != "bought" or str(bought.get("target", "")) != "plaza":
		_bad("buy log %s" % str(bought))
		return false
	if str(bought.get("target", "")) == capital:
		_bad("buy opened the capital")
		return false
	if int(bought.get("week", 0)) != 8:
		_bad("buy week")
		return false
	_wipe(game)
	game._resolve_intent({"faction": "exchange", "kind": "buy", "station": "plaza", "hidden": true})
	if not game.rival_log.is_empty():
		_bad("hidden buy was logged")
		return false
	_wipe(game)
	game._resolve_intent({"faction": "exchange", "kind": "secure", "hidden": false})
	if game.rival_log.has("exchange"):
		_bad("secure was logged")
		return false
	_wipe(game)
	game._resolve_intent({"faction": "exchange", "kind": "demand_posted", "hidden": false})
	if game.rival_log.has("exchange"):
		_bad("demand was logged")
		return false
	_wipe(game)
	game._resolve_intent({"faction": "exchange", "kind": "hold", "hidden": false})
	var held: Dictionary = game.rival_log.get("exchange", {})
	var stood := str(game.squads.exchange.get("station", ""))
	if str(held.get("kind", "")) != "held" or str(held.get("target", "")) != stood:
		_bad("hold log %s stood %s" % [str(held), stood])
		return false
	_wipe(game)
	RivalDesk.note_chip(game, "directorate", "map.chip.marched_faction", "mill")
	RivalDesk.note_chip(game, "directorate", "map.chip.marched_back", "mill")
	if str(game.rival_log.directorate.get("kind", "")) != "marched" or str(game.rival_log.directorate.get("target", "")) != "mill":
		_bad("marched chip")
		return false
	RivalDesk.note_chip(game, "synod", "map.chip.preached", "chapel")
	if str(game.rival_log.synod.get("kind", "")) != "preached":
		_bad("preached chip")
		return false
	for chip in ["map.chip.secured", "map.chip.demanded", "map.chip.bought_fail"]:
		if chip != "map.chip.bought_fail" and RivalDesk.kind_of_chip(chip) != "":
			_bad("untexted chip mapped " + chip)
			return false
	if RivalDesk.kind_of_chip("map.chip.bought_fail") != "bought":
		_bad("bought_fail")
		return false
	_wipe(game)
	RivalDesk.note(game, "exchange", "secure", "plaza")
	RivalDesk.note(game, "exchange", "demand_posted", "plaza")
	RivalDesk.note(game, "depot", "bought", "plaza")
	RivalDesk.note(game, game.player, "took", "plaza")
	if not game.rival_log.is_empty():
		_bad("player or untexted kind logged")
		return false
	game.week = 8
	game.stations.plaza.owner = "neutral"
	game.stations.plaza.low_weeks = 2
	if not game._capture("plaza", "exchange", true):
		_bad("capture did not land")
		return false
	if str(game.rival_log.exchange.get("kind", "")) != "took" or str(game.rival_log.exchange.get("target", "")) != "plaza":
		_bad("took %s" % str(game.rival_log.get("exchange", {})))
		return false
	if str(game.rival_log.exchange.get("target", "")) == capital:
		_bad("took rewrote the capital")
		return false
	RivalDesk.note_chip(game, "exchange", "map.chip.bought", "mill")
	if str(game.rival_log.exchange.get("kind", "")) != "took":
		_bad("chip overwrote took")
		return false
	game.week = 9
	RivalDesk.note_chip(game, "exchange", "map.chip.held", "mill")
	if str(game.rival_log.exchange.get("kind", "")) != "held" or str(game.rival_log.exchange.get("target", "")) != "mill":
		_bad("later week did not replace took")
		return false
	_wipe(game)
	var before := game.map_playback.size()
	game._synod_preach()
	if game.map_playback.size() != before:
		_bad("preach queued a hop")
		return false
	var syn: Dictionary = game.rival_log.get("synod", {})
	if not ["preached", "took"].has(str(syn.get("kind", ""))):
		_bad("synod preach %s" % str(syn))
		return false
	if str(syn.get("target", "")) == "" or str(syn.get("target", "")) == str(catalog.factions.synod.capital):
		_bad("synod target %s" % str(syn.get("target", "")))
		return false
	if game.rival_log.has("depot") or game.rival_log.has(game.player):
		_bad("player row")
		return false
	var rows: Array = RivalDesk.rows(game)
	if rows.size() != 3:
		_bad("RD-U1 count")
		return false
	var order := PackedStringArray()
	for row in rows:
		order.append(str(row.get("fid", "")))
		if _digits_besides(str(row.get("line", "")), int(game.rival_log.get(row.get("fid", ""), {}).get("week", 0))):
			_bad("RD-U5 " + str(row.get("line", "")))
			return false
	if ",".join(order) != "exchange,directorate,synod":
		_bad("RD-U1 order " + ",".join(order))
		return false
	_wipe(game)
	rows = RivalDesk.rows(game)
	for row in rows:
		if not bool(row.get("quiet", false)) or str(row.get("text", "")) != Copy.t("rival.quiet") or bool(row.get("clickable", false)):
			_bad("RD-U2 quiet")
			return false
	var line := RivalDesk.claim(game)
	if line != "":
		_bad("float before a write")
		return false
	RivalDesk.note(game, "directorate", "marched", "mill")
	if not bool(game.flags.get(RivalDesk.SEEN, false)):
		_bad("seen flag")
		return false
	line = RivalDesk.claim(game)
	if line != Copy.t("rival.first") or RivalDesk.claim(game) != "":
		_bad("RD-U7 first float once")
		return false
	RivalDesk.note(game, "directorate", "held", "mill")
	if RivalDesk.claim(game) != "":
		_bad("second write refloated")
		return false
	RivalDesk.enabled = false
	var off := _fresh(catalog)
	RivalDesk.note(off, "exchange", "bought", "plaza")
	off._resolve_intent({"faction": "exchange", "kind": "hold", "hidden": false})
	if not off.rival_log.is_empty() or bool(off.flags.get(RivalDesk.SEEN, false)):
		_bad("disabled still wrote")
		RivalDesk.enabled = true
		return false
	RivalDesk.enabled = true
	return true


func _digits_besides(line: String, week: int) -> bool:
	var stripped := line.replace(str(week), "")
	for i in stripped.length():
		var code := stripped.unicode_at(i)
		if code >= 48 and code <= 57:
			return true
	if line.find("+") >= 0 or line.to_lower().find("garrison") >= 0 or line.to_lower().find("opinion") >= 0:
		return true
	return false


func _save(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	RivalDesk.note(game, "exchange", "bought", "plaza")
	RivalDesk.claim(game)
	var data := game.export_state()
	data["schema"] = 23
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data):
		_bad("schema 23 load " + again.load_error)
		return false
	if str(again.rival_log.exchange.get("kind", "")) != "bought" or str(again.rival_log.exchange.get("target", "")) != "plaza":
		_bad("round trip")
		return false
	if not bool(again.flags.get(RivalDesk.SEEN, false)) or RivalDesk.claim(again) != "":
		_bad("seen flag did not survive save")
		return false
	data.erase("rival_log")
	var bare := Game.new()
	bare.catalog = catalog
	if bare.import_state(data):
		_bad("schema 23 accepted a save with no rival_log")
		return false
	var old := game.export_state()
	old.erase("rival_log")
	old["schema"] = 21
	var migrated := Game.new()
	migrated.catalog = catalog
	if not migrated.import_state(old):
		_bad("schema 21 load " + migrated.load_error)
		return false
	if not migrated.rival_log.is_empty():
		_bad("schema 21 kept a log")
		return false
	if migrated.carry.is_empty() and game.carry.is_empty():
		pass
	var no_carry := game.export_state()
	no_carry.erase("carry")
	no_carry.erase("rival_log")
	no_carry["schema"] = 21
	var refused := Game.new()
	refused.catalog = catalog
	if refused.import_state(no_carry):
		_bad("schema 21 accepted a save with no carry")
		return false
	var days := game.export_state()
	days.erase("sdays")
	days.erase("rival_log")
	days["schema"] = 19
	var day_load := Game.new()
	day_load.catalog = catalog
	if not day_load.import_state(days):
		_bad("schema 19 load " + day_load.load_error)
		return false
	if not day_load.sdays.get("kept", {}).is_empty() or not day_load.rival_log.is_empty():
		_bad("schema 19 kept days or a log")
		return false
	var day_need := game.export_state()
	day_need.erase("sdays")
	day_need["schema"] = 20
	var day_no := Game.new()
	day_no.catalog = catalog
	if day_no.import_state(day_need):
		_bad("schema 20 accepted a save with no sdays")
		return false
	var carry_old := game.export_state()
	carry_old.erase("carry")
	carry_old.erase("rival_log")
	carry_old["schema"] = 20
	var carry_load := Game.new()
	carry_load.catalog = catalog
	if not carry_load.import_state(carry_old):
		_bad("schema 20 load " + carry_load.load_error)
		return false
	if not carry_load.carry.pocket.is_empty() or not carry_load.rival_log.is_empty():
		_bad("schema 20 kept a note or a log")
		return false
	var heard := {"plaza": {"kind": "deal", "from": "mill", "week": 8}}
	game.echoes = heard.duplicate(true)
	game.sdays.kept = {"plaza": [8]}
	game.carry.pocket = {"thread": "lamp_copper", "leg": 1, "opened": false, "week": 8}
	var full := game.export_state()
	full["schema"] = 23
	var round := Game.new()
	round.catalog = catalog
	if not round.import_state(full):
		_bad("schema 23 round trip " + round.load_error)
		return false
	if str(round.rival_log.exchange.get("kind", "")) != "bought" or str(round.echoes.plaza.get("kind", "")) != "deal":
		_bad("schema 23 dropped rival_log or echoes")
		return false
	if str(round.carry.pocket.get("thread", "")) != "lamp_copper" or round.sdays.kept.get("plaza", []) != [8]:
		_bad("schema 23 dropped carry or sdays")
		return false
	var no_echo := full.duplicate(true)
	no_echo.erase("echoes")
	var missing_echo := Game.new()
	missing_echo.catalog = catalog
	if missing_echo.import_state(no_echo):
		_bad("schema 23 accepted a save with no echoes")
		return false
	var echo22 := full.duplicate(true)
	echo22.erase("rival_log")
	echo22["schema"] = 22
	var kept := Game.new()
	kept.catalog = catalog
	if not kept.import_state(echo22):
		_bad("schema 22 load " + kept.load_error)
		return false
	if str(kept.echoes.plaza.get("kind", "")) != "deal" or str(kept.echoes.plaza.get("from", "")) != "mill":
		_bad("schema 22 lost echoes")
		return false
	if not kept.rival_log.is_empty():
		_bad("schema 22 invented a log")
		return false
	if str(kept.carry.pocket.get("thread", "")) != "lamp_copper":
		_bad("schema 22 lost carry")
		return false
	echo22.erase("echoes")
	var bare22 := Game.new()
	bare22.catalog = catalog
	if bare22.import_state(echo22):
		_bad("schema 22 accepted a save with no echoes")
		return false
	var s21 := full.duplicate(true)
	s21.erase("echoes")
	s21.erase("rival_log")
	s21["schema"] = 21
	var mig21 := Game.new()
	mig21.catalog = catalog
	if not mig21.import_state(s21):
		_bad("schema 21 migrate " + mig21.load_error)
		return false
	if not mig21.echoes.is_empty() or not mig21.rival_log.is_empty():
		_bad("schema 21 kept a newer key")
		return false
	if str(mig21.carry.pocket.get("thread", "")) != "lamp_copper" or mig21.sdays.kept.get("plaza", []) != [8]:
		_bad("schema 21 lost carry or sdays")
		return false
	var s20 := full.duplicate(true)
	s20.erase("carry")
	s20.erase("echoes")
	s20.erase("rival_log")
	s20["schema"] = 20
	var mig20 := Game.new()
	mig20.catalog = catalog
	if not mig20.import_state(s20):
		_bad("schema 20 migrate " + mig20.load_error)
		return false
	if not mig20.carry.pocket.is_empty() or not mig20.echoes.is_empty() or not mig20.rival_log.is_empty():
		_bad("schema 20 invented a newer key")
		return false
	if mig20.sdays.kept.get("plaza", []) != [8]:
		_bad("schema 20 lost sdays")
		return false
	var kept20 := s20.duplicate(true)
	kept20["echoes"] = heard.duplicate(true)
	var old_new := Game.new()
	old_new.catalog = catalog
	if not old_new.import_state(kept20) or str(old_new.echoes.plaza.get("kind", "")) != "deal":
		_bad("schema 20 dropped a newer key that was present")
		return false
	var bad_type := game.export_state()
	bad_type["rival_log"] = []
	bad_type["schema"] = 23
	var typed := Game.new()
	typed.catalog = catalog
	if typed.import_state(bad_type):
		_bad("schema 23 accepted a list")
		return false
	var future := game.export_state()
	future["schema"] = 28
	var ahead := Game.new()
	ahead.catalog = catalog
	if ahead.import_state(future):
		_bad("schema 28 loaded")
		return false
	return true


func _bounds() -> bool:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 27") < 0 or src.find("V19_ADDED") < 0 or src.find("V20_ADDED") < 0 or src.find("V21_ADDED") < 0 or src.find("V22_ADDED") < 0 or src.find("V23_ADDED") < 0:
		_bad("schema source")
		return false
	if src.find("const SAVE_SCHEMA := 22") >= 0 or src.find("const SAVE_SCHEMA := 23") >= 0:
		_bad("schema stopped early")
		return false
	var persist_at := src.find("\"transfer_hub_sids\"")
	var persist := src.substr(persist_at, 220) if persist_at >= 0 else ""
	if persist.find("echoes") < 0 or persist.find("rival_log") < 0 or persist.find("carry") < 0 or persist.find("sdays") < 0 or persist.find("callers") < 0:
		_bad("persist list")
		return false
	if src.find("<= 21 and V21_ADDED") < 0 or src.find("<= 22 and V22_ADDED") < 0 or src.find("<= 23 and V23_ADDED") < 0 or src.find("<= 20 and V20_ADDED") < 0:
		_bad("migration chain")
		return false
	if src.find("\"sdays\"") < 0 or src.find("\"carry\"") < 0 or src.find("\"rival_log\"") < 0:
		_bad("persist chain")
		return false
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("rival") >= 0 or picker.find("RivalDesk") >= 0:
		_bad("dawn picker knows the desk")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _fn(view, "_draw_pin")
	if pin.find("RivalDesk") >= 0 or pin.find("rival.") >= 0:
		_bad("map pin knows the desk")
		return false
	for draw_name in ["_draw_pins", "_draw_soft_marks", "_draw_ink"]:
		var body := _fn(view, draw_name)
		if body.find("RivalDesk") >= 0 or body.find("rival_log") >= 0:
			_bad(draw_name + " draws a rival mark")
			return false
	if FileAccess.get_file_as_string("res://sim/bot.gd").find("RivalDesk") >= 0 or FileAccess.get_file_as_string("res://sim/bot.gd").find("rival_log") >= 0:
		_bad("bot reads the desk")
		return false
	var logic := FileAccess.get_file_as_string("res://sim/rival_desk.gd")
	for token in ["stock.", "hope ", "discontent", "opinions[", "loyalty", "rng.", "net_rng", "balance.json", "kept_bonus", "closed_bonus"]:
		if logic.find(token) >= 0:
			_bad("desk touches " + token)
			return false
	var panel := FileAccess.get_file_as_string("res://ui/observer_panel.gd")
	if panel.find("520") >= 0:
		_bad("hard 520")
		return false
	if panel.find("kept_bonus") >= 0 or panel.find("closed_bonus") >= 0:
		_bad("bonus wired in the panel")
		return false
	var yard := _fn(FileAccess.get_file_as_string("res://ui/station.gd"), "_show_rival_yard")
	if yard.find("_tip_plate_style") < 0 or yard.find("outline_size\", 0") < 0 or yard.find("_place_yard_notice") < 0 or yard.find("_restack_yard_notices") < 0:
		_bad("yard float plate")
		return false
	if yard.find("custom_minimum_size = Vector2(420, 36)") >= 0 or yard.find("size = Vector2(420, 36)") >= 0:
		_bad("yard plate sizes before the line has a width")
		return false
	var map_fn := _fn(view, "_show_rival_float")
	if map_fn.find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	if FileAccess.get_file_as_string("res://data/balance.json").find("rival_log") >= 0:
		_bad("balance mentions the desk")
		return false
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.find("\nfunc ", at + 4)
	if next < 0:
		next = src.length()
	return src.substr(at, next - at)


func _ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	for sid in ["brickworks", "plaza", "observatory"]:
		game.stations[sid].known = true
		game.stations[sid].sympathy = 40
		game.stations[sid].owner = "neutral"
		PlatformFaces.meet(game, sid)
	_wipe(game)
	RivalDesk.note(game, "exchange", "bought", "plaza")
	RivalDesk.note(game, "synod", "preached", "observatory")
	RivalDesk.claim(game)
	var host := Host.new()
	host.game = game
	var sink := Sink.new()
	host.network_view = sink
	root.add_child(host)
	var panel := ObserverPanel.new()
	host.add_child(panel)
	Copy.set_lang("en")
	root.size = Vector2i(1920, 1080)
	panel.present(host)
	await process_frame
	await process_frame
	if not (panel._main is HBoxContainer):
		_bad("horizontal chrome")
		return false
	if not _order(panel):
		return false
	var listed := _metas(panel, "rival_row")
	if listed.size() != 3:
		_bad("RD-U1 rows %d" % listed.size())
		return false
	var want := ["exchange", "directorate", "synod"]
	for i in 3:
		if str(listed[i].get_meta("rival_fid")) != want[i]:
			_bad("RD-U1 fid")
			return false
	if str(listed[0].text) != "Exchange · Bought goodwill at Union Sq (week 8).":
		_bad("EN line " + str(listed[0].text))
		return false
	if str(listed[1].text) != "Directorate · No word yet." or not bool(listed[1].get_meta("rival_quiet")):
		_bad("RD-U2 " + str(listed[1].text))
		return false
	if listed[1] is Button or listed[1].mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		_bad("RD-U3 quiet affordance")
		return false
	if str(listed[1].get_meta("obs_focus", "")) != "" or listed[1].focus_mode != Control.FOCUS_NONE:
		_bad("RD-U3 quiet focus")
		return false
	if not (listed[0] is Button) or listed[0].mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_bad("RD-U3 cursor")
		return false
	var hover: StyleBoxFlat = listed[0].get_theme_stylebox("hover")
	var focus: StyleBoxFlat = listed[0].get_theme_stylebox("focus")
	if hover == null or focus == null or hover.get_border_width(SIDE_LEFT) != 1 or focus.get_border_width(SIDE_LEFT) != 1:
		_bad("RD-N brass")
		return false
	if listed[0].tooltip_text != Copy.t("rival.tip") or _meta(panel, "rival_fold").tooltip_text != Copy.t("rival.tip"):
		_bad("tip")
		return false
	if int(listed[0].get_theme_font_size("font_size")) != 14:
		_bad("font shrink")
		return false
	listed[0].pressed.emit()
	await process_frame
	if sink.opened != "plaza":
		_bad("RD-U3 visit %s" % sink.opened)
		return false
	var synod_capital := str(catalog.factions.synod.capital)
	sink.opened = ""
	panel.present(host)
	await process_frame
	listed = _metas(panel, "rival_row")
	listed[2].pressed.emit()
	await process_frame
	if sink.opened != "observatory" or sink.opened == synod_capital:
		_bad("RD-U3 synod visit %s" % sink.opened)
		return false
	if not await _floats(game):
		return false
	if not await _fits(catalog):
		return false
	panel.queue_free()
	host.queue_free()
	return true


func _order(panel: ObserverPanel) -> bool:
	var names := PackedStringArray()
	_collect_folds(panel, names)
	var want := ["kit_fold", "pocket_fold", "face_fold", "rival_fold", "sday_count"]
	var at := 0
	for name in names:
		if at < want.size() and name == want[at]:
			at += 1
	if at != want.size():
		_bad("RD-U4 order %s" % ",".join(names))
		return false
	var rival := _meta(panel, "rival_row")
	if rival == null or str(rival.get_meta("obs_focus", "")) != "rival":
		_bad("RD-U4 focus")
		return false
	return true


func _collect_folds(node: Node, names: PackedStringArray) -> void:
	for key in ["kit_fold", "pocket_fold", "face_fold", "rival_fold", "sday_count"]:
		if node is Control and node.has_meta(key):
			names.append(key)
	for child in node.get_children():
		_collect_folds(child, names)


func _floats(game: Game) -> bool:
	var host := Host.new()
	host.game = game
	host.showing_network = true
	root.add_child(host)
	var view := NetworkView.new()
	host.network_view = view
	view.host = host
	view.size = Vector2(1280, 720)
	view.visible = true
	root.add_child(view)
	await process_frame
	_wipe(game)
	RivalDesk.note(game, "exchange", "marched", "mill")
	var line := ""
	if RivalDesk.has_pending(game):
		line = RivalDesk.claim(game)
	if line != Copy.t("rival.first"):
		_bad("pending float")
		return false
	view._show_rival_float(line)
	await process_frame
	var plate := _meta(view, "rival_float")
	if plate == null or str(plate.text) != Copy.t("rival.first"):
		_bad("CN1 map float")
		return false
	if int(plate.get_theme_constant("outline_size")) != 0:
		_bad("CN1 outline")
		return false
	var parent := plate.get_parent()
	if parent == null or not bool(parent.get_meta("map_float_plate", false)):
		_bad("CN1 plate")
		return false
	view.queue_free()
	host.queue_free()
	return true


func _fits(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	for sid in ["brickworks", "plaza", "observatory"]:
		game.stations[sid].known = true
		game.stations[sid].owner = "neutral"
		PlatformFaces.meet(game, sid)
	RivalDesk.note(game, "exchange", "bought", "plaza")
	RivalDesk.note(game, "directorate", "marched", "brickworks")
	RivalDesk.note(game, "synod", "took", "observatory")
	RivalDesk.claim(game)
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var panel := ObserverPanel.new()
	host.add_child(panel)
	for case in [["en", Vector2i(1920, 1080)], ["ru", Vector2i(1920, 1080)], ["en", Vector2i(1536, 864)], ["ru", Vector2i(1536, 864)], ["en", Vector2i(1280, 720)]]:
		Copy.set_lang(str(case[0]))
		var sz: Vector2i = case[1]
		DisplayServer.window_set_size(sz)
		root.size = sz
		await process_frame
		panel.present(host)
		await process_frame
		await process_frame
		if absf(panel.size.y - 520.0) < 0.5:
			_bad("RD-U7 height 520")
			Copy.set_lang("en")
			return false
		var scroll := _meta(panel, "obs_tail_scroll") as ScrollContainer
		if scroll == null:
			_bad("RD-U7 scroll")
			Copy.set_lang("en")
			return false
		if absf(scroll.custom_minimum_size.y - 520.0) < 0.5:
			_bad("RD-U7 scroll 520")
			Copy.set_lang("en")
			return false
		var grab: StyleBoxFlat = scroll.theme.get_stylebox("grabber", "VScrollBar") as StyleBoxFlat
		if grab == null or grab.bg_color.r < 0.4:
			_bad("RD-U7 brass")
			Copy.set_lang("en")
			return false
		var vp := Rect2(Vector2.ZERO, Vector2(sz))
		var desk := panel.get_global_rect()
		if not vp.grow(2.0).encloses(desk):
			_bad("RD-U7 panel %s %s" % [case[0], desk])
			Copy.set_lang("en")
			return false
		var bar := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(bar.max_value) if bar != null else 0
		await process_frame
		await process_frame
		var close := _focus_bucket(panel, "close")
		if close == null:
			_bad("RD-U7 close")
			Copy.set_lang("en")
			return false
		var crect := close.get_global_rect()
		var srect := scroll.get_global_rect()
		if crect.size.y < 8.0 or not vp.grow(2.0).encloses(crect) or not srect.grow(4.0).encloses(crect):
			_bad("RD-U7 close unreachable %s %s scroll %s" % [case[0], crect, srect])
			Copy.set_lang("en")
			return false
		for row in _metas(panel, "rival_row"):
			var ctrl := row as Control
			if ctrl.clip_text:
				_bad("RD-U7 clip")
				Copy.set_lang("en")
				return false
			var rect := ctrl.get_global_rect()
			if rect.size.x < 280.0 or rect.size.y > 96.0 or rect.size.x < rect.size.y * 4.0:
				_bad("letter stack %s %s %s" % [case[0], ctrl.text, rect.size])
				Copy.set_lang("en")
				return false
			if ctrl is Button and ctrl.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
				_bad("wrap mode")
				Copy.set_lang("en")
				return false
		if str(case[0]) == "ru":
			var ru_rows := _metas(panel, "rival_row")
			if str(ru_rows[0].text) != "Биржа · Купили расположение на Юнион-сквер (неделя 8).":
				_bad("RU line " + str(ru_rows[0].text))
				Copy.set_lang("en")
				return false
			if str(ru_rows[1].text).find("Дирекция") < 0 or str(ru_rows[2].text).find("Синод") < 0:
				_bad("RU shorts")
				Copy.set_lang("en")
				return false
			if str(ru_rows[0].text).find("Управление") >= 0 or str(ru_rows[1].text).find("Директорат") >= 0:
				_bad("banned short")
				Copy.set_lang("en")
				return false
	Copy.set_lang("en")
	panel.queue_free()
	host.queue_free()
	return true


func _focus_bucket(node: Node, bucket: String) -> Control:
	if node is Control and str(node.get_meta("obs_focus", "")) == bucket:
		return node
	for child in node.get_children():
		var found := _focus_bucket(child, bucket)
		if found != null:
			return found
	return null


func _meta(node: Node, key: String) -> Node:
	if node is Control and node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _meta(child, key)
		if found != null:
			return found
	return null


func _metas(node: Node, key: String) -> Array:
	var out: Array = []
	_gather(node, key, out)
	return out


func _gather(node: Node, key: String, out: Array) -> void:
	if node is Control and node.has_meta(key):
		out.append(node)
	for child in node.get_children():
		_gather(child, key, out)


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		RivalDesk.enabled = true
		RivalDesk.pending_id = 0
		var on := _play(catalog, run_seed)
		RivalDesk.enabled = false
		RivalDesk.pending_id = 0
		var off := _play(catalog, run_seed)
		if str(on.report) != str(off.report) or str(on.rng) != str(off.rng):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		if int(off.rows) != 0:
			_bad("seed %d logged while off" % run_seed)
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
	RivalDesk.enabled = true
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
	var rows := 0
	if game.rival_log is Dictionary:
		rows = game.rival_log.size()
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"report": str(report.get("summary", "")),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
		"rows": rows,
	}


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
