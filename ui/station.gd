extends Control

## Cut-away of the station. Placeholder shapes on a painted wall. The sim stays in charge of the week.

const INK := Color("efe6d2")
const INK_DARK := Color("24180e")
const MUTED := Color("b7aa96")
const PAPER := Color("241c14")
const PAPER_INK := Color("f4efe4")
const PAPER_MUTED := Color("d9cbb4")
const PAPER_BUTTON := Color("3a3126")
const PAPER_BUTTON_HOVER := Color("4a3f32")
const PAPER_BUTTON_DOWN := Color("1a140e")
const PAPER_EDGE := Color("b89a6a")
const DELTA_UP := Color("b6e38a")
const DELTA_DOWN := Color("ff9b8a")
const STEEL := Color(0.07, 0.08, 0.09, 0.88)
const ROOM_COLOR := {
	"platform": Color("c9843a"),
	"quarters": Color("c4a574"),
	"hydroponics": Color("5f8f4a"),
	"air_filter": Color("4e8f9c"),
	"generator": Color("d06a32"),
	"workshop": Color("8a6840"),
	"infirmary": Color("a85a62"),
	"meeting_hall": Color("7a6496"),
	"radio": Color("3f74a0"),
}
const STOCK_KEYS := ["air", "food", "power", "materials", "tokens", "influence"]
const ModalDeck = preload("res://ui/modals.gd")
const WAITING := "Someone is still waiting. Choose before the week ends."

var game: Game
var yard: Yard
var middle: VBoxContainer
var wide_row: HBoxContainer
var stack: VBoxContainer
var side: PanelContainer
var people_box: VBoxContainer
var title_row: HBoxContainer
var action_row: VBoxContainer
var pump_row: HBoxContainer
var res_grid: GridContainer
var week_label: Label
var footer: Label
var hint: Label
var end_button: Button
var pump_button: Button
var quarantine_button: Button
var burn_button: Button
var power_button: Button
var forecast_button: Button
var revolt_button: Button
var chips := {}
var hope_label: Label
var dis_label: Label
var hope_fill: ColorRect
var dis_fill: ColorRect
var dim: ColorRect
var card: PanelContainer
var card_body: VBoxContainer
var power_loss := {}
var chrome_bottom := 96.0
var notice := ""
var display_font: Font
var body_font: Font
var hud: PanelContainer
var hud_box: VBoxContainer
var meter_box: HBoxContainer
var ticker: HBoxContainer
var ticker_label: Label
var ticker_dismissed := false
var ticker_week := -1
var drawer_open := false
var tray: HBoxContainer
var people_button: Button
var on_paper := false
var turn_clear := false
var card_fit_queued := false
var portraits: Array = []
var ahead: PanelContainer
var deck = ModalDeck.new()
var ambient_restore: Callable = Callable()
var shelved_event := ""
var end_cover: Control
var ahead_box: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_load_fonts()
	_load_portraits()
	var theme := Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	self.theme = theme
	_build()
	var catalog := Catalog.new()
	if not catalog.load_all():
		footer.text = catalog.error
		footer.visible = true
		return
	game = Game.new()
	game.setup(catalog, 1, 40)
	yard.station = self
	_refresh()
	resized.connect(_layout)
	_layout()
	_show_dawn()
	if _want_shots():
		await _shots()


func _want_shots() -> bool:
	return OS.get_cmdline_user_args().has("--shots") or OS.get_environment("UNDERLINE_SHOTS") == "1"


func _load_fonts() -> void:
	body_font = FontFile.new()
	var body_path := ProjectSettings.globalize_path("res://assets/fonts/CourierPrime-Regular.ttf")
	if body_font.load_dynamic_font(body_path) != OK:
		body_font = ThemeDB.fallback_font
	var file := FontFile.new()
	var display_path := ProjectSettings.globalize_path("res://assets/fonts/BigShouldersDisplay.ttf")
	if file.load_dynamic_font(display_path) != OK:
		display_font = ThemeDB.fallback_font
		return
	var variation := FontVariation.new()
	variation.base_font = file
	# This file is the variable face. The string key "wght" is ignored and leaves
	# the Thin instance. The integer OpenType tag selects the real ExtraBold outlines.
	variation.set_variation_opentype({2003265652: 800.0})
	variation.get_string_size("Hg", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	display_font = variation


func _load_portraits() -> void:
	portraits.clear()
	for i in range(1, 17):
		var path := ProjectSettings.globalize_path("res://assets/portraits/portrait_%02d.webp" % i)
		var image := Image.load_from_file(path)
		if image == null or image.get_width() < 1:
			continue
		portraits.append(ImageTexture.create_from_image(image))


func _portrait_for(id: String) -> Texture2D:
	if portraits.is_empty():
		return null
	var n := 0
	for i in id.length():
		n = (n * 33 + id.unicode_at(i)) % portraits.size()
	return portraits[n]


func _portrait_box(id: String, px: int) -> TextureRect:
	var face := TextureRect.new()
	face.texture = _portrait_for(id)
	face.custom_minimum_size = Vector2(px, px)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.clip_contents = true
	return face


func _resident_id_named(who: String) -> String:
	var needle := who.strip_edges().to_lower()
	if needle == "":
		return ""
	for person in game.residents:
		var full := str(person.name).to_lower()
		var first := full.get_slice(" ", 0)
		if first == needle or full == needle or str(person.id) == needle:
			return str(person.id)
	return ""


func _who_row(who: String) -> void:
	var id := _resident_id_named(who)
	if id == "":
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_portrait_box(id, 84))
	var lab := _label(str(game.people[id].name), 18)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	card_body.add_child(row)


func _process(_delta: float) -> void:
	if end_button == null:
		return
	if _choice_shelved():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
		end_button.modulate = Color(1.0, 0.94 + 0.06 * pulse, 0.78 + 0.14 * pulse, 1.0)
		return
	if not turn_clear:
		end_button.modulate = Color(1, 1, 1, 1)
		return
	var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.4)
	end_button.modulate = Color(1.0, 0.97 + 0.03 * wave, 0.82 + 0.1 * wave, 1.0)


func _build() -> void:
	var backdrop := Backdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	yard = Yard.new()
	yard.set_anchors_preset(Control.PRESET_FULL_RECT)
	yard.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(yard)

	hud = _top_bar()
	add_child(hud)

	tray = HBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	pump_button = _tool("pump", "Pump", _ask_pump)
	quarantine_button = _tool("quarantine", "Quarantine", _ask_quarantine)
	burn_button = _tool("burn", "Burn", _ask_burn)
	power_button = _tool("power", "Power", _show_power)
	people_button = _tool("people", "People", _toggle_drawer)
	burn_button.tooltip_text = "Burn salvage"
	power_button.tooltip_text = "Power order"
	people_button.tooltip_text = "Residents"
	for button in [pump_button, quarantine_button, burn_button, power_button, people_button]:
		tray.add_child(button)

	end_button = _button("End turn", _end_turn)
	end_button.custom_minimum_size = Vector2(168, 58)
	end_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_button.add_theme_font_size_override("font_size", 26)
	end_button.add_theme_font_override("font", display_font)
	end_button.add_theme_color_override("font_color", INK_DARK)
	end_button.add_theme_color_override("font_disabled_color", Color("1a1008"))
	end_button.add_theme_stylebox_override("normal", _brass_style(false))
	end_button.add_theme_stylebox_override("hover", _brass_style(false))
	end_button.add_theme_stylebox_override("pressed", _brass_style(true))
	end_button.add_theme_stylebox_override("disabled", _brass_style(false, false))
	end_button.mouse_entered.connect(_show_ahead.bind(true))
	end_button.mouse_exited.connect(_show_ahead.bind(false))
	add_child(end_button)
	end_cover = Control.new()
	end_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_cover.mouse_entered.connect(_show_ahead.bind(true))
	end_cover.mouse_exited.connect(_show_ahead.bind(false))
	end_cover.gui_input.connect(_end_cover_input)
	add_child(end_cover)

	side = _side_panel()
	add_child(side)

	footer = _label("", 14)
	footer.visible = false
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)

	_build_overlay()


func _tool(kind: String, caption: String, cb: Callable) -> Button:
	var button := ToolButton.new()
	button.glyph_name = kind
	button.caption = caption
	button.tooltip_text = caption
	button.pressed.connect(cb)
	_style_tool(button)
	return button


func _style_tool(button: Button) -> void:
	var style := _steel_style()
	style.set_content_margin_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	var dimmed := style.duplicate() as StyleBoxFlat
	dimmed.bg_color = Color(0.07, 0.08, 0.09, 0.45)
	button.add_theme_stylebox_override("disabled", dimmed)
	button.custom_minimum_size = Vector2(58, 66)


func _top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _steel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	hud_box = box

	title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)
	week_label = _label("Week 1", 22, true)
	week_label.custom_minimum_size = Vector2(108, 28)
	week_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	week_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(week_label)

	res_grid = GridContainer.new()
	res_grid.columns = 6
	res_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(res_grid)
	for key in STOCK_KEYS:
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 3)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon := Glyph.new()
		icon.kind = str(key)
		icon.custom_minimum_size = Vector2(20, 20)
		chip.tooltip_text = str(key).capitalize()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var value := _label("0", 16)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		value.custom_minimum_size = Vector2(22, 18)
		var delta := _label("—", 18)
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		delta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		delta.custom_minimum_size = Vector2(42, 22)
		chip.add_child(icon)
		chip.add_child(value)
		chip.add_child(delta)
		chip.gui_input.connect(_chip_input.bind(str(key)))
		res_grid.add_child(chip)
		chips[key] = {"box": chip, "value": value, "delta": delta, "icon": icon}

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 12)
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(meters)
	meter_box = meters
	meters.add_child(_meter(Color("d7a441"), true))
	meters.add_child(_meter(Color("c4544a"), false))

	ticker = HBoxContainer.new()
	ticker.visible = false
	ticker.add_theme_constant_override("separation", 6)
	box.add_child(ticker)
	ticker_label = _label("", 14)
	ticker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ticker_label.custom_minimum_size = Vector2(80, 20)
	ticker_label.clip_text = true
	ticker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ticker_label.mouse_filter = Control.MOUSE_FILTER_STOP
	ticker_label.gui_input.connect(_ticker_input)
	ticker.add_child(ticker_label)
	var dismiss := _button("×", _dismiss_ticker)
	dismiss.custom_minimum_size = Vector2(28, 24)
	dismiss.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticker.add_child(dismiss)
	return panel


func _meter(fill_color: Color, hope: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(88, 0)
	var lab := _label("Hope", 12)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(lab)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.14)
	track.custom_minimum_size = Vector2(0, 4)
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 0.5
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)
	box.add_child(track)
	if hope:
		hope_label = lab
		hope_fill = fill
	else:
		dis_label = lab
		dis_fill = fill
	return box


func _side_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _steel_style())
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var title := _label("Residents", 22, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var auto := _button("Auto-staff", _auto_staff)
	auto.custom_minimum_size = Vector2(120, 40)
	head.add_child(auto)
	var shut := _button("×", _toggle_drawer)
	shut.custom_minimum_size = Vector2(40, 40)
	shut.alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(shut)
	box.add_child(head)
	hint = _label("Drag a name onto a room, or tap a room and pick.", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", MUTED)
	box.add_child(hint)
	people_box = VBoxContainer.new()
	people_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_box.add_theme_constant_override("separation", 4)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(people_box)
	box.add_child(scroll)
	return panel


func _toggle_drawer() -> void:
	drawer_open = not drawer_open
	_place_drawer()


func _dismiss_ticker() -> void:
	ticker_dismissed = true
	ticker.visible = false
	_place_chrome()


func _ticker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var warning: Dictionary = game.revolt_warning()
		if not warning.is_empty():
			_open_forecast_at(str(warning.hint), int(warning.level), int(warning.cell))
			return
		_open_forecast()


func _layout() -> void:
	_place_chrome()
	if yard != null:
		yard.on_resize()


func _place_chrome() -> void:
	if res_grid != null:
		res_grid.columns = 6
	if meter_box != null and title_row != null and meter_box.get_parent() != title_row:
		meter_box.get_parent().remove_child(meter_box)
		title_row.add_child(meter_box)
	var short: bool = size.y < 520.0
	var margin := 8.0 if short else 12.0
	var tool_w := 76.0 if short else 64.0
	var tool_h := 48.0 if short else 68.0
	tool_w = maxf(tool_w, 44.0)
	tool_h = maxf(tool_h, 44.0)
	var end_w := 148.0 if short else 176.0
	var end_h := maxf(48.0 if short else 58.0, 44.0)
	end_button.add_theme_font_size_override("font_size", 20 if short else 26)
	var hud_h := 56.0
	if ticker != null and ticker.visible:
		hud_h += 28.0
	if hud != null:
		hud.anchor_left = 0.0
		hud.anchor_right = 1.0
		hud.anchor_top = 0.0
		hud.anchor_bottom = 0.0
		hud.offset_left = 0.0
		hud.offset_right = 0.0
		hud.offset_top = 0.0
		hud.offset_bottom = hud_h
	chrome_bottom = margin + tool_h + 4.0
	if end_button != null:
		end_button.anchor_left = 1.0
		end_button.anchor_right = 1.0
		end_button.anchor_top = 1.0
		end_button.anchor_bottom = 1.0
		end_button.offset_right = -margin
		end_button.offset_left = -margin - end_w
		end_button.custom_minimum_size = Vector2(end_w, end_h)
		end_button.offset_bottom = -margin
		end_button.offset_top = -margin - end_h
	if end_cover != null:
		end_cover.anchor_left = 1.0
		end_cover.anchor_right = 1.0
		end_cover.anchor_top = 1.0
		end_cover.anchor_bottom = 1.0
		end_cover.offset_right = -margin
		end_cover.offset_left = -margin - end_w
		end_cover.offset_bottom = -margin
		end_cover.offset_top = -margin - end_h
	if tray != null:
		tray.anchor_left = 0.0
		tray.anchor_top = 1.0
		tray.anchor_right = 0.0
		tray.anchor_bottom = 1.0
		for child in tray.get_children():
			if child is Control:
				(child as Control).custom_minimum_size = Vector2(tool_w, tool_h)
		tray.offset_left = margin
		tray.offset_top = -margin - tool_h
		tray.offset_right = margin + tool_w * 5.0 + 40.0
		tray.offset_bottom = -margin
	if footer != null:
		footer.anchor_left = 0.0
		footer.anchor_right = 1.0
		footer.anchor_top = 1.0
		footer.anchor_bottom = 1.0
		footer.offset_left = 290.0
		footer.offset_right = -190.0
		footer.offset_top = -margin - 22.0
		footer.offset_bottom = -margin
	_place_drawer()
	_place_card()
	_place_ahead()
	if yard != null:
		yard.on_resize()


func _show_ahead(show: bool) -> void:
	if ahead == null or game == null:
		return
	if not game.pending.is_empty():
		ahead.visible = false
		return
	ahead.visible = show and game.over == ""
	if ahead.visible:
		_fill_ahead()
		_place_ahead()


func _fill_ahead() -> void:
	_wipe(ahead_box)
	var was := on_paper
	on_paper = true
	var title := _label("After this week", 22, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ahead_box.add_child(title)
	var proj: Dictionary = game.dawn_projection()
	for key in STOCK_KEYS:
		var line := _label("%s %d" % [str(key).capitalize(), int(proj.get(key, 0))], 16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ahead_box.add_child(line)
	var hope_line := _label("Hope %d" % int(proj.get("hope", 0)), 16)
	hope_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ahead_box.add_child(hope_line)
	var dis_line := _label("Discontent %d" % int(proj.get("discontent", 0)), 16)
	dis_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ahead_box.add_child(dis_line)
	on_paper = was


func _place_ahead() -> void:
	if ahead == null or not ahead.visible:
		return
	var w := 248.0
	var h := 248.0
	ahead.anchor_left = 0.0
	ahead.anchor_top = 0.0
	ahead.anchor_right = 0.0
	ahead.anchor_bottom = 0.0
	ahead.offset_left = size.x - 16.0 - w
	ahead.offset_right = size.x - 16.0
	ahead.offset_bottom = size.y - chrome_bottom - 8.0
	ahead.offset_top = ahead.offset_bottom - h


func _place_drawer() -> void:
	if side == null:
		return
	side.visible = drawer_open
	if not drawer_open:
		return
	var w := minf(520.0, size.x * 0.56)
	side.offset_left = size.x - w
	side.offset_right = size.x
	side.offset_top = 56.0
	side.offset_bottom = size.y - chrome_bottom

func _build_overlay() -> void:
	ahead = PanelContainer.new()
	ahead.visible = false
	ahead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ahead.add_theme_stylebox_override("panel", _paper_style())
	ahead_box = VBoxContainer.new()
	ahead_box.add_theme_constant_override("separation", 2)
	ahead_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ahead.add_child(ahead_box)
	add_child(ahead)
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _paper_style())
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	card_body = VBoxContainer.new()
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_body.add_theme_constant_override("separation", 8)
	scroll.add_child(card_body)


func _sticky_note(text: String) -> bool:
	return text.begins_with("That ") or text.begins_with("The hall") or text.begins_with("Someone is still")


func _mood_delta(n: int) -> String:
	if game.hope_history.is_empty():
		return "—"
	return _signed(n)


func _place_card() -> void:
	_fit_card()


func _fit_card() -> void:
	if card == null or not dim.visible:
		return
	var margin := 24.0
	var max_w := minf(size.x - margin * 2.0, 560.0)
	var top_limit := 64.0
	if hud != null and hud.size.y > 8.0:
		top_limit = hud.size.y + 8.0
	var bottom_limit := chrome_bottom + 8.0
	var max_h := size.y - top_limit - bottom_limit
	card_body.custom_minimum_size.x = max_w - 36.0
	var left := (size.x - max_w) / 2.0
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = left
	card.offset_top = top_limit
	card.offset_right = left + max_w
	card.offset_bottom = top_limit + max_h
	if not card_fit_queued:
		card_fit_queued = true
		_shrink_card.call_deferred()


func _shrink_card() -> void:
	card_fit_queued = false
	if card == null or card_body == null or not dim.visible:
		return
	var max_w := card.offset_right - card.offset_left
	var top_limit := 64.0
	if hud != null and hud.size.y > 8.0:
		top_limit = hud.size.y + 8.0
	var bottom_limit := chrome_bottom + 8.0
	var max_h := size.y - top_limit - bottom_limit
	var content_h := card_body.size.y
	if content_h < 40.0:
		if not card_fit_queued:
			card_fit_queued = true
			_shrink_card.call_deferred()
		return
	var h := content_h + 52.0
	if h < 96.0:
		if not card_fit_queued:
			card_fit_queued = true
			_shrink_card.call_deferred()
		return
	h = clampf(h, 96.0, max_h)
	var top := clampf((size.y - h) / 2.0, top_limit, top_limit + maxf(0.0, max_h - h))
	card.offset_top = top
	card.offset_bottom = top + h
	card.offset_right = card.offset_left + max_w


func _refresh() -> void:
	if game == null:
		return
	var season := ""
	if not game.active_season.is_empty():
		season = " · %s" % str(game.active_season.id)
	week_label.text = "Week %d%s" % [game.week, season]
	for key in STOCK_KEYS:
		chips[key].value.text = str(int(game.stock.get(key, 0)))
		var delta_text := "—"
		var color := MUTED
		if not game.last_net.is_empty():
			var d := int(game.last_net.get(key, 0))
			delta_text = "+%d" % d if d > 0 else str(d)
			if d > 0:
				color = DELTA_UP
			elif d < 0:
				color = DELTA_DOWN
		chips[key].delta.text = delta_text
		chips[key].delta.add_theme_color_override("font_color", color)
		var outlook: Dictionary = game.resource_outlook(str(key))
		chips[key].box.tooltip_text = "%s. %s" % [str(key).capitalize(), str(outlook.text)]
		var value_color := INK
		if bool(outlook.hit):
			value_color = Color("e0a15a")
		chips[key].value.add_theme_color_override("font_color", value_color)
	power_loss = {}
	for uid in game.rooms_losing_power():
		power_loss[str(uid)] = true
	hope_label.text = "Hope %d  %s" % [game.hope, _mood_delta(game.last_hope_delta)]
	dis_label.text = "Discontent %d  %s" % [game.discontent, _mood_delta(game.last_dis_delta)]
	hope_fill.anchor_right = clampf(float(game.hope) / 100.0, 0.0, 1.0)
	dis_fill.anchor_right = clampf(float(game.discontent) / 100.0, 0.0, 1.0)
	end_button.text = "End turn" if game.over == "" else _ending()
	var burn: Dictionary = game.burn_preview()
	burn_button.disabled = not bool(burn.ok) or game.over != ""
	burn_button.tooltip_text = "Burn salvage" if bool(burn.ok) else "Burn salvage. %s" % str(burn.reason)
	if game.week != ticker_week:
		ticker_week = game.week
		ticker_dismissed = false
		shelved_event = ""
	_sync_shelf()
	var warning: Dictionary = game.revolt_warning()
	var outlook_rows: Array = game.forecasts()
	var line := ""
	if not warning.is_empty():
		line = str(warning.text)
	elif not outlook_rows.is_empty():
		line = str(outlook_rows[0].text)
	ticker_label.text = line
	ticker.visible = line != "" and not ticker_dismissed
	_place_chrome()
	turn_clear = game.over == "" and game.pending.is_empty() and game.forecasts().is_empty() and game.revolt_warning().is_empty()
	_fill_people()
	yard.queue_redraw()
	if not _sticky_note(footer.text):
		footer.text = ""
		footer.visible = false
	_sync_waiting()
	_offer_pending()


func _fill_people() -> void:
	_wipe(people_box)
	for person in game.residents:
		var id := str(person.id)
		var row := PersonRow.new()
		row.person_id = id
		row.person_name = str(person.name)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(_portrait_box(id, 52))
		row.add_child(line)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 1)
		var traits: PackedStringArray = []
		for trait_name in person.traits:
			traits.append(str(trait_name))
		var trait_line := ", ".join(traits) if not traits.is_empty() else "no trait"
		var name_label := _label(str(person.name), 16)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(name_label)
		var skill_label := _label(_skill_line(person), 14)
		skill_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		skill_label.clip_text = false
		skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_label.add_theme_color_override("font_color", Color(INK.r, INK.g, INK.b, 0.8))
		box.add_child(skill_label)
		var where := _label("%s · %s" % [trait_line, _where(id)], 14)
		where.autowrap_mode = TextServer.AUTOWRAP_OFF
		where.clip_text = false
		where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		where.add_theme_color_override("font_color", MUTED)
		box.add_child(where)
		line.add_child(box)
		people_box.add_child(row)


func _skill_line(person: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in ["care", "fight", "labor", "talk", "tech"]:
		if person.skills.has(key):
			bits.append("%s %d" % [str(key).capitalize(), int(person.skills[key])])
	return " · ".join(bits)


func _where(id: String) -> String:
	for room in game.rooms:
		for sid in room.staff:
			if str(sid) == id:
				return str(game.catalog.rooms[room.type].name)
	for wid in game._locked_ids():
		if str(wid) == id:
			return "On a crew"
	var person: Dictionary = game.people[id]
	if int(person.sick) > 0:
		return "Sick"
	if int(person.absent) > 0:
		return "Away"
	return "Unassigned"


func _choice_shelved() -> bool:
	if game == null or game.pending.is_empty() or shelved_event == "":
		return false
	return str(game.front_event().get("id", "")) == shelved_event


func _sync_shelf() -> void:
	if game.pending.is_empty():
		shelved_event = ""
	elif shelved_event != "" and str(game.front_event().get("id", "")) != shelved_event:
		shelved_event = ""


func _sync_waiting() -> void:
	_sync_shelf()
	var waiting := game.over == "" and not game.pending.is_empty()
	end_button.disabled = game.over != "" or waiting
	if end_cover != null:
		end_cover.mouse_filter = Control.MOUSE_FILTER_STOP if waiting else Control.MOUSE_FILTER_IGNORE
		end_cover.tooltip_text = WAITING if waiting else ""
	if waiting:
		end_button.tooltip_text = WAITING
		end_button.add_theme_stylebox_override("disabled", _brass_style(false, false))
	elif game.over != "":
		end_button.tooltip_text = _ending()
	else:
		end_button.tooltip_text = "End the week"


func _offer_pending() -> void:
	if game.over != "" or game.pending.is_empty():
		return
	if _choice_shelved():
		return
	if deck.top_token() == "dawn":
		return
	_show_dawn()


func _end_cover_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not game.pending.is_empty():
			_show_dawn()
			end_cover.accept_event()


func _end_turn() -> void:
	if game.over != "":
		return
	if not game.pending.is_empty():
		_show_dawn()
		return
	game.end_week()
	_refresh()
	if game.over == "":
		_show_dawn()
	else:
		_show_ending()


func _auto_staff() -> void:
	game.apply({"kind": "staff"})
	_refresh()


func _chip_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_resource(key)


func _show_resource(key: String) -> void:
	if not _claim(ModalDeck.AMBIENT, "resource", _show_resource.bind(key)):
		return
	var info: Dictionary = game.resource_outlook(key)
	_open_card(key.capitalize())
	_body(str(info.text))
	card_body.add_child(_button("Close", _close_card))


func _ask_pump() -> void:
	var lines: PackedStringArray = [
		"%s and %d power." % [Words.count(int(game.bal.pump_materials), "material"), int(game.bal.pump_power)],
	]
	var why := game.pump_reason()
	if why != "":
		lines.append(why)
	_confirm("Pump the lower level?", lines, why == "", {"kind": "pump"})


func _ask_quarantine() -> void:
	var lines: PackedStringArray = ["Sick rooms stay shut for the week. Hope takes a knock."]
	if not game.can_quarantine():
		lines.append("Quarantine is only there while the cough season is on, and only once.")
	_confirm("Quarantine?", lines, game.can_quarantine(), {"kind": "quarantine"})


func _ask_rally() -> void:
	var why := game.rally_reason()
	var lines: PackedStringArray = ["The hall pulls the platform back from a revolt. Discontent %+d. Hope %+d." % [int(game.bal.rally_discontent), int(game.bal.rally_hope)]]
	if why != "":
		lines.append(why)
	_confirm("Hold a rally?", lines, why == "", {"kind": "rally"})


func _ask_law(law_id: String) -> void:
	var defin: Dictionary = game.catalog.laws[law_id]
	var why := game.enact_reason(law_id)
	var lines: PackedStringArray = [_law_blurb(defin)]
	if why != "":
		lines.append(why)
	_confirm(str(defin.name) + "?", lines, why == "", {"kind": "law", "law": law_id})


func _ask_repeal(law_id: String) -> void:
	var defin: Dictionary = game.catalog.laws[law_id]
	var why := game.repeal_reason(law_id)
	var lines: PackedStringArray = ["Take %s off the books." % str(defin.name)]
	if why != "":
		lines.append(why)
	_confirm("Repeal %s?" % str(defin.name), lines, why == "", {"kind": "repeal", "law": law_id})


func _ask_burn() -> void:
	var info := game.burn_preview()
	var lines: PackedStringArray = [
		"%s %s %d power this week. Hope %+d." % [Words.count(int(info.materials), "material"), "becomes" if int(info.materials) == 1 else "become", int(info.power), int(info.hope)],
	]
	if str(info.reason) != "":
		lines.append(str(info.reason))
	_confirm("Burn salvage?", lines, bool(info.ok), {"kind": "burn"})


func _open_forecast() -> void:
	var rows: Array = game.forecasts()
	if rows.is_empty():
		return
	var row: Dictionary = rows[0]
	_open_forecast_at(str(row.hint), int(row.level), int(row.cell))


func _open_warning() -> void:
	var warning: Dictionary = game.revolt_warning()
	if warning.is_empty():
		return
	_open_forecast_at(str(warning.hint), int(warning.level), int(warning.cell))


func _open_forecast_at(hint: String, level: int, cell: int) -> void:
	if hint == "rally":
		_ask_rally()
		return
	if hint == "quarantine":
		_ask_quarantine()
		return
	if hint.begins_with("law:"):
		_ask_law(hint.trim_prefix("law:"))
		return
	if hint.begins_with("repeal:"):
		_ask_repeal(hint.trim_prefix("repeal:"))
		return
	if hint.begins_with("staff:"):
		var type := hint.trim_prefix("staff:")
		for room in game.rooms:
			if str(room.type) == type:
				_show_room(str(room.uid))
				return
	if level >= 0 and cell >= 0:
		_tap_cell(level, cell)
		return
	_close_card()


func _show_power() -> void:
	if not _claim(ModalDeck.AMBIENT, "power", _show_power):
		return
	_open_card("Power order")
	_body("Higher rooms keep their power when it runs short. The rest go dark.")
	var index := 0
	for uid in game.power_order:
		var room = game._room(str(uid))
		if room == null:
			continue
		index += 1
		var name := str(game.catalog.rooms[room.type].name)
		_body("%d. %s" % [index, name])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_button("Up", _nudge_power.bind(str(uid), true)))
		row.add_child(_button("Down", _nudge_power.bind(str(uid), false)))
		card_body.add_child(row)
	card_body.add_child(_button("Close", _close_card))


func _nudge_power(uid: String, up: bool) -> void:
	game.apply({"kind": "power", "room": uid, "up": up})
	_show_power()
	_refresh()


func _tap_cell(level: int, cell: int) -> void:
	var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
	if str(spot.room) != "":
		_show_room(str(spot.room))
		return
	if not game.dig.is_empty() and int(game.dig.level) == level and int(game.dig.cell) == cell:
		var digging: PackedStringArray = [
			"%s left." % Words.count(int(game.dig.left), "week"),
			"%s on the crew." % Words.count(game.dig.workers.size(), "person", "people"),
		]
		_confirm("Dig in progress", digging, false, {})
		return
	if not game.build.is_empty() and int(game.build.level) == level and int(game.build.cell) == cell:
		var name := str(game.catalog.rooms[str(game.build.type)].name)
		var building: PackedStringArray = ["%s left." % Words.count(int(game.build.left), "week")]
		_confirm(name, building, false, {})
		return
	if not bool(spot.dug):
		var info := game.dig_preview(level, cell)
		var lines: PackedStringArray = [
			Words.count(int(info.turns), "week"),
			Words.count(int(info.workers), "worker"),
			Words.count(int(info.materials), "material"),
		]
		if str(info.reason) != "":
			lines.append(str(info.reason))
		_confirm("Dig this cell?", lines, bool(info.ok), {"kind": "dig", "level": level, "cell": cell})
		return
	_show_build(level, cell)


func _drop_person(person_id: String, uid: String) -> void:
	var info := game.assign_preview(person_id, uid)
	drawer_open = true
	if not bool(info.ok):
		var room = game._room(uid)
		if room != null and yard != null:
			yard.shake_cell = Vector2i(int(room.level), int(room.cell))
			yard.shake_until = Time.get_ticks_msec() + 560
			yard.shake_px = 0.0
			yard.shake_reason = str(info.reason)
			yard.queue_redraw()
		_place_drawer()
		return
	if yard != null:
		yard.shake_cell = Vector2i(-1, -1)
		yard.shake_reason = ""
		yard.shake_px = 0.0
	game.apply({"kind": "assign", "person": person_id, "room": uid})
	_refresh()


func _show_build(level: int, cell: int) -> void:
	if not _claim(ModalDeck.AMBIENT, "build", _show_build.bind(level, cell)):
		return
	_open_card("Build here")
	_body("Level %d, cell %d. An open floor." % [level + 1, cell + 1])
	for type in game.buildable_types():
		var info := game.build_preview(str(type), level, cell)
		var text := "%s — %s, %s, %s, power %d" % [
			str(info.name), Words.count(int(info.materials), "material"), Words.count(int(info.turns), "week"), Words.count(int(info.workers), "worker"), int(info.power)]
		if not bool(info.ok) and str(info.reason) != "":
			text += " — " + str(info.reason)
		var build_button := _button(text, _confirm_build.bind(str(type), level, cell))
		if not bool(info.ok):
			build_button.custom_minimum_size.y = 72
		card_body.add_child(build_button)
	card_body.add_child(_button("Back", _close_card))


func _confirm_build(type: String, level: int, cell: int) -> void:
	var info := game.build_preview(type, level, cell)
	var lines: PackedStringArray = [
		"%s, %s, %s." % [Words.count(int(info.materials), "material"), Words.count(int(info.turns), "week"), Words.count(int(info.workers), "worker")],
		"Power use once it is running: %d." % int(info.power),
	]
	if str(info.reason) != "":
		lines.append(str(info.reason))
	_confirm("Build %s?" % str(info.name), lines, bool(info.ok), {
		"kind": "build", "type": type, "level": level, "cell": cell,
	})


func _room_lead(detail: Dictionary) -> String:
	var bits: PackedStringArray = []
	for out in detail.outputs:
		bits.append("%s +%d / week" % [str(out.key).capitalize(), int(out.amount)])
	bits.append("%d of %d crew" % [detail.staff.size(), int(detail.staff_max)])
	bits.append("uses %d power" % int(detail.power))
	return " · ".join(bits)


func _show_room(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	if detail.is_empty():
		return
	if not _claim(ModalDeck.AMBIENT, "room", _show_room.bind(uid)):
		return
	_open_card(str(detail.name))
	if notice != "":
		_body(notice)
		notice = ""
	_body(_room_lead(detail))
	if bool(detail.offline):
		_body("Offline.")
	for member in detail.staff:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_portrait_box(str(member.id), 44))
		var staff_line := "%s · %s %d" % [str(member.name), str(detail.skill), int(member.skill)]
		if str(member.traits) != "":
			staff_line += " · " + str(member.traits)
		var lab := _label(staff_line, 15)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var off := _button("Off", _unassign.bind(str(member.id), uid))
		off.custom_minimum_size = Vector2(72, 48)
		row.add_child(off)
		card_body.add_child(row)
	if int(detail.staff_max) > 0:
		var picks: Array = []
		var blocked := ""
		for row in game.candidates_for(uid):
			if bool(row.here):
				continue
			var preview: Dictionary = game.assign_preview(str(row.id), uid)
			if not bool(preview.ok):
				blocked = str(preview.reason)
				continue
			picks.append(row)
		if picks.is_empty():
			if blocked != "":
				_body(blocked)
		else:
			_body("Tap a name to assign.")
			for row in picks:
				card_body.add_child(_button(str(row.name), _assign_person.bind(str(row.id), uid)))
	if str(detail.skill) != "":
		_body("%s from crew skill." % _mult(float(detail.multiplier)))
	var up: Dictionary = game.upgrade_preview(uid)
	var up_label := "Upgrade"
	var up_choice := {}
	if str(up.name) != "":
		up_label = "Upgrade: %s" % str(up.name).replace("_", " ")
		if int(up.materials) != 0:
			up_choice = {"cost": {"materials": int(up.materials)}}
	card_body.add_child(_choice_button(up_label, up_choice, _confirm_upgrade.bind(uid)))
	card_body.add_child(_button("Demolish", _confirm_demolish.bind(uid)))
	if str(detail.type) == "meeting_hall":
		card_body.add_child(_button("Laws", _show_laws))


func _show_assign(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	if not _claim(ModalDeck.AMBIENT, "assign", _show_assign.bind(uid)):
		return
	_open_card("Assign to %s" % str(detail.name))
	var skill_name := str(detail.skill)
	_body("Best %s first. The number is that skill." % skill_name)
	var filter := LineEdit.new()
	filter.placeholder_text = "Filter names"
	filter.add_theme_color_override("font_color", PAPER_INK)
	filter.add_theme_color_override("font_placeholder_color", PAPER_MUTED)
	if body_font != null:
		filter.add_theme_font_override("font", body_font)
	filter.custom_minimum_size = Vector2(0, 44)
	filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	filter.text_changed.connect(_fill_assign.bind(uid, skill_name, list))
	card_body.add_child(filter)
	card_body.add_child(list)
	_fill_assign(uid, skill_name, list, "")
	card_body.add_child(_button("Back", _show_room.bind(uid)))


func _fill_assign(uid: String, skill_name: String, list: VBoxContainer, query: String) -> void:
	_wipe(list)
	var needle := query.strip_edges().to_lower()
	var shown := 0
	for row in game.candidates_for(uid):
		var person_name := str(row.name)
		if needle != "" and not person_name.to_lower().contains(needle):
			continue
		shown += 1
		var text := "%s · %s %d" % [person_name, skill_name, int(row.skill)]
		if str(row.traits) != "":
			text += " · " + str(row.traits)
		if bool(row.here):
			text += " · here"
		list.add_child(_button(text, _assign_person.bind(str(row.id), uid)))
	if shown == 0:
		var empty := _label("No one matches.", 15)
		list.add_child(empty)


func _assign_person(person_id: String, uid: String) -> void:
	var info := game.assign_preview(person_id, uid)
	if not bool(info.ok):
		notice = str(info.reason)
		_show_room(uid)
		return
	game.apply({"kind": "assign", "person": person_id, "room": uid})
	_refresh()
	_show_room(uid)


func _unassign(person_id: String, uid: String) -> void:
	game.apply({"kind": "unassign", "person": person_id})
	_refresh()
	_show_room(uid)


func _confirm_upgrade(uid: String) -> void:
	var info := game.upgrade_preview(uid)
	var lines: PackedStringArray = []
	if str(info.name) != "":
		lines.append("%s for %s." % [str(info.name), Words.count(int(info.materials), "material")])
	if str(info.reason) != "":
		lines.append(str(info.reason))
	if lines.is_empty():
		lines.append("Nothing to upgrade.")
	_confirm("Upgrade?", lines, bool(info.ok), {"kind": "upgrade", "room": uid})


func _confirm_demolish(uid: String) -> void:
	var info := game.demolish_preview(uid)
	var refund_n := int(info.refund)
	var lines: PackedStringArray = ["%s %s back." % [Words.count(refund_n, "material"), "comes" if refund_n == 1 else "come"]]
	if str(info.reason) != "":
		lines.append(str(info.reason))
	_confirm("Pull down %s?" % str(info.name), lines, bool(info.ok), {"kind": "demolish", "room": uid})


func _show_laws() -> void:
	if not _claim(ModalDeck.AMBIENT, "laws", _show_laws):
		return
	_open_card("Laws")
	if not game._room_ready("meeting_hall"):
		_body("Staff the meeting hall. The hall can pass one law, then it waits %s." % Words.count(int(game.bal.law_cooldown), "week"))
	elif game.law_lock > 0:
		_body("A law was just passed. The next one is %s away." % Words.count(game.law_lock, "week"))
	else:
		_body("One law this sitting. The next sitting is %s later." % Words.count(int(game.bal.law_cooldown), "week"))
	for id in game.catalog.laws:
		var defin: Dictionary = game.catalog.laws[id]
		_heading(str(defin.name))
		_body(_law_blurb(defin))
		if game.laws_on.has(id):
			_body("In force.")
		else:
			var why := game.enact_reason(str(id))
			var label := "Enact %s" % str(defin.name)
			if why != "":
				label = "%s — %s" % [str(defin.name), why]
			var enact := _button(label, _enact.bind(str(id)))
			enact.disabled = why != ""
			if why != "":
				enact.custom_minimum_size.y = 72
			card_body.add_child(enact)
	card_body.add_child(_button("Close", _close_card))


func _enact(law_id: String) -> void:
	if not game.apply({"kind": "law", "law": law_id}):
		footer.text = "The hall did not pass that."
		footer.visible = true
		_show_laws()
		return
	_refresh()
	_show_laws()


func _law_blurb(defin: Dictionary) -> String:
	var bits: PackedStringArray = []
	if defin.has("power"):
		bits.append("The charter adds %d power." % int(defin.power))
	if defin.has("dig_faster"):
		bits.append("Digs finish %s sooner." % Words.count(int(defin.dig_faster), "week"))
	if defin.has("food_mult"):
		bits.append("Food use ×%s." % str(defin.food_mult))
	if defin.has("prod_mult"):
		bits.append("Room output ×%s." % str(defin.prod_mult))
	if defin.has("hope_week"):
		bits.append("Hope %+d each week." % int(defin.hope_week))
	if defin.has("discontent_week"):
		bits.append("Discontent %+d each week." % int(defin.discontent_week))
	if defin.has("tokens_week"):
		bits.append("Tokens %+d each week." % int(defin.tokens_week))
	if defin.has("influence_mult"):
		bits.append("Influence ×%s." % str(defin.influence_mult))
	if defin.has("synod"):
		bits.append("Synod %+d when someone Devout is home." % int(defin.synod))
	if defin.has("devout_hope"):
		bits.append("A Devout resident adds %+d Hope." % int(defin.devout_hope))
	if defin.has("squad_bonus"):
		bits.append("The platform guard gains %d." % int(defin.squad_bonus))
	if defin.has("sick_chance"):
		bits.append("Crews can fall sick (%.0f%%)." % (float(defin.sick_chance) * 100.0))
	if defin.has("materials_on_enact"):
		bits.append("Materials %+d when passed." % int(defin.materials_on_enact))
	if defin.has("hope_on_enact"):
		bits.append("Hope %+d when passed." % int(defin.hope_on_enact))
	if defin.has("discontent_on_enact"):
		bits.append("Discontent %+d when passed." % int(defin.discontent_on_enact))
	if defin.has("opinion_on_enact"):
		bits.append("Every rival's opinion %+d." % int(defin.opinion_on_enact))
	return " ".join(bits)


func _show_dawn() -> void:
	shelved_event = ""
	if not _claim(ModalDeck.NARRATIVE, "dawn", _show_dawn):
		return
	if footer.text == WAITING:
		footer.text = ""
		footer.visible = false
	var lines := _morning_lines()
	if game.pending.is_empty():
		_open_card("Dawn, week %d" % game.week)
		_intent_row(lines)
		_morning_notes(lines)
		_dawn_alert()
		_body("No one is waiting on a decision.")
		card_body.add_child(_button("To the platform", _close_card))
		return
	var ev: Dictionary = game.front_event()
	_open_card(str(ev.title), false)
	var banner := _event_banner(str(ev.id))
	if banner != null:
		card_body.add_child(banner)
		card_body.move_child(banner, 0)
	_who_row(str(ev.get("who", "")))
	_body(str(ev.text))
	_intent_row(lines)
	_morning_notes(lines)
	_dawn_alert()
	for choice in ev.choices:
		var pick := _choice_button(str(choice.label), choice, _pick_event.bind(str(ev.id), str(choice.id)))
		if not game.afford_choice(choice):
			var why := game.shortage_text(choice.get("cost", {}))
			if why == "":
				why = "That cost cannot be paid."
			pick.disabled = true
			pick.tooltip_text = why
			_body(why)
		card_body.add_child(pick)
	if game.pending.size() > 1:
		_body("%s waiting after this one." % Words.count(game.pending.size() - 1, "other", "others"))
	var later := _button("Not now", _close_card)
	_style_choice(later)
	card_body.add_child(later)


func _dawn_alert() -> void:
	var warning: Dictionary = game.revolt_warning()
	if not warning.is_empty():
		var warn := _button(str(warning.text), _open_forecast_at.bind(str(warning.hint), int(warning.level), int(warning.cell)))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_body.add_child(warn)
		return
	var rows: Array = game.forecasts()
	if rows.is_empty():
		return
	var row: Dictionary = rows[0]
	var forecast := _button(str(row.text), _open_forecast_at.bind(str(row.hint), int(row.level), int(row.cell)))
	forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.add_child(forecast)


func _morning_notes(lines: PackedStringArray) -> void:
	var any := false
	for line in lines:
		if line.begins_with("INTENT"):
			continue
		any = true
		_body(line)
	if not any and game.pending.is_empty():
		_body("No season warning, and no word from the tunnels.")


func _intent_row(lines: PackedStringArray) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var count := 0
	for line in lines:
		if not line.begins_with("INTENT "):
			continue
		var sentence := line.substr(7)
		var kind := "hold"
		var low := sentence.to_lower()
		if "squad" in low:
			kind = "squad"
		elif "buy" in low or "sympathy" in low:
			kind = "buy"
		elif "secur" in low:
			kind = "secure"
		elif "demand" in low:
			kind = "demand"
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.tooltip_text = sentence
		var icon := Glyph.new()
		icon.kind = kind
		icon.ink = PAPER_INK
		icon.custom_minimum_size = Vector2(18, 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
		var lab := _label(sentence, 16)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_child(lab)
		row.add_child(chip)
		count += 1
	if count > 0:
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(row)


func _event_banner(event_id: String) -> TextureRect:
	var path := ProjectSettings.globalize_path("res://assets/events/%s.webp" % event_id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.get_width() <= 0:
		return null
	var banner := TextureRect.new()
	banner.texture = ImageTexture.create_from_image(image)
	banner.custom_minimum_size = Vector2(0, 148)
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return banner


func _morning_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for entry in game.log:
		var w := int(entry.week)
		var text := str(entry.text)
		if w == game.week and _starts(text, ["INTENT", "SEASON", "ULTIMATUM", "PRESSURE", "No warning"]):
			lines.append(text)
		elif w == game.week - 1 and bool(entry.important) and _starts(text, ["SHORT", "ROT", "AGENT", "SEASON", "JOIN", "ULTIMATUM", "FIND"]):
			lines.append(text)
	return lines


func _starts(text: String, prefixes: Array) -> bool:
	for prefix in prefixes:
		if text.begins_with(str(prefix)):
			return true
	return false


func _pick_event(event_id: String, choice_id: String) -> void:
	var before := str(game.front_event().get("id", ""))
	if not game.apply({"kind": "event", "event_id": event_id, "choice_id": choice_id}):
		footer.text = "That choice did not take."
		footer.visible = true
		return
	_refresh()
	_advance_dawn(before)


func _dismiss_dawn() -> void:
	var before := str(game.front_event().get("id", ""))
	if before != "":
		game.dismiss_front()
	_refresh()
	_advance_dawn(before)


func _advance_dawn(before: String) -> void:
	if game.pending.is_empty():
		_close_card()
		return
	if str(game.front_event().get("id", "")) == before:
		_close_card()
		return
	_show_dawn()


func _show_ending() -> void:
	if not _claim(ModalDeck.NARRATIVE, "ending", _show_ending):
		return
	_open_card(_ending())
	_body("Week %d. Food %d, air %d, power %d, materials %d." % [
		game.week, int(game.stock.food), int(game.stock.air), int(game.stock.power), int(game.stock.materials)])
	_body("Hope %d. Discontent %d. %s." % [game.hope, game.discontent, Words.count(game.residents.size(), "person", "people")])
	card_body.add_child(_button("Close", _close_card))


func _ending() -> String:
	match game.over:
		"time":
			return "Forty weeks. The yard is still yours."
		"revolt":
			return "The platform turned."
		"hope":
			return "Hope ran out."
		"collapse":
			return "The stores gave out."
		"capital":
			return "The capital was lost."
		"error":
			return "The week broke."
		_:
			return "The run is over."


func _mult(n: float) -> String:
	if is_equal_approx(n, round(n)):
		return "×%d" % int(round(n))
	if is_equal_approx(n * 10.0, round(n * 10.0)):
		return "×%.1f" % n
	return "×%.2f" % n


func _style_choice(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	if display_font != null:
		button.add_theme_font_override("font", display_font)
	button.add_theme_color_override("font_color", PAPER_INK)
	button.add_theme_color_override("font_hover_color", PAPER_INK)
	button.add_theme_color_override("font_pressed_color", PAPER_INK)
	button.add_theme_color_override("font_disabled_color", PAPER_MUTED)


func _choice_button(label: String, choice: Dictionary, cb: Callable) -> Button:
	var button := _button(label, cb)
	_style_choice(button)
	var marks := _marks(choice)
	if marks.get_child_count() == 0:
		return button
	var pad := 24 + marks.get_child_count() * 52
	var faces := {
		"normal": _button_face(false, false),
		"hover": _button_face(false, true),
		"pressed": _button_face(true, false),
		"disabled": _button_face(false, false),
	}
	for state in faces:
		var face: StyleBoxFlat = faces[state]
		face.content_margin_left = 12
		face.content_margin_right = pad
		face.content_margin_top = 8
		face.content_margin_bottom = 8
		button.add_theme_stylebox_override(state, face)
	marks.anchor_left = 1.0
	marks.anchor_right = 1.0
	marks.anchor_top = 0.0
	marks.anchor_bottom = 1.0
	marks.offset_left = float(-pad + 8)
	marks.offset_right = -10.0
	marks.offset_top = 0.0
	marks.offset_bottom = 0.0
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	button.clip_contents = true
	button.add_child(marks)
	return button


func _marks(choice: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_END
	if choice.has("cost"):
		for key in choice.cost:
			_add_mark(row, str(key), -int(choice.cost[key]))
	for key in ["food", "air", "power", "materials", "tokens", "influence", "hope", "discontent"]:
		if choice.has(key):
			_add_mark(row, key, int(choice[key]))
	return row


func _add_mark(row: HBoxContainer, key: String, amount: int) -> void:
	if amount == 0:
		return
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var icon := Glyph.new()
	icon.kind = key
	icon.ink = PAPER_INK if on_paper else INK
	icon.custom_minimum_size = Vector2(14, 14)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var lab := _label(_signed(amount), 14)
	lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lab)
	row.add_child(box)


func _choice_bits(choice: Dictionary) -> String:
	var bits: PackedStringArray = []
	if choice.has("cost"):
		for key in choice.cost:
			bits.append("%s %s" % [str(choice.cost[key]), str(key)])
	for key in ["food", "air", "power", "materials", "tokens", "influence", "hope", "discontent"]:
		if choice.has(key):
			bits.append("%s %+d" % [key, int(choice[key])])
	return ", ".join(bits)


func _confirm(heading: String, lines: PackedStringArray, ok: bool, action: Dictionary) -> void:
	if not _claim(ModalDeck.AMBIENT, "confirm", _confirm.bind(heading, lines, ok, action)):
		return
	_open_card(heading)
	for line in lines:
		_body(line)
	var go := _button("Confirm", _do_confirm.bind(action))
	go.disabled = not ok or action.is_empty()
	if not ok and not lines.is_empty():
		go.text = lines[lines.size() - 1]
		go.custom_minimum_size.y = 72
	card_body.add_child(go)
	card_body.add_child(_button("Back", _close_card))


func _do_confirm(action: Dictionary) -> void:
	if action.is_empty() or not game.apply(action):
		footer.text = "That did not happen."
		footer.visible = true
		_close_card()
		_refresh()
		return
	_close_card()
	_refresh()


func _claim(priority: int, token: String, restore: Callable) -> bool:
	if priority == ModalDeck.AMBIENT:
		ambient_restore = restore
	deck.push(priority, token)
	return deck.top_token() == token


func _open_card(heading: String, with_close: bool = true) -> void:
	_show_ahead(false)
	on_paper = true
	_wipe(card_body)
	dim.visible = true
	var row := HBoxContainer.new()
	var lab := _label(heading, 28, true)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	if with_close:
		var close := _button("Close", _close_card)
		close.custom_minimum_size = Vector2(96, 44)
		close.alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(close)
	card_body.add_child(row)
	_fit_card()
	_fit_card.call_deferred()


func _close_card() -> void:
	var token := deck.top_token()
	if token == "dawn" and game != null and not game.pending.is_empty():
		shelved_event = str(game.front_event().get("id", ""))
	deck.pop()
	if deck.top_priority() == ModalDeck.AMBIENT and ambient_restore.is_valid():
		ambient_restore.call()
		_sync_waiting()
		return
	on_paper = false
	dim.visible = false
	_wipe(card_body)
	_sync_waiting()


func _heading(text: String) -> void:
	card_body.add_child(_label(text, 26, true))


func _body(text: String) -> void:
	var lab := _label(text, 15)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.add_child(lab)


func _label(text: String, size: int, display: bool = false) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", PAPER_INK if on_paper else INK)
	if display and display_font != null:
		lab.add_theme_font_override("font", display_font)
	elif body_font != null:
		lab.add_theme_font_override("font", body_font)
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lab.clip_text = false
	return lab


func _button(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 20)
	if display_font != null:
		button.add_theme_font_override("font", display_font)
	button.add_theme_color_override("font_color", PAPER_INK if on_paper else INK)
	button.add_theme_color_override("font_disabled_color", PAPER_MUTED if on_paper else MUTED)
	button.add_theme_stylebox_override("normal", _button_face(false, false))
	button.add_theme_stylebox_override("hover", _button_face(false, true))
	button.add_theme_stylebox_override("pressed", _button_face(true, false))
	button.add_theme_stylebox_override("disabled", _button_face(false, false))
	button.custom_minimum_size.y = 48
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(cb)
	return button


func _button_face(pressed: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if on_paper:
		style.bg_color = PAPER_BUTTON_DOWN if pressed else (PAPER_BUTTON_HOVER if hover else PAPER_BUTTON)
		style.border_color = PAPER_EDGE
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.2, 0.21, 0.23) if pressed else Color(0.14, 0.15, 0.17, 0.96)
		style.border_color = Color(1, 1, 1, 0.16)
		style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(3)
	return style


func _brass_style(pressed: bool, enabled: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if enabled:
		style.bg_color = Color("a56b22") if pressed else Color("e2a63a")
	else:
		style.bg_color = Color("c4a15c")
	style.border_color = Color("3a2610")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(3)
	return style


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER_EDGE
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	return style


func _steel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = STEEL
	style.border_color = Color(1, 1, 1, 0.08)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(2)
	return style


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	return style


func _wipe(node: Node) -> void:
	while node.get_child_count() > 0:
		var child := node.get_child(0)
		node.remove_child(child)
		child.queue_free()


func _signed(n: int) -> String:
	if n > 0:
		return "+%d" % n
	return str(n)


func _room_uid(type: String) -> String:
	for room in game.rooms:
		if str(room.type) == type:
			return str(room.uid)
	return ""


func _shots() -> void:
	await _settle(Vector2i(1280, 720))
	_close_card()
	await _frame()
	await _frame()
	var station_px := yard._station_rect().size.x * yard.zoom
	var ratio := station_px / maxf(size.x, 1.0)
	print("STATION width %.3f" % ratio)
	_save("ux_opening")
	if ratio < 0.85 or ratio > 0.90:
		get_tree().quit(1)
		return
	_show_dawn()
	await _frame()
	await _frame()
	_save("ux_event")
	_close_card()
	drawer_open = true
	_place_drawer()
	await _frame()
	_save("ux_residents")
	get_tree().quit(0)


func _card_title() -> String:
	if card_body == null:
		return ""
	for child in card_body.get_children():
		if child is HBoxContainer:
			for inner in child.get_children():
				if inner is Label:
					return inner.text
	return ""


func _first_open_floor() -> Vector2i:
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if bool(spot.dug) and str(spot.room) == "":
				return Vector2i(level, cell)
	return Vector2i(2, 0)


func _shot_drag() -> bool:
	var donor = null
	for room in game.rooms:
		var cap := int(game.catalog.rooms[str(room.type)].get("staff_max", 0))
		if cap > 0 and room.staff.size() > 0:
			donor = room
			break
	if donor == null:
		print("DRAG: FAIL no staffed room")
		return false
	var person_id := str(donor.staff[0])
	game.apply({"kind": "unassign", "person": person_id})
	_refresh()
	var full = null
	for room in game.rooms:
		var cap := int(game.catalog.rooms[str(room.type)].get("staff_max", 0))
		if cap > 0 and room.staff.size() >= cap:
			full = room
			break
	if full == null:
		print("DRAG: FAIL no full room")
		return false
	var reason := str(game.assign_preview(person_id, str(full.uid)).reason)
	if reason == "" or bool(game.assign_preview(person_id, str(full.uid)).ok):
		print("DRAG: FAIL full room accepted the drop")
		return false
	yard.drag_id = person_id
	yard.drag_lock = true
	yard.shake_cell = Vector2i(int(full.level), int(full.cell))
	yard.shake_until = Time.get_ticks_msec() + 60000
	yard.shake_px = 8.0
	yard.shake_reason = reason
	drawer_open = true
	_place_drawer()
	yard.queue_redraw()
	print("DRAG person=%s reason=%s" % [person_id, reason])
	return true


func _sample_dig() -> void:
	for level in 3:
		for cell in 6:
			var info: Dictionary = game.dig_preview(level, cell)
			if bool(info.ok):
				game.apply({"kind": "dig", "level": level, "cell": cell})
				return


func _mark_hover_diggable() -> void:
	if not game.dig.is_empty():
		yard.hover = Vector2i(int(game.dig.level), int(game.dig.cell))
		return
	for level in 3:
		for cell in 6:
			if not game.dig.is_empty() and int(game.dig.level) == level and int(game.dig.cell) == cell:
				continue
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if str(spot.room) != "" or bool(spot.dug):
				continue
			if game._beside_dug(spot):
				yard.hover = Vector2i(level, cell)
				return


func _zoom_pair(a: String, b: String) -> void:
	var geo := yard._geo()
	var best := -1.0
	var rect := Rect2()
	for left in game.rooms:
		if str(left.type) != a:
			continue
		if left.staff.is_empty():
			continue
		for right in game.rooms:
			if str(right.type) != b or right.staff.is_empty():
				continue
			var box := yard._rect(geo, int(left.level), int(left.cell)).merge(yard._rect(geo, int(right.level), int(right.cell)))
			var area := box.size.x * box.size.y
			if best < 0.0 or area < best:
				best = area
				rect = box
	if best < 0.0:
		return
	yard._zoom_to_rect(rect.grow(6.0))


func _zoom_room(type: String) -> void:
	for room in game.rooms:
		if str(room.type) == type:
			yard._zoom_to(int(room.level), int(room.cell))
			return


func _settle(window_size: Vector2i) -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	win.content_scale_size = window_size
	win.mode = Window.MODE_WINDOWED
	win.size = window_size
	for _i in 4:
		await get_tree().process_frame
	_layout()
	await _frame()


func _frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(shot_name: String) -> void:
	var dir := ProjectSettings.globalize_path("res://shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var path := dir + "/%s.png" % shot_name
	var err := img.save_png(path)
	print("SHOT %s %dx%d ui %s win %s err %s" % [shot_name, img.get_width(), img.get_height(), size, get_window().size, err])


class Backdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.09))
		var band := Rect2(0, size.y * 0.22, size.x, size.y * 0.42)
		draw_rect(band, Color(0.28, 0.13, 0.07, 0.55))
		draw_rect(Rect2(0, size.y * 0.58, size.x, size.y * 0.42), Color(0.04, 0.05, 0.06, 0.45))
		var tile := Color(1, 1, 1, 0.035)
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), tile, 1.0)
			y += 22.0
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.02), 1.0)
			x += 46.0


class PersonRow extends PanelContainer:
	var person_id := ""
	var person_name := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06)
		style.set_content_margin_all(6)
		style.set_corner_radius_all(4)
		add_theme_stylebox_override("panel", style)

	func _get_drag_data(_at_position: Vector2):
		var preview := Label.new()
		preview.text = person_name
		preview.add_theme_color_override("font_color", Color("efe6d2"))
		set_drag_preview(preview)
		return {"person": person_id}


class Yard extends Control:
	var station
	const BAND := 12.0
	const ART := {
		"hydroponics": "res://assets/rooms/room_hydroponics.webp",
		"generator": "res://assets/rooms/room_generator.webp",
		"quarters": "res://assets/rooms/room_quarters.webp",
		"air_filter": "res://assets/rooms/room_air_filter.webp",
		"workshop": "res://assets/rooms/room_workshop.webp",
		"infirmary": "res://assets/rooms/room_infirmary.webp",
		"meeting_hall": "res://assets/rooms/room_meeting_hall.webp",
		"platform": "res://assets/rooms/room_platform.webp",
		"radio": "res://assets/rooms/room_radio.webp",
	}
	const POSE_ART := {
		"standing": "res://assets/figures/fig_standing.webp",
		"walking": "res://assets/figures/fig_walking.webp",
		"working": "res://assets/figures/fig_working.webp",
		"carrying": "res://assets/figures/fig_carrying.webp",
		"kneeling": "res://assets/figures/fig_kneeling.webp",
		"sitting": "res://assets/figures/fig_sitting.webp",
	}
	# Backdrop image: tunnel rail, and how much of each side is the mouth.
	const BACKDROP_RAIL := 0.783
	# Inner lip of each tunnel mouth, so the arches meet the station edges.
	const BACKDROP_SIDE := 0.147
	const OPEN_WIDTH := 0.875
	const PLATFORM_RAIL := 0.96
	const SKY_FRAC := 0.268
	const ROCK_LIP := 0.0
	var art := {}
	var poses := {}
	var figure_scale_px := 660.0
	var cell_rock: Texture2D
	var cell_dug: Texture2D
	var backdrop_tex: Texture2D
	var art_aspect := 1.6
	var hover := Vector2i(-1, -1)
	var drag_id := ""
	var drag_lock := false
	var shake_cell := Vector2i(-1, -1)
	var shake_until := 0
	var shake_px := 0.0
	var shake_reason := ""
	var zoom := 1.0
	var user_zoom := 1.0
	var pan := Vector2.ZERO
	var dragging := false
	var drag_from := Vector2.ZERO
	var pan_from := Vector2.ZERO
	var moved := false
	var pending_level := -1
	var pending_cell := -1
	var pending_at := 0
	var focused := Vector2i(-1, -1)
	const DOUBLE_MS := 320

	func fit() -> void:
		user_zoom = 1.0
		focused = Vector2i(-1, -1)
		_frame_station()

	func on_resize() -> void:
		if user_zoom <= 1.001 and focused.x < 0:
			fit()
			return
		var area := _content()
		var focus := _unview(area.get_center())
		var base := _fit_zoom()
		zoom = base * user_zoom
		pan = area.get_center() - focus * zoom
		queue_redraw()

	func _frame_station() -> void:
		var base := _fit_zoom()
		zoom = base * maxf(user_zoom, 1.0)
		var area := _content()
		var station_rect := _station_rect()
		var pan_x := area.get_center().x - station_rect.get_center().x * zoom
		var pan_y := area.position.y + area.size.y - 6.0 - (station_rect.position.y + station_rect.size.y) * zoom
		pan = Vector2(pan_x, pan_y)
		queue_redraw()

	func _fit_zoom() -> float:
		var station_rect := _station_rect()
		var area := _content()
		if station_rect.size.x < 1.0 or area.size.x < 1.0 or area.size.y < 1.0:
			return 1.0
		var by_width := area.size.x * OPEN_WIDTH / station_rect.size.x
		var sky := station_rect.size.y * 0.12
		var by_height := maxf(area.size.y - 8.0, 48.0) / (station_rect.size.y + sky)
		return minf(by_width, by_height)

	func _station_rect() -> Rect2:
		var geo := _geo()
		return Rect2(geo.origin, Vector2(float(geo.w) * 6.0, float(geo.h) * 3.0 + float(geo.band) * 2.0))

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		for type in ART:
			var image := _load_image(str(ART[type]))
			if image != null:
				art_aspect = float(image.get_width()) / float(image.get_height())
				art[type] = ImageTexture.create_from_image(image)
		cell_rock = _tex("res://assets/cells/cell_rock.webp")
		cell_dug = _tex("res://assets/cells/cell_dug.webp")
		backdrop_tex = _tex("res://assets/backdrop_station.webp")
		for pose_name in POSE_ART:
			var figure := _load_image(str(POSE_ART[pose_name]))
			if figure == null:
				continue
			if str(pose_name) == "standing":
				figure_scale_px = float(figure.get_height())
			poses[pose_name] = ImageTexture.create_from_image(_erode_alpha(figure, 2))

	func _load_image(path: String) -> Image:
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.get_width() < 1:
			return null
		return image

	func _tex(path: String) -> Texture2D:
		var image := _load_image(path)
		if image == null:
			return null
		return ImageTexture.create_from_image(image)

	func _erode_alpha(image: Image, radius: int) -> Image:
		var src := image.duplicate()
		src.convert(Image.FORMAT_RGBA8)
		var out := src.duplicate()
		var w: int = src.get_width()
		var h: int = src.get_height()
		for y in h:
			for x in w:
				var c: Color = src.get_pixel(x, y)
				if c.a < 0.02:
					continue
				var clear := false
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						var xx: int = x + dx
						var yy: int = y + dy
						if xx < 0 or yy < 0 or xx >= w or yy >= h or src.get_pixel(xx, yy).a < 0.08:
							clear = true
							break
					if clear:
						break
				if clear:
					out.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
		return out

	func _process(_delta: float) -> void:
		if pending_level >= 0 and Time.get_ticks_msec() - pending_at >= DOUBLE_MS:
			var level := pending_level
			var cell := pending_cell
			pending_level = -1
			if station != null:
				station._tap_cell(level, cell)
		if station != null and station.game != null:
			_track_drag()
			queue_redraw()

	func _track_drag() -> void:
		if drag_lock or station == null:
			return
		var vp := get_viewport()
		if vp != null and vp.gui_is_dragging():
			var data = vp.gui_get_drag_data()
			if typeof(data) == TYPE_DICTIONARY and data.has("person"):
				drag_id = str(data.person)
				if not station.drawer_open:
					station.drawer_open = true
					station._place_drawer()
				return
		if drag_id != "":
			drag_id = ""

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != Vector2i(-1, -1):
			hover = Vector2i(-1, -1)
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMagnifyGesture:
			_zoom_at(event.position, event.factor)
			accept_event()
			return
		if event is InputEventPanGesture:
			pan += event.delta
			queue_redraw()
			accept_event()
			return
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(event.position, 1.12)
				accept_event()
				return
			if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(event.position, 1.0 / 1.12)
				accept_event()
				return
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
				if event.pressed:
					dragging = true
					moved = false
					drag_from = event.position
					pan_from = pan
				else:
					var tapped: bool = event.button_index == MOUSE_BUTTON_LEFT and not moved
					dragging = false
					if tapped:
						_note_tap(event.position)
				accept_event()
				return
		if event is InputEventMouseMotion:
			if dragging:
				var delta: Vector2 = event.position - drag_from
				if delta.length() > 5.0:
					moved = true
					pan = pan_from + delta
			if not moved:
				var over: Dictionary = _hit(event.position)
				var next := Vector2i(-1, -1)
				if not over.is_empty() and _kind(over) != "hidden":
					next = Vector2i(int(over.level), int(over.cell))
				if next != hover:
					hover = next
			queue_redraw()

	func _note_tap(screen: Vector2) -> void:
		var hit: Dictionary = _hit(screen)
		if hit.is_empty():
			pending_level = -1
			return
		var level := int(hit.level)
		var cell := int(hit.cell)
		var now := Time.get_ticks_msec()
		if pending_level == level and pending_cell == cell and now - pending_at < DOUBLE_MS:
			pending_level = -1
			var key := Vector2i(level, cell)
			if focused == key:
				fit()
			else:
				_zoom_to(level, cell)
				focused = key
			return
		pending_level = level
		pending_cell = cell
		pending_at = now

	func _zoom_to(level: int, cell: int) -> void:
		var geo := _geo()
		var rect := _rect(geo, level, cell)
		var area := _content()
		var zx := area.size.x / maxf(rect.size.x, 1.0)
		var zy := area.size.y / maxf(rect.size.y, 1.0)
		var base := _fit_zoom()
		user_zoom = clampf(minf(zx, zy) * 0.9 / maxf(base, 0.0001), 1.0, 8.0)
		zoom = base * user_zoom
		var center := rect.get_center()
		pan = area.get_center() - center * zoom
		queue_redraw()

	func _zoom_to_rect(rect: Rect2) -> void:
		var area := _content()
		var zx := area.size.x / maxf(rect.size.x, 1.0)
		var zy := area.size.y / maxf(rect.size.y, 1.0)
		var base := _fit_zoom()
		user_zoom = clampf(minf(zx, zy) * 0.92 / maxf(base, 0.0001), 1.0, 8.0)
		zoom = base * user_zoom
		pan = area.get_center() - rect.get_center() * zoom
		queue_redraw()

	func _zoom_at(screen: Vector2, factor: float) -> void:
		var world := _unview(screen)
		var base := _fit_zoom()
		user_zoom = clampf(user_zoom * factor, 1.0, 8.0)
		zoom = base * user_zoom
		if user_zoom <= 1.001:
			focused = Vector2i(-1, -1)
			_frame_station()
			return
		pan = screen - world * zoom
		queue_redraw()

	func _unview(screen: Vector2) -> Vector2:
		return (screen - pan) / zoom

	func _can_drop_data(at_position: Vector2, data) -> bool:
		if typeof(data) != TYPE_DICTIONARY or not data.has("person"):
			return false
		var hit: Dictionary = _hit(at_position)
		return not hit.is_empty() and str(hit.room) != ""

	func _drop_data(at_position: Vector2, data) -> void:
		var hit: Dictionary = _hit(at_position)
		if hit.is_empty() or str(hit.room) == "":
			return
		station._drop_person(str(data.person), str(hit.room))

	func _hit(at_position: Vector2) -> Dictionary:
		if station == null or station.game == null:
			return {}
		var world := _unview(at_position)
		var geo := _geo()
		if geo.w < 4.0 or geo.h < 4.0:
			return {}
		for level in 3:
			for cell in 6:
				var rect := _rect(geo, level, cell)
				if rect.has_point(world):
					var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
					spot = spot.duplicate()
					spot.level = level
					spot.cell = cell
					return spot
		return {}

	func _content() -> Rect2:
		var top := 52.0
		if station != null and station.hud != null and station.hud.size.y > 8.0:
			top = station.hud.size.y
		var bottom := 96.0
		if station != null:
			bottom = station.chrome_bottom
		return Rect2(0, top, size.x, maxf(48.0, size.y - top - bottom))

	func _geo() -> Dictionary:
		var aspect := art_aspect if art_aspect > 0.4 else 1.9
		var w := 240.0
		var h := w / aspect
		return {"origin": Vector2.ZERO, "w": w, "h": h, "band": BAND}

	func _rect(geo: Dictionary, level: int, cell: int) -> Rect2:
		var origin: Vector2 = geo.origin
		return Rect2(
			origin.x + cell * float(geo.w),
			origin.y + level * (float(geo.h) + float(geo.band)),
			float(geo.w),
			float(geo.h))

	func _draw() -> void:
		if station == null or station.game == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.07))
		draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
		var geo := _geo()
		_draw_backdrop(geo)
		var span := float(geo.w) * 6.0
		for gap in 2:
			var y: float = geo.origin.y + float(gap + 1) * float(geo.h) + float(gap) * float(geo.band)
			_blit_fill(cell_rock, Rect2(geo.origin.x, y, span, float(geo.band)))
		for level in 3:
			for cell in 6:
				_draw_cell(_rect(geo, level, cell), level, cell)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _platform_rail_y(geo: Dictionary) -> float:
		var plat := _rect(geo, 1, 0)
		return plat.position.y + plat.size.y * PLATFORM_RAIL

	func _backdrop_dest(station_rect: Rect2) -> Rect2:
		var tex := backdrop_tex.get_size()
		var inner := 1.0 - BACKDROP_SIDE * 2.0
		var scale := station_rect.size.x / (tex.x * inner)
		return Rect2(
			station_rect.position.x - tex.x * BACKDROP_SIDE * scale,
			_platform_rail_y(_geo()) - BACKDROP_RAIL * tex.y * scale,
			tex.x * scale,
			tex.y * scale)

	func _draw_backdrop(_geo: Dictionary) -> void:
		if backdrop_tex == null:
			return
		var dest := _backdrop_dest(_station_rect())
		var tex := backdrop_tex.get_size()
		var station_top := _station_rect().position.y
		var src_y := (station_top - ROCK_LIP - dest.position.y) / dest.size.y * tex.y
		src_y = clampf(src_y, 0.0, tex.y - 1.0)
		var src_h := tex.y - src_y
		var lower_h := dest.size.y * src_h / tex.y
		var lower_y := dest.position.y + dest.size.y * src_y / tex.y
		draw_texture_rect_region(backdrop_tex, Rect2(dest.position.x, lower_y, dest.size.x, lower_h), Rect2(0, src_y, tex.x, src_h))
		var sky_src_h := tex.y * SKY_FRAC
		var sky_h := dest.size.y * SKY_FRAC
		draw_texture_rect_region(backdrop_tex, Rect2(dest.position.x, lower_y - sky_h, dest.size.x, sky_h), Rect2(0, 0, tex.x, sky_src_h))

	func _draw_cell(rect: Rect2, level: int, cell: int) -> void:
		var shift := 0.0
		if shake_cell == Vector2i(level, cell) and (shake_px != 0.0 or Time.get_ticks_msec() < shake_until):
			shift = shake_px if shake_px != 0.0 else sin(Time.get_ticks_msec() / 45.0) * 8.0
		if shift != 0.0:
			rect.position += Vector2(shift, 0.0)
		var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
		var kind := _kind(spot)
		var room = null
		var room_type := ""
		if kind == "room":
			room = station.game._room(str(spot.room))
			room_type = str(room.type)
		if kind == "hidden":
			_blit_fill(cell_rock, rect)
			draw_rect(rect, Color(0, 0, 0, 0.38))
		elif kind == "undug":
			_blit_fill(cell_rock, rect)
		elif kind == "dug":
			_blit_fill(cell_dug, rect)
		else:
			var fill: Color = ROOM_COLOR.get(room_type, Color(0.12, 0.12, 0.13))
			draw_rect(rect, fill)
			var texture = art.get(room_type, null)
			if texture != null:
				_blit_room(texture, rect)
		var losing: bool = kind == "room" and station.power_loss.has(str(spot.room))
		if losing:
			draw_rect(rect, Color(0, 0, 0, _lamp(level, cell)))
			_draw_power_icon(rect)
		if kind == "room":
			if room_type == "platform":
				_draw_platform(rect, room)
			else:
				_draw_people(rect, room)
		_draw_carriers(rect, level, cell)
		if _under_water(spot, kind):
			_draw_water(rect, level, cell)
		var job_left := _job_left(level, cell)
		if job_left >= 0:
			_draw_scaffold(rect)
			_draw_pips(rect, job_left)
		elif kind == "undug":
			_draw_dig_outline(rect, level, cell)
		if drag_id != "" and kind == "room" and room != null:
			var preview: Dictionary = station.game.assign_preview(drag_id, str(room.uid))
			if bool(preview.ok):
				draw_rect(rect, Color(0.95, 0.84, 0.55, 0.28))
				draw_rect(rect.grow(-4.0), Color(0.95, 0.84, 0.55, 0.95), false, 4.0)
		if shake_reason != "" and shake_cell == Vector2i(level, cell):
			var reason_font: Font = ThemeDB.fallback_font
			if station.body_font != null:
				reason_font = station.body_font
			var reason_size: Vector2 = reason_font.get_string_size(shake_reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
			var reason_w := maxf(rect.size.x, reason_size.x + 16.0)
			var reason_bar := Rect2(rect.get_center().x - reason_w * 0.5, rect.position.y + rect.size.y - 26, reason_w, 26)
			draw_rect(reason_bar, Color(0.28, 0.08, 0.06, 0.94))
			draw_rect(Rect2(reason_bar.position, Vector2(reason_bar.size.x, 2)), Color(0.9, 0.35, 0.28, 0.95))
			draw_string(reason_font, reason_bar.position + Vector2(8, 18), shake_reason, HORIZONTAL_ALIGNMENT_LEFT, reason_bar.size.x - 12, 15, Color("f4efe4"))
		if hover == Vector2i(level, cell):
			var tip := _cell_action(level, cell, kind, room_type)
			if tip != "":
				var font: Font = ThemeDB.fallback_font
				if station.body_font != null:
					font = station.body_font
				var text_size: Vector2 = font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
				var bar_w := maxf(rect.size.x, text_size.x + 16.0)
				var bar := Rect2(rect.get_center().x - bar_w * 0.5, rect.position.y + rect.size.y - 26, bar_w, 26)
				draw_rect(bar, Color(0.05, 0.04, 0.03, 0.92))
				draw_rect(Rect2(bar.position, Vector2(bar.size.x, 2)), Color(0.85, 0.72, 0.4, 0.95))
				draw_string(font, bar.position + Vector2(8, 18), tip, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 12, 15, Color("f4efe4"))

	func _paint_rock(rect: Rect2, salt: int) -> void:
		draw_rect(rect, Color(0.16, 0.13, 0.1))
		var specks := 22
		for i in specks:
			var n := _speck(salt, i)
			var px := rect.position.x + fmod(n, maxf(rect.size.x, 1.0))
			var py := rect.position.y + fmod(n * 1.37, maxf(rect.size.y, 1.0))
			var shade := 0.1 + fmod(n, 9.0) * 0.018
			draw_rect(Rect2(px, py, 4.0 + fmod(n, 6.0), 2.0), Color(shade, shade * 0.82, shade * 0.62, 0.9))

	func _speck(salt: int, i: int) -> float:
		var n := (salt * 131 + i * 17) % 997
		return float(n)

	func _blit_fill(texture: Texture2D, rect: Rect2) -> void:
		if texture == null:
			_paint_rock(rect, 1)
			return
		draw_texture_rect(texture, rect, false)

	func _blit_room(texture: Texture2D, rect: Rect2) -> void:
		var tex := texture.get_size()
		if tex.x < 1.0 or tex.y < 1.0:
			return
		var aspect := tex.x / tex.y
		var cell_aspect := rect.size.x / maxf(rect.size.y, 1.0)
		var dest := rect
		if cell_aspect > aspect:
			var w := rect.size.y * aspect
			dest = Rect2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y, w, rect.size.y)
		elif cell_aspect < aspect:
			var h := rect.size.x / aspect
			dest = Rect2(rect.position.x, rect.position.y + (rect.size.y - h) * 0.5, rect.size.x, h)
		draw_rect(rect, Color(0.1, 0.08, 0.06))
		draw_texture_rect(texture, dest, false)

	func _lamp(level: int, cell: int) -> float:
		var t := Time.get_ticks_msec() / 1000.0
		var wobble := sin(t * 1.1 + float(cell) * 2.3) * 0.65 + sin(t * 0.37 + float(level) * 1.7 + float(cell)) * 0.35
		return clampf(0.6 + wobble * 0.08, 0.5, 0.72)

	func _draw_power_icon(rect: Rect2) -> void:
		var origin := rect.position + Vector2(rect.size.x - 18, 8)
		var bolt := PackedVector2Array([
			origin + Vector2(8, 0),
			origin + Vector2(3, 8),
			origin + Vector2(7, 8),
			origin + Vector2(2, 16),
			origin + Vector2(10, 7),
			origin + Vector2(6, 7),
		])
		draw_colored_polygon(bolt, Color("e07a6a"))

	func _draw_water(rect: Rect2, level: int, cell: int) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var wave := sin(t * 1.25 + float(cell) * 1.3) * 0.018 + sin(t * 0.55 + float(level) * 2.0) * 0.012
		var frac := clampf(0.33 + wave, 0.28, 0.4)
		var height := rect.size.y * frac
		var body := Rect2(rect.position.x, rect.position.y + rect.size.y - height, rect.size.x, height)
		draw_rect(body, Color(0.04, 0.11, 0.16, 0.82))
		draw_line(Vector2(body.position.x, body.position.y + 1.0), Vector2(body.position.x + body.size.x, body.position.y + 1.0), Color(0.55, 0.72, 0.8, 0.7), 2.0)

	func _short(type: String, width: float) -> String:
		var full := str(station.game.catalog.rooms[type].name)
		if width >= 108.0:
			return full
		match type:
			"hydroponics":
				return "Hydro"
			"air_filter":
				return "Air"
			"meeting_hall":
				return "Hall"
			"generator":
				return "Power"
			"infirmary":
				return "Infirm"
			"workshop":
				return "Shop"
			"quarters":
				return "Bunks"
			"platform":
				return "Plat"
			"radio":
				return "Radio"
			_:
				return full

	func _under_water(spot: Dictionary, kind: String) -> bool:
		if bool(spot.flooded):
			return true
		if kind != "room" and kind != "dug":
			return false
		if not station.game._season_is("flood"):
			return false
		return int(spot.level) == station.game._lowest_open_level()

	func _kind(spot: Dictionary) -> String:
		if str(spot.room) != "":
			return "room"
		if bool(spot.dug):
			return "dug"
		if station.game._beside_dug(spot):
			return "undug"
		return "hidden"

	func _draw_dig_outline(rect: Rect2, level: int, cell: int) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var wave := 0.5 + 0.5 * sin(t * 2.4 + float(level) * 1.3 + float(cell) * 0.7)
		var alpha := 0.55 + 0.4 * wave
		var ring := rect.grow(-4.0)
		draw_rect(ring, Color(0.02, 0.015, 0.01, 0.9), false, 5.0)
		draw_rect(ring, Color(0.95, 0.84, 0.55, alpha), false, 2.0)

	func _draw_scaffold(rect: Rect2) -> void:
		var box := rect.grow(-12.0)
		var ink := Color(0.08, 0.05, 0.03, 0.95)
		var wood := Color(0.78, 0.58, 0.3, 0.96)
		_beam(box.position, box.position + Vector2(box.size.x, 0), ink, wood)
		_beam(box.position + Vector2(0, box.size.y), box.position + box.size, ink, wood)
		_beam(box.position, box.position + Vector2(0, box.size.y), ink, wood)
		_beam(box.position + Vector2(box.size.x, 0), box.position + box.size, ink, wood)
		var mid := box.position.y + box.size.y * 0.5
		_beam(Vector2(box.position.x, mid), Vector2(box.end.x, mid), ink, wood)
		_beam(box.position, box.position + box.size, ink, wood)
		_beam(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), ink, wood)

	func _beam(a: Vector2, b: Vector2, ink: Color, wood: Color) -> void:
		draw_line(a, b, ink, 6.0)
		draw_line(a, b, wood, 2.5)

	func _draw_pips(rect: Rect2, left: int) -> void:
		if left <= 0:
			return
		var pip := 11.0
		var gap := 5.0
		var count := mini(left, 8)
		var total := float(count) * pip + float(count - 1) * gap
		var x := rect.position.x + (rect.size.x - total) * 0.5
		var y := rect.position.y + rect.size.y - 40.0
		for i in count:
			var mark := Rect2(x, y, pip, 7.0)
			draw_rect(mark.grow(1.5), Color(0.04, 0.03, 0.02, 0.92))
			draw_rect(mark, Color(0.95, 0.78, 0.38))
			x += pip + gap

	func _job_left(level: int, cell: int) -> int:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return int(digging.left)
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			return int(building.left)
		return -1

	func _cell_action(level: int, cell: int, kind: String, room_type: String) -> String:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return "Digging, %s left" % Words.count(int(digging.left), "week")
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			var name := str(station.game.catalog.rooms[str(building.type)].name)
			return "Building %s, %s left" % [name, Words.count(int(building.left), "week")]
		match kind:
			"hidden":
				return "Solid rock"
			"undug":
				return "Dig"
			"dug":
				return "Build"
			"room":
				return "Open %s" % str(station.game.catalog.rooms[room_type].name)
		return ""

	func _job_text(level: int, cell: int, width: float) -> String:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return "Dig %d" % int(digging.left)
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			return "%s %d" % [_short(str(building.type), width), int(building.left)]
		return ""

	func _draw_people(rect: Rect2, room: Dictionary) -> void:
		var crew: Array = room.staff
		if crew.is_empty() or poses.is_empty():
			return
		_draw_crew(rect, crew, str(room.type))

	func _draw_platform(rect: Rect2, room: Dictionary) -> void:
		var entries: Array = []
		for sid in room.staff:
			entries.append({"id": str(sid), "pose": _pose_name("platform", entries.size())})
		if poses.has("walking"):
			for sid in _idle_ids():
				entries.append({"id": str(sid), "pose": "walking"})
		_draw_figures(rect, entries, true)

	func _draw_carriers(rect: Rect2, level: int, cell: int) -> void:
		var crew: Array = []
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			crew = digging.workers
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			crew = building.workers
		if crew.is_empty():
			return
		_draw_crew(rect, crew, "carry")

	func _draw_crew(rect: Rect2, crew: Array, room_type: String) -> void:
		var entries: Array = []
		for i in crew.size():
			var pose_name := "carrying" if room_type == "carry" else _pose_name(room_type, i)
			entries.append({"id": str(crew[i]), "pose": pose_name})
		_draw_figures(rect, entries, false)

	func _draw_figures(rect: Rect2, entries: Array, sway: bool) -> void:
		var n := entries.size()
		if n == 0 or poses.is_empty():
			return
		var shown := mini(n, 5)
		var extra := n - shown
		var widths: Array[float] = []
		var total := 0.0
		for i in shown:
			var pose_name := str(entries[i].pose)
			if not poses.has(pose_name):
				widths.append(0.0)
				continue
			var width := _pose_size(poses[pose_name], rect.size.y).x
			widths.append(width)
			total += width
		var tag_w := 36.0 if extra > 0 else 0.0
		var pad := 6.0
		var usable := maxf(8.0, rect.size.x - pad * 2.0 - tag_w)
		var min_gap := 8.0
		var gaps := shown - 1
		var gap := min_gap
		if gaps > 0:
			gap = maxf(min_gap, (usable - total) / float(gaps))
			var run_try := total + gap * float(gaps)
			if run_try > usable:
				gap = maxf(2.0, (usable - total) / float(gaps))
		var run := total + gap * float(maxi(gaps, 0))
		var x := rect.position.x + pad + maxf(0.0, (usable - run) * 0.5)
		var t := Time.get_ticks_msec() / 1000.0
		for i in shown:
			var id := str(entries[i].id)
			var pose_name := str(entries[i].pose)
			var width: float = widths[i]
			if width <= 0.0:
				continue
			var h := _id_hash(id)
			var slide := 0.0
			if sway:
				var spare := maxf(0.0, gap - min_gap)
				slide = sin(t * 0.7 + h * 0.02) * minf(spare * 0.35, 6.0)
			var cx := x + width * 0.5 + slide
			var left_lim := rect.position.x + pad + width * 0.5
			var right_lim := rect.position.x + pad + usable - width * 0.5
			cx = clampf(cx, left_lim, right_lim)
			var bob := sin(t * 1.7 + h * 0.02) * 1.6
			var foot_y := rect.position.y + rect.size.y + bob
			_paint_pose(pose_name, cx, foot_y, rect.size.y, id, sway and int(h) % 2 == 0)
			x += width + gap
		if extra > 0:
			_draw_more(rect, extra)

	func _draw_more(rect: Rect2, extra: int) -> void:
		var label := "+%d" % extra
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var font_size := 13
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Vector2(text_size.x + 10.0, text_size.y + 4.0)
		var origin := Vector2(rect.position.x + rect.size.x - box.x - 4.0, rect.position.y + rect.size.y - box.y - 6.0)
		draw_rect(Rect2(origin, box), Color(0.09, 0.06, 0.04, 0.88))
		draw_string(font, origin + Vector2(5.0, text_size.y * 0.82), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("efe6d2"))

	func _pose_name(room_type: String, index: int) -> String:
		match room_type:
			"workshop":
				return "working"
			"hydroponics":
				return "kneeling"
			"quarters", "meeting_hall":
				return "sitting"
			"infirmary":
				return "standing"
			"generator", "air_filter":
				if index % 2 == 0:
					return "working"
				return "standing"
			_:
				return "standing"

	func _pose_size(sprite: Texture2D, cell_h: float) -> Vector2:
		var scale := (cell_h * 0.58) / maxf(figure_scale_px, 1.0)
		return sprite.get_size() * scale

	func _paint_pose(pose_name: String, cx: float, foot_y: float, cell_h: float, id: String, flip: bool) -> void:
		if not poses.has(pose_name):
			return
		var sprite: Texture2D = poses[pose_name]
		var fitted := _pose_size(sprite, cell_h)
		var dest := Rect2(cx - fitted.x * 0.5, foot_y - fitted.y, fitted.x, fitted.y)
		if flip:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		var warm := fmod(_id_hash(id), 9.0) / 90.0
		draw_texture_rect(sprite, dest, false, Color(0.96 + warm, 0.97, 1.02 - warm))

	func _idle_ids() -> Array:
		var busy := {}
		for room in station.game.rooms:
			for sid in room.staff:
				busy[str(sid)] = true
		if not station.game.dig.is_empty():
			for sid in station.game.dig.workers:
				busy[str(sid)] = true
		if not station.game.build.is_empty():
			for sid in station.game.build.workers:
				busy[str(sid)] = true
		var ids: Array = []
		for person in station.game.residents:
			var id := str(person.id)
			if busy.has(id) or int(person.absent) > 0:
				continue
			ids.append(id)
		return ids

	func _id_hash(id: String) -> float:
		var n := 17
		for i in id.length():
			n = (n * 33 + id.unicode_at(i)) % 100003
		return float(n)


class Glyph extends Control:
	var kind := "food"
	var ink := Color("efe6d2")

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var c := rect.get_center()
		var s := minf(rect.size.x, rect.size.y)
		var r := s * 0.38
		var thick := maxf(2.4, r * 0.55)
		match kind:
			"air":
				draw_arc(c, r * 0.62, 0, TAU, 28, ink, thick)
				draw_circle(c + Vector2(r * 0.22, -r * 0.18), r * 0.16, ink)
			"food":
				draw_circle(c + Vector2(0, r * 0.12), r * 0.62, ink)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.05, -r * 0.35),
					c + Vector2(r * 0.15, -r * 0.95),
					c + Vector2(r * 0.62, -r * 0.28),
				]), ink)
			"power":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(r * 0.2, -r), c + Vector2(-r * 0.55, r * 0.08),
					c + Vector2(r * 0.02, r * 0.08), c + Vector2(-r * 0.28, r),
					c + Vector2(r * 0.62, -r * 0.18), c + Vector2(r * 0.02, -r * 0.18),
				]), ink)
			"materials":
				draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.05), Vector2(r * 1.7, r * 0.7)), ink)
				draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.72), Vector2(r * 1.25, r * 0.48)), ink)
			"tokens", "buy":
				draw_circle(c, r * 0.78, ink)
				draw_arc(c, r * 0.42, 0, TAU, 20, Color(0, 0, 0, 0.35), maxf(1.5, r * 0.18))
			"demand":
				draw_circle(c, r * 0.78, ink)
				draw_line(c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.4, 0), Color(0, 0, 0, 0.45), thick)
			"influence":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.28, -r * 0.28),
					c + Vector2(r, 0), c + Vector2(r * 0.28, r * 0.28),
					c + Vector2(0, r), c + Vector2(-r * 0.28, r * 0.28),
					c + Vector2(-r, 0), c + Vector2(-r * 0.28, -r * 0.28),
				]), ink)
			"hope":
				draw_circle(c, r * 0.45, ink)
			"discontent":
				draw_line(c + Vector2(-r, r * 0.4), c + Vector2(-r * 0.2, -r * 0.4), ink, 1.6)
				draw_line(c + Vector2(-r * 0.2, -r * 0.4), c + Vector2(r * 0.2, r * 0.3), ink, 1.6)
				draw_line(c + Vector2(r * 0.2, r * 0.3), c + Vector2(r, -r * 0.2), ink, 1.6)
			"pump":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.45), c + Vector2(-r * 0.7, r * 0.45)
				]), ink)
			"quarantine":
				draw_rect(Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), ink, false, 1.6)
				draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), ink, 1.6)
				draw_line(c + Vector2(-r * 0.6, 0), c + Vector2(r * 0.6, 0), ink, 1.6)
			"burn":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.55, r * 0.2),
					c + Vector2(r * 0.15, r * 0.15), c + Vector2(r * 0.35, r),
					c + Vector2(-r * 0.35, r), c + Vector2(-r * 0.1, r * 0.05),
					c + Vector2(-r * 0.5, r * 0.15),
				]), ink)
			"people":
				draw_circle(c + Vector2(0, -r * 0.55), r * 0.38, ink)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.7, r), c + Vector2(0, -r * 0.1), c + Vector2(r * 0.7, r)
				]), ink)
			"squad":
				draw_line(c + Vector2(-r, 0), c + Vector2(r * 0.2, 0), ink, 1.8)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(r * 0.1, -r * 0.55), c + Vector2(r, 0), c + Vector2(r * 0.1, r * 0.55)
				]), ink)
			"secure":
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.2),
					c + Vector2(r * 0.55, r), c + Vector2(-r * 0.55, r), c + Vector2(-r * 0.8, -r * 0.2)
				]), ink)
			"hold":
				draw_rect(Rect2(c + Vector2(-r * 0.7, -r), Vector2(s * 0.22, s * 0.75)), ink)
				draw_rect(Rect2(c + Vector2(r * 0.15, -r), Vector2(s * 0.22, s * 0.75)), ink)
			_:
				draw_circle(c, r * 0.4, ink)


class ToolButton extends Button:
	var glyph_name := "pump"
	var caption := ""

	func _ready() -> void:
		text = ""
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_left = 4.0
		box.offset_top = 4.0
		box.offset_right = -4.0
		box.offset_bottom = -2.0
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 1)
		add_child(box)
		var mark := Glyph.new()
		mark.kind = glyph_name
		mark.custom_minimum_size = Vector2(22, 22)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(mark)
		var lab := Label.new()
		lab.text = caption
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color("efe6d2"))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
