extends SceneTree

## Soak test: bot runs per audience style with save/load identity checks and invariants every week.
##   godot --headless --path . -s res://.tools/soak.gd -- --styles=silence,helper --seeds=200 --from=1 --weeks=40
##   godot --headless --path . -s res://.tools/soak.gd -- --report
## Each style writes build/soak/<style>.json; --report merges them into docs/audit/soak_<date>.md.
## --keep=N copies the first save of the first N seeds per style to build/soak/saves/ (for the save fuzz).
## Saves go under user://soak_<pid>/ only; the player's slots are never touched.

const STYLES := ["silence", "helper", "helper_mixed", "accept_all", "mixed", "storyteller", "storyteller_climb"]
const FOLLOW := 5
const OUT := "res://build/soak"

var catalog: Catalog
var failures: Array = []
var context := ""
var caught: Array = []
var print_catalog := {}
const CATALOG_FIELDS := ["balance", "rooms", "laws", "factions", "leaders", "lines", "stations", "tunnels", "events",
	"check_events", "truth", "endings", "coney", "cast_portraits", "residents", "names", "grid", "communities"]


class Catch extends Logger:
	var sink: Callable

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if rationale != "" else code
		var kind := "script_warning" if error_type == Logger.ERROR_TYPE_WARNING else "script_error"
		sink.call(kind, "%s (%s:%d %s)" % [text, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _init() -> void:
	var args := _args()
	if args.has("report"):
		_report()
		quit(0)
		return
	Copy.set_lang(str(args.get("lang", "en")))
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	var logger := Catch.new()
	logger.sink = func(kind: String, text: String) -> void: caught.append([kind, text])
	OS.add_logger(logger)
	var styles: Array = str(args.get("styles", ",".join(STYLES))).split(",", false)
	var seeds := int(args.get("seeds", 200))
	var first := int(args.get("from", 1))
	var weeks := int(args.get("weeks", 40))
	var keep := int(args.get("keep", 0))
	SaveGame.root = "user://soak_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var started := Time.get_ticks_msec()
	Game.new().setup(catalog, 1, weeks)
	print_catalog = _catalog_prints()
	for style in styles:
		var rows: Array = []
		failures = []
		var t0 := Time.get_ticks_msec()
		for i in seeds:
			var run_seed := first + i
			rows.append(_run(str(style), run_seed, weeks, i < keep))
		var out := {
			"style": style, "seeds": seeds, "from": first, "weeks": weeks, "lang": Copy.lang,
			"runs": rows, "failures": failures, "ms": Time.get_ticks_msec() - t0,
		}
		var f := FileAccess.open(OUT.path_join("%s.json" % style), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
		print("STYLE %s seeds %d failures %d ms %d" % [style, seeds, failures.size(), int(out.ms)])
	_wipe(SaveGame.root)
	SaveGame.root = "user://"
	print("SOAK DONE ms %d" % (Time.get_ticks_msec() - started))
	quit(0)


func _args() -> Dictionary:
	var out := {}
	for arg in OS.get_cmdline_user_args():
		var text := str(arg).trim_prefix("--")
		var at := text.find("=")
		if at < 0:
			out[text] = true
		else:
			out[text.substr(0, at)] = text.substr(at + 1)
	return out


func _fail(kind: String, style: String, run_seed: int, week: int, detail: String) -> void:
	failures.append({"kind": kind, "style": style, "seed": run_seed, "week": week, "detail": detail})


func _bot(style: String) -> Bot:
	var bot := Bot.new()
	bot.profile = "careful"
	bot.audience_style = style
	return bot


func _run(style: String, run_seed: int, weeks: int, keep: bool) -> Dictionary:
	var game := Game.new()
	game.setup(catalog, run_seed, weeks)
	var bot := _bot(style)
	var pick := RandomNumberGenerator.new()
	pick.seed = run_seed * 7919 + STYLES.find(style) * 104729 + 17
	var save_at := {}
	while save_at.size() < 3:
		save_at[pick.randi_range(2, weeks - FOLLOW)] = "dawn" if pick.randf() < 0.5 else "turn"
	var clones: Array = []
	var kept := false
	var seen_audience := {}
	var front_id := ""
	var front_weeks := 0
	var reported := {}
	var guard := 0
	var fails_before := failures.size()
	while game.over == "" and guard < weeks + 2:
		guard += 1
		var week := game.week
		_drain(style, run_seed, week, reported)
		_check(game, style, run_seed, reported)
		if not game.audience.is_empty() and int(game.audience.get("week", week)) < week - 1:
			_once(reported, "audience_stuck", style, run_seed, week, str(game.audience))
		var front := str(game.pending[0].id) if not game.pending.is_empty() else ""
		if front != "" and front == front_id:
			front_weeks += 1
			if front_weeks >= 3:
				_once(reported, "event_stuck", style, run_seed, week, front)
		else:
			front_id = front
			front_weeks = 0
		if save_at.get(week, "") == "dawn":
			var c := _clone(game, style, run_seed, week, "dawn", keep and not kept)
			kept = kept or not c.is_empty()
			if not c.is_empty():
				clones.append(c)
		for c in clones:
			c.bot._act(c.game)
		bot._act(game)
		if save_at.get(week, "") == "turn":
			var c := _clone(game, style, run_seed, week, "turn", keep and not kept)
			kept = kept or not c.is_empty()
			if not c.is_empty():
				clones.append(c)
		for c in clones:
			c.game.end_week()
		game.end_week()
		_drain(style, run_seed, week, reported)
		if game.over == "" and game.week == week:
			_once(reported, "week_stuck", style, run_seed, week, "end_week left week %d" % week)
			break
		var still: Array = []
		for c in clones:
			var diff := _diff(game.export_state(), c.game.export_state())
			if diff != "":
				_once(reported, "save_divergence", style, run_seed, week, "%s save at W%d, differs at W%d end: %s" % [c.how, c.from, week, diff])
			elif int(c.until) > week and game.over == "":
				still.append(c)
		clones = still
	_check(game, style, run_seed, reported)
	var now := _catalog_prints()
	for field in now:
		if now[field] != print_catalog[field]:
			_once(reported, "catalog_mutated", style, run_seed, game.week, "catalog.%s changed during the run" % field)
	print_catalog = now
	if game.over == "":
		_once(reported, "no_ending", style, run_seed, game.week, "week %d" % game.week)
	return {
		"seed": run_seed, "over": game.over, "ending": game.ending_id(), "week": game.week,
		"fails": failures.size() - fails_before,
	}


var known_text := ""


## A flag the data or the code names somewhere; anything else was set from nowhere the game reads.
func _known_flag(flag: String) -> bool:
	if known_text == "":
		for dir_path in ["res://data", "res://sim"]:
			for file in DirAccess.get_files_at(dir_path):
				if file.ends_with(".json") or file.ends_with(".gd"):
					known_text += FileAccess.get_file_as_string(dir_path.path_join(file))
	return known_text.contains("\"%s\"" % flag)


func _catalog_prints() -> Dictionary:
	var out := {}
	for field in CATALOG_FIELDS:
		out[field] = var_to_bytes(catalog.get(field)).hex_encode().sha256_text()
	return out


func _once(reported: Dictionary, kind: String, style: String, run_seed: int, week: int, detail: String) -> void:
	if reported.has(kind):
		return
	reported[kind] = true
	_fail(kind, style, run_seed, week, detail)


func _drain(style: String, run_seed: int, week: int, reported: Dictionary) -> void:
	for row in caught:
		_once(reported, str(row[0]), style, run_seed, week, str(row[1]))
	caught.clear()


func _clone(game: Game, style: String, run_seed: int, week: int, how: String, keep: bool) -> Dictionary:
	if not SaveGame.write_auto(game):
		_fail("save_failed", style, run_seed, week, SaveGame.last_error)
		return {}
	if keep:
		var dir := ProjectSettings.globalize_path(OUT.path_join("saves"))
		DirAccess.make_dir_recursive_absolute(dir)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SaveGame.auto_path()), dir.path_join("%s_%d_w%d_%s.sav" % [style, run_seed, week, how]))
	var copy := Game.new()
	copy.setup(catalog, run_seed + 100000, game.max_weeks)
	var why := SaveGame._read(SaveGame.auto_path(), copy)
	if why != "":
		_fail("load_failed", style, run_seed, week, why)
		return {}
	var diff := _diff(game.export_state(), copy.export_state())
	if diff != "":
		_fail("load_mismatch", style, run_seed, week, "%s save: %s" % [how, diff])
		return {}
	return {"game": copy, "bot": _bot(style), "from": week, "until": week + FOLLOW - 1, "how": how}


## The first key where two exported states differ, with a short path; "" when equal.
func _diff(a: Dictionary, b: Dictionary) -> String:
	for key in a:
		if not b.has(key):
			return "%s missing" % key
		var at := _where(a[key], b[key], str(key))
		if at != "":
			return at
	for key in b:
		if not a.has(key):
			return "%s extra" % key
	return ""


func _where(x, y, path: String) -> String:
	if typeof(x) != typeof(y):
		if (x is float or x is int) and (y is float or y is int) and float(x) == float(y):
			return ""
		return "%s type %s vs %s" % [path, type_string(typeof(x)), type_string(typeof(y))]
	if x is Dictionary:
		if x.size() != y.size():
			return "%s size %d vs %d" % [path, x.size(), y.size()]
		for k in x:
			if not y.has(k):
				return "%s.%s missing" % [path, str(k)]
			var at := _where(x[k], y[k], "%s.%s" % [path, str(k)])
			if at != "":
				return at
		return ""
	if x is Array:
		if x.size() != y.size():
			return "%s size %d vs %d" % [path, x.size(), y.size()]
		for i in x.size():
			var at := _where(x[i], y[i], "%s[%d]" % [path, i])
			if at != "":
				return at
		return ""
	if x != y:
		return "%s %s vs %s" % [path, str(x).left(60), str(y).left(60)]
	return ""


func _check(game: Game, style: String, run_seed: int, reported: Dictionary) -> void:
	var week := game.week
	for line in game.errors:
		_once(reported, "game_error", style, run_seed, week, str(line))
	for key in game.stock:
		if int(game.stock[key]) < 0:
			_once(reported, "negative_stock", style, run_seed, week, "%s %d" % [key, int(game.stock[key])])
	for key in game.artifacts:
		if int(game.artifacts[key]) < 0:
			_once(reported, "negative_stock", style, run_seed, week, "artifact %s %d" % [key, int(game.artifacts[key])])
	if game.hope < 0 or game.hope > 100 or game.discontent < 0 or game.discontent > 100:
		_once(reported, "meter_range", style, run_seed, week, "hope %d discontent %d" % [game.hope, game.discontent])
	var ids := {}
	for person in game.residents:
		var id := str(person.id)
		if ids.has(id):
			_once(reported, "resident_twice", style, run_seed, week, id)
		ids[id] = true
		if not game.people.has(id) or not is_same(game.people[id], person):
			_once(reported, "people_sync", style, run_seed, week, "resident %s not the people entry" % id)
	if ids.size() != game.people.size():
		_once(reported, "people_sync", style, run_seed, week, "people %d residents %d" % [game.people.size(), ids.size()])
	var placed := {}
	for room in game.rooms:
		for id in room.staff:
			var key := str(id)
			if placed.has(key):
				_once(reported, "two_rooms", style, run_seed, week, "%s in %s and %s" % [key, placed[key], room.uid])
			placed[key] = str(room.uid)
			if not game.people.has(key):
				_once(reported, "ghost_staff", style, run_seed, week, "%s in %s" % [key, room.uid])
	for job_name in ["dig", "build"]:
		var job: Dictionary = game.get(job_name)
		for id in job.get("workers", []):
			var key := str(id)
			if placed.has(key):
				_once(reported, "two_rooms", style, run_seed, week, "%s on %s and in %s" % [key, job_name, placed[key]])
			placed[key] = job_name
			if not game.people.has(key):
				_once(reported, "ghost_staff", style, run_seed, week, "%s on %s" % [key, job_name])
	for flag in game.flags:
		var at = game.flags[flag]
		var fine: bool = (typeof(at) == TYPE_BOOL and at) or (typeof(at) == TYPE_INT and int(at) >= 1 and int(at) <= week)
		if not fine or not _known_flag(str(flag)):
			_once(reported, "orphan_flag", style, run_seed, week, "%s = %s" % [str(flag), str(at)])
	var target := str(game.audience.get("target", ""))
	if target != "" and not game.people.has(target):
		_once(reported, "orphan_flag", style, run_seed, week, "audience target %s gone" % target)
	var nan := _nan(game.export_state(), "")
	if nan != "":
		_once(reported, "nan", style, run_seed, week, nan)
	for ev in game.pending:
		for key in ["title", "text"]:
			if game.line_of(ev, key).strip_edges() == "":
				_once(reported, "empty_text", style, run_seed, week, "%s %s" % [str(ev.get("id", "")), key])
		for choice in ev.get("choices", []):
			if game.line_of(choice, "label").strip_edges() == "":
				_once(reported, "empty_text", style, run_seed, week, "%s choice %s label" % [str(ev.get("id", "")), str(choice.get("id", ""))])


func _nan(value, path: String) -> String:
	if value is float:
		return path if is_nan(value) or is_inf(value) else ""
	if value is Dictionary:
		for k in value:
			var at := _nan(value[k], "%s.%s" % [path, str(k)])
			if at != "":
				return at
	elif value is Array:
		for i in value.size():
			var at := _nan(value[i], "%s[%d]" % [path, i])
			if at != "":
				return at
	return ""


func _wipe(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(dir_path)


func _report() -> void:
	var date := Time.get_date_string_from_system().replace("-", "")
	var lines: PackedStringArray = []
	var all_fail: Array = []
	var table: Array = []
	var ending_names := {}
	var total_ms := 0
	for style in STYLES:
		var path := OUT.path_join("%s.json" % style)
		if not FileAccess.file_exists(path):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary:
			continue
		total_ms += int(data.ms)
		var endings := {}
		var no_end := 0
		var clean := 0
		for run in data.runs:
			var key := str(run.ending) if str(run.over) != "" else "(none)"
			if str(run.ending) == "" and str(run.over) != "":
				key = "over:%s" % run.over
			endings[key] = int(endings.get(key, 0)) + 1
			ending_names[key] = true
			if str(run.over) == "":
				no_end += 1
			if int(run.fails) == 0:
				clean += 1
		table.append({"style": style, "runs": data.runs.size(), "seeds": "%d..%d" % [int(data.from), int(data.from) + int(data.seeds) - 1], "endings": endings, "no_end": no_end, "clean": clean, "fails": data.failures.size(), "weeks": int(data.weeks)})
		all_fail.append_array(data.failures)
	lines.append("# Soak test, %s" % Time.get_date_string_from_system())
	lines.append("")
	lines.append("Bot profile careful, each style over its seeds for up to 40 weeks. In every run the game is saved to disk and loaded into a fresh game of another seed at three random weeks (half at dawn right after the autosave point, half after the turn's actions, like a manual save); the loaded copy then plays the same bot for 5 weeks and its whole exported state is compared with the uninterrupted run after every week. Invariants are checked every week; script errors and warnings are caught with a Logger.")
	lines.append("")
	lines.append("Total time %.1f min summed over the styles (one process per style, in parallel)." % (total_ms / 60000.0))
	lines.append("")
	lines.append("## Runs")
	lines.append("")
	lines.append("| Style | Seeds | Runs | Clean runs | Failures | No ending by week 40 |")
	lines.append("|---|---|---|---|---|---|")
	for row in table:
		lines.append("| %s | %s | %d | %d | %d | %d |" % [row.style, row.seeds, row.runs, row.clean, row.fails, row.no_end])
	lines.append("")
	lines.append("## Endings per style")
	lines.append("")
	var names: Array = ending_names.keys()
	names.sort()
	var head := "| Style |"
	var rule := "|---|"
	for n in names:
		head += " %s |" % n
		rule += "---|"
	lines.append(head)
	lines.append(rule)
	for row in table:
		var line := "| %s |" % row.style
		for n in names:
			line += " %d |" % int(row.endings.get(n, 0))
		lines.append(line)
	lines.append("")
	lines.append("## Failures by kind")
	lines.append("")
	if all_fail.is_empty():
		lines.append("None.")
	else:
		var kinds := {}
		for f in all_fail:
			var k := str(f.kind)
			if not kinds.has(k):
				kinds[k] = {"count": 0, "first": f, "styles": {}}
			kinds[k].count += 1
			kinds[k].styles[str(f.style)] = true
			var first: Dictionary = kinds[k].first
			if int(f.seed) < int(first.seed):
				kinds[k].first = f
		lines.append("| Kind | Runs | Styles | First failing seed | Week | Detail |")
		lines.append("|---|---|---|---|---|---|")
		for k in kinds:
			var first: Dictionary = kinds[k].first
			lines.append("| %s | %d | %s | %s %d | %d | %s |" % [k, int(kinds[k].count), ", ".join(PackedStringArray(kinds[k].styles.keys())), first.style, int(first.seed), int(first.week), str(first.detail).replace("|", "/").left(160)])
		lines.append("")
		lines.append("Reproduce one run:")
		lines.append("")
		for k in kinds:
			var first: Dictionary = kinds[k].first
			lines.append("- %s: `.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://.tools/soak.gd -- --styles=%s --seeds=1 --from=%d` then `-- --report`" % [k, first.style, int(first.seed)])
	lines.append("")
	lines.append("## Reproduce the whole soak")
	lines.append("")
	lines.append("One process per style (they run in parallel), then the merge:")
	lines.append("")
	lines.append("```")
	lines.append(".tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://.tools/soak.gd -- --styles=<style> --seeds=200 --from=1 --weeks=40 --keep=8")
	lines.append(".tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://.tools/soak.gd -- --report")
	lines.append("```")
	lines.append("")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audit"))
	var out := "res://docs/audit/soak_%s.md" % date
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("REPORT ", out)
