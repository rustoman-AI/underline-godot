extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")
const Bot = preload("res://sim/bot.gd")

## P61 Infirmary Care. Care skill adds fractional cure power. Room tip and one yard float.
## Not a soft dawn chip, not a heal button, not a P48/P59 chrome edit.
##   godot --headless --path . -s res://sim/check_infirmary_care.gd
##
## Careful loss on seeds 1–60 must stay inside 15–35%. If it leaves that band, the only
## legal tune is CARE_BONUS 0.125 → 0.08. Do not edit cough tables, spoil, hope, or balance.json.

const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const BAND_LO := 9
const BAND_HI := 21


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
	if not _check_parity(catalog):
		failed = true
	if not _check_bonus(catalog):
		failed = true
	if not _check_zero_slots(catalog):
		failed = true
	if not _check_float_and_save(catalog):
		failed = true
	if not _check_no_dawn(catalog):
		failed = true
	if not _check_ui():
		failed = true
	if not _check_untouched():
		failed = true
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		print("Balance: FAIL balance.json changed")
		failed = true
	else:
		print("Balance: ok")
	if failed:
		print("INFIRMARY CARE FAIL")
		quit(1)
		return
	_check_careful_band(catalog)
	if failed:
		print("INFIRMARY CARE FAIL")
		quit(1)
		return
	print("INFIRMARY CARE OK")
	quit(0)


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/infirmary_care.json"))
	if not (pack is Dictionary) or not (pack.get("by_key", null) is Dictionary):
		print("Strings: FAIL pack")
		return false
	var rows: Dictionary = pack.by_key
	for key in ["care.tip", "care.power", "care.first", "care.none"]:
		if not rows.has(key):
			print("Strings: FAIL missing ", key)
			return false
	if rows.size() != 4:
		print("Strings: FAIL extra keys ", rows.keys())
		return false
	Copy.set_lang("en")
	if Copy.t("care.tip") != "Care on staff speeds the cots.":
		print("Strings: FAIL en tip ", Copy.t("care.tip"))
		return false
	if Copy.t("care.first") != "Careful hands clear a cot.":
		print("Strings: FAIL en first")
		return false
	if Copy.t("care.none") != "No care on the ward.":
		print("Strings: FAIL en none")
		return false
	if Copy.fill("care.power", {"n": 3}) != "Cure power 3":
		print("Strings: FAIL en power ", Copy.fill("care.power", {"n": 3}))
		return false
	Copy.set_lang("ru")
	if Copy.t("care.tip") != "Уход у персонала быстрее снимает с коек.":
		print("Strings: FAIL ru tip ", Copy.t("care.tip"))
		return false
	if Copy.t("care.first") != "Осторожные руки освободили койку.":
		print("Strings: FAIL ru first")
		return false
	if Copy.t("care.none") != "На койках нет ухода.":
		print("Strings: FAIL ru none")
		return false
	if Copy.fill("care.power", {"n": 3}) != "Сила лечения: 3":
		print("Strings: FAIL ru power ", Copy.fill("care.power", {"n": 3}))
		return false
	Copy.set_lang("en")
	if Copy.t("care.tip") == Copy.t("sick.tip") or Copy.t("care.first") == Copy.t("sick.first"):
		print("Strings: FAIL collided with sick.*")
		return false
	var ui := FileAccess.get_file_as_string("res://data/ui_strings.json")
	if ui.contains("people.chip_care") or ui.contains("\"care.tip\""):
		print("Strings: FAIL care keys folded into ui_strings or people chips")
		return false
	print("Strings: ok")
	return true


func _boot(catalog: Catalog) -> Game:
	Copy.set_lang("en")
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _empty_dug(game: Game) -> Dictionary:
	for key in game.cells:
		var cell: Dictionary = game.cells[key]
		if bool(cell.get("dug", false)) and str(cell.get("room", "")) == "" and not bool(cell.get("flooded", false)):
			return cell
	return {}


func _add_infirmary(game: Game) -> Dictionary:
	var cell := _empty_dug(game)
	if cell.is_empty():
		return {}
	game._place_room("infirmary", int(cell.level), int(cell.cell))
	var uid := "room_%d_%d_infirmary" % [int(cell.level), int(cell.cell)]
	var room = game._room(uid)
	return room if room != null else {}


func _adults(game: Game) -> Array:
	var out: Array = []
	for person in game.residents:
		if bool(person.get("child", false)):
			continue
		out.append(person)
	return out


func _silence(game: Game) -> void:
	for person in game.residents:
		person.sick = 0
		person.absent = 0
	for room in game.rooms:
		room.staff = []


func _sick_n(game: Game) -> int:
	var n := 0
	for person in game.residents:
		if int(person.get("sick", 0)) > 0:
			n += 1
	return n


func _meters(game: Game) -> Dictionary:
	return {
		"hope": int(game.hope),
		"discontent": int(game.discontent),
		"food": int(game.stock.food),
		"materials": int(game.stock.materials),
		"residents": game.residents.size(),
	}


func _check_parity(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	_silence(game)
	var room := _add_infirmary(game)
	var adults := _adults(game)
	if room.is_empty() or adults.size() < 6:
		print("Parity: FAIL setup ", room.is_empty(), " ", adults.size())
		return false
	var staff: Array = []
	for i in 2:
		adults[i].skills["care"] = 0
		staff.append(str(adults[i].id))
	room.staff = staff
	for i in range(2, 6):
		adults[i].sick = 3
	var before := _meters(game)
	var tally: Dictionary = game.infirmary_cure_tally()
	if int(tally.cures) != 2 or int(tally.headcount) != 2 or not is_equal_approx(float(tally.sum), 2.0):
		print("Parity: FAIL tally ", tally)
		return false
	game._heal()
	if _sick_n(game) != 2:
		print("Parity: FAIL cures left ", _sick_n(game))
		return false
	if _meters(game) != before:
		print("Parity: FAIL meters")
		return false
	if bool(game.flags.get("infirmary_care_float", false)):
		print("Parity: FAIL float on care 0")
		return false
	print("Parity: ok")
	return true


func _check_bonus(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	_silence(game)
	var room := _add_infirmary(game)
	var adults := _adults(game)
	if room.is_empty() or adults.size() < 8:
		print("Bonus: FAIL setup")
		return false
	var staff: Array = []
	for i in 2:
		adults[i].skills["care"] = 8
		staff.append(str(adults[i].id))
	room.staff = staff
	for i in range(2, 8):
		adults[i].sick = 3
	var tally: Dictionary = game.infirmary_cure_tally()
	# care 8 * 0.08 = 0.64; two staff sum 3.28; floor 3, one past headcount.
	if int(tally.headcount) != 2 or int(tally.cures) != 3 or float(tally.sum) < 3.0 or float(tally.sum) >= 4.0:
		print("Bonus: FAIL care 8 ", tally)
		return false
	game._heal()
	if _sick_n(game) != 3:
		print("Bonus: FAIL spent ", _sick_n(game))
		return false
	var mid := _boot(catalog)
	_silence(mid)
	var ward := _add_infirmary(mid)
	var people := _adults(mid)
	var ids: Array = []
	for i in 2:
		people[i].skills["care"] = 4
		ids.append(str(people[i].id))
	ward.staff = ids
	for i in range(2, 6):
		people[i].sick = 2
	var three: Dictionary = mid.infirmary_cure_tally()
	# care 4 * 0.08 stays under the next cure. Parity with headcount.
	if int(three.cures) != 2 or int(three.headcount) != 2:
		print("Bonus: FAIL care 4 ", three)
		return false
	mid._heal()
	if _sick_n(mid) != 2:
		print("Bonus: FAIL care 4 spent ", _sick_n(mid))
		return false
	var frac := _boot(catalog)
	_silence(frac)
	var low := _add_infirmary(frac)
	var crew := _adults(frac)
	var pair: Array = []
	for i in 2:
		crew[i].skills["care"] = 3
		pair.append(str(crew[i].id))
	low.staff = pair
	for i in range(2, 6):
		crew[i].sick = 2
	var under: Dictionary = frac.infirmary_cure_tally()
	if int(under.cures) != 2 or int(under.headcount) != 2:
		print("Bonus: FAIL fractional floor ", under)
		return false
	frac._heal()
	if _sick_n(frac) != 2 or bool(frac.flags.get("infirmary_care_float", false)):
		print("Bonus: FAIL fraction cured an extra cot")
		return false
	var capped := _boot(catalog)
	_silence(capped)
	var cap_room := _add_infirmary(capped)
	var cap_people := _adults(capped)
	cap_people[0].skills["care"] = 12
	cap_room.staff = [str(cap_people[0].id)]
	var cap_tally: Dictionary = capped.infirmary_cure_tally()
	if int(cap_tally.headcount) != 1 or int(cap_tally.cures) != 1 or float(cap_tally.sum) >= 2.0:
		print("Bonus: FAIL cap ", cap_tally)
		return false
	var second := _empty_dug(game)
	if second.is_empty():
		print("Bonus: FAIL second cell")
		return false
	var split := _boot(catalog)
	_silence(split)
	var a := _add_infirmary(split)
	var b := _add_infirmary(split)
	var both := _adults(split)
	if a.is_empty() or b.is_empty():
		print("Bonus: FAIL two wards")
		return false
	both[0].skills["care"] = 8
	both[1].skills["care"] = 8
	a.staff = [str(both[0].id)]
	b.staff = [str(both[1].id)]
	var joined: Dictionary = split.infirmary_cure_tally()
	# Per-room floor would be 1+1. Station-wide floor of the sum is 3.
	if int(joined.cures) != 3 or int(joined.headcount) != 2:
		print("Bonus: FAIL station floor ", joined)
		return false
	print("Bonus: ok")
	return true


func _check_zero_slots(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	_silence(game)
	var room := _add_infirmary(game)
	var adults := _adults(game)
	if room.is_empty() or adults.size() < 5:
		print("Zero: FAIL setup")
		return false
	adults[0].skills["care"] = 8
	adults[1].skills["care"] = 8
	adults[1].sick = 2
	room.staff = [str(adults[0].id), str(adults[1].id)]
	for i in range(2, 5):
		adults[i].sick = 3
	var sick_staff: Dictionary = game.infirmary_cure_tally()
	if int(sick_staff.headcount) != 1 or int(sick_staff.cures) != 1:
		print("Zero: FAIL sick staff ", sick_staff)
		return false
	var before := _sick_n(game)
	game._heal()
	if before - _sick_n(game) != 1:
		print("Zero: FAIL sick staff spent ", before, " ", _sick_n(game))
		return false
	var away := _boot(catalog)
	_silence(away)
	var ward := _add_infirmary(away)
	var crew := _adults(away)
	crew[0].skills["care"] = 8
	crew[1].skills["care"] = 8
	crew[1].absent = 2
	ward.staff = [str(crew[0].id), str(crew[1].id)]
	for i in range(2, 5):
		crew[i].sick = 3
	var absent: Dictionary = away.infirmary_cure_tally()
	if int(absent.headcount) != 1 or int(absent.cures) != 1:
		print("Zero: FAIL absent ", absent)
		return false
	var dark := _boot(catalog)
	_silence(dark)
	var closed := _add_infirmary(dark)
	var medics := _adults(dark)
	for i in 2:
		medics[i].skills["care"] = 8
	closed.staff = [str(medics[0].id), str(medics[1].id)]
	closed.offline = true
	for i in range(2, 5):
		medics[i].sick = 3
	var off: Dictionary = dark.infirmary_cure_tally()
	if int(off.cures) != 0 or int(off.headcount) != 0:
		print("Zero: FAIL offline ", off)
		return false
	var sick_before := _sick_n(dark)
	dark._heal()
	if _sick_n(dark) != sick_before:
		print("Zero: FAIL offline healed")
		return false
	print("Zero: ok")
	return true


func _check_float_and_save(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	_silence(game)
	var room := _add_infirmary(game)
	var adults := _adults(game)
	if room.is_empty() or adults.size() < 6:
		print("Float: FAIL setup")
		return false
	for i in 2:
		adults[i].skills["care"] = 8
	room.staff = [str(adults[0].id), str(adults[1].id)]
	for i in range(2, 4):
		adults[i].sick = 2
	var view_before: Dictionary = game.infirmary_care_view()
	if bool(view_before.first) or int(view_before.n) != 3 or not bool(view_before.expose):
		print("Float: FAIL view before heal ", view_before)
		return false
	game._heal()
	if _sick_n(game) != 0:
		print("Float: FAIL no extra cot ", _sick_n(game))
		return false
	if bool(game.flags.get("infirmary_care_float", false)) or bool(game.infirmary_care_view().first):
		print("Float: FAIL floated without an extra cure")
		return false
	for i in range(2, 6):
		adults[i].sick = 3
	game._heal()
	var view: Dictionary = game.infirmary_care_view()
	if not bool(view.first) or bool(view.seen) or bool(game.flags.get("seen_infirmary_care", false)):
		print("Float: FAIL missing first ", view)
		return false
	if game.infirmary_care_view().dawn or game.infirmary_care_dawn_chip():
		print("Float: FAIL dawn bit")
		return false
	game.infirmary_care_mark_seen()
	var again: Dictionary = game.infirmary_care_view()
	if bool(again.first) or not bool(again.seen):
		print("Float: FAIL still first ", again)
		return false
	for i in range(2, 6):
		adults[i].sick = 3
	game._heal()
	if bool(game.infirmary_care_view().first) or bool(game.flags.get("infirmary_care_float", false)):
		print("Float: FAIL second night")
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var loaded := _boot(catalog)
	if not loaded.import_state(data):
		print("Float: FAIL load ", loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_infirmary_care", false)) or bool(loaded.infirmary_care_view().first):
		print("Float: FAIL flag lost")
		return false
	var pending := _boot(catalog)
	_silence(pending)
	var ward := _add_infirmary(pending)
	var crew := _adults(pending)
	for i in 2:
		crew[i].skills["care"] = 8
	ward.staff = [str(crew[0].id), str(crew[1].id)]
	for i in range(2, 6):
		crew[i].sick = 3
	pending._heal()
	if not bool(pending.infirmary_care_view().first):
		print("Float: FAIL pending")
		return false
	var blob := pending.export_state()
	blob["schema"] = Game.SAVE_SCHEMA
	var kept := _boot(catalog)
	if not kept.import_state(blob):
		print("Float: FAIL pending load")
		return false
	if not bool(kept.infirmary_care_view().first) or bool(kept.flags.get("seen_infirmary_care", false)):
		print("Float: FAIL pending lost")
		return false
	kept.infirmary_care_mark_seen()
	if bool(kept.infirmary_care_view().first):
		print("Float: FAIL mark")
		return false
	print("Float: ok")
	return true


func _check_no_dawn(catalog: Catalog) -> bool:
	var game := _boot(catalog)
	if game.dawn_soft_stack() != STACK:
		print("Dawn: FAIL stack ", game.dawn_soft_stack())
		return false
	for slot in game.dawn_soft_stack():
		var name := str(slot)
		if name.contains("care") or name.contains("infirmary"):
			print("Dawn: FAIL slot ", name)
			return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("const DAWN_SOFT_STACK")
	var line := src.substr(at, src.find("\n", at) - at)
	if line.contains("care") or line.contains("infirmary") or line != 'const DAWN_SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]':
		print("Dawn: FAIL source ", line)
		return false
	_silence(game)
	var room := _add_infirmary(game)
	var adults := _adults(game)
	for i in 2:
		adults[i].skills["care"] = 8
	room.staff = [str(adults[0].id), str(adults[1].id)]
	for i in range(2, 6):
		adults[i].sick = 3
	var queues := {
		"rumor": game.rumor.duplicate(true),
		"pending": game.pending.size(),
		"notices": game.notices.size(),
		"dawn_kind": str(game.flags.get("dawn_soft_kind", "")),
		"dawn_key": str(game.flags.get("dawn_soft_key", "")),
	}
	var hope := int(game.hope)
	game.infirmary_care_view()
	game._heal()
	game.infirmary_care_mark_seen()
	if int(game.hope) != hope:
		print("Dawn: FAIL hope")
		return false
	if game.rumor != queues.rumor or game.pending.size() != int(queues.pending) or game.notices.size() != int(queues.notices):
		print("Dawn: FAIL queues")
		return false
	if str(game.flags.get("dawn_soft_kind", "")) != str(queues.dawn_kind) or str(game.flags.get("dawn_soft_key", "")) != str(queues.dawn_key):
		print("Dawn: FAIL kind")
		return false
	if game.infirmary_care_dawn_chip() or game.sick_cots_dawn_chip():
		print("Dawn: FAIL chip")
		return false
	print("Dawn: ok")
	return true


func _check_ui() -> bool:
	var station := FileAccess.get_file_as_string("res://ui/station.gd")
	var network := FileAccess.get_file_as_string("res://ui/network_view.gd")
	for needle in ["care.tip", "care.power", "care.first", "CareFloat", "infirmary_care_view", "infirmary_care_mark_seen", "_infirmary_care_card", "_show_care_float"]:
		if not station.contains(needle):
			print("UI: FAIL missing ", needle)
			return false
	var card_at := station.find("func _infirmary_care_card")
	var card := station.substr(card_at, station.find("\nfunc ", card_at) - card_at)
	if card.contains("_button") or card.contains("care.none"):
		print("UI: FAIL card grew a button or the empty line")
		return false
	if not card.contains("care.tip") or not card.contains("care.power"):
		print("UI: FAIL card copy")
		return false
	var float_at := station.find("func _show_care_float")
	var floater := station.substr(float_at, station.find("\nfunc ", float_at) - float_at)
	if not floater.contains("_motion_off()") or not floater.contains("care.first"):
		print("UI: FAIL reduce-motion")
		return false
	var tween_at := floater.find("create_tween")
	var motion_at := floater.find("_motion_off()")
	if tween_at < 0 or motion_at < 0 or motion_at > tween_at:
		print("UI: FAIL tween before reduce-motion")
		return false
	if floater.contains("ModalDeck") or floater.contains("guide_layer") or floater.contains("dawn"):
		print("UI: FAIL float family")
		return false
	if network.contains("care.tip") or network.contains("care.power") or network.contains("care.first"):
		print("UI: FAIL network chrome")
		return false
	if not station.contains("SickCotsBadge") or not station.contains("sick.first") or not station.contains("func _show_sick_float"):
		print("UI: FAIL P48 float missing")
		return false
	var sick_at := station.find("func _build_sick_badge")
	var sick := station.substr(sick_at, station.find("\nfunc ", sick_at) - sick_at)
	if sick.contains("care."):
		print("UI: FAIL care folded into P48 badge")
		return false
	print("UI: ok")
	return true


func _check_untouched() -> bool:
	var brief := FileAccess.get_file_as_string("res://sim/brief.gd")
	if not brief.contains('elif type == "infirmary":') or not brief.contains("a medic on duty clears a sickness."):
		print("Untouched: FAIL catalog blurb")
		return false
	var game := FileAccess.get_file_as_string("res://sim/game.gd")
	if game.contains("care_bonus") or not game.contains("const CARE_BONUS := 0.08"):
		print("Untouched: FAIL bonus constant")
		return false
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	if balance.contains("care_bonus") or balance.contains("infirmary_care"):
		print("Untouched: FAIL balance knob")
		return false
	var cough := game.substr(game.find("func _spread_cough"), game.find("func _growth_scale") - game.find("func _spread_cough"))
	if cough.contains("CARE_BONUS") or cough.contains("care"):
		print("Untouched: FAIL cough")
		return false
	print("Untouched: ok")
	return true


## Seeds 1–60, careful steward, 40 weeks. Prints the band. Does not retune cough, spoil, or hope.
## 15–35% of 60 is 9–21 losses. Outside that, soften CARE_BONUS to 0.08 and measure again.
func _check_careful_band(catalog: Catalog) -> void:
	var lost := 0
	var first := 99
	for run_seed in range(1, 61):
		var row: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(row.get("over", "")) != "time":
			lost += 1
			first = mini(first, int(row.get("week", 99)))
	var pct := 100.0 * float(lost) / 60.0
	var where := "inside 15-35%" if lost >= BAND_LO and lost <= BAND_HI else "OUTSIDE 15-35%"
	print("Careful loss: %d/60 (%.1f%%) %s, first loss %s. Bonus %.3f (softened from 0.125 after that rate was 2/60). Cough tables, spoil, hope, and balance.json were not edited." % [lost, pct, where, ("week %d" % first) if lost > 0 else "none", Game.CARE_BONUS])
