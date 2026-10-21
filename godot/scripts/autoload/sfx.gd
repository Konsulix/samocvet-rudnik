extends Node
## Sound effects synthesised once at start-up (the same recipes as the prototype's WebAudio synth),
## played from a small pool of players. Also the phone's haptics.

const RATE := 22050
var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func play(sfx_name: String, arg := 0) -> void:
	if Save.d.get("mute", false): return
	var key := "%s%d" % [sfx_name, arg]
	if not _cache.has(key):
		_cache[key] = _make(sfx_name, arg)
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _cache[key]
	p.play()

## light taps for hits, a longer thump for blasts
func buzz(ms := 20) -> void:
	if Save.d.get("mute", false): return
	Input.vibrate_handheld(ms)

# ---------------------------------------------------------------- synth

func _make(n: String, k: int) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(int(RATE * 1.3))
	buf.fill(0.0)
	match n:
		"swap": _noise(buf, 0.08, 1800, 0.08, "band")
		"bad":
			_tone(buf, 180, 0, 0.12, 0.06, "square")
			_tone(buf, 140, 0.08, 0.12, 0.05, "square")
		"pop":
			var f := 520.0 * pow(1.12, mini(10, k))
			_tone(buf, f, 0, 0.12, 0.07, "triangle", 1.6)
			_tone(buf, f * 2, 0.02, 0.08, 0.03, "sine")
		"rock":
			_noise(buf, 0.15, 600, 0.25, "low")
			_tone(buf, 110, 0, 0.1, 0.06, "square", 0.6)
		"boom":
			_noise(buf, 0.6, 160, 0.5, "low")
			_tone(buf, 70, 0, 0.4, 0.12, "saw", 0.5)
		"rocket": _noise(buf, 0.35, 2600, 0.15, "high")
		"zap": _tone(buf, 1400, 0, 0.25, 0.05, "saw", 0.4)
		"special":
			for i in 3: _tone(buf, [660, 880, 1320][i], i * 0.05, 0.18, 0.05, "triangle")
		"coin":
			_tone(buf, 1568, 0, 0.08, 0.06, "square")
			_tone(buf, 2093, 0.06, 0.12, 0.05, "square")
		"win":
			for i in 5: _tone(buf, [523, 659, 784, 1047, 1319][i], i * 0.1, 0.45, 0.08, "triangle")
		"lose":
			for i in 3: _tone(buf, [392, 330, 262][i], i * 0.16, 0.4, 0.07, "triangle")
		"crack":
			_noise(buf, 0.18, 2600 + k * 500, 0.4, "high")
			_tone(buf, 300 - k * 40, 0, 0.08, 0.06, "square")
		"reveal":
			var st := [0, 4, 7, 12, 16, 19]
			for i in 3 + k: _tone(buf, 392.0 * pow(2.0, st[mini(5, i)] / 12.0), i * 0.08, 0.6, 0.08, "triangle")
		"build":
			for i in 4: _tone(buf, [392, 523, 659, 784][i], i * 0.08, 0.4, 0.07, "triangle")
			_noise(buf, 0.4, 400, 0.15, "low")
		"gas": _noise(buf, 0.5, 500, 0.15, "band")
	# trim the silent tail and convert to 16-bit PCM
	var last := buf.size() - 1
	while last > 0 and absf(buf[last]) < 0.0005: last -= 1
	var data := PackedByteArray()
	data.resize((last + 1) * 2)
	for i in last + 1:
		data.encode_s16(i * 2, int(clampf(buf[i] * 2.2, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _env(t: float, dur: float) -> float:
	if t < 0.008: return t / 0.008
	return pow(0.0001, (t - 0.008) / maxf(0.001, dur - 0.008))

func _tone(buf: PackedFloat32Array, f: float, at: float, dur: float, vol: float, type := "sine", slide := 0.0) -> void:
	var i0 := int(at * RATE)
	var nsamp := int(dur * RATE)
	var phase := 0.0
	for i in nsamp:
		if i0 + i >= buf.size(): break
		var t := i / float(RATE)
		var freq := f * pow(slide, t / dur) if slide > 0.0 else f
		phase = fmod(phase + freq / RATE, 1.0)
		var s := 0.0
		match type:
			"sine": s = sin(phase * TAU)
			"triangle": s = 1.0 - 4.0 * absf(phase - 0.5)
			"square": s = 1.0 if phase < 0.5 else -1.0
			"saw": s = 2.0 * phase - 1.0
		buf[i0 + i] += s * vol * _env(t, dur)

func _noise(buf: PackedFloat32Array, dur: float, freq: float, vol: float, type: String) -> void:
	var nsamp := int(dur * RATE)
	var a_lo := 1.0 - exp(-TAU * freq * (1.4 if type == "band" else 1.0) / RATE)
	var a_hi := 1.0 - exp(-TAU * freq * (0.7 if type == "band" else 1.0) / RATE)
	var lo := 0.0
	var hi_lo := 0.0
	for i in nsamp:
		if i >= buf.size(): break
		var x := (randf() * 2.0 - 1.0) * pow(1.0 - i / float(nsamp), 2.0)
		var y := 0.0
		match type:
			"low":
				lo += a_lo * (x - lo)
				y = lo
			"high":
				hi_lo += a_hi * (x - hi_lo)
				y = x - hi_lo
			"band":
				hi_lo += a_hi * (x - hi_lo)
				var h := x - hi_lo
				lo += a_lo * (h - lo)
				y = lo * 2.0
		buf[i] += y * vol
