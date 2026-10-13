extends SceneTree

## Clarity pass (docs/briefs/cursor_clarity_pass.txt), headless on the real station:
##   B1  a rebuilt card leaves no empty paper; a second press inside the guard window is dropped.
##   B2  station and network cameras keep the dark void out at every zoom and window size.
##   B3  wheel zoom keeps the point under the cursor unless the bounds need the view to move.
##   U1-U4  upgrade tiers on the yard sign, the room card and titles; before and after numbers equal what is applied.
##   Price  tier II costs upgrade_step_cost times tier I (rounded up); the card shows and the purchase takes that price.
##   Effects  each of the 13 upgrades changes the sim as its card line says (beds, power use, upkeep, digging,
##            workshop shutdowns, the Cough, the flood warning, hope and discontent, +25% output).
##   M1, M3  the network map opens filling 90 percent of the free area; zoom bounds, the deepest zoom, + - and Whole map.
##   End turn is "waiting" while a dawn choice is open and lit when ready; the dawn and event card titles.
##   Effect words under five event choices and five audiences (deal and help) match what applying them changes.
##   C8  people, beds and the weekly overcrowding cost on the people line, the people tab and the ticker.
##   C9  Settings in a framed card over a dim, below the top bar, Back inside, Esc closes, at 1280x720 and 1024x768.
##   Hints: shown in their weeks, hidden under a modal, dismissed by the action or a click, remembered in the
##   player's settings file (not the save), off in shot runs and on saves loaded past week 6.
## Settings, saves and logs go to user://check_clarity, never to the player's own files.
##   godot --headless --path . -s res://sim/check_clarity.gd

const SCRATCH := "user://check_clarity"
const LEADERS := ["directorate", "depot", "synod", "exchange", "black_flag"]
const SIZES := [Vector2(1280, 720), Vector2(1024, 768), Vector2(1920, 1080)]

var bad: PackedStringArray = []
var catalog: Catalog
var numbers_done := false
var st


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Copy.set_lang("en")
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = false
	Settings.load_file()
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	Settings.hints_on = true
	Settings.hints_seen = []
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	catalog = Catalog.new()
	if not catalog.load_all():
		bad.append("catalog: " + catalog.error)
	_hint_file()
	st = load("res://ui/station.tscn").instantiate()
	root.add_child(st)
	for i in 3:
		await process_frame
	st._begin_new_game(false)
	await _frames(4)
	await _end_turn_logic()
	await _card_gap()
	_double_press()
	_yard_bounds()
	_network_bounds()
	_event_words()
	_audience_words()
	_crowd_words()
	await _upgrade_view()
	_upgrade_effects()
	_week_numbers()
	if not numbers_done:
		bad.append("N1: the week check stopped on a script error")
	await _settings_sheet()
	await _hint_flow()
	st._end_log()
	st.queue_free()
	await process_frame
	for line in bad:
		print("FAIL " + line)
	print("CLARITY CHECK OK" if bad.is_empty() else "CLARITY CHECK FAILED (%d)" % bad.size())
	quit(0 if bad.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _clear_modals() -> void:
	st.game.pending.clear()
	for i in 6:
		if st.deck.is_empty() and not st.modal_open:
			break
		st._close_card()
	st._refresh()


## End turn: dark while the dawn choice waits, lit (brass ready face) when the week can end, off at the end.
func _end_turn_logic() -> void:
	var game: Game = st.game
	if game.pending.is_empty():
		game.pending.append(_plain_event())
	st._show_dawn()
	await process_frame
	if st._end_state() != "waiting" or not st.end_button.disabled:
		bad.append("end turn: pending choice gives %s, disabled %s" % [st._end_state(), st.end_button.disabled])
	var tag := _find_meta(st.card_body, "card_tag")
	if tag == null or str(tag.get_meta("card_tag")) != "Event":
		bad.append("event card has no Event tag")
	_clear_modals()
	st._sync_waiting()
	var face: StyleBoxFlat = st.end_button.get_theme_stylebox("normal")
	if st._end_state() != "ready" or st.end_button.disabled or face.border_color != Color("fff0c8"):
		bad.append("end turn: ready state %s, disabled %s, border %s" % [st._end_state(), st.end_button.disabled, face.border_color])
	st._paint_dawn()
	await process_frame
	if not _shows(st.card_body, "Dawn of week %d" % game.week):
		bad.append("new-week card title is not 'Dawn of week %d'" % game.week)
	if _find_meta(st.card_body, "card_tag") != null:
		bad.append("new-week card carries the Event tag")
	_clear_modals()
	game.over = "test"
	if st._end_state() != "over":
		bad.append("end turn: game over gives %s" % st._end_state())
	game.over = ""
	st._sync_waiting()


## C8: the population line, the people tab and the overcrowding ticker say people, beds and the weekly cost,
## with the numbers the week end actually uses.
func _crowd_words() -> void:
	_clear_modals()
	var game: Game = st.game
	var added := 0
	while game.residents.size() <= game.housing():
		var twin: Dictionary = game.residents[0].duplicate(true)
		twin.id = "%s_crowd%d" % [str(twin.id), added]
		game.residents.append(twin)
		added += 1
	st._refresh()
	var cost := int(game.bal.overcrowd_discontent)
	var want := "People: %d. Beds: %d. Not enough beds raises discontent by %d a week." % [game.residents.size(), game.housing(), cost]
	for pair in [["ticker", st.ticker_label], ["people head", st.people_head], ["people tab", st.people_tab]]:
		if str(pair[1].tooltip_text) != want:
			bad.append("C8: %s tooltip is '%s'" % [pair[0], pair[1].tooltip_text])
	st._show_crowd()
	if not _shows(st.card_body, want):
		bad.append("C8: overcrowding card does not explain the beds")
	_clear_modals()
	Copy.set_lang("ru")
	if not game.crowd_tip().begins_with("Людей: %d. Коек: %d." % [game.residents.size(), game.housing()]):
		bad.append("C8: RU tip is '%s'" % game.crowd_tip())
	Copy.set_lang("en")
	var kept: Array = game.residents.duplicate()
	while game.residents.size() > game.housing():
		game.residents.pop_back()
	st._refresh()
	if st.ticker_label.text == game.crowd_line():
		bad.append("C8: ticker still shows overcrowding with enough beds")
	var calm := "People: %d. Beds: %d." % [game.residents.size(), game.housing()]
	if game.crowd_tip() != calm or st.people_head.tooltip_text != calm:
		bad.append("C8: with enough beds the tip is '%s'" % st.people_head.tooltip_text)
	game.residents = kept
	for i in added:
		game.residents.pop_back()
	st._refresh()
	print("C8 crowd tip: %s" % want)


## N1: the resource card's week (WeekForecast) against what End turn really does to the stock, careful and
## expander bots, 5 seeds x 40 weeks each. Power, air and materials must match exactly; food must fall inside the harvest range.
## Skipped and counted: weeks where the day's End turn work (pending events, the rival phase) changes the stock or
## the rooms before the night, and cough weeks (the night moves and sickens workers before counting output).
func _week_numbers() -> void:
	var total := 0
	var skipped := 0
	var wrong := 0
	var runs := []
	for profile in ["careful", "expander"]:
		for run_seed in [1, 2, 3, 4, 5]:
			runs.append([profile, run_seed])
	for run in runs:
		var run_seed := int(run[1])
		var game := Game.new()
		game.setup(catalog, run_seed, 40)
		var bot := Bot.new()
		bot.profile = str(run[0])
		var seen := 0
		var skip_day := 0
		var skip_cough := 0
		while game.over == "" and game.week <= 40:
			bot._act(game)
			seen += 1
			var fc: Dictionary = WeekForecast.week(game)
			var before := _rooms_state(game)
			game._resolve_pending()
			game._rival_phase()
			var day_moved := _rooms_state(game) != before
			var cough := game._season_is("cough")
			game._night()
			if day_moved:
				skip_day += 1
			elif cough:
				skip_cough += 1
			else:
				for key in WeekForecast.KEYS:
					var row: Dictionary = fc[key]
					var net := int(game.last_net.get(key, 0))
					var ok := net == int(row.net)
					if key == "food":
						ok = net >= int(row.low) and net <= int(row.high)
					if not ok:
						wrong += 1
						if wrong <= 8:
							bad.append("N1 seed %d week %d %s: card net %+d (food %+d..%+d), stock moved %+d" % [run_seed, game.week, key, int(row.net), int(row.get("low", 0)), int(row.get("high", 0)), net])
			game._finish_checks()
			game._invariants()
			if game.over != "":
				break
			game.week += 1
			game.decisions = 0
			game._dawn()
			game._vo_watch()
		total += seen
		skipped += skip_day + skip_cough
		print("N1 %s seed %d: %d weeks, checked %d, skipped %d (day work %d, cough %d)" % [str(run[0]), run_seed, seen, seen - skip_day - skip_cough, skip_day + skip_cough, skip_day, skip_cough])
	for case in ["brownout", "generator_half", "workshop_down", "belt_down", "quarantine", "cold", "filter_broke", "switched_off"]:
		var game := Game.new()
		game.setup(catalog, 7, 40)
		match case:
			"brownout":
				for room in game.rooms:
					if str(room.type) == "generator":
						for id in room.staff.duplicate():
							game._unassign(str(id))
				game.stock.power = 3
			"generator_half":
				game.gen_down = true
			"workshop_down":
				game.workshop_down = true
			"belt_down":
				game.belt_down = true
			"quarantine":
				game.quarantine = true
			"cold":
				game.crunch_power = true
				game.stock.power = 5
			"filter_broke":
				for room in game.rooms:
					if str(room.type) == "air_filter":
						room.disabled = 2
			"switched_off":
				for room in game.rooms:
					if str(room.type) == "workshop":
						game.apply({"kind": "switch", "room": str(room.uid), "on": false})
		var fc: Dictionary = WeekForecast.week(game)
		game._night()
		for key in WeekForecast.KEYS:
			var net := int(game.last_net.get(key, 0))
			var row: Dictionary = fc[key]
			var ok := net == int(row.net) if key != "food" else (net >= int(row.low) and net <= int(row.high))
			if not ok:
				bad.append("N1 case %s %s: card net %+d, stock moved %+d" % [case, key, int(row.net), net])
		print("N1 case %s: power %+d air %+d materials %+d food %+d..%+d" % [case, int(fc.power.net), int(fc.air.net), int(fc.materials.net), int(fc.food.low), int(fc.food.high)])
	numbers_done = true
	print("N1 total: %d weeks, skipped %d (%.0f%%), mismatches %d" % [total, skipped, 100.0 * skipped / maxf(1.0, total), wrong])
	if skipped * 3 > total:
		bad.append("N1: %d of %d weeks skipped, more than a third; the check is too weak" % [skipped, total])


func _rooms_state(game: Game) -> String:
	var parts: PackedStringArray = []
	for key in WeekForecast.KEYS:
		parts.append("%s=%d" % [key, int(game.stock[key])])
	for room in game.rooms:
		parts.append("%s:%s:%s:%s" % [str(room.uid), str(room.staff), str(room.offline), str(room.get("disabled", 0))])
	for person in game.residents:
		parts.append("%s:%d:%d" % [str(person.id), int(person.sick), int(person.absent)])
	parts.append(str(game.laws_on.keys()) + str(game.active_season.get("id", "")))
	parts.append(str(game.quarantine) + str(game.belt_down) + str(game.workshop_down) + str(game.gen_down) + str(game.crunch_power) + str(game.vent_cut))
	return "|".join(parts)


## C9: Settings from the game sits in a framed card over a dark overlay, below the top bar, Back inside; Esc closes.
func _settings_sheet() -> void:
	_clear_modals()
	var views := []
	for window in [Vector2(1280, 720), Vector2(1024, 768)]:
		views.append([window / Settings.auto_scale(int(window.y)), true])
		views.append([window, false])
	for pair in views:
		var view: Vector2 = pair[0]
		st.size = view
		st._layout()
		st._open_settings(true)
		await _frames(3)
		var frame: Control = st.menu_settings.get_child(0)
		var box: Rect2 = frame.get_global_rect()
		if not st.menu_dim.visible:
			bad.append("C9: no dim behind Settings")
		if bool(pair[1]) and box.position.y < st.hud.get_global_rect().end.y:
			bad.append("C9 %s: Settings card starts at %.0f, under the top bar" % [view, box.position.y])
		if not Rect2(Vector2.ZERO, view).grow(1.0).encloses(box):
			bad.append("C9 %s: Settings card %s leaves the window" % [view, box])
		var back := _find_meta(frame, "sheet_back")
		if back == null:
			bad.append("C9: Back is not inside the Settings card")
		if not _shows(frame, "Settings"):
			bad.append("C9: the Settings title is not inside the card")
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		st._unhandled_key_input(esc)
		if st.menu_layer.visible:
			bad.append("C9: Esc did not close Settings")
	st.size = Vector2(1280, 720)
	st._layout()


func _plain_event() -> Dictionary:
	for ev in catalog.events:
		if ev.get("choices", []).size() >= 2 and not ev.has("trigger"):
			return ev.duplicate(true)
	return {}


## B1: rebuilding an open room card (what a second click does) must not leave the card taller than its content.
func _card_gap() -> void:
	_clear_modals()
	var uid := ""
	for room in st.game.rooms:
		if int(catalog.rooms[str(room.type)].get("staff_max", 0)) > 0:
			uid = str(room.uid)
			break
	for round in 3:
		st._show_room(uid)
		await _frames(2)
	await _frames(40)
	var gap: float = st.card.size.y - (st.card_body.get_combined_minimum_size().y + 52.0)
	if gap > 6.0:
		bad.append("B1: room card rebuilt three times leaves %.0f px of empty paper" % gap)
	print("B1 card gap after rebuilds: %.0f px" % gap)


## B1: two presses inside the guard window run the action once; a later press runs it again.
func _double_press() -> void:
	var runs := [0]
	st.on_paper = true
	var button: Button = st._button("Probe", func() -> void: runs[0] += 1)
	st.card_click_guard = 0
	button.pressed.emit()
	button.pressed.emit()
	if runs[0] != 1:
		bad.append("B1: double press ran the action %d times" % runs[0])
	st.card_click_guard = 0
	button.pressed.emit()
	if runs[0] != 2:
		bad.append("B1: press after the guard window was dropped")
	button.free()
	_clear_modals()


## B2 and B3 on the station view.
func _yard_bounds() -> void:
	var yard = st.yard
	var checked := 0
	for view in SIZES:
		yard.size = view
		yard.fit()
		var base: float = yard._fit_zoom()
		for user_zoom in [1.0, 1.4, 2.5, 5.0, 8.0]:
			yard.user_zoom = user_zoom
			yard.zoom = base * user_zoom
			for far in [Vector2(-1e5, -1e5), Vector2(1e5, 1e5), Vector2(-1e5, 1e5), Vector2(1e5, -1e5), Vector2.ZERO]:
				yard.pan = far
				yard._clamp_pan()
				var why := _covers(yard.view_bounds(), yard._content())
				checked += 1
				if why != "":
					bad.append("B2 station %s zoom x%.1f pan %s: %s" % [view, user_zoom, far, why])
		yard.fit()
		var area: Rect2 = yard._content()
		var framed: Vector2 = yard.pan
		var spot := area.position + area.size * Vector2(0.2, 0.35)
		var other := area.position + area.size * Vector2(0.75, 0.6)
		for step in 4:
			_zoom_kept(yard, spot, 1.12, "in", view)
		for step in 12:
			_zoom_kept(yard, other, 1.0 / 1.12, "out", view)
		if yard.user_zoom > 1.001:
			bad.append("B3 station %s: zoom out did not reach the fit zoom" % view)
		var why := _covers(yard.view_bounds(), area)
		if why != "":
			bad.append("B3 station %s after zoom out: %s" % [view, why])
		if absf(yard.pan.x - framed.x) < 0.5 and absf(_free_span(yard)) > 2.0:
			bad.append("B3 station %s: zooming out snapped back to the framed centre" % view)
	print("B2 station: %d clamps checked over %d window sizes" % [checked, SIZES.size()])
	yard.fit()


## Room left for the content to slide on x at the current zoom (negative when it is pinned).
func _free_span(yard) -> float:
	return absf(yard.view_bounds().size.x - yard._content().size.x)


## One wheel step at `spot`: the world point under it stays put, or the bounds forced the move.
func _zoom_kept(yard, spot: Vector2, factor: float, way: String, view: Vector2) -> void:
	var world: Vector2 = yard._unview(spot)
	yard._zoom_at(spot, factor)
	var drift: Vector2 = yard._unview(spot) - world
	if drift.length() * yard.zoom <= 0.5:
		return
	var kept: Vector2 = yard.pan
	yard.pan = spot - world * yard.zoom
	var why := _covers(yard.view_bounds(), yard._content())
	yard.pan = kept
	if why == "":
		bad.append("B3 station %s zoom %s moved the view %.1f px with no bounds reason" % [view, way, drift.length() * yard.zoom])


## "" when `shown` keeps the void out of `area` on both axes: smaller content stays inside, larger covers it.
func _covers(shown: Rect2, area: Rect2) -> String:
	for axis in 2:
		var lo: float = shown.position[axis]
		var hi: float = shown.end[axis]
		var a_lo: float = area.position[axis]
		var a_hi: float = area.end[axis]
		var name := "x" if axis == 0 else "y"
		if hi - lo <= a_hi - a_lo:
			if lo < a_lo - 0.5 or hi > a_hi + 0.5:
				return "%s: content %.0f..%.0f leaves the view %.0f..%.0f" % [name, lo, hi, a_lo, a_hi]
		elif lo > a_lo + 0.5 or hi < a_hi - 0.5:
			return "%s: void shows, content %.0f..%.0f, view %.0f..%.0f" % [name, lo, hi, a_lo, a_hi]
	return ""


## B2 and B3 on the network map.
func _network_bounds() -> void:
	st._toggle_network()
	var net = st.network_view
	var checked := 0
	for view in SIZES:
		net.size = view
		net._fit()
		for factor in [1.0, 1.6, 3.0, 100.0]:
			net.zoom = clampf(net._zoom_min * factor, net._zoom_min, net._zoom_max)
			var box: Rect2 = net._map_box()
			for far in [box.position - Vector2(1e4, 1e4), box.end + Vector2(1e4, 1e4), Vector2(box.position.x - 1e4, box.end.y + 1e4), box.get_center()]:
				net.origin = far
				net._clamp_view()
				checked += 1
				var why := _covers(_net_shown(net), net._open_area())
				if why != "":
					bad.append("B2 network %s zoom x%.1f: %s" % [view, factor, why])
		net._fit()
		_map_fill(net, view)
		var area: Rect2 = net._open_area()
		var spot := area.position + area.size * Vector2(0.25, 0.3)
		for step in 10:
			var factor := 1.12 if step < 4 else 1.0 / 1.12
			var world: Vector2 = net._world(spot)
			net._zoom_at(spot, factor)
			var drift: Vector2 = (net._world(spot) - world) * net.zoom
			if drift.length() > 0.5:
				var kept: Vector2 = net.origin
				net.origin = world - (spot - net._center()) / net.zoom
				var why := _covers(_net_shown(net), area)
				net.origin = kept
				if why == "":
					bad.append("B3 network %s: zoom moved the view %.1f px with no bounds reason" % [view, drift.length()])
	print("B2 network: %d clamps checked" % checked)
	st._toggle_network()


## Map size: the opening view fills 90 percent of the free area with every station inside it; no void at the
## smallest and the largest zoom; the deepest zoom shows a dense station and its neighbours on about a third of
## the window; the "+", "-" and "Whole map" buttons step the zoom and come back to the opening view.
func _map_fill(net, view: Vector2) -> void:
	var area: Rect2 = net._open_area()
	var spots := Rect2()
	var first := true
	for sid in net._spots:
		var at: Vector2 = net._screen(net._map_xf * net._map_spot(str(sid)))
		spots = Rect2(at, Vector2.ZERO) if first else spots.expand(at)
		first = false
		if not area.has_point(at):
			bad.append("M1 network %s: station %s at %s is outside the free area %s" % [view, sid, at, area])
	var fill := maxf(spots.size.x / area.size.x, spots.size.y / area.size.y)
	print("M1 network %s: stations fill %.0f%% of the free area" % [view, 100.0 * fill])
	if fill < 0.9:
		bad.append("M1 network %s: the opening view fills %.0f%% of the free area, under 90%%" % [view, 100.0 * fill])
	var opening: float = net.zoom
	var kept: Vector2 = net.origin
	for z in [net._zoom_min, net._zoom_max]:
		net.zoom = z
		for far in [Vector2(-1e5, -1e5), Vector2(1e5, 1e5)]:
			net.origin = far
			net._clamp_view()
			var why := _covers(_net_shown(net), area)
			if why != "":
				bad.append("M3 network %s at zoom %.2f: %s" % [view, z, why])
	var third := minf(view.x, view.y) / 3.0
	var span: float = net._neighbour_span()
	if span <= 0.0 or span * net._zoom_max < third * 0.95:
		bad.append("M3 network %s: at the deepest zoom a dense station and its neighbours span %.0f px, under a third (%.0f)" % [view, span * net._zoom_max, third])
	net.zoom = opening
	net.origin = kept
	net._zoom_button("out")
	if not is_equal_approx(net.zoom, opening):
		bad.append("M3 network %s: '-' went below the opening zoom" % view)
	net._zoom_button("in")
	net._zoom_button("in")
	if net.zoom <= opening * 1.2:
		bad.append("M3 network %s: '+' did not zoom in (%.2f from %.2f)" % [view, net.zoom, opening])
	net._zoom_button("fit")
	if not is_equal_approx(net.zoom, opening) or net.origin.distance_to(kept) > 0.5:
		bad.append("M3 network %s: 'Whole map' did not return to the opening view" % view)
	var bar: Rect2 = net._zoom_bar.get_rect()
	if not Rect2(Vector2.ZERO, view).encloses(bar) or bar.end.y > net._chrome_top() + 0.5:
		bad.append("M3 network %s: zoom buttons %s are off the map or over the bottom buttons" % [view, bar])


## U1 to U4: the hydroponics sign and room card show tiers 0, I and II; with a second hydroponics the card title
## and the people list say "Hydroponics, tier II"; the upgrade card's "after" numbers are what the room makes
## once bought, the toast names the upgrade and its gain, the room flashes and the journal keeps the tier.
func _upgrade_view() -> void:
	var game: Game = st.game
	_clear_modals()
	var uid := ""
	for room in game.rooms:
		if str(room.type) == "hydroponics":
			uid = str(room.uid)
	if uid == "":
		bad.append("U: no hydroponics on a new game")
		return
	var room: Dictionary = game._room(uid)
	var twin: Dictionary = room.duplicate(true)
	twin.uid = uid + "_twin"
	twin.staff = []
	for tier in [0, 1, 2]:
		await _frames(2)
		var sign := str(st.yard.sign_tiers.get(uid, ""))
		if sign != st.roman(tier):
			bad.append("U1 tier %d: the sign shows '%s'" % [tier, sign])
		st._show_room(uid)
		var chip := _find_meta(st.card_body, "tier_chip")
		if (tier == 0) != (chip == null) or (chip != null and int(chip.get_meta("tier_chip")) != tier):
			bad.append("U2 tier %d: the room card's tier plate is %s" % [tier, "missing" if chip == null else str(chip.get_meta("tier_chip"))])
		game.rooms.append(twin)
		var title: String = st.room_title(room)
		var want := "Hydroponics" if tier == 0 else "Hydroponics, tier %s" % st.roman(tier)
		if title != want:
			bad.append("U4 tier %d with two hydroponics: title '%s', want '%s'" % [tier, title, want])
		game.rooms.erase(twin)
		if st.room_title(room) != "Hydroponics":
			bad.append("U4: a single upgraded hydroponics is titled '%s'" % st.room_title(room))
		_clear_modals()
		if tier == 2:
			break
		game.stock.materials = 99
		var gains: Array = st.upgrade_gains(uid)
		st._confirm_upgrade(uid)
		var head := _find_meta(st.card_body, "upgrade_title")
		if head == null or int(head.get_meta("upgrade_title")) != tier + 1:
			bad.append("U2 tier %d: the upgrade card does not name tier %s" % [tier, st.roman(tier + 1)])
		if not _shows(st.card_body, "Grow lamps: Food +25%." if tier == 0 else "Mushroom beds: Food +25%, power use 2 -> 1."):
			bad.append("U2 tier %d: the upgrade's plain words are missing" % tier)
		var shown := _find_meta(st.card_body, "upgrade_gain")
		if shown == null:
			bad.append("U2 tier %d: no before and after line" % tier)
		var price: int = [8, 12][tier]
		var tag := _find_meta(st.card_body, "upgrade_cost")
		if tag == null or int(tag.get_meta("upgrade_cost")) != price or tag.text != str(price):
			bad.append("Price tier %d: the card's price is %s, want %d" % [tier, "missing" if tag == null else tag.text, price])
		st._do_upgrade(uid)
		if int(room.upgrade) != tier + 1:
			bad.append("U3 tier %d: the upgrade was not bought" % tier)
			return
		if int(game.stock.materials) != 99 - price:
			bad.append("Price tier %d: the upgrade took %d materials, want %d" % [tier, 99 - int(game.stock.materials), price])
		st._sync_numbers()
		for row in gains:
			var now: int = st._room_amount(uid, str(row.key))
			if now != int(row.after):
				bad.append("U2 tier %d: the card said %s %+d after, the room makes %+d" % [tier, row.key, int(row.after), now])
		var toast: String = st.toast_label.text if st.toast_label != null else ""
		if not toast.begins_with("Hydroponics upgraded: %s" % st._upgrade_name(["grow_lamps", "mushroom_beds"][tier])):
			bad.append("U3 tier %d: toast '%s'" % [tier, toast])
		if not st.yard.flash.has(uid):
			bad.append("U3 tier %d: no flash on the room" % tier)
		var last: Dictionary = game.journal[game.journal.size() - 1] if not game.journal.is_empty() else {}
		if str(last.get("kind", "")) != "upgrade" or int(last.get("tier", 0)) != tier + 1:
			bad.append("U3 tier %d: the journal's last line is %s" % [tier, last])
		print("U tier %d -> %d: %s | journal: %s" % [tier, tier + 1, toast, st._journal_line(last)])
	_clear_modals()
	var tier2 := {"quarters": 9, "workshop": 9, "hydroponics": 12, "air_filter": 12, "generator": 15, "infirmary": 12, "meeting_hall": 12, "radio": 12}
	for type in tier2:
		var first := int(game.catalog.rooms[type].upgrade_materials)
		if game.upgrade_cost(type, 1) != first or game.upgrade_cost(type, 2) != int(tier2[type]):
			bad.append("Price %s: tier I costs %d (want %d), tier II costs %d (want %d)" % [type, game.upgrade_cost(type, 1), first, game.upgrade_cost(type, 2), tier2[type]])


func _upgrade_effects() -> void:
	var game := Game.new()
	game.setup(st.game.catalog, 1, 40)
	var lines := {
		"bunks": "Bunks: +2 beds.",
		"family": "Family: +2 beds, hope +1 a week.",
		"grow_lamps": "Grow lamps: Food +25%.",
		"mushroom_beds": "Mushroom beds: Food +25%, power use 2 -> 1.",
		"charcoal": "Charcoal: Air +25%.",
		"pressure_seals": "Pressure seals: Air +25%, upkeep 2 -> 1 materials a week.",
		"dynamo": "Dynamo: Power +25%.",
		"substation": "Substation: Power +25%, power use 2 -> 0.",
		"drill_heads": "Drill heads: Materials +25%, digging takes 1 week less, at least 1 week.",
		"armor": "Armor: Materials +25%, events cannot shut the workshop down.",
		"quarantine_ward": "Quarantine ward: the Cough spreads 40% -> 20% a week.",
		"loudspeakers": "Loudspeakers: Influence +25%, discontent -1 a week.",
		"antenna": "Antenna: flood warning 2 -> 3 weeks ahead.",
	}
	for id in lines:
		var said: String = st._upgrade_what(id)
		if said != lines[id]:
			bad.append("Effects %s: the card says '%s', want '%s'" % [id, said, lines[id]])
	var made := {}
	for type in ["quarters", "hydroponics", "air_filter", "generator", "workshop", "infirmary", "meeting_hall", "radio"]:
		var room: Dictionary = {"uid": "fx_" + type, "type": type, "level": 9, "cell": 9, "upgrade": 0, "efficiency": 1.0,
			"staff": [], "offline": false, "browned": false, "disabled": 0}
		game.rooms.append(room)
		made[type] = room
	var beds := game.housing()
	var hope_d := game.upgrade_mood("hope_week")
	made.quarters.upgrade = 1
	_fx_expect(game.housing() == beds + 2, "bunks: beds %d -> %d" % [beds, game.housing()])
	made.quarters.upgrade = 2
	_fx_expect(game.housing() == beds + 4 and game.upgrade_mood("hope_week") == hope_d + 1, "family: beds %d, hope a week %d" % [game.housing(), game.upgrade_mood("hope_week")])
	made.hydroponics.upgrade = 2
	_fx_expect(game.room_power(made.hydroponics) == 1, "mushroom beds: power use %d" % game.room_power(made.hydroponics))
	made.air_filter.upgrade = 2
	_fx_expect(game.filter_upkeep(made.air_filter) == 1, "pressure seals: upkeep %d" % game.filter_upkeep(made.air_filter))
	made.generator.upgrade = 2
	_fx_expect(game.room_power(made.generator) == 0, "substation: generator power use %d" % game.room_power(made.generator))
	var dig_before := int(game._dig_cost(2).turns)
	made.workshop.upgrade = 1
	_fx_expect(dig_before > 1 and int(game._dig_cost(2).turns) == dig_before - 1, "drill heads: dig %d -> %d weeks" % [dig_before, int(game._dig_cost(2).turns)])
	_fx_expect(not game.shrugs_down(made.workshop), "drill heads alone shrug off shutdowns")
	made.workshop.upgrade = 2
	game._disable_room("workshop", 2)
	_fx_expect(game.shrugs_down(made.workshop) and int(made.workshop.disabled) == 0, "armour: workshop disabled %d" % int(made.workshop.disabled))
	made.infirmary.upgrade = 1
	_fx_expect(is_equal_approx(game.station_fx("cough_spread"), 0.5), "quarantine ward: spread x%.2f" % game.station_fx("cough_spread"))
	var dis_d := game.upgrade_mood("discontent_week")
	made.meeting_hall.upgrade = 1
	_fx_expect(game.upgrade_mood("discontent_week") == dis_d - 1, "loudspeakers: discontent a week %d" % game.upgrade_mood("discontent_week"))
	made.radio.upgrade = 1
	_fx_expect(game.flood_warning() == 3, "antenna: flood warning %d weeks" % game.flood_warning())
	made.radio.offline = true
	_fx_expect(game.flood_warning() == 2, "antenna switched off: flood warning %d weeks" % game.flood_warning())
	print("Effects: 13 upgrade lines and their sim effects checked")


func _fx_expect(ok: bool, what: String) -> void:
	if not ok:
		bad.append("Effects " + what)


func _net_shown(net) -> Rect2:
	var box: Rect2 = net._map_box()
	return Rect2(net._screen(box.position), box.size * net.zoom)


## Five plain event choices (no check, bet or people): the effect line built before the pick equals the line
## built from what the pick actually changed.
func _event_words() -> void:
	var cases := 0
	var hopes := [50, 99, 2, 60, 40]
	for ev in catalog.events:
		if cases >= 5:
			break
		if ev.has("trigger"):
			continue
		for choice in ev.get("choices", []):
			if choice.has("check") or choice.has("bet") or choice.has("people") or choice.has("sick") or choice.has("papers"):
				continue
			var game := Game.new()
			game.setup(catalog, 7 + cases, 40)
			game.hope = int(hopes[cases])
			game.pending = [ev.duplicate(true)]
			if game.choice_locked(choice) or not game.choice_offered(choice) or not game._afford(choice.get("cost", {})):
				continue
			var fx := game.choice_effects(choice)
			var words := _with_game(game, func(): return st._choice_words(fx))
			if words == "":
				continue
			var before := _snap(game)
			if not game.apply({"kind": "event", "event_id": str(ev.id), "choice_id": str(choice.id)}):
				continue
			var real := _moved(before, _snap(game))
			var real_words := _with_game(game, func(): return st._choice_words(real))
			if words != real_words:
				bad.append("event %s/%s: button says '%s', the pick did '%s'" % [ev.id, choice.id, words, real_words])
			cases += 1
			print("event %s/%s: %s" % [ev.id, choice.id, words])
			break
	if cases < 5:
		bad.append("only %d event choices checked" % cases)


func _snap(game: Game) -> Dictionary:
	return {"stock": game.stock.duplicate(), "hope": game.hope, "discontent": game.discontent,
		"standing": game.standing.duplicate(), "papers": int(game.artifacts.get("papers", 0))}


func _moved(was: Dictionary, now: Dictionary) -> Dictionary:
	var fx := {"stock": {}, "hope": int(now.hope) - int(was.hope), "discontent": int(now.discontent) - int(was.discontent),
		"people": 0, "sick": 0, "papers": int(now.papers) - int(was.papers), "standing": {}, "check": false, "bet": false}
	for key in now.stock:
		var delta := int(now.stock[key]) - int(was.stock.get(key, 0))
		if delta != 0:
			fx.stock[key] = delta
	for fid in now.standing:
		var delta := int(now.standing[fid]) - int(was.standing.get(fid, 0))
		if delta != 0:
			fx.standing[fid] = delta
	return fx


func _with_game(game: Game, call: Callable) -> String:
	var kept = st.game
	st.game = game
	var out := str(call.call())
	st.game = kept
	return out


## Five leaders at the door: the deal line equals the line built from what accepting changed; the help line
## equals what offering help spent and moved.
func _audience_words() -> void:
	for fid in LEADERS:
		var game := _door(fid)
		var fx := game.audience_effects()
		var words := _with_game(game, func(): return st._deal_words(fx))
		var before := _snap(game)
		var pop := game.residents.size()
		var handed := str(fx.hand_over)
		var handed_name := _with_game(game, func(): return st._resident_name(game.people[handed]) if handed != "" else "")
		if not game.apply({"kind": "audience", "accept": true}):
			bad.append("audience %s: deal refused (%s)" % [fid, game.audience_reason()])
			continue
		var real := _moved(before, _snap(game))
		var real_fx := fx.duplicate(true)
		real_fx.hope = real.hope
		real_fx.discontent = real.discontent
		real_fx.food = int(real.stock.get("food", 0))
		var regard := {}
		for other in fx.standing:
			if real.standing.has(other):
				regard[other] = real.standing[other]
		for other in real.standing:
			if not regard.has(other):
				regard[other] = real.standing[other]
		real_fx.standing = regard
		if handed != "" and (game.residents.size() != pop - 1 or game.people.has(handed)):
			bad.append("audience %s: %s was not handed over" % [fid, handed_name])
		var real_words := _with_game(game, func(): return st._deal_words(real_fx) if handed == "" else words)
		if words != real_words:
			bad.append("audience %s: Take the deal says '%s', accepting did '%s'" % [fid, words, real_words])
		print("audience %s deal: %s" % [fid, words])
		var helper := _door(fid)
		var help: Dictionary = helper.help_effects()
		if help.is_empty() or helper.help_reason() != "":
			continue
		var stock_was := int(helper.stock[str(help.resource)])
		var regard_was := int(helper.standing.get(fid, 0))
		if not helper.apply({"kind": "audience", "help": true}):
			bad.append("audience %s: help refused" % fid)
			continue
		if stock_was - int(helper.stock[str(help.resource)]) != int(help.amount) or int(helper.standing.get(fid, 0)) - regard_was != int(help.standing):
			bad.append("audience %s: help line says %s %d, regard %d; applying spent %d, regard %d" % [fid, help.resource, int(help.amount),
				int(help.standing), stock_was - int(helper.stock[str(help.resource)]), int(helper.standing.get(fid, 0)) - regard_was])


func _door(fid: String) -> Game:
	var game := Game.new()
	game.setup(catalog, 1, 60)
	game.week = 21
	game.stock.food = maxi(int(game.stock.food), 20)
	game.audience_last = {}
	game.help_last = {}
	var target := game.list_target() if fid == "directorate" else ""
	game.audience = {"faction": fid, "week": game.week, "target": target}
	return game


## Settings round trip: hints on/off and the seen ids survive a reload; nothing about hints is in a save.
func _hint_file() -> void:
	Settings.hints_on = false
	Settings.hints_seen = ["dig", "network"]
	Settings.save()
	Settings.hints_on = true
	Settings.hints_seen = []
	Settings.loaded = false
	Settings.load_file()
	if Settings.hints_on or Settings.hints_seen != ["dig", "network"]:
		bad.append("hints settings did not survive a reload: on %s, seen %s" % [Settings.hints_on, Settings.hints_seen])
	for key in Game.PERSIST:
		if str(key).contains("hint"):
			bad.append("save carries %s" % key)
	Settings.hints_on = true
	Settings.hints_seen = []
	Settings.save()


func _hint_flow() -> void:
	_clear_modals()
	st.shot_mode = false
	st.hints_late = false
	st._hide_hint()
	st.game.week = 1
	st._tick_hints()
	if st.hint_id != "dig" or st.hint_box == null:
		bad.append("week 1: dig hint not shown (got '%s'; allowed %s, modal %s, target %s, deck %d, dim %s, notice %s, menu %s)" % [
			st.hint_id, st._hints_allowed(), st._modal_up(), st._hint_target("dark_cell"), st.deck.depth(), st.modal_open,
			st.notice_layer != null, st.at_menu])
		return
	await process_frame
	var box: Rect2 = st.hint_box.get_rect()
	if box.position.x < 0.0 or box.end.x > st.size.x or box.position.y < 0.0 or box.end.y > st.size.y:
		bad.append("dig hint callout %s leaves the window %s" % [box, st.size])
	if st.hint_box.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		bad.append("hint callout takes mouse input")
	st._show_power()
	st._tick_hints()
	if st.hint_box != null or st.hint_id != "dig":
		bad.append("hint stays on screen under a modal")
	var dug := false
	for level in 3:
		for cell in 6:
			if not dug and st.yard._kind(st.game.cells["%d:%d" % [level, cell]]) == "undug" and bool(st.game.dig_preview(level, cell).ok):
				dug = st.game.apply({"kind": "dig", "level": level, "cell": cell})
	_clear_modals()
	st._tick_hints()
	if not dug or not Settings.hints_seen.has("dig"):
		bad.append("digging did not dismiss the dig hint (dug %s, seen %s)" % [dug, Settings.hints_seen])
	st._tick_hints()
	var next: String = st.hint_id
	if next != "" and st.hint_box != null:
		st.hint_box.dismissed.emit()
		if not Settings.hints_seen.has(next):
			bad.append("click did not dismiss the %s hint" % next)
	Settings.loaded = false
	Settings.load_file()
	if not Settings.hints_seen.has("dig"):
		bad.append("seen hints not written to the settings file")
	Settings.hints_seen = []
	st._hide_hint()
	st.game.week = 7
	st._loaded_hints()
	st.game.week = 3
	st._tick_hints()
	if st.hint_id != "":
		bad.append("save loaded past week 6 still shows hint %s" % st.hint_id)
	st.hints_late = false
	st.shot_mode = true
	st._tick_hints()
	if st.hint_id != "":
		bad.append("shot mode shows hint %s" % st.hint_id)
	st.shot_mode = false
	Settings.hints_on = false
	st._tick_hints()
	if st.hint_id != "":
		bad.append("Hints off still shows %s" % st.hint_id)
	Settings.hints_on = true
	st.game.week = 9
	st._tick_hints()
	if st.hint_id != "":
		bad.append("week 9 shows hint %s outside every window" % st.hint_id)
	print("Hints: shown, hidden under a modal, dismissed by the action and by a click, kept in settings; seen %s" % [Settings.hints_seen])


func _find_meta(node: Node, key: String) -> Node:
	for child in node.find_children("*", "", true, false):
		if child.has_meta(key) and child.is_visible_in_tree():
			return child
	return null


func _shows(node: Node, text: String) -> bool:
	for child in node.find_children("*", "", true, false):
		if (child is Label or child is Button) and child.is_visible_in_tree() and str(child.text).contains(text):
			return true
	return false


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
