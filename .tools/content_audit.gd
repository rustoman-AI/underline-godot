extends SceneTree

## Content audit and run-time estimate (docs/briefs/cursor_content_audit.txt). Read-only: it plays the existing
## bot on fresh games and forks saved states; nothing in data, balance, map or saves is written.
##   godot --headless --path . -s res://.tools/content_audit.gd [-- --seeds=30 --fork-seeds=10]
## Writes docs/audit/content_audit_<YYYYMMDD>.md.
##
## Decisions per week are counted from the journal rows of that week plus the events the bot left open, which
## the night resolves with the first available choice (a player would have to click those too):
##   event choices = journal "event" rows + night-resolved events; orders = "order" rows; laws = "law" and
##   "repeal" rows; audiences = audiences shown at dawn (the bots never answer, so a waiting leader is turned
##   away by silence the next dawn); building = "build", "dig", "upgrade", "demolish" rows.
## Events shown per week = first presentations in event_history (check events included; a white check shown
## again after its retry opens is not a new presentation).
## Leader forks: at each leader's first audience in a run the state is exported and played three ways from the
## same dawn (accept, refuse, silence), then the bot continues; snapshots right after the answer, and at the
## dawn 5 and 10 weeks later are compared with the silence branch.

const STYLES := ["careful", "expander", "follower"]
## Bot.audience_style values; sections 1 to 6 use "silence" runs only, section 7 compares all of them.
const AUDIENCE := ["silence", "accept_all", "refuse_all", "mixed"]
const WEEKS := 40
const FACTIONS := ["depot", "directorate", "synod", "exchange", "black_flag"]
## Seconds per decision (brief, section 3), and how much longer or shorter each player type takes.
const SECONDS := {"event": 25, "order": 12, "law": 30, "audience": 40, "dawn": 20, "build_week": 60}
const SPEED := {"careful": 1.5, "normal": 1.0, "fast": 0.6}

var seeds := 30
var fork_seeds := 10
## Appended to the report name ("e1" gives content_audit_<date>_e1.md) so a re-run never overwrites an earlier one.
var tag := ""
var md: PackedStringArray = []
## Numbers the closing list repeats from earlier sections.
var facts := {}


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--seeds="):
			seeds = int(str(arg).trim_prefix("--seeds="))
		if str(arg).begins_with("--fork-seeds="):
			fork_seeds = int(str(arg).trim_prefix("--fork-seeds="))
		if str(arg).begins_with("--tag="):
			tag = str(arg).trim_prefix("--tag=")
	var started := Time.get_ticks_msec()
	var runs: Array = []
	var all_runs: Array = []
	var forks: Array = []
	for answer in AUDIENCE:
		for style in STYLES:
			for s in range(1, seeds + 1):
				var run := _play(style, s, answer == "silence" and s <= fork_seeds, answer)
				all_runs.append(run)
				if answer == "silence":
					runs.append(run)
					forks.append_array(run.forks)
			print("AUDIT %s / %s done (%d s)" % [style, answer, (Time.get_ticks_msec() - started) / 1000])
	var date := Time.get_date_dict_from_system()
	var stamp := "%04d%02d%02d" % [date.year, date.month, date.day]
	_header(stamp)
	_counts()
	_repeat(runs)
	_runtime(runs)
	_dead_ends(runs)
	_leaders(runs, forks)
	_consequences(all_runs)
	_thin(runs, forks)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audit"))
	var path := "res://docs/audit/content_audit_%s%s.md" % [stamp, "_" + tag if tag != "" else ""]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	print("AUDIT wrote %s, %d runs, %d forks, %d s" % [path, all_runs.size(), forks.size(), (Time.get_ticks_msec() - started) / 1000])
	quit(0)


# ---------------------------------------------------------------- runs

## The sim unchanged, plus a record of what each leader consequence choice moved when it was applied.
class AuditGame extends Game:
	var lc_picks: Array = []

	func _apply_event(action: Dictionary) -> bool:
		var front: Dictionary = pending[0] if not pending.is_empty() else {}
		var watch: bool = front.has("needs") and str(front.id) == str(action.get("event_id", ""))
		var h := hope
		var d := discontent
		var was: Dictionary = standing.duplicate()
		var ok := super(action)
		if ok and watch:
			var fid := str(front.needs.leader)
			lc_picks.append({"event": str(front.id), "choice": str(action.get("choice_id", "")), "week": week,
				"hope": hope - h, "dis": discontent - d, "standing": int(standing.get(fid, 0)) - int(was.get(fid, 0))})
		return ok


func _new_game(run_seed: int) -> Game:
	var catalog := Catalog.new()
	catalog.load_all()
	var game := AuditGame.new()
	game.setup(catalog, run_seed, WEEKS)
	return game


func _new_bot(style: String, answer: String = "silence") -> Bot:
	var bot := Bot.new()
	bot.profile = style
	bot.audience_style = answer
	return bot


## One bot run with per-week counts; forks each leader's first audience when `fork` is set.
func _play(style: String, run_seed: int, fork: bool, answer: String = "silence") -> Dictionary:
	var game := _new_game(run_seed)
	game.audit = style != "follower"
	var bot := _new_bot(style, answer)
	var weeks: Array = []
	var picks: Array = []
	var shown_leaders := {}
	var forks: Array = []
	var guard := 0
	var hope_min := game.hope
	var dis_max := game.discontent
	while game.over == "" and guard < WEEKS + 2:
		guard += 1
		var w := game.week
		var fid := str(game.audience.get("faction", ""))
		if fid != "":
			shown_leaders[fid] = int(shown_leaders.get(fid, 0)) + 1
			if fork and not _forked(forks, fid):
				forks.append(_fork(style, run_seed, game, bot, fid))
		var row := _week(game, bot, picks)
		row["audience"] = 1 if fid != "" else 0
		weeks.append(row)
		game.end_week()
		hope_min = mini(hope_min, game.hope)
		dis_max = maxi(dis_max, game.discontent)
	var shown := {}
	for item in game.event_history:
		shown[str(item.id)] = int(shown.get(str(item.id), 0)) + 1
		var at := int(item.week) - 1
		if at >= 0 and at < weeks.size():
			weeks[at].events = int(weeks[at].events) + 1
	var deals := {}
	for row in game.journal:
		if str(row.get("kind", "")) == "audience" and str(row.get("result", "")) == "deal":
			deals[str(row.faction)] = true
	var lc_seen := {}
	for ev in game.catalog.events:
		if ev.has("needs") and game.events_seen.has(str(ev.id)):
			lc_seen[str(ev.id)] = int(game.events_seen[str(ev.id)])
	return {
		"style": style, "seed": run_seed, "over": game.over, "week": game.week, "weeks": weeks,
		"shown": shown, "picks": picks, "leaders": shown_leaders, "deals": deals, "forks": forks,
		"errors": game.errors.size(), "answer": answer, "answers": game.leader_answers.duplicate(true),
		"lc_seen": lc_seen, "lc_picks": game.lc_picks.duplicate(true), "hope_min": hope_min, "dis_max": dis_max,
		"hope_end": game.hope, "dis_end": game.discontent,
	}


func _forked(forks: Array, fid: String) -> bool:
	for item in forks:
		if str(item.faction) == fid:
			return true
	return false


## Plays one week with the bot and returns its counts; `picks` collects [event, choice, how].
func _week(game: Game, bot: Bot, picks: Array) -> Dictionary:
	var w := game.week
	bot._act(game)
	var row := {"week": w, "events": 0, "event": 0, "auto": 0, "order": 0, "law": 0, "audience": 0, "build": 0}
	for entry in game.journal:
		if int(entry.get("week", 0)) != w:
			continue
		match str(entry.get("kind", "")):
			"event":
				row.event += 1
				picks.append([str(entry.event_id), str(entry.choice_id), "bot"])
			"order":
				row.order += 1
			"law", "repeal":
				row.law += 1
			"build", "dig", "upgrade", "demolish":
				row.build += 1
	for ev in game.pending:
		for c in ev.choices:
			if game.choice_locked(c) or not game.choice_offered(c) or not game._afford(c.get("cost", {})):
				continue
			row.auto += 1
			picks.append([str(ev.id), str(c.id), "night"])
			break
	return row


# ---------------------------------------------------------------- leader forks

func _fork(style: String, run_seed: int, game: Game, bot: Bot, fid: String) -> Dictionary:
	var state := game.export_state()
	state["schema"] = Game.SAVE_SCHEMA
	var w := game.week
	var out := {"style": style, "seed": run_seed, "faction": fid, "week": w, "branches": {}}
	for policy in ["silence", "accept", "refuse"]:
		var g := _new_game(run_seed)
		if not g.import_state(state.duplicate(true)):
			out.branches[policy] = {"error": g.load_error}
			continue
		var b := _new_bot(style)
		for key in ["_did_aid", "_did_talk", "_did_ration"]:
			b.set(key, bot.get(key))
		var note := ""
		if policy != "silence":
			var reason := g.audience_reason()
			if not g.apply({"kind": "audience", "accept": policy == "accept"}):
				note = "blocked: " + reason
		var snaps := {"t0": _snap(g, w)}
		var guard := 0
		while g.over == "" and g.week < w + 10 and guard < 12:
			guard += 1
			_week(g, b, [])
			g.end_week()
			if g.week == w + 5 and not snaps.has("t5"):
				snaps["t5"] = _snap(g, w)
		if not snaps.has("t5"):
			snaps["t5"] = _snap(g, w)
		snaps["t10"] = _snap(g, w)
		out.branches[policy] = {"note": note, "snaps": snaps}
	return out


func _snap(g: Game, since: int) -> Dictionary:
	var events := {}
	for item in g.event_history:
		if int(item.week) >= since:
			events[str(item.id)] = true
	var journal := {}
	for row in g.journal:
		if int(row.get("week", 0)) < since:
			continue
		var key := str(row.get("kind", ""))
		if row.has("result"):
			key += ":" + str(row.result)
		journal[key] = int(journal.get(key, 0)) + 1
	var laws := {}
	for law in g.laws_on:
		if bool(g.laws_on[law]):
			laws[str(law)] = true
	return {
		"week": g.week, "over": g.over, "flags": g.flags.keys(), "standing": g.standing.duplicate(true),
		"laws": laws.keys(), "pop": g.residents.size(), "hope": g.hope, "dis": g.discontent,
		"food": int(g.stock.food), "events": events.keys(), "journal": journal,
		"memory": g.standing_memory.duplicate(true),
	}


## What differs between a branch and the silence branch at the same horizon.
func _diff(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {"flags": [], "standing": {}, "laws": [], "events_only": [], "events_missing": [], "journal": {}}
	for f in a.flags:
		if not b.flags.has(f):
			out.flags.append(str(f))
	for fid in a.standing:
		var d := int(a.standing[fid]) - int(b.standing.get(fid, 0))
		if d != 0:
			out.standing[str(fid)] = d
	for law in a.laws:
		if not b.laws.has(law):
			out.laws.append(str(law))
	for id in a.events:
		if not b.events.has(id):
			out.events_only.append(str(id))
	for id in b.events:
		if not a.events.has(id):
			out.events_missing.append(str(id))
	var keys := {}
	for k in a.journal:
		keys[k] = true
	for k in b.journal:
		keys[k] = true
	for k in keys:
		var d := int(a.journal.get(k, 0)) - int(b.journal.get(k, 0))
		if d != 0:
			out.journal[str(k)] = d
	out["pop"] = int(a.pop) - int(b.pop)
	out["hope"] = int(a.hope) - int(b.hope)
	out["dis"] = int(a.dis) - int(b.dis)
	out["food"] = int(a.food) - int(b.food)
	return out


# ---------------------------------------------------------------- report sections

func _header(stamp: String) -> void:
	md.append("# Content audit %s" % stamp)
	md.append("")
	md.append("Measured with `.tools/content_audit.gd` on the current data and sim, %d seeds for each of the bot styles %s and each audience style %s (%d runs of %d weeks), leader forks on seeds 1 to %d. Facts only, no proposals. The bots are not players: they decide instantly and use the same rules each week. Sections 1 to 6 use the silence audience style (the bot never answers, so every leader is turned away by silence, as before audience styles existed): %d runs. Section 7 compares the audience styles." % [seeds, ", ".join(STYLES), ", ".join(AUDIENCE), seeds * STYLES.size() * AUDIENCE.size(), WEEKS, fork_seeds, seeds * STYLES.size()])
	md.append("")


func _counts() -> void:
	var game := _new_game(1)
	var cat: Catalog = game.catalog
	md.append("## 1. Counts")
	md.append("")
	var major := 0
	var minor := 0
	var chain := 0
	var check := 0
	var follow := 0
	var cooldown := 0
	var memory := 0
	var choices: Array = []
	for ev in cat.events:
		var n: int = ev.get("choices", []).size()
		choices.append(n)
		if bool(ev.get("check_only", false)):
			check += 1
		elif bool(ev.get("chain_only", false)):
			chain += 1
		elif bool(ev.get("major", false)):
			major += 1
		else:
			minor += 1
		if str(ev.get("follow", "")) != "":
			follow += 1
		if ev.has("cooldown"):
			cooldown += 1
		if ev.get("by", {}) is Dictionary and not ev.get("by", {}).is_empty():
			memory += 1
	choices.sort()
	var total := 0
	for n in choices:
		total += int(n)
	var rooms := 0
	var buildable := 0
	var tiers := 0
	for id in cat.rooms:
		rooms += 1
		if bool(cat.rooms[id].get("buildable", false)):
			buildable += 1
		tiers += cat.rooms[id].get("upgrades", []).size()
	var repealable := 0
	for id in cat.laws:
		if bool(cat.laws[id].get("repealable", false)):
			repealable += 1
	var seasons: PackedStringArray = []
	for s in cat.balance.get("seasons", []):
		seasons.append("%s (week %d, %d weeks)" % [str(s.id), int(s.week), int(s.weeks)])
	var code := FileAccess.get_file_as_string("res://sim/game.gd")
	var artifact_sources: PackedStringArray = []
	for key in game.artifacts:
		if code.contains("artifacts.%s = int(artifacts.%s) +" % [key, key]):
			artifact_sources.append(str(key))
	var bunkers: PackedStringArray = []
	var owners := {}
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		owners[str(st.owner)] = int(owners.get(str(st.owner), 0)) + 1
		if str(st.get("bunker", "")) != "" or str(st.owner) == "bunker":
			bunkers.append("%s (owner %s%s)" % [str(sid), str(st.owner), ", " + str(st.bunker) if str(st.get("bunker", "")) != "" else ""])
	var endings: PackedStringArray = []
	var rx := RegEx.new()
	rx.compile("over = \"([a-z]+)\"")
	for m in rx.search_all(code):
		if m.get_string(1) != "error" and not endings.has(m.get_string(1)):
			endings.append(m.get_string(1))
	var coney: Array = cat.coney.get("characters", [])
	var backstories = JSON.parse_string(FileAccess.get_file_as_string("res://data/backstories.json"))
	var stories: int = backstories.get("people", []).size() if backstories is Dictionary and backstories.get("people", []) is Array else (backstories.get("people", {}).size() if backstories is Dictionary else 0)
	var voiced := _voiced()
	facts["events"] = cat.events.size()
	facts["endings"] = endings
	facts["stories"] = stories
	facts["residents"] = cat.residents.size()
	var no_source: PackedStringArray = []
	for key in game.artifacts:
		if not artifact_sources.has(str(key)):
			no_source.append(str(key))
	facts["no_source"] = no_source
	var deals := 0
	for row in cat.leaders.get("factions", []):
		if not row.get("dirty_deal", {}).is_empty():
			deals += 1
	var owner_bits: PackedStringArray = []
	for o in owners:
		owner_bits.append("%s %d" % [o, owners[o]])
	md.append("| Item | Count | Detail |")
	md.append("| --- | --- | --- |")
	md.append("| Events, all | %d | %d major, %d minor, %d check, %d follow-up only (chain_only) |" % [cat.events.size(), major, minor, check, chain])
	md.append("| Events with a follow-up | %d | follow-up text varies by the earlier choice in %d |" % [follow, memory])
	md.append("| Events with their own cooldown | %d | global cooldown %d weeks, minor events capped at %d per run (balance.json) |" % [cooldown, int(cat.balance.get("event_cooldown", 8)), int(cat.balance.get("event_minor_cap", 2))])
	md.append("| Choices per event | %d / %.1f / %d | min / mean / max over all %d events |" % [int(choices[0]), float(total) / choices.size(), int(choices[-1]), choices.size()])
	md.append("| Laws | %d | %d repealable |" % [cat.laws.size(), repealable])
	md.append("| Rooms | %d | %d buildable, %d upgrade tiers in all |" % [rooms, buildable, tiers])
	md.append("| Seasons | %d | %s |" % [seasons.size(), ", ".join(seasons)])
	md.append("| Artifact kinds | %d | %s declared; with a source in the sim: %s |" % [game.artifacts.size(), ", ".join(PackedStringArray(game.artifacts.keys())), ", ".join(artifact_sources) if not artifact_sources.is_empty() else "none"])
	md.append("| Bunkers | %d | %s |" % [bunkers.size(), ", ".join(bunkers)])
	md.append("| Run endings (game over states) | %d | %s; each has one end card line, there is no epilogue |" % [endings.size(), ", ".join(endings)])
	md.append("| Named residents | %d | residents.json; %d in characters_coney.json |" % [cat.residents.size(), coney.size()])
	md.append("| Backstories | %d | backstories.json |" % stories)
	md.append("| Voiced lines (rows) | %d | %s |" % [voiced.rows, voiced.detail])
	md.append("| Voiced audio files | %d | EN %d, RU %d |" % [voiced.en + voiced.ru, voiced.en, voiced.ru])
	md.append("| Stations | %d | %d on the map pins (stations.json); owners at start: %s |" % [game.stations.size(), cat.stations.size(), ", ".join(owner_bits)])
	md.append("| Tunnels | %d | %d in tunnels.json |" % [game.tunnels.size(), cat.tunnels.size()])
	md.append("| Leaders / audience deals | %d / %d | one dirty deal per leader |" % [cat.leaders.get("factions", []).size(), deals])
	md.append("")


func _voiced() -> Dictionary:
	Voice.load_all()
	var by_type := {}
	var en := 0
	var ru := 0
	for id in Voice.lines:
		var row: Dictionary = Voice.lines[id]
		var type := str(row.get("type", "?"))
		by_type[type] = int(by_type.get(type, 0)) + 1
		for lang in ["en", "ru"]:
			var path := str(row.get("audio_" + lang, ""))
			if path != "" and ResourceLoader.exists(path):
				if lang == "en":
					en += 1
				else:
					ru += 1
	var leader := 0
	for fid in FACTIONS:
		for key in Voice.LEADER_KEYS:
			leader += 1
			for lang in ["en", "ru"]:
				if ResourceLoader.exists(Voice.leader_file(fid, key, lang)):
					if lang == "en":
						en += 1
					else:
						ru += 1
	var bits: PackedStringArray = []
	for t in by_type:
		bits.append("%s %d" % [t, by_type[t]])
	bits.append("leader %d" % leader)
	return {"rows": Voice.lines.size() + leader, "detail": ", ".join(bits), "en": en, "ru": ru}


func _repeat(runs: Array) -> void:
	md.append("## 2. Forty-week repeat rate")
	md.append("")
	md.append("Per run, then mean / min / max over the %d seeds of each style. Decisions = event choices (bot and night-resolved) + orders + laws + audiences shown." % seeds)
	md.append("")
	md.append("| Style | Events shown per week | Distinct events | Events shown 2+ times | Longest gap without an event (weeks) | Weeks with zero decisions | Decisions per week |")
	md.append("| --- | --- | --- | --- | --- | --- | --- |")
	for style in STYLES:
		var cols := {"epw": [], "distinct": [], "twice": [], "gap": [], "zero": [], "dpw": []}
		for run in runs:
			if run.style != style:
				continue
			var m := _run_metrics(run)
			for k in cols:
				cols[k].append(m[k])
		md.append("| %s | %s | %s | %s | %s | %s | %s |" % [style, _mmm(cols.epw, 2), _mmm(cols.distinct, 0), _mmm(cols.twice, 0), _mmm(cols.gap, 0), _mmm(cols.zero, 0), _mmm(cols.dpw, 2)])
	md.append("")
	md.append("Decisions per week by type (mean over all runs and weeks):")
	md.append("")
	md.append("| Style | Event choices (bot) | Event choices (night) | Orders | Laws | Audiences shown | Build / dig / upgrade |")
	md.append("| --- | --- | --- | --- | --- | --- | --- |")
	for style in STYLES:
		var sums := {"event": 0.0, "auto": 0.0, "order": 0.0, "law": 0.0, "audience": 0.0, "build": 0.0}
		var n := 0
		for run in runs:
			if run.style != style:
				continue
			for w in run.weeks:
				n += 1
				for k in sums:
					sums[k] += float(w[k])
		md.append("| %s | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [style, sums.event / n, sums.auto / n, sums.order / n, sums.law / n, sums.audience / n, sums.build / n])
	md.append("")
	var per_week := {}
	for run in runs:
		for w in run.weeks:
			var at := int(w.week)
			if not per_week.has(at):
				per_week[at] = {"d": 0.0, "e": 0.0, "n": 0}
			per_week[at].d += float(_decisions(w))
			per_week[at].e += float(w.events)
			per_week[at].n += 1
	var rows: Array = []
	for at in per_week:
		rows.append({"week": at, "d": per_week[at].d / per_week[at].n, "e": per_week[at].e / per_week[at].n, "n": per_week[at].n})
	rows.sort_custom(func(a, b): return a.d < b.d or (a.d == b.d and a.week < b.week))
	md.append("Emptiest and busiest week numbers across all %d runs (mean decisions and events shown in that week):" % runs.size())
	md.append("")
	md.append("| Emptiest week | Decisions | Events | | Busiest week | Decisions | Events |")
	md.append("| --- | --- | --- | --- | --- | --- | --- |")
	for i in 5:
		var lo: Dictionary = rows[i]
		var hi: Dictionary = rows[rows.size() - 1 - i]
		md.append("| %d | %.2f | %.2f | | %d | %.2f | %.2f |" % [lo.week, lo.d, lo.e, hi.week, hi.d, hi.e])
	md.append("")


func _decisions(w: Dictionary) -> int:
	return int(w.event) + int(w.auto) + int(w.order) + int(w.law) + int(w.audience)


func _run_metrics(run: Dictionary) -> Dictionary:
	var weeks: Array = run.weeks
	var events := 0
	var zero := 0
	var gap := 0
	var longest := 0
	var dec := 0
	for w in weeks:
		events += int(w.events)
		dec += _decisions(w)
		if _decisions(w) == 0:
			zero += 1
		if int(w.events) == 0:
			gap += 1
			longest = maxi(longest, gap)
		else:
			gap = 0
	var twice := 0
	for id in run.shown:
		if int(run.shown[id]) >= 2:
			twice += 1
	var n := maxi(weeks.size(), 1)
	return {"epw": float(events) / n, "distinct": run.shown.size(), "twice": twice, "gap": longest, "zero": zero, "dpw": float(dec) / n}


func _mmm(values: Array, places: int) -> String:
	if values.is_empty():
		return "-"
	var lo := INF
	var hi := -INF
	var sum := 0.0
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
		sum += float(v)
	var fmt := "%." + str(places) + "f"
	return (fmt + " / " + fmt + " / " + fmt) % [sum / values.size(), lo, hi]


func _runtime(runs: Array) -> void:
	md.append("## 3. Run-time estimate")
	md.append("")
	md.append("Assumptions (brief): event choice %d s, order %d s, law %d s, audience %d s, reading the dawn report %d s per week, building and assigning %d s per week. A normal new player takes those times; careful x%.1f, fast x%.1f. Decision counts are the bots' (section 2), audiences counted when shown. The bots use fewer order seats than a player may: the second line puts every order seat to use (%d per week)." % [
		SECONDS.event, SECONDS.order, SECONDS.law, SECONDS.audience, SECONDS.dawn, SECONDS.build_week, SPEED.careful, SPEED.fast, 3])
	md.append("")
	md.append("| Counts from | Player | Minutes per week (mean, min..max run) | 40 weeks, hours (mean, min..max run) |")
	md.append("| --- | --- | --- | --- |")
	for basis in ["bots", "all seats"]:
		for player in ["careful", "normal", "fast"]:
			var per_run: Array = []
			for run in runs:
				var secs := 0.0
				for w in run.weeks:
					var orders := 3 if basis == "all seats" else int(w.order)
					secs += (int(w.event) + int(w.auto)) * SECONDS.event + orders * SECONDS.order + int(w.law) * SECONDS.law
					secs += int(w.audience) * SECONDS.audience + SECONDS.dawn + SECONDS.build_week
				secs *= float(SPEED[player])
				per_run.append({"week": secs / 60.0 / maxf(run.weeks.size(), 1), "total": secs / 3600.0 * WEEKS / maxf(run.weeks.size(), 1)})
			var wk: Array = per_run.map(func(r): return r.week)
			var tot: Array = per_run.map(func(r): return r.total)
			md.append("| %s | %s | %s | %s |" % [basis, player, _mean_range(wk, 1), _mean_range(tot, 2)])
	md.append("")
	md.append("Runs that ended before week 40 are scaled to 40 weeks at their own weekly rate. The fixed part (dawn report and building) is %d s, that is %.1f minutes a week and %.1f hours over 40 weeks for a normal player." % [SECONDS.dawn + SECONDS.build_week, (SECONDS.dawn + SECONDS.build_week) / 60.0, (SECONDS.dawn + SECONDS.build_week) * WEEKS / 3600.0])
	md.append("")


func _mean_range(values: Array, places: int) -> String:
	var lo := INF
	var hi := -INF
	var sum := 0.0
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
		sum += float(v)
	var fmt := "%." + str(places) + "f"
	return (fmt + " (" + fmt + ".." + fmt + ")") % [sum / maxf(values.size(), 1), lo, hi]


func _dead_ends(runs: Array) -> void:
	md.append("## 4. Dead ends")
	md.append("")
	md.append("Endings reached:")
	md.append("")
	md.append("| Style | Ending (week) counts | Runs with sim errors |")
	md.append("| --- | --- | --- |")
	for style in STYLES:
		var ends := {}
		var errs := 0
		for run in runs:
			if run.style != style:
				continue
			var key := str(run.over) if str(run.over) == "time" else "%s (week %d)" % [run.over, int(run.week)]
			ends[key] = int(ends.get(key, 0)) + 1
			if int(run.errors) > 0:
				errs += 1
		var bits: PackedStringArray = []
		for k in ends:
			bits.append("%s x%d" % [k, ends[k]])
		md.append("| %s | %s | %d |" % [style, ", ".join(bits), errs])
	md.append("")
	md.append("Per seed (careful / expander / follower):")
	md.append("")
	md.append("| Seed | careful | expander | follower |")
	md.append("| --- | --- | --- | --- |")
	for s in range(1, seeds + 1):
		var cells: PackedStringArray = []
		for style in STYLES:
			for run in runs:
				if run.style == style and int(run.seed) == s:
					cells.append(str(run.over) if str(run.over) == "time" else "%s w%d" % [run.over, int(run.week)])
		md.append("| %d | %s |" % [s, " | ".join(cells)])
	md.append("")
	var game := _new_game(1)
	var fired := {}
	var picked := {}
	var by_style := {}
	for run in runs:
		for id in run.shown:
			fired[id] = int(fired.get(id, 0)) + int(run.shown[id])
		for p in run.picks:
			var key := "%s/%s" % [p[0], p[1]]
			picked[key] = int(picked.get(key, 0)) + 1
			if not by_style.has(key):
				by_style[key] = {}
			by_style[key][str(run.style) + ("" if p[2] == "bot" else " (night)")] = true
	var never: PackedStringArray = []
	var never_choice: PackedStringArray = []
	var only_night: PackedStringArray = []
	var rows: Array = []
	for ev in game.catalog.events:
		var id := str(ev.id)
		var n := int(fired.get(id, 0))
		rows.append([id, n])
		if n == 0:
			never.append(id)
			continue
		for c in ev.choices:
			var key := "%s/%s" % [id, str(c.id)]
			if not picked.has(key):
				never_choice.append(key)
			else:
				var bot_pick := false
				for s in by_style[key]:
					if not str(s).ends_with("(night)"):
						bot_pick = true
				if not bot_pick:
					only_night.append(key)
	md.append("Events that never fired in any run (%d of %d): %s" % [never.size(), game.catalog.events.size(), ", ".join(never) if not never.is_empty() else "none"])
	md.append("")
	var known := {}
	for ev in game.catalog.events:
		known[str(ev.id)] = true
	var extra: PackedStringArray = []
	for id in fired:
		if not known.has(id):
			extra.append("%s %d" % [id, fired[id]])
	if not extra.is_empty():
		md.append("Upkeep events built at run time in `sim/game.gd`, not in events.json (presentations): %s" % ", ".join(extra))
		md.append("")
	var choice_total := 0
	for ev in game.catalog.events:
		if fired.has(str(ev.id)):
			choice_total += ev.choices.size()
	facts["upkeep"] = extra.size()
	facts["fired"] = fired
	facts["never_choice"] = never_choice.size()
	facts["choices"] = choice_total
	md.append("Choices never picked in events that did fire (%d): %s" % [never_choice.size(), ", ".join(never_choice) if not never_choice.is_empty() else "none"])
	md.append("")
	md.append("Choices only ever taken by the night resolve, never by a bot (%d): %s" % [only_night.size(), ", ".join(only_night) if not only_night.is_empty() else "none"])
	md.append("")
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	md.append("Presentations per event over all %d runs (most to least):" % runs.size())
	md.append("")
	var line: PackedStringArray = []
	for r in rows:
		line.append("%s %d" % [r[0], r[1]])
	md.append(", ".join(line))
	md.append("")


func _leaders(runs: Array, forks: Array) -> void:
	md.append("## 5. Leader deals")
	md.append("")
	md.append("Audiences shown per run (mean / min / max over seeds) and deals accepted by the bot:")
	md.append("")
	md.append("| Leader | careful shown | careful accepted | expander shown | expander accepted | follower shown | follower accepted |")
	md.append("| --- | --- | --- | --- | --- | --- | --- |")
	for fid in FACTIONS:
		var cells: PackedStringArray = [fid]
		for style in STYLES:
			var shown: Array = []
			var took := 0
			var n := 0
			for run in runs:
				if run.style != style:
					continue
				n += 1
				shown.append(int(run.leaders.get(fid, 0)))
				if run.deals.has(fid):
					took += 1
			cells.append(_mmm(shown, 1))
			cells.append("%d of %d" % [took, n])
		md.append("| %s |" % " | ".join(cells))
	md.append("")
	md.append("These runs use the silence audience style: a leader left waiting is turned away by silence at the next dawn, which the game records as a refusal with the deed \"silence\" and which the leader consequence events treat as refused. The forks below answer for the bot.")
	md.append("")
	md.append("Forks: %d (seeds 1 to %d, all styles, first audience of each leader). Each row compares the accept or refuse branch with the silence branch at the same week: right after the answer (t0), 5 weeks later and 10 weeks later. Counts are forks where the item differs." % [forks.size(), fork_seeds])
	md.append("")
	md.append("| Leader | Branch | Forks | Blocked | When | Flag set | Own standing (mean diff) | Other standings moved | Law | Pop (mean diff) | Hope (mean diff) | Events differ | Journal rows differ |")
	md.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	var differing := {}
	for fid in FACTIONS:
		for policy in ["accept", "refuse"]:
			var set: Array = forks.filter(func(f): return str(f.faction) == fid and f.branches.has(policy) and f.branches.has("silence") and not f.branches[policy].has("error"))
			if set.is_empty():
				md.append("| %s | %s | 0 | | | | | | | | | | |" % [fid, policy])
				continue
			var blocked := set.filter(func(f): return str(f.branches[policy].note) != "").size()
			for horizon in ["t0", "t5", "t10"]:
				var flag := 0
				var own := 0.0
				var others := 0
				var law := 0
				var pop := 0.0
				var hope := 0.0
				var ev := 0
				var jr := 0
				for f in set:
					var d := _diff(f.branches[policy].snaps[horizon], f.branches.silence.snaps[horizon])
					if not d.flags.is_empty():
						flag += 1
					own += float(d.standing.get(fid, 0))
					for o in d.standing:
						if str(o) != fid:
							others += 1
							break
					if not d.laws.is_empty():
						law += 1
					pop += d.pop
					hope += d.hope
					if not d.events_only.is_empty() or not d.events_missing.is_empty():
						ev += 1
					if not d.journal.is_empty():
						jr += 1
					if horizon == "t10":
						var key := "%s|%s" % [fid, policy]
						if not differing.has(key):
							differing[key] = {"journal": {}, "events": 0}
						differing[key].events += d.events_only.size() + d.events_missing.size()
						for k in d.journal:
							differing[key].journal[k] = int(differing[key].journal.get(k, 0)) + 1
				var n := float(set.size())
				md.append("| %s | %s | %d | %d | %s | %d | %+.1f | %d | %d | %+.2f | %+.1f | %d | %d |" % [
					fid if horizon == "t0" else "", policy if horizon == "t0" else "", set.size() if horizon == "t0" else 0,
					blocked if horizon == "t0" else 0, horizon, flag, own / n, others, law, pop / n, hope / n, ev, jr])
	md.append("")
	md.append("Journal rows that differ from the silence branch by week +10 (row kind:result, number of forks), and event ids shown in one branch only (mean per fork). The sim draws all events from one random stream, so any change of state shifts later draws; the leader consequence events (section 7) read the first answer, not the deal flags:")
	md.append("")
	md.append("| Leader | Branch | Journal rows that differ | Event ids in one branch only (mean per fork) |")
	md.append("| --- | --- | --- | --- |")
	for fid in FACTIONS:
		for policy in ["accept", "refuse"]:
			var key := "%s|%s" % [fid, policy]
			if not differing.has(key):
				continue
			var n := forks.filter(func(f): return str(f.faction) == fid).size()
			var bits: PackedStringArray = []
			var kinds: Array = differing[key].journal.keys()
			kinds.sort()
			for k in kinds:
				bits.append("%s (%d)" % [k, differing[key].journal[k]])
			md.append("| %s | %s | %s | %.1f |" % [fid, policy, ", ".join(bits), float(differing[key].events) / maxf(n, 1)])
	md.append("")
	md.append("Where each deal flag is read after it is set (`flags.has`, `flags.get`, `flags[...]` or `flags.<name>` in `sim/` and `ui/`, and the flag name in any event or data condition):")
	md.append("")
	md.append("| Leader | Deal | Flag | Read in |")
	md.append("| --- | --- | --- | --- |")
	var cat := Catalog.new()
	cat.load_all()
	for row in cat.leaders.get("factions", []):
		var deal: Dictionary = row.get("dirty_deal", {})
		var flag := str(deal.get("flag", deal.get("id", "")))
		md.append("| %s | %s | %s | %s |" % [str(row.id), str(deal.get("id", "")), flag, _readers(flag)])
	md.append("")
	md.append("Readers of the other state a deal changes, from `sim/game.gd`: `audience_deals` stops that leader coming back (`audience_eligible`); `leader_answers` (first answer and its week) opens that leader's consequence event; `standing` feeds the leader's band, which picks the leader's lines, the audience cooldown and the lantern toll; `standing_memory` is shown on the leader card. Outside the audience code, the consequence events and their tests, nothing in `sim/` reads standing (no map, order or trade rule).")
	md.append("")
	var sanity := 0
	for run in runs:
		for f in run.forks:
			if not f.branches.has("silence") or f.branches.silence.has("error"):
				continue
			sanity += 1
	md.append("Silence branches replayed from an exported state: %d; branches with a load error: %d." % [sanity, _load_errors(forks)])
	md.append("")


## Leader consequence events (data/events_leaders.json) under each audience style.
func _consequences(all_runs: Array) -> void:
	var cat: Catalog = _new_game(1).catalog
	var events: Array = cat.events.filter(func(ev): return ev.has("needs"))
	md.append("## 7. Leader consequences by audience style")
	md.append("")
	md.append("Audience styles (`Bot.audience_style`): silence leaves every leader waiting; accept_all takes every deal it can pay for (a deal it cannot pay for is left waiting, which counts as silence); refuse_all turns everyone away; mixed accepts the Synod and the Exchange and refuses the others. Event choices are the bot style's own (careful, expander, follower), unchanged. %d runs per audience style." % (seeds * STYLES.size()))
	md.append("")
	md.append("First answer per leader (`leader_answers`), runs out of %d per audience style. \"none\" = the leader never came or was never answered before the run ended:" % (seeds * STYLES.size()))
	md.append("")
	md.append("| Leader | Audience style | accepted | refused | silence | none | Mean answer week |")
	md.append("| --- | --- | --- | --- | --- | --- | --- |")
	for fid in FACTIONS:
		for answer in AUDIENCE:
			var counts := {"accepted": 0, "refused": 0, "silence": 0, "none": 0}
			var weeks := 0.0
			var n := 0
			for run in all_runs:
				if str(run.answer) != answer:
					continue
				var row: Dictionary = run.answers.get(fid, {})
				if row.is_empty():
					counts.none += 1
					continue
				counts[str(row.answer)] += 1
				weeks += float(row.week)
				n += 1
			md.append("| %s | %s | %d | %d | %d | %d | %s |" % [fid if answer == AUDIENCE[0] else "", answer, counts.accepted, counts.refused, counts.silence, counts.none, "%.1f" % (weeks / n) if n > 0 else "-"])
	md.append("")
	md.append("How often each consequence fires. Due = runs where the matching answer (refused also matches silence) was given in week %d or earlier, the brief's \"at least 3 weeks before week 40\"; cut short = due runs that ended before the window opened. Target: fired in at least 95 percent of due runs. Fired late = shown with fewer weeks left in its window than it had when it opened (held by a major event)." % (WEEKS - 3))
	md.append("")
	md.append("| Event | Needs | Due | Cut short | Fired | Fired of due | Weeks after the answer (mean) | Held at least one dawn |")
	md.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
	var worst := 1.0
	var all_due := 0
	var all_fired := 0
	for ev in events:
		var id := str(ev.id)
		var fid := str(ev.needs.leader)
		var lo := int(ev.needs.after_weeks[0])
		var due := 0
		var cut := 0
		var fired := 0
		var gap := 0.0
		var held := 0
		for run in all_runs:
			var row: Dictionary = run.answers.get(fid, {})
			if row.is_empty() or not Game.answer_matches(str(ev.needs.answer), str(row.answer)) or int(row.week) > WEEKS - 3:
				continue
			due += 1
			if run.lc_seen.has(id):
				fired += 1
				var since := int(run.lc_seen[id]) - int(row.week)
				gap += since
				if since > lo:
					held += 1
			elif int(run.week) < int(row.week) + lo or str(run.over) != "time":
				cut += 1
		var share := float(fired) / float(maxi(due, 1))
		if due > 0:
			worst = minf(worst, share)
		all_due += due
		all_fired += fired
		md.append("| %s | %s %s %d..%d | %d | %d | %d | %.0f%% | %s | %d |" % [id, fid, str(ev.needs.answer), lo, int(ev.needs.after_weeks[1]), due, cut, fired, share * 100.0, "%.1f" % (gap / fired) if fired > 0 else "-", held])
	md.append("")
	md.append("All consequences: fired in %d of %d due runs (%.1f%%); lowest single event %.0f%%." % [all_fired, all_due, 100.0 * all_fired / maxf(all_due, 1), worst * 100.0])
	md.append("")
	md.append("What each choice moved when the bot (or the night resolve) took it, mean over all picks in all %d runs. Standing is the event's own leader; changes are after clamping:" % all_runs.size())
	md.append("")
	md.append("| Event | Choice | Picks | Hope | Discontent | Standing |")
	md.append("| --- | --- | --- | --- | --- | --- |")
	for ev in events:
		for choice in ev.choices:
			var n := 0
			var h := 0.0
			var d := 0.0
			var s := 0.0
			for run in all_runs:
				for pick in run.lc_picks:
					if str(pick.event) == str(ev.id) and str(pick.choice) == str(choice.id):
						n += 1
						h += float(pick.hope)
						d += float(pick.dis)
						s += float(pick.standing)
			var f := maxf(n, 1)
			md.append("| %s | %s | %d | %s | %s | %s |" % [str(ev.id) if choice == ev.choices[0] else "", str(choice.id), n,
				"%+.2f" % (h / f) if n > 0 else "-", "%+.2f" % (d / f) if n > 0 else "-", "%+.2f" % (s / f) if n > 0 else "-"])
	md.append("")
	md.append("Endings and meters per bot style and audience style (report only, nothing tuned). Hope min and discontent max are the run's extremes at the end of each week, mean over seeds:")
	md.append("")
	md.append("| Bot style | Audience style | Endings | Collapse, hope or revolt endings | Hope min (mean) | Discontent max (mean, worst) |")
	md.append("| --- | --- | --- | --- | --- | --- |")
	for style in STYLES:
		for answer in AUDIENCE:
			var ends := {}
			var bad := 0
			var hmin := 0.0
			var dmax := 0.0
			var dworst := 0
			var n := 0
			for run in all_runs:
				if str(run.style) != style or str(run.answer) != answer:
					continue
				n += 1
				var key := str(run.over) if str(run.over) == "time" else "%s (week %d)" % [run.over, int(run.week)]
				ends[key] = int(ends.get(key, 0)) + 1
				if str(run.over) != "time":
					bad += 1
				hmin += float(run.hope_min)
				dmax += float(run.dis_max)
				dworst = maxi(dworst, int(run.dis_max))
			var bits: PackedStringArray = []
			for k in ends:
				bits.append("%s x%d" % [k, ends[k]])
			md.append("| %s | %s | %s | %d | %.1f | %.1f, %d |" % [style if answer == AUDIENCE[0] else "", answer, ", ".join(bits), bad, hmin / maxf(n, 1), dmax / maxf(n, 1), dworst])
	md.append("")
	facts["lc_fired"] = [all_fired, all_due, worst]


func _load_errors(forks: Array) -> int:
	var n := 0
	for f in forks:
		for p in f.branches:
			if f.branches[p].has("error"):
				n += 1
	return n


func _readers(flag: String) -> String:
	var hits: PackedStringArray = []
	for dir in ["res://sim", "res://ui", "res://data", "res://data/vo"]:
		for file in DirAccess.get_files_at(dir):
			if not (str(file).ends_with(".gd") or str(file).ends_with(".json")):
				continue
			if str(file) == "faction_leaders.json":
				continue
			var text := FileAccess.get_file_as_string(dir.path_join(str(file)))
			var at: PackedStringArray = []
			var lines := text.split("\n")
			var code := str(file).ends_with(".gd")
			for i in lines.size():
				var l := lines[i]
				if code and (l.contains("flags.has(\"%s\")" % flag) or l.contains("flags.get(\"%s\"" % flag) or l.contains("flags[\"%s\"]" % flag) or l.contains("flags.%s" % flag)):
					at.append(str(i + 1))
				elif not code and l.contains("\"%s\"" % flag) and (l.contains("flag") or l.contains("requires")):
					at.append(str(i + 1))
			if not at.is_empty():
				hits.append("%s lines %s" % [dir.path_join(str(file)).trim_prefix("res://"), ", ".join(at)])
	return ", ".join(hits) if not hits.is_empty() else "nowhere"


func _thin(runs: Array, forks: Array) -> void:
	md.append("## 6. What looks thin (facts from the tables above)")
	md.append("")
	var all_m: Array = runs.map(func(r): return _run_metrics(r))
	var twice := 0.0
	var distinct := 0.0
	var zero := 0.0
	var gap := 0
	for m in all_m:
		twice += m.twice
		distinct += m.distinct
		zero += m.zero
		gap = maxi(gap, int(m.gap))
	var n := float(all_m.size())
	var reached := {}
	for run in runs:
		reached[str(run.over)] = int(reached.get(str(run.over), 0)) + 1
	var unreached: PackedStringArray = []
	for e in facts.endings:
		if not reached.has(e):
			unreached.append(e)
	var accepted := 0
	for run in runs:
		accepted += run.deals.size()
	var refuse_same := true
	for f in forks:
		if not f.branches.has("refuse") or f.branches.refuse.has("error"):
			continue
		var d := _diff(f.branches.refuse.snaps.t10, f.branches.silence.snaps.t10)
		var only_audience := true
		for k in d.journal:
			if not str(k).begins_with("audience"):
				only_audience = false
		if not d.flags.is_empty() or not d.standing.is_empty() or d.pop != 0 or d.hope != 0 or d.dis != 0 or d.food != 0 or not only_audience or not d.events_only.is_empty():
			refuse_same = false
	var by_count := {}
	for ev in _new_game(1).catalog.events:
		var c: int = ev.get("choices", []).size()
		by_count[c] = int(by_count.get(c, 0)) + 1
	var count_bits: PackedStringArray = []
	for c in by_count:
		count_bits.append("%d with %d choices" % [by_count[c], c])
	md.append("- Catalog events: %s; the %d upkeep events built in `sim/game.gd` are pay or suffer." % [", ".join(count_bits), facts.upkeep])
	md.append("- A 40-week run shows %.1f distinct event ids on average out of %d possible (%d catalog + %d upkeep); %.1f of them come up twice or more. Rumble and its follow-up came up %d and %d times in %d runs." % [distinct / n, facts.events + facts.upkeep, facts.events, facts.upkeep, twice / n, int(facts.fired.get("rumble", 0)), int(facts.fired.get("rumble_next", 0)), runs.size()])
	md.append("- No bot style picked %d of the %d choices in events that fired." % [facts.never_choice, facts.choices])
	md.append("- Endings: %d of %d runs ended on time (week 40); never reached: %s." % [int(reached.get("time", 0)), runs.size(), ", ".join(unreached) if not unreached.is_empty() else "none"])
	md.append("- Artifacts: only papers has a source in the sim; %s are declared with no source." % ", ".join(facts.no_source))
	md.append("- Backstories: %d for %d named residents." % [facts.stories, facts.residents])
	md.append("- Every week had at least one event and one decision (longest gap %d weeks, %.1f empty weeks per run)." % [gap, zero / n])
	md.append("- Leader deals: accepted %d times over the %d silence-style runs. An accepted deal sets its flag, moves standing and changes meters at once; no sim rule reads any of the five deal flags afterwards (`collaborator` is read by the UI for one dossier line); the consequence events read the first answer instead (section 7)." % [accepted, runs.size()])
	md.append("- Refusing and leaving a leader waiting %s at +10 weeks except for the audience row's result (refused or silence); the consequence events treat both as refused." % ("end the same in every fork" if refuse_same else "differ in some forks"))
	md.append("")
