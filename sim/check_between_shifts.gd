extends SceneTree

## P96 Between Shifts gate.
##   godot --headless --path . -s res://sim/check_between_shifts.gd
##   godot --rendering-driver opengl3 --path . -s res://sim/check_between_shifts.gd
## Headless prints screenshotSKIP and does not claim the visual gate.
## A real renderer writes EN 100, RU 100, and EN 125 before/after PNGs.

const Words = preload("res://sim/between_shifts.gd")
const SPEAKERS := ["ruth", "benny", "samira", "owen", "lila", "pete"]
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
const CHROME := {
	"shiftword.open": "Talk between shifts",
	"shiftword.archive": "Our exchange",
	"shiftword.back": "Back",
	"shiftword.unavailable": "Not here to talk.",
}
const RUTH_SAMIRA := {
	"shiftword.ruth.scene": "Ruth lowers the needles when you sit down. The scarf has an unfinished edge. She leaves a space beside it, but does not begin a story for you.",
	"shiftword.ruth.a": "Ask about the scarf.",
	"shiftword.ruth.b": "Ask what keeps her awake.",
	"shiftword.ruth.answer_a": "This edge keeps curling. I can tell you where the stitch went wrong. That is something I can show you.",
	"shiftword.ruth.answer_b": "A quiet platform is not the same as a quiet watch. Some nights I count the time. I would rather leave the rest there.",
	"shiftword.ruth.follow_a": "Ruth turns the unfinished edge toward you. 'The stitch we spoke about is here.' She keeps the needles in her own hands.",
	"shiftword.ruth.follow_b": "'You asked about the hours last time,' Ruth says. 'Ask me what is in front of me today.' She picks up the scarf.",
	"shiftword.samira.scene": "Samira turns the brass piston in the light. The engine it belongs to is unfinished. She waits to see whether you mean to ask about the machine or the work.",
	"shiftword.samira.a": "Ask what the engine sounded like.",
	"shiftword.samira.b": "Ask where the work stopped.",
	"shiftword.samira.answer_a": "It never ran. In my head it starts too cleanly. A little two-stroke would cough first; I keep forgetting that.",
	"shiftword.samira.answer_b": "Before the last fit. Close enough to see the shape, not close enough to turn it over. That is where the work stopped.",
	"shiftword.samira.follow_a": "'There was a cough before the sound,' Samira says. 'I left it out when I told you.' She turns the piston once.",
	"shiftword.samira.follow_b": "'That last fit we spoke about is still missing,' Samira says. 'I wanted you to know where it stopped, not promise to finish it.'",
}

var _failed := false
var _shots_skipped := false
var _shots_saved := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	Words.enabled = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("SHIFTWORD FAIL catalog")
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
		print("Strings: ok (interim EN, RU empty)")
	if not _bounds():
		_failed = true
	else:
		print("Bounds: ok")
	if not _branches(catalog):
		_failed = true
	else:
		print("Branches: ok")
	if not _eligibility(catalog):
		_failed = true
	else:
		print("Eligibility: ok")
	if not _save(catalog):
		_failed = true
	else:
		print("Save: ok")
	if not await _ui(catalog):
		_failed = true
	else:
		print("UI: ok")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if _failed:
		print("SHIFTWORD FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("SHIFTWORD FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("SHIFTWORD FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	Words.enabled = true
	if _shots_skipped:
		print("SHIFTWORD screenshotSKIP headless")
	elif _shots_saved > 0:
		print("SHIFTWORD SHOTS %d" % _shots_saved)
	else:
		print("SHIFTWORD screenshotSKIP no frames")
	print("COPY GATE OUTSTANDING: EN is interim draft, not canon. RU unauthored (46 empty strings). No between_shifts_ru_fragment.json. Ruth/Samira scenes are the spec examples and sit under the 35-word bar.")
	print("SHIFTWORD OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/between_shifts.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P96":
		_bad("pack roadmap")
		return false
	if pack.get("_canon", true) != false or str(pack.get("_status", "")).find("INTERIM") < 0:
		_bad("pack claims canon approval")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 46:
		_bad("key count %d" % rows.size())
		return false
	if FileAccess.file_exists("res://data/between_shifts_ru_fragment.json"):
		_bad("ru fragment exists before Texts authored it")
		return false
	var src := FileAccess.get_file_as_string("res://sim/copy.gd")
	if src.find("res://data/between_shifts.json") < 0:
		_bad("copy pack not merged")
		return false
	for id in SPEAKERS:
		for part in Words.PARTS:
			var key := Words.person_key(id, part)
			if not rows.has(key):
				_bad("missing " + key)
				return false
	for key in CHROME:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		if str(rows[key].get("en", "")) != str(CHROME[key]):
			_bad("chrome " + key)
			return false
	for key in RUTH_SAMIRA:
		if str(rows[key].get("en", "")) != str(RUTH_SAMIRA[key]):
			_bad("spec example drifted " + key)
			return false
	for key in rows:
		var row = rows[key]
		if not (row is Dictionary):
			_bad("row " + str(key))
			return false
		var en := str(row.get("en", ""))
		var ru := str(row.get("ru", ""))
		if en == "" or en == str(key) or en.find("{") >= 0:
			_bad("en " + str(key))
			return false
		if ru != "":
			_bad("ru filled before Texts " + str(key))
			return false
		var n := _words(en)
		var id := str(key)
		if id.ends_with(".a") or id.ends_with(".b"):
			if n > 8:
				_bad("reply length %s %d" % [id, n])
				return false
		elif id.find(".answer_") >= 0 or id.find(".follow_") >= 0:
			if n < 15 or n > 30:
				_bad("answer length %s %d" % [id, n])
				return false
		elif id.ends_with(".scene") and id != "shiftword.ruth.scene" and id != "shiftword.samira.scene":
			if n < 35 or n > 60:
				_bad("scene length %s %d" % [id, n])
				return false
		Copy.set_lang("en")
		if Copy.t(id) != en:
			_bad("Copy.t " + id)
			return false
		if Words.line(id) != en:
			_bad("line " + id)
			return false
	Copy.set_lang("ru")
	for key in rows:
		if Words.line(str(key)) != "":
			_bad("ru line leaked " + str(key))
			Copy.set_lang("en")
			return false
		if Copy.t(str(key)) == str(key):
			_bad("raw key shown for " + str(key))
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	if Words.line("shiftword.nope") != "":
		_bad("missing key returned text")
		return false
	return true


func _words(text: String) -> int:
	var n := 0
	var cur := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		var ok := (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "'"
		if ok:
			cur += ch
		else:
			n += _word_token(cur)
			cur = ""
	n += _word_token(cur)
	return n


func _word_token(token: String) -> int:
	for i in token.length():
		var ch := token.substr(i, 1)
		if (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			return 1
	return 0


func _bounds() -> bool:
	if Words.dawn_chip() or Words.map_mark() or Words.joins_soft_dawn():
		_bad("dawn or map")
		return false
	var src := FileAccess.get_file_as_string("res://sim/between_shifts.gd")
	for token in [".rand", "story_events", "orders_left", "chronicle", "wall_plates", "story_words", "pending", "balance"]:
		if src.find(token) >= 0:
			_bad("reader touches " + token)
			return false
	if src.find("NightRuns") >= 0:
		_bad("reader boots night runs")
		return false
	var game_src := FileAccess.get_file_as_string("res://sim/game.gd")
	if game_src.find("const SAVE_SCHEMA := 27") < 0 or game_src.find("V25_ADDED") < 0 or game_src.find("V26_ADDED") < 0 or game_src.find("V24_ADDED") < 0:
		_bad("schema source")
		return false
	if game_src.find("const SAVE_SCHEMA := 25") >= 0 or game_src.find("const SAVE_SCHEMA := 26") >= 0:
		_bad("schema const drifted")
		return false
	if game_src.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") < 0:
		_bad("soft dawn stack moved")
		return false
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var fill_at := station.find("func _fill_people")
	var fill_end := station.find("\nfunc ", fill_at + 10)
	if fill_at >= 0 and fill_end > fill_at and station.substr(fill_at, fill_end - fill_at).find("shiftword") >= 0:
		_bad("people list gained a chip")
		return false
	var net := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if net.find("shiftword") >= 0:
		_bad("map view gained shiftword")
		return false
	return true


func _fresh(catalog: Catalog, run_seed := 4) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.week = 4
	game.shiftword_state = {}
	return game


func _rng(game: Game) -> String:
	return "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)]


func _body(game: Game) -> String:
	var data := game.export_state()
	data.erase("shiftword_state")
	return JSON.stringify(data)


func _branches(catalog: Catalog) -> bool:
	for id in SPEAKERS:
		for choice in ["a", "b"]:
			var game := _fresh(catalog)
			var before_rng := _rng(game)
			var before_body := _body(game)
			var events: Array = (game.people[id].get("story_events", []) as Array).duplicate(true)
			var memory := int(game.people[id].get("memory", 0))
			var orders := int(game.orders_left)
			var pending := game.pending.size()
			var words := int(game.story_words)
			var wall := game.wall_plates.duplicate(true)
			var chron := game.chronicle.duplicate(true)
			if Words.offer(game, id) != "talk":
				_bad("%s not offered (%s)" % [id, Words.offer(game, id)])
				return false
			if Words.reply(game, id, choice) != "ok":
				_bad("%s %s did not commit" % [id, choice])
				return false
			if Words.reply(game, id, "a" if choice == "b" else "b") != "closed":
				_bad("%s second reply reopened" % id)
				return false
			if Words.choice_of(game, id) != choice or Words.answered_week(game, id) != 4:
				_bad("%s stored %s week %d" % [id, Words.choice_of(game, id), Words.answered_week(game, id)])
				return false
			if bool(game.shiftword_state[id].get("follow_seen", true)):
				_bad("%s follow marked early" % id)
				return false
			if Words.reveal_follow(game, id):
				_bad("%s callback on the same week" % id)
				return false
			if _rng(game) != before_rng or _body(game) != before_body:
				_bad("%s %s moved sim or rng" % [id, choice])
				return false
			if game.people[id].get("story_events", []) != events or int(game.people[id].get("memory", 0)) != memory:
				_bad("%s wrote a life note" % id)
				return false
			if int(game.orders_left) != orders or game.pending.size() != pending or int(game.story_words) != words:
				_bad("%s touched orders, pending, or words" % id)
				return false
			if game.wall_plates != wall or game.chronicle != chron:
				_bad("%s touched wall or chronicle" % id)
				return false
			game.week = 5
			if not Words.reveal_follow(game, id) or not bool(game.shiftword_state[id].follow_seen):
				_bad("%s callback missing" % id)
				return false
			if Words.line(Words.person_key(id, "follow_" + choice)) == "":
				_bad("%s follow text" % id)
				return false
			if _rng(game) != before_rng:
				_bad("%s callback moved rng" % id)
				return false
			var other := "b" if choice == "a" else "a"
			if Words.line(Words.person_key(id, "follow_" + choice)) == Words.line(Words.person_key(id, "follow_" + other)):
				_bad("%s callbacks match" % id)
				return false
	return true


func _eligibility(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	if game.flags.has("night_runs"):
		game.flags.erase("night_runs")
	var flags_before := JSON.stringify(game.flags)
	if not Words.present(game, "ruth") or Words.offer(game, "ruth") != "talk":
		_bad("ruth home")
		return false
	if JSON.stringify(game.flags) != flags_before or game.flags.has("night_runs"):
		_bad("opening the check booted night runs")
		return false
	game.week = 3
	if Words.offer(game, "ruth") != "hide" or Words.reply(game, "ruth", "a") != "stale":
		_bad("week 3 offered")
		return false
	game.week = 4
	if not game.shiftword_state.is_empty():
		_bad("stale week wrote state")
		return false
	for id in ["jonah", "inez", "june", "ellis"]:
		if Words.offer(game, id) != "hide":
			_bad("outsider " + id)
			return false
	game.people.june.name = "Ruth Adel"
	if Words.offer(game, "june") != "hide":
		_bad("alias name offered")
		return false
	game.people.ruth.cast_id = "mina"
	if Words.present(game, "ruth"):
		_bad("recast still original")
		return false
	game.people.ruth.erase("cast_id")
	game.people.ruth.dossier = {"title": {"en": "Night nurse"}}
	if Words.present(game, "ruth"):
		_bad("dossier still original")
		return false
	game.people.ruth.erase("dossier")
	game.people.ruth.child = true
	game.people.ruth.child_left = 2
	if Words.present(game, "ruth"):
		_bad("child still offered")
		return false
	game.people.ruth.child = false
	game.people.ruth.child_left = 0
	game.council.append({"role": "guest", "id": "ruth"})
	if Words.present(game, "ruth"):
		_bad("council still offered")
		return false
	game.council.pop_back()
	if not Words.present(game, "ruth"):
		_bad("ruth did not return after council")
		return false
	game.people.ruth.sick = 1
	if Words.present(game, "ruth") or Words.reply(game, "ruth", "a") != "stale":
		_bad("sick committed")
		return false
	game.people.ruth.sick = 0
	game.people.ruth.absent = 2
	if Words.present(game, "ruth"):
		_bad("injury still home")
		return false
	game.people.ruth.absent = 0
	if Words.offer(game, "ruth") != "talk":
		_bad("return did not restore")
		return false
	var seat := ""
	for sid in game.stations:
		if str(sid) != str(game.capital_id):
			seat = str(sid)
			break
	game.stations[seat].governor = "ruth"
	if Words.present(game, "ruth"):
		_bad("governor still home")
		return false
	game.stations[seat].governor = ""
	game.people.ruth.on_run = true
	if Words.present(game, "ruth"):
		_bad("on_run still home")
		return false
	game.people.ruth.on_run = false
	game.flags.night_runs = {"active": {"runners": ["ruth"]}, "intel": {}}
	if Words.present(game, "ruth"):
		_bad("runner still home")
		return false
	game.flags.erase("night_runs")
	var sq: Dictionary = game.squads[game.player]
	var roster: Array = sq.roster
	if not roster.has("ruth"):
		roster.append("ruth")
	sq.away = false
	sq.station = game.capital_id
	game.people.ruth.soldier = true
	game.people.ruth.soup_cook = true
	if game.rooms.is_empty():
		_bad("no home room")
		return false
	var staff: Array = game.rooms[0].staff
	if not staff.has("ruth"):
		staff.append("ruth")
	game.dig = {"workers": ["ruth"], "level": 0, "cell": 0, "left": 1}
	if not Words.present(game, "ruth") or Words.offer(game, "ruth") != "talk":
		_bad("home room guard crew soup hidden")
		return false
	if not game._locked_ids().has("ruth"):
		_bad("fixture was not locked; the home allowance was not proven")
		return false
	sq.away = true
	if Words.present(game, "ruth"):
		_bad("away squad still home")
		return false
	sq.away = false
	sq.station = seat
	if Words.present(game, "ruth"):
		_bad("off-home station still home")
		return false
	sq.station = game.capital_id
	roster.erase("ruth")
	game.people.ruth.duty_edge_id = "home|far"
	if Words.present(game, "ruth"):
		_bad("duty seat still home")
		return false
	game.people.ruth.erase("duty_edge_id")
	game.expedition = {"left": 2, "tunnel": "to_ferry", "roster": ["ruth"]}
	if Words.present(game, "ruth"):
		_bad("expedition roster still home")
		return false
	game.expedition = {"left": 2, "tunnel": "to_ferry"}
	if not Words.present(game, "ruth"):
		_bad("expedition without a roster hid a home resident")
		return false
	game.expedition = {}
	var kept: Array = []
	for person in game.residents:
		if str(person.id) != "ruth":
			kept.append(person)
	game.residents = kept
	if Words.present(game, "ruth") or Words.offer(game, "ruth") != "hide":
		_bad("people-dict ghost still offered")
		return false
	game.residents.append(game.people.ruth)
	if Words.reply(game, "ruth", "a") != "ok":
		_bad("restored ruth could not answer")
		return false
	var row: Dictionary = game.shiftword_state.ruth.duplicate(true)
	game._remove_resident("ruth")
	if game.people.has("ruth") or Words.offer(game, "ruth") != "hide" or Words.reveal_follow(game, "ruth"):
		_bad("death still speaks")
		return false
	if game.shiftword_state.get("ruth", {}) != row or bool(row.get("follow_seen", true)):
		_bad("death rewrote the exchange")
		return false
	if not game.burials.is_empty():
		_bad("death grew a burial from the exchange")
		return false
	return true


func _save(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 9)
	game.scars = {"a|b": {"kind": "raid", "week": 4, "count": 1}}
	game.flags["seen_room_trace"] = true
	game.callers.here = "exchange"
	if Words.reply(game, "pete", "b") != "ok":
		_bad("pete commit")
		return false
	game.week = 6
	if not Words.reveal_follow(game, "pete"):
		_bad("pete follow")
		return false
	var snap := game.export_state()
	snap["schema"] = 26
	snap.erase("receipt_seq")
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(snap):
		_bad("schema 26 " + again.load_error)
		return false
	if int(again.receipt_seq) != 0:
		_bad("schema 26 invented a receipt sequence")
		return false
	if Words.choice_of(again, "pete") != "b" or not bool(again.shiftword_state.pete.follow_seen):
		_bad("load dropped the exchange")
		return false
	if str(again.scars.get("a|b", {}).get("kind", "")) != "raid" or not bool(again.flags.get("seen_room_trace", false)):
		_bad("load dropped scars or the room-trace flag")
		return false
	if str(again.callers.get("here", "")) != "exchange":
		_bad("load dropped callers")
		return false
	Copy.set_lang("ru")
	if Words.offer(again, "pete") != "hide":
		_bad("ru showed a vignette with empty strings")
		return false
	if Words.choice_of(again, "pete") != "b":
		_bad("locale switch rewrote the branch")
		return false
	Copy.set_lang("en")
	if Words.offer(again, "pete") != "archive":
		_bad("en did not restore the archive")
		return false
	var legacy := game.export_state()
	legacy.erase("shiftword_state")
	legacy["schema"] = 25
	var old := Game.new()
	old.catalog = catalog
	if not old.import_state(legacy):
		_bad("schema 25 " + old.load_error)
		return false
	if not old.shiftword_state.is_empty() or Words.offer(old, "pete") != "talk":
		_bad("schema 25 invented an exchange")
		return false
	if str(old.scars.get("a|b", {}).get("kind", "")) != "raid":
		_bad("schema 25 dropped scars")
		return false
	legacy["schema"] = 26
	var refused := Game.new()
	refused.catalog = catalog
	if refused.import_state(legacy):
		_bad("schema 26 accepted a missing shiftword_state")
		return false
	var current := game.export_state()
	current["schema"] = 27
	var ahead := Game.new()
	ahead.catalog = catalog
	if not ahead.import_state(current) or Words.choice_of(ahead, "pete") != "b" or int(ahead.receipt_seq) != int(game.receipt_seq):
		_bad("schema 27 dropped an exchange or receipt_seq " + ahead.load_error)
		return false
	var only_receipt := game.export_state()
	only_receipt["schema"] = 27
	only_receipt.erase("shiftword_state")
	var p97_only := Game.new()
	p97_only.catalog = catalog
	if not p97_only.import_state(only_receipt) or not p97_only.shiftword_state.is_empty():
		_bad("schema 27 P97-only save " + p97_only.load_error)
		return false
	var future := game.export_state()
	future["schema"] = 28
	var too_new := Game.new()
	too_new.catalog = catalog
	if too_new.import_state(future):
		_bad("schema 28 accepted")
		return false
	var bad := game.export_state()
	bad["schema"] = 26
	bad.shiftword_state.ruth = {"vignette_id": "ruth", "choice_id": "c", "answered_week": 4, "follow_seen": false}
	bad.shiftword_state.owen = "nope"
	var messy := Game.new()
	messy.catalog = catalog
	if not messy.import_state(bad):
		_bad("malformed row rejected the save " + messy.load_error)
		return false
	if Words.offer(messy, "ruth") != "hide" or Words.row_issue(messy, "ruth") == "":
		_bad("bad choice still offered")
		return false
	if Words.reply(messy, "ruth", "a") != "bad" or str(messy.shiftword_state.ruth.get("choice_id", "")) != "c":
		_bad("bad row was rewritten")
		return false
	if Words.offer(messy, "owen") != "hide" or Words.reply(messy, "owen", "a") == "ok":
		_bad("string row offered or committed")
		return false
	if Words.choice_of(messy, "pete") != "b":
		_bad("one bad row hid pete")
		return false
	var typed := game.export_state()
	typed["schema"] = 26
	typed.shiftword_state = []
	var wrong := Game.new()
	wrong.catalog = catalog
	if wrong.import_state(typed):
		_bad("list accepted as shiftword_state")
		return false
	var held: Dictionary = Copy.keys["shiftword.ruth.scene"]
	Copy.keys.erase("shiftword.ruth.scene")
	var quiet := _fresh(catalog)
	if Words.offer(quiet, "ruth") != "hide" or Words.reply(quiet, "ruth", "a") != "stale":
		_bad("missing scene still offered")
		return false
	if not quiet.shiftword_state.is_empty():
		_bad("missing key wrote state")
		return false
	Copy.keys["shiftword.ruth.scene"] = held
	return true


func _ui(catalog: Catalog) -> bool:
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	if st.game == null:
		_bad("no station game")
		return false
	if st.dim != null and st.dim.visible:
		st._close_card()
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	st.game.week = 3
	st._show_person("ruth")
	for _i in 4:
		await process_frame
	if _find_meta(st.card_body, "shiftword", "") != null:
		_bad("week 3 showed a control")
		return false
	st.game.week = 4
	st._show_person("ruth")
	for _i in 3:
		await process_frame
	var opener := _find_meta(st.card_body, "shiftword", "talk")
	if opener == null or str(opener.text) != "Talk between shifts":
		_bad("talk button")
		return false
	if _find_meta(st.card_body, "shiftword", "talk") != opener:
		_bad("duplicate talk")
		return false
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(10, 2400)
	st.card_body.add_child(pad)
	for _i in 3:
		await process_frame
	st.card_scroll.scroll_vertical = 180
	for _i in 2:
		await process_frame
	var scrolled := int(st.card_scroll.scroll_vertical)
	if scrolled < 40:
		_bad("card did not scroll (%d)" % scrolled)
		return false
	st.shiftword_scroll = scrolled
	st._shiftword_restore_scroll()
	for _i in 2:
		await process_frame
	if int(st.card_scroll.scroll_vertical) != scrolled:
		_bad("scroll helper %d want %d" % [int(st.card_scroll.scroll_vertical), scrolled])
		return false
	st.card_scroll.scroll_vertical = scrolled
	st._open_shiftword("ruth")
	if st.shiftword_scroll != scrolled:
		_bad("fold did not keep the person-card scroll")
		return false
	for _i in 3:
		await process_frame
	if _find_meta(st.card_body, "shiftword", "scene") == null:
		_bad("scene missing")
		return false
	if _find_meta(st.card_body, "shiftword", "reply_a") == null or _find_meta(st.card_body, "shiftword", "reply_b") == null:
		_bad("replies missing")
		return false
	st._shiftword_back()
	for _i in 4:
		await process_frame
	if not st.game.shiftword_state.is_empty():
		_bad("back wrote state")
		return false
	if st.shiftword_scroll != -1:
		_bad("back left the scroll latch set")
		return false
	var focus = st.get_viewport().gui_get_focus_owner()
	if focus == null or str(focus.get_meta("shiftword", "")) != "talk":
		_bad("focus did not return to the talk action")
		return false
	st._open_shiftword("ruth")
	for _i in 2:
		await process_frame
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	st._unhandled_key_input(ev)
	for _i in 3:
		await process_frame
	if st.shiftword_fold or not st.game.shiftword_state.is_empty():
		_bad("escape committed")
		return false
	st._open_shiftword("ruth")
	st.game.people.ruth.sick = 1
	st._shiftword_reply("ruth", "a")
	for _i in 3:
		await process_frame
	if not st.game.shiftword_state.is_empty():
		_bad("stale click committed")
		return false
	var stale := _find_meta(st.card_body, "shiftword", "unavailable")
	if stale == null or str(stale.text) != "Not here to talk.":
		_bad("stale fallback")
		return false
	if str(stale.text).find("shiftword.") >= 0:
		_bad("raw key")
		return false
	st.game.people.ruth.sick = 0
	st._shiftword_reply("ruth", "a")
	for _i in 3:
		await process_frame
	if Words.choice_of(st.game, "ruth") != "a":
		_bad("ui commit")
		return false
	if _find_meta(st.card_body, "shiftword", "answer") == null or _find_meta(st.card_body, "shiftword", "reply_a") != null:
		_bad("answer view")
		return false
	if bool(st.game.shiftword_state.ruth.follow_seen):
		_bad("follow marked on the answer week")
		return false
	st._shiftword_reply("ruth", "b")
	if Words.choice_of(st.game, "ruth") != "a":
		_bad("ui re-pick")
		return false
	st.game.week = 5
	st.game.people.ruth.absent = 1
	st._show_shiftword("ruth")
	for _i in 2:
		await process_frame
	if bool(st.game.shiftword_state.ruth.follow_seen) or _find_meta(st.card_body, "shiftword", "follow") != null:
		_bad("away week showed the callback")
		return false
	st.game.people.ruth.absent = 0
	st._show_shiftword("ruth")
	for _i in 2:
		await process_frame
	var follow := _find_meta(st.card_body, "shiftword", "follow")
	if follow == null or not bool(st.game.shiftword_state.ruth.follow_seen):
		_bad("callback not rendered")
		return false
	if str(follow.text).find("shiftword.") >= 0:
		_bad("callback raw key")
		return false
	Copy.set_lang("ru")
	st._load_fonts()
	st._show_person("ruth")
	for _i in 2:
		await process_frame
	if _find_meta(st.card_body, "shiftword", "") != null:
		_bad("ru showed the vignette")
		return false
	Copy.set_lang("en")
	st._load_fonts()
	await _shots(st)
	st.free()
	return true


func _find_meta(node: Node, key: String, value: String) -> Control:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Control and here.has_meta(key):
			if value == "" or str(here.get_meta(key)) == value:
				return here
		for child in here.get_children():
			stack.append(child)
	return null


func _shots(st) -> void:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		_shots_skipped = true
		return
	st.game.people.ruth.sick = 0
	st.game.people.ruth.absent = 0
	st.game.shiftword_state.erase("ruth")
	await _shot_set(st, "en", 1.0, "100")
	await _shot_set(st, "ru", 1.0, "100")
	await _shot_set(st, "en", 1.25, "125")


func _shot_set(st, lang: String, scale: float, tag: String) -> void:
	Copy.set_lang(lang)
	st._load_fonts()
	await _resize(st, Vector2i(1920, 1080), scale)
	st.game.week = 3
	st.game.shiftword_state.erase("ruth")
	_stamp_week(st)
	st._show_person("ruth")
	for _i in 4:
		await process_frame
	await _grab(st, "p96_%s_%s_before" % [lang, tag])
	st.game.week = 4
	_stamp_week(st)
	st._show_person("ruth")
	for _i in 4:
		await process_frame
	await _grab(st, "p96_%s_%s_after" % [lang, tag])
	if lang == "en":
		st._open_shiftword("ruth")
		for _i in 4:
			await process_frame
		await _grab(st, "p96_%s_%s_fold" % [lang, tag])
		st._shiftword_back()


func _stamp_week(st) -> void:
	if st.week_label != null and st.game != null:
		st.week_label.text = Copy.t("Week %d%s") % [int(st.game.week), ""]


func _resize(st, sz: Vector2i, scale: float) -> void:
	var win: Window = st.get_window()
	if win != null:
		win.mode = Window.MODE_WINDOWED
		win.size = sz
	root.size = Vector2(sz)
	st.set_anchors_preset(Control.PRESET_TOP_LEFT)
	st.position = Vector2.ZERO
	st.size = Vector2(sz)
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	if win != null:
		Settings.apply_scale(win)
	for _i in 2:
		await process_frame
	if st.has_method("_layout"):
		st._layout()
	if st.dim != null and st.dim.visible:
		st._fit_card()
	await process_frame


func _grab(st, shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = st.get_viewport().get_texture().get_image()
	if img == null:
		_bad("shot null " + shot_name)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/%s.png" % shot_name
	var err := img.save_png(path)
	print("SHOT %s %dx%d err %s" % [shot_name, img.get_width(), img.get_height(), err])
	if err != OK:
		_bad("shot save " + shot_name)
		return
	_shots_saved += 1


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60 or LOST_SEEDS.split(",").size() != BASELINE_LOST:
		_bad("baseline missing")
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
		if not (on.state as Dictionary).is_empty() or not (off.state as Dictionary).is_empty():
			_bad("seed %d careful wrote an exchange" % run_seed)
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
	Words.enabled = on
	var game := Game.new()
	# stats.best_score is filled from user://records.cfg at game over. A second
	# Godot (rendered pass, another gate) can change that file between the on
	# and off plays and fail this equality without moving the sim.
	game.records_path = "user://check_between_shifts_%d.cfg" % OS.get_process_id()
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
			for id in SPEAKERS:
				Words.present(game, id)
				Words.offer(game, id)
				Words.line(Words.person_key(id, "scene"))
	Words.enabled = true
	var data := game.export_state()
	data.erase("shiftword_state")
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"snap": JSON.stringify(data),
		"summary": str(game.report().get("summary", "")),
		"rng": _rng(game),
		"state": game.shiftword_state.duplicate(true),
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
