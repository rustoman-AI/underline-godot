class_name ObserverPanel
extends Control

## P87 desk panel. Marks, kit, free swap. AMBIENT. No face, no stats.

const PAPER := Color("241c14")
const PAPER_INK := Color("f4efe4")
const PAPER_MUTED := Color("d9cbb4")
const PAPER_EDGE := Color("b89a6a")
const PAPER_BUTTON := Color("3a3126")
const PAPER_BUTTON_HOVER := Color("4a3f32")
const PAPER_BUTTON_DOWN := Color("1a140e")
const BRASS := Color("e2a63a")
const FOCUS := Color("e9c46a")

var host = null
var _selected := {"kind": "slot", "id": "coat"}
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _hooks: HBoxContainer
var _bust: Control
var _body: VBoxContainer
var _tail: VBoxContainer
var _tail_scroll: ScrollContainer
var _main: Container
var _hint: Label
var _blocked: Label
var _sliding := false


func present(station) -> void:
	host = station
	if host != null and host.game != null:
		MarksKit.clear_pip(host.game)
		MarksKit.take_anim(host.game)
	if _selected.is_empty():
		_selected = MarksKit.default_selection(host.game) if host != null else {"kind": "slot", "id": "coat"}
	elif str(_selected.get("kind", "")) == "":
		_selected = MarksKit.default_selection(host.game)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild()


func dismiss() -> void:
	visible = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or host == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if host.has_method("_dismiss_undo_toast") and host._dismiss_undo_toast():
			host.get_viewport().set_input_as_handled()
			return
		_close()
		host.get_viewport().set_input_as_handled()


func _rebuild() -> void:
	var stale: Array = get_children()
	for child in stale:
		remove_child(child)
		child.free()
	var game = host.game if host != null else null
	if game == null:
		return
	var view := get_viewport_rect().size
	if view.x < 8.0:
		view = Vector2(1280, 720)
	var width := minf(640.0, view.x - 48.0)
	var cap := view.y - 48.0
	custom_minimum_size = Vector2(width, 0)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _paper())
	add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(_body)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title := _lab(Copy.t("obs.title"), 22, true, PAPER_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_body.add_child(head)
	var content_w := width - 20.0
	var stacked := content_w < 536.0
	_main = VBoxContainer.new() if stacked else HBoxContainer.new()
	_main.add_theme_constant_override("separation", 16)
	_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body.add_child(_main)
	var bust_scale := 0.75 if stacked or cap < 460.0 else 1.0
	_bust = _make_bust(game, bust_scale)
	_main.add_child(_bust)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(360 if not stacked else content_w, 120)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_brass_scroll(_scroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 12)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_detail)
	_main.add_child(_scroll)
	_fill_detail(game)
	## Kit through Close scroll inside the window. The portrait stays put.
	_tail_scroll = ScrollContainer.new()
	_tail_scroll.set_meta("obs_tail_scroll", true)
	_tail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tail_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_brass_scroll(_tail_scroll)
	_tail = VBoxContainer.new()
	_tail.add_theme_constant_override("separation", 8)
	_tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tail_scroll.add_child(_tail)
	_body.add_child(_tail_scroll)
	var kit_head := _lab(Copy.t("obs.kit_title"), 16, true, PAPER_INK)
	kit_head.set_meta("kit_fold", true)
	_tail.add_child(kit_head)
	_hooks = HBoxContainer.new()
	_hooks.add_theme_constant_override("separation", 24)
	_hooks.alignment = BoxContainer.ALIGNMENT_CENTER
	for slot in MarksKit.SLOT_ORDER:
		_hooks.add_child(_hook(game, slot))
	_tail.add_child(_hooks)
	_add_pocket(game)
	_add_faces(game)
	_add_rivals(game)
	_add_day_tally(game)
	_hint = _lab(Copy.t("obs.hint"), 14, false, PAPER_MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tail.add_child(_hint)
	var close := _btn(Copy.t("Close"), _close)
	close.set_meta("obs_focus", "close")
	close.custom_minimum_size = Vector2(110, 40)
	_tail.add_child(close)
	_wire_focus()
	var block := _lab("", 14, false, PAPER_MUTED)
	block.visible = false
	_tail.add_child(block)
	_fit_panel(view, width, cap, head)


## Cap the desk to the window. Kit through Close live in the brass tail scroll.
func _fit_panel(view: Vector2, width: float, cap: float, head: Control) -> void:
	var pad := 28.0
	var sep := float(_body.get_theme_constant("separation"))
	## Autowrap labels have no width yet, so their minimum height is one glyph per line.
	## Pin them to the width they will actually get, then measure that. The detail scrolls.
	var inner := maxf(120.0, width - 20.0)
	_pin_wrap(head, inner)
	_pin_wrap(_tail, inner)
	var bust_w := 160.0
	if _bust.get_child_count() > 0 and _bust.get_child(0) is Control:
		bust_w = maxf(96.0, (_bust.get_child(0) as Control).custom_minimum_size.x)
	_pin_wrap(_bust, bust_w)
	var main_h := maxf(_layout_height(_bust), _scroll.custom_minimum_size.y)
	var top_h := _layout_height(head) + sep + main_h + sep
	var tail_h := _layout_height(_tail)
	var need := top_h + tail_h + pad
	var used := minf(cap, need)
	var tail_view := tail_h
	if need > cap:
		tail_view = maxf(96.0, cap - pad - top_h)
	_tail_scroll.custom_minimum_size = Vector2(0, tail_view)
	position = Vector2(maxi(24.0, (view.x - width) * 0.5), maxi(24.0, (view.y - used) * 0.5))
	size = Vector2(width, used)
	custom_minimum_size = size


## Give a wrapping control the width it will be laid out at, so its minimum height is the real line count.
func _pin_wrap(node: Node, inner: float) -> void:
	if node is Label or node is Button:
		var ctl := node as Control
		if ctl.autowrap_mode != TextServer.AUTOWRAP_OFF and ctl.custom_minimum_size.x < 8.0:
			ctl.custom_minimum_size.x = inner
	for child in node.get_children():
		if child is ScrollContainer:
			continue
		_pin_wrap(child, inner)


## Scroll views count as their window, not the scrolled list. A plain control counts as its own minimum.
func _layout_height(node: Control) -> float:
	if node is ScrollContainer:
		return node.custom_minimum_size.y
	if node is BoxContainer:
		var box := node as BoxContainer
		var vertical := box is VBoxContainer
		var sep := float(box.get_theme_constant("separation"))
		var total := 0.0
		var n := 0
		for child in box.get_children():
			if not (child is Control) or not (child as Control).visible:
				continue
			var h := _layout_height(child)
			if vertical:
				total += h
				n += 1
			else:
				total = maxf(total, h)
		if vertical and n > 1:
			total += sep * float(n - 1)
		return total
	if (node is Label or node is Button) and node.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return _wrapped_height(node)
	return node.get_combined_minimum_size().y


## Godot reports a zero-width autowrap line as one glyph per row. Measure at the pinned width instead.
func _wrapped_height(ctl: Control) -> float:
	var text := ""
	var px := 16
	if ctl is Label:
		text = (ctl as Label).text
		px = int((ctl as Label).get_theme_font_size("font_size"))
	else:
		var button := ctl as Button
		text = button.text
		px = int(button.get_theme_font_size("font_size"))
	if px < 8:
		px = 16
	var width := ctl.custom_minimum_size.x
	if width < 8.0:
		width = 160.0
	var font: Font = ctl.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var text_h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, px).y
	var pad := 8.0 if ctl is Button else 0.0
	return maxf(ctl.custom_minimum_size.y, text_h + pad)


func _fill_detail(game) -> void:
	for child in _detail.get_children():
		child.queue_free()
	_add_caller(game)
	var kind := str(_selected.get("kind", "slot"))
	var id := str(_selected.get("id", "coat"))
	if kind == "mark":
		_fill_mark(game, id)
		return
	_fill_slot(game, id)


## Home desk. The same courier as the home Visit, above the mark or kit detail. No button.
func _add_caller(game) -> void:
	if _detail == null or not PlatformCallers.enabled:
		return
	var card: Dictionary = PlatformCallers.card(game)
	if card.is_empty():
		return
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 4)
	var title := _lab(Copy.t("caller.title"), 14, true, PAPER_INK)
	title.clip_text = false
	title.set_meta("caller_title", true)
	block.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("caller_hbox", true)
	var portrait_id := str(card.portrait)
	if host != null and host.has_method("_portrait_box"):
		var portrait: TextureRect = host._portrait_box(portrait_id, 36)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		portrait.custom_minimum_size = Vector2(36, 36)
		portrait.set_meta("caller_portrait", portrait_id)
		row.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 2)
	var who := HBoxContainer.new()
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := _lab(Copy.t(str(card.name_key)), 15, true, PAPER_INK)
	name.clip_text = false
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name.set_meta("caller_name", true)
	who.add_child(name)
	var dot := _lab(" · ", 15, false, PAPER_MUTED)
	dot.clip_text = false
	dot.autowrap_mode = TextServer.AUTOWRAP_OFF
	dot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	who.add_child(dot)
	var role := _lab(Copy.t(str(card.role_key)), 15, false, PAPER_MUTED)
	role.clip_text = false
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role.set_meta("caller_role", true)
	who.add_child(role)
	words.add_child(who)
	var quote := _lab(Copy.t(str(card.line_key)), 14, false, PAPER_INK)
	quote.clip_text = false
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quote_font: Font = null
	if host != null and host.get("body_font") != null:
		quote_font = host.body_font
	if quote_font == null:
		quote_font = load("res://assets/fonts/CourierPrime-Regular.ttf")
	if quote_font != null:
		quote.add_theme_font_override("font", quote_font)
	quote.custom_minimum_size = Vector2(300, 0)
	quote.set_meta("caller_quote", true)
	words.add_child(quote)
	row.add_child(words)
	block.add_child(row)
	var shell := MarginContainer.new()
	shell.set_meta("caller_row", true)
	shell.set_meta("caller_fid", str(card.fid))
	shell.set_meta("caller_why", str(card.why))
	shell.set_meta("caller_line_key", str(card.line_key))
	shell.set_meta("caller_home", "desk")
	shell.tooltip_text = Copy.t("caller.tip")
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.focus_mode = Control.FOCUS_NONE
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("margin_right", 8)
	shell.add_child(block)
	_detail.add_child(shell)


func _fill_mark(game, id: String) -> void:
	MarksKit.mark_viewed(game, id)
	var state := MarksKit.state_of_mark(game, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	ObsGlyph.rect(row, "mark", id, 32, PAPER_INK if state == "inked" else PAPER_MUTED)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	var name := _lab(Copy.t("obs.mark.%s.name" % id), 16, true, PAPER_INK)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name)
	var state_key := "obs.mark_state_%s" % state
	var state_lab := _lab(Copy.t(state_key), 14, false, PAPER_MUTED)
	state_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_lab.custom_minimum_size = Vector2(120, 0)
	words.add_child(state_lab)
	if MarksKit.boot(game).fresh.has(id):
		words.add_child(_lab(Copy.t("obs.mark_new"), 14, false, BRASS))
	row.add_child(words)
	_detail.add_child(row)
	var flavor := _lab(Copy.t("obs.mark.%s.flavor" % id), 14, false, PAPER_INK)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(flavor)
	for line in MarksKit.does_lines(id, "mark"):
		var does := _lab(line, 14, false, PAPER_MUTED)
		does.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(does)
	_detail.add_child(_lab(Copy.t("obs.earned_from_head"), 14, true, PAPER_MUTED))
	var earned := _lab(MarksKit.earned_line(game, id), 14, false, PAPER_MUTED)
	earned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(earned)
	if state == "offered":
		var key := MarksKit.ink_button_key(game, id)
		var narrow := size.x < 400.0
		var label := Copy.t("obs.ink_btn") if narrow and size.x < 360.0 else Copy.t(key if key != "obs.ink.queue" else "obs.ink.queue")
		if key != "obs.ink.queue":
			label = Copy.t(key)
		var button := _btn(label, _queue.bind(id))
		button.set_meta("obs_focus", "pane")
		button.custom_minimum_size = Vector2(120 if Copy.ru() else 110, 44)
		button.disabled = key != "obs.ink.queue"
		if button.disabled:
			_disable_face(button, "")
		_detail.add_child(button)


func _fill_slot(game, slot: String) -> void:
	var head := _lab(Copy.t("obs.slot_%s" % slot), 16, true, PAPER_INK)
	_detail.add_child(head)
	if not MarksKit.can_swap(game):
		_blocked = _lab(Copy.t("obs.swap_blocked"), 14, false, PAPER_MUTED)
		_blocked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(_blocked)
	var owned: Array = MarksKit.owned_in(game, slot)
	if owned.is_empty():
		var empty := _lab(Copy.t("obs.kit_empty"), 14, false, PAPER_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(0, 36)
		_detail.add_child(empty)
	for id in owned:
		_detail.add_child(_kit_row(game, slot, str(id)))
	for line in MarksKit.lost_lines(game, slot):
		var lost := _lab(line, 14, false, PAPER_MUTED)
		lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lost.focus_mode = Control.FOCUS_NONE
		_detail.add_child(lost)


func _kit_row(game, slot: String, id: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := ObsGlyph.rect(row, "kit", id, 48, PAPER_INK)
	icon.custom_minimum_size = Vector2(48, 48)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := _lab(Copy.t("obs.kit.%s.name" % id), 16, true, PAPER_INK)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name)
	var flavor := _lab(Copy.t("obs.kit.%s.flavor" % id), 14, false, PAPER_MUTED)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(flavor)
	var earned := _lab(MarksKit.earned_line(game, id), 14, false, PAPER_MUTED)
	earned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(earned)
	var worn := MarksKit.worn_in(game, slot) == id
	var state := _lab(Copy.t("obs.kit_state_worn" if worn else "obs.kit_state_kept"), 14, false, PAPER_INK if worn else PAPER_MUTED)
	state.custom_minimum_size = Vector2(120, 18)
	words.add_child(state)
	row.add_child(words)
	box.add_child(row)
	var verb := "obs.take_off" if worn else "obs.wear"
	var button := _btn(Copy.t(verb), _swap.bind(slot, "" if worn else id))
	button.custom_minimum_size = Vector2(120 if Copy.ru() else 110, 44)
	button.set_meta("obs_swap", true)
	button.set_meta("obs_focus", "pane")
	if not MarksKit.can_swap(game) or _sliding:
		button.disabled = true
		_disable_face(button, Copy.t("obs.swap_blocked"))
	box.add_child(button)
	return box


func _hook(game, slot: String) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(96, 0)
	col.add_theme_constant_override("separation", 4)
	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 56)
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text = false
	button.text = ""
	var worn := MarksKit.worn_in(game, slot)
	var face := _face(false, false)
	if worn != "":
		face.border_color = PAPER_EDGE
		face.set_border_width_all(2)
	else:
		face.border_color = Color(PAPER_EDGE, 0.7)
		face.set_border_width_all(1)
	if str(_selected.get("kind", "")) == "slot" and str(_selected.get("id", "")) == slot:
		face.border_color = BRASS
		face.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", face)
	button.add_theme_stylebox_override("hover", _face(false, true))
	button.add_theme_stylebox_override("pressed", _face(true, false))
	button.add_theme_stylebox_override("disabled", _flat_disabled())
	button.add_theme_stylebox_override("focus", _focus_ring())
	if worn != "":
		button.icon = ObsGlyph.texture("kit", worn, 48)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 48)
		button.add_theme_constant_override("icon_max_height", 40)
		button.add_theme_color_override("icon_normal_color", PAPER_INK)
		button.add_theme_color_override("icon_hover_color", PAPER_INK)
		button.add_theme_color_override("icon_focus_color", PAPER_INK)
	else:
		button.text = Copy.t("obs.kit_empty")
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", PAPER_MUTED)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.clip_text = false
	button.set_meta("obs_focus", "hook")
	button.pressed.connect(_select.bind("slot", slot))
	col.add_child(button)
	var label := _lab(Copy.t("obs.slot_%s" % slot), 14, false, PAPER_INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(96, 18)
	col.add_child(label)
	var under := _lab(Copy.t("obs.kit.%s.name" % worn) if worn != "" else Copy.t("obs.kit_empty"), 12, false, PAPER_MUTED)
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	under.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	under.custom_minimum_size = Vector2(96, 36)
	under.clip_text = false
	col.add_child(under)
	return col


func _make_bust(game, scale: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := Control.new()
	var w := 160.0 * scale
	var h := 240.0 * scale
	box.custom_minimum_size = Vector2(w, h)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(box)
	var tex := _bust_tex()
	if tex != null:
		var face := TextureRect.new()
		face.texture = tex
		face.custom_minimum_size = Vector2(w, h)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(face)
	else:
		var outline := _lab("○", 28, false, PAPER_EDGE)
		outline.position = Vector2(w * 0.35, 8)
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(outline)
	var rows: Array = MarksKit.rows(game)
	var spots := ["forearm", "hand", "chest_neck"]
	for i in 3:
		var spot := Button.new()
		spot.focus_mode = Control.FOCUS_NONE
		spot.mouse_filter = Control.MOUSE_FILTER_STOP
		spot.custom_minimum_size = Vector2(28 * scale, 28 * scale)
		spot.position = Vector2(18.0 * scale + float(i) * 36.0 * scale, h * 0.55)
		var ring := _face(false, false)
		ring.bg_color = Color(0, 0, 0, 0)
		ring.border_color = Color(PAPER_EDGE, 0.7)
		ring.set_border_width_all(1)
		spot.add_theme_stylebox_override("normal", ring)
		spot.add_theme_stylebox_override("hover", ring)
		spot.add_theme_stylebox_override("focus", _focus_ring())
		spot.tooltip_text = Copy.t("obs.mark_locked")
		if i < rows.size() and MarksKit.state_of_mark(game, str(rows[i])) == "inked":
			spot.icon = ObsGlyph.texture("mark", str(rows[i]), 24)
			spot.expand_icon = false
			spot.add_theme_color_override("icon_normal_color", PAPER_INK)
			spot.tooltip_text = Copy.t("obs.mark.%s.name" % str(rows[i]))
			var mark_id := str(rows[i])
			spot.pressed.connect(_select.bind("mark", mark_id))
		box.add_child(spot)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(w, 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rows.is_empty():
		var locked := _lab(Copy.t("obs.mark_locked"), 14, false, PAPER_MUTED)
		locked.focus_mode = Control.FOCUS_NONE
		locked.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(locked)
	else:
		for id in rows:
			var state := MarksKit.state_of_mark(game, str(id))
			var button := _btn(Copy.t("obs.mark.%s.name" % str(id)), _select.bind("mark", str(id)))
			button.set_meta("obs_focus", "mark")
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.add_theme_color_override("font_color", PAPER_MUTED if state == "noroom" else PAPER_INK)
			if state == "inked":
				button.icon = ObsGlyph.texture("mark", str(id), 24)
				button.add_theme_color_override("icon_normal_color", PAPER_INK)
				button.add_theme_color_override("icon_hover_color", PAPER_INK)
			list.add_child(button)
	col.add_child(list)
	return col


func _bust_tex() -> Texture2D:
	var path := "res://assets/portraits/obs_silhouette.png"
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null


func _select(kind: String, id: String) -> void:
	_selected = {"kind": kind, "id": id}
	if host != null and host.game != null and kind == "mark":
		MarksKit.mark_viewed(host.game, id)
	_rebuild()


func _queue(id: String) -> void:
	if host == null or host.game == null:
		return
	MarksKit.queue_ink(host.game, id)
	_rebuild()


func _swap(slot: String, id: String) -> void:
	if host == null or host.game == null or _sliding:
		return
	if not MarksKit.can_swap(host.game):
		return
	var beat: Dictionary = MarksKit.swap(host.game, slot, id)
	if beat.is_empty():
		return
	if host.has_method("_ui_click"):
		host._ui_click()
	var motion: bool = host.has_method("_motion_off") and bool(host._motion_off())
	if not motion:
		_sliding = true
	_rebuild()
	if host.has_method("_undo_toast"):
		host._undo_toast(str(beat.get("toast", "")), _undo)
	if not motion:
		var tween := create_tween()
		tween.tween_interval(0.15)
		tween.tween_callback(_slide_done)
	else:
		_sliding = false


func _slide_done() -> void:
	_sliding = false
	if host != null:
		_rebuild()


func _undo() -> void:
	if host == null or host.game == null:
		return
	if not MarksKit.can_swap(host.game):
		if host.has_method("_hide_undo_toast"):
			host._hide_undo_toast()
		return
	if not MarksKit.undo_swap(host.game):
		return
	if host.has_method("_hide_undo_toast"):
		host._hide_undo_toast()
	_rebuild()


func _close() -> void:
	dismiss()
	if host != null and host.has_method("_close_observer"):
		host._close_observer()


## Pocket under Kit. Stays when empty: it is also the tally.
func _add_pocket(game) -> void:
	if not CarriedWord.enabled:
		return
	var head := _lab(Copy.t("carry.pocket_title"), 16, true, PAPER_INK)
	head.set_meta("pocket_fold", true)
	_tail.add_child(head)
	var view: Dictionary = CarriedWord.pocket_view(game)
	if bool(view.get("empty", true)):
		var empty := _lab(Copy.t("carry.pocket_empty"), 14, false, PAPER_MUTED)
		empty.set_meta("pocket_empty", true)
		_tail.add_child(empty)
	else:
		var line := _lab(str(view.get("line", "")), 14, false, PAPER_INK)
		line.set_meta("pocket_line", true)
		_tail.add_child(line)
		if bool(view.get("no_one", false)):
			var gone := _lab(Copy.t("carry.no_one"), 14, false, PAPER_MUTED)
			gone.set_meta("pocket_none", true)
			_tail.add_child(gone)
		var written := str(view.get("text", ""))
		if written != "":
			var inset := PanelContainer.new()
			inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inset.add_theme_stylebox_override("panel", _note_paper())
			inset.set_meta("pocket_text", true)
			var body := _lab(written, 14, false, PAPER_INK)
			body.clip_text = false
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if host != null and host.get("body_font") != null:
				body.add_theme_font_override("font", host.body_font)
			inset.add_child(body)
			_tail.add_child(inset)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 8)
		buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if bool(view.get("can_open", false)):
			buttons.add_child(_pocket_button("carry.open", _open_note))
		buttons.add_child(_pocket_button("carry.give_back", _give_note))
		_tail.add_child(buttons)
	var tally: Dictionary = CarriedWord.tally(game)
	var count := _lab(Copy.fill("carry.count", {"n": int(tally.get("n", 0))}), 14, false, PAPER_INK)
	count.set_meta("pocket_count", true)
	_tail.add_child(count)
	for id in tally.get("closed", []):
		var title := _lab(Copy.t("carry.%s.title" % str(id)), 14, false, PAPER_INK)
		title.set_meta("pocket_closed", str(id))
		_tail.add_child(title)
	for id in tally.get("opened", []):
		var title := _lab(Copy.t("carry.%s.title" % str(id)), 14, false, PAPER_MUTED)
		title.set_meta("pocket_opened", str(id))
		_tail.add_child(title)


func _open_note() -> void:
	if host == null or host.game == null:
		return
	if not CarriedWord.open(host.game):
		return
	_rebuild()
	if host.has_method("_undo_toast"):
		host._undo_toast(Copy.t("carry.open_confirm"), _cancel_open, _commit_open)


func _cancel_open() -> void:
	if host != null and host.game != null:
		CarriedWord.cancel_open(host.game)
	_rebuild()


func _commit_open() -> void:
	if host != null and host.game != null:
		CarriedWord.commit_open(host.game)
	_rebuild()


func _give_note() -> void:
	if host == null or host.game == null:
		return
	var from_name := CarriedWord.give_back(host.game)
	if from_name == "":
		return
	if host.has_method("_hide_undo_toast"):
		host._hide_undo_toast()
	if host.has_method("_toast"):
		host._toast(Copy.fill("carry.given_back", {"from": from_name}))
	_rebuild()


func _pocket_button(key: String, cb: Callable) -> Button:
	var button := _btn(Copy.t(key), cb)
	button.custom_minimum_size = Vector2(110, 40)
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_theme_font_size_override("font_size", 20)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("obs_focus", "pocket")
	button.set_meta("pocket_button", key)
	button.tooltip_text = ""
	if host != null and host.get("display_font") != null:
		button.add_theme_font_override("font", host.display_font)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = BRASS
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(2)
	button.add_theme_stylebox_override("focus", focus)
	var hover := _face(false, true)
	hover.border_color = BRASS
	hover.set_border_width_all(1)
	button.add_theme_stylebox_override("hover", hover)
	return button


func _note_paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_BUTTON
	style.border_color = PAPER_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8)
	return style


## Faces on the line. Met only. Hidden when nobody has been met. Click opens that Visit.
func _add_faces(game) -> void:
	if not PlatformFaces.enabled:
		return
	var rows: Array = PlatformFaces.list_rows(game)
	if rows.is_empty():
		return
	var head := _lab(Copy.t("regular.title"), 16, true, PAPER_INK)
	head.set_meta("face_fold", true)
	_tail.add_child(head)
	var count := _lab(Copy.fill("regular.count", {"n": rows.size(), "total": PlatformFaces.face_total(game)}), 14, false, PAPER_MUTED)
	count.set_meta("face_count", true)
	if rows.size() < PlatformFaces.face_total(game):
		count.tooltip_text = Copy.t("regular.unmet")
	_tail.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, mini(rows.size() * 36, 220))
	scroll.set_meta("face_scroll", true)
	_brass_scroll(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for entry in rows:
		list.add_child(_face_button(entry))
	_tail.add_child(scroll)


## Rivals under Faces. Three fixed seats. A row with no target is quiet and not clickable.
func _add_rivals(game) -> void:
	if not RivalDesk.enabled or game == null:
		return
	var head := _lab(Copy.t("rival.title"), 16, true, PAPER_INK)
	head.set_meta("rival_fold", true)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.tooltip_text = Copy.t("rival.tip")
	_tail.add_child(head)
	var width := maxf(360.0, size.x - 48.0)
	for entry in RivalDesk.rows(game):
		_tail.add_child(_rival_row(entry, width))


func _rival_row(entry: Dictionary, width: float) -> Control:
	var text := str(entry.get("line", ""))
	var tip := Copy.t("rival.tip")
	var clickable := bool(entry.get("clickable", false))
	var ink := PAPER_INK if clickable else PAPER_MUTED
	if not clickable:
		var quiet := _lab(text, 14, false, ink)
		quiet.custom_minimum_size = Vector2(width, 0)
		quiet.mouse_filter = Control.MOUSE_FILTER_STOP
		quiet.focus_mode = Control.FOCUS_NONE
		quiet.mouse_default_cursor_shape = Control.CURSOR_ARROW
		quiet.tooltip_text = tip
		quiet.set_meta("rival_row", true)
		quiet.set_meta("rival_fid", str(entry.get("fid", "")))
		quiet.set_meta("rival_quiet", true)
		quiet.set_meta("rival_target", "")
		return quiet
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(width, 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = tip
	button.set_meta("obs_focus", "rival")
	button.set_meta("rival_row", true)
	button.set_meta("rival_fid", str(entry.get("fid", "")))
	button.set_meta("rival_quiet", false)
	button.set_meta("rival_target", str(entry.get("target", "")))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_stylebox_override("normal", _face_row_style(false))
	button.add_theme_stylebox_override("hover", _face_row_style(true))
	button.add_theme_stylebox_override("pressed", _face_row_style(true))
	button.add_theme_stylebox_override("focus", _face_focus())
	button.pressed.connect(_open_rival.bind(str(entry.get("target", ""))))
	return button


func _open_rival(sid: String) -> void:
	if sid == "":
		return
	_open_face(sid)


## Days kept. A plain tally. Hover lists station · day · week. Focusable only when that list exists.
func _add_day_tally(game) -> void:
	if not StationDays.enabled or game == null:
		return
	var n := StationDays.count(game)
	var lines := StationDays.tally_lines(game)
	var text := Copy.fill("sday.count", {"n": n})
	if lines.is_empty():
		var quiet := _lab(text, 14, false, PAPER_INK)
		quiet.focus_mode = Control.FOCUS_NONE
		quiet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quiet.set_meta("sday_count", true)
		quiet.set_meta("sday_n", n)
		_tail.add_child(quiet)
		return
	var button := DayTally.new()
	button.text = text
	button.lines = lines
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 28)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "\n".join(lines)
	button.set_meta("obs_focus", "sday")
	button.set_meta("sday_count", true)
	button.set_meta("sday_tally", true)
	button.set_meta("sday_n", n)
	button.set_meta("sday_rows", lines.size())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", PAPER_INK)
	button.add_theme_color_override("font_hover_color", PAPER_INK)
	button.add_theme_color_override("font_pressed_color", PAPER_INK)
	button.add_theme_color_override("font_focus_color", PAPER_INK)
	button.add_theme_stylebox_override("normal", _day_style(false))
	button.add_theme_stylebox_override("hover", _day_style(true))
	button.add_theme_stylebox_override("pressed", _day_style(true))
	button.add_theme_stylebox_override("focus", _day_focus())
	_tail.add_child(button)


func _day_style(hot: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER.r, PAPER.g, PAPER.b, 0.0)
	style.border_color = BRASS if hot else Color(0, 0, 0, 0)
	style.set_border_width_all(1 if hot else 0)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _day_focus() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


static func tally_tip(lines: PackedStringArray) -> Control:
	var cap := 8
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line in lines:
		var lab := Label.new()
		lab.text = line
		lab.clip_text = false
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 14)
		lab.add_theme_color_override("font_color", Color("efe6d2"))
		lab.custom_minimum_size = Vector2(280, 20)
		lab.set_meta("sday_tally_line", true)
		list.add_child(lab)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.07, 0.06, 0.05, 0.97)
	plate.border_color = Color(0.93, 0.78, 0.42, 0.9)
	plate.set_border_width_all(1)
	plate.set_content_margin_all(8)
	if lines.size() <= cap:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", plate)
		panel.add_child(list)
		panel.set_meta("sday_tally_cap", cap)
		return panel
	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(300, cap * 22)
	scroll.set_meta("sday_tally_scroll", true)
	scroll.set_meta("sday_tally_cap", cap)
	var theme := Theme.new()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.07, 0.06, 0.55)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.55, 0.44, 0.26, 0.85)
	grab.border_color = Color(0.93, 0.78, 0.42, 0.55)
	grab.set_border_width_all(1)
	grab.set_corner_radius_all(2)
	for kind in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", kind, track)
		theme.set_stylebox("scroll_focus", kind, track)
		theme.set_stylebox("grabber", kind, grab)
		theme.set_stylebox("grabber_highlight", kind, grab)
		theme.set_stylebox("grabber_pressed", kind, grab)
	scroll.theme = theme
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", plate)
	frame.add_child(scroll)
	scroll.add_child(list)
	return frame


func _face_button(entry: Dictionary) -> Button:
	var sid := str(entry.get("sid", ""))
	var station := Copy.t(str(entry.get("station", sid)))
	var text := "%s · %s · %s" % [Copy.t(str(entry.get("name_key", ""))), station, Copy.t(str(entry.get("band_key", "")))]
	var muted := bool(entry.get("muted", false))
	var ink := PAPER_MUTED if muted else PAPER_INK
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 32)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = Copy.t("regular.tip")
	button.set_meta("obs_focus", "face")
	button.set_meta("face_sid", sid)
	button.set_meta("face_list", true)
	button.set_meta("face_muted", muted)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_stylebox_override("normal", _face_row_style(false))
	button.add_theme_stylebox_override("hover", _face_row_style(true))
	button.add_theme_stylebox_override("pressed", _face_row_style(true))
	button.add_theme_stylebox_override("focus", _face_focus())
	button.pressed.connect(_open_face.bind(sid))
	return button


func _open_face(sid: String) -> void:
	if host == null:
		return
	if host.has_method("_close_observer"):
		host._close_observer()
	if host.get("showing_network") != true and host.has_method("_toggle_network"):
		host._toggle_network()
	var net = host.get("network_view")
	if net != null and net.has_method("open_visit"):
		net.open_visit(str(sid))


func _face_row_style(hot: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_BUTTON_HOVER if hot else Color(PAPER.r, PAPER.g, PAPER.b, 0.0)
	style.border_color = BRASS if hot else Color(0, 0, 0, 0)
	style.set_border_width_all(1 if hot else 0)
	style.set_corner_radius_all(2)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _face_focus() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


func _brass_scroll(node: Control) -> void:
	var theme := Theme.new()
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.07, 0.06, 0.55)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.55, 0.44, 0.26, 0.85)
	grab.border_color = Color(0.93, 0.78, 0.42, 0.55)
	grab.set_border_width_all(1)
	grab.set_corner_radius_all(2)
	for kind in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", kind, track)
		theme.set_stylebox("scroll_focus", kind, track)
		theme.set_stylebox("grabber", kind, grab)
		theme.set_stylebox("grabber_highlight", kind, grab)
		theme.set_stylebox("grabber_pressed", kind, grab)
	node.theme = theme


func _wire_focus() -> void:
	var marks: Array = []
	var hooks: Array = []
	var pocket: Array = []
	var faces: Array = []
	var rivals: Array = []
	var days: Array = []
	var pane: Array = []
	var close: Array = []
	_collect_focus(self, marks, hooks, pocket, faces, rivals, days, pane, close)
	var order: Array = []
	order.append_array(marks)
	order.append_array(hooks)
	order.append_array(pocket)
	order.append_array(faces)
	order.append_array(rivals)
	order.append_array(days)
	order.append_array(pane)
	order.append_array(close)
	for i in order.size():
		var button: Control = order[i]
		var prev: Control = order[(i - 1 + order.size()) % order.size()]
		var nxt: Control = order[(i + 1) % order.size()]
		button.focus_neighbor_left = button.get_path_to(prev)
		button.focus_neighbor_right = button.get_path_to(nxt)
		button.focus_neighbor_top = button.get_path_to(prev)
		button.focus_neighbor_bottom = button.get_path_to(nxt)
		button.focus_next = button.get_path_to(nxt)
		button.focus_previous = button.get_path_to(prev)


func _collect_focus(node: Node, marks: Array, hooks: Array, pocket: Array, faces: Array, rivals: Array, days: Array, pane: Array, close: Array) -> void:
	if node is Control and str(node.get_meta("obs_focus", "")) != "":
		var bucket := str(node.get_meta("obs_focus"))
		if bucket == "mark":
			marks.append(node)
		elif bucket == "hook":
			hooks.append(node)
		elif bucket == "pocket":
			pocket.append(node)
		elif bucket == "face":
			faces.append(node)
		elif bucket == "rival":
			rivals.append(node)
		elif bucket == "sday":
			days.append(node)
		elif bucket == "pane":
			pane.append(node)
		elif bucket == "close":
			close.append(node)
	for child in node.get_children():
		_collect_focus(child, marks, hooks, pocket, faces, rivals, days, pane, close)


func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER_EDGE
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	return style


func _face(down: bool, hot: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_BUTTON_DOWN if down else (PAPER_BUTTON_HOVER if hot else PAPER_BUTTON)
	style.border_color = PAPER_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _flat_disabled() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(PAPER_EDGE, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 8
	style.content_margin_right = 8
	return style


func _focus_ring() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = FOCUS
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	return style


func _disable_face(button: Button, tip: String) -> void:
	button.disabled = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	button.add_theme_stylebox_override("disabled", _flat_disabled())
	button.add_theme_color_override("font_disabled_color", PAPER_MUTED)
	if tip != "":
		button.tooltip_text = tip


func _btn(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(110, 40)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", PAPER_INK)
	button.add_theme_color_override("font_hover_color", PAPER_INK)
	button.add_theme_color_override("font_pressed_color", PAPER_INK)
	button.add_theme_stylebox_override("normal", _face(false, false))
	button.add_theme_stylebox_override("hover", _face(false, true))
	button.add_theme_stylebox_override("pressed", _face(true, false))
	button.add_theme_stylebox_override("disabled", _flat_disabled())
	button.add_theme_stylebox_override("focus", _focus_ring())
	button.pressed.connect(cb)
	return button


func _lab(text: String, size: int, bold: bool, color: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.clip_text = false
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


class DayTally extends Button:
	var lines := PackedStringArray()

	func _make_custom_tooltip(_for_text: String) -> Object:
		return ObserverPanel.tally_tip(lines)
