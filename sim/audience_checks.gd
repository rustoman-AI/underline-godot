extends RefCounted

## Leader audience regressions: fair scheduling, refusals, completed deals, the list's target, every deal's
## preview against what accepting it changes, and the schedule surviving a save. Pure sim, no UI.
## Run alone with sim/check_audience.gd; sim/bot_run.gd runs them too.

const ALL := ["depot", "directorate", "synod", "exchange", "black_flag"]
## The brief's starvation fixture: everyone arrived long ago, Exchange first.
const DUE := {"exchange": 2, "depot": 6, "directorate": 7, "synod": 10, "black_flag": 20}

var catalog: Catalog
var lines: PackedStringArray = []
var failed := false


static func run(cat: Catalog) -> Dictionary:
	var checks = load("res://sim/audience_checks.gd").new()
	checks.catalog = cat
	checks._schedule()
	checks._refusals()
	checks._list_target()
	checks._deals()
	checks._save_reload()
	return {"ok": not checks.failed, "lines": checks.lines}


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		lines.append(good + ": ok")
	else:
		failed = true
		lines.append("FAIL " + bad)


## A game where exactly the leaders in `due` wait, nobody is at the door and no one has been seen.
## Everyone else is closed off with a done deal so arrivals during the run cannot join.
func _waiting(standing: Dictionary, due: Dictionary = DUE) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 60)
	game.audience = {}
	game.audience_due = due.duplicate()
	game.audience_last = {}
	game.audience_deals = {}
	for fid in ALL:
		if not due.has(fid):
			game.audience_deals[fid] = 1
	for fid in standing:
		game.standing[fid] = int(standing[fid])
	return game


## Dawns from week `from` through `to`, nobody answering; one entry per dawn, "" when nobody came.
func _dawns(game: Game, from: int, to: int) -> PackedStringArray:
	var seen: PackedStringArray = []
	for at in range(from, to + 1):
		game.week = at
		game._audience_dawn()
		seen.append(str(game.audience.get("faction", "")))
	return seen


func _schedule() -> void:
	var game := _waiting({"exchange": -60})
	var seen := _dawns(game, 21, 28)
	var first := {}
	for fid in seen.slice(0, 5):
		first[fid] = true
	_expect(seen.count("exchange") < 8 and first.size() == 5,
		"Hostile oldest does not starve the rest (%s)" % " ".join(seen), "starvation " + " ".join(seen))
	_expect(seen == _dawns(_waiting({"exchange": -60}), 21, 28), "Schedule is deterministic", "same fixture, different sequence")

	for name in ["hostile", "pact"]:
		var value := -60 if name == "hostile" else 80
		var all := {}
		for fid in ALL:
			all[fid] = value
		seen = _dawns(_waiting(all), 21, 40)
		var fair := not seen.has("")
		for i in range(0, seen.size() - 4):
			var window := {}
			for fid in seen.slice(i, i + 5):
				window[fid] = true
			fair = fair and window.size() == 5
		_expect(fair, "All %s: everyone within five selections, one per dawn" % name, "%s rotation %s" % [name, " ".join(seen)])

	for name in ["hostile", "pact"]:
		var alone := _waiting({"synod": -60 if name == "hostile" else 80}, {"synod": 10})
		seen = _dawns(alone, 21, 24)
		_expect(seen == PackedStringArray(["synod", "synod", "synod", "synod"]), "Lone %s leader returns every dawn" % name, "%s repeater %s" % [name, " ".join(seen)])

	var ordinary := _waiting({"depot": 0}, {"depot": 6})
	seen = _dawns(ordinary, 21, 29)
	_expect(seen == PackedStringArray(["depot", "", "", "", "", "", "", "depot", ""]),
		"Ordinary leader left in silence returns six weeks after the silent dawn", "silent cooldown " + " ".join(seen))
	ordinary = _waiting({"depot": 0}, {"depot": 6})
	seen = _dawns(ordinary, 21, 21)
	ordinary.apply({"kind": "audience", "accept": false})
	seen.append_array(_dawns(ordinary, 22, 28))
	_expect(seen == PackedStringArray(["depot", "", "", "", "", "", "depot", ""]),
		"Ordinary leader refused returns six weeks later", "refused cooldown " + " ".join(seen))

	var done := _waiting({"exchange": -60}, {"exchange": 2, "depot": 6})
	done.week = 21
	done._audience_dawn()
	done.stock.food = 100
	var took := done.apply({"kind": "audience", "accept": true})
	seen = _dawns(done, 22, 30)
	_expect(took and not seen.has("exchange") and done.audience_deals.has("exchange"),
		"Completed deal never returns, even hostile", "completed deal %s %s" % [took, " ".join(seen)])


func _refusals() -> void:
	var game := _waiting({"exchange": -60, "depot": -60}, {"exchange": 2, "depot": 6})
	game.week = 21
	game._audience_dawn()
	var decisions := game.decisions
	var refused := game.apply({"kind": "audience", "accept": false})
	var memory: Array = game.standing_memory.exchange
	var rows := game.journal.filter(func(r): return str(r.kind) == "audience")
	var row: Dictionary = rows.back() if not rows.is_empty() else {}
	_expect(refused and game.audience.is_empty() and int(game.audience_last.exchange) == 21 and game.decisions == decisions + 1
		and str(memory.back().deed) == "refused" and str(row.get("result", "")) == "refused" and str(row.get("faction", "")) == "exchange",
		"Explicit refusal is remembered and journaled", "refusal %s %s %s" % [refused, memory, row])
	var seen := _dawns(game, 22, 23)
	_expect(seen[0] == "depot", "Refused leader goes behind the one waiting", "after refusal " + " ".join(seen))
	memory = game.standing_memory.depot
	_expect(str(memory.back().deed) == "silence" and int(game.audience_last.depot) == 23 and seen[1] == "exchange",
		"Unanswered audience counts as silence", "silence memory %s" % [memory])
	rows = game.journal.filter(func(r): return str(r.kind) == "audience" and str(r.get("result", "")) == "silence")
	_expect(rows.size() == 1 and str(rows[0].faction) == "depot", "Silence is journaled once", "silence rows %s" % [rows])


func _list_target() -> void:
	var game := _waiting({}, {"directorate": 7})
	game.week = 21
	game._audience_dawn()
	var target := str(game.audience.get("target", ""))
	_expect(target != "" and target == game.list_target() and not game._is_council(target),
		"The list names the least skilled non-council resident", "list target %s vs %s" % [target, game.list_target()])
	game._remove_resident(target)
	var before := var_to_bytes(game.export_state())
	var took := game.apply({"kind": "audience", "accept": true})
	_expect(not took and game.audience_reason() != "" and var_to_bytes(game.export_state()) == before,
		"Gone target blocks the deal without changes", "gone target took=%s" % took)


## Each case opens one leader at the door with a prepared station, then takes the deal.
func _deals() -> void:
	_deal("the_list, plain", "directorate", func(g: Game): pass)
	_deal("the_list, clamps, curfew on, air filter maxed", "directorate", func(g: Game):
		g.hope = 3
		g.discontent = 2
		g.standing.directorate = 90
		g.standing.depot = -90
		g.laws_on["curfew"] = true
		_max_rooms(g, "air_filter"))
	_deal("burn_papers, no Papers, no workshop", "depot", func(g: Game):
		g.artifacts.papers = 0
		g.rooms = g.rooms.filter(func(r): return str(r.type) != "workshop"))
	_deal("burn_papers, two Papers, workshop", "depot", func(g: Game):
		g.artifacts.papers = 2)
	_deal("stay_down, hope clamp", "synod", func(g: Game):
		g.hope = 95)
	_deal("open_books", "exchange", func(g: Game): pass)
	_deal("lantern_toll, opinion at zero", "black_flag", func(g: Game):
		g.standing.black_flag = 0
		g.stock.food = 20)
	_deal("lantern_toll, opinion below zero", "black_flag", func(g: Game):
		g.standing.black_flag = -30
		g.stock.food = 20)
	var game := _door("black_flag", func(g: Game): g.stock.food = 5)
	var before := var_to_bytes(game.export_state())
	var took := game.apply({"kind": "audience", "accept": true})
	_expect(not took and game.audience_reason() != "" and var_to_bytes(game.export_state()) == before,
		"Unaffordable toll is refused without changes", "unaffordable toll took=%s" % took)


func _max_rooms(game: Game, type: String) -> void:
	for room in game.rooms:
		if str(room.type) == type:
			room.upgrade = catalog.rooms[type].get("upgrades", []).size()


func _door(fid: String, prepare: Callable) -> Game:
	var game := _waiting({}, {})
	game.week = 21
	prepare.call(game)
	var target := game.list_target() if fid == "directorate" else ""
	game.audience = {"faction": fid, "week": game.week, "target": target}
	return game


func _deal(name: String, fid: String, prepare: Callable) -> void:
	var game := _door(fid, prepare)
	var fx := game.audience_effects()
	var before := {
		"hope": game.hope, "discontent": game.discontent, "food": int(game.stock.food),
		"standing": game.standing.duplicate(), "pop": game.residents.size(), "papers": int(game.artifacts.papers),
		"laws": game.laws_on.duplicate(), "upgrades": _upgrades(game), "journal": game.journal.size(),
	}
	var bad: PackedStringArray = []
	if not game.apply({"kind": "audience", "accept": true}):
		_expect(false, "", "%s not accepted: %s" % [name, game.audience_reason()])
		return
	if game.hope - int(before.hope) != int(fx.hope):
		bad.append("hope")
	if game.discontent - int(before.discontent) != int(fx.discontent):
		bad.append("discontent")
	if int(game.stock.food) - int(before.food) != int(fx.food):
		bad.append("food")
	for other in game.standing:
		if int(game.standing[other]) - int(before.standing.get(other, 0)) != int(fx.standing.get(other, 0)):
			bad.append("standing " + str(other))
	var handed := str(fx.hand_over) != ""
	if int(before.pop) - game.residents.size() != (1 if handed else 0) or (handed and game.people.has(str(fx.hand_over))):
		bad.append("hand over")
	if int(before.papers) - int(game.artifacts.papers) != (1 if bool(fx.papers) else 0):
		bad.append("papers")
	for law in game.laws_on:
		if not before.laws.has(law) and str(law) != str(fx.law):
			bad.append("law " + str(law))
	if str(fx.law) != "" and not game.laws_on.has(str(fx.law)):
		bad.append("law missing")
	var after := _upgrades(game)
	for uid in after:
		var want := 1 if not fx.tier.is_empty() and str(fx.tier.uid) == str(uid) else 0
		if int(after[uid]) - int(before.upgrades.get(uid, 0)) != want:
			bad.append("tier " + str(uid))
	if not game.flags.has(str(fx.flag)):
		bad.append("flag")
	var kinds: PackedStringArray = []
	for row in game.journal.slice(int(before.journal)):
		kinds.append(str(row.kind))
	if kinds.has("false_way") != bool(fx.toll_lost):
		bad.append("false_way row")
	if kinds.has("handed_over") != handed:
		bad.append("handed_over row")
	_expect(bad.is_empty(), "Deal %s matches preview %s" % [name, _shown(fx)], "deal %s: %s" % [name, ", ".join(bad)])


func _shown(fx: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in ["hope", "discontent", "food"]:
		if int(fx[key]) != 0:
			parts.append("%s %+d" % [key, int(fx[key])])
	if not fx.standing.is_empty():
		parts.append("standing %s" % str(fx.standing))
	for key in ["hand_over", "law"]:
		if str(fx[key]) != "":
			parts.append("%s %s" % [key, fx[key]])
	if not fx.tier.is_empty():
		parts.append("tier %s" % fx.tier.name)
	if bool(fx.papers):
		parts.append("papers -1")
	if bool(fx.toll_lost):
		parts.append("toll lost")
	return "(" + "; ".join(parts) + ")"


func _upgrades(game: Game) -> Dictionary:
	var out := {}
	for room in game.rooms:
		out[str(room.uid)] = int(room.upgrade)
	return out


## Saving with a leader at the door, and again right after a refusal, must not change who comes next.
func _save_reload() -> void:
	var all := {}
	for fid in ALL:
		all[fid] = -60
	var straight := _waiting(all)
	var expected := _dawns(straight, 21, 23)
	straight.apply({"kind": "audience", "accept": false})
	expected.append_array(_dawns(straight, 24, 32))

	var game := _waiting(all)
	var seen := _dawns(game, 21, 23)
	game = _reloaded(game)
	game.apply({"kind": "audience", "accept": false})
	game = _reloaded(game)
	seen.append_array(_dawns(game, 24, 32))
	_expect(seen == expected and var_to_bytes(game.export_state()) == var_to_bytes(straight.export_state()),
		"Save during a waiting audience and after a refusal keeps the schedule", "reload %s vs %s" % [" ".join(seen), " ".join(expected)])


func _reloaded(game: Game) -> Game:
	var copy := Game.new()
	copy.setup(catalog, 7, 60)
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	if not copy.import_state(data):
		lines.append("FAIL reload " + copy.load_error)
		failed = true
	return copy
