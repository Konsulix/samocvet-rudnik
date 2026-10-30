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
	# a swap that does not match: the two stones clack back into place, low and dull, over a soft thud of rock
	# (the old digital error beep was out of place, like the old clicks)
	bad = {f = ["impactGlass_light_000", "impactGlass_light_001", "impactGlass_light_002"], db = -12.0, pitch = 0.6, synth = true},
	rock = {f = ["impactMining_000", "impactMining_001", "impactMining_002", "impactMining_003"], db = -3.0},
	crack = {f = ["impactMining_001", "impactMining_003"], db = -2.0, step = 0.12},
	boom = {f = ["impactPunch_heavy_000", "impactPunch_heavy_001"], db = -2.0, pitch = 0.7, synth = true},
	special = {f = ["glass_002"], db = -4.0},
	coin = {f = ["chips-stack-1", "chips-stack-2", "chips-collide-1"], db = -6.0},
	# a step of building: a plank set down, two hammer knocks, a brass latch (sfx_cut.py; was a digital ding)
	build = {f = ["build_knock"], db = 0.0},
	# the end of a level, put together from the game's own stones and crystals (prototype/tools/sfx_cut.py):
	# won — a geode splits and its crystals ring out over the singing bowl; lost — rock comes down over a low hum
	# and a slow heavy bell
	win = {f = ["win_geode"], db = 0.0},
	lose = {f = ["lose_rockfall"], db = 0.0},
	# a find comes out: crystals ring up, more of them the rarer it is (reveal_<tier>, 0..4; sfx_cut.py)
	reveal_0 = {f = ["reveal_0"], db = 0.0},
	reveal_1 = {f = ["reveal_1"], db = 0.0},
	reveal_2 = {f = ["reveal_2"], db = 0.0},
	reveal_3 = {f = ["reveal_3"], db = 0.0},
	reveal_4 = {f = ["reveal_4"], db = 0.0},
	# Copper Mountain and its Mistress (OpenGameArt, CC0: rubberduck's breaking/falling and creature packs, JaggedStone's
	# magic spell sfx): a malachite crust and a nodule breaking, rock dropped on the board, her lizards, her hiss,
	# a new phase, the stone flower in bloom
	crust = {f = ["bfh1_glass_breaking_02", "bfh1_glass_breaking_05"], db = -8.0},
	nodule = {f = ["bfh1_rock_breaking_03", "bfh1_glass_hit_01", "bfh1_glass_hit_02"], db = -5.0, step = 0.08},
	rockfall = {f = ["bfh1_rock_falling_04", "bfh1_rock_falling_06", "bfh1_rock_falling_07", "bfh1_rock_falling_08"], db = -4.0},
	lizards = {f = ["bug_05", "bug_08", "bug_09", "bug_12", "bug_13"], db = -10.0},
	hiss = {f = ["breath_02", "weird_08", "weird_09"], db = -6.0},
	phase = {f = ["roar_04", "roar_05", "roar_06"], db = -4.0},
	bloom = {f = ["magical_1", "magical_5", "magical_6"], db = -5.0},
	# story scenes (StoryScene): knocking somewhere in the rock, far off; the mountain's breath rumbling under the boots
	knock = {f = ["impactMining_000", "impactMining_002"], db = -6.0, pitch = 0.55},
	rumble = {f = ["bfh1_rock_falling_04", "bfh1_rock_falling_07"], db = -2.0, pitch = 0.45},
	# the gold pan: gravel rattling round it
	pan = {f = ["bfh1_rock_falling_06", "bfh1_rock_falling_07"], db = -8.0, pitch = 1.5},
	# buttons and windows: a book set down, a page turned (Kenney RPG Audio) — the old digital clicks were out of place
	click = {f = ["bookPlace1", "bookPlace2", "bookPlace3"], db = -10.0},
	tab = {f = ["switch_002"], db = -8.0},
	open = {f = ["bookFlip1"], db = 1.0},
	# the resonator rings like a singing bowl (BigSoundBank #1109); gas gurgles over a muffled hiss (bubbles + steam, CC0)
	zap = {f = ["bowl_ping"], db = -8.0},
	gas = {f = ["gas_0", "gas_1", "gas_2"], db = -8.0},
	# the Kraken (Whalebone Cove): the sea's own recordings (amb/sea, a path with "/" is under assets/audio/) and the
	# creature roars taken deeper; "all" plays the takes together
	kr_roar = {f = ["roar_04", "roar_05", "roar_06"], db = -3.0, pitch = 0.62},
	kr_phase = {f = ["amb/sea/crash_0", "roar_05"], all = true, db = -2.0, pitch = 0.8},
	kr_rise = {f = ["amb/sea/crash_1", "amb/sea/crash_2"], db = -3.0, pitch = 0.85},
	kr_tentacle = {f = ["amb/sea/squelch"], db = -3.0, pitch = 0.8},
	kr_cut = {f = ["amb/sea/squelch"], db = -6.0, pitch = 1.35},
	kr_drag = {f = ["amb/sea/squelch", "amb/sea/bubble_0"], all = true, db = -4.0, pitch = 0.7},
	kr_ink = {f = ["gas_0", "gas_1", "gas_2"], db = -5.0, pitch = 0.6},
	kr_tide = {f = ["amb/sea/crash_0", "amb/sea/crash_1"], db = -7.0, pitch = 1.1},
	kr_maelstrom = {f = ["amb/sea/bubble_0", "amb/sea/bubble_1", "amb/sea/bubble_2"], db = -8.0, pitch = 0.55},
	kr_suck = {f = ["amb/sea/bubble_0", "amb/sea/squelch"], all = true, db = -5.0, pitch = 0.5},
	kr_eye = {f = ["weird_08", "weird_09"], db = -3.0, pitch = 0.6},
	kr_gulls = {f = ["amb/sea/gull_1", "amb/sea/gull_2", "amb/sea/gull_4"], all = true, db = -6.0},
	kr_drown = {f = ["amb/sea/deep", "amb/sea/bubble_0"], all = true, db = -2.0, pitch = 0.8},
	# Brontes (Fire Horizon): the mine's own forge recordings (amb/fire: his hammer, the anvil's ring, burning sulphur,
	# steam), the storm's thunder for his bolt, the creature roars taken low for a giant
	br_roar = {f = ["roar_04", "roar_05", "roar_06"], db = -3.0, pitch = 0.5},
	br_phase = {f = ["amb/fire/hammer_1", "roar_05"], all = true, db = -1.0, pitch = 0.6},
	br_hammer = {f = ["amb/fire/hammer_0", "amb/fire/hammer_2", "impactPunch_heavy_000"], all = true, db = 0.0, pitch = 0.9},
	br_clang = {f = ["amb/fire/ring"], db = -6.0, pitch = 1.25, step = 0.1},
	br_anvil = {f = ["amb/fire/ring", "impactMining_001"], all = true, db = -4.0, pitch = 0.8},
	br_bellows = {f = ["amb/fire/steam", "breath_02"], all = true, db = -5.0, pitch = 0.7},
	br_pour = {f = ["amb/fire/burn", "gas_1"], all = true, db = -5.0, pitch = 0.8},
	br_run = {f = ["gas_0", "gas_2"], db = -9.0, pitch = 0.7},
	br_take = {f = ["amb/fire/ring", "amb/fire/sparks"], all = true, db = -7.0, pitch = 0.6},
	br_bolt = {f = ["amb/sea/thunder_near_0", "amb/sea/thunder_near_1"], db = 0.0},
	br_daze = {f = ["amb/fire/ring", "magical_5"], all = true, db = -3.0, pitch = 0.55},
}
const MUSIC := {home = ["res://assets/audio/music/home.ogg"], level = ["res://assets/audio/music/level1.ogg", "res://assets/audio/music/level2.ogg"],
	# a mine's own: "<track>_<area>" wins over "<track>"
	# for now one theme per mine, at home and in its levels
	home_0 = ["res://assets/audio/music/home_adit.ogg"], level_0 = ["res://assets/audio/music/home_adit.ogg"],
	home_1 = ["res://assets/audio/music/home_copper.ogg"], level_1 = ["res://assets/audio/music/home_copper.ogg"],
	home_2 = ["res://assets/audio/music/home_cove.ogg"], level_2 = ["res://assets/audio/music/home_cove.ogg"],
	home_3 = ["res://assets/audio/music/home_fire.ogg"], level_3 = ["res://assets/audio/music/home_fire.ogg"],
	# a boss's own theme: "boss_<id>"
	boss_poloz = ["res://assets/audio/music/boss_poloz.mp3"],
	boss_mistress = ["res://assets/audio/music/boss_mistress.mp3"],
	boss_kraken = ["res://assets/audio/music/boss_kraken.ogg"]}
## where a Suno track's loop starts (s): its intro plays once (prototype/tools/music_loop.py finds the cut)
const LOOP_AT := {"res://assets/audio/music/home_adit.ogg": 11.7, "res://assets/audio/music/home_copper.ogg": 19.3, "res://assets/audio/music/home_cove.ogg": 48.25,
	"res://assets/audio/music/boss_kraken.ogg": 57.65, "res://assets/audio/music/home_fire.ogg": 49.35}
const MUSIC_DB := -14.0
## the home screen's ambience (MineAmb): far off and behind rock — muffled, a little cave reverb, well under the music
const AMB_BUS := "Amb"
const AMB_DB := -15.0

var _cache := {}
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _fade: Tween
var _cur := 0
var _track := ""
var _level_i := 0
var _click_at := -1.0

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
	if sfx_name == "reveal": sfx_name = "reveal_%d" % clampi(arg, 0, 4)
	# a press sounds as the book set down, even when it opens a window: the window's page turn is only for
	# windows that come up by themselves (a win, a loss, a find)
	var now := Time.get_ticks_msec() / 1000.0
	if sfx_name == "click": _click_at = now
	elif sfx_name == "open" and now - _click_at < 0.25: return
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
		_streams[f] = load(("res://assets/audio/" if "/" in f else SFX) + f + ".ogg")
	return _streams[f]

## background music for "home" or "level": cross-fades to it (levels alternate between their two loops)
func music(track: String) -> void:
	var own := "%s_%d" % [track, Save.area()]
	if MUSIC.has(own): track = own
	if track == _track and _music[_cur].playing:
		return
	_track = track
	var list: Array = MUSIC[track]
	var path: String = list[_level_i % list.size()]
	if track.begins_with("level"): _level_i += 1
	# the same theme on both screens plays on without a restart
	if _music[_cur].playing and _music[_cur].stream and _music[_cur].stream.resource_path == path:
		return
	var st: AudioStream = load(path)
	st.set("loop", true)   # Ogg and MP3 both loop
	st.set("loop_offset", LOOP_AT.get(path, 0.0))
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

## the music dies away to silence (a boss's theme as it falls); the next music() starts afresh
func music_fade(sec: float) -> void:
	var p := _music[_cur]
	_track = ""
	if _fade and _fade.is_valid(): _fade.kill()
	var tw := create_tween()
	_fade = tw
	# eased out: most of the drop comes late, the theme seems to sink rather than switch off
	tw.tween_property(p, "volume_db", -60.0, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.stop)

func _music_db() -> float:
	return -80.0 if Save.d.get("mute", false) else MUSIC_DB

## sound switched on or off
func apply_mute() -> void:
	_music[_cur].volume_db = _music_db()
	var b := AudioServer.get_bus_index(AMB_BUS)
	if b >= 0: AudioServer.set_bus_mute(b, Save.d.get("mute", false))

## the "Amb" bus, made on first use: low-pass + reverb, sent to Master
func amb_bus() -> void:
	if AudioServer.get_bus_index(AMB_BUS) >= 0: return
	AudioServer.add_bus()
	var b := AudioServer.bus_count - 1
	AudioServer.set_bus_name(b, AMB_BUS)
	AudioServer.set_bus_send(b, "Master")
	AudioServer.set_bus_volume_db(b, AMB_DB)
	AudioServer.set_bus_mute(b, Save.d.get("mute", false))
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 2200.0
	AudioServer.add_bus_effect(b, lp)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.7
	rv.damping = 0.6
	rv.spread = 0.8
	rv.dry = 0.8
	rv.wet = 0.3
	AudioServer.add_bus_effect(b, rv)

## one take of the pick striking rock (shared with the board's "rock")
func pick_stream() -> AudioStream:
	var takes: Array = SAMPLES.rock.f
	return _sample(takes[randi() % takes.size()])

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
			_tone(buf, 140, 0, 0.14, 0.05, "sine", 0.6)
			_noise(buf, 0.07, 450, 0.08, "low")
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
		"special":
			for i in 3: _tone(buf, [660, 880, 1320][i], i * 0.05, 0.18, 0.05, "triangle")
		"coin":
			_tone(buf, 1568, 0, 0.08, 0.06, "square")
			_tone(buf, 2093, 0.06, 0.12, 0.05, "square")
		"crack":
			_noise(buf, 0.18, 2600 + k * 500, 0.4, "high")
			_tone(buf, 300 - k * 40, 0, 0.08, 0.06, "square")
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
