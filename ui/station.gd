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
const CARD_PAPER := Color("30261b")
const CARD_EDGE := Color("d9ac4f")
## Extra space above each button row in a card.
const BUTTON_GAP := 8.0
## The shortest an event banner may get before a tall card drops it altogether.
const BANNER_MIN_H := 72.0
const ALERT_INK := Color("e07a62")
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
	"listening_post": Color("2f8f62"),
}
const URGENT_WEEKS := 2
const STOCK_KEYS := ["air", "food", "power", "materials", "tokens", "influence"]
## Life support: air, food and power read larger, with a bar of the weeks they last.
const LIFE_KEYS := ["air", "food", "power"]
## Top bar numbers: amber while the week's net is below zero, red when the stock runs out within two weeks.
const STOCK_AMBER := Color("e8b04a")
const STOCK_RED := Color("ff6a55")
const PILL := Color(0.0, 0.0, 0.0, 0.42)
const STOCK_WHAT := {
	"power": "Keeps the rooms running. Rooms without power go dark.",
	"food": "Everyone eats every week. Running short costs hope, and people can die.",
	"air": "Everyone breathes every week. Running short costs hope, and people can die.",
	"materials": "Spent on building, upgrades and filter upkeep.",
}
const LINE_NAMES := {
	"quarantine": "Quarantine",
	"harvest": "Harvest",
	"vent": "Vent cut",
	"outposts": "Outposts",
	"outpost_upkeep": "Outpost upkeep",
	"flood": "Flood",
	"full": "Storage full",
	"spoil": "Spoilage",
	"rot": "Rot in the stores",
	"meals": "Meals",
	"breathing": "Breathing",
	"filter_upkeep": "Filter upkeep",
}
const YIELD_ZERO := {
	"off": "switched off",
	"flooded": "flooded",
	"broken": "out of order",
	"dark": "no power, browned out",
	"unstaffed": "no crew",
	"event": "stopped by an event",
	"mold": "mold in the beds",
}
const ROMAN := ["", "I", "II", "III", "IV", "V"]
const UPGRADE_FLASH_MS := 900
const BRASS := Color("c9a050")
const YIELD_STEP := {
	"skill": "crew skill",
	"half_crew": "short crew",
	"wear": "filter wear",
	"double_shifts": "double shifts",
	"event": "event",
	"quarantine": "quarantine",
	"push": "pushed",
}
const ModalDeck = preload("res://ui/modals.gd")
const NetworkViewScript = preload("res://ui/network_view.gd")
const ArtPack = preload("res://ui/art_pack.gd")
const Brief = preload("res://sim/brief.gd")
const WeekForecast = preload("res://sim/week_forecast.gd")
const WAITING := "Someone is still waiting. Choose before the week ends."
const ORDER_DONE := {
	"propaganda": "agitation completed",
	"envoy": "envoy mission completed",
	"aid": "aid delivered",
	"pay": "demand paid",
	"gift": "gift delivered",
	"trade": "trade deal struck",
	"move": "squad moved",
	"focus": "station focus set",
	"expedition": "expedition set out",
}
const FIND_LINES := {
	"flooded": "The dig hit a flooded pocket.",
	"maintenance": "The dig opened an old maintenance room.",
	"sealed_door": "The dig found a sealed door marked FLOOR.",
	"cable": "The dig turned up old cable.",
	"salvage": "The dig turned up salvage.",
}
const DISCLAIMER := "Underline is a work of fiction. Its people, communities and events are invented. Real New York places are used fictitiously, and any resemblance to real persons is coincidental. Not affiliated with or endorsed by the MTA or the City of New York."

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
var pop_chip := {}
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
var hope_dial: Dial
var dis_dial: Dial
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
var card_fit_tries := 0
## Content height at the last fit; the card is refitted every frame until two measures agree.
var card_fit_last := -1.0
## Card buttons ignore presses until this tick (msec), set by each card press.
var card_click_guard := 0
var help_unfold := false
var hint_data: Array = []
var hint_box: HintCallout
var hint_id := ""
var hint_mark := ""
var hint_next := 0
## Set by shot tools that want a callout on screen.
var hints_in_shots := false
## A save loaded past week 6 never shows hints.
var hints_late := false
const CARD_CLICK_GUARD_MS := 350
## The audience card may be wider (800 px) and reach over the dimmed ticker row; reset by every _open_card.
var card_roomy := false
var portraits: Array = []
var portrait_names: Array = []
## Playtest: consent, how-to and crash cards sit on their own layer above the menu.
var notice_layer: Control
var howto_check: CheckBox
var howto_count := 0
var log_game: Game
var log_week := -1
var log_over := ""
var ahead: PanelContainer
var deck = ModalDeck.new()
var ambient_restore: Callable = Callable()
var shelved_event := ""
var check_picks := {}
var check_flash := false
var pending_button: Button
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
var guide_skips := 0
var toast_label: Label
var toast_plate: PanelContainer
var toast_fade: Tween
var blown_flash: TextureRect
var salvage_float: Control
## P43 dawn chip (paper strip under the top bar) and the once-per-run platform float.
var dawn_chip: PanelContainer
var dawn_chip_label: Label
var dawn_chip_icon: TextureRect
var home_float: Label
var home_float_tween: Tween
## End turn refreshes before the dawn card opens. Hold the float until that card is up or gone.
var home_hold_float := false
## P44 sticky yard badge. One plate, not a soft dawn chip.
var away_badge: PanelContainer
var away_badge_label: Label
var away_badge_body: Label
var away_badge_icon: TextureRect
var away_float: Label
var away_float_until := 0
var away_float_fade: Tween
## P48 sticky cot count. One plate, on the infirmary when it stands, else the people strip. Not a dawn chip.
var sick_badge: PanelContainer
var sick_badge_label: Label
var sick_badge_body: Label
var sick_badge_icon: TextureRect
var sick_float: Label
var sick_float_until := 0
var sick_float_fade: Tween
var undo_toast: PanelContainer
## P42 dawn rail-noise chip (bottom-left yard) and the once-per-run platform float.
var rail_chip: PanelContainer
var rail_chip_label: Label
var rail_icon: TextureRect
var rail_float: PanelContainer
var rail_float_label: Label
var rail_chip_live := false
var rail_float_live := false
var rail_hold_ms := 0
var rail_last_ms := 0
var rail_fading := false
var rail_token := 0
var rail_fade: Tween
var delta_hold_until := 0
var news_open := false
var _soft_gap_warned := false
var picker_busy_open := false
var news_week := -1
var net_guide := false
var net_guided := false
var net_guide_sid := ""
var guide_played := false
var shot_mode := false
var menu_button: Button
## Brass "Address" by the meters (Tension pass, brief B2): a council order that buys hope with influence once a week.
var address_button: Button
## Discontent gauge pulse while a revolt is 2 weeks or less away; killed when the warning clears.
var dis_pulse: Tween
var hub_button: Button
var network_button: Button
var night_button: Button
var night_panel: Control
var network_view: Control
var showing_network := false
var hub_layer: Control
var hub_station_label: Label
var hub_community_label: Label
var hub_begin: Button
var hub_back: Button
var number_font: Font
var life_epilogue: Control
var life_epilogue_panel: Control
var life_epilogue_body: VBoxContainer
var life_epilogue_actions: HBoxContainer
var life_epilogue_dots: HBoxContainer
var life_epilogue_eyebrow: Label
var life_epilogue_page := 0
var at_menu := false
var hold_dawn := false
var menu_layer: Control
var menu_root: Control
var week_fc := {}
var dark_now := {}
var room_out := {}
var menu_settings: Control
var menu_credits: Control
var settings_body: VBoxContainer
var credits_body: VBoxContainer
var menu_picture: TextureRect
var menu_dim: ColorRect
var continue_button: Button
var settings_from_game := false
var filling_settings := false
var stock_shown := {}
var stock_week := 0
var stock_tween: Tween
var modal_tween: Tween
## Slides the People drawer open and shut.
var drawer_tween: Tween
var modal_open := false
var dossier_tab := "profile"
var journal_filter := ""
var room_open := ""
var room_hover := ""
var radio_panel: PanelContainer
var radio_text: Label
var radio_tween: Tween
var vo_pill: PanelContainer
var vo_label: Label
var vo_bars: Control
var vo_sub: Label
var vo_dossier := ""
var vo_story_progress := 0.0
var audience_key := ""
var audience_heard := false
var dawn_heard := ""
var event_vo_heard := ""
## Room type -> "<game id>:<week>" for the week an event's data named that room; its yard sign shows a warning.
var incident_rooms := {}
## The leader line last voiced; a redraw that shows the same line again stays silent.
var leader_voiced := ""
var vo_queue: Array = []
var vo_text := ""
var vo_text_caption := ""
var vo_text_until := 0
var radio_bars: Control
var radio_done_ms := 0
var radio_extra_week := -1
const RADIO_HALF_WEEK_MS := 75000
var sentence_re := RegEx.create_from_string("[^.!?\u2026]+[.!?\u2026]+[\"'\u00bb\u201d]?")


func _ready() -> void:
	Copy.boot()
	Settings.load_file()
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
	get_tree().root.theme = _tooltip_theme()
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
	if _want_shots() or _want_clarity() or _want_review() or _want_hub() or _want_polish() or _want_network() or _want_checks() or _want_ux() or _want_visual() or _want_lore() or _want_drawer() or _want_rooms() or _want_night():
		shot_mode = true
		Lore.dry = true
	if hub_button != null:
		hub_button.visible = _hub_texture() != null
	if not shot_mode:
		Settings.apply_display(get_window())
		get_window().size_changed.connect(_rescale)
		Sound.apply_buses()
		var score := Music.new()
		score.name = "Music"
		score.source = music_state
		add_child(score)
		PlaytestLog.begin(_session_info())
		_playtest_prompts.call_deferred()
	if shot_mode:
		if not _want_hub() and not _want_polish() and not _want_network() and not _want_checks() and not _want_ux() and not _want_visual() and not _want_lore() and not _want_drawer() and not _want_rooms() and not _want_night():
			_show_dawn()
	elif Settings.resume and game != null and SaveGame.load_latest(game):
		Settings.resume = false
		at_menu = false
		_loaded_hints()
		Sound.bed("station")
		_refresh()
		_note_save_recovery()
		if Settings.reopen == "settings":
			Settings.reopen = ""
			_open_settings(true)
	else:
		_show_main_menu()
		if Settings.reopen == "settings":
			Settings.reopen = ""
			_open_settings(false)
		elif not Settings.intro_seen:
			_play_intro()
	if _want_checks():
		await _check_shots()
	elif _want_polish():
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
	elif _want_ux():
		await _ux_shots()
	elif _want_visual():
		await _visual_shots()
	elif _want_lore():
		await _lore_shots()
	elif _want_drawer():
		await _drawer_shots()
	elif _want_rooms():
		await _rooms_shots()
	elif _want_vo():
		await _vo_shots()
	elif _dev_args().has("--journal"):
		await _journal_shots()
	elif _want_night():
		await _night_shots()


func _journal_shots() -> void:
	hold_dawn = false
	await _settle(_shot_size())
	_begin_new_game(false)
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	var spot := _first_open_floor()
	if spot.x >= 0:
		game.apply({"kind": "build", "type": "hydroponics", "level": spot.x, "cell": spot.y})
	var target := ""
	for sid in game.stations:
		if game.order_block("propaganda", str(sid)) == "":
			target = str(sid)
			break
	print("JOURNAL agitation target %s queued %s" % [target, target != "" and game.queue_order({"kind": "order", "order": "propaganda", "station": target})])
	for i in 11:
		if not game.pending.is_empty():
			var ev: Dictionary = game.pending[0]
			game.apply({"kind": "event", "event_id": str(ev.id), "choice_id": str(ev.choices[0].id)})
		game.pending.clear()
		game.end_week()
		if game.over != "":
			break
	game.pending.clear()
	_refresh()
	_close_card()
	print("JOURNAL rows %d bytes %d" % [game.journal.size(), JSON.stringify(game.journal).length()])
	await _frame()
	await _frame()
	_save("journal_tray")
	_show_journal()
	await _frame()
	await _frame()
	_save("journal_all")
	_pick_journal_filter("map")
	await _frame()
	await _frame()
	_save("journal_map")
	get_tree().quit()


func _want_vo() -> bool:
	return _dev_args().has("--vo")


func _vo_shots() -> void:
	hold_dawn = false
	await _settle(_shot_size())
	_begin_new_game(false)
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	_refresh()
	_open_dossier("inez")
	_play_story("inez")
	await get_tree().create_timer(0.4).timeout
	_tick_voice()
	await _frame()
	_save("vo_dossier_playing")
	_stop_story("inez")
	await _frame()
	await _frame()
	_save("vo_dossier_replay")
	_close_card()
	for person in game.residents:
		var pid := str(person.get("id", ""))
		var row := _story(pid)
		if not bool(person.get("core", false)) and not row.is_empty() and not Voice.has_audio(row):
			_show_person(pid)
			await _frame()
			_save("vo_person_story")
			_open_dossier(pid)
			await _frame()
			await _frame()
			_save("vo_dossier_text")
			_close_card()
			break
	_open_dossier("mara")
	await get_tree().create_timer(4.0).timeout
	_tick_voice()
	await _frame()
	_save("vo_pill")
	print("VO first open plays story: %s" % str(Voice.playing("mara_story")))
	_close_card()
	await _frame()
	print("VO closing the dossier fades it: %s" % str(not Voice.playing()))
	_play_radio(Radio.by_id("news_001"))
	await get_tree().create_timer(0.4).timeout
	_tick_voice()
	await _frame()
	_save("vo_radio")
	_hide_radio()
	Voice.stop()
	var played: PackedStringArray = []
	for cast in ["old_man_coney", "salty_maggie", "bait", "barnum", "sylvia"]:
		for pid in game.people:
			if game.cast_id_of(game.people[pid]) == cast:
				_open_dossier(str(pid))
				await get_tree().create_timer(0.5).timeout
				played.append("%s %s" % [cast, "plays" if Voice.playing(cast + "_story") else "SILENT"])
				if cast == "salty_maggie":
					await get_tree().create_timer(2.0).timeout
					_tick_voice()
					await _frame()
					_save("vo_dossier_coney")
				_close_card()
				await _frame()
	print("VO phase 1 stories: " + ", ".join(played))
	_play_radio(Voice.line("radio_news_005"))
	await get_tree().create_timer(3.0).timeout
	_tick_voice()
	await _frame()
	print("VO radio_news_005 plays: %s" % str(Voice.playing("radio_news_005")))
	_save("vo_radio_005")
	_hide_radio()
	Voice.stop()
	game.vo_cues.append("food_critical")
	_tick_voice()
	await _frame()
	_tick_voice()
	await _frame()
	_save("vo_system_text")
	vo_text_until = 0
	_say(Voice.event_line("lamps", ""), Copy.t("Station"))
	_tick_voice()
	await _frame()
	_save("vo_event_text")
	vo_text_until = 0
	_open_settings(true)
	await _frame()
	await _frame()
	_save("vo_settings")
	get_tree().quit()


func _want_lore() -> bool:
	return _dev_args().has("--lore")


func _want_drawer() -> bool:
	return _dev_args().has("--drawer")


func _drawer_shots() -> void:
	hold_dawn = false
	await _settle(_shot_size())
	_show_main_menu()
	await _frame()
	await _frame()
	_save("menu_disclaimer")
	_open_credits()
	await _frame()
	await _frame()
	_save("credits_disclaimer")
	_begin_new_game(false)
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	_refresh()
	await _frame()
	await _frame()
	_save("drawer_closed")
	drawer_open = true
	_place_drawer()
	_fill_people()
	await _frame()
	await _frame()
	_save("drawer_open")
	var free_id := ""
	for person in game.residents:
		if _person_post(str(person.id)) == "free" and int(person.get("sick", 0)) == 0:
			free_id = str(person.id)
			break
	var full_cell := Vector2i(-1, -1)
	var open_cell := Vector2i(-1, -1)
	var shut_cell := Vector2i(-1, -1)
	for room in game.rooms:
		var at := Vector2i(int(room.level), int(room.cell))
		var preview: Dictionary = game.assign_preview(free_id, str(room.uid))
		if bool(preview.get("full", false)) and full_cell.x < 0:
			full_cell = at
		elif bool(preview.ok) and open_cell.x < 0:
			open_cell = at
		elif not bool(preview.ok) and not bool(preview.get("full", false)) and shut_cell.x < 0:
			shut_cell = at
	yard.drag_lock = true
	yard.drag_id = free_id
	for pair in [["drag_swap", full_cell], ["drag_open", open_cell], ["drag_blocked", shut_cell]]:
		yard.drop_cell = pair[1]
		yard.queue_redraw()
		await _frame()
		await _frame()
		_save(str(pair[0]))
	yard.drag_id = ""
	yard.drop_cell = Vector2i(-1, -1)
	yard.drag_lock = false
	if full_cell.x >= 0:
		var uid := str(game.cells["%d:%d" % [full_cell.x, full_cell.y]].room)
		_drop_person(free_id, uid)
		_fill_people()
		await _frame()
		await _frame()
		_save("drawer_swapped")
	_hide_undo_toast()
	drawer_open = false
	_place_drawer()
	_toggle_network()
	network_view.open_sheet(str(game.capital_id))
	await _frame()
	await _frame()
	_save("net_sheet_home")
	var foreign: String = network_view.first_known_neighbor()
	if foreign != "":
		network_view.open_sheet(foreign)
		await _frame()
		await _frame()
		_save("net_sheet_neighbor")
	get_tree().quit()


func _lore_shots() -> void:
	hold_dawn = false
	await _settle(_shot_size())
	_begin_new_game(false)
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	var spot := _first_open_floor()
	if spot.x >= 0:
		game.apply({"kind": "build", "type": "workshop", "level": spot.x, "cell": spot.y})
	game.end_week()
	game.pending.clear()
	_refresh()
	_close_card()
	var cast_id := ""
	for person in game.residents:
		if Lore.has(game.cast_id_of(person)):
			cast_id = str(person.id)
			break
	_open_dossier(cast_id)
	await _frame()
	await _frame()
	_save("lore_profile")
	_pick_dossier_tab(cast_id, "nostalgia")
	await _frame()
	await _frame()
	_save("lore_nostalgia")
	_pick_dossier_tab(cast_id, "anecdote")
	await _frame()
	await _frame()
	_save("lore_anecdote")
	_close_card()
	drawer_open = true
	_place_drawer()
	_fill_people()
	await _frame()
	await _frame()
	_save("lore_people")
	drawer_open = false
	_place_drawer()
	_play_radio(Radio.next())
	await _frame()
	await _frame()
	_save("radio_popup")
	_hide_radio()
	_show_journal()
	await _frame()
	await _frame()
	_save("journal_all")
	_pick_journal_filter("builds")
	await _frame()
	await _frame()
	_save("journal_builds")
	journal_filter = ""
	_close_card()
	_open_settings(true)
	await _frame()
	await _frame()
	_save("settings_sound")
	get_tree().quit()


func _want_ux() -> bool:
	return _dev_args().has("--ux")


func _want_visual() -> bool:
	return _dev_args().has("--visual")


func _want_shots() -> bool:
	return _dev_args().has("--shots") or (OS.is_debug_build() and OS.get_environment("UNDERLINE_SHOTS") == "1")


## Screenshot and review switches. Empty in a release export, so a player's build cannot reach them.
func _dev_args() -> PackedStringArray:
	return OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()


func _want_review() -> bool:
	return _dev_args().has("--review")


func _want_clarity() -> bool:
	return _dev_args().has("--clarity")


func _want_hub() -> bool:
	return _dev_args().has("--hub")


func _want_checks() -> bool:
	return _dev_args().has("--checks")


func _want_rooms() -> bool:
	return _dev_args().has("--rooms")


## The station built out by a careful bot to week 12, for judging how rooms read as separate spaces: the whole
## station, a close look at a busy row, and an empty dug cell next to rooms. Writes rooms_station*.png.
func _rooms_shots() -> void:
	shot_mode = true
	hold_dawn = false
	at_menu = false
	await _settle(_shot_size())
	_close_card()
	if guide_layer != null:
		guide_layer.visible = false
	var bot := Bot.new()
	bot.profile = "careful"
	var guard := 0
	while game.over == "" and game.week < 12 and guard < 16:
		guard += 1
		bot._act(game)
		game.end_week()
	game.pending.clear()
	hold_dawn = true
	_refresh()
	for i in 6:
		if deck.is_empty() and not modal_open:
			break
		_close_card()
	await _frame()
	await _frame()
	_save("rooms_station")
	var busy := Vector2i(-1, -1)
	var best := -1
	for room in game.rooms:
		var row := 0
		for other in game.rooms:
			if int(other.level) == int(room.level):
				row += 1
		if row > best:
			best = row
			busy = Vector2i(int(room.level), int(room.cell))
	if busy.x >= 0:
		yard._zoom_to(busy.x, busy.y)
		await _frame()
		await _frame()
		_save("rooms_station_zoom")
	var empty := Vector2i(-1, -1)
	for key in game.cells:
		var c: Dictionary = game.cells[key]
		if bool(c.get("dug", false)) and str(c.get("room", "")) == "":
			empty = Vector2i(int(c.level), int(c.cell))
	if empty.x >= 0:
		yard._zoom_to(empty.x, empty.y)
		await _frame()
		await _frame()
		_save("rooms_station_empty")
	get_tree().quit()


func _want_polish() -> bool:
	return _dev_args().has("--polish")


func _want_network() -> bool:
	return _dev_args().has("--network")


func _tabular(base: Font) -> Font:
	if base == null:
		return null
	var variation := FontVariation.new()
	variation.base_font = base
	variation.opentype_features = {"tnum": 1}
	return variation


## Shot scripts freeze motion for still frames; a recording of the station turns it back on with motion_in_shots.
var motion_in_shots := false


func _motion_off() -> bool:
	return (shot_mode and not motion_in_shots) or Settings.reduced()


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
	portrait_names.clear()
	var i := 1
	while ResourceLoader.exists("res://assets/portraits/portrait_%02d.webp" % i):
		var tex := ArtPack.load_texture("res://assets/portraits/portrait_%02d.webp" % i)
		if tex != null:
			portraits.append(tex)
			portrait_names.append("portrait_%02d" % i)
		i += 1


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
	if game != null:
		var at := portrait_names.find(game.portrait_name(id, portrait_names))
		if at >= 0:
			return portraits[at]
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
	_watch_log()
	_tick_rail_noise()
	_tick_radio()
	_tick_voice()
	if Time.get_ticks_msec() >= hint_next:
		hint_next = Time.get_ticks_msec() + 200
		_tick_hints()
	_pulse_alarms()
	_tick_away_float()
	_tick_sick_cots()
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


## A stock about to run out (red) breathes in the top bar so the eye finds it without reading the numbers.
func _pulse_alarms() -> void:
	if chips.is_empty():
		return
	var still := _motion_off()
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	for key in chips:
		var chip: Dictionary = chips[key]
		if not chip.has("box") or chip.box == null:
			continue
		if str(chip.get("alarm", "")) == "red" and not still:
			chip.box.modulate = Color(1.0, 0.82 + 0.18 * beat, 0.82 + 0.18 * beat, 1.0)
		else:
			chip.box.modulate = Color.WHITE


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
	var salvage_button := _tool("salvage_open", "salvage.title", _show_salvage)
	salvage_button.tooltip_text = Copy.t("salvage.title")
	var journal_button := _tool("journal", "Journal", _show_journal)
	pending_button = _tool("lock", "Pending", _show_pending)
	pending_button.visible = false
	burn_button.tooltip_text = "Burn salvage"
	power_button.tooltip_text = "Power order"
	people_button.tooltip_text = "Residents"
	journal_button.tooltip_text = Copy.t("Journal") + "  (J)"
	for button in [pump_button, quarantine_button, burn_button, power_button, people_button, salvage_button, journal_button, pending_button]:
		tray.add_child(button)

	night_button = _button("run.panel_title", open_night_panel)
	night_button.custom_minimum_size = Vector2(168, 44)
	night_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	night_button.add_theme_font_size_override("font_size", 16)
	night_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(night_button)
	night_panel = preload("res://ui/night_panel.gd").new()
	add_child(night_panel)
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
	_build_away_badge()
	_build_sick_badge()

	footer = _label("", 14)
	footer.visible = false
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	_build_rail_noise()
	_build_dawn_chip()
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


## The top bar is the station's ceiling beam: dark riveted steel with a brass lip and a shadow on the rooms below.
func _top_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	var beam := _steel_style()
	beam.bg_color = Color(0.085, 0.085, 0.095, 0.97)
	beam.border_color = Color(0.62, 0.5, 0.3, 0.75)
	beam.set_border_width_all(0)
	beam.border_width_bottom = 2
	beam.set_corner_radius_all(0)
	beam.shadow_color = Color(0, 0, 0, 0.55)
	beam.shadow_size = 10
	beam.shadow_offset = Vector2(0, 5)
	beam.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", beam)
	panel.draw.connect(_draw_beam_rivets.bind(panel))
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
	week_label.add_theme_color_override("font_color", Color("e9d6a6"))
	var plaque := PanelContainer.new()
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.13, 0.11, 0.08, 1.0)
	plate.border_color = Color(0.7, 0.55, 0.3, 0.9)
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(3)
	plate.content_margin_left = 10
	plate.content_margin_right = 10
	plate.shadow_color = Color(0, 0, 0, 0.5)
	plate.shadow_size = 3
	plaque.add_theme_stylebox_override("panel", plate)
	plaque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(week_label)
	title_row.add_child(plaque)

	res_grid = GridContainer.new()
	res_grid.columns = 7
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
		var life := str(key) in LIFE_KEYS
		var value := _label("0", 26 if life else 21)
		value.add_theme_constant_override("outline_size", 4)
		value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if number_font != null:
			value.add_theme_font_override("font", number_font)
		var digit := 12.0
		if number_font != null:
			digit = number_font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 26 if life else 21).x
		value.custom_minimum_size = Vector2(digit * 3.4 + 2.0, 24)
		var delta := _label("", 11)
		delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		delta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if number_font != null:
			delta.add_theme_font_override("font", number_font)
		var small := 8.0
		if number_font != null:
			small = number_font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		delta.custom_minimum_size = Vector2(small * 3.0 + 2.0, 13)
		chip.tooltip_text = Copy.res(str(key))
		chip.add_child(icon_col)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", -3)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stack.add_child(value)
		var under := HBoxContainer.new()
		under.add_theme_constant_override("separation", 4)
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		under.add_child(delta)
		var left_bar: ColorRect = null
		if life:
			var track := ColorRect.new()
			track.color = Color(1, 1, 1, 0.12)
			track.custom_minimum_size = Vector2(26, 3)
			track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			track.mouse_filter = Control.MOUSE_FILTER_IGNORE
			left_bar = ColorRect.new()
			left_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
			left_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			track.add_child(left_bar)
			under.add_child(track)
		stack.add_child(under)
		chip.add_child(stack)
		chip.gui_input.connect(_chip_input.bind(str(key)))
		chip.mouse_entered.connect(_peek_source.bind(str(key)))
		chip.mouse_exited.connect(_unpeek_source)
		var pill := PanelContainer.new()
		var pill_face := StyleBoxFlat.new()
		pill_face.bg_color = PILL
		pill_face.set_corner_radius_all(14)
		pill_face.content_margin_left = 8
		pill_face.content_margin_right = 4
		pill_face.content_margin_top = 1
		pill_face.content_margin_bottom = 1
		pill.add_theme_stylebox_override("panel", pill_face)
		pill.mouse_filter = Control.MOUSE_FILTER_PASS
		pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if life:
			pill_face.bg_color = Color(0.0, 0.0, 0.0, 0.55)
			pill_face.border_color = Color(0.62, 0.5, 0.3, 0.35)
			pill_face.set_border_width_all(1)
		pill.add_child(chip)
		var cell: Control = pill
		if str(key) == "materials":
			var gap := MarginContainer.new()
			gap.add_theme_constant_override("margin_left", 14)
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_PASS
			gap.add_child(pill)
			cell = gap
		res_grid.add_child(cell)
		chips[key] = {"box": chip, "value": value, "delta": delta, "icon": icon, "name": name, "pill": pill, "left": left_bar}
	res_grid.add_child(_blueprint_chip())
	title_row.add_child(_people_pill())

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 12)
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(meters)
	meter_box = meters
	meters.add_child(_meter(Color("d7a441"), true))
	meters.add_child(_meter(Color("c4544a"), false))
	address_button = _address_button()
	address_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meters.add_child(address_button)
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


## People against beds at a glance, "18/24", beside the stocks; soldiers under it. Red when beds run out.
func _draw_beam_rivets(panel: PanelContainer) -> void:
	var y := panel.size.y - 6.0
	var x := 10.0
	while x < panel.size.x - 6.0:
		panel.draw_circle(Vector2(x, y), 2.2, Color(0.02, 0.02, 0.02, 0.9))
		panel.draw_circle(Vector2(x - 0.6, y - 0.6), 1.5, Color(0.42, 0.4, 0.37, 0.9))
		x += 46.0


func _people_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = PILL
	face.set_corner_radius_all(14)
	face.content_margin_left = 8
	face.content_margin_right = 10
	face.content_margin_top = 1
	face.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", face)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pill.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_show_crowd()
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var icon := Glyph.new()
	icon.kind = "people"
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var value := _label("0/0", 22)
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if number_font != null:
		value.add_theme_font_override("font", number_font)
	col.add_child(value)
	var guard := _label("", 11)
	guard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guard.add_theme_color_override("font_color", MUTED)
	col.add_child(guard)
	pop_chip = {"pill": pill, "value": value, "guard": guard}
	return pill


func _sync_people_pill() -> void:
	if pop_chip.is_empty() or game == null:
		return
	var pop := game.residents.size()
	var beds := game.housing()
	var value: Label = pop_chip.value
	value.text = "%d/%d" % [pop, beds]
	var color := INK
	if pop > beds:
		color = STOCK_RED
	elif pop == beds:
		color = STOCK_AMBER
	value.add_theme_color_override("font_color", color)
	var guard: Label = pop_chip.guard
	guard.text = Copy.t("Guard %d") % game.soldier_count()
	var tip := "%s\n%s" % [game.crowd_tip(), Copy.t("Guard: %s. Soldiers eat and sleep here but work no room.") % Words.count(game.soldier_count(), "soldier")]
	pop_chip.pill.tooltip_text = tip


func _meter(fill_color: Color, hope: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(88, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var meter_key := "hope" if hope else "discontent"
	box.gui_input.connect(_chip_input.bind(meter_key))
	box.mouse_entered.connect(_peek_source.bind(meter_key))
	box.mouse_exited.connect(_unpeek_source)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var dial := Dial.new()
	dial.needle = fill_color
	dial.danger_high = not hope
	dial.custom_minimum_size = Vector2(46, 30)
	dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dial)
	var lab := _label("Hope", 12)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.14)
	track.custom_minimum_size = Vector2(0, 4)
	track.visible = false
	var fill := ColorRect.new()
	fill.color = fill_color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = 0.5
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)
	box.add_child(track)
	if hope:
		hope_dial = dial
		hope_label = lab
		hope_fill = fill
	else:
		dis_dial = dial
		dis_label = lab
		dis_fill = fill
	return box


func _side_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var drawer_face := _steel_style()
	drawer_face.bg_color = Color(0.055, 0.05, 0.045, 0.97)
	drawer_face.border_color = Color(0.89, 0.65, 0.23, 0.7)
	drawer_face.set_border_width_all(0)
	drawer_face.border_width_left = 3
	drawer_face.shadow_color = Color(0, 0, 0, 0.55)
	drawer_face.shadow_size = 14
	drawer_face.shadow_offset = Vector2(-6, 0)
	panel.add_theme_stylebox_override("panel", drawer_face)
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	people_tab = Button.new()
	people_tab.focus_mode = Control.FOCUS_NONE
	people_tab.pressed.connect(_toggle_drawer)
	people_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	people_tab.pressed.connect(func(): Sound.play("click"))
	_style_tool(people_tab)
	people_tab.custom_minimum_size = Vector2(52, 72)
	people_rail = PeopleRail.new()
	people_rail.set_anchors_preset(Control.PRESET_FULL_RECT)
	people_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	people_rail.face = display_font if display_font != null else body_font
	people_rail.still = _motion_off()
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
	people_head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(people_head)
	var shut := _button("×", _toggle_drawer)
	shut.custom_minimum_size = Vector2(40, 36)
	shut.alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(shut)
	people_expand.add_child(head)
	hint = _label("Drag a name onto a room or a group here. Drop on a full room to swap. Drop on Free to take someone off work.", 13)
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
		if ticker_label.text == game.crowd_line():
			_show_crowd()
			return
		_open_forecast()


func _show_crowd() -> void:
	if not _claim(ModalDeck.AMBIENT, "crowd", _show_crowd):
		return
	_open_card("Overcrowding")
	_body(game.crowd_tip())
	if game.residents.size() > game.housing():
		var fix: Dictionary = game._supply_hint("quarters")
		var go := _button(str(fix.text), func() -> void:
			_close_card()
			_open_forecast_at(str(fix.hint), int(fix.level), int(fix.cell))
		)
		go.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_body.add_child(go)
	_fit_card()


func _layout() -> void:
	_place_chrome()
	_place_source()
	_place_sheet()
	if yard != null:
		yard.on_resize()


func _place_chrome() -> void:
	if res_grid != null:
		res_grid.columns = 7
	if meter_box != null and title_row != null and hud_box != null:
		var row_w := title_row.get_combined_minimum_size().x
		if meter_box.get_parent() != title_row:
			row_w += meter_box.get_combined_minimum_size().x + float(title_row.get_theme_constant("separation"))
		var narrow := row_w + 24.0 > size.x
		if narrow and meter_box.get_parent() == title_row:
			title_row.remove_child(meter_box)
			hud_box.add_child(meter_box)
			hud_box.move_child(meter_box, 1)
		elif not narrow and meter_box.get_parent() != title_row:
			meter_box.get_parent().remove_child(meter_box)
			title_row.add_child(meter_box)
			if menu_button != null and menu_button.get_parent() == title_row:
				title_row.move_child(meter_box, menu_button.get_index())
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
		hud_h = maxf(hud_h, hud.get_combined_minimum_size().y)
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
	if night_button != null:
		night_button.anchor_left = 1.0
		night_button.anchor_right = 1.0
		night_button.anchor_top = 1.0
		night_button.anchor_bottom = 1.0
		night_button.offset_right = -margin
		night_button.offset_left = -margin - end_w
		night_button.offset_bottom = -margin - end_h - 8.0
		night_button.offset_top = -margin - end_h - 8.0 - 44.0
		night_button.custom_minimum_size = Vector2(end_w, 44)
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
		var net_w := 240.0 if showing_network else 132.0
		network_button.anchor_left = 1.0
		network_button.anchor_right = 1.0
		network_button.anchor_top = 1.0
		network_button.anchor_bottom = 1.0
		network_button.custom_minimum_size = Vector2(net_w, tool_h)
		network_button.offset_right = -margin - end_w - 8.0
		network_button.offset_left = -margin - end_w - 8.0 - net_w
		network_button.offset_bottom = -margin
		network_button.offset_top = -margin - tool_h
		network_button.text = Copy.t("Back to your station") if showing_network else Copy.t("Network")
		network_button.tooltip_text = Copy.t("Close the map and return to your own station.") if showing_network else Copy.t("Open the map of the tunnels.")
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
		var tools := tray.get_child_count()
		var gap := float(tray.get_theme_constant("separation"))
		tray.offset_left = margin
		tray.offset_top = -margin - tool_h
		tray.offset_right = margin + tool_w * float(tools) + gap * float(maxi(0, tools - 1))
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
	_place_rail_noise()
	_place_dawn_chip(hud_h)
	_place_home_float()
	_place_drawer()
	_place_card()
	_place_ahead()
	if yard != null:
		yard.on_resize()
	_sync_away_badge()
	_sync_sick_badge()


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
	var w := 60.0
	if drawer_open:
		w = minf(380.0, size.x * 0.42)
	var goal := size.x - w
	if drawer_tween != null and drawer_tween.is_valid():
		drawer_tween.kill()
	var width_now := side.offset_right - side.offset_left
	if _motion_off() or absf(width_now - w) < 1.0 or absf(side.offset_right - size.x) > 1.0:
		side.offset_left = goal
	else:
		drawer_tween = create_tween()
		drawer_tween.tween_property(side, "offset_left", goal, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	card.add_theme_stylebox_override("panel", _card_style())
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
	card_body.add_theme_constant_override("separation", 6)
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
	var max_w := minf(size.x - margin * 2.0, 800.0 if card_roomy else 680.0)
	var top_limit := _card_top_limit()
	var bottom_limit := 12.0
	var max_h := size.y - top_limit - bottom_limit
	card_body.custom_minimum_size.x = max_w - 36.0
	var left := (size.x - max_w) / 2.0
	card.anchor_left = 0.0
	card.anchor_top = 0.0
	card.anchor_right = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = left
	card.offset_right = left + max_w
	if card.offset_bottom - card.offset_top < 96.0 or card.offset_bottom > top_limit + max_h + 0.5:
		card.offset_top = top_limit
		card.offset_bottom = top_limit + max_h
	card_fit_tries = 0
	card_fit_last = -1.0
	_queue_shrink()


## Containers settle over a few deferred passes after the body is rebuilt, so the fit is measured on the
## next frame and again until the content height stops changing.
func _queue_shrink() -> void:
	if card_fit_queued:
		return
	card_fit_queued = true
	get_tree().process_frame.connect(_shrink_card, CONNECT_ONE_SHOT)


## Puts `gap` px above every button row in the card that follows other content; the gaps fold to 0 when
## the card has to squeeze. Idempotent: a gap already in place is resized, never doubled.
func _space_buttons(gap: float) -> void:
	var kids := card_body.get_children()
	for i in range(kids.size() - 1, 0, -1):
		var child: Node = kids[i]
		if child.has_meta("button_gap") or not _holds_button(child):
			continue
		var before: Node = kids[i - 1]
		if before.has_meta("button_gap"):
			(before as Control).custom_minimum_size.y = gap
			continue
		var spacer := Control.new()
		spacer.set_meta("button_gap", true)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.custom_minimum_size = Vector2(0, gap)
		card_body.add_child(spacer)
		card_body.move_child(spacer, i)


func _holds_button(node: Node) -> bool:
	if node is Button:
		return (node as Button).visible
	if node is BoxContainer and (node as Control).visible and node.get_child_count() > 0:
		return node.get_child(0) is Button
	return false


func _card_top_limit() -> float:
	var top_limit := 64.0
	if hud != null and hud.size.y > 8.0:
		top_limit = hud.size.y + 8.0
		if card_roomy and ticker != null and ticker.visible:
			top_limit -= 28.0
	return top_limit


func _shrink_card() -> void:
	card_fit_queued = false
	if card == null or card_body == null or not dim.visible:
		return
	var max_w := card.offset_right - card.offset_left
	var top_limit := _card_top_limit()
	var bottom_limit := 12.0
	var max_h := size.y - top_limit - bottom_limit
	if card_fit_tries == 0 and card_body.get_theme_constant("separation") > 2:
		_space_buttons(BUTTON_GAP)
	var content_h := card_body.size.y
	card_fit_tries += 1
	if card_fit_tries > 30:
		return
	var h := content_h + 52.0
	if content_h < 40.0 or h < 96.0:
		_queue_shrink()
		return
	if h > max_h and card_body.get_child_count() > 0:
		var top_child := card_body.get_child(0)
		if top_child is TextureRect and top_child.has_meta("banner") and top_child.visible:
			## The banner gives up only the height the card lacks, down to a strip; below that it goes.
			var shorter: float = top_child.custom_minimum_size.y - (h - max_h)
			if shorter >= BANNER_MIN_H:
				top_child.custom_minimum_size.y = roundf(shorter)
			else:
				top_child.visible = false
			_queue_shrink()
			return
		if card_body.get_theme_constant("separation") > 2:
			card_body.add_theme_constant_override("separation", 2)
			_space_buttons(0.0)
			_queue_shrink()
			return
	h = clampf(h, 96.0, max_h)
	var top := clampf((size.y - h) / 2.0, top_limit, top_limit + maxf(0.0, max_h - h))
	card.offset_top = top
	card.offset_bottom = top + h
	card.offset_right = card.offset_left + max_w
	if absf(content_h - card_fit_last) > 0.5:
		card_fit_last = content_h
		_queue_shrink()


func _refresh() -> void:
	if game == null:
		return
	var notes: PackedStringArray = []
	_sync_rail_noise()
	while not game.notices.is_empty():
		notes.append(str(game.notices.pop_front()))
	if not notes.is_empty():
		_toast_chain(notes)
	_show_perk_floats()
	_watch_work()
	var season := ""
	if not game.active_season.is_empty():
		season = " · %s" % Copy.season(str(game.active_season.id))
	week_label.text = Copy.t("Week %d%s") % [game.week, season]
	_sync_people_pill()
	var roll := stock_week > 0 and game.week != stock_week and not game.last_net.is_empty()
	_paint_stocks(roll)
	_paint_blueprints()
	var floated := game.take_salvage_float()
	if str(floated.get("id", "")) != "":
		_yard_float(Copy.fill("salvage.fitted", {"name": Copy.t("salvage.node." + str(floated.id))}), str(floated.get("uid", "")))
	stock_week = game.week
	_sync_resource_names()
	_sync_numbers()
	var hold_deltas := Time.get_ticks_msec() < delta_hold_until
	for key in STOCK_KEYS:
		var keep_delta: bool = hold_deltas and chips[key].delta.text != ""
		var delta_text := ""
		var color := MUTED
		var d := 0
		var have_delta := false
		if week_fc.has(key):
			d = int(week_fc[key].net)
			have_delta = true
		elif not game.last_net.is_empty():
			d = int(game.last_net.get(key, 0))
			have_delta = true
		if have_delta and d != 0:
			delta_text = "+%d" % d if d > 0 else str(d)
		if d > 0:
			color = DELTA_UP
		elif d < 0:
			color = DELTA_DOWN
		if not keep_delta:
			chips[key].delta.text = delta_text
			chips[key].delta.tooltip_text = Copy.t("This week, after upkeep") if delta_text != "" else ""
			chips[key].delta.add_theme_color_override("font_color", color)
		var alarm := ""
		if week_fc.has(key):
			var row: Dictionary = week_fc[key]
			chips[key].box.tooltip_text = _stock_tip(str(key))
			alarm = stock_alarm(int(row.after), int(row.net), int(row.short))
		else:
			var outlook: Dictionary = game.resource_outlook(str(key))
			chips[key].box.tooltip_text = "%s. %s" % [Copy.res(str(key)), str(outlook.text)]
			var have := int(game.stock.get(key, 0))
			alarm = stock_alarm(int(outlook.next), int(outlook.next) - have, maxi(0, -int(outlook.next)))
		chips[key].alarm = alarm
		var value_color := INK
		if alarm == "red":
			value_color = STOCK_RED
		elif alarm == "amber":
			value_color = STOCK_AMBER
		chips[key].value.add_theme_color_override("font_color", value_color)
	power_loss = {}
	for uid in game.rooms_losing_power():
		power_loss[str(uid)] = true
	hope_label.text = Copy.t("Hope %d  %s") % [game.hope, _mood_delta(game.last_hope_delta)]
	dis_label.text = Copy.t("Discontent %d  %s") % [game.discontent, _mood_delta(game.last_dis_delta)]
	hope_fill.anchor_right = clampf(float(game.hope) / 100.0, 0.0, 1.0)
	dis_fill.anchor_right = clampf(float(game.discontent) / 100.0, 0.0, 1.0)
	if hope_dial != null:
		hope_dial.value = float(game.hope)
		hope_dial.queue_redraw()
	if dis_dial != null:
		dis_dial.value = float(game.discontent)
		dis_dial.queue_redraw()
	for key in LIFE_KEYS:
		var bar = chips.get(key, {}).get("left", null)
		if bar == null:
			continue
		var weeks: int = game._weeks_until_empty(str(key))
		(bar as ColorRect).anchor_right = clampf(float(weeks) / 6.0, 0.0, 1.0)
		(bar as ColorRect).color = STOCK_RED if weeks <= 1 else (STOCK_AMBER if weeks <= 3 else Color("7dba6a"))
	hope_label.get_parent().tooltip_text = _meter_rule("hope")
	dis_label.get_parent().tooltip_text = _meter_rule("discontent")
	_sync_address()
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
	var hold := false
	if not warning.is_empty():
		line = str(warning.text)
	elif game.residents.size() > game.housing():
		line = game.crowd_line()
		hold = true
	elif not outlook_rows.is_empty():
		line = str(outlook_rows[0].text)
	ticker_label.text = line
	ticker_label.tooltip_text = game.crowd_tip() if line == game.crowd_line() else ""
	_pulse_discontent(not warning.is_empty() and int(warning.get("weeks", 99)) <= URGENT_WEEKS)
	ticker.visible = line != "" and (hold or not ticker_dismissed)
	_place_chrome()
	turn_clear = game.over == "" and game.pending.is_empty() and game.forecasts().is_empty() and game.revolt_warning().is_empty()
	_fill_people()
	yard.queue_redraw()
	_sync_homecoming()
	if not _sticky_note(footer.text):
		footer.text = ""
		footer.visible = false
	if pending_button != null:
		pending_button.visible = game.over == "" and not game.white_pending.is_empty()
	_sync_waiting()
	_offer_pending()
	_sync_away_badge()
	_sync_sick_badge()


func _fill_people() -> void:
	if people_box == null or game == null:
		return
	_wipe(people_box)
	_party_block()
	var total := game.residents.size()
	var working := 0
	var grouped := {"free": [], "crew": [], "guard": [], "sick": []}
	var sick_n := 0
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
		elif post == "guard":
			working += 1
			grouped["guard"].append(person)
		elif post == "sick":
			sick_n += 1
			grouped["sick"].append(person)
		else:
			grouped["free"].append(person)
	var free_n := total - working - sick_n
	if people_head != null:
		people_head.text = _people_counts(total, working, free_n, sick_n)
		people_head.tooltip_text = game.crowd_tip()
	if people_tab != null:
		people_tab.tooltip_text = game.crowd_tip()
	if people_rail != null:
		people_rail.caption = _people_tab_caption(free_n)
		people_rail.badge = free_n
		people_rail.ink = Color("e2a63a") if free_n > 0 else MUTED
		people_rail.queue_redraw()
	if people_filter != "":
		var clear := _button("All", _clear_people_filter)
		clear.custom_minimum_size.y = 36
		people_box.add_child(clear)
	else:
		var toggle := HBoxContainer.new()
		toggle.add_theme_constant_override("separation", 6)
		var only := _pick_button("Only free", Settings.people_free_only, _set_people_free_only.bind(true), 0.0)
		only.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		only.custom_minimum_size.y = 36
		only.add_theme_font_size_override("font_size", 16)
		toggle.add_child(only)
		var every := _pick_button("All", not Settings.people_free_only, _set_people_free_only.bind(false), 0.0)
		every.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		every.custom_minimum_size.y = 36
		every.add_theme_font_size_override("font_size", 16)
		toggle.add_child(every)
		people_box.add_child(toggle)
	if Lore.total() > 0:
		var lore_row := HBoxContainer.new()
		lore_row.add_theme_constant_override("separation", 8)
		var lore_lab := _label(Copy.t("Backstories %d/%d") % [Lore.read_total(), Lore.total()], 14)
		lore_lab.add_theme_color_override("font_color", MUTED)
		lore_row.add_child(lore_lab)
		lore_row.add_child(_progress_bar(float(Lore.read_total()) / float(Lore.total()), 90.0))
		people_box.add_child(lore_row)
	var heard := _stories_heard()
	if heard.y > 0:
		var heard_row := HBoxContainer.new()
		heard_row.add_theme_constant_override("separation", 8)
		var heard_lab := _label(Copy.t("Stories heard %d/%d") % [heard.x, heard.y], 14)
		heard_lab.add_theme_color_override("font_color", MUTED)
		heard_row.add_child(heard_lab)
		heard_row.add_child(_progress_bar(float(heard.x) / float(heard.y), 90.0))
		if heard.x < heard.y:
			var dot := _label("•", 14, true)
			dot.add_theme_color_override("font_color", Color("e2a63a"))
			heard_row.add_child(dot)
		people_box.add_child(heard_row)
	if bool(game.flags.get("medkits", false)) and game.medkit_targets() > 0:
		var kits := _button("Use medkits", _use_medkits)
		kits.custom_minimum_size.y = 36
		people_box.add_child(kits)
	var view := people_filter
	if view == "" and Settings.people_free_only:
		view = "free"
	if view == "" or view == "free":
		_people_group(Copy.t("Free"), grouped["free"], "", true, "")
		if not grouped["sick"].is_empty():
			_people_group(Copy.t("Cannot work"), grouped["sick"], "", true, "")
	if view != "free":
		for uid in room_order:
			if people_filter != "" and people_filter != uid:
				continue
			var room = game._room(uid)
			if room == null:
				continue
			var room_name := room_title(room)
			var skill := str(game.catalog.rooms[room.type].get("skill", ""))
			_people_group(room_name, grouped[uid], skill, false, str(uid))
		if (people_filter == "" or people_filter == "crew") and not grouped["crew"].is_empty():
			_people_group(Copy.t("Crew"), grouped["crew"], "labor", false)
		if (people_filter == "" or people_filter == "guard") and not grouped["guard"].is_empty():
			_people_group(Copy.t("Guard"), grouped["guard"], "fight", false)
	if showing_network and network_view != null:
		network_view.refresh()


## Small events during the week (game.event_is_big): dawn opens with the big decisions only. After that, each time
## the player gets something done (assigns, builds, digs, staffs, sends an order) or opens the map, one small event
## waiting in the queue comes up a moment later. End turn shows whatever is left before the week can end.
## event_mode: "dawn" shows big events only, "one" shows the front small event and closes, "all" shows the rest.
var event_mode := "dawn"
var _work_seen := -1
var _release_due := false
var _snoozed := {}
const RELEASE_DELAY := 0.8


func _watch_work() -> void:
	var done := int(game.decisions)
	if _work_seen < 0 or done < _work_seen:
		_work_seen = done
		return
	if done == _work_seen:
		return
	_work_seen = done
	if not modal_open and deck.is_empty():
		_queue_release()


func _queue_release() -> void:
	if _release_due or shot_mode or game == null or game.small_pending() == 0:
		return
	_release_due = true
	get_tree().create_timer(RELEASE_DELAY).timeout.connect(_release_small)


func _release_small() -> void:
	_release_due = false
	if game == null or game.over != "" or at_menu or shot_mode or modal_open or not deck.is_empty():
		return
	game.big_first()
	if game.pending.is_empty() or game.event_is_big(game.front_event()):
		return
	## A small event put off with "Not now" sleeps until End turn; the next one waiting comes up instead.
	var pick := -1
	for i in game.pending.size():
		if not _snoozed.has("%d:%s" % [game.week, str(game.pending[i].get("id", ""))]):
			pick = i
			break
	if pick < 0:
		return
	if pick > 0:
		var ev: Dictionary = game.pending[pick]
		game.pending.remove_at(pick)
		game.pending.push_front(ev)
	event_mode = "one"
	_show_dawn()


func _toggle_network() -> void:
	showing_network = not showing_network
	if showing_network:
		_queue_release()
	if network_view != null:
		network_view.visible = showing_network
		network_view.bind(self)
	if yard != null:
		yard.visible = not showing_network
	if net_guide and not showing_network:
		_skip_guide()
	room_hover = ""
	_sync_room_sound()
	_place_chrome()


func _skill_line(person: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in ["care", "fight", "labor", "talk", "tech"]:
		if person.skills.has(key):
			bits.append("%s %d" % [Copy.skill(str(key)), int(person.skills[key])])
	return " · ".join(bits)


func _check_line(person: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in ["grit", "wits", "voice", "senses"]:
		bits.append("%s %d" % [Copy.skill(str(key)), game.check_value(person, str(key))])
	return " · ".join(bits)


func _where(id: String) -> String:
	for room in game.rooms:
		for sid in room.staff:
			if str(sid) == id:
				return room_title(room)
	if bool(game.people[id].get("soldier", false)):
		return Copy.t("In the guard")
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
	if bool(game.people[id].get("soldier", false)):
		return "guard"
	for wid in game._locked_ids():
		if str(wid) == id:
			return "crew"
	var person: Dictionary = game.people[id]
	if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
		return "sick"
	return "free"


func _people_tab_caption(free_n: int) -> String:
	if Copy.ru():
		var word := "свободен" if _ru_singular(free_n) else "свободны"
		return "Люди %d %s" % [free_n, word]
	return "People %d free" % free_n


func _people_counts(total: int, working: int, free_n: int, sick_n: int) -> String:
	if Copy.ru():
		var work_word := "работает" if _ru_singular(working) else "работают"
		var free_word := "свободен" if _ru_singular(free_n) else "свободны"
		var line := "Люди: %d · %s %d · %s %d" % [total, work_word, working, free_word, free_n]
		if sick_n > 0:
			line += " · не могут %d" % sick_n
		return line
	var line := "People: %d · working %d · free %d" % [total, working, free_n]
	if sick_n > 0:
		line += " · cannot work %d" % sick_n
	return line


func _ru_singular(n: int) -> bool:
	var n_abs := absi(n) % 100
	if n_abs > 10 and n_abs < 20:
		return false
	return n_abs % 10 == 1


func _use_medkits() -> void:
	if game.apply({"kind": "medkits"}):
		_fill_people()
		_refresh()


func _clear_people_filter() -> void:
	people_filter = ""
	_fill_people()


func _set_people_free_only(on: bool) -> void:
	if Settings.people_free_only == on:
		return
	Settings.people_free_only = on
	if not shot_mode:
		Settings.save()
	_fill_people()


func _open_people_for(filter_id: String) -> void:
	people_filter = filter_id
	drawer_open = true
	_fill_people()
	_place_drawer()


func _people_group(title: String, members: Array, skill_name: String, highlight: bool, drop_uid: String = "-") -> void:
	if members.is_empty() and not highlight:
		return
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 3)
	if drop_uid != "-":
		_drop_target(wrap, drop_uid)
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
		var empty := _label("people.empty_free", 13)
		empty.add_theme_color_override("font_color", MUTED)
		wrap.add_child(empty)
		return
	for person in members:
		var row := _people_row(person, skill_name)
		if drop_uid != "-":
			row.can_drop = _drawer_can_drop.bind(drop_uid)
			row.on_drop = _drawer_drop.bind(drop_uid)
		wrap.add_child(row)


func _people_row(person: Dictionary, skill_name: String) -> PersonRow:
	var id := str(person.id)
	var row := PersonRow.new()
	row.person_id = id
	row.person_name = _resident_name(person)
	row.drag_card = _drag_card
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.picked.connect(_show_person)
	var line := HBoxContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_portrait_box(id, 36))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_line := HBoxContainer.new()
	name_line.add_theme_constant_override("separation", 6)
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(Copy.person(str(person.name)), 15)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_line.add_child(name_label)
	if _story_state(id) == "new":
		var dot := _label("•", 15, true)
		dot.add_theme_color_override("font_color", Color("e2a63a"))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_line.add_child(dot)
		row.tooltip_text = Copy.t("Story not heard yet")
	box.add_child(name_line)
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


## "waiting" while a dawn choice is open (End turn stays dark), "over" after the ending, else "ready" (lit).
func _end_state() -> String:
	if game == null or game.over != "":
		return "over"
	## Only a big decision holds the week; small ones come up when End turn is pressed.
	if game.pending.size() > game.small_pending():
		return "waiting"
	return "ready"


func _sync_waiting() -> void:
	_sync_shelf()
	var waiting := _end_state() == "waiting"
	end_button.disabled = game.over != "" or waiting
	end_button.add_theme_stylebox_override("normal", _brass_ready() if _end_state() == "ready" else _brass_style(false))
	end_button.add_theme_stylebox_override("hover", _brass_ready() if _end_state() == "ready" else _brass_style(false))
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


## "red" when the week falls short or the same net empties the stock within two weeks; "amber" while the
## net is below zero; "" otherwise. `after` is the stock at dawn, `net` the week's change and `short` what
## the week could not pay, all from the forecast.
static func stock_alarm(after: int, net: int, short: int) -> String:
	if short > 0 or (net < 0 and after + net <= 0):
		return "red"
	if net < 0:
		return "amber"
	return ""


func _paint_stocks(roll: bool) -> void:
	if not roll and Time.get_ticks_msec() < delta_hold_until:
		var settled := true
		for key in STOCK_KEYS:
			if not is_equal_approx(float(stock_shown.get(key, -1.0)), float(int(game.stock.get(key, 0)))):
				settled = false
		if settled:
			return
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
	if night_panel != null and night_panel.has_method("close_panel"):
		night_panel.close_panel()
	if game.raid_share_open() or game.dawn_held():
		_show_raid_share()
		return
	if not game.pending.is_empty():
		event_mode = "all"
		_show_dawn()
		return
	var before := {}
	for room in game.rooms:
		before[str(room.uid)] = true
	Sound.play("end_turn")
	game.raid_share_hold = true
	game.end_week()
	game.raid_share_hold = false
	var placed: Array = []
	if game.over == "" and yard != null:
		for room in game.rooms:
			if before.has(str(room.uid)):
				continue
			yard.flash_at(int(room.level), int(room.cell))
			Sound.play("build_done")
			placed.append(str(room.uid))
	if game.over == "":
		for uid in placed:
			_staff_new_room(uid)
	if game.over == "":
		_sync_rail_noise()
	if game.over == "" and game.raid_share_open():
		home_hold_float = true
		_refresh()
		home_hold_float = false
		_show_raid_share()
		return
	if game.over == "" and not shot_mode:
		SaveGame.write_auto(game)
	home_hold_float = true
	_refresh()
	home_hold_float = false
	if game.over == "":
		_show_dawn()
		_play_night()
	else:
		_show_ending()
	_try_home_float()


## Between weeks: the screen goes dark over the morning card, the new week is named, and dawn comes up on the
## card. Skipped with reduce motion; a click during it lets it go at once.
var night: ColorRect
var night_tween: Tween

func _play_night() -> void:
	if _motion_off():
		return
	if night == null:
		night = ColorRect.new()
		night.color = Color(0.02, 0.018, 0.015, 1.0)
		night.set_anchors_preset(Control.PRESET_FULL_RECT)
		night.mouse_filter = Control.MOUSE_FILTER_STOP
		night.z_index = 200
		var title := Label.new()
		title.name = "Title"
		title.set_anchors_preset(Control.PRESET_FULL_RECT)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 54)
		title.add_theme_color_override("font_color", Color("e8dcc4"))
		if display_font != null:
			title.add_theme_font_override("font", display_font)
		night.add_child(title)
		night.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_end_night())
		add_child(night)
	var season := ""
	if not game.active_season.is_empty():
		var name := Copy.season(str(game.active_season.id))
		season = "
" + name.substr(0, 1).to_upper() + name.substr(1)
	var label := night.get_node("Title") as Label
	label.text = (Copy.t("Week %d%s") % [game.week, ""]) + season
	label.modulate.a = 0.0
	night.visible = true
	night.modulate.a = 0.0
	if night_tween != null and night_tween.is_valid():
		night_tween.kill()
	night_tween = create_tween()
	night_tween.tween_property(night, "modulate:a", 1.0, 0.22)
	night_tween.tween_property(label, "modulate:a", 1.0, 0.3)
	night_tween.tween_interval(0.55)
	night_tween.tween_property(label, "modulate:a", 0.0, 0.2)
	night_tween.tween_property(night, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	night_tween.finished.connect(func(): night.visible = false)


func _end_night() -> void:
	if night_tween != null and night_tween.is_valid():
		night_tween.kill()
	if night != null:
		night.visible = false


func _auto_staff() -> void:
	game.apply({"kind": "staff"})
	_refresh()


func _staff_new_room(uid: String) -> Array:
	var room = game._room(uid)
	if room == null:
		return []
	var defin: Dictionary = game.catalog.rooms[str(room.type)]
	var skill := str(defin.get("skill", ""))
	var open_seats: int = int(defin.get("staff_max", 0)) - int(room.staff.size())
	var pool: Array = []
	for person in game.residents:
		var id := str(person.id)
		if _person_post(id) != "free" or int(person.sick) > 0 or int(person.absent) > 0:
			continue
		pool.append(person)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.skills.get(skill, 0)) > int(b.skills.get(skill, 0)))
	var placed: Array = []
	for person in pool:
		if placed.size() >= open_seats:
			break
		var id := str(person.id)
		if game.apply({"kind": "assign", "person": id, "room": uid}):
			placed.append(id)
	if not placed.is_empty():
		_undo_toast(Copy.t("Assigned: %d") % placed.size(), _undo_new_staff.bind(placed))
	return placed


func _undo_new_staff(ids: Array) -> void:
	for id in ids:
		if _person_post(str(id)) == "room":
			game.apply({"kind": "unassign", "person": str(id)})
	_hide_undo_toast()
	_refresh()
	_fill_people()


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
	if week_fc.has(key):
		source_body.add_child(_source_label(_stock_head(key), 18, true, inner))
		for line in _stock_lines(key, 99):
			source_body.add_child(_source_label(line, 15, false, inner))
		for note in _stock_notes(key):
			source_body.add_child(_source_label(note, 15, false, inner))
		source_body.add_child(_source_label(Copy.t(STOCK_WHAT[key]), 14, false, inner))
	else:
		source_body.add_child(_source_label(str(info.headline), 18, true, inner))
		if info.has("hardships"):
			_hardship_lines(info.hardships, inner)
		source_body.add_child(_source_label(str(info.made), 15, false, inner))
		source_body.add_child(_source_label(str(info.used), 15, false, inner))
		if key == "hope" or key == "discontent":
			source_body.add_child(_source_label(_meter_rule(key), 14, false, inner))
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


## The week's numbers for the top bar, the resource panel, room cards and yard badges.
func _sync_numbers() -> void:
	week_fc = WeekForecast.week(game)
	dark_now = WeekForecast.dark_rooms(game)
	room_out = {}
	for room in game.rooms:
		var row := {}
		for key in game.catalog.rooms[room.type].get("base", {}):
			var info: Dictionary = WeekForecast.room_yield(game, room, str(key), dark_now)
			row[str(key)] = _room_cut(str(key), int(info.amount))
		room_out[str(room.uid)] = row


## Quarantine and the curfew cut the yard's total; a room shows its own share.
func _room_cut(key: String, amount: int) -> int:
	var n := amount
	if game.quarantine and key != "tokens":
		n = int(round(float(n) * WeekForecast.QUARANTINE_CUT))
	if key == "influence" and game._law_on("curfew"):
		n = int(round(float(n) * float(game.catalog.laws.curfew.influence_mult)))
	return n


func _room_amount(uid: String, key: String) -> int:
	return int(room_out.get(uid, {}).get(key, 0))


## Each output the next upgrade raises: this week's number now and at the next tier, read like the room header,
## and the step on the base output in percent.
func upgrade_gains(uid: String) -> Array:
	var rows: Array = []
	var room = game._room(uid)
	if room == null:
		return rows
	_sync_numbers()
	var defin: Dictionary = game.catalog.rooms[room.type]
	var base: Dictionary = defin.get("base", {})
	for key in base:
		var now: Dictionary = WeekForecast.room_yield(game, room, str(key), dark_now)
		var next: Dictionary = WeekForecast.room_yield(game, room, str(key), dark_now, int(room.upgrade) + 1)
		var pct := int(round((float(next.base) - float(now.base)) / maxf(float(base[key]), 0.001) * 100.0))
		rows.append({"key": str(key), "before": _room_amount(uid, str(key)), "after": _room_cut(str(key), int(next.amount)), "pct": pct})
	return rows


## Brass plate by the room card's title: the tier and the last upgrade bought.
func _tier_chip(room) -> PanelContainer:
	var tier := int(room.upgrade)
	var steps: Array = game.catalog.rooms[room.type].get("upgrades", [])
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := StyleBoxFlat.new()
	face.bg_color = BRASS
	face.border_color = Color("5a3d12")
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 2
	face.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", face)
	var text := Copy.t("Tier %s") % roman(tier)
	if tier - 1 < steps.size():
		text = Copy.t("Tier %s: %s") % [roman(tier), _upgrade_name(str(steps[tier - 1]))]
	var lab := _label(text, 15, true)
	lab.add_theme_color_override("font_color", Color("24180e"))
	chip.add_child(lab)
	chip.set_meta("tier_chip", tier)
	return chip


func roman(n: int) -> String:
	return ROMAN[n] if n >= 0 and n < ROMAN.size() else str(n)


func _built_count(type: String) -> int:
	var n := 0
	for room in game.rooms:
		if str(room.type) == type:
			n += 1
	return n


## "Hydroponics, tier II" when another room of the type stands in the yard, so the two read apart.
func room_title(room) -> String:
	var name := Copy.t(str(game.catalog.rooms[room.type].name))
	if int(room.upgrade) <= 0 or _built_count(str(room.type)) < 2:
		return name
	return Copy.t("%s, tier %s") % [name, roman(int(room.upgrade))]


## "Mushroom beds: Food +75%, power use 2 -> 1." Built from the tier output bonus and balance.json upgrade_fx,
## so the card says exactly what the sim does.
func _upgrade_what(id: String) -> String:
	if id == "pipe_taps" or id == "dead_drop":
		return "listening.upgrade.%s" % id
	var type := ""
	for key in game.catalog.rooms:
		if game.catalog.rooms[key].get("upgrades", []).has(id):
			type = str(key)
	if type == "":
		return ""
	var parts: PackedStringArray = []
	var pct := int(round(float(game.bal.get("upgrade_output", 0.75)) * 100.0))
	for key in game.catalog.rooms[type].get("base", {}):
		parts.append(Copy.t("%s +%d%%") % [Copy.res(str(key)), pct])
	parts.append_array(upgrade_fx_words(id))
	if parts.is_empty():
		return ""
	return Copy.t("%s: %s.") % [_upgrade_name(id), ", ".join(parts)]


## What one upgrade adds beyond its output bonus, in words with the real numbers.
func upgrade_fx_words(id: String) -> PackedStringArray:
	var fx: Dictionary = game.bal.get("upgrade_fx", {}).get(id, {})
	var type := ""
	var earlier := {}
	for key in game.catalog.rooms:
		var steps: Array = game.catalog.rooms[key].get("upgrades", [])
		if steps.has(id):
			type = str(key)
			for i in steps.find(id):
				var prev: Dictionary = game.bal.get("upgrade_fx", {}).get(str(steps[i]), {})
				for k in prev:
					if prev[k] is float or prev[k] is int:
						earlier[k] = int(earlier.get(k, 0)) + int(prev[k])
	var bits: PackedStringArray = []
	if type == "":
		return bits
	var defin: Dictionary = game.catalog.rooms[type]
	if fx.has("housing"):
		bits.append("+" + Words.count(int(fx.housing), "bed"))
	if fx.has("power"):
		var was := maxi(0, int(defin.get("power", 0)) + int(earlier.get("power", 0)))
		bits.append(Copy.t("power use %d -> %d") % [was, maxi(0, was + int(fx.power))])
	if fx.has("upkeep"):
		var was := maxi(0, int(game.bal.filter_upkeep) + int(earlier.get("upkeep", 0)))
		bits.append(Copy.t("upkeep %d -> %d materials a week") % [was, maxi(0, was + int(fx.upkeep))])
	if fx.has("dig_turns"):
		bits.append(Copy.t("digging takes %s less, at least 1 week") % Words.count(-int(fx.dig_turns), "week"))
	if bool(fx.get("shrug_down", false)):
		bits.append(Copy.t("events cannot shut the workshop down"))
	if fx.has("cough_spread"):
		var was := int(round(float(game.bal.cough_spread) * 100.0))
		bits.append(Copy.t("the Cough spreads %d%% -> %d%% a week") % [was, int(round(was * float(fx.cough_spread)))])
	if fx.has("warning_weeks"):
		var was := int(game.bal.get("season_warning", 2))
		bits.append(Copy.t("flood warning %d -> %d weeks ahead") % [was, was + int(fx.warning_weeks)])
	if fx.has("hope_week"):
		bits.append(Copy.t("hope %+d a week") % int(fx.hope_week))
	if fx.has("discontent_week"):
		bits.append(Copy.t("discontent %+d a week") % int(fx.discontent_week))
	return bits


## "+4 power a week, +1 influence a week" for the gains that move.
func _gain_words(gains: Array) -> String:
	var bits: PackedStringArray = []
	for row in gains:
		var delta := int(row.after) - int(row.before)
		if delta != 0:
			bits.append(Copy.t("%s%s a week") % ["+" if delta > 0 else "-", Copy.stock(absi(delta), str(row.key))])
	return ", ".join(bits)


func _stock_head(key: String) -> String:
	var row: Dictionary = week_fc[key]
	var net := "%+d" % int(row.net)
	if bool(row.random):
		net = Copy.t("%+d (expected, ±%d)") % [int(row.net), int(row.swing)]
	var head := Copy.t("%s: %d in store. This week: +%d made, -%d used, net %s.") % [Copy.res(key), int(row.stock), int(row.made), int(row.used), net]
	if not game.last_net.is_empty():
		head += " " + Copy.t("Last week: %s.") % ("%+d" % int(game.last_net.get(key, 0)))
	return head


## Sources and sinks merged by name, biggest first.
func _stock_lines(key: String, most: int) -> PackedStringArray:
	var sums := {}
	var counts := {}
	var order: Array = []
	for row in week_fc[key].lines:
		var name := _line_name(str(row.what))
		var sign := "+" if int(row.amount) > 0 else "-"
		var id := sign + name
		if not sums.has(id):
			order.append(id)
		sums[id] = int(sums.get(id, 0)) + int(row.amount)
		counts[id] = int(counts.get(id, 0)) + 1
	order.sort_custom(func(a, b): return absi(int(sums[a])) > absi(int(sums[b])))
	var out: PackedStringArray = []
	for id in order:
		if out.size() >= most:
			break
		var name := str(id).substr(1)
		if int(counts[id]) > 1:
			name = "%s (%d)" % [name, int(counts[id])]
		out.append("%s %+d" % [name, int(sums[id])])
	return out


func _line_name(what: String) -> String:
	if LINE_NAMES.has(what):
		return Copy.t(LINE_NAMES[what])
	return Copy.t(what)


func _stock_notes(key: String) -> PackedStringArray:
	var row: Dictionary = week_fc[key]
	var notes: PackedStringArray = []
	if int(row.short) > 0:
		notes.append(Copy.t("Short by %d.") % int(row.short))
	if bool(row.get("cold", false)):
		notes.append(Copy.t("This week the rooms draw double."))
	if key == "power" and not dark_now.is_empty():
		var names: PackedStringArray = []
		for uid in dark_now:
			var room = game._room(str(uid))
			if room != null:
				names.append(Copy.t(str(game.catalog.rooms[room.type].name)))
		notes.append(Copy.t("Not enough power: %s go dark tonight.") % ", ".join(names))
	if game._season_is("cough") and not game.quarantine:
		notes.append(Copy.t("Cough season: a few workers fall sick, but they keep their posts. Output falls while they are ill."))
	return notes


func _stock_tip(key: String) -> String:
	var parts: PackedStringArray = [_stock_head(key)]
	parts.append_array(_stock_lines(key, 3))
	if _stock_lines(key, 99).size() > 3:
		parts.append(Copy.t("Click for every line."))
	parts.append_array(_stock_notes(key))
	parts.append(Copy.t(STOCK_WHAT[key]))
	return "\n".join(parts)


## The lead's lines for the meters; the numbers come from the game's rules.
func _meter_rule(key: String) -> String:
	if key == "discontent":
		return Copy.t("How angry people are. At 100 the platform turns on you and the run ends at once.")
	var leave := Game.HOPE_ZERO_LEAVE
	var weeks := Game.HOPE_ZERO_WEEKS
	if Copy.ru():
		return "Насколько станция верит, что выдержит. При 0 каждую неделю уходят %s, а %s на нуле заканчивают игру." % [_ru_people(leave), _ru_weeks(weeks)]
	var who := "one person" if leave == 1 else "%s people" % _en_number(leave)
	var span := "one week" if weeks == 1 else "%s weeks" % _en_number(weeks)
	return "How much the station believes it will last. At 0, %s leave every week, and %s at 0 end the run." % [who, span]


func _en_number(n: int) -> String:
	var words := ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
	return words[n] if n >= 0 and n < words.size() else str(n)


func _ru_people(n: int) -> String:
	var words := {1: "один человек", 2: "двое", 3: "трое", 4: "четверо", 5: "пятеро", 6: "шестеро"}
	return str(words.get(n, Words.count(n, "person", "people")))


func _ru_weeks(n: int) -> String:
	var words := {1: "одна неделя", 2: "две недели", 3: "три недели", 4: "четыре недели", 5: "пять недель"}
	return str(words.get(n, Words.count(n, "week")))


## N2: the room's own weekly output, the multipliers that made it, or why it makes nothing.
func _yield_line(uid: String, key: String) -> String:
	var room = game._room(uid)
	if room == null:
		return ""
	var info: Dictionary = WeekForecast.room_yield(game, room, key, dark_now)
	var res := Copy.res(key)
	if str(info.zero) != "":
		return Copy.t("%s: nothing this week, %s.") % [res, Copy.t(YIELD_ZERO[str(info.zero)])]
	var parts: PackedStringArray = [Copy.t("base %s") % _short_num(float(info.base))]
	for step in info.steps:
		parts.append("%s x%s" % [Copy.t(YIELD_STEP[str(step[0])]), _short_num(float(step[1]))])
	if game.quarantine and key != "tokens":
		parts.append("%s x%s" % [Copy.t(YIELD_STEP["quarantine"]), _short_num(WeekForecast.QUARANTINE_CUT)])
	return Copy.t("%s %+d a week: %s") % [res, _room_amount(uid, key), ", ".join(parts)]


func _short_num(value: float) -> String:
	var text := "%.2f" % value
	while text.contains(".") and (text.ends_with("0") or text.ends_with(".")):
		text = text.substr(0, text.length() - 1)
	return text


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


## The week's hardships under a meter's headline: "This week:" and one bullet each, or the settled line.
func _hardship_lines(rows: Array, inner: float) -> void:
	if rows.is_empty():
		source_body.add_child(_source_label(Copy.t("No hardships this week. The platform is cooling."), 15, false, inner))
		return
	var head := _source_label(Copy.t("This week:"), 13, false, inner)
	head.add_theme_color_override("font_color", PAPER_EDGE)
	source_body.add_child(head)
	for text in rows:
		source_body.add_child(_source_label("• " + str(text), 15, false, inner))


func _address_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(118, 40)
	button.focus_mode = Control.FOCUS_ALL
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_constant_override("line_spacing", -2)
	if display_font != null:
		button.add_theme_font_override("font", display_font)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("24180e"))
	button.add_theme_color_override("font_disabled_color", Color(0.14, 0.09, 0.05, 0.55))
	var faces := {"normal": _brass_style(false), "hover": _brass_style(false), "pressed": _brass_style(true), "disabled": _brass_style(false, false)}
	for state in faces:
		var face: StyleBoxFlat = faces[state]
		face.content_margin_top = 2
		face.content_margin_bottom = 2
		face.content_margin_left = 6
		face.content_margin_right = 6
		button.add_theme_stylebox_override(state, face)
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = PAPER_EDGE
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(3)
	button.add_theme_stylebox_override("focus", ring)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("ui_sound", "click")
	button.pressed.connect(_plain_press.bind(button, _ask_address))
	return button


func _sync_address() -> void:
	if address_button == null:
		return
	var cost := int(game.bal.get("address_influence", 0))
	address_button.text = "%s\n%s" % [Copy.t("Address"), Copy.stock(cost, "influence")]
	address_button.visible = game.over == ""
	var why: String = game.order_block("address")
	address_button.disabled = why != ""
	if why == "":
		address_button.tooltip_text = Copy.t("Speak to the platform. Hope %+d. Once this week.") % int(game.bal.get("address_hope", 1))
	else:
		address_button.tooltip_text = why


func _ask_address() -> void:
	if game == null or game.over != "":
		return
	var cost := int(game.bal.get("address_influence", 0))
	var why: String = game.order_block("address")
	if not _claim(ModalDeck.AMBIENT, "confirm", _ask_address):
		return
	_open_card(Copy.t("Address the platform?"))
	_body(Copy.t("At dawn a councillor speaks to the people. It takes this week's council order and %s. Hope %+d.") % [Copy.stock(cost, "influence"), int(game.bal.get("address_hope", 1))])
	if why == "":
		card_body.add_child(_button("Address", _do_address, ""))
	else:
		_blocked_pair("Address", why)
	card_body.add_child(_button("Back", _close_card))


func _do_address() -> void:
	if not game.queue_order({"kind": "order", "order": "address"}):
		Sound.play("error")
		footer.text = Copy.t("That did not happen.")
		footer.visible = true
		_close_card()
		_refresh()
		return
	Sound.play("confirm")
	_close_card()
	_refresh()
	_toast(Copy.t("At dawn a councillor will speak to the platform. Hope %+d.") % int(game.bal.get("address_hope", 1)))
	_pulse_hope()


## One soft dip of the hope gauge after an address is queued. Skipped with reduce motion.
func _pulse_hope() -> void:
	if _motion_off() or hope_dial == null:
		return
	var pulse := create_tween()
	pulse.tween_property(hope_dial, "modulate:a", 0.55, 0.225)
	pulse.tween_property(hope_dial, "modulate:a", 1.0, 0.225)


## The discontent gauge breathes between full and 0.55 alpha every 0.7 s while a revolt is close. Modulate only;
## no flash. Off with reduce motion, and killed (gauge back to full) when the warning clears.
func _pulse_discontent(on: bool) -> void:
	if dis_dial == null:
		return
	var want := on and not _motion_off() and game.over == ""
	if want:
		if dis_pulse != null and dis_pulse.is_valid():
			return
		dis_pulse = create_tween().set_loops()
		dis_pulse.tween_method(_dis_alpha, 1.0, 0.55, 0.35)
		dis_pulse.tween_method(_dis_alpha, 0.55, 1.0, 0.35)
		return
	if dis_pulse != null:
		dis_pulse.kill()
		dis_pulse = null
	_dis_alpha(1.0)


func _dis_alpha(alpha: float) -> void:
	if dis_dial != null:
		dis_dial.modulate.a = alpha
	if dis_fill != null:
		dis_fill.modulate.a = alpha


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
	if hint == "address":
		_ask_address()
		return
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
		var name := room_title(room)
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
	if str(spot.get("pile", "")) != "" or _clearing_cell(level, cell):
		_tap_clear(level, cell, spot)
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


func _clearing_cell(level: int, cell: int) -> bool:
	return not game.clear.is_empty() and int(game.clear.level) == level and int(game.clear.cell) == cell


## Soft-confirm for a pile. Same card as dig, with the injury line muted under the costs.
func _tap_clear(level: int, cell: int, spot: Dictionary) -> void:
	var kind := str(spot.get("pile", game.clear.get("kind", "")))
	if _clearing_cell(level, cell):
		var busy: PackedStringArray = [
			Copy.fill("clear.progress", {"n": str(int(game.clear.left))}),
			Copy.t("%s on the crew.") % Words.count(game.clear.workers.size(), "person", "people"),
		]
		_confirm("clear.confirm", busy, false, {"kind": "clear", "level": level, "cell": cell}, "clear.go", Copy.t("clear.busy"))
		return
	var info := game.clear_preview(level, cell)
	var lines: PackedStringArray = [
		Words.count(int(info.weeks), "week"),
		Words.count(int(info.workers), "worker"),
	]
	if int(info.materials) > 0:
		lines.append(Words.count(int(info.materials), "material"))
	var muted := PackedStringArray()
	if kind != "":
		muted.append(Copy.t("clear.title_" + kind))
	if kind == "coal":
		muted.append(Copy.t("clear.risk_coal"))
	elif int(info.risk_pct) > 0:
		muted.append(Copy.fill("clear.risk", {"pct": str(int(info.risk_pct))}))
	_confirm("clear.confirm", lines, bool(info.ok), {"kind": "clear", "level": level, "cell": cell}, "clear.go", str(info.reason), muted)


func _drop_person(person_id: String, uid: String) -> void:
	var info := game.assign_preview(person_id, uid)
	drawer_open = true
	if bool(info.get("full", false)) and _swap_partner(person_id, uid) != "":
		_swap_into(person_id, uid)
		return
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
	var assigned := _assign_toast_line(person_id, uid)
	game.apply({"kind": "assign", "person": person_id, "room": uid})
	_refresh()
	if assigned != "":
		_toast(assigned)


## Who leaves a full room when `person_id` is dropped on it. Empty when no swap makes sense.
func _swap_partner(person_id: String, uid: String) -> String:
	if _staff_room(person_id) == uid:
		return ""
	var out := _weakest_staff(uid)
	return "" if out == person_id else out


func _swap_into(person_id: String, uid: String) -> void:
	var out := _swap_partner(person_id, uid)
	if out == "":
		return
	var from := _staff_room(person_id)
	game.apply({"kind": "unassign", "person": out})
	if not game.apply({"kind": "assign", "person": person_id, "room": uid}):
		game.apply({"kind": "assign", "person": out, "room": uid})
		_refresh()
		return
	if from != "" and bool(game.assign_preview(out, from).ok):
		game.apply({"kind": "assign", "person": out, "room": from})
	if yard != null:
		yard.shake_reason = ""
		yard.flash_at(int(game._room(uid).level), int(game._room(uid).cell))
	Sound.play("confirm")
	_refresh()
	var a := _resident_name(game.people[person_id])
	var b := _resident_name(game.people[out])
	_undo_toast(Copy.t("Swapped %s and %s.") % [a, b], _undo_swap.bind(person_id, out, uid, from))


func _undo_swap(person_id: String, out: String, uid: String, from: String) -> void:
	game.apply({"kind": "unassign", "person": person_id})
	game.apply({"kind": "unassign", "person": out})
	game.apply({"kind": "assign", "person": out, "room": uid})
	if from != "":
		game.apply({"kind": "assign", "person": person_id, "room": from})
	_hide_undo_toast()
	_refresh()


## Drawer groups take drops too: a room group assigns there, the Free group takes the resident off work.
func _drawer_can_drop(_at: Vector2, data, uid: String) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("person"):
		return false
	var id := str(data.person)
	if uid == "":
		return _person_post(id) == "room"
	return _staff_room(id) != uid


func _drawer_drop(_at: Vector2, data, uid: String) -> void:
	var id := str(data.person)
	if uid == "":
		game.apply({"kind": "unassign", "person": id})
		Sound.play("click")
		_refresh()
		return
	_drop_person(id, uid)


func _drop_target(node: Control, uid: String) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.set_drag_forwarding(Callable(), _drawer_can_drop.bind(uid), _drawer_drop.bind(uid))


func _drag_card(person_id: String) -> Control:
	var person: Dictionary = game.people.get(person_id, {})
	var plate := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.95)
	style.border_color = Color("e2a63a")
	style.set_border_width_all(2)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	plate.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_portrait_box(person_id, 36))
	var was := on_paper
	on_paper = false
	var text := VBoxContainer.new()
	text.add_child(_label(_resident_name(person), 16, true))
	var tip := _label("Drop on a room", 12)
	tip.add_theme_color_override("font_color", MUTED)
	text.add_child(tip)
	on_paper = was
	row.add_child(text)
	plate.add_child(row)
	plate.position = Vector2(-24, -24)
	var holder := Control.new()
	holder.add_child(plate)
	return holder


func _show_build(level: int, cell: int) -> void:
	if not _claim(ModalDeck.AMBIENT, "build", _show_build.bind(level, cell)):
		return
	if yard != null:
		yard.place_lock = false
		yard.clear_place()
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
	]
	var join: Dictionary = game.merge_preview(type, level, cell)
	if bool(join.get("joins", false)) and str(join.get("bonus_line", "")) != "":
		lines.append(str(join.bonus_line))
	lines.append(Copy.t("Power use once it is running: %d.") % int(info.power))
	if str(info.reason) != "":
		lines.append(str(info.reason))
	if yard != null:
		yard.place_lock = true
		yard.show_place(type, level, cell)
	_confirm(Copy.t("Build %s?") % Copy.t(str(info.name)), lines, bool(info.ok), {
		"kind": "build", "type": type, "level": level, "cell": cell,
	})


func _blueprint_chip() -> Control:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 6)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := Glyph.new()
	icon.kind = "blueprint"
	icon.custom_minimum_size = Vector2(24, 24)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var value := _label("0", 21)
	value.add_theme_constant_override("outline_size", 4)
	value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if number_font != null:
		value.add_theme_font_override("font", number_font)
	var name := _label(Copy.t("salvage.blueprints"), 11)
	name.visible = false
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.tooltip_text = Copy.t("salvage.blueprints")
	chip.add_child(icon)
	chip.add_child(value)
	chip.add_child(name)
	chip.gui_input.connect(_blueprint_chip_input)
	var pill := PanelContainer.new()
	var face := StyleBoxFlat.new()
	face.bg_color = PILL
	face.set_corner_radius_all(14)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 1
	face.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", face)
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_child(chip)
	chips["blueprints"] = {"box": chip, "value": value, "delta": _label("", 11), "icon": icon, "name": name, "pill": pill}
	return pill


func _blueprint_chip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_salvage()


func _paint_blueprints() -> void:
	if game == null or not chips.has("blueprints"):
		return
	var n := int(game.stock.get("blueprints", 0))
	var row: Dictionary = chips.blueprints
	(row.value as Label).text = str(n)
	var icon: Glyph = row.icon
	var kind := "blueprint_ready" if n >= 1 else "blueprint"
	if icon.kind != kind:
		icon.kind = kind
		icon.queue_redraw()
	(row.box as Control).tooltip_text = Copy.t("salvage.blueprints")


## Empty clipboard when nothing is fitted. Locked clipboard when a fit is waiting on a blueprint.
func _salvage_panel(rows: Array) -> String:
	match game.salvage_face_of(rows):
		"empty":
			return "res://assets/ui/salvage_board_empty.webp"
		"no_blueprint":
			return "res://assets/ui/salvage_board_no_blueprint.webp"
		_:
			return "res://assets/ui/salvage_board_panel.webp"


func _show_salvage() -> void:
	if game == null:
		return
	if not _claim(ModalDeck.AMBIENT, "salvage", _show_salvage):
		return
	_open_card(Copy.t("salvage.title"))
	card_roomy = true
	_fit_card()
	var rows: Array = game.salvage_board()
	var banner := TextureRect.new()
	banner.texture = ArtPack.load_texture(_salvage_panel(rows))
	banner.set_meta("banner", true)
	banner.set_meta("salvage_face", game.salvage_face_of(rows))
	banner.custom_minimum_size = Vector2(0, 84)
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_body.add_child(banner)
	var count := HBoxContainer.new()
	count.add_theme_constant_override("separation", 6)
	var mark := Glyph.new()
	mark.kind = "blueprint_ready" if int(game.stock.get("blueprints", 0)) >= 1 else "blueprint"
	mark.custom_minimum_size = Vector2(24, 24)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.add_child(mark)
	count.add_child(_label("%s %d" % [Copy.t("salvage.blueprints"), int(game.stock.get("blueprints", 0))], 16, true))
	card_body.add_child(count)
	card_body.add_child(_strip_card(true))
	for tier in [0, 1, 2]:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		var tic := Glyph.new()
		tic.kind = "tier%d" % tier
		tic.custom_minimum_size = Vector2(22, 22)
		tic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(tic)
		head.add_child(_label(Copy.t("salvage.tier%d" % tier), 16, true))
		card_body.add_child(head)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for row in rows:
			if int(row.tier) != tier:
				continue
			flow.add_child(_salvage_node(row))
		card_body.add_child(flow)
	_fit_card()


func _salvage_node(row: Dictionary) -> Control:
	var fitted: bool = bool(row.fitted)
	var uid := str(row.get("uid", ""))
	var gate := str(row.get("gate", ""))
	var can := uid != "" and gate == "" and not fitted
	var panel := _option_card(can, _fit_from_board.bind(uid) if can else Callable())
	panel.custom_minimum_size = Vector2(210, 78)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_constant_override("separation", 6)
	var name := _label(Copy.t(str(row.name_key)), 15, true)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name)
	if fitted:
		title.add_child(_mini_glyph("fitted", 18))
	elif gate == "blueprint":
		title.add_child(_mini_glyph("locked_blueprint", 18))
	box.add_child(title)
	var sub := ""
	if fitted:
		sub = ""
	elif gate == "listening":
		sub = Copy.t("salvage.need_listening")
	elif gate == "blueprint":
		sub = Copy.t("salvage.locked")
	elif str(row.get("reason", "")) != "":
		sub = str(row.reason)
	if sub != "":
		var why := _label(sub, 13)
		why.mouse_filter = Control.MOUSE_FILTER_IGNORE
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.add_theme_color_override("font_color", DELTA_DOWN if gate != "" else PAPER_MUTED)
		box.add_child(why)
	if not fitted and int(row.get("materials", 0)) > 0:
		var cost := HBoxContainer.new()
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost.add_theme_constant_override("separation", 4)
		cost.add_child(_mini_glyph("materials", 14))
		cost.add_child(_label(str(int(row.materials)), 13))
		if int(row.get("blueprints", 0)) > 0:
			cost.add_child(_mini_glyph("blueprint", 14))
			cost.add_child(_label(str(int(row.blueprints)), 13))
		box.add_child(cost)
	panel.add_child(box)
	return panel


func _fit_from_board(uid: String) -> void:
	var room = game._room(uid)
	var info := game.upgrade_preview(uid)
	var gains := upgrade_gains(uid)
	if room == null or not game.apply({"kind": "upgrade", "room": uid}):
		_show_salvage()
		return
	Sound.play("upgrade")
	if yard != null:
		yard.flash[uid] = Time.get_ticks_msec() + UPGRADE_FLASH_MS
	_refresh()
	var line := upgrade_toast(str(room.type), str(info.name), gains)
	line += "\n" + _salvage_staff_line("fit")
	_toast(line, 3.2)
	_show_salvage()


func _strip_card(on_board: bool) -> Control:
	var info := game.strip_preview()
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon := Glyph.new()
	icon.kind = "strip_scrap"
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var button := _button("salvage.strip", _do_strip.bind(on_board))
	button.text = Copy.t("salvage.strip")
	button.disabled = not bool(info.ok)
	button.tooltip_text = Copy.t("salvage.strip_tip")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	panel.add_child(row)
	var tip := _label(Copy.t("salvage.strip_tip"), 13)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", PAPER_MUTED if on_paper else MUTED)
	if str(info.reason) != "" and not bool(info.ok):
		tip.text = str(info.reason)
	panel.add_child(tip)
	return panel


func _do_strip(on_board: bool) -> void:
	var room_uid := ""
	for room in game.rooms:
		if str(room.type) == "workshop":
			room_uid = str(room.uid)
			break
	if not game.apply({"kind": "strip"}):
		if on_board:
			_show_salvage()
		elif room_uid != "":
			_show_room(room_uid)
		return
	Sound.play("click")
	_refresh()
	_append_salvage_staff("strip")
	if on_board:
		_show_salvage()
	elif room_uid != "":
		_show_room(room_uid)


func _append_salvage_staff(kind: String) -> void:
	var line := _salvage_staff_line(kind)
	if line == "":
		return
	if toast_label == null or not toast_label.visible:
		_toast(line, 2.6)
		return
	toast_label.text = toast_label.text + "\n" + line


func _salvage_staff_line(kind: String) -> String:
	var named := _salvage_who_line(kind)
	if named != "":
		return named
	var keys: PackedStringArray = []
	if kind == "strip":
		keys = PackedStringArray([
			"staff.salvage.assign_1", "staff.salvage.assign_2", "staff.salvage.assign_3", "staff.salvage.assign_4",
			"staff.salvage.strip_1", "staff.salvage.strip_2", "staff.salvage.strip_3",
		])
	else:
		keys = PackedStringArray(["staff.salvage.fit_1", "staff.salvage.fit_2", "staff.salvage.fit_3"])
	if keys.is_empty():
		return ""
	return Copy.t(keys[int(Time.get_ticks_msec()) % keys.size()])


func _salvage_who_line(kind: String) -> String:
	var want := ["Pete", "Benny"] if kind == "strip" else ["June"]
	for room in game.rooms:
		if kind == "strip" and str(room.type) != "workshop":
			continue
		for id in room.get("staff", []):
			var full := str(game.people.get(str(id), {}).get("name", ""))
			var first := full.split(" ")[0] if full != "" else ""
			if not want.has(first):
				continue
			var key := "staff.salvage.who." + first
			var line := Copy.t(key)
			if line != key:
				return line
	return ""


func _yard_float(text: String, uid: String) -> void:
	if salvage_float != null and is_instance_valid(salvage_float):
		salvage_float.queue_free()
	var row := HBoxContainer.new()
	row.z_index = 40
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var burst := TextureRect.new()
	burst.texture = ArtPack.load_texture("res://assets/overlays/fitted_flash.webp")
	burst.custom_minimum_size = Vector2(64, 64)
	burst.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	burst.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(burst)
	var lab := _label(text, 22, true)
	lab.add_theme_color_override("font_color", Color("e9d6a6"))
	lab.add_theme_constant_override("outline_size", 6)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lab)
	add_child(row)
	salvage_float = row
	row.reset_size()
	var w := row.get_combined_minimum_size().x
	row.position = Vector2((size.x - w) * 0.5, size.y * 0.42)
	if yard != null and uid != "":
		yard.fitted_flash[uid] = Time.get_ticks_msec() + UPGRADE_FLASH_MS
		yard.flash[uid] = Time.get_ticks_msec() + UPGRADE_FLASH_MS
	var tw := create_tween()
	tw.tween_property(row, "position:y", row.position.y - 42.0, 1.5)
	tw.parallel().tween_property(row, "modulate:a", 0.0, 0.7).set_delay(0.9)
	tw.finished.connect(func() -> void:
		if is_instance_valid(row):
			row.queue_free()
		if salvage_float == row:
			salvage_float = null
	)


func _show_room(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	if detail.is_empty():
		return
	if not _claim(ModalDeck.AMBIENT, "room", _show_room.bind(uid)):
		return
	var room = game._room(uid)
	var blocked := int(detail.get("block_width", 1)) >= 2
	var title := room_title(room)
	if blocked:
		title = Copy.t("merge.sign") % [Copy.t(str(game.catalog.rooms[room.type].name)), int(detail.block_width)]
	_open_card(title)
	room_open = str(detail.type)
	_sync_room_sound()
	var title_row := card_body.get_child(0) as HBoxContainer
	if title_row != null:
		title_row.add_theme_constant_override("separation", 12)
		var icon := _room_icon(str(detail.type), 48)
		title_row.add_child(icon)
		title_row.move_child(icon, 0)
		if int(room.upgrade) > 0:
			var chip := _tier_chip(room)
			title_row.add_child(chip)
			title_row.move_child(chip, 2)
		if room_what(str(detail.type)) != "":
			var line := _help_line(str(detail.type), help_unfold)
			var badge := _help_badge(str(detail.type), line)
			title_row.add_child(badge)
			title_row.move_child(badge, 2)
			card_body.add_child(line)
	help_unfold = false
	if blocked:
		var cells: Array = detail.get("cells", [])
		if cells.size() >= 2:
			var sub := _label(Copy.t("merge.cells") % [int(detail.level) + 1, int(cells[0]) + 1, int(cells[cells.size() - 1]) + 1], 14)
			sub.add_theme_color_override("font_color", PAPER_MUTED)
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_body.add_child(sub)
	_room_header(detail)
	if str(detail.type) == "listening_post":
		_listening_card(uid)
	elif str(detail.type) == "radio" and game.listening_active():
		_body("listening.radio_helper")
	if blocked:
		var warn := _label(str(detail.get("disaster_note", "")), 17)
		warn.add_theme_color_override("font_color", Color("8a2f22"))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(warn)
		var shares := _label(Copy.t("merge.shares"), 16)
		shares.add_theme_color_override("font_color", PAPER_MUTED)
		shares.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shares.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(shares)
	_apply_block_glow(detail)
	if notice != "":
		_body(notice)
		notice = ""
	if int(detail.staff_max) > 0:
		_seat_row(uid, detail)
	if str(detail.skill) != "":
		_body(Copy.t("Crew skill bonus: %s") % _mult(float(detail.multiplier)))
	var up: Dictionary = game.upgrade_preview(uid)
	if str(up.get("name", "")) != "" or str(up.get("reason", "")) != "":
		card_body.add_child(_upgrade_card(uid, false))
	if str(detail.type) == "workshop":
		_breach_craft_card()
		card_body.add_child(_strip_card(false))
	_body(Brief.demolish_line(game, uid))
	card_body.add_child(_button("Demolish", _confirm_demolish.bind(uid)))
	if str(detail.type) == "meeting_hall":
		card_body.add_child(_button("Laws", _show_laws))
	_room_push(uid)
	_room_switch(uid)


func _listening_card(uid: String) -> void:
	_body(game.listening_card_key())
	var idle := game.listening_idle_line()
	if idle != "":
		_body_ready(idle)
	for sid in game.listening_probe_targets():
		var place := game.station_text(str(sid), "community")
		var probe := _button("listening.probe", _queue_listening.bind(uid, "probe", str(sid), ""))
		probe.text = "%s · %s · %d%%" % [Copy.t("listening.probe"), place, game.listening_blown_pct("probe")]
		var why := game.order_block("probe", str(sid))
		probe.disabled = why != ""
		probe.tooltip_text = why if why != "" else Copy.t("listening.probe_tip")
		card_body.add_child(probe)
	for fid in game.listening_tap_targets():
		var tap := _button("listening.tap", _queue_listening.bind(uid, "tap", "", str(fid)))
		tap.text = "%s · %s · %d%%" % [Copy.t("listening.tap"), Copy.t(game._fname(str(fid))), game.listening_blown_pct("tap")]
		var why := game.order_block("tap", str(fid))
		tap.disabled = why != ""
		tap.tooltip_text = why if why != "" else Copy.t("listening.tap_tip")
		card_body.add_child(tap)


func _queue_listening(uid: String, kind: String, sid: String, fid: String) -> void:
	var action := {"order": kind}
	if kind == "probe":
		action["station"] = sid
	else:
		action["faction"] = fid
	if game.queue_order(action):
		_show_room(uid)


func _room_icon(type: String, px: int) -> Glyph:
	var icon := Glyph.new()
	icon.kind = type
	icon.ink = PAPER_INK
	icon.custom_minimum_size = Vector2(px, px)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _apply_block_glow(detail: Dictionary) -> void:
	if yard == null:
		return
	if int(detail.get("block_width", 1)) < 2:
		if yard.block_glow:
			_clear_block_glow()
		return
	var glow := {}
	for uid in game.merge_group_of(str(detail.uid)):
		glow[str(uid)] = true
	yard.glow = glow
	yard.block_glow = true
	yard.queue_redraw()


func _clear_block_glow() -> void:
	if yard == null or not yard.block_glow:
		return
	yard.block_glow = false
	yard.glow = {}
	if source_pinned and source_key != "" and game != null:
		var info: Dictionary = Brief.source(game, source_key)
		for uid in info.get("rooms", []):
			yard.glow[str(uid)] = true
	yard.queue_redraw()


func _room_header(detail: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var blocked := int(detail.get("block_width", 1)) >= 2
	var outputs: Array = detail.outputs
	var block_outputs: Array = detail.get("block_outputs", [])
	if blocked and not block_outputs.is_empty():
		for out in block_outputs:
			row.add_child(_mini_glyph(str(out.key), 20))
			var total := 0 if bool(detail.offline) else int(out.total)
			var bonus := 0 if bool(detail.offline) else int(out.bonus)
			row.add_child(_label(Copy.t("merge.output") % [Copy.res(str(out.key)), total, bonus], 18, true))
	elif outputs.is_empty():
		if blocked and str(detail.type) == "quarters":
			var beds_defin: Dictionary = game.catalog.rooms[str(detail.type)]
			var beds := int(beds_defin.get("housing", 0)) * int(detail.block_width) + int(detail.get("merge_bonus", 0))
			if bool(detail.offline):
				beds = 0
			row.add_child(_mini_glyph("people", 20))
			row.add_child(_label(Copy.t("Housing %d") % beds, 18, true))
		else:
			var defin: Dictionary = game.catalog.rooms[str(detail.type)]
			row.add_child(_makes_line(str(detail.type), defin))
	var uid := str(detail.uid)
	_sync_numbers()
	for out in outputs:
		row.add_child(_mini_glyph(str(out.key), 20))
		var lab := _label(Copy.t("%s %+d/wk") % [Copy.res(str(out.key)), _room_amount(uid, str(out.key))], 18, true)
		row.add_child(lab)
	var draw := int(detail.power)
	if blocked:
		draw = int(detail.get("block_power", draw))
	if draw > 0:
		if game._season_is("cold") or game.crunch_power:
			draw *= 2
		row.add_child(_dot())
		row.add_child(_mini_glyph("power", 20))
		var power_text := Copy.t("Power −%d/wk") % draw
		if blocked:
			power_text = Copy.t("merge.power") % draw
		if (bool(detail.offline) or dark_now.has(uid)) and not blocked:
			power_text = Copy.t("Power 0/wk")
		row.add_child(_label(power_text, 18, true))
	card_body.add_child(row)
	for out in outputs:
		var why := _label(_yield_line(uid, str(out.key)), 14)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		why.add_theme_color_override("font_color", PAPER_MUTED)
		why.set_meta("yield_line", str(out.key))
		card_body.add_child(why)
	for line in _room_status_lines(detail):
		_body_ready(line)


func _seat_row(uid: String, detail: Dictionary) -> void:
	if int(detail.get("block_width", 1)) >= 2:
		var crew := _label(Copy.t("merge.crew") % [int(detail.get("block_staff", detail.staff.size())), int(detail.get("block_staff_max", detail.staff_max))], 16)
		crew.add_theme_color_override("font_color", PAPER_MUTED)
		crew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(crew)
	var free := _free_picks(uid)
	var full: bool = detail.staff.size() >= int(detail.staff_max)
	var room = game._room(uid)
	var dark: bool = room != null and bool(room.offline)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var minus := _seat_step("−", _seat_minus.bind(uid))
	minus.disabled = detail.staff.is_empty()
	minus.tooltip_text = Copy.t("Take off the weakest worker")
	row.add_child(minus)
	var seats := HFlowContainer.new()
	seats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seats.add_theme_constant_override("h_separation", 8)
	seats.add_theme_constant_override("v_separation", 8)
	seats.alignment = FlowContainer.ALIGNMENT_CENTER
	for member in detail.staff:
		seats.add_child(_seat_filled(uid, member, str(detail.skill)))
	for i in int(detail.staff_max) - detail.staff.size():
		seats.add_child(_seat_empty(uid, not dark))
	row.add_child(seats)
	var plus := _seat_step("+", _seat_plus.bind(uid))
	var why := _seat_block(full, free.is_empty(), dark)
	plus.disabled = why != ""
	plus.tooltip_text = Copy.t(why) if why != "" else Copy.t("Assign the best free resident")
	plus.set_meta("blocked", why)
	row.add_child(plus)
	card_body.add_child(row)
	if why != "":
		var block := _label(why, 15, true)
		block.add_theme_color_override("font_color", PAPER_MUTED)
		block.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.set_meta("seat_block", why)
		card_body.add_child(block)
	var each := _per_worker_text(uid, free)
	if each != "":
		var lab := _label(each, 16)
		lab.add_theme_color_override("font_color", PAPER_MUTED)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_body.add_child(lab)
	if not full and not dark and free.is_empty():
		_body("Open a seat to take someone off other work.")


## Why the + button cannot add a worker, as the player reads it. Empty when it can.
func _seat_block(full: bool, none_free: bool, dark: bool) -> String:
	if dark:
		return "Room is off"
	if full:
		return "Room is full"
	if none_free:
		return "No free people"
	return ""


func _seat_step(text: String, cb: Callable) -> Button:
	var button := _button(text, cb)
	button.custom_minimum_size = Vector2(56, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 32)
	return button


func _seat_filled(uid: String, member: Dictionary, skill_name: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 0)
	var face := _button_face(false, false)
	face.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", face)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait := _portrait_box(str(member.id), 56)
	box.add_child(portrait)
	var who := _label(Copy.person(str(member.name)).get_slice(" ", 0), 15)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.clip_text = true
	who.tooltip_text = Copy.person(str(member.name))
	who.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(who)
	if skill_name != "":
		var skill := _label("%s %d" % [_skill_word(skill_name), int(member.skill)], 14)
		skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill.add_theme_color_override("font_color", PAPER_MUTED)
		skill.tooltip_text = _skill_tip(skill_name, str(member.name), int(member.skill))
		skill.mouse_filter = Control.MOUSE_FILTER_STOP
		box.add_child(skill)
	var off := _button("Unassign", _unassign.bind(str(member.id), uid))
	off.custom_minimum_size = Vector2(0, 28)
	off.alignment = HORIZONTAL_ALIGNMENT_CENTER
	off.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed"]:
		var small := _button_face(state == "pressed", state == "hover")
		small.content_margin_top = 2
		small.content_margin_bottom = 2
		off.add_theme_stylebox_override(state, small)
	box.add_child(off)
	panel.add_child(box)
	return panel


func _seat_empty(uid: String, open: bool) -> Control:
	var slot := SeatSlot.new()
	slot.custom_minimum_size = Vector2(120, 150)
	slot.ink = PAPER_EDGE
	slot.open = open
	var wanted := ""
	var seated = game._room(uid)
	if seated != null:
		wanted = str(game.catalog.rooms[str(seated.type)].get("skill", ""))
	if not open:
		slot.tooltip_text = Copy.t("Room is off")
	elif wanted != "":
		slot.tooltip_text = Copy.fill("assign.tip_empty", {"skill": _skill_word(wanted)})
	else:
		slot.tooltip_text = Copy.t("assign.tip_empty_any")
	if open:
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.picked.connect(_open_picker.bind(uid))
	return slot


func _open_picker(uid: String) -> void:
	picker_busy_open = false
	_show_assign(uid)


func _free_picks(uid: String) -> Array:
	var rows: Array = []
	for row in _assign_picks(uid):
		if _other_room_name(str(row.id), uid) == "":
			rows.append(row)
	rows.sort_custom(func(a, b): return int(a.skill) > int(b.skill))
	return rows


func _per_worker_text(uid: String, free: Array) -> String:
	var row: Dictionary = {}
	if not free.is_empty():
		row = free[0]
	else:
		var room = game._room(uid)
		if room != null and not room.staff.is_empty():
			var weakest := _weakest_staff(uid)
			var effect: Dictionary = Brief.marginal(game, uid, weakest)
			var delta := 0
			if str(effect.key) != "":
				var defin: Dictionary = game.catalog.rooms[room.type]
				var all_ids: Array = []
				var rest: Array = []
				for id in room.staff:
					all_ids.append(str(id))
					if str(id) != weakest:
						rest.append(str(id))
				delta = Brief._amount(game, room, defin, all_ids, str(effect.key)) - Brief._amount(game, room, defin, rest, str(effect.key))
			row = {"out_key": str(effect.key), "delta": delta, "note": str(effect.note)}
	if row.is_empty():
		return ""
	var key := str(row.get("out_key", ""))
	if key != "":
		if int(row.delta) == 0:
			return ""
		var word := Copy.res(key)
		word = word.substr(0, 1).to_lower() + word.substr(1)
		return Copy.t("Each worker: %+d %s/wk") % [int(row.delta), word]
	var note := str(row.get("note", ""))
	if note == "":
		return ""
	return Copy.t("Each worker: %s") % Copy.t(note)


func _weakest_staff(uid: String) -> String:
	var detail: Dictionary = game.room_detail(uid)
	var weakest := ""
	var low := 999
	for member in detail.staff:
		if int(member.skill) < low:
			low = int(member.skill)
			weakest = str(member.id)
	return weakest


func _seat_plus(uid: String) -> void:
	var free := _free_picks(uid)
	if free.is_empty():
		_open_picker(uid)
		return
	_assign_person(str(free[0].id), uid)


func _seat_minus(uid: String) -> void:
	var weakest := _weakest_staff(uid)
	if weakest != "":
		_unassign(weakest, uid)


## Push doubles this room for one night. The odds string is the same percent the night rolls.
func _room_push(uid: String) -> void:
	var info: Dictionary = game.push_preview(uid)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var odds := str(info.get("reason", ""))
	if bool(info.get("ok", false)):
		odds = Copy.t("push.tip_ok") % int(info.pct)
	var state := _label(odds, 16)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	var button := _button("Push", _ask_push.bind(uid))
	button.disabled = not bool(info.get("ok", false)) or game.over != ""
	button.tooltip_text = odds
	button.custom_minimum_size = Vector2(140, 48)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(button)
	card_body.add_child(row)


func _ask_push(uid: String) -> void:
	var info: Dictionary = game.push_preview(uid)
	var lines: PackedStringArray = [Copy.t("push.confirm_body") % int(info.get("pct", 0))]
	var why := str(info.get("reason", ""))
	if why != "":
		lines.append(why)
	_confirm(Copy.t("push.confirm_title"), lines, bool(info.get("ok", false)), {"kind": "push", "room": uid}, "Push", why)


func _room_switch(uid: String) -> void:
	var info: Dictionary = game.switch_preview(uid)
	if int(info.saves) <= 0:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := bool(info.on)
	var saves := int(info.saves)
	var state := _label(_switch_state(on, saves), 17)
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	var flip := _button("Switch off" if on else "Switch on", _switch_room.bind(uid, not on))
	flip.disabled = not bool(info.can)
	flip.custom_minimum_size = Vector2(170, 48)
	flip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	flip.add_theme_font_size_override("font_size", 17)
	flip.set_meta("switch_to", not on)
	row.add_child(flip)
	card_body.add_child(row)
	if str(info.reason) != "":
		_body(str(info.reason))


## SX5 status. Quarters and the platform stay quiet. Switched off wins over the offline flag it sets.
func _room_status_lines(detail: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var type := str(detail.get("type", ""))
	var room = game._room(str(detail.get("uid", "")))
	if room == null:
		return lines
	var quiet := type == "quarters" or type == "platform"
	var have := int(room.staff.size())
	var need := int(detail.get("crew_need", 0))
	if int(detail.get("block_width", 1)) > 1:
		have = int(detail.get("block_staff", have))
	var key := ""
	if bool(room.get("switched_off", false)):
		key = "station.status_switched"
	elif bool(room.get("offline", false)) or int(room.get("disabled", 0)) > 0:
		key = "station.status_offline"
	elif bool(room.get("browned", false)) or dark_now.has(str(room.uid)) or power_loss.has(str(room.uid)):
		key = "station.status_power"
	elif not quiet and need > 0 and have < need:
		key = "station.status_understaffed"
	elif not quiet:
		key = "station.status_running"
	if key != "":
		lines.append(Copy.t(key))
	if key == "station.status_understaffed":
		lines.append(Copy.fill("station.status_need", {"n": need - have}))
	if float(room.get("efficiency", 1.0)) < 0.999:
		lines.append(Copy.t("station.tip_damaged"))
	return lines


func _room_hover_tip(room: Dictionary) -> String:
	var detail: Dictionary = game.room_detail(str(room.get("uid", "")))
	if detail.is_empty():
		return ""
	var lines := _room_status_lines(detail)
	if lines.is_empty():
		return ""
	var tip := lines[0]
	if tip == Copy.t("station.status_switched"):
		tip = Copy.t("station.tip_switched")
	elif tip == Copy.t("station.status_understaffed"):
		tip = Copy.t("station.tip_understaffed")
	if lines.size() > 1 and lines[1] != Copy.t("station.tip_damaged"):
		tip = "%s · %s" % [tip, lines[1]]
	if lines[lines.size() - 1] == Copy.t("station.tip_damaged") and tip != Copy.t("station.tip_damaged"):
		tip = "%s · %s" % [tip, lines[lines.size() - 1]]
	return tip


func _skill_word(skill_name: String) -> String:
	var key := "skill.%s" % skill_name
	var word := Copy.t(key)
	if word == key:
		return Copy.skill(skill_name, false)
	return word


func _skill_tip(skill_name: String, person_name: String, value: int) -> String:
	return Copy.fill("assign.tip_skill", {"skill": _skill_word(skill_name), "name": person_name, "n": value})


func _assign_toast_line(person_id: String, uid: String) -> String:
	var person: Dictionary = game.people.get(person_id, {})
	var room = game._room(uid)
	if person.is_empty() or room == null:
		return ""
	var line := Copy.fill("assign.toast_on", {
		"name": Copy.person(str(person.get("name", ""))),
		"room": Copy.t(str(game.catalog.rooms[str(room.type)].name)),
	})
	var effect: Dictionary = Brief.marginal(game, uid, person_id)
	var key := str(effect.get("key", ""))
	var delta := int(effect.get("delta", 0))
	if key != "" and key != "hope" and delta != 0:
		var res := Copy.res(key)
		res = res.substr(0, 1).to_lower() + res.substr(1)
		line += " · %+d %s/wk" % [delta, res]
	return line


func _unassign_toast_line(person_id: String) -> String:
	var person: Dictionary = game.people.get(person_id, {})
	if person.is_empty():
		return ""
	return Copy.fill("assign.toast_off", {"name": Copy.person(str(person.get("name", "")))})


## The room's current state first; the button next to it says what pressing it does.
func _switch_state(on: bool, saves: int) -> String:
	if on:
		return Copy.t("On. It is doing its work and drawing power. Switch it off to stop both.")
	if saves == 1:
		return Copy.t("Off. It is not working, and it saves 1 power.")
	return Copy.t("Off. It is not working, and it saves %d power.") % saves


func _switch_room(uid: String, on: bool) -> void:
	var saves := int(game.switch_preview(uid).get("saves", 0))
	if game.apply({"kind": "switch", "room": uid, "on": on}):
		_refresh()
		if on:
			_toast(Copy.t("station.toast_switch_on"))
		else:
			_toast(Copy.fill("station.toast_switch_off", {"n": saves}))
	_show_room(uid)


func _show_assign(uid: String) -> void:
	var detail: Dictionary = game.room_detail(uid)
	if not _claim(ModalDeck.AMBIENT, "assign", _show_assign.bind(uid)):
		return
	_open_card(Copy.t("Assign to %s") % room_title(game._room(uid)))
	var skill_name := str(detail.skill)
	if skill_name != "":
		_body(Copy.t("Best %s first. The number is that skill.") % Copy.skill(skill_name, false))
	var free := _free_picks(uid)
	var busy: Array = []
	for row in _assign_picks(uid):
		if _other_room_name(str(row.id), uid) != "":
			busy.append(row)
	busy.sort_custom(func(a, b): return int(a.skill) > int(b.skill))
	if free.is_empty():
		var seated := 0
		var room = game._room(uid)
		if room != null:
			seated = room.staff.size()
		if int(detail.staff_max) > 0 and seated >= int(detail.staff_max):
			_body(Copy.t("This room is full (%d seats). Take someone off a seat to free one.") % int(detail.staff_max))
		else:
			_body("No free residents.")
	for row in free:
		card_body.add_child(_assign_row(uid, row))
	if not busy.is_empty():
		var arrow := "▾" if picker_busy_open else "▸"
		var fold := _button("%s %s (%d)" % [arrow, Copy.t("Busy (take off other work)"), busy.size()], _toggle_picker_busy.bind(uid))
		fold.custom_minimum_size.y = 44
		fold.add_theme_font_size_override("font_size", 17)
		card_body.add_child(fold)
		if picker_busy_open:
			for row in busy:
				card_body.add_child(_assign_row(uid, row))
	card_body.add_child(_button("Back", _show_room.bind(uid)))


func _toggle_picker_busy(uid: String) -> void:
	picker_busy_open = not picker_busy_open
	_show_assign(uid)


func _assign_person(person_id: String, uid: String) -> void:
	var info := game.assign_preview(person_id, uid)
	if not bool(info.ok):
		notice = str(info.reason)
		_show_room(uid)
		return
	var assigned := _assign_toast_line(person_id, uid)
	game.apply({"kind": "assign", "person": person_id, "room": uid})
	_refresh()
	if assigned != "":
		_toast(assigned)
	_show_room(uid)


func _unassign(person_id: String, uid: String) -> void:
	var released := _unassign_toast_line(person_id)
	game.apply({"kind": "unassign", "person": person_id})
	_refresh()
	if released != "":
		_toast(released)
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
			card_body.add_child(_button("Upgrade", _do_upgrade.bind(uid)))
		else:
			_blocked_pair("Upgrade", str(info.reason))
	card_body.add_child(_button("Back", _close_card))


## Buys the next tier, then marks it: the "upgrade" cue, a brass flash on the room and a toast with what it adds.
func _do_upgrade(uid: String) -> void:
	var room = game._room(uid)
	var info := game.upgrade_preview(uid)
	var gains := upgrade_gains(uid)
	if room == null or not game.apply({"kind": "upgrade", "room": uid}):
		_do_confirm({})
		return
	Sound.play("upgrade")
	_close_card()
	_refresh()
	_action_voice("upgrade", "")
	if yard != null:
		yard.flash[uid] = Time.get_ticks_msec() + UPGRADE_FLASH_MS
	var fitted_line := upgrade_toast(str(room.type), str(info.name), gains)
	if str(info.get("node", "")) != "":
		fitted_line += "\n" + _salvage_staff_line("fit")
	_toast(fitted_line, 3.2)


func upgrade_toast(type: String, upgrade_id: String, gains: Array) -> String:
	var bits: PackedStringArray = []
	if _gain_words(gains) != "":
		bits.append(_gain_words(gains))
	bits.append_array(upgrade_fx_words(upgrade_id))
	var words := ", ".join(bits)
	var name := _room_type_name(type)
	if words == "":
		return Copy.t("%s upgraded: %s.") % [name, _upgrade_name(upgrade_id)]
	return Copy.t("%s upgraded: %s (%s).") % [name, _upgrade_name(upgrade_id), words]


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
	_action_voice("law", law_id)


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


func _blown_toast(text: String) -> bool:
	if text == Copy.t("listening.blown_dawn"):
		return true
	var stem := Copy.t("listening.blown").split("{station}")[0]
	return stem != "" and text.begins_with(stem)


## Map tags use this paper. The order toast sits on it while the network is open so the line stays readable.
func _map_toast_face() -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = SLIP_PAPER
	face.border_color = Color(SLIP_INK, 0.85)
	face.set_border_width_all(1)
	face.set_content_margin_all(8)
	face.content_margin_left = 12
	face.content_margin_right = 12
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 3
	face.shadow_offset = Vector2(1, 2)
	return face


func _park_toast_label(parent: Node) -> void:
	if toast_label == null or parent == null or toast_label.get_parent() == parent:
		return
	if toast_label.get_parent() != null:
		toast_label.get_parent().remove_child(toast_label)
	parent.add_child(toast_label)


func _toast_chain(lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_toast(str(lines[0]))
	if lines.size() < 2 or toast_fade == null:
		return
	var rest := lines.slice(1)
	toast_fade.tween_callback(func() -> void:
		_toast_chain(rest)
	)


## Dawn rail noise sits on the yard, under the dawn card: one paper chip, and once a run a platform float.
## No shake. Reduce-motion keeps the text still and skips the fade.
func _build_rail_noise() -> void:
	rail_chip = PanelContainer.new()
	rail_chip.visible = false
	rail_chip.z_index = 18
	rail_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	rail_chip.add_theme_stylebox_override("panel", _rail_paper())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	rail_chip.add_child(row)
	rail_icon = TextureRect.new()
	rail_icon.visible = false
	rail_icon.custom_minimum_size = Vector2(24, 24)
	rail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rail_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rail_icon)
	rail_chip_label = _label("", 15, false, false)
	rail_chip_label.add_theme_color_override("font_color", PAPER_INK)
	rail_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_chip_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rail_chip_label)
	add_child(rail_chip)

	rail_float = PanelContainer.new()
	rail_float.visible = false
	rail_float.z_index = 18
	rail_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_float.add_theme_stylebox_override("panel", _rail_paper())
	rail_float_label = _label("", 18, false, false)
	rail_float_label.add_theme_color_override("font_color", PAPER_INK)
	rail_float_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rail_float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail_float_label.custom_minimum_size = Vector2(320, 0)
	rail_float_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_float_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail_float.add_child(rail_float_label)
	add_child(rail_float)


func _rail_paper() -> StyleBoxFlat:
	var style := _paper_style()
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(3)
	style.border_color = PAPER_EDGE
	return style


func _sync_rail_noise() -> void:
	if game == null or rail_chip == null or at_menu or hold_dawn or game.over != "":
		return
	var chip: Dictionary = game.present_dawn_soft_chip()
	if not bool(chip.get("fresh", false)):
		return
	if str(chip.get("kind", "")) != "rail":
		_hide_rail_noise()
		return
	_show_rail_noise(game.dawn_soft_line(chip), bool(chip.get("first", false)))


func _show_rail_noise(text: String, first: bool) -> void:
	rail_token += 1
	if rail_fade != null and rail_fade.is_valid():
		rail_fade.kill()
	rail_fading = false
	rail_hold_ms = 0
	rail_last_ms = 0
	rail_chip_label.text = text
	rail_chip.tooltip_text = Copy.t("noise.tip")
	var tex := ArtPack.icon_texture("noise_rail", 24.0)
	rail_icon.texture = tex
	rail_icon.visible = tex != null
	rail_chip.modulate.a = 1.0
	rail_chip_live = true
	rail_float_live = first
	if first:
		rail_float_label.text = Copy.t("noise.first")
		rail_float.modulate.a = 1.0
	rail_float.visible = false
	rail_chip.visible = false
	_place_rail_noise()


func _hide_rail_noise() -> void:
	rail_token += 1
	rail_chip_live = false
	rail_float_live = false
	rail_fading = false
	rail_hold_ms = 0
	rail_last_ms = 0
	if rail_fade != null and rail_fade.is_valid():
		rail_fade.kill()
	if rail_chip != null:
		rail_chip.visible = false
		rail_chip.modulate.a = 1.0
	if rail_float != null:
		rail_float.visible = false
		rail_float.modulate.a = 1.0


func _place_rail_noise() -> void:
	if rail_chip == null:
		return
	var short := size.y < 520.0
	var margin := 8.0 if short else 12.0
	var tool_h := 48.0 if short else 68.0
	rail_chip.reset_size()
	var chip_size := rail_chip.get_combined_minimum_size()
	chip_size.x = clampf(chip_size.x, 120.0, minf(460.0, size.x - margin * 2.0))
	chip_size.y = maxf(chip_size.y, 32.0)
	rail_chip.anchor_left = 0.0
	rail_chip.anchor_right = 0.0
	rail_chip.anchor_top = 1.0
	rail_chip.anchor_bottom = 1.0
	rail_chip.offset_left = margin
	rail_chip.offset_right = margin + chip_size.x
	rail_chip.offset_bottom = -(margin + tool_h + 8.0)
	rail_chip.offset_top = rail_chip.offset_bottom - chip_size.y
	if rail_float == null:
		return
	rail_float.reset_size()
	var float_size := rail_float.get_combined_minimum_size()
	var w := clampf(maxf(float_size.x, 320.0), 280.0, minf(520.0, size.x - 48.0))
	var h := maxf(float_size.y, 44.0)
	rail_float.anchor_left = 0.5
	rail_float.anchor_right = 0.5
	rail_float.anchor_top = 0.5
	rail_float.anchor_bottom = 0.5
	rail_float.offset_left = -w * 0.5
	rail_float.offset_right = w * 0.5
	var y := size.y * 0.12
	rail_float.offset_top = y
	rail_float.offset_bottom = y + h


## The hold runs only while the yard is uncovered. The dawn card and the map pause it.
## Reduce-motion hides the text in place. Otherwise the paper fades. Nothing shakes.
func _tick_rail_noise() -> void:
	if not rail_chip_live and not rail_float_live:
		return
	var now := Time.get_ticks_msec()
	var covered := (dim != null and dim.visible) or showing_network or (hub_layer != null and hub_layer.visible)
	if covered:
		rail_chip.visible = false
		rail_float.visible = false
		rail_last_ms = now
		return
	rail_chip.visible = rail_chip_live
	rail_float.visible = rail_float_live
	if rail_fading:
		rail_last_ms = now
		return
	if rail_last_ms == 0:
		rail_last_ms = now
	rail_hold_ms += now - rail_last_ms
	rail_last_ms = now
	if rail_hold_ms < 6500:
		return
	_fade_rail_noise()


func _fade_rail_noise() -> void:
	if rail_fading:
		return
	rail_fading = true
	rail_token += 1
	var token := rail_token
	if _motion_off():
		_finish_rail_noise(token)
		return
	if rail_fade != null and rail_fade.is_valid():
		rail_fade.kill()
	rail_fade = create_tween()
	var started := false
	if rail_chip_live and rail_chip != null:
		rail_fade.tween_property(rail_chip, "modulate:a", 0.0, 0.4)
		started = true
	if rail_float_live and rail_float != null:
		if started:
			rail_fade.parallel().tween_property(rail_float, "modulate:a", 0.0, 0.4)
		else:
			rail_fade.tween_property(rail_float, "modulate:a", 0.0, 0.4)
	rail_fade.tween_callback(_finish_rail_noise.bind(token))


func _finish_rail_noise(token: int) -> void:
	if token != rail_token:
		return
	_hide_rail_noise()

## Cream paper strip, same family as the rumor / border / rail dawn chips. No sticky "Homecoming" label.
func _build_dawn_chip() -> void:
	dawn_chip = PanelContainer.new()
	dawn_chip.visible = false
	dawn_chip.z_index = 6
	dawn_chip.mouse_filter = Control.MOUSE_FILTER_STOP
	var face := StyleBoxFlat.new()
	face.bg_color = Color("efe4c8")
	face.border_color = Color("b89a6a")
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.content_margin_left = 10
	face.content_margin_right = 12
	face.content_margin_top = 4
	face.content_margin_bottom = 4
	dawn_chip.add_theme_stylebox_override("panel", face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dawn_chip.add_child(row)
	dawn_chip_icon = TextureRect.new()
	dawn_chip_icon.custom_minimum_size = Vector2(18, 18)
	dawn_chip_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dawn_chip_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dawn_chip_icon.visible = false
	dawn_chip_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dawn_chip_icon)
	dawn_chip_label = _label("", 15, true, false)
	dawn_chip_label.add_theme_color_override("font_color", Color("24180e"))
	dawn_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dawn_chip_label)
	add_child(dawn_chip)


func _sync_homecoming() -> void:
	if game == null or dawn_chip == null:
		return
	var line := game.home_chip_line(_motion_off())
	var show := line != "" and not showing_network
	dawn_chip.visible = show
	if show:
		dawn_chip_label.text = line
		dawn_chip.tooltip_text = Copy.t("home.tip")
		var icon := ArtPack.icon_texture("home_boots", 24.0)
		dawn_chip_icon.visible = icon != null
		if icon != null:
			dawn_chip_icon.texture = icon
	elif home_float != null and int(game.flags.get("home_shown", -1)) != game.week:
		home_float.visible = false
	_try_home_float()
	var bar_h := 72.0
	if hud != null:
		bar_h = hud.offset_bottom
	_place_dawn_chip(bar_h)


func _place_dawn_chip(hud_h: float) -> void:
	if dawn_chip == null or not dawn_chip.visible:
		return
	var w := minf(560.0, maxf(240.0, dawn_chip.get_combined_minimum_size().x))
	dawn_chip.anchor_left = 0.0
	dawn_chip.anchor_right = 0.0
	dawn_chip.anchor_top = 0.0
	dawn_chip.anchor_bottom = 0.0
	dawn_chip.offset_left = maxf(8.0, (size.x - w) * 0.5)
	dawn_chip.offset_right = dawn_chip.offset_left + w
	dawn_chip.offset_top = hud_h + 8.0
	dawn_chip.offset_bottom = hud_h + 40.0


func _try_home_float() -> void:
	if home_hold_float or game == null or showing_network:
		return
	if not bool(game.flags.get("home_float", false)):
		return
	if dim != null and dim.visible:
		return
	_show_home_float()


## Soft yard line over the platform. Text only when reduce-motion is on. No shake, no modal, no camera pan.
func _show_home_float() -> void:
	if game == null:
		return
	if home_float == null:
		home_float = _label("", 18, true, false)
		home_float.z_index = 8
		home_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
		home_float.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		home_float.add_theme_constant_override("outline_size", 6)
		home_float.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		add_child(home_float)
	home_float.text = Copy.t("home.first")
	home_float.modulate.a = 1.0
	home_float.visible = true
	game.flags["home_float"] = false
	if home_float_tween != null and home_float_tween.is_valid():
		home_float_tween.kill()
	_place_home_float()
	home_float_tween = create_tween()
	var fade := home_float_tween
	if _motion_off():
		fade.tween_interval(4.2)
	else:
		var rise := home_float.position.y - 22.0
		fade.tween_property(home_float, "position:y", rise, 2.6)
		fade.parallel().tween_property(home_float, "modulate:a", 0.0, 2.6).set_delay(1.1)
	fade.tween_callback(func() -> void:
		if home_float != null:
			home_float.visible = false)


func _place_home_float() -> void:
	if home_float == null or not home_float.visible or game == null:
		return
	if home_float_tween != null and home_float_tween.is_valid() and home_float_tween.is_running():
		return
	var at := Vector2(size.x * 0.5, size.y * 0.42)
	if yard != null:
		var level := 1
		var cell := 0
		for room in game.rooms:
			if str(room.type) == "platform":
				level = int(room.level)
				cell = int(room.cell)
				break
		var rect := yard.cell_screen(level, cell)
		if rect.size.x > 2.0:
			at = Vector2(rect.get_center().x, rect.position.y + 6.0)
	home_float.custom_minimum_size = Vector2(360, 28)
	home_float.position = Vector2(at.x - 180.0, at.y)
	home_float.size = Vector2(360, 28)


func _toast(text: String, hold: float = 1.8) -> void:
	if toast_label == null:
		toast_label = _label("", 16, true)
		toast_label.z_index = 30
		toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(toast_label)
	var blown := _blown_toast(text)
	if blown:
		_arm_blown_flash()
	elif blown_flash != null:
		blown_flash.visible = false
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	var icon_w := 36.0 if blown else 0.0
	var toast_y := (hud.size.y if hud != null else 72.0) + 8.0
	var on_map := showing_network
	if not on_map:
		toast_y = _yard_toast_y(toast_y)
	var origin := Vector2(16.0 + icon_w, toast_y)
	if on_map:
		if toast_plate == null:
			toast_plate = PanelContainer.new()
			toast_plate.z_index = 30
			toast_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
			toast_plate.add_theme_stylebox_override("panel", _map_toast_face())
			add_child(toast_plate)
		_park_toast_label(toast_plate)
		toast_label.add_theme_color_override("font_color", SLIP_INK)
		toast_label.add_theme_constant_override("outline_size", 0)
		toast_plate.position = origin
		toast_plate.visible = true
		toast_plate.modulate.a = 1.0
	else:
		_park_toast_label(self)
		toast_label.add_theme_color_override("font_color", INK)
		toast_label.add_theme_constant_override("outline_size", 6)
		toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		toast_label.position = origin
		if toast_plate != null:
			toast_plate.visible = false
	if blown_flash != null and blown:
		blown_flash.position = Vector2(8.0, origin.y - 18.0)
		blown_flash.modulate.a = 1.0
		blown_flash.visible = true
	if toast_fade != null and toast_fade.is_valid():
		toast_fade.kill()
	if not is_inside_tree():
		return
	toast_fade = create_tween()
	var fade := toast_fade
	fade.tween_interval(hold)
	var fade_node: CanvasItem = toast_plate if on_map and toast_plate != null else toast_label
	if not _motion_off():
		fade.tween_property(fade_node, "modulate:a", 0.0, 0.35)
		if blown_flash != null and blown:
			fade.parallel().tween_property(blown_flash, "modulate:a", 0.0, 0.35)
	fade.tween_callback(func() -> void:
		if toast_label != null:
			toast_label.visible = false
		if toast_plate != null:
			toast_plate.visible = false
		if blown_flash != null:
			blown_flash.visible = false)


func _arm_blown_flash() -> void:
	if blown_flash != null:
		return
	blown_flash = TextureRect.new()
	blown_flash.texture = ArtPack.load_texture("res://assets/overlays/blown_flash.webp")
	blown_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blown_flash.z_index = 31
	blown_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blown_flash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blown_flash.custom_minimum_size = Vector2(64, 64)
	blown_flash.size = Vector2(64, 64)
	var mark := TextureRect.new()
	mark.texture = ArtPack.icon_texture("blown", 32.0)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.position = Vector2(16, 16)
	mark.size = Vector2(32, 32)
	blown_flash.add_child(mark)
	add_child(blown_flash)


## People/order plate under the beam. One badge. No idle bob. Text stays when motion is off.
func _build_away_badge() -> void:
	away_badge = PanelContainer.new()
	away_badge.name = "AwayBadge"
	away_badge.visible = false
	away_badge.z_index = 8
	away_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	away_badge.set_meta("away_badge", true)
	var face := StyleBoxFlat.new()
	face.bg_color = Color("3a3126")
	face.border_color = Color("e2a63a")
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.content_margin_left = 8
	face.content_margin_right = 10
	face.content_margin_top = 4
	face.content_margin_bottom = 4
	away_badge.add_theme_stylebox_override("panel", face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	away_badge.add_child(row)
	away_badge_icon = TextureRect.new()
	away_badge_icon.custom_minimum_size = Vector2(22, 22)
	away_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	away_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	away_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(away_badge_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	away_badge_label = _label("", 11, true, false)
	away_badge_label.add_theme_color_override("font_color", Color("e2a63a"))
	away_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(away_badge_label)
	away_badge_body = _label("", 15, false, false)
	away_badge_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(away_badge_body)
	add_child(away_badge)
	away_float = _label("", 18, true, false)
	away_float.name = "AwayFloat"
	away_float.visible = false
	away_float.z_index = 12
	away_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	away_float.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	away_float.add_theme_constant_override("outline_size", 6)
	away_float.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(away_float)


func _away_yard_open() -> bool:
	if at_menu or showing_network:
		return false
	if hub_layer != null and hub_layer.visible:
		return false
	return true


func _place_away_badge() -> void:
	if away_badge == null:
		return
	var top := hud.size.y if hud != null else 72.0
	away_badge.position = Vector2(16.0, top + 8.0)
	if away_float == null or not away_float.visible:
		return
	var w := maxf(away_float.size.x, away_float.get_combined_minimum_size().x)
	var play_top := top + 48.0
	var play_bot := size.y - chrome_bottom
	away_float.position = Vector2((size.x - w) * 0.5, lerpf(play_top, play_bot, 0.38))


func _sync_away_badge() -> void:
	if away_badge == null or game == null:
		return
	var view: Dictionary = game.party_away_view()
	var show: bool = bool(view.get("show", false)) and _away_yard_open()
	away_badge.visible = show
	if not show:
		_hide_away_float()
		return
	var reduce := _motion_off()
	away_badge_label.text = Copy.t("away.badge_label")
	away_badge_body.text = game.party_away_line(reduce)
	away_badge.tooltip_text = Copy.t("away.tip")
	var icon := ArtPack.icon_texture("away_boots", 22.0)
	away_badge_icon.texture = icon
	away_badge_icon.visible = icon != null
	away_badge.rotation = 0.0
	away_badge.scale = Vector2.ONE
	if bool(view.get("first", false)):
		_show_away_float()
		game.party_mark_heard_away()
	_place_away_badge()


func _show_away_float() -> void:
	if away_float == null:
		return
	away_float.text = Copy.t("away.first")
	away_float.visible = true
	away_float.modulate.a = 1.0
	away_float.rotation = 0.0
	if away_float_fade != null and away_float_fade.is_valid():
		away_float_fade.kill()
	if _motion_off():
		away_float_until = Time.get_ticks_msec() + 3200
		return
	away_float_until = 0
	away_float_fade = create_tween()
	away_float_fade.tween_interval(2.6)
	away_float_fade.tween_property(away_float, "modulate:a", 0.0, 0.4)
	away_float_fade.tween_callback(func() -> void:
		if away_float != null:
			away_float.visible = false)


func _hide_away_float() -> void:
	away_float_until = 0
	if away_float_fade != null and away_float_fade.is_valid():
		away_float_fade.kill()
	if away_float != null:
		away_float.visible = false


func _tick_away_float() -> void:
	if away_float == null or not away_float.visible:
		return
	_place_away_badge()
	if away_float_until > 0 and Time.get_ticks_msec() >= away_float_until:
		_hide_away_float()


## Toasts sit under the people-strip badges. A cot plate on the infirmary stays in the yard and does not push them.
func _yard_toast_y(above: float) -> float:
	var y := above
	if away_badge != null and away_badge.visible:
		y = maxf(y, away_badge.position.y + away_badge.get_combined_minimum_size().y + 6.0)
	if sick_badge != null and sick_badge.visible and bool(sick_badge.get_meta("on_strip", false)):
		y = maxf(y, sick_badge.position.y + sick_badge.get_combined_minimum_size().y + 6.0)
	return y


## Same plate family as the away badge. Dusty, still, no pulse.
func _build_sick_badge() -> void:
	sick_badge = PanelContainer.new()
	sick_badge.name = "SickCotsBadge"
	sick_badge.visible = false
	sick_badge.z_index = 8
	sick_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	sick_badge.set_meta("sick_cots", true)
	sick_badge.set_meta("on_strip", true)
	var face := StyleBoxFlat.new()
	face.bg_color = Color("2c2426")
	face.border_color = Color("a85a62")
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.content_margin_left = 8
	face.content_margin_right = 10
	face.content_margin_top = 4
	face.content_margin_bottom = 4
	sick_badge.add_theme_stylebox_override("panel", face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sick_badge.add_child(row)
	sick_badge_icon = TextureRect.new()
	sick_badge_icon.custom_minimum_size = Vector2(22, 22)
	sick_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sick_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sick_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sick_badge_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	sick_badge_label = _label("", 11, true, false)
	sick_badge_label.add_theme_color_override("font_color", Color("c48a90"))
	sick_badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sick_badge_label)
	sick_badge_body = _label("", 15, false, false)
	sick_badge_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sick_badge_body)
	add_child(sick_badge)
	sick_float = _label("", 18, true, false)
	sick_float.name = "SickCotsFloat"
	sick_float.visible = false
	sick_float.z_index = 12
	sick_float.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sick_float.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sick_float.add_theme_constant_override("outline_size", 6)
	sick_float.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(sick_float)


func _sync_sick_badge() -> void:
	if sick_badge == null or game == null:
		return
	var view: Dictionary = game.sick_cots_view()
	var show: bool = bool(view.get("show", false)) and _away_yard_open()
	sick_badge.visible = show
	if not show:
		_hide_sick_float()
		return
	var reduce := _motion_off()
	sick_badge_label.text = Copy.t("sick.label")
	sick_badge_body.text = game.sick_cots_line(reduce)
	sick_badge.tooltip_text = Copy.t("sick.tip")
	var icon := ArtPack.icon_texture("sick_cot", 22.0)
	sick_badge_icon.texture = icon
	sick_badge_icon.visible = icon != null
	sick_badge.rotation = 0.0
	sick_badge.scale = Vector2.ONE
	sick_badge.modulate = Color.WHITE
	if bool(view.get("first", false)):
		_show_sick_float()
		game.sick_mark_seen_cots()
	_place_sick_badge()


func _place_sick_badge() -> void:
	if sick_badge == null or game == null:
		return
	var view: Dictionary = game.sick_cots_view()
	var badge_size := sick_badge.get_combined_minimum_size()
	if badge_size.x < 8.0:
		badge_size.x = 148.0
	if badge_size.y < 8.0:
		badge_size.y = 40.0
	var on_strip := true
	var pos := Vector2.ZERO
	if str(view.get("place", "")) == "infirmary" and yard != null:
		var rect := yard.cell_screen(int(view.get("level", -1)), int(view.get("cell", -1)))
		rect.position += yard.position
		if rect.size.x > 2.0 and rect.size.y > 2.0:
			on_strip = false
			pos = rect.position + Vector2(6.0, 6.0)
	if on_strip:
		var top := hud.size.y if hud != null else 72.0
		var x := 16.0
		if away_badge != null and away_badge.visible:
			var away_w := maxf(away_badge.size.x, away_badge.get_combined_minimum_size().x)
			x = away_badge.position.x + away_w + 8.0
		pos = Vector2(x, top + 8.0)
	var top_lim := (hud.size.y if hud != null else 72.0) + 8.0
	var bot_lim := maxf(top_lim, size.y - chrome_bottom - badge_size.y - 8.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, size.x - badge_size.x - 8.0))
	pos.y = clampf(pos.y, top_lim, bot_lim)
	if away_badge != null and away_badge.visible:
		var away_box := Rect2(away_badge.position, away_badge.get_combined_minimum_size())
		var mine := Rect2(pos, badge_size)
		if away_box.intersects(mine):
			pos.x = clampf(away_box.end.x + 8.0, 8.0, maxf(8.0, size.x - badge_size.x - 8.0))
	sick_badge.position = pos
	sick_badge.rotation = 0.0
	sick_badge.scale = Vector2.ONE
	sick_badge.set_meta("on_strip", on_strip)
	if sick_float == null or not sick_float.visible:
		return
	var w := maxf(sick_float.size.x, sick_float.get_combined_minimum_size().x)
	var play_top := top_lim + 40.0
	var play_bot := size.y - chrome_bottom
	var fy := lerpf(play_top, play_bot, 0.46)
	if away_float != null and away_float.visible:
		fy += 36.0
	sick_float.position = Vector2((size.x - w) * 0.5, fy)


func _show_sick_float() -> void:
	if sick_float == null:
		return
	sick_float.text = Copy.t("sick.first")
	sick_float.visible = true
	sick_float.modulate.a = 1.0
	sick_float.rotation = 0.0
	if sick_float_fade != null and sick_float_fade.is_valid():
		sick_float_fade.kill()
	if _motion_off():
		sick_float_until = Time.get_ticks_msec() + 3200
		return
	sick_float_until = 0
	sick_float_fade = create_tween()
	sick_float_fade.tween_interval(2.6)
	sick_float_fade.tween_property(sick_float, "modulate:a", 0.0, 0.4)
	sick_float_fade.tween_callback(func() -> void:
		if sick_float != null:
			sick_float.visible = false)


func _hide_sick_float() -> void:
	sick_float_until = 0
	if sick_float_fade != null and sick_float_fade.is_valid():
		sick_float_fade.kill()
	if sick_float != null:
		sick_float.visible = false


func _tick_sick_cots() -> void:
	if sick_badge == null or not sick_badge.visible:
		return
	sick_badge.rotation = 0.0
	sick_badge.scale = Vector2.ONE
	_place_sick_badge()
	if sick_float == null or not sick_float.visible:
		return
	if sick_float_until > 0 and Time.get_ticks_msec() >= sick_float_until:
		_hide_sick_float()


## One cable radio item every Settings.radio_every weeks once a radio room stands, held until no card or voice is up.
## At radio_every 0 (twice a week) a second item follows within the same turn, RADIO_HALF_WEEK_MS after the first ends.
func _tick_radio() -> void:
	if shot_mode or at_menu or game == null or game.over != "" or not Settings.radio_on:
		return
	if not game.has_radio_room():
		return
	var due := game.week - game.radio_week >= maxi(Settings.radio_every, 1)
	var second := false
	if not due and Settings.radio_every == 0 and game.radio_week == game.week and radio_extra_week != game.week:
		second = Time.get_ticks_msec() >= radio_done_ms + RADIO_HALF_WEEK_MS
	if not due and not second:
		return
	if hub_layer != null and hub_layer.visible:
		return
	if (dim != null and dim.visible) or guide_step >= 0 or Voice.playing():
		return
	if second:
		radio_extra_week = game.week
	game.radio_week = game.week
	_play_radio(Radio.next(_threat()))


## 0..1 for how much trouble the station is in, to tilt the radio toward anxious news.
func _threat() -> float:
	var t := float(game.discontent) / 100.0
	if game.food_buffer_weeks() < 2.0:
		t += 0.3
	if not game.active_season.is_empty():
		t += 0.2
	if game.hope < 40:
		t += 0.2
	return clampf(t, 0.0, 1.0)


func _play_radio(item: Dictionary) -> void:
	if item.is_empty():
		return
	var lead := Sound.radio_static()
	var length := Voice.play(item, Copy.t("Cable radio"), lead * 0.6)
	game.journal_note("radio", {"id": str(item.get("id", ""))})
	var hold := 10.0
	if length > 0.0:
		hold = maxf(hold, lead * 0.6 + length + 1.5)
	radio_done_ms = Time.get_ticks_msec() + int(hold * 1000.0)
	_show_radio(Radio.text(item), hold)


func _dossier_open() -> bool:
	return deck.top_token() == "dossier" and dim != null and dim.visible


func _tick_voice() -> void:
	if Voice.now_kind == "story" and Voice.playing() and not _dossier_open() and not shot_mode:
		Voice.fade()
	if vo_dossier != "" and Voice.playing(_story_id(vo_dossier)):
		vo_story_progress = Voice.progress()
	elif vo_dossier != "":
		var person_id := vo_dossier
		vo_dossier = ""
		_finish_story(person_id)
		if _dossier_open():
			_show_dossier(person_id)
	_drain_cues()
	if radio_bars != null:
		radio_bars.get_parent().visible = Voice.playing() and Voice.now_kind == "radio"
		radio_bars.queue_redraw()
	var spoken := Voice.playing() and Voice.now_kind != "radio" and Voice.now_kind != "leader" and Voice.now_kind != "event_show"
	var shown := not spoken and Time.get_ticks_msec() < vo_text_until
	if vo_pill == null:
		if not spoken and not shown:
			return
		_build_vo_pill()
	if not spoken and not shown:
		vo_pill.visible = false
		return
	var sub := vo_text
	if spoken:
		vo_label.text = Voice.now_caption
		sub = _subtitle(Voice.now_text, Voice.progress())
	else:
		vo_label.text = vo_text_caption
	vo_bars.visible = spoken
	vo_sub.text = sub
	vo_sub.visible = sub != ""
	var width := 480.0
	if card != null and dim != null and dim.visible:
		width = clampf(card.get_global_rect().position.x - 48.0, 240.0, 480.0)
	vo_sub.custom_minimum_size.x = width
	vo_pill.visible = true
	vo_pill.reset_size()
	var bottom := size.y - chrome_bottom - 8.0
	if radio_panel != null and radio_panel.visible:
		bottom = radio_panel.position.y - 8.0
	vo_pill.position = Vector2(16.0, bottom - vo_pill.get_combined_minimum_size().y)
	vo_bars.queue_redraw()


## The sentence being spoken, guessed from how far through the line playback is, weighted by sentence length.
func _subtitle(text: String, progress: float) -> String:
	var flat := text.replace("\n\n", " ")
	var sentences: Array = []
	for m in sentence_re.search_all(flat):
		var s := m.get_string().strip_edges()
		if s != "":
			sentences.append(s)
	if sentences.is_empty():
		return flat
	var total := 0
	for s in sentences:
		total += str(s).length()
	var at := progress * float(total)
	for s in sentences:
		at -= float(str(s).length())
		if at <= 0.0:
			return str(s)
	return str(sentences.back())


## Plays queued sim conditions one at a time, once no card, guide, or other line is in the way.
func _drain_cues() -> void:
	if game == null or at_menu:
		return
	for cue in game.vo_cues:
		var row := Voice.condition(str(cue))
		if not row.is_empty() and vo_queue.size() < 3:
			vo_queue.append(row)
	game.vo_cues.clear()
	if vo_queue.is_empty() or Voice.playing() or Time.get_ticks_msec() < vo_text_until:
		return
	if (dim != null and dim.visible) or guide_step >= 0 or (hub_layer != null and hub_layer.visible):
		return
	_say(vo_queue.pop_front(), Copy.t("Station"))


func _build_vo_pill() -> void:
	vo_pill = PanelContainer.new()
	vo_pill.z_index = 25
	vo_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	vo_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	vo_pill.tooltip_text = Copy.t("Click to stop the voice")
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.07, 0.06, 0.05, 0.94)
	plate.border_color = Color("e2a63a")
	plate.set_border_width_all(1)
	plate.set_content_margin_all(8)
	plate.content_margin_left = 12
	plate.content_margin_right = 14
	plate.set_corner_radius_all(14)
	vo_pill.add_theme_stylebox_override("panel", plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vo_bars = Control.new()
	vo_bars.custom_minimum_size = Vector2(22, 18)
	vo_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vo_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vo_bars.draw.connect(func() -> void:
		var t := Time.get_ticks_msec() / 1000.0
		for i in 4:
			var h := 4.0 + 14.0 * (0.5 + 0.5 * sin(t * (5.0 + i * 1.7) + i * 1.3))
			if Settings.reduced():
				h = 10.0
			vo_bars.draw_rect(Rect2(i * 6.0, 18.0 - h, 4.0, h), Color("e2a63a")))
	row.add_child(vo_bars)
	var was := on_paper
	on_paper = false
	vo_label = _label("", 15)
	vo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vo_sub = _label("", 15)
	vo_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vo_sub.add_theme_color_override("font_color", Color(0.93, 0.9, 0.84, 0.92))
	vo_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	on_paper = was
	vo_label.add_theme_color_override("font_color", Color("e2a63a"))
	row.add_child(vo_label)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	box.add_child(vo_sub)
	vo_pill.add_child(box)
	vo_pill.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			Voice.fade(0.3)
			vo_text_until = 0
			vo_pill.visible = false)
	add_child(vo_pill)


## Speaks a line now, or shows its text in the voice pill for a while when its audio is missing.
func _say(row: Dictionary, caption: String) -> void:
	if row.is_empty():
		return
	if Voice.play(row, caption) > 0.0:
		vo_text_until = 0
		return
	vo_text = Voice.text(row)
	vo_text_caption = caption
	if vo_text == "":
		return
	vo_text_until = Time.get_ticks_msec() + int(clampf(vo_text.length() * 60.0, 5000.0, 14000.0))


## The recorded reading of the card's text, once per card: the body, or a follow-up's text for the earlier choice.
## The card has the text already, so it plays without a subtitle; no take, or an outdated one, stays silent.
func _event_voice(ev: Dictionary) -> void:
	var kind := "event"
	if bool(ev.get("check_only", false)):
		kind = "check"
	elif bool(ev.get("crunch", false)):
		kind = "crunch"
	var part := "body"
	var memory := str(ev.get("follow_memory", ""))
	var by = ev.get("by", {})
	if memory != "" and by is Dictionary and by.has(memory):
		part = "after_" + memory
	var key := "%d:%d:%s:%s" % [game.get_instance_id(), game.week, str(ev.get("id", "")), part]
	if event_vo_heard == key:
		return
	event_vo_heard = key
	Voice.play(Voice.event_show(kind, str(ev.get("id", "")), part, Copy.t(game.line_of(ev, "text"))), "")


## A check's outcome read aloud (chk_<check>_<option>_<success|fail>); true when it plays.
func _check_voice(event_id: String, choice_id: String) -> bool:
	var last: Dictionary = game.last_check
	if not check_flash or last.is_empty() or bool(last.get("bet", false)):
		return false
	var part := "%s_%s" % [choice_id, "success" if bool(last.get("success", false)) else "fail"]
	return Voice.play(Voice.event_show("check", event_id, part, str(last.get("outcome", ""))), "") > 0.0


## A confirmed action can have a system line named "<kind>_<id>" (law_rationing) or just "<kind>" (rally).
func _action_voice(kind: String, id: String) -> void:
	var row := Voice.condition("%s_%s" % [kind, id]) if id != "" else {}
	if row.is_empty():
		row = Voice.condition(kind)
	_say(row, Copy.t("Station"))


func _show_radio(text: String, hold: float) -> void:
	if radio_panel == null:
		radio_panel = PanelContainer.new()
		radio_panel.z_index = 25
		radio_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		radio_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		radio_panel.tooltip_text = Copy.t("Click to dismiss")
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(0.07, 0.06, 0.05, 0.94)
		plate.border_color = Color("e2a63a")
		plate.border_width_left = 4
		plate.set_content_margin_all(12)
		plate.content_margin_left = 16
		plate.set_corner_radius_all(3)
		radio_panel.add_theme_stylebox_override("panel", plate)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var was := on_paper
		on_paper = false
		var head_row := HBoxContainer.new()
		head_row.add_theme_constant_override("separation", 12)
		head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var head := _label("Cable radio", 15, true)
		head.add_theme_color_override("font_color", Color("e2a63a"))
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head_row.add_child(head)
		var air := HBoxContainer.new()
		air.add_theme_constant_override("separation", 6)
		air.mouse_filter = Control.MOUSE_FILTER_IGNORE
		radio_bars = Control.new()
		radio_bars.custom_minimum_size = Vector2(22, 16)
		radio_bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		radio_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
		radio_bars.draw.connect(func() -> void:
			var t := Time.get_ticks_msec() / 1000.0
			for i in 4:
				var h := 3.0 + 13.0 * (0.5 + 0.5 * sin(t * (4.0 + i * 1.9) + i * 0.9))
				if Settings.reduced():
					h = 9.0
				radio_bars.draw_rect(Rect2(i * 6.0, 16.0 - h, 4.0, h), Color("d9534f")))
		air.add_child(radio_bars)
		var on_air := _label("On air", 13, true)
		on_air.add_theme_color_override("font_color", Color("d9534f"))
		on_air.mouse_filter = Control.MOUSE_FILTER_IGNORE
		air.add_child(on_air)
		air.visible = false
		head_row.add_child(air)
		box.add_child(head_row)
		radio_text = _label("", 16)
		radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		radio_text.custom_minimum_size = Vector2(380, 0)
		radio_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(radio_text)
		on_paper = was
		radio_panel.add_child(box)
		radio_panel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				_hide_radio())
		add_child(radio_panel)
	radio_text.text = text
	radio_panel.visible = true
	radio_panel.modulate.a = 1.0
	radio_panel.reset_size()
	var bottom := size.y - chrome_bottom - 8.0
	radio_panel.position = Vector2(16.0, bottom - radio_panel.get_combined_minimum_size().y)
	if radio_tween != null:
		radio_tween.kill()
	radio_tween = create_tween()
	radio_tween.tween_interval(hold)
	radio_tween.tween_property(radio_panel, "modulate:a", 0.0, 0.5)
	radio_tween.tween_callback(func() -> void:
		radio_panel.visible = false)


func _hide_radio() -> void:
	if Voice.playing() and Voice.now_kind == "radio":
		Voice.stop()
	if radio_tween != null:
		radio_tween.kill()
	if radio_panel != null:
		radio_panel.visible = false


func _journal_line(row: Dictionary) -> String:
	var kind := str(row.get("kind", ""))
	match kind:
		"week":
			return Copy.t("Week %d began.") % int(row.get("week", 0))
		"build":
			return Copy.t("Started building %s.") % _room_type_name(str(row.get("type", "")))
		"built":
			return Copy.t("%s built.") % _room_type_name(str(row.get("type", "")))
		"order_done":
			var who := Copy.person(str(row.get("name", "")))
			var what := Copy.t(str(ORDER_DONE.get(str(row.get("order", "")), "order completed"))) if bool(row.get("ok", true)) else Copy.t("order failed")
			var line := "%s: %s" % [who, what] if who != "" else what.substr(0, 1).to_upper() + what.substr(1)
			var where := _station_name(str(row.get("station", "")))
			return "%s (%s)." % [line, where] if where != "" else line + "."
		"season":
			var season := Copy.season(str(row.get("id", "")))
			if not Copy.ru():
				season = season.capitalize()
			if bool(row.get("soon", false)):
				return Copy.t("%s season is coming.") % season
			return Copy.t("%s season started.") % season
		"flood":
			return Copy.t("Flood started on level %d.") % (int(row.get("level", 0)) + 1)
		"deaths":
			return Copy.t("Deaths: %d.") % int(row.get("n", 0))
		"born":
			return Copy.t("New residents: %d.") % int(row.get("n", 0))
		"find":
			return Copy.t(str(FIND_LINES.get(str(row.get("find", "")), "The dig turned something up.")))
		"tunnel":
			return Copy.t("Tunnel to %s cleared.") % _station_name(str(row.get("station", "")))
		"dark":
			return Copy.t("%s went dark.") % _room_type_name(str(row.get("type", "")))
		"war":
			return Copy.t("%s declared war.") % Copy.t(game._fname(str(row.get("faction", ""))))
		"ultimatum":
			return Copy.t("%s took its price for an unpaid demand.") % Copy.t(game._fname(str(row.get("faction", ""))))
		"station":
			var place := _station_name(str(row.get("station", "")))
			var to := str(row.get("to", ""))
			if to == game.player:
				return Copy.t("%s joined us.") % place
			if str(row.get("from", "")) == game.player:
				if to == "neutral":
					return Copy.t("%s threw out our garrison.") % place
				return Copy.t("%s went over to %s.") % [place, Copy.t(game._fname(to))]
			return Copy.t("%s took %s.") % [Copy.t(game._fname(to)), place]
		"dig":
			return Copy.t("Dug a new cell.")
		"governor":
			var who: Dictionary = game.people.get(str(row.get("person", "")), {})
			return Copy.t("%s now holds %s for us.") % [Copy.person(str(who.get("name", ""))), _station_name(str(row.get("station", "")))]
		"upgrade":
			if str(row.get("name", "")) != "":
				return Copy.t("Upgraded %s to tier %s: %s.") % [_room_type_name(str(row.get("type", ""))), roman(int(row.get("tier", 1))), _upgrade_name(str(row.name))]
			return Copy.t("Upgraded %s.") % _room_type_name(str(row.get("type", "")))
		"demolish":
			return Copy.t("Demolished %s.") % _room_type_name(str(row.get("type", "")))
		"event":
			var title := game.line_of(row, "title")
			var choice := game.line_of(row, "choice")
			var ev: Dictionary = game._event_by_id(str(row.get("event_id", "")))
			if title == "" and not ev.is_empty():
				title = Copy.t(game.line_of(ev, "title"))
				for option in ev.get("choices", []):
					if str(option.get("id", "")) == str(row.get("choice_id", "")):
						choice = Copy.t(game.line_of(option, "label"))
			if title == "" and ev.is_empty():
				var leg: Dictionary = game.crunch_leg(str(row.get("event_id", "")))
				if not leg.is_empty():
					title = Copy.t(str(leg.title))
					choice = Copy.t(str(leg.suffer)) if str(row.get("choice_id", "")) == "leave" else ""
			if title == "":
				title = str(row.get("event_id", ""))
			return "%s: %s" % [title, choice] if choice != "" else title
		"law":
			return Copy.t("Enacted %s.") % Copy.t(str(game.catalog.laws.get(str(row.get("law", "")), {}).get("name", row.get("law", ""))))
		"repeal":
			return Copy.t("Repealed %s.") % Copy.t(str(game.catalog.laws.get(str(row.get("law", "")), {}).get("name", row.get("law", ""))))
		"pump", "quarantine", "burn", "rally":
			return Copy.t({"pump": "Pumped the water out.", "quarantine": "Called a quarantine.", "burn": "Burned salvage for power.", "rally": "Held a rally."}[kind])
		"push":
			return Copy.t("push.toast_ok").replace("{room}", _room_type_name(str(row.get("type", ""))))
		"order", "cancel":
			var target := _station_name(str(row.get("station", "")))
			var verb := Copy.t(network_view._order_title(str(row.get("order", ""))))
			if kind == "cancel":
				verb = Copy.t("Cancelled: %s") % verb
			return "%s: %s" % [verb, target] if target != "" else verb
		"news":
			var news := _alert_text(str(row.get("text", "")))
			var tag := news.get_slice(" ", 0)
			if tag.length() >= 3 and tag == tag.to_upper() and tag != tag.to_lower():
				news = news.substr(tag.length() + 1)
			return news
		"radio":
			return Radio.text(Radio.by_id(str(row.get("id", ""))))
		"audience":
			var leader_name := _leader_text(game.leader_name(str(row.get("faction", "")), "leader"))
			match str(row.get("result", "")):
				"deal":
					return Copy.t("%s: deal taken, %s.") % [leader_name, Copy.t(str(DEAL_NAMES.get(str(row.get("deal", "")), ""))).to_lower()]
				"silence":
					return Copy.t("%s was left waiting. They count it as a refusal.") % leader_name
				"helped":
					return Copy.t("%s: you brought help, %s.") % [leader_name, Copy.stock(int(row.get("amount", 0)), str(row.get("resource", "")))]
			return Copy.t("%s was turned away.") % leader_name
		"handed_over":
			var given := str(row.get("name_ru", "")) if Copy.ru() else ""
			if given == "":
				given = Copy.person(str(row.get("name", "")))
			return Copy.t("Handed %s to the Directorate.") % given
		"papers_burned":
			if bool(row.get("destroyed", false)):
				return Copy.t("Burned the papers. One Papers clue is gone.")
			return Copy.t("Burned the papers before any clue was found.")
		"false_way":
			return Copy.t("%s took the lantern toll and gave nothing back.") % _leader_text(game.leader_name("black_flag", "leader"))
		"regard":
			return _regard_text({str(row.get("faction", "")): int(row.get("delta", 0))}) + "."
		"truth":
			return Copy.t("Truth learned: %s.") % _fragment_title(str(row.get("id", "")))
		"testimony":
			return Copy.t("Testimony gathered: Words +1 (%d stories heard).") % int(row.get("stories", 0))
		"proof":
			return Copy.t("Proof gathered: %d.") % int(row.get("amount", 0))
		"ending":
			return Copy.t("The run ended: %s.") % game.ending_text(str(row.get("ending", "")), "title")
	return kind


func _journal_group(kind: String) -> String:
	match kind:
		"build", "built", "dig", "upgrade", "demolish", "find", "tunnel", "dark":
			return "builds"
		"event", "law", "repeal", "pump", "quarantine", "burn", "rally", "push", "audience", "handed_over", "papers_burned", "false_way", "regard":
			return "decisions"
		"order", "cancel", "order_done", "station", "war", "ultimatum":
			return "map"
		"news", "radio", "season", "flood", "deaths", "born", "truth", "testimony", "proof", "ending":
			return "news"
	return ""


func _room_type_name(type: String) -> String:
	if game.catalog.rooms.has(type):
		return Copy.t(str(game.catalog.rooms[type].name))
	return type


## rooms.json names upgrades by id ("drill_heads"); ru.json keys them by the spaced words.
func _upgrade_name(id: String) -> String:
	var name := Copy.t(id.replace("_", " "))
	return name.substr(0, 1).to_upper() + name.substr(1)


func _station_name(sid: String) -> String:
	if sid == "" or not game.stations.has(sid):
		return ""
	var community: String = game.station_text(sid, "community")
	if community != "":
		return community
	return Copy.t(str(game.stations[sid].get("name", sid)))


func _show_journal() -> void:
	if game == null:
		return
	if not _claim(ModalDeck.AMBIENT, "journal", _show_journal):
		return
	_open_card(Copy.t("Journal"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for pair in [["", "All"], ["builds", "Builds"], ["decisions", "Decisions"], ["map", "Map"], ["news", "News"], ["truth", "Truth"]]:
		var key := str(pair[0])
		var button := _button(str(pair[1]), _pick_journal_filter.bind(key), "dossier_tab")
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 17)
		if key == journal_filter:
			_style_primary(button)
		flow.add_child(button)
	card_body.add_child(flow)
	if journal_filter == "truth":
		_truth_page()
		return
	var shown := 0
	var week_seen := -1
	for i in range(game.journal.size() - 1, -1, -1):
		var row: Dictionary = game.journal[i]
		var kind := str(row.get("kind", ""))
		if kind == "week":
			continue
		if journal_filter != "" and _journal_group(kind) != journal_filter:
			continue
		var week_n := int(row.get("week", 0))
		if week_n != week_seen:
			week_seen = week_n
			var head := _label(Copy.t("Week %d") % week_n, 18, true)
			head.add_theme_color_override("font_color", Color("e2a63a"))
			card_body.add_child(head)
		var text := _label(_journal_line(row), 15)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if kind == "radio":
			text.add_theme_color_override("font_color", PAPER_MUTED)
		elif kind in ["flood", "deaths", "war", "ultimatum", "handed_over", "papers_burned", "false_way"] or (kind == "season" and not bool(row.get("soon", false))):
			text.add_theme_color_override("font_color", ALERT_INK)
		card_body.add_child(text)
		shown += 1
		if shown >= 150:
			break
	if shown == 0:
		_placeholder("", "Nothing recorded yet.")


func _pick_journal_filter(key: String) -> void:
	journal_filter = key
	_show_journal()


const SLIP_PAPER := Color("efe4c8")
const SLIP_UNKNOWN := Color("cfc3a6")
const SLIP_INK := Color("2b2118")
const SLIP_MUTED := Color("5f4f3c")
const FRAGMENT_HOW := {"honest": "Learned honestly, week %d", "dirty": "Learned the dirty way, week %d", "found": "Found, week %d"}
const PROOF_MARK := {"honest": "with proof", "dirty": "without proof", "found": "found"}
const PROOF_INK := {"honest": Color("2f5a2c"), "dirty": Color("8a2f22"), "found": Color("5f4f3c")}


## The journal's Truth page: the five fragments as paper slips, then the artifact counts and the Words source.
func _truth_page() -> void:
	var known := 0
	for id in Game.FRAGMENTS:
		if game.fragment_known(str(id)):
			known += 1
	_body(Copy.t("Truth fragments known: %d of %d.") % [known, Game.FRAGMENTS.size()])
	for id in Game.FRAGMENTS:
		card_body.add_child(_truth_slip(str(id)))
	var counts := _label(Copy.t("Papers %d · Iron %d · Words %d") % [int(game.artifacts.get("papers", 0)),
		int(game.artifacts.get("iron", 0)), int(game.artifacts.get("words", 0))], 17, true)
	card_body.add_child(counts)
	var words := _label(Copy.t("Words: stories heard %d, next testimony in %s.") % [game.stories_heard(),
		Words.count(game.stories_to_testimony(), "story", "stories")], 15)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_color_override("font_color", PAPER_MUTED)
	card_body.add_child(words)


func _truth_slip(id: String) -> PanelContainer:
	var fid := str(Game.FRAGMENTS[id])
	var row = game.fragments.get(id, {})
	var known := game.fragment_known(id)
	var slip := _slip_panel(SLIP_PAPER if known else SLIP_UNKNOWN)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	slip.add_child(line)
	var mark := _faction_mark(game.leader(fid), 32)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	line.add_child(mark)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	var holder := Copy.t("Held by %s, %s.") % [_leader_text(game.leader_name(fid, "leader")), _leader_text(game.leader_name(fid, "title"))]
	if known:
		var how := str(row.get("how", "found"))
		if not PROOF_MARK.has(how):
			how = "found"
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(_slip_label(_fragment_title(id), 17, SLIP_INK, true))
		head.add_child(_proof_stamp(how))
		words.add_child(head)
		words.add_child(_slip_label(game.fragment_text(id, "text"), 15, SLIP_INK))
		words.add_child(_slip_label(Copy.t(str(FRAGMENT_HOW.get(how, FRAGMENT_HOW.found))) % int(row.get("week", 0)), 13, SLIP_MUTED))
	else:
		words.add_child(_slip_label("?", 22, SLIP_INK, true))
		var hint := game.fragment_text(id, "hint")
		if hint != "":
			words.add_child(_slip_label(hint, 15, SLIP_INK))
		words.add_child(_slip_label(holder, 13, SLIP_MUTED))
	return slip


func _slip_panel(paper: Color) -> PanelContainer:
	var slip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = paper
	style.border_color = Color(0, 0, 0, 0.35)
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	style.set_content_margin_all(10)
	slip.add_theme_stylebox_override("panel", style)
	slip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slip


## A small ink stamp on a known slip: with proof (honest), without proof (dirty) or found.
func _proof_stamp(how: String) -> PanelContainer:
	var ink: Color = PROOF_INK[how]
	var stamp := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(ink, 0.08)
	style.border_color = ink
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	stamp.add_theme_stylebox_override("panel", style)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lab := _label(Copy.t(str(PROOF_MARK[how])).to_upper(), 12, true)
	lab.add_theme_color_override("font_color", ink)
	stamp.add_child(lab)
	return stamp


func _slip_label(text: String, size: int, ink: Color, display := false) -> Label:
	var lab := _label(text, size, display)
	lab.add_theme_color_override("font_color", ink)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _fragment_title(id: String) -> String:
	var title: String = game.fragment_text(id, "title")
	return title if title != "" else id


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (event as InputEventKey).keycode == KEY_ESCAPE and game != null and deck.top_token() == "raid_share":
		Sound.play("click")
		_pick_raid_share("stockpile")
		get_viewport().set_input_as_handled()
		return
	if (event as InputEventKey).keycode == KEY_ESCAPE and _sheet_open():
		Sound.play("click")
		_menu_back()
		get_viewport().set_input_as_handled()
		return
	if (event as InputEventKey).keycode == KEY_J and not at_menu and game != null:
		if deck.top_token() == "journal":
			_close_card()
		else:
			_show_journal()
		get_viewport().set_input_as_handled()


func _tooltip_theme() -> Theme:
	var tips := Theme.new()
	tips.default_font = body_font
	tips.default_font_size = 16
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.07, 0.06, 0.05, 0.97)
	plate.border_color = Color(0.93, 0.78, 0.42, 0.9)
	plate.set_border_width_all(1)
	plate.set_content_margin_all(8)
	tips.set_stylebox("panel", "TooltipPanel", plate)
	tips.set_color("font_color", "TooltipLabel", Color("efe6d2"))
	tips.set_font_size("font_size", "TooltipLabel", 16)
	return tips


func _undo_toast(text: String, undo: Callable) -> void:
	_hide_undo_toast()
	undo_toast = PanelContainer.new()
	undo_toast.z_index = 31
	undo_toast.mouse_filter = Control.MOUSE_FILTER_STOP
	undo_toast.add_theme_stylebox_override("panel", _paper_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	undo_toast.add_child(row)
	var was := on_paper
	on_paper = true
	var lab := _label(text, 18, true)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	var back := _button("Undo", undo)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.custom_minimum_size = Vector2(110, 40)
	back.add_theme_font_size_override("font_size", 18)
	row.add_child(back)
	on_paper = was
	add_child(undo_toast)
	undo_toast.position = Vector2(16.0, (hud.size.y if hud != null else 72.0) + 8.0)
	var fade := create_tween()
	fade.tween_interval(8.0)
	fade.tween_property(undo_toast, "modulate:a", 0.0, 0.4)
	fade.tween_callback(_expire_undo_toast.bind(undo_toast))


func _expire_undo_toast(which: PanelContainer) -> void:
	if which == undo_toast:
		_hide_undo_toast()


func _hide_undo_toast() -> void:
	if undo_toast != null and is_instance_valid(undo_toast):
		undo_toast.queue_free()
	undo_toast = null


func note_spend(cost: Dictionary) -> void:
	if game == null:
		return
	if stock_tween != null:
		stock_tween.kill()
	stock_tween = create_tween()
	for key in cost:
		var spent := int(cost[key])
		if spent == 0 or not chips.has(str(key)):
			continue
		var target := float(int(game.stock.get(key, 0)))
		var start := target + float(spent)
		stock_shown[str(key)] = target
		chips[str(key)].delta.text = "-%d" % spent
		chips[str(key)].delta.add_theme_color_override("font_color", DELTA_DOWN)
		stock_tween.parallel().tween_method(_set_stock_text.bind(str(key)), start, target, 0.45)


func _show_dawn() -> void:
	shelved_event = ""
	if game != null and game.raid_share_open():
		_show_raid_share()
		return
	if game != null and not game.order_reports.is_empty():
		_show_order_report()
		return
	if game != null and game.over == "" and not game.audience.is_empty():
		_show_audience()
		return
	if game != null:
		game.big_first()
		## Every waiting event marks the room it names right away, so a small one shows on the station before it
		## comes up.
		for ev in game.pending:
			note_incident(ev)
	if not _claim(ModalDeck.NARRATIVE, "dawn", _show_dawn):
		return
	if footer.text == WAITING or footer.text == Copy.t(WAITING):
		footer.text = ""
		footer.visible = false
	_paint_dawn()


func open_night_panel() -> void:
	if game == null or game.over != "" or night_panel == null:
		return
	if modal_open:
		return
	if night_panel.has_method("open_for"):
		night_panel.open_for(self)


func _want_night() -> bool:
	return _dev_args().has("--night-runs")


func _paint_night_resolve(ev: Dictionary) -> void:
	Sound.play("card_open")
	_open_card(game.line_of(ev, "title"), false)
	var art_path := str(ev.get("art", ""))
	if art_path != "" and ResourceLoader.exists(art_path):
		var tex: Texture2D = load(art_path)
		if tex != null:
			var plate := TextureRect.new()
			plate.texture = tex
			plate.custom_minimum_size = Vector2(0, 96)
			plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			card_body.add_child(plate)
	for line in game.line_of(ev, "text").split("\n"):
		if str(line) != "":
			_body_ready(str(line))
	var enc := str(ev.get("encounter", ""))
	if enc != "":
		var nest := PanelContainer.new()
		var face := StyleBoxFlat.new()
		face.bg_color = Color("241c14")
		face.border_color = Color("e0a84a")
		face.set_border_width_all(1)
		face.set_corner_radius_all(6)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 8
		face.content_margin_bottom = 8
		nest.add_theme_stylebox_override("panel", face)
		nest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nest.custom_minimum_size = Vector2(480, 0)
		var inner := VBoxContainer.new()
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_theme_constant_override("separation", 6)
		nest.add_child(inner)
		inner.add_child(_label("run.encounter_title", 18, true))
		var body := _label("run.encounter." + enc, 16)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(440, 0)
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(body)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for choice in ev.choices:
			var pick := _choice_button(game.line_of(choice, "label"), choice, _pick_event.bind(str(ev.id), str(choice.id)))
			pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(pick)
		inner.add_child(row)
		card_body.add_child(nest)
	else:
		for choice in ev.choices:
			card_body.add_child(_choice_button(game.line_of(choice, "label"), choice, _pick_event.bind(str(ev.id), str(choice.id))))


func _night_shots() -> void:
	shot_mode = true
	hold_dawn = true
	at_menu = false
	await _settle(_shot_size())
	_close_card()
	if guide_layer != null:
		guide_layer.visible = false
	var free: Array = []
	for person in game.residents:
		var pid := str(person.get("id", ""))
		if game._is_council(pid) or game._is_child(person):
			continue
		if NightRuns.block_reason(game, pid) == "":
			free.append(pid)
	var sq: Dictionary = game.squads[game.player]
	var roster: Array = sq.get("roster", [])
	if not free.is_empty():
		var member := str(free[0])
		if roster.size() >= int(sq.get("max_size", roster.size())) and not roster.is_empty():
			game.party_toggle(str(roster[0]))
		game.party_toggle(member)
		free.pop_front()
	if night_panel != null and free.size() >= 2:
		night_panel.picked = [free[0], free[1]]
	showing_network = true
	if network_view != null:
		network_view.visible = true
		network_view.bind(self)
	if yard != null:
		yard.visible = false
	open_night_panel()
	for _i in 4:
		await _frame()
	if night_panel != null and night_panel.has_method("reveal_pack"):
		night_panel.reveal_pack()
	for _i in 3:
		await _frame()
	_save("p74_backpack")
	if night_panel != null:
		night_panel._rebuild()
	for _i in 3:
		await _frame()
	_save("p74_night_panel")
	if night_panel != null and night_panel.has_method("close_panel"):
		night_panel.close_panel()
	var runner := ""
	for person in game.residents:
		var pid := str(person.get("id", ""))
		if game._is_council(pid) or game._is_child(person):
			continue
		if NightRuns.block_reason(game, pid) == "":
			runner = pid
			break
	var known: Array = NightRuns.known_sites(game)
	if runner != "" and not known.is_empty():
		NightRuns.send(game, str(known[0].get("id", "")), [runner], ["food", "materials", "medkits", "intel"])
		var st: Dictionary = game.flags.night_runs
		st["force_total"] = 6
		st["force_encounter"] = "open_cache"
		NightRuns.dawn(game)
		_show_dawn()
		await _frame()
		await _frame()
		if card_scroll != null:
			var bar := card_scroll.get_v_scroll_bar()
			card_scroll.scroll_vertical = int(bar.max_value)
		await _frame()
		_save("p74_dawn_resolve")
		_close_card()
	showing_network = true
	if network_view != null:
		network_view.visible = true
		network_view.bind(self)
	await _frame()
	await _frame()
	if network_view != null and game.stations.has("eastwater"):
		var world: Vector2 = network_view._station_world(game.stations.eastwater)
		network_view.origin = world
		network_view.zoom = 1.45
		network_view._clamp_view()
		network_view.queue_redraw()
		if network_view._ink_layer != null:
			network_view._ink_layer.queue_redraw()
	await _frame()
	await _frame()
	_save("p74_rumored_pin")
	get_tree().quit(0)


func _paint_dawn() -> void:
	var lines := _morning_lines()
	var show_event: bool = not game.pending.is_empty() and (event_mode != "dawn" or game.event_is_big(game.front_event()))
	if not show_event:
		var dawn_key := "%d:%d" % [game.get_instance_id(), game.week]
		if dawn_heard != dawn_key:
			dawn_heard = dawn_key
			Sound.play("new_week")
		_open_card(Copy.t("Dawn of week %d") % game.week)
		_choice_tally()
		var urgent: PackedStringArray = []
		var rest: PackedStringArray = []
		for line in lines:
			if _urgent_line(line):
				urgent.append(line)
			else:
				rest.append(line)
		_alert_chips(urgent, 0)
		_far_revolt()
		_intent_row(rest)
		if urgent.is_empty() or not rest.is_empty():
			_morning_notes(rest)
		_forecast_buttons(_forecast_rows(99, URGENT_WEEKS))
		var later_n: int = game.small_pending()
		if later_n > 0:
			_body(Copy.t("%s will come up during the week.") % Words.count(later_n, "smaller matter", "smaller matters"))
		else:
			_body("No one is waiting on a decision.")
		card_body.add_child(_button("To the platform", _close_card))
		return
	var ev: Dictionary = game.front_event()
	if bool(ev.get("night_run", false)):
		_paint_night_resolve(ev)
		return
	Sound.play("card_open")
	note_incident(ev)
	_open_card(game.line_of(ev, "title"), false, "Event")
	var banner := _event_banner(ev)
	if banner != null:
		card_body.add_child(banner)
		card_body.move_child(banner, 0)
	_who_row(str(ev.get("who", "")))
	_body(game.line_of(ev, "text"))
	_event_voice(ev)
	if check_flash:
		var rolled := _check_result_line()
		if rolled != "":
			_body(rolled)
			check_flash = false
	_choice_tally()
	var urgent: PackedStringArray = []
	var folded: PackedStringArray = []
	for line in lines:
		if _urgent_line(line):
			urgent.append(line)
		else:
			folded.append(line)
	var news := _news_count(folded) + _forecast_rows(URGENT_WEEKS, 99).size() + _far_revolt_count()
	_alert_chips(urgent, news)
	if news_open:
		_far_revolt()
		_intent_row(folded)
		_morning_notes(folded)
		_forecast_buttons(_forecast_rows(URGENT_WEEKS, 99))
	_choice_divider()
	for choice in ev.choices:
		if not game.choice_offered(choice):
			continue
		if choice.has("check") and not game.choice_locked(choice):
			_check_block(ev, choice)
		elif choice.has("bet"):
			_body("The odds are hidden.")
		var pick := _choice_button(game.line_of(choice, "label"), choice, _pick_event.bind(str(ev.id), str(choice.id)))
		var why := ""
		if game.choice_locked(choice):
			why = game.lock_reason(choice)
		elif not game.afford_choice(choice):
			why = game.shortage_text(choice.get("cost", {}))
			if why == "":
				why = Copy.t("That cost cannot be paid.")
		card_body.add_child(pick)
		var words := _choice_words(game.choice_effects(choice))
		if words != "":
			card_body.add_child(_effect_line(words))
		if game.choice_locked(choice) or why != "":
			pick.disabled = true
			pick.tooltip_text = why
			if why != "":
				card_body.add_child(_choice_reason(why))
	var after_n: int = game.pending.size() - 1
	if event_mode == "dawn":
		after_n = game.pending.size() - game.small_pending() - 1
	elif event_mode == "one":
		after_n = 0
	if after_n > 0:
		_body(Copy.t("%s waiting after this one.") % Words.count(after_n, "other", "others"))
	var later := _button("Not now", _close_card)
	_style_choice(later)
	later.custom_minimum_size.y = 40
	later.add_theme_font_size_override("font_size", 17)
	card_body.add_child(later)


## Why the choice above is closed: one small muted line right under its button.
func _choice_reason(text: String) -> Label:
	var lab := _label(text, 15)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_color_override("font_color", PAPER_MUTED)
	return lab


## Prefer the report's own text. Structured blocks fill an empty body. A failure stays a failure line.
func _order_report_body(row: Dictionary) -> String:
	var text := str(row.get("text", ""))
	if text != "":
		return text
	if game != null and game.has_method("order_report_lines"):
		var lines: PackedStringArray = game.order_report_lines(row)
		if not lines.is_empty():
			return "\n".join(lines)
	if not bool(row.get("ok", true)):
		return Copy.t("The order failed.")
	return ""


## Share card after a player raid win. Dilemma paper, three choices, no deltas on the buttons.
## Close, ESC, or the dawn timeout takes Stockpile. Not a soft dawn chip.
func _show_raid_share() -> void:
	if game == null or not game.raid_share_open():
		if game != null and game.dawn_held():
			game.resume_dawn()
		_show_dawn()
		return
	if not _claim(ModalDeck.NARRATIVE, "raid_share", _show_raid_share):
		return
	_open_card("raid_share.title", true)
	_body_ready(game.raid_share_body())
	_body_muted("raid_share.tip")
	_choice_divider()
	card_body.add_child(_choice_button("raid_share.stockpile", {}, _pick_raid_share.bind("stockpile")))
	card_body.add_child(_choice_button("raid_share.yard", {}, _pick_raid_share.bind("yard")))
	card_body.add_child(_choice_button("raid_share.tribute", {}, _pick_raid_share.bind("tribute")))


func _pick_raid_share(choice_id: String) -> void:
	if game == null:
		return
	if game.raid_share_open():
		var row: Dictionary = game.apply_raid_share(choice_id)
		if not bool(row.get("ok", false)):
			_body_muted("raid_share.tip")
			_fit_card()
			return
		var toast := str(row.get("toast", ""))
		if toast != "":
			_toast(toast)
	var resume := game.dawn_held()
	game.resume_dawn()
	_close_card()
	_refresh()
	if not resume:
		return
	if game.over == "":
		if not shot_mode:
			SaveGame.write_auto(game)
		_show_dawn()
		_play_night()
	else:
		_show_ending()
	_try_home_float()


func _show_order_report() -> void:
	if game == null or game.order_reports.is_empty():
		_show_dawn()
		return
	if not _claim(ModalDeck.NARRATIVE, "order", _show_order_report):
		return
	var row: Dictionary = game.order_reports[0]
	# P22 may share order_reports. Battle rows carry the dawn aftermath.
	if bool(row.get("battle", false)):
		_show_battle_report(row)
		return
	_open_card(str(row.get("title", Copy.t("Dawn report"))))
	var art := _order_art(row)
	if art != null:
		card_body.add_child(art)
	_body(_order_report_body(row))
	var said := _leader_said(str(row.get("faction", "")), row.get("line", {}))
	if said != "":
		_body(said)
		var line_key := str(row.get("line_key", ""))
		if line_key != "":
			_leader_voice(str(row.faction), line_key, "report:%d:%s:%s" % [game.week, str(row.faction), str(row.get("text", ""))])
	card_body.add_child(_button("Continue", _next_order_report))


func _show_battle_report(row: Dictionary) -> void:
	_open_card(str(row.get("title", Copy.t("combat.dawn"))))
	var eyebrow := _label("", 14)
	eyebrow.text = Copy.t("combat.dawn")
	eyebrow.add_theme_color_override("font_color", PAPER_MUTED)
	card_body.add_child(eyebrow)
	card_body.move_child(eyebrow, 1)
	_body_ready(str(row.get("text", "")))
	var dead: Array = row.get("dead", [])
	var injured: Array = row.get("injured", [])
	if not dead.is_empty() or not injured.is_empty():
		_body("combat.named_losses")
		for person in dead:
			var key := "combat.dead_known" if bool(person.get("known", false)) else "combat.dead"
			_body_ready(Copy.t(key) % str(person.get("name", "")))
		for person in injured:
			_body_ready(Copy.t("combat.injured") % [str(person.get("name", "")), int(person.get("weeks", 2))])
	else:
		_body("combat.no_named")
	if bool(row.get("force", false)) and bool(row.get("win", false)):
		_body("combat.yard_felt")
		var deltas: Dictionary = row.get("deltas", {})
		var hope_d := int(deltas.get("hope", 0))
		var dis_d := int(deltas.get("discontent", 0))
		if hope_d < 0:
			_body_ready(Copy.t("combat.hope_force") % absi(hope_d))
		if dis_d > 0:
			_body_ready(Copy.t("combat.discontent_force") % dis_d)
		_body("combat.hope_known")
	if int(row.get("loyalty", -1)) >= 0:
		_body_ready("%s: %d" % [Copy.t("Loyalty"), int(row.loyalty)])
	if str(row.get("opinion_line", "")) != "":
		_body_ready(str(row.opinion_line))
	card_body.add_child(_button("Continue", _next_order_report))


func _open_combat_confirm(kind: String, sid: String) -> void:
	if game == null:
		return
	var preview: Dictionary = game.battle_preview(kind, sid)
	if not bool(preview.get("ok", false)):
		_toast(str(preview.get("why", "")))
		return
	if not _claim(ModalDeck.AMBIENT, "combat", _open_combat_confirm.bind(kind, sid)):
		return
	var title_key := "combat.confirm_raid" if kind == "raid" else "combat.confirm_assault"
	_open_card(Copy.t(title_key) % str(preview.get("place", "")))
	var win_line := _label("", 20, true)
	win_line.text = "%s  %d%%" % [Copy.t("combat.win_chance"), int(preview.get("win_pct", 0))]
	card_body.add_child(win_line)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	for mod in preview.get("mods", []):
		chips.add_child(_mod_chip(str(mod.get("id", "")), str(mod.get("label", ""))))
	if chips.get_child_count() > 0:
		card_body.add_child(chips)
	var risk := Copy.t("combat.named_risk") % int(preview.get("named_at_risk", 0))
	if int(preview.get("known_at_risk", 0)) > 0:
		risk += Copy.t("combat.known_risk") % int(preview.known_at_risk)
	_body_ready(risk)
	var moral: Dictionary = preview.get("moral", {})
	if kind == "assault":
		_body("combat.force_cost")
		_body_ready(Copy.t("combat.hope_force") % int(moral.get("hope", 3)))
		_body("combat.hope_known")
		_body_ready(Copy.t("combat.discontent_force") % int(moral.get("discontent", 8)))
		if int(moral.get("unbidden_hope", 0)) > 0:
			_body_ready(Copy.t("combat.unbidden") % int(moral.unbidden_hope))
	else:
		_body_ready(Copy.t("combat.raid_cost") % [int(moral.get("raid_discontent", 2)), int(moral.get("raid_opinion", 15))])
		_body("order.raid_detail")
	var send_key := "combat.send_raid" if kind == "raid" else "combat.send_assault"
	var send := _button(send_key, _send_combat.bind(kind, sid))
	if kind == "raid":
		_style_primary(send)
	else:
		_style_assault(send)
	card_body.add_child(send)
	card_body.add_child(_button("Back", _close_card))


func _send_combat(kind: String, sid: String) -> void:
	if game == null:
		return
	if not game.queue_order({"kind": "order", "order": kind, "dest": sid}):
		Sound.play("error")
		_toast(game.order_block(kind, sid))
		return
	var toast := Copy.t("combat.toast_sent")
	if network_view != null and network_view.has_method("_order_queue_toast"):
		toast = network_view._order_queue_toast(kind, sid, {})
	_toast(toast)
	_close_card()
	_refresh()
	if network_view != null:
		network_view.refresh()


func _mod_chip(id: String, label: String) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var brass := id == "dark" or id == "breach"
	style.bg_color = Color("3a3126")
	style.border_color = Color("e2a63a") if brass else Color("554533")
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)
	var lab := Label.new()
	lab.text = label
	lab.add_theme_color_override("font_color", Color("e2a63a") if brass else Color("554533"))
	panel.add_child(lab)
	return panel


func _style_assault(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color("a0281e")
	style.set_content_margin_all(10)
	style.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_color_override("font_color", Color("efe6d2"))


func _party_block() -> void:
	if game == null or not game.squads.has(game.player):
		return
	var info: Dictionary = game.party_roster()
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3a3126")
	style.border_color = Color("e2a63a")
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	style.set_corner_radius_all(3)
	plate.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	plate.add_child(box)
	box.add_child(_party_line(Copy.t("party.title"), 18, true))
	box.add_child(_party_line(Copy.t("party.count") % [info.members.size(), int(info.max_size)], 15, false))
	box.add_child(_party_line(Copy.t("party.empty_hint"), 14, false))
	box.add_child(_party_line(Copy.t("party.marshal_note"), 14, false))
	var locked := game._party_locked()
	if locked:
		box.add_child(_party_line(Copy.t("party.away_block"), 14, false))
	for member in info.members:
		var away := " · %s" % Copy.t("party.away") if bool(member.get("away", false)) else ""
		var text := "%s · %s %d%s" % [str(member.get("name", "")), Copy.skill("fight"), int(member.get("fight", 0)), away]
		var row := _button(text, _toggle_party.bind(str(member.get("id", ""))))
		row.custom_minimum_size.y = 44
		if locked:
			row.disabled = true
		box.add_child(row)
	for _i in int(info.get("empty_slots", 0)):
		var empty := _button("party.empty_slot", _add_party_member)
		empty.custom_minimum_size.y = 44
		if locked:
			empty.disabled = true
		box.add_child(empty)
		box.add_child(_party_line(Copy.t("party.half"), 13, false))
	var add := _button("party.add", _add_party_member)
	add.custom_minimum_size.y = 44
	if locked:
		add.disabled = true
	box.add_child(add)
	people_box.add_child(plate)


func _party_line(text: String, size: int, display: bool) -> Label:
	var lab := _label("", size, display)
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _toggle_party(person_id: String) -> void:
	if game == null:
		return
	var why := game.party_toggle(person_id)
	if why != "":
		_toast(why)
	_fill_people()
	_refresh()


func _add_party_member() -> void:
	if game == null:
		return
	var why := game.party_add_best()
	if why != "":
		_toast(why)
	_fill_people()
	_refresh()


func _breach_craft_card() -> void:
	card_body.add_child(_label("breach.section", 16, true))
	var cost := _label("", 16)
	cost.text = Copy.t("breach.cost") % game.breach_stock()
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_body.add_child(cost)
	if game.breach_stock() >= 1:
		_body("breach.held")
	var why := game.breach_craft_reason()
	var craft := _button("breach.craft", _confirm_breach)
	if why == "":
		_brass_border(craft)
	else:
		craft.disabled = true
		craft.tooltip_text = why
		_body_ready(why)
	card_body.add_child(craft)


func _confirm_breach() -> void:
	var why := "" if game == null else game.breach_craft_reason()
	_confirm("breach.confirm_title", PackedStringArray(["breach.confirm_body"]), why == "", {
		"kind": "order", "order": "breach",
	}, "breach.craft", why)


func _brass_border(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		var copy := style.duplicate() if style != null else StyleBoxFlat.new()
		if copy is StyleBoxFlat:
			copy.border_color = Color("e2a63a")
			copy.set_border_width_all(1)
			button.add_theme_stylebox_override(state, copy)
## The picture on an order's dawn card: the station's banner across the card, the councillor who carried the order
## in a gold-rimmed portrait on its lower left, and the order's map icon on a paper disc at the right. A failed
## order dims the banner. Null when the report names no station with a picture.
func _order_art(row: Dictionary) -> Control:
	var sid := str(row.get("station", ""))
	if sid == "" or not game.stations.has(sid) or network_view == null:
		return null
	var path: String = network_view.banner_path(game, sid)
	if path == "":
		return null
	var tex := ArtPack.load_texture(path)
	if tex == null:
		return null
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 170)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	var banner := TextureRect.new()
	banner.texture = tex
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not bool(row.get("ok", true)):
		banner.modulate = Color(0.55, 0.5, 0.48)
	frame.add_child(banner)
	var fade := Gradient.new()
	fade.set_color(0, Color(0, 0, 0, 0.0))
	fade.set_color(1, Color(0, 0, 0, 0.65))
	var ramp := GradientTexture2D.new()
	ramp.gradient = fade
	ramp.fill_from = Vector2(0.5, 0.35)
	ramp.fill_to = Vector2(0.5, 1.0)
	var under := TextureRect.new()
	under.texture = ramp
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	under.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(under)
	var place := _label(str(game.station_text(sid, "community")), 18, true)
	place.add_theme_color_override("font_color", Color("f4efe4"))
	place.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	place.add_theme_constant_override("shadow_offset_x", 1)
	place.add_theme_constant_override("shadow_offset_y", 2)
	place.position = Vector2(96, 136)
	frame.add_child(place)
	var pid := str(row.get("person", ""))
	if pid != "" and game.people.has(pid):
		var rim := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1e1812")
		style.border_color = Color("c9a227")
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 4
		rim.add_theme_stylebox_override("panel", style)
		rim.add_child(_portrait_box(pid, 72))
		rim.position = Vector2(10, 82)
		frame.add_child(rim)
	var kind := str(row.get("kind", ""))
	var icon := ArtPack.icon_texture(str({"move": "squad", "expedition": "squad", "address": "hope"}.get(kind, kind)), 32.0)
	if icon != null:
		var disc := PanelContainer.new()
		var paper := StyleBoxFlat.new()
		paper.bg_color = Color("efe4c8")
		paper.border_color = Color("c9a227") if bool(row.get("ok", true)) else Color("8a3a3a")
		paper.set_border_width_all(3)
		paper.set_corner_radius_all(26)
		paper.set_content_margin_all(8)
		disc.add_theme_stylebox_override("panel", paper)
		var mark := TextureRect.new()
		mark.texture = icon
		mark.custom_minimum_size = Vector2(32, 32)
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		disc.add_child(mark)
		disc.anchor_left = 1.0
		disc.anchor_right = 1.0
		disc.offset_left = -62.0
		disc.offset_right = -10.0
		disc.offset_top = 10.0
		disc.offset_bottom = 62.0
		frame.add_child(disc)
	return frame


## Leader text from data/faction_leaders.json, which carries en and ru side by side.
func _leader_text(pair) -> String:
	if pair is Dictionary:
		var out := str(pair.get("ru", "")) if Copy.ru() else ""
		return out if out != "" else str(pair.get("en", ""))
	return str(pair) if pair != null else ""


## The faction sign from disk, or the first letter of the faction's name on its color.
## The path as given, or the same name as .png; "" when neither file is there.
func _art_file(path: String) -> String:
	if path == "":
		return ""
	for candidate in [path, path.get_basename() + ".png"]:
		if ResourceLoader.exists(candidate):
			return candidate
	return ""


func _faction_mark(row: Dictionary, px: int) -> Control:
	var path := _art_file(str(row.get("symbol", "")))
	if path != "":
		var tex := ArtPack.load_texture(path)
		if tex != null:
			var sign := TextureRect.new()
			sign.texture = tex
			sign.custom_minimum_size = Vector2(px, px)
			sign.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			sign.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sign.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sign.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return sign
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(px, px)
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(str(row.get("color", "#888888")))
	style.border_color = PAPER_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(px / 2)
	plate.add_theme_stylebox_override("panel", style)
	var letter := _label(_leader_text(game.leader_name(str(row.get("id", "")), "name")).trim_prefix("The ").substr(0, 1).to_upper(), int(px * 0.55), true)
	letter.add_theme_color_override("font_color", Color("1d1a16"))
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plate.add_child(letter)
	return plate


## Leader portrait from assets/factions/<leader_id>.png with rounded corners; null when the file is not there.
func _leader_face(row: Dictionary, px: int) -> Control:
	var path := _art_file("res://assets/factions/%s.png" % str(row.get("leader_id", "")))
	if path == "":
		return null
	var tex := ArtPack.load_texture(path)
	if tex == null:
		return null
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(px, px)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(px / 8)
	frame.add_theme_stylebox_override("panel", style)
	var face := TextureRect.new()
	face.texture = tex
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(face)
	return frame


const BAND_NAMES := {"hostile": "Hostile", "cold": "Cold", "wary": "Wary", "useful": "Useful", "pact": "Pact"}
const DEAL_NAMES := {
	"burn_papers": "Burn the papers", "the_list": "The list", "stay_down": "Stay below",
	"open_books": "Open books", "lantern_toll": "Lantern toll",
}
const MARK_NAMES := {
	"collaborator": "collaborator", "buried_papers": "buried papers", "stayed_down": "stayed down",
	"open_books": "open books", "lantern_toll": "lantern toll",
}
const DEED_LINES := {
	"burn_papers": "You burned the papers.", "stay_down": "You agreed to stay below.",
	"open_books": "You let the Exchange into your books.", "lantern_toll": "You paid the lantern toll.",
	"refused": "You turned them away.", "silence": "You left them waiting.", "helped": "You brought help.",
}


func _deed_line(row: Dictionary) -> String:
	var deed := str(row.get("deed", ""))
	if deed == "the_list":
		var name := str(row.get("name_ru", "")) if Copy.ru() else ""
		if name == "":
			name = Copy.person(str(row.get("name", "")))
		return Copy.t("You handed %s to the Directorate.") % name
	if deed == "event":
		var ev: Dictionary = game._event_by_id(str(row.get("event", "")))
		for option in ev.get("choices", []):
			if str(option.get("id", "")) == str(row.get("choice", "")):
				return "%s: %s." % [Copy.t(game.line_of(ev, "title")), Copy.t(game.line_of(option, "label")).trim_suffix(".")]
		return Copy.t(game.line_of(ev, "title"))
	return Copy.t(str(DEED_LINES.get(deed, deed)))


func _show_audience() -> void:
	if not _claim(ModalDeck.NARRATIVE, "audience", _show_audience):
		return
	var fid := str(game.audience.get("faction", ""))
	var key := "%d:%s" % [int(game.audience.get("week", 0)), fid]
	if audience_key != key:
		audience_key = key
		audience_heard = false
		Sound.play("audience_open")
	var row: Dictionary = game.leader(fid)
	_open_card(_leader_text(game.leader_name(fid, "leader")), false)
	card_roomy = true
	_fit_card()
	card_body.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var face_px := 80 if audience_heard else 112
	var face := _leader_face(row, face_px)
	top.add_child(face if face != null else _faction_mark(row, face_px))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var named := HBoxContainer.new()
	named.add_theme_constant_override("separation", 8)
	if face != null:
		named.add_child(_faction_mark(row, 28))
	var title := _label("%s, %s" % [_leader_text(game.leader_name(fid, "title")), _leader_text(game.leader_name(fid, "name"))], 18, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	named.add_child(title)
	who.add_child(named)
	var stand := _label(Copy.t("Regard %s · %s") % [_signed(int(game.standing.get(fid, 0))), Copy.t(str(BAND_NAMES.get(game.standing_band(fid), "")))], 15)
	stand.add_theme_color_override("font_color", PAPER_MUTED)
	who.add_child(stand)
	top.add_child(who)
	card_body.add_child(top)
	var opening := _quoted(game.audience_opening(fid))
	var pitch := _quoted(game.leader_line(fid, "pitch")) if audience_heard else ""
	if pitch != "":
		var said := _label(pitch, 16)
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(said)
		_leader_voice(fid, "pitch", "%s:pitch" % audience_key)
		if str(row.get("dirty_deal", {}).get("id", "")) == "the_list":
			var taken := str(game.audience.get("target", ""))
			var plain := Copy.t("In plain words: he wants one of your people. There is nobody to hand over.")
			if game.people.has(taken):
				plain = Copy.t("In plain words: he takes %s. That person leaves the station. You get a curfew and one free step on the air filter.") % _resident_name(game.people[taken])
			_body(plain)
	elif opening != "":
		_body(opening)
		var opening_key: String = game.audience_opening_key(fid)
		_leader_voice(fid, opening_key, "%s:%s" % [audience_key, opening_key])
	var memory: Array = game.standing_memory.get(fid, [])
	if not memory.is_empty():
		var remembered := VBoxContainer.new()
		remembered.add_theme_constant_override("separation", 0)
		remembered.add_child(_label("They remember", 15, true))
		for i in range(memory.size() - 1, -1, -1):
			var line := _label("%s  %s" % [Copy.t("Week %d") % int(memory[i].get("week", 0)), _deed_line(memory[i])], 14)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_theme_color_override("font_color", PAPER_MUTED)
			remembered.add_child(line)
		card_body.add_child(remembered)
	var remembers_list := memory.any(func(deed): return str(deed.get("deed", "")) == "the_list")
	if game.flags.has("collaborator") and not remembers_list:
		var stain := _label(Copy.t("Known to all: you handed a person to the Directorate (week %d).") % int(game.flags.collaborator), 15)
		stain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stain.add_theme_color_override("font_color", Color("8a2f22"))
		card_body.add_child(stain)
	_choice_divider()
	if not audience_heard:
		_audience_buttons("Hear them out", _hear_audience, "Not today", "", Copy.t("No change now"))
		return
	_audience_terms(fid, row.get("dirty_deal", {}))
	var why: String = game.audience_reason()
	if why != "":
		_body(why)
	var help: Dictionary = game.help_effects()
	var offer := _leader_text(game.help_line(fid, "offer"))
	var help_why := ""
	if not help.is_empty() and offer != "":
		_heading(Copy.t("Help"))
		var cost := _label("· %s: %s. %s" % [Copy.t("Cost"), Copy.stock(int(help.amount), str(help.resource)), Copy.t("Regard %s") % _signed(int(help.standing))], 15)
		cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_body.add_child(cost)
		help_why = game.help_reason()
	var take := _audience_buttons("Take the deal", _answer_audience.bind(true), "Refuse", _deal_words(game.audience_effects()), Copy.t("No change now"))
	if why != "":
		take.disabled = true
		take.tooltip_text = why
	if not help.is_empty() and offer != "":
		var give := _button(offer, _offer_help, "confirm")
		_style_choice(give)
		give.custom_minimum_size.y = 48
		give.add_theme_font_size_override("font_size", 18)
		give.alignment = HORIZONTAL_ALIGNMENT_CENTER
		give.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		give.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var help_words: PackedStringArray = ["%s %s" % [Copy.res(str(help.resource)), _signed(-int(help.amount))]]
		help_words.append_array(_regard_words({str(game.audience.faction): int(help.standing)} if int(help.standing) != 0 else {}))
		var column := _effect_column(give, " · ".join(help_words))
		var answers := take.get_parent().get_parent()
		answers.add_child(column)
		answers.move_child(column, 1)
		if help_why != "":
			give.disabled = true
			give.tooltip_text = help_why
			_body(help_why)


## Yes and no side by side, each with its effect line under it; returns the yes button. No always turns the
## leader away.
func _audience_buttons(yes_text: String, yes: Callable, no_text: String, yes_words: String = "", no_words: String = "") -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var out: Button = null
	for pair in [[yes_text, yes, yes_words], [no_text, _answer_audience.bind(false), no_words]]:
		var button := _button(str(pair[0]), pair[1], "confirm")
		_style_choice(button)
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 18)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(_effect_column(button, str(pair[2])))
		if out == null:
			out = button
	card_body.add_child(row)
	return out


func _effect_column(button: Button, words: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_child(button)
	if words != "":
		var lab := _effect_line(words)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.custom_minimum_size.x = 60
		column.add_child(lab)
	return column


## What taking the deal moves this turn, from Game.audience_effects, in one line.
func _deal_words(fx: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in ["hope", "discontent", "food"]:
		if int(fx[key]) != 0:
			bits.append("%s %s" % [Copy.res(key), _signed(int(fx[key]))])
	bits.append_array(_regard_words(fx.standing))
	if str(fx.hand_over) != "":
		bits.append((Copy.t("Handed over: %s.") % _resident_name(game.people[str(fx.hand_over)])).trim_suffix("."))
	if str(fx.law) != "":
		bits.append((Copy.t("Enacted %s.") % Copy.t(str(game.catalog.laws[str(fx.law)].name))).trim_suffix("."))
	if not fx.tier.is_empty():
		bits.append((Copy.t("%s: %s, free.") % [_room_type_name(str(fx.tier.type)), _upgrade_name(str(fx.tier.name))]).trim_suffix("."))
	if str(fx.flag) != "":
		bits.append((Copy.t("Mark: %s.") % Copy.t(str(MARK_NAMES.get(str(fx.flag), fx.flag)))).trim_suffix("."))
	return " · ".join(bits)


## The dirty price with every number it moves, shown before the player can agree.
func _audience_terms(fid: String, deal: Dictionary) -> void:
	var deal_id := str(deal.get("id", ""))
	_heading(Copy.t(str(DEAL_NAMES.get(deal_id, deal_id))))
	var fx: Dictionary = game.audience_effects()
	var lines: PackedStringArray = []
	if int(fx.hope) != 0:
		lines.append(Copy.t("Hope %s") % _signed(int(fx.hope)))
	if int(fx.discontent) != 0:
		lines.append(Copy.t("Discontent %s") % _signed(int(fx.discontent)))
	if int(fx.food) != 0:
		lines.append(Copy.t("Food %s") % _signed(int(fx.food)))
	var parts: PackedStringArray = []
	for other in fx.standing:
		parts.append("%s %s" % [_leader_text(game.leader_name(str(other), "name")), _signed(int(fx.standing[other]))])
	if not parts.is_empty():
		lines.append(Copy.t("Regard: %s") % ", ".join(parts))
	if str(fx.hand_over) != "":
		lines.append(Copy.t("Handed over: %s.") % _resident_name(game.people[str(fx.hand_over)]))
	if str(fx.law) != "":
		lines.append(Copy.t("Enacted %s.") % Copy.t(str(game.catalog.laws[str(fx.law)].name)))
	if not fx.tier.is_empty():
		lines.append(Copy.t("%s: %s, free.") % [_room_type_name(str(fx.tier.type)), _upgrade_name(str(fx.tier.name))])
	if deal_id == "burn_papers":
		if bool(fx.papers):
			lines.append(Copy.t("One Papers clue destroyed (you hold %d).") % int(game.artifacts.get("papers", 0)))
		else:
			lines.append(Copy.t("No Papers clue found yet: only the mark is set."))
	if bool(fx.toll_lost):
		lines.append(Copy.t("Her regard is %s, below zero: she takes the toll and gives nothing back.") % _signed(int(game.standing.get(fid, 0))))
	if str(fx.flag) != "":
		lines.append(Copy.t("Mark: %s.") % Copy.t(str(MARK_NAMES.get(str(fx.flag), fx.flag))))
		if str(fx.flag) == "collaborator":
			lines.append(Copy.t("This mark never comes off."))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	for line in lines:
		var lab := _label("· " + line, 15)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(lab)
	card_body.add_child(list)


func _hear_audience() -> void:
	audience_heard = true
	_show_audience()


func _answer_audience(accept: bool) -> void:
	var snapshot := _tally_snapshot()
	var fid := str(game.audience.get("faction", ""))
	if not game.apply({"kind": "audience", "accept": accept}):
		footer.text = Copy.t("That choice did not take.")
		footer.visible = true
		return
	audience_heard = false
	var changes := _tally_changes(snapshot)
	_refresh()
	note_change(changes)
	if card != null and dim.visible:
		_fly_changes(changes, card.get_global_rect().get_center())
	_fill_people()
	_close_card()
	_show_dawn()
	var reply := _leader_said(fid, game.leader_line(fid, "accepted" if accept else "declined"))
	if reply != "":
		_toast(reply, 4.5)
		_leader_voice(fid, "accepted" if accept else "declined", "%s:reply" % audience_key)


## The honest favour: the leader answers with their help reply, unvoiced, and the audience closes.
func _offer_help() -> void:
	var snapshot := _tally_snapshot()
	var fid := str(game.audience.get("faction", ""))
	if not game.apply({"kind": "audience", "help": true}):
		footer.text = Copy.t("That choice did not take.")
		footer.visible = true
		return
	audience_heard = false
	var changes := _tally_changes(snapshot)
	_refresh()
	note_change(changes)
	if card != null and dim.visible:
		_fly_changes(changes, card.get_global_rect().get_center())
	_fill_people()
	_close_card()
	_show_dawn()
	var reply := _leader_said(fid, game.help_line(fid, "reply"))
	if reply != "":
		_toast(reply, 4.5)


## Plays lead_<faction>_<key>_<lang>.ogg for a line that has just appeared, once per `token`. A new line
## stops the previous leader line even when it has no file of its own; a missing file plays nothing.
func _leader_voice(fid: String, key: String, token: String) -> void:
	if token == leader_voiced:
		return
	leader_voiced = token
	if Voice.now_kind == "leader":
		Voice.stop()
	Voice.play(Voice.leader_row(fid, key), "")


## "Name: «line»" in Russian, "Name: “line”" in English; "" when there is no line.
func _leader_said(fid: String, pair: Dictionary) -> String:
	var line := _quoted(pair)
	if line == "":
		return ""
	return "%s: %s" % [_leader_text(game.leader_name(fid, "leader")), line]


func _quoted(pair) -> String:
	var text := _leader_text(pair).strip_edges()
	if text == "" or text == "TODO_REWRITE":
		return ""
	return ("«%s»" if Copy.ru() else "“%s”") % text


func _next_order_report() -> void:
	if game != null and not game.order_reports.is_empty():
		game.order_reports.pop_front()
	_close_card()
	_show_dawn()


func _news_count(lines: PackedStringArray) -> int:
	if news_week != game.week:
		news_week = game.week
		news_open = false
	var n := 0
	for line in lines:
		if not line.begins_with("No warning"):
			n += 1
	return n


func _urgent_line(line: String) -> bool:
	if _starts(line, ["SEASON", "PRESSURE", "WARN"]):
		return true
	if line.begins_with("ULTIMATUM"):
		for d in game.demands:
			if not bool(d.paid) and int(d.deadline) <= URGENT_WEEKS:
				return true
	return false


func _forecast_rows(within: int, beyond: int = -1) -> Array:
	var out: Array = []
	for row in game.forecasts():
		var weeks := int(row.get("weeks", 0))
		if weeks <= within and weeks > beyond:
			out.append(row)
	return out


func _alert_chips(urgent: PackedStringArray, news: int) -> void:
	var flow := _chip_flow()
	var warning: Dictionary = game.revolt_warning()
	var revolt_near := not warning.is_empty() and int(warning.get("weeks", 99)) <= URGENT_WEEKS
	if revolt_near:
		flow.add_child(_chip(str(warning.text), true, _open_forecast_at.bind(str(warning.hint), int(warning.level), int(warning.cell))))
	for row in _forecast_rows(URGENT_WEEKS):
		if revolt_near and str(row.get("key", "")) == "discontent":
			continue
		flow.add_child(_chip(str(row.text), true, _open_forecast_at.bind(str(row.hint), int(row.level), int(row.cell))))
	for line in urgent:
		var chip := _chip(_alert_text(line), true, Callable())
		chip.tooltip_text = Copy.gloss(line)
		flow.add_child(chip)
	if news > 0:
		var caption := Copy.t("Morning news (%d) ▾") % news if news_open else Copy.t("Morning news (%d) ▸") % news
		flow.add_child(_chip(caption, false, _toggle_news))
	if flow.get_child_count() > 0:
		card_body.add_child(flow)


func _alert_text(line: String) -> String:
	if line.begins_with("WARN ") and line.ends_with(" is losing its loyalty"):
		var place := line.substr(5, line.length() - 5 - " is losing its loyalty".length())
		return Copy.t("%s is losing loyalty and may flip.") % place
	var text := Copy.gloss(line)
	if line.begins_with("PRESSURE "):
		return text.replace(". ", ": ")
	var stop := text.find(". ")
	if stop > 0 and stop <= 12:
		text = text.substr(stop + 2)
	else:
		var tag := text.get_slice(" ", 0)
		if tag.length() >= 3 and tag == tag.to_upper() and tag != tag.to_lower():
			text = text.substr(tag.length() + 1)
	return text


func _far_revolt() -> void:
	var warning: Dictionary = game.revolt_warning()
	if warning.is_empty() or int(warning.get("weeks", 99)) <= URGENT_WEEKS:
		return
	var flow := _chip_flow()
	flow.add_child(_chip(str(warning.text), true, _open_forecast_at.bind(str(warning.hint), int(warning.level), int(warning.cell))))
	card_body.add_child(flow)


func _choice_divider() -> void:
	var gap := MarginContainer.new()
	gap.add_theme_constant_override("margin_top", 2)
	gap.add_theme_constant_override("margin_bottom", 2)
	var line := ColorRect.new()
	line.color = Color(PAPER_EDGE, 0.45)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.add_child(line)
	card_body.add_child(gap)


func _chip_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	return flow


func _far_revolt_count() -> int:
	var warning: Dictionary = game.revolt_warning()
	return 1 if not warning.is_empty() and int(warning.get("weeks", 99)) > URGENT_WEEKS else 0


func _chip(text: String, alert: bool, cb: Callable) -> Button:
	var full := text.strip_edges()
	var short := full
	var stop := full.find(". ")
	if stop > 0:
		short = full.substr(0, stop + 1)
	if short.length() > 46:
		short = short.substr(0, 45).strip_edges() + "…"
	var chip := Button.new()
	chip.text = ("⚠ " + short) if alert else short
	chip.tooltip_text = full
	chip.focus_mode = Control.FOCUS_NONE
	chip.custom_minimum_size = Vector2(0, 26)
	chip.add_theme_font_size_override("font_size", 14)
	if body_font != null:
		chip.add_theme_font_override("font", body_font)
	var ink := ALERT_INK if alert else PAPER_INK
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		chip.add_theme_color_override(state, ink)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.55, 0.18, 0.12, 0.10 if state != "hover" else 0.18) if alert else Color(0.24, 0.16, 0.08, 0.08 if state != "hover" else 0.16)
		face.border_color = Color(0.55, 0.18, 0.12, 0.55) if alert else Color(0.24, 0.16, 0.08, 0.45)
		face.set_border_width_all(1)
		face.set_corner_radius_all(3)
		face.content_margin_left = 8
		face.content_margin_right = 8
		face.content_margin_top = 2
		face.content_margin_bottom = 2
		chip.add_theme_stylebox_override(state, face)
	if cb.is_valid():
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.pressed.connect(cb)
	else:
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
	return chip


func _forecast_buttons(rows: Array) -> void:
	if rows.is_empty():
		return
	var flow := _chip_flow()
	for row in rows:
		flow.add_child(_chip(str(row.text), false, _open_forecast_at.bind(str(row.hint), int(row.level), int(row.cell))))
	card_body.add_child(flow)


func _toggle_news() -> void:
	news_open = not news_open
	_paint_dawn()


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


func _event_banner(ev: Dictionary) -> Control:
	var use := ArtPack.resolve_event_banner(ev)
	if use == "":
		return null
	var path := "res://assets/events/%s.webp" % use
	var tex := ArtPack.load_texture(path)
	if tex == null:
		return null
	## The art is 2.4:1, so the banner takes the card's width at that ratio and shows the whole picture.
	var wide := card_body.custom_minimum_size.x
	if wide <= 0.0:
		wide = minf(size.x - 48.0, 680.0) - 36.0
	var height := roundf(wide / 2.4)
	var plate := TextureRect.new()
	plate.texture = tex
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim: Texture2D = null
	if bool(ev.get("major", false)) and game != null and game._state_dilemma(ev):
		rim = ArtPack.dilemma_frame()
	if rim == null:
		plate.custom_minimum_size = Vector2(0, height)
		plate.set_meta("banner", true)
		return plate
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, height)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.clip_contents = true
	wrap.set_meta("banner", true)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(plate)
	var frame := TextureRect.new()
	frame.texture = rim
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(frame)
	return wrap


func _morning_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for entry in game.log:
		var w := int(entry.week)
		var text := str(entry.text)
		if w == game.week and _starts(text, ["INTENT", "SEASON", "ULTIMATUM", "PRESSURE", "No warning"]):
			lines.append(text)
		elif w == game.week - 1 and bool(entry.important) and _starts(text, ["SHORT", "ROT", "AGENT", "SEASON", "JOIN", "ULTIMATUM", "FIND", "BATTLE", "DEFECT", "REVOLT", "DEAL", "PREACH", "WARN", "TRUTH", "TESTIMONY", "LOST", "SICK", "BACK", "PUSH"]):
			lines.append(text)
	return lines


func _starts(text: String, prefixes: Array) -> bool:
	for prefix in prefixes:
		if text.begins_with(str(prefix)):
			return true
	return false


func _pick_event(event_id: String, choice_id: String) -> void:
	var before := str(game.front_event().get("id", ""))
	var choice := _choice_by_id(event_id, choice_id)
	var action := {"kind": "event", "event_id": event_id, "choice_id": choice_id}
	if choice.has("check"):
		action["person"] = str(check_picks.get(_check_key(event_id, choice_id), ""))
	var title := game.line_of(game.front_event(), "title") if not game.pending.is_empty() else ""
	var snapshot := _tally_snapshot()
	var regard_before: Dictionary = game.standing.duplicate()
	if not game.apply(action):
		footer.text = Copy.t("That choice did not take.")
		footer.visible = true
		return
	if choice.has("check") or choice.has("bet"):
		check_flash = true
	var changes := _tally_changes(snapshot)
	var regard := {}
	for fid in game.standing:
		var moved := int(game.standing[fid]) - int(regard_before.get(fid, game.standing[fid]))
		if moved != 0:
			regard[str(fid)] = moved
	_record_choice(title, game.line_of(choice, "label"), changes, regard)
	_refresh()
	note_change(changes)
	if card != null and dim.visible:
		_fly_changes(changes, card.get_global_rect().get_center())
	if check_flash:
		footer.text = _check_result_line()
		footer.visible = footer.text != ""
	if game.over != "":
		_close_card()
		_show_ending()
		return
	if not _check_voice(event_id, choice_id):
		_say(Voice.event_line(event_id, choice_id), title)
	_advance_dawn(before)


func _tally_snapshot() -> Dictionary:
	var snap := {}
	for key in STOCK_KEYS:
		snap[key] = int(game.stock.get(key, 0))
	snap["hope"] = int(game.hope)
	snap["discontent"] = int(game.discontent)
	return snap


func _tally_changes(before: Dictionary) -> Dictionary:
	var after := _tally_snapshot()
	var out := {}
	for key in after:
		var d := int(after[key]) - int(before.get(key, after[key]))
		if d != 0:
			out[key] = d
	return out


func _record_choice(title: String, label: String, changes: Dictionary, regard: Dictionary = {}) -> void:
	var keep: Array = []
	for row in game.choice_results:
		if int(row.get("week", 0)) >= game.week:
			keep.append(row)
	var row := {"week": game.week, "title": title, "label": label, "changes": changes}
	if not regard.is_empty():
		row["regard"] = regard
	keep.append(row)
	game.choice_results = keep


## "Regard: The Depot +5, Synod -3", the audience card's wording.
func _regard_text(regard: Dictionary) -> String:
	var parts: PackedStringArray = []
	for fid in regard:
		parts.append("%s %s" % [_leader_text(game.leader_name(str(fid), "name")), _signed(int(regard[fid]))])
	if parts.is_empty():
		return ""
	return Copy.t("Regard: %s") % ", ".join(parts)


func _change_text(changes: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in STOCK_KEYS + ["hope", "discontent"]:
		if not changes.has(key):
			continue
		var name := Copy.res(str(key)) if key in STOCK_KEYS else Copy.t("Hope" if key == "hope" else "Discontent")
		bits.append("%s %+d" % [name, int(changes[key])])
	if bits.is_empty():
		return Copy.t("No change to stocks.")
	return ", ".join(bits)


func _choice_tally() -> void:
	var rows: Array = []
	for row in game.choice_results:
		if int(row.get("week", 0)) == game.week:
			return
		if int(row.get("week", 0)) == game.week - 1:
			rows.append(row)
	if rows.is_empty():
		return
	var lines: PackedStringArray = []
	for row in rows:
		var label := Copy.t(str(row.get("label", ""))).trim_suffix(".")
		var moved: Dictionary = row.get("changes", {})
		var said := _change_text(moved)
		var regard := _regard_text(row.get("regard", {}))
		if regard != "":
			said = regard if moved.is_empty() else "%s, %s" % [said, regard]
		lines.append("%s: %s. %s" % [Copy.t(str(row.get("title", ""))), label, said])
	var tally := RichTextLabel.new()
	tally.bbcode_enabled = true
	tally.fit_content = true
	tally.scroll_active = false
	tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tally.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.add_theme_font_size_override("normal_font_size", 17)
	tally.add_theme_font_size_override("bold_font_size", 17)
	tally.add_theme_color_override("default_color", PAPER_INK if on_paper else INK)
	if body_font != null:
		tally.add_theme_font_override("normal_font", body_font)
	if display_font != null:
		tally.add_theme_font_override("bold_font", display_font)
	tally.text = "[b]%s:[/b] %s" % [Copy.t("Decision results"), "\n".join(lines).replace("[", "(").replace("]", ")")]
	card_body.add_child(tally)


func note_change(changes: Dictionary) -> void:
	if game == null or changes.is_empty():
		return
	if stock_tween != null:
		stock_tween.kill()
	stock_tween = create_tween()
	var any := false
	for key in changes:
		if not chips.has(str(key)):
			continue
		var d := int(changes[key])
		var target := float(int(game.stock.get(key, 0)))
		stock_shown[str(key)] = target
		chips[str(key)].delta.text = "%+d" % d
		chips[str(key)].delta.add_theme_color_override("font_color", DELTA_UP if d > 0 else DELTA_DOWN)
		stock_tween.parallel().tween_method(_set_stock_text.bind(str(key)), target - float(d), target, 0.45)
		any = true
	if not any:
		stock_tween.kill()
		stock_tween = null
		return
	delta_hold_until = Time.get_ticks_msec() + 1500


func _change_anchor(key: String) -> Vector2:
	var target: Control = null
	if chips.has(key):
		target = chips[key].icon
	elif key == "hope" and hope_label != null:
		target = hope_label
	elif key == "discontent" and dis_label != null:
		target = dis_label
	if target == null:
		return Vector2(-1, -1)
	return target.get_global_rect().get_center() - get_global_rect().position


## The first week a perk applies, its weekly number flies onto the meter once.
func _show_perk_floats() -> void:
	if game == null or game.perk_float_due.is_empty():
		return
	var due: Dictionary = game.perk_float_due.duplicate()
	game.perk_float_due = {}
	var origin := Vector2(size.x * 0.5, (hud.size.y if hud != null else 72.0) + 48.0)
	_fly_changes(due, get_global_rect().position + origin)


func _fly_changes(changes: Dictionary, from_global: Vector2) -> void:
	if Settings.reduced():
		return
	var start := from_global - get_global_rect().position
	var i := 0
	for key in STOCK_KEYS + ["hope", "discontent"]:
		if not changes.has(key):
			continue
		var goal := _change_anchor(str(key))
		if goal.x < 0.0:
			continue
		var d := int(changes[key])
		var lab := _label("%+d" % d, 32, true)
		if number_font != null:
			lab.add_theme_font_override("font", number_font)
		lab.add_theme_color_override("font_color", DELTA_UP if d > 0 else DELTA_DOWN)
		lab.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
		lab.add_theme_constant_override("outline_size", 6)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.z_index = 32
		add_child(lab)
		var origin := start + Vector2(float(i) * 54.0 - 40.0, 0.0)
		lab.position = origin
		lab.set_meta("fly_goal", goal)
		var hop := create_tween()
		hop.tween_interval(0.06 * float(i))
		hop.tween_property(lab, "position", goal - Vector2(10.0, 14.0), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		hop.tween_property(lab, "modulate:a", 0.0, 0.25)
		hop.tween_callback(lab.queue_free)
		i += 1


func _choice_by_id(event_id: String, choice_id: String) -> Dictionary:
	if game.pending.is_empty():
		return {}
	var ev: Dictionary = game.front_event()
	if str(ev.get("id", "")) != event_id:
		return {}
	for choice in ev.choices:
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _check_key(event_id: String, choice_id: String) -> String:
	return "%s:%s" % [event_id, choice_id]


func _check_block(ev: Dictionary, choice: Dictionary) -> void:
	var key := _check_key(str(ev.id), str(choice.id))
	var preview: Dictionary = game.check_preview(choice, str(check_picks.get(key, "")))
	check_picks[key] = str(preview.get("person", ""))
	var chance := int(preview.get("chance", 0))
	var odds := Copy.t("Unlikely.")
	if chance >= 60:
		odds = Copy.t("Likely.")
	elif chance >= 40:
		odds = Copy.t("Uncertain.")
	var who := Copy.person(str(preview.get("name", "")))
	_body(Copy.t("%s uses %s. %s") % [who, Copy.skill(str(preview.get("skill", ""))), odds])
	var bits: PackedStringArray = ["%s · %s %d" % [who, Copy.skill(str(preview.skill)), int(preview.get("value", 0))]]
	for row in preview.get("modifiers", []):
		var amount := int(row.get("amount", 0))
		var signed := "+%d" % amount if amount >= 0 else str(amount)
		bits.append("%s %s" % [signed, Copy.t(str(row.get("text", "")))])
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lab := _label(" · ".join(bits), 17)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(lab)
	if _check_roster().size() > 1:
		var swap := _button("Someone else", _swap_check.bind(str(ev.id), str(choice.id)))
		swap.custom_minimum_size = Vector2(0, 36)
		swap.autowrap_mode = TextServer.AUTOWRAP_OFF
		swap.alignment = HORIZONTAL_ALIGNMENT_CENTER
		swap.add_theme_font_size_override("font_size", 16)
		swap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(swap)
	card_body.add_child(line)


func _check_roster() -> Array:
	var ids: Array = []
	for person in game.residents:
		if int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		ids.append(str(person.id))
	return ids


func _swap_check(event_id: String, choice_id: String) -> void:
	var roster := _check_roster()
	if roster.size() < 2:
		return
	var key := _check_key(event_id, choice_id)
	var current := str(check_picks.get(key, ""))
	var idx := roster.find(current)
	check_picks[key] = str(roster[(idx + 1) % roster.size()])
	if deck.top_token() == "dawn":
		_paint_dawn()
	else:
		_show_dawn()


func _check_result_line() -> String:
	var last: Dictionary = game.last_check
	if last.is_empty():
		return ""
	if bool(last.get("bet", false)):
		if bool(last.get("box", false)):
			return Copy.t("Double 6. The bet wins.")
		if bool(last.get("snake", false)):
			return Copy.t("Double 1. The bet loses.")
		if bool(last.get("success", false)):
			return Copy.t("The bet wins.")
		return Copy.t("The bet loses.")
	var outcome := str(last.get("outcome", ""))
	if outcome != "":
		return outcome
	var who := Copy.person(str(last.get("name", "")))
	var skill_name := Copy.skill(str(last.get("skill", "")))
	if bool(last.get("success", false)):
		return Copy.t("%s tries %s. It holds.") % [who, skill_name]
	return Copy.t("%s tries %s. It does not hold.") % [who, skill_name]


func _show_pending() -> void:
	if not _claim(ModalDeck.AMBIENT, "pending", _show_pending):
		return
	_open_card("Pending")
	if game.white_pending.is_empty():
		_body("Nothing is waiting on a retry.")
		return
	for ev in game.white_pending:
		_body(game.line_of(ev, "title"))
		for choice in ev.get("choices", []):
			if game.choice_locked(choice):
				_body(str(choice.get("lock_reason", "")))


func _dismiss_dawn() -> void:
	var before := str(game.front_event().get("id", ""))
	if before != "":
		game.dismiss_front()
	_refresh()
	_advance_dawn(before)


func _advance_dawn(before: String) -> void:
	var mode := event_mode
	if game.pending.is_empty():
		_close_card()
		event_mode = "dawn"
		if mode == "all":
			_end_turn.call_deferred()
		else:
			_maybe_guide()
		return
	if str(game.front_event().get("id", "")) == before:
		_close_card()
		return
	if mode == "one" or (mode == "dawn" and not game.event_is_big(game.front_event())):
		## The small ones wait for the week: one per piece of work, the rest at End turn.
		_close_card()
		event_mode = "dawn"
		if mode == "dawn":
			_maybe_guide()
		return
	_show_dawn()


func _show_ending() -> void:
	if not _claim(ModalDeck.NARRATIVE, "ending", _show_ending):
		return
	_show_life_epilogue()


## The epilogue from data/endings.json on paper: the ending, a line per leader by your answer, the truth line,
## the run in numbers, then a new run or the main menu. Scrolls when it runs long.
func _epilogue(id: String) -> void:
	_open_card(game.ending_text(id, "title"), false)
	card_roomy = true
	_fit_card()
	_body(game.ending_text(id, "text"))
	_body(Copy.t("The week closes. The tunnels will remember this."))
	_heading_small("The leaders")
	for row in game.catalog.leaders.get("factions", []):
		var fid := str(row.get("id", ""))
		var slip := _slip_panel(SLIP_PAPER)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		slip.add_child(line)
		var mark := _faction_mark(game.leader(fid), 32)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(mark)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(words)
		words.add_child(_slip_label(_leader_text(game.leader_name(fid, "leader")), 16, SLIP_INK, true))
		words.add_child(_slip_label(game.leader_epilogue(fid), 15, SLIP_INK))
		card_body.add_child(slip)
	_heading_small("The truth")
	var truth := _slip_panel(SLIP_PAPER if game.truth_state() != "none" else SLIP_UNKNOWN)
	truth.add_child(_slip_label(game.truth_epilogue(), 15, SLIP_INK))
	card_body.add_child(truth)
	_heading_small("The run")
	var known := 0
	for fragment in Game.FRAGMENTS:
		if game.fragment_known(str(fragment)):
			known += 1
	var deals := game.deals_tally()
	for text in [
		Copy.t("Week %d. %s. Stations held: %d.") % [game.week, Words.count(game.residents.size(), "person", "people"), game.owned_count()],
		Copy.t("Hope %d. Discontent %d.") % [game.hope, game.discontent],
		Copy.t("Truth fragments known: %d of %d, with proof %d.") % [known, Game.FRAGMENTS.size(), game.honest_fragments()],
		Copy.t("Stories heard: %d of %d.") % [game.stories_heard(), Voice.of_type("story").size()],
		Copy.t("Deals made: %d. Deals refused: %d.") % [int(deals.made), int(deals.refused)],
	]:
		var lab := _label(text, 16)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.add_theme_color_override("font_color", PAPER_MUTED)
		card_body.add_child(lab)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	for pair in [["New run", _new_run], ["Main menu", _back_to_menu]]:
		var button := _button(str(pair[0]), pair[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		buttons.add_child(button)
	card_body.add_child(buttons)
	card_scroll.scroll_vertical = 0
	card_scroll.set_deferred("scroll_vertical", 0)


func _heading_small(text: String) -> void:
	var lab := _label(text, 19, true)
	card_body.add_child(lab)


func _new_run() -> void:
	_close_card()
	_begin_new_game(true)


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


func _choice_button(label: String, _choice: Dictionary, cb: Callable) -> Button:
	var button := _button(label, cb, "confirm")
	_style_choice(button)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 18)
	return button


## One line in plain words of what a choice changes right now, from Game.choice_effects: "Power -2 · Hope -1".
func _choice_words(fx: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key in ["food", "air", "power", "materials", "tokens", "influence"]:
		if fx.stock.has(key):
			bits.append("%s %s" % [Copy.res(key), _signed(int(fx.stock[key]))])
	for key in ["hope", "discontent"]:
		if int(fx[key]) != 0:
			bits.append("%s %s" % [Copy.res(key), _signed(int(fx[key]))])
	if int(fx.people) != 0:
		bits.append("%s %s" % [Copy.t("People"), _signed(int(fx.people))])
	if int(fx.sick) != 0:
		bits.append("%s %s" % [Copy.t("Sick people"), _signed(int(fx.sick))])
	if int(fx.papers) != 0:
		bits.append("%s %s" % [Copy.t("Papers"), _signed(int(fx.papers))])
	bits.append_array(_regard_words(fx.standing))
	if bool(fx.check):
		bits.append(Copy.t("The rest depends on the check"))
	return " · ".join(bits)


func _regard_words(shifts: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = []
	for fid in shifts:
		parts.append("%s %s" % [_leader_text(game.leader_name(str(fid), "name")), _signed(int(shifts[fid]))])
	if parts.is_empty():
		return PackedStringArray()
	return PackedStringArray([Copy.t("Regard: %s") % ", ".join(parts)])


## The effect line under a choice, audience or order button.
func _effect_line(text: String) -> Label:
	var lab := _label(text, 15)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_color_override("font_color", PAPER_MUTED)
	lab.set_meta("effect_line", true)
	return lab

func _choice_bits(choice: Dictionary) -> String:
	var bits: PackedStringArray = []
	if choice.has("cost"):
		for key in choice.cost:
			bits.append("%s %s" % [str(choice.cost[key]), str(key)])
	for key in ["food", "air", "power", "materials", "tokens", "influence", "hope", "discontent"]:
		if choice.has(key):
			bits.append("%s %+d" % [key, int(choice[key])])
	return ", ".join(bits)


func _confirm(heading: String, lines: PackedStringArray, ok: bool, action: Dictionary, verb: String = "Confirm", reason: String = "", muted: PackedStringArray = PackedStringArray()) -> void:
	if not _claim(ModalDeck.AMBIENT, "confirm", _confirm.bind(heading, lines, ok, action, verb, reason, muted)):
		return
	if str(action.get("kind", "")) == "build" and yard != null:
		yard.place_lock = true
		yard.show_place(str(action.get("type", "")), int(action.get("level", -1)), int(action.get("cell", -1)))
	_open_card(heading)
	var shown := lines
	var why := reason
	var ready := ok and not action.is_empty()
	if not ready and why == "" and lines.size() > 0:
		why = str(lines[lines.size() - 1])
		shown = lines.slice(0, lines.size() - 1)
	for line in shown:
		_body(Copy.gloss(line))
	for line in muted:
		_body_muted(line)
	if ready:
		card_body.add_child(_button(verb, _do_confirm.bind(action), ""))
	else:
		_blocked_pair(verb, why)
	card_body.add_child(_button("Back", _close_card))


func _do_confirm(action: Dictionary) -> void:
	var pulled := ""
	if str(action.get("kind", "")) == "demolish":
		var gone = game._room(str(action.get("room", "")))
		if gone != null:
			pulled = Copy.t(str(game.catalog.rooms[str(gone.type)].name))
	if action.is_empty() or not game.apply(action):
		Sound.play("error")
		footer.text = Copy.t("That did not happen.")
		footer.visible = true
		_close_card()
		_refresh()
		return
	var kind := str(action.get("kind", ""))
	if kind == "dig":
		Sound.play("dig")
	else:
		Sound.play("confirm")
	if kind == "push":
		var pushed = game._room(str(action.get("room", "")))
		if pushed != null:
			var room_name := Copy.t(str(game.catalog.rooms[str(pushed.type)].name))
			_toast(Copy.t("push.toast_ok").replace("{room}", room_name), 3.2)
	_close_card()
	_refresh()
	if pulled != "":
		_toast(Copy.fill("station.toast_demolish", {"room": pulled}))
	_action_voice(kind, str(action.get("law", "")))


func _claim(priority: int, token: String, restore: Callable) -> bool:
	if priority == ModalDeck.AMBIENT:
		ambient_restore = restore
	deck.push(priority, token)
	return deck.top_token() == token


## tag: a small word in front of the title saying what kind of card this is ("Event").
func _open_card(heading: String, with_close: bool = true, tag: String = "") -> void:
	_show_ahead(false)
	if room_open != "":
		room_open = ""
		_sync_room_sound()
	on_paper = true
	card_roomy = false
	_wipe(card_body)
	card_body.add_theme_constant_override("separation", 6)
	dim.visible = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if tag != "":
		row.add_child(_card_tag(tag))
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


func _card_tag(text: String) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.89, 0.65, 0.23, 0.16)
	face.border_color = Color("e2a63a")
	face.set_border_width_all(1)
	face.set_corner_radius_all(3)
	face.content_margin_left = 8
	face.content_margin_right = 8
	face.content_margin_top = 2
	face.content_margin_bottom = 2
	plate.add_theme_stylebox_override("panel", face)
	var word := _label(text, 14, true)
	word.add_theme_color_override("font_color", Color("f0c070"))
	plate.add_child(word)
	plate.set_meta("card_tag", text)
	return plate


## One plain line on what a room is for, from rooms.json.
func room_what(type: String) -> String:
	var defin: Dictionary = game.catalog.rooms.get(type, {})
	var pair = defin.get("what", {})
	if not (pair is Dictionary):
		return ""
	var out := str(pair.get("ru", "")) if Copy.ru() else ""
	return out if out != "" else str(pair.get("en", ""))


func _help_line(type: String, open: bool) -> Label:
	var line := _effect_line(room_what(type))
	line.remove_meta("effect_line")
	line.set_meta("room_what", type)
	line.visible = open
	return line


## Hover shows the line as a tooltip; a click or tap unfolds it in the card.
func _help_badge(type: String, line: Label) -> Button:
	var badge := Button.new()
	badge.text = "?"
	badge.custom_minimum_size = Vector2(28, 28)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	badge.focus_mode = Control.FOCUS_NONE
	badge.tooltip_text = room_what(type)
	badge.mouse_default_cursor_shape = Control.CURSOR_HELP
	badge.add_theme_font_size_override("font_size", 16)
	if display_font != null:
		badge.add_theme_font_override("font", display_font)
	for state in ["normal", "hover", "pressed", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.89, 0.65, 0.23, 0.34 if state == "hover" else 0.16)
		face.border_color = Color("e2a63a")
		face.set_border_width_all(1)
		face.set_corner_radius_all(14)
		face.set_content_margin_all(0)
		badge.add_theme_stylebox_override(state, face)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		badge.add_theme_color_override(key, Color("f0c070"))
	badge.set_meta("room_help", type)
	badge.pressed.connect(func() -> void:
		line.visible = not line.visible
		_fit_card()
	)
	return badge


func _close_card() -> void:
	if deck.top_token() == "raid_share" and game != null and game.raid_share_open():
		_pick_raid_share("stockpile")
		return
	if yard != null:
		yard.place_lock = false
		yard.clear_place()
	_clear_block_glow()
	if Voice.now_kind == "leader":
		Voice.stop()
	var token := deck.top_token()
	if token == "dawn":
		if event_mode == "one" and game != null and not game.pending.is_empty():
			_snoozed["%d:%s" % [game.week, str(game.front_event().get("id", ""))]] = true
		event_mode = "dawn"
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
	if room_open != "":
		room_open = ""
		_sync_room_sound()
	_try_home_float()


func _yard_hover(level: int, cell: int) -> void:
	var type := ""
	if game != null and level >= 0:
		var spot: Dictionary = game.cells.get("%d:%d" % [level, cell], {})
		var room = game._room(str(spot.get("room", "")))
		if room != null:
			type = str(room.type)
	if type == room_hover:
		return
	room_hover = type
	_sync_room_sound()


func _sync_room_sound() -> void:
	if at_menu or showing_network or shot_mode:
		Sound.room("", false)
		return
	var type := room_open if room_open != "" else room_hover
	Sound.room(type, type == room_open)


func _heading(text: String) -> void:
	card_body.add_child(_label(text, 26, true))


func _body(text: String) -> void:
	var lab := _label(text, 17)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.add_child(lab)


func _body_muted(text: String) -> void:
	var lab := _label(text, 15)
	lab.add_theme_color_override("font_color", PAPER_MUTED)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.add_child(lab)


func _body_ready(text: String) -> void:
	var lab := _label("", 17)
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_body.add_child(lab)


func _label(text: String, size: int, display: bool = false, translate: bool = true) -> Label:
	var lab := Label.new()
	lab.text = Copy.t(text) if translate else text
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
	button.set_meta("ui_sound", sound)
	button.pressed.connect(_card_press.bind(button, cb) if on_paper else _plain_press.bind(button, cb))
	return button


func _plain_press(button: Button, cb: Callable) -> void:
	_ui_pressed(button)
	cb.call()


## The second click of a double click lands on whatever the rebuilt card put under the cursor; it is dropped.
func _card_press(button: Button, cb: Callable) -> void:
	if Time.get_ticks_msec() < card_click_guard:
		return
	card_click_guard = Time.get_ticks_msec() + CARD_CLICK_GUARD_MS
	_ui_pressed(button)
	cb.call()


func _ui_pressed(button: Button) -> void:
	if button.disabled:
		return
	Sound.play(str(button.get_meta("ui_sound", "click")))


## Called by the network map for a station pick or a zoom button.
func _ui_click() -> void:
	Sound.play("map_click")


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


## End turn when nothing is waiting: the same brass with a pale rim and a soft glow.
func _brass_ready() -> StyleBoxFlat:
	var style := _brass_style(false)
	style.border_color = Color("fff0c8")
	style.shadow_color = Color(1.0, 0.8, 0.38, 0.5)
	style.shadow_size = 10
	return style


func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER_EDGE
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(2)
	return style


## Marks the room an event happens in (its requires_room) for this week; nothing when the data names none.
func note_incident(ev: Dictionary) -> void:
	var type := str(ev.get("requires_room", ""))
	if type == "" or game == null or not game.catalog.rooms.has(type):
		return
	incident_rooms[type] = "%d:%d" % [game.get_instance_id(), game.week]
	if yard != null:
		yard.queue_redraw()


func incident_on(type: String) -> bool:
	return game != null and str(incident_rooms.get(type, "")) == "%d:%d" % [game.get_instance_id(), game.week]


## The modal card (events, rooms, the build list): a shade lighter than the paper with a stronger gold edge.
func _card_style() -> StyleBoxFlat:
	var style := _paper_style()
	style.bg_color = CARD_PAPER
	style.border_color = CARD_EDGE
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	return style


func _column_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.035)
	style.border_color = Color(PAPER_EDGE, 0.35)
	style.set_border_width_all(1)
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
	if not game.clear.is_empty():
		return Copy.t("clear.busy")
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
	row.add_child(_room_icon(type, 48))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	var title := _label(Copy.t(str(defin.name)), 18, true)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	text.add_child(head)
	if room_what(type) != "":
		var line := _help_line(type, false)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(_help_badge(type, line))
		text.add_child(line)
	text.add_child(_makes_line(type, defin))
	text.add_child(_cost_line(info, defin, building))
	if type == "listening_post" and str(info.get("reason", "")) != "":
		var why := _label("", 14)
		why.text = str(info.reason)
		why.mouse_filter = Control.MOUSE_FILTER_IGNORE
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(why)
	if not enabled:
		var lock := Glyph.new()
		lock.kind = "lock"
		lock.ink = PAPER_INK
		lock.custom_minimum_size = Vector2(16, 16)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_END
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(lock)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(text)
	panel.add_child(row)
	if yard != null:
		panel.mouse_entered.connect(func() -> void:
			if yard.place_lock:
				return
			yard.show_place(type, level, cell)
		)
		panel.mouse_exited.connect(func() -> void:
			if yard.place_lock:
				return
			yard.clear_place()
		)
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
		row.add_child(_mini_glyph(key, 20))
		var text := Copy.t("+%d / wk") % span.x
		if span.x != span.y:
			text = Copy.t("+%d…%d / wk") % [span.x, span.y]
		var lab := _label(text, 16)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lab)
		if type == "platform":
			var beds := _label(Copy.t("Housing %d") % int(defin.get("housing", 0)), 16)
			beds.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(beds)
		elif type == "radio":
			var hears := _label(Copy.t("Reveals intents"), 16)
			hears.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(hears)
		return row
	var words := ""
	var glyph := ""
	if type == "quarters" or type == "platform":
		words = Copy.t("Housing %d") % int(defin.get("housing", 0))
		glyph = "people"
	elif type == "meeting_hall":
		words = Copy.t("Laws")
		glyph = "influence"
	elif type == "radio":
		words = Copy.t("2 tokens a week. Reveals intents.")
	elif type == "listening_post":
		words = "listening.desc"
		glyph = "listen"
	elif type == "infirmary":
		words = Copy.t("Clears sickness")
		glyph = "quarantine"
	if glyph != "":
		row.add_child(_mini_glyph(glyph, 20))
	var lab := _label(words, 16)
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
	var icon := _mini_glyph(kind, 20)
	icon.ink = ink
	row.add_child(icon)
	var lab := _label(text, 16)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", ink)
	row.add_child(lab)


func _dot() -> Label:
	var lab := _label("·", 16)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", PAPER_MUTED)
	return lab


func _mini_glyph(kind: String, px: int = 16) -> Glyph:
	var icon := Glyph.new()
	icon.kind = kind
	icon.ink = PAPER_INK if on_paper else INK
	icon.custom_minimum_size = Vector2(px, px)
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
	var uid_name := str(info.get("name", ""))
	var uname := _upgrade_name(uid_name)
	if uname != "" and room != null:
		var title := _label(Copy.t("Tier %s: %s") % [roman(int(room.upgrade) + 1), uname], 18, true)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.set_meta("upgrade_title", int(room.upgrade) + 1)
		text.add_child(title)
	if _upgrade_what(uid_name) != "":
		var what := _label(_upgrade_what(uid_name), 14)
		what.mouse_filter = Control.MOUSE_FILTER_IGNORE
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(what)
	var gains: Array = upgrade_gains(uid) if uname != "" else []
	var moved := false
	for gain in gains:
		if int(gain.after) == int(gain.before):
			continue
		moved = true
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 4)
		line.add_child(_mini_glyph(str(gain.key)))
		var nums := _label(Copy.t("%s %+d -> %+d a week") % [Copy.res(str(gain.key)), int(gain.before), int(gain.after)], 15, true)
		nums.mouse_filter = Control.MOUSE_FILTER_IGNORE
		nums.add_theme_color_override("font_color", DELTA_UP)
		nums.set_meta("upgrade_gain", gain)
		line.add_child(nums)
		text.add_child(line)
	if not gains.is_empty():
		var pct := _label(Copy.t("You get: +%d%% of the base output.") % int(gains[0].pct), 14)
		pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(pct)
	if not moved and uname != "" and upgrade_fx_words(uid_name).is_empty():
		var stay := _label("the weekly numbers stay", 14)
		stay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(stay)
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
	cost_n.set_meta("upgrade_cost", int(info.get("materials", 0)))
	cost.add_child(cost_n)
	if uname != "":
		text.add_child(cost)
	else:
		cost.free()
	if not enabled and not embedded:
		var why := _label(str(info.get("reason", "")), 13)
		why.mouse_filter = Control.MOUSE_FILTER_IGNORE
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		if int(row.delta) <= 0:
			return Copy.t("No extra this week")
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
				return room_title(room)
	return ""


func _show_menu() -> void:
	if not _claim(ModalDeck.AMBIENT, "menu", _show_menu):
		return
	_open_card("Menu")
	var load_button := _button("Load", _manual_load)
	load_button.disabled = not SaveGame.has_manual()
	if load_button.disabled:
		load_button.tooltip_text = Copy.t("No saved game.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for button in [_button("Save", _manual_save), load_button, _button("Settings", _open_settings.bind(true)),
			_button("Journal  (J)", _show_journal), _button("Guide", _replay_guide), _button("How to play", _show_howto.bind(false)),
			_button("Main menu", _back_to_menu), _button("Close", _close_card)]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	card_body.add_child(grid)
	card_body.add_child(_log_row(true))
	var version := _label(BuildInfo.line(), 13)
	version.add_theme_color_override("font_color", PAPER_MUTED)
	card_body.add_child(version)


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
	guide_skips = 0
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
	if guide_step >= _guide_lines().size():
		_skip_guide()
		return
	_fill_guide()


func _guide_lines() -> PackedStringArray:
	return PackedStringArray([
		"Stocks sit up here. Tap one to see where it comes from.",
		"Dig a rock cell that touches an open floor.",
		"Build Quarters on a dug floor.",
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
	if guide_step == 2:
		guide_copy.text = "%s. %s" % [game.crowd_line(), Copy.t(lines[guide_step])]
	else:
		guide_copy.text = Copy.t(lines[guide_step])
	guide_count.text = "%d / %d" % [guide_step + 1, lines.size()]
	guide_next.text = Copy.t("Done") if guide_step >= lines.size() - 1 else Copy.t("Next")
	if guide_step == 4:
		drawer_open = true
		people_filter = "free"
		_fill_people()
		_place_drawer()
	_keep_guide_on_screen()


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


func _keep_guide_on_screen() -> void:
	if guide_step < 0:
		return
	var view := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	if net_guide and network_view != null:
		network_view.focus_station(net_guide_sid)
		var aimed := _guide_target()
		if aimed.size.x < 2.0 or not view.intersects(aimed):
			_skip_guide()
		return
	if guide_step >= 1 and guide_step <= 3 and yard != null:
		var cell := Vector2i(-1, -1)
		match guide_step:
			1:
				cell = _guide_cell(false)
			2:
				cell = _quarters_cell()
			3:
				cell = _first_open_floor()
		if cell.x >= 0:
			yard.nudge_into_view(cell.x, cell.y)
	var target := _guide_target()
	if target.size.x >= 2.0 and view.intersects(target):
		guide_skips = 0
		return
	if guide_skips > 6:
		_skip_guide()
		return
	guide_skips += 1
	_advance_guide()


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
			var beds := _quarters_cell()
			if yard != null:
				return yard.cell_screen(beds.x, beds.y)
		3:
			var floor := _first_open_floor()
			if yard != null:
				return yard.cell_screen(floor.x, floor.y)
		4:
			if people_button != null:
				return _control_rect(people_button)
		5:
			if end_button != null:
				return _control_rect(end_button)
	return Rect2()


func _control_rect(node: Control) -> Rect2:
	var g := node.get_global_rect()
	var origin := get_global_rect().position
	return Rect2(g.position - origin, g.size)


func _quarters_cell() -> Vector2i:
	for room in game.rooms:
		if str(room.type) == "quarters":
			return Vector2i(int(room.level), int(room.cell))
	return _first_open_floor()


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


func _resident_name(person: Dictionary) -> String:
	if Copy.ru() and str(person.get("name_ru", "")) != "":
		return str(person.name_ru)
	return Copy.person(str(person.get("name", "")))


func _dossier_line(person: Dictionary, key: String) -> String:
	var dossier: Dictionary = person.get("dossier", {})
	if dossier.is_empty():
		return ""
	return game.line_of(dossier, key)


## Profession before the Silence: the Coney cast's from their dossier, everyone else's from the profile.
func _person_title(person: Dictionary) -> String:
	var title := _dossier_line(person, "title")
	return title if title != "" else game.profile_line(person, "title")


func _show_person(person_id: String) -> void:
	if not game.people.has(person_id):
		return
	if not _claim(ModalDeck.AMBIENT, "person", _show_person.bind(person_id)):
		return
	var person: Dictionary = game.people[person_id]
	_open_card(_resident_name(person))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_portrait_box(person_id, 64))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _person_title(person)
	if title != "":
		text.add_child(_label(title, 14))
	text.add_child(_label(_skill_line(person), 14))
	text.add_child(_label(_check_line(person), 14))
	var traits := Copy.trait_list(person.get("traits", []))
	if traits != "":
		text.add_child(_label(traits, 14))
	text.add_child(_label(_where(person_id), 14))
	row.add_child(text)
	card_body.add_child(row)
	if bool(person.get("core", false)) or not _story(person_id).is_empty():
		var lore_id := game.cast_id_of(person)
		var caption := Copy.t("Dossier")
		if Lore.has(lore_id):
			caption = Copy.t("Dossier  ·  read %d/%d") % [Lore.read_count(lore_id), Lore.sections(lore_id).size()]
		if _story_state(person_id) == "new":
			caption += " •"
		card_body.add_child(_button(caption, _open_dossier.bind(person_id), "dossier_open"))
	card_body.add_child(_button("Close", _close_card))


func _open_dossier(person_id: String) -> void:
	dossier_tab = "profile"
	var row := _story(person_id)
	var id := str(row.get("id", ""))
	if Voice.has_audio(row) and not game.vo_heard.has(id) and not shot_mode:
		game.vo_heard[id] = "started"
		_play_story(person_id, false)
	_show_dossier(person_id)


func _story(person_id: String) -> Dictionary:
	if not game.people.has(person_id):
		return {}
	return Voice.story(game.cast_id_of(game.people[person_id]))


func _story_id(person_id: String) -> String:
	return str(_story(person_id).get("id", ""))


## "" when the resident has no recorded story, else "new" until it has played to the end, then "heard".
## vo_heard holds "started" while the first listen is under way; true (also in older saves) means heard.
func _story_state(person_id: String) -> String:
	var row := _story(person_id)
	if not Voice.has_audio(row):
		return ""
	var mark = game.vo_heard.get(str(row.id), null)
	return "heard" if mark is bool and mark else "new"


func _stories_heard() -> Vector2i:
	var out := Vector2i.ZERO
	for person in game.residents:
		var state := _story_state(str(person.id))
		if state == "":
			continue
		out.y += 1
		if state == "heard":
			out.x += 1
	return out


func _finish_story(person_id: String) -> void:
	if vo_story_progress < 0.9:
		return
	if game.hear_story(_story_id(person_id)) > 0:
		_toast(Copy.t("Testimony gathered"), 2.6)
	_fill_people()


func _play_story(person_id: String, redraw := true) -> void:
	var caption := Copy.t("%s: story") % _resident_name(game.people[person_id])
	if Voice.play(_story(person_id), caption) > 0.0:
		vo_dossier = person_id
		vo_story_progress = 0.0
	if redraw:
		_show_dossier(person_id)


func _stop_story(person_id: String) -> void:
	vo_story_progress = maxf(vo_story_progress, Voice.progress())
	Voice.fade(0.3)
	vo_dossier = ""
	_finish_story(person_id)
	_show_dossier(person_id)


func _story_buttons(person_id: String) -> void:
	var row := _story(person_id)
	if not Voice.has_audio(row):
		return
	if Voice.playing(str(row.id)):
		card_body.add_child(_button("Stop story", _stop_story.bind(person_id), "click"))
	elif _story_state(person_id) == "heard":
		card_body.add_child(_button("Replay story", _play_story.bind(person_id), "click"))
	else:
		card_body.add_child(_button("Play story", _play_story.bind(person_id), "click"))


func _story_text(person_id: String) -> void:
	var text := Voice.text(_story(person_id))
	if text == "":
		return
	_heading("In their words")
	if _story_state(person_id) == "new":
		if Voice.playing(_story_id(person_id)):
			_placeholder("", "Listening. The words appear here once the story ends.")
		else:
			_placeholder("", "Listen to the story first. The words appear here once it ends.")
		return
	for para in text.split("\n\n"):
		_body(para)


func _pick_dossier_tab(person_id: String, tab: String) -> void:
	dossier_tab = tab
	_show_dossier(person_id)


func _dossier_tabs(person_id: String, lore_id: String) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var tabs: Array = ["profile"]
	tabs.append_array(Lore.sections(lore_id))
	for tab in tabs:
		var caption := Copy.t("Profile") if tab == "profile" else Copy.t(str(Lore.TITLES[tab]))
		if tab != "profile" and not Lore.is_read(lore_id, str(tab)):
			caption += " •"
		var button := _button(caption, _pick_dossier_tab.bind(person_id, str(tab)), "dossier_tab")
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(0, 40)
		button.add_theme_font_size_override("font_size", 17)
		if tab == dossier_tab:
			_style_primary(button)
		flow.add_child(button)
	card_body.add_child(flow)


func _lore_progress(lore_id: String) -> void:
	var done := Lore.read_count(lore_id)
	var count := Lore.sections(lore_id).size()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var lab := _label(Copy.t("Backstory read %d/%d") % [done, count], 15)
	lab.add_theme_color_override("font_color", PAPER_MUTED)
	row.add_child(lab)
	row.add_child(_progress_bar(float(done) / float(maxi(count, 1)), 140.0))
	var all_done := Lore.read_total()
	var all_count := Lore.total()
	var pct := int(round(100.0 * float(all_done) / float(maxi(all_count, 1))))
	var whole := _label(Copy.t("All residents %d%%") % pct, 15)
	whole.add_theme_color_override("font_color", Color("e2a63a") if pct >= 100 else PAPER_MUTED)
	whole.tooltip_text = Copy.t("%d of %d backstory pages read") % [all_done, all_count]
	whole.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(whole)
	card_body.add_child(row)


func _progress_bar(fraction: float, width: float) -> Control:
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.14)
	track.custom_minimum_size = Vector2(width, 8)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = Color("e2a63a")
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = clampf(fraction, 0.0, 1.0)
	fill.offset_right = 0.0
	track.add_child(fill)
	return track


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
	var who := _label(_resident_name(person), 22, true)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	card_body.add_child(row)
	var title := _person_title(person)
	if title != "":
		card_body.add_child(_label(title, 16))
	card_body.add_child(_label(_check_line(person), 15))
	_story_buttons(person_id)
	var lore_id := game.cast_id_of(person)
	var has_lore := Lore.has(lore_id)
	if not has_lore:
		_story_text(person_id)
	if has_lore:
		if dossier_tab != "profile" and not Lore.sections(lore_id).has(dossier_tab):
			dossier_tab = "profile"
		if dossier_tab != "profile":
			Lore.mark(lore_id, dossier_tab)
		_dossier_tabs(person_id, lore_id)
		_lore_progress(lore_id)
	if has_lore and dossier_tab != "profile":
		_heading(str(Lore.TITLES[dossier_tab]))
		_placeholder(Lore.text(lore_id, dossier_tab), "Not written yet.")
	elif person.has("dossier"):
		_section("Look", _dossier_line(person, "look"))
		_section("Bio", _dossier_line(person, "bio"))
		_section("Hook", _dossier_line(person, "hook"))
	else:
		_section("Before the Silence", game.profile_line(person, "before"))
		_section("Keepsake", game.profile_line(person, "keepsake"))
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
	if has_lore and dossier_tab == "profile":
		_story_text(person_id)
	card_body.add_child(_button("Back", _show_person.bind(person_id)))


## A dossier section that is left out when it has no text.
func _section(caption: String, value: String) -> void:
	if value.strip_edges() == "":
		return
	_heading(caption)
	_placeholder(value, "")


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
	if str(game.capital_id) in ["coney", "southdepot"] and str(game.player) == "depot":
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
	await _settle(_shot_size())
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
	await _settle(_shot_size())
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
	await _settle(_shot_size())
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
	await _settle(_shot_size())
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


func _shot_size() -> Vector2i:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--size="):
			var bits := str(arg).trim_prefix("--size=").split("x")
			if bits.size() == 2 and int(bits[0]) >= 320 and int(bits[1]) >= 240:
				return Vector2i(int(bits[0]), int(bits[1]))
	return Vector2i(1280, 720)


func _settle(window_size: Vector2i) -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.content_scale_factor = 1.0
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = window_size
	win.mode = Window.MODE_WINDOWED
	win.size = window_size
	get_tree().root.size = window_size
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
	card.scale = Vector2(0.93, 0.93)
	card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
	modal_tween = create_tween()
	modal_tween.tween_property(dim, "modulate:a", 1.0, 0.2)
	modal_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.18)
	modal_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	modal_tween.tween_property(dim, "modulate:a", 0.0, 0.16)
	modal_tween.parallel().tween_property(card, "modulate:a", 0.0, 0.12)
	modal_tween.parallel().tween_property(card, "scale", Vector2(0.97, 0.97), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	modal_tween.finished.connect(_finish_hide_modal)


func _finish_hide_modal() -> void:
	if modal_open or dim == null:
		return
	dim.visible = false
	dim.modulate.a = 1.0
	if card != null:
		card.scale = Vector2.ONE
		card.modulate.a = 1.0


func _check_shots() -> void:
	shot_mode = true
	hold_dawn = false
	at_menu = false
	await _settle(_shot_size())
	_close_card()
	if guide_layer != null:
		guide_layer.visible = false
	_offer_shot("queens_expedition")
	await _frame()
	await _frame()
	_save("check_card_white")
	_close_card()
	game.week = 8
	_offer_shot("showtime_betting")
	await _frame()
	await _frame()
	_save("check_card_red")
	_close_card()
	_show_person("kim")
	await _frame()
	await _frame()
	_save("resident_card_bait")
	_close_card()
	game.pending.clear()
	hold_dawn = true
	var waiting: Dictionary = game._copy(game._event_by_id("moles_vents"))
	waiting.choices[1].locked = true
	waiting.choices[1].lock_reason = "Retry after: A resident with Senses 2"
	game.white_pending = [waiting]
	_refresh()
	_show_pending()
	await _frame()
	await _frame()
	_save("pending_list")
	get_tree().quit(0)


func _ux_shots() -> void:
	shot_mode = true
	hold_dawn = false
	at_menu = false
	await _settle(_shot_size())
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	game.pending.clear()
	_refresh()
	var started := false
	var types: Array = game.catalog.rooms.keys()
	types.sort_custom(func(a, b) -> bool:
		return int(game.catalog.rooms[a].get("staff_max", 0)) > int(game.catalog.rooms[b].get("staff_max", 0)))
	for type in types:
		if started or not game.build_possible(str(type)):
			continue
		for level in 3:
			for cell in 6:
				if started:
					break
				var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
				if not bool(spot.get("dug", false)) or str(spot.get("room", "")) != "":
					continue
				started = game.apply({"kind": "build", "type": str(type), "level": level, "cell": cell})
	print("UX build started %s %s" % [started, str(game.build)])
	_refresh()
	await _frame()
	await _frame()
	_save("build_timer")
	Settings.people_free_only = true
	_open_people_for("")
	await _frame()
	await _frame()
	_save("people_free_only")
	Settings.people_free_only = false
	_fill_people()
	await _frame()
	await _frame()
	_save("people_all")
	drawer_open = false
	_place_drawer()
	var pick := _ux_choice()
	if not pick.is_empty():
		_offer_shot(str(pick.event))
		await _frame()
		await _frame()
		_pick_event(str(pick.event), str(pick.choice))
		await get_tree().create_timer(0.3).timeout
		await _frame()
		_save("choice_fly")
		await get_tree().create_timer(1.2).timeout
	game.pending.clear()
	_close_card()
	_end_turn()
	await _frame()
	await _frame()
	_save("dawn_tally")
	_close_card()
	var guard := 0
	while not game.build.is_empty() and guard < 6 and game.over == "":
		guard += 1
		game.pending.clear()
		_end_turn()
		_close_card()
	await _frame()
	await _frame()
	_save("room_staffed")
	_hide_undo_toast()
	game.pending.clear()
	_close_card()
	await _ux_map_tips()
	await _ux_card_fit()
	get_tree().quit(0)


func _ux_choice() -> Dictionary:
	var best := {}
	var best_n := 0
	for ev in game.catalog.events:
		if ev.has("check_event") or str(ev.get("kind", "")) == "check":
			continue
		for choice in ev.get("choices", []):
			if choice.has("check") or choice.has("bet") or choice.has("cost"):
				continue
			var n := 0
			var stock_hits := 0
			for key in STOCK_KEYS:
				if choice.has(key):
					n += 1
					stock_hits += 1
			for key in ["hope", "discontent"]:
				if choice.has(key):
					n += 1
			if stock_hits > 0 and n > best_n:
				best_n = n
				best = {"event": str(ev.id), "choice": str(choice.id)}
	print("UX choice %s" % str(best))
	return best


func _ux_order_button(kind: String) -> Button:
	if network_view == null or network_view._sheet_body == null:
		return null
	var stack: Array = [network_view._sheet_body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and node.has_meta("order_kind") and str(node.get_meta("order_kind")) == kind:
			if not node.is_visible_in_tree():
				for toggle in network_view._sheet_body.find_children("*", "Button", true, false):
					if toggle.has_meta("details_toggle"):
						toggle.button_pressed = true
			return node
		stack.append_array(node.get_children())
	return null


func _ux_hover(button: Button) -> void:
	if button == null:
		return
	var at := button.get_global_rect().get_center()
	get_viewport().warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion)
	await get_tree().create_timer(1.0).timeout
	await _frame()


func _ux_map_tips() -> void:
	if not showing_network:
		_toggle_network()
	await _frame()
	var foreign := ""
	for candidate in game.stations:
		var st: Dictionary = game.stations[candidate]
		if str(st.owner) == game.player or not bool(st.get("known", false)):
			continue
		if game.borders_player(str(candidate)) and game._court_block(str(candidate)) == "":
			foreign = str(candidate)
			break
	print("UX map station %s" % foreign)
	if foreign == "":
		return
	var keep_influence := int(game.stock.influence)
	game.stock.influence = 1
	_refresh()
	network_view.open_sheet(foreign)
	await _frame()
	await _ux_hover(_ux_order_button("envoy"))
	_save("map_tip_disabled")
	game.stock.influence = maxi(keep_influence, 12)
	_refresh()
	network_view.open_sheet(foreign)
	await _frame()
	await _ux_hover(_ux_order_button("move"))
	_save("map_tip_enabled")
	var keep_seats: Dictionary = game.seat_used.duplicate()
	for seat in game.council:
		game.seat_used[str(seat.role)] = "envoy"
	_refresh()
	network_view.open_sheet(foreign)
	await _frame()
	await _ux_hover(_ux_order_button("envoy"))
	_save("map_tip_no_councillor")
	game.seat_used = keep_seats
	network_view.close_sheet()
	_toggle_network()


func _ux_card_fit() -> void:
	await _ux_fit_pass("calm")
	game.discontent = 98
	game.stock.food = 3
	var st_name := ""
	for sid in game.stations:
		if str(game.stations[sid].owner) == game.player and sid != game.capital_id:
			st_name = str(game.stations[sid].name)
	if st_name == "":
		st_name = "Coney Island"
	game.demands.append({"faction": "exchange", "amount": 10, "deadline": 2, "paid": false})
	game.log.append({"week": game.week, "text": "SEASON Скоро %s." % Copy.season("flood"), "important": true})
	game.log.append({"week": game.week, "text": "ULTIMATUM %s хочет %s, осталось %s." % [Copy.t("Exchange"), Copy.stock(10, "tokens"), Words.count(2, "week")], "important": true})
	game.log.append({"week": game.week, "text": "PRESSURE Еда, Воздух, Энергия", "important": true})
	game.log.append({"week": game.week - 1, "text": "WARN %s is losing its loyalty" % Copy.t(st_name), "important": true})
	await _ux_fit_pass("stressed")


func _ux_fit_pass(tag: String) -> void:
	var worst := ""
	var worst_over := -99999.0
	var over_n := 0
	var seen := 0
	for ev in game.catalog.events:
		game.pending.clear()
		game.week_event_ids = {}
		game._present_event(ev)
		if game.pending.is_empty():
			continue
		_show_dawn()
		await _frame()
		await _frame()
		await _frame()
		seen += 1
		var over := card_body.size.y - card_scroll.size.y
		if over > 1.0:
			over_n += 1
			print("FIT %s over %s %.0f" % [tag, str(ev.id), over])
		if card_body.size.y > worst_over:
			worst_over = card_body.size.y
			worst = str(ev.id)
		_close_card()
	game.pending.clear()
	_show_dawn()
	await _frame()
	print("FIT %s plain dawn over %.0f" % [tag, card_body.size.y - card_scroll.size.y])
	_close_card()
	print("FIT %s cards %d overflowing %d tallest %s (content %.0f px, view %.0f px)" % [tag, seen, over_n, worst, worst_over, card_scroll.size.y])
	if worst != "":
		_offer_shot(worst)
		await _frame()
		await _frame()
		await _frame()
		_save("card_tallest" if tag == "calm" else "card_tallest_%s" % tag)
		_close_card()


func _visual_shots() -> void:
	shot_mode = true
	hold_dawn = false
	at_menu = false
	await _settle(_shot_size())
	_close_card()
	guide_played = true
	guide_step = -1
	if guide_layer != null:
		guide_layer.visible = false
	game.pending.clear()
	_refresh()
	await _frame()
	_save("station_full")
	var crowded: Array = []
	for room in game.rooms:
		if str(room.type) == "quarters" and not bool(room.offline):
			room.offline = true
			crowded.append(room)
	var pick := _ux_choice()
	print("VISUAL crowding %s housing %d pop %d" % [game.residents.size() > game.housing(), game.housing(), game.residents.size()])
	_offer_shot(str(pick.get("event", "moles_vents")))
	await _frame()
	await _frame()
	_save("event_chips")
	news_open = true
	_paint_dawn()
	await _frame()
	await _frame()
	_save("event_news_open")
	var keep_dis := game.discontent
	var keep_food := int(game.stock.food)
	game.discontent = 72
	game.stock.food = game.food_need() * 4
	print("VISUAL forecasts %s revolt %s" % [str(game.forecasts()), str(game.revolt_warning())])
	_paint_dawn()
	await _frame()
	await _frame()
	_save("event_news_far")
	news_open = false
	_close_card()
	game.pending.clear()
	_show_dawn()
	await _frame()
	await _frame()
	_save("dawn_plain")
	_close_card()
	game.discontent = keep_dis
	game.stock.food = keep_food
	for room in crowded:
		room.offline = false
	game.pending.clear()
	_refresh()
	var uid := ""
	for type in ["workshop", "hydroponics", "generator", "air_filter"]:
		uid = _room_uid(type)
		if uid != "":
			break
	if uid != "":
		var room = game._room(uid)
		var cap := int(game.catalog.rooms[str(room.type)].staff_max)
		while room.staff.size() > maxi(1, cap - 2):
			game.apply({"kind": "unassign", "person": str(room.staff.back())})
		_refresh()
		_show_room(uid)
		await _frame()
		await _frame()
		_save("room_panel")
		_close_card()
		_visual_picker(uid)
		await _frame()
		await _frame()
		_save("room_picker")
		_close_card()
		_open_picker(uid)
		_toggle_picker_busy(uid)
		await _frame()
		await _frame()
		card_scroll.scroll_vertical = int(card_body.size.y)
		await _frame()
		_save("room_picker_busy")
		_close_card()
		game.apply({"kind": "switch", "room": uid, "on": false})
		_refresh()
		_show_room(uid)
		await _frame()
		await _frame()
		_save("room_panel_off")
		_close_card()
		game.apply({"kind": "switch", "room": uid, "on": true})
		game.apply({"kind": "staff"})
		_refresh()
	var floor_at := _first_open_floor()
	_show_build(floor_at.x, floor_at.y)
	await _frame()
	await _frame()
	_save("build_menu")
	_close_card()
	var built := false
	for type in ["generator", "workshop", "hydroponics", "air_filter", "quarters"]:
		if built or not game.build_possible(type):
			continue
		var at := _first_open_floor()
		built = game.apply({"kind": "build", "type": type, "level": at.x, "cell": at.y})
	_sample_dig()
	print("VISUAL build %s dig %s" % [str(game.build), str(game.dig)])
	_refresh()
	await _frame()
	await _frame()
	_save("construction_station")
	if not game.build.is_empty():
		yard._zoom_to(int(game.build.level), int(game.build.cell))
		await _frame()
		await _frame()
		_save("construction_build")
	if not game.dig.is_empty():
		yard._zoom_to(int(game.dig.level), int(game.dig.cell))
		await _frame()
		await _frame()
		_save("construction_dig")
	yard.fit()
	game.pending.clear()
	_end_turn()
	_close_card()
	game.pending.clear()
	_refresh()
	if not game.build.is_empty():
		yard._zoom_to(int(game.build.level), int(game.build.cell))
		await _frame()
		await _frame()
		_save("construction_build_mid")
	yard.fit()
	_zoom_pair("workshop", "hydroponics")
	await _frame()
	await _frame()
	_save("figures_rooms")
	_zoom_room("quarters")
	await _frame()
	await _frame()
	_save("figures_quarters")
	get_tree().quit(0)


func _visual_picker(uid: String) -> void:
	_open_picker(uid)


func _offer_shot(event_id: String) -> void:
	game.pending.clear()
	game.week_event_ids = {}
	game._present_event(game._event_by_id(event_id))
	_show_dawn()


func _network_shots() -> void:
	shot_mode = true
	hold_dawn = false
	at_menu = false
	await _settle(_shot_size())
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
	await _desk_zoom_shots("desk_w1")
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
	await _desk_zoom_shots("desk_w20")
	network_view._fit()
	network_view.focus_intent()
	await _frame()
	await _frame()
	_save("network_intents")
	await _caravan_shot()
	network_view.open_sheet(game.capital_id)
	await _frame()
	await _frame()
	_save("network_own")
	var foreign := ""
	for candidate in game.stations:
		var st: Dictionary = game.stations[candidate]
		if str(candidate) == game.capital_id or str(st.owner) == game.player:
			continue
		if not bool(st.get("known", false)):
			continue
		if foreign == "" or game.borders_player(str(candidate)):
			foreign = str(candidate)
		if game.borders_player(str(candidate)) and game.order_block("envoy", str(candidate)) == "":
			foreign = str(candidate)
			break
	if foreign != "":
		network_view.open_sheet(foreign)
		await _frame()
		await _frame()
		_save("network_foreign")
		if game.queue_order({"kind": "order", "order": "envoy", "station": foreign}):
			var spent: Dictionary = game.order_cost("envoy", foreign)
			_refresh()
			note_spend(spent)
			_toast(network_view._order_queue_toast("envoy", foreign, {}))
			network_view.refresh()
			await _frame()
			await _frame()
			_save("network_order")
			if toast_label != null:
				toast_label.visible = false
			if toast_plate != null:
				toast_plate.visible = false
			game._resolve_queued()
			hold_dawn = false
			_show_order_report()
			await _frame()
			await _frame()
			_save("order_dawn")
			_close_card()
		network_view.open_visit(foreign)
		await _frame()
		await _frame()
		_save("station_visit")
	get_tree().quit()


## Caravans on the map: borrows one deal with the nearest known foreign station and an expedition in its tunnel for
## a single frame, then puts both back, so the rest of the run sees the bot's own state.
func _caravan_shot() -> void:
	var partner := ""
	for sid in game.stations:
		var st: Dictionary = game.stations[sid]
		if str(sid) == game.capital_id or str(st.owner) == game.player or not bool(st.get("known", false)):
			continue
		if game.trade_route(str(sid)).size() >= 2 and (partner == "" or game.trade_route(str(sid)).size() < game.trade_route(partner).size()):
			partner = str(sid)
	var deals_were := int(game.stations[partner].get("deals", 0)) if partner != "" else 0
	var trip_was: Dictionary = game.expedition.duplicate()
	var away_was := bool(game.squads[game.player].get("away", false))
	if partner != "":
		game.stations[partner].deals = maxi(1, deals_were)
	game.expedition = {"left": 2, "tunnel": "to_ferry"}
	game.squads[game.player].away = true
	network_view.show_zoom(2.0, game.capital_id)
	await _frame()
	await _frame()
	_save("network_caravans")
	var motion_was := motion_in_shots
	motion_in_shots = true
	network_view.show_zoom(3.5, game.capital_id)
	network_view._anim_t = 7.3
	network_view.refresh()
	await _frame()
	_save("network_handcar")
	motion_in_shots = motion_was
	network_view.show_zoom(2.0, game.capital_id)
	network_view.refresh()
	await _frame()
	for held in network_view._chip_hits:
		var hit: Rect2 = network_view._chip_hits[held]
		network_view._chip_hover = str(held)
		network_view.open_focus_menu(str(held), hit.end)
		network_view._redraw()
		await _frame()
		await _frame()
		_save("network_focus_menu")
		network_view._focus_menu.hide()
		network_view._chip_hover = ""
		break
	await _squad_walk_shot()
	await _governor_shots()
	if partner != "":
		game.stations[partner].deals = deals_were
	game.expedition = trip_was
	game.squads[game.player].away = away_was
	network_view._fit()
	await _frame()


## The governor picker on a held station's card, then the card and the map seal once someone holds it. Puts the
## run back as it was (governor recalled, influence returned).
func _governor_shots() -> void:
	var held := ""
	for sid in game.stations:
		if str(game.stations[sid].owner) == game.player and str(sid) != game.capital_id:
			held = str(sid)
			break
	if held == "" or game.governor_candidates(held).is_empty():
		return
	var influence_was := int(game.stock.influence)
	game.stock.influence = maxi(influence_was, 20)
	network_view.show_zoom(2.0, held)
	network_view.open_sheet(held)
	await _frame()
	await _frame()
	network_view.open_governor_menu(held, Vector2(network_view.size.x * 0.42, network_view.size.y * 0.3))
	await _frame()
	await _frame()
	_save("network_governor_pick")
	network_view._gov_menu.hide()
	var pick: Dictionary = game.governor_candidates(held)[0]
	game.apply({"kind": "appoint", "station": held, "person": str(pick.id)})
	network_view.refresh()
	await _frame()
	await _frame()
	_save("network_governor")
	game.recall_governor(held)
	game.stock.influence = influence_was
	network_view.close_sheet()
	network_view.refresh()
	await _frame()


## A rival squad caught halfway along a two-tunnel walk: the map is told it stood two stations back, with motion on
## for this one frame.
func _squad_walk_shot() -> void:
	var walker := ""
	var back := ""
	for fid in game.squads:
		if str(fid) == game.player:
			continue
		var here := str(game.squads[fid].station)
		if not game.stations.has(here) or not bool(game.stations[here].get("known", false)):
			continue
		for n in game._neighbors(here):
			for far in game._neighbors(str(n)):
				if str(far) != here and bool(game.stations[str(far)].get("known", false)):
					back = str(far)
					break
			if back != "":
				break
		if back != "":
			walker = str(fid)
			break
	if walker == "":
		return
	var motion_was := motion_in_shots
	motion_in_shots = true
	var here := str(game.squads[walker].station)
	network_view.show_zoom(1.6, here)
	network_view._squad_seen[walker] = back
	network_view.refresh()
	if network_view._walks.has(walker):
		network_view._walks[walker].t = float(network_view._walks[walker].dur) * 0.5
	await _frame()
	_save("network_squad_walk")
	network_view._walks.clear()
	motion_in_shots = motion_was


func _desk_zoom_shots(prefix: String) -> void:
	for step in [["min", 1.0, ""], ["mid", 2.0, "plaza"], ["max", 3.5, "quarry"]]:
		network_view.show_zoom(float(step[1]), str(step[2]))
		await _frame()
		await _frame()
		_save("%s_%s" % [prefix, step[0]])
	network_view._fit()


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
	await _settle(_shot_size())
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
	_start_guide()
	await _frame()
	await _frame()
	_save("station_guide")
	get_tree().quit()


## What the score reads: where the player is and how the station stands. Read only.
func music_state() -> Dictionary:
	var at := {"context": "none", "voice": Voice.playing()}
	if shot_mode or game == null:
		return at
	var in_menu := menu_layer != null and menu_layer.visible and not settings_from_game
	if at_menu or in_menu or (hub_layer != null and hub_layer.visible):
		at.context = "menu"
		return at
	if game.over != "":
		at.context = "ending"
		return at
	var revolt := game.revolt_warning()
	at.context = "station"
	at.hope = game.hope
	at.discontent = game.discontent
	at.revolt_warn = not revolt.is_empty()
	at.revolt_edge = not revolt.is_empty() and int(revolt.get("weeks", 99)) <= 1
	at.hope_warn = game._hope_warn_weeks() <= int(game.bal.get("forecast_weeks", 2))
	at.flood = game._season_is("flood")
	at.cough_call = game.can_quarantine()
	return at


## The intro about the Silence (ui/intro/teaser.tscn) over the main menu, once per player: any click or key
## skips it. The menu music is muted under it so the intro's own score plays alone.
func _play_intro() -> void:
	var scene: PackedScene = load("res://ui/intro/teaser.tscn")
	if scene == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var intro = scene.instantiate()
	intro.in_game = true
	var music_bus := AudioServer.get_bus_index("Music")
	var was_muted := music_bus >= 0 and AudioServer.is_bus_mute(music_bus)
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, true)
	intro.finished.connect(func():
		if music_bus >= 0:
			AudioServer.set_bus_mute(music_bus, was_muted)
		Settings.intro_seen = true
		Settings.save()
		layer.queue_free())
	layer.add_child(intro)


func _show_main_menu() -> void:
	at_menu = true
	settings_from_game = false
	Voice.stop()
	_hide_radio()
	_close_card()
	_ensure_menu()
	_fill_menu_root()
	menu_root.visible = true
	menu_settings.visible = false
	menu_credits.visible = false
	menu_picture.visible = true
	menu_dim.visible = false
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
	hints_late = false
	_hide_hint()
	_refresh()
	if not shot_mode:
		SaveGame.write_auto(game)
		_show_howto(true)
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
	_loaded_hints()
	Sound.play("confirm")
	Sound.bed("station")
	_refresh()
	_note_save_recovery()


## SaveGame.last_error after a successful load names the newer files it had to skip.
func _note_save_recovery() -> void:
	if SaveGame.last_error != "":
		_toast(Copy.t("The latest save was damaged. Loaded the last good copy."), 6.0)


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
	_loaded_hints()
	Sound.play("confirm")
	_close_card()
	_refresh()
	_note_save_recovery()


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
	_show_sheet(menu_settings)


func _open_credits() -> void:
	_ensure_menu()
	_show_sheet(menu_credits)


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
	layer.z_index = 220
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
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.78)
	shade.visible = false
	layer.add_child(shade)
	menu_picture = picture
	menu_dim = shade
	menu_root = _menu_page()
	settings_body = VBoxContainer.new()
	credits_body = VBoxContainer.new()
	menu_settings = _menu_sheet(settings_body)
	menu_credits = _menu_sheet(credits_body)
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


## Settings and Credits sit in a framed card over the dimmed screen, like the other modals.
func _menu_sheet(body: VBoxContainer) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.offset_left = 12.0
	holder.offset_top = 12.0
	holder.offset_right = -12.0
	holder.offset_bottom = -12.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _paper_style())
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 16)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	frame.add_child(margin)
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	return holder


func _sheet_head(heading: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var title := _label(heading, 32, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var back := _button("Back", _menu_back)
	back.custom_minimum_size = Vector2(120, 44)
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.set_meta("sheet_back", true)
	row.add_child(back)
	return row


func _sheet_open() -> bool:
	return menu_layer != null and menu_layer.visible and (menu_settings.visible or menu_credits.visible)


func _show_sheet(page: Control) -> void:
	menu_root.visible = false
	menu_settings.visible = page == menu_settings
	menu_credits.visible = page == menu_credits
	menu_picture.visible = not settings_from_game
	menu_dim.visible = true
	menu_layer.visible = true
	_place_sheet()
	_place_sheet.call_deferred()


## Below the top bar like the other cards when the station shows behind; higher only if it would not fit.
func _place_sheet() -> void:
	if not _sheet_open():
		return
	var over_station := not menu_picture.visible or menu_picture.texture == null
	var top := _card_top_limit() if over_station else 12.0
	for page in [menu_settings, menu_credits]:
		if page.visible:
			var tall: float = (page.get_child(0) as Control).get_combined_minimum_size().y
			page.offset_top = clampf(size.y - 12.0 - tall, 12.0, top)


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
	menu_root.add_child(_menu_choice("How to play", _show_howto.bind(false), false))
	menu_root.add_child(_menu_choice("Intro", _play_intro, false))
	menu_root.add_child(_menu_choice("Settings", _open_settings.bind(false), false))
	menu_root.add_child(_menu_choice("Credits", _open_credits, false))
	menu_root.add_child(_menu_choice("Quit", _quit_game, false))
	menu_root.add_child(_log_row(false))
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(push)
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.035, 0.03, 0.82)))
	var note := _label(DISCLAIMER, 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(minf(720.0, size.x - 120.0), 0)
	note.add_theme_color_override("font_color", Color(0.94, 0.9, 0.82, 0.85))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	lines.add_child(note)
	lines.add_child(_version_label())
	plate.add_child(lines)
	menu_root.add_child(plate)


func _menu_choice(caption: String, cb: Callable, primary: bool) -> Button:
	var button := _button(caption, cb, "confirm" if primary else "click")
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(280, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if primary:
		_style_primary(button)
	return button


func _version_label() -> Label:
	var lab := _label(BuildInfo.line(), 13)
	lab.add_theme_color_override("font_color", PAPER_MUTED if on_paper else Color(0.94, 0.9, 0.82, 0.7))
	return lab


const CONSENT_TEXT := "This playtest build writes a local log of what you did (weeks, choices, time) to a file on your computer. Nothing is sent automatically. You can send the file to the developer if you want."

var howto_data := {}


## Playtest log controls for the main menu and the in-game Menu card: the log state (click to change), the log
## folder and the copied report.
func _log_row(in_card: bool) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	var on := Settings.log_consent == "yes"
	var refill := _show_menu if in_card else _fill_menu_root
	var state := _button("Playtest log: on" if on else "Playtest log: off", func() -> void:
		PlaytestLog.set_consent(not on)
		refill.call())
	for button in [state, _button("Open log folder", _open_log_folder), _button("Copy report", _copy_report)]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size = Vector2(0, 40)
		row.add_child(button)
	return row


func _open_log_folder() -> void:
	OS.shell_show_in_file_manager(PlaytestLog.folder(), true)


func _report_text() -> String:
	return PlaytestLog.report_text(PlaytestLog.records, PlaytestLog.active_seconds())


func _copy_report() -> void:
	DisplayServer.clipboard_set(_report_text())
	Sound.play("confirm")
	_toast(Copy.t("Report copied. Paste it into your reply."), 3.0)
	toast_label.z_index = 95 if menu_layer != null and menu_layer.visible else 30


func _session_info() -> Dictionary:
	var screen := DisplayServer.screen_get_size()
	var win := get_window().size
	return {
		"version": BuildInfo.version(),
		"build": BuildInfo.build(),
		"language": Copy.lang,
		"resolution": "%dx%d" % [screen.x, screen.y],
		"window": "%dx%d" % [win.x, win.y],
		"fullscreen": Settings.fullscreen,
		"os": OS.get_name(),
		"godot_version": str(Engine.get_version_info().get("string", "")),
	}


func _quit_game() -> void:
	_end_log()
	get_tree().quit()


func _show_life_epilogue() -> void:
	if game == null:
		return
	game._seal_score()
	life_epilogue_page = 0
	_ensure_life_epilogue()
	if yard != null:
		yard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	life_epilogue.visible = true
	_paint_life_epilogue()


func _ensure_life_epilogue() -> void:
	if life_epilogue != null:
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 80
	layer.visible = false
	var wash := ColorRect.new()
	wash.color = Color(0.05, 0.04, 0.03, 0.94)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(wash)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := _paper_style()
	paper.set_border_width_all(3)
	paper.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", paper)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	on_paper = true
	life_epilogue_eyebrow = _label("", 13)
	life_epilogue_eyebrow.add_theme_color_override("font_color", PAPER_EDGE)
	column.add_child(life_epilogue_eyebrow)
	life_epilogue_body = VBoxContainer.new()
	life_epilogue_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	life_epilogue_body.add_theme_constant_override("separation", 10)
	column.add_child(life_epilogue_body)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	life_epilogue_dots = HBoxContainer.new()
	life_epilogue_dots.add_theme_constant_override("separation", 8)
	life_epilogue_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(life_epilogue_dots)
	for _i in 3:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		life_epilogue_dots.add_child(dot)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)
	life_epilogue_actions = HBoxContainer.new()
	life_epilogue_actions.add_theme_constant_override("separation", 8)
	bottom.add_child(life_epilogue_actions)
	on_paper = false
	add_child(layer)
	life_epilogue = layer
	life_epilogue_panel = panel


func _paint_life_epilogue() -> void:
	if life_epilogue == null or game == null:
		return
	_layout_life_epilogue()
	var payload: Dictionary = game.epilogue_payload()
	on_paper = true
	life_epilogue_eyebrow.text = Copy.t("epilogue.eyebrow") % (life_epilogue_page + 1)
	_wipe(life_epilogue_body)
	_wipe(life_epilogue_actions)
	match life_epilogue_page:
		0:
			_life_verdict(payload)
		1:
			_life_chronicle()
		_:
			_life_fates(payload)
	_paint_life_dots()
	on_paper = false
	if _motion_off():
		life_epilogue_body.modulate.a = 1.0
		return
	life_epilogue_body.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(life_epilogue_body, "modulate:a", 1.0, 0.15)


func _life_verdict(payload: Dictionary) -> void:
	var verdict := str(payload.get("verdict", ""))
	if verdict == "":
		verdict = _ending()
	var head := _label(verdict, 34, true)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_epilogue_body.add_child(head)
	var creed := str(payload.get("creed_label", Copy.t("epilogue.no_creed")))
	var sub := _label("%s · %s" % [Copy.t("Week %d%s") % [int(payload.get("week", game.week)), ""], creed], 16)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color", PAPER_MUTED)
	life_epilogue_body.add_child(sub)
	var judgment := str(payload.get("judgment", ""))
	if judgment != "":
		var ask := _label(judgment, 20, true)
		ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ask.add_theme_color_override("font_color", PAPER_MUTED)
		ask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		life_epilogue_body.add_child(ask)
	_life_story_lines()
	var go := _button("epilogue.continue", _life_epilogue_go.bind(1))
	_style_primary(go)
	go.custom_minimum_size = Vector2(180, 48)
	life_epilogue_actions.add_child(go)


## The story ending stays on the verdict page: title, leader lines, and the truth line.
func _life_story_lines() -> void:
	var id := game.ending_id()
	if game.ending_text(id, "title") == "":
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 120)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var title := _label(game.ending_text(id, "title"), 18, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(title)
	var body := _label(game.ending_text(id, "text"), 15)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(body)
	for row in game.catalog.leaders.get("factions", []):
		var fid := str(row.get("id", ""))
		var line := _label("%s — %s" % [_leader_text(game.leader_name(fid, "leader")), game.leader_epilogue(fid)], 14)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_color_override("font_color", PAPER_MUTED)
		list.add_child(line)
	var truth := _label(game.truth_epilogue(), 14)
	truth.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	truth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(truth)
	life_epilogue_body.add_child(scroll)


func _life_chronicle() -> void:
	var title := _label("epilogue.chronicle_title", 26, true)
	life_epilogue_body.add_child(title)
	var moments: Array = game.chronicle_top(6)
	if moments.is_empty():
		var empty := _label("epilogue.chronicle_empty", 16)
		empty.add_theme_color_override("font_color", PAPER_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		life_epilogue_body.add_child(empty)
	for moment in moments:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var tag := Label.new()
		tag.text = "W%d" % int(moment.get("week", 0))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.custom_minimum_size = Vector2(52, 24)
		tag.add_theme_font_size_override("font_size", 14)
		tag.add_theme_color_override("font_color", INK_DARK)
		if number_font != null:
			tag.add_theme_font_override("font", number_font)
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("e2a63a")
		plate.set_corner_radius_all(2)
		tag.add_theme_stylebox_override("normal", plate)
		row.add_child(tag)
		var text := str(moment.get("text", ""))
		if text == "":
			text = game.chronicle_line(moment)
		var line := _label(text, 16)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(line)
		life_epilogue_body.add_child(row)
	var go := _button("epilogue.continue", _life_epilogue_go.bind(2))
	_style_primary(go)
	go.custom_minimum_size = Vector2(180, 48)
	life_epilogue_actions.add_child(go)


func _life_fates(payload: Dictionary) -> void:
	var title := _label("epilogue.fates_title", 26, true)
	life_epilogue_body.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for row in payload.get("fates", []):
		var line := str(row.get("line", ""))
		var lab := _label(line, 16)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(lab)
	life_epilogue_body.add_child(scroll)
	var score_name := _label("epilogue.score", 13)
	score_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_name.add_theme_color_override("font_color", PAPER_EDGE)
	life_epilogue_body.add_child(score_name)
	var score_num := _label(str(int(payload.get("score", 0))), 44, true)
	score_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_num.add_theme_color_override("font_color", Color("e2a63a"))
	if number_font != null:
		score_num.add_theme_font_override("font", number_font)
	life_epilogue_body.add_child(score_num)
	var parts := _label(str(payload.get("score_parts", "")), 11)
	parts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts.add_theme_color_override("font_color", PAPER_MUTED)
	life_epilogue_body.add_child(parts)
	var again := _button("epilogue.new_run", _life_epilogue_new_game)
	again.custom_minimum_size = Vector2(160, 48)
	life_epilogue_actions.add_child(again)
	var menu := _button("epilogue.menu", _life_epilogue_menu)
	_style_primary(menu)
	menu.custom_minimum_size = Vector2(180, 48)
	life_epilogue_actions.add_child(menu)


func _paint_life_dots() -> void:
	if life_epilogue_dots == null:
		return
	for i in life_epilogue_dots.get_child_count():
		var dot := life_epilogue_dots.get_child(i) as Panel
		if dot == null:
			continue
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color("e2a63a") if i == life_epilogue_page else Color("554533")
		plate.set_corner_radius_all(5)
		dot.add_theme_stylebox_override("panel", plate)


func _life_epilogue_go(page: int) -> void:
	life_epilogue_page = clampi(page, 0, 2)
	_paint_life_epilogue()


func _close_life_epilogue() -> void:
	if life_epilogue != null:
		life_epilogue.visible = false
	if yard != null:
		yard.mouse_filter = Control.MOUSE_FILTER_STOP


func _life_epilogue_menu() -> void:
	_close_life_epilogue()
	_back_to_menu()


func _life_epilogue_new_game() -> void:
	_close_life_epilogue()
	_close_card()
	_begin_new_game(true)


func _layout_life_epilogue() -> void:
	if life_epilogue_panel == null or life_epilogue == null or not life_epilogue.visible:
		return
	var w := minf(720.0, maxf(280.0, size.x - 48.0))
	var h := minf(860.0, maxf(320.0, size.y - 48.0))
	life_epilogue_panel.position = Vector2((size.x - w) * 0.5, (size.y - h) * 0.5)
	life_epilogue_panel.size = Vector2(w, h)


func _life_epilogue_input(event: InputEvent) -> bool:
	if life_epilogue == null or not life_epilogue.visible:
		return false
	var cancel := false
	if event.is_action_pressed("ui_cancel"):
		cancel = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel = true
	if not cancel:
		return false
	if life_epilogue_page < 2:
		_life_epilogue_go(life_epilogue_page + 1)
	else:
		_life_epilogue_menu()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_log()
	elif what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_life_epilogue()


func _end_log() -> void:
	if shot_mode or not PlaytestLog.started:
		return
	var ending := ""
	if game != null and game.over != "":
		ending = game.ending_id()
	PlaytestLog.end(maxi(log_week, 0), ending)


func _input(event: InputEvent) -> void:
	if _life_epilogue_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventKey or event is InputEventMouseMotion or event is InputEventScreenTouch:
		PlaytestLog.touch()


## Week starts, dawn events and the ending go to the playtest log from here; choices come through game.watcher.
func _watch_log() -> void:
	if not PlaytestLog.started or shot_mode:
		return
	PlaytestLog.pump()
	if at_menu or game == null:
		return
	if log_game != game:
		log_game = game
		log_week = -1
		log_over = ""
		game.watcher = _on_game_note
	if game.week != log_week:
		log_week = game.week
		PlaytestLog.week = game.week
		var stocks := {}
		for key in game.stock:
			stocks[str(key)] = int(game.stock[key])
		PlaytestLog.event("week_start", {
			"week": game.week,
			"real_seconds_since_start": PlaytestLog.real_seconds(),
			"active_seconds": PlaytestLog.active_seconds(),
			"hope": game.hope,
			"discontent": game.discontent,
			"stocks": stocks,
		})
		var ids: Array = []
		for ev in game.pending:
			ids.append(str(ev.get("id", "")))
		PlaytestLog.event("dawn_events", {"week": game.week, "ids": ids})
	if game.over != "" and log_over == "":
		log_over = game.over
		PlaytestLog.event("ending", {"id": game.ending_id(), "week": game.week, "proofs": game.proofs()})


func _on_game_note(what: String, data: Dictionary) -> void:
	var week := int(game.week) if game != null else 0
	if what == "journal":
		match str(data.get("kind", "")):
			"order":
				PlaytestLog.event("decision", {"kind": "order", "id": str(data.get("order", "")), "choice": str(data.get("station", "")), "week": week})
			"audience":
				var leader := str(data.get("faction", ""))
				var answer := str(data.get("result", ""))
				PlaytestLog.event("decision", {"kind": "audience", "id": leader, "choice": answer, "week": week})
				PlaytestLog.event("audience", {"leader": leader, "answer": answer, "week": week})
			"truth":
				PlaytestLog.event("fragment", {"id": str(data.get("id", "")), "how": str(data.get("how", "")), "week": week})
		return
	var kind := str(data.get("kind", ""))
	var action: Dictionary = data.get("action", {})
	var entry: Dictionary = data.get("entry", {})
	var row := {}
	match kind:
		"order", "audience":
			return
		"event":
			row = {"kind": "event_choice", "id": str(action.get("event_id", "")), "choice": str(action.get("choice_id", ""))}
			if bool(data.get("scene", false)):
				PlaytestLog.event("bunker_scene", {"id": row.id, "choice": row.choice, "week": week})
		"build":
			row = {"kind": "build", "id": str(action.get("type", "")), "choice": "build"}
		"demolish":
			row = {"kind": "build", "id": str(entry.get("type", "")), "choice": "demolish"}
		"dig":
			row = {"kind": "dig", "id": "%d:%d" % [int(action.get("level", -1)), int(action.get("cell", -1))], "choice": "dig"}
		"upgrade":
			row = {"kind": "upgrade", "id": str(entry.get("type", "")), "choice": "upgrade"}
		"law":
			row = {"kind": "law", "id": str(action.get("law", "")), "choice": "pass"}
		"repeal":
			row = {"kind": "law", "id": str(action.get("law", "")), "choice": "repeal"}
		"assign", "unassign", "staff":
			var room = game._room(str(action.get("room", ""))) if game != null else null
			row = {"kind": "assign", "id": str(room.type) if room != null else "", "choice": kind}
		_:
			row = {"kind": "action", "id": kind, "choice": ""}
	row["week"] = week
	PlaytestLog.event("decision", row)


## First launch asks about the log; after a launch that never reached session_end, offers the log folder once.
func _playtest_prompts() -> void:
	if Settings.log_consent == "":
		_show_consent()
	elif PlaytestLog.crashed and Settings.log_consent == "yes":
		PlaytestLog.crashed = false
		_show_crash_offer()


## A paper card over everything, menus included. `fill` adds the body to the card's column.
func _notice(heading: String, fill: Callable) -> void:
	_close_notice()
	var was := on_paper
	on_paper = true
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index = 90
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := PanelContainer.new()
	var style := _paper_style()
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(minf(760.0, maxf(size.x, 1280.0) - 120.0), 0)
	panel.add_child(box)
	var title := _label(heading, 28, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title)
	fill.call(box)
	add_child(layer)
	notice_layer = layer
	on_paper = was


func _notice_text(box: VBoxContainer, text: String, font_size: int = 18) -> Label:
	var lab := _label(text, font_size)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(lab)
	return lab


func _notice_buttons(box: VBoxContainer, rows: Array) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	for spec in rows:
		var button := _button(str(spec[0]), spec[1], "confirm" if bool(spec[2]) else "click")
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.custom_minimum_size = Vector2(200, 48)
		if bool(spec[2]):
			_style_primary(button)
		line.add_child(button)
	box.add_child(line)


func _close_notice() -> void:
	if notice_layer != null:
		notice_layer.queue_free()
	notice_layer = null
	howto_check = null


func _show_consent() -> void:
	_notice("Playtest log", func(box: VBoxContainer) -> void:
		_notice_text(box, CONSENT_TEXT)
		_notice_buttons(box, [["Allow logging", _answer_consent.bind(true), true], ["No logging", _answer_consent.bind(false), false]]))


func _answer_consent(allow: bool) -> void:
	PlaytestLog.set_consent(allow)
	_close_notice()
	if at_menu:
		_fill_menu_root()


func _show_crash_offer() -> void:
	_notice("Playtest log", func(box: VBoxContainer) -> void:
		_notice_text(box, "The game closed unexpectedly. Open the log folder?")
		_notice_buttons(box, [["Open log folder", _crash_open_folder, true], ["Not now", _close_notice, false]]))


func _crash_open_folder() -> void:
	_close_notice()
	_open_log_folder()


func _howto() -> Dictionary:
	if howto_data.is_empty():
		var f := FileAccess.open("res://data/howto.json", FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f != null else null
		howto_data = data if data is Dictionary else {}
	return howto_data


## data/howto.json on paper. At the start of a new game unless the player ticked Do not show again; always
## from the menus.
func _show_howto(auto: bool) -> void:
	var data := _howto()
	if data.is_empty() or (auto and Settings.howto_hidden):
		return
	howto_count += 1
	var lang := "ru" if Copy.ru() else "en"
	var title: Dictionary = data.get("title", {})
	_notice(str(title.get(lang, title.get("en", ""))), func(box: VBoxContainer) -> void:
		var n := 0
		for line in data.get("lines", []):
			n += 1
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			var num := _label("%d" % n, 22, true)
			num.custom_minimum_size = Vector2(22, 0)
			num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(num)
			var text := _label(str(line.get(lang, line.get("en", ""))), 18)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.set_meta("howto_line", true)
			row.add_child(text)
			box.add_child(row)
		var check := CheckBox.new()
		check.text = Copy.t("Do not show again")
		check.button_pressed = Settings.howto_hidden
		check.add_theme_font_size_override("font_size", 17)
		if body_font != null:
			check.add_theme_font_override("font", body_font)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			check.add_theme_color_override(key, PAPER_INK)
		check.add_theme_icon_override("checked", _check_icon(true))
		check.add_theme_icon_override("unchecked", _check_icon(false))
		check.add_theme_constant_override("h_separation", 10)
		check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		box.add_child(check)
		howto_check = check
		_notice_buttons(box, [["Close", _close_howto, true]]))
	if notice_layer != null:
		var panels := notice_layer.find_children("*", "PanelContainer", true, false)
		if not panels.is_empty():
			get_tree().process_frame.connect(_fit_notice.bind(panels[0]), CONNECT_ONE_SHOT)


## A 22 px box in the paper card's colours, ticked with a brass square.
func _check_icon(on: bool) -> Texture2D:
	var px := 22
	var image := Image.create(px, px, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in px:
		for edge in [0, 1, px - 2, px - 1]:
			image.set_pixel(i, edge, PAPER_INK)
			image.set_pixel(edge, i, PAPER_INK)
	if on:
		image.fill_rect(Rect2i(5, 5, px - 10, px - 10), Color("e2a63a"))
	return ImageTexture.create_from_image(image)


func _close_howto() -> void:
	if howto_check != null:
		Settings.howto_hidden = howto_check.button_pressed
		Settings.save()
	_close_notice()


## Smaller how-to lines, a step at a time, until the card fits the window height.
func _fit_notice(panel: Control, tries: int = 0) -> void:
	if not is_instance_valid(panel) or tries > 8:
		return
	var tall := panel.get_combined_minimum_size().y
	if tall < 1.0:
		get_tree().process_frame.connect(_fit_notice.bind(panel, tries + 1), CONNECT_ONE_SHOT)
		return
	if tall <= size.y - 24.0:
		return
	var smaller := false
	for lab in panel.find_children("*", "Label", true, false):
		if lab.has_meta("howto_line"):
			var now: int = lab.get_theme_font_size("font_size")
			if now > 14:
				lab.add_theme_font_size_override("font_size", now - 1)
				smaller = true
	for box in panel.find_children("*", "VBoxContainer", true, false):
		var gap: int = box.get_theme_constant("separation")
		if gap > 6:
			box.add_theme_constant_override("separation", gap - 2)
			smaller = true
	if smaller:
		get_tree().process_frame.connect(_fit_notice.bind(panel, tries + 1), CONNECT_ONE_SHOT)


func _hints() -> Array:
	if hint_data.is_empty():
		var f := FileAccess.open("res://data/hints.json", FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f != null else null
		if data is Dictionary and data.get("hints", null) is Array:
			hint_data = data.hints
	return hint_data


## No hints in shot runs, on a loaded game past week 6, with the setting off, or after the game ends.
func _hints_allowed() -> bool:
	if shot_mode and not hints_in_shots:
		return false
	if not Settings.hints_on or hints_late or game == null or game.over != "":
		return false
	return true


func _modal_up() -> bool:
	if at_menu or showing_network or notice_layer != null or not deck.is_empty():
		return true
	if modal_open:
		return true
	return menu_layer != null and menu_layer.visible


## A count that changes once the player does what the hint asks.
func _hint_progress(id: String) -> String:
	match id:
		"dig":
			var dug := 0
			for key in game.cells:
				if bool(game.cells[key].dug):
					dug += 1
			return "%d:%s" % [dug, str(not game.dig.is_empty())]
		"build":
			return "%d:%s" % [game.rooms.size(), str(not game.build.is_empty())]
		"staff":
			var staffed := 0
			for room in game.rooms:
				staffed += room.staff.size()
			return str(staffed)
		"end_turn":
			return str(game.week)
		"network":
			return str(showing_network)
	return ""


## Screen rect of the element a hint points at; empty when it is not on screen now.
func _hint_target(target: String) -> Rect2:
	match target:
		"end_turn":
			return _local_rect(end_button)
		"network_button":
			return _local_rect(network_button)
	if yard == null or not yard.visible:
		return Rect2()
	var view: Rect2 = yard._content()
	for level in 3:
		for cell in 6:
			var spot: Dictionary = game.cells["%d:%d" % [level, cell]]
			var fits := false
			match target:
				"dark_cell":
					fits = yard._kind(spot) == "undug" and bool(game.dig_preview(level, cell).ok)
				"open_floor":
					fits = bool(spot.dug) and str(spot.room) == "" and str(spot.get("pile", "")) == "" and not _job_here(level, cell)
				"room":
					var room = game._room(str(spot.room)) if str(spot.room) != "" else null
					if room != null:
						var defin: Dictionary = game.catalog.rooms[str(room.type)]
						fits = int(defin.get("staff_max", 0)) > room.staff.size() and not bool(room.offline)
			if not fits:
				continue
			var box: Rect2 = yard.cell_screen(level, cell)
			if view.encloses(box.grow(-box.size.x * 0.25)):
				return box
	return Rect2()


func _job_here(level: int, cell: int) -> bool:
	for job in [game.dig, game.clear, game.build]:
		if not job.is_empty() and int(job.level) == level and int(job.cell) == cell:
			return true
	return false


func _local_rect(node: Control) -> Rect2:
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	return get_global_transform().affine_inverse() * node.get_global_rect()


## One hint at a time. While a modal is up the callout is taken down but the hint stays current, so doing the
## action inside the modal still counts as done.
func _tick_hints() -> void:
	if game == null:
		return
	if hint_id != "":
		var row := _hint_by_id(hint_id)
		if _hint_progress(hint_id) != hint_mark:
			_dismiss_hint()
			return
		if not _hints_allowed() or not _hint_week(row):
			_hide_hint()
			return
		var spot := Rect2()
		if not _modal_up():
			spot = _hint_target(str(row.get("target", "")))
		if spot.size == Vector2.ZERO:
			_drop_callout()
			return
		if hint_box == null:
			_make_callout(row)
		hint_box.point_at(spot, size, hud.size.y + 8.0 if hud != null else 8.0)
		return
	if not _hints_allowed() or _modal_up():
		return
	for row in _hints():
		var id := str(row.get("id", ""))
		if id == "" or Settings.hints_seen.has(id) or not _hint_week(row):
			continue
		var spot := _hint_target(str(row.get("target", "")))
		if spot.size == Vector2.ZERO:
			continue
		hint_id = id
		hint_mark = _hint_progress(id)
		_make_callout(row)
		hint_box.point_at(spot, size, hud.size.y + 8.0 if hud != null else 8.0)
		return


func _hint_week(row: Dictionary) -> bool:
	var weeks: Array = row.get("weeks", [1, 40])
	return weeks.size() >= 2 and game.week >= int(weeks[0]) and game.week <= int(weeks[1])


func _hint_by_id(id: String) -> Dictionary:
	for row in _hints():
		if str(row.get("id", "")) == id:
			return row
	return {}


func _make_callout(row: Dictionary) -> void:
	_drop_callout()
	hint_box = HintCallout.new()
	hint_box.text = str(row.get("ru" if Copy.ru() else "en", row.get("en", "")))
	hint_box.font = body_font
	hint_box.dismissed.connect(_dismiss_hint)
	hint_box.set_meta("hint", str(row.get("id", "")))
	add_child(hint_box)


func _drop_callout() -> void:
	if hint_box != null:
		hint_box.queue_free()
	hint_box = null


## Forget the current hint without marking it seen (setting off, new game, week window over).
func _hide_hint() -> void:
	_drop_callout()
	hint_id = ""
	hint_mark = ""


func _loaded_hints() -> void:
	hints_late = game != null and game.week > 6
	_hide_hint()


func _dismiss_hint() -> void:
	if hint_id != "" and not Settings.hints_seen.has(hint_id):
		Settings.hints_seen.append(hint_id)
		Settings.save()
	_hide_hint()


func _fill_settings() -> void:
	if menu_settings == null:
		return
	filling_settings = true
	_wipe(settings_body)
	on_paper = true
	settings_body.add_child(_sheet_head("Settings"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	settings_body.add_child(cards)
	var col_w := clampf((size.x - 112.0) * 0.5, 440.0, 500.0)
	var sound_card := PanelContainer.new()
	sound_card.add_theme_stylebox_override("panel", _column_style())
	sound_card.custom_minimum_size = Vector2(col_w, 0)
	sound_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sound := VBoxContainer.new()
	sound.add_theme_constant_override("separation", 8)
	sound_card.add_child(sound)
	cards.add_child(sound_card)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _column_style())
	card.custom_minimum_size = Vector2(col_w, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	cards.add_child(card)
	var inner := col_w - 20.0
	sound.add_child(_label("Volume", 18, true))
	sound.add_child(_volume_row("Master", Settings.master, _set_master))
	sound.add_child(_volume_row("Music", Settings.music, _set_music))
	sound.add_child(_volume_row("SFX", Settings.sfx, _set_sfx))
	sound.add_child(_volume_row("Radio", Settings.radio, _set_radio))
	sound.add_child(_label("Water drips", 18, true))
	var drips := HBoxContainer.new()
	drips.add_theme_constant_override("separation", 8)
	for pair in [["off", "Off"], ["rare", "Rare"], ["often", "Often"]]:
		drips.add_child(_pick_button(str(pair[1]), Settings.drips == str(pair[0]), _pick_drips.bind(str(pair[0]))))
	sound.add_child(drips)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 8)
	var score := Copy.t("Music") + ": " + Copy.t("On" if Settings.music_on else "Off")
	var score_toggle := _pick_button(score, Settings.music_on, _toggle_music, 150.0)
	score_toggle.set_meta("music_toggle", true)
	toggles.add_child(score_toggle)
	var rooms := Copy.t("Room sounds") + ": " + Copy.t("On" if Settings.room_sounds else "Off")
	toggles.add_child(_pick_button(rooms, Settings.room_sounds, _toggle_room_sounds, 220.0))
	sound.add_child(toggles)
	sound.add_child(_label("Cable radio", 18, true))
	var radios := HFlowContainer.new()
	radios.add_theme_constant_override("h_separation", 8)
	radios.add_theme_constant_override("v_separation", 8)
	radios.add_child(_pick_button("Off", not Settings.radio_on, _pick_radio.bind(-1)))
	for pair in [[1, "Every week"], [2, "Every 2 weeks"], [0, "More often (every 3-4 days)"]]:
		var on := Settings.radio_on and Settings.radio_every == int(pair[0])
		radios.add_child(_pick_button(str(pair[1]), on, _pick_radio.bind(int(pair[0])), 0.0))
	sound.add_child(radios)
	var radio_hint := _label("Plays once a radio room is built.", 14)
	radio_hint.add_theme_color_override("font_color", PAPER_MUTED)
	sound.add_child(radio_hint)
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
	var scale_w := minf(112.0, (inner - 32.0) * 0.2)
	scales.add_child(_pick_button("Auto", Settings.ui_scale_auto, _pick_auto_scale, scale_w))
	for pair in [[0.75, "75%"], [1.0, "100%"], [1.25, "125%"], [1.5, "150%"]]:
		var scale := float(pair[0])
		scales.add_child(_pick_button(str(pair[1]), not Settings.ui_scale_auto and absf(Settings.ui_scale - scale) < 0.02, _pick_scale.bind(scale), scale_w))
	box.add_child(scales)
	var motion := Copy.t("Reduce motion") + ": " + Copy.t("On" if Settings.reduce_motion else "Off")
	box.add_child(_pick_button(motion, Settings.reduce_motion, _toggle_motion, minf(420.0, inner)))
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 8)
	var hints := Copy.t("Hints") + ": " + Copy.t("On" if Settings.hints_on else "Off")
	var hints_toggle := _pick_button(hints, Settings.hints_on, _toggle_hints, minf(200.0, (inner - 8.0) * 0.45))
	hints_toggle.set_meta("hints_toggle", true)
	hint_row.add_child(hints_toggle)
	var again := _pick_button("Show hints again", false, _hints_again, minf(260.0, (inner - 8.0) * 0.55))
	again.set_meta("hints_again", true)
	again.disabled = Settings.hints_seen.is_empty() and Settings.hints_on
	hint_row.add_child(again)
	box.add_child(hint_row)
	var quiet := Copy.t("Fewer audio cues") + ": " + Copy.t("On" if Settings.quiet_cues else "Off")
	box.add_child(_pick_button(quiet, Settings.quiet_cues, _toggle_quiet_cues, minf(420.0, inner)))
	var quiet_hint := _label("No hover ticks or drips. Room sounds only while a room is open.", 14)
	quiet_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiet_hint.custom_minimum_size = Vector2(minf(460.0, inner), 0)
	quiet_hint.add_theme_color_override("font_color", PAPER_MUTED)
	box.add_child(quiet_hint)
	on_paper = false
	filling_settings = false


func _fill_credits() -> void:
	if menu_credits == null:
		return
	_wipe(credits_body)
	on_paper = true
	credits_body.add_child(_sheet_head("Credits"))
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 6)
	credits_body.add_child(box)
	box.add_child(_label("Fonts", 20, true))
	var fonts := _label("Courier Prime, Big Shoulders Display, Oswald, and PT Mono. SIL Open Font License 1.1.", 16)
	fonts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fonts.custom_minimum_size = Vector2(600, 0)
	box.add_child(fonts)
	box.add_child(_label("Sounds", 20, true))
	var made := _label("Sound effects, station ambience, water drips, room loops, radio static and the menu tone were generated with ElevenLabs Sound Effects (paid plan).", 16)
	made.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	made.custom_minimum_size = Vector2(600, 0)
	box.add_child(made)
	var score := _label("Music was generated with ElevenLabs Music (paid plan).", 16)
	score.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score.custom_minimum_size = Vector2(600, 0)
	box.add_child(score)
	var sounds := _label("Kenney Interface Sounds (www.kenney.nl), CC0.", 14)
	sounds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sounds.custom_minimum_size = Vector2(600, 0)
	sounds.add_theme_color_override("font_color", PAPER_MUTED)
	box.add_child(sounds)
	var row := _label("hover.ogg  Interface Sounds  tick_001", 14)
	row.add_theme_color_override("font_color", PAPER_MUTED)
	box.add_child(row)
	box.add_child(_label("Disclaimer", 20, true))
	var fiction := _label(DISCLAIMER, 15)
	fiction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fiction.custom_minimum_size = Vector2(600, 0)
	box.add_child(fiction)
	if not Sound.has_ambient() or not Sound.has_drone():
		var missing := _label("Station ambience and the menu tone are not included yet.", 15)
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		missing.custom_minimum_size = Vector2(600, 0)
		box.add_child(missing)
	box.add_child(_version_label())
	on_paper = false


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
	elif which == "radio":
		Settings.radio = linear
	else:
		Settings.sfx = linear
	Settings.save()
	Sound.apply_buses()


func _set_radio(value: float) -> void:
	_set_volume("radio", value)


func _pick_drips(mode: String) -> void:
	Settings.drips = mode
	Settings.save()
	Sound.schedule_drip()
	_fill_settings()


func _toggle_room_sounds() -> void:
	Settings.room_sounds = not Settings.room_sounds
	Settings.save()
	_sync_room_sound()
	_fill_settings()


func _toggle_music() -> void:
	Settings.music_on = not Settings.music_on
	Settings.save()
	_fill_settings()


func _toggle_quiet_cues() -> void:
	Settings.quiet_cues = not Settings.quiet_cues
	Settings.save()
	Sound.schedule_drip()
	_sync_room_sound()
	_fill_settings()


## -1 turns the radio off; 0 is twice a week.
func _pick_radio(weeks: int) -> void:
	Settings.radio_on = weeks >= 0
	if Settings.radio_on:
		Settings.radio_every = weeks
	Settings.save()
	if not Settings.radio_on:
		_hide_radio()
	_fill_settings()


func _pick_lang(code: String) -> void:
	if Copy.lang == code:
		return
	Settings.language = code
	Settings.save()
	PlaytestLog.event("settings", {"language": code})
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
	Settings.ui_scale_auto = false
	Settings.save()
	if not shot_mode:
		Settings.apply_scale(get_window())
	_fill_settings()


func _pick_auto_scale() -> void:
	Settings.ui_scale_auto = true
	Settings.save()
	if not shot_mode:
		Settings.apply_scale(get_window())
	_fill_settings()


func _rescale() -> void:
	Settings.apply_scale(get_window())


func _toggle_motion() -> void:
	Settings.reduce_motion = not Settings.reduce_motion
	Settings.save()
	_fill_settings()


func _toggle_hints() -> void:
	Settings.hints_on = not Settings.hints_on
	Settings.save()
	if not Settings.hints_on:
		_hide_hint()
	_fill_settings()


func _hints_again() -> void:
	Settings.hints_on = true
	Settings.hints_seen = []
	Settings.save()
	_fill_settings()


## A small paper callout beside the element it points at. It takes no mouse input, so the element under it
## still works; a click on it dismisses it.
class HintCallout extends PanelContainer:
	signal dismissed
	var text := ""
	var font: Font
	var target := Rect2()
	var below := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 40
		var face := StyleBoxFlat.new()
		face.bg_color = Color("efe6d2")
		face.border_color = Color("3a2610")
		face.set_border_width_all(2)
		face.set_corner_radius_all(4)
		face.set_content_margin_all(10)
		face.shadow_color = Color(0, 0, 0, 0.45)
		face.shadow_size = 6
		add_theme_stylebox_override("panel", face)
		var words := Label.new()
		words.text = text
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size = Vector2(260, 0)
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_font_size_override("font_size", 15)
		words.add_theme_color_override("font_color", Color("24180e"))
		if font != null:
			words.add_theme_font_override("font", font)
		add_child(words)

	## Above the target when there is room under `top`, else below it; always inside the view.
	func point_at(spot: Rect2, view: Vector2, top: float = 8.0) -> void:
		target = spot
		var want := get_combined_minimum_size()
		size = want
		var gap := 14.0
		var x := spot.get_center().x - want.x * 0.5
		var y := spot.position.y - want.y - gap
		below = y < top
		if below:
			y = spot.end.y + gap
		position = Vector2(clampf(x, 8.0, maxf(8.0, view.x - want.x - 8.0)), clampf(y, top, maxf(top, view.y - want.y - 8.0)))
		queue_redraw()

	func _draw() -> void:
		var tip := target.get_center() - position
		var x := clampf(tip.x, 14.0, size.x - 14.0)
		var edge := 0.0 if below else size.y
		var out := -10.0 if below else 10.0
		var tri := PackedVector2Array([Vector2(x - 9.0, edge), Vector2(x + 9.0, edge), Vector2(x, edge + out)])
		draw_colored_polygon(tri, Color("efe6d2"))
		draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), Color("3a2610"), 2.0, true)

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if get_global_rect().has_point(get_global_mouse_position()):
				dismissed.emit()


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
	var drag_card: Callable
	var can_drop: Callable
	var on_drop: Callable
	var _armed := false
	var _dragged := false
	var _calm: StyleBoxFlat
	var _lit: StyleBoxFlat

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_DRAG
		tooltip_text = Copy.t("Click for details. Drag onto a room to assign.")
		_calm = StyleBoxFlat.new()
		_calm.bg_color = Color(1, 1, 1, 0.07)
		_calm.set_content_margin_all(4)
		_calm.content_margin_right = 20
		_calm.set_corner_radius_all(4)
		_lit = _calm.duplicate()
		_lit.bg_color = Color(0.89, 0.65, 0.23, 0.22)
		_lit.border_color = Color(0.89, 0.65, 0.23, 0.8)
		_lit.set_border_width_all(1)
		add_theme_stylebox_override("panel", _calm)
		mouse_entered.connect(func() -> void: add_theme_stylebox_override("panel", _lit))
		mouse_exited.connect(func() -> void: add_theme_stylebox_override("panel", _calm))

	func _draw() -> void:
		var x := size.x - 12.0
		var y := size.y * 0.5 - 6.0
		for i in 3:
			for j in 2:
				draw_circle(Vector2(x + float(j) * 5.0, y + float(i) * 6.0), 1.4, Color(1, 1, 1, 0.35))

	func _can_drop_data(at_position: Vector2, data) -> bool:
		return can_drop.is_valid() and bool(can_drop.call(at_position, data))

	func _drop_data(at_position: Vector2, data) -> void:
		if on_drop.is_valid():
			on_drop.call(at_position, data)

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
		if drag_card.is_valid():
			set_drag_preview(drag_card.call(person_id))
		else:
			var preview := Label.new()
			preview.text = person_name
			preview.add_theme_color_override("font_color", Color("efe6d2"))
			set_drag_preview(preview)
		modulate.a = 0.45
		return {"person": person_id}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			modulate.a = 1.0


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
		"listening_post": "res://assets/rooms/room_listening_post.webp",
	}
	const TIER_ART := "res://assets/rooms/upgrades/room_%s_t%d.png"
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
		"listening_post": Color(0.35, 0.95, 0.55, 0.22),
		"platform": Color(1.0, 0.72, 0.40, 0.14),
	}
	# Backdrop image: tunnel rail, and how much of each side is the mouth.
	const BACKDROP_RAIL := 0.783
	# Inner lip of each tunnel mouth, so the arches meet the station edges.
	const BACKDROP_SIDE := 0.147
	## Share of the view height the camera may show as sky above the station.
	const SKY_SHARE := 0.2
	const OPEN_WIDTH := 0.96
	const PLATFORM_RAIL := 0.96
	const SKYLINE_FRAC := 0.164
	const SOIL_LIP := 0.032
	const ROCK_LIP := 0.0
	var art := {}
	var tier_cache := {}
	var poses := {}
	var figure_scale_px := 660.0
	var lamp_glow: Texture2D
	var probe_wash: Texture2D
	var offline_wash: Texture2D
	var offline_wash_256: Texture2D
	var grey_plates := {}
	var cell_rock: Texture2D
	var cell_dug: Texture2D
	## Room separation, kept light (Underline_Props_Pack_Light): one slim steel column on every line between cells,
	## one thin riveted beam from the pack's ceiling beam across every gap between levels. Pictures only, no geometry.
	var sep_pillar: Texture2D
	var edge_beam: Texture2D
	## Column width as a share of a cell, and which strip of the beam sheet is used (share of the sheet).
	const PILLAR_W := 0.044
	const BEAM_SRC := Rect2(0.0, 0.345, 1.0, 0.18)
	## Room lamps keep this far in from the column on each side, so their light never reaches the next room.
	const LIGHT_PAD := 0.06
	## Soft lamp cones under the three painted lamps (share of the room width), how far down they start, their size
	## and strength. The cone picture fades out at its sides and before the floor.
	const LAMP_X := [0.2, 0.5, 0.79]
	const CONE_TOP := 0.28
	const CONE_W := 0.3
	const CONE_H := 0.55
	const CONE_STRENGTH := 0.16
	## Rooms whose background (Underline_Rooms_Redraw_v2) paints its own light: no cones over them.
	const SELF_LIT := ["quarters", "workshop", "hydroponics", "meeting_hall", "infirmary", "generator", "air_filter", "platform"]
	var cones := {}
	## The few key props the painted rooms do not already show, each standing on the floor: x is the prop's centre,
	## foot its bottom and h its height, as shares of the room.
	## Empty while the v2 backgrounds paint their own key props (the generator's jerrycans replaced the fuel drums).
	const PROPS := {}
	var prop_tex := {}
	var pile_tex := {}
	var dust_tex: Texture2D
	var dust_tried := false
	var clear_dust_cell := Vector2i(-1, -1)
	var clear_dust_until := 0
	var clear_dust_seq := 0
	var backdrop_tex: Texture2D
	var scaffold: Texture2D
	var ghosts := {}
	var room_figs := {}
	var body_figs: Array = []
	var fig_variants := {}
	var soft_figs := {}
	var fig_tint_mix := 0.0
	const FIG_DIR := "res://assets/figures/poses"
	## Drawn stems for the crew on a building site: the hammer and the crate.
	const BUILDER_FIGS := ["workshop_02", "workshop_03"]
	## Site crew loop: strokes a second, and how high the body rises between strokes (share of the cell height).
	const CREW_BEAT := 1.1
	const CREW_BOB := 0.022
	const CREW_LEAN := 0.1
	## Warm rim on working figures: colour, screen px out from the silhouette, and the silhouette's cap in px.
	const RIM := Color(1.0, 0.74, 0.4, 0.55)
	const RIM_PX := 1.6
	const RIM_H := 240
	var rim_cache := {}
	const SCAFFOLD := "res://assets/construction/scaffold.webp"
	var glow := {}
	var more_hits: Array = []
	## "?" discs next to room signs: {rect, type, uid} in screen space.
	var help_hits: Array = []
	var art_aspect := 1.6
	var hover := Vector2i(-1, -1)
	var place_type := ""
	var place_level := -1
	var place_cell := -1
	var place_lock := false
	var block_glow := false
	var dust: Array = []
	var seam_seen := {}
	var seam_init := false
	var drag_id := ""
	var drop_cell := Vector2i(-1, -1)
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
	## Room uid -> msec when its upgrade flash ends.
	var flash := {}
	## Room uid -> msec when the first-fit check burst ends.
	var fitted_flash := {}
	## Room uid -> the numeral its sign showed last frame (for the checks).
	var sign_tiers := {}
	var sign_incidents := {}
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
		_clamp_pan()
		queue_redraw()

	func _frame_station() -> void:
		var base := _fit_zoom()
		zoom = base * maxf(user_zoom, 1.0)
		var area := _content()
		var station_rect := _station_rect()
		var pan_x := area.get_center().x - station_rect.get_center().x * zoom
		var pan_y := area.position.y + area.size.y - 6.0 - (station_rect.position.y + station_rect.size.y) * zoom
		pan = Vector2(pan_x, pan_y)
		_clamp_pan()
		queue_redraw()

	## What the camera may show, on screen at the current pan and zoom: the station, the painted backdrop at
	## its sides, a band of sky above it and a thin lip of rock below.
	func view_bounds() -> Rect2:
		var station_rect := _station_rect()
		var side := 24.0 / maxf(zoom, 0.0001)
		if backdrop_tex != null:
			side = station_rect.size.x * BACKDROP_SIDE / (1.0 - BACKDROP_SIDE * 2.0)
		var area := _content()
		var sky := area.size.y * SKY_SHARE / maxf(zoom, 0.0001)
		var lip := 6.0 / maxf(zoom, 0.0001)
		var world := Rect2(station_rect.position.x - side, station_rect.position.y - sky,
			station_rect.size.x + side * 2.0, station_rect.size.y + sky + lip)
		return Rect2(pan + world.position * zoom, world.size * zoom)

	## Keeps the dark void out of the view: content smaller than the view stays inside it, content larger than
	## the view keeps covering it, on each axis.
	func _clamp_pan() -> void:
		var area := _content()
		var shown := view_bounds()
		var shift := Vector2.ZERO
		for axis in 2:
			var lo: float = shown.position[axis]
			var hi: float = shown.end[axis]
			var a_lo: float = area.position[axis]
			var a_hi: float = area.end[axis]
			if hi - lo <= a_hi - a_lo:
				if lo < a_lo:
					shift[axis] = a_lo - lo
				elif hi > a_hi:
					shift[axis] = a_hi - hi
			elif lo > a_lo:
				shift[axis] = a_lo - lo
			elif hi < a_hi:
				shift[axis] = a_hi - hi
		pan += shift

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
		var alt := ArtPack.load_texture("res://assets/rooms/room_listening_post_alt.webp")
		if alt != null:
			art["listening_post_alt"] = alt
		probe_wash = ArtPack.load_texture("res://assets/overlays/room_probe.webp")
		offline_wash = ArtPack.load_texture("res://assets/overlays/room_offline.webp")
		offline_wash_256 = ArtPack.load_texture("res://assets/overlays/room_offline_256.webp")
		cell_rock = ArtPack.load_texture("res://assets/cells/cell_rock.webp")
		sep_pillar = ArtPack.load_texture("res://assets/separators/sep_slim_steel_column.webp")
		edge_beam = ArtPack.load_texture("res://assets/edges/edge_ceiling_beam_albedo.png")
		cell_dug = ArtPack.load_texture("res://assets/cells/cell_dug.webp")
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
		if ResourceLoader.exists(SCAFFOLD):
			scaffold = ArtPack.load_texture(SCAFFOLD)
		_load_incoming_figures()

	## body_figs and room_figs hold pose stems; fig_variants maps a stem to its base texture followed by every
	## palette in FIG_DIR/palettes/<name>/ that has the same stem. FIG_DIR/figures.json comes with the drawn
	## resident set and sets how far their tint is lightened (soft_figs); without it every pose keeps the full tint.
	func _load_incoming_figures() -> void:
		if not DirAccess.dir_exists_absolute(FIG_DIR):
			return
		var manifest = null
		if FileAccess.file_exists(FIG_DIR.path_join("figures.json")):
			manifest = JSON.parse_string(FileAccess.get_file_as_string(FIG_DIR.path_join("figures.json")))
		if manifest is Dictionary:
			fig_tint_mix = clampf(float(manifest.get("tint_mix", 0.0)), 0.0, 1.0)
		var base := _fig_textures(FIG_DIR)
		var stems: Array = base.keys()
		stems.sort()
		var palette_dir := FIG_DIR.path_join("palettes")
		var palettes: Array = []
		if DirAccess.dir_exists_absolute(palette_dir):
			var names := Array(DirAccess.get_directories_at(palette_dir))
			names.sort()
			for name in names:
				palettes.append(_fig_textures(palette_dir.path_join(str(name))))
		for stem in stems:
			var variants: Array = [base[stem]]
			for palette in palettes:
				if palette.has(stem):
					variants.append(palette[stem])
			fig_variants[stem] = variants
			if manifest is Dictionary:
				for texture in variants:
					soft_figs[texture] = true
			if str(stem).begins_with("body_"):
				body_figs.append(stem)
				continue
			for type in ART:
				if str(stem).begins_with(str(type) + "_"):
					if not room_figs.has(type):
						room_figs[type] = []
					room_figs[type].append(stem)
					break

	## Stem -> texture for one folder, one file per stem (webp over png when both are there).
	func _fig_textures(dir: String) -> Dictionary:
		var paths := {}
		for file in DirAccess.get_files_at(dir):
			var name := str(file).trim_suffix(".import").trim_suffix(".remap")
			var ext := name.get_extension().to_lower()
			if ext != "png" and ext != "webp":
				continue
			var stem := name.get_basename()
			if not paths.has(stem) or ext == "webp":
				paths[stem] = dir.path_join(name)
		var out := {}
		for stem in paths:
			if not ResourceLoader.exists(str(paths[stem])):
				continue
			var tex := ArtPack.load_texture(str(paths[stem]))
			if tex != null:
				out[stem] = tex
		return out

	## A resident's pose from `stems`, and the palette of it, both fixed by the resident id.
	func _fig_for(stems: Array, id: String) -> Texture2D:
		var stem: String = stems[int(_id_hash(id)) % stems.size()]
		var variants: Array = fig_variants.get(stem, [])
		if variants.is_empty():
			return null
		return variants[int(_id_hash(id + "#palette")) % variants.size()]

	## Figures for people seen together, in order: each takes its own stem by id hash while the group still has
	## stems it has not used, then a palette of that stem nobody in the group wears yet. Fixed by the ids and
	## their order (room staff order is saved), so a reload draws the same people. null where no stem is drawn.
	func _figs_for_group(stems: Array, ids: Array) -> Array:
		var out: Array = []
		var used_stems := {}
		var worn := {}
		for id in ids:
			var key := str(id)
			if stems.is_empty():
				out.append(null)
				continue
			var n := stems.size()
			var at := int(_id_hash(key)) % n
			if used_stems.size() < n:
				for step in n:
					if not used_stems.has(stems[(at + step) % n]):
						at = (at + step) % n
						break
			var stem := str(stems[at])
			used_stems[stem] = true
			var variants: Array = fig_variants.get(stem, [])
			if variants.is_empty():
				out.append(null)
				continue
			var m := variants.size()
			var pick := int(_id_hash(key + "#palette")) % m
			for step in m:
				if not worn.has(variants[(pick + step) % m]):
					pick = (pick + step) % m
					break
			worn[variants[pick]] = true
			out.append(variants[pick])
		return out

	## Clears every pixel with a near-clear pixel (alpha byte 20 or less) or the image edge within `radius` in a
	## square window, and greys the rest.
	func _erode_alpha(image: Image, radius: int) -> Image:
		var src: Image = image.duplicate()
		src.convert(Image.FORMAT_RGBA8)
		var out: Image = src.duplicate()
		var w: int = src.get_width()
		var h: int = src.get_height()
		var data: PackedByteArray = src.get_data()
		var near := PackedByteArray()
		near.resize(w * h)
		var sums := PackedInt32Array()
		sums.resize(maxi(w, h) + 1)
		for y in h:
			var row := y * w
			for x in w:
				sums[x + 1] = sums[x] + (1 if data[(row + x) * 4 + 3] <= 20 else 0)
			for x in w:
				if x < radius or x + radius >= w or sums[x + radius + 1] - sums[x - radius] > 0:
					near[row + x] = 1
		var cleared := PackedByteArray()
		cleared.resize(w * h)
		for x in w:
			for y in h:
				sums[y + 1] = sums[y] + near[y * w + x]
			for y in h:
				if y < radius or y + radius >= h or sums[y + radius + 1] - sums[y - radius] > 0:
					cleared[y * w + x] = 1
		for y in h:
			var row := y * w
			for x in w:
				if data[(row + x) * 4 + 3] <= 5:
					continue
				if cleared[row + x] == 1:
					out.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var c: Color = src.get_pixel(x, y)
				var v := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				out.set_pixel(x, y, Color(v, v, v, c.a))
		return out

	func _process(_delta: float) -> void:
		life_t += _delta
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
		drop_cell = Vector2i(-1, -1)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT and hover != Vector2i(-1, -1):
			hover = Vector2i(-1, -1)
			if station != null:
				station._yard_hover(-1, -1)
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMagnifyGesture:
			_zoom_at(event.position, event.factor)
			accept_event()
			return
		if event is InputEventPanGesture:
			pan += event.delta
			_clamp_pan()
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
					_clamp_pan()
			if not moved:
				var over: Dictionary = _hit(event.position)
				var next := Vector2i(-1, -1)
				if not over.is_empty() and _kind(over) != "hidden":
					next = Vector2i(int(over.level), int(over.cell))
				if next != hover:
					hover = next
					mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover.x >= 0 else Control.CURSOR_ARROW
					if station != null:
						station._yard_hover(hover.x, hover.y)
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

	func nudge_into_view(level: int, cell: int) -> void:
		var box := cell_screen(level, cell)
		var view := _content().grow(-16.0)
		var shift := Vector2.ZERO
		if box.position.x < view.position.x:
			shift.x = view.position.x - box.position.x
		elif box.end.x > view.end.x:
			shift.x = view.end.x - box.end.x
		if box.position.y < view.position.y:
			shift.y = view.position.y - box.position.y
		elif box.end.y > view.end.y:
			shift.y = view.end.y - box.end.y
		if shift == Vector2.ZERO:
			return
		pan += shift
		_clamp_pan()
		queue_redraw()

	func _note_tap(screen: Vector2) -> void:
		var help := _help_at(screen)
		if not help.is_empty():
			pending_level = -1
			station.help_unfold = true
			station._show_room(str(help.uid))
			return
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
		_clamp_pan()
		queue_redraw()

	func _zoom_to_rect(rect: Rect2) -> void:
		var area := _content()
		var zx := area.size.x / maxf(rect.size.x, 1.0)
		var zy := area.size.y / maxf(rect.size.y, 1.0)
		var base := _fit_zoom()
		user_zoom = clampf(minf(zx, zy) * 0.92 / maxf(base, 0.0001), 1.0, 8.0)
		zoom = base * user_zoom
		pan = area.get_center() - rect.get_center() * zoom
		_clamp_pan()
		queue_redraw()

	## The point under the cursor stays under it; the view only moves further when the clamp needs it.
	func _zoom_at(screen: Vector2, factor: float) -> void:
		var world := _unview(screen)
		var base := _fit_zoom()
		user_zoom = clampf(user_zoom * factor, 1.0, 8.0)
		zoom = base * user_zoom
		if user_zoom <= 1.001:
			focused = Vector2i(-1, -1)
		pan = screen - world * zoom
		_clamp_pan()
		queue_redraw()

	func _unview(screen: Vector2) -> Vector2:
		return (screen - pan) / zoom

	func _can_drop_data(at_position: Vector2, data) -> bool:
		if typeof(data) != TYPE_DICTIONARY or not data.has("person"):
			return false
		var hit: Dictionary = _hit(at_position)
		var cell := Vector2i(-1, -1)
		if not hit.is_empty() and str(hit.room) != "":
			cell = Vector2i(int(hit.level), int(hit.cell))
		if cell != drop_cell:
			drop_cell = cell
			queue_redraw()
		return cell.x >= 0

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
		_poll_clear_burst()
		more_hits.clear()
		help_hits.clear()
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
		_draw_merge_ghost(geo)
		_draw_structure(geo)
		_draw_pops(geo)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_room_chrome(geo)
		_draw_merge_tag(geo)
		_draw_seam_dust()
		_draw_hover_label(geo)

	## How far a rib reaches into a cell from each side (half its width), so room notes and badges sit clear of it.
	func _wall_inset() -> float:
		if sep_pillar == null:
			return 0.0
		return float(_geo().w) * PILLAR_W * 0.5

	## The part of a cell a room's lamps may light: clear of the ribs at the sides.
	func _light_rect(rect: Rect2) -> Rect2:
		return rect.grow_individual(-rect.size.x * LIGHT_PAD, 0.0, -rect.size.x * LIGHT_PAD, 0.0)

	## Thin separators: a beam across every gap between levels and above and below the station, then a rib on every
	## cell boundary and at both ends, from the middle of the beam above to the middle of the beam below.
	func _draw_structure(geo: Dictionary) -> void:
		var w := float(geo.w)
		var h := float(geo.h)
		var band := float(geo.band)
		var origin: Vector2 = geo.origin
		if edge_beam != null:
			var sheet := edge_beam.get_size()
			var src := Rect2(BEAM_SRC.position * sheet, BEAM_SRC.size * sheet)
			var beam_h := maxf(band, h * 0.06)
			var tile_w := beam_h * src.size.x / maxf(src.size.y, 1.0)
			for gap in 4:
				var mid := origin.y + float(gap) * (h + band) - band * 0.5
				var x := origin.x
				var end := origin.x + w * 6.0
				while x < end - 0.5:
					var slice := minf(tile_w, end - x)
					draw_texture_rect_region(edge_beam, Rect2(x, mid - beam_h * 0.5, slice, beam_h),
						Rect2(src.position, Vector2(src.size.x * slice / tile_w, src.size.y)))
					x += slice
		if sep_pillar != null:
			var col_w := w * PILLAR_W
			for level in 3:
				var top := origin.y + float(level) * (h + band)
				for edge in 7:
					draw_texture_rect(sep_pillar, Rect2(origin.x + float(edge) * w - col_w * 0.5, top, col_w, h), false)

	## A room type's soft lamp cone from the pack, or the untinted one with the room's lamp colour.
	func _cone(room_type: String) -> Array:
		if not cones.has(room_type):
			var path := "res://assets/lights/glow_soft_%s.webp" % room_type
			if ResourceLoader.exists(path):
				cones[room_type] = [ArtPack.load_texture(path), Color.WHITE]
			else:
				var typed: Color = LAMP.get(room_type, Color(1.0, 0.78, 0.46))
				cones[room_type] = [ArtPack.load_texture("res://assets/lights/glow_soft_white.webp"), Color(typed.r, typed.g, typed.b)]
		return cones[room_type]

	func _draw_props(rect: Rect2, room_type: String) -> void:
		for item in PROPS.get(room_type, []):
			var path: String = item.art
			if not prop_tex.has(path):
				prop_tex[path] = ArtPack.load_texture(path)
			var tex: Texture2D = prop_tex[path]
			if tex == null:
				continue
			var ph := rect.size.y * float(item.h)
			var pw := ph * tex.get_width() / maxf(float(tex.get_height()), 1.0)
			var foot := rect.position.y + rect.size.y * float(item.foot)
			draw_texture_rect(tex, Rect2(rect.position.x + rect.size.x * float(item.x) - pw * 0.5, foot - ph, pw, ph), false)

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
		var screen_h := size.y
		if station != null and station.size.y > 8.0:
			screen_h = station.size.y
		var band_h := minf(0.22 * screen_h / maxf(zoom, 0.001), maxf(soil_y - (72.0 - pan.y) / maxf(zoom, 0.001), 8.0))
		var band := Rect2(dest.position.x, soil_y - band_h, dest.size.x, band_h)
		var sky_w := tex.x
		var sky_h := tex.y * SKYLINE_FRAC
		var cover := maxf(band.size.x / sky_w, band.size.y / sky_h)
		var vis_w := band.size.x / cover
		var vis_h := band.size.y / cover
		var sky_src := Rect2((sky_w - vis_w) * 0.5, sky_h - vis_h, vis_w, vis_h)
		var sky_top := (72.0 - pan.y) / maxf(zoom, 0.001)
		if station != null and station.hud != null and station.hud.size.y > 8.0:
			sky_top = (station.hud.size.y - pan.y) / maxf(zoom, 0.001)
		if band.position.y > sky_top:
			draw_rect(Rect2(dest.position.x, sky_top, dest.size.x, band.position.y - sky_top), Color(0.11, 0.13, 0.16))
		draw_texture_rect_region(backdrop_tex, band, sky_src)

	func _draw_cell(rect: Rect2, level: int, cell: int) -> void:
		var shift := 0.0
		if shake_cell == Vector2i(level, cell) and (shake_px != 0.0 or Time.get_ticks_msec() < shake_until):
			shift = shake_px if shake_px != 0.0 else sin(Time.get_ticks_msec() / 45.0) * 8.0
		if shift != 0.0:
			rect.position += Vector2(shift, 0.0)
		var clearing: bool = station._clearing_cell(level, cell)
		if not clearing and _job_span(level, cell).x >= 0:
			_draw_site(rect, level, cell)
			if hover == Vector2i(level, cell):
				draw_rect(rect.grow(-2.0), Color(0.93, 0.78, 0.45, 0.9), false, 2.0)
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
			draw_rect(rect, Color(0, 0, 0, 0.5))
			_draw_rough(rect, level * 6 + cell, 0.7)
		elif kind == "undug":
			_blit_fill(cell_rock, rect)
			draw_rect(rect, Color(0, 0, 0, 0.3))
			_draw_rough(rect, level * 6 + cell, 1.0)
		elif kind == "dug":
			if cell_dug != null:
				_blit_room(cell_dug, rect)
			else:
				_paint_rock(rect, level * 6 + cell)
			_draw_dug_props(rect, level * 6 + cell, str(spot.get("pile", "")) != "")
		else:
			draw_rect(rect, Color(0.08, 0.07, 0.06))
			var tier_tex: Texture2D = tier_art(room_type, int(room.upgrade)) if room != null else null
			var texture = tier_tex if tier_tex != null else art.get(room_type, null)
			if room_type == "listening_post" and tier_tex == null:
				texture = _listening_plate()
			var shut := room != null and int(room.get("disabled", 0)) > 0
			var plate := rect
			if texture != null:
				plate = _blit_room(_grey_plate(texture) if shut else texture, rect)
			if shut:
				var wash := _offline_wash(plate)
				if wash != null:
					draw_texture_rect(wash, plate, false)
			elif room_type == "listening_post" and station.game.listening_probe_live() and probe_wash != null:
				draw_texture_rect(probe_wash, _art_rect(room_type, rect), false)
			_draw_props(rect, room_type)
			var salt := level * 6 + cell
			var weak: bool = room != null and (bool(room.get("browned", false)) or station.dark_now.has(str(room.uid)) or station.power_loss.has(str(room.uid)))
			var off: bool = room != null and (bool(room.get("offline", false)) or shut)
			_draw_lamp_glow(rect, room_type, salt, weak, off)
			if room != null and not off and not weak and room_type in ["generator", "air_filter"]:
				_draw_steam(rect, room_type, salt)
			if room != null and not off:
				_draw_motes(rect, salt)
			if room != null and int(room.upgrade) > 0 and tier_tex == null:
				_draw_tier_light(rect, int(room.upgrade))
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
			if int(room.upgrade) > 0:
				draw_rect(rect.grow(-1.0), Color(station.BRASS, 0.9), false, 1.0 + float(int(room.upgrade)))
			_draw_flash(rect, str(room.uid))
			if int(room.get("push_tint_until", 0)) >= station.game.week:
				draw_rect(rect, Color(0.05, 0.03, 0.02, 0.5))
		if _under_water(spot, kind):
			_draw_water(rect, level, cell)
		if kind == "undug":
			_draw_dig_outline(rect, level, cell)
		if kind == "dug" and str(spot.get("pile", "")) != "":
			_draw_pile(rect, str(spot.pile))
		if clearing:
			_draw_clear_work(rect, level, cell)
		_draw_clear_burst(rect, level, cell)
		if drag_id != "" and kind == "room" and room != null:
			var uid := str(room.uid)
			var preview: Dictionary = station.game.assign_preview(drag_id, uid)
			var here := drop_cell == Vector2i(level, cell)
			if bool(preview.ok):
				draw_rect(rect, Color(0.95, 0.84, 0.55, 0.4 if here else 0.24))
				draw_rect(rect.grow(-4.0), Color(0.95, 0.84, 0.55, 0.95), false, 5.0 if here else 3.0)
			elif bool(preview.get("full", false)) and station._swap_partner(drag_id, uid) != "":
				draw_rect(rect, Color(0.55, 0.78, 1.0, 0.3 if here else 0.12))
				draw_rect(rect.grow(-4.0), Color(0.62, 0.82, 1.0, 0.9), false, 4.0 if here else 2.0)
				if here:
					var out: Dictionary = station.game.people.get(station._swap_partner(drag_id, uid), {})
					_note_bar(rect, Copy.t("Swap with %s") % station._resident_name(out), Color(0.07, 0.14, 0.24, 0.94), Color(0.62, 0.82, 1.0))
			elif here:
				draw_rect(rect.grow(-4.0), Color(0.9, 0.35, 0.28, 0.9), false, 3.0)
				_note_bar(rect, str(preview.reason), Color(0.28, 0.08, 0.06, 0.94), Color(0.9, 0.35, 0.28, 0.95))
		if hover == Vector2i(level, cell) and kind != "hidden":
			draw_rect(rect, Color(0.93, 0.78, 0.45, 0.16))
			draw_rect(rect.grow(-2.0), Color(0.93, 0.78, 0.45, 0.9), false, 2.0)
		if shake_reason != "" and shake_cell == Vector2i(level, cell):
			_note_bar(rect, shake_reason, Color(0.28, 0.08, 0.06, 0.94), Color(0.9, 0.35, 0.28, 0.95))

	func _note_bar(rect: Rect2, text: String, back: Color, edge: Color) -> void:
		var bar_font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			bar_font = station.body_font
		var text_size: Vector2 = bar_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var bar_w := maxf(rect.size.x, text_size.x + 16.0)
		var bar := Rect2(rect.get_center().x - bar_w * 0.5, rect.position.y + rect.size.y - 26, bar_w, 26)
		draw_rect(bar, back)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x, 2)), edge)
		draw_string(bar_font, bar.position + Vector2(8, 18), text, HORIZONTAL_ALIGNMENT_LEFT, bar.size.x - 12, 15, Color("f4efe4"))

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

	func _blit_room(texture: Texture2D, rect: Rect2) -> Rect2:
		var tex := texture.get_size()
		if tex.x < 1.0 or tex.y < 1.0:
			return rect
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
		return dest

	## Disabled week (Listening Post blown, or any room_disabled): the same plate, grey, under the tape wash.
	func _grey_plate(texture: Texture2D) -> Texture2D:
		if grey_plates.has(texture):
			var cached = grey_plates[texture]
			return cached if cached is Texture2D else texture
		var image := texture.get_image()
		if image == null or image.is_empty():
			grey_plates[texture] = false
			return texture
		image = image.duplicate()
		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)
		image.adjust_bcs(1.0, 1.0, 0.0)
		var grey := ImageTexture.create_from_image(image)
		grey_plates[texture] = grey
		return grey

	func _offline_wash(dest: Rect2) -> Texture2D:
		if dest.size.x <= 256.0 and offline_wash_256 != null:
			return offline_wash_256
		return offline_wash

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
			"listening_post":
				return "Listen"
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

	func _poll_clear_burst() -> void:
		var burst: Dictionary = station.game.clear_burst
		if burst.is_empty():
			return
		var seq := int(burst.get("seq", 0))
		if seq == clear_dust_seq:
			return
		clear_dust_seq = seq
		clear_dust_cell = Vector2i(int(burst.level), int(burst.cell))
		clear_dust_until = Time.get_ticks_msec() + 700

	func _pile_texture(kind: String) -> Texture2D:
		if pile_tex.has(kind):
			var cached = pile_tex[kind]
			return cached if cached is Texture2D else null
		var tex := ArtPack.pile_texture(kind)
		pile_tex[kind] = tex if tex != null else false
		return tex

	func _dust_texture() -> Texture2D:
		if not dust_tried:
			dust_tried = true
			dust_tex = ArtPack.clear_dust_texture()
		return dust_tex

	## Floor clutter. The 210-wide overlay sits at about two fifths of the cell; a mound stands in if the art is missing.
	func _draw_pile(rect: Rect2, kind: String) -> void:
		var tex := _pile_texture(kind)
		if tex == null:
			_draw_mound(rect, kind)
			return
		var pw := rect.size.x * 0.42
		var ph := pw * float(tex.get_height()) / maxf(float(tex.get_width()), 1.0)
		if ph > rect.size.y * 0.46:
			ph = rect.size.y * 0.46
			pw = ph * float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
		var dest := Rect2(rect.get_center().x - pw * 0.5, rect.end.y - ph - rect.size.y * 0.05, pw, ph)
		draw_texture_rect(tex, dest, false)

	func _draw_mound(rect: Rect2, kind: String) -> void:
		var col := Color(0.45, 0.40, 0.34)
		if kind == "scrap":
			col = Color(0.55, 0.32, 0.18)
		elif kind == "coal":
			col = Color(0.18, 0.16, 0.15)
		var w := rect.size.x * 0.42
		var h := rect.size.y * 0.22
		var base := Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.end.y - rect.size.y * 0.08)
		var mound := PackedVector2Array([
			base,
			base + Vector2(w * 0.16, -h * 0.5),
			base + Vector2(w * 0.48, -h),
			base + Vector2(w * 0.8, -h * 0.42),
			base + Vector2(w, 0.0),
		])
		draw_colored_polygon(mound, col)
		draw_polyline(mound, col.darkened(0.35), maxf(1.0, rect.size.y * 0.008))

	## Dust while a crew is on the pile. Reduce-motion keeps a still puff and the progress chip; it does not pulse.
	func _draw_clear_work(rect: Rect2, level: int, cell: int) -> void:
		var still: bool = station._motion_off()
		var tex := _dust_texture()
		if tex != null:
			var sway := 0.0 if still else sin(Time.get_ticks_msec() / 280.0)
			var s := rect.size.y * (0.28 if still else 0.30 + sway * 0.04)
			var at := rect.get_center() + Vector2(0.0, rect.size.y * 0.08)
			var alpha := 0.5 if still else 0.42 + absf(sway) * 0.18
			draw_texture_rect(tex, Rect2(at.x - s, at.y - s, s * 2.0, s * 2.0), false, Color(1, 1, 1, alpha))
		if not still:
			_draw_dig_haze(rect, level * 6 + cell)
		draw_rect(rect.grow(-5.0), Color(0.72, 0.58, 0.32, 0.8), false, 2.0)

	func _draw_clear_burst(rect: Rect2, level: int, cell: int) -> void:
		if station._motion_off() or clear_dust_cell != Vector2i(level, cell):
			return
		var now := Time.get_ticks_msec()
		if now >= clear_dust_until:
			return
		var tex := _dust_texture()
		if tex == null:
			return
		var u := 1.0 - float(clear_dust_until - now) / 700.0
		var s := rect.size.y * (0.22 + 0.45 * u)
		draw_texture_rect(tex, Rect2(rect.get_center().x - s, rect.get_center().y - s * 0.4, s * 2.0, s * 2.0), false, Color(1, 1, 1, 0.75 * (1.0 - u)))

	func _lamp_texture() -> Texture2D:
		if lamp_glow != null:
			return lamp_glow
		var n := 64
		var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var center := Vector2(float(n) * 0.5, float(n) * 0.5)
		var radius := float(n) * 0.5
		for y in n:
			for x in n:
				var dist := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / radius
				var alpha := 0.0
				if dist < 1.0:
					alpha = pow(1.0 - dist, 2.0) * 0.15
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
		lamp_glow = ImageTexture.create_from_image(image)
		return lamp_glow

	## A soft cone under each painted lamp, kept inside the room: every cone is clamped to the part of the cell clear
	## of the columns, and the picture itself fades out before its edges.
	func _draw_lamp_glow(rect: Rect2, room_type: String, salt := 0, weak := false, off := false) -> void:
		var lit := 0.0 if off else _flicker(salt, weak)
		if lit < 1.0:
			draw_rect(rect, Color(0, 0, 0, (1.0 - lit) * 0.3))
		if room_type in SELF_LIT:
			return
		var pair := _cone(room_type)
		var tex: Texture2D = pair[0]
		if tex == null or lit <= 0.0:
			return
		var col: Color = pair[1]
		col.a = CONE_STRENGTH * lit
		var room := _light_rect(rect)
		var cone_w := rect.size.x * CONE_W
		for lx in LAMP_X:
			var left := clampf(rect.position.x + rect.size.x * float(lx) - cone_w * 0.5, room.position.x, room.end.x - cone_w)
			draw_texture_rect(tex, Rect2(left, rect.position.y + rect.size.y * CONE_TOP, cone_w, rect.size.y * CONE_H), false, col)

	## How bright a room's lamps burn this frame, 0..1: a slow, barely visible breath; only a room short of power
	## dips now and then, slowly enough not to strobe. Still with reduce motion.
	func _flicker(salt: int, weak: bool) -> float:
		if station == null or station._motion_off():
			return 1.0
		var t := life_t
		var f := 0.98 + 0.02 * sin(t * 0.9 + float(salt) * 1.7)
		if not weak:
			return f
		var period := 9.0 + float(salt % 5) * 2.0
		var window := fmod(t / period + float(salt) * 0.37, 1.0)
		if window < 0.06:
			f *= 0.55 + 0.45 * absf(sin(t * 9.0 + float(salt)))
		return clampf(f, 0.0, 1.0)

	## Steam from the machine in a generator or filter room: soft puffs that rise from the middle and fade.
	var puff_tex: Texture2D

	## A soft round puff, opaque in the middle, for steam.
	func _puff_texture() -> Texture2D:
		if puff_tex != null:
			return puff_tex
		var n := 48
		var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(float(n) * 0.5, float(n) * 0.5)
		for y in n:
			for x in n:
				var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(c) / (float(n) * 0.5)
				image.set_pixel(x, y, Color(1, 1, 1, pow(maxf(0.0, 1.0 - d), 1.25)))
		puff_tex = ImageTexture.create_from_image(image)
		return puff_tex

	func _draw_steam(rect: Rect2, room_type: String, salt: int) -> void:
		var tex := _puff_texture()
		if tex == null or station == null or station._motion_off():
			return
		var src := rect.position + rect.size * (Vector2(0.56, 0.62) if room_type == "generator" else Vector2(0.46, 0.58))
		for k in 5:
			var age := fmod(life_t / 3.6 + float(k) / 5.0 + float(salt) * 0.13, 1.0)
			var rise := rect.size.y * 0.34 * age
			var drift := sin(life_t * 0.8 + float(k) * 1.9) * rect.size.x * 0.06 * age
			var r := rect.size.y * (0.09 + 0.24 * age)
			var a := 0.55 * sin(age * PI) * (1.0 - age * 0.35)
			var puff := Rect2(src + Vector2(drift - r, -rise - r), Vector2(r * 2.0, r * 2.0))
			draw_texture_rect(tex, puff, false, Color(0.97, 0.96, 0.94, a))
			draw_texture_rect(tex, puff.grow(-r * 0.35), false, Color(1.0, 1.0, 1.0, a * 0.6))

	## Dust turning in the lamp light: a few warm specks drifting slowly down through the upper part of the room.
	func _draw_motes(rect: Rect2, salt: int) -> void:
		if station == null or station._motion_off():
			return
		for k in 7:
			var n := _speck(salt + 3, k)
			var fall := fmod(life_t * (0.025 + fmod(n, 7.0) * 0.004) + fmod(n * 0.013, 1.0), 1.0)
			var x := rect.position.x + rect.size.x * (0.2 + fmod(n * 0.0071, 0.6)) + sin(life_t * 0.6 + n) * rect.size.x * 0.02
			var y := rect.position.y + rect.size.y * (0.12 + 0.5 * fall)
			var a := 0.5 * sin(fall * PI)
			draw_circle(Vector2(x, y), maxf(0.8, rect.size.y * 0.0045), Color(1.0, 0.86, 0.6, a))

	## An upgraded room's lamps burn a touch warmer and wider, more with each tier, and stay clear of the ribs.
	func _draw_tier_light(rect: Rect2, tier: int) -> void:
		rect = _light_rect(rect)
		var tex := _lamp_texture()
		if tex == null:
			return
		var warm := Color(1.0, 0.74, 0.4, 0.5 + 0.15 * float(tier))
		var glow_w := rect.size.x * (0.5 + 0.1 * float(tier))
		var glow_h := rect.size.y * (0.4 + 0.08 * float(tier))
		var origin := rect.position + Vector2((rect.size.x - glow_w) * 0.5, rect.size.y * 0.02)
		draw_texture_rect(tex, Rect2(origin, Vector2(glow_w, glow_h)), false, warm)

	## The brass flash on a room just upgraded, fading out over UPGRADE_FLASH_MS.
	func _draw_flash(rect: Rect2, uid: String) -> void:
		if not flash.has(uid):
			return
		var left := float(int(flash[uid]) - Time.get_ticks_msec()) / float(station.UPGRADE_FLASH_MS)
		if left <= 0.0:
			flash.erase(uid)
			fitted_flash.erase(uid)
			return
		draw_rect(rect, Color(1.0, 0.86, 0.5, 0.45 * left))
		draw_rect(rect.grow(-2.0), Color(1.0, 0.9, 0.6, left), false, 4.0)
		if fitted_flash.has(uid):
			var burst := float(int(fitted_flash[uid]) - Time.get_ticks_msec()) / float(station.UPGRADE_FLASH_MS)
			if burst <= 0.0:
				fitted_flash.erase(uid)
			else:
				var tex := ArtPack.load_texture("res://assets/overlays/fitted_flash.webp")
				if tex != null:
					var side := minf(rect.size.x, rect.size.y) * 0.72
					var origin := rect.get_center() - Vector2(side, side) * 0.5
					draw_texture_rect(tex, Rect2(origin, Vector2(side, side)), false, Color(1, 1, 1, burst))

	func _job_reveal(level: int, cell: int) -> float:
		var job := _job_span(level, cell)
		if job.x < 0:
			return 0.0
		return clampf(float(job.y - job.x + 1) / float(job.y + 1), 0.0, 1.0)

	func _fit_rect(texture: Texture2D, rect: Rect2) -> Rect2:
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

	func _ghost(key: String, source: Texture2D) -> Texture2D:
		if source == null:
			return null
		if ghosts.has(key):
			return ghosts[key]
		var image := source.get_image()
		if image == null:
			ghosts[key] = source
			return source
		if image.is_compressed():
			image.decompress()
		image.adjust_bcs(0.6, 0.9, 0.12)
		image.generate_mipmaps()
		var tex := ImageTexture.create_from_image(image)
		ghosts[key] = tex
		return tex

	func _draw_site(rect: Rect2, level: int, cell: int) -> void:
		var building := _job_is_build(level, cell)
		var target: Texture2D = null
		var workers: Array = []
		if building:
			var type := str(station.game.build.type)
			draw_rect(rect, Color(0.08, 0.07, 0.06))
			if cell_dug != null:
				_blit_room(cell_dug, rect)
			draw_rect(rect, Color(0, 0, 0, 0.5))
			target = _ghost(type, art.get(type, null))
			workers = station.game.build.get("workers", [])
		else:
			_blit_fill(cell_rock, rect)
			draw_rect(rect, Color(0, 0, 0, 0.2))
			_draw_cracks(rect, level * 6 + cell, 5, Color(0.02, 0.015, 0.01, 0.85), maxf(1.5, rect.size.y * 0.01))
			target = _ghost("#dug", cell_dug)
			workers = station.game.dig.get("workers", [])
		var reveal := _job_reveal(level, cell)
		var floor := rect
		if target != null:
			floor = _fit_rect(target, rect)
			var tex := target.get_size()
			var shown := floor.size.y * reveal
			var top := floor.end.y - shown
			draw_texture_rect_region(target, Rect2(floor.position.x, top, floor.size.x, shown), Rect2(0.0, tex.y * (1.0 - reveal), tex.x, tex.y * reveal))
			draw_line(Vector2(floor.position.x, top), Vector2(floor.end.x, top), Color(0.95, 0.82, 0.42, 0.75), maxf(1.5, rect.size.y * 0.008))
		if scaffold != null:
			draw_texture_rect(scaffold, _fit_rect(scaffold, rect), false)
		else:
			_draw_frame(rect)
		if not building:
			_draw_dig_haze(rect, level * 6 + cell)
		_draw_site_crew(floor, workers, building)

	## Unmined rock: chipped flakes and a few dark seams so it reads rougher than a dug floor.
	func _draw_rough(rect: Rect2, salt: int, strength: float) -> void:
		var h := rect.size.y
		for i in 14:
			var n := _speck(salt + 7, i)
			var at := rect.position + Vector2(fmod(n * 2.3, rect.size.x), fmod(n * 1.71, rect.size.y))
			var r := h * (0.008 + fmod(n, 5.0) * 0.003)
			var shard := PackedVector2Array([at + Vector2(-r, 0), at + Vector2(0, -r * 0.7), at + Vector2(r * 1.2, r * 0.2), at + Vector2(r * 0.1, r * 0.8)])
			draw_colored_polygon(shard, Color(0, 0, 0, 0.45 * strength))
		_draw_cracks(rect, salt, 3, Color(0.0, 0.0, 0.0, 0.55 * strength), maxf(1.0, h * 0.006))

	## Jagged seams from points inside the cell, the same for a cell every frame.
	func _draw_cracks(rect: Rect2, salt: int, count: int, color: Color, width: float) -> void:
		for c in count:
			var n := _speck(salt * 3 + 11, c)
			var at := rect.position + Vector2(rect.size.x * (0.15 + fmod(n * 0.013, 0.7)), rect.size.y * (0.15 + fmod(n * 0.029, 0.7)))
			var heading := fmod(n * 0.37, TAU)
			var line := PackedVector2Array([at])
			for k in 5:
				heading += (fmod(_speck(salt + c, k), 7.0) - 3.0) * 0.18
				at += Vector2(cos(heading), sin(heading)) * rect.size.y * 0.05
				line.append(at)
			draw_polyline(line, color, width)
			draw_line(line[2], line[2] + Vector2(cos(heading + 1.1), sin(heading + 1.1)) * rect.size.y * 0.04, color, width * 0.7)

	## Dust hanging over a cell being dug: a haze along the floor and specks drifting up.
	func _draw_dig_haze(rect: Rect2, salt: int) -> void:
		var band := rect.size.y * 0.32
		var steps := 6
		for i in steps:
			var y := rect.end.y - band * float(i + 1) / float(steps)
			draw_rect(Rect2(rect.position.x, y, rect.size.x, band / float(steps) + 0.5), Color(0.62, 0.55, 0.44, 0.07 * float(steps - i) / float(steps) + 0.03))
		var t := 0.0 if station._motion_off() else Time.get_ticks_msec() / 1000.0
		for i in 10:
			var n := _speck(salt + 3, i)
			var rise := fmod(t * 0.08 + n * 0.01, 1.0)
			var at := Vector2(rect.position.x + fmod(n * 1.9, rect.size.x), rect.end.y - rect.size.y * (0.05 + 0.45 * rise))
			draw_circle(at, rect.size.y * 0.008, Color(0.78, 0.7, 0.58, 0.5 * (1.0 - rise)))

	## A dug, empty cell: a slack cable along the wall and a small heap of rubble in one corner.
	func _draw_dug_props(rect: Rect2, salt: int, skip_heap := false) -> void:
		var h := rect.size.y
		var y0 := rect.position.y + h * 0.2
		var sag := h * 0.07
		var cable := PackedVector2Array()
		for i in 13:
			var f := float(i) / 12.0
			cable.append(Vector2(rect.position.x + rect.size.x * f, y0 + sag * sin(f * PI) + sag * 0.6 * sin(f * TAU)))
		draw_polyline(cable, Color(0.04, 0.035, 0.03, 0.55), maxf(1.5, h * 0.012))
		if skip_heap:
			return
		var left := salt % 2 == 0
		var base := Vector2(rect.position.x + rect.size.x * (0.2 if left else 0.8), rect.end.y - h * 0.03)
		for i in 5:
			var n := _speck(salt + 5, i)
			var r := h * (0.025 + fmod(n, 4.0) * 0.006)
			var at := base + Vector2((float(i) - 2.0) * r * 0.9, -r * (0.4 if i % 2 == 0 else 0.9))
			var rock := PackedVector2Array([at + Vector2(-r, r * 0.5), at + Vector2(-r * 0.6, -r * 0.4), at + Vector2(r * 0.3, -r * 0.6), at + Vector2(r, r * 0.5)])
			draw_colored_polygon(rock, Color(0.24, 0.2, 0.16, 0.9) if i % 2 == 0 else Color(0.32, 0.27, 0.21, 0.9))

	func _draw_frame(rect: Rect2) -> void:
		var wood := Color(0.46, 0.31, 0.16, 0.9)
		var edge := Color(0.10, 0.06, 0.03, 0.85)
		var t := maxf(2.0, rect.size.x * 0.009)
		var xs := [0.05, 0.5, 0.95]
		var top := rect.position.y + rect.size.y * 0.06
		var mid := rect.position.y + rect.size.y * 0.5
		var low := rect.position.y + rect.size.y * 0.97
		var beams: Array = []
		for fx in xs:
			var x: float = rect.position.x + rect.size.x * float(fx)
			beams.append([Vector2(x, top), Vector2(x, low)])
		for y in [top, mid]:
			beams.append([Vector2(rect.position.x + rect.size.x * 0.03, y), Vector2(rect.end.x - rect.size.x * 0.03, y)])
		for i in 2:
			var x0: float = rect.position.x + rect.size.x * float(xs[i])
			var x1: float = rect.position.x + rect.size.x * float(xs[i + 1])
			beams.append([Vector2(x0, top), Vector2(x1, mid)])
			beams.append([Vector2(x1, mid), Vector2(x0, low)])
		for beam in beams:
			draw_line(beam[0], beam[1], edge, t + 2.0)
		for beam in beams:
			draw_line(beam[0], beam[1], wood, t)

	## Builders are the drawn hammer and crate figures, diggers any body stem; the old working pose only when
	## the drawn set is not installed.
	func _draw_site_crew(floor: Rect2, workers: Array, building: bool) -> void:
		if workers.is_empty():
			return
		var pose_name := "working" if poses.has("working") else "standing"
		var slots := [0.3, 0.68, 0.48, 0.84]
		var shown := mini(workers.size(), slots.size())
		var stems: Array = BUILDER_FIGS.filter(func(s): return fig_variants.has(s)) if building else body_figs
		var looks := _figs_for_group(stems, workers.slice(0, shown))
		var t := 0.3 if station._motion_off() else life_t
		var kind := "build" if building else "dig"
		if _anim_ready(kind):
			_draw_site_anim(floor, workers, shown, slots, kind)
			return
		for i in shown:
			var id := str(workers[i])
			var x := floor.position.x + floor.size.x * float(slots[i])
			var beat := fmod(t * CREW_BEAT + fmod(_id_hash(id) / 97.0, 1.0) + 0.5 * float(i), 1.0)
			var foot := floor.end.y - 2.0 - floor.size.y * CREW_BOB * sin(beat * PI)
			var lean := CREW_LEAN * (1.0 - sin(beat * PI))
			if looks[i] != null:
				_paint_sprite(looks[i], x, foot, floor.size.y, id, i % 2 == 1, lean, true)
			else:
				_paint_pose(pose_name, x, foot, floor.size.y, id, i % 2 == 1, lean, true)
			_draw_dust(Vector2(x + floor.size.y * (-0.07 if i % 2 == 1 else 0.07), floor.end.y - 2.0), beat, floor.size.y)
			if not building and not station._motion_off():
				_draw_chips(Vector2(x + floor.size.y * (-0.1 if i % 2 == 1 else 0.1), floor.end.y - floor.size.y * 0.22), beat, floor.size.y, -1.0 if i % 2 == 1 else 1.0)

	## The crew in real frames (docs/briefs/art_anim_set2.txt): each swings at 6 fps, every second one faces left,
	## and dust (and chips at the rock) come off on the strike frame.
	func _draw_site_anim(floor: Rect2, workers: Array, shown: int, slots: Array, kind: String) -> void:
		var fps := float(ANIM_KINDS[kind][1])
		var count := int(ANIM_KINDS[kind][0])
		var h := floor.size.y * 0.58
		for i in shown:
			var id := str(workers[i])
			var x := floor.position.x + floor.size.x * float(slots[i])
			var body: String = ANIM_BODIES[(int(_id_hash(id)) + i) % ANIM_BODIES.size()]
			var left := i % 2 == 1
			var frame := _anim_frame(kind, id)
			_draw_anim(kind, body, x, floor.end.y - 2.0, h, id, left, frame)
			if station._motion_off():
				continue
			var off := int(_id_hash(id)) % count
			var since := fmod(life_t * fps + float(off) - float(ANIM_STRIKE), float(count)) / float(count)
			var side := -1.0 if left else 1.0
			_draw_dust(Vector2(x + side * h * 0.12, floor.end.y - 2.0), since, floor.size.y)
			if kind == "dig":
				_draw_chips(Vector2(x + side * h * 0.42, floor.end.y - h * 0.35), since, floor.size.y, side)

	## Rock chips thrown off the face on each strike, arcing out and dropping, gone by mid beat.
	func _draw_chips(at: Vector2, beat: float, cell_h: float, side: float) -> void:
		var age := beat / 0.45
		if age >= 1.0:
			return
		for k in 4:
			var spread := 0.6 + float(k) * 0.35
			var vx := side * cell_h * 0.09 * spread
			var vy := -cell_h * (0.09 + 0.03 * float(k % 2))
			var p := at + Vector2(vx * age, vy * age + cell_h * 0.2 * age * age)
			var sz := maxf(1.2, cell_h * (0.008 + 0.003 * float(k % 3)))
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(0.42, 0.36, 0.3, 1.0 - age))

	## A small puff where the tool strikes, just after each downstroke (beat 0), drifting up and fading.
	func _draw_dust(at: Vector2, beat: float, cell_h: float) -> void:
		var age := beat / 0.5
		if age >= 1.0:
			return
		for k in 3:
			var drift := Vector2((float(k) - 1.0) * 0.035, -0.02 - 0.03 * age) * cell_h * (0.4 + age)
			var r := cell_h * (0.02 + 0.03 * age) * (1.0 - 0.2 * float(k))
			draw_circle(at + drift, r, Color(0.7, 0.62, 0.5, 0.7 * (1.0 - age)))

	func _job_span(level: int, cell: int) -> Vector2i:
		var clearing: Dictionary = station.game.clear
		if not clearing.is_empty() and int(clearing.level) == level and int(clearing.cell) == cell:
			var total: int = station.game.clear_weeks(str(clearing.get("kind", "rubble")))
			var left := int(clearing.left)
			return Vector2i(left, maxi(total, left))
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

	## "1 wk" for a one-week job; "1 of 2 wk" (the week under way, of all) for a longer one.
	func job_label(job: Vector2i) -> String:
		if job.y > 1:
			return Copy.t("%d of %d wk") % [job.y - job.x + 1, job.y]
		return Copy.t("%d wk") % job.x

	func _job_is_build(level: int, cell: int) -> bool:
		var building: Dictionary = station.game.build
		return not building.is_empty() and int(building.level) == level and int(building.cell) == cell

	func _cell_action(level: int, cell: int, kind: String, room_type: String) -> String:
		var clearing: Dictionary = station.game.clear
		if not clearing.is_empty() and int(clearing.level) == level and int(clearing.cell) == cell:
			return Copy.fill("clear.progress", {"n": str(int(clearing.left))})
		var digging: Dictionary = station.game.dig
		if not digging.is_empty() and int(digging.level) == level and int(digging.cell) == cell:
			return Copy.t("Digging, %s left") % Words.count(int(digging.left), "week")
		var building: Dictionary = station.game.build
		if not building.is_empty() and int(building.level) == level and int(building.cell) == cell:
			var name := Copy.t(str(station.game.catalog.rooms[str(building.type)].name))
			return Copy.fill("station.tip_building", {"room": name, "weeks": int(building.left)})
		match kind:
			"hidden":
				return Copy.t("Solid rock")
			"undug":
				return Copy.t("Dig")
			"dug":
				var piled: Dictionary = station.game.cells["%d:%d" % [level, cell]]
				var pile := str(piled.get("pile", ""))
				if pile != "":
					var info: Dictionary = station.game.clear_preview(level, cell)
					return Copy.fill("clear.tip", {
						"kind": Copy.t("clear.title_" + pile),
						"weeks": str(int(info.weeks)),
						"crew": str(int(info.workers)),
					})
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

	## The drawn variant for a room with this many upgrades bought (assets/rooms/upgrades/room_<id>_t<N>.png);
	## null at tier 0 or when the file is missing, and the base image with the layered tier light is drawn instead.
	func tier_art(room_type: String, tier: int) -> Texture2D:
		if tier <= 0:
			return null
		var path := TIER_ART % [room_type, tier]
		if not tier_cache.has(path):
			var tex: Texture2D = ArtPack.load_texture(path) if ResourceLoader.exists(path) else null
			tier_cache[path] = tex if tex != null else false
		var found = tier_cache[path]
		return found if found is Texture2D else null

	func _listening_plate() -> Texture2D:
		var base: Texture2D = art.get("listening_post", null)
		if station == null or station.game == null:
			return base
		if station.game.listening_probe_live():
			return base
		if station.game.listening_active() and int(station.game.week) % 2 == 1:
			var alt: Texture2D = art.get("listening_post_alt", null)
			if alt != null:
				return alt
		return base

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
				_draw_job_plate(geo, level, cell, font)
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
		_draw_merge_brackets(geo)

	func _draw_job_plate(geo: Dictionary, level: int, cell: int, font: Font) -> void:
		var job := _job_span(level, cell)
		if job.x < 0:
			return
		var world := _rect(geo, level, cell)
		var screen := Rect2(pan + world.position * zoom, world.size * zoom)
		if screen.size.x < 60.0:
			return
		var clearing: bool = station._clearing_cell(level, cell)
		var kind := str(station.game.build.type) if _job_is_build(level, cell) else "dig"
		var icon_px := 48.0 if screen.size.x >= 150.0 else 32.0
		var font_size := 24 if icon_px >= 48.0 else 18
		var label := Copy.fill("clear.progress", {"n": str(job.x)}) if clearing else job_label(job)
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var line_h := font.get_height(font_size)
		var bar_w := maxf(text_w, clampf(screen.size.x * 0.4, 60.0, 170.0))
		var plate_w := minf(10.0 + icon_px + 8.0 + bar_w + 10.0, screen.size.x - 8.0)
		bar_w = plate_w - icon_px - 28.0
		var plate_h := maxf(icon_px, line_h + 14.0) + 12.0
		var plate := Rect2(screen.get_center().x - plate_w * 0.5, screen.position.y + 8.0, plate_w, plate_h)
		draw_rect(plate, Color(0.05, 0.04, 0.03, 0.86))
		draw_rect(plate, Color(0.93, 0.78, 0.42, 0.9), false, 1.5)
		var tex := ArtPack.icon_texture(kind, icon_px)
		if tex != null:
			draw_texture_rect(tex, Rect2(plate.position + Vector2(10.0, (plate_h - icon_px) * 0.5), Vector2(icon_px, icon_px)), false)
		var x0 := plate.position.x + 10.0 + icon_px + 8.0
		var block_h := line_h + 14.0
		var y0 := plate.position.y + (plate_h - block_h) * 0.5
		draw_string(font, Vector2(x0, y0 + font.get_ascent(font_size)), label, HORIZONTAL_ALIGNMENT_LEFT, bar_w, font_size, Color(0.98, 0.94, 0.84))
		var bar := Rect2(x0, y0 + line_h + 4.0, bar_w, 10.0)
		draw_rect(bar, Color(0.42, 0.30, 0.12, 0.95))
		var done := _job_reveal(level, cell)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(0.95, 0.82, 0.42, 1.0))
		draw_rect(bar, Color(0.1, 0.07, 0.03, 0.9), false, 1.0)

	func _room_glyph(room_type: String) -> String:
		return room_type

	func show_place(type: String, level: int, cell: int) -> void:
		place_type = type
		place_level = level
		place_cell = cell
		queue_redraw()

	func clear_place() -> void:
		if place_type == "":
			return
		place_type = ""
		place_level = -1
		place_cell = -1
		queue_redraw()

	func _screen_of(geo: Dictionary, level: int, cell: int) -> Rect2:
		var world := _rect(geo, level, cell)
		return Rect2(pan + world.position * zoom, world.size * zoom)

	func _place_info() -> Dictionary:
		if place_type == "" or station == null or station.game == null:
			return {}
		return station.game.merge_preview(place_type, place_level, place_cell)

	func _draw_merge_ghost(geo: Dictionary) -> void:
		var info := _place_info()
		if not bool(info.get("joins", false)):
			return
		for c in info.get("cells", []):
			if int(c) == place_cell:
				continue
			draw_rect(_rect(geo, place_level, int(c)), Color("e2a63a", 0.10))
		var rect := _rect(geo, place_level, place_cell)
		var tex: Texture2D = _ghost(place_type, art.get(place_type, null))
		if tex != null:
			draw_texture_rect(tex, _fit_rect(tex, rect), false, Color(1, 1, 1, 0.55))
		else:
			draw_rect(rect, Color("e2a63a", 0.18))

	func _draw_merge_tag(geo: Dictionary) -> void:
		var info := _place_info()
		if not bool(info.get("joins", false)):
			return
		var cells: Array = info.get("cells", [])
		if cells.is_empty():
			return
		var union := _screen_of(geo, place_level, int(cells[0]))
		for c in cells:
			union = union.merge(_screen_of(geo, place_level, int(c)))
		draw_rect(union, Color("e2a63a", 0.95), false, 2.5)
		draw_rect(union.grow(-2.5), Color("efe6d2", 0.35), false, 1.0)
		var full := str(info.get("bonus_line", ""))
		if full == "":
			return
		var share := str(info.get("share_line", ""))
		var head := full
		if share != "" and full.ends_with(share):
			head = full.substr(0, full.length() - share.length()).strip_edges()
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var font_size := 14
		var head_w := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var share_w := 0.0
		if share != "":
			share_w = font.get_string_size(share, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var inner := minf(344.0, maxf(8.0, maxf(head_w, share_w)))
		var line_h := font.get_height(font_size)
		var split := head_w <= inner and share != ""
		var lines := 2 if split or head_w > inner else 1
		var plate := Rect2(0, 0, inner + 16.0, line_h * float(lines) + 12.0)
		plate.position = Vector2(union.get_center().x - plate.size.x * 0.5, union.position.y - plate.size.y - 6.0)
		plate.position.x = clampf(plate.position.x, 8.0, maxf(8.0, size.x - plate.size.x - 8.0))
		if plate.position.y < 4.0:
			plate.position.y = union.end.y + 6.0
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.10, 0.08, 0.06, 0.90)
		style.border_color = Color("b89a6a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(2)
		style.draw(self, plate)
		var text_pos := plate.position + Vector2(8.0, 6.0 + font.get_ascent(font_size))
		if split:
			draw_string(font, text_pos, head, HORIZONTAL_ALIGNMENT_LEFT, inner, font_size, Color("f4efe4"))
			draw_string(font, text_pos + Vector2(0, line_h), share, HORIZONTAL_ALIGNMENT_LEFT, inner, font_size, Color("d9cbb4"))
		else:
			draw_multiline_string(font, text_pos, full, HORIZONTAL_ALIGNMENT_LEFT, inner, font_size, 2, Color("f4efe4"))

	func _draw_merge_brackets(geo: Dictionary) -> void:
		var live := {}
		var seen := {}
		for level in 3:
			for cell in 6:
				var spot: Dictionary = station.game.cells["%d:%d" % [level, cell]]
				var uid := str(spot.get("room", ""))
				if uid == "" or seen.has(uid):
					continue
				var ids: Array = station.game.merge_group_of(uid)
				if ids.size() < 2:
					continue
				var prev_cell := -99
				var prev_level := -99
				for id in ids:
					seen[str(id)] = true
					var room = station.game._room(str(id))
					if room == null:
						continue
					var c := int(room.cell)
					var lv := int(room.level)
					if prev_level == lv and c == prev_cell + 1:
						live["%d:%d" % [lv, prev_cell]] = _draw_bracket(geo, lv, prev_cell)
					prev_cell = c
					prev_level = lv
		_sync_seams(live)

	func _draw_bracket(geo: Dictionary, level: int, left_cell: int) -> Vector2:
		var screen := _screen_of(geo, level, left_cell)
		var x := screen.end.x
		var y0 := screen.position.y + screen.size.y * 0.22
		var y1 := screen.position.y + screen.size.y * 0.78
		_stroke_bracket(x, y0, y1, Color("efe6d2", 0.55), 5.0)
		_stroke_bracket(x, y0, y1, Color("e2a63a", 0.92), 2.5)
		return Vector2(x, (y0 + y1) * 0.5)

	func _stroke_bracket(x: float, y0: float, y1: float, color: Color, width: float) -> void:
		draw_line(Vector2(x, y0), Vector2(x, y1), color, width)
		draw_line(Vector2(x - 10.0, y0), Vector2(x + 10.0, y0), color, width)
		draw_line(Vector2(x - 10.0, y1), Vector2(x + 10.0, y1), color, width)

	func _sync_seams(live: Dictionary) -> void:
		if seam_init and station != null and not station._motion_off():
			for key in live:
				if not seam_seen.has(key):
					_spawn_dust(live[key])
		seam_seen = live
		seam_init = true

	func _spawn_dust(at: Vector2) -> void:
		var now := Time.get_ticks_msec()
		for i in 8:
			dust.append({
				"x": at.x + (float(i) - 3.5) * 4.0,
				"y": at.y,
				"vx": (float(i) - 3.5) * 22.0,
				"vy": -36.0 - float(i % 4) * 18.0,
				"born": now,
				"w": 3.0 + float(i % 3),
				"h": 2.0 + float((i + 1) % 3),
			})

	func _draw_seam_dust() -> void:
		if dust.is_empty():
			return
		var now := Time.get_ticks_msec()
		var keep: Array = []
		for p in dust:
			var age := float(now - int(p.born)) / 1000.0
			if age < 0.0 or age > 0.35:
				continue
			keep.append(p)
			var x := float(p.x) + float(p.vx) * age
			var y := float(p.y) + float(p.vy) * age
			draw_rect(Rect2(x, y, float(p.w), float(p.h)), Color(0.78, 0.66, 0.42, (1.0 - age / 0.35) * 0.65))
		dust = keep

	func _draw_sign(screen: Rect2, room: Dictionary, font: Font) -> void:
		var ids: Array = station.game.merge_group_of(str(room.uid))
		var width := maxi(ids.size(), 1)
		if width >= 2 and str(ids[0]) != str(room.uid):
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var room_name := Copy.t(str(defin.name))
		if width >= 2:
			room_name = Copy.t("merge.sign") % [room_name, width]
		var font_size := 13
		var text_w := font.get_string_size(room_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var steps: Array = defin.get("upgrades", [])
		var total := mini(3, maxi(1, steps.size() + 1))
		var filled := clampi(int(room.upgrade) + 1, 1, total)
		var tier := int(room.upgrade)
		var numeral: String = station.roman(tier)
		var pip_w := float(total) * 8.0
		if tier > 0:
			pip_w = font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0
		var plate_w := minf(8.0 + 16.0 + 4.0 + text_w + 8.0 + pip_w, screen.size.x - 8.0)
		var plate := Rect2(screen.position + Vector2(4.0, 4.0), Vector2(plate_w, 22.0))
		draw_rect(plate, Color("efe6d2"))
		draw_rect(plate, Color("3a2610"), false, 1.5)
		_paint_mini(plate.position + Vector2(3.0, 4.0), _room_glyph(str(room.type)), Color("24180e"))
		var name_w := maxf(8.0, plate_w - 16.0 - 8.0 - pip_w)
		draw_string(font, plate.position + Vector2(20.0, 16.0), room_name, HORIZONTAL_ALIGNMENT_LEFT, name_w, font_size, Color("24180e"))
		var px := plate.position.x + plate.size.x - pip_w - 2.0
		if tier > 0:
			var brass := Rect2(px + 1.0, plate.position.y + 2.0, pip_w - 1.0, plate.size.y - 4.0)
			draw_rect(brass, station.BRASS)
			draw_rect(brass, Color("5a3d12"), false, 1.0)
			draw_string(font, Vector2(brass.position.x + 7.0, plate.position.y + 16.0), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("24180e"))
			sign_tiers[str(room.uid)] = numeral
		else:
			sign_tiers.erase(str(room.uid))
			for i in total:
				var pip := Color("3a2610") if i < filled else Color("3a2610", 0.28)
				draw_circle(Vector2(px + 4.0 + float(i) * 8.0, plate.position.y + 11.0), 2.2, pip)
		var disc := Rect2(plate.end.x + 4.0, plate.position.y + 2.0, 18.0, 18.0)
		if station.incident_on(str(room.type)):
			var warn := ArtPack.icon_texture("warning", 24.0)
			if warn != null and disc.end.x <= screen.end.x - 4.0:
				draw_texture_rect(warn, disc, false)
				sign_incidents[str(room.uid)] = true
				disc.position.x += 22.0
		else:
			sign_incidents.erase(str(room.uid))
		if disc.end.x <= screen.end.x - 4.0 and station.room_what(str(room.type)) != "":
			var mid := disc.get_center()
			draw_circle(mid, 9.0, Color("efe6d2"))
			draw_arc(mid, 9.0, 0.0, TAU, 24, Color("3a2610"), 1.5, true)
			var q_w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, Vector2(mid.x - q_w * 0.5, mid.y + 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("24180e"))
			help_hits.append({"rect": disc.grow(4.0), "type": str(room.type), "uid": str(room.uid)})

	func _help_at(at_position: Vector2) -> Dictionary:
		for mark in help_hits:
			if (mark.rect as Rect2).has_point(at_position):
				return mark
		return {}

	func _get_tooltip(at_position: Vector2) -> String:
		var mark := _help_at(at_position)
		if mark.is_empty():
			return tooltip_text
		return station.room_what(str(mark.type))

	func _draw_badge_screen(screen: Rect2, room: Dictionary, font: Font) -> void:
		var ids: Array = station.game.merge_group_of(str(room.uid))
		if ids.size() >= 2 and str(ids[0]) != str(room.uid):
			return
		var detail: Dictionary = station.game.room_detail(str(room.uid))
		var outputs: Array = detail.get("outputs", [])
		if outputs.is_empty():
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var dimmed: bool = bool(room.get("browned", false)) or bool(room.get("offline", false)) or station.dark_now.has(str(room.uid))
		if station.power_loss.has(str(room.uid)):
			dimmed = true
		if ids.size() >= 2:
			if int(detail.get("crew_need", 0)) > 0 and int(detail.get("block_staff", 0)) < int(detail.crew_need):
				dimmed = true
		elif int(defin.get("staff_min", 0)) > 0 and room.staff.size() < int(defin.staff_min):
			dimmed = true
		var ink := Color(0.96, 0.93, 0.86, 0.38 if dimmed else 0.96)
		var width := 8.0
		for out in outputs:
			width += 16.0 + font.get_string_size("+%d" % station._room_amount(str(room.uid), str(out.key)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 6.0
		var plate := Rect2(screen.position.x + screen.size.x - width - 4.0, screen.position.y + screen.size.y - 22.0, width, 18.0)
		draw_rect(plate, Color(0.05, 0.04, 0.03, 0.55 if dimmed else 0.72))
		var x := plate.position.x + 4.0
		for out in outputs:
			_paint_mini(Vector2(x, plate.position.y + 2.0), str(out.key), ink)
			x += 16.0
			var text := "+%d" % station._room_amount(str(room.uid), str(out.key))
			draw_string(font, Vector2(x, plate.position.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
			x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 6.0

	func _draw_hover_label(geo: Dictionary) -> void:
		if hover.x < 0:
			return
		var spot: Dictionary = station.game.cells["%d:%d" % [hover.x, hover.y]]
		var kind := _kind(spot)
		var room_type := ""
		var found: Dictionary = {}
		if kind == "room":
			found = station.game._room(str(spot.room))
			room_type = str(found.get("type", ""))
		var tip := _cell_action(hover.x, hover.y, kind, room_type)
		if kind == "room" and not found.is_empty():
			var status: String = station._room_hover_tip(found)
			if status != "":
				tip = status if tip == "" else "%s · %s" % [tip, status]
		if tip == "":
			return
		var world := _rect(geo, hover.x, hover.y)
		var screen := pan + world.position * zoom
		screen.x = clampf(screen.x + 6.0, 8.0, size.x - 180.0)
		screen.y = clampf(screen.y + 6.0, 8.0, size.y - 32.0)
		_draw_corner_label(Rect2(screen, Vector2(220, 28)), tip)

	func _draw_people(rect: Rect2, room: Dictionary) -> void:
		if str(room.type) == "quarters":
			_draw_sleepers(rect, room)
			return
		var crew: Array = room.staff
		if crew.is_empty() or not poses.has("standing"):
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var spots: Array = defin.get("spots", [])
		var floor := _art_rect(str(room.type), rect)
		var shown := mini(crew.size(), mini(spots.size(), 3))
		var own: Array = room_figs.get(str(room.type), [])
		var looks := _figs_for_group(own if not own.is_empty() else body_figs, crew.slice(0, shown))
		var animated := _anim_ready("work")
		var room_salt := int(_id_hash(str(room.uid)))
		for i in shown:
			var spot: Dictionary = spots[i]
			var id := str(crew[i])
			var x := floor.position.x + float(spot.get("x", 0.5)) * floor.size.x
			var flip := int(spot.get("face", 1)) < 0
			if animated:
				var body: String = ANIM_BODIES[(room_salt + i) % ANIM_BODIES.size()]
				var h := floor.size.y * 0.58
				_draw_anim("work", body, x, floor.position.y + floor.size.y - 2.0, h, id, flip, _anim_frame("work", id))
				continue
			var sprite: Texture2D = looks[i]
			if not own.is_empty():
				flip = int(_id_hash(id) / 7.0) % 2 == 0
			elif sprite == null:
				sprite = _pose_sprite(str(spot.get("pose", "standing")), id)
			if sprite == null:
				continue
			var foot_y := floor.position.y + floor.size.y - 2.0
			var body_h := floor.size.y
			var fitted := _pose_size(sprite, body_h)
			var limit := floor.size.x * 0.34
			if fitted.x > limit:
				body_h *= limit / fitted.x
			var margin := fitted.x * 0.5 + 4.0
			var life := _life(id, x, floor.position.x + margin, floor.position.x + floor.size.x - margin, flip, true)
			_paint_sprite(sprite, float(life.x), foot_y + float(life.bob), body_h, id, bool(life.flip), float(life.lean), true, float(life.breath))
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
		var looks := _figs_for_group(body_figs, ids.slice(0, shown))
		for i in shown:
			var x := rect.position.x + rect.size.x * (0.28 if i == 0 else 0.62)
			var foot_y := rect.position.y + rect.size.y - 2.0
			var fig_h := rect.size.y * 0.58
			var salt := int(_id_hash(str(ids[0])))
			if i == 0 and _anim_ready("walk"):
				_draw_walker(rect, foot_y, fig_h, str(ids[i]), ANIM_BODIES[salt % ANIM_BODIES.size()])
				continue
			if i == 1 and _anim_ready("stand"):
				var body: String = ANIM_BODIES[(salt + 2) % ANIM_BODIES.size()]
				_draw_anim("stand", body, x, foot_y, fig_h, str(ids[i]), false, _anim_frame("stand", str(ids[i])))
				continue
			var life := _life(str(ids[i]), x, rect.position.x + rect.size.x * 0.1, rect.position.x + rect.size.x * 0.9, i == 0, false)
			if looks[i] != null:
				_paint_sprite(looks[i], float(life.x), foot_y + float(life.bob), rect.size.y, str(ids[i]), bool(life.flip), float(life.lean), false, float(life.breath))
			else:
				_paint_pose(pose_name, float(life.x), foot_y + float(life.bob), rect.size.y, str(ids[i]), bool(life.flip), float(life.lean))
		if ids.size() > shown:
			_draw_more(rect, ids.size() - shown, "free")

	## Real animation frames (docs/briefs/art_anim_pilot.txt, art_anim_set1.txt): four residents drawn in walk,
	## stand and work. Frames are 256 x 512 cells with the soles on WALK_FLOOR and the figure WALK_FIG tall.
	## Room crews work with them, the platform has one walker and one standing; everyone else keeps their picture.
	const ANIM_DIR := "res://assets/figures/anim/"
	const ANIM_BODIES := ["body03", "body01", "body07", "body11"]
	## kind: [frames, frames a second]
	const ANIM_KINDS := {"walk": [8, 6.0], "stand": [4, 3.0], "work": [6, 5.0], "dig": [6, 6.0], "build": [6, 6.0]}
	## Where the body stands across its cell: dig and build cells are wider to hold the swing, body on the left.
	const ANIM_BODY_X := {"dig": 0.4, "build": 0.4}
	## The strike frame of dig and build, when dust and chips fly.
	const ANIM_STRIKE := 2
	const WALK_FLOOR := 488.0
	const WALK_FIG := 464.0
	## Ground covered in one full cycle (two steps), as a share of the figure height, so the feet do not slide.
	const WALK_STRIDE := 0.62
	var anim_tex := {}

	## The frames of one kind for one body, or [] when any file is missing.
	func _anim(kind: String, body: String) -> Array:
		var key := "%s_%s" % [kind, body]
		if not anim_tex.has(key):
			var frames: Array = []
			for i in int(ANIM_KINDS[kind][0]):
				var path := ANIM_DIR + key + "/f%d.png" % i
				if not ResourceLoader.exists(path):
					frames = []
					break
				frames.append(load(path))
			anim_tex[key] = frames
		return anim_tex[key]

	func _anim_ready(kind: String) -> bool:
		for body in ANIM_BODIES:
			if _anim(kind, str(body)).is_empty():
				return false
		return true

	## Which frame a looping animation shows now, offset per person so a room does not move in step.
	func _anim_frame(kind: String, id: String) -> int:
		if station._motion_off():
			return 0
		var count := int(ANIM_KINDS[kind][0])
		return (int(floor(life_t * float(ANIM_KINDS[kind][1]))) + int(_id_hash(id))) % count

	## One animation frame standing on foot_y at x, the figure body_h tall, tinted like the still figures.
	func _draw_anim(kind: String, body: String, x: float, foot_y: float, body_h: float, id: String, flip: bool, frame: int) -> void:
		var frames := _anim(kind, body)
		if frames.is_empty():
			return
		var tex: Texture2D = frames[clampi(frame, 0, frames.size() - 1)]
		var k := body_h / WALK_FIG
		var size := tex.get_size() * k
		var bx := float(ANIM_BODY_X.get(kind, 0.5))
		_draw_shadow(Vector2(x, foot_y), body_h * 0.13, body_h * 0.02)
		var dest := Rect2(x - size.x * ((1.0 - bx) if flip else bx), foot_y - WALK_FLOOR * k, size.x, size.y)
		if flip:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		var shade := 0.36 + fmod(_id_hash(id), 5.0) * 0.02
		var tint := Color(clampf(shade * 1.75, 0.6, 0.78), clampf(shade * 1.5, 0.52, 0.66), clampf(shade * 1.2, 0.42, 0.54)).lerp(Color.WHITE, fig_tint_mix)
		draw_texture_rect(tex, dest, false, tint)

	## Walks the platform from one end to the other and back, stopping for a while at each end. Position and frame
	## come from the clock, so nothing is stored. Reduce motion stands him still on a neutral frame.
	func _draw_walker(rect: Rect2, foot_y: float, body_h: float, id: String, body: String) -> void:
		var frames := _anim("walk", body)
		var walk_fps := float(ANIM_KINDS.walk[1])
		var lo := rect.position.x + rect.size.x * 0.14
		var hi := rect.position.x + rect.size.x * 0.86
		var x := lo + (hi - lo) * 0.3
		var frame := 2
		var flip := false
		if not station._motion_off():
			var cycle := float(frames.size()) / walk_fps
			var speed := body_h * WALK_STRIDE / cycle
			var leg := (hi - lo) / speed
			var rest := 3.0
			var period := (leg + rest) * 2.0
			var u := fmod(life_t + fmod(_id_hash(id), 7.0), period)
			if u < leg:
				x = lo + speed * u
				frame = int(floor(u * walk_fps)) % frames.size()
			elif u < leg + rest:
				x = hi
			elif u < leg * 2.0 + rest:
				var back := u - leg - rest
				x = hi - speed * back
				flip = true
				frame = int(floor(back * walk_fps)) % frames.size()
			else:
				x = lo
				flip = true
		_draw_anim("walk", body, x, foot_y, body_h, id, flip, frame)

	func _draw_output_badges(rect: Rect2, room: Dictionary) -> void:
		var detail: Dictionary = station.game.room_detail(str(room.uid))
		var outputs: Array = detail.get("outputs", [])
		if outputs.is_empty():
			return
		var defin: Dictionary = station.game.catalog.rooms[str(room.type)]
		var dim: bool = bool(room.get("browned", false)) or bool(room.get("offline", false)) or station.dark_now.has(str(room.uid))
		if int(defin.get("staff_min", 0)) > 0 and room.staff.size() < int(defin.staff_min):
			dim = true
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var x := rect.position.x + 6.0 + _wall_inset()
		var y := rect.position.y + rect.size.y - 22.0
		var ink := Color(0.96, 0.93, 0.86, 0.35 if dim else 0.95)
		for out in outputs:
			_paint_mini(Vector2(x, y), str(out.key), ink)
			x += 16.0
			var text := "+%d" % station._room_amount(str(room.uid), str(out.key))
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
		var label := ("ещё %s" % Words.count(extra, "person")) if Copy.ru() else "%d more %s" % [extra, "person" if extra == 1 else "people"]
		var font: Font = ThemeDB.fallback_font
		if station.body_font != null:
			font = station.body_font
		var font_size := 13
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var box := Vector2(text_size.x + 10.0, text_size.y + 4.0)
		var origin := Vector2(rect.position.x + rect.size.x - box.x - 4.0 - _wall_inset(), rect.position.y + rect.size.y - box.y - 24.0)
		draw_rect(Rect2(origin, box), Color(0.09, 0.06, 0.04, 0.88))
		draw_string(font, origin + Vector2(5.0, text_size.y * 0.82), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("efe6d2"))
		if filter_id != "":
			var screen := Rect2(pan + origin * zoom, box * zoom)
			more_hits.append({"rect": screen.grow(6.0), "filter": filter_id})

	func _pose_size(sprite: Texture2D, cell_h: float) -> Vector2:
		var target_h := cell_h * 0.58
		var aspect := sprite.get_width() / maxf(sprite.get_height(), 1.0)
		return Vector2(target_h * aspect, target_h)

	func _draw_sleepers(rect: Rect2, room: Dictionary) -> void:
		var ids := _quarters_ids(str(room.uid))
		if ids.is_empty():
			return
		var floor := _art_rect("quarters", rect)
		var own: Array = room_figs.get("quarters", body_figs)
		var slots := [0.2, 0.5, 0.8]
		var looks := _figs_for_group(own, ids.slice(0, slots.size()))
		for i in mini(ids.size(), slots.size()):
			var id := str(ids[i])
			var sprite: Texture2D = looks[i]
			if sprite == null:
				sprite = _pose_sprite("sitting", id)
			if sprite == null:
				continue
			var x := floor.position.x + floor.size.x * float(slots[i])
			var body_h := floor.size.y if not own.is_empty() else floor.size.y * 0.8
			_paint_sprite(sprite, x, floor.end.y - 2.0, body_h, id, int(_id_hash(id) / 7.0) % 2 == 0)

	func _quarters_ids(uid: String) -> Array:
		var idle := _idle_ids()
		var on_platform := mini(2, idle.size())
		var rest: Array = idle.slice(on_platform)
		var quarters: Array = []
		for room in station.game.rooms:
			if str(room.type) == "quarters" and not bool(room.offline):
				quarters.append(str(room.uid))
		quarters.sort()
		var at := quarters.find(uid)
		if at < 0:
			return []
		return rest.slice(at * 3, at * 3 + 3)

	func _pose_sprite(pose_name: String, id: String) -> Texture2D:
		if not body_figs.is_empty():
			return _fig_for(body_figs, id)
		if poses.has(pose_name):
			return poses[pose_name]
		return poses.get("standing", null)

	func _paint_pose(pose_name: String, cx: float, foot_y: float, cell_h: float, id: String, flip: bool, lean := 0.0, working := false) -> void:
		var sprite := _pose_sprite(pose_name, id)
		if sprite == null:
			return
		_paint_sprite(sprite, cx, foot_y, cell_h, id, flip, lean, working)

	## `lean` tips the figure about its feet (radians, toward the side it faces). Every figure stands on a soft
	## shadow; a working one gets a thin warm rim so it separates from the machinery behind it.
	func _paint_sprite(sprite: Texture2D, cx: float, foot_y: float, cell_h: float, id: String, flip: bool, lean := 0.0, working := false, breath := 0.0) -> void:
		var scale := 0.94 + fmod(floor(_id_hash(id) / 11.0), 13.0) * 0.01
		var fitted := _pose_size(sprite, cell_h) * scale
		fitted.y *= 1.0 + breath
		_draw_shadow(Vector2(cx, foot_y), fitted.x * 0.42, fitted.y * 0.035)
		var tipped := lean != 0.0
		if tipped:
			var world := Transform2D(0.0, Vector2(zoom, zoom), 0.0, pan)
			draw_set_transform_matrix(world * Transform2D(-lean if flip else lean, Vector2(-1.0 if flip else 1.0, 1.0), 0.0, Vector2(cx, foot_y)))
			cx = 0.0
			foot_y = 0.0
		var dest := Rect2(cx - fitted.x * 0.5, foot_y - fitted.y, fitted.x, fitted.y)
		if flip and not tipped:
			dest.position.x += dest.size.x
			dest.size.x = -dest.size.x
		var shade := 0.36 + fmod(_id_hash(id), 5.0) * 0.02
		var tint := Color(
			clampf(shade * 1.75, 0.6, 0.78),
			clampf(shade * 1.5, 0.52, 0.66),
			clampf(shade * 1.2, 0.42, 0.54))
		if soft_figs.has(sprite):
			tint = tint.lerp(Color.WHITE, fig_tint_mix)
		if working:
			var rim := _rim_tex(sprite)
			if rim != null:
				var step := RIM_PX / maxf(zoom, 0.01)
				for k in 8:
					var off := Vector2.from_angle(TAU * float(k) / 8.0) * step
					draw_texture_rect(rim, Rect2(dest.position + off, dest.size), false, RIM)
		draw_texture_rect(sprite, dest, false, tint)
		if tipped:
			draw_set_transform(pan, 0.0, Vector2(zoom, zoom))

	## A soft dark ellipse on the floor, darkest under the feet.
	func _draw_shadow(at: Vector2, rx: float, ry: float) -> void:
		for ring in 3:
			var f := 1.0 - float(ring) * 0.28
			var pts := PackedVector2Array()
			for i in 20:
				var a := TAU * float(i) / 20.0
				pts.append(at + Vector2(cos(a) * rx * f, sin(a) * maxf(ry, 1.0) * f))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.16))

	## The figure's silhouette in white (alpha kept), at most RIM_H px tall; drawn tinted behind a working figure.
	func _rim_tex(sprite: Texture2D) -> Texture2D:
		if rim_cache.has(sprite):
			return rim_cache[sprite]
		var made: Texture2D = null
		var img := sprite.get_image()
		if img != null:
			img = img.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if img.get_height() > RIM_H:
				img.resize(maxi(1, int(float(img.get_width()) * RIM_H / float(img.get_height()))), RIM_H, Image.INTERPOLATE_BILINEAR)
			for y in img.get_height():
				for x in img.get_width():
					img.set_pixel(x, y, Color(1, 1, 1, img.get_pixel(x, y).a))
			made = ImageTexture.create_from_image(img)
		rim_cache[sprite] = made
		return made

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

	## Seconds of frame time the station has been drawn; motion runs on it, so a Movie Maker recording plays at the
	## right speed.
	var life_t := 0.0

	## A still figure is a picture, not an animation: moving it around reads as jumping (owner, playtest 17). Until
	## real animation exists, people stay in place and only breathe, slowly and barely. Reduce motion keeps
	## them still. lo, hi and at_work are kept for the animated version.
	func _life(id: String, x: float, _lo: float, _hi: float, flip: bool, _at_work: bool) -> Dictionary:
		var out := {"x": x, "flip": flip, "lean": 0.0, "bob": 0.0, "breath": 0.0}
		if station == null or station._motion_off():
			return out
		var phase := fmod(_id_hash(id) * 0.0137, 1.0)
		out.breath = sin(life_t * 0.55 + phase * TAU) * 0.005
		return out

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
		var view := Rect2(Vector2.ZERO, size)
		if not view.intersects(target):
			return
		var color := Color("e2a63a")
		draw_rect(target.grow(5.0), color, false, 3.0)
		var card: Control = host.guide_card
		var from := _edge_point(Rect2(card.position, card.size), target.get_center())
		var to := _edge_point(target.grow(5.0), from)
		var dir := from - to
		if dir.length() < 8.0:
			return
		dir = dir.normalized()
		var tip := to + dir * 4.0
		var tail := tip + dir * 18.0
		draw_line(tail, tip, color, 3.0)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			tip,
			tip + dir * 12.0 + side * 5.0,
			tip + dir * 12.0 - side * 5.0,
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
	var badge := 0
	var still := false

	func _process(_delta: float) -> void:
		if badge > 0 and not still and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var font: Font = face if face != null else ThemeDB.fallback_font
		var mid_x := size.x * 0.5
		var mark := Color("e2a63a")
		draw_line(Vector2(mid_x + 7.0, 8.0), Vector2(mid_x - 7.0, 18.0), mark, 3.0)
		draw_line(Vector2(mid_x - 7.0, 18.0), Vector2(mid_x + 7.0, 28.0), mark, 3.0)
		var reserve := 0.0
		if badge > 0:
			reserve = 40.0
			var at := Vector2(mid_x, size.y - 22.0)
			var beat := 0.0 if still else 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
			draw_circle(at, 17.0 + 3.0 * beat, Color(0.89, 0.65, 0.23, 0.18 * beat))
			draw_circle(at, 14.0, mark)
			var digits := str(badge)
			var dw := font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, at + Vector2(-dw * 0.5, 6.0), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("1a1008"))
		if caption == "":
			return
		var font_size := 15
		var room := maxf(24.0, size.y - 44.0 - reserve)
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
			"journal":
				draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.9), Vector2(r * 1.4, r * 1.8)), ink, false, 1.6)
				for k in 4:
					var y := -r * 0.5 + k * r * 0.38
					draw_line(c + Vector2(-r * 0.4, y), c + Vector2(r * (0.4 if k < 3 else 0.05), y), ink, 1.4)
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


class SeatSlot extends Control:
	signal picked
	var ink := Color("b89a6a")
	var open := true
	var hovered := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void:
			hovered = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			hovered = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if not open:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			picked.emit()

	func _draw() -> void:
		var box := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var col := ink
		col.a = 0.95 if hovered and open else (0.7 if open else 0.3)
		if hovered and open:
			draw_rect(box, Color(col.r, col.g, col.b, 0.12))
		var dash := 8.0
		var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], col, 2.0, dash, true)
		var c := box.get_center()
		var arm := minf(box.size.x, box.size.y) * 0.16
		draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), col, 4.0)
		draw_line(c - Vector2(0, arm), c + Vector2(0, arm), col, 4.0)


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


## A small half-round gauge behind glass: a needle over a scale with a red zone at the dangerous end.
class Dial extends Control:
	var value := 50.0
	var needle := Color("d7a441")
	var danger_high := false

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y - 3.0)
		var r := minf(size.x * 0.5, size.y) - 2.0
		draw_arc(c, (r + 1.5) * 0.5, PI, TAU, 24, Color(0.05, 0.05, 0.05, 1.0), r + 1.5, false)
		draw_arc(c, r * 0.5, PI, TAU, 24, Color(0.85, 0.8, 0.68, 0.95), r, false)
		var zone_from := PI * 1.75 if danger_high else PI
		draw_arc(c, r - 2.0, zone_from, zone_from + PI * 0.25, 10, Color(0.75, 0.2, 0.16, 0.9), 4.0, true)
		for k in 6:
			var t := PI + PI * float(k) / 5.0
			draw_line(c + Vector2.from_angle(t) * (r - 1.0), c + Vector2.from_angle(t) * (r - 5.0), Color(0.1, 0.1, 0.1, 0.9), 1.0, true)
		var a := PI + PI * clampf(value / 100.0, 0.0, 1.0)
		draw_line(c, c + Vector2.from_angle(a) * (r - 3.0), Color(0.1, 0.08, 0.06), 3.0, true)
		draw_line(c, c + Vector2.from_angle(a) * (r - 3.0), needle.darkened(0.2), 1.5, true)
		draw_circle(c, 2.5, Color(0.15, 0.12, 0.1))
		draw_arc(c, r + 1.0, PI, TAU, 24, Color(0.62, 0.5, 0.3, 0.8), 1.2, true)
