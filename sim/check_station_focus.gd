extends SceneTree

## P52 gate: owned outposts set focus from the visit sheet; capital and foreign never do.
##   godot --headless --path . -s res://sim/check_station_focus.gd


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
		print("STATION FOCUS FAIL catalog")
		quit(1)
		return
	if not _check_strings():
		_failed = true
	if not _check_balance(catalog):
		_failed = true
	if not await _check_ui(catalog):
		_failed = true
	print("STATION FOCUS FAIL" if _failed else "STATION FOCUS OK")
	quit(1 if _failed else 0)


func _bad(msg: String) -> void:
	_failed = true
	print("Station focus: FAIL ", msg)


func _check_strings() -> bool:
	Copy.set_lang("en")
	if Copy.t("focus.current") != "Focus: {name}":
		_bad("current en " + Copy.t("focus.current"))
		return false
	if Copy.t("focus.food") != "Food" or Copy.t("focus.air") != "Air":
		_bad("food/air en")
		return false
	if Copy.t("focus.defense") != "Defense" or Copy.t("focus.influence") != "Influence":
		_bad("defense/influence en")
		return false
	if Copy.t("focus.tip") != "This outpost leans here.":
		_bad("tip en")
		return false
	if Copy.t("focus.first") != "Outposts can lean food, air, defense, or influence.":
		_bad("first en")
		return false
	if Copy.fill("focus.set", {"name": "Food"}) != "Focus set to Food.":
		_bad("set en")
		return false
	if Copy.fill("focus.current", {"name": "Air"}) != "Focus: Air":
		_bad("current fill en")
		return false
	Copy.set_lang("ru")
	if Copy.t("focus.food") != "Еда" or Copy.t("focus.air") != "Воздух":
		_bad("food/air ru")
		return false
	if Copy.t("focus.defense") != "Оборона" or Copy.t("focus.influence") != "Влияние":
		_bad("defense/influence ru")
		return false
	if Copy.t("focus.tip") != "Эта застава клонится сюда.":
		_bad("tip ru")
		return false
	if Copy.t("focus.first") != "Заставы могут клониться к еде, воздуху, обороне или влиянию.":
		_bad("first ru " + Copy.t("focus.first"))
		return false
	if Copy.fill("focus.current", {"name": "Еда"}) != "Уклон: Еда":
		_bad("current ru")
		return false
	if Copy.fill("focus.set", {"name": "Оборона"}) != "Уклон — Оборона.":
		_bad("set ru " + Copy.fill("focus.set", {"name": "Оборона"}))
		return false
	if Copy.t("Focus: {name}") != "Уклон: {name}":
		_bad("ru.json current")
		return false
	if Copy.t("Outposts can lean food, air, defense, or influence.") != "Заставы могут клониться к еде, воздуху, обороне или влиянию.":
		_bad("ru.json first")
		return false
	Copy.set_lang("en")
	print("Strings: ok")
	return true


func _check_balance(catalog: Catalog) -> bool:
	if Game.DAWN_SOFT_STACK != ["rumor", "border.dawn_new", "rail", "homecoming"]:
		_bad("dawn stack " + str(Game.DAWN_SOFT_STACK))
		return false
	var game := Game.new()
	game.setup(catalog, 4, 40)
	if game.station_focus_dawn_chip():
		_bad("focus joined the dawn stack")
		return false
	if int(game.bal.assault_hope) != -3 or int(game.bal.assault_discontent) != 8 or int(game.bal.unbidden_hope) != -2:
		_bad("assault numbers moved")
		return false
	if int(game.bal.join_hope) != 0 or int(game.bal.join_discontent) != -3:
		_bad("join numbers moved")
		return false
	var food: Dictionary = Formulas.outpost_flow(5, 2, "food")
	var air: Dictionary = Formulas.outpost_flow(5, 2, "air")
	var defense: Dictionary = Formulas.outpost_flow(5, 2, "defense")
	var influence: Dictionary = Formulas.outpost_flow(5, 2, "influence")
	if int(food.food) != 5 or int(food.materials) != 1 or int(food.tokens) != 0 or int(food.air) != 0:
		_bad("food flow " + str(food))
		return false
	if int(air.air) != 0 or int(air.food) != 3 or int(air.materials) != 1:
		_bad("air flow " + str(air))
		return false
	if int(defense.materials) != 3 or int(defense.food) != 3 or int(defense.tokens) != 0:
		_bad("defense flow " + str(defense))
		return false
	if int(influence.influence) != 4 or int(influence.food) != 3 or int(influence.materials) != 1:
		_bad("influence flow " + str(influence))
		return false
	var young: Dictionary = Formulas.outpost_flow(2, 1, "food")
	if int(young.upkeep_materials) != 1 or int(young.food) != 0:
		_bad("upkeep moved")
		return false
	var src := FileAccess.get_file_as_string("res://sim/formulas.gd")
	if not src.contains('const FOCUS_ADD := {"food": {"food": 2}, "defense": {"materials": 2}, "influence": {"influence": 6}, "air": {"air": 2}}'):
		_bad("FOCUS_ADD drifted")
		return false
	var ui := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if not ui.contains("game._order_focus(sid, focus)"):
		_bad("picker does not call _order_focus")
		return false
	print("Balance: ok")
	return true


func _neighbor(game: Game, skip: String = "") -> String:
	for sid in game.stations:
		if str(sid) == str(game.capital_id) or str(sid) == skip:
			continue
		var st: Dictionary = game.stations[str(sid)]
		if str(st.get("bunker", "")) != "" or str(st.owner) in ["bunker", "ruin"]:
			continue
		return str(sid)
	return ""


func _fresh(catalog: Catalog) -> Game:
	var game := Game.new()
	game.setup(catalog, 4, 40)
	game.week = 4
	return game


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


func _choice(root: Node, focus: String) -> Button:
	for node in _meta(root, "focus_choice"):
		if str(node.get_meta("focus_choice")) == focus:
			return node as Button
	return null


func _check_ui(catalog: Catalog) -> bool:
	var game := _fresh(catalog)
	var sid := _neighbor(game)
	var foreign := _neighbor(game, sid)
	if sid == "" or foreign == "":
		_bad("no outpost")
		return false
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.focus = "food"
	var other: Dictionary = game.stations[foreign]
	other.known = false
	if str(other.owner) == str(game.player):
		_bad("foreign is owned")
		return false
	var hope0 := int(game.hope)
	var dis0 := int(game.discontent)
	var orders0 := int(game.orders_left)
	var stock0 := {
		"food": int(game.stock.food),
		"air": int(game.stock.air),
		"materials": int(game.stock.materials),
		"tokens": int(game.stock.tokens),
		"influence": int(game.stock.influence),
	}
	var cap_focus := str(game.stations[game.capital_id].get("focus", ""))
	var foreign_focus := str(other.get("focus", ""))
	if game._order_focus(game.capital_id, "defense") or str(game.stations[game.capital_id].get("focus", "")) != cap_focus:
		_bad("capital accepted focus")
		return false
	if game._order_focus(foreign, "defense") or str(other.get("focus", "")) != foreign_focus:
		_bad("foreign accepted focus")
		return false
	if game._order_focus(sid, "loot"):
		_bad("invented focus id")
		return false
	if int(game.orders_left) != orders0 or int(game.hope) != hope0:
		_bad("rejected focus spent an order")
		return false
	var host := Host.new()
	host.game = game
	root.add_child(host)
	var view := NetworkView.new()
	view.size = Vector2(1280, 720)
	root.add_child(view)
	view.host = host
	Settings.reduced()
	Settings.reduce_motion = true
	view.open_sheet(sid)
	if _meta(view._sheet_body, "focus_choice").size() != 4:
		_bad("sheet picker " + str(_meta(view._sheet_body, "focus_choice").size()))
		return false
	if bool(game.flags.get("seen_station_focus", false)):
		_bad("sheet set the first-float flag")
		return false
	if view._focus_float != null and view._focus_float.visible:
		_bad("sheet showed the float")
		return false
	view.close_sheet()
	view.open_visit(game.capital_id)
	if not _meta(view.visit, "focus_choice").is_empty() or bool(game.flags.get("seen_station_focus", false)):
		_bad("capital visit taught focus")
		return false
	view.close_visit()
	view.open_visit(foreign)
	if not _meta(view.visit, "focus_choice").is_empty():
		_bad("foreign visit has a picker")
		return false
	view.close_visit()
	view.open_visit(sid)
	var choices := _meta(view.visit, "focus_choice")
	if choices.size() != 4:
		_bad("visit picker " + str(choices.size()))
		return false
	var want := ["food", "air", "defense", "influence"]
	var got: Array = []
	for node in choices:
		got.append(str(node.get_meta("focus_choice")))
	got.sort()
	var sorted_want := want.duplicate()
	sorted_want.sort()
	if got != sorted_want:
		_bad("choice ids " + str(got))
		return false
	var food_btn := _choice(view.visit, "food")
	var defense_btn := _choice(view.visit, "defense")
	if food_btn == null or not bool(food_btn.get_meta("focus_selected")) or bool(defense_btn.get_meta("focus_selected")):
		_bad("current food is not marked")
		return false
	var current := _meta(view.visit, "focus_current")
	if current.size() != 1 or str(current[0].text) != "Focus: Food":
		_bad("current label " + (str(current[0].text) if not current.is_empty() else "missing"))
		return false
	if not bool(game.flags.get("seen_station_focus", false)):
		_bad("first visit did not set the flag")
		return false
	if view._focus_float == null or not view._focus_float.visible or view._focus_float.text != Copy.t("focus.first"):
		_bad("first float")
		return false
	if not bool(view._focus_float.get_meta("focus_float_static", false)):
		_bad("float moved under reduce-motion")
		return false
	var y := view._focus_float.position.y
	var alpha := view._focus_float.modulate.a
	for _i in 3:
		await process_frame
	if not is_equal_approx(view._focus_float.position.y, y) or not is_equal_approx(view._focus_float.modulate.a, alpha):
		_bad("float was not static")
		return false
	var logs := game.log.size()
	food_btn.pressed.emit()
	if str(st.focus) != "food" or game.log.size() != logs or host.toasts.size() != 0:
		_bad("reselecting food wrote a new order")
		return false
	defense_btn = _choice(view.visit, "defense")
	defense_btn.pressed.emit()
	if str(st.focus) != "defense":
		_bad("pick did not set focus")
		return false
	if int(game.orders_left) != orders0 or int(game.hope) != hope0 or int(game.discontent) != dis0:
		_bad("pick spent hope or an order")
		return false
	for key in stock0:
		if int(game.stock[key]) != int(stock0[key]):
			_bad("pick moved " + key)
			return false
	if str(game.flags.get("dawn_soft_kind", "")) == "focus" or game.station_focus_dawn_chip():
		_bad("pick queued a dawn chip")
		return false
	if host.toasts.size() != 1 or host.toasts[0] != "Focus set to Defense.":
		_bad("toast " + str(host.toasts))
		return false
	var marked := _choice(view.visit, "defense")
	if marked == null or not bool(marked.get_meta("focus_selected")) or marked.scale != Vector2.ONE:
		_bad("defense not marked, or the button bounced")
		return false
	if view.find_children("*", "ConfirmationDialog", true, false).size() != 0:
		_bad("confirm modal")
		return false
	view.close_visit()
	view.open_visit(sid)
	if view._focus_float != null and view._focus_float.visible:
		_bad("second visit floated again")
		return false
	if not bool(game.flags.get("seen_station_focus", false)):
		_bad("flag dropped")
		return false
	Copy.set_lang("ru")
	view._fill_visit(sid)
	current = _meta(view.visit, "focus_current")
	if current.is_empty() or str(current[0].text) != "Уклон: Оборона":
		_bad("ru label " + (str(current[0].text) if not current.is_empty() else "missing"))
		Copy.set_lang("en")
		return false
	if _choice(view.visit, "air") == null or _choice(view.visit, "air").text != "Воздух":
		_bad("ru air")
		Copy.set_lang("en")
		return false
	Copy.set_lang("en")
	var snap := game.export_state()
	snap["schema"] = Game.SAVE_SCHEMA
	var loaded := _fresh(catalog)
	if not loaded.import_state(snap):
		_bad("save " + loaded.load_error)
		return false
	if not bool(loaded.flags.get("seen_station_focus", false)) or str(loaded.stations[sid].focus) != "defense":
		_bad("load lost focus or the flag")
		return false
	var left := int(game.orders_left)
	var hope1 := int(game.hope)
	if not game.apply({"kind": "order", "order": "focus", "station": sid, "focus": "air"}):
		_bad("bot focus order failed")
		return false
	if str(st.focus) != "air" or int(game.orders_left) != left - 1 or int(game.hope) != hope1:
		_bad("bot path drifted")
		return false
	if Game.DAWN_SOFT_STACK.has("focus") or game.station_focus_dawn_chip():
		_bad("dawn stack gained focus")
		return false
	print("Visit: ok")
	return true
