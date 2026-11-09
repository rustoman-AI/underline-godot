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
	await _round2(st)
	_round3(st)
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
	## #70 asserted schema 14, the schema of its base. P90 raised the tip to schema 21.
	## P94 raised the tip to schema 25 (scars). P96 added schema 26 (shiftword_state).
	## P97 added schema 27 (receipt_seq). This branch keeps both. sdays stays 20. carry stays 21.
	if Game.SAVE_SCHEMA != 27:
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
	if BuildInfo.version_for(true) != "0.1.0":
		_bad("release version %s" % BuildInfo.version_for(true))
	if BuildInfo.version_for(false) != "0.1.0-playtest3":
		_bad("playtest version %s" % BuildInfo.version_for(false))
	if presets.find("name=\"Windows Steam\"") < 0:
		_bad("Windows Steam preset missing")
	var exporter := FileAccess.get_file_as_string("res://tools/export.ps1")
	if exporter.find("--export-release") < 0 or exporter.find("--export-debug") >= 0 or exporter.find("Windows Steam") < 0:
		_bad("steam export is not Export Release")


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
	var disabled_ink: Color = button.get_theme_color("font_disabled_color")
	if disabled == null or not is_equal_approx(disabled.bg_color.a, 0.18) or disabled.get_border_width(SIDE_LEFT) != 0:
		_bad("disabled face %s border %s" % [disabled.bg_color if disabled != null else "null", disabled.get_border_width(SIDE_LEFT) if disabled != null else -1])
	if not is_equal_approx(disabled_ink.a, 0.6) or not is_equal_approx(disabled_ink.r, st.PAPER_MUTED.r):
		_bad("disabled ink %s" % disabled_ink)
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
		var face := (row.get_child(1) as Button).get_theme_stylebox("normal") as StyleBoxFlat
		if not ink.is_equal_approx(st.PAPER_INK) or not hot.is_equal_approx(st.DELTA_DOWN):
			_bad("demolish ink %s hover %s" % [ink, hot])
		elif face == null or face.get_border_width(SIDE_LEFT) != 1 or not face.border_color.is_equal_approx(st.PAPER_EDGE):
			_bad("demolish outline %s" % (face.border_color if face != null else "null"))
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
	var tip_src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var drop_at := tip_src.find("func drop_tip")
	var drop_fn := tip_src.substr(drop_at, tip_src.find("func close_sheet", drop_at) - drop_at)
	if drop_fn.find("warp_mouse") < 0:
		_bad("drop_tip does not warp the pointer")
	net.drop_tip()
	root.size = Vector2i(1920, 1080)
	st.size = Vector2(1920, 1080)
	await process_frame
	st._fit_card()
	st._tick_voice()
	await process_frame
	if st.vo_pill != null and st.vo_pill.visible and st.dim != null and st.dim.visible:
		var left_w: float = st.vo_pill.get_combined_minimum_size().x
		if st.vo_pill.position.x > 20.0:
			_bad("journal pill x %.1f is not the left rule" % st.vo_pill.position.x)
		var limit: float = st.card.get_global_rect().position.x - 48.0
		if limit > 80.0 and st.vo_pill.position.x + left_w > limit + 2.0:
			_bad("pill overlaps the journal, right %.1f limit %.1f" % [st.vo_pill.position.x + left_w, limit])
	net._show_warm_float("The ring remembers how they feel.")
	if net._warm_float == null or net._warm_float.z_index != 11:
		_bad("first float z %s" % (net._warm_float.z_index if net._warm_float != null else "null"))
	else:
		var warm_plate: Control = net._float_plate(net._warm_float)
		if warm_plate == null or warm_plate == net._warm_float or not bool(warm_plate.get_meta("map_float_plate", false)) or warm_plate.z_index != 11:
			_bad("warm float has no map plate")
		var top := float(net._float_top())
		if top + 0.5 < float(net._hud_top()) + 26.0:
			_bad("float stack %.1f is not HUD+26" % top)
		if absf(warm_plate.position.y - top) > 1.0:
			_bad("warm float y %.1f, want %.1f" % [warm_plate.position.y, top])
		if warm_plate.size.y > 34.5:
			_bad("warm plate height %.1f exceeds the 34 px slot" % warm_plate.size.y)
		var slip: StyleBoxFlat = st._map_toast_face()
		var face: StyleBoxFlat = warm_plate.get_theme_stylebox("panel")
		if face == null or slip == null or not face.bg_color.is_equal_approx(slip.bg_color):
			_bad("warm float plate is not the map slip")
		if net._warm_float.get_theme_constant("outline_size") != 0 or not net._warm_float.get_theme_color("font_color").is_equal_approx(Color("2b2118")):
			_bad("warm float is still bare outlined ink")
		net._show_deal_float("The ring remembers how they feel.")
		net._place_warm_float()
		net._show_leaf_float("The ring remembers how they feel.")
		var deal_plate: Control = net._float_plate(net._deal_float) if net._deal_float != null else null
		var leaf_plate: Control = net._float_plate(net._leaf_float) if net._leaf_float != null else null
		if deal_plate == null or not bool(deal_plate.get_meta("map_float_plate", false)) or absf(deal_plate.position.y - top) > 1.0:
			_bad("deal float y %s" % (deal_plate.position.y if deal_plate != null else "null"))
		if absf(warm_plate.position.y - (top + 34.0)) > 1.0:
			_bad("warm float stacked y %.1f" % warm_plate.position.y)
		if leaf_plate == null or not bool(leaf_plate.get_meta("map_float_plate", false)) or absf(leaf_plate.position.y - (top + 68.0)) > 1.0:
			_bad("leaf float stacked y %s" % (leaf_plate.position.y if leaf_plate != null else "null"))
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


## Round 2 is UI on top of this gate. Schema stays 16 and the 125% default stays held (auto, scale 1.0).
func _round2(st) -> void:
	var settings := FileAccess.get_file_as_string("res://sim/settings.gd")
	if settings.find("static var ui_scale := 1.0") < 0 or settings.find("static var ui_scale_auto := true") < 0:
		_bad("ui scale default moved off auto 1.0")
	var shrink := FileAccess.get_file_as_string("res://ui/station.gd")
	var overflow_at := shrink.find("if h > max_h and card_body.get_child_count() > 0:")
	if overflow_at < 0 or shrink.find("func _shrink_card") < 0:
		_bad("dilemma card no longer squeezes only when it overflows")
	var net = st.network_view
	if not is_equal_approx(float(net.FOG_ALPHA), 0.6) or not is_equal_approx(float(net.FOG_SCALE), 0.8):
		_bad("fog pins are not 0.6 ink / 0.8 scale")
	var map_src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if map_src.find("_frame_home") >= 0 or map_src.find("HOME_CLEAR") >= 0:
		_bad("map framing nudge is still applied")
	var locked: StyleBoxFlat = net._locked_face("patrol")
	if locked == null or not is_equal_approx(locked.bg_color.a, 0.85) or locked.get_border_width(SIDE_LEFT) != 1:
		_bad("locked order face")
	net._rumor_named_game = 0
	net._rumor_named_sid = ""
	if not net._rumor_shows_name(st.game, "first") or not net._rumor_shows_name(st.game, "first") or net._rumor_shows_name(st.game, "later"):
		_bad("rumor chip does not keep the first name and hide the next")
	var logo: Control = st._title_logo()
	if logo == null or not bool(logo.get_meta("title_logo", false)):
		_bad("title falls back even though the logo texture is present")
	elif logo is TextureRect:
		var tex: Texture2D = (logo as TextureRect).texture
		if tex == null or tex.get_width() < 500:
			_bad("title logo is not the 520-wide lockup")
	logo.free()
	var quiet: StyleBoxFlat = st.hub_button.get_theme_stylebox("normal") as StyleBoxFlat
	if quiet == null or quiet.get_border_width(SIDE_LEFT) != 1 or quiet.bg_color.a > 0.45:
		_bad("Station view is not the quiet face")
	var station_icon := ArtPack.icon_texture("station_view", 24.0) if shrink.find("ArtPack") >= 0 else null
	if station_icon != null and st.hub_button.icon == null:
		_bad("Station view icon did not land on the button")
	elif station_icon == null and shrink.find("icon_texture(\"station_view\"") < 0:
		_bad("Station view is not wired to the station icon")
	var was_shot: bool = st.shot_mode
	var motion := Settings.reduce_motion
	st.shot_mode = false
	Settings.reduce_motion = false
	st._play_night()
	if st.night == null or st.night.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_bad("night card blocks input")
	else:
		var frame := st.night.get_node_or_null("Frame") as Panel
		var hair: StyleBoxFlat = null
		if frame != null:
			hair = frame.get_theme_stylebox("panel") as StyleBoxFlat
		if hair == null or hair.get_border_width(SIDE_LEFT) != 1 or not is_equal_approx(hair.border_color.r, st.BRASS.r):
			_bad("night card has no brass hairline")
	Settings.reduce_motion = true
	st._end_night()
	st._play_night()
	if st.night != null and st.night.visible:
		_bad("reduce motion still fades the night card")
	Settings.reduce_motion = motion
	st.shot_mode = was_shot
	st._end_night()
	st._show_howto(false)
	await process_frame
	var notice: Node = st.notice_layer
	if notice == null:
		_bad("how to play did not open")
	else:
		var leads: Array = []
		var bodies: Array = []
		for lab in notice.find_children("*", "Label", true, false):
			if lab.has_meta("howto_lead"):
				leads.append(lab)
			elif lab.has_meta("howto_line"):
				bodies.append(lab)
		var lines: Array = st._howto().get("lines", [])
		if leads.size() != lines.size():
			_bad("how to play leads %d lines %d" % [leads.size(), lines.size()])
		else:
			for i in lines.size():
				var whole := str(lines[i].get("en", ""))
				var parts: PackedStringArray = st._howto_parts(whole)
				var lead_lab: Label = leads[i]
				if str(lead_lab.text) != parts[0] or int(lead_lab.get_theme_font_size("font_size")) != 20:
					_bad("how to play lead %d '%s'" % [i + 1, lead_lab.text])
				elif st.display_font != null and lead_lab.get_theme_font("font") != st.display_font:
					_bad("how to play lead %d is not the display face" % (i + 1))
				var shown := str(lead_lab.text)
				if parts[1] != "":
					var body_lab: Label = null
					for lab in bodies:
						if str(lab.text) == parts[1]:
							body_lab = lab
							break
					if body_lab == null or int(body_lab.get_theme_font_size("font_size")) != 16:
						_bad("how to play body %d missing" % (i + 1))
					else:
						shown = parts[0] + " " + parts[1]
				if shown != whole:
					_bad("how to play copy %d changed" % (i + 1))
	await _night_clears_rail(st)
	if st.has_method("_close_notice"):
		st._close_notice()


## Round 3 plates yard toasts and map first-floats. No new strings, and the 125% default stays in _round2.
func _round3(st) -> void:
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var switch_at := station.find("func _room_switch")
	var switch_end := station.find("func _room_status_lines", switch_at)
	if switch_at < 0 or switch_end < switch_at:
		_bad("room switch missing")
	else:
		var switch_fn := station.substr(switch_at, switch_end - switch_at)
		if switch_fn.find("if not bool(info.can) and str(info.reason) == \"\":") < 0:
			_bad("N9 still shows Switch off with an empty reason")
	if station.find("burn_button.tooltip_text = Copy.t(\"Burn salvage\")") < 0:
		_bad("burn tip is raw English")
	if station.find("power_button.tooltip_text = Copy.t(\"Power order\")") < 0:
		_bad("power tip is raw English")
	if station.find("people_button.tooltip_text = Copy.t(\"Residents\")") < 0:
		_bad("people tip is raw English")
	var theme: Theme = st._tooltip_theme()
	var grab: StyleBoxFlat = theme.get_stylebox("grabber", "VScrollBar") as StyleBoxFlat
	var track: StyleBoxFlat = theme.get_stylebox("scroll", "HScrollBar") as StyleBoxFlat
	if grab == null or grab.bg_color.r < 0.4 or grab.bg_color.g < 0.3:
		_bad("scrollbar grabber is not brass")
	if track == null or track.bg_color.a < 0.4 or track.bg_color.r > 0.2:
		_bad("scrollbar track is not the dark brass well")
	var motion := Settings.reduce_motion
	Settings.reduce_motion = true
	st.showing_network = false
	st._toast("Order sent. The result comes at next dawn.")
	Settings.reduce_motion = motion
	if st.toast_plate == null or not st.toast_plate.visible or st.toast_label.get_parent() != st.toast_plate:
		_bad("yard toast is still bare")
	else:
		var yard: StyleBoxFlat = st.toast_plate.get_theme_stylebox("panel")
		var tip: StyleBoxFlat = st._tip_plate_style()
		if yard == null or tip == null or not yard.bg_color.is_equal_approx(tip.bg_color):
			_bad("yard toast is not the tip plate")
		if st.toast_label.get_theme_constant("outline_size") != 0:
			_bad("yard toast is still outlined")


## Night runs sits above End turn, clear of the People rail's round mark, in EN and RU at 100% and 125%.
func _night_clears_rail(st) -> void:
	var saved := Copy.ru()
	for case in [["en", Vector2(1920, 1080)], ["en", Vector2(1536, 864)], ["ru", Vector2(1920, 1080)], ["ru", Vector2(1536, 864)]]:
		Copy.set_lang(str(case[0]))
		var sz: Vector2 = case[1]
		st.size = sz
		if st.network_view != null:
			st.network_view.size = sz
			if st.network_view.has_method("_name_zoom_bar"):
				st.network_view._name_zoom_bar()
		st._place_chrome()
		await process_frame
		var night: Rect2 = st.night_button.get_global_rect()
		if st.people_tab != null and st.people_tab.visible:
			var tab: Rect2 = st.people_tab.get_global_rect()
			var mark := Rect2(tab.position.x, tab.end.y - 40.0, tab.size.x, 40.0)
			if night.intersects(mark):
				_bad("night runs covers the people mark %s %s" % [case[0], sz])
		if st.network_button != null:
			var net: Rect2 = st.network_button.get_global_rect()
			var shares_x := night.position.x < net.end.x - 1.0 and night.end.x > net.position.x + 1.0
			var gap := net.position.y - night.end.y
			if shares_x and gap < 4.0:
				_bad("night runs gap to network %.1f %s %s" % [gap, case[0], sz])
		if st.showing_network and st.network_view != null and st.network_view.legend_button != null:
			st.network_view._place_panels()
			var key: Rect2 = st.network_view.legend_button.get_global_rect()
			if key.size.x > 2.0 and night.intersects(key):
				_bad("night runs covers the map key %s %s" % [case[0], sz])
	Copy.set_lang("ru" if saved else "en")


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
