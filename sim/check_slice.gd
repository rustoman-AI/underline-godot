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
