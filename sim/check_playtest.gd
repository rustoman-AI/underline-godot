extends SceneTree

## Playtest build (docs/briefs/cursor_playtest_build.txt): build info loads, log lines are valid JSON with the
## fields the brief names and no paths, idle gaps leave active time, the copied report carries every field, the
## consent card comes first, and the how-to card shows once per new game until Do not show again.
## Settings, saves and logs go to user://check_playtest, never to the player's own files.
##   godot --headless --path . -s res://sim/check_playtest.gd

const SCRATCH := "user://check_playtest"
const REPORT_FIELDS := ["Version:", "Build:", "Language:", "Active minutes:", "Weeks reached:", "Ending:",
	"Hope and discontent at the last week:", "Decisions per week:", "Slowest weeks (seconds):", "Script errors:",
	"Fragments known:", "Audience answers"]
const NEEDS := {
	"session_start": ["version", "build", "language", "resolution", "fullscreen", "os", "godot_version"],
	"week_start": ["week", "real_seconds_since_start", "hope", "discontent", "stocks"],
	"dawn_events": ["ids"],
	"decision": ["kind", "id", "choice", "week"],
	"audience": ["leader", "answer", "week"],
	"fragment": ["id", "how", "week"],
	"bunker_scene": ["id", "choice"],
	"ending": ["id", "week", "proofs"],
	"error": ["text", "week"],
	"warning": ["text", "week"],
	"idle": ["seconds"],
	"session_end": ["week", "ending", "real_minutes", "active_minutes"],
}

var bad: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")

	_ui_scale()
	_build_info()
	_log_and_report()
	await _station()

	_wipe(ProjectSettings.globalize_path(SCRATCH))
	if bad.is_empty():
		print("PLAYTEST CHECK OK")
		quit(0)
		return
	for line in bad:
		print("  " + line)
	print("PLAYTEST CHECK FAILED")
	quit(1)


## Auto is the default; a manual pick survives a reload; files from before Auto keep a non-default pick.
func _ui_scale() -> void:
	if not Settings.ui_scale_auto:
		bad.append("ui scale: fresh settings are not on Auto")
	for pair in [[720, 0.9], [768, 0.9], [900, 0.9], [1080, 1.0], [1200, 1.1], [1440, 1.35], [2160, 1.6]]:
		if absf(Settings.auto_scale(int(pair[0])) - float(pair[1])) > 0.001:
			bad.append("ui scale: auto at %d is %.3f, want %.2f" % [int(pair[0]), Settings.auto_scale(int(pair[0])), float(pair[1])])
	for case in [["manual", 1.0, false], ["manual", 1.25, false], ["auto", 1.25, true], ["", 1.0, true], ["", 1.5, false]]:
		var cfg := ConfigFile.new()
		cfg.set_value("game", "ui_scale", float(case[1]))
		if str(case[0]) != "":
			cfg.set_value("game", "ui_scale_mode", str(case[0]))
		cfg.save(Settings.path)
		Settings.loaded = false
		Settings.load_file()
		if Settings.ui_scale_auto != bool(case[2]) or absf(Settings.ui_scale - float(case[1])) > 0.001:
			bad.append("ui scale: file %s loads as auto=%s scale=%.2f" % [str(case), Settings.ui_scale_auto, Settings.ui_scale])
		if not Settings.ui_scale_auto and absf(Settings.scale_for(1440) - float(case[1])) > 0.001:
			bad.append("ui scale: manual %s loses to Auto at 1440" % str(case))
	Settings.ui_scale = 1.25
	Settings.ui_scale_auto = false
	Settings.save()
	Settings.loaded = false
	Settings.load_file()
	if Settings.ui_scale_auto or absf(Settings.ui_scale - 1.25) > 0.001:
		bad.append("ui scale: a manual 125% did not survive a save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.ui_scale = 1.0
	Settings.ui_scale_auto = true


func _build_info() -> void:
	var info := BuildInfo.info()
	if not RegEx.create_from_string("^0\\.1\\.0-playtest\\d+$").search(str(info.version)) or str(info.build) == "" or str(info.build) == "unknown":
		bad.append("build_info %s" % str(info))
	if not BuildInfo.line().contains(str(info.version)):
		bad.append("build line %s" % BuildInfo.line())
	print("Build info: %s" % BuildInfo.line())


func _log_and_report() -> void:
	Settings.log_consent = "yes"
	PlaytestLog.started = false
	PlaytestLog.begin({"version": "0.1.0-playtest1", "build": "test", "language": "en", "resolution": "1280x720",
		"fullscreen": false, "os": "Windows", "godot_version": "4.7.2"}, 0)
	if not PlaytestLog.writing:
		bad.append("consent yes but no log file")
	var t := 0
	for week in range(1, 7):
		PlaytestLog.week = week
		PlaytestLog.event("week_start", {"week": week, "real_seconds_since_start": int(t / 1000), "active_seconds": PlaytestLog.active_seconds(t),
			"hope": 60 - week, "discontent": 15 + week, "stocks": {"food": 40, "air": 30}}, t)
		PlaytestLog.event("dawn_events", {"week": week, "ids": ["rat", "flood"]}, t)
		for i in week:
			t += 10000 * week
			PlaytestLog.touch(t)
			PlaytestLog.event("decision", {"kind": "event_choice", "id": "rat", "choice": "trap", "week": week}, t)
	PlaytestLog.event("audience", {"leader": "synod", "answer": "accepted", "week": 3}, t)
	PlaytestLog.event("fragment", {"id": "depot_order", "how": "honest", "week": 4}, t)
	PlaytestLog.event("fragment", {"id": "synod_recording", "how": "dirty", "week": 5}, t)
	PlaytestLog.event("bunker_scene", {"id": "st3_vault", "choice": "open"}, t)
	var before := PlaytestLog.active_seconds(t)
	t += 30000
	PlaytestLog.touch(t)
	t += 130000
	PlaytestLog.touch(t)
	var after := PlaytestLog.active_seconds(t)
	if after != before + 30:
		bad.append("idle: active went %d to %d over 30 s of play and a 130 s gap" % [before, after])
	t += 90000
	if PlaytestLog.active_seconds(t) != after + 90:
		bad.append("a 90 s gap counted as idle")
	t += 125000
	if PlaytestLog.active_seconds(t) != after:
		bad.append("an idle gap still running counted as active")
	PlaytestLog.touch(t)
	push_error("check error in C:\\Users\\someone\\secret\\file.txt and user://playtest/x.jsonl")
	PlaytestLog.pump()
	PlaytestLog.event("ending", {"id": "winter", "week": 6, "proofs": 2}, t)
	PlaytestLog.end(6, "winter", t)
	var rows := PlaytestLog.read_rows(PlaytestLog.path)
	var f := FileAccess.open(PlaytestLog.path, FileAccess.READ)
	var lines := 0
	while f != null and not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		lines += 1
		if not (JSON.parse_string(line) is Dictionary):
			bad.append("line %d is not a JSON object" % lines)
		for needle in ["C:\\", "user://", "someone", "\\Users"]:
			if line.contains(needle):
				bad.append("line %d carries a path: %s" % [lines, line.substr(0, 120)])
	if lines == 0 or rows.size() != lines:
		bad.append("%d lines, %d rows" % [lines, rows.size()])
	var kinds := {}
	for row in rows:
		var kind := str(row.get("event", ""))
		kinds[kind] = true
		if not row.has("t"):
			bad.append("%s row has no time" % kind)
		for key in NEEDS.get(kind, []):
			if not row.has(key):
				bad.append("%s row lacks %s" % [kind, key])
	for kind in ["session_start", "week_start", "dawn_events", "decision", "audience", "fragment", "bunker_scene", "ending", "error", "idle", "session_end"]:
		if not kinds.has(kind):
			bad.append("no %s row" % kind)
	var idle_rows := rows.filter(func(r): return str(r.event) == "idle")
	if idle_rows.size() != 2 or int(idle_rows[0].seconds) != 130 or int(idle_rows[1].seconds) != 215:
		bad.append("idle rows %s" % str(idle_rows))
	if FileAccess.file_exists(PlaytestLog.dir.path_join("running.flag")):
		bad.append("running.flag left after session_end")
	print("Log: %d lines, all JSON objects, kinds %s" % [lines, ", ".join(PackedStringArray(kinds.keys()))])

	var text := PlaytestLog.report_text(rows)
	for field in REPORT_FIELDS:
		if not text.contains(field):
			bad.append("report lacks %s" % field)
	for want in ["Weeks reached: 6", "Ending: winter", "Hope and discontent at the last week: 54 / 21", "Decisions per week: 3.5 (21 decisions)",
			"Slowest weeks (seconds): W6", "Fragments known: honest 1, dirty 1", "synod: accepted W3", "Script errors: 1", "<path>"]:
		if not text.contains(want):
			bad.append("report lacks '%s'" % want)
	var slow := PlaytestLog.week_seconds(rows)
	if int(slow.get(5, 0)) != 250:
		bad.append("week 5 took %s s, want 250" % str(slow.get(5)))
	print("Report:\n" + text)

	PlaytestLog.started = false
	Settings.log_consent = "no"
	var files_before := DirAccess.get_files_at(ProjectSettings.globalize_path(PlaytestLog.dir)).size()
	PlaytestLog.begin({"version": "x"}, 0)
	PlaytestLog.event("week_start", {"week": 1}, 10)
	if PlaytestLog.writing or DirAccess.get_files_at(ProjectSettings.globalize_path(PlaytestLog.dir)).size() != files_before + 1:
		bad.append("No logging still wrote a session file")
	if PlaytestLog.records.size() != 2:
		bad.append("No logging lost the in-memory rows for the report")
	PlaytestLog.end(1, "", 20)
	PlaytestLog.started = false


## The real station, headless: consent first, then the how-to card once per new game.
func _station() -> void:
	Settings.log_consent = ""
	Settings.howto_hidden = false
	var st = load("res://ui/station.tscn").instantiate()
	root.add_child(st)
	for i in 3:
		await process_frame
	if st.notice_layer == null or not _shows(st, "Nothing is sent automatically."):
		bad.append("first launch shows no consent card")
	st._answer_consent(true)
	await process_frame
	if Settings.log_consent != "yes" or not PlaytestLog.writing:
		bad.append("Allow logging did not start the log")
	if st.notice_layer != null:
		bad.append("consent card stays open")
	if not _shows(st, "Playtest log: on") or not _shows(st, "Open log folder") or not _shows(st, "Copy report") or not _shows(st, "Version " + str(BuildInfo.info().version)):
		bad.append("main menu lacks the log row or the version")

	st._begin_new_game(false)
	await process_frame
	if st.howto_count != 1 or st.notice_layer == null or not _shows(st, "How to hold a station"):
		bad.append("new game: how-to shown %d times" % st.howto_count)
	st._close_howto()
	for i in 3:
		st.game.pending.clear()
		st._end_turn()
		st._close_card()
		await process_frame
	st._back_to_menu()
	st._continue_game()
	await process_frame
	if st.howto_count != 1:
		bad.append("how-to shown again on weeks or Continue (%d)" % st.howto_count)
	st._begin_new_game(false)
	await process_frame
	if st.howto_count != 2:
		bad.append("second new game without Do not show again: how-to %d" % st.howto_count)
	st.howto_check.button_pressed = true
	st._close_howto()
	if not Settings.howto_hidden:
		bad.append("Do not show again not kept")
	st._begin_new_game(false)
	await process_frame
	if st.howto_count != 2:
		bad.append("how-to shown after Do not show again")
	st._show_howto(false)
	if st.howto_count != 3:
		bad.append("How to play from the menu does not open the card")
	st._close_howto()
	await process_frame
	var weeks := PlaytestLog.records.filter(func(r): return str(r.event) == "week_start")
	if weeks.size() < 4:
		bad.append("station logged %d week starts" % weeks.size())
	print("Station: consent first, how-to %d times over three new games and one menu open, %d week rows" % [st.howto_count, weeks.size()])
	st._end_log()
	st.queue_free()
	await process_frame


func _shows(node: Node, text: String) -> bool:
	for child in node.find_children("*", "", true, false):
		if (child is Label or child is Button) and child.is_visible_in_tree() and str(child.text).contains(text):
			return true
	return false


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
