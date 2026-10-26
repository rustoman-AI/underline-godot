extends SceneTree

const Warmth = preload("res://sim/pin_warmth.gd")

## P46 pin warmth. Known stations take a ring tint from existing sympathy.
## The first tint of a run floats once. No soft dawn chip. No balance drift.
##   godot --headless --path . -s res://sim/check_pin_warmth.gd

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
	if not _check_bands(catalog):
		failed = true
	if not _check_float(catalog):
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_draw():
		failed = true
	if not _check_sympathy(catalog):
		failed = true
	if not _check_balance():
		failed = true
	if failed:
		print("PIN WARMTH FAIL")
		quit(1)
		return
	print("PIN WARMTH OK")
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


func _neutral(game: Game) -> String:
	for sid in game.stations:
		if str(sid) == str(game.capital_id):
			continue
		var st: Dictionary = game.stations[sid]
		if str(st.owner) != "neutral" or bool(st.get("hidden", false)):
			continue
		return str(sid)
	return ""


func _silence(game: Game) -> void:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(sid) == str(game.capital_id):
			continue
		st.known = false
		st.intel = 0
		st.hidden = false
		st.erase("visited")
		st.erase("joined")
		st.erase("captured")


func _arm(game: Game, sid: String, sympathy: int, known: bool, owner: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = owner
	st.known = known
	st.sympathy = sympathy
	st.intel = 1 if known else 0
	st.hidden = false
	st.erase("visited")
	st.erase("joined")
	st.erase("captured")


func _sympathies(game: Game) -> Dictionary:
	var out := {}
	for sid in game.stations:
		out[str(sid)] = int(game.stations[sid].get("sympathy", 0))
	return out


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("warm.cold") != "Cold" or Copy.t("warm.wary") != "Wary" or Copy.t("warm.warm") != "Warm":
		print("Strings: FAIL en bands")
		return false
	if Copy.t("warm.ready") != "Ready" or Copy.t("warm.join") != "With us":
		print("Strings: FAIL en ready/join")
		return false
	if Copy.t("warm.band") != "{band}" or Copy.fill("warm.band", {"band": Copy.t("warm.cold")}) != "Cold":
		print("Strings: FAIL en band fill")
		return false
	if Copy.t("warm.tip") != "Sympathy sits on the ring.":
		print("Strings: FAIL en tip ", Copy.t("warm.tip"))
		return false
	if Copy.t("warm.first") != "The ring remembers how they feel.":
		print("Strings: FAIL en first ", Copy.t("warm.first"))
		return false
	Copy.set_lang("ru")
	if Copy.t("warm.cold") != "Холод" or Copy.t("warm.wary") != "Настороже" or Copy.t("warm.warm") != "Тепло":
		print("Strings: FAIL ru bands ", Copy.t("warm.cold"), " ", Copy.t("warm.wary"), " ", Copy.t("warm.warm"))
		return false
	if Copy.t("warm.ready") != "Готовы" or Copy.t("warm.join") != "С нами":
		print("Strings: FAIL ru ready/join")
		return false
	if Copy.fill("warm.band", {"band": Copy.t("warm.join")}) != "С нами":
		print("Strings: FAIL ru band fill")
		return false
	if Copy.t("warm.tip") != "Симпатия на кольце.":
		print("Strings: FAIL ru tip ", Copy.t("warm.tip"))
		return false
	if Copy.t("warm.first") != "Кольцо помнит, как они к вам.":
		print("Strings: FAIL ru first ", Copy.t("warm.first"))
		return false
	var ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/ru.json"))
	if typeof(ru) != TYPE_DICTIONARY:
		print("Strings: FAIL ru.json")
		return false
	var want := {
		"Sympathy sits on the ring.": "Симпатия на кольце.",
		"The ring remembers how they feel.": "Кольцо помнит, как они к вам.",
		"{band}": "{band}",
	}
	for key in want:
		if str(ru.get(key, "")) != str(want[key]):
			print("Strings: FAIL ru.json ", key)
			return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_bands(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	if sid == "":
		print("Bands: FAIL no station")
		return false
	_silence(game)
	var expect := {
		0: ["cold", "6f8494"],
		19: ["cold", "6f8494"],
		20: ["wary", "8c8170"],
		49: ["wary", "8c8170"],
		50: ["warm", "c4a574"],
		69: ["warm", "c4a574"],
		70: ["ready", "e2a63a"],
		99: ["ready", "e2a63a"],
	}
	for sympathy in expect:
		_arm(game, sid, int(sympathy), true, "neutral")
		var row: Array = expect[sympathy]
		var st: Dictionary = game.stations[sid]
		if not Warmth.shows(game, sid) or Warmth.band_of(st) != str(row[0]):
			print("Bands: FAIL show ", sympathy, " ", Warmth.band_of(st))
			return false
		var got := Warmth.color_of(game, st).to_html(false)
		if got != str(row[1]):
			print("Bands: FAIL tint ", sympathy, " ", got)
			return false
		var ink := Warmth.ink(game, st)
		if ink.to_html(false) != str(row[1]) or not is_equal_approx(ink.a, Warmth.RING_ALPHA):
			print("Bands: FAIL ink ", sympathy, " ", ink)
			return false
		var tip: PackedStringArray = Warmth.lines(game, sid)
		var word := Copy.t(Warmth.band_key(str(row[0])))
		if tip.size() != 2 or tip[0] != word or tip[1] != "Sympathy sits on the ring.":
			print("Bands: FAIL tip ", sympathy, " ", tip)
			return false
		if tip[0].find("+") >= 0 or tip[1].find("+") >= 0 or tip[0].find(str(sympathy)) >= 0:
			print("Bands: FAIL delta ", tip)
			return false
	_arm(game, sid, 100, true, "neutral")
	var join_html := Warmth.join_color(game).to_html(false)
	var faction_html := Color(str(game.catalog.factions[str(game.player)].color)).to_html(false)
	if Warmth.band_of(game.stations[sid]) != "join" or join_html != faction_html or join_html == "e2a63a":
		print("Bands: FAIL join ", join_html, " ", faction_html)
		return false
	if Warmth.join_color(null).to_html(false) != "ff7a2f":
		print("Bands: FAIL join fallback")
		return false
	if Warmth.lines(game, sid)[0] != "With us":
		print("Bands: FAIL join word")
		return false
	_arm(game, sid, 12, true, "neutral")
	game.stations[sid].joined = true
	if Warmth.band_of(game.stations[sid]) != "join" or Warmth.color_of(game, game.stations[sid]).to_html(false) != join_html:
		print("Bands: FAIL joined flag")
		return false
	if int(game.stations[sid].sympathy) != 12:
		print("Bands: FAIL joined moved sympathy")
		return false
	game.stations[sid].erase("joined")
	game.stations[sid].captured = true
	if Warmth.band_of(game.stations[sid]) != "join":
		print("Bands: FAIL captured flag")
		return false
	game.stations[sid].erase("captured")
	_arm(game, sid, 55, false, "neutral")
	if Warmth.shows(game, sid) or Warmth.lines(game, sid).size() != 0:
		print("Bands: FAIL unknown")
		return false
	game.stations[sid].hidden = true
	if Warmth.shows(game, sid):
		print("Bands: FAIL fog")
		return false
	game.stations[sid].hidden = false
	game.stations[sid].intel = 1
	if not Warmth.shows(game, sid) or Warmth.band_of(game.stations[sid]) != "warm":
		print("Bands: FAIL intel")
		return false
	game.stations[sid].intel = 0
	game.stations[sid].visited = true
	if not Warmth.shows(game, sid):
		print("Bands: FAIL visited")
		return false
	game.stations[sid].erase("visited")
	_arm(game, sid, 80, true, str(game.player))
	if Warmth.shows(game, sid):
		print("Bands: FAIL owned")
		return false
	var home := str(game.capital_id)
	var held := str(game.stations[home].owner)
	var home_sym := int(game.stations[home].sympathy)
	game.stations[home].owner = "neutral"
	game.stations[home].known = true
	game.stations[home].sympathy = 90
	if Warmth.shows(game, home):
		print("Bands: FAIL home")
		return false
	game.stations[home].owner = held
	game.stations[home].sympathy = home_sym
	if not is_equal_approx(Warmth.RING_OUT, 2.5) or not is_equal_approx(Warmth.RING_WIDTH, 2.0) or Warmth.RING_SEGS != 28:
		print("Bands: FAIL geometry")
		return false
	if Warmth.READY == Color("a0281e"):
		print("Bands: FAIL ready is order red")
		return false
	print("Bands: ok")
	return true


func _check_float(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_silence(game)
	if Warmth.note(game) != "" or bool(game.flags.get("seen_pin_warmth", false)):
		print("Float: FAIL empty fired")
		return false
	_arm(game, sid, 3, true, "neutral")
	var before := _sympathies(game)
	var line := Warmth.note(game)
	if line != "The ring remembers how they feel." or not bool(game.flags.get("seen_pin_warmth", false)):
		print("Float: FAIL first ", line, " ", game.flags.get("seen_pin_warmth", false))
		return false
	if _sympathies(game) != before:
		print("Float: FAIL sympathy moved")
		return false
	_arm(game, sid, 88, true, "neutral")
	if Warmth.note(game) != "":
		print("Float: FAIL second")
		return false
	if line.find("+") >= 0:
		print("Float: FAIL delta")
		return false
	print("Float: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_silence(game)
	_arm(game, sid, 60, true, "neutral")
	if Warmth.note(game) != "The ring remembers how they feel.":
		print("Save: FAIL float")
		return false
	var data := game.export_state()
	var loaded := Game.new()
	loaded.setup(catalog, 4, 40)
	if not loaded.import_state(data):
		print("Save: FAIL import ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_pin_warmth", false)):
		print("Save: FAIL flag dropped")
		return false
	if Warmth.note(loaded) != "":
		print("Save: FAIL float after load")
		return false
	if not Warmth.shows(loaded, sid) or Warmth.band_of(loaded.stations[sid]) != "warm":
		print("Save: FAIL tint did not load ", loaded.stations[sid].get("sympathy", -1))
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
		"sympathy": _sympathies(game),
	}


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_silence(game)
	_arm(game, sid, 40, true, "neutral")
	var leaflet := int(game.stations[sid].get("leaflet_until", 0))
	var before := _dawn_snapshot(game)
	var line := Warmth.note(game)
	if line != "The ring remembers how they feel.":
		print("Dawn: FAIL float")
		return false
	var after := _dawn_snapshot(game)
	var flags_before: Dictionary = before.flags
	var flags_after: Dictionary = after.flags.duplicate(true)
	flags_after.erase("seen_pin_warmth")
	if flags_before != flags_after:
		print("Dawn: FAIL flags changed ", flags_after)
		return false
	if before.notices != after.notices or before.reports != after.reports:
		print("Dawn: FAIL queued a report")
		return false
	if str(after.chip.get("kind", "")) != str(before.chip.get("kind", "")):
		print("Dawn: FAIL chip kind ", before.chip, " ", after.chip)
		return false
	if str(after.chip.get("kind", "")) == "warm" or str(after.home) != "":
		print("Dawn: FAIL warm chip ", after.chip, " ", after.home)
		return false
	if before.sympathy != after.sympathy:
		print("Dawn: FAIL sympathy")
		return false
	if int(game.stations[sid].get("leaflet_until", 0)) != leaflet:
		print("Dawn: FAIL leaflet")
		return false
	if bool(game.flags.get("rumor_dawn", false)) or bool(game.flags.get("border_dawn_new", false)):
		print("Dawn: FAIL higher chip armed")
		return false
	if bool(game.flags.get("rail_dawn", false)) or bool(game.flags.get("home_pending", false)) or bool(game.flags.get("heard_home", false)):
		print("Dawn: FAIL stack flag")
		return false
	print("Dawn: ok")
	return true


func _check_draw() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin_at := src.find("func _draw_pin(")
	var pin := src.substr(pin_at)
	pin = pin.substr(0, pin.find("\nfunc "))
	var body := pin.find("draw_texture_rect_region")
	var warm := pin.find("_draw_warmth_ring")
	var border := pin.find("_draw_border_tick")
	if body < 0 or warm < 0 or warm < body:
		print("Draw: FAIL warmth not after pin")
		return false
	if border < 0 or border < warm:
		print("Draw: FAIL border tick not above warmth")
		return false
	var selected := pin.find("if sid == selected")
	if selected >= 0 and selected < border:
		print("Draw: FAIL selection covers the tick slot")
		return false
	var ink_fn := src.substr(src.find("func _draw_ink"))
	ink_fn = ink_fn.substr(0, ink_fn.find("\nfunc "))
	var order := ["_draw_pins", "_draw_deal_pips", "_draw_flags"]
	var at := -1
	for name in order:
		var found := ink_fn.find(name, at + 1)
		if found < 0:
			print("Draw: FAIL order missing ", name)
			return false
		at = found
	var warm_fn := src.substr(src.find("func _draw_warmth_ring"))
	warm_fn = warm_fn.substr(0, warm_fn.find("\nfunc "))
	if warm_fn.find("draw_arc") < 0 or warm_fn.find("PinWarmth.RING_OUT") < 0 or warm_fn.find("PinWarmth.RING_WIDTH") < 0:
		print("Draw: FAIL ring geometry")
		return false
	if warm_fn.find("_faction_color(game, str(game.player))") < 0:
		print("Draw: FAIL join accent")
		return false
	if warm_fn.find("_anim_t") >= 0 or warm_fn.find("sin(") >= 0 or warm_fn.find("create_tween") >= 0:
		print("Draw: FAIL pulse")
		return false
	var arcs := warm_fn.split("draw_arc").size() - 1
	if arcs != 1:
		print("Draw: FAIL extra ring ", arcs)
		return false
	if src.find("warm_lines(game, sid)") < 0 or src.find("note_pin_warmth") < 0:
		print("Draw: FAIL tip or float wiring")
		return false
	var float_fn := src.substr(src.find("func _show_warm_float"))
	float_fn = float_fn.substr(0, float_fn.find("\nfunc "))
	if float_fn.find("_motion_off()") < 0 or float_fn.find("tween_interval") < 0:
		print("Draw: FAIL reduce-motion float")
		return false
	if src.find("present_dawn_soft_chip") >= 0 and src.find("func _note_first_pin_warmth") >= 0:
		var note_fn := src.substr(src.find("func _note_first_pin_warmth"))
		note_fn = note_fn.substr(0, note_fn.find("\nfunc "))
		if note_fn.find("present_dawn_soft_chip") >= 0 or note_fn.find("leaflet") >= 0:
			print("Draw: FAIL dawn from float")
			return false
	print("Draw: ok")
	return true


func _check_sympathy(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_silence(game)
	_arm(game, sid, 33, true, "neutral")
	var before := _sympathies(game)
	var base := float(game.bal.sympathy_base)
	Warmth.band_of(game.stations[sid])
	Warmth.color_of(game, game.stations[sid])
	Warmth.lines(game, sid)
	Warmth.note(game)
	if _sympathies(game) != before or not is_equal_approx(float(game.bal.sympathy_base), base):
		print("Sympathy: FAIL values moved")
		return false
	if int(game.stations[sid].sympathy) != 33:
		print("Sympathy: FAIL station")
		return false
	print("Sympathy: ok")
	return true


func _check_balance() -> bool:
	var now := FileAccess.get_file_as_string("res://data/balance.json")
	if now != balance_text:
		print("Balance: FAIL file changed")
		return false
	if now.contains("seen_pin_warmth") or now.contains("warm.cold") or now.contains("pin_warmth"):
		print("Balance: FAIL mentions warmth")
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
