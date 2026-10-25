extends SceneTree

## The audience card after "Hear them out" with the third button, offer help (docs/briefs/cursor_offer_help.txt).
##   godot --path . -s res://.tools/help_shots.gd -- --lang=ru --size=1280x720
## Saves shots/help/<lang>_<size>/help_<faction>.png for all five leaders, help_disabled.png (the Synod with
## too little food) and help_reply.png (the leader's reply after help). Nothing is saved to a slot.

const LEADERS := ["depot", "directorate", "synod", "exchange", "black_flag"]

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
	out_dir = "help/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out_dir))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.week = 18
	game.pending = []
	game.white_pending = []
	game.order_reports = []
	for fid in LEADERS:
		await _card(fid, 40)
		await _shot("help_%s" % fid)
		st._close_card()
	await _card("synod", 2)
	await _shot("help_disabled")
	st._close_card()
	await _card("depot", 40)
	game.pending = []
	st._offer_help()
	st._close_card()
	await st._frame()
	await st._frame()
	await _shot("help_reply")
	quit(0)


func _card(fid: String, stores: int) -> void:
	var game = st.game
	game.stock.food = stores
	game.stock.tokens = stores
	game.stock.materials = stores
	game.audience = {"faction": fid, "week": game.week, "target": game.list_target() if fid == "directorate" else ""}
	st.audience_key = "%d:%s" % [game.week, fid]
	st.audience_heard = true
	st._refresh()
	st._show_audience()
	await st._frame()
	await st._frame()


func _shot(shot_name: String) -> void:
	await st._frame()
	st._save(out_dir + "/" + shot_name)
