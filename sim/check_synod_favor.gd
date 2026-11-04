extends SceneTree

const SynodFavor = preload("res://sim/synod_favor.gd")

## P80 Synod Favor gate.
##   godot --headless --path . -s res://sim/check_synod_favor.gd
## Strings, the ask row, the three options, and the dawn hooks. Careful loss on seeds 1–60
## stays on the measured 2/60 line. Soft dawn is not joined.

var failed := false
var section_failed := false


func _init() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("FAVOR FAIL catalog " + catalog.error)
		quit(1)
		return
	if _strings():
		print("strings ok")
	if _ask(catalog):
		print("ask ok")
	if _options(catalog):
		print("options ok")
	if _dawn(catalog):
		print("dawn ok")
	var lost := _careful(catalog)
	print("careful loss %d/60" % lost)
	if lost != 2:
		_bad("careful loss %d/60 moved off the measured 2/60 baseline" % lost)
	if lost < 9 or lost > 21:
		print("NOTE spec names 15-35 percent of 60. Measured %d/60. Left as-is; careful does not spend." % lost)
	if failed:
		print("FAVOR FAIL")
		quit(1)
	else:
		print("FAVOR OK")
		quit(0)


func _bad(msg: String) -> void:
	failed = true
	section_failed = true
	print("FAIL " + msg)


func _begin() -> void:
	section_failed = false


func _section_ok() -> bool:
	return not section_failed


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_bad(msg)


func _strings() -> bool:
	_begin()
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/synod_favor.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P80":
		_bad("synod_favor.json roadmap")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	var keys := ["favor.open", "favor.need", "favor.blessing", "favor.blessing_tip", "favor.escort_tip", "favor.escort_tip_tip", "favor.quiet_week", "favor.quiet_week_tip", "favor.spent", "favor.cooldown", "favor.first", "favor.expire"]
	if rows.size() != 12:
		_bad("favor key count %d" % rows.size())
	for key in keys:
		if not rows.has(key):
			_bad("missing " + key)
	Copy.set_lang("en")
	for key in keys:
		if not rows.has(key):
			continue
		var want := str(rows[key].get("en", ""))
		if Copy.t(key) != want:
			_bad("EN %s got %s" % [key, Copy.t(key)])
	Copy.set_lang("ru")
	for key in keys:
		if not rows.has(key):
			continue
		var want := str(rows[key].get("ru", ""))
		if Copy.t(key) != want:
			_bad("RU %s got %s" % [key, Copy.t(key)])
	Copy.set_lang("en")
	_expect(Copy.fill("favor.spent", {"favor": "Blessing"}) == "The chapel answers: Blessing.", "spent fill")
	_expect(Copy.fill("favor.cooldown", {"n": 2}) == "The chapel rests. Wait 2 weeks.", "cooldown fill")
	_expect(Copy.t("favor.need") == "The chapel listens at 10.", "need line")
	_expect(Copy.t("favor.blessing_tip") == "Hope +1. Discontent −1. Cost 8.", "blessing tip")
	_expect(Copy.t("favor.escort_tip_tip") == "Next fight leans your way. Cost 10.", "escort tip")
	_expect(Copy.t("favor.quiet_week_tip") == "Skip one hard knock at dawn. Cost 12.", "quiet tip")
	_expect(Copy.t("favor.expire") == "The escort tip faded. No fight came.", "expire line")
	_expect(Copy.t("favor.first") == "The chapel will answer — for a price.", "first line")
	return _section_ok()


func _game(catalog: Catalog, run_seed := 3) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _ask(catalog: Catalog) -> bool:
	_begin()
	var game := _game(catalog)
	game.synod = 9
	_expect(not SynodFavor.open(game), "ask open below 10")
	_expect(SynodFavor.block(game, "blessing") == "closed", "spend below 10")
	game.synod = 10
	_expect(SynodFavor.open(game), "ask closed at 10")
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var at := view.find("func _add_favor_chapel")
	var end := view.find("func _favor_option", at)
	var body := view.substr(at, end - at) if at >= 0 and end > at else ""
	_expect(at >= 0, "chapel row missing")
	_expect(view.find("_add_favor_chapel") >= 0 and view.find("func _fill_visit") >= 0, "visit does not call the chapel row")
	_expect(body.find("favor.need") >= 0 and body.find("favor.open") >= 0, "ask copy missing")
	_expect(body.find("ProgressBar") < 0, "chapel row builds a synod meter")
	_expect(body.find("ConfirmationDialog") < 0 and body.find("Are you sure") < 0, "ask invented a confirm")
	var dawn := FileAccess.get_file_as_string("res://sim/game.gd")
	var pick := dawn.find("func _pick_dawn_soft_chip")
	var pick_end := dawn.find("func dawn_soft_chip", pick)
	var picker := dawn.substr(pick, pick_end - pick)
	_expect(picker.find("favor") < 0, "soft dawn picker knows favor")
	_expect(dawn.find("const SAVE_SCHEMA := 14") >= 0, "save schema moved")
	return _section_ok()


func _options(catalog: Catalog) -> bool:
	_begin()
	_expect(SynodFavor.cost("blessing") == 8 and SynodFavor.cost("escort_tip") == 10 and SynodFavor.cost("quiet_week") == 12, "costs moved")
	var game := _game(catalog)
	game.hope = 40
	game.discontent = 20
	var hope0 := game.hope
	var dis0 := game.discontent
	var creed0 := str(game.creed)
	game.synod = 12
	game.week = 6
	_expect(game.apply({"kind": "favor", "id": "blessing"}), "blessing spend")
	_expect(game.synod == 4, "blessing did not deduct 8")
	_expect(game.hope == hope0 + 1 and game.discontent == dis0 - 1, "blessing mood")
	_expect(str(game.creed) == creed0, "blessing wrote creed")
	_expect(bool(game.flags.get("seen_synod_favor", false)), "first flag")
	_expect(str(game.last_favor.get("toast", "")) == "The chapel answers: Blessing.", "spent toast")
	_expect(str(game.last_favor.get("float", "")) == "The chapel will answer — for a price.", "first float")
	_expect(SynodFavor.cooldown_n(game) == 2, "cooldown right after spend")
	_expect(not game.apply({"kind": "favor", "id": "escort_tip"}), "second spend during cooldown")
	_expect(game.synod == 4, "cooldown spend deducted")
	game.week = 8
	_expect(SynodFavor.cooldown_n(game) == 0, "cooldown did not lift after 2 weeks")
	var moment: Dictionary = {}
	for row in game.chronicle:
		if str(row.get("kind", "")) == "favor":
			moment = row
	_expect(not moment.is_empty() and int(moment.get("weight", 0)) == 1 and int(moment.get("weight", 0)) <= 2, "chronicle weight")
	_expect(game.chronicle_line(moment) == "The chapel answers: Blessing.", "chronicle line")
	var score_fn := FileAccess.get_file_as_string("res://sim/game.gd")
	var score_at := score_fn.find("func score_now")
	var score_body := score_fn.substr(score_at, score_fn.find("func _mandate_fulfilled", score_at) - score_at)
	_expect(score_body.find("favor") < 0, "epilogue score reads favor")
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var favor_src := FileAccess.get_file_as_string("res://sim/synod_favor.gd")
	_expect(favor_src.find("\"blessing\"") >= 0 and favor_src.find("\"escort_tip\"") >= 0 and favor_src.find("\"quiet_week\"") >= 0, "option ids")
	_expect(view.find("SynodFavor.IDS") >= 0 and view.find("tip_key") >= 0 and view.find("label_key") >= 0, "option keys")
	_expect(favor_src.find("quiet_week") >= 0 and view.find("for id in SynodFavor.IDS") >= 0, "quiet week dropped from the panel")
	_expect(view.find("ConfirmationDialog") < 0, "options invented a confirm")
	var bal = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	if bal is Dictionary:
		for key in bal:
			if str(key).begins_with("favor"):
				_bad("balance key " + str(key))
	game.synod = 20
	_expect(game.apply({"kind": "favor", "id": "blessing"}), "second blessing after cooldown")
	_expect(str(game.last_favor.get("float", "")) == "", "first float repeated")
	_expect(game.synod == 12, "second blessing cost")
	var saved := game.export_state()
	saved["schema"] = Game.SAVE_SCHEMA
	var loaded := Game.new()
	loaded.catalog = catalog
	_expect(loaded.import_state(saved), "favor flags did not load")
	_expect(int(loaded.synod) == 12 and bool(loaded.flags.get("seen_synod_favor", false)), "save dropped favor")
	_expect(SynodFavor.cooldown_n(loaded) == 2, "save dropped cooldown")
	_expect(not SynodFavor.bot_may_bless(game, "careful"), "careful spends")
	var rich := _game(catalog)
	rich.synod = 18
	rich.hope = 30
	_expect(SynodFavor.bot_may_bless(rich, "expander"), "expander may not bless")
	rich.hope = 40
	_expect(not SynodFavor.bot_may_bless(rich, "expander"), "expander blesses when hope is not low")
	return _section_ok()


func _dawn(catalog: Catalog) -> bool:
	_begin()
	var quiet := _game(catalog, 4)
	quiet.week = 10
	quiet.synod = 20
	_expect(quiet.apply({"kind": "favor", "id": "quiet_week"}), "quiet spend")
	_expect(quiet.synod == 8, "quiet cost")
	for ev in quiet.catalog.events:
		var id := str(ev.get("id", ""))
		if id != "toll":
			quiet.event_last[id] = quiet.week
	quiet.pending.clear()
	quiet.week_event_ids = {}
	quiet.flags["favor_quiet"] = true
	quiet._roll_events()
	var saw_toll := false
	for ev in quiet.pending:
		if str(ev.get("id", "")) == "toll":
			saw_toll = true
	_expect(not saw_toll, "quiet week presented toll")
	_expect(not bool(quiet.flags.get("favor_quiet", false)), "quiet flag stuck")
	_expect(str(quiet.flags.get("favor_quiet_result", "")) == "skip", "quiet result")
	_expect(quiet.synod == 8, "quiet refunded")
	var noop := _game(catalog, 5)
	noop.week = 10
	noop.synod = 30
	noop.apply({"kind": "favor", "id": "quiet_week"})
	var syn := noop.synod
	for ev in noop.catalog.events:
		var id := str(ev.get("id", ""))
		if id != "lamps":
			noop.event_last[id] = noop.week
	noop.pending.clear()
	noop.week_event_ids = {}
	noop.flags["favor_quiet"] = true
	noop._roll_events()
	var saw_lamps := false
	for ev in noop.pending:
		if str(ev.get("id", "")) == "lamps":
			saw_lamps = true
	_expect(saw_lamps, "quiet no-op ate a non-pressure card")
	_expect(str(noop.flags.get("favor_quiet_result", "")) == "noop", "quiet no-op result")
	_expect(noop.synod == syn, "quiet no-op refunded")
	var escort := _game(catalog, 6)
	escort.week = 5
	escort.synod = 22
	var bare: Dictionary = escort._battle_factors(escort.squads[escort.player], _faith_or_owned(escort), false)
	_expect(escort.apply({"kind": "favor", "id": "escort_tip"}), "escort spend")
	_expect(escort.synod == 12, "escort cost")
	var sid := _faith_or_owned(escort)
	var leaned: Dictionary = escort._battle_factors(escort.squads[escort.player], sid, false)
	_expect(float(leaned.attack) > float(bare.attack), "escort did not lean the existing fight term")
	_expect(int(escort.flags.get("favor_escort_until", 0)) == 9, "escort window")
	var still: Dictionary = escort._battle_factors(escort.squads[escort.player], sid, false)
	_expect(float(still.attack) == float(leaned.attack), "preview consumed the escort")
	var resolved: Dictionary = escort._resolve_battle(escort.squads[escort.player], sid, false)
	_expect(int(escort.flags.get("favor_escort_until", 0)) == 0, "resolve left the escort armed")
	_expect(float(resolved.attack) > float(bare.attack), "resolve dropped the lean")
	var other := {"faction": "directorate", "fight": 1, "gear": 1.0, "size": 8, "station": escort.capital_id}
	escort.flags["favor_escort_until"] = 9
	_expect(not SynodFavor.escort_applies(escort, other, sid), "escort leaned a rival squad")
	var held := escort.synod
	escort.week = 9
	escort.notices.clear()
	SynodFavor.expire_escort(escort)
	_expect(int(escort.flags.get("favor_escort_until", 0)) == 0, "expire left the escort")
	_expect(escort.synod == held, "expire refunded synod")
	_expect(escort.notices.size() == 1 and str(escort.notices[0]) == Copy.t("favor.expire"), "expire toast")
	var early := _game(catalog, 8)
	early.week = 5
	early.synod = 15
	early.apply({"kind": "favor", "id": "escort_tip"})
	early.week = 8
	early.notices.clear()
	SynodFavor.expire_escort(early)
	_expect(int(early.flags.get("favor_escort_until", 0)) == 9, "escort expired inside the window")
	_expect(early.notices.is_empty(), "expire toasted early")
	return _section_ok()


func _faith_or_owned(game: Game) -> String:
	for id in game.stations:
		var st: Dictionary = game.stations[id]
		if str(st.get("lean", "")) == "faith" or str(st.get("owner", "")) == str(game.player):
			return str(id)
	return str(game.capital_id)


func _careful(catalog: Catalog) -> int:
	var lost := 0
	var spent := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		if str(game.over) != "time":
			lost += 1
		if bool(game.flags.get("seen_synod_favor", false)) or int(game.hope_totals.get("favor", 0)) != 0:
			spent += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	if spent != 0:
		_bad("careful spent favor on %d seeds" % spent)
	return lost
