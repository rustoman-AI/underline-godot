extends SceneTree

## Headless checks for P28 Map Alive.
##   godot --headless --path . -s res://sim/check_map_alive.gd


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("MAP ALIVE FAIL catalog ", catalog.error)
		quit(1)
		return
	var failed := false
	if not _check_rumors(catalog):
		failed = true
	if not _check_gift(catalog):
		failed = true
	if not _check_verbs(catalog):
		failed = true
	if not _check_intent(catalog):
		failed = true
	if not _check_art():
		failed = true
	if not _check_schema(catalog):
		failed = true
	if failed:
		print("MAP ALIVE FAIL")
		quit(1)
		return
	print("MAP ALIVE OK")
	quit(0)


func _check_rumors(catalog: Catalog) -> bool:
	for run_seed in [1, 2, 7]:
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		if game.over == "error":
			print("Rumor: FAIL setup seed %d" % run_seed)
			return false
		if not _one_rumor(game, "seed %d week 1" % run_seed):
			return false
		if run_seed == 1 and game.rumor_count() != 1:
			print("Rumor: FAIL seed 1 week 1 has %d" % game.rumor_count())
			return false
		var guard := 0
		while game.over == "" and game.week < 18 and guard < 24:
			guard += 1
			game.end_week()
			if not _one_rumor(game, "seed %d week %d" % [run_seed, game.week]):
				return false
	var owned := Game.new()
	owned.setup(catalog, 1, 40)
	if owned.rumor_count() != 1:
		print("Rumor: FAIL owned-clear had no rumor")
		return false
	var sid := str(owned.rumor.get("station", ""))
	owned.stations[sid].owner = owned.player
	owned._roll_rumor()
	if owned._rumor_live() and str(owned.rumor.get("station", "")) == sid:
		print("Rumor: FAIL owned station %s still live" % sid)
		return false
	var radio := Game.new()
	radio.setup(catalog, 1, 40)
	if not is_equal_approx(radio.rumor_truth_chance(), 0.6):
		print("Rumor: FAIL truth chance %s" % radio.rumor_truth_chance())
		return false
	radio.rooms.append({"type": "radio", "offline": false, "staff": ["chris"]})
	if not is_equal_approx(radio.rumor_truth_chance(), 0.9):
		print("Rumor: FAIL radio truth chance %s" % radio.rumor_truth_chance())
		return false
	var label := radio.rumor_label()
	var community := radio.station_text(str(radio.rumor.get("station", "")), "community")
	if radio.rumor_count() == 1 and label != community and label != Copy.t("rumor.chip_fallback"):
		print("Rumor: FAIL chip label %s" % label)
		return false
	var toast := radio.rumor_toast()
	if radio.rumor_count() == 1 and not toast.begins_with("Rumor:"):
		print("Rumor: FAIL toast %s" % toast)
		return false
	return true


func _one_rumor(game: Game, where: String) -> bool:
	if game.rumor_count() > 1:
		print("Rumor: FAIL %s count %d" % [where, game.rumor_count()])
		return false
	if game.rumor.is_empty():
		return true
	for key in ["station", "text_key", "week_until", "true"]:
		if not game.rumor.has(key):
			print("Rumor: FAIL %s missing %s" % [where, key])
			return false
	return true


func _check_gift(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	if game.over == "error":
		print("Gift: FAIL setup")
		return false
	var sid := str(game.catalog.factions["exchange"].capital)
	var n := int(game.bal.gift_opinion)
	game.stock.tokens = int(game.bal.gift_tokens) + 5
	if not game.verb_shown("gift", sid):
		print("Gift: FAIL button hidden on %s" % sid)
		return false
	if game.order_block("gift", sid) != "":
		print("Gift: FAIL blocked: %s" % game.order_block("gift", sid))
		return false
	var action := {"kind": "order", "order": "gift", "faction": "exchange", "station": sid}
	var toast := game.order_toast("gift", action)
	var expect := "Gift → Exchange · Opinion ~+%d" % n
	if toast != expect:
		print("Gift: FAIL toast %s" % toast)
		return false
	var community := game.station_text(sid, "community")
	if community != "" and toast.contains(community):
		print("Gift: FAIL toast names the station %s" % toast)
		return false
	var was := int(game.opinions.get("exchange", 0))
	if not game.queue_order(action):
		print("Gift: FAIL queue")
		return false
	game._resolve_queued()
	var found := false
	for report in game.order_reports:
		if str(report.get("kind", "")) != "gift":
			continue
		found = true
		if not bool(report.get("ok", false)):
			print("Gift: FAIL report not ok")
			return false
		if int(report.get("before", -999)) != was:
			print("Gift: FAIL before %s want %d" % [report.get("before"), was])
			return false
		if int(report.get("after", -999)) < was:
			print("Gift: FAIL after %s" % report.get("after"))
			return false
		var text := str(report.get("text", ""))
		if not text.contains(str(report.get("before"))) or not text.contains(str(report.get("after"))) or not text.contains("→"):
			print("Gift: FAIL report text %s" % text)
			return false
		if not text.contains("Exchange"):
			print("Gift: FAIL report misses the faction %s" % text)
			return false
	if not found:
		print("Gift: FAIL no report")
		return false
	return true


func _check_verbs(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 3, 40)
	if game.verb_shown("gift", "riverside"):
		print("Verbs: FAIL gift shown on a neutral station")
		return false
	if game.demands.is_empty() and game.verb_shown("pay", "trampark"):
		print("Verbs: FAIL pay shown with no demand")
		return false
	if not game.verb_shown("aid", "riverside"):
		print("Verbs: FAIL aid hidden on a bordering station")
		return false
	for need in game.stations["riverside"].needs:
		need.fill = 1.0
	if game.verb_shown("aid", "riverside"):
		print("Verbs: FAIL aid shown when every need is full")
		return false
	var view := NetworkView.new()
	var foreign: Array = view.order_rows(game, false, "trampark")
	var kinds: Array = []
	for row in foreign:
		kinds.append(str(row[0]))
	if not kinds.has("gift"):
		print("Verbs: FAIL gift missing from the card")
		return false
	if kinds.has("pay"):
		print("Verbs: FAIL pay on the card with no demand")
		return false
	var neutral: Array = view.order_rows(game, false, "riverside")
	for row in neutral:
		if str(row[0]) == "gift":
			print("Verbs: FAIL gift row on a neutral station")
			return false
	return true


func _check_intent(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.map_playback.clear()
	game._resolve_intent({"faction": "exchange", "kind": "preach", "hidden": false})
	if not game.map_playback.is_empty():
		print("Intent: FAIL preach queued")
		return false
	game._resolve_intent({"faction": "exchange", "kind": "hold", "hidden": true})
	if not game.map_playback.is_empty():
		print("Intent: FAIL hidden intent queued")
		return false
	game._resolve_intent({"faction": "exchange", "kind": "hold", "hidden": false})
	if game.map_playback.size() != 1:
		print("Intent: FAIL queue %d" % game.map_playback.size())
		return false
	var chip := str(game.map_playback[0].get("chip", ""))
	if chip != "map.chip.held":
		print("Intent: FAIL chip %s" % chip)
		return false
	if chip.contains("preach"):
		print("Intent: FAIL preach chip")
		return false
	var view := NetworkView.new()
	view.drain_map_playback(game)
	if not game.map_playback.is_empty():
		print("Intent: FAIL queue survived drain")
		return false
	game._resolve_intent({"faction": "exchange", "kind": "hold", "hidden": false})
	if game.map_playback.size() != 1:
		print("Intent: FAIL second queue")
		return false
	var desk := Desk.new()
	desk.game = game
	view.host = desk
	# _draw_ink drains through _game() before it paints. Call that same step here so the
	# check does not draw outside NOTIFICATION_DRAW.
	view.drain_map_playback(view._game())
	if not game.map_playback.is_empty():
		print("Intent: FAIL queue survived draw")
		return false
	return true


class Desk extends Node:
	var game


func _check_art() -> bool:
	if ArtPack.icon_texture("rumor", 14.0) == null:
		print("Art: FAIL rumor icon")
		return false
	if ArtPack.icon_texture("gift", 24.0) == null or ArtPack.icon_texture("aid", 24.0) == null or ArtPack.icon_texture("pay", 24.0) == null:
		print("Art: FAIL order icons")
		return false
	if ArtPack.map_chip("intent_bought") == null or ArtPack.map_chip("intent_bought", true) == null:
		print("Art: FAIL bought chip")
		return false
	if ArtPack.map_chip("intent_marched") == null or ArtPack.map_chip("intent_held") == null:
		print("Art: FAIL march/hold chip")
		return false
	if ArtPack.map_chip("intent_preached") == null or ArtPack.map_chip("intent_preached", true) == null:
		print("Art: FAIL spare preached chip")
		return false
	if ArtPack.map_stamp("gift") == null or ArtPack.map_stamp("aid") == null or ArtPack.map_stamp("pay") == null:
		print("Art: FAIL stamps")
		return false
	return true


func _check_schema(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	var data := game.export_state()
	data.erase("rumor")
	data["schema"] = 10
	var loaded := Game.new()
	loaded.catalog = catalog
	if not loaded.import_state(data):
		print("Schema: FAIL import %s" % loaded.load_error)
		return false
	if not loaded.rumor.is_empty():
		print("Schema: FAIL old save kept a rumor")
		return false
	return true
