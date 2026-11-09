extends SceneTree

## P90 Carried Word gate.
##   godot --headless --path . -s res://sim/check_carried_word.gd
## Balance ZERO. Soft dawn none. Map mark none. Schema 21. closed_bonus unwired.

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
const PARTS := ["title", "offer", "read", "delivered", "reply_read", "closed", "opened"]

var _failed := false


class Host extends Node:
	var game
	var showing_network := true
	var network_view = null
	var body_font: Font
	var display_font: Font
	var toast_text := ""
	var toast_commit: Callable = Callable()
	var toast_undo: Callable = Callable()
	func _motion_off() -> bool:
		return true
	func _ui_click() -> void:
		pass
	func _portrait_box(id: String, px: int) -> TextureRect:
		var face := TextureRect.new()
		face.custom_minimum_size = Vector2(px, px)
		face.set_meta("portrait_for", id)
		return face
	func _close_observer() -> void:
		pass
	func _toggle_network() -> void:
		showing_network = true
	func _undo_toast(text: String, undo: Callable, commit: Callable = Callable()) -> void:
		toast_text = text
		toast_undo = undo
		toast_commit = commit
	func _hide_undo_toast() -> void:
		toast_text = ""
		toast_commit = Callable()
		toast_undo = Callable()
	func _dismiss_undo_toast() -> bool:
		if toast_text == "":
			return false
		var undo := toast_undo
		_hide_undo_toast()
		if undo.is_valid():
			undo.call()
		return true
	func _toast(text: String, _hold: float = 1.8) -> void:
		toast_text = text


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	CarriedWord.enabled = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("CARRIED WORD FAIL catalog")
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 27:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _rules(catalog):
		_failed = true
	else:
		print("Rules: ok")
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
	if not await _undo_plate():
		_failed = true
	else:
		print("Toast: ok")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if _failed:
		print("CARRIED WORD FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("CARRIED WORD FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("CARRIED WORD FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	CarriedWord.enabled = true
	print("CARRIED WORD OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 12)
	game.week = 6
	game.stock.influence = 40
	game.stock.food = 40
	game.stock.materials = 40
	game.stock.air = 40
	game.stock.tokens = 40
	game.stock.power = 40
	game.orders_left = 4
	return game


func _touch(game: Game, sid: String, sympathy: int = 60) -> void:
	var st: Dictionary = game.stations[sid]
	st.known = true
	st.sympathy = sympathy
	st.owner = "neutral"
	st.low_weeks = 2
	PlatformFaces.meet(game, sid)


func _border(game: Game, sid: String) -> void:
	for n in game._neighbors(sid):
		var id := str(n)
		if id == sid:
			continue
		game.stations[id].owner = game.player


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/carried_word.json"))
	var frag = JSON.parse_string(FileAccess.get_file_as_string("res://data/carried_word_ru_fragment.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P90":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	if int(pack.get("_flag_later", {}).get("closed_bonus", -1)) != 0:
		_bad("closed_bonus flag")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	var threads: Array = pack.get("_threads", [])
	if rows.size() != 74 or not (frag is Dictionary) or frag.size() != 74 or threads.size() != 8:
		_bad("key count %s / %s threads %s" % [rows.size(), frag.size() if frag is Dictionary else "bad", threads.size()])
		return false
	var want := ["lamp_copper", "seed_smoke", "water_air", "arm_debt", "badge_4411", "last_page", "unsigned", "no_cough"]
	for i in want.size():
		if str(threads[i].get("id", "")) != want[i]:
			_bad("thread order " + str(threads[i]))
			return false
		for part in PARTS:
			var key := "carry.%s.%s" % [want[i], part]
			if not rows.has(key):
				_bad("missing " + key)
				return false
	for key in rows:
		if not str(key).begins_with("carry."):
			_bad("namespace " + str(key))
			return false
		if str(key).begins_with("word.") or str(key).begins_with("note."):
			_bad("banned namespace " + str(key))
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty " + str(key))
			return false
		if str(row.get("ru", "")) != str(frag.get(key, "")):
			_bad("ru drift " + str(key))
			return false
		if str(key).find("closed_bonus") >= 0 or str(key).find("kept_bonus") >= 0:
			_bad("bonus key " + str(key))
			return false
	Copy.set_lang("ru")
	if Copy.t("carry.first") != "Тебе доверили чужие слова.":
		_bad("first ru")
		return false
	if Copy.t("carry.take") != "Взять записку" or Copy.t("carry.take_reply") != "Взять ответ":
		_bad("button ru")
		return false
	var handed := Copy.fill("carry.delivered_report", {"who": "Ада", "to": "Рен", "station": "Фултон-стрит", "fem": true})
	if handed.find("передала") < 0 or handed.find("передал ") >= 0:
		_bad("report agreement " + handed)
		return false
	Copy.set_lang("en")
	if Copy.t("carry.take") != "Take the note" or Copy.t("carry.open_confirm") != "Once it's open, it stays open.":
		_bad("button en")
		return false
	if CarriedWord.threads().size() != 8 or str(CarriedWord.threads()[0].get("id", "")) != "lamp_copper":
		_bad("loaded order")
		return false
	return true


func _rules(catalog: Catalog) -> bool:
	if CarriedWord.dawn_chip() or CarriedWord.joins_soft_dawn() or CarriedWord.map_mark():
		_bad("dawn or map")
		return false
	var game := Game.new()
	if game.carried_word_dawn_chip() or game.dawn_soft_stack().has("carry"):
		_bad("game dawn chip")
		return false
	var closed := _fresh(catalog)
	_pair(closed, "brickworks", "quarry")
	if not _deliver_pair(closed, "envoy", "trade"):
		return false
	var origin: Dictionary = PlatformFaces.line(closed, "brickworks")
	if int(origin.get("slot", 0)) != 1 or str(origin.get("key", "")) != "carry.lamp_copper.closed":
		_bad("closed line %s slot %s" % [str(origin.get("key", "")), str(origin.get("slot", 0))])
		return false
	if str(closed.carry.threads.get("lamp_copper", "")) != "closed" or int(closed.carry.delivered) != 2:
		_bad("closed state %s n %s" % [str(closed.carry.threads), str(closed.carry.delivered)])
		return false
	closed.week = 8
	var later: Dictionary = PlatformFaces.line(closed, "brickworks")
	if str(later.get("key", "")).begins_with("carry."):
		_bad("linger stuck " + str(later.get("key", "")))
		return false
	var opened := _fresh(catalog)
	_pair(opened, "brickworks", "quarry")
	if not CarriedWord.take(opened, "brickworks"):
		_bad("open path take")
		return false
	if CarriedWord.commit_open(opened):
		_bad("commit without the toast window")
		return false
	if not CarriedWord.open(opened) or CarriedWord.pocket_view(opened).text != "":
		_bad("text before lapse")
		return false
	CarriedWord.cancel_open(opened)
	if bool(CarriedWord.pocket_view(opened).opened) or CarriedWord.pocket_view(opened).text != "":
		_bad("escape opened the note")
		return false
	if not CarriedWord.open(opened) or not CarriedWord.commit_open(opened):
		_bad("lapse")
		return false
	if CarriedWord.pocket_view(opened).text != Copy.t("carry.lamp_copper.read"):
		_bad("read text")
		return false
	if not _resolve(opened, "envoy", "quarry"):
		_bad("opened envoy " + opened._envoy_block("quarry"))
		return false
	if str(opened.carry.threads.get("lamp_copper", "")) != "opened" or not CarriedWord.offer(opened, "quarry").is_empty():
		_bad("reply after opened")
		return false
	var dest: Dictionary = PlatformFaces.line(opened, "quarry")
	var back: Dictionary = PlatformFaces.line(opened, "brickworks")
	if str(dest.get("key", "")) != "carry.lamp_copper.opened" or str(back.get("key", "")) != "carry.origin_opened":
		_bad("opened lines %s / %s" % [str(dest.get("key", "")), str(back.get("key", ""))])
		return false
	if int(dest.get("slot", 0)) != 1:
		_bad("opened slot")
		return false
	var full := _fresh(catalog)
	_pair(full, "brickworks", "quarry")
	_touch(full, "riverside", 60)
	_touch(full, "mill", 20)
	if not CarriedWord.take(full, "brickworks"):
		_bad("first take")
		return false
	if CarriedWord.take(full, "riverside"):
		_bad("second note")
		return false
	var muted: Dictionary = PlatformFaces.line(full, "riverside")
	if not bool(muted.get("muted", false)) or str(muted.get("reason", "")) != "carry.one_only" or str(muted.get("button", "")) != "":
		_bad("full pocket %s" % str(muted))
		return false
	if int(muted.get("slot", 0)) != 1:
		_bad("muted slot")
		return false
	var back_name := CarriedWord.give_back(full)
	if back_name != "Pilar Ruiz" or not full.carry.threads.is_empty() or not CarriedWord._pocket(full).is_empty():
		_bad("give back " + back_name)
		return false
	if str(CarriedWord.offer(full, "brickworks").get("button", "")) != "carry.take":
		_bad("reoffer")
		return false
	var forced := _fresh(catalog)
	_pair(forced, "brickworks", "quarry")
	if not CarriedWord.take(forced, "brickworks"):
		_bad("force take")
		return false
	if not forced._capture("quarry", forced.player, true):
		_bad("force capture")
		return false
	if not bool(CarriedWord.pocket_view(forced).no_one) or CarriedWord.tip_line(forced, "quarry") != "":
		_bad("no one")
		return false
	var before := forced.carry.duplicate(true)
	forced.stations.quarry.focus = "food"
	if CarriedWord.on_order(forced, "focus", "quarry", "Ada", true) != "":
		_bad("focus delivered to a force-taken station")
		return false
	if not _resolve_action(forced, {"order": "focus", "station": "quarry", "focus": "air"}, "Ada"):
		_bad("focus order failed")
		return false
	if str(forced.carry.pocket.get("thread", "")) != "lamp_copper":
		_bad("force focus emptied the pocket")
		return false
	forced.carry = before
	for kind in ["probe", "tap", "patrol", "raid", "assault"]:
		var rng := forced.rng.state
		var line := CarriedWord.on_order(forced, kind, "quarry", "Ada", true)
		if line != "" or str(forced.carry.pocket.get("thread", "")) != "lamp_copper" or forced.rng.state != rng:
			_bad("never %s delivered" % kind)
			return false
	if not _kinds(catalog):
		return false
	var win := _fresh(catalog)
	_touch(win, "brickworks", 10)
	_touch(win, "quarry", 10)
	win.stations.quarry.known = true
	if not win._capture("brickworks", win.player, true):
		_bad("slot capture")
		return false
	win.stations.brickworks.sympathy = 60
	var slot: Dictionary = PlatformFaces.line(win, "brickworks")
	if int(slot.get("slot", 0)) != 1 or not str(slot.get("key", "")).begins_with("carry."):
		_bad("slot 1 lost to gone %s" % str(slot))
		return false
	var cold := _fresh(catalog)
	_touch(cold, "brickworks", 10)
	_touch(cold, "quarry", 10)
	var band: Dictionary = PlatformFaces.line(cold, "brickworks")
	if str(band.get("key", "")).begins_with("carry."):
		_bad("offer below 50")
		return false
	return true


func _deliver_pair(game: Game, leg1: String, leg2: String) -> bool:
	if not CarriedWord.take(game, "brickworks"):
		_bad("take leg 1")
		return false
	if CarriedWord.claim_first(game) != Copy.t("carry.first") or CarriedWord.claim_first(game) != "":
		_bad("first float once")
		return false
	if not _resolve(game, leg1, "quarry"):
		_bad(leg1 + " " + game._envoy_block("quarry"))
		return false
	if not game.carry.pocket.is_empty() or str(game.carry.threads.get("lamp_copper", "")) != "leg1_done":
		_bad("leg 1 state")
		return false
	var report := str(game.order_reports.back().get("text", "")) if not game.order_reports.is_empty() else ""
	var want := Copy.fill("carry.delivered_report", {"who": "Ada", "to": "Wren Kowalski", "station": "Fulton St", "fem": true})
	if report.find(want) < 0:
		_bad("report [" + report + "] want [" + want + "]")
		return false
	var reply: Dictionary = CarriedWord.offer(game, "quarry")
	if str(reply.get("button", "")) != "carry.take_reply":
		_bad("reply offer %s" % str(reply))
		return false
	if not CarriedWord.take(game, "quarry"):
		_bad("take reply")
		return false
	if not _resolve(game, leg2, "brickworks"):
		_bad(leg2 + " block")
		return false
	if str(game.order_reports.back().get("text", "")).find("Pilar Ruiz") < 0:
		_bad("reply report " + str(game.order_reports.back().get("text", "")))
		return false
	return true


func _kinds(catalog: Catalog) -> bool:
	var aid := _fresh(catalog)
	_pair(aid, "brickworks", "quarry")
	if not CarriedWord.take(aid, "brickworks") or not _resolve(aid, "aid", "quarry"):
		_bad("aid deliver")
		return false
	if str(aid.carry.threads.get("lamp_copper", "")) != "leg1_done":
		_bad("aid state")
		return false
	var paper := _fresh(catalog)
	_pair(paper, "brickworks", "quarry")
	if not CarriedWord.take(paper, "brickworks") or not _resolve(paper, "propaganda", "quarry"):
		_bad("propaganda deliver")
		return false
	var owned := _fresh(catalog)
	_pair(owned, "brickworks", "quarry")
	if not CarriedWord.take(owned, "brickworks"):
		_bad("move take")
		return false
	if not owned._capture("quarry", owned.player, false) or bool(PlatformFaces.memory(owned, "quarry").taken):
		_bad("peace capture")
		return false
	owned.squads[owned.player].station = "market"
	owned.squads[owned.player].away = false
	if not _resolve(owned, "move", "quarry"):
		_bad("move deliver " + owned._move_block("quarry"))
		return false
	if str(owned.carry.threads.get("lamp_copper", "")) != "leg1_done":
		_bad("move state")
		return false
	var focus := _fresh(catalog)
	_pair(focus, "riverside", "mill")
	if not CarriedWord.take(focus, "riverside"):
		_bad("focus take")
		return false
	if not focus._capture("mill", focus.player, false):
		_bad("focus own")
		return false
	focus.stations.mill.focus = "food"
	if not _resolve_action(focus, {"order": "focus", "station": "mill", "focus": "air"}, "Ada"):
		_bad("focus deliver")
		return false
	if str(focus.carry.threads.get("seed_smoke", "")) != "leg1_done":
		_bad("focus state " + str(focus.carry.threads))
		return false
	var patrol := _fresh(catalog)
	_pair(patrol, "brickworks", "quarry")
	if not CarriedWord.take(patrol, "brickworks"):
		_bad("patrol take")
		return false
	patrol.squads[patrol.player].station = "market"
	patrol.squads[patrol.player].away = false
	if not _resolve(patrol, "patrol", "quarry"):
		_bad("patrol order " + patrol._patrol_gate("quarry"))
		return false
	if str(patrol.carry.pocket.get("thread", "")) != "lamp_copper":
		_bad("patrol delivered")
		return false
	var run := _fresh(catalog)
	_pair(run, "brickworks", "quarry")
	if not CarriedWord.take(run, "brickworks"):
		_bad("run take")
		return false
	var home: Dictionary = CarriedWord.on_night_run(run, {"id": "quarry_ruins", "station": "quarry"})
	if str(home.get("en", "")).find("Wren Kowalski") < 0 or str(home.get("en", "")).find("Fulton St") < 0:
		_bad("run line " + str(home))
		return false
	if not run.carry.pocket.is_empty() or str(run.carry.threads.get("lamp_copper", "")) != "leg1_done":
		_bad("run state")
		return false
	var miss := _fresh(catalog)
	_pair(miss, "brickworks", "quarry")
	CarriedWord.take(miss, "brickworks")
	var other: Dictionary = CarriedWord.on_night_run(miss, {"station": "mill"})
	if not other.is_empty() or str(miss.carry.pocket.get("thread", "")) != "lamp_copper":
		_bad("run wrong station")
		return false
	var src := FileAccess.get_file_as_string("res://sim/night_runs.gd")
	if src.find("CarriedWord.on_night_run") < 0 or src.find("rested.is_empty()") < 0:
		_bad("night hook")
		return false
	return true


func _pair(game: Game, origin: String, dest: String) -> void:
	_touch(game, origin, 60)
	_touch(game, dest, 20)
	_border(game, origin)
	_border(game, dest)
	game.stations[origin].owner = "neutral"
	game.stations[dest].owner = "neutral"


func _resolve(game: Game, kind: String, sid: String) -> bool:
	var action := {"order": kind}
	if kind == "move" or kind == "patrol" or kind == "raid" or kind == "assault":
		action["dest"] = sid
	else:
		action["station"] = sid
	return _resolve_action(game, action, "Ada")


func _resolve_action(game: Game, action: Dictionary, who: String) -> bool:
	game.queued_orders = [{
		"action": action,
		"cost": {},
		"role": "talk",
		"name": who,
		"person": "ada",
	}]
	var before := game.order_reports.size()
	game._resolve_queued()
	if game.order_reports.size() <= before:
		return false
	return bool(game.order_reports.back().get("ok", false))


func _save(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	_pair(game, "brickworks", "quarry")
	CarriedWord.take(game, "brickworks")
	game.flags[CarriedWord.SEEN] = true
	var data := game.export_state()
	data["schema"] = 21
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data):
		_bad("schema 21 load " + again.load_error)
		return false
	if str(again.carry.pocket.get("thread", "")) != "lamp_copper" or not bool(again.flags.get(CarriedWord.SEEN, false)):
		_bad("round trip")
		return false
	data.erase("carry")
	var bare := Game.new()
	bare.catalog = catalog
	if bare.import_state(data):
		_bad("schema 21 accepted a save with no carry")
		return false
	for old_schema in [20, 19, 18]:
		var old_data := game.export_state()
		old_data.erase("carry")
		old_data["schema"] = old_schema
		var old := Game.new()
		old.catalog = catalog
		if not old.import_state(old_data):
			_bad("schema %d load %s" % [old_schema, old.load_error])
			return false
		if not old.carry.pocket.is_empty() or int(old.carry.delivered) != 0 or not old.carry.threads.is_empty():
			_bad("schema %d kept a note" % old_schema)
			return false
	return true


func _bounds() -> bool:
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	if src.find("const SAVE_SCHEMA := 27") < 0 or src.find("V20_ADDED") < 0 or src.find("\"carry\"") < 0:
		_bad("schema source")
		return false
	var picker := _fn(src, "_pick_dawn_soft_chip")
	if picker == "" or picker.find("carry") >= 0 or picker.find("CarriedWord") >= 0:
		_bad("dawn picker knows carry")
		return false
	var view := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var pin := _fn(view, "_draw_pin")
	if pin.find("CarriedWord") >= 0 or pin.find("carry.") >= 0:
		_bad("map pin knows carry")
		return false
	for draw_name in ["_draw_pins", "_draw_soft_marks", "_draw_ink"]:
		var body := _fn(view, draw_name)
		if body.find("CarriedWord") >= 0 or body.find("carry.") >= 0:
			_bad(draw_name + " draws a carry mark")
			return false
	if FileAccess.get_file_as_string("res://sim/bot.gd").find("CarriedWord") >= 0 or FileAccess.get_file_as_string("res://sim/bot.gd").find("carry_take") >= 0:
		_bad("bot takes notes")
		return false
	for path in ["res://sim/carried_word.gd", "res://ui/network_view.gd", "res://ui/observer_panel.gd", "res://ui/station.gd", "res://sim/game.gd"]:
		var body := FileAccess.get_file_as_string(path)
		if body.find("closed_bonus") >= 0 or body.find("kept_bonus") >= 0:
			_bad("bonus wired in " + path)
			return false
	var logic := FileAccess.get_file_as_string("res://sim/carried_word.gd")
	if logic.find("regulars") >= 0:
		_bad("carry reads regulars by name")
		return false
	for token in ["stock.", "hope ", "discontent", "opinions", "loyalty", "fragments", "rng."]:
		if logic.find(token) >= 0:
			_bad("carry touches " + token)
			return false
	var yard := FileAccess.get_file_as_string("res://ui/station.gd")
	var yard_fn := _fn(yard, "_show_carry_yard")
	if yard_fn.find("_tip_plate_style") < 0 or yard_fn.find("outline_size\", 0") < 0:
		_bad("yard float plate")
		return false
	var map_fn := _fn(view, "_show_carry_float")
	if map_fn.find("_bind_float_plate") < 0:
		_bad("map float plate")
		return false
	var toast := _fn(yard, "_undo_toast")
	if toast.find("tween_interval(8.0)") < 0 or toast.find("_tip_plate_style") < 0 or toast.find("outline_size\", 0") < 0:
		_bad("undo toast")
		return false
	if toast.find("AUTOWRAP_OFF") < 0 or toast.find("AUTOWRAP_WORD_SMART") >= 0:
		_bad("undo toast wraps into a column")
		return false
	if yard.find("_dismiss_undo_toast") < 0:
		_bad("escape undo")
		return false
	var night := FileAccess.get_file_as_string("res://sim/night_runs.gd")
	var dawn := _fn(night, "dawn")
	if dawn.find("CarriedWord.on_night_run") < 0:
		_bad("dawn missing the run hook")
		return false
	return true


## Open confirm must be a short horizontal YA1 plate in EN and RU, not a letter stack.
func _undo_plate() -> bool:
	var packed := load("res://ui/station.tscn") as PackedScene
	if packed == null:
		_bad("station scene")
		return false
	var station = packed.instantiate()
	root.add_child(station)
	await process_frame
	await process_frame
	var samples := [
		["en", "Once it's open, it stays open."],
		["ru", "Что вскрыто, то вскрыто."],
	]
	var ok := true
	for sample in samples:
		Copy.set_lang(str(sample[0]))
		station.showing_network = false
		station._undo_toast(Copy.t("carry.open_confirm"), func() -> void: pass, func() -> void: pass)
		await process_frame
		await process_frame
		var plate: PanelContainer = station.undo_toast
		if plate == null or not is_instance_valid(plate):
			_bad("undo plate missing " + str(sample[0]))
			ok = false
			break
		var plate_size := plate.size
		if plate_size.x < 8.0:
			plate_size = plate.get_combined_minimum_size()
		var row := plate.get_child(0)
		var lab := row.get_child(0) as Label
		var button := row.get_child(1) as Button
		if lab == null or button == null:
			_bad("undo row " + str(sample[0]))
			ok = false
			break
		var line_size := lab.size
		if line_size.x < 8.0:
			line_size = lab.get_combined_minimum_size()
		if lab.text != str(sample[1]):
			_bad("undo copy %s [%s]" % [str(sample[0]), lab.text])
			ok = false
			break
		if lab.autowrap_mode != TextServer.AUTOWRAP_OFF or lab.get_line_count() != 1:
			_bad("undo wrap %s lines %d" % [str(sample[0]), lab.get_line_count()])
			ok = false
			break
		if plate_size.y > 160.0 or plate_size.x < plate_size.y or plate_size.x < 280.0:
			_bad("undo plate %s %s" % [str(sample[0]), str(plate_size)])
			ok = false
			break
		if line_size.x < line_size.y * 3.0:
			_bad("undo line %s %s" % [str(sample[0]), str(line_size)])
			ok = false
			break
		if button.global_position.x < lab.global_position.x + 40.0:
			_bad("undo button not beside the line")
			ok = false
			break
		station._hide_undo_toast()
	Copy.set_lang("en")
	if is_instance_valid(station):
		station.free()
	return ok


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
	_pair(game, "brickworks", "quarry")
	_touch(game, "riverside", 60)
	_touch(game, "mill", 20)
	var host := Host.new()
	host.game = game
	host.body_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	host.display_font = load("res://assets/fonts/Oswald.ttf")
	root.add_child(host)
	var view := NetworkView.new()
	host.network_view = view
	view.host = host
	view.size = Vector2(1280, 720)
	view.visible = true
	root.add_child(view)
	await process_frame
	view.open_visit("brickworks")
	await process_frame
	await process_frame
	var row := _meta(view, "face_row")
	if row == null or int(row.get_meta("face_slot")) != 1 or str(row.get_meta("face_key")) != "carry.lamp_copper.offer":
		_bad("CW-U5 face row")
		return false
	var button := _meta(view, "carry_button")
	if button == null or button.clip_text or int(button.get_theme_font_size("font_size")) != 20:
		_bad("CW-N1 button")
		return false
	if button.custom_minimum_size.x < 110.0 or button.tooltip_text != Copy.t("carry.tip"):
		_bad("CW-N1 size or tip")
		return false
	if button.mouse_default_cursor_shape != Control.CURSOR_POINTING_HAND:
		_bad("CW-N9 cursor")
		return false
	var hover: StyleBoxFlat = button.get_theme_stylebox("hover")
	var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
	if hover == null or focus == null or hover.get_border_width(SIDE_LEFT) != 1 or focus.get_border_width(SIDE_LEFT) != 1:
		_bad("CW-N1 rim")
		return false
	if not await _fits(view, button):
		return false
	for size in [Vector2(1536, 864), Vector2(1280, 720)]:
		view.size = size
		view._size_visit()
		await process_frame
		await process_frame
		if not await _fits(view, _meta(view, "carry_button")):
			_bad("CW-U6 at %s" % str(size))
			return false
	button = _meta(view, "carry_button")
	button.pressed.emit()
	await process_frame
	if str(game.carry.pocket.get("thread", "")) != "lamp_copper":
		_bad("button take")
		return false
	var plate := _meta(view, "carry_float")
	if plate == null or str(plate.text) != Copy.t("carry.first"):
		_bad("CN1 map float")
		return false
	if int(plate.get_theme_constant("outline_size")) != 0:
		_bad("CN1 outline")
		return false
	var parent := plate.get_parent()
	if parent == null or not bool(parent.get_meta("map_float_plate", false)):
		_bad("CN1 plate")
		return false
	if _meta(view, "carry_button") != null:
		_bad("button stayed")
		return false
	var tip := view._tip("quarry")
	if not tip.ends_with(Copy.t("carry.tip_dest").replace("{to}", "Wren Kowalski")) and tip.find("Wren Kowalski") < 0:
		_bad("tip " + tip)
		return false
	view.open_visit("riverside")
	await process_frame
	if _meta(view, "carry_button") != null:
		_bad("CW-U1 button while full")
		return false
	var reason := _meta(view, "carry_reason")
	if reason == null or str(reason.text) != Copy.t("carry.one_only"):
		_bad("CW-U1 reason")
		return false
	if not reason.get_theme_color("font_color").is_equal_approx(NetworkView.MUTED):
		_bad("CN5 muted")
		return false
	Copy.set_lang("ru")
	view.open_visit("riverside")
	await process_frame
	reason = _meta(view, "carry_reason")
	if reason == null or str(reason.text) != "Карман уже занят.":
		_bad("ru reason")
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var panel := ObserverPanel.new()
	host.add_child(panel)
	panel.present(host)
	await process_frame
	if _meta(panel, "pocket_fold") == null or _meta(panel, "pocket_line") == null:
		_bad("pocket fold")
		return false
	var open_btn := _pocket_button(panel, "carry.open")
	if open_btn == null or open_btn.custom_minimum_size.x < 110.0 or int(open_btn.get_theme_font_size("font_size")) != 20 or open_btn.clip_text:
		_bad("open button")
		return false
	open_btn.pressed.emit()
	await process_frame
	if _meta(panel, "pocket_text") != null or host.toast_text != Copy.t("carry.open_confirm"):
		_bad("CW-U2 text during toast")
		return false
	if not host._dismiss_undo_toast():
		_bad("escape")
		return false
	await process_frame
	if bool(game.carry.pocket.get("opened", false)) or _meta(panel, "pocket_text") != null:
		_bad("CW-U2 escape opened")
		return false
	open_btn = _pocket_button(panel, "carry.open")
	if open_btn == null:
		_bad("open returned")
		return false
	open_btn.pressed.emit()
	await process_frame
	if not host.toast_commit.is_valid():
		_bad("commit missing")
		return false
	host.toast_commit.call()
	await process_frame
	var written := _meta(panel, "pocket_text")
	if written == null:
		_bad("CW-U2 text after lapse")
		return false
	var inner := _label_child(written)
	if inner == null or inner.clip_text or str(inner.text) != Copy.t("carry.lamp_copper.read"):
		_bad("CW-N2 text")
		return false
	var paper: StyleBoxFlat = written.get_theme_stylebox("panel")
	if paper == null or not paper.bg_color.is_equal_approx(ObserverPanel.PAPER_BUTTON):
		_bad("CW-N2 paper")
		return false
	Copy.set_lang("ru")
	CarriedWord.commit_open(game)
	game.carry.pocket.thread = "last_page"
	game.carry.pocket.opened = true
	panel.present(host)
	await process_frame
	await process_frame
	written = _meta(panel, "pocket_text")
	inner = _label_child(written) if written != null else null
	if inner == null or inner.clip_text or inner.text.length() < 100:
		_bad("CW-U6 ru clip")
		Copy.set_lang("en")
		return false
	if inner.get_combined_minimum_size().y < 28.0:
		_bad("CW-U6 ru height")
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var scroll := _meta(panel, "obs_tail_scroll")
	if scroll == null or not (scroll is ScrollContainer):
		_bad("CN4 scroll")
		return false
	game.carry.threads = {"lamp_copper": "closed", "water_air": "opened"}
	game.carry.delivered = 3
	game.carry.pocket = {}
	panel.present(host)
	await process_frame
	var count := _meta(panel, "pocket_count")
	if count == null or str(count.text) != Copy.fill("carry.count", {"n": 3}):
		_bad("tally " + (str(count.text) if count != null else "missing"))
		return false
	var shut := _meta(panel, "pocket_closed")
	var shown := _meta(panel, "pocket_opened")
	if shut == null or shown == null or not shown.get_theme_color("font_color").is_equal_approx(ObserverPanel.PAPER_MUTED):
		_bad("CW-N4 tally")
		return false
	if _meta(panel, "pocket_empty") == null:
		_bad("empty line")
		return false
	forced_ui(game, panel, host)
	await process_frame
	if _meta(panel, "pocket_none") == null:
		_bad("CW-N5 no one")
		return false
	if CarriedWord.tip_line(game, "quarry") != "" or view._tip("quarry").find("You carry a note") >= 0:
		_bad("CW-N5 tip")
		return false
	return true


func forced_ui(game: Game, panel: ObserverPanel, host: Host) -> void:
	game.carry.threads = {}
	game.carry.pocket = {}
	game.carry.lines = []
	_pair(game, "brickworks", "quarry")
	CarriedWord.take(game, "brickworks")
	game._capture("quarry", game.player, true)
	panel.present(host)


func _fits(view: NetworkView, button: Button) -> bool:
	if button == null:
		_bad("CW-U6 missing button")
		return false
	var quote := _meta(view, "face_line") as Control
	if quote == null:
		_bad("CW-U6 missing line")
		return false
	await process_frame
	var brow: Rect2 = button.get_global_rect()
	var qrow: Rect2 = quote.get_global_rect()
	if brow.size.x < 8.0 or qrow.size.x < 8.0:
		_bad("CW-U6 zero rect")
		return false
	if brow.intersects(qrow):
		_bad("CW-U6 overlap")
		return false
	var body := view._visit_body as Control
	if body != null:
		var limit: Rect2 = body.get_global_rect()
		if brow.end.x > limit.end.x + 4.0:
			_bad("CW-U6 clipped x")
			return false
	return true


func _pocket_button(node: Node, key: String) -> Button:
	if node is Button and str(node.get_meta("pocket_button", "")) == key:
		return node
	for child in node.get_children():
		var found := _pocket_button(child, key)
		if found != null:
			return found
	return null


func _label_child(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found := _label_child(child)
		if found != null:
			return found
	return null


func _meta(node: Node, key: String) -> Node:
	if node is Control and node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _meta(child, key)
		if found != null:
			return found
	return null


func _careful(catalog: Catalog) -> bool:
	if MASTER_HASH.size() != 60:
		_bad("baseline")
		return false
	var lost := 0
	var matched := 0
	var lost_seeds := PackedStringArray()
	for run_seed in range(1, 61):
		CarriedWord.enabled = true
		var on := _play(catalog, run_seed)
		CarriedWord.enabled = false
		var off := _play(catalog, run_seed)
		if str(on.report) != str(off.report) or str(on.rng) != str(off.rng):
			_bad("seed %d on/off diverged" % run_seed)
			return false
		if int(on.notes) != 0 or int(off.notes) != 0:
			_bad("seed %d held a note" % run_seed)
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
	CarriedWord.enabled = true
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
	var report: Dictionary = game.report()
	return {
		"over": str(game.over),
		"hash": _outcome_hash(game),
		"report": str(report.get("summary", "")),
		"rng": "%d|%d|%d|%d|%d" % [int(game.rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state), int(game.crunch_rng.state)],
		"notes": 0 if game.carry.pocket.is_empty() else 1,
	}


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
