extends RefCounted

## Random pool batches (data/events_pool.json, docs/briefs/cursor_event_pool_1.txt): data validation, the draw
## window and every choice applied once. Pure sim, no UI. Run by sim/audience_checks.gd, so check_audience.gd
## and bot_run.gd both cover it. The card fit at 1280x720 is shot by .tools/pool_shots.gd.

const POOL_FILE := "events_pool.json"
const EVENT_KEYS := ["id", "banner", "title", "major", "min_week", "max_week", "weight", "cooldown", "text", "choices", "who",
	"ru_own"]
const CHOICE_KEYS := ["id", "label", "hope", "discontent", "food", "tokens", "materials", "cost", "artifacts",
	"standing", "ru_own"]
const STOCK := ["food", "air", "power", "materials", "tokens", "influence"]
const CHOICES := 3

var catalog: Catalog
var lines: PackedStringArray = []
var failed := false


static func run(cat: Catalog) -> Dictionary:
	var checks = load("res://sim/pool_checks.gd").new()
	checks.catalog = cat
	checks._validate()
	checks._window()
	checks._apply()
	return {"ok": not checks.failed, "lines": checks.lines}


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		lines.append(good + ": ok")
	else:
		failed = true
		lines.append("FAIL " + bad)


func _pool_ids() -> Array:
	var out: Array = []
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + POOL_FILE))
	for ev in data.get("events", []) if data is Dictionary else []:
		out.append(str(ev.get("id", "")))
	return out


func _pool_events() -> Array:
	var ids := _pool_ids()
	return catalog.events.filter(func(ev): return ids.has(str(ev.get("id", ""))))


## Who a card may name: a first name from data/residents.json or a Coney cast name (data/characters_coney.json),
## which replaces five residents' names on the Coney start.
func _first_names() -> Dictionary:
	var out := {}
	for row in catalog.residents:
		var name := str(row.get("name", "")).strip_edges()
		if name != "":
			out[name.split(" ")[0]] = true
	for row in catalog.coney.get("characters", []):
		var cast := str(row.get("name", {}).get("en", "")).strip_edges()
		if cast != "":
			out[cast] = true
	return out


func _leaders() -> Dictionary:
	var out := {}
	for row in catalog.leaders.get("factions", []):
		out[str(row.get("id", ""))] = true
	return out


func _validate() -> void:
	var bad: PackedStringArray = []
	var events := _pool_events()
	var names := _first_names()
	var leaders := _leaders()
	var counts := {}
	for ev in catalog.events:
		counts[str(ev.get("id", ""))] = int(counts.get(str(ev.get("id", "")), 0)) + 1
	for ev in events:
		var id := str(ev.id)
		if int(counts.get(id, 0)) != 1:
			bad.append("%s: id used %d times across event files" % [id, int(counts.get(id, 0))])
		for key in ev:
			if not EVENT_KEYS.has(str(key)):
				bad.append("%s: unknown key %s" % [id, key])
		if ev.has("who") and not names.has(str(ev.who)):
			bad.append("%s: who %s is no resident's first name or Coney cast name" % [id, ev.who])
		var low := int(ev.get("min_week", 1))
		var high := int(ev.get("max_week", 99))
		if low < 1 or low > high or high > 40:
			bad.append("%s: weeks %d to %d" % [id, low, high])
		var texts: Array = [str(ev.get("title", "")), str(ev.get("text", ""))]
		var choices: Array = ev.get("choices", [])
		if choices.size() != CHOICES:
			bad.append("%s: %d choices" % [id, choices.size()])
		var dis_sum := 0
		var hope_sum := 0
		for choice in choices:
			dis_sum += int(choice.get("discontent", 0))
			hope_sum += int(choice.get("hope", 0))
		if not choices.is_empty() and (dis_sum > choices.size() or hope_sum < -choices.size()):
			bad.append("%s: mean discontent %+.2f, hope %+.2f" % [id, float(dis_sum) / choices.size(), float(hope_sum) / choices.size()])
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
			for key in cost if cost is Dictionary else {"(not an object)": 0}:
				if not STOCK.has(str(key)):
					bad.append("%s/%s: unknown cost %s" % [id, cid, key])
			var found = choice.get("artifacts", {})
			for key in found if found is Dictionary else {"(not an object)": 0}:
				if not Game.ARTIFACTS.has(str(key)):
					bad.append("%s/%s: unknown artifact %s" % [id, cid, key])
			var shifts = choice.get("standing", {})
			for fid in shifts if shifts is Dictionary else {"(not an object)": 0}:
				if not leaders.has(str(fid)):
					bad.append("%s/%s: standing names %s, not a faction in faction_leaders.json" % [id, cid, fid])
		for en in texts:
			if en.strip_edges() == "":
				bad.append("%s: empty text" % id)
				continue
			var ru := str(catalog.pool_ru.get(en, ""))
			if ru.strip_edges() == "":
				bad.append("%s: no Russian for \"%s\"" % [id, en])
			for dash in ["\u2014", "\u2013"]:
				if en.contains(dash) or ru.contains(dash):
					bad.append("%s: dash in \"%s\"" % [id, en])
	_expect(bad.is_empty() and events.size() == _pool_ids().size() and not events.is_empty(),
		"Pool events valid: %d events in the random pool, ids unique across files, %d choices each, mean discontent at most +1 and hope at least -1, known keys, every string has Russian, no dashes, who is a resident or a Coney cast name" % [events.size(), CHOICES],
		"pool events: " + "; ".join(bad))


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.pending = []
	game.audience = {}
	return game


## Each pool event is drawn only inside its weeks, by the same rule as data/events.json.
func _window() -> void:
	var bad: PackedStringArray = []
	var game := _game()
	for ev in _pool_events():
		var low := int(ev.get("min_week", 1))
		var high := int(ev.get("max_week", 99))
		for week in [low - 1, low, high, high + 1]:
			if week < 1 or week > 40:
				continue
			game.week = week
			var want: bool = week >= low and week <= high
			if game._event_ok(ev) != want:
				bad.append("%s week %d" % [ev.id, week])
		game.week = low
		if not game._event_pool(false).has(ev):
			bad.append("%s not in the pool at week %d" % [ev.id, low])
	_expect(bad.is_empty(), "Pool events join the random pool inside their weeks only", "pool windows: " + ", ".join(bad))


## Every choice pays its cost and applies hope, discontent, stock, artifacts and standing.
func _apply() -> void:
	var bad: PackedStringArray = []
	for ev in _pool_events():
		for choice in ev.choices:
			var game := _game()
			game.week = int(ev.get("min_week", 1))
			for key in STOCK:
				game.stock[key] = 200
			game.hope = 50
			game.discontent = 20
			var arts: Dictionary = game.artifacts.duplicate()
			game._init_standing()
			var stand: Dictionary = game.standing.duplicate()
			game._present_event(ev)
			if not game.apply({"kind": "event", "event_id": str(ev.id), "choice_id": str(choice.id)}):
				bad.append("%s/%s not applied" % [ev.id, choice.id])
				continue
			var found: Dictionary = choice.get("artifacts", {})
			for key in found:
				if int(game.artifacts[key]) - int(arts.get(key, 0)) != int(found[key]):
					bad.append("%s/%s artifact %s" % [ev.id, choice.id, key])
			var shifts: Dictionary = choice.get("standing", {})
			for fid in shifts:
				if int(game.standing.get(fid, 0)) == int(stand.get(fid, 0)):
					bad.append("%s/%s standing %s" % [ev.id, choice.id, fid])
			if not game.errors.is_empty():
				bad.append("%s/%s errors %s" % [ev.id, choice.id, str(game.errors)])
	_expect(bad.is_empty(), "Every pool choice applies (cost, artifacts, standing)", "pool choices: " + ", ".join(bad))
