class_name NetworkView
extends Control

## The overseer's desk: the painted city map pinned under the lamp. The week still lives on Game.

const ArtPack = preload("res://ui/art_pack.gd")
const PINS_JSON := "res://data/map_pins.json"
const MAP_FILE := "res://incoming-art/map/nyc_map.png"
const PAPER := Color("241c14")
const INK := Color("f4efe4")
const MUTED := Color("d9cbb4")
const CARD := Color("ece1c6")
const CARD_INK := Color("2b2118")
const CARD_MUTED := Color("554533")
const TAG_PAPER := Color("efe4c8")
const TAG_INK := Color("2b2118")
const GRAPHITE := Color(0.19, 0.18, 0.17, 0.78)
const ORDER_RED := Color("a0281e")
const LINE_COLOR := {
	"g": Color("46783c"),
	"b": Color("285096"),
	"r": Color("a0281e"),
	"a": Color("1e7873"),
}
const LINE_ALPHA := 0.85
const LINE_WIDTH := 5.0
const LINE_GAP := 3.0
const WASH_RADIUS := 70.0
const PIN_CAPITAL := 52.0
const PIN_OTHER := 38.0
const PIN_FLOOR := 24.0
const ZOOM_SPAN := 3.5
const PIN_SPRITE := {"depot": "depot", "directorate": "dir", "exchange": "exch", "synod": "synod"}
const FLAG_ANCHOR := Vector2(0.176, 0.35)
const FLAG_CLOTH := Vector2(0.62, 0.42)


class Layer extends Control:
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


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
var _zoom_min := 1.0
var _zoom_max := 3.5
var _cam_origin := Vector2.ZERO
var _cam_zoom := 1.0
var visit: PanelContainer
var _visit_body: VBoxContainer
var _paper: Texture2D
var _desk: Texture2D
var _map: Texture2D
var _pins: Texture2D
var _desk_size := Vector2(1536, 1024)
var _map_size := Vector2(1024, 1536)
var _map_xf := Transform2D.IDENTITY
var _spots := {}
var _pin_rects := {}
var _head_anchor := Vector2(0.4, 0.36)
var _weights: Array[Vector2] = []
var _weight_radius := 34.0
var _washes := {}
var _dot: Texture2D
var _base_layer: Control
var _wash_layer: Control
var _ink_layer: Control
var _layout := {}
var _lift := {}
var _on_paper := false
var _tag_font: Font
var _italic: Font
var _glide: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	clip_contents = true
	_load_desk()
	_base_layer = _add_layer(_draw_base)
	_wash_layer = _add_layer(_draw_wash)
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_wash_layer.material = mul
	_ink_layer = _add_layer(_draw_ink)
	_paper = _map_tex("res://incoming-art/map/paper.png")
	_build_sheet()
	_build_council()
	_build_visit()
	resized.connect(_on_resize)


func _add_layer(paint: Callable) -> Control:
	var layer := Layer.new()
	layer.paint = paint
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(layer)
	return layer


func _load_desk() -> void:
	var cfg := {}
	var f := FileAccess.open(PINS_JSON, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			cfg = parsed
	_map_size = _vec(cfg.get("map_size", []), _map_size)
	_spots = cfg.get("stations", {})
	var desk: Dictionary = cfg.get("desk", {})
	_desk_size = _vec(desk.get("size", []), _desk_size)
	_desk = _map_tex("res://" + str(desk.get("file", "incoming-art/map/desk_empty.png")))
	_map = _map_tex(MAP_FILE)
	var turn := deg_to_rad(float(desk.get("map_rotation_deg", 0.0)))
	var k := float(desk.get("map_scale", 1.0))
	var center := _vec(desk.get("map_center", []), _desk_size * 0.5)
	_map_xf = Transform2D(turn, Vector2(k, k), 0.0, center) * Transform2D(0.0, -_map_size * 0.5)
	for spot in desk.get("weights", []):
		_weights.append(_vec(spot, Vector2.ZERO))
	_weight_radius = float(desk.get("weight_radius", 34.0))
	var sheet_cfg: Dictionary = cfg.get("pins_sheet", {})
	_pins = _map_tex("res://" + str(sheet_cfg.get("file", "incoming-art/map/pins.png")))
	_head_anchor = _vec(sheet_cfg.get("head_anchor", []), _head_anchor)
	var rects: Dictionary = sheet_cfg.get("rects", {})
	for key in rects:
		var r = rects[key]
		if r is Array and r.size() >= 4:
			var top_left := Vector2(float(r[0]), float(r[1]))
			_pin_rects[str(key)] = Rect2(top_left, Vector2(float(r[2]), float(r[3])) - top_left)


func _vec(raw, fallback: Vector2) -> Vector2:
	if raw is Array and raw.size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return fallback


func bind(station) -> void:
	host = station
	_fitted = false
	refresh()


func refresh() -> void:
	_track_hops()
	_place_panels()
	_fill_council()
	if selected != "":
		_fill_sheet(selected)
	_redraw()


func _redraw() -> void:
	queue_redraw()
	for layer in [_base_layer, _wash_layer, _ink_layer]:
		if layer != null:
			layer.queue_redraw()


func open_sheet(sid: String) -> void:
	selected = sid
	sheet.visible = true
	_fill_sheet(sid)
	_redraw()


func close_sheet() -> void:
	selected = ""
	sheet.visible = false
	_redraw()


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
	zoom = clampf(maxf(zoom, _zoom_min * 2.0), _zoom_min, _zoom_max)
	_clamp_view()
	_redraw()


func show_zoom(ratio: float, sid: String) -> void:
	zoom = clampf(_zoom_min * ratio, _zoom_min, _zoom_max)
	var game = _game()
	if sid != "" and game != null and game.stations.has(sid):
		origin = _station_world(game.stations[sid])
	else:
		origin = _desk_size * 0.5
	_clamp_view()
	_redraw()


func station_anchor(sid: String, host: Control) -> Rect2:
	var game = _game()
	if game == null or not game.stations.has(sid) or host == null:
		return Rect2()
	var at := _screen(_station_world(game.stations[sid]))
	if _layout.has(sid):
		at = _layout[sid].at
	var global_at := get_global_rect().position + at
	var corner := host.get_global_rect().position
	return Rect2(global_at - corner - Vector2(18, 18), Vector2(36, 36))


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
			zoom = clampf(maxf(zoom, _zoom_min * 1.8), _zoom_min, _zoom_max)
			_clamp_view()
			_redraw()
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
	if not visible:
		return
	var busy := false
	if _hop_left > 0.0:
		_hop_left = maxf(0.0, _hop_left - delta)
		busy = true
	if _hover != "" and not _lift.has(_hover):
		_lift[_hover] = 0.0
	for sid in _lift.keys():
		var goal := 1.0 if sid == _hover else 0.0
		var now := float(_lift[sid])
		if is_equal_approx(now, goal):
			if goal == 0.0:
				_lift.erase(sid)
			continue
		_lift[sid] = goal if _motion_off() else move_toward(now, goal, delta / 0.12)
		busy = true
	if busy and _ink_layer != null:
		_ink_layer.queue_redraw()


func _on_resize() -> void:
	_place_panels()
	if not _fitted:
		_fit()
		return
	_zoom_range()
	zoom = clampf(zoom, _zoom_min, _zoom_max)
	_clamp_view()
	_redraw()


func _center() -> Vector2:
	return size * 0.5


func _view() -> Transform2D:
	return Transform2D(0.0, Vector2(zoom, zoom), 0.0, _center() - origin * zoom)


func _screen(world: Vector2) -> Vector2:
	return (world - origin) * zoom + _center()


func _world(screen_at: Vector2) -> Vector2:
	return (screen_at - _center()) / zoom + origin


func _map_spot(sid: String) -> Vector2:
	return _vec(_spots.get(sid, []), _map_size * 0.5)


func _station_world(st: Dictionary) -> Vector2:
	return _map_xf * _map_spot(str(st.get("id", "")))


func _map_scale() -> float:
	return maxf(_map_xf.get_scale().x, 0.01)


func _map_box() -> Rect2:
	var box := Rect2(_map_xf * Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(_map_size.x, 0.0), _map_size, Vector2(0.0, _map_size.y)]:
		box = box.expand(_map_xf * corner)
	return box


func _zoom_range() -> void:
	_zoom_min = maxf(size.x / _desk_size.x, size.y / _desk_size.y)
	_zoom_max = _zoom_min * ZOOM_SPAN


func _clamp_view() -> void:
	var box := _map_box()
	origin = origin.clamp(box.position, box.end)
	var half := size / (2.0 * maxf(zoom, 0.001))
	if half.x * 2.0 < _desk_size.x:
		origin.x = clampf(origin.x, half.x, _desk_size.x - half.x)
	else:
		origin.x = _desk_size.x * 0.5
	if half.y * 2.0 < _desk_size.y:
		origin.y = clampf(origin.y, half.y, _desk_size.y - half.y)
	else:
		origin.y = _desk_size.y * 0.5


func _fit() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	_zoom_range()
	zoom = _zoom_min
	origin = _desk_size * 0.5
	_clamp_view()
	_fitted = true
	_place_panels()
	_redraw()


func _map_tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is Texture2D:
		return res
	return null


func _hash(text: String) -> int:
	return absi(hash(text))


func _secret(st: Dictionary) -> bool:
	return bool(st.get("hidden", false)) and not bool(st.get("known", false))


func _soft_dot() -> Texture2D:
	if _dot != null:
		return _dot
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_dot = tex
	return _dot


func _shadow(c: CanvasItem, center: Vector2, radius: float, alpha: float) -> void:
	c.draw_texture_rect(_soft_dot(), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, Color(1, 1, 1, alpha))


func _soft_rect(c: CanvasItem, rect: Rect2, spread: float, col: Color) -> void:
	c.draw_rect(rect, col)
	var clear := Color(col, 0.0)
	var o := rect.grow(spread)
	var inner := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var outer := [o.position, Vector2(o.end.x, o.position.y), o.end, Vector2(o.position.x, o.end.y)]
	for i in 4:
		var j := (i + 1) % 4
		c.draw_polygon(PackedVector2Array([inner[i], inner[j], outer[j], outer[i]]), PackedColorArray([col, col, clear, clear]))


func _draw_base(c: CanvasItem) -> void:
	if not _fitted:
		_fit()
	c.draw_rect(Rect2(Vector2.ZERO, size), Color("120d09"))
	var view := _view()
	c.draw_set_transform_matrix(view)
	if _desk != null:
		c.draw_texture_rect(_desk, Rect2(Vector2.ZERO, _desk_size), false)
	c.draw_set_transform_matrix(view * _map_xf)
	_soft_rect(c, Rect2(Vector2(16, 26), _map_size - Vector2(8, 8)), 46.0, Color(0, 0, 0, 0.55))
	if _map != null:
		c.draw_texture_rect(_map, Rect2(Vector2.ZERO, _map_size), false, Color(1.0, 0.96, 0.9))
	else:
		c.draw_rect(Rect2(Vector2.ZERO, _map_size), Color("d8c8a4"))
	c.draw_set_transform_matrix(view)
	_draw_weights(c)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_weights(c: CanvasItem) -> void:
	if _desk == null:
		return
	for spot in _weights:
		_shadow(c, spot + Vector2(4, 7), _weight_radius * 1.35, 0.55)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 32:
			var ang := TAU * float(i) / 32.0
			var p := spot + Vector2(cos(ang), sin(ang)) * _weight_radius
			pts.append(p)
			uvs.append(p / _desk_size)
		c.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _desk)


func _draw_wash(c: CanvasItem) -> void:
	var game = _game()
	if game == null:
		return
	c.draw_set_transform_matrix(_view() * _map_xf)
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if not bool(st.get("known", false)) or not PIN_SPRITE.has(str(st.owner)):
			continue
		var tex := _wash_for(str(st.owner))
		var at := _map_spot(str(sid))
		var h := _hash(str(sid))
		for k in 3:
			var off := Vector2(float((h >> (k * 5)) % 13) - 6.0, float((h >> (k * 5 + 3)) % 13) - 6.0) * 3.0
			var r := WASH_RADIUS * (0.8 + 0.15 * float(k))
			c.draw_texture_rect(tex, Rect2(at + off - Vector2(r, r), Vector2(r, r) * 2.0), false)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _wash_for(owner: String) -> Texture2D:
	if _washes.has(owner):
		return _washes[owner]
	var col := _faction_color(_game(), owner)
	var grad := Gradient.new()
	grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color.WHITE.lerp(col, 0.24), Color.WHITE.lerp(col, 0.13), Color.WHITE])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_washes[owner] = tex
	return tex


func _draw_ink(c: CanvasItem) -> void:
	var game = _game()
	if game == null:
		return
	_ready_fonts()
	var view := _view()
	c.draw_set_transform_matrix(view * _map_xf)
	_draw_lines(c, game)
	_draw_tunnels(c, game)
	_draw_order_trails(c, game)
	_draw_lamp(c, view)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_layout_pins(game)
	_draw_leaders(c)
	_draw_pins(c, game)
	_draw_tags(c, game)
	_draw_flags(c, game)
	_draw_squads(c, game)
	_draw_intents(c, game)


func _draw_lamp(c: CanvasItem, view: Transform2D) -> void:
	c.draw_set_transform_matrix(view)
	var cols := 12
	var rows := 8
	var cell := _desk_size / Vector2(cols, rows)
	var lamp := _desk_size * Vector2(0.05, 0.03)
	var reach := _desk_size.length()
	for y in rows:
		for x in cols:
			var p0 := Vector2(x, y) * cell
			var quad := PackedVector2Array([p0, p0 + Vector2(cell.x, 0), p0 + cell, p0 + Vector2(0, cell.y)])
			var shades := PackedColorArray()
			for p in quad:
				var t := clampf((p.distance_to(lamp) / reach - 0.3) / 0.7, 0.0, 1.0)
				shades.append(Color(0.05, 0.03, 0.01, 0.5 * t * t))
			c.draw_polygon(quad, shades)


func _edge_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func _segment_alpha(game, a: String, b: String) -> float:
	var sa: Dictionary = game.stations[a]
	var sb: Dictionary = game.stations[b]
	if _secret(sa) or _secret(sb):
		return 0.0
	var ka := bool(sa.get("known", false))
	var kb := bool(sb.get("known", false))
	if ka and kb:
		return 1.0
	if ka or kb:
		return 0.45
	return 0.0


func _wobble(a: Vector2, b: Vector2, seed: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var d := b - a
	var length := d.length()
	if length < 0.5:
		return pts
	var perp := Vector2(-d.y, d.x) / length
	var steps := maxi(2, int(length / 9.0))
	var p1 := fmod(float(seed % 1000) * 0.618034, 1.0) * TAU
	var p2 := fmod(float(seed % 997) * 0.414214, 1.0) * TAU
	for i in steps + 1:
		var t := float(i) / float(steps)
		var w := (sin(t * 5.3 + p1) * 0.6 + sin(t * 11.7 + p2) * 0.4) * amp * sin(t * PI)
		pts.append(a + d * t + perp * w)
	return pts


func _marker(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, seed: int) -> void:
	var pts := _wobble(a, b, seed, width * 0.35)
	if pts.size() < 2:
		return
	c.draw_polyline(pts, col, width, true)
	var d := (b - a).normalized()
	var edge := Vector2(-d.y, d.x) * width * 0.3
	var rim := _wobble(a + edge, b + edge, seed + 7, width * 0.3)
	c.draw_polyline(rim, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6, col.a * 0.3), width * 0.3, true)


func _draw_lines(c: CanvasItem, game) -> void:
	var lines: Dictionary = game.catalog.communities.get("lines", {})
	var shared := {}
	for line_id in lines:
		var stops: Array = lines[line_id]
		for i in range(stops.size() - 1):
			var key := _edge_key(str(stops[i]), str(stops[i + 1]))
			if not shared.has(key):
				shared[key] = []
			shared[key].append(str(line_id))
	var k := 1.0 / _map_scale()
	for line_id in lines:
		var stops: Array = lines[line_id]
		var col: Color = LINE_COLOR.get(str(line_id), Color("3a3028"))
		for i in range(stops.size() - 1):
			var a := str(stops[i])
			var b := str(stops[i + 1])
			if not game.stations.has(a) or not game.stations.has(b):
				continue
			var fade := _segment_alpha(game, a, b)
			if fade <= 0.0:
				continue
			var key := _edge_key(a, b)
			var users: Array = shared[key]
			var slot := float(users.find(str(line_id))) - float(users.size() - 1) * 0.5
			var dir := (_map_spot(key.get_slice("|", 1)) - _map_spot(key.get_slice("|", 0))).normalized()
			var shift := Vector2(-dir.y, dir.x) * slot * LINE_GAP * k
			_marker(c, _map_spot(a) + shift, _map_spot(b) + shift, Color(col, LINE_ALPHA * fade), LINE_WIDTH * k, _hash(key + str(line_id)))


func _draw_tunnels(c: CanvasItem, game) -> void:
	var k := 1.0 / _map_scale()
	for tunnel in game.tunnels:
		var state := str(tunnel.get("state", "open"))
		if state == "open":
			continue
		var a := str(tunnel.a)
		var b := str(tunnel.b)
		if not game.stations.has(a) or not game.stations.has(b):
			continue
		var fade := _segment_alpha(game, a, b)
		if fade <= 0.0:
			continue
		var col := Color(0.16, 0.32, 0.45, 0.8 * fade) if state == "flooded" else Color(GRAPHITE, GRAPHITE.a * fade)
		_dash(c, _map_spot(a), _map_spot(b), col, 1.6 * k, 7.0 * k, 12.0 * k)


func _dash(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, dash: float, step: float) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 1.0:
		return
	dir /= length
	var t := 0.0
	while t < length:
		var t2 := minf(length, t + dash)
		c.draw_line(a + dir * t, a + dir * t2, col, width, true)
		t += step


func _draw_order_trails(c: CanvasItem, game) -> void:
	var k := 1.0 / _map_scale()
	for row in game.queued_orders:
		var target := str(row.get("target", ""))
		var home := str(row.get("home", ""))
		if not game.stations.has(target) or not game.stations.has(home) or _secret(game.stations[target]):
			continue
		var a := _map_spot(home)
		var b := _map_spot(target)
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var t := 0.0
		while t <= length:
			c.draw_circle(a.lerp(b, t / length), 2.1 * k, Color(ORDER_RED, 0.9))
			t += 9.0 * k


func _pin_px(game, sid: String) -> float:
	var st: Dictionary = game.stations[sid]
	var big := bool(st.get("capital", false)) or sid == str(game.capital_id)
	return maxf(PIN_FLOOR, (PIN_CAPITAL if big else PIN_OTHER) * sqrt(zoom))


func _layout_pins(game) -> void:
	_layout.clear()
	var ids: Array[String] = []
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if _secret(st):
			continue
		var spot := _screen(_station_world(st))
		var known := bool(st.get("known", false))
		var px := _pin_px(game, str(sid)) if known else maxf(PIN_FLOOR, 26.0 * sqrt(zoom))
		var radius := px * 0.42 if known else px * 0.45
		var big := known and (bool(st.get("capital", false)) or str(sid) == str(game.capital_id))
		_layout[str(sid)] = {"spot": spot, "at": spot, "px": px, "r": radius, "known": known, "big": big}
		ids.append(str(sid))
	for _round in 14:
		var moved := false
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var p: Dictionary = _layout[ids[i]]
				var q: Dictionary = _layout[ids[j]]
				var gap: Vector2 = q.at - p.at
				var need := (float(p.r) + float(q.r)) * 0.9
				var dist := gap.length()
				if dist >= need:
					continue
				var dir := gap / dist if dist > 0.01 else Vector2.RIGHT.rotated(float(i * 7 + j))
				var wp := 0.3 if bool(p.big) else 1.0
				var wq := 0.3 if bool(q.big) else 1.0
				var push := (need - dist) / (wp + wq)
				p["at"] = (p.at as Vector2) - dir * push * wp
				q["at"] = (q.at as Vector2) + dir * push * wq
				moved = true
		if not moved:
			break


func _draw_leaders(c: CanvasItem) -> void:
	for sid in _layout:
		var row: Dictionary = _layout[sid]
		var spot: Vector2 = row.spot
		var at: Vector2 = row.at
		if spot.distance_to(at) < 3.0:
			continue
		c.draw_line(spot, at, GRAPHITE, 1.0, true)
		c.draw_circle(spot, 2.0, GRAPHITE)


func _draw_pins(c: CanvasItem, game) -> void:
	var order: Array = _layout.keys()
	order.sort_custom(_pin_order)
	for sid in order:
		var row: Dictionary = _layout[sid]
		if bool(row.known):
			_draw_pin(c, game, str(sid), row)
		else:
			_draw_unknown(c, str(sid), row)


func _pin_order(a, b) -> bool:
	var fa := 1 if a == _hover or a == selected else 0
	var fb := 1 if b == _hover or b == selected else 0
	if fa != fb:
		return fa < fb
	return float(_layout[a].at.y) < float(_layout[b].at.y)


func _draw_pin(c: CanvasItem, game, sid: String, row: Dictionary) -> void:
	var st: Dictionary = game.stations[sid]
	var key := str(PIN_SPRITE.get(str(st.owner), "neutral"))
	var src: Rect2 = _pin_rects.get(key, Rect2())
	var at: Vector2 = row.at
	var px := float(row.px)
	var r := float(row.r)
	var lift := float(_lift.get(sid, 0.0))
	if lift > 0.0:
		_shadow(c, at + Vector2(1.5, 2.0) * lift, r * 1.15, 0.45 * lift)
	if _pins == null or src.size.x < 1.0:
		var col := _faction_color(game, str(st.owner))
		c.draw_circle(at - Vector2(0, 2.0 * lift), r, col)
		c.draw_arc(at - Vector2(0, 2.0 * lift), r, 0, TAU, 24, Color("3a2a1a"), 1.5, true)
	else:
		var dst := src.size * (px / src.size.x)
		c.draw_texture_rect_region(_pins, Rect2(at - _head_anchor * dst - Vector2(0, 2.0 * lift), dst), src)
	if sid == selected:
		c.draw_arc(at, r + 5.0, 0, TAU, 32, GRAPHITE, 1.6, true)
		c.draw_arc(at + Vector2(0.8, -0.5), r + 6.0, 0.4, TAU - 0.3, 30, Color(GRAPHITE, 0.4), 1.0, true)
	if int(st.get("low_weeks", 0)) > 0:
		var warn := ArtPack.icon_texture("warning", 16.0)
		if warn != null:
			c.draw_texture_rect(warn, Rect2(at + Vector2(r * 0.6, -r - 14.0), Vector2(16, 16)), false)


func _draw_unknown(c: CanvasItem, sid: String, row: Dictionary) -> void:
	var at: Vector2 = row.at
	var r := float(row.r)
	var ink := Color(GRAPHITE, 0.95 if sid == _hover else 0.75)
	var turn := float(_hash(sid) % 7) * 0.4
	c.draw_arc(at, r, turn, turn + TAU * 0.97, 32, ink, 1.4, true)
	c.draw_arc(at + Vector2(0.8, -0.6), r * 0.95, turn + 1.2, turn + 1.2 + TAU * 0.8, 28, Color(ink, ink.a * 0.55), 1.0, true)
	var font := _font()
	var fs := int(clampf(r * 1.25, 12.0, 40.0))
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _ready_fonts() -> void:
	if _tag_font != null:
		return
	var display: Font = host.get("display_font") if host != null else null
	_tag_font = display if display != null else _font()
	var slant := FontVariation.new()
	slant.base_font = _font()
	slant.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-0.22, 1.0), Vector2.ZERO)
	_italic = slant


func _tag_level() -> int:
	var ratio := zoom / maxf(_zoom_min, 0.001)
	if ratio < 1.7:
		return 0
	if ratio < 2.7:
		return 1
	return 2


func _hits(box: Rect2, boxes: Array) -> bool:
	for other in boxes:
		if box.intersects(other):
			return true
	return false


func _draw_tags(c: CanvasItem, game) -> void:
	var level := _tag_level()
	var rows: Array = []
	for sid in _layout:
		var row: Dictionary = _layout[sid]
		if not bool(row.known):
			continue
		var st: Dictionary = game.stations[sid]
		var own := str(st.owner) == str(game.player)
		var focus: bool = sid == _hover or sid == selected
		if level == 0 and not (bool(row.big) or own or focus):
			continue
		var weight := 10
		if sid == str(game.capital_id):
			weight = 100
		elif bool(row.big):
			weight = 80
		elif own:
			weight = 60
		if focus:
			weight += 200
		rows.append({"id": sid, "w": weight})
	rows.sort_custom(func(a, b): return int(a.w) > int(b.w))
	var heads: Array = []
	for sid in _layout:
		var info: Dictionary = _layout[sid]
		var r := float(info.r)
		heads.append({"id": sid, "box": Rect2(info.at - Vector2(r, r), Vector2(r, r) * 2.0)})
	var placed: Array = []
	var fs := 14 if level < 2 else 15
	for row in rows:
		var sid := str(row.id)
		var info: Dictionary = _layout[sid]
		var st: Dictionary = game.stations[sid]
		var title := str(st.get("community", st.get("name", sid)))
		var sub := str(st.get("name", "")) if level == 2 else ""
		var width := _tag_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if sub != "":
			width = maxf(width, _italic.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		var h := _tag_font.get_height(fs) + 6.0
		if sub != "":
			h += _italic.get_height(11)
		var w := width + 18.0
		var at: Vector2 = info.at
		var reach := float(info.r) + 5.0
		var right := Rect2(at + Vector2(reach, -h * 0.5), Vector2(w, h))
		var left := Rect2(at + Vector2(-reach - w, -h * 0.5), Vector2(w, h))
		var sides := [right, left]
		if right.end.x > size.x - 8.0:
			sides = [left, right]
		var others: Array = []
		for head in heads:
			if str(head.id) != sid:
				others.append(head.box)
		var chosen := Rect2()
		var found := false
		for strict in [true, false]:
			for box in sides:
				if _hits(box, placed) or (strict and _hits(box, others)):
					continue
				chosen = box
				found = true
				break
			if found:
				break
		if not found:
			continue
		placed.append(chosen.grow(3.0))
		_paint_tag(c, chosen, title, sub, fs, _faction_color(game, str(st.owner)), sid)


func _paint_tag(c: CanvasItem, box: Rect2, title: String, sub: String, fs: int, strip: Color, sid: String) -> void:
	var tilt := deg_to_rad(float(_hash(sid + "#tag") % 61 - 30) / 10.0)
	var pivot := box.get_center()
	c.draw_set_transform(pivot, tilt)
	var local := Rect2(box.position - pivot, box.size)
	c.draw_rect(Rect2(local.position + Vector2(1.5, 2.0), local.size), Color(0, 0, 0, 0.35))
	c.draw_rect(local, TAG_PAPER)
	c.draw_rect(Rect2(local.position, Vector2(5.0, local.size.y)), strip)
	c.draw_rect(local, Color(TAG_INK, 0.85), false, 1.0)
	var base := local.position.y + 3.0 + _tag_font.get_ascent(fs)
	c.draw_string(_tag_font, Vector2(local.position.x + 10.0, base), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TAG_INK)
	if sub != "":
		var sub_base := base + _tag_font.get_descent(fs) + _italic.get_ascent(11)
		c.draw_string(_italic, Vector2(local.position.x + 10.0, sub_base), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(TAG_INK, 0.8))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _order_icon(kind: String) -> String:
	match kind:
		"move":
			return "squad"
		"expedition":
			return "artifact"
		_:
			return kind


func _draw_flags(c: CanvasItem, game) -> void:
	var src: Rect2 = _pin_rects.get("flag", Rect2())
	for row in game.queued_orders:
		var target := str(row.get("target", ""))
		if not _layout.has(target):
			continue
		var info: Dictionary = _layout[target]
		var r := float(info.r)
		var at: Vector2 = info.at + Vector2(r * 0.7, -r * 0.9)
		var icon := ArtPack.icon_texture(_order_icon(str(row.get("kind", "envoy"))), 18.0)
		if _pins == null or src.size.x < 1.0:
			c.draw_circle(at, 11.0, TAG_PAPER)
			c.draw_arc(at, 11.0, 0, TAU, 16, ORDER_RED, 1.5, true)
			if icon != null:
				c.draw_texture_rect(icon, Rect2(at - Vector2(8, 8), Vector2(16, 16)), false)
			continue
		var w := maxf(56.0, 80.0 * sqrt(zoom))
		var dst := src.size * (w / src.size.x)
		var corner := at - FLAG_ANCHOR * dst
		c.draw_texture_rect_region(_pins, Rect2(corner, dst), src)
		if icon != null:
			var s := clampf(dst.y * 0.3, 10.0, 22.0)
			c.draw_texture_rect(icon, Rect2(corner + FLAG_CLOTH * dst - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(0.45, 0.2, 0.14, 0.85))


func _pin_at(game, sid: String) -> Vector2:
	if _layout.has(sid):
		return _layout[sid].at
	return _screen(_station_world(game.stations[sid]))


func _draw_squads(c: CanvasItem, game) -> void:
	for fid in game.squads:
		var sq: Dictionary = game.squads[fid]
		var sid := str(sq.station)
		if not game.stations.has(sid) or _secret(game.stations[sid]):
			continue
		if not bool(game.stations[sid].get("known", false)) and str(fid) != game.player:
			continue
		var at := _pin_at(game, sid)
		if _hop.has(str(fid)) and _hop_left > 0.0 and not _motion_off():
			var from_world: Vector2 = _hop[str(fid)]
			var to_world := _station_world(game.stations[sid])
			at = _screen(from_world.lerp(to_world, 1.0 - _hop_left / 0.6))
		var r := float(_layout[sid].r) if _layout.has(sid) else 12.0
		at += Vector2(r * 0.9, r * 0.6)
		var col := _faction_color(game, str(fid))
		c.draw_circle(at + Vector2(1, 2), 10.0, Color(0, 0, 0, 0.35))
		c.draw_circle(at, 10.0, TAG_PAPER)
		c.draw_arc(at, 10.0, 0, TAU, 20, col, 2.0, true)
		var icon := ArtPack.icon_texture("squad", 16.0)
		if icon != null:
			c.draw_texture_rect(icon, Rect2(at - Vector2(8, 8), Vector2(16, 16)), false, Color(0.25, 0.18, 0.12))
		else:
			c.draw_string(_font(), at + Vector2(-4, 4), str(sq.size), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TAG_INK)


func _draw_intents(c: CanvasItem, game) -> void:
	for intent in game.telegraphed:
		if bool(intent.get("hidden", false)):
			continue
		var sid := str(intent.get("station", ""))
		if not game.stations.has(sid) or _secret(game.stations[sid]):
			continue
		var r := float(_layout[sid].r) if _layout.has(sid) else 12.0
		var at := _pin_at(game, sid) + Vector2(-r * 0.9, -r * 0.9)
		var kind := str(intent.get("kind", "hold"))
		var icon := ArtPack.icon_texture(kind if kind != "buy" else "propaganda", 20.0)
		if kind == "demand_posted":
			icon = ArtPack.icon_texture("ultimatum", 20.0)
		c.draw_circle(at + Vector2(1, 2), 11.0, Color(0, 0, 0, 0.35))
		c.draw_circle(at, 11.0, Color("241c14"))
		if icon != null:
			c.draw_texture_rect(icon, Rect2(at - Vector2(10, 10), Vector2(20, 20)), false)
		else:
			c.draw_circle(at, 6.0, Color("f0b429"))


func _faction_color(game, fid: String) -> Color:
	if game != null and game.catalog.factions.has(fid) and game.catalog.factions[fid].has("color"):
		return Color(str(game.catalog.factions[fid].color))
	match fid:
		"neutral":
			return Color("8c8170")
		"enemy":
			return Color("8a3a3a")
		"bunker", "ruin":
			return Color("6f8494")
		_:
			return Color("8c8170")


func _font() -> Font:
	if host != null and host.get("body_font") != null:
		return host.body_font
	return ThemeDB.fallback_font


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		var pinch := event as InputEventMagnifyGesture
		_zoom_at(pinch.position, pinch.factor)
		accept_event()
		return
	if event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		origin += pan.delta * 12.0 / zoom
		_clamp_view()
		_redraw()
		accept_event()
		return
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
				var game = _game()
				if aimed != "" and game != null and game.stations.has(aimed):
					_glide_to(_station_world(game.stations[aimed]))
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
			_redraw()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit != "" else Control.CURSOR_ARROW
		tooltip_text = _tip(hit)
		if _drag:
			origin -= motion.relative / zoom
			_clamp_view()
			_redraw()
			accept_event()


func _glide_to(world: Vector2) -> void:
	if _glide != null and _glide.is_valid():
		_glide.kill()
	if _motion_off():
		origin = world
		_clamp_view()
		_redraw()
		return
	_glide = create_tween()
	_glide.tween_method(_glide_step.bind(origin, world), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _glide_step(t: float, from: Vector2, to: Vector2) -> void:
	origin = from.lerp(to, t)
	_clamp_view()
	_redraw()


func _zoom_at(screen_at: Vector2, factor: float) -> void:
	var before := _world(screen_at)
	zoom = clampf(zoom * factor, _zoom_min, _zoom_max)
	var after := _world(screen_at)
	origin += before - after
	_clamp_view()
	_redraw()


func _station_at(screen_at: Vector2) -> String:
	var best := ""
	var best_d := INF
	for sid in _layout:
		var row: Dictionary = _layout[sid]
		var dist := (row.at as Vector2).distance_to(screen_at)
		if dist <= float(row.r) + 4.0 and dist < best_d:
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
	for fid in game.squads:
		var sq: Dictionary = game.squads[fid]
		if not game.stations.has(str(sq.station)):
			continue
		var now := _station_world(game.stations[str(sq.station)])
		if _hop.has(str(fid)):
			var prev: Vector2 = _hop[str(fid)]
			if prev.distance_to(now) > 0.5 and not _motion_off():
				_hop_left = 0.6
		if _hop_left <= 0.0:
			_hop[str(fid)] = now


func _build_sheet() -> void:
	sheet = PanelContainer.new()
	sheet.visible = false
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = Color("8a7456")
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(6, 9)
	style.set_content_margin_all(16)
	style.content_margin_top = 34
	sheet.add_theme_stylebox_override("panel", style)
	sheet.rotation_degrees = 1.2
	sheet.resized.connect(func(): sheet.pivot_offset = sheet.size * 0.5)
	sheet.draw.connect(_dress_card.bind(sheet))
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
	council.mouse_filter = Control.MOUSE_FILTER_IGNORE
	council.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_council_body = VBoxContainer.new()
	_council_body.add_theme_constant_override("separation", 14)
	_council_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	council.add_child(_council_body)
	add_child(council)


func _dress_card(card: Control) -> void:
	if _paper != null:
		card.draw_texture_rect(_paper, Rect2(Vector2.ZERO, card.size), true, Color(1, 1, 1, 0.3))
	card.draw_line(Vector2(10, 26), Vector2(card.size.x - 10, 26), Color(0.7, 0.2, 0.18, 0.45), 1.0)
	var y := 48.0
	while y < card.size.y - 8.0:
		card.draw_line(Vector2(10, y), Vector2(card.size.x - 10, y), Color(0.3, 0.42, 0.6, 0.1), 1.0)
		y += 22.0
	_paper_clip(card, Vector2(34, -16), 48.0)


func _dress_photo(photo: Control) -> void:
	_paper_clip(photo, Vector2(photo.size.x * 0.5, -14), 40.0)


func _paper_clip(c: CanvasItem, at: Vector2, length: float) -> void:
	var r1 := length * 0.17
	var r2 := r1 * 0.7
	var r3 := r2 * 0.75
	var inner := -r1 + 2.0 * r2
	var path := PackedVector2Array([Vector2(r1, length * 0.72)])
	path.append_array(_arc_pts(Vector2(0, r1), r1, 0.0, -PI))
	path.append(Vector2(-r1, length - r2))
	path.append_array(_arc_pts(Vector2(-r1 + r2, length - r2), r2, PI, 0.0))
	path.append(Vector2(inner, r1 + r3))
	path.append_array(_arc_pts(Vector2(inner - r3, r1 + r3), r3, 0.0, -PI))
	path.append(Vector2(inner - 2.0 * r3, length * 0.62))
	var shade := PackedVector2Array()
	var steel := PackedVector2Array()
	for p in path:
		shade.append(at + p + Vector2(1.5, 2.0))
		steel.append(at + p)
	c.draw_polyline(shade, Color(0, 0, 0, 0.35), 2.6, true)
	c.draw_polyline(steel, Color(0.74, 0.75, 0.77), 2.2, true)
	c.draw_polyline(steel, Color(1, 1, 1, 0.35), 0.8, true)


func _arc_pts(center: Vector2, radius: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 11:
		var ang := lerpf(a0, a1, float(i) / 10.0)
		pts.append(center + Vector2(cos(ang), sin(ang)) * radius)
	return pts


func _place_panels() -> void:
	var top := 100.0
	if host != null and host.get("hud") != null and host.hud.size.y > 8.0:
		top = host.hud.size.y + 22.0
	if sheet != null:
		var w := clampf(size.x * 0.24, 330.0, 420.0)
		sheet.offset_left = size.x - w - 30.0
		sheet.offset_top = top + 4.0
		sheet.offset_right = size.x - 30.0
		sheet.offset_bottom = size.y - 120.0
	if council != null:
		council.offset_left = 24.0
		council.offset_top = top
		council.offset_right = 24.0 + 280.0
		council.offset_bottom = top + 10.0


func _fill_council() -> void:
	if _council_body == null:
		return
	for child in _council_body.get_children():
		child.queue_free()
	var game = _game()
	if game == null:
		return
	var title := _lab(Copy.t("Council"), 18, true)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 2)
	_council_body.add_child(title)
	_on_paper = true
	var tilts := [-2.2, 1.6, -1.1]
	var index := 0
	for seat in game.council:
		var role := str(seat.role)
		var person = game.people.get(str(seat.id), {})
		var used := str(game.seat_used.get(role, ""))
		var photo := PanelContainer.new()
		photo.mouse_filter = Control.MOUSE_FILTER_STOP
		var face := StyleBoxFlat.new()
		face.bg_color = Color("efe8d6")
		face.border_color = Color("c9bea4")
		face.set_border_width_all(1)
		face.set_content_margin_all(8)
		face.content_margin_top = 16
		face.shadow_color = Color(0, 0, 0, 0.5)
		face.shadow_size = 10
		face.shadow_offset = Vector2(4, 6)
		photo.add_theme_stylebox_override("panel", face)
		photo.rotation_degrees = float(tilts[index % tilts.size()])
		photo.resized.connect(func(): photo.pivot_offset = photo.size * 0.5)
		photo.draw.connect(_dress_photo.bind(photo))
		index += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		if host != null and host.has_method("_portrait_box"):
			row.add_child(host._portrait_box(str(seat.id), 64))
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
		photo.add_child(row)
		_council_body.add_child(photo)
	_on_paper = false


func _fill_sheet(sid: String) -> void:
	_on_paper = true
	_fill_sheet_body(sid)
	_on_paper = false


func _fill_sheet_body(sid: String) -> void:
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
	if game != null:
		button.tooltip_text = _order_tip(game, kind, sid, why)
	button.set_meta("order_kind", kind)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if why == "":
		button.pressed.connect(_issue.bind(kind, sid))
	button.custom_minimum_size = Vector2(0, 52)
	parent.add_child(button)


func _order_tip(game, kind: String, sid: String, why: String) -> String:
	var cost: Dictionary = game.order_cost(kind, sid)
	if why != "":
		if why == Copy.t("Not enough influence."):
			var need := int(cost.get("influence", 4))
			return Copy.t("Not enough influence: need %d, have %d.") % [need, int(game.stock.get("influence", 0))]
		return why
	var who: Dictionary = game.order_councillor()
	var lines: PackedStringArray = []
	lines.append("%s: %s" % [Copy.t("Cost"), _cost_text(cost)])
	lines.append("%s: %s" % [Copy.t("Goes"), str(who.get("name", ""))])
	lines.append("%s: %s" % [Copy.t("Result"), Copy.t("Next dawn")])
	var risk: String = game.order_risk(kind, sid)
	if risk != "":
		lines.append("%s: %s" % [Copy.t("Risk"), risk])
	return "\n".join(lines)


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
	if _on_paper:
		label.add_theme_color_override("font_color", CARD_INK if display else CARD_MUTED)
	else:
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
	_redraw()


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
