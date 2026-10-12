class_name Settings
extends RefCounted

## Player preferences in user://settings.cfg. Window, audio, language, motion.

## Tests point this at a scratch file so they never touch the player's settings.
static var path := "user://settings.cfg"
const DRIP_MODES := ["off", "rare", "often"]

static var master := 0.85
static var music := 0.55
static var sfx := 0.8
static var radio := 0.8
static var drips := "rare"
static var room_sounds := true
## No hover ticks or drips, and room loops only while a room panel is open.
static var quiet_cues := false
static var radio_on := true
## Weeks between cable radio items once the station has a radio room; 0 means twice a week.
static var radio_every := 1
static var language := ""
static var fullscreen := false
static var ui_scale := 1.0
static var reduce_motion := false
static var people_free_only := false
## Playtest log: "" until the player answers the consent card, then "yes" or "no".
static var log_consent := ""
static var howto_hidden := false
static var loaded := false
static var resume := false
static var reopen := ""


static func load_file() -> void:
	if loaded:
		return
	loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	master = clampf(float(cfg.get_value("audio", "master", master)), 0.0, 1.0)
	music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
	sfx = clampf(float(cfg.get_value("audio", "sfx", sfx)), 0.0, 1.0)
	radio = clampf(float(cfg.get_value("audio", "radio", radio)), 0.0, 1.0)
	drips = str(cfg.get_value("audio", "drips", drips))
	if not DRIP_MODES.has(drips):
		drips = "rare"
	room_sounds = bool(cfg.get_value("audio", "room_sounds", room_sounds))
	quiet_cues = bool(cfg.get_value("audio", "quiet_cues", quiet_cues))
	radio_on = bool(cfg.get_value("radio", "on", radio_on))
	radio_every = clampi(int(cfg.get_value("radio", "every_weeks", radio_every)), 0, 4)
	language = str(cfg.get_value("game", "language", ""))
	fullscreen = bool(cfg.get_value("game", "fullscreen", false))
	ui_scale = clampf(float(cfg.get_value("game", "ui_scale", 1.0)), 0.75, 1.5)
	reduce_motion = bool(cfg.get_value("game", "reduce_motion", false))
	people_free_only = bool(cfg.get_value("game", "people_free_only", false))
	log_consent = str(cfg.get_value("playtest", "log", ""))
	if log_consent != "yes" and log_consent != "no":
		log_consent = ""
	howto_hidden = bool(cfg.get_value("playtest", "howto_hidden", false))


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "radio", radio)
	cfg.set_value("audio", "drips", drips)
	cfg.set_value("audio", "room_sounds", room_sounds)
	cfg.set_value("audio", "quiet_cues", quiet_cues)
	cfg.set_value("radio", "on", radio_on)
	cfg.set_value("radio", "every_weeks", radio_every)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "fullscreen", fullscreen)
	cfg.set_value("game", "ui_scale", ui_scale)
	cfg.set_value("game", "reduce_motion", reduce_motion)
	cfg.set_value("game", "people_free_only", people_free_only)
	cfg.set_value("playtest", "log", log_consent)
	cfg.set_value("playtest", "howto_hidden", howto_hidden)
	cfg.save(path)


static func reduced() -> bool:
	load_file()
	return reduce_motion


static func apply_display(win: Window) -> void:
	load_file()
	if fullscreen:
		win.mode = Window.MODE_FULLSCREEN
	else:
		win.mode = Window.MODE_WINDOWED
		win.size = Vector2i(1280, 720)
	win.content_scale_factor = ui_scale
	if absf(ui_scale - 1.0) < 0.01:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	else:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
