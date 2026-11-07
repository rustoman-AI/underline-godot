extends SceneTree

## Epilogue pages keep Next / Back / Close on the card. Yard notices stay horizontal.
## EN and RU, at the 1920×1080 window (100%) and the 1536×864 logical window (125%).
##   godot --headless --path . -s res://sim/check_notice_layout.gd

const SCRATCH := "user://check_notice_layout"

var bad: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = true
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 6:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	await _case(st, Vector2i(1920, 1080), 1.0, "100")
	await _case(st, Vector2i(1536, 864), 1.0, "125")
	await _case(st, Vector2i(1920, 1080), 1.25, "125scale")
	_clear_yards(st)
	if is_instance_valid(st):
		st.free()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Copy.set_lang("en")
	if bad.is_empty():
		print("NOTICE LAYOUT OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("NOTICE LAYOUT FAILED")
	quit(1)


func _case(st, win_size: Vector2i, scale: float, tag: String) -> void:
	await _apply_view(st, win_size, scale)
	var view: Vector2 = st.get_viewport_rect().size
	print("VIEW %s window %s scale %.2f viewport %s station %s" % [tag, win_size, st.get_window().content_scale_factor, view, st.size])
	if tag == "100" and (view.x < 1800.0 or view.y < 1000.0):
		_bad("%s viewport %s" % [tag, view])
	if tag == "125" and (absf(view.x - 1536.0) > 2.0 or absf(view.y - 864.0) > 2.0):
		_bad("%s viewport %s" % [tag, view])
	if tag == "125scale" and (st.get_window().content_scale_factor < 1.2 or view.y > 900.0):
		_bad("%s scale %s viewport %s" % [tag, st.get_window().content_scale_factor, view])
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		if _shots() and tag == "100" and lang == "en":
			await _broken_echo(st, "en")
		if _shots() and tag == "100" and lang == "ru":
			await _broken_echo(st, "ru")
		await _yards(st, "%s %s" % [tag, lang], view)
		await _epilogue(st, "%s %s" % [tag, lang], view)


func _apply_view(st, win_size: Vector2i, scale: float) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	if absf(scale - 1.0) < 0.01:
		win.content_scale_factor = 1.0
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_size = win_size
	else:
		Settings.apply_scale(win)
	for _i in 4:
		await process_frame


func _yards(st, tag: String, view: Vector2) -> void:
	_clear_yards(st)
	var lines := {
		"regular": Copy.t("regular.first"),
		"sday": Copy.t("sday.first"),
		"carry": Copy.t("carry.first"),
		"echo": Copy.t("echo.first"),
		"rival": Copy.t("rival.first"),
		"caller": Copy.t("caller.first"),
		"scar": Copy.t("scar.first"),
	}
	st._show_regular_yard(lines.regular)
	st._show_sday_yard(lines.sday)
	st._show_carry_yard(lines.carry)
	st._show_echo_yard(lines.echo)
	for _i in 3:
		await process_frame
	var plates: Array[Control] = []
	for key in ["regular", "sday", "carry", "echo"]:
		var plate: PanelContainer = st.get(key + "_float")
		var lab: Label = st.get(key + "_float_label")
		if plate == null or lab == null or not plate.visible:
			_bad("%s %s missing" % [tag, key])
			continue
		if str(lab.text) != str(lines[key]):
			_bad("%s %s text [%s]" % [tag, key, lab.text])
		_notice(tag + " " + key, plate, lab, view)
		plates.append(plate)
	if plates.size() == 4:
		var top: Rect2 = plates[0].get_global_rect()
		var mid: Rect2 = plates[1].get_global_rect()
		var bot: Rect2 = plates[2].get_global_rect()
		var echo: Rect2 = plates[3].get_global_rect()
		if _hits(top, mid) or _hits(mid, bot) or _hits(top, bot) or _hits(bot, echo) or _hits(mid, echo):
			_bad("%s notices overlap %s | %s | %s | %s" % [tag, top, mid, bot, echo])
		if mid.position.y < top.end.y - 1.0 or bot.position.y < mid.end.y - 1.0 or echo.position.y < bot.end.y - 1.0:
			_bad("%s notice stack %s %s %s %s" % [tag, top, mid, bot, echo])
		st._show_rival_yard(lines.rival)
		for _i in 2:
			await process_frame
		var rival_plate: PanelContainer = st.rival_float
		var rival_lab: Label = st.rival_float_label
		echo = st.echo_float.get_global_rect()
		bot = st.carry_float.get_global_rect()
		if rival_plate == null or rival_lab == null or str(rival_lab.text) != lines.rival:
			_bad("%s rival missing" % tag)
		else:
			_notice(tag + " rival", rival_plate, rival_lab, view)
			var rival_rect := rival_plate.get_global_rect()
			if _hits(echo, rival_rect) or _hits(bot, rival_rect) or rival_rect.position.y < echo.end.y - 1.0:
				_bad("%s rival overlap %s echo %s" % [tag, rival_rect, echo])
			var again_lines := rival_lab.get_line_count()
			st._show_rival_yard(lines.rival)
			for _i in 2:
				await process_frame
			rival_plate = st.rival_float
			rival_lab = st.rival_float_label
			if rival_plate == null or rival_lab == null or str(rival_lab.text) != lines.rival:
				_bad("%s rival second show" % tag)
			elif rival_plate.size.x < rival_plate.size.y * 2.0 or rival_lab.get_line_count() > 3 or rival_lab.get_line_count() < 1:
				_bad("%s rival slab %s lines %d" % [tag, rival_plate.size, rival_lab.get_line_count()])
			elif again_lines > 3:
				_bad("%s rival first show stacked %d" % [tag, again_lines])
			st._show_caller_yard(lines.caller)
			for _i in 2:
				await process_frame
			var caller_plate: PanelContainer = st.caller_float
			var caller_lab: Label = st.caller_float_label
			rival_rect = st.rival_float.get_global_rect()
			if caller_plate == null or caller_lab == null or str(caller_lab.text) != lines.caller:
				_bad("%s caller missing" % tag)
			else:
				_notice(tag + " caller", caller_plate, caller_lab, view)
				var caller_rect := caller_plate.get_global_rect()
				if _hits(rival_rect, caller_rect) or caller_rect.position.y < rival_rect.end.y - 1.0:
					_bad("%s caller overlap %s rival %s" % [tag, caller_rect, rival_rect])
				st._show_caller_yard(lines.caller)
				for _i in 2:
					await process_frame
				if st.caller_float == null or st.caller_float.size.x < st.caller_float.size.y * 2.0 or st.caller_float_label.get_line_count() > 3:
					_bad("%s caller second show %s" % [tag, st.caller_float.size if st.caller_float != null else "null"])
				st._show_scar_yard(lines.scar)
				for _i in 2:
					await process_frame
				var scar_plate: PanelContainer = st.scar_float
				var scar_lab: Label = st.scar_float_label
				caller_rect = st.caller_float.get_global_rect()
				if scar_plate == null or scar_lab == null or str(scar_lab.text) != lines.scar:
					_bad("%s scar missing" % tag)
				else:
					_notice(tag + " scar", scar_plate, scar_lab, view)
					var scar_rect := scar_plate.get_global_rect()
					if _hits(caller_rect, scar_rect) or scar_rect.position.y < caller_rect.end.y - 1.0:
						_bad("%s scar overlap %s caller %s" % [tag, scar_rect, caller_rect])
					st._show_scar_yard(lines.scar)
					for _i in 2:
						await process_frame
					if st.scar_float == null or st.scar_float.size.x < st.scar_float.size.y * 2.0 or st.scar_float_label.get_line_count() > 3:
						_bad("%s scar second show %s" % [tag, st.scar_float.size if st.scar_float != null else "null"])
			if not await _reverse_stack(st, tag, lines, view):
				return
			if tag.begins_with("100 ") or tag.begins_with("125 "):
				await _save_shot(st, "/opt/cursor/artifacts/p94_yard_stack_%s_%s.png" % ["ru" if tag.ends_with("ru") else "en", "125" if tag.begins_with("125") else "100"])
			if _shots() or OS.get_cmdline_user_args().has("--rival-shots"):
				if tag.begins_with("100 ") or tag.begins_with("125 "):
					var lang := "ru" if tag.ends_with("ru") else "en"
					var size := "125" if tag.begins_with("125") else "100"
					await _save_shot(st, "/opt/cursor/artifacts/p93_yard_mixed_%s_%s.png" % [lang, size])
	if _shots() and (tag.begins_with("100 ") or tag.begins_with("125 ")):
		await _shot_yards(st, tag)
	_clear_yards(st)


func _notice(tag: String, plate: Control, lab: Label, view: Vector2) -> void:
	var rect: Rect2 = plate.get_global_rect()
	var screen := Rect2(Vector2.ZERO, view)
	if not _fits_rect(rect, screen):
		_bad("%s plate offscreen %s view %s" % [tag, rect, view])
	if plate.size.x < 300.0 or plate.size.x > 520.0 or plate.size.y < 28.0 or plate.size.y > 140.0:
		_bad("%s plate size %s" % [tag, plate.size])
	if plate.size.x < plate.size.y * 2.0:
		_bad("%s plate is a column %s" % [tag, plate.size])
	if lab.size.x < 200.0 or lab.size.y < 16.0 or lab.size.y > 96.0 or lab.size.x < lab.size.y * 2.0:
		_bad("%s line size %s" % [tag, lab.size])
	if lab.get_line_count() < 1 or lab.get_line_count() > 3:
		_bad("%s lines %d [%s]" % [tag, lab.get_line_count(), lab.text])
	if int(lab.get_theme_font_size("font_size")) != 18:
		_bad("%s font %s" % [tag, lab.get_theme_font_size("font_size")])
	if lab.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
		_bad("%s wrap off" % tag)


func _epilogue(st, tag: String, view: Vector2) -> void:
	_stage(st)
	st.life_epilogue_page = 0
	st._show_life_epilogue()
	for _i in 3:
		await process_frame
	var heights: Array[float] = []
	if not await _page(st, tag, 0, view, heights):
		st._close_life_epilogue()
		return
	if not _press(st, "epilogue.next"):
		_bad("%s missing next" % tag)
		st._close_life_epilogue()
		return
	for _i in 2:
		await process_frame
	if not await _page(st, tag, 1, view, heights):
		st._close_life_epilogue()
		return
	if not _press(st, "epilogue.next"):
		_bad("%s missing second next" % tag)
		st._close_life_epilogue()
		return
	for _i in 2:
		await process_frame
	if not await _page(st, tag, 2, view, heights):
		st._close_life_epilogue()
		return
	if not _press(st, "epilogue.back"):
		_bad("%s missing back" % tag)
		st._close_life_epilogue()
		return
	for _i in 2:
		await process_frame
	if not await _page(st, tag, 1, view, heights):
		st._close_life_epilogue()
		return
	if not _press(st, "epilogue.back"):
		_bad("%s missing second back" % tag)
		st._close_life_epilogue()
		return
	for _i in 2:
		await process_frame
	if not await _page(st, tag, 0, view, heights):
		st._close_life_epilogue()
		return
	if heights.size() >= 2 and absf(heights[heights.size() - 1] - heights[0]) > 1.0:
		_bad("%s page 0 grew %s" % [tag, heights])
	_tap(st, KEY_RIGHT)
	for _i in 2:
		await process_frame
	_tap(st, KEY_RIGHT)
	for _i in 2:
		await process_frame
	if int(st.life_epilogue_page) != 2:
		_bad("%s keys landed on %s" % [tag, st.life_epilogue_page])
	else:
		await _page(st, tag + " keys", 2, view, heights)
	_tap(st, KEY_LEFT)
	for _i in 2:
		await process_frame
	_tap(st, KEY_LEFT)
	for _i in 2:
		await process_frame
	if int(st.life_epilogue_page) != 0:
		_bad("%s back keys landed on %s" % [tag, st.life_epilogue_page])
	if not _press(st, "epilogue.next"):
		_bad("%s relayout next missing" % tag)
	for _i in 2:
		await process_frame
	if not _press(st, "epilogue.next"):
		_bad("%s relayout next missing" % tag)
	for _i in 2:
		await process_frame
	var again: float = st.life_epilogue_panel.size.y
	if heights.size() >= 3 and absf(again - heights[2]) > 1.0:
		_bad("%s page 2 grew %s -> %s" % [tag, heights[2], again])
	if not _press(st, "epilogue.close"):
		_bad("%s missing close" % tag)
	for _i in 2:
		await process_frame
	if st.life_epilogue != null and st.life_epilogue.visible:
		_bad("%s close left the card up" % tag)
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	st._show_life_epilogue()
	for _i in 2:
		await process_frame
	_tap(st, KEY_ESCAPE)
	for _i in 2:
		await process_frame
	if st.life_epilogue != null and st.life_epilogue.visible:
		_bad("%s escape left the card up" % tag)
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false


func _page(st, tag: String, page: int, view: Vector2, heights: Array[float]) -> bool:
	if st.life_epilogue == null or not st.life_epilogue.visible:
		_bad("%s page %d hidden" % [tag, page])
		return false
	if int(st.life_epilogue_page) != page:
		_bad("%s page is %s want %d" % [tag, st.life_epilogue_page, page])
		return false
	var panel: Control = st.life_epilogue_panel
	var screen := Rect2(Vector2.ZERO, view)
	var bounds: Vector2 = st._epilogue_bounds()
	if absf(panel.size.x - bounds.x) > 1.0 or absf(panel.size.y - bounds.y) > 1.0:
		_bad("%s page %d panel %s bounds %s" % [tag, page, panel.size, bounds])
		return false
	if panel.size.y > 640.0 or panel.size.x > 700.0:
		_bad("%s page %d unbounded %s" % [tag, page, panel.size])
		return false
	var panel_rect: Rect2 = panel.get_global_rect()
	if not _fits_rect(panel_rect, screen):
		_bad("%s page %d panel offscreen %s" % [tag, page, panel_rect])
		return false
	heights.append(panel.size.y)
	var keys: PackedStringArray = []
	if page == 0:
		keys = PackedStringArray(["epilogue.next"])
	elif page == 1:
		keys = PackedStringArray(["epilogue.back", "epilogue.next"])
	else:
		keys = PackedStringArray(["epilogue.back", "epilogue.close"])
	for key in keys:
		var button := _find(st, key)
		if button == null:
			_bad("%s page %d no %s" % [tag, page, key])
			return false
		var rect: Rect2 = button.get_global_rect()
		if not _fits_rect(rect, screen):
			_bad("%s page %d %s offscreen %s" % [tag, page, key, rect])
			return false
		if not _fits_rect(rect, panel_rect.grow(2.0)):
			_bad("%s page %d %s outside the card %s card %s" % [tag, page, key, rect, panel_rect])
			return false
	if not _lines_fit(st, "%s page %d" % [tag, page]):
		return false
	var dots: Control = st.life_epilogue_dots
	if dots != null:
		var dot_rect := Rect2(dots.global_position, dots.get_combined_minimum_size())
		if dot_rect.size.x < 40.0 or not _fits_rect(dot_rect, screen):
			_bad("%s page %d dots %s" % [tag, page, dot_rect])
			return false
	return true


func _lines_fit(st, tag: String) -> bool:
	var seen := 0
	for child in st.life_epilogue_body.get_children():
		if not (child is Label):
			continue
		var lab: Label = child
		seen += 1
		if lab.size.x < 200.0 or lab.get_line_count() > 6 or lab.size.y > lab.size.x:
			_bad("%s copy [%s] size %s lines %d" % [tag, lab.text.substr(0, 42), lab.size, lab.get_line_count()])
			return false
	if seen < 1:
		_bad("%s has no copy" % tag)
		return false
	return true


func _find(st, key: String) -> Button:
	var want := Copy.t(key)
	if st.life_epilogue_actions == null:
		return null
	for child in st.life_epilogue_actions.get_children():
		if child is Button and str((child as Button).text).find(want) >= 0:
			return child
	return null


func _press(st, key: String) -> bool:
	var button := _find(st, key)
	if button == null:
		return false
	button.pressed.emit()
	return true


func _tap(st, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.physical_keycode = code
	st._life_epilogue_input(ev)


func _stage(st) -> void:
	var game = st.game
	game.chronicle.clear()
	game.creed = "watch"
	game.over = ""
	var beats := [
		[38, "named_death", {"name": "Rhee", "cause": "cough"}, 5],
		[32, "creed_line", {"law": "sealed the sick"}, 5],
		[28, "station_taken", {"place": "Coney Island"}, 3],
		[22, "dilemma", {"title": "The Gate", "choice": "turn away"}, 3],
		[16, "season", {"season": "cold"}, 2],
		[10, "creed_chosen", {"creed": "Watch"}, 2],
		[8, "clear", {}, 1],
	]
	for beat in beats:
		game.week = int(beat[0])
		game._note_moment(str(beat[1]), beat[2], int(beat[3]))
	game.week = 40
	game.stats.named_dead = 1
	game.hope = 40
	game.over = "time"
	game.stats.scored = false


func _shots() -> bool:
	return OS.get_cmdline_user_args().has("--echo-shots")


func _broken_echo(st, lang: String) -> void:
	var plate := PanelContainer.new()
	plate.z_index = 8
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", st._tip_plate_style())
	var lab := Label.new()
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.clip_text = false
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color("efe6d2"))
	lab.add_theme_constant_override("outline_size", 0)
	lab.text = Copy.t("echo.first")
	# No width yet: WORD_SMART shapes one glyph per line. The old plate then
	# kept that column after the label was given 420px.
	lab.custom_minimum_size = Vector2(1, 0)
	lab.size = Vector2(1, 0)
	plate.add_child(lab)
	st.add_child(plate)
	for _i in 2:
		await process_frame
	var stacked: Vector2 = lab.get_combined_minimum_size()
	var y: float = (st.hud.size.y if st.hud != null else 72.0) + 8.0
	plate.custom_minimum_size = Vector2(420, maxf(36.0, stacked.y))
	plate.size = plate.custom_minimum_size
	plate.position = Vector2(maxf(8.0, st.size.x * 0.5 - 210.0), y)
	lab.custom_minimum_size = Vector2(404, stacked.y)
	lab.size = Vector2(404, stacked.y)
	await process_frame
	print("BEFORE %s plate %s line %s lines %d stacked %s" % [lang, plate.size, lab.size, lab.get_line_count(), stacked])
	await _save_shot(st, "/opt/cursor/artifacts/p91_yard_column_before_%s.png" % lang)
	plate.queue_free()
	await process_frame


func _shot_yards(st, tag: String) -> void:
	var lang := "ru" if tag.ends_with("ru") else "en"
	var size := "125" if tag.begins_with("125") else "100"
	await _save_shot(st, "/opt/cursor/artifacts/p91_yard_echo_after_%s_%s.png" % [lang, size])


func _save_shot(st, path: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT skipped " + path)
		return
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = st.get_viewport().get_texture()
	if tex == null:
		print("SHOT miss " + path)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("SHOT empty " + path)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var err: Error = img.save_png(path)
	print("SHOT %s %dx%d err %s" % [path, img.get_width(), img.get_height(), err])


func _reverse_stack(st, tag: String, lines: Dictionary, view: Vector2) -> bool:
	_clear_yards(st)
	st._show_scar_yard(lines.scar)
	st._show_caller_yard(lines.caller)
	st._show_rival_yard(lines.rival)
	st._show_echo_yard(lines.echo)
	st._show_carry_yard(lines.carry)
	st._show_sday_yard(lines.sday)
	st._show_regular_yard(lines.regular)
	st._restack_yard_notices()
	for _i in 2:
		await process_frame
	var order := ["regular", "sday", "carry", "echo", "rival", "caller", "scar"]
	var prev := Rect2()
	var first := true
	for key in order:
		var plate: PanelContainer = st.get(key + "_float")
		var lab: Label = st.get(key + "_float_label")
		if plate == null or lab == null or not plate.visible or str(lab.text) != str(lines[key]):
			_bad("%s reverse %s missing" % [tag, key])
			return false
		_notice(tag + " reverse " + key, plate, lab, view)
		var rect := plate.get_global_rect()
		if not first and (rect.position.y < prev.end.y - 1.0 or _hits(prev, rect)):
			_bad("%s reverse order %s %s then %s" % [tag, key, rect, prev])
			return false
		prev = rect
		first = false
	return true


func _clear_yards(st) -> void:
	for key in ["regular_float", "sday_float", "carry_float", "echo_float", "rival_float", "caller_float", "scar_float"]:
		var tween = st.get(key + "_tween")
		if tween != null and is_instance_valid(tween) and tween.is_valid():
			tween.kill()
		var node = st.get(key)
		if node != null and is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
		st.set(key, null)
		st.set(key + "_label", null)
		st.set(key + "_tween", null)


func _fits_rect(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - 1.0 \
		and rect.position.y >= bounds.position.y - 1.0 \
		and rect.end.x <= bounds.end.x + 1.0 \
		and rect.end.y <= bounds.end.y + 1.0


func _hits(a: Rect2, b: Rect2) -> bool:
	if not a.intersects(b):
		return false
	var overlap: Rect2 = a.intersection(b)
	return overlap.size.x > 1.0 and overlap.size.y > 1.0


func _bad(msg: String) -> void:
	bad.append(msg)


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
