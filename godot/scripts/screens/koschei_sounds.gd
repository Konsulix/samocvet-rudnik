class_name KoscheiSounds
extends RefCounted
## Deathless Barrow's sounds (BarrowView), at the moments and places its picture shows them, through MineAmb's muffled
## bus; how far a place is from the middle of the screen takes it down (BarrowView._far). Own files in
## assets/audio/amb/barrow/ (prototype/tools/amb_barrow.py: the gusli, chains, a hare, the egg's heart, a laugh) and
## other mines' files used as they are:
##   the steppe wind always, a gust with each whirlwind (Proval's); frogs in the bog at dusk and night (Spider Hollow's);
##   the whim's creak at each turn and the horse's hooves and snorts (Copper Mountain's); ravens over the oak; the blind
##   singer's gusli now and then; the crews' axe, hammer and chisel; Koschei's signs: the chains, a hare, wings off the
##   lake, the egg's heart, a squelch in the bog, a far gallop, a drone and a laugh from under the ground.

const WIND_DB := -16.0
const FROG_DB := -22.0

var _gusli_at := 8.0
var _raven_at := 5.0
var _snort_at := 12.0
var _turn := -1

static func of(v: BarrowView) -> KoscheiSounds:
	if not v.has_meta("koschei_sounds"):
		v.set_meta("koschei_sounds", KoscheiSounds.new())
	return v.get_meta("koschei_sounds")

## a crew member's stroke: an axe in a root, a hammer on a chisel, otherwise the pick
static func strike(v: BarrowView, who: String, db: float) -> void:
	if who.begins_with("axe"):
		v.amb.shot("pick", db - 2.0, 0.7)
	elif who.begins_with("lock"):
		v.amb.shot("web/chisel_%d" % (randi() % 3), db - 6.0, randf_range(0.85, 0.95))
	else:
		v.amb.shot("pick", db, 1.0)

static func gust(v: BarrowView, db: float) -> void:
	v.amb.shot("ice/gust_%d" % (randi() % 3), db - 6.0, randf_range(0.85, 1.0))

static func chain(v: BarrowView, db: float) -> void:
	v.amb.shot_clear("barrow/chain_%d" % (randi() % 3), db - 6.0, randf_range(0.9, 1.05))

## the flock: several caws, one after another, and wings
static func caw(v: BarrowView, db: float) -> void:
	for i in 4:
		v.get_tree().create_timer(0.3 + i * 0.7 + randf() * 0.3).timeout.connect(func():
			if is_instance_valid(v): v.amb.shot("copper/crow_%d" % (randi() % 3), db - 4.0, randf_range(0.75, 0.9)))
	v.amb.shot("copper/wings_%d" % (randi() % 3), db - 4.0, 0.9)

static func scurry(v: BarrowView, db: float) -> void:
	v.amb.shot("barrow/scurry", db - 6.0, randf_range(0.95, 1.1))

static func wings(v: BarrowView, db: float) -> void:
	v.amb.shot("copper/wings_%d" % (randi() % 3), db - 6.0, 1.1)

static func heart(v: BarrowView, db: float) -> void:
	v.amb.shot("barrow/heart", db - 2.0, 1.0)
	v.get_tree().create_timer(1.1).timeout.connect(func(): if is_instance_valid(v): v.amb.shot("barrow/heart", db - 6.0, 0.98))

static func squelch(v: BarrowView, db: float) -> void:
	v.amb.shot("sea/squelch", db - 8.0, 0.8)

static func gallop(v: BarrowView, db: float) -> void:
	v.amb.shot("copper/hoof_%d" % (randi() % 2), db - 10.0, 1.3)

static func drone(v: BarrowView, db: float) -> void:
	v.amb.shot("web/drone", db - 2.0, 0.85)

static func groan(v: BarrowView, db: float) -> void:
	v.amb.shot("barrow/laugh", db - 4.0, 0.9)
	v.amb.shot("web/groan", db - 8.0, 0.8)

func tick(v: BarrowView) -> void:
	var a := v.amb
	var J := v.J
	var sp := v._shown_places
	var sky := float(J.sky)
	var nt := v._night()
	var top := v._far(sky + 900.0)
	a.hum("ice/wind", WIND_DB + top + 8.0 * v._wind())
	a.hum("web/frogs", FROG_DB + v._far(sky + 1100.0) - 8.0 * (1.0 - nt))
	# the whim creaks each half turn while it goes; the horse snorts now and then
	if J.has("gin") and int(sp.get("gin", 0)) >= 3:
		var gy := float((J.gin.c as Array)[1])
		var c := int(v._gin_a / PI)
		if c != _turn:
			if _turn >= 0 and absf(v._gin_v) > 0.1: a.shot("copper/creak_%d" % (randi() % 3), -18.0 + v._far(gy), 0.7)
			_turn = c
		if v.t > _snort_at:
			_snort_at = v.t + randf_range(14.0, 26.0)
			a.shot("copper/snort_%d" % (randi() % 2), -14.0 + v._far(gy), 1.0)
	# ravens over the oak
	if v.t > _raven_at:
		_raven_at = v.t + randf_range(9.0, 18.0)
		a.shot("copper/crow_%d" % (randi() % 3), -14.0 + v._far(sky + 200.0), randf_range(0.8, 0.9))
	# the blind singer's gusli: a phrase now and then
	if v.t > _gusli_at:
		_gusli_at = v.t + randf_range(16.0, 28.0)
		a.shot_clear("barrow/gusli_%d" % (randi() % 4), -10.0 + v.guide_db(), 1.0)
