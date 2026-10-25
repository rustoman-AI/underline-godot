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
		_write("room_" + str(key), _loop(cb.call(12), 0.7))
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


## A soft drop into a puddle: mostly splash noise with a short low plink, so it never reads as a beep.
func _drip() -> PackedFloat32Array:
	var n := int(RATE * 0.4)
	var out := _silence(n)
	var phase := 0.0
	var splash := 0.0
	var tail := 0.0
	for k in n:
		var t := float(k) / float(RATE)
		var freq := 380.0 + 320.0 * (1.0 - exp(-t / 0.02))
		phase += TAU * freq / float(RATE)
		var env := exp(-t / 0.014) * minf(1.0, t / 0.004)
		splash += (rng.randf_range(-1.0, 1.0) - splash) * 0.22
		tail += (splash - tail) * 0.08
		out[k] = sin(phase) * env * 0.35 + splash * exp(-t / 0.02) * 0.5 + tail * exp(-t / 0.12) * 0.6
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


## Grow room: AC compressor and fan under a steady trickle, a hose spraying now and then, bubbling trays.
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
		if i % 220 == 0:
			gate_to = rng.randf_range(0.35, 1.0)
		gate += (gate_to - gate) * 0.01
		var compressor := sin(TAU * 60.0 * t) * 0.05 + sin(TAU * 120.4 * t) * 0.035 + sin(TAU * 180.0 * t) * 0.012
		src[i] = fan * 0.7 + band * gate * 0.3 + compressor
	var at := rng.randi_range(0, RATE)
	while at < src.size() - RATE * 2:
		_hose(src, at, rng.randf_range(1.2, 2.2), rng.randf_range(0.18, 0.28))
		at += rng.randi_range(RATE * 3, RATE * 6)
	for _b in seconds * 3:
		_bubble(src, rng.randi_range(0, src.size() - RATE), rng.randf_range(260.0, 520.0), rng.randf_range(0.04, 0.1))
	return src


func _hose(src: PackedFloat32Array, at: int, seconds: float, gain: float) -> void:
	var length := int(RATE * seconds)
	var lp := 0.0
	for k in length:
		var t := float(k) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.5
		var env := minf(1.0, t / 0.12) * minf(1.0, (seconds - t) / 0.3)
		var flutter := 0.8 + 0.2 * sin(TAU * 9.0 * t + rng.randf() * 0.3)
		src[at + k] += (white - lp * 0.6) * env * flutter * gain


func _bubble(src: PackedFloat32Array, at: int, base: float, gain: float) -> void:
	var length := int(RATE * 0.08)
	var phase := 0.0
	for k in length:
		var t := float(k) / float(RATE)
		phase += TAU * base * (1.0 + t * 8.0) / float(RATE)
		src[at + k] += sin(phase) * exp(-t / 0.025) * gain


## Machine shop: a lathe motor that spins up and down, a belt thumping unevenly, filing, a dull clank now and then.
func _workshop(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var rumble := 0.0
	var phase := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		rumble += (rng.randf_range(-1.0, 1.0) - rumble) * 0.03
		var spin := 0.5 - 0.5 * cos(TAU * t / float(seconds))
		phase += TAU * (140.0 + 60.0 * spin) / float(RATE)
		var whine := sin(phase) * 0.05 + sin(phase * 2.0) * 0.03 + sin(phase * 3.0) * 0.012
		src[i] = rumble * 0.8 + whine * (0.4 + 0.6 * spin)
	var at := rng.randi_range(0, RATE / 2)
	while at < src.size() - RATE:
		_thump(src, at, rng.randf_range(0.25, 0.4))
		at += rng.randi_range(int(RATE * 0.38), int(RATE * 0.62))
	at = rng.randi_range(RATE, RATE * 2)
	while at < src.size() - RATE * 2:
		_file(src, at, rng.randi_range(4, 8))
		at += rng.randi_range(RATE * 3, RATE * 5)
	at = rng.randi_range(RATE * 2, RATE * 3)
	while at < src.size() - RATE:
		_clank(src, at, rng.randf_range(0.15, 0.3))
		at += rng.randi_range(RATE * 2, RATE * 4)
	return src


func _thump(src: PackedFloat32Array, at: int, gain: float) -> void:
	var length := int(RATE * 0.12)
	var lp := 0.0
	for k in length:
		var t := float(k) / float(RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.06
		src[at + k] += (lp * 2.5 + sin(TAU * 70.0 * t) * 0.4) * exp(-t / 0.03) * gain


func _file(src: PackedFloat32Array, at: int, strokes: int) -> void:
	var stroke := int(RATE * 0.22)
	var hp_lp := 0.0
	for s in strokes:
		for k in stroke:
			var t := float(k) / float(stroke)
			var white := rng.randf_range(-1.0, 1.0)
			hp_lp += (white - hp_lp) * 0.3
			src[at + s * stroke + k] += (white - hp_lp) * sin(PI * t) * 0.12


func _clank(src: PackedFloat32Array, at: int, gain: float) -> void:
	var partials := [410.0, 690.0, 1150.0]
	var length := int(RATE * 0.25)
	var shift := rng.randf_range(0.85, 1.15)
	for k in length:
		var t := float(k) / float(RATE)
		var v := 0.0
		for j in partials.size():
			v += sin(TAU * float(partials[j]) * shift * t) * exp(-t / (0.05 / float(j + 1)))
		src[at + k] += v * gain * 0.3


func _generator(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var low := 0.0
	var rattle := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.06
		var chug := 0.55 + 0.45 * pow(0.5 + 0.5 * sin(TAU * 7.5 * t + 0.4 * sin(TAU * 0.5 * t)), 3.0)
		var hum := sin(TAU * 50.0 * t) * 0.3 + sin(TAU * 100.0 * t) * 0.16 + sin(TAU * 150.0 * t) * 0.07 + sin(TAU * 200.0 * t) * 0.03
		rattle += (rng.randf_range(-1.0, 1.0) - rattle) * 0.4
		src[i] = hum * (0.9 + 0.1 * chug) + low * chug * 1.1 + rattle * chug * 0.04
	return src


## Two big extractor fans a little out of step, with blade beat and air rushing through the ducts.
func _air_filter(seconds: int) -> PackedFloat32Array:
	var src := _silence(RATE * seconds + FADE)
	var lp := 0.0
	var duct := 0.0
	for i in src.size():
		var t := float(i) / float(RATE)
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.22
		duct += (white - duct) * 0.04
		var blade_a := 0.8 + 0.2 * sin(TAU * 22.0 * t)
		var blade_b := 0.85 + 0.15 * sin(TAU * 23.5 * t)
		var tone := sin(TAU * 88.0 * t) * 0.04 + sin(TAU * 94.0 * t) * 0.035 + sin(TAU * 176.0 * t) * 0.015
		src[i] = lp * blade_a * 0.6 + duct * blade_b * 1.2 + tone
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
