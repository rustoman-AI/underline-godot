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
	checks._help()
	checks._save_reload()
	checks._leader_lines()
	checks._leader_text_source()
	checks._leader_voice_files()
	checks._openings()
	checks._flavour()
	var consequences: Dictionary = load("res://sim/leader_event_checks.gd").run(cat)
	checks.lines.append_array(consequences.lines)
	var story: Dictionary = load("res://sim/story_checks.gd").run(cat)
	checks.lines.append_array(story.lines)
	return {"ok": not checks.failed and bool(consequences.ok) and bool(story.ok), "lines": checks.lines}


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


## Offering help: the stock and regard it moves match what the card shows; the answer is "helped", which opens
## no consequence event, sets no deal flag, and leaves the leader to come back after the cooldown with the deal.
func _help() -> void:
	for fid in ALL:
		var help: Dictionary = {}
		for row in catalog.leaders.get("factions", []):
			if str(row.get("id", "")) == fid:
				help = row.get("help", {})
		var offer: Dictionary = catalog.lines.factions.get(fid, {}).get("help", {}).get("offer", {})
		var reply: Dictionary = catalog.lines.factions.get(fid, {}).get("help", {}).get("reply", {})
		_expect(not help.is_empty() and str(offer.get("en", "")) != "" and str(offer.get("ru", "")) != ""
			and str(reply.get("en", "")) != "" and str(reply.get("ru", "")) != "",
			"Help for %s has a cost and an offer and reply in EN and RU" % fid, "help data for %s" % fid)
		if help.is_empty():
			continue
		var key := str(help.resource)
		var game := _waiting({fid: 0}, {fid: DUE[fid]})
		game.week = 21
		game._audience_dawn()
		game.stock[key] = int(help.amount) + 3
		var fx := game.help_effects()
		var stock_before := int(game.stock[key])
		var regard_before := int(game.standing[fid])
		var flags_before := game.flags.duplicate()
		var gave := game.apply({"kind": "audience", "help": true})
		var bad: PackedStringArray = []
		if not gave:
			bad.append("not taken: %s" % game.help_reason())
		if stock_before - int(game.stock[key]) != int(fx.amount) or int(fx.amount) != int(help.amount):
			bad.append("charged %d, shown %d" % [stock_before - int(game.stock[key]), int(fx.amount)])
		if int(game.standing[fid]) - regard_before != int(fx.standing) or int(fx.standing) != int(help.standing):
			bad.append("regard %d, shown %d" % [int(game.standing[fid]) - regard_before, int(fx.standing)])
		if str(game.leader_answers.get(fid, {}).get("answer", "")) != "helped" or not game.audience.is_empty():
			bad.append("answer %s" % str(game.leader_answers.get(fid, {})))
		if game.audience_deals.has(fid) or game.flags.size() != flags_before.size():
			bad.append("deal closed or flag set")
		var rows := game.journal.filter(func(r): return str(r.kind) == "audience")
		if rows.is_empty() or str(rows.back().get("result", "")) != "helped" or int(rows.back().get("amount", 0)) != int(fx.amount):
			bad.append("journal")
		_expect(bad.is_empty(), "Help for %s charges what it shows (%s %d, regard %+d)" % [fid, key, int(fx.amount), int(fx.standing)],
			"help %s: %s" % [fid, ", ".join(bad)])

		var opened: PackedStringArray = []
		var keep := game.week
		for at in range(21, 61):
			game.week = at
			for ev in catalog.events:
				var needs = ev.get("needs", null)
				if needs is Dictionary and str(needs.get("leader", "")) == fid and game.needs_window(ev) >= 0:
					opened.append("%s@%d" % [str(ev.id), at])
		game.week = keep
		_expect(opened.is_empty(), "Helped %s opens no consequence event" % fid, "helped %s opens %s" % [fid, ", ".join(opened)])

		var seen := _dawns(game, 22, 27)
		_expect(seen == PackedStringArray(["", "", "", "", "", fid]),
			"Helped %s returns six weeks later" % fid, "helped %s return %s" % [fid, " ".join(seen)])
		game.stock.food = 100
		game.stock.tokens = 100
		game.stock.materials = 100
		var took := game.apply({"kind": "audience", "accept": true})
		var answer: Dictionary = game.leader_answers.get(fid, {})
		_expect(took and str(answer.get("answer", "")) == "accepted" and int(answer.get("week", 0)) == 27 and game.audience_deals.has(fid),
			"After help the %s deal is still on the table and overrides the answer" % fid,
			"%s deal after help took=%s answer=%s" % [fid, took, answer])

	var pact := _waiting({"depot": 80}, {"depot": 6})
	pact.week = 21
	pact._audience_dawn()
	pact.stock.materials = 100
	var first := pact.apply({"kind": "audience", "help": true})
	var waits: PackedStringArray = []
	var open_at := 0
	for at in range(22, 29):
		pact.week = at
		pact.audience = {}
		pact._audience_dawn()
		if str(pact.audience.get("faction", "")) != "depot":
			waits.append("%d nobody" % at)
			continue
		if pact.help_reason() == "":
			if open_at == 0:
				open_at = at
		else:
			waits.append("%d %d" % [at, pact.help_wait("depot")])
	pact.week = 22
	pact.audience = {"faction": "depot", "week": 22, "target": ""}
	var before_pact := var_to_bytes(pact.export_state())
	var again := pact.apply({"kind": "audience", "help": true})
	_expect(first and open_at == 27 and not again and var_to_bytes(pact.export_state()) == before_pact
		and waits == PackedStringArray(["22 5", "23 4", "24 3", "25 2", "26 1"]),
		"Pact leader returns every dawn but help waits six weeks (open again week %d)" % open_at,
		"pact help first=%s open_at=%d again=%s waits=%s" % [first, open_at, again, " ".join(waits)])

	for style in ["helper", "helper_mixed"]:
		var too_soon: PackedStringArray = []
		var helps := 0
		for run_seed in range(1, 4):
			var bot := Bot.new()
			bot.audience_style = style
			var game := Game.new()
			game.setup(catalog, run_seed, 40)
			game.audit = true
			var guard := 0
			while game.over == "" and guard < 42:
				guard += 1
				bot._act(game)
				game.end_week()
			var last := {}
			for row in game.journal:
				if str(row.get("kind", "")) != "audience" or str(row.get("result", "")) != "helped":
					continue
				helps += 1
				var fid := str(row.faction)
				if last.has(fid) and int(row.week) - int(last[fid]) < 6:
					too_soon.append("seed %d %s %d->%d" % [run_seed, fid, int(last[fid]), int(row.week)])
				last[fid] = int(row.week)
		_expect(too_soon.is_empty() and helps > 0, "Bot %s helps each leader at most once per six weeks (%d helps in 3 runs)" % [style, helps],
			"bot %s helps too soon: %s" % [style, ", ".join(too_soon)])

	var top := _door("depot", func(g: Game): g.standing.depot = 95)
	var fx_top := top.help_effects()
	top.apply({"kind": "audience", "help": true})
	_expect(int(fx_top.standing) == 5 and int(top.standing.depot) == 100, "Help regard clamps at 100 and shows the clamped step",
		"help clamp shown %d, now %d" % [int(fx_top.standing), int(top.standing.depot)])

	var poor := _door("synod", func(g: Game): g.stock.food = 2)
	var before := var_to_bytes(poor.export_state())
	var gave_poor := poor.apply({"kind": "audience", "help": true})
	_expect(not gave_poor and poor.help_reason() != "" and var_to_bytes(poor.export_state()) == before,
		"Unaffordable help is refused without changes (%s)" % poor.help_reason(), "unaffordable help took=%s" % gave_poor)


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


const LINE_KEYS := ["name", "leader", "title", "first_contact", "territory", "trade", "pitch", "accepted", "declined"]
const BANDS := ["hostile", "cold", "wary", "useful", "pact"]


## Keys that hold words a player reads; none may sit in faction_leaders.json, which is mechanics only.
const LEADER_TEXT_KEYS := ["name", "leader", "title", "voice_note", "opening", "en", "ru", "first_contact",
	"bands", "territory", "trade", "pitch", "accepted", "declined"]


## data/leader_lines.json is the one source of leader text: faction_leaders.json carries no text fields
## and no Cyrillic; every string in leader_lines.json is filled, has no em or en dash and no TODO_REWRITE;
## no first_contact starts with the leader's name, which the card title already shows.
func _leader_text_source() -> void:
	var bad: PackedStringArray = []
	_text_keys(catalog.leaders, "faction_leaders", bad)
	if RegEx.create_from_string("[\\x{0400}-\\x{04FF}]").search(JSON.stringify(catalog.leaders)) != null:
		bad.append("Cyrillic in faction_leaders.json")
	_line_strings(catalog.lines, "leader_lines", bad)
	var lines_by_id: Dictionary = catalog.lines.get("factions", {})
	for fid in ALL:
		var row: Dictionary = lines_by_id.get(fid, {})
		for lang in ["en", "ru"]:
			var opening := str(row.get("first_contact", {}).get(lang, "")).strip_edges()
			var full := str(row.get("leader", {}).get(lang, "")).get_slice(",", 0).strip_edges()
			for part in [full] + Array(full.split(" ", false)):
				if str(part) != "" and opening.begins_with(str(part)):
					bad.append("%s first_contact.%s starts with %s" % [fid, lang, part])
					break
	_expect(bad.is_empty(), "Leader text has one source; first contact does not repeat the name",
		"leader text: " + ", ".join(bad))


func _text_keys(value, path: String, bad: PackedStringArray) -> void:
	if value is Dictionary:
		for key in value:
			if LEADER_TEXT_KEYS.has(str(key)):
				bad.append("%s.%s is text in faction_leaders.json" % [path, key])
			_text_keys(value[key], "%s.%s" % [path, key], bad)
	elif value is Array:
		for i in value.size():
			_text_keys(value[i], "%s[%d]" % [path, i], bad)


func _line_strings(value, path: String, bad: PackedStringArray) -> void:
	if value is Dictionary:
		for key in value:
			_line_strings(value[key], "%s.%s" % [path, key], bad)
	elif value is Array:
		for i in value.size():
			_line_strings(value[i], "%s[%d]" % [path, i], bad)
	elif value is String:
		var text := str(value)
		if text.strip_edges() == "":
			bad.append("%s is empty" % path)
		if text.contains("\u2014") or text.contains("\u2013"):
			bad.append("%s has a dash" % path)
		if text.contains("TODO_REWRITE"):
			bad.append("%s is TODO_REWRITE" % path)


## Leader voice: every leader and key names lead_<faction>_<key>_<lang>.ogg in assets/audio/vo, each key
## has a written line, and a missing file resolves to "" (play nothing) without an error. The opening key
## is first_contact at the first meeting and the band after it.
func _leader_voice_files() -> void:
	var bad: PackedStringArray = []
	var present: PackedStringArray = []
	var was := Copy.lang
	var lines_by_id: Dictionary = catalog.lines.get("factions", {})
	for fid in ALL:
		for key in Voice.LEADER_KEYS:
			var row: Dictionary = lines_by_id.get(fid, {})
			var pair = row.get("bands", {}).get(str(key).trim_prefix("band_"), {}) if str(key).begins_with("band_") else row.get(key, {})
			if not Game.line_written(pair):
				bad.append("%s %s has no line" % [fid, key])
			var voice := Voice.leader_row(fid, key)
			for lang in ["en", "ru"]:
				var want := "res://assets/audio/vo/lead_%s_%s_%s.ogg" % [fid, key, lang]
				if Voice.leader_file(fid, key, lang) != want or str(voice.get("audio_" + lang, "")) != want:
					bad.append("%s %s %s names %s" % [fid, key, lang, Voice.leader_file(fid, key, lang)])
				Copy.set_lang(lang)
				var found := Voice.audio(voice)
				if found != (want if ResourceLoader.exists(want) else ""):
					bad.append("%s resolves to '%s'" % [want.get_file(), found])
				if found != "":
					present.append(want.get_file())
	Copy.set_lang(was)
	var game := _waiting({"synod": 80}, {"synod": 10})
	var first := game.audience_opening_key("synod")
	game.audience_last["synod"] = 3
	var later := game.audience_opening_key("synod")
	if first != "first_contact" or later != "band_pact":
		bad.append("opening keys %s / %s" % [first, later])
	_expect(bad.is_empty(), "Leader voice: %d file names, %d present, missing ones stay silent" % [
		ALL.size() * Voice.LEADER_KEYS.size() * 2, present.size()], "leader voice: " + ", ".join(bad))


## Every leader has every line in both languages, none empty or left as TODO_REWRITE, and the
## portrait id on the card matches the lines file.
func _leader_lines() -> void:
	var bad: PackedStringArray = []
	var lines_by_id: Dictionary = catalog.lines.get("factions", {})
	for fid in ALL:
		var row: Dictionary = lines_by_id.get(fid, {})
		var pairs := {}
		for key in LINE_KEYS:
			pairs[key] = row.get(key, null)
		for band in BANDS:
			pairs["bands." + band] = row.get("bands", {}).get(band, null)
		for key in pairs:
			for lang in ["en", "ru"]:
				var text := str(pairs[key].get(lang, "")) if pairs[key] is Dictionary else ""
				if text.strip_edges() == "" or text.contains("TODO_REWRITE"):
					bad.append("%s %s.%s" % [fid, key, lang])
		var card: Dictionary = {}
		for leader in catalog.leaders.get("factions", []):
			if str(leader.get("id", "")) == fid:
				card = leader
		if str(card.get("leader_id", "")) != str(row.get("leader_id", "")):
			bad.append("%s leader_id differs" % fid)
		if JSON.stringify(card).contains("TODO_REWRITE"):
			bad.append("%s TODO_REWRITE left in faction_leaders.json" % fid)
	if JSON.stringify(catalog.factions).contains("TODO_REWRITE"):
		bad.append("TODO_REWRITE left in factions.json")
	_expect(bad.is_empty(), "Every leader has every line in EN and RU", "leader lines: " + ", ".join(bad))


## First meeting opens with first_contact, later ones with the band line; a missing line falls back.
func _openings() -> void:
	var game := _waiting({"synod": 80}, {"synod": 10})
	var lines_by_id: Dictionary = catalog.lines.factions
	var first := game.audience_opening("synod")
	game.audience_last["synod"] = 3
	var later := game.audience_opening("synod")
	var missing := game.leader_line("synod", "bands", "no_such_band")
	_expect(first == lines_by_id.synod.first_contact and later == lines_by_id.synod.bands.pact
		and missing == lines_by_id.synod.first_contact,
		"Opening is first_contact, then the band line, missing lines fall back", "openings %s / %s / %s" % [first, later, missing])


## Territory and trade lines are flavour: at most once per faction every four weeks, nothing else moves.
func _flavour() -> void:
	var game := _waiting({}, {})
	game.player = "depot"
	var shown: PackedStringArray = []
	var before := game.standing.duplicate()
	for at in range(10, 19):
		game.week = at
		var a := game._leader_flavour("territory", "synod")
		var b := game._leader_flavour("trade", "synod")
		shown.append("%d%s%s" % [at, "t" if not a.is_empty() else "", "r" if not b.is_empty() else ""])
	var own := game._leader_flavour("territory", "depot")
	_expect(" ".join(shown) == "10t 11 12 13 14t 15 16 17 18t" and own.is_empty() and game.standing == before,
		"Territory and trade lines show once per faction every four weeks", "flavour %s own=%s" % [" ".join(shown), own])


func _reloaded(game: Game) -> Game:
	var copy := Game.new()
	copy.setup(catalog, 7, 60)
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	if not copy.import_state(data):
		lines.append("FAIL reload " + copy.load_error)
		failed = true
	return copy
