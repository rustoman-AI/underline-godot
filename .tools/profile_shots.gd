extends SceneTree

## Dossiers of Tess, Leo, Bait, Hal and Inez and the People panel at weeks 1 and 25 (windowed, one run per language):
##   godot --path . -s res://.tools/profile_shots.gd -- --lang=ru --size=1280x720
## Shots go to shots/profiles/<lang>/. Settings, saves and logs go to user://profile_shots, not the player's.

const SCRATCH := "user://profile_shots"
const DOSSIERS := ["tess", "leo", "kim", "hal", "inez"]

var st
var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	Lore.dry = true
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	await st._settle(st._shot_size())
	out = "profiles/%s" % Copy.lang
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))
	st._begin_new_game(true)
	if st.hub_layer != null:
		st.hub_layer.visible = false
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending.clear()
	st._refresh()
	for id in DOSSIERS:
		var person: Dictionary = st.game.people[id]
		print("%s: %s, %s, %s, wears %s" % [id, st._resident_name(person), person.sex, st._person_title(person), st.game.portrait_name(id, st.portrait_names)])
		st._open_dossier(id)
		await _shot("dossier_" + id)
		st._close_card()
	await _people("people_w1")
	var bot := Bot.new()
	bot.profile = "careful"
	while st.game.week < 25 and st.game.over == "":
		bot._act(st.game)
		st.game.end_week()
	st.game.pending.clear()
	st.game.audience = {}
	st.hold_dawn = true
	st._close_card()
	st._refresh()
	await _people("people_w25")
	var newcomers := 0
	for person in st.game.residents:
		if str(person.id).begins_with("n"):
			newcomers += 1
	print("week %d: %d residents, %d newcomers" % [st.game.week, st.game.residents.size(), newcomers])
	print("SHOTS %s done" % Copy.lang)
	quit(0)


func _people(screen: String) -> void:
	st.drawer_open = true
	st._place_drawer()
	st._fill_people()
	await _shot(screen)
	st.drawer_open = false
	st._place_drawer()


func _shot(screen: String) -> void:
	for i in 4:
		await st._frame()
	await create_timer(0.6).timeout
	await st._frame()
	st._save(out + "/" + screen)
