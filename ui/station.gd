extends Control

## Cut-away of the station. Placeholder shapes on a painted wall. The sim stays in charge of the week.

const INK := Color("efe6d2")
const MUTED := Color("b7aa96")
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
var chips := {}
var hope_label: Label
var dis_label: Label
var hope_fill: ColorRect
var dis_fill: ColorRect
var dim: ColorRect
var card: PanelContainer
var card_body: VBoxContainer
var portrait := false
var power_loss := {}
var notice := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font_size = 16
	self.theme = theme
	_build()
	get_window().size_changed.connect(_layout)
	var catalog := Catalog.new()
	if not catalog.load_all():
		footer.text = catalog.error
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


func _build() -> void:
	var backdrop := Backdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_bottom", 8)
	add_child(root)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	root.add_child(column)

	column.add_child(_top_bar())

	middle = VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(middle)

	wide_row = HBoxContainer.new()
	wide_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wide_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wide_row.add_theme_constant_override("separation", 10)
	middle.add_child(wide_row)

	stack = VBoxContainer.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	stack.visible = false
	middle.add_child(stack)

	yard = Yard.new()
	yard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	yard.custom_minimum_size = Vector2(360, 280)
	wide_row.add_child(yard)

	side = _side_panel()
	wide_row.add_child(side)

	footer = _label("", 14)
	footer.clip_text = true
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(footer)

	_build_overlay()


func _top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.1, 0.12, 0.92)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	box.add_child(title_row)
	week_label = _label("Week 1", 22)
	week_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(week_label)

	pump_button = _button("Pump", _ask_pump)
	pump_button.custom_minimum_size = Vector2(96, 48)
	title_row.add_child(pump_button)
	quarantine_button = _button("Quarantine", _ask_quarantine)
	quarantine_button.custom_minimum_size = Vector2(130, 48)
	title_row.add_child(quarantine_button)
	end_button = _button("End turn", _end_turn)
	end_button.custom_minimum_size = Vector2(140, 48)
	title_row.add_child(end_button)
	burn_button = _button("Burn salvage", _ask_burn)
	burn_button.custom_minimum_size = Vector2(150, 48)
	title_row.add_child(burn_button)
	power_button = _button("Power", _show_power)
	power_button.custom_minimum_size = Vector2(96, 48)
	title_row.add_child(power_button)

	forecast_button = _button("", _open_forecast)
	forecast_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	forecast_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	forecast_button.visible = false
	box.add_child(forecast_button)

	action_row = VBoxContainer.new()
	action_row.visible = false
	action_row.add_theme_constant_override("separation", 6)
	box.add_child(action_row)
	pump_row = HBoxContainer.new()
	pump_row.add_theme_constant_override("separation", 8)
	pump_row.visible = false
	action_row.add_child(pump_row)

	res_grid = GridContainer.new()
	res_grid.columns = 6
	res_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(res_grid)
	for key in STOCK_KEYS:
		var chip := VBoxContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		var name := _label(key.capitalize(), 14)
		name.add_theme_color_override("font_color", MUTED)
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		name.custom_minimum_size = Vector2(0, 18)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var value := _label("0", 20)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var delta := _label("—", 13)
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(name)
		chip.add_child(value)
		chip.add_child(delta)
		chip.gui_input.connect(_chip_input.bind(str(key)))
		res_grid.add_child(chip)
		chips[key] = {"box": chip, "name": name, "value": value, "delta": delta}

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 12)
	box.add_child(meters)
	meters.add_child(_meter("Hope", Color("d7a441"), true))
	meters.add_child(_meter("Discontent", Color("c4544a"), false))
	return panel


func _meter(title: String, fill_color: Color, hope: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lab := _label(title, 14)
	box.add_child(lab)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(0, 16)
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
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.1, 0.12, 0.9)))
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	var title := _label("Residents", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var auto := _button("Auto-staff", _auto_staff)
	auto.custom_minimum_size = Vector2(120, 48)
	head.add_child(auto)
	box.add_child(head)
	hint = _label("Drag a name onto a room, or tap a room and pick. Best fit is first.", 13)
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


func _build_overlay() -> void:
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.11, 0.12, 0.14, 0.98)))
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


func _mood_delta(n: int) -> String:
	if game.hope_history.is_empty():
		return "—"
	return _signed(n)


func _layout() -> void:
	portrait = size.y > size.x or size.x < 860
	res_grid.columns = 3 if size.x < 900 else 6
	var yard_parent: Node = stack if portrait else wide_row
	if yard.get_parent() != yard_parent:
		yard.get_parent().remove_child(yard)
		side.get_parent().remove_child(side)
		yard_parent.add_child(yard)
		yard_parent.add_child(side)
	wide_row.visible = not portrait
	stack.visible = portrait
	side.custom_minimum_size = Vector2(0, 200) if portrait else Vector2(340, 0)
	yard.custom_minimum_size = Vector2(280, 188 if portrait else 240)
	yard.size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if portrait:
		if end_button.get_parent() != action_row:
			end_button.get_parent().remove_child(end_button)
			action_row.add_child(end_button)
			action_row.move_child(end_button, 0)
		for button in [pump_button, quarantine_button]:
			if button.get_parent() != pump_row:
				button.get_parent().remove_child(button)
				pump_row.add_child(button)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size.y = 44
		end_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		end_button.custom_minimum_size.y = 44
		pump_row.visible = true
		action_row.visible = true
	else:
		pump_row.visible = false
		for button in [pump_button, quarantine_button, end_button]:
			if button.get_parent() != title_row:
				button.get_parent().remove_child(button)
				title_row.add_child(button)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			button.custom_minimum_size.y = 48
		action_row.visible = false
	_place_card()
	if yard != null:
		yard.queue_redraw()


func _place_card() -> void:
	if card == null:
		return
	var margin := 12.0 if portrait else 36.0
	var max_w := size.x - margin * 2.0
	if not portrait:
		max_w = minf(max_w, 640.0)
	var left := (size.x - max_w) / 2.0
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = left
	card.offset_right = left + max_w
	card.offset_top = margin
	card.offset_bottom = -margin


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
		chips[key].box.tooltip_text = str(outlook.text)
		var name_color := MUTED
		if bool(outlook.hit):
			name_color = Color("e0a15a")
		chips[key].name.add_theme_color_override("font_color", name_color)
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
	burn_button.text = "Burn salvage" if bool(burn.ok) else "Burn salvage — %s" % str(burn.reason)
	var outlook_rows: Array = game.forecasts()
	forecast_button.visible = not outlook_rows.is_empty()
	if not outlook_rows.is_empty():
		forecast_button.text = str(outlook_rows[0].text)
	_fill_people()
	yard.queue_redraw()
	if game.log.size() > 0:
		footer.text = str(game.log[game.log.size() - 1].text)


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


func _open_forecast_at(hint: String, level: int, cell: int) -> void:
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


func _show_room(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	if detail.is_empty():
		return
	_open_card(str(detail.name))
	if notice != "":
		_body(notice)
		notice = ""
	var level_names := ["Street", "Platform", "Deep"]
	_body("%s, cell %d." % [level_names[int(detail.level)], int(detail.cell) + 1])
	if bool(detail.offline):
		_body("Offline.")
	if str(detail.skill) != "":
		_body("Output is base × (1 + 0.15 for each skill point above 1), and it stops at 2.5×.")
		_body("This crew has %.0f points above 1, so the room runs at ×%.2f." % [float(detail.skill_extra), float(detail.multiplier)])
	if detail.outputs.is_empty():
		_body("No weekly output.")
	else:
		for out in detail.outputs:
			_body("%s %d a week, from a base of %.0f." % [str(out.key), int(out.amount), float(out.base)])
	_body("Draws %d power." % int(detail.power))
	_body("Staff %d / %d." % [detail.staff.size(), int(detail.staff_max)])
	for member in detail.staff:
		var row := HBoxContainer.new()
		var staff_line := "%s · %s %d" % [str(member.name), str(detail.skill), int(member.skill)]
		if str(member.traits) != "":
			staff_line += " · " + str(member.traits)
		var lab := _label(staff_line, 15)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)
		var off := _button("Off", _unassign.bind(str(member.id), uid))
		off.custom_minimum_size = Vector2(72, 48)
		row.add_child(off)
		card_body.add_child(row)
	if int(detail.staff_max) > 0:
		card_body.add_child(_button("Assign someone", _show_assign.bind(uid)))
	var up: Dictionary = game.upgrade_preview(uid)
	var up_text := "Upgrade"
	if str(up.name) != "":
		up_text = "Upgrade: %s (%d materials)" % [str(up.name).replace("_", " "), int(up.materials)]
	card_body.add_child(_button(up_text, _confirm_upgrade.bind(uid)))
	card_body.add_child(_button("Demolish", _confirm_demolish.bind(uid)))
	if str(detail.type) == "meeting_hall":
		card_body.add_child(_button("Laws", _show_laws))
	card_body.add_child(_button("Close", _close_card))


func _show_assign(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	_open_card("Assign to %s" % str(detail.name))
	var skill_name := str(detail.skill)
	_body("Best %s first. The number is that skill." % skill_name)
	var filter := LineEdit.new()
	filter.placeholder_text = "Filter names"
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
	_open_card("Dawn, week %d" % game.week)
	_body("Food %d, air %d, power %d, materials %d, tokens %d, influence %d." % [
		int(game.stock.food), int(game.stock.air), int(game.stock.power),
		int(game.stock.materials), int(game.stock.tokens), int(game.stock.influence)])
	_body("%d people. Hope %d (%s). Discontent %d (%s)." % [
		game.residents.size(), game.hope, _mood_delta(game.last_hope_delta),
		game.discontent, _mood_delta(game.last_dis_delta)])
	var lines := _morning_lines()
	if lines.is_empty():
		_body("No season warning, and no word from the tunnels.")
	for line in lines:
		_body(line)
	for row in game.forecasts():
		var forecast := _button(str(row.text), _open_forecast_at.bind(str(row.hint), int(row.level), int(row.cell)))
		forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast.custom_minimum_size.y = 72
		card_body.add_child(forecast)
	if game.pending.is_empty():
		_body("No one is waiting on a decision.")
		card_body.add_child(_button("To the platform", _close_card))
		return
	var ev: Dictionary = game.front_event()
	_heading(str(ev.title))
	_body(str(ev.text))
	for choice in ev.choices:
		var label := str(choice.label)
		var extra := _choice_bits(choice)
		if extra != "":
			label += "  (" + extra + ")"
		var pick := _button(label, _pick_event.bind(str(ev.id), str(choice.id)))
		if not game.afford_choice(choice):
			var why := game.shortage_text(choice.get("cost", {}))
			if why == "":
				why = "That cost cannot be paid."
			pick.disabled = true
			pick.text = "%s — %s" % [label, why]
			pick.custom_minimum_size.y = 72
		card_body.add_child(pick)
	if game.pending.size() > 1:
		_body("%d more waiting after this one." % (game.pending.size() - 1))
	card_body.add_child(_button("Close", _dismiss_dawn))


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
		_close_card()
		_refresh()
		return
	_close_card()
	_refresh()


func _open_card(heading: String) -> void:
	_wipe(card_body)
	_place_card()
	dim.visible = true
	var row := HBoxContainer.new()
	var lab := _label(heading, 20)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)
	var close := _button("Close", _close_card)
	close.custom_minimum_size = Vector2(88, 48)
	close.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(close)
	card_body.add_child(row)


func _close_card() -> void:
	dim.visible = false
	_wipe(card_body)


func _heading(text: String) -> void:
	card_body.add_child(_label(text, 20))


func _body(text: String) -> void:
	card_body.add_child(_label(text, 15))


func _label(text: String, size: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", INK)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _button(text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 15)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(cb)
	return button


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(10)
	style.set_corner_radius_all(6)
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
	_show_room(_room_uid("hydroponics"))
	await _frame()
	_save("room_panel")
	_show_dawn()
	await _frame()
	_save("dawn_report")
	_close_card()
	var bot := Bot.new()
	var guard := 0
	while game.week < 15 and game.over == "" and guard < 20:
		guard += 1
		bot._act(game)
		game.end_week()
	_refresh()
	_close_card()
	await _settle(Vector2i(1280, 720))
	_save("week15_cutaway")
	await _settle(Vector2i(420, 780))
	_save("portrait")
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
	const GAP := 8.0
	const LABEL_W := 84.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var hit: Dictionary = _hit(event.position)
			if not hit.is_empty():
				station._tap_cell(int(hit.level), int(hit.cell))
			accept_event()

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
		var geo := _geo()
		if geo.w < 4.0 or geo.h < 4.0:
			return {}
		for level in 3:
			for cell in 6:
				var rect := _rect(geo, level, cell)
				if rect.has_point(at_position):
					var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
					spot = spot.duplicate()
					spot.level = level
					spot.cell = cell
					return spot
		return {}

	func _geo() -> Dictionary:
		var label_w := 64.0 if size.x < 560.0 else LABEL_W
		var origin := Vector2(label_w, 8)
		var avail := size - origin - Vector2(8, 8)
		var w := (avail.x - GAP * 5.0) / 6.0
		var h := (avail.y - GAP * 2.0) / 3.0
		return {"origin": origin, "w": w, "h": h, "label_w": label_w}

	func _rect(geo: Dictionary, level: int, cell: int) -> Rect2:
		var origin: Vector2 = geo.origin
		return Rect2(
			origin.x + cell * (float(geo.w) + GAP),
			origin.y + level * (float(geo.h) + GAP),
			float(geo.w),
			float(geo.h))

	func _draw() -> void:
		if station == null or station.game == null:
			return
		var geo := _geo()
		var names: PackedStringArray = ["Street", "Platform", "Deep"] if size.x >= 560.0 else ["Street", "Plat", "Deep"]
		var font := ThemeDB.fallback_font
		var band := _rect(geo, 1, 0)
		draw_rect(Rect2(0, band.position.y - 4, size.x, band.size.y + 8), Color(0.55, 0.28, 0.12, 0.22))
		for level in 3:
			var sample := _rect(geo, level, 0)
			draw_string(font, Vector2(6, sample.position.y + sample.size.y * 0.55), names[level], HORIZONTAL_ALIGNMENT_LEFT, float(geo.label_w) - 8.0, 13 if size.x < 560.0 else 15, Color("efe6d2"))
			for cell in 6:
				_draw_cell(_rect(geo, level, cell), level, cell)
		var rail := _rect(geo, 1, 0)
		draw_line(
			Vector2(rail.position.x, rail.position.y + rail.size.y - 8),
			Vector2(size.x - 10, rail.position.y + rail.size.y - 8),
			Color("e2b15a"),
			3.0)

	func _draw_cell(rect: Rect2, level: int, cell: int) -> void:
		var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
		var kind := _kind(spot)
		var fill := Color(0.16, 0.15, 0.13)
		if kind == "hidden":
			fill = Color(0.07, 0.07, 0.08)
		elif kind == "undug":
			fill = Color(0.2, 0.16, 0.12)
		elif kind == "room":
			var room = station.game._room(str(spot.room))
			fill = ROOM_COLOR.get(str(room.type), Color("888888"))
		draw_rect(rect, fill)
		var losing: bool = kind == "room" and station.power_loss.has(str(spot.room))
		draw_rect(rect, Color("e07a6a") if losing else Color(0, 0, 0, 0.35), false, 3.0 if losing else 1.0)
		if losing:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x - 16, 16), "!", HORIZONTAL_ALIGNMENT_LEFT, 14, 16, Color("e07a6a"))
		if bool(spot.flooded):
			draw_rect(rect, Color(0.2, 0.35, 0.55, 0.45))
		var font := ThemeDB.fallback_font
		var caption := ""
		if kind == "hidden":
			caption = ""
		elif kind == "undug":
			caption = "Dig"
		elif kind == "dug":
			caption = "Open"
		elif kind == "room":
			var room = station.game._room(str(spot.room))
			caption = _short(str(room.type), rect.size.x)
			_draw_people(rect, room)
		var job := _job_text(level, cell, rect.size.x)
		if job != "":
			caption = job
			draw_rect(rect, Color(0, 0, 0, 0.35))
		if caption != "":
			var font_size := 12 if rect.size.x < 100.0 else 14
			draw_string(font, rect.position + Vector2(6, 16), caption, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, font_size, Color(0.08, 0.06, 0.05) if kind == "room" else Color("efe6d2"))

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
		var slot := minf(26.0, (rect.size.x - 8.0) / float(n))
		for i in n:
			var cx := rect.position.x + 6.0 + float(i) * slot + slot * 0.45
			var foot := rect.position.y + rect.size.y - 7.0
			var ink := Color(0.08, 0.06, 0.05)
			var head := maxf(3.0, slot * 0.22)
			draw_circle(Vector2(cx, foot - slot * 0.85), head, ink)
			draw_rect(Rect2(cx - slot * 0.18, foot - slot * 0.58, slot * 0.36, slot * 0.5), ink)
