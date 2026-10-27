extends SceneTree

## P60 gate: the visit relation block shows raw Game.synod. First float once. Not a dawn chip.
##   godot --headless --path . -s res://sim/check_synod_score.gd


const EN := {
	"synod.label": "Synod",
	"synod.tip": "Chapel favor. Flushing listens at 10.",
	"synod.first": "The chapel is counting.",
	"synod.value": "{n}",
}
const RU := {
	"synod.label": "Синод",
	"synod.tip": "Милость часовни. Flushing слышит с 10.",
	"synod.first": "Часовня считает.",
	"synod.value": "{n}",
}


class Host extends Node:
	var game
	var shot_mode := false
	var motion_in_shots := false
	var net_guide := false
	var net_guide_sid := ""
	var toasts := PackedStringArray()

	func _toast(line: String) -> void:
		toasts.append(line)

	func _ui_click() -> void:
		pass


var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Copy.set_lang("en")
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("SYNOD SCORE FAIL catalog")
		quit(1)
		return
	if not _check_strings():
		_failed = true
	if not _check_balance(catalog):
		_failed = true
	if not _check_sim(catalog):
		_failed = true
	if not await _check_ui(catalog):
		_failed = true
	print("SYNOD SCORE FAIL" if _failed else "SYNOD SCORE OK")
	quit(1 if _failed else 0)


func _bad(msg: String) -> void:
	_failed = true
	print("Synod score: FAIL ", msg)


func _check_strings() -> bool:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/synod_score.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P60":
		_bad("synod_score.json")
		return false
	var rows = pack.get("by_key", {})
	if not (rows is Dictionary):
		_bad("by_key")
		return false
	var keys: Array = rows.keys()
	keys.sort()
	var want: Array = EN.keys()
	want.sort()
	if keys != want:
		_bad("key set " + str(keys))
		return false
	Copy.set_lang("en")
	for key in EN:
		if str(rows[key].get("en", "")) != str(EN[key]) or Copy.t(str(key)) != str(EN[key]):
			_bad("EN " + str(key) + " " + Copy.t(str(key)))
			return false
	Copy.set_lang("ru")
	for key in RU:
		if str(rows[key].get("ru", "")) != str(RU[key]) or Copy.t(str(key)) != str(RU[key]):
			_bad("RU " + str(key) + " " + Copy.t(str(key)))
			return false
	Copy.set_lang("en")
	if Copy.fill("synod.value", {"n": 0}) != "0":
		_bad("value 0")
		return false
	if Copy.fill("synod.value", {"n": 10}) != "10" or Copy.fill("synod.value", {"n": 250}) != "250":
		_bad("value raw")
		return false
	if Copy.fill("synod.value", {"n": -17}) != "-17":
		_bad("value negative")
		return false
	print("Strings: ok")
	return true


func _check_balance(catalog: Catalog) -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var dilemmas: Dictionary = catalog.balance.get("dilemmas", {})
	var chain: Dictionary = catalog.balance.get("chain_scale", {})
	if int(dilemmas.get("flushing_synod", -1)) != 10 or int(dilemmas.get("open_synod", -1)) != 8:
		_bad("dilemma synod moved")
		return false
	if int(chain.get("synod_small", -1)) != 3:
		_bad("synod_small moved")
		return false
	if int(catalog.balance.get("gift_opinion", 0)) != 12 or int(catalog.balance.get("assault_hope", 0)) != -3:
		_bad("opinion or assault numbers moved")
		return false
	if int(catalog.balance.get("join_hope", 1)) != 0 or int(catalog.balance.get("join_discontent", 0)) != -3:
		_bad("join numbers moved")
		return false
	var text := FileAccess.get_file_as_string("res://data/balance.json")
	if text.contains("seen_synod_score") or text.contains("synod.label") or text.contains("synod.tip"):
		_bad("balance.json gained synod score copy")
		return false
	var game := Game.new()
	game.setup(catalog, 4, 40)
	if game.synod_score_dawn_chip() or game.station_focus_dawn_chip():
		_bad("synod joined the dawn stack")
		return false
	print("Balance: ok")
	return true


func _check_sim(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var synod := int(game.synod)
	var exchange := int(game.opinions.get("exchange", 0))
	game._add_opinion("synod", 5, "p60")
	if int(game.synod) != synod or int(game.opinions.get("exchange", 0)) != exchange:
		_bad("_add_opinion wrote synod")
		return false
	game._add_opinion("exchange", 2, "p60")
	if int(game.opinions.get("exchange", 0)) != exchange + 2 or int(game.synod) != synod:
		_bad("exchange opinion path drifted")
		return false
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var add := _body(src, "func _add_opinion(")
	if add.find('fid == "synod"') < 0:
		_bad("_add_opinion no longer skips synod")
		return false
	if src.find("synod += int(choice.synod)") < 0 or src.find('synod += int(defin.get("synod", 0))') < 0:
		_bad("synod writers removed")
		return false
	var pick := _body(src, "func _pick_dawn_soft_chip(")
	if pick.find("synod") >= 0:
		_bad("dawn picker knows synod")
		return false
	var ui := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var visit := _body(ui, "func _fill_visit(")
	var sheet := _body(ui, "func _fill_sheet_body(")
	if visit.find("_synod_line") < 0 or visit.find("_note_synod_score") < 0:
		_bad("visit does not show the meter")
		return false
	if sheet.find("_synod_line") >= 0 or sheet.find("_note_synod_score") >= 0:
		_bad("compact sheet grew a synod strip")
		return false
	var line := _body(ui, "func _synod_line(")
	if line.find('Copy.t("synod.label")') < 0 or line.find('Copy.t("synod.tip")') < 0 or line.find('Copy.fill("synod.value"') < 0:
		_bad("meter does not use synod strings")
		return false
	if line.find("clampf") >= 0 or line.find("ProgressBar") >= 0 or line.find("create_tween") >= 0 or line.find("Button") >= 0:
		_bad("meter clamps, bars, tweens, or spends")
		return false
	var note := _body(ui, "func _note_synod_score(")
	if note.find("seen_synod_score") < 0 or note.find('Copy.t("synod.first")') < 0:
		_bad("first float missing")
		return false
	if note.find("present_dawn_soft_chip") >= 0 or note.find("guide_layer") >= 0 or note.find("ModalDeck") >= 0:
		_bad("float joined dawn or a modal")
		return false
	var shown := _body(ui, "func _show_synod_float(")
	if shown.find("_motion_off()") < 0 or shown.find("tween_interval") < 0:
		_bad("reduce-motion float")
		return false
	if _body(ui, "func _band_key(").find("sympathy >= 100") < 0 or _body(ui, "func _band_key(").find("sympathy >= 20") < 0:
		_bad("relation bands moved")
		return false
	print("Sim: ok")
	return true


func _body(src: String, header: String) -> String:
	var at := src.find(header)
	if at < 0:
		return ""
	var rest := src.substr(at)
	var nxt := rest.find("\nfunc ")
	if nxt < 0:
		return rest
	return rest.substr(0, nxt)


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


func _sid(game: Game, owner: String) -> String:
	for key in game.stations:
		if str(game.stations[key].get("owner", "")) == owner:
			return str(key)
	return ""


func _gone(node: Node) -> bool:
	var here: Node = node
	while here != null:
		if here.is_queued_for_deletion():
			return true
		here = here.get_parent()
	return false


func _meta(node: Node, key: String) -> Array:
	var found: Array = []
	if node == null:
		return found
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if _gone(here):
			continue
		if here.has_meta(key):
			found.append(here)
		for child in here.get_children():
			stack.append(child)
	return found


func _one(node: Node, key: String) -> Node:
	var found := _meta(node, key)
	if found.is_empty():
		return null
	return found[0]


func _under(node: Node, key: String) -> bool:
	var here: Node = node
	while here != null:
		if here.has_meta(key):
			return true
		here = here.get_parent()
	return false


func _label_starts(node: Node, prefix: String) -> Label:
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if _gone(here):
			continue
		if here is Label and str((here as Label).text).begins_with(prefix):
			return here as Label
		for child in here.get_children():
			stack.append(child)
	return null


func _has_class(node: Node, kind: String) -> bool:
	var stack: Array = [node]
	while not stack.is_empty():
		var here: Node = stack.pop_back()
		if _gone(here):
			continue
		if here.is_class(kind):
			return true
		for child in here.get_children():
			stack.append(child)
	return false


func _read_meter(view: NetworkView) -> Dictionary:
	var chip := _one(view.visit, "synod_line")
	var label := _one(view.visit, "synod_label")
	var value := _one(view.visit, "synod_value")
	return {"chip": chip, "label": label, "value": value}


func _meter_ok(view: NetworkView, game: Game, sid: String, n: int) -> String:
	var meter := _read_meter(view)
	var chip: Control = meter.chip
	var label: Label = meter.label
	var value: Label = meter.value
	if chip == null or label == null or value == null:
		return "missing meter"
	if not chip.is_visible_in_tree():
		return "meter hidden"
	if _under(chip, "station_details"):
		return "meter folded into details"
	if int(chip.get_meta("synod_raw")) != n or str(value.text) != str(n):
		return "value %s raw %s want %d" % [value.text, str(chip.get_meta("synod_raw")), n]
	if str(value.text) != Copy.fill("synod.value", {"n": n}):
		return "value format " + str(value.text)
	if str(label.text) != Copy.t("synod.label"):
		return "label " + str(label.text)
	if str(chip.tooltip_text) != Copy.t("synod.tip"):
		return "tip " + str(chip.tooltip_text)
	if _has_class(chip, "Button") or _has_class(chip, "ProgressBar"):
		return "spend or bar"
	var face := chip.get_theme_stylebox("panel") as StyleBoxFlat
	if face == null or not is_equal_approx(face.border_color.a, 0.9) or face.get_border_width(SIDE_LEFT) != 1:
		return "brass outline"
	var bar := _one(view.visit, "opinion_bar") as ProgressBar
	if bar == null or not bar.is_visible_in_tree():
		return "opinion bar missing"
	var loyalty := _label_starts(view.visit, Copy.t("Loyalty"))
	if loyalty == null or not _under(loyalty, "station_details"):
		return "loyalty moved"
	if str(view._visit_sid) != sid:
		return "visit sid"
	var st: Dictionary = game.stations[sid]
	var owner := str(st.get("owner", ""))
	var relation := int(st.get("sympathy", 0))
	var low := 0.0
	if game.opinions.has(owner):
		relation = int(game.opinions[owner])
		low = -100.0
	if int(bar.get_meta("opinion_bar")) != relation or not is_equal_approx(bar.min_value, low) or not is_equal_approx(bar.max_value, 100.0):
		return "opinion row changed"
	if int(game.synod) != n:
		return "sim synod drifted"
	return ""


func _float_up(view: NetworkView) -> bool:
	return view._synod_float != null and view._synod_float.visible


func _check_ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var owners := {
		"exchange": _sid(game, "exchange"),
		"directorate": _sid(game, "directorate"),
		"neutral": _sid(game, "neutral"),
		"bunker": _sid(game, "bunker"),
		"ruin": _sid(game, "ruin"),
		"capital": str(game.capital_id),
	}
	for key in owners:
		if str(owners[key]) == "":
			_bad("no station " + str(key))
			return false
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.host = host
	view.size = Vector2(1280, 720)
	view.custom_minimum_size = Vector2(1280, 720)
	root.add_child(view)
	if view._band_key(100) != "map.relation_band_join" or view._band_key(70) != "map.relation_band_ready":
		_bad("band join/ready")
		return false
	if view._band_key(50) != "map.relation_band_warm" or view._band_key(20) != "map.relation_band_wary" or view._band_key(19) != "map.relation_band_cold":
		_bad("band warm/wary/cold")
		return false
	Settings.reduced()
	Settings.reduce_motion = true
	game.synod = 10
	view.open_sheet(str(owners.exchange))
	await process_frame
	if not _meta(view._sheet_body, "synod_line").is_empty():
		_bad("sheet shows synod")
		return false
	if _one(view._sheet_body, "opinion_bar") == null:
		_bad("sheet lost opinion")
		return false
	if bool(game.flags.get("seen_synod_score", false)) or _float_up(view):
		_bad("sheet taught the float")
		return false
	view.close_sheet()
	game.synod = 0
	for key in owners:
		view.open_visit(str(owners[key]))
		await process_frame
		var err := _meter_ok(view, game, str(owners[key]), 0)
		if err != "":
			_bad(str(key) + " " + err)
			return false
		if bool(game.flags.get("seen_synod_score", false)) or _float_up(view):
			_bad(str(key) + " floated at zero")
			return false
	var hope := int(game.hope)
	var dis := int(game.discontent)
	var orders := int(game.orders_left)
	var opinions: Dictionary = game.opinions.duplicate(true)
	var stock := {
		"food": int(game.stock.food),
		"air": int(game.stock.air),
		"materials": int(game.stock.materials),
		"tokens": int(game.stock.tokens),
		"influence": int(game.stock.influence),
	}
	var flags_before: Dictionary = game.flags.duplicate(true)
	view.open_visit(str(owners.directorate))
	await process_frame
	if bool(game.flags.get("seen_synod_score", false)) or _float_up(view):
		_bad("zero directorate floated")
		return false
	game.synod = 10
	view._fill_visit(str(owners.directorate))
	await process_frame
	var err10 := _meter_ok(view, game, str(owners.directorate), 10)
	if err10 != "":
		_bad("first " + err10)
		return false
	if not bool(game.flags.get("seen_synod_score", false)):
		_bad("flag unset")
		return false
	if not _float_up(view) or view._synod_float.text != Copy.t("synod.first"):
		_bad("first float")
		return false
	if view._synod_float.text.find("+") >= 0:
		_bad("delta toast")
		return false
	if not bool(view._synod_float.get_meta("synod_float_static", false)):
		_bad("float moved under reduce-motion")
		return false
	var y := view._synod_float.position.y
	var alpha := view._synod_float.modulate.a
	var chip_y := (_one(view.visit, "synod_line") as Control).position.y
	for _i in 3:
		await process_frame
	if not is_equal_approx(view._synod_float.position.y, y) or not is_equal_approx(view._synod_float.modulate.a, alpha):
		_bad("float was not static")
		return false
	if not is_equal_approx((_one(view.visit, "synod_line") as Control).position.y, chip_y):
		_bad("meter was not static")
		return false
	if int(game.hope) != hope or int(game.discontent) != dis or int(game.orders_left) != orders:
		_bad("visit spent hope or an order")
		return false
	for key in stock:
		if int(game.stock[key]) != int(stock[key]):
			_bad("visit moved " + str(key))
			return false
	if game.opinions.duplicate(true) != opinions:
		_bad("visit moved opinion")
		return false
	var flags_after: Dictionary = game.flags.duplicate(true)
	flags_after.erase("seen_synod_score")
	if flags_before != flags_after:
		_bad("flags changed " + str(flags_after))
		return false
	if str(game.dawn_soft_chip().get("kind", "")) == "synod" or game.synod_score_dawn_chip():
		_bad("dawn chip")
		return false
	if host.toasts.size() != 0:
		_bad("toast " + str(host.toasts))
		return false
	await _save_shot(view)
	view.close_visit()
	if _float_up(view):
		_bad("float stayed after close")
		return false
	game.synod = 250
	view.open_visit(str(owners.exchange))
	await process_frame
	var err250 := _meter_ok(view, game, str(owners.exchange), 250)
	if err250 != "":
		_bad("uncapped " + err250)
		return false
	if _float_up(view):
		_bad("later +N floated")
		return false
	view.close_visit()
	game.synod = -17
	view.open_visit(str(owners.capital))
	await process_frame
	var err_neg := _meter_ok(view, game, str(owners.capital), -17)
	if err_neg != "":
		_bad("negative " + err_neg)
		return false
	if _float_up(view):
		_bad("negative delta floated")
		return false
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	var loaded := _fresh(catalog)
	if not loaded.import_state(snap):
		_bad("save " + loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_synod_score", false)) or int(loaded.synod) != -17:
		_bad("load lost the flag or the score")
		return false
	host.game = loaded
	view.open_visit(str(owners.neutral))
	await process_frame
	var err_load := _meter_ok(view, loaded, str(owners.neutral), -17)
	if err_load != "":
		_bad("loaded " + err_load)
		return false
	if _float_up(view):
		_bad("float after load")
		return false
	Copy.set_lang("ru")
	view._fill_visit(str(owners.neutral))
	await process_frame
	var ru_meter := _read_meter(view)
	if ru_meter.label == null or str(ru_meter.label.text) != "Синод" or str(ru_meter.chip.tooltip_text) != RU["synod.tip"]:
		_bad("ru meter")
		Copy.set_lang("en")
		return false
	if str(ru_meter.value.text) != "-17":
		_bad("ru value " + str(ru_meter.value.text))
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var again := _fresh(catalog)
	again.synod = 0
	host.game = again
	Settings.reduce_motion = false
	view.open_visit(str(owners.bunker))
	await process_frame
	if bool(again.flags.get("seen_synod_score", false)) or _float_up(view):
		_bad("second run floated at zero")
		return false
	again.synod = -40
	view._fill_visit(str(owners.bunker))
	await process_frame
	var err_live := _meter_ok(view, again, str(owners.bunker), -40)
	if err_live != "":
		_bad("live " + err_live)
		return false
	if not _float_up(view) or view._synod_float.text != "The chapel is counting.":
		_bad("live float")
		return false
	if bool(view._synod_float.get_meta("synod_float_static", true)):
		_bad("motion float marked static")
		return false
	view.close_visit()
	again.synod = -39
	view.open_visit(str(owners.ruin))
	await process_frame
	if _float_up(view) or str((_one(view.visit, "synod_value") as Label).text) != "-39":
		_bad("second live float")
		return false
	print("Visit: ok")
	return true


func _save_shot(view: NetworkView) -> void:
	await process_frame
	var img := view.get_viewport().get_texture().get_image()
	if img == null:
		print("Shot: skip")
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	var path := "/opt/cursor/artifacts/synod_score_after.png"
	img.save_png(path)
	print("Shot: ", path)
