extends RefCounted

## Story engine, phase S1 (docs/briefs/cursor_story_engine.txt): data validation for every event with "needs"
## and every story effect, the truth fragments, the Words source, the expedition hook and the save fields.
## Pure sim, no UI. Run by sim/audience_checks.gd, so check_audience.gd and bot_run.gd both cover it.

const LeaderEventChecks = preload("res://sim/leader_event_checks.gd")
const STORY_FILE := "events_story.json"
const TRUTH_KEYS := ["title", "hint", "text"]

var catalog: Catalog
var lines: PackedStringArray = []
var failed := false


static func run(cat: Catalog) -> Dictionary:
	var checks = load("res://sim/story_checks.gd").new()
	checks.catalog = cat
	checks._validate()
	checks._endings()
	checks._truth()
	checks._placeholders()
	checks._conditions()
	checks._draws()
	checks._effects()
	checks._words()
	checks._expedition()
	checks._saves()
	checks._scenes()
	checks._choices()
	checks._decision()
	checks._epilogue()
	checks._bot()
	return {"ok": not checks.failed, "lines": checks.lines}


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		lines.append(good + ": ok")
	else:
		failed = true
		lines.append("FAIL " + bad)


func _leaders() -> Dictionary:
	var out := {}
	for row in catalog.leaders.get("factions", []):
		out[str(row.get("id", ""))] = true
	return out


func _bands() -> Array:
	return catalog.leaders.get("opinion_bands", []).map(func(row): return str(row.get("id", "")))


func _seasons() -> Array:
	return catalog.balance.get("seasons", []).map(func(row): return str(row.get("id", "")))


func _story_ids() -> Dictionary:
	var out := {}
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + STORY_FILE))
	for ev in data.get("events", []) if data is Dictionary else []:
		out[str(ev.get("id", ""))] = true
	return out


func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and value == floor(value))


func _span_ok(span, low: int, high: int) -> bool:
	return span is Array and span.size() == 2 and _is_number(span[0]) and _is_number(span[1]) \
		and int(span[0]) >= low and int(span[0]) <= int(span[1]) and int(span[1]) <= high


## Problems with one event's "needs"; an empty list when every key is known and well formed.
func needs_problems(id: String, ev: Dictionary) -> PackedStringArray:
	var bad: PackedStringArray = []
	var needs = ev.get("needs", null)
	if not (needs is Dictionary) or needs.is_empty():
		bad.append("%s: needs is not a non-empty object" % id)
		return bad
	if ev.has("forced") and typeof(ev.forced) != TYPE_BOOL:
		bad.append("%s: forced is not true or false" % id)
	var leaders := _leaders()
	for key in needs:
		if not Game.NEEDS_KEYS.has(str(key)):
			bad.append("%s: unknown needs key %s" % [id, key])
	if needs.has("leader") or needs.has("answer") or needs.has("after_weeks"):
		if not leaders.has(str(needs.get("leader", ""))):
			bad.append("%s: needs.leader %s is not a leader" % [id, needs.get("leader", "")])
		if not Game.ANSWERS.has(str(needs.get("answer", ""))):
			bad.append("%s: needs.answer %s" % [id, needs.get("answer", "")])
		if needs.has("after_weeks") and not _span_ok(needs.after_weeks, 0, 40):
			bad.append("%s: after_weeks %s" % [id, str(needs.after_weeks)])
	for key in ["standing_min", "standing_max"]:
		if not needs.has(key):
			continue
		if not (needs[key] is Dictionary) or needs[key].is_empty():
			bad.append("%s: %s is not a non-empty object" % [id, key])
			continue
		for fid in needs[key]:
			if not leaders.has(str(fid)) or not _is_number(needs[key][fid]) or absi(int(needs[key][fid])) > 100:
				bad.append("%s: %s %s=%s" % [id, key, fid, str(needs[key][fid])])
	if needs.has("band"):
		if not (needs.band is Dictionary) or needs.band.is_empty():
			bad.append("%s: band is not a non-empty object" % id)
		else:
			for fid in needs.band:
				if not leaders.has(str(fid)) or not _bands().has(str(needs.band[fid])):
					bad.append("%s: band %s=%s" % [id, fid, str(needs.band[fid])])
	for key in ["fragment", "no_fragment"]:
		if needs.has(key) and not Game.FRAGMENTS.has(str(needs[key])):
			bad.append("%s: %s %s is not a fragment id" % [id, key, str(needs[key])])
	for key in ["flag", "no_flag"]:
		if needs.has(key) and (typeof(needs[key]) != TYPE_STRING or str(needs[key]).strip_edges() == ""):
			bad.append("%s: %s is not a name" % [id, key])
	if needs.has("artifacts_min"):
		if not (needs.artifacts_min is Dictionary) or needs.artifacts_min.is_empty():
			bad.append("%s: artifacts_min is not a non-empty object" % id)
		else:
			for key in needs.artifacts_min:
				if not Game.ARTIFACTS.has(str(key)) or not _is_number(needs.artifacts_min[key]) or int(needs.artifacts_min[key]) < 1:
					bad.append("%s: artifacts_min %s=%s" % [id, key, str(needs.artifacts_min[key])])
	if needs.has("week") and not _span_ok(needs.week, 1, 40):
		bad.append("%s: week %s" % [id, str(needs.week)])
	if needs.has("season") and not _seasons().has(str(needs.season)):
		bad.append("%s: season %s" % [id, str(needs.season)])
	if needs.has("ending_blocked") and typeof(needs.ending_blocked) != TYPE_BOOL:
		bad.append("%s: ending_blocked is not true or false" % id)
	return bad


## Problems with the story effects on one choice (or effect block).
func effect_problems(where: String, choice: Dictionary) -> PackedStringArray:
	var bad: PackedStringArray = []
	if choice.has("fragment") and not Game.FRAGMENTS.has(str(choice.fragment)):
		bad.append("%s: fragment %s is not a fragment id" % [where, str(choice.fragment)])
	if choice.has("how") and (not choice.has("fragment") or not Game.FRAGMENT_HOWS.has(str(choice.how))):
		bad.append("%s: how %s (needs a fragment, one of %s)" % [where, str(choice.how), ", ".join(Game.FRAGMENT_HOWS)])
	if choice.has("artifacts"):
		if not (choice.artifacts is Dictionary) or choice.artifacts.is_empty():
			bad.append("%s: artifacts is not a non-empty object" % where)
		else:
			for key in choice.artifacts:
				if not Game.ARTIFACTS.has(str(key)) or not _is_number(choice.artifacts[key]):
					bad.append("%s: artifacts %s=%s" % [where, key, str(choice.artifacts[key])])
	if choice.has("flag") and (typeof(choice.flag) != TYPE_STRING or str(choice.flag).strip_edges() == ""):
		bad.append("%s: flag is not a name" % where)
	if choice.has("proof") and (not _is_number(choice.proof) or int(choice.proof) < 1):
		bad.append("%s: proof %s is not a positive number" % [where, str(choice.proof)])
	if choice.has("ending"):
		var ending := str(choice.ending)
		if not Game.STORY_ENDINGS.has(ending) or not catalog.endings.get("endings", {}).has(ending):
			bad.append("%s: ending %s is not one of %s in endings.json" % [where, ending, ", ".join(Game.STORY_ENDINGS)])
	if choice.has("requires"):
		bad.append_array(requires_problems(where, choice.requires))
	return bad


## Problems with a choice's "requires": the "needs" keys plus Game.REQUIRES_EXTRA, "any_of" checked inside.
func requires_problems(where: String, req) -> PackedStringArray:
	var bad: PackedStringArray = []
	if not (req is Dictionary) or req.is_empty():
		bad.append("%s: requires is not a non-empty object" % where)
		return bad
	var plain := {}
	for key in req:
		if not Game.REQUIRES_EXTRA.has(str(key)):
			plain[key] = req[key]
	if not plain.is_empty():
		for line in needs_problems(where, {"needs": plain}):
			bad.append(line.replace("needs key", "requires key"))
	if req.has("proofs_min") and (not _is_number(req.proofs_min) or int(req.proofs_min) < 1 or int(req.proofs_min) > 10):
		bad.append("%s: proofs_min %s" % [where, str(req.proofs_min)])
	if req.has("hope_min") and (not _is_number(req.hope_min) or int(req.hope_min) < 0 or int(req.hope_min) > 100):
		bad.append("%s: hope_min %s" % [where, str(req.hope_min)])
	if req.has("any_flag"):
		if not (req.any_flag is Array) or req.any_flag.is_empty() \
				or req.any_flag.any(func(f): return typeof(f) != TYPE_STRING or str(f).strip_edges() == ""):
			bad.append("%s: any_flag is not a list of names" % where)
	if req.has("any_of"):
		if not (req.any_of is Array) or req.any_of.is_empty():
			bad.append("%s: any_of is not a non-empty list" % where)
		else:
			for i in req.any_of.size():
				bad.append_array(requires_problems("%s any_of[%d]" % [where, i], req.any_of[i]))
	return bad


## Problems with an event's "trigger": a known order, and "needs" keys that do not hang on a window.
func trigger_problems(id: String, ev: Dictionary) -> PackedStringArray:
	var bad: PackedStringArray = []
	var trigger = ev.trigger
	if not (trigger is Dictionary):
		return PackedStringArray(["%s: trigger is not an object" % id])
	for key in trigger:
		if not ["order", "needs"].has(str(key)):
			bad.append("%s: unknown trigger key %s" % [id, key])
	if not Game.TRIGGER_ORDERS.has(str(trigger.get("order", ""))):
		bad.append("%s: trigger order %s is not one of %s" % [id, str(trigger.get("order", "")), ", ".join(Game.TRIGGER_ORDERS)])
	if trigger.has("needs"):
		bad.append_array(needs_problems(id, {"needs": trigger.needs}))
		for key in ["leader", "answer", "after_weeks", "week"]:
			if trigger.needs is Dictionary and trigger.needs.has(key):
				bad.append("%s: trigger needs %s (a scene comes when its order is done)" % [id, key])
	if ev.has("needs") or ev.has("forced"):
		bad.append("%s: a triggered scene has needs or forced" % id)
	return bad


## Flags named in any "requires" (also inside any_of): each must be set by some choice's "flag".
func _required_flags(req, out: Dictionary) -> void:
	if not (req is Dictionary):
		return
	for key in ["flag", "no_flag"]:
		if req.has(key):
			out[str(req[key])] = true
	for flag in req.get("any_flag", []):
		out[str(flag)] = true
	for sub in req.get("any_of", []):
		_required_flags(sub, out)


## Every event with "needs" in any file, every choice in data/events_story.json, the story text.
func _validate() -> void:
	var bad: PackedStringArray = []
	var with_needs := 0
	var leaders := _leaders()
	var story := _story_ids()
	var triggered := 0
	var flags_set := {Game.EXPEDITION_FLAG: true}
	var flags_read := {}
	for ev in catalog.events:
		var id := str(ev.get("id", ""))
		if ev.has("needs") or ev.has("forced"):
			with_needs += 1
			bad.append_array(needs_problems(id, ev))
		if ev.has("trigger"):
			triggered += 1
			bad.append_array(trigger_problems(id, ev))
		for choice in ev.get("choices", []):
			bad.append_array(effect_problems("%s/%s" % [id, choice.get("id", "")], choice))
			if str(choice.get("flag", "")) != "":
				flags_set[str(choice.flag)] = true
			_required_flags(choice.get("requires", {}), flags_read)
		if not story.has(id):
			continue
		for key in ev:
			if not LeaderEventChecks.EVENT_KEYS.has(str(key)):
				bad.append("%s: unknown key %s" % [id, key])
		for key in ["fragment", "no_fragment"]:
			if ev.get("needs", {}).has(key) and not catalog.truth.has(str(ev.needs[key])):
				bad.append("%s: needs.%s %s is not in truth.json" % [id, key, str(ev.needs[key])])
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
				if not LeaderEventChecks.CHOICE_KEYS.has(str(key)):
					bad.append("%s/%s: unknown effect %s" % [id, cid, key])
			if choice.has("fragment") and not catalog.truth.has(str(choice.fragment)):
				bad.append("%s/%s: fragment %s is not in truth.json" % [id, cid, str(choice.fragment)])
			var cost = choice.get("cost", {})
			if cost is Dictionary:
				for key in cost:
					if not LeaderEventChecks.STOCK.has(str(key)) and not Game.ARTIFACTS.has(str(key)):
						bad.append("%s/%s: unknown cost %s" % [id, cid, key])
			else:
				bad.append("%s/%s: cost is not an object" % [id, cid])
			var shifts = choice.get("standing", {})
			if shifts is Dictionary:
				for fid in shifts:
					if not leaders.has(str(fid)):
						bad.append("%s/%s: standing names %s" % [id, cid, fid])
			else:
				bad.append("%s/%s: standing is not an object" % [id, cid])
		for en in texts:
			bad.append_array(_text_problems(id, en, str(catalog.story_ru.get(en, ""))))
	for flag in flags_read:
		if not flags_set.has(flag):
			bad.append("requires reads flag %s that no choice sets" % flag)
	_expect(bad.is_empty(),
		"Event conditions and story effects valid: %d events with needs, %d scenes by order, %d story events, every story string has Russian, no dashes" % [with_needs, triggered, story.size()],
		"story data: " + "; ".join(bad))


func _text_problems(id: String, en: String, ru: String) -> PackedStringArray:
	var bad: PackedStringArray = []
	if en.strip_edges() == "":
		bad.append("%s: empty text" % id)
		return bad
	if ru.strip_edges() == "":
		bad.append("%s: no Russian for \"%s\"" % [id, en])
	for dash in ["\u2014", "\u2013"]:
		if en.contains(dash) or ru.contains(dash):
			bad.append("%s: dash in \"%s\"" % [id, en])
	return bad


## data/truth.json: exactly the five fixed ids, each with title, hint and text in both languages.
func _truth() -> void:
	var bad: PackedStringArray = []
	for id in catalog.truth:
		if not Game.FRAGMENTS.has(str(id)):
			bad.append("unknown fragment %s" % id)
	for id in Game.FRAGMENTS:
		var row: Dictionary = catalog.truth.get(id, {})
		if row.is_empty():
			bad.append("%s missing" % id)
			continue
		for key in TRUTH_KEYS:
			var pair = row.get(key, {})
			if not (pair is Dictionary):
				bad.append("%s.%s is not {en, ru}" % [id, key])
				continue
			bad.append_array(_text_problems("%s.%s" % [id, key], str(pair.get("en", "")), str(pair.get("ru", ""))))
	_expect(bad.is_empty(), "Truth fragments: %d written, title, hint and text in EN and RU" % catalog.truth.size(), "truth.json: " + "; ".join(bad))


## data/endings.json: the eight endings with title and text, every leader's four epilogue lines, three truth
## lines; EN and RU everywhere, no dashes.
func _endings() -> void:
	var bad: PackedStringArray = []
	var data: Dictionary = catalog.endings
	var endings: Dictionary = data.get("endings", {})
	for id in endings:
		if not Game.ENDINGS.has(str(id)):
			bad.append("unknown ending %s" % id)
	for id in Game.ENDINGS:
		for key in ["title", "text"]:
			bad.append_array(_pair_problems("endings.%s.%s" % [id, key], endings.get(id, {}).get(key, null)))
	var leaders: Dictionary = data.get("leaders", {})
	for fid in _leaders():
		for state in ["accepted", "refused", "helped", "none"]:
			bad.append_array(_pair_problems("leaders.%s.%s" % [fid, state], leaders.get(fid, {}).get(state, null)))
	for fid in leaders:
		if not _leaders().has(str(fid)):
			bad.append("leaders.%s is not a leader" % fid)
	for state in ["none", "some", "proof"]:
		bad.append_array(_pair_problems("truth.%s" % state, data.get("truth", {}).get(state, null)))
	_expect(bad.is_empty() and endings.size() == 8 and leaders.size() == 5,
		"Endings: %d endings, %d leaders x 4 epilogue lines, 3 truth lines, EN and RU, no dashes" % [endings.size(), leaders.size()],
		"endings.json: " + "; ".join(bad))


func _pair_problems(where: String, pair) -> PackedStringArray:
	if not (pair is Dictionary):
		return PackedStringArray(["%s is not {en, ru}" % where])
	return _text_problems(where, str(pair.get("en", "")), str(pair.get("ru", "")))


## Empty data/events_story.json and data/truth.json ({"events": []}, {"fragments": []}) load and play.
func _placeholders() -> void:
	var cat := Catalog.new()
	cat.load_all()
	var story := _story_ids()
	cat.events = cat.events.filter(func(ev): return not story.has(str(ev.get("id", ""))))
	var before := cat.events.size()
	var ru := cat.add_events({"events": []}, {})
	var empty_truth := {"fragments": []}
	cat.truth = cat._index(empty_truth.get("fragments", []), "id")
	var added := cat.events.size() - before
	var game := Game.new()
	game.setup(cat, 3, 40)
	var learned := game.know_fragment("depot_order", "honest")
	var guard := 0
	while game.over == "" and guard < 42:
		guard += 1
		game.end_week()
	_expect(added == 0 and ru.is_empty() and cat.truth.is_empty() and learned
		and game.fragment_text("depot_order", "title") == "" and game.errors.is_empty(),
		"Empty story and truth placeholders load; a fragment with no text is still learned; a run plays to the end",
		"placeholders added %d ru %s truth %s learned %s errors %s" % [added, ru, cat.truth, learned, game.errors])


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.pending = []
	game.audience = {}
	return game


func _probe(needs: Dictionary, forced := false) -> Dictionary:
	return {"id": "probe", "title": "Probe", "major": false, "weight": 5, "cooldown": 99, "forced": forced, "needs": needs,
		"text": "Probe.", "choices": [{"id": "a", "label": "A"}, {"id": "b", "label": "B"}]}


## Each "needs" key on its own: the event shows only while it holds.
func _conditions() -> void:
	var bad: PackedStringArray = []
	var game := _game()
	game.week = 10
	game.standing.synod = 30
	game.flags["seen_lamps"] = true
	game.artifacts.iron = 2
	game.fragments = {"synod_recording": {"known": true, "how": "honest", "week": 9}}
	game.leader_answers = {"depot": {"answer": "silence", "week": 6}}
	var flood_week := 0
	for season in catalog.balance.get("seasons", []):
		if str(season.id) == "flood":
			flood_week = int(season.week)
	var cases := [
		[{"leader": "depot", "answer": "refused"}, {"leader": "depot", "answer": "accepted"}],
		[{"leader": "depot", "answer": "refused", "after_weeks": [3, 5]}, {"leader": "depot", "answer": "refused", "after_weeks": [5, 9]}],
		[{"standing_min": {"synod": 30}}, {"standing_min": {"synod": 31}}],
		[{"standing_max": {"synod": 30}}, {"standing_max": {"synod": 29}}],
		[{"band": {"synod": "useful"}}, {"band": {"synod": "pact"}}],
		[{"fragment": "synod_recording"}, {"fragment": "depot_order"}],
		[{"no_fragment": "depot_order"}, {"no_fragment": "synod_recording"}],
		[{"flag": "seen_lamps"}, {"flag": "never_set"}],
		[{"no_flag": "never_set"}, {"no_flag": "seen_lamps"}],
		[{"artifacts_min": {"iron": 2}}, {"artifacts_min": {"iron": 3}}],
		[{"week": [10, 12]}, {"week": [11, 12]}],
		[{"ending_blocked": true}, {"ending_blocked": false}],
		[{"week": [8, 12], "standing_min": {"synod": 20}, "flag": "seen_lamps"}, {"week": [8, 12], "standing_min": {"synod": 20}, "flag": "never_set"}],
	]
	var reasons: PackedStringArray = []
	for pair in cases:
		if game.needs_window(_probe(pair[0])) < 0:
			bad.append("held: %s" % str(pair[0]))
		if game.needs_window(_probe(pair[1])) >= 0:
			bad.append("not held: %s" % str(pair[1]))
		if game.requires_reason(pair[0]) != "":
			bad.append("requires met but says %s" % game.requires_reason(pair[0]))
		var why := game.requires_reason(pair[1])
		if why == "" or why.contains("%"):
			bad.append("requires %s unmet without a reason" % str(pair[1]))
		reasons.append(why)
	var season_game := _game()
	season_game.week = flood_week
	season_game.active_season = {"id": "flood", "start": flood_week, "until": flood_week + 1}
	if season_game.needs_window(_probe({"season": "flood"})) < 0 or season_game.needs_window(_probe({"season": "cold"})) >= 0:
		bad.append("season")
	game.events_seen["probe"] = 4
	if game.needs_window(_probe({"week": [1, 40]})) >= 0:
		bad.append("shown twice")
	_expect(bad.is_empty(), "Every needs key holds and fails on its own, all keys together, once a run; as \"requires\" each unmet key gives a reason (%d cases)" % (cases.size() + 2),
		"conditions " + "; ".join(bad))
	var invalid := {
		"unknown key": {"weather": "rain"}, "standing range": {"standing_min": {"synod": 300}},
		"band name": {"band": {"synod": "friendly"}}, "fragment id": {"fragment": "the_moon"},
		"artifact kind": {"artifacts_min": {"gold": 1}}, "week order": {"week": [9, 4]},
		"season id": {"season": "summer"}, "ending flag": {"ending_blocked": "yes"}, "answer": {"leader": "depot", "answer": "maybe"},
	}
	var missed: PackedStringArray = []
	for name in invalid:
		if needs_problems("probe", _probe(invalid[name])).is_empty():
			missed.append(name)
	var effects := {"fragment id": {"fragment": "the_moon"}, "how": {"fragment": "depot_order", "how": "stolen"},
		"how alone": {"how": "honest"}, "artifact kind": {"artifacts": {"gold": 1}}, "flag": {"flag": ""},
		"proof zero": {"proof": 0}, "ending id": {"ending": "winter"}, "requires empty": {"requires": {}},
		"requires key": {"requires": {"luck": 3}}, "proofs_min": {"requires": {"proofs_min": "3"}},
		"hope_min": {"requires": {"hope_min": 140}}, "any_flag": {"requires": {"any_flag": []}},
		"any_of empty": {"requires": {"any_of": []}}, "any_of inner": {"requires": {"any_of": [{"standing_min": {"synod": 300}}]}}}
	for name in effects:
		if effect_problems("probe", effects[name]).is_empty():
			missed.append("effect " + name)
	var triggers := {"order": {"order": "approach_moon"}, "key": {"order": "approach_floor", "when": 3},
		"week": {"order": "approach_floor", "needs": {"week": [1, 4]}}, "needs key": {"order": "approach_floor", "needs": {"weather": 1}}}
	for name in triggers:
		if trigger_problems("probe", {"id": "probe", "trigger": triggers[name]}).is_empty():
			missed.append("trigger " + name)
	_expect(missed.is_empty(), "Validation rejects every malformed needs key, story effect, requires and trigger (%d cases)" % (invalid.size() + effects.size() + triggers.size()),
		"validation let through: " + ", ".join(missed))


## Forced events show at dawn outside the random pool, one a week. The others are story beats: never in the
## pool, at most one a week on top of it, weighted from story_rng alone, once a run, only inside their window.
func _draws() -> void:
	var game := _game()
	game.week = 6
	var forced := _probe({"week": [5, 7]}, true)
	var beat := _probe({"week": [5, 7]})
	beat.id = "probe_beat"
	var later := _probe({"week": [5, 9]}, true)
	later.id = "probe_later"
	game.catalog = _with_events([forced, beat, later])
	game.week_event_ids = {}
	game._offer_forced_event()
	var first: Array = game.pending.map(func(ev): return str(ev.id))
	var needs_in_pool := game._event_pool(false).any(func(ev): return ev.has("needs"))
	game.pending = []
	game.week = 7
	game.week_event_ids = {}
	game._offer_forced_event()
	var second: Array = game.pending.map(func(ev): return str(ev.id))
	_expect(first == ["probe"] and not needs_in_pool and second == ["probe_later"],
		"Forced story events show at dawn one a week, closest window first, never pooled",
		"first %s needs pooled %s second %s" % [first, needs_in_pool, second])
	var slot := _game()
	var other := _probe({"week": [5, 7]})
	other.id = "probe_other"
	var closed := _probe({"week": [9, 12]})
	closed.id = "probe_closed"
	slot.catalog = _with_events([beat, other, closed])
	var shown: Array = []
	var pool_stream := true
	var story_stream := true
	for w in [5, 6, 7, 8]:
		slot.week = w
		slot.week_event_ids = {}
		slot.pending = [{"id": "major_waiting", "major": true, "choices": []}]
		slot.event_last = {}
		var rng_before := slot.rng.state
		var story_before := slot.story_rng.state
		slot._offer_story_event()
		pool_stream = pool_stream and slot.rng.state == rng_before
		var week_shown: Array = slot.pending.slice(1).map(func(ev): return str(ev.id))
		if not week_shown.is_empty():
			story_stream = story_stream and slot.story_rng.state != story_before
		shown.append(week_shown)
	var once: bool = shown[0].size() == 1 and shown[1].size() == 1 and shown[0] != shown[1] and shown[2].is_empty() and shown[3].is_empty()
	_expect(once and pool_stream and story_stream,
		"Story beats come one a week on top of the pool, weighted from their own stream only, once a run, inside their window",
		"shown %s pool stream untouched %s story stream drawn %s" % [shown, pool_stream, story_stream])


func _with_events(extra: Array) -> Catalog:
	var cat := Catalog.new()
	cat.load_all()
	cat.events = cat.events.filter(func(ev): return not ev.has("needs")) + extra
	return cat


## "fragment", "artifacts" and "flag" choice effects; know_fragment sets a fragment once.
func _effects() -> void:
	var game := _game()
	game.week = 12
	var ev := _probe({"week": [1, 40]})
	ev.choices[0] = {"id": "a", "label": "A", "fragment": "exchange_papers", "how": "dirty", "artifacts": {"iron": 2, "words": 1}, "flag": "probe_flag"}
	game._present_event(ev)
	var applied := game.apply({"kind": "event", "event_id": "probe", "choice_id": "a"})
	var row: Dictionary = game.fragments.get("exchange_papers", {})
	var truth_rows := game.journal.filter(func(r): return str(r.kind) == "truth")
	var dawn_line := game.log.any(func(e): return str(e.text).begins_with("TRUTH ") and bool(e.important))
	var again := game.know_fragment("exchange_papers", "honest")
	var bogus := game.know_fragment("the_moon", "honest")
	_expect(applied and bool(row.get("known", false)) and str(row.how) == "dirty" and int(row.week) == 12
		and int(game.artifacts.iron) == 2 and int(game.artifacts.words) == 1 and game.flags.has("probe_flag")
		and truth_rows.size() == 1 and dawn_line and not again and not bogus and str(game.fragments.exchange_papers.how) == "dirty",
		"Choice effects: fragment learned once the dirty way, artifacts, flag; journal row and dawn line",
		"applied %s fragment %s artifacts %s flags %s rows %d dawn %s again %s" % [applied, row, game.artifacts, game.flags.keys(), truth_rows.size(), dawn_line, again])
	var found := _game()
	found.week = 3
	found._apply_story_effects({"fragment": "quarantine_path"})
	_expect(str(found.fragments.get("quarantine_path", {}).get("how", "")) == "found", "A fragment with no \"how\" counts as found", "how %s" % str(found.fragments))


## One Words artifact for every three distinct stories heard, each threshold once; replays and a story still
## playing ("started") do not count.
func _words() -> void:
	var ids: Array = Voice.of_type("story").map(func(row): return str(row.id))
	var game := _game()
	var grants: Array = []
	game.vo_heard[ids[7]] = "started"
	for i in 7:
		grants.append(game.hear_story(str(ids[i])))
		grants.append(game.hear_story(str(ids[i])))
	var rows := game.journal.filter(func(r): return str(r.kind) == "testimony")
	_expect(grants == [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0] and int(game.artifacts.words) == 2 and game.story_words == 2
		and rows.size() == 2 and game.stories_heard() == 7 and game.stories_to_testimony() == 2,
		"Words: one per 3 distinct stories heard, once per threshold (%d stories voiced)" % ids.size(),
		"grants %s words %d granted %d rows %d heard %d next %d" % [grants, int(game.artifacts.words), game.story_words, rows.size(), game.stories_heard(), game.stories_to_testimony()])
	var older := _game()
	for i in 4:
		older.vo_heard[str(ids[i])] = true
	var caught := older.hear_story(str(ids[4]))
	_expect(caught == 1 and int(older.artifacts.words) == 1, "Stories heard before this save count toward the next testimony",
		"caught %d words %d" % [caught, int(older.artifacts.words)])


## The South Ferry expedition sets its flag on the way back; a story event reading it can grant iron.
func _expedition() -> void:
	var game := _game()
	var back := _probe({"flag": Game.EXPEDITION_FLAG}, true)
	back.id = "probe_ferry"
	back.choices[0] = {"id": "a", "label": "A", "artifacts": {"iron": 1}}
	game.catalog = _with_events([back])
	game.expedition = {"left": 1, "tunnel": "to_ferry"}
	game.squads[game.player].away = true
	game._tick_expedition()
	game.week_event_ids = {}
	game._offer_forced_event()
	var shown := game.pending.any(func(ev): return str(ev.id) == "probe_ferry")
	var ok := shown and game.apply({"kind": "event", "event_id": "probe_ferry", "choice_id": "a"})
	_expect(game.flags.has(Game.EXPEDITION_FLAG) and ok and int(game.artifacts.iron) == 1,
		"Expedition back sets %s; a story event on it grants iron" % Game.EXPEDITION_FLAG, "flag %s shown %s iron %d" % [game.flags.keys(), shown, int(game.artifacts.iron)])


## fragments and story_words survive a save; a schema 3 save loads with none; malformed rows are rejected.
func _saves() -> void:
	var game := _game()
	game.week = 15
	game.know_fragment("directorate_ledger", "honest")
	game.story_words = 2
	game.artifacts.words = 2
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var copy := _game()
	var loaded := copy.import_state(data)
	_expect(loaded and copy.fragments == game.fragments and copy.story_words == 2, "Fragments and testimonies survive a save",
		"reload %s %s %s" % [loaded, copy.load_error, copy.fragments])
	var old := data.duplicate(true)
	old["schema"] = 3
	for key in Game.V3_ADDED:
		old.erase(key)
	copy = _game()
	copy.fragments = {"depot_order": {"known": true, "how": "found", "week": 1}}
	copy.story_words = 5
	loaded = copy.import_state(old)
	_expect(loaded and copy.fragments.is_empty() and copy.story_words == 0, "Schema 3 save loads with no fragments and no testimonies",
		"schema 3 %s %s %s %d" % [loaded, copy.load_error, copy.fragments, copy.story_words])
	var cases := {
		"unknown fragment": ["fragments", {"the_moon": {"known": true, "how": "found", "week": 2}}],
		"bad how": ["fragments", {"depot_order": {"known": true, "how": "stolen", "week": 2}}],
		"future week": ["fragments", {"depot_order": {"known": true, "how": "found", "week": 30}}],
		"known text": ["fragments", {"depot_order": {"known": "yes", "how": "found", "week": 2}}],
		"not a row": ["fragments", {"depot_order": true}],
		"negative testimonies": ["story_words", -1],
		"artifact text": ["artifacts", {"papers": 0, "iron": "1", "words": 0}],
	}
	var bad: PackedStringArray = []
	for name in cases:
		var broken := data.duplicate(true)
		broken[cases[name][0]] = cases[name][1]
		copy = _game()
		if copy.import_state(broken):
			bad.append(name)
	for key in Game.V3_ADDED:
		var missing := data.duplicate(true)
		missing.erase(key)
		copy = _game()
		if copy.import_state(missing):
			bad.append("current schema without " + key)
	_expect(bad.is_empty(), "Rejects malformed fragments, testimonies and artifacts", "accepted: " + ", ".join(bad))


func _shown(game: Game, id: String) -> bool:
	return game.pending.any(func(ev): return str(ev.id) == id)


## Bunker scenes come from orders, never from the pool or the story slot: the Floor on its approach, the
## Quarantine on its order once the path is known and there is iron, the Observatory on its own order.
## Each comes at the next dawn, once a run.
func _scenes() -> void:
	var bad: PackedStringArray = []
	var game := _game()
	game.week = 20
	if (game._event_pool(false) + game._event_pool(true)).any(func(ev): return ev.has("trigger")):
		bad.append("a scene is in the pool")
	game._tunnel_by_id("to_floor").dug = true
	game.artifacts.papers = 1
	if not game.apply({"kind": "order", "order": "approach"}):
		bad.append("approach refused")
	if not game.floor_met or game.story_queue != ["st3_floor"] or _shown(game, "st3_floor"):
		bad.append("floor met %s queue %s" % [game.floor_met, game.story_queue])
	if game.approach_block() == "":
		bad.append("approach open twice")
	game.end_week()
	if not _shown(game, "st3_floor") or not game.story_queue.is_empty() or not game.floor_met:
		bad.append("floor not at the next dawn: queue %s" % game.story_queue)
	game.apply({"kind": "event", "event_id": "st3_floor", "choice_id": "leave"})
	game._fire_trigger("approach_floor")
	if not game.story_queue.is_empty():
		bad.append("floor queued twice")
	var trip := _game()
	trip.week = 20
	trip.fragments = {"quarantine_path": {"known": true, "how": "found", "week": 18}}
	trip.artifacts.iron = 1
	trip.expedition = {"left": 1, "tunnel": "to_ferry"}
	trip.squads[trip.player].away = true
	trip._tick_expedition()
	if not trip.story_queue.is_empty() or bool(trip.stations.vault.hidden) or not trip.flags.has(Game.EXPEDITION_FLAG):
		bad.append("expedition back: queue %s vault hidden %s" % [trip.story_queue, trip.stations.vault.hidden])
	var gate := _game()
	gate.week = 22
	var shut := gate.quarantine_block()
	gate.fragments = {"quarantine_path": {"known": true, "how": "honest", "week": 20}}
	var no_iron := gate.quarantine_block()
	gate.artifacts.iron = 1
	var gate_orders := gate.orders_left
	if shut != "Needs the Lamplighters' path and iron" or no_iron != shut or gate.quarantine_block() != "":
		bad.append("quarantine locked '%s' no iron '%s' open '%s'" % [shut, no_iron, gate.quarantine_block()])
	if not gate.queue_order({"kind": "order", "order": "approach_quarantine"}) or gate.orders_left != gate_orders - 1 or _shown(gate, "st3_quarantine"):
		bad.append("quarantine order not queued for one order")
	gate.end_week()
	if not _shown(gate, "st3_quarantine") or gate.quarantine_block() != "The Quarantine has already been met." or gate.can_approach_quarantine():
		bad.append("quarantine not met once at the next dawn")
	var obs := _game()
	obs.week = 24
	var locked := obs.observatory_block()
	obs.artifacts.words = 2
	var half := obs.observatory_block()
	obs.fragments = {"synod_recording": {"known": true, "how": "honest", "week": 20}}
	var open := obs.observatory_block()
	var hidden_before := bool(obs.stations.oldcommand.hidden)
	var orders := obs.orders_left
	var queued := obs.queue_order({"kind": "order", "order": "approach_observatory"})
	if locked != "Needs 2 testimonies and the recording" or half != locked or open != "" or not hidden_before:
		bad.append("observatory locked '%s' half '%s' open '%s' hidden %s" % [locked, half, open, hidden_before])
	if not queued or obs.orders_left != orders - 1:
		bad.append("observatory order not queued for one order")
	obs.end_week()
	if not _shown(obs, "st3_observatory") or bool(obs.stations.oldcommand.hidden) or not bool(obs.stations.oldcommand.known):
		bad.append("observatory not met at the next dawn")
	if obs.observatory_block() != "The Observatory has already been met." or obs.can_approach_observatory():
		bad.append("observatory open twice")
	_expect(bad.is_empty(), "Bunker scenes come by order at the next dawn, once a run, never pooled; Quarantine and Observatory orders locked with their reasons; the expedition sets off no scene",
		"scenes: " + "; ".join(bad))


## A choice with unmet "requires" stays on the card, closed, with its reason, and cannot be taken. "proof" adds
## to proofs(), a cost may spend artifacts, "ending" ends the run at once.
func _choices() -> void:
	var bad: PackedStringArray = []
	var game := _game()
	game.week = 20
	game.hope = 40
	var ev := _probe({"week": [1, 40]})
	ev.choices = [
		{"id": "proof", "label": "P", "requires": {"proofs_min": 3}, "ending": "open_door"},
		{"id": "hope", "label": "H", "requires": {"hope_min": 60}},
		{"id": "any", "label": "A", "requires": {"any_flag": ["observatory_trusted", "observatory_sheltered"]}},
		{"id": "either", "label": "E", "requires": {"any_of": [{"flag": "floor_to_directorate"}, {"standing_min": {"directorate": 50}}]}},
		{"id": "spend", "label": "S", "cost": {"words": 2}, "proof": 1},
		{"id": "free", "label": "F"},
	]
	game.proof_extra = 1
	var wants := {
		"proof": "Needs 3 proofs, you have 1",
		"hope": "Needs hope 60, now 40",
		"any": "Needs the Observatory's trust or the Observatory sheltered",
		"either": "Needs the Floor handed over or the Directorate's trust: 50",
	}
	for choice in ev.choices:
		var why := game.lock_reason(choice)
		if wants.has(str(choice.id)) and why != str(wants[choice.id]):
			bad.append("%s says '%s'" % [choice.id, why])
	var mixed := game.requires_reason({"any_of": [{"flag": "floor_to_directorate", "hope_min": 90}, {"proofs_min": 5}]})
	if not mixed.contains("; or "):
		bad.append("any_of with compound ways says '%s'" % mixed)
	if not game.choice_locked(ev.choices[3]):
		bad.append("any_of open while neither way holds")
	game.standing.directorate = 50
	if game.choice_locked(ev.choices[3]):
		bad.append("any_of met but locked")
	game._present_event(ev)
	if game.apply({"kind": "event", "event_id": "probe", "choice_id": "proof"}) or game.over != "":
		bad.append("took a closed choice")
	if game.apply({"kind": "event", "event_id": "probe", "choice_id": "spend"}):
		bad.append("spent words it did not have")
	game.artifacts.words = 2
	var before := game.proofs()
	if not game.apply({"kind": "event", "event_id": "probe", "choice_id": "spend"}) or int(game.artifacts.words) != 0 or game.proofs() != before + 1:
		bad.append("spend: words %d proofs %d" % [int(game.artifacts.words), game.proofs()])
	var end := _game()
	end.week = 30
	end.proof_extra = 3
	var door := _probe({"week": [1, 40]})
	door.choices = [{"id": "door", "label": "D", "requires": {"proofs_min": 3}, "ending": "open_door"}, {"id": "b", "label": "B"}]
	end._present_event(door)
	end.apply({"kind": "event", "event_id": "probe", "choice_id": "door"})
	var week_then := end.week
	end.end_week()
	if end.over != "open_door" or end.ending_id() != "open_door" or end.week != week_then:
		bad.append("ending over '%s' id '%s' week %d" % [end.over, end.ending_id(), end.week])
	_expect(bad.is_empty(), "Closed choices show why (proofs, hope, flags, either way) and cannot be taken; proof counts, words pay, an ending ends the run",
		"choices: " + "; ".join(bad))


## st3_decision: forced in weeks 34 to 38 only while one of its endings can be chosen, once; "hold" changes
## nothing; the stewards and auto-resolve never pick an ending for the player. With every ending closed the run
## ends as winter at week 40.
func _decision() -> void:
	var bad: PackedStringArray = []
	var ev: Dictionary = {}
	for row in catalog.events:
		if str(row.get("id", "")) == "st3_decision":
			ev = row
	if ev.is_empty():
		_expect(false, "", "st3_decision missing")
		return
	var shut := _game()
	shut.week = 34
	if not shut.ending_blocked() or shut.needs_window(ev) >= 0:
		bad.append("shown with every ending closed")
	var game := _game()
	game.week = 34
	game.proof_extra = 3
	game.flags["floor_published"] = true
	if game.ending_blocked() or game.needs_window(ev) < 0:
		bad.append("not shown with the door open")
	game.week = 33
	if game.needs_window(ev) >= 0:
		bad.append("shown before week 34")
	game.week = 34
	game.week_event_ids = {}
	game._offer_forced_event()
	if not _shown(game, "st3_decision"):
		bad.append("not offered at dawn")
	var auto := _game()
	auto.week = 34
	auto.proof_extra = 3
	auto.flags["floor_published"] = true
	auto._present_event(ev)
	auto._resolve_pending()
	if auto.over != "" or _shown(auto, "st3_decision") or not auto.events_seen.has("st3_decision"):
		bad.append("auto-resolve over '%s' still pending %s" % [auto.over, _shown(auto, "st3_decision")])
	var stock_before := game.stock.duplicate(true)
	var hope_before := game.hope
	if not game.apply({"kind": "event", "event_id": "st3_decision", "choice_id": "hold"}) or game.over != "" \
			or game.stock != stock_before or game.hope != hope_before:
		bad.append("hold changed the run")
	game.week = 35
	if game.needs_window(ev) >= 0:
		bad.append("shown again after hold")
	var winter := _game()
	for over in Game.OVER_ENDINGS:
		winter.over = str(over)
		if winter.ending_id() != str(Game.OVER_ENDINGS[over]) or winter.ending_text(winter.ending_id(), "title") == "":
			bad.append("%s maps to %s" % [over, winter.ending_id()])
	_expect(bad.is_empty(), "Final decision: weeks 34 to 38 while an ending is open, once; hold changes nothing; auto-resolve holds; game overs map to their endings",
		"decision: " + "; ".join(bad))


## The epilogue's leader lines by answer and its truth line by proofs; deals made and turned away.
func _epilogue() -> void:
	var bad: PackedStringArray = []
	var game := _game()
	game.leader_answers = {"depot": {"answer": "accepted", "week": 3}, "synod": {"answer": "silence", "week": 4},
		"exchange": {"answer": "refused", "week": 5}, "black_flag": {"answer": "helped", "week": 6}}
	var states := {"depot": "accepted", "synod": "refused", "exchange": "refused", "black_flag": "helped", "directorate": "none"}
	for fid in states:
		if game.leader_epilogue_state(fid) != str(states[fid]) or game.leader_epilogue(fid) == "":
			bad.append("%s state %s" % [fid, game.leader_epilogue_state(fid)])
	var truths: Array = [game.truth_state()]
	game.know_fragment("depot_order", "dirty")
	truths.append(game.truth_state())
	game.proof_extra = 3
	truths.append(game.truth_state())
	if truths != ["none", "some", "proof"] or game.truth_epilogue() == "":
		bad.append("truth %s" % truths)
	game.journal = [{"kind": "audience", "result": "deal"}, {"kind": "audience", "result": "refused"},
		{"kind": "audience", "result": "silence"}, {"kind": "audience", "result": "helped"}]
	if game.deals_tally() != {"made": 1, "refused": 2}:
		bad.append("deals %s" % game.deals_tally())
	_expect(bad.is_empty(), "Epilogue: leader lines by answer (silence reads as refused), truth line by proofs, deals tallied",
		"epilogue: " + "; ".join(bad))


## Share of bot runs (percent) an act I story event (st1_*) must show in; COVERAGE_REST for any not listed.
## Later acts hang on standing and deals the bots rarely reach, so they are only counted.
const COVERAGE := {"st1_first_paper": 90, "st1_story_night": 90}
const COVERAGE_REST := 75


## The stewards play with every story event in the data plus a forced and a drawn probe: no sim errors, the
## probes show and get answered, and each of the lead's story events shows in its COVERAGE share of the runs.
func _bot() -> void:
	var forced := _probe({"week": [12, 16], "artifacts_min": {"papers": 1}}, true)
	forced.id = "probe_forced"
	forced.choices[0] = {"id": "a", "label": "A", "fragment": "synod_recording", "how": "honest"}
	var drawn := _probe({"week": [33, 39]})
	drawn.id = "probe_drawn"
	drawn.choices[0] = {"id": "a", "label": "A", "artifacts": {"iron": 1}, "flag": "probe_drawn"}
	var cat := Catalog.new()
	cat.load_all()
	cat.events = cat.events + [forced, drawn]
	var story := _story_ids()
	var shown := {}
	var errors := 0
	var runs := 0
	var probes := {"probe_forced": 0, "probe_drawn": 0}
	for profile in ["careful", "expander", "follower"]:
		for run_seed in range(1, 11):
			var game := Game.new()
			game.setup(cat, run_seed, 40)
			game.artifacts.papers = 1
			var bot := Bot.new()
			bot.profile = profile
			var guard := 0
			while game.over == "" and guard < 42:
				guard += 1
				bot._act(game)
				game.end_week()
			runs += 1
			errors += game.errors.size()
			for id in game.events_seen:
				if story.has(str(id)):
					shown[str(id)] = int(shown.get(str(id), 0)) + 1
				if probes.has(str(id)):
					probes[str(id)] += 1
			if game.fragment_known("synod_recording") != game.events_seen.has("probe_forced"):
				errors += 1
	var counts: PackedStringArray = []
	var rare: PackedStringArray = []
	for id in story:
		counts.append("%s %d" % [id, int(shown.get(id, 0))])
		if str(id).begins_with("st1_") and int(shown.get(id, 0)) * 100 < runs * int(COVERAGE.get(id, COVERAGE_REST)):
			rare.append("%s %d/%d (needs %d%%)" % [id, int(shown.get(id, 0)), runs, int(COVERAGE.get(id, COVERAGE_REST))])
	_expect(errors == 0 and int(probes.probe_forced) == runs and int(probes.probe_drawn) > 0,
		"Bots play story events in %d runs without errors; forced probe %d/%d, drawn probe %d" % [runs, int(probes.probe_forced), runs, int(probes.probe_drawn)],
		"bot story errors %d probes %s" % [errors, probes])
	_expect(rare.is_empty(), "Story events show often enough in %d bot runs: %s" % [runs, ", ".join(counts)],
		"story events shown too rarely in %d bot runs: %s" % [runs, ", ".join(rare)])
