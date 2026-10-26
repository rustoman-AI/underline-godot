extends SceneTree

## P56 gate: yard confirm toasts and the End-turn Ahead panel.
##   godot --headless --path . -s res://sim/check_yard_confirm_ahead.gd
## Settings, saves and logs stay under user://check_yard_confirm_ahead.

const SCRATCH := "user://check_yard_confirm_ahead"
const KINDS := ["dig", "build", "upgrade", "rally", "law", "repeal", "burn"]

var failed := false
var st


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_scratch()
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		_bad("catalog " + catalog.error)
		_finish()
		return
	_strings()
	_balance(catalog)
	_projection(catalog)
	_dawn_stack(catalog)
	if not await _ui(catalog):
		_failed_mark()
	_finish()


func _scratch() -> void:
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = false
	Settings.hints_seen = []
	Settings.reduce_motion = true
	Settings.intro_seen = true
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")


func _finish() -> void:
	print("YARD CONFIRM AHEAD FAIL" if failed else "YARD CONFIRM AHEAD OK")
	quit(1 if failed else 0)


func _failed_mark() -> void:
	failed = true


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_bad(msg)


func _strings() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/yard_confirm_ahead.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P56" or not (pack.get("by_key", {}) is Dictionary):
		_bad("yard_confirm_ahead.json")
		return
	var rows: Dictionary = pack.by_key
	if rows.size() != 9:
		_bad("pack size %d" % rows.size())
	Copy.set_lang("en")
	for key in rows:
		if Copy.t(str(key)) != str(rows[key].get("en", "")):
			_bad("EN %s got %s" % [str(key), Copy.t(str(key))])
	Copy.set_lang("ru")
	for key in rows:
		if Copy.t(str(key)) != str(rows[key].get("ru", "")):
			_bad("RU %s got %s" % [str(key), Copy.t(str(key))])
	Copy.set_lang("en")
	var dig := Copy.fill("station.toast_dig", {"weeks": "3"})
	_expect(dig == "Dig started · 3 left", "dig fill " + dig)
	var built := Copy.fill("station.toast_build", {"room": "Workshop", "weeks": "2"})
	_expect(built == "Building Workshop · 2 left", "build fill " + built)
	var rally := Copy.fill("station.toast_rally", {"d": "-4", "h": "+1"})
	_expect(rally == "Rally held · Discontent -4 · Hope +1", "rally fill " + rally)
	var long_line := "Law passed · " + "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
	var clipped := Copy.clip(long_line, 72)
	_expect(clipped.length() == 72 and clipped.ends_with("…"), "clip %d %s" % [clipped.length(), clipped])
	Copy.set_lang("ru")
	var dig_ru := Copy.fill("station.toast_dig", {"weeks": "3"})
	_expect(dig_ru == "Раскопки начаты · осталось 3", "dig ru " + dig_ru)
	var law_ru := Copy.fill("station.toast_law", {"name": "Паёк"})
	_expect(law_ru == "Закон принят · Паёк", "law ru " + law_ru)
	_expect(Copy.t("ahead.clear") == "Можно завершить ход", "clear ru")
	_expect(Copy.t("ahead.blocked") == "Ещё что-то ждёт вас", "blocked ru")
	_expect(Copy.t("station.toast_demolish") == "Снесли · {room}", "demolish ru left alone")
	Copy.set_lang("en")
	_expect(Copy.t("station.toast_demolish") == "Pulled down · {room}", "demolish en left alone")
	_expect(Copy.t("station.toast_switch_on") == "Room running again", "switch en left alone")
	if not failed:
		print("Strings: ok")


func _balance(catalog: Catalog) -> void:
	var bal: Dictionary = catalog.balance
	_expect(int(bal.get("rally_discontent", 0)) == -4, "rally_discontent moved")
	_expect(int(bal.get("rally_hope", 0)) == 1, "rally_hope moved")
	_expect(int(bal.get("burn_hope", 0)) == -2, "burn_hope moved")
	_expect(int(bal.get("revolt_warn", 0)) == 70, "revolt_warn moved")
	for key in bal:
		var name := str(key)
		if name.begins_with("toast") or name.begins_with("ahead") or name.begins_with("yard_confirm"):
			_bad("balance key " + name)
	if not failed:
		print("Balance: ok")


func _projection(catalog: Catalog) -> void:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	var proj: Dictionary = game.dawn_projection()
	for key in ["air", "food", "power", "materials", "tokens", "influence"]:
		var outlook: Dictionary = game.resource_outlook(key)
		var want := maxi(0, int(outlook.next))
		if int(proj.get(key, -999)) != want:
			_bad("projection %s %s != outlook %s" % [key, str(proj.get(key)), str(want)])
	if not proj.has("hope") or not proj.has("discontent"):
		_bad("projection missing hope")
	var again: Dictionary = game.dawn_projection()
	if int(again.hope) != int(proj.hope) or int(again.food) != int(proj.food):
		_bad("projection drifted between calls")
	if not failed:
		print("Projection: ok")


func _dawn_stack(catalog: Catalog) -> void:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return
	var game := Game.new()
	game.setup(catalog, 4, 40)
	var stack: Array = game.dawn_soft_stack()
	if stack != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft order " + str(stack))
		return
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.contains("yard_confirm") or src.contains("ahead.clear"):
		_bad("P56 joined the sim")
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.contains("people_chip") or ui.contains("L3 People"):
		_bad("people chips landed")
	if not failed:
		print("Dawn: ok")


func _boot(catalog: Catalog) -> bool:
	st = load("res://ui/station.tscn").instantiate()
	root.add_child(st)
	for _i in 8:
		await process_frame
	if st.game == null:
		_bad("station has no game")
		return false
	st.shot_mode = true
	st.at_menu = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	_reset(catalog)
	st.set_anchors_preset(Control.PRESET_TOP_LEFT)
	st.size = Vector2(1280, 720)
	await process_frame
	return true


func _reset(catalog: Catalog) -> void:
	st.game = Game.new()
	st.game.setup(catalog, 3, 40)
	st.game.notices.clear()
	st.game.pending.clear()
	st.yard.station = st
	st.hold_dawn = true
	st.at_menu = false
	st.showing_network = false
	st._refresh()
	st.hold_dawn = false
	st.game.notices.clear()
	st.toast_hits = 0


func _ui(catalog: Catalog) -> bool:
	if not await _boot(catalog):
		return false
	_toasts(catalog)
	_doubles(catalog)
	await _ahead(catalog)
	_plate()
	if OS.get_environment("P56_SHOTS") == "1":
		await _shots(catalog)
	st.queue_free()
	return not failed


func _quiet_overlays() -> void:
	st.at_menu = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	if st.night != null:
		st.night.visible = false
	for child in st.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	if st.salvage_float != null and is_instance_valid(st.salvage_float):
		st.salvage_float.visible = false


func _grab(dir: String, shot_name: String) -> void:
	_quiet_overlays()
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var toast_at := ""
	if st.toast_label != null:
		toast_at = "%s vis %s" % [str(st.toast_label.position), str(st.toast_label.visible)]
	var ahead_box := ""
	if st.ahead != null:
		ahead_box = "vis %s top %s bot %s" % [str(st.ahead.visible), str(st.ahead.offset_top), str(st.ahead.offset_bottom)]
	print("FRAME %s station %s toast [%s] %s ahead %s" % [shot_name, str(st.size), "" if st.toast_label == null else st.toast_label.text, toast_at, ahead_box])
	var tex := root.get_texture()
	if tex == null:
		_bad("no viewport for " + shot_name)
		return
	var img := tex.get_image()
	var path := dir.path_join("p56_%s.png" % shot_name)
	var err := img.save_png(path)
	print("SHOT %s %dx%d err %s bright %d" % [path, img.get_width(), img.get_height(), str(err), _bright(img)])


func _bright(img: Image) -> int:
	var n := 0
	var step := 8
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.45:
				n += 1
	return n


func _hide_toast() -> void:
	if st.toast_label != null:
		st.toast_label.visible = false
	if st.toast_plate != null:
		st.toast_plate.visible = false
	if st.ahead != null:
		st.ahead.visible = false


func _shots(catalog: Catalog) -> void:
	var dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	await st._settle(Vector2i(1280, 720))
	_quiet_overlays()
	st._close_card()
	_reset(catalog)
	_hide_toast()
	var game: Game = st.game
	game.stock.materials = 80
	var at := _dig_cell(game)
	st._do_confirm({"kind": "dig", "level": at.x, "cell": at.y})
	if st.ahead != null:
		st.ahead.visible = false
	await _grab(dir, "toast_dig")
	_reset(catalog)
	_hide_toast()
	game = st.game
	game.stock.materials = 80
	var spot := _build_cell(game)
	st._do_confirm({"kind": "build", "type": "infirmary", "level": spot.x, "cell": spot.y})
	if st.ahead != null:
		st.ahead.visible = false
	await _grab(dir, "toast_build")
	_reset(catalog)
	_hide_toast()
	game = st.game
	_calm(game)
	game.stock.materials = 80
	at = _dig_cell(game)
	if at.x >= 0:
		game.apply({"kind": "dig", "level": at.x, "cell": at.y})
	game.notices.clear()
	st.dim.visible = false
	st._show_ahead(true)
	await process_frame
	st._place_ahead()
	await _grab(dir, "ahead_clear")
	game.discontent = 92
	st._show_ahead(true)
	await process_frame
	st._place_ahead()
	await _grab(dir, "ahead_blocked")
	if not st.showing_network:
		st._toggle_network()
	await process_frame
	await process_frame
	if st.network_view != null:
		st.network_view.council_open = true
		st.network_view._fill_council()
		st.network_view._place_panels()
	if st.ahead != null:
		st.ahead.visible = false
	st._toast(Copy.fill("station.toast_dig", {"weeks": "2"}))
	await _grab(dir, "toast_map")


func _free_person(game: Game) -> String:
	for person in game.residents:
		if game._is_child(person) or int(person.sick) > 0 or int(person.absent) > 0:
			continue
		if str(person.get("post", "")) != "":
			continue
		return str(person.id)
	return ""


func _staff_hall(game: Game) -> void:
	var uid := ""
	for room in game.rooms:
		if str(room.type) == "meeting_hall":
			uid = str(room.uid)
	if uid == "":
		game._place_room("meeting_hall", 2, 0)
		uid = "room_2_0_meeting_hall"
	var pid := _free_person(game)
	if pid != "":
		game.apply({"kind": "assign", "person": pid, "room": uid})
	game.law_lock = 0
	game.rally_lock = 0
	game.notices.clear()


func _dig_cell(game: Game) -> Vector2i:
	for level in 3:
		for cell in 6:
			if bool(game.dig_preview(level, cell).ok):
				return Vector2i(level, cell)
	return Vector2i(-1, -1)


func _build_cell(game: Game) -> Vector2i:
	for key in game.cells:
		var spot: Dictionary = game.cells[key]
		if game._cell_buildable(spot):
			return Vector2i(int(spot.level), int(spot.cell))
	return Vector2i(-1, -1)


func _room_uid(game: Game, type: String) -> String:
	for room in game.rooms:
		if str(room.type) == type:
			return str(room.uid)
	return ""


func _toast_is(want: String, hits: int, label: String) -> void:
	var got := "" if st.toast_label == null else str(st.toast_label.text)
	if st.toast_hits != hits:
		_bad("%s hits %d want %d (%s)" % [label, st.toast_hits, hits, got])
		return
	if got != want:
		_bad("%s toast %s" % [label, got])
		return
	if got.length() > 72:
		_bad("%s longer than 72" % label)


func _toasts(catalog: Catalog) -> void:
	_reset(catalog)
	var game: Game = st.game
	game.stock.materials = 80
	game.stock.blueprints = 3
	var at := _dig_cell(game)
	if at.x < 0:
		_bad("no dig cell")
		return
	st.toast_hits = 0
	st._do_confirm({"kind": "dig", "level": at.x, "cell": at.y})
	var weeks := str(int(game.dig.get("left", 0)))
	_toast_is(Copy.fill("station.toast_dig", {"weeks": weeks}), 1, "dig")
	_expect(not game.dig.is_empty(), "dig did not start")

	_reset(catalog)
	game = st.game
	game.stock.materials = 80
	var spot := _build_cell(game)
	if spot.x < 0:
		_bad("no build cell")
	else:
		st.toast_hits = 0
		st._do_confirm({"kind": "build", "type": "workshop", "level": spot.x, "cell": spot.y})
		var room := Copy.t(str(game.catalog.rooms.workshop.name))
		var left := str(int(game.build.get("left", 0)))
		_toast_is(Copy.fill("station.toast_build", {"room": room, "weeks": left}), 1, "build")

	_reset(catalog)
	game = st.game
	game.stock.materials = 80
	game.stock.blueprints = 3
	var uid := _room_uid(game, "quarters")
	st.toast_hits = 0
	st._do_upgrade(uid)
	_toast_is(Copy.fill("station.toast_upgrade", {"room": Copy.t("Quarters")}), 1, "upgrade button")
	_reset(catalog)
	game = st.game
	game.stock.materials = 80
	game.stock.blueprints = 3
	uid = _room_uid(game, "quarters")
	st.toast_hits = 0
	st._do_confirm({"kind": "upgrade", "room": uid})
	_toast_is(Copy.fill("station.toast_upgrade", {"room": Copy.t("Quarters")}), 1, "upgrade confirm")

	_reset(catalog)
	game = st.game
	game.stock.materials = 40
	_staff_hall(game)
	st.toast_hits = 0
	st._do_confirm({"kind": "rally"})
	_toast_is(Copy.fill("station.toast_rally", {
		"d": st._signed(int(game.bal.rally_discontent)),
		"h": st._signed(int(game.bal.rally_hope)),
	}), 1, "rally")

	_reset(catalog)
	game = st.game
	_staff_hall(game)
	st.toast_hits = 0
	st._do_confirm({"kind": "law", "law": "rationing"})
	_toast_is(Copy.fill("station.toast_law", {"name": Copy.t("Rationing")}), 1, "law confirm")

	_reset(catalog)
	game = st.game
	_staff_hall(game)
	st.toast_hits = 0
	st._enact("rationing")
	_toast_is(Copy.fill("station.toast_law", {"name": Copy.t("Rationing")}), 1, "law enact")
	_expect(game._law_on("rationing"), "enact did not pass")

	_reset(catalog)
	game = st.game
	_staff_hall(game)
	game.apply({"kind": "law", "law": "curfew"})
	game.law_lock = 0
	game.notices.clear()
	st.toast_hits = 0
	st._do_confirm({"kind": "repeal", "law": "curfew"})
	_toast_is(Copy.fill("station.toast_repeal", {"name": Copy.t("Curfew")}), 1, "repeal")

	_reset(catalog)
	game = st.game
	game.stock.materials = 40
	st.toast_hits = 0
	st._do_confirm({"kind": "burn"})
	_toast_is(Copy.t("station.toast_burn"), 1, "burn")

	_reset(catalog)
	game = st.game
	_staff_hall(game)
	game.catalog.laws.rationing.name = "A law name that runs far past the seventy-two character toast plate so the line must clip"
	st.toast_hits = 0
	st._enact("rationing")
	var clipped := "" if st.toast_label == null else str(st.toast_label.text)
	_expect(st.toast_hits == 1 and clipped.length() == 72 and clipped.ends_with("…"), "enact clip " + clipped)
	if not failed:
		print("Toasts: ok")


func _doubles(catalog: Catalog) -> void:
	_reset(catalog)
	var game: Game = st.game
	var uid := _room_uid(game, "workshop")
	var room = game._room(uid)
	var pulled := Copy.t(str(game.catalog.rooms[str(room.type)].name))
	st.toast_hits = 0
	st._do_confirm({"kind": "demolish", "room": uid})
	_toast_is(Copy.fill("station.toast_demolish", {"room": pulled}), 1, "demolish")
	_expect(not str(st.toast_label.text).contains("Upgrade ordered"), "demolish doubled")

	_reset(catalog)
	game = st.game
	uid = _room_uid(game, "generator")
	var saves := int(game.switch_preview(uid).get("saves", 0))
	st.toast_hits = 0
	st._switch_room(uid, false)
	_toast_is(Copy.fill("station.toast_switch_off", {"n": saves}), 1, "switch")
	_expect(not str(st.toast_label.text).contains("Dig started") and not str(st.toast_label.text).contains("Pulled down"), "switch doubled")

	_reset(catalog)
	game = st.game
	uid = _room_uid(game, "workshop")
	var pid := _free_person(game)
	st.toast_hits = 0
	st._assign_person(pid, uid)
	var assigned := "" if st.toast_label == null else str(st.toast_label.text)
	_expect(st.toast_hits == 1, "assign hits %d" % st.toast_hits)
	_expect(assigned.begins_with("Assigned "), "assign toast " + assigned)
	_expect(not assigned.contains("Dig started") and not assigned.contains("Law passed"), "assign doubled")
	if not failed:
		print("Doubles: ok")


func _calm(game: Game) -> void:
	game.pending.clear()
	game.stock.food = 400
	game.stock.air = 400
	game.stock.power = 400
	game.stock.materials = 400
	game.stock.tokens = 40
	game.stock.influence = 40
	game.hope = 90
	game.discontent = 10
	game.quarantine = false
	game.notices.clear()
	var guard := 0
	while game.residents.size() > game.housing() and guard < 8:
		var spot := _build_cell(game)
		if spot.x < 0:
			break
		game._place_room("quarters", spot.x, spot.y)
		guard += 1


func _meter(key: String) -> Control:
	for child in st.ahead_box.get_children():
		if child.has_meta("ahead_key") and str(child.get_meta("ahead_key")) == key:
			return child
	return null


func _meter_text(row: Control) -> String:
	var bits: PackedStringArray = []
	for child in row.get_children():
		if child is Label:
			bits.append(str(child.text))
	return "".join(bits)


func _ahead(catalog: Catalog) -> void:
	_reset(catalog)
	var game: Game = st.game
	_calm(game)
	game.dig = {"level": 1, "cell": 4, "left": 2, "workers": []}
	game.build = {"type": "workshop", "level": 2, "cell": 1, "left": 2, "workers": []}
	game.queued_orders = [{}, {}, {}, {}]
	st.ahead.visible = true
	st._fill_ahead()
	await process_frame
	st._place_ahead()
	var proj: Dictionary = game.dawn_projection()
	for key in ["air", "food", "power", "materials", "tokens", "influence", "hope", "discontent"]:
		var row := _meter(key)
		if row == null:
			_bad("missing meter " + key)
			continue
		var now: int = int(st._ahead_now(key))
		var after: int = int(proj.get(key, now))
		var delta: int = after - now
		var text := _meter_text(row)
		var want := "%s  %d  →  %d" % [Copy.res(key), now, after]
		if delta != 0:
			want += "   (%s)" % st._signed(delta)
		if text != want:
			_bad("meter %s got %s want %s" % [key, text, want])
		if delta == 0 and text.contains("("):
			_bad("zero delta kept a parenthesis " + key)
		if delta != 0:
			var mark: Label = null
			for child in row.get_children():
				if child is Label and child.has_meta("ahead_sign"):
					mark = child
			if mark == null:
				_bad("no sign " + key)
			else:
				var color: Color = mark.get_theme_color("font_color")
				var expect: Color = st.DELTA_UP if delta > 0 else st.DELTA_DOWN
				if color != expect:
					_bad("delta color " + key)
	var queues: PackedStringArray = []
	var footer := ""
	for child in st.ahead_box.get_children():
		if child.has_meta("ahead_queue"):
			queues.append(str(child.text))
		if child.has_meta("ahead_footer"):
			footer = str(child.text)
	if queues.size() != 3:
		_bad("queue lines %d %s" % [queues.size(), str(queues)])
	else:
		_expect(queues[0].begins_with("Dig · ") and queues[0].contains("Generator") and queues[0].ends_with("2 weeks"), "dig line " + queues[0])
		_expect(queues[1] == Copy.fill("station.tip_building", {"room": "Workshop", "weeks": "2"}), "build line " + queues[1])
		_expect(queues[2] == "Orders queued: 4", "orders line " + queues[2])
	var h: float = float(st.ahead.offset_bottom - st.ahead.offset_top)
	var w: float = float(st.ahead.offset_right - st.ahead.offset_left)
	_expect(w >= 248.0, "ahead width %s" % str(w))
	_expect(h <= 280.0 and h > 40.0, "ahead height %s" % str(h))
	if game.forecasts().is_empty() and game.revolt_warning().is_empty() and st._end_state() != "waiting":
		_expect(footer == Copy.t("ahead.clear"), "clear footer " + footer)
	else:
		_bad("calm state was not clear forecasts=%s revolt=%s waiting=%s hope=%d food=%d" % [str(game.forecasts()), str(not game.revolt_warning().is_empty()), st._end_state(), game.hope, int(game.stock.food)])

	game.hope = 40
	st._fill_ahead()
	footer = ""
	for child in st.ahead_box.get_children():
		if child.has_meta("ahead_footer"):
			footer = str(child.text)
	_expect(not game.forecasts().is_empty(), "hope did not forecast")
	_expect(footer == Copy.t("ahead.blocked"), "forecast footer " + footer)

	_calm(game)
	game.discontent = 90
	st._fill_ahead()
	footer = ""
	for child in st.ahead_box.get_children():
		if child.has_meta("ahead_footer"):
			footer = str(child.text)
	_expect(not game.revolt_warning().is_empty(), "revolt did not warn")
	_expect(footer == Copy.t("ahead.blocked"), "revolt footer " + footer)

	_calm(game)
	game.pending = [{"id": "lamps", "major": true, "choices": []}]
	st._fill_ahead()
	footer = ""
	for child in st.ahead_box.get_children():
		if child.has_meta("ahead_footer"):
			footer = str(child.text)
	_expect(st._end_state() == "waiting", "pending was not waiting")
	_expect(footer == Copy.t("ahead.blocked"), "waiting footer " + footer)
	if not failed:
		print("Ahead: ok")


func _plate() -> void:
	st.showing_network = true
	st.size = Vector2(1280, 720)
	st.toast_hits = 0
	st._toast("Dig started · 2 left")
	if st.toast_plate == null or not st.toast_plate.visible or st.toast_label.get_parent() != st.toast_plate:
		_bad("map plate missing")
		return
	var face: StyleBoxFlat = st.toast_plate.get_theme_stylebox("panel") as StyleBoxFlat
	if face == null or face.bg_color.get_luminance() > 0.15:
		_bad("map plate is not dark")
	var plate_w: float = float(st._toast_text_width(st.toast_label)) + 28.0
	var expect_x: float = (float(st.size.x) - plate_w) * 0.5
	if absf(st.toast_plate.position.x - expect_x) > 1.0:
		_bad("map toast not centered %s vs %s" % [str(st.toast_plate.position.x), str(expect_x)])
	var council_right := 14.0 + 220.0
	if st.toast_plate.position.x <= council_right:
		_bad("map toast overlaps the council column")
	var ink: Color = st.toast_label.get_theme_color("font_color")
	if ink.get_luminance() < 0.5:
		_bad("map toast ink is dark")
	st.showing_network = false
	st._toast("Order sent. The result comes at next dawn.")
	if st.toast_plate.visible or st.toast_label.get_parent() != st:
		_bad("station toast kept the plate")
	if st.toast_label.position.x > 60.0:
		_bad("station toast is not top-left")
	if not failed:
		print("Plate: ok")
