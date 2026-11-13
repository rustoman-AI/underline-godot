class_name LivingLight
extends RefCounted

## Cut flicker, relight, generator strain, night/dawn grade, ward wash, frontier.
## Pure: no scene tree, no sim writes. The clock is passed in.

var _seen := false
var _reduced := false
var _in := {}
var _events: Array = []
var _last_entry := {}
var _meta := {}
var _generators: Array = []
var _phase := "off"
var _intro := 0.0
var _pause_age := 0.0
var _dawn := 0.0
var _ward_uid := ""
var _ward_weight := 0.0
var _front := {}


func reset() -> void:
	_seen = false
	_reduced = false
	_in = {}
	_events = []
	_last_entry = {}
	_meta = {}
	_generators = []
	_phase = "off"
	_intro = 0.0
	_pause_age = 0.0
	_dawn = 0.0
	_ward_uid = ""
	_ward_weight = 0.0
	_front = {}


func snap_events() -> void:
	_events = []


func phase() -> String:
	return _phase


func pause_age() -> float:
	return _pause_age


func event_count() -> int:
	return _events.size()


func frontier_count() -> int:
	return _front.size()


func rate_count() -> int:
	return _last_entry.size()


func observe(loss: Dictionary, week: int, rooms: Array, cells: Dictionary, t: float, still: bool) -> void:
	_reduced = still
	_index_rooms(rooms)
	_rebuild_frontier(cells)
	var now := {}
	for uid in loss:
		if bool(loss[uid]):
			now[str(uid)] = true
	if still:
		_events = []
		_in = now
		_seen = true
		_phase = "off"
		return
	if not _seen:
		_in = now
		_seen = true
		return
	var grew := false
	for uid in now:
		if not _in.has(str(uid)):
			grew = true
			_start_cut(str(uid), week, t)
	var leaving: Array = []
	for uid in _in:
		if not now.has(str(uid)):
			leaving.append(str(uid))
	for uid in leaving:
		_start_relight(str(uid), t)
	_in = now
	if grew:
		_start_strain(week, t)
	_prune(t)


func set_ward(uid: String, still: bool) -> void:
	_ward_uid = uid
	if still:
		_ward_weight = 1.0 if uid != "" else 0.0


func night_begin(t: float) -> void:
	if _reduced:
		return
	_phase = "intro"
	_intro = 0.0
	_pause_age = 0.0
	_dawn = 0.0
	for ev in _events:
		if float(ev.t0) >= 0.0 and t - float(ev.t0) <= 0.05:
			ev.waiting = true
			ev.t0 = -1.0


func night_end(t: float) -> void:
	if _phase == "intro" or _phase == "hold":
		_start_dawn(t)


func tick(dt: float, paused: bool, still: bool, t: float) -> void:
	if still:
		_reduced = true
		_events = []
		_phase = "off"
		_ward_weight = 1.0 if _ward_uid != "" else 0.0
		return
	_reduced = false
	var goal := 1.0 if _ward_uid != "" else 0.0
	if not paused:
		var step := dt / LivingStyle.WARD_FADE_S
		if _ward_weight < goal:
			_ward_weight = minf(_ward_weight + step, goal)
		elif _ward_weight > goal:
			_ward_weight = maxf(_ward_weight - step, goal)
	if _phase == "off":
		_prune(t)
		return
	if _phase == "intro":
		_intro += dt
		if _intro < LivingStyle.VEIL_S:
			_prune(t)
			return
		_phase = "hold"
	if _phase == "hold":
		if paused:
			_pause_age += dt
			_prune(t)
			return
		_start_dawn(t)
		_prune(t)
		return
	if _phase == "dawn":
		if not paused:
			_dawn += dt
			if _dawn >= LivingStyle.DAWN_S:
				_phase = "off"
				_dawn = 0.0
	_prune(t)


func grade_color() -> Color:
	if _phase == "off" or _reduced:
		return Color(0, 0, 0, 0)
	if _phase == "intro":
		var u := clampf(_intro / LivingStyle.NIGHT_IN_S, 0.0, 1.0)
		return Color(LivingStyle.NIGHT.r, LivingStyle.NIGHT.g, LivingStyle.NIGHT.b, LivingStyle.NIGHT_ALPHA * u)
	if _phase == "hold":
		return Color(LivingStyle.NIGHT.r, LivingStyle.NIGHT.g, LivingStyle.NIGHT.b, LivingStyle.NIGHT_ALPHA)
	return _dawn_color()


func cut_alpha(uid: String, t: float) -> float:
	var rel = _find(uid, "relight")
	if rel != null and not bool(rel.waiting) and float(rel.t0) >= 0.0 and t - float(rel.t0) <= float(rel.dur):
		return 1.0 - _relight_b(rel, t)
	if not _in.has(uid):
		return 0.0
	var cut = _find(uid, "cut")
	if cut != null and bool(cut.waiting):
		return 0.0
	if _reduced:
		return LivingStyle.CUT_REDUCED_ALPHA
	if cut != null and float(cut.t0) >= 0.0 and t - float(cut.t0) < float(cut.dur):
		return 1.0 - _flicker_b(cut, t)
	return _steady_alpha(uid, t)


func cut_visible(uid: String, _t: float) -> bool:
	if not _in.has(uid):
		return false
	var cut = _find(uid, "cut")
	if cut != null and bool(cut.waiting):
		return false
	return true


func strain_alpha(uid: String, t: float) -> float:
	if _reduced:
		return 0.0
	var ev = _find(uid, "strain")
	if ev == null or bool(ev.waiting) or float(ev.t0) < 0.0:
		return 0.0
	if t - float(ev.t0) >= float(ev.dur):
		return 0.0
	return 1.0 - _flicker_b(ev, t)


func ward_color(uid: String, t: float) -> Color:
	if uid == "" or uid != _ward_uid or _ward_weight <= 0.001:
		return Color(0, 0, 0, 0)
	var breath := LivingStyle.WARD_REDUCED_ALPHA
	if not _reduced:
		var wave := 0.5 + 0.5 * sin(TAU * t / LivingStyle.WARD_PERIOD_S)
		breath = LivingStyle.WARD_ALPHA_LO + LivingStyle.WARD_ALPHA_SPAN * wave
	return Color(LivingStyle.WARD.r, LivingStyle.WARD.g, LivingStyle.WARD.b, breath * _ward_weight)


func frontier_alpha(level: int, cell: int) -> float:
	var key := "%d:%d" % [level, cell]
	if not _front.has(key):
		return -1.0
	var row: Dictionary = _front[key]
	var kind := str(row.get("kind", ""))
	if kind == "hidden":
		var dist := int(row.get("dist", 99))
		if dist <= 1:
			return LivingStyle.HIDDEN_NEAR
		if dist == 2:
			return LivingStyle.HIDDEN_D2
		return LivingStyle.HIDDEN_FAR
	if kind == "undug":
		return LivingStyle.UNDUG_ALPHA
	return -1.0


func cell_kind(level: int, cell: int) -> String:
	var key := "%d:%d" % [level, cell]
	if not _front.has(key):
		return ""
	return str(_front[key].get("kind", ""))


func lantern_edges(level: int, cell: int) -> Array:
	var key := "%d:%d" % [level, cell]
	if not _front.has(key):
		return []
	var edges: Array = _front[key].get("edges", [])
	return edges


func has_lantern(level: int, cell: int) -> bool:
	return not lantern_edges(level, cell).is_empty()


func cut_plan(uid: String) -> Dictionary:
	var ev = _find(uid, "cut")
	if ev == null:
		ev = _find(uid, "strain")
	if ev == null:
		return {}
	var gaps: Array = []
	var packed: PackedFloat32Array = ev.gaps
	for g in packed:
		gaps.append(float(g))
	return {"n": int(ev.n), "gaps": gaps, "dur": float(ev.dur), "kind": str(ev.kind), "waiting": bool(ev.waiting)}


func _start_cut(uid: String, week: int, t: float) -> void:
	var last := float(_last_entry.get(uid, -999.0))
	_drop_kind(uid, "relight")
	if last > -100.0 and t - last < LivingStyle.ENTRY_LIMIT_S:
		return
	if not _room_for_event(t):
		return
	_last_entry[uid] = t
	_events.append(_make_flicker(uid, week, t, "cut"))


func _start_relight(uid: String, t: float) -> void:
	var b0 := _brightness_now(uid, t)
	_drop_kind(uid, "cut")
	if _reduced:
		return
	if not _room_for_event(t):
		_drop_one("strain")
	if not _room_for_event(t):
		return
	var ev := {
		"uid": uid, "kind": "relight", "t0": t, "waiting": false,
		"n": 0, "gaps": PackedFloat32Array(), "dur": LivingStyle.RELIGHT_S, "b0": b0,
		"level": 0, "cell": 0,
	}
	_arm(ev, t)
	_events.append(ev)


func _start_strain(week: int, t: float) -> void:
	for uid in _generators:
		var id := str(uid)
		if _in.has(id):
			continue
		var meta: Dictionary = _meta.get(id, {})
		if bool(meta.get("offline", false)):
			continue
		if _active(id, "strain", t):
			continue
		var last := float(_last_entry.get(id, -999.0))
		if last > -100.0 and t - last < LivingStyle.ENTRY_LIMIT_S:
			continue
		if not _room_for_event(t):
			return
		_last_entry[id] = t
		_events.append(_make_flicker(id, week, t, "strain"))


func _make_flicker(uid: String, week: int, t: float, kind: String) -> Dictionary:
	var n := LivingStyle.DIP_N_BASE + posmod(hash([uid, week]), 3)
	var roll := RandomNumberGenerator.new()
	roll.seed = hash([uid, week, kind]) & 0x7fffffff
	var gaps := PackedFloat32Array()
	var gap_sum := 0.0
	for _i in n - 1:
		var g := LivingStyle.GAP_MIN + LivingStyle.GAP_SPAN * roll.randf()
		gaps.append(g)
		gap_sum += g
	var dur := LivingStyle.LEAD_S + float(n) * LivingStyle.DIP_S + gap_sum + LivingStyle.SETTLE_S
	var meta: Dictionary = _meta.get(uid, {})
	var ev := {
		"uid": uid, "kind": kind, "t0": t, "waiting": false,
		"n": n, "gaps": gaps, "dur": dur, "b0": 1.0,
		"level": int(meta.get("level", 0)), "cell": int(meta.get("cell", 0)),
	}
	_arm(ev, t)
	return ev


func _arm(ev: Dictionary, t: float) -> void:
	if _phase == "intro" or _phase == "hold":
		ev.waiting = true
		ev.t0 = -1.0
	else:
		ev.waiting = false
		ev.t0 = t


func _start_dawn(t: float) -> void:
	_phase = "dawn"
	_dawn = 0.0
	for ev in _events:
		if bool(ev.waiting):
			ev.waiting = false
			ev.t0 = t


func _dawn_color() -> Color:
	if _dawn < LivingStyle.DAWN_BLEND_S:
		var u := clampf(_dawn / LivingStyle.DAWN_BLEND_S, 0.0, 1.0)
		var c := LivingStyle.NIGHT.lerp(LivingStyle.DAWN, u)
		var a := lerpf(LivingStyle.NIGHT_ALPHA, LivingStyle.DAWN_ALPHA, u)
		return Color(c.r, c.g, c.b, a)
	var u := clampf((_dawn - LivingStyle.DAWN_BLEND_S) / (LivingStyle.DAWN_S - LivingStyle.DAWN_BLEND_S), 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - u, 3.0)
	var a := lerpf(LivingStyle.DAWN_ALPHA, 0.0, ease)
	return Color(LivingStyle.DAWN.r, LivingStyle.DAWN.g, LivingStyle.DAWN.b, a)


func _steady_alpha(uid: String, t: float) -> float:
	if _reduced:
		return LivingStyle.CUT_REDUCED_ALPHA
	var meta: Dictionary = _meta.get(uid, {})
	var level := float(int(meta.get("level", 0)))
	var cell := float(int(meta.get("cell", 0)))
	var wobble := sin(t * 1.1 + cell * 2.3) * 0.65 + sin(t * 0.37 + level * 1.7 + cell) * 0.35
	return clampf(LivingStyle.CUT_ALPHA_BASE + LivingStyle.CUT_WOBBLE * wobble, LivingStyle.CUT_ALPHA_MIN, LivingStyle.CUT_ALPHA_MAX)


func _flicker_b(ev: Dictionary, t: float) -> float:
	var elapsed := t - float(ev.t0)
	if elapsed < 0.0:
		return 1.0
	var cursor := LivingStyle.LEAD_S
	if elapsed < cursor:
		return 1.0
	var n := int(ev.n)
	var gaps: PackedFloat32Array = ev.gaps
	for i in n:
		if elapsed < cursor + LivingStyle.DIP_S:
			return LivingStyle.DIP_B
		cursor += LivingStyle.DIP_S
		if i < n - 1:
			var g := float(gaps[i])
			if elapsed < cursor + g:
				return LivingStyle.GAP_B
			cursor += g
	var u := clampf((elapsed - cursor) / LivingStyle.SETTLE_S, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - u, 3.0)
	var target := 1.0
	if str(ev.kind) == "cut":
		target = 1.0 - _steady_alpha(str(ev.uid), t)
	return lerpf(LivingStyle.GAP_B, target, ease)


func _relight_b(ev: Dictionary, t: float) -> float:
	var u := clampf((t - float(ev.t0)) / LivingStyle.RELIGHT_S, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - u, 3.0)
	return lerpf(float(ev.b0), 1.0, ease)


func _brightness_now(uid: String, t: float) -> float:
	var cut = _find(uid, "cut")
	if cut != null and not bool(cut.waiting) and float(cut.t0) >= 0.0 and t - float(cut.t0) < float(cut.dur):
		return _flicker_b(cut, t)
	if _in.has(uid):
		return 1.0 - _steady_alpha(uid, t)
	return 1.0


func _index_rooms(rooms: Array) -> void:
	_meta = {}
	_generators = []
	for room in rooms:
		var uid := str(room.get("uid", ""))
		if uid == "":
			continue
		_meta[uid] = {
			"level": int(room.get("level", 0)),
			"cell": int(room.get("cell", 0)),
			"type": str(room.get("type", "")),
			"offline": bool(room.get("offline", false)),
		}
		if str(room.get("type", "")) == "generator":
			_generators.append(uid)
	var kept := {}
	for uid in _last_entry:
		if _meta.has(str(uid)):
			kept[str(uid)] = _last_entry[uid]
	_last_entry = kept


func _rebuild_frontier(cells: Dictionary) -> void:
	_front = {}
	if cells.is_empty():
		return
	var kinds := {}
	var coords: Array = []
	for key in cells:
		var spot: Dictionary = cells[key]
		var level := int(spot.get("level", 0))
		var cell := int(spot.get("cell", 0))
		var id := str(key)
		var kind := "hidden"
		if str(spot.get("room", "")) != "":
			kind = "room"
		elif bool(spot.get("dug", false)):
			kind = "dug"
		else:
			var beside := false
			for nb in _neighbor_keys(level, cell, cells):
				if bool(cells[nb].get("dug", false)):
					beside = true
					break
			kind = "undug" if beside else "hidden"
		kinds[id] = kind
		coords.append([level, cell, id])
	var dist := {}
	var q: Array = []
	for item in coords:
		var id: String = item[2]
		if kinds[id] == "room" or kinds[id] == "dug":
			dist[id] = 0
			q.append([int(item[0]), int(item[1]), id])
	var head := 0
	while head < q.size():
		var item: Array = q[head]
		head += 1
		var level := int(item[0])
		var cell := int(item[1])
		var id: String = item[2]
		for nb in _neighbor_keys(level, cell, cells):
			if dist.has(nb):
				continue
			var spot: Dictionary = cells[nb]
			dist[nb] = int(dist[id]) + 1
			q.append([int(spot.get("level", 0)), int(spot.get("cell", 0)), nb])
	for item in coords:
		var level := int(item[0])
		var cell := int(item[1])
		var id: String = item[2]
		var edges: Array = []
		if str(kinds[id]) == "undug":
			if _kind_at(kinds, cells, level, cell - 1) == "room":
				edges.append("l")
			if _kind_at(kinds, cells, level, cell + 1) == "room":
				edges.append("r")
			if _kind_at(kinds, cells, level - 1, cell) == "room":
				edges.append("u")
			if _kind_at(kinds, cells, level + 1, cell) == "room":
				edges.append("d")
		_front[id] = {"kind": kinds[id], "dist": int(dist.get(id, 99)), "edges": edges}


func _neighbor_keys(level: int, cell: int, cells: Dictionary) -> Array:
	var out: Array = []
	for pair in [[level, cell - 1], [level, cell + 1], [level - 1, cell], [level + 1, cell]]:
		var key := "%d:%d" % [int(pair[0]), int(pair[1])]
		if cells.has(key):
			out.append(key)
	return out


func _kind_at(kinds: Dictionary, cells: Dictionary, level: int, cell: int) -> String:
	var key := "%d:%d" % [level, cell]
	if not cells.has(key):
		return ""
	return str(kinds.get(key, ""))


func _find(uid: String, kind: String):
	for ev in _events:
		if str(ev.uid) == uid and str(ev.kind) == kind:
			return ev
	return null


func _active(uid: String, kind: String, t: float) -> bool:
	var ev = _find(uid, kind)
	if ev == null:
		return false
	if bool(ev.waiting) or float(ev.t0) < 0.0:
		return true
	return t - float(ev.t0) < float(ev.dur)


func _drop_kind(uid: String, kind: String) -> void:
	var kept: Array = []
	for ev in _events:
		if str(ev.uid) == uid and str(ev.kind) == kind:
			continue
		kept.append(ev)
	_events = kept


func _drop_one(kind: String) -> void:
	for i in _events.size():
		if str(_events[i].kind) == kind:
			_events.remove_at(i)
			return


func _room_for_event(t: float) -> bool:
	_prune(t)
	return _events.size() < LivingStyle.MAX_EVENTS


func _prune(t: float) -> void:
	var kept: Array = []
	for ev in _events:
		if bool(ev.waiting) or float(ev.t0) < 0.0:
			kept.append(ev)
			continue
		if t - float(ev.t0) <= float(ev.dur) + 0.02:
			kept.append(ev)
	_events = kept
