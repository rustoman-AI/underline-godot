extends SceneTree

## Prepare an isolated complete-set review with a visible expedition and a trader route.
func _initialize() -> void:
	_run.call_deferred()

## Capture the expedition, verify tint/effects, or record the last 300 steady map frames.
func _run() -> void:
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
	Settings.intro_seen = true
	Settings.reduce_motion = false
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
	var chosen: Dictionary = {}
	for tunnel in station.game.tunnels:
		if str(station.game.capital_id) in [str(tunnel.a), str(tunnel.b)] and net._layout.has(str(tunnel.a)) and net._layout.has(str(tunnel.b)):
			chosen = tunnel
			break
	assert(not chosen.is_empty())
	station.game.expedition = {"tunnel": str(chosen.id), "left": 3}
	station.game.squads[station.game.player].away = true
	var trade: Dictionary = {}
	for row in net._caravans:
		if str(row.kind) == "supply":
			trade = {"route": row.route.duplicate(), "good": "materials", "kind": "trade", "seed": 12345}
			break
	assert(not trade.is_empty())
	for sibling in net.get_parent().get_children():
		if sibling is CanvasItem and sibling != net:
			sibling.visible = false
	if "--movie" in OS.get_cmdline_user_args():
		net._caravans.append(trade)
		for i in 310:
			await process_frame
		print("FULL MOVIE: ten steady seconds, active expedition, handcars, trader and cruise dust")
		quit(0)
		return
	net.set_process(false)
	await _tints(net)
	var midpoint: Vector2 = (Vector2(net._layout[str(chosen.a)].at) + Vector2(net._layout[str(chosen.b)].at)) * 0.5
	net._zoom_at(midpoint, net._zoom_max / net.zoom)
	net.refresh()
	await process_frame
	await process_frame
	net._anim_t = 1.5
	net._caravans.append(trade)
	net._unit_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var sprite: Sprite2D = net._sprites.sprites["expedition_" + str(station.game.player)]
	assert(sprite.visible and sprite.texture in net._sprites.frames.expedition_walk)
	var image := root.get_texture().get_image()
	var rect := Rect2i(Vector2i(sprite.position) - Vector2i(90, 100), Vector2i(210, 135)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://build/expedition_tunnel_max_crop.png")
	await _dust(net)
	print("FULL SET OK: seven sheets; six expedition pennant masks protect mugs; cruise-only dust every 0.6 seconds; expiry and reduced motion; real expedition tunnel crop")
	quit(0)

## Compare every expedition pose in two faction colours, protecting all pixels outside its pennant box.
func _tints(net) -> void:
	var meta: Dictionary = net._sprites.sheet_meta.expedition_walk
	assert(meta.tint_regions.size() == 6)
	for frame in 6:
		var texture: Texture2D = net._sprites.frames.expedition_walk[frame]
		var source := texture.get_image()
		var viewport := SubViewport.new()
		viewport.size = Vector2i(source.get_width() * 3, source.get_height())
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		for i in 3:
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture = texture
			sprite.position.x = i * source.get_width()
			if i < 2:
				sprite.material = net._sprites._material(net._faction_color(net._game(), "depot" if i == 0 else "exchange"), "expedition_walk", frame)
			viewport.add_child(sprite)
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := viewport.get_texture().get_image()
		rendered.save_png("res://build/expedition_tint_%d.png" % frame)
		var region: Array = meta.tint_regions[frame]
		for i in 2:
			var changed := 0
			for y in source.get_height():
				for x in source.get_width():
					if source.get_pixel(x, y).a < 0.9:
						continue
					var before := rendered.get_pixel(x + 2 * source.get_width(), y)
					var after := rendered.get_pixel(x + i * source.get_width(), y)
					var delta := maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
					var uv := Vector2(float(x) / source.get_width(), float(y) / source.get_height())
					if uv.x < region[0] or uv.x > region[2] or uv.y < region[1] or uv.y > region[3]:
						assert(delta < 0.02, "Expedition tint changed mugs or other pixels outside the pennant")
					elif delta > 0.05:
						changed += 1
			print("PENNANT frame %d colour %d changed %d" % [frame, i, changed])
			assert(changed > 100, "Pennant must tint in every pose")
		viewport.queue_free()

## Exercise real idle/cruise emission plus effect timing, absence of tint and reduced-motion cleanup.
func _dust(net) -> void:
	net._puffs.clear()
	net._puff_times.clear()
	net._anim_t = 20.0
	net._unit_routes.clear()
	for row in net._caravans:
		var id := "%s_%s_%s" % [row.kind, row.get("owner", "home"), row.seed]
		net._unit_routes[id] = {"row": row, "born": 19.4, "retire": -1.0}
	net._unit_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(net._puffs.is_empty(), "Waiting vehicles must not emit dust")
	for state in net._unit_routes.values():
		state.born = 18.0
	net._unit_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(not net._puffs.is_empty(), "Cruising vehicles must emit dust")
	var key: String = net._puffs.keys()[0]
	var node: Sprite2D = net._sprites.sprites[key]
	assert(node.material == null and node.z_index == 0, "Dust must be untinted above the static map")
	for sprite in net._sprites.sprites.values():
		if sprite.texture in net._sprites.frames.handcar_pump or sprite.texture in net._sprites.frames.trader_roll:
			assert(sprite.z_index > node.z_index, "Vehicles must draw in front of dust")
	var born: float = net._puffs[key].born
	net._emit_cruise_puff(key.trim_prefix("puff_"), Vector2.ZERO, 10)
	assert(net._puffs[key].born == born, "Repeated draws must not emit within 0.6 seconds")
	net._anim_t += 0.21
	net._unit_layer.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var rect := Rect2i(Vector2i(node.position) - Vector2i(90, 80), Vector2i(180, 120)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://build/cruise_dust_max_crop.png")
	for i in 6:
		net._sprites.puff("dust_test", Vector2.ZERO, 12, i * 0.1 + 0.01)
		assert(net._sprites.sprites.dust_test.texture == net._sprites.frames.puff[i])
	net._anim_t += 0.7
	net._draw_puffs(false)
	assert(net._puffs.is_empty(), "Dust expires after its six frames")
	net._emit_cruise_puff("test", Vector2.ZERO, 10)
	net._draw_puffs(true)
	assert(net._puffs.is_empty(), "Reduced motion removes dust")
