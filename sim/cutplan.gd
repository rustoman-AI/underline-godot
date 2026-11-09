class_name Cutplan
extends RefCounted

## P100 Keep the Lights. Transient allocation comparison for the Power order panel.
##
## The dark set is the existing brownout-id rule: generator overhead, cold OR
## crunch multiplier 2, merge groups, reserve covering one group without spending
## pool, zero draw taking nothing. The draw-sorted coverage helper is not used.
##
## Preview never swaps live power_order, never writes browned flags, and never
## calls apply, the night brownout writer, or a sim tick. The copy below is detached.
## Generator yield is the existing helper on that copy only.
##
## No save field. Schema stays 27. Copy in data/cutplan.json is an interim
## wiring draft, not a Texts or canon approval. An empty active-locale string
## hides the whole comparison. The key is never shown.


const KEYS := [
	"cutplan.compare",
	"cutplan.title",
	"cutplan.now",
	"cutplan.after",
	"cutplan.up",
	"cutplan.down",
	"cutplan.apply_up",
	"cutplan.apply_down",
	"cutplan.keep",
	"cutplan.gains",
	"cutplan.losses",
	"cutplan.unchanged",
	"cutplan.cut",
	"cutplan.within",
	"cutplan.not_drawing",
	"cutplan.budget",
	"cutplan.draw",
	"cutplan.scope",
	"cutplan.changed",
	"cutplan.unavailable",
	"cutplan.group",
	"cutplan.reserve",
	"cutplan.swap_up",
	"cutplan.swap_down",
]

## Gate seam. While true, project() refuses instead of inventing a dark set.
static var force_fail := false


static func line(key: String) -> String:
	Copy.boot()
	if not Copy.keys.has(key):
		return ""
	var row = Copy.keys[key]
	if not (row is Dictionary):
		return ""
	var field := "ru" if Copy.lang == "ru" else "en"
	return str(row.get(field, "")).strip_edges()


static func locale_ready() -> bool:
	for key in KEYS:
		if line(key) == "":
			return false
	return true


static func fill(key: String, vars: Dictionary = {}) -> String:
	var text := line(key)
	if text == "":
		return ""
	for token in vars:
		text = text.replace("{%s}" % str(token), str(vars[token]))
	return text


static func fingerprint(game) -> String:
	if game == null:
		return ""
	var snap: Dictionary = game.export_state()
	var bal = game.bal if game.bal is Dictionary else {}
	return "v1|" + _canon(snap) + "|bal|" + _canon(bal)


## One adjacent swap of a detached order. The passed array is not written.
static func swapped(order: Array, uid: String, up: bool) -> Array:
	var out: Array = order.duplicate()
	var i := out.find(uid)
	if i < 0:
		return out
	var j := i - 1 if up else i + 1
	if j < 0 or j >= out.size():
		return out
	var held = out[i]
	out[i] = out[j]
	out[j] = held
	return out


## Existing generator yield on a detached copy. Live browned flags are not touched.
static func generator_yield(game) -> int:
	var ghost = _ghost(game)
	if ghost == null:
		return -1
	return int(ghost._generator_yield())


## Dark set and group rows for one priority order. `ok` is false when the copy
## cannot be proved detached or the walk disagrees with _brownout_ids.
static func project(game, order: Array) -> Dictionary:
	if force_fail or game == null or order == null:
		return {"ok": false}
	var ghost = _ghost(game)
	if ghost == null or not _is_detached(game, ghost):
		return {"ok": false}
	ghost.power_order = order.duplicate(true)
	if not _is_detached(game, ghost):
		return {"ok": false}
	var walked: Dictionary = _walk(ghost)
	var canonical: Array = ghost._brownout_ids()
	if not _same_ids(walked.get("dark", []), canonical):
		return {"ok": false}
	walked["ok"] = true
	return walked


static func _ghost(game):
	if game == null or game.catalog == null or not (game.bal is Dictionary):
		return null
	var snap: Dictionary = game.export_state()
	var ghost := Game.new()
	ghost.catalog = game.catalog
	ghost.bal = game.bal.duplicate(true)
	for key in Game.PERSIST:
		if not snap.has(key):
			return null
		var value = snap[key]
		if value is Array or value is Dictionary:
			ghost.set(key, value.duplicate(true))
		else:
			ghost.set(key, value)
	if ghost.residents is Array and ghost.people is Dictionary:
		var linked: Array = []
		for person in ghost.residents:
			if person is Dictionary and ghost.people.has(str(person.get("id", ""))):
				linked.append(ghost.people[str(person.id)])
			else:
				linked.append(person)
		ghost.residents = linked
	return ghost


static func _is_detached(game, ghost) -> bool:
	if game == null or ghost == null:
		return false
	if is_same(game.rooms, ghost.rooms) or is_same(game.people, ghost.people):
		return false
	if is_same(game.stock, ghost.stock) or is_same(game.power_order, ghost.power_order):
		return false
	if is_same(game.cells, ghost.cells) or is_same(game.laws_on, ghost.laws_on):
		return false
	if game.rooms is Array and ghost.rooms is Array:
		var n: int = mini(game.rooms.size(), ghost.rooms.size())
		for i in n:
			if is_same(game.rooms[i], ghost.rooms[i]):
				return false
	if game.people is Dictionary and ghost.people is Dictionary:
		for pid in game.people:
			if ghost.people.has(pid) and is_same(game.people[pid], ghost.people[pid]):
				return false
	return true


## Same allocation as Game._brownout_ids, plus the group rows the panel shows.
static func _walk(game) -> Dictionary:
	var dark: Array = []
	var groups: Array = []
	var mult := 2 if (game._season_is("cold") or game.crunch_power) else 1
	var pool := int(game.stock.power) + int(game._generator_yield())
	for room in game.rooms:
		if str(room.type) != "generator" or bool(room.offline):
			continue
		pool -= game.room_power(room) * mult
	if pool < 0:
		pool = 0
	var spares := int(game.brownout_spare())
	var spare := spares
	var left := pool
	var decided := {}
	for uid in game.power_order:
		var room = game._room(str(uid))
		if room == null:
			continue
		if decided.has(str(uid)):
			continue
		if str(room.type) == "generator" or bool(room.offline) or game._flood_silences(room):
			continue
		var grp: Array = game._merge_group_of(room)
		var draw := 0
		var members: Array = []
		for r in grp:
			decided[str(r.uid)] = true
			members.append(str(r.uid))
			if bool(r.offline) or game._flood_silences(r) or str(r.type) == "generator":
				continue
			draw += game.room_power(r) * mult
		var status := "not_drawing"
		if draw <= 0:
			status = "not_drawing"
		elif left >= draw:
			left -= draw
			status = "within"
		elif spare > 0:
			spare -= 1
			status = "within"
		else:
			status = "cut"
			for r in grp:
				dark.append(str(r.uid))
		groups.append({
			"anchor": str(room.uid),
			"members": members,
			"draw": draw,
			"status": status,
		})
	return {
		"dark": dark,
		"groups": groups,
		"pool": pool,
		"spares": spares,
		"mult": mult,
	}


static func _same_ids(a, b) -> bool:
	var left: Array = []
	var right: Array = []
	for id in a:
		left.append(str(id))
	for id in b:
		right.append(str(id))
	left.sort()
	right.sort()
	return left == right


static func _canon(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(x, y): return str(x) < str(y))
		var parts: PackedStringArray = []
		for key in keys:
			parts.append(_canon(str(key)) + ":" + _canon(value[key]))
		return "{" + "|".join(parts) + "}"
	if value is Array or value is PackedStringArray or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedByteArray:
		var parts: PackedStringArray = []
		for item in value:
			parts.append(_canon(item))
		return "[" + "|".join(parts) + "]"
	if value is bool:
		return "b1" if value else "b0"
	if value == null:
		return "n"
	return "s" + str(typeof(value)) + ":" + str(value)
