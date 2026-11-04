extends SceneTree

## Headless checks for the UI-only release polish fixes (R01, R02, R03, R05, R06, R07, R08, R14, R15, R19, R20, R24, R25, R27).
##   godot --headless --path . -s res://sim/check_release_rfix.gd

const SCRATCH := "user://check_release_rfix"

var bad: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Copy.set_lang("en")
	_static()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 4:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.guide_layer != null:
		st.guide_layer.visible = false
	_chrome(st)
	_buttons(st)
	await _more(st)
	await _room(st)
	_ahead(st)
	await _map(st)
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	if bad.is_empty():
		print("RELEASE RFIX OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("RELEASE RFIX FAILED")
	quit(1)


func _bad(msg: String) -> void:
	bad.append(msg)


func _static() -> void:
	if Game.SAVE_SCHEMA != 14:
		_bad("SAVE_SCHEMA is %s" % str(Game.SAVE_SCHEMA))
	var delay := float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec"))
	if not is_equal_approx(delay, 0.35):
		_bad("tooltip delay %.3f" % delay)
	if not BuildInfo.show_log_chrome(true, false) or not BuildInfo.show_log_chrome(false, true) or BuildInfo.show_log_chrome(false, false):
		_bad("log chrome gate %s %s %s" % [BuildInfo.show_log_chrome(true, false), BuildInfo.show_log_chrome(false, true), BuildInfo.show_log_chrome(false, false)])
	var stamped := BuildInfo.release_build_id("dev")
	if stamped == "dev" or stamped == "" or stamped == "unknown":
		_bad("release stamp of dev is '%s'" % stamped)
	if BuildInfo.release_build_id("abc123") != "abc123":
		_bad("release stamp rewrote a real id")
	if BuildInfo.release_build_id("unknown") == "dev" or BuildInfo.release_build_id("unknown") == "unknown":
		_bad("unknown build id was not stamped")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var playtest := presets.find("name=\"Windows Playtest\"")
	var en := presets.find("name=\"Windows EN\"")
	if playtest < 0 or presets.find("custom_features=\"playtest\"") < 0:
		_bad("playtest export has no playtest feature")
	if en < 0 or presets.substr(en, playtest - en).find("custom_features=\"playtest\"") >= 0:
		_bad("Windows EN carries the playtest feature")
	var teaser := FileAccess.get_file_as_string("res://ui/intro/teaser.gd")
	if teaser.find("_label(\"\", _font(false), 34, PAPER)") < 0:
		_bad("teaser subtitle is not 34 px")
	if teaser.find("outline_size\", 6") < 0 or teaser.find("Color(0, 0, 0, 0.8)") < 0:
		_bad("teaser subtitle outline")
	var plugin := FileAccess.get_file_as_string("res://addons/build_stamp/export_plugin.gd")
	if plugin.find("release_build_id") < 0 or plugin.find("skip()") < 0:
		_bad("export plugin does not stamp the packed build id")


func _chrome(st) -> void:
	var net = st.network_view
	if net.sheet.z_index != 8:
		_bad("sheet z %s" % net.sheet.z_index)
	for pair in [["hud", st.hud], ["tray", st.tray], ["end", st.end_button], ["network", st.network_button], ["hub", st.hub_button], ["ahead", st.ahead]]:
		if pair[1] == null or int(pair[1].z_index) != 10:
			_bad("%s z %s" % [pair[0], pair[1].z_index if pair[1] != null else "null"])
	if st.dim.z_index <= net.sheet.z_index:
		_bad("dim z %s is not above the sheet" % st.dim.z_index)


func _buttons(st) -> void:
	st.on_paper = true
	var button: Button = st._button("Push", func() -> void: pass)
	var disabled := button.get_theme_stylebox("disabled") as StyleBoxFlat
	var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	if disabled == null or disabled.bg_color.a > 0.5 or not disabled.border_color.is_equal_approx(st.PAPER_MUTED):
		_bad("disabled face %s" % (disabled.bg_color if disabled != null else "null"))
	if hover == null or focus == null or not hover.bg_color.is_equal_approx(focus.bg_color) or not hover.border_color.is_equal_approx(focus.border_color):
		_bad("focus face is not the hover face")
	button.free()


func _more(st) -> void:
	for room in st.game.rooms:
		var staff: Array = room.staff.duplicate()
		for sid in staff:
			st.game.apply({"kind": "unassign", "person": str(sid)})
	st._refresh()
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	st.yard.queue_redraw()
	await process_frame
	await process_frame
	if st.yard.more_hits.is_empty():
		_bad("no +N pip on a yard with idle people")
		return
	for mark in st.yard.more_hits:
		var tip := str(mark.get("tip", ""))
		if tip.find("more") < 0:
			_bad("pip tip '%s'" % tip)
		var rect: Rect2 = mark.rect
		var world_w := rect.size.x / maxf(st.yard.zoom, 0.01)
		if world_w > 90.0:
			_bad("pip is %.0f px wide" % world_w)


func _room(st) -> void:
	var uid := ""
	for room in st.game.rooms:
		var info: Dictionary = st.game.upgrade_preview(str(room.uid))
		if str(info.get("name", "")) != "":
			uid = str(room.uid)
			break
	if uid == "":
		_bad("no room has an upgrade to price")
		return
	st.game.stock.materials = 99
	st._show_room(uid)
	await process_frame
	_cost_ink(st, st.PAPER_INK, "affordable")
	var row := _demolish_row(st)
	if row == null or not row.has_meta("demolish_row"):
		_bad("demolish is not the quiet row")
	elif row.get_child_count() < 2 or not (row.get_child(1) is Button) or (row.get_child(1) as Control).size_flags_horizontal != Control.SIZE_SHRINK_END:
		_bad("demolish is not right-aligned")
	else:
		var ink: Color = (row.get_child(1) as Button).get_theme_color("font_color")
		var hot: Color = (row.get_child(1) as Button).get_theme_color("font_hover_color")
		if not ink.is_equal_approx(st.PAPER_MUTED) or not hot.is_equal_approx(st.DELTA_DOWN):
			_bad("demolish ink %s hover %s" % [ink, hot])
	st.game.stock.materials = 0
	st._show_room(uid)
	await process_frame
	_cost_ink(st, st.DELTA_DOWN, "short")
	st._close_card()
	if st.dim != null:
		st.dim.visible = false


func _cost_ink(st, want: Color, label: String) -> void:
	var found := false
	for node in st.card_body.find_children("*", "Label", true, false):
		if node.is_queued_for_deletion() or not node.has_meta("upgrade_cost"):
			continue
		found = true
		var ink: Color = node.get_theme_color("font_color")
		if not ink.is_equal_approx(want):
			_bad("upgrade cost %s is %s" % [label, ink])
	if not found:
		_bad("upgrade cost label missing (%s)" % label)


func _demolish_row(st) -> Control:
	for node in st.card_body.find_children("*", "HBoxContainer", true, false):
		if node.is_queued_for_deletion():
			continue
		if node.has_meta("demolish_row"):
			return node
	return null


func _ahead(st) -> void:
	st.game.pending.clear()
	st._sync_waiting()
	if st.end_button.tooltip_text != Copy.t("End the week"):
		_bad("end tip before hover '%s'" % st.end_button.tooltip_text)
	st._show_ahead(true)
	if not st.ahead.visible or st.end_button.tooltip_text != "":
		_bad("end tip while Ahead shows '%s' visible %s" % [st.end_button.tooltip_text, st.ahead.visible])
	st._sync_waiting()
	if st.end_button.tooltip_text != "":
		_bad("a refresh put the end tip back over Ahead")
	st._show_ahead(false)
	if st.ahead.visible or st.end_button.tooltip_text != Copy.t("End the week"):
		_bad("end tip after Ahead '%s'" % st.end_button.tooltip_text)


func _map(st) -> void:
	if not st.showing_network:
		st._toggle_network()
	var net = st.network_view
	net.size = st.size
	net._fit()
	net.tooltip_text = "Unknown · borders your line"
	net._hover = "kept"
	net.open_sheet(str(st.game.capital_id))
	await process_frame
	if net.tooltip_text != "" or net._hover != "":
		_bad("open_sheet left tip '%s' hover '%s'" % [net.tooltip_text, net._hover])
	var capital_once := 0
	var ships := 0
	for node in net.sheet.find_children("*", "Label", true, false):
		if node.is_queued_for_deletion():
			continue
		if str(node.text).find(Copy.t("This is the capital.")) >= 0:
			capital_once += 1
		if str(node.text).find(Copy.t("Ships home")) >= 0:
			ships += 1
	if capital_once != 1 or ships != 0:
		_bad("capital lines: this-is-capital %d, ships %d" % [capital_once, ships])
	for node in net.sheet.find_children("*", "Button", true, false):
		if node.is_queued_for_deletion():
			continue
		if str(node.text) == Copy.t("Back to your station"):
			_bad("capital sheet still has the inner back row")
	var release: Button = null
	for node in net.sheet.find_children("*", "Button", true, false):
		if node.is_queued_for_deletion():
			continue
		if str(node.text) == Copy.t("Release"):
			release = node
	if release == null or not (release.get_parent() is HFlowContainer):
		_bad("Release is not in a wrapping row")
	elif (release.size_flags_horizontal & Control.SIZE_EXPAND_FILL) != Control.SIZE_EXPAND_FILL or release.custom_minimum_size.x < 80.0 or release.clip_text:
		_bad("Release still clips: flags %s min %s clip %s" % [release.size_flags_horizontal, release.custom_minimum_size, release.clip_text])
	st.vo_text = "The ring keeps its own hours."
	st.vo_text_caption = "Station"
	st.vo_text_until = Time.get_ticks_msec() + 60000
	st._tick_voice()
	await process_frame
	if st.vo_pill == null or not st.vo_pill.visible:
		_bad("voice pill did not show on the map")
	else:
		var pill_w: float = st.vo_pill.get_combined_minimum_size().x
		var want := maxf(16.0, (st.size.x - pill_w) * 0.5)
		if absf(st.vo_pill.position.x - want) > 1.0:
			_bad("pill x %.1f, want %.1f" % [st.vo_pill.position.x, want])
		var overlap: Rect2 = st.vo_pill.get_rect().grow(2.0)
		if not net._legend_blocked(overlap):
			_bad("legend does not treat the voice pill as an obstacle")
		if net._legend_blocked(Rect2(8000, 8000, 10, 10)):
			_bad("legend hides from an empty corner")
	net.tooltip_text = "Unknown · borders your line"
	net._hover = "kept"
	st._show_journal()
	await process_frame
	if net.tooltip_text != "" or str(net._hover) != "":
		_bad("journal left the map tip '%s'" % net.tooltip_text)
	if st.dim == null or not st.dim.visible or st.dim.z_index <= net.sheet.z_index:
		_bad("journal on the map is not dimmed (dim %s)" % (st.dim.z_index if st.dim != null else "null"))
	st._ensure_menu()
	st._fill_menu_root()
	var saw_log := false
	for node in st.menu_root.find_children("*", "Button", true, false):
		if str(node.text).begins_with("Playtest log:"):
			saw_log = true
	if not saw_log:
		_bad("debug build hid the playtest log row")


func _wipe(path: String) -> void:
	var abs := path if path.begins_with("/") else ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(abs):
		_wipe_dir(abs)


func _wipe_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var sub := path.path_join(name)
			if dir.current_is_dir():
				_wipe_dir(sub)
			else:
				DirAccess.remove_absolute(sub)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
