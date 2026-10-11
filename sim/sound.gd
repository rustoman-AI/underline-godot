class_name Sound
extends RefCounted

## Short CC0 cues on the SFX bus. Looping beds play only when the files exist.

const CUES := {
	"click": "res://assets/audio/click.ogg",
	"hover": "res://assets/audio/hover.ogg",
	"confirm": "res://assets/audio/confirm.ogg",
	"error": "res://assets/audio/error.ogg",
	"whoosh": "res://assets/audio/whoosh.ogg",
	"built": "res://assets/audio/built.ogg",
	"thud": "res://assets/audio/thud.ogg",
	"card": "res://assets/audio/card.ogg",
}
const AMBIENT := "res://assets/audio/ambient.ogg"
const DRONE := "res://assets/audio/drone.ogg"
const DRIP := "res://assets/audio/drip.ogg"
const RADIO_CUE := "res://assets/audio/radio.ogg"
const ROOM_DIR := "res://assets/audio/rooms"
# Seconds between drips for each Settings.drips mode.
const DRIP_GAPS := {"rare": Vector2(14.0, 34.0), "often": Vector2(3.0, 9.0)}
const ROOM_DB_HOVER := -20.0
const ROOM_DB_OPEN := -13.0
const SILENT_DB := -60.0

static var host: Node
static var players := {}
static var ambient: AudioStreamPlayer
static var drone: AudioStreamPlayer
static var drip: AudioStreamPlayer
static var drip_timer: Timer
static var room_player: AudioStreamPlayer
static var room_tween: Tween
static var room_now := ""
static var room_streams := {}
static var radio_cue: AudioStreamPlayer
static var voice: AudioStreamPlayer
static var last_ms := {}
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
	apply_buses()
	for cue in CUES:
		var stream := _stream(str(CUES[cue]))
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "SFX"
		player.name = "Sfx" + str(cue)
		host.add_child(player)
		players[cue] = player
	ambient = _loop_player(AMBIENT, "Ambient")
	drone = _loop_player(DRONE, "Drone")
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
	drip_timer = Timer.new()
	drip_timer.one_shot = true
	drip_timer.name = "DripTimer"
	drip_timer.timeout.connect(_drip_due)
	host.add_child(drip_timer)


static func play(cue: String) -> void:
	if cue == "" or not players.has(cue):
		return
	var now := Time.get_ticks_msec()
	var gap := 80 if cue == "hover" else 35
	if now - int(last_ms.get(cue, 0)) < gap:
		return
	last_ms[cue] = now
	var player: AudioStreamPlayer = players[cue]
	player.play()


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
	if not DRIP_GAPS.has(Settings.drips) or ambient == null or not ambient.playing:
		return
	var gap: Vector2 = DRIP_GAPS[Settings.drips]
	drip_timer.start(rng.randf_range(gap.x, gap.y))


static func _drip_due() -> void:
	if ambient == null or not ambient.playing:
		return
	drip.pitch_scale = rng.randf_range(0.75, 1.3)
	drip.volume_db = rng.randf_range(-22.0, -14.0)
	drip.play()
	schedule_drip()


## Fades the room loop for `type` in, or out when `type` is empty.
static func room(type: String, open: bool) -> void:
	if room_player == null:
		return
	Settings.load_file()
	if not Settings.room_sounds:
		type = ""
	var stream := _room_stream(type)
	if stream == null:
		type = ""
	var target := SILENT_DB
	if type != "":
		target = ROOM_DB_OPEN if open else ROOM_DB_HOVER
	if room_tween != null and room_tween.is_valid():
		room_tween.kill()
	room_tween = host.create_tween()
	if type != room_now:
		if room_player.playing:
			room_tween.tween_property(room_player, "volume_db", SILENT_DB, 0.18)
		room_tween.tween_callback(_swap_room.bind(type, stream))
	room_now = type
	if type != "":
		room_tween.tween_property(room_player, "volume_db", target, 0.45)


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


## Static burst before a radio item. Returns true when a voice file started.
static func radio(voice_path: String) -> bool:
	if radio_cue != null:
		radio_cue.play()
	if voice == null or voice_path == "" or not ResourceLoader.exists(voice_path):
		return false
	var stream := ResourceLoader.load(voice_path) as AudioStream
	if stream == null:
		return false
	voice.stop()
	voice.stream = stream
	voice.play()
	return true


static func voice_seconds() -> float:
	if voice == null or voice.stream == null or not voice.playing:
		return 0.0
	return voice.stream.get_length() - voice.get_playback_position()


static func apply_buses() -> void:
	Settings.load_file()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Radio")
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
	player.volume_db = -10.0
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


static func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


static func _bus_db(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)))
