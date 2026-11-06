class_name WebSounds
extends RefCounted
## Spider Hollow's sounds (WebView), at the moments and places its picture shows them, through MineAmb's muffled bus; how
## far a place is from the middle of the screen takes it down (WebView._far). Files: assets/audio/amb/web/
## (prototype/tools/amb_web.py, synthesized) and Copper Mountain's waterfall, furnace and wheel creak:
##   the rain swelling with each shower; the evening cicadas (higurashi) by day, frogs at night; the waterfall and the
##   wheel's creak once it turns, the smelter's furnace; the bamboo deer-scarer knocking now and then; the shrine's bell;
##   the crews' chisel, bellows and the nun's bell; the spider: small legs skittering, a low drone from below (its eyes),
##   the monk's staff rings, the lair's rope groaning.

const RAIN_DB := -10.0
const CICADA_DB := -24.0
const FROG_DB := -20.0
const FALLS_DB := -18.0
const FURNACE_DB := -20.0

var _shishi_at := 6.0
var _bell_at := 25.0
var _creak := -1

static func of(v: WebView) -> WebSounds:
	if not v.has_meta("web_sounds"):
		v.set_meta("web_sounds", WebSounds.new())
	return v.get_meta("web_sounds")

## a crew member's stroke: the chisel on rock, the bellows' breath, the nun's little bell
static func strike(v: WebView, who: String, db: float) -> void:
	if who.begins_with("chisel"):
		v.amb.shot("web/chisel_%d" % (randi() % 3), db - 6.0, randf_range(0.95, 1.05))
	elif who.begins_with("bellows"):
		v.amb.shot("web/bellows", db - 8.0, randf_range(0.9, 1.05))
	elif who.begins_with("nun"):
		v.amb.shot_clear("web/rin", db - 16.0, 1.0)
	else:
		v.amb.shot("pick", db, 1.0)

static func skitter(v: WebView, db: float) -> void:
	v.amb.shot_clear("web/skitter", db - 18.0, randf_range(0.9, 1.1))

static func drone(v: WebView, db: float) -> void:
	v.amb.shot("web/drone", db - 2.0, randf_range(0.95, 1.02))

static func jingle(v: WebView, db: float) -> void:
	v.amb.shot_clear("web/jingle", db - 16.0, randf_range(0.95, 1.05))

## the leg's claw on the planks
static func tap(v: WebView, db: float) -> void:
	v.amb.shot("web/chisel_%d" % (randi() % 3), db - 14.0, 0.45)

static func groan(v: WebView, db: float) -> void:
	v.amb.shot("web/groan", db - 2.0, 1.0)

func tick(v: WebView) -> void:
	var a := v.amb
	var J := v.J
	var sp := v._shown_places
	var sky := float(J.sky)
	var rn := v._rain(v.t - v._rain_at) * v._rain_k
	var nt := v._night()
	# the shower: loud where the sky is on the screen, softer down in the rock
	var top := v._far(sky + 900.0)
	a.hum("web/rain", RAIN_DB + 26.0 * log(maxf(rn, 0.05)) / log(10.0) * 0.5 + top * 0.5 if rn > 0.01 else -80.0)
	a.hum("web/higurashi", CICADA_DB + top - 20.0 * nt - 10.0 * rn, true)
	a.hum("web/frogs", FROG_DB + top - 20.0 * (1.0 - nt) - 6.0 * rn)
	var wheel_on := int(sp.get("wheel", 0)) >= 3
	if J.has("wheel"):
		var wy := float((J.wheel.at as Array)[1])
		a.hum("copper/falls", FALLS_DB + v._far(wy) + 4.0 * rn)
		# the wheel creaks twice a turn
		if wheel_on:
			var c := int(v._wheel_a / PI)
			if c != _creak:
				if _creak >= 0: a.shot("copper/creak_%d" % (randi() % 3), -16.0 + v._far(wy), 0.8)
				_creak = c
	if J.has("furnace"):
		var fy := float((J.furnace as Array)[1])
		a.hum("copper/furnace", FURNACE_DB + v._far(fy) if int(sp.get("smelter", 0)) >= 3 else -80.0)
	# the bamboo deer-scarer by the houses tips over now and then; the shrine's bell, rarely
	if v.t > _shishi_at:
		_shishi_at = v.t + randf_range(9.0, 15.0)
		if int(sp.get("houses", 0)) >= 2:
			a.shot("web/shishi", -12.0 + v._far(sky + 1200.0), randf_range(0.97, 1.03))
	if v.t > _bell_at:
		_bell_at = v.t + randf_range(45.0, 70.0)
		if int(sp.get("shrine", 0)) >= 3:
			a.shot("web/bell", -8.0 + v._far(sky + 300.0), 1.0)
