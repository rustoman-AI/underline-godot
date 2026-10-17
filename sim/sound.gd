class_name Sound
extends RefCounted

## Short cues on the SFX bus; a cue with several files picks one at random. Looping beds play only when
## the files exist.

const CUES := {
	"click": ["res://assets/audio/click_01.ogg", "res://assets/audio/click_02.ogg", "res://assets/audio/click_03.ogg"],
	"hover": "res://assets/audio/hover.ogg",
	"confirm": "res://assets/audio/confirm.ogg",
	"error": "res://assets/audio/error.ogg",
	"end_turn": "res://assets/audio/end_turn.ogg",
	"build_done": "res://assets/audio/build_done.ogg",
	"upgrade": "res://assets/audio/upgrade.ogg",
	"dig": "res://assets/audio/dig.ogg",
	"card_open": ["res://assets/audio/card_open.ogg", "res://assets/audio/card_open_02.ogg", "res://assets/audio/card_open_03.ogg"],
	"new_week": "res://assets/audio/new_week.ogg",
	"audience_open": "res://assets/audio/audience_open.ogg",
	"dossier_open": "res://assets/audio/dossier_open.ogg",
	"dossier_tab": "res://assets/audio/dossier_tab.ogg",
	"map_click": "res://assets/audio/map_click.ogg",
}
const AMBIENT := "res://assets/audio/ambient.ogg"
const MENU_TONE := "res://assets/audio/menu_tone.ogg"
const DRIP := "res://assets/audio/drip.ogg"
const RADIO_CUE := "res://assets/audio/radio.ogg"
const ROOM_DIR := "res://assets/audio/rooms"
# Seconds between drips for each Settings.drips mode.
const DRIP_GAPS := {"rare": Vector2(45.0, 100.0), "often": Vector2(12.0, 30.0)}
## drip.ogg is 12 s of drops at most 1.5 s apart: each drip plays a slice from a random point.
const DRIP_HOLD := 1.3
const DRIP_FADE := 0.3
## radio.ogg is 10 s of static: the burst before a radio voice keeps the old 0.7 s length.
const RADIO_HOLD := 0.5
const RADIO_FADE := 0.2
## Room loops are -23 LUFS files: open plays them near -28 LUFS, 8 LU under the -20 LUFS voices.
const ROOM_DB_HOVER := -15.0
const ROOM_DB_OPEN := -5.0
const HOVER_DB := -9.0
const SILENT_DB := -60.0
## The click files run 479 ms; each is played 6 dB down and faded out so it is over by 78 ms.
const CLICK_DB := -6.0
const CLICK_HOLD := 0.06
const CLICK_FADE := 0.018
## Seconds skipped at the start of a file whose first hit comes late, and per-file trims that keep the
## cut click variants level with each other.
const FILE_START := {"click_03": 0.135, "dig": 0.5}
const FILE_DB := {"click_01": 3.0, "click_02": -2.5}
## A press that also starts an action cue (confirm, end_turn, card_open...) plays only that cue.
const PAIR_MS := 80
## Cues that land while end_turn swells wait for its impact, then follow one another QUEUE_STEP_MS apart.
const AFTER_END_TURN := ["build_done", "card_open", "new_week", "audience_open"]
const END_TURN_MS := 1250
const QUEUE_STEP_MS := 700
## Per-room trim on top of the open/hover level, and seconds open before the loop fades away.
const ROOM_TRIM := {"hydroponics": -10.0}
const ROOM_FADE_AFTER := {"hydroponics": 1.4}
const CUE_CUT := {
	"end_turn": [-9.0, 0.45, 0.18],
	"dossier_open": [-8.0, 0.35, 0.12],
	"dossier_tab": [-10.0, 0.2, 0.08],
	"new_week": [-6.0, 0.55, 0.16],
	"map_click": [-4.0, 0.16, 0.06],
}
const ROOM_FADE_OUT := 1.5

static var host: Node
static var players := {}
static var ambient: AudioStreamPlayer
static var drone: AudioStreamPlayer
static var drip: AudioStreamPlayer
static var drip_timer: Timer
static var room_player: AudioStreamPlayer
static var room_tween: Tween
static var room_now := ""
static var room_open_now := false
static var room_streams := {}
static var radio_cue: AudioStreamPlayer
static var voice: AudioStreamPlayer
static var voice_timer: Timer
static var voice_tail: AudioStreamPlayer
static var voice_tween: Tween
static var last_ms := {}
static var click_tween: Tween
static var drip_tween: Tween
static var radio_tween: Tween
static var variants := {}
static var queue_ms := 0
static var queued := {}
static var rng := RandomNumberGenerator.new()


static func boot(tree_host: Node) -> void:
	if host != null and is_instance_valid(host):
		apply_buses()
		return
	host = tree_host
	rng.randomize()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Radio")
	_ensure_bus("Voice", "SFX")
	apply_buses()
	for cue in CUES:
		var files: Array = []
		for path in cue_files(cue):
			var stream := _stream(path)
			if stream != null:
				files.append({"stream": stream, "name": path.get_file().get_basename()})
		if files.is_empty():
			continue
		var player := AudioStreamPlayer.new()
		player.stream = files[0].stream
		player.bus = "SFX"
		player.name = "Sfx" + str(cue)
		if cue == "hover":
			player.volume_db = HOVER_DB
		host.add_child(player)
		players[cue] = player
		variants[cue] = files
	ambient = _loop_player(AMBIENT, "Ambient")
	drone = _loop_player(MENU_TONE, "MenuTone")
	drip = _one_shot(DRIP, "Drip", "Music")
	radio_cue = _one_shot(RADIO_CUE, "RadioCue", "Radio")
	room_player = AudioStreamPlayer.new()
	room_player.bus = "Music"
	room_player.name = "Room"
	room_player.volume_db = SILENT_DB
	host.add_child(room_player)
	voice = AudioStreamPlayer.new()
	voice.bus = "Radio"
	voice.name = "Voice"
	host.add_child(voice)
	voice_timer = Timer.new()
	voice_timer.one_shot = true
	voice_timer.name = "VoiceTimer"
	voice_timer.timeout.connect(func() -> void:
		if voice.stream != null:
			voice.play())
	host.add_child(voice_timer)
	voice_tail = AudioStreamPlayer.new()
	voice_tail.name = "VoiceTail"
	host.add_child(voice_tail)
	drip_timer = Timer.new()
	drip_timer.one_shot = true
	drip_timer.name = "DripTimer"
	drip_timer.timeout.connect(_drip_due)
	host.add_child(drip_timer)


## Every file a cue may play.
static func cue_files(cue: String) -> PackedStringArray:
	var entry = CUES.get(cue, [])
	return PackedStringArray(entry) if entry is Array else PackedStringArray([str(entry)])


static func play(cue: String) -> void:
	if cue == "" or not players.has(cue):
		return
	if cue == "hover" and Settings.quiet_cues:
		return
	var now := Time.get_ticks_msec()
	if cue in AFTER_END_TURN and now < queue_ms and host != null and host.is_inside_tree():
		if queued.has(cue):
			return
		queued[cue] = true
		var wait := float(queue_ms - now) / 1000.0
		queue_ms += QUEUE_STEP_MS
		host.get_tree().create_timer(wait).timeout.connect(_play_now.bind(cue))
		return
	var gap := 160 if cue == "hover" else 35
	if now - int(last_ms.get(cue, 0)) < gap:
		return
	if cue == "click" and now - int(last_ms.get("action", -PAIR_MS)) < PAIR_MS:
		return
	if cue == "end_turn":
		queue_ms = now + END_TURN_MS
	_play_now(cue)


static func _play_now(cue: String) -> void:
	queued.erase(cue)
	var now := Time.get_ticks_msec()
	if cue != "click" and cue != "hover":
		last_ms["action"] = now
		if now - int(last_ms.get("click", -PAIR_MS)) < PAIR_MS and players.has("click"):
			(players["click"] as AudioStreamPlayer).stop()
	last_ms[cue] = now
	var player: AudioStreamPlayer = players[cue]
	var files: Array = variants[cue]
	var pick: Dictionary = files[rng.randi_range(0, files.size() - 1)]
	player.stream = pick.stream
	var trim := float(FILE_DB.get(pick.name, 0.0))
	var start := float(FILE_START.get(pick.name, 0.0))
	if cue == "click":
		_play_click(player, trim, start)
		return
	if CUE_CUT.has(cue):
		var cut: Array = CUE_CUT[cue]
		_slice(player, start, float(cut[0]) + trim, float(cut[1]), float(cut[2]))
		return
	if cue != "hover":
		player.volume_db = trim
	player.play(start)


static func _play_click(player: AudioStreamPlayer, trim: float, start: float) -> void:
	if click_tween != null and click_tween.is_valid():
		click_tween.kill()
	player.volume_db = CLICK_DB + trim
	player.play(start)
	if host == null or not host.is_inside_tree():
		return
	click_tween = host.create_tween()
	click_tween.tween_interval(CLICK_HOLD)
	click_tween.tween_property(player, "volume_db", SILENT_DB, CLICK_FADE)
	click_tween.tween_callback(player.stop)


## Plays `seconds` of `player` from `start` at `db`, then fades it out over `fade`.
static func _slice(player: AudioStreamPlayer, start: float, db: float, seconds: float, fade: float) -> Tween:
	player.volume_db = db
	player.play(start)
	if host == null or not host.is_inside_tree():
		return null
	var tween := host.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(player, "volume_db", SILENT_DB, fade)
	tween.tween_callback(player.stop)
	return tween


static func bed(which: String) -> void:
	_set_loop(ambient, which == "station")
	_set_loop(drone, which == "hub")
	if which == "station":
		schedule_drip()
	else:
		if drip_timer != null:
			drip_timer.stop()
		room("", false)


static func has_ambient() -> bool:
	return ambient != null


static func has_drone() -> bool:
	return drone != null


## Restarts the drip clock after a settings change or a bed switch.
static func schedule_drip() -> void:
	if drip_timer == null or drip == null:
		return
	drip_timer.stop()
	Settings.load_file()
	if Settings.quiet_cues or not DRIP_GAPS.has(Settings.drips) or ambient == null or not ambient.playing:
		return
	var gap: Vector2 = DRIP_GAPS[Settings.drips]
	drip_timer.start(rng.randf_range(gap.x, gap.y))


static func _drip_due() -> void:
	if ambient == null or not ambient.playing:
		return
	drip.pitch_scale = rng.randf_range(0.75, 1.3)
	if drip_tween != null and drip_tween.is_valid():
		drip_tween.kill()
	var room_left := maxf(drip.stream.get_length() - DRIP_HOLD - DRIP_FADE, 0.0)
	drip_tween = _slice(drip, rng.randf_range(0.0, room_left), rng.randf_range(-24.0, -16.0), DRIP_HOLD, DRIP_FADE)
	schedule_drip()


## Fades the room loop for `type` in, or out when `type` is empty.
static func room(type: String, open: bool) -> void:
	if room_player == null:
		return
	Settings.load_file()
	if not Settings.room_sounds or (Settings.quiet_cues and not open):
		type = ""
	var stream := _room_stream(type)
	if stream == null:
		type = ""
	if type == "" and room_now == "" and not room_player.playing:
		return
	if type != "" and type == room_now and open == room_open_now and room_player.playing:
		return
	room_open_now = open
	var target := SILENT_DB
	if type != "":
		target = (ROOM_DB_OPEN if open else ROOM_DB_HOVER) + float(ROOM_TRIM.get(type, 0.0))
	if room_tween != null and room_tween.is_valid():
		room_tween.kill()
	room_tween = host.create_tween()
	if type != room_now:
		if room_player.playing:
			var out := 0.7 if type == "" else 0.3
			room_tween.tween_property(room_player, "volume_db", SILENT_DB, out).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		room_tween.tween_callback(_swap_room.bind(type, stream))
	room_now = type
	if type != "":
		room_tween.tween_property(room_player, "volume_db", target, 0.45)
		if open and ROOM_FADE_AFTER.has(type):
			room_tween.tween_interval(float(ROOM_FADE_AFTER[type]))
			room_tween.tween_property(room_player, "volume_db", SILENT_DB, ROOM_FADE_OUT)


static func _swap_room(type: String, stream: AudioStream) -> void:
	room_player.stop()
	if type == "" or stream == null:
		return
	room_player.stream = stream
	room_player.volume_db = SILENT_DB
	room_player.play(rng.randf_range(0.0, 6.0))


static func _room_stream(type: String) -> AudioStream:
	if type == "":
		return null
	if room_streams.has(type):
		return room_streams[type]
	var path := "%s/%s.ogg" % [ROOM_DIR, type]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
	room_streams[type] = stream
	return stream


## Static burst that opens a radio item. Returns its length so a voice can start under its tail.
static func radio_static() -> float:
	if radio_cue == null:
		return 0.0
	if radio_tween != null and radio_tween.is_valid():
		radio_tween.kill()
	var room_left := maxf(radio_cue.stream.get_length() - RADIO_HOLD - RADIO_FADE, 0.0)
	radio_tween = _slice(radio_cue, rng.randf_range(0.0, room_left), 0.0, RADIO_HOLD, RADIO_FADE)
	return minf(radio_cue.stream.get_length(), RADIO_HOLD + RADIO_FADE)


## Plays a voice file on `bus` after `delay` seconds. Returns the line length, or 0 when nothing plays.
static func voice_play(voice_path: String, bus: String, delay := 0.0) -> float:
	if voice == null or voice_path == "" or not ResourceLoader.exists(voice_path):
		return 0.0
	var stream := ResourceLoader.load(voice_path) as AudioStream
	if stream == null:
		return 0.0
	voice_fade(0.25)
	voice.stream = stream
	voice.bus = bus
	if delay > 0.0:
		voice_timer.start(delay)
	else:
		voice.play()
	return stream.get_length()


static func voice_stop() -> void:
	if voice == null:
		return
	voice_timer.stop()
	voice.stop()
	voice.stream = null


## Lets the current line die away over `seconds` on a tail player, so the main voice is free at once.
static func voice_fade(seconds: float) -> void:
	if voice == null:
		return
	if voice.playing and voice_tail != null:
		if voice_tween != null and voice_tween.is_valid():
			voice_tween.kill()
		voice_tail.stream = voice.stream
		voice_tail.bus = voice.bus
		voice_tail.volume_db = 0.0
		voice_tail.play(voice.get_playback_position())
		voice_tween = host.create_tween()
		voice_tween.tween_property(voice_tail, "volume_db", SILENT_DB, seconds)
		voice_tween.tween_callback(_tail_done)
	voice_stop()


static func _tail_done() -> void:
	voice_tail.stop()
	voice_tail.stream = null
	voice_tween = null


static func voice_busy() -> bool:
	if voice == null or voice.stream == null:
		return false
	return voice.playing or not voice_timer.is_stopped()


static func apply_buses() -> void:
	Settings.load_file()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Radio")
	_ensure_bus("Voice", "SFX")
	_bus_db("Master", Settings.master)
	_bus_db("Music", Settings.music)
	_bus_db("SFX", Settings.sfx)
	_bus_db("Radio", Settings.radio)


static func _set_loop(player: AudioStreamPlayer, on: bool) -> void:
	if player == null:
		return
	if on:
		if not player.playing:
			player.play()
		return
	player.stop()


static func _loop_player(path: String, node_name: String) -> AudioStreamPlayer:
	var stream := _stream(path)
	if stream == null:
		return null
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop = true
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Music"
	player.name = node_name
	player.volume_db = -18.0 if node_name == "MenuTone" else -10.0
	host.add_child(player)
	return player


static func _one_shot(path: String, node_name: String, bus: String) -> AudioStreamPlayer:
	var stream := _stream(path)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.name = node_name
	host.add_child(player)
	return player


static func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		print("Missing audio: %s" % path)
		return null
	var res: Resource = ResourceLoader.load(path)
	if res == null or not (res is AudioStream):
		print("Missing audio: %s" % path)
		return null
	return res as AudioStream


static func _ensure_bus(bus_name: String, send := "Master") -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)


static func _bus_db(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)))
