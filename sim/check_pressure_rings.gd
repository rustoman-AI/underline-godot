extends SceneTree

## P25 gate: pressure arc vs full ring, claim after a loss, visit copy. Assault numbers stay put.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -s res://sim/check_pressure_rings.gd


class Host extends Node:
	var game
	var shot_mode := false
	var motion_in_shots := false
	var net_guide := false
	var net_guide_sid := ""


class Probe extends Control:
	var paint: Callable

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a140e"))
		if paint.is_valid():
			paint.call(self)


var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PRESSURE RINGS FAIL catalog")
		quit(1)
		return
	if not _check_strings():
		_failed = true
	if not _check_rules(catalog):
		_failed = true
	if not await _check_draw(catalog):
		_failed = true
	print("PRESSURE RINGS FAIL" if _failed else "PRESSURE RINGS OK")
	quit(1 if _failed else 0)


func _bad(msg: String) -> void:
	_failed = true
	print("Pressure: FAIL ", msg)


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("pressure.hover_1") != "Under pressure · 1 week. One more and Assault is open.":
		_bad("hover_1 en " + Copy.t("pressure.hover_1"))
		return false
	if Copy.t("pressure.chip_ready") != "Assault ready":
		_bad("chip en")
		return false
	if Copy.fill("pressure.hover_ready", {"n": 2}) != "Under pressure · 2 weeks. Assault ready.":
		_bad("hover_ready en")
		return false
	if Copy.fill("pressure.claim_hover", {"faction": "Exchange", "n": 9}) != "Exchange claim · 9 weeks":
		_bad("claim hover en")
		return false
	if Copy.fill("pressure.visit_line", {"n": 2, "name": "Iron Directorate"}) != "Pressure 2/2 · Claim: Iron Directorate":
		_bad("visit en")
		return false
	if Copy.t("pressure.claim_note") != "They want it back. Retaking it costs no extra opinion.":
		_bad("note en")
		return false
	Copy.set_lang("ru")
	if Copy.t("pressure.hover_1") != "Под давлением · 1 неделя. Ещё одна — и можно штурмовать.":
		_bad("hover_1 ru " + Copy.t("pressure.hover_1"))
		return false
	if Copy.t("pressure.chip_ready") != "Штурм готов":
		_bad("chip ru")
		return false
	if Copy.fill("pressure.visit_pressure", {"n": 1}) != "Давление 1/2":
		_bad("visit pressure ru")
		return false
	if Copy.fill("pressure.claim_cleared", {"station": "Джей"}) != "Притязание на Джей снято.":
		_bad("cleared ru")
		return false
	if Copy.t("Under pressure · 1 week. One more and Assault is open.") != "Под давлением · 1 неделя. Ещё одна — и можно штурмовать.":
		_bad("ru.json hover")
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _neighbor(game: Game) -> String:
	for sid in game._neighbors(game.capital_id):
		var st: Dictionary = game.stations[str(sid)]
		if str(st.get("bunker", "")) != "" or str(st.owner) == "bunker" or str(st.owner) == "ruin":
			continue
		return str(sid)
	return ""


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


func _check_rules(catalog: Catalog) -> bool:
	if Game.CLAIM_WEEKS != 12:
		_bad("claim weeks")
		return false
	var game := _fresh(catalog)
	if int(game.bal.assault_hope) != -3 or int(game.bal.assault_discontent) != 8 or int(game.bal.unbidden_hope) != -2:
		_bad("assault numbers moved")
		return false
	var sid := _neighbor(game)
	if sid == "":
		_bad("no neighbour")
		return false
	var st: Dictionary = game.stations[sid]
	st.owner = "directorate"
	st.known = true
	st.low_weeks = 1
	st["pressure_by"] = "directorate"
	if game._assault_gate(sid) != Copy.t("order.assault_gate"):
		_bad("gate at 1 week: " + game._assault_gate(sid))
		return false
	st.low_weeks = 2
	if game._assault_gate(sid) != "":
		_bad("gate at 2 weeks: " + game._assault_gate(sid))
		return false
	var view := NetworkView.new()
	if not is_equal_approx(view.pressure_sweep(1), TAU * 0.75) or not is_equal_approx(view.pressure_sweep(2), TAU):
		_bad("sweep")
		return false
	if view.pressure_sweep(0) != 0.0 or view.claim_ring_radius(10.0) <= view.pressure_ring_radius(10.0):
		_bad("radii")
		return false
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var op0 := int(game.opinions.directorate)
	var mem0 := int(game.opinion_memory.get("directorate", []).size())
	if not game._capture(sid, game.player, true) or str(st.owner) != game.player:
		_bad("capture")
		return false
	if int(game.hope) - hope0 != -3 or int(game.discontent) - dis0 != 8:
		_bad("capture hope %d dis %d" % [int(game.hope) - hope0, int(game.discontent) - dis0])
		return false
	if int(game.opinions.directorate) != op0 - 20:
		_bad("opinion %d -> %d" % [op0, int(game.opinions.directorate)])
		return false
	var mem: Array = game.opinion_memory.get("directorate", [])
	if mem.size() != mem0 + 1 or int(mem.back().delta) != -20:
		_bad("extra opinion hit")
		return false
	var claim: Dictionary = game.station_claim(sid)
	if str(claim.get("faction", "")) != "directorate" or int(claim.get("weeks_left", 0)) != 12:
		_bad("claim after loss " + str(claim))
		return false
	if int(st.get("low_weeks", 0)) != 0:
		_bad("pressure cleared")
		return false
	## A claim already on the station is kept. Retaking clears that ring and the loser gets the next one.
	st.owner = "exchange"
	st.low_weeks = 2
	st["claim"] = {"faction": "synod", "weeks_left": 4}
	var ex0 := int(game.opinions.exchange)
	if not game._capture(sid, game.player, true):
		_bad("second capture")
		return false
	claim = game.station_claim(sid)
	if str(claim.get("faction", "")) != "synod" or int(claim.get("weeks_left", 0)) != 4:
		_bad("claim overwritten " + str(claim))
		return false
	if int(game.opinions.exchange) != ex0 - 20:
		_bad("retake opinion changed the old shift")
		return false
	st.owner = "exchange"
	st.low_weeks = 2
	st["claim"] = {"faction": game.player, "weeks_left": 3}
	var ex1 := int(game.opinions.exchange)
	var notes := game.notices.size()
	if not game._capture(sid, game.player, true):
		_bad("reclaim")
		return false
	claim = game.station_claim(sid)
	if str(claim.get("faction", "")) != "exchange" or int(claim.get("weeks_left", 0)) != 12:
		_bad("reclaim claim " + str(claim))
		return false
	if int(game.opinions.exchange) != ex1 - 20:
		_bad("reclaim added an opinion hit")
		return false
	var cleared := false
	for i in range(notes, game.notices.size()):
		if str(game.notices[i]).begins_with("Claim on "):
			cleared = true
	if not cleared:
		_bad("reclaim notice")
		return false
	st.owner = "neutral"
	st.low_weeks = 2
	st.erase("claim")
	if not game._capture(sid, "exchange", false):
		_bad("neutral capture")
		return false
	if not game.station_claim(sid).is_empty():
		_bad("neutral gained a claim")
		return false
	st.owner = game.player
	st.known = true
	st["claim"] = {"faction": "exchange", "weeks_left": 2}
	game._tick_claims()
	if int(game.station_claim(sid).get("weeks_left", 0)) != 1:
		_bad("tick")
		return false
	game._tick_claims()
	if not game.station_claim(sid).is_empty():
		_bad("claim lingered")
		return false
	if game.notices.is_empty() or not str(game.notices.back()).begins_with("Claim on ") or not str(game.notices.back()).ends_with(" is over."):
		_bad("expiry notice " + (str(game.notices.back()) if not game.notices.is_empty() else ""))
		return false
	st["claim"] = {"faction": "directorate", "weeks_left": 7}
	st.low_weeks = 1
	st["pressure_by"] = "directorate"
	var copy: Dictionary = game.export_state()
	copy["schema"] = Game.SAVE_SCHEMA
	var loaded := Game.new()
	loaded.setup(catalog, 9, 40)
	if not loaded.import_state(copy) or int(loaded.low_weeks_of(sid)) != 1:
		_bad("save low_weeks " + loaded.load_error)
		return false
	if str(loaded.station_claim(sid).get("faction", "")) != "directorate" or int(loaded.station_claim(sid).get("weeks_left", 0)) != 7:
		_bad("save claim")
		return false
	if loaded.pressure_faction(sid) != "directorate":
		_bad("pressure faction")
		return false
	var siege: Dictionary = view.siege_copy(game, sid)
	if str(siege.visit) != "Pressure 1/2 · Claim: Iron Directorate":
		_bad("visit line " + str(siege.visit))
		return false
	if str(siege.chip) != "":
		_bad("chip at 1 week")
		return false
	var hover := "\n".join(siege.hover)
	if not hover.contains("Under pressure · 1 week") or not hover.contains("Iron Directorate is squeezing") or not hover.contains("Iron Directorate claim · 7 weeks"):
		_bad("hover " + hover)
		return false
	st.low_weeks = 2
	siege = view.siege_copy(game, sid)
	if str(siege.chip) != "Assault ready" or str(siege.visit) != "Pressure 2/2 · Claim: Iron Directorate":
		_bad("ready copy " + str(siege))
		return false
	view.host = _host(game)
	if not view._tip(sid).contains("Assault ready"):
		_bad("tip " + view._tip(sid))
		return false
	print("Rules: ok")
	return true


func _host(game: Game) -> Host:
	var host := Host.new()
	host.game = game
	return host


func _check_draw(catalog: Catalog) -> bool:
	if DisplayServer.get_name() == "headless":
		_bad("draw needs a renderer (xvfb + opengl3, not --headless)")
		return false
	var game := _fresh(catalog)
	var sid := _neighbor(game)
	var st: Dictionary = game.stations[sid]
	st.owner = "exchange"
	st.known = true
	st.low_weeks = 2
	st["pressure_by"] = "directorate"
	st["claim"] = {"faction": "depot", "weeks_left": 9}
	var view := NetworkView.new()
	view.host = _host(game)
	var arc := await _shot(Vector2i(220, 220), func(c: CanvasItem):
		view._draw_pressure_ring(c, Vector2(110, 110), 70.0, 1, view._faction_color(game, "directorate"), false, 0.0)
	)
	var full := await _shot(Vector2i(220, 220), func(c: CanvasItem):
		view._draw_pressure_ring(c, Vector2(110, 110), 70.0, 2, view._faction_color(game, "directorate"), false, 0.0)
		view._draw_dashed_ring(c, Vector2(110, 110), 92.0, view._faction_color(game, "depot"), 2.4)
		view._hover = sid
		view._draw_assault_chip(c, Vector2(110, 110), 36.0)
	)
	var pulse_a := await _shot(Vector2i(180, 180), func(c: CanvasItem):
		view._draw_pressure_ring(c, Vector2(90, 90), 60.0, 2, view._faction_color(game, "directorate"), true, 0.0)
	)
	var pulse_b := await _shot(Vector2i(180, 180), func(c: CanvasItem):
		view._draw_pressure_ring(c, Vector2(90, 90), 60.0, 2, view._faction_color(game, "directorate"), true, 1.4)
	)
	var still_a := await _shot(Vector2i(180, 180), func(c: CanvasItem):
		view._draw_pressure_ring(c, Vector2(90, 90), 60.0, 2, view._faction_color(game, "directorate"), false, 0.0)
	)
	var still_b := await _shot(Vector2i(180, 180), func(c: CanvasItem):
		view._draw_pressure_ring(c, Vector2(90, 90), 60.0, 2, view._faction_color(game, "directorate"), false, 1.4)
	)
	if arc == null or full == null or pulse_a == null or pulse_b == null or still_a == null or still_b == null:
		_bad("viewport did not draw")
		return false
	var arc_hits := _ring_hits(arc, Vector2(110, 110), 70.0)
	var full_hits := _ring_hits(full, Vector2(110, 110), 70.0)
	var dash_hits := _ring_hits(full, Vector2(110, 110), 92.0)
	print("Draw hits arc %d full %d dash %d" % [_count(arc_hits), _count(full_hits), _count(dash_hits)])
	if _count(arc_hits) < 20 or _count(arc_hits) > 32 or _longest_gap(arc_hits) < 4:
		_bad("partial ring hits %d gap %d" % [_count(arc_hits), _longest_gap(arc_hits)])
		return false
	if _count(full_hits) < 34:
		_bad("full ring hits %d" % _count(full_hits))
		return false
	if _count(dash_hits) < 12 or _count(dash_hits) > 30 or _gap_count(dash_hits) < 6:
		_bad("dashed ring hits %d gaps %d" % [_count(dash_hits), _gap_count(dash_hits)])
		return false
	if not _near_faction(arc, Vector2(110, 110), 70.0, Color("b86972")):
		_bad("pressure colour")
		return false
	if not _near_faction(full, Vector2(110, 110), 92.0, Color("b46b4d")):
		_bad("claim colour")
		return false
	var chip := _ink_box(full, Rect2(20, 8, 180, 48))
	if chip < 30:
		_bad("chip pixels %d" % chip)
		return false
	if pulse_a.get_pixel(90, 30).a == pulse_b.get_pixel(90, 30).a and _same(pulse_a, pulse_b):
		_bad("pulse did not move")
		return false
	if not _same(still_a, still_b):
		_bad("reduce-motion ring changed")
		return false
	Settings.reduced()
	Settings.reduce_motion = true
	if view._motion_off() != true:
		_bad("motion flag")
		return false
	Settings.reduce_motion = false
	if view._motion_off():
		_bad("motion stayed off")
		return false
	var map := await _map_shot(game, view, sid)
	if map == null:
		_bad("map shot")
		return false
	var path := "/opt/cursor/artifacts/pressure_rings_map.png"
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	map.save_png(path)
	full.save_png("/opt/cursor/artifacts/pressure_rings_close.png")
	arc.save_png("/opt/cursor/artifacts/pressure_rings_arc.png")
	if not _visit_line(game, view, sid):
		return false
	print("Draw: ok")
	return true


func _visit_line(game: Game, view: NetworkView, sid: String) -> bool:
	if view.get_parent():
		view.get_parent().remove_child(view)
	view.size = Vector2(1280, 720)
	root.add_child(view)
	view._show_visit(sid)
	var line: Node = _find_meta(view, "siege_line")
	var chip: Node = _find_meta(view, "assault_ready")
	if line == null or str(line.text) != "Pressure 2/2 · Claim: The Depot":
		_bad("visit sheet " + (str(line.text) if line != null else "missing"))
		return false
	if chip == null or str(chip.text) != "Assault ready":
		_bad("visit chip")
		return false
	view.close_visit()
	view.open_sheet(sid)
	line = _find_meta(view._sheet_body, "siege_line")
	if line == null or not str(line.text).contains("Pressure 2/2"):
		_bad("sheet line")
		return false
	print("Visit: ok")
	return true


func _find_meta(node: Node, key: String):
	if node.has_meta(key):
		return node
	for child in node.get_children():
		var found = _find_meta(child, key)
		if found != null:
			return found
	return null


func _map_shot(game: Game, view: NetworkView, sid: String) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	if view.get_parent():
		view.get_parent().remove_child(view)
	view.size = Vector2(1280, 720)
	view.custom_minimum_size = Vector2(1280, 720)
	vp.add_child(view)
	view.origin = view._station_world(game.stations[sid])
	view._zoom_range()
	view.zoom = view._zoom_max
	view._hover = sid
	view._clamp_view()
	view._redraw()
	for _i in 3:
		await process_frame
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	return img


func _shot(size: Vector2i, paint: Callable) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("1a140e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	var probe := Probe.new()
	probe.paint = paint
	probe.set_anchors_preset(Control.PRESET_TOP_LEFT)
	probe.position = Vector2.ZERO
	probe.size = Vector2(size)
	vp.add_child(probe)
	root.add_child(vp)
	for _i in 3:
		await process_frame
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		vp.queue_free()
		return null
	var img := tex.get_image()
	vp.queue_free()
	return img


func _ring_hits(img: Image, center: Vector2, radius: float) -> Array:
	var hits: Array = []
	for i in 36:
		var ang := TAU * float(i) / 36.0
		hits.append(_ink_at(img, center, ang, radius))
	return hits


func _ink_at(img: Image, center: Vector2, ang: float, radius: float) -> bool:
	var dir := Vector2(cos(ang), sin(ang))
	var bg := Color("1a140e")
	for dr in range(-5, 6):
		var p := center + dir * (radius + float(dr))
		var x := clampi(int(round(p.x)), 0, img.get_width() - 1)
		var y := clampi(int(round(p.y)), 0, img.get_height() - 1)
		if _color_gap(img.get_pixel(x, y), bg) > 0.18:
			return true
	return false


func _near_faction(img: Image, center: Vector2, radius: float, want: Color) -> bool:
	var best := 99.0
	for i in 36:
		var ang := TAU * float(i) / 36.0
		var dir := Vector2(cos(ang), sin(ang))
		for dr in range(-5, 6):
			var p := center + dir * (radius + float(dr))
			var x := clampi(int(round(p.x)), 0, img.get_width() - 1)
			var y := clampi(int(round(p.y)), 0, img.get_height() - 1)
			var pix := img.get_pixel(x, y)
			best = minf(best, absf(pix.r - want.r) + absf(pix.g - want.g) + absf(pix.b - want.b))
	return best < 0.45


func _ink_box(img: Image, box: Rect2) -> int:
	var n := 0
	var bg := Color("1a140e")
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			if _color_gap(img.get_pixel(x, y), bg) > 0.2:
				n += 1
	return n


func _count(hits: Array) -> int:
	var n := 0
	for hit in hits:
		if hit:
			n += 1
	return n


func _longest_gap(hits: Array) -> int:
	var n := hits.size()
	var best := 0
	var run := 0
	for i in n * 2:
		if hits[i % n]:
			best = maxi(best, run)
			run = 0
		else:
			run += 1
	return mini(best, n)


func _gap_count(hits: Array) -> int:
	var n := hits.size()
	var gaps := 0
	for i in n:
		if hits[i] and not hits[(i + 1) % n]:
			gaps += 1
	return gaps


func _color_gap(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)


func _same(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			if _color_gap(a.get_pixel(x, y), b.get_pixel(x, y)) > 0.02:
				return false
	return true
