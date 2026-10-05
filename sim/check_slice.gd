extends SceneTree

## Headless checks for the slice: dawn queue, then the later gates as they land.
##   godot --headless --path . -s res://sim/check_slice.gd


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_queue(catalog):
		failed = true
	if not _check_power(catalog):
		failed = true
	if not _check_events(catalog):
		failed = true
	if not _check_crisis(catalog):
		failed = true
	if failed:
		print("SLICE FAIL")
		quit(1)
		return
	print("SLICE OK")
	quit(0)


func _check_queue(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	if game.over == "error":
		print("Queue: FAIL setup")
		return false
	if not _ids_once(game, "opening report"):
		return false
	var clog: Dictionary = {}
	for ev in catalog.events:
		if str(ev.id) == "clog":
			clog = ev
	if clog.is_empty():
		print("Queue: FAIL no clog")
		return false
	var before := game.pending.size()
	game._present_event(clog)
	game._present_event(clog)
	if game.pending.size() != before and _count_id(game, "clog") > 1:
		print("Queue: FAIL clog queued twice")
		return false
	if _count_id(game, "clog") > 1:
		print("Queue: FAIL duplicate clog")
		return false
	var guard := 0
	while not game.pending.is_empty() and guard < 8:
		guard += 1
		var front: Dictionary = game.front_event()
		var id := str(front.id)
		var choices: Array = []
		for choice in front.choices:
			choices.append(str(choice.id))
		if not game.dismiss_front():
			print("Queue: FAIL dismiss stuck on %s" % id)
			return false
		if not game.pending.is_empty():
			var nxt: Dictionary = game.front_event()
			if str(nxt.id) == id:
				print("Queue: FAIL close showed %s again" % id)
				return false
			var again := true
			if nxt.choices.size() == choices.size():
				for i in choices.size():
					if str(nxt.choices[i].id) != str(choices[i]):
						again = false
			else:
				again = false
			if again:
				print("Queue: FAIL same choices after close")
				return false
	if not game.pending.is_empty():
		print("Queue: FAIL queue did not empty")
		return false
	print("Queue: ok")
	return true


func _ids_once(game: Game, label: String) -> bool:
	var seen := {}
	for ev in game.pending:
		var id := str(ev.id)
		if seen.has(id):
			print("Queue: FAIL %s lists %s twice" % [label, id])
			return false
		seen[id] = true
	if game.modal_ids().size() != game.pending.size():
		print("Queue: FAIL %s modal ids collapsed a duplicate" % label)
		return false
	return true


func _count_id(game: Game, id: String) -> int:
	var n := 0
	for ev in game.pending:
		if str(ev.id) == id:
			n += 1
	return n


func _check_power(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	if game.over == "error":
		print("Power: FAIL setup ", game.errors)
		return false
	if not game.buildable_types().has("generator"):
		print("Power: FAIL generator missing from the build list")
		return false
	var defin: Dictionary = catalog.rooms.generator
	if int(defin.materials) > int(catalog.balance.start.materials):
		print("Power: FAIL generator costs more than the opening stores")
		return false
	if int(defin.build_turns) != 2:
		print("Power: FAIL generator is not a 2-week build")
		return false
	var gens := 0
	var staffed := false
	for room in game.rooms:
		if str(room.type) != "generator":
			continue
		gens += 1
		staffed = int(room.staff.size()) >= int(defin.staff_min)
	if gens != 1 or not staffed:
		print("Power: FAIL start layout wants one staffed generator")
		return false
	var preview: Dictionary = game.build_preview("generator", 2, 0)
	if not bool(preview.ok):
		print("Power: FAIL cannot build a generator on a dug cell: ", preview.reason)
		return false
	var types: Array = []
	for uid in game.power_order:
		var room = game._room(str(uid))
		types.append(str(room.type))
	if types.slice(0, 4) != ["air_filter", "hydroponics", "quarters", "workshop"]:
		print("Power: FAIL default priority ", types)
		return false
	if not game._brownout_ids().is_empty():
		print("Power: FAIL opening week browns out with a full store")
		return false
	for room in game.rooms:
		if str(room.type) == "generator":
			room.staff = []
	game.stock.power = 4
	var dark: Array = game._brownout_ids()
	var dark_types := {}
	for uid in dark:
		dark_types[str(game._room(str(uid)).type)] = true
	if dark_types.has("air_filter") or dark_types.has("hydroponics") or not dark_types.has("workshop"):
		print("Power: FAIL brownout did not keep the top of the list: ", dark_types.keys())
		return false
	if dark_types.has("quarters"):
		print("Power: FAIL quarters went dark")
		return false
	var bare := Game.new()
	bare.setup(catalog, 1, 40)
	for room in bare.rooms:
		if str(room.type) == "generator":
			if not bare.apply({"kind": "demolish", "room": str(room.uid)}):
				print("Power: FAIL could not clear the starter generator")
				return false
	bare.stock.power = 3
	var said := false
	for row in bare.forecasts():
		if str(row.key) == "power" and str(row.text).contains("Build a generator on a dug cell"):
			said = str(row.hint) == "build:generator"
	if not said:
		print("Power: FAIL forecast ", bare.forecasts())
		return false
	var before_power := int(bare.stock.power)
	var before_hope := bare.hope
	if not bare.apply({"kind": "burn"}):
		print("Power: FAIL burn salvage")
		return false
	if int(bare.stock.power) <= before_power or bare.hope >= before_hope:
		print("Power: FAIL burn did not trade materials for power and hope")
		return false
	var digger := Game.new()
	digger.setup(catalog, 1, 40)
	if not digger.apply({"kind": "dig", "level": 0, "cell": 2}):
		print("Power: FAIL dig the cable cell")
		return false
	var guard := 0
	while not digger.dig.is_empty() and guard < 4:
		guard += 1
		digger.end_week()
	var found := false
	for entry in digger.log:
		if str(entry.text).contains("old cable"):
			found = true
	if not found:
		print("Power: FAIL cable find")
		return false
	print("Power: ok")
	return true


func _check_events(catalog: Catalog) -> bool:
	if catalog.events.size() < 30:
		print("Events: FAIL pool %d" % catalog.events.size())
		return false
	var sasha := 0
	var chains := 0
	var names: Array = []
	for person in catalog.residents:
		names.append(str(person.name).split(" ")[0])
	var named := 0
	for ev in catalog.events:
		if bool(ev.get("sasha", false)):
			sasha += 1
		if str(ev.get("follow", "")) != "":
			chains += 1
		var free := false
		for choice in ev.choices:
			var cost = choice.get("cost", {})
			var empty := true
			if cost is Dictionary:
				for key in cost:
					if int(cost[key]) > 0:
						empty = false
			if empty:
				free = true
		if not free:
			print("Events: FAIL %s has no always-affordable choice" % str(ev.id))
			return false
		var blob := str(ev.text)
		var by = ev.get("by", {})
		if by is Dictionary:
			for key in by:
				blob += " " + str(by[key])
		for person_name in names:
			if blob.contains(str(person_name)):
				named += 1
				break
	if sasha < 9:
		print("Events: FAIL sasha %d" % sasha)
		return false
	if float(chains) < float(catalog.events.size()) / 3.0:
		print("Events: FAIL chains %d of %d" % [chains, catalog.events.size()])
		return false
	if named < 9:
		print("Events: FAIL named residents %d" % named)
		return false
	var game := Game.new()
	game.setup(catalog, 1, 40)
	var guard := 0
	while game.over == "" and guard < 42:
		guard += 1
		game.end_week()
	if int(game.stats.get("unaffordable_dawn", 0)) > 0:
		print("Events: FAIL a dawn had no affordable option")
		return false
	var seen := {}
	for row in game.event_history:
		var id := str(row.id)
		var at := int(row.week)
		if not seen.has(id):
			seen[id] = []
		for prior in seen[id]:
			if at == int(prior) or abs(at - int(prior)) < 8:
				print("Events: FAIL %s repeated at weeks %s and %d" % [id, str(prior), at])
				return false
		seen[id].append(at)
	for ev in catalog.events:
		if bool(ev.get("major", false)) or bool(ev.get("chain_only", false)):
			continue
		if int(game.event_times.get(str(ev.id), 0)) > 2:
			print("Events: FAIL %s appeared %d times" % [str(ev.id), int(game.event_times[str(ev.id)])])
			return false
	var chain := Game.new()
	chain.setup(catalog, 2, 40)
	var clog: Dictionary = chain._event_by_id("clog")
	chain.pending.clear()
	chain.week_event_ids = {}
	if not chain._present_event(clog):
		print("Events: FAIL could not present clog")
		return false
	if not chain.apply({"kind": "event", "event_id": "clog", "choice_id": "run"}):
		print("Events: FAIL clog choice")
		return false
	if chain.follows.is_empty():
		print("Events: FAIL clog did not schedule a follow-up")
		return false
	var due := int(chain.follows[0].due)
	var gap := due - chain.week
	if gap < 2 or gap > 6 or str(chain.follows[0].memory) != "run":
		print("Events: FAIL follow gap %d memory %s" % [gap, str(chain.follows[0].memory)])
		return false
	chain.week = due
	chain.pending.clear()
	chain.week_event_ids = {}
	chain._present_due_follows()
	var front: Dictionary = chain.front_event()
	if str(front.id) != "clog_next" or not str(front.text).contains("left the filter running"):
		print("Events: FAIL follow-up forgot the choice: ", front)
		return false
	print("Events: ok (%d in the pool)" % catalog.events.size())
	return true


func _check_crisis(catalog: Catalog) -> bool:
	for run_seed in [1, 2, 3, 4, 5]:
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		if str(game.pressure.get(game.crunch_week, "")) != "crunch":
			print("Crisis: FAIL seed %d crunch week %d is %s" % [run_seed, game.crunch_week, str(game.pressure.get(game.crunch_week, ""))])
			return false
		if not game.crisis_faults.is_empty():
			print("Crisis: FAIL ", game.crisis_faults)
			return false
		game.trade_on = true
		var posted := false
		for at in [8, 16, 24, 32]:
			if game._pressure_taken(at + 1) or game._pressure_taken(at + 2) or game.warning_weeks.has(at + 2):
				continue
			game.week = at
			var row: Dictionary = game._post_ultimatum("exchange")
			if row.is_empty() or game.demand_log.is_empty():
				continue
			var last: Dictionary = game.demand_log[game.demand_log.size() - 1]
			var span := int(last.span)
			if span < 2 or span > 3 or int(last.amount) != int(last.income) * span:
				print("Crisis: FAIL demand %s" % str(last))
				return false
			if game.warning_weeks.has(int(last.deadline_week)):
				print("Crisis: FAIL warning shares week %d with a deadline" % int(last.deadline_week))
				return false
			posted = true
			break
		if not posted:
			print("Crisis: FAIL seed %d had no quiet week for an ultimatum" % run_seed)
			return false
		var guard := 0
		game.week = 1
		while game.over == "" and guard < 42:
			guard += 1
			game.end_week()
		if not game.crisis_faults.is_empty():
			print("Crisis: FAIL ", game.crisis_faults)
			return false
	print("Crisis: ok")
	return true
