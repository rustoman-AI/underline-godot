extends SceneTree

## C1, C4, C11, C12, C13, C14, C15. UI chrome only.
##   godot --headless --path . -s res://sim/check_chrome_nits.gd
##   UNDERLINE_SHOTS_DIR=/tmp/chrome godot --rendering-driver opengl3 --path . -s res://sim/check_chrome_nits.gd
## Headless skips screenshots. A real renderer writes them. Logic still has to pass.

const ONCE := [
	"seen_room_trace", "seen_rival_desk", "seen_callers", "seen_passage_scars",
	"seen_line_echo", "seen_regulars", "seen_carried_word", "seen_station_days",
]
const YARD := ["regular", "sday", "carry", "echo", "rival", "caller", "scar", "trace"]
const MAP := ["deal", "warm", "leaf", "transfer", "regular", "sday", "carry", "echo", "rival", "caller", "scar"]

var bad: PackedStringArray = []
var _shots_skipped := false
var _shots_saved := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if Game.SAVE_SCHEMA != 25:
		_bad("SAVE_SCHEMA %s" % str(Game.SAVE_SCHEMA))
	_c1_source()
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
	for lang in ["en", "ru"]:
		for size_name in ["100", "125"]:
			var win := Vector2i(1920, 1080) if size_name == "100" else Vector2i(1536, 864)
			await _view(st, win)
			Copy.set_lang(lang)
			var tag := "%s %s" % [lang, size_name]
			await _c1(st, tag)
			await _c4(st, tag)
			await _c11(st, tag)
			await _c12_forward(st, tag)
			await _c14(st, tag)
			await _c15(st, tag)
	await _view(st, Vector2i(1536, 864))
	Copy.set_lang("ru")
	await _c12_orders(st, "ru 125")
	await _view(st, Vector2i(1100, 700))
	Copy.set_lang("en")
	await _c4_tight(st, "en tight")
	await _c13(st)
	_shots_note()
	Copy.set_lang("en")
	if is_instance_valid(st):
		st.free()
	if bad.is_empty():
		print("CHROME NITS OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("CHROME NITS FAILED")
	quit(1)


func _c1_source() -> void:
	var src := FileAccess.get_file_as_string("res://ui/observer_panel.gd")
	if src.find("_btn(\"Close\"") >= 0:
		_bad("observer Close is still a hardcoded English literal")
	if src.find("Copy.t(\"Close\")") < 0:
		_bad("observer Close does not reuse Copy.t")
	var ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/ru.json"))
	if not (ru is Dictionary) or str(ru.get("Close", "")) != "Закрыть":
		_bad("ru.json Close is not Закрыть")


func _c1(st, tag: String) -> void:
	_home(st)
	st._show_observer()
	for _i in 2:
		await process_frame
	var close := _close_button(st.observer_panel)
	var want := "Закрыть" if Copy.ru() else "Close"
	if close == null or close.text != want or close.text != Copy.t("Close"):
		_bad("C1 %s close [%s] want [%s]" % [tag, close.text if close != null else "missing", want])
	else:
		print("C1 %s close %s" % [tag, close.text])
	if tag == "ru 125":
		await _shot(st, "c1_ru_observer_125_after")
	st._close_observer()
	for _i in 1:
		await process_frame


func _c4(st, tag: String) -> void:
	_home(st)
	var line := "Cable radio. The passage kept a mark and the caller is still on the platform."
	st._show_radio(line, 30.0)
	_station_chatter(st)
	for _i in 1:
		await process_frame
	if st.radio_panel == null or not st.radio_hold or st.radio_tween == null or not st.radio_tween.is_valid():
		_bad("C4 %s radio did not start" % tag)
		return
	if not st.radio_panel.visible:
		_bad("C4 %s radio hidden with no panel" % tag)
	st._show_observer()
	for _i in 2:
		await process_frame
	_assert_chatter_clear(st, st.observer_panel, "C4 %s observer" % tag)
	_assert_hold(st, "C4 %s observer" % tag)
	if tag == "ru 125":
		await _shot(st, "c4_radio_observer_ru_125_after")
	st._close_observer()
	for _i in 1:
		await process_frame
	if not st.showing_network:
		st._toggle_network()
	for _i in 2:
		await process_frame
	st.network_view.open_visit(str(st.game.capital_id))
	for _i in 2:
		await process_frame
	st._sync_chatter_cover()
	if st.radio_panel.visible:
		_bad("C4 %s radio still covers Visit" % tag)
	_assert_chatter_clear(st, st.network_view.visit, "C4 %s visit" % tag)
	_assert_hold(st, "C4 %s visit" % tag)
	_note_rows(st, "C4 %s visit rows" % tag)
	if tag == "ru 125":
		await _shot(st, "c4_radio_visit_ru_125_after")
	st.network_view.close_visit()
	st._show_menu()
	for _i in 2:
		await process_frame
	if st.dim == null or not st.dim.visible:
		_bad("C4 %s pause did not open" % tag)
	elif st.radio_panel.visible:
		_bad("C4 %s radio still covers pause" % tag)
	_assert_hold(st, "C4 %s pause" % tag)
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	for _i in 1:
		await process_frame
	st._sync_chatter_cover()
	if st.radio_hold and not st.radio_panel.visible and not st._chatter_blocked(st.radio_panel):
		_bad("C4 %s radio did not return after pause" % tag)
	if st.dim != null:
		st.dim.visible = true
	st._sync_chatter_cover()
	if st.radio_panel.visible:
		_bad("C4 %s radio covers a modal" % tag)
	if st.dim != null:
		st.dim.visible = false
	st._sync_chatter_cover()
	if st.showing_network:
		st._toggle_network()
	st._hide_radio()
	if st.vo_pill != null:
		st.vo_pill.visible = false
		st.vo_text_until = 0


func _c14(st, tag: String) -> void:
	_home(st)
	_clear_yards(st)
	var flags := _flag_snap(st.game)
	var marks := bool(st.game.flags.get("seen_obs_marks", false))
	var kit := bool(st.game.flags.get("seen_obs_kit", false))
	var text := Copy.t("obs.first_mark")
	st._show_obs_float(text)
	for _i in 2:
		await process_frame
	if st.obs_float == null or not st.obs_float.visible or st.obs_float.text != text:
		_bad("C14 %s float missing" % tag)
		return
	var home_y: float = st.size.y * 0.42
	if absf(st.obs_float.position.y - home_y) > 1.0 or absf(st.obs_float.position.x - (st.size.x * 0.5 - 210.0)) > 1.0:
		_bad("C14 %s home position %s" % [tag, st.obs_float.position])
	var tween: Tween = st.obs_float_tween
	var tween_id := tween.get_instance_id() if tween != null else 0
	var room_uid := ""
	for room in st.game.rooms:
		room_uid = str(room.uid)
		break
	if room_uid != "":
		st._show_room(room_uid)
		for _i in 2:
			await process_frame
		if not st.obs_float.visible:
			_bad("C14 %s room card hid the observer float" % tag)
		st._close_card()
		if st.dim != null:
			st.dim.visible = false
		for _i in 1:
			await process_frame
	# Pause first, after the float is already up.
	st._show_menu()
	for _i in 2:
		await process_frame
	if st.obs_float.visible or not bool(st.obs_float.get_meta("yard_notice_paused", false)):
		_bad("C14 %s pause did not park the float" % tag)
	if st.obs_float_tween == null or st.obs_float_tween.get_instance_id() != tween_id or st.obs_float_tween.is_running():
		_bad("C14 %s pause replaced the tween" % tag)
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	for _i in 2:
		await process_frame
	st._sync_yard_notice_cover()
	if not st.obs_float.visible or st.obs_float_tween == null or not st.obs_float_tween.is_running():
		_bad("C14 %s float did not resume" % tag)
	if st.obs_float_tween.get_instance_id() != tween_id:
		_bad("C14 %s resume started a new tween" % tag)
	# Again, the other way: open pause, then show.
	st._show_menu()
	for _i in 1:
		await process_frame
	st._show_obs_float(text)
	for _i in 2:
		await process_frame
	if st.obs_float.visible:
		_bad("C14 %s show during pause stayed on screen" % tag)
	var second: Tween = st.obs_float_tween
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	for _i in 2:
		await process_frame
	st._sync_yard_notice_cover()
	if not st.obs_float.visible or second == null or not second.is_running() or st.obs_float_tween != second:
		_bad("C14 %s second resume" % tag)
	if tag == "ru 125":
		st._show_menu()
		for _i in 2:
			await process_frame
		await _shot(st, "c14_obs_float_pause_ru_125_after")
		st._close_card()
		if st.dim != null:
			st.dim.visible = false
		for _i in 1:
			await process_frame
		st._sync_yard_notice_cover()
	if second != null and second.is_valid():
		second.custom_step(10.0)
	for _i in 1:
		await process_frame
	if st.obs_float.visible or bool(st.obs_float.get_meta("yard_notice_live", false)):
		_bad("C14 %s expiry left the float up" % tag)
	st._show_menu()
	for _i in 1:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	for _i in 1:
		await process_frame
	st._sync_yard_notice_cover()
	if st.obs_float.visible:
		_bad("C14 %s expired float returned" % tag)
	if bool(st.game.flags.get("seen_obs_marks", false)) != marks or bool(st.game.flags.get("seen_obs_kit", false)) != kit:
		_bad("C14 %s once flags rewritten" % tag)
	if not _same_flags(st.game, flags):
		_bad("C14 %s yard flags rewritten" % tag)
	print("C14 %s ok" % tag)


func _c15(st, tag: String) -> void:
	_home(st)
	st._hide_radio()
	if st.vo_pill != null:
		st.vo_pill.visible = false
		st.vo_text_until = 0
	# Yard first, then the map.
	st._show_radio("Cable radio over the map legend.", 30.0)
	_station_chatter(st)
	for _i in 1:
		await process_frame
	if not st.radio_panel.visible:
		_bad("C15 %s radio hidden on the yard" % tag)
		return
	var hold: Tween = st.radio_tween
	if not st.showing_network:
		st._toggle_network()
	for _i in 3:
		await process_frame
	st.network_view._open_legend()
	for _i in 2:
		await process_frame
	st._sync_chatter_cover()
	_assert_legend_clear(st, "C15 %s map" % tag)
	_assert_hold(st, "C15 %s map" % tag)
	if hold == null or st.radio_tween != hold:
		_bad("C15 %s map replaced the radio hold" % tag)
	st.network_view._close_legend()
	for _i in 1:
		await process_frame
	st._sync_chatter_cover()
	_assert_legend_clear(st, "C15 %s slip" % tag)
	if st.showing_network:
		st._toggle_network()
	for _i in 2:
		await process_frame
	st._sync_chatter_cover()
	if st.radio_hold and not st.radio_panel.visible:
		_bad("C15 %s radio did not return to the yard" % tag)
	# Map first, then the radio.
	if not st.showing_network:
		st._toggle_network()
	for _i in 2:
		await process_frame
	st.network_view._open_legend()
	st._show_radio("Cable radio over the map legend.", 30.0)
	_station_chatter(st)
	for _i in 2:
		await process_frame
	st._sync_chatter_cover()
	_assert_legend_clear(st, "C15 %s open-first" % tag)
	_assert_hold(st, "C15 %s open-first" % tag)
	if tag == "ru 125":
		await _shot(st, "c15_radio_legend_ru_125_after")
	# Twice back and forth.
	for _i in 2:
		if st.showing_network:
			st._toggle_network()
		for _j in 1:
			await process_frame
		st._sync_chatter_cover()
		if st.radio_hold and not st.radio_panel.visible:
			_bad("C15 %s yard pass %d" % [tag, _i])
		if not st.showing_network:
			st._toggle_network()
		for _j in 2:
			await process_frame
		st.network_view._open_legend()
		for _j in 1:
			await process_frame
		st._sync_chatter_cover()
		_assert_legend_clear(st, "C15 %s repeat %d" % [tag, _i])
	# The hold can finish while the map is up. Closing the map must not bring it back.
	if st.radio_tween != null and st.radio_tween.is_valid():
		st.radio_tween.custom_step(40.0)
	for _i in 1:
		await process_frame
	if st.showing_network:
		st._toggle_network()
	for _i in 2:
		await process_frame
	st._sync_chatter_cover()
	if st.radio_hold or (st.radio_panel != null and st.radio_panel.visible):
		_bad("C15 %s expired radio returned" % tag)
	if st.vo_pill != null:
		st.vo_pill.visible = false
		st.vo_text_until = 0
	print("C15 %s ok" % tag)


func _assert_legend_clear(st, tag: String) -> void:
	var net = st.network_view
	if net == null:
		_bad(tag + " no map")
		return
	var blockers: Array[Rect2] = []
	if net.legend_panel != null and net.legend_panel.visible:
		blockers.append(net.legend_panel.get_global_rect())
	if net.legend_button != null and net.legend_button.visible:
		blockers.append(net.legend_button.get_global_rect())
	if net.has_method("legend_slip_rect"):
		var local: Rect2 = net.legend_slip_rect()
		if local.size.x > 1.0:
			var origin: Vector2 = net.get_global_transform() * local.position
			var far: Vector2 = net.get_global_transform() * local.end
			blockers.append(Rect2(origin, far - origin))
	if blockers.is_empty():
		_bad(tag + " no legend rect")
		return
	var mine: Rect2 = st._chatter_rect(st.radio_panel) if st.radio_panel != null else Rect2()
	if st.radio_panel != null and st.radio_panel.visible:
		for box in blockers:
			if st._rects_hit(mine, box):
				_bad("%s radio %s hits %s" % [tag, mine, box])
				return
	if st.vo_pill != null and st.vo_pill.visible and net.legend_panel != null and net.legend_panel.visible:
		if st._rects_hit(st._chatter_rect(st.vo_pill), net.legend_panel.get_global_rect()):
			_bad(tag + " station chatter hits the open legend")
			return
	var would := false
	for box in blockers:
		if st.radio_panel != null and st._rects_hit(mine, box):
			would = true
	if would and st.radio_hold and st.radio_panel.visible:
		_bad(tag + " radio stayed over the legend")


func _c4_tight(st, tag: String) -> void:
	_home(st)
	st._show_radio("Cable radio sits across the open Observer desk at a narrow width.", 30.0)
	st._show_observer()
	for _i in 2:
		await process_frame
	if st.observer_panel == null or not st.observer_panel.visible:
		_bad("C4 %s no observer" % tag)
		return
	var mine: Rect2 = st._chatter_rect(st.radio_panel)
	var desk: Rect2 = st.observer_panel.get_global_rect()
	if not mine.intersects(desk):
		_bad("C4 %s fixture does not overlap %s %s" % [tag, mine, desk])
	if st.radio_panel.visible:
		_bad("C4 %s radio still drawn over the desk" % tag)
	_assert_hold(st, "C4 %s" % tag)
	await _shot(st, "c4_radio_observer_tight_after")
	st._close_observer()
	for _i in 1:
		await process_frame
	st._sync_chatter_cover()
	if st.radio_hold and st.radio_panel != null and not st.radio_panel.visible:
		_bad("C4 %s radio stayed hidden after the desk" % tag)
	st._hide_radio()


func _c11(st, tag: String) -> void:
	_home(st)
	var flags := _flag_snap(st.game)
	_show_yards(st)
	for _i in 2:
		await process_frame
	if not _yard_order(st, "C11 %s yard" % tag):
		return
	var shown := _yard_visible(st)
	if shown != 8:
		_bad("C11 %s showed %d notices" % [tag, shown])
	if not st.showing_network:
		st._toggle_network()
	for _i in 2:
		await process_frame
	if _yard_visible(st) != 0:
		_bad("C11 %s %d notices still on the map" % [tag, _yard_visible(st)])
	st.network_view.open_visit(str(st.game.capital_id))
	for _i in 2:
		await process_frame
	if _yard_visible(st) != 0:
		_bad("C11 %s notices on Visit" % tag)
	if tag == "ru 125":
		await _shot(st, "c11_visit_ru_125_after")
	st.network_view.close_visit()
	for _i in 1:
		await process_frame
	if _yard_visible(st) != 0:
		_bad("C11 %s notices returned while the map is open" % tag)
	var paused := _yard_paused(st)
	if paused != 8:
		_bad("C11 %s paused %d holds" % [tag, paused])
	st._toggle_network()
	for _i in 2:
		await process_frame
	if _yard_visible(st) != 8:
		_bad("C11 %s back from map showed %d" % [tag, _yard_visible(st)])
	if not _yard_order(st, "C11 %s back" % tag):
		return
	st._show_menu()
	for _i in 2:
		await process_frame
	if _yard_visible(st) != 0:
		_bad("C11 %s notices over pause" % tag)
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	for _i in 1:
		await process_frame
	st._sync_yard_notice_cover()
	if _yard_visible(st) != 8:
		_bad("C11 %s pause resume %d" % [tag, _yard_visible(st)])
	var room_uid := ""
	for room in st.game.rooms:
		room_uid = str(room.uid)
		break
	if room_uid != "":
		st._show_room(room_uid)
		for _i in 2:
			await process_frame
		if st.dim == null or not st.dim.visible:
			_bad("C11 %s room card did not open" % tag)
		elif _yard_visible(st) != 8:
			_bad("C11 %s room card hid the notices" % tag)
		st._close_card()
		if st.dim != null:
			st.dim.visible = false
		for _i in 1:
			await process_frame
		st._sync_yard_notice_cover()
	st._show_observer()
	for _i in 2:
		await process_frame
	if _yard_visible(st) != 0:
		_bad("C11 %s notices over the desk" % tag)
	st._close_observer()
	for _i in 1:
		await process_frame
	st._sync_yard_notice_cover()
	if _yard_visible(st) != 8:
		_bad("C11 %s desk resume %d" % [tag, _yard_visible(st)])
	if not st.showing_network:
		st._toggle_network()
	st._toggle_network()
	for _i in 1:
		await process_frame
	if _yard_visible(st) != 8:
		_bad("C11 %s second return %d" % [tag, _yard_visible(st)])
	_end_yards(st)
	if not st.showing_network:
		st._toggle_network()
	st._toggle_network()
	for _i in 1:
		await process_frame
	if _yard_visible(st) != 0:
		_bad("C11 %s ended notices came back" % tag)
	if not _same_flags(st.game, flags):
		_bad("C11 %s once flags changed" % tag)
	_clear_yards(st)


func _c12_forward(st, tag: String) -> void:
	if not st.showing_network:
		st._toggle_network()
	for _i in 1:
		await process_frame
	var net = st.network_view
	_clear_map(net)
	for key in MAP:
		_show_map(net, key)
	if not _map_order(net, MAP, "C12 %s forward" % tag):
		return
	_clear_map(net)
	if st.showing_network:
		st._toggle_network()


func _c12_orders(st, tag: String) -> void:
	if not st.showing_network:
		st._toggle_network()
	for _i in 1:
		await process_frame
	var net = st.network_view
	_clear_map(net)
	var reverse: Array = MAP.duplicate()
	reverse.reverse()
	for key in reverse:
		_show_map(net, key)
	if not _map_order(net, MAP, "C12 %s reverse" % tag):
		return
	await _shot(st, "c12_stack_ru_125_after")
	for start in MAP.size():
		_clear_map(net)
		var turned: Array = []
		for i in MAP.size():
			turned.append(MAP[(start + i) % MAP.size()])
		for key in turned:
			_show_map(net, key)
		if not _map_order(net, MAP, "C12 %s rot %s" % [tag, MAP[start]]):
			_clear_map(net)
			return
	for key in MAP:
		_clear_map(net)
		for other in MAP:
			if other != key:
				_show_map(net, other)
		_show_map(net, key)
		if not _map_order(net, MAP, "C12 %s last %s" % [tag, key]):
			_clear_map(net)
			return
	_clear_map(net)
	for key in MAP:
		_show_map(net, key)
	for key in ["echo", "deal", "scar", "warm", "caller"]:
		_hide_map(net, key)
		var left: Array = []
		for other in MAP:
			if other != key and _map_up(net, other):
				left.append(other)
		if not _map_order(net, left, "C12 %s hide %s" % [tag, key]):
			_clear_map(net)
			return
		_show_map(net, key)
		if not _map_order(net, MAP, "C12 %s reshow %s" % [tag, key]):
			_clear_map(net)
			return
	_clear_map(net)
	for key in reverse:
		_show_map(net, key)
	var hiding: Array = MAP.duplicate()
	hiding.reverse()
	for key in hiding:
		_hide_map(net, key)
		var left: Array = []
		for other in MAP:
			if _map_up(net, other):
				left.append(other)
		if not _map_order(net, left, "C12 %s peel %s" % [tag, key]):
			_clear_map(net)
			return
	_clear_map(net)
	if st.showing_network:
		st._toggle_network()
	print("C12 %s orders ok" % tag)


func _c13(st) -> void:
	var cat: Catalog = st.game.catalog
	var game := Game.new()
	game.setup(cat, 1, 40)
	for key in ONCE:
		if bool(game.flags.get(key, false)):
			_bad("C13 setup marked %s" % key)
	game.scars["a|z"] = {"kind": "raid", "week": 2, "count": 1}
	if not bool(game.flags.get("seen_passage_scars", false)) and PassageScars.claim_first(game) == "":
		_bad("C13 fresh game refused a first scar")
	if not bool(game.flags.get("seen_passage_scars", false)):
		_bad("C13 claim_first did not set the scar flag")
	var begin := _fn(FileAccess.get_file_as_string("res://ui/station.gd"), "_begin_new_game")
	var setup := _fn(FileAccess.get_file_as_string("res://sim/game.gd"), "setup")
	for key in ONCE:
		if begin.find(key) >= 0 or setup.find(key) >= 0:
			_bad("C13 %s is written by new-game setup" % key)
	st._begin_new_game(false)
	for key in ONCE:
		if bool(st.game.flags.get(key, false)):
			_bad("C13 new game marked %s" % key)
	if FileAccess.file_exists("res://.tools/steam_shots.gd"):
		_bad("C13 steam_shots.gd exists; this gate expected no capture script")
	else:
		print("C13 capture script absent; once-flags stay unset on a new game")


func _show_yards(st) -> void:
	st._show_regular_yard(Copy.t("regular.first"))
	st._show_sday_yard(Copy.t("sday.first"))
	st._show_carry_yard(Copy.t("carry.first"))
	st._show_echo_yard(Copy.t("echo.first"))
	st._show_rival_yard(Copy.t("rival.first"))
	st._show_caller_yard(Copy.t("caller.first"))
	st._show_scar_yard(Copy.t("scar.first"))
	st._show_trace_float(Copy.t("trace.first"))


func _show_map(net, key: String) -> void:
	net.call("_show_%s_float" % key, Copy.t("scar.first"))


func _hide_map(net, key: String) -> void:
	var lab: Label = net.get("_%s_float" % key)
	if lab == null:
		return
	lab.visible = false
	var plate: Control = net._float_plate(lab)
	if plate != lab:
		plate.visible = false
	var tween: Tween = net.get("_%s_float_tween" % key)
	if tween != null and is_instance_valid(tween) and tween.is_valid():
		tween.kill()
	net._restack_map_floats()


func _map_up(net, key: String) -> bool:
	var lab: Label = net.get("_%s_float" % key)
	return lab != null and lab.visible


func _clear_map(net) -> void:
	for key in MAP:
		var lab: Label = net.get("_%s_float" % key)
		if lab == null:
			continue
		lab.visible = false
		var plate: Control = net._float_plate(lab)
		if plate != lab:
			plate.visible = false
		var tween: Tween = net.get("_%s_float_tween" % key)
		if tween != null and is_instance_valid(tween) and tween.is_valid():
			tween.kill()
	net._restack_map_floats()


func _map_order(net, keys: Array, tag: String) -> bool:
	var prev := -1.0
	var prev_rect := Rect2()
	var have := false
	for key in MAP:
		if not keys.has(key):
			continue
		var lab: Label = net.get("_%s_float" % key)
		if lab == null or not lab.visible:
			_bad("%s missing %s" % [tag, key])
			return false
		var plate: Control = net._float_plate(lab)
		var rect: Rect2 = plate.get_global_rect()
		if have:
			if plate.position.y < prev + 30.0:
				_bad("%s %s y %.1f after %.1f" % [tag, key, plate.position.y, prev])
				return false
			if rect.grow(-1.0).intersects(prev_rect.grow(-1.0)):
				_bad("%s %s overlaps" % [tag, key])
				return false
		prev = plate.position.y
		prev_rect = rect
		have = true
	return true


func _yard_order(st, tag: String) -> bool:
	var prev := -1.0
	var prev_rect := Rect2()
	var have := false
	for key in YARD:
		var plate: Control = st.get(key + "_float")
		if plate == null or not plate.visible:
			_bad("%s missing %s" % [tag, key])
			return false
		var rect: Rect2 = plate.get_global_rect()
		if have:
			if plate.position.y < prev + 8.0 or rect.grow(-1.0).intersects(prev_rect.grow(-1.0)):
				_bad("%s %s stacked %s on %s" % [tag, key, rect, prev_rect])
				return false
		prev = plate.position.y
		prev_rect = rect
		have = true
	return true


func _yard_visible(st) -> int:
	var n := 0
	for key in YARD:
		var plate: Control = st.get(key + "_float")
		if plate != null and plate.visible:
			n += 1
	return n


func _yard_paused(st) -> int:
	var n := 0
	for key in YARD:
		var plate: Control = st.get(key + "_float")
		if plate != null and bool(plate.get_meta("yard_notice_paused", false)):
			n += 1
	return n


func _end_yards(st) -> void:
	for key in YARD:
		var plate: CanvasItem = st.get(key + "_float")
		st._end_yard_notice(plate)


func _clear_yards(st) -> void:
	for key in YARD:
		var tween: Tween = st.get(key + "_float_tween")
		if tween != null and is_instance_valid(tween) and tween.is_valid():
			tween.kill()
		var node: Node = st.get(key + "_float")
		if node != null and is_instance_valid(node):
			node.queue_free()
		st.set(key + "_float", null)
		st.set(key + "_float_label", null)
		st.set(key + "_float_tween", null)


func _flag_snap(game) -> Dictionary:
	var snap := {}
	for key in ONCE:
		snap[key] = bool(game.flags.get(key, false))
	return snap


func _same_flags(game, snap: Dictionary) -> bool:
	for key in ONCE:
		if bool(game.flags.get(key, false)) != bool(snap.get(key, false)):
			return false
	return true


func _note_rows(st, tag: String) -> void:
	var net = st.network_view
	if net == null or net.visit == null:
		_bad(tag + " no visit")
		return
	for meta_name in ["toll_row", "scar_row", "ledger_row"]:
		pass
	var caller := _find_meta(net.visit, "caller_quote")
	if caller == null:
		caller = _find_meta(net.visit, "caller_title")
	if st.radio_panel != null and st.radio_panel.visible and caller != null:
		if st.radio_panel.get_global_rect().grow(-1.0).intersects(caller.get_global_rect().grow(-1.0)):
			_bad(tag + " radio covers the caller quote")


func _station_chatter(st) -> void:
	st.vo_text = "Station"
	st.vo_text_caption = Copy.t("Station")
	st.vo_text_until = Time.get_ticks_msec() + 20000
	st._tick_voice()
	st._sync_chatter_cover()


func _assert_hold(st, tag: String) -> void:
	if not st.radio_hold or st.radio_tween == null or not st.radio_tween.is_valid():
		_bad(tag + " hold was cleared")


func _assert_chatter_clear(st, panel: Control, tag: String) -> void:
	if panel == null or not panel.visible:
		_bad(tag + " panel missing")
		return
	if st.radio_panel != null and st.radio_panel.visible and _hit(st.radio_panel, panel):
		_bad(tag + " radio overlaps")
	if st.vo_pill != null and st.vo_pill.visible and _hit(st.vo_pill, panel):
		_bad(tag + " station chatter overlaps")


func _home(st) -> void:
	if st.showing_network:
		st._toggle_network()
	if st.observer_panel != null and st.observer_panel.visible:
		st._close_observer()
	if st.network_view != null:
		st.network_view.close_visit()
		if st.network_view.has_method("close_sheet"):
			st.network_view.close_sheet()
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	st.at_menu = false
	st._sync_yard_notice_cover()
	st._sync_chatter_cover()


func _view(st, win_size: Vector2i) -> void:
	var win: Window = st.get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	win.content_scale_factor = 1.0
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_size = win_size
	for _i in 2:
		await process_frame
	st._layout()
	await process_frame


func _close_button(panel: Node) -> Button:
	return _find_close(panel)


func _find_close(node: Node) -> Button:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and str(here.get_meta("obs_focus", "")) == "close":
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _find_meta(node: Node, key: String) -> Control:
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


func _hit(a: Control, b: Control) -> bool:
	if a == null or b == null:
		return false
	return a.get_global_rect().grow(-1.0).intersects(b.get_global_rect().grow(-1.0))


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.length()
	for marker in ["\nfunc ", "\nstatic func "]:
		var found := src.find(marker, at + 4)
		if found >= 0 and found < next:
			next = found
	return src.substr(at, next - at)


func _shot_dir() -> String:
	var dir := OS.get_environment("UNDERLINE_SHOTS_DIR")
	if dir == "":
		for arg in OS.get_cmdline_user_args():
			if str(arg).begins_with("--shots-dir="):
				dir = str(arg).trim_prefix("--shots-dir=")
	if dir == "":
		dir = "user://chrome_nits"
	if dir.begins_with("user://") or dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	return dir


func _renderer_live() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


func _shot(st, name: String) -> void:
	if not _renderer_live():
		_shots_skipped = true
		print("CHROME SHOT SKIP %s no renderer" % name)
		return
	await process_frame
	RenderingServer.force_draw()
	var tex: ViewportTexture = st.get_viewport().get_texture()
	var img: Image = null
	if tex != null:
		img = tex.get_image()
	if img == null or img.get_width() < 2:
		_bad("no image " + name)
		return
	var dir := _shot_dir()
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and not DirAccess.dir_exists_absolute(dir):
		_bad("shot dir %s err %s" % [dir, str(made)])
		return
	var err := img.save_png(dir.path_join(name + ".png"))
	if err != OK:
		_bad("shot %s err %s" % [name, str(err)])
		return
	_shots_saved += 1
	print("CHROME SHOT %s" % dir.path_join(name + ".png"))


func _shots_note() -> void:
	if _shots_skipped:
		print("CHROME SHOTS SKIP no renderer")
	elif _shots_saved > 0:
		print("CHROME SHOTS %d %s" % [_shots_saved, _shot_dir()])


func _bad(msg: String) -> void:
	bad.append(msg)
