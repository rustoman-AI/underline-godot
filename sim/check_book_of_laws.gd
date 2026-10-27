extends SceneTree

## Headless gate for Book of Laws (P72, DEC-L1…L4).
##   godot --headless --path . -s res://sim/check_book_of_laws.gd
##   godot --headless --path . -s res://sim/check_book_of_laws.gd -- --logic
##   godot --headless --path . -s res://sim/check_book_of_laws.gd -- --seeds=60

const SEEDS := 60
const LOSS_LO := 9
const LOSS_HI := 21
const PROFILES := ["careful", "watch", "chapel", "market"]
const DAWN := ["rumor", "border.dawn_new", "rail", "homecoming"]


func _init() -> void:
	var logic_only := false
	var seeds := SEEDS
	for arg in OS.get_cmdline_user_args():
		if str(arg) == "--logic":
			logic_only = true
		elif str(arg).begins_with("--seeds="):
			seeds = maxi(1, int(str(arg).trim_prefix("--seeds=")))
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Strings: fail")
		print("Adaptation: fail")
		print("Creed: fail")
		print("Line: fail")
		print("Week6: fail")
		print("Dawn: fail")
		print("careful 0/%d; watch 0/%d; chapel 0/%d; market 0/%d" % [seeds, seeds, seeds, seeds])
		print("BOOK OF LAWS FAIL")
		print(catalog.error)
		quit(1)
		return
	var strings_ok := _strings()
	var adapt_ok := _adaptation(catalog)
	var creed_ok := _creed(catalog)
	var line_ok := _line(catalog)
	var week_ok := _week6(catalog)
	var dawn_ok := _dawn()
	var lost := {"careful": -1, "watch": -1, "chapel": -1, "market": -1}
	var loss_ok := false
	if logic_only:
		print("logic only — loss band not run")
	else:
		var run := _losses(catalog, seeds)
		lost = run.lost
		loss_ok = bool(run.ok)
		for note in run.notes:
			print(note)
	print("Strings: %s" % ("ok" if strings_ok else "fail"))
	print("Adaptation: %s" % ("ok" if adapt_ok else "fail"))
	print("Creed: %s" % ("ok" if creed_ok else "fail"))
	print("Line: %s" % ("ok" if line_ok else "fail"))
	print("Week6: %s" % ("ok" if week_ok else "fail"))
	if dawn_ok:
		print("Dawn: ok  (soft dawn unchanged — P72 does not join)")
	else:
		print("Dawn: fail")
	if logic_only:
		print("careful -/%d; watch -/%d; chapel -/%d; market -/%d" % [seeds, seeds, seeds, seeds])
	else:
		print("careful %d/%d; watch %d/%d; chapel %d/%d; market %d/%d" % [
			lost.careful, seeds, lost.watch, seeds, lost.chapel, seeds, lost.market, seeds])
	var ok := strings_ok and adapt_ok and creed_ok and line_ok and week_ok and dawn_ok and not logic_only and loss_ok
	if logic_only and strings_ok and adapt_ok and creed_ok and line_ok and week_ok and dawn_ok:
		print("LOGIC ONLY")
		quit(0)
		return
	print("BOOK OF LAWS OK" if ok else "BOOK OF LAWS FAIL")
	quit(0 if ok else 1)


func _strings() -> bool:
	var rows := {
		"law.tab_adaptation": ["Adaptation", "Приспособление"],
		"law.tab_creed": ["Creed", "Кредо"],
		"law.week6": ["The platform asks what we stand for.", "Платформа спрашивает, за что мы стоим."],
		"law.week6_title": ["What we stand for", "За что мы стоим"],
		"law.week6_body": ["Week six. The meeting hall is full. Adaptation has kept us alive. Now the platform wants a creed — or none, and the Engineers' Charter holds the root.", "Шестая неделя. Зал собраний полон. Приспособление нас продержало. Теперь платформа хочет кредо — или никакого, и корень останется за Уставом инженеров."],
		"law.week6_open": ["Open the Creed", "Открыть кредо"],
		"law.week6_later": ["Later", "Позже"],
		"law.line_confirm_title": ["Permanent line", "Постоянная линия"],
		"law.line_confirm": ["This line is permanent. Enact?", "Эта линия постоянна. Ввести?"],
		"law.line_need_influence": ["Needs 10 influence.", "Нужно 10 влияния."],
		"law.influence_short": ["Not enough influence.", "Не хватает влияния."],
		"law.locked_path": ["Locked — another creed was chosen.", "Закрыто — выбрано другое кредо."],
		"law.requires_row": ["Needs a law from the row above.", "Нужен закон из ряда выше."],
		"law.creed_locked_week": ["Creed opens at week 6.", "Кредо открывается на 6-й неделе."],
		"law.need_hall": ["Needs a staffed meeting hall.", "Нужен укомплектованный зал собраний."],
		"law.cooldown": ["Meeting hall cooling down — {n} weeks.", "Зал собраний остывает — {n} нед."],
		"law.enact_tip": ["Pass this law. Next sitting in {n} weeks.", "Принять этот закон. Следующее заседание через {n} нед."],
		"law.in_force": ["In force.", "Действует."],
		"creed.watch": ["Watch", "Дозор"],
		"creed.chapel": ["Chapel", "Часовня"],
		"creed.market": ["Market", "Рынок"],
		"creed.none_hint": ["No creed — Depot holds.", "Без кредо — держит Депо."],
		"law.name.soup_line": ["Soup line", "Суповая очередь"],
		"law.name.night_shift": ["Night shift", "Ночная смена"],
		"law.name.triage": ["Triage", "Сортировка"],
		"law.name.quarantine": ["Quarantine all", "Всеобщий карантин"],
		"law.name.burial_tunnel": ["Burial tunnel", "Погребальный ход"],
		"law.name.informers": ["Informers", "Доносчики"],
		"law.name.timetable": ["Timetable", "Расписание"],
		"law.name.chapel_shift": ["Chapel shift", "Церковная смена"],
		"law.name.penance": ["Penance", "Покаяние"],
		"law.name.covenant": ["Covenant", "Завет"],
		"law.name.token_wages": ["Token wages", "Жетонная плата"],
		"law.name.everything_has_a_price": ["Everything has a price", "У всего есть цена"],
	}
	var bad := false
	for key in rows:
		var pair: Array = rows[key]
		Copy.set_lang("en")
		if Copy.t(key) != str(pair[0]):
			print("string en %s -> %s" % [key, Copy.t(key)])
			bad = true
		Copy.set_lang("ru")
		if Copy.t(key) != str(pair[1]):
			print("string ru %s -> %s" % [key, Copy.t(key)])
			bad = true
	Copy.set_lang("en")
	for law_id in ["timetable", "covenant", "everything_has_a_price"]:
		var key: String = "law.line_text." + str(law_id)
		if Copy.t(key) == key or Copy.t(key).length() < 40:
			print("string line text short " + key)
			bad = true
		Copy.set_lang("ru")
		var ru := Copy.t(key)
		Copy.set_lang("en")
		if ru == Copy.t(key) or ru.length() < 40:
			print("string line ru " + key)
			bad = true
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("func _ask_line") < 0 or ui.find("law.line_text.") < 0 or ui.find("law.line_confirm") < 0:
		print("string confirm not in station")
		bad = true
	if ui.find("why.influence") >= 0 and ui.find("law.influence_short") < 0:
		print("string influence tip reopened P65")
		bad = true
	return not bad


func _adaptation(catalog: Catalog) -> bool:
	if int(catalog.balance.get("law_cooldown", 0)) != 3:
		print("adapt cooldown %s" % str(catalog.balance.get("law_cooldown", 0)))
		return false
	var laws: Dictionary = catalog.laws
	if not _num(laws, "rationing", "food_mult", 0.75) or int(laws.rationing.hope_week) != -1 or int(laws.rationing.discontent_on_enact) != 5:
		print("adapt rationing numbers")
		return false
	if not _num(laws, "soup_line", "food_mult", 0.9) or int(laws.soup_line.discontent_week) != -1 or not bool(laws.soup_line.cook):
		print("adapt soup numbers")
		return false
	if not _num(laws, "double_shifts", "prod_mult", 1.4) or not _num(laws, "double_shifts", "sick_chance", 0.1):
		print("adapt shifts numbers")
		return false
	if not _num(laws, "night_shift", "room_mult", 1.15) or int(laws.night_shift.discontent_on_enact) != 2:
		print("adapt night numbers")
		return false
	if int(laws.triage.cure_bonus) != 1 or int(laws.triage.cough_per) != 4:
		print("adapt triage numbers")
		return false
	if not _num(laws, "quarantine", "spread_mult", 0.5) or not _num(laws, "quarantine", "output_mult", 0.9) or int(laws.quarantine.sick_at) != 3:
		print("adapt quarantine numbers")
		return false
	if int(laws.burial_tunnel.materials_cost) != 6 or int(laws.burial_tunnel.needs_level) != 3 or int(laws.burial_tunnel.burial_hope) != 1:
		print("adapt burial numbers")
		return false
	if str(laws.engineers_charter.tab) != "depot" or str(laws.engineers_charter.row) != "" or bool(laws.engineers_charter.repealable):
		print("adapt charter is a fork")
		return false
	var rows := {
		"food": ["rationing", "soup_line", ""],
		"work": ["double_shifts", "night_shift", "food"],
		"sickness": ["triage", "quarantine", "work"],
		"dead": ["ledger", "burial_tunnel", "sickness"],
	}
	for row in rows:
		var pair: Array = rows[row]
		for law_id in [str(pair[0]), str(pair[1])]:
			var defin: Dictionary = laws[law_id]
			if str(defin.tab) != "adapt" or str(defin.row) != row or str(defin.requires_row) != str(pair[2]):
				print("adapt row %s %s" % [row, law_id])
				return false
			if not (defin.locks is Array) or not defin.locks.has(str(pair[0]) if law_id == str(pair[1]) else str(pair[1])):
				print("adapt lock %s" % law_id)
				return false
	if bool(laws.ledger.repealable):
		print("adapt ledger repeals")
		return false
	var game := _fresh(catalog)
	if not game.laws_on.has("engineers_charter"):
		print("adapt charter not in force")
		return false
	if game.enact_reason("rationing") != Copy.t("law.need_hall"):
		print("adapt hall %s" % game.enact_reason("rationing"))
		return false
	_staff(game)
	game.week = 4
	if game.enact_reason("double_shifts") != Copy.t("law.requires_row"):
		print("adapt work early %s" % game.enact_reason("double_shifts"))
		return false
	if game.enact_reason("triage") != Copy.t("law.requires_row") or game.enact_reason("ledger") != Copy.t("law.requires_row"):
		print("adapt lower early")
		return false
	if not game.can_enact("rationing") or not game.can_enact("soup_line"):
		print("adapt food closed %s / %s" % [game.enact_reason("rationing"), game.enact_reason("soup_line")])
		return false
	if not game.apply({"kind": "law", "law": "rationing"}):
		print("adapt rationing refused")
		return false
	if game.enact_reason("soup_line") != Copy.t("law.fork_taken"):
		print("adapt fork %s" % game.enact_reason("soup_line"))
		return false
	if game.law_lock != 3:
		print("adapt lock %d" % game.law_lock)
		return false
	if game.enact_reason("double_shifts") != Copy.fill("law.cooldown", {"n": 3}):
		print("adapt cooldown %s" % game.enact_reason("double_shifts"))
		return false
	game.law_lock = 0
	if not game.can_enact("double_shifts") or not game.can_enact("night_shift"):
		print("adapt work still locked")
		return false
	if not game.apply({"kind": "law", "law": "night_shift"}):
		print("adapt night refused")
		return false
	game.law_lock = 0
	if game.enact_reason("double_shifts") != Copy.t("law.fork_taken"):
		print("adapt work fork %s" % game.enact_reason("double_shifts"))
		return false
	if not game.can_enact("triage"):
		print("adapt triage %s" % game.enact_reason("triage"))
		return false
	if game.enact_reason("ledger") != Copy.t("law.requires_row"):
		print("adapt dead early %s" % game.enact_reason("ledger"))
		return false
	var bare := game.food_need()
	game.laws_on.erase("rationing")
	var open := game.food_need()
	game.laws_on["rationing"] = true
	if open > 0 and bare != int(round(float(open) * 0.75)):
		print("adapt food %d vs %d" % [bare, open])
		return false
	var cook := _fresh(catalog)
	_staff(cook)
	if not cook.apply({"kind": "law", "law": "soup_line"}):
		print("adapt soup refused")
		return false
	var cooks := 0
	for person in cook.residents:
		if bool(person.get("soup_cook", false)):
			cooks += 1
	if cooks != 1:
		print("adapt cooks %d" % cooks)
		return false
	return true


func _creed(catalog: Catalog) -> bool:
	var laws: Dictionary = catalog.laws
	var chains := {
		"watch": ["curfew", "conscription", "informers", "timetable"],
		"chapel": ["sermons", "chapel_shift", "penance", "covenant"],
		"market": ["open_market", "tunnel_tax", "token_wages", "everything_has_a_price"],
	}
	for branch in chains:
		var steps: Array = chains[branch]
		for i in steps.size():
			var defin: Dictionary = laws[str(steps[i])]
			if str(defin.tab) != "creed" or str(defin.branch) != branch or int(defin.step) != i + 1:
				print("creed shape %s" % str(steps[i]))
				return false
			if i == 0 and str(defin.requires) != "":
				print("creed root requires %s" % str(steps[i]))
				return false
			if i > 0 and str(defin.requires) != str(steps[i - 1]):
				print("creed requires %s" % str(steps[i]))
				return false
			if i == 3 and not bool(defin.line):
				print("creed line flag %s" % str(steps[i]))
				return false
		var root: Dictionary = laws[str(steps[0])]
		for other in chains:
			if other == branch:
				continue
			if not (root.locks is Array) or not root.locks.has(other):
				print("creed locks %s missing %s" % [branch, other])
				return false
	if int(laws.curfew.regard.directorate) != 10 or int(laws.curfew.regard.exchange) != -5:
		print("creed watch regard")
		return false
	if int(laws.sermons.regard.synod) != 10 or int(laws.sermons.regard.penn) != -10:
		print("creed chapel regard")
		return false
	if int(laws.open_market.regard.exchange) != 10 or int(laws.open_market.regard.directorate) != -5:
		print("creed market regard")
		return false
	if int(laws.informers.discontent_week) != -3 or int(laws.informers.mood_week) != -2 or int(laws.informers.warn_sooner) != 1:
		print("creed informers numbers")
		return false
	var game := _fresh(catalog)
	_staff(game)
	game.week = 5
	if game.enact_reason("curfew") != Copy.t("law.creed_locked_week"):
		print("creed week %s" % game.enact_reason("curfew"))
		return false
	if game.can_enact("sermons") or game.can_enact("open_market"):
		print("creed opened early")
		return false
	game.week = 6
	if not game.can_enact("curfew") or not game.can_enact("sermons") or not game.can_enact("open_market"):
		print("creed week6 closed")
		return false
	if game.enact_reason("conscription") != Copy.t("law.requires_row"):
		print("creed step %s" % game.enact_reason("conscription"))
		return false
	var bot := Bot.new()
	bot.profile = "watch"
	var early: Dictionary = bot._creed_project(game)
	game.week = 5
	if not bot._creed_project(game).is_empty():
		print("creed bot early")
		return false
	game.week = 6
	early = bot._creed_project(game)
	if str(early.get("law", "")) != "curfew":
		print("creed bot %s" % str(early))
		return false
	var dir_before := int(game.opinions.get("directorate", 0))
	var ex_before := int(game.opinions.get("exchange", 0))
	if not game.apply({"kind": "law", "law": "curfew"}):
		print("creed curfew refused")
		return false
	if game.creed != "watch":
		print("creed set %s" % game.creed)
		return false
	if int(game.opinions.get("directorate", 0)) != dir_before + 10 or int(game.opinions.get("exchange", 0)) != ex_before - 5:
		print("creed opinions %s %s" % [str(game.opinions.get("directorate")), str(game.opinions.get("exchange"))])
		return false
	if game.enact_reason("sermons") != Copy.t("law.locked_path") or game.enact_reason("open_market") != Copy.t("law.locked_path"):
		print("creed lock %s / %s" % [game.enact_reason("sermons"), game.enact_reason("open_market")])
		return false
	var chapel := _fresh(catalog)
	_staff(chapel)
	chapel.week = 6
	var synod_meter := int(chapel.synod)
	var standing_before := int(chapel.standing.get("synod", 0))
	var penn_before := int(chapel.stations.foundry.get("sympathy", 0))
	if not chapel.apply({"kind": "law", "law": "sermons"}):
		print("creed sermons refused")
		return false
	if int(chapel.standing.get("synod", 0)) != standing_before + 10:
		print("creed synod standing %s" % str(chapel.standing.get("synod")))
		return false
	if int(chapel.synod) != synod_meter:
		print("creed synod meter moved %d -> %d" % [synod_meter, int(chapel.synod)])
		return false
	if int(chapel.stations.foundry.get("sympathy", 0)) != clampi(penn_before - 10, -100, 100):
		print("creed penn %s" % str(chapel.stations.foundry.get("sympathy")))
		return false
	if chapel.enact_reason("curfew") != Copy.t("law.locked_path"):
		print("creed chapel did not lock watch")
		return false
	var other := _fresh(catalog)
	if other.creed != "":
		print("creed leaked across runs")
		return false
	return true


func _line(catalog: Catalog) -> bool:
	var laws: Dictionary = catalog.laws
	if int(laws.timetable.influence) != 10 or int(laws.timetable.hope_hold) != 20 or int(laws.timetable.line_discontent) != 80 or int(laws.timetable.line_hope) != -2:
		print("line timetable numbers")
		return false
	if bool(laws.timetable.repealable) or bool(laws.covenant.repealable) or bool(laws.everything_has_a_price.repealable):
		print("line repealable")
		return false
	if int(laws.covenant.hope_floor) != 25 or not bool(laws.covenant.synod_pact) or int(laws.covenant.regard.directorate) != -20:
		print("line covenant numbers")
		return false
	if int(laws.everything_has_a_price.sell_tokens) != 15 or int(laws.everything_has_a_price.migrant_tokens) != 20 or int(laws.everything_has_a_price.hope_tokens) != 10:
		print("line price numbers")
		return false
	if int(laws.token_wages.token_each) != 1 or int(laws.token_wages.paid_discontent) != -2 or int(laws.token_wages.unpaid_discontent) != 6:
		print("line wages numbers")
		return false
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("func _ask_line") < 0 or ui.find("func _confirm") < 0:
		print("line confirm missing")
		return false
	var game := _fresh(catalog)
	_staff(game)
	game.week = 6
	for step in ["curfew", "conscription", "informers"]:
		game.law_lock = 0
		if not game.apply({"kind": "law", "law": step}):
			print("line step %s %s" % [step, game.enact_reason(step)])
			return false
	game.law_lock = 0
	game.stock.influence = 4
	if game.enact_reason("timetable") != Copy.t("law.influence_short"):
		print("line short %s" % game.enact_reason("timetable"))
		return false
	if game.apply({"kind": "law", "law": "timetable"}):
		print("line enacted without influence")
		return false
	game.stock.influence = 10
	if not game.apply({"kind": "law", "law": "timetable"}):
		print("line refused %s" % game.enact_reason("timetable"))
		return false
	if int(game.stock.influence) != 0 or game.repeal_reason("timetable") != Copy.t("It cannot be repealed."):
		print("line spend/repeal inf %d %s" % [int(game.stock.influence), game.repeal_reason("timetable")])
		return false
	var sq: Dictionary = game.squads[game.player]
	sq.away = false
	sq.station = str(game.capital_id)
	game.hope = 20
	game.discontent = 100
	game.over = ""
	if not game._timetable_holds():
		print("line hold failed")
		return false
	game._finish_checks()
	if game.over != "":
		print("line revolt while timetable holds (%s)" % game.over)
		return false
	sq.away = true
	if game._timetable_holds():
		print("line holds while squad is away")
		return false
	game.hope = 19
	sq.away = false
	if game._timetable_holds():
		print("line holds under hope 20")
		return false
	var chapel := _fresh(catalog)
	chapel.laws_on["covenant"] = true
	chapel.laws_on["sermons"] = true
	chapel.hope = 40
	chapel._add_hope(-30, "law")
	if chapel.hope != 25:
		print("line hope floor %d" % chapel.hope)
		return false
	if chapel.repeal_reason("sermons") != Copy.t("It cannot be repealed."):
		print("line sermons repeal %s" % chapel.repeal_reason("sermons"))
		return false
	var none := _fresh(catalog)
	var with_depot := none.score_now()
	none.creed = "watch"
	if with_depot != none.score_now() + 50:
		print("line depot score %d vs %d" % [with_depot, none.score_now()])
		return false
	return true


func _week6(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	game.pending.clear()
	game.week = 5
	game._offer_week6_creed()
	if not game.pending.is_empty():
		print("week6 early")
		return false
	game.week = 6
	game.pending.clear()
	game._offer_week6_creed()
	if game.pending.is_empty():
		print("week6 missing")
		return false
	var ev: Dictionary = game.pending[0]
	if str(ev.id) != "law_week6" or not bool(ev.get("major", false)):
		print("week6 shape %s" % str(ev.get("id", "")))
		return false
	if not game.event_is_big(ev):
		print("week6 not a dawn card")
		return false
	var ids: PackedStringArray = []
	for choice in ev.choices:
		ids.append(str(choice.id))
	if ids != PackedStringArray(["open", "later"]):
		print("week6 choices %s" % str(ids))
		return false
	var text := str(ev.text.get("en", ""))
	if not text.contains(Copy.t("law.week6")) or not text.contains(Copy.t("law.week6_body")):
		print("week6 text")
		return false
	var before := game.pending.size()
	game._offer_week6_creed()
	if game.pending.size() != before or not bool(game.flags.get("law_week6", false)):
		print("week6 repeated")
		return false
	if game.book_joins_soft_dawn():
		print("week6 joined soft dawn")
		return false
	for chip in game.dawn_soft_stack():
		if str(chip).find("week6") >= 0 or str(chip).find("law") >= 0:
			print("week6 chip %s" % str(chip))
			return false
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	if ui.find("law_week6") < 0 or ui.find("laws_open_after") < 0:
		print("week6 ui")
		return false
	return true


func _dawn() -> bool:
	if Game.DAWN_SOFT_STACK != DAWN:
		print("dawn stack %s" % str(Game.DAWN_SOFT_STACK))
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var nxt := src.find("\nfunc ", at + 10)
	var body := src.substr(at, nxt - at)
	if body.find("week6") >= 0 or body.find("law_week6") >= 0 or body.find("book_of_laws") >= 0:
		print("dawn picker joined")
		return false
	var game := Game.new()
	if game.book_joins_soft_dawn():
		print("dawn book joined")
		return false
	if game.dawn_soft_stack() != DAWN:
		print("dawn instance stack")
		return false
	return true


func _losses(catalog: Catalog, seeds: int) -> Dictionary:
	var lost := {"careful": 0, "watch": 0, "chapel": 0, "market": 0}
	var notes: PackedStringArray = []
	var bad := false
	for seed in range(1, seeds + 1):
		for profile in PROFILES:
			var row: Dictionary = Bot.new().play(40, seed, profile, catalog)
			if str(row.get("over", "")) != "time":
				lost[profile] += 1
			var errors: Array = row.get("errors", [])
			if not errors.is_empty():
				bad = true
				if notes.size() < 8:
					notes.append("loss error %s seed %d %s" % [profile, seed, str(errors[0])])
		if seed % 10 == 0:
			print("seeds %d careful %d watch %d chapel %d market %d" % [seed, lost.careful, lost.watch, lost.chapel, lost.market])
	var ok := not bad
	for profile in PROFILES:
		var n := int(lost[profile])
		if n < LOSS_LO or n > LOSS_HI:
			ok = false
			notes.append("band %s %d/%d outside %d-%d" % [profile, n, seeds, LOSS_LO, LOSS_HI])
	return {"lost": lost, "ok": ok, "notes": notes}


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	return game


func _staff(game: Game) -> void:
	var who := ""
	for person in game.residents:
		if game._is_child(person):
			continue
		who = str(person.id)
		break
	game.rooms.append({
		"uid": "law_test_hall", "type": "meeting_hall", "level": 2, "cell": 5,
		"upgrade": 0, "efficiency": 1.0, "staff": [who], "offline": false, "browned": false,
		"disabled": 0, "switched_off": false, "push_weeks": [], "push_tint_until": 0,
	})
	game.law_lock = 0


func _num(laws: Dictionary, law_id: String, key: String, want: float) -> bool:
	return is_equal_approx(float(laws[law_id].get(key, -999)), want)
