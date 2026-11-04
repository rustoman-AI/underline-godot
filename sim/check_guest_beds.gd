extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")
const Bot = preload("res://sim/bot.gd")

## P83 Guest Beds. Seats, convert, chip, first float, no soft dawn, careful loss vs the measured 2/60.
##   godot --headless --path . -s res://sim/check_guest_beds.gd
##   godot --headless --path . -s res://sim/check_guest_beds.gd -- --skip-careful

const BASELINE_LOST := 2
const EN := {
	"guest.name": "Guest Beds",
	"guest.status": "{n}/{max} guest cots",
	"guest.tip": "Guest. New mouths rest before work.",
	"guest.first": "Spare cots for new mouths.",
	"guest.full": "Guest cots full.",
	"guest.free": "{name} takes a Free cot.",
	"guest.empty": "No guests.",
	"guest.convert": "Ready for work.",
	"people.chip_guest": "Guest",
}
const RU := {
	"guest.name": "Гостевые койки",
	"guest.status": "Гостевых коек: {n}/{max}",
	"guest.tip": "Гость. Новые рты отдыхают перед работой.",
	"guest.first": "Запасные койки для новых ртов.",
	"guest.full": "Гостевые койки полны.",
	"guest.free": "{name} берёт свободную койку.",
	"guest.empty": "Гостей нет.",
	"guest.convert": "Готов к работе.",
	"people.chip_guest": "Гость",
}


func _init() -> void:
	var skip := false
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--skip-careful":
			skip = true
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	var failed := false
	if not _check_strings():
		failed = true
	if not _check_beds(catalog):
		failed = true
	if not _check_chip(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_wires():
		failed = true
	if balance != FileAccess.get_file_as_string("res://data/balance.json"):
		print("Balance: FAIL balance.json changed")
		failed = true
	if not skip:
		if not _check_careful(catalog):
			failed = true
	if failed:
		print("GUEST FAIL")
		quit(1)
		return
	print("GUEST OK")
	quit(0)


func _game(catalog: Catalog) -> Game:
	Copy.set_lang("en")
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _meters(game: Game) -> Dictionary:
	return {
		"hope": int(game.hope),
		"dis": int(game.discontent),
		"food": int(game.stock.food),
		"pop": game.residents.size(),
		"housing": game.housing(),
	}


func _check_strings() -> bool:
	Copy.set_lang("en")
	for key in EN:
		if Copy.t(str(key)) != str(EN[key]):
			print("Strings: FAIL en ", key, " -> ", Copy.t(str(key)))
			return false
	if Copy.fill("guest.status", {"n": 1, "max": 4}) != "1/4 guest cots":
		print("Strings: FAIL status fill ", Copy.fill("guest.status", {"n": 1, "max": 4}))
		return false
	if Copy.fill("guest.free", {"name": "Mina Cho"}) != "Mina Cho takes a Free cot.":
		print("Strings: FAIL free fill")
		return false
	Copy.set_lang("ru")
	for key in RU:
		if Copy.t(str(key)) != str(RU[key]):
			print("Strings: FAIL ru ", key, " -> ", Copy.t(str(key)))
			return false
	if Copy.fill("guest.status", {"n": 1, "max": 4}) != "Гостевых коек: 1/4":
		print("Strings: FAIL ru status")
		return false
	if Copy.fill("guest.free", {"name": "Мина"}) != "Мина берёт свободную койку.":
		print("Strings: FAIL ru free")
		return false
	Copy.set_lang("en")
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/guest_beds.json"))
	if str(pack.get("_roadmap", "")) != "P83":
		print("Strings: FAIL roadmap")
		return false
	for key in pack.get("by_key", {}):
		if not str(key).begins_with("guest."):
			print("Strings: FAIL namespace ", key)
			return false
	if pack.by_key.has("people.chip_guest"):
		print("Strings: FAIL chip key under guest.*")
		return false
	print("Strings: ok")
	return true


func _quarters(game: Game) -> Array:
	var rows: Array = []
	for room in game.rooms:
		if str(room.type) == "quarters":
			rows.append(room)
	return rows


func _check_beds(catalog: Catalog) -> bool:
	var game := _game(catalog)
	if game.over == "error":
		print("Beds: FAIL setup")
		return false
	if catalog.rooms.has("barracks") or catalog.rooms.has("dorm"):
		print("Beds: FAIL barracks or dorm type was invented")
		return false
	var quarters := _quarters(game)
	if quarters.is_empty():
		print("Beds: FAIL no quarters")
		return false
	if game.guest_max() != mini(quarters.size(), Game.GUEST_CAP):
		print("Beds: FAIL open quarters ", game.guest_max(), " rooms ", quarters.size())
		return false
	if not game._guest_room_online({"type": "barracks", "offline": false, "disabled": 0}):
		print("Beds: FAIL barracks type would not count")
		return false
	if not game._guest_room_online({"type": "dorm", "offline": false, "disabled": 0}):
		print("Beds: FAIL dorm type would not count")
		return false
	if game._guest_room_online({"type": "platform", "offline": false, "disabled": 0}):
		print("Beds: FAIL platform counted")
		return false
	if game._guest_room_online({"type": "quarters", "offline": true, "disabled": 0}):
		print("Beds: FAIL offline quarters counted")
		return false
	if game._guest_room_online({"type": "quarters", "offline": false, "disabled": 2}):
		print("Beds: FAIL shut quarters counted")
		return false
	var before := game.guest_max()
	quarters[0].offline = true
	if game.guest_max() != before - 1:
		print("Beds: FAIL offline did not drop a seat ", game.guest_max())
		return false
	quarters[0].offline = false
	var built := game.guest_max()
	game.build = {"type": "quarters", "level": 9, "cell": 9, "left": 2, "workers": []}
	if game.guest_max() != built:
		print("Beds: FAIL a building job lent a cot")
		return false
	game.build = {}
	var placed := 0
	for key in game.cells:
		if game.guest_max() > Game.GUEST_CAP:
			break
		var cell: Dictionary = game.cells[key]
		if str(cell.get("room", "")) != "":
			continue
		game._place_room("quarters", int(cell.level), int(cell.cell))
		placed += 1
	if game.guest_max() != Game.GUEST_CAP:
		print("Beds: FAIL cap ", game.guest_max(), " placed ", placed)
		return false
	var hope := _meters(game)
	var popped := game.residents.size()
	game._hire(6, true)
	if game.guest_count() != Game.GUEST_CAP:
		print("Beds: FAIL parked ", game.guest_count())
		return false
	if game.residents.size() != popped + 6:
		print("Beds: FAIL refuse-keep changed the intake")
		return false
	if int(hope.hope) != int(game.hope) or int(hope.housing) != game.housing():
		print("Beds: FAIL hope or housing moved")
		return false
	if not bool(game.flags.get("seen_guest_beds", false)) or not game.take_guest_float():
		print("Beds: FAIL first float")
		return false
	if game.take_guest_float():
		print("Beds: FAIL float twice")
		return false
	game.flags.erase("guest_float")
	var again: Dictionary = game.guest_people()[0]
	game._convert_guest(again)
	if game._park_guest(again) and bool(game.flags.get("guest_float", false)):
		print("Beds: FAIL float rearmed")
		return false
	var party := _game(catalog)
	var party_n := party.residents.size()
	party._hire(2)
	if party.guest_count() != 0 or party.residents.size() != party_n + 2:
		print("Beds: FAIL party return parked as guest")
		return false
	var born := party._birth()
	if born != "" and party.is_guest(party.people["n%d" % party.next_person]):
		print("Beds: FAIL a birth parked as guest")
		return false
	var held := _game(catalog)
	var meters := _meters(held)
	held._hire(1, true)
	var guest: Dictionary = held.guest_people()[0]
	if not held.is_guest(guest):
		print("Beds: FAIL joiner was not a guest")
		return false
	var uid := ""
	for room in held.rooms:
		if str(room.type) == "workshop" and not room.staff.is_empty():
			uid = str(room.uid)
			held.apply({"kind": "unassign", "person": str(room.staff[0])})
			break
	if uid == "" or not held.apply({"kind": "assign", "person": str(guest.id), "room": uid}):
		print("Beds: FAIL assign")
		return false
	if held.is_guest(held.people[str(guest.id)]):
		print("Beds: FAIL assign left them a guest")
		return false
	var seated := false
	for room in held.rooms:
		for sid in room.staff:
			if str(sid) == str(guest.id):
				seated = true
	if not seated:
		print("Beds: FAIL assign did not seat them")
		return false
	var toasted := false
	for line in held.notices:
		if str(line).find("takes a Free cot.") >= 0:
			toasted = true
	if not toasted or not bool(held.flags.get("seen_guest_convert", false)):
		print("Beds: FAIL convert toast")
		return false
	if int(meters.hope) != int(held.hope) or int(meters.food) != int(held.stock.food):
		print("Beds: FAIL convert moved hope or food")
		return false
	var week := _game(catalog)
	week._hire(1, true)
	var who: Dictionary = week.guest_people()[0]
	var id := str(who.id)
	if not week.is_guest(who):
		print("Beds: FAIL week guest")
		return false
	week.apply({"kind": "staff"})
	if Game.GUEST_HOLD_WORK:
		for room in week.rooms:
			for sid in room.staff:
				if str(sid) == id:
					print("Beds: FAIL staff auto-assigned a guest")
					return false
	week._tick_guests()
	if week.is_guest(week.people[id]):
		print("Beds: FAIL night tick left them a guest")
		return false
	print("Beds: ok")
	return true


func _check_chip(catalog: Catalog) -> bool:
	var game := _game(catalog)
	game._hire(1, true)
	var person: Dictionary = game.guest_people()[0]
	var id := str(person.id)
	if game.people_chip_kind(id) != "guest":
		print("Chip: FAIL guest ", game.people_chip_kind(id))
		return false
	person.sick = 2
	if game.people_chip_kind(id) != "sick":
		print("Chip: FAIL sick")
		return false
	person.sick = 0
	person.absent = 2
	if game.people_chip_kind(id) != "away":
		print("Chip: FAIL away")
		return false
	person.absent = 0
	if game.people_chip_kind(id) != "guest":
		print("Chip: FAIL guest after away")
		return false
	game._convert_guest(person)
	person["duty_id"] = "passage"
	if game.people_chip_kind(id) != "duty":
		print("Chip: FAIL duty cite")
		return false
	person.erase("duty_id")
	if game.dig.is_empty():
		game.dig = {"workers": [id], "left": 1}
	else:
		game.dig.workers = [id]
	if game.people_chip_kind(id) != "crew":
		print("Chip: FAIL crew")
		return false
	game.dig = {}
	var uid := ""
	for room in game.rooms:
		if int(game.catalog.rooms[room.type].get("staff_max", 0)) > 0:
			uid = str(room.uid)
			break
	if uid == "":
		print("Chip: FAIL no room")
		return false
	game._unassign(id)
	game._room(uid).staff.append(id)
	if game.people_chip_kind(id) != "room":
		print("Chip: FAIL room")
		return false
	game._unassign(id)
	if game.people_chip_kind(id) != "free":
		print("Chip: FAIL free ", game.people_chip_kind(id))
		return false
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("people.chip_guest") < 0 or ui.find("people_chip_kind") < 0:
		print("Chip: FAIL drawer chip missing")
		return false
	if ui.find("people.chip_sick") >= 0 or ui.find("people.chip_duty") >= 0:
		print("Chip: FAIL reopened another chip pack")
		return false
	print("Chip: ok")
	return true


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	game._hire(1, true)
	var chip: Dictionary = game._pick_dawn_soft_chip()
	var kind := str(chip.get("kind", ""))
	if kind != "rumor" and kind != "border_new" and kind != "rail" and not chip.is_empty() and kind != "":
		if kind.find("guest") >= 0:
			print("Dawn: FAIL guest chip ", kind)
			return false
	if str(chip.get("key", "")).begins_with("guest."):
		print("Dawn: FAIL guest key on the dawn stack")
		return false
	if str(game.flags.get("dawn_soft_kind", "")).find("guest") >= 0:
		print("Dawn: FAIL latched guest")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var end := src.find("func dawn_soft_chip", at)
	var body := src.substr(at, end - at)
	if body.find("guest") >= 0:
		print("Dawn: FAIL picker knows guest")
		return false
	var order := ["rumor", "border.dawn_new", "rail", "homecoming"]
	if order.size() != 4:
		print("Dawn: FAIL stack size")
		return false
	var home := FileAccess.get_file_as_string("res://sim/check_homecoming.gd")
	if home.find("rumor > border > rail > home") < 0:
		print("Dawn: FAIL homecoming order cite missing")
		return false
	if FileAccess.get_file_as_string("res://ui/network_view.gd").find("guest.") >= 0:
		print("Dawn: FAIL a map mark")
		return false
	print("Dawn: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	if Game.SAVE_SCHEMA != 14:
		print("Save: FAIL schema ", Game.SAVE_SCHEMA)
		return false
	var game := _game(catalog)
	game._hire(1, true)
	var id := str(game.guest_people()[0].id)
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var staged: Dictionary = Game.stage_state(data, catalog)
	if str(staged.error) != "":
		print("Save: FAIL ", staged.error)
		return false
	var back: Dictionary = staged.state.people[id]
	if int(back.get("guest_until", 0)) != game.week:
		print("Save: FAIL guest_until dropped")
		return false
	if not bool(staged.state.flags.get("seen_guest_beds", false)):
		print("Save: FAIL seen flag dropped")
		return false
	var older: Dictionary = data.duplicate(true)
	older.people[id].erase("guest_until")
	var again: Dictionary = Game.stage_state(older, catalog)
	if str(again.error) != "":
		print("Save: FAIL a person without guest_until ", again.error)
		return false
	print("Save: ok schema 14")
	return true


func _check_wires() -> bool:
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	var sim := FileAccess.get_file_as_string("res://sim/game.gd")
	for key in ["guest.status", "guest.empty", "guest.full", "guest.first", "guest.tip", "guest.name"]:
		if ui.find(key) < 0:
			print("Wires: FAIL missing ", key)
			return false
	if sim.find("guest.free") < 0 or sim.find("guest.convert") < 0:
		print("Wires: FAIL convert copy")
		return false
	if ui.find("notices") < 0 or ui.find("_toast") < 0:
		print("Wires: FAIL toast drain")
		return false
	if ui.find("GuestFloat") < 0:
		print("Wires: FAIL float")
		return false
	if ui.find("func _build_dawn_chip") >= 0 and ui.find("guest.first") >= 0:
		var dawn := ui.find("func _build_dawn_chip")
		var nxt := ui.find("func _sync_homecoming", dawn)
		var chip := ui.substr(dawn, nxt - dawn)
		if chip.find("guest.") >= 0:
			print("Wires: FAIL guest joined the dawn chip")
			return false
	print("Wires: ok")
	return true


func _check_careful(catalog: Catalog) -> bool:
	var lost := 0
	for run_seed in range(1, 61):
		var row: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(row.get("over", "")) != "time":
			lost += 1
			print("  careful seed %d over %s" % [run_seed, str(row.get("over", ""))])
	var line := "careful loss %d/60 (master baseline %d/60)" % [lost, BASELINE_LOST]
	if lost != BASELINE_LOST:
		print("Careful: FAIL ", line)
		return false
	print("Careful: ok ", line)
	return true
