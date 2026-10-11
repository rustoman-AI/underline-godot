extends SceneTree

## Writes the generated station audio as WAV into .tools/audio/. Encode to OGG with ffmpeg afterwards.
## godot --headless --path . -s res://tools/synth_audio.gd

const RATE := 22050
const FADE := 11025
const OUT := "res://.tools/audio"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rng.seed = 8841
	_write("ambient", _loop(_ambient(60), 0.45))
	_write("drip", _norm(_drip(), 0.6))
	_write("radio", _norm(_radio_cue(), 0.55))
	var rooms := {
		"hydroponics": _hydroponics,
		"workshop": _workshop,
		"generator": _generator,
		"air_filter": _air_filter,
		"quarters": _quarters,
		"infirmary": _infirmary,
		"meeting_hall": _meeting_hall,
		"radio": _radio_room,
		"platform": _platform,
	}
	for key in rooms:
		rng.seed = hash(key)
		var cb: Callable = rooms[key]
		_write("room_" + str(key), _loop(cb.call(8), 0.7))
	quit()


func _ambient(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var brown := 0.0
	var low := 0.0
	for i in src.size():
		brown = brown * 0.992 + rng.randf_range(-1.0, 1.0) * 0.008
		low += (brown - low) * 0.12
		src[i] = low
	return src


func _drip() -> PackedFloat32Array:
	var n := int(RATE * 0.35)
	var out := _silence(n)
	var phase := 0.0
	var splash := 0.0
	for k in n:
		var t := float(k) / float(RATE)
		var freq := 640.0 + 760.0 * (1.0 - exp(-t / 0.03))
		phase += TAU * freq / float(RATE)
		var env := exp(-t / 0.028) * minf(1.0, t / 0.002)
		splash += (rng.randf_range(-1.0, 1.0) - splash) * 0.3
		out[k] = sin(phase) * env * 0.8 + splash * exp(-t / 0.012) * 0.25
	return out


func _radio_cue() -> PackedFloat32Array:
	var n := int(RATE * 0.7)
	var out := _silence(n)
	var lp := 0.0
	for k in n:
		var t := float(k) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.35
		var hiss := white - lp
		var env := minf(1.0, t / 0.02) * clampf((0.7 - t) / 0.25, 0.0, 1.0)
		var crackle := 0.0
		if rng.randf() < 0.004:
			crackle = rng.randf_range(-1.0, 1.0)
		out[k] = (hiss * 0.5 + crackle) * env
		if t > 0.62 and t < 0.64:
			out[k] += sin(TAU * 900.0 * t) * 0.3
	return out


func _hydroponics(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var fan := 0.0
	var hp_lp := 0.0
	var band := 0.0
	var gate := 0.0
	var gate_to := 0.5
	for i in src.size():
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		fan += (white - fan) * 0.05
		hp_lp += (white - hp_lp) * 0.08
		band += ((white - hp_lp) - band) * 0.45
		if i % 441 == 0:
			gate_to = rng.randf_range(0.2, 1.0)
		gate += (gate_to - gate) * 0.004
		src[i] = fan * 0.9 + band * gate * 0.35 + sin(TAU * 120.0 * t) * 0.02
	for _b in seconds * 3:
		_bubble(src, rng.randi_range(0, src.size() - RATE), rng.randf_range(260.0, 520.0), rng.randf_range(0.04, 0.1))
	return src


func _bubble(src: PackedFloat32Array, at: int, base: float, gain: float) -> void:
	var length := int(RATE * 0.08)
	var phase := 0.0
	for k in length:
		var t := float(k) / float(RATE)
		phase += TAU * base * (1.0 + t * 8.0) / float(RATE)
		src[at + k] += sin(phase) * exp(-t / 0.025) * gain


func _workshop(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var rumble := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		rumble += (rng.randf_range(-1.0, 1.0) - rumble) * 0.03
		var wobble := 1.0 + 0.02 * sin(TAU * 0.7 * t)
		var whine := sin(TAU * 182.0 * wobble * t) * 0.06 + sin(TAU * 364.0 * wobble * t) * 0.03
		src[i] = rumble * 0.8 + whine * (0.6 + 0.4 * sin(TAU * 0.25 * t))
	var at := rng.randi_range(RATE / 4, RATE)
	while at < src.size() - RATE:
		_clank(src, at, rng.randf_range(0.25, 0.55))
		at += rng.randi_range(int(RATE * 0.9), int(RATE * 2.6))
	return src


func _clank(src: PackedFloat32Array, at: int, gain: float) -> void:
	var partials := [820.0, 1340.0, 2210.0, 3170.0]
	var length := int(RATE * 0.35)
	var shift := rng.randf_range(0.85, 1.15)
	for k in length:
		var t := float(k) / float(RATE)
		var v := 0.0
		for j in partials.size():
			v += sin(TAU * float(partials[j]) * shift * t) * exp(-t / (0.09 / float(j + 1)))
		src[at + k] += v * gain * 0.3


func _generator(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var low := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.06
		var chug := 0.55 + 0.45 * pow(0.5 + 0.5 * sin(TAU * 7.5 * t), 3.0)
		var hum := sin(TAU * 55.0 * t) * 0.3 + sin(TAU * 110.0 * t) * 0.14 + sin(TAU * 165.0 * t) * 0.06
		src[i] = hum + low * chug * 1.2
	return src


func _air_filter(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.22
		var blade := 0.85 + 0.15 * sin(TAU * 22.0 * t)
		src[i] = lp * blade + sin(TAU * 70.0 * t) * 0.05
	return src


func _quarters(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	for i in src.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		src[i] = lp * 0.8
	for _m in 3:
		_murmur(src, rng.randi_range(0, src.size() - RATE * 3), rng.randf_range(1.2, 2.6), 0.25)
	return src


func _murmur(src: PackedFloat32Array, at: int, seconds: float, gain: float) -> void:
	var length := int(RATE * seconds)
	var hp_lp := 0.0
	var band := 0.0
	var rate := rng.randf_range(3.0, 5.0)
	for k in length:
		var t := float(k) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		hp_lp += (white - hp_lp) * 0.04
		band += ((white - hp_lp) - band) * 0.12
		var syllable := maxf(0.0, sin(TAU * rate * t + sin(TAU * 1.3 * t)))
		var env := sin(PI * t / seconds)
		src[at + k] += band * syllable * env * gain


func _infirmary(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.04
		var breath := 0.5 + 0.5 * sin(TAU * 0.25 * t)
		var buzz := sin(TAU * 120.0 * t) * 0.05 + sin(TAU * 240.0 * t) * 0.02
		src[i] = lp * (0.4 + 0.6 * breath) + buzz
	return src


func _meeting_hall(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	for i in src.size():
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.03
		src[i] = lp * 0.5
	for _v in seconds * 2:
		_murmur(src, rng.randi_range(0, src.size() - RATE * 3), rng.randf_range(0.8, 2.4), rng.randf_range(0.2, 0.4))
	return src


func _radio_room(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	var sweep := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.3
		var crackle := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.002 else 0.0
		sweep += TAU * (1400.0 + 500.0 * sin(TAU * 0.125 * t)) / float(RATE)
		src[i] = (white - lp) * 0.25 + crackle * 0.8 + sin(sweep) * 0.015
	return src


func _platform(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	var lp2 := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.02
		lp2 += (lp - lp2) * 0.2
		var swell := 0.35 + 0.65 * pow(0.5 - 0.5 * cos(TAU * t / float(seconds)), 2.0)
		var squeal := sin(TAU * (2600.0 + 40.0 * sin(TAU * 3.0 * t)) * t) * 0.01 * swell
		src[i] = lp2 * 2.5 * swell + squeal
	return src


func _silence(count: int) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(count)
	data.fill(0.0)
	return data


func _loop(src: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var n := src.size() - FADE
	var out := _silence(n)
	for i in n:
		out[i] = src[i]
	for i in FADE:
		var mix := float(i) / float(FADE)
		out[i] = src[i] * mix + src[n + i] * (1.0 - mix)
	return _norm(out, peak)


func _norm(out: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.001
	for sample in out:
		top = maxf(top, absf(sample))
	var gain := peak / top
	for i in out.size():
		out[i] = clampf(out[i] * gain, -1.0, 1.0)
	return out


func _write(file_name: String, samples: PackedFloat32Array) -> void:
	var path := ProjectSettings.globalize_path("%s/%s.wav" % [OUT, file_name])
	var file := FileAccess.open(path, FileAccess.WRITE)
	var data_bytes := samples.size() * 2
	file.store_string("RIFF")
	file.store_32(36 + data_bytes)
	file.store_string("WAVE")
	file.store_string("fmt ")
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(RATE)
	file.store_32(RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_string("data")
	file.store_32(data_bytes)
	for sample in samples:
		file.store_16(int(round(sample * 32767.0)))
	file.close()
	print(file_name, " ", samples.size())
