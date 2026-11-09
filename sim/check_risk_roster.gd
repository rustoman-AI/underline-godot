extends SceneTree

## P99 Risk Roster. UI selection over the five existing checks. Not a balance change.
##   godot --headless --path . -s res://sim/check_risk_roster.gd
## A windowed run also writes EN/RU 100 and EN 125 before/after stills.
## Headless prints RISK ROSTER SHOTS SKIP.

const EVENTS := ["queens_expedition", "garden_mold", "moles_vents", "generator_sabotage", "showtime_betting"]
const EN := {
	"checkpick.open": "Compare people",
	"checkpick.title": "Who takes the check?",
	"checkpick.current": "Current choice",
	"checkpick.use": "Use {name}",
	"checkpick.back": "Back without changing",
	"checkpick.empty": "No one in the current selection list.",
	"checkpick.changed": "The people or choice changed. Compare again.",
	"checkpick.preview_only": "Choosing a name does not roll or move them.",
	"checkpick.injury": "This option can put the selected resident out of work.",
	"checkpick.work": "Current room: {room}",
	"checkpick.no_room": "No room assignment",
	"checkpick.shared": "Shared modifiers",
	"checkpick.more": "More people below",
	"checkpick.no_extra_cost": "Selecting a name adds no cost. The action's cost is unchanged.",
}

var bad: PackedStringArray = []
var st = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_wipe(ProjectSettings.globalize_path("user://check_risk_roster"))
	Settings.path = "user://check_risk_roster/settings.cfg"
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.intro_seen = true
	Settings.hints_on = false
	Settings.reduce_motion = true
	Settings.ui_scale_auto = false
	Settings.ui_scale = 1.0
	SaveGame.root = "user://check_risk_roster/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = "user://check_risk_roster/log"
	Copy.set_lang("en")
	_copy_keys()
	_dice()
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 6:
		await process_frame
	st._close_card()
	if st.dim != null:
		st.dim.visible = false
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	st.guide_played = true
	if st.guide_layer != null:
		st.guide_layer.visible = false
	_schema()
	_bands_and_dice()
	_five_cards()
	_membership()
	_rows_and_room()
	_select_back_escape()
	_stale()
	_no_stamp()
	_injury()
	_mirrors()
	_out_of_scope()
	_locale()
	_browse_then_apply()
	_receipt_from_compare()
	await _shots()
	_wipe(ProjectSettings.globalize_path("user://check_risk_roster"))
	if is_instance_valid(st):
		st.free()
	if bad.is_empty():
		print("RISK ROSTER OK")
		quit(0)
		return
	for line in bad:
		print("FAIL " + line)
	print("RISK ROSTER FAILED")
	quit(1)


func _bad(msg: String) -> void:
	bad.append(msg)
	print("FAIL " + msg)


func _copy_keys() -> void:
	for key in EN:
		if not Copy.keys.has(key):
			_bad("missing key " + key)
			continue
		var row: Dictionary = Copy.keys[key]
		if str(row.get("en", "")) != str(EN[key]):
			_bad("en %s %s" % [key, str(row.get("en", ""))])
		if str(row.get("ru", "")) != "":
			_bad("ru filled " + key)


func _schema() -> void:
	if Game.SAVE_SCHEMA != 27:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
	var data: Dictionary = st.game.export_state()
	for key in data:
		if str(key).begins_with("checkpick"):
			_bad("saved " + str(key))
	if data.has("check_picks"):
		_bad("picks saved")
	if not data.has("shiftword_state") or not data.has("receipt_seq"):
		_bad("master save fields missing")


func _dice() -> void:
	var game := Game.new()
	var catalog := Catalog.new()
	if not catalog.load_all():
		_bad("catalog")
		return
	game.setup(catalog, 1, 8)
	if game._check_chance_bonus(4, 10, "white") != 72:
		_bad("bonus4 %s" % str(game._check_chance_bonus(4, 10, "white")))
	if game._check_chance_bonus(1, 10, "white") != 28:
		_bad("bonus1 %s" % str(game._check_chance_bonus(1, 10, "white")))
	if not game._check_hits(6, 6, 0, 99, "red"):
		_bad("box")
	if game._check_hits(1, 1, 99, 0, "white"):
		_bad("snake")
	if not game._check_hits(4, 2, 4, 10, "red"):
		_bad("red high")
	if game._check_hits(2, 4, 4, 10, "red"):
		_bad("red low")
	if game._check_hits(3, 3, 4, 10, "red"):
		_bad("red tie")
	if not game._check_hits(3, 3, 4, 10, "white"):
		_bad("white tie")
	for color in ["white", "red"]:
		for bonus in range(0, 8):
			for diff in [8, 9, 10]:
				var ok := 0
				for a in 6:
					for b in 6:
						if game._check_hits(a + 1, b + 1, bonus, diff, color):
							ok += 1
				var got: int = game._check_chance_bonus(bonus, diff, color)
				if got != int(round(float(ok) * 100.0 / 36.0)):
					_bad("pairs %s %d %d" % [color, bonus, diff])
	var raw := {"fail": {"effects": {"injured": 4}}, "success": {"text": "no"}}
	if game.check_injures_actor(raw):
		_bad("raw effects counted")
	if not game.check_injures_actor({"success": {}, "failure": {"injured": 1}}):
		_bad("runtime injury missed")
	if game.check_injures_actor({"success": {"injured": 0}, "failure": {"sick": 2, "residents_lost": 1}}):
		_bad("sick counted as injury")
	if not game.check_injures_actor({"success": {"injured": 2}, "failure": {}}):
		_bad("success injury missed")


func _bands_and_dice() -> void:
	if st._check_band_word(72) != "Likely" or st._check_band_word(60) != "Likely":
		_bad("likely")
	if st._check_band_word(59) != "Uncertain" or st._check_band_word(40) != "Uncertain":
		_bad("uncertain")
	if st._check_band_word(39) != "Unlikely" or st._check_band_word(28) != "Unlikely":
		_bad("unlikely")


func _offer(id: String, week: int) -> void:
	st.game.week = week
	st.game.pending.clear()
	st.game.week_event_ids = {}
	st.check_picks = {}
	st._checkpick_clear()
	st.event_mode = "all"
	if not st.game._present_event(st.game._event_by_id(id)):
		_bad("offer " + id)
		return
	st._show_dawn()


func _five_cards() -> void:
	for id in EVENTS:
		_offer(id, 1)
		var front: Dictionary = st.game.front_event()
		var red := 0
		var white := 0
		for choice in front.choices:
			if not choice.has("check"):
				continue
			if str(choice.get("check", {}).get("color", "")) == "red":
				red += 1
				if st._checkpick_scoped(front, choice) and st.game.choice_offered(choice):
					_bad("red offered early " + id)
			else:
				white += 1
		if white < 1 or red < 1:
			_bad("pair %s %d %d" % [id, white, red])
		var opens := _roles(st.card_body, "open")
		if opens.size() != white:
			_bad("week1 opens %s %d" % [id, opens.size()])
		if _blob(st.card_body).find("%") >= 0 and id == "moles_vents":
			_bad("percent on card")
		_offer(id, 8)
		front = st.game.front_event()
		var offered := 0
		for choice in front.choices:
			if choice.has("check") and st.game.choice_offered(choice) and not st.game.choice_locked(choice):
				offered += 1
				if not st._checkpick_scoped(front, choice):
					_bad("unscoped " + id)
		if _roles(st.card_body, "open").size() != offered:
			_bad("week8 opens %s %d" % [id, _roles(st.card_body, "open").size()])
	_offer("showtime_betting", 8)
	var bet := {}
	for choice in st.game.front_event().choices:
		if str(choice.get("id", "")) == "bet":
			bet = choice
	if bet.is_empty() or not bet.has("check") or bet.has("bet"):
		_bad("showtime bet schema")
	elif not st._checkpick_scoped(st.game.front_event(), bet):
		_bad("showtime bet out")


func _membership() -> void:
	_offer("moles_vents", 8)
	var game = st.game
	var child := {
		"id": "kid_p99",
		"name": "Small Wren",
		"name_ru": "Маленький Крапивник Длинное Имя",
		"child": true,
		"child_left": 5,
		"sick": 0,
		"absent": 0,
		"skills": {"labor": 1, "tech": 1, "care": 1, "talk": 1, "fight": 1},
		"traits": [],
		"checks": {"grit": 3, "wits": 3, "voice": 3, "senses": 3},
	}
	game.people[child.id] = child
	game.residents.append(child)
	var sick_id := ""
	for person in game.residents:
		var pid := str(person.get("id", ""))
		if pid == "kid_p99" or game._is_council(pid):
			continue
		if int(person.get("sick", 0)) <= 0 and int(person.get("absent", 0)) <= 0:
			sick_id = pid
			break
	game.people[sick_id].sick = 2
	var manual: Array = []
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		manual.append(str(person.id))
	var roster: Array = st._check_roster()
	if roster != manual:
		_bad("roster order")
	if not roster.has("kid_p99"):
		_bad("child dropped")
	if roster.has(sick_id):
		_bad("sick kept")
	if game.best_check_resident("senses") == "kid_p99":
		_bad("best picked child")
	var council := ""
	for seat in game.council:
		council = str(seat.get("id", ""))
		break
	if council != "" and int(game.people[council].get("sick", 0)) <= 0 and not roster.has(council):
		_bad("council dropped")
	st._paint_dawn()
	var ids: Array = []
	for row in _roles(st.card_body, "row"):
		ids.append(str(row.get_meta("checkpick_id", "")))
	if ids.is_empty():
		_open_first()
		ids.clear()
		for row in _roles(st.card_body, "row"):
			ids.append(str(row.get_meta("checkpick_id", "")))
	if ids != roster:
		_bad("row order")
	var kid_row = _row("kid_p99")
	if kid_row == null or str(_label_text(kid_row, "skill")).find(Copy.t("Child")) < 0:
		_bad("child label")
	game.people[sick_id].sick = 0
	game.residents.erase(child)
	game.people.erase("kid_p99")


func _rows_and_room() -> void:
	_offer("moles_vents", 8)
	var game = st.game
	var roster: Array = st._check_roster()
	if roster.size() < 2:
		_bad("short roster")
		return
	var room_id := str(roster[0])
	var bare_id := str(roster[1])
	for room in game.rooms:
		var keep: Array = []
		for sid in room.staff:
			if str(sid) != room_id and str(sid) != bare_id:
				keep.append(sid)
		room.staff = keep
	if not game.rooms.is_empty():
		var staff: Array = game.rooms[0].staff.duplicate()
		staff.append(room_id)
		game.rooms[0].staff = staff
	game.dig = {"workers": [bare_id], "left": 2, "level": 0, "cell": 0}
	var key := _check_key("moles_vents", "cut")
	st.check_picks[key] = bare_id
	st._open_checkpick("moles_vents", "cut")
	var room_line := ""
	var bare_line := ""
	for row in _roles(st.card_body, "row"):
		var pid := str(row.get_meta("checkpick_id", ""))
		var text := _label_text(row, "room")
		if pid == room_id:
			room_line = text
		elif pid == bare_id:
			bare_line = text
		if _label_text(row, "skill").find("%") >= 0:
			_bad("percent row")
	var title = st.room_title(game.rooms[0]) if not game.rooms.is_empty() else ""
	if room_line != st._checkpick_fill("checkpick.work", {"room": title}):
		_bad("room line " + room_line)
	if bare_line != "No room assignment":
		_bad("bare room " + bare_line)
	if bare_line.find("Free") >= 0 or bare_line.find("crew") >= 0 or bare_line.find("available") >= 0:
		_bad("false free")
	var shared := _roles(st.card_body, "shared")
	if shared.size() > 1:
		_bad("shared repeated")
	if st.game.check_modifiers("senses").is_empty() and not shared.is_empty():
		_bad("shared invented")
	if _roles(st.card_body, "list").is_empty():
		_bad("no list")
	else:
		var list: Control = _roles(st.card_body, "list")[0]
		var want := float(mini(roster.size(), 6)) * 58.0
		if absf(list.custom_minimum_size.y - want) > 1.0:
			_bad("viewport %s" % str(list.custom_minimum_size.y))
	if roster.size() > 6 and _roles(st.card_body, "more").is_empty():
		_bad("more hidden")
	var highlighted := 0
	for row in _roles(st.card_body, "row"):
		if str(_label_text(row, "skill")).find("Current choice") >= 0:
			highlighted += 1
			if str(row.get_meta("checkpick_id", "")) != bare_id:
				_bad("highlight")
	if highlighted != 1:
		_bad("highlight count %d" % highlighted)


func _select_back_escape() -> void:
	_offer("moles_vents", 8)
	var roster: Array = st._check_roster()
	var key := _check_key("moles_vents", "cut")
	var before: Dictionary = st.game.export_state()
	var rng_before := _rng(st.game)
	var decisions := int(st.game.decisions)
	st.check_picks[key] = str(roster[0])
	st._open_checkpick("moles_vents", "cut")
	if str(st.check_picks.get(key, "")) != str(roster[0]):
		_bad("open cleared pick")
	if JSON.stringify(st.game.export_state()) != JSON.stringify(before):
		_bad("open mutated sim")
	if _rng(st.game) != rng_before:
		_bad("open rng")
	st._back_checkpick()
	if st.checkpick_open != "" or str(st.check_picks.get(key, "")) != str(roster[0]):
		_bad("back changed")
	st._open_checkpick("moles_vents", "cut")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	st._unhandled_key_input(ev)
	if st.checkpick_open != "" or str(st.check_picks.get(key, "")) != str(roster[0]):
		_bad("escape changed")
	var picks := [roster[0], roster[roster.size() / 2], roster[roster.size() - 1]]
	for pid in picks:
		st._open_checkpick("moles_vents", "cut")
		var fp := ""
		var cfp := ""
		for use in _roles(st.card_body, "use"):
			if str(use.get_meta("checkpick_id", "")) == str(pid):
				fp = str(use.get_meta("checkpick_fp", ""))
				cfp = str(use.get_meta("checkpick_choice_fp", ""))
		var snap: Dictionary = st.game.export_state()
		st._use_checkpick("moles_vents", "cut", str(pid), fp, cfp)
		if str(st.check_picks.get(key, "")) != str(pid) or st.checkpick_open != "":
			_bad("use " + str(pid))
		if int(st.game.decisions) != decisions:
			_bad("use paid")
		if JSON.stringify(st.game.export_state()) != JSON.stringify(snap):
			_bad("use mutated " + str(pid))
		if _rng(st.game) != rng_before:
			_bad("use rng")
	if st.game.pending.is_empty() or str(st.game.front_event().get("id", "")) != "moles_vents":
		_bad("use resolved")


func _stale() -> void:
	_offer("garden_mold", 8)
	var roster: Array = st._check_roster()
	var key := _check_key("garden_mold", "order")
	var keep := str(roster[0])
	st.check_picks[key] = keep
	st._open_checkpick("garden_mold", "order")
	var victim := str(roster[1])
	var fp := ""
	var cfp := ""
	for use in _roles(st.card_body, "use"):
		if str(use.get_meta("checkpick_id", "")) == victim:
			fp = str(use.get_meta("checkpick_fp", ""))
			cfp = str(use.get_meta("checkpick_choice_fp", ""))
	st.game.people[victim].sick = 3
	st._use_checkpick("garden_mold", "order", victim, fp, cfp)
	if str(st.check_picks.get(key, "")) != keep:
		_bad("stale wrote " + str(st.check_picks.get(key, "")))
	var notice := _roles(st.card_body, "notice")
	if notice.is_empty() or str(notice[0].text) != str(EN["checkpick.changed"]):
		_bad("changed copy")
	for row in _roles(st.card_body, "row"):
		if str(row.get_meta("checkpick_id", "")) == victim:
			_bad("stale row kept")
	if int(st.game.decisions) != 0:
		_bad("stale paid")
	st.game.people[victim].sick = 0


func _no_stamp() -> void:
	_offer("queens_expedition", 8)
	var game = st.game
	for person in game.residents:
		person.erase("checks")
	var rng_before := _rng(game)
	for person in game.residents:
		var projected: int = game.check_value_projected(person, "grit")
		var copy: Dictionary = person.duplicate(true)
		game._stamp_checks(copy)
		if projected != int(copy.get("checks", {}).get("grit", -1)):
			_bad("projection mismatch")
		game.check_chance_projected(person, "grit", 8, "white")
		if person.has("checks"):
			_bad("projection stamped")
	if _rng(game) != rng_before:
		_bad("projection rng")
	st.check_picks = {}
	st._checkpick_clear()
	st._paint_dawn()
	var stamped := {}
	for person in game.residents:
		if person.has("checks"):
			stamped[str(person.id)] = true
	if stamped.is_empty():
		_bad("preview stamped nobody")
	var rng_mid := _rng(game)
	st._open_checkpick("queens_expedition", "force")
	var stamped_open := {}
	for person in game.residents:
		if person.has("checks"):
			stamped_open[str(person.id)] = true
	if stamped_open != stamped:
		_bad("browse stamped %d" % stamped_open.size())
	if _rng(game) != rng_mid:
		_bad("browse rng")
	for person in game.residents:
		if not person.has("checks"):
			game.check_value(person, "grit")


func _injury() -> void:
	for id in EVENTS:
		_offer(id, 8)
		var front: Dictionary = st.game.front_event()
		for choice in front.choices:
			if not choice.has("check") or not st.game.choice_offered(choice):
				continue
			st._open_checkpick(id, str(choice.get("id", "")))
			var shown := not _roles(st.card_body, "injury").is_empty()
			var want: bool = st.game.check_injures_actor(choice)
			if shown != want:
				_bad("injury %s %s" % [id, str(choice.get("id", ""))])
			if shown and str(_roles(st.card_body, "injury")[0].text) != str(EN["checkpick.injury"]):
				_bad("injury text")
			if _roles(st.card_body, "injury").size() > 1:
				_bad("injury repeated")


func _mirrors() -> void:
	var pack: Dictionary = MarksKit.catalog()
	var hood: Dictionary = pack.get("kit", {}).get("filter_hood", {})
	var saved: Array = hood.get("events", []).duplicate()
	if saved.has("moles_vents"):
		_bad("catalog already hosts moles")
	var file := FileAccess.get_file_as_string("res://data/obs.json")
	if file.find("moles_vents") >= 0:
		_bad("obs.json hosts a check")
	_offer("moles_vents", 8)
	var mirrored := false
	for choice in st.game.front_event().choices:
		if bool(choice.get("obs_line", false)):
			mirrored = true
	if mirrored:
		_bad("mirror without a host")
	var events: Array = saved.duplicate()
	events.append("moles_vents")
	hood.events = events
	MarksKit.boot(st.game).kit_worn.lamp = "filter_hood"
	_offer("moles_vents", 8)
	var mirror := {}
	for choice in st.game.front_event().choices:
		if bool(choice.get("obs_line", false)):
			mirror = choice
	if mirror.is_empty() or not mirror.has("check"):
		_bad("mirror missing")
	elif not st._checkpick_scoped(st.game.front_event(), mirror):
		_bad("mirror unscoped")
	else:
		var opens := _roles(st.card_body, "open")
		var hit := false
		for button in opens:
			if str(button.get_meta("checkpick_key", "")).ends_with(str(mirror.get("id", ""))):
				hit = true
		if not hit:
			_bad("mirror chooser")
		st._open_checkpick("moles_vents", str(mirror.get("id", "")))
		if _roles(st.card_body, "panel").is_empty():
			_bad("mirror panel")
	hood.events = saved
	MarksKit.boot(st.game).kit_worn.lamp = ""
	MarksKit._pack = {}


func _out_of_scope() -> void:
	_offer("two_portions", 8)
	var front: Dictionary = st.game.front_event()
	var pier := {}
	for choice in front.choices:
		if str(choice.get("id", "")) == "pier":
			pier = choice
	if pier.is_empty() or not pier.has("check"):
		_bad("pier missing")
	elif st._checkpick_scoped(front, pier):
		_bad("pier scoped")
	if not _roles(st.card_body, "open").is_empty():
		_bad("pier chooser")
	if _roles(st.card_body, "cycle").is_empty() and st._check_roster().size() > 1:
		_bad("pier cycle missing")
	_offer("moles_vents", 8)
	var ev: Dictionary = st.game.front_event()
	ev.choices.append({
		"id": "sidebet",
		"label": {"en": "Side bet", "ru": "Side bet"},
		"bet": {"target": 7, "win": 2},
	})
	st._paint_dawn()
	for button in _roles(st.card_body, "open"):
		if str(button.get_meta("checkpick_key", "")).ends_with("sidebet"):
			_bad("bet chooser")
	_offer("showtime_betting", 8)
	for choice in st.game.front_event().choices:
		if str(choice.get("id", "")) != "bet":
			continue
		choice.locked = true
		choice.lock_reason = "The roll stands."
	st._paint_dawn()
	for button in _roles(st.card_body, "open"):
		if str(button.get_meta("checkpick_key", "")).ends_with("bet"):
			_bad("locked chooser")
	st.game.stock.tokens = 0
	_offer("showtime_betting", 8)
	var afford := false
	for choice in st.game.front_event().choices:
		if str(choice.get("id", "")) == "bet" and not st.game.afford_choice(choice):
			afford = true
	if not afford:
		_bad("bet still affordable")
	var disabled := false
	for node in _all(st.card_body):
		if node is Button and str(node.get_meta("check_choice_key", "")) == "showtime_betting:bet" and node.disabled:
			disabled = true
	if not disabled:
		_bad("unaffordable enabled")
	st._open_checkpick("showtime_betting", "bet")
	var roster: Array = st._check_roster()
	if roster.size() > 1:
		var use = _roles(st.card_body, "use")[0]
		st._use_checkpick("showtime_betting", "bet", str(use.get_meta("checkpick_id", "")), str(use.get_meta("checkpick_fp", "")), str(use.get_meta("checkpick_choice_fp", "")))
	for node in _all(st.card_body):
		if node is Button and str(node.get_meta("check_choice_key", "")) == "showtime_betting:bet" and not node.disabled:
			_bad("select unlocked cost")
	if int(st.game.stock.tokens) != 0 or int(st.game.decisions) != 0:
		_bad("select spent")


func _locale() -> void:
	_offer("moles_vents", 8)
	Copy.set_lang("ru")
	st._checkpick_clear()
	st._paint_dawn()
	if not _roles(st.card_body, "open").is_empty():
		_bad("ru chooser")
	if _roles(st.card_body, "cycle").is_empty():
		_bad("ru cycle missing")
	else:
		var cycle: Button = _roles(st.card_body, "cycle")[0]
		if cycle.text != Copy.t("Someone else") or cycle.text.find("checkpick.") >= 0:
			_bad("ru cycle text " + cycle.text)
	if _blob(st.card_body).find("checkpick.") >= 0:
		_bad("ru raw key")
	Copy.set_lang("en")
	var saved := {}
	for key in EN:
		saved[key] = Copy.keys[key]
		Copy.keys.erase(key)
	st._paint_dawn()
	if not _roles(st.card_body, "open").is_empty() or _roles(st.card_body, "cycle").is_empty():
		_bad("missing-key fallback")
	if _blob(st.card_body).find("checkpick.") >= 0:
		_bad("missing-key raw")
	for key in saved:
		Copy.keys[key] = saved[key]
	Copy.set_lang("ru")
	for key in EN:
		Copy.keys[key].ru = "Длинная строка %s для переноса" % key
	Copy.keys["checkpick.use"].ru = "Выбрать {name} на эту проверку"
	Copy.keys["checkpick.work"].ru = "Сейчас в комнате: {room}"
	Copy.keys["checkpick.no_room"].ru = "Комната не назначена"
	var long_id := str(st._check_roster()[0])
	st.game.people[long_id].name_ru = "Очень Длинное Имя Жителя Которое Должно Переноситься"
	st._checkpick_clear()
	st._paint_dawn()
	if _roles(st.card_body, "open").is_empty():
		_bad("injected ru hidden")
	else:
		st._open_checkpick("moles_vents", "cut")
		var use: Button = null
		for button in _roles(st.card_body, "use"):
			if str(button.get_meta("checkpick_id", "")) == long_id:
				use = button
		if use == null or use.clip_text or not use.visible:
			_bad("ru use hidden")
		elif use.text.find("checkpick.") >= 0 or use.text.find("{name}") >= 0:
			_bad("ru use raw")
		else:
			var row = _row(long_id)
			var skill: Label = null
			if row != null:
				for node in _all(row):
					if node is Label and str(node.get_meta("checkpick_role", "")) == "skill":
						skill = node
			if skill == null or skill.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART:
				_bad("ru wrap")
	for key in EN:
		Copy.keys[key].ru = ""
		Copy.keys[key].en = str(EN[key])
	Copy.set_lang("en")


func _browse_then_apply() -> void:
	var game = st.game
	game.pending.clear()
	game.week_event_ids = {}
	game.white_pending = []
	game.week = 8
	if not game._present_event(game._event_by_id("moles_vents")):
		_bad("apply offer")
		return
	var person := str(st._check_roster()[0])
	for resident in game.residents:
		game.check_value_projected(resident, "senses")
		game.check_chance_projected(resident, "senses", int(game.front_event().choices[1].get("check", {}).get("difficulty", 10)), "white")
	var action := {"kind": "event", "event_id": "moles_vents", "choice_id": "cut", "person": person}
	var snap: Dictionary = game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	game.apply(action)
	var got := JSON.stringify(game.export_state())
	var other := Game.new()
	other.catalog = game.catalog
	other.records_path = "user://check_risk_roster/records.cfg"
	if not other.import_state(snap):
		_bad("import " + other.load_error)
		return
	other.apply(action)
	if JSON.stringify(other.export_state()) != got:
		_bad("browse changed apply")
	elif int(other.rng.state) != int(game.rng.state) or int(other.check_rng.state) != int(game.check_rng.state) or int(other.crunch_rng.state) != int(game.crunch_rng.state) or int(other.net_rng.state) != int(game.net_rng.state) or int(other.story_rng.state) != int(game.story_rng.state):
		_bad("browse rng streams")


## The original action, after Compare people, still journals a P97 check receipt for that person.
func _receipt_from_compare() -> void:
	_offer("moles_vents", 8)
	var roster: Array = st._check_roster()
	if roster.size() < 2:
		_bad("receipt roster")
		return
	var chosen := str(roster[roster.size() - 1])
	var key := _check_key("moles_vents", "cut")
	st.check_picks[key] = str(roster[0])
	st._open_checkpick("moles_vents", "cut")
	var fp := ""
	var cfp := ""
	for use in _roles(st.card_body, "use"):
		if str(use.get_meta("checkpick_id", "")) == chosen:
			fp = str(use.get_meta("checkpick_fp", ""))
			cfp = str(use.get_meta("checkpick_choice_fp", ""))
	st._use_checkpick("moles_vents", "cut", chosen, fp, cfp)
	if str(st.check_picks.get(key, "")) != chosen:
		_bad("receipt pick")
		return
	var mark: int = st.game.journal.size()
	st._pick_event("moles_vents", "cut")
	var found := false
	for i in range(mark, st.game.journal.size()):
		var row = st.game.journal[i]
		if not (row is Dictionary):
			continue
		var rec = row.get("receipt", null)
		if not (rec is Dictionary):
			continue
		if str(rec.get("event_id", "")) != "moles_vents" or str(rec.get("choice_id", "")) != "cut":
			continue
		var result = rec.get("result", {})
		if not (result is Dictionary):
			_bad("receipt result missing")
			return
		if str(result.get("kind", "")) != "check":
			_bad("receipt kind " + str(result.get("kind", "")))
			return
		if str(result.get("person_id", "")) != chosen:
			_bad("receipt person " + str(result.get("person_id", "")))
			return
		var tag := str(result.get("tag", ""))
		if tag != "success" and tag != "failure":
			_bad("receipt tag " + tag)
			return
		found = true
	if not found:
		_bad("receipt not journaled")


func _shots() -> void:
	if not _renderer_live():
		print("RISK ROSTER SHOTS SKIP")
		return
	if not _fonts_real():
		print("RISK ROSTER SHOTS SKIP")
		return
	var dir := "/opt/cursor/artifacts"
	DirAccess.make_dir_recursive_absolute(dir)
	await _still("en", 1.0, Vector2i(1920, 1080), "p99_en_100_before", false)
	await _still("en", 1.0, Vector2i(1920, 1080), "p99_en_100_after", true)
	await _still("ru", 1.0, Vector2i(1920, 1080), "p99_ru_100_before", false)
	await _still("ru", 1.0, Vector2i(1920, 1080), "p99_ru_100_after", true)
	await _still("en", 1.25, Vector2i(1920, 1080), "p99_en_125_before", false)
	await _still("en", 1.25, Vector2i(1920, 1080), "p99_en_125_after", true)
	print("RISK ROSTER SHOTS %s" % dir)


func _still(lang: String, scale: float, window: Vector2i, name: String, opened: bool) -> void:
	Copy.set_lang(lang)
	Settings.ui_scale_auto = false
	Settings.ui_scale = scale
	await st._settle(window)
	Settings.apply_scale(st.get_window())
	_offer("moles_vents", 1)
	for _i in 3:
		await process_frame
	if opened and lang == "en":
		st._open_checkpick("moles_vents", "cut")
	for _i in 3:
		await process_frame
	if opened and lang == "en" and st.card_scroll != null:
		var panels := _roles(st.card_body, "panel")
		if not panels.is_empty():
			st.card_scroll.scroll_vertical = maxi(0, int(panels[0].position.y) - 24)
	for _i in 2:
		await process_frame
	var img: Image = st.get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		_bad("shot " + name)
		return
	var path := "/opt/cursor/artifacts/%s.png" % name
	var err := img.save_png(path)
	if err != OK:
		_bad("shot write " + name)
		return
	print("RISK ROSTER SHOT %s %dx%d" % [path, img.get_width(), img.get_height()])


func _renderer_live() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


func _fonts_real() -> bool:
	var bytes := FileAccess.get_file_as_bytes("res://assets/fonts/CourierPrime-Regular.ttf")
	if bytes.size() < 16:
		return false
	return bytes[0] == 0 or bytes[0] == 79


func _rng(game) -> Array:
	return [int(game.rng.state), int(game.crunch_rng.state), int(game.net_rng.state), int(game.check_rng.state), int(game.story_rng.state)]


func _check_key(event_id: String, choice_id: String) -> String:
	return "%s:%s" % [event_id, choice_id]


func _open_first() -> void:
	var opens := _roles(st.card_body, "open")
	if opens.is_empty():
		return
	var key := str(opens[0].get_meta("checkpick_key", ""))
	var bits := key.split(":")
	if bits.size() == 2:
		st._open_checkpick(bits[0], bits[1])


func _row(pid: String):
	for row in _roles(st.card_body, "row"):
		if str(row.get_meta("checkpick_id", "")) == pid:
			return row
	return null


func _label_text(root: Node, role: String) -> String:
	for node in _all(root):
		if node is Label and str(node.get_meta("checkpick_role", "")) == role:
			return str(node.text)
	return ""


func _roles(root: Node, role: String) -> Array:
	var out: Array = []
	if root == null:
		return out
	for node in _all(root):
		if str(node.get_meta("checkpick_role", "")) == role:
			out.append(node)
	return out


func _blob(root: Node) -> String:
	var bits: PackedStringArray = []
	for node in _all(root):
		if node is Label or node is Button:
			bits.append(str(node.text))
	return "\n".join(bits)


func _all(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		var kids := node.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.append(kids[i])
	return out


func _wipe(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var sub := path.path_join(name)
		if dir.current_is_dir():
			_wipe(sub)
			dir.remove(name)
		else:
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
