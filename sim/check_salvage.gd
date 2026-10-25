extends SceneTree

## Salvage board: blueprints, the twelve nodes, strip, the dormant junk hook, save schema 12,
## desk empty states, and the careful loss band (15–35% of seeds 1–60, 40 weeks).
##   godot --headless --path . -s res://sim/check_salvage.gd

const Desk = preload("res://ui/station.gd")

const LINES := [
	["salvage.title", "Salvage", "Утиль"],
	["salvage.tier0", "Tier 0", "Уровень 0"],
	["salvage.tier1", "Tier 1", "Уровень 1"],
	["salvage.tier2", "Tier 2", "Уровень 2"],
	["salvage.strip", "Strip scrap", "Разобрать лом"],
	["salvage.strip_tip", "Workshop · 4 materials · once / 3 weeks · +1 blueprint", "Мастерская · 4 материала · раз в 3 недели · +1 чертёж"],
	["salvage.gained_strip", "Blueprint from scrap.", "Чертёж из лома."],
	["salvage.gained_raid", "Blueprint from the raid.", "Чертёж с набега."],
	["salvage.gained_junk", "Blueprint from the junk flow.", "Чертёж из потока утиля."],
	["salvage.fitted", "Fitted {name}", "Поставили: {name}"],
	["salvage.locked", "Need a blueprint.", "Нужен чертёж."],
	["salvage.blueprints", "Blueprints", "Чертежи"],
	["salvage.need_listening", "Needs Listening Post", "Нужен пост прослушки"],
	["salvage.need_blueprint", "Need a blueprint.", "Нужен чертёж."],
	["salvage.node.grow_lamps", "grow lamps", "лампы роста"],
	["salvage.node.charcoal", "charcoal", "уголь"],
	["salvage.node.dynamo", "dynamo", "динамо"],
	["salvage.node.drill_heads", "drill heads", "буровые головки"],
	["salvage.node.bunks", "bunks", "нары"],
	["salvage.node.mushroom_beds", "mushroom beds", "грибные грядки"],
	["salvage.node.pressure_seals", "pressure seals", "уплотнения"],
	["salvage.node.substation", "substation", "подстанция"],
	["salvage.node.armor", "armor", "броня"],
	["salvage.node.quarantine_ward", "quarantine ward", "изолятор"],
	["salvage.node.antenna", "antenna", "антенна"],
	["salvage.node.pipe_taps", "pipe taps", "отводы от труб"],
	["staff.salvage.assign_1", "Sent to strip scrap.", "Отправили разбирать лом."],
	["staff.salvage.assign_2", "Workshop table. Blueprints come hard.", "Стол в мастерской. Чертежи даются трудно."],
	["staff.salvage.assign_3", "Hands in the junk pile. Eyes for what still fits.", "Руки в куче утиля. Глаза — на то, что ещё встанет."],
	["staff.salvage.assign_4", "Salvage desk. They sort what the raids bring back.", "Стол утиля. Сортируют то, что приносят с набегов."],
	["staff.salvage.strip_1", "Stripped a useful plate from the scrap.", "Сняли с лома полезную пластину."],
	["staff.salvage.strip_2", "Hours over cold metal. Something worth drawing.", "Часы над холодным металлом. Что-то стоит начертить."],
	["staff.salvage.strip_3", "The scrap gave up a line. Blueprint chalked.", "Лом отдал линию. Чертёж наметили мелом."],
	["staff.salvage.fit_1", "Fitted. The yard feels it hold.", "Поставили. Двор чувствует, как держит."],
	["staff.salvage.fit_2", "Bolted in. No speech. Just the wrench.", "Закрутили. Без речей. Только ключ."],
	["staff.salvage.fit_3", "Another piece found a home on the board.", "Ещё одна деталь нашла место на доске."],
	["staff.salvage.who.Pete", "Pete takes the strip shift. He knows which belts still sing.", "Пит берёт смену на разбор. Знает, какие ремни ещё поют."],
	["staff.salvage.who.Benny", "Benny sorts scrap like names on a board — nothing left blank.", "Бенни сортирует лом, как имена на доске — ничего пустого."],
	["staff.salvage.who.June", "June fits quiet. She does not celebrate a bolt.", "Джун ставит тихо. Болт не празднует."],
]

var catalog: Catalog
var failed := false


func _init() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	_strings()
	_art()
	_costs()
	_tier0()
	_tier1()
	_family()
	_faces()
	_strip()
	_junk()
	_listening()
	_effects()
	_raid()
	_save()
	_bots()
	_staff()
	_careful_band()
	if failed:
		print("SALVAGE CHECK FAILED")
		quit(1)
	else:
		print("SALVAGE CHECK OK")
		quit(0)


func _expect(ok: bool, good: String, bad: String) -> void:
	if ok:
		print(good + ": ok")
	else:
		failed = true
		print("FAIL " + bad)


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _room(game: Game, type: String):
	for room in game.rooms:
		if str(room.type) == type:
			return room
	return null


func _named(game: Game, first: String) -> String:
	for id in game.people:
		var name := str(game.people[id].get("name", ""))
		var bit := name.split(" ")[0] if name != "" else ""
		if bit == first:
			return str(id)
	return ""


func _row(game: Game, id: String) -> Dictionary:
	for row in game.salvage_board():
		if str(row.id) == id:
			return row
	return {}


func _strings() -> void:
	for row in LINES:
		Copy.set_lang("en")
		var en := Copy.t(str(row[0]))
		Copy.set_lang("ru")
		var ru := Copy.t(str(row[0]))
		_expect(en == str(row[1]) and ru == str(row[2]), str(row[0]), "%s en=%s ru=%s" % [row[0], en, ru])
	Copy.set_lang("ru")
	_expect(Copy.t("grow lamps") == "фитолампы", "Room card keeps фитолампы", "grow lamps -> %s" % Copy.t("grow lamps"))
	_expect(Copy.fill("salvage.fitted", {"name": Copy.t("salvage.node.grow_lamps")}) == "Поставили: лампы роста",
		"Fitted line fills the node name", Copy.fill("salvage.fitted", {"name": Copy.t("salvage.node.grow_lamps")}))
	Copy.set_lang("en")
	_expect(Copy.fill("salvage.fitted", {"name": "grow lamps"}) == "Fitted grow lamps", "English fitted line", Copy.fill("salvage.fitted", {"name": "grow lamps"}))


func _art() -> void:
	var tex: Dictionary = ArtPack.textures()
	var paths := [
		"res://assets/ui/salvage_board_panel.webp",
		"res://assets/ui/salvage_board_empty.webp",
		"res://assets/ui/salvage_board_no_blueprint.webp",
		"res://assets/overlays/fitted_flash.webp",
		"res://assets/icons/ui/salvage_open.png",
		"res://assets/icons/ui/salvage_open_24.png",
		"res://assets/icons/ui/blueprint_ready.png",
		"res://assets/icons/ui/blueprint_ready_24.png",
		"res://assets/icons/status/salvage_open.png",
		"res://assets/icons/status/salvage_open_24.png",
		"res://assets/icons/status/blueprint_ready.png",
		"res://assets/icons/status/blueprint_ready_24.png",
		"res://assets/icons/ui/blueprint.png",
		"res://assets/icons/ui/strip_scrap_24.png",
		"res://assets/icons/ui/fitted.png",
		"res://assets/icons/ui/locked_blueprint.png",
		"res://assets/icons/ui/tier0.png",
		"res://assets/icons/ui/tier1.png",
		"res://assets/icons/ui/tier2.png",
	]
	for path in paths:
		_expect(tex.get(path) is Texture2D, path.get_file(), "missing " + path)
	for pair in [["salvage_open", 64], ["salvage_open", 24], ["blueprint_ready", 64], ["blueprint_ready", 24], ["blueprint", 64], ["strip_scrap", 24], ["fitted", 64], ["locked_blueprint", 64], ["tier0", 64], ["tier1", 64], ["tier2", 64]]:
		var icon := ArtPack.icon_texture(str(pair[0]), float(pair[1]))
		_expect(icon != null, "icon %s @%s" % [pair[0], pair[1]], "icon %s @%s missing" % [pair[0], pair[1]])


func _costs() -> void:
	var game := _game()
	var want := {
		"hydroponics/1": 8, "hydroponics/2": 12,
		"air_filter/2": 12, "generator/2": 15,
		"workshop/1": 6, "workshop/2": 9,
		"quarters/2": 9, "infirmary/1": 8, "radio/1": 8,
	}
	for key in want:
		var bits: PackedStringArray = str(key).split("/")
		var got := game.upgrade_cost(bits[0], int(bits[1]))
		_expect(got == int(want[key]), "upgrade %s costs %d" % [key, int(want[key])], "%s costs %d" % [key, got])


func _tier0() -> void:
	var game := _game()
	var hydro = _room(game, "hydroponics")
	var mats := int(game.stock.materials)
	var hope0 := game.hope
	_expect(game.salvage_face() == "empty" and int(game.stock.blueprints) == 0, "A new board is empty, with no blueprints", "face %s bp %s" % [game.salvage_face(), game.stock.blueprints])
	var ok := game.apply({"kind": "upgrade", "room": str(hydro.uid)})
	var floated: Dictionary = game.take_salvage_float()
	_expect(ok and int(hydro.upgrade) == 1 and int(game.stock.blueprints) == 0 and int(game.stock.materials) == mats - 8 and game.hope == hope0,
		"Tier 0 grow lamps spends materials only", "ok=%s up=%s bp=%s mats=%s" % [ok, hydro.upgrade, game.stock.blueprints, game.stock.materials])
	_expect(str(floated.get("id", "")) == "grow_lamps" and str(floated.get("uid", "")) == str(hydro.uid),
		"First fit floats grow lamps once", str(floated))
	var filt = _room(game, "air_filter")
	game.apply({"kind": "upgrade", "room": str(filt.uid)})
	_expect(game.take_salvage_float().is_empty(), "A later fit does not float again", "float still set")
	_expect(bool(_row(game, "grow_lamps").fitted), "Board marks grow lamps fitted", "not fitted")


func _tier1() -> void:
	var game := _game()
	var hydro = _room(game, "hydroponics")
	game.stock.materials = 40
	game.apply({"kind": "upgrade", "room": str(hydro.uid)})
	game.take_salvage_float()
	var hope0 := game.hope
	var preview: Dictionary = game.upgrade_preview(str(hydro.uid))
	_expect(not bool(preview.ok) and str(preview.reason) == Copy.t("salvage.need_blueprint") and int(preview.tier) == 1,
		"Tier 1 refuses without a blueprint", "ok=%s reason=%s tier=%s" % [preview.ok, preview.reason, preview.get("tier", "?")])
	_expect(not game.apply({"kind": "upgrade", "room": str(hydro.uid)}) and int(hydro.upgrade) == 1 and game.hope == hope0,
		"The refused fit does not spend or move hope", "up=%s hope %d -> %d" % [hydro.upgrade, hope0, game.hope])
	game.stock.blueprints = 1
	var ok := game.apply({"kind": "upgrade", "room": str(hydro.uid)})
	_expect(ok and int(hydro.upgrade) == 2 and int(game.stock.blueprints) == 0 and game.hope == hope0 and game.mushroom_food(hydro) == 1,
		"Mushroom beds spends one blueprint and hope stays", "ok=%s up=%s bp=%s hope %d -> %d food=%s" % [ok, hydro.upgrade, game.stock.blueprints, hope0, game.hope, game.mushroom_food(hydro)])


func _family() -> void:
	var game := _game()
	var bunks = _room(game, "quarters")
	game.stock.materials = 40
	game.stock.blueprints = 1
	_expect(game.apply({"kind": "upgrade", "room": str(bunks.uid)}) and int(game.stock.blueprints) == 1,
		"Bunks is tier 0 and keeps the blueprint", "bp %s" % game.stock.blueprints)
	var before := int(game.stock.materials)
	var cost := game.upgrade_cost("quarters", 2)
	_expect(game.apply({"kind": "upgrade", "room": str(bunks.uid)}) and int(bunks.upgrade) == 2 and int(game.stock.blueprints) == 1 and int(game.stock.materials) == before - cost,
		"Family quarters stays materials-only", "up=%s bp=%s mats %d -> %d" % [bunks.upgrade, game.stock.blueprints, before, game.stock.materials])


func _faces() -> void:
	var game := _game()
	var desk = Desk.new()
	desk.game = game
	_expect(game.salvage_face() == "empty" and desk._salvage_panel(game.salvage_board()) == "res://assets/ui/salvage_board_empty.webp",
		"Nothing fitted shows the empty clipboard", game.salvage_face())
	var hydro = _room(game, "hydroponics")
	game.stock.materials = 40
	game.apply({"kind": "upgrade", "room": str(hydro.uid)})
	_expect(game.salvage_face() == "no_blueprint" and desk._salvage_panel(game.salvage_board()) == "res://assets/ui/salvage_board_no_blueprint.webp",
		"A fitted board with a blueprint lock shows the locked clipboard", game.salvage_face())
	game.stock.blueprints = 1
	_expect(game.salvage_face() == "board" and desk._salvage_panel(game.salvage_board()) == "res://assets/ui/salvage_board_panel.webp",
		"A blueprint brings back the working clipboard", game.salvage_face())
	desk.free()


func _strip() -> void:
	var game := _game()
	var shop = _room(game, "workshop")
	var mats := int(game.stock.materials)
	var held: Array = shop.staff.duplicate()
	shop.staff.clear()
	_expect(not bool(game.strip_preview().ok) and not game.apply({"kind": "strip"}), "Strip needs a staffed workshop", game.strip_preview().reason)
	shop.staff = held
	game.stock.materials = mats
	var ok := game.apply({"kind": "strip"})
	_expect(ok and int(game.stock.blueprints) == 1 and int(game.stock.materials) == mats - 4 and int(game.salvage.strip_week) == game.week,
		"Strip scrap spends 4 materials and grants one blueprint", "ok=%s bp=%s mats=%s week=%s" % [ok, game.stock.blueprints, game.stock.materials, game.salvage.strip_week])
	_expect(not game.apply({"kind": "strip"}) and int(game.stock.blueprints) == 1, "Strip waits three weeks", "bp %s" % game.stock.blueprints)
	game.week = int(game.salvage.strip_week) + 3
	_expect(bool(game.strip_preview().ok), "Strip is open again after three weeks", game.strip_preview().reason)


func _junk() -> void:
	var game := _game()
	_expect(not game.junk_flowing(), "Junk is not flowing on this master", "junk_flowing")
	game.flags.junk_flow = true
	game.week = 5
	game._grant_junk_blueprints()
	_expect(int(game.stock.blueprints) == 0, "Junk waits for every sixth week", "bp %s" % game.stock.blueprints)
	game.week = 6
	game._grant_junk_blueprints()
	game._grant_junk_blueprints()
	_expect(int(game.stock.blueprints) == 1 and int(game.salvage.junk_week) == 6, "Junk grants once that week", "bp %s week %s" % [game.stock.blueprints, game.salvage.get("junk_week", 0)])
	game.week = 12
	game._grant_junk_blueprints()
	_expect(int(game.stock.blueprints) == 2, "The next sixth week grants another", "bp %s" % game.stock.blueprints)


func _listening() -> void:
	var game := _game()
	_expect(not game.catalog.rooms.has("listening_post"), "Listening Post is not a room on this master", "catalog has it")
	var gate := game.salvage_gate(game.salvage_def("pipe_taps"))
	var row := _row(game, "pipe_taps")
	_expect(gate == Copy.t("salvage.need_listening") and str(row.gate) == "listening",
		"Pipe taps stay locked until a Listening Post exists", "gate=%s row=%s" % [gate, row.gate])
	_expect(is_equal_approx(game.blown_scale(), 1.0), "Blown chance is unchanged without pipe taps", str(game.blown_scale()))
	game.rooms.append({"uid": "lp-test", "type": "listening_post", "upgrade": 1, "offline": false, "staff": []})
	var scaled := game.blown_scale()
	game.rooms.pop_back()
	_expect(is_equal_approx(scaled, 0.95), "Pipe taps cut blown chance by 5% once that upgrade is online", str(scaled))
	game.catalog.rooms["listening_post"] = {"id": "listening_post"}
	game.rooms.append({"uid": "lp-test", "type": "listening_post", "upgrade": 0, "offline": false, "staff": []})
	var hidden := game.intent_hide_chance()
	game.rooms.pop_back()
	game.catalog.rooms.erase("listening_post")
	_expect(is_equal_approx(hidden, 0.0), "An online Listening Post hides nothing", str(hidden))


func _effects() -> void:
	var game := _game()
	var base := game.cough_spread_chance()
	var filt = _room(game, "air_filter")
	filt.upgrade = 2
	var sealed := game.cough_spread_chance()
	filt.upgrade = 0
	_expect(is_equal_approx(base, 0.3) and is_equal_approx(sealed, 0.24), "Pressure seals cut cough spread by 20%", "base %s sealed %s" % [base, sealed])
	var gen = _room(game, "generator")
	_expect(game.brownout_spare() == 0, "No spare room before the substation", str(game.brownout_spare()))
	gen.upgrade = 2
	_expect(game.brownout_spare() == 1, "Substation keeps one room lit", str(game.brownout_spare()))
	gen.upgrade = 0
	_expect(is_equal_approx(game.intent_hide_chance(), 0.25), "No radio hides a quarter of intents", str(game.intent_hide_chance()))
	game.rooms.append({"uid": "radio-test", "type": "radio", "upgrade": 1, "offline": false, "staff": []})
	var halved := game.intent_hide_chance()
	game.rooms[game.rooms.size() - 1].staff = ["x"]
	var staffed := game.intent_hide_chance()
	game.rooms.pop_back()
	_expect(is_equal_approx(halved, 0.125) and is_equal_approx(staffed, 0.0),
		"Antenna halves a hide; a staffed radio hides nothing", "antenna %s radio %s" % [halved, staffed])


func _raid() -> void:
	var unit := _game()
	unit._grant_first_raid_blueprint()
	unit._grant_first_raid_blueprint()
	_expect(int(unit.stock.blueprints) == 1 and bool(unit.salvage.raid_bp), "The raid blueprint is granted once", "bp %s" % unit.stock.blueprints)
	var game := _game()
	var dest := ""
	var fallback := ""
	for sid in game._neighbors(game.capital_id):
		if fallback == "":
			fallback = str(sid)
		var st: Dictionary = game.stations[str(sid)]
		var owner := str(st.get("owner", ""))
		if owner == "" or owner == game.player or owner == "neutral" or owner == "ruin" or owner == "bunker" or str(st.get("bunker", "")) != "":
			continue
		dest = str(sid)
		break
	if dest == "":
		dest = fallback
		if dest != "" and game.stations.has(dest):
			game.stations[dest].owner = "directorate"
			game.stations[dest].bunker = ""
	if dest == "":
		print("raid gate: capital has no neighbour")
		return
	game.stations[dest].known = true
	game.stations[dest].garrison = 1
	game.stations[dest].fort = 0.2
	game.squads[game.player].gear = 40.0
	game.stock.food = 40
	var gate := game._raid_gate(dest)
	if gate != "":
		print("raid gate: " + gate)
		_expect(false, "First raid win grants a blueprint", "blocked: " + gate)
		return
	var ok := game._order_raid(dest, true)
	_expect(ok and int(game.stock.blueprints) == 1, "First raid win grants a blueprint", "ok=%s bp=%s win=%s" % [ok, game.stock.blueprints, game.last_combat_report.get("win", "?")])
	var held := int(game.stock.blueprints)
	game._grant_first_raid_blueprint()
	_expect(int(game.stock.blueprints) == held, "A later raid does not grant a second blueprint", "bp %s" % game.stock.blueprints)


func _save() -> void:
	_expect(Game.SAVE_SCHEMA == 13, "Save schema is 13", str(Game.SAVE_SCHEMA))
	var game := _game()
	game.stock.blueprints = 4
	game.salvage.strip_week = 9
	game.salvage.junk_week = 6
	var fixture := game.export_state()
	fixture.schema = 13
	var other := _game()
	var loaded := other.import_state(fixture)
	_expect(loaded and int(other.stock.blueprints) == 4 and int(other.salvage.strip_week) == 9 and int(other.salvage.junk_week) == 6,
		"Schema 13 keeps blueprints and the strip week", "loaded=%s err=%s bp=%s strip=%s" % [loaded, other.load_error, other.stock.get("blueprints", "?"), other.salvage.get("strip_week", "?")])
	fixture.schema = 11
	fixture.erase("salvage")
	fixture.stock.erase("blueprints")
	var legacy := _game()
	legacy.stock.blueprints = 7
	legacy.salvage.strip_week = 3
	loaded = legacy.import_state(fixture)
	_expect(loaded and int(legacy.stock.blueprints) == 0 and int(legacy.salvage.get("strip_week", -1)) == 0,
		"A schema 11 save with no salvage starts at zero", "loaded=%s err=%s bp=%s strip=%s" % [loaded, legacy.load_error, legacy.stock.get("blueprints", "?"), legacy.salvage.get("strip_week", "?")])


func _bots() -> void:
	var game := _game()
	game.stock.food = 3
	game.flood_guard = true
	for key in game.cells:
		game.cells[key].flooded = false
	var careful := Bot.new()
	careful.profile = "careful"
	var act: Dictionary = careful._project(game)
	var info: Dictionary = game.upgrade_preview(str(act.get("room", ""))) if str(act.get("kind", "")) == "upgrade" else {}
	_expect(str(act.get("kind", "")) == "upgrade" and bool(info.get("ok", false)) and int(info.get("tier", -1)) == 0,
		"Careful fits a tier 0 node when the pantry is thin", "act=%s tier=%s" % [act, info.get("tier", "?")])
	var wide := _game()
	wide.build = {"type": "", "level": 0, "cell": 0, "left": 1, "workers": []}
	wide.stock.materials = 20
	wide.quarantine = true
	wide.flood_guard = true
	var expander := Bot.new()
	expander.profile = "expander"
	var strip: Dictionary = expander._project_expander(wide)
	_expect(str(strip.get("kind", "")) == "strip", "Expander strips when materials are at least 12 and nothing is being built", str(strip))


func _staff() -> void:
	var game := _game()
	var desk = Desk.new()
	desk.game = game
	var shop = _room(game, "workshop")
	var pete := _named(game, "Pete")
	shop.staff = [pete] if pete != "" else []
	var line := desk._salvage_staff_line("strip")
	_expect(line == Copy.t("staff.salvage.who.Pete"), "Pete on the workshop speaks for the strip", line)
	var june := _named(game, "June")
	var bunks = _room(game, "quarters")
	if june != "" and not bunks.staff.has(june):
		bunks.staff.append(june)
	_expect(desk._salvage_staff_line("fit") == Copy.t("staff.salvage.who.June"), "June speaks for the fit", desk._salvage_staff_line("fit"))
	shop.staff.clear()
	var plain := desk._salvage_staff_line("strip")
	var known := false
	for key in ["staff.salvage.assign_1", "staff.salvage.assign_2", "staff.salvage.assign_3", "staff.salvage.assign_4", "staff.salvage.strip_1", "staff.salvage.strip_2", "staff.salvage.strip_3"]:
		known = known or plain == Copy.t(key)
	_expect(known, "An unnamed strip still uses a salvage line", plain)
	desk.free()


func _careful_band() -> void:
	var lost := 0
	for run_seed in range(1, 61):
		var row: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(row.get("over", "")) != "time":
			lost += 1
			print("  careful seed %d over %s week %s" % [run_seed, row.get("over", ""), row.get("week", "")])
	var pct := 100.0 * float(lost) / 60.0
	print("careful loss %d of 60 (%.1f%%)" % [lost, pct])
	# 15% of 60 is 9, 35% is 21.
	_expect(lost >= 9 and lost <= 21, "Careful loss stays 15–35%", "%d of 60 (%.1f%%)" % [lost, pct])
