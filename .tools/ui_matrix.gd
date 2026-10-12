extends SceneTree

## UI matrix: one language and one window size per run (windowed, not headless):
##   godot --path . -s res://.tools/ui_matrix.gd -- --lang=ru --size=1366x768
## Shots go to shots/qa/<lang>_<WxH>/, findings to build/ui_matrix/<lang>_<WxH>.json.
## The window gets the default Auto interface scale; rects are in UI units, contrast is sampled in shot pixels.
## On every screen each visible control is checked: outside the window, squeezed below its minimum size, text cut
## (trimmed or lines hidden), poking out of its container, and text contrast measured on the shot's pixels.
## All visible text is also checked for language: Latin words in Russian, Cyrillic in English, raw ids, dashes.
## Custom-drawn text (the yard, the map canvas) is not a Control and is not covered.
## Settings, saves and logs go to user://ui_matrix, not the player's.

const SCRATCH := "user://ui_matrix"
const LATIN_OK := ["OK", "VO", "UI", "Esc", "Enter", "Ctrl", "Alt", "Shift", "Tab", "F11", "Underline", "itch", "io", "Windows", "Discord", "playtest", "MTA", "dev"]

var st
var size := Vector2i(1280, 720)
var out := ""
var findings: Array = []
var texts := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			Copy.set_lang(str(arg).trim_prefix("--lang="))
	Settings.path = SCRATCH.path_join("settings.cfg")
	Settings.loaded = true
	Settings.log_consent = "no"
	Settings.howto_hidden = true
	SaveGame.root = SCRATCH + "/saves/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveGame.root))
	PlaytestLog.dir = SCRATCH.path_join("log")
	st = load("res://ui/station.tscn").instantiate()
	st.shot_mode = true
	root.add_child(st)
	await process_frame
	await process_frame
	size = st._shot_size()
	await st._settle(size)
	Settings.apply_scale(st.get_window())
	for _i in 4:
		await process_frame
	st._layout()
	out = "qa/%s_%dx%d" % [Copy.lang, size.x, size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/" + out))
	var t0 := Time.get_ticks_msec()

	st._show_main_menu()
	await _shot("menu_main")
	st._open_settings(false)
	await _shot("settings")
	st._show_main_menu()
	st._show_howto(false)
	await _shot("howto")
	st._close_howto()
	st._begin_new_game(true)
	if st.hub_layer != null and st.hub_layer.visible:
		await _shot("new_game")
		st.hub_layer.visible = false
	else:
		findings.append({"screen": "new_game", "kind": "note", "detail": "hub art missing, new game opens on the dawn report"})
		st._show_dawn()
		await _shot("new_game")
	st._close_card()
	st.guide_played = true
	st.guide_step = -1
	if st.guide_layer != null:
		st.guide_layer.visible = false
	st.game.pending.clear()
	st._refresh()
	await _shot("station_w1")

	st.drawer_open = true
	st._place_drawer()
	st._fill_people()
	await _shot("people")
	st.drawer_open = false
	st._place_drawer()

	var three := ""
	for ev in st.game.catalog.events:
		if ev.get("choices", []).size() == 3 and not ev.has("needs") and not ev.has("trigger") and not bool(ev.get("check_only", false)) and not bool(ev.get("chain_only", false)):
			three = str(ev.id)
			break
	st._offer_shot(three)
	await _shot("event_3_choices")
	st._close_card()
	st.game.pending.clear()

	st.game.audience = {"faction": "depot", "week": st.game.week, "target": ""}
	st._show_audience()
	await _shot("audience")
	st._close_card()
	st.game.audience = {}

	st._toggle_network()
	await st._frame()
	st.network_view._fit()
	st._place_chrome()
	await _shot("network")
	var sid: String = st.network_view.first_known_neighbor()
	st.network_view.open_sheet(sid if sid != "" else st.game.capital_id)
	await _shot("station_sheet")
	st.network_view.close_sheet()
	st._toggle_network()

	var bot := Bot.new()
	bot.profile = "careful"
	bot.audience_style = "helper"
	while st.game.week < 25 and st.game.over == "":
		bot._act(st.game)
		st.game.end_week()
	st.game.pending.clear()
	st.game.audience = {}
	# The bot gives council orders the player has no button for; their journal rows are not something a player sees.
	st.game.journal = st.game.journal.filter(func(row): return not (str(row.get("kind", "")) in ["order", "cancel"] and str(row.get("order", "")) in ["pay", "gift", "address", "aid"]))
	st.hold_dawn = true
	st._close_card()
	st._refresh()
	await _shot("station_w25")

	st._show_journal()
	await _shot("journal")
	st._pick_journal_filter("truth")
	await _shot("truth")
	st.journal_filter = ""
	st._close_card()

	st.game.proof_extra = 3
	st._offer_shot("st3_decision")
	await _shot("final_decision")
	st._close_card()
	st.game.pending.clear()
	st._epilogue("open_door")
	await _shot("epilogue")
	st._close_card()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/ui_matrix"))
	var f := FileAccess.open("res://build/ui_matrix/%s_%dx%d.json" % [Copy.lang, size.x, size.y], FileAccess.WRITE)
	f.store_string(JSON.stringify({"lang": Copy.lang, "size": "%dx%d" % [size.x, size.y], "window": str(st.get_window().size),
		"scale": st.get_window().content_scale_factor, "ui": str(st.get_viewport().get_visible_rect().size.round()),
		"ms": Time.get_ticks_msec() - t0, "findings": findings, "texts": texts.keys()}, "\t"))
	f.close()
	print("MATRIX %s %dx%d findings %d" % [Copy.lang, size.x, size.y, findings.size()])
	_wipe(ProjectSettings.globalize_path(SCRATCH))
	quit(0)


func _shot(screen: String) -> void:
	for i in 4:
		await st._frame()
	await create_timer(0.6).timeout
	await st._frame()
	st._save(out + "/" + screen)
	var img: Image = st.get_viewport().get_texture().get_image()
	_audit(screen, img)


func _audit(screen: String, img: Image) -> void:
	var window: Rect2 = st.get_viewport().get_visible_rect()
	var px: float = float(img.get_width()) / window.size.x
	var top := _top_layer()
	for node in st.find_children("*", "Control", true, false):
		var c := node as Control
		if c == null or not c.is_visible_in_tree() or c.size.x < 2.0 or c.size.y < 2.0:
			continue
		if top != null and c != top and not top.is_ancestor_of(c):
			continue
		var text := _text_of(c)
		var rect := c.get_global_rect()
		var scrolled := _in_scroll(c)
		var clip := _clip_rect(c)
		if text != "":
			_language(screen, c, text)
		var leaf := true
		for child in c.get_children():
			if child is Control and child.visible:
				leaf = false
				break
		if not leaf and text == "":
			continue
		var shown := rect.intersection(clip) if clip.has_area() else rect
		if not scrolled and not window.grow(1.0).encloses(rect) and window.intersects(rect):
			_note(screen, c, "outside_window", "%s vs window %s" % [_r(rect), _r(window)])
		elif not scrolled and not window.intersects(rect) and text != "":
			_note(screen, c, "off_screen", _r(rect))
		var need := c.get_combined_minimum_size()
		if text != "" and (c.size.x + 1.0 < need.x or c.size.y + 1.0 < need.y):
			_note(screen, c, "squeezed", "size %s, needs %s" % [str(c.size.round()), str(need.round())])
		if c is Label:
			_label_cut(screen, c)
		elif c is Button and text != "":
			_button_cut(screen, c)
		elif c is RichTextLabel and not c.fit_content and not c.scroll_active and c.get_content_height() > c.size.y + 2:
			_note(screen, c, "text_cut", "content %d px in %d px" % [c.get_content_height(), int(c.size.y)])
		var parent := c.get_parent() as Control
		if parent != null and parent is Container and not (parent is ScrollContainer) and not parent.clip_contents and is_zero_approx(c.get_global_transform().get_rotation()):
			var room := parent.get_global_rect().grow(2.0)
			if not room.encloses(rect):
				_note(screen, c, "outside_parent", "%s in %s %s" % [_r(rect), parent.get_class(), _r(parent.get_global_rect())])
		if text.strip_edges().length() >= 3 and shown.has_area() and shown.size.y >= rect.size.y * 0.8 and window.encloses(shown) and (c is Label or c is Button):
			var ink := _ink_rect(c, shown)
			var ratio := _contrast(img, Rect2(ink.position * px, ink.size * px))
			if ratio > 0.0 and ratio < 2.2:
				_note(screen, c, "low_contrast", "%.2f:1" % ratio)


## The layer drawn last among the open overlays; controls under it are hidden from the player and are not checked.
func _top_layer() -> Control:
	var best: Control = null
	for layer in [st.network_view, st.card, st.hub_layer, st.menu_layer, st.notice_layer]:
		var c := layer as Control
		if c == null or not c.is_visible_in_tree():
			continue
		if best == null or c.is_greater_than(best):
			best = c
	return best


func _text_of(c: Control) -> String:
	if c is Label:
		return c.text
	if c is Button:
		return c.text
	if c is RichTextLabel:
		return c.get_parsed_text()
	if c is LineEdit:
		return c.text if c.text != "" else c.placeholder_text
	return ""


func _label_cut(screen: String, c: Label) -> void:
	if c.text.strip_edges() == "":
		return
	if c.autowrap_mode != TextServer.AUTOWRAP_OFF:
		if c.max_lines_visible < 0 and c.get_visible_line_count() < c.get_line_count():
			_note(screen, c, "text_cut", "%d of %d lines shown" % [c.get_visible_line_count(), c.get_line_count()])
		return
	if c.clip_text or c.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		var font := c.get_theme_font("font")
		var px := c.get_theme_font_size("font_size")
		var width := 0.0
		for line in c.text.split("\n"):
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
		if width > c.size.x + 1.0:
			_note(screen, c, "text_cut", "text %d px in %d px" % [int(width), int(c.size.x)])


func _button_cut(screen: String, c: Button) -> void:
	if c.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return
	if not c.clip_text and c.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		return
	var font := c.get_theme_font("font")
	var px := c.get_theme_font_size("font_size")
	var style := c.get_theme_stylebox("normal")
	var pad := style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT) if style != null else 0.0
	var icon_w := float(c.icon.get_width()) + 4.0 if c.icon != null else 0.0
	var width := font.get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + pad + icon_w
	if width > c.size.x + 1.0:
		_note(screen, c, "text_cut", "button text %d px in %d px" % [int(width), int(c.size.x)])


func _in_scroll(c: Node) -> bool:
	var at := c.get_parent()
	while at != null:
		if at is ScrollContainer:
			return true
		at = at.get_parent()
	return false


func _clip_rect(c: Control) -> Rect2:
	var out_rect := Rect2()
	var at := c.get_parent()
	while at != null:
		if at is Control and (at.clip_contents or at is ScrollContainer):
			var r: Rect2 = at.get_global_rect()
			out_rect = r if not out_rect.has_area() else out_rect.intersection(r)
		at = at.get_parent()
	return out_rect


## The part of a label actually covered by its text, so a short word in a wide row is not measured against bare paper.
func _ink_rect(c: Control, shown: Rect2) -> Rect2:
	if not (c is Label) or c.horizontal_alignment != HORIZONTAL_ALIGNMENT_LEFT:
		return shown
	var font: Font = c.get_theme_font("font")
	var px: int = c.get_theme_font_size("font_size")
	var width := 0.0
	for line in c.text.split("\n"):
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	var r := shown
	r.size.x = minf(r.size.x, width + 2.0)
	return r


## Contrast of the lightest against the darkest pixels under the text (1st and 99th percentile), as a WCAG-style ratio.
func _contrast(img: Image, rect: Rect2) -> float:
	var lum: Array = []
	var step := maxi(1, int(rect.size.x * rect.size.y / 2500.0))
	var x0 := int(rect.position.x)
	var y0 := int(rect.position.y)
	var w := int(rect.size.x)
	var h := int(rect.size.y)
	var i := 0
	for y in range(y0, mini(y0 + h, img.get_height())):
		for x in range(x0, mini(x0 + w, img.get_width())):
			i += 1
			if i % step != 0:
				continue
			var col := img.get_pixel(x, y)
			lum.append(0.2126 * _lin(col.r) + 0.7152 * _lin(col.g) + 0.0722 * _lin(col.b))
	if lum.size() < 20:
		return 0.0
	lum.sort()
	var lo: float = lum[int(lum.size() * 0.01)]
	var hi: float = lum[int(lum.size() * 0.99)]
	return (hi + 0.05) / (lo + 0.05)


func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


var latin := RegEx.create_from_string("[A-Za-z][A-Za-z']{2,}")
var cyrillic := RegEx.create_from_string("[А-Яа-яЁё]")
var raw_id := RegEx.create_from_string("\\b(?:[a-z]+_[a-z0-9_]+|st\\d_\\w*)\\b")
var log_tag := RegEx.create_from_string("^(?:⚠ )?(?:ULTIMATUM|SHORT|AGENT|FIND|JOIN|BATTLE|WARN|DEFECT|REVOLT|DEAL|PREACH|TRUTH|TESTIMONY|ROT|SEASON|INTENT|STANDING) ")


func _language(screen: String, c: Control, text: String) -> void:
	texts[text.left(200)] = true
	if Copy.ru():
		var words: PackedStringArray = []
		for m in latin.search_all(text):
			if not LATIN_OK.has(m.get_string()):
				words.append(m.get_string())
		if not words.is_empty():
			_note(screen, c, "latin_in_ru", "%s in '%s'" % [", ".join(words), text.left(120)])
	elif cyrillic.search(text) != null:
		_note(screen, c, "cyrillic_in_en", text.left(120))
	var id := raw_id.search(text)
	if id != null:
		_note(screen, c, "raw_id", "%s in '%s'" % [id.get_string(), text.left(120)])
	if text.contains("—") or text.contains("–"):
		_note(screen, c, "dash", text.left(120))
	if log_tag.search(text) != null:
		_note(screen, c, "log_tag", text.left(120))


func _note(screen: String, c: Control, kind: String, detail: String) -> void:
	findings.append({"screen": screen, "kind": kind, "node": _path(c), "class": c.get_class(), "text": _text_of(c).left(80), "detail": detail})


func _path(c: Node) -> String:
	var bits: PackedStringArray = []
	var at := c
	while at != null and at != st:
		bits.insert(0, at.name if not str(at.name).begins_with("@") else at.get_class())
		at = at.get_parent()
	return "/".join(bits)


func _r(r: Rect2) -> String:
	return "(%d,%d %dx%d)" % [int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub in DirAccess.get_directories_at(path):
		_wipe(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
