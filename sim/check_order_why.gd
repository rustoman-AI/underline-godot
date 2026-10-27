extends SceneTree

## P65 Order Why. Disabled covered orders name one first blocker. Enabled tips stay.
##   godot --headless --path . -s res://sim/check_order_why.gd

const STACK := ["rumor", "border.dawn_new", "rail", "homecoming"]
const EN := {
	"why.workers": "Need free hands.",
	"why.materials": "Not enough materials.",
	"why.orders": "No orders left this week.",
	"why.blocked": "Blocked right now.",
	"why.trade_opinion": "Exchange will not trade yet.",
	"why.trade_on": "Trade already running.",
	"why.power": "Not enough power.",
	"why.food": "Not enough food.",
	"why.party_away": "The party is still out.",
	"why.already": "Already done.",
}
const RU := {
	"why.workers": "Нужны свободные руки.",
	"why.materials": "Не хватает материалов.",
	"why.orders": "На этой неделе приказов больше нет.",
	"why.blocked": "Сейчас заблокировано.",
	"why.trade_opinion": "Биржа пока не станет торговать.",
	"why.trade_on": "Торговля уже идёт.",
	"why.power": "Не хватает энергии.",
	"why.food": "Не хватает еды.",
	"why.party_away": "Отряд ещё вне.",
	"why.already": "Уже сделано.",
}

var failed := false
var catalog: Catalog


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var balance := FileAccess.get_file_as_string("res://data/balance.json")
	Copy.set_lang("en")
	catalog = Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	_strings()
	_priority()
	_dig()
	_build()
	_clear()
	_rally()
	_trade()
	_move()
	_expedition()
	_approach()
	_influence_gap()
	_uncovered()
	_enabled_tip()
	_dawn_and_motion()
	_geometry()
	_yard_card()
	if FileAccess.get_file_as_string("res://data/balance.json") != balance:
		_bad("Balance: balance.json changed")
	else:
		print("Balance: ok")
	if failed:
		print("ORDER WHY FAIL")
		quit(1)
		return
	print("ORDER WHY OK")
	quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL ", msg)


func _ok(msg: String) -> void:
	print(msg, ": ok")


func _game() -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	return game


func _ctx(level: int, cell: int, type: String = "", sid: String = "") -> Dictionary:
	return {"level": level, "cell": cell, "type": type, "sid": sid}


func _beside(game: Game, want: bool) -> Vector2i:
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if bool(spot.get("dug", false)):
				continue
			if game._beside_dug(spot) == want:
				return Vector2i(level, cell)
	return Vector2i(-1, -1)


func _floor(game: Game) -> Vector2i:
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if game._cell_buildable(spot):
				return Vector2i(level, cell)
	return Vector2i(-1, -1)


func _floors(game: Game) -> Array:
	var out: Array = []
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if game._cell_buildable(spot):
				out.append(Vector2i(level, cell))
	return out


func _dug(game: Game) -> Vector2i:
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if bool(spot.get("dug", false)) and str(spot.get("room", "")) == "" and str(spot.get("pile", "")) == "":
				return Vector2i(level, cell)
	return Vector2i(-1, -1)


func _lock_hands(game: Game) -> void:
	for person in game.residents:
		person.sick = 2


func _busy_council(game: Game) -> void:
	for seat in game.council:
		game.seat_used[str(seat.get("role", ""))] = "held"


func _drop_soldiers(game: Game) -> void:
	for person in game.residents:
		person.soldier = false


func _foreign(game: Game) -> String:
	for n in game._neighbors(str(game.capital_id)):
		var sid := str(n)
		if game.stations.has(sid) and str(game.stations[sid].get("owner", "")) != str(game.player):
			return sid
	return ""


func _deal_sid(game: Game) -> String:
	for n in game._neighbors(str(game.capital_id)):
		var sid := str(n)
		if not game.stations.has(sid) or not game.borders_player(sid):
			continue
		var st: Dictionary = game.stations[sid]
		var owner := str(st.get("owner", ""))
		if owner == str(game.player) or owner == "bunker" or owner == "ruin" or owner == "enemy":
			continue
		if bool(st.get("hidden", false)) or str(st.get("bunker", "")) != "":
			continue
		return sid
	return ""


func _strings() -> void:
	if EN.size() != 10 or RU.size() != 10:
		_bad("Strings: expected 10 keys")
		return
	Copy.set_lang("en")
	for key in EN:
		if Copy.t(str(key)) != str(EN[key]):
			_bad("Strings en %s -> %s" % [key, Copy.t(str(key))])
			return
	Copy.set_lang("ru")
	for key in RU:
		if Copy.t(str(key)) != str(RU[key]):
			_bad("Strings ru %s -> %s" % [key, Copy.t(str(key))])
			return
	Copy.set_lang("en")
	if Copy.keys.has("why.influence") or Copy.keys.has("why.approach"):
		_bad("Strings: invented why.influence or why.approach")
		return
	if Copy.t("why.influence") != "why.influence":
		_bad("Strings: why.influence resolved")
		return
	_ok("Strings")


func _priority() -> void:
	var rows := [
		[{"workers": true, "materials": true}, "why.workers"],
		[{"materials": true, "orders": true}, "why.materials"],
		[{"orders": true, "blocked": true}, "why.orders"],
		[{"blocked": true, "trade_opinion": true}, "why.blocked"],
		[{"trade_opinion": true, "trade_on": true}, "why.trade_opinion"],
		[{"trade_on": true, "power": true}, "why.trade_on"],
		[{"power": true, "food": true}, "why.power"],
		[{"food": true, "party_away": true}, "why.food"],
		[{"party_away": true, "already": true}, "why.party_away"],
		[{"already": true, "approach": true}, "why.already"],
		[{"approach": true}, "approach.need"],
		[{}, ""],
	]
	for row in rows:
		var got := OrderWhy.first_key(row[0])
		if got != str(row[1]):
			_bad("Priority %s -> %s want %s" % [row[0], got, row[1]])
			return
	if OrderWhy.first_key({"workers": true, "orders": true}) != "why.workers":
		_bad("Priority workers beat orders")
		return
	_ok("Priority")


func _dig() -> void:
	var game := _game()
	var open := _beside(game, true)
	var rock := _beside(game, false)
	var dug := _dug(game)
	if open.x < 0 or rock.x < 0 or dug.x < 0:
		_bad("Dig: missing cells")
		return
	var ready := OrderWhy.tip(game, "dig", _ctx(open.x, open.y))
	var preview: Dictionary = game.dig_preview(open.x, open.y)
	if ready != "" or not bool(preview.ok):
		_bad("Dig enabled tip %s ok %s" % [ready, preview.ok])
		return
	game.stock.materials = 0
	var mats := OrderWhy.tip(game, "dig", _ctx(open.x, open.y))
	var long_mats := str(game.dig_preview(open.x, open.y).reason)
	if mats != Copy.t("why.materials") or long_mats == mats or long_mats.find("Needs") < 0:
		_bad("Dig mats tip %s formula %s" % [mats, long_mats])
		return
	_lock_hands(game)
	var both := OrderWhy.tip(game, "dig", _ctx(open.x, open.y))
	var long_both := str(game.dig_preview(open.x, open.y).reason)
	if both != Copy.t("why.workers") or long_both.find("Needs") < 0:
		_bad("Dig workers+mats %s formula %s" % [both, long_both])
		return
	var rock_tip := OrderWhy.tip(game, "dig", _ctx(rock.x, rock.y))
	var rock_why := str(game.dig_preview(rock.x, rock.y).reason)
	if rock_tip != Copy.t("why.blocked") or rock_why != Copy.t("Solid rock. Dig from a cell that touches an open one."):
		_bad("Dig rock %s formula %s" % [rock_tip, rock_why])
		return
	var done := OrderWhy.tip(game, "dig", _ctx(dug.x, dug.y))
	if done != Copy.t("why.already") or str(game.dig_preview(dug.x, dug.y).reason) != Copy.t("Already open."):
		_bad("Dig already %s" % done)
		return
	var fresh := _game()
	var spot := _beside(fresh, true)
	fresh.dig = {"level": spot.x, "cell": spot.y, "left": 2, "workers": []}
	if OrderWhy.tip(fresh, "dig", _ctx(spot.x, spot.y)) != Copy.t("why.workers"):
		_bad("Dig busy crew")
		return
	_ok("Dig")


func _build() -> void:
	var game := _game()
	var floor := _floor(game)
	if floor.x < 0:
		_bad("Build: no floor")
		return
	var type := "workshop"
	if OrderWhy.tip(game, "build", _ctx(floor.x, floor.y, type)) != "" or not bool(game.build_preview(type, floor.x, floor.y).ok):
		_bad("Build enabled changed")
		return
	game.stock.materials = 0
	var mats := OrderWhy.tip(game, "build", _ctx(floor.x, floor.y, type))
	var long_mats := str(game.build_preview(type, floor.x, floor.y).reason)
	if mats != Copy.t("why.materials") or long_mats.find("Needs") < 0:
		_bad("Build mats %s formula %s" % [mats, long_mats])
		return
	_lock_hands(game)
	if OrderWhy.tip(game, "build", _ctx(floor.x, floor.y, type)) != Copy.t("why.workers"):
		_bad("Build workers beat mats")
		return
	var piled := _game()
	var cell := _floor(piled)
	piled.cells["%d:%d" % [cell.x, cell.y]]["pile"] = "rubble"
	var blocked := OrderWhy.tip(piled, "build", _ctx(cell.x, cell.y, type))
	if blocked != Copy.t("why.blocked") or str(piled.build_preview(type, cell.x, cell.y).reason) != Copy.t("clear.blocked_build"):
		_bad("Build pile %s" % blocked)
		return
	var radio := _game()
	var open := _floor(radio)
	radio.stock.materials = 40
	var listen := OrderWhy.tip(radio, "build", _ctx(open.x, open.y, "listening_post"))
	var listen_why := str(radio.build_preview("listening_post", open.x, open.y).reason)
	if listen != Copy.t("why.blocked") or listen_why == "":
		_bad("Build radio %s formula %s" % [listen, listen_why])
		return
	var cap := _game()
	var slots: Array = _floors(cap)
	if slots.size() < 2:
		_bad("Build: need two floors")
		return
	var hall: Vector2i = slots[0]
	var site: Vector2i = slots[1]
	cap._place_room("radio", hall.x, hall.y)
	var uid := str(cap.cells["%d:%d" % [hall.x, hall.y]].get("room", ""))
	cap._room(uid).staff.append("listener")
	cap.rooms.append({
		"uid": "cap_listen", "type": "listening_post", "offline": false, "staff": [],
		"level": -1, "cell": -1,
	})
	cap.stock.materials = 40
	var already := OrderWhy.tip(cap, "build", _ctx(site.x, site.y, "listening_post"))
	if already != Copy.t("why.already") or bool(cap.build_preview("listening_post", site.x, site.y).ok):
		_bad("Build cap %s" % already)
		return
	_ok("Build")


func _clear() -> void:
	var game := _game()
	var cell := _floor(game)
	if cell.x < 0:
		_bad("Clear: no floor")
		return
	game.cells["%d:%d" % [cell.x, cell.y]]["pile"] = "scrap"
	game.stock.materials = 0
	var mats := OrderWhy.tip(game, "clear", _ctx(cell.x, cell.y))
	var long_mats := str(game.clear_preview(cell.x, cell.y).reason)
	if mats != Copy.t("why.materials") or long_mats.find("Needs") < 0:
		_bad("Clear mats %s formula %s" % [mats, long_mats])
		return
	var busy := _game()
	var spot := _floor(busy)
	busy.cells["%d:%d" % [spot.x, spot.y]]["pile"] = "rubble"
	busy.dig = {"left": 1, "workers": []}
	var crew := OrderWhy.tip(busy, "clear", _ctx(spot.x, spot.y))
	if crew != Copy.t("why.workers") or str(busy.clear_preview(spot.x, spot.y).reason) != Copy.t("clear.dig_busy"):
		_bad("Clear dig busy %s" % crew)
		return
	var bare_game := _game()
	var bare := _floor(bare_game)
	if OrderWhy.tip(bare_game, "clear", _ctx(bare.x, bare.y)) != Copy.t("why.already"):
		_bad("Clear already")
		return
	_ok("Clear")


func _rally() -> void:
	var game := _game()
	var blocked := OrderWhy.tip(game, "rally", {})
	if blocked != Copy.t("why.blocked") or game.rally_reason() != Copy.t("Needs a meeting hall."):
		_bad("Rally hall %s formula %s" % [blocked, game.rally_reason()])
		return
	var floor := _floor(game)
	game._place_room("meeting_hall", floor.x, floor.y)
	if OrderWhy.tip(game, "rally", {}) != Copy.t("why.workers"):
		_bad("Rally unstaffed")
		return
	var uid := str(game.cells["%d:%d" % [floor.x, floor.y]].get("room", ""))
	var room = game._room(uid)
	room.staff.append(str(game.residents[0].get("id", "p")))
	room.offline = true
	if OrderWhy.tip(game, "rally", {}) != Copy.t("why.blocked"):
		_bad("Rally offline")
		return
	room.offline = false
	game.rally_lock = 2
	var held := OrderWhy.tip(game, "rally", {})
	if held != Copy.t("why.already") or str(game.rally_reason()).find("rally") < 0:
		_bad("Rally lock %s formula %s" % [held, game.rally_reason()])
		return
	game.rally_lock = 0
	if OrderWhy.tip(game, "rally", {}) != "" or game.rally_reason() != "":
		_bad("Rally enabled changed")
		return
	_ok("Rally")


func _trade() -> void:
	var game := _game()
	game.orders_left = 1
	game.stock.influence = 8
	game.trade_on = false
	game.opinions["exchange"] = -4
	var cold := OrderWhy.tip(game, "trade", {"sid": ""})
	var cold_live := game.order_block("trade", "")
	if cold != Copy.t("why.trade_opinion") or cold_live != Copy.t("The Exchange will not deal with you."):
		_bad("Trade opinion %s formula %s" % [cold, cold_live])
		return
	game.trade_on = true
	if OrderWhy.tip(game, "trade", {"sid": ""}) != Copy.t("why.trade_opinion"):
		_bad("Trade opinion beats trade_on")
		return
	game.opinions["exchange"] = 4
	var running := OrderWhy.tip(game, "trade", {"sid": ""})
	if running != Copy.t("why.trade_on") or game.order_block("trade", "") != Copy.t("Trade with the Exchange is already open."):
		_bad("Trade on %s" % running)
		return
	game.trade_on = false
	game.orders_left = 0
	_busy_council(game)
	if OrderWhy.tip(game, "trade", {"sid": ""}) != Copy.t("why.workers"):
		_bad("Trade workers beat orders")
		return
	if game.order_block("trade", "") != Copy.t("No council order left this week."):
		_bad("Trade formula still names orders first")
		return
	var alone := _game()
	alone.orders_left = 0
	alone.opinions["exchange"] = 4
	alone.trade_on = false
	alone.stock.influence = 8
	if OrderWhy.tip(alone, "trade", {"sid": ""}) != Copy.t("why.orders"):
		_bad("Trade orders alone")
		return
	var sid := _deal_sid(game)
	if sid == "":
		_bad("Trade: no neighbor")
		return
	var deal := _game()
	deal.orders_left = 1
	deal.stock.influence = 8
	deal.stations[sid]["deals"] = 3
	var done := OrderWhy.tip(deal, "trade", {"sid": sid})
	if done != Copy.t("why.already") or deal.order_block("trade", sid) != Copy.t("Three deals are already in force."):
		_bad("Deal already %s formula %s" % [done, deal.order_block("trade", sid)])
		return
	_ok("Trade")


func _move() -> void:
	var game := _game()
	var sid := _foreign(game)
	if sid == "":
		_bad("Move: no neighbor")
		return
	game.orders_left = 1
	game.stock.food = 0
	var food := OrderWhy.tip(game, "move", {"sid": sid})
	if food != Copy.t("why.food") or game.order_block("move", sid) != Copy.t("Not enough food for the march."):
		_bad("Move food %s formula %s" % [food, game.order_block("move", sid)])
		return
	_drop_soldiers(game)
	if OrderWhy.tip(game, "move", {"sid": sid}) != Copy.t("why.workers"):
		_bad("Move soldiers beat food")
		return
	var away := _game()
	away.orders_left = 1
	away.stock.food = 20
	away.squads[away.player]["away"] = true
	var party := OrderWhy.tip(away, "move", {"sid": sid})
	if party != Copy.t("why.party_away") or away.order_block("move", sid) != Copy.t("The squad is away."):
		_bad("Move away %s formula %s" % [party, away.order_block("move", sid)])
		return
	if OrderWhy.tip(away, "move", {"sid": "no-such-station"}) != Copy.t("why.blocked"):
		_bad("Move no tunnel")
		return
	_ok("Move")


func _expedition() -> void:
	var game := _game()
	game.orders_left = 1
	var tunnel: Dictionary = game._tunnel_by_id("to_ferry")
	if tunnel.is_empty():
		_bad("Expedition: no ferry tunnel")
		return
	tunnel["dug"] = true
	var open := OrderWhy.tip(game, "expedition", {})
	if open != Copy.t("why.already") or game.order_block("expedition") != Copy.t("South Ferry is already open."):
		_bad("Expedition open %s formula %s" % [open, game.order_block("expedition")])
		return
	tunnel["dug"] = false
	game.squads[game.player]["away"] = true
	var party := OrderWhy.tip(game, "expedition", {})
	if party != Copy.t("why.party_away") or game.order_block("expedition") != Copy.t("The squad must be home first."):
		_bad("Expedition away %s" % party)
		return
	game.squads[game.player]["away"] = false
	_drop_soldiers(game)
	var hands := OrderWhy.tip(game, "expedition", {})
	if hands != Copy.t("why.workers") or str(game.order_block("expedition")).find("soldiers") < 0:
		_bad("Expedition soldiers %s formula %s" % [hands, game.order_block("expedition")])
		return
	var ready := _game()
	ready.orders_left = 1
	if OrderWhy.tip(ready, "expedition", {}) != "" or ready.order_block("expedition") != "":
		_bad("Expedition enabled changed %s" % ready.order_block("expedition"))
		return
	_ok("Expedition")


func _approach() -> void:
	var game := _game()
	game.orders_left = 1
	game.artifacts["papers"] = 0
	var live := game.order_block("approach", "")
	if OrderWhy.tip(game, "approach", {}) != "":
		_bad("Approach invented a why without approach.need")
		return
	if live != Copy.t("Needs Papers and the Floor tunnel"):
		_bad("Approach formula %s" % live)
		return
	var view := NetworkView.new()
	if view._order_tip(game, "approach", "", live) != live:
		_bad("Approach tooltip replaced the live line")
		return
	game.orders_left = 0
	if OrderWhy.tip(game, "approach", {}) != Copy.t("why.orders"):
		_bad("Approach orders beat the floor need")
		return
	Copy.keys["approach.need"] = {"en": "Need papers and the Floor tunnel.", "ru": "Нужны бумаги и тоннель Этажа."}
	game.orders_left = 1
	var cited := OrderWhy.tip(game, "approach", {})
	Copy.keys.erase("approach.need")
	if cited != "Need papers and the Floor tunnel.":
		_bad("Approach cite %s" % cited)
		return
	if Copy.keys.has("why.approach"):
		_bad("Approach duplicated why.approach")
		return
	var other := _game()
	other.orders_left = 1
	var q := other.order_block("approach_quarantine", "")
	if view._order_tip(other, "approach_quarantine", "", q) != q:
		_bad("Quarantine tip changed")
		return
	_ok("Approach")


func _influence_gap() -> void:
	var game := _game()
	game.orders_left = 1
	game.trade_on = false
	game.opinions["exchange"] = 6
	game.stock.influence = 0
	game.stock.materials = 40
	if OrderWhy.tip(game, "trade", {"sid": ""}) != "":
		_bad("Influence was remapped")
		return
	var live := game.order_block("trade", "")
	if not live.begins_with(Copy.t("Not enough influence.")):
		_bad("Influence formula %s" % live)
		return
	var view := NetworkView.new()
	var tip := view._order_tip(game, "trade", "", live)
	if not tip.begins_with(Copy.t("Not enough influence: need")) or tip == Copy.t("why.materials"):
		_bad("Influence live tip %s" % tip)
		return
	var sid := _foreign(game)
	if sid != "" and OrderWhy.tip(game, "trade", {"sid": sid}) == Copy.t("why.materials"):
		_bad("Deal influence became materials")
		return
	_ok("Influence")


func _uncovered() -> void:
	var game := _game()
	game.orders_left = 0
	var view := NetworkView.new()
	var sid := _foreign(game)
	var why := game.order_block("raid", sid)
	var tip := view._order_tip(game, "raid", sid, why)
	if tip != why or tip == Copy.t("why.orders"):
		_bad("Raid tip changed %s" % tip)
		return
	var gift := game.order_block("gift", sid)
	if view._order_tip(game, "gift", sid, gift) != gift and not gift.begins_with(Copy.t("Not enough influence.")):
		_bad("Gift tip changed")
		return
	_ok("Uncovered")


func _enabled_tip() -> void:
	var game := _game()
	game.orders_left = 1
	game.stock.food = 20
	var sid := _foreign(game)
	var view := NetworkView.new()
	if game.order_block("move", sid) != "":
		_bad("Move should be enabled for the unchanged tip")
		return
	var tip := view._order_tip(game, "move", sid, "")
	var who: Dictionary = game.order_councillor()
	var want := "%s: %s\n%s: %s\n%s: %s" % [
		Copy.t("Cost"), view._cost_text(game.order_cost("move", sid)),
		Copy.t("Goes"), Copy.person(str(who.get("name", ""))),
		Copy.t("Result"), Copy.t("Next dawn"),
	]
	var risk := game.order_risk("move", sid)
	if risk != "":
		want += "\n%s: %s" % [Copy.t("Risk"), risk]
	if tip != want or tip.find(Copy.t("why.food")) >= 0:
		_bad("Enabled move tip changed")
		return
	game.stock.food = 0
	var blocked := view._order_tip(game, "move", sid, game.order_block("move", sid))
	if blocked != Copy.t("why.food"):
		_bad("Disabled move tip %s" % blocked)
		return
	_ok("Enabled tip")


func _dawn_and_motion() -> void:
	var game := _game()
	if Game.DAWN_SOFT_STACK != STACK or game.dawn_soft_stack() != STACK:
		_bad("Soft dawn stack changed")
		return
	if game.order_why_dawn_chip():
		_bad("Order why joined the soft dawn stack")
		return
	var src := FileAccess.get_file_as_string("res://sim/order_why.gd")
	var low := src.to_lower()
	if low.find("create_tween") >= 0 or low.find("dawn_soft") >= 0 or src.find("balance.json") >= 0:
		_bad("Order why script tweens, joins dawn, or touches balance")
		return
	Settings.reduce_motion = true
	var still := OrderWhy.tip(game, "rally", {})
	Settings.reduce_motion = false
	if still != OrderWhy.tip(game, "rally", {}) or still == "":
		_bad("Reduce-motion changed the tip")
		return
	_ok("Dawn and motion")


func _geometry() -> void:
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	if src.find("icon_texture(_order_icon(kind), 24.0)") < 0:
		_bad("Order icon size changed")
		return
	if src.find("Vector2(24, 24)") < 0:
		_bad("Order icon rect changed")
		return
	if src.find("76 if why != \"\" and APPROACHES.has(kind) else 40") < 0:
		_bad("Order button height changed")
		return
	_ok("Geometry")


func _labels(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	if node is Button:
		out.append((node as Button).text)
		if (node as Button).tooltip_text != "":
			out.append((node as Button).tooltip_text)
	for child in node.get_children():
		_labels(child, out)


func _has_line(node: Node, want: String) -> bool:
	var lines := PackedStringArray()
	_labels(node, lines)
	return lines.has(want)


func _yard_card() -> void:
	Settings.intro_seen = true
	Settings.resume = false
	Settings.howto_hidden = true
	var st = load("res://ui/station.tscn").instantiate()
	root.add_child(st)
	st.shot_mode = true
	st._close_card()
	var game = st.game
	var open := _beside(game, true)
	if open.x < 0:
		_bad("Yard: no dig cell")
		st.queue_free()
		return
	game.stock.materials = 0
	st._tap_cell(open.x, open.y)
	if not _has_line(st.card_body, Copy.t("why.materials")):
		_bad("Yard dig card missed why.materials")
		st.queue_free()
		return
	var long := str(game.dig_preview(open.x, open.y).reason)
	if _has_line(st.card_body, long):
		_bad("Yard dig card still shows the long formula")
		st.queue_free()
		return
	st._close_card()
	game.stock.materials = 40
	st._tap_cell(open.x, open.y)
	if _has_line(st.card_body, Copy.t("why.materials")) or _has_line(st.card_body, Copy.t("why.workers")):
		_bad("Enabled dig card gained a why tip")
		st.queue_free()
		return
	st._close_card()
	var floor := _floor(game)
	game.stock.materials = 0
	st._confirm_build("workshop", floor.x, floor.y)
	if not _has_line(st.card_body, Copy.t("why.materials")):
		_bad("Yard build card missed why.materials")
		st.queue_free()
		return
	var build_long := str(game.build_preview("workshop", floor.x, floor.y).reason)
	if _has_line(st.card_body, build_long):
		_bad("Yard build card still shows the long formula")
		st.queue_free()
		return
	st.queue_free()
	_ok("Yard card")
