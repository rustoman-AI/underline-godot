extends RefCounted

## Leader consequence events (data/events_leaders.json): data validation and the rules that make them fire.
## Pure sim, no UI. Run by sim/audience_checks.gd, so check_audience.gd and bot_run.gd both cover it.

const EVENT_KEYS := ["id", "title", "major", "weight", "cooldown", "needs", "forced", "trigger", "text", "choices", "ru_own"]
## What Game._apply_deltas and _apply_standing_choice understand on a plain choice.
const CHOICE_KEYS := ["id", "label", "cost", "food", "air", "power", "materials", "tokens", "influence", "hope",
	"discontent", "people", "sick", "efficiency", "papers", "synod", "opinion_exchange", "opinion_directorate",
	"trait_hope", "trait_absent", "power_double", "hydro_down", "shop_down", "gen_down", "standing",
	"artifacts", "fragment", "how", "flag", "requires", "proof", "ending", "ru_own"]
const STOCK := ["food", "air", "power", "materials", "tokens", "influence"]

var catalog: Catalog
var lines: PackedStringArray = []
var failed := false


static func run(cat: Catalog) -> Dictionary:
	var checks = load("res://sim/leader_event_checks.gd").new()
	checks.catalog = cat
	checks._validate()
	checks._answers()
	checks._windows()
	checks._deferral()
	checks._standing()
	checks._saves()
	return {"ok": not checks.failed, "lines": checks.lines}


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		lines.append(good + ": ok")
	else:
		failed = true
		lines.append("FAIL " + bad)


func _leader_events() -> Array:
	return catalog.events.filter(func(ev): return ev.get("needs") is Dictionary and ev.needs.has("leader"))


func _leaders() -> Dictionary:
	var out := {}
	for row in catalog.leaders.get("factions", []):
		out[str(row.get("id", ""))] = true
	return out


func _validate() -> void:
	var bad: PackedStringArray = []
	var ids := {}
	for ev in catalog.events:
		var id := str(ev.get("id", ""))
		if ids.has(id):
			bad.append("event id %s twice" % id)
		ids[id] = true
	var leaders := _leaders()
	var events := _leader_events()
	for ev in events:
		var id := str(ev.id)
		for key in ev:
			if not EVENT_KEYS.has(str(key)):
				bad.append("%s: unknown key %s" % [id, key])
		var needs = ev.needs
		if not (needs is Dictionary):
			bad.append("%s: needs is not an object" % id)
			continue
		for key in needs:
			if not Game.NEEDS_KEYS.has(str(key)):
				bad.append("%s: unknown needs key %s" % [id, key])
		if not leaders.has(str(needs.get("leader", ""))):
			bad.append("%s: needs.leader %s is not a leader" % [id, needs.get("leader", "")])
		if not Game.ANSWERS.has(str(needs.get("answer", ""))):
			bad.append("%s: needs.answer %s" % [id, needs.get("answer", "")])
		var span = needs.get("after_weeks", null)
		if not (span is Array) or span.size() != 2 or int(span[0]) < 1 or int(span[0]) > int(span[1]):
			bad.append("%s: after_weeks %s" % [id, str(span)])
		var texts: Array = [str(ev.get("title", "")), str(ev.get("text", ""))]
		var choices: Array = ev.get("choices", [])
		if choices.size() < 2:
			bad.append("%s: %d choices" % [id, choices.size()])
		var choice_ids := {}
		for choice in choices:
			var cid := str(choice.get("id", ""))
			if cid == "" or choice_ids.has(cid):
				bad.append("%s: choice id '%s' empty or twice" % [id, cid])
			choice_ids[cid] = true
			texts.append(str(choice.get("label", "")))
			for key in choice:
				if not CHOICE_KEYS.has(str(key)):
					bad.append("%s/%s: unknown effect %s" % [id, cid, key])
			var cost = choice.get("cost", {})
			if not (cost is Dictionary):
				bad.append("%s/%s: cost is not an object" % [id, cid])
			else:
				for key in cost:
					if not STOCK.has(str(key)):
						bad.append("%s/%s: unknown cost %s" % [id, cid, key])
			var shifts = choice.get("standing", {})
			if not (shifts is Dictionary):
				bad.append("%s/%s: standing is not an object" % [id, cid])
			else:
				for fid in shifts:
					if not leaders.has(str(fid)):
						bad.append("%s/%s: standing names %s, not a faction in faction_leaders.json" % [id, cid, fid])
					if typeof(shifts[fid]) != TYPE_INT and typeof(shifts[fid]) != TYPE_FLOAT:
						bad.append("%s/%s: standing %s is not a number" % [id, cid, fid])
		for en in texts:
			if en.strip_edges() == "":
				bad.append("%s: empty text" % id)
				continue
			var ru := str(catalog.leader_ru.get(en, ""))
			if ru.strip_edges() == "":
				bad.append("%s: no Russian for \"%s\"" % [id, en])
			for dash in ["\u2014", "\u2013"]:
				if en.contains(dash) or ru.contains(dash):
					bad.append("%s: dash in \"%s\"" % [id, en])
	_expect(bad.is_empty() and not events.is_empty(),
		"Leader events valid: %d events, %d catalog ids unique, every string has Russian, no dashes" % [events.size(), ids.size()],
		"leader events: " + "; ".join(bad))
	var pairs := {}
	for ev in events:
		var key := "%s/%s" % [ev.needs.leader, ev.needs.answer]
		pairs[key] = int(pairs.get(key, 0)) + 1
	_expect(pairs.size() == events.size(), "One consequence per leader and answer (%s)" % ", ".join(PackedStringArray(pairs.keys())),
		"leader/answer pairs %s" % str(pairs))


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.pending = []
	game.audience = {}
	return game


## First answer sticks: accept, refuse and silence are all recorded with the audience's week.
func _answers() -> void:
	var game := _game()
	game.week = 12
	game.stock.food = 200
	game.audience = {"faction": "synod", "week": 12, "target": ""}
	game.apply({"kind": "audience", "accept": true})
	game.audience = {"faction": "exchange", "week": 12, "target": ""}
	game.apply({"kind": "audience", "accept": false})
	game.audience = {"faction": "depot", "week": 12, "target": ""}
	game.week = 13
	game._audience_refuse("silence")
	game.audience = {"faction": "exchange", "week": 19, "target": ""}
	game.week = 19
	game.apply({"kind": "audience", "accept": true})
	var a: Dictionary = game.leader_answers
	_expect(str(a.get("synod", {}).get("answer", "")) == "accepted" and str(a.get("exchange", {}).get("answer", "")) == "refused"
		and int(a.exchange.week) == 12 and str(a.get("depot", {}).get("answer", "")) == "silence" and int(a.depot.week) == 12
		and a.size() == 3,
		"Answers recorded once with the audience week (accept, refuse, silence; a later deal does not overwrite)", "answers %s" % str(a))


## The window opens after_weeks[0] weeks after the answer and closes after after_weeks[1]; refused matches silence.
func _windows() -> void:
	var bad: PackedStringArray = []
	for ev in _leader_events():
		var fid := str(ev.needs.leader)
		var span: Array = ev.needs.after_weeks
		var givens: Array = ["accepted"] if str(ev.needs.answer) == "accepted" else ["refused", "silence"]
		for given in givens:
			for since in range(0, int(span[1]) + 3):
				var game := _game()
				game.leader_answers = {fid: {"answer": given, "week": 5}}
				game.week = 5 + since
				var other := "refused" if given == "accepted" else "accepted"
				var shown := _dawn_offer(game)
				var want := since >= int(span[0]) and since <= int(span[1])
				if shown != (str(ev.id) if want else ""):
					bad.append("%s %s +%d showed '%s'" % [ev.id, given, since, shown])
				game = _game()
				game.leader_answers = {fid: {"answer": other, "week": 5}}
				game.week = 5 + since
				shown = _dawn_offer(game)
				if shown == str(ev.id):
					bad.append("%s fired for %s" % [ev.id, other])
		var once := _game()
		once.leader_answers = {fid: {"answer": "silence" if str(ev.needs.answer) == "refused" else "accepted", "week": 5}}
		once.week = 5 + int(span[0])
		var first := _dawn_offer(once)
		once.pending = []
		once.week += 1
		if first != str(ev.id) or _dawn_offer(once) != "":
			bad.append("%s showed twice" % ev.id)
	_expect(bad.is_empty(), "Each consequence shows inside its window only, for the matching answer, once a run", "; ".join(bad))

	var game := _game()
	game.week = 20
	for fid in ["depot", "directorate", "synod", "exchange", "black_flag"]:
		game.leader_answers[fid] = {"answer": "accepted", "week": 20 - 3 - (1 if fid == "synod" else 0)}
	game.leader_answers["synod"].week = 10
	var seen: PackedStringArray = []
	for at in range(20, 28):
		game.week = at
		game.pending = []
		seen.append(_dawn_offer(game))
	var shown_once := {}
	for id in seen:
		if id != "":
			shown_once[id] = int(shown_once.get(id, 0)) + 1
	_expect(seen[0] == "lc_synod_accepted" and shown_once.size() == 5 and shown_once.values().max() == 1,
		"Five due at once: one per dawn, closest window first (%s)" % " ".join(seen), "queue %s" % " ".join(seen))


## Leader event offer exactly as at dawn: the random pool never offers it, only _offer_forced_event.
func _dawn_offer(game: Game) -> String:
	var before := game.pending.size()
	game.week_event_ids = {}
	game._offer_forced_event()
	if game.pending.size() == before:
		return ""
	return str(game.pending.back().id)


## A major event already waiting holds the consequence to the next dawn; cooldown and minor cap never block it;
## the random pool never draws it.
func _deferral() -> void:
	var ev: Dictionary = _leader_events()[0]
	var fid := str(ev.needs.leader)
	var game := _game()
	game.leader_answers = {fid: {"answer": "silence" if str(ev.needs.answer) == "refused" else str(ev.needs.answer), "week": 5}}
	game.week = 5 + int(ev.needs.after_weeks[0])
	game.pending = [{"id": "big", "major": true, "choices": []}]
	var held := _dawn_offer(game)
	game.pending = []
	game.week += 1
	game.event_last = {}
	for other in game.catalog.events:
		game.event_last[str(other.id)] = game.week
		game.event_times[str(other.id)] = 99
	var next := _dawn_offer(game)
	var pooled := false
	for row in game._event_pool(false) + game._event_pool(true):
		if Game.needs_forced(row):
			pooled = true
	_expect(held == "" and next == str(ev.id) and not pooled,
		"Major event waiting defers it a week; cooldowns and caps do not; never in the random pool", "held=%s next=%s pooled=%s" % [held, next, pooled])
	var late := _game()
	late.leader_answers = {fid: {"answer": "silence" if str(ev.needs.answer) == "refused" else str(ev.needs.answer), "week": 5}}
	var missed := 0
	for at in range(5, 5 + int(ev.needs.after_weeks[1]) + 1):
		late.week = at
		late.pending = [{"id": "big", "major": true, "choices": []}]
		if _dawn_offer(late) != "":
			missed += 1
	late.pending = []
	late.week = 5 + int(ev.needs.after_weeks[1]) + 1
	_expect(missed == 0 and _dawn_offer(late) == "" and not late.events_seen.has(str(ev.id)),
		"Window that passes under major events shows nothing", "late window fired %d / %s" % [missed, str(late.events_seen.get(str(ev.id), ""))])


## "standing" moves the leader's regard, clamps at 100, journals a "regard" row and is remembered as a deed.
func _standing() -> void:
	var game := _game()
	var ev: Dictionary = {}
	for row in _leader_events():
		if str(row.id) == "lc_lamp_refused":
			ev = row
	game.leader_answers = {"black_flag": {"answer": "refused", "week": 5}}
	game.week = 8
	game.stock.food = 100
	game.standing["black_flag"] = 95
	game.pending = []
	game._present_event(ev)
	var ok := game.apply({"kind": "event", "event_id": "lc_lamp_refused", "choice_id": "food"})
	var rows := game.journal.filter(func(r): return str(r.kind) == "regard")
	var memory: Array = game.standing_memory.get("black_flag", [])
	_expect(ok and int(game.standing.black_flag) == 100 and rows.size() == 1 and int(rows[0].delta) == 5
		and str(rows[0].faction) == "black_flag" and not memory.is_empty() and str(memory.back().deed) == "event"
		and str(memory.back().event) == "lc_lamp_refused" and int(game.stock.food) == 92,
		"Standing effect clamps to 100, journals the real change and is remembered", "standing %s rows %s memory %s food %d" % [game.standing.black_flag, rows, memory, int(game.stock.food)])
	game = _game()
	game.standing["directorate"] = -95
	for row in _leader_events():
		if str(row.id) == "lc_directorate_refused":
			ev = row
	game.leader_answers = {"directorate": {"answer": "refused", "week": 5}}
	game.week = 8
	game._present_event(ev)
	game.apply({"kind": "event", "event_id": "lc_directorate_refused", "choice_id": "refuse"})
	_expect(int(game.standing.directorate) == -100, "Standing clamps at -100", "standing %d" % int(game.standing.directorate))


## leader_answers survives a save; an older save without it loads with none; a bad answer is rejected.
func _saves() -> void:
	var game := _game()
	game.week = 9
	game.leader_answers = {"depot": {"answer": "silence", "week": 4}}
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var copy := _game()
	var loaded := copy.import_state(data)
	_expect(loaded and copy.leader_answers == game.leader_answers, "Leader answers survive a save", "reload %s %s" % [loaded, copy.load_error])
	var old := data.duplicate(true)
	old["schema"] = 2
	old.erase("leader_answers")
	copy = _game()
	copy.leader_answers = {"synod": {"answer": "accepted", "week": 1}}
	loaded = copy.import_state(old)
	_expect(loaded and copy.leader_answers.is_empty(), "Schema 2 save loads with no answers", "schema 2 %s %s %s" % [loaded, copy.load_error, copy.leader_answers])
	var cases := {
		"unknown leader": {"nobody": {"answer": "accepted", "week": 2}},
		"bad answer": {"depot": {"answer": "maybe", "week": 2}},
		"future week": {"depot": {"answer": "refused", "week": 30}},
		"not a row": {"depot": "refused"},
	}
	var bad: PackedStringArray = []
	for name in cases:
		var broken := data.duplicate(true)
		broken.leader_answers = cases[name]
		copy = _game()
		if copy.import_state(broken):
			bad.append(name)
	var missing := data.duplicate(true)
	missing.erase("leader_answers")
	copy = _game()
	if copy.import_state(missing):
		bad.append("current schema without leader_answers")
	_expect(bad.is_empty(), "Rejects malformed leader answers", "accepted: " + ", ".join(bad))
