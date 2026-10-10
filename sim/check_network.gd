extends SceneTree

## Headless network slice: projection, 25 stations, one idle run.
##   godot --headless --path . -s res://sim/check_network.gd


func _init() -> void:
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
		if int(game.stats.get("first_ultimatum", 0)) <= 0 or int(game.stats.get("first_ultimatum", 0)) > 20:
			failed = true
			print("ULTIMATUM gate missed")
		if int(game.stats.get("flip_week", 0)) <= 0 or int(game.stats.get("flip_week", 0)) > 30:
			failed = true
			print("FLIP gate missed")
		if not game.errors.is_empty():
			failed = true
	if failed:
		print("NETWORK CHECK FAILED")
		quit(1)
	else:
		print("NETWORK CHECK OK")
		quit(0)
