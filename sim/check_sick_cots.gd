extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")

## P48 Sick Cots. Sticky yard read only — never a soft dawn chip, never a heal, never a balance edit.
##   godot --headless --path . -s res://sim/check_sick_cots.gd

const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const EN := {
	"sick.cots": "{n} on cots",
	"sick.tip": "Someone is still down.",
	"sick.first": "A cot is taken.",
	"sick.reduce": "{n} sick",
	"sick.label": "Cots",
}
const RU := {
	"sick.cots": "{n} на койках",
	"sick.tip": "Кто-то всё ещё лежит.",
	"sick.first": "Койка занята.",
	"sick.reduce": "{n} больных",
	"sick.label": "Койки",
}


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
	if not _check_quiet(catalog):
		failed = true
	if not _check_show_hide(catalog):
		failed = true
	if not _check_place(catalog):
		failed = true
	if not _check_float_and_save(catalog):
		failed = true
	if not _check_no_dawn(catalog):
		failed = true
	if not _check_ui():
		failed = true
	if not _check_art():
		failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("Balance: FAIL balance.json changed")
		failed = true
	else:
		print("Balance: ok")
	if failed:
		print("SICK COTS FAIL")
		quit(1)
		return
	print("SICK COTS OK")
	quit(0)


func _check_strings() -> bool:
	Copy.set_lang("en")
	for key in EN:
		if Copy.t(str(key)) != str(EN[key]):
			print("Strings: FAIL en ", key, " ", Copy.t(str(key)))
			return false
	if Copy.fill("sick.cots", {"n": 2}) != "2 on cots":
		print("Strings: FAIL fill ", Copy.fill("sick.cots", {"n": 2}))
		return false
	if Copy.fill("sick.reduce", {"n": 2}) != "2 sick":
		print("Strings: FAIL reduce fill")
		return false
	Copy.set_lang("ru")
	for key in RU:
		if Copy.t(str(key)) != str(RU[key]):
			print("Strings: FAIL ru ", key, " ", Copy.t(str(key)))
			return false
	if Copy.fill("sick.cots", {"n": 2}) != "2 на койках":
		print("Strings: FAIL ru fill ", Copy.fill("sick.cots", {"n": 2}))
		return false
	if Copy.fill("sick.reduce", {"n": 3}) != "3 больных":
		print("Strings: FAIL ru reduce")
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _boot(catalog: Catalog) -> Game:
	Copy.set_lang("en")
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _sick_map(game: Game) -> Dictionary:
	var out := {}
	for person in game.residents:
		out[str(person.id)] = int(person.get("sick", 0))
	return out


func _staff_map(game: Game) -> Dictionary:
	var out := {}
	for room in game.rooms:
		var ids: Array = []
		for id in room.staff:
			ids.append(str(id))
		out[str(room.uid)] = ids
	return out


func _meters(game: Game) -> Dictionary:
	return {
		"hope": int(game.hope),
		"discontent": int(game.discontent),
		"stock": game.stock.duplicate(true),
		"sick": _sick_map(game),
		"staff": _staff_map(game),
		"residents": game.residents.size(),
	}


func _same(a: Dictionary, b: Dictionary) -> bool:
	if int(a.hope) != int(b.hope) or int(a.discontent) != int(b.discontent):
		return false
	if int(a.residents) != int(b.residents) or a.stock != b.stock or a.sick != b.sick:
		return false
	var left: Dictionary = a.staff
	var right: Dictionary = b.staff
	if left.size() != right.size():
		return false
	for uid in left:
		if not right.has(uid) or left[uid] != right[uid]:
			return false
	return true


func _queues(game: Game) -> Dictionary:
	return {
		"rumor": game.rumor.duplicate(true),
		"pending": game.pending.size(),
		"notices": game.notices.size(),
		"white": game.white_pending.size(),
		"story": game.story_queue.size(),
		"dawn_kind": str(game.flags.get("dawn_soft_kind", "")),
		"dawn_key": str(game.flags.get("dawn_soft_key", "")),
	}


func _set_sick(game: Game, n_people: int, weeks: int) -> bool:
	if game.residents.size() < n_people:
		return false
	var i := 0
	for person in game.residents:
		person.sick = weeks if i < n_people else 0
		i += 1
	return true


func _empty_dug(game: Game) -> Dictionary:
	for key in game.cells:
		var cell: Dictionary = game.cells[key]
		if bool(cell.get("dug", false)) and str(cell.get("room", "")) == "" and not bool(cell.get("flooded", false)):
			return cell
	return {}


func _drop_infirmary(game: Game) -> void:
	var keep: Array = []
	for room in game.rooms:
		if str(room.get("type", "")) == "infirmary":
			var key := "%d:%d" % [int(room.level), int(room.cell)]
			if game.cells.has(key):
				game.cells[key].room = ""
			continue
		keep.append(room)
	game.rooms = keep


func _check_quiet(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	var view: Dictionary = game.sick_cots_view()
	if bool(view.show) or int(view.count) != 0 or str(view.place) != "strip":
		print("Quiet: FAIL ", view)
		return false
	if bool(view.first) or bool(view.seen) or bool(view.dawn) or game.sick_cots_dawn_chip():
		print("Quiet: FAIL flags ", view)
		return false
	if game.sick_cots_line(false) != "" or game.sick_cots_line(true) != "":
		print("Quiet: FAIL line")
		return false
	if bool(game.flags.get("seen_sick_cots", false)):
		print("Quiet: FAIL flag set")
		return false
	if game.dawn_soft_stack() != STACK:
		print("Quiet: FAIL stack ", game.dawn_soft_stack())
		return false
	for slot in game.dawn_soft_stack():
		var name := str(slot)
		if name.contains("sick") or name.contains("cot"):
			print("Quiet: FAIL stack slot ", name)
			return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("const DAWN_SOFT_STACK")
	var line := src.substr(at, src.find("\n", at) - at)
	if line.contains("sick") or line.contains("cot"):
		print("Quiet: FAIL stack source ", line)
		return false
	print("Quiet: ok")
	return true


func _check_show_hide(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	if not _set_sick(game, 1, 3):
		print("Sick: FAIL roster")
		return false
	var before := _meters(game)
	var queues := _queues(game)
	var view: Dictionary = game.sick_cots_view()
	if not bool(view.show) or int(view.count) != 1 or str(view.place) != "strip" or not bool(view.first):
		print("Sick: FAIL one ", view)
		return false
	if game.sick_cots_line(false) != "1 on cots" or game.sick_cots_line(true) != "1 sick":
		print("Sick: FAIL lines ", game.sick_cots_line(false), " / ", game.sick_cots_line(true))
		return false
	if bool(game.flags.get("seen_sick_cots", false)):
		print("Sick: FAIL view set the flag")
		return false
	if not _set_sick(game, 2, 2):
		print("Sick: FAIL second")
		return false
	var two: Dictionary = game.sick_cots_view()
	if not bool(two.show) or int(two.count) != 2 or game.sick_cots_line(false) != "2 on cots":
		print("Sick: FAIL two ", two, " ", game.sick_cots_line(false))
		return false
	if int(two.count) != game.sick_count():
		print("Sick: FAIL count drift ", two.count, " ", game.sick_count())
		return false
	if not _set_sick(game, 0, 0):
		print("Sick: FAIL clear")
		return false
	var gone: Dictionary = game.sick_cots_view()
	if bool(gone.show) or int(gone.count) != 0 or game.sick_cots_line(false) != "" or bool(gone.first):
		print("Sick: FAIL still showing ", gone)
		return false
	if not _same(_meters(game), _meters_cleared(before)):
		print("Sick: FAIL meters drifted")
		return false
	if _queues(game) != queues:
		print("Sick: FAIL queues drifted")
		return false
	print("Sick: ok")
	return true


## Hope, stock, and assignments stay put. Sick time is whatever the test wrote, including the clear.
func _meters_cleared(before: Dictionary) -> Dictionary:
	var sick: Dictionary = before.sick.duplicate()
	for id in sick:
		sick[id] = 0
	var out := before.duplicate(true)
	out.sick = sick
	return out


func _check_place(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	if not _set_sick(game, 1, 4):
		print("Place: FAIL roster")
		return false
	var cell := _empty_dug(game)
	if cell.is_empty():
		print("Place: FAIL no dug cell")
		return false
	game.build = {"type": "infirmary", "level": int(cell.level), "cell": int(cell.cell), "left": 1, "workers": []}
	var building: Dictionary = game.sick_cots_view()
	if str(building.place) != "strip" or not bool(building.show) or game.room_count("infirmary") < 1:
		print("Place: FAIL construction counted ", building, " rooms ", game.room_count("infirmary"))
		return false
	game.build = {}
	var held := _meters(game)
	var queues := _queues(game)
	game._place_room("infirmary", int(cell.level), int(cell.cell))
	var stood: Dictionary = game.sick_cots_view()
	if str(stood.place) != "infirmary" or not bool(stood.show) or int(stood.count) != 1:
		print("Place: FAIL infirmary ", stood)
		return false
	if str(stood.room) == "" or int(stood.level) != int(cell.level) or int(stood.cell) != int(cell.cell):
		print("Place: FAIL room ", stood)
		return false
	for room in game.rooms:
		if str(room.get("type", "")) == "infirmary":
			room.offline = true
	var dark: Dictionary = game.sick_cots_view()
	if str(dark.place) != "infirmary" or not bool(dark.show):
		print("Place: FAIL offline ", dark)
		return false
	if game.sick_cots_line(false) != "1 on cots":
		print("Place: FAIL line changed")
		return false
	_drop_infirmary(game)
	var back: Dictionary = game.sick_cots_view()
	if str(back.place) != "strip" or not bool(back.show) or int(back.count) != 1:
		print("Place: FAIL strip again ", back)
		return false
	var now := _meters(game)
	if int(now.hope) != int(held.hope) or int(now.discontent) != int(held.discontent) or now.stock != held.stock:
		print("Place: FAIL hope or stock")
		return false
	if now.sick != held.sick or int(now.residents) != int(held.residents):
		print("Place: FAIL healed or lost someone")
		return false
	if _queues(game) != queues or game.sick_cots_dawn_chip():
		print("Place: FAIL dawn")
		return false
	print("Place: ok")
	return true


func _check_float_and_save(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	if not _set_sick(game, 1, 2):
		print("Float: FAIL roster")
		return false
	var first: Dictionary = game.sick_cots_view()
	if not bool(first.first) or bool(first.seen):
		print("Float: FAIL missing first ", first)
		return false
	game.sick_cots_line(false)
	if bool(game.flags.get("seen_sick_cots", false)):
		print("Float: FAIL line set the flag")
		return false
	game.sick_mark_seen_cots()
	var again: Dictionary = game.sick_cots_view()
	if bool(again.first) or not bool(again.seen) or not bool(again.show):
		print("Float: FAIL second ", again)
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var loaded := _boot(catalog)
	if not loaded.import_state(data):
		print("Float: FAIL load ", loaded.load_error)
		return false
	var kept: Dictionary = loaded.sick_cots_view()
	if not bool(kept.show) or bool(kept.first) or not bool(loaded.flags.get("seen_sick_cots", false)):
		print("Float: FAIL loaded sick ", kept)
		return false
	if not _set_sick(loaded, 0, 0):
		print("Float: FAIL clear")
		return false
	var home := loaded.export_state()
	home["schema"] = Game.SAVE_SCHEMA
	var quiet := _boot(catalog)
	if not quiet.import_state(home):
		print("Float: FAIL quiet load ", quiet.load_error)
		return false
	var hidden: Dictionary = quiet.sick_cots_view()
	if bool(hidden.show) or not bool(quiet.flags.get("seen_sick_cots", false)):
		print("Float: FAIL flag lost ", hidden)
		return false
	if not _set_sick(quiet, 1, 1):
		print("Float: FAIL return")
		return false
	var second: Dictionary = quiet.sick_cots_view()
	if not bool(second.show) or bool(second.first) or quiet.sick_cots_line(false) != "1 on cots":
		print("Float: FAIL second wave ", second)
		return false
	print("Float: ok")
	return true


func _check_no_dawn(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	if not _set_sick(game, 2, 3):
		print("Dawn: FAIL roster")
		return false
	var queues := _queues(game)
	var hope := int(game.hope)
	var stock: Dictionary = game.stock.duplicate(true)
	var sick := _sick_map(game)
	game.sick_cots_view()
	game.sick_cots_line(false)
	game.sick_cots_line(true)
	game.sick_mark_seen_cots()
	if _sick_map(game) != sick or int(game.hope) != hope or game.stock != stock:
		print("Dawn: FAIL heal or meters")
		return false
	if not _set_sick(game, 0, 0):
		print("Dawn: FAIL clear")
		return false
	var hidden: Dictionary = game.sick_cots_view()
	if bool(hidden.show) or game.sick_cots_line(false) != "":
		print("Dawn: FAIL still showing")
		return false
	var now := _queues(game)
	if now.rumor != queues.rumor or int(now.pending) != int(queues.pending) or int(now.notices) != int(queues.notices):
		print("Dawn: FAIL queues")
		return false
	if int(now.white) != int(queues.white) or int(now.story) != int(queues.story):
		print("Dawn: FAIL white or story")
		return false
	if str(now.dawn_kind) != str(queues.dawn_kind) or str(now.dawn_key) != str(queues.dawn_key):
		print("Dawn: FAIL kind")
		return false
	if game.sick_cots_dawn_chip() or game.dawn_soft_stack() != STACK:
		print("Dawn: FAIL chip")
		return false
	print("Dawn: ok")
	return true


func _check_ui() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/station.gd")
	src += "\n" + FileAccess.get_file_as_string("res://sim/game.gd")
	for needle in ["sick_cots_view", "sick_cots_line", "sick_mark_seen_cots", "SickCotsBadge", "sick.cots", "sick.reduce", "sick.first", "sick.tip", "sick.label"]:
		if not src.contains(str(needle)):
			print("UI: FAIL missing ", needle)
			return false
	if not src.contains('icon_texture("sick_cot", 22.0)'):
		print("UI: FAIL badge icon")
		return false
	print("UI: ok")
	return true


## status+map twins. Badge size asks for the _24 plate; the 256 plate is the fallback.
const COT_24_MD5 := "18a53f064abfe2ee7bf0f11625958716"


func _check_art() -> bool:
	var paths := [
		"res://assets/icons/status/sick_cot.png",
		"res://assets/icons/status/sick_cot_24.png",
		"res://assets/icons/map/sick_cot.png",
		"res://assets/icons/map/sick_cot_24.png",
	]
	for path in paths:
		if not FileAccess.file_exists(path):
			print("Art: FAIL missing ", path)
			return false
	var pack := FileAccess.get_file_as_string("res://ui/art_pack.gd")
	for path in paths:
		if not pack.contains(path):
			print("Art: FAIL not preloaded ", path)
			return false
	var status := FileAccess.get_file_as_bytes("res://assets/icons/status/sick_cot_24.png")
	var twin := FileAccess.get_file_as_bytes("res://assets/icons/map/sick_cot_24.png")
	if status != twin or status.is_empty():
		print("Art: FAIL status/map 24 differ")
		return false
	if status[0] == 118:
		var head := status.get_string_from_ascii()
		if not head.begins_with("version https://git-lfs.github.com/spec/v1") or not head.contains("oid sha256:"):
			print("Art: FAIL lfs pointer")
			return false
		print("Art: ok lfs")
		return true
	var md5 := FileAccess.get_md5("res://assets/icons/status/sick_cot_24.png")
	if md5 != COT_24_MD5 or FileAccess.get_md5("res://assets/icons/map/sick_cot_24.png") != COT_24_MD5:
		print("Art: FAIL md5 ", md5)
		return false
	print("Art: ok")
	return true
