extends SceneTree

## Screenshots of the people/beds chip, the guard on the home card and a march on a rival (windowed, not headless):
##   godot --path . -s res://.tools/guard_shots.gd -- --lang=ru --size=1280x720
## Saves to shots/guard/<lang>_<WxH>/. Settings, saves and logs go to user://guard_shots, not the player's.

const SCRATCH := "user://guard_shots"

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
	out = "guard/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.pending.clear()
	st._refresh()
	await _shot("station_people_chip")
	game._hire(3)
	st._refresh()
	await _shot("station_crowded")
	for each in game.stations:
		game.stations[each].known = true
		game.stations[each].hidden = false
	st._toggle_network()
	await st._frame()
	var net = st.network_view
	net.refresh()
	net._fit()
	net.open_visit(str(game.capital_id))
	await _shot("home_card_guard")
	net.close_visit()
	game.week = 8
	var enemy := ""
	for sid in game._neighbors(game.capital_id):
		var station: Dictionary = game.stations[sid]
		if str(station.get("bunker", "")) == "":
			station.owner = "directorate"
			enemy = str(sid)
			break
	if enemy != "":
		net.refresh()
		net.open_visit(enemy)
		await _shot("rival_card_march")
		net.close_visit()
	quit(0)


func _shot(name: String) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
