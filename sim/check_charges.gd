extends SceneTree

const ChargesMandate = preload("res://sim/charges_mandate.gd")

## P73 gate.
##   godot --headless --path . -s res://sim/check_charges.gd

var strings_ok := true
var charges_ok := true
var promise_ok := true
var mandate_ok := true
var ticker_ok := true
var dawn_ok := true
var other_ok := true
var lost := 0


func _init() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Strings: fail")
		print("Charges: fail")
		print("Promise: fail")
		print("Mandate: fail")
		print("Ticker: fail")
		print("Dawn: fail")
		print("careful 0/60 (0.0%%)")
		print("CHARGES MANDATE FAIL catalog " + catalog.error)
		quit(1)
		return
	_strings()
	_charges(catalog)
	_promise(catalog)
	_mandate(catalog)
	_ticker(catalog)
	_dawn(catalog)
	_persist(catalog)
	_seals()
	lost = _careful(catalog)
	var pct := 100.0 * float(lost) / 60.0
	print("Strings: %s" % ("ok" if strings_ok else "fail"))
	print("Charges: %s" % ("ok" if charges_ok else "fail"))
	print("Promise: %s" % ("ok" if promise_ok else "fail"))
	print("Mandate: %s" % ("ok" if mandate_ok else "fail"))
	print("Ticker: %s" % ("ok" if ticker_ok else "fail"))
	if dawn_ok:
		print("Dawn: ok  (soft dawn unchanged — P73 does not join)")
	else:
		print("Dawn: fail")
	print("careful %d/60 (%.1f%%)" % [lost, pct])
	var band_ok := lost <= 21
	if strings_ok and charges_ok and promise_ok and mandate_ok and ticker_ok and dawn_ok and other_ok and band_ok:
		print("CHARGES MANDATE OK")
		quit(0)
	else:
		print("CHARGES MANDATE FAIL")
		quit(1)


func _bad(section: String, msg: String) -> void:
	print("FAIL %s %s" % [section, msg])
	match section:
		"strings":
			strings_ok = false
		"charges":
			charges_ok = false
		"promise":
			promise_ok = false
		"mandate":
			mandate_ok = false
		"ticker":
			ticker_ok = false
		"dawn":
			dawn_ok = false
		_:
			other_ok = false


func _strings() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/charges.json"))
	if not (pack is Dictionary) or not ((pack as Dictionary).get("by_key") is Dictionary):
		_bad("strings", "charges.json by_key")
		return
	var rows: Dictionary = pack.by_key
	if rows.size() < 80:
		_bad("strings", "by_key count %d" % rows.size())
	Copy.set_lang("en")
	for key in rows:
		var want := str(rows[key].get("en", ""))
		if Copy.t(str(key)) != want:
			_bad("strings", "EN %s got %s" % [str(key), Copy.t(str(key))])
	Copy.set_lang("ru")
	for key in rows:
		var want_ru := str(rows[key].get("ru", ""))
		if Copy.t(str(key)) != want_ru:
			_bad("strings", "RU %s got %s" % [str(key), Copy.t(str(key))])
	Copy.set_lang("en")
	if Copy.t("promise.refused") != "They heard no.":
		_bad("strings", "promise.refused")
	if Copy.t("promise.cooldown") != "Not asking again yet.":
		_bad("strings", "promise.cooldown")
	if Copy.t("mandate.confirm") != "Confirm Mandates":
		_bad("strings", "mandate.confirm")
	if Copy.t("mandate.need_three") != "Pick three.":
		_bad("strings", "mandate.need_three")
	if pack.get("charges", []).size() != 30 or pack.get("promises", []).size() != 8 or pack.get("mandates", []).size() != 5:
		_bad("strings", "pool counts")


func _fresh(catalog: Catalog, run_seed := 1) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _stock_snap(game: Game) -> Dictionary:
	var out := {}
	for key in ["food", "air", "power", "materials", "tokens", "influence", "blueprints"]:
		out[key] = int(game.stock.get(key, 0))
	return out


func _rng_snap(game: Game) -> Array:
	return [game.rng.state, game.crunch_rng.state, game.net_rng.state, game.check_rng.state, game.story_rng.state]


func _charges(catalog: Catalog) -> void:
	var game := _fresh(catalog)
	var saw3: bool = game.charges.active.size() == 3
	for _i in 15:
		if game.charges.active.size() > 3:
			_bad("charges", "cap %d" % game.charges.active.size())
			return
		if game.charges.active.size() == 3:
			saw3 = true
		game.week += 1
		game._tick_charges()
	if game.charges.active.size() > 3 or not saw3:
		_bad("charges", "active %d saw3 %s" % [game.charges.active.size(), saw3])
	var fail := _fresh(catalog, 2)
	var hope0 := fail.hope
	var dis0 := fail.discontent
	var stock0 := _stock_snap(fail)
	var rng0 := _rng_snap(fail)
	fail.notices.clear()
	fail.charges.active = [{"id": "dig_level_3", "due": fail.week, "reward": "blueprint", "streak": 0, "base": 0, "born": 0}]
	fail._tick_charges()
	if fail.hope != hope0 or fail.discontent != dis0:
		_bad("charges", "fail moved hope/dis %d/%d" % [fail.hope, fail.discontent])
	var stock1 := _stock_snap(fail)
	for key in stock0:
		if int(stock1[key]) != int(stock0[key]):
			_bad("charges", "fail moved %s" % key)
	if _rng_snap(fail) != rng0:
		_bad("charges", "tick touched the main rng")
	var failed_note := false
	for note in fail.notices:
		if str(note) == Copy.t("charge.failed"):
			failed_note = true
	if not failed_note:
		_bad("charges", "missing charge.failed")
	var done := _fresh(catalog, 3)
	var bp0 := int(done.stock.get("blueprints", 0))
	var hope1 := done.hope
	var dis1 := done.discontent
	done.notices.clear()
	done.cells["2:2"].dug = true
	done.charges.active = [{"id": "dig_level_3", "due": done.week + 4, "reward": "blueprint", "streak": 0, "base": 0, "born": 0}]
	done._tick_charges()
	if int(done.stock.get("blueprints", 0)) != bp0 + 1:
		_bad("charges", "blueprint %s" % done.stock.get("blueprints", 0))
	if done.hope != hope1 or done.discontent != dis1:
		_bad("charges", "blueprint reward moved hope/dis")
	var done_note := false
	for note in done.notices:
		if str(note) == Copy.t("charge.done"):
			done_note = true
	if not done_note:
		_bad("charges", "missing charge.done")
	if done.charges.active.size() > 3:
		_bad("charges", "cap after grant")


func _promise_event(game: Game) -> Dictionary:
	for ev in game.pending:
		if str(ev.get("cm", "")) == "promise":
			return ev
	return {}


func _promise(catalog: Catalog) -> void:
	var game := _fresh(catalog, 4)
	game.pending.clear()
	game.discontent = 70
	game.promise.prev_dis = 50
	game.promise.status = ""
	game._tick_charges()
	var ev := _promise_event(game)
	if ev.is_empty():
		_bad("promise", "rising edge did not offer")
		return
	var again := 0
	for row in game.pending:
		if str(row.get("cm", "")) == "promise":
			again += 1
	if again != 1:
		_bad("promise", "offer count %d" % again)
	var dis_before := game.discontent
	if not game.apply({"kind": "event", "event_id": str(ev.id), "choice_id": "accept"}):
		_bad("promise", "accept did not apply")
		return
	if game.discontent != dis_before - 8:
		_bad("promise", "accept dis %d -> %d" % [dis_before, game.discontent])
	if str(game.promise.status) != "active":
		_bad("promise", "accept status %s" % game.promise.status)
	game.promise.id = "no_shortage_3"
	game.promise.clean = 2
	game.week = int(game.promise.born) + 1
	var hope_before := game.hope
	game.notices.clear()
	game._tick_charges()
	if game.hope != hope_before + 3:
		_bad("promise", "keep hope %d -> %d" % [hope_before, game.hope])
	if not game.notices.has(Copy.t("promise.kept")):
		_bad("promise", "missing promise.kept")
	var broke := _fresh(catalog, 5)
	broke.promise.status = "active"
	broke.promise.id = "no_shortage_3"
	broke.promise.born = 0
	broke.promise.due = broke.week
	broke.promise.clean = 0
	broke.flags["cm_food_short"] = broke.week - 1
	var hope_b := broke.hope
	var dis_b := broke.discontent
	broke.notices.clear()
	broke._tick_charges()
	if broke.discontent != dis_b + 15 or broke.hope != hope_b - 3:
		_bad("promise", "break dis %d hope %d" % [broke.discontent - dis_b, broke.hope - hope_b])
	if not broke.notices.has(Copy.t("promise.broke")):
		_bad("promise", "missing promise.broke")
	var decline := _fresh(catalog, 6)
	decline.pending.clear()
	decline.discontent = 70
	decline.promise.prev_dis = 50
	decline.promise.status = ""
	decline.notices.clear()
	decline._tick_charges()
	var offer := _promise_event(decline)
	if offer.is_empty():
		_bad("promise", "decline setup had no offer")
		return
	if not decline.apply({"kind": "event", "event_id": str(offer.id), "choice_id": "decline"}):
		_bad("promise", "decline did not apply")
		return
	if not decline.notices.has(Copy.t("promise.refused")):
		_bad("promise", "missing promise.refused")
	if int(decline.promise.cooldown_until) != decline.week + 4 or not bool(decline.promise.refused_recent):
		_bad("promise", "cooldown %s" % decline.promise.cooldown_until)
	decline.notices.clear()
	decline.pending.clear()
	decline.promise.prev_dis = 50
	decline.discontent = 70
	decline._tick_charges()
	if not _promise_event(decline).is_empty():
		_bad("promise", "offered during cooldown")
	if not decline.notices.has(Copy.t("promise.cooldown")):
		_bad("promise", "missing promise.cooldown")
	decline.notices.clear()
	decline.promise.prev_dis = 50
	decline._tick_charges()
	if decline.notices.has(Copy.t("promise.cooldown")):
		_bad("promise", "cooldown tip repeated")
	var busy := _fresh(catalog, 7)
	busy.pending.clear()
	busy.promise.status = "active"
	busy.promise.id = "squad_rest"
	busy.promise.born = busy.week
	busy.promise.due = busy.week + 4
	busy.promise.prev_dis = 50
	busy.discontent = 80
	busy._tick_charges()
	if not _promise_event(busy).is_empty():
		_bad("promise", "second promise while one is active")


func _mandate(catalog: Catalog) -> void:
	var game := _fresh(catalog, 8)
	game.week = 8
	game.pending.clear()
	game.mandate.offered = false
	game.mandate.picked = []
	game._tick_charges()
	var n := 0
	for ev in game.pending:
		if str(ev.get("cm", "")) == "mandate":
			n += 1
	if n != 1:
		_bad("mandate", "week 8 offers %d" % n)
	game._tick_charges()
	n = 0
	for ev in game.pending:
		if str(ev.get("cm", "")) == "mandate":
			n += 1
	if n != 1:
		_bad("mandate", "second offer %d" % n)
	if game.commit_mandate(["hold_coney", "unite_brooklyn"]):
		_bad("mandate", "commit of 2 succeeded")
	if not game.commit_mandate(["hold_coney", "unite_brooklyn", "reach_floor"]):
		_bad("mandate", "commit of 3 failed")
	var line := game.mandate_progress_line()
	if line.find(" · ") < 0 or line.find("Hold the Coney line") < 0 or line.find("Unite Brooklyn") < 0:
		_bad("mandate", "progress line %s" % line)
	var miss := _fresh(catalog, 9)
	miss.mandate.picked = ["hold_coney", "unite_brooklyn", "reach_floor"]
	miss.mandate.show_progress = true
	miss.mandate.offered = true
	var over0 := str(miss.over)
	ChargesMandate.before_score(miss)
	if bool(miss.stats.get("mandate_fulfilled", false)):
		_bad("mandate", "miss set the fulfill flag")
	if miss.mandate_progress_line() != "":
		_bad("mandate", "miss left progress %s" % miss.mandate_progress_line())
	if str(miss.over) != over0:
		_bad("mandate", "miss changed over to %s" % miss.over)
	var hit := _fresh(catalog, 10)
	hit.mandate.picked = ["unite_brooklyn", "reach_floor", "faith_dead"]
	hit.mandate.show_progress = true
	hit.mandate.offered = true
	var owned := 0
	for sid in hit.stations:
		if str(hit.stations[sid].owner) == hit.player:
			owned += 1
		elif owned < 5:
			hit.stations[sid].owner = hit.player
			owned += 1
	hit.artifacts.papers = 3
	hit.floor_met = true
	hit.week = 33
	var before := hit.score_now()
	var over1 := str(hit.over)
	ChargesMandate.before_score(hit)
	if not bool(hit.stats.get("mandate_fulfilled", false)):
		_bad("mandate", "fulfill did not set the P68 flag")
	if hit.score_now() - before != 100:
		_bad("mandate", "score delta %d" % (hit.score_now() - before))
	if str(hit.over) != over1:
		_bad("mandate", "fulfill changed over")
	if not hit.notices.has(Copy.t("mandate.fulfilled")):
		_bad("mandate", "missing mandate.fulfilled")


func _ticker(catalog: Catalog) -> void:
	var game := _fresh(catalog, 11)
	for season in game.seasons:
		season["week"] = 0
	game.expedition = {}
	game.build = {}
	game.law_lock = 0
	game.charges.active = []
	game.promise.status = ""
	game.demands = []
	if game.squads.has(game.player):
		game.squads[game.player].returning = false
	if not game.ticker_items().is_empty():
		_bad("ticker", "empty strip showed %s" % str(game.ticker_items()))
	game.week = 10
	game.demands = [{"paid": false, "deadline": 2, "faction": "exchange", "amount": 5}]
	game.seasons = [{"id": "cough", "week": 12, "weeks": 2}]
	game.charges.active = [{"id": "dig_level_3", "due": 12, "reward": "blueprint", "streak": 0, "base": 0, "born": 1}]
	game.promise.status = "active"
	game.promise.due = 12
	game.expedition = {"left": 2, "tunnel": "to_ferry"}
	game.build = {"left": 2, "type": "quarters"}
	game.law_lock = 2
	var items: Array = game.ticker_items()
	if items.size() != 4:
		_bad("ticker", "tie size %d" % items.size())
		return
	var kinds: PackedStringArray = []
	for row in items:
		kinds.append(str(row.get("kind", "")))
	var want := "ultimatum,season,charge,promise"
	if ",".join(kinds) != want:
		_bad("ticker", "order %s" % ",".join(kinds))
	for row in items:
		if int(row.get("n", 0)) < 1:
			_bad("ticker", "non-positive week")


func _dawn(catalog: Catalog) -> void:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var end := src.find("\nfunc dawn_soft_chip", at)
	var picker := src.substr(at, end - at)
	if picker.find("rumor") < 0 or picker.find("border") < 0 or picker.find("rail_noise") < 0:
		_bad("dawn", "soft stack order changed")
	if picker.find("charge") >= 0 or picker.find("promise") >= 0 or picker.find("mandate") >= 0:
		_bad("dawn", "soft picker mentions P73")
	var game := _fresh(catalog, 12)
	game.flags["rumor_dawn"] = true
	var chip: Dictionary = game._pick_dawn_soft_chip()
	if str(chip.get("kind", "")) != "rumor":
		_bad("dawn", "rumor did not win")
	game.flags.erase("rumor_dawn")
	game.flags["border_dawn_new"] = true
	chip = game._pick_dawn_soft_chip()
	if str(chip.get("kind", "")) != "border_new":
		_bad("dawn", "border did not win")
	game.flags.erase("border_dawn_new")
	game.flags.erase("rail_dawn")
	game.flags.erase("home_shown")
	game._tick_charges()
	for key in ["rumor_dawn", "border_dawn_new", "rail_dawn", "home_shown"]:
		if game.flags.has(key):
			_bad("dawn", "tick set %s" % key)


func _persist(catalog: Catalog) -> void:
	var game := _fresh(catalog, 13)
	game.charges.active = [{"id": "penn_cool", "due": 6, "reward": "intel", "streak": 1, "base": 0, "born": 1}]
	game.promise.status = "active"
	game.promise.id = "feed_full"
	game.mandate.picked = ["faith_dead", "line_capital", "reach_floor"]
	game.mandate.show_progress = true
	var data := game.export_state()
	data.schema = 15
	var other := Game.new()
	other.catalog = catalog
	if not other.import_state(data):
		_bad("persist", other.load_error)
		return
	if other.charges.active.is_empty() or str(other.charges.active[0].get("id", "")) != "penn_cool":
		_bad("persist", "charges did not round-trip")
	if str(other.promise.get("id", "")) != "feed_full" or str(other.promise.get("status", "")) != "active":
		_bad("persist", "promise did not round-trip")
	if other.mandate.picked.size() != 3 or not bool(other.mandate.show_progress):
		_bad("persist", "mandate did not round-trip")
	var legacy := game.export_state()
	legacy.schema = 14
	legacy.erase("charges")
	legacy.erase("promise")
	legacy.erase("mandate")
	var staged: Dictionary = Game.stage_state(legacy, catalog)
	if str(staged.get("error", "")) != "":
		_bad("persist", "schema 14 " + str(staged.error))
		return
	var state: Dictionary = staged.state
	if not (state.get("charges") is Dictionary) or not (state.get("promise") is Dictionary) or not (state.get("mandate") is Dictionary):
		_bad("persist", "schema 14 did not migrate")


func _seals() -> void:
	var want := {
		"res://assets/icons/ui/mandate_hold_coney.png": "0e6b52aa24ed446c7fb55c89673455d8",
		"res://assets/icons/ui/mandate_unite_brooklyn.png": "a52172f208f7f9264bb7835859abe608",
		"res://assets/icons/ui/mandate_reach_floor.png": "527ad30c2ca9d6d9cb8206c5a536f81f",
		"res://assets/icons/ui/mandate_faith_dead.png": "450ed6aa02814eaab75f77f3941c2eba",
		"res://assets/icons/ui/mandate_line_capital.png": "cbfd8fc89d173c0406c8561875f769eb",
	}
	for path in want:
		if not FileAccess.file_exists(path):
			continue
		var got := FileAccess.get_md5(path)
		if got != str(want[path]):
			_bad("seals", "%s md5 %s" % [path, got])


func _careful(catalog: Catalog) -> int:
	var n_lost := 0
	var promise_touch := 0
	var errors := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 48:
			guard += 1
			bot._act(game)
			game.end_week()
		if str(game.over) != "time":
			n_lost += 1
		if not game.errors.is_empty():
			errors += 1
			if errors == 1:
				_bad("careful", "seed %d %s" % [run_seed, str(game.errors[0])])
		if int(game.hope_totals.get("promise", 0)) != 0 or int(game.dis_totals.get("promise", 0)) != 0:
			promise_touch += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, n_lost])
	if promise_touch != 0:
		_bad("promise", "careful resolved %d promises" % promise_touch)
	if errors != 0:
		_bad("careful", "errors on %d seeds" % errors)
	if n_lost > 21:
		_bad("careful", "losses %d/60" % n_lost)
	return n_lost
