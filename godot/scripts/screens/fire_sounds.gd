class_name FireSounds
extends RefCounted
## Fire Horizon's sounds (FireView), at the moments and places its picture shows them, through MineAmb's muffled bus;
## how far a place is from the middle of the screen takes it down (FireView._far). Files: assets/audio/amb/fire/
## (prototype/tools/amb_fire_rec.py cuts them from recordings; only the herald's cold wind is still amb_fire.py's synth),
## the bell and the engine's chuff borrowed from Copper Mountain's folder.
##   the giant's hammer far below at each blow of the forge's breath (louder the deeper the screen looks);
##   cicadas over the hot hill and the kilns' burning sulphur on the surface; the river of molten sulphur seething at
##   400 m; the chapel's bell, the winding engine's chuff, the donkey; the Cyclops' signs: sparks out of a crack, a jet
##   of steam, a rumble; the herald's cold wind; the forge gate's ring; the acid stream down the gorge, the drop falling
##   into its puddle at 50 m, the goat's bleat. Cicadas, the goat and the steam are nearly all highs: they go past the
##   bus's low-pass (MineAmb.hum/shot_clear), else it took them away.

const CICADA_DB := -20.0
const BURN_DB := -18.0
const RIVER_DB := -14.0
const STREAM_DB := -16.0

var _goat_at := 12.0
# the cicadas sing in spells: a chorus of 12-40 s, then a hush of 6-25 s; _cic eases 0..1 between them over a few seconds
var _cic := 1.0
var _cic_on := true
var _cic_until := randf_range(12.0, 40.0)

static func of(v: FireView) -> FireSounds:
	if not v.has_meta("fire_sounds"):
		v.set_meta("fire_sounds", FireSounds.new())
	return v.get_meta("fire_sounds")

## a crew member's stroke: the smith's hammer rings on the anvil, the mason's sledge on a wedge, picks on the ore
static func strike(a: MineAmb, who: String, db: float, pitch: float) -> void:
	if who.begins_with("forger") or who.begins_with("mason"):
		a.shot("copper/rivet_%d" % (randi() % 3), db - 6.0, pitch * (0.85 if who.begins_with("mason") else 1.0))
	else:
		a.shot("pick", db, pitch)

## the blow from below: heard everywhere, nearer the deeper the screen looks
static func hammer(v: FireView, k: float) -> void:
	var mid := v._seen.x * 0.5 + v._seen.y * 0.5
	var deep := clampf((mid - float(v.J.sky) - float(v.J.surf)) / (float(v.J.band) * 9.0), 0.0, 1.0)
	v.amb.shot("fire/hammer_%d" % (randi() % 3), -14.0 + 10.0 * deep + 4.0 * (k - 1.0), randf_range(0.92, 1.04))

static func bell(v: FireView, db: float) -> void:
	v.amb.shot("copper/bell", db - 4.0, randf_range(1.25, 1.32))

static func chuff(v: FireView, db: float) -> void:
	if db > -10.0:
		v.amb.shot("copper/chuff_%d" % (randi() % 3), db - 12.0, randf_range(1.05, 1.15))

static func donkey(v: FireView, db: float) -> void:
	if db > -10.0:
		# a bray is long: not more than one in 25 s, whatever the drawing does
		if v.t < float(v.get_meta("bray_at", -100.0)) + 25.0:
			return
		v.set_meta("bray_at", v.t)
		v.amb.shot("fire/donkey_%d" % (randi() % 2), db - 12.0, randf_range(0.96, 1.04))

static func sparks(v: FireView, db: float) -> void:
	v.amb.shot("fire/sparks", db - 6.0, randf_range(0.9, 1.1))

static func steam(v: FireView, db: float) -> void:
	v.amb.shot_clear("fire/steam", db - 10.0, randf_range(0.9, 1.05))

static func wind(v: FireView, db: float) -> void:
	v.amb.shot("fire/wind", db - 4.0, randf_range(0.95, 1.05))

static func rumble(v: FireView, db: float) -> void:
	v.amb.shot("fire/hammer_%d" % (randi() % 3), db - 6.0, 0.6)

static func ring(v: FireView, db: float) -> void:
	v.amb.shot("fire/ring", db - 6.0, randf_range(0.97, 1.0))

func tick(v: FireView) -> void:
	var a := v.amb
	var J := v.J
	var sp := v._shown_places
	var sky := float(J.sky)
	# cicadas over the hot hill (a day without them only while the mine is a ruin is still a day), in spells of song
	# and hush; the dying out and the starting up take a few seconds, like a real chorus
	if v.t > _cic_until:
		_cic_on = not _cic_on
		_cic_until = v.t + (randf_range(12.0, 40.0) if _cic_on else randf_range(6.0, 25.0))
	_cic = move_toward(_cic, 1.0 if _cic_on else 0.0, v.get_process_delta_time() / (2.0 if _cic_on else 3.5))
	a.hum("fire/cicadas", CICADA_DB + v._far(sky + 700.0) + linear_to_db(maxf(_cic, 0.001)), true)
	# the acid stream down the gorge (and on down the section once the stair is built)
	if J.has("stream"):
		var sa: Array = J.stream.at
		a.hum("fire/stream", STREAM_DB + v._far(float(sa[1]) + 300.0))
	# the goat on the bridge, now and then
	if v.t > _goat_at:
		_goat_at = v.t + randf_range(18.0, 40.0)
		for g in J.life:
			if String(g.name) == "goat" and v._far(sky + float(g.y)) > -10.0:
				a.shot_clear("fire/goat_%d" % (randi() % 2), -22.0 + v._far(sky + float(g.y)), randf_range(0.95, 1.08))
	_drip(v, a)
	var kd: Array = J.kilns.doors[0]
	a.hum("fire/burn", BURN_DB + v._far(float(kd[1])) if int(sp.get("kiln", 0)) >= 2 else -80.0)
	if J.has("river"):
		var k := int(J.river.d) - 1
		var y := v.band_y(k) + 400.0
		a.hum("fire/river", RIVER_DB + v._far(y) if k <= v.open and v._far(y) > -12.0 else -80.0)

## the drop at 50 m falls into its puddle: in time with FireView._drip (it swells, falls, splashes, waits)
func _drip(v: FireView, a: MineAmb) -> void:
	if not v.J.has("drip"):
		return
	var dp: Dictionary = v.J.drip
	var k := int(dp.d) - 1
	if k > v.open:
		return
	var y := v.band_y(k)
	var fall := sqrt(2.0 * (float(dp.floor) - float(dp.beam)) / FireView.DRIP_G)
	if v._passed("drip_hit", v.t, FireView.DRIP_GROW + fall + 0.9, FireView.DRIP_GROW + fall):
		var f := v._far(y + float(dp.floor))
		if f > -10.0:
			a.shot("fire/drip", -10.0 + f, randf_range(0.9, 1.1))
