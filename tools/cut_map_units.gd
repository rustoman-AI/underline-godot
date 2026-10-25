extends SceneTree

## Cut accepted unit sheets by alpha gaps and normalize their rail or sole anchors.
const SOURCE := "res://incoming-art/map_units/pilot/handcar_pump_attempt3.png"
const DEST := "res://assets/map/units/handcar_pump"
const COUNT := 6

## Validate the expected frame count before replacing any imported frames.
func _initialize() -> void:
	var source := SOURCE
	var kind := "handcar_pump"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source = arg.trim_prefix("--source=")
		if arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
	if kind not in ["handcar_pump", "handcar_idle", "trader_roll", "squad_walk", "squad_stand", "expedition_walk", "puff"]:
		push_error("Only accepted unit sheets can be imported")
		quit(1)
		return
	var count := 4 if kind in ["handcar_idle", "squad_stand"] else COUNT
	var dest := "res://assets/map/units/" + kind
	var template: Dictionary = {}
	if kind == "handcar_idle":
		template = JSON.parse_string(FileAccess.get_file_as_string(DEST.path_join("frames.json")))
	var sheet := Image.load_from_file(source)
	if sheet == null or sheet.is_empty():
		push_error("Missing pilot: " + source)
		quit(1)
		return
	if kind == "puff":
		_clean(sheet)
	var spans := _spans(sheet)
	if kind == "puff":
		var groups: Array[Vector2i] = []
		for span in spans:
			if not groups.is_empty() and span.x - groups[-1].y < 60:
				groups[-1].y = span.y
			else:
				groups.append(span)
		spans = groups
	if spans.size() != count:
		push_error("%s: expected %d alpha-separated frames, found %d; no assets written" % [kind, count, spans.size()])
		quit(1)
		return
	if kind == "puff":
		_cut_puff(sheet, spans, source, dest)
		return
	if kind.begins_with("squad_") or kind == "expedition_walk":
		_cut_squad(sheet, spans, source, kind, count, dest)
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
	var tint_key := _canopy_grey(cells[0]) if kind == "trader_roll" else _plate_grey(cells[0], marks[0])
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
	var metadata := {"count": count, "anchor": [-origin.x, -origin.y], "wheelbase": target, "source": source, "landmarks": marks, "owner_grey": tint_key, "placeholder": false, "accepted": true}
	if kind == "trader_roll":
		metadata.tint_region = [0.0, 0.0, 0.72, 0.55]
	file.store_string(JSON.stringify(metadata, "\t"))
	print("%s: %d frames, size %s, anchor %s, owner grey %.4f" % [kind, count, extent, -origin, tint_key])
	quit(0)

## Normalize both squad sheets by body height and place their lowest opaque soles on one shared baseline.
func _cut_squad(sheet: Image, spans: Array[Vector2i], source: String, kind: String, count: int, dest: String) -> void:
	var expedition := kind == "expedition_walk"
	var canvas := Vector2i(700, 650) if expedition else Vector2i(600, 580)
	var anchor := Vector2(350, 630) if expedition else Vector2(300, 560)
	var cells: Array[Image] = []
	var marks: Array[Dictionary] = []
	var factor := 1.0
	var maximum_width := 0.0
	var samples: Array[float] = []
	for i in count:
		var span := spans[i]
		var cell := sheet.get_region(Rect2i(span.x, 0, span.y - span.x + 1, sheet.get_height()))
		_clean(cell)
		var used := cell.get_used_rect()
		var sole := used.end.y - 1
		var body_top := used.position.y
		for y in range(used.position.y, sole):
			var occupied := 0
			for x in cell.get_width():
				if cell.get_pixel(x, y).a > 60.0 / 255.0:
					occupied += 1
			if occupied > cell.get_width() * 0.22:
				body_top = y
				break
		if i == 0:
			factor = 400.0 / maxf(1, sole - body_top)
		var center := cell.get_width() * 0.5
		var box := Rect2((Vector2(used.position) - Vector2(center, sole)) * factor + anchor, Vector2(used.size) * factor)
		if not Rect2(Vector2(3, 3), Vector2(canvas) - Vector2(6, 6)).encloses(box):
			push_error("Squad frame %d exceeds shared canvas; no assets written" % i)
			quit(1)
			return
		maximum_width = maxf(maximum_width, used.size.x * factor)
		var pennant := Rect2i()
		if expedition:
			for y in range(used.position.y, used.position.y + int(used.size.y * 0.28)):
				for x in range(int(cell.get_width() * 0.70), cell.get_width()):
					var pixel := cell.get_pixel(x, y)
					var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
					var low := minf(pixel.r, minf(pixel.g, pixel.b))
					if pixel.a > 0.9 and high - low < 0.16 and high > 0.35 and high < 0.8:
						pennant = Rect2i(Vector2i(x, y), Vector2i.ONE) if not pennant.has_area() else pennant.expand(Vector2i(x, y))
						samples.append(high)
			if not pennant.has_area():
				push_error("No pennant near pole tip; no assets written")
				quit(1)
				return
		for y in range(body_top, body_top if expedition else body_top + int((sole - body_top) * 0.45)):
			for x in cell.get_width():
				var pixel := cell.get_pixel(x, y)
				var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
				var low := minf(pixel.r, minf(pixel.g, pixel.b))
				if pixel.a > 0.9 and high - low <= 6.0 / 255.0 and high > 0.45 and high < 0.8:
					samples.append(high)
		cells.append(cell)
		marks.append({"center": center, "sole": sole, "body_top": body_top, "pennant": [pennant.position.x, pennant.position.y, pennant.size.x, pennant.size.y]})
		print("%s f%d columns %d..%d sole %d body top %d scale %.5f" % [kind, i, span.x, span.y, sole, body_top, factor])
	if samples.is_empty():
		push_error("No neutral armband pixels found; no assets written")
		quit(1)
		return
	samples.sort()
	var tint_key: float = samples[samples.size() / 2]
	DirAccess.make_dir_recursive_absolute(dest)
	for i in count:
		var out := Image.create(canvas.x, canvas.y, false, Image.FORMAT_RGBA8)
		for y in canvas.y:
			for x in canvas.x:
				var p := Vector2i(((Vector2(x, y) - anchor) / factor + Vector2(marks[i].center, marks[i].sole)).round())
				if Rect2i(Vector2i.ZERO, cells[i].get_size()).has_point(p):
					out.set_pixel(x, y, cells[i].get_pixelv(p))
		if out.save_png(dest.path_join("f%d.png" % i)) != OK:
			push_error("Could not save squad frame")
			quit(1)
			return
	var file := FileAccess.open(dest.path_join("frames.json"), FileAccess.WRITE)
	var metadata := {"count": count, "anchor": [anchor.x, anchor.y], "source": source, "landmarks": marks, "owner_grey": tint_key, "tint_region": [0.0, 0.38, 1.0, 0.60], "cycle_distance": maximum_width * 1.1, "body_height": 400, "accepted": true, "placeholder": false}
	if expedition:
		var regions: Array = []
		for mark in marks:
			var p: Array = mark.pennant
			var box := Rect2(Vector2(p[0], p[1]) - Vector2(mark.center, mark.sole), Vector2(p[2], p[3])).grow(2)
			box = Rect2(box.position * factor + anchor, box.size * factor)
			regions.append([box.position.x / canvas.x, box.position.y / canvas.y, box.end.x / canvas.x, box.end.y / canvas.y])
		metadata.tint_regions = regions
		metadata.owner_spread = 0.16
		metadata.owner_tolerance = 0.12
	file.store_string(JSON.stringify(metadata, "\t"))
	print("%s: %d frames, canvas %s, sole anchor %s, owner grey %.4f" % [kind, count, canvas, anchor, tint_key])
	quit(0)

## Keep dust fragments together, preserving their shared source baseline and fading alpha.
func _cut_puff(sheet: Image, spans: Array[Vector2i], source: String, dest: String) -> void:
	var shared := Rect2()
	var baseline := sheet.get_used_rect().end.y - 1
	for i in spans.size():
		var span := spans[i]
		var cell := sheet.get_region(Rect2i(span.x, 0, span.y - span.x + 1, sheet.get_height()))
		var used := cell.get_used_rect()
		var box := Rect2(Vector2(used.position) - Vector2(cell.get_width() - 1, baseline), Vector2(used.size))
		shared = box if i == 0 else shared.merge(box)
	var origin := shared.position.floor() - Vector2(3, 3)
	var extent := Vector2i(shared.end.ceil() - origin + Vector2(3, 3))
	DirAccess.make_dir_recursive_absolute(dest)
	for i in spans.size():
		var span := spans[i]
		var cell := sheet.get_region(Rect2i(span.x, 0, span.y - span.x + 1, sheet.get_height()))
		var out := Image.create(extent.x, extent.y, false, Image.FORMAT_RGBA8)
		out.blit_rect(cell, Rect2i(Vector2i.ZERO, cell.get_size()), Vector2i(-origin) - Vector2i(cell.get_width() - 1, baseline))
		out.save_png(dest.path_join("f%d.png" % i))
		print("puff f%d columns %d..%d baseline %d" % [i, span.x, span.y, baseline])
	var file := FileAccess.open(dest.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": 6, "anchor": [-origin.x, -origin.y], "source": source, "accepted": true, "placeholder": false, "tinted": false}, "\t"))
	print("puff: six untinted frames, shared canvas %s" % extent)
	quit(0)

## Sample the canopy interior rather than the neutral silver cargo below it.
func _canopy_grey(image: Image) -> float:
	var used := image.get_used_rect()
	var samples: Array[float] = []
	for y in range(used.position.y + int(used.size.y * 0.3), used.position.y + int(used.size.y * 0.5)):
		for x in range(int(image.get_width() * 0.1), int(image.get_width() * 0.5)):
			var pixel := image.get_pixel(x, y)
			var high := maxf(pixel.r, maxf(pixel.g, pixel.b))
			var low := minf(pixel.r, minf(pixel.g, pixel.b))
			if pixel.a > 0.9 and high - low <= 6.0 / 255.0 and high > 0.45 and high < 0.9:
				samples.append(high)
	samples.sort()
	return samples[samples.size() / 2] if not samples.is_empty() else 166.0 / 255.0

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
