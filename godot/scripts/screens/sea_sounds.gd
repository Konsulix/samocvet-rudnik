class_name SeaSounds
extends RefCounted
## Whalebone Cove's sounds (SeaView), at the moments and places its picture shows them, through MineAmb's muffled bus;
## how far a place is from the middle of the screen takes it down (SeaView._far). Files: assets/audio/amb/sea/
## (prototype/tools/amb_sea.py synthesizes the Kraken's groan and squelch; amb_sea_rec.py cuts the recorded sea, gulls,
## foghorn, harbour, the sea in section and the tryworks), the bell and the creaks borrowed from Copper Mountain's folder.
##   the surf (a loop under everything near the surface) and a crash for each big wave that breaks on the rocks;
##   gulls now and then over the cliff; the chapel's bell (struck in SeaView._chapel); the man engine's creak at the top
##   of each stroke (SeaView._man_engine); the Kraken's signs: a groan from the deep, a wet squelch at a crack;
##   the lighthouse's foghorn now and then, water slapping the boat at the landing, the tryworks' fire and seething
##   oil, the sea in section heard as through water, the diver's air bubbling up.

const SURF_DB := -14.0
const LAP_DB := -12.0
const TRY_DB := -20.0
const UNDER_DB := -14.0

var _gull_at := 6.0
var _horn_at := 14.0
var _bubble_at := 3.0

static func of(v: SeaView) -> SeaSounds:
	if not v.has_meta("sea_sounds"):
		v.set_meta("sea_sounds", SeaSounds.new())
	return v.get_meta("sea_sounds")

## a crew member's stroke: the caulker's mallet and the smith's spanner ring higher than a sledge on shale
static func strike(a: MineAmb, who: String, db: float, pitch: float) -> void:
	if who.begins_with("caulker") or who.begins_with("fossil"):
		a.shot("pick", db - 3.0, pitch * 1.3)
	elif who.begins_with("smith"):
		a.shot("copper/rivet_%d" % (randi() % 3), db - 8.0, pitch * 0.9)
	else:
		a.shot("pick", db, pitch)

static func bell(a: MineAmb, db: float) -> void:
	a.shot("copper/bell", db - 2.0, randf_range(1.05, 1.12))

static func crash(a: MineAmb, db: float) -> void:
	if db > -14.0:
		a.shot("sea/crash_%d" % (randi() % 3), db - 6.0, randf_range(0.9, 1.08))

static func deep(a: MineAmb, db: float) -> void:
	a.shot("sea/deep", db - 4.0, randf_range(0.9, 1.0))

static func squelch(a: MineAmb, db: float) -> void:
	a.shot("sea/squelch", db - 6.0, randf_range(0.9, 1.1))

func tick(v: SeaView) -> void:
	var a := v.amb
	var J := v.J
	var t := v.t
	var sea_y := float(J.sky) + float(J.surf)
	a.hum("sea/surf", SURF_DB + v._far(sea_y - 200.0))
	if t > _gull_at:
		_gull_at = t + randf_range(9.0, 20.0)
		var db := v._far(float(J.sky) + 500.0)
		if db > -10.0:
			# near cries mostly, now and then a far one from over the harbour
			var g := randi() % 7
			a.shot("sea/gull_%d" % g, (-16.0 if g < 5 else -10.0) + db, randf_range(0.92, 1.08))
	var sp := v._shown_places
	# the boat moored at the landing, the try-pots seething under their smoke, the sea in section as heard through it
	var ld: Array = J.places.landing
	a.hum("sea/lap", LAP_DB + v._far(float(ld[1]) + 150.0) if int(sp.get("landing", 0)) >= 3 else -80.0)
	var td: Array = J.tryworks.door
	a.hum("sea/tryworks", TRY_DB + v._far(float(td[1])) if int(sp.get("tryworks", 0)) >= 2 else -80.0)
	var mid := sea_y + float(J.sea) * 0.5
	a.hum("sea/under", UNDER_DB + v._far(mid) if v._far(mid) > -12.0 else -80.0)
	# the lighthouse sounds its foghorn now and then: one long low blast out to sea
	if int(sp.get("lighthouse", 0)) >= 3 and t > _horn_at:
		_horn_at = t + randf_range(35.0, 60.0)
		var ln: Array = J.lighthouse.lantern
		a.shot("sea/horn", -18.0 + v._far(float(ln[1])), randf_range(0.97, 1.0))
	# the diver's air: a burst of bubbles every few seconds, heard only with the sea in section on screen
	if int(sp.get("crane", 0)) >= 3 and t > _bubble_at:
		_bubble_at = t + randf_range(2.5, 4.5)
		var dv: Array = J.sea_life.diver
		var f := v._far(sea_y + float(dv[1]))
		if f > -10.0:
			a.shot("sea/bubble_%d" % (randi() % 3), -20.0 + f, randf_range(0.85, 1.1))
