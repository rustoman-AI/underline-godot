extends SceneTree

## P84 Transfer Hubs.
##   godot --headless --path . -s res://sim/check_transfer_hubs.gd
## Hub forms and clears from the open-passage graph. The map mark is omitted
## when its rect meets P78 R, P82 crescent, or P57 focus at max pin radius.
## Careful loss stays on the master 20/60 line (inside 15–35%). Soft dawn is not joined. Balance is untouched.

var failed := false


func _init() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("TRANSFER HUBS FAIL catalog " + catalog.error)
		quit(1)
		return
	if _strings():
		print("Strings: ok")
	if _graph(catalog):
		print("Graph: ok")
	if _clear(catalog):
		print("Clear: ok")
	if _float(catalog):
		print("Float: ok")
	if _mark():
		print("Mark: ok")
	if _dawn():
		print("Dawn: ok")
	if _save(catalog):
		print("Save: ok")
	if _surface():
		print("Surface: ok")
	_art()
	if failed:
		print("TRANSFER HUBS FAIL")
		quit(1)
		return
	var band := _careful(catalog)
	var lost := int(band.lost)
	var pct := 100.0 * float(lost) / 60.0
	print("Careful loss: %d/60 (%.1f%%)" % [lost, pct])
	if lost != 20:
		_bad("careful loss %d/60 moved off the master 20/60 line" % lost)
	if lost < 9 or lost > 21:
		print("NOTE spec names 15-35 percent of 60. Measured %d/60 (%.1f percent)." % [lost, pct])
	if failed:
		print("TRANSFER HUBS FAIL")
		quit(1)
		return
	print("TRANSFER HUBS OK")
	quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _game(catalog: Catalog, run_seed := 3) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/transfer_hubs.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P84":
		_bad("transfer_hubs.json roadmap")
		return false
	if str(pack.get("_soft_dawn", "")) != "NONE":
		_bad("transfer soft dawn")
		return false
	var rows: Dictionary = pack.get("by_key", {})
	var want := [
		"transfer.name", "transfer.tip", "transfer.first", "transfer.lost",
		"transfer.status", "transfer.status_none", "transfer.mark", "transfer.quiet",
	]
	if rows.size() != want.size():
		_bad("expected 8 transfer keys, got %d" % rows.size())
		return false
	for key in rows:
		if not str(key).begins_with("transfer."):
			_bad("namespace " + str(key))
			return false
		for banned in ["relay.", "duty.", "signal.", "ledger.", "toll."]:
			if str(key).begins_with(banned):
				_bad("banned key " + str(key))
				return false
	Copy.set_lang("en")
	for key in want:
		if not rows.has(key):
			_bad("missing " + key)
			return false
		var en := str(rows[key].get("en", ""))
		if Copy.t(key) != en:
			_bad("EN %s got %s" % [key, Copy.t(key)])
			return false
	if Copy.t("transfer.tip") != "Transfer Hub. Three ways open.":
		_bad("tip redefined")
		return false
	if Copy.t("transfer.first") != "A junction on the Line.":
		_bad("first redefined")
		return false
	if Copy.t("transfer.lost") != "Hub quiet. Ways closed.":
		_bad("lost redefined")
		return false
	Copy.set_lang("ru")
	for key in want:
		var ru := str(rows[key].get("ru", ""))
		if ru == "" or Copy.t(key) != ru:
			_bad("RU %s got %s" % [key, Copy.t(key)])
			return false
	if Copy.t("transfer.name") != "Пересадка":
		_bad("RU name")
		return false
	if Copy.t("transfer.status_none") != "Пересадки нет.":
		_bad("RU status_none")
		return false
	Copy.set_lang("en")
	var src := FileAccess.get_file_as_string("res://sim/transfer_hubs.gd")
	if src.find("balance.json") >= 0 or src.find("stock.") >= 0 or src.find("_add_hope") >= 0:
		_bad("hub sim touches balance")
		return false
	return true


func _own(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.hidden = false
	st.bunker = ""
	st.ruin = false
	st.known = true


func _graph(catalog: Catalog) -> bool:
	var game := _game(catalog)
	if TransferHubs.open_degree(game, "northgate") < 3:
		_bad("northgate degree %d" % TransferHubs.open_degree(game, "northgate"))
		return false
	if TransferHubs.open_degree(game, "plaza") < 3:
		_bad("plaza degree %d" % TransferHubs.open_degree(game, "plaza"))
		return false
	if TransferHubs.open_degree(game, "clocktower") < 3:
		_bad("clocktower degree %d" % TransferHubs.open_degree(game, "clocktower"))
		return false
	if TransferHubs.open_degree(game, str(game.capital_id)) >= 3:
		_bad("home capital already a hub")
		return false
	if TransferHubs.is_hub(game, "northgate") or TransferHubs.is_hub(game, "plaza"):
		_bad("foreign junction became a hub")
		return false
	_own(game, "plaza")
	if not TransferHubs.is_hub(game, "plaza"):
		_bad("owned plaza is not a hub")
		return false
	game.stations.plaza.passage = false
	if not TransferHubs.is_hub(game, "plaza"):
		_bad("hub required the deal passage flag")
		return false
	var home := str(game.capital_id)
	if TransferHubs.is_hub(game, home):
		_bad("degree-1 capital is a hub")
		return false
	_link(game, home, "plaza")
	_link(game, home, "central")
	if TransferHubs.open_degree(game, home) < 3 or not TransferHubs.is_hub(game, home):
		_bad("capital did not qualify at degree %d" % TransferHubs.open_degree(game, home))
		return false
	_link(game, "archive", "foundry")
	_link(game, "archive", "garden")
	_link(game, "archive", "mill")
	game.stations.archive.owner = game.player
	game.stations.archive.hidden = false
	if TransferHubs.open_degree(game, "archive") < 3 or TransferHubs.is_hub(game, "archive"):
		_bad("bunker hub")
		return false
	game.stations.archive.bunker = ""
	if not TransferHubs.is_hub(game, "archive"):
		_bad("cleared bunker did not qualify")
		return false
	_link(game, "vault", "foundry")
	_link(game, "vault", "garden")
	_link(game, "vault", "mill")
	game.stations.vault.owner = game.player
	game.stations.vault.hidden = false
	if not bool(game.stations.vault.ruin) or TransferHubs.is_hub(game, "vault"):
		_bad("ruin hub")
		return false
	_link(game, "signal", "foundry")
	_link(game, "signal", "garden")
	_link(game, "signal", "mill")
	game.stations.signal.owner = game.player
	game.stations.signal.bunker = ""
	game.stations.signal.ruin = false
	if not bool(game.stations.signal.hidden) or TransferHubs.is_hub(game, "signal"):
		_bad("hidden hub")
		return false
	var quiet := _game(catalog, 4)
	_own(quiet, "market")
	if TransferHubs.open_degree(quiet, "market") >= 3 or TransferHubs.is_hub(quiet, "market"):
		_bad("degree-2 station became a hub")
		return false
	var row: Dictionary = TransferHubs.visit_row(game, "plaza")
	if str(row.status) != "transfer.status" or str(row.tip) != "transfer.tip" or bool(row.muted):
		_bad("visit hub row " + str(row))
		return false
	var none: Dictionary = TransferHubs.visit_row(quiet, "market")
	if str(none.status) != "transfer.status_none" or str(none.tip) != "transfer.quiet" or not bool(none.muted):
		_bad("visit none row " + str(none))
		return false
	if str(TransferHubs.visit_row(game, "northgate").status) != "":
		_bad("foreign visit status")
		return false
	if TransferHubs.hover_lines(game, "plaza").size() != 1 or TransferHubs.hover_lines(quiet, "market").size() != 0:
		_bad("hover is not tip-only")
		return false
	return true


func _link(game: Game, a: String, b: String) -> void:
	game.tunnels.append({
		"id": "th_%s_%s" % [a, b],
		"a": a,
		"b": b,
		"state": "open",
		"sealed": false,
		"dug": true,
		"closed_until": 0,
	})


func _clear(catalog: Catalog) -> bool:
	var game := _game(catalog, 5)
	_own(game, "plaza")
	_own(game, "clocktower")
	TransferHubs.sync(game)
	if game.transfer_hub_sids.find("plaza") < 0 or game.transfer_hub_sids.find("clocktower") < 0:
		_bad("sync did not cache hubs " + str(game.transfer_hub_sids))
		return false
	if not game.notices.is_empty():
		_bad("forming toasted lost")
		return false
	game.stations.plaza.owner = "neutral"
	var before := game.notices.size()
	TransferHubs.sync(game)
	if TransferHubs.is_hub(game, "plaza") or game.transfer_hub_sids.find("plaza") >= 0:
		_bad("lost ownership did not clear")
		return false
	if game.notices.size() != before + 1 or str(game.notices.back()) != "Hub quiet. Ways closed.":
		_bad("lost toast " + str(game.notices))
		return false
	TransferHubs.sync(game)
	if game.notices.size() != before + 1:
		_bad("lost toast repeated")
		return false
	var edge: Dictionary = game._edge("clocktower", "harbor")
	if edge.is_empty():
		_bad("clocktower harbor edge missing")
		return false
	edge.closed_until = 99
	if TransferHubs.open_degree(game, "clocktower") >= 3:
		_bad("closed edge still counted")
		return false
	TransferHubs.sync(game)
	if TransferHubs.is_hub(game, "clocktower") or str(game.notices.back()) != "Hub quiet. Ways closed.":
		_bad("degree drop did not clear")
		return false
	if game.notices.size() != before + 2:
		_bad("degree drop toast " + str(game.notices))
		return false
	return true


func _float(catalog: Catalog) -> bool:
	var game := _game(catalog, 6)
	if TransferHubs.note(game) != "" or bool(game.flags.get("seen_transfer_hub", false)):
		_bad("float before a hub")
		return false
	_own(game, "plaza")
	var line := TransferHubs.note(game)
	if line != "A junction on the Line." or not bool(game.flags.get("seen_transfer_hub", false)):
		_bad("first float " + line)
		return false
	if TransferHubs.note(game) != "":
		_bad("float repeated")
		return false
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var loaded := Game.new()
	loaded.catalog = catalog
	if not loaded.import_state(data) or not bool(loaded.flags.get("seen_transfer_hub", false)):
		_bad("flag did not save")
		return false
	if TransferHubs.note(loaded) != "":
		_bad("float after load")
		return false
	if game.transfer_joins_soft_dawn() or TransferHubs.joins_soft_dawn():
		_bad("first float joined soft dawn")
		return false
	return true


func _mark() -> bool:
	if TransferHubs.MARK_PX < 12.0 or TransferHubs.MARK_PX > 14.0:
		_bad("mark px %s" % str(TransferHubs.MARK_PX))
		return false
	if TransferHubs.MARK_SLOT != Vector2(-0.32, 0.22):
		_bad("mark slot shifted")
		return false
	var layout := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if layout.find("const PIN_CAPITAL := 52.0") < 0 or layout.find("const ZOOM_SPAN := 3.5") < 0:
		_bad("pin constants drifted")
		return false
	if layout.find("var radius := px * 0.42") < 0 or layout.find("(1.0 + (0.4 if big else 0.22)") < 0:
		_bad("max pin formula drifted")
		return false
	var radius := TransferHubs.max_pin_radius()
	if radius < 40.0:
		_bad("max pin radius %s" % str(radius))
		return false
	if TransferHubs.overlaps_slot(TransferHubs.MARK_SLOT, radius):
		_bad("locked slot overlaps P78/P82/P57 at r=%s — mark must omit" % str(radius))
		if TransferHubs.slot_clean():
			_bad("overlap did not omit")
		return false
	if not TransferHubs.slot_clean():
		_bad("clean slot reported dirty")
		return false
	if not TransferHubs.overlaps_slot(TransferHubs.FOCUS_SLOT, radius):
		_bad("overlap detector missed the focus rect")
		return false
	if not TransferHubs.overlaps_slot(TransferHubs.RELAY_SLOT, radius):
		_bad("overlap detector missed the relay rect")
		return false
	if not TransferHubs.overlaps_slot(TransferHubs.CRESCENT_SLOT, radius):
		_bad("overlap detector missed the crescent rect")
		return false
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if src.find("MARK_PX") < 0 and src.find("TransferHubs.MARK_PX") < 0:
		_bad("draw does not use the locked size")
		return false
	if src.find("icon == null") < 0:
		_bad("missing texture is not omitted")
		return false
	print("Mark slot clean at max pin radius %.2f" % radius)
	return true


func _dawn() -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("soft dawn stack changed")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var end := src.find("func dawn_soft_chip", at)
	var picker := src.substr(at, end - at)
	if picker.find("transfer") >= 0:
		_bad("soft dawn picker knows transfer")
		return false
	if src.find("func transfer_joins_soft_dawn") < 0:
		_bad("transfer dawn hook missing")
		return false
	return true


func _save(catalog: Catalog) -> bool:
	if Game.SAVE_SCHEMA != 21:
		_bad("schema %s" % str(Game.SAVE_SCHEMA))
		return false
	var game := _game(catalog, 8)
	_own(game, "plaza")
	TransferHubs.sync(game)
	game.flags["seen_transfer_hub"] = true
	var data := game.export_state()
	data["schema"] = 17
	var again := Game.new()
	again.catalog = catalog
	if not again.import_state(data) or again.transfer_hub_sids.find("plaza") < 0:
		_bad("schema 17 roundtrip " + again.load_error)
		return false
	data.erase("transfer_hub_sids")
	var bare := Game.new()
	bare.catalog = catalog
	if bare.import_state(data):
		_bad("schema 17 accepted a missing cache")
		return false
	var old := game.export_state()
	old["schema"] = 16
	old.erase("transfer_hub_sids")
	var legacy := Game.new()
	legacy.catalog = catalog
	if not legacy.import_state(old) or not legacy.transfer_hub_sids.is_empty():
		_bad("schema 16 migrate " + legacy.load_error)
		return false
	return true


func _surface() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	for needle in ["_add_transfer_status", "_draw_transfer_mark", "TransferHubs.note", "TransferHubs.hover_lines"]:
		if src.find(needle) < 0:
			_bad("surface missing " + needle)
			return false
	var sim := FileAccess.get_file_as_string("res://sim/transfer_hubs.gd")
	if sim.find("transfer.first") < 0 or sim.find("transfer.lost") < 0:
		_bad("float or lost key not wired")
		return false
	if src.find("func _draw_focus_letter") >= 0 or src.find("func _draw_relay") >= 0:
		_bad("stole a locked map slot")
		return false
	return true


func _art() -> void:
	if not TransferHubs.texture_ready():
		print("Art: omitted transfer_mark_24")
		return
	print("Art: wired transfer_mark_24")


func _careful(catalog: Catalog) -> Dictionary:
	var lost := 0
	for run_seed in range(1, 61):
		var row: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(row.get("over", "")) != "time":
			lost += 1
		if run_seed % 15 == 0:
			print("  careful %d/60 lost %d" % [run_seed, lost])
	return {"lost": lost}
