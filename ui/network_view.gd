class_name NetworkView
extends Control

## The overseer's desk: the painted city map pinned under the lamp. The week still lives on Game.

const UnitSprites = preload("res://ui/map_unit_sprites.gd")
var _sprites := UnitSprites.new()
var _unit_routes := {}
var _squad_positions := {}
var _squad_bay_cache := {}
var _puffs := {}
var _puff_times := {}

const ArtPack = preload("res://ui/art_pack.gd")
const PINS_JSON := "res://data/map_pins.json"
const MAP_FILE := "res://assets/map/nyc_map.webp"
const PAPER := Color("241c14")
const INK := Color("f4efe4")
const MUTED := Color("d9cbb4")
const CARD := Color("ece1c6")
const CARD_INK := Color("2b2118")
const CARD_MUTED := Color("554533")
const TAG_PAPER := Color("efe4c8")
const TAG_INK := Color("2b2118")
## Faction sign on a station tag: 16 px at tag levels 0 and 1, where pins sit close together; 20 px at level 2.
## Station names are never smaller than this on screen, in window pixels.
const TAG_MIN_PX := 14.0
const TAG_BADGE_SMALL := 16.0
const TAG_BADGE_LARGE := 20.0
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
const LINE_GAP := LINE_WIDTH + 1.0
const FIT_PAD := 14.0
## Screen px kept free around the outermost stations at the opening zoom, for their pins.
const FIT_PIN := 24.0
const ZOOM_STEP := 1.25
## At the deepest zoom a station and its neighbours span about this share of the window's short side.
const NEAR_SHARE := 1.0 / 3.0
## Territories: how far a station's land reaches on the map (map px), how strong the wash is, the dashed border's
## width and dash in window px, and the edge tags that never get a border line.
const TERRITORY_REACH := 165.0
const TERRITORY_FILL := 0.32
const TERRITORY_LINE := 1.2
const TERRITORY_DASH := 7.0
## Territory raster: one grid cell is TERR_STEP map px; a station's influence fades out over TERR_REACH map px,
## a faction holds the land where its summed influence passes TERR_EDGE; fill strength, hatch period (cells) and
## the border's strength.
const TERR_STEP := 3
const TERR_REACH := 250.0
const TERR_EDGE := 0.24
const TERR_FILL := 0.62
const TERR_HATCH := 3
const TERR_LINE := 0.9
## Half-width of the band that joins two stations of one holder along their tunnel, as a share of the reach.
const TERR_BRIDGE := 0.38
const SCHEMATIC_FILE := "res://data/map_schematic.json"
const TAG_REACH := -1
const TAG_PAPER_EDGE := -2
const PIN_CAPITAL := 52.0
const PIN_OTHER := 38.0
const PIN_FLOOR := 24.0
const ZOOM_SPAN := 3.5
const PIN_SPRITE := {"depot": "depot", "directorate": "dir", "exchange": "exch", "synod": "synod"}
## Symbols too pale to read on the cream paper in their own colours; on paper they are printed as an ink stamp.
const STAMP_ON_PAPER := ["black_flag"]
const FLAG_ANCHOR := Vector2(0.176, 0.35)
const FLAG_CLOTH := Vector2(0.62, 0.42)
const PANORAMA_HUBS := ["northgate", "chapel", "trampark", "brickworks"]
## Room picture for each station without its own hub art, chosen from what the station's community and art
## lines describe. A station missing here has no fitting picture and shows a dark plate with its name.
## Stations that still borrow a room picture. The rest use assets/hubs/<id>.webp, a placeholder
## until a finished painting replaces it. Capitals keep the hubs already accepted.
const BANNER_ROOMS := {
	"southdepot": "platform",
	"stadium": "meeting_hall",
}
const PLATE := Color("1e1812")
const HUB_MAX_H := 400.0
## The visit sheet never grows wider than this; the map shows dimmed on both sides of it.
const VISIT_MAX_W := 900.0
## Where the crop window centres on the panorama, as a share of its height from the top.
const HUB_FOCUS_Y := 0.55
## Plain wood in the desk picture (no props), in desk px, and how dark it is drawn beyond the desk.
const WOOD := Rect2(560, 130, 480, 680)
const WOOD_TINT := Color(0.62, 0.57, 0.52)
## How far the dark edge of the table reaches in from the window border, as a share of the short side.
const VIGNETTE := 0.22
## The council photos stay a narrow column docked at the left edge, off the map's middle.
const COUNCIL_W := 220.0


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
## Squad moves seen since the last look: the station each squad stood on, and the walks under way
## ({route, t, dur}), so a squad that moved three tunnels this week walks all three on the map.
var _squad_seen := {}
var _walks := {}
const WALK_PER_HOP := 0.7
const WALK_MAX := 2.8
var _zoom_min := 1.0
var _zoom_max := 3.5
var _near_span := 0.0
var _zoom_bar: HBoxContainer
var _zoom_buttons := {}
var _cam_origin := Vector2.ZERO
var _cam_zoom := 1.0
var visit: PanelContainer
var visit_sheet: PanelContainer
var visit_close: Button
var _visit_title: Label
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
var territories := true
var _terr_key := "-"
var _terr_owners: PackedStringArray = []
var _terr_cells: Array = []
var _terr_tex: ImageTexture
var _terr_tex_key := "-"
var _land := PackedByteArray()
var _land_w := 0
var _land_h := 0
## The network view has two layouts: the schematic (default) and the real map. Each keeps its own station spots,
## paper size and desk transform; set_schematic swaps them.
var schematic := true
## The council cards are folded away until the player opens them, so they never cover a station.
var council_open := false
var _geo_spots := {}
var _geo_size := Vector2(1024, 1536)
var _geo_xf := Transform2D.IDENTITY
var _sch_spots := {}
var _sch_size := Vector2(1600, 1000)
var _sch_xf := Transform2D.IDENTITY
var _sch_boroughs: Array = []
var _dot: Texture2D
var _back_layer: Control
var _base_layer: Control
var _wash_layer: Control
var _ink_layer: Control
var _layout := {}
var _lift := {}
var _on_paper := false
var _tag_font: Font
var _italic: Font
var _glide: Tween
## Faction id -> symbol texture, or null when the file is missing (the tag keeps its colour strip).
var _symbols := {}
## Station id -> the tag box drawn last frame, in screen px.
var _tags := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	clip_contents = true
	_load_desk()
	_back_layer = _add_layer(_draw_backdrop)
	_base_layer = _add_layer(_draw_base)
	_wash_layer = _add_layer(_draw_wash)
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_wash_layer.material = mul
	_ink_layer = _add_layer(_draw_ink)
	_unit_layer = _add_layer(_draw_units)
	_sprites.setup(_unit_layer)
	_paper = _map_tex("res://assets/map/paper.webp")
	_build_zoom_bar()
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
	_desk = _map_tex("res://" + str(desk.get("file", "assets/map/desk_empty.webp")))
	_map = _map_tex(MAP_FILE)
	var turn := deg_to_rad(float(desk.get("map_rotation_deg", 0.0)))
	var k := float(desk.get("map_scale", 1.0))
	var center := _vec(desk.get("map_center", []), _desk_size * 0.5)
	_map_xf = Transform2D(turn, Vector2(k, k), 0.0, center) * Transform2D(0.0, -_map_size * 0.5)
	for spot in desk.get("weights", []):
		_weights.append(_vec(spot, Vector2.ZERO))
	_weight_radius = float(desk.get("weight_radius", 34.0))
	_geo_spots = _spots
	_geo_size = _map_size
	_geo_xf = _map_xf
	var sch := {}
	var sf := FileAccess.open(SCHEMATIC_FILE, FileAccess.READ)
	if sf != null:
		var sparsed = JSON.parse_string(sf.get_as_text())
		if sparsed is Dictionary:
			sch = sparsed
	if sch.has("stations"):
		_sch_spots = sch.get("stations", {})
		_sch_size = _vec(sch.get("size", []), _sch_size)
		_sch_boroughs = sch.get("boroughs", [])
		_sch_xf = Transform2D(0.0, Vector2.ONE, 0.0, _desk_size * 0.5) * Transform2D(0.0, -_sch_size * 0.5)
	else:
		schematic = false
	_apply_mode()
	var sheet_cfg: Dictionary = cfg.get("pins_sheet", {})
	_pins = _map_tex("res://" + str(sheet_cfg.get("file", "assets/map/pins.webp")))
	_head_anchor = _vec(sheet_cfg.get("head_anchor", []), _head_anchor)
	var rects: Dictionary = sheet_cfg.get("rects", {})
	for key in rects:
		var r = rects[key]
		if r is Array and r.size() >= 4:
			var top_left := Vector2(float(r[0]), float(r[1]))
			_pin_rects[str(key)] = Rect2(top_left, Vector2(float(r[2]), float(r[3])) - top_left)


func _apply_mode() -> void:
	if schematic and not _sch_spots.is_empty():
		_spots = _sch_spots
		_map_size = _sch_size
		_map_xf = _sch_xf
	else:
		_spots = _geo_spots
		_map_size = _geo_size
		_map_xf = _geo_xf
	_fitted = false
	_near_span = 0.0
	_terr_key = "-"
	_terr_tex = null
	_terr_tex_key = "-"
	_land_w = 0
	_land_h = 0
	_layout.clear()


func set_schematic(on: bool) -> void:
	if on == schematic or _sch_spots.is_empty():
		return
	schematic = on
	_apply_mode()
	_name_zoom_bar()
	if size.x > 10.0:
		_fit()
	_redraw()


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
	var game_seen = _game()
	if game_seen != null:
		_track_owners(game_seen)
	_ready_fonts()
	_name_zoom_bar()
	_place_panels()
	if _fitted:
		_rezoom()
	_fill_council()
	if selected != "":
		_fill_sheet(selected)
	_redraw()


func _redraw() -> void:
	queue_redraw()
	for layer in [_back_layer, _base_layer, _wash_layer, _ink_layer, _unit_layer]:
		if layer != null:
			layer.queue_redraw()


func open_sheet(sid: String) -> void:
	_details_open = false
	selected = sid
	## The map tip points at one station; once its card is open the pointer has done its job.
	if host != null and bool(host.get("net_guide")) and str(host.get("net_guide_sid")) == sid:
		host._skip_guide()
	var was_open := sheet.visible
	sheet.visible = true
	_fill_sheet(sid)
	_clear_of_sheet(sid)
	_redraw()
	if not was_open and not _motion_off():
		_slide_in(sheet)


## A panel slides in from the right and fades up, then sits where its layout put it.
var _sheet_tween: Tween

func _slide_in(panel: Control) -> void:
	if _sheet_tween != null and _sheet_tween.is_valid():
		_sheet_tween.kill()
	var home := panel.position
	panel.position = home + Vector2(36.0, 0.0)
	panel.modulate.a = 0.0
	_sheet_tween = create_tween().set_parallel(true)
	_sheet_tween.tween_property(panel, "position", home, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sheet_tween.tween_property(panel, "modulate:a", 1.0, 0.16)


## Slides the map so the chosen station is not under its own sheet, as far as the map's bounds allow.
func _clear_of_sheet(sid: String) -> void:
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	var at := _screen(_station_world(game.stations[sid]))
	var edge := sheet.offset_left - 48.0
	if at.x <= edge:
		return
	var goal := (FIT_PAD + edge) * 0.5
	_glide_to(origin + Vector2((at.x - goal) / zoom, 0.0))


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
	if host != null and bool(host.get("shot_mode")) and not bool(host.get("motion_in_shots")):
		return true
	return Settings.reduced()


## Map motion: a wheel step eases toward its zoom instead of jumping; a station that comes over to the player
## sends a wave of their colour out over the map; rival moves breathe so the eye finds them.
const SPLASH_S := 1.4
var _zoom_goal := 0.0
var _zoom_anchor := Vector2.ZERO
var _splashes: Array = []
var _owners_seen := {}
var _anim_t := 0.0
## P22 join pulse: one 0.5 s ring on a pin the week it joins, played once per join.
var _pulses: Array = []
var _pulsed := {}


## Notes every station that turned the player's since the last look and starts its wave; the first look only
## remembers, so opening the map does not splash what was already held.
func _track_owners(game) -> void:
	for sid in game.stations:
		var joined := int(game.stations[sid].get("join_pulse", -1))
		var key := "%s:%d" % [sid, joined]
		if joined == int(game.week) and not _pulsed.has(key):
			_pulsed[key] = true
			if not _motion_off():
				_pulses.append({"sid": str(sid), "age": 0.0})
	var first := _owners_seen.is_empty()
	for sid in game.stations:
		var owner := str(game.stations[sid].owner)
		if not first and owner == str(game.player) and str(_owners_seen.get(sid, "")) != owner and not _motion_off():
			_splashes.append({"sid": str(sid), "age": 0.0})
		_owners_seen[sid] = owner


func _draw_splashes(c: CanvasItem, game) -> void:
	for row in _splashes:
		var sid := str(row.sid)
		if not game.stations.has(sid):
			continue
		var k := clampf(float(row.age) / SPLASH_S, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - k, 3.0)
		var at := _pin_at(game, sid)
		var col := territory_color(game, str(game.player))
		var r := lerpf(10.0, 170.0, ease)
		c.draw_circle(at, r, Color(col, 0.22 * (1.0 - k)))
		c.draw_arc(at, r, 0.0, TAU, 64, Color(col.darkened(0.3), 0.85 * (1.0 - k)), 3.0, true)
	for row in _pulses:
		var sid := str(row.sid)
		if not _layout.has(sid):
			continue
		var k := clampf(float(row.age) / PULSE_S, 0.0, 1.0)
		var pin_r := float(_layout[sid].r)
		c.draw_arc(_layout[sid].at, lerpf(pin_r + 4.0, pin_r + 18.0, k), 0.0, TAU, 40, Color(_faction_color(game, str(game.player)), 0.9 * (1.0 - k)), 2.5, true)


func _process(delta: float) -> void:
	if not visible:
		return
	var busy := false
	var ink_busy := false
	_anim_t += delta
	if _zoom_goal > 0.0:
		var step := pow(_zoom_goal / zoom, minf(1.0, delta * 14.0))
		if absf(_zoom_goal - zoom) / zoom < 0.002:
			step = _zoom_goal / zoom
			_zoom_goal = 0.0
		_zoom_at(_zoom_anchor, step)
	if not _splashes.is_empty():
		for row in _splashes:
			row.age = float(row.age) + delta
		_splashes = _splashes.filter(func(row): return float(row.age) < SPLASH_S)
		busy = true
	if not _pulses.is_empty():
		for row in _pulses:
			row.age = float(row.age) + delta
		_pulses = _pulses.filter(func(row): return float(row.age) < PULSE_S)
		busy = true
	var game_now = _game()
	if game_now != null and not game_now.telegraphed.is_empty() and not _motion_off():
		busy = true
	if not _walks.is_empty():
		for fid in _walks.keys():
			_walks[fid].t = float(_walks[fid].t) + delta
			if float(_walks[fid].t) >= float(_walks[fid].dur):
				_walks.erase(fid)
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
		ink_busy = true
	if ink_busy and _ink_layer != null:
		_ink_layer.queue_redraw()
	var walking: bool = not _unit_routes.is_empty() or not _walks.is_empty() or not _caravans.is_empty() or (game_now != null and (not game_now.expedition.is_empty() or not game_now.squads.is_empty()))
	if _unit_layer != null and (busy or (walking and not _motion_off())):
		_unit_layer.queue_redraw()


func _on_resize() -> void:
	_place_panels()
	if not _fitted or zoom <= _zoom_min * 1.001:
		_fit()
		return
	_rezoom()
	_redraw()


func _rezoom() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	var at_min := zoom <= _zoom_min * 1.001
	_zoom_range()
	zoom = _zoom_min if at_min else clampf(zoom, _zoom_min, _zoom_max)
	_clamp_view()


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


func _hud_top() -> float:
	if host != null and host.get("hud") != null and host.hud.size.y > 8.0:
		return host.hud.size.y
	return 78.0


func _open_area() -> Rect2:
	var top := _hud_top() + FIT_PAD
	var left := FIT_PAD
	var bottom := size.y - FIT_PAD
	if schematic:
		## The schematic sits clear of the council cards at the left and of the station's bottom buttons.
		left = FIT_PAD + (COUNCIL_W + 12.0 if council_open else 190.0)
		bottom = _chrome_top() - 4.0
	## Room at the right for the longest tag of the easternmost station and the people tab.
	var right := 150.0 if schematic else FIT_PAD
	return Rect2(left, top, maxf(size.x - left - right, 1.0), maxf(bottom - top, 1.0))


## Every station spot on the desk, hidden ones too, so the opening view does not change as stations turn up.
func _net_box() -> Rect2:
	var box := Rect2()
	var first := true
	for sid in _spots:
		var at := _map_xf * _map_spot(str(sid))
		box = Rect2(at, Vector2.ZERO) if first else box.expand(at)
		first = false
	return _map_box() if first else box


## The lower quartile of "a station and its tunnel neighbours" spans, in desk px: the dense middle of the map.
func _neighbour_span() -> float:
	if _near_span > 0.0:
		return _near_span
	var game = _game()
	if game == null:
		return 0.0
	var spans: Array = []
	for sid in game.stations:
		var box := Rect2(_station_world(game.stations[sid]), Vector2.ZERO)
		for tunnel in game.tunnels:
			var other := ""
			if str(tunnel.a) == str(sid):
				other = str(tunnel.b)
			elif str(tunnel.b) == str(sid):
				other = str(tunnel.a)
			if other != "" and game.stations.has(other):
				box = box.expand(_station_world(game.stations[other]))
		var span := maxf(box.size.x, box.size.y)
		if span > 1.0:
			spans.append(span)
	if spans.is_empty():
		return 0.0
	spans.sort()
	_near_span = float(spans[spans.size() / 4])
	return _near_span


func _zoom_range() -> void:
	var box := _net_box()
	var area := _open_area()
	var room := area.size - Vector2(FIT_PIN, FIT_PIN) * 2.0
	_zoom_min = minf(room.x / maxf(box.size.x, 1.0), room.y / maxf(box.size.y, 1.0))
	_zoom_max = _zoom_min * ZOOM_SPAN
	var span := _neighbour_span()
	if span > 0.0:
		_zoom_max = maxf(_zoom_max, minf(size.x, size.y) * NEAR_SHARE / span)


func _clamp_view() -> void:
	var box := _map_box()
	var area := _open_area()
	var z := maxf(zoom, 0.001)
	var mid := _center()
	for axis in 2:
		## A map larger than the view keeps covering it; a smaller one sits in the middle of the free area.
		var lo: float = box.position[axis] + (mid[axis] - area.position[axis]) / z
		var hi: float = box.end[axis] - (area.end[axis] - mid[axis]) / z
		if lo > hi:
			origin[axis] = box.get_center()[axis] - (area.get_center()[axis] - mid[axis]) / z
		else:
			origin[axis] = clampf(origin[axis], lo, hi)


func _fit() -> void:
	if size.x < 10.0 or size.y < 10.0:
		return
	_zoom_range()
	zoom = _zoom_min
	origin = _net_box().get_center() - (_open_area().get_center() - _center()) / zoom
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
	var view := _view()
	c.draw_set_transform_matrix(view * _map_xf)
	_soft_rect(c, Rect2(Vector2(16, 26), _map_size - Vector2(8, 8)), 46.0, Color(0, 0, 0, 0.55))
	if schematic:
		_draw_board(c)
	elif _map != null:
		c.draw_texture_rect(_map, Rect2(Vector2.ZERO, _map_size), false, Color(1.0, 0.96, 0.9))
	else:
		c.draw_rect(Rect2(Vector2.ZERO, _map_size), Color("d8c8a4"))
	c.draw_set_transform_matrix(view)
	_draw_weights(c)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## The schematic board: warm paper with a faint ruled grid, a thin border rule and the borough names in large
## faded ink, the lines and stations drawn over it. Drawn in schematic px (the transform is set by the caller).
func _draw_board(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, _map_size), Color("dccfab"))
	if _map != null:
		c.draw_texture_rect(_map, Rect2(Vector2.ZERO, _map_size), false, Color(1.0, 1.0, 1.0, 0.13))
	var grid := Color(0.35, 0.27, 0.16, 0.10)
	var gx := 0.0
	while gx <= _map_size.x:
		c.draw_line(Vector2(gx, 0.0), Vector2(gx, _map_size.y), grid, 1.0)
		gx += 100.0
	var gy := 0.0
	while gy <= _map_size.y:
		c.draw_line(Vector2(0.0, gy), Vector2(_map_size.x, gy), grid, 1.0)
		gy += 100.0
	c.draw_rect(Rect2(Vector2(14, 14), _map_size - Vector2(28, 28)), Color(0.2, 0.15, 0.09, 0.55), false, 3.0)
	_ready_fonts()
	var font: Font = _tag_font if _tag_font != null else ThemeDB.fallback_font
	for row in _sch_boroughs:
		var label := str(row.get("ru" if Copy.ru() else "en", ""))
		var at := _vec(row.get("at", []), Vector2.ZERO)
		c.draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 54, Color(0.25, 0.18, 0.1, 0.16))


## A bare table: plain wood from the middle of the desk picture (none of its props), tiled mirror-wise under
## the whole window in desk space so no black shows at any size, pan and zoom, darkened toward the window edges.
func _draw_backdrop(c: CanvasItem) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, size), Color("120d09"))
	if _desk == null or size.x < 1.0:
		return
	var view := _view()
	var tile := WOOD.size
	var top_left := _world(Vector2.ZERO)
	var bottom_right := _world(size)
	var i0 := floori(top_left.x / tile.x)
	var j0 := floori(top_left.y / tile.y)
	var i1 := floori(bottom_right.x / tile.x)
	var j1 := floori(bottom_right.y / tile.y)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			var flip := Vector2(-1.0 if absi(i) % 2 == 1 else 1.0, -1.0 if absi(j) % 2 == 1 else 1.0)
			var at := Vector2(i * tile.x, j * tile.y) + tile * (Vector2.ONE - flip) * 0.5
			c.draw_set_transform_matrix(view * Transform2D(0.0, flip, 0.0, at))
			c.draw_texture_rect_region(_desk, Rect2(Vector2.ZERO, tile), WOOD, WOOD_TINT)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_vignette(c)


func _vignette(c: CanvasItem) -> void:
	var reach := VIGNETTE * minf(size.x, size.y)
	var shade := Color(0.02, 0.012, 0.006, 0.75)
	var clear := Color(shade, 0.0)
	var outer := Rect2(Vector2.ZERO, size)
	var inner := outer.grow(-reach)
	var i_pts := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
	var o_pts := [outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)]
	for i in 4:
		var j := (i + 1) % 4
		c.draw_polygon(PackedVector2Array([i_pts[i], i_pts[j], o_pts[j], o_pts[i]]), PackedColorArray([clear, clear, shade, shade]))


func _draw_weights(c: CanvasItem) -> void:
	if _desk == null or schematic:
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


## Territories on the multiply layer: land the factions hold, as a soft wash of their colour with pencil hatching
## and a thin inked border where it ends or meets another faction. Water is never coloured and the coast is not
## outlined. Built as one raster (see _territory_texture), drawn only while the Territories button is on.
func _draw_wash(c: CanvasItem) -> void:
	var game = _game()
	if game == null or not territories:
		return
	var tex := _territory_texture(game)
	if tex == null:
		return
	c.draw_set_transform_matrix(_view() * _map_xf)
	c.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(_land_w, _land_h) * float(TERR_STEP)), false)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## 1 per grid cell where the paper shows land (warm paper, not the blue-grey water), the coast smoothed by a
## 3x3 majority so speckles in the map art do not make holes.
func _build_land() -> void:
	if _land_w > 0:
		return
	_land_w = ceili(_map_size.x / float(TERR_STEP))
	_land_h = ceili(_map_size.y / float(TERR_STEP))
	var raw := PackedByteArray()
	raw.resize(_land_w * _land_h)
	var img: Image = _map.get_image() if _map != null else null
	if img == null or img.is_empty():
		raw.fill(1)
	else:
		if img.is_compressed():
			img.decompress()
		var k := Vector2(float(img.get_width()) / _map_size.x, float(img.get_height()) / _map_size.y)
		for y in _land_h:
			for x in _land_w:
				var px := mini(img.get_width() - 1, int((float(x) + 0.5) * TERR_STEP * k.x))
				var py := mini(img.get_height() - 1, int((float(y) + 0.5) * TERR_STEP * k.y))
				var col := img.get_pixel(px, py)
				raw[y * _land_w + x] = 1 if (col.r - col.b > 0.17 and col.r > 0.5) else 0
	if schematic:
		_land.resize(_land_w * _land_h)
		_land.fill(1)
		return
	_land.resize(_land_w * _land_h)
	for y in _land_h:
		for x in _land_w:
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := clampi(x + dx, 0, _land_w - 1)
					var yy := clampi(y + dy, 0, _land_h - 1)
					n += raw[yy * _land_w + xx]
			_land[y * _land_w + x] = 1 if n >= 5 else 0


## Slow value noise in 0.74..1.26 so the edge of a held area wanders like ground, not like a compass circle.
func _terr_noise(x: int, y: int) -> float:
	var n := 0.5 + 0.25 * sin(float(x) * 0.11 + 1.3) * cos(float(y) * 0.09 + 0.7) + 0.25 * sin(float(x) * 0.23 + float(y) * 0.17 + 2.1)
	return 0.74 + 0.52 * clampf(n, 0.0, 1.0)


func territory_is_land(map_px: Vector2) -> bool:
	_build_land()
	var x := clampi(int(map_px.x / float(TERR_STEP)), 0, _land_w - 1)
	var y := clampi(int(map_px.y / float(TERR_STEP)), 0, _land_h - 1)
	return _land[y * _land_w + x] == 1


## The raster of the held land, rebuilt only when an owner, a discovery or a rival move changes (same key as
## territory_cells). White where nothing is held, so it multiplies away.
func _territory_texture(game) -> ImageTexture:
	territory_cells(game)
	if _terr_tex != null and _terr_tex_key == _terr_key:
		return _terr_tex
	_terr_tex_key = _terr_key
	_build_land()
	var w := _land_w
	var h := _land_h
	var ids: Array = []
	var seeds: Array = []
	var held := {}
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if _secret(st) or not bool(st.get("known", true)) or not _spots.has(str(sid)):
			continue
		var holder := territory_owner(game, str(sid))
		if holder == "":
			continue
		var fi := ids.find(holder)
		if fi < 0:
			ids.append(holder)
			seeds.append([])
			fi = ids.size() - 1
		seeds[fi].append(_map_spot(str(sid)) / float(TERR_STEP))
		held[str(sid)] = fi
	## Two stations of one holder joined by an open tunnel are joined on the map too: a band of their colour runs
	## along the tunnel, so a holding reads as one land and not as islands.
	var bridges: Array = []
	for _fi in ids.size():
		bridges.append([])
	for tunnel in game.tunnels:
		var a := str(tunnel.get("a", ""))
		var b := str(tunnel.get("b", ""))
		if held.has(a) and held.has(b) and int(held[a]) == int(held[b]) and game._edge_open(tunnel):
			bridges[int(held[a])].append([_map_spot(a) / float(TERR_STEP), _map_spot(b) / float(TERR_STEP)])
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	if ids.is_empty():
		_terr_tex = ImageTexture.create_from_image(img)
		return _terr_tex
	var reach := TERR_REACH * (0.6 if schematic else 1.0) / float(TERR_STEP)
	var infl: Array = []
	for fi in ids.size():
		var field := PackedFloat32Array()
		field.resize(w * h)
		for at in seeds[fi]:
			var x0 := maxi(0, floori(at.x - reach))
			var x1 := mini(w - 1, ceili(at.x + reach))
			var y0 := maxi(0, floori(at.y - reach))
			var y1 := mini(h - 1, ceili(at.y + reach))
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(at) / reach
					if d < 1.0:
						var v := 1.0 - d
						v = v * v * (3.0 - 2.0 * v) * _terr_noise(x, y)
						field[y * w + x] += v
		var band := reach * TERR_BRIDGE
		for seg in bridges[fi]:
			var p: Vector2 = seg[0]
			var q: Vector2 = seg[1]
			var x0 := maxi(0, floori(minf(p.x, q.x) - band))
			var x1 := mini(w - 1, ceili(maxf(p.x, q.x) + band))
			var y0 := maxi(0, floori(minf(p.y, q.y) - band))
			var y1 := mini(h - 1, ceili(maxf(p.y, q.y) + band))
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var at := Vector2(float(x) + 0.5, float(y) + 0.5)
					var d := at.distance_to(Geometry2D.get_closest_point_to_segment(at, p, q)) / band
					if d < 1.0:
						var v := 1.0 - d
						v = v * v * (3.0 - 2.0 * v) * _terr_noise(x, y) * 0.8
						field[y * w + x] = maxf(field[y * w + x], v)
		infl.append(field)
	var owner_at := PackedInt32Array()
	owner_at.resize(w * h)
	var strength := PackedFloat32Array()
	strength.resize(w * h)
	for i in w * h:
		owner_at[i] = -1
		if _land[i] == 0:
			continue
		var best := -1
		var top := 0.0
		for fi in ids.size():
			var v: float = infl[fi][i]
			if v > top:
				top = v
				best = fi
		if best >= 0 and top >= TERR_EDGE:
			owner_at[i] = best
			strength[i] = top
	var colors: Array = []
	for fi in ids.size():
		colors.append(territory_color(game, str(ids[fi])))
	for y in h:
		for x in w:
			var i := y * w + x
			var fi := owner_at[i]
			if fi < 0:
				continue
			var col: Color = colors[fi]
			var fade := smoothstep(TERR_EDGE, TERR_EDGE + 0.32, strength[i])
			var amount := TERR_FILL * (0.35 + 0.65 * fade)
			if (x - y) % TERR_HATCH == 0:
				amount *= 1.55
			var out := Color.WHITE.lerp(col, amount)
			var edge := false
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + n.x
				var yy: int = y + n.y
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var j := yy * w + xx
				if owner_at[j] != fi and _land[j] == 1:
					edge = true
					break
			if edge:
				out = Color.WHITE.lerp(col.darkened(0.45), TERR_LINE)
			img.set_pixel(x, y, out)
	_terr_tex = ImageTexture.create_from_image(img)
	return _terr_tex


## The colour a faction's land is washed in: the leader data first, then the faction table.
func territory_color(game, fid: String) -> Color:
	var row: Dictionary = game.leader(fid) if game != null and game.has_method("leader") else {}
	if row.has("color"):
		return Color(str(row.color))
	return _faction_color(game, fid)


## "" when a station's ground stays open: unknown, neutral, ruined or enemy, or contested (a rival's move on it
## shows on the map). The player's own stations stay coloured while a rival moves on them.
func territory_owner(game, sid: String) -> String:
	var st: Dictionary = game.stations[sid]
	if _secret(st) or not bool(st.get("known", true)):
		return ""
	var owner := str(st.owner)
	if owner in ["neutral", "enemy", "ruin", "bunker", ""]:
		return ""
	if not game.catalog.factions.has(owner) and game.leader(owner).is_empty():
		return ""
	if owner == str(game.player):
		return owner
	for intent in game.telegraphed:
		if str(intent.get("station", "")) == sid and not bool(intent.get("hidden", false)):
			return ""
	return owner


func cells_owner(seed: int) -> String:
	return str(_terr_owners[seed]) if seed >= 0 and seed < _terr_owners.size() else ""


## Voronoi cells around the known stations, each cut to TERRITORY_REACH and to the paper, in map px; only the
## held ones are returned. Rebuilt when an owner, a discovery or a rival move changes.
func territory_cells(game) -> Array:
	var seeds: Array = []
	var owners: PackedStringArray = []
	var key := ""
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if _secret(st) or not bool(st.get("known", true)) or not _spots.has(str(sid)):
			continue
		var holder := territory_owner(game, str(sid))
		seeds.append(_map_spot(str(sid)))
		owners.append(holder)
		key += "%s:%s;" % [sid, holder]
	if key == _terr_key:
		return _terr_cells
	_terr_key = key
	_terr_owners = owners
	_terr_cells = []
	var paper := Rect2(Vector2.ZERO, _map_size)
	for i in seeds.size():
		if owners[i] == "":
			continue
		var at: Vector2 = seeds[i]
		var pts := PackedVector2Array()
		var tags := PackedInt32Array()
		for k in 40:
			var ang := TAU * float(k) / 40.0
			pts.append(at + Vector2(cos(ang), sin(ang)) * TERRITORY_REACH)
			tags.append(TAG_REACH)
		for edge in [[Vector2(-1, 0), -paper.position.x], [Vector2(1, 0), paper.end.x], [Vector2(0, -1), -paper.position.y], [Vector2(0, 1), paper.end.y]]:
			var cut := _clip_half(pts, tags, edge[0], float(edge[1]), TAG_PAPER_EDGE)
			pts = cut[0]
			tags = cut[1]
		for j in seeds.size():
			var other: Vector2 = seeds[j]
			if j == i or at.distance_to(other) > TERRITORY_REACH * 2.0 or pts.size() < 3:
				continue
			var cut := _clip_half(pts, tags, (other - at) * 2.0, other.length_squared() - at.length_squared(), j)
			pts = cut[0]
			tags = cut[1]
		if pts.size() >= 3:
			_terr_cells.append({"owner": owners[i], "color": territory_color(game, owners[i]), "pts": pts, "tags": tags})
	return _terr_cells


## Sutherland-Hodgman against n.x <= d; tags[k] names what cut the edge from pts[k] to pts[k + 1].
func _clip_half(pts: PackedVector2Array, tags: PackedInt32Array, n: Vector2, d: float, tag: int) -> Array:
	var out := PackedVector2Array()
	var out_tags := PackedInt32Array()
	var count := pts.size()
	for k in count:
		var a := pts[k]
		var b := pts[(k + 1) % count]
		var da := n.dot(a) - d
		var db := n.dot(b) - d
		if da <= 0.0:
			out.append(a)
			out_tags.append(tags[k])
			if db > 0.0:
				out.append(a.lerp(b, da / (da - db)))
				out_tags.append(tag)
		elif db <= 0.0:
			out.append(a.lerp(b, da / (da - db)))
			out_tags.append(tags[k])
	return [out, out_tags]


func _draw_ink(c: CanvasItem) -> void:
	_squad_bay_cache.clear()
	var game = _game()
	if game == null:
		return
	_ready_fonts()
	var view := _view()
	c.draw_set_transform_matrix(view * _map_xf)
	_draw_lines(c, game)
	_draw_tunnels(c, game)
	_draw_passage_edges(c, game)
	_draw_order_trails(c, game)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
	_layout_pins(game)
	_caravans = _caravan_routes(game)
	_draw_leaders(c)
	_draw_junctions(c, game)
	_draw_pins(c, game)
	_draw_deal_pips(c, game)
	_draw_line_badges(c, game)
	_plan_yields(game)
	_draw_tags(c, game)
	_draw_yields(c, game)
	_draw_governors(c, game)
	_draw_flags(c, game)
	_draw_unit_routes(c, game)
	_draw_legend(c, game)


## Faction whose symbol a station carries: its owner when that is a leader faction, otherwise the leader
## faction whose name is the station's community (the Lamplighters' camp at Atlantic Av). "" for bunkers,
## ruins, enemies and neutrals.
func station_faction(game, sid: String) -> String:
	if game == null or not game.stations.has(sid):
		return ""
	var named: Dictionary = game.catalog.lines.get("factions", {})
	var owner := str(game.stations[sid].owner)
	if named.has(owner):
		return owner
	var community := str(game.catalog.communities_en.get("stations", {}).get(sid, {}).get("community", ""))
	if community == "":
		return ""
	for fid in named:
		if str(named[fid].get("name", {}).get("en", "")) == community:
			return str(fid)
	return ""


func _symbol(game, fid: String) -> Texture2D:
	if fid == "" or game == null:
		return null
	if not _symbols.has(fid):
		var path := str(game.leader(fid).get("symbol", ""))
		_symbols[fid] = ArtPack.load_texture(path) if path != "" and ResourceLoader.exists(path) else null
	return _symbols[fid]


func _paper_tint(fid: String) -> Color:
	return Color(TAG_INK, 0.85) if fid in STAMP_ON_PAPER else Color.WHITE


func _symbol_rect(mark: Texture2D, px: int, tint := Color.WHITE) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = mark
	pic.self_modulate = tint
	pic.custom_minimum_size = Vector2(px, px)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


## The five symbols with their names on a paper slip in the lower left of the desk; left out on any frame
## where the slip would cover a pin or a tag.
func _draw_legend(c: CanvasItem, game) -> void:
	var rows: Array = []
	for row in game.catalog.leaders.get("factions", []):
		var fid := str(row.get("id", ""))
		var mark := _symbol(game, fid)
		if mark == null:
			continue
		var name: Dictionary = game.leader_name(fid, "name")
		rows.append([mark, str(name.get("ru" if Copy.ru() else "en", fid)), _paper_tint(fid), territory_color(game, fid)])
	if rows.is_empty():
		return
	var fs := 13
	var icon := 20.0
	var step := 25.0
	var swatch := 14.0 if territories else 0.0
	var widest := 0.0
	for row in rows:
		widest = maxf(widest, _tag_font.get_string_size(str(row[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	widest += swatch + (6.0 if territories else 0.0)
	var area := _open_area()
	var bottom := minf(area.end.y, _chrome_top())
	if _zoom_bar != null and _zoom_bar.visible:
		bottom = _zoom_bar.position.y - 8.0
	var slip := Vector2(widest + icon + 26.0, step * rows.size() + 12.0)
	var box := Rect2(Vector2((FIT_PAD + 4.0) if schematic else (area.position.x + 4.0), bottom - slip.y), slip)
	if council != null and council.visible and box.intersects(council.get_rect().grow(6.0)):
		return
	for sid in _layout:
		var info: Dictionary = _layout[sid]
		var r := float(info.r)
		if box.grow(4.0).intersects(Rect2(info.at - Vector2(r, r), Vector2(r, r) * 2.0)):
			return
	for sid in _tags:
		if box.grow(4.0).intersects(_tags[sid]):
			return
	c.draw_set_transform(box.get_center(), deg_to_rad(-0.8))
	var local := Rect2(-box.size * 0.5, box.size)
	c.draw_rect(Rect2(local.position + Vector2(1.5, 2.0), local.size), Color(0, 0, 0, 0.35))
	c.draw_rect(local, TAG_PAPER)
	c.draw_rect(local, Color(TAG_INK, 0.85), false, 1.0)
	for i in rows.size():
		var top := local.position.y + 6.0 + step * i
		c.draw_texture_rect(rows[i][0], Rect2(local.position.x + 7.0, top + (step - icon) * 0.5, icon, icon), false, rows[i][2])
		var base := top + (step - _tag_font.get_height(fs)) * 0.5 + _tag_font.get_ascent(fs)
		var text_x := local.position.x + icon + 14.0
		if territories:
			var chip := Rect2(text_x, top + (step - swatch) * 0.5, swatch, swatch)
			c.draw_rect(chip, Color.WHITE.lerp(rows[i][3], 0.55))
			c.draw_rect(chip, Color(rows[i][3]).darkened(0.35), false, 1.0)
			text_x += swatch + 6.0
		c.draw_string(_tag_font, Vector2(text_x, base), str(rows[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TAG_INK)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


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


## A route as drawn in pencil and ink on the paper: a faint soft stroke underneath (the ink bleeding into the
## fibres) and, over it, a dashed hand-wobbled stroke in the line's colour mixed toward dark ink, with a short
## tick at every dash so it reads as a surveyed track rather than a vector line.
func _marker(c: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, seed: int) -> void:
	var pts := _wobble(a, b, seed, width * 0.35)
	if pts.size() < 2:
		return
	var ink := Color(0.16, 0.12, 0.09, col.a)
	var stroke := Color(col.r, col.g, col.b, col.a).lerp(ink, 0.55)
	c.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.16), width * 1.7, true)
	var dash := width * 4.2
	var gap := width * 1.5
	var run := 0.0
	var on := true
	for i in pts.size() - 1:
		var p := pts[i]
		var q := pts[i + 1]
		var seg := p.distance_to(q)
		if seg < 0.001:
			continue
		var dir := (q - p) / seg
		var t := 0.0
		while t < seg:
			var left := (dash if on else gap) - run
			var step := minf(left, seg - t)
			if on:
				c.draw_line(p + dir * t, p + dir * (t + step), stroke, width * 0.5, true)
			run += step
			t += step
			if run >= (dash if on else gap) - 0.0001:
				if on:
					var tick := p + dir * t
					var n := Vector2(-dir.y, dir.x) * width * 0.55
					c.draw_line(tick - n, tick + n, stroke, width * 0.28, true)
				on = not on
				run = 0.0


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


## P22 map feedback. Sympathy bands tint a ring on the pins you court; the colours are the muted paper-map set, never
## ORDER_RED.
const PASSAGE_BRASS := Color("e2a63a", 0.85)
const PULSE_S := 0.5


func _sympathy_band(game, sympathy: int) -> Color:
	if sympathy >= 100:
		return _faction_color(game, str(game.player))
	if sympathy >= 70:
		return Color("e2a63a")
	if sympathy >= 50:
		return Color("c4a574")
	if sympathy >= 20:
		return Color("8c8170")
	return Color("6f8494")


## The band's word for the sheet: Cold, Wary, Warm, Ready, With us.
func _sympathy_word(sympathy: int) -> String:
	if sympathy >= 100:
		return "With us"
	if sympathy >= 70:
		return "Ready"
	if sympathy >= 50:
		return "Warm"
	if sympathy >= 20:
		return "Wary"
	return "Cold"


## A station you court: known, not yours, not a bunker or ruin, and carrying a sympathy number.
func _courted(game, st: Dictionary) -> bool:
	return bool(st.get("known", false)) and str(st.owner) != str(game.player) and not (str(st.owner) in ["bunker", "ruin", "enemy"]) \
		and str(st.get("bunker", "")) == "" and st.has("sympathy") and not _secret(st)


## A dashed brass edge from every station with an open passage home to the yard; persistent while the passage is
## open, drawn under the red order trails.
func _draw_passage_edges(c: CanvasItem, game) -> void:
	var k := 1.0 / _map_scale()
	var home := str(game.capital_id)
	if not game.stations.has(home):
		return
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(sid) == home or not bool(st.get("passage", false)) or not bool(st.get("known", false)) or _secret(st):
			continue
		var a := _map_spot(str(sid))
		var b := _map_spot(home)
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var t := 0.0
		while t <= length:
			c.draw_circle(a.lerp(b, t / length), 1.8 * k, PASSAGE_BRASS)
			t += 11.0 * k


## Brass pips under a pin for each deal struck, three slots; nothing under a pin with no deal yet.
func _draw_deal_pips(c: CanvasItem, game) -> void:
	for sid in _layout:
		var row: Dictionary = _layout[sid]
		if not bool(row.known):
			continue
		var deals := clampi(int(game.stations[sid].get("deals", 0)), 0, 3)
		if deals < 1:
			continue
		var r := float(row.r)
		var lift := float(_lift.get(sid, 0.0))
		var mid: Vector2 = row.at + Vector2(0, r + 8.0) - Vector2(0, 2.0 * lift)
		for i in 3:
			var at := mid + Vector2((float(i) - 1.0) * 7.0, 0.0)
			if i < deals:
				c.draw_circle(at, 2.8, Color("e2a63a"))
			else:
				c.draw_arc(at, 2.8, 0, TAU, 16, Color(GRAPHITE, 0.5), 1.0, true)


func _pin_px(game, sid: String) -> float:
	var st: Dictionary = game.stations[sid]
	var big := bool(st.get("capital", false)) or sid == str(game.capital_id)
	var base := (PIN_CAPITAL if big else PIN_OTHER) * (1.0 + (0.4 if big else 0.22) * (1.0 if schematic else 0.0))
	return maxf(PIN_FLOOR, base * sqrt(zoom))


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


## Transfer stations (on two lines or more): a double ring round the pin, so the choke points read at a glance.
func _draw_junctions(c: CanvasItem, game) -> void:
	var lines: Dictionary = game.catalog.communities.get("lines", {})
	var count := {}
	for line_id in lines:
		for stop in lines[line_id]:
			count[str(stop)] = int(count.get(str(stop), 0)) + 1
	for sid in _layout:
		if schematic and bool(_layout[sid].known) and not bool(_layout[sid].big):
			var plain: Dictionary = _layout[sid]
			var holder := str(game.stations[sid].owner)
			var ring := Color("7a6a50")
			match holder:
				"neutral":
					ring = Color("7a6a50")
				"enemy":
					ring = ORDER_RED
				"ruin":
					ring = Color("5b5b5b")
				"bunker":
					ring = Color("b08a2a")
				_:
					ring = territory_color(game, holder)
			var pr := float(plain.px) * 0.5
			c.draw_arc(plain.at, pr + 1.5, 0.0, TAU, 40, Color(TAG_INK, 0.8), 5.0, true)
			c.draw_arc(plain.at, pr + 1.5, 0.0, TAU, 40, ring, 3.0, true)
	for sid in _layout:
		if bool(_layout[sid].known) and bool(_layout[sid].big):
			var cap: Dictionary = _layout[sid]
			var cr := float(cap.px) * 0.66
			c.draw_arc(cap.at, cr + 6.0, 0.0, TAU, 56, Color(TAG_INK, 0.85), 3.0, true)
			c.draw_arc(cap.at, cr + 2.0, 0.0, TAU, 56, Color("d9a93a"), 4.0, true)
	for sid in _layout:
		if int(count.get(str(sid), 0)) < 2 or not bool(_layout[sid].known):
			continue
		var row: Dictionary = _layout[sid]
		var r := float(row.px) * 0.62
		c.draw_arc(row.at, r + 4.0, 0.0, TAU, 48, Color(TAG_INK, 0.85), 3.0, true)
		c.draw_arc(row.at, r, 0.0, TAU, 48, Color(TAG_PAPER, 0.95), 4.0, true)


## A round badge with the line's letter at the first and the last stop of each line, in the line's colour.
func _draw_line_badges(c: CanvasItem, game) -> void:
	_ready_fonts()
	var lines: Dictionary = game.catalog.communities.get("lines", {})
	var font: Font = _tag_font if _tag_font != null else ThemeDB.fallback_font
	for line_id in lines:
		var stops: Array = lines[line_id]
		if stops.size() < 2:
			continue
		var col: Color = LINE_COLOR.get(str(line_id), Color("3a3028"))
		for end in [0, stops.size() - 1]:
			var sid := str(stops[end])
			if not _layout.has(sid) or not bool(_layout[sid].known):
				continue
			var row: Dictionary = _layout[sid]
			var at: Vector2 = row.at + Vector2(float(row.px) * 0.52, -float(row.px) * 0.52)
			c.draw_circle(at, 11.0, Color(TAG_INK, 0.9))
			c.draw_circle(at, 9.0, col)
			c.draw_string(font, at + Vector2(-5.0, 5.0), str(line_id).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)


## The route segments between known stations, in screen px, for placing tags clear of the lines.
func _line_segments(game) -> Array:
	var out: Array = []
	var lines: Dictionary = game.catalog.communities.get("lines", {})
	for line_id in lines:
		var stops: Array = lines[line_id]
		for i in range(stops.size() - 1):
			var a := str(stops[i])
			var b := str(stops[i + 1])
			if _layout.has(a) and _layout.has(b) and bool(_layout[a].known) and bool(_layout[b].known):
				out.append([_layout[a].at, _layout[b].at])
	return out


func _crossings(box: Rect2, segs: Array) -> int:
	var n := 0
	var tl := box.position
	var tr := Vector2(box.end.x, box.position.y)
	var br := box.end
	var bl := Vector2(box.position.x, box.end.y)
	for seg in segs:
		var p: Vector2 = seg[0]
		var q: Vector2 = seg[1]
		if box.has_point(p) or box.has_point(q):
			n += 1
		elif Geometry2D.segment_intersects_segment(p, q, tl, tr) != null or Geometry2D.segment_intersects_segment(p, q, tr, br) != null or Geometry2D.segment_intersects_segment(p, q, br, bl) != null or Geometry2D.segment_intersects_segment(p, q, bl, tl) != null:
			n += 1
	return n


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
	if bool(st.get("capital", false)):
		var mark := _symbol(game, station_faction(game, sid))
		if mark != null:
			var head := at - Vector2(0, 2.0 * lift)
			c.draw_circle(head, r * 0.72, TAG_PAPER)
			c.draw_arc(head, r * 0.72, 0, TAU, 24, Color(TAG_INK, 0.7), 1.0, true)
			var s := r * 1.08
			c.draw_texture_rect(mark, Rect2(head - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	if _courted(game, st):
		var band := _sympathy_band(game, int(st.sympathy))
		c.draw_arc(at - Vector2(0, 2.0 * lift), r + 2.5, 0, TAU, 28, Color(band, 0.92), 2.0, true)
		var left := int(st.get("leaflet_until", 0)) - int(game.week)
		if left > 0:
			_draw_leaflet(c, at + Vector2(r * 0.55, -r * 0.95) - Vector2(0, 2.0 * lift), 1.0 if left >= 2 else 0.55)
	if sid == selected:
		c.draw_arc(at, r + 5.0, 0, TAU, 32, GRAPHITE, 1.6, true)
		c.draw_arc(at + Vector2(0.8, -0.5), r + 6.0, 0.4, TAU - 0.3, 30, Color(GRAPHITE, 0.4), 1.0, true)
	if int(st.get("low_weeks", 0)) > 0:
		var warn := ArtPack.icon_texture("warning", 16.0)
		if warn != null:
			c.draw_texture_rect(warn, Rect2(at + Vector2(r * 0.6, -r - 14.0), Vector2(16, 16)), false)


## The leaflet chip: a recent Propaganda swing past 70, on a paper disc with a brass rim; faded in its last week.
func _draw_leaflet(c: CanvasItem, at: Vector2, alpha: float) -> void:
	c.draw_circle(at, 9.0, Color(TAG_PAPER, alpha))
	c.draw_arc(at, 9.0, 0, TAU, 20, Color("e2a63a", alpha), 1.0, true)
	var icon := ArtPack.icon_texture("propaganda", 14.0)
	if icon != null:
		c.draw_texture_rect(icon, Rect2(at - Vector2(7, 7), Vector2(14, 14)), false, Color(0.35, 0.22, 0.14, 0.95 * alpha))


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


## Window pixels per UI pixel: below 1 when the interface is scaled down to fit a small window.
func _window_scale() -> float:
	var ui_h := get_viewport_rect().size.y
	if not is_inside_tree() or ui_h < 1.0:
		return 1.0
	return clampf(float(get_window().size.y) / ui_h, 0.25, 4.0)


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
		if level == 0 and not schematic and not (bool(row.big) or own or focus):
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
	var placed: Array = [Rect2(0.0, 0.0, size.x, _hud_top())]
	for panel in [council, sheet, _zoom_bar]:
		if panel != null and panel.visible:
			placed.append(panel.get_rect().grow(4.0))
	for row in _yield_rows:
		placed.append(Rect2(row.x - 2.0, row.y - 2.0, float(row.total) + 4.0, 22.0))
	_tags.clear()
	var segs := _line_segments(game)
	var fs := maxi(14 if level < 2 else 15, ceili(TAG_MIN_PX / _window_scale()))
	for row in rows:
		var sid := str(row.id)
		var info: Dictionary = _layout[sid]
		var st: Dictionary = game.stations[sid]
		var title: String = game.station_text(sid, "community")
		if title == "":
			title = Copy.t(str(st.get("name", sid)))
		var sub := Copy.t(str(st.get("name", ""))) if level == 2 else ""
		var width := _tag_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if sub != "":
			width = maxf(width, _italic.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)
		var h := _tag_font.get_height(fs) + 6.0
		if sub != "":
			h += _italic.get_height(11)
		var fid := station_faction(game, sid)
		var mark := _symbol(game, fid)
		var badge := (TAG_BADGE_SMALL if level < 2 else TAG_BADGE_LARGE) if mark != null else 0.0
		var w := width + 18.0 + badge
		var at: Vector2 = info.at
		var reach := float(info.r) + 5.0
		var right := Rect2(at + Vector2(reach, -h * 0.5), Vector2(w, h))
		var left := Rect2(at + Vector2(-reach - w, -h * 0.5), Vector2(w, h))
		var sides := [right, left]
		if right.end.x > size.x - 8.0:
			sides = [left, right]
		var own := str(st.owner) == str(game.player)
		if own or sid == _hover or sid == selected:
			sides.append(Rect2(at + Vector2(-w * 0.5, -reach - h), Vector2(w, h)))
			sides.append(Rect2(at + Vector2(-w * 0.5, reach), Vector2(w, h)))
		if own or bool(info.big) or sid == _hover or sid == selected or schematic:
			for lean in [reach * 0.7, reach * 1.8, reach * 3.0]:
				for corner in [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					var x: float = at.x + lean if corner.x > 0.0 else at.x - lean - w
					var y: float = at.y - lean - h if corner.y < 0.0 else at.y + lean
					sides.append(Rect2(Vector2(x, y), Vector2(w, h)))
		var others: Array = []
		for head in heads:
			if str(head.id) != sid:
				others.append(head.box)
		var chosen := Rect2()
		var found := false
		var fewest := 1000
		for box in sides:
			if _hits(box, placed) or _hits(box, others):
				continue
			var crossings := _crossings(box, segs) if schematic else 0
			if crossings < fewest:
				fewest = crossings
				chosen = box
				found = true
				if crossings == 0:
					break
		if not found and schematic:
			## No exceptions in the schematic: when every spot is taken the tag goes where it hides the least.
			for box in sides:
				if not _hits(box, placed):
					chosen = box
					found = true
					break
			if not found:
				chosen = sides[0]
				found = true
		if not found:
			continue
		placed.append(chosen.grow(3.0))
		_tags[sid] = chosen
		var near := Vector2(clampf(at.x, chosen.position.x, chosen.end.x), clampf(at.y, chosen.position.y, chosen.end.y))
		if near.distance_to(at) > reach + 6.0:
			c.draw_line(at + (near - at).normalized() * float(info.r), near, GRAPHITE, 1.2, true)
		_paint_tag(c, chosen, title, sub, fs, _faction_color(game, str(st.owner)), sid, mark, badge, _paper_tint(fid))


## A tag with a faction carries its symbol at the left (the tag is `badge` px wider for it); one without keeps
## the colour strip.
func _paint_tag(c: CanvasItem, box: Rect2, title: String, sub: String, fs: int, strip: Color, sid: String, mark: Texture2D = null, badge := 0.0, tint := Color.WHITE) -> void:
	var tilt := deg_to_rad(float(_hash(sid + "#tag") % 61 - 30) / 10.0)
	var pivot := box.get_center()
	c.draw_set_transform(pivot, tilt)
	var local := Rect2(box.position - pivot, box.size)
	var bold := schematic
	c.draw_rect(Rect2(local.position + (Vector2(2.5, 3.5) if bold else Vector2(1.5, 2.0)), local.size), Color(0, 0, 0, 0.6 if bold else 0.35))
	c.draw_rect(local, TAG_PAPER)
	if mark == null:
		c.draw_rect(Rect2(local.position, Vector2(5.0, local.size.y)), strip)
	else:
		var line_h := _tag_font.get_height(fs) + 6.0
		c.draw_texture_rect(mark, Rect2(local.position + Vector2(4.0, maxf(1.0, (line_h - badge) * 0.5)), Vector2(badge, badge)), false, tint)
	c.draw_rect(local, Color(TAG_INK, 1.0 if bold else 0.85), false, 2.6 if bold else 1.0)
	var text_x := local.position.x + 10.0 + badge
	var base := local.position.y + 3.0 + _tag_font.get_ascent(fs)
	c.draw_string(_tag_font, Vector2(text_x, base), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TAG_INK)
	if sub != "":
		var sub_base := base + _tag_font.get_descent(fs) + _italic.get_ascent(11)
		c.draw_string(_italic, Vector2(text_x, sub_base), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(TAG_INK, 0.8))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _order_icon(kind: String) -> String:
	match kind:
		"move":
			return "squad"
		"expedition":
			return "artifact"
		"approach", "approach_quarantine", "approach_observatory":
			return "envoy"
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


## Draw cached map miniatures using presentation state while preserving the simulation's orders.
func _draw_squads(c: CanvasItem, game) -> void:
	var bay_slots := {}
	_squad_positions.clear()
	for fid in game.squads:
		var sq: Dictionary = game.squads[fid]
		var sid := str(sq.station)
		if not game.stations.has(sid) or _secret(game.stations[sid]) or bool(sq.get("away", false)):
			continue
		if not bool(game.stations[sid].get("known", false)) and str(fid) != game.player:
			continue
		var at := _pin_at(game, sid)
		var direction := Vector2.RIGHT
		var distance := 0.0
		var kind := "squad_stand"
		var compact := false
		if _walks.has(str(fid)) and not _motion_off():
			var walk: Dictionary = _walks[str(fid)]
			var pts := PackedVector2Array()
			for hop in walk.route:
				pts.append(_pin_at(game, str(hop)))
			pts[0] = _squad_station_bay(game, str(walk.route[0]), int(sq.size), 0)
			pts[-1] = _squad_station_bay(game, str(walk.route[-1]), int(sq.size), 0)
			var k := clampf(float(walk.t) / float(walk.dur), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			distance = k * _poly_length(pts)
			var spot := _along(pts, distance)
			at = spot[0]
			direction = spot[1]
			kind = "squad_walk"
		else:
			var slot := int(bay_slots.get(sid, 0))
			bay_slots[sid] = slot + 1
			var bay := _squad_station_layout(sid, int(sq.size), slot)
			at = bay.at
			compact = bay.compact
		_squad_positions[str(fid)] = {"at": at, "compact": compact, "sid": sid}
		_draw_squad_token(c, game, at, str(fid), int(sq.size), kind, direction, distance, compact)

## Use a visible neighbouring tunnel to choose the same clear bay for standing, departure and arrival.
func _squad_station_bay(game, sid: String, size_n: int, slot: int = 0) -> Vector2:
	return _squad_station_layout(sid, size_n, slot).at

## Search only the station's immediate neighbourhood, falling back to a 30-pixel count token.
func _squad_station_layout(sid: String, size_n: int, slot: int = 0) -> Dictionary:
	var key := "%s_%d_%d" % [sid, size_n, slot]
	if _squad_bay_cache.has(key):
		return _squad_bay_cache[key]
	var pin: Dictionary = _layout[sid]
	for compact in [false, true]:
		var footprint := Rect2(-15, -15, 30, 30) if compact else _squad_footprint(size_n)
		for reach in [1.4, 1.8, 2.2]:
			for i in 32:
				var angle := -PI * 0.5 + (i + slot * 8) * TAU / 32.0
				var at: Vector2 = Vector2(pin.at) + Vector2.from_angle(angle) * float(pin.r) * reach
				if _squad_bay_clear(sid, at, footprint):
					_squad_bay_cache[key] = {"at": at, "compact": compact}
					return _squad_bay_cache[key]
	_squad_bay_cache[key] = {"at": Vector2(pin.at) + Vector2(-float(pin.r) * 2.2, 0), "compact": true}
	return _squad_bay_cache[key]

## Require local ownership, paper containment and exact circle clearance for the whole bay footprint.
func _squad_bay_clear(sid: String, at: Vector2, footprint: Rect2) -> bool:
	var own: Dictionary = _layout[sid]
	var distance := at.distance_to(own.at)
	if distance > float(own.r) * 2.2 + 0.01:
		return false
	var box := Rect2(at + footprint.position, footprint.size).grow(1.0)
	if not _inside_map_paper(box):
		return false
	for other in _layout:
		var pin: Dictionary = _layout[other]
		if str(other) != sid and at.distance_to(pin.at) <= distance:
			return false
		var closest := Vector2(clampf(pin.at.x, box.position.x, box.end.x), clampf(pin.at.y, box.position.y, box.end.y))
		if closest.distance_to(pin.at) < float(pin.r) + 1.0:
			return false
	for tag in _tags.values():
		if box.intersects(tag.grow(1.0)):
			return false
	for row in _yield_rows:
		if box.intersects(Rect2(row.x, row.y, row.total, 18).grow(1.0)):
			return false
	return true

## Invert both camera and paper transforms so desk pixels never count as paper.
func _inside_map_paper(box: Rect2) -> bool:
	var inverse := _map_xf.affine_inverse()
	var paper := Rect2(Vector2(2, 2), _map_size - Vector2(4, 4))
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		if not paper.has_point(inverse * _world(corner)):
			return false
	return true


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
		var beat := 1.0 if _motion_off() else 1.0 + 0.12 * sin(_anim_t * 3.2 + float(sid.length()))
		if not _motion_off():
			c.draw_arc(at, 11.0 + 6.0 * fmod(_anim_t * 0.8, 1.0), 0.0, TAU, 32, Color("f0b429", 0.5 * (1.0 - fmod(_anim_t * 0.8, 1.0))), 2.0, true)
		c.draw_circle(at + Vector2(1, 2), 11.0 * beat, Color(0, 0, 0, 0.35))
		c.draw_circle(at, 11.0 * beat, Color("241c14"))
		if icon != null:
			c.draw_texture_rect(icon, Rect2(at - Vector2(10, 10) * beat, Vector2(20, 20) * beat), false)
		else:
			c.draw_circle(at, 6.0, Color("f0b429"))


## Yields and caravans. Under every held station a row of chips says what it ships home at next dawn (the focus
## good ringed in gold, a clock while it is still settling in, a red mark when the line is cut). Over the map,
## loads walk home along each supply line, building materials walk out to stations still settling in, and
## traders walk out and back to every station with a deal. Pure view: the sim pays at dawn either way.
const FOCUS_GOOD := {"food": "food", "air": "air", "defense": "materials", "influence": "influence"}
const YIELD_KEYS := ["food", "materials", "air", "influence", "tokens"]
const CARAVAN_SPEED := 34.0
const CARAVAN_SPACING := 200.0
const TRADE_GOLD := Color("c9a227")
const SETTLE_WEEKS := 5
## What each rival's carts carry, by what the faction lives on.
const RIVAL_GOOD := {"exchange": "tokens", "directorate": "materials", "synod": "influence", "depot": "food", "black_flag": "air"}
var _unit_layer: Control
var _caravans: Array = []
var _chip_box: StyleBoxFlat
var _chip_hits := {}
var _yield_rows: Array = []
var _chip_hover := ""
var _focus_menu: PopupMenu
var _focus_menu_sid := ""
const FOCUS_ORDER := ["food", "air", "defense", "influence"]


func _chip_at(screen_at: Vector2) -> String:
	for sid in _chip_hits:
		if (_chip_hits[sid] as Rect2).has_point(screen_at):
			return str(sid)
	return ""


## A popup menu dressed as a paper card (cream, brown rim, gold hover), so menus on the map match the sheets.
func _paper_menu(picked: Callable) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.id_pressed.connect(picked)
	var card := StyleBoxFlat.new()
	card.bg_color = CARD
	card.border_color = Color("8a6a44")
	card.set_border_width_all(2)
	card.set_corner_radius_all(4)
	card.set_content_margin_all(8)
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 6
	card.shadow_offset = Vector2(2, 3)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(TRADE_GOLD, 0.28)
	lit.set_corner_radius_all(3)
	var rule := StyleBoxLine.new()
	rule.color = Color(CARD_MUTED, 0.5)
	rule.thickness = 1
	menu.add_theme_stylebox_override("panel", card)
	menu.add_theme_stylebox_override("hover", lit)
	menu.add_theme_stylebox_override("separator", rule)
	menu.add_theme_stylebox_override("labeled_separator_left", rule)
	menu.add_theme_stylebox_override("labeled_separator_right", rule)
	menu.add_theme_color_override("font_color", CARD_INK)
	menu.add_theme_color_override("font_hover_color", CARD_INK)
	menu.add_theme_color_override("font_disabled_color", Color(CARD_MUTED, 0.7))
	menu.add_theme_color_override("font_separator_color", CARD_MUTED)
	menu.add_theme_constant_override("v_separation", 10)
	menu.add_theme_constant_override("h_separation", 8)
	menu.add_theme_font_override("font", _font())
	menu.add_theme_font_size_override("font_size", 15)
	if _tag_font != null:
		menu.add_theme_font_override("font_separator", _tag_font)
	menu.add_theme_font_size_override("font_separator_size", 16)
	add_child(menu)
	return menu


## Governors on the station card: who holds it (portrait, skill, what they add) with Recall, or Appoint, which opens
## a picker of residents sorted by what they would add, each with the price.
var _gov_menu: PopupMenu
var _gov_menu_sid := ""
var _gov_menu_ids: Array = []


func _add_governor(game, st: Dictionary, sid: String, parent: Node) -> void:
	var pid := str(st.get("governor", ""))
	var focus := str(st.get("focus", "food"))
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	block.add_child(row)
	if pid != "" and game.people.has(pid):
		var person: Dictionary = game.people[pid]
		if host != null and host.has_method("_portrait_box"):
			row.add_child(host._portrait_box(pid, 44))
		var key := str(game.GOVERNOR_SKILL.get(focus, "labor"))
		var bonus := int(game.governor_bonus(pid, focus))
		var line := "%s: %s\n%s %d" % [Copy.t("Governor"), Copy.person(str(person.name)), Copy.skill(key), int(person.skills.get(key, 0))]
		if bonus > 0:
			line += " · +%d %s" % [bonus, Copy.res(str(FOCUS_GOOD.get(focus, "food")))]
		var text := _lab(line, 14, false)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var back := Button.new()
		back.text = Copy.t("Recall")
		back.tooltip_text = Copy.t("Bring them home now. Their old room takes them back if there is space.")
		back.pressed.connect(_recall_governor.bind(sid))
		block.add_child(back)
	else:
		var text := _lab(Copy.t("No governor. One of ours in charge ships more and keeps the station loyal."), 14, false)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var pick := Button.new()
		block.add_child(pick)
		pick.text = Copy.t("Appoint")
		pick.tooltip_text = Copy.t("%d influence, then %d a week.") % [int(game.bal.governor.appoint_influence), int(game.bal.governor.weekly_influence)]
		pick.disabled = game.governor_candidates(sid).is_empty()
		pick.pressed.connect(func(): open_governor_menu(sid, pick.get_global_rect().position - get_global_rect().position + Vector2(0, pick.size.y)))
	parent.add_child(block)


func open_governor_menu(sid: String, at: Vector2) -> void:
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	if _gov_menu == null:
		_gov_menu = _paper_menu(_on_governor_picked)
	_gov_menu.clear()
	_gov_menu_sid = sid
	_gov_menu_ids.clear()
	var g: Dictionary = game.bal.governor
	_gov_menu.add_separator(Copy.t("Who holds %s?") % str(game.station_text(sid, "community")))
	var focus := str(game.stations[sid].get("focus", "food"))
	var good := Copy.res(str(FOCUS_GOOD.get(focus, "food")))
	var short: bool = int(game.stock.influence) < int(g.appoint_influence)
	for row in game.governor_candidates(sid).slice(0, 8):
		var bits: PackedStringArray = ["%s %d" % [Copy.skill(str(row.skill_key)), int(row.skill)]]
		if int(row.bonus) > 0:
			bits.append("+%d %s" % [int(row.bonus), good])
		if int(row.talk) >= int(g.talk_min):
			bits.append(Copy.t("loyalty +%d a week") % int(g.talk_loyalty))
		if bool(row.council):
			bits.append(Copy.t("councillor: no order while away"))
		var label := "%s   %s" % [Copy.person(str(row.name)), ", ".join(bits)]
		var id := _gov_menu_ids.size()
		_gov_menu_ids.append(str(row.id))
		_gov_menu.add_item(label, id)
		_gov_menu.set_item_disabled(_gov_menu.get_item_index(id), short)
	_gov_menu.add_separator(Copy.t("%d influence, then %d a week.") % [int(g.appoint_influence), int(g.weekly_influence)])
	_gov_menu.reset_size()
	_gov_menu.popup(Rect2i(Vector2i(get_screen_position() + at), Vector2i.ZERO))


func _on_governor_picked(id: int) -> void:
	var game = _game()
	if game == null or id < 0 or id >= _gov_menu_ids.size():
		return
	var sid := _gov_menu_sid
	var pid := str(_gov_menu_ids[id])
	if not game.apply({"kind": "appoint", "station": sid, "person": pid}):
		return
	if host != null and host.has_method("_toast"):
		host._toast(Copy.t("%s now holds %s for us.") % [Copy.person(str(game.people[pid].name)), str(game.station_text(sid, "community"))])
	_after_governor()


func _recall_governor(sid: String) -> void:
	var game = _game()
	if game == null or not game.apply({"kind": "recall", "station": sid}):
		return
	_after_governor()


func _after_governor() -> void:
	if host != null:
		if host.has_method("_ui_click"):
			host._ui_click()
		if host.has_method("_refresh"):
			host._refresh()
	refresh()


## The focus menu under a held station's chips: one row per focus with what it would ship home, the current one
## ticked. Picking a row is the same order as the focus buttons on the station card.
func open_focus_menu(sid: String, screen_at: Vector2) -> void:
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	if _focus_menu == null:
		_focus_menu = _paper_menu(_on_focus_picked)
	_focus_menu.clear()
	_focus_menu_sid = sid
	var st: Dictionary = game.stations[sid]
	var current := str(st.get("focus", "food"))
	var settling := int(game.outpost_yield(sid).get("upkeep_materials", 0)) > 0
	_focus_menu.add_separator(str(game.station_text(sid, "community")))
	var labels := {}
	for row in order_rows(game, true, sid):
		labels[str(row[0]).trim_prefix("focus:")] = str(row[1])
	for i in FOCUS_ORDER.size():
		var focus: String = FOCUS_ORDER[i]
		var flow: Dictionary = game.outpost_yield(sid, focus, true)
		var bits: PackedStringArray = []
		for key in YIELD_KEYS:
			if int(flow.get(key, 0)) > 0:
				bits.append("+%d %s" % [int(flow[key]), Copy.res(key)])
		var text := Copy.t(str(labels.get(focus, _focus_word(focus))))
		if not bits.is_empty():
			text += "   " + ", ".join(bits)
		_focus_menu.add_check_item(text, i)
		var idx := _focus_menu.get_item_index(i)
		_focus_menu.set_item_checked(idx, focus == current)
		var icon := ArtPack.icon_texture(str(FOCUS_GOOD[focus]), 24.0)
		if icon != null:
			_focus_menu.set_item_icon(idx, icon)
			_focus_menu.set_item_icon_max_width(idx, 20)
	if settling:
		_focus_menu.add_separator(Copy.t("Ships once it has settled in."))
	_focus_menu.reset_size()
	_focus_menu.popup(Rect2i(Vector2i(get_screen_position() + screen_at), Vector2i.ZERO))


func _on_focus_picked(id: int) -> void:
	if id < 0 or id >= FOCUS_ORDER.size() or _focus_menu_sid == "":
		return
	var game = _game()
	var sid := _focus_menu_sid
	var focus: String = FOCUS_ORDER[id]
	if game == null or not game.set_outpost_focus(sid, focus):
		return
	if host != null and host.has_method("_toast"):
		host._toast(Copy.t("%s will send %s home.") % [str(game.station_text(sid, "community")), Copy.t(_focus_word(focus))])
	if host != null and host.has_method("_ui_click"):
		host._ui_click()
	refresh()


## Lays out every chip row before the tags are placed, so name tags step around the chips instead of covering them.
func _plan_yields(game) -> void:
	_yield_rows.clear()
	var font := _font()
	var fs := 12
	for sid in _layout:
		var st: Dictionary = game.stations[sid]
		if str(sid) == str(game.capital_id) or not bool(_layout[sid].known):
			continue
		var own := str(st.owner) == str(game.player)
		## A station that is not ours shows, while hovered or picked, what it would ship once taken: faint, not a button.
		var preview := not own and (str(sid) == _hover or str(sid) == selected)
		if not own and not preview:
			continue
		var cells: Array = _yield_cells(game, str(sid), st) if own else _preview_cells(game, str(sid))
		if cells.is_empty():
			continue
		var widths: Array = []
		var total := 0.0
		for cell in cells:
			var w := font.get_string_size(str(cell.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
			w += 18.0 if str(cell.icon) != "" else 4.0
			widths.append(w)
			total += w + 2.0
		total += -2.0 if preview else 16.0
		var pin: Dictionary = _layout[sid]
		_yield_rows.append({"sid": str(sid), "cells": cells, "widths": widths, "total": total, "preview": preview,
			"x": (pin.at as Vector2).x - total * 0.5, "y": (pin.at as Vector2).y + float(pin.r) + 4.0})


func _draw_yields(c: CanvasItem, game) -> void:
	if _chip_box == null:
		_chip_box = StyleBoxFlat.new()
		_chip_box.bg_color = Color(PAPER, 0.88)
		_chip_box.set_corner_radius_all(7)
		_chip_box.border_color = Color(TRADE_GOLD, 0.0)
	var font := _font()
	var fs := 12
	_chip_hits.clear()
	for plan in _yield_rows:
		var sid := str(plan.sid)
		var cells: Array = plan.cells
		var widths: Array = plan.widths
		var total := float(plan.total)
		var x := float(plan.x)
		var y := float(plan.y)
		if bool(plan.preview):
			_chip_box.bg_color = Color(PAPER, 0.78)
			_chip_box.border_color = Color(MUTED, 0.0)
			_chip_box.set_border_width_all(0)
			for i in cells.size():
				var cell: Dictionary = cells[i]
				var box := Rect2(x, y, float(widths[i]), 18.0)
				_chip_box.draw(c.get_canvas_item(), box)
				var tx := 4.0
				var icon := ArtPack.icon_texture(str(cell.icon), 14.0) if str(cell.icon) != "" else null
				if icon != null:
					c.draw_texture_rect(icon, Rect2(box.position + Vector2(4, 2), Vector2(14, 14)), false, Color(1, 1, 1, 0.75))
					tx = 19.0
				c.draw_string(font, box.position + Vector2(tx, 13.5), str(cell.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cell.col)
				x += float(widths[i]) + 2.0
			_chip_box.bg_color = Color(PAPER, 0.88)
			continue
		var hot: bool = str(sid) == _chip_hover
		_chip_hits[str(sid)] = Rect2(x - 2.0, y - 2.0, total + 4.0, 22.0)
		if hot:
			_chip_box.border_color = TRADE_GOLD
			_chip_box.set_border_width_all(1)
			_chip_box.bg_color = Color(TRADE_GOLD, 0.35)
			_chip_box.draw(c.get_canvas_item(), _chip_hits[str(sid)])
			_chip_box.bg_color = Color(PAPER, 0.88)
		## The last chip is a small caret: the row is a button that opens the focus menu.
		var caret := Rect2(x + total - 16.0, y, 16.0, 18.0)
		_chip_box.border_color = Color(TRADE_GOLD, 0.0)
		_chip_box.set_border_width_all(0)
		_chip_box.draw(c.get_canvas_item(), caret)
		var mid := caret.get_center() + Vector2(0, 1)
		c.draw_colored_polygon(PackedVector2Array([mid + Vector2(-4, -2), mid + Vector2(4, -2), mid + Vector2(0, 3)]), TRADE_GOLD if hot else MUTED)
		for i in cells.size():
			var cell: Dictionary = cells[i]
			var box := Rect2(x, y, float(widths[i]), 18.0)
			_chip_box.border_color = TRADE_GOLD if bool(cell.ring) else Color(TRADE_GOLD, 0.0)
			_chip_box.set_border_width_all(2 if bool(cell.ring) else 0)
			_chip_box.draw(c.get_canvas_item(), box)
			var icon := ArtPack.icon_texture(str(cell.icon), 14.0)
			if icon != null:
				c.draw_texture_rect(icon, Rect2(box.position + Vector2(4, 2), Vector2(14, 14)), false)
			c.draw_string(font, box.position + Vector2(19, 13.5), str(cell.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cell.col)
			x += float(widths[i]) + 2.0


## The faint chips under a station that is not ours: "If ours" and what it would ship once settled in.
func _preview_cells(game, sid: String) -> Array:
	var flow: Dictionary = game.yield_if_taken(sid)
	if flow.is_empty():
		return []
	var cells: Array = [{"icon": "", "text": Copy.t("If ours"), "col": MUTED}]
	var any := false
	for key in YIELD_KEYS:
		var gain := int(flow.get(key, 0))
		if gain > 0:
			any = true
			cells.append({"icon": key, "text": "+%d" % gain, "col": Color(INK, 0.85)})
	if not any:
		cells.append({"icon": "warning", "text": Copy.t("no supply line"), "col": Color("e0705a")})
	return cells


## The chips under one held station, left to right: [{icon, text, col, ring}].
func _yield_cells(game, sid: String, st: Dictionary) -> Array:
	var cells: Array = []
	if int(game._supply_hops(sid)) >= 900:
		cells.append({"icon": "warning", "text": Copy.t("cut"), "col": Color("e0705a"), "ring": false})
		return cells
	var flow: Dictionary = game.outpost_yield(sid)
	var upkeep := int(flow.get("upkeep_materials", 0))
	if upkeep > 0:
		cells.append({"icon": "materials", "text": "-%d" % upkeep, "col": Color("e0705a"), "ring": false})
		var left := maxi(1, SETTLE_WEEKS - int(st.get("held_weeks", 0)))
		cells.append({"icon": "clock", "text": str(left), "col": MUTED, "ring": false})
		return cells
	var focus_good := str(FOCUS_GOOD.get(str(st.get("focus", "food")), "food"))
	var lift := int(game.governor_bonus(str(st.get("governor", "")), str(st.get("focus", "food"))))
	for key in YIELD_KEYS:
		var gain := int(flow.get(key, 0))
		if gain > 0:
			var boosted: bool = key == focus_good and lift > 0
			cells.append({"icon": key, "text": "+%d ▲%d" % [gain, lift] if boosted else "+%d" % gain, "col": TRADE_GOLD.lightened(0.25) if boosted else INK, "ring": key == focus_good})
	return cells


## A governed station wears its governor's face as a round seal on the lower left of the pin.
func _draw_governors(c: CanvasItem, game) -> void:
	if host == null or not host.has_method("_portrait_for"):
		return
	for sid in _layout:
		var st: Dictionary = game.stations[sid]
		var pid := str(st.get("governor", ""))
		if pid == "" or str(st.owner) != str(game.player):
			continue
		var face: Texture2D = host._portrait_for(pid)
		var row: Dictionary = _layout[sid]
		var r := float(row.r)
		var at: Vector2 = (row.at as Vector2) + Vector2(-r * 0.95, r * 0.45)
		var rad := 12.0
		c.draw_circle(at + Vector2(1, 2), rad + 2.5, Color(0, 0, 0, 0.35))
		c.draw_circle(at, rad + 2.5, TRADE_GOLD)
		if face != null:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for i in 24:
				var a := TAU * float(i) / 24.0
				var d := Vector2(cos(a), sin(a))
				pts.append(at + d * rad)
				uvs.append(Vector2(0.5, 0.42) + d * 0.42)
			c.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, face)
		else:
			c.draw_circle(at, rad, TAG_PAPER)
		c.draw_arc(at, rad + 2.5, 0.0, TAU, 28, Color("5e4329"), 1.2, true)


func _caravan_routes(game) -> Array:
	var out: Array = []
	var player := str(game.player)
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if _secret(st) or str(sid) == str(game.capital_id):
			continue
		if str(st.owner) == player:
			var flow: Dictionary = game.outpost_yield(str(sid))
			var route: Array = game.supply_route(str(sid))
			if route.size() < 2 or not _route_shown(game, route):
				continue
			if int(flow.get("upkeep_materials", 0)) > 0:
				route.reverse()
				out.append({"route": route, "good": "materials", "kind": "settle", "seed": _hash(str(sid))})
				continue
			var good := _main_good(flow, str(st.get("focus", "food")))
			if good != "":
				out.append({"route": route, "good": good, "kind": "supply", "seed": _hash(str(sid))})
		elif int(st.get("deals", 0)) > 0 and bool(st.get("known", false)):
			var route: Array = game.trade_route(str(sid))
			if route.size() >= 2 and _route_shown(game, route):
				out.append({"route": route, "good": "tokens", "kind": "trade", "seed": _hash(str(sid))})
	out.append_array(_rival_routes(game))
	return out


## Rival stations send their own carts to their faction's seat, so the map shows a living economy and where each
## rival's strength flows. Only routes the player can see end to end (every station on it known).
func _rival_routes(game) -> Array:
	var out: Array = []
	var seats := {}
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if bool(st.get("capital", false)):
			seats[str(st.owner)] = str(sid)
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		var owner := str(st.owner)
		if owner == str(game.player) or not seats.has(owner) or str(seats[owner]) == str(sid):
			continue
		if not bool(st.get("known", false)) or _secret(st):
			continue
		var route: Array = game.rival_route(str(sid), str(seats[owner]))
		if route.size() < 2 or not _route_shown(game, route):
			continue
		var known_all := true
		for hop in route:
			if not bool(game.stations[str(hop)].get("known", false)):
				known_all = false
				break
		if known_all:
			out.append({"route": route, "good": RIVAL_GOOD.get(owner, "materials"), "kind": "rival", "owner": owner, "seed": _hash(str(sid))})
	return out


func _route_shown(game, route: Array) -> bool:
	for sid in route:
		if not _layout.has(str(sid)) or _secret(game.stations[str(sid)]):
			return false
	return true


## The good a caravan carries: the focus good when the station ships it, otherwise the largest load.
func _main_good(flow: Dictionary, focus: String) -> String:
	var want := str(FOCUS_GOOD.get(focus, "food"))
	if int(flow.get(want, 0)) > 0:
		return want
	var best := ""
	for key in YIELD_KEYS:
		if int(flow.get(key, 0)) > int(flow.get(best, 0)):
			best = key
	return best


## Draw cached map miniatures using presentation state while preserving the simulation's orders.
func _draw_units(c: CanvasItem) -> void:
	var game = _game()
	if game == null or _layout.is_empty():
		return
	_sprites.begin()
	_sprites.distance_per_frame = CARAVAN_SPEED / 8.0 * zoom / _zoom_min
	_draw_splashes(c, game)
	_draw_intents(c, game)
	_draw_squads(c, game)
	var still := _motion_off()
	var home_col := _faction_color(game, str(game.player))
	var active := {}
	for row in _caravans:
		var id := "%s_%s_%s" % [row.kind, row.get("owner", "home"), row.seed]
		active[id] = true
		if not _unit_routes.has(id):
			_unit_routes[id] = {"row": row, "born": _anim_t, "retire": -1.0}
		else:
			_unit_routes[id].row = row
			_unit_routes[id].retire = -1.0
	for id in _unit_routes.keys():
		var state: Dictionary = _unit_routes[id]
		if still and not active.has(id):
			_unit_routes.erase(id)
			continue
		var row: Dictionary = state.row
		var trade := str(row.kind) == "trade"
		var kind := "trader_roll" if trade else "handcar_pump"
		var pts := PackedVector2Array()
		for sid in row.route:
			pts.append((_layout[str(sid)] as Dictionary).at)
		pts = _unit_route_bays(pts, str(row.route[0]), str(row.route[-1]), kind)
		var length := _poly_length(pts)
		if length < 12.0:
			continue
		var rival := str(row.kind) == "rival"
		var col: Color = TRADE_GOLD if trade else home_col
		if rival:
			col = _faction_color(game, str(row.owner))
		var speed := CARAVAN_SPEED * zoom / _zoom_min
		var duration := length / speed + 0.45 * (pts.size() - 1)
		var leg_period := duration + (1.2 if trade else 2.4)
		var cycle := leg_period * (2.0 if trade else 1.0)
		var car_width := _unit_width(kind)
		var headway := 2.4 + 1.6 * car_width / speed + 0.45 * pts.size()
		var n := maxi(1, int(leg_period / headway)) if str(row.kind) in ["supply", "settle"] else 1
		var elapsed := _anim_t - float(state.born)
		if not active.has(id) and float(state.retire) < 0:
			state.retire = elapsed + leg_period - fmod(elapsed, leg_period) + (0.25 if trade else 0.0)
		if float(state.retire) >= 0 and elapsed >= float(state.retire):
			_unit_routes.erase(id)
			continue
		for i in n:
			## Stagger departures from the station rather than creating the later cars mid-track.
			var launch := float(i) * cycle / n
			if not still and elapsed < launch:
				continue
			var clock := minf(elapsed, float(state.retire) - 0.25001) if trade and float(state.retire) >= 0 else elapsed
			var time := fmod(maxf(0.0, clock - launch), cycle)
			var returning := trade and time >= leg_period and not still
			var local := fmod(time, leg_period)
			var idle := local < 1.2 or local >= duration + 1.2
			var progress := _unit_progress(pts, local - 1.2, speed)
			var distance := float(progress.x)
			if still:
				distance = (float(i) + 0.5) / n * length
				idle = true
			if trade and float(state.retire) >= 0 and elapsed >= float(state.retire) - 0.25:
				distance = length
				idle = true
			var along := length - distance if returning else distance
			if still and trade and i % 2 == 1:
				returning = true
			var spot := _along(pts, along)
			var dir: Vector2 = -spot[1] if returning else spot[1]
			var at: Vector2 = spot[0]
			if trade or rival:
				var lane: Vector2 = spot[1]
				if lane.x < 0 or (is_zero_approx(lane.x) and lane.y < 0):
					lane = -lane
				var lane_offset := 10.0 if trade else -10.0 * (1 + maxi(0, game.catalog.factions.keys().find(str(row.get("owner", "")))))
				at += Vector2(-lane.y, lane.x) * lane_offset * zoom / _zoom_min
			var good := "tokens" if returning else str(row.good)
			var alpha := 1.0
			if not still:
				alpha = clampf(elapsed / 0.25, 0, 1)
				if not trade:
					alpha = minf(alpha, clampf((leg_period - local) / 0.25, 0, 1))
				if not trade:
					alpha = minf(alpha, clampf(local / 0.25, 0, 1))
			if float(state.retire) >= 0 and not still:
				alpha = minf(alpha, clampf((float(state.retire) - elapsed) / 0.25, 0, 1))
			var key := "cart_%s_%s_%s_%d" % [row.kind, row.get("owner", "home"), row.seed, i]
			var accepted_car := str(row.kind) in ["supply", "settle", "trade", "rival"]
			var height := _unit_height()
			if height < 30 or not accepted_car:
				_draw_unit_disc(c, at, col, good)
				continue
			c.draw_texture_rect(_sprites.shadow, Rect2(at - Vector2(height * 0.6, height * 0.12), Vector2(height * 1.2, height * 0.3)), false, Color(1, 1, 1, alpha * minf(1, zoom / _zoom_min * 0.65)))
			if not _sprites.paint(key, kind, at, dir, col, height, distance, _anim_t, still, idle, alpha):
				_draw_unit_disc(c, at, col, good)
				continue
			if not still and not idle and progress.y >= 0.4 and progress.z >= 0.5:
				_emit_cruise_puff(key, at - dir * car_width * 0.38, height * 0.28)
			var unloading := not trade and local >= duration + 1.2
			var drop := clampf((local - duration - 1.2) / 0.45, 0, 1) if unloading and not still else 0.0
			var tag := at + Vector2(-height * 0.35, -height * 0.25 + drop * 12 - sin(drop * PI * 3) * (1.0 - drop) * 3)
			var swing := 0.0 if still or idle else sin(_anim_t * 4) * 0.08
			_sprites.tag(key + "_tag", tag, good, swing, alpha * (1.0 - drop))
	_draw_expedition(c, game, home_col, still)
	_draw_puffs(still)
	_sprites.finish()

## Emit at most one dust burst per vehicle every 0.6 seconds, only during its cruise interval.
func _emit_cruise_puff(key: String, at: Vector2, height: float) -> void:
	if not _sprites.frames.has("puff") or _anim_t - float(_puff_times.get(key, -100.0)) < 0.6:
		return
	_puff_times[key] = _anim_t
	_puffs["puff_" + key] = {"at": at, "height": height, "born": _anim_t}

## Fade and retire pooled dust bursts without redrawing the static map or tinting their colours.
func _draw_puffs(still: bool) -> void:
	if still:
		_puffs.clear()
		_puff_times.clear()
		return
	for key in _puffs.keys():
		var row: Dictionary = _puffs[key]
		var age := _anim_t - float(row.born)
		if age >= 0.6:
			_puffs.erase(key)
		else:
			_sprites.puff(str(key), row.at, row.height, age)


func _poly_length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total


## [position, unit direction] at a distance along a polyline.
func _along(pts: PackedVector2Array, dist: float) -> Array:
	var left := dist
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if seg <= 0.001:
			continue
		var dir := (pts[i + 1] - pts[i]) / seg
		if left <= seg:
			return [pts[i] + dir * left, dir]
		left -= seg
	var last := pts.size() - 1
	return [pts[last], (pts[last] - pts[last - 1]).normalized()]


func _route_dots(c: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var length := _poly_length(pts)
	var t := 6.0
	while t < length - 6.0:
		var dot: Vector2 = _along(pts, t)[0]
		c.draw_circle(dot, 2.6, Color(TAG_PAPER, col.a))
		c.draw_circle(dot, 1.8, col)
		t += 10.0


## Draw cached map miniatures using presentation state while preserving the simulation's orders.
func _draw_expedition(c: CanvasItem, game, col: Color, still: bool) -> void:
	if game.expedition.is_empty() or not game.squads.has(game.player):
		return
	var tunnel: Dictionary = game._tunnel_by_id(str(game.expedition.get("tunnel", "")))
	if tunnel.is_empty():
		return
	var a := str(tunnel.get("a", ""))
	var b := str(tunnel.get("b", ""))
	if a != str(game.capital_id):
		var swap := a
		a = b
		b = swap
	if not _layout.has(a) or not _layout.has(b):
		return
	var from: Vector2 = (_layout[a] as Dictionary).at
	var to: Vector2 = (_layout[b] as Dictionary).at
	var left := int(game.expedition.get("left", 3))
	var t := 0.3 if left >= 3 else (0.85 if left == 2 else 0.45)
	var returning := left < 2
	if not still:
		var phase := fmod(_anim_t / maxf(3.0, from.distance_to(to) / 34.0), 2.0)
		returning = phase > 1.0
		t = 2.0 - phase if returning else phase
	_route_dots(c, PackedVector2Array([from, to]), Color(col, 0.5))
	var at := from.lerp(to, t)
	var direction := (from - to).normalized() if returning else (to - from).normalized()
	_draw_squad_token(c, game, at, str(game.player), int(game.squads[game.player].size), "expedition_walk", direction, t * from.distance_to(to))


## Paint accepted squad poses with a faction-coloured circular count at their upper right.
func _draw_squad_token(c: CanvasItem, game, at: Vector2, fid: String, size_n: int, kind: String = "squad_stand", direction: Vector2 = Vector2.RIGHT, distance: float = 0.0, compact: bool = false) -> void:
	var height := _unit_height()
	var col := _faction_color(game, fid)
	if compact:
		c.draw_circle(at, 15, TAG_INK)
		c.draw_circle(at, 13, col)
		var text := str(size_n)
		var pos := at + Vector2(-_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 4.5)
		c.draw_string_outline(_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, TAG_INK)
		c.draw_string(_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TAG_PAPER)
		return
	var painted := false
	if height >= 30 and _sprites.frames.has(kind):
		c.draw_texture_rect(_sprites.shadow, Rect2(at - Vector2(height * 0.5, height * 0.08), Vector2(height, height * 0.2)), false, Color(1, 1, 1, 0.7))
		painted = _sprites.paint(("expedition_" if kind == "expedition_walk" else "squad_") + fid, kind, at, direction, col, height, distance, _anim_t, _motion_off(), kind == "squad_stand")
	if not painted:
		_draw_unit_disc(c, at, col, "squad")
	_draw_squad_badge(c, _squad_badge_at(at, size_n, painted), size_n, col)

## Grow the circular badge for large counts without shrinking its text.
func _squad_badge_radius(size_n: int) -> float:
	return maxf(12.0, _font().get_string_size(str(size_n), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5 + 5.0)

## Reserve both the standing group and its upper-right badge when choosing a station bay.
func _squad_footprint(size_n: int) -> Rect2:
	var height := _unit_height()
	var width := _unit_width("squad_stand")
	var group := Rect2(Vector2(-width * 0.6, -height * 1.05), Vector2(width * 1.2, height * 1.2))
	var radius := _squad_badge_radius(size_n) + 2.0
	var badge := Vector2(width * 0.5, -height * 0.8)
	return group.merge(Rect2(badge - Vector2.ONE * radius, Vector2.ONE * radius * 2))

## Keep the upper-right badge off every tag, including while a walking group crosses a label.
func _squad_badge_at(at: Vector2, size_n: int, painted: bool = true) -> Vector2:
	var radius := _squad_badge_radius(size_n) + 2.0
	var offset := Vector2(_unit_width("squad_stand") * 0.5, -_unit_height() * 0.8) if painted else Vector2(14, -14)
	for step in 128:
		var candidate := at + offset + Vector2(0, -step * (radius * 2.0 + 4.0))
		var box := Rect2(candidate - Vector2.ONE * radius, Vector2.ONE * radius * 2).grow(2)
		var clear := true
		for tag in _tags.values():
			if box.intersects(tag):
				clear = false
				break
		if clear:
			return candidate
	return at + offset + Vector2(0, -128.0 * (radius * 2.0 + 4.0))

## Put readable count text on a faction-coloured circle instead of covering station labels with paper.
func _draw_squad_badge(c: CanvasItem, at: Vector2, size_n: int, col: Color) -> void:
	var font := _font()
	var text := str(size_n)
	var radius := _squad_badge_radius(size_n)
	c.draw_circle(at, radius + 2, TAG_INK)
	c.draw_circle(at, radius, col)
	var text_at := at + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 4.5)
	c.draw_string_outline(font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, TAG_INK)
	c.draw_string(font, text_at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TAG_PAPER)


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
			_wheel_zoom(button.position, 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_wheel_zoom(button.position, 1.0 / 1.12)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed and button.double_click:
				var aimed := _station_at(button.position)
				var game = _game()
				if aimed != "" and game != null and game.stations.has(aimed):
					_glide_to(_station_world(game.stations[aimed]))
				accept_event()
			elif button.pressed:
				var chip := _chip_at(button.position)
				var hit := _station_at(button.position)
				if chip != "" and hit == "":
					open_focus_menu(chip, button.position)
				elif hit != "":
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
		var chip := _chip_at(motion.position) if hit == "" else ""
		if hit != _hover or chip != _chip_hover:
			_hover = hit
			_chip_hover = chip
			_redraw()
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit != "" or chip != "" else Control.CURSOR_ARROW
		tooltip_text = Copy.t("Choose what this station sends home.") if chip != "" else _tip(hit)
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


## A wheel step: eases there over a few frames, steps stacking while the wheel turns.
func _wheel_zoom(screen_at: Vector2, factor: float) -> void:
	if _motion_off():
		_zoom_at(screen_at, factor)
		return
	var from := _zoom_goal if _zoom_goal > 0.0 else zoom
	_zoom_goal = clampf(from * factor, _zoom_min, _zoom_max)
	_zoom_anchor = screen_at


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
	var lines: PackedStringArray = [game.station_text(sid, "community")]
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
		var now := str(sq.station)
		if not game.stations.has(now):
			continue
		var prev := str(_squad_seen.get(str(fid), ""))
		_squad_seen[str(fid)] = now
		if prev == "" or prev == now or _motion_off() or not game.stations.has(prev):
			continue
		var route: Array = game.walk_route(prev, now)
		var shown := route.size() >= 2
		for hop in route:
			if _secret(game.stations[str(hop)]):
				shown = false
				break
		if shown:
			_walks[str(fid)] = {"route": route, "t": 0.0, "dur": minf(WALK_MAX, WALK_PER_HOP * float(route.size() - 1))}


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
	_council_body.add_theme_constant_override("separation", 10)
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
	_paper_clip(photo, Vector2(24, -10), 30.0)


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
		var w := clampf(size.x * 0.22, 300.0, 400.0)
		var right := 30.0
		if host != null and host.get("side") != null and host.side.visible:
			right = maxf(right, host.side.size.x + 10.0)
		sheet.offset_left = size.x - w - right
		sheet.offset_top = top + 4.0
		sheet.offset_right = size.x - right
		sheet.offset_bottom = size.y - 120.0
	if council != null:
		council.offset_left = FIT_PAD
		council.offset_top = top
		council.offset_right = FIT_PAD + COUNCIL_W
		council.offset_bottom = top + 10.0
	if _zoom_bar != null:
		_zoom_bar.reset_size()
		_zoom_bar.position = Vector2(FIT_PAD + 4.0, _chrome_top() - _zoom_bar.size.y)


## Just above the station's bottom buttons.
func _chrome_top() -> float:
	var bottom := size.y - FIT_PAD
	if host != null and host.get("chrome_bottom") != null:
		bottom = minf(bottom, size.y - float(host.chrome_bottom) - 6.0)
	return bottom


func _build_zoom_bar() -> void:
	_zoom_bar = HBoxContainer.new()
	_zoom_bar.add_theme_constant_override("separation", 6)
	_zoom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["out", "in", "fit", "map", "land"]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(44, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 22 if key in ["out", "in"] else 16)
		if key == "land":
			button.toggle_mode = true
			button.button_pressed = territories
		for state in ["normal", "hover", "pressed"]:
			var face := StyleBoxFlat.new()
			face.bg_color = TAG_PAPER.darkened(0.12 if state == "pressed" else 0.0).lightened(0.06 if state == "hover" else 0.0)
			face.border_color = Color(TAG_INK, 0.85)
			face.set_border_width_all(1)
			face.set_content_margin_all(6)
			face.content_margin_left = 12
			face.content_margin_right = 12
			face.shadow_color = Color(0, 0, 0, 0.35)
			face.shadow_size = 3
			face.shadow_offset = Vector2(1, 2)
			button.add_theme_stylebox_override(state, face)
		for colour in ["font_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(colour, TAG_INK)
		button.pressed.connect(_zoom_button.bind(key))
		_zoom_bar.add_child(button)
		_zoom_buttons[key] = button
	add_child(_zoom_bar)
	_name_zoom_bar()


func _name_zoom_bar() -> void:
	if _zoom_bar == null:
		return
	_zoom_buttons.out.text = "-"
	_zoom_buttons.out.tooltip_text = Copy.t("Zoom out")
	_zoom_buttons["in"].text = "+"
	_zoom_buttons["in"].tooltip_text = Copy.t("Zoom in")
	_zoom_buttons.fit.text = Copy.t("Whole map")
	_zoom_buttons.fit.tooltip_text = Copy.t("Show the whole network")
	_zoom_buttons.map.text = Copy.t("Real map") if schematic else Copy.t("Schematic")
	_zoom_buttons.map.tooltip_text = Copy.t("Show the painted map of New York.") if schematic else Copy.t("Show the schematic of the lines.")
	_zoom_buttons.land.text = Copy.t("Territories")
	_zoom_buttons.land.tooltip_text = Copy.t("Colour each faction's land on the map.")
	if _tag_font != null:
		_zoom_buttons.fit.add_theme_font_override("font", _tag_font)
		_zoom_buttons.map.add_theme_font_override("font", _tag_font)
		_zoom_buttons.land.add_theme_font_override("font", _tag_font)


func set_territories(on: bool) -> void:
	territories = on
	if _zoom_buttons.has("land"):
		_zoom_buttons.land.set_pressed_no_signal(on)
	_redraw()


func _zoom_button(key: String) -> void:
	if host != null and host.has_method("_ui_click"):
		host._ui_click()
	if key == "land":
		set_territories(_zoom_buttons.land.button_pressed)
		return
	if key == "map":
		set_schematic(not schematic)
		return
	if key == "fit":
		_fit()
		return
	_zoom_at(_open_area().get_center(), ZOOM_STEP if key == "in" else 1.0 / ZOOM_STEP)


func _toggle_council() -> void:
	if host != null and host.has_method("_ui_click"):
		host._ui_click()
	council_open = not council_open
	_fill_council()
	_place_panels()
	_redraw()


func _fill_council() -> void:
	if _council_body == null:
		return
	for child in _council_body.get_children():
		child.queue_free()
	var game = _game()
	if game == null:
		return
	var fold := Button.new()
	fold.text = ("- " if council_open else "+ ") + Copy.t("Council")
	fold.focus_mode = Control.FOCUS_NONE
	fold.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fold.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = TAG_PAPER.darkened(0.12 if state == "pressed" else 0.0).lightened(0.06 if state == "hover" else 0.0)
		face.border_color = Color(TAG_INK, 0.85)
		face.set_border_width_all(1)
		face.set_content_margin_all(6)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.shadow_color = Color(0, 0, 0, 0.35)
		face.shadow_size = 3
		face.shadow_offset = Vector2(1, 2)
		fold.add_theme_stylebox_override(state, face)
	for colour in ["font_color", "font_hover_color", "font_pressed_color"]:
		fold.add_theme_color_override(colour, TAG_INK)
	fold.pressed.connect(_toggle_council)
	_council_body.add_child(fold)
	if not council_open:
		return
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
		face.set_content_margin_all(5)
		face.content_margin_top = 12
		face.shadow_color = Color(0, 0, 0, 0.5)
		face.shadow_size = 6
		face.shadow_offset = Vector2(3, 4)
		photo.add_theme_stylebox_override("panel", face)
		photo.rotation_degrees = float(tilts[index % tilts.size()])
		photo.resized.connect(func(): photo.pivot_offset = photo.size * 0.5)
		photo.draw.connect(_dress_photo.bind(photo))
		index += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		if host != null and host.has_method("_portrait_box"):
			row.add_child(host._portrait_box(str(seat.id), 40))
		var text := "%s\n%s" % [Copy.t(role.capitalize()), Copy.person(str(person.get("name", "")))]
		if used != "":
			text += "\n" + Copy.t("Council order") + ": " + Copy.t(_order_title(used))
		else:
			text += "\n" + Copy.t("Open seat")
		var seat_label := _lab(text, 13, false)
		seat_label.custom_minimum_size = Vector2(130, 40)
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
	## The way back sits at the top, so the player never has to scroll the sheet to close it.
	var back := Button.new()
	back.text = Copy.t("Back to the map")
	back.pressed.connect(close_sheet)
	_sheet_body.add_child(back)
	var game = _game()
	if game == null or not game.stations.has(sid):
		return
	var st: Dictionary = game.stations[sid]
	var own := str(st.owner) == str(game.player)
	_sheet_body.add_child(_station_photo(game, st))
	var title := _lab(game.station_text(sid, "community"), 20, true)
	var fid := station_faction(game, sid)
	var mark := _symbol(game, fid)
	if mark == null:
		_sheet_body.add_child(title)
	else:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(_symbol_rect(mark, 26, _paper_tint(fid)))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		_sheet_body.add_child(head)
	_sheet_body.add_child(_lab(Copy.t(str(st.name)), 14, false))
	var known := _known_for(game, sid)
	if known != "":
		_sheet_body.add_child(_lab(known, 14, false))
	var details := _details_box()
	if own:
		_add_own_facts(game, st, sid, _sheet_body, details)
	else:
		_sheet_body.add_child(_standing_row(game, st, sid))
		var who: String = game.station_text(sid, "who")
		if who != "":
			details.add_child(_lab(who, 14, false))
		var conflict: String = game.station_text(sid, "conflict")
		if conflict != "":
			details.add_child(_lab(conflict, 14, false))
		details.add_child(_lab("%s: %s" % [Copy.t("Owner"), Copy.t(_owner_name(game, str(st.owner)))], 14, false))
		details.add_child(_lab("%s: %s" % [Copy.t("Loyalty"), str(int(st.loyalty))], 14, false))
		if int(st.unrest) > 0:
			details.add_child(_lab("%s: %s" % [Copy.t("Unrest"), str(int(st.unrest))], 14, false))
		_add_needs(st, details)
		var art: String = game.station_text(sid, "art")
		if art != "":
			details.add_child(_lab(art, 13, false))
		var trade := _trade_line(st)
		if trade != "":
			details.add_child(_lab(trade, 14, false))
	_add_actions(sid, own, _sheet_body, details)
	_add_fold(_sheet_body, details)


## Orders aimed at a bunker rather than the station on the sheet; a locked one says why on its face.
const APPROACHES := ["approach", "approach_quarantine", "approach_observatory"]
## Orders a card shows above its "Details" fold; the rest wait behind it.
const CARD_ORDERS := 4
var _details_open := false


func _order_button(kind: String, label: String, sid: String, parent: Node = null, notes: Node = null) -> void:
	if parent == null:
		parent = _sheet_body
	if notes == null:
		notes = parent
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
	var tex := ArtPack.icon_texture(_order_icon(kind), 24.0)
	if tex != null:
		var face := TextureRect.new()
		face.texture = tex
		face.custom_minimum_size = Vector2(24, 24)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
	var why := ""
	var caption := Label.new()
	caption.text = Copy.t(label)
	if game != null:
		why = game.order_block(kind, sid)
	if why != "" and APPROACHES.has(kind):
		caption.text = "%s\n%s" % [Copy.t(label), why]
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Color("efe6d2"))
	row.add_child(caption)
	if game != null and not (why != "" and APPROACHES.has(kind)):
		row.add_child(_cost_tag(game.order_cost(kind, sid)))
	button.custom_minimum_size = Vector2(0, 36)
	button.add_child(row)
	button.disabled = why != ""
	if button.disabled:
		var locked := StyleBoxFlat.new()
		locked.bg_color = Color(0.24, 0.16, 0.08, 0.7)
		locked.set_content_margin_all(4)
		button.add_theme_stylebox_override("disabled", locked)
	if game != null:
		button.tooltip_text = _order_tip(game, kind, sid, why)
	button.set_meta("order_kind", kind)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if why == "":
		button.pressed.connect(_issue.bind(kind, sid))
	button.custom_minimum_size = Vector2(0, 76 if why != "" and APPROACHES.has(kind) else 40)
	button.set_meta("order_caption", caption)
	button.set_meta("base_height", button.custom_minimum_size.y)
	caption.resized.connect(_fit_order_button.bind(button, caption))
	parent.add_child(button)
	if game != null and why == "":
		var effect: String = game.order_risk(kind, sid)
		if effect != "":
			var line := _lab(effect if notes == parent else "%s: %s" % [Copy.t(label), effect], 13, false)
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.set_meta("effect_line", true)
			notes.add_child(line)


## An order's price at the right of its button: a number and the resource's icon per cost, or "No cost".
func _cost_tag(cost: Dictionary) -> HBoxContainer:
	var tag := HBoxContainer.new()
	tag.add_theme_constant_override("separation", 3)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.set_meta("order_cost", _cost_text(cost))
	if cost.is_empty():
		var free := Label.new()
		free.text = Copy.t("No cost")
		free.add_theme_font_size_override("font_size", 13)
		free.add_theme_color_override("font_color", Color("b9ad96"))
		free.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(free)
		return tag
	for key in cost:
		var amount := Label.new()
		amount.text = str(int(cost[key]))
		amount.add_theme_color_override("font_color", Color("efe6d2"))
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(amount)
		var tex := ArtPack.icon_texture(str(key), 24.0)
		if tex == null:
			amount.text = "%d %s" % [int(cost[key]), Copy.res(str(key))]
			continue
		var face := TextureRect.new()
		face.texture = tex
		face.custom_minimum_size = Vector2(18, 18)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(face)
	return tag


## The button grows with its wrapped caption, so the second line (cost, envoy, dawn) is never cut.
func _fit_order_button(button: Button, caption: Label) -> void:
	if caption.size.x < 80.0:
		return
	var lines := maxi(caption.get_line_count(), 1)
	var tall := float(lines * (caption.get_line_height() + caption.get_theme_constant("line_spacing"))) + 14.0
	var want := maxf(float(button.get_meta("base_height", 52.0)), tall)
	if absf(want - button.custom_minimum_size.y) > 0.5:
		button.custom_minimum_size.y = want


func _order_tip(game, kind: String, sid: String, why: String) -> String:
	var cost: Dictionary = game.order_cost(kind, sid)
	if why != "":
		if why.begins_with(Copy.t("Not enough influence.")):
			var need := int(cost.get("influence", 4))
			var tip := Copy.t("Not enough influence: need %d, have %d.") % [need, int(game.stock.get("influence", 0))]
			if game.room_count("meeting_hall") == 0:
				tip += " " + Copy.t("A meeting hall makes it.")
			return tip
		return why
	var who: Dictionary = game.order_councillor()
	var lines: PackedStringArray = []
	lines.append("%s: %s" % [Copy.t("Cost"), _cost_text(cost)])
	lines.append("%s: %s" % [Copy.t("Goes"), Copy.person(str(who.get("name", "")))])
	lines.append("%s: %s" % [Copy.t("Result"), Copy.t("Next dawn")])
	var risk: String = game.order_risk(kind, sid)
	if risk != "":
		lines.append("%s: %s" % [Copy.t("Risk"), risk])
	return "\n".join(lines)


func _issue(kind: String, sid: String) -> void:
	var game = _game()
	if game == null:
		return
	if kind.begins_with("focus:"):
		var focus := kind.trim_prefix("focus:")
		if game.set_outpost_focus(sid, focus):
			if host != null and host.has_method("_toast"):
				var place := str(game.station_text(sid, "community"))
				host._toast(Copy.t("%s will send %s home.") % [place, Copy.t(_focus_word(focus))])
			refresh()
			if visit != null and visit.visible:
				_fill_visit(sid)
			else:
				_fill_sheet(sid)
		return
	var action := {"kind": "order", "order": kind}
	if kind == "move":
		action["dest"] = sid
	elif APPROACHES.has(kind) or kind == "expedition":
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
			host._toast(_order_toast(game, kind, sid))
		refresh()
		if visit != null and visit.visible:
			_fill_visit(sid)
		else:
			_fill_sheet(sid)


## The one-line toast when an order queues (P22): the soft orders name the station and the change they expect, the
## rest keep the plain line. Previews come from the sim; the toast never works out numbers itself.
func _order_toast(game, kind: String, sid: String) -> String:
	var place := Copy.t(str(game.stations[sid].name)) if game.stations.has(sid) else ""
	var line := Copy.t("Order sent. The result comes at next dawn.")
	match kind:
		"propaganda":
			line = Copy.t("Propaganda → %s · Sympathy ~+%d") % [place, int(game.propaganda_gain(sid))]
		"envoy":
			var envoy: Dictionary = game.envoy_preview(sid)
			line = Copy.t("Envoy → %s · Sympathy ~+%d, %s improves") % [place, int(envoy.gain), Copy.t(str(envoy.need_id)).to_lower()]
		"trade":
			if sid != "":
				line = Copy.t("Deal → %s · Deal %d/3, passage opens") % [place, int(game.deal_next(sid))]
	if line.length() > 72:
		line = line.left(71) + "…"
	return line


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
			return "Strike a deal"
		"expedition":
			return "Start expedition"
		"approach":
			return "Approach the Floor"
		"approach_observatory":
			return "Approach the Observatory"
		"approach_quarantine":
			return "Approach the Quarantine"
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


## "Known for: food, materials": a station's two biggest own goods (data, docs/STATION_GOODS_PLAN.md). Empty for the
## capital, bunkers and ruins, which ship nothing.
func _known_for(game, sid: String) -> String:
	var st: Dictionary = game.stations.get(sid, {})
	if st.is_empty() or sid == str(game.capital_id) or str(st.owner) in ["bunker", "ruin"] or str(st.get("bunker", "")) != "":
		return ""
	var goods: Dictionary = game.catalog.station_goods(sid)
	var keys: Array = goods.keys()
	keys.sort_custom(func(a, b): return int(goods[a]) > int(goods[b]) or (int(goods[a]) == int(goods[b]) and YIELD_KEYS.find(a) < YIELD_KEYS.find(b)))
	var words: PackedStringArray = []
	for key in keys.slice(0, 2):
		words.append(Copy.res(str(key)))
	return "%s: %s" % [Copy.t("Known for"), ", ".join(words)]


func _trade_line(st: Dictionary) -> String:
	var goods: PackedStringArray = []
	for need in st.get("needs", []):
		goods.append(Copy.t(str(need.id)))
	## The deal count lives in the Relation block's pips now (P22).
	if goods.is_empty():
		return ""
	return "%s: %s" % [Copy.t("They trade"), ", ".join(goods)]


func _add_own_facts(game, st: Dictionary, sid: String, parent: Node, details: Node) -> void:
	parent.add_child(_lab("%s: %d" % [Copy.t("Population"), int(st.pop)], 14, false))
	parent.add_child(_lab("%s: %d" % [Copy.t("Loyalty"), int(st.loyalty)], 14, false))
	parent.add_child(_lab("%s: %d" % [Copy.t("Garrison"), int(st.garrison)], 14, false))
	if str(sid) != str(game.capital_id):
		parent.add_child(_lab("%s: %s" % [Copy.t("Sends home"), Copy.t(_focus_word(str(st.get("focus", "food"))))], 14, false))
		_add_governor(game, st, str(sid), parent)
	parent.add_child(_lab(_supply_text(game, sid), 14, false))
	parent.add_child(_lab(_ships_text(game, st, sid), 14, false))
	_add_needs(st, details)


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
	var flow: Dictionary = game.outpost_yield(str(sid))
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


func _add_actions(sid: String, own: bool, parent: Node, details: Node, with_visit: bool = true) -> void:
	var game_now = _game()
	var home: bool = game_now != null and str(sid) == str(game_now.capital_id)
	if with_visit:
		var open_b := Button.new()
		open_b.text = Copy.t("Back to your station") if home else Copy.t("Visit station")
		open_b.tooltip_text = Copy.t("Close the map and return to your own station.") if home else Copy.t("See the station up close: its people, leader and needs. Spends nothing.")
		open_b.set_meta("visit_station", sid)
		open_b.pressed.connect(_open_station.bind(sid))
		parent.add_child(open_b)
	if game_now == null:
		return
	if home:
		_add_guard(game_now, parent)
	parent.add_child(_dawn_line(game_now))
	## Open orders first; the card fills up with closed ones, greyed with the reason under them, so it never shows
	## an empty card when nothing can be sent this week.
	var shown := 0
	var later: Array = []
	var closed: Array = []
	for row in order_rows(game_now, own, sid):
		var kind := str(row[0])
		if APPROACHES.has(kind):
			later.append(row)
		elif shown < CARD_ORDERS and game_now.order_block(kind, sid) == "":
			_order_button(kind, str(row[1]), sid, parent, details)
			shown += 1
		else:
			closed.append(row)
	for row in closed:
		if shown < CARD_ORDERS:
			_order_button(str(row[0]), str(row[1]), sid, parent, details)
			var why := _lab(str(game_now.order_block(str(row[0]), sid)), 12, false)
			why.add_theme_color_override("font_color", CARD_MUTED if _on_paper else MUTED)
			why.set_meta("closed_reason", str(row[0]))
			parent.add_child(why)
			shown += 1
		else:
			later.append(row)
	for row in later:
		_order_button(str(row[0]), str(row[1]), sid, details, details)


## The guard on the home card: how many soldiers, and buttons to take a resident into it or send one back.
## Soldiers come from your own people, so every recruit is a worker less.
func _add_guard(game, parent: Node) -> void:
	var n: int = game.soldier_count()
	var line := _lab(Copy.t("Guard: %s (marches need %d).") % [Words.count(n, "soldier"), int(game.bal.guard.move_min)], 14, false)
	line.set_meta("guard_line", true)
	parent.add_child(line)
	var names: PackedStringArray = []
	for id in game.soldier_ids():
		if game.people.has(str(id)):
			names.append(Copy.person(str(game.people[str(id)].name)))
	if not names.is_empty():
		var who := _lab(Copy.t("On the gate: %s.") % ", ".join(names), 13, false)
		who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(who)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var recruit := Button.new()
	var price := int(game.bal.guard.recruit_materials)
	recruit.text = Copy.t("Recruit soldier") if price == 0 else "%s  −%d %s" % [Copy.t("Recruit soldier"), price, Copy.res("materials")]
	recruit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var why: String = game.recruit_block()
	recruit.disabled = why != ""
	recruit.tooltip_text = why if why != "" else Copy.t("%s leaves their work and joins the guard.") % str(game.recruit_preview())
	recruit.pressed.connect(_guard_action.bind("recruit"))
	row.add_child(recruit)
	var dismiss := Button.new()
	dismiss.text = Copy.t("Release")
	var why_d: String = game.dismiss_block()
	dismiss.disabled = why_d != ""
	dismiss.tooltip_text = why_d if why_d != "" else Copy.t("One soldier goes back to work.")
	dismiss.pressed.connect(_guard_action.bind("dismiss"))
	row.add_child(dismiss)


func _guard_action(kind: String) -> void:
	var game = _game()
	if game == null or not game.apply({"kind": kind}):
		return
	if host != null and host.has_method("_refresh"):
		host._refresh()
	if kind == "recruit" and host != null and host.has_method("note_spend"):
		host.note_spend({"materials": int(game.bal.guard.recruit_materials)})


## Every order a station's card offers, in card order: [kind, label].
const FOCUS_WORD := {"food": "Food", "air": "Air", "defense": "Defense", "influence": "Influence"}


func _focus_word(focus: String) -> String:
	return str(FOCUS_WORD.get(focus, "Food"))


func order_rows(game, own: bool, sid: String = "") -> Array:
	if own:
		var rows: Array = []
		if sid != "" and sid != str(game.capital_id):
			rows.append(["focus:food", "Send food home"])
			rows.append(["focus:air", "Send air home"])
			rows.append(["focus:defense", "Fortify"])
			rows.append(["focus:influence", "Spread our name"])
		rows.append(["move", "Garrison"])
		return rows
	var rows := [["envoy", "Send envoy"], ["propaganda", "Propaganda"], ["move", "Move squad"], ["trade", "Strike a deal"], ["expedition", "Start expedition"]]
	if not game.floor_met:
		rows.append(["approach", "Approach the Floor"])
	if not game._scene_used("st3_quarantine"):
		rows.append(["approach_quarantine", "Approach the Quarantine"])
	if not game._scene_used("st3_observatory"):
		rows.append(["approach_observatory", "Approach the Observatory"])
	return rows


## Who carries the orders and when they land, said once above the buttons.
func _dawn_line(game) -> Label:
	var who: Dictionary = game.order_councillor()
	var who_name := Copy.person(str(who.get("name", "")))
	if who.is_empty():
		who_name = Copy.t("No councillor is free.")
	var line := _lab("%s: %s · %s: %s" % [Copy.t("Goes"), who_name, Copy.t("Result"), Copy.t("Next dawn")], 13, false)
	line.set_meta("dawn_line", true)
	return line


## The box behind the "Details" fold; _add_fold puts it on the card, closed unless the player opened it.
func _details_box() -> VBoxContainer:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.visible = _details_open
	body.set_meta("station_details", true)
	return body


func _add_fold(parent: Node, body: VBoxContainer) -> void:
	if body.get_child_count() == 0:
		body.free()
		return
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = _details_open
	toggle.text = Copy.t("Details")
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.custom_minimum_size = Vector2(0, 32)
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.set_meta("details_toggle", true)
	toggle.toggled.connect(func(on: bool):
		_details_open = on
		body.visible = on)
	parent.add_child(toggle)
	parent.add_child(body)


## Opinion number and bar, then up to three state marks from existing data.
## The standing block under a station's name: the holding faction's opinion and the state marks on one row, then,
## for a station you court, its Relation (sympathy) as a band-coloured bar, deal pips and the passage line (P22).
func _standing_row(game, st: Dictionary, sid: String) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	block.add_child(_opinion_row(game, st, sid))
	if _courted(game, st):
		_add_relation(game, st, block)
	return block


func _add_relation(game, st: Dictionary, parent: Node) -> void:
	var sympathy := clampi(int(st.get("sympathy", 0)), 0, 100)
	var band := _sympathy_band(game, sympathy)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var label := _lab(Copy.t("Relation"), 13, false)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(label)
	var word := _lab(Copy.t(_sympathy_word(sympathy)), 14, true)
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.add_theme_color_override("font_color", band.darkened(0.25) if _on_paper else band)
	word.set_meta("relation_band", _sympathy_word(sympathy))
	head.add_child(word)
	parent.add_child(head)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = sympathy
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color("2b2118", 0.28)
	track.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = band
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta("relation_bar", sympathy)
	line.add_child(bar)
	var num := _lab(str(sympathy), 13, false)
	num.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(num)
	parent.add_child(line)
	var deals := clampi(int(st.get("deals", 0)), 0, 3)
	if deals > 0:
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 4)
		var count := _lab(Copy.t("Deals %d/3") % deals, 14, false)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		pips.add_child(count)
		for i in 3:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(8, 8)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var dot := StyleBoxFlat.new()
			dot.set_corner_radius_all(4)
			if i < deals:
				dot.bg_color = Color("e2a63a")
			else:
				dot.bg_color = Color(0, 0, 0, 0)
				dot.border_color = Color(GRAPHITE, 0.5)
				dot.set_border_width_all(1)
			pip.add_theme_stylebox_override("panel", dot)
			pips.add_child(pip)
		pips.set_meta("deal_pips", deals)
		parent.add_child(pips)
	if bool(st.get("passage", false)):
		var open := _lab(Copy.t("Tunnel open to the yard."), 15, false)
		open.add_theme_color_override("font_color", Color("a8761c") if _on_paper else Color("e2a63a"))
		open.set_meta("passage_line", true)
		parent.add_child(open)


func _opinion_row(game, st: Dictionary, sid: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if not game.opinions.has(str(st.owner)):
		## Sympathy reads in the Relation block below; this row only carries the state marks.
		_add_state_marks(game, st, sid, row)
		return row
	var relation := int(game.opinions[str(st.owner)])
	var low := -100.0
	var words := _lab("%s: %d" % [Copy.t("Opinion"), relation], 15, true)
	words.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	var bar := ProgressBar.new()
	bar.min_value = low
	bar.max_value = 100
	bar.value = clampf(relation, low, 100.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0, 0, 0, 0.18 if _on_paper else 0.45)
	groove.border_color = Color(CARD_MUTED if _on_paper else MUTED, 0.6)
	groove.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", groove)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c4544a") if relation < 0 else (Color("e2a63a") if relation < 40 else Color("7dba6a"))
	bar.add_theme_stylebox_override("fill", fill)
	bar.set_meta("opinion_bar", relation)
	row.add_child(bar)
	_add_state_marks(game, st, sid, row)
	return row


func _add_state_marks(game, st: Dictionary, sid: String, row: HBoxContainer) -> void:
	for mark in state_marks(game, st, sid):
		var tex := ArtPack.icon_texture(str(mark[0]), 24.0)
		if tex == null:
			continue
		var face := TextureRect.new()
		face.texture = tex
		face.custom_minimum_size = Vector2(24, 24)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		face.tooltip_text = Copy.t(str(mark[1]))
		face.mouse_filter = Control.MOUSE_FILTER_PASS
		face.set_meta("state_mark", str(mark[1]))
		row.add_child(face)


## [icon, words] for: can trade, an expedition under way, hostile, pact. At most three.
func state_marks(game, st: Dictionary, sid: String) -> Array:
	var marks: Array = []
	if int(st.get("deals", 0)) > 0 or game.order_block("trade", sid) == "":
		marks.append(["trade", "Can trade"])
	if not game.expedition.is_empty():
		marks.append(["artifact", "Expedition under way"])
	var fid := station_faction(game, sid)
	var band: String = game.standing_band(fid) if game.standing.has(fid) else ""
	if str(st.owner) == "enemy" or band == "hostile":
		marks.append(["ultimatum", "Hostile"])
	elif band == "pact":
		marks.append(["envoy", "Pact"])
	return marks.slice(0, 3)


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
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0.03, 0.025, 0.02, 0.82)
	dim.content_margin_top = 8
	dim.content_margin_bottom = 8
	visit.add_theme_stylebox_override("panel", dim)
	visit_sheet = PanelContainer.new()
	visit_sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	visit_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 1.0)
	style.border_color = Color(0.36, 0.29, 0.2)
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	visit_sheet.add_theme_stylebox_override("panel", style)
	visit.add_child(visit_sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	visit_sheet.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_visit_title = _lab("", 20, true)
	_visit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visit_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_visit_title)
	visit_close = Button.new()
	visit_close.text = Copy.t("Back to map")
	visit_close.custom_minimum_size = Vector2(120, 36)
	visit_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	visit_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visit_close.tooltip_text = "Esc"
	visit_close.pressed.connect(close_visit)
	header.add_child(visit_close)
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_visit_body = VBoxContainer.new()
	_visit_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visit_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_visit_body)
	column.add_child(scroll)
	visit.resized.connect(_size_visit)
	add_child(visit)


func _size_visit() -> void:
	if visit_sheet != null:
		visit_sheet.custom_minimum_size.x = minf(VISIT_MAX_W, maxf(0.0, visit.size.x - 32.0))


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if visit != null and visit.is_visible_in_tree():
		close_visit()
		get_viewport().set_input_as_handled()


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
	_details_open = false
	visit.visible = true
	_size_visit()
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
	_visit_title.text = Copy.t(str(st.name))
	var hub := _hub_tex(game, st)
	if hub != null:
		var face := TextureRect.new()
		face.texture = hub
		face.custom_minimum_size = Vector2(0, 220)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		face.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		face.set_meta("visit_banner", true)
		if sid in PANORAMA_HUBS:
			face.stretch_mode = TextureRect.STRETCH_SCALE
			face.resized.connect(_crop_hub.bind(face, hub))
		else:
			face.resized.connect(_banner_height.bind(face, hub))
		_visit_body.add_child(face)
	else:
		var plate := _name_plate(Copy.t(str(st.name)), Vector2(0, 150), 34)
		plate.set_meta("visit_banner", true)
		_visit_body.add_child(plate)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	if host != null and host.has_method("_portrait_box"):
		head.add_child(host._portrait_box(str(sid), 64))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var named := HBoxContainer.new()
	named.add_theme_constant_override("separation", 10)
	var mark := _symbol(game, station_faction(game, sid))
	if mark != null:
		named.add_child(_symbol_rect(mark, 28))
	var community := _lab(game.station_text(sid, "community"), 22, true)
	community.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	named.add_child(community)
	column.add_child(named)
	column.add_child(_standing_row(game, st, sid))
	head.add_child(column)
	_visit_body.add_child(head)
	var details := _details_box()
	var who: String = game.station_text(sid, "who")
	var conflict: String = game.station_text(sid, "conflict")
	if conflict != "":
		details.add_child(_lab(conflict, 16, true))
	if who != "":
		details.add_child(_lab(who, 15, false))
	details.add_child(_lab("%s: %d" % [Copy.t("Loyalty"), int(st.loyalty)], 15, false))
	_add_needs(st, details)
	var trade := _trade_line(st)
	if trade != "":
		details.add_child(_lab(trade, 15, false))
	var art: String = game.station_text(sid, "art")
	if art != "":
		details.add_child(_lab(art, 14, false))
	_add_actions(sid, str(st.owner) == str(game.player), _visit_body, details, false)
	_add_fold(_visit_body, details)


## The picture keeps its own proportions at the sheet's width, cut no taller than banner_cap().
func _banner_height(face: TextureRect, hub: Texture2D) -> void:
	if face.size.x <= 0.0 or hub.get_width() <= 0:
		return
	face.custom_minimum_size.y = minf(face.size.x * float(hub.get_height()) / float(hub.get_width()), banner_cap())


## On a short window the banner leaves most of the sheet to the words and the orders.
func banner_cap() -> float:
	if visit == null or visit.size.y < 1.0:
		return HUB_MAX_H
	return minf(HUB_MAX_H, visit.size.y * 0.42)


## Cover-fit at full width, no taller than banner_cap(); the cut is shared around HUB_FOCUS_Y.
func _crop_hub(face: TextureRect, hub: Texture2D) -> void:
	if face.size.x <= 0.0:
		return
	var w := float(hub.get_width())
	var h := float(hub.get_height())
	var shown := minf(face.size.x * h / w, banner_cap())
	var region_h := minf(h, w * shown / face.size.x)
	var top := clampf(h * HUB_FOCUS_Y - region_h * 0.5, 0.0, h - region_h)
	var atlas := face.texture as AtlasTexture
	if atlas == null:
		atlas = AtlasTexture.new()
		atlas.atlas = hub
	atlas.region = Rect2(0.0, roundf(top), w, roundf(region_h))
	face.texture = atlas
	face.custom_minimum_size.y = shown


func _hub_tex(game, st: Dictionary) -> Texture2D:
	var path := banner_path(game, str(st.get("id", "")))
	return ArtPack.load_texture(path) if path != "" else null


## The picture a station shows: the capital's hub, the station's own hub art, else the room from BANNER_ROOMS;
## "" when nothing fits.
func banner_path(game, sid: String) -> String:
	var paths: PackedStringArray = []
	if sid == str(game.capital_id):
		paths.append("res://assets/hubs/hub_coney_island.webp")
	paths.append("res://assets/hubs/%s.webp" % sid)
	if BANNER_ROOMS.has(sid):
		paths.append("res://assets/rooms/room_%s.webp" % str(BANNER_ROOMS[sid]))
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	return ""


## A dark plate with the station's name in place of a picture.
func _name_plate(text: String, min_size: Vector2, px: int) -> PanelContainer:
	var plate := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = PLATE
	face.border_color = Color(0.55, 0.43, 0.24, 0.6)
	face.set_border_width_all(1)
	face.set_content_margin_all(12)
	plate.add_theme_stylebox_override("panel", face)
	plate.custom_minimum_size = min_size
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := _lab(text, px, true)
	name_label.add_theme_color_override("font_color", Color(MUTED, 0.75))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plate.add_child(name_label)
	return plate


## Small snapshot for the station sheet. Stations without their own art borrow a room picture.
func _station_photo(game, st: Dictionary) -> Control:
	var frame := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = Color("efe8d6")
	face.border_color = Color("c9bea4")
	face.set_border_width_all(1)
	face.set_content_margin_all(6)
	face.content_margin_bottom = 4
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 6
	face.shadow_offset = Vector2(2, 3)
	frame.add_theme_stylebox_override("panel", face)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.rotation_degrees = -1.6
	frame.resized.connect(func(): frame.pivot_offset = frame.size * 0.5)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	frame.add_child(box)
	var shot_size := Vector2(220, 110)
	var caption := ""
	if not _secret(st) and banner_path(game, str(st.get("id", ""))) == "":
		box.add_child(_name_plate(Copy.t(str(st.get("name", ""))), shot_size, 20))
		caption = Copy.t("No photo yet")
	elif _secret(st):
		var blank := ColorRect.new()
		blank.color = Color(0.18, 0.16, 0.14)
		blank.custom_minimum_size = shot_size
		var mark := Label.new()
		mark.text = "?"
		mark.add_theme_font_size_override("font_size", 48)
		mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		blank.add_child(mark)
		box.add_child(blank)
		caption = Copy.t("No photo yet")
	else:
		var shot := TextureRect.new()
		shot.custom_minimum_size = shot_size
		shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shot.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shot.clip_contents = true
		shot.texture = _thumb_tex(game, st)
		shot.modulate = Color(1.0, 0.94, 0.84)
		box.add_child(shot)
		caption = Copy.t(str(st.get("name", "")))
	var tag := Label.new()
	tag.text = caption
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", CARD_MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.clip_text = true
	tag.custom_minimum_size = Vector2(220, 0)
	box.add_child(tag)
	return frame


func _thumb_tex(game, st: Dictionary) -> Texture2D:
	return _hub_tex(game, st)


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

## Size in screen pixels keeps art readable at fit zoom and bounded when inspecting a station.
func _unit_height() -> float:
	return minf(76.0, 44.0 * zoom / maxf(0.001, _zoom_min))


## A compact owner disc stays crisp when there is too little space for a full miniature.
func _draw_unit_disc(c: CanvasItem, at: Vector2, col: Color, good: String) -> void:
	c.draw_circle(at + Vector2(1, 2), 9, Color(0, 0, 0, 0.3))
	c.draw_circle(at, 9, col)
	var icon: Texture2D = _sprites.icons.get(good)
	if icon != null:
		c.draw_texture_rect(icon, Rect2(at - Vector2(6, 6), Vector2(12, 12)), false)

## Integrate each real tunnel separately so a cart eases at intermediate stations as well as terminals.
func _unit_progress(pts: PackedVector2Array, time: float, speed: float) -> Vector3:
	var remaining := maxf(0.0, time)
	var distance := 0.0
	for i in pts.size() - 1:
		var length := pts[i].distance_to(pts[i + 1])
		var duration := length / speed + 0.45
		if remaining <= duration:
			return Vector3(distance + UnitSprites.travel(remaining, duration) * length, remaining, duration - remaining)
		remaining -= duration
		distance += length
	return Vector3(distance, 0, 0)

## Draw the static dotted routes with the map ink so motion redraws only the moving miniatures.
func _draw_unit_routes(c: CanvasItem, game) -> void:
	for row in _caravans:
		var pts := PackedVector2Array()
		for sid in row.route:
			if _layout.has(str(sid)):
				pts.append((_layout[str(sid)] as Dictionary).at)
		if pts.size() < 2:
			continue
		var col := TRADE_GOLD if str(row.kind) == "trade" else _faction_color(game, str(row.get("owner", game.player)))
		_route_dots(c, pts, Color(col, 0.4))

## Use the shared normalized canvas so spacing follows car size rather than changing crew silhouettes.
func _unit_width(kind: String = "handcar_pump") -> float:
	if _sprites.frames.has(kind):
		var texture: Texture2D = _sprites.frames[kind][0]
		return _unit_height() * texture.get_width() / texture.get_height()
	return _unit_height() * 1.16

## Keep the entire waiting miniature clear of pins, chip rows and placed name tags.
func _unit_bay_clear(at: Vector2, width: float, footprint: Rect2 = Rect2()) -> bool:
	var height := _unit_height()
	var box := Rect2(at - Vector2(width * 0.6, height * 1.05), Vector2(width * 1.2, height * 1.2)).grow(4.0)
	if footprint.has_area():
		box = Rect2(at + footprint.position, footprint.size).grow(4.0)
	for tag in _tags.values():
		if box.intersects(tag):
			return false
	for row in _yield_rows:
		if box.intersects(Rect2(float(row.x), float(row.y), float(row.total), 18.0)):
			return false
	for pin in _layout.values():
		if box.intersects(Rect2(Vector2(pin.at) - Vector2.ONE * float(pin.r), Vector2.ONE * float(pin.r) * 2.0)):
			return false
	return true

## Try both sides along the route, then search further out when nearby bays are occupied.
func _unit_station_bay(sid: String, direction: Vector2, width: float, slot: int, footprint: Rect2 = Rect2(), keep_visible: bool = false) -> Vector2:
	var pin: Dictionary = _layout[sid]
	var distance := float(pin.r) + width * (0.8 + slot * 1.6)
	for step in 128:
		for side in [1.0, -1.0]:
			var at: Vector2 = Vector2(pin.at) + direction * side * (distance + step * width * 0.5)
			if keep_visible and Rect2(Vector2.ZERO, size).has_point(pin.at):
				if not Rect2(Vector2(4, 4), size - Vector2(8, 8)).encloses(Rect2(at + footprint.position, footprint.size).grow(4)):
					continue
			if _unit_bay_clear(at, width, footprint):
				return at
	return Vector2(pin.at) + direction * (distance + 128.0 * width)

## Join the tunnel to station-side parking bays so arrival and departure never jump onto a pin.
func _unit_route_bays(points: PackedVector2Array, first: String, last: String, kind: String = "handcar_pump") -> PackedVector2Array:
	if points.size() < 2:
		return points
	var start_dir := (points[1] - points[0]).normalized()
	var end_dir := (points[-1] - points[-2]).normalized()
	var out := PackedVector2Array([_unit_station_bay(first, start_dir, _unit_width(kind), 0)])
	for i in range(1, points.size() - 1):
		out.append(points[i])
	out.append(_unit_station_bay(last, -end_dir, _unit_width(kind), 0))
	return out
