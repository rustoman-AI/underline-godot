extends SceneTree

## Map size measurements and screenshots, one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/map_size_shots.gd -- --lang=ru --size=1920x1080 --tag=after
## Prints FILL lines (network box and paper against the free area, side panels against the width, tag sizes,
## the station view against its content area) and saves to shots/map_size/<tag>/<lang>_<WxH>/:
## the network map at opening, zoomed in on a station, with a station sheet open, and the station view.
## Settings, saves and logs go to user://map_size_shots, not the player's.

const SCRATCH := "user://map_size_shots"

var st
var size := Vector2i(1280, 720)
var tag := "after"
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
		if str(arg).begins_with("--tag="):
			tag = str(arg).trim_prefix("--tag=")
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
	out = "map_size/%s/%s_%dx%d" % [tag, Copy.lang, size.x, size.y]
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
	st.yard.fit()
	await _shot("station_view")
	_yard_fill()

	st._toggle_network()
	await st._frame()
	var net = st.network_view
	net._fit()
	st._place_chrome()
	await _shot("network_open")
	_net_fill(net)
	_tag_count(net, "opening")

	for ratio in [1.7, 2.7]:
		net.show_zoom(ratio, str(st.game.capital_id))
		await st._frame()
		await st._frame()
		_tag_count(net, "zoom x%.1f" % ratio)
	net._fit()
	await st._frame()

	var sid: String = net.first_known_neighbor()
	if sid == "":
		sid = str(st.game.capital_id)
	net.open_sheet(sid)
	await _shot("network_sheet")
	var sheet_box: Rect2 = net.sheet.get_global_rect()
	var view := Rect2(Vector2.ZERO, st.size)
	print("FILL %s sheet %d px = %.0f%% of width, inside %s, scroll %s" % [_key(), int(net.sheet.size.x), 100.0 * net.sheet.size.x / st.size.x,
		"yes" if view.grow(8.0).encloses(sheet_box) else "NO", "yes" if _scrolls(net.sheet) else "no"])
	net.close_sheet()

	net.origin = net._station_world(st.game.stations[sid])
	net.zoom = net._zoom_max
	net._clamp_view()
	net._redraw()
	await _shot("network_zoomed")
	_zoom_reach(net, sid)
	quit(0)


func _key() -> String:
	return "%s %dx%d" % [Copy.lang, size.x, size.y]


func _net_fill(net) -> void:
	var area: Rect2 = net._open_area()
	var paper: Rect2 = _screen_box(net, net._map_box())
	var spots := Rect2()
	var first := true
	for sid in net._spots:
		var at: Vector2 = net._screen(net._map_xf * net._map_spot(str(sid)))
		if first:
			spots = Rect2(at, Vector2.ZERO)
			first = false
		else:
			spots = spots.expand(at)
	var council_w: float = net.council.size.x + net.council.offset_left
	var level: int = net._tag_level()
	var drawn: int = net._tags.size()
	var known := 0
	for s in net._layout:
		if bool(net._layout[s].known):
			known += 1
	print("FILL %s area %s zoom %.3f..%.3f" % [_key(), area, net.zoom, net._zoom_max])
	print("FILL %s paper w %.0f%% h %.0f%% | stations w %.0f%% h %.0f%% | limiting %.0f%%" % [_key(),
		100.0 * paper.size.x / area.size.x, 100.0 * paper.size.y / area.size.y,
		100.0 * spots.size.x / area.size.x, 100.0 * spots.size.y / area.size.y,
		100.0 * maxf(spots.size.x / area.size.x, spots.size.y / area.size.y)])
	print("FILL %s council %.0f%% of width | tags level %d font %d, drawn %d of %d known" % [_key(),
		100.0 * council_w / st.size.x, level, 14 if level < 2 else 15, drawn, known])


## Known stations on screen that should carry a tag at this zoom, and the ones whose tag found no free spot.
func _tag_count(net, label: String) -> void:
	var level: int = net._tag_level()
	var top: float = net._hud_top()
	var view := Rect2(0.0, top, net.size.x, net.size.y - top)
	var want := 0
	var lost: PackedStringArray = []
	for sid in net._layout:
		var row: Dictionary = net._layout[sid]
		if not bool(row.known) or not view.has_point(row.at):
			continue
		var own := str(st.game.stations[sid].owner) == str(st.game.player)
		if level == 0 and not (bool(row.big) or own):
			continue
		want += 1
		if not net._tags.has(sid):
			lost.append(str(sid))
	print("FILL %s tags at %s (level %d, font %d UI px = %.1f window px): %d of %d drawn, no room for: %s" % [_key(), label, level,
		_fs(net), _fs(net) * net._window_scale(), want - lost.size(), want, ", ".join(lost) if not lost.is_empty() else "none"])


func _fs(net) -> int:
	return maxi(14 if net._tag_level() < 2 else 15, ceili(net.TAG_MIN_PX / net._window_scale()))


func _screen_box(net, box: Rect2) -> Rect2:
	var a: Vector2 = net._screen(box.position)
	var b: Vector2 = net._screen(box.end)
	return Rect2(a, b - a)


func _near_span(net) -> void:
	var spans: Array = []
	for sid in st.game.stations:
		var box := Rect2(net._station_world(st.game.stations[sid]), Vector2.ZERO)
		for tunnel in st.game.tunnels:
			var other := ""
			if str(tunnel.a) == str(sid):
				other = str(tunnel.b)
			elif str(tunnel.b) == str(sid):
				other = str(tunnel.a)
			if other != "" and st.game.stations.has(other):
				box = box.expand(net._station_world(st.game.stations[other]))
		spans.append(maxf(box.size.x, box.size.y))
	spans.sort()
	var mid: float = spans[spans.size() / 2]
	var third := minf(st.size.x, st.size.y) / 3.0
	print("FILL %s median station+neighbours span %.0f desk px; at max zoom %.0f px = %.0f%% of the short side" % [_key(), mid,
		mid * net._zoom_max, 100.0 * mid * net._zoom_max / minf(st.size.x, st.size.y)])
	print("FILL %s a third of the short side needs zoom %.3f = %.2f x the opening zoom" % [_key(), third / mid, third / mid / net._zoom_min])


func _zoom_reach(net, sid: String) -> void:
	_near_span(net)
	var at: Vector2 = net._screen(net._station_world(st.game.stations[sid]))
	var box := Rect2(at, Vector2.ZERO)
	for other in st.game._neighbors(sid):
		box = box.expand(net._screen(net._station_world(st.game.stations[str(other)])))
	print("FILL %s max zoom: %s and %d neighbours span %.0f x %.0f px = %.0f%% x %.0f%% of the window" % [_key(), sid,
		st.game._neighbors(sid).size(), box.size.x, box.size.y, 100.0 * box.size.x / st.size.x, 100.0 * box.size.y / st.size.y])


func _yard_fill() -> void:
	var y = st.yard
	var area: Rect2 = y._content()
	var rect: Rect2 = y._station_rect()
	var w: float = rect.size.x * y.zoom
	var h: float = rect.size.y * y.zoom
	var art: Rect2 = rect
	if y.backdrop_tex != null:
		art = art.merge(y._backdrop_dest(rect))
	var painted := Rect2(y.pan + art.position * y.zoom, art.size * y.zoom).intersection(area)
	print("FILL %s station view: zoom %.3f, station w %.0f%% h %.0f%% of content, painted picture covers %.0f%% x %.0f%%" % [_key(), y.zoom,
		100.0 * w / area.size.x, 100.0 * h / area.size.y, 100.0 * painted.size.x / area.size.x, 100.0 * painted.size.y / area.size.y])


func _scrolls(panel: Control) -> bool:
	for scroll in panel.find_children("*", "ScrollContainer", true, false):
		if scroll.get_v_scroll_bar().visible:
			return true
	return false


func _shot(name: String) -> void:
	for _i in 30:
		await process_frame
	await st._frame()
	st._save(out + "/" + name)
