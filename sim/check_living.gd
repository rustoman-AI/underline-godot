extends SceneTree

## LR1 gate skeleton. Sections 1, 2, 3 and 11 of the Living Rooms spec.
##   godot --headless --path . -s res://sim/check_living.gd -- --living-test
## Draw checks re-exec under xvfb when this process is headless.
##   godot --headless --path . -s res://sim/check_living.gd -- --dump-careful

const SCRATCH := "user://check_living"
const TEXT_KINDS := ["sign", "name", "known", "pip", "badge"]
const BANS := [
	"game.apply(", ".end_week(", "randi(", "randf(", "randomize(",
	"_brownout_ids", "rooms_losing_power", "_generator_yield", "dark_rooms", "WeekForecast.",
	"PointLight2D", "Light2D", "CanvasModulate", "create_tween(",
]
const FROZEN := [
	"data/balance.json", "sim/game.gd", "sim/bot.gd", "sim/save_game.gd",
	"data/names.json", "data/ru.json", "data/ui_strings.json", "data/named_lives.json",
]

var bad: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dump := _flag("--dump-careful")
	var labels_only := _flag("--labels-only")
	if dump:
		_prepare_scratch()
		var catalog := Catalog.new()
		if not catalog.load_all():
			print("LIVING DUMP FAIL catalog")
			quit(1)
			return
		_dump_careful(catalog)
		quit(0)
		return
	_prepare_scratch()
	var failed := false
	if not labels_only:
		if not _section_1():
			failed = true
		if not _section_2():
			failed = true
		if not _section_11():
			failed = true
		if _headless():
			var code := _exec_labels()
			print("SECTION 3 xvfb exit %d" % code)
			if code != 0:
				failed = true
				_bad("section 3 xvfb exit %d" % code)
		elif not await _section_3():
			failed = true
	elif not await _section_3():
		failed = true
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Copy.set_lang("en")
	if failed or not bad.is_empty():
		for line in bad:
			print("FAIL " + line)
		print("LIVING CHECK FAILED")
		quit(1)
		return
	print("LIVING CHECK OK")
	quit(0)


func _section_1() -> bool:
	var text := _git_text(["diff", "-U0", "origin/master", "--", "ui/station.gd", "ui/yard_float_stack.gd", "ui/network_view.gd"])
	text += "\n" + _added_file("res://ui/yard_float_stack.gd")
	var assign := RegEx.new()
	assign.compile("game\\.[A-Za-z_][A-Za-z0-9_]*\\s*=[^=]")
	var rng := RegEx.new()
	rng.compile("(^|[^A-Za-z0-9_])([A-Za-z0-9_]*_rng|\\.rng)([^A-Za-z0-9_]|$)")
	var hits := 0
	for raw in text.split("\n"):
		if not raw.begins_with("+") or raw.begins_with("+++"):
			continue
		var line := raw.substr(1)
		var stripped := line.strip_edges()
		if stripped.begins_with("#") or stripped.begins_with("##"):
			continue
		for ban in BANS:
			if line.contains(ban):
				hits += 1
				_bad("lint %s :: %s" % [ban, stripped])
		if assign.search(line) != null:
			hits += 1
			_bad("lint game write :: %s" % stripped)
		if rng.search(line) != null:
			hits += 1
			_bad("lint rng :: %s" % stripped)
	var living := DirAccess.open("res://ui/living")
	if living != null:
		_bad("lint ui/living exists in LR1")
		hits += 1
	print("SECTION 1 lint %s" % ("ok" if hits == 0 else "FAIL"))
	return hits == 0


func _section_2() -> bool:
	var catalog := Catalog.new()
	if not catalog.load_all():
		_bad("section 2 catalog")
		return false
	var modes := ["off", "on", "reduced"]
	var mismatch := 0
	var started := Time.get_ticks_msec()
	for seed in range(1, 61):
		var base := {}
		for mode in modes:
			_arm_mode(mode)
			var got := _careful(catalog, seed)
			if base.is_empty():
				base = got
			elif not _same_run(base, got):
				mismatch += 1
				_bad("section 2 seed %d mode %s hash %s vs %s over %s/%s" % [seed, mode, str(got.hash), str(base.hash), str(got.over), str(base.over)])
		if seed == 1 or seed % 10 == 0:
			print("SECTION 2 seed %d %s" % [seed, "ok" if mismatch == 0 else "DIFF"])
	_arm_mode("on")
	var elapsed := Time.get_ticks_msec() - started
	print("SECTION 2 parity mismatches %d in %d ms" % [mismatch, elapsed])
	return mismatch == 0


## LR2 will branch these. LR1 has no Living clocks, so the three drivers must still match.
func _arm_mode(mode: String) -> void:
	Settings.reduce_motion = mode == "reduced"
	Settings.loaded = true


func _section_3() -> bool:
	_section_3_clean = true
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.motion_in_shots = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	if not await _browned_holds(st):
		_bad("section 3 browned changed across draws")
	var pairs := _name_pairs()
	var planted := _plant_names(st, pairs)
	var idle: Array = st.yard._idle_ids()
	print("SECTION 3 planted %d idle %d" % [planted, idle.size()])
	if planted < 6 or idle.size() < 6:
		_bad("section 3 need 6 idle, planted %d idle %d" % [planted, idle.size()])
	var views := [
		{"tag": "100", "size": Vector2i(1920, 1080), "scale": 1.0},
		{"tag": "125", "size": Vector2i(1536, 864), "scale": 1.0},
		{"tag": "125scale", "size": Vector2i(1920, 1080), "scale": 1.25},
	]
	for view in views:
		await _apply_view(st, view.size, float(view.scale))
		var viewport: Vector2 = st.get_viewport_rect().size
		print("VIEW %s window %s scale %.2f viewport %s" % [view.tag, view.size, st.get_window().content_scale_factor, viewport])
		if str(view.tag) == "100" and (viewport.x < 1800.0 or viewport.y < 1000.0):
			_bad("%s viewport %s" % [view.tag, viewport])
		if str(view.tag) == "125" and (absf(viewport.x - 1536.0) > 2.0 or absf(viewport.y - 864.0) > 2.0):
			_bad("%s viewport %s" % [view.tag, viewport])
		if str(view.tag) == "125scale" and (st.get_window().content_scale_factor < 1.2 or viewport.y > 900.0):
			_bad("%s scale %s viewport %s" % [view.tag, st.get_window().content_scale_factor, viewport])
		for lang in ["en", "ru"]:
			Copy.set_lang(lang)
			var tag := "%s %s" % [view.tag, lang]
			_clear_floats(st)
			if not await _labels(st, tag):
				pass
			if not await _floats(st, tag):
				pass
	if is_instance_valid(st):
		st.free()
	print("SECTION 3 %s" % ("ok" if _section_3_clean else "FAIL"))
	return _section_3_clean


var _section_3_clean := true


func _labels(st, tag: String) -> bool:
	var before := bad.size()
	st.yard.record_layout = true
	st.yard.queue_redraw()
	for _i in 2:
		await process_frame
	RenderingServer.force_draw()
	var log: Array = st.yard.layout_log.duplicate(true)
	st.yard.record_layout = false
	if log.is_empty():
		_bad("%s labels yard drew nothing" % tag)
		_section_3_clean = false
		return false
	var cells := {}
	var texts := {}
	var names := 0
	var known := 0
	for item in log:
		var kind := str(item.get("kind", ""))
		var key := str(item.get("cell", ""))
		if kind == "cell":
			cells[key] = item.rect
			continue
		if not TEXT_KINDS.has(kind):
			continue
		var bucket: Array = texts.get(key, [])
		bucket.append(item)
		texts[key] = bucket
		if kind == "name":
			names += 1
		elif kind == "known":
			known += 1
	print("LABELS %s names %d known %d cells %d" % [tag, names, known, cells.size()])
	if names < 1 or names > 4:
		_bad("%s labels name count %d" % [tag, names])
	if known < 1:
		_bad("%s labels known word missing" % [tag,])
	for key in texts:
		var group: Array = texts[key]
		var cell: Rect2 = cells.get(key, Rect2())
		for i in group.size():
			var a: Dictionary = group[i]
			var ar: Rect2 = a.rect
			if cell.size.x > 1.0 and not _inside(ar, cell):
				_bad("%s labels %s outside cell %s" % [tag, a.kind, key])
			if str(a.kind) == "name" or str(a.kind) == "known":
				var slot: Rect2 = a.get("slot", Rect2())
				if slot.size.x < 1.0:
					_bad("%s labels %s missing slot" % [tag, a.kind])
				elif not _inside(ar, slot):
					_bad("%s labels %s outside slot %s vs %s" % [tag, a.kind, ar, slot])
			for j in range(i + 1, group.size()):
				var b: Dictionary = group[j]
				if _hits(ar, b.rect):
					_bad("%s labels %s overlaps %s in %s" % [tag, a.kind, b.kind, key])
		var idle_n: int = st.yard._idle_ids().size()
		if idle_n > 2 and key == _platform_key(st):
			var pip := false
			for item in group:
				if str(item.kind) == "pip":
					pip = true
			if not pip:
				_bad("%s labels platform pip missing" % tag)
	if bad.size() > before:
		_section_3_clean = false
		return false
	return true


func _floats(st, tag: String) -> bool:
	var before := bad.size()
	var line := Copy.fill("salvage.fitted", {"name": Copy.t("salvage.node.grow_lamps")})
	st._yard_float(line, "")
	st._show_obs_float(Copy.t("obs.first_mark"))
	for _i in 2:
		await process_frame
	if not _pair_clear(st, tag, "t0"):
		pass
	st._show_home_float()
	for _i in 2:
		await process_frame
	var home := _node_rect(st.home_float)
	var salvage := _node_rect(st.salvage_float)
	var obs := _node_rect(st.obs_float)
	if _hits(home, salvage) or _hits(home, obs):
		_bad("%s float home intersects salvage %s obs %s home %s" % [tag, salvage, obs, home])
	for step in 4:
		await create_timer(0.5).timeout
		_pair_clear(st, tag, "t%.1f" % (float(step + 1) * 0.5))
	if bad.size() > before:
		_section_3_clean = false
		return false
	return true


func _pair_clear(st, tag: String, when: String) -> bool:
	var salvage := _node_rect(st.salvage_float)
	var obs := _node_rect(st.obs_float)
	if salvage.size.x < 1.0 or obs.size.x < 1.0:
		print("FLOATS %s %s salvage-gone %s obs-gone %s" % [tag, when, salvage.size.x < 1.0, obs.size.x < 1.0])
		return true
	if _hits(salvage, obs):
		_bad("%s float overlap %s %s | %s" % [tag, when, salvage, obs])
		return false
	if obs.position.y < salvage.position.y - 0.5:
		_bad("%s float obs above salvage %s %s | %s" % [tag, when, salvage, obs])
		return false
	print("FLOATS %s %s ok salvage %s obs %s" % [tag, when, salvage, obs])
	return true


func _browned_holds(st) -> bool:
	var before := _browned_map(st.game)
	var hash_before := hash(var_to_str(st.game.export_state()))
	for _i in 100:
		st.yard.queue_redraw()
		await process_frame
	var after := _browned_map(st.game)
	var hash_after := hash(var_to_str(st.game.export_state()))
	if hash_before != hash_after:
		_bad("section 3 export hash moved across 100 draws")
		_section_3_clean = false
		return false
	for uid in before:
		if bool(before[uid]) != bool(after.get(uid, false)):
			_section_3_clean = false
			return false
	print("SECTION 3 browned stable, draw hash held")
	return true


func _section_11() -> bool:
	if Game.SAVE_SCHEMA != 27:
		_bad("section 11 schema %s" % str(Game.SAVE_SCHEMA))
		print("SECTION 11 FAIL schema")
		return false
	var text := _git_text(["diff", "--name-only", "origin/master"])
	var hits := 0
	for raw in text.split("\n"):
		var path := raw.strip_edges()
		if path == "" or path.begins_with("diff "):
			continue
		if FROZEN.has(path):
			hits += 1
			_bad("section 11 touched %s" % path)
	print("SECTION 11 schema 27 frozen %s" % ("ok" if hits == 0 else "FAIL"))
	print("SECTION 11 sibling gates run as their own processes: check_notice_layout, check_save, check_release_polish, check_chrome_nits, check_yard_clearance")
	return hits == 0


func _dump_careful(catalog: Catalog) -> void:
	for seed in range(1, 61):
		var got := _careful(catalog, seed)
		var rngs: Array = got.rng
		print("CAREFUL %d %s %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d" % [
			seed, str(got.hash), str(got.over), int(got.week), int(got.hope), int(got.discontent), int(got.residents),
			int(got.food), int(got.materials), int(got.air), int(got.power), int(got.tokens), int(got.influence),
			int(rngs[0]), int(rngs[1]), int(rngs[2]), int(rngs[3]), int(rngs[4])])
		if seed % 10 == 0:
			print("DUMP seed %d" % seed)


func _careful(catalog: Catalog, run_seed: int) -> Dictionary:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		bot._act(game)
		game.end_week()
	var stock: Dictionary = game.stock
	return {
		"hash": hash(var_to_str(game.export_state())),
		"rng": [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
		"over": str(game.over),
		"week": int(game.week),
		"hope": int(game.hope),
		"discontent": int(game.discontent),
		"residents": game.residents.size(),
		"food": int(stock.get("food", 0)),
		"materials": int(stock.get("materials", 0)),
		"air": int(stock.get("air", 0)),
		"power": int(stock.get("power", 0)),
		"tokens": int(stock.get("tokens", 0)),
		"influence": int(stock.get("influence", 0)),
	}


func _same_run(a: Dictionary, b: Dictionary) -> bool:
	for key in a:
		if str(a[key]) != str(b[key]):
			return false
	return true


func _exec_labels() -> int:
	var godot := OS.get_executable_path()
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var output: Array = []
	var args := PackedStringArray([
		"-a", "-s", "-screen 0 1920x1080x24", godot, "--rendering-driver", "opengl3", "--path", project,
		"-s", "res://sim/check_living.gd", "--", "--living-test", "--labels-only",
	])
	var code := OS.execute("/usr/bin/xvfb-run", args, output, true)
	for line in output:
		print(str(line))
	return code


func _prepare_scratch() -> void:
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = true
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	Settings.loaded = true
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")


func _apply_view(st, win_size: Vector2i, scale: float) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	Settings.loaded = true
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	if absf(scale - 1.0) < 0.01:
		win.content_scale_factor = 1.0
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_size = win_size
	else:
		Settings.apply_scale(win)
	st._layout()
	for _i in 4:
		await process_frame


func _plant_names(st, pairs: Array) -> int:
	var game = st.game
	for room in game.rooms:
		room.staff.clear()
	if typeof(game.dig) == TYPE_DICTIONARY and not game.dig.is_empty():
		game.dig["workers"] = []
	if typeof(game.build) == TYPE_DICTIONARY and not game.build.is_empty():
		game.build["workers"] = []
	var n := 0
	for person in game.residents:
		if n >= pairs.size():
			break
		person.absent = 0
		person.name = str(pairs[n].en)
		person.name_ru = str(pairs[n].ru)
		person.memory = 80
		n += 1
	return n


func _name_pairs() -> Array:
	var file := FileAccess.open("res://data/names.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	var pairs: Array = []
	for first in data.first:
		for last in data.last:
			var en := "%s %s" % [str(first), str(last)]
			Copy.set_lang("ru")
			var ru := Copy.person(en)
			Copy.set_lang("en")
			pairs.append({"en": en, "ru": ru, "rank": maxi(en.length(), ru.length())})
	pairs.sort_custom(func(a, b): return int(a.rank) > int(b.rank))
	return pairs.slice(0, 6)


func _platform_key(st) -> String:
	for room in st.game.rooms:
		if str(room.get("type", "")) == "platform":
			return "%d:%d" % [int(room.level), int(room.cell)]
	return ""


func _browned_map(game) -> Dictionary:
	var out := {}
	for room in game.rooms:
		out[str(room.uid)] = bool(room.get("browned", false))
	return out


func _node_rect(node) -> Rect2:
	if node == null or not is_instance_valid(node) or not node.visible:
		return Rect2()
	return node.get_global_rect()


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 1.0 \
		and inner.position.y >= outer.position.y - 1.0 \
		and inner.end.x <= outer.end.x + 1.0 \
		and inner.end.y <= outer.end.y + 1.0


func _hits(a: Rect2, b: Rect2) -> bool:
	if a.size.x < 1.0 or b.size.x < 1.0 or not a.intersects(b):
		return false
	var overlap := a.intersection(b)
	return overlap.size.x > 1.0 and overlap.size.y > 1.0


func _clear_floats(st) -> void:
	if st.obs_float_tween != null and is_instance_valid(st.obs_float_tween) and st.obs_float_tween.is_valid():
		st.obs_float_tween.kill()
	if st.home_float_tween != null and is_instance_valid(st.home_float_tween) and st.home_float_tween.is_valid():
		st.home_float_tween.kill()
	for key in ["salvage_float", "obs_float", "home_float"]:
		var node = st.get(key)
		if node != null and is_instance_valid(node):
			node.visible = false
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
		st.set(key, null)


func _added_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var body := file.get_as_text()
	file.close()
	var out := ""
	for line in body.split("\n"):
		out += "+" + line + "\n"
	return out


func _git_text(args: Array) -> String:
	var output: Array = []
	OS.execute("git", PackedStringArray(args), output, true)
	var text := ""
	for line in output:
		text += str(line)
	return text


func _flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)


func _headless() -> bool:
	return OS.has_feature("headless") or DisplayServer.get_name() == "headless"


func _bad(msg: String) -> void:
	bad.append(msg)
	print("FAIL " + msg)


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir() and name != "." and name != "..":
			_wipe(sub)
			dir.remove(name)
		elif name != "." and name != "..":
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
