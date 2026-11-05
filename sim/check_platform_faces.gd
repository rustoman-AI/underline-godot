extends SceneTree

## P88 Platform Faces gate.
##   godot --headless --path . -s res://sim/check_platform_faces.gd
## Balance ZERO. Soft dawn none. Map mark none. Schema 19.

const BASELINE_LOST := 20
const MASTER_HASH := [
	530485220, 1440811691, 812324724, 1813219972, 325093522, 595908171, 2008396391, 1780671410, 856785781, 158007594,
	927219026, 88326475, 1637882681, 1666385348, 109892276, 1909826692, 17422148, 1248879695, 53792616, 1638580681,
	1667606982, 225933280, 1956210069, 664024800, 910860718, 1749011044, 317060065, 247917712, 1212469253, 1368249385,
	1040415204, 699411940, 240273769, 1927554047, 1435382424, 289105020, 1555551452, 991802799, 73486466, 389179272,
	1820378459, 1369693866, 479947888, 2022586468, 14678228, 2098321440, 788241386, 462862112, 1956553458, 372817444,
	1943912010, 743372996, 2101744492, 1885192366, 1640866844, 1363718713, 230067406, 1872288106, 522666115, 82470554,
]
const LOST_SEEDS := "1,8,11,12,13,14,23,27,28,30,33,35,39,40,41,45,51,52,56,57"
const BUNKERS := ["archive", "vault", "signal", "oldcommand"]

var _failed := false


class Host extends Node:
	var game
	var showing_network := true
	var network_view = null
	var body_font: Font
	func _motion_off() -> bool:
		return true
	func _ui_click() -> void:
		pass
	func _portrait_box(id: String, px: int) -> TextureRect:
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(px, px)
		face.size = Vector2(px, px)
		face.set_meta("portrait_for", id)
		return face
	func _close_observer() -> void:
		pass
	func _toggle_network() -> void:
		showing_network = true
	func _map_toast_face() -> StyleBoxFlat:
		var face := StyleBoxFlat.new()
		face.bg_color = Color("efe4c8")
		face.border_color = Color("2b2118")
		face.set_border_width_all(1)
		face.set_content_margin_all(8)
		return face
	func _tip_plate_style() -> StyleBoxFlat:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.07, 0.06, 0.05, 0.97)
		plate.border_color = Color(0.93, 0.78, 0.42, 0.9)
		plate.set_border_width_all(1)
		plate.set_content_margin_all(8)
		return plate


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	PlatformFaces.enabled = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("PLATFORM FACES FAIL catalog")
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 19:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _roster(catalog):
		_failed = true
	else:
		print("Roster: ok")
	if not _memory(catalog):
		_failed = true
	else:
		print("Memory: ok")
	if not _priority(catalog):
		_failed = true
	else:
		print("Priority: ok")
	if not _save(catalog):
		_failed = true
	else:
		print("Save: ok")
	if not _bounds():
		_failed = true
	else:
		print("Bounds: ok")
	if not await _ui(catalog):
		_failed = true
	else:
		print("UI: ok")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if _failed:
		print("PLATFORM FACES FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("PLATFORM FACES FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("PLATFORM FACES FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	PlatformFaces.enabled = true
	print("PLATFORM FACES OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _fresh(catalog: Catalog, run_seed: int = 4) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 12)
	game.week = 6
	return game


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/platform_faces.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P88":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	var frag = JSON.parse_string(FileAccess.get_file_as_string("res://data/platform_faces_ru_fragment.json"))
	if rows.size() != 117 or not (frag is Dictionary) or frag.size() != 117:
		_bad("key count %s / %s" % [rows.size(), frag.size() if frag is Dictionary else "bad"])
		return false
	var faces: Dictionary = pack.get("_faces", {})
	if faces.size() != 20:
		_bad("face rows %d" % faces.size())
		return false
	var fems := 0
	for sid in faces:
		var row: Dictionary = faces[sid]
		if bool(row.get("fem", false)):
			fems += 1
		for part in ["name", "role", "cold", "warm", "held"]:
			var key := "regular.%s.%s" % [str(sid), part]
			if not rows.has(key):
				_bad("missing " + key)
				return false
	if fems != 9:
		_bad("fem flags %d" % fems)
		return false
	for key in rows:
		if not str(key).begins_with("regular."):
			_bad("namespace " + str(key))
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty " + str(key))
			return false
		if str(row.get("ru", "")) != str(frag.get(key, "")):
			_bad("ru drift " + str(key))
			return false
		var blob := (str(row.en) + " " + str(row.ru)).to_lower()
		if blob.find("gear") >= 0 or blob.find("снаряж") >= 0:
			_bad("gear in " + str(key))
			return false
		if blob.find("kept_bonus") >= 0 or blob.find("closed_bonus") >= 0:
			_bad("bonus in " + str(key))
			return false
	Copy.set_lang("ru")
	if Copy.t("regular.first") != "На платформе тебя теперь кто-то знает.":
		_bad("first ru")
		return false
	var gone_f := Copy.fill("regular.gone", {"name": "Агнес Торн", "fem": true})
	var gone_m := Copy.fill("regular.gone", {"name": "Теодор Варга", "fem": false})
	if gone_f.find("пропала") < 0 or gone_m.find("пропала") >= 0 or gone_m.find("пропал") < 0:
		_bad("gone agreement %s / %s" % [gone_f, gone_m])
		return false
	Copy.set_lang("en")
	if Copy.t("regular.title") != "Faces on the line":
		_bad("title en")
		return false
	return true


func _roster(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	if PlatformFaces.face_total(game) != 20 or PlatformFaces.face_ids().size() != 20:
		_bad("total %d" % PlatformFaces.face_total(game))
		return false
	for sid in game.stations:
		var id := str(sid)
		var st: Dictionary = game.stations[id]
		var bunker := bool(st.get("hidden", false)) or str(st.get("bunker", "")) != "" or str(st.get("owner", "")) == "bunker" or BUNKERS.has(id)
		var home := id == str(game.capital_id)
		var want := not bunker and not home
		if PlatformFaces.has_face(game, id) != want:
			_bad("has_face %s bunker %s home %s" % [id, bunker, home])
			return false
	if PlatformFaces.has_face(game, "southdepot") or PlatformFaces.has_face(game, "archive"):
		_bad("home or bunker face")
		return false
	if not PlatformFaces.has_face(game, "northgate") or not PlatformFaces.has_face(game, "westfield") or not PlatformFaces.has_face(game, "trampark") or not PlatformFaces.has_face(game, "chapel"):
		_bad("enemy capital or aqueduct missing")
		return false
	if PlatformFaces.dawn_chip() or PlatformFaces.joins_soft_dawn() or PlatformFaces.map_mark() or game.platform_faces_dawn_chip():
		_bad("dawn or map mark")
		return false
	if not PlatformFaces.carry_hook(game, "plaza").is_empty() or not PlatformFaces.station_day_hook(game, "plaza").is_empty():
		_bad("p89/p90 hook not empty")
		return false
	return true


func _touch(game: Game, sid: String) -> Dictionary:
	var st: Dictionary = game.stations[sid]
	st.known = true
	st.sympathy = 10
	st.owner = "neutral"
	st.low_weeks = 2
	return st


func _memory(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var sid := "brickworks"
	if PlatformFaces.meet(game, sid):
		_bad("met before known")
		return false
	if not PlatformFaces.line(game, sid).is_empty():
		_bad("line before met")
		return false
	PlatformFaces.note_order(game, {"order": "envoy", "station": sid})
	if int(PlatformFaces.memory(game, sid).met) != 0:
		_bad("order met an unknown station")
		return false
	_touch(game, sid)
	if not PlatformFaces.meet(game, sid) or int(PlatformFaces.memory(game, sid).met) != 6:
		_bad("visit meet")
		return false
	if PlatformFaces.meet(game, sid):
		_bad("met twice")
		return false
	var other := _fresh(catalog)
	_touch(other, sid)
	other.orders_left = 2
	other.stock.influence = 30
	for n in other._neighbors(sid):
		other.stations[str(n)].owner = other.player
	if not other._apply_order({"order": "envoy", "station": sid}):
		_bad("envoy apply " + other._envoy_block(sid))
		return false
	var mem := PlatformFaces.memory(other, sid)
	if int(mem.met) != 6 or str(mem.last_kind) != "envoy" or int(mem.last_week) != 6:
		_bad("apply hook %s" % str(mem))
		return false
	var queued := _fresh(catalog)
	_touch(queued, "plaza")
	queued.orders_left = 2
	queued.stock.influence = 30
	queued.stock.food = 40
	queued.stock.materials = 40
	queued.stock.tokens = 40
	queued.stock.air = 40
	queued.stock.power = 40
	for n in queued._neighbors("plaza"):
		queued.stations[str(n)].owner = queued.player
	queued.queued_orders = [{"action": {"order": "aid", "station": "plaza"}, "cost": {}, "role": "talk", "name": "Ada", "person": ""}]
	queued._resolve_queued()
	var qmem := PlatformFaces.memory(queued, "plaza")
	if str(qmem.last_kind) != "aid" or int(qmem.met) != 6:
		_bad("queued hook %s" % str(qmem))
		return false
	var cap := _fresh(catalog)
	_touch(cap, sid)
	if not cap._capture(sid, cap.player, true):
		_bad("force capture")
		return false
	if not bool(PlatformFaces.memory(cap, sid).taken):
		_bad("taken not set")
		return false
	var peace := _fresh(catalog)
	_touch(peace, sid)
	if not peace._capture(sid, peace.player, false):
		_bad("peace capture")
		return false
	if bool(PlatformFaces.memory(peace, sid).taken):
		_bad("peace set taken")
		return false
	var rival := _fresh(catalog)
	_touch(rival, sid)
	if not rival._capture(sid, "exchange", true):
		_bad("rival capture")
		return false
	if bool(PlatformFaces.memory(rival, sid).taken) or str(rival.stations[sid].owner) != "exchange":
		_bad("rival taken")
		return false
	return true


func _priority(catalog: Catalog) -> bool:
	var cold := _met(catalog, "brickworks")
	var row: Dictionary = PlatformFaces.line(cold, "brickworks")
	if int(row.slot) != 8 or str(row.key) != "regular.brickworks.cold" or PlatformFaces.render(row) != Copy.t("regular.brickworks.cold"):
		_bad("cold %s" % str(row))
		return false
	if _digits(PlatformFaces.render(row)):
		_bad("digits in cold")
		return false
	cold.stations.brickworks.sympathy = 55
	row = PlatformFaces.line(cold, "brickworks")
	if str(row.key) != "regular.brickworks.warm":
		_bad("warm " + str(row.key))
		return false
	cold.stations.brickworks.owner = cold.player
	row = PlatformFaces.line(cold, "brickworks")
	if str(row.key) != "regular.brickworks.held":
		_bad("held " + str(row.key))
		return false
	var gone := _met(catalog, "quarry")
	_touch(gone, "quarry")
	if not gone._capture("quarry", gone.player, true):
		_bad("gone capture")
		return false
	PlatformFaces.meet(gone, "quarry")
	PlatformFaces.note_order(gone, {"order": "assault", "dest": "quarry"})
	row = PlatformFaces.line(gone, "quarry")
	if int(row.slot) != 2 or str(row.key) != "regular.gone":
		_bad("gone %s" % str(row))
		return false
	if PlatformFaces.render(row).find("Wren Kowalski") < 0:
		_bad("gone name")
		return false
	var rival := _met(catalog, "mill")
	_touch(rival, "mill")
	if not rival._capture("mill", "exchange", true):
		_bad("rival line capture")
		return false
	PlatformFaces.meet(rival, "mill")
	row = PlatformFaces.line(rival, "mill")
	if int(row.slot) != 3 or str(row.key) != "regular.rival" or PlatformFaces.render(row).find("Free Exchange") < 0:
		_bad("rival %s %s" % [str(row.key), PlatformFaces.render(row)])
		return false
	var after := _met(catalog, "library")
	for kind in ["envoy", "trade", "aid", "propaganda", "probe", "patrol", "raid", "assault"]:
		var action := {"order": kind, "station": "library", "dest": "library"}
		PlatformFaces.note_order(after, action)
		row = PlatformFaces.line(after, "library")
		var want := "regular.after_raid" if kind == "raid" or kind == "assault" else ("regular.after_deal" if kind == "trade" else "regular.after_%s" % kind)
		if int(row.slot) != 4 or str(row.key) != want:
			_bad("after %s -> %s" % [kind, str(row.key)])
			return false
	after.regulars.library.last_week = int(after.week) - 2
	row = PlatformFaces.line(after, "library")
	if int(row.slot) != 8:
		_bad("after expired " + str(row.key))
		return false
	var greet := _met(catalog, "brickworks")
	greet.stations.brickworks.sympathy = 30
	greet.obs.kit_owned = ["carbide"]
	greet.obs.kit_worn.lamp = "carbide"
	row = PlatformFaces.line(greet, "brickworks")
	if int(row.slot) != 6 or str(row.key) != "obs.greet.carbide":
		_bad("greet %s" % str(row))
		return false
	var cached: Dictionary = PlatformFaces.line_cached(greet, "brickworks", {})
	if int(cached.slot) == 6:
		_bad("empty cache recomputed greet")
		return false
	var dead := _met(catalog, "brickworks")
	dead.departed.append({"how": "died", "place": str(dead.stations.brickworks.name), "name": "Owen", "name_ru": "Оуэн"})
	row = PlatformFaces.line(dead, "brickworks")
	if int(row.slot) != 7 or str(row.key) != "regular.your_dead" or PlatformFaces.render(row).find("Owen") < 0:
		_bad("dead %s %s" % [str(row.key), PlatformFaces.render(row)])
		return false
	if not PlatformFaces.carry_hook(dead, "brickworks").is_empty():
		_bad("carry slot")
		return false
	var home := _fresh(catalog)
	if not PlatformFaces.line(home, str(home.capital_id)).is_empty():
		_bad("home line")
		return false
	var aqueduct := _fresh(catalog)
	aqueduct.stations.westfield.known = true
	PlatformFaces.meet(aqueduct, "westfield")
	row = PlatformFaces.line(aqueduct, "westfield")
	if str(aqueduct.stations.westfield.owner) == "neutral" or int(row.slot) != 8 or str(row.key) != "regular.westfield.cold":
		_bad("aqueduct cold %s owner %s" % [str(row.key), str(aqueduct.stations.westfield.owner)])
		return false
	var capital := _fresh(catalog)
	capital.stations.northgate.known = true
	PlatformFaces.meet(capital, "northgate")
	row = PlatformFaces.line(capital, "northgate")
	if int(row.slot) != 8 or str(row.key) != "regular.northgate.cold":
		_bad("enemy capital cold " + str(row.key))
		return false
	return true


func _met(catalog: Catalog, sid: String) -> Game:
	var game := _fresh(catalog)
	_touch(game, sid)
	PlatformFaces.meet(game, sid)
	return game


func _digits(text: String) -> bool:
	for i in text.length():
		if text.unicode_at(i) >= 48 and text.unicode_at(i) <= 57:
			return true
	return false


func _save(catalog: Catalog) -> bool:
	var game := _met(catalog, "harbor")
	game.flags[PlatformFaces.SEEN] = true
	var data := game.export_state()
	data["schema"] = 19
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data):
		_bad("schema 19 load " + again.load_error)
		return false
	if int(PlatformFaces.memory(again, "harbor").met) != 6 or not bool(again.flags.get(PlatformFaces.SEEN, false)):
		_bad("round trip")
		return false
	data.erase("regulars")
	data["schema"] = 19
	var bare := Game.new()
	bare.catalog = catalog
	if bare.import_state(data):
		_bad("schema 19 accepted a save with no regulars")
		return false
	var old_data := game.export_state()
	old_data.erase("regulars")
	old_data["schema"] = 18
	if old_data.flags is Dictionary:
		old_data.flags.erase(PlatformFaces.SEEN)
	var old := Game.new()
	old.catalog = catalog
	if not old.import_state(old_data):
		_bad("schema 18 load " + old.load_error)
		return false
	if not old.regulars.is_empty() or bool(old.flags.get(PlatformFaces.SEEN, false)):
		_bad("old schema kept faces")
		return false
	var older := game.export_state()
	older.erase("regulars")
	older["schema"] = 17
	var back := Game.new()
	back.catalog = catalog
	if not back.import_state(older) or not back.regulars.is_empty():
		_bad("schema 17 migrate")
		return false
	var first := _met(catalog, "market")
	var line := PlatformFaces.claim_first(first)
	if line != Copy.t("regular.first") or PlatformFaces.claim_first(first) != "":
		_bad("first float once")
		return false
	var loaded := Game.new()
	loaded.catalog = catalog
	var snap := game.export_state()
	snap["schema"] = 19
	if not loaded.import_state(snap) or PlatformFaces.claim_first(loaded) != "":
		_bad("seen flag did not survive save")
		return false
	return true


func _bounds() -> bool:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 19") < 0 or src.find("V19_ADDED") >= 0:
		_bad("schema source")
		return false
	if src.find("V18_ADDED") < 0 or src.find("\"regulars\"") < 0:
		_bad("migration missing")
		return false
	if src.find("regulars[") >= 0 or src.find("regulars.get") >= 0 or src.find("PlatformFaces.line") >= 0 or src.find("PlatformFaces.list") >= 0:
		_bad("sim reads regulars")
		return false
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("regular") >= 0 or picker.find("platform_faces") >= 0:
		_bad("dawn picker knows faces")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _fn(view, "_draw_pin")
	if pin.find("PlatformFaces") >= 0 or pin.find("regular.") >= 0:
		_bad("map pin knows faces")
		return false
	if FileAccess.get_file_as_string("res://sim/bot.gd").find("regulars") >= 0:
		_bad("bot reads faces")
		return false
	var dir := DirAccess.open("res://sim")
	if dir == null:
		_bad("sim dir")
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".gd") and not name.begins_with("check_") and name != "platform_faces.gd" and name != "game.gd":
			var body := FileAccess.get_file_as_string("res://sim/" + name)
			if body.find("regulars") >= 0:
				_bad("sim file reads regulars " + name)
				return false
		name = dir.get_next()
	for path in ["res://sim/platform_faces.gd", "res://ui/network_view.gd", "res://ui/observer_panel.gd", "res://ui/station.gd", "res://data/platform_faces.json"]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("kept_bonus") >= 0 or body.find("closed_bonus") >= 0:
			_bad("bonus wired in " + path)
			return false
	var yard := FileAccess.get_file_as_string("res://ui/station.gd")
	var yard_fn := _fn(yard, "_show_regular_yard")
	if yard_fn.find("_tip_plate_style") < 0 or yard_fn.find("outline_size\", 0") < 0 or yard_fn.find("outline_size\", 6") >= 0:
		_bad("yard float plate")
		return false
	var map_fn := _fn(view, "_show_regular_float")
	if map_fn.find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	if view.find("PlatformFaces.enabled and PlatformFaces.has_face") < 0:
		_bad("greet still has its own row")
		return false
	var fill := _fn(view, "_fill_visit")
	var head_at := fill.find("add_child(head)")
	var face_at := fill.find("_add_face_row")
	var details_at := fill.find("_details_box")
	var transfer_at := fill.find("_add_transfer_status")
	var toll_at := fill.find("_add_quiet_toll")
	var ledger_at := fill.find("_add_outpost_ledger")
	if head_at < 0 or face_at < 0 or details_at < 0 or not (head_at < face_at and face_at < details_at):
		_bad("PF-U2 face placement")
		return false
	if transfer_at < 0 or toll_at < 0 or ledger_at < 0 or not (transfer_at < toll_at and toll_at < ledger_at):
		_bad("PF-U2 status source order")
		return false
	if face_at < ledger_at:
		_bad("face row moved into the status column")
		return false
	return true


func _fn(src: String, name: String) -> String:
	var at := src.find("func " + name)
	if at < 0:
		return ""
	var next := src.find("\nfunc ", at + 4)
	if next < 0:
		next = src.length()
	return src.substr(at, next - at)


func _ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	_touch(game, "brickworks")
	_touch(game, "observatory")
	for n in game._neighbors("brickworks"):
		game.stations[str(n)].owner = game.player
	var host := Host.new()
	host.game = game
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	root.add_child(host)
	var view := NetworkView.new()
	host.network_view = view
	view.host = host
	view.size = Vector2(1280, 720)
	view.visible = true
	root.add_child(view)
	await process_frame
	view.open_visit("archive")
	if _face(view) != null:
		_bad("bunker row")
		return false
	view.close_visit()
	view.open_visit(str(game.capital_id))
	if _face(view) != null:
		_bad("home row")
		return false
	view.close_visit()
	game.stations.brickworks.known = false
	view.open_visit("brickworks")
	if _face(view) != null or int(PlatformFaces.memory(game, "brickworks").met) != 0:
		_bad("unknown visit met")
		return false
	view.close_visit()
	game.stations.brickworks.known = true
	view.open_visit("brickworks")
	await process_frame
	if not _layout(view, "brickworks", 8, "regular.brickworks.cold"):
		return false
	if not bool(game.flags.get(PlatformFaces.SEEN, false)):
		_bad("PF-U7 flag")
		return false
	var plate := _meta_node(view, "regular_float")
	if plate == null or str(plate.text) != Copy.t("regular.first"):
		_bad("PF-U7 float")
		return false
	if int(plate.get_theme_constant("outline_size")) != 0:
		_bad("PF-N float outline")
		return false
	if not plate.get_theme_color("font_color").is_equal_approx(NetworkView.TAG_INK):
		_bad("PF-N float ink")
		return false
	var parent := plate.get_parent()
	if parent == null or not bool(parent.get_meta("map_float_plate", false)):
		_bad("PF-N float plate")
		return false
	if PlatformFaces.claim_first(game) != "":
		_bad("PF-U7 second float")
		return false
	if not _column_order(view):
		return false
	game.obs.kit_owned = ["carbide"]
	game.obs.kit_worn.lamp = "carbide"
	game.stations.brickworks.sympathy = 30
	view.open_visit("brickworks")
	await process_frame
	if not _one_greet(view, Copy.t("obs.greet.carbide")):
		return false
	Copy.set_lang("ru")
	host.body_font = load("res://assets/fonts/PTMono-Regular.ttf")
	game.stations.observatory.owner = game.player
	game.stations.observatory.sympathy = 0
	for size in [Vector2(1536, 864), Vector2(1280, 720), Vector2(1920, 1080)]:
		view.size = size
		view.open_visit("observatory")
		view._size_visit()
		await process_frame
		await process_frame
		if not _fits(view, "regular.observatory.held"):
			Copy.set_lang("en")
			return false
	Copy.set_lang("en")
	var panel_game := _fresh(catalog)
	var panel_host := Host.new()
	panel_host.game = panel_game
	panel_host.network_view = view
	root.add_child(panel_host)
	var panel := ObserverPanel.new()
	panel_host.add_child(panel)
	panel.present(panel_host)
	await process_frame
	if _meta_node(panel, "face_fold") != null:
		_bad("PF-N5 fold shown at 0")
		return false
	_touch(panel_game, "brickworks")
	panel_game._capture("brickworks", panel_game.player, true)
	PlatformFaces.meet(panel_game, "brickworks")
	_touch(panel_game, "plaza")
	PlatformFaces.meet(panel_game, "plaza")
	panel.present(panel_host)
	await process_frame
	var fold := _meta_node(panel, "face_fold")
	var listed := _metas(panel, "face_list")
	if fold == null or str(fold.text) != Copy.t("regular.title") or listed.size() != 2:
		_bad("faces fold %d" % listed.size())
		return false
	var muted: Button = listed[0]
	for button in listed:
		if str(button.get_meta("face_sid")) == "brickworks":
			muted = button
	if not bool(muted.get_meta("face_muted")) or not muted.get_theme_color("font_color").is_equal_approx(ObserverPanel.PAPER_MUTED):
		_bad("PF-N4 muted")
		return false
	if muted.get_theme_color("font_color").r > muted.get_theme_color("font_color").g + 0.2:
		_bad("PF-N4 red")
		return false
	var focus: StyleBoxFlat = muted.get_theme_stylebox("focus")
	if focus == null or focus.get_border_width(SIDE_LEFT) != 1:
		_bad("focus rim")
		return false
	muted.pressed.emit()
	await process_frame
	if view._visit_sid != "brickworks":
		_bad("list click visit " + str(view._visit_sid))
		return false
	view.queue_free()
	panel.queue_free()
	host.queue_free()
	panel_host.queue_free()
	return true


func _layout(view: NetworkView, sid: String, slot: int, key: String) -> bool:
	var rows := _metas(view, "face_row")
	if rows.size() != 1:
		_bad("PF-U1 rows %d" % rows.size())
		return false
	var row: Control = rows[0]
	if str(row.get_meta("face_sid")) != sid or int(row.get_meta("face_slot")) != slot or str(row.get_meta("face_key")) != key:
		_bad("PF-U8 %s %s" % [str(row.get_meta("face_key")), key])
		return false
	if row.tooltip_text != Copy.t("regular.tip"):
		_bad("tip " + row.tooltip_text)
		return false
	if int(row.get_theme_constant("separation")) != 8:
		_bad("PF-N1 gap")
		return false
	var portrait := _meta_node(row, "face_portrait")
	if portrait == null or not portrait.custom_minimum_size.is_equal_approx(Vector2(36, 36)):
		_bad("PF-N1 portrait")
		return false
	if str(portrait.get_meta("face_portrait")) != "regular_%s" % sid:
		_bad("portrait id")
		return false
	var line := _meta_node(row, "face_line")
	if line == null or int(line.get_theme_font_size("font_size")) != 14 or line.clip_text:
		_bad("PF-N2 quote")
		return false
	if str(line.text) != Copy.t(key) or _digits(str(line.text)):
		_bad("PF-U4 " + str(line.text))
		return false
	var body := view._visit_body
	var head := _meta_node(body, "visit_head")
	var details := _meta_node(body, "station_details")
	if head == null or details == null or row.get_parent() != body:
		_bad("PF-U2 missing head or details")
		return false
	if body.get_children().find(head) >= body.get_children().find(row) or body.get_children().find(row) >= body.get_children().find(details):
		_bad("PF-U2 order")
		return false
	return true


func _column_order(view: NetworkView) -> bool:
	var head := _meta_node(view._visit_body, "visit_head")
	if head == null:
		_bad("head")
		return false
	var column: Node = null
	for child in head.get_children():
		if child is VBoxContainer:
			column = child
	if column == null:
		_bad("status column")
		return false
	var transfer := -1
	var toll := -1
	var ledger := -1
	for i in column.get_child_count():
		var child: Node = column.get_child(i)
		if child.has_meta("transfer_status") or _has_meta_child(child, "transfer_status"):
			transfer = i
		if bool(child.get_meta("toll_row", false)):
			toll = i
		if bool(child.get_meta("ledger_row", false)):
			ledger = i
		if bool(child.get_meta("face_row", false)):
			_bad("face row inside status column")
			return false
	var seen: Array = []
	if transfer >= 0:
		seen.append(transfer)
	if toll >= 0:
		seen.append(toll)
	if ledger >= 0:
		seen.append(ledger)
	for i in range(1, seen.size()):
		if int(seen[i]) <= int(seen[i - 1]):
			_bad("PF-U2 status order %d %d %d" % [transfer, toll, ledger])
			return false
	return true


func _one_greet(view: NetworkView, text: String) -> bool:
	var hits := _count_text(view._visit_body, text)
	if hits != 1:
		_bad("PF-U3 greet hits %d" % hits)
		return false
	var row := _face(view)
	if row == null or str(row.get_meta("face_key")) != "obs.greet.carbide":
		_bad("PF-U3 not on the face row")
		return false
	return true


func _count_text(node: Node, text: String) -> int:
	var hits := 0
	if node is Label and str(node.text) == text:
		hits += 1
	for child in node.get_children():
		hits += _count_text(child, text)
	return hits


func _fits(view: NetworkView, key: String) -> bool:
	var row := _face(view)
	if row == null or str(row.get_meta("face_key")) != key:
		_bad("PF-U6 row " + key)
		return false
	var line := _meta_node(row, "face_line")
	if line == null or line.clip_text or int(line.get_theme_font_size("font_size")) != 14:
		_bad("PF-U6 clip or font")
		return false
	if line.get_line_count() > 3:
		_bad("PF-U6 lines %d" % line.get_line_count())
		return false
	var body: Control = view._visit_body
	var bottom := row.position.y + maxf(row.size.y, row.get_combined_minimum_size().y)
	var limit := maxf(body.size.y, body.get_combined_minimum_size().y)
	if bottom > limit + 2.0:
		_bad("PF-U6 outside body")
		return false
	return true


func _face(view: NetworkView) -> Control:
	var rows := _metas(view, "face_row")
	if rows.is_empty():
		return null
	return rows[0]


func _meta_node(node: Node, key: String) -> Node:
	if node is Control and node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _meta_node(child, key)
		if found != null:
			return found
	return null


func _metas(node: Node, key: String) -> Array:
	var out: Array = []
	if node is Control and node.has_meta(key):
		out.append(node)
	for child in node.get_children():
		out.append_array(_metas(child, key))
	return out


func _has_meta_child(node: Node, key: String) -> bool:
	return _meta_node(node, key) != null


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		PlatformFaces.enabled = true
		var on := _play(catalog, run_seed)
		PlatformFaces.enabled = false
		var off := _play(catalog, run_seed)
		if str(on.snap) != str(off.snap):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		if int(off.faces) != 0:
			_bad("seed %d off wrote regulars" % run_seed)
			return false
		var got := int(on.hash)
		var want := int(MASTER_HASH[run_seed - 1])
		if got == want:
			matched += 1
		else:
			_bad("seed %d hash %d master %d" % [run_seed, got, want])
		if str(on.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		print("Seed %d: %d %s %s" % [run_seed, got, str(on.over), "match" if got == want else "DIFF"])
	PlatformFaces.enabled = true
	print("Careful loss: %d/60 (master %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master, on/off identical" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss moved")
		return false
	return matched == 60 and not _failed


func _play(catalog: Catalog, run_seed: int) -> Dictionary:
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
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"snap": _snap(game),
		"faces": game.regulars.size(),
	}


func _snap(game: Game) -> String:
	var dead := 0
	for row in game.departed:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("how", "")) == "died":
			dead += 1
	var night := 0
	if game.flags.get("night_runs", null) is Dictionary:
		night = int(game.flags.night_runs.get("deaths", 0))
	return "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(), dead, night,
		int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state),
		int(game.story_rng.state), int(game.crunch_rng.state),
	]


func _outcome_hash(game: Game) -> int:
	var ids: Array = game.stations.keys()
	ids.sort()
	var held := PackedStringArray()
	for sid in ids:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != str(game.player):
			continue
		held.append("%s:%s:%s" % [str(sid), str(st.get("held_weeks", 0)), str(st.get("focus", ""))])
	var line := "%s|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [
		str(game.over), int(game.hope), int(game.discontent),
		int(game.stock.food), int(game.stock.materials), int(game.stock.air),
		int(game.stock.power), int(game.stock.tokens), int(game.stock.influence),
		game.residents.size(), ",".join(held)]
	var h := 5381
	for i in line.length():
		h = ((h << 5) + h) + line.unicode_at(i)
		h = h & 0x7fffffff
	return h
