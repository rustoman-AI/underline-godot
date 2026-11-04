extends SceneTree

## P82 Signal Chain gate.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://sim/check_signal_chain.gd

const STRINGS := {
	"signal.name": ["Signal Chain", "Сигнальная цепь"],
	"signal.tip": ["Signal Chain. The Post hears along the Line.", "Сигнальная цепь. Пост слышит по всей Линии."],
	"signal.first": ["The Line carries a whisper.", "Линия несёт шёпот."],
	"signal.lost": ["Signal Chain quiet. Post dark.", "Сигнальная цепь молчит. Пост погас."],
	"signal.status": ["Chain live along the Line.", "Цепь жива вдоль Линии."],
	"signal.status_none": ["No Signal Chain.", "Сигнальной цепи нет."],
	"signal.probe_lean": ["Chain Probe. Costs less this week.", "Зонд по цепи. На этой неделе дешевле."],
	"signal.quiet": ["Chain hears nothing new.", "Цепь ничего нового не слышит."],
}
const ART := {
	"res://assets/icons/map/signal_mark.png": "91e2cb4724b8643997318a5ace69b698",
	"res://assets/icons/map/signal_mark_24.png": "15dcef5aeb853e5523aa9e79f09dc5e4",
}
const MASTER_CAREFUL := 2


class Host extends Node:
	var game
	var shot_mode := true
	var motion_in_shots := false


class Diagram extends Control:
	var view: NetworkView
	var pin_r := 16.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a140e"))
		if view == null:
			return
		var at := size * 0.5
		draw_circle(at, pin_r, Color("3a3126"))
		draw_arc(at, pin_r, 0, TAU, 48, Color("efe4c8"), 1.2, true)
		_disc(at + Vector2(pin_r * view.FOCUS_OFFSET.x, pin_r * view.FOCUS_OFFSET.y), view.FOCUS_DISC, Color("efe4c8"), "F")
		_disc(at + Vector2(pin_r * view.GOODS_OFFSET.x, pin_r * view.GOODS_OFFSET.y), view.GOODS_PIP_R * 2.0, Color("d7a441"), "")
		for i in 3:
			var pip := Vector2((float(i) - 1.0) * 7.0, pin_r + 8.0)
			draw_circle(at + pip, 2.8, Color("e2a63a"))
		var leaf := LeafletDust.chip_px(pin_r)
		var near := Vector2(LeafletDust.NEAR.x * pin_r, LeafletDust.NEAR.y * pin_r)
		draw_rect(Rect2(at + near - Vector2(leaf, leaf) * 0.5, Vector2(leaf, leaf)), Color("efe4c8", 0.8))
		_disc(at + Vector2(pin_r * view.RELAY_OFFSET.x, pin_r * view.RELAY_OFFSET.y), view.RELAY_DISC, Color("8a7048"), "R")
		var sig: Vector2 = at + view.signal_mark_offset(pin_r)
		draw_arc(sig, view.SIGNAL_DISC * 0.5, 0, TAU, 24, Color("c9a050"), 1.6, true)


	func _disc(pos: Vector2, dia: float, col: Color, glyph: String) -> void:
		draw_circle(pos, dia * 0.5, col)
		if glyph == "":
			return
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, pos + Vector2(-w * 0.5, 4.0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("2b2118"))


var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("SIGNAL CHECK FAILED: " + catalog.error)
		quit(1)
		return
	if not _strings():
		_failed = true
	else:
		print("strings ok")
	if not _chain(catalog):
		_failed = true
	else:
		print("chain ok")
	if not await _map(catalog):
		_failed = true
	else:
		print("map ok")
	if not _dawn():
		_failed = true
	else:
		print("dawn ok")
	if not _art():
		_failed = true
	else:
		print("art ok")
	await _shots(catalog)
	var lost := _careful(catalog)
	var pct := 100.0 * float(lost) / 60.0
	print("careful loss: %d/60 (%.1f%%) master baseline %d/60" % [lost, pct, MASTER_CAREFUL])
	if lost != MASTER_CAREFUL:
		_bad("careful loss moved off %d/60" % MASTER_CAREFUL)
	if _failed:
		print("SIGNAL CHECK FAILED")
		quit(1)
		return
	print("SIGNAL OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var ok := true
	for key in STRINGS:
		var pair: Array = STRINGS[key]
		Copy.set_lang("en")
		if Copy.t(key) != str(pair[0]):
			_bad("en %s = %s" % [key, Copy.t(key)])
			ok = false
		Copy.set_lang("ru")
		if Copy.t(key) != str(pair[1]):
			_bad("ru %s = %s" % [key, Copy.t(key)])
			ok = false
	Copy.set_lang("en")
	if Copy.t("Signal Chain quiet. Post dark.") != "Signal Chain quiet. Post dark.":
		_bad("ru.json leaked into en")
		ok = false
	Copy.set_lang("ru")
	if Copy.t("Signal Chain quiet. Post dark.") != "Сигнальная цепь молчит. Пост погас.":
		_bad("ru.json lost " + Copy.t("Signal Chain quiet. Post dark."))
		ok = false
	Copy.set_lang("en")
	var raw := FileAccess.get_file_as_string("res://data/signal_chain.json")
	if raw.find("\"_roadmap\": \"P82\"") < 0:
		_bad("roadmap is not P82")
		ok = false
	if raw.find("chain.") >= 0 and raw.find("\"signal.") < 0:
		_bad("namespace drifted")
		ok = false
	return ok


func _chain(catalog: Catalog) -> bool:
	if Game.SAVE_SCHEMA != 14:
		_bad("schema bumped to %d" % Game.SAVE_SCHEMA)
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 14") < 0:
		_bad("schema literal drifted")
		return false
	var game := Game.new()
	game.setup(catalog, 3, 40)
	if game.signal_live() or not game.signal_members().is_empty():
		_bad("chain live before the post")
		return false
	if game.signal_status_key(game.capital_id) != "signal.status_none":
		_bad("home status before the post: " + game.signal_status_key(game.capital_id))
		return false
	var radio = _place(game, "radio")
	var post = _place(game, "listening_post")
	if radio == null or post == null:
		_bad("rooms did not place")
		return false
	if game.build_possible("listening_post"):
		_bad("a second listening post is buildable")
		return false
	_staff(game, radio)
	_staff(game, post)
	if not game.listening_active() or not game.signal_live():
		_bad("staffed post did not form a chain")
		return false
	var home := str(game.capital_id)
	if not game.signal_on(home):
		_bad("home is not the root")
		return false
	var hop1 := _step(game, home, [home])
	var hop2 := _step(game, hop1, [home, hop1])
	var hop3 := _step(game, hop2, [home, hop1, hop2])
	if hop1 == "" or hop2 == "" or hop3 == "":
		_bad("map has no 3-hop walk from home")
		return false
	_own(game, hop1)
	_own(game, hop2)
	_own(game, hop3)
	var members := game.signal_members()
	if not members.has(hop1) or not members.has(hop2):
		_bad("owned hops 1-2 missing: " + str(members))
		return false
	if members.has(hop3):
		_bad("hop 3 joined")
		return false
	var far := ""
	for sid in game.stations:
		var id := str(sid)
		if game.signal_on(id) or game.signal_linked(id):
			continue
		var row: Dictionary = game.stations[id]
		if str(row.get("bunker", "")) != "" or str(row.owner) in ["bunker", "ruin"]:
			continue
		if bool(row.get("hidden", false)):
			continue
		far = id
		break
	if far == "":
		_bad("every station is on or beside the chain")
		return false
	var hidden := _step(game, hop1, [home, hop1, hop2, hop3])
	if hidden != "":
		_own(game, hidden)
		game.stations[hidden]["hidden"] = true
		if game.signal_on(hidden):
			_bad("hidden station joined")
			return false
	var foreign := ""
	for member in game.signal_members():
		for n in game._neighbors(str(member)):
			var sid := str(n)
			if game.signal_on(sid) or str(game.stations[sid].owner) == str(game.player):
				continue
			var st: Dictionary = game.stations[sid]
			if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
				continue
			foreign = sid
			break
		if foreign != "":
			break
	if foreign == "":
		_bad("no foreign neighbour of the chain")
		return false
	game.stations[foreign]["known"] = true
	if game.signal_on(foreign):
		_bad("foreign station joined")
		return false
	if not game.signal_linked(foreign) or not game.signal_linked(hop1):
		_bad("lean target is not on or beside the chain")
		return false
	var blown_p := game.listening_blown_chance("probe")
	var blown_t := game.listening_blown_chance("tap")
	if not is_equal_approx(blown_p, float(game.bal.get("probe_blown", 0.15))) or not is_equal_approx(blown_t, float(game.bal.get("tap_blown", 0.25))):
		_bad("blown chance moved %.3f %.3f" % [blown_p, blown_t])
		return false
	var base := int(game.bal.get("probe_tokens", 3))
	if base != 3:
		_bad("probe_tokens is %d" % base)
		return false
	if game.probe_token_cost(foreign) != base - 1 or game.probe_token_cost(hop1) != base - 1:
		_bad("lean cost %d / %d" % [game.probe_token_cost(foreign), game.probe_token_cost(hop1)])
		return false
	if game.probe_token_cost(far) != base:
		_bad("far probe cost %d" % game.probe_token_cost(far))
		return false
	game.bal.probe_tokens = 2
	if game.probe_token_cost(foreign) != 2:
		_bad("min cost raised a 2-token probe to %d" % game.probe_token_cost(foreign))
		return false
	game.bal.probe_tokens = base
	game.stock.tokens = 12
	game.orders_left = 2
	game.bal.probe_blown = 0.0
	var before := int(game.stock.tokens)
	if not game.apply({"kind": "order", "order": "probe", "station": foreign}):
		_bad("probe did not apply: " + game.order_block("probe", foreign))
		return false
	if int(game.stock.tokens) != before - (base - 1):
		_bad("first probe spent %d" % (before - int(game.stock.tokens)))
		return false
	if not game.signal_lean_spent():
		_bad("lean was not marked spent")
		return false
	game.flags.erase("listening_order_week")
	game.orders_left = 2
	game.seat_used = {}
	var mid := int(game.stock.tokens)
	game.stations[foreign]["intel"] = 2
	if not game.apply({"kind": "order", "order": "probe", "station": foreign}):
		_bad("second probe did not apply")
		return false
	if int(game.stock.tokens) != mid - base:
		_bad("second probe spent %d" % (mid - int(game.stock.tokens)))
		return false
	if _notice(game, Copy.t("signal.quiet")) == "":
		_bad("quiet tip missing")
		return false
	var line := game.signal_note()
	if line != Copy.t("signal.first") or game.signal_note() != "":
		_bad("first float " + line)
		return false
	game.flags.erase("seen_signal_chain")
	_clear_staff(game, post)
	var n0 := game.notices.size()
	game.signal_sync()
	if game.signal_live() or game.signal_members().size() != 0:
		_bad("chain stayed after the post went dark")
		return false
	if game.notices.size() != n0 + 1 or str(game.notices[game.notices.size() - 1]) != Copy.t("signal.lost"):
		_bad("lost toast " + str(game.notices))
		return false
	game.signal_sync()
	if game.notices.size() != n0 + 1:
		_bad("lost toast repeated")
		return false
	if game.signal_status_key(home) != "signal.status_none":
		_bad("home status after the drop")
		return false
	_staff(game, post)
	game.signal_sync()
	if game.signal_status_key(hop1) != "signal.status" or game.signal_status_key(hop3) != "":
		_bad("visit status keys")
		return false
	return true


func _map(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	root.add_child(view)
	await process_frame
	if view.has_method("_zoom_range"):
		view._zoom_range()
	var zmax := float(view.get("_zoom_max"))
	var radius: float = view.signal_pin_radius(zmax, true)
	var report: Dictionary = view.signal_overlap_report(radius)
	var gaps: Dictionary = report.get("gaps", {})
	print("map pin r %.2f at zoom %.3f disc %.0f offset (%.2f, %.2f)" % [radius, zmax, view.SIGNAL_DISC, view.SIGNAL_OFFSET.x, view.SIGNAL_OFFSET.y])
	print("map gaps focus %.1f goods %.1f deal %.1f leaflet %.1f relay %.1f wired %.1f" % [
		float(gaps.get("focus", -1)), float(gaps.get("goods", -1)), float(gaps.get("deal", -1)),
		float(gaps.get("leaflet", -1)), float(gaps.get("relay", -1)), float(gaps.get("wired", -1)),
	])
	var hits: PackedStringArray = report.get("hits", PackedStringArray())
	if bool(report.get("omit", false)):
		print("map omit: %s" % ", ".join(hits))
	else:
		print("map placed")
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if src.find("SIGNAL_OFFSET := Vector2(0.32, -0.22)") < 0 or src.find("SIGNAL_DISC := 14.0") < 0:
		_bad("slot or disc drifted")
		return false
	if src.find("signal_mark_omitted()") < 0:
		_bad("draw does not honor the overlap omit")
		return false
	if src.find("str(game.capital_id)") < 0 or src.find("signal_on(sid)") < 0:
		_bad("home mark or chain gate missing")
		return false
	if bool(report.get("omit", false)) and src.find("if signal_mark_omitted():\n\t\treturn") < 0:
		_bad("omit does not skip the draw")
		return false
	view.queue_free()
	host.queue_free()
	return true


func _dawn() -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var game := Game.new()
	if game.signal_dawn_chip():
		_bad("signal joined the dawn stack")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var body := src.substr(at, src.find("func dawn_soft_chip", at) - at)
	if body.find("signal") >= 0:
		_bad("picker mentions signal")
		return false
	return true


func _art() -> bool:
	var ok := true
	for path in ART:
		var abs := ProjectSettings.globalize_path(path)
		var got := FileAccess.get_md5(abs)
		if got != str(ART[path]):
			_bad("md5 %s %s" % [path, got])
			ok = false
		var tex := ArtPack.icon_texture("signal_mark", 24.0 if path.ends_with("_24.png") else 256.0)
		if path.ends_with("_24.png") and (tex == null or tex.get_width() < 1):
			_bad("signal_mark_24 did not load")
			ok = false
	var tiny: Texture2D = ArtPack.icon_texture("signal_mark", 24.0)
	var full: Texture2D = ArtPack.load_texture("res://assets/icons/map/signal_mark.png")
	if tiny == null or full == null:
		_bad("signal mark texture missing")
		ok = false
	elif tiny.get_width() == full.get_width() and tiny.get_height() > 24:
		_bad("24 plate is the 256 plate")
		ok = false
	return ok


func _shots(catalog: Catalog) -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var game := Game.new()
	game.setup(catalog, 4, 40)
	var radio = _place(game, "radio")
	var post = _place(game, "listening_post")
	if radio == null or post == null:
		_bad("shot rooms missing")
		return
	_staff(game, radio)
	var home := str(game.capital_id)
	var hop1 := _step(game, home, [home])
	if hop1 == "":
		_bad("shot hop missing")
		return
	_own(game, hop1)
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var view := NetworkView.new()
	view.size = Vector2(1280, 720)
	view.custom_minimum_size = Vector2(1280, 720)
	view.host = host
	vp.add_child(view)
	for _i in 3:
		await process_frame
	view._zoom_range()
	view.open_visit(home)
	for _i in 2:
		await process_frame
	_grab(vp, "visit_before")
	view.close_visit()
	_frame_station(view, game, home)
	for _i in 2:
		await process_frame
	_grab(vp, "map_before")
	_staff(game, post)
	game.signal_sync()
	game.flags.erase("seen_signal_chain")
	view.open_visit(home)
	for _i in 2:
		await process_frame
	_grab(vp, "visit_after")
	view.close_visit()
	view.open_visit(hop1)
	for _i in 2:
		await process_frame
	_grab(vp, "visit_chain")
	view.close_visit()
	_frame_station(view, game, hop1)
	view.refresh()
	for other in [view._deal_float, view._warm_float, view._leaf_float, view._need_float, view._focus_float]:
		if other != null:
			other.visible = false
	view._place_signal_float()
	for _i in 2:
		await process_frame
	_grab(vp, "map_after")
	_grab(vp, "float")
	if view._signal_float != null:
		view._signal_float.visible = false
	_clear_staff(game, post)
	game.signal_sync()
	var toast := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = Color("efe4c8")
	face.border_color = Color("8a6a44")
	face.set_border_width_all(2)
	face.set_content_margin_all(12)
	toast.add_theme_stylebox_override("panel", face)
	toast.position = Vector2(390, 28)
	toast.z_index = 20
	var toast_line := Label.new()
	toast_line.text = Copy.t("signal.lost")
	toast_line.set_meta("signal_lost", true)
	toast_line.add_theme_font_size_override("font_size", 18)
	toast_line.add_theme_color_override("font_color", Color("2b2118"))
	toast.add_child(toast_line)
	view.add_child(toast)
	for _i in 2:
		await process_frame
	_grab(vp, "lost_toast")
	var diagram := Diagram.new()
	diagram.view = view
	diagram.pin_r = view.signal_max_pin_radius()
	var span := maxf(480.0, diagram.pin_r * 3.2)
	diagram.custom_minimum_size = Vector2(span, span)
	diagram.size = Vector2(span, span)
	var plate := SubViewport.new()
	plate.size = Vector2i(int(span), int(span))
	plate.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(plate)
	plate.add_child(diagram)
	for _i in 2:
		await process_frame
	_grab(plate, "overlap")
	await _room_shots(catalog)
	vp.queue_free()
	plate.queue_free()


func _frame_station(view: NetworkView, game: Game, sid: String) -> void:
	view.origin = view._station_world(game.stations[sid])
	view._zoom_range()
	view.zoom = view._zoom_max
	view._hover = sid
	view._clamp_view()
	view._redraw()


func _room_shots(catalog: Catalog) -> void:
	Settings.intro_seen = true
	var packed: PackedScene = load("res://ui/station.tscn")
	var station: Node = packed.instantiate()
	station.shot_mode = true
	station.set_anchors_preset(Control.PRESET_TOP_LEFT)
	station.position = Vector2.ZERO
	station.size = Vector2(1280, 720)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(station)
	for _i in 6:
		await process_frame
	if station.get("game") == null:
		_bad("station scene did not boot")
		vp.queue_free()
		return
	station.at_menu = false
	station.size = Vector2(1280, 720)
	if station.get("menu_layer") != null:
		station.menu_layer.visible = false
	if station.get("hub_layer") != null:
		station.hub_layer.visible = false
	for child in station.get_children():
		if child is CanvasLayer:
			child.visible = false
	var game: Game = station.game
	var radio = _place(game, "radio")
	var post = _place(game, "listening_post")
	if radio == null or post == null:
		_bad("room shot could not place the post")
		vp.queue_free()
		return
	_staff(game, radio)
	_staff(game, post)
	var home := str(game.capital_id)
	for n in game._neighbors(home):
		var sid := str(n)
		var st: Dictionary = game.stations[sid]
		if str(st.owner) == str(game.player) or str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
			continue
		st["known"] = true
	game.stock.tokens = 12
	game.orders_left = 2
	game.signal_sync()
	_clear_staff(game, post)
	game.signal_sync()
	station._open_card("Listening Post")
	station._listening_card(str(post.uid))
	if station.has_method("_layout"):
		station._layout()
	for _i in 4:
		await process_frame
	_grab(vp, "probe_before")
	_staff(game, post)
	game.flags.erase("signal_lean_week")
	game.orders_left = 2
	game.stock.tokens = 12
	game.signal_sync()
	station._open_card("Listening Post")
	station._listening_card(str(post.uid))
	if station.has_method("_layout"):
		station._layout()
	for _i in 4:
		await process_frame
	var scroll: ScrollContainer = station.get("card_scroll")
	if scroll != null:
		for node in station.card_body.get_children():
			if node.has_meta("signal_probe_lean"):
				scroll.scroll_vertical = int(node.position.y) - 80
				break
	for _i in 2:
		await process_frame
	_grab(vp, "probe_after")
	vp.queue_free()


func _grab(vp: SubViewport, name: String) -> void:
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		_bad("no viewport for " + name)
		return
	var img := tex.get_image()
	if img == null:
		_bad("no image for " + name)
		return
	var path := "/opt/cursor/artifacts/signal_%s.png" % name
	var err := img.save_png(path)
	print("shot %s %dx%d err %s" % [name, img.get_width(), img.get_height(), err])


func _careful(catalog: Catalog) -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var report: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(report.get("over", "")) != "time":
			lost += 1
			print("  loss seed %d over %s week %s" % [run_seed, report.get("over", ""), report.get("week", "")])
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost


func _place(game: Game, type: String):
	var cell := _open_cell(game)
	if cell.x < 0:
		return null
	game._place_room(type, cell.x, cell.y)
	for room in game.rooms:
		if str(room.type) == type:
			return room
	return null


func _open_cell(game: Game) -> Vector2i:
	for key in game.cells:
		var cell: Dictionary = game.cells[key]
		if game._cell_buildable(cell):
			return Vector2i(int(cell.level), int(cell.cell))
	return Vector2i(-1, -1)


func _staff(game: Game, room) -> void:
	if room == null:
		return
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or str(person.get("post", "")) != "":
			continue
		room.staff.append(str(person.id))
		person["post"] = str(room.uid)
		return


func _clear_staff(game: Game, room) -> void:
	if room == null:
		return
	for pid in room.staff:
		if game.people.has(str(pid)):
			game.people[str(pid)]["post"] = ""
	room.staff.clear()


func _own(game: Game, sid: String) -> void:
	if sid == "" or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.hidden = false


func _step(game: Game, sid: String, skip: Array) -> String:
	if sid == "":
		return ""
	for n in game._neighbors(sid):
		var nxt := str(n)
		if skip.has(nxt) or not game.stations.has(nxt):
			continue
		var st: Dictionary = game.stations[nxt]
		if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
			continue
		if bool(st.get("hidden", false)):
			continue
		return nxt
	return ""


func _notice(game: Game, needle: String) -> String:
	for line in game.notices:
		if str(line) == needle or str(line).find(needle) >= 0:
			return str(line)
	return ""
