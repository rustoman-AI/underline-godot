extends SceneTree

## Cut the accepted six-frame pilot by alpha gaps and normalize around its wheel hubs and rail.
const SOURCE := "res://incoming-art/map_units/pilot/handcar_pump_attempt3.png"
const DEST := "res://assets/map/units/handcar_pump"
const COUNT := 6

## Validate all six images before replacing any imported frames.
func _initialize() -> void:
	var source := SOURCE
	var kind := "handcar_pump"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
		if arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
	if kind not in ["handcar_pump", "handcar_idle"]:
		push_error("Only accepted handcar sheets can be imported")
		quit(1)
		return
	var count := 4 if kind == "handcar_idle" else COUNT
	var dest := "res://assets/map/units/" + kind
	var template: Dictionary = {}
	if kind == "handcar_idle":
		template = JSON.parse_string(FileAccess.get_file_as_string(DEST.path_join("frames.json")))
	var sheet := Image.load_from_file(source)
	if sheet == null or sheet.is_empty():
		push_error("Missing pilot: " + source)
		quit(1)
		return
	var spans := _spans(sheet)
	if spans.size() != count:
		push_error("%s: expected %d alpha-separated frames, found %d; no assets written" % [kind, count, spans.size()])
		quit(1)
		return
	var cells: Array[Image] = []
	var marks: Array[Dictionary] = []
	var shared := Rect2()
	var target := 0.0
	for i in count:
		var span: Vector2i = spans[i]
		var cell := sheet.get_region(Rect2i(span.x, 0, span.y - span.x + 1, sheet.get_height()))
		_clean(cell)
		var wheel := _wheels(cell)
		if wheel.is_empty():
			push_error("Invalid wheel landmarks in frame %d; no assets written" % i)
			quit(1)
			return
		if i == 0:
			target = float(template.get("wheelbase", wheel.base))
		var factor: float = target / float(wheel.base)
		var used := cell.get_used_rect()
		var box := Rect2((Vector2(used.position) - Vector2(wheel.center, wheel.rail)) * factor, Vector2(used.size) * factor)
		shared = box if i == 0 else shared.merge(box)
		cells.append(cell)
		marks.append(wheel)
		print("f%d columns %d..%d hubs %.2f / %.2f base %.2f rail %d scale %.5f" % [i, span.x, span.y, wheel.left, wheel.right, wheel.base, wheel.rail, factor])
	var origin := shared.position.floor() - Vector2(3, 3)
	var extent := Vector2i(shared.end.ceil() - origin + Vector2(3, 3))
	if not template.is_empty():
		origin = -Vector2(template.anchor[0], template.anchor[1])
		extent = Image.load_from_file(DEST.path_join("f0.png")).get_size()
		if not Rect2(origin, Vector2(extent)).encloses(shared):
			push_error("Idle art exceeds the pump canvas; no assets written")
			quit(1)
			return
	var tint_key := _plate_grey(cells[0], marks[0])
	DirAccess.make_dir_recursive_absolute(dest)
	for i in count:
		var wheel: Dictionary = marks[i]
		var factor: float = target / float(wheel.base)
		var anchor := Vector2(wheel.center, wheel.rail)
		var out := Image.create(extent.x, extent.y, false, Image.FORMAT_RGBA8)
		for y in extent.y:
			for x in extent.x:
				var p := Vector2i(((Vector2(x, y) + origin) / factor + anchor).round())
				if p.x >= 0 and p.y >= 0 and p.x < cells[i].get_width() and p.y < cells[i].get_height():
					out.set_pixel(x, y, cells[i].get_pixelv(p))
		if out.save_png(dest.path_join("f%d.png" % i)) != OK:
			push_error("Could not save pilot frame %d" % i)
			quit(1)
			return
	for name in DirAccess.get_files_at(dest):
		if name.begins_with("f") and name.get_extension() == "png" and int(name.trim_prefix("f").get_basename()) >= count:
			DirAccess.remove_absolute(dest.path_join(name))
			DirAccess.remove_absolute(dest.path_join(name + ".import"))
	var file := FileAccess.open(dest.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": count, "anchor": [-origin.x, -origin.y], "wheelbase": target, "source": source, "landmarks": marks, "owner_grey": tint_key, "placeholder": false, "accepted": true}, "\t"))
	print("%s: %d frames, size %s, anchor %s, owner grey %.4f" % [kind, count, extent, -origin, tint_key])
	quit(0)

## Sample the central owner plate so each accepted sheet keeps its own neutral-grey key.
func _plate_grey(image: Image, wheel: Dictionary) -> float:
	var samples: Array[float] = []
	for y in range(int(wheel.rail - wheel.base * 0.27), int(wheel.rail - wheel.base * 0.20)):
		for x in range(int(wheel.center - wheel.base * 0.25), int(wheel.center + wheel.base * 0.25)):
			var pixel := image.get_pixel(x, y)
			var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var low := minf(pixel.r, minf(pixel.g, pixel.b))
			if pixel.a > 0.9 and high - low <= 6.0 / 255.0 and high > 0.45 and high < 0.9:
				samples.append(high)
	samples.sort()
	return samples[samples.size() / 2] if not samples.is_empty() else 181.0 / 255.0

## Detect occupied column runs using alpha greater than 60, independent of nominal cell dimensions.
func _spans(image: Image) -> Array[Vector2i]:
	var spans: Array[Vector2i] = []
	var start := -1
	for x in image.get_width() + 1:
		var occupied := false
		if x < image.get_width():
			for y in image.get_height():
				if image.get_pixel(x, y).a > 60.0 / 255.0:
					occupied = true
					break
		if occupied and start < 0:
			start = x
		if not occupied and start >= 0:
			spans.append(Vector2i(start, x - 1))
			start = -1
	return spans

## Remove alpha below 40 and eight-connected islands smaller than thirty pixels.
func _clean(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	for y in h:
		for x in w:
			if image.get_pixel(x, y).a < 40.0 / 255.0:
				image.set_pixel(x, y, Color.TRANSPARENT)
	for y in h:
		for x in w:
			if seen[y * w + x] != 0 or image.get_pixel(x, y).a == 0:
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			seen[y * w + x] = 1
			var head := 0
			while head < queue.size():
				var p := queue[head]
				head += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q := p + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
							continue
						var index := q.y * w + q.x
						if seen[index] == 0 and image.get_pixelv(q).a > 0:
							seen[index] = 1
							queue.append(q)
			if queue.size() < 30:
				for p in queue:
					image.set_pixelv(p, Color.TRANSPARENT)

## Find the two lower wheel silhouettes, excluding the thin rail, and use their symmetry axes as hub centres.
func _wheels(image: Image) -> Dictionary:
	var used := image.get_used_rect()
	var rail := used.end.y - 1
	for y in range(used.end.y - 1, used.end.y - 12, -1):
		var pixels := 0
		for x in image.get_width():
			if image.get_pixel(x, y).a > 60.0 / 255.0:
				pixels += 1
		if pixels > image.get_width() * 0.65:
			rail = y
	var top := rail - int(image.get_width() * 0.05)
	var runs: Array[Vector2i] = []
	var start := -1
	for x in image.get_width() + 1:
		var occupied := false
		if x < image.get_width():
			for y in range(top, rail - 4):
				if image.get_pixel(x, y).a > 60.0 / 255.0:
					occupied = true
					break
		if occupied and start < 0:
			start = x
		if not occupied and start >= 0:
			if x - start >= 12:
				runs.append(Vector2i(start, x - 1))
			start = -1
	if runs.size() != 2:
		push_error("Expected two wheel silhouettes, found %s" % str(runs))
		return {}
	var left := (runs[0].x + runs[0].y) * 0.5
	var right := (runs[1].x + runs[1].y) * 0.5
	var bottom := 0
	for run in runs:
		for x in range(run.x, run.y + 1):
			for y in range(top, rail):
				if image.get_pixel(x, y).a > 60.0 / 255.0:
					bottom = maxi(bottom, y)
	return {"left": left, "right": right, "center": (left + right) * 0.5, "base": right - left, "rail": bottom}
