extends SceneTree

## Story S2 shots (docs/briefs/cursor_story_engine_s2.txt):
##   godot --path . -s res://.tools/s2_shots.gd -- --lang=ru --size=1280x720
## Saves shots/s2/<lang>_<size>/: the three bunker scenes (scene_st3_floor shows a choice closed by trust,
## scene_st3_quarantine two closed choices), the Observatory order locked and open on a station sheet, the final
## decision with closed choices, and the epilogue of all eight endings (top and scrolled to the buttons).
## Nothing is saved to a slot.

const SHEET_STATION := "central"
const OVER_FOR := {"winter": "time", "collapse": "collapse", "hope": "hope", "revolt": "revolt", "capital": "capital"}

var st
var out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	st.hold_dawn = false
	var size: Vector2i = st._shot_size()
	await st._settle(size)
	out_dir = "s2/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out_dir))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.week = 24
	game.white_pending = []
	game.order_reports = []
	game.artifacts.iron = 1
	game.fragments = {"quarantine_path": {"known": true, "how": "honest", "week": 20}}
	for id in ["st3_floor", "st3_quarantine", "st3_observatory"]:
		await _scene(id)
		await _shot("scene_" + id)
		st._close_card()
	game.pending = []
	game.events_seen.erase("st3_observatory")
	await _sheet("observatory_locked")
	game.artifacts.words = 2
	game.fragments["synod_recording"] = {"known": true, "how": "honest", "week": 21}
	await _sheet("observatory_open")
	game.week = 34
	game.proof_extra = 2
	game.flags["floor_published"] = true
	game.fragments["depot_order"] = {"known": true, "how": "honest", "week": 12}
	await _scene("st3_decision")
	await _shot("decision")
	st._close_card()
	game.leader_answers = {"depot": {"answer": "accepted", "week": 6}, "synod": {"answer": "helped", "week": 10},
		"exchange": {"answer": "silence", "week": 14}, "black_flag": {"answer": "refused", "week": 18}}
	for id in Game.ENDINGS:
		game.over = str(OVER_FOR.get(id, id))
		st._show_ending()
		await _frames()
		await _shot("epilogue_%s" % id)
		st.card_scroll.scroll_vertical = int(st.card_body.size.y)
		await _frames()
		await _shot("epilogue_%s_end" % id)
		st._close_card()
	quit(0)


func _scene(id: String) -> void:
	var game = st.game
	game.pending = []
	game.week_event_ids = {}
	game.events_seen.erase(id)
	game._present_event(game._event_by_id(id))
	st._refresh()
	st._show_dawn()
	await _frames()


func _sheet(shot_name: String) -> void:
	var game = st.game
	for sid in game.stations:
		game.stations[sid].known = true
	if not st.showing_network:
		st._toggle_network()
	await _frames()
	var nv = st.network_view
	nv.open_sheet(SHEET_STATION)
	await _frames()
	for scroll in nv.sheet.find_children("*", "ScrollContainer", true, false):
		scroll.scroll_vertical = 100000
	await _frames()
	await _shot(shot_name)
	nv.close_sheet()
	st._toggle_network()
	await _frames()


func _frames() -> void:
	for i in 3:
		await st._frame()


func _shot(shot_name: String) -> void:
	await st._frame()
	st._save(out_dir + "/" + shot_name)
