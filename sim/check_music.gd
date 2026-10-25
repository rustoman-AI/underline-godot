extends SceneTree

## Music player (docs/briefs/cursor_music_player.txt): every track file loads, the state picks the right track,
## the station mood holds against small swings and steps down only after the minimum time, crossfades keep
## equal power, a track restarts on the other player before its end, the ending plays once, the score ducks
## under a voice and comes back in 1.5 s, Music off and Fewer audio cues work, and the Music slider sets the bus.
## The clock is driven by hand; settings go to user://check_music, never to the player's own file.
##   godot --headless --path . -s res://sim/check_music.gd

const SCRATCH := "user://check_music"
const DT := 0.05
const CALM := {"context": "station", "hope": 60, "discontent": 20}

var bad: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	_files()
	_mapping()
	_hysteresis()
	_hold()
	_crossfade()
	_loop()
	_ending()
	_duck()
	_switches()
	_bus()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	## The audio server lets go of stopped playbacks on its next mixes.
	for i in 10:
		await process_frame
	if bad.is_empty():
		print("MUSIC CHECK OK")
		quit(0)
		return
	for line in bad:
		print("  " + line)
	print("MUSIC CHECK FAILED")
	quit(1)


func _files() -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/audio/music_new")):
		bad.append("files: assets/audio/music_new is still there")
	for key in Music.TRACKS:
		var path := Music.file_of(str(key))
		if not ResourceLoader.exists(path):
			bad.append("files: %s is missing" % path)
			continue
		var stream := ResourceLoader.load(path) as AudioStream
		if stream == null or stream.get_length() < Music.LOOP_FADE * 3.0:
			bad.append("files: %s does not load as a track longer than %.0f s" % [path, Music.LOOP_FADE * 3.0])


func _mapping() -> void:
	var cases := [
		[{"context": "menu"}, "menu"],
		[CALM, "calm"],
		[{"context": "station", "hope": 49, "discontent": 20}, "tension"],
		[{"context": "station", "hope": 60, "discontent": 60}, "tension"],
		[{"context": "station", "hope": 60, "discontent": 20, "revolt_warn": true}, "tension"],
		[{"context": "station", "hope": 60, "discontent": 20, "hope_warn": true}, "tension"],
		[{"context": "station", "hope": 60, "discontent": 20, "flood": true}, "crisis"],
		[{"context": "station", "hope": 60, "discontent": 20, "cough_call": true}, "crisis"],
		[{"context": "station", "hope": 60, "discontent": 90, "revolt_warn": true, "revolt_edge": true}, "crisis"],
		[{"context": "ending"}, "ending"],
		[{"context": "none"}, ""],
	]
	for case in cases:
		var score := _score()
		score.step(0.0, case[0])
		if score.track != str(case[1]):
			bad.append("mapping: %s plays '%s', want '%s'" % [str(case[0]), score.track, str(case[1])])
		_drop(score)
	var quiet := _score()
	quiet.allowed = false
	quiet.step(0.0, CALM)
	if quiet.track != "":
		bad.append("mapping: a headless run plays '%s'" % quiet.track)
	_drop(quiet)
	var fresh := Music.new()
	if fresh.allowed:
		bad.append("mapping: the player is allowed in a headless run by default")
	fresh.free()


func _hysteresis() -> void:
	var at := {"context": "station", "hope": 50, "discontent": 20}
	_want("hysteresis: calm at hope 50", Music.pick("calm", at), "calm")
	at.hope = 49
	_want("hysteresis: calm at hope 49", Music.pick("calm", at), "tension")
	at.hope = 52
	_want("hysteresis: tension at hope 52", Music.pick("tension", at), "tension")
	at.hope = 53
	_want("hysteresis: tension at hope 53", Music.pick("tension", at), "calm")
	at.discontent = 48
	_want("hysteresis: tension at discontent 48", Music.pick("tension", at), "tension")
	at.discontent = 46
	_want("hysteresis: tension at discontent 46", Music.pick("tension", at), "calm")
	at.discontent = 55
	_want("hysteresis: calm at discontent 55", Music.pick("calm", at), "calm")
	var edge := {"context": "station", "hope": 60, "discontent": 83, "revolt_warn": true}
	_want("hysteresis: crisis 2 under the edge", Music.pick("crisis", edge, 85), "crisis")
	edge.discontent = 82
	_want("hysteresis: crisis 3 under the edge", Music.pick("crisis", edge, 85), "tension")
	var score := _score()
	score.step(0.0, {"context": "station", "hope": 60, "discontent": 85, "revolt_warn": true, "revolt_edge": true})
	score.step(1.0, {"context": "station", "hope": 60, "discontent": 84, "revolt_warn": true})
	if score.track != "crisis" or score.edge_discontent != 85:
		bad.append("hysteresis: one point off the revolt edge plays '%s' (edge %d)" % [score.track, score.edge_discontent])
	_drop(score)


func _hold() -> void:
	var score := _score()
	score.step(0.0, CALM)
	var tense := {"context": "station", "hope": 40, "discontent": 20}
	score.step(1.0, tense)
	_want("hold: tension at once", score.track, "tension")
	score.step(2.0, {"context": "station", "hope": 60, "discontent": 20, "flood": true})
	_want("hold: crisis at once", score.track, "crisis")
	score.step(30.0, CALM)
	_want("hold: calm before %.0f s" % Music.MIN_HOLD, score.track, "crisis")
	score.step(2.0 + Music.MIN_HOLD - 0.5, CALM)
	_want("hold: calm just before the hold ends", score.track, "crisis")
	score.step(2.0 + Music.MIN_HOLD + 0.5, CALM)
	_want("hold: calm after the hold", score.track, "calm")
	score.step(50.0, {"context": "menu"})
	score.step(51.0, CALM)
	_want("hold: back from the menu", score.track, "calm")
	_drop(score)


func _crossfade() -> void:
	var score := _score()
	_run_to(score, 0.0, Music.SWITCH_FADE + 0.5, CALM)
	var t := Music.SWITCH_FADE + 0.5
	var level := score.level_db()
	_near("crossfade: settled level", score.players[score.front].volume_db, level, 0.05)
	score.step(t, {"context": "station", "hope": 40, "discontent": 20})
	score.step(t + Music.SWITCH_FADE * 0.5, {"context": "station", "hope": 40, "discontent": 20})
	var power := 0.0
	for player in score.players:
		power += pow(db_to_linear(player.volume_db - level), 2.0)
	_near("crossfade: power at mid fade", power, 1.0, 0.01)
	_near("crossfade: each deck at mid fade", score.players[0].volume_db - level, linear_to_db(sin(PI * 0.25)), 0.1)
	_drop(score)


func _loop() -> void:
	var score := _score()
	score.step(0.0, CALM)
	var length := score._length("calm")
	var first := score.front
	score.step(length - Music.LOOP_FADE - 0.1, CALM)
	if score.front != first:
		bad.append("loop: restarted %.1f s before the end, want %.0f" % [Music.LOOP_FADE + 0.1, Music.LOOP_FADE])
	score.step(length - Music.LOOP_FADE + 0.01, CALM)
	if score.front == first or str(score.decks[score.front].get("track", "")) != "calm":
		bad.append("loop: calm did not restart on the other player %.0f s before its end" % Music.LOOP_FADE)
	elif float(score.decks[first].p1) != 0.0 or absf(float(score.decks[first].span) - Music.LOOP_FADE) > 0.001:
		bad.append("loop: the old player does not fade over %.0f s" % Music.LOOP_FADE)
	_drop(score)


func _ending() -> void:
	var score := _score()
	score.step(0.0, {"context": "ending"})
	var length := score._length("ending")
	score.step(length - Music.LOOP_FADE + 0.01, {"context": "ending"})
	if not score.ending_done or score.track != "":
		bad.append("ending: M5 does not fade out %.0f s before its end" % Music.LOOP_FADE)
	score.step(length + 10.0, {"context": "ending"})
	if score.track != "" or not score.decks[0].is_empty() or not score.decks[1].is_empty():
		bad.append("ending: M5 plays again or a player is left on")
	score.step(length + 11.0, {"context": "menu"})
	score.step(length + 12.0, {"context": "ending"})
	_want("ending: a new ending plays M5 again", score.track, "ending")
	_drop(score)


func _duck() -> void:
	var score := _score()
	var t := Music.SWITCH_FADE + 0.5
	_run_to(score, 0.0, t, CALM)
	var level := score.level_db()
	var talk := CALM.duplicate()
	talk.voice = true
	_run_to(score, t, t + Music.DUCK_IN + 0.05, talk)
	t += Music.DUCK_IN + 0.05
	_near("duck: under a voice", score.players[score.front].volume_db, level + Music.DUCK_DB, 0.05)
	_run_to(score, t, t + Music.DUCK_OUT * 0.5, CALM)
	_near("duck: half way back", score.players[score.front].volume_db, level + Music.DUCK_DB * 0.5, 0.2)
	_run_to(score, t + Music.DUCK_OUT * 0.5, t + Music.DUCK_OUT - 0.1, CALM)
	if score.players[score.front].volume_db > level - 0.05:
		bad.append("duck: back before %.1f s" % Music.DUCK_OUT)
	_run_to(score, t + Music.DUCK_OUT - 0.1, t + Music.DUCK_OUT + 0.05, CALM)
	_near("duck: back after %.1f s" % Music.DUCK_OUT, score.players[score.front].volume_db, level, 0.05)
	_drop(score)


func _switches() -> void:
	var score := _score()
	var t := Music.SWITCH_FADE + 0.5
	_run_to(score, 0.0, t, CALM)
	Settings.quiet_cues = true
	score.step(t, CALM)
	_near("fewer cues", score.players[score.front].volume_db, Music.BASE_DB + Music.QUIET_DB, 0.05)
	Settings.quiet_cues = false
	Settings.music_on = false
	_run_to(score, t, t + Music.OUT_FADE + 0.5, CALM)
	if score.track != "" or not score.decks[0].is_empty() or not score.decks[1].is_empty():
		bad.append("music off: a player is left on")
	Settings.music_on = true
	score.step(t + Music.OUT_FADE + 1.0, CALM)
	_want("music on again", score.track, "calm")
	_drop(score)
	Settings.music_on = false
	Settings.save()
	Settings.loaded = false
	Settings.music_on = true
	Settings.load_file()
	if Settings.music_on:
		bad.append("music off: not kept in settings.cfg")
	Settings.music_on = true
	Settings.save()


func _bus() -> void:
	for value in [0.55, 0.2, 1.0]:
		Settings.music = value
		Sound.apply_buses()
		_near("slider %.2f: Music bus" % value, AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(value), 0.01)
	Settings.music = 0.55


func _score() -> Music:
	var score := Music.new()
	score.allowed = true
	root.add_child(score)
	score.set_process(false)
	return score


func _drop(score: Music) -> void:
	for player in score.players:
		player.stop()
	score.free()


func _run_to(score: Music, from: float, to: float, at: Dictionary) -> void:
	var t := from
	while t < to - 0.0001:
		t = minf(to, t + DT)
		score.step(t, at)


func _want(what: String, got: String, want: String) -> void:
	if got != want:
		bad.append("%s: '%s', want '%s'" % [what, got, want])


func _near(what: String, got: float, want: float, tol: float) -> void:
	if absf(got - want) > tol:
		bad.append("%s: %.3f, want %.3f" % [what, got, want])


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
