extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")

## P68 Epilogue. Verdict, chronicle top 6, fates, judgment, score.
## No win/loss change. No Mandate +100. Soft dawn stays the four-chip stack.
##   godot --headless --path . -s res://sim/check_epilogue.gd

const ENDINGS := ["time", "revolt", "hope", "collapse", "capital"]
const CREEDS := ["watch", "chapel", "market", "none"]
const JUDGMENTS := [
	"sent_down", "sealed_sick", "turned_away", "sold_route", "ledger_dead", "timetable",
	"covenant", "price", "cough_list", "held_stations", "floor_papers", "quiet_survive",
]
const CHROME := {
	"epilogue.score": {"en": "Score {n} · Best {best}", "ru": "Счёт {n} · Лучший {best}"},
	"epilogue.chronicle_empty": {"en": "Nothing the yard kept.", "ru": "Двор ничего не сохранил."},
	"epilogue.next": {"en": "Next", "ru": "Дальше"},
	"epilogue.back": {"en": "Back", "ru": "Назад"},
	"epilogue.close": {"en": "Close", "ru": "Закрыть"},
	"epilogue.page_verdict": {"en": "Verdict", "ru": "Приговор"},
	"epilogue.page_chronicle": {"en": "Chronicle", "ru": "Летопись"},
	"epilogue.page_fates": {"en": "Fates", "ru": "Судьбы"},
}
const DAWN := ["rumor", "border.dawn_new", "rail", "homecoming"]


func _init() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/epilogues.json"))
	var balance_before := FileAccess.get_file_as_string("res://data/balance.json")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	var strings_ok := _check_strings(pack)
	var verdict_ok := _check_verdict(catalog, pack)
	var chronicle_ok := _check_chronicle(catalog, pack)
	var fates_ok := _check_fates(catalog, pack)
	var score_ok := _check_score(catalog)
	var dawn_ok := _check_dawn(catalog)
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_before:
		print("Balance: FAIL balance.json changed")
		score_ok = false
	print("Strings: %s" % ("ok" if strings_ok else "fail"))
	print("Verdict: %s" % ("ok" if verdict_ok else "fail"))
	print("Chronicle: %s" % ("ok" if chronicle_ok else "fail"))
	print("Fates: %s" % ("ok" if fates_ok else "fail"))
	print("Score: %s" % ("ok" if score_ok else "fail"))
	print("Dawn: %s" % ("ok" if dawn_ok else "fail"))
	if strings_ok and verdict_ok and chronicle_ok and fates_ok and score_ok and dawn_ok:
		print("EPILOGUE OK")
		quit(0)
		return
	print("EPILOGUE FAIL")
	quit(1)


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.records_path = "user://check_epilogue_%d.cfg" % OS.get_process_id()
	return game


func _check_strings(pack: Dictionary) -> bool:
	var ok := true
	if str(pack.get("_roadmap", "")) != "P68":
		print("Strings: FAIL roadmap ", pack.get("_roadmap", ""))
		ok = false
	var verdicts: Dictionary = pack.get("verdicts", {})
	if verdicts.size() != 5:
		print("Strings: FAIL verdict endings ", verdicts.size())
		ok = false
	for ending in ENDINGS:
		var row: Dictionary = verdicts.get(ending, {})
		if row.size() != 4:
			print("Strings: FAIL %s creeds %d" % [ending, row.size()])
			ok = false
			continue
		for creed in CREEDS:
			var line: Dictionary = row.get(creed, {})
			if str(line.get("en", "")) == "" or str(line.get("ru", "")) == "":
				print("Strings: FAIL empty verdict %s %s" % [ending, creed])
				ok = false
	var judgments: Array = pack.get("judgments", [])
	if judgments.size() != 12:
		print("Strings: FAIL judgments %d" % judgments.size())
		ok = false
	var seen := {}
	for row in judgments:
		var id := str(row.get("id", ""))
		seen[id] = true
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			print("Strings: FAIL empty judgment ", id)
			ok = false
	for id in JUDGMENTS:
		if not seen.has(id):
			print("Strings: FAIL missing judgment ", id)
			ok = false
	var fates: Array = pack.get("fates", [])
	if fates.size() != 30:
		print("Strings: FAIL fates %d" % fates.size())
		ok = false
	for row in fates:
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			print("Strings: FAIL empty fate ", row.get("id", ""))
			ok = false
	var chronicle: Array = pack.get("chronicle", [])
	if chronicle.size() != 16:
		print("Strings: FAIL chronicle %d" % chronicle.size())
		ok = false
	var kinds := {}
	for row in chronicle:
		kinds[str(row.get("kind", ""))] = true
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			print("Strings: FAIL empty chronicle ", row.get("kind", ""))
			ok = false
	for kind in ["named_death", "creed_line", "station_taken", "station_lost", "dilemma", "season", "crunch"]:
		if not kinds.has(kind):
			print("Strings: FAIL missing chronicle ", kind)
			ok = false
	var by_key: Dictionary = pack.get("by_key", {})
	for key in CHROME:
		var want: Dictionary = CHROME[key]
		var got: Dictionary = by_key.get(key, {})
		if str(got.get("en", "")) != str(want.en) or str(got.get("ru", "")) != str(want.ru):
			print("Strings: FAIL by_key ", key)
			ok = false
		Copy.set_lang("en")
		if Copy.t(key) != str(want.en):
			print("Strings: FAIL en Copy ", key, " ", Copy.t(key))
			ok = false
		Copy.set_lang("ru")
		if Copy.t(key) != str(want.ru):
			print("Strings: FAIL ru Copy ", key, " ", Copy.t(key))
			ok = false
	Copy.set_lang("en")
	if Copy.fill("epilogue.score", {"n": 482, "best": 510}) != "Score 482 · Best 510":
		print("Strings: FAIL score fill ", Copy.fill("epilogue.score", {"n": 482, "best": 510}))
		ok = false
	Copy.set_lang("ru")
	if Copy.fill("epilogue.score", {"n": 482, "best": 510}) != "Счёт 482 · Лучший 510":
		print("Strings: FAIL ru score fill ", Copy.fill("epilogue.score", {"n": 482, "best": 510}))
		ok = false
	Copy.set_lang("en")
	return ok


func _check_verdict(catalog: Catalog, pack: Dictionary) -> bool:
	var ok := true
	var game := _game(catalog)
	Copy.set_lang("en")
	for ending in ENDINGS:
		for creed in CREEDS:
			game.over = ending
			game.creed = creed
			var want := str(pack.verdicts[ending][creed].en)
			if game.verdict_line() != want:
				print("Verdict: FAIL %s %s got %s" % [ending, creed, game.verdict_line()])
				ok = false
	Copy.set_lang("ru")
	game.over = "time"
	game.creed = "watch"
	if game.verdict_line() != str(pack.verdicts.time.watch.ru):
		print("Verdict: FAIL ru watch ", game.verdict_line())
		ok = false
	Copy.set_lang("en")
	game.over = "error"
	game.creed = "watch"
	if game.verdict_line() != "" or game.ending_fallback() != "The week broke.":
		print("Verdict: FAIL error fallback ", game.verdict_line(), " / ", game.ending_fallback())
		ok = false
	game.over = "bogus"
	if game.verdict_line() != "" or game.ending_fallback() != "The run is over.":
		print("Verdict: FAIL unknown fallback")
		ok = false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	for needle in [
		"over = \"collapse\"",
		"over = \"hope\"",
		"over = \"revolt\"",
		"over = \"time\"",
		"over = \"capital\"",
	]:
		if src.find(needle) < 0:
			print("Verdict: FAIL missing win/loss setter ", needle)
			ok = false
	var rules := _game(catalog)
	while rules.residents.size() >= 8:
		var person: Dictionary = rules.residents.pop_back()
		rules.people.erase(str(person.get("id", "")))
	rules.hope = 40
	rules.discontent = 10
	rules.week = 3
	rules.hope_zero = 0
	rules._finish_checks()
	if rules.over != "collapse":
		print("Verdict: FAIL collapse setter now ", rules.over)
		ok = false
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("ModalDeck.NARRATIVE, \"ending\"") < 0:
		print("Verdict: FAIL ending claim")
		ok = false
	if ui.find("game.ending_fallback()") < 0:
		print("Verdict: FAIL quiet fallback not wired")
		ok = false
	return ok


func _check_chronicle(catalog: Catalog, pack: Dictionary) -> bool:
	var ok := true
	var game := _game(catalog)
	game.chronicle.clear()
	if not game.chronicle_top(6).is_empty():
		print("Chronicle: FAIL empty run returned moments")
		ok = false
	if Copy.t("epilogue.chronicle_empty") != "Nothing the yard kept.":
		print("Chronicle: FAIL empty string")
		ok = false
	var rows := [
		[6, "season", {"season": "cold"}, 2],
		[9, "named_death", {"name": "Rhee", "cause": "cough"}, 5],
		[4, "dilemma", {"title": "The Gate", "choice": "turn away"}, 3],
		[3, "crunch", {}, 2],
		[7, "station_lost", {"place": "Stillwell"}, 3],
		[8, "creed_line", {"law": "the Timetable"}, 5],
		[5, "station_taken", {"place": "Coney Island"}, 3],
		[1, "clear", {}, 1],
	]
	for row in rows:
		game.week = int(row[0])
		game._note_moment(str(row[1]), row[2], int(row[3]))
	var top: Array = game.chronicle_top(6)
	if top.size() != 6:
		print("Chronicle: FAIL size ", top.size())
		ok = false
	var kinds: PackedStringArray = []
	for moment in top:
		kinds.append(str(moment.get("kind", "")))
		if str(moment.get("text", "")).find("Week ") < 0 and str(moment.get("kind", "")) != "crunch" and str(moment.get("kind", "")) != "clear":
			print("Chronicle: FAIL line ", moment.get("text", ""))
			ok = false
	var want := ["named_death", "creed_line", "station_lost", "station_taken", "dilemma", "season"]
	if kinds != PackedStringArray(want):
		print("Chronicle: FAIL order ", kinds)
		ok = false
	if str(top[0].get("text", "")) != "Week 9: Rhee died — cough.":
		print("Chronicle: FAIL death line ", top[0].get("text", ""))
		ok = false
	for moment in top:
		if str(moment.get("kind", "")) == "clear" or int(moment.get("weight", 0)) < 2:
			print("Chronicle: FAIL kept a light moment ", moment)
			ok = false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	for pair in [
		["_note_moment(\"named_death\",", ", 5)"],
		["_note_moment(\"creed_line\",", ", 5)"],
		["_note_moment(\"station_taken\",", ", 3)"],
		["_note_moment(\"station_lost\",", ", 3)"],
		["_note_moment(\"dilemma\",", ", 3)"],
		["_note_moment(\"season\",", ", 2)"],
		["_note_moment(\"crunch\",", ", 2)"],
	]:
		var at := src.find(pair[0])
		if at < 0 or src.substr(at, 220).find(pair[1]) < 0:
			print("Chronicle: FAIL weight site ", pair[0])
			ok = false
	if pack.chronicle.is_empty():
		ok = false
	return ok


func _check_fates(catalog: Catalog, pack: Dictionary) -> bool:
	var ok := true
	var game := _game(catalog)
	game.over = "time"
	game.week = 40
	var lines := game.fate_lines()
	if lines.size() != 8:
		print("Fates: FAIL count ", lines.size(), " council ", game.council.size())
		ok = false
	for seat in game.council:
		var info: Dictionary = game._person_record(str(seat.id))
		var name := str(info.get("name", ""))
		var hit := false
		for line in lines:
			if line.find(name) >= 0:
				hit = true
		if not hit:
			print("Fates: FAIL council missing ", name)
			ok = false
	if lines.size() > 8:
		print("Fates: FAIL overflow")
		ok = false
	var ranked: Array = []
	for person in game.residents:
		var id := str(person.get("id", ""))
		var on_council := false
		for seat in game.council:
			if str(seat.id) == id:
				on_council = true
		if not on_council:
			ranked.append(person)
	ranked.sort_custom(func(a, b): return int(a.get("memory", 0)) > int(b.get("memory", 0)))
	for i in mini(5, ranked.size()):
		ranked[i].memory = 80 - i * 10
	if ranked.size() > 5:
		ranked[5].memory = 1
	var picked := game.fate_lines()
	for i in mini(5, ranked.size()):
		var name := str(ranked[i].get("name", ""))
		var hit := false
		for line in picked:
			if line.find(name) >= 0:
				hit = true
		if not hit:
			print("Fates: FAIL memory ", name)
			ok = false
	if ranked.size() > 5:
		var low := str(ranked[5].get("name", ""))
		for line in picked:
			if line.find(low) >= 0:
				print("Fates: FAIL showed sixth resident ", low)
				ok = false
	game.chronicle.clear()
	game.creed = "watch"
	game.week = 12
	game._note_moment("named_death", {"name": "Rhee", "cause": "cough", "who": "x"}, 5)
	if game._judgment_id() != "cough_list":
		print("Fates: FAIL judgment ", game._judgment_id())
		ok = false
	var cough := ""
	for row in pack.judgments:
		if str(row.get("id", "")) == "cough_list":
			cough = str(row.get("en", ""))
	if game.judgment_line() != cough:
		print("Fates: FAIL judgment line ", game.judgment_line())
		ok = false
	game.chronicle.clear()
	game._note_moment("station_taken_force", {"place": "Yard"}, 5)
	if game._judgment_id() != "held_stations":
		print("Fates: FAIL force judgment ", game._judgment_id())
		ok = false
	if game.judgment_line().find("mandate") >= 0 or game.judgment_line().find("+100") >= 0:
		print("Fates: FAIL mandate in judgment")
		ok = false
	var payload: Dictionary = game.epilogue_payload()
	if payload.get("fates", []).size() > 8 or str(payload.get("judgment", "")) == "":
		print("Fates: FAIL payload")
		ok = false
	return ok


func _check_score(catalog: Catalog) -> bool:
	var ok := true
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func score_now()")
	var body := src.substr(at, 280)
	if body.find("100") >= 0 or body.find("mandate") >= 0 or body.find("_mandate_fulfilled") >= 0:
		print("Score: FAIL mandate still in score_now")
		ok = false
	var game := _game(catalog)
	game.week = 10
	game.hope = 7
	game.stats.named_dead = 2
	var expect := 10 * 10 + game.residents.size() * 2 + game.owned_count() * 15 + 7 - 2 * 5
	if game.score_now() != expect:
		print("Score: FAIL formula ", game.score_now(), " want ", expect)
		ok = false
	game.stats.mandate_fulfilled = true
	if game.score_now() != expect:
		print("Score: FAIL mandate changed the score ", game.score_now())
		ok = false
	var path := game.records_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.over = "time"
	game.stats.scored = false
	game._seal_score()
	if int(game.stats.score) != expect or int(game.stats.best_score) != expect:
		print("Score: FAIL seal ", game.stats.get("score", ""), " best ", game.stats.get("best_score", ""))
		ok = false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or int(cfg.get_value("scores", "best", 0)) != expect:
		print("Score: FAIL records.cfg ", cfg.get_value("scores", "best", -1))
		ok = false
	var lower := _game(catalog)
	lower.records_path = path
	lower.week = 1
	lower.hope = 0
	lower.stats.named_dead = 0
	lower.over = "collapse"
	lower.stats.scored = false
	var low := lower.score_now()
	lower._seal_score()
	if low >= expect or int(lower.stats.best_score) != expect:
		print("Score: FAIL best dropped ", lower.stats.best_score, " low ", low)
		ok = false
	var higher := _game(catalog)
	higher.records_path = path
	higher.week = 40
	higher.hope = 80
	higher.stats.named_dead = 0
	higher.over = "time"
	higher.stats.scored = false
	var high := higher.score_now()
	higher._seal_score()
	if high <= expect or int(higher.stats.best_score) != high:
		print("Score: FAIL best did not rise ", higher.stats.best_score, " high ", high)
		ok = false
	if cfg.load(path) != OK or int(cfg.get_value("scores", "best", 0)) != high:
		print("Score: FAIL records best ", cfg.get_value("scores", "best", -1))
		ok = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("Copy.fill(\"epilogue.score\"") < 0:
		print("Score: FAIL display fill missing")
		ok = false
	if ui.find("epilogue.score_parts") >= 0:
		print("Score: FAIL formula still on the card")
		ok = false
	return ok


func _check_dawn(catalog: Catalog) -> bool:
	var ok := true
	var game := _game(catalog)
	var stack: Array = game.dawn_soft_stack()
	if stack != DAWN:
		print("Dawn: FAIL stack ", stack)
		ok = false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") < 0:
		print("Dawn: FAIL const moved")
		ok = false
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	var a := ui.find("func _show_life_epilogue")
	var b := ui.find("func _life_epilogue_input")
	var chunk := ui.substr(a, b - a)
	for needle in ["present_dawn_soft_chip", "dawn_soft", "border.dawn_new", "homecoming", "rumor_dawn"]:
		if chunk.find(needle) >= 0:
			print("Dawn: FAIL epilogue mentions ", needle)
			ok = false
	for key in ["epilogue.next", "epilogue.back", "epilogue.close", "epilogue.page_verdict", "epilogue.page_chronicle", "epilogue.page_fates", "epilogue.chronicle_empty"]:
		if chunk.find(key) < 0:
			print("Dawn: FAIL card missing ", key)
			ok = false
	if chunk.find("if _motion_off():") < 0 or chunk.find("life_epilogue_body.modulate.a = 1.0") < 0:
		print("Dawn: FAIL reduce-motion is not static")
		ok = false
	if chunk.find("create_tween()") >= 0 and chunk.find("if _motion_off():") > chunk.find("create_tween()"):
		print("Dawn: FAIL tween runs before the motion check")
		ok = false
	if game.party_away_dawn_chip() or game.sick_cots_dawn_chip():
		print("Dawn: FAIL a neighbor chip turned on")
		ok = false
	return ok
