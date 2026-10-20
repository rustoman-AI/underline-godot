extends SceneTree

## Exercise animation contracts and measure forty visible sprites after caches are warm.
const Renderer := preload("res://ui/map_unit_sprites.gd")
var renderer := Renderer.new()
var layer := Node2D.new()

## Defer until autoloads and the rendering tree exist.
func _initialize() -> void:
	_run.call_deferred()

## Check import anchors, fixed poses, missing-sheet fallback, cache reuse and bounded rendering work.
func _run() -> void:
	root.add_child(layer)
	renderer.setup(layer)
	assert(renderer.frames.size() == 7, "Seven complete sheets required")
	assert(is_equal_approx(Renderer.travel(0, 4), 0))
	assert(is_equal_approx(Renderer.travel(4, 4), 1))
	var last := 0.0
	for i in 401:
		var next := Renderer.travel(i * 0.01, 4)
		assert(next >= last and next <= 1.0, "Distance must remain monotonic")
		last = next
	assert(not renderer.paint("missing", "absent", Vector2.ZERO, Vector2.RIGHT, Color.RED, 44, 0, 0, true, true))
	var total := 0
	var worst := 0
	for frame in 330:
		var start := Time.get_ticks_usec()
		renderer.begin()
		for i in 40:
			var at := Vector2(55 + (i % 10) * 115, 180 + (i / 10) * 125)
			renderer.paint(str(i), "handcar_pump", at, Vector2.RIGHT, Color("c65c42") if i % 2 == 0 else Color("52828c"), 44, frame * 1.2, frame / 30.0, false, false)
		renderer.finish()
		var elapsed := Time.get_ticks_usec() - start
		if frame >= 30:
			total += elapsed
			worst = maxi(worst, elapsed)
		await process_frame
	assert(renderer.materials.size() == 2, "Materials shared per owner")
	assert(renderer.sprites.size() == 40, "Pool must not grow over time")
	renderer.begin()
	renderer.paint("0", "handcar_idle", Vector2(55, 180), Vector2.RIGHT, Color("c65c42"), 44, 500, 20, true, true)
	renderer.finish()
	assert(renderer.sprites["0"].texture == renderer.frames.handcar_idle[0])
	assert(not renderer.sprites["1"].visible)
	print("MAP UNITS: contracts pass; 40 sprite updates mean %.3f ms, worst %.3f ms (CPU submission only)" % [total / 300000.0, worst / 1000.0])
	for file in ["network_caravans", "network_handcar", "network_squad_walk"]:
		var image := Image.load_from_file("res://shots/" + file + ".png")
		if image != null:
			var crop := image.get_region(Rect2i(400, 160, 480, 300))
			crop.resize(1440, 900, Image.INTERPOLATE_NEAREST)
			crop.save_png("res://build/" + file + "_crop.png")
	layer.queue_free()
	renderer.sprites.clear()
	await process_frame
	quit(0)
