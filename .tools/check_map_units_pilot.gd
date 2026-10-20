extends SceneTree

## Render the real owner shader in all five colours and capture matched fit and max map crops.
var station

## Run only after autoload initialization and keep this review separate from player saves.
func _initialize() -> void:
	_run.call_deferred()

## Prepare week twenty, verify shader protection and station bays, then save repeatable review images.
func _run() -> void:
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
	Settings.intro_seen = true
	Settings.reduce_motion = false
	station = load("res://ui/station.tscn").instantiate()
	station.shot_mode = true
	root.add_child(station)
	await process_frame
	station._begin_new_game(false)
	var bot := Bot.new()
	bot.profile = "careful"
	while station.game.week < 20 and station.game.over == "":
		bot._act(station.game)
		station.game.end_week()
	station.game.pending.clear()
	station.game.order_reports.clear()
	station.hold_dawn = true
	station._close_card()
	station.guide_step = -1
	if station.guide_layer != null:
		station.guide_layer.visible = false
	station._refresh()
	station._toggle_network()
	var net = station.network_view
	net._fit()
	net.refresh()
	await process_frame
	await process_frame
	var route: Dictionary = {}
	for row in net._caravans:
		if str(row.kind) == "supply":
			route = row
			break
	assert(not route.is_empty(), "Week twenty must exercise the accepted supply car")
	await _shot(net, route, "fit")
	var points := PackedVector2Array()
	for sid in route.route:
		points.append(net._layout[str(sid)].at)
	points = net._unit_route_bays(points, str(route.route[0]), str(route.route[-1]))
	var at: Vector2 = net._along(points, net._poly_length(points) * 0.5)[0]
	net._zoom_at(at, net._zoom_max / net.zoom)
	net.refresh()
	await process_frame
	await process_frame
	await _shot(net, route, "max")
	var pin: Dictionary = net._layout[str(route.route[0])]
	var bay: Vector2 = net._unit_station_bay(str(route.route[0]), Vector2.RIGHT, net._unit_width(), 0)
	assert(bay.distance_to(pin.at) > float(pin.r) + net._unit_height() * 0.7)
	assert(net._unit_bay_clear(bay, net._unit_width()), "Waiting bay overlaps a pin, chip row or name tag")
	for sid in net._layout:
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(1, -1).normalized()]:
			var parked: Vector2 = net._unit_station_bay(str(sid), direction, net._unit_width(), 0)
			assert(net._unit_bay_clear(parked, net._unit_width()), "Blocked bays must search further along the route")
	assert(net._sprites.paint("tilt_check", "handcar_pump", Vector2.ZERO, Vector2(0.01, 1), Color.WHITE, 76, 0, 0, true, true))
	assert(absf(net._sprites.sprites.tilt_check.rotation) <= deg_to_rad(6.0) + 0.0001)
	_check_spacing(net)
	await _tints(net)
	print("PILOT REVIEW OK: five shader colours, protected trousers/sacks, long-route spacing, off-pin bay, fit/max crops")
	quit(0)

## Save a full view and nearest-neighbour enlargement centred on a fixed supply-car position.
func _shot(net, route: Dictionary, suffix: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://shots/network_pilot_" + suffix + ".png")
	var points := PackedVector2Array()
	for sid in route.route:
		points.append(net._layout[str(sid)].at)
	points = net._unit_route_bays(points, str(route.route[0]), str(route.route[-1]))
	var length: float = net._poly_length(points)
	var speed: float = net.CARAVAN_SPEED * net.zoom / net._zoom_min
	var duration: float = length / speed + 0.45 * (points.size() - 1)
	var count: int = maxi(1, int((duration + 2.4) / (2.4 + 1.6 * net._unit_width() / speed + 0.45 * points.size())))
	var at: Vector2 = net._along(points, length * 0.5 / count)[0]
	var rect := Rect2i(Vector2i(at) - Vector2i(100, 105), Vector2i(200, 150)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://build/network_pilot_" + suffix + "_crop.png")

## Sample a long straight tunnel through all phases to check the minimum spatial headway.
func _check_spacing(net) -> void:
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(1400, 0)])
	var speed: float = net.CARAVAN_SPEED * net.zoom / net._zoom_min
	var length := 1400.0
	var period: float = length / speed + 0.45 + 2.4
	var gap: float = net._unit_width() * 1.6
	var n: int = maxi(1, int(period / (2.4 + gap / speed + 0.45 * pts.size())))
	assert(n > 1, "Long routes must support more than one car")
	for tick in 1000:
		var positions: Array[float] = []
		for i in n:
			var t := fposmod(tick * period / 1000.0 - i * period / n, period)
			positions.append(net._unit_progress(pts, t - 1.2, speed).x)
		positions.sort()
		for i in range(1, n):
			assert(positions[i] - positions[i - 1] >= gap - 0.1, "Cars violated 1.6 widths")

## Compare actual GPU shader output with untouched trouser and sack regions for every faction.
func _tints(net) -> void:
	var source: Image = net._sprites.frames.handcar_pump[0].get_image()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(source.get_width() * 5, source.get_height())
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var names := ["depot", "directorate", "synod", "exchange", "black_flag"]
	for i in 5:
		var sprite := Sprite2D.new()
		sprite.texture = net._sprites.frames.handcar_pump[0]
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position.x = i * source.get_width()
		sprite.material = net._sprites._material(net._faction_color(station.game, names[i]))
		viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	rendered.save_png("res://build/map_units_pilot_five_tints.png")
	for i in 5:
		var checks := 0
		var changed := 0
		for y in source.get_height():
			for x in source.get_width():
				var before := source.get_pixel(x, y)
				if before.a < 0.99:
					continue
				var after := rendered.get_pixel(x + i * source.get_width(), y)
				var delta := maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
				## These explicit regions isolate the woman's trousers and rear beige sack.
				if Rect2i(65, 125, 25, 55).has_point(Vector2i(x, y)) or Rect2i(15, 160, 30, 25).has_point(Vector2i(x, y)):
					assert(delta < 0.02, "Owner tint changed trousers or sacks")
					checks += 1
				if Rect2i(100, 211, 85, 7).has_point(Vector2i(x, y)) and delta > 0.05:
					changed += 1
		assert(checks > 200 and changed > 100, "Tint test must cover the protected regions and plate")
	viewport.queue_free()
