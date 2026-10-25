extends Node
## Sounds and music. Most effects are recorded samples (Kenney, CC0: assets/audio/CREDITS.md), picked at random
## from a few takes and nudged in pitch so repeats do not sound mechanical; the rest are synthesised once at
## start-up (the prototype's WebAudio recipes). Background music: one loop on the home screens, two
## alternating ones in the levels, cross-faded. Also the phone's haptics.

const RATE := 22050
const SFX := "res://assets/audio/sfx/"
## name -> takes, volume (dB), pitch step per arg (a cascade climbs), synth layer underneath
const SAMPLES := {
	swap = {f = ["impactGlass_light_000", "impactGlass_light_001", "impactGlass_light_002"], db = -8.0},
	pop = {f = ["impactGlass_medium_000", "impactGlass_medium_001", "impactGlass_medium_002"], db = -6.0, step = 0.06},
	bad = {f = ["error_006"], db = -6.0},
	rock = {f = ["impactMining_000", "impactMining_001", "impactMining_002", "impactMining_003"], db = -3.0},
	crack = {f = ["impactMining_001", "impactMining_003"], db = -2.0, step = 0.12},
	boom = {f = ["impactPunch_heavy_000", "impactPunch_heavy_001"], db = -2.0, pitch = 0.7, synth = true},
	special = {f = ["glass_002"], db = -4.0},
	coin = {f = ["chips-stack-1", "chips-stack-2", "chips-collide-1"], db = -6.0},
	build = {f = ["impactPlank_medium_000", "confirmation_002"], db = -4.0, all = true},
	win = {f = ["jingles_SAX02"], db = -2.0},
	lose = {f = ["jingles_SAX07"], db = -3.0},
	reveal = {f = ["jingles_SAX10"], db = -3.0},
	reveal_rare = {f = ["jingles_SAX16", "impactBell_heavy_000"], db = -3.0, all = true},
	click = {f = ["click_002"], db = -10.0},
	tab = {f = ["switch_002"], db = -8.0},
	open = {f = ["open_001"], db = -10.0},
}
const MUSIC := {home = ["res://assets/audio/music/home.ogg"], level = ["res://assets/audio/music/level1.ogg", "res://assets/audio/music/level2.ogg"],
	# a boss's own theme: "boss_<id>"
	boss_poloz = ["res://assets/audio/music/boss_poloz.mp3"]}
const MUSIC_DB := -14.0

var _cache := {}
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _fade: Tween
var _cur := 0
var _track := ""
var _level_i := 0

func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)

func play(sfx_name: String, arg := 0) -> void:
	if Save.d.get("mute", false): return
	if sfx_name == "reveal" and arg >= 3: sfx_name = "reveal_rare"
	if SAMPLES.has(sfx_name):
		var d: Dictionary = SAMPLES[sfx_name]
		var takes: Array = d.f
		var pick: Array = takes if d.get("all", false) else [takes[randi() % takes.size()]]
		for f in pick:
			var p := _player()
			p.stream = _sample(f)
			p.volume_db = d.get("db", 0.0)
			p.pitch_scale = float(d.get("pitch", 1.0)) * (1.0 + float(d.get("step", 0.0)) * mini(arg, 10)) * randf_range(0.96, 1.04)
			p.play()
		if not d.get("synth", false):
			return
	var key := "%s%d" % [sfx_name, arg]
	if not _cache.has(key):
		_cache[key] = _make(sfx_name, arg)
	var sp := _player()
	sp.stream = _cache[key]
	sp.volume_db = 0.0
	sp.pitch_scale = 1.0
	sp.play()

func _player() -> AudioStreamPlayer:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	return p

func _sample(f: String) -> AudioStream:
	if not _streams.has(f):
		_streams[f] = load(SFX + f + ".ogg")
	return _streams[f]

## background music for "home" or "level": cross-fades to it (levels alternate between their two loops)
func music(track: String) -> void:
	if track == _track and _music[_cur].playing:
		return
	_track = track
	var list: Array = MUSIC[track]
	var path: String = list[_level_i % list.size()]
	if track == "level": _level_i += 1
	var st: AudioStream = load(path)
	st.set("loop", true)   # Ogg and MP3 both loop
	var old := _music[_cur]
	_cur = 1 - _cur
	var nw := _music[_cur]
	nw.stream = st
	nw.volume_db = -40.0
	nw.play()
	# a cross-fade still running would stop the player this one starts
	if _fade and _fade.is_valid(): _fade.kill()
	var tw := create_tween().set_parallel(true)
	_fade = tw
	tw.tween_property(nw, "volume_db", _music_db(), 1.2)
	tw.tween_property(old, "volume_db", -60.0, 0.9)
	tw.chain().tween_callback(old.stop)

func _music_db() -> float:
	return -80.0 if Save.d.get("mute", false) else MUSIC_DB

## sound switched on or off
func apply_mute() -> void:
	_music[_cur].volume_db = _music_db()

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
