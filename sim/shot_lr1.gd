extends SceneTree

## Before/after stills for LR1. Not a gate.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://sim/shot_lr1.gd -- --tag=before

const SCRATCH := "user://shot_lr1"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tag := "after"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--tag="):
			tag = str(arg).trim_prefix("--tag=")
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = false
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	Settings.save()
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.motion_in_shots = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	var pairs := _name_pairs()
	var planted := _plant_names(st, pairs)
	print("PLANTED %d residents, idle %d" % [planted, st.yard._idle_ids().size()])
	for scale_name in ["100", "125"]:
		var scale := 1.0 if scale_name == "100" else 1.25
		await _apply_view(st, Vector2i(1920, 1080), scale)
		for lang in ["en", "ru"]:
			Copy.set_lang(lang)
			_clear_floats(st)
			st.yard.queue_redraw()
			for _i in 2:
				await process_frame
			RenderingServer.force_draw()
			await _save(st, "lr1_%s_names_%s_%s.png" % [tag, lang, scale_name], _platform_rect(st))
			_show_pair(st)
			for _i in 2:
				await process_frame
			RenderingServer.force_draw()
			var salvage: Rect2 = _node_rect(st.salvage_float)
			var obs: Rect2 = _node_rect(st.obs_float)
			print("FLOATS %s %s %s salvage %s obs %s overlap %s" % [tag, lang, scale_name, salvage, obs, _overlap(salvage, obs)])
			await _save(st, "lr1_%s_floats_%s_%s.png" % [tag, lang, scale_name], salvage.merge(obs).grow(28.0))
			if scale_name == "100" and lang == "en":
				await _save(st, "lr1_%s_full_en_100.png" % tag, Rect2())
	_clear_floats(st)
	Settings.reduce_motion = true
	Settings.loaded = true
	st.motion_in_shots = false
	Copy.set_lang("en")
	await _apply_view(st, Vector2i(1920, 1080), 1.0)
	st.yard.queue_redraw()
	for _i in 2:
		await process_frame
	RenderingServer.force_draw()
	await _save(st, "lr1_%s_reduce_motion_en_100.png" % tag, Rect2())
	_clear_floats(st)
	if is_instance_valid(st):
		st.free()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	print("SHOT LR1 DONE %s" % tag)
	quit(0)


func _show_pair(st) -> void:
	var line := Copy.fill("salvage.fitted", {"name": Copy.t("salvage.node.grow_lamps")})
	st._yard_float(line, "")
	st._show_obs_float(Copy.t("obs.first_mark"))


func _platform_rect(st) -> Rect2:
	for room in st.game.rooms:
		if str(room.get("type", "")) != "platform":
			continue
		return st.yard.cell_screen(int(room.level), int(room.cell)).grow(8.0)
	return Rect2()


func _node_rect(node) -> Rect2:
	if node == null or not is_instance_valid(node) or not node.visible:
		return Rect2()
	return node.get_global_rect()


func _overlap(a: Rect2, b: Rect2) -> bool:
	if a.size.x < 1.0 or b.size.x < 1.0 or not a.intersects(b):
		return false
	var overlap := a.intersection(b)
	return overlap.size.x > 1.0 and overlap.size.y > 1.0


func _apply_view(st, win_size: Vector2i, scale: float) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	Settings.loaded = true
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	if absf(scale - 1.0) < 0.01:
		win.content_scale_factor = 1.0
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_size = win_size
	else:
		Settings.apply_scale(win)
	st._layout()
	for _i in 4:
		await process_frame


func _save(st, file_name: String, crop: Rect2) -> void:
	var tex: ViewportTexture = st.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.get_width() < 2:
		print("SHOT MISS %s" % file_name)
		return
	var view: Vector2 = st.get_viewport().get_visible_rect().size
	if crop.size.x > 2.0 and crop.size.y > 2.0:
		var sx := float(img.get_width()) / maxf(view.x, 1.0)
		var sy := float(img.get_height()) / maxf(view.y, 1.0)
		var origin := Vector2i(maxi(0, int(floor(crop.position.x * sx))), maxi(0, int(floor(crop.position.y * sy))))
		var extent := Vector2i(mini(img.get_width() - origin.x, int(ceil(crop.size.x * sx))), mini(img.get_height() - origin.y, int(ceil(crop.size.y * sy))))
		if extent.x > 2 and extent.y > 2:
			img = img.get_region(Rect2i(origin, extent))
	var path := "/opt/cursor/artifacts".path_join(file_name)
	var err := img.save_png(path)
	print("SHOT %s %dx%d err %s" % [path, img.get_width(), img.get_height(), err])


func _name_pairs() -> Array:
	var file := FileAccess.open("res://data/names.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	var pairs: Array = []
	for first in data.first:
		for last in data.last:
			var en := "%s %s" % [str(first), str(last)]
			Copy.set_lang("ru")
			var ru := Copy.person(en)
			Copy.set_lang("en")
			pairs.append({"en": en, "ru": ru, "rank": maxi(en.length(), ru.length())})
	pairs.sort_custom(func(a, b): return int(a.rank) > int(b.rank))
	return pairs.slice(0, 6)


func _plant_names(st, pairs: Array) -> int:
	var game = st.game
	for room in game.rooms:
		room.staff.clear()
	if typeof(game.dig) == TYPE_DICTIONARY and not game.dig.is_empty():
		game.dig["workers"] = []
	if typeof(game.build) == TYPE_DICTIONARY and not game.build.is_empty():
		game.build["workers"] = []
	var n := 0
	for person in game.residents:
		if n >= pairs.size():
			break
		if int(person.get("absent", 0)) > 0:
			person.absent = 0
		person.name = str(pairs[n].en)
		person.name_ru = str(pairs[n].ru)
		person.memory = 80
		n += 1
	return n


func _clear_floats(st) -> void:
	if st.obs_float_tween != null and is_instance_valid(st.obs_float_tween) and st.obs_float_tween.is_valid():
		st.obs_float_tween.kill()
	if st.home_float_tween != null and is_instance_valid(st.home_float_tween) and st.home_float_tween.is_valid():
		st.home_float_tween.kill()
	for key in ["salvage_float", "obs_float", "home_float"]:
		var node = st.get(key)
		if node != null and is_instance_valid(node):
			node.visible = false
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
		st.set(key, null)


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir() and name != "." and name != "..":
			_wipe(sub)
			dir.remove(name)
		elif name != "." and name != "..":
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
