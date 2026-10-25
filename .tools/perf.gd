extends SceneTree

## Performance numbers, windowed (vsync off, no FPS cap):
##   godot --path . -s res://.tools/perf.gd -- --size=1920x1080
## Time from engine start to the first drawn main menu, frame time on a busy week-25 station and on the zoomed
## network map, memory and node counts at week 1 and after 40 weeks (opening the journal and the map every
## week to catch leaks), and manual save / load time. Settings, saves and logs go to user://perf.

const SCRATCH := "user://perf"
const FRAMES := 400

var st


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var size := Vector2i(1920, 1080)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--size="):
			var bits := str(arg).trim_prefix("--size=").split("x")
			size = Vector2i(int(bits[0]), int(bits[1]))
	Copy.set_lang("en")
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.fullscreen = false
	Settings.resume = false
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	var script_at := Time.get_ticks_msec()
	st = load("res://ui/station.tscn").instantiate()
	root.add_child(st)
	await process_frame
	await RenderingServer.frame_post_draw
	var menu_at := Time.get_ticks_msec()
	print("PERF engine_to_script_ms %d" % script_at)
	print("PERF menu_drawn_ms %d (scene build %d ms) menu_visible %s" % [menu_at, menu_at - script_at, str(st.menu_layer != null and st.menu_layer.visible)])
	print("PERF adapter %s / %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = size
	for i in 6:
		await process_frame

	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.hold_dawn = true
	st._refresh()
	for i in 10:
		await process_frame
	var mem_w1 := _mem()
	print("PERF week1 %s" % _mem_text(mem_w1))

	var bot := Bot.new()
	bot.profile = "careful"
	bot.audience_style = "helper"
	var week_ms := 0
	while st.game.week < 25 and st.game.over == "":
		var t := Time.get_ticks_msec()
		bot._act(st.game)
		st.game.end_week()
		st._refresh()
		week_ms += Time.get_ticks_msec() - t
		await process_frame
	st.game.pending.clear()
	st.game.audience = {}
	st._close_card()
	st._refresh()
	for i in 30:
		await process_frame
	print("PERF station_w25 %s rooms %d residents %d" % [_frames_text(await _frames()), st.game.rooms.size(), st.game.residents.size()])

	st._toggle_network()
	await process_frame
	st.network_view._fit()
	for i in 10:
		await process_frame
	print("PERF network_fit %s" % _frames_text(await _frames()))
	var centre: Vector2 = st.network_view.get_global_rect().get_center()
	st.network_view._zoom_at(centre, 2.5)
	for i in 10:
		await process_frame
	print("PERF network_zoom x%.2f %s" % [float(st.network_view.zoom), _frames_text(await _frames())])
	st._toggle_network()

	var weeks := 25
	while st.game.over == "" and st.game.week < 40:
		var t := Time.get_ticks_msec()
		bot._act(st.game)
		st.game.end_week()
		st._refresh()
		week_ms += Time.get_ticks_msec() - t
		weeks += 1
		st._show_journal()
		await process_frame
		st._close_card()
		st._toggle_network()
		await process_frame
		st._toggle_network()
		await process_frame
	st.game.pending.clear()
	st._close_card()
	st._refresh()
	for i in 30:
		await process_frame
	var mem_end := _mem()
	print("PERF week%d over=%s %s" % [st.game.week, st.game.over, _mem_text(mem_end)])
	print("PERF growth static %+.1f MB, objects %+d, nodes %+d, orphans %d" % [
		(mem_end.static - mem_w1.static) / 1048576.0, mem_end.objects - mem_w1.objects, mem_end.nodes - mem_w1.nodes, mem_end.orphans])
	print("PERF end_week_avg_ms %.1f over %d weeks (sim + UI refresh)" % [float(week_ms) / float(maxi(1, st.game.week - 1)), st.game.week - 1])
	for i in 20:
		st._show_journal()
		await process_frame
		st._close_card()
		st._toggle_network()
		await process_frame
		st._toggle_network()
		st._refresh()
		await process_frame
	for i in 30:
		await process_frame
	var mem_idle := _mem()
	print("PERF after 20 journal/map opens without play: objects %+d, nodes %+d, orphans %d" % [mem_idle.objects - mem_end.objects, mem_idle.nodes - mem_end.nodes, mem_idle.orphans])

	var saves: Array = []
	var loads: Array = []
	for i in 10:
		var t := Time.get_ticks_usec()
		SaveGame.write_manual(st.game)
		saves.append(Time.get_ticks_usec() - t)
		var other := Game.new()
		other.setup(st.game.catalog, 1, 40)
		t = Time.get_ticks_usec()
		var ok := SaveGame.load_manual(other)
		loads.append(Time.get_ticks_usec() - t)
		if not ok:
			print("PERF load FAILED ", SaveGame.last_error)
	var bytes := FileAccess.get_file_as_bytes(SaveGame.manual_path()).size()
	print("PERF save_ms median %.1f max %.1f, load_ms median %.1f max %.1f, file %d KB" % [
		_median(saves) / 1000.0, float(saves.max()) / 1000.0, _median(loads) / 1000.0, float(loads.max()) / 1000.0, bytes / 1024])
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	quit(0)


func _frames() -> Array:
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(now - last)
		last = now
	return times


func _frames_text(times: Array) -> String:
	var sorted := times.duplicate()
	sorted.sort()
	var total := 0
	for t in times:
		total += int(t)
	var avg := float(total) / float(times.size()) / 1000.0
	return "frame avg %.2f ms (%.0f fps) p95 %.2f ms max %.2f ms" % [avg, 1000.0 / maxf(avg, 0.001), float(sorted[int(sorted.size() * 0.95)]) / 1000.0, float(sorted[sorted.size() - 1]) / 1000.0]


func _mem() -> Dictionary:
	return {
		"static": float(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"video": float(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"textures": float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _mem_text(m: Dictionary) -> String:
	return "static %.1f MB, video %.1f MB (textures %.1f MB), objects %d, nodes %d, orphan nodes %d" % [
		m.static / 1048576.0, m.video / 1048576.0, m.textures / 1048576.0, m.objects, m.nodes, m.orphans]


func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
