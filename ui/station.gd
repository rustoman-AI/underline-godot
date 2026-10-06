extends Control

## Cut-away of the station. Placeholder shapes on a painted wall. The sim stays in charge of the week.

const INK := Color("efe6d2")
const INK_DARK := Color("24180e")
const MUTED := Color("b7aa96")
const PAPER := Color("e6d3b0")
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if OS.get_name() == "Android":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	_load_fonts()
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
	variation.set_variation_opentype({"wght": 800.0})
	display_font = variation


func _process(_delta: float) -> void:
	if end_button == null:
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
	end_button.add_theme_stylebox_override("normal", _brass_style(false))
	end_button.add_theme_stylebox_override("hover", _brass_style(false))
	end_button.add_theme_stylebox_override("pressed", _brass_style(true))
	end_button.add_theme_stylebox_override("disabled", _brass_style(false))
	add_child(end_button)

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
		var delta := _label("—", 12)
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		delta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		delta.custom_minimum_size = Vector2(18, 16)
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
		yard.fit()


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
	if yard != null:
		yard.queue_redraw()


func _place_drawer() -> void:
	if side == null:
		return
	side.visible = drawer_open
	if not drawer_open:
		return
	var w := minf(360.0, size.x * 0.42)
	side.offset_left = size.x - w
	side.offset_right = size.x
	side.offset_top = 56.0
	side.offset_bottom = size.y - chrome_bottom

func _build_overlay() -> void:
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
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
	var h := 28.0
	var count := card_body.get_child_count()
	for child in card_body.get_children():
		h += child.size.y
	if count > 1:
		h += float(count - 1) * 8.0
	h += 32.0
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
				color = Color("8fbf6a")
			elif d < 0:
				color = Color("e07a6a")
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
	end_button.disabled = game.over != ""
	end_button.text = "End turn" if game.over == "" else _ending()
	var burn: Dictionary = game.burn_preview()
	burn_button.disabled = not bool(burn.ok) or game.over != ""
	burn_button.tooltip_text = "Burn salvage" if bool(burn.ok) else "Burn salvage. %s" % str(burn.reason)
	if game.week != ticker_week:
		ticker_week = game.week
		ticker_dismissed = false
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


func _fill_people() -> void:
	_wipe(people_box)
	for person in game.residents:
		var id := str(person.id)
		var row := PersonRow.new()
		row.person_id = id
		row.person_name = str(person.name)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 1)
		row.add_child(box)
		var traits: PackedStringArray = []
		for trait_name in person.traits:
			traits.append(str(trait_name))
		var trait_line := ", ".join(traits) if not traits.is_empty() else "no trait"
		var skills := ""
		for key in person.skills:
			if skills != "":
				skills += "  "
			skills += "%s %d" % [key, int(person.skills[key])]
		box.add_child(_label(str(person.name), 16))
		var skill_label := _label(skills, 13)
		skill_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		box.add_child(skill_label)
		var where := _label("%s · %s" % [trait_line, _where(id)], 13)
		where.add_theme_color_override("font_color", MUTED)
		box.add_child(where)
		people_box.add_child(row)


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


func _end_turn() -> void:
	if game.over != "":
		return
	if not game.pending.is_empty():
		_show_dawn()
		footer.text = "Someone is still waiting. Choose before the week ends."
		footer.visible = true
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
		var info: Dictionary = game.resource_outlook(key)
		_open_card(key.capitalize())
		_body(str(info.text))
		card_body.add_child(_button("Close", _close_card))


func _ask_pump() -> void:
	var lines: PackedStringArray = [
		"%d materials and %d power." % [int(game.bal.pump_materials), int(game.bal.pump_power)],
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
		"%d materials become %d power this week. Hope %+d." % [int(info.materials), int(info.power), int(info.hope)],
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
			"%d turns left." % int(game.dig.left),
			"%d people on the crew." % game.dig.workers.size(),
		]
		_confirm("Dig in progress", digging, false, {})
		return
	if not game.build.is_empty() and int(game.build.level) == level and int(game.build.cell) == cell:
		var name := str(game.catalog.rooms[str(game.build.type)].name)
		var building: PackedStringArray = ["%d turns left." % int(game.build.left)]
		_confirm(name, building, false, {})
		return
	if not bool(spot.dug):
		var info := game.dig_preview(level, cell)
		var lines: PackedStringArray = [
			"%d turns." % int(info.turns),
			"%d workers." % int(info.workers),
			"%d materials." % int(info.materials),
		]
		if str(info.reason) != "":
			lines.append(str(info.reason))
		_confirm("Dig this cell?", lines, bool(info.ok), {"kind": "dig", "level": level, "cell": cell})
		return
	_show_build(level, cell)


func _drop_person(person_id: String, uid: String) -> void:
	var info := game.assign_preview(person_id, uid)
	if not bool(info.ok):
		_open_card(str(game.people[person_id].name))
		_body(str(info.reason))
		card_body.add_child(_button("Close", _close_card))
		return
	game.apply({"kind": "assign", "person": person_id, "room": uid})
	_refresh()


func _show_build(level: int, cell: int) -> void:
	_open_card("Build here")
	_body("Level %d, cell %d. An open floor." % [level + 1, cell + 1])
	for type in game.buildable_types():
		var info := game.build_preview(str(type), level, cell)
		var text := "%s — %d materials, %d turns, %d workers, power %d" % [
			str(info.name), int(info.materials), int(info.turns), int(info.workers), int(info.power)]
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
		"%d materials, %d turns, %d workers." % [int(info.materials), int(info.turns), int(info.workers)],
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
	_open_card(str(detail.name))
	if notice != "":
		_body(notice)
		notice = ""
	_body(_room_lead(detail))
	if bool(detail.offline):
		_body("Offline.")
	for member in detail.staff:
		var row := HBoxContainer.new()
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
		card_body.add_child(_button("Assign someone", _show_assign.bind(uid)))
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
	_open_card("Assign to %s" % str(detail.name))
	var skill_name := str(detail.skill)
	_body("Best %s first. The number is that skill." % skill_name)
	var filter := LineEdit.new()
	filter.placeholder_text = "Filter names"
	filter.add_theme_color_override("font_color", INK_DARK)
	filter.add_theme_color_override("font_placeholder_color", Color(0.28, 0.22, 0.16, 0.55))
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
		lines.append("%s for %d materials." % [str(info.name), int(info.materials)])
	if str(info.reason) != "":
		lines.append(str(info.reason))
	if lines.is_empty():
		lines.append("Nothing to upgrade.")
	_confirm("Upgrade?", lines, bool(info.ok), {"kind": "upgrade", "room": uid})


func _confirm_demolish(uid: String) -> void:
	var info := game.demolish_preview(uid)
	var lines: PackedStringArray = ["%d materials come back." % int(info.refund)]
	if str(info.reason) != "":
		lines.append(str(info.reason))
	_confirm("Pull down %s?" % str(info.name), lines, bool(info.ok), {"kind": "demolish", "room": uid})


func _show_laws() -> void:
	_open_card("Laws")
	if not game._room_ready("meeting_hall"):
		_body("Staff the meeting hall. The hall can pass one law, then it waits %d weeks." % int(game.bal.law_cooldown))
	elif game.law_lock > 0:
		_body("A law was just passed. The next one is %d weeks away." % game.law_lock)
	else:
		_body("One law this sitting. The next sitting is %d weeks later." % int(game.bal.law_cooldown))
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
		bits.append("Digs finish %d week sooner." % int(defin.dig_faster))
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
		_body("%d more waiting after this one." % (game.pending.size() - 1))
	card_body.add_child(_button(game.close_caption(), _dismiss_dawn))


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
		icon.ink = INK_DARK
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
	_open_card(_ending())
	_body("Week %d. Food %d, air %d, power %d, materials %d." % [
		game.week, int(game.stock.food), int(game.stock.air), int(game.stock.power), int(game.stock.materials)])
	_body("Hope %d. Discontent %d. %d people." % [game.hope, game.discontent, game.residents.size()])
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


func _choice_button(label: String, choice: Dictionary, cb: Callable) -> Button:
	var button := _button(label, cb)
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
	icon.ink = INK_DARK if on_paper else INK
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


func _open_card(heading: String, with_close: bool = true) -> void:
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
	on_paper = false
	dim.visible = false
	_wipe(card_body)


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
	lab.add_theme_color_override("font_color", INK_DARK if on_paper else INK)
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
	button.add_theme_color_override("font_color", INK_DARK if on_paper else INK)
	button.add_theme_color_override("font_disabled_color", Color(0.25, 0.2, 0.16, 0.55) if on_paper else MUTED)
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
		style.bg_color = Color("b7a27a") if pressed else (Color("ead9b4") if hover else Color("d4c19a"))
		style.border_color = INK_DARK
		style.set_border_width_all(2)
	else:
		style.bg_color = Color(0.2, 0.21, 0.23) if pressed else Color(0.14, 0.15, 0.17, 0.96)
		style.border_color = Color(1, 1, 1, 0.16)
		style.set_border_width_all(1)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(3)
	return style


func _brass_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("a56b22") if pressed else Color("e2a63a")
	style.border_color = Color("3a2610")
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(3)
	return style


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("2a2118")
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
		child.free()


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
	_save("week1_cutaway")
	await _settle(Vector2i(844, 390))
	_close_card()
	await _frame()
	_save("week1_phone")
	await _settle(Vector2i(1280, 720))
	var bot := Bot.new()
	var guard := 0
	while game.week < 11 and game.over == "" and guard < 20:
		guard += 1
		bot._act(game)
		game.end_week()
	_refresh()
	_close_card()
	await _settle(Vector2i(1280, 720))
	_save("week11_flood")
	await _settle(Vector2i(844, 390))
	_close_card()
	await _frame()
	_save("week11_phone")
	get_tree().quit()


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
		style.set_content_margin_all(8)
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
	}
	var art := {}
	var art_aspect := 1.9
	var hover := Vector2i(-1, -1)
	var zoom := 1.0
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
		zoom = 1.0
		pan = Vector2.ZERO
		focused = Vector2i(-1, -1)
		queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		for type in ART:
			var image := Image.load_from_file(ProjectSettings.globalize_path(str(ART[type])))
			if image != null and image.get_width() > 0:
				image = _crop_navy(image)
				if image.get_height() > 0:
					art_aspect = float(image.get_width()) / float(image.get_height())
				art[type] = ImageTexture.create_from_image(image)

	func _process(_delta: float) -> void:
		if pending_level >= 0 and Time.get_ticks_msec() - pending_at >= DOUBLE_MS:
			var level := pending_level
			var cell := pending_cell
			pending_level = -1
			if station != null:
				station._tap_cell(level, cell)
		if station != null and station.game != null:
			queue_redraw()

	func _crop_navy(image: Image) -> Image:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
		var w := image.get_width()
		var h := image.get_height()
		var top := 0
		var bottom := h - 1
		while top < h - 1 and _navy_row(image, top):
			top += 1
		while bottom > top and _navy_row(image, bottom):
			bottom -= 1
		var cap := int(float(h) * 0.4)
		top = mini(top, cap)
		bottom = maxi(bottom, h - 1 - cap)
		if top <= 0 and bottom >= h - 1:
			return image
		return image.get_region(Rect2i(0, top, w, bottom - top + 1))

	func _navy_row(image: Image, y: int) -> bool:
		var w := image.get_width()
		var navy := 0
		var samples := 12
		for i in samples:
			var x := int(round(float(i) * float(w - 1) / float(samples - 1)))
			var c := image.get_pixel(x, y)
			var bright := maxf(c.r, maxf(c.g, c.b))
			if bright > 0.3:
				navy -= 8
			elif c.b > c.r and c.r < 0.25 and c.b > 0.06:
				navy += 1
		return navy >= int(float(samples) * 0.55)

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
		zoom = clampf(minf(zx, zy) * 0.9, 1.0, 6.0)
		var center := rect.get_center()
		var view_center := area.get_center()
		pan = view_center - center * zoom
		queue_redraw()

	func _zoom_at(screen: Vector2, factor: float) -> void:
		var world := _unview(screen)
		zoom = clampf(zoom * factor, 1.0, 6.0)
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
		var area := _content()
		var aspect := art_aspect if art_aspect > 0.4 else 1.9
		var h := (area.size.y - BAND * 2.0) / 3.0
		var w := h * aspect
		var rows := h * 3.0 + BAND * 2.0
		var origin := area.position
		origin.y += maxf(0.0, (area.size.y - rows) * 0.5)
		var span := w * 6.0
		if span < area.size.x:
			origin.x += (area.size.x - span) * 0.5
		return {"origin": origin, "w": w, "h": h, "band": BAND}

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
		_paint_rock(Rect2(Vector2.ZERO, size), 2)
		draw_set_transform(pan, 0.0, Vector2(zoom, zoom))
		var geo := _geo()
		var span := float(geo.w) * 6.0
		_paint_rock(Rect2(geo.origin, Vector2(span, float(geo.h) * 3.0 + float(geo.band) * 2.0)), 3)
		for gap in 2:
			var y: float = geo.origin.y + float(gap + 1) * float(geo.h) + float(gap) * float(geo.band)
			_paint_rock(Rect2(geo.origin.x, y, span, float(geo.band)), 9 + gap)
		for level in 3:
			for cell in 6:
				_draw_cell(_rect(geo, level, cell), level, cell)
		var plat := _rect(geo, 1, 0)
		var rail_y := plat.position.y + plat.size.y - 7.0
		var x0 := plat.position.x
		var x1 := plat.position.x + span
		draw_line(Vector2(x0, rail_y), Vector2(x1, rail_y), Color(0.42, 0.38, 0.32), 2.0)
		var sleeper := x0 + 6.0
		while sleeper < x1:
			draw_line(Vector2(sleeper, rail_y - 3.0), Vector2(sleeper + 7.0, rail_y + 3.0), Color(0.2, 0.15, 0.1), 2.0)
			sleeper += 16.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_cell(rect: Rect2, level: int, cell: int) -> void:
		var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
		var kind := _kind(spot)
		var room = null
		var room_type := ""
		if kind == "room":
			room = station.game._room(str(spot.room))
			room_type = str(room.type)
		if kind == "hidden":
			_paint_rock(rect, 40 + level * 6 + cell)
			draw_rect(rect, Color(0, 0, 0, 0.28))
		elif kind == "undug":
			_paint_rock(rect, 10 + level * 6 + cell)
		elif kind == "dug":
			_draw_cavity(rect)
		elif room_type == "platform":
			_draw_platform(rect, cell)
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
			_draw_people(rect, room)
		if _under_water(spot, kind):
			_draw_water(rect, level, cell)
		var job := _job_text(level, cell, rect.size.x)
		if job != "":
			var font := ThemeDB.fallback_font
			draw_string(font, rect.position + Vector2(6, 16), job, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 13, Color("efe6d2"))
		elif hover == Vector2i(level, cell) and kind != "hidden":
			var tip := ""
			if kind == "undug":
				tip = "Dig"
			elif kind == "dug":
				tip = "Build here"
			elif kind == "room":
				tip = str(station.game.catalog.rooms[room_type].name)
			if tip != "":
				var bar := Rect2(rect.position.x, rect.position.y + rect.size.y - 20, rect.size.x, 20)
				draw_rect(bar, Color(0.05, 0.05, 0.06, 0.82))
				draw_string(ThemeDB.fallback_font, bar.position + Vector2(6, 14), tip, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 13, Color("efe6d2"))

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

	func _draw_cavity(rect: Rect2) -> void:
		_paint_rock(rect, 4)
		draw_rect(rect, Color(0.28, 0.22, 0.16, 0.28))
		var frame := rect.grow(-5.0)
		draw_rect(frame, Color(0.42, 0.28, 0.14), false, 4.0)
		draw_rect(frame.grow(-3.0), Color(0.22, 0.16, 0.1), false, 1.0)
		var glow := minf(rect.size.x, rect.size.y) * 0.28
		var lamp := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.34)
		draw_circle(lamp, glow, Color(0.95, 0.72, 0.32, 0.14))
		draw_circle(lamp, glow * 0.45, Color(1.0, 0.82, 0.45, 0.22))
		draw_circle(lamp, 3.5, Color(1.0, 0.9, 0.62, 0.8))

	func _draw_platform(rect: Rect2, cell: int) -> void:
		draw_rect(rect, Color(0.055, 0.058, 0.062))
		var x := rect.position.x + fmod(float(cell) * 7.0, 14.0)
		while x < rect.position.x + rect.size.x:
			draw_line(Vector2(x, rect.position.y + 2.0), Vector2(x, rect.position.y + rect.size.y - 16.0), Color(1, 1, 1, 0.045), 1.0)
			x += 14.0

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

	func _job_text(level: int, cell: int, width: float) -> String:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return "Dig %d" % int(digging.left)
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			return "%s %d" % [_short(str(building.type), width), int(building.left)]
		return ""

	func _draw_people(rect: Rect2, room: Dictionary) -> void:
		var n := int(room.staff.size())
		if n == 0:
			return
		var t := Time.get_ticks_msec() / 1000.0
		for i in n:
			var id := str(room.staff[i])
			var h := _id_hash(id)
			var span := rect.size.x * 0.78
			var jitter := fmod(h, span * 0.28) - span * 0.14
			var cx := rect.position.x + rect.size.x * 0.11 + span * (float(i) + 0.5) / float(n) + jitter
			cx = clampf(cx, rect.position.x + 8.0, rect.position.x + rect.size.x - 8.0)
			var bob := sin(t * 1.7 + h * 0.02) * 1.6
			var foot := Vector2(cx, rect.position.y + rect.size.y * 0.8 + bob)
			var scale := 18.0 + fmod(h, 8.0)
			var tint := Color.from_hsv(fmod(h * 0.013, 1.0), 0.35, 0.16)
			_silhouette(foot, scale + 2.0, Color(0.45, 0.36, 0.24, 0.85))
			_silhouette(foot, scale, tint)

	func _id_hash(id: String) -> float:
		var n := 17
		for i in id.length():
			n = (n * 33 + id.unicode_at(i)) % 100003
		return float(n)

	func _silhouette(foot: Vector2, scale: float, tint: Color) -> void:
		var head := foot + Vector2(0, -scale * 0.72)
		draw_circle(head, scale * 0.16, tint)
		var body := PackedVector2Array([
			foot + Vector2(-scale * 0.22, -scale * 0.5),
			foot + Vector2(scale * 0.22, -scale * 0.5),
			foot + Vector2(scale * 0.28, -scale * 0.22),
			foot + Vector2(scale * 0.1, -scale * 0.02),
			foot + Vector2(-scale * 0.1, -scale * 0.02),
			foot + Vector2(-scale * 0.28, -scale * 0.22),
		])
		draw_colored_polygon(body, tint)


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
