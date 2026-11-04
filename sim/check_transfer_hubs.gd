extends SceneTree

## P84 Transfer Hubs gate.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://sim/check_transfer_hubs.gd

const Hubs = preload("res://sim/transfer_hubs.gd")
const MASTER_CAREFUL := 2
const STRINGS := {
	"transfer.name": ["Transfer Hub", "Пересадка"],
	"transfer.tip": ["Transfer Hub. Three ways open.", "Пересадка. Три пути открыты."],
	"transfer.first": ["A junction on the Line.", "Развилка на Линии."],
	"transfer.lost": ["Hub quiet. Ways closed.", "Пересадка затихла. Пути закрыты."],
	"transfer.status": ["Transfer Hub.", "Пересадка."],
	"transfer.status_none": ["Not a Hub.", "Пересадки нет."],
	"transfer.mark": ["Hub", "Пересадка"],
	"transfer.quiet": ["No junction here.", "Здесь нет развилки."],
}
const ART := {
	"res://assets/icons/map/transfer_mark.png": "86a62eeb7720cdca60dd46eef9895bca",
	"res://assets/icons/map/transfer_mark_24.png": "cc56eb6906f1c172c56ea78affc7d70d",
}

var failed := false
var catalog: Catalog


class Host extends Node:
	var game
	var shot_mode := true
	var motion_in_shots := false
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)


class Diagram extends Control:
	var view: NetworkView
	var game
	var sid := ""
	var pin_r := 16.0

	func _draw() -> void:
		var at := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a140e"))
		draw_circle(at, pin_r, Color("3a3126"))
		draw_arc(at, pin_r, 0, TAU, 48, Color("efe4c8"), 1.4, true)
		if view == null:
			return
		_box(at + Vector2(pin_r * view.P57_FOCUS_OFFSET.x, pin_r * view.P57_FOCUS_OFFSET.y), view.P57_FOCUS_DISC, Color("efe4c8"), "F")
		_box(at + Vector2(pin_r * view.P55_GOODS_OFFSET.x, pin_r * view.P55_GOODS_OFFSET.y), view.P55_GOODS_R * 2.0, Color("d7a441"), "")
		var deal := Rect2()
		var first := true
		for i in 3:
			var pip := Vector2((float(i) - 1.0) * DealMarks.PIP_GAP, pin_r + DealMarks.PIP_DROP)
			var box := Rect2(at + pip - Vector2.ONE * DealMarks.PIP_R, Vector2.ONE * DealMarks.PIP_R * 2.0)
			deal = box if first else deal.merge(box)
			first = false
			draw_rect(box, Color("e2a63a"))
		draw_rect(deal, Color("e2a63a", 0.35), false, 1.0)
		var leaf := LeafletDust.chip_px(pin_r)
		for rel in [LeafletDust.NEAR, LeafletDust.OPPOSITE]:
			var leaf_at := at + Vector2(rel.x * pin_r, rel.y * pin_r)
			draw_rect(Rect2(leaf_at - Vector2(leaf, leaf) * 0.5, Vector2(leaf, leaf)), Color("efe4c8", 0.55), false, 1.0)
		_box(at + Vector2(pin_r * view.P78_RELAY_OFFSET.x, pin_r * view.P78_RELAY_OFFSET.y), view.P78_RELAY_DISC, Color("8a7048"), "R")
		_box(at + Vector2(pin_r * view.P82_SIGNAL_OFFSET.x, pin_r * view.P82_SIGNAL_OFFSET.y), view.P82_SIGNAL_DISC, Color("c9a050"), "")
		var mark_at := at + view.transfer_mark_offset(pin_r)
		draw_rect(Rect2(mark_at - Vector2(view.TRANSFER_DISC, view.TRANSFER_DISC) * 0.5, Vector2(view.TRANSFER_DISC, view.TRANSFER_DISC)), Color("c9a050"), false, 1.6)
		if game != null and sid != "":
			view._draw_transfer_mark(self, game, sid, at, pin_r, 0.0)
		var report: Dictionary = view.transfer_overlap_report(pin_r)
		var label := "omitted" if bool(report.get("omit", false)) else "placed"
		draw_string(ThemeDB.fallback_font, Vector2(12, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("efe4c8"))


	func _box(pos: Vector2, dia: float, col: Color, glyph: String) -> void:
		var box := Rect2(pos - Vector2(dia, dia) * 0.5, Vector2(dia, dia))
		draw_rect(box, Color(col, 0.35))
		draw_rect(box, col, false, 1.2)
		if glyph != "":
			draw_string(ThemeDB.fallback_font, pos + Vector2(-5, 5), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1a140e"))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("TRANSFER CHECK FAILED: " + catalog.error)
		quit(1)
		return
	if not _strings():
		failed = true
	else:
		print("strings ok")
	if not _hubs():
		failed = true
	else:
		print("hubs ok")
	if not await _map():
		failed = true
	else:
		print("map ok")
	if not _dawn():
		failed = true
	else:
		print("dawn ok")
	if not _art():
		failed = true
	else:
		print("art ok")
	await _shots()
	var lost := _careful()
	var pct := 100.0 * float(lost) / 60.0
	print("careful loss: %d/60 (%.1f%%) master baseline %d/60" % [lost, pct, MASTER_CAREFUL])
	if lost != MASTER_CAREFUL:
		_bad("careful loss moved off %d/60" % MASTER_CAREFUL)
	if failed:
		print("TRANSFER CHECK FAILED")
		quit(1)
		return
	print("TRANSFER OK")
	quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var ok := true
	Copy.set_lang("en")
	for key in STRINGS:
		var pair: Array = STRINGS[key]
		if Copy.t(str(key)) != str(pair[0]):
			_bad("en %s got %s" % [key, Copy.t(str(key))])
			ok = false
		if Copy.t(str(pair[0])) != str(pair[0]):
			_bad("en sentence %s" % key)
			ok = false
	Copy.set_lang("ru")
	for key in STRINGS:
		var pair: Array = STRINGS[key]
		if Copy.t(str(key)) != str(pair[1]):
			_bad("ru %s got %s" % [key, Copy.t(str(key))])
			ok = false
		if Copy.t(str(pair[0])) != str(pair[1]):
			_bad("ru.json %s got %s" % [key, Copy.t(str(pair[0]))])
			ok = false
	Copy.set_lang("en")
	var raw := FileAccess.get_file_as_string("res://data/transfer_hubs.json")
	if raw.find("\"_roadmap\": \"P84\"") < 0:
		_bad("roadmap is not P84")
		ok = false
	for banned in ["relay.", "duty.", "signal.", "ledger.", "toll."]:
		if raw.find("\"%s" % banned) >= 0:
			_bad("pack collides with %s" % banned)
			ok = false
	if STRINGS.size() != 8:
		_bad("string count")
		ok = false
	return ok


func _hubs() -> bool:
	if Game.SAVE_SCHEMA != 14:
		_bad("schema bumped to %d" % Game.SAVE_SCHEMA)
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 14") < 0:
		_bad("schema literal drifted")
		return false
	var balance_before := FileAccess.get_file_as_string("res://data/balance.json")
	var game := Game.new()
	game.setup(catalog, 3, 40)
	if Hubs.dawn_chip() or game.transfer_dawn_chip():
		_bad("dawn chip")
		return false
	var home := str(game.capital_id)
	if Hubs.is_hub(game, home):
		_bad("home is a hub before any passage")
		return false
	if Hubs.status_key(game, home) != "transfer.status_none":
		_bad("home status " + Hubs.status_key(game, home))
		return false
	var junction := _junction(game)
	if junction == "":
		_bad("map has no open junction")
		return false
	var ends := _ends(game, junction)
	if ends.size() < 3:
		_bad("junction %s degree %d" % [junction, ends.size()])
		return false
	_own(game, junction)
	for i in 2:
		game.stations[str(ends[i])].passage = true
	if Hubs.degree(game, junction) != 2 or Hubs.is_hub(game, junction):
		_bad("degree 2 counted as a hub (%d)" % Hubs.degree(game, junction))
		return false
	if Hubs.status_key(game, junction) != "transfer.status_none":
		_bad("not-hub status")
		return false
	if Hubs.tip_key(game, junction) != "transfer.quiet":
		_bad("quiet tip")
		return false
	var hope := int(game.hope)
	var mats := int(game.stock.materials)
	var food := int(game.stock.food)
	game.stations[str(ends[2])].passage = true
	if not Hubs.is_hub(game, junction) or Hubs.degree(game, junction) < 3:
		_bad("degree 3 did not form a hub (%d)" % Hubs.degree(game, junction))
		return false
	if Hubs.status_key(game, junction) != "transfer.status" or Hubs.tip_key(game, junction) != "transfer.tip":
		_bad("hub copy keys")
		return false
	if int(game.hope) != hope or int(game.stock.materials) != mats or int(game.stock.food) != food:
		_bad("hub granted stock or hope")
		return false
	var foreign := _foreign(game, junction)
	if foreign == "":
		_bad("no foreign station")
		return false
	var saved_owner := str(game.stations[foreign].owner)
	_own(game, foreign)
	for n in _ends(game, foreign):
		game.stations[str(n)].passage = true
	game.stations[foreign].owner = saved_owner
	if Hubs.is_hub(game, foreign):
		_bad("foreign station became a hub")
		return false
	if Hubs.status_key(game, foreign) != "":
		_bad("foreign status line")
		return false
	game.stations[junction].hidden = true
	if Hubs.is_hub(game, junction):
		_bad("hidden station stayed a hub")
		return false
	game.stations[junction].hidden = false
	var bunker := _tagged(game, "bunker")
	var ruin := _tagged(game, "ruin")
	if bunker == "" or ruin == "":
		_bad("missing bunker or ruin")
		return false
	if str(game.stations[bunker].get("bunker", "")) == "":
		game.stations[bunker]["bunker"] = "floor"
	game.stations[ruin]["ruin"] = true
	_force_hub(game, bunker)
	_force_hub(game, ruin)
	if Hubs.is_hub(game, bunker) or Hubs.is_hub(game, ruin):
		_bad("bunker or ruin became a hub")
		return false
	if not _capital(game):
		return false
	if not _clear(game, junction, str(ends[2])):
		return false
	if not _float_once(game, junction, ends):
		return false
	if not _save(game, junction):
		return false
	if FileAccess.get_file_as_string("res://data/balance.json") != balance_before:
		_bad("balance.json changed")
		return false
	return true


func _capital(game: Game) -> bool:
	var home := str(game.capital_id)
	var ends := _ends(game, home)
	var extra: Array = []
	for sid in game.stations:
		var id := str(sid)
		if id == home or ends.has(id) or Hubs.barred(game.stations[id]):
			continue
		extra.append(id)
		if ends.size() + extra.size() >= 3:
			break
	for id in extra:
		_link(game, home, str(id))
		ends.append(str(id))
	if ends.size() < 3:
		_bad("cannot give the capital three open ends")
		return false
	for i in 3:
		game.stations[str(ends[i])].passage = true
	if not Hubs.is_hub(game, home):
		_bad("capital with degree %d was not a hub" % Hubs.degree(game, home))
		return false
	if Hubs.status_key(game, home) != "transfer.status":
		_bad("capital status")
		return false
	game.stations[str(ends[0])].passage = false
	if Hubs.is_hub(game, home):
		_bad("capital stayed a hub after a way closed")
		return false
	return true


func _clear(game: Game, junction: String, _end: String) -> bool:
	for sid in game.stations:
		game.stations[sid].passage = false
	game.stations[junction].hidden = false
	_own(game, junction)
	var drop := ""
	var opened := 0
	for n in _ends(game, junction):
		if opened >= 3:
			break
		game.stations[str(n)].passage = true
		drop = str(n)
		opened += 1
	if opened < 3 or not Hubs.is_hub(game, junction):
		_bad("could not restore the junction hub (degree %d)" % Hubs.degree(game, junction))
		return false
	Hubs.sync(game, false)
	var before := game.notices.size()
	game.stations[drop].passage = false
	var end := drop
	if Hubs.is_hub(game, junction):
		_bad("hub survived a closed way")
		return false
	Hubs.sync(game, true)
	if game.notices.size() != before + 1 or str(game.notices.back()) != Copy.t("transfer.lost"):
		_bad("lost toast missing " + str(game.notices))
		return false
	Hubs.sync(game, true)
	if game.notices.size() != before + 1:
		_bad("lost toast repeated")
		return false
	game.stations[end].passage = true
	Hubs.sync(game, true)
	if game.notices.size() != before + 1:
		_bad("regaining a hub toasted")
		return false
	game.week += 1
	game.stations[end].passage = false
	Hubs.sync(game, true)
	if game.notices.size() != before + 2:
		_bad("a later week did not toast the next loss")
		return false
	game.stations[junction].owner = "neutral"
	if Hubs.is_hub(game, junction) or Hubs.status_key(game, junction) != "":
		_bad("lost ownership still reads as a hub")
		return false
	return true


func _float_once(game: Game, junction: String, ends: Array) -> bool:
	_own(game, junction)
	for i in mini(3, ends.size()):
		game.stations[str(ends[i])].passage = true
	game.flags.erase("seen_transfer_hub")
	if not Hubs.is_hub(game, junction):
		_bad("float fixture is not a hub")
		return false
	var line := Hubs.note(game)
	if line != Copy.t("transfer.first") or not bool(game.flags.get("seen_transfer_hub", false)):
		_bad("first float " + line)
		return false
	if Hubs.note(game) != "":
		_bad("first float repeated")
		return false
	return true


func _save(game: Game, junction: String) -> bool:
	SaveGame.root = "user://transfer_hubs_check"
	game.flags["seen_transfer_hub"] = true
	Hubs.sync(game, false)
	if not SaveGame.write_auto(game):
		_bad("save failed " + SaveGame.last_error)
		return false
	var loaded := Game.new()
	loaded.setup(catalog, 9, 40)
	if not SaveGame.load_latest(loaded):
		_bad("load failed " + SaveGame.last_error)
		return false
	if Game.SAVE_SCHEMA != 14:
		_bad("load bumped schema")
		return false
	if not bool(loaded.flags.get("seen_transfer_hub", false)):
		_bad("seen_transfer_hub did not round-trip")
		return false
	if not loaded.flags.has("transfer_hub_sids"):
		_bad("hub cache missing from the save")
		return false
	return true


func _map() -> bool:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	view.custom_minimum_size = Vector2(1280, 720)
	root.add_child(view)
	for _i in 3:
		await process_frame
	if view.has_method("_zoom_range"):
		view._zoom_range()
	var zmax := float(view.get("_zoom_max"))
	var outpost: float = view.transfer_pin_radius(zmax, true, false)
	var capital: float = view.transfer_pin_radius(zmax, true, true)
	var radius: float = view.transfer_max_pin_radius()
	var report: Dictionary = view.transfer_overlap_report(radius)
	var gaps: Dictionary = report.get("gaps", {})
	print("map pin r %.2f (outpost %.2f capital %.2f) at zoom %.3f disc %.0f offset (%.2f, %.2f)" % [
		radius, outpost, capital, zmax, view.TRANSFER_DISC, view.TRANSFER_OFFSET.x, view.TRANSFER_OFFSET.y,
	])
	print("map gaps focus %.1f goods %.1f deal %.1f leaflet %.1f relay %.1f signal %.1f" % [
		float(gaps.get("focus", -1)), float(gaps.get("goods", -1)), float(gaps.get("deal", -1)),
		float(gaps.get("leaflet", -1)), float(gaps.get("relay", -1)), float(gaps.get("signal", -1)),
	])
	var hits: PackedStringArray = report.get("hits", PackedStringArray())
	var outpost_report: Dictionary = view.transfer_overlap_report(outpost)
	var outpost_gaps: Dictionary = outpost_report.get("gaps", {})
	var outpost_hits: PackedStringArray = outpost_report.get("hits", PackedStringArray())
	print("map outpost gaps focus %.1f goods %.1f deal %.1f leaflet %.1f relay %.1f signal %.1f" % [
		float(outpost_gaps.get("focus", -1)), float(outpost_gaps.get("goods", -1)), float(outpost_gaps.get("deal", -1)),
		float(outpost_gaps.get("leaflet", -1)), float(outpost_gaps.get("relay", -1)), float(outpost_gaps.get("signal", -1)),
	])
	if bool(report.get("omit", false)):
		print("map omit: %s" % ", ".join(hits))
	else:
		print("map placed")
	if not outpost_hits.is_empty():
		print("map outpost hits: %s" % ", ".join(outpost_hits))
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if src.find("TRANSFER_OFFSET := Vector2(-0.32, 0.22)") < 0 or src.find("TRANSFER_DISC := 14.0") < 0:
		_bad("slot or disc drifted")
		return false
	if src.find("transfer_mark_omitted()") < 0:
		_bad("draw does not honor the overlap omit")
		return false
	if view.TRANSFER_OFFSET != Vector2(-0.32, 0.22) or not is_equal_approx(view.TRANSFER_DISC, 14.0):
		_bad("mark was shrunk or shifted")
		return false
	if outpost_hits.is_empty() == bool(outpost_report.get("omit", false)):
		_bad("outpost overlap flag disagrees with hits")
		return false
	if bool(report.get("omit", false)) != (not hits.is_empty()):
		_bad("max-radius omit flag disagrees with hits")
		return false
	if bool(report.get("omit", false)) != view.transfer_mark_omitted():
		_bad("draw omit disagrees with the max-radius report")
		return false
	view.queue_free()
	host.queue_free()
	return true


func _dawn() -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var game := Game.new()
	game.setup(catalog, 2, 40)
	if game.transfer_dawn_chip() or Hubs.dawn_chip():
		_bad("transfer joined the dawn stack")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var body := src.substr(at, src.find("func dawn_soft_chip", at) - at)
	if body.find("transfer") >= 0:
		_bad("picker mentions transfer")
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
	var tiny: Texture2D = ArtPack.icon_texture("transfer_mark", 24.0)
	var full: Texture2D = ArtPack.load_texture("res://assets/icons/map/transfer_mark.png")
	if tiny == null or full == null:
		_bad("transfer mark texture missing")
		ok = false
	elif tiny.get_width() < 1 or full.get_width() < 1:
		_bad("transfer mark texture empty")
		ok = false
	return ok


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var game := Game.new()
	game.setup(catalog, 5, 40)
	var junction := _junction(game)
	var ends := _ends(game, junction)
	if junction == "" or ends.size() < 3:
		_bad("shot junction missing")
		return
	_own(game, junction)
	game.stations[junction].known = true
	for i in 2:
		game.stations[str(ends[i])].passage = true
		game.stations[str(ends[i])].known = true
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
	for _i in 4:
		await process_frame
	view._zoom_range()
	_frame(view, game, junction)
	for _i in 2:
		await process_frame
	_grab(vp, "map_before")
	view.open_visit(junction)
	for _i in 3:
		await process_frame
	_show_status(view)
	for _i in 2:
		await process_frame
	_grab(vp, "visit_before")
	if view._transfer_float != null:
		view._transfer_float.visible = false
	_grab(vp, "float_before")
	view.close_visit()
	game.stations[str(ends[2])].passage = true
	game.stations[str(ends[2])].known = true
	game.flags.erase("seen_transfer_hub")
	view.open_visit(junction)
	for _i in 3:
		await process_frame
	_show_status(view)
	for _i in 2:
		await process_frame
	_grab(vp, "visit_after")
	view.close_visit()
	_frame(view, game, junction)
	view.refresh()
	for other in [view._deal_float, view._warm_float, view._leaf_float, view._need_float, view._focus_float]:
		if other != null:
			other.visible = false
	view._place_transfer_float()
	for _i in 2:
		await process_frame
	_grab(vp, "map_after")
	_grab(vp, "float_after")
	if view._transfer_float != null:
		view._transfer_float.visible = false
	_grab(vp, "toast_before")
	Hubs.sync(game, false)
	game.stations[str(ends[2])].passage = false
	Hubs.sync(game, true)
	var lost := ""
	if not game.notices.is_empty():
		lost = str(game.notices.pop_back())
	await _toast_shot(vp, view, lost)
	var diagram := Diagram.new()
	diagram.view = view
	diagram.game = game
	diagram.sid = junction
	game.stations[str(ends[2])].passage = true
	diagram.pin_r = view.transfer_max_pin_radius()
	var span := maxf(520.0, diagram.pin_r * 3.4)
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
	vp.queue_free()
	plate.queue_free()
	host.queue_free()


func _toast_shot(vp: SubViewport, view: NetworkView, line: String) -> void:
	if line == "":
		_bad("toast shot had no lost line")
		return
	var packed: PackedScene = load("res://ui/station.tscn")
	var station: Node = packed.instantiate()
	station.shot_mode = true
	station.set_anchors_preset(Control.PRESET_TOP_LEFT)
	station.position = Vector2.ZERO
	station.size = Vector2(1280, 720)
	var host_vp := SubViewport.new()
	host_vp.size = Vector2i(1280, 720)
	host_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host_vp)
	host_vp.add_child(station)
	for _i in 8:
		await process_frame
	station.at_menu = false
	station.showing_network = true
	if station.get("menu_layer") != null:
		station.menu_layer.visible = false
	if station.get("dawn_chip") != null:
		station.dawn_chip.visible = false
	if station.get("guide_layer") != null:
		station.guide_layer.visible = false
	if station.has_method("_close_card"):
		station._close_card()
	if station.get("network_view") != null:
		station.network_view.visible = true
	if station.get("yard") != null:
		station.yard.visible = false
	if station.has_method("_toast"):
		station._toast(line, 8.0)
	for _i in 3:
		await process_frame
	_grab(host_vp, "toast_after")
	host_vp.queue_free()
	if view != null and vp != null:
		pass


func _show_status(view: NetworkView) -> void:
	if view._visit_body == null:
		return
	var line := _find_meta(view._visit_body, "transfer_status")
	if line == null or not (line is Control):
		return
	var scroll := view._visit_body.get_parent()
	if scroll is ScrollContainer:
		var y: float = 0.0
		var walker: Node = line
		while walker != null and walker != view._visit_body:
			if walker is Control:
				y += (walker as Control).position.y
			walker = walker.get_parent()
		scroll.scroll_vertical = maxi(0, int(y) - 80)


func _find_meta(node: Node, key: String) -> Node:
	if node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _find_meta(child, key)
		if found != null:
			return found
	return null


func _frame(view: NetworkView, game: Game, sid: String) -> void:
	view.origin = view._station_world(game.stations[sid])
	view._zoom_range()
	view.zoom = view._zoom_max
	view._hover = sid
	view._clamp_view()
	view._redraw()


func _grab(vp: SubViewport, name: String) -> void:
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		_bad("no viewport for " + name)
		return
	var img := tex.get_image()
	if img == null:
		_bad("no image for " + name)
		return
	var path := "/opt/cursor/artifacts/transfer_%s.png" % name
	var err := img.save_png(path)
	print("shot %s %dx%d err %s" % [name, img.get_width(), img.get_height(), err])


func _careful() -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var report: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(report.get("over", "")) != "time":
			lost += 1
			print("  loss seed %d over %s week %s" % [run_seed, report.get("over", ""), report.get("week", "")])
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost


func _junction(game: Game) -> String:
	var best := ""
	var best_n := 0
	for sid in game.stations:
		var id := str(sid)
		if Hubs.barred(game.stations[id]):
			continue
		var n := _ends(game, id).size()
		if n > best_n:
			best = id
			best_n = n
	return best


func _ends(game: Game, sid: String) -> Array:
	var out: Array = []
	for other in game._neighbors(sid):
		var id := str(other)
		if game.stations.has(id) and not Hubs.barred(game.stations[id]):
			out.append(id)
	return out


func _own(game: Game, sid: String) -> void:
	game.stations[sid].owner = game.player
	game.stations[sid].known = true
	game.stations[sid].hidden = false


func _foreign(game: Game, skip: String) -> String:
	for sid in game.stations:
		var id := str(sid)
		if id == skip or id == str(game.capital_id):
			continue
		var st: Dictionary = game.stations[id]
		if Hubs.barred(st) or str(st.owner) == str(game.player):
			continue
		return id
	return ""


func _tagged(game: Game, kind: String) -> String:
	for sid in game.stations:
		var id := str(sid)
		var st: Dictionary = game.stations[id]
		if kind == "bunker" and (str(st.get("bunker", "")) != "" or str(st.owner) == "bunker"):
			return id
		if kind == "ruin" and (bool(st.get("ruin", false)) or str(st.owner) == "ruin"):
			return id
	return ""


func _force_hub(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	var ends := _ends(game, sid)
	var extra: Array = []
	for other in game.stations:
		var id := str(other)
		if id == sid or ends.has(id):
			continue
		extra.append(id)
		if ends.size() + extra.size() >= 3:
			break
	for id in extra:
		_link(game, sid, str(id))
		ends.append(str(id))
	for i in mini(3, ends.size()):
		game.stations[str(ends[i])].passage = true
		game.stations[str(ends[i])].hidden = false


func _link(game: Game, a: String, b: String) -> void:
	var edge: Dictionary = game._edge(a, b)
	if edge.is_empty():
		game._add_tunnel(a, b, "open", "", {})
		return
	game._mark_tunnel(a, b, "open")
