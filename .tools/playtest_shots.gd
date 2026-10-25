extends SceneTree

## Playtest build shots (docs/briefs/cursor_playtest_build.txt), one language per run:
##   godot --path . -s res://.tools/playtest_shots.gd -- --lang=ru --size=1280x720 --build=1a2b3c4
## Saves shots/playtest/<lang>_<size>/: consent card over the main menu, how-to card, main menu and in-game Menu
## with the log row and version. Then plays five weeks with the log on and writes the copied report to
## shots/playtest/report_<lang>.txt. Settings, saves and logs go to user://playtest_shots, not the player's.

const SCRATCH := "user://playtest_shots"

var st


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var build := "dev"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
		if str(arg).begins_with("--build="):
			build = str(arg).trim_prefix("--build=")
	BuildInfo.info()
	BuildInfo._info["build"] = build
	BuildInfo._info["date"] = Time.get_date_string_from_system()
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = ""
	Settings.howto_hidden = false
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")

	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	var size: Vector2i = st._shot_size()
	await st._settle(size)
	var out := "playtest/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))

	st._show_main_menu()
	st._show_consent()
	await _frames()
	print("FIT %s consent %s" % [Copy.lang, _fit(size)])
	st._save(out + "/consent")
	st._answer_consent(true)
	st._show_howto(false)
	await _frames()
	print("FIT %s howto %s" % [Copy.lang, _fit(size)])
	st._save(out + "/howto")
	st._close_howto()
	st._fill_menu_root()
	await _frames()
	st._save(out + "/menu_main")

	PlaytestLog.begin(st._session_info())
	st.shot_mode = false
	st._begin_new_game(false)
	st._close_notice()
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var bot := Bot.new()
	bot.profile = "careful"
	for week in 5:
		await _frames()
		bot._act(st.game)
		st.game.pending.clear()
		st._end_turn()
		st._close_card()
	await _frames()
	st.shot_mode = true
	st._show_menu()
	await _frames()
	print("FIT %s menu %s" % [Copy.lang, _fit(size)])
	st._save(out + "/menu_game")
	var report: String = st._report_text()
	var f := FileAccess.open(ProjectSettings.globalize_path("res://shots/playtest/report_%s.txt" % Copy.lang), FileAccess.WRITE)
	f.store_string(report + "\n")
	f.close()
	print(report)
	PlaytestLog.end(st.game.week, "")
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	quit(0)


func _frames() -> void:
	for i in 3:
		await st._frame()


## Whether the open paper card (notice or Menu card) sits inside the window without scrolling.
func _fit(size: Vector2i) -> String:
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	var panel: Control = null
	if st.notice_layer != null:
		panel = st.notice_layer.find_children("*", "PanelContainer", true, false)[0]
	elif st.card_scroll != null and st.card_scroll.is_visible_in_tree():
		if st.card_body.size.y > st.card_scroll.size.y + 1:
			return "scrolls (%d of %d px)" % [int(st.card_body.size.y), int(st.card_scroll.size.y)]
		panel = st.card_scroll
	if panel == null:
		return "no card"
	return "ok" if screen.encloses(panel.get_global_rect()) else "outside the window %s" % str(panel.get_global_rect())


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
