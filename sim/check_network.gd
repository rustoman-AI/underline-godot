extends SceneTree

## Headless network slice: projection, 25 stations, one idle run.
##   godot --headless --path . -s res://sim/check_network.gd


## Propaganda's last push toward 100 adds only what is left and costs only that share of the price.
func _last_push_ok(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	var sid := ""
	for n in game._neighbors(game.capital_id):
		if str(game.stations[str(n)].owner) == "neutral" and game.sympathy_preview(str(n)) > 4:
			sid = str(n)
			break
	if sid == "":
		print("LAST PUSH no neutral neighbour")
		return false
	var swing := game.sympathy_preview(sid)
	var full := int(game.bal.propaganda_influence)
	game.stations[sid].sympathy = 0
	var fresh_ok := game.propaganda_gain(sid) == swing and game.propaganda_cost(sid) == full
	game.stations[sid].sympathy = 100 - swing / 2
	var left := 100 - int(game.stations[sid].sympathy)
	var want := maxi(1, int(ceil(float(full) * float(left) / float(swing))))
	var last_ok := game.propaganda_gain(sid) == left and game.propaganda_cost(sid) == want and want < full
	print("Last push: swing %d costs %d; %d left costs %d: %s" % [swing, full, left, game.propaganda_cost(sid), "ok" if fresh_ok and last_ok else "FAIL"])
	return fresh_ok and last_ok


func _init() -> void:
	Copy.set_lang("en")
	var failed := false
	for err in Geo.self_check():
		failed = true
		print("GEO ", err)
	if not failed:
		print("Geo: ok")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("CATALOG ", catalog.error)
		quit(1)
		return
	if not _station_text_ok(catalog):
		failed = true
	var game := Game.new()
	game.setup(catalog, 1, 40)
	if game.over == "error":
		failed = true
		print("SETUP ", game.errors)
	else:
		print("Stations %d capital %s" % [game.stations.size(), game.capital_id])
		var spec: Dictionary = catalog.geo.projection
		var land: Dictionary = catalog.geo.land
		var raw: Array = land.man
		var dense := Geo.densify_ring(raw, 0.0025)
		print("Manhattan corners %d densified %d" % [raw.size(), dense.size()])
		if dense.size() <= raw.size():
			failed = true
			print("DENSIFY did not add points")
		var guard := 0
		while game.over == "" and game.week < 21 and guard < 25:
			guard += 1
			game.end_week()
		print("Idle week %d over %s ultimatum %s flip %s errors %s" % [
			game.week, game.over, str(game.stats.get("first_ultimatum", 0)),
			str(game.stats.get("flip_week", 0)), str(game.errors)])
		var ult := int(game.stats.get("first_ultimatum", 0))
		var flip := int(game.stats.get("flip_week", 0))
		if ult < 6 or ult > 16:
			failed = true
			print("ULTIMATUM gate missed")
		if flip < 4:
			failed = true
			print("FLIP gate missed")
		if not game.errors.is_empty():
			failed = true
	if not _last_push_ok(catalog):
		failed = true
	if failed:
		print("NETWORK CHECK FAILED")
		quit(1)
	else:
		print("NETWORK CHECK OK")
		quit(0)


## Every station in station_communities.json has community, who, conflict and art in English, none empty,
## no Cyrillic in the English file, no em dash in either; English display falls back to Russian where missing.
func _station_text_ok(catalog: Catalog) -> bool:
	var ok := true
	var cyrillic := RegEx.create_from_string("[\\x{0400}-\\x{04FF}]")
	var ru: Dictionary = catalog.communities.get("stations", {})
	var en: Dictionary = catalog.communities_en.get("stations", {})
	for sid in ru:
		var row: Dictionary = en.get(sid, {})
		for field in Game.STATION_TEXT:
			var text := str(row.get(field, "")).strip_edges()
			if text == "":
				ok = false
				print("WARN station %s has no English %s; English shows the Russian line" % [sid, field])
			elif cyrillic.search(text) != null:
				ok = false
				print("STATION TEXT %s.%s (en) has Cyrillic: %s" % [sid, field, text])
	for sid in en:
		if not ru.has(sid):
			ok = false
			print("STATION TEXT %s is in the English file but not the Russian one" % sid)
	for file in ["station_communities.json", "station_communities_en.json"]:
		var lines := FileAccess.get_file_as_string("res://data/" + file).split("\n")
		for i in lines.size():
			if "\u2014" in lines[i]:
				ok = false
				print("STATION TEXT em dash in %s line %d" % [file, i + 1])
	var game := Game.new()
	game.catalog = catalog
	var was := Copy.lang
	Copy.set_lang("en")
	for sid in ru:
		for field in Game.STATION_TEXT:
			var shown := game.station_text(str(sid), field)
			if cyrillic.search(shown) != null:
				ok = false
				print("STATION TEXT English display of %s.%s is Russian" % [sid, field])
	Copy.set_lang(was)
	if ok:
		print("Station text: %d stations, English complete, no em dash: ok" % ru.size())
	return ok
