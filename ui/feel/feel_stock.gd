extends RefCounted

## One owner for the stock roll, the icon pop and the floating chip.
## Hope and discontent pop and chip only. They are gauges, not numbers.

const Style = preload("res://ui/feel/feel_style.gd")

var host
var station
var target := {}
var acc := {}
var display := {}
var display_int := {}
var queued := false
var hold_all := false
var held := {}
var flown := {}
var land_pop := {}
var pool: Array = []
var live := {}
var roll_tween := {}
var rolls_started := 0
var pops_started := 0
var peak_chips := 0
var last_roll_from := {}
var last_chip := {}
var shown_chip := {}
var epoch := 0


func build_pool() -> void:
	if station == null or host == null or host.chips_root == null:
		return
	if not pool.is_empty():
		return
	for i in Style.CHIP_POOL:
		var lab := Label.new()
		lab.name = "FeelChip%d" % i
		lab.visible = false
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_font_size_override("font_size", Style.CHIP_FONT)
		lab.add_theme_constant_override("outline_size", Style.CHIP_OUTLINE)
		lab.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.9))
		lab.z_as_relative = false
		lab.z_index = Style.Z_CHIPS
		if station.number_font != null:
			lab.add_theme_font_override("font", station.number_font)
		host.chips_root.add_child(lab)
		pool.append(lab)


func reset() -> void:
	epoch += 1
	for key in roll_tween.keys():
		_kill(key)
	roll_tween.clear()
	for lab in pool:
		if is_instance_valid(lab):
			lab.visible = false
			lab.modulate.a = 0.0
	target.clear()
	acc.clear()
	display.clear()
	display_int.clear()
	held.clear()
	flown.clear()
	land_pop.clear()
	live.clear()
	last_chip.clear()
	shown_chip.clear()
	last_roll_from.clear()
	hold_all = false
	queued = false
	rolls_started = 0
	pops_started = 0
	if station != null:
		station.stock_shown = {}


func clear_counts() -> void:
	rolls_started = 0
	pops_started = 0
	last_roll_from.clear()


func sync(game, _roll: bool) -> void:
	if game == null or station == null or host == null:
		return
	build_pool()
	var changed := false
	for key in station.STOCK_KEYS:
		var id := str(key)
		var now := int(game.stock.get(id, 0))
		if not target.has(id):
			_seed(id, now)
			continue
		if now == int(target[id]):
			continue
		acc[id] = int(acc.get(id, 0)) + (now - int(target[id]))
		target[id] = now
		station.stock_shown[id] = now
		changed = true
	if _take_mood(game, "hope", int(game.hope)):
		changed = true
	if _take_mood(game, "discontent", int(game.discontent)):
		changed = true
	if not host.enabled() or host.reduced():
		_snap_pending()
		return
	if changed or _acc_pending():
		_queue()


func hold(key: String) -> void:
	held[key] = true


func hold_all_keys() -> void:
	hold_all = true


func release(key: String) -> void:
	held.erase(key)
	if not _held(key) and int(acc.get(key, 0)) != 0:
		_queue()


func release_all() -> void:
	hold_all = false
	held.clear()
	if _acc_pending():
		_queue()


func mark_flown(changes: Dictionary) -> void:
	if host == null or not host.enabled() or host.reduced():
		return
	for key in changes:
		flown[str(key)] = true


func pop_landed(key: String) -> void:
	if not bool(land_pop.get(key, false)):
		return
	land_pop.erase(key)
	if host == null or not host.enabled() or host.reduced():
		return
	_pop_only(key)


func chip_text(key: String) -> String:
	var lab: Label = last_chip.get(key, null)
	if lab == null or not is_instance_valid(lab) or not lab.visible:
		return ""
	return lab.text


func chip_gain(key: String) -> bool:
	var lab: Label = last_chip.get(key, null)
	if lab == null or not is_instance_valid(lab):
		return false
	return lab.get_theme_color("font_color") == Style.DELTA_UP


func visible_chips(key: String) -> int:
	var n := 0
	for id in live.keys():
		if str(id).begins_with(key + ":"):
			var lab: Label = live[id]
			if lab != null and is_instance_valid(lab) and lab.visible:
				n += 1
	return n


func live_tweens() -> int:
	var n := 0
	for key in roll_tween.keys():
		var tw: Tween = roll_tween[key]
		if tw != null and tw.is_valid():
			n += 1
	return n


func flush() -> void:
	queued = false
	if not host.enabled() or host.reduced():
		_snap_pending()
		return
	var keys: Array = acc.keys()
	for key in keys:
		var id := str(key)
		if _held(id):
			continue
		var delta := int(acc[id])
		acc.erase(id)
		_emit(id, delta)


func _seed(id: String, now: int) -> void:
	target[id] = now
	display[id] = float(now)
	display_int[id] = now
	if id in station.STOCK_KEYS:
		station.stock_shown[id] = now
		station._set_stock_text(float(now), id)


func _take_mood(game, id: String, now: int) -> bool:
	if not target.has(id):
		target[id] = now
		return false
	if now == int(target[id]):
		return false
	acc[id] = int(acc.get(id, 0)) + (now - int(target[id]))
	target[id] = now
	return true


func _queue() -> void:
	if queued or host == null:
		return
	queued = true
	host.call_deferred("_flush_stock_if", epoch)


func _acc_pending() -> bool:
	for key in acc.keys():
		if int(acc[key]) != 0 and not _held(str(key)):
			return true
	return false


func _held(id: String) -> bool:
	return hold_all or held.has(id)


func _snap_pending() -> void:
	var keys: Array = acc.keys()
	for key in keys:
		var id := str(key)
		acc.erase(id)
		_kill(id)
		if id in station.STOCK_KEYS:
			var now := int(target.get(id, 0))
			display[id] = float(now)
			display_int[id] = now
			station.stock_shown[id] = now
			station._set_stock_text(float(now), id)
			_restore_modulate(_value_label(id))
			_restore_scale(_icon(id))
	flown.clear()
	land_pop.clear()
	for id in live.keys():
		var lab: Label = live[id]
		if lab != null and is_instance_valid(lab):
			lab.visible = false
	live.clear()
	last_chip.clear()


func _emit(id: String, delta: int) -> void:
	if delta == 0:
		_kill(id)
		if id in station.STOCK_KEYS:
			var back := float(int(target.get(id, 0)))
			display[id] = back
			display_int[id] = int(back)
			station._set_stock_text(back, id)
		return
	var skip_chip := bool(flown.get(id, false))
	flown.erase(id)
	var from := float(display.get(id, float(int(target.get(id, 0)) - delta)))
	var to := float(int(target.get(id, 0)))
	if id in station.STOCK_KEYS:
		last_roll_from[id] = from
		rolls_started += 1
		if absi(delta) >= 2:
			Sound.play("feel_tick")
		_kill(id)
		var tw: Tween = host.create_tween()
		tw.set_parallel(true)
		roll_tween[id] = tw
		tw.tween_method(_on_roll.bind(id), from, to, Style.ROLL_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_arm_flash(tw, id, delta)
		if skip_chip:
			land_pop[id] = true
		else:
			_arm_pop(tw, id)
			_arm_chip(tw, id, delta)
	else:
		_kill(id)
		var mood: Tween = host.create_tween()
		mood.set_parallel(true)
		roll_tween[id] = mood
		_arm_flash(mood, id, delta)
		if skip_chip:
			land_pop[id] = true
		else:
			_arm_pop(mood, id)
			_arm_chip(mood, id, delta)


func _on_roll(value: float, id: String) -> void:
	display[id] = value
	var shown := int(round(value))
	if int(display_int.get(id, -99999)) == shown:
		return
	display_int[id] = shown
	if station != null:
		station._set_stock_text(value, id)


func _arm_pop(tw: Tween, id: String) -> void:
	var icon := _icon(id)
	if icon == null:
		return
	_pivot(icon)
	icon.scale = Vector2.ONE
	pops_started += 1
	tw.tween_method(_on_pop.bind(icon), 0.0, 1.0, Style.POP_SEC)


func _pop_only(id: String) -> void:
	var icon := _icon(id)
	if icon == null or host == null:
		return
	_kill(id)
	var tw: Tween = host.create_tween()
	roll_tween[id] = tw
	_pivot(icon)
	icon.scale = Vector2.ONE
	pops_started += 1
	tw.tween_method(_on_pop.bind(icon), 0.0, 1.0, Style.POP_SEC)


func _on_pop(t: float, icon: Control) -> void:
	if not is_instance_valid(icon):
		return
	var s := Style.POP_SCALE
	if t < 0.5:
		s = lerpf(1.0, Style.POP_SCALE, t / 0.5)
	else:
		var u := (t - 0.5) / 0.5
		s = float(Tween.interpolate_value(Style.POP_SCALE, 1.0 - Style.POP_SCALE, u, 1.0, Tween.TRANS_BACK, Tween.EASE_OUT))
	icon.scale = Vector2(s, s)


func _arm_flash(tw: Tween, id: String, delta: int) -> void:
	var lab := _value_label(id)
	if lab == null:
		return
	lab.modulate = _ink(id, delta)
	tw.tween_property(lab, "modulate", Color.WHITE, Style.FLASH_SEC)


func _arm_chip(tw: Tween, id: String, delta: int) -> void:
	var sign := 1 if delta > 0 else -1
	var slot := "%s:%d" % [id, sign]
	var age := 0.0
	var existing: Label = live.get(slot, null)
	if existing != null and is_instance_valid(existing) and existing.visible:
		age = float(existing.get_meta("age", 1.0))
		if age < Style.CHIP_MERGE_SEC and int(existing.get_meta("sign", 0)) == sign:
			var merged := int(existing.get_meta("amount", 0)) + delta
			existing.set_meta("amount", merged)
			existing.text = "%+d" % merged
			existing.set_meta("age", 0.0)
			existing.modulate.a = 1.0
		var origin: Vector2 = existing.get_meta("origin", existing.position)
		origin = _place_chip(id, existing, origin, false)
		existing.position = origin
		last_chip[id] = existing
		shown_chip[id] = existing.text
		_rise(tw, existing, origin)
		return
	var lab := _claim()
	if lab == null:
		return
	lab.text = "%+d" % delta
	lab.add_theme_color_override("font_color", _ink(id, delta))
	lab.modulate = Color.WHITE
	lab.modulate.a = 1.0
	lab.visible = true
	lab.set_meta("amount", delta)
	lab.set_meta("sign", sign)
	lab.set_meta("age", 0.0)
	lab.set_meta("key", id)
	var origin := _place_chip(id, lab, _chip_origin(id), true)
	lab.position = origin
	live[slot] = lab
	last_chip[id] = lab
	shown_chip[id] = lab.text
	var shown := visible_chip_count()
	if shown > peak_chips:
		peak_chips = shown
	_rise(tw, lab, origin)


func _rise(tw: Tween, lab: Label, origin: Vector2) -> void:
	lab.set_meta("origin", origin)
	tw.tween_method(_on_chip.bind(lab), 0.0, 1.0, Style.CHIP_SEC)


func _on_chip(t: float, lab: Label) -> void:
	if not is_instance_valid(lab):
		return
	var origin: Vector2 = lab.get_meta("origin", lab.position)
	lab.position = origin + Vector2(0.0, -Style.CHIP_RISE * t)
	lab.set_meta("age", t * Style.CHIP_SEC)
	var fade_at := 1.0 - Style.CHIP_FADE / Style.CHIP_SEC
	var a := 1.0
	if t > fade_at:
		a = clampf(1.0 - (t - fade_at) / (1.0 - fade_at), 0.0, 1.0)
	lab.modulate.a = a
	if t >= 1.0:
		lab.visible = false
		var id := str(lab.get_meta("key", ""))
		var sign := int(lab.get_meta("sign", 0))
		var slot := "%s:%d" % [id, sign]
		if live.get(slot, null) == lab:
			live.erase(slot)


func _claim() -> Label:
	for lab in pool:
		if lab != null and is_instance_valid(lab) and not lab.visible:
			return lab
	var oldest: Label = null
	var oldest_age := -1.0
	for lab in pool:
		if lab == null or not is_instance_valid(lab):
			continue
		var age := float(lab.get_meta("age", 0.0))
		if age > oldest_age:
			oldest_age = age
			oldest = lab
	return oldest


func visible_chip_count() -> int:
	var n := 0
	for lab in pool:
		if lab != null and is_instance_valid(lab) and lab.visible:
			n += 1
	return n


func _chip_origin(id: String) -> Vector2:
	var node := _value_label(id)
	if node == null or host == null or host.chips_root == null:
		return Vector2.ZERO
	var rect := node.get_global_rect()
	var top_right := Vector2(rect.end.x, rect.position.y)
	return host.chips_root.get_global_transform().affine_inverse() * top_right


## Keeps the 18px rise inside the viewport and clear of the delta forecast under the number.
func _place_chip(id: String, lab: Label, origin: Vector2, jitter: bool) -> Vector2:
	if host == null or host.chips_root == null:
		return origin
	if jitter and host.jitter != null:
		origin.x += host.jitter.randf_range(-Style.CHIP_JITTER, Style.CHIP_JITTER)
	var box := _chip_box(lab)
	lab.custom_minimum_size = box
	lab.size = box
	var root: Control = host.chips_root
	var xform: Transform2D = root.get_global_transform()
	var global: Vector2 = xform * origin
	var view: Vector2 = root.get_viewport_rect().size
	var floor_y := Style.CHIP_FLOOR_Y
	if global.y - Style.CHIP_RISE < floor_y:
		global.y += floor_y - (global.y - Style.CHIP_RISE)
	global.x = _clamp_x(global.x, box.x, view.x, floor_y)
	if view.y > box.y + floor_y and global.y + box.y > view.y - floor_y:
		global.y = view.y - floor_y - box.y
	if global.y - Style.CHIP_RISE < floor_y:
		global.y = floor_y + Style.CHIP_RISE
	global = _clear_forecast(id, global, box, view)
	global.x = _clamp_x(global.x, box.x, view.x, floor_y)
	var local: Vector2 = xform.affine_inverse() * global
	var end_global: Vector2 = xform * (local + Vector2(0.0, -Style.CHIP_RISE))
	var path_pos := Vector2(minf(global.x, end_global.x), minf(global.y, end_global.y))
	var path_size := Vector2(box.x + absf(global.x - end_global.x), box.y + absf(global.y - end_global.y))
	lab.set_meta("path_min_y", path_pos.y)
	lab.set_meta("path_x", path_pos.x)
	lab.set_meta("path_y", path_pos.y)
	lab.set_meta("path_w", path_size.x)
	lab.set_meta("path_h", path_size.y)
	return local


func _clamp_x(x: float, width: float, view_w: float, floor_y: float) -> float:
	if x < floor_y:
		x = floor_y
	if view_w > width + floor_y * 2.0 and x + width > view_w - floor_y:
		x = view_w - floor_y - width
	return x


func _clear_forecast(id: String, global: Vector2, box: Vector2, view: Vector2) -> Vector2:
	var delta := _delta_label(id)
	if delta == null or not delta.visible or str(delta.text) == "":
		return global
	var blocked: Rect2 = delta.get_global_rect()
	if blocked.size.x < 1.0 or blocked.size.y < 1.0:
		return global
	var path := Rect2(Vector2(global.x, global.y - Style.CHIP_RISE), Vector2(box.x, box.y + Style.CHIP_RISE))
	if not path.intersects(blocked):
		return global
	var floor_y := Style.CHIP_FLOOR_Y
	var right := blocked.end.x + floor_y
	var left := blocked.position.x - box.x - floor_y
	if view.x > right + box.x + floor_y:
		global.x = right
	elif left >= floor_y:
		global.x = left
	return global


func _chip_box(lab: Label) -> Vector2:
	var font: Font = lab.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var measured: Vector2 = font.get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.CHIP_FONT)
	var pad := float(Style.CHIP_OUTLINE)
	return Vector2(maxf(measured.x, 8.0) + pad * 2.0, maxf(measured.y, float(Style.CHIP_FONT)) + pad)


func _delta_label(id: String) -> Control:
	if station == null or not station.chips.has(id):
		return null
	var row: Dictionary = station.chips[id]
	var node: Variant = row.get("delta", null)
	if node is Control:
		return node
	return null


func _value_label(id: String) -> Control:
	if station == null:
		return null
	if station.chips.has(id):
		return station.chips[id].value
	if id == "hope":
		return station.hope_label
	if id == "discontent":
		return station.dis_label
	return null


func _icon(id: String) -> Control:
	if station == null:
		return null
	if station.chips.has(id):
		return station.chips[id].icon
	return _value_label(id)


func _ink(id: String, delta: int) -> Color:
	var up := delta > 0
	if id == "discontent":
		up = delta < 0
	return Style.DELTA_UP if up else Style.DELTA_DOWN


func _pivot(node: Control) -> void:
	var sz := node.size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = node.custom_minimum_size
	if sz.x < 1.0 or sz.y < 1.0:
		sz = Vector2(24, 24)
	node.pivot_offset = sz * 0.5


func _kill(id: String) -> void:
	var tw: Tween = roll_tween.get(id, null)
	if tw != null and tw.is_valid():
		tw.kill()
	roll_tween.erase(id)


func _restore_modulate(node: Control) -> void:
	if node != null and is_instance_valid(node):
		node.modulate = Color.WHITE


func _restore_scale(node: Control) -> void:
	if node != null and is_instance_valid(node):
		node.scale = Vector2.ONE
