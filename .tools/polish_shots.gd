extends SceneTree

## Screenshots for docs/briefs/cursor_polish_1.txt, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/polish_shots.gd -- --lang=ru --size=1280x720 [--only=banners]
## Saves to shots/polish_1/<lang>_<WxH>/. Settings, saves and logs go to user://polish_shots, not the player's.

const SCRATCH := "user://polish_shots"
const BANNER_STATIONS := ["riverside", "garden", "central", "signal"]

var st
var size := Vector2i(1280, 720)
var only := ""
var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
		if str(arg).begins_with("--size="):
			var wh := str(arg).trim_prefix("--size=").split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		if str(arg).begins_with("--only="):
			only = str(arg).trim_prefix("--only=")
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	await st._settle(size)
	Settings.apply_scale(st.get_window())
	for _i in 4:
		await process_frame
	st._layout()
	out = "polish_1/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending.clear()
	st._refresh()
	for _i in 6:
		await process_frame
	if only == "" or only == "banners":
		await _banners()
	quit(0)


func _banners() -> void:
	for each in st.game.stations:
		st.game.stations[each].known = true
		st.game.stations[each].hidden = false
	st._toggle_network()
	await st._frame()
	var net = st.network_view
	net.refresh()
	net._fit()
	for sid in BANNER_STATIONS:
		net.open_visit(sid)
		await _shot("banner_visit_" + sid)
		net.close_visit()
		net.open_sheet(sid)
		await _shot("banner_sheet_" + sid)
		net.close_sheet()
	st._toggle_network()
	await st._frame()


func _shot(name: String) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
