extends SceneTree

## P67 release polish. Visual only: order faces, the map pick ring, and event plates
## that already have a file named for the event.
##   godot --headless --path . -s res://sim/check_polish.gd

const OWN_ART := [
	"lamps", "clog", "smuggler", "rumble", "static", "desertion", "diesel",
	"refugees_next", "preacher_next", "toll_next", "toll_last", "knock_next", "loan_next",
	"market_food", "market_next",
]


class HostStub extends Node:
	var game


func _init() -> void:
	var failed := false
	var catalog := Catalog.new()
	if not catalog.load_all():
		print("Catalog: FAIL ", catalog.error)
		quit(1)
		return
	Copy.set_lang("en")
	if not _check_banners(catalog):
		failed = true
	if not _check_orders(catalog):
		failed = true
	if not _check_ring():
		failed = true
	if failed:
		print("POLISH FAIL")
		quit(1)
		return
	print("POLISH OK")
	quit(0)


func _check_banners(catalog: Catalog) -> bool:
	var bad: PackedStringArray = []
	for id in OWN_ART:
		var ev := _event(catalog, id)
		if ev.is_empty():
			bad.append(id + " missing")
			continue
		var plate := ArtPack.resolve_event_banner(ev)
		if plate != id:
			bad.append("%s shows %s" % [id, plate])
	var wire := _event(catalog, "wire")
	if ArtPack.resolve_event_banner(wire) != "dark":
		bad.append("wire lost its dark plate")
	var leak := _event(catalog, "leak")
	if ArtPack.resolve_event_banner(leak) != "flood":
		bad.append("leak lost its flood plate")
	if not bad.is_empty():
		print("Banners: FAIL ", ", ".join(bad))
		return false
	print("Banners: own art wins, mood aliases still cover events without a file")
	return true


func _event(catalog: Catalog, id: String) -> Dictionary:
	for ev in catalog.events:
		if str(ev.get("id", "")) == id:
			return ev
	return {}


func _check_orders(catalog: Catalog) -> bool:
	var game := Game.new()
	game.setup(catalog, 1, 40)
	game.stock.influence = 40
	var sid := ""
	for candidate in game.stations:
		if str(candidate) == str(game.capital_id):
			continue
		if game.borders_player(str(candidate)) and bool(game.stations[candidate].get("known", false)):
			sid = str(candidate)
			break
	if sid == "":
		print("Orders: FAIL no known neighbour")
		return false
	var view := NetworkView.new()
	var stub := HostStub.new()
	stub.game = game
	view.host = stub
	var parent := VBoxContainer.new()
	view._order_button("envoy", "Send envoy", sid, parent)
	view._order_button("approach", "Approach the Floor", sid, parent)
	var envoy: Button = null
	var approach: Button = null
	for child in parent.get_children():
		if child is Button and str(child.get_meta("order_kind", "")) == "envoy":
			envoy = child
		if child is Button and str(child.get_meta("order_kind", "")) == "approach":
			approach = child
	var bad: PackedStringArray = []
	if envoy == null or envoy.disabled:
		bad.append("envoy not lit")
	else:
		var normal: StyleBoxFlat = envoy.get_theme_stylebox("normal")
		var hover: StyleBoxFlat = envoy.get_theme_stylebox("hover")
		var pressed: StyleBoxFlat = envoy.get_theme_stylebox("pressed")
		if normal.bg_color.is_equal_approx(hover.bg_color) or hover.bg_color.is_equal_approx(pressed.bg_color):
			bad.append("envoy hover/press")
		if normal.get_content_margin(SIDE_LEFT) != hover.get_content_margin(SIDE_LEFT):
			bad.append("envoy margin bounce")
		if normal.get_content_margin(SIDE_TOP) != pressed.get_content_margin(SIDE_TOP):
			bad.append("envoy press margin")
		var ink: Color = envoy.get_meta("order_caption").get_theme_color("font_color")
		if not ink.is_equal_approx(view._order_ink(true)):
			bad.append("envoy ink")
	if approach == null or not approach.disabled:
		bad.append("approach not locked")
	else:
		var locked: StyleBoxFlat = approach.get_theme_stylebox("disabled")
		var open: StyleBoxFlat = envoy.get_theme_stylebox("normal") if envoy != null else null
		if open != null and locked.bg_color.is_equal_approx(open.bg_color):
			bad.append("approach face")
		var dim: Color = approach.get_meta("order_caption").get_theme_color("font_color")
		if not dim.is_equal_approx(view._order_ink(false)):
			bad.append("approach ink")
		if approach.mouse_default_cursor_shape != Control.CURSOR_ARROW:
			bad.append("approach cursor")
	if not bad.is_empty():
		print("Orders: FAIL ", ", ".join(bad))
		return false
	print("Orders: hover, press, and a dim locked face")
	return true


func _check_ring() -> bool:
	var view := NetworkView.new()
	var pin := 18.0
	var radius := view.pick_ring_radius(pin)
	var outer := radius + view.pick_ring_width(true) * 0.5
	var bad: PackedStringArray = []
	if radius <= view.pressure_ring_radius(pin) + 1.5:
		bad.append("inside pressure")
	if outer >= view.claim_ring_radius(pin) - 0.4:
		bad.append("hits claim")
	if view.pick_ring_width(true) <= view.pick_ring_width(false):
		bad.append("selected width")
	if view.pick_ring_color(true).a <= view.pick_ring_color(false).a:
		bad.append("selected alpha")
	if view.pick_ring_color(true).r < 0.7:
		bad.append("not brass")
	if not bad.is_empty():
		print("Ring: FAIL ", ", ".join(bad))
		return false
	print("Ring: brass pick sits between pressure and claim")
	return true
