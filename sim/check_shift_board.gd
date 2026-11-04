extends SceneTree

## P79 Shift Board gate.
##   godot --headless --path . -s res://sim/check_shift_board.gd
## Strings, seats, assign gates, skill pip, first float, soft dawn, and careful loss on seeds 1–60.

const LINES := [
	["shift.open", "Shifts", "Смены"],
	["shift.first", "Put people on the board.", "Поставь людей на доску."],
	["shift.empty", "Empty seat.", "Место свободно."],
	["shift.full", "Full.", "Полно."],
	["shift.assign", "Assign", "Назначить"],
	["shift.unassign", "Unassign", "Снять"],
	["shift.need_free", "No Free hands.", "Нет свободных рук."],
	["shift.skill_match", "Fits {skill}.", "Подходит: {skill}."],
	["shift.skill_low", "Low {skill}.", "Слабо: {skill}."],
	["shift.title", "Shift Board", "Доска смен"],
]

var failed := false


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("SHIFT CHECK FAILED catalog " + catalog.error)
		quit(1)
		return
	if _strings():
		print("strings ok")
	if _board(catalog):
		print("board ok")
	if _picker(catalog):
		print("picker ok")
	if _dawn(catalog):
		print("dawn ok")
	var lost := _careful_band(catalog)
	print("careful loss %d/60" % lost)
	if lost != 2:
		_bad("careful loss %d/60 moved off the preserved 2/60 baseline" % lost)
	if failed:
		print("SHIFT CHECK FAILED")
		quit(1)
	else:
		print("SHIFT OK")
		quit(0)


func _bad(why: String) -> void:
	failed = true
	print("FAIL " + why)


func _strings() -> bool:
	var before := failed
	if LINES.size() != 10:
		_bad("string table is not 10 keys")
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/shift_board.json"))
	if not (pack is Dictionary):
		_bad("shift_board.json did not parse")
		return false
	if str(pack.get("_roadmap", "")) != "P79":
		_bad("roadmap is not P79")
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn is not NONE")
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 10:
		_bad("by_key count %d" % rows.size())
	for key in rows:
		if not str(key).begins_with("shift."):
			_bad("namespace %s" % str(key))
		if str(key).begins_with("salvage"):
			_bad("salvage key %s" % str(key))
	for row in LINES:
		Copy.set_lang("en")
		var en := Copy.t(str(row[0]))
		Copy.set_lang("ru")
		var ru := Copy.t(str(row[0]))
		if en != str(row[1]) or ru != str(row[2]):
			_bad("%s en=%s ru=%s" % [row[0], en, ru])
		var spec: Dictionary = rows.get(str(row[0]), {})
		if str(spec.get("en", "")) != str(row[1]) or str(spec.get("ru", "")) != str(row[2]):
			_bad("pack drift %s" % str(row[0]))
	Copy.set_lang("en")
	if Copy.fill("shift.skill_match", {"skill": Copy.skill("labor", false)}) != "Fits labor.":
		_bad("en match pip " + Copy.fill("shift.skill_match", {"skill": Copy.skill("labor", false)}))
	if Copy.fill("shift.skill_low", {"skill": Copy.skill("tech", false)}) != "Low tech.":
		_bad("en low pip")
	Copy.set_lang("ru")
	if Copy.fill("shift.skill_match", {"skill": Copy.skill("labor", false)}) != "Подходит: труд.":
		_bad("ru match pip " + Copy.fill("shift.skill_match", {"skill": Copy.skill("labor", false)}))
	if Copy.fill("shift.skill_low", {"skill": Copy.skill("tech", false)}) != "Слабо: техника.":
		_bad("ru low pip " + Copy.fill("shift.skill_low", {"skill": Copy.skill("tech", false)}))
	Copy.set_lang("en")
	return failed == before


func _board(catalog: Catalog) -> bool:
	var before := failed
	var game := _game(catalog)
	var hope := int(game.hope)
	var mats := int(game.stock.materials)
	var food := int(game.stock.food)
	var staff_before := _staff_map(game)
	var rows: Array = game.shift_board_rows()
	if _staff_map(game) != staff_before:
		_bad("board rows changed staffing")
	if int(game.hope) != hope or int(game.stock.materials) != mats or int(game.stock.food) != food:
		_bad("board rows moved hope or stock")
	var seen := {}
	for row in rows:
		var uid := str(row.get("room_id", ""))
		if bool(row.get("building", false)):
			if uid != "":
				_bad("building row has a room id")
			if int(row.seats.size()) != int(row.staff_max):
				_bad("building seats %d vs %d" % [row.seats.size(), int(row.staff_max)])
			for seat in row.seats:
				if seat.get("person_id", null) != null:
					_bad("building seat is occupied")
			continue
		var room = game._room(uid)
		if room == null:
			_bad("missing room " + uid)
			continue
		if bool(room.offline):
			_bad("offline room on the board " + uid)
		var defin: Dictionary = game.catalog.rooms[str(room.type)]
		if not bool(defin.get("buildable", false)) or int(defin.staff_max) <= 0:
			_bad("unstaffed room on the board " + str(room.type))
		if int(row.staff_min) != int(defin.staff_min) or int(row.staff_max) != int(defin.staff_max):
			_bad("staff range drift " + str(room.type))
		var occupied := 0
		var seats: Array = row.seats
		if room.staff.size() <= int(defin.staff_max) and seats.size() != int(defin.staff_max):
			_bad("seats %d staff_max %d for %s" % [seats.size(), int(defin.staff_max), room.type])
		for i in seats.size():
			var seat: Dictionary = seats[i]
			if i < room.staff.size():
				if str(seat.get("person_id", "")) != str(room.staff[i]):
					_bad("seat order drift")
				occupied += 1
			elif seat.get("person_id", null) != null:
				_bad("empty seat has a person")
		if bool(row.full) != (room.staff.size() >= int(defin.staff_max)):
			_bad("full flag " + str(room.type))
		seen[uid] = true
		if str(room.type) == "platform" or str(room.type) == "quarters":
			_bad("platform or quarters listed")
	for room in game.rooms:
		var type := str(room.type)
		var defin: Dictionary = game.catalog.rooms[type]
		var want := bool(defin.get("buildable", false)) and int(defin.get("staff_max", 0)) > 0 and not bool(room.offline)
		if want and not seen.has(str(room.uid)):
			_bad("online room missing " + type)
		if not want and seen.has(str(room.uid)):
			_bad("room should be off the board " + type)
	var air = _room(game, "air_filter")
	if air != null:
		game.apply({"kind": "switch", "room": str(air.uid), "on": false})
		var still := false
		for row in game.shift_board_rows():
			if str(row.get("room_id", "")) == str(air.uid):
				still = true
		if still:
			_bad("switched-off room stayed on the board")
		game.apply({"kind": "switch", "room": str(air.uid), "on": true})
	var spot := _open_cell(game)
	if spot.x < 0:
		_bad("no open cell for a building row")
	else:
		game.stock.materials = maxi(int(game.stock.materials), 40)
		if not game.apply({"kind": "build", "type": "infirmary", "level": spot.x, "cell": spot.y}):
			_bad("infirmary build did not start")
		else:
			var found := false
			for row in game.shift_board_rows():
				if bool(row.get("building", false)) and str(row.get("name", "")) == Copy.t("Infirmary"):
					found = int(row.staff_max) == 2 and int(row.seats.size()) == 2
			if not found:
				_bad("building infirmary missing from the board")
	if game.shift_clip_name("Samira Holt") != "Samira Holt":
		_bad("short name clipped")
	if game.shift_clip_name("Alexandria Quinn") != "Alexandria Q…":
		_bad("long name clip " + game.shift_clip_name("Alexandria Quinn"))
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	var at := ui.find("## P79-SHIFT-BEGIN")
	var end := ui.find("## P79-SHIFT-END", at)
	var block := ui.substr(at, end - at) if at >= 0 and end > at else ""
	if block == "":
		_bad("station shift block missing")
	if block.find("_open_shift_board") < 0 or block.find("_show_shift_board") < 0:
		_bad("board open missing")
	if ui.find("_button(\"shift.open\", _open_shift_board)") < 0:
		_bad("desk Shifts button missing")
	if ui.find("_button(\"shift.title\", _open_shift_board)") < 0:
		_bad("People board button missing")
	if block.find("present_dawn_soft_chip") >= 0 or block.find("_build_dawn_chip") >= 0:
		_bad("shift block touches the dawn chip")
	if block.find("_auto_staff") >= 0:
		_bad("shift block auto-assigns")
	if block.find("salvage.") >= 0:
		_bad("shift block uses salvage.")
	if block.find("_confirm(") >= 0:
		_bad("shift block opens a confirm")
	if block.find("shift_board_panel") >= 0 or block.find("chalk_frame") >= 0:
		_bad("shift block requires art")
	return failed == before


func _picker(catalog: Catalog) -> bool:
	var before := failed
	var game := _game(catalog)
	var shop = _room(game, "workshop")
	if shop == null:
		_bad("no workshop")
		return false
	var uid := str(shop.uid)
	while shop.staff.size() > 1:
		game.apply({"kind": "unassign", "person": str(shop.staff[shop.staff.size() - 1])})
	var hope := int(game.hope)
	var mats := int(game.stock.materials)
	var out_before := game.output_of("materials")
	var free_id := ""
	var low_id := ""
	var match_id := ""
	for person in game.residents:
		var id := str(person.id)
		if game._is_child(person) or game._staff_room_of(id) != "" or game._locked_ids().has(id):
			continue
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		if free_id == "":
			free_id = id
		var band := game.shift_skill_band(id, "labor")
		if band == "low" and low_id == "":
			low_id = id
		if band == "match" and match_id == "":
			match_id = id
	if free_id == "" or low_id == "" or match_id == "":
		_bad("picker sample missing free=%s low=%s match=%s" % [free_id, low_id, match_id])
		return failed == before
	if game.output_of("materials") != out_before or int(game.hope) != hope or int(game.stock.materials) != mats:
		_bad("skill pip moved output, hope, or materials")
	Copy.set_lang("en")
	if game.shift_pip_line(match_id, "labor") != "Fits labor.":
		_bad("match line " + game.shift_pip_line(match_id, "labor"))
	if game.shift_pip_line(low_id, "labor") != "Low labor.":
		_bad("low line " + game.shift_pip_line(low_id, "labor"))
	var pick: Dictionary = game.shift_picker(uid)
	if not _has_id(pick.free, match_id) or not _has_id(pick.free, low_id):
		_bad("free hands missing from the picker")
	if bool(pick.need_free):
		_bad("need_free while free hands exist")
	for person in game.residents:
		var id := str(person.id)
		if game._staff_room_of(id) != "" and _has_id(pick.free, id):
			_bad("seated person listed as Free")
		if game._locked_ids().has(id) and _has_id(pick.free, id):
			_bad("crew listed as Free")
	var sick_id := low_id
	game.people[sick_id].sick = 3
	if bool(game.assign_preview(sick_id, uid).ok):
		_bad("sick assign_preview passed")
	var away_id := ""
	for person in game.residents:
		var id := str(person.id)
		if id == sick_id or game._staff_room_of(id) != "" or game._is_child(person):
			continue
		if game._locked_ids().has(id):
			continue
		away_id = id
		break
	if away_id == "":
		_bad("no away sample")
	else:
		game.people[away_id].absent = 2
		if bool(game.assign_preview(away_id, uid).ok):
			_bad("away assign_preview passed")
	pick = game.shift_picker(uid)
	if _has_id(pick.free, sick_id) or not _blocked_state(pick.blocked, sick_id, "sick"):
		_bad("sick not blocked on the picker")
	if away_id != "" and (_has_id(pick.free, away_id) or not _blocked_state(pick.blocked, away_id, "away")):
		_bad("away not blocked on the picker")
	game.people[sick_id].sick = 0
	if away_id != "":
		game.people[away_id].absent = 0
	if not bool(game.assign_preview(match_id, uid).ok):
		_bad("healthy free preview failed")
	var seated: int = shop.staff.size()
	if not game.apply({"kind": "assign", "person": match_id, "room": uid}):
		_bad("assign did not apply")
	elif not shop.staff.has(match_id):
		_bad("assign did not seat them")
	if shop.staff.size() != seated + 1:
		_bad("assign seat count")
	if not game.apply({"kind": "unassign", "person": match_id}):
		_bad("unassign did not apply")
	elif shop.staff.has(match_id):
		_bad("unassign left them seated")
	for person in game.residents:
		var id := str(person.id)
		if game._staff_room_of(id) != "" or game._is_child(person) or game._locked_ids().has(id):
			continue
		game.people[id].sick = 2
	pick = game.shift_picker(uid)
	if not pick.free.is_empty() or not bool(pick.need_free):
		_bad("need_free did not trip when nobody is Free")
	if int(game.hope) != hope:
		_bad("picker path changed hope")
	return failed == before


func _dawn(catalog: Catalog) -> bool:
	var before := failed
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	var game := _game(catalog)
	if game.shift_board_dawn_chip() or game.party_away_dawn_chip() or game.sick_cots_dawn_chip():
		_bad("a sticky or shift dawn chip returned true")
	if game.dawn_soft_stack() != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn_soft_stack " + str(game.dawn_soft_stack()))
	var dawn_flags := {
		"rumor_dawn": game.flags.get("rumor_dawn", null),
		"border_dawn_new": game.flags.get("border_dawn_new", null),
		"heard_rail": game.flags.get("heard_rail", null),
		"home_pending": game.flags.get("home_pending", null),
		"home_dawn": game.flags.get("home_dawn", null),
		"dawn_soft_kind": game.flags.get("dawn_soft_kind", null),
	}
	if not game.shift_note_seen():
		_bad("first open did not float")
	if game.shift_note_seen():
		_bad("second open floated again")
	for key in dawn_flags:
		if game.flags.get(key, null) != dawn_flags[key]:
			_bad("first float wrote dawn flag " + str(key))
	if str(game._pick_dawn_soft_chip().get("kind", "")) == "shift":
		_bad("dawn picker returned shift")
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var end := src.find("func dawn_soft_chip", at)
	var picker := src.substr(at, end - at)
	if picker.find("shift") >= 0:
		_bad("soft dawn picker mentions shift")
	if Game.SAVE_SCHEMA != 14:
		_bad("save schema moved to %d" % Game.SAVE_SCHEMA)
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var copy := Game.new()
	copy.catalog = catalog
	if not copy.import_state(data):
		_bad("seen flag did not round-trip: " + copy.load_error)
	elif not bool(copy.flags.get("seen_shift_board", false)):
		_bad("seen_shift_board missing after load")
	var sim := _between(src, "## P79-SHIFT-BEGIN", "## P79-SHIFT-END")
	if sim.find("_auto_staff") >= 0 or sim.find("stock.") >= 0 or sim.find("hope ") >= 0:
		_bad("shift sim block grants or auto-assigns")
	return failed == before


func _between(text: String, start: String, stop: String) -> String:
	var at := text.find(start)
	var end := text.find(stop, at + start.length())
	if at < 0 or end < at:
		return ""
	return text.substr(at, end - at)


func _careful_band(catalog: Catalog) -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = true
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		if str(game.over) != "time":
			lost += 1
			print("  careful seed %d over %s week %s" % [run_seed, game.over, game.week])
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return lost


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _room(game: Game, type: String):
	for room in game.rooms:
		if str(room.type) == type:
			return room
	return null


func _open_cell(game: Game) -> Vector2i:
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if game._cell_buildable(spot):
				return Vector2i(level, cell)
	return Vector2i(-1, -1)


func _staff_map(game: Game) -> String:
	var bits: PackedStringArray = []
	for room in game.rooms:
		var ids: PackedStringArray = []
		for id in room.staff:
			ids.append(str(id))
		bits.append("%s=%s" % [str(room.uid), ",".join(ids)])
	return "|".join(bits)


func _has_id(rows: Array, id: String) -> bool:
	for row in rows:
		if str(row.get("id", "")) == id:
			return true
	return false


func _blocked_state(rows: Array, id: String, state: String) -> bool:
	for row in rows:
		if str(row.get("id", "")) == id:
			return bool(row.get("blocked", false)) and str(row.get("state", "")) == state
	return false
