extends SceneTree

## The journal's Truth page with 0, 2 and 5 fragments known (docs/briefs/cursor_story_engine.txt).
##   godot --path . -s res://.tools/truth_shots.gd -- --lang=ru --size=1280x720
## Saves shots/truth/<lang>_<size>/truth_0.png, truth_2.png, truth_5.png and truth_5_end.png (scrolled to the
## bottom). Fragments, artifacts and stories heard are set in memory only; nothing is saved. One FIT line per
## page: the page against its scroll area.

const STAGES := {
	0: {},
	2: {"depot_order": "honest", "synod_recording": "dirty"},
	5: {"depot_order": "honest", "synod_recording": "dirty", "directorate_ledger": "honest", "exchange_papers": "dirty", "quarantine_path": "found"},
}

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
	out_dir = "truth/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out_dir))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.week = 24
	game.pending = []
	game.white_pending = []
	game.audience = {}
	game.order_reports = []
	var stories: Array = Voice.of_type("story").map(func(row): return str(row.id))
	for known in STAGES:
		game.fragments = {}
		game.journal = []
		game.story_words = 0
		game.artifacts = {"papers": 0, "iron": 0, "words": 0}
		var week := 6
		for id in STAGES[known]:
			game.week = week
			game.know_fragment(str(id), str(STAGES[known][id]))
			week += 3
		game.week = 24
		game.artifacts.papers = int(known) / 2
		game.artifacts.iron = 1 if int(known) == 5 else 0
		for sid in game.vo_heard.keys():
			game.vo_heard.erase(sid)
		for i in int(known) + 2:
			game.hear_story(str(stories[i]))
		st._refresh()
		st.journal_filter = "truth"
		st._show_journal()
		await st._frame()
		await st._frame()
		var body: Control = st.card_body
		var scroll: Control = st.card_scroll
		print("FIT [%s %dx%d] truth_%d page %d / scroll %d px: %s" % [Copy.lang, size.x, size.y, int(known),
			int(body.size.y), int(scroll.size.y), "fits" if body.size.y <= scroll.size.y + 1.0 else "scrolls"])
		await _shot("truth_%d" % int(known))
		if int(known) == 5:
			(scroll as ScrollContainer).scroll_vertical = int(body.size.y)
			await st._frame()
			await st._frame()
			await _shot("truth_5_end")
		st._close_card()
	quit(0)


func _shot(shot_name: String) -> void:
	await st._frame()
	st._save(out_dir + "/" + shot_name)
