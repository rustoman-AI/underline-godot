extends SceneTree

## P100 Keep the Lights. Projection parity, panel behavior, schema 27.
##   godot --headless --path . -s res://sim/check_keep_the_lights.gd
## Headless logic must pass. Screenshots print SKIP without a renderer.
##   UNDERLINE_SHOTS_DIR=/opt/cursor/artifacts godot --rendering-driver opengl3 --path . -s res://sim/check_keep_the_lights.gd

const EN := {
	"cutplan.compare": "Compare",
	"cutplan.title": "Compare power priority",
	"cutplan.now": "Current order",
	"cutplan.after": "With this move",
	"cutplan.up": "Compare up",
	"cutplan.down": "Compare down",
	"cutplan.apply_up": "Move up",
	"cutplan.apply_down": "Move down",
	"cutplan.keep": "Keep current",
	"cutplan.gains": "No longer cut",
	"cutplan.losses": "Newly cut",
	"cutplan.unchanged": "No allocation change.",
	"cutplan.cut": "Cut by priority",
	"cutplan.within": "Within allocation",
	"cutplan.not_drawing": "No competing draw",
	"cutplan.budget": "Pool after generator use: {power}. Reserve allocations: {spares}.",
	"cutplan.draw": "Group draw: {draw}",
	"cutplan.scope": "Current conditions only. Changes before night can change the allocation.",
	"cutplan.changed": "Conditions or neighbors changed. Compare again before moving.",
	"cutplan.unavailable": "Allocation comparison unavailable. Original move controls still work.",
	"cutplan.group": "The first eligible linked room sets the group's priority.",
	"cutplan.reserve": "A reserve allocation can cover a group without spending the remaining pool.",
	"cutplan.swap_up": "Move {room} ahead of {other}.",
	"cutplan.swap_down": "Move {room} behind {other}.",
}

var catalog: Catalog
var failed := false
var _shots_skipped := false
var _shots_saved := 0
var _balance := ""


class YieldSpy extends Game:
	var calls := 0

	func _generator_yield() -> int:
		calls += 1
		return super._generator_yield()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("CUTPLAN FAIL catalog")
		quit(1)
		return
	_balance = FileAccess.get_file_as_string("res://data/balance.json")
	_strings()
	_schema()
	_source()
	_worked()
	_fixtures()
	_reserve()
	_yield_and_flags()
	_replay()
	_random_live()
	if FileAccess.get_file_as_string("res://data/balance.json") != _balance:
		_bad("balance.json changed")
	if not failed:
		await _ui()
	Copy.set_lang("en")
	Cutplan.force_fail = false
	if failed:
		print("CUTPLAN FAIL")
		quit(1)
		return
	print("CUTPLAN OK")
	if _shots_skipped:
		print("CUTPLAN SHOTS SKIP")
	elif _shots_saved > 0:
		print("CUTPLAN SHOTS OK %d" % _shots_saved)
	else:
		_bad("screenshots neither saved nor skipped")
		print("CUTPLAN FAIL")
		quit(1)
		return
	quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_bad(msg)


func _records(game: Game) -> void:
	game.records_path = "user://check_keep_the_lights_%d.cfg" % OS.get_process_id()


func _boot(run_seed: int = 1) -> Game:
	var game := Game.new()
	_records(game)
	game.setup(catalog, run_seed, 40)
	game.laws_on.erase("engineers_charter")
	game.crunch_power = false
	game.active_season = {}
	game.belt_down = false
	game.workshop_down = false
	game.gen_down = false
	return game


func _by_type(game: Game) -> Dictionary:
	var out := {}
	for room in game.rooms:
		var key := str(room.type)
		if not out.has(key):
			out[key] = []
		out[key].append(str(room.uid))
	return out


func _uid(game: Game, type: String, nth: int = 0) -> String:
	var rows: Array = _by_type(game).get(type, [])
	if nth < 0 or nth >= rows.size():
		return ""
	return str(rows[nth])


func _offline_except(game: Game, keep: Array) -> void:
	var live := {}
	for uid in keep:
		live[str(uid)] = true
	for room in game.rooms:
		room.offline = not live.has(str(room.uid))


func _worked_game() -> Game:
	var game := _boot()
	game.stock.power = 3
	if _uid(game, "infirmary") == "":
		game._place_room("infirmary", 2, 0)
	var order := [
		_uid(game, "air_filter"),
		_uid(game, "hydroponics"),
		_uid(game, "infirmary"),
		_uid(game, "platform"),
	]
	_offline_except(game, order)
	for room in game.rooms:
		if str(room.type) == "generator":
			room.offline = true
	game.power_order = order
	return game


func _ids(rows) -> Array:
	var out: Array = []
	for id in rows:
		out.append(str(id))
	out.sort()
	return out


func _isolate(game: Game) -> Game:
	var ghost := Game.new()
	ghost.catalog = game.catalog
	ghost.bal = game.bal.duplicate(true)
	_records(ghost)
	var snap: Dictionary = game.export_state()
	for key in Game.PERSIST:
		var value = snap[key]
		if value is Array or value is Dictionary:
			ghost.set(key, value.duplicate(true))
		else:
			ghost.set(key, value)
	var linked: Array = []
	for person in ghost.residents:
		if person is Dictionary and ghost.people.has(str(person.get("id", ""))):
			linked.append(ghost.people[str(person.id)])
		else:
			linked.append(person)
	ghost.residents = linked
	ghost.rng.state = game.rng.state
	ghost.crunch_rng.state = game.crunch_rng.state
	ghost.net_rng.state = game.net_rng.state
	ghost.check_rng.state = game.check_rng.state
	ghost.story_rng.state = game.story_rng.state
	return ghost


func _spy(game: Game) -> YieldSpy:
	var spy := YieldSpy.new()
	spy.catalog = game.catalog
	spy.bal = game.bal.duplicate(true)
	_records(spy)
	var snap: Dictionary = game.export_state()
	for key in Game.PERSIST:
		var value = snap[key]
		if value is Array or value is Dictionary:
			spy.set(key, value.duplicate(true))
		else:
			spy.set(key, value)
	var linked: Array = []
	for person in spy.residents:
		if person is Dictionary and spy.people.has(str(person.get("id", ""))):
			linked.append(spy.people[str(person.id)])
		else:
			linked.append(person)
	spy.residents = linked
	spy.calls = 0
	return spy


func _flags(game: Game) -> Array:
	var out: Array = []
	for room in game.rooms:
		out.append(bool(room.get("browned", false)))
	return out


func _rng(game: Game) -> String:
	return "%s|%s|%s|%s|%s" % [game.rng.state, game.crunch_rng.state, game.net_rng.state, game.check_rng.state, game.story_rng.state]


func _dark_of(game: Game, order: Array) -> Array:
	var iso := _isolate(game)
	iso.power_order = order.duplicate()
	return _ids(iso._brownout_ids())


func _expect_match(game: Game, order: Array, label: String) -> void:
	var fp := Cutplan.fingerprint(game)
	var flags: Array = _flags(game)
	var rng := _rng(game)
	var decisions := int(game.decisions)
	var live: Array = game.power_order.duplicate()
	var proj: Dictionary = Cutplan.project(game, order)
	_ok(bool(proj.get("ok", false)), label + " projection unavailable")
	if not bool(proj.get("ok", false)):
		return
	_ok(_ids(proj.dark) == _dark_of(game, order), label + " dark %s vs %s" % [str(_ids(proj.dark)), str(_dark_of(game, order))])
	_ok(Cutplan.fingerprint(game) == fp, label + " mutated export")
	_ok(_flags(game) == flags, label + " browned flags changed")
	_ok(_rng(game) == rng, label + " rng moved")
	_ok(int(game.decisions) == decisions, label + " decisions moved")
	_ok(game.power_order == live, label + " live order swapped")


func _strings() -> void:
	_ok(Cutplan.KEYS.size() == 24 and EN.size() == 24, "key count %d" % Cutplan.KEYS.size())
	Copy.set_lang("en")
	for key in Cutplan.KEYS:
		_ok(EN.has(key), "missing spec " + key)
		_ok(Cutplan.line(key) == str(EN[key]), "en %s got %s" % [key, Cutplan.line(key)])
		_ok(not Cutplan.line(key).begins_with("cutplan."), "raw en " + key)
	_ok(Cutplan.locale_ready(), "en locale not ready")
	Copy.set_lang("ru")
	_ok(not Cutplan.locale_ready(), "ru showed compare")
	for key in Cutplan.KEYS:
		_ok(Cutplan.line(key) == "", "ru not empty " + key)
		_ok(Copy.t(key) == str(EN[key]), "ru Copy.t fell through to the key " + key)
	Copy.set_lang("en")
	print("Strings: 24 en, ru empty")


func _schema() -> void:
	_ok(Game.SAVE_SCHEMA == 27, "schema %s" % str(Game.SAVE_SCHEMA))
	for key in Game.PERSIST:
		_ok(not str(key).begins_with("cutplan"), "persist " + str(key))
	var game := _boot()
	var snap: Dictionary = game.export_state()
	for key in snap:
		_ok(not str(key).begins_with("cutplan"), "export " + str(key))
	print("Schema 27, no cutplan field")


func _source() -> void:
	var body := FileAccess.get_file_as_string("res://sim/cutplan.gd")
	_ok(body.find("_uncovered_power_ids") < 0, "projection uses uncovered power")
	_ok(body.find("_mark_brownout") < 0, "projection stamps brownout")
	_ok(body.find(".apply(") < 0, "projection calls apply")
	var ui := FileAccess.get_file_as_string("res://ui/station.gd")
	_ok(ui.find("{\"kind\": \"power\", \"room\": uid, \"up\": up}") >= 0, "move is not the power command")
	print("Source: brownout path, no uncovered helper")


func _worked() -> void:
	var game := _worked_game()
	var hydro := _uid(game, "hydroponics")
	var filt := _uid(game, "air_filter")
	var inf := _uid(game, "infirmary")
	var plat := _uid(game, "platform")
	var now: Dictionary = Cutplan.project(game, game.power_order)
	_ok(bool(now.get("ok", false)), "worked now unavailable")
	_ok(int(now.get("pool", -1)) == 3, "worked pool %s" % str(now.get("pool", -1)))
	_ok(int(now.get("spares", -1)) == 0, "worked spare %s" % str(now.get("spares", -1)))
	_ok(_ids(now.get("dark", [])) == _ids([hydro, plat]), "worked dark %s" % str(_ids(now.get("dark", []))))
	_ok(not _ids(now.dark).has(filt) and not _ids(now.dark).has(inf), "worked cut a lit room")
	var up_order: Array = Cutplan.swapped(game.power_order, hydro, true)
	_ok(up_order[0] == hydro and up_order[1] == filt, "worked swap order")
	_ok(game.power_order[0] == filt, "swapped() wrote the live order")
	var cand: Dictionary = Cutplan.project(game, up_order)
	_ok(_ids(cand.get("dark", [])) == _ids([filt, plat]), "worked up dark %s" % str(_ids(cand.get("dark", []))))
	_ok(not _ids(cand.dark).has(hydro) and not _ids(cand.dark).has(inf), "worked up lit set")
	var back: Array = Cutplan.swapped(up_order, hydro, false)
	var restored: Dictionary = Cutplan.project(game, back)
	_ok(_ids(restored.get("dark", [])) == _ids(now.dark), "worked not reversible")
	var down: Dictionary = Cutplan.project(game, Cutplan.swapped(game.power_order, hydro, false))
	_ok(_ids(down.get("dark", [])) == _ids([hydro, plat]), "worked down dark %s" % str(_ids(down.get("dark", []))))
	var fp := Cutplan.fingerprint(game)
	var decisions := int(game.decisions)
	_ok(Cutplan.fingerprint(game) == fp and int(game.decisions) == decisions, "worked browse mutated")
	var preview := _ids(cand.dark)
	var before := int(game.decisions)
	_ok(game.apply({"kind": "power", "room": hydro, "up": true}), "worked apply")
	_ok(int(game.decisions) == before + 1, "worked decisions")
	_ok(int(game.stock.power) == 3, "worked spent power")
	_ok(_dark_of(game, game.power_order) == preview, "commit dark != preview")
	print("Worked example: filter/hydro trade")


func _fixtures() -> void:
	for pool in [0, 1, 3, 8, 100]:
		var game := _worked_game()
		game.stock.power = pool
		_expect_match(game, game.power_order, "pool %d" % pool)
		_expect_match(game, Cutplan.swapped(game.power_order, _uid(game, "hydroponics"), true), "pool %d up" % pool)
	var cold := _worked_game()
	cold.active_season = {"id": "cold"}
	cold.stock.power = 4
	var cold_now: Dictionary = Cutplan.project(cold, cold.power_order)
	_ok(int(cold_now.get("mult", 0)) == 2, "cold mult")
	_ok(bool(cold_now.get("ok", false)) and _ids(cold_now.dark).has(_uid(cold, "hydroponics")), "cold did not cut the second draw")
	_expect_match(cold, cold.power_order, "cold")
	var crunch := _worked_game()
	crunch.crunch_power = true
	crunch.stock.power = 4
	_ok(int(Cutplan.project(crunch, crunch.power_order).get("mult", 0)) == 2, "crunch mult")
	_expect_match(crunch, crunch.power_order, "crunch")
	var both := _worked_game()
	both.active_season = {"id": "cold"}
	both.crunch_power = true
	both.stock.power = 4
	var both_now: Dictionary = Cutplan.project(both, both.power_order)
	_ok(int(both_now.get("mult", 0)) == 2, "cold+crunch mult %s" % str(both_now.get("mult", 0)))
	# Effective draw 4 fits in pool 4. Multiplier 4 would cut it.
	_ok(not _ids(both_now.get("dark", [])).has(_uid(both, "air_filter")), "cold+crunch used multiplier 4")
	_expect_match(both, both.power_order, "both")
	var charter := _boot()
	charter.laws_on["engineers_charter"] = true
	charter.stock.power = 0
	for room in charter.rooms:
		room.offline = str(room.type) == "generator" or str(room.type) != "air_filter"
	var air := _uid(charter, "air_filter")
	for room in charter.rooms:
		if str(room.uid) == air:
			room.offline = false
	charter.power_order = [air]
	var with_law: Dictionary = Cutplan.project(charter, charter.power_order)
	_ok(bool(with_law.get("ok", false)) and not _ids(with_law.dark).has(air), "charter did not cover draw 2")
	charter.laws_on.erase("engineers_charter")
	var no_law: Dictionary = Cutplan.project(charter, charter.power_order)
	_ok(_ids(no_law.get("dark", [])).has(air), "charter off still covered")
	_expect_match(charter, charter.power_order, "charter off")
	var flood := _worked_game()
	flood.active_season = {"id": "flood"}
	var lowest := flood._lowest_open_level()
	var flooded := _uid(flood, "platform")
	for room in flood.rooms:
		if str(room.uid) == flooded:
			room.level = lowest
			room.offline = false
	var flood_now: Dictionary = Cutplan.project(flood, flood.power_order)
	_ok(not _ids(flood_now.get("dark", [])).has(flooded), "flooded room was cut as if it drew")
	_expect_match(flood, flood.power_order, "flood")
	var gen_flood := _boot()
	gen_flood.active_season = {"id": "flood"}
	gen_flood.stock.power = 3
	var gen := _uid(gen_flood, "generator")
	var victim := _uid(gen_flood, "air_filter")
	for room in gen_flood.rooms:
		room.offline = str(room.uid) != gen and str(room.uid) != victim
		if str(room.uid) == gen:
			room.offline = false
			room.upgrade = 0
			room.staff = []
			room.level = gen_flood._lowest_open_level()
	gen_flood.power_order = [victim]
	var soaked: Dictionary = Cutplan.project(gen_flood, gen_flood.power_order)
	_ok(_ids(soaked.get("dark", [])).has(victim), "flooded generator overhead was skipped")
	_expect_match(gen_flood, gen_flood.power_order, "gen flood")
	var missing := _worked_game()
	var order: Array = missing.power_order.duplicate()
	order.insert(1, "missing-uid")
	order.insert(3, order[0])
	_expect_match(missing, order, "missing and duplicate")
	var zero := _worked_game()
	var quarters := _uid(zero, "quarters")
	for room in zero.rooms:
		if str(room.uid) == quarters:
			room.offline = false
	var zorder: Array = [_uid(zero, "air_filter"), quarters, _uid(zero, "infirmary"), _uid(zero, "platform")]
	zero.power_order = zorder
	var zero_now: Dictionary = Cutplan.project(zero, zorder)
	_ok(not _ids(zero_now.get("dark", [])).has(quarters), "zero-draw room was cut")
	var saw_zero := false
	for grp in zero_now.get("groups", []):
		if str(grp.get("anchor", "")) == quarters and int(grp.get("draw", -1)) == 0 and str(grp.get("status", "")) == "not_drawing":
			saw_zero = true
	_ok(saw_zero, "zero-draw group missing")
	_expect_match(zero, zorder, "zero draw")
	var disagree := _worked_game()
	disagree.stock.power = 2
	var big_first: Dictionary = Cutplan.project(disagree, disagree.power_order)
	var uncovered: Array = _ids(disagree._uncovered_power_ids())
	_ok(_ids(big_first.get("dark", [])) != uncovered or uncovered.is_empty(), "fixture did not separate the two allocators")
	_ok(_ids(big_first.get("dark", [])) == _dark_of(disagree, disagree.power_order), "disagreement followed uncovered")
	_ok(not _ids(big_first.dark).has(_uid(disagree, "air_filter")), "order did not keep the first draw")
	print("Fixtures: pool, cold, crunch, charter, flood, gaps")


func _reserve() -> void:
	var game := _boot()
	game.stock.power = 1
	var gen := _uid(game, "generator")
	var heavy := _uid(game, "air_filter")
	var light := _uid(game, "infirmary")
	if light == "":
		game._place_room("infirmary", 2, 0)
		light = _uid(game, "infirmary")
	for room in game.rooms:
		if str(room.uid) == gen:
			room.offline = false
			room.upgrade = 2
			room.staff = []
		elif str(room.uid) == heavy or str(room.uid) == light:
			room.offline = false
			room.upgrade = 0
		else:
			room.offline = true
	game.power_order = [heavy, light]
	var covered: Dictionary = Cutplan.project(game, game.power_order)
	_ok(int(covered.get("spares", 0)) == 1, "reserve missing")
	_ok(int(covered.get("pool", -1)) == 1, "reserve pool %s" % str(covered.get("pool", -1)))
	_ok(_ids(covered.get("dark", [])).is_empty(), "reserve still cut %s" % str(_ids(covered.get("dark", []))))
	for room in game.rooms:
		if str(room.uid) == gen:
			room.upgrade = 0
			room.offline = true
	var bare: Dictionary = Cutplan.project(game, game.power_order)
	_ok(int(bare.get("spares", 1)) == 0, "offline generator kept a reserve")
	_ok(_ids(bare.get("dark", [])) == _ids([heavy]), "non-fit consumed the pool or cut the small room %s" % str(_ids(bare.get("dark", []))))
	_expect_match(game, game.power_order, "no reserve")
	var merged := _boot()
	merged.stock.power = 1
	merged._place_room("hydroponics", 2, 0)
	merged._place_room("hydroponics", 2, 1)
	var pair: Array = _by_type(merged).hydroponics
	var a := ""
	var b := ""
	for uid in pair:
		var room = merged._room(str(uid))
		if int(room.level) == 2:
			if a == "":
				a = str(uid)
			else:
				b = str(uid)
	var third := _uid(merged, "air_filter")
	for room in merged.rooms:
		if str(room.uid) == _uid(merged, "generator"):
			room.offline = false
			room.upgrade = 2
			room.staff = []
		elif str(room.uid) == a or str(room.uid) == b or str(room.uid) == third:
			room.offline = false
			room.upgrade = 0
		else:
			room.offline = true
	merged.power_order = [a, third, b]
	_ok(merged.merge_group_of(a).size() == 2, "hydros did not merge")
	var block: Dictionary = Cutplan.project(merged, merged.power_order)
	_ok(not _ids(block.get("dark", [])).has(a) and not _ids(block.get("dark", [])).has(b), "merged group took a reserve per member %s" % str(_ids(block.get("dark", []))))
	_ok(_ids(block.get("dark", [])).has(third), "later room was covered by a second reserve")
	var grouped := false
	for grp in block.get("groups", []):
		if (grp.get("members", []) as Array).size() == 2 and int(grp.get("draw", 0)) == 4:
			grouped = true
	_ok(grouped, "merged draw was not one group of 4")
	_expect_match(merged, merged.power_order, "merged reserve")
	for room in merged.rooms:
		if str(room.uid) == b:
			room.offline = true
	merged.stock.power = 0
	for room in merged.rooms:
		if str(room.type) == "generator":
			room.offline = true
			room.upgrade = 0
	merged.power_order = [a, third]
	var inactive: Dictionary = Cutplan.project(merged, merged.power_order)
	_ok(_ids(inactive.get("dark", [])).has(a) and _ids(inactive.get("dark", [])).has(b), "inactive merge member left out of the dark set %s" % str(_ids(inactive.get("dark", []))))
	_expect_match(merged, merged.power_order, "inactive member")
	print("Reserve: one spare, no pool spend, one per group")


func _yield_and_flags() -> void:
	var game := _boot(3)
	for room in game.rooms:
		if str(room.type) == "generator":
			room.offline = false
	var flags: Array = _flags(game)
	var fp := Cutplan.fingerprint(game)
	var rng := _rng(game)
	var pure := Cutplan.generator_yield(game)
	var iso := _isolate(game)
	var helper := int(iso._generator_yield())
	_ok(pure == helper, "yield %d vs isolated helper %d" % [pure, helper])
	_ok(_flags(game) == flags, "yield touched live flags")
	_ok(Cutplan.fingerprint(game) == fp and _rng(game) == rng, "yield touched live state")
	var spy := _spy(game)
	spy.calls = 0
	var spy_flags: Array = _flags(spy)
	var proj: Dictionary = Cutplan.project(spy, spy.power_order)
	_ok(bool(proj.get("ok", false)), "spy projection unavailable")
	_ok(spy.calls == 0, "preview called live _generator_yield %d" % spy.calls)
	_ok(_flags(spy) == spy_flags, "spy flags changed")
	var staffed := _boot(4)
	_ok(Cutplan.generator_yield(staffed) == int(_isolate(staffed)._generator_yield()), "staffed yield diverged")
	print("Yield: detached helper, live flags held")


func _replay() -> void:
	var game := _worked_game()
	var hydro := _uid(game, "hydroponics")
	var a := _isolate(game)
	var b := _isolate(game)
	a.active_season = {"id": "cough", "start": int(a.week), "until": int(a.week) + 8}
	b.active_season = {"id": "cough", "start": int(b.week), "until": int(b.week) + 8}
	for uid in a.power_order:
		if _cut_can(a, str(uid), true):
			Cutplan.project(a, Cutplan.swapped(a.power_order, str(uid), true))
		if _cut_can(a, str(uid), false):
			Cutplan.project(a, Cutplan.swapped(a.power_order, str(uid), false))
	var cmd := {"kind": "power", "room": hydro, "up": true}
	_ok(a.apply(cmd) and b.apply(cmd), "replay apply")
	_ok(Cutplan.fingerprint(a) == Cutplan.fingerprint(b) and _rng(a) == _rng(b), "replay diverged at commit")
	a.end_week()
	b.end_week()
	_ok(Cutplan.fingerprint(a) == Cutplan.fingerprint(b), "replay diverged after cough night")
	_ok(_rng(a) == _rng(b), "replay rng diverged after night")
	var plain := _worked_game()
	var before := int(plain.decisions)
	plain.stock.power = 100
	_ok(plain.apply({"kind": "power", "room": hydro, "up": true}), "no-change swap rejected")
	_ok(int(plain.decisions) == before + 1, "unchanged allocation did not count")
	print("Replay: preview then night matches a direct command")


func _cut_can(game: Game, uid: String, up: bool) -> bool:
	var i := game.power_order.find(uid)
	if i < 0:
		return false
	var j := i - 1 if up else i + 1
	return j >= 0 and j < game.power_order.size()


func _random_live() -> void:
	var bot := Bot.new()
	bot.profile = "careful"
	var checked := 0
	for run_seed in range(1, 9):
		var game := Game.new()
		_records(game)
		game.setup(catalog, run_seed, 40)
		game.audit = false
		game.raid_share_profile = "careful"
		for _week in 8:
			if str(game.over) != "":
				break
			_expect_match(game, game.power_order, "live %d w%d" % [run_seed, game.week])
			for uid in game.power_order:
				if not _cut_can(game, str(uid), true):
					continue
				var order: Array = Cutplan.swapped(game.power_order, str(uid), true)
				_expect_match(game, order, "live %d swap %s" % [run_seed, uid])
				checked += 1
				if checked == 1:
					var preview: Array = _ids(Cutplan.project(game, order).dark)
					var committed := _isolate(game)
					_ok(committed.apply({"kind": "power", "room": str(uid), "up": true}), "live commit")
					_ok(_dark_of(committed, committed.power_order) == preview, "live commit dark")
			if failed:
				return
			bot._act(game)
			game.end_week()
	_ok(checked > 20, "random swaps %d" % checked)
	print("Random live states: %d swaps" % checked)


func _ui() -> void:
	var st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	st.hold_dawn = true
	root.add_child(st)
	for _i in 8:
		await process_frame
	if st.game == null:
		_bad("station had no game")
		return
	_records(st.game)
	st._close_card()
	if st.menu_layer != null:
		st.menu_layer.visible = false
	st.at_menu = false
	_shape_worked(st.game)
	Copy.set_lang("en")
	st._show_power()
	await process_frame
	var filt := _uid(st.game, "air_filter")
	var hydro := _uid(st.game, "hydroponics")
	var plat := _uid(st.game, "platform")
	var up0 := _dir_button(st, filt, "up")
	var down_last := _dir_button(st, plat, "down")
	_ok(up0 != null and up0.disabled and up0.focus_mode == Control.FOCUS_NONE, "first up not disabled")
	_ok(down_last != null and down_last.disabled, "last down not disabled")
	var compare := _meta_button(st.card_body, "cutplan_compare", hydro)
	_ok(compare != null and not compare.disabled and compare.focus_mode == Control.FOCUS_ALL, "hydro compare")
	_ok(compare.custom_minimum_size.y >= 44.0, "compare touch size")
	var fp := Cutplan.fingerprint(st.game)
	var decisions := int(st.game.decisions)
	st.card_click_guard = 0
	compare.pressed.emit()
	await process_frame
	_ok(int(st.game.decisions) == decisions and Cutplan.fingerprint(st.game) == fp, "opening compare mutated")
	var body := _texts(st.card_body)
	_ok(body.find("cutplan.") < 0, "raw key on compare")
	_ok(body.find("Compare power priority") >= 0, "title missing")
	_ok(body.find("Current conditions only.") >= 0, "scope missing")
	_ok(body.find("Newly cut") >= 0 and body.find("No longer cut") >= 0, "changed sets missing")
	_ok(body.find("Air filter") >= 0 and body.find("Hydroponics") >= 0, "endpoint names")
	_ok(body.find("Within allocation") >= 0 and body.find("operating") < 0, "within/operating")
	_ok(body.find("Pool after generator use: 3.") >= 0, "budget line")
	var move := _meta_button(st.card_body, "cutplan_move", "up")
	var keep := _meta_button(st.card_body, "cutplan_keep", true)
	var dir_down := _meta_button(st.card_body, "cutplan_dir", "down")
	_ok(move != null and move.focus_mode == Control.FOCUS_ALL, "move button")
	_ok(keep != null and keep.focus_mode == Control.FOCUS_ALL, "keep button")
	_ok(dir_down != null and dir_down.focus_mode == Control.FOCUS_ALL, "direction button")
	st.card_click_guard = 0
	dir_down.pressed.emit()
	await process_frame
	_ok(int(st.game.decisions) == decisions, "direction counted a decision")
	_ok(_texts(st.card_body).find("No allocation change.") >= 0, "down did not say unchanged")
	st.card_click_guard = 0
	var dir_up := _meta_button(st.card_body, "cutplan_dir", "up")
	if dir_up != null:
		dir_up.pressed.emit()
		await process_frame
	st.card_click_guard = 0
	keep = _meta_button(st.card_body, "cutplan_keep", true)
	keep.pressed.emit()
	await process_frame
	_ok(st.cutplan_room == "" and Cutplan.fingerprint(st.game) == fp, "keep current changed state")
	_ok(_texts(st.card_body).find("Compare power priority") < 0, "keep left the expansion")
	compare = _meta_button(st.card_body, "cutplan_compare", hydro)
	st.card_click_guard = 0
	compare.pressed.emit()
	await process_frame
	st.game.stock.power = 4
	move = _meta_button(st.card_body, "cutplan_move", "up")
	st.card_click_guard = 0
	var stale_decisions := int(st.game.decisions)
	move.pressed.emit()
	await process_frame
	_ok(int(st.game.decisions) == stale_decisions, "stale move applied")
	_ok(_texts(st.card_body).find("Conditions or neighbors changed.") >= 0, "changed copy missing")
	st.card_click_guard = 0
	move = _meta_button(st.card_body, "cutplan_move", "up")
	var direct := _isolate(st.game)
	move.pressed.emit()
	await process_frame
	direct.apply({"kind": "power", "room": hydro, "up": true})
	_ok(st.game.power_order == direct.power_order, "move order != direct up")
	_ok(int(st.game.decisions) == int(direct.decisions), "move decisions != direct")
	_ok(_rng(st.game) == _rng(direct), "move rng != direct")
	# Boundary change: arm hydro down, then make that neighbor illegal.
	_shape_worked(st.game)
	st._show_power()
	await process_frame
	compare = _meta_button(st.card_body, "cutplan_compare", hydro)
	st.card_click_guard = 0
	compare.pressed.emit()
	await process_frame
	dir_down = _meta_button(st.card_body, "cutplan_dir", "down")
	st.card_click_guard = 0
	dir_down.pressed.emit()
	await process_frame
	var armed := int(st.game.decisions)
	st.game.power_order = [filt, plat, hydro]
	move = _meta_button(st.card_body, "cutplan_move", "down")
	st.card_click_guard = 0
	if move != null:
		move.pressed.emit()
		await process_frame
	_ok(int(st.game.decisions) == armed and st.cutplan_room == "", "boundary press applied or stayed open")
	# Unavailable leaves the original buttons working.
	_shape_worked(st.game)
	st._show_power()
	await process_frame
	Cutplan.force_fail = true
	compare = _meta_button(st.card_body, "cutplan_compare", hydro)
	st.card_click_guard = 0
	compare.pressed.emit()
	await process_frame
	Cutplan.force_fail = false
	_ok(_texts(st.card_body).find("Allocation comparison unavailable.") >= 0, "unavailable copy")
	_ok(_meta_button(st.card_body, "cutplan_move", "up") == null, "unavailable still offered move")
	var up_h := _dir_button(st, hydro, "up")
	var before_up := int(st.game.decisions)
	st.card_click_guard = 0
	up_h.pressed.emit()
	await process_frame
	_ok(int(st.game.decisions) == before_up + 1, "direct up did not apply")
	# One expansion, escape, double click, preemption.
	_shape_worked(st.game)
	st._show_power()
	await process_frame
	st.card_click_guard = 0
	_meta_button(st.card_body, "cutplan_compare", hydro).pressed.emit()
	await process_frame
	st.card_click_guard = 0
	_meta_button(st.card_body, "cutplan_compare", filt).pressed.emit()
	await process_frame
	var panels := _count_meta(st.card_body, "cutplan_panel")
	_ok(st.cutplan_room == filt and panels == 1, "second compare did not replace the open row (%s, %d)" % [st.cutplan_room, panels])
	var fp_esc := Cutplan.fingerprint(st.game)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	st._unhandled_key_input(ev)
	await process_frame
	_ok(st.cutplan_room == "" and Cutplan.fingerprint(st.game) == fp_esc, "escape applied or kept the expansion")
	st.card_click_guard = 0
	_meta_button(st.card_body, "cutplan_compare", hydro).pressed.emit()
	await process_frame
	st.deck.push(2, "preempt")
	st._close_card()
	await process_frame
	_ok(st.cutplan_room == "" and _texts(st.card_body).find("Newly cut") < 0, "preemption kept the comparison")
	_shape_worked(st.game)
	st._show_power()
	await process_frame
	var twice := int(st.game.decisions)
	var up_btn := _dir_button(st, hydro, "up")
	st.card_click_guard = 0
	up_btn.pressed.emit()
	up_btn.pressed.emit()
	await process_frame
	_ok(int(st.game.decisions) == twice + 1, "double click applied twice")
	Copy.set_lang("ru")
	_shape_worked(st.game)
	st._show_power()
	await process_frame
	var ru := _texts(st.card_body)
	_ok(_meta_button(st.card_body, "cutplan_compare", hydro) == null, "ru showed compare")
	_ok(ru.find("cutplan.") < 0 and ru.find("Compare") < 0 and ru.find("Keep current") < 0, "ru leaked en compare")
	_ok(_dir_button(st, hydro, "up") != null and _dir_button(st, hydro, "down") != null, "ru lost direct moves")
	Copy.set_lang("en")
	await _focus_views(st)
	if not _renderer_live():
		_shots_skipped = true
		for spec in [["en", "100", "before"], ["en", "100", "after"], ["en", "125", "before"], ["en", "125", "after"], ["ru", "100", "before"], ["ru", "100", "after"]]:
			print("CUTPLAN SHOT SKIP %s %s %s" % [spec[0], spec[1], spec[2]])
	else:
		await _shoot_pair(st, "en", "100")
		await _shoot_pair(st, "en", "125scale")
		await _shoot_pair(st, "ru", "100")
	if is_instance_valid(st):
		st.free()
	print("UI: compare, stale, keep, move, ru fallback")


func _shape_worked(game: Game) -> void:
	game.laws_on.erase("engineers_charter")
	game.crunch_power = false
	game.active_season = {}
	game.stock.power = 3
	if _uid(game, "infirmary") == "":
		game._place_room("infirmary", 2, 0)
	var order := [_uid(game, "air_filter"), _uid(game, "hydroponics"), _uid(game, "infirmary"), _uid(game, "platform")]
	for room in game.rooms:
		room.offline = str(room.type) == "generator" or not order.has(str(room.uid))
		if str(room.type) == "generator":
			room.offline = true
	game.power_order = order


func _shoot_pair(st, lang: String, scale: String) -> void:
	Copy.set_lang(lang)
	_shape_worked(st.game)
	await _apply_view(st, scale)
	st._show_power()
	await _settle_card(st)
	await _shoot(st, lang, scale, false)
	if lang == "en":
		var hydro := _uid(st.game, "hydroponics")
		var compare := _meta_button(st.card_body, "cutplan_compare", hydro)
		if compare == null:
			_bad("shot compare missing")
			return
		st.card_click_guard = 0
		compare.pressed.emit()
		await _settle_card(st)
		_ok(_texts(st.card_body).find("cutplan.") < 0, "shot raw key")
	await _shoot(st, lang, scale, true)


func _apply_view(st, scale: String) -> void:
	var window: Window = st.get_window()
	window.mode = Window.MODE_WINDOWED
	var win := Vector2i(1920, 1080)
	var factor := 1.0
	if scale == "125":
		win = Vector2i(1536, 864)
	elif scale == "125scale":
		factor = 1.25
	window.size = win
	root.size = win
	Settings.ui_scale_auto = false
	Settings.ui_scale = factor
	if absf(factor - 1.0) < 0.01:
		window.content_scale_factor = 1.0
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		window.content_scale_size = win
	else:
		Settings.apply_scale(window)
	for _i in 3:
		await process_frame
	if st.has_method("_layout"):
		st._layout()
	await process_frame
	print("VIEW %s window %s scale %.2f viewport %s" % [scale, window.size, window.content_scale_factor, st.get_viewport_rect().size])


func _focus_views(st) -> void:
	for tag in ["100", "125", "125scale"]:
		await _apply_view(st, tag)
		await _focus_paths(st, tag)
		await _wrap_scope(st, tag)


func _focus_paths(st, tag: String) -> void:
	var hydro := _uid(st.game, "hydroponics")
	var filt := _uid(st.game, "air_filter")
	var inf := _uid(st.game, "infirmary")
	await _open_compare(st, hydro)
	await _press(st, _meta_button(st.card_body, "cutplan_keep", true))
	_expect_focus(st, tag, "keep", "cutplan_compare", hydro)
	await _open_compare(st, hydro)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	st._unhandled_key_input(ev)
	await _focus_settle()
	_expect_focus(st, tag, "esc", "cutplan_compare", hydro)
	await _open_compare(st, hydro)
	var close := _find_button(st.card_body, "Close")
	await _press(st, close)
	_ok(st.deck.top_token() == "power" and st.cutplan_room == "", "%s close left the preview or the card" % tag)
	_expect_focus(st, tag, "close", "cutplan_compare", hydro)
	_shape_worked(st.game)
	await _open_compare(st, filt)
	await _press(st, _meta_button(st.card_body, "cutplan_move", "down"))
	_expect_focus(st, tag, "move down", "power_dir", "down", filt)
	_shape_worked(st.game)
	await _open_compare(st, hydro)
	await _press(st, _meta_button(st.card_body, "cutplan_move", "up"))
	var up_after := _dir_button(st, hydro, "up")
	if up_after != null and up_after.disabled:
		_expect_focus(st, tag, "move up", "cutplan_compare", hydro)
	else:
		_expect_focus(st, tag, "move up", "power_dir", "up", hydro)
	_shape_worked(st.game)
	st._show_power()
	await _focus_settle()
	await _press(st, _dir_button(st, inf, "up"))
	_expect_focus(st, tag, "direct up", "power_dir", "up", inf)
	_shape_worked(st.game)
	st._show_power()
	await _focus_settle()
	await _press(st, _dir_button(st, hydro, "down"))
	_expect_focus(st, tag, "direct down", "power_dir", "down", hydro)


func _wrap_scope(st, tag: String) -> void:
	var hydro := _uid(st.game, "hydroponics")
	_shape_worked(st.game)
	await _open_compare(st, hydro)
	await _focus_settle()
	var panel := _meta_control(st.card_body, "cutplan_panel")
	var scope := _meta_control(st.card_body, "cutplan_scope")
	_ok(panel != null and scope != null, "%s scope missing" % tag)
	if panel == null or scope == null:
		return
	_ok(scope.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "%s scope does not wrap" % tag)
	_ok(str(scope.text) == "Current conditions only. Changes before night can change the allocation.", "%s scope copy changed" % tag)
	_ok(scope.size.x <= panel.size.x + 0.5, "%s scope %s wider than panel %s" % [tag, scope.size, panel.size])
	_ok(scope.get_global_rect().end.x <= panel.get_global_rect().end.x + 1.0, "%s scope escapes the panel" % tag)
	_ok(scope.get_line_count() >= 2, "%s scope lines %d" % [tag, scope.get_line_count()])
	_ok(scope.custom_maximum_size.x <= panel.size.x + 0.5, "%s scope max %s panel %s" % [tag, scope.custom_maximum_size, panel.size])
	print("SCOPE %s panel %s label %s lines %d" % [tag, panel.size, scope.size, scope.get_line_count()])


func _open_compare(st, uid: String) -> void:
	_shape_worked(st.game)
	st._show_power()
	await _focus_settle()
	await _press(st, _meta_button(st.card_body, "cutplan_compare", uid))


func _press(st, button: Button) -> void:
	_ok(button != null, "missing button")
	if button == null:
		return
	st.card_click_guard = 0
	button.pressed.emit()
	await _focus_settle()


func _focus_settle() -> void:
	for _i in 3:
		await process_frame


func _expect_focus(st, tag: String, path: String, key: String, value: String, uid: String = "") -> void:
	var owner: Control = st.get_viewport().gui_get_focus_owner()
	_ok(owner != null, "%s %s focus null" % [tag, path])
	if owner == null:
		return
	_ok(owner.has_meta(key) and str(owner.get_meta(key)) == value, "%s %s focused %s" % [tag, path, owner])
	var who := uid if uid != "" else value
	if owner.has_meta("power_index"):
		_ok(int(owner.get_meta("power_index")) == st.game.power_order.find(who), "%s %s index %s order %s" % [tag, path, owner.get_meta("power_index"), st.game.power_order.find(who)])
	if key == "power_dir":
		_ok(str(owner.get_meta("power_uid", "")) == uid, "%s %s uid" % [tag, path])


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and str((here as Button).text) == text:
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _meta_control(node: Node, key: String) -> Control:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Control and here.has_meta(key):
			return here
		for child in here.get_children():
			stack.append(child)
	return null


func _reveal_compare(st) -> void:
	if st.card_scroll == null or st.card_body == null:
		return
	var panel: Control = null
	var stack: Array = [st.card_body]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Control and here.has_meta("cutplan_panel"):
			panel = here
			break
		for child in here.get_children():
			stack.append(child)
	if panel == null:
		return
	var view: float = st.card_scroll.size.y
	var bottom: float = panel.position.y + panel.size.y + 12.0
	st.card_scroll.scroll_vertical = int(maxi(0.0, bottom - view))


func _settle_card(st) -> void:
	for _i in 12:
		await process_frame
	if st.has_method("_fit_card"):
		st._fit_card()
	for _i in 8:
		await process_frame


func _shoot(st, lang: String, scale: String, opened: bool) -> void:
	var phase := "after" if opened else "before"
	if not _renderer_live():
		_shots_skipped = true
		print("CUTPLAN SHOT SKIP %s %s %s" % [lang, scale, phase])
		return
	await _settle_card(st)
	if opened:
		_reveal_compare(st)
		await process_frame
		await process_frame
	RenderingServer.force_draw()
	var tex: ViewportTexture = st.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	var shot_scale := "125" if scale == "125scale" else scale
	var name := "cutplan_%s_%s_%s.png" % [lang, shot_scale, phase]
	var path := _shot_dir().path_join(name)
	if img == null or img.get_width() < 2:
		_bad("no image " + name)
		return
	DirAccess.make_dir_recursive_absolute(_shot_dir())
	var err := img.save_png(path)
	if err != OK:
		_bad("shot %s %s" % [name, str(err)])
		return
	_shots_saved += 1
	print("CUTPLAN SHOT %s" % path)


func _renderer_live() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


func _shot_dir() -> String:
	var dir := OS.get_environment("UNDERLINE_SHOTS_DIR")
	if dir == "":
		dir = "/opt/cursor/artifacts"
	if dir.begins_with("user://") or dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path(dir)
	return dir


func _dir_button(st, uid: String, dir: String) -> Button:
	return _meta_button(st.card_body, "power_dir", dir, "power_uid", uid)


func _meta_button(node: Node, key: String, value, key2: String = "", value2 = null) -> Button:
	if node == null:
		return null
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Button and here.has_meta(key) and here.get_meta(key) == value:
			if key2 == "" or (here.has_meta(key2) and here.get_meta(key2) == value2):
				return here
		for child in here.get_children():
			stack.append(child)
	return null


func _count_meta(node: Node, key: String) -> int:
	var n := 0
	if node == null:
		return 0
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here.has_meta(key):
			n += 1
		for child in here.get_children():
			stack.append(child)
	return n


func _texts(node: Node) -> String:
	var bits: PackedStringArray = []
	if node == null:
		return ""
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if here is Label:
			bits.append(str((here as Label).text))
		elif here is Button:
			bits.append(str((here as Button).text))
		for child in here.get_children():
			stack.append(child)
	return "\n".join(bits)
