extends SceneTree

## Import 384 px cells through one checked pipeline. Use -- --placeholders before the painted delivery arrives.
const COUNTS := {"handcar_pump": 8, "handcar_idle": 4, "trader_car": 8, "squad_walk": 8, "squad_stand": 4, "expedition_walk": 8, "puff": 6}
const CELL := 384
var failed := false

## Cut supplied sheets, or explicitly generate replaceable development sheets, without silently mixing sources.
func _initialize() -> void:
	var placeholders := OS.get_cmdline_user_args().has("--placeholders")
	for kind in COUNTS:
		var path := "res://incoming-art/map_units/" + str(kind) + ".png"
		var sheet: Image
		if placeholders:
			sheet = _placeholder(str(kind), int(COUNTS[kind]))
			var source := "res://incoming-art/map_units/placeholders"
			DirAccess.make_dir_recursive_absolute(source)
			sheet.save_png(source.path_join(str(kind) + ".png"))
		else:
			sheet = Image.load_from_file(path)
		if sheet == null or sheet.is_empty():
			push_error("Missing sheet: " + path)
			failed = true
			continue
		_cut(str(kind), sheet, int(COUNTS[kind]))
	quit(1 if failed else 0)

## Share one crop and record the original sole anchor so replacement art cannot bob between frames.
func _cut(kind: String, sheet: Image, count: int) -> void:
	var cols := sheet.get_width() / CELL
	if sheet.get_width() % CELL != 0 or sheet.get_height() % CELL != 0 or cols * (sheet.get_height() / CELL) != count:
		push_error("Invalid cell grid: " + kind)
		failed = true
		return
	var cells: Array[Image] = []
	var shared := Rect2i()
	for i in count:
		var cell := sheet.get_region(Rect2i((i % cols) * CELL, (i / cols) * CELL, CELL, CELL))
		var used := cell.get_used_rect()
		if used.has_area():
			shared = used if not shared.has_area() else shared.merge(used)
			if used.position.x == 0 or used.position.y == 0 or used.end.x == CELL or used.end.y == CELL:
				push_warning("Cell edge touched: %s f%d" % [kind, i])
		cells.append(cell)
	if not shared.has_area():
		push_error("Empty sheet: " + kind)
		failed = true
		return
	shared = shared.grow(2).intersection(Rect2i(0, 0, CELL, CELL))
	var dest := "res://assets/map/units/" + kind
	DirAccess.make_dir_recursive_absolute(dest)
	for i in count:
		if cells[i].get_region(shared).save_png(dest.path_join("f%d.png" % i)) != OK:
			failed = true
	var file := FileAccess.open(dest.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": count, "anchor": [192 - shared.position.x, 336 - shared.position.y], "placeholder": OS.get_cmdline_user_args().has("--placeholders")}, "\t"))
	print("%s: %d frames, shared crop %s" % [kind, count, shared])

## Rasterize simple development poses derived from the old handcar and crew, with neutral owner cloth.
func _placeholder(kind: String, count: int) -> Image:
	var sheet := Image.create(CELL * count, CELL, false, Image.FORMAT_RGBA8)
	var grey := Color("c8c8c8")
	var iron := Color("29231e")
	var wood := Color("987346")
	for i in count:
		var o := Vector2(i * CELL + 192, 336)
		var phase := float(i) / count * TAU
		if kind == "puff":
			for j in 5:
				_disc(sheet, o + Vector2(-float(i) * 9 + j * 9, -12 - i * 5 - j * 3), 9 + i * 2, Color(0.66, 0.59, 0.48, (1.0 - float(i) / count) * 0.35))
		elif kind.begins_with("handcar") or kind == "trader_car":
			for x in [-65, 65]:
				var hub := o + Vector2(x, -22)
				_disc(sheet, hub, 22, iron)
				for spoke in 4:
					var v := Vector2.from_angle(phase + spoke * PI / 4) * 17
					_line(sheet, hub - v, hub + v, 3, wood)
			_line(sheet, o + Vector2(-100, -49), o + Vector2(100, -49), 17, wood)
			_line(sheet, o + Vector2(-90, -40), o + Vector2(90, -40), 8, grey)
			_line(sheet, o + Vector2(0, -50), o + Vector2(0, -130), 7, iron)
			var arm := Vector2(63, sin(phase) * 18)
			_line(sheet, o + Vector2(0, -130) - arm, o + Vector2(0, -130) + arm, 8, wood)
			for side in [-1, 1]:
				_person(sheet, o + Vector2(side * 58, -53), sin(phase) * side * 6, grey)
		else:
			for j in 3:
				_person(sheet, o + Vector2((j - 1) * 70, -absf(j - 1) * 8), 0.0 if kind == "squad_stand" else sin(phase + j) * 15, grey)
	return sheet

## Draw crew with distinct heads, coats and walking feet for readable placeholder poses.
func _person(img: Image, foot: Vector2, stride: float, grey: Color) -> void:
	_line(img, foot + Vector2(-12 - stride, -4), foot + Vector2(-8, -50), 12, Color("3e3933"))
	_line(img, foot + Vector2(12 + stride, -4), foot + Vector2(8, -50), 12, Color("3e3933"))
	_line(img, foot + Vector2(0, -48), foot + Vector2(stride * 0.25, -98), 28, grey)
	_disc(img, foot + Vector2(stride * 0.25, -119), 16, Color("c9a07a"))
	_line(img, foot + Vector2(-17, -130), foot + Vector2(17, -130), 10, Color("403329"))
	_line(img, foot + Vector2(-12, -90), foot + Vector2(-27, -57 + stride), 9, grey)
	_line(img, foot + Vector2(12, -90), foot + Vector2(27, -57 - stride), 9, grey)

## Stamp a filled disc without requiring a rendering device in the headless import tool.
func _disc(img: Image, at: Vector2, radius: float, col: Color) -> void:
	for y in range(maxi(0, int(at.y - radius)), mini(img.get_height(), int(at.y + radius + 1))):
		for x in range(maxi(0, int(at.x - radius)), mini(img.get_width(), int(at.x + radius + 1))):
			if Vector2(x, y).distance_squared_to(at) <= radius * radius:
				img.set_pixel(x, y, col)

## Stroke between points with round caps for the old renderer's simple shapes.
func _line(img: Image, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var steps := maxi(1, int(a.distance_to(b)))
	for i in steps + 1:
		_disc(img, a.lerp(b, float(i) / steps), width * 0.5, col)
