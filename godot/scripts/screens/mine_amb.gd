class_name MineAmb
extends Node
## The home screen's quiet soundscape, in step with what the MineScene draws: the cave breathing under
## everything, crickets on the surface, the cage winch when the headframe runs, the cart rolling in the
## chosen gallery and picks knocking in the open ones. All of it goes through Sfx's muffled "Amb" bus.

const AMB := "res://assets/audio/amb/"
## level of each layer on the bus (dB)
const DB := {cave = -6.0, crickets = -16.0, winch = -12.0, cart = -9.0, pick = -14.0}

var scene: MineScene
var _cave: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}
var _cage_ph := 0.0
var _cart_ph := 0.0
var _pick_at := 2.5
var _hits: Array = []   # [time, depth] of picks still to strike

func _init(s: MineScene) -> void:
	scene = s

func _ready() -> void:
	Sfx.amb_bus()
	_cave = _loop("cave")
	if not scene.fire:
		_crickets = _loop("crickets")
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = Sfx.AMB_BUS
		add_child(p)
		_pool.append(p)
	_cage_ph = _phase(9.0)
	_cart_ph = _phase(10.0)

func _loop(n: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = Sfx.AMB_BUS
	var st: AudioStream = _stream(n)
	st.set("loop", true)
	p.stream = st
	p.volume_db = -50.0
	add_child(p)
	# a random place in the loop, faded in, so coming home never starts on the same drip
	p.play(randf() * st.get_length() * 0.8)
	create_tween().tween_property(p, "volume_db", float(DB[n]), 2.5)
	return p

func _stream(n: String) -> AudioStream:
	if not _streams.has(n):
		_streams[n] = load(AMB + n + ".ogg")
	return _streams[n]

func _phase(dur: float) -> float:
	return fposmod(scene.t, dur) / dur

func _shot(st: AudioStream, db: float, pitch := 1.0) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.play()

func _process(dt: float) -> void:
	var t := scene.t
	# the cage goes down on 0 and up on 0.5 of its 9 s cycle (MineScene._draw_live)
	if scene.has("headframe"):
		var ph := _phase(9.0)
		if _crossed(_cage_ph, ph, 0.0) or _crossed(_cage_ph, ph, 0.5):
			_shot(_stream("winch_%d" % (randi() % 2)), DB.winch)
		_cage_ph = ph
	# the cart sets off on 0 and comes back on 0.5 of its 10 s cycle
	var cph := _phase(10.0)
	if _crossed(_cart_ph, cph, 0.0) or _crossed(_cart_ph, cph, 0.5):
		_shot(_stream("cart_%d" % (randi() % 2)), DB.cart - scene.d_sel * 1.5, 1.0 - scene.d_sel * 0.03)
	_cart_ph = cph
	# now and then a miner in an open gallery swings a few times; deeper ones sound farther off
	if t >= _pick_at:
		_pick_at = t + randf_range(3.0, 8.0)
		var k := randi() % (scene.d_open + 1)
		var n := 2 + randi() % 3
		var gap := randf_range(0.5, 0.75)
		for i in n:
			_hits.append([t + i * gap * randf_range(0.9, 1.1), k])
	var i := 0
	while i < _hits.size():
		var h: Array = _hits[i]
		if t >= float(h[0]):
			var k: int = h[1]
			_shot(Sfx.pick_stream(), DB.pick - k * 2.5, 0.85 - k * 0.03)
			_hits.remove_at(i)
		else:
			i += 1

## did the phase pass mark m (0..1) since last frame, wrapping at 1
static func _crossed(a: float, b: float, m: float) -> bool:
	if b >= a: return a < m and m <= b
	return m > a or m <= b
