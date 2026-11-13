extends SceneTree

## UI feedback for the "nothing happened" clicks. Presentation only.
##   godot --headless --path . --user-data-dir /tmp/underline-ui-feedback -s res://sim/check_ui_feedback.gd
## Asserts U1 scroll and padding at 1920x1080 and at 125%, U2's toast with no footer write,
## U5's waiting toast with End turn staying disabled, and U6's 4px drag threshold.

const SCRATCH := "user://check_ui_feedback"
const WAITING := "Someone is still waiting. Choose before the week ends."

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
	Settings.resume = false
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	if Game.SAVE_SCHEMA != 27:
		_bad("SAVE_SCHEMA %s" % str(Game.SAVE_SCHEMA))
	_keys()
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
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
	Settings.reduce_motion = true
	await _view(st, Vector2i(1920, 1080), 1.0)
	Copy.set_lang("en")
	await _u1(st, "1920")
	await _view(st, Vector2i(1920, 1080), 1.25)
	await _u1(st, "125")
	await _view(st, Vector2i(1920, 1080), 1.0)
	Copy.set_lang("en")
	await _u2(st)
	await _u5(st)
	_u6()
	await _u3(st)
	await _u4(st)
	_u7(st)
	await _u8(st)
	_u9(st)
	_u10(st)
	if is_instance_valid(st):
		st.free()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Copy.set_lang("en")
	if bad.is_empty():
		print("UI FEEDBACK OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("UI FEEDBACK FAILED")
	quit(1)


func _keys() -> void:
	var keys := ["Saved.", WAITING, "Up", "Down", "Push"]
	for code in ["en", "ru"]:
		Copy.set_lang(code)
		for key in keys:
			var got := Copy.t(key)
			if got == "" or (code == "ru" and got == key):
				_bad("Copy.t missing %s [%s]" % [code, key])


func _u1(st, tag: String) -> void:
	_home(st)
	var uid := _last_power(st)
	if uid == "":
		_bad("U1 %s no power room" % tag)
		return
	st.cutplan_room = ""
	st._show_power()
	for _i in 4:
		await process_frame
	var compare := _meta_button(st.card_body, "cutplan_compare", uid)
	if compare == null:
		_bad("U1 %s compare missing" % tag)
		return
	st.card_click_guard = 0
	compare.pressed.emit()
	for _i in 16:
		await process_frame
	var pad := _meta_control(st.card_body, "power_pad")
	if pad == null or absf(pad.custom_minimum_size.y - 8.0) > 0.1:
		_bad("U1 %s pad %s" % [tag, pad.custom_minimum_size.y if pad != null else "missing"])
	elif st.card_body.get_child(st.card_body.get_child_count() - 1) != pad:
		_bad("U1 %s pad is not under the last row" % tag)
	var bar: VScrollBar = st.card_scroll.get_v_scroll_bar()
	if bar == null or bar.modulate.a < 0.9:
		_bad("U1 %s scrollbar hidden" % tag)
	var content := maxf(st.card_body.size.y, st.card_body.get_combined_minimum_size().y)
	var view: float = st.card_scroll.size.y
	if content > view + 1.0 and st.card_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_ALWAYS:
		_bad("U1 %s scrollbar not kept visible" % tag)
	var block := _meta_control(st.card_body, "cutplan_panel")
	if block == null:
		_bad("U1 %s compare block missing" % tag)
	else:
		var view_rect: Rect2 = st.card_scroll.get_global_rect()
		var block_rect: Rect2 = block.get_global_rect()
		var block_h := maxf(block.size.y, block.get_combined_minimum_size().y)
		if block_h + 8.0 <= view + 1.0:
			if block_rect.position.y < view_rect.position.y - 2.0 or block_rect.end.y > view_rect.end.y - 6.0:
				_bad("U1 %s block not inside with 8px (%s view %s)" % [tag, block_rect, view_rect])
		elif block_rect.position.y < view_rect.position.y - 2.0 or block_rect.position.y > view_rect.end.y - 8.0:
			_bad("U1 %s tall block top not in view (%s view %s)" % [tag, block_rect, view_rect])
	_buttons_clear_of_edge(st, "U1 " + tag)
	print("U1 %s scroll %d view %.0f content %.0f" % [tag, int(st.card_scroll.scroll_vertical), view, content])
	st._close_card()
	for _i in 2:
		await process_frame


func _buttons_clear_of_edge(st, tag: String) -> void:
	var edge: float = st.card_scroll.get_global_rect().end.y
	var stack: Array = [st.card_body]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and (here as CanvasItem).visible:
			var rect := (here as Control).get_global_rect()
			if rect.size.y > 4.0 and rect.position.y + 2.0 < edge and edge < rect.end.y - 2.0:
				_bad("%s button row cut at the card edge %s" % [tag, (here as Button).text])
				return
		for child in here.get_children():
			stack.append(child)


func _u2(st) -> void:
	_home(st)
	st.footer.text = ""
	st.footer.visible = false
	var before := int(Sound.last_ms.get("confirm", -1))
	st._manual_save()
	for _i in 2:
		await process_frame
	if st.toast_label == null or not st.toast_label.visible or st.toast_label.text != Copy.t("Saved."):
		_bad("U2 toast [%s]" % (st.toast_label.text if st.toast_label != null else "missing"))
	if st.footer.text == Copy.t("Saved.") or (st.footer.visible and st.footer.text.find("Saved") >= 0):
		_bad("U2 wrote the footer [%s]" % st.footer.text)
	if Sound.players.has("confirm") and int(Sound.last_ms.get("confirm", -1)) < before:
		_bad("U2 confirm sound missing")
	print("U2 toast ok footer [%s]" % st.footer.text)


func _u5(st) -> void:
	_home(st)
	var ev := _major(st.game)
	if ev.is_empty():
		_bad("U5 no major event")
		return
	st.game.pending.clear()
	st.game.week_event_ids = {}
	if not st.game._present_event(ev):
		_bad("U5 present failed")
		return
	st._sync_waiting()
	if not st.end_button.disabled or st._end_state() != "waiting":
		_bad("U5 end turn was not waiting")
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var before := int(Sound.last_ms.get("error", -1))
	st._end_cover_input(click)
	for _i in 3:
		await process_frame
	if st.end_button.disabled == false or st._end_state() != "waiting":
		_bad("U5 enabled End turn")
	if st.toast_label == null or st.toast_label.text != Copy.t(WAITING):
		_bad("U5 toast [%s]" % (st.toast_label.text if st.toast_label != null else "missing"))
	if Sound.players.has("error") and int(Sound.last_ms.get("error", -1)) < before:
		_bad("U5 error sound missing")
	print("U5 toast ok disabled %s" % st.end_button.disabled)
	st.game.pending.clear()
	st._close_card()
	for _i in 2:
		await process_frame


func _u6() -> void:
	var net = load("res://ui/network_view.gd").new()
	root.add_child(net)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(120, 80)
	net._gui_input(press)
	if net._drag:
		_bad("U6 empty press started a drag")
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(float(net.DRAG_SLOP), 0)
	motion.relative = Vector2(float(net.DRAG_SLOP), 0)
	net._gui_input(motion)
	if net._drag:
		_bad("U6 4px started a drag")
	motion.position = press.position + Vector2(float(net.DRAG_SLOP) + 0.5, 0)
	motion.relative = Vector2(0.5, 0)
	net._gui_input(motion)
	if not net._drag:
		_bad("U6 movement past 4px did not drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	net._gui_input(release)
	press.position = Vector2(40, 40)
	net._gui_input(press)
	release.position = press.position
	net._gui_input(release)
	if net._drag:
		_bad("U6 a click with no hit captured a drag")
	net.free()
	print("U6 4px threshold ok")


func _u3(st) -> void:
	_home(st)
	st.cutplan_room = ""
	st._show_power()
	for _i in 6:
		await process_frame
	var order: Array = st.game.power_order
	if order.size() < 2:
		_bad("U3 short order")
		return
	var first_up := _dir(st, str(order[0]), "up")
	var last_down := _dir(st, str(order[order.size() - 1]), "down")
	var mid_up := _dir(st, str(order[1]), "up")
	if not _is_lock(first_up) or not _is_lock(last_down):
		_bad("U3 illegal Up/Down is not locked")
	if mid_up == null or mid_up.disabled or mid_up.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		_bad("U3 a legal Up was locked")
	st._close_card()
	for _i in 2:
		await process_frame


func _u4(st) -> void:
	_home(st)
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "quarters":
			uid = str(room.uid)
	if uid == "":
		_bad("U4 no quarters")
		return
	st._show_room(uid)
	for _i in 6:
		await process_frame
	var push := _button_text(st.card_body, Copy.t("Push"))
	if not _is_lock(push):
		_bad("U4 Push is not locked")
	var labeled := false
	var stack: Array = [st.card_body]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Label and str((here as Label).text).find(Copy.t("This room cannot be pushed.")) >= 0:
			labeled = true
		for child in here.get_children():
			stack.append(child)
	if not labeled:
		_bad("U4 reason label missing")
	st._close_card()
	for _i in 2:
		await process_frame


func _u7(st) -> void:
	_home(st)
	var pid := ""
	for person in st.game.residents:
		pid = str(person.get("id", ""))
		if pid != "":
			break
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "platform":
			uid = str(room.uid)
	var info: Dictionary = st.game.assign_preview(pid, uid)
	if pid == "" or uid == "" or bool(info.get("ok", false)) or str(info.get("reason", "")) == "":
		_bad("U7 no refused drop")
		return
	st._drop_person(pid, uid)
	if st.toast_label == null or st.toast_label.text != str(info.reason):
		_bad("U7 toast [%s]" % (st.toast_label.text if st.toast_label != null else "missing"))
	else:
		print("U7 toast ok")


func _u8(st) -> void:
	_home(st)
	var ev := _major(st.game)
	st.game.pending.clear()
	st.game.week_event_ids = {}
	st.game.audience = {}
	st.game.order_reports = []
	if not st.game._present_event(ev):
		_bad("U8 present failed")
		return
	st._show_dawn()
	for _i in 4:
		await process_frame
	if not st.showing_network:
		st._toggle_network()
	for _i in 2:
		await process_frame
	if not st.dim.visible or not st.showing_network:
		_bad("U8 card or map missing")
		return
	if st.network_view.z_index + 40 >= st.dim.z_index:
		_bad("U8 map z %s is not under dim %s" % [st.network_view.z_index, st.dim.z_index])
	if st.network_view.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_bad("U8 map still takes clicks")
	st.game.pending.clear()
	st._close_card()
	for _i in 3:
		await process_frame
	if st.dim.visible:
		_bad("U8 dim stayed up")
	if st.network_view.z_index != 0 or st.network_view.mouse_filter != Control.MOUSE_FILTER_STOP:
		_bad("U8 map was not restored")
	else:
		print("U8 map under dim")
	if st.showing_network:
		st._toggle_network()


func _u9(st) -> void:
	var runs := [0]
	st.on_paper = true
	var button: Button = st._button("Close", func() -> void: runs[0] += 1)
	st.add_child(button)
	st.card_click_guard = 0
	button.pressed.emit()
	button.pressed.emit()
	if runs[0] != 1:
		_bad("U9 double press ran %d" % runs[0])
	Sound.last_ms.erase("click")
	st.card_click_guard = Time.get_ticks_msec() + 5000
	button.pressed.emit()
	if runs[0] != 1:
		_bad("U9 guard ran the action")
	if Sound.players.has("click") and not Sound.last_ms.has("click"):
		_bad("U9 guard played no click")
	else:
		print("U9 guard click ok")
	button.free()


func _u10(st) -> void:
	_home(st)
	st.game.week = 1
	st.guide_played = false
	st.net_guide = false
	st._start_guide()
	if st.guide_step != 0 or st.guide_layer == null or not st.guide_layer.visible:
		_bad("U10 guide did not start")
		return
	st.game.week = 3
	st._retire_early_guide()
	if st.guide_step >= 0 or (st.guide_layer != null and st.guide_layer.visible):
		_bad("U10 stocks coach still up at week 3")
	else:
		print("U10 coach hidden")
	st.game.week = 1


func _home(st) -> void:
	if st.showing_network:
		st._toggle_network()
	st.game.pending.clear()
	if st.dim != null and st.dim.visible:
		st._close_card()
	st.at_menu = false


func _last_power(st) -> String:
	if st.game.power_order.is_empty():
		return ""
	return str(st.game.power_order[st.game.power_order.size() - 1])


func _major(game) -> Dictionary:
	for ev in game.catalog.events:
		if bool(ev.get("major", false)) and not ev.has("needs") and not ev.has("trigger"):
			return ev
	return {}


func _is_lock(button: Button) -> bool:
	if button == null or not button.disabled or button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	if button.modulate.a > 0.55:
		return false
	for child in button.get_children():
		if str(child.get("kind")) == "lock":
			return true
	return false


func _dir(st, uid: String, dir: String) -> Button:
	return _meta_button2(st.card_body, "power_dir", dir, "power_uid", uid)


func _view(st, win_size: Vector2i, scale: float) -> void:
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
	print("VIEW scale %.2f viewport %s station %s" % [st.get_window().content_scale_factor, st.get_viewport_rect().size, st.size])


func _meta_button(node: Node, key: String, value) -> Button:
	return _meta_button2(node, key, value, "", null)


func _meta_button2(node: Node, key: String, value, key2: String, value2) -> Button:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and here.has_meta(key) and here.get_meta(key) == value:
			if key2 == "" or (here.has_meta(key2) and here.get_meta(key2) == value2):
				return here
		for child in here.get_children():
			stack.append(child)
	return null


func _meta_control(node: Node, key: String) -> Control:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Control and here.has_meta(key):
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _button_text(node: Node, text: String) -> Button:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and str((here as Button).text) == text:
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _bad(line: String) -> void:
	bad.append(line)


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir():
			_wipe(sub)
			dir.remove(name)
		else:
			dir.remove(name)
		name = dir.get_next()
