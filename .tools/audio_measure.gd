extends SceneTree

## Integrated loudness (ITU-R BS.1770-4: K-weighting, 400 ms blocks, 75% overlap, -70 LUFS absolute and
## -10 LU relative gates), sample peak and length of UI cues and room loops, decoded headless with
## AudioStreamPlayback.mix_audio. Clips shorter than one 400 ms block are measured as one ungated block.
## Measures the pre-ElevenLabs set kept for rollback in assets/audio/_originals_sfx/ (ignored by git and Godot);
## the shipped set and its played levels: .tools/audio_measure_dir.gd -- --dir=res://assets/audio --played
## godot --headless --path . -s res://.tools/audio_measure.gd

const FILES := [
	"res://assets/audio/_originals_sfx/click.ogg", "res://assets/audio/hover.ogg", "res://assets/audio/_originals_sfx/confirm.ogg",
	"res://assets/audio/_originals_sfx/error.ogg", "res://assets/audio/_originals_sfx/whoosh.ogg", "res://assets/audio/_originals_sfx/built.ogg",
	"res://assets/audio/_originals_sfx/thud.ogg", "res://assets/audio/_originals_sfx/card.ogg", "res://assets/audio/_originals_sfx/radio.ogg",
	"res://assets/audio/_originals_sfx/drip.ogg",
	"res://assets/audio/_originals_sfx/rooms/air_filter.ogg", "res://assets/audio/_originals_sfx/rooms/generator.ogg",
	"res://assets/audio/_originals_sfx/rooms/hydroponics.ogg", "res://assets/audio/_originals_sfx/rooms/infirmary.ogg",
	"res://assets/audio/_originals_sfx/rooms/meeting_hall.ogg", "res://assets/audio/_originals_sfx/rooms/platform.ogg",
	"res://assets/audio/_originals_sfx/rooms/quarters.ogg", "res://assets/audio/_originals_sfx/rooms/radio.ogg",
	"res://assets/audio/_originals_sfx/rooms/workshop.ogg",
]


func _init() -> void:
	var rate := AudioServer.get_mix_rate()
	print("mix rate %d" % int(rate))
	print("%-34s %8s %9s %9s %10s" % ["file", "len ms", "LUFS", "peak dB", "audible ms"])
	for path in FILES:
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
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
	quit()



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
