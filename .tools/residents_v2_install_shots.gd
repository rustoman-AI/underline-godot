extends SceneTree

## Shots of the installed resident figures (assets/figures/poses, residents_v2) in the station.
##   godot --path . -s res://.tools/residents_v2_install_shots.gd -- --size=1280x720
## Writes shots/residents_v2_install/<size>/:
##   start.png    new game, week 1.
##   full.png     the expander bot plays 18 weeks; any room type still missing is placed on a dug cell and
##                staffed from idle residents (in memory only), so every room type is on screen.
##   crisis.png   the same run to week 31 (cough season), three working residents sick and food at 4.
##   crop_<scene>_<room>.png  each room cell of that scene at 2x.
## The log lists the stems per room (FIGS), how far each drawn figure's soles sit from the floor line (FEET),
## and whether every resident keeps its stem and palette after a manual save and load (RELOAD). Saves go to
## user://residents_v2_shots/, never the player's slots.

const OUT := "res://shots/residents_v2_install"
const SAVE_ROOT := "user://residents_v2_shots/"
const ROOM_TYPES := ["platform", "quarters", "hydroponics", "air_filter", "generator", "workshop", "infirmary", "meeting_hall", "radio"]

var st
var view
var dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var size := "1280x720"
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--size="):
			size = str(arg).trim_prefix("--size=")
	dir = OUT.path_join(size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	SaveGame.root = SAVE_ROOT
	await _open()
	st._begin_new_game(false)
	_quiet()
	_figs()
	await _shoot("start")

	var bot := Bot.new()
	bot.profile = "expander"
	while st.game.week < 19 and st.game.over == "":
		bot._act(st.game)
		st.game.end_week()
	_complete_rooms()
	_quiet()
	await _shoot("full")
	var before := _assignments()
	if not SaveGame.write_manual(st.game):
		print("RELOAD FAIL write: %s" % SaveGame.last_error)
	st.queue_free()
	await process_frame
	await _open()
	st._begin_new_game(false)
	if not SaveGame.load_manual(st.game):
		print("RELOAD FAIL load: %s" % SaveGame.last_error)
	_quiet()
	await st._frame()
	var after := _assignments()
	var same := 0
	var diff: PackedStringArray = []
	for id in before:
		if str(after.get(id, "")) == str(before[id]):
			same += 1
		else:
			diff.append("%s %s -> %s" % [id, before[id], after.get(id, "missing")])
	print("RELOAD %s: %d of %d residents keep stem and palette%s" % ["OK" if diff.is_empty() and before.size() == after.size() else "FAIL", same, before.size(), "" if diff.is_empty() else "; " + ", ".join(diff)])
	await _shoot("full_reloaded", false)

	while st.game.week < 31 and st.game.over == "":
		bot._act(st.game)
		st.game.end_week()
	_complete_rooms()
	var sick := 0
	for room in st.game.rooms:
		for id in room.staff:
			if sick < 3 and str(room.type) != "infirmary":
				st.game.people[str(id)].sick = 3
				sick += 1
	st.game.stock.food = 4
	_quiet()
	await _shoot("crisis")
	print("SHOTS %s done, season %s" % [size, str(st.game.active_season.get("id", "none"))])
	quit(0)


func _open() -> void:
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	st.hold_dawn = false
	await st._settle(st._shot_size())
	view = _find_view(st)


func _quiet() -> void:
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending = []
	st.game.audience = {}
	st._refresh()


## Places each missing room type on a free dug cell (digging one if needed) and staffs it from idle residents.
func _complete_rooms() -> void:
	var g: Game = st.game
	var have := {}
	for room in g.rooms:
		have[str(room.type)] = true
	for type in ROOM_TYPES:
		if have.has(type) or type == "platform":
			continue
		var spot := {}
		for key in g.cells:
			var c: Dictionary = g.cells[key]
			if g._cell_buildable(c):
				spot = c
				break
		if spot.is_empty():
			for key in g.cells:
				var c: Dictionary = g.cells[key]
				if not c.dug and str(c.room) == "" and not c.flooded and not c.walled:
					c.dug = true
					spot = c
					break
		if spot.is_empty():
			print("STAGE no cell for %s" % type)
			continue
		g._place_room(type, int(spot.level), int(spot.cell))
		have[type] = true
	for room in g.rooms:
		var want: int = g.catalog.rooms[str(room.type)].get("spots", []).size()
		if str(room.type) == "quarters" or room.staff.size() >= want:
			continue
		for id in view._idle_ids():
			if room.staff.size() >= want:
				break
			g._apply_assign(str(id), str(room.uid))


func _figs() -> void:
	var rooms: PackedStringArray = []
	for type in view.room_figs:
		rooms.append("%s %s" % [type, ", ".join(PackedStringArray(view.room_figs[type]))])
	print("FIGS body %d: %s" % [view.body_figs.size(), ", ".join(PackedStringArray(view.body_figs))])
	print("FIGS rooms: %s" % "; ".join(rooms))
	for type in ["hydroponics", "generator", "air_filter", "workshop", "infirmary", "radio"]:
		print("FIGS %-12s %s" % [type, "ok" if view.room_figs.get(type, []).size() > 0 else "MISSING"])
	print("FIGS tint_mix %.2f, soft textures %d, variants per stem %d" % [view.fig_tint_mix, view.soft_figs.size(), view.fig_variants.get("body_01", []).size()])


## resident id -> "stem/palette" the station draws for that resident where they are now.
func _assignments() -> Dictionary:
	var out := {}
	var g: Game = st.game
	var staffed := {}
	for room in g.rooms:
		if str(room.type) == "quarters":
			for id in view._quarters_ids(str(room.uid)):
				staffed[str(id)] = true
				out[str(id)] = _name_of(view._fig_for(view.room_figs.get("quarters", view.body_figs), str(id)))
			continue
		var own: Array = view.room_figs.get(str(room.type), [])
		for id in room.staff:
			staffed[str(id)] = true
			out[str(id)] = _name_of(view._fig_for(own, str(id)) if not own.is_empty() else view._pose_sprite("walking", str(id)))
	for id in view._idle_ids():
		if not staffed.has(str(id)):
			out[str(id)] = _name_of(view._pose_sprite("walking", str(id)))
	return out


func _name_of(tex: Texture2D) -> String:
	if tex == null:
		return "none"
	for stem in view.fig_variants:
		var variants: Array = view.fig_variants[stem]
		var at := variants.find(tex)
		if at >= 0:
			return "%s/%s" % [stem, "base" if at == 0 else tex.resource_path.get_base_dir().get_file()]
	return tex.resource_path.get_file()


func _shoot(name: String, crops := true) -> void:
	st._refresh()
	view.queue_redraw()
	await create_timer(0.5).timeout
	await st._frame()
	await st._frame()
	var img: Image = st.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(dir.path_join(name + ".png")))
	_feet(name)
	if not crops:
		return
	var origin: Vector2 = view.get_global_rect().position
	for room in st.game.rooms:
		var box: Rect2 = view.cell_screen(int(room.level), int(room.cell))
		box.position += origin
		var cut := Rect2i(box).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if cut.size.x < 8 or cut.size.y < 8:
			continue
		var crop := img.get_region(cut)
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(ProjectSettings.globalize_path(dir.path_join("crop_%s_%s_L%dC%d.png" % [name, room.type, int(room.level), int(room.cell)])))


## For every staffed room: the lowest opaque row of each drawn sprite against the floor line, in screen px
## (positive = soles above the floor).
func _feet(name: String) -> void:
	var lines: PackedStringArray = []
	var worst := 0.0
	var geo: Dictionary = view._geo()
	for room in st.game.rooms:
		var type := str(room.type)
		if type == "quarters" or type == "platform" or room.staff.is_empty():
			continue
		var own: Array = view.room_figs.get(type, [])
		var rect: Rect2 = view._rect(geo, int(room.level), int(room.cell))
		var floor: Rect2 = view._art_rect(type, rect)
		for id in room.staff.slice(0, 3):
			var tex: Texture2D = view._fig_for(own, str(id)) if not own.is_empty() else view._pose_sprite("walking", str(id))
			if tex == null:
				continue
			var used := tex.get_image().get_used_rect()
			var drawn: Vector2 = view._pose_size(tex, floor.size.y)
			var gap := (tex.get_height() - used.end.y) / float(tex.get_height()) * drawn.y * float(view.zoom) + 2.0 * float(view.zoom)
			worst = maxf(worst, gap)
			lines.append("%s:%s %.1f" % [type, _name_of(tex).get_slice("/", 0), gap])
	print("FEET %s worst %.1f px above the floor line: %s" % [name, worst, ", ".join(lines)])


func _find_view(node: Node) -> Object:
	if "body_figs" in node and node.has_method("cell_screen"):
		return node
	for child in node.get_children():
		var found = _find_view(child)
		if found != null:
			return found
	return null
