extends SceneTree

## Integrated loudness (ITU-R BS.1770-4: K-weighting, 400 ms blocks, 75% overlap, -70 LUFS absolute and
## -10 LU relative gates), sample peak and length of UI cues and room loops, decoded headless with
## AudioStreamPlayback.mix_audio. Clips shorter than one 400 ms block are measured as one ungated block.
## godot --headless --path . -s res://.tools/audio_measure_dir.gd -- --dir=res://assets/audio [--limit=40] [--played] [--env=1500]
## --played also prints what the player hears with the current Sound constants: each click*.ogg from its
## FILE_START after the CLICK_DB hold-and-fade cut, and each room loop (room_<id>.ogg or rooms/<id>.ogg) at
## the open and hover levels, each music track at its Music levels and the ambient and menu_tone beds.
## --env prints the peak of each 10 ms window over the first milliseconds.

## The volume_db Sound._loop_player gives the ambient bed and the menu tone.
const BED_DB := -10.0

var dir := "res://assets/audio"
var limit := 0
var played := false
var env_ms := 0


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--dir="):
			dir = str(arg).trim_prefix("--dir=")
		elif str(arg).begins_with("--limit="):
			limit = int(str(arg).trim_prefix("--limit="))
		elif str(arg) == "--played":
			played = true
		elif str(arg).begins_with("--env="):
			env_ms = int(str(arg).trim_prefix("--env="))
	var root := ProjectSettings.globalize_path(dir) if dir.begins_with("res://") else dir
	var rate := AudioServer.get_mix_rate()
	print("mix rate %d, %s" % [int(rate), dir])
	print("%-34s %8s %9s %9s %10s" % ["file", "len ms", "LUFS", "peak dB", "audible ms"])
	var FILES: Array = []
	for f in DirAccess.get_files_at(root):
		if f.ends_with(".ogg"):
			FILES.append(root + "/" + f)
	FILES.sort()
	if limit > 0 and FILES.size() > limit:
		FILES = FILES.slice(0, limit)
	var levels: Array = []
	for path in FILES:
		var stream: AudioStream = AudioStreamOggVorbis.load_from_file(path)
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
		print("%-34s %8d %9.1f %9.1f %10d" % [path.get_file(),
			int(stream.get_length() * 1000.0), lufs, linear_to_db(maxf(peak, 0.000001)), int(float(last) / rate * 1000.0)])
		levels.append(lufs)
		if env_ms > 0:
			_envelope(frames, rate)
		if played:
			_played(path, frames, lufs, rate)
	if not levels.is_empty():
		levels.sort()
		print("files %d: LUFS min %.1f, median %.1f, max %.1f" % [levels.size(), levels[0], levels[levels.size() / 2], levels[-1]])
	quit()


## Peak dB per 10 ms window over the first --env milliseconds.
func _envelope(frames: PackedVector2Array, rate: float) -> void:
	var step := int(rate / 100.0)
	var cells: PackedStringArray = []
	for w in mini(env_ms / 10, frames.size() / step):
		var m := 0.0
		for i in range(w * step, (w + 1) * step):
			m = maxf(m, maxf(absf(frames[i].x), absf(frames[i].y)))
		cells.append("%d" % int(linear_to_db(maxf(m, 0.000001))))
	print("  env 10ms: " + " ".join(cells))


## What the player hears with the current Sound constants.
func _played(path: String, frames: PackedVector2Array, lufs: float, rate: float) -> void:
	var file := path.get_file().get_basename()
	if file.begins_with("click"):
		var db := Sound.CLICK_DB + float(Sound.FILE_DB.get(file, 0.0))
		var start := int(float(Sound.FILE_START.get(file, 0.0)) * rate)
		var hold := int(Sound.CLICK_HOLD * rate)
		var fade := int(Sound.CLICK_FADE * rate)
		var cut := PackedVector2Array()
		for i in mini(frames.size() - start, hold + fade):
			var g := db_to_linear(db)
			if i >= hold:
				g *= db_to_linear(lerpf(0.0, Sound.SILENT_DB - db, float(i - hold) / float(fade)))
			cut.append(frames[start + i] * g)
		print("  played: %s from %d ms, cut to %d ms, %.1f LUFS (file %.1f, %+.1f dB)" % [file, int(float(start) / rate * 1000.0),
			int(float(cut.size()) / rate * 1000.0), _loudness(cut, rate), lufs, db])
		return
	if path.get_base_dir().ends_with("music"):
		var base := lufs + Music.BASE_DB
		print("  played: music %.1f LUFS, under a voice %.1f, fewer cues %.1f, both %.1f (base %+.1f, duck %+.1f, quiet %+.1f dB; Music bus %+.1f at %.2f)" % [
			base, base + Music.DUCK_DB, base + Music.QUIET_DB, base + Music.DUCK_DB + Music.QUIET_DB,
			Music.BASE_DB, Music.DUCK_DB, Music.QUIET_DB, linear_to_db(Settings.music), Settings.music])
		return
	if file == "ambient" or file == "menu_tone":
		print("  played: bed %s %.1f LUFS (%+.1f dB, Music bus)" % [file, lufs + BED_DB, BED_DB])
		return
	var room := file.trim_prefix("room_") if file.begins_with("room_") else (file if path.get_base_dir().ends_with("rooms") else "")
	if room == "":
		return
	var trim := float(Sound.ROOM_TRIM.get(room, 0.0))
	print("  played: room %s open %.1f LUFS, hover %.1f LUFS (open %+.1f, hover %+.1f, trim %+.1f dB)" % [room,
		lufs + Sound.ROOM_DB_OPEN + trim, lufs + Sound.ROOM_DB_HOVER + trim, Sound.ROOM_DB_OPEN, Sound.ROOM_DB_HOVER, trim])


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
