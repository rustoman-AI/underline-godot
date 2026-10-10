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

static var host: Node
static var players := {}
static var ambient: AudioStreamPlayer
static var drone: AudioStreamPlayer
static var last_ms := {}


static func boot(tree_host: Node) -> void:
	if host != null and is_instance_valid(host):
		apply_buses()
		return
	host = tree_host
	_ensure_bus("Music")
	_ensure_bus("SFX")
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


static func has_ambient() -> bool:
	return ambient != null


static func has_drone() -> bool:
	return drone != null


static func apply_buses() -> void:
	Settings.load_file()
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_bus_db("Master", Settings.master)
	_bus_db("Music", Settings.music)
	_bus_db("SFX", Settings.sfx)


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


static func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = ResourceLoader.load(path)
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
