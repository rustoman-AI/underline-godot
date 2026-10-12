extends SceneTree

## Review shots for the fitted resident figures in incoming-art/residents_v2/game (made by fit_residents.gd).
## Nothing is installed: the textures are loaded from the incoming folder and handed to the station view in memory.
##   godot --path . -s res://.tools/residents_v2_shots.gd -- --size=1280x720
## Writes shots/residents_v2/<size>/:
##   station_<a|b|c>.png new game, tint A / half strength / none on the new figures (fig_tint_mix 0 / 0.5 / 1); hydroponics, air filter, generator and quarters show the new body stems as their
##                      room figures, the workshop its workshop stems, the platform two idle residents, so every
##                      accepted figure is on screen once. Palettes are picked per resident as in the game.
##   compare_<view>.png the three tints side by side, for the station and 2x crops of the staged rooms.
##   The log ends with CLEARANCE: head room between the tallest new figure and the top of each room cell.
##   wall.png           figures on the platform wall: current assets with tint A, new with each tint, new at 0.5x.
## and once (size independent) under shots/residents_v2/:
##   fit_native.png     each sprite 1:1 with the baseline (656, red) and the 520..600 height band (green).
##   palettes.png       base and every palette, untinted; palettes_tinted.png the same with the game tint.

const GAME := "res://incoming-art/residents_v2/game"
const OUT := "res://shots/residents_v2"
const SETTINGS := "res://.tools/fit_residents.json"
const STAGED_ROOMS := ["hydroponics", "air_filter", "generator", "quarters"]
const CROPS := ["workshop", "hydroponics", "air_filter", "generator", "platform", "quarters"]
## How far _paint_sprite lightens the tint toward white for the new figures (fig_tint_mix).
const TINTS := {"a": 0.0, "b": 0.5, "c": 1.0}
const TINT_NAMES := {"a": "tint A (current)", "b": "tint at half strength", "c": "no tint"}

var view
var stems: Array = []
var base := {}
var palettes := {}


class Sheet extends Control:
	var ops: Array = []

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for op in ops:
			match str(op.kind):
				"rect":
					draw_rect(op.rect, op.color)
				"tex":
					draw_texture_rect(op.tex, op.rect, false, op.color)
				"line":
					draw_line(op.a, op.b, op.color, op.width)
				"text":
					draw_string(font, op.pos, op.text, HORIZONTAL_ALIGNMENT_LEFT, -1, op.size, op.color)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var size := "1280x720"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--size="):
			size = str(arg).trim_prefix("--size=")
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	for stem in settings.get("accepted", []):
		var tex := _load(GAME.path_join(str(stem) + ".webp"))
		if tex == null:
			print("SHOTS missing fitted %s, run fit_residents.gd first" % stem)
			quit(1)
			return
		stems.append(str(stem))
		base[str(stem)] = tex
	var names := Array(DirAccess.get_directories_at(GAME.path_join("palettes")))
	names.sort()
	for name in names:
		palettes[str(name)] = {}
		for stem in stems:
			var tex := _load(GAME.path_join("palettes").path_join(str(name)).path_join(stem + ".webp"))
			if tex != null:
				palettes[str(name)][stem] = tex

	var st = load("res://ui/station.tscn").instantiate()
	root.add_child(st)
	await process_frame
	await process_frame
	st.hold_dawn = false
	await st._settle(st._shot_size())
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st._refresh()
	view = _find_view(st)
	if view == null:
		print("SHOTS no station view")
		quit(1)
		return
	var old: Array = []
	for stem in view.fig_variants:
		old.append([str(stem), view.fig_variants[stem][0]])
	old.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	var placed := _stage(st)

	await create_timer(1.0).timeout
	var dir := OUT.path_join(size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var origin: Vector2 = view.get_global_rect().position
	var shots := {}
	for variant in TINTS:
		view.fig_tint_mix = float(TINTS[variant])
		view.queue_redraw()
		await st._frame()
		await st._frame()
		var img: Image = st.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(dir.path_join("station_%s.png" % variant)))
		shots["station"] = shots.get("station", []) + [img]
		for type in CROPS:
			for room in st.game.rooms:
				if str(room.type) != type:
					continue
				var box: Rect2 = view.cell_screen(int(room.level), int(room.cell))
				box.position += origin
				var cut := Rect2i(box).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				if cut.size.x >= 8 and cut.size.y >= 8:
					var crop := img.get_region(cut)
					crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
					shots[type] = shots.get(type, []) + [crop]
				break
	for view_name in shots:
		await _save_sheet(_compare_sheet(shots[view_name], view_name == "station"), dir.path_join("compare_%s.png" % view_name))
	var clearance := _clearance(st)

	var wall := _wall_sheet(old)
	st.visible = false
	root.add_child(wall)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	st.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(dir.path_join("wall.png")))
	wall.queue_free()

	if size == "1280x720":
		await _save_sheet(_native_sheet(), OUT.path_join("fit_native.png"))
		await _save_sheet(_palette_sheet(false), OUT.path_join("palettes.png"))
		await _save_sheet(_palette_sheet(true), OUT.path_join("palettes_tinted.png"))
	print("SHOTS %s %d stems in %d slots: %s" % [size, stems.size(), placed.size(), ", ".join(placed)])
	print("CLEARANCE %s\n  %s" % [size, "\n  ".join(clearance)])
	quit(0)


## Tint variants side by side with their labels; the station at half size, room crops as they are.
func _compare_sheet(imgs: Array, halve: bool) -> Sheet:
	var sheet := Sheet.new()
	var texs: Array = []
	for img in imgs:
		var copy: Image = img.duplicate()
		if halve:
			copy.resize(copy.get_width() / 2, copy.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		texs.append(ImageTexture.create_from_image(copy))
	var w: float = texs[0].get_width()
	var h: float = texs[0].get_height()
	sheet.size = Vector2(w * texs.size() + 8.0 * (texs.size() - 1), h + 26.0)
	sheet.ops.append({"kind": "rect", "rect": Rect2(Vector2.ZERO, sheet.size), "color": Color(0.1, 0.1, 0.1)})
	var labels: Array = TINTS.keys()
	for i in texs.size():
		var x := i * (w + 8.0)
		sheet.ops.append({"kind": "text", "pos": Vector2(x + 6.0, 18.0), "text": "%s: %s" % [labels[i], TINT_NAMES[labels[i]]], "size": 15, "color": Color.WHITE})
		sheet.ops.append({"kind": "tex", "tex": texs[i], "rect": Rect2(x, 26.0, w, h), "color": Color.WHITE})
	return sheet


## Room-top clearance with the drawn sizes: for every staged room, the tallest of the new figures at the largest
## per-resident scale (1.06), drawn as _draw_people / _draw_sleepers / _draw_platform would; screen px between
## the head and the top of the room cell, and whether the sprite runs past the cell.
func _clearance(st) -> PackedStringArray:
	var out: PackedStringArray = []
	var geo: Dictionary = view._geo()
	var zoom: float = view.zoom
	for room in st.game.rooms:
		var type := str(room.type)
		if not type in CROPS:
			continue
		var rect: Rect2 = view._rect(geo, int(room.level), int(room.cell))
		var floor: Rect2 = rect if type == "platform" else view._art_rect(type, rect)
		var foot := floor.end.y - 2.0
		var pool: Array = stems.filter(func(s): return str(s).begins_with("workshop_") == (type == "workshop"))
		var worst := INF
		var worst_stem := ""
		for stem in pool:
			var tex: Texture2D = base[stem]
			var body_h := floor.size.y
			if type == "workshop" or type in STAGED_ROOMS and type != "quarters":
				var fitted: Vector2 = view._pose_size(tex, body_h)
				if fitted.x > floor.size.x * 0.34:
					body_h *= floor.size.x * 0.34 / fitted.x
			var drawn: Vector2 = view._pose_size(tex, body_h) * 1.06
			var head := foot - drawn.y + drawn.y * float(tex.get_image().get_used_rect().position.y) / 660.0
			var margin := (head - rect.position.y) * zoom
			if margin < worst:
				worst = margin
				worst_stem = stem
		var top_px: float = (foot - view._pose_size(base[worst_stem], floor.size.y).y * 1.06 - rect.position.y) * zoom
		out.append("%-12s tallest %s head %.0f px below the room top (sprite top %.0f px)%s" % [type, worst_stem, worst, top_px, "" if top_px >= 0.0 else " CUT"])
	return out


## Hands the new figures to the view and maps each visible resident to its own stem, through the same
## _fig_for lookup the game uses (stem by id hash, palette by id hash).
func _stage(st) -> PackedStringArray:
	for stem in stems:
		var variants: Array = [base[stem]]
		for name in palettes:
			if palettes[name].has(stem):
				variants.append(palettes[name][stem])
		view.fig_variants[stem] = variants
		for texture in variants:
			view.soft_figs[texture] = true
	var body: Array = stems.filter(func(s): return str(s).begins_with("body_"))
	var work: Array = stems.filter(func(s): return not str(s).begins_with("body_"))
	var groups := {}
	for room in st.game.rooms:
		var type := str(room.type)
		if type in STAGED_ROOMS and type != "quarters" or type == "workshop":
			groups[type] = room.staff.slice(0, 3)
		elif type == "quarters" and not groups.has("quarters"):
			groups["quarters"] = view._quarters_ids(str(room.uid))
	groups["platform"] = view._idle_ids().slice(0, 2)
	var placed: PackedStringArray = []
	var next := 0
	for type in ["platform"] + STAGED_ROOMS + ["workshop"]:
		var pool: Array = work if type == "workshop" else body
		var table := {}
		var ids: Array = groups.get(type, [])
		for i in ids.size():
			var stem: String
			if type == "workshop":
				stem = str(pool[i % pool.size()])
			else:
				stem = str(pool[next % pool.size()])
				next += 1
			table[str(ids[i])] = stem
			placed.append("%s:%s" % [type, stem])
		var lookup := _lookup(table, pool)
		if type == "platform":
			view.body_figs = lookup
		else:
			view.room_figs[type] = lookup
	view.queue_redraw()
	return placed


## An array where index (id hash % size) holds the stem chosen for that id.
func _lookup(table: Dictionary, pool: Array) -> Array:
	for n in range(max(table.size(), 1), 5000):
		var used := {}
		var clash := false
		for id in table:
			var at := int(view._id_hash(str(id))) % n
			if used.has(at) and used[at] != table[id]:
				clash = true
				break
			used[at] = table[id]
		if clash:
			continue
		var out: Array = []
		out.resize(n)
		out.fill(pool[0])
		for at in used:
			out[at] = used[at]
		return out
	return pool


func _tint(id: String, mix := 0.0) -> Color:
	var shade: float = 0.36 + fmod(view._id_hash(id), 5.0) * 0.02
	return Color(clampf(shade * 1.75, 0.6, 0.78), clampf(shade * 1.5, 0.52, 0.66), clampf(shade * 1.2, 0.42, 0.54)).lerp(Color.WHITE, mix)


## Rows of platform cells at the station's current zoom (and half of it) with figures standing on the floor,
## sized and tinted like _paint_sprite (height floor * 0.58, id scale left at 1.0).
func _wall_sheet(old: Array) -> Sheet:
	var sheet := Sheet.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var win: Vector2 = Vector2(root.size)
	sheet.size = win
	sheet.ops.append({"kind": "rect", "rect": Rect2(Vector2.ZERO, win), "color": Color(0.05, 0.06, 0.07)})
	var geo: Dictionary = view._geo()
	var zoom: float = view.zoom
	var y := 8.0
	var rows := [
		["current assets/figures/poses, tint A", old, 1.0, 0.0],
		["new, tint A", stems.map(func(s): return [s, base[s]]), 1.0, 0.0],
		["new, tint at half strength", stems.map(func(s): return [s, base[s]]), 1.0, 0.5],
		["new, no tint", stems.map(func(s): return [s, base[s]]), 1.0, 1.0],
		["new, 0.5x, tint at half strength", stems.map(func(s): return [s, base[s]]), 0.5, 0.5],
	]
	for row in rows:
		var cell := Vector2(float(geo.w), float(geo.h)) * zoom * float(row[2])
		sheet.ops.append({"kind": "text", "pos": Vector2(10, y + 14), "text": "%s  (cell %.0f px high)" % [row[0], cell.y], "size": 14, "color": Color(0.9, 0.86, 0.78)})
		y += 20.0
		var x := 0.0
		var floor := Rect2()
		while x < win.x:
			floor = view._art_rect("platform", Rect2(Vector2(x, y), cell))
			if view.art.has("platform"):
				sheet.ops.append({"kind": "tex", "tex": view.art["platform"], "rect": floor, "color": Color.WHITE})
			x += cell.x
		var items: Array = row[1]
		var step := (win.x - 40.0) / float(maxi(items.size(), 1))
		for i in items.size():
			var tex: Texture2D = items[i][1]
			var h := floor.size.y * 0.58
			var w := h * tex.get_width() / float(tex.get_height())
			var cx := 20.0 + step * (i + 0.5)
			var foot := floor.end.y - 2.0 * zoom * float(row[2])
			sheet.ops.append({"kind": "tex", "tex": tex, "rect": Rect2(cx - w * 0.5, foot - h, w, h), "color": _tint(str(items[i][0]), float(row[3]))})
			if row[2] == 1.0:
				sheet.ops.append({"kind": "text", "pos": Vector2(cx - step * 0.45, foot + 13), "text": str(items[i][0]), "size": 10, "color": Color(0.75, 0.72, 0.66)})
		y = floor.end.y + 22.0
	return sheet


func _native_sheet() -> Sheet:
	var sheet := Sheet.new()
	var x := 10.0
	var top := 26.0
	var total := 20.0
	for stem in stems:
		total += base[stem].get_width() + 10.0
	sheet.size = Vector2(total, top + 660 + 30)
	sheet.ops.append({"kind": "rect", "rect": Rect2(Vector2.ZERO, sheet.size), "color": Color(0.36, 0.36, 0.38)})
	sheet.ops.append({"kind": "rect", "rect": Rect2(0, top + 656 - 600, total, 80), "color": Color(0.30, 0.45, 0.30)})
	sheet.ops.append({"kind": "line", "a": Vector2(0, top + 656), "b": Vector2(total, top + 656), "color": Color(0.9, 0.2, 0.2), "width": 1.0})
	for stem in stems:
		var tex: Texture2D = base[stem]
		sheet.ops.append({"kind": "rect", "rect": Rect2(x, top, tex.get_width(), 660), "color": Color(0.40, 0.40, 0.42)})
		sheet.ops.append({"kind": "tex", "tex": tex, "rect": Rect2(x, top, tex.get_width(), 660), "color": Color.WHITE})
		sheet.ops.append({"kind": "text", "pos": Vector2(x, 18), "text": "%s %d" % [stem, tex.get_width()], "size": 14, "color": Color.WHITE})
		x += tex.get_width() + 10.0
	sheet.ops.append({"kind": "text", "pos": Vector2(10, top + 660 + 22), "text": "red: baseline y=656   green band: head top for 520..600 px body height   canvas outlined in lighter grey", "size": 14, "color": Color.WHITE})
	return sheet


func _palette_sheet(tinted: bool) -> Sheet:
	var sheet := Sheet.new()
	var scale := 0.33
	var names: Array = ["base"] + palettes.keys()
	var col := 0.0
	for stem in stems:
		col = maxf(col, base[stem].get_width() * scale)
	col += 8.0
	sheet.size = Vector2(90.0 + col * stems.size(), 24.0 + names.size() * (660.0 * scale + 8.0))
	sheet.ops.append({"kind": "rect", "rect": Rect2(Vector2.ZERO, sheet.size), "color": Color(0.16, 0.17, 0.18) if tinted else Color(0.42, 0.42, 0.44)})
	for i in stems.size():
		sheet.ops.append({"kind": "text", "pos": Vector2(90.0 + col * i, 16), "text": stems[i], "size": 11, "color": Color.WHITE})
	for r in names.size():
		var y := 24.0 + r * (660.0 * scale + 8.0)
		sheet.ops.append({"kind": "text", "pos": Vector2(8, y + 110), "text": str(names[r]), "size": 14, "color": Color.WHITE})
		for i in stems.size():
			var stem: String = stems[i]
			var tex: Texture2D = base[stem] if names[r] == "base" else palettes[names[r]].get(stem, null)
			if tex == null:
				continue
			var w := tex.get_width() * scale
			sheet.ops.append({"kind": "tex", "tex": tex, "rect": Rect2(90.0 + col * i + (col - 8.0 - w) * 0.5, y, w, 660.0 * scale), "color": _tint(stem) if tinted else Color.WHITE})
	return sheet


func _save_sheet(sheet: Sheet, path: String) -> void:
	var port := SubViewport.new()
	port.size = Vector2i(sheet.size.ceil())
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	port.add_child(sheet)
	root.add_child(port)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	port.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	port.queue_free()


func _load(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _find_view(node: Node) -> Object:
	if "body_figs" in node and node.has_method("cell_screen"):
		return node
	for child in node.get_children():
		var found = _find_view(child)
		if found != null:
			return found
	return null
