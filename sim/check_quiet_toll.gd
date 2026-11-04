extends SceneTree

const Toll = preload("res://sim/quiet_toll.gd")

## P86 Quiet Toll gate.
##   godot --path . -s res://sim/check_quiet_toll.gd
## Tip and Visit only. toll.skim is not wired. No map tick. No soft dawn chip.
## Careful loss on seeds 1–60 must stay on the master baseline of 2/60.

const BASELINE := 2


class Host extends Node:
	var game
	var shot_mode := true
	var motion_in_shots := false
	var net_guide := false
	var net_guide_sid := ""
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)

	func _ui_click() -> void:
		pass


var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("TOLL FAIL catalog")
		quit(1)
		return
	if _strings():
		print("Strings: ok")
	if _tip(catalog):
		print("Tip: ok")
	if await _visit(catalog):
		print("Visit: ok")
	if _dawn():
		print("Dawn: ok")
	if _skim():
		print("Skim: unwired")
	var band := _careful(catalog)
	var lost := int(band.lost)
	print("Play: careful toll line on %d/60 seeds (need_duty %d, qualifies %d, quiet %d)" % [
		int(band.seeds), int(band.need_duty), int(band.qualifies), int(band.quiet)])
	print("Careful loss: %d/60 (master baseline %d/60)" % [lost, BASELINE])
	if lost != BASELINE:
		_bad("careful loss %d/60 moved off the master baseline %d/60" % [lost, BASELINE])
	if failed:
		print("TOLL FAIL")
		quit(1)
	else:
		print("TOLL OK")
		quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/quiet_toll.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P86":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack dawn")
		return false
	var rows = pack.get("by_key", {})
	if not (rows is Dictionary):
		_bad("pack rows")
		return false
	var want := ["toll.name", "toll.tip", "toll.first", "toll.skim", "toll.status", "toll.status_none", "toll.need_duty", "toll.quiet"]
	if rows.size() != want.size():
		_bad("key count %d" % rows.size())
		return false
	for key in want:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty " + key)
			return false
	Copy.set_lang("en")
	for key in want:
		if Copy.t(key) != str(rows[key].get("en", "")):
			_bad("EN %s got %s" % [key, Copy.t(key)])
			return false
	Copy.set_lang("ru")
	for key in want:
		if Copy.t(key) != str(rows[key].get("ru", "")):
			_bad("RU %s got %s" % [key, Copy.t(key)])
			return false
	Copy.set_lang("en")
	if Copy.t("toll.first") != "Duty watches what passes.":
		_bad("first copy")
		return false
	if Copy.t("toll.need_duty") != "Post Duty to watch the flow.":
		_bad("need_duty copy")
		return false
	if Copy.t("toll.skim") != "Quiet Toll. A few mats off the flow.":
		_bad("skim copy")
		return false
	var src := FileAccess.get_file_as_string("res://sim/copy.gd")
	if src.find("res://data/quiet_toll.json") < 0:
		_bad("pack not merged")
		return false
	return true


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 8
	return game


func _pair(game: Game) -> Array:
	for sid in game.stations:
		var id := str(sid)
		if id == str(game.capital_id):
			continue
		var st: Dictionary = game.stations[id]
		if str(st.get("bunker", "")) != "" or bool(st.get("ruin", false)):
			continue
		if str(st.get("owner", "")) in ["bunker", "ruin"]:
			continue
		for other in game._neighbors(id):
			var far := str(other)
			if far == str(game.capital_id):
				continue
			if game.station_good(far).is_empty():
				continue
			var fst: Dictionary = game.stations[far]
			if str(fst.get("bunker", "")) != "" or bool(fst.get("ruin", false)):
				continue
			if str(fst.get("owner", "")) in ["bunker", "ruin"]:
				continue
			return [id, far]
	return ["", ""]


func _own(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.hidden = false
	st.passage = true


func _flow(game: Game, far: String, on: bool) -> void:
	var other: Dictionary = game.stations[far]
	other.hidden = false
	if str(other.get("owner", "")) == str(game.player):
		other.owner = "neutral"
	if on:
		other.known = true
		other.passage = true
		other.deals = maxi(1, int(other.get("deals", 0)))
	else:
		other.passage = false
		other.deals = 0


func _clear_duty(game: Game) -> void:
	for person in game.residents:
		if person.has("duty_edge_id"):
			person.erase("duty_edge_id")


func _post_duty(game: Game, sid: String) -> void:
	_clear_duty(game)
	if game.residents.is_empty():
		return
	game.residents[0]["duty_edge_id"] = Toll.edge_id(str(game.capital_id), sid)


func _stock(game: Game) -> Dictionary:
	return {
		"food": int(game.stock.food),
		"materials": int(game.stock.materials),
		"hope": int(game.hope),
		"discontent": int(game.discontent),
		"orders": int(game.orders_left),
	}


func _tip(catalog: Catalog) -> bool:
	if Toll.draws_map_tick() or Toll.skim_wired() or Toll.joins_soft_dawn():
		_bad("toll flags")
		return false
	if Game.SAVE_SCHEMA != 14:
		_bad("schema " + str(Game.SAVE_SCHEMA))
		return false
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	var far := str(pair[1])
	if sid == "" or far == "":
		_bad("no passage pair")
		return false
	var host := Host.new()
	host.game = game
	var view := NetworkView.new()
	view.host = host
	_own(game, sid)
	_flow(game, far, false)
	_clear_duty(game)
	if Toll.station_state(game, sid) != "" or Toll.tip_line(game, sid) != "":
		_bad("idle tip " + Toll.station_state(game, sid))
		return false
	if Toll.tip_line(game, far) != "" or Toll.tip_line(game, str(game.capital_id)) != "":
		_bad("foreign or capital tip")
		return false
	_flow(game, far, true)
	if not Toll.foreign_display(game, far):
		_bad("foreign display did not light on " + far)
		return false
	if Toll.station_state(game, sid) != "need_duty":
		_bad("need_duty state " + Toll.station_state(game, sid))
		return false
	var lined := view._tip(sid)
	var parts := lined.split("\n")
	if parts.is_empty() or parts[parts.size() - 1] != Copy.t("toll.need_duty"):
		_bad("need_duty tip [" + lined + "]")
		return false
	if lined.find(Copy.t("toll.tip")) >= 0 or lined.find(Copy.t("toll.quiet")) >= 0:
		_bad("need_duty showed another toll line")
		return false
	if bool(game.flags.get(Toll.FLAG, false)) or Toll.note(game) != "":
		_bad("need_duty floated")
		return false
	var before := _stock(game)
	_post_duty(game, sid)
	var qualified := view._tip(sid).split("\n")
	if Toll.station_state(game, sid) != "qualifies" or qualified.is_empty() or qualified[qualified.size() - 1] != Copy.t("toll.tip"):
		_bad("qualifies tip " + view._tip(sid))
		return false
	var first := Toll.note(game)
	if first != Copy.t("toll.first") or not bool(game.flags.get(Toll.FLAG, false)):
		_bad("first float " + first)
		return false
	if Toll.note(game) != "":
		_bad("second float")
		return false
	_flow(game, far, false)
	var quiet := view._tip(sid).split("\n")
	if Toll.station_state(game, sid) != "quiet" or quiet.is_empty() or quiet[quiet.size() - 1] != Copy.t("toll.quiet"):
		_bad("quiet tip " + view._tip(sid))
		return false
	if _stock(game) != before:
		_bad("tip moved stock or hope")
		return false
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	var loaded := Game.new()
	loaded.catalog = catalog
	if not loaded.import_state(snap) or not bool(loaded.flags.get(Toll.FLAG, false)):
		_bad("save dropped seen_quiet_toll")
		return false
	if str(loaded.residents[0].get("duty_edge_id", "")) != Toll.edge_id(str(game.capital_id), sid):
		_bad("save dropped duty_edge_id")
		return false
	return true


func _meta(node: Node, key: String) -> Array:
	var found: Array = []
	if node == null:
		return found
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here == null or not is_instance_valid(here):
			continue
		if here.has_meta(key):
			found.append(here)
		for child in here.get_children():
			stack.append(child)
	return found


func _visit(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var pair := _pair(game)
	var sid := str(pair[0])
	var far := str(pair[1])
	if sid == "" or far == "":
		_bad("visit pair")
		return false
	var host := Host.new()
	host.game = game
	var frame := SubViewport.new()
	frame.size = Vector2i(1280, 720)
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(frame)
	frame.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	view.custom_minimum_size = Vector2(1280, 720)
	frame.add_child(view)
	Settings.reduce_motion = true
	for _i in 3:
		await process_frame
	_own(game, sid)
	_flow(game, far, true)
	_clear_duty(game)
	game.flags.erase(Toll.FLAG)
	view.open_visit(sid)
	await process_frame
	if not _meta(view.visit, "toll_row").is_empty():
		_bad("need_duty drew a visit row")
		return false
	view.open_visit(str(game.capital_id))
	await process_frame
	if not _meta(view.visit, "toll_row").is_empty():
		_bad("capital visit row")
		return false
	view.open_visit(far)
	await process_frame
	if not _meta(view.visit, "toll_row").is_empty():
		_bad("foreign visit row")
		return false
	view.close_visit()
	view.open_sheet(sid)
	await process_frame
	if not _meta(view._sheet_body, "toll_row").is_empty():
		_bad("sheet drew a toll row")
		return false
	view.close_sheet()
	_post_duty(game, sid)
	_flow(game, far, false)
	view.open_visit(sid)
	await process_frame
	var muted := _meta(view.visit, "toll_row")
	if muted.size() != 1 or str(muted[0].get_meta("toll_kind")) != "none" or not bool(muted[0].get_meta("toll_muted")):
		_bad("status_none")
		return false
	if str(muted[0].text) != Copy.t("toll.status_none"):
		_bad("status_none text " + str(muted[0].text))
		return false
	if muted[0].get_index() != muted[0].get_parent().get_child_count() - 1:
		_bad("none row is not last in the status column")
		return false
	_flow(game, far, true)
	game.flags.erase(Toll.FLAG)
	var before := _stock(game)
	view.refresh()
	view.open_visit(sid)
	for _i in 3:
		await process_frame
	var row := _meta(view.visit, "toll_row")
	if row.size() != 1 or str(row[0].get_meta("toll_kind")) != "status" or bool(row[0].get_meta("toll_muted")):
		_bad("status row")
		return false
	if str(row[0].text) != Copy.t("toll.status"):
		_bad("status text " + str(row[0].text))
		return false
	if row[0].get_index() != row[0].get_parent().get_child_count() - 1:
		_bad("status row is not last in the status column")
		return false
	if view._toll_float == null or not view._toll_float.visible or view._toll_float.text != Copy.t("toll.first"):
		_bad("visit float")
		return false
	if not bool(view._toll_float.get_meta("toll_float_static", false)):
		_bad("float moved under reduce-motion")
		return false
	var y := view._toll_float.position.y
	var alpha := view._toll_float.modulate.a
	for _i in 3:
		await process_frame
	if not is_equal_approx(view._toll_float.position.y, y) or not is_equal_approx(view._toll_float.modulate.a, alpha):
		_bad("float was not static")
		return false
	if _stock(game) != before:
		_bad("visit moved stock or hope")
		return false
	if str(game.dawn_soft_chip().get("kind", "")) == "toll" or game.quiet_toll_dawn_chip():
		_bad("visit joined dawn")
		return false
	view.close_visit()
	if view._toll_float != null:
		view._toll_float.visible = false
	view._hover = sid
	view.origin = view._station_world(game.stations[sid])
	view._zoom_range()
	view.zoom = view._zoom_max
	view._clamp_view()
	view._redraw()
	var plate := _overlay(view, view._tip(sid))
	for _i in 3:
		await process_frame
	var tip_img := _grab(frame)
	if plate != null:
		plate.visible = false
	view.open_visit(sid)
	for _i in 3:
		await process_frame
	var visit_img := _grab(frame)
	var dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	if tip_img == null or visit_img == null or tip_img.get_width() < 100:
		_bad("screenshot")
		return false
	tip_img.save_png(dir + "/quiet_toll_edge_tip_after.png")
	visit_img.save_png(dir + "/quiet_toll_visit_after.png")
	Copy.set_lang("ru")
	view._fill_visit(sid)
	await process_frame
	row = _meta(view.visit, "toll_row")
	if row.size() != 1 or str(row[0].text) != "Тихая пошлина действует.":
		_bad("ru visit " + (str(row[0].text) if not row.is_empty() else "missing"))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	return true


func _overlay(view: NetworkView, tip: String) -> Control:
	var plate := PanelContainer.new()
	plate.position = Vector2(36, 36)
	plate.z_index = 20
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.07, 0.06, 0.05, 0.97)
	face.border_color = Color(0.93, 0.78, 0.42, 0.9)
	face.set_border_width_all(1)
	face.set_content_margin_all(10)
	plate.add_theme_stylebox_override("panel", face)
	var label := Label.new()
	label.text = tip
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("efe6d2"))
	plate.add_child(label)
	view.add_child(plate)
	return plate


func _grab(frame: SubViewport) -> Image:
	var tex := frame.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.get_width() < 2:
		return null
	return img


func _dawn() -> bool:
	var stack: Array = Game.DAWN_SOFT_STACK
	if stack != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(stack))
		return false
	var game := Game.new()
	if game.quiet_toll_dawn_chip() or game.dawn_soft_stack().has("toll") or game.dawn_soft_stack().has("quiet_toll"):
		_bad("dawn chip")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("toll") >= 0 or picker.find("quiet_toll") >= 0:
		_bad("dawn picker knows the toll")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	for draw_name in ["_draw_passage_edges", "_draw_ink", "_draw_pins", "_draw_pin"]:
		var body := _fn(view, draw_name)
		if body.find("QuietToll") >= 0 or body.find("toll_float") >= 0 or body.find("_add_quiet_toll") >= 0:
			_bad(draw_name + " draws a toll mark")
			return false
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if balance.find("quiet_toll") >= 0 or balance.find("toll.skim") >= 0 or balance.find("seen_quiet_toll") >= 0:
		_bad("balance mentions the toll")
		return false
	return true


func _skim() -> bool:
	for path in ["res://sim/quiet_toll.gd", "res://ui/network_view.gd", "res://sim/game.gd", "res://ui/station.gd", "res://sim/copy.gd"]:
		var src := FileAccess.get_file_as_string(path)
		if src.find("toll.skim") >= 0:
			_bad("toll.skim wired in " + path)
			return false
		if src.find("skim_once") >= 0:
			_bad("skim_once in " + path)
			return false
	if Toll.skim_wired():
		_bad("skim flag")
		return false
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var end := src.find("\nfunc ", at + 4)
	if end < 0:
		end = src.length()
	return src.substr(at, end - at)


func _careful(catalog: Catalog) -> Dictionary:
	var lost := 0
	var seeds := 0
	var need_duty := 0
	var qualifies := 0
	var quiet := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		var bot := Bot.new()
		bot.profile = "careful"
		var saw := {"need_duty": false, "qualifies": false, "quiet": false}
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
			for sid in game.stations:
				var state := Toll.station_state(game, str(sid))
				if saw.has(state):
					saw[state] = true
		if str(game.over) != "time":
			lost += 1
		if bool(saw.need_duty) or bool(saw.qualifies) or bool(saw.quiet):
			seeds += 1
		if bool(saw.need_duty):
			need_duty += 1
		if bool(saw.qualifies):
			qualifies += 1
		if bool(saw.quiet):
			quiet += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d line %d" % [run_seed, lost, seeds])
	return {"lost": lost, "seeds": seeds, "need_duty": need_duty, "qualifies": qualifies, "quiet": quiet}
