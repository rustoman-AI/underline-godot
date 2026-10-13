extends SceneTree

## Upgrade screenshots, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/upgrade_shots.gd -- --lang=ru --size=1024x768
## The careful bot plays to week 8 (two hydroponics by then); one hydroponics is then upgraded on screen.
## Shots go to shots/upgrades/<lang>_<WxH>/: the yard with two plain hydroponics, the room card before, the
## confirm card, the toast and flash right after buying, the room card after, the yard at tier I and at tier II.
## Settings, saves and logs go to user://upgrade_shots, not the player's.

const SCRATCH := "user://upgrade_shots"

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
	out = "upgrades/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))

	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var bot := Bot.new()
	bot.profile = "careful"
	while st.game.week < 8 and not st.game.over:
		st.game.pending.clear()
		bot._act(st.game)
		st.game.pending.clear()
		st.game.end_week()
	st.game.pending.clear()
	st._close_card()
	var hydro: Array = []
	for room in st.game.rooms:
		if str(room.type) == "hydroponics":
			room.upgrade = 0
			hydro.append(str(room.uid))
	print("HYDRO %d rooms: %s" % [hydro.size(), hydro])
	var uid: String = hydro[0]
	st.game.stock.materials = maxi(int(st.game.stock.materials), 40)
	st._refresh()
	st.yard.fit()
	await _shot("yard_tier0")

	st._show_room(uid)
	await _shot("card_before")
	st._confirm_upgrade(uid)
	await _shot("confirm")
	st._do_upgrade(uid)
	await _shot("toast_flash", 6)
	print("TOAST %s" % st.toast_label.text)
	await _settle_flash()
	st._show_room(uid)
	await _shot("card_after")
	st._close_card()
	await _shot("yard_tier1")
	st._do_upgrade(uid)
	await _settle_flash()
	st.toast_label.visible = false
	await _shot("yard_tier2")
	st._show_room(uid)
	await _shot("card_tier2")
	quit(0)


func _settle_flash() -> void:
	for _i in 90:
		await process_frame
	st.yard.flash.clear()


func _shot(name: String, frames := 30) -> void:
	for _i in frames:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
