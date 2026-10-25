extends SceneTree

## Residents seen together look different, and building sites use the drawn set.
##   godot --path . -s res://.tools/residents_distinct_shots.gd -- --size=1280x720
## DUPES  test stations (seeds 1..8, expander bot, weeks 1, 10, 19, 31, then week 31 with every room type
##        placed and fully staffed): every group drawn together (a room's crew, a quarters' sleepers, the
##        platform, a site crew) is checked for two people with the same stem and palette while the group's
##        pool still had an unused look. "old" counts the groups the per-id pick drew with a twin.
## SITE   seed 1 at week 19 with a workshop being built and a cell being dug (materials topped up in memory):
##        which figure each builder and digger gets. Any old fig_* pose there is a FAIL.
## RELOAD every group's looks after a manual save and load.
## Writes shots/residents_distinct/<size>/site.png, site_reloaded.png and 2x crops of the build and dig cells.
## Saves go to user://residents_distinct_shots/, never the player's slots.

const OUT := "res://shots/residents_distinct"
const SAVE_ROOT := "user://residents_distinct_shots/"
const ROOM_TYPES := ["quarters", "hydroponics", "air_filter", "generator", "workshop", "infirmary", "meeting_hall", "radio"]
const SEEDS := 8
const CHECK_WEEKS := [1, 10, 19, 31]

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
	_dupes()

	_fresh(1)
	var bot := Bot.new()
	bot.profile = "expander"
	while st.game.week < 19 and st.game.over == "":
		bot._act(st.game)
		st.game.end_week()
	_complete_rooms()
	_stage_site()
	_quiet()
	_site()
	await _shoot("site")
	var before := _looks()
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
	var after := _looks()
	var diff: PackedStringArray = []
	for key in before:
		if str(after.get(key, "")) != str(before[key]):
			diff.append("%s: %s -> %s" % [key, before[key], after.get(key, "missing")])
	print("RELOAD %s: %d groups, %d changed%s" % ["OK" if diff.is_empty() and before.size() == after.size() else "FAIL", before.size(), diff.size(), "" if diff.is_empty() else "; " + "; ".join(diff)])
	await _shoot("site_reloaded")
	print("SHOTS %s done" % size)
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


func _fresh(run_seed: int) -> void:
	var g := Game.new()
	g.setup(st.game.catalog, run_seed, 40)
	st.game = g


func _dupes() -> void:
	var groups := 0
	var bad: PackedStringArray = []
	var old := 0
	var forced := 0
	for run_seed in range(1, SEEDS + 1):
		_fresh(run_seed)
		var bot := Bot.new()
		bot.profile = "expander"
		for week in CHECK_WEEKS:
			while st.game.week < week and st.game.over == "":
				bot._act(st.game)
				st.game.end_week()
			for stage in (["natural", "full"] if week == CHECK_WEEKS[-1] else ["natural"]):
				if stage == "full":
					_complete_rooms()
				for group in _groups():
					if group.ids.size() < 2:
						continue
					groups += 1
					var looks: Array = group.looks
					var distinct := {}
					for tex in looks:
						distinct[tex] = true
					var pool := {}
					for stem in group.pool:
						for tex in view.fig_variants.get(stem, []):
							pool[tex] = true
					if distinct.size() < mini(looks.size(), pool.size()):
						bad.append("seed %d week %d %s %s: %s" % [run_seed, st.game.week, stage, group.name, _names(looks)])
					elif distinct.size() < looks.size():
						forced += 1
					var per_id := {}
					for id in group.ids:
						per_id[view._fig_for(group.pool, str(id))] = true
					if per_id.size() < group.ids.size():
						old += 1
	print("DUPES %s: %d groups of 2+ checked, %d with a twin while another look was free, %d with more people than looks; old per-id pick had a twin in %d" % ["OK" if bad.is_empty() else "FAIL", groups, bad.size(), forced, old])
	for line in bad:
		print("DUPES   ", line)


## Every set of residents the station draws side by side, with the stems it draws them from and the looks it picks.
func _groups() -> Array:
	var out: Array = []
	var g: Game = st.game
	for room in g.rooms:
		var type := str(room.type)
		if type == "quarters":
			var ids: Array = view._quarters_ids(str(room.uid)).slice(0, 3)
			var pool: Array = view.room_figs.get("quarters", view.body_figs)
			out.append({"name": "quarters %s" % room.uid, "pool": pool, "ids": ids, "looks": view._figs_for_group(pool, ids)})
			continue
		if type == "platform":
			continue
		var spots: Array = g.catalog.rooms[type].get("spots", [])
		var ids: Array = room.staff.slice(0, mini(room.staff.size(), mini(spots.size(), 3)))
		var own: Array = view.room_figs.get(type, [])
		var pool: Array = own if not own.is_empty() else view.body_figs
		out.append({"name": "%s %s" % [type, room.uid], "pool": pool, "ids": ids, "looks": view._figs_for_group(pool, ids)})
	var idle: Array = view._idle_ids().slice(0, 2)
	out.append({"name": "platform", "pool": view.body_figs, "ids": idle, "looks": view._figs_for_group(view.body_figs, idle)})
	if not g.build.is_empty():
		var ids: Array = g.build.workers.slice(0, 4)
		var pool: Array = view.BUILDER_FIGS.filter(func(s): return view.fig_variants.has(s))
		out.append({"name": "build", "pool": pool, "ids": ids, "looks": view._figs_for_group(pool, ids)})
	if not g.dig.is_empty():
		var ids: Array = g.dig.workers.slice(0, 4)
		out.append({"name": "dig", "pool": view.body_figs, "ids": ids, "looks": view._figs_for_group(view.body_figs, ids)})
	return out


func _looks() -> Dictionary:
	var out := {}
	for group in _groups():
		out["%s [%s]" % [group.name, ",".join(PackedStringArray(group.ids))]] = _names(group.looks)
	return out


func _complete_rooms() -> void:
	var g: Game = st.game
	var have := {}
	for room in g.rooms:
		have[str(room.type)] = true
	for type in ROOM_TYPES:
		if have.has(type):
			continue
		var spot := _free_cell(true)
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


func _free_cell(dig_it: bool) -> Dictionary:
	var g: Game = st.game
	for key in g.cells:
		var c: Dictionary = g.cells[key]
		if g._cell_buildable(c):
			return c
	if not dig_it:
		return {}
	for key in g.cells:
		var c: Dictionary = g.cells[key]
		if not c.dug and str(c.room) == "" and not c.flooded and not c.walled:
			c.dug = true
			return c
	return {}


## A workshop under construction and a cell being dug, both through the game's own orders.
func _stage_site() -> void:
	var g: Game = st.game
	g.stock.materials = 99
	g.build = {}
	g.dig = {}
	var spot := _free_cell(true)
	if spot.is_empty() or not g._apply_build("workshop", int(spot.level), int(spot.cell)):
		print("STAGE build failed: %s" % ", ".join(PackedStringArray(g.errors)))
	if not g._apply_dig(false):
		print("STAGE dig failed")
	g.build.left = maxi(1, int(g.build.get("left", 1)) - 1)


func _site() -> void:
	var stray := 0
	for group in _groups():
		if group.name != "build" and group.name != "dig":
			continue
		for tex in group.looks:
			if tex == null or not _drawn(tex):
				stray += 1
		print("SITE %s at L%dC%d, %d workers: %s" % [group.name, int(st.game[group.name].level), int(st.game[group.name].cell), group.ids.size(), _names(group.looks)])
	print("SITE %s: %d old fig_* poses on site crews" % ["OK" if stray == 0 else "FAIL", stray])


func _drawn(tex: Texture2D) -> bool:
	for stem in view.fig_variants:
		if view.fig_variants[stem].has(tex):
			return true
	return false


func _names(looks: Array) -> String:
	var out: PackedStringArray = []
	for tex in looks:
		out.append(_name_of(tex))
	return ", ".join(out)


func _name_of(tex: Texture2D) -> String:
	if tex == null:
		return "none"
	for stem in view.fig_variants:
		var variants: Array = view.fig_variants[stem]
		var at := variants.find(tex)
		if at >= 0:
			return "%s/%s" % [stem, "base" if at == 0 else tex.resource_path.get_base_dir().get_file()]
	return tex.resource_path.get_file()


func _shoot(name: String) -> void:
	st._refresh()
	view.queue_redraw()
	await create_timer(0.5).timeout
	await st._frame()
	await st._frame()
	var img: Image = st.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(dir.path_join(name + ".png")))
	var origin: Vector2 = view.get_global_rect().position
	for job in ["build", "dig"]:
		var at: Dictionary = st.game[job]
		if at.is_empty():
			continue
		var box: Rect2 = view.cell_screen(int(at.level), int(at.cell))
		box.position += origin
		var cut := Rect2i(box).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if cut.size.x < 8 or cut.size.y < 8:
			print("SHOT %s %s cell off screen" % [name, job])
			continue
		var crop := img.get_region(cut)
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(ProjectSettings.globalize_path(dir.path_join("crop_%s_%s.png" % [name, job])))


func _find_view(node: Node) -> Object:
	if "body_figs" in node and node.has_method("cell_screen"):
		return node
	for child in node.get_children():
		var found = _find_view(child)
		if found != null:
			return found
	return null
