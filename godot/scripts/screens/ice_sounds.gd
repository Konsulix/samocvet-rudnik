class_name IceSounds
extends RefCounted
## Proval's sounds (IceView), at the moments and places its picture shows them, through MineAmb's muffled bus; how far a
## place is from the middle of the screen takes it down (IceView._far). Files: assets/audio/amb/ice/
## (prototype/tools/amb_proval.py: public-domain and CC0 recordings from Wikimedia Commons, a little synthesis):
##   the polar wind over everything, a gust of the blizzard at each of the view's gusts; the sled dogs howling; the
##   culture palace's piano through its walls once it is rebuilt, the old man's bayan by the barracks; the generator's hum
##   at the power station; the kibble's winch (Old Adit's) as it sets off; ice cracking (the frozen dwarf, the funnel
##   shaking), the heart's double beat from far below, the dwarven gate's groan; the watchman's flare.

const WIND_DB := -14.0
const PIANO_DB := -16.0
const BAYAN_DB := -18.0
const HUM_DB := -20.0

var _kib_from := -1.0

static func of(v: IceView) -> IceSounds:
	if not v.has_meta("ice_sounds"):
		v.set_meta("ice_sounds", IceSounds.new())
	return v.get_meta("ice_sounds")

## a crew member's stroke: picks, the mallet and the sledge on rock and timber, the crowbar and the ice axe on ice
static func strike(a: MineAmb, who: String, db: float, pitch: float) -> void:
	if who.begins_with("ice") or who.begins_with("axe"):
		a.shot("ice/crack_%d" % (randi() % 3), db - 8.0, pitch * 1.3)
		a.shot("pick", db - 4.0, pitch * 1.1)
	else:
		a.shot("pick", db, pitch)

static func gust(v: IceView, k: float) -> void:
	v.amb.shot("ice/gust_%d" % (randi() % 3), -12.0 + 6.0 * (k - 1.0), randf_range(0.92, 1.06))

static func howl(v: IceView, db: float) -> void:
	if db > -10.0 and v.t > float(v.get_meta("howl_at", -100.0)) + 20.0:
		v.set_meta("howl_at", v.t)
		v.amb.shot("ice/howl_%d" % (randi() % 2), db - 12.0, randf_range(0.95, 1.05))

static func crack(v: IceView, db: float) -> void:
	v.amb.shot("ice/crack_%d" % (randi() % 3), db - 6.0, randf_range(0.85, 1.05))

static func heart(v: IceView, db: float) -> void:
	v.amb.shot("ice/heart", db - 4.0, 1.0)

static func gate(v: IceView, db: float) -> void:
	v.amb.shot("ice/gate", db - 4.0, 1.0)

static func flare(v: IceView, db: float) -> void:
	v.amb.shot_clear("fire/sparks", db - 12.0, 1.4)

## a sign of the four waking in the funnel's wall: a crack of ice under it, and the Smith's handprint hisses
static func sign(v: IceView, kind: String, db: float) -> void:
	crack(v, db - 4.0)
	if kind == "hand":
		v.amb.shot_clear("fire/steam", db - 16.0, 0.9)

func tick(v: IceView) -> void:
	var a := v.amb
	var J := v.J
	var sp := v._shown_places
	var sky := float(J.sky)
	a.hum("ice/wind", WIND_DB + 0.5 * v._far(sky + 700.0))
	if J.has("palace"):
		var pp: Array = J.palace.windows[0]
		a.hum("ice/piano", PIANO_DB + v._far(float(pp[1])) if int(sp.get("palace", 0)) >= 3 else -80.0)
	for l in J.life:
		if String(l.name) == "accordion24":
			var on := int(sp.get(String(l.get("place", "")), 3)) >= int(l.get("from", 3))
			a.hum("ice/accordion", BAYAN_DB + v._far(sky + float(l.y)) if on else -80.0)
	if J.has("power"):
		var pw: Array = J.power.windows[0]
		a.hum("ice/hum", HUM_DB + v._far(float(pw[1])) if int(sp.get("power", 0)) >= 3 else -80.0)
	# the kibble's winch as it sets off down and up
	if int(sp.get("gantry", 0)) >= 3 and v._kib_from != _kib_from:
		_kib_from = v._kib_from
		a.shot("winch_%d" % (randi() % 2), -8.0 + v._far(float(J.gantry.cable[1])), 0.85)
