class_name NetworkView
extends Control

## Projected subway map. The week still lives on Game.

const ArtPack = preload("res://ui/art_pack.gd")
const PAPER := Color("241c14")
const INK := Color("f4efe4")
const MUTED := Color("d9cbb4")
const WATER := Color("1a3040")
const LAND := Color("3e5344")
const LAND_EDGE := Color("cbb892")
const LINE_COLOR := {
	"g": Color("7dcea0"),
	"b": Color("5dade2"),
	"r": Color("e06a5c"),
	"a": Color("f0b429"),
}

var host: Node = null
var origin := Vector2.ZERO
var zoom := 1.0
var _drag := false
var _hover := ""
var selected := ""
var sheet: PanelContainer
var council: PanelContainer
var _sheet_body: VBoxContainer
var _council_body: VBoxContainer
var _fitted := false
var _hop := {}
var _hop_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_build_sheet()
	_build_council()
	resized.connect(_on_resize)


func bind(station) -> void:
	host = station
	_fitted = false
	refresh()


func refresh() -> void:
	_track_hops()
	_fill_council()
	if selected != "":
		_fill_sheet(selected)
	queue_redraw()


func open_sheet(sid: String) -> void:
	selected = sid
	sheet.visible = true
	_fill_sheet(sid)
	queue_redraw()


func close_sheet() -> void:
	selected = ""
	sheet.visible = false
	queue_redraw()


func first_known_neighbor() -> String:
	var game = _game()
	if game == null:
		return ""
	var fallback := ""
	for sid in game.stations:
		if str(sid) == game.capital_id:
			continue
		if not bool(game.stations[sid].get("known", false)):
			continue
		if fallback == "":
			fallback = str(sid)
		if game.borders_player(str(sid)):
			return str(sid)
	return fallback


func focus_intent() -> void:
	var game = _game()
	if game == null:
		return
	for intent in game.telegraphed:
		if bool(intent.get("hidden", false)):
			continue
		var sid := str(intent.get("station", ""))
		if game.stations.has(sid):
			origin = _station_world(game.stations[sid])
			zoom = maxf(zoom, 1.4)
			queue_redraw()
			return


func _game():
	if host == null:
		return null
	return host.game


func _motion_off() -> bool:
	if host != null and bool(host.get("shot_mode")):
		return true
	return Settings.reduced()


func _process(delta: float) -> void:
	if not visible or _hop_left <= 0.0:
		return
	_hop_left = maxf(0.0, _hop_left - delta)
	queue_redraw()


func _on_resize() -> void:
	_place_panels()
	if not _fitted:
		_fit()


func _center() -> Vector2:
	var top := 78.0
	var bottom := 96.0
	return Vector2(size.x * 0.5, (top + size.y - bottom) * 0.5)


func _screen(world: Vector2) -> Vector2:
	return (world - origin) * zoom + _center()


func _world(screen_at: Vector2) -> Vector2:
	return (screen_at - _center()) / zoom + origin


func _spec() -> Dictionary:
	var game = _game()
	if game == null:
		return {}
	return game.catalog.geo.get("projection", {})


func _station_world(st: Dictionary) -> Vector2:
	return Geo.project(float(st.lat), float(st.lon), _spec())


func _fit() -> void:
	var game = _game()
	var spec := _spec()
	if game == null or spec.is_empty() or size.x < 10.0:
		return
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	var land: Dictionary = game.catalog.geo.get("land", {})
	for key in land:
		var ring: Array = land[key]
		for point in ring:
			if not (point is Array):
				continue
			var pair: Array = point
			var world := Geo.project(float(pair[0]), float(pair[1]), spec)
			min_p.x = minf(min_p.x, world.x)
			min_p.y = minf(min_p.y, world.y)
			max_p.x = maxf(max_p.x, world.x)
			max_p.y = maxf(max_p.y, world.y)
	for sid in game.stations:
		var world := _station_world(game.stations[sid])
		min_p = min_p.min(world)
		max_p = max_p.max(world)
	var span := max_p - min_p
	if span.x < 1.0 or span.y < 1.0:
		return
	var view := Vector2(size.x - 80.0, size.y - 190.0)
	zoom = minf(view.x / span.x, view.y / span.y)
	origin = (min_p + max_p) * 0.5
	_fitted = true
	_place_panels()
	queue_redraw()


func _draw() -> void:
	var game = _game()
	if game == null or _spec().is_empty():
		return
	if not _fitted:
		_fit()
	draw_rect(Rect2(Vector2.ZERO, size), WATER)
	_draw_land(game)
	_draw_labels(game)
	_draw_lines(game)
	_draw_tunnels(game)
	_draw_stations(game)
	_draw_squads(game)
	_draw_intents(game)


func _draw_land(game) -> void:
	var spec := _spec()
	var land: Dictionary = game.catalog.geo.get("land", {})
	var step := float(spec.get("densify_step", 0.0025))
	for key in land:
		var ring: Array = land[key]
		var projected := Geo.project_ring(ring, spec, step)
		if projected.size() < 3:
			continue
		var screen := PackedVector2Array()
		for point in projected:
			screen.append(_screen(point))
		draw_colored_polygon(screen, LAND)
		screen.append(screen[0])
		draw_polyline(screen, LAND_EDGE, 1.5, true)


func _draw_labels(game) -> void:
	var font := _font()
	var spec := _spec()
	for row in game.catalog.geo.get("labels", []):
		if not (row is Dictionary):
			continue
		var at := _screen(Geo.project(float(row.lat), float(row.lon), spec))
		var text := str(row.text)
		var water: bool = str(row.get("kind", "")) == "wat"
		var col := Color(0.65, 0.78, 0.82, 0.7) if water else Color(0.86, 0.9, 0.8, 0.85)
		var px := 13 if water else 15
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_lines(game) -> void:
	var lines: Dictionary = game.catalog.communities.get("lines", {})
	for line_id in lines:
		var stops: Array = lines[line_id]
		var col: Color = LINE_COLOR.get(str(line_id), Color("efe6d2"))
		var pts := PackedVector2Array()
		for sid in stops:
			if not game.stations.has(str(sid)):
				continue
			pts.append(_screen(_station_world(game.stations[str(sid)])))
		if pts.size() >= 2:
			draw_polyline(pts, col, 3.0, false)


func _draw_tunnels(game) -> void:
	for tunnel in game.tunnels:
		var state := str(tunnel.get("state", "open"))
		if state == "open":
			continue
		if not game.stations.has(str(tunnel.a)) or not game.stations.has(str(tunnel.b)):
			continue
		var a := _screen(_station_world(game.stations[str(tunnel.a)]))
		var b := _screen(_station_world(game.stations[str(tunnel.b)]))
		var col := Color("8ec8d8") if state == "flooded" else Color("9a8b74")
		if state == "sealed" or state == "collapsed":
			_dash(a, b, col)
		else:
			draw_line(a, b, col, 2.0)


func _dash(a: Vector2, b: Vector2, col: Color) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 1.0:
		return
	dir /= length
	var t := 0.0
	while t < length:
		var t2 := minf(length, t + 7.0)
		draw_line(a + dir * t, a + dir * t2, col, 1.5)
		t += 12.0


func _draw_stations(game) -> void:
	var font := _font()
	var placed: Array[Rect2] = []
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		var at := _screen(_station_world(st))
		var known := bool(st.get("known", false)) or str(sid) == selected
		var hidden := bool(st.get("hidden", false))
		if not known:
			draw_circle(at, 4.0, Color(0.75, 0.75, 0.7, 0.35))
			continue
		var col := _faction_color(game, str(st.owner))
		var radius := 11.0 if str(sid) == _hover or str(sid) == selected else 8.0
		if hidden:
			_dash_ring(at, radius + 3.0, col)
		else:
			draw_arc(at, radius + 4.0, 0, TAU, 24, col, 2.5)
		draw_circle(at, radius, Color("1c1814"))
		draw_circle(at, radius - 2.0, col.lightened(0.15))
		if str(sid) == _hover:
			draw_arc(at, radius + 8.0, 0, TAU, 24, Color(0.93, 0.78, 0.45, 0.9), 2.0)
		var name := str(st.get("community", st.name))
		var px := 14
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var box := Rect2(at + Vector2(-width * 0.5, 14), Vector2(width, 16))
		var blocked := false
		for taken in placed:
			if taken.intersects(box.grow(2)):
				blocked = true
				break
		if blocked:
			continue
		placed.append(box)
		draw_string(font, box.position + Vector2(0, 12), name, HORIZONTAL_ALIGNMENT_LEFT, -1, px, INK)


func _dash_ring(center: Vector2, radius: float, col: Color) -> void:
	var steps := 16
	for i in steps:
		if i % 2 == 1:
			continue
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		draw_arc(center, radius, a0, a1, 4, col, 2.0)


func _draw_squads(game) -> void:
	for fid in game.squads:
		var sq: Dictionary = game.squads[fid]
		if not game.stations.has(str(sq.station)):
			continue
		if not bool(game.stations[str(sq.station)].get("known", false)) and str(fid) != game.player:
			continue
		var to_world := _station_world(game.stations[str(sq.station)])
		var at := _screen(to_world)
		if _hop.has(str(fid)) and _hop_left > 0.0 and not _motion_off():
			var from_world: Vector2 = _hop[str(fid)]
			at = _screen(from_world.lerp(to_world, 1.0 - _hop_left / 0.6))
		at += Vector2(14, -12)
		var col := _faction_color(game, str(fid))
		draw_circle(at, 9.0, col)
		draw_circle(at, 9.0, Color("1c1814"), false, 1.5)
		var icon := ArtPack.icon_texture("squad")
		if icon != null:
			draw_texture_rect(icon, Rect2(at - Vector2(8, 8), Vector2(16, 16)), false)
		else:
			draw_string(_font(), at + Vector2(-4, 4), str(sq.size), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("1c1814"))


func _draw_intents(game) -> void:
	for intent in game.telegraphed:
		if bool(intent.get("hidden", false)):
			continue
		var sid := str(intent.get("station", ""))
		if not game.stations.has(sid):
			continue
		var at := _screen(_station_world(game.stations[sid])) + Vector2(-16, -18)
		var kind := str(intent.get("kind", "hold"))
		var icon := ArtPack.icon_texture(kind if kind != "buy" else "propaganda")
		if kind == "demand_posted":
			icon = ArtPack.icon_texture("ultimatum")
		draw_circle(at, 11.0, Color("241c14"))
		if icon != null:
			draw_texture_rect(icon, Rect2(at - Vector2(10, 10), Vector2(20, 20)), false)
		else:
			draw_circle(at, 6.0, Color("f0b429"))


func _faction_color(game, fid: String) -> Color:
	if game.catalog.factions.has(fid) and game.catalog.factions[fid].has("color"):
		return Color(str(game.catalog.factions[fid].color))
	match fid:
		"neutral":
			return Color("c4b49a")
		"enemy":
			return Color("8a3a3a")
		"bunker", "ruin":
			return Color("8aa0b0")
		_:
			return Color("efe6d2")


func _font() -> Font:
	if host != null and host.get("body_font") != null:
		return host.body_font
	return ThemeDB.fallback_font


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(button.position, 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(button.position, 1.0 / 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				var hit := _station_at(button.position)
				if hit != "":
					open_sheet(hit)
					if host != null and host.has_method("_ui_click"):
						host._ui_click()
				else:
					_drag = true
			else:
				_drag = false
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var hit := _station_at(motion.position)
		if hit != _hover:
			_hover = hit
			queue_redraw()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit != "" else Control.CURSOR_ARROW
		tooltip_text = _tip(hit)
		if _drag:
			origin -= motion.relative / zoom
			queue_redraw()
			accept_event()


func _zoom_at(screen_at: Vector2, factor: float) -> void:
	var before := _world(screen_at)
	zoom = clampf(zoom * factor, 0.15, 6.0)
	var after := _world(screen_at)
	origin += before - after
	queue_redraw()


func _station_at(screen_at: Vector2) -> String:
	var game = _game()
	if game == null:
		return ""
	var best := ""
	var best_d := 18.0
	for sid in game.stations:
		var at := _screen(_station_world(game.stations[sid]))
		var dist := at.distance_to(screen_at)
		if dist < best_d:
			best_d = dist
			best = str(sid)
	return best


func _tip(sid: String) -> String:
	var game = _game()
	if game == null or sid == "" or not game.stations.has(sid):
		return ""
	var st: Dictionary = game.stations[sid]
	if not bool(st.get("known", false)):
		return Copy.t("Hidden station") if bool(st.get("hidden", false)) else ""
	var lines: PackedStringArray = [str(st.community)]
	for intent in game.telegraphed:
		if bool(intent.get("hidden", false)):
			continue
		if str(intent.get("station", "")) == sid:
			lines.append(game._intent_text(intent))
	return "\n".join(lines)


func _track_hops() -> void:
	var game = _game()
	if game == null:
		return
	var moved := false
	for fid in game.squads:
		var sq: Dictionary = game.squads[fid]
		if not game.stations.has(str(sq.station)):
			continue
		var now := _station_world(game.stations[str(sq.station)])
		if _hop.has(str(fid)):
			var prev: Vector2 = _hop[str(fid)]
			if prev.distance_to(now) > 0.5 and not _motion_off():
				_hop_left = 0.6
				moved = true
		if _hop_left <= 0.0:
			_hop[str(fid)] = now
	if moved:
		pass


func _build_sheet() -> void:
	sheet = PanelContainer.new()
	sheet.visible = false
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("b89a6a")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	sheet.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_body = VBoxContainer.new()
	_sheet_body.add_theme_constant_override("separation", 6)
	_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_sheet_body)
	sheet.add_child(scroll)
	add_child(sheet)


func _build_council() -> void:
	council = PanelContainer.new()
	council.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.11, 0.08, 0.94)
	style.border_color = Color("b89a6a")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	council.add_theme_stylebox_override("panel", style)
	_council_body = VBoxContainer.new()
	_council_body.add_theme_constant_override("separation", 4)
	council.add_child(_council_body)
	add_child(council)


func _place_panels() -> void:
	if sheet != null:
		sheet.offset_left = size.x - 380.0
		sheet.offset_top = 84.0
		sheet.offset_right = size.x - 16.0
		sheet.offset_bottom = size.y - 108.0
	if council != null:
		council.offset_left = 16.0
		council.offset_top = size.y - 340.0
		council.offset_right = 420.0
		council.offset_bottom = size.y - 96.0


func _fill_council() -> void:
	if _council_body == null:
		return
	for child in _council_body.get_children():
		child.queue_free()
	var game = _game()
	if game == null:
		return
	_council_body.add_child(_lab(Copy.t("Council"), 18, true))
	for seat in game.council:
		var role := str(seat.role)
		var person = game.people.get(str(seat.id), {})
		var used := str(game.seat_used.get(role, ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if host != null and host.has_method("_portrait_box"):
			row.add_child(host._portrait_box(str(seat.id), 48))
		var text := "%s\n%s" % [Copy.t(role.capitalize()), str(person.get("name", ""))]
		if used != "":
			text += "\n" + Copy.t("Used") + ": " + Copy.t(used.capitalize())
		else:
			text += "\n" + Copy.t("Open seat")
		var seat_label := _lab(text, 15, false)
		seat_label.custom_minimum_size = Vector2(180, 64)
		seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(seat_label)
		_council_body.add_child(row)


func _fill_sheet(sid: String) -> void:
	for child in _sheet_body.get_children():
		child.queue_free()
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	if str(sid) == game.capital_id:
		var hub := ArtPack.load_texture("res://assets/hubs/hub_coney_island.webp")
		if hub != null:
			var face := TextureRect.new()
			face.texture = hub
			face.custom_minimum_size = Vector2(320, 120)
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_sheet_body.add_child(face)
	_sheet_body.add_child(_lab(str(st.community), 20, true))
	_sheet_body.add_child(_lab(str(st.name), 14, false))
	_sheet_body.add_child(_lab(str(st.who), 14, false))
	_sheet_body.add_child(_lab(str(st.conflict), 14, false))
	_sheet_body.add_child(_lab("%s: %s" % [Copy.t("Owner"), Copy.t(_owner_name(game, str(st.owner)))], 14, false))
	_sheet_body.add_child(_lab("%s: %s" % [Copy.t("Loyalty"), str(int(st.loyalty))], 14, false))
	if int(st.unrest) > 0:
		_sheet_body.add_child(_lab("%s: %s" % [Copy.t("Unrest"), str(int(st.unrest))], 14, false))
	_sheet_body.add_child(_lab(Copy.t(_lean_name(str(st.lean))), 14, true))
	_sheet_body.add_child(_lab(Copy.t("Needs"), 14, true))
	for need in st.needs:
		_sheet_body.add_child(_need_bar(str(need.id), float(need.fill)))
	_sheet_body.add_child(_lab(Copy.t("Garrison") + " " + str(int(st.garrison)), 14, false))
	if str(st.art) != "":
		_sheet_body.add_child(_lab(str(st.art), 13, false))
	_order_button("envoy", "Send envoy", sid)
	_order_button("propaganda", "Propaganda", sid)
	_order_button("move", "Move squad", sid)
	_order_button("trade", "Open trade", sid)
	_order_button("expedition", "Start expedition", sid)
	var back := Button.new()
	back.text = Copy.t("Back to the map")
	back.pressed.connect(close_sheet)
	_sheet_body.add_child(back)


func _order_button(kind: String, label: String, sid: String) -> void:
	var game = _game()
	var button := Button.new()
	button.text = Copy.t(label)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var why := ""
	if game != null:
		why = game.order_block(kind, sid)
	button.disabled = why != ""
	button.tooltip_text = why
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if why == "":
		button.pressed.connect(_issue.bind(kind, sid))
	_sheet_body.add_child(button)


func _issue(kind: String, sid: String) -> void:
	var game = _game()
	if game == null:
		return
	var action := {"kind": "order", "order": kind}
	if kind == "move":
		action["dest"] = sid
	elif kind == "expedition":
		pass
	else:
		action["station"] = sid
	if game.apply(action):
		if host != null and host.has_method("_refresh"):
			host._refresh()
		refresh()
		_fill_sheet(sid)


func _need_bar(need_id: String, fill: float) -> Control:
	var row := HBoxContainer.new()
	var name := _lab(Copy.t(need_id), 14, false)
	name.custom_minimum_size = Vector2(110, 18)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = fill
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	return row


func _lab(text: String, px: int, display: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", INK if display else MUTED)
	if display and host != null and host.get("display_font") != null:
		label.add_theme_font_override("font", host.display_font)
	return label


func _owner_name(game, fid: String) -> String:
	if game.catalog.factions.has(fid):
		return str(game.catalog.factions[fid].name)
	return fid.capitalize()


func _lean_name(lean: String) -> String:
	match lean:
		"order":
			return "Order"
		"faith":
			return "Faith"
		"trade":
			return "Trade"
		"craft":
			return "Craft"
		_:
			return lean
