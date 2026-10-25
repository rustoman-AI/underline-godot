extends SceneTree

## Faction symbols on the network map (docs/briefs/cursor_map_symbols.txt).
##   godot --path . -s res://.tools/map_symbols_shots.gd -- --lang=en --size=1280x720 [--mode=before]
## Saves shots/map_symbols/<mode>/<lang>_<size>/:
##   map_start       the whole map at the start of a run.
##   map_owned       the player has taken five more stations (in memory only).
##   grand_L<n>, wall_L<n>, atlantic_L<n>  Grand Central, Wall St and Atlantic Av at tag levels 0, 1 and 2,
##                   every station known so all tags and symbols show.
##   sheet_<sid>, visit_<sid>  the station sheet and the visit screen for Wall St, Grand Central, Atlantic Av.
## --mode=before forces every symbol missing, which is the strip fallback, i.e. the map as it was. Each run writes
## tags.json (tag boxes and pin heads per shot); the "after" run compares with "before" and logs every tag that
## got wider and now overlaps a pin head or another tag it did not overlap before.

const FACTIONS := ["depot", "directorate", "synod", "exchange", "black_flag"]
const OWNED := ["plaza", "riverside", "stadium", "library", "quarry"]

var st
var nv
var game
var mode := "after"
var dir := ""
var tags := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var size := "1280x720"
	for arg in OS.get_cmdline_user_args():
		var a := str(arg)
		if a.begins_with("--lang="):
			Copy.set_lang(a.trim_prefix("--lang="))
		if a.begins_with("--size="):
			size = a.trim_prefix("--size=")
		if a.begins_with("--mode="):
			mode = a.trim_prefix("--mode=")
	dir = "map_symbols/%s/%s_%s" % [mode, Copy.lang, size]
	if "--recount" in OS.get_cmdline_user_args():
		tags = JSON.parse_string(FileAccess.get_file_as_string("res://shots/%s/tags.json" % dir))
		_overlaps(size)
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + dir))
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	st.hold_dawn = false
	await st._settle(st._shot_size())
	st._begin_new_game(false)
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	game = st.game
	st._refresh()
	st._toggle_network()
	nv = st.network_view
	if mode == "before":
		for fid in FACTIONS:
			nv._symbols[fid] = null
	await _settle()
	var faction_of: PackedStringArray = []
	for sid in game.stations:
		var fid: String = nv.station_faction(game, str(sid))
		if fid != "":
			faction_of.append("%s=%s" % [sid, fid])
	print("FACTION OF %s" % ", ".join(faction_of))
	nv._fit()
	await _shot("map_start")

	for sid in OWNED:
		game.stations[sid].owner = game.player
		game.stations[sid].known = true
	st._refresh()
	nv._fit()
	await _shot("map_owned")

	for sid in game.stations:
		game.stations[sid].known = true
	st._refresh()
	var places := {"grand": _by_name("Grand Central"), "wall": _by_name("Wall St"), "atlantic": _by_name("Atlantic Av")}
	print("PLACES %s" % str(places))
	for key in places:
		for ratio in [1.2, 2.2, 3.2]:
			nv.show_zoom(ratio, str(places[key]))
			await _settle()
			await _shot("%s_L%d" % [key, nv._tag_level()])
	nv._fit()
	for key in ["wall", "grand", "atlantic"]:
		var sid := str(places[key])
		nv.open_sheet(sid)
		await _settle()
		await _shot("sheet_" + sid, false)
		nv.close_sheet()
		nv.open_visit(sid)
		await _settle()
		await _shot("visit_" + sid, false)
		nv.close_visit()
	var f := FileAccess.open(ProjectSettings.globalize_path("res://shots/%s/tags.json" % dir), FileAccess.WRITE)
	f.store_string(JSON.stringify(tags, "\t"))
	f.close()
	if mode != "before":
		_compare(size)
	_overlaps(size)
	quit(0)


## Every tag on screen against every other station's pin head and every other tag, whatever the mode.
func _overlaps(size: String) -> void:
	var pins := 0
	var stacked := 0
	var lines: PackedStringArray = []
	var untagged: PackedStringArray = []
	for shot in tags:
		var row: Dictionary = tags[shot]
		for sid in row.tags:
			var box := _rect(row.tags[sid])
			for h in _hits(box, row.heads, sid):
				pins += 1
				lines.append("%s tag %s covers pin %s" % [shot, sid, h])
			for t in _hits(box, row.tags, sid):
				if str(t) > str(sid):
					stacked += 1
					lines.append("%s tags %s and %s overlap" % [shot, sid, t])
		for sid in row.get("own_untagged", []):
			untagged.append("%s %s" % [shot, sid])
	print("OVERLAPS %s %s %s: %d tag over pin, %d tag over tag in %d shots; player's stations on screen without a tag: %s%s" % [
		mode, Copy.lang, size, pins, stacked, tags.size(), ", ".join(untagged) if not untagged.is_empty() else "none",
		"" if lines.is_empty() else "\n  " + "\n  ".join(lines)])


func _by_name(name: String) -> String:
	for sid in game.stations:
		if str(game.stations[sid].get("name", "")) == name:
			return str(sid)
	return ""


func _settle() -> void:
	if st.toast_label != null:
		st.toast_label.visible = false
	nv._redraw()
	await st._frame()
	await st._frame()
	await st._frame()


func _shot(name: String, record := true) -> void:
	await _settle()
	st._save("%s/%s" % [dir, name])
	if not record:
		return
	var row := {"tags": {}, "heads": {}}
	var screen := Rect2(Vector2.ZERO, nv.size)
	for sid in nv._tags:
		var b: Rect2 = nv._tags[sid]
		if screen.intersects(b):
			row.tags[sid] = [b.position.x, b.position.y, b.size.x, b.size.y]
	for sid in nv._layout:
		var info: Dictionary = nv._layout[sid]
		var r := float(info.r)
		var head := Rect2(info.at - Vector2(r, r), Vector2(r, r) * 2.0)
		if screen.intersects(head):
			row.heads[sid] = [head.position.x, head.position.y, head.size.x, head.size.y]
	var untagged: Array = []
	for sid in row.heads:
		if str(game.stations[sid].owner) == str(game.player) and bool(game.stations[sid].get("known", false)) and not row.tags.has(sid):
			untagged.append(str(sid))
	row["own_untagged"] = untagged
	tags[name] = row


func _rect(a) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


func _hits(box: Rect2, group: Dictionary, skip: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for sid in group:
		if str(sid) != skip and box.intersects(_rect(group[sid])):
			out.append(str(sid))
	return out


func _compare(size: String) -> void:
	var path := "res://shots/map_symbols/before/%s_%s/tags.json" % [Copy.lang, size]
	if not FileAccess.file_exists(path):
		print("COMPARE no before run at %s" % path)
		return
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var lines: PackedStringArray = []
	var wider := 0
	var new_hits := 0
	for shot in tags:
		if not before.has(shot):
			continue
		var now: Dictionary = tags[shot]
		var was: Dictionary = before[shot]
		for sid in now.tags:
			var box := _rect(now.tags[sid])
			if not was.tags.has(sid):
				lines.append("%s %s placed now, not before" % [shot, sid])
				continue
			var old := _rect(was.tags[sid])
			if box.size.x <= old.size.x + 0.5:
				continue
			wider += 1
			var heads_now := _hits(box, now.heads, sid)
			var heads_was := _hits(old, was.heads, sid)
			var tags_now := _hits(box, now.tags, sid)
			var tags_was := _hits(old, was.tags, sid)
			var fresh: PackedStringArray = []
			for h in heads_now:
				if not heads_was.has(h):
					fresh.append("pin " + h)
			for t in tags_now:
				if not tags_was.has(t):
					fresh.append("tag " + t)
			if not fresh.is_empty():
				new_hits += 1
				lines.append("%s %s +%.0f px overlaps %s" % [shot, sid, box.size.x - old.size.x, ", ".join(fresh)])
		for sid in was.tags:
			if not now.tags.has(sid):
				lines.append("%s %s placed before, dropped now" % [shot, sid])
	print("COMPARE %s %s: %d wider tags, %d with a new overlap\n  %s" % [Copy.lang, size, wider, new_hits, "\n  ".join(lines)])
