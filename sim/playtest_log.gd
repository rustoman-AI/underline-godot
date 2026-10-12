class_name PlaytestLog
extends RefCounted

## Local playtest log (docs/briefs/cursor_playtest_build.txt): one JSON object per line in
## user://playtest/session_<yyyymmdd_hhmmss>.jsonl, written only after the player allows it on the consent card.
## Nothing leaves the computer. Rows carry game ids and numbers only: no names, paths, addresses or hardware ids.
## Every file error is swallowed; logging never stops the game. Rows stay in memory for the copied report even
## while nothing is written.

const IDLE_MS := 120000
const MAX_ERRORS := 200

static var dir := "user://playtest"
static var started := false
static var ended := false
static var writing := false
static var path := ""
static var records: Array = []
## The previous launch never reached session_end: it crashed or was killed.
static var crashed := false
static var week := 0
static var _file: FileAccess = null
static var _t0 := 0
static var _last_input := 0
static var _idle_ms := 0
static var _errors := 0
static var _catch: Catch = null
static var _queue: Array = []
static var _mutex := Mutex.new()


## Script errors and warnings, queued from whatever thread raised them and written by pump().
class Catch extends Logger:
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := rationale if rationale != "" else code
		for trace in script_backtraces:
			if trace != null and trace.get_frame_count() > 0:
				file = trace.get_frame_file(0)
				line = trace.get_frame_line(0)
				function = trace.get_frame_function(0)
				break
		var where := file.get_file()
		if where != "":
			text += " (%s:%d %s)" % [where, line, function]
		PlaytestLog.queue_error("warning" if error_type == Logger.ERROR_TYPE_WARNING else "error", text)

	func _log_message(_message: String, _error: bool) -> void:
		pass


static func now_ms() -> int:
	return Time.get_ticks_msec()


## Starts the session once per launch; a scene reload (language switch) keeps it.
static func begin(start: Dictionary, at: int = -1) -> void:
	if started:
		return
	started = true
	ended = false
	_t0 = now_ms() if at < 0 else at
	_last_input = _t0
	_idle_ms = 0
	_errors = 0
	records = []
	_ensure_dir()
	var flag := dir.path_join("running.flag")
	crashed = FileAccess.file_exists(flag)
	var mark := FileAccess.open(flag, FileAccess.WRITE)
	if mark != null:
		mark.store_string("running")
		mark.close()
	if _catch == null:
		_catch = Catch.new()
		OS.add_logger(_catch)
	event("session_start", start, _t0)
	if Settings.log_consent == "yes":
		_open()


## The player's answer on the consent card or in the Menu. Turning it on mid-session writes what happened so far.
static func set_consent(allow: bool) -> void:
	Settings.log_consent = "yes" if allow else "no"
	Settings.save()
	if not started:
		return
	if allow and not writing:
		_open()
	elif not allow and writing:
		_close()


static func event(kind: String, data: Dictionary = {}, at: int = -1) -> void:
	if not started:
		return
	var row := {"event": kind, "t": snappedf(float((now_ms() if at < 0 else at) - _t0) / 1000.0, 0.1)}
	for key in data:
		row[key] = data[key]
	records.append(row)
	if writing and _file != null:
		_file.store_line(JSON.stringify(row))
		_file.flush()
		if _file.get_error() != OK:
			_close()


## Any input. A gap over two minutes becomes an idle row and does not count as active time.
static func touch(at: int = -1) -> void:
	if not started:
		return
	var t := now_ms() if at < 0 else at
	var gap := t - _last_input
	if gap > IDLE_MS:
		_idle_ms += gap
		event("idle", {"seconds": int(gap / 1000)}, t)
	_last_input = t


static func active_seconds(at: int = -1) -> int:
	var t := now_ms() if at < 0 else at
	var idle := _idle_ms
	if t - _last_input > IDLE_MS:
		idle += t - _last_input
	return maxi(0, int((t - _t0 - idle) / 1000))


static func real_seconds(at: int = -1) -> int:
	return maxi(0, int(((now_ms() if at < 0 else at) - _t0) / 1000))


static func queue_error(kind: String, text: String) -> void:
	_mutex.lock()
	if _queue.size() < MAX_ERRORS:
		_queue.append({"kind": kind, "text": clean(text)})
	_mutex.unlock()


## Writes queued script errors. Called every frame from the station.
static func pump() -> void:
	if _queue.is_empty():
		return
	_mutex.lock()
	var rows := _queue
	_queue = []
	_mutex.unlock()
	for row in rows:
		if _errors >= MAX_ERRORS:
			return
		_errors += 1
		event(str(row.kind), {"text": str(row.text), "week": week})


static func end(last_week: int, ending: String, at: int = -1) -> void:
	if not started or ended:
		return
	pump()
	var t := now_ms() if at < 0 else at
	touch(t)
	ended = true
	event("session_end", {
		"week": last_week,
		"ending": ending,
		"real_minutes": snappedf(float(real_seconds(t)) / 60.0, 0.1),
		"active_minutes": snappedf(float(active_seconds(t)) / 60.0, 0.1),
	}, t)
	_close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join("running.flag")))


static func folder() -> String:
	_ensure_dir()
	return ProjectSettings.globalize_path(dir)


## Drops paths from an error text so the log never names a folder on the player's computer.
static func clean(text: String) -> String:
	var re := RegEx.create_from_string("([A-Za-z]:[\\\\/]|user://|/Users/|/home/)[^\\s'\"()]*")
	var out := re.sub(text, "<path>", true)
	return out.substr(0, 300)


static func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


static func _open() -> void:
	_ensure_dir()
	var d := Time.get_datetime_dict_from_system()
	path = dir.path_join("session_%04d%02d%02d_%02d%02d%02d.jsonl" % [int(d.year), int(d.month), int(d.day), int(d.hour), int(d.minute), int(d.second)])
	_file = FileAccess.open(path, FileAccess.WRITE)
	writing = _file != null
	if not writing:
		return
	for row in records:
		_file.store_line(JSON.stringify(row))
	_file.flush()


static func _close() -> void:
	if _file != null:
		_file.close()
	_file = null
	writing = false


## Plain-text summary of one session's rows for the Copy report button and .tools/playtest_report.js.
## `active` overrides the active seconds while the session is still running.
static func report_text(rows: Array, active: int = -1) -> String:
	var start := {}
	var finish := {}
	var weeks: Array = []
	var decisions := 0
	var ending := ""
	var errors: Array = []
	var warnings := 0
	var honest := 0
	var dirty := 0
	var found := 0
	var answers := {}
	for row in rows:
		if not (row is Dictionary):
			continue
		match str(row.get("event", "")):
			"session_start":
				start = row
			"session_end":
				finish = row
			"week_start":
				weeks.append(row)
			"decision":
				decisions += 1
			"ending":
				ending = str(row.get("id", ""))
			"error":
				errors.append(str(row.get("text", "")))
			"warning":
				warnings += 1
			"fragment":
				match str(row.get("how", "")):
					"honest":
						honest += 1
					"dirty":
						dirty += 1
					_:
						found += 1
			"audience":
				var leader := str(row.get("leader", ""))
				if not answers.has(leader):
					answers[leader] = []
				answers[leader].append("%s W%d" % [str(row.get("answer", "")), int(row.get("week", 0))])
	var reached := 0
	var last: Dictionary = {}
	for row in weeks:
		if int(row.get("week", 0)) >= reached:
			reached = int(row.get("week", 0))
			last = row
	var minutes := float(finish.get("active_minutes", 0.0))
	if active >= 0:
		minutes = snappedf(float(active) / 60.0, 0.1)
	var lines: PackedStringArray = []
	lines.append("Underline playtest report")
	lines.append("Version: %s" % str(start.get("version", "unknown")))
	lines.append("Build: %s" % str(start.get("build", "unknown")))
	lines.append("Language: %s" % str(start.get("language", "")))
	lines.append("Active minutes: %.1f" % minutes)
	lines.append("Weeks reached: %d" % reached)
	lines.append("Ending: %s" % (ending if ending != "" else "not finished"))
	if last.is_empty():
		lines.append("Hope and discontent at the last week: none")
	else:
		lines.append("Hope and discontent at the last week: %d / %d (week %d)" % [int(last.get("hope", 0)), int(last.get("discontent", 0)), reached])
	var counted := maxi(1, _distinct_weeks(weeks))
	lines.append("Decisions per week: %.1f (%d decisions)" % [float(decisions) / float(counted), decisions])
	var slow := week_seconds(rows)
	var keys := slow.keys()
	keys.sort_custom(func(a, b): return int(slow[a]) > int(slow[b]) or (int(slow[a]) == int(slow[b]) and int(a) < int(b)))
	var top: PackedStringArray = []
	for key in keys.slice(0, 5):
		top.append("W%d %ds" % [int(key), int(slow[key])])
	lines.append("Slowest weeks (seconds): %s" % (", ".join(top) if not top.is_empty() else "none"))
	lines.append("Script errors: %d (warnings %d)" % [errors.size(), warnings])
	for text in errors.slice(maxi(0, errors.size() - 3)):
		lines.append("  " + str(text))
	lines.append("Fragments known: honest %d, dirty %d, found %d" % [honest, dirty, found])
	if answers.is_empty():
		lines.append("Audience answers: none")
	else:
		lines.append("Audience answers:")
		var leaders := answers.keys()
		leaders.sort()
		for leader in leaders:
			lines.append("  %s: %s" % [leader, ", ".join(PackedStringArray(answers[leader]))])
	return "\n".join(lines)


## Active seconds spent in each week, from one week_start to the next (or to session_end). A week played in
## two stretches, after a reload, adds up.
static func week_seconds(rows: Array) -> Dictionary:
	var out := {}
	var open_week := -1
	var open_at := 0.0
	for row in rows:
		if not (row is Dictionary):
			continue
		var kind := str(row.get("event", ""))
		if kind != "week_start" and kind != "session_end":
			continue
		var at := float(row.get("active_seconds", -1.0))
		if kind == "session_end":
			at = float(row.get("active_minutes", 0.0)) * 60.0
		if open_week >= 0 and at >= open_at:
			out[open_week] = int(out.get(open_week, 0)) + int(round(at - open_at))
		open_week = int(row.get("week", 0)) if kind == "week_start" else -1
		open_at = at
	return out


static func _distinct_weeks(weeks: Array) -> int:
	var seen := {}
	for row in weeks:
		seen[int(row.get("week", 0))] = true
	return seen.size()


## Every line of a session file as a Dictionary; lines that do not parse are skipped.
static func read_rows(file_path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		var row = JSON.parse_string(line)
		if row is Dictionary:
			out.append(row)
	return out
