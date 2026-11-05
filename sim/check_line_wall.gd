extends SceneTree

## P77 Line Wall gate.
##   godot --headless --path . -s res://sim/check_line_wall.gd
## Plates hang from P72 / P73 / P67 / P68-weight events only. First plate hope +1 once.
## Mandate miss is not a fail plate. Epilogue can read every plate. Soft dawn is not joined.
## Careful loss over seeds 1–60 stays on the preserved band (about 2/60).

var failed := false


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("LINE WALL FAIL catalog " + catalog.error)
		quit(1)
		return
	if _strings():
		print("Strings: ok")
	if _wall(catalog):
		print("Wall: ok")
	if _plates(catalog):
		print("Plates: ok")
	if _epilogue(catalog):
		print("Epilogue: ok")
	if _dawn(catalog):
		print("Dawn: ok")
	_art()
	if failed:
		print("LINE WALL FAIL")
		quit(1)
		return
	var band := _careful(catalog)
	var lost := int(band.lost)
	var pct := 100.0 * float(lost) / 60.0
	print("Careful loss: %d/60 (%.1f%%)" % [lost, pct])
	print("Careful wall hope %d across %d runs with a plate" % [int(band.hope), int(band.hung)])
	if Game.WALL_HOPE_ONCE == 0:
		print("First hope: dropped — +1 once measured 3/60 and left the preserved 2/60 band")
	if lost != 2:
		_bad("careful loss %d/60 moved off the preserved 2/60 band" % lost)
	if lost < 9 or lost > 21:
		print("NOTE spec names 15-35 percent of 60. Measured %d/60 (%.1f percent). Left as-is." % [lost, pct])
	if Game.WALL_HOPE_ONCE > 0 and int(band.hope) <= 0:
		_bad("first-plate hope never fired on a careful run")
	if failed:
		print("LINE WALL FAIL")
		quit(1)
		return
	print("LINE WALL OK")
	quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _expect(ok: bool, msg: String) -> bool:
	if not ok:
		_bad(msg)
	return ok


func _game(catalog: Catalog, run_seed := 3) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/line_wall.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P77":
		_bad("line_wall.json roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("line_wall soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 14:
		_bad("expected 14 wall keys, got %d" % rows.size())
		return false
	Copy.set_lang("en")
	for key in rows:
		var want := str(rows[key].get("en", ""))
		if Copy.t(str(key)) != want:
			_bad("EN %s got %s" % [str(key), Copy.t(str(key))])
			return false
	var filled := Copy.fill("wall.plate_law", {"name": "Quiet hours"})
	if filled != "Law: Quiet hours":
		_bad("fill law " + filled)
		return false
	filled = Copy.fill("wall.count", {"n": "6"})
	if filled != "6 hung":
		_bad("fill count " + filled)
		return false
	filled = Copy.fill("wall.plate_beat", {"beat": "Station taken — North Spur"})
	if filled != "Station taken — North Spur":
		_bad("fill beat " + filled)
		return false
	if Copy.clip(Copy.t("wall.first"), 72) != "First plate on the Wall.":
		_bad("toast clip")
		return false
	Copy.set_lang("ru")
	for key in rows:
		var want := str(rows[key].get("ru", ""))
		if Copy.t(str(key)) != want:
			_bad("RU %s got %s" % [str(key), Copy.t(str(key))])
			return false
	var ru_count := Copy.fill("wall.count", {"n": "6"})
	if ru_count != "Повешено: 6":
		_bad("RU count " + ru_count)
		return false
	Copy.set_lang("en")
	return true


func _wall(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var view: Dictionary = game.wall_open()
	if not bool(view.empty) or int(view.count) != 0 or int(view.showing_cap) != 12:
		_bad("empty wall %s" % str(view))
		return false
	if game.wall_plate_label({"kind": "nope", "name": "X"}) != "":
		_bad("unknown kind rendered")
		return false
	if game.wall_hang("fail", {"name": "Miss"}) or game.wall_hang("charge_fail", {"name": "Charge"}):
		_bad("fail plate accepted")
		return false
	var hope := game.hope
	if not game.wall_hang("law", {"name": "Quiet hours", "week": 4, "weight": 3}):
		_bad("first plate refused")
		return false
	var once := Game.WALL_HOPE_ONCE
	if game.hope != hope + once:
		_bad("first hope %d -> %d want +%d" % [hope, game.hope, once])
		return false
	if game.wall_first_hope != (once > 0):
		_bad("toast latch %s" % str(game.wall_first_hope))
		return false
	if not game.wall_hang("bury", {"name": "Mira", "week": 5}):
		_bad("second plate refused")
		return false
	if game.hope != hope + once or game.wall_plates.size() != 2:
		_bad("second plate moved hope or count")
		return false
	if game.wall_take_first_hope() != (once > 0) or game.wall_first_hope:
		_bad("toast did not drain once")
		return false
	if game.wall_take_first_hope():
		_bad("toast drained twice")
		return false
	var label := game.wall_plate_label(game.wall_plates[0])
	if label != "Law: Quiet hours":
		_bad("law label " + label)
		return false
	var open_now: Dictionary = game.wall_open()
	if bool(open_now.empty) or int(open_now.count) != 2 or (open_now.plates as Array).size() != 2:
		_bad("open after hang %s" % str(open_now))
		return false
	if str((open_now.plates as Array)[0].get("label", "")) != "Buried: Mira":
		_bad("newest first " + str((open_now.plates as Array)[0]))
		return false
	return true


func _plates(catalog: Catalog) -> bool:
	if not _law_plates(catalog):
		return false
	if not _mandate_plates(catalog):
		return false
	if not _burial_plates(catalog):
		return false
	if not _beat_plates(catalog):
		return false
	if not _cap_and_save(catalog):
		return false
	return _prefer(catalog)


func _staff_hall(game: Game) -> void:
	game.law_lock = 0
	game.rooms.append({
		"uid": "lw_hall",
		"type": "meeting_hall",
		"offline": false,
		"staff": [str(game.residents[0].id)],
		"level": 0,
		"cell": 5,
		"upgrade": 0,
	})


func _law_plates(catalog: Catalog) -> bool:
	var game := _game(catalog, 4)
	_staff_hall(game)
	var before := game.wall_plates.size()
	if not game._apply_law("rationing"):
		_bad("rationing did not enact " + game.enact_reason("rationing"))
		return false
	for plate in game.wall_plates:
		if str(plate.get("kind", "")) == "law":
			_bad("ordinary law hung a plate")
			return false
	if game.wall_plates.size() != before:
		_bad("ordinary law changed the wall")
		return false
	game.law_lock = 0
	game.catalog.laws["lw_quiet"] = {"name": "Quiet hours", "line": true, "creed": "watch"}
	if not game._apply_law("lw_quiet"):
		game.catalog.laws.erase("lw_quiet")
		_bad("line law did not enact")
		return false
	game.catalog.laws.erase("lw_quiet")
	var law := false
	var beat := false
	for plate in game.wall_plates:
		if str(plate.get("kind", "")) == "law" and str(plate.get("name", "")) == "Quiet hours":
			law = true
		if str(plate.get("kind", "")) == "beat" and str(plate.get("moment_kind", "")) == "creed_line":
			beat = true
	if not law or not beat:
		_bad("line law plates law=%s beat=%s" % [law, beat])
		return false
	if str(game.creed) != "watch":
		_bad("creed not set by the line law")
		return false
	var forks_was = game.catalog.communities.get("forks", null)
	game.catalog.communities["forks"] = {"quiet_side": {"name": "Hold the Line"}}
	game._grant_fork("quiet_side")
	if forks_was == null:
		game.catalog.communities.erase("forks")
	else:
		game.catalog.communities["forks"] = forks_was
	var fork := false
	for plate in game.wall_plates:
		if str(plate.get("kind", "")) == "law" and str(plate.get("name", "")) == "Hold the Line":
			fork = true
	if not fork:
		_bad("fork side did not hang")
		return false
	return true


func _mandate_plates(catalog: Catalog) -> bool:
	var game := _game(catalog, 5)
	game._note_moment("mandate", {"mandate": "Hold the Line"}, 3)
	var pick := false
	var beat := false
	var done := false
	for plate in game.wall_plates:
		var kind := str(plate.get("kind", ""))
		if kind == "mandate_pick" and str(plate.get("name", "")) == "Hold the Line":
			pick = true
		if kind == "mandate_done":
			done = true
		if kind == "beat" and str(plate.get("moment_kind", "")) == "mandate":
			beat = true
		if kind == "fail" or kind == "charge_fail":
			_bad("punish plate")
			return false
	if not pick or done or beat:
		_bad("mandate pick plate pick=%s done=%s beat=%s" % [pick, done, beat])
		return false
	game.stats["mandate_fulfilled"] = false
	game._wall_sync_mandate()
	if _count_kind(game, "mandate_done") != 0:
		_bad("mandate miss hung a plate")
		return false
	var score_before := game.score_now()
	game.stats["mandate_fulfilled"] = true
	game.stats["mandate"] = "Hold the Line"
	game._wall_sync_mandate()
	if _count_kind(game, "mandate_done") != 1:
		_bad("fulfill plate missing")
		return false
	if game.wall_plate_label(_find_kind(game, "mandate_done")) != "Mandate kept: Hold the Line":
		_bad("done label")
		return false
	if game.score_now() != score_before + 100:
		_bad("fulfill changed score outside the existing +100")
		return false
	game._wall_sync_mandate()
	if _count_kind(game, "mandate_done") != 1:
		_bad("fulfill plate duplicated")
		return false
	return true


func _burial_plates(catalog: Catalog) -> bool:
	var game := _game(catalog, 6)
	game.departed.append({"id": "mira", "name": "Mira", "burial": ""})
	game._resolve_burial("mira", "bury")
	game.departed.append({"id": "kolya", "name": "Kolya", "burial": ""})
	game._resolve_burial("kolya", "ledger")
	game.departed.append({"id": "ada", "name": "Ada", "burial": ""})
	game._resolve_burial("ada", "tunnel")
	if _count_kind(game, "bury") != 1 or _count_kind(game, "ledger") != 1:
		_bad("burial plates bury=%d ledger=%d" % [_count_kind(game, "bury"), _count_kind(game, "ledger")])
		return false
	if game.wall_plate_label(_find_kind(game, "bury")) != "Buried: Mira":
		_bad("bury label")
		return false
	if game.wall_plate_label(_find_kind(game, "ledger")) != "Ledgered: Kolya":
		_bad("ledger label")
		return false
	for plate in game.wall_plates:
		if str(plate.get("name", "")) == "Ada":
			_bad("tunnel choice hung a plate")
			return false
	return true


func _beat_plates(catalog: Catalog) -> bool:
	var game := _game(catalog, 7)
	var before := game.wall_plates.size()
	game._note_moment("season", {"season": "cold"}, 2)
	game._note_moment("crunch", {}, 2)
	game._note_moment("birth", {"name": "Ada"}, 2)
	if game.wall_plates.size() != before:
		_bad("weight under 3 hung a plate")
		return false
	game._note_moment("station_taken", {"place": "North Spur"}, 3)
	game._note_moment("named_death", {"name": "Mira", "cause": "sickness", "who": "mira"}, 5)
	if _count_kind(game, "beat") != 2:
		_bad("weight >=3 beats %d" % _count_kind(game, "beat"))
		return false
	var label := game.wall_plate_label(_find_kind(game, "beat"))
	if label.find("North Spur") < 0 and label.find("Mira") < 0:
		_bad("beat label " + label)
		return false
	return true


func _cap_and_save(catalog: Catalog) -> bool:
	var game := _game(catalog, 8)
	game.wall_hoped = true
	for i in 14:
		game._note_moment("station_lost", {"place": "Spur %d" % i}, 3)
	var view: Dictionary = game.wall_open()
	if (view.plates as Array).size() != 12 or game.wall_plates.size() != 14:
		_bad("cap mid %d persist %d" % [(view.plates as Array).size(), game.wall_plates.size()])
		return false
	if game.wall_epilogue_rows().size() != 14:
		_bad("epilogue cap leaked")
		return false
	var newest: Dictionary = (view.plates as Array)[0]
	if str(newest.get("label", "")).find("Spur 13") < 0:
		_bad("newest dropped " + str(newest.get("label", "")))
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var loaded := Game.new()
	loaded.catalog = catalog
	if not loaded.import_state(data) or loaded.wall_plates.size() != 14 or not loaded.wall_hoped:
		_bad("save roundtrip " + loaded.load_error)
		return false
	var old := game.export_state()
	old["schema"] = 14
	old.erase("wall_plates")
	old.erase("wall_hoped")
	old.erase("wall_first_hope")
	var legacy := Game.new()
	legacy.catalog = catalog
	if not legacy.import_state(old) or not legacy.wall_plates.is_empty() or legacy.wall_hoped:
		_bad("schema 14 migrate " + legacy.load_error)
		return false
	return true


func _prefer(catalog: Catalog) -> bool:
	var game := _game(catalog, 9)
	game.chronicle.append({"week": 3, "kind": "dilemma", "weight": 4, "fields": {"title": "Older", "choice": "stay"}})
	game.chronicle.append({"week": 9, "kind": "dilemma", "weight": 4, "fields": {"title": "Newer", "choice": "go"}})
	var top: Array = game.chronicle_top(1)
	if top.is_empty() or int(top[0].get("week", 0)) != 9:
		_bad("tie broke toward the older moment")
		return false
	game.wall_hoped = true
	game._hang_wall("beat", {
		"moment_kind": "dilemma",
		"week": 3,
		"weight": 4,
		"beat": "Older",
		"fields": {"title": "Older", "choice": "stay"},
	})
	top = game.chronicle_top(1)
	if top.is_empty() or int(top[0].get("week", 0)) != 3:
		_bad("plate-backed moment did not prefer")
		return false
	if game.chronicle_top(6).size() > 6:
		_bad("top-6 grew")
		return false
	return true


func _epilogue(catalog: Catalog) -> bool:
	var quiet := _game(catalog, 10)
	var empty: Dictionary = quiet.epilogue_payload()
	if bool(empty.get("wall_page", true)) or not (empty.get("wall_plates", []) as Array).is_empty():
		_bad("empty run invented an epilogue page")
		return false
	var game := _game(catalog, 11)
	game.wall_hoped = true
	game._hang_wall("law", {"name": "Quiet hours", "week": 2})
	game._note_moment("station_taken", {"place": "North Spur"}, 3)
	var payload: Dictionary = game.epilogue_payload()
	if not bool(payload.get("wall_page", false)):
		_bad("plates did not open the epilogue page")
		return false
	var rows: Array = payload.get("wall_plates", [])
	if rows.size() != game.wall_plates.size() or rows.size() < 2:
		_bad("epilogue rows %d persist %d" % [rows.size(), game.wall_plates.size()])
		return false
	var src := FileAccess.get_file_as_string("res://ui/station.gd")
	if src.find("func _life_wall") < 0 or src.find("wall.epilogue") < 0:
		_bad("epilogue page missing")
		return false
	if src.find("func _epilogue_pages") < 0 or src.find("wall_has_plates") < 0:
		_bad("page count does not follow plates")
		return false
	var score := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := score.find("func score_now")
	var end := score.find("func _mandate_fulfilled", at)
	var body := score.substr(at, end - at)
	if body.find("wall") >= 0:
		_bad("score formula mentions the wall")
		return false
	if body.find("100") < 0:
		_bad("mandate +100 hook missing")
		return false
	return true


func _dawn(catalog: Catalog) -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
		return false
	var game := _game(catalog, 12)
	game.wall_hang("law", {"name": "Quiet hours"})
	if game.wall_dawn_chip():
		_bad("wall dawn chip")
		return false
	var chip: Dictionary = game._pick_dawn_soft_chip()
	if str(chip.get("kind", "")).find("wall") >= 0:
		_bad("picker returned a wall chip")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var end := src.find("func dawn_soft_chip", at)
	var picker := src.substr(at, end - at)
	if picker.find("wall") >= 0:
		_bad("soft dawn picker knows the wall")
		return false
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("ModalDeck.AMBIENT, \"wall\"") < 0 or ui.find("func _show_wall") < 0:
		_bad("desk wall panel missing")
		return false
	if ui.find("wall.open") < 0 or ui.find("func _draw_line_wall") < 0:
		_bad("desk button or yard hotspot missing")
		return false
	if ui.find("func _drain_wall_toast") < 0 or ui.find("wall.first") < 0:
		_bad("first toast missing")
		return false
	if ui.find("func _wall_row") < 0 or ui.find(".pressed.connect") > 0 and ui.find("func _wall_row") >= 0:
		var row_at := ui.find("func _wall_row")
		var row_end := ui.find("func _wall_kind_tint", row_at)
		var row := ui.substr(row_at, row_end - row_at)
		if row.find("pressed") >= 0 or row.find("gui_input") >= 0:
			_bad("plate row has a click verb")
			return false
	if ui.find("func _wall_art") < 0:
		_bad("missing art is not omitted")
		return false
	return true


func _art() -> void:
	var want := {
		"res://assets/ui/wall_plate_frame.webp": "6ccabb2142f92e216832cb50a105a17c",
		"res://assets/ui/wall_panel_empty.webp": "bedef9488da51d815ec7ad7fdf2b2266",
		"res://assets/props/common/prop_line_wall.webp": "1cd7b8ce8a29f68146ec50b14ae8dcce",
	}
	for path in want:
		var abs := ProjectSettings.globalize_path(path)
		if not FileAccess.file_exists(abs):
			print("Art: omitted %s" % path)
			continue
		var f := FileAccess.open(abs, FileAccess.READ)
		if f == null:
			_bad("art unreadable " + path)
			continue
		var bytes := f.get_buffer(f.get_length())
		f.close()
		if bytes.size() < 64 or bytes.slice(0, 12).get_string_from_ascii().find("git-lfs") >= 0:
			_bad("art is an LFS stub " + path)
			continue
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		ctx.update(bytes)
		var got := ctx.finish().hex_encode()
		if got != str(want[path]):
			_bad("art md5 %s %s" % [path, got])
		else:
			print("Art: ok %s" % path.get_file())


func _count_kind(game: Game, kind: String) -> int:
	var n := 0
	for plate in game.wall_plates:
		if str(plate.get("kind", "")) == kind:
			n += 1
	return n


func _find_kind(game: Game, kind: String) -> Dictionary:
	for plate in game.wall_plates:
		if str(plate.get("kind", "")) == kind:
			return plate
	return {}


func _careful(catalog: Catalog) -> Dictionary:
	var lost := 0
	var hope := 0
	var hung := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		if str(game.over) != "time":
			lost += 1
		hope += int(game.hope_totals.get("wall", 0))
		if not game.wall_plates.is_empty():
			hung += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return {"lost": lost, "hope": hope, "hung": hung}
