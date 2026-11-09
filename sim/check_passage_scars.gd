extends SceneTree

const Scars = preload("res://sim/passage_scars.gd")
const Toll = preload("res://sim/quiet_toll.gd")
const Night = preload("res://sim/night_runs.gd")

## P94 Passage Scars gate.
##   godot --headless --path . -s res://sim/check_passage_scars.gd
##   UNDERLINE_SCARS_SHOTS=/tmp/scars godot --rendering-driver opengl3 --path . -s res://sim/check_passage_scars.gd
## PS-U1..U8. Schema 25. Careful seeds 1–60 match with the pack on and off.
## Headless runs skip screenshots and do not claim the visual gate. A real renderer
## writes PNGs to UNDERLINE_SCARS_SHOTS, UNDERLINE_SHOTS_DIR, or --shots-dir=.

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
const KEYS := ["scar.raid", "scar.raid_n", "scar.night", "scar.night_n", "scar.first", "scar.tip"]
const EN := {
	"scar.raid": "This stretch remembers a raid (week {n}).",
	"scar.raid_n": "This stretch remembers raids ({count}; last week {n}).",
	"scar.night": "Someone did not come back along here (week {n}).",
	"scar.night_n": "People have not come back along here ({count}; last week {n}).",
	"scar.first": "The passage kept a mark.",
	"scar.tip": "Owned tunnels remember violence.",
}
const RU := {
	"scar.raid": "Этот перегон помнит рейд (неделя {n}).",
	"scar.raid_n": "Этот перегон помнит рейды ({count}; последний — неделя {n}).",
	"scar.night": "Кто-то здесь не вернулся (неделя {n}).",
	"scar.night_n": "Здесь не возвращались ({count}; последний — неделя {n}).",
	"scar.first": "Проход сохранил отметину.",
	"scar.tip": "Свои тоннели помнят насилие.",
}
var _shots_skipped := false
var _shots_saved := 0


class Host extends Node:
	var game
	var shot_mode := true
	var motion_in_shots := false

	func _ui_click() -> void:
		pass


var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	Scars.enabled = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("SCARS FAIL catalog")
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
	if not _hooks():
		_failed = true
	else:
		print("Hooks: ok")
	if not await _ui(catalog):
		_failed = true
	else:
		print("UI: ok")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if _failed:
		print("SCARS FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("SCARS FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("SCARS FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	Scars.enabled = true
	if _shots_skipped:
		print("SCARS SHOTS SKIP no renderer")
	elif _shots_saved > 0:
		print("SCARS SHOTS %d %s" % [_shots_saved, _shot_dir()])
	print("SCARS OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/passage_scars.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P94":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != KEYS.size():
		_bad("key count %d" % rows.size())
		return false
	var frag = JSON.parse_string(FileAccess.get_file_as_string("res://data/passage_scars_ru_fragment.json"))
	if not (frag is Dictionary) or frag.size() != KEYS.size():
		_bad("ru fragment")
		return false
	for key in KEYS:
		if not rows.has(key) or not str(key).begins_with("scar."):
			_bad("namespace " + key)
			return false
		if str(rows[key].get("en", "")) != str(EN[key]) or str(rows[key].get("ru", "")) != str(RU[key]):
			_bad("copy " + key)
			return false
		if str(frag.get(key, "")) != str(RU[key]):
			_bad("fragment " + key)
			return false
		if Copy.t(key) != str(EN[key]):
			_bad("Copy.t " + key)
			return false
	Copy.set_lang("ru")
	for key in KEYS:
		if Copy.t(key) != str(RU[key]):
			_bad("ru Copy.t " + key)
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	var src := FileAccess.get_file_as_string("res://sim/copy.gd")
	if src.find("res://data/passage_scars.json") < 0:
		_bad("copy pack not merged")
		return false
	return true


func _fresh(catalog: Catalog, run_seed := 4) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.week = 6
	game.scars = {}
	game.flags.erase(Scars.FLAG)
	return game


func _rules(catalog: Catalog) -> bool:
	if Scars.dawn_chip() or Scars.map_mark() or Scars.joins_soft_dawn():
		_bad("flags")
		return false
	if not Scars.night_armed():
		_bad("P74 night trigger should be live on this master")
		return false
	var game := _fresh(catalog)
	if game.passage_scars_dawn_chip() or str(game.dawn_soft_chip().get("kind", "")) == "scar":
		_bad("dawn chip")
		return false
	if not Scars.holds(game, str(game.capital_id)):
		_bad("capital is not player-held")
		return false
	var home := str(game.capital_id)
	var nbr := ""
	for n in game._neighbors(home):
		nbr = str(n)
		break
	if nbr == "":
		_bad("no capital neighbor")
		return false
	if Scars.edge_id(home, nbr) != Scars.edge_id(nbr, home) or Scars.edge_id(home, nbr) != Toll.edge_id(home, nbr):
		_bad("edge key drifted")
		return false
	var view := NetworkView.new()
	if view._edge_key(home, nbr) != Scars.edge_id(home, nbr):
		_bad("network edge key drifted")
		return false
	# PS-U1 foreign-only stays silent.
	var foreign := _foreign_pair(game)
	if str(foreign[0]) == "":
		_bad("no foreign pair")
		return false
	Scars.note_raid(game, str(foreign[0]))
	Scars.note_night(game, str(foreign[1]))
	if game.scars.has(Scars.edge_id(str(foreign[0]), str(foreign[1]))):
		_bad("foreign edge scarred")
		return false
	if Scars.edge_tip(game, str(foreign[0]), str(foreign[1])) != "" or Scars.visit_line(game, str(foreign[0])) != "":
		_bad("foreign tip or visit")
		return false
	# Owned edge: capital is player-held, so a raid on the neighbor scars that one passage.
	game.scars = {}
	game.week = 4
	Scars.note_raid(game, nbr)
	var edge := Scars.edge_id(home, nbr)
	if not game.scars.has(edge):
		_bad("owned edge missed the raid")
		return false
	var row: Dictionary = game.scars[edge]
	if str(row.get("kind", "")) != "raid" or int(row.get("week", 0)) != 4 or int(row.get("count", 0)) != 1:
		_bad("first raid record %s" % str(row))
		return false
	if Scars.line_of(row) != Copy.fill("scar.raid", {"n": "4"}):
		_bad("singular form " + Scars.line_of(row))
		return false
	if Scars.line_of(row).find("scar.raid_n") >= 0 or row.has("count") and int(row.count) == 1 and Scars.line_of(row).find("(1;") >= 0:
		_bad("count 1 used the plural")
		return false
	for key in game.scars:
		var bits := str(key).split("|")
		if str(bits[0]) != home and str(bits[1]) != home and str(bits[0]) != nbr and str(bits[1]) != nbr:
			_bad("scar off the endpoint " + str(key))
			return false
		if not Scars.holds(game, str(bits[0])) and not Scars.holds(game, str(bits[1])):
			_bad("unowned scar stored " + str(key))
			return false
	# Repeat: count increments, newest kind and week win.
	game.week = 9
	Scars.note_raid(game, nbr)
	row = game.scars[edge]
	if int(row.count) != 2 or int(row.week) != 9 or str(row.kind) != "raid":
		_bad("repeat raid %s" % str(row))
		return false
	if Scars.line_of(row) != Copy.fill("scar.raid_n", {"count": "2", "n": "9"}):
		_bad("plural raid " + Scars.line_of(row))
		return false
	game.week = 11
	Scars.note_night(game, home)
	row = game.scars[edge]
	if str(row.kind) != "night" or int(row.week) != 11 or int(row.count) != 3:
		_bad("latest kind %s" % str(row))
		return false
	if Scars.visit_line(game, home) != Scars.line_of(row) or Scars.visit_line(game, nbr) != Scars.line_of(row):
		_bad("visit missed an endpoint")
		return false
	if Scars.edge_tip(game, home, nbr).split("\n")[-1] != Scars.line_of(row):
		_bad("tip is not the scar line")
		return false
	# Most recent of two owned edges. Cap is applied by visit_row, not by dropping the older scar.
	var hub := home
	var spoke_a := nbr
	var spoke_b := ""
	for sid in game.stations:
		var ns: Array = game._neighbors(str(sid))
		if ns.size() < 2:
			continue
		hub = str(sid)
		if not Scars.holds(game, hub):
			game.stations[hub].owner = game.player
		spoke_a = str(ns[0])
		spoke_b = str(ns[1])
		break
	if spoke_b == "":
		_bad("no station with two passages")
		return false
	game.scars[Scars.edge_id(hub, spoke_a)] = {"kind": "raid", "week": 2, "count": 1}
	game.scars[Scars.edge_id(hub, spoke_b)] = {"kind": "night", "week": 15, "count": 2}
	var shown := Scars.visit_row(game, hub)
	if int(shown.get("week", 0)) != 15 or str(shown.get("kind", "")) != "night" or int(shown.get("count", 0)) != 2:
		_bad("visit did not keep the newest " + str(shown))
		return false
	if Scars.visit_line(game, hub) != Copy.fill("scar.night_n", {"count": "2", "n": "15"}):
		_bad("newest line " + Scars.visit_line(game, hub))
		return false
	if Scars.visit_line(game, str(foreign[0])) != "":
		_bad("foreign visit after owned scars")
		return false
	# First float once. Not a chip.
	var first := Scars.claim_first(game)
	if first != Copy.t("scar.first") or not bool(game.flags.get(Scars.FLAG, false)):
		_bad("first float " + first)
		return false
	if Scars.claim_first(game) != "":
		_bad("second float")
		return false
	game.flags.erase(Scars.FLAG)
	game.scars = {}
	if Scars.claim_first(game) != "":
		_bad("empty scars floated")
		return false
	Scars.enabled = false
	game.week = 3
	Scars.note_raid(game, nbr)
	Scars.note_night(game, nbr)
	if not game.scars.is_empty() or Scars.claim_first(game) != "" or Scars.edge_tip(game, home, nbr) != "":
		_bad("disabled pack wrote")
		return false
	Scars.enabled = true
	# Live player raid and assault, rival step, sortie, and a P74 death. Capture stays silent.
	if not _live_raid(catalog):
		return false
	if not _live_assault(catalog):
		return false
	if not _live_rival(catalog):
		return false
	if not _live_night(catalog):
		return false
	var body := FileAccess.get_file_as_string("res://sim/passage_scars.gd")
	if body.find("rand") >= 0 or body.find("balance.json") >= 0 or body.find("kept_bonus") >= 0 or body.find("closed_bonus") >= 0:
		_bad("pack touches rng, balance, or bonuses")
		return false
	if body.find("game.stock") >= 0 or body.find("game.hope") >= 0:
		_bad("pack touches meters")
		return false
	return true


func _arm(game: Game) -> String:
	var dest := ""
	var fallback := ""
	for sid in game._neighbors(game.capital_id):
		if fallback == "":
			fallback = str(sid)
		var owner := str(game.stations[str(sid)].get("owner", ""))
		if owner != game.player and owner != "neutral" and owner != "ruin" and owner != "bunker" and str(game.stations[str(sid)].get("bunker", "")) == "":
			dest = str(sid)
			break
	if dest == "":
		dest = fallback
		if dest != "" and game.stations.has(dest):
			game.stations[dest].owner = "directorate"
			game.stations[dest].bunker = ""
	if dest == "":
		return ""
	var st: Dictionary = game.stations[dest]
	st.known = true
	st.intel = 2
	st.garrison = 1
	st.fort = 0.2
	st.unrest = 0
	st.low_weeks = 2
	game.squads[game.player].gear = 40.0
	game.squads[game.player].size = maxi(int(game.squads[game.player].size), 8)
	game.stock.food = 40
	return dest


func _live_raid(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var dest := _arm(game)
	if dest == "" or game._raid_gate(dest) != "":
		_bad("raid setup " + game._raid_gate(dest))
		return false
	game.scars = {}
	game.week = 8
	if not game._order_raid(dest, true):
		_bad("raid did not resolve")
		return false
	var edge := Scars.edge_id(str(game.capital_id), dest)
	if not game.scars.has(edge) or str(game.scars[edge].get("kind", "")) != "raid":
		_bad("player raid left no scar")
		return false
	# A second order is often locked by the squad's return. The repeat path is note_raid.
	var count := int(game.scars[edge].count)
	game.week = 10
	Scars.note_raid(game, dest)
	if int(game.scars[edge].count) != count + 1 or int(game.scars[edge].week) != 10:
		_bad("repeat on the raid edge did not increment")
		return false
	return true


func _live_assault(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var dest := _arm(game)
	if dest == "" or game._assault_gate(dest) != "":
		_bad("assault setup " + game._assault_gate(dest))
		return false
	game.scars = {}
	if not game._order_assault(dest, true):
		_bad("assault did not resolve")
		return false
	var edge := Scars.edge_id(str(game.capital_id), dest)
	if not game.scars.has(edge) or str(game.scars[edge].get("kind", "")) != "raid":
		_bad("assault left no raid scar")
		return false
	return true


func _live_rival(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var seat := ""
	var approach := ""
	for sid in game.stations:
		var id := str(sid)
		if id == str(game.capital_id):
			continue
		if str(game.stations[id].get("bunker", "")) != "":
			continue
		for n in game._neighbors(id):
			var far := str(n)
			if far == str(game.capital_id):
				continue
			var tunnel: Dictionary = game._edge(id, far)
			if tunnel.is_empty() or str(tunnel.get("state", "open")) == "sealed":
				continue
			seat = id
			approach = far
			break
		if seat != "":
			break
	if seat == "" or not game.squads.has("directorate"):
		_bad("no rival approach")
		return false
	game.stations[seat].owner = game.player
	game.stations[seat].known = true
	game.stations[seat].passage = true
	game.stations[approach].owner = "directorate"
	game.stations[approach].garrison = 4
	game.at_war["directorate"] = true
	var sq: Dictionary = game.squads["directorate"]
	sq.station = approach
	sq.size = 18
	sq.gear = 2.0
	game.scars = {}
	game._step_squad(sq, seat, false)
	var edge := Scars.edge_id(seat, approach)
	if not game.scars.has(edge):
		_bad("rival assault left no scar")
		return false
	# Sortie is a garrison raid onto the squad's station. Chance is a test copy, not balance.json.
	game.bal = game.bal.duplicate(true)
	game.bal["guard"] = (game.bal.get("guard", {}) as Dictionary).duplicate(true)
	game.bal.guard["sortie_chance"] = 1.0
	game.flags["provoked_directorate"] = int(game.week) + 4
	game.squads[game.player].station = seat
	game.squads[game.player].away = false
	var before := game.scars.duplicate(true)
	game._sorties()
	if game.scars.is_empty() or str(game.scars.get(Scars.edge_id(str(game.capital_id), seat), {}).get("kind", "")) == "" and before == game.scars:
		# The seat's owned edges should have been touched if the sortie fired.
		var grew := game.scars.size() > before.size()
		var bumped := false
		for key in game.scars:
			if int(game.scars[key].get("count", 0)) > int(before.get(key, {}).get("count", 0)):
				bumped = true
		if not grew and not bumped:
			_bad("sortie raid left the scars unchanged")
			return false
	return true


func _live_night(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	if game.residents.size() < 2:
		_bad("need two residents")
		return false
	var home := str(game.capital_id)
	var pid := str(game.residents[0].get("id", ""))
	var other := str(game.residents[1].get("id", ""))
	game.scars = {}
	Night._kill(game, pid, {"id": "gate", "station": home})
	if game.scars.is_empty():
		_bad("night death left no scar")
		return false
	for key in game.scars:
		if str(game.scars[key].get("kind", "")) != "night":
			_bad("death scar kind " + str(key))
			return false
		var bits := str(key).split("|")
		if str(bits[0]) != home and str(bits[1]) != home:
			_bad("death scar is not on the site " + str(key))
			return false
	var foreign := _foreign_pair(game)
	var quiet := game.scars.duplicate(true)
	Night._kill(game, other, {"id": "gate", "station": str(foreign[0])})
	if game.scars.has(Scars.edge_id(str(foreign[0]), str(foreign[1]))):
		_bad("foreign death scarred")
		return false
	# Capture is not a death. The cite names the site helper; it does not write a scar.
	var held := game.scars.duplicate(true)
	if game.residents.is_empty():
		_bad("no resident left for capture")
		return false
	Night._capture(game, str(game.residents[0].get("id", "")), {"id": "gate", "station": home})
	if str(game.scars) != str(held):
		_bad("capture wrote a scar")
		return false
	if str(quiet) == "":
		_bad("quiet")
		return false
	return true


func _foreign_pair(game: Game) -> Array:
	for tunnel in game.tunnels:
		var a := str(tunnel.get("a", ""))
		var b := str(tunnel.get("b", ""))
		if Scars.holds(game, a) or Scars.holds(game, b):
			continue
		if not game.stations.has(a) or not game.stations.has(b):
			continue
		return [a, b]
	return ["", ""]


func _save(catalog: Catalog) -> bool:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 27") < 0 or src.find("V19_ADDED") < 0 or src.find("V20_ADDED") < 0 or src.find("V21_ADDED") < 0 or src.find("V22_ADDED") < 0 or src.find("V23_ADDED") < 0 or src.find("V24_ADDED") < 0:
		_bad("schema source")
		return false
	if src.find("\"sdays\"") < 0 or src.find("\"carry\"") < 0 or src.find("\"echoes\"") < 0 or src.find("\"rival_log\"") < 0 or src.find("\"callers\"") < 0 or src.find("\"scars\"") < 0:
		_bad("persist keys")
		return false
	var game := _fresh(catalog)
	game.sdays["kept"] = {"plaza": 4}
	game.carry["delivered"] = 3
	game.carry["pocket"] = {"thread": "lamp_copper", "leg": 1}
	game.echoes = {"plaza": {"kind": "deal", "week": 2}}
	game.rival_log = {"exchange": {"kind": "bought", "week": 3, "target": "trampark"}}
	game.callers.here = "exchange"
	game.callers.why = "warm"
	game.week = 12
	var nbr := ""
	for n in game._neighbors(game.capital_id):
		nbr = str(n)
		break
	Scars.note_raid(game, nbr)
	game.flags[Scars.FLAG] = true
	var snap := game.export_state()
	snap["schema"] = 25
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(snap):
		_bad("schema 25 " + again.load_error)
		return false
	var edge := Scars.edge_id(str(game.capital_id), nbr)
	if str(again.scars.get(edge, {}).get("kind", "")) != "raid" or int(again.scars[edge].count) != 1:
		_bad("load dropped scars")
		return false
	if int(again.sdays.kept.get("plaza", 0)) != 4 or int(again.carry.delivered) != 3:
		_bad("load dropped sdays or carry")
		return false
	if str(again.echoes.get("plaza", {}).get("kind", "")) != "deal" or str(again.rival_log.get("exchange", {}).get("kind", "")) != "bought" or str(again.callers.get("here", "")) != "exchange":
		_bad("schema 25 dropped an earlier field")
		return false
	if not bool(again.flags.get(Scars.FLAG, false)):
		_bad("load dropped seen flag")
		return false
	var bare := game.export_state()
	bare.erase("scars")
	bare["schema"] = 25
	var refused := Game.new()
	refused.catalog = catalog
	if refused.import_state(bare):
		_bad("schema 25 accepted a save with no scars")
		return false
	var legacy := game.export_state()
	legacy.erase("scars")
	legacy["schema"] = 21
	var old := Game.new()
	old.catalog = catalog
	if not old.import_state(legacy):
		_bad("schema 21 " + old.load_error)
		return false
	if not old.scars.is_empty() or int(old.sdays.kept.get("plaza", 0)) != 4 or int(old.carry.delivered) != 3:
		_bad("schema 21 migration")
		return false
	var days := game.export_state()
	days.erase("scars")
	days.erase("carry")
	days["schema"] = 20
	var v20 := Game.new()
	v20.catalog = catalog
	if not v20.import_state(days):
		_bad("schema 20 " + v20.load_error)
		return false
	if not v20.scars.is_empty() or not v20.carry.pocket.is_empty() or int(v20.carry.delivered) != 0:
		_bad("schema 20 did not keep sdays-only and empty carry")
		return false
	if int(v20.sdays.kept.get("plaza", 0)) != 4:
		_bad("schema 20 dropped sdays")
		return false
	for ver in [20, 21, 22, 23, 24]:
		var mixed := game.export_state()
		mixed.erase("scars")
		mixed["schema"] = ver
		var mid := Game.new()
		mid.catalog = catalog
		if not mid.import_state(mixed):
			_bad("schema %d %s" % [ver, mid.load_error])
			return false
		if not mid.scars.is_empty():
			_bad("schema %d invented scars" % ver)
			return false
		if int(mid.sdays.kept.get("plaza", 0)) != 4 or int(mid.carry.delivered) != 3:
			_bad("schema %d dropped sdays or carry" % ver)
			return false
		if str(mid.echoes.get("plaza", {}).get("kind", "")) != "deal" or str(mid.rival_log.get("exchange", {}).get("kind", "")) != "bought" or str(mid.callers.get("here", "")) != "exchange":
			_bad("schema %d dropped echoes, rival_log, or callers" % ver)
			return false
	var plain := game.export_state()
	plain.erase("scars")
	plain["schema"] = 24
	var without := Game.new()
	without.catalog = catalog
	if not without.import_state(plain):
		_bad("schema 24 without draft keys " + without.load_error)
		return false
	if not without.scars.is_empty():
		_bad("schema 24 invented scars")
		return false
	var extra := game.export_state()
	extra["schema"] = 25
	extra["echoes"] = {}
	extra["rival_log"] = {}
	extra["callers"] = {}
	extra.scars[edge]["note"] = "kept"
	var with_extra := Game.new()
	with_extra.catalog = catalog
	if not with_extra.import_state(extra):
		_bad("extra row field " + with_extra.load_error)
		return false
	var bad_kind := game.export_state()
	bad_kind["schema"] = 25
	bad_kind.scars[edge]["kind"] = "feast"
	var no_kind := Game.new()
	no_kind.catalog = catalog
	if no_kind.import_state(bad_kind):
		_bad("bad kind accepted")
		return false
	var future := game.export_state()
	future["schema"] = 26
	var too_new := Game.new()
	too_new.catalog = catalog
	if too_new.import_state(future):
		_bad("schema 26 accepted")
		return false
	var no_carry := game.export_state()
	no_carry.erase("carry")
	no_carry["schema"] = 21
	var dropped := Game.new()
	dropped.catalog = catalog
	if dropped.import_state(no_carry):
		_bad("schema 21 accepted a save with no carry")
		return false
	return true


func _hooks() -> bool:
	var game := FileAccess.get_file_as_string("res://sim/game.gd")
	var raid := _fn(game, "_order_raid")
	var assault := _fn(game, "_order_assault")
	var step := _fn(game, "_step_squad")
	var sortie := _fn(game, "_sorties")
	if raid.find("PassageScars.note_raid") < 0 or assault.find("PassageScars.note_raid") < 0:
		_bad("player raid hook")
		return false
	if step.find("if not player_move:") < 0 or step.find("PassageScars.note_raid") < 0:
		_bad("rival assault hook")
		return false
	if sortie.find("PassageScars.note_raid") < 0:
		_bad("sortie hook")
		return false
	var night := FileAccess.get_file_as_string("res://sim/night_runs.gd")
	var kill := _fn(night, "_kill")
	var capture := _fn(night, "_capture")
	if kill.find("PassageScars.note_night") < 0:
		_bad("death hook")
		return false
	if capture.find("PassageScars.note_night") >= 0 or capture.find("note_raid") >= 0:
		_bad("capture is not dormant")
		return false
	var scars := FileAccess.get_file_as_string("res://sim/passage_scars.gd")
	if scars.find("night_armed") < 0 or scars.find("res://sim/night_runs.gd") < 0:
		_bad("night trigger is not dormant without P74")
		return false
	var picker := _fn(game, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("PassageScars") >= 0 or picker.find("scar.") >= 0:
		_bad("dawn picker knows scars")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	for draw_name in ["_draw_passage_edges", "_draw_pins", "_draw_pin", "_draw_ink", "_draw_lines"]:
		var body := _fn(view, draw_name)
		if body.find("scar") >= 0 or body.find("PassageScars") >= 0:
			_bad(draw_name + " draws a scar")
			return false
	if view.find("_draw_scar") >= 0 or view.find("scar_tick") >= 0:
		_bad("map tick")
		return false
	var fill := _fn(view, "_fill_visit")
	var toll_at := fill.find("_add_quiet_toll")
	var scar_at := fill.find("_add_passage_scar")
	var ledger_at := fill.find("_add_outpost_ledger")
	if toll_at < 0 or scar_at < 0 or ledger_at < 0 or not (toll_at < scar_at and scar_at < ledger_at):
		_bad("visit source order")
		return false
	var yard := _fn(FileAccess.get_file_as_string("res://ui/station.gd"), "_show_scar_yard")
	if yard.find("_tip_plate_style") < 0 or yard.find("outline_size\", 0") < 0 or yard.find("outline_size\", 6") >= 0 or yard.find("_place_yard_notice") < 0 or yard.find("_restack_yard_notices") < 0:
		_bad("yard float plate")
		return false
	var shown := _fn(view, "_show_scar_float")
	if shown.find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var found := src.find(marker, at + 4)
		if found >= 0 and found < next:
			next = found
	return src.substr(at, next - at)


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


func _post_duty(game: Game, sid: String) -> void:
	if game.residents.is_empty():
		return
	game.residents[0]["duty_edge_id"] = Toll.edge_id(str(game.capital_id), sid)


func _ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	var far := str(pair[1])
	if sid == "" or far == "":
		_bad("ui pair")
		return false
	_own(game, sid)
	_flow(game, far, true)
	_post_duty(game, sid)
	if Toll.edge_state(game, sid, far) != "qualifies":
		_bad("toll preface " + Toll.edge_state(game, sid, far))
		return false
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	root.add_child(view)
	await process_frame
	await process_frame
	if view.has_method("_draw_scar_tick") or view.has_method("_draw_flow_tick"):
		_bad("tick method")
		return false
	# Before: no scar on the edge, pin tip still ends on the toll line.
	var pin := view._tip(sid)
	if pin.split("\n")[-1] != Copy.t("toll.tip"):
		_bad("pin tip changed before a scar " + pin.split("\n")[-1])
		return false
	if Scars.edge_tip(game, sid, far) != "":
		_bad("edge tip without a scar")
		return false
	view.open_visit(sid)
	await _frames(2)
	if not _meta(view.visit, "scar_row").is_empty():
		_bad("visit row before a scar")
		return false
	await _shot_surface(view, sid, far, "visit", "p94_visit_before_en")
	await _shot_surface(view, sid, far, "edge", "p94_edge_before_en")
	await _shot_surface(view, sid, far, "float", "p94_float_before_en")
	view.open_visit(sid)
	game.week = 40
	game.flags.erase(Scars.FLAG)
	# One scar, plural form, so the RU width check is the long line.
	game.scars = {}
	game.scars[Scars.edge_id(sid, far)] = {"kind": "raid", "week": 40, "count": 12}
	var rows: Array = Scars.edge_rows(game, sid, far)
	if rows.is_empty() or str(rows.back().get("role", "")) != "scar":
		_bad("scar is not last on the edge tip")
		return false
	var saw_toll := false
	for row in rows:
		var role := str(row.get("role", ""))
		if role == "scar" and saw_toll:
			break
		if role == "toll":
			saw_toll = true
		elif role == "scar" and not saw_toll:
			_bad("scar preceded toll")
			return false
		if role == "flow" or role == "duty":
			if saw_toll:
				_bad("flow or duty after toll")
				return false
	if not saw_toll:
		_bad("qualifying toll missing from the edge tip")
		return false
	if view._tip(sid).split("\n")[-1] != Copy.t("toll.tip"):
		_bad("scar replaced the pin tip")
		return false
	if view._tip(sid).find(Scars.visit_line(game, sid)) >= 0:
		_bad("pin tip absorbed the scar sentence")
		return false
	view._fill_visit(sid)
	await _frames(2)
	var scar_rows := _meta(view.visit, "scar_row")
	if scar_rows.size() != 1:
		_bad("visit scar count %d" % scar_rows.size())
		return false
	var scar_line: Label = scar_rows[0]
	if str(scar_line.text) != Scars.visit_line(game, sid) or str(scar_line.text) != Copy.fill("scar.raid_n", {"count": "12", "n": "40"}):
		_bad("visit text " + str(scar_line.text))
		return false
	if scar_line.tooltip_text != Copy.t("scar.tip"):
		_bad("visit tooltip")
		return false
	var ledgers := _meta(view.visit, "ledger_row")
	var tolls := _meta(view.visit, "toll_row")
	if ledgers.size() != 1 or tolls.size() != 1:
		_bad("toll or ledger missing")
		return false
	if tolls[0].get_index() >= scar_line.get_index() or scar_line.get_index() >= ledgers[0].get_index():
		_bad("visit order toll %d scar %d ledger %d" % [tolls[0].get_index(), scar_line.get_index(), ledgers[0].get_index()])
		return false
	if _overlaps(tolls[0], scar_line) or _overlaps(scar_line, ledgers[0]):
		_bad("visit overlap")
		return false
	view.open_visit(far)
	await _frames(1)
	if _meta(view.visit, "scar_row").size() != 1:
		_bad("far endpoint hid the scar")
		return false
	view.open_visit(str(game.capital_id))
	await _frames(1)
	if not _meta(view.visit, "scar_row").is_empty():
		_bad("capital visit showed a scar for an edge it does not touch")
		return false
	view.open_visit(sid)
	await _frames(1)
	view.present_edge_tip(sid, far, Vector2(420, 180))
	await _frames(2)
	if not _tip_ok(view, false):
		return false
	game.flags.erase(Scars.FLAG)
	view._note_first_passage_scar()
	await _frames(2)
	if view._scar_float == null or not view._scar_float.visible or view._scar_float.text != Copy.t("scar.first"):
		_bad("float")
		return false
	var plate := view._scar_float.get_parent()
	if plate == null or not bool(plate.get_meta("map_float_plate", false)):
		_bad("float is not on the X1 plate")
		return false
	if int(view._scar_float.get_theme_constant("outline_size")) != 0:
		_bad("float outline")
		return false
	if Scars.claim_first(game) != "":
		_bad("float did not consume the flag")
		return false
	await _shot_surface(view, sid, far, "visit", "p94_visit_after_en")
	await _shot_surface(view, sid, far, "edge", "p94_edge_after_en")
	await _shot_surface(view, sid, far, "float", "p94_float_after_en")
	view.open_visit(sid)
	Copy.set_lang("ru")
	view._fill_visit(sid)
	view.present_edge_tip(sid, far, Vector2(420, 180))
	view._show_scar_float(Copy.t("scar.first"))
	await _frames(2)
	scar_rows = _meta(view.visit, "scar_row")
	if scar_rows.size() != 1 or str(scar_rows[0].text) != Copy.fill("scar.raid_n", {"count": "12", "n": "40"}):
		_bad("ru visit")
		Copy.set_lang("en")
		return false
	if scar_rows[0].get_line_count() > 2:
		_bad("ru visit lines %d" % scar_rows[0].get_line_count())
		Copy.set_lang("en")
		return false
	if not _tip_ok(view, true):
		Copy.set_lang("en")
		return false
	await _shot_surface(view, sid, far, "visit", "p94_visit_after_ru")
	await _shot_surface(view, sid, far, "edge", "p94_edge_after_ru")
	await _shot_surface(view, sid, far, "float", "p94_float_after_ru")
	view.open_visit(sid)
	Copy.set_lang("en")
	view.size = Vector2(1536, 864)
	root.size = Vector2(1536, 864)
	view._fill_visit(sid)
	view.present_edge_tip(sid, far, Vector2(480, 200))
	view._show_scar_float(Copy.t("scar.first"))
	await _frames(2)
	Copy.set_lang("ru")
	view._fill_visit(sid)
	view.present_edge_tip(sid, far, Vector2(480, 200))
	view._show_scar_float(Copy.t("scar.first"))
	await _frames(2)
	scar_rows = _meta(view.visit, "scar_row")
	tolls = _meta(view.visit, "toll_row")
	ledgers = _meta(view.visit, "ledger_row")
	if scar_rows.size() != 1 or tolls.is_empty() or ledgers.is_empty():
		_bad("125 visit rows")
		Copy.set_lang("en")
		return false
	if scar_rows[0].get_line_count() > 2:
		_bad("125 ru visit lines %d" % scar_rows[0].get_line_count())
		Copy.set_lang("en")
		return false
	if _overlaps(tolls[0], scar_rows[0]) or _overlaps(scar_rows[0], ledgers[0]):
		_bad("125 overlap")
		Copy.set_lang("en")
		return false
	if not _tip_ok(view, true):
		Copy.set_lang("en")
		return false
	await _shot_surface(view, sid, far, "visit", "p94_visit_after_125")
	await _shot_surface(view, sid, far, "edge", "p94_edge_after_125")
	await _shot_surface(view, sid, far, "float", "p94_float_after_125")
	view.open_visit(sid)
	Copy.set_lang("en")
	# Before shots in RU and at 125% of the unscarred sheet, for the comparison set.
	game.scars = {}
	Copy.set_lang("ru")
	view.size = Vector2(1280, 720)
	root.size = Vector2(1280, 720)
	view._fill_visit(sid)
	view._hide_edge_tip()
	if view._scar_float != null:
		view._scar_float.visible = false
		var old_plate := view._float_plate(view._scar_float)
		if old_plate != view._scar_float:
			old_plate.visible = false
	await _frames(1)
	await _shot_surface(view, sid, far, "visit", "p94_visit_before_ru")
	await _shot_surface(view, sid, far, "edge", "p94_edge_before_ru")
	await _shot_surface(view, sid, far, "float", "p94_float_before_ru")
	view.open_visit(sid)
	view.size = Vector2(1536, 864)
	root.size = Vector2(1536, 864)
	view._fill_visit(sid)
	await _frames(1)
	await _shot_surface(view, sid, far, "visit", "p94_visit_before_125")
	await _shot_surface(view, sid, far, "edge", "p94_edge_before_125")
	await _shot_surface(view, sid, far, "float", "p94_float_before_125")
	Copy.set_lang("en")
	return true


func _tip_ok(view: NetworkView, ru: bool) -> bool:
	if view._edge_tip == null or not view._edge_tip.visible:
		_bad("edge tip hidden")
		return false
	var box := view._edge_tip.get_child(0)
	var prev: Control = null
	var scar_n := 0
	var toll_before := false
	for child in box.get_children():
		if not child is Label:
			continue
		var lab := child as Label
		if lab.custom_minimum_size.x > Scars.TIP_W + 0.5:
			_bad("tip wider than 360")
			return false
		if lab.get_line_count() > 2:
			_bad("tip lines %d %s" % [lab.get_line_count(), lab.text])
			return false
		if prev != null and lab.position.y < prev.position.y + prev.size.y - 1.0:
			_bad("tip lines overlap")
			return false
		prev = lab
		if str(lab.get_meta("edge_tip_role", "")) == "toll":
			toll_before = scar_n == 0
		if str(lab.get_meta("edge_tip_role", "")) == "scar":
			scar_n += 1
			if not toll_before:
				_bad("tip scar before toll")
				return false
	if scar_n != 1:
		_bad("tip scar lines %d" % scar_n)
		return false
	if view._edge_tip.get_global_rect().end.x > view.size.x + 1.0 or view._edge_tip.get_global_rect().end.y > view.size.y + 80.0:
		_bad("tip outside the map")
		return false
	if ru and prev != null and prev.get_line_count() > 2:
		_bad("ru tip")
		return false
	return true


func _overlaps(a: Control, b: Control) -> bool:
	var ra := a.get_global_rect().grow(-1.0)
	var rb := b.get_global_rect().grow(-1.0)
	return ra.intersects(rb)


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


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _hide_float(view: NetworkView) -> void:
	if view._scar_float == null:
		return
	view._scar_float.visible = false
	var plate := view._float_plate(view._scar_float)
	if plate != view._scar_float:
		plate.visible = false


## One surface per shot: the Visit sheet, the edge tip on the map, or the first float.
func _shot_surface(view: NetworkView, sid: String, far: String, kind: String, name: String) -> void:
	if kind == "visit":
		view._hide_edge_tip()
		_hide_float(view)
		view.open_visit(sid)
	elif kind == "edge":
		view.close_visit()
		_hide_float(view)
		if not view._fitted:
			view._fit()
		view.present_edge_tip(sid, far, Vector2(view.size.x * 0.5 - 80.0, view.size.y * 0.28))
	else:
		view.close_visit()
		view._hide_edge_tip()
		if not view._fitted:
			view._fit()
		if not view._game().scars.is_empty():
			view._show_scar_float(Copy.t("scar.first"))
		else:
			_hide_float(view)
	await _frames(2)
	await _shot(view, name)


func _shot_dir() -> String:
	var dir := OS.get_environment("UNDERLINE_SCARS_SHOTS")
	if dir == "":
		dir = OS.get_environment("UNDERLINE_SHOTS_DIR")
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots-dir="):
			dir = str(arg).trim_prefix("--shots-dir=")
	if dir == "":
		dir = "user://scars_shots"
	if dir.begins_with("user://") or dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	return dir


func _renderer_live() -> bool:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return false
	return true


func _shot(_view: Control, name: String) -> void:
	if not _renderer_live():
		_shots_skipped = true
		print("SCARS SHOT SKIP %s no renderer" % name)
		return
	await process_frame
	RenderingServer.force_draw()
	var tex := root.get_texture()
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	if img == null or img.get_width() < 2:
		_bad("no image " + name)
		return
	var dir := _shot_dir()
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and not DirAccess.dir_exists_absolute(dir):
		_bad("shot dir %s err %s" % [dir, str(made)])
		return
	var err := img.save_png(dir.path_join(name + ".png"))
	if err != OK:
		_bad("shot %s err %s" % [name, str(err)])
		return
	_shots_saved += 1


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


func _play(catalog: Catalog, run_seed: int) -> Game:
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
	return game


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60 or LOST_SEEDS.split(",").size() != BASELINE_LOST:
		_bad("baseline missing")
		return false
	for on in [true, false]:
		Scars.enabled = on
		var lost := 0
		var matched := 0
		for run_seed in range(1, 61):
			var game := _play(catalog, run_seed)
			var got := _outcome_hash(game)
			var want := int(MASTER_HASH[run_seed - 1])
			if got == want:
				matched += 1
			else:
				_bad("seed %d on=%s hash %d master %d" % [run_seed, str(on), got, want])
			if str(game.over) != "time":
				lost += 1
		if matched != 60 or lost != BASELINE_LOST:
			_bad("careful on=%s matched %d lost %d" % [str(on), matched, lost])
			return false
		print("Careful on=%s: 60/60 lost %d" % [str(on), lost])
	Scars.enabled = true
	return true
