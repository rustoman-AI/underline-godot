extends SceneTree

## Prepare a reproducible map without saving changes to the player's game.
func _initialize() -> void:
	_run.call_deferred()

## Check pose timing and real map selection, then capture both owners at fit and max zoom.
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
	net.set_process(false)
	var route: Array = ["riverside", "southdepot"]
	assert(route.size() == 2)
	var owners := [str(station.game.player), "exchange"]
	station.game.squads = {
		owners[0]: {"station": route[0], "size": 12, "away": false},
		owners[1]: {"station": route[1], "size": 27, "away": false}
	}
	for sid in route:
		station.game.stations[str(sid)].known = true
	net._caravans.clear()
	net._unit_routes.clear()
	net._walks.clear()
	_check_timing(net)
	await _check_tints(net, owners)
	for level in ["fit", "max"]:
		if level == "max":
			var center: Vector2 = (Vector2(net._layout[str(route[0])].at) + Vector2(net._layout[str(route[1])].at)) * 0.5
			net._zoom_at(center, net._zoom_max / net.zoom)
			net.refresh()
			await process_frame
			await process_frame
		net._walks.clear()
		net._anim_t = 0.375
		await _capture(net, owners, level + "_stand", "squad_stand")
		net._walks[owners[0]] = {"route": route, "t": 0.14, "dur": 0.7}
		net._walks[owners[1]] = {"route": [route[1], route[0]], "t": 0.14, "dur": 0.7}
		await _capture(net, owners, level + "_walk", "squad_walk")
		station.motion_in_shots = false
		net._unit_layer.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		for owner in owners:
			assert(net._sprites.sprites["squad_" + owner].texture == net._sprites.frames.squad_stand[0], "Reduced motion holds standing frame zero")
		station.motion_in_shots = true
	print("SQUADS OK: distance-driven walk, 4 fps stand, common soles, player/rival colours, circular 12/27 badges, clear visible bays at Garden and Depot, no badge/tag overlap, fit/max crops, reduced motion")
	quit(0)

## Exercise animation selection and the common foot anchor independently of the camera.
func _check_timing(net) -> void:
	var renderer = net._sprites
	assert(renderer.frames.squad_walk.size() == 6 and renderer.frames.squad_stand.size() == 4)
	assert(renderer.anchors.squad_walk == renderer.anchors.squad_stand)
	assert(renderer.frames.squad_walk[0].get_size() == renderer.frames.squad_stand[0].get_size())
	for kind in ["squad_walk", "squad_stand"]:
		for texture in renderer.frames[kind]:
			var image: Image = texture.get_image()
			assert(absi(image.get_used_rect().end.y - 1 - int(renderer.anchors[kind].y)) <= 1, "Soles must remain on the anchor line")
	for i in 6:
		var step: float = renderer.cycle_distances.squad_walk * (44.0 / 580.0) / 6.0
		assert(renderer.paint("test_walk", "squad_walk", Vector2.ZERO, Vector2.RIGHT, Color.RED, 44, (i + 0.1) * step, 0, false, false))
		assert(renderer.sprites.test_walk.texture == renderer.frames.squad_walk[i])
	for i in 4:
		assert(renderer.paint("test_stand", "squad_stand", Vector2.ZERO, Vector2.RIGHT, Color.RED, 44, 0, i * 0.25, false, true))
		assert(renderer.sprites.test_stand.texture == renderer.frames.squad_stand[i])
	renderer.sprites.test_walk.visible = false
	renderer.sprites.test_stand.visible = false

## Save paired player/rival crops from the real map draw path, including its size badges.
func _capture(net, owners: Array, suffix: String, kind: String) -> void:
	for sibling in net.get_parent().get_children():
		if sibling is CanvasItem and sibling != net:
			sibling.visible = false
	for tick in 6:
		net._anim_t += 0.05
		net._unit_layer.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var pair := Image.create(400, 120, false, Image.FORMAT_RGBA8)
	var contexts: Array[Image] = []
	for i in owners.size():
		var owner: String = owners[i]
		var sprite: Sprite2D = net._sprites.sprites["squad_" + owner]
		assert(sprite.visible and sprite.texture in net._sprites.frames[kind])
		assert(sprite.material == net._sprites._material(net._faction_color(net._game(), owner), kind))
		var count_n := int(net._game().squads[owner].size)
		var badge_at: Vector2 = net._squad_badge_at(sprite.position, count_n)
		var badge_radius: float = net._squad_badge_radius(count_n) + 2.0
		var badge_box := Rect2(badge_at - Vector2.ONE * badge_radius, Vector2.ONE * badge_radius * 2)
		for tag in net._tags.values():
			assert(not badge_box.intersects(tag), "Squad badge must never cover a tag")
		if kind == "squad_stand":
			assert(net._unit_bay_clear(sprite.position, net._unit_width("squad_stand"), net._squad_footprint(count_n)), "Standing group and badge overlap station obstacles")
			assert(Rect2(Vector2.ZERO, net.size).encloses(Rect2(sprite.position + net._squad_footprint(count_n).position, net._squad_footprint(count_n).size)), "Standing bay must remain on screen")
			assert(badge_at.x > sprite.position.x and badge_at.y < sprite.position.y, "Badge belongs at the group's upper right")
			if suffix.begins_with("fit"):
				var sid := str(net._game().squads[owner].station)
				var pin: Dictionary = net._layout[sid]
				var bounds := Rect2(sprite.position + net._squad_footprint(count_n).position, net._squad_footprint(count_n).size)
				bounds = bounds.merge(Rect2(Vector2(pin.at) - Vector2.ONE * float(pin.r), Vector2.ONE * float(pin.r) * 2))
				if net._tags.has(sid):
					bounds = bounds.merge(net._tags[sid])
				for row in net._yield_rows:
					if str(row.sid) == sid:
						bounds = bounds.merge(Rect2(row.x, row.y, row.total, 18))
				var context := image.get_region(Rect2i(bounds.grow(12)).intersection(Rect2i(Vector2i.ZERO, image.get_size())))
				contexts.append(context)
				var enlarged: Image = context.duplicate()
				enlarged.resize(context.get_width() * 4, context.get_height() * 4, Image.INTERPOLATE_NEAREST)
				enlarged.save_png("res://build/squad_bay_%s_fit_crop.png" % sid)
		var rect := Rect2i(Vector2i(sprite.position) - Vector2i(75, 90), Vector2i(200, 120)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		assert(rect.size.x > 160 and rect.size.y > 100, "Squad crop must remain visible")
		pair.blit_rect(image, rect, Vector2i(i * 200, 0))
	pair.resize(1600, 480, Image.INTERPOLATE_NEAREST)
	pair.save_png("res://build/squad_" + suffix + "_crop.png")
	if contexts.size() == 2:
		var context_pair := Image.create(contexts[0].get_width() + contexts[1].get_width(), maxi(contexts[0].get_height(), contexts[1].get_height()), false, Image.FORMAT_RGBA8)
		context_pair.blit_rect(contexts[0], Rect2i(Vector2i.ZERO, contexts[0].get_size()), Vector2i.ZERO)
		context_pair.blit_rect(contexts[1], Rect2i(Vector2i.ZERO, contexts[1].get_size()), Vector2i(contexts[0].get_width(), 0))
		context_pair.resize(context_pair.get_width() * 4, context_pair.get_height() * 4, Image.INTERPOLATE_NEAREST)
		context_pair.save_png("res://build/squad_bays_fit_crop.png")

## Check real shader output in both faction colours without recolouring trousers or shield stripes.
func _check_tints(net, owners: Array) -> void:
	for kind in ["squad_walk", "squad_stand"]:
		for frame in net._sprites.frames[kind].size():
			var texture: Texture2D = net._sprites.frames[kind][frame]
			var source := texture.get_image()
			var viewport := SubViewport.new()
			viewport.size = Vector2i(1200, 580)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			for i in 2:
				var sprite := Sprite2D.new()
				sprite.centered = false
				sprite.position.x = i * 600
				sprite.texture = texture
				sprite.material = net._sprites._material(net._faction_color(net._game(), str(owners[i])), kind)
				viewport.add_child(sprite)
			await process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			for i in 2:
				var changed := 0
				for y in 580:
					for x in 600:
						var before := source.get_pixel(x, y)
						if before.a < 0.99:
							continue
						var after := rendered.get_pixel(x + i * 600, y)
						var delta := maxf(absf(before.r - after.r), maxf(absf(before.g - after.g), absf(before.b - after.b)))
						var spread := maxf(before.r, maxf(before.g, before.b)) - minf(before.r, minf(before.g, before.b))
						if y < 580 * 0.38 or y > 580 * 0.60 or spread > 6.0 / 255.0 + 0.00001:
							assert(delta < 0.02, "Squad tint changed protected gear or warm clothing")
						elif delta > 0.05:
							changed += 1
				assert(changed > 300, "Tint test must cover substantial armband pixels")
			viewport.queue_free()
