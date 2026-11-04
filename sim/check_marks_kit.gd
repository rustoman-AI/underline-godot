extends SceneTree

## P87 Marks & Kit. Strings, mirrors, swap, dawn order, save, and the careful band.
##   godot --headless --path . -s res://sim/check_marks_kit.gd

const LOSSES_BASELINE := 2
const SEEDS := 60

var failed := false
var catalog: Catalog


func _init() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	_strings()
	_schema()
	_triggers()
	_lines()
	_swap()
	_defaults()
	_dawn()
	_soft_dawn()
	_bots_skip()
	if failed:
		print("MARKS KIT FAILED")
		quit(1)
		return
	_careful()
	if failed:
		print("MARKS KIT FAILED")
		quit(1)
		return
	print("MARKS KIT OK")
	quit(0)


func _strings() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/marks_kit.json"))
	if not (pack is Dictionary) or not (pack.by_key is Dictionary):
		_bad("marks_kit.json")
		return
	var rows: Dictionary = pack.by_key
	_expect(rows.size() == 108, "108 obs keys", str(rows.size()))
	for key in rows:
		var id := str(key)
		if not id.begins_with("obs."):
			_bad("key outside obs.* %s" % id)
		if id.begins_with("observer.") or id.find("observer.") >= 0:
			_bad("observer key %s" % id)
		var row: Dictionary = rows[key]
		var en := str(row.get("en", ""))
		var ru := str(row.get("ru", ""))
		if en == "" or ru == "":
			_bad("missing text %s" % id)
		if en.to_lower().find("gear") >= 0 or ru.to_lower().find("gear") >= 0:
			_bad("says gear %s" % id)
		if Copy.t(id) != en:
			_bad("Copy.t %s -> %s" % [id, Copy.t(id)])
	Copy.set_lang("ru")
	_expect(Copy.t("obs.title") == "Наблюдатель", "RU title", Copy.t("obs.title"))
	_expect(Copy.t("obs.kit_title") == "Пожитки", "RU Kit", Copy.t("obs.kit_title"))
	_expect(Copy.t("obs.ink.yes") == "Набить", "RU ink", Copy.t("obs.ink.yes"))
	Copy.set_lang("en")
	_expect(Game.DAWN_SOFT_STACK == ["rumor", "border.dawn_new", "rail", "homecoming"], "soft dawn stack", str(Game.DAWN_SOFT_STACK))


func _schema() -> void:
	_expect(Game.SAVE_SCHEMA == 17, "schema 17", str(Game.SAVE_SCHEMA))
	var game := _game()
	game.obs.marks = ["ash_hand"]
	game.obs.offered = ["signal_scar"]
	game.obs.earned = {"ash_hand": {"week": 6, "what": "obs.what.ash_hand", "station": ""}}
	game.obs.kit_owned = ["oilskin"]
	game.obs.kit_worn = {"coat": "oilskin", "lamp": "", "token": ""}
	game.obs.card_week = 4
	game.flags["seen_obs_marks"] = true
	var raw := game.export_state()
	raw["schema"] = 17
	var other := _game()
	var ok := other.import_state(raw)
	_expect(ok, "schema 17 loads", other.load_error)
	_expect(other.obs.marks == ["ash_hand"] and str(other.obs.kit_worn.coat) == "oilskin" and int(other.obs.card_week) == 4, "obs round trip", str(other.obs))
	_expect(bool(other.flags.get("seen_obs_marks", false)), "first-mark flag kept", str(other.flags.get("seen_obs_marks", false)))
	raw["schema"] = 14
	raw.erase("obs")
	var old := _game()
	old.obs.marks = ["raid_tally"]
	ok = old.import_state(raw)
	_expect(ok and old.obs.marks.is_empty() and old.obs.kit_owned.is_empty(), "schema 14 starts with no marks", old.load_error + " " + str(old.obs.marks))


func _triggers() -> void:
	var game := _game()
	var rng_before := game.rng.state
	var net_before := game.net_rng.state
	MarksKit.note_bury(game)
	MarksKit.note_bury(game)
	_expect(game.obs.offered.is_empty(), "two burials do not offer", str(game.obs.offered))
	MarksKit.note_bury(game)
	_expect(game.obs.offered.has("ash_hand"), "third burial offers Ash Hand", str(game.obs.offered))
	_expect(str(game.obs.earned.ash_hand.what) == "obs.what.ash_hand", "earned-from ash", str(game.obs.earned))
	MarksKit.note_word_kept(game)
	MarksKit.note_blown(game)
	MarksKit.note_raid(game, "westfield")
	MarksKit.note_arrival(game, 5)
	var far := _far_outpost(game)
	if far != "":
		game.stations[far].owner = game.player
		MarksKit.note_week_end(game)
	else:
		_bad("no outpost three hops out")
	for id in ["ash_hand", "word_knot", "signal_scar", "raid_tally", "open_door", "rail_stitch"]:
		_expect(game.obs.offered.has(id) or game.obs.marks.has(id), "offered %s" % id, str(game.obs.offered))
	_expect(game.rng.state == rng_before and game.net_rng.state == net_before, "triggers do not draw rng", "")
	game.obs.marks = ["ash_hand", "word_knot", "signal_scar"]
	game.obs.offered = ["ash_hand", "word_knot", "signal_scar"]
	game.obs.due_ink = []
	game.obs.noroom = []
	game.obs.offer_toast_week = 0
	MarksKit.note_raid(game, "westfield")
	_expect(game.obs.noroom.has("raid_tally"), "fourth offer has no skin", str(game.obs.noroom))
	_expect(game.obs.due_ink.is_empty(), "no ink card when full", str(game.obs.due_ink))
	var toasted := false
	for line in game.obs.toasts:
		if str(line).find("No skin") >= 0:
			toasted = true
	_expect(toasted, "noroom toast", str(game.obs.toasts))
	var before: Array = game.obs.marks.duplicate()
	MarksKit.resolve(game, {"obs_kind": "ink", "obs_id": "ash_hand"}, "later")
	_expect(game.obs.marks == before, "inked marks stay", str(game.obs.marks))
	## One card this week, gift waits.
	var gift := _game()
	gift.week = 4
	MarksKit.note_sympathy(gift, "brickworks", 40, 55)
	MarksKit.note_blueprint(gift, "strip")
	MarksKit.dawn(gift)
	_expect(_obs_cards(gift) == 1, "one observer card", str(_obs_cards(gift)))
	_expect(str(gift.pending[0].get("obs_kind", "")) != "gift" or gift.obs.due_ink.is_empty(), "ink before gift when both wait", str(gift.pending[0].get("obs_kind", "")))
	var week := gift.week
	MarksKit.dawn(gift)
	_expect(_obs_cards(gift) == 1, "still one card this week", str(_obs_cards(gift)))
	gift.week = week + 1
	gift.obs.card_week = week
	## Drop the shown card the way a resolved week does, then the next dawn may bring the gift.
	var kept: Array = []
	for ev in gift.pending:
		if not MarksKit.is_card(ev):
			kept.append(ev)
	gift.pending = kept
	MarksKit.dawn(gift)
	_expect(_obs_cards(gift) == 1, "gift comes the week after", str(gift.pending))
	var captured := _game()
	MarksKit.note_capture(captured, "dockyard", true)
	_expect(captured.obs.kit_lost.has("oilskin") and captured.obs.wait_kit.is_empty(), "captured station gives nothing", str(captured.obs.kit_lost))
	MarksKit.note_sympathy(captured, "dockyard", 10, 80)
	_expect(captured.obs.wait_kit.is_empty(), "captured station still gives nothing", str(captured.obs.wait_kit))
	var once := _game()
	MarksKit.note_sympathy(once, "eastwater", 49, 50)
	MarksKit.note_sympathy(once, "eastwater", 50, 60)
	_expect(once.obs.wait_kit.size() == 1, "gift fires once", str(once.obs.wait_kit))
	var found := _game()
	MarksKit.note_blueprint(found, "junk")
	MarksKit.note_blueprint(found, "strip")
	_expect(found.obs.wait_kit.size() == 1 and str(found.obs.wait_kit[0].id) == "linesman_vest", "vest once", str(found.obs.wait_kit))
	MarksKit.note_night_return(found, 1, "")
	_expect(found.obs.wait_kit.size() == 1, "a death on the run is not a whistle", str(found.obs.wait_kit))
	MarksKit.note_night_return(found, 0, "signal")
	var ids: PackedStringArray = []
	for row in found.obs.wait_kit:
		ids.append(str(row.get("id", "")))
	_expect(ids.has("whistle") and ids.has("headset"), "whistle and headset", str(ids))
	MarksKit.note_signal(found, "probe")
	_expect(found.obs.wait_kit.size() == 3, "headset once", str(found.obs.wait_kit.size()))


func _lines() -> void:
	var game := _game()
	for id in ["two_portions", "breathers_price", "the_list"]:
		var ev := _event(game, id)
		_expect(not ev.is_empty() and MarksKit.best_line(game, ev).is_empty(), "no line on %s" % id, str(ev.get("id", "")))
	game.obs.marks = ["rail_stitch", "ash_hand"]
	var rumble := _event(game, "rumble")
	var line := MarksKit.best_line(game, rumble)
	_expect(str(line.get("mirror", "")) != "", "rumble has a mirrored line", str(line))
	var src := _choice(rumble, str(line.mirror))
	_expect(_same_effect(src, line), "mirror copies cost check and effect", "src %s line %s" % [src, line])
	_expect(str(line.label) == "obs.mark.rail_stitch.opt", "label is the obs key", str(line.label))
	game.obs.marks = []
	_expect(MarksKit.best_line(game, rumble).is_empty(), "unmet line is absent", "")
	var hidden := line.duplicate(true)
	_expect(MarksKit.line_hidden(game, hidden), "unmet obs line is hidden", "")
	_expect(game.choice_locked(hidden), "hidden line is not offered to a bot", "")
	game.obs.marks = ["raid_tally"]
	game.obs.kit_worn.token = "free_mask"
	var arm := _event(game, "armband")
	var one := MarksKit.best_line(game, arm)
	_expect(str(one.get("obs_source", {}).get("kind", "")) == "mark", "mark beats kit", str(one.get("obs_source", {})))
	MarksKit.attach(game, arm)
	MarksKit.attach(game, arm)
	var n := 0
	for choice in arm.choices:
		if bool(choice.get("obs_hidden", false)):
			n += 1
	_expect(n == 1, "one obs line on a card", str(n))
	var burial := {
		"id": "burial_ada",
		"burial_id": "ada",
		"choices": [
			{"id": "bury", "label": "Bury them", "cost": {"materials": 1}, "hope": 1},
			{"id": "tunnel", "label": "Leave them"},
		],
	}
	game.obs.marks = ["ash_hand"]
	var speak := MarksKit.best_line(game, burial)
	_expect(str(speak.get("mirror", "")) == "bury" and int(speak.get("hope", 0)) == 1, "names mirror bury", str(speak))


func _swap() -> void:
	var game := _game()
	game.obs_desk = true
	game.obs.kit_owned = ["oilskin", "barrel_quilt", "carbide"]
	game.obs_narrative = true
	_expect(not game.obs_can_swap(), "swap blocked while a card is open", "")
	game.obs_narrative = false
	game.obs_shelved = true
	_expect(not game.obs_can_swap(), "swap blocked while a card is shelved", "")
	game.obs_shelved = false
	game.obs_desk = false
	_expect(not game.obs_can_swap(), "swap is the home desk only", "")
	game.obs_desk = true
	var prev := game.obs_swap("coat", "oilskin")
	_expect(str(game.obs.kit_worn.coat) == "oilskin" and prev == "", "wear the coat", str(game.obs.kit_worn))
	game.obs_swap("coat", "barrel_quilt")
	_expect(str(game.obs.kit_worn.coat) == "barrel_quilt", "one coat", str(game.obs.kit_worn))
	game.obs_swap("lamp", "oilskin")
	_expect(str(game.obs.kit_worn.lamp) == "", "a coat does not sit on the lamp hook", str(game.obs.kit_worn))
	game.obs_swap("coat", "")
	_expect(str(game.obs.kit_worn.coat) == "", "take the coat off", str(game.obs.kit_worn))


func _defaults() -> void:
	var blank := MarksKit.fresh()
	_expect(not blank.has("name"), "the Observer has no name field", str(blank.keys()))
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/marks_kit.json"))
	var rows: Dictionary = pack.by_key
	for key in rows:
		var en := str(rows[key].get("en", ""))
		var ru := str(rows[key].get("ru", ""))
		if en.to_lower().find("what is your name") >= 0 or en.to_lower().find("name the observer") >= 0 or ru.find("как тебя зовут") >= 0:
			_bad("name prompt %s" % str(key))
	var taken := _game()
	var food := int(taken.stock.food)
	var hope := taken.hope
	var mats := int(taken.stock.materials)
	var tokens := int(taken.stock.tokens)
	MarksKit.note_capture(taken, "dockyard", true)
	MarksKit.note_sympathy(taken, "dockyard", 20, 80)
	_expect(taken.obs.kit_owned.is_empty() and taken.obs.wait_kit.is_empty() and taken.obs.kit_lost.has("oilskin"),
		"capturing a station never grants Kit", str(taken.obs.kit_owned) + " " + str(taken.obs.wait_kit))
	taken.obs_desk = false
	taken.obs.kit_owned = ["carbide"]
	taken.obs_swap("lamp", "carbide")
	_expect(str(taken.obs.kit_worn.lamp) == "", "no swap off the home desk", str(taken.obs.kit_worn))
	taken.obs_desk = true
	taken.obs_swap("lamp", "carbide")
	_expect(str(taken.obs.kit_worn.lamp) == "carbide", "swap at the home desk", str(taken.obs.kit_worn))
	_expect(int(taken.stock.food) == food and taken.hope == hope and int(taken.stock.materials) == mats and int(taken.stock.tokens) == tokens,
		"a swap has no cost", "food %s hope %s" % [taken.stock.food, taken.hope])


func _dawn() -> void:
	var game := _game()
	game.week = 5
	game.pending = [
		{"id": "toll", "major": true, "choices": [{"id": "pay", "label": "Pay"}]},
		{"id": "burial_ada", "burial_id": "ada", "choices": [{"id": "bury", "label": "Bury them", "cost": {"materials": 1}}]},
		{"id": "leak", "choices": [{"id": "patch", "label": "Patch"}]},
	]
	game.obs.offered = ["ash_hand"]
	game.obs.due_ink = ["ash_hand"]
	game.obs.card_week = 0
	var before := game.rng.state
	MarksKit.dawn(game)
	MarksKit.reseat(game)
	_expect(game.rng.state == before, "the ink card does not draw rng", "")
	_expect(str(game.pending[0].get("burial_id", "")) != "", "death card stays first", str(game.pending[0].get("id", "")))
	_expect(MarksKit.is_card(game.pending[1]), "ink card follows the death card", str(game.pending[1].get("id", "")))
	_expect(str(game.pending[1].get("obs_kind", "")) == "ink", "it is the ink card", str(game.pending[1]))
	_expect(not game.event_is_big({"id": "rumor"}) , "rumor is not an observer card", "")
	for ev in game.pending:
		_expect(str(ev.get("id", "")) != "border.dawn_new", "observer card is not a dawn chip", str(ev.get("id", "")))


func _soft_dawn() -> void:
	_expect(Game.DAWN_SOFT_STACK.find("obs") < 0, "P87 does not join the soft dawn stack", str(Game.DAWN_SOFT_STACK))
	var text := FileAccess.get_file_as_string("res://sim/game.gd")
	_expect(text.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") >= 0, "stack literal unchanged", "")


func _bots_skip() -> void:
	var game := _game()
	game.obs.marks = ["word_knot"]
	var loan := _event(game, "loan")
	MarksKit.attach(game, loan)
	game.pending = [loan]
	var bot := Bot.new()
	bot.profile = "careful"
	var picked := ""
	for choice in loan.choices:
		if bot._open(game, choice):
			picked = str(choice.get("id", ""))
			break
	_expect(picked != "" and picked != "obs_word_knot", "bot skips the obs line", picked)


func _careful() -> void:
	var on_losses := 0
	var off_losses := 0
	for seed in range(1, SEEDS + 1):
		MarksKit.pack_on = true
		var on: Dictionary = Bot.new().play(40, seed, "careful", catalog)
		MarksKit.pack_on = false
		var off: Dictionary = Bot.new().play(40, seed, "careful", catalog)
		MarksKit.pack_on = true
		if str(on.get("over", "")) != "time":
			on_losses += 1
		if str(off.get("over", "")) != "time":
			off_losses += 1
		if str(on.get("summary", "")) != str(off.get("summary", "")) or str(on.get("over", "")) != str(off.get("over", "")):
			_bad("seed %d drifted\non %s\noff %s" % [seed, on.get("over", ""), off.get("over", "")])
			print(str(on.get("summary", "")).substr(0, 400))
			print("---")
			print(str(off.get("summary", "")).substr(0, 400))
			return
	_expect(on_losses == LOSSES_BASELINE and off_losses == LOSSES_BASELINE, "careful losses stay 2/60", "%d on, %d off" % [on_losses, off_losses])


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _event(game: Game, id: String) -> Dictionary:
	for ev in game.catalog.events:
		if str(ev.get("id", "")) == id:
			return ev.duplicate(true)
	return {}


func _choice(ev: Dictionary, id: String) -> Dictionary:
	for choice in ev.get("choices", []):
		if str(choice.get("id", "")) == id:
			return choice
	return {}


func _same_effect(src: Dictionary, line: Dictionary) -> bool:
	if src.is_empty() or line.is_empty():
		return false
	for key in src:
		var name := str(key)
		if name == "id" or name == "label" or name == "ru_own" or name == "text":
			continue
		if str(line.get(key, null)) != str(src[key]) and line.get(key, null) != src[key]:
			return false
	return str(line.get("mirror", "")) == str(src.get("id", ""))


func _obs_cards(game: Game) -> int:
	var n := 0
	for ev in game.pending:
		if MarksKit.is_card(ev):
			n += 1
	return n


func _far_outpost(game: Game) -> String:
	for sid in game.stations:
		if str(sid) == game.capital_id:
			continue
		if game._hops(game.capital_id, str(sid)) >= 3 and game._hops(game.capital_id, str(sid)) < 900:
			return str(sid)
	return ""


func _expect(ok: bool, what: String, detail: String) -> void:
	if ok:
		return
	_bad("%s (%s)" % [what, detail])


func _bad(msg: String) -> void:
	failed = true
	print("FAIL ", msg)
