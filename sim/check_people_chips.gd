extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")

## P59 People Chips. Drawer row chips only — never a soft dawn chip, never a balance edit.
##   godot --headless --path . -s res://sim/check_people_chips.gd

const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const EN := {
	"people.chip_sick": "Sick",
	"people.chip_away": "Away",
	"people.chip_crew": "On a crew",
	"people.chip_free": "Free",
	"people.chip_room": "{room}",
}
const RU := {
	"people.chip_sick": "Болен",
	"people.chip_away": "Вне",
	"people.chip_crew": "В бригаде",
	"people.chip_free": "Свободен",
	"people.chip_room": "{room}",
}
const SICK_FILL := Color("c4544a")
const SOLID_FILL := Color("3a3126")
const MUTED_FILL := Color("241c14")
const EDGE := Color("b89a6a")


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if not _check_strings():
		failed = true
	if not _check_priority(catalog):
		failed = true
	if not _check_reads_only(catalog):
		failed = true
	if not _check_chip_node(catalog):
		failed = true
	if not _check_locks():
		failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("Balance: FAIL balance.json changed")
		failed = true
	else:
		print("Balance: ok")
	if failed:
		print("PEOPLE CHIPS FAIL")
		quit(1)
		return
	print("PEOPLE CHIPS OK")
	quit(0)


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/people_chips.json"))
	if not (pack is Dictionary) or not (pack.get("by_key", {}) is Dictionary):
		print("Strings: FAIL pack")
		return false
	var rows: Dictionary = pack.by_key
	if rows.size() != EN.size():
		print("Strings: FAIL key count ", rows.size())
		return false
	for key in EN:
		if not rows.has(key):
			print("Strings: FAIL missing ", key)
			return false
		if str(rows[key].get("en", "")) != str(EN[key]) or str(rows[key].get("ru", "")) != str(RU[key]):
			print("Strings: FAIL pack row ", key)
			return false
	var ui = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_strings.json"))
	if ui is Dictionary:
		for key in ui:
			if str(key).begins_with("people.chip_"):
				print("Strings: FAIL ui_strings also defines ", key)
				return false
	Copy.set_lang("en")
	for key in EN:
		if Copy.t(str(key)) != str(EN[key]):
			print("Strings: FAIL en ", key, " ", Copy.t(str(key)))
			return false
	if Copy.fill("people.chip_room", {"room": "Workshop"}) != "Workshop":
		print("Strings: FAIL room fill")
		return false
	Copy.set_lang("ru")
	for key in RU:
		if Copy.t(str(key)) != str(RU[key]):
			print("Strings: FAIL ru ", key, " ", Copy.t(str(key)))
			return false
	if Copy.fill("people.chip_room", {"room": "Мастерская"}) != "Мастерская":
		print("Strings: FAIL ru room fill ", Copy.fill("people.chip_room", {"room": "Мастерская"}))
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _boot(catalog: Catalog) -> Game:
	Copy.set_lang("en")
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _desk(game: Game):
	var st = load("res://ui/station.gd").new()
	st.game = game
	return st


func _staffed(game: Game) -> String:
	for room in game.rooms:
		for sid in room.staff:
			return str(sid)
	return ""


func _loose(game: Game) -> String:
	var locked := {}
	for id in game._locked_ids():
		locked[str(id)] = true
	for id in game._roster_ids():
		locked[str(id)] = true
	for person in game.residents:
		var id := str(person.id)
		if locked.has(id) or bool(person.get("soldier", false)):
			continue
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		var posted := false
		for room in game.rooms:
			for sid in room.staff:
				if str(sid) == id:
					posted = true
		if not posted:
			return id
	return ""


func _check_priority(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var st = _desk(game)
	if st._people_chip_clip("Listening Post") != "Listening Post":
		print("Priority: FAIL short room")
		return false
	if st._people_chip_clip("Hydroponics, tier II") != "Hydroponics, t…":
		print("Priority: FAIL clip ", st._people_chip_clip("Hydroponics, tier II"))
		return false
	var ru_room := "Воздушный фильтр"
	if st._people_chip_clip(ru_room) != ru_room.substr(0, 14) + "…":
		print("Priority: FAIL ru clip")
		return false
	var posted := _staffed(game)
	var loose := _loose(game)
	if posted == "" or loose == "":
		print("Priority: FAIL fixtures ", posted, " ", loose)
		return false
	var room_chip: Dictionary = st._people_chip(posted)
	var title: String = st._people_chip_clip(st.room_title(game._room(st._staff_room(posted))))
	if str(room_chip.kind) != "room" or str(room_chip.text) != title or str(room_chip.fill) != "#3a3126":
		print("Priority: FAIL room ", room_chip, " ", title)
		return false
	if title.length() > 15 and not str(room_chip.text).ends_with("…"):
		print("Priority: FAIL room ellipsis ", room_chip.text)
		return false
	game.people[posted].sick = 2
	game.people[posted].absent = 2
	game.dig = {"workers": [posted], "left": 1}
	var sick: Dictionary = st._people_chip(posted)
	if str(sick.kind) != "sick" or str(sick.text) != "Sick" or str(sick.fill) != "#c4544a" or not bool(sick.static):
		print("Priority: FAIL sick beats ", sick)
		return false
	game.people[posted].sick = 0
	var away: Dictionary = st._people_chip(posted)
	if str(away.kind) != "away" or str(away.text) != "Away" or str(away.fill) != "#3a3126":
		print("Priority: FAIL away beats ", away)
		return false
	game.people[posted].absent = 0
	var crew: Dictionary = st._people_chip(posted)
	if str(crew.kind) != "crew" or str(crew.text) != "On a crew":
		print("Priority: FAIL crew beats room ", crew)
		return false
	game.dig = {}
	game.build = {"workers": [loose], "left": 1}
	if str(st._people_chip(loose).kind) != "crew":
		print("Priority: FAIL build crew")
		return false
	game.build = {}
	game.clear = {"workers": [loose], "left": 1}
	if str(st._people_chip(loose).kind) != "crew":
		print("Priority: FAIL clear crew")
		return false
	game.clear = {}
	game.people[loose].soldier = true
	var guard: Dictionary = st._people_chip(loose)
	if str(guard.kind) != "free" or str(guard.text) != "Free" or str(guard.fill) != "muted":
		print("Priority: FAIL guard is not crew ", guard)
		return false
	game.people[loose].soldier = false
	var free: Dictionary = st._people_chip(loose)
	if str(free.kind) != "free" or not bool(free.muted):
		print("Priority: FAIL free ", free)
		return false
	var left := bool(game.flags.get("party_left_home", false))
	var heard := bool(game.flags.get("heard_away", false))
	var seen := bool(game.flags.get("seen_sick_cots", false))
	game.squads[game.player].away = true
	var roster: Array = game.squads[game.player].get("roster", [])
	if roster.is_empty():
		print("Priority: FAIL empty roster")
		return false
	var member := str(roster[0])
	game.people[member].sick = 0
	game.people[member].absent = 0
	var party: Dictionary = st._people_chip(member)
	if str(party.kind) != "away":
		print("Priority: FAIL party away ", party)
		return false
	if bool(game.flags.get("party_left_home", false)) != left or bool(game.flags.get("heard_away", false)) != heard:
		print("Priority: FAIL away bar side effect")
		return false
	if bool(game.flags.get("seen_sick_cots", false)) != seen:
		print("Priority: FAIL sick cot flag")
		return false
	game.people[member].sick = 1
	if str(st._people_chip(member).kind) != "sick":
		print("Priority: FAIL sick beats party")
		return false
	game.people[member].sick = 0
	game.squads[game.player].away = false
	game.squads[game.player].station = game.capital_id
	if str(st._people_chip(loose).kind) != "free":
		print("Priority: FAIL home party still away")
		return false
	Copy.set_lang("ru")
	game.people[loose].sick = 4
	if str(st._people_chip(loose).text) != "Болен":
		print("Priority: FAIL ru sick ", st._people_chip(loose).text)
		return false
	game.people[loose].sick = 0
	game.people[loose].absent = 1
	if str(st._people_chip(loose).text) != "Вне":
		print("Priority: FAIL ru away")
		return false
	game.people[loose].absent = 0
	game.dig = {"workers": [loose]}
	if str(st._people_chip(loose).text) != "В бригаде":
		print("Priority: FAIL ru crew")
		return false
	game.dig = {}
	if str(st._people_chip(loose).text) != "Свободен":
		print("Priority: FAIL ru free ", st._people_chip(loose).text)
		return false
	Copy.set_lang("en")
	if game.party_away_dawn_chip() or game.sick_cots_dawn_chip() or game.dawn_soft_stack() != STACK:
		print("Priority: FAIL dawn")
		return false
	print("Priority: ok")
	return true


func _check_reads_only(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var st = _desk(game)
	var sick := {}
	var absent := {}
	var staff: Array = []
	for person in game.residents:
		var id := str(person.id)
		sick[id] = int(person.get("sick", 0))
		absent[id] = int(person.get("absent", 0))
	for room in game.rooms:
		staff.append((room.staff as Array).duplicate())
	var hope := int(game.hope)
	var stock: Dictionary = game.stock.duplicate(true)
	var dig: Dictionary = game.dig.duplicate(true)
	var motion := Settings.reduce_motion
	Settings.reduce_motion = true
	for person in game.residents:
		var id := str(person.id)
		var chip: Dictionary = st._people_chip(id)
		if not bool(chip.static):
			print("Read: FAIL motion")
			Settings.reduce_motion = motion
			return false
		st._people_status_chip(id)
	Settings.reduce_motion = false
	for person in game.residents:
		st._people_chip(str(person.id))
	Settings.reduce_motion = motion
	for person in game.residents:
		var id := str(person.id)
		if int(person.get("sick", 0)) != int(sick[id]) or int(person.get("absent", 0)) != int(absent[id]):
			print("Read: FAIL sick or absent changed")
			return false
	var i := 0
	for room in game.rooms:
		if room.staff != staff[i]:
			print("Read: FAIL staff changed")
			return false
		i += 1
	if int(game.hope) != hope or game.stock != stock or game.dig != dig:
		print("Read: FAIL meters or dig")
		return false
	print("Read: ok")
	return true


func _check_chip_node(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var st = _desk(game)
	var posted := _staffed(game)
	var loose := _loose(game)
	if posted == "" or loose == "":
		print("Node: FAIL fixtures")
		return false
	game.people[posted].sick = 3
	if not _expect_node(st._people_status_chip(posted), "sick", "Sick", SICK_FILL, false):
		return false
	game.people[posted].sick = 0
	game.people[posted].absent = 2
	if not _expect_node(st._people_status_chip(posted), "away", "Away", SOLID_FILL, false):
		return false
	game.people[posted].absent = 0
	if not _expect_node(st._people_status_chip(posted), "room", str(st._people_chip(posted).text), SOLID_FILL, false):
		return false
	if not _expect_node(st._people_status_chip(loose), "free", "Free", MUTED_FILL, true):
		return false
	var person: Dictionary = game.people[loose]
	var row = st._people_row(person, "labor")
	var line: Node = row.get_child(0)
	if line.get_child_count() < 3 or str(line.get_child(line.get_child_count() - 1).name) != "PeopleChip":
		print("Node: FAIL chip is not the right-hand child")
		return false
	var skill := false
	for lab in _labels(row):
		if int(lab.get_theme_font_size("font_size")) == 13:
			skill = true
	if not skill:
		print("Node: FAIL skill line missing")
		return false
	print("Node: ok")
	return true


func _expect_node(node: Control, kind: String, text: String, fill: Color, muted: bool) -> bool:
	if node == null or str(node.name) != "PeopleChip":
		print("Node: FAIL missing chip")
		return false
	if node.custom_minimum_size != Vector2(72, 22):
		print("Node: FAIL size ", node.custom_minimum_size)
		return false
	if node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("Node: FAIL mouse")
		return false
	if str(node.get_meta("people_chip", "")) != kind or node.get_meta("people_chip_static", false) != true:
		print("Node: FAIL meta ", kind)
		return false
	var style := node.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		print("Node: FAIL style")
		return false
	if style.bg_color != fill:
		print("Node: FAIL fill ", kind, " ", style.bg_color, " ", fill)
		return false
	if style.border_color != EDGE or style.get_border_width(SIDE_LEFT) != 1:
		print("Node: FAIL edge")
		return false
	if style.get_corner_radius(CORNER_TOP_LEFT) != 3:
		print("Node: FAIL radius")
		return false
	var lab := node.get_child(0) as Label
	if lab == null or lab.text != text or int(lab.get_theme_font_size("font_size")) != 11:
		print("Node: FAIL label ", kind, " ", lab.text if lab != null else "")
		return false
	var ink: Color = lab.get_theme_color("font_color")
	var want := Color("b7aa96") if muted else Color("efe6d2")
	if ink != want:
		print("Node: FAIL ink ", kind, " ", ink)
		return false
	return true


func _labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for child in node.get_children():
		out.append_array(_labels(child))
	return out


func _check_locks() -> bool:
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var game_src := FileAccess.get_file_as_string("res://sim/game.gd")
	var net := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if station.find("func _people_status_chip(") < 0 or station.find("Vector2(72, 22)") < 0:
		print("Lock: FAIL geometry")
		return false
	if station.find('"#c4544a"') < 0 or station.find('"#3a3126"') < 0 or station.find("PEOPLE_CHIP_ROOM := 14") < 0:
		print("Lock: FAIL colors or truncate")
		return false
	var row := _body(station, "_people_row")
	if row.find("_people_status_chip(") < 0 or row.find("_main_skill_text(") < 0:
		print("Lock: FAIL row")
		return false
	var order := _body(station, "_people_chip")
	var at := PackedInt32Array([
		order.find('"sick"'),
		order.find('"away"'),
		order.find('"crew"'),
		order.find('"room"'),
		order.find('"free"'),
	])
	for i in range(1, at.size()):
		if at[i - 1] < 0 or at[i] <= at[i - 1]:
			print("Lock: FAIL priority order")
			return false
	var chip_fn := _body(station, "_people_status_chip")
	if chip_fn.find("create_tween") >= 0 or chip_fn.find("bob") >= 0:
		print("Lock: FAIL motion")
		return false
	for name in ["_build_away_badge", "_sync_away_badge", "_build_sick_badge", "_sync_sick_badge", "_show_ahead", "_fill_ahead"]:
		var body := _body(station, name)
		if body == "":
			print("Lock: FAIL missing ", name)
			return false
		if body.find("PeopleChip") >= 0 or body.find("people.chip") >= 0:
			print("Lock: FAIL chip leaked into ", name)
			return false
	if _body(station, "_build_away_badge").find('away_badge.name = "AwayBadge"') < 0:
		print("Lock: FAIL away badge")
		return false
	if _body(station, "_build_sick_badge").find('sick_badge.name = "SickCotsBadge"') < 0:
		print("Lock: FAIL sick badge")
		return false
	if _body(station, "_fill_ahead").find("After this week") < 0:
		print("Lock: FAIL ahead")
		return false
	if game_src.find('const DAWN_SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]') < 0:
		print("Lock: FAIL dawn stack")
		return false
	if game_src.find("people.chip") >= 0 or net.find("PeopleChip") >= 0 or net.find("people.chip") >= 0:
		print("Lock: FAIL chip outside the drawer")
		return false
	print("Lock: ok")
	return true


func _body(src: String, name: String) -> String:
	var token := "func %s(" % name
	var at := src.find(token)
	if at < 0:
		return ""
	var nxt := src.find("\nfunc ", at + token.length())
	if nxt < 0:
		return src.substr(at)
	return src.substr(at, nxt - at)
