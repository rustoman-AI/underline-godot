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
var punch := Style.CHECK_PUNCH
var phase := ""
var planned_sec := 0.0
var done_count := 0
var cues: PackedStringArray = []
var plate: PanelContainer
var banner: Label
var stamp_box: PanelContainer
var stamp: Label
var subline: Label
var hint: Label
var _done := Callable()
var _tw: Tween


func start(last: Dictionary, choice: Dictionary, on_done: Callable) -> bool:
	if host == null or station == null or not host.enabled():
		return false
	if open:
		return false
	open = true
	finished = false
	_done = on_done
	full_reveal = _wants_full(last, choice)
	var boxed := bool(last.get("box", false)) or bool(last.get("snake", false))
	punch = Style.CHECK_PUNCH_BOX if boxed else Style.CHECK_PUNCH
	planned_sec = _duration()
	host.stock.hold_all_keys()
	if station.toast_plate != null:
		station.toast_plate.visible = false
	_build_plate(last)
	visible = true
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


func _wants_full(last: Dictionary, choice: Dictionary) -> bool:
	if str(last.get("color", "")) == "red":
		return true
	if bool(last.get("bet", false)) or not choice.has("check"):
		return false
	var check: Dictionary = choice.get("check", {})
	var chance := int(station.game._check_chance_bonus(int(last.get("bonus", 0)), int(check.get("difficulty", 10)), str(last.get("color", "white"))))
	return _band_unlikely(chance)


## Same cut as Station._check_band_word: under 40 is Unlikely. No new odds math.
func _band_unlikely(chance: int) -> bool:
	var word := str(station._check_band_word(chance))
	var raw := Copy.t("Unlikely.")
	if raw.ends_with("."):
		raw = raw.substr(0, raw.length() - 1)
	return word == raw


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
	stamp_box = PanelContainer.new()
	stamp_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_box.visible = false
	var inner := _plate_style(edge)
	inner.set_border_width_all(2)
	inner.bg_color = Color(0, 0, 0, 0)
	var outer := _plate_style(edge)
	outer.set_border_width_all(4)
	outer.bg_color = Color(0.08, 0.06, 0.04, 0.2)
	outer.set_content_margin_all(6)
	stamp_box.add_theme_stylebox_override("panel", outer)
	var inner_box := PanelContainer.new()
	inner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_box.add_theme_stylebox_override("panel", inner)
	stamp = _line(_stamp_text(last), Style.CHECK_STAMP_FONT, true)
	stamp.add_theme_color_override("font_color", Style.AMBER if bool(last.get("success", false)) else Style.RUST)
	if station.display_font != null:
		stamp.add_theme_font_override("font", station.display_font)
	stamp.autowrap_mode = TextServer.AUTOWRAP_OFF
	stamp.rotation_degrees = -4.0
	inner_box.add_child(stamp)
	stamp_box.add_child(inner_box)
	box.add_child(stamp_box)
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
	stamp.custom_minimum_size = Vector2(width - 80.0, 72)
	stamp.size = stamp.custom_minimum_size
	hint.custom_minimum_size = Vector2(width - 48.0, 24)
	plate.custom_minimum_size = Vector2(width, 0)
	var h := plate.get_combined_minimum_size().y
	plate.position = Vector2((view.x - width) * 0.5, view.y * Style.CHECK_TOP)
	plate.size = Vector2(width, h)


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


func _reveal_stamp(animated: bool) -> void:
	if stamp_box == null:
		return
	stamp_box.visible = true
	subline.visible = true
	subline.text = station._check_result_line()
	var success := bool(station.game.last_check.get("success", false))
	_cue("feel_stamp_ok" if success else "feel_stamp_fail", "confirm" if success else "error")
	stamp.pivot_offset = stamp.size * 0.5 if stamp.size.x > 1.0 else stamp.custom_minimum_size * 0.5
	if not animated:
		stamp.scale = Vector2.ONE
		return
	stamp.scale = Vector2(punch, punch)
	var pop := create_tween()
	pop.tween_property(stamp, "scale", Vector2.ONE, Style.CHECK_STAMP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
