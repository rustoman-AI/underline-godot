extends SceneTree

## P78 Relay Posts.
##   godot --headless --path . -s res://sim/check_relay_posts.gd

const KEYS := [
	"relay.name", "relay.mark", "relay.clear", "relay.tip",
	"relay.first", "relay.lost", "relay.status", "relay.status_none",
]
const ART := {
	"res://assets/icons/map/relay_mark.png": "0ee96e0c433d65a809507c9e2225ee5b",
	"res://assets/icons/map/relay_mark_24.png": "acda36638afcba587358830a475de2f8",
}

var failed := false


func _init() -> void:
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("RELAY FAIL catalog " + catalog.error)
		quit(1)
		return
	_strings()
	_relay(catalog)
	_map(catalog)
	_dawn()
	_art()
	if failed:
		print("RELAY FAIL")
		quit(1)
		return
	print("strings ok")
	print("relay ok")
	print("map ok")
	print("dawn ok")
	print("art ok")
	var lost := _careful(catalog)
	var pct := 100.0 * float(lost) / 60.0
	print("Careful loss: %d/60 (%.1f%%)" % [lost, pct])
	if lost != 2:
		_bad("careful loss %d/60 moved off the preserved 2/60 band" % lost)
	if lost < 9 or lost > 21:
		print("NOTE spec names 15-35 percent of 60. Measured %d/60 (%.1f percent)." % [lost, pct])
	if failed:
		print("RELAY FAIL")
		quit(1)
	else:
		print("RELAY OK")
		quit(0)


func _bad(msg: String) -> void:
	failed = true
	print("FAIL " + msg)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		_bad(msg)


func _strings() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/relay_posts.json"))
	if not (pack is Dictionary) or str(pack.get("_roadmap", "")) != "P78" or not (pack.get("by_key", {}) is Dictionary):
		_bad("relay_posts.json")
		return
	var rows: Dictionary = pack.by_key
	if rows.size() != 8:
		_bad("key count %d" % rows.size())
	Copy.set_lang("en")
	for key in KEYS:
		var want := str(rows.get(key, {}).get("en", ""))
		if Copy.t(key) != want or want == "":
			_bad("EN %s got %s" % [key, Copy.t(key)])
		if "Реле" in str(rows[key].get("ru", "")):
			_bad("RU used Реле in %s" % key)
	Copy.set_lang("ru")
	for key in KEYS:
		var want := str(rows.get(key, {}).get("ru", ""))
		if Copy.t(key) != want or want == "":
			_bad("RU %s got %s" % [key, Copy.t(key)])
	if Copy.t("relay.name") != "Узел":
		_bad("relay name is not Узел")
	Copy.set_lang("en")
	var ru: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ru.json"))
	if ru is Dictionary:
		for key in KEYS:
			var row: Dictionary = rows[key]
			var en := str(row.get("en", ""))
			if str(ru.get(en, "")) != str(row.get("ru", "")):
				_bad("ru.json %s" % en)


func _game(catalog: Catalog, run_seed: int = 3) -> Game:
	var game := Game.new()
	game.setup(catalog, run_seed, 40)
	return game


func _own(game: Game, sid: String) -> void:
	var st: Dictionary = game.stations[sid]
	st.owner = game.player
	st.known = true
	st.hidden = false
	st.held_weeks = 6
	if str(st.get("focus", "")) == "":
		st.focus = "food"


func _relay(catalog: Catalog) -> void:
	var game := _game(catalog)
	game.orders_left = 8
	var capital := str(game.capital_id)
	_expect(not bool(game.can_mark_relay(capital).ok), "capital can be marked")
	_expect(str(game.can_mark_relay(capital).reason) == "capital", "capital reason")
	var owned: Array[String] = []
	var bridge := ""
	for sid in game.stations:
		var id := str(sid)
		var st: Dictionary = game.stations[id]
		if str(st.get("owner", "")) == "ruin" and bridge == "":
			bridge = id
		if id == capital:
			continue
		if str(st.get("owner", "")) in ["bunker", "ruin"] or bool(st.get("hidden", false)) or str(st.get("bunker", "")) != "":
			_expect(not bool(game.can_mark_relay(id).ok), "ineligible %s can be marked" % id)
			continue
		_own(game, id)
		owned.append(id)
	if owned.size() < 2 or bridge == "":
		_bad("not enough stations")
		return
	var relay := ""
	var far := ""
	var far_h := -1
	for id in owned:
		var hops := game._supply_hops_direct(id)
		if relay == "" and hops >= 1 and hops < 900:
			relay = id
		if hops > far_h and hops < 900:
			far_h = hops
			far = id
	if relay == far:
		for id in owned:
			if id != far and game._supply_hops_direct(id) < 900:
				relay = id
				break
	_expect(game.order_block("relay_mark", relay) == "", "mark blocked: " + game.order_block("relay_mark", relay))
	var left := game.orders_left
	_expect(game.apply({"kind": "order", "order": "relay_mark", "station": relay}), "mark did not apply")
	_expect(game.relay_sid == relay, "mark did not set relay")
	_expect(game.orders_left == left - 1, "mark did not spend an order")
	_expect(bool(game.flags.get("seen_relay_posts", false)) and game.relay_float_pending, "first float was not armed")
	game.relay_float_pending = false
	var other := ""
	for id in owned:
		if id != relay:
			other = id
			break
	_expect(game.apply({"kind": "order", "order": "relay_mark", "station": other}), "second mark failed")
	_expect(game.relay_sid == other, "second mark did not clear the first")
	_expect(not game.relay_float_pending, "float armed twice")
	_expect(game.apply({"kind": "order", "order": "relay_clear", "station": other}), "clear failed")
	_expect(game.relay_sid == "", "clear left a relay")
	_expect(not game.apply({"kind": "order", "order": "relay_mark", "station": capital}), "capital mark applied")
	_expect(game.apply({"kind": "order", "order": "relay_mark", "station": relay}), "remark failed")
	var direct_far := game._supply_hops_direct(far)
	var direct_relay := game._supply_hops_direct(relay)
	_link(game, capital, bridge)
	_link(game, bridge, far)
	var graph := game._hops(far, capital)
	_expect(graph < direct_far and graph < 900, "shortcut did not beat supply hops %d vs %d" % [graph, direct_far])
	_expect(game._supply_hops(far) == mini(game._hops(far, capital), game._hops(far, relay) + game._hops(relay, capital)), "bent hops are not the shorter path")
	_expect(game._supply_hops(far) < direct_far, "relay path was not shorter")
	_expect(game._supply_hops(relay) == direct_relay, "relay took a self bonus %d vs %d" % [game._supply_hops(relay), direct_relay])
	if not Game.RELAY_GRANT:
		_bad("grant const drifted")
	var saved := game.relay_sid
	game.relay_sid = ""
	_expect(game._supply_hops(far) == direct_far, "empty relay changed hops")
	game.relay_sid = saved
	var before := game.notices.size()
	game.stations[relay].owner = "neutral"
	game._settle_relay()
	_expect(game.relay_sid == "", "lost relay stayed marked")
	var toast := ""
	if game.notices.size() > before:
		toast = str(game.notices[game.notices.size() - 1])
	_expect(toast == Copy.t("relay.lost"), "lost toast " + toast)
	var snap := game.export_state()
	snap.schema = Game.SAVE_SCHEMA
	snap.relay_sid = other
	var loaded := Game.new()
	loaded.catalog = catalog
	_expect(loaded.import_state(snap) and loaded.relay_sid == other, "schema 15 dropped relay: " + loaded.load_error)
	snap.schema = 14
	snap.erase("relay_sid")
	var legacy := Game.new()
	legacy.catalog = catalog
	_expect(legacy.import_state(snap) and legacy.relay_sid == "", "schema 14 migration: " + legacy.load_error)
	var bot := Bot.new()
	bot.profile = "expander"
	var fresh := _game(catalog, 4)
	for id in owned:
		if fresh.stations.has(id):
			_own(fresh, id)
	_link(fresh, str(fresh.capital_id), bridge if fresh.stations.has(bridge) else "")
	if fresh.stations.has(bridge) and fresh.stations.has(far):
		_link(fresh, bridge, far)
		fresh.relay_sid = ""
		var order: Dictionary = bot.relay_mark_order(fresh)
		_expect(str(order.get("order", "")) == "relay_mark", "expander did not offer a relay")
		_expect(bool(fresh.can_mark_relay(str(order.get("station", ""))).ok), "expander mark is ineligible")
	var src := FileAccess.get_file_as_string("res://sim/bot.gd")
	var act := src.substr(src.find("func _act("), src.find("func _appoint_governors") - src.find("func _act("))
	_expect(act.find("relay_mark") < 0, "careful play() marks a relay")
	var flow := FileAccess.get_file_as_string("res://sim/formulas.gd")
	_expect(flow.find('const FOCUS_ADD := {"food": {"food": 2}, "defense": {"materials": 2}, "influence": {"influence": 6}, "air": {"air": 2}}') >= 0, "outpost_flow table changed")


func _link(game: Game, a: String, b: String) -> void:
	if a == "" or b == "" or a == b or not game._edge(a, b).is_empty():
		return
	game.tunnels.append({
		"id": "relay_test_%s_%s" % [a, b],
		"a": a, "b": b, "line": "",
		"state": "open", "sealed": false, "dug": true, "flooded": false, "closed_until": 0,
	})


func _map(_catalog: Catalog) -> void:
	var net_script: Script = load("res://ui/network_view.gd")
	var view: Node = net_script.new()
	root.add_child(view)
	view.size = Vector2(1280, 720)
	if view.has_method("_zoom_range"):
		view._zoom_range()
	var zmax := float(view.get("_zoom_max"))
	if zmax <= 0.0:
		zmax = 1.0
	var radius: float = view.pin_radius_at(zmax, true)
	var overlaps: bool = view.relay_overlaps_focus(radius)
	print("map pin r %.2f at zoom %.3f overlap %s" % [radius, zmax, overlaps])
	_expect(not overlaps, "relay mark overlaps the focus pip at max pin radius")
	var relay_at: Vector2 = view.relay_mark_offset(radius)
	var half := float(view.RELAY_DISC) * 0.5
	var goods := Vector2(radius * 0.62, radius * 0.55)
	var deal := Vector2(0.0, radius + 8.0)
	var leaflet := Vector2(radius * 0.95, radius * 0.72)
	var focus: Vector2 = view.focus_pip_offset(radius)
	print("map gaps goods %.1f focus %.1f deal %.1f leaf %.1f" % [
		relay_at.distance_to(goods), relay_at.distance_to(focus), relay_at.distance_to(deal), relay_at.distance_to(leaflet),
	])
	_expect(relay_at.distance_to(goods) >= 8.0 + half, "relay steals the goods pip")
	_expect(relay_at.distance_to(deal) >= 2.8 + half, "relay steals the deal row")
	_expect(relay_at.distance_to(leaflet) >= 8.0 + half, "relay steals the leaflet")
	_expect(relay_at.distance_to(focus) >= 7.0 + half, "relay steals the focus letter")
	var src := FileAccess.get_file_as_string("res://ui/network_view.gd")
	var draw := src.substr(src.find("func _draw_relay_mark"), src.find("func _add_relay_row") - src.find("func _draw_relay_mark"))
	_expect(draw.find("relay_stroke") < 0 and draw.find("dashed") < 0, "supply stroke was drawn")
	_expect(draw.find("\"R\"") >= 0, "letter R fallback missing")
	_expect(draw.find("relay_mark") >= 0, "art plate is not consulted")
	_expect(src.find("RELAY_OFFSET := Vector2(0.30, -0.12)") >= 0, "slot drifted")
	view.queue_free()


func _dawn() -> void:
	_expect(Game.DAWN_SOFT_STACK == ["rumor", "border.dawn_new", "rail", "homecoming"], "dawn stack changed")
	var src := FileAccess.get_file_as_string("res://sim/game.gd")
	var at := src.find("func _pick_dawn_soft_chip")
	var body := src.substr(at, src.find("func dawn_soft_chip", at) - at)
	_expect(body.find("relay") < 0, "relay joined the soft dawn picker")
	_expect(src.find("const DAWN_SOFT_STACK := [\"rumor\", \"border.dawn_new\", \"rail\", \"homecoming\"]") >= 0, "stack literal drifted")


func _art() -> void:
	for path in ART:
		var abs := ProjectSettings.globalize_path(path)
		var got := FileAccess.get_md5(abs)
		if got != str(ART[path]):
			_bad("md5 %s %s" % [path, got])
		var tex := ArtPack.load_texture(path)
		if tex == null or tex.get_width() < 1:
			_bad("texture %s" % path)
	var tiny: Texture2D = ArtPack.icon_texture("relay_mark", 24.0)
	_expect(tiny != null and tiny.get_width() > 0, "relay_mark_24 did not load")


func _careful(catalog: Catalog) -> int:
	var lost := 0
	for run_seed in range(1, 61):
		var row: Dictionary = Bot.new().play(40, run_seed, "careful", catalog)
		if str(row.get("over", "")) != "time":
			lost += 1
			print("  careful %d/60 lost %s week %s" % [run_seed, row.get("over", ""), row.get("week", "")])
	return lost
