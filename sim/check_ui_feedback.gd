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
	for row in [["en", 1.0, "en 100"], ["en", 1.25, "en 125"], ["ru", 1.0, "ru 100"], ["ru", 1.25, "ru 125"]]:
		Copy.set_lang(str(row[0]))
		await _view(st, Vector2i(1920, 1080), float(row[1]))
		await _u1(st, str(row[2]))
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
	await _e1(st)
	await _e2(st)
	await _e3(st)
	await _e4(st)
	await _e5(st)
	await _e6(st)
	await _hit(st)
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
	var keys := ["Saved.", WAITING, "Up", "Down", "Push", "No saved game.", "push.disabled_room"]
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
	if compare != null:
		st.card_click_guard = 0
		compare.pressed.emit()
	elif tag.begins_with("en"):
		_bad("U1 %s compare missing" % tag)
		return
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
	if content > view + 1.0:
		if st.card_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_ALWAYS:
			_bad("U1 %s scrollbar not kept visible" % tag)
		var wide: float = bar.get_global_rect().size.x if bar != null else 0.0
		if bar == null or not bar.visible or wide < 8.0:
			_bad("U1 %s scrollbar width %.1f visible %s" % [tag, wide, bar.visible if bar != null else false])
		var grab: StyleBox = bar.get_theme_stylebox("grabber") if bar != null else null
		if grab == null:
			_bad("U1 %s scrollbar has no grabber" % tag)
	var block := _meta_control(st.card_body, "cutplan_panel")
	if block == null and tag.begins_with("en"):
		_bad("U1 %s compare block missing" % tag)
	elif block != null:
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
	st.get_viewport().gui_release_focus()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	st.get_viewport().push_input(esc)
	for _i in 2:
		await process_frame
	var owner: Control = st.get_viewport().gui_get_focus_owner()
	if owner == null or st.card == null or not st.card.is_ancestor_of(owner):
		_bad("U8 esc focus %s" % owner)
	elif owner is BaseButton and (owner as BaseButton).disabled:
		_bad("U8 esc focused a disabled control")
	else:
		print("U8 esc focus %s" % owner.name)
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


func _e1(st) -> void:
	_home(st)
	var ev := _small(st.game)
	if ev.is_empty():
		_bad("E1 no small event")
		return
	st.game.pending.clear()
	st.game.week_event_ids = {}
	if not st.game._present_event(ev):
		_bad("E1 present failed")
		return
	st.event_mode = "one"
	st._show_dawn()
	for _i in 4:
		await process_frame
	if st._end_state() != "ready" or st.end_button.disabled:
		_bad("E1 small event changed when the week can end (%s disabled %s)" % [st._end_state(), st.end_button.disabled])
		return
	if st.end_cover == null or st.end_cover.mouse_filter != Control.MOUSE_FILTER_STOP or st.end_cover.z_index <= st.dim.z_index:
		_bad("E1 cover not armed over the dim (filter %s z %s dim %s)" % [st.end_cover.mouse_filter if st.end_cover != null else -1, st.end_cover.z_index if st.end_cover != null else -1, st.dim.z_index])
		return
	var before := int(st.card_pulse_n)
	var center: Vector2 = st.end_button.get_global_rect().get_center()
	_click(st, center)
	for _i in 3:
		await process_frame
	if st.toast_label == null or st.toast_label.text != Copy.t(WAITING):
		_bad("E1 toast [%s]" % (st.toast_label.text if st.toast_label != null else "missing"))
	if int(st.card_pulse_n) <= before:
		_bad("E1 card did not pulse")
	else:
		print("E1 cover toast pulse %d" % int(st.card_pulse_n))
	_home(st)


func _e2(st) -> void:
	_home(st)
	await _view(st, Vector2i(1920, 1080), 1.0)
	var ev := _small(st.game)
	st.game.pending.clear()
	st.game.week_event_ids = {}
	st.game.audience = {}
	st.game.order_reports = []
	if not st.game._present_event(ev):
		_bad("E2 present failed")
		return
	st._sync_waiting()
	var week := int(st.game.week)
	var center: Vector2 = st.end_button.get_global_rect().get_center()
	var down_at := Time.get_ticks_msec()
	_mouse(st, center, true)
	for _i in 3:
		await process_frame
	var press_ms := int(st.end_press_drawn_at) - int(st.end_press_at)
	if st.end_ack == null or not st.end_ack.visible:
		_bad("E2 pressed face not showing")
	elif press_ms < 0 or press_ms > 100:
		_bad("E2 press face %d ms" % press_ms)
	_mouse(st, center, false)
	var card_ms := -1
	for _i in 20:
		await process_frame
		if st.dim != null and st.dim.visible and st.deck.top_token() == "dawn":
			card_ms = Time.get_ticks_msec() - down_at
			break
	if card_ms < 0:
		_bad("E2 card did not open")
	elif card_ms > 400:
		_bad("E2 card %d ms" % card_ms)
	if int(st.game.week) != week:
		_bad("E2 week changed %s -> %s" % [week, st.game.week])
	if card_ms >= 0 and press_ms >= 0 and press_ms <= 100 and card_ms <= 400:
		print("E2 press %d ms card %d ms" % [press_ms, card_ms])
	_home(st)


func _e3(st) -> void:
	_home(st)
	st._sync_waiting()
	var buttons := [
		["End turn", st.end_button],
		["Network", st.network_button],
		["Menu", st.menu_button],
		["Power", st.power_button],
	]
	for pair in buttons:
		var name := str(pair[0])
		var button: Button = pair[1]
		if button == null:
			_bad("E3 missing %s" % name)
			continue
		var normal := _fill(button, "normal")
		var hover := _fill(button, "hover")
		var pressed := _fill(button, "pressed")
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
		if _near(normal, hover):
			_bad("E3 %s hover matches rest %s" % [name, normal])
		if _near(normal, pressed) or _near(hover, pressed):
			_bad("E3 %s pressed is not its own face %s" % [name, pressed])
		if focus == null or _near(focus.bg_color, Color("24262b")) or _near(focus.border_color, Color("ffffff")):
			_bad("E3 %s focus is the engine face" % name)
		elif focus.border_color != Color("b89a6a") or focus.get_border_width_min() < 2:
			_bad("E3 %s focus ring %s width %s" % [name, focus.border_color, focus.get_border_width_min()])
		else:
			print("E3 %s rest %s hover %s pressed %s focus %s" % [name, normal.to_html(false), hover.to_html(false), pressed.to_html(false), focus.bg_color.to_html(false)])
	var ready: StyleBoxFlat = st.end_button.get_theme_stylebox("normal")
	if ready.border_color != Color("fff0c8"):
		_bad("E3 ready rim %s" % ready.border_color)


func _e4(st) -> void:
	for row in [["en", "en125"], ["ru", "ru125"]]:
		Copy.set_lang(str(row[0]))
		await _view(st, Vector2i(1920, 1080), 1.25)
		_home(st)
		if not st.showing_network:
			st._toggle_network()
		for _i in 2:
			await process_frame
		var sid := _foreign(st)
		st.network_view.open_visit(sid)
		for _i in 4:
			await process_frame
		var visit: Control = st.network_view.visit
		var tray: Control = st.tray
		if visit == null or tray == null or not visit.visible:
			_bad("E4 %s visit missing" % row[1])
			continue
		var gap: float = tray.get_global_rect().position.y - visit.get_global_rect().end.y
		if gap < 8.0:
			_bad("E4 %s visit gap %.1f" % [row[1], gap])
		var scroll := _scroll(visit)
		if scroll == null:
			_bad("E4 %s no scroll" % row[1])
		else:
			var scroll_gap: float = tray.get_global_rect().position.y - scroll.get_global_rect().end.y
			if scroll_gap < 8.0:
				_bad("E4 %s scroll gap %.1f" % [row[1], scroll_gap])
			else:
				print("E4 %s visit gap %.1f scroll gap %.1f" % [row[1], gap, scroll_gap])
		st.network_view.close_visit()
		if st.showing_network:
			st._toggle_network()
	Copy.set_lang("en")
	await _view(st, Vector2i(1920, 1080), 1.0)


func _e5(st) -> void:
	_home(st)
	var manual := SaveGame.manual_path()
	for path in [manual, manual + ".bak", manual + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	st.menu_button.grab_focus()
	st._show_menu()
	for _i in 4:
		await process_frame
	var load_button := _button_text(st.card_body, Copy.t("Load"))
	if load_button == null:
		_bad("E5 Load missing")
		return
	var face: StyleBoxFlat = load_button.get_theme_stylebox("disabled")
	if load_button.modulate.a > 0.7 or face == null or face.get_border_width_min() > 0:
		_bad("E5 Load alpha %.2f border %s" % [load_button.modulate.a, face.get_border_width_min() if face != null else -1])
	_click(st, load_button.get_global_rect().get_center())
	for _i in 3:
		await process_frame
	if st.toast_label == null or st.toast_label.text != Copy.t("No saved game."):
		_bad("E5 Load toast [%s]" % (st.toast_label.text if st.toast_label != null else "missing"))
	else:
		print("E5 Load toast alpha %.2f" % load_button.modulate.a)
	_home(st)
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "quarters":
			uid = str(room.uid)
	if uid == "":
		_bad("E5 no quarters")
		return
	st._show_room(uid)
	for _i in 4:
		await process_frame
	var push := _button_text(st.card_body, Copy.t("Push"))
	if not _is_lock(push):
		_bad("E5 Push is not locked")
		return
	_click(st, push.get_global_rect().get_center())
	for _i in 3:
		await process_frame
	if st.toast_label == null or st.toast_label.text != Copy.t("push.disabled_room"):
		_bad("E5 Push toast [%s]" % (st.toast_label.text if st.toast_label != null else "missing"))
	else:
		print("E5 Push toast")
	_home(st)


func _e6(st) -> void:
	_home(st)
	st.menu_button.grab_focus()
	await process_frame
	st._show_menu()
	for _i in 2:
		await process_frame
	_esc(st)
	for _i in 3:
		await process_frame
	if st.dim != null and st.dim.visible:
		_bad("E6 Esc left the menu open")
	var owner: Control = st.get_viewport().gui_get_focus_owner()
	if owner != st.menu_button:
		_bad("E6 menu focus %s" % owner)
	else:
		print("E6 menu focus returned")
	_home(st)
	st.drawer_open = true
	st._fill_people()
	st._place_drawer()
	for _i in 2:
		await process_frame
	var row: Control = _person_row(st.people_box)
	if row == null:
		_bad("E6 no person row")
	else:
		row.grab_focus()
		await process_frame
		row.emit_signal("picked", str(row.get("person_id")))
		for _i in 2:
			await process_frame
		_esc(st)
		for _i in 3:
			await process_frame
		owner = st.get_viewport().gui_get_focus_owner()
		if st.dim != null and st.dim.visible:
			_bad("E6 Esc left the person card open")
		elif owner != row:
			_bad("E6 person focus %s" % owner)
		else:
			print("E6 person focus returned")
	_home(st)
	var laws_opener: Button = st.network_button
	laws_opener.grab_focus()
	await process_frame
	st._show_laws()
	for _i in 2:
		await process_frame
	_esc(st)
	for _i in 3:
		await process_frame
	owner = st.get_viewport().gui_get_focus_owner()
	if st.dim != null and st.dim.visible:
		_bad("E6 Esc left the laws card open")
	elif owner != laws_opener:
		_bad("E6 laws focus %s" % owner)
	else:
		print("E6 laws focus returned")
	_home(st)
	if st.observer_button == null:
		_bad("E6 no observer")
		return
	st.observer_button.grab_focus()
	await process_frame
	st._show_observer()
	for _i in 3:
		await process_frame
	_esc(st)
	for _i in 3:
		await process_frame
	owner = st.get_viewport().gui_get_focus_owner()
	var desk_up: bool = st.observer_panel != null and st.observer_panel.visible
	if desk_up:
		_bad("E6 Esc left the observer open")
	elif owner != st.observer_button:
		_bad("E6 observer focus %s" % owner)
	else:
		print("E6 observer focus returned")
	_home(st)


func _hit(st) -> void:
	Copy.set_lang("ru")
	await _view(st, Vector2i(1920, 1080), 1.25)
	_home(st)
	for _i in 2:
		await process_frame
	for pair in [["End turn", st.end_button], ["Network", st.network_button]]:
		var button: Button = pair[1]
		var center: Vector2 = button.get_global_rect().get_center()
		var got := [false]
		var cb := func() -> void: got[0] = true
		button.button_down.connect(cb)
		_mouse(st, center, true)
		await process_frame
		_mouse(st, center, false)
		await process_frame
		if button.button_down.is_connected(cb):
			button.button_down.disconnect(cb)
		if not got[0]:
			_bad("HIT %s center %s did not receive the click" % [pair[0], center])
		else:
			print("HIT %s center %s" % [pair[0], center])
		for _i in 4:
			await process_frame
		_home(st)
		for _i in 2:
			await process_frame
	Copy.set_lang("en")
	await _view(st, Vector2i(1920, 1080), 1.0)


func _mouse(st, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	event.global_position = point
	st.get_viewport().push_input(event, true)


func _click(st, point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	st.get_viewport().push_input(move, true)
	_mouse(st, point, true)


func _esc(st) -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	st.get_viewport().push_input(esc)


func _fill(button: Button, state: String) -> Color:
	var box: StyleBox = button.get_theme_stylebox(state)
	if box is StyleBoxFlat:
		return (box as StyleBoxFlat).bg_color
	return Color(0, 0, 0, 0)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func _small(game) -> Dictionary:
	for ev in game.catalog.events:
		if not bool(ev.get("major", false)) and not ev.has("needs") and not ev.has("trigger"):
			return ev
	return {}


func _foreign(st) -> String:
	var capital := str(st.game.capital_id)
	for key in st.game.stations:
		if str(key) != capital:
			return str(key)
	return capital


func _scroll(node: Node) -> ScrollContainer:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is ScrollContainer:
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _person_row(node: Node) -> Control:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here.get_script() != null and str(here.get("person_id")) != "":
			return here
		for child in here.get_children():
			stack.append(child)
	return null


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
