extends SceneTree

## P51 Join Pulse. A join or a player capture plays one pin beat and an optional toast.
## Reduce-motion skips the beat and still toasts. No soft dawn chip. No balance drift.
##   godot --headless --path . -s res://sim/check_join_pulse.gd


class Host extends Node:
	var game
	var dim: ColorRect
	var shot_mode := false
	var motion_in_shots := false
	var toasts: Array = []

	func _toast(text: String, _hold: float = 1.8) -> void:
		toasts.append(str(text))


var failed := false
var balance_text := ""


func _init() -> void:
	Copy.set_lang("en")
	balance_text = FileAccess.get_file_as_string("res://data/balance.json")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	if not _check_strings():
		failed = true
	if not _check_join(catalog):
		failed = true
	if not _check_capture(catalog):
		failed = true
	if not _check_lost(catalog):
		failed = true
	if not _check_reduce(catalog):
		failed = true
	if not _check_once(catalog):
		failed = true
	if not _check_dawn(catalog):
		failed = true
	if not _check_chrome():
		failed = true
	if not _check_save(catalog):
		failed = true
	if not _check_balance():
		failed = true
	Settings.reduce_motion = false
	if failed:
		print("JOIN PULSE FAIL")
		quit(1)
		return
	print("JOIN PULSE OK")
	quit(0)


func _game(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.week = 5
	game.stock.influence = 40
	game.stock.food = 40
	game.stock.materials = 40
	return game


func _neighbor(game: Game) -> String:
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(sid) == str(game.capital_id):
			continue
		if str(st.owner) != "neutral":
			continue
		if str(st.get("bunker", "")) != "" or bool(st.get("hidden", false)):
			continue
		if game.borders_player(str(sid)):
			return str(sid)
	return ""


func _view(game: Game) -> Dictionary:
	var view := NetworkView.new()
	var host := Host.new()
	host.game = game
	view.host = host
	return {"view": view, "host": host}


func _fail(msg: String) -> bool:
	failed = true
	print("Join: FAIL ", msg)
	return false


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("join.pulse") != "{station} stands with you.":
		return _fail("pulse en " + Copy.t("join.pulse"))
	if Copy.t("join.taken") != "{station} is yours.":
		return _fail("taken en " + Copy.t("join.taken"))
	if Copy.t("join.lost") != "{station} fell.":
		return _fail("lost en " + Copy.t("join.lost"))
	if Copy.t("join.first") != "When they join, the pin answers.":
		return _fail("first en " + Copy.t("join.first"))
	if Copy.t("join.reduce") != "Joined.":
		return _fail("reduce en " + Copy.t("join.reduce"))
	if Copy.fill("join.pulse", {"station": "Jay"}) != "Jay stands with you.":
		return _fail("fill pulse")
	if Copy.fill("join.taken", {"station": "Jay"}) != "Jay is yours.":
		return _fail("fill taken")
	if Copy.fill("join.lost", {"station": "Jay"}) != "Jay fell.":
		return _fail("fill lost")
	Copy.set_lang("ru")
	if Copy.t("join.pulse") != "{station} встаёт рядом.":
		return _fail("pulse ru " + Copy.t("join.pulse"))
	if Copy.t("join.taken") != "{station} — ваша.":
		return _fail("taken ru " + Copy.t("join.taken"))
	if Copy.t("join.lost") != "{station} пала.":
		return _fail("lost ru " + Copy.t("join.lost"))
	if Copy.t("join.first") != "Когда встают рядом — пин отвечает.":
		return _fail("first ru " + Copy.t("join.first"))
	if Copy.t("join.reduce") != "С нами.":
		return _fail("reduce ru " + Copy.t("join.reduce"))
	if Copy.fill("join.pulse", {"station": "Джей"}) != "Джей встаёт рядом.":
		return _fail("fill pulse ru")
	if Copy.t("{station} stands with you.") != "{station} встаёт рядом.":
		return _fail("ru.json pulse")
	if Copy.t("{station} is yours.") != "{station} — ваша.":
		return _fail("ru.json taken")
	if Copy.t("{station} fell.") != "{station} пала.":
		return _fail("ru.json lost")
	if Copy.t("When they join, the pin answers.") != "Когда встают рядом — пин отвечает.":
		return _fail("ru.json first")
	if Copy.t("Joined.") != "С нами.":
		return _fail("ru.json reduce")
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_join(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("join no neighbor")
	var st: Dictionary = game.stations[sid]
	st.deals = 2
	st.sympathy = 30
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var op := game.opinions.duplicate(true)
	if not game._order_deal(sid):
		return _fail("join order " + game._deal_block(sid))
	if str(st.owner) != str(game.player):
		return _fail("join owner " + str(st.owner))
	if str(st.get("join_pulse_kind", "")) != "join" or not bool(st.get("join_pulse", false)):
		return _fail("join flag " + str(st.get("join_pulse_kind", "")))
	if int(game.hope) - hope0 != int(game.bal.join_hope):
		return _fail("join hope %d" % (int(game.hope) - hope0))
	if int(game.discontent) - dis0 != int(game.bal.join_discontent):
		return _fail("join discontent")
	if game.opinions != op:
		return _fail("join opinion")
	var pack: Dictionary = _view(game)
	var view: NetworkView = pack.view
	var host: Host = pack.host
	if not view._arm_join_pulses():
		return _fail("join did not arm")
	if not is_equal_approx(float(view._join_left.get(sid, -1)), NetworkView.JOIN_PULSE_S):
		return _fail("join duration " + str(view._join_left.get(sid, "")))
	if view._join_dim.has(sid):
		return _fail("join dim")
	if bool(st.get("join_pulse", false)) or st.has("join_pulse_kind"):
		return _fail("join flag lingered")
	var want := game.join_toast_line(sid, "join", false)
	if want == "" or not want.ends_with("stands with you.") or host.toasts.size() != 1 or str(host.toasts[0]) != want:
		return _fail("join toast " + str(host.toasts))
	if view._arm_join_pulses() or host.toasts.size() != 1:
		return _fail("join second arm")
	if not view._tick_join_pulses(0.2) or not view._join_left.has(sid):
		return _fail("join mid beat")
	if float(view._join_left[sid]) > NetworkView.JOIN_PULSE_S:
		return _fail("join grew")
	view._tick_join_pulses(0.25)
	if view._join_left.has(sid) or view._join_dim.has(sid):
		return _fail("join chrome stayed")
	if view._tick_join_pulses(1.0):
		return _fail("join looped")
	print("Join: ok")
	return true


func _check_capture(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("capture no neighbor")
	var st: Dictionary = game.stations[sid]
	st.owner = "directorate"
	st.known = true
	st.low_weeks = 2
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var op0 := int(game.opinions.get("directorate", 0))
	if not game._capture(sid, game.player, true):
		return _fail("capture refused")
	if str(st.owner) != str(game.player) or str(st.get("join_pulse_kind", "")) != "taken":
		return _fail("capture kind " + str(st.get("join_pulse_kind", "")))
	if int(game.hope) - hope0 != int(game.bal.assault_hope) or int(game.discontent) - dis0 != int(game.bal.assault_discontent):
		return _fail("capture balance drift")
	if int(game.opinions.get("directorate", 0)) != op0 - 20:
		return _fail("capture opinion")
	var pack: Dictionary = _view(game)
	var view: NetworkView = pack.view
	var host: Host = pack.host
	if not view._arm_join_pulses():
		return _fail("capture did not arm")
	var want := game.join_toast_line(sid, "taken", false)
	if host.toasts.size() != 1 or str(host.toasts[0]) != want or not want.ends_with("is yours."):
		return _fail("capture toast " + str(host.toasts))
	if not is_equal_approx(float(view._join_left.get(sid, -1)), 0.4) or view._join_dim.has(sid):
		return _fail("capture beat")
	var notes := game.notices.duplicate()
	view._tick_join_pulses(0.0)
	if game.notices != notes:
		return _fail("capture toast wrote a notice")
	## A rival taking a neutral station is not a player gain and not a player loss.
	var other := ""
	for nid in game.stations:
		if str(nid) == sid or str(nid) == str(game.capital_id):
			continue
		var row: Dictionary = game.stations[nid]
		if str(row.get("bunker", "")) != "" or str(row.owner) == "bunker":
			continue
		other = str(nid)
		break
	if other == "":
		return _fail("capture no other")
	var quiet: Dictionary = game.stations[other]
	quiet.owner = "neutral"
	quiet.low_weeks = 2
	quiet.erase("join_pulse")
	quiet.erase("join_pulse_kind")
	if not game._capture(other, "exchange", false):
		return _fail("neutral capture")
	if bool(quiet.get("join_pulse", false)):
		return _fail("neutral pulsed")
	print("Capture: ok")
	return true


func _check_lost(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("lost no neighbor")
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.low_weeks = 2
	st.erase("join_pulse")
	st.erase("join_pulse_kind")
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var stock0: Dictionary = game.stock.duplicate(true)
	if not game._capture(sid, "directorate", false):
		return _fail("lost capture")
	if str(st.get("join_pulse_kind", "")) != "lost" or str(st.owner) != "directorate":
		return _fail("lost kind")
	if int(game.hope) != hope0 or int(game.discontent) != dis0 or game.stock != stock0:
		return _fail("lost balance")
	var pack: Dictionary = _view(game)
	var view: NetworkView = pack.view
	var host: Host = pack.host
	if not view._arm_join_pulses():
		return _fail("lost did not arm")
	if not bool(view._join_dim.get(sid, false)):
		return _fail("lost not dim")
	if not is_equal_approx(float(view._join_left.get(sid, -1)), NetworkView.JOIN_PULSE_S):
		return _fail("lost duration")
	var want := game.join_toast_line(sid, "lost", false)
	if host.toasts.size() != 1 or str(host.toasts[0]) != want or not want.ends_with("fell."):
		return _fail("lost toast " + str(host.toasts))
	view._tick_join_pulses(0.4)
	if view._join_left.has(sid) or view._join_dim.has(sid):
		return _fail("lost chrome stayed")
	print("Lost: ok")
	return true


func _check_reduce(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("reduce no neighbor")
	var st: Dictionary = game.stations[sid]
	Settings.reduced()
	Settings.reduce_motion = true
	st["join_pulse"] = true
	st["join_pulse_kind"] = "join"
	var pack: Dictionary = _view(game)
	var view: NetworkView = pack.view
	var host: Host = pack.host
	if not view._motion_off():
		Settings.reduce_motion = false
		return _fail("reduce flag")
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var stock0: Dictionary = game.stock.duplicate(true)
	var notes := game.notices.duplicate()
	if not view._arm_join_pulses():
		Settings.reduce_motion = false
		return _fail("reduce did not toast")
	if view._join_left.has(sid) or view._join_dim.has(sid):
		Settings.reduce_motion = false
		return _fail("reduce moved")
	if host.toasts.size() != 1 or str(host.toasts[0]) != "Joined.":
		Settings.reduce_motion = false
		return _fail("reduce toast " + str(host.toasts))
	if int(game.hope) != hope0 or int(game.discontent) != dis0 or game.stock != stock0 or game.notices != notes:
		Settings.reduce_motion = false
		return _fail("reduce drift")
	Settings.reduce_motion = false
	if view._motion_off():
		return _fail("reduce stuck")
	st["join_pulse"] = true
	st["join_pulse_kind"] = "taken"
	host.toasts.clear()
	if not view._arm_join_pulses() or view._join_left.is_empty():
		return _fail("motion beat missing")
	if str(host.toasts[0]) != game.join_toast_line(sid, "taken", false):
		return _fail("motion toast")
	view._join_left.clear()
	view._join_dim.clear()
	host.shot_mode = true
	st["join_pulse"] = true
	st["join_pulse_kind"] = "lost"
	host.toasts.clear()
	if not view._motion_off() or not view._arm_join_pulses():
		return _fail("shot motion")
	if view._join_left.has(sid) or str(host.toasts[0]) != game.join_toast_line(sid, "lost", true):
		return _fail("shot toast " + str(host.toasts))
	if not str(host.toasts[0]).ends_with("fell."):
		return _fail("shot lost line")
	print("Reduce: ok")
	return true


func _check_once(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("once no neighbor")
	var st: Dictionary = game.stations[sid]
	var pack: Dictionary = _view(game)
	var view: NetworkView = pack.view
	var host: Host = pack.host
	host.dim = ColorRect.new()
	host.dim.visible = true
	st["join_pulse"] = true
	st["join_pulse_kind"] = "join"
	if view._arm_join_pulses() or not bool(st.get("join_pulse", false)):
		return _fail("dim consumed the beat")
	host.dim.visible = false
	if not view._arm_join_pulses() or bool(st.get("join_pulse", false)):
		return _fail("dim held the beat")
	var left := float(view._join_left.get(sid, -1))
	if view._arm_join_pulses() or not is_equal_approx(float(view._join_left.get(sid, -1)), left):
		return _fail("once restarted")
	if host.toasts.size() != 1:
		return _fail("once toasted twice")
	st["join_pulse"] = true
	st["join_pulse_kind"] = "taken"
	if not view._arm_join_pulses() or host.toasts.size() != 2:
		return _fail("new event silent")
	if NetworkView.JOIN_PULSE_S > 0.4:
		return _fail("duration")
	if bool(game.flags.get("seen_join_pulse", false)):
		return _fail("first float armed")
	print("Once: ok")
	return true


func _check_dawn(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("dawn no neighbor")
	var st: Dictionary = game.stations[sid]
	st["join_pulse"] = true
	st["join_pulse_kind"] = "join"
	var flags0: Dictionary = game.flags.duplicate(true)
	var chip0 := str(game.dawn_soft_chip().get("kind", ""))
	var home0 := game.home_chip_line(false)
	var pack: Dictionary = _view(game)
	var view: NetworkView = pack.view
	if not view._arm_join_pulses():
		return _fail("dawn arm")
	if game.flags != flags0:
		return _fail("dawn flags")
	if str(game.dawn_soft_chip().get("kind", "")) != chip0 or game.home_chip_line(false) != home0:
		return _fail("dawn chip")
	if bool(game.flags.get("rumor_dawn", false)) or bool(game.flags.get("border_dawn_new", false)):
		return _fail("dawn higher")
	if bool(game.flags.get("rail_dawn", false)) or bool(game.flags.get("home_pending", false)) or bool(game.flags.get("heard_home", false)):
		return _fail("dawn stack")
	var stack := game.dawn_soft_stack()
	if stack != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		return _fail("dawn order " + str(stack))
	for kind in stack:
		if str(kind).find("join") >= 0:
			return _fail("dawn slot " + str(kind))
	if game.party_away_dawn_chip() or game.sick_cots_dawn_chip():
		return _fail("sticky chrome became dawn")
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var dawn := _body(src, "func _pick_dawn_soft_chip(")
	if dawn.find("join") >= 0 or dawn.find("Join") >= 0:
		return _fail("dawn picker")
	var note := _body(src, "func _note_join_pulse(")
	if note.find("_add_hope") >= 0 or note.find("_add_discontent") >= 0 or note.find("_add_opinion") >= 0 or note.find("notices") >= 0:
		return _fail("note touches balance")
	if note.find("join_pulse_kind") < 0:
		return _fail("note missing kind")
	print("Dawn: ok")
	return true


func _check_chrome() -> bool:
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if src.find("const DEAL_PIP_R := 2.8") < 0:
		return _fail("deal pip")
	if src.find("const PRESSURE_ARC := TAU * 0.75") < 0 or src.find("const CLAIM_DASHES := 16") < 0:
		return _fail("pressure constants")
	var pressure := _body(src, "func pressure_ring_radius(")
	var claim := _body(src, "func claim_ring_radius(")
	if pressure.find("return pin_r + 4.0") < 0 or claim.find("return pin_r + 9.5") < 0:
		return _fail("ring radii")
	var pulse := _body(src, "func _draw_join_pulse(")
	if pulse.find("JOIN_PULSE_S") < 0 or pulse.find("_join_left") < 0:
		return _fail("pulse draw")
	if pulse.find("_anim_t") >= 0 or pulse.find("create_tween") >= 0:
		return _fail("pulse loops")
	for banned in ["_draw_pressure_ring", "_draw_deal_pips", "DealMarks", "LeafletDust", "NeedTick", "PinWarmth", "_draw_warmth_ring", "_draw_leaflet_chip", "_draw_need_tick"]:
		if pulse.find(banned) >= 0:
			return _fail("pulse reopens " + banned)
	var pin := _body(src, "func _draw_pin(")
	var warm := pin.find("_draw_warmth_ring")
	var leaf := pin.find("_draw_leaflet_chip")
	var need := pin.find("_draw_need_tick")
	var beat := pin.find("_draw_join_pulse")
	if warm < 0 or leaf < warm or need < leaf or beat < need:
		return _fail("pin order")
	if src.find("seen_join_pulse") >= 0:
		return _fail("first float shipped")
	var game_src := FileAccess.get_file_as_string("res://sim/game.gd")
	if game_src.find("seen_join_pulse") >= 0:
		return _fail("flag shipped")
	var cap := _body(game_src, "func _capture(")
	if cap.find("_note_join_pulse") < 0:
		return _fail("capture hook")
	print("Chrome: ok")
	return true


func _check_save(catalog: Catalog) -> bool:
	var game := _game(catalog)
	var sid := _neighbor(game)
	if sid == "":
		return _fail("save no neighbor")
	var st: Dictionary = game.stations[sid]
	st["join_pulse"] = true
	st["join_pulse_kind"] = "taken"
	var data := game.export_state()
	data["schema"] = Game.SAVE_SCHEMA
	var loaded := Game.new()
	loaded.setup(catalog, 4, 40)
	if not loaded.import_state(data):
		return _fail("save import " + loaded.load_error)
	var kept: Dictionary = loaded.stations[sid]
	if not bool(kept.get("join_pulse", false)) or str(kept.get("join_pulse_kind", "")) != "taken":
		return _fail("save dropped the beat")
	var pack: Dictionary = _view(loaded)
	var view: NetworkView = pack.view
	if not view._arm_join_pulses() or bool(kept.get("join_pulse", false)):
		return _fail("save arm")
	var again := loaded.export_state()
	again["schema"] = Game.SAVE_SCHEMA
	var next := Game.new()
	next.setup(catalog, 5, 40)
	if not next.import_state(again):
		return _fail("save reimport")
	if bool(next.stations[sid].get("join_pulse", false)):
		return _fail("save replayed")
	print("Save: ok")
	return true


func _check_balance() -> bool:
	var now := FileAccess.get_file_as_string("res://data/balance.json")
	if now != balance_text:
		return _fail("balance.json changed")
	if now.contains("join.pulse") or now.contains("join_pulse") or now.contains("seen_join_pulse"):
		return _fail("balance mentions join pulse")
	var parsed = JSON.parse_string(now)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("balance parse")
	if int(parsed.get("hope_drift", 0)) != -1 or float(parsed.get("sympathy_base", 0)) != 12.0:
		return _fail("balance drift")
	if int(parsed.get("join_hope", 1)) != 0 or int(parsed.get("join_discontent", 0)) != -3:
		return _fail("join band")
	if int(parsed.get("assault_hope", 0)) != -3 or int(parsed.get("assault_discontent", 0)) != 8:
		return _fail("assault band")
	print("Balance: ok")
	return true


func _body(src: String, name: String) -> String:
	var at := src.find(name)
	if at < 0:
		return ""
	var body := src.substr(at)
	var next := body.find("\nfunc ")
	if next >= 0:
		body = body.substr(0, next)
	return body
