class_name FeelFX
extends Node

## Presentation owner. No sim writes. Idle process stays off.

const Style = preload("res://ui/feel/feel_style.gd")
const StockScript = preload("res://ui/feel/feel_stock.gd")

var station
var layer: Control
var chips_root: Control
var stock
var jitter := RandomNumberGenerator.new()
var perf_n := 0
var perf_total_us := 0
var perf_max_us := 0


func _ready() -> void:
	jitter.seed = maxi(int(Time.get_ticks_usec() % 2147483647), 1)
	set_process(false)
	_build_layer()
	stock = StockScript.new()
	stock.host = self
	stock.station = station
	stock.build_pool()


func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.has("--no-feel"):
		return false
	if DisplayServer.get_name() == "headless" and not args.has("--feel-test"):
		return false
	if station != null and bool(station.shot_mode) and not bool(station.motion_in_shots):
		return false
	return true


## Settings.reduced() or the station motion freeze. Never reads reduce_motion itself.
func reduced() -> bool:
	if station != null and station._motion_off():
		return true
	return Settings.reduced()


func busy() -> bool:
	return false


func handle_input(_event: InputEvent) -> bool:
	return false


func reset() -> void:
	if stock != null:
		stock.reset()
	perf_n = 0
	perf_total_us = 0
	perf_max_us = 0
	set_process(false)


func skip_all() -> void:
	reset()


func note_flush(us: int) -> void:
	perf_n += 1
	perf_total_us += us
	if us > perf_max_us:
		perf_max_us = us


func perf_avg_us() -> int:
	if perf_n <= 0:
		return 0
	return int(perf_total_us / perf_n)


func _build_layer() -> void:
	layer = Control.new()
	layer.name = "FeelLayer"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_as_relative = false
	layer.z_index = Style.Z_LAYER
	add_child(layer)
	chips_root = Control.new()
	chips_root.name = "FeelChips"
	chips_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	chips_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips_root.z_as_relative = false
	chips_root.z_index = Style.Z_CHIPS
	layer.add_child(chips_root)


func _flush_stock() -> void:
	_flush_stock_if(-1)


func _flush_stock_if(stamp: int) -> void:
	if stock == null:
		return
	if stamp >= 0 and int(stock.epoch) != stamp:
		return
	var t0 := Time.get_ticks_usec()
	stock.flush()
	note_flush(int(Time.get_ticks_usec() - t0))
