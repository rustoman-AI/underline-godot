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
var _zoom_min := 0.15
var _zoom_max := 6.0
var _cam_origin := Vector2.ZERO
var _cam_zoom := 1.0
var visit: PanelContainer
var _visit_body: VBoxContainer
var _paper: Texture2D
var _water_tex: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_build_sheet()
	_build_council()
	_build_visit()
	_paper = _map_tex("res://incoming-art/map/paper.png")
	_water_tex = _map_tex("res://incoming-art/map/water.png")
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


func focus_station(sid: String) -> void:
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	origin = _station_world(game.stations[sid])
	zoom = clampf(maxf(zoom, 1.6), _zoom_min, _zoom_max)
	queue_redraw()


func station_anchor(sid: String, host: Control) -> Rect2:
	var game = _game()
	if game == null or not game.stations.has(sid) or host == null:
		return Rect2()
	var at := _screen(_station_world(game.stations[sid]))
	var global_at := get_global_rect().position + at
	var origin := host.get_global_rect().position
	return Rect2(global_at - origin - Vector2(18, 18), Vector2(36, 36))


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
	for sid in game.stations:
		var world := _station_world(game.stations[sid])
		min_p = min_p.min(world)
		max_p = max_p.max(world)
	var span := max_p - min_p
	if span.x < 1.0 or span.y < 1.0:
		return
	var margin := Vector2(maxf(span.x, 40.0), maxf(span.y, 40.0)) * 0.08
	min_p -= margin
	max_p += margin
	span = max_p - min_p
	var view := Vector2(size.x - 80.0, size.y - 190.0)
	zoom = minf(view.x / span.x, view.y / span.y)
	_zoom_min = zoom * 0.85
	_zoom_max = zoom * 4.0
	zoom = clampf(zoom, _zoom_min, _zoom_max)
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
	var labels := _station_labels(game)
	_draw_land(game)
	_draw_labels(game, labels)
	_draw_lines(game)
	_draw_tunnels(game)
	_draw_stations(game, labels)
	_draw_orders(game)
	_draw_squads(game)
	_draw_intents(game)


func _palette_tint(base: Color, lift: float) -> Color:
	return Color(lerpf(base.r, 1.0, lift), lerpf(base.g, 1.0, lift), lerpf(base.b, 1.0, lift), 1.0)


func _map_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is Texture2D:
		return res
	return null


func _draw_land(game) -> void:
	var spec := _spec()
	var land: Dictionary = game.catalog.geo.get("land", {})
	var step := float(spec.get("densify_step", 0.0025))
	if _water_tex != null:
		draw_texture_rect(_water_tex, Rect2(Vector2.ZERO, size), true, _palette_tint(WATER, 0.42))
	for key in land:
		var ring: Array = land[key]
		var projected := Geo.project_ring(ring, spec, step)
		if projected.size() < 3:
			continue
		var screen := PackedVector2Array()
		for point in projected:
			screen.append(_screen(point))
		if _paper != null:
			var uvs := PackedVector2Array()
			var bounds := Rect2(screen[0], Vector2.ZERO)
			for point in screen:
				bounds = bounds.expand(point)
			var span := bounds.size
			if span.x < 1.0:
				span.x = 1.0
			if span.y < 1.0:
				span.y = 1.0
			for point in screen:
				uvs.append(Vector2((point.x - bounds.position.x) / span.x, (point.y - bounds.position.y) / span.y))
			var tint := PackedColorArray()
			tint.resize(screen.size())
			tint.fill(_palette_tint(LAND, 0.22))
			draw_polygon(screen, tint, uvs, _paper)
		else:
			draw_colored_polygon(screen, LAND)
		screen.append(screen[0])
		draw_polyline(screen, LAND_EDGE, 1.5, true)


func _draw_labels(game, taken: Array) -> void:
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
		var box := Rect2(at - Vector2(width * 0.5, 12), Vector2(width, 16))
		var blocked := false
		for station_box in taken:
			var mark: Rect2 = station_box.box if station_box is Dictionary else Rect2()
			if mark.size.x > 1.0 and mark.intersects(box.grow(4)):
				blocked = true
				break
		if blocked:
			continue
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


func _station_labels(game) -> Array:
	var font := _font()
	var placed: Array[Rect2] = []
	var nudges: Array[Vector2] = [Vector2(0, 16)]
	for ring in [22.0, 40.0, 58.0]:
		for step in 8:
			var ang := TAU * float(step) / 8.0
			nudges.append(Vector2(cos(ang), sin(ang)) * ring)
	var out: Array = []
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		var at := _screen(_station_world(st))
		var name := str(st.get("community", st.get("name", sid)))
		var px := 13
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var box := Rect2(at + nudges[0] + Vector2(-width * 0.5, 0), Vector2(width, 16))
		for nudge in nudges:
			var trial := Rect2(at + nudge + Vector2(-width * 0.5, 0), Vector2(width, 16))
			var hit := false
			for taken in placed:
				if taken.intersects(trial.grow(3)):
					hit = true
					break
			if not hit:
				box = trial
				break
		placed.append(box)
		out.append({"id": str(sid), "at": at, "box": box, "name": name})
	return out


func _draw_stations(game, labels: Array) -> void:
	var font := _font()
	for row in labels:
		var sid := str(row.id)
		var st: Dictionary = game.stations[sid]
		var at: Vector2 = row.at
		var col := _faction_color(game, str(st.owner))
		var radius := 7.0 if str(sid) == _hover or str(sid) == selected else 5.0
		if bool(st.get("hidden", false)):
			_dash_ring(at, radius + 3.0, col)
		else:
			draw_arc(at, radius + 3.5, 0, TAU, 20, col, 2.0)
		draw_circle(at, radius, Color("1c1814"))
		if int(st.get("low_weeks", 0)) > 0:
			var warn := ArtPack.icon_texture("warning", 16.0)
			if warn != null:
				draw_texture_rect(warn, Rect2(at + Vector2(6, -16), Vector2(16, 16)), false)
		if str(sid) == _hover:
			draw_arc(at, radius + 7.0, 0, TAU, 20, Color(0.93, 0.78, 0.45, 0.9), 2.0)
		var box: Rect2 = row.box
		draw_rect(box.grow(2.0), Color(0.05, 0.08, 0.1, 0.78))
		draw_string(font, box.position + Vector2(0, 12), str(row.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)


func _draw_orders(game) -> void:
	for row in game.queued_orders:
		var target := str(row.get("target", ""))
		var home := str(row.get("home", ""))
		if not game.stations.has(target):
			continue
		var dest := _screen(_station_world(game.stations[target]))
		if game.stations.has(home):
			var start := _screen(_station_world(game.stations[home]))
			_dash(start, dest, Color("e2a63a"))
		var kind := str(row.get("kind", "envoy"))
		var icon_name := kind
		if kind == "move":
			icon_name = "squad"
		elif kind == "expedition":
			icon_name = "artifact"
		elif kind == "trade":
			icon_name = "trade"
		var icon := ArtPack.icon_texture(icon_name, 18.0)
		var at := dest + Vector2(12, -14)
		draw_circle(at, 11.0, Color("241c14"))
		draw_arc(at, 11.0, 0, TAU, 16, Color("e2a63a"), 1.5)
		if icon != null:
			draw_texture_rect(icon, Rect2(at - Vector2(8, 8), Vector2(16, 16)), false)


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
		var icon := ArtPack.icon_texture("squad", 16.0)
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
		var icon := ArtPack.icon_texture(kind if kind != "buy" else "propaganda", 20.0)
		if kind == "demand_posted":
			icon = ArtPack.icon_texture("ultimatum", 20.0)
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
			if button.pressed and button.double_click:
				var aimed := _station_at(button.position)
				if aimed != "":
					var game = _game()
					if game != null and game.stations.has(aimed):
						origin = _station_world(game.stations[aimed])
						queue_redraw()
				accept_event()
			elif button.pressed:
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
	zoom = clampf(zoom * factor, _zoom_min, _zoom_max)
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
			text += "\n" + Copy.t("Council order") + ": " + Copy.t(_order_title(used))
		else:
			text += "\n" + Copy.t("Open seat")
		var seat_label := _lab(text, 15, false)
		seat_label.custom_minimum_size = Vector2(160, 48)
		seat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stack.add_child(seat_label)
		if used != "":
			var cancel := Button.new()
			cancel.text = Copy.t("Cancel order")
			cancel.pressed.connect(_cancel_seat.bind(role))
			stack.add_child(cancel)
		row.add_child(stack)
		_council_body.add_child(row)


func _fill_sheet(sid: String) -> void:
	for child in _sheet_body.get_children():
		child.queue_free()
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	var own := str(st.owner) == str(game.player)
	_sheet_body.add_child(_lab(str(st.community), 20, true))
	_sheet_body.add_child(_lab(str(st.name), 14, false))
	if own:
		_add_own_facts(game, st, sid, _sheet_body)
	else:
		if str(st.who) != "":
			_sheet_body.add_child(_lab(str(st.who), 14, false))
		if str(st.conflict) != "":
			_sheet_body.add_child(_lab(str(st.conflict), 14, false))
		_sheet_body.add_child(_lab("%s: %s" % [Copy.t("Owner"), Copy.t(_owner_name(game, str(st.owner)))], 14, false))
		_sheet_body.add_child(_lab("%s: %s" % [Copy.t("Loyalty"), str(int(st.loyalty))], 14, false))
		if int(st.unrest) > 0:
			_sheet_body.add_child(_lab("%s: %s" % [Copy.t("Unrest"), str(int(st.unrest))], 14, false))
		_add_needs(st, _sheet_body)
		if str(st.art) != "":
			_sheet_body.add_child(_lab(str(st.art), 13, false))
		var trade := _trade_line(st)
		if trade != "":
			_sheet_body.add_child(_lab(trade, 14, false))
	_add_actions(sid, own, _sheet_body)
	var back := Button.new()
	back.text = Copy.t("Back to the map")
	back.pressed.connect(close_sheet)
	_sheet_body.add_child(back)


func _order_button(kind: String, label: String, sid: String, parent: Node = null) -> void:
	if parent == null:
		parent = _sheet_body
	var game = _game()
	var button := Button.new()
	button.text = ""
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8.0
	row.offset_right = -8.0
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon_name := kind
	if kind == "move":
		icon_name = "squad"
	elif kind == "expedition":
		icon_name = "artifact"
	var tex := ArtPack.icon_texture(icon_name, 24.0)
	if tex != null:
		var face := TextureRect.new()
		face.texture = tex
		face.custom_minimum_size = Vector2(24, 24)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
	var detail := Copy.t("Next dawn")
	if game != null:
		var who: Dictionary = game.order_councillor()
		var who_name := str(who.get("name", ""))
		if who.is_empty():
			who_name = Copy.t("No councillor is free.")
		detail = "%s · %s · %s" % [_cost_text(game.order_cost(kind, sid)), who_name, Copy.t("Next dawn")]
	var caption := Label.new()
	caption.text = "%s\n%s" % [Copy.t(label), detail]
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Color("efe6d2"))
	row.add_child(caption)
	button.custom_minimum_size = Vector2(0, 36)
	button.add_child(row)
	var why := ""
	if game != null:
		why = game.order_block(kind, sid)
	button.disabled = why != ""
	button.tooltip_text = why
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if why == "":
		button.pressed.connect(_issue.bind(kind, sid))
	button.custom_minimum_size = Vector2(0, 52)
	parent.add_child(button)


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
	var cost: Dictionary = game.order_cost(kind, sid)
	if game.queue_order(action):
		if host != null and host.has_method("_refresh"):
			host._refresh()
		if host != null and host.has_method("note_spend"):
			host.note_spend(cost)
		if host != null and host.has_method("_toast"):
			host._toast(Copy.t("Order sent. The result comes at next dawn."))
		refresh()
		if visit != null and visit.visible:
			_fill_visit(sid)
		else:
			_fill_sheet(sid)


func _need_bar(need_id: String, fill: float) -> Control:
	var row := HBoxContainer.new()
	var name := _lab(Copy.t(need_id), 14, false)
	name.custom_minimum_size = Vector2(110, 18)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(name)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clampf(fill, 0.0, 1.0) * 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Color("c4544a")
	if fill >= 0.66:
		col = Color("7dba6a")
	elif fill >= 0.40:
		col = Color("e2a63a")
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = col
	bar.add_theme_stylebox_override("fill", fill_box)
	row.add_child(bar)
	var num := _lab(str(int(round(clampf(fill, 0.0, 1.0) * 100.0))), 14, true)
	num.add_theme_color_override("font_color", col)
	num.custom_minimum_size = Vector2(36, 18)
	row.add_child(num)
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
	if fid == "neutral":
		return "Neutral"
	if fid == "bunker":
		return "Bunker"
	if fid == "ruin":
		return "Ruin"
	if fid == "enemy":
		return "Enemy"
	return fid.capitalize()


func _cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return Copy.t("No cost")
	var bits: PackedStringArray = []
	for key in cost:
		bits.append("%d %s" % [int(cost[key]), Copy.res(str(key))])
	return ", ".join(bits)


func _order_title(kind: String) -> String:
	match kind:
		"envoy":
			return "Send envoy"
		"propaganda":
			return "Propaganda"
		"move":
			return "Move squad"
		"trade":
			return "Open trade"
		"expedition":
			return "Start expedition"
		_:
			return kind.capitalize()


func _cancel_seat(role: String) -> void:
	var game = _game()
	if game == null or not game.cancel_queued(role):
		return
	if host != null and host.has_method("_refresh"):
		host._refresh()
	refresh()
	if selected != "":
		_fill_sheet(selected)


func _add_needs(st: Dictionary, parent: Node) -> void:
	var needs: Array = st.get("needs", [])
	if needs.is_empty():
		return
	parent.add_child(_lab(Copy.t("Needs"), 14, true))
	for need in needs:
		parent.add_child(_need_bar(str(need.id), float(need.fill)))


func _trade_line(st: Dictionary) -> String:
	var goods: PackedStringArray = []
	for need in st.get("needs", []):
		goods.append(Copy.t(str(need.id)))
	if int(st.get("deals", 0)) > 0:
		goods.append(Copy.t("Deals %d") % int(st.deals))
	if goods.is_empty():
		return ""
	return "%s: %s" % [Copy.t("They trade"), ", ".join(goods)]


func _add_own_facts(game, st: Dictionary, sid: String, parent: Node) -> void:
	parent.add_child(_lab("%s: %d" % [Copy.t("Population"), int(st.pop)], 14, false))
	parent.add_child(_lab("%s: %d" % [Copy.t("Loyalty"), int(st.loyalty)], 14, false))
	parent.add_child(_lab("%s: %d" % [Copy.t("Garrison"), int(st.garrison)], 14, false))
	parent.add_child(_lab(_supply_text(game, sid), 14, false))
	parent.add_child(_lab(_ships_text(game, st, sid), 14, false))
	_add_needs(st, parent)


func _supply_text(game, sid: String) -> String:
	if str(sid) == str(game.capital_id):
		return Copy.t("This is the capital.")
	var hops := int(game._supply_hops(str(sid)))
	if hops >= 900:
		return Copy.t("The supply line is cut.")
	return Copy.t("The supply line is open.")


func _ships_text(game, st: Dictionary, sid: String) -> String:
	if str(sid) == str(game.capital_id):
		return Copy.t("Ships home") + ": " + Copy.t("This is the capital.")
	var hops := int(game._supply_hops(str(sid)))
	var flow: Dictionary = Formulas.outpost_flow(int(st.get("held_weeks", 0)), hops, str(st.get("focus", "")))
	if int(flow.get("upkeep_materials", 0)) > 0:
		return Copy.t("It costs 1 material a week until it can ship.")
	var bits: PackedStringArray = []
	for key in ["food", "materials", "tokens", "influence", "air"]:
		var gain := int(flow.get(key, 0))
		if gain > 0:
			bits.append("%d %s" % [gain, Copy.res(key)])
	if bits.is_empty():
		return Copy.t("It ships nothing home this week.")
	return "%s: %s" % [Copy.t("Ships home"), ", ".join(bits)]


func _add_actions(sid: String, own: bool, parent: Node) -> void:
	var open_b := Button.new()
	open_b.text = Copy.t("Open station")
	open_b.pressed.connect(_open_station.bind(sid))
	parent.add_child(open_b)
	if own:
		_order_button("move", "Garrison", sid, parent)
		return
	_order_button("envoy", "Send envoy", sid, parent)
	_order_button("propaganda", "Propaganda", sid, parent)
	_order_button("move", "Move squad", sid, parent)
	_order_button("trade", "Open trade", sid, parent)
	_order_button("expedition", "Start expedition", sid, parent)


func _open_station(sid: String) -> void:
	var game = _game()
	if game != null and str(sid) == str(game.capital_id):
		if host != null and host.has_method("_toggle_network"):
			host._toggle_network()
		return
	_cam_origin = origin
	_cam_zoom = zoom
	_show_visit(sid)


func _build_visit() -> void:
	visit = PanelContainer.new()
	visit.visible = false
	visit.mouse_filter = Control.MOUSE_FILTER_STOP
	visit.z_index = 6
	visit.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 1.0)
	style.set_content_margin_all(16)
	visit.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visit_body = VBoxContainer.new()
	_visit_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visit_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_visit_body)
	visit.add_child(scroll)
	add_child(visit)


func open_visit(sid: String) -> void:
	_cam_origin = origin
	_cam_zoom = zoom
	_show_visit(sid)


func close_visit() -> void:
	if visit != null:
		visit.visible = false
	if sheet != null and selected != "":
		sheet.visible = true
	origin = _cam_origin
	zoom = _cam_zoom
	queue_redraw()


func _show_visit(sid: String) -> void:
	if visit == null:
		return
	visit.offset_top = 78.0
	if host != null and host.get("hud") != null and host.hud.size.y > 8.0:
		visit.offset_top = host.hud.size.y
	if sheet != null:
		sheet.visible = false
	visit.visible = true
	_fill_visit(sid)


func _fill_visit(sid: String) -> void:
	if _visit_body == null:
		return
	for child in _visit_body.get_children():
		child.queue_free()
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	var hub := _hub_tex(game, st)
	if hub != null:
		var face := TextureRect.new()
		face.texture = hub
		face.custom_minimum_size = Vector2(0, 220)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_visit_body.add_child(face)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	if host != null and host.has_method("_portrait_box"):
		head.add_child(host._portrait_box(str(sid), 96))
	var quote := str(st.conflict) if str(st.conflict) != "" else str(st.who)
	var words := _lab(quote, 18, true)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(words)
	_visit_body.add_child(head)
	_visit_body.add_child(_lab(str(st.community), 22, true))
	_visit_body.add_child(_lab(str(st.name), 15, false))
	if str(st.who) != "":
		_visit_body.add_child(_lab(str(st.who), 15, false))
	_add_needs(st, _visit_body)
	var relation := int(st.get("sympathy", 0))
	if game.opinions.has(str(st.owner)):
		relation = int(game.opinions[str(st.owner)])
	_visit_body.add_child(_lab("%s: %d    %s: %d" % [Copy.t("Relation"), relation, Copy.t("Loyalty"), int(st.loyalty)], 15, false))
	var trade := _trade_line(st)
	if trade != "":
		_visit_body.add_child(_lab(trade, 15, false))
	if str(st.art) != "":
		_visit_body.add_child(_lab(str(st.art), 14, false))
	_add_actions(sid, str(st.owner) == str(game.player), _visit_body)
	var back := Button.new()
	back.text = Copy.t("Back to map")
	back.pressed.connect(close_visit)
	_visit_body.add_child(back)


func _hub_tex(game, st: Dictionary) -> Texture2D:
	var sid := str(st.get("id", ""))
	var paths: PackedStringArray = []
	if sid == str(game.capital_id):
		paths.append("res://assets/hubs/hub_coney_island.webp")
	paths.append("res://assets/hubs/%s.webp" % sid)
	paths.append("res://assets/hubs/hub_%s.webp" % str(st.get("lean", "")))
	var room := "workshop"
	match str(st.get("lean", "")):
		"order", "faith":
			room = "meeting_hall"
		"trade":
			room = "radio"
		_:
			room = "workshop"
	paths.append("res://assets/rooms/room_%s.webp" % room)
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		var tex := ArtPack.load_texture(path)
		if tex != null:
			return tex
	return null


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
