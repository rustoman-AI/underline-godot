extends SceneTree

const Pip = preload("res://sim/focus_pip.gd")
const Dust = preload("res://sim/leaflet_dust.gd")
const Marks = preload("res://sim/deal_marks.gd")
const Tick = preload("res://sim/need_tick.gd")

## P57 gate: owned outpost pins carry a focus letter. Capital, foreign, and unset never do.
##   xvfb-run -a godot --rendering-driver opengl3 --rendering-method gl_compatibility --path . -s res://sim/check_focus_pip.gd


class Host extends Node:
	var game
	var shot_mode := true
	var motion_in_shots := false
	var display_font: Font
	var body_font: Font


class Probe extends Control:
	var paint: Callable

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1a140e"))
		if paint.is_valid():
			paint.call(self)


var _failed := false
const CLUSTER := ["riverside", "brickworks", "library", "westfield", "signal", "southdepot", "oldcommand"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("FOCUS PIP FAIL catalog")
		quit(1)
		return
	if not _check_strings():
		_failed = true
	if not _check_rules(catalog):
		_failed = true
	if not _check_source():
		_failed = true
	if not await _check_draw(catalog):
		_failed = true
	print("FOCUS PIP FAIL" if _failed else "FOCUS PIP OK")
	quit(1 if _failed else 0)


func _bad(msg: String) -> void:
	_failed = true
	print("Focus pip: FAIL ", msg)


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("focus.food") != "Food" or Copy.t("focus.air") != "Air":
		_bad("food/air en")
		return false
	if Copy.t("focus.defense") != "Defense" or Copy.t("focus.influence") != "Influence":
		_bad("defense/influence en")
		return false
	if Copy.t("focus.current") != "Focus: {name}" or Copy.t("focus.tip") != "This outpost leans here.":
		_bad("current/tip en")
		return false
	if Copy.fill("focus.current", {"name": Copy.t("focus.food")}) != "Focus: Food":
		_bad("current fill en")
		return false
	if Copy.fill("focus.current", {"name": "Air"}) != "Focus: Air":
		_bad("air fill en")
		return false
	Copy.set_lang("ru")
	if Copy.t("focus.food") != "Еда" or Copy.t("focus.air") != "Воздух":
		_bad("food/air ru")
		return false
	if Copy.t("focus.defense") != "Оборона" or Copy.t("focus.influence") != "Влияние":
		_bad("defense/influence ru")
		return false
	if Copy.t("focus.tip") != "Эта застава клонится сюда.":
		_bad("tip ru")
		return false
	if Copy.fill("focus.current", {"name": Copy.t("focus.food")}) != "Уклон: Еда":
		_bad("current ru " + Copy.fill("focus.current", {"name": Copy.t("focus.food")}))
		return false
	if Copy.t("focus.pip") != "focus.pip":
		_bad("invented focus.pip")
		return false
	Copy.set_lang("en")
	var raw := FileAccess.get_file_as_string("res://data/ui_strings.json")
	if raw.find("\"focus.pip\"") >= 0:
		_bad("ui_strings packed focus.pip")
		return false
	print("Strings: ok")
	return true


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


func _stage(game: Game) -> void:
	var owned := {
		"riverside": "food",
		"brickworks": "air",
		"library": "defense",
		"westfield": "influence",
		"signal": "",
	}
	for sid in owned:
		var st: Dictionary = game.stations[sid]
		st.owner = game.player
		st.known = true
		st.hidden = false
		st.intel = 1
		st.focus = str(owned[sid])
		st.sympathy = 40
	var home: Dictionary = game.stations[game.capital_id]
	home.known = true
	home.owner = game.player
	home.focus = "food"
	var foreign: Dictionary = game.stations["oldcommand"]
	foreign.owner = "neutral"
	foreign.known = true
	foreign.hidden = false
	foreign.intel = 1
	foreign.focus = "food"
	foreign.sympathy = 80
	foreign["leaflet_until_week"] = int(game.week) + 2
	foreign["leaflet_until"] = int(game.week) + 2
	var pressed: Dictionary = game.stations["riverside"]
	pressed.low_weeks = 1
	pressed["pressure_by"] = "directorate"


func _check_rules(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	_stage(game)
	var glyphs := {"riverside": "F", "brickworks": "A", "library": "D", "westfield": "I"}
	for sid in glyphs:
		if not Pip.shows(game, sid) or Pip.glyph(str(game.stations[sid].focus)) != str(glyphs[sid]):
			_bad("show " + sid)
			return false
	if Pip.shows(game, game.capital_id) or Pip.shows(game, "oldcommand") or Pip.shows(game, "signal"):
		_bad("hide failed")
		return false
	var secret: Dictionary = game.stations["archive"]
	secret.owner = game.player
	secret.focus = "defense"
	secret.known = false
	secret.hidden = true
	if Pip.shows(game, "archive"):
		_bad("secret showed")
		return false
	secret.known = true
	secret.hidden = false
	secret.capital = true
	if Pip.shows(game, "archive"):
		_bad("capital flag showed")
		return false
	game.stations["signal"].focus = "loot"
	if Pip.shows(game, "signal") or Pip.glyph("loot") != "":
		_bad("invented focus id")
		return false
	game.stations["signal"].focus = ""
	if Pip.bounces():
		_bad("letter bounces")
		return false
	var at := Vector2(40, 80)
	for pin_r in [8.0, 9.5, 10.0, 16.0, 22.0]:
		var radius := float(pin_r)
		var mark: Vector2 = Pip.slot(at, radius)
		var want := at + Vector2(-radius * 0.35, -radius * 0.20)
		if mark.distance_to(want) > 0.01:
			_bad("slot moved " + str(radius))
			return false
		if mark.x >= at.x or mark.y >= at.y:
			_bad("slot left the upper-inner " + str(mark))
			return false
		var goods := at + Vector2(radius * 0.62, radius * 0.55)
		if mark.distance_to(goods) < 8.0:
			_bad("slot stole goods " + str(radius))
			return false
		for crowded in [false, true]:
			var leaf: Vector2 = Dust.slot(at, radius, crowded)
			var need: Vector2 = Tick.slot(at, radius, crowded)
			if mark.distance_to(leaf) < 6.0 or mark.distance_to(need) < 6.0:
				_bad("slot stole leaflet or need " + str(radius))
				return false
		for i in 3:
			if mark.distance_to(Marks.pip_slot(at, radius, i)) < 8.0:
				_bad("slot stole deal " + str(radius))
				return false
	if not is_equal_approx(Pip.disc_px(16.0), 13.0) or not is_equal_approx(Pip.disc_px(8.0), 10.0):
		_bad("disc size")
		return false
	if Pip.letter_px(16.0) != 12 or Pip.letter_px(8.0) != 10:
		_bad("letter size")
		return false
	Copy.set_lang("en")
	var food := Pip.lines(game, "riverside")
	if food.size() != 2 or food[0] != "Focus: Food" or food[1] != "This outpost leans here.":
		_bad("tip en " + str(food))
		return false
	if not Pip.lines(game, game.capital_id).is_empty() or not Pip.lines(game, "oldcommand").is_empty():
		_bad("tip on a hidden pin")
		return false
	if not Pip.lines(game, "signal").is_empty():
		_bad("tip on unset")
		return false
	Copy.set_lang("ru")
	var air := Pip.lines(game, "brickworks")
	if air.size() != 2 or air[0] != "Уклон: Воздух" or air[1] != "Эта застава клонится сюда.":
		_bad("tip ru " + str(air))
		return false
	Copy.set_lang("en")
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	if game.station_focus_dawn_chip() or str(game.dawn_soft_chip().get("kind", "")) == "focus":
		_bad("focus joined the soft stack")
		return false
	var flow: Dictionary = Formulas.outpost_flow(5, 2, "food")
	if int(flow.food) != 5 or int(flow.materials) != 1:
		_bad("food flow " + str(flow))
		return false
	var src := FileAccess.get_file_as_string("res://sim/formulas.gd")
	if not src.contains('const FOCUS_ADD := {"food": {"food": 2}, "defense": {"materials": 2}, "influence": {"influence": 6}, "air": {"air": 2}}'):
		_bad("FOCUS_ADD drifted")
		return false
	var pip_src := FileAccess.get_file_as_string("res://sim/focus_pip.gd")
	if pip_src.find("outpost_flow") >= 0 or pip_src.find("balance.json") >= 0 or pip_src.find("present_dawn_soft") >= 0:
		_bad("pip helper touches flow, balance, or a soft chip")
		return false
	print("Rules: ok")
	return true


func _body(src: String, name: String) -> String:
	var at := src.find(name)
	if at < 0:
		return ""
	var body := src.substr(at)
	var next := body.find("\nfunc ")
	if next >= 0:
		body = body.substr(0, next)
	return body


func _check_source() -> bool:
	var ui := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _body(ui, "func _draw_pin(")
	var siege := pin.find("_draw_siege")
	var warm := pin.find("_draw_warmth_ring")
	var border := pin.find("_draw_border_tick")
	var focus := pin.find("_draw_focus_pip")
	var leaf := pin.find("_draw_leaflet_chip")
	var need := pin.find("_draw_need_tick")
	var good := pin.find("_draw_good_pip")
	if siege < 0 or warm < siege or border < warm or focus < border or leaf < focus or need < leaf or good < need:
		_bad("draw order")
		return false
	var letter := _body(ui, "func _draw_focus_pip(")
	if letter.find("FocusPip.slot") < 0 or letter.find("FocusPip.disc_px") < 0 or letter.find("FocusPip.glyph") < 0:
		_bad("letter draw")
		return false
	if letter.find("sin(") >= 0 or letter.find("create_tween") >= 0 or letter.find("_anim_t") >= 0 or letter.find("bounce") >= 0:
		_bad("letter motion")
		return false
	if letter.find("outpost_flow") >= 0 or letter.find("present_dawn_soft") >= 0 or letter.find("focus.pip") >= 0:
		_bad("letter side effects")
		return false
	var goods := _body(ui, "func _draw_good_pip(")
	if goods.find("Vector2(r * 0.62, r * 0.55)") < 0:
		_bad("goods slot moved")
		return false
	if _body(ui, "func _draw_leaflet_chip(").find("LeafletDust.slot") < 0:
		_bad("leaflet slot moved")
		return false
	if _body(ui, "func _draw_need_tick(").find("NeedTick.slot") < 0:
		_bad("need slot moved")
		return false
	var ink := _body(ui, "func _draw_ink(")
	if ink.find("_draw_pins") < 0 or ink.find("_draw_deal_pips") < ink.find("_draw_pins") or ink.find("_draw_flags") < ink.find("_draw_deal_pips"):
		_bad("pins, deals, flags")
		return false
	if ui.find("FocusPip.lines(game, sid)") < 0:
		_bad("tip not wired")
		return false
	if ui.find("func _add_focus_picker(") < 0 or ui.find("game._order_focus(sid, focus)") < 0:
		_bad("visit picker dropped")
		return false
	if ui.find("present_dawn_soft_chip") >= 0 and _body(ui, "func _draw_focus_pip(").find("present_dawn_soft_chip") >= 0:
		_bad("letter queues a chip")
		return false
	print("Source: ok")
	return true


func _host(game: Game) -> Host:
	var host := Host.new()
	host.game = game
	var shoulders := ArtPack.load_font("res://assets/fonts/BigShouldersDisplay.ttf")
	if shoulders != null:
		var face := FontVariation.new()
		face.base_font = shoulders
		face.set_variation_opentype({2003265652: 800.0})
		host.display_font = face
		host.body_font = face
	return host


func _check_draw(catalog: Catalog) -> bool:
	if DisplayServer.get_name() == "headless":
		_bad("draw needs a renderer")
		return false
	var game := _fresh(catalog)
	_stage(game)
	var host := _host(game)
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	root.add_child(view)
	view.size = Vector2(1280, 720)
	var food_tip := view._tip("riverside")
	if not food_tip.contains("Focus: Food") or not food_tip.contains("This outpost leans here."):
		_bad("pin tip " + food_tip)
		return false
	var home_tip := view._tip(game.capital_id)
	var foreign_tip := view._tip("oldcommand")
	var unset_tip := view._tip("signal")
	if home_tip.contains("Focus:") or home_tip.contains("leans here"):
		_bad("capital tip " + home_tip)
		return false
	if foreign_tip.contains("Focus:") or foreign_tip.contains("leans here"):
		_bad("foreign tip " + foreign_tip)
		return false
	if unset_tip.contains("Focus:") or unset_tip.contains("leans here"):
		_bad("unset tip " + unset_tip)
		return false
	game.stations["archive"].known = false
	if view._tip("archive").contains("Focus:"):
		_bad("unknown tip")
		return false
	if not await _pixels(view, game):
		return false
	if not await _visit(view, game):
		return false
	if not await _shots(view, game):
		return false
	print("Draw: ok")
	return true


func _pixels(view: NetworkView, game: Game) -> bool:
	var at := Vector2(120, 90)
	var radius := 22.0
	var on := await _shot(Vector2i(240, 180), func(c: CanvasItem):
		view._draw_focus_pip(c, game, "riverside", game.stations["riverside"], at, radius, 0.0)
	)
	var off := await _shot(Vector2i(240, 180), func(c: CanvasItem):
		view._draw_focus_pip(c, game, game.capital_id, game.stations[game.capital_id], at, radius, 0.0)
		view._draw_focus_pip(c, game, "oldcommand", game.stations["oldcommand"], at + Vector2(0, 40), radius, 0.0)
		view._draw_focus_pip(c, game, "signal", game.stations["signal"], at + Vector2(40, 0), radius, 0.0)
	)
	view._anim_t = 1.7
	Settings.reduced()
	Settings.reduce_motion = true
	var still_a := await _shot(Vector2i(240, 180), func(c: CanvasItem):
		view._draw_focus_pip(c, game, "library", game.stations["library"], at, radius, 0.0)
	)
	view._anim_t = 0.2
	Settings.reduce_motion = false
	var still_b := await _shot(Vector2i(240, 180), func(c: CanvasItem):
		view._draw_focus_pip(c, game, "library", game.stations["library"], at, radius, 0.0)
	)
	Settings.reduce_motion = false
	if on == null or off == null or still_a == null or still_b == null:
		_bad("viewport")
		return false
	var pos: Vector2 = Pip.slot(at, radius)
	var paper := _count_near(on, Rect2(pos - Vector2(8, 8), Vector2(16, 16)), Color("efe4c8"), 0.55)
	var ink := _count_dark(on, Rect2(pos - Vector2(6, 6), Vector2(12, 12)), 0.55)
	if paper < 12 or ink < 2:
		_bad("letter pixels paper %d ink %d" % [paper, ink])
		return false
	var goods := at + Vector2(radius * 0.62, radius * 0.55)
	if _count_near(on, Rect2(goods - Vector2(8, 8), Vector2(16, 16)), Color("efe4c8"), 0.45) > 4:
		_bad("letter drew on the goods slot")
		return false
	if _count_near(off, Rect2(pos - Vector2(8, 8), Vector2(16, 16)), Color("efe4c8"), 0.45) > 2:
		_bad("hidden pin drew a disc")
		return false
	if not _same(still_a, still_b):
		_bad("letter moved between frames")
		return false
	print("Pixels: ok")
	return true


func _visit(view: NetworkView, game: Game) -> bool:
	view.open_visit("riverside")
	await process_frame
	if _meta(view.visit, "focus_choice").size() != 4:
		_bad("visit picker")
		return false
	if view.find_children("*", "ConfirmationDialog", true, false).size() != 0:
		_bad("confirm modal")
		return false
	view.close_visit()
	view.open_visit(game.capital_id)
	await process_frame
	if not _meta(view.visit, "focus_choice").is_empty():
		_bad("capital picker")
		return false
	view.close_visit()
	view.open_visit("oldcommand")
	await process_frame
	if not _meta(view.visit, "focus_choice").is_empty():
		_bad("foreign picker")
		return false
	view.close_visit()
	print("Visit: ok")
	return true


func _shots(view: NetworkView, game: Game) -> bool:
	var board := await _shot(Vector2i(1120, 360), func(c: CanvasItem):
		_paint_board(c, view, game)
	)
	var map := await _map_shot(view, game)
	if board == null or map == null:
		_bad("shots")
		return false
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	board.save_png("/opt/cursor/artifacts/focus_pip_tip_hide.png")
	map.save_png("/opt/cursor/artifacts/focus_pip_after_map.png")
	for sid in ["riverside", "brickworks", "library", "westfield"]:
		var row: Dictionary = view._layout.get(sid, {})
		if row.is_empty():
			_bad("map layout " + sid)
			return false
		var letter: Vector2 = Pip.slot(row.at, float(row.r))
		var paper := _count_near(map, Rect2(letter - Vector2(8, 8), Vector2(16, 16)), Color("efe4c8"), 0.4)
		if paper < 8:
			_bad("map letter hidden " + sid + " paper " + str(paper))
			return false
	for sid in ["riverside", "southdepot", "oldcommand", "signal"]:
		var row: Dictionary = view._layout.get(sid, {})
		if row.is_empty():
			continue
		var center: Vector2 = row.at
		var span := 150.0
		var rect := Rect2i(Vector2i(center) - Vector2i(int(span), int(span)), Vector2i(int(span * 2), int(span * 2)))
		rect = rect.intersection(Rect2i(0, 0, map.get_width(), map.get_height()))
		if rect.size.x > 8:
			map.get_region(rect).save_png("/opt/cursor/artifacts/focus_pip_after_%s.png" % sid)
	print("Shots: ok")
	return true


func _paint_board(c: CanvasItem, view: NetworkView, game: Game) -> void:
	var font := view._focus_letter_font()
	var cases := [
		{"sid": "riverside", "title": "Owned · food"},
		{"sid": "brickworks", "title": "Owned · air"},
		{"sid": "library", "title": "Owned · defense"},
		{"sid": "westfield", "title": "Owned · influence"},
		{"sid": game.capital_id, "title": "Capital"},
		{"sid": "oldcommand", "title": "Foreign"},
		{"sid": "signal", "title": "Unset"},
	]
	for i in cases.size():
		var row: Dictionary = cases[i]
		var at := Vector2(80.0 + float(i) * 150.0, 78.0)
		var radius := 26.0
		view._draw_pin(c, game, str(row.sid), {"at": at, "px": radius / 0.42, "r": radius, "known": true})
		c.draw_string(font, at + Vector2(-46, 52), str(row.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("efe4c8"))
		var lines: PackedStringArray = Pip.lines(game, str(row.sid))
		if lines.is_empty():
			continue
		var text := "\n".join(lines)
		var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, 130.0, 12)
		var box := Rect2(at + Vector2(-58, 62), size + Vector2(12, 10))
		c.draw_rect(box, Color("efe4c8"))
		c.draw_rect(box, Color("e2a63a", 0.9), false, 1.0)
		c.draw_multiline_string(font, box.position + Vector2(6, font.get_ascent(12) + 4), text, HORIZONTAL_ALIGNMENT_LEFT, 130.0, 12, -1, Color("2b2118"))


func _map_shot(view: NetworkView, game: Game) -> Image:
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
	for _i in 2:
		await process_frame
	view._zoom_range()
	var box := Rect2(view._station_world(game.stations[CLUSTER[0]]), Vector2.ZERO)
	for sid in CLUSTER:
		box = box.expand(view._station_world(game.stations[str(sid)]))
	box = box.grow(70.0)
	var area := view._open_area()
	var fit := minf(area.size.x / maxf(box.size.x, 1.0), area.size.y / maxf(box.size.y, 1.0))
	view.zoom = clampf(fit * 0.92, view._zoom_min, view._zoom_max)
	view.origin = box.get_center()
	view._clamp_view()
	view._redraw()
	for _i in 4:
		await process_frame
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return null
	return tex.get_image()


func _shot(size: Vector2i, paint: Callable) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
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


func _meta(node: Node, key: String) -> Array:
	var found: Array = []
	if node == null:
		return found
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here.has_meta(key):
			found.append(here)
		for child in here.get_children():
			stack.append(child)
	return found


func _count_near(img: Image, box: Rect2, want: Color, tol: float) -> int:
	var n := 0
	var x0 := clampi(int(box.position.x), 0, img.get_width() - 1)
	var y0 := clampi(int(box.position.y), 0, img.get_height() - 1)
	var x1 := clampi(int(box.end.x), 0, img.get_width())
	var y1 := clampi(int(box.end.y), 0, img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			if _gap(img.get_pixel(x, y), want) < tol:
				n += 1
	return n


func _count_dark(img: Image, box: Rect2, lum: float) -> int:
	var n := 0
	var x0 := clampi(int(box.position.x), 0, img.get_width() - 1)
	var y0 := clampi(int(box.position.y), 0, img.get_height() - 1)
	var x1 := clampi(int(box.end.x), 0, img.get_width())
	var y1 := clampi(int(box.end.y), 0, img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var pix := img.get_pixel(x, y)
			if pix.r * 0.3 + pix.g * 0.59 + pix.b * 0.11 < lum:
				n += 1
	return n


func _gap(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _same(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			if _gap(a.get_pixel(x, y), b.get_pixel(x, y)) > 0.04:
				return false
	return true
