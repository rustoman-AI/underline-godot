class_name FeelCheck
extends Control

## Banner, then a beat, then a SUCCESS / FAILED stamp. Presentation only.
## Red checks and Unlikely checks (the station's existing band, chance under 40) get the full ~2.1 s.
## White likely and uncertain checks, and bets, get banner + stamp with no pause, ~0.6 s.

const Style = preload("res://ui/feel/feel_style.gd")

var host
var station
var open := false
var finished := false
var full_reveal := false
## Offer-time band: red, unlikely, uncertain, likely, bet, none, unknown.
var offer_band := ""
var punch := Style.CHECK_PUNCH
var phase := ""
var planned_sec := 0.0
var done_count := 0
var cues: PackedStringArray = []
var plate: PanelContainer
var banner: Label
var stamp_box: Control
var stamp_outer: Panel
var stamp_inner: Panel
var stamp: Label
var subline: Label
var hint: Label
var _done := Callable()
var _tw: Tween


func start(last: Dictionary, choice: Dictionary, on_done: Callable, offer_full: bool = false) -> bool:
	if host == null or station == null or not host.enabled():
		return false
	if open:
		return false
	open = true
	finished = false
	_done = on_done
	## The band was fixed before apply. Do not recompute it from the roll.
	full_reveal = offer_full
	var boxed := bool(last.get("box", false)) or bool(last.get("snake", false))
	punch = Style.CHECK_PUNCH_BOX if boxed else Style.CHECK_PUNCH
	planned_sec = _duration()
	host.stock.hold_all_keys()
	if station.toast_plate != null:
		station.toast_plate.visible = false
	_build_plate(last)
	visible = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	if host.reduced():
		_show_static()
		return true
	if full_reveal:
		_play_full()
	else:
		_play_short()
	return true


func handle_input(event: InputEvent) -> bool:
	if not open:
		return false
	if event is InputEventKey and event.echo:
		return true
	if event.is_action_pressed("ui_cancel"):
		_finish_now()
		return true
	var click := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click = true
	if click:
		_click()
		return true
	return true


func reset() -> void:
	finished = true
	open = false
	phase = ""
	_kill()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if plate != null and is_instance_valid(plate):
		plate.free()
		plate = null
	if host != null and host.stock != null:
		host.stock.release_all()
	_done = Callable()


## Read-only. Uses the choice's offer difficulty, skill, and color, and check_chance_projected
## (a copy of the resident, never stamped). check_preview / check_chance / best_check_resident
## call check_value, which writes checks onto a live resident, so they are not used here.
## Full: red, or white Unlikely (under 40). Short: white Uncertain, white Likely, and bets.
func offer_is_full(game, choice: Dictionary, person_id: String) -> bool:
	offer_band = _offer_band(game, choice, person_id)
	return offer_band == "red" or offer_band == "unlikely"


func _offer_band(game, choice: Dictionary, person_id: String) -> String:
	if choice.has("bet") and not choice.has("check"):
		return "bet"
	if not choice.has("check"):
		return "none"
	var check: Dictionary = choice.get("check", {})
	var color := str(check.get("color", "white"))
	if color == "red":
		return "red"
	var skill := str(check.get("skill", "wits"))
	var difficulty := int(check.get("difficulty", 10))
	var person := _offer_person(game, person_id, skill)
	if person.is_empty():
		return "unknown"
	var chance := int(game.check_chance_projected(person, skill, difficulty, color))
	return _band_name(chance)


func _band_name(chance: int) -> String:
	var word := str(station._check_band_word(chance))
	if word == _bare("Unlikely."):
		return "unlikely"
	if word == _bare("Uncertain."):
		return "uncertain"
	if word == _bare("Likely."):
		return "likely"
	return "unknown"


func _bare(source: String) -> String:
	var raw := Copy.t(source)
	if raw.ends_with("."):
		return raw.substr(0, raw.length() - 1)
	return raw


## Same ranking as best_check_resident, but check_value_projected never writes the resident.
func _offer_person(game, person_id: String, skill: String) -> Dictionary:
	if person_id != "" and game.people.has(person_id):
		return game.people[person_id]
	var best: Dictionary = {}
	var best_v := -1
	var best_named := false
	for person in game.residents:
		if game._is_child(person) or int(person.get("sick", 0)) > 0 or int(person.get("absent", 0)) > 0:
			continue
		var value := int(game.check_value_projected(person, skill))
		var named := bool(game._named_cast(person))
		if value > best_v or (value == best_v and named and not best_named):
			best_v = value
			best = person
			best_named = named
	return best


func _duration() -> float:
	if host.reduced():
		return Style.CHECK_REDUCED_SEC
	if not full_reveal:
		return Style.CHECK_SHORT_BANNER_SEC + Style.CHECK_SHORT_STAMP_SEC + Style.CHECK_SHORT_HOLD_SEC + Style.CHECK_SHORT_FADE_SEC
	return Style.CHECK_BANNER_SEC + Style.CHECK_BEAT_SEC + Style.CHECK_STAMP_SEC + Style.CHECK_HOLD_SEC + Style.CHECK_FADE_SEC


func _build_plate(last: Dictionary) -> void:
	if plate != null and is_instance_valid(plate):
		plate.free()
		plate = null
	plate = PanelContainer.new()
	plate.name = "FeelCheckPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := Style.RUST if str(last.get("color", "")) == "red" else Style.BRASS
	plate.add_theme_stylebox_override("panel", _plate_style(edge))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(box)
	banner = _line(_banner_text(last), 28, true)
	banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(banner)
	# A Container lays its children out and clears a stamp's rotation, so the
	# tilted label sits in a plain Control. Spec 5.3: display size 64, -4°.
	stamp_box = Control.new()
	stamp_box.name = "FeelStampBox"
	stamp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_box.visible = false
	var inner := _plate_style(edge)
	inner.set_border_width_all(2)
	inner.bg_color = Color(0, 0, 0, 0)
	inner.set_content_margin_all(0)
	var outer := _plate_style(edge)
	outer.set_border_width_all(4)
	outer.bg_color = Color(0.08, 0.06, 0.04, 0.2)
	outer.set_content_margin_all(0)
	stamp_outer = Panel.new()
	stamp_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_outer.add_theme_stylebox_override("panel", outer)
	stamp_inner = Panel.new()
	stamp_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_inner.add_theme_stylebox_override("panel", inner)
	stamp = _line(_stamp_text(last), Style.CHECK_STAMP_FONT, true)
	stamp.name = "FeelStamp"
	stamp.add_theme_color_override("font_color", Style.AMBER if bool(last.get("success", false)) else Style.RUST)
	if station.display_font != null:
		stamp.add_theme_font_override("font", station.display_font)
	stamp.autowrap_mode = TextServer.AUTOWRAP_OFF
	stamp_box.add_child(stamp_outer)
	stamp_box.add_child(stamp_inner)
	stamp_box.add_child(stamp)
	box.add_child(stamp_box)
	_tilt_stamp()
	subline = _line(station._check_result_line(), 18, false)
	subline.autowrap_mode = TextServer.AUTOWRAP_OFF
	subline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subline.visible = false
	subline.text = station._check_result_line()
	box.add_child(subline)
	hint = _line(Copy.t("feel.check.hint"), 14, false)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_theme_color_override("font_color", Style.INK)
	box.add_child(hint)
	add_child(plate)
	_place()


func _banner_text(last: Dictionary) -> String:
	if bool(last.get("bet", false)):
		return Copy.t("feel.check.bet")
	return Copy.fill("feel.check.banner", {
		"name": Copy.person(str(last.get("name", ""))),
		"skill": Copy.skill(str(last.get("skill", ""))),
	})


func _stamp_text(last: Dictionary) -> String:
	if bool(last.get("success", false)):
		return Copy.t("feel.check.success")
	return Copy.t("feel.check.failed")


func _line(text: String, size: int, display: bool) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", Style.INK)
	if display and station.display_font != null:
		lab.add_theme_font_override("font", station.display_font)
	elif station.body_font != null:
		lab.add_theme_font_override("font", station.body_font)
	return lab


func _plate_style(edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Style.PAPER
	style.border_color = edge
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(18)
	return style


func _place() -> void:
	if plate == null or not is_instance_valid(plate):
		return
	var view := get_viewport_rect().size
	if view.x < 2.0 and station != null:
		view = station.size
	var width := minf(560.0, maxf(280.0, view.x - 48.0))
	banner.custom_minimum_size = Vector2(width - 48.0, 36)
	banner.size = banner.custom_minimum_size
	subline.custom_minimum_size = Vector2(width - 48.0, 48)
	_tilt_stamp()
	hint.custom_minimum_size = Vector2(width - 48.0, 24)
	plate.custom_minimum_size = Vector2(width, 0)
	var h := plate.get_combined_minimum_size().y
	plate.position = Vector2((view.x - width) * 0.5, view.y * Style.CHECK_TOP)
	plate.size = Vector2(width, h)
	_clear_badges(view)


## The banner slides down 24px onto the resting position. Both ends stay off the badges.
func _clear_badges(view: Vector2) -> void:
	if station == null or plate == null:
		return
	var slide := 24.0
	for _round in 4:
		var badge := _blocking_badge(slide)
		if badge.size.x < 1.0:
			break
		var mine := _plate_global(slide)
		var gap := 10.0
		var below := badge.end.y + gap
		var above := badge.position.y - mine.size.y - gap - slide
		var right := badge.end.x + gap
		var left := badge.position.x - mine.size.x - gap
		var goal := mine.position
		if below + mine.size.y + slide <= view.y - 8.0 and absf(below - mine.position.y) < view.y:
			goal.y = below
		elif above >= 8.0:
			goal.y = above
		elif right + mine.size.x <= view.x - 8.0:
			goal.x = right
		elif left >= 8.0:
			goal.x = left
		else:
			break
		goal.x = clampf(goal.x, 8.0, maxf(8.0, view.x - mine.size.x - 8.0))
		goal.y = clampf(goal.y, 8.0, maxf(8.0, view.y - mine.size.y - slide - 8.0))
		_set_plate_global(goal)
	var fitted := _plate_global(0.0)
	var clamped := fitted.position
	clamped.x = clampf(clamped.x, 8.0, maxf(8.0, view.x - fitted.size.x - 8.0))
	clamped.y = clampf(clamped.y, 8.0, maxf(8.0, view.y - fitted.size.y - 8.0))
	_set_plate_global(clamped)


func _blocking_badge(slide: float) -> Rect2:
	var mine := _plate_global(slide)
	for node_name in ["sick_badge", "away_badge"]:
		var node: Control = station.get(node_name)
		if node == null or not node.visible:
			continue
		var badge := node.get_global_rect()
		if badge.size.x < 2.0 or badge.size.y < 2.0:
			continue
		if mine.intersects(badge):
			return badge
	return Rect2()


func _plate_global(slide: float) -> Rect2:
	var rect := plate.get_global_rect()
	rect.size.y += slide
	return rect


func _set_plate_global(top_left: Vector2) -> void:
	var xform: Transform2D = get_global_transform()
	plate.position = xform.affine_inverse() * top_left


func _show_static() -> void:
	phase = "hold"
	plate.modulate.a = 1.0
	_reveal_stamp(false)
	_kill()
	_tw = create_tween()
	_tw.tween_interval(Style.CHECK_REDUCED_SEC)
	_tw.tween_callback(_finish_now)


func _play_full() -> void:
	phase = "banner"
	_slide_in(Style.CHECK_BANNER_SEC)
	_tw.tween_callback(_mark_beat)
	_tw.tween_interval(Style.CHECK_BEAT_SEC)
	_tw.tween_callback(_mark_stamp)
	_tw.tween_interval(Style.CHECK_STAMP_SEC + Style.CHECK_HOLD_SEC)
	_tw.tween_callback(_mark_fade)
	_tw.tween_property(plate, "modulate:a", 0.0, Style.CHECK_FADE_SEC)
	_tw.tween_callback(_finish_now)


func _play_short() -> void:
	phase = "banner"
	_slide_in(Style.CHECK_SHORT_BANNER_SEC)
	_tw.tween_callback(_mark_stamp)
	_tw.tween_interval(Style.CHECK_SHORT_STAMP_SEC + Style.CHECK_SHORT_HOLD_SEC)
	_tw.tween_callback(_mark_fade)
	_tw.tween_property(plate, "modulate:a", 0.0, Style.CHECK_SHORT_FADE_SEC)
	_tw.tween_callback(_finish_now)


func _slide_in(seconds: float) -> void:
	_place()
	var rest: Vector2 = plate.position
	plate.position = rest + Vector2(0, 24)
	plate.modulate.a = 0.0
	_kill()
	_tw = create_tween()
	_tw.tween_property(plate, "position", rest, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(plate, "modulate:a", 1.0, seconds)


func _mark_beat() -> void:
	if not open or phase == "stamp" or phase == "fade":
		return
	phase = "beat"
	_cue("feel_heartbeat", "")


func _mark_stamp() -> void:
	if not open or finished or phase == "stamp" or phase == "fade":
		return
	phase = "stamp"
	_reveal_stamp(not host.reduced())


func _mark_fade() -> void:
	if not open or finished:
		return
	phase = "fade"


func _tilt_stamp() -> void:
	if stamp == null or stamp_box == null:
		return
	var font: Font = stamp.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var measured: Vector2 = font.get_string_size(stamp.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.CHECK_STAMP_FONT)
	var padded := Vector2(maxf(measured.x, 48.0) + 28.0, maxf(measured.y, 48.0) + 16.0)
	stamp.custom_minimum_size = padded
	stamp.size = padded
	stamp.pivot_offset = padded * 0.5
	stamp.rotation_degrees = -4.0
	stamp.scale = Vector2.ONE
	if stamp_outer != null:
		stamp_outer.size = padded
		stamp_outer.pivot_offset = padded * 0.5
		stamp_outer.rotation_degrees = -4.0
	if stamp_inner != null:
		var inset := padded - Vector2(12.0, 12.0)
		stamp_inner.size = inset
		stamp_inner.pivot_offset = inset * 0.5
		stamp_inner.rotation_degrees = -4.0
	var rad := deg_to_rad(4.0)
	var bounds := Vector2(
		absf(padded.x * cos(rad)) + absf(padded.y * sin(rad)) + 8.0,
		absf(padded.x * sin(rad)) + absf(padded.y * cos(rad)) + 8.0
	)
	stamp_box.custom_minimum_size = bounds
	var slot: Vector2 = stamp_box.size
	if slot.x < bounds.x:
		slot = bounds
	var at := (slot - padded) * 0.5
	stamp.position = at
	if stamp_outer != null:
		stamp_outer.position = at
	if stamp_inner != null:
		stamp_inner.position = at + Vector2(6.0, 6.0)


func _reveal_stamp(animated: bool) -> void:
	if stamp_box == null:
		return
	stamp_box.visible = true
	subline.visible = true
	subline.text = station._check_result_line()
	_tilt_stamp()
	var success := bool(station.game.last_check.get("success", false))
	_cue("feel_stamp_ok" if success else "feel_stamp_fail", "confirm" if success else "error")
	stamp.pivot_offset = stamp.size * 0.5
	stamp.rotation_degrees = -4.0
	if stamp_outer != null:
		stamp_outer.rotation_degrees = -4.0
	if stamp_inner != null:
		stamp_inner.rotation_degrees = -4.0
	if not animated:
		stamp.scale = Vector2.ONE
		_keep_tilt.call_deferred()
		return
	stamp.scale = Vector2(punch, punch)
	var pop := create_tween()
	pop.tween_property(stamp, "scale", Vector2.ONE, Style.CHECK_STAMP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_keep_tilt.call_deferred()


func _keep_tilt() -> void:
	if stamp != null and is_instance_valid(stamp):
		stamp.rotation_degrees = -4.0
	if stamp_outer != null and is_instance_valid(stamp_outer):
		stamp_outer.rotation_degrees = -4.0
	if stamp_inner != null and is_instance_valid(stamp_inner):
		stamp_inner.rotation_degrees = -4.0


func _click() -> void:
	if not open or finished or phase == "fade":
		return
	if phase == "banner" or phase == "beat":
		_kill()
		_mark_stamp()
		var fade := Style.CHECK_FADE_SEC if full_reveal else Style.CHECK_SHORT_FADE_SEC
		var hold := Style.CHECK_HOLD_SEC if full_reveal else Style.CHECK_SHORT_HOLD_SEC
		_tw = create_tween()
		_tw.tween_interval(hold)
		_tw.tween_callback(_mark_fade)
		_tw.tween_property(plate, "modulate:a", 0.0, fade)
		_tw.tween_callback(_finish_now)
		return
	_kill()
	var fade_now := Style.CHECK_FADE_SEC if full_reveal and not host.reduced() else Style.CHECK_SHORT_FADE_SEC
	_mark_fade()
	_tw = create_tween()
	_tw.tween_property(plate, "modulate:a", 0.0, fade_now)
	_tw.tween_callback(_finish_now)


func _finish_now() -> void:
	if finished:
		return
	finished = true
	open = false
	phase = ""
	_kill()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if host != null and host.stock != null:
		host.stock.release_all()
	done_count += 1
	var cb := _done
	_done = Callable()
	if cb.is_valid():
		cb.call()


func _cue(id: String, fallback: String) -> void:
	cues.append(id)
	if Sound.CUES.has(id):
		Sound.play(id)
	elif fallback != "":
		cues.append(fallback)
		Sound.play(fallback)


func _kill() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null
