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
const NetworkViewScript = preload("res://ui/network_view.gd")
const ArtPack = preload("res://ui/art_pack.gd")
const Brief = preload("res://sim/brief.gd")
const WAITING := "Someone is still waiting. Choose before the week ends."

var game: Game
var yard: Yard
var middle: VBoxContainer
var wide_row: HBoxContainer
var stack: VBoxContainer
var side: PanelContainer
var people_box: VBoxContainer
var people_scroll: ScrollContainer
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
var card_scroll: ScrollContainer
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
var source_panel: Panel
var source_body: Control
var source_pinned := false
var source_key := ""
var people_head: Label
var people_expand: Control
var people_tab: Button
var people_rail: PeopleRail
var people_filter := ""
var guide_layer: Control
var guide_card: PanelContainer
var guide_copy: Label
var guide_count: Label
var guide_next: Button
var guide_step := -1
var net_guide := false
var net_guided := false
var net_guide_sid := ""
var guide_played := false
var shot_mode := false
var menu_button: Button
var hub_button: Button
var network_button: Button
var network_view: Control
var showing_network := false
var hub_layer: Control
var hub_station_label: Label
var hub_community_label: Label
var hub_begin: Button
var hub_back: Button
var number_font: Font
var at_menu := false
var hold_dawn := false
var menu_layer: Control
var menu_root: Control
var menu_settings: VBoxContainer
var menu_credits: VBoxContainer
var continue_button: Button
var settings_from_game := false
var filling_settings := false
var stock_shown := {}
var stock_week := 0
var stock_tween: Tween
var modal_tween: Tween
var modal_open := false


func _ready() -> void:
	Copy.boot()
	Settings.load_file()
	ArtPack.adopt_icons()
	ArtPack.textures()
	ArtPack.fonts()
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
	Sound.boot(self)
	_audit_art()
	var catalog := Catalog.new()
	if not catalog.load_all():
		footer.text = catalog.error
		footer.visible = true
		return
	game = Game.new()
	game.setup(catalog, 1, 40)
	yard.station = self
	hold_dawn = true
	_refresh()
	hold_dawn = false
	resized.connect(_layout)
	_layout()
	if _want_shots() or _want_clarity() or _want_review() or _want_hub() or _want_polish() or _want_network():
		shot_mode = true
	if hub_button != null:
		hub_button.visible = _hub_texture() != null
	if not shot_mode:
		Settings.apply_display(get_window())
		Sound.apply_buses()
	if shot_mode:
		if not _want_hub() and not _want_polish() and not _want_network():
			_show_dawn()
	elif Settings.resume and game != null and SaveGame.load_latest(game):
		Settings.resume = false
		at_menu = false
		Sound.bed("station")
		_refresh()
		if Settings.reopen == "settings":
			Settings.reopen = ""
			_open_settings(true)
	else:
		_show_main_menu()
		if Settings.reopen == "settings":
			Settings.reopen = ""
			_open_settings(false)
	if _want_polish():
		await _polish_shots()
	elif _want_shots():
		await _shots()
	elif _want_clarity():
		await _clarity_shots()
	elif _want_review():
		await _review_shots()
	elif _want_hub():
		await _hub_shots()
	elif _want_network():
		await _network_shots()


func _want_shots() -> bool:
	return OS.get_cmdline_user_args().has("--shots") or OS.get_environment("UNDERLINE_SHOTS") == "1"


func _want_review() -> bool:
	return OS.get_cmdline_user_args().has("--review")


func _want_clarity() -> bool:
	return OS.get_cmdline_user_args().has("--clarity")


func _want_hub() -> bool:
	return OS.get_cmdline_user_args().has("--hub")


func _want_polish() -> bool:
	return OS.get_cmdline_user_args().has("--polish")


func _want_network() -> bool:
	return OS.get_cmdline_user_args().has("--network")


func _tabular(base: Font) -> Font:
	if base == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = base
	variation.opentype_features = {"tnum": 1}
	return variation


func _motion_off() -> bool:
	return shot_mode or Settings.reduced()


func _load_fonts() -> void:
	var courier := ArtPack.load_font("res://assets/fonts/CourierPrime-Regular.ttf")
	var mono := ArtPack.load_font("res://assets/fonts/PTMono-Regular.ttf", true)
	var shoulders := ArtPack.load_font("res://assets/fonts/BigShouldersDisplay.ttf")
	var oswald_file := ArtPack.load_font("res://assets/fonts/Oswald.ttf", true)
	var shoulders_face := _display_face(shoulders, 800.0)
	var oswald_face := _display_face(oswald_file, 700.0)
	if oswald_face != null and oswald_face.get_char_size(0x0410, 32).x <= 1.0:
		ArtPack.note("res://assets/fonts/Oswald.ttf")
		oswald_face = null
	# Courier and Big Shoulders have no Cyrillic. PT Mono and Oswald fill those glyphs.
	_attach(courier, mono)
	_attach(shoulders_face, oswald_face)
	if Copy.ru():
		body_font = mono if mono != null else _system_cyrillic()
		display_font = oswald_face if oswald_face != null else body_font
		return
	body_font = courier if courier != null else ThemeDB.fallback_font
	display_font = shoulders_face if shoulders_face != null else ThemeDB.fallback_font
	number_font = _tabular(body_font)


func _display_face(file: Font, weight: float) -> Font:
	if file == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = file
	# Integer OpenType tag for "wght". The string key is ignored and leaves the thin master.
	variation.set_variation_opentype({2003265652: weight})
	variation.get_string_size("Hg", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	return variation


func _attach(primary: Font, fallback: Font) -> void:
	if primary == null or fallback == null:
		return
	var next: Array[Font] = []
	next.append(fallback)
	primary.fallbacks = next


func _system_cyrillic() -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Segoe UI", "Arial"])
	return sys


func _load_portraits() -> void:
	portraits.clear()
	for i in range(1, 17):
		var tex := ArtPack.load_texture("res://assets/portraits/portrait_%02d.webp" % i)
		if tex != null:
			portraits.append(tex)


func _audit_art() -> void:
	ArtPack.audit()
	var count := ArtPack.missing.size()
	if count == 0 or not OS.is_debug_build():
		return
	var panel := PanelContainer.new()
	panel.name = "ArtWarning"
	panel.z_index = 200
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c83c32")
	style.set_content_margin_all(12)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)
	var lab := _label("Missing art: %d files" % count, 22, true)
	lab.add_theme_color_override("font_color", Color("fff6f2"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lab)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 72.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	panel.reset_size()


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
	var lab := _label(Copy.person(str(game.people[id].name)), 18)
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
	network_view = NetworkViewScript.new()
	network_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	network_view.visible = false
	add_child(network_view)

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
	end_button.set_meta("ui_sound", "")
	end_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	end_button.clip_text = true
	end_button.mouse_entered.connect(_show_ahead.bind(true))
	end_button.mouse_exited.connect(_show_ahead.bind(false))
	add_child(end_button)
	network_button = _button("Network", _toggle_network)
	network_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	network_button.add_theme_font_size_override("font_size", 16)
	add_child(network_button)
	hub_button = _button("Station view", _show_hub_view)
	hub_button.visible = false
	hub_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	hub_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	hub_button.add_theme_font_size_override("font_size", 16)
	add_child(hub_button)
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
	_build_source_panel()

	_build_overlay()


func _tool(kind: String, caption: String, cb: Callable) -> Button:
	var button := ToolButton.new()
	button.glyph_name = kind
	button.caption = Copy.t(caption)
	button.tooltip_text = Copy.t(caption)
	if Copy.ru() and display_font != null:
		button.set_meta("caption_font", display_font)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_ui_hover)
	button.pressed.connect(_ui_pressed.bind(button))
	button.pressed.connect(cb)
	_style_tool(button)
	return button


func _style_tool(button: Button) -> void:
	var style := _steel_style()
	style.set_content_margin_all(4)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.17, 0.2, 0.96)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
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
		chip.add_theme_constant_override("separation", 6)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.alignment = BoxContainer.ALIGNMENT_CENTER
		var icon_col := VBoxContainer.new()
		icon_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_col.alignment = BoxContainer.ALIGNMENT_CENTER
		icon_col.add_theme_constant_override("separation", 0)
		var icon := Glyph.new()
		icon.kind = str(key)
		var icon_px := 24 if ArtPack.icon_texture(str(key)) != null else 18
		icon.custom_minimum_size = Vector2(icon_px, icon_px)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name := _label(Copy.res(str(key)), 11)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		name.visible = false
		icon_col.add_child(icon)
		icon_col.add_child(name)
		var value := _label("0", 22)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if number_font != null:
			value.add_theme_font_override("font", number_font)
		var digit := 12.0
		if number_font != null:
			digit = number_font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		value.custom_minimum_size = Vector2(digit * 4.0 + 2.0, 26)
		var delta := _label("", 12)
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if number_font != null:
			delta.add_theme_font_override("font", number_font)
		var small := 8.0
		if number_font != null:
			small = number_font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		delta.custom_minimum_size = Vector2(small * 4.0 + 4.0, 16)
		chip.tooltip_text = Copy.res(str(key))
		chip.add_child(icon_col)
		chip.add_child(value)
		chip.add_child(delta)
		chip.gui_input.connect(_chip_input.bind(str(key)))
		chip.mouse_entered.connect(_peek_source.bind(str(key)))
		chip.mouse_exited.connect(_unpeek_source)
		res_grid.add_child(chip)
		chips[key] = {"box": chip, "value": value, "delta": delta, "icon": icon, "name": name}

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 12)
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(meters)
	meter_box = meters
	meters.add_child(_meter(Color("d7a441"), true))
	meters.add_child(_meter(Color("c4544a"), false))
	menu_button = _button("Menu", _show_menu)
	menu_button.custom_minimum_size = Vector2(84, 40)
	menu_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(menu_button)

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
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var meter_key := "hope" if hope else "discontent"
	box.gui_input.connect(_chip_input.bind(meter_key))
	box.mouse_entered.connect(_peek_source.bind(meter_key))
	box.mouse_exited.connect(_unpeek_source)
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
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	people_tab = Button.new()
	people_tab.focus_mode = Control.FOCUS_NONE
	people_tab.pressed.connect(_toggle_drawer)
	people_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	people_tab.mouse_entered.connect(_ui_hover)
	people_tab.pressed.connect(func(): Sound.play("click"))
	_style_tool(people_tab)
	people_tab.custom_minimum_size = Vector2(52, 72)
	people_rail = PeopleRail.new()
	people_rail.set_anchors_preset(Control.PRESET_FULL_RECT)
	people_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	people_rail.face = display_font if display_font != null else body_font
	people_tab.add_child(people_rail)
	box.add_child(people_tab)
	people_expand = VBoxContainer.new()
	people_expand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	people_expand.add_theme_constant_override("separation", 4)
	box.add_child(people_expand)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	people_head = _label("", 15, true)
	people_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	people_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(people_head)
	var shut := _button("×", _toggle_drawer)
	shut.custom_minimum_size = Vector2(40, 36)
	shut.alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(shut)
	people_expand.add_child(head)
	hint = _label("Drag a name onto a room, or tap a room and pick.", 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", MUTED)
	people_expand.add_child(hint)
	people_box = VBoxContainer.new()
	people_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_box.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	people_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(people_box)
	people_expand.add_child(scroll)
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
	_place_source()
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
	var hud_h := 90.0 if _guide_names() else 72.0
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
	if network_button != null:
		var net_w := 132.0
		network_button.anchor_left = 1.0
		network_button.anchor_right = 1.0
		network_button.anchor_top = 1.0
		network_button.anchor_bottom = 1.0
		network_button.custom_minimum_size = Vector2(net_w, tool_h)
		network_button.offset_right = -margin - end_w - 8.0
		network_button.offset_left = -margin - end_w - 8.0 - net_w
		network_button.offset_bottom = -margin
		network_button.offset_top = -margin - tool_h
		network_button.text = Copy.t("Station") if showing_network else Copy.t("Network")
	if hub_button != null and hub_button.visible:
		var view_w := 210.0
		var tray_right := margin + tool_w * 5.0 + 48.0
		var end_left := size.x - margin - end_w - 8.0
		var view_left := clampf((size.x - view_w) * 0.5, tray_right, maxf(tray_right, end_left - view_w))
		hub_button.anchor_left = 0.0
		hub_button.anchor_top = 0.0
		hub_button.anchor_right = 0.0
		hub_button.anchor_bottom = 0.0
		hub_button.custom_minimum_size = Vector2(view_w, tool_h)
		hub_button.offset_left = view_left
		hub_button.offset_top = size.y - margin - tool_h
		hub_button.offset_right = view_left + view_w
		hub_button.offset_bottom = size.y - margin
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
		var line := _label("%s %d" % [Copy.res(str(key)), int(proj.get(key, 0))], 16)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ahead_box.add_child(line)
	var hope_line := _label(Copy.t("Hope %d") % int(proj.get("hope", 0)), 16)
	hope_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ahead_box.add_child(hope_line)
	var dis_line := _label(Copy.t("Discontent %d") % int(proj.get("discontent", 0)), 16)
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
	side.visible = true
	var top := 78.0
	if hud != null and hud.size.y > 8.0:
		top = hud.size.y
	if people_expand != null:
		people_expand.visible = drawer_open
	if people_tab != null:
		people_tab.visible = not drawer_open
	var w := 56.0
	if drawer_open:
		w = minf(360.0, size.x * 0.42)
	side.offset_left = size.x - w
	side.offset_right = size.x
	side.offset_top = top
	side.offset_bottom = size.y - chrome_bottom
	if people_tab != null and not drawer_open:
		people_tab.custom_minimum_size = Vector2(52, maxf(72.0, side.offset_bottom - side.offset_top - 8.0))

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
	dim.z_index = 20
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
	card_scroll = scroll
	card_body = VBoxContainer.new()
	card_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card_body.add_theme_constant_override("separation", 8)
	scroll.add_child(card_body)


func _sticky_note(text: String) -> bool:
	if text == "":
		return false
	for key in ["That choice did not take.", "That did not happen.", "The hall did not pass that.", WAITING]:
		if text == key or text == Copy.t(key):
			return true
	return false


func _mood_delta(n: int) -> String:
	if game.hope_history.is_empty():
		return ""
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
		season = " · %s" % Copy.season(str(game.active_season.id))
	week_label.text = Copy.t("Week %d%s") % [game.week, season]
	var roll := stock_week > 0 and game.week != stock_week and not game.last_net.is_empty()
	_paint_stocks(roll)
	stock_week = game.week
	_sync_resource_names()
	for key in STOCK_KEYS:
		var delta_text := ""
		var color := MUTED
		if not game.last_net.is_empty():
			var d := int(game.last_net.get(key, 0))
			if d != 0:
				delta_text = "+%d" % d if d > 0 else str(d)
			if d > 0:
				color = DELTA_UP
			elif d < 0:
				color = DELTA_DOWN
		chips[key].delta.text = delta_text
		chips[key].delta.add_theme_color_override("font_color", color)
		var outlook: Dictionary = game.resource_outlook(str(key))
		chips[key].box.tooltip_text = "%s. %s" % [Copy.res(str(key)), str(outlook.text)]
		var value_color := INK
		if bool(outlook.hit):
			value_color = Color("e0a15a")
		chips[key].value.add_theme_color_override("font_color", value_color)
	power_loss = {}
	for uid in game.rooms_losing_power():
		power_loss[str(uid)] = true
	hope_label.text = Copy.t("Hope %d  %s") % [game.hope, _mood_delta(game.last_hope_delta)]
	dis_label.text = Copy.t("Discontent %d  %s") % [game.discontent, _mood_delta(game.last_dis_delta)]
	hope_fill.anchor_right = clampf(float(game.hope) / 100.0, 0.0, 1.0)
	dis_fill.anchor_right = clampf(float(game.discontent) / 100.0, 0.0, 1.0)
	end_button.text = Copy.t("End turn") if game.over == "" else _ending()
	var burn: Dictionary = game.burn_preview()
	burn_button.disabled = not bool(burn.ok) or game.over != ""
	burn_button.tooltip_text = Copy.t("Burn salvage") if bool(burn.ok) else Copy.t("Burn salvage. %s") % str(burn.reason)
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
	if people_box == null or game == null:
		return
	_wipe(people_box)
	var total := game.residents.size()
	var working := 0
	var grouped := {"free": [], "crew": []}
	var room_order: Array = []
	for person in game.residents:
		var id := str(person.id)
		var post := _person_post(id)
		if post == "room":
			working += 1
			var uid := _staff_room(id)
			if not grouped.has(uid):
				grouped[uid] = []
				room_order.append(uid)
			grouped[uid].append(person)
		elif post == "crew":
			working += 1
			grouped["crew"].append(person)
		else:
			grouped["free"].append(person)
	var free_n := total - working
	if people_head != null:
		people_head.text = _people_counts(total, working, free_n)
	if people_rail != null:
		people_rail.caption = _people_tab_caption(free_n)
		people_rail.ink = Color("e2a63a") if free_n > 0 else MUTED
		people_rail.queue_redraw()
	if people_filter != "":
		var clear := _button("All", _clear_people_filter)
		clear.custom_minimum_size.y = 36
		people_box.add_child(clear)
	if people_filter == "" or people_filter == "free":
		_people_group(Copy.t("Free"), grouped["free"], "", true)
	if people_filter != "free":
		for uid in room_order:
			if people_filter != "" and people_filter != uid:
				continue
			var room = game._room(uid)
			if room == null:
				continue
			var room_name := Copy.t(str(game.catalog.rooms[room.type].name))
			var skill := str(game.catalog.rooms[room.type].get("skill", ""))
			_people_group(room_name, grouped[uid], skill, false)
		if (people_filter == "" or people_filter == "crew") and not grouped["crew"].is_empty():
			_people_group(Copy.t("Crew"), grouped["crew"], "labor", false)
	if showing_network and network_view != null:
		network_view.refresh()


func _toggle_network() -> void:
	showing_network = not showing_network
	if network_view != null:
		network_view.visible = showing_network
		network_view.bind(self)
	if yard != null:
		yard.visible = not showing_network
	_place_chrome()


func _skill_line(person: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in ["care", "fight", "labor", "talk", "tech"]:
		if person.skills.has(key):
			bits.append("%s %d" % [Copy.skill(str(key)), int(person.skills[key])])
	return " · ".join(bits)


func _where(id: String) -> String:
	for room in game.rooms:
		for sid in room.staff:
			if str(sid) == id:
				return Copy.t(str(game.catalog.rooms[room.type].name))
	for wid in game._locked_ids():
		if str(wid) == id:
			return Copy.t("On a crew")
	var person: Dictionary = game.people[id]
	if int(person.sick) > 0:
		return Copy.t("Sick")
	if int(person.absent) > 0:
		return Copy.t("Away")
	return Copy.t("Unassigned")


func _staff_room(id: String) -> String:
	for room in game.rooms:
		for sid in room.staff:
			if str(sid) == id:
				return str(room.uid)
	return ""


func _person_post(id: String) -> String:
	if _staff_room(id) != "":
		return "room"
	for wid in game._locked_ids():
		if str(wid) == id:
			return "crew"
	return "free"


func _people_tab_caption(free_n: int) -> String:
	if Copy.ru():
		var word := "свободен" if _ru_singular(free_n) else "свободны"
		return "Люди %d %s" % [free_n, word]
	return "People %d free" % free_n


func _people_counts(total: int, working: int, free_n: int) -> String:
	if Copy.ru():
		var work_word := "работает" if _ru_singular(working) else "работают"
		var free_word := "свободен" if _ru_singular(free_n) else "свободны"
		return "Люди: %d · %s %d · %s %d" % [total, work_word, working, free_word, free_n]
	return "People: %d · working %d · free %d" % [total, working, free_n]


func _ru_singular(n: int) -> bool:
	var n_abs := absi(n) % 100
	if n_abs > 10 and n_abs < 20:
		return false
	return n_abs % 10 == 1


func _clear_people_filter() -> void:
	people_filter = ""
	_fill_people()


func _open_people_for(filter_id: String) -> void:
	people_filter = filter_id
	drawer_open = true
	_fill_people()
	_place_drawer()


func _people_group(title: String, members: Array, skill_name: String, highlight: bool) -> void:
	if members.is_empty() and not highlight:
		return
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 2)
	if highlight:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.86, 0.62, 0.28, 0.16)
		style.border_color = Color("e2a63a")
		style.set_border_width_all(1)
		style.set_content_margin_all(6)
		style.set_corner_radius_all(3)
		plate.add_theme_stylebox_override("panel", style)
		plate.add_child(wrap)
		people_box.add_child(plate)
	else:
		people_box.add_child(wrap)
	var heading := _label(title, 16, true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(heading)
	if members.is_empty():
		return
	for person in members:
		wrap.add_child(_people_row(person, skill_name))


func _people_row(person: Dictionary, skill_name: String) -> PersonRow:
	var id := str(person.id)
	var row := PersonRow.new()
	row.person_id = id
	row.person_name = Copy.person(str(person.name))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.picked.connect(_show_person)
	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_portrait_box(id, 28))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(Copy.person(str(person.name)), 15)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var skill_label := _label(_main_skill_text(person, skill_name), 13)
	skill_label.add_theme_color_override("font_color", MUTED)
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(skill_label)
	line.add_child(box)
	row.add_child(line)
	return row


func _main_skill_text(person: Dictionary, prefer: String) -> String:
	var key := prefer
	if key == "" or not person.skills.has(key):
		var best := 0
		key = "labor"
		for skill_key in ["labor", "tech", "care", "talk", "fight"]:
			var value := int(person.skills.get(skill_key, 0))
			if value > best:
				best = value
				key = skill_key
	return "%s %d" % [Copy.skill(key), int(person.skills.get(key, 0))]


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
		end_cover.tooltip_text = Copy.t(WAITING) if waiting else ""
	if waiting:
		end_button.tooltip_text = Copy.t(WAITING)
		end_button.add_theme_stylebox_override("disabled", _brass_style(false, false))
	elif game.over != "":
		end_button.tooltip_text = _ending()
	else:
		end_button.tooltip_text = Copy.t("End the week")


func _guide_names() -> bool:
	return game != null and int(game.week) == 1 and guide_step >= 0 and guide_layer != null and guide_layer.visible


func _sync_resource_names() -> void:
	var show_names := _guide_names()
	for key in chips:
		var name_label: Label = chips[key].name
		name_label.visible = show_names
	_place_chrome()


func _paint_stocks(roll: bool) -> void:
	if stock_tween != null:
		stock_tween.kill()
	var can_roll := roll and not _motion_off()
	if can_roll:
		stock_tween = create_tween()
	for key in STOCK_KEYS:
		var target := float(int(game.stock.get(key, 0)))
		var start := float(stock_shown.get(key, target))
		stock_shown[key] = target
		if can_roll and not is_equal_approx(start, target):
			stock_tween.parallel().tween_method(_set_stock_text.bind(str(key)), start, target, 0.45)
		else:
			_set_stock_text(target, str(key))


func _set_stock_text(value: float, key: String) -> void:
	if not chips.has(key):
		return
	chips[key].value.text = str(int(round(value)))


func _offer_pending() -> void:
	if hold_dawn or at_menu:
		return
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
	var before := {}
	for room in game.rooms:
		before[str(room.uid)] = true
	Sound.play("whoosh")
	game.end_week()
	if game.over == "" and yard != null:
		for room in game.rooms:
			if before.has(str(room.uid)):
				continue
			yard.flash_at(int(room.level), int(room.cell))
			Sound.play("built")
	if game.over == "" and not shot_mode:
		SaveGame.write_auto(game)
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
		_pin_source(key)


func _build_source_panel() -> void:
	source_panel = Panel.new()
	source_panel.visible = false
	source_panel.z_index = 40
	source_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	source_panel.add_theme_stylebox_override("panel", _paper_style())
	source_panel.mouse_entered.connect(_hold_source)
	source_panel.mouse_exited.connect(_unpeek_source)
	source_body = Control.new()
	source_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_panel.add_child(source_body)
	add_child(source_panel)


func _peek_source(key: String) -> void:
	if source_pinned and source_key == key:
		return
	if source_pinned:
		return
	_fill_source(key, false)


func _pin_source(key: String) -> void:
	if source_pinned and source_key == key:
		_hide_source()
		return
	_fill_source(key, true)


func _hold_source() -> void:
	source_pinned = source_pinned


func _unpeek_source() -> void:
	if source_pinned:
		return
	_hide_source()


func _hide_source() -> void:
	source_pinned = false
	source_key = ""
	if source_panel != null:
		source_panel.visible = false
	if yard != null:
		yard.glow = {}
		yard.queue_redraw()


func _fill_source(key: String, pin: bool) -> void:
	if game == null or source_body == null:
		return
	source_key = key
	source_pinned = pin
	_wipe(source_body)
	var info: Dictionary = Brief.source(game, key)
	var inner := _source_width() - 28.0
	on_paper = true
	source_body.add_child(_source_label(str(info.headline), 18, true, inner))
	source_body.add_child(_source_label(str(info.made), 15, false, inner))
	source_body.add_child(_source_label(str(info.used), 15, false, inner))
	var build_type := str(info.get("build_type", ""))
	if build_type != "":
		var room_name := Copy.t(str(game.catalog.rooms[build_type].name))
		source_body.add_child(_button(Copy.t("Build a %s") % room_name, _open_build_list))
	if pin:
		source_body.add_child(_button("Close", _hide_source))
	on_paper = false
	source_panel.visible = true
	if yard != null:
		var glow := {}
		for uid in info.get("rooms", []):
			glow[str(uid)] = true
		yard.glow = glow
		yard.queue_redraw()
	_place_source()


func _source_width() -> float:
	return minf(420.0, maxf(300.0, size.x - 24.0))


func _source_label(text: String, font_size: int, display: bool, inner: float) -> Label:
	var lab := _label(text, font_size, display)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var font: Font = body_font
	if display and display_font != null:
		font = display_font
	if font == null:
		font = ThemeDB.fallback_font
	var measured: Vector2 = font.get_multiline_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, inner, font_size)
	lab.custom_minimum_size = Vector2(inner, measured.y + 2.0)
	return lab


func _place_source() -> void:
	if source_panel == null or not source_panel.visible or source_body == null:
		return
	var width := _source_width()
	var inner := width - 28.0
	var y := 0.0
	for child in source_body.get_children():
		var h := 48.0
		if child is Label:
			h = maxf(float(child.custom_minimum_size.y), 18.0)
		elif child is Button:
			h = maxf(float(child.custom_minimum_size.y), 48.0)
			child.custom_minimum_size = Vector2(inner, h)
		child.position = Vector2(0, y)
		child.size = Vector2(inner, h)
		y += h + 8.0
	source_body.position = Vector2(14, 12)
	source_body.size = Vector2(inner, y)
	source_panel.position = Vector2(12, 64)
	source_panel.size = Vector2(width, y + 20.0)


func _open_build_list() -> void:
	_hide_source()
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if bool(spot.dug) and str(spot.room) == "":
				_show_build(level, cell)
				return
	_open_card("Build here")
	_body("No open floor. Dig a cell first.")
	card_body.add_child(_button("Close", _close_card))


func _show_resource(key: String) -> void:
	_pin_source(key)


func _ask_pump() -> void:
	var pump_cost := "%s and %d power." % [Words.count(int(game.bal.pump_materials), "material"), int(game.bal.pump_power)]
	if Copy.ru():
		pump_cost = "%s и %s." % [Words.count(int(game.bal.pump_materials), "material"), Copy.stock(int(game.bal.pump_power), "power")]
	var lines: PackedStringArray = [pump_cost]
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
	var lines: PackedStringArray = [Copy.t("The hall pulls the platform back from a revolt. Discontent %+d. Hope %+d.") % [int(game.bal.rally_discontent), int(game.bal.rally_hope)]]
	if why != "":
		lines.append(why)
	_confirm("Hold a rally?", lines, why == "", {"kind": "rally"})


func _ask_law(law_id: String) -> void:
	var defin: Dictionary = game.catalog.laws[law_id]
	var why := game.enact_reason(law_id)
	var lines: PackedStringArray = [_law_blurb(defin)]
	if why != "":
		lines.append(why)
	_confirm(Copy.t(str(defin.name)) + "?", lines, why == "", {"kind": "law", "law": law_id})


func _ask_repeal(law_id: String) -> void:
	var defin: Dictionary = game.catalog.laws[law_id]
	var why := game.repeal_reason(law_id)
	var lines: PackedStringArray = [Copy.t("Take %s off the books.") % Copy.t(str(defin.name))]
	if why != "":
		lines.append(why)
	_confirm(Copy.t("Repeal %s?") % Copy.t(str(defin.name)), lines, why == "", {"kind": "repeal", "law": law_id})


func _ask_burn() -> void:
	var info := game.burn_preview()
	var burn_line := "%s %s %d power this week. Hope %+d." % [Words.count(int(info.materials), "material"), "becomes" if int(info.materials) == 1 else "become", int(info.power), int(info.hope)]
	if Copy.ru():
		burn_line = "%s даёт %s на эту неделю. Надежда %+d." % [Words.count(int(info.materials), "material"), Copy.stock(int(info.power), "power"), int(info.hope)]
	var lines: PackedStringArray = [burn_line]
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
		var name := Copy.t(str(game.catalog.rooms[room.type].name))
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
			Copy.t("%s left.") % Words.count(int(game.dig.left), "week"),
			Copy.t("%s on the crew.") % Words.count(game.dig.workers.size(), "person", "people"),
		]
		_confirm("Dig this cell?", digging, false, {"kind": "dig", "level": level, "cell": cell}, "Dig", _brigade_busy_reason())
		return
	if not game.build.is_empty() and int(game.build.level) == level and int(game.build.cell) == cell:
		var name := str(game.catalog.rooms[str(game.build.type)].name)
		var building: PackedStringArray = [Copy.t("%s left.") % Words.count(int(game.build.left), "week")]
		_confirm(name, building, false, {})
		return
	if not bool(spot.dug):
		var info := game.dig_preview(level, cell)
		var lines: PackedStringArray = [
			Words.count(int(info.turns), "week"),
			Words.count(int(info.workers), "worker"),
			Words.count(int(info.materials), "material"),
		]
		var why := _brigade_busy_reason() if not game.dig.is_empty() else str(info.reason)
		_confirm("Dig this cell?", lines, bool(info.ok), {"kind": "dig", "level": level, "cell": cell}, "Dig", why)
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
	_body(Copy.t("Level %d, cell %d. An open floor.") % [level + 1, cell + 1])
	var banner := _build_banner()
	if banner != "":
		var band := _label(banner, 16, true)
		band.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.add_theme_color_override("font_color", Color("e2a63a"))
		card_body.add_child(band)
	for type in game.buildable_types():
		card_body.add_child(_build_card(str(type), level, cell))
	card_body.add_child(_button("Back", _close_card))


func _confirm_build(type: String, level: int, cell: int) -> void:
	var info := game.build_preview(type, level, cell)
	var lines: PackedStringArray = [
		"%s, %s, %s." % [Words.count(int(info.materials), "material"), Words.count(int(info.turns), "week"), Words.count(int(info.workers), "worker")],
		Copy.t("Power use once it is running: %d.") % int(info.power),
	]
	if str(info.reason) != "":
		lines.append(str(info.reason))
	_confirm(Copy.t("Build %s?") % Copy.t(str(info.name)), lines, bool(info.ok), {
		"kind": "build", "type": type, "level": level, "cell": cell,
	})


func _room_lead(detail: Dictionary) -> String:
	var bits: PackedStringArray = []
	for out in detail.outputs:
		bits.append(Copy.t("%s +%d / week") % [Copy.res(str(out.key)), int(out.amount)])
	bits.append(Copy.t("%d of %d crew") % [detail.staff.size(), int(detail.staff_max)])
	bits.append(Copy.t("uses %d power") % int(detail.power))
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
		var staff_line := "%s · %s %d" % [str(member.name), Copy.skill(str(detail.skill), false), int(member.skill)]
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
		var picks := _assign_picks(uid)
		if picks.is_empty():
			var blocked := ""
			for row in game.candidates_for(uid):
				if bool(row.here):
					continue
				var preview: Dictionary = game.assign_preview(str(row.id), uid)
				if not bool(preview.ok):
					blocked = str(preview.reason)
					break
			if blocked != "":
				_body(blocked)
		else:
			_body("Tap a name to assign.")
			for row in picks:
				card_body.add_child(_assign_row(uid, row))
	if str(detail.skill) != "":
		_body(Copy.t("%s from crew skill.") % _mult(float(detail.multiplier)))
	var up: Dictionary = game.upgrade_preview(uid)
	if str(up.get("name", "")) != "" or str(up.get("reason", "")) != "":
		card_body.add_child(_upgrade_card(uid, false))
	_body(Brief.demolish_line(game, uid))
	card_body.add_child(_button("Demolish", _confirm_demolish.bind(uid)))
	if str(detail.type) == "meeting_hall":
		card_body.add_child(_button("Laws", _show_laws))


func _show_assign(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	if not _claim(ModalDeck.AMBIENT, "assign", _show_assign.bind(uid)):
		return
	_open_card(Copy.t("Assign to %s") % Copy.t(str(detail.name)))
	var skill_name := str(detail.skill)
	_body(Copy.t("Best %s first. The number is that skill.") % Copy.skill(skill_name, false))
	var filter := LineEdit.new()
	filter.placeholder_text = Copy.t("Filter names")
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


func _fill_assign(uid: String, _skill_name: String, list: VBoxContainer, query: String) -> void:
	_wipe(list)
	var needle := query.strip_edges().to_lower()
	var shown := 0
	for row in _assign_picks(uid):
		var person_name := str(row.name)
		if needle != "" and not person_name.to_lower().contains(needle):
			continue
		shown += 1
		list.add_child(_assign_row(uid, row))
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
	if not _claim(ModalDeck.AMBIENT, "upgrade", _confirm_upgrade.bind(uid)):
		return
	_open_card("Upgrade?")
	if str(info.get("name", "")) == "" and str(info.reason) != "":
		_blocked_pair("Upgrade", str(info.reason))
	else:
		card_body.add_child(_upgrade_card(uid, true))
		if bool(info.ok):
			card_body.add_child(_button("Upgrade", _do_confirm.bind({"kind": "upgrade", "room": uid})))
		else:
			_blocked_pair("Upgrade", str(info.reason))
	card_body.add_child(_button("Back", _close_card))


func _confirm_demolish(uid: String) -> void:
	var info := game.demolish_preview(uid)
	var lines: PackedStringArray = [Brief.demolish_line(game, uid)]
	if str(info.reason) != "":
		lines.append(str(info.reason))
	_confirm(Copy.t("Pull down %s?") % Copy.t(str(info.name)), lines, bool(info.ok), {"kind": "demolish", "room": uid})


func _show_laws() -> void:
	if not _claim(ModalDeck.AMBIENT, "laws", _show_laws):
		return
	_open_card("Laws")
	if not game._room_ready("meeting_hall"):
		_body(Copy.t("Staff the meeting hall. The hall can pass one law, then it waits %s.") % Words.count(int(game.bal.law_cooldown), "week"))
	elif game.law_lock > 0:
		_body(Copy.t("A law was just passed. The next one is %s away.") % Words.count(game.law_lock, "week"))
	else:
		_body(Copy.t("One law this sitting. The next sitting is %s later.") % Words.count(int(game.bal.law_cooldown), "week"))
	for id in game.catalog.laws:
		var defin: Dictionary = game.catalog.laws[id]
		_heading(Copy.t(str(defin.name)))
		_body(_law_blurb(defin))
		if game.laws_on.has(id):
			_body("In force.")
		else:
			var why := game.enact_reason(str(id))
			var label := Copy.t("Enact %s") % Copy.t(str(defin.name))
			if why == "":
				card_body.add_child(_button(label, _enact.bind(str(id))))
			else:
				_blocked_pair(label, why)
	card_body.add_child(_button("Close", _close_card))


func _enact(law_id: String) -> void:
	if not game.apply({"kind": "law", "law": law_id}):
		footer.text = Copy.t("The hall did not pass that.")
		footer.visible = true
		_show_laws()
		return
	_refresh()
	_show_laws()


func _law_blurb(defin: Dictionary) -> String:
	var bits: PackedStringArray = []
	if defin.has("power"):
		bits.append(Copy.t("The charter adds %d power.") % int(defin.power))
	if defin.has("dig_faster"):
		bits.append(Copy.t("Digs finish %s sooner.") % Words.count(int(defin.dig_faster), "week"))
	if defin.has("food_mult"):
		bits.append(Copy.t("Food use ×%s.") % str(defin.food_mult))
	if defin.has("prod_mult"):
		bits.append(Copy.t("Room output ×%s.") % str(defin.prod_mult))
	if defin.has("hope_week"):
		bits.append(Copy.t("Hope %+d each week.") % int(defin.hope_week))
	if defin.has("discontent_week"):
		bits.append(Copy.t("Discontent %+d each week.") % int(defin.discontent_week))
	if defin.has("tokens_week"):
		bits.append(Copy.t("Tokens %+d each week.") % int(defin.tokens_week))
	if defin.has("influence_mult"):
		bits.append(Copy.t("Influence ×%s.") % str(defin.influence_mult))
	if defin.has("synod"):
		bits.append(Copy.t("Synod %+d when someone Devout is home.") % int(defin.synod))
	if defin.has("devout_hope"):
		bits.append(Copy.t("A Devout resident adds %+d Hope.") % int(defin.devout_hope))
	if defin.has("squad_bonus"):
		bits.append(Copy.t("The platform guard gains %d.") % int(defin.squad_bonus))
	if defin.has("sick_chance"):
		bits.append(Copy.t("Crews can fall sick (%.0f%%).") % (float(defin.sick_chance) * 100.0))
	if defin.has("materials_on_enact"):
		bits.append(Copy.t("Materials %+d when passed.") % int(defin.materials_on_enact))
	if defin.has("hope_on_enact"):
		bits.append(Copy.t("Hope %+d when passed.") % int(defin.hope_on_enact))
	if defin.has("discontent_on_enact"):
		bits.append(Copy.t("Discontent %+d when passed.") % int(defin.discontent_on_enact))
	if defin.has("opinion_on_enact"):
		bits.append(Copy.t("Every rival's opinion %+d.") % int(defin.opinion_on_enact))
	return " ".join(bits)


func _show_dawn() -> void:
	shelved_event = ""
	if not _claim(ModalDeck.NARRATIVE, "dawn", _show_dawn):
		return
	if footer.text == WAITING or footer.text == Copy.t(WAITING):
		footer.text = ""
		footer.visible = false
	var lines := _morning_lines()
	if game.pending.is_empty():
		_open_card(Copy.t("Dawn, week %d") % game.week)
		_intent_row(lines)
		_morning_notes(lines)
		_dawn_alert()
		_body("No one is waiting on a decision.")
		card_body.add_child(_button("To the platform", _close_card))
		return
	Sound.play("card")
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
				why = Copy.t("That cost cannot be paid.")
			pick.disabled = true
			pick.tooltip_text = why
			_body(why)
		card_body.add_child(pick)
	if game.pending.size() > 1:
		_body(Copy.t("%s waiting after this one.") % Words.count(game.pending.size() - 1, "other", "others"))
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
		_body(Copy.gloss(line))
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
	var path := "res://assets/events/%s.webp" % event_id
	if not ArtPack.has_event_art(event_id):
		return null
	var tex := ArtPack.load_texture(path)
	if tex == null:
		return null
	var banner := TextureRect.new()
	banner.texture = tex
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
		elif w == game.week - 1 and bool(entry.important) and _starts(text, ["SHORT", "ROT", "AGENT", "SEASON", "JOIN", "ULTIMATUM", "FIND", "BATTLE", "DEFECT", "REVOLT", "DEAL", "PREACH", "WARN"]):
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
		footer.text = Copy.t("That choice did not take.")
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
		_maybe_guide()
		return
	if str(game.front_event().get("id", "")) == before:
		_close_card()
		return
	_show_dawn()


func _show_ending() -> void:
	if not _claim(ModalDeck.NARRATIVE, "ending", _show_ending):
		return
	_open_card(_ending())
	_body(Copy.t("Week %d. Food %d, air %d, power %d, materials %d.") % [
		game.week, int(game.stock.food), int(game.stock.air), int(game.stock.power), int(game.stock.materials)])
	_body(Copy.t("Hope %d. Discontent %d. %s.") % [game.hope, game.discontent, Words.count(game.residents.size(), "person", "people")])
	card_body.add_child(_button("Close", _close_card))


func _ending() -> String:
	match game.over:
		"time":
			return Copy.t("Forty weeks. The yard is still yours.")
		"revolt":
			return Copy.t("The platform turned.")
		"hope":
			return Copy.t("Hope ran out.")
		"collapse":
			return Copy.t("The stores gave out.")
		"capital":
			return Copy.t("The capital was lost.")
		"error":
			return Copy.t("The week broke.")
		_:
			return Copy.t("The run is over.")


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
	var button := _button(label, cb, "confirm")
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


func _confirm(heading: String, lines: PackedStringArray, ok: bool, action: Dictionary, verb: String = "Confirm", reason: String = "") -> void:
	if not _claim(ModalDeck.AMBIENT, "confirm", _confirm.bind(heading, lines, ok, action, verb, reason)):
		return
	_open_card(heading)
	var shown := lines
	var why := reason
	var ready := ok and not action.is_empty()
	if not ready and why == "" and lines.size() > 0:
		why = str(lines[lines.size() - 1])
		shown = lines.slice(0, lines.size() - 1)
	for line in shown:
		_body(Copy.gloss(line))
	if ready:
		card_body.add_child(_button(verb, _do_confirm.bind(action), ""))
	else:
		_blocked_pair(verb, why)
	card_body.add_child(_button("Back", _close_card))


func _do_confirm(action: Dictionary) -> void:
	if action.is_empty() or not game.apply(action):
		Sound.play("error")
		footer.text = Copy.t("That did not happen.")
		footer.visible = true
		_close_card()
		_refresh()
		return
	var kind := str(action.get("kind", ""))
	if kind == "dig":
		Sound.play("thud")
	else:
		Sound.play("confirm")
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
	_reveal_modal()


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
	_hide_modal()
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
	lab.text = Copy.t(text)
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


func _button(text: String, cb: Callable, sound: String = "click") -> Button:
	var button := Button.new()
	button.text = Copy.t(text)
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
	button.custom_minimum_size.y = 64 if Copy.ru() else 48
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_ui_hover)
	button.set_meta("ui_sound", sound)
	button.pressed.connect(_ui_pressed.bind(button))
	button.pressed.connect(cb)
	return button


func _ui_hover() -> void:
	Sound.play("hover")


func _ui_pressed(button: Button) -> void:
	if button.disabled:
		return
	Sound.play(str(button.get_meta("ui_sound", "click")))


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


func _style_primary(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_color_override("font_color", INK_DARK)
	button.add_theme_color_override("font_disabled_color", Color("1a1008"))
	button.add_theme_stylebox_override("normal", _brass_style(false))
	button.add_theme_stylebox_override("hover", _brass_style(false))
	button.add_theme_stylebox_override("pressed", _brass_style(true))
	button.add_theme_stylebox_override("disabled", _brass_style(false, false))


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


func _blocked_pair(label: String, reason: String) -> void:
	card_body.add_child(_lock_button(label))
	var why := reason.strip_edges()
	if why == "":
		return
	var lab := _label(why, 14)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_color_override("font_color", DELTA_DOWN)
	card_body.add_child(lab)


func _lock_button(label: String) -> Button:
	var button := _button(label, func() -> void: pass)
	button.disabled = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.modulate = Color(1, 1, 1, 0.4)
	var face := _button_face(false, false)
	button.add_theme_stylebox_override("hover", face)
	button.add_theme_stylebox_override("pressed", face)
	button.add_theme_stylebox_override("disabled", face)
	var lock := Glyph.new()
	lock.kind = "lock"
	lock.ink = PAPER_INK if on_paper else INK
	lock.custom_minimum_size = Vector2(16, 16)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	lock.offset_left = -30.0
	lock.offset_right = -10.0
	lock.offset_top = -8.0
	lock.offset_bottom = 8.0
	button.clip_contents = true
	button.add_child(lock)
	return button


func _brigade_busy_reason() -> String:
	if game.dig.is_empty():
		return ""
	var left := int(game.dig.left)
	var free_week := int(game.week) + maxi(left, 1)
	if left <= 1:
		return Copy.t("Brigade is busy until next week (week %d).") % free_week
	return Copy.t("Brigade is busy until week %d.") % free_week


func _build_banner() -> String:
	if game.build.is_empty():
		return ""
	var name := Copy.t(str(game.catalog.rooms[str(game.build.type)].name))
	return Copy.t("Building %s, ready in %s.") % [name, Words.count(int(game.build.left), "week")]


func _build_card(type: String, level: int, cell: int) -> Control:
	var defin: Dictionary = game.catalog.rooms[type]
	var info := game.build_preview(type, level, cell)
	var building := not game.build.is_empty()
	var enabled := bool(info.ok) and not building
	var panel := _option_card(enabled, _confirm_build.bind(type, level, cell))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_room_thumb(type))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	var title := _label(Copy.t(str(defin.name)), 18, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	text.add_child(_makes_line(type, defin))
	text.add_child(_cost_line(info, defin, building))
	if not enabled:
		var lock := Glyph.new()
		lock.kind = "lock"
		lock.ink = PAPER_INK
		lock.custom_minimum_size = Vector2(16, 16)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_END
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(lock)
	row.add_child(text)
	panel.add_child(row)
	return panel


func _option_card(enabled: bool, cb: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 96
	panel.add_theme_stylebox_override("panel", _button_face(false, false))
	if enabled:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				cb.call()
		)
		panel.mouse_entered.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", _button_face(false, true))
		)
		panel.mouse_exited.connect(func() -> void:
			panel.add_theme_stylebox_override("panel", _button_face(false, false))
		)
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.modulate = Color(1, 1, 1, 0.4)
	return panel


func _room_thumb(type: String) -> TextureRect:
	var face := TextureRect.new()
	if yard != null:
		face.texture = yard.art.get(type, null)
	face.custom_minimum_size = Vector2(104, 72)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


func _makes_line(type: String, defin: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var base: Dictionary = defin.get("base", {})
	if not base.is_empty():
		var key := str(base.keys()[0])
		var span := Brief.output_span(game, type)
		row.add_child(_mini_glyph(key))
		var text := Copy.t("+%d / wk") % span.x
		if span.x != span.y:
			text = Copy.t("+%d…%d / wk") % [span.x, span.y]
		var lab := _label(text, 15)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lab)
		return row
	var words := ""
	var glyph := ""
	if type == "quarters":
		words = Copy.t("Housing %d") % int(defin.get("housing", 0))
		glyph = "people"
	elif type == "meeting_hall":
		words = Copy.t("Laws")
		glyph = "influence"
	elif type == "radio":
		words = Copy.t("Reveals intents")
	elif type == "infirmary":
		words = Copy.t("Clears sickness")
		glyph = "quarantine"
	if glyph != "":
		row.add_child(_mini_glyph(glyph))
	var lab := _label(words, 15)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	return row


func _cost_line(info: Dictionary, defin: Dictionary, building: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var mats := int(info.get("materials", defin.get("materials", 0)))
	var weeks := maxi(int(info.get("turns", defin.get("build_turns", 1))), 1)
	var crew := int(info.get("workers", game.bal.build_workers))
	var power := int(info.get("power", defin.get("power", 0)))
	var mat_short := int(game.stock.materials) < mats
	var crew_short := int(game._free_count()) < crew
	var spare := int(game.output_of("power")) - int(game._weekly_draw("power"))
	var power_short := power > 0 and spare < power
	if building:
		mat_short = false
		crew_short = false
		power_short = false
	_cost_bit(row, "materials", str(mats), mat_short)
	row.add_child(_dot())
	_cost_bit(row, "clock", Copy.t("%d wk") % weeks, false)
	row.add_child(_dot())
	_cost_bit(row, "people", str(crew), crew_short)
	if power > 0:
		row.add_child(_dot())
		_cost_bit(row, "power", str(power), power_short)
	return row


func _cost_bit(row: HBoxContainer, kind: String, text: String, short: bool) -> void:
	var ink := DELTA_DOWN if short else PAPER_INK
	var icon := _mini_glyph(kind)
	icon.ink = ink
	row.add_child(icon)
	var lab := _label(text, 14)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", ink)
	row.add_child(lab)


func _dot() -> Label:
	var lab := _label("·", 14)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", PAPER_MUTED)
	return lab


func _mini_glyph(kind: String) -> Glyph:
	var icon := Glyph.new()
	icon.kind = kind
	icon.ink = PAPER_INK if on_paper else INK
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _upgrade_card(uid: String, embedded: bool) -> Control:
	var info := game.upgrade_preview(uid)
	var room = game._room(uid)
	var enabled := bool(info.ok)
	var panel := _option_card(enabled and not embedded, _confirm_upgrade.bind(uid))
	if embedded:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.modulate = Color(1, 1, 1, 1)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if room != null:
		row.add_child(_room_thumb(str(room.type)))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	var uname := str(info.get("name", "")).replace("_", " ")
	if uname != "":
		var title := _label(uname, 18, true)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(title)
	var changes: Array = Brief.upgrade_changes(game, uid)
	if changes.is_empty():
		var stay := _label("the weekly numbers stay", 14)
		stay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(stay)
	else:
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 4)
		var first := true
		for change in changes:
			if not first:
				line.add_child(_dot())
			first = false
			_change_bit(line, change)
		var per := _label("/ wk", 14)
		per.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(per)
		text.add_child(line)
	var cost := HBoxContainer.new()
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_theme_constant_override("separation", 4)
	var cost_lab := _label("cost", 14)
	cost_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_lab.add_theme_color_override("font_color", DELTA_DOWN)
	cost.add_child(cost_lab)
	var cost_icon := _mini_glyph("materials")
	cost_icon.ink = DELTA_DOWN
	cost.add_child(cost_icon)
	var cost_n := _label(str(int(info.get("materials", 0))), 14)
	cost_n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_n.add_theme_color_override("font_color", DELTA_DOWN)
	cost.add_child(cost_n)
	text.add_child(cost)
	if not enabled and not embedded:
		var why := _label(str(info.get("reason", "")), 13)
		why.mouse_filter = Control.MOUSE_FILTER_IGNORE
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.add_theme_color_override("font_color", DELTA_DOWN)
		text.add_child(why)
		var lock := Glyph.new()
		lock.kind = "lock"
		lock.ink = PAPER_INK
		lock.custom_minimum_size = Vector2(16, 16)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(lock)
	row.add_child(text)
	panel.add_child(row)
	return panel


func _change_bit(row: HBoxContainer, change: Dictionary) -> void:
	row.add_child(_mini_glyph(str(change.key)))
	var before := _label("+%d" % int(change.before), 14)
	before.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(before)
	var arrow := _mini_glyph("arrow")
	row.add_child(arrow)
	var after := _label("+%d" % int(change.after), 14)
	after.mouse_filter = Control.MOUSE_FILTER_IGNORE
	after.add_theme_color_override("font_color", DELTA_UP if bool(change.gain) else DELTA_DOWN)
	row.add_child(after)


func _assign_picks(uid: String) -> Array:
	var rows: Array = []
	for row in game.candidates_for(uid):
		if bool(row.here):
			continue
		var preview: Dictionary = game.assign_preview(str(row.id), uid)
		if not bool(preview.ok):
			continue
		var effect: Dictionary = Brief.marginal(game, uid, str(row.id))
		var copy: Dictionary = row.duplicate()
		copy["delta"] = int(effect.delta)
		copy["out_key"] = str(effect.key)
		copy["note"] = str(effect.note)
		rows.append(copy)
	rows.sort_custom(func(a, b):
		if int(a.delta) != int(b.delta):
			return int(a.delta) > int(b.delta)
		return int(a.skill) > int(b.skill)
	)
	return rows


func _assign_row(uid: String, row: Dictionary) -> Control:
	var button := _button("", _assign_person.bind(str(row.id), uid))
	button.text = ""
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_right = -8
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(box)
	box.add_child(_portrait_box(str(row.id), 36))
	var bits: PackedStringArray = [str(row.name)]
	var detail: Dictionary = game.room_detail(uid)
	bits.append("%s %d" % [Copy.skill(str(detail.skill)), int(row.skill)])
	if str(row.traits) != "":
		bits.append(str(row.traits))
	var effect := _effect_text(row)
	if effect != "":
		bits.append(effect)
	var lab := _label(" · ".join(bits), 14)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(lab)
	var other := _other_room_name(str(row.id), uid)
	if other != "":
		var grey := _label(other, 13)
		grey.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grey.add_theme_color_override("font_color", PAPER_MUTED)
		box.add_child(grey)
		button.set_meta("other_room", true)
	return button


func _effect_text(row: Dictionary) -> String:
	var key := str(row.get("out_key", ""))
	if key != "":
		var word := Copy.res(key)
		if word.length() > 0:
			word = word.substr(0, 1).to_lower() + word.substr(1)
		return Copy.t("+%d %s / wk") % [int(row.delta), word]
	var note := str(row.get("note", ""))
	if note == "":
		return ""
	return Copy.t(note)


func _other_room_name(person_id: String, uid: String) -> String:
	for room in game.rooms:
		if str(room.uid) == uid:
			continue
		for sid in room.staff:
			if str(sid) == person_id:
				return Copy.t(str(game.catalog.rooms[room.type].name))
	return ""


func _show_menu() -> void:
	if not _claim(ModalDeck.AMBIENT, "menu", _show_menu):
		return
	_open_card("Menu")
	card_body.add_child(_button("Save", _manual_save))
	var load_button := _button("Load", _manual_load)
	load_button.disabled = not SaveGame.has_manual()
	if load_button.disabled:
		load_button.tooltip_text = Copy.t("No saved game.")
	card_body.add_child(load_button)
	card_body.add_child(_button("Settings", _open_settings.bind(true)))
	card_body.add_child(_button("Guide", _replay_guide))
	card_body.add_child(_button("Main menu", _back_to_menu))
	card_body.add_child(_button("Close", _close_card))


func _replay_guide() -> void:
	_close_card()
	guide_played = false
	_start_guide()


func _maybe_guide() -> void:
	if shot_mode or game == null:
		return
	if not deck.is_empty():
		return
	if not guide_played and int(game.week) == 1:
		_start_guide()
		return
	if not net_guided and int(game.week) >= 4:
		_start_net_guide()


func _start_net_guide() -> void:
	net_guided = true
	net_guide_sid = game.nearest_neutral()
	if net_guide_sid == "":
		return
	if not showing_network:
		_toggle_network()
	if network_view != null:
		network_view.focus_station(net_guide_sid)
	net_guide = true
	guide_step = 0
	if guide_layer == null:
		_build_guide()
	guide_layer.visible = true
	_fill_guide()


func _start_guide() -> void:
	guide_played = true
	guide_step = 0
	if guide_layer == null:
		_build_guide()
	guide_layer.visible = true
	_fill_guide()
	_sync_resource_names()


func _skip_guide() -> void:
	net_guide = false
	guide_step = -1
	guide_played = true
	if guide_layer != null:
		guide_layer.visible = false
	_sync_resource_names()


func _advance_guide() -> void:
	if net_guide:
		_skip_guide()
		return
	guide_step += 1
	if guide_step >= 5:
		_skip_guide()
		return
	_fill_guide()


func _guide_lines() -> PackedStringArray:
	return PackedStringArray([
		"Stocks sit up here. Tap one to see where it comes from.",
		"Dig a rock cell that touches an open floor.",
		"Build a room on an open floor.",
		"Assign people to a room. Open People, then tap a name.",
		"End the turn. Dawn reports what the week changed.",
	])


func _fill_guide() -> void:
	if guide_copy == null or guide_step < 0:
		return
	if net_guide:
		guide_copy.text = game.trade_pitch(net_guide_sid)
		guide_count.text = "1 / 1"
		guide_next.text = Copy.t("Done")
		return
	var lines := _guide_lines()
	guide_copy.text = Copy.t(lines[guide_step])
	guide_count.text = "%d / %d" % [guide_step + 1, lines.size()]
	guide_next.text = Copy.t("Done") if guide_step >= lines.size() - 1 else Copy.t("Next")
	if guide_step == 3:
		drawer_open = true
		people_filter = "free"
		_fill_people()
		_place_drawer()


func _build_guide() -> void:
	guide_layer = GuideLayer.new()
	guide_layer.host = self
	guide_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	guide_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_layer.z_index = 12
	add_child(guide_layer)
	guide_card = PanelContainer.new()
	guide_card.mouse_filter = Control.MOUSE_FILTER_STOP
	guide_card.add_theme_stylebox_override("panel", _paper_style())
	guide_card.custom_minimum_size = Vector2(340, 0)
	guide_layer.add_child(guide_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	guide_card.add_child(box)
	guide_count = _label("1 / 5", 13)
	guide_count.add_theme_color_override("font_color", PAPER_MUTED)
	box.add_child(guide_count)
	guide_copy = _label("", 16)
	guide_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_copy.custom_minimum_size = Vector2(320, 0)
	guide_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(guide_copy)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	guide_next = _button("Next", _advance_guide)
	guide_next.custom_minimum_size = Vector2(120, 40)
	guide_next.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var skip := _button("Skip", _skip_guide)
	skip.custom_minimum_size = Vector2(120, 40)
	skip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(guide_next)
	actions.add_child(skip)
	box.add_child(actions)


func _guide_target() -> Rect2:
	if net_guide and network_view != null:
		return network_view.station_anchor(net_guide_sid, self)
	match guide_step:
		0:
			if res_grid != null:
				return _control_rect(res_grid)
		1:
			var dig_at := _guide_cell(false)
			if dig_at.x >= 0 and yard != null:
				return yard.cell_screen(dig_at.x, dig_at.y)
		2:
			var floor := _first_open_floor()
			if yard != null:
				return yard.cell_screen(floor.x, floor.y)
		3:
			if people_button != null:
				return _control_rect(people_button)
		4:
			if end_button != null:
				return _control_rect(end_button)
	return Rect2()


func _control_rect(node: Control) -> Rect2:
	var g := node.get_global_rect()
	var origin := get_global_rect().position
	return Rect2(g.position - origin, g.size)


func _guide_cell(open_floor: bool) -> Vector2i:
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if str(spot.room) != "":
				continue
			if open_floor and bool(spot.dug):
				return Vector2i(level, cell)
			if not open_floor and not bool(spot.dug) and game._beside_dug(spot):
				return Vector2i(level, cell)
	return Vector2i(-1, -1)


func _show_person(person_id: String) -> void:
	if not game.people.has(person_id):
		return
	if not _claim(ModalDeck.AMBIENT, "person", _show_person.bind(person_id)):
		return
	var person: Dictionary = game.people[person_id]
	_open_card(Copy.person(str(person.name)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_portrait_box(person_id, 64))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label(_skill_line(person), 14))
	var traits := Copy.trait_list(person.get("traits", []))
	if traits != "":
		text.add_child(_label(traits, 14))
	text.add_child(_label(_where(person_id), 14))
	row.add_child(text)
	card_body.add_child(row)
	if bool(person.get("core", false)):
		card_body.add_child(_button("Dossier", _show_dossier.bind(person_id)))
	card_body.add_child(_button("Close", _close_card))


func _show_dossier(person_id: String) -> void:
	if not game.people.has(person_id):
		return
	if not _claim(ModalDeck.AMBIENT, "dossier", _show_dossier.bind(person_id)):
		return
	var person: Dictionary = game.people[person_id]
	_open_card(Copy.t("Dossier"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_portrait_box(person_id, 72))
	var who := _label(Copy.person(str(person.name)), 22, true)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	card_body.add_child(row)
	_heading("Before the Silence")
	_placeholder(str(person.get("before_silence", "")), "Not written yet.")
	_heading("Keepsake")
	_placeholder(str(person.get("keepsake", "")), "Not written yet.")
	_heading("Album")
	var album: Array = person.get("album", [])
	if album.is_empty():
		_placeholder("", "No pictures yet.")
	else:
		for image_id in album:
			_body(str(image_id))
	_heading(Copy.t("Memory %d") % clampi(int(person.get("memory", 0)), 0, 100))
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.14)
	track.custom_minimum_size = Vector2(0, 8)
	var fill := ColorRect.new()
	fill.color = Color("e2a63a")
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(float(person.get("memory", 0)) / 100.0, 0.0, 1.0)
	fill.offset_right = 0.0
	track.add_child(fill)
	card_body.add_child(track)
	_heading("Events")
	var events: Array = person.get("story_events", [])
	if events.is_empty():
		_placeholder("", "No events yet.")
	else:
		for event_id in events:
			_body(Copy.t(str(event_id)))
	card_body.add_child(_button("Back", _show_person.bind(person_id)))


func _placeholder(value: String, fallback: String) -> void:
	var text := value.strip_edges()
	if text == "":
		text = Copy.t(fallback)
	var lab := _label(text, 15)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if value.strip_edges() == "":
		lab.add_theme_color_override("font_color", PAPER_MUTED)
	card_body.add_child(lab)


func _hub_texture() -> Texture2D:
	if game == null:
		return null
	var path := ""
	if str(game.capital_id) == "coney" and str(game.player) == "depot":
		path = "res://assets/hubs/hub_coney_island.webp"
	if path == "":
		return null
	return ArtPack.load_texture(path)


func _capital_name() -> String:
	var sid := str(game.capital_id)
	if game.stations.has(sid):
		return Copy.t(str(game.stations[sid].name))
	return sid


func _community_name() -> String:
	var fac: Dictionary = game.catalog.factions.get(game.player, {})
	return Copy.t(str(fac.get("name", "")))


func _ensure_hub_layer() -> void:
	if hub_layer != null:
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 40
	layer.visible = false
	var picture := TextureRect.new()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture = _hub_texture()
	layer.add_child(picture)
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.03, 0.02, 0.015, 0.66)
	shade.anchor_left = 0.0
	shade.anchor_right = 1.0
	shade.anchor_top = 0.70
	shade.anchor_bottom = 1.0
	layer.add_child(shade)
	var names := VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", 2)
	names.anchor_left = 0.0
	names.anchor_right = 0.62
	names.anchor_top = 1.0
	names.anchor_bottom = 1.0
	names.offset_left = 36.0
	names.offset_top = -118.0
	names.offset_bottom = -28.0
	hub_station_label = _label("", 42, true)
	hub_station_label.add_theme_color_override("font_color", Color("f4efe4"))
	hub_community_label = _label("", 22)
	hub_community_label.add_theme_color_override("font_color", Color("e2a63a"))
	names.add_child(hub_station_label)
	names.add_child(hub_community_label)
	layer.add_child(names)
	hub_begin = _button("Begin", _leave_start)
	hub_back = _button("Back", _hide_hub)
	for button in [hub_begin, hub_back]:
		_style_primary(button)
		button.anchor_left = 1.0
		button.anchor_right = 1.0
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0
		button.offset_right = -36.0
		button.offset_left = -236.0
		button.offset_bottom = -28.0
		button.offset_top = -92.0
		button.custom_minimum_size = Vector2(200, 56)
	layer.add_child(hub_begin)
	layer.add_child(hub_back)
	add_child(layer)
	hub_layer = layer


func _fill_hub_names() -> void:
	if hub_station_label != null:
		hub_station_label.text = _capital_name()
	if hub_community_label != null:
		hub_community_label.text = _community_name()


func _show_start() -> void:
	if _hub_texture() == null:
		Sound.bed("station")
		_show_dawn()
		return
	_ensure_hub_layer()
	_fill_hub_names()
	hub_begin.visible = true
	hub_back.visible = false
	hub_layer.visible = true
	Sound.bed("hub")


func _leave_start() -> void:
	if hub_layer != null:
		hub_layer.visible = false
	Sound.bed("station")
	_show_dawn()


func _show_hub_view() -> void:
	if _hub_texture() == null:
		return
	_ensure_hub_layer()
	_fill_hub_names()
	hub_begin.visible = false
	hub_back.visible = true
	hub_layer.visible = true
	Sound.bed("hub")


func _hide_hub() -> void:
	if hub_layer != null:
		hub_layer.visible = false
	if not at_menu:
		Sound.bed("station")


func _hub_shots() -> void:
	shot_mode = true
	await _settle(Vector2i(1280, 720))
	_close_card()
	_show_start()
	await _frame()
	await _frame()
	_save("hub_start")
	_leave_start()
	_close_card()
	await _frame()
	await _frame()
	_save("hub_station")
	_show_hub_view()
	await _frame()
	await _frame()
	_save("hub_view")
	get_tree().quit(0)


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


func _review_shots() -> void:
	await _settle(Vector2i(1280, 720))
	_close_card()
	await _frame()
	_pin_source("materials")
	await _frame()
	await _frame()
	_save("review_materials")
	_hide_source()
	_close_card()
	var floor := _first_open_floor()
	_show_build(floor.x, floor.y)
	await _frame()
	await _frame()
	_save("review_build")
	_close_card()
	var shop := ""
	for room in game.rooms:
		if str(room.type) == "workshop":
			shop = str(room.uid)
	if shop != "":
		_confirm_upgrade(shop)
		await _frame()
		await _frame()
		_save("review_upgrade")
		_close_card()
	for _step in 2:
		game.end_week()
	_refresh()
	await _frame()
	_close_card()
	if yard != null:
		yard.fit()
	await _frame()
	await _frame()
	_save("review_week3")
	if yard != null:
		for room in game.rooms:
			if str(room.type) == "hydroponics":
				yard.hover = Vector2i(int(room.level), int(room.cell))
				yard._zoom_to(int(room.level), int(room.cell))
	await _frame()
	await _frame()
	_save("review_zoom")
	_close_card()
	var built := false
	for level in 3:
		for cell in 6:
			if built:
				break
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			if bool(spot.dug) and str(spot.room) == "":
				built = game.apply({"kind": "build", "type": "quarters", "level": level, "cell": cell})
	_close_card()
	_refresh()
	if yard != null:
		yard.fit()
	await _frame()
	await _frame()
	_save("review_site")
	get_tree().quit(0)


func _clarity_shots() -> void:
	shot_mode = true
	await _settle(Vector2i(1280, 720))
	_close_card()
	await _frame()
	_start_guide()
	await _frame()
	await _frame()
	_save("clarity_guide")
	_skip_guide()
	drawer_open = true
	people_filter = ""
	_fill_people()
	_place_drawer()
	await _frame()
	await _frame()
	_save("clarity_people")
	var core_id := ""
	for person in game.residents:
		if bool(person.get("core", false)):
			core_id = str(person.id)
			break
	if core_id != "":
		_show_dossier(core_id)
		await _frame()
		await _frame()
		_save("clarity_dossier")
		_close_card()
	drawer_open = false
	_place_drawer()
	var floor := _first_open_floor()
	_show_build(floor.x, floor.y)
	await _frame()
	await _frame()
	_save("clarity_build")
	_close_card()
	var shop := _room_uid("workshop")
	if shop != "":
		_confirm_upgrade(shop)
		await _frame()
		await _frame()
		_save("clarity_upgrade")
		_close_card()
		var held: PackedStringArray = PackedStringArray()
		var crew = game._room(shop)
		if crew != null:
			for sid in crew.staff:
				held.append(str(sid))
		for sid in held:
			game.apply({"kind": "unassign", "person": sid})
		_show_room(shop)
		await _frame()
		await _frame()
		_scroll_card_to_assign()
		await _frame()
		_save("clarity_assign")
		_close_card()
		for sid in held:
			game.apply({"kind": "assign", "person": sid, "room": shop})
	_sample_dig()
	_refresh()
	_close_card()
	if not game.dig.is_empty():
		_tap_cell(int(game.dig.level), int(game.dig.cell))
	await _frame()
	await _frame()
	_save("clarity_dig")
	_close_card()
	var guard := 0
	while not game.dig.is_empty() and guard < 6:
		game.end_week()
		guard += 1
		while not game.pending.is_empty():
			game.dismiss_front()
	_refresh()
	_close_card()
	var site := _first_open_floor()
	game.apply({"kind": "build", "type": "quarters", "level": site.x, "cell": site.y})
	while not game.pending.is_empty():
		game.dismiss_front()
	_refresh()
	_close_card()
	drawer_open = false
	_place_drawer()
	if yard != null:
		yard.fit()
	await _frame()
	await _frame()
	_save("clarity_station")
	var other := _first_open_floor()
	_show_build(other.x, other.y)
	await _frame()
	await _frame()
	_save("clarity_building")
	get_tree().quit(0)


func _scroll_card_to_assign() -> void:
	if card_scroll == null or card_body == null:
		return
	var first := -1
	var marked := -1
	for child in card_body.get_children():
		if not (child is Button) or str(child.text) != "":
			continue
		var y := int(child.position.y)
		if first < 0:
			first = y
		if child.has_meta("other_room"):
			marked = y
			break
	var top := first
	if marked > 0:
		top = maxi(0, marked - 96)
	if top >= 0:
		card_scroll.scroll_vertical = top


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
	win.content_scale_factor = 1.0
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
	if not OS.has_feature("editor"):
		dir = OS.get_executable_path().get_base_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	var path := dir + "/%s.png" % shot_name
	var err := img.save_png(path)
	print("SHOT %s %dx%d ui %s win %s err %s" % [shot_name, img.get_width(), img.get_height(), size, get_window().size, err])


	print("SHOT %s %dx%d ui %s win %s err %s" % [shot_name, img.get_width(), img.get_height(), size, get_window().size, err])


func _reveal_modal() -> void:
	modal_open = true
	if modal_tween != null:
		modal_tween.kill()
	var was_open := dim.visible and dim.modulate.a > 0.85
	dim.visible = true
	card.pivot_offset = card.size * 0.5
	if _motion_off() or was_open:
		dim.modulate.a = 1.0
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		return
	dim.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2(0.96, 0.96)
	modal_tween = create_tween()
	modal_tween.tween_property(dim, "modulate:a", 1.0, 0.15)
	modal_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.15)
	modal_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.15)


func _hide_modal() -> void:
	modal_open = false
	if modal_tween != null:
		modal_tween.kill()
	if _motion_off() or dim == null or not dim.visible:
		if dim != null:
			dim.visible = false
			dim.modulate.a = 1.0
		if card != null:
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
		return
	modal_tween = create_tween()
	modal_tween.tween_property(dim, "modulate:a", 0.0, 0.15)
	modal_tween.parallel().tween_property(card, "modulate:a", 0.0, 0.15)
	modal_tween.parallel().tween_property(card, "scale", Vector2(0.96, 0.96), 0.15)
	modal_tween.finished.connect(_finish_hide_modal)


func _finish_hide_modal() -> void:
	if modal_open or dim == null:
		return
	dim.visible = false
	dim.modulate.a = 1.0
	if card != null:
		card.scale = Vector2.ONE
		card.modulate.a = 1.0


func _network_shots() -> void:
	shot_mode = true
	hold_dawn = false
	at_menu = false
	await _settle(Vector2i(1280, 720))
	_close_card()
	if guide_layer != null:
		guide_layer.visible = false
	showing_network = true
	yard.visible = false
	network_view.visible = true
	network_view.bind(self)
	await _frame()
	await _frame()
	network_view._fit()
	_place_chrome()
	await _frame()
	_save("network_week1")
	var sid: String = network_view.first_known_neighbor()
	if sid != "":
		network_view.open_sheet(sid)
	await _frame()
	await _frame()
	_save("network_sheet")
	network_view.close_sheet()
	await _frame()
	_save("network_council")
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	var saw_warn := false
	var saw_ult := false
	while game.over == "" and game.week < 20 and guard < 30:
		guard += 1
		bot._act(game)
		game.end_week()
		if not saw_warn and _shot_logged("WARN", game.week - 1):
			saw_warn = true
			await _card_shot("flip_warning")
		if not saw_ult and _shot_logged("ULTIMATUM", game.week):
			saw_ult = true
			await _card_shot("ultimatum_card")
	hold_dawn = true
	_close_card()
	_refresh()
	network_view._fit()
	await _frame()
	_save("network_week20")
	network_view.focus_intent()
	await _frame()
	await _frame()
	_save("network_intents")
	get_tree().quit()


func _shot_logged(prefix: String, week_n: int) -> bool:
	for entry in game.log:
		if int(entry.week) == week_n and str(entry.text).begins_with(prefix):
			return true
	return false


func _card_shot(shot_name: String) -> void:
	var saved: Array = game.pending.duplicate()
	game.pending.clear()
	if dim.visible:
		_close_card()
	hold_dawn = true
	_refresh()
	hold_dawn = false
	_show_dawn()
	await _frame()
	await _frame()
	_save(shot_name)
	if dim.visible:
		_close_card()
	game.pending = saved


func _polish_shots() -> void:
	shot_mode = true
	hold_dawn = false
	await _settle(Vector2i(1280, 720))
	_close_card()
	guide_played = true
	_show_main_menu()
	await _frame()
	await _frame()
	_save("menu_main")
	_open_settings(false)
	await _frame()
	await _frame()
	_save("menu_settings")
	_begin_new_game(false)
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	_sync_resource_names()
	await _frame()
	await _frame()
	_save("station_week1")
	get_tree().quit()


func _show_main_menu() -> void:
	at_menu = true
	settings_from_game = false
	_close_card()
	_ensure_menu()
	_fill_menu_root()
	menu_root.visible = true
	menu_settings.visible = false
	menu_credits.visible = false
	menu_layer.visible = true
	Sound.bed("hub")


func _begin_new_game(intro: bool) -> void:
	at_menu = false
	if menu_layer != null:
		menu_layer.visible = false
	if game != null and game.catalog != null:
		var cat: Catalog = game.catalog
		game = Game.new()
		game.setup(cat, 1, 40)
	if yard != null:
		yard.station = self
	hold_dawn = false
	stock_week = 0
	stock_shown = {}
	_refresh()
	if not shot_mode:
		SaveGame.write_auto(game)
	if intro and _hub_texture() != null:
		_show_start()
		return
	Sound.bed("station")
	if not shot_mode:
		_show_dawn()


func _continue_game() -> void:
	if game == null or not SaveGame.load_latest(game):
		Sound.play("error")
		return
	at_menu = false
	if menu_layer != null:
		menu_layer.visible = false
	stock_week = 0
	stock_shown = {}
	hold_dawn = false
	Sound.play("confirm")
	Sound.bed("station")
	_refresh()


func _manual_save() -> void:
	if SaveGame.write_manual(game):
		Sound.play("confirm")
		footer.text = Copy.t("Saved.")
		footer.visible = true
	else:
		Sound.play("error")
	_close_card()


func _manual_load() -> void:
	if game == null or not SaveGame.load_manual(game):
		Sound.play("error")
		return
	stock_week = 0
	stock_shown = {}
	Sound.play("confirm")
	_close_card()
	_refresh()


func _back_to_menu() -> void:
	_close_card()
	if not shot_mode:
		SaveGame.write_auto(game)
	_show_main_menu()


func _open_settings(from_game: bool) -> void:
	settings_from_game = from_game
	if from_game:
		_close_card()
	_ensure_menu()
	_fill_settings()
	menu_root.visible = false
	menu_credits.visible = false
	menu_settings.visible = true
	menu_layer.visible = true


func _open_credits() -> void:
	_ensure_menu()
	menu_root.visible = false
	menu_settings.visible = false
	menu_credits.visible = true
	menu_layer.visible = true


func _menu_back() -> void:
	if settings_from_game:
		settings_from_game = false
		if menu_layer != null:
			menu_layer.visible = false
		Sound.bed("station")
		_offer_pending()
		return
	_show_main_menu()


func _ensure_menu() -> void:
	if menu_layer != null:
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 60
	var picture := TextureRect.new()
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.texture = _hub_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	layer.add_child(picture)
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = Color(0.04, 0.03, 0.02, 0.28)
	layer.add_child(wash)
	menu_root = _menu_page()
	menu_settings = _menu_page()
	menu_credits = _menu_page()
	layer.add_child(menu_root)
	layer.add_child(menu_settings)
	layer.add_child(menu_credits)
	add_child(layer)
	menu_layer = layer
	_fill_credits()


func _menu_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 48.0
	page.offset_top = 36.0
	page.offset_right = -48.0
	page.offset_bottom = -28.0
	page.add_theme_constant_override("separation", 8)
	page.visible = false
	return page


func _fill_menu_root() -> void:
	if menu_root == null:
		return
	_wipe(menu_root)
	var title := _label("Underline", 54, true)
	title.add_theme_color_override("font_color", Color("f4efe4"))
	menu_root.add_child(title)
	var place := _label("%s  ·  %s" % [_capital_name(), _community_name()], 20)
	place.add_theme_color_override("font_color", Color("e2a63a"))
	menu_root.add_child(place)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(gap)
	var can_continue := SaveGame.has_any()
	continue_button = _menu_choice("Continue", _continue_game, can_continue)
	continue_button.disabled = not can_continue
	if continue_button.disabled:
		continue_button.tooltip_text = Copy.t("No saved game.")
	menu_root.add_child(continue_button)
	menu_root.add_child(_menu_choice("New game", _begin_new_game.bind(true), true))
	menu_root.add_child(_menu_choice("Settings", _open_settings.bind(false), false))
	menu_root.add_child(_menu_choice("Credits", _open_credits, false))
	menu_root.add_child(_menu_choice("Quit", func() -> void: get_tree().quit(), false))


func _menu_choice(caption: String, cb: Callable, primary: bool) -> Button:
	var button := _button(caption, cb, "confirm" if primary else "click")
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(280, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if primary:
		_style_primary(button)
	return button


func _fill_settings() -> void:
	if menu_settings == null:
		return
	filling_settings = true
	_wipe(menu_settings)
	on_paper = false
	var title := _label("Settings", 40, true)
	title.add_theme_color_override("font_color", Color("f4efe4"))
	menu_settings.add_child(title)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _paper_style())
	card.custom_minimum_size = Vector2(560, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	menu_settings.add_child(card)
	on_paper = true
	box.add_child(_label("Volume", 18, true))
	box.add_child(_volume_row("Master", Settings.master, _set_master))
	box.add_child(_volume_row("Music", Settings.music, _set_music))
	box.add_child(_volume_row("SFX", Settings.sfx, _set_sfx))
	box.add_child(_label("Language", 18, true))
	var langs := HBoxContainer.new()
	langs.add_theme_constant_override("separation", 8)
	langs.add_child(_pick_button("RU", Copy.lang == "ru", _pick_lang.bind("ru")))
	langs.add_child(_pick_button("EN", Copy.lang == "en", _pick_lang.bind("en")))
	box.add_child(langs)
	box.add_child(_label("Window", 18, true))
	var windows := HBoxContainer.new()
	windows.add_theme_constant_override("separation", 8)
	windows.add_child(_pick_button("Fullscreen", Settings.fullscreen, _pick_window.bind(true), 210.0))
	windows.add_child(_pick_button("Windowed", not Settings.fullscreen, _pick_window.bind(false), 160.0))
	box.add_child(windows)
	box.add_child(_label("UI scale", 18, true))
	var scales := HBoxContainer.new()
	scales.add_theme_constant_override("separation", 8)
	for pair in [[0.75, "75%"], [1.0, "100%"], [1.25, "125%"], [1.5, "150%"]]:
		var scale := float(pair[0])
		scales.add_child(_pick_button(str(pair[1]), absf(Settings.ui_scale - scale) < 0.02, _pick_scale.bind(scale)))
	box.add_child(scales)
	var motion := Copy.t("Reduce motion") + ": " + Copy.t("On" if Settings.reduce_motion else "Off")
	box.add_child(_pick_button(motion, Settings.reduce_motion, _toggle_motion, 420.0))
	on_paper = false
	var back := _menu_choice("Back", _menu_back, false)
	menu_settings.add_child(back)
	filling_settings = false


func _fill_credits() -> void:
	if menu_credits == null:
		return
	_wipe(menu_credits)
	var title := _label("Credits", 40, true)
	title.add_theme_color_override("font_color", Color("f4efe4"))
	menu_credits.add_child(title)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _paper_style())
	card.custom_minimum_size = Vector2(640, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	menu_credits.add_child(card)
	on_paper = true
	box.add_child(_label("Fonts", 20, true))
	var fonts := _label("Courier Prime, Big Shoulders Display, Oswald, and PT Mono. SIL Open Font License 1.1.", 16)
	fonts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fonts.custom_minimum_size = Vector2(600, 0)
	box.add_child(fonts)
	box.add_child(_label("Sounds", 20, true))
	var sounds := _label("Kenney Interface Sounds and Kenney RPG sounds (www.kenney.nl), CC0.", 16)
	sounds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sounds.custom_minimum_size = Vector2(600, 0)
	box.add_child(sounds)
	for line in [
		"click.ogg  Interface Sounds  click_001",
		"hover.ogg  Interface Sounds  tick_001",
		"confirm.ogg  Interface Sounds  confirmation_001",
		"error.ogg  Interface Sounds  error_001",
		"whoosh.ogg  Interface Sounds  minimize_001",
		"built.ogg  Interface Sounds  confirmation_003",
		"card.ogg  Interface Sounds  open_001",
		"thud.ogg  RPG sounds  chop",
	]:
		var row := _label(line, 14)
		row.add_theme_color_override("font_color", PAPER_MUTED)
		box.add_child(row)
	if not Sound.has_ambient() or not Sound.has_drone():
		var missing := _label("Station ambience and the hub drone are not included yet.", 15)
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		missing.custom_minimum_size = Vector2(600, 0)
		box.add_child(missing)
	on_paper = false
	menu_credits.add_child(_menu_choice("Back", _menu_back, false))


func _volume_row(caption: String, value: float, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lab := _label(caption, 16)
	lab.custom_minimum_size = Vector2(110, 0)
	row.add_child(lab)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = value * 100.0
	slider.custom_minimum_size = Vector2(260, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.value_changed.connect(cb)
	row.add_child(slider)
	var num := _label("%d" % int(round(value * 100.0)), 16)
	num.custom_minimum_size = Vector2(42, 0)
	slider.set_meta("readout", num)
	row.add_child(num)
	return row


func _pick_button(caption: String, on: bool, cb: Callable, width: float = 112.0) -> Button:
	var button := _button(caption, cb, "click")
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	button.custom_minimum_size = Vector2(width, 44)
	if on:
		_style_primary(button)
	return button


func _set_master(value: float) -> void:
	_set_volume("master", value)


func _set_music(value: float) -> void:
	_set_volume("music", value)


func _set_sfx(value: float) -> void:
	_set_volume("sfx", value)


func _set_volume(which: String, value: float) -> void:
	if filling_settings:
		return
	var linear := clampf(value / 100.0, 0.0, 1.0)
	if which == "master":
		Settings.master = linear
	elif which == "music":
		Settings.music = linear
	else:
		Settings.sfx = linear
	Settings.save()
	Sound.apply_buses()


func _pick_lang(code: String) -> void:
	if Copy.lang == code:
		return
	Settings.language = code
	Settings.save()
	if not at_menu and game != null:
		SaveGame.write_auto(game)
		Settings.resume = true
	Settings.reopen = "settings"
	Copy.set_lang(code)
	get_tree().reload_current_scene()


func _pick_window(full: bool) -> void:
	Settings.fullscreen = full
	Settings.save()
	if not shot_mode:
		Settings.apply_display(get_window())
	_fill_settings()


func _pick_scale(scale: float) -> void:
	Settings.ui_scale = scale
	Settings.save()
	if not shot_mode:
		Settings.apply_display(get_window())
	_fill_settings()


func _toggle_motion() -> void:
	Settings.reduce_motion = not Settings.reduce_motion
	Settings.save()
	_fill_settings()


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
	signal picked(id: String)
	var person_id := ""
	var person_name := ""
	var _armed := false
	var _dragged := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06)
		style.set_content_margin_all(3)
		style.set_corner_radius_all(4)
		add_theme_stylebox_override("panel", style)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_armed = true
				_dragged = false
			elif _armed and not _dragged:
				_armed = false
				picked.emit(person_id)
				accept_event()

	func _get_drag_data(_at_position: Vector2):
		_dragged = true
		var preview := Label.new()
		preview.text = person_name
		preview.add_theme_color_override("font_color", Color("efe6d2"))
		if Copy.ru():
			preview.add_theme_font_override("font", get_theme_default_font())
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
		"carrying": "res://assets/figures/fig_carrying.webp",
		"working": "res://assets/figures/fig_working.webp",
		"kneeling": "res://assets/figures/fig_kneeling.webp",
		"sitting": "res://assets/figures/fig_sitting.webp",
	}
	const LAMP := {
		"air_filter": Color(0.62, 0.82, 1.0, 0.42),
		"generator": Color(1.0, 0.32, 0.10, 0.46),
		"infirmary": Color(0.55, 0.95, 0.68, 0.40),
		"hydroponics": Color(1.0, 0.38, 0.58, 0.42),
		"quarters": Color(1.0, 0.62, 0.28, 0.40),
		"workshop": Color(0.95, 0.55, 0.22, 0.16),
		"meeting_hall": Color(0.72, 0.58, 0.95, 0.16),
		"radio": Color(0.55, 0.78, 1.0, 0.18),
		"platform": Color(1.0, 0.72, 0.40, 0.14),
	}
	# Backdrop image: tunnel rail, and how much of each side is the mouth.
	const BACKDROP_RAIL := 0.783
	# Inner lip of each tunnel mouth, so the arches meet the station edges.
	const BACKDROP_SIDE := 0.147
	const OPEN_WIDTH := 0.96
	const PLATFORM_RAIL := 0.96
	const SKYLINE_FRAC := 0.164
	const SOIL_LIP := 0.032
	const ROCK_LIP := 0.0
	var art := {}
	var poses := {}
	var figure_scale_px := 660.0
	var cell_rock: Texture2D
	var cell_dug: Texture2D
	var backdrop_tex: Texture2D
	var cell_build: Texture2D
	var glow := {}
	var more_hits: Array = []
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
	var pops: Array = []
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
		var sky := station_rect.size.y * 0.03
		var by_height := maxf(area.size.y - 8.0, 48.0) / (station_rect.size.y + sky)
		return minf(by_width, by_height)

	func _station_rect() -> Rect2:
		var geo := _geo()
		return Rect2(geo.origin, Vector2(float(geo.w) * 6.0, float(geo.h) * 3.0 + float(geo.band) * 2.0))

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		for type in ART:
			var tex := ArtPack.load_texture(str(ART[type]))
			if tex == null:
				continue
			art_aspect = float(tex.get_width()) / float(tex.get_height())
			art[type] = tex
		cell_rock = ArtPack.load_texture("res://assets/cells/cell_rock.webp")
		cell_dug = ArtPack.load_texture("res://assets/cells/cell_dug.webp")
		var site := ArtPack.load_texture("res://assets/cells/cell_construction.webp")
		cell_build = site if site != null else cell_dug
		backdrop_tex = ArtPack.load_texture("res://assets/backdrop_station.webp")
		for pose_name in POSE_ART:
			var fig_path := str(POSE_ART[pose_name])
			var fig_tex := ArtPack.load_texture(fig_path)
			if fig_tex == null:
				continue
			var figure := fig_tex.get_image()
			if figure == null or figure.get_width() < 1:
				ArtPack.note(fig_path)
				continue
			if str(pose_name) == "standing":
				figure_scale_px = float(figure.get_height())
			poses[pose_name] = ImageTexture.create_from_image(_erode_alpha(figure, 2))

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
					out.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var v := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				out.set_pixel(x, y, Color(v, v, v, c.a))
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
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover.x >= 0 else Control.CURSOR_ARROW
			queue_redraw()

	func flash_at(level: int, cell: int) -> void:
		if station != null and station._motion_off():
			return
		pops.append({"at": Vector2i(level, cell), "born": Time.get_ticks_msec()})

	func _draw_pops(geo: Dictionary) -> void:
		if pops.is_empty():
			return
		var now := Time.get_ticks_msec()
		var keep: Array = []
		for pop in pops:
			var age := float(now - int(pop.born)) / 1000.0
			if age > 0.7:
				continue
			keep.append(pop)
			var rect := _rect(geo, int(pop.at.x), int(pop.at.y))
			var fade := 1.0 - age / 0.7
			draw_rect(rect, Color(1.0, 0.96, 0.86, 0.34 * fade))
			for i in 7:
				var ang := float(i) / 7.0 * TAU
				var dist := age * rect.size.y * 0.55
				var puff := rect.get_center() + Vector2(cos(ang), sin(ang) * 0.45) * dist + Vector2(0, -age * 36.0)
				draw_circle(puff, maxf(1.4, 4.5 * fade), Color(0.86, 0.78, 0.62, 0.55 * fade))
		pops = keep

	func cell_screen(level: int, cell: int) -> Rect2:
		var world := _rect(_geo(), level, cell)
		return Rect2(pan + world.position * zoom, world.size * zoom)

	func _note_tap(screen: Vector2) -> void:
		for mark in more_hits:
			var area: Rect2 = mark.rect
			if area.has_point(screen) and str(mark.filter) != "":
				pending_level = -1
				station._open_people_for(str(mark.filter))
				return
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
		more_hits.clear()
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
		_draw_job_worker(geo)
		_draw_pops(geo)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_room_chrome(geo)
		_draw_hover_label(geo)

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

	func _draw_backdrop(_geo_now: Dictionary) -> void:
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
		var soil_src := tex.y * SOIL_LIP
		var soil_h := dest.size.y * SOIL_LIP
		var soil_y := lower_y - soil_h
		draw_texture_rect_region(
			backdrop_tex,
			Rect2(dest.position.x, soil_y, dest.size.x, soil_h),
			Rect2(0, tex.y * SKYLINE_FRAC, tex.x, soil_src))
		var hud_h := 72.0
		if station != null and station.hud != null and station.hud.size.y > 8.0:
			hud_h = station.hud.size.y
		var visible_top := (hud_h - pan.y) / maxf(zoom, 0.001)
		var sky_h := soil_y - visible_top
		if sky_h < 8.0:
			sky_h = dest.size.y * SKYLINE_FRAC
			visible_top = soil_y - sky_h
		draw_texture_rect_region(
			backdrop_tex,
			Rect2(dest.position.x, visible_top, dest.size.x, sky_h),
			Rect2(0, 0, tex.x, tex.y * SKYLINE_FRAC))

	func _draw_cell(rect: Rect2, level: int, cell: int) -> void:
		var shift := 0.0
		if shake_cell == Vector2i(level, cell) and (shake_px != 0.0 or Time.get_ticks_msec() < shake_until):
			shift = shake_px if shake_px != 0.0 else sin(Time.get_ticks_msec() / 45.0) * 8.0
		if shift != 0.0:
			rect.position += Vector2(shift, 0.0)
		if _job_is_build(level, cell):
			draw_rect(rect, Color(0.08, 0.07, 0.06))
			if cell_build != null:
				_blit_room(cell_build, rect)
			return
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
			if cell_dug != null:
				_blit_room(cell_dug, rect)
			else:
				_paint_rock(rect, level * 6 + cell)
		else:
			var fill: Color = ROOM_COLOR.get(room_type, Color(0.12, 0.12, 0.13))
			draw_rect(rect, fill)
			var texture = art.get(room_type, null)
			if texture != null:
				_blit_room(texture, rect)
			_draw_lamp_glow(rect, room_type)
		var losing: bool = kind == "room" and station.power_loss.has(str(spot.room))
		if losing:
			draw_rect(rect, Color(0, 0, 0, _lamp(level, cell)))
			_draw_power_icon(rect)
		if kind == "room":
			if room_type == "platform":
				_draw_platform(rect, room)
			else:
				_draw_people(rect, room)
			if glow.has(str(spot.room)):
				draw_rect(rect.grow(-3.0), Color(0.95, 0.84, 0.55, 0.95), false, 3.0)
		if _under_water(spot, kind):
			_draw_water(rect, level, cell)
		var job := _job_span(level, cell)
		if job.x >= 0:
			_draw_progress(rect, job.x, job.y, true)
		elif kind == "undug":
			_draw_dig_outline(rect, level, cell)
		if drag_id != "" and kind == "room" and room != null:
			var preview: Dictionary = station.game.assign_preview(drag_id, str(room.uid))
			if bool(preview.ok):
				draw_rect(rect, Color(0.95, 0.84, 0.55, 0.28))
				draw_rect(rect.grow(-4.0), Color(0.95, 0.84, 0.55, 0.95), false, 4.0)
		if hover == Vector2i(level, cell) and kind != "hidden":
			draw_rect(rect, Color(0.93, 0.78, 0.45, 0.16))
			draw_rect(rect.grow(-2.0), Color(0.93, 0.78, 0.45, 0.9), false, 2.0)
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
		var scale := _rock_scale(rect, texture)
		var tile := texture.get_size() * scale
		if tile.x < 2.0 or tile.y < 2.0:
			draw_texture_rect(texture, rect, false)
			return
		var y := rect.position.y
		while y < rect.end.y - 0.5:
			var x := rect.position.x
			while x < rect.end.x - 0.5:
				var dest := Rect2(x, y, tile.x, tile.y)
				var cut := dest.intersection(rect)
				if cut.size.x > 0.5 and cut.size.y > 0.5:
					var src_pos := (cut.position - dest.position) / scale
					var src_size := cut.size / scale
					draw_texture_rect_region(texture, cut, Rect2(src_pos, src_size))
				x += tile.x
			y += tile.y

	func _rock_scale(rect: Rect2, texture: Texture2D) -> float:
		var room_h := 1.0
		var sample: Texture2D = art.get("workshop", null)
		if sample == null:
			for key in art:
				sample = art[key]
				break
		if sample != null and sample.get_height() > 1:
			room_h = float(sample.get_height())
		var scale := rect.size.y / room_h
		var tile_h := float(texture.get_height()) * scale
		var target := rect.size.y / 3.0
		if tile_h > target:
			scale = target / maxf(float(texture.get_height()), 1.0)
		return scale

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
		_draw_status(rect.position + Vector2(rect.size.x - 28, 6), "unpowered")

	func _draw_water(rect: Rect2, level: int, cell: int) -> void:
		var t := Time.get_ticks_msec() / 1000.0
		var wave := sin(t * 1.25 + float(cell) * 1.3) * 0.018 + sin(t * 0.55 + float(level) * 2.0) * 0.012
		var frac := clampf(0.33 + wave, 0.28, 0.4)
		var height := rect.size.y * frac
		var body := Rect2(rect.position.x, rect.position.y + rect.size.y - height, rect.size.x, height)
		draw_rect(body, Color(0.04, 0.11, 0.16, 0.82))
		draw_line(Vector2(body.position.x, body.position.y + 1.0), Vector2(body.position.x + body.size.x, body.position.y + 1.0), Color(0.55, 0.72, 0.8, 0.7), 2.0)
		_draw_status(rect.position + Vector2(6, 6), "flooded")

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
		_draw_status(rect.get_center() - Vector2(12, 12), "dig")

	func _draw_lamp_glow(rect: Rect2, room_type: String) -> void:
		var tint: Color = LAMP.get(room_type, Color(1.0, 0.82, 0.48, 0.08))
		var pool := Rect2(rect.position.x + rect.size.x * 0.22, rect.position.y, rect.size.x * 0.56, rect.size.y * 0.34)
		draw_rect(pool, tint)
		draw_rect(rect, Color(tint.r, tint.g, tint.b, tint.a * 0.45))

	func _draw_progress(rect: Rect2, left: int, total: int, with_label: bool = true) -> void:
		var span := maxi(total, 1)
		var done := clampf(float(span - left) / float(span), 0.0, 1.0)
		var bar := Rect2(rect.position.x + 8.0, rect.position.y + rect.size.y - 12.0, rect.size.x - 16.0, 5.0)
		draw_rect(bar, Color(0.42, 0.30, 0.12, 0.95))
		if done > 0.0:
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(0.93, 0.78, 0.42, 0.95))
		if not with_label:
			return
		var label := Copy.t("%d wk") % left
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var box := Rect2(rect.position.x + 6.0, bar.position.y - text_size.y - 6.0, text_size.x + 8.0, text_size.y + 2.0)
		draw_rect(box, Color(0.05, 0.04, 0.03, 0.55))
		draw_string(font, box.position + Vector2(4.0, text_size.y - 1.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.96, 0.93, 0.86, 0.9))

	func _job_span(level: int, cell: int) -> Vector2i:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			var total := int(station.game._dig_cost(level).turns)
			var left := int(digging.left)
			return Vector2i(left, maxi(total, left))
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			var defin: Dictionary = station.game.catalog.rooms[str(building.type)]
			var total := int(defin.get("build_turns", 1))
			var left := int(building.left)
			return Vector2i(left, maxi(total, left))
		return Vector2i(-1, 0)

	func _job_is_build(level: int, cell: int) -> bool:
		var building: Dictionary = station.game.build
		return not building.is_empty() and int(building.level) == level and int(building.cell) == cell

	func _cell_action(level: int, cell: int, kind: String, room_type: String) -> String:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return Copy.t("Digging, %s left") % Words.count(int(digging.left), "week")
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			var name := Copy.t(str(station.game.catalog.rooms[str(building.type)].name))
			return Copy.t("Building %s, %s left") % [name, Words.count(int(building.left), "week")]
		match kind:
			"hidden":
				return Copy.t("Solid rock")
			"undug":
				return Copy.t("Dig")
			"dug":
				return Copy.t("Build")
			"room":
				return Copy.t(str(station.game.catalog.rooms[room_type].name))
		return ""

	func _draw_corner_label(rect: Rect2, tip: String) -> void:
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var font_size := 13
		var text_size: Vector2 = font.get_string_size(tip, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Rect2(rect.position.x + 4.0, rect.position.y + 4.0, minf(text_size.x + 8.0, rect.size.x - 8.0), text_size.y + 4.0)
		draw_rect(box, Color(0.05, 0.04, 0.03, 0.45))
		draw_string(font, box.position + Vector2(4.0, text_size.y * 0.82), tip, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 6.0, font_size, Color(0.96, 0.93, 0.86, 0.82))

	func _job_text(level: int, cell: int, width: float) -> String:
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return "Dig %d" % int(digging.left)
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			return "%s %d" % [_short(str(building.type), width), int(building.left)]
		return ""

	func _art_rect(room_type: String, rect: Rect2) -> Rect2:
		var texture: Texture2D = art.get(room_type, null)
		if texture == null:
			return rect
		var tex := texture.get_size()
		if tex.x < 1.0 or tex.y < 1.0:
			return rect
		var aspect := tex.x / tex.y
		var cell_aspect := rect.size.x / maxf(rect.size.y, 1.0)
		if cell_aspect > aspect:
			var w := rect.size.y * aspect
			return Rect2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y, w, rect.size.y)
		if cell_aspect < aspect:
			var h := rect.size.x / aspect
			return Rect2(rect.position.x, rect.position.y + (rect.size.y - h) * 0.5, rect.size.x, h)
		return rect

	func _draw_room_chrome(geo: Dictionary) -> void:
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		for level in 3:
			for cell in 6:
				if _job_is_build(level, cell):
					_draw_build_bar(geo, level, cell)
				var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
				if str(spot.room) == "":
					continue
				var room = station.game._room(str(spot.room))
				if room == null:
					continue
				var world := _rect(geo, level, cell)
				var screen := Rect2(pan + world.position * zoom, world.size * zoom)
				if screen.size.x < 36.0 or screen.size.y < 28.0:
					continue
				_draw_sign(screen, room, font)
				_draw_badge_screen(screen, room, font)

	func _draw_build_bar(geo: Dictionary, level: int, cell: int) -> void:
		var world := _rect(geo, level, cell)
		var screen := Rect2(pan + world.position * zoom, world.size * zoom)
		if screen.size.x < 24.0:
			return
		var built := _job_span(level, cell)
		var span := maxi(built.y, 1)
		var done := clampf(float(span - built.x) / float(span), 0.0, 1.0)
		var bar := Rect2(screen.position.x + 8.0, screen.position.y + screen.size.y - 12.0, screen.size.x - 16.0, 6.0)
		draw_rect(bar, Color(0.55, 0.38, 0.14, 0.96))
		if done > 0.0:
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(0.95, 0.82, 0.42, 1.0))
		_draw_status(screen.get_center() - Vector2(12, 12), "building")

	func _room_glyph(room_type: String) -> String:
		return room_type

	func _draw_sign(screen: Rect2, room: Dictionary, font: Font) -> void:
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var room_name := Copy.t(str(defin.name))
		var font_size := 13
		var text_w := font.get_string_size(room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var steps: Array = defin.get("upgrades", [])
		var total := mini(3, maxi(1, steps.size() + 1))
		var filled := clampi(int(room.upgrade) + 1, 1, total)
		var pip_w := float(total) * 8.0
		var plate_w := minf(8.0 + 16.0 + 4.0 + text_w + 8.0 + pip_w, screen.size.x - 8.0)
		var plate := Rect2(screen.position + Vector2(4.0, 4.0), Vector2(plate_w, 22.0))
		draw_rect(plate, Color("efe6d2"))
		draw_rect(plate, Color("3a2610"), false, 1.5)
		_paint_mini(plate.position + Vector2(3.0, 4.0), _room_glyph(str(room.type)), Color("24180e"))
		var name_w := maxf(8.0, plate_w - 16.0 - 8.0 - pip_w)
		draw_string(font, plate.position + Vector2(20.0, 16.0), room_name, HORIZONTAL_ALIGNMENT_LEFT, name_w, font_size, Color("24180e"))
		var px := plate.position.x + plate.size.x - pip_w - 2.0
		for i in total:
			var pip := Color("3a2610") if i < filled else Color("3a2610", 0.28)
			draw_circle(Vector2(px + 4.0 + float(i) * 8.0, plate.position.y + 11.0), 2.2, pip)

	func _draw_badge_screen(screen: Rect2, room: Dictionary, font: Font) -> void:
		var detail: Dictionary = station.game.room_detail(str(room.uid))
		var outputs: Array = detail.get("outputs", [])
		if outputs.is_empty():
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var dimmed := bool(room.get("browned", false)) or bool(room.get("offline", false))
		if station.power_loss.has(str(room.uid)):
			dimmed = true
		if int(defin.get("staff_min", 0)) > 0 and room.staff.size() < int(defin.staff_min):
			dimmed = true
		var ink := Color(0.96, 0.93, 0.86, 0.38 if dimmed else 0.96)
		var width := 8.0
		for out in outputs:
			width += 16.0 + font.get_string_size("+%d" % int(out.amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 6.0
		var plate := Rect2(screen.position.x + screen.size.x - width - 4.0, screen.position.y + screen.size.y - 22.0, width, 18.0)
		draw_rect(plate, Color(0.05, 0.04, 0.03, 0.55 if dimmed else 0.72))
		var x := plate.position.x + 4.0
		for out in outputs:
			_paint_mini(Vector2(x, plate.position.y + 2.0), str(out.key), ink)
			x += 16.0
			var text := "+%d" % int(out.amount)
			draw_string(font, Vector2(x, plate.position.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 6.0

	func _draw_hover_label(geo: Dictionary) -> void:
		if hover.x < 0:
			return
		var spot: Dictionary = station.game.cells["%d:%d" % [hover.x, hover.y]]
		var kind := _kind(spot)
		var room_type := ""
		if kind == "room":
			var found: Dictionary = station.game._room(str(spot.room))
			room_type = str(found.get("type", ""))
		var tip := _cell_action(hover.x, hover.y, kind, room_type)
		if tip == "":
			return
		var world := _rect(geo, hover.x, hover.y)
		var screen := pan + world.position * zoom
		screen.x = clampf(screen.x + 6.0, 8.0, size.x - 180.0)
		screen.y = clampf(screen.y + 6.0, 8.0, size.y - 32.0)
		_draw_corner_label(Rect2(screen, Vector2(220, 28)), tip)

	func _draw_people(rect: Rect2, room: Dictionary) -> void:
		var crew: Array = room.staff
		if crew.is_empty() or not poses.has("standing"):
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var spots: Array = defin.get("spots", [])
		var floor := _art_rect(str(room.type), rect)
		var shown := mini(crew.size(), mini(spots.size(), 3))
		for i in shown:
			var spot: Dictionary = spots[i]
			var x := floor.position.x + float(spot.get("x", 0.5)) * floor.size.x
			var face := int(spot.get("face", 1))
			var pose_name := str(spot.get("pose", "standing"))
			if not poses.has(pose_name):
				pose_name = "standing"
			var foot_y := floor.position.y + floor.size.y - 2.0
			var body_h := floor.size.y
			var fitted := _pose_size(poses[pose_name], body_h)
			var limit := floor.size.x * 0.34
			if fitted.x > limit:
				body_h *= limit / fitted.x
			_paint_pose(pose_name, x, foot_y, body_h, str(crew[i]), face < 0)
		if crew.size() > shown:
			_draw_more(rect, crew.size() - shown, str(room.uid))
		for id in crew:
			var person: Dictionary = station.game.people.get(str(id), {})
			if int(person.get("sick", 0)) > 0:
				_draw_status(rect.position + Vector2(6, 6), "sick")
				break

	func _draw_platform(rect: Rect2, _room: Dictionary) -> void:
		if not poses.has("walking") and not poses.has("standing"):
			return
		var ids: Array = _idle_ids()
		var shown := mini(2, ids.size())
		var pose_name := "walking" if poses.has("walking") else "standing"
		for i in shown:
			var x := rect.position.x + rect.size.x * (0.28 if i == 0 else 0.62)
			var foot_y := rect.position.y + rect.size.y - 2.0
			_paint_pose(pose_name, x, foot_y, rect.size.y, str(ids[i]), i == 0)
		if ids.size() > shown:
			_draw_more(rect, ids.size() - shown, "free")

	func _draw_job_worker(geo: Dictionary) -> void:
		var job_level := -1
		var job_cell := -1
		var worker := ""
		var digging: Dictionary = station.game.dig
		if not digging.is_empty():
			job_level = int(digging.level)
			job_cell = int(digging.cell)
			if digging.workers.size() > 0:
				worker = str(digging.workers[0])
		var building: Dictionary = station.game.build
		if not building.is_empty():
			job_level = int(building.level)
			job_cell = int(building.cell)
			if building.workers.size() > 0:
				worker = str(building.workers[0])
		if job_level < 0 or worker == "":
			return
		var host := _neighbor_floor(geo, job_level, job_cell)
		if host.size.x < 1.0:
			return
		var pose_name := "carrying" if poses.has("carrying") else "standing"
		var on_left: bool = host.position.x < _rect(geo, job_level, job_cell).position.x
		var inset := maxf(36.0, host.size.x * 0.28)
		var x := host.end.x - inset if on_left else host.position.x + inset
		var foot_y := host.position.y + host.size.y - 2.0
		_paint_pose(pose_name, x, foot_y, host.size.y, worker, not on_left)

	func _neighbor_floor(geo: Dictionary, level: int, cell: int) -> Rect2:
		for delta in [-1, 1]:
			var next: int = cell + int(delta)
			if next < 0 or next >= 6:
				continue
			var spot: Dictionary = station.game.cells["%d:%d" % [level, next]]
			if str(spot.room) == "" and not bool(spot.dug):
				continue
			if _job_span(level, next).x >= 0:
				continue
			return _rect(geo, level, next)
		return Rect2()

	func _draw_output_badges(rect: Rect2, room: Dictionary) -> void:
		var detail: Dictionary = station.game.room_detail(str(room.uid))
		var outputs: Array = detail.get("outputs", [])
		if outputs.is_empty():
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var dim := bool(room.get("browned", false)) or bool(room.get("offline", false))
		if int(defin.get("staff_min", 0)) > 0 and room.staff.size() < int(defin.staff_min):
			dim = true
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var x := rect.position.x + 6.0
		var y := rect.position.y + rect.size.y - 22.0
		var ink := Color(0.96, 0.93, 0.86, 0.35 if dim else 0.95)
		for out in outputs:
			_paint_mini(Vector2(x, y), str(out.key), ink)
			x += 16.0
			var text := "+%d" % int(out.amount)
			draw_string(font, Vector2(x, y + 12.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 8.0

	func _draw_status(origin: Vector2, glyph_kind: String) -> void:
		var tex := ArtPack.icon_texture(glyph_kind, 24.0)
		if tex == null:
			return
		draw_texture_rect(tex, Rect2(origin, Vector2(24, 24)), false)

	func _paint_mini(origin: Vector2, glyph_kind: String, ink: Color) -> void:
		var tex := ArtPack.icon_texture(glyph_kind, 16.0)
		if tex != null:
			draw_texture_rect(tex, Rect2(origin, Vector2(16, 16)), false)
			return
		var c := origin + Vector2(7, 7)
		match glyph_kind:
			"food":
				draw_circle(c, 5.5, ink)
			"air":
				draw_arc(c, 5.0, 0, TAU, 16, ink, 1.6)
			"power":
				draw_line(c + Vector2(-2, -6), c + Vector2(1, 1), ink, 2.0)
				draw_line(c + Vector2(1, 1), c + Vector2(-2, 6), ink, 2.0)
			"materials":
				draw_rect(Rect2(origin + Vector2(1, 4), Vector2(12, 7)), ink)
			"tokens":
				draw_circle(c, 5.5, ink)
			"influence":
				draw_rect(Rect2(origin + Vector2(3, 1), Vector2(8, 12)), ink)
			_:
				draw_rect(Rect2(origin, Vector2(12, 12)), ink)

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

	func _draw_more(rect: Rect2, extra: int, filter_id: String = "") -> void:
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
		if filter_id != "":
			var screen := Rect2(pan + origin * zoom, box * zoom)
			more_hits.append({"rect": screen.grow(6.0), "filter": filter_id})

	func _pose_size(sprite: Texture2D, cell_h: float) -> Vector2:
		var target_h := cell_h * 0.58
		var aspect := sprite.get_width() / maxf(sprite.get_height(), 1.0)
		return Vector2(target_h * aspect, target_h)

	func _paint_pose(pose_name: String, cx: float, foot_y: float, cell_h: float, id: String, flip: bool) -> void:
		if not poses.has(pose_name):
			return
		var sprite: Texture2D = poses[pose_name]
		var fitted := _pose_size(sprite, cell_h)
		var dest := Rect2(cx - fitted.x * 0.5, foot_y - fitted.y, fitted.x, fitted.y)
		if flip:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		var shade := 0.36 + fmod(_id_hash(id), 5.0) * 0.02
		var tint := Color(
			clampf(shade * 1.2, 0.38, 0.55),
			clampf(shade * 0.68, 0.22, 0.36),
			clampf(shade * 0.28, 0.08, 0.16))
		draw_texture_rect(sprite, dest, false, tint)

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


class GuideLayer extends Control:
	var host

	func _process(_delta: float) -> void:
		if host == null or host.guide_step < 0 or host.guide_card == null:
			return
		var card: Control = host.guide_card
		var target: Rect2 = host._guide_target()
		var w := 380.0
		card.custom_minimum_size.x = w
		var h := maxf(card.get_combined_minimum_size().y, card.size.y)
		if h < 40.0:
			h = 140.0
		var pos := Vector2(16.0, host.size.y - host.chrome_bottom - h - 12.0)
		if target.size.x > 1.0 and Rect2(pos, Vector2(w, h)).intersects(target.grow(8.0)):
			var top := 90.0
			if host.hud != null:
				top = host.hud.size.y + 12.0
			pos = Vector2(16.0, top)
		card.position = pos
		card.size = Vector2(w, h)
		queue_redraw()

	func _draw() -> void:
		if host == null or host.guide_step < 0 or host.guide_card == null:
			return
		var target: Rect2 = host._guide_target()
		if target.size.x < 2.0:
			return
		var card: Control = host.guide_card
		var from := _edge_point(Rect2(card.position, card.size), target.get_center())
		var to := _edge_point(target, from)
		var color := Color("e2a63a")
		draw_line(from, to, color, 3.0)
		var dir := to - from
		if dir.length() < 4.0:
			return
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			to,
			to - dir * 14.0 + side * 6.0,
			to - dir * 14.0 - side * 6.0,
		]), color)

	func _edge_point(rect: Rect2, toward: Vector2) -> Vector2:
		var center := rect.get_center()
		var delta := toward - center
		if absf(delta.x) < 0.001 and absf(delta.y) < 0.001:
			return center
		var sx := rect.size.x * 0.5 / maxf(absf(delta.x), 0.001)
		var sy := rect.size.y * 0.5 / maxf(absf(delta.y), 0.001)
		return center + delta * minf(sx, sy)


class PeopleRail extends Control:
	var caption := ""
	var ink := Color("efe6d2")
	var face: Font

	func _draw() -> void:
		var font: Font = face if face != null else ThemeDB.fallback_font
		var mid_x := size.x * 0.5
		var mark := Color("e2a63a")
		draw_line(Vector2(mid_x + 7.0, 8.0), Vector2(mid_x - 7.0, 18.0), mark, 3.0)
		draw_line(Vector2(mid_x - 7.0, 18.0), Vector2(mid_x + 7.0, 28.0), mark, 3.0)
		if caption == "":
			return
		var font_size := 15
		var room := maxf(24.0, size.y - 44.0)
		var text_w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if text_w > room:
			font_size = maxi(11, int(floor(float(font_size) * room / text_w)))
		var origin := Vector2(mid_x + float(font_size) * 0.35, 40.0)
		draw_set_transform(origin, PI * 0.5, Vector2.ONE)
		draw_string(font, Vector2.ZERO, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class Glyph extends Control:
	var kind := "food"
	var ink := Color("efe6d2")

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var tex := ArtPack.icon_texture(kind, side)
		if tex != null:
			var px := side if side <= 32.0 else minf(side, 48.0)
			var origin := (size - Vector2(px, px)) * 0.5
			draw_texture_rect(tex, Rect2(origin, Vector2(px, px)), false)
			return
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
			"people", "crew":
				draw_circle(c + Vector2(0, -r * 0.55), r * 0.38, ink)
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.7, r), c + Vector2(0, -r * 0.1), c + Vector2(r * 0.7, r)
				]), ink)
			"clock":
				draw_arc(c, r * 0.78, 0, TAU, 24, ink, maxf(1.6, thick * 0.45))
				draw_line(c, c + Vector2(0, -r * 0.48), ink, maxf(1.6, thick * 0.4))
				draw_line(c, c + Vector2(r * 0.34, r * 0.08), ink, maxf(1.6, thick * 0.4))
			"lock":
				draw_arc(c + Vector2(0, -r * 0.2), r * 0.42, PI, TAU, 16, ink, maxf(1.6, thick * 0.45))
				draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.95)), ink)
			"arrow":
				draw_line(c + Vector2(-r * 0.75, 0), c + Vector2(r * 0.2, 0), ink, maxf(1.8, thick * 0.45))
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(r * 0.05, -r * 0.48), c + Vector2(r * 0.85, 0), c + Vector2(r * 0.05, r * 0.48)
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
		mark.custom_minimum_size = Vector2(32, 32) if ArtPack.icon_texture(glyph_name) != null else Vector2(22, 22)
		mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(mark)
		var lab := Label.new()
		lab.text = Copy.t(caption)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color("efe6d2"))
		if has_meta("caption_font") and get_meta("caption_font") is Font:
			lab.add_theme_font_override("font", get_meta("caption_font"))
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
