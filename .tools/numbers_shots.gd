extends SceneTree

## Numbers clarity screenshots, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/numbers_shots.gd -- --lang=ru --size=1024x768
## Shots go to shots/numbers/<lang>_<WxH>/: the power and materials cards, the hope and discontent
## panels and the generator's room card, on a new game and again at week 8 (careful bot).
## Each shot prints the top bar tooltip it stands for; FIT lines say whether the panel is inside the window.
## Settings, saves and logs go to user://numbers_shots, not the player's.

const SCRATCH := "user://numbers_shots"

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
	out = "numbers/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))

	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending.clear()
	st._refresh()
	await _shots_at("w01")

	var bot := Bot.new()
	bot.profile = "careful"
	while st.game.week < 8 and not st.game.over:
		bot._act(st.game)
		st.game.pending.clear()
		st.game.end_week()
		st.game.pending.clear()
	st._close_card()
	st._refresh()
	await _shots_at("w08")
	quit(0)


func _shots_at(tag: String) -> void:
	for key in ["power", "materials", "hope", "discontent"]:
		print("TIP %s %s: %s" % [tag, key, _tip(key).replace("\n", " | ")])
		st._fill_source(key, true)
		await _shot("%s_%s" % [tag, key])
		_fit("%s_%s" % [tag, key])
		st._hide_source()
	for room in st.game.rooms:
		if str(room.type) == "generator":
			st._show_room(str(room.uid))
			await _shot("%s_generator_card" % tag)
			st._close_card()
			break


func _tip(key: String) -> String:
	if key == "hope" or key == "discontent":
		var label: Label = st.hope_label if key == "hope" else st.dis_label
		return label.get_parent().tooltip_text
	return st._stock_tip(key)


func _fit(name: String) -> void:
	var box: Rect2 = st.source_panel.get_global_rect()
	var view := Rect2(Vector2.ZERO, st.size)
	print("FIT %s panel %s %s" % [name, "inside" if view.grow(1.0).encloses(box) else "OUTSIDE", box])


func _shot(name: String) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
