extends Control

## P74 night panel. One panel, opened from the station HUD (visible on the yard and on the Network).

const PAPER := Color("2a241c")
const EDGE := Color("e0a84a")
const INK := Color("f4efe4")
const MUTED := Color("b7aa96")
const GOLD := Color("e0a84a")
const ROW := Color("3a3126")
const ROW_ON := Color("4a3c28")
const ROW_OFF := Color("2c2824")
const PRIORITY_KEYS := {
	"food": "run.priority_food",
	"materials": "run.priority_mats",
	"medkits": "run.priority_medkits",
	"intel": "run.priority_intel",
}

var host: Node = null
var site_id := ""
var picked: Array = []
var priority: Array = ["food", "materials", "medkits", "intel"]


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 300


func open_for(station: Node) -> void:
	host = station
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild()


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func showing() -> bool:
	return visible


func reveal_pack() -> void:
	var pack := find_child("Pack", true, false) as CanvasItem
	if pack == null:
		return
	var box := pack.get_parent()
	var seen := false
	for child in box.get_children():
		if child == pack:
			seen = true
		if child is CanvasItem:
			(child as CanvasItem).visible = seen


func scroll_to_pack() -> void:
	var scroll := find_child("Scroll", true, false) as ScrollContainer
	var pack := find_child("Pack", true, false) as Control
	if scroll == null or pack == null:
		print("PACK SCROLL missing")
		return
	var y := 0.0
	var node: Node = pack
	while node != null and node != scroll:
		if node is Control:
			y += (node as Control).position.y
		node = node.get_parent()
	scroll.scroll_vertical = maxi(0, int(y) - 8)
	scroll.ensure_control_visible(pack)


func _game():
	if host == null:
		return null
	return host.get("game")


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	var game = _game()
	if game == null:
		return
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.04, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var card := PanelContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -360
	card.offset_right = 360
	card.offset_top = -300
	card.offset_bottom = 300
	card.add_theme_stylebox_override("panel", _plate(PAPER, EDGE, 2))
	dim.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(680, 520)
	scroll.clip_contents = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	# Margin wraps the box so the scroll child stays the vbox. Rebuild: put margin inside scroll.
	scroll.remove_child(box)
	margin.add_child(box)
	scroll.add_child(margin)
	var title := _lab(Copy.t("run.panel_title"), 22, GOLD)
	box.add_child(title)
	box.add_child(_lab(Copy.t("run.pick_site"), 15, MUTED))
	var known: Array = NightRuns.known_sites(game)
	if known.is_empty():
		box.add_child(_lab(Copy.t("run.no_site"), 16, INK))
		site_id = ""
	else:
		var still := false
		for row in known:
			if str(row.get("id", "")) == site_id:
				still = true
		if not still:
			site_id = str(known[0].get("id", ""))
		for row in known:
			var id := str(row.get("id", ""))
			var on := id == site_id
			var btn := _row(NightRuns.site_label(game, row), on, true)
			btn.pressed.connect(_pick_site.bind(id))
			box.add_child(btn)
			if on and NightRuns.depleted(game, id):
				box.add_child(_lab(Copy.t("run.depleted"), 14, Color("c48a7a")))
	var cap := NightRuns.runner_cap(game)
	box.add_child(_lab(Copy.fill("run.pick_runners", {"n": cap}), 15, MUTED))
	if picked.size() > cap:
		picked.resize(cap)
	var keep: Array = []
	for id in picked:
		if NightRuns.block_reason(game, str(id)) == "":
			keep.append(str(id))
	picked = keep
	var bench: Array = []
	var party_rows: Array = []
	for person in game.residents:
		var pid := str(person.get("id", ""))
		var why := NightRuns.block_reason(game, pid)
		if why == "child" or why == "away" or why == "locked":
			continue
		if why == "party":
			party_rows.append(person)
		else:
			bench.append(person)
	bench.sort_custom(func(a, b):
		var ap := picked.has(str(a.get("id", "")))
		var bp := picked.has(str(b.get("id", "")))
		if ap == bp:
			return str(a.get("name", "")) < str(b.get("name", ""))
		return ap
	)
	var placed_party := false
	for person in bench:
		var pid := str(person.get("id", ""))
		var name := str(person.get("name", pid))
		var on := picked.has(pid)
		if not on and not placed_party:
			_add_party_rows(box, party_rows)
			placed_party = true
		var mark := "✓ %s" % name if on else name
		var btn := _row(mark, on, true)
		btn.pressed.connect(_toggle_runner.bind(pid))
		box.add_child(btn)
	if not placed_party:
		_add_party_rows(box, party_rows)
	_add_pack(box, game, site_id)


func _add_pack(box: VBoxContainer, game, current_site: String) -> void:
	var pack_lab := _lab(Copy.fill("run.backpack", {"n": NightRuns.PACK_UNITS}), 16, INK)
	pack_lab.name = "Pack"
	box.add_child(pack_lab)
	var rank := 1
	for kind in priority:
		var key := str(PRIORITY_KEYS.get(kind, "run.priority_food"))
		var label := "#%d %s" % [rank, Copy.t(key)]
		var on := rank == 1
		var btn := _row(label, on, true)
		btn.pressed.connect(_raise_priority.bind(kind))
		box.add_child(btn)
		rank += 1
	var ready := current_site != "" and not picked.is_empty()
	var send := _row(Copy.t("run.send"), ready, ready)
	send.disabled = not ready
	send.pressed.connect(_send)
	box.add_child(send)
	var cancel := _row(Copy.t("Close"), false, true)
	cancel.pressed.connect(close_panel)
	box.add_child(cancel)


func _add_party_rows(box: VBoxContainer, party_rows: Array) -> void:
	for person in party_rows:
		var pid := str(person.get("id", ""))
		var name := str(person.get("name", pid))
		var blocked := _row("%s — %s" % [name, Copy.t("run.party_block")], false, false)
		blocked.disabled = true
		blocked.tooltip_text = Copy.t("run.party_block")
		box.add_child(blocked)


func _pick_site(id: String) -> void:
	site_id = id
	_rebuild()


func _toggle_runner(pid: String) -> void:
	var game = _game()
	if game == null:
		return
	if picked.has(pid):
		picked.erase(pid)
	elif picked.size() < NightRuns.runner_cap(game) and NightRuns.block_reason(game, pid) == "":
		picked.append(pid)
	_rebuild()


func _raise_priority(kind: String) -> void:
	var next: Array = [kind]
	for other in priority:
		if str(other) != kind:
			next.append(other)
	priority = next
	_rebuild()


func _send() -> void:
	var game = _game()
	if game == null or host == null:
		return
	var err := NightRuns.send(game, site_id, picked, priority)
	if err != "":
		if host.has_method("_toast"):
			host._toast(err)
		return
	picked = []
	close_panel()
	if host.has_method("_toast"):
		host._toast("run.back")
	if host.has_method("_refresh"):
		host._refresh()


func _row(text: String, on: bool, enabled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(620, 40)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK if enabled else MUTED)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var fill := ROW_ON if on else (ROW if enabled else ROW_OFF)
	var edge := EDGE if on else Color("6a5a40")
	button.add_theme_stylebox_override("normal", _plate(fill, edge, 1))
	button.add_theme_stylebox_override("hover", _plate(fill.lightened(0.08), edge, 1))
	button.add_theme_stylebox_override("pressed", _plate(fill.darkened(0.08), edge, 1))
	button.add_theme_stylebox_override("disabled", _plate(ROW_OFF, Color("4a4034"), 1))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	return button


func _lab(text: String, size: int, color: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lab


func _plate(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
