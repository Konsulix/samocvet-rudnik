class_name CopperSounds
extends RefCounted
## Copper Mountain's sounds (CopperView), at the moments and places its picture shows them, through MineAmb's muffled
## bus; how far a place is from the middle of the screen takes it down (CopperView._far). Files: assets/audio/amb/copper/
## (prototype/tools/amb_copper.py). Kept out of mine_view_copper.gd: the view calls tick() from its _sounds.
##   the falls of the mill race (a loop, while the wheel turns) and the wheel's creaks, twice a turn;
##   the blast furnace's roar (a loop, once lit); the hoisting engine's steam, a chuff each turn of the flywheel;
##   the incline's cart rolling up and down; the tower's bell (struck in CopperView._sky) and the crows off the
##   belfry; now and then a crow over the ridge, the smelter's cat, the pigeons cooing on the incline's roof, the
##   groom's pony down at 300 m snorting, stamping, now and then a neigh; the Mistress's signs: the lizard's scurry and
##   hiss, a breath of her in the waterfall, the hot crack's steam and rumble, the hall of the flower's shimmer.

const FALLS_DB := -16.0
const FURNACE_DB := -19.0
const TOWER_CYCLE := 27.0   # as CopperView._sky: the candle, the bell, the birds

var _heard := {}          # event -> the start time it was sounded for
var _crow_at := 8.0       # next lone crow over the ridge
var _cat_at := 25.0
var _hall_at := 4.0
var _coo_at := 3.0
var _pony_at := 6.0

static func of(v: CopperView) -> CopperSounds:
	if not v.has_meta("copper_sounds"):
		v.set_meta("copper_sounds", CopperSounds.new())
	return v.get_meta("copper_sounds")

## a crew member's stroke: the riveter's hammer rings on iron, the cutter's chisel is higher than a pick
static func strike(a: MineAmb, who: String, db: float, pitch: float) -> void:
	if who.begins_with("riveter"):
		a.shot("copper/rivet_%d" % (randi() % 3), db - 8.0, pitch)
	elif who.begins_with("cutter"):
		a.shot("pick", db - 2.0, pitch * 1.35)
	else:
		a.shot("pick", db, pitch)

## the tower's bell, struck far off on the hill (CopperView._sky, at each of its three strikes)
static func bell(a: MineAmb, db: float) -> void:
	a.shot("copper/bell", db - 4.0, randf_range(0.97, 1.03))

func tick(v: CopperView) -> void:
	var a := v.amb
	var J := v.J
	var t := v.t
	var sp := v._shown_places
	var sky := float(J.sky)
	var wheel_on := int(sp.get("wheel", 0)) >= 3
	var wc: Array = J.wheel.c
	var mo: Array = J.smelter.mouth
	a.hum("copper/falls", FALLS_DB + v._far(float(wc[1])) if wheel_on else -80.0)
	a.hum("copper/furnace", FURNACE_DB + v._far(float(mo[1]) + float(mo[3]) / 2) if int(sp.get("smelter", 0)) >= 2 else -80.0)
	if wheel_on and v._passed("cu_creak", t * absf(float(J.wheel.rate)) * 2.0, 1.0, 0.3):
		a.shot("copper/creak_%d" % (randi() % 3), -18.0 + v._far(float(wc[1])), randf_range(0.85, 1.05))
	if int(sp.get("hoist", 0)) >= 3:
		var fw: Dictionary = J.flywheel
		var fc: Array = fw.c
		# the puff of steam leaves the engine at the start of each turn (CopperView._surface_live)
		if v._passed("cu_chuff", t * float(fw.rate), 1.0):
			a.shot("copper/chuff_%d" % (randi() % 3), -22.0 + v._far(float(fc[1])), randf_range(0.9, 1.1))
	if int(sp.get("incline", 0)) >= 3:
		# the cart sets off up at 0 and down at 8 of its 16 s (CopperView._incline_cart); a 4 s take slowed to the 6 s run
		var mid := sky + 700.0
		if J.incline.has("path"):
			var pa: Array = J.incline.path
			mid = (float(pa[0][1]) + float(pa[pa.size() - 1][1])) / 2
		if v._passed("cu_inc_up", t, 16.0) or v._passed("cu_inc_dn", t, 16.0, 8.0):
			a.shot("cart_%d" % (randi() % 2), -6.0 + v._far(mid), 0.67)
	_birds(v, a, t, sky)
	if int(sp.get("incline", 0)) >= 3 and t >= _coo_at:
		# the two pigeons on the roof by the winch house (mine.json life: pigeon12)
		_coo_at = t + randf_range(7.0, 18.0)
		a.shot("copper/coo_%d" % (randi() % 3), -20.0 + v._far(sky + 310.0), randf_range(0.95, 1.08))
	_pony(v, a, t)
	if int(sp.get("smelter", 0)) >= 3 and t >= _cat_at:
		_cat_at = t + randf_range(45.0, 90.0)
		a.shot("copper/meow", -20.0 + v._far(sky + 1185.0), randf_range(0.9, 1.15))
	_events(v, a, t)

## the crows: three or four start up cawing from the belfry at the bell's first strike, wings and all; between whiles
## one calls over the ridge
func _birds(v: CopperView, a: MineAmb, t: float, sky: float) -> void:
	if not v.J.has("tower"):
		return
	var tw: Dictionary = v.J.tower
	var by := float(tw.belfry[1])
	var wins: Array = tw.windows
	var bs := fmod(t + 4.0, TOWER_CYCLE) - wins.size() * 2.2
	if v._passed("cu_birds", bs, 100.0, 0.15):
		a.shot("copper/wings_%d" % (randi() % 3), -12.0 + v._far(by))
		var n := 3 + randi() % 2
		for i in n:
			var at := 0.3 + i * randf_range(0.35, 0.6)
			v.get_tree().create_timer(at).timeout.connect(func(): a.shot("copper/crow_%d" % (randi() % 3), -16.0 - i * 1.5 + v._far(by), randf_range(0.95, 1.05)))
	if t >= _crow_at:
		_crow_at = t + randf_range(16.0, 34.0)
		var calls := 1 + randi() % 3
		for i in calls:
			v.get_tree().create_timer(i * randf_range(0.45, 0.7)).timeout.connect(func(): a.shot("copper/crow_%d" % (randi() % 3), -22.0 + v._far(sky + 250.0), randf_range(0.9, 1.0)))

## the groom's pony (the crew of the depth that has a pet: mine.json crews[].pet), once its people live there
func _pony(v: CopperView, a: MineAmb, t: float) -> void:
	if t < _pony_at:
		return
	_pony_at = t + randf_range(8.0, 16.0)
	for b in v._bands:
		var cr: Dictionary = v.J.crews.get(str(int(b.d)), {})
		if not cr.has("pet") or not b.lived:
			continue
		var y := float(b.y) + v.floor_of(int(b.d))
		var f := v._far(y)
		var r := randf()
		if r < 0.2:
			a.shot("copper/neigh_%d" % (randi() % 3), -24.0 + f, randf_range(0.95, 1.05))
		elif r < 0.6:
			a.shot("copper/snort_%d" % (randi() % 2), -20.0 + f, randf_range(0.9, 1.1))
		else:
			for j in 2:
				v.get_tree().create_timer(j * randf_range(0.3, 0.5)).timeout.connect(func(): a.shot("copper/hoof_%d" % (randi() % 2), -18.0 + f, randf_range(0.9, 1.1)))

## the Mistress's signs, sounded once as each starts (CopperView._tick_events / _events_live)
func _events(v: CopperView, a: MineAmb, t: float) -> void:
	for ev in v._events.keys():
		if ev == "lizard_at":
			continue
		var at := float(v._events[ev])
		if at < 0.0 or is_equal_approx(float(_heard.get(ev, -1.0)), at):
			continue
		_heard[ev] = at
		match ev:
			"lizard":
				# scurries at her three darts, a hiss as she slips into the crack
				var cr: Dictionary = v._events.get("lizard_at", {})
				var y := v.band_y(int(cr.get("d", 1)) - 1) + float(cr.get("y", 0))
				for j in 3:
					v.get_tree().create_timer(j * 1.1).timeout.connect(func(): a.shot("lizards", -10.0 + v._far(y), randf_range(1.0, 1.2)))
				v.get_tree().create_timer(4.1).timeout.connect(func(): a.shot("hiss", -18.0 + v._far(y), 1.2))
			"reflection":
				if not v.J.water.has("reflection"):
					continue
				var rf: Array = v.J.water.reflection
				a.shot("bloom", -16.0 + v._far(float(rf[1])), 0.6)
			"hotcrack":
				if not v.J.has("hotcrack"):
					continue
				var hc: Dictionary = v.J.hotcrack
				var y := v.band_y(int(hc.d) - 1) + float(hc.y)
				a.shot("rockfall", -14.0 + v._far(y), 0.5)
				v.get_tree().create_timer(0.8).timeout.connect(func(): a.shot("copper/chuff_%d" % (randi() % 3), -10.0 + v._far(y), 0.7))
				v.get_tree().create_timer(2.6).timeout.connect(func(): a.shot("copper/chuff_%d" % (randi() % 3), -12.0 + v._far(y), 0.65))
	# the hall of the stone flower, open: a faint shimmer now and then
	if String(v._shown_bands.get(8, "")) == "done" and t >= _hall_at:
		_hall_at = t + randf_range(7.0, 12.0)
		a.shot("bloom", -22.0 + v._far(v.band_y(8) + 300.0), randf_range(0.7, 0.85))
