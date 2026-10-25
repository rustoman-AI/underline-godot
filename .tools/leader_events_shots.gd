extends SceneTree

## Every leader consequence event card (data/events_leaders.json), plus how a regard change reads afterwards.
##   godot --path . -s res://.tools/leader_events_shots.gd -- --lang=ru --size=1280x720
## Saves shots/leader_events/<lang>_<size>/<event>.png, result_regard.png (decision results on the next card)
## and journal_regard.png. Stocks are topped up in memory so every choice is enabled; nothing is saved.
## The log has one FIT line per card: the card body against its scroll area (fits = no scrolling needed) and
## the lowest choice button against the bottom of the screen.

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
	out_dir = "leader_events/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out_dir))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.week = 12
	var worst := ""
	var fits := 0
	var events: Array = game.catalog.events.filter(func(ev): return ev.has("needs"))
	for ev in events:
		_stage(game)
		game._present_event(ev)
		st._refresh()
		st._show_dawn()
		await st._frame()
		await st._frame()
		var fit := _fit()
		print("FIT [%s %dx%d] %-24s %s" % [Copy.lang, size.x, size.y, str(ev.id), fit.line])
		if bool(fit.ok):
			fits += 1
		else:
			worst += " " + str(ev.id)
		await _shot(str(ev.id))
		st._close_card()
	print("FIT [%s %dx%d] %d of %d cards fit without scrolling%s" % [Copy.lang, size.x, size.y, fits, events.size(), "" if worst == "" else "; overflow:" + worst])

	_stage(game)
	var lamp: Dictionary = game._event_by_id("lc_lamp_refused")
	game._present_event(lamp)
	st._refresh()
	st._show_dawn()
	await st._frame()
	st._pick_event("lc_lamp_refused", "food")
	st._close_card()
	game.week += 1
	_stage(game)
	game._present_event(game._event_by_id("lc_exchange_accepted"))
	st._refresh()
	st._show_dawn()
	await st._frame()
	await st._frame()
	await _shot("result_regard")
	st._close_card()
	st.journal_filter = "decisions"
	st._show_journal()
	await st._frame()
	await st._frame()
	await _shot("journal_regard")
	quit(0)


func _stage(game) -> void:
	game.pending = []
	game.audience = {}
	game.week_event_ids = {}
	game.events_seen = {}
	game.stock.food = 60
	game.stock.tokens = 40
	game.stock.materials = 30


func _fit() -> Dictionary:
	var body: Control = st.card_body
	var scroll: Control = st.card_scroll
	var view: Rect2 = st.get_viewport().get_visible_rect()
	var lowest := 0.0
	for child in body.get_children():
		if child is Button:
			lowest = maxf(lowest, (child as Control).get_global_rect().end.y)
	var fits := body.size.y <= scroll.size.y + 1.0
	var on_screen := lowest <= view.end.y
	return {"ok": fits and on_screen, "line": "body %d / scroll %d px, lowest button %d of %d px: %s" % [
		int(body.size.y), int(scroll.size.y), int(lowest), int(view.end.y), "fits" if fits and on_screen else "SCROLLS"]}


func _shot(shot_name: String) -> void:
	await st._frame()
	st._save(out_dir + "/" + shot_name)
