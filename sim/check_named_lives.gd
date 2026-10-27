extends SceneTree

const Catalog = preload("res://sim/catalog.gd")
const Game = preload("res://sim/game.gd")
const Copy = preload("res://sim/copy.gd")
const Bot = preload("res://sim/bot.gd")

## P67 Named Lives. Named cause on every death, Known never anonymous, death card
## at memory ≥ 30, no soft-dawn chip, P48 sick cots still not a dawn chip.
##   godot --headless --path . -s res://sim/check_named_lives.gd

const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings(catalog):
		failed = true
	if not _check_identity(catalog):
		failed = true
	if not _check_causes(catalog):
		failed = true
	if not _check_known_and_card(catalog):
		failed = true
	if not _check_memory_skill_child(catalog):
		failed = true
	if not _check_soft_dawn(catalog):
		failed = true
	var band := _careful_band(catalog)
	var rate := float(catalog.balance.get("growth_rate", 0))
	var pct := 100.0 * float(band.lost) / 60.0
	print("careful %d/60 (%.1f%%) growth_rate %.2f" % [band.lost, pct, rate])
	# Master careful line is 2/60 (3.3%), preserved since P53. The spec still names 15–35%.
	# The only listed retune is growth_rate 0.04→0.05 when loss is above 30%. This measure
	# is not above 30%, so the rate stays. Do not invent a cough or climb into the old corridor.
	if pct > 30.0:
		print("Careful: FAIL above 30%% — set growth_rate 0.04→0.05 and remeasure")
		failed = true
	elif int(band.lost) != 2:
		print("Careful: FAIL moved off the preserved 2/60 master line")
		failed = true
	else:
		print("NOTE spec names 15-35 percent of 60. Measured %d/60 (%.1f percent). growth_rate left at %.2f; careful is not above 30 percent." % [band.lost, pct, rate])
	print("soft dawn: rumor > border.dawn_new > rail > homecoming; named lives does not join")
	if failed:
		print("NAMED LIVES FAIL")
		quit(1)
		return
	print("NAMED LIVES OK")
	quit(0)


func _check_strings(catalog: Catalog) -> bool:
	var pack: Dictionary = _read_pack()
	var rows: Dictionary = pack.get("by_key", {})
	if rows.is_empty():
		print("Strings: FAIL no by_key")
		return false
	for lang in ["en", "ru"]:
		Copy.set_lang(lang)
		for key in ["named.bury", "named.ledger", "named.known", "named.seasoned", "named.birth"]:
			var want := str(rows[key].get(lang, ""))
			if Copy.t(key) != want or want == "":
				print("Strings: FAIL %s %s got %s" % [lang, key, Copy.t(key)])
				return false
	Copy.set_lang("en")
	var deaths: Array = pack.get("deaths", [])
	if deaths.size() != Game.DEATH_CAUSES.size():
		print("Strings: FAIL deaths %d" % deaths.size())
		return false
	for row in deaths:
		if not Game.DEATH_CAUSES.has(str(row.get("id", ""))):
			print("Strings: FAIL death id ", row.get("id", ""))
			return false
		if str(row.get("en", "")).find("{name}") < 0:
			print("Strings: FAIL death line missing {name} ", row.get("id", ""))
			return false
	if str(catalog.names.get("pasts", {}).get("authored", {}).get("jonah", {}).get("en", "")).find("R train") < 0:
		print("Strings: FAIL jonah past was not the locked pack")
		return false
	print("Strings: ok")
	return true


func _check_identity(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 2)
	var jonah: Dictionary = game.people["jonah"]
	var past := game.life_line(jonah, "before")
	var keep := game.life_line(jonah, "keepsake")
	var want_past := str(catalog.names.pasts.authored.jonah.en)
	var want_keep := str(catalog.names.keepsakes.authored.jonah.en)
	if past != want_past or keep != want_keep:
		print("Identity: FAIL jonah past/keepsake")
		print("  past ", past)
		print("  keep ", keep)
		return false
	if past.find("fifth floor") >= 0:
		print("Identity: FAIL showed the old profile bio")
		return false
	var chris: Dictionary = game.people["chris"]
	if not game.cast_bio_locked(chris) or game.life_line(chris, "before") != "" or game.life_line(chris, "keepsake") != "":
		print("Identity: FAIL coney past overwrote the cast")
		return false
	var row: Dictionary = catalog.coney.characters[0]
	var bios: Dictionary = chris.get("dossier", {})
	if game.line_of(bios, "bio") != game.line_of(row, "bio") or game.line_of(bios, "bio") == "":
		print("Identity: FAIL chris bio moved")
		return false
	if str(chris.get("before_silence", "")) != "" or str(chris.get("keepsake", "")) != "":
		print("Identity: FAIL chris was given a named-lives past")
		return false
	print("Identity: ok")
	return true


func _check_causes(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 4)
	var ids := _spare(game)
	if ids.size() < Game.DEATH_CAUSES.size() + 2:
		print("Causes: FAIL not enough people %d" % ids.size())
		return false
	for i in Game.DEATH_CAUSES.size():
		var cause := str(Game.DEATH_CAUSES[i])
		var id := str(ids[i])
		var person: Dictionary = game.people[id]
		person.memory = 12
		var name := str(person.name)
		game._remove_resident(id, true, cause, "died")
		var row := _departed(game, id)
		if str(row.get("how", "")) != "died" or str(row.get("cause_id", "")) != cause or str(row.get("name", "")) != name:
			print("Causes: FAIL %s row %s" % [cause, row])
			return false
		if not _notice_has(game, name):
			print("Causes: FAIL %s toast missed %s" % [cause, name])
			return false
	game._shed(1, "died", "hope")
	var hope_row: Dictionary = game.departed.back()
	if not Game.DEATH_CAUSES.has(str(hope_row.get("cause_id", ""))) or str(hope_row.get("name", "")) == "":
		print("Causes: FAIL hope mapped to ", hope_row)
		return false
	var left_id := ""
	for candidate in ids:
		if game.people.has(str(candidate)):
			left_id = str(candidate)
			break
	if left_id == "":
		print("Causes: FAIL no one left to leave")
		return false
	var left_person: Dictionary = game.people[left_id]
	left_person.memory = 55
	var hope_before := game.hope
	var left_name := str(left_person.name)
	game._remove_resident(left_id, false, "left", "left")
	var left_row := _departed(game, left_id)
	if str(left_row.get("how", "")) != "left" or str(left_row.get("name", "")) != left_name:
		print("Causes: FAIL leave ", left_row)
		return false
	if game.hope != hope_before - 1 or not game.burials.is_empty():
		print("Causes: FAIL known leave hope %d burials %d" % [game.hope - hope_before, game.burials.size()])
		return false
	print("Causes: ok")
	return true


func _check_known_and_card(catalog: Catalog) -> bool:
	var quiet := _fresh(catalog, 5)
	var low := str(_spare(quiet)[0])
	var low_person: Dictionary = quiet.people[low]
	low_person.memory = 20
	var low_name := str(low_person.name)
	var low_hope := quiet.hope
	quiet._remove_resident(low, true, "cold", "died")
	if not quiet.burials.is_empty() or quiet.hope != low_hope or not _notice_has(quiet, low_name):
		print("Card: FAIL low memory still opened a rite or dropped hope")
		return false
	var pending_before := quiet.pending.size()
	quiet._offer_burial()
	var queued_card := false
	for ev in quiet.pending:
		if str(ev.get("burial_id", "")) != "":
			queued_card = true
	if queued_card or quiet.pending.size() != pending_before:
		print("Card: FAIL low memory queued a card")
		return false
	var game := _fresh(catalog, 6)
	var id := str(_spare(game)[0])
	var person: Dictionary = game.people[id]
	person.memory = 55
	var name := str(person.name)
	var hope0 := game.hope
	var mats0 := int(game.stock.materials)
	game._remove_resident(id, true, "sickness", "died")
	if game.hope != hope0 - 2 or game.burials.size() != 1:
		print("Card: FAIL known death hope %d burials %d" % [game.hope - hope0, game.burials.size()])
		return false
	if _notice_has(game, name):
		print("Card: FAIL known death also toasted instead of the card")
		return false
	game._offer_burial()
	if game.pending.is_empty() or str(game.pending[0].get("burial_id", "")) != id:
		print("Card: FAIL burial was not an event card")
		return false
	var ev: Dictionary = game.pending[0]
	var body := game.line_of(ev, "text")
	if body.find(name) < 0:
		print("Card: FAIL anonymous body ", body)
		return false
	var ids: PackedStringArray = []
	for choice in ev.choices:
		ids.append(str(choice.get("id", "")))
	if ids.size() != 1 or ids[0] != "bury" or game.line_of(ev.choices[0], "label") != Copy.t("named.bury"):
		print("Card: FAIL bury-only choices ", ids)
		return false
	if not game.apply({"kind": "event", "event_id": str(ev.id), "choice_id": "bury"}):
		print("Card: FAIL bury did not apply")
		return false
	if int(game.stock.materials) != mats0 - 1 or game.hope != hope0 - 1:
		print("Card: FAIL bury mats %d hope %d" % [int(game.stock.materials) - mats0, game.hope - hope0])
		return false
	if game._burial_of(id) != "bury":
		print("Card: FAIL burial mark ", game._burial_of(id))
		return false
	var led := _fresh(catalog, 7)
	led.laws_on["ledger"] = true
	var devout_id := str(_spare(led)[1])
	led.people[devout_id].traits = ["Devout"]
	var dead := str(_spare(led)[0])
	if dead == devout_id:
		print("Card: FAIL devout was the victim")
		return false
	led.people[dead].memory = 44
	var led_name := str(led.people[dead].name)
	var led_hope := led.hope
	var led_mats := int(led.stock.materials)
	led._remove_resident(dead, true, "battle", "died")
	led._offer_burial()
	var card: Dictionary = led.pending[0]
	var seen := {}
	for choice in card.choices:
		seen[str(choice.get("id", ""))] = choice
	if not seen.has("bury") or not seen.has("ledger") or seen.has("tunnel"):
		print("Card: FAIL ledger choices ", seen.keys())
		return false
	if led.line_of(seen.ledger, "label") != Copy.t("named.ledger"):
		print("Card: FAIL ledger label ", led.line_of(seen.ledger, "label"))
		return false
	if led.line_of(card, "text").find(led_name) < 0 or str(_departed(led, dead).get("cause_id", "")) != "battle":
		print("Card: FAIL battle line")
		return false
	if not led.apply({"kind": "event", "event_id": str(card.id), "choice_id": "ledger"}):
		print("Card: FAIL ledger did not apply")
		return false
	if int(led.stock.materials) != led_mats + 2 or led.hope != led_hope - 4:
		print("Card: FAIL ledger mats %d hope %d" % [int(led.stock.materials) - led_mats, led.hope - led_hope])
		return false
	if led._burial_of(dead) != "ledger":
		print("Card: FAIL ledger mark")
		return false
	if led.named_lives_dawn_chip() or led.dawn_soft_stack() != STACK:
		print("Card: FAIL death card joined soft dawn")
		return false
	print("Card: ok")
	return true


func _check_memory_skill_child(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 8)
	var person: Dictionary = game.people[str(_spare(game)[0])]
	person.memory = 98
	game._life_note(person, "sick", {"room": "Infirmary"})
	if int(person.memory) != 100:
		print("Memory: FAIL cap %d" % int(person.memory))
		return false
	var notes := int(person.story_events.size())
	game._life_note(person, "check_rolled", {})
	if int(person.memory) != 100 or person.story_events.size() != notes + 1:
		print("Memory: FAIL second beat")
		return false
	var line := game.journal_line(person.story_events.back(), game.sex_of(person) == "f")
	if line == "" or line.find(str(person.name)) < 0:
		print("Memory: FAIL journal line ", line)
		return false
	var skilled := false
	for room in game.rooms:
		var skill := str(catalog.rooms[room.type].get("skill", ""))
		if skill == "" or room.staff.is_empty():
			continue
		var worker: Dictionary = game.people[str(room.staff[0])]
		if game._is_child(worker):
			continue
		worker.skills[skill] = 1
		worker.staff_room = str(room.uid)
		worker.staff_weeks = Game.SKILL_WEEKS - 1
		var before := game.notices.size()
		game._mark_served(worker, room)
		var toast := str(game.notices.back()) if game.notices.size() > before else ""
		var room_name := Copy.t(str(catalog.rooms[room.type].get("name", "")))
		if int(worker.skills[skill]) != 2 or toast != Copy.fill("named.seasoned", {"room": room_name}):
			print("Skill: FAIL growth %s toast %s" % [worker.skills[skill], toast])
			return false
		worker.skills[skill] = Game.SKILL_CAP
		worker.staff_room = str(room.uid)
		worker.staff_weeks = Game.SKILL_WEEKS - 1
		var held := game.notices.size()
		game._mark_served(worker, room)
		if int(worker.skills[skill]) != Game.SKILL_CAP or game.notices.size() != held:
			print("Skill: FAIL cap")
			return false
		skilled = true
		break
	if not skilled:
		print("Skill: FAIL no staffed room")
		return false
	var shares := game.ration_shares()
	var child: Dictionary = game.people[str(_spare(game)[2])]
	if game._is_child(child):
		print("Child: FAIL spare was already a child")
		return false
	child.child = true
	child.child_left = Game.CHILD_WEEKS
	if absf(shares - game.ration_shares() - (1.0 / 3.0)) > 0.001:
		print("Child: FAIL food share %s -> %s" % [shares, game.ration_shares()])
		return false
	var hope := game.hope
	var born := game._birth()
	if born == "" or game.hope != hope + 1:
		print("Child: FAIL first birth")
		return false
	var baby: Dictionary = {}
	for person_row in game.residents:
		if str(person_row.get("name", "")) == born and game._is_child(person_row):
			baby = person_row
	if baby.is_empty() or int(baby.child_left) != Game.CHILD_WEEKS:
		print("Child: FAIL child_left ", baby.get("child_left", -1))
		return false
	if str(game.notices.back()) != Copy.fill("named.birth", {"name": born, "fem": game.sex_of(baby) == "f"}):
		print("Child: FAIL birth toast ", game.notices.back())
		return false
	game._birth()
	game._birth()
	if game.hope != hope + Game.BIRTH_HOPE_CAP:
		print("Child: FAIL hope cap %d" % (game.hope - hope))
		return false
	game.week = int(baby.born_week) + 1
	for _i in Game.CHILD_WEEKS:
		game._tick_children()
	if game._is_child(baby):
		print("Child: FAIL still a child after %d weeks" % Game.CHILD_WEEKS)
		return false
	print("Memory: ok")
	return true


func _check_soft_dawn(catalog: Catalog) -> bool:
	var game := _fresh(catalog, 9)
	if game.dawn_soft_stack() != STACK or game.named_lives_dawn_chip() or game.sick_cots_dawn_chip() or game.party_away_dawn_chip():
		print("Dawn: FAIL stack ", game.dawn_soft_stack())
		return false
	var view := game.sick_cots_view()
	if bool(view.get("dawn", true)):
		print("Dawn: FAIL sick cots dawn flag")
		return false
	var sim := FileAccess.get_file_as_string("res://sim/game.gd")
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if sim.find('const DAWN_SOFT_STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]') < 0:
		print("Dawn: FAIL stack literal moved")
		return false
	if ui.find("func _known_tag") < 0 or ui.find("func _journal_block") < 0 or ui.find("P48 sticky cot count") < 0:
		print("Dawn: FAIL chrome markers")
		return false
	if ui.find('if words != "" and str(ev.get("burial_id", "")) == ""') < 0:
		print("Dawn: FAIL death card would invent a delta line")
		return false
	print("Dawn: ok")
	return true


func _careful_band(catalog: Catalog) -> Dictionary:
	var lost := 0
	for run_seed in range(1, 61):
		var report: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(report.get("over", "")) != "time":
			lost += 1
			print("  careful seed %d over %s week %s" % [run_seed, report.get("over", ""), report.get("week", "")])
		elif run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return {"lost": lost}


func _fresh(catalog: Catalog, run_seed: int) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _spare(game: Game) -> Array:
	var ids: Array = []
	for person in game.residents:
		var id := str(person.id)
		if game._is_council(id) or game.cast_bio_locked(person):
			continue
		ids.append(id)
	return ids


func _departed(game: Game, id: String) -> Dictionary:
	for row in game.departed:
		if str(row.get("id", "")) == id:
			return row
	return {}


func _notice_has(game: Game, name: String) -> bool:
	for line in game.notices:
		if str(line).find(name) >= 0:
			return true
	return false


func _read_pack() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/named_lives.json"))
	return data if data is Dictionary else {}
