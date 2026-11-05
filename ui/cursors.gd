class_name Cursors
extends RefCounted

## R23 brass cursors. Hardware cursors stay at image pixels, so the 32px pair is the
## 1:1 cursor and the 64px pair is used from 125% up (the title lockup's @2x cutoff).
## Hotspots are the arrow tip and the fingertip from Art's sheet.

const ARROW: Texture2D = preload("res://assets/ui/cursor_arrow.png")
const ARROW_2X: Texture2D = preload("res://assets/ui/cursor_arrow@2x.png")
const HAND: Texture2D = preload("res://assets/ui/cursor_hand.png")
const HAND_2X: Texture2D = preload("res://assets/ui/cursor_hand@2x.png")
const ARROW_HOT := Vector2(2, 2)
const ARROW_HOT_2X := Vector2(4, 4)
const HAND_HOT := Vector2(10, 2)
const HAND_HOT_2X := Vector2(20, 4)
const HI_DPI := 1.25


static func apply(win: Window = null) -> Dictionary:
	return apply_at(display_scale(win))


static func apply_at(scale: float) -> Dictionary:
	var chosen := shapes_for(scale)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		var row: Dictionary = chosen[shape]
		var tex: Texture2D = row["texture"]
		var hot: Vector2 = row["hotspot"]
		if tex == null or tex.get_width() < 1:
			push_warning("Missing brass cursor for shape %s" % shape)
			continue
		if hot.x < 0.0 or hot.y < 0.0 or hot.x >= tex.get_width() or hot.y >= tex.get_height():
			push_warning("Cursor hotspot %s is outside %s" % [hot, row["path"]])
			continue
		Input.set_custom_mouse_cursor(tex, shape, hot)
		row["applied"] = true
	return chosen


static func shapes_for(scale: float) -> Dictionary:
	var hi := scale >= HI_DPI - 0.001
	var arrow: Texture2D = ARROW_2X if hi else ARROW
	var hand: Texture2D = HAND_2X if hi else HAND
	return {
		Input.CURSOR_ARROW: {
			"texture": arrow,
			"hotspot": ARROW_HOT_2X if hi else ARROW_HOT,
			"path": str(arrow.resource_path),
		},
		Input.CURSOR_POINTING_HAND: {
			"texture": hand,
			"hotspot": HAND_HOT_2X if hi else HAND_HOT,
			"path": str(hand.resource_path),
		},
	}


static func display_scale(win: Window) -> float:
	var ui := 1.0
	if win != null and is_instance_valid(win):
		ui = float(win.content_scale_factor)
	return maxf(ui, screen_scale())


static func screen_scale() -> float:
	if OS.has_feature("headless") or DisplayServer.get_name() == "headless":
		return 1.0
	var screen := DisplayServer.window_get_current_screen()
	var scale := float(DisplayServer.screen_get_scale(screen))
	if scale <= 0.01:
		return 1.0
	return scale
