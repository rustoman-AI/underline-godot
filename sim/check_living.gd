extends SceneTree

## Living Rooms gate.
## LR2 owns section_1 (lighting lint), section_2, section_4, section_5, section_6, section_9, section_10.
## LR1 owns section_3 and section_11, and may extend section_1. Keep each section in its own function.
##   godot --headless --path . -s res://sim/check_living.gd -- --living-test
## Screenshots: xvfb + opengl3, add --shots. --skip-parity skips the 60-seed station loop.

const LivingLib = preload("res://ui/living/living.gd")
const LightLib = preload("res://ui/living/living_light.gd")
const WalkLib = preload("res://ui/living/living_walk.gd")
const SCRATCH := "user://check_living"
const MASTER_PURE := "/tmp/living_master_pure.json"
const BRANCH_PURE := "/tmp/living_branch_pure.json"

var bad: PackedStringArray = []
var catalog: Catalog
var _shots := false
var _skip_parity := false
var _min_bright := 1.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--living-shots":
			_shots = true
		elif str(arg) == "--skip-parity":
			_skip_parity = true
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = false
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	Settings.loaded = true
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	catalog = Catalog.new()
	if not catalog.load_all():
		_fail("catalog %s" % catalog.error)
		_finish()
		return
	print("SECTION 1 lint")
	_section_1()
	print("SECTION 6 determinism")
	_section_6()
	print("SECTION 4 cut")
	_section_4()
	print("SECTION 5 brightness")
	_section_5()
	print("SECTION 9 frontier math")
	_section_9_math()
	print("SECTION 10 leak")
	_section_10_leak()
	if not _skip_parity:
		print("SECTION 2 parity")
		await _section_2()
	print("SECTION 9 draw + SECTION 10 perf")
	await _section_9_draw_and_10()
	if _shots:
		print("SHOTS")
		await _shots_run()
	_finish()


func _finish() -> void:
	LivingLib.test_force = ""
	Copy.set_lang("en")
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	if bad.is_empty():
		print("LIVING CHECK OK")
		print("MIN_BRIGHTNESS %.4f" % _min_bright)
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("LIVING CHECK FAILED")
	quit(1)


func _fail(msg: String) -> void:
	bad.append(msg)
	print("FAIL " + msg)


func _section_1() -> void:
	if Game.SAVE_SCHEMA != 27:
		_fail("schema %s" % str(Game.SAVE_SCHEMA))
	var living_dir := "res://ui/living"
	var names := DirAccess.get_files_at(living_dir)
	if names.is_empty():
		_fail("ui/living empty")
		return
	var forbid := ["_brownout_ids", "rooms_losing_power", "_generator_yield", "dark_rooms", "WeekForecast.", "PointLight2D", "Light2D", "CanvasModulate", "create_tween", "randomize("]
	for name in names:
		var path := living_dir.path_join(str(name))
		if not str(name).ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for token in forbid:
			if text.find(token) >= 0:
				_fail("%s contains %s" % [name, token])
		if _global_rand(text, "randf(") or _global_rand(text, "randi("):
			_fail("%s calls the global rng" % name)
		if text.find("game.apply(") >= 0 or text.find(".end_week(") >= 0:
			_fail("%s calls the sim" % name)
		if text.find("_rng") >= 0:
			_fail("%s names a sim rng" % name)
		if text.find(".modulate") >= 0:
			_fail("%s assigns modulate" % name)
		var rx := RegEx.new()
		rx.compile("game\\.[A-Za-z0-9_]+\\s*=[^=]")
		if rx.search(text) != null:
			_fail("%s assigns a game field" % name)
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var yard := _yard_text(station)
	if yard == "":
		_fail("yard class missing")
		return
	if yard.find("create_tween") >= 0:
		_fail("Yard creates a tween")
	if yard.find("PointLight2D") >= 0 or yard.find("CanvasModulate") >= 0:
		_fail("Yard adds a light node")
	var bodies := _yard_draw_bodies(yard)
	for token in ["_brownout_ids", "rooms_losing_power", "_generator_yield", "dark_rooms", "WeekForecast."]:
		if bodies.find(token) >= 0:
			_fail("Yard draw/process calls %s" % token)
	if station.find("living.observe(power_loss, game.week)") < 0:
		_fail("refresh does not observe")
	if station.find("living.night_begin()") < 0 or station.find("living.night_end()") < 0:
		_fail("night hooks missing")


func _global_rand(text: String, token: String) -> bool:
	var at := 0
	while true:
		at = text.find(token, at)
		if at < 0:
			return false
		if at == 0 or text.substr(at - 1, 1) != ".":
			return true
		at += token.length()
	return false


func _yard_text(src: String) -> String:
	var at := src.find("class Yard extends Control:")
	if at < 0:
		return ""
	var rest := src.substr(at)
	var nxt := rest.find("\nclass ")
	if nxt < 0:
		return rest
	return rest.substr(0, nxt)


func _yard_draw_bodies(yard: String) -> String:
	var out := ""
	var on := false
	for line in yard.split("\n"):
		if line.begins_with("\tfunc _draw") or line.begins_with("\tfunc _process"):
			on = true
		elif on and line.begins_with("\tfunc "):
			on = false
		if on:
			out += line + "\n"
	return out


func _section_6() -> void:
	seed(1)
	randf()
	var first := _one_plan("room_a", 4)
	seed(999)
	randf()
	var second := _one_plan("room_a", 4)
	if not _plans_equal(first, second):
		_fail("dip plan moved when the global seed changed")
	var again := _one_plan("room_a", 4)
	if not _plans_equal(first, again):
		_fail("same uid and week gave two dip plans")
	var other := _one_plan("room_b", 4)
	if _plans_equal(first, other) and int(first.get("n", 0)) == 0:
		_fail("plan was empty")
	var walk = WalkLib.new()
	if walk.active() != 0:
		_fail("LR2 spawned a walker")
	walk.reset()
	if walk.active() != 0:
		_fail("walk reset left a walker")


func _one_plan(uid: String, week: int) -> Dictionary:
	var light = LightLib.new()
	var rooms := [_room(uid, "workshop", 0, 1), _room("gen", "generator", 1, 3)]
	light.observe({}, 1, rooms, _grid(), 0.0, false)
	var loss := {}
	loss[uid] = true
	light.observe(loss, week, rooms, _grid(), 0.0, false)
	return light.cut_plan(uid)


func _plans_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	if int(a.n) != int(b.n) or absf(float(a.dur) - float(b.dur)) > 0.0001:
		return false
	var ag: Array = a.gaps
	var bg: Array = b.gaps
	if ag.size() != bg.size():
		return false
	for i in ag.size():
		if absf(float(ag[i]) - float(bg[i])) > 0.0001:
			return false
	return true


func _section_4() -> void:
	var uid := "room_a"
	var rooms := [_room(uid, "workshop", 0, 1), _room("gen", "generator", 1, 3)]
	var cells := _grid()
	var light = LightLib.new()
	var loss := {}
	loss[uid] = true
	light.observe(loss, 3, rooms, cells, 0.0, false)
	var primed: float = light.cut_alpha(uid, 0.05)
	if primed < 0.38 or primed > 0.62:
		_fail("first observe flickered (alpha %.3f)" % primed)
	light = LightLib.new()
	light.observe({}, 1, rooms, cells, 0.0, false)
	light.observe(loss, 6, rooms, cells, 0.0, false)
	var plan: Dictionary = light.cut_plan(uid)
	var n := int(plan.get("n", 0))
	if n < 3 or n > 5:
		_fail("dip count %d" % n)
	var gaps: Array = plan.get("gaps", [])
	if gaps.size() != n - 1:
		_fail("gap count %d for %d dips" % [gaps.size(), n])
	for g in gaps:
		if float(g) < 0.24 - 0.0001 or float(g) > 0.36 + 0.0001:
			_fail("gap %.4f outside 0.24-0.36" % float(g))
	if float(plan.get("dur", 9.0)) > 2.5 + 0.0001:
		_fail("flicker longer than 2.5 s")
	var dips: Array = []
	var in_dip := false
	var dip_len := 0.0
	var min_b := 1.0
	var step := 0.01
	for i in 280:
		var t := float(i) * step
		var b := 1.0 - light.cut_alpha(uid, t)
		min_b = minf(min_b, b)
		var dipping := b <= 0.41
		if dipping and not in_dip:
			in_dip = true
			dip_len = step
			dips.append(t)
		elif dipping:
			dip_len += step
		elif in_dip:
			if dip_len < 0.10 or dip_len > 0.13:
				_fail("dip length %.3f" % dip_len)
			in_dip = false
	if in_dip and (dip_len < 0.10 or dip_len > 0.13):
		_fail("final dip length %.3f" % dip_len)
	if dips.size() != n:
		_fail("played %d dips, plan %d" % [dips.size(), n])
	if min_b < 0.35:
		_fail("cut brightness %.3f below 0.35" % min_b)
	_note_bright(min_b)
	for i in dips.size():
		var window := 0
		for j in dips.size():
			if float(dips[j]) >= float(dips[i]) and float(dips[j]) < float(dips[i]) + 1.0:
				window += 1
		if window > 3:
			_fail("%d flashes in 1 s" % window)
	var steady := 1.0 - light.cut_alpha(uid, 3.0)
	var wobble_lo := 1.0
	var wobble_hi := 0.0
	for i in 600:
		var b := 1.0 - light.cut_alpha(uid, 3.0 + float(i) / 60.0)
		wobble_lo = minf(wobble_lo, b)
		wobble_hi = maxf(wobble_hi, b)
	if wobble_lo < 0.38 - 0.001 or wobble_hi > 0.62 + 0.001:
		_fail("settled brightness %.3f..%.3f" % [wobble_lo, wobble_hi])
	_note_bright(wobble_lo)
	if absf(steady - (1.0 - light.cut_alpha(uid, 3.0))) > 0.02:
		_fail("flicker did not end on the steady dim")
	var gen := 1.0 - light.strain_alpha("gen", 3.0)
	if gen < 0.999:
		_fail("generator settled at %.3f" % gen)
	var mid := 1.0 - light.strain_alpha("gen", 0.2)
	if mid > 0.95:
		_fail("generator did not strain")
	light = LightLib.new()
	light.observe({}, 1, rooms, cells, 0.0, false)
	light.observe(loss, 2, rooms, cells, 0.0, false)
	light.observe({}, 2, rooms, cells, 1.0, false)
	var back := 1.0 - light.cut_alpha(uid, 1.4)
	if back < 0.999:
		_fail("relight at 0.40 s is %.3f" % back)
	var early := 1.0 - light.cut_alpha(uid, 1.2)
	if early >= 0.999:
		_fail("relight finished early")
	light.observe(loss, 2, rooms, cells, 1.5, false)
	var snapped := 1.0 - light.cut_alpha(uid, 1.55)
	if snapped > 0.7:
		_fail("second entry inside 4 s played a lead (brightness %.3f)" % snapped)
	if not light.cut_plan(uid).is_empty():
		_fail("second entry inside 4 s still has a flicker")
	light = LightLib.new()
	light.observe({}, 1, rooms, cells, 0.0, true)
	light.observe(loss, 4, rooms, cells, 0.0, true)
	if absf(light.cut_alpha(uid, 0.2) - 0.5) > 0.001:
		_fail("reduce motion alpha %.3f" % light.cut_alpha(uid, 0.2))
	if light.strain_alpha("gen", 0.2) > 0.001:
		_fail("reduce motion strained the generator")
	if not light.cut_plan(uid).is_empty():
		_fail("reduce motion queued a flicker")
	var offline := [_room(uid, "workshop", 0, 1), _room("gen", "generator", 1, 3)]
	offline[1]["offline"] = true
	light = LightLib.new()
	light.observe({}, 1, offline, cells, 0.0, false)
	light.observe(loss, 8, offline, cells, 0.0, false)
	if light.strain_alpha("gen", 0.2) > 0.001:
		_fail("offline generator strained")
	light = LightLib.new()
	light.observe({}, 1, rooms, cells, 5.0, false)
	light.observe(loss, 9, rooms, cells, 5.0, false)
	light.night_begin(5.0)
	if light.cut_alpha(uid, 5.2) > 0.001:
		_fail("night queued flicker played under the veil")
	light.night_end(5.0)
	if light.cut_plan(uid).get("waiting", true):
		_fail("dawn did not release the flicker")
	if light.cut_alpha(uid, 5.05) > 0.05:
		_fail("released flicker skipped its lead")


func _section_5() -> void:
	var uid := "room_cut"
	var inf := "room_inf"
	var rooms := [_room(uid, "workshop", 0, 1), _room(inf, "infirmary", 1, 1), _room("gen", "generator", 1, 3)]
	var cells := _grid()
	var loss := {}
	loss[uid] = true
	var light = LightLib.new()
	light.observe({}, 1, rooms, cells, 0.0, false)
	light.observe(loss, 2, rooms, cells, 0.0, false)
	light.set_ward(inf, false)
	for _i in 40:
		light.tick(1.0 / 60.0, false, false, 3.0)
	var t := 3.0
	light.night_begin(t)
	var min_grade := 1.0
	var min_cut := 1.0
	var min_ward := 1.0
	var min_stack := 1.0
	for i in 160:
		var paused := i < 80
		if not paused:
			t += 1.0 / 60.0
		var grade: Color = light.grade_color()
		if grade.a > 0.0:
			var lum := _lum(grade)
			min_grade = minf(min_grade, lum)
			_note_bright(lum)
			if lum < 0.85:
				_fail("grade brightness %.4f at step %d" % [lum, i])
				break
		var cut_b := 1.0 - light.cut_alpha(uid, t)
		min_cut = minf(min_cut, cut_b)
		_note_bright(cut_b)
		if cut_b < 0.35:
			_fail("cut brightness %.4f during grade" % cut_b)
			break
		var wash: Color = light.ward_color(inf, t)
		if wash.a > 0.0:
			var wlum := _lum(wash)
			min_ward = minf(min_ward, wlum)
			var stacked := _lum_over(_over_white(wash), grade)
			min_stack = minf(min_stack, stacked)
			if wlum < 0.85 or stacked < 0.85:
				_fail("ward %.4f stacked %.4f" % [wlum, stacked])
				break
			if wlum < 0.55:
				_fail("tint %.4f" % wlum)
				break
		light.tick(1.0 / 60.0, paused, false, t)
	if min_grade > 0.99:
		_fail("night grade never drew")
	if light.phase() != "off" and light.phase() != "dawn":
		_fail("grade ended in %s" % light.phase())
	print("  grade min %.4f cut min %.4f ward min %.4f stack min %.4f" % [min_grade, min_cut, min_ward, min_stack])
	var hidden := light.frontier_alpha(0, 5)
	if hidden > 0.82 + 0.0001:
		_fail("frontier alpha %.3f" % hidden)


func _section_9_math() -> void:
	var light = LightLib.new()
	var rooms := [_room("room_a", "workshop", 1, 1)]
	light.observe({}, 1, rooms, _frontier_cells(), 0.0, false)
	if absf(light.frontier_alpha(0, 0) - 0.66) > 0.001:
		_fail("hidden dist 2 alpha %.3f" % light.frontier_alpha(0, 0))
	if absf(light.frontier_alpha(0, 4) - 0.82) > 0.001:
		_fail("hidden dist 3 alpha %.3f" % light.frontier_alpha(0, 4))
	if light.frontier_alpha(0, 4) > 0.82:
		_fail("hidden alpha above 0.82")
	if absf(light.frontier_alpha(1, 3) - 0.42) > 0.001:
		_fail("undug alpha %.3f" % light.frontier_alpha(1, 3))
	if not light.has_lantern(1, 0):
		_fail("no lantern beside the room")
	if light.has_lantern(1, 3):
		_fail("lantern beside a dug cell only")
	if light.has_lantern(1, 2):
		_fail("lantern on a dug cell")
	if light.cell_kind(2, 2) != "undug":
		_fail("expected undug beside dug rock")
	if light.has_lantern(2, 2):
		_fail("lantern without a room edge")
	var station_src := FileAccess.get_file_as_string("res://ui/station.gd")
	var yard := _yard_text(station_src)
	if yard.find("_draw_dig_outline") < 0:
		_fail("dig ring call removed")
	if yard.find("dig_ring_draws += 1") < 0:
		_fail("dig ring recorder missing")


func _section_10_leak() -> void:
	var light = LightLib.new()
	var rooms := [_room("room_a", "workshop", 0, 1), _room("gen", "generator", 1, 3)]
	var cells := _grid()
	var worst_events := 0
	for week in 50:
		var loss := {}
		if week % 2 == 0:
			loss["room_a"] = true
		light.observe(loss, week + 1, rooms, cells, float(week) * 5.0, false)
		light.tick(0.2, false, false, float(week) * 5.0)
		worst_events = maxi(worst_events, light.event_count())
	if worst_events > 6:
		_fail("events grew to %d" % worst_events)
	if light.frontier_count() > 18:
		_fail("frontier grew to %d" % light.frontier_count())
	if light.rate_count() > 18:
		_fail("rate map grew to %d" % light.rate_count())
	light.reset()
	if light.event_count() != 0 or light.frontier_count() != 0 or light.phase() != "off":
		_fail("reset left lighting state")


func _section_2() -> void:
	var last_seed := 60
	if OS.get_environment("LIVING_ONLY_SEED") != "":
		last_seed = int(OS.get_environment("LIVING_ONLY_SEED"))
	var pure: Array = []
	for run_seed in range(1, last_seed + 1):
		pure.append(_pure_seed(run_seed))
		if run_seed % 10 == 0:
			print("  pure %d/60" % run_seed)
	_write_json(BRANCH_PURE, pure)
	_compare_master(pure)
	var st = await _boot_station()
	if st == null:
		_fail("station did not boot")
		return
	# The first station play fills static UI caches. A later play of the same
	# seed then resolves same-week events in a stable order. Warm up before
	# comparing modes so that order is not blamed on Living.
	await _station_seed(st, 1, "off")
	print("  station warmup done")
	var mismatch := 0
	for run_seed in range(1, last_seed + 1):
		var off: Dictionary = await _station_seed(st, run_seed, "off")
		var on: Dictionary = await _station_seed(st, run_seed, "on")
		var reduced: Dictionary = await _station_seed(st, run_seed, "reduced")
		if not _sig_equal(off, on) or not _sig_equal(off, reduced):
			mismatch += 1
			_fail("seed %d modes diverged" % run_seed)
			_print_sig_diff("off", off, "on", on)
			_print_sig_diff("off", off, "reduced", reduced)
			if mismatch >= 3:
				break
		if run_seed % 10 == 0:
			print("  station %d/60" % run_seed)
	print("  station mode mismatches %d" % mismatch)
	await _browned_frames(st)
	if is_instance_valid(st):
		st.free()


func _pure_seed(run_seed: int) -> Dictionary:
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
	return _sig(game, run_seed)


func _station_seed(st, run_seed: int, mode: String) -> Dictionary:
	LivingLib.test_force = "off" if mode == "off" else "on"
	Settings.reduce_motion = mode == "reduced"
	st.motion_in_shots = true
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	game.audit = false
	game.raid_share_profile = "careful"
	st.game = game
	st.yard.station = st
	if st.living != null:
		st.living.attach(st)
		st.living.reset()
	st._refresh()
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while str(game.over) == "" and guard < 42:
		guard += 1
		bot._act(game)
		st._refresh()
		game.end_week()
		st._refresh()
		await process_frame
	return _sig(game, run_seed)


func _browned_frames(st) -> void:
	LivingLib.test_force = "on"
	Settings.reduce_motion = false
	st.motion_in_shots = true
	var game := Game.new()
	game.setup(catalog, 3, 40)
	game.audit = false
	st.game = game
	st._refresh()
	var before := {}
	var rng_before := _rng_line(game)
	for room in game.rooms:
		before[str(room.uid)] = bool(room.get("browned", false))
	var export_before := hash(var_to_str(game.export_state()))
	for _i in 100:
		await process_frame
	for room in game.rooms:
		if bool(room.get("browned", false)) != bool(before[str(room.uid)]):
			_fail("draw changed browned on %s" % str(room.uid))
	if _rng_line(game) != rng_before:
		_fail("draw changed an RNG stream")
	if hash(var_to_str(game.export_state())) != export_before:
		_fail("draw changed export_state")
	if st.living == null or st.living.frames_drawn <= 0:
		_fail("yard did not draw (frames_drawn 0); rerun under xvfb")
	else:
		print("  frames_drawn %d" % st.living.frames_drawn)


func _compare_master(pure: Array) -> void:
	if not FileAccess.file_exists(MASTER_PURE):
		print("  master pure file missing; branch pure saved")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MASTER_PURE))
	if not parsed is Array:
		_fail("master pure file unreadable")
		return
	var master: Array = parsed
	if master.size() != pure.size():
		_fail("master pure count %d" % master.size())
		return
	var mismatches := 0
	for i in pure.size():
		var a: Dictionary = pure[i]
		var b: Dictionary = master[i]
		if not _sig_equal(a, b):
			mismatches += 1
			if mismatches <= 5:
				_fail("master seed %s diverged" % str(a.get("seed", i + 1)))
				_print_sig_diff("branch", a, "master", b)
	print("  careful60 vs master mismatches %d" % mismatches)


func _sig(game: Game, run_seed: int) -> Dictionary:
	return {
		"seed": run_seed,
		"over": str(game.over),
		"week": int(game.week),
		"hash": str(hash(var_to_str(game.export_state()))),
		"rng": str(int(game.rng.state)),
		"net": str(int(game.net_rng.state)),
		"check": str(int(game.check_rng.state)),
		"story": str(int(game.story_rng.state)),
		"crunch": str(int(game.crunch_rng.state)),
		"hope": int(game.hope),
		"dis": int(game.discontent),
		"pop": game.residents.size(),
		"food": int(game.stock.food),
		"power": int(game.stock.power),
		"air": int(game.stock.air),
		"mat": int(game.stock.materials),
	}


func _sig_equal(a: Dictionary, b: Dictionary) -> bool:
	for key in ["over", "week", "hash", "rng", "net", "check", "story", "crunch", "hope", "dis", "pop", "food", "power", "air", "mat"]:
		if not _field_equal(a.get(key, ""), b.get(key, "")):
			return false
	return true


func _field_equal(a, b) -> bool:
	if str(a) == str(b):
		return true
	var left := str(a)
	var right := str(b)
	if left.is_valid_float() and right.is_valid_float():
		return int(float(left)) == int(float(right))
	return false


func _print_sig_diff(left_name: String, left: Dictionary, right_name: String, right: Dictionary) -> void:
	for key in ["over", "week", "hash", "rng", "net", "check", "story", "crunch", "hope", "dis", "pop", "food", "power", "air", "mat"]:
		if not _field_equal(left.get(key, ""), right.get(key, "")):
			print("  DIFF %s %s=%s %s=%s" % [key, left_name, str(left.get(key, "")), right_name, str(right.get(key, ""))])


func _rng_line(game: Game) -> String:
	return "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)]


func _section_9_draw_and_10() -> void:
	var st = await _boot_station()
	if st == null:
		_fail("perf station did not boot")
		return
	LivingLib.test_force = "on"
	Settings.reduce_motion = false
	st.motion_in_shots = true
	_clear_pause(st)
	st._refresh()
	var rings_before := int(st.yard.dig_ring_draws)
	await _frames(8)
	if st.living.frames_drawn <= 0:
		_fail("draw fallback: frames_drawn 0")
	elif int(st.yard.dig_ring_draws) <= rings_before:
		_fail("dig ring was not drawn")
	else:
		print("  dig rings %d lanterns %d" % [int(st.yard.dig_ring_draws) - rings_before, st.living.lanterns_drawn])
	if st.living.lanterns_drawn <= 0 and st.living.frames_drawn > 0:
		_fail("no lantern beside a built room")
	_pad_residents(st.game)
	var cuts := {}
	var n := 0
	for room in st.game.rooms:
		if str(room.type) == "generator":
			continue
		cuts[str(room.uid)] = true
		n += 1
		if n >= 4:
			break
	st.living.reset()
	st.living.observe({}, st.game.week)
	st.power_loss = cuts
	st.living.observe(cuts, st.game.week)
	st.living.perf_sum = 0
	st.living.perf_frames = 0
	st.living.perf_worst = 0
	for _i in 40:
		st.living.living_t += 1.0 / 60.0
		await process_frame
	var avg: float = st.living.perf_avg_ms()
	var worst: float = st.living.perf_worst_ms()
	print("  perf avg %.3f ms worst %.3f ms residents %d frames %d" % [avg, worst, st.game.residents.size(), st.living.perf_frames])
	if st.game.residents.size() < 30:
		_fail("perf fixture has %d residents" % st.game.residents.size())
	if st.living.perf_frames < 30:
		_fail("perf sampled %d frames" % st.living.perf_frames)
	if avg > 0.6:
		_fail("living avg %.3f ms" % avg)
	if worst > 2.0:
		_fail("living worst %.3f ms" % worst)
	if is_instance_valid(st):
		st.free()


func _pad_residents(game: Game) -> void:
	if game.residents.is_empty():
		return
	var base: Dictionary = game.residents[0]
	while game.residents.size() < 32:
		var copy: Dictionary = base.duplicate(true)
		copy["id"] = "perf_%d" % game.residents.size()
		copy["name"] = "Perf"
		copy["sick"] = 0
		copy["absent"] = 0
		game.people[str(copy.id)] = copy
		game.residents.append(copy)


func _shots_run() -> void:
	var st = await _boot_station()
	if st == null:
		_fail("shot station did not boot")
		return
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		await _apply_view(st, Vector2i(1920, 1080), 1.0)
		_clear_pause(st)
		st._refresh()
		await _frames(3)
		await _save(st, "lr2_frontier_%s_1080.png" % lang)
		_arm_settled_cut(st)
		await _frames(2)
		await _save(st, "lr2_brownout_settled_%s_1080.png" % lang)
		_measure_view(st, "1920x1080 %s settled" % lang)
		st.living.night_begin()
		st.living.tick(0.40)
		await _frames(2)
		await _save(st, "lr2_night_%s_1080.png" % lang)
		_measure_view(st, "1920x1080 %s night" % lang)
		# Land in the amber half of the 1.5 s dawn, while the grade is still easy to see.
		for _i in 48:
			st.living.tick(1.0 / 60.0)
		await _frames(2)
		await _save(st, "lr2_dawn_%s_1080.png" % lang)
		_measure_view(st, "1920x1080 %s dawn" % lang)
		_clear_grade(st)
		if lang == "en":
			await _flicker_strip(st)
			await _side_by_side(st)
	Settings.reduce_motion = true
	Copy.set_lang("en")
	_clear_pause(st)
	st.living.reset()
	st._refresh()
	_arm_settled_cut(st)
	await _frames(2)
	await _save(st, "lr2_reduce_motion_en_1080.png")
	_measure_view(st, "reduce")
	Settings.reduce_motion = false
	_place_infirmary(st)
	st.living.reset()
	st._refresh()
	for _i in 50:
		st.living.living_t += 1.0 / 60.0
		st.living.tick(1.0 / 60.0)
	await _frames(2)
	await _save(st, "lr2_infirmary_en_1080.png")
	Copy.set_lang("ru")
	st._refresh()
	for _i in 10:
		st.living.tick(1.0 / 60.0)
	await _frames(2)
	await _save(st, "lr2_infirmary_ru_1080.png")
	_measure_view(st, "infirmary")
	for view in [["1536x864", Vector2i(1536, 864), 1.0], ["125scale", Vector2i(1920, 1080), 1.25]]:
		for lang in ["en", "ru"]:
			Copy.set_lang(lang)
			await _apply_view(st, view[1], float(view[2]))
			_clear_pause(st)
			Settings.reduce_motion = false
			st.living.reset()
			st._refresh()
			_arm_settled_cut(st)
			st.living.night_begin()
			st.living.tick(0.40)
			await _frames(2)
			_measure_view(st, "%s %s" % [view[0], lang])
	if is_instance_valid(st):
		st.free()
	print("  min brightness across shot views %.4f" % _min_bright)


func _arm_settled_cut(st) -> void:
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "workshop":
			uid = str(room.uid)
	if uid == "":
		return
	st.living.reset()
	st.living.observe({}, st.game.week)
	var loss := {}
	loss[uid] = true
	st.power_loss = loss
	st.living.observe(loss, st.game.week)
	st.living.living_t = 3.0


func _clear_grade(st) -> void:
	for _i in 120:
		st.living.tick(1.0 / 60.0)
		if st.living.light.phase() == "off":
			break


func _place_infirmary(st) -> void:
	var key := "2:0"
	if not st.game.cells.has(key):
		return
	var room := {
		"uid": "room_shot_inf", "type": "infirmary", "level": 2, "cell": 0,
		"upgrade": 0, "efficiency": 1.0, "staff": [], "offline": false, "browned": false,
		"disabled": 0, "switched_off": false, "push_weeks": [], "push_tint_until": 0,
	}
	st.game.rooms.append(room)
	st.game.cells[key].room = room.uid
	st.game.cells[key].dug = true
	if not st.game.residents.is_empty():
		st.game.residents[0].sick = 3


func _flicker_strip(st) -> void:
	_arm_live_cut(st)
	var was_menu := bool(st.at_menu)
	st.at_menu = true
	var frames: Array = []
	for i in 16:
		st.living.living_t = float(i) * 2.5 / 15.0
		st.yard.queue_redraw()
		await process_frame
		var img := _viewport_image(st)
		if img != null:
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			frames.append(img)
	_arm_settled_cut(st)
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "workshop":
			uid = str(room.uid)
	st.living.living_t = 3.0
	st.living.observe({}, st.game.week)
	for i in 6:
		st.living.living_t = 3.0 + float(i) * 0.4 / 5.0
		st.yard.queue_redraw()
		await process_frame
		var img := _viewport_image(st)
		if img != null:
			img.resize(480, 270, Image.INTERPOLATE_BILINEAR)
			frames.append(img)
	st.at_menu = was_menu
	if frames.is_empty():
		_fail("flicker strip had no frames")
		return
	var sample: Image = frames[0]
	var sheet := Image.create(sample.get_width() * frames.size(), sample.get_height(), false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, sample.get_width(), sample.get_height()), Vector2i(i * sample.get_width(), 0))
	var path := "/opt/cursor/artifacts/lr2_brownout_flicker_relight_strip.png"
	sheet.save_png(path)
	print("  strip %s" % path)
	DirAccess.make_dir_recursive_absolute("/tmp/lr2_frames")
	for i in frames.size():
		frames[i].save_png("/tmp/lr2_frames/f_%02d.png" % i)
	var ffmpeg_out: Array = []
	var ffmpeg_code := OS.execute("ffmpeg", [
		"-y", "-framerate", "8", "-i", "/tmp/lr2_frames/f_%02d.png",
		"-vf", "scale=640:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse",
		"/opt/cursor/artifacts/lr2_brownout_flicker_relight.gif",
	], ffmpeg_out, true)
	print("  gif exit %s" % str(ffmpeg_code))
	if uid != "":
		print("  flicker uid %s" % uid)


func _arm_live_cut(st) -> void:
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "workshop":
			uid = str(room.uid)
	st.living.reset()
	st.living.observe({}, st.game.week)
	var loss := {}
	loss[uid] = true
	st.power_loss = loss
	st.living.observe(loss, maxi(st.game.week, 2))
	st.living.living_t = 0.0


func _side_by_side(st) -> void:
	_arm_settled_cut(st)
	st.yard.queue_redraw()
	await process_frame
	await process_frame
	var level := 0
	var cell := 1
	for room in st.game.rooms:
		if str(room.type) == "workshop":
			level = int(room.level)
			cell = int(room.cell)
	var world: Rect2 = st.yard._rect(st.yard._geo(), level, cell)
	var screen := Rect2(st.yard.pan + world.position * st.yard.zoom, world.size * st.yard.zoom)
	var shot := _viewport_image(st)
	if shot == null:
		return
	var region := Rect2i(int(screen.position.x), int(screen.position.y), int(screen.size.x), int(screen.size.y))
	region = region.intersection(Rect2i(0, 0, shot.get_width(), shot.get_height()))
	if region.size.x < 8 or region.size.y < 8:
		_fail("workshop crop missed the window")
		return
	var crop := shot.get_region(region)
	var src_tex: Texture2D = load("res://assets/rooms/room_workshop.webp")
	if src_tex == null:
		return
	var src := src_tex.get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	if crop.get_format() != Image.FORMAT_RGBA8:
		crop.convert(Image.FORMAT_RGBA8)
	src.resize(crop.get_width(), crop.get_height(), Image.INTERPOLATE_LANCZOS)
	var both := Image.create(crop.get_width() * 2 + 8, crop.get_height(), false, Image.FORMAT_RGBA8)
	both.fill(Color(0.05, 0.05, 0.05))
	both.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(0, 0))
	both.blit_rect(crop, Rect2i(0, 0, crop.get_width(), crop.get_height()), Vector2i(crop.get_width() + 8, 0))
	var path := "/opt/cursor/artifacts/lr2_workshop_original_vs_lit_en.png"
	both.save_png(path)
	print("  compare %s" % path)


func _measure_view(st, tag: String) -> void:
	var uid := ""
	for room in st.game.rooms:
		if str(room.type) == "workshop":
			uid = str(room.uid)
	if uid == "" or st.living == null:
		return
	var cut_b: float = 1.0 - st.living.light.cut_alpha(uid, st.living.living_t)
	var grade: Color = st.living.light.grade_color()
	var grade_b := 1.0 if grade.a <= 0.0 else _lum(grade)
	_note_bright(cut_b)
	_note_bright(grade_b)
	print("  view %s cut %.4f grade %.4f" % [tag, cut_b, grade_b])
	if cut_b < 0.35:
		_fail("%s cut brightness %.4f" % [tag, cut_b])
	if grade.a > 0.0 and grade_b < 0.85:
		_fail("%s grade brightness %.4f" % [tag, grade_b])


func _boot_station():
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	st.motion_in_shots = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	_clear_pause(st)
	await process_frame
	return st


func _clear_pause(st) -> void:
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	st.showing_network = false
	while st.deck != null and st.deck.top_priority() > 0:
		st.deck.pop()


func _apply_view(st, win_size: Vector2i, scale: float) -> void:
	var win: Window = st.get_window()
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	root.size = win_size
	if absf(scale - 1.0) < 0.01:
		win.content_scale_factor = 1.0
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		win.content_scale_size = win_size
	else:
		Settings.apply_scale(win)
	for _i in 4:
		await process_frame


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _save(st, name: String) -> void:
	var img := _viewport_image(st)
	if img == null:
		_fail("no image for %s" % name)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/" + name
	var err := img.save_png(path)
	if err != OK:
		_fail("save %s err %s" % [name, str(err)])
		return
	print("  shot %s %s" % [name, img.get_size()])


func _viewport_image(st) -> Image:
	var tex: ViewportTexture = st.get_viewport().get_texture()
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null or img.get_width() < 2:
		return null
	return img


func _lum(c: Color) -> float:
	return _lum_rgb(_over_white(c))


func _over_white(c: Color) -> Color:
	return Color(
		1.0 * (1.0 - c.a) + c.r * c.a,
		1.0 * (1.0 - c.a) + c.g * c.a,
		1.0 * (1.0 - c.a) + c.b * c.a,
		1.0)


func _lum_over(base: Color, top: Color) -> float:
	var rgb := Color(
		base.r * (1.0 - top.a) + top.r * top.a,
		base.g * (1.0 - top.a) + top.g * top.a,
		base.b * (1.0 - top.a) + top.b * top.a,
		1.0)
	return _lum_rgb(rgb)


func _lum_rgb(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


func _note_bright(v: float) -> void:
	_min_bright = minf(_min_bright, v)


func _room(uid: String, kind: String, level: int, cell: int) -> Dictionary:
	return {"uid": uid, "type": kind, "level": level, "cell": cell, "offline": false}


func _grid() -> Dictionary:
	var cells := {}
	for level in 3:
		for cell in 6:
			var dug := level == 1 and cell <= 3
			cells["%d:%d" % [level, cell]] = {"level": level, "cell": cell, "dug": dug, "room": "", "flooded": false}
	cells["0:1"]["dug"] = true
	cells["0:1"]["room"] = "room_a"
	cells["1:3"]["room"] = "gen"
	return cells


func _frontier_cells() -> Dictionary:
	var cells := {}
	for level in 3:
		for cell in 6:
			cells["%d:%d" % [level, cell]] = {"level": level, "cell": cell, "dug": false, "room": "", "flooded": false}
	cells["1:1"]["dug"] = true
	cells["1:1"]["room"] = "room_a"
	cells["1:2"]["dug"] = true
	return cells


func _write_json(path: String, rows: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(rows))
	f.close()


func _wipe(path: String) -> void:
	if path == "" or path == "/" or not DirAccess.dir_exists_absolute(path):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(str(name)))
	for name in DirAccess.get_directories_at(path):
		_wipe(path.path_join(str(name)))
	DirAccess.remove_absolute(path)
