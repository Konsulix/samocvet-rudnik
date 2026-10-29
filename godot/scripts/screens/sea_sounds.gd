class_name SeaSounds
extends RefCounted
## Whalebone Cove's sounds (SeaView), at the moments and places its picture shows them, through MineAmb's muffled bus;
## how far a place is from the middle of the screen takes it down (SeaView._far). Files: assets/audio/amb/sea/
## (prototype/tools/amb_sea.py), the bell and the creaks borrowed from Copper Mountain's folder.
##   the surf (a loop under everything near the surface) and a crash for each big wave that breaks on the rocks;
##   gulls now and then over the cliff; the chapel's bell (struck in SeaView._chapel); the man engine's creak at the top
##   of each stroke (SeaView._man_engine); the Kraken's signs: a groan from the deep, a wet squelch at a crack.

const SURF_DB := -14.0

var _gull_at := 6.0

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
			a.shot("sea/gull_%d" % (randi() % 3), -16.0 + db, randf_range(0.92, 1.08))
