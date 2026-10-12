extends SceneTree

## Clarity pass screenshots, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/clarity_shots.gd -- --lang=ru --size=1024x768
## Shots go to shots/clarity/<lang>_<WxH>/. Each shot also prints FIT lines: whether the card or notice is
## inside the window and whether the card had to scroll.
## Settings, saves and logs go to user://clarity_shots, not the player's.

const SCRATCH := "user://clarity_shots"

var st
var size := Vector2i(1280, 720)
var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
		if str(arg).begins_with("--size="):
			var wh := str(arg).trim_prefix("--size=").split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = true
	Settings.hints_seen = []
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	await st._settle(size)
	Settings.apply_scale(st.get_window())
	for _i in 4:
		await process_frame
	st._layout()
	out = "clarity/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))

	st._show_main_menu()
	st._show_howto(false)
	await _shot("howto", true)
	st._close_howto()
	st._open_settings(false)
	await _shot("settings_hints")
	st._show_main_menu()

	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending.clear()
	st._refresh()
	st._sync_waiting()
	await _shot("end_turn_ready")
	st.hints_in_shots = true
	st._tick_hints()
	await _shot("hint_" + st.hint_id)
	st._hide_hint()
	st.hints_in_shots = false

	var hydro := ""
	for room in st.game.rooms:
		if str(room.type) == "hydroponics":
			hydro = str(room.uid)
	if hydro != "":
		if st.game._room(hydro).staff.is_empty():
			st.game.apply({"kind": "staff"})
		st._show_room(hydro)
		await _shot("hydro_staffed", true)
		for id in st.game._room(hydro).staff.duplicate():
			st.game.apply({"kind": "unassign", "person": str(id)})
		st._refresh()
		st._show_room(hydro)
		await _shot("hydro_empty", true)
		st.help_unfold = true
		st._show_room(hydro)
		await _shot("hydro_help_open", true)
		st._close_card()
	st._open_build_list()
	await _shot("build_menu_help", true)
	st._close_card()

	var three := ""
	for ev in st.game.catalog.events:
		if ev.get("choices", []).size() == 3 and not ev.has("needs") and not ev.has("trigger") and not bool(ev.get("check_only", false)) and not bool(ev.get("chain_only", false)):
			three = str(ev.id)
			break
	st._offer_shot(three)
	await _shot("event_3_choices", true)
	st._close_card()
	st.game.pending.clear()
	st._refresh()
	st._sync_waiting()

	for fid in ["synod", "directorate"]:
		st.game.audience = {"faction": fid, "week": st.game.week, "target": st.game.list_target() if fid == "directorate" else ""}
		for key in ["food", "materials", "power", "air"]:
			st.game.stock[key] = maxi(int(st.game.stock[key]), 30)
		st._show_audience()
		st._hear_audience()
		await _shot("audience_" + fid, true)
		st._close_card()
		st.game.audience = {}

	st._toggle_network()
	await st._frame()
	st.network_view._fit()
	st._place_chrome()
	var sid: String = st.network_view.first_known_neighbor()
	st.network_view.open_sheet(sid if sid != "" else st.game.capital_id)
	await _shot("network_station_sheet")
	var visit: Control = null
	for node in st.network_view.sheet.find_children("*", "Button", true, false):
		if node.has_meta("visit_station"):
			visit = node
	for scroll in st.network_view.sheet.find_children("*", "ScrollContainer", true, false):
		if visit != null and scroll.is_ancestor_of(visit):
			scroll.ensure_control_visible(visit)
	print("VISIT button: %s, tooltip: %s" % [visit.text if visit != null else "missing", visit.tooltip_text if visit != null else ""])
	await _shot("network_station_sheet_actions")
	st.network_view.close_sheet()
	st._toggle_network()
	quit(0)


func _shot(name: String, card := false) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
	var view := Rect2(Vector2.ZERO, st.size)
	if card and st.notice_layer != null:
		var panels: Array = st.notice_layer.find_children("*", "PanelContainer", true, false)
		if not panels.is_empty():
			var box: Rect2 = panels[0].get_global_rect()
			print("FIT %s notice %s inside %s" % [name, "yes" if view.grow(1.0).encloses(box) else "NO", box])
	elif card:
		var box: Rect2 = st.card.get_global_rect()
		var scrolls: bool = st.card_scroll.get_v_scroll_bar().visible
		print("FIT %s card %s scroll %s %s" % [name, "inside" if view.grow(1.0).encloses(box) else "OUTSIDE", "YES" if scrolls else "no", box])
