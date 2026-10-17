extends Control

## The 40-second teaser "The Silence", drawn by the engine and recorded with Godot's Movie Maker:
##   godot --path . --resolution 1920x1080 --fixed-fps 30 --write-movie build/teaser/teaser_en.avi \
##     res://tools/teaser/teaser.tscn -- --lang=en [--stills]
## Script, slots and pictures are in docs/briefs/teaser_silence_edit.md. Narration plays from
## incoming-audio/teaser-vo-01/ogg/teaser_silence_<n>_<lang>_take1.ogg when the file is there; without it the
## subtitles carry the line. --stills also saves a PNG at each review time to build/teaser/stills_<lang>/.

const LENGTH := 40.5
const FADE := 0.7
const VO_DIR := "res://incoming-audio/teaser-vo-01/ogg/"
const STILL_TIMES := [2.0, 7.0, 13.0, 19.0, 23.5, 27.0, 30.0, 33.5, 38.5]
const AMBER := Color("e2a63a")
const PAPER := Color("e8dcc4")
const MUTED := Color("a89a80")

## Pictures with a slow push or pan: [path, start, end, zoom from, zoom to, pan from, pan to]. Pan is the
## centre of the crop as a share of the picture (0.5, 0.5 is the middle).
const SHOTS := [
	["res://assets/hubs/hub_coney_island.webp", 4.0, 10.3, 1.0, 1.06, Vector2(0.38, 0.5), Vector2(0.55, 0.52)],
	["res://assets/hubs/northgate.webp", 10.0, 16.3, 1.08, 1.0, Vector2(0.6, 0.55), Vector2(0.45, 0.5)],
	["res://assets/hubs/brickworks.webp", 16.0, 22.3, 1.0, 1.1, Vector2(0.45, 0.55), Vector2(0.68, 0.5)],
	["res://shots/map_size/teaser/{lang}_1920x1080/station_view.png", 22.0, 25.8, 1.32, 1.24, Vector2(0.4, 0.5), Vector2(0.5, 0.5)],
	["res://shots/map_size/teaser/{lang}_1920x1080/network_territories_all.png", 25.5, 28.8, 1.3, 1.5, Vector2(0.5, 0.5), Vector2(0.62, 0.6)],
	["res://incoming-art/stations/style_v3/dockyard.png", 28.5, 31.0, 1.0, 1.08, Vector2(0.4, 0.5), Vector2(0.3, 0.55)],
]

## The 9:16 cut sees a third of a wide picture, so each shot gets its own crop there, in SHOTS order:
## [zoom from, zoom to, pan from, pan to].
const PORTRAIT := [
	[1.0, 1.05, Vector2(0.42, 0.5), Vector2(0.55, 0.5)],
	[1.05, 1.0, Vector2(0.62, 0.5), Vector2(0.3, 0.5)],
	[1.0, 1.08, Vector2(0.45, 0.5), Vector2(0.68, 0.5)],
	[1.25, 1.2, Vector2(0.22, 0.52), Vector2(0.3, 0.52)],
	[1.3, 1.45, Vector2(0.3, 0.55), Vector2(0.42, 0.6)],
	[1.0, 1.05, Vector2(0.24, 0.55), Vector2(0.28, 0.55)],
]

## Narration slots: [line number, start, end]. The subtitle shows for the slot; the voice starts a beat in.
const LINES := [[1, 4.4, 9.8], [2, 10.4, 15.8], [3, 16.4, 21.8], [4, 22.2, 31.0], [5, 31.6, 35.8]]

const TEXT := {
	"en": {
		"place": "New York. 03:40.",
		1: "One night, the surface stopped answering.",
		2: "The radios went quiet. Whoever went up never came back.",
		3: "So we stayed below. We called it the Silence.",
		4: "Now every station is its own country. Food. Air. Light.\nAnd neighbours who want the same.",
		5: "But up there... someone is still counting.",
		"tag": "Hold one station. Keep the lights on.\nDo not ask what happened up there.",
		"cta": "Wishlist on Steam",
	},
	"ru": {
		"place": "Нью-Йорк. 03:40.",
		1: "Однажды ночью сверху перестали отвечать.",
		2: "Радио замолчало. Кто поднимался наверх, тот не возвращался.",
		3: "Мы остались под землёй. И назвали это Тишиной.",
		4: "Теперь каждая станция сама себе государство. Еда. Воздух. Свет.\nИ соседи, которым нужно то же самое.",
		5: "Но наверху... кто-то до сих пор ведёт счёт.",
		"tag": "Держи станцию. Держи свет.\nИ не спрашивай, что там наверху.",
		"cta": "Добавь в желаемое в Steam",
	},
}

var lang := "en"
var portrait := false
var vertical := false
var frames_dir := ""
var frame := 0
var stills := false
var t := 0.0
var shot_nodes: Array = []
var subtitle: Label
var band: ColorRect
var place: Label
var logo: Control
var music: AudioStreamPlayer
var hiss: AudioStreamPlayer
var tick: AudioStreamPlayer
var voices := {}
var next_tick := 0.5
var still_index := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			lang = str(arg).trim_prefix("--lang=")
		if str(arg) == "--stills":
			stills = true
		if str(arg) == "--vertical":
			vertical = true
	if vertical and get_viewport() == get_tree().root:
		_host_vertical()
		return
	var vp := get_viewport_rect().size
	portrait = vp.y > vp.x
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	for row in SHOTS:
		_add_shot(row)
	add_child(_vignette())
	place = _label(str(TEXT[lang].place), _font(true), 64, PAPER)
	place.set_anchors_preset(Control.PRESET_FULL_RECT)
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(place)
	band = _band()
	add_child(band)
	subtitle = _label("", _font(false), 26, PAPER)
	subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_top = -150
	subtitle.offset_bottom = -48
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	subtitle.add_theme_constant_override("outline_size", 8)
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	if portrait:
		subtitle.add_theme_font_size_override("font_size", 46)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle.offset_left = 70
		subtitle.offset_right = -70
		subtitle.offset_top = -900
		subtitle.offset_bottom = -560
		band.offset_top = -1050
	add_child(subtitle)
	logo = _logo()
	add_child(logo)
	music = _player("res://assets/audio/music/M1_menu_theme.ogg", -80.0)
	hiss = _player("res://assets/audio/radio.ogg", -80.0)
	tick = _player("res://assets/audio/hover.ogg", -6.0)
	for row in LINES:
		var path := VO_DIR + "teaser_silence_%d_%s_take1.ogg" % [int(row[0]), lang]
		if FileAccess.file_exists(path):
			var stream := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
			var p := AudioStreamPlayer.new()
			p.stream = stream
			add_child(p)
			voices[int(row[0])] = p
	if stills:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/teaser/stills_%s%s" % [lang, "_v" if portrait else ""]))
	_update()


## A screen will not open a 1080x1920 window, so --vertical draws the teaser inside an off-screen viewport of that
## size and saves every frame to build/teaser/frames_<lang>_v/. The sound is the same as the 16:9 recording;
## ffmpeg puts the two together.
func _host_vertical() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1080, 1920)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	frames_dir = "res://build/teaser/frames_%s_v" % lang
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frames_dir))
	var inner = load("res://tools/teaser/teaser.tscn").instantiate()
	inner.frames_dir = frames_dir
	sv.add_child(inner)
	set_process(false)


func _process(delta: float) -> void:
	t += delta
	_update()
	if frames_dir != "":
		get_viewport().get_texture().get_image().save_png("%s/f%05d.png" % [frames_dir, frame])
		frame += 1
	if stills and still_index < STILL_TIMES.size() and t >= float(STILL_TIMES[still_index]):
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://build/teaser/stills_%s%s/t%04.1f.png" % [lang, "_v" if portrait else "", float(STILL_TIMES[still_index])])
		still_index += 1
	if t >= LENGTH:
		get_tree().quit()


func _update() -> void:
	var size := get_viewport_rect().size
	for item in shot_nodes:
		_place_shot(item, size)
	place.modulate.a = _window(t, 0.8, 3.6, 0.6)
	var line_text := ""
	var line_alpha := 0.0
	for row in LINES:
		var a := _window(t, float(row[1]), float(row[2]), 0.35)
		if a > 0.0:
			line_text = str(TEXT[lang][int(row[0])])
			line_alpha = a
	subtitle.text = line_text
	subtitle.modulate.a = line_alpha
	band.modulate.a = line_alpha
	logo.modulate.a = _window(t, 36.3, LENGTH + 1.0, 0.9)
	_sound()


## The audio cues, keyed to the clock: the ticking clock, then the radio, music under the story, silence and
## the counting clicks, music back under the title.
func _sound() -> void:
	var ticking := t < 4.0 or (t >= 31.8 and t < 36.0)
	if ticking and t >= next_tick:
		tick.pitch_scale = 1.0 if t < 4.0 else 0.72
		tick.play()
		next_tick += 1.0 if t < 4.0 else 0.62
	if t >= 4.0 and t < 31.8 and next_tick < 31.8:
		next_tick = 31.8
	var duck := 1.0
	for n in voices:
		if (voices[n] as AudioStreamPlayer).playing:
			duck = 0.4
	_level(hiss, (_window(t, 0.2, 14.0, 2.5) * 0.55 + _window(t, 31.2, 36.0, 0.6) * 0.3) * duck)
	_level(music, (_window(t, 4.0, 31.0, 2.0) * 0.6 + _window(t, 36.0, LENGTH + 2.0, 1.2) * 0.7) * duck)
	if t >= 31.0 and t < 36.0 and music.playing:
		music.stop()
	if t >= 36.0 and not music.playing:
		music.play(0.0)
	if t >= 0.2 and not hiss.playing and t < 36.0:
		hiss.play()
	if t >= 4.0 and t < 31.0 and not music.playing:
		music.play()
	for n in voices:
		var start := 0.0
		for row in LINES:
			if int(row[0]) == int(n):
				start = float(row[1]) + 0.2
		var p: AudioStreamPlayer = voices[n]
		if t >= start and not p.playing and not p.has_meta("done"):
			p.play()
			p.set_meta("done", true)


func _level(p: AudioStreamPlayer, amount: float) -> void:
	p.volume_db = linear_to_db(maxf(amount, 0.0001))


## 0 outside [a, b], 1 inside, with linear fades of `fade` seconds at both ends.
func _window(x: float, a: float, b: float, fade: float) -> float:
	if x <= a or x >= b:
		return 0.0
	return clampf(minf((x - a) / fade, (b - x) / fade), 0.0, 1.0)


func _add_shot(row: Array) -> void:
	var path := str(row[0]).replace("{lang}", lang)
	var tex := _texture(path)
	if tex == null:
		push_warning("teaser: missing " + path)
		return
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	shot_nodes.append({"node": rect, "row": row, "index": shot_nodes.size()})


## Cover-fit the picture, zoomed and centred on the pan point, faded in and out at its ends.
func _place_shot(item: Dictionary, size: Vector2) -> void:
	var row: Array = item.row
	var rect: TextureRect = item.node
	var a := float(row[1])
	var b := float(row[2])
	rect.modulate.a = _window(t, a, b, FADE)
	rect.visible = rect.modulate.a > 0.0
	if not rect.visible:
		return
	var k := clampf((t - a) / (b - a), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var crop: Array = PORTRAIT[int(item.index)] if portrait else [row[3], row[4], row[5], row[6]]
	var zoom := lerpf(float(crop[0]), float(crop[1]), k)
	var pan: Vector2 = (crop[2] as Vector2).lerp(crop[3] as Vector2, k)
	var tex_size := rect.texture.get_size()
	var cover := maxf(size.x / tex_size.x, size.y / tex_size.y) * zoom
	var shown := tex_size * cover
	var pos := size * 0.5 - shown * pan
	pos.x = clampf(pos.x, size.x - shown.x, 0.0)
	pos.y = clampf(pos.y, size.y - shown.y, 0.0)
	rect.position = pos
	rect.size = shown


func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	return p


func _font(display: bool) -> Font:
	if lang == "ru":
		return load("res://assets/fonts/Oswald.ttf" if display else "res://assets/fonts/PTMono-Regular.ttf")
	return _bold() if display else load("res://assets/fonts/CourierPrime-Regular.ttf")


func _label(text: String, font: Font, px: int, color: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.add_theme_font_override("font", font)
	lab.add_theme_font_size_override("font_size", px)
	lab.add_theme_color_override("font_color", color)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


## UNDERLINE over a thick line, the key line under it and the call to wishlist.
func _logo() -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("UNDERLINE", _bold(), 132, PAPER)
	box.add_child(title)
	var bar_row := CenterContainer.new()
	var bar := ColorRect.new()
	bar.color = AMBER
	bar.custom_minimum_size = Vector2(560, 12)
	bar_row.add_child(bar)
	box.add_child(bar_row)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	box.add_child(gap)
	box.add_child(_label(str(TEXT[lang].tag), _font(false), 26, PAPER))
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 22)
	box.add_child(gap2)
	box.add_child(_label(str(TEXT[lang].cta), _font(true), 30, AMBER))
	return box


func _vignette() -> ColorRect:
	var v := ColorRect.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.38, 0.85, length(d * vec2(1.0, 0.8)));
	COLOR = vec4(0.0, 0.0, 0.0, v * 0.75);
}"""
	mat.shader = sh
	v.material = mat
	return v


## A dark gradient under the subtitles so they read over the map and the bright frames.
func _band() -> ColorRect:
	var b := ColorRect.new()
	b.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	b.offset_top = -200
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.0, 0.7, UV.y) * 0.72);
}"""
	mat.shader = sh
	b.material = mat
	return b


## Big Shoulders is a variable font that opens at its thinnest; the title and the call to action need the bold.
func _bold() -> Font:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/BigShouldersDisplay.ttf")
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): 700}
	return f
