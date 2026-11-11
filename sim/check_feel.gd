extends SceneTree

## V3a feel gate. F1 covers sections 1-5 and 12-14.
##   godot --headless --path . -s res://sim/check_feel.gd -- --feel-test
## Optional: --master-json=/abs/path.json compares the UI loop to a live master harness.
## Optional: --feel-shots writes 1920x1080 stills. --feel-shots-only skips the long loop.

const SCRATCH := "user://check_feel"
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
				print("SECTION 3 sim-only matches aside from notices, choice_results, and the UI writes flags/obs/salvage")
			else:
				_bad("seed 1 sim-only state %s" % ", ".join(sim_diff))
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
	await _apply_view(Vector2i(1920, 1080))
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
	print("SHOTS wrote feel_f1")


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


func _apply_view(win_size: Vector2i) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	win.content_scale_factor = 1.0
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for _i in 4:
		await process_frame


func _pass(mode: String, cat: Catalog, master: Dictionary) -> Dictionary:
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


func _drive(run_seed: int, mode: String) -> Dictionary:
	_arm_feel(mode != "off", mode == "reduced")
	var game := Game.new()
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
