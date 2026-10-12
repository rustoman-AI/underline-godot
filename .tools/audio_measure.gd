extends SceneTree

## Integrated loudness (ITU-R BS.1770-4: K-weighting, 400 ms blocks, 75% overlap, -70 LUFS absolute and
## -10 LU relative gates), sample peak and length of UI cues and room loops, decoded headless with
## AudioStreamPlayback.mix_audio. Clips shorter than one 400 ms block are measured as one ungated block.
## godot --headless -s res://.tools/audio_measure.gd -- [--gain=click:-6,hydroponics:-8]

const FILES := [
	"res://assets/audio/click.ogg", "res://assets/audio/hover.ogg", "res://assets/audio/confirm.ogg",
	"res://assets/audio/error.ogg", "res://assets/audio/whoosh.ogg", "res://assets/audio/built.ogg",
	"res://assets/audio/thud.ogg", "res://assets/audio/card.ogg", "res://assets/audio/radio.ogg",
	"res://assets/audio/drip.ogg",
	"res://assets/audio/rooms/air_filter.ogg", "res://assets/audio/rooms/generator.ogg",
	"res://assets/audio/rooms/hydroponics.ogg", "res://assets/audio/rooms/infirmary.ogg",
	"res://assets/audio/rooms/meeting_hall.ogg", "res://assets/audio/rooms/platform.ogg",
	"res://assets/audio/rooms/quarters.ogg", "res://assets/audio/rooms/radio.ogg",
	"res://assets/audio/rooms/workshop.ogg",
]


func _init() -> void:
	var rate := AudioServer.get_mix_rate()
	print("mix rate %d" % int(rate))
	print("%-34s %8s %9s %9s %10s" % ["file", "len ms", "LUFS", "peak dB", "audible ms"])
	for path in FILES:
		var stream := (load(path) as AudioStream).duplicate() as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		var frames := _decode(stream, rate)
		var lufs := _loudness(frames, rate)
		var peak := 0.0
		var last := 0
		for i in frames.size():
			var m := maxf(absf(frames[i].x), absf(frames[i].y))
			peak = maxf(peak, m)
			if m > 0.001:
				last = i
		print("%-34s %8d %9.1f %9.1f %10d" % [path.get_file() if not path.contains("/rooms/") else "rooms/" + path.get_file(),
			int(stream.get_length() * 1000.0), lufs, linear_to_db(maxf(peak, 0.000001)), int(float(last) / rate * 1000.0)])
	_after(rate)
	quit()


## What the player hears now: Sound.CLICK_DB with the hold-and-fade cut, and the hydroponics loop at the
## open-panel level with its trim, before and after.
func _after(rate: float) -> void:
	var click := _decode(load("res://assets/audio/click.ogg"), rate)
	var gain := db_to_linear(Sound.CLICK_DB)
	var hold := int(Sound.CLICK_HOLD * rate)
	var fade := int(Sound.CLICK_FADE * rate)
	var cut := PackedVector2Array()
	for i in mini(click.size(), hold + fade):
		var g := gain
		if i >= hold:
			g *= db_to_linear(lerpf(0.0, Sound.SILENT_DB - Sound.CLICK_DB, float(i - hold) / float(fade)))
		cut.append(click[i] * g)
	print("after: click.ogg as played  len %d ms  LUFS %.1f (file %.1f)" % [int(float(cut.size()) / rate * 1000.0), _loudness(cut, rate), _loudness(click, rate)])
	var hydro_stream := (load("res://assets/audio/rooms/hydroponics.ogg") as AudioStream).duplicate() as AudioStreamOggVorbis
	hydro_stream.loop = false
	var hydro := _loudness(_decode(hydro_stream, rate), rate)
	var trim := float(Sound.ROOM_TRIM.get("hydroponics", 0.0))
	print("after: hydroponics loop  len %d ms  file %.1f LUFS  open panel before %.1f, after %.1f  hover before %.1f, after %.1f  fades after %.1f s open" % [
		int(hydro_stream.get_length() * 1000.0), hydro, hydro + Sound.ROOM_DB_OPEN, hydro + Sound.ROOM_DB_OPEN + trim,
		hydro + Sound.ROOM_DB_HOVER, hydro + Sound.ROOM_DB_HOVER + trim, float(Sound.ROOM_FADE_AFTER.get("hydroponics", 0.0))])


func _decode(stream: AudioStream, rate: float) -> PackedVector2Array:
	var playback := stream.instantiate_playback()
	playback.start(0.0)
	var out := PackedVector2Array()
	var want := int(ceil(stream.get_length() * rate))
	while out.size() < want and playback.is_playing():
		var chunk: PackedVector2Array = playback.mix_audio(1.0, mini(4096, want - out.size()))
		if chunk.is_empty():
			break
		out.append_array(chunk)
	return out


func _kweight(frames: PackedVector2Array, rate: float) -> PackedVector2Array:
	var k := tan(PI * 1681.974450955533 / rate)
	var vh := pow(10.0, 3.999843853973347 / 20.0)
	var vb := pow(vh, 0.4996667741545416)
	var q := 0.7071752369554196
	var a0 := 1.0 + k / q + k * k
	var s1 := [(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0,
		2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
	k = tan(PI * 38.13547087602444 / rate)
	q = 0.5003270373238773
	a0 = 1.0 + k / q + k * k
	var s2 := [1.0, -2.0, 1.0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0]
	return _biquad(_biquad(frames, s1), s2)


func _biquad(x: PackedVector2Array, c: Array) -> PackedVector2Array:
	var y := PackedVector2Array()
	y.resize(x.size())
	var x1 := Vector2.ZERO
	var x2 := Vector2.ZERO
	var y1 := Vector2.ZERO
	var y2 := Vector2.ZERO
	for i in x.size():
		var v: Vector2 = x[i] * float(c[0]) + x1 * float(c[1]) + x2 * float(c[2]) - y1 * float(c[3]) - y2 * float(c[4])
		x2 = x1
		x1 = x[i]
		y2 = y1
		y1 = v
		y[i] = v
	return y


func _loudness(frames: PackedVector2Array, rate: float) -> float:
	if frames.is_empty():
		return -INF
	var w := _kweight(frames, rate)
	var block := int(0.4 * rate)
	var hop := int(0.1 * rate)
	var powers: Array = []
	if w.size() < block:
		powers.append(_power(w, 0, w.size()))
	else:
		var start := 0
		while start + block <= w.size():
			powers.append(_power(w, start, block))
			start += hop
	var kept: Array = powers.filter(func(p): return _lufs(p) > -70.0)
	if kept.is_empty():
		return -INF
	var gate := _lufs(_mean(kept)) - 10.0
	var final: Array = kept.filter(func(p): return _lufs(p) > gate)
	return _lufs(_mean(final))


func _power(w: PackedVector2Array, start: int, count: int) -> float:
	var sum := 0.0
	for i in range(start, start + count):
		sum += w[i].x * w[i].x + w[i].y * w[i].y
	return sum / float(count)


func _mean(values: Array) -> float:
	var sum := 0.0
	for v in values:
		sum += float(v)
	return sum / float(values.size())


func _lufs(p: float) -> float:
	return -0.691 + 10.0 * log(maxf(p, 1e-12)) / log(10.0)
