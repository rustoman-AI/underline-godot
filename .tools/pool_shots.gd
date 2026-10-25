extends SceneTree

## Event pool batch 1 shots (docs/briefs/cursor_event_pool_1.txt):
##   godot --path . -s res://.tools/pool_shots.gd -- --lang=ru --size=1280x720
## Saves shots/pool1/<lang>_<size>/card_<id>.png for the longest new cards (or --cards=a,b) and prints whether
## the text and all three choices fit the card without scrolling and inside the window, and whose portrait and
## name stand over the card. Nothing is saved to a slot.

const CARDS := ["coney_errand", "maggie_salt", "bait_throw", "barnum_cabinet", "sylvia_tide", "fran_crate", "quiet_letter"]

var st
var out_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cards: Array = CARDS.duplicate()
	var folder := "pool1"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--dir="):
			folder = str(arg).trim_prefix("--dir=")
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
		if str(arg).begins_with("--cards="):
			cards = Array(str(arg).trim_prefix("--cards=").split(","))
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	st.hold_dawn = false
	var size: Vector2i = st._shot_size()
	await st._settle(size)
	out_dir = "%s/%s_%dx%d" % [folder, Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out_dir))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	var game = st.game
	game.white_pending = []
	game.order_reports = []
	var all_fit := true
	for id in cards:
		var ev: Dictionary = game._event_by_id(id)
		var who := str(ev.get("who", ""))
		if who != "":
			var rid: String = st._resident_id_named(who)
			print("WHO %s %s: %s" % [Copy.lang, id, "resident %s shown as %s, %s" % [rid, Copy.person(str(game.people[rid].name)), game.portrait_name(rid, st.portrait_names)] if rid != "" else "no resident named " + who])
		game.week = int(ev.get("min_week", 1))
		game.pending = []
		game.week_event_ids = {}
		game._present_event(ev)
		st._refresh()
		st._show_dawn()
		for i in 3:
			await st._frame()
		var fit := _fit(ev, Rect2(Vector2.ZERO, Vector2(size)))
		all_fit = all_fit and fit == ""
		print("FIT %s %s %s" % [Copy.lang, id, "ok" if fit == "" else fit])
		await st._frame()
		st._save(out_dir + "/card_" + id)
		st._close_card()
	print("POOL SHOTS %s" % ("FIT" if all_fit else "OVERFLOW"))
	quit(0)


func _fit(ev: Dictionary, screen: Rect2) -> String:
	var scroll: ScrollContainer = st.card_scroll
	var view := scroll.get_global_rect()
	if st.card_body.size.y > scroll.size.y + 1:
		return "card scrolls (%d of %d px)" % [int(st.card_body.size.y), int(scroll.size.y)]
	if not screen.encloses(view.grow(-1)):
		return "card outside the window"
	var missing: Array = []
	for choice in ev.choices:
		var label := Copy.t(str(choice.label))
		var found := false
		for node in st.find_children("*", "Button", true, false):
			var button := node as Button
			if button.is_visible_in_tree() and button.text.contains(label):
				var rect := button.get_global_rect()
				found = screen.encloses(rect) and button.get_minimum_size().x <= rect.size.x + 1
		if not found:
			missing.append(str(choice.id))
	return "" if missing.is_empty() else "choices clipped or missing: " + ", ".join(missing)
