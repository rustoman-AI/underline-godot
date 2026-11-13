class_name Living
extends RefCounted

## Clocks, enablement, pause and reset. Drawing asks LivingLight.
## Presentation only: reads the station caches, never the sim RNGs.

static var test_force := ""

var station = null
var light := LivingLight.new()
var walk := LivingWalk.new()
var living_t := 0.0
var last_draw_msec := 0
var frames_drawn := 0
var lanterns_drawn := 0
var perf_sum := 0
var perf_frames := 0
var perf_worst := 0
var _frame_cost := 0


func attach(st) -> void:
	station = st
	if st != null and st.yard != null:
		st.yard.living = self


func reset() -> void:
	living_t = 0.0
	last_draw_msec = 0
	frames_drawn = 0
	lanterns_drawn = 0
	perf_sum = 0
	perf_frames = 0
	perf_worst = 0
	_frame_cost = 0
	light.reset()
	walk.reset()


func enabled() -> bool:
	if test_force == "off":
		return false
	if test_force == "on":
		return true
	var args := OS.get_cmdline_user_args()
	if args.has("--no-living"):
		return false
	if DisplayServer.get_name() == "headless" and not args.has("--living-test"):
		return false
	if station != null and station.shot_mode and not station.motion_in_shots:
		return false
	return true


func reduced() -> bool:
	if station == null:
		return false
	return station._motion_off()


func paused() -> bool:
	if station == null:
		return false
	if station.deck != null and station.deck.top_priority() > 0:
		return true
	if station.dim != null and station.dim.visible:
		return true
	if bool(station.showing_network) or bool(station.at_menu):
		return true
	return station._yard_notices_covered()


func advance_clock(dt: float) -> void:
	if enabled() and not paused() and not reduced():
		living_t += dt


func tick(dt: float) -> void:
	if not enabled():
		return
	light.tick(dt, paused(), reduced(), living_t)


func step_for_test(dt: float) -> void:
	advance_clock(dt)
	tick(dt)


func observe(loss: Dictionary, week: int) -> void:
	if not enabled() or station == null or station.game == null:
		return
	var game = station.game
	light.observe(loss, int(week), game.rooms, game.cells, living_t, reduced())
	var ward := ""
	var view: Dictionary = game.sick_cots_view()
	if bool(view.get("show", false)) and str(view.get("place", "")) == "infirmary":
		var uid := str(view.get("room", ""))
		var offline := false
		for room in game.rooms:
			if str(room.get("uid", "")) != uid:
				continue
			offline = bool(room.get("offline", false))
			break
		var cut := loss.has(uid) and bool(loss[uid])
		if uid != "" and not offline and not cut:
			ward = uid
	light.set_ward(ward, reduced())


func night_begin() -> void:
	if not enabled() or reduced():
		return
	light.night_begin(living_t)


func night_end() -> void:
	if not enabled():
		return
	light.night_end(living_t)


func begin_frame(_life_t: float) -> void:
	var mark := Time.get_ticks_usec()
	var now := Time.get_ticks_msec()
	if last_draw_msec > 0 and now - last_draw_msec > LivingStyle.RESYNC_MS:
		light.snap_events()
	last_draw_msec = now
	frames_drawn += 1
	lanterns_drawn = 0
	_frame_cost = Time.get_ticks_usec() - mark


func end_frame() -> void:
	var mark := Time.get_ticks_usec()
	_frame_cost += Time.get_ticks_usec() - mark
	perf_sum += _frame_cost
	perf_frames += 1
	if _frame_cost > perf_worst:
		perf_worst = _frame_cost
	_frame_cost = 0


func perf_avg_ms() -> float:
	if perf_frames <= 0:
		return 0.0
	return float(perf_sum) / float(perf_frames) / 1000.0


func perf_worst_ms() -> float:
	return float(perf_worst) / 1000.0


func draw_walkers(yard) -> void:
	var mark := Time.get_ticks_usec()
	walk.draw(yard)
	_frame_cost += Time.get_ticks_usec() - mark


func draw_grade(yard, _geo: Dictionary) -> void:
	if not enabled():
		return
	var mark := Time.get_ticks_usec()
	var col := light.grade_color()
	if col.a > 0.001:
		yard.draw_rect(yard._station_rect(), col)
	_frame_cost += Time.get_ticks_usec() - mark


func frontier_alpha(level: int, cell: int, kind: String) -> float:
	var mark := Time.get_ticks_usec()
	var shade := light.frontier_alpha(level, cell)
	if shade < 0.0:
		shade = 0.5 if kind == "hidden" else 0.3
	_frame_cost += Time.get_ticks_usec() - mark
	return shade


func paint_lantern(yard, rect: Rect2, level: int, cell: int) -> void:
	if not enabled():
		return
	var edges: Array = light.lantern_edges(level, cell)
	if edges.is_empty():
		return
	var mark := Time.get_ticks_usec()
	var pool_a := LivingStyle.LANTERN_POOL.a
	if not reduced():
		pool_a += LivingStyle.LANTERN_BREATH * sin(TAU * LivingStyle.LANTERN_HZ * living_t)
	pool_a = clampf(pool_a, 0.0, 1.0)
	var tex: Texture2D = yard._lamp_texture()
	var radius: float = rect.size.y * LivingStyle.LANTERN_POOL_R
	var col := LivingStyle.LANTERN_POOL
	col.a = pool_a
	for edge in edges:
		var at := _lantern_at(rect, str(edge))
		if tex != null:
			yard.draw_texture_rect(tex, Rect2(at.x - radius, at.y - radius, radius * 2.0, radius * 2.0), false, col)
		yard.draw_circle(at, LivingStyle.LANTERN_DOT, LivingStyle.LANTERN)
		lanterns_drawn += 1
	_frame_cost += Time.get_ticks_usec() - mark


func paint_room(yard, rect: Rect2, uid: String, room_type: String) -> void:
	if not enabled():
		return
	var mark := Time.get_ticks_usec()
	var t := living_t
	var shade := light.cut_alpha(uid, t)
	if shade > 0.001:
		yard.draw_rect(rect, Color(0, 0, 0, shade))
	if light.cut_visible(uid, t):
		yard._draw_power_icon(rect)
	var strain := light.strain_alpha(uid, t)
	if strain > 0.001:
		yard.draw_rect(rect, Color(0, 0, 0, strain))
	if room_type == "infirmary":
		var wash := light.ward_color(uid, t)
		if wash.a > 0.001:
			yard.draw_rect(rect, wash)
	_frame_cost += Time.get_ticks_usec() - mark


func _lantern_at(rect: Rect2, edge: String) -> Vector2:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	if edge == "l":
		return Vector2(x + w * LivingStyle.LANTERN_INSET, y + h * LivingStyle.LANTERN_DOWN)
	if edge == "r":
		return Vector2(rect.end.x - w * LivingStyle.LANTERN_INSET, y + h * LivingStyle.LANTERN_DOWN)
	if edge == "u":
		return Vector2(x + w * 0.5, y + h * LivingStyle.LANTERN_INSET)
	return Vector2(x + w * 0.5, rect.end.y - h * LivingStyle.LANTERN_INSET)
