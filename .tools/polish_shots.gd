extends SceneTree

## Screenshots for docs/briefs/cursor_polish_1.txt, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/polish_shots.gd -- --lang=ru --size=1280x720 [--only=banners|yard|cards|map]
## Saves to shots/polish_1/<lang>_<WxH>/. Settings, saves and logs go to user://polish_shots, not the player's.

const SCRATCH := "user://polish_shots"
const BANNER_STATIONS := ["riverside", "garden", "central", "signal"]

var st
var size := Vector2i(1280, 720)
var only := ""
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
		if str(arg).begins_with("--only="):
			only = str(arg).trim_prefix("--only=")
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
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
	out = "polish_1/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending.clear()
	st._refresh()
	for _i in 6:
		await process_frame
	if only == "" or only == "banners":
		await _banners()
	if only == "" or only == "yard":
		await _yard()
	if only == "" or only == "cards":
		await _cards()
	if only == "" or only == "map":
		await _map()
	quit(0)


## Event card, room card and build list; each prints whether the card stays inside the window.
func _cards() -> void:
	var game = st.game
	for ev in game.catalog.events:
		if ev.get("choices", []).size() >= 2 and not ev.has("trigger"):
			game.pending.append(ev.duplicate(true))
			break
	st._show_dawn()
	await _card_shot("card_event")
	st._close_card()
	for room in game.rooms:
		if str(room.type) == "generator":
			st._show_room(str(room.uid))
			break
	await _card_shot("card_room")
	st._close_card()
	game.stock.materials = maxi(int(game.stock.materials), 60)
	var floor_spot := Vector2i(-1, -1)
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if floor_spot.x < 0 and bool(spot.dug) and str(spot.room) == "":
				floor_spot = Vector2i(level, cell)
	if floor_spot.x < 0:
		for level in [2, 1]:
			for cell in 6:
				if floor_spot.x < 0 and bool(game.dig_preview(level, cell).get("ok", false)):
					floor_spot = Vector2i(level, cell)
		if floor_spot.x >= 0:
			game.cells["%d:%d" % [floor_spot.x, floor_spot.y]].dug = true
	st._refresh()
	st._open_build_list()
	await _card_shot("card_build")
	st._close_card()
	for ev in game.catalog.events:
		if str(ev.get("requires_room", "")) == "generator":
			game.pending.insert(0, ev.duplicate(true))
			break
	st._show_dawn()
	await st._frame()
	st._close_card()
	game.pending.clear()
	for room in game.rooms:
		if str(room.type) == "generator":
			st.yard._zoom_to(int(room.level), int(room.cell))
			break
	await _shot("yard_incident_sign")
	st.yard.fit()


func _card_shot(name: String) -> void:
	await _shot(name)
	var box: Rect2 = st.card.get_global_rect()
	var view := Rect2(Vector2.ZERO, st.size)
	var body_h: float = st.card_body.size.y
	var verdict := "fits"
	if body_h + 52.0 > box.size.y + 1.0:
		verdict = "scrolls"
	if not view.encloses(box) or st.card_body.size.x > st.card_scroll.size.x + 1.0:
		verdict = "OVERFLOW"
	print("CARD %s %s %dx%d: card %s, body %.0f, %s" % [name, Copy.lang, size.x, size.y, box, body_h, verdict])


## Territories on the whole map, then a neighbour's card closed and with Details open, on the visit sheet and
## the map sheet.
func _map() -> void:
	var game = st.game
	for each in game.stations:
		game.stations[each].known = true
		game.stations[each].hidden = false
	game.stock.influence = maxi(int(game.stock.influence), 12)
	st._refresh()
	st._toggle_network()
	await st._frame()
	var net = st.network_view
	net.set_territories(true)
	net.refresh()
	net._fit()
	await _shot("map_territories")
	var sid := ""
	for each in game.stations:
		if str(game.stations[each].owner) != str(game.player) and game.order_block("envoy", str(each)) == "":
			sid = str(each)
			break
	if sid != "":
		net.open_visit(sid)
		await _shot("station_card_closed")
		await _open_details(net.visit_sheet)
		await _shot("station_card_open")
		net.close_visit()
		net.open_sheet(sid)
		await _shot("station_sheet_closed")
		await _open_details(net.sheet)
		await _shot("station_sheet_open")
		net.close_sheet()
	st._toggle_network()
	await st._frame()


func _open_details(where: Node) -> void:
	for node in where.find_children("*", "Button", true, false):
		if node.has_meta("details_toggle") and not node.is_queued_for_deletion():
			node.button_pressed = true
			await st._frame()
			var scroll := where.find_children("*", "ScrollContainer", true, false)
			if not scroll.is_empty():
				scroll[0].ensure_control_visible(node)
				scroll[0].scroll_vertical += int(scroll[0].size.y * 0.6)


## Shots only: hydroponics loses its crew (food net below zero) and air is nearly gone, a dig starts, and one
## more cell is marked dug so the three cell states sit side by side.
func _yard() -> void:
	var game = st.game
	game.stock.materials = maxi(int(game.stock.materials), 40)
	for room in game.rooms:
		if str(room.type) == "hydroponics":
			room.staff.clear()
	game.stock.air = 3
	var spots: Array = []
	for level in [2, 1]:
		for cell in 6:
			if bool(game.dig_preview(level, cell).get("ok", false)):
				spots.append(Vector2i(level, cell))
	if spots.size() >= 2:
		var empty: Vector2i = spots[1]
		game.cells["%d:%d" % [empty.x, empty.y]].dug = true
		var dig: Vector2i = spots[0]
		if game.dig_preview(dig.x, dig.y).get("ok", false):
			game.apply({"kind": "dig", "level": dig.x, "cell": dig.y})
	st._refresh()
	for key in st.STOCK_KEYS:
		print("PILL %s %s: %s" % [Copy.lang, key, str(st.chips[key].get("alarm", ""))])
	st.yard.fit()
	await _shot("yard_whole")
	if not game.dig.is_empty():
		st.yard._zoom_to(int(game.dig.level), int(game.dig.cell))
		await _shot("yard_cells_dig")
	if spots.size() >= 2:
		st.yard._zoom_to(int(spots[1].x), int(spots[1].y))
		await _shot("yard_cells_dug_empty")
	for type in ["generator", "workshop"]:
		for room in game.rooms:
			if str(room.type) == type:
				st.yard._zoom_to(int(room.level), int(room.cell))
				await _shot("yard_people_" + type)
				break
	st.yard.fit()


func _banners() -> void:
	for each in st.game.stations:
		st.game.stations[each].known = true
		st.game.stations[each].hidden = false
	st._toggle_network()
	await st._frame()
	var net = st.network_view
	net.refresh()
	net._fit()
	for sid in BANNER_STATIONS:
		net.open_visit(sid)
		await _shot("banner_visit_" + sid)
		net.close_visit()
		net.open_sheet(sid)
		await _shot("banner_sheet_" + sid)
		net.close_sheet()
	st._toggle_network()
	await st._frame()


func _shot(name: String) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
