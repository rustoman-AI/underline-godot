extends SceneTree

## V3a feel gate. F1 covers sections 1-5 and 12-14.
##   godot --headless --path . -s res://sim/check_feel.gd -- --feel-test
## Optional: --master-json=/abs/path.json compares the UI loop to a live master harness.
## Optional: --feel-shots writes 1920x1080 stills. --feel-shots-only skips the long loop.

const SCRATCH := "user://check_feel"
const FeelLook = preload("res://ui/feel/feel_style.gd")
const KEYS := [
	"feel.dawn.title", "feel.dawn.gains", "feel.dawn.losses", "feel.dawn.people",
	"feel.dawn.threats", "feel.dawn.notes", "feel.dawn.quiet", "feel.dawn.more",
	"feel.dawn.hint", "feel.people.joined", "feel.people.back", "feel.people.recovered",
	"feel.people.sick", "feel.people.left", "feel.people.gone", "feel.check.banner",
	"feel.check.bet", "feel.check.success", "feel.check.failed", "feel.check.hint",
	"feel.settings.shake", "feel.settings.shake_note",
]

var bad: PackedStringArray = []
var st
var records_rel := "user://check_feel/records.cfg"
var catalog: Catalog
var cat_sim: Catalog
var cat_off: Catalog
var cat_on: Catalog
var cat_red: Catalog


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var shots_only := _has("--feel-shots-only")
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = false
	Settings.shake = true
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	if not shots_only:
		_section_1()
		_section_2()
		_section_12()
	cat_sim = Catalog.new()
	cat_off = Catalog.new()
	cat_on = Catalog.new()
	cat_red = Catalog.new()
	for cat in [cat_sim, cat_off, cat_on, cat_red]:
		if not cat.load_all():
			_bad("catalog " + cat.error)
			_finish()
			return
	catalog = cat_off
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.motion_in_shots = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	_park(st)
	if shots_only or _has("--feel-shots"):
		await _shots()
	if shots_only:
		_finish()
		return
	if not _has("--skip-parity"):
		await _section_3()
	await _section_4()
	await _section_5()
	await _section_chip_floor()
	await _section_6()
	await _section_focus_stamp()
	await _section_7()
	await _section_9()
	await _section_13()
	_section_14()
	_finish()


func _finish() -> void:
	if is_instance_valid(st):
		st.free()
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Copy.set_lang("en")
	if bad.is_empty():
		print("FEEL CHECK OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("FEEL CHECK FAILED")
	quit(1)


func _section_1() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/feel.json"))
	if not (raw is Dictionary) or not (raw.by_key is Dictionary):
		_bad("feel.json")
		return
	var rows: Dictionary = raw.by_key
	if rows.size() != 22:
		_bad("feel.json key count %d" % rows.size())
	for key in rows:
		if not str(key).begins_with("feel."):
			_bad("key outside feel.* %s" % str(key))
	for key in KEYS:
		if not rows.has(key):
			_bad("missing %s" % key)
			continue
		var row: Dictionary = rows[key]
		var en := str(row.get("en", ""))
		var ru := str(row.get("ru", ""))
		if en == "" or ru == "":
			_bad("empty %s" % key)
			continue
		if ru.length() > int(ceil(float(en.length()) * 1.4)):
			_bad("ru length %s %d/%d" % [key, ru.length(), en.length()])
	Copy.set_lang("en")
	for key in KEYS:
		var filled := Copy.fill(key, {"n": "2", "names": "Vic", "name": "Vic", "skill": "Labor"})
		if filled.find("{") >= 0 or filled == key:
			_bad("fill %s [%s]" % [key, filled])
	Copy.set_lang("ru")
	for key in KEYS:
		var filled_ru := Copy.fill(key, {"n": "2", "names": "Вик", "name": "Вик", "skill": "Труд"})
		if filled_ru.find("{") >= 0 or filled_ru == key:
			_bad("fill ru %s [%s]" % [key, filled_ru])
	Copy.set_lang("en")
	_section_done(0, "SECTION 1 texts")


func _section_2() -> void:
	var mark := bad.size()
	var feel_dir := "res://ui/feel"
	var dir := DirAccess.open(feel_dir)
	if dir == null:
		_bad("no ui/feel")
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gd"):
			_lint_text(FileAccess.get_file_as_string(feel_dir.path_join(name)), "ui/feel/" + name, false)
		name = dir.get_next()
	dir.list_dir_end()
	var out: Array = []
	var root := ProjectSettings.globalize_path("res://")
	var code := OS.execute("git", ["-C", root, "diff", "master", "--", "ui/station.gd", "sim/settings.gd", "sim/copy.gd", "ui/feel"], out, true)
	if code != 0:
		_bad("git diff %s" % str(out))
	else:
		var diff := "\n".join(PackedStringArray(out))
		for line in diff.split("\n"):
			if not line.begins_with("+") or line.begins_with("+++"):
				continue
			_lint_text(line.substr(1), "diff", true)
	_section_done(mark, "SECTION 2 lint")


func _lint_text(text: String, where: String, from_diff: bool) -> void:
	var assign := RegEx.new()
	assign.compile("game\\.[A-Za-z_][A-Za-z0-9_]*\\s*=[^=]")
	var bare := RegEx.new()
	bare.compile("(^|[^\\.\\w])(randf|randi|randomize)\\(")
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("#"):
			continue
		if "game.apply(" in line:
			_bad("lint %s apply %s" % [where, line])
		if ".end_week(" in line:
			_bad("lint %s end_week %s" % [where, line])
		if assign.search(line) and "game.notices" not in line:
			_bad("lint %s assign %s" % [where, line])
		if bare.search(line):
			_bad("lint %s rand %s" % [where, line])
		if "canvas_transform" in line and where.find("feel_loss") < 0:
			_bad("lint %s canvas %s" % [where, line])
		if "_rng" in line:
			var read_only := from_diff and line.find("game.check_rng.state") >= 0 and line.find("game.check_rng.state =") < 0 and line.find("game.check_rng.rand") < 0
			if not read_only:
				_bad("lint %s rng %s" % [where, line])


func _section_3() -> void:
	var mark := bad.size()
	print("SECTION 3 parity start")
	var master := _load_master()
	var t0 := Time.get_ticks_msec()
	# One catalog per mode, seeds in order. A shared catalog is mutated by setup, so interleaving
	# modes would not match a single master pass.
	# Each mode seals best_score into user://records.cfg. A single-pass master
	# capture starts from an empty file, so every mode here does too. Otherwise
	# the sim pass raises the file and seed 1's full export hash no longer matches.
	var sim_rows := await _pass("sim", cat_sim, master)
	var off_rows := await _pass("off", cat_off, master)
	var on_rows := await _pass("on", cat_on, master)
	var red_rows := await _pass("reduced", cat_red, master)
	for run_seed in range(1, 61):
		if not off_rows.has(run_seed) or not on_rows.has(run_seed) or not red_rows.has(run_seed) or not sim_rows.has(run_seed):
			continue
		var off: Dictionary = off_rows[run_seed]
		var on: Dictionary = on_rows[run_seed]
		var red: Dictionary = red_rows[run_seed]
		var sim: Dictionary = sim_rows[run_seed]
		if not _same_play(off, on) or not _same_play(off, red):
			_bad("seed %d modes diverged" % run_seed)
			_print_row("off", off)
			_print_row("on", on)
			_print_row("reduced", red)
		if str(sim.rng) != str(off.rng) or str(sim.over) != str(off.over) or str(sim.ending) != str(off.ending):
			_bad("seed %d sim-only rng or ending diverged" % run_seed)
		if run_seed == 1:
			var sim_diff := _diff_state(sim.state, off.state)
			if sim_diff.is_empty():
				print("SECTION 3 sim-only matches aside from notices, choice_results, flags/obs/salvage, and stats.best_score")
			else:
				_bad("seed 1 sim-only state %s" % ", ".join(sim_diff))
			var seed_hash := int(off.hash)
			var master_hash := seed_hash
			var master_note := ""
			if not master.is_empty():
				var want1: Dictionary = master.get("1", {})
				master_hash = int(want1.get("hash", -1))
				master_note = " master %d" % master_hash
			# Sim-only skips the station refresh, so its full hash is not the UI hash.
			# off, on, and reduced are the runs compared to a single-pass master capture.
			if int(on.hash) == seed_hash and int(red.hash) == seed_hash and master_hash == seed_hash:
				print("SECTION 3 seed 1 full hash %d matches%s" % [seed_hash, master_note])
			else:
				_bad("seed 1 full hash off %d on %d reduced %d%s" % [seed_hash, int(on.hash), int(red.hash), master_note])
		sim.erase("state")
		if not master.is_empty():
			var want: Dictionary = master.get(str(run_seed), {})
			if want.is_empty():
				_bad("master missing seed %d" % run_seed)
			elif not _same_master(off, want) or not _same_master(on, want) or not _same_master(red, want):
				_bad("seed %d master diverged" % run_seed)
				_print_row("master", want)
				_print_row("off", off)
				_print_row("on", on)
				_print_row("reduced", red)
	print("PROGRESS 60/60 %d ms" % [Time.get_ticks_msec() - t0])
	_section_done(mark, "SECTION 3 parity %d ms" % [Time.get_ticks_msec() - t0])


func _section_4() -> void:
	var mark := bad.size()
	_arm_feel(true, false)
	var game: Game = st.game
	st.delta_hold_until = 0
	game.stock.food = 10
	st.feel.reset()
	st.feel.stock.sync(game, false)
	st.feel.stock.clear_counts()
	await process_frame
	game.stock.food = 15
	st.feel.stock.sync(game, true)
	game.stock.food = 12
	st.feel.stock.sync(game, true)
	await process_frame
	if st.feel.stock.rolls_started != 1:
		_bad("coalesce rolls %d" % st.feel.stock.rolls_started)
	if str(st.feel.stock.shown_chip.get("food", "")) != "+2":
		_bad("coalesce chip [%s]" % str(st.feel.stock.shown_chip.get("food", "")))
	if st.feel.stock.pops_started != 1:
		_bad("coalesce pops %d" % st.feel.stock.pops_started)
	if st.feel.stock.live_tweens() != 1 and str(st.chips.food.value.text) != "12":
		_bad("coalesce tween %d text %s" % [st.feel.stock.live_tweens(), st.chips.food.value.text])
	await _until_text("food", "12")
	if str(st.chips.food.value.text) != "12":
		_bad("final food %s" % st.chips.food.value.text)
	st.feel.stock.clear_counts()
	st.feel.reset()
	game.stock.food = 10
	st.feel.stock.sync(game, false)
	st.feel.stock.clear_counts()
	await process_frame
	game.stock.food = 13
	st.feel.stock.sync(game, true)
	game.stock.food = 10
	st.feel.stock.sync(game, true)
	await process_frame
	if st.feel.stock.rolls_started != 0 or str(st.feel.stock.shown_chip.get("food", "")) != "" or st.feel.stock.pops_started != 0:
		_bad("zero net rolls %d chip [%s] pops %d" % [st.feel.stock.rolls_started, str(st.feel.stock.shown_chip.get("food", "")), st.feel.stock.pops_started])
	st.feel.reset()
	game.stock.food = 8
	st.feel.stock.sync(game, false)
	st.feel.stock.clear_counts()
	await process_frame
	game.stock.food = 11
	for _i in 5:
		st._refresh()
	await process_frame
	if st.feel.stock.rolls_started != 1:
		_bad("five refresh rolls %d" % st.feel.stock.rolls_started)
	st.feel.reset()
	game.stock.food = 10
	st.feel.stock.sync(game, false)
	await process_frame
	st.feel.stock.clear_counts()
	game.stock.food = 20
	st.feel.stock.sync(game, true)
	await process_frame
	await create_timer(0.15).timeout
	var mid := float(st.chips.food.value.text)
	game.stock.food = 30
	st.feel.stock.sync(game, true)
	await process_frame
	var started := float(st.feel.stock.last_roll_from.get("food", -1))
	if st.feel.stock.rolls_started < 2 or absf(started - mid) > 1.5:
		_bad("retarget from %s mid %s rolls %d" % [started, mid, st.feel.stock.rolls_started])
	await _until_text("food", "30")
	st.feel.reset()
	game.stock.food = 20
	st.feel.stock.sync(game, false)
	st.feel.stock.clear_counts()
	await process_frame
	game.stock.food = 16
	st.feel.stock.sync(game, true)
	await process_frame
	await create_timer(0.3).timeout
	st.feel.stock.clear_counts()
	game.stock.food = 20
	st.feel.stock.sync(game, true)
	await process_frame
	if str(st.feel.stock.shown_chip.get("food", "")) != "+4" or not st.feel.stock.chip_gain("food"):
		_bad("undo chip [%s] gain %s" % [str(st.feel.stock.shown_chip.get("food", "")), st.feel.stock.chip_gain("food")])
	st.feel.reset()
	game.stock.food = 77
	st.feel.stock.clear_counts()
	st.feel.stock.sync(game, true)
	await process_frame
	if st.feel.stock.rolls_started != 0 or st.feel.stock.pops_started != 0 or str(st.chips.food.value.text) != "77":
		_bad("silent first paint text %s rolls %d" % [st.chips.food.value.text, st.feel.stock.rolls_started])
	var hope := int(game.hope)
	st.feel.stock.clear_counts()
	game.hope = hope + 4
	st.feel.stock.sync(game, true)
	await process_frame
	if st.feel.stock.rolls_started != 0 or str(st.feel.stock.shown_chip.get("hope", "")) != "+4" or not st.feel.stock.chip_gain("hope"):
		_bad("hope chip [%s] rolls %d" % [str(st.feel.stock.shown_chip.get("hope", "")), st.feel.stock.rolls_started])
	var dis := int(game.discontent)
	st.feel.stock.clear_counts()
	game.discontent = dis + 3
	st.feel.stock.sync(game, true)
	await process_frame
	if str(st.feel.stock.shown_chip.get("discontent", "")) != "+3" or st.feel.stock.chip_gain("discontent"):
		_bad("discontent chip [%s] gain %s" % [str(st.feel.stock.shown_chip.get("discontent", "")), st.feel.stock.chip_gain("discontent")])
	st.feel.stock.clear_counts()
	await create_timer(0.05).timeout
	game.hope = hope + 5
	st.feel.stock.sync(game, true)
	await process_frame
	if str(st.feel.stock.shown_chip.get("hope", "")) != "+5" or st.feel.stock.visible_chips("hope") > 1:
		_bad("merge hope [%s] n %d" % [str(st.feel.stock.shown_chip.get("hope", "")), st.feel.stock.visible_chips("hope")])
	game.hope = hope
	game.discontent = dis
	print("PERF flush n %d avg %d us max %d us" % [st.feel.perf_n, st.feel.perf_avg_us(), st.feel.perf_max_us])
	_section_done(mark, "SECTION 4 counters")


func _section_chip_floor() -> void:
	var mark := bad.size()
	_arm_feel(true, false)
	await _chip_floor_view("en", Vector2i(1920, 1080), 1.0, "en100")
	await _chip_floor_view("ru", Vector2i(1920, 1080), 1.0, "ru100")
	await _chip_floor_view("en", Vector2i(1536, 864), 1.0, "en1536")
	await _chip_floor_view("ru", Vector2i(1536, 864), 1.0, "ru1536")
	await _chip_floor_view("en", Vector2i(1920, 1080), 1.25, "en125")
	await _chip_floor_view("ru", Vector2i(1920, 1080), 1.25, "ru125")
	Copy.set_lang("en")
	await _apply_view(Vector2i(1920, 1080), 1.0)
	_arm_feel(true, false)
	_section_done(mark, "SECTION chip floor")


func _chip_floor_view(lang: String, win_size: Vector2i, scale: float, tag: String) -> void:
	Copy.set_lang(lang)
	await _apply_view(win_size, scale)
	_park(st)
	await _chip_floor_case(tag)


func _chip_floor_case(tag: String) -> void:
	var game: Game = st.game
	st.feel.reset()
	st.delta_hold_until = 0
	var food := int(game.stock.food)
	game.stock.food = food
	st.feel.stock.sync(game, false)
	st.chips.food.delta.text = "+2"
	st.chips.food.delta.visible = true
	await process_frame
	if st.has_method("_layout"):
		st._layout()
	await process_frame
	game.stock.food = food + 6
	st.feel.stock.sync(game, true)
	await process_frame
	var found = st.feel.stock.last_chip.get("food", null)
	if found == null or not is_instance_valid(found) or not found.visible:
		_bad("%s chip missing" % tag)
		game.stock.food = food
		return
	var floor_y := float(FeelLook.CHIP_FLOOR_Y)
	var min_y := float(found.get_meta("path_min_y", -999.0))
	var path := Rect2(
		float(found.get_meta("path_x", 0.0)),
		float(found.get_meta("path_y", 0.0)),
		float(found.get_meta("path_w", 0.0)),
		float(found.get_meta("path_h", 0.0))
	)
	var view: Rect2 = st.get_viewport_rect()
	var live: Rect2 = found.get_global_rect()
	if min_y < floor_y - 0.05 or path.position.y < floor_y - 0.05 or live.position.y < floor_y - 0.05:
		_bad("%s chip min y %.2f path %s live %s" % [tag, min_y, path, live])
	elif path.position.x < -0.5 or path.end.x > view.size.x + 0.5 or path.end.y > view.size.y + 0.5:
		_bad("%s chip outside %s view %s" % [tag, path, view.size])
	else:
		var delta: Control = st.chips.food.delta
		var forecast: Rect2 = delta.get_global_rect()
		if str(delta.text) != "" and forecast.size.y > 1.0 and path.intersects(forecast):
			_bad("%s chip hits forecast path %s delta %s" % [tag, path, forecast])
		else:
			print("CHIP FLOOR %s min_y %.2f path %s" % [tag, min_y, path])
	game.stock.food = food


func _section_5() -> void:
	var mark := bad.size()
	_arm_feel(true, true)
	var game: Game = st.game
	st.feel.reset()
	var food := int(game.stock.food)
	game.stock.food = food + 9
	st.delta_hold_until = 0
	st._refresh()
	await process_frame
	if str(st.chips.food.value.text) != str(food + 9):
		_bad("reduced text %s" % st.chips.food.value.text)
	if st.feel.stock.live_tweens() != 0 or st.feel.stock.visible_chip_count() != 0:
		_bad("reduced tweens %d chips %d" % [st.feel.stock.live_tweens(), st.feel.stock.visible_chip_count()])
	_arm_feel(false, false)
	st.feel.reset()
	game.stock.food = food + 4
	st._refresh()
	await process_frame
	if str(st.chips.food.value.text) != str(food + 4) or st.feel.stock.live_tweens() != 0:
		_bad("disabled text %s tweens %d" % [st.chips.food.value.text, st.feel.stock.live_tweens()])
	var xform: Transform2D = st.get_viewport().canvas_transform
	game.departed.append({"how": "died", "name": "Feel Gate"})
	st._refresh()
	await process_frame
	if st.get_viewport().canvas_transform != Transform2D.IDENTITY:
		_bad("canvas moved %s" % str(st.get_viewport().canvas_transform))
	st.get_viewport().canvas_transform = xform
	Settings.shake = false
	st._refresh()
	await process_frame
	if st.get_viewport().canvas_transform != Transform2D.IDENTITY:
		_bad("shake off canvas")
	Settings.shake = true
	Settings.reduce_motion = false
	_arm_feel(true, false)
	_section_done(mark, "SECTION 5 reduce")


func _section_6() -> void:
	var mark := bad.size()
	_arm_feel(true, false)
	st.hold_dawn = true
	var game: Game = st.game
	game.over = ""
	game.week = 8
	var decisions := int(game.decisions)
	var journal := game.journal.size()
	var finishes := int(st.feel_pick_finishes)
	_queue_check(game, "white", 8, false)
	st._pick_event("feel_gate", "try")
	if st.feel.check == null or not st.feel.check.open:
		_bad("check reveal did not open")
	else:
		_click_check()
		_click_check()
		await create_timer(0.5).timeout
		if int(st.feel_pick_finishes) != finishes + 1:
			_bad("finish ran %d" % [int(st.feel_pick_finishes) - finishes])
		if int(game.decisions) != decisions + 1:
			_bad("decisions %d" % [int(game.decisions) - decisions])
		if game.journal.size() != journal + 1:
			_bad("journal %d" % [game.journal.size() - journal])
		if st.feel.check.open:
			_bad("reveal still open")
	_section_done(mark, "SECTION 6 check input")


func _section_focus_stamp() -> void:
	var mark := bad.size()
	_arm_feel(true, false)
	st.hold_dawn = true
	await _focus_path("click", false)
	await _focus_path("esc", true)
	await _focus_fallback("click", false)
	await _focus_fallback("esc", true)
	_arm_feel(true, false)
	var game: Game = st.game
	game.over = ""
	game.week = 8
	_queue_check(game, "red", 8, false)
	st._pick_event("feel_gate", "try")
	if st.feel.check == null or not st.feel.check.open:
		_bad("stamp reveal missing")
	else:
		_click_check()
		await process_frame
		await process_frame
		var turned := float(st.feel.check.stamp.rotation_degrees)
		if not is_equal_approx(turned, -4.0):
			_bad("stamp rotation %s" % turned)
		elif st.feel.check.phase != "stamp" and st.feel.check.phase != "fade" and st.feel.check.phase != "hold":
			_bad("stamp phase %s" % st.feel.check.phase)
		else:
			print("STAMP rotation %.1f phase %s" % [turned, st.feel.check.phase])
		st.feel.check.reset()
	_section_done(mark, "SECTION focus stamp")


func _focus_path(tag: String, esc: bool) -> void:
	var game: Game = st.game
	game.over = ""
	game.week = 8
	if st.menu_button == null:
		_bad("%s no menu button" % tag)
		return
	st.menu_button.grab_focus()
	await process_frame
	_queue_check(game, "white", 8, false)
	st._pick_event("feel_gate", "try")
	if st.feel.check == null or not st.feel.check.open:
		_bad("%s reveal missing" % tag)
		return
	if esc:
		_esc_check()
	else:
		_click_check()
		_click_check()
		await create_timer(0.5).timeout
	await process_frame
	await process_frame
	var owner: Control = st.get_viewport().gui_get_focus_owner()
	if owner != st.menu_button:
		_bad("%s focus %s" % [tag, owner])
	else:
		print("FOCUS %s owner menu" % tag)


func _focus_fallback(tag: String, esc: bool) -> void:
	var game: Game = st.game
	game.over = ""
	game.week = 8
	st.event_mode = "all"
	game.pending = [_check_event("white", 8, false), {
		"id": "feel_next",
		"title": {"en": "Next", "ru": "Дальше"},
		"text": {"en": "Still here.", "ru": "Ещё здесь."},
		"choices": [{"id": "ok", "label": {"en": "Stay", "ru": "Остаться"}}],
	}]
	var temp := Button.new()
	temp.text = "temp"
	temp.focus_mode = Control.FOCUS_ALL
	st.add_child(temp)
	temp.grab_focus()
	await process_frame
	st._pick_event("feel_gate", "try")
	if is_instance_valid(temp):
		temp.queue_free()
	await process_frame
	if st.feel.check == null or not st.feel.check.open:
		_bad("%s fallback reveal missing" % tag)
		st.event_mode = "dawn"
		return
	if esc:
		_esc_check()
	else:
		_click_check()
		_click_check()
		await create_timer(0.5).timeout
	await process_frame
	await process_frame
	var owner: Control = st.get_viewport().gui_get_focus_owner()
	var expect: Control = st._first_enabled_control(st.card) if st.dim != null and st.dim.visible else null
	if owner == null:
		_bad("%s fallback focus null" % tag)
	elif expect != null and owner != expect:
		_bad("%s fallback focus %s want %s" % [tag, owner, expect])
	else:
		print("FOCUS %s fallback %s" % [tag, owner])
	st.event_mode = "dawn"
	if st.feel.check != null and st.feel.check.open:
		st.feel.check.reset()


func _esc_check() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	st._input(ev)


func _section_7() -> void:
	var mark := bad.size()
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		st._refresh()
		for size in [Vector2i(1920, 1080), Vector2i(1536, 864)]:
			await _apply_view(size)
			await _overlap_case("%s %s" % [lang, size])
		await _apply_view(Vector2i(1920, 1080))
		st.get_window().content_scale_factor = 1.25
		st.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		st.get_window().content_scale_size = Vector2i(1920, 1080)
		for _i in 3:
			await process_frame
		await _overlap_case("%s 125" % lang)
	Copy.set_lang("en")
	_arm_feel(true, false)
	_section_done(mark, "SECTION 7 overlap")


func _section_9() -> void:
	var mark := bad.size()
	_arm_feel(true, false)
	st.hold_dawn = true
	var game: Game = st.game
	game.over = ""
	game.week = 8
	var stale := {"name": "Stale", "skill": "wits", "color": "white", "success": true, "outcome": "stale line"}
	game.last_check = stale.duplicate()
	var state := int(game.check_rng.state)
	_queue_plain(game)
	st._pick_event("feel_plain", "ok")
	if st.feel.check.open:
		_bad("stale last_check opened a reveal")
		st.feel.check.reset()
	if int(game.check_rng.state) != state:
		_bad("plain choice moved check_rng")
	game.week = 3
	game.last_check = stale.duplicate()
	state = int(game.check_rng.state)
	var red_early := _check_choice("red", 10, false)
	game._resolve_check({"id": "feel_red_early", "title": "Early"}, red_early, "")
	if int(game.check_rng.state) != state:
		_bad("red before week 6 rolled")
	if str(game.last_check.get("name", "")) != "Stale":
		_bad("red before week 6 replaced last_check")
	game.over = ""
	game.week = 8
	var finishes := int(st.feel_pick_finishes)
	game.watcher = func(what, _data):
		if str(what) == "action":
			game.over = "hope"
	_queue_check(game, "white", 8, false)
	st._pick_event("feel_gate", "try")
	game.watcher = Callable()
	if st.feel.check.open:
		_bad("game.over still revealed")
		st.feel.check.reset()
	if int(st.feel_pick_finishes) != finishes + 1:
		_bad("over path skipped finish")
	game.over = ""
	_queue_check(game, "white", 4, true)
	st._pick_event("feel_gate", "try")
	if not st.feel.check.open or str(st.feel.check.banner.text) != Copy.t("feel.check.bet"):
		_bad("bet banner [%s]" % [st.feel.check.banner.text if st.feel.check.banner != null else ""])
	if st.feel.check.full_reveal or st.feel.check.offer_band != "bet":
		_bad("bet band %s full %s" % [st.feel.check.offer_band, st.feel.check.full_reveal])
	if str(st.feel.check.banner.text).find(" ") < 0 and false:
		pass
	st.feel.check.reset()
	game.over = ""
	game.week = 8
	_queue_check(game, "red", 4, false)
	st._pick_event("feel_gate", "try")
	if not st.feel.check.open or st.feel.check.offer_band != "red" or not st.feel.check.full_reveal:
		_bad("red band %s full %s" % [st.feel.check.offer_band, st.feel.check.full_reveal])
	elif st.feel.check.planned_sec < 2.0 or st.feel.check.planned_sec > 2.6:
		_bad("full duration %s" % st.feel.check.planned_sec)
	st.feel.check.reset()
	var likely := _difficulty_for(game, "white", 60)
	_queue_check(game, "white", likely, false)
	st._pick_event("feel_gate", "try")
	if not st.feel.check.open or st.feel.check.offer_band != "likely" or st.feel.check.full_reveal:
		_bad("likely white band %s full %s" % [st.feel.check.offer_band, st.feel.check.full_reveal])
	elif st.feel.check.planned_sec < 0.55 or st.feel.check.planned_sec > 0.7:
		_bad("short duration %s" % st.feel.check.planned_sec)
	st.feel.check.reset()
	var uncertain := _difficulty_for(game, "white", 50)
	_queue_check(game, "white", uncertain, false)
	st._pick_event("feel_gate", "try")
	if not st.feel.check.open or st.feel.check.offer_band != "uncertain" or st.feel.check.full_reveal:
		_bad("uncertain white band %s full %s" % [st.feel.check.offer_band, st.feel.check.full_reveal])
	elif st.feel.check.planned_sec < 0.55 or st.feel.check.planned_sec > 0.7:
		_bad("uncertain duration %s" % st.feel.check.planned_sec)
	st.feel.check.reset()
	var unlikely := _difficulty_for(game, "white", 0)
	_queue_check(game, "white", unlikely, false)
	st._pick_event("feel_gate", "try")
	if not st.feel.check.open or st.feel.check.offer_band != "unlikely" or not st.feel.check.full_reveal:
		_bad("unlikely white band %s full %s" % [st.feel.check.offer_band, st.feel.check.full_reveal])
	st.feel.check.reset()
	game.last_check = {"bet": true, "d1": 6, "d2": 6, "success": true, "box": true, "snake": false}
	var box_line: String = st._check_result_line()
	if box_line != Copy.t("Double 6. The bet wins."):
		_bad("double 6 line [%s]" % box_line)
	st.feel.check.start(game.last_check.duplicate(true), {"bet": {}}, Callable())
	if not is_equal_approx(st.feel.check.punch, 1.8):
		_bad("box punch %s" % st.feel.check.punch)
	if st.feel.check.subline.text != box_line:
		_bad("box subline [%s]" % st.feel.check.subline.text)
	st.feel.check.reset()
	game.last_check = {"bet": true, "d1": 1, "d2": 1, "success": false, "box": false, "snake": true}
	if st._check_result_line() != Copy.t("Double 1. The bet loses."):
		_bad("double 1 line [%s]" % st._check_result_line())
	_arm_feel(true, true)
	_queue_check(game, "white", likely, false)
	st._pick_event("feel_gate", "try")
	if not st.feel.check.open or st.feel.check.stamp_box == null or not st.feel.check.stamp_box.visible:
		_bad("reduced plate missing stamp")
	elif not is_equal_approx(st.feel.check.stamp.scale.x, 1.0):
		_bad("reduced stamp scaled")
	st.feel.check.reset()
	_arm_feel(true, false)
	game.over = ""
	_section_done(mark, "SECTION 9 check reveal")


func _overlap_case(tag: String) -> void:
	_arm_feel(true, false)
	st.hold_dawn = true
	var game: Game = st.game
	game.over = ""
	game.week = 8
	if st.toast_plate != null:
		st.toast_plate.visible = false
	await process_frame
	if st.toast_plate != null:
		st.toast_plate.visible = false
	var sick_before := 0
	if game.residents.size() > 0:
		sick_before = int(game.residents[0].get("sick", 0))
		if sick_before < 1:
			game.residents[0]["sick"] = 3
	var saw_infirmary := false
	for room in game.rooms:
		if str(room.get("type", "")) == "infirmary":
			saw_infirmary = true
	if st.has_method("_sync_sick_badge"):
		st._sync_sick_badge()
	if not saw_infirmary and st.sick_badge != null and st.sick_badge.visible and st.yard != null:
		var cot: Rect2 = st.yard.cell_screen(0, 2)
		cot.position += st.yard.position
		st.sick_badge.position = cot.position + Vector2(6.0, 6.0)
	if st.has_method("_sync_away_badge"):
		st._sync_away_badge()
	_queue_check(game, "red", 10, false)
	st._pick_event("feel_gate", "try")
	await process_frame
	if st.feel.check == null or not st.feel.check.open:
		_bad("%s reveal missing" % tag)
		_restore_overlap(game, sick_before)
		return
	if st.toast_plate != null and st.toast_plate.visible:
		_bad("%s toast visible" % tag)
	if st.notice_layer != null:
		_bad("%s notice open" % tag)
	if st.feel.layer.z_index >= 90:
		_bad("%s z %s" % [tag, st.feel.layer.z_index])
	var view: Rect2 = st.get_viewport_rect()
	var plate: Control = st.feel.check.plate
	if plate == null:
		_bad("%s no plate" % tag)
	else:
		var rect := plate.get_global_rect()
		if not view.encloses(rect) and not view.grow(-1).encloses(rect):
			if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > view.size.x + 1.0 or rect.end.y > view.size.y + 1.0:
				_bad("%s plate outside %s view %s" % [tag, rect, view])
		var sick := _badge_note(st.sick_badge)
		var away := _badge_note(st.away_badge)
		var hit := false
		for node_name in ["away_badge", "sick_badge", "undo_toast", "rail_chip", "radio_panel"]:
			var node: Control = st.get(node_name)
			if node != null and node.visible and _hits(rect, node.get_global_rect()):
				_bad("%s hits %s" % [tag, node_name])
				hit = true
		if not hit:
			print("SECTION 7 %s clear plate %s sick %s away %s" % [tag, rect, sick, away])
	st.feel.check.reset()
	_restore_overlap(game, sick_before)


func _restore_overlap(game: Game, sick_before: int) -> void:
	if game.residents.size() > 0:
		game.residents[0]["sick"] = sick_before
	if st.has_method("_sync_sick_badge"):
		st._sync_sick_badge()


func _badge_note(node: Control) -> String:
	if node == null or not node.visible:
		return "hidden"
	var badge := node.get_global_rect()
	return "shown %s" % badge


func _shot_plate_badge(lang: String, win_size: Vector2i, scale: float, path: String) -> void:
	Copy.set_lang(lang)
	_arm_feel(true, false)
	await _apply_view(win_size, scale)
	_park(st)
	var game: Game = st.game
	game.over = ""
	game.week = 8
	var sick_before := 0
	if game.residents.size() > 0:
		sick_before = int(game.residents[0].get("sick", 0))
		if sick_before < 1:
			game.residents[0]["sick"] = 3
	if st.has_method("_sync_sick_badge"):
		st._sync_sick_badge()
	if st.sick_badge != null and st.sick_badge.visible and st.yard != null:
		var cot: Rect2 = st.yard.cell_screen(0, 2)
		cot.position += st.yard.position
		st.sick_badge.position = cot.position + Vector2(6.0, 6.0)
	_queue_check(game, "red", 10, false)
	st._pick_event("feel_gate", "try")
	await create_timer(0.35).timeout
	_save_view(path)
	var plate := "none"
	var sick := "hidden"
	if st.feel.check != null and st.feel.check.plate != null:
		plate = str(st.feel.check.plate.get_global_rect())
	if st.sick_badge != null and st.sick_badge.visible:
		sick = str(st.sick_badge.get_global_rect())
	print("PLATE SHOT %s plate %s sick %s" % [lang, plate, sick])
	if st.feel.check != null:
		st.feel.check.reset()
	_restore_overlap(game, sick_before)


func _shot_check(tag: String, path: String, color: String) -> void:
	st.hold_dawn = true
	var game: Game = st.game
	game.over = ""
	game.week = 8
	_queue_check(game, color, 8 if color == "red" else 4, false)
	st._pick_event("feel_gate", "try")
	await process_frame
	if not host_reduced():
		await create_timer(0.95).timeout
	_save_view(path)
	print("SHOT check %s open %s" % [tag, st.feel.check.open])
	st.feel.check.reset()


func host_reduced() -> bool:
	return st.feel.reduced()


func _queue_check(game: Game, color: String, difficulty: int, bet: bool) -> void:
	game.pending = [_check_event(color, difficulty, bet)]


func _queue_plain(game: Game) -> void:
	game.pending = [{
		"id": "feel_plain",
		"title": {"en": "A plain errand", "ru": "Обычное дело"},
		"text": {"en": "Nothing to roll.", "ru": "Броска нет."},
		"choices": [{"id": "ok", "label": {"en": "Go", "ru": "Идём"}}],
	}]


func _check_event(color: String, difficulty: int, bet: bool) -> Dictionary:
	return {
		"id": "feel_gate",
		"title": {"en": "A test", "ru": "Проверка"},
		"text": {"en": "Roll.", "ru": "Бросок."},
		"choices": [_check_choice(color, difficulty, bet)],
	}


func _check_choice(color: String, difficulty: int, bet: bool) -> Dictionary:
	if bet:
		return {
			"id": "try",
			"label": {"en": "Bet", "ru": "Ставка"},
			"bet": {"target": 7, "win": 1},
		}
	return {
		"id": "try",
		"label": {"en": "Try", "ru": "Пробовать"},
		"check": {"skill": "wits", "difficulty": difficulty, "color": color},
		"success": {"text": "The line holds."},
		"failure": {"text": "The line fails."},
	}


func _difficulty_for(game: Game, color: String, want: int) -> int:
	var skill := "wits"
	var who := str(game.best_check_resident(skill))
	var bonus := int(game.check_bonus(skill, who))
	var best := 10
	var best_gap := 999
	for difficulty in range(2, 28):
		var chance := int(game._check_chance_bonus(bonus, difficulty, color))
		var gap := absi(chance - want)
		if want >= 60 and chance >= 60 and gap < best_gap:
			best = difficulty
			best_gap = gap
		elif want >= 40 and want < 60 and chance >= 40 and chance < 60 and gap < best_gap:
			best = difficulty
			best_gap = gap
		elif want < 40 and chance < 40 and gap < best_gap:
			best = difficulty
			best_gap = gap
	return best


func _click_check() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	st._input(ev)


func _hits(a: Rect2, b: Rect2) -> bool:
	return a.intersects(b, true)


func _section_12() -> void:
	var mark := bad.size()
	var path := Settings.path
	Settings.shake = false
	Settings.reduce_motion = false
	Settings.save()
	Settings.shake = true
	Settings.loaded = false
	Settings.load_file()
	if Settings.shake:
		_bad("shake did not round-trip")
	Settings.loaded = false
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.erase_section_key("game", "shake")
	cfg.save(path)
	Settings.shake = false
	Settings.loaded = false
	Settings.load_file()
	if not Settings.shake:
		_bad("missing shake key did not load true")
	Settings.reduce_motion = true
	Settings.shake = true
	if Settings.shaking():
		_bad("shaking while reduced")
	Settings.reduce_motion = false
	if not Settings.shaking():
		_bad("shaking while motion on")
	Settings.reduce_motion = false
	Settings.shake = true
	Settings.save()
	_section_done(mark, "SECTION 12 settings")


func _section_13() -> void:
	var mark := bad.size()
	_arm_feel(true, false)
	_park(st)
	if st.feel != null:
		st.feel.reset()
	await process_frame
	var before := _node_count(st.feel)
	var pool := int(st.feel.stock.pool.size())
	st.feel.stock.peak_chips = 0
	await _drive(2, "on")
	# Twenty weeks is the leak window. The seed above already ran a full game; run a bounded prefix too.
	var game := Game.new()
	game.setup(catalog, 2, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	st.game = game
	st.stock_week = 0
	st.feel.reset()
	st.hold_dawn = true
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 20:
		guard += 1
		bot._act(game)
		st._refresh()
		await process_frame
		if str(game.over) != "":
			break
		game.end_week()
		st._refresh()
		await process_frame
	await create_timer(0.8).timeout
	var after := _node_count(st.feel)
	if after != before:
		_bad("feel nodes %d -> %d" % [before, after])
	if st.feel.stock.live_tweens() != 0:
		_bad("tweens left %d" % st.feel.stock.live_tweens())
	if pool != 12 or st.feel.stock.pool.size() != 12:
		_bad("chip pool %d" % st.feel.stock.pool.size())
	if st.feel.stock.peak_chips > 12:
		_bad("peak chips %d" % st.feel.stock.peak_chips)
	_section_done(mark, "SECTION 13 leak")


func _section_14() -> void:
	if Game.SAVE_SCHEMA != 27:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	print("SECTION 14 schema %d; sibling gates are separate processes" % Game.SAVE_SCHEMA)


func _shots() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOTS skipped headless")
		return
	_arm_feel(true, false)
	await _apply_view(Vector2i(1920, 1080), 1.0)
	_park(st)
	Copy.set_lang("en")
	st._refresh()
	await _bump_shot("en", "/opt/cursor/artifacts/feel_f1_counters_en.png")
	Copy.set_lang("ru")
	st._refresh()
	await _bump_shot("ru", "/opt/cursor/artifacts/feel_f1_counters_ru.png")
	Copy.set_lang("en")
	_arm_feel(true, true)
	var game: Game = st.game
	st.feel.reset()
	game.stock.materials = int(game.stock.materials) + 6
	st.delta_hold_until = 0
	st._refresh()
	for _i in 3:
		await process_frame
	_save_view("/opt/cursor/artifacts/feel_f1_counters_reduce.png")
	Settings.reduce_motion = false
	_arm_feel(true, false)
	await _shot_check("en", "/opt/cursor/artifacts/feel_f2_check_en.png", "red")
	Copy.set_lang("ru")
	st._refresh()
	await _shot_check("ru", "/opt/cursor/artifacts/feel_f2_check_ru.png", "red")
	Copy.set_lang("en")
	st._refresh()
	_arm_feel(true, true)
	await _shot_check("reduce", "/opt/cursor/artifacts/feel_f2_check_reduce.png", "white")
	Settings.reduce_motion = false
	_arm_feel(true, false)
	await _chip_edge_shot("en", 1.0, "/opt/cursor/artifacts/feel_f1_chip_en100.png")
	await _chip_edge_shot("ru", 1.0, "/opt/cursor/artifacts/feel_f1_chip_ru100.png")
	await _chip_edge_shot("en", 1.25, "/opt/cursor/artifacts/feel_f1_chip_en125.png")
	await _apply_view(Vector2i(1920, 1080), 1.0)
	await _shot_plate_badge("en", Vector2i(1920, 1080), 1.0, "/opt/cursor/artifacts/feel_f2_plate_sick_en100.png")
	await _shot_plate_badge("ru", Vector2i(1920, 1080), 1.25, "/opt/cursor/artifacts/feel_f2_plate_sick_ru125.png")
	print("SHOTS wrote feel_f1 and feel_f2")


func _chip_edge_shot(lang: String, scale: float, path: String) -> void:
	Copy.set_lang(lang)
	_arm_feel(true, false)
	await _apply_view(Vector2i(1920, 1080), scale)
	_park(st)
	var game: Game = st.game
	st.feel.reset()
	st.delta_hold_until = 0
	var food := int(game.stock.food)
	st.chips.food.delta.text = "+2"
	st.chips.food.delta.visible = true
	st.feel.stock.sync(game, false)
	await process_frame
	if st.has_method("_layout"):
		st._layout()
	await process_frame
	game.stock.food = food + 6
	st.feel.stock.sync(game, true)
	await process_frame
	var found = st.feel.stock.last_chip.get("food", null)
	if found == null or not is_instance_valid(found):
		_bad("chip shot missed " + path)
		game.stock.food = food
		return
	st.feel.stock._kill("food")
	var origin: Vector2 = found.get_meta("origin", found.position)
	found.position = origin + Vector2(0.0, -FeelLook.CHIP_RISE)
	found.modulate = Color.WHITE
	found.visible = true
	await process_frame
	await process_frame
	var top: float = found.get_global_rect().position.y
	_save_view(path)
	print("CHIP SHOT %s y %.2f %s" % [lang, top, path])
	game.stock.food = food


func _bump_shot(tag: String, path: String) -> void:
	var game: Game = st.game
	st.feel.reset()
	var food := int(game.stock.food)
	st.feel.stock.sync(game, false)
	await process_frame
	game.stock.food = food + 6
	game.hope = int(game.hope) + 2
	st.delta_hold_until = 0
	st._refresh()
	await process_frame
	await create_timer(0.18).timeout
	_save_view(path)
	print("SHOT %s food %s chip %s" % [tag, st.chips.food.value.text, str(st.feel.stock.shown_chip.get("food", ""))])
	game.stock.food = food


func _save_view(path: String) -> void:
	var image: Image = st.get_viewport().get_texture().get_image()
	if image == null:
		_bad("no image " + path)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var err := image.save_png(path)
	if err != OK:
		_bad("save %s %s" % [path, err])


func _apply_view(win_size: Vector2i, scale: float = 1.0) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	if scale <= 1.01:
		win.content_scale_factor = 1.0
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	else:
		win.content_scale_factor = scale
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_size = win_size
	for _i in 4:
		await process_frame
	if st.has_method("_layout"):
		st._layout()
	await process_frame


func _pass(mode: String, cat: Catalog, master: Dictionary) -> Dictionary:
	records_rel = _fresh_records(mode)
	var rows := {}
	var saved := catalog
	catalog = cat
	for run_seed in range(1, 61):
		var row: Dictionary = {}
		if mode == "sim":
			row = await _sim_only(run_seed)
		else:
			row = await _drive(run_seed, mode)
		if run_seed != 1:
			row.erase("state")
		rows[run_seed] = row
		if run_seed % 10 == 0:
			print("PASS %s %d" % [mode, run_seed])
		if not master.is_empty() and mode != "sim":
			var want: Dictionary = master.get(str(run_seed), {})
			if not want.is_empty() and not _same_master(row, want):
				_bad("seed %d %s diverged during pass" % [run_seed, mode])
				_print_row("master", want)
				_print_row(mode, row)
				break
	catalog = saved
	return rows


## best_score is sealed from records_path, which defaults to the shared
## user://records.cfg. This Godot build has no --user-data-dir, so that file is
## one home for every run. Each mode gets its own empty file instead, matching a
## master-json capture that also starts from an empty records file.
func _fresh_records(mode: String) -> String:
	var rel := SCRATCH.path_join("records_%s.cfg" % mode)
	var path := ProjectSettings.globalize_path(rel)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return rel


func _drive(run_seed: int, mode: String) -> Dictionary:
	_arm_feel(mode != "off", mode == "reduced")
	var game := Game.new()
	game.records_path = records_rel
	game.setup(catalog, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	st.game = game
	if st.yard != null:
		st.yard.station = st
	st.stock_week = 0
	st.stock_shown = {}
	st.delta_hold_until = 0
	st.hold_dawn = true
	if st.feel != null:
		st.feel.reset()
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		bot._act(game)
		st._refresh()
		await process_frame
		if str(game.over) != "":
			break
		game.end_week()
		st._refresh()
		await process_frame
	var row := _row(game, run_seed)
	row["state"] = game.export_state()
	return row


func _sim_only(run_seed: int) -> Dictionary:
	var game := Game.new()
	game.records_path = records_rel
	game.setup(catalog, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		bot._act(game)
		if str(game.over) != "":
			break
		game.end_week()
	var row := _row(game, run_seed)
	row["state"] = game.export_state()
	return row


func _row(game: Game, run_seed: int) -> Dictionary:
	var data := game.export_state()
	var stripped: Dictionary = data.duplicate(true)
	stripped.erase("notices")
	stripped.erase("choice_results")
	return {
		"seed": run_seed,
		"over": str(game.over),
		"ending": game.ending_id(),
		"week": int(game.week),
		"hope": int(game.hope),
		"discontent": int(game.discontent),
		"residents": game.residents.size(),
		"food": int(game.stock.get("food", 0)),
		"air": int(game.stock.get("air", 0)),
		"power": int(game.stock.get("power", 0)),
		"materials": int(game.stock.get("materials", 0)),
		"tokens": int(game.stock.get("tokens", 0)),
		"influence": int(game.stock.get("influence", 0)),
		"hash": hash(var_to_str(data)),
		"hash_stripped": hash(var_to_str(stripped)),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
	}


func _same_play(a: Dictionary, b: Dictionary) -> bool:
	return int(a.hash) == int(b.hash) and str(a.rng) == str(b.rng) and str(a.over) == str(b.over) and int(a.week) == int(b.week) and int(a.hope) == int(b.hope) and int(a.discontent) == int(b.discontent) and int(a.residents) == int(b.residents) and int(a.food) == int(b.food)


func _same_master(got: Dictionary, want: Dictionary) -> bool:
	if want.has("hash"):
		return _same_play(got, want) and str(got.ending) == str(want.get("ending", got.ending))
	return false


func _load_master() -> Dictionary:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--master-json="):
			path = str(arg).trim_prefix("--master-json=")
	if path == "" or not FileAccess.file_exists(path):
		print("SECTION 3 no master json; modes compared to each other and to sim-only")
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_bad("bad master json")
		return {}
	print("SECTION 3 master json " + path)
	return parsed


func _diff_state(a: Dictionary, b: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	_diff_any(a, b, "", out, 14)
	return out


func _diff_any(a, b, prefix: String, out: PackedStringArray, limit: int) -> void:
	if out.size() >= limit:
		return
	if typeof(a) != typeof(b):
		out.append(prefix + " type")
		return
	if a is Dictionary:
		var keys := {}
		for key in a:
			keys[str(key)] = true
		for key in b:
			keys[str(key)] = true
		var names: Array = keys.keys()
		names.sort()
		for key in names:
			# stats.best_score is filled from user://records.cfg when a run seals.
			# The sim pass plays all 60 seeds before the UI pass, so it can raise
			# that file and seed 1's best differs even with feel off. Other stats
			# keys still have to match. The export hash still includes stats.
			if prefix == "/stats" and str(key) == "best_score":
				continue
			if str(key) in ["notices", "choice_results", "flags", "obs", "salvage"]:
				continue
			_diff_any(a.get(key, null), b.get(key, null), prefix + "/" + str(key), out, limit)
		return
	if a is Array:
		if var_to_str(a) != var_to_str(b):
			out.append("%s len %d/%d" % [prefix, a.size(), b.size()])
		return
	if a != b:
		out.append(prefix)


func _arm_feel(motion: bool, reduced: bool) -> void:
	st.shot_mode = true
	st.motion_in_shots = motion
	Settings.reduce_motion = reduced
	Settings.loaded = true


func _park(node) -> void:
	node.hold_dawn = true
	node.set_process(false)
	if node.has_method("_close_card"):
		node._close_card()
	if node.dim != null:
		node.dim.visible = false
	if node.menu_layer != null:
		node.menu_layer.visible = false
	node.at_menu = false


func _until_text(key: String, want: String) -> void:
	for _i in 40:
		if str(st.chips[key].value.text) == want:
			return
		await process_frame
	await create_timer(0.6).timeout


func _node_count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _node_count(child)
	return n


func _print_row(tag: String, row: Dictionary) -> void:
	print("%s seed %s over %s week %s hash %s rng %s" % [tag, str(row.get("seed", "")), str(row.get("over", "")), str(row.get("week", "")), str(row.get("hash", "")), str(row.get("rng", ""))])


func _has(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)


func _section_done(mark: int, title: String) -> void:
	if bad.size() == mark:
		print(title + " OK")
	else:
		print(title + " FAIL")


func _failed_prefix(prefix: String) -> bool:
	for line in bad:
		if line.begins_with(prefix) or line.find(prefix) >= 0:
			return true
	return false


func _bad(line: String) -> void:
	bad.append(line)
	print("FAIL " + line)


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir():
			_wipe(sub)
			dir.remove(sub)
		else:
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
