extends SceneTree

const Renderer := preload("res://ui/map_unit_sprites.gd")
var renderer := Renderer.new()

## Exercise actual trade-route selection and GPU tint isolation before saving review crops.
func _initialize() -> void:
	_run.call_deferred()

## Render all six frames in two colours, then verify a real network trade uses the accepted sheet.
func _run() -> void:
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
	Settings.intro_seen = true
	Settings.reduce_motion = false
	var layer := Node2D.new()
	root.add_child(layer)
	renderer.setup(layer)
	assert(renderer.frames.trader_roll.size() == 6)
	var factions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/factions.json"))
	var colours := [Color(str(factions.depot.color)), Color(str(factions.exchange.color))]
	for frame in 6:
		await _check_tint(frame, colours)
	await _max_crop(colours)
	var station = load("res://ui/station.tscn").instantiate()
	station.shot_mode = true
	station.motion_in_shots = true
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
	var route: Array = []
	for row in net._caravans:
		if str(row.kind) == "supply":
			route = row.route.duplicate()
			break
	assert(route.size() >= 2)
	var midpoint: Vector2 = (Vector2(net._layout[str(route[0])].at) + Vector2(net._layout[str(route[1])].at)) * 0.5
	net._zoom_at(midpoint, net._zoom_max / net.zoom)
	net.refresh()
	await process_frame
	await process_frame
	net.set_process(false)
	var trade := {"route": route, "good": "materials", "kind": "trade", "seed": 12345}
	net._caravans = [trade]
	net._unit_routes.clear()
	net._unit_routes["trade_home_12345"] = {"row": trade, "born": net._anim_t - 3.0, "retire": -1.0}
	net._unit_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var car: Sprite2D = net._sprites.sprites["cart_trade_home_12345_0"]
	assert(car.visible and car.texture in net._sprites.frames.trader_roll, "Trade routes must render the accepted trader sheet")
	assert(car.material == net._sprites._material(net.TRADE_GOLD, "trader_roll"), "Keep the existing trade colour")
	var image := root.get_texture().get_image()
	var rect := Rect2i(Vector2i(car.position) - Vector2i(110, 100), Vector2i(220, 140)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://build/trader_network_max_crop.png")
	print("TRADER OK: six frames, two faction colours, canopy tint, all lower cargo including silver can unchanged, trade-route sprite at max zoom")
	quit(0)

## Compare real GPU pixels against the source so silver cargo stays untouched in every pose.
func _check_tint(frame: int, colours: Array) -> void:
	var texture: Texture2D = renderer.frames.trader_roll[frame]
	var source := texture.get_image()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(source.get_width() * 2, source.get_height())
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for i in 2:
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = texture
		sprite.position.x = source.get_width() * i
		sprite.material = renderer._material(colours[i], "trader_roll")
		viewport.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	for i in 2:
		var changed := 0
		var silver := 0
		for y in source.get_height():
			for x in source.get_width():
				var before := source.get_pixel(x, y)
				if before.a < 0.99:
					continue
				var after := rendered.get_pixel(x + i * source.get_width(), y)
				var delta := maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
				if y >= int(source.get_height() * 0.55):
					assert(delta < 0.02, "Tint changed cargo below the canopy")
					if Rect2(195, 140, 30, 35).has_point(Vector2(x, y)) and maxf(before.r, maxf(before.g, before.b)) - minf(before.r, minf(before.g, before.b)) <= 6.0 / 255.0 + 0.00001 and maxf(before.r, maxf(before.g, before.b)) > 60.0 / 255.0:
						silver += 1
				elif delta > 0.05:
					changed += 1
		assert(changed > 500, "Canopy tint must affect substantial neutral fabric")
		assert(silver >= 1, "Protection check must cover neutral silver-can pixels, including its dark shading")
	viewport.queue_free()

## Render both faction tints at the runtime 76-pixel maximum height with matching route lines.
func _max_crop(colours: Array) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(380, 120)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var layer := Node2D.new()
	viewport.add_child(layer)
	layer.draw.connect(func():
		layer.draw_line(Vector2(10, 108), Vector2(370, 108), Color("78634b"), 1.0)
	)
	var review := Renderer.new()
	review.setup(layer)
	for i in 2:
		assert(review.paint(str(i), "trader_roll", Vector2(95 + i * 190, 108), Vector2.RIGHT, colours[i], 76, 0, 0, true, true))
	await process_frame
	await RenderingServer.frame_post_draw
	var crop := viewport.get_texture().get_image()
	crop.resize(1520, 480, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://build/trader_two_factions_max_crop.png")
	viewport.queue_free()
