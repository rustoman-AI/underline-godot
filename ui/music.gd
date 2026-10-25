class_name Music
extends Node

## The score on the Music bus: two players that cross over with equal power, so two tracks are never louder
## than one. `source` returns the state below about twice a second; the player only reads it.
##   context "menu"     M1 (main menu and hub)
##   context "station"  M2 calm, M3 tension, M4 crisis (the network map stays here)
##   context "ending"   M5 once, then a fade to silence
##   context "none"     silence (shot mode)
##   hope, discontent, revolt_warn, revolt_edge, hope_warn, flood, cough_call: the station's numbers and flags
##   voice              a voice line is playing: the score ducks DUCK_DB under it
## The files start and end on one held note and do not loop by themselves: near the end the same track starts
## again on the other player and the two overlap for LOOP_FADE seconds.

const DIR := "res://assets/audio/music"
const TRACKS := {
	"menu": "M1_menu_theme",
	"calm": "M2_station_calm",
	"tension": "M3_station_tension",
	"crisis": "M4_station_crisis",
	"ending": "M5_ending_quiet",
}
## The files are -20 LUFS: at BASE_DB they play near -31 LUFS, 11 LU under the -20 LUFS voices and within
## 3 LU of the station bed (ambient.ogg played at -10 dB, about -33 LUFS) on the same bus.
const BASE_DB := -11.0
## "Fewer audio cues" takes the score down this much more.
const QUIET_DB := -6.0
const DUCK_DB := -6.0
const DUCK_IN := 0.3
const DUCK_OUT := 1.5
const SWITCH_FADE := 4.0
const LOOP_FADE := 6.0
const OUT_FADE := 6.0
## A calmer station mood waits this long on the current track; a more intense one comes at once.
const MIN_HOLD := 40.0
## Points the numbers must clear past a threshold before the station mood steps back down.
const HYSTERESIS := 3
const POLL := 0.5
const SILENT_DB := -80.0
const RANK := {"calm": 0, "tension": 1, "crisis": 2}

var source: Callable
## Seconds; the checks drive it by hand.
var clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
## Off in a headless run unless a check turns it on.
var allowed := DisplayServer.get_name() != "headless"
var players: Array[AudioStreamPlayer] = []
## Per player: track, start (clock time of file position 0), p0 and p1 (equal-power phase 0..1), t0, span.
var decks: Array[Dictionary] = [{}, {}]
var front := 0
var track := ""
var mood := ""
var mood_at := -1000.0
var edge_discontent := 999
var ending_done := false
var duck := 0.0
var last_step := -1.0
var poll_left := 0.0
var state := {}
var streams := {}


func _ready() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.name = "Score%d" % i
		player.volume_db = SILENT_DB
		add_child(player)
		players.append(player)
	set_process(allowed)


func _process(delta: float) -> void:
	poll_left -= delta
	if poll_left <= 0.0:
		poll_left = POLL
		state = source.call() if source.is_valid() else {}
	step(float(clock.call()), state)


## One tick at `now` seconds: picks the track, keeps the loop going, fades and ducks.
func step(now: float, at: Dictionary) -> void:
	var dt := 0.0 if last_step < 0.0 else maxf(0.0, now - last_step)
	last_step = now
	var want := want_track(at, now)
	if want != track:
		if want == "":
			_fade_out(now, OUT_FADE)
		else:
			_start(want, now, SWITCH_FADE)
	elif track != "":
		var deck: Dictionary = decks[front]
		var length := _length(track)
		if not deck.is_empty() and length > 0.0 and now - float(deck.start) >= length - LOOP_FADE:
			if track == "ending":
				ending_done = true
				_fade_out(now, OUT_FADE)
			else:
				_start(track, now, LOOP_FADE)
	var target := DUCK_DB if bool(at.get("voice", false)) else 0.0
	if duck > target:
		duck = maxf(target, duck - dt * absf(DUCK_DB) / DUCK_IN)
	elif duck < target:
		duck = minf(target, duck + dt * absf(DUCK_DB) / DUCK_OUT)
	_apply(now)


## What should play for `at`; updates the station mood, its hold and the ending's one play.
func want_track(at: Dictionary, now: float) -> String:
	Settings.load_file()
	if not allowed or not Settings.music_on:
		return ""
	var context := str(at.get("context", "none"))
	if context != "station":
		mood = ""
		edge_discontent = 999
	if context != "ending":
		ending_done = false
	match context:
		"menu":
			return "menu"
		"ending":
			return "" if ending_done else "ending"
		"station":
			var next := pick(mood, at, edge_discontent)
			if bool(at.get("revolt_edge", false)):
				edge_discontent = maxi(edge_discontent if mood == "crisis" else 0, int(at.get("discontent", 0)))
			elif next != "crisis":
				edge_discontent = 999
			if next != mood and (mood == "" or int(RANK[next]) > int(RANK[mood]) or now - mood_at >= MIN_HOLD):
				mood = next
				mood_at = now
			return mood
	return ""


## The station mood for `at` when `cur` plays. Crisis: a flood this week, the Cough waiting on a quarantine,
## or the revolt warning at its edge (it holds until discontent is HYSTERESIS under where the edge was).
## Tension: hope under 50, discontent 60 or more, the revolt warning or the hope warning. Calm: hope 50 or more
## and discontent under 50; tension steps back only at hope 53 and discontent under 47.
static func pick(cur: String, at: Dictionary, edge_at := 999) -> String:
	var hope := int(at.get("hope", 50))
	var discontent := int(at.get("discontent", 0))
	var revolt := bool(at.get("revolt_warn", false))
	if bool(at.get("flood", false)) or bool(at.get("cough_call", false)) or bool(at.get("revolt_edge", false)):
		return "crisis"
	if cur == "crisis" and revolt and discontent > edge_at - HYSTERESIS:
		return "crisis"
	if hope < 50 or discontent >= 60 or revolt or bool(at.get("hope_warn", false)):
		return "tension"
	var settled := hope >= 50 and discontent < 50
	if cur == "tension" or cur == "crisis":
		settled = hope >= 50 + HYSTERESIS and discontent < 50 - HYSTERESIS
	if settled:
		return "calm"
	return cur if cur == "calm" else "tension"


func _start(name: String, now: float, span: float) -> void:
	var stream := _stream(name)
	if stream == null:
		_fade_out(now, span)
		return
	var old: Dictionary = decks[front]
	if not old.is_empty():
		decks[front] = _fade(old, now, 0.0, span)
	front = 1 - front
	var player := players[front]
	player.stop()
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()
	decks[front] = {"track": name, "start": now, "p0": 0.0, "p1": 1.0, "t0": now, "span": span}
	track = name


func _fade_out(now: float, span: float) -> void:
	for i in 2:
		if not decks[i].is_empty():
			decks[i] = _fade(decks[i], now, 0.0, span)
	track = ""


func _fade(deck: Dictionary, now: float, to: float, span: float) -> Dictionary:
	var next := deck.duplicate()
	next.p0 = phase(deck, now)
	next.p1 = to
	next.t0 = now
	next.span = span
	return next


static func phase(deck: Dictionary, now: float) -> float:
	if deck.is_empty():
		return 0.0
	var span := float(deck.span)
	var t := 1.0 if span <= 0.0 else clampf((now - float(deck.t0)) / span, 0.0, 1.0)
	return lerpf(float(deck.p0), float(deck.p1), t)


## Equal power: a deck at phase p plays at sin(p * PI / 2), so two crossing decks always sum to one.
static func gain(p: float) -> float:
	return sin(clampf(p, 0.0, 1.0) * PI * 0.5)


func level_db() -> float:
	Settings.load_file()
	return BASE_DB + (QUIET_DB if Settings.quiet_cues else 0.0) + duck


func _apply(now: float) -> void:
	for i in 2:
		var deck: Dictionary = decks[i]
		if deck.is_empty():
			continue
		var p := phase(deck, now)
		if float(deck.p1) <= 0.0 and p <= 0.0:
			players[i].stop()
			decks[i] = {}
			continue
		players[i].volume_db = maxf(SILENT_DB, level_db() + linear_to_db(maxf(gain(p), 0.0001)))


func _length(name: String) -> float:
	var stream := _stream(name)
	return stream.get_length() if stream != null else 0.0


func _stream(name: String) -> AudioStream:
	if streams.has(name):
		return streams[name]
	var path := file_of(name)
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = ResourceLoader.load(path) as AudioStream
	streams[name] = stream
	return stream


static func file_of(name: String) -> String:
	return "%s/%s.ogg" % [DIR, TRACKS[name]] if TRACKS.has(name) else ""
