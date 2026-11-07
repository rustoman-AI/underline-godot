extends SceneTree

## P87 Marks & Kit gate.
##   godot --headless --path . -s res://sim/check_marks_kit.gd
## Balance ZERO. Soft dawn none. Schema 18. Careful seeds 1–60 match master.

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

var _failed := false


class Host extends Node:
	var game
	var showing_network := false
	func _motion_off() -> bool:
		return true
	func _ui_click() -> void:
		pass
	func _undo_toast(_text: String, _undo: Callable) -> void:
		pass
	func _hide_undo_toast() -> void:
		pass
	func _close_observer() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("MARKS KIT FAIL catalog")
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if Game.SAVE_SCHEMA != 25:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
	var game := Game.new()
	if game.obs_dawn_chip() or game.marks_kit_dawn_chip() or MarksKit.joins_soft_dawn():
		_bad("obs dawn chip")
	if not _strings():
		_failed = true
	else:
		print("Strings: ok")
	if not _art():
		_failed = true
	else:
		print("Art: ok")
	if not _schema(catalog):
		_failed = true
	else:
		print("Schema: ok")
	if not _triggers(catalog):
		_failed = true
	else:
		print("Triggers: ok")
	if not _lines(catalog):
		_failed = true
	else:
		print("Lines: ok")
	if not _dawn(catalog):
		_failed = true
	else:
		print("Dawn: ok")
	if not _swap(catalog):
		_failed = true
	else:
		print("Swap: ok")
	if not await _ux(catalog):
		_failed = true
	else:
		print("UX: ok")
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("balance.json changed")
	if _failed:
		print("MARKS KIT FAIL")
		quit(1)
		return
	if not _careful(catalog):
		print("MARKS KIT FAIL")
		quit(1)
		return
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("MARKS KIT FAIL")
		print("FAIL balance.json changed during careful")
		quit(1)
		return
	print("MARKS KIT OK")
	quit(0)


func _bad(msg: String) -> void:
	_failed = true
	print("FAIL " + msg)


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/marks_kit.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P87":
		_bad("pack roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("pack soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	if rows.size() != 109:
		_bad("key count %d" % rows.size())
		return false
	var frag = JSON.parse_string(FileAccess.get_file_as_string("res://data/marks_kit_ru_fragment.json"))
	if not (frag is Dictionary) or frag.size() != 109:
		_bad("ru fragment %s" % str(frag.size() if frag is Dictionary else "bad"))
		return false
	for key in rows:
		if not str(key).begins_with("obs."):
			_bad("namespace " + str(key))
			return false
		if str(key).begins_with("observer."):
			_bad("observer key")
			return false
		var row: Dictionary = rows[key]
		if str(row.get("en", "")) == "" or str(row.get("ru", "")) == "":
			_bad("empty " + str(key))
			return false
		if str(row.get("ru", "")) != str(frag.get(key, "")):
			_bad("ru drift " + str(key))
			return false
		var blob := str(row.en) + " " + str(row.ru)
		if blob.to_lower().find("gear") >= 0 or blob.find("снаряж") >= 0:
			_bad("gear in " + str(key))
			return false
	Copy.set_lang("ru")
	if Copy.t("obs.ink.queued_after") != "Набьют через рассвет":
		_bad("queued_after ru")
		return false
	Copy.set_lang("en")
	if Copy.t("obs.ink.queued") != "Inks at next dawn":
		_bad("queued en")
		return false
	for path in ["res://sim/marks_kit.gd", "res://ui/observer_panel.gd", "res://ui/obs_glyph.gd", "res://data/obs.json"]:
		var src := FileAccess.get_file_as_string(path)
		if src.find("observer.") >= 0 or src.to_lower().find("gear") >= 0:
			_bad("gear or observer in " + path)
			return false
	return true


func _art() -> bool:
	var n := 0
	var dir := DirAccess.open("res://assets/icons/status")
	if dir == null:
		_bad("status dir")
		return false
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("obs_") and name.ends_with(".png"):
			n += 1
		name = dir.get_next()
	if n < 54:
		_bad("icon count %d" % n)
		return false
	if not FileAccess.file_exists("res://assets/portraits/obs_silhouette.png"):
		_bad("bust missing")
		return false
	var tex := ObsGlyph.texture("mark", "missing_mark", 16)
	if tex == null:
		_bad("fallback texture")
		return false
	return true


func _schema(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 10)
	game.obs.marks = ["ash_hand"]
	game.obs.offered = ["word_knot"]
	var data := game.export_state()
	data["schema"] = 18
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data):
		_bad("schema 18 load " + again.load_error)
		return false
	if again.obs.marks != ["ash_hand"] or again.obs.offered != ["word_knot"]:
		_bad("round trip lost obs")
		return false
	data.erase("obs")
	data["schema"] = 17
	var old := Game.new()
	old.catalog = catalog
	if not old.import_state(data):
		_bad("schema 17 migrate " + old.load_error)
		return false
	if not old.obs.marks.is_empty() or not old.obs.kit_owned.is_empty():
		_bad("schema 17 was not empty")
		return false
	return true


func _triggers(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	for _i in 3:
		MarksKit.note_bury(game)
	if MarksKit.state_of_mark(game, "ash_hand") != "offered":
		_bad("ash hand not offered")
		return false
	if str(game.obs.earned.ash_hand.get("what", "")) != "obs.what.ash_hand":
		_bad("earned what")
		return false
	MarksKit.note_charge_done(game)
	MarksKit.note_blown(game)
	MarksKit.note_raid(game, "dockyard")
	game.obs.deeds.guests = 5
	MarksKit.note_arrivals(game, {"id": "refugees"}, {"people": 5})
	if not game.obs.offered.has("open_door"):
		_bad("open door")
		return false
	var before: Array = game.obs.offered.duplicate()
	MarksKit.note_bury(game)
	if game.obs.offered != before:
		_bad("trigger repeated")
		return false
	game.obs.marks = ["rail_stitch", "ash_hand", "word_knot"]
	game.obs.offered = []
	game.obs.ink_queue = []
	game.obs.earned.erase("signal_scar")
	game.obs.noroom = []
	game.obs.toast = ""
	MarksKit.note_blown(game)
	if game.obs.noroom.has("signal_scar") and game.obs.dawn_card.is_empty() and str(game.obs.toast).find("Signal") >= 0:
		pass
	else:
		_bad("noroom toast %s" % str(game.obs.toast))
		return false
	if not game.obs.ink_queue.is_empty():
		_bad("noroom queued a card")
		return false
	var warm := _fresh(catalog)
	MarksKit.note_sympathy(warm, "dockyard", 40, 55)
	if not warm.obs.gift_queue.has("oilskin"):
		_bad("warm gift")
		return false
	MarksKit.note_capture(warm, "dockyard", true)
	if warm.obs.gift_queue.has("oilskin") or not warm.obs.kit_lost.has("oilskin"):
		_bad("force capture still gifts")
		return false
	var lost := _fresh(catalog)
	MarksKit.note_capture(lost, "central", true)
	MarksKit.note_sympathy(lost, "central", 10, 80)
	if lost.obs.gift_queue.has("free_mask"):
		_bad("lost station warmed into a gift")
		return false
	var peace := _fresh(catalog)
	MarksKit.note_capture(peace, "eastwater", false)
	if not peace.obs.gift_queue.has("filter_hood"):
		_bad("peaceful join")
		return false
	MarksKit.note_strip(peace)
	MarksKit.note_junk(peace)
	if peace.obs.gift_queue.count("linesman_vest") != 1:
		_bad("vest once")
		return false
	MarksKit.note_night(peace, {"id": "signal_outer", "station": "signal"}, [])
	if not peace.obs.gift_queue.has("headset") or not peace.obs.gift_queue.has("whistle"):
		_bad("signal find %s" % str(peace.obs.gift_queue))
		return false
	var deaths := _fresh(catalog)
	MarksKit.note_night(deaths, {"id": "signal_outer", "station": "signal"}, ["p1"])
	if deaths.obs.gift_queue.has("whistle") or not deaths.obs.gift_queue.has("headset"):
		_bad("dirty run whistle")
		return false
	return true


func _lines(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	game.obs.marks = ["rail_stitch", "raid_tally"]
	game.obs.kit_worn.coat = "oilskin"
	var rumble := _event(catalog, "rumble")
	if rumble.is_empty():
		_bad("rumble missing")
		return false
	MarksKit.decorate(game, rumble)
	var obs := _obs_choices(rumble)
	if obs.size() != 1:
		_bad("rumble lines %d" % obs.size())
		return false
	var mirror := {}
	for choice in rumble.choices:
		if str(choice.get("id", "")) == str(obs[0].get("mirror", "")):
			mirror = choice
	if not MarksKit.effect_same(obs[0], mirror):
		_bad("mirror drift")
		return false
	var cold := _event(catalog, "cold_rail")
	MarksKit.decorate(game, cold)
	var both := _obs_choices(cold)
	if both.size() != 1 or str(both[0].get("obs_kind", "")) != "mark":
		_bad("mark did not beat kit")
		return false
	for banned in ["two_portions", "breathers_price", "the_list"]:
		var ev := _event(catalog, banned)
		if ev.is_empty():
			continue
		var before: int = int(ev.choices.size())
		MarksKit.decorate(game, ev)
		if _obs_choices(ev).size() != 0 or ev.choices.size() != before:
			_bad("line on " + banned)
			return false
	var bare := _fresh(catalog)
	var wire := _event(catalog, "wire")
	MarksKit.decorate(bare, wire)
	if not _obs_choices(wire).is_empty():
		_bad("unmet line attached")
		return false
	game.obs.marks = ["signal_scar"]
	MarksKit.decorate(game, wire)
	if _obs_choices(wire).size() != 1:
		_bad("scar line missing")
		return false
	var hidden: Dictionary = _obs_choices(wire)[0]
	bare.obs = game.obs.duplicate(true)
	if not game.choice_offered(hidden):
		_bad("met line hidden")
		return false
	bare.obs.marks = []
	if bare.choice_offered(hidden):
		_bad("unmet line offered")
		return false
	var bot := Bot.new()
	if bot._open(game, hidden):
		_bad("bot picked an obs line")
		return false
	return true


func _dawn(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	game.week = 4
	MarksKit.note_charge_done(game)
	MarksKit.note_blown(game)
	if game.obs.ink_queue.size() < 2:
		_bad("queue %s" % str(game.obs.ink_queue))
		return false
	if MarksKit.ink_button_key(game, str(game.obs.ink_queue[0])) != "obs.ink.queued":
		_bad("front key")
		return false
	if MarksKit.ink_button_key(game, str(game.obs.ink_queue[1])) != "obs.ink.queued_after":
		_bad("behind key")
		return false
	MarksKit.prepare_dawn(game)
	if not MarksKit.has_card(game) or str(game.obs.dawn_card.get("kind", "")) != "ink":
		_bad("ink card")
		return false
	if str(game.obs.dawn_card.get("id", "")) != str(game.obs.ink_queue[0]):
		_bad("ink card was not the oldest")
		return false
	game.pending.push_front({"id": "burial_x", "burial_id": "p", "choices": []})
	if MarksKit.show_card_now(game):
		_bad("obs card jumped the burial")
		return false
	game.pending.clear()
	if not MarksKit.show_card_now(game):
		_bad("obs card did not lead")
		return false
	if MarksKit.slots_after_ink(game) != 2:
		_bad("slots %d" % MarksKit.slots_after_ink(game))
		return false
	MarksKit.resolve_ink(game, false)
	if MarksKit.has_card(game) or game.obs.card_week != 4:
		_bad("not yet")
		return false
	if not game.obs.offered.has(str(game.obs.declined[0])):
		_bad("not yet dropped the offer")
		return false
	game.week = 5
	MarksKit.queue_ink(game, str(game.obs.declined[0]))
	MarksKit.prepare_dawn(game)
	MarksKit.resolve_ink(game, true)
	if game.obs.marks.size() != 1 or game.obs.float_mark != true:
		_bad("first ink")
		return false
	if bool(game.flags.get("seen_obs_marks", false)):
		_bad("flag set before the float")
		return false
	var gift := _fresh(catalog)
	gift.week = 6
	MarksKit.note_sympathy(gift, "brickworks", 20, 60)
	MarksKit.prepare_dawn(gift)
	if str(gift.obs.dawn_card.get("kind", "")) != "gift":
		_bad("gift card %s" % str(gift.obs.dawn_card))
		return false
	MarksKit.resolve_gift(gift)
	if not gift.obs.kit_owned.has("carbide") or not gift.obs.float_kit:
		_bad("take gift")
		return false
	var find := _fresh(catalog)
	find.week = 2
	MarksKit.note_strip(find)
	MarksKit.prepare_dawn(find)
	if str(find.obs.dawn_card.get("kind", "")) != "find":
		_bad("find card")
		return false
	return true


func _swap(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	game.obs.kit_owned = ["oilskin", "barrel_quilt"]
	var beat: Dictionary = MarksKit.swap(game, "coat", "oilskin")
	if str(game.obs.kit_worn.coat) != "oilskin" or str(beat.get("toast", "")) == "":
		_bad("wear")
		return false
	if not MarksKit.undo_swap(game) or str(game.obs.kit_worn.coat) != "":
		_bad("undo")
		return false
	MarksKit.swap(game, "coat", "oilskin")
	game.obs_ui_block = true
	if game.obs_can_swap() or not MarksKit.swap(game, "coat", "barrel_quilt").is_empty():
		_bad("swap while blocked")
		return false
	if MarksKit.undo_swap(game):
		_bad("undo while blocked")
		return false
	game.obs_ui_block = false
	MarksKit.swap(game, "coat", "")
	if str(game.obs.kit_worn.coat) != "":
		_bad("take off")
		return false
	return true


func _ux(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	game.obs.kit_owned = ["oilskin"]
	game.obs_ui_block = true
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var panel := ObserverPanel.new()
	host.add_child(panel)
	panel.present(host)
	await process_frame
	await process_frame
	var blocked := _find_blocked(panel)
	if blocked == null:
		_bad("blocked swap button missing")
		return false
	if not blocked.disabled or blocked.mouse_filter != Control.MOUSE_FILTER_STOP or blocked.focus_mode == Control.FOCUS_NONE:
		_bad("blocked swap not focusable")
		return false
	if blocked.tooltip_text != Copy.t("obs.swap_blocked"):
		_bad("swap tip " + blocked.tooltip_text)
		return false
	if panel.get_node_or_null("") != null:
		pass
	var scroll := _find_type(panel, "ScrollContainer")
	if scroll == null:
		_bad("detail does not scroll")
		return false
	panel.queue_free()
	host.queue_free()
	return true


func _find_blocked(node: Node) -> Button:
	if node is Button and bool(node.get_meta("obs_swap", false)) and node.disabled:
		return node
	for child in node.get_children():
		var found := _find_blocked(child)
		if found != null:
			return found
	return null


func _find_type(node: Node, kind: String) -> Node:
	if node.get_class() == kind:
		return node
	for child in node.get_children():
		var found := _find_type(child, kind)
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
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		game.audit = false
		game.raid_share_profile = "careful"
		var bot := Bot.new()
		bot.profile = "careful"
		var guard := 0
		while game.over == "" and guard < 42:
			guard += 1
			bot._act(game)
			game.end_week()
		var got := _outcome_hash(game)
		var want := int(MASTER_HASH[run_seed - 1])
		if got == want:
			matched += 1
		else:
			_bad("seed %d hash %d master %d" % [run_seed, got, want])
		if str(game.over) != "time":
			lost += 1
			lost_seeds.append(str(run_seed))
		print("Seed %d: %d %s %s" % [run_seed, got, str(game.over), "match" if got == want else "DIFF"])
	print("Careful loss: %d/60 (master %d/60) seeds %s" % [lost, BASELINE_LOST, ",".join(lost_seeds)])
	print("Seed outcomes: %d/60 match master" % matched)
	if lost != BASELINE_LOST or ",".join(lost_seeds) != LOST_SEEDS:
		_bad("careful loss moved")
		return false
	return matched == 60 and not _failed


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


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 12)
	return game


func _event(catalog: Catalog, id: String) -> Dictionary:
	for ev in catalog.events:
		if str(ev.get("id", "")) == id:
			return ev.duplicate(true)
	return {}


func _obs_choices(ev: Dictionary) -> Array:
	var out: Array = []
	for choice in ev.get("choices", []):
		if bool(choice.get("obs_line", false)):
			out.append(choice)
	return out
