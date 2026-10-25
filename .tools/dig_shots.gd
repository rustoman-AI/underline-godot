extends SceneTree

## A dig in progress, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/dig_shots.gd -- --lang=ru --size=2048x1090
## Starts a two-week dig on the deepest level, saves the whole yard and the dug cell up close to
## shots/dig/<lang>_<WxH>/ and prints the badge text. Settings, saves and logs go to user://dig_shots.

const SCRATCH := "user://dig_shots"

var st
var size := Vector2i(1280, 720)
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
	out = "dig/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))

	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.pending.clear()
	game.stock.materials = maxi(int(game.stock.materials), 40)
	var spot := Vector2i(-1, -1)
	for level in [2, 1]:
		for cell in 6:
			if bool(game.dig_preview(level, cell).get("ok", false)):
				spot = Vector2i(level, cell)
				break
		if spot.x >= 0:
			break
	if spot.x < 0 or not game.apply({"kind": "dig", "level": spot.x, "cell": spot.y}):
		push_error("dig_shots: no cell could be dug")
		quit(1)
		return
	st._refresh()
	var job: Vector2i = st.yard._job_span(spot.x, spot.y)
	print("DIG %s cell %s: week %d of %d, crew %d" % [Copy.lang, spot, job.y - job.x + 1, job.y, game.dig.workers.size()])
	st.yard.fit()
	await _shot("dig_yard")
	st.yard._zoom_to(spot.x, spot.y)
	await _shot("dig_close")
	quit(0)


func _shot(name: String) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
