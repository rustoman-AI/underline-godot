extends SceneTree

const Dust = preload("res://sim/leaflet_dust.gd")
const Marks = preload("res://sim/deal_marks.gd")

## P47 leaflet dust. Propaganda that lands at sympathy >= 70 leaves a two-week scrap.
## Envoy, deal, and bare sympathy never spawn it. No soft dawn chip. No balance drift.
##   godot --headless --path . -s res://sim/check_leaflet_dust.gd

var failed := false
var balance_text := ""


func _init() -> void:
	Copy.set_lang("en")
	balance_text = FileAccess.get_file_as_string("res://data/balance.json")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	if not _check_spawn(catalog):
		failed = true
	if not _check_envoy_deal(catalog):
		failed = true
	if not _check_clear(catalog):
		failed = true
	if not _check_float(catalog):
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_draw():
		failed = true
	if not _check_balance():
		failed = true
	if not _check_icon():
		failed = true
	if failed:
		print("LEAFLET DUST FAIL")
		quit(1)
		return
	print("LEAFLET DUST OK")
	quit(0)


func _expect(ok: bool, good: String, bad: String) -> bool:
	if ok:
		print(good + ": ok")
		return true
	failed = true
	print("FAIL " + bad)
	return false


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _neighbor(game: Game) -> String:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != "neutral":
			continue
		if str(st.get("bunker", "")) != "" or bool(st.get("hidden", false)):
			continue
		if game.borders_player(str(sid)):
			return str(sid)
	return ""


func _silence(game: Game) -> void:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		Dust.clear_station(st)
		if str(sid) == str(game.capital_id):
			continue
		st.known = false
		st.intel = 0
		st.hidden = false
		st.erase("visited")
		st.erase("joined")
		st.erase("captured")


func _arm_ready(game: Game, sid: String, sympathy: int) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = "neutral"
	st.known = true
	st.sympathy = sympathy
	st.intel = 1
	st.hidden = false
	st.deals = 0
	st.passage = false
	st.erase("joined")
	st.erase("captured")
	game.stock.influence = 40


func _has_dust(st: Dictionary) -> bool:
	return int(st.get("leaflet_until_week", 0)) > 0 or int(st.get("leaflet_until", 0)) > 0


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("leaf.tip") != "Leaflets still up.":
		print("Strings: FAIL en tip ", Copy.t("leaf.tip"))
		return false
	if Copy.t("leaf.label") != "Leaflets":
		print("Strings: FAIL en label ", Copy.t("leaf.label"))
		return false
	if Copy.t("leaf.first") != "Paper still on the platform.":
		print("Strings: FAIL en first ", Copy.t("leaf.first"))
		return false
	if Copy.t("leaf.gone") != "The paper blew off.":
		print("Strings: FAIL en gone ", Copy.t("leaf.gone"))
		return false
	if Copy.t("leaf.reduce") != "Leaflets.":
		print("Strings: FAIL en reduce ", Copy.t("leaf.reduce"))
		return false
	Copy.set_lang("ru")
	if Copy.t("leaf.tip") != "Листовки ещё висят.":
		print("Strings: FAIL ru tip ", Copy.t("leaf.tip"))
		return false
	if Copy.t("leaf.label") != "Листовки":
		print("Strings: FAIL ru label ", Copy.t("leaf.label"))
		return false
	if Copy.t("leaf.first") != "На платформе ещё бумага.":
		print("Strings: FAIL ru first ", Copy.t("leaf.first"))
		return false
	if Copy.t("leaf.gone") != "Бумагу сдуло.":
		print("Strings: FAIL ru gone ", Copy.t("leaf.gone"))
		return false
	if Copy.t("leaf.reduce") != "Листовки.":
		print("Strings: FAIL ru reduce ", Copy.t("leaf.reduce"))
		return false
	var ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/ru.json"))
	if typeof(ru) != TYPE_DICTIONARY:
		print("Strings: FAIL ru.json")
		return false
	var want := {
		"Leaflets still up.": "Листовки ещё висят.",
		"Leaflets": "Листовки",
		"Paper still on the platform.": "На платформе ещё бумага.",
		"The paper blew off.": "Бумагу сдуло.",
		"Leaflets.": "Листовки.",
	}
	for key in want:
		if str(ru.get(key, "")) != str(want[key]):
			print("Strings: FAIL ru.json ", key)
			return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_spawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Spawn: FAIL no neighbor")
		return false
	_silence(game)
	_arm_ready(game, sid, 95)
	if Dust.shows(game, sid) or Dust.note(game) != "":
		print("Spawn: FAIL natural sympathy")
		return false
	_arm_ready(game, sid, 10)
	var low_cost := game.propaganda_cost(sid)
	var low_inf := int(game.stock.influence)
	if not game._order_propaganda(sid):
		print("Spawn: FAIL low order ", game._propaganda_block(sid))
		return false
	var low: Dictionary = game.stations[sid]
	if int(low.sympathy) >= 70 or _has_dust(low) or Dust.shows(game, sid):
		print("Spawn: FAIL under 70 ", low.sympathy, " ", low.get("leaflet_until_week", 0))
		return false
	if int(game.stock.influence) != low_inf - low_cost:
		print("Spawn: FAIL low cost")
		return false
	_arm_ready(game, sid, 69)
	Dust.clear_station(game.stations[sid])
	var cost := game.propaganda_cost(sid)
	var held := int(game.stock.influence)
	var week := int(game.week)
	if not game._order_propaganda(sid):
		print("Spawn: FAIL ready order")
		return false
	var st: Dictionary = game.stations[sid]
	var after := int(st.sympathy)
	if after < 70:
		print("Spawn: FAIL did not reach ready ", after)
		return false
	if int(st.get("leaflet_until_week", 0)) != week + 2 or int(st.get("leaflet_until", 0)) != week + 2:
		print("Spawn: FAIL ttl ", st.get("leaflet_until_week", 0), " ", st.get("leaflet_until", 0))
		return false
	if not Dust.shows(game, sid):
		print("Spawn: FAIL chip hidden")
		return false
	if int(game.stock.influence) != held - cost:
		print("Spawn: FAIL cost")
		return false
	var full: PackedStringArray = Dust.lines(game, sid, false)
	var compact: PackedStringArray = Dust.lines(game, sid, true)
	if full.size() != 2 or full[0] != "Leaflets" or full[1] != "Leaflets still up.":
		print("Spawn: FAIL tip ", full)
		return false
	if compact.size() != 1 or compact[0] != "Leaflets.":
		print("Spawn: FAIL compact ", compact)
		return false
	var blob := " ".join(full) + " " + " ".join(compact)
	if blob.find("+") >= 0 or blob.find(str(after)) >= 0:
		print("Spawn: FAIL delta ", blob)
		return false
	st.known = false
	if Dust.shows(game, sid) or _has_dust(st) == false:
		print("Spawn: FAIL unknown should hide and keep ttl")
		return false
	st.known = true
	if not Dust.shows(game, sid):
		print("Spawn: FAIL known again")
		return false
	print("Spawn: ok")
	return true


func _check_envoy_deal(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Others: FAIL no neighbor")
		return false
	_silence(game)
	_arm_ready(game, sid, 80)
	if not game._order_envoy(sid):
		print("Others: FAIL envoy ", game._envoy_block(sid))
		return false
	var st: Dictionary = game.stations[sid]
	if int(st.sympathy) < 70 or _has_dust(st) or Dust.shows(game, sid):
		print("Others: FAIL envoy spawned ", st.sympathy, " ", st.get("leaflet_until_week", 0))
		return false
	_arm_ready(game, sid, 85)
	Dust.clear_station(st)
	var sympathy := int(st.sympathy)
	if not game._order_deal(sid):
		print("Others: FAIL deal ", game._deal_block(sid))
		return false
	if int(st.sympathy) != sympathy or int(st.deals) != 1 or _has_dust(st) or Dust.shows(game, sid):
		print("Others: FAIL deal spawned ", st.sympathy, " ", st.deals)
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var envoy := _body(src, "func _order_envoy(")
	var deal := _body(src, "func _order_deal(")
	var prop := _body(src, "func _order_propaganda(")
	if envoy.find("leaflet_until") >= 0 or deal.find("leaflet_until") >= 0:
		print("Others: FAIL envoy or deal writes ttl")
		return false
	if prop.find("LeafletDust.arm") < 0:
		print("Others: FAIL propaganda does not arm")
		return false
	var dust_src := FileAccess.get_file_as_string("res://sim/leaflet_dust.gd")
	var arm := _body(dust_src, "static func arm(")
	if arm.find("leaflet_until_week") < 0 or arm.find("leaflet_until") < 0:
		print("Others: FAIL arm does not store ttl")
		return false
	if envoy.find("LeafletDust.arm") >= 0 or deal.find("LeafletDust.arm") >= 0:
		print("Others: FAIL arm outside propaganda")
		return false
	var dawn := _body(src, "func _pick_dawn_soft_chip(")
	if dawn.find("leaflet") >= 0 or dawn.find("leaf.") >= 0:
		print("Others: FAIL dawn stack")
		return false
	print("Others: ok")
	return true


func _check_clear(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Clear: FAIL no neighbor")
		return false
	_silence(game)
	_arm_ready(game, sid, 69)
	if not game._order_propaganda(sid):
		print("Clear: FAIL order")
		return false
	var st: Dictionary = game.stations[sid]
	var until := int(st.get("leaflet_until_week", 0))
	if until != int(game.week) + 2 or not Dust.shows(game, sid):
		print("Clear: FAIL missing chip")
		return false
	st.sympathy = 50
	if not Dust.shows(game, sid) or int(st.get("leaflet_until_week", 0)) != until:
		print("Clear: FAIL cooled at 50")
		return false
	st.sympathy = 49
	if Dust.shows(game, sid) or _has_dust(st):
		print("Clear: FAIL sympathy 49 kept dust")
		return false
	st.sympathy = 80
	if Dust.shows(game, sid) or _has_dust(st):
		print("Clear: FAIL sympathy rebound")
		return false
	_arm_ready(game, sid, 69)
	if not game._order_propaganda(sid):
		print("Clear: FAIL rearm")
		return false
	until = int(st.get("leaflet_until_week", 0))
	game.week = until
	if Dust.shows(game, sid) or _has_dust(st):
		print("Clear: FAIL ttl ", game.week, " ", until)
		return false
	game.week = 5
	_arm_ready(game, sid, 99)
	game.stock.influence = 40
	if not game._order_propaganda(sid):
		print("Clear: FAIL join order ", game._propaganda_block(sid))
		return false
	if str(st.owner) != str(game.player) or Dust.shows(game, sid) or _has_dust(st):
		print("Clear: FAIL join kept dust ", st.owner, " ", st.get("leaflet_until_week", 0), " ", st.sympathy)
		return false
	game.week = 6
	_silence(game)
	_arm_ready(game, sid, 72)
	st.leaflet_until_week = 9
	st.leaflet_until = 9
	st.joined = true
	if Dust.shows(game, sid) or _has_dust(st):
		print("Clear: FAIL joined flag")
		return false
	_arm_ready(game, sid, 72)
	st.leaflet_until_week = 9
	st.leaflet_until = 9
	st.captured = true
	if Dust.shows(game, sid) or _has_dust(st):
		print("Clear: FAIL captured flag")
		return false
	print("Clear: ok")
	return true


func _check_float(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	_silence(game)
	_arm_ready(game, sid, 40)
	if Dust.note(game) != "" or bool(game.flags.get("seen_leaflet_dust", false)):
		print("Float: FAIL empty fired")
		return false
	_arm_ready(game, sid, 69)
	if not game._order_propaganda(sid):
		print("Float: FAIL order")
		return false
	var line := Dust.note(game)
	if line != "Paper still on the platform." or not bool(game.flags.get("seen_leaflet_dust", false)):
		print("Float: FAIL first ", line)
		return false
	if line.find("+") >= 0:
		print("Float: FAIL delta")
		return false
	if Dust.note(game) != "":
		print("Float: FAIL second")
		return false
	print("Float: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	_silence(game)
	_arm_ready(game, sid, 69)
	if not game._order_propaganda(sid):
		print("Save: FAIL order")
		return false
	var until := int(game.stations[sid].get("leaflet_until_week", 0))
	if Dust.note(game) != "Paper still on the platform.":
		print("Save: FAIL float")
		return false
	var data := game.export_state()
	var loaded := Game.new()
	loaded.setup(catalog, 4, 40)
	if not loaded.import_state(data):
		print("Save: FAIL import ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_leaflet_dust", false)):
		print("Save: FAIL flag dropped")
		return false
	if Dust.note(loaded) != "":
		print("Save: FAIL float after load")
		return false
	var st: Dictionary = loaded.stations[sid]
	if int(st.get("leaflet_until_week", 0)) != until or int(st.get("leaflet_until", 0)) != until:
		print("Save: FAIL ttl dropped ", st.get("leaflet_until_week", 0))
		return false
	if not Dust.shows(loaded, sid):
		print("Save: FAIL chip after load")
		return false
	loaded.flags.erase("seen_leaflet_dust")
	if Dust.note(loaded) != "Paper still on the platform.":
		print("Save: FAIL flag was not the latch")
		return false
	print("Save: ok")
	return true


func _dawn_snapshot(game: Game) -> Dictionary:
	return {
		"flags": game.flags.duplicate(true),
		"notices": game.notices.duplicate(true),
		"reports": game.order_reports.duplicate(true),
		"chip": game.dawn_soft_chip().duplicate(true),
		"home": game.home_chip_line(false),
		"sympathy": int(game.stations[_neighbor(game)].sympathy),
	}


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	_silence(game)
	_arm_ready(game, sid, 69)
	if not game._order_propaganda(sid):
		print("Dawn: FAIL order")
		return false
	var until := int(game.stations[sid].get("leaflet_until_week", 0))
	var before := _dawn_snapshot(game)
	var line := Dust.note(game)
	if line != "Paper still on the platform.":
		print("Dawn: FAIL float")
		return false
	var after := _dawn_snapshot(game)
	var flags_before: Dictionary = before.flags
	var flags_after: Dictionary = after.flags.duplicate(true)
	flags_after.erase("seen_leaflet_dust")
	if flags_before != flags_after:
		print("Dawn: FAIL flags changed")
		return false
	if before.notices != after.notices or before.reports != after.reports:
		print("Dawn: FAIL queued a report")
		return false
	if str(after.chip.get("kind", "")) != str(before.chip.get("kind", "")):
		print("Dawn: FAIL chip kind ", before.chip, " ", after.chip)
		return false
	var kind := str(after.chip.get("kind", ""))
	if kind == "leaf" or kind == "leaflet" or kind.find("leaf") >= 0 or str(after.home) != str(before.home):
		print("Dawn: FAIL leaf chip ", after.chip, " ", after.home)
		return false
	if int(after.sympathy) != int(before.sympathy):
		print("Dawn: FAIL sympathy")
		return false
	if int(game.stations[sid].get("leaflet_until_week", 0)) != until:
		print("Dawn: FAIL ttl moved")
		return false
	if bool(game.flags.get("rumor_dawn", false)) or bool(game.flags.get("border_dawn_new", false)):
		print("Dawn: FAIL higher chip armed")
		return false
	if bool(game.flags.get("rail_dawn", false)) or bool(game.flags.get("home_pending", false)) or bool(game.flags.get("heard_home", false)):
		print("Dawn: FAIL stack flag")
		return false
	print("Dawn: ok")
	return true


func _body(src: String, name: String) -> String:
	var at := src.find(name)
	if at < 0:
		return ""
	var body := src.substr(at)
	var next := body.find("\nfunc ")
	if next >= 0:
		body = body.substr(0, next)
	return body


func _check_draw() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _body(src, "func _draw_pin(")
	var body := pin.find("draw_texture_rect_region")
	var warm := pin.find("_draw_warmth_ring")
	var border := pin.find("_draw_border_tick")
	var leaf := pin.find("_draw_leaflet_chip")
	var selected := pin.find("if sid == selected")
	if body < 0 or warm < body or border < warm or leaf < border:
		print("Draw: FAIL order ", body, " ", warm, " ", border, " ", leaf)
		return false
	if selected >= 0 and selected < border:
		print("Draw: FAIL selection covers the tick slot")
		return false
	var ink := _body(src, "func _draw_ink(")
	var pins_at := ink.find("_draw_pins")
	var pips_at := ink.find("_draw_deal_pips")
	var flags_at := ink.find("_draw_flags")
	if pins_at < 0 or pips_at < pins_at or flags_at < pips_at:
		print("Draw: FAIL pips not above the pin pass")
		return false
	var chip := _body(src, "func _draw_leaflet_chip(")
	if chip.find("LeafletDust.slot") < 0 or chip.find("LeafletDust.chip_px") < 0:
		print("Draw: FAIL slot or size")
		return false
	if chip.find("leaflet_chip") < 0 or chip.find("propaganda") < 0:
		print("Draw: FAIL icon fallback")
		return false
	if chip.find("sin(") >= 0 or chip.find("_anim_t") >= 0 or chip.find("create_tween") >= 0 or chip.find("flutter") >= 0:
		print("Draw: FAIL flutter")
		return false
	if Dust.flutters():
		print("Draw: FAIL flutters flag")
		return false
	var at := Vector2(40, 80)
	var pin_r := 16.0
	var near := Dust.slot(at, pin_r, false)
	var far := Dust.slot(at, pin_r, true)
	if near.y <= at.y or far.y >= at.y:
		print("Draw: FAIL sides ", near, " ", far)
		return false
	var crowded_clear := true
	for i in 3:
		var pip := Marks.pip_slot(at, pin_r, i)
		if far.distance_to(pip) < 14.0:
			crowded_clear = false
	if not crowded_clear:
		print("Draw: FAIL crowded overlaps pips ", far)
		return false
	var px := Dust.chip_px(pin_r)
	if px < 8.0 or px > 12.0:
		print("Draw: FAIL quarter pin ", px)
		return false
	if src.find("leaf_lines(game, sid, _motion_off())") < 0 or src.find("note_leaflet_dust") < 0:
		print("Draw: FAIL tip or float wiring")
		return false
	var float_fn := _body(src, "func _show_leaf_float(")
	if float_fn.find("_motion_off()") < 0 or float_fn.find("tween_interval") < 0:
		print("Draw: FAIL reduce-motion float")
		return false
	var note_fn := _body(src, "func _note_first_leaflet(")
	if note_fn.find("present_dawn_soft_chip") >= 0 or note_fn.find("guide_layer") >= 0:
		print("Draw: FAIL dawn from float")
		return false
	if note_fn.find("leaf.gone") >= 0:
		print("Draw: FAIL clear toast")
		return false
	print("Draw: ok")
	return true


func _check_balance() -> bool:
	var now := FileAccess.get_file_as_string("res://data/balance.json")
	if now != balance_text:
		print("Balance: FAIL file changed")
		return false
	if now.contains("seen_leaflet_dust") or now.contains("leaflet") or now.contains("leaf.tip"):
		print("Balance: FAIL mentions leaflets")
		return false
	var parsed = JSON.parse_string(now)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("Balance: FAIL parse")
		return false
	if int(parsed.get("hope_drift", 0)) != -1 or float(parsed.get("sympathy_base", 0)) != 12.0:
		print("Balance: FAIL drift")
		return false
	if int(parsed.get("propaganda_influence", 0)) != 6 or int(parsed.get("join_hope", 1)) != 0 or int(parsed.get("join_discontent", 0)) != -3:
		print("Balance: FAIL join band")
		return false
	print("Balance: ok")
	return true


func _check_icon() -> bool:
	var paths := [
		"res://assets/icons/status/leaflet_chip_24.png",
		"res://assets/icons/map/leaflet_chip_24.png",
	]
	for path in paths:
		if not FileAccess.file_exists(path):
			print("Icon: FAIL missing ", path)
			return false
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			print("Icon: FAIL open ", path)
			return false
		var size := file.get_length()
		file.close()
		if size < 200:
			print("Icon: FAIL stub ", path, " ", size)
			return false
		var image := Image.new()
		if image.load(path) != OK or image.get_width() != 24 or image.get_height() != 24:
			print("Icon: FAIL image ", path, " ", image.get_width())
			return false
	var status := FileAccess.open("res://assets/icons/status/leaflet_chip_24.png", FileAccess.READ)
	var got := status.get_length()
	status.close()
	if got != 339:
		print("Icon: FAIL hand-pixel size ", got)
		return false
	print("Icon: leaflet_chip_24 339")
	return true
