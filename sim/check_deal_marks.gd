extends SceneTree

const Marks = preload("res://sim/deal_marks.gd")

## P45 deal marks. Pips and the passage thread come from existing deals / passage.
## The first pip of a run floats once. No soft dawn chip. No balance drift.
##   godot --headless --path . -s res://sim/check_deal_marks.gd

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
	if not _check_pips(catalog):
		failed = true
	if not _check_passage(catalog):
		failed = true
	if not _check_float(catalog):
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_deal_numbers(catalog):
		failed = true
	if not _check_balance():
		failed = true
	_check_icon()
	if failed:
		print("DEAL MARKS FAIL")
		quit(1)
		return
	print("DEAL MARKS OK")
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


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("deal.pips") != "{n}/3 deals":
		print("Strings: FAIL pips en ", Copy.t("deal.pips"))
		return false
	if Copy.fill("deal.pips", {"n": 2}) != "2/3 deals":
		print("Strings: FAIL fill en")
		return false
	if Copy.t("deal.pips_done") != "3/3 · joined":
		print("Strings: FAIL done en")
		return false
	if Copy.t("deal.passage") != "Passage open":
		print("Strings: FAIL passage en")
		return false
	if Copy.t("deal.first") != "The pin keeps the handshake.":
		print("Strings: FAIL first en")
		return false
	if Copy.t("deal.tip") != "Deals stay on the pin.":
		print("Strings: FAIL tip en")
		return false
	if Copy.fill("deal.reduce", {"n": 1}) != "1/3":
		print("Strings: FAIL reduce en")
		return false
	Copy.set_lang("ru")
	if Copy.t("deal.pips") != "{n}/3 сделок" or Copy.fill("deal.pips", {"n": 2}) != "2/3 сделок":
		print("Strings: FAIL pips ru ", Copy.t("deal.pips"))
		return false
	if Copy.t("deal.pips_done") != "3/3 · вошли":
		print("Strings: FAIL done ru")
		return false
	if Copy.t("deal.passage") != "Проход открыт":
		print("Strings: FAIL passage ru")
		return false
	if Copy.t("deal.first") != "Метка хранит рукопожатие.":
		print("Strings: FAIL first ru")
		return false
	if Copy.t("deal.tip") != "Сделки остаются на метке.":
		print("Strings: FAIL tip ru")
		return false
	if Copy.fill("deal.reduce", {"n": 1}) != "1/3":
		print("Strings: FAIL reduce ru")
		return false
	var ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/ru.json"))
	if typeof(ru) != TYPE_DICTIONARY:
		print("Strings: FAIL ru.json")
		return false
	var want := {
		"{n}/3 deals": "{n}/3 сделок",
		"3/3 · joined": "3/3 · вошли",
		"Passage open": "Проход открыт",
		"The pin keeps the handshake.": "Метка хранит рукопожатие.",
		"Deals stay on the pin.": "Сделки остаются на метке.",
		"{n}/3": "{n}/3",
	}
	for key in want:
		if str(ru.get(key, "")) != str(want[key]):
			print("Strings: FAIL ru.json ", key)
			return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _arm(game: Game, sid: String, deals: int, passage: bool, owner: String, known: bool) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = owner
	st.known = known
	st.deals = deals
	st.passage = passage
	st.erase("joined")


func _check_pips(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	if sid == "":
		print("Pips: FAIL no station")
		return false
	_arm(game, sid, 0, false, "neutral", true)
	if Marks.pip_count(game, sid) != 0:
		print("Pips: FAIL zero ", Marks.pip_count(game, sid))
		return false
	for n in [1, 2, 3]:
		_arm(game, sid, n, false, "neutral", true)
		if Marks.pip_count(game, sid) != n:
			print("Pips: FAIL count ", n, " ", Marks.pip_count(game, sid))
			return false
		var line := Marks.pip_line(game, sid, false)
		if line != "%d/3 deals" % n:
			print("Pips: FAIL line ", line)
			return false
	_arm(game, sid, 4, false, "neutral", true)
	if Marks.pip_count(game, sid) != 3 or Marks.pip_line(game, sid, false) != "3/3 deals":
		print("Pips: FAIL cap")
		return false
	_arm(game, sid, 2, false, "neutral", false)
	if Marks.pip_count(game, sid) != 0:
		print("Pips: FAIL unknown")
		return false
	var st: Dictionary = game.stations[sid]
	st.hidden = true
	if Marks.pip_count(game, sid) != 0:
		print("Pips: FAIL secret")
		return false
	st.hidden = false
	_arm(game, sid, 2, false, str(game.player), true)
	if Marks.pip_count(game, sid) != 0 or Marks.pip_line(game, sid, false) != "":
		print("Pips: FAIL player")
		return false
	_arm(game, sid, 3, true, str(game.player), true)
	if Marks.pip_count(game, sid) != 0 or Marks.pip_line(game, sid, false) != "3/3 · joined":
		print("Pips: FAIL joined owner ", Marks.pip_line(game, sid, false))
		return false
	_arm(game, sid, 3, false, "neutral", true)
	st = game.stations[sid]
	st.joined = true
	if Marks.pip_count(game, sid) != 3 or Marks.pip_line(game, sid, false) != "3/3 · joined":
		print("Pips: FAIL joined flag")
		return false
	st.erase("joined")
	_arm(game, sid, 2, true, "neutral", true)
	var lines: PackedStringArray = Marks.mark_lines(game, sid, false)
	if lines[0] != "2/3 deals" or not lines.has("Deals stay on the pin.") or not lines.has("Passage open"):
		print("Pips: FAIL lines ", lines)
		return false
	var compact: PackedStringArray = Marks.mark_lines(game, sid, true)
	if compact[0] != "2/3" or compact.has("2/3 deals") or compact.has("Deals stay on the pin."):
		print("Pips: FAIL compact ", compact)
		return false
	if not compact.has("Passage open"):
		print("Pips: FAIL compact passage")
		return false
	var view_src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var wired := view_src.find("deal_mark_lines(game, sid, _motion_off())") >= 0
	if not wired or Marks.pips_pulse() or view_src.find("return DealMarks.pips_pulse()") < 0:
		print("Pips: FAIL motion wiring")
		return false
	var at := Vector2(10, 20)
	var p0 := Marks.pip_slot(at, 12.0, 0)
	var p1 := Marks.pip_slot(at, 12.0, 1)
	var p2 := Marks.pip_slot(at, 12.0, 2)
	var slots_ok := is_equal_approx(p0.x, 3.0) and is_equal_approx(p1.x, 10.0) and is_equal_approx(p2.x, 17.0)
	slots_ok = slots_ok and is_equal_approx(p0.y, 40.0) and is_equal_approx(p1.y, 40.0) and is_equal_approx(p1.distance_to(p2), 7.0)
	if not slots_ok or not is_equal_approx(Marks.PIP_R, 2.8):
		print("Pips: FAIL slots ", p0, p1, p2)
		return false
	if Marks.BRASS.to_html(false) != "e2a63a":
		print("Pips: FAIL brass")
		return false
	print("Pips: ok")
	return true


func _check_passage(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_arm(game, sid, 1, false, "neutral", true)
	if Marks.shows_thread(game, sid):
		print("Passage: FAIL false showed")
		return false
	_arm(game, sid, 1, true, "neutral", true)
	if not Marks.shows_thread(game, sid):
		print("Passage: FAIL missing")
		return false
	_arm(game, sid, 1, true, "neutral", false)
	if Marks.shows_thread(game, sid):
		print("Passage: FAIL unknown")
		return false
	_arm(game, sid, 3, true, str(game.player), true)
	if Marks.shows_thread(game, sid):
		print("Passage: FAIL joined still threaded")
		return false
	if Marks.shows_thread(game, str(game.capital_id)):
		print("Passage: FAIL capital")
		return false
	var ink := Marks.passage_ink()
	if ink.to_html(false) != "e2a63a" or not is_equal_approx(ink.a, 0.85):
		print("Passage: FAIL ink ", ink)
		return false
	if ink.to_html(false) == Color("a0281e").to_html(false):
		print("Passage: FAIL ORDER_RED")
		return false
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var ink_fn := src.substr(src.find("func _draw_ink"))
	ink_fn = ink_fn.substr(0, ink_fn.find("\nfunc "))
	var order := ["_draw_lines", "_draw_tunnels", "_draw_passage_edges", "_draw_order_trails", "_draw_pins", "_draw_deal_pips"]
	var at := -1
	for name in order:
		var found := ink_fn.find(name, at + 1)
		if found < 0:
			print("Passage: FAIL draw order missing ", name)
			return false
		at = found
	print("Passage: ok")
	return true


func _check_float(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_arm(game, sid, 0, false, "neutral", true)
	if Marks.note(game) != "" or bool(game.flags.get("seen_deal_marks", false)):
		print("Float: FAIL empty fired")
		return false
	_arm(game, sid, 1, true, "neutral", true)
	var line := Marks.note(game)
	if line != "The pin keeps the handshake." or not bool(game.flags.get("seen_deal_marks", false)):
		print("Float: FAIL first ", line, " ", game.flags.get("seen_deal_marks", false))
		return false
	_arm(game, sid, 3, true, "neutral", true)
	if Marks.note(game) != "":
		print("Float: FAIL second")
		return false
	print("Float: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_arm(game, sid, 2, true, "neutral", true)
	if Marks.note(game) != "The pin keeps the handshake.":
		print("Save: FAIL float")
		return false
	var data := game.export_state()
	var loaded := Game.new()
	loaded.setup(catalog, 4, 40)
	if not loaded.import_state(data):
		print("Save: FAIL import ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_deal_marks", false)):
		print("Save: FAIL flag dropped")
		return false
	if Marks.note(loaded) != "":
		print("Save: FAIL float after load")
		return false
	if Marks.pip_count(loaded, sid) != 2 or not Marks.shows_thread(loaded, sid):
		print("Save: FAIL marks did not load")
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
	}


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neutral(game)
	_arm(game, sid, 1, true, "neutral", true)
	var before := _dawn_snapshot(game)
	var line := Marks.note(game)
	if line != "The pin keeps the handshake.":
		print("Dawn: FAIL float")
		return false
	var after := _dawn_snapshot(game)
	var flags_before: Dictionary = before.flags
	var flags_after: Dictionary = after.flags.duplicate(true)
	flags_after.erase("seen_deal_marks")
	if flags_before != flags_after:
		print("Dawn: FAIL flags changed ", flags_after)
		return false
	if before.notices != after.notices or before.reports != after.reports:
		print("Dawn: FAIL queued a report")
		return false
	if str(after.chip.get("kind", "")) != str(before.chip.get("kind", "")):
		print("Dawn: FAIL chip kind ", before.chip, " ", after.chip)
		return false
	if str(after.chip.get("kind", "")) == "deal" or str(after.home) != "":
		print("Dawn: FAIL deal chip ", after.chip, " ", after.home)
		return false
	if bool(game.flags.get("rumor_dawn", false)) or bool(game.flags.get("border_dawn_new", false)):
		print("Dawn: FAIL higher chip armed")
		return false
	if bool(game.flags.get("rail_dawn", false)) or bool(game.flags.get("home_pending", false)) or bool(game.flags.get("heard_home", false)):
		print("Dawn: FAIL stack flag")
		return false
	print("Dawn: ok")
	return true


func _check_deal_numbers(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		print("Numbers: FAIL no neighbor")
		return false
	if game.order_cost("trade", sid).influence != 4:
		print("Numbers: FAIL cost")
		return false
	var st: Dictionary = game.stations[sid]
	st.known = true
	var sympathy := int(st.sympathy)
	var influence := int(game.stock.influence)
	var food := int(game.stock.food)
	var materials := int(game.stock.materials)
	if not game._order_deal(sid):
		print("Numbers: FAIL order ", game._deal_block(sid))
		return false
	if int(st.deals) != 1 or not bool(st.passage) or int(st.sympathy) != sympathy:
		print("Numbers: FAIL state ", st.deals, " ", st.passage, " ", st.sympathy)
		return false
	if int(game.stock.influence) != influence - 4 or int(game.stock.food) != food + 4 or int(game.stock.materials) != materials + 2:
		print("Numbers: FAIL payout")
		return false
	if game.deal_preview(sid) != 2:
		print("Numbers: FAIL preview ", game.deal_preview(sid))
		return false
	if Marks.pip_count(game, sid) != 1 or not Marks.shows_thread(game, sid):
		print("Numbers: FAIL marks after deal")
		return false
	game.week = 2
	st.deals = 3
	st.owner = "neutral"
	st.sympathy = 40
	var held := int(game.stock.influence)
	if game._deal_block(sid) != "Three deals are already in force." or game._order_deal(sid):
		print("Numbers: FAIL threshold ", game._deal_block(sid))
		return false
	if int(st.deals) != 3 or int(st.sympathy) != 40 or int(game.stock.influence) != held:
		print("Numbers: FAIL threshold moved state")
		return false
	game.week = 5
	st.deals = 2
	st.owner = "neutral"
	st.sympathy = 30
	var hope := int(game.hope)
	var dis := int(game.discontent)
	if not game._order_deal(sid):
		print("Numbers: FAIL join order")
		return false
	if int(st.deals) != 3 or str(st.owner) != str(game.player) or int(st.sympathy) != 0:
		print("Numbers: FAIL join ", st.owner, " ", st.deals, " ", st.sympathy)
		return false
	if int(game.hope) != hope + int(game.bal.join_hope) or int(game.discontent) != dis + int(game.bal.join_discontent):
		print("Numbers: FAIL join meters")
		return false
	if Marks.pip_count(game, sid) != 0 or Marks.shows_thread(game, sid) or Marks.pip_line(game, sid, false) != "3/3 · joined":
		print("Numbers: FAIL joined marks")
		return false
	print("Numbers: ok")
	return true


func _check_balance() -> bool:
	var now := FileAccess.get_file_as_string("res://data/balance.json")
	if now != balance_text:
		print("Balance: FAIL file changed")
		return false
	if now.contains("seen_deal_marks") or now.contains("deal_pip") or now.contains("deal.pips"):
		print("Balance: FAIL mentions deal marks")
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


func _check_icon() -> void:
	var paths := [
		"res://assets/icons/status/deal_pip.png",
		"res://assets/icons/status/deal_pip_24.png",
		"res://assets/icons/map/deal_pip.png",
		"res://assets/icons/map/deal_pip_24.png",
	]
	for path in paths:
		if not FileAccess.file_exists(path):
			print("Icon: omitted (deal_pip file missing)")
			return
	var big := Image.new()
	var small := Image.new()
	if big.load("res://assets/icons/status/deal_pip.png") != OK or small.load("res://assets/icons/status/deal_pip_24.png") != OK:
		print("Icon: deal_pip present but did not load; pips stay vector")
		return
	if big.get_width() != 256 or small.get_width() != 24:
		print("Icon: FAIL size %d / %d" % [big.get_width(), small.get_width()])
		failed = true
		return
	print("Icon: deal_pip 256+24")
