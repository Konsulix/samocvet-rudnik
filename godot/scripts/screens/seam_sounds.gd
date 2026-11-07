class_name SeamSounds
extends RefCounted
## Whispering Seam's sounds (SeamView), at the moments and places its picture shows them, through MineAmb's muffled
## bus; how far a place is from the middle of the screen takes it down (SeamView._far). Own files in
## assets/audio/amb/seam/ (prototype/tools/amb_seam.py: the canaries - recordings, Zenodo CC BY 4.0 - Shubin's cough, the
## knocks, the gas's hiss, its flame, the signal bell, the steamer's whistle) and other mines' files used as they are:
##   the furnace's roar (Copper Mountain's) by the draught furnace, the river lapping at the pier (the cove's), jackdaws
##   (Copper Mountain's crows, higher), the cat, the rats' scurry (the barrow's), the carts' rumble on the incline, picks.

const RIVER_DB := -24.0
const FURNACE_DB := -24.0
const CANARY_DB := -12.0

var _song_at := 3.0
var _cat_at := 20.0
var _rumble_at := 0.0

static func of(v: SeamView) -> SeamSounds:
	if not v.has_meta("seam_sounds"):
		v.set_meta("seam_sounds", SeamSounds.new())
	return v.get_meta("seam_sounds")

static func strike(v: SeamView, who: String, db: float) -> void:
	if who.begins_with("bell"):       # the onsetter's pull: the pit bottom's bell
		v.amb.shot_clear("seam/bell", db - 8.0, 1.12)
	elif who.begins_with("rescue"):
		v.amb.shot("pick", db - 3.0, 0.75)
	else:
		v.amb.shot("pick", db, 1.0)

static func cough(v: SeamView, db: float) -> void:
	v.amb.shot("seam/cough_%d" % (randi() % 3), db - 2.0, randf_range(0.9, 1.0))

static func knock(v: SeamView, db: float) -> void:
	v.amb.shot("seam/knock", db - 2.0, 1.0)

static func hiss(v: SeamView, db: float) -> void:
	v.amb.shot_clear("seam/hiss", db - 8.0, 1.0)

static func flame(v: SeamView, db: float) -> void:
	v.amb.shot("seam/flame", db - 2.0, 1.0)

static func whistle(v: SeamView, db: float) -> void:
	v.amb.shot("seam/whistle", db - 6.0, 1.0)

static func scurry(v: SeamView, db: float) -> void:
	v.amb.shot("barrow/scurry", db - 6.0, 1.4)

static func jackdaws(v: SeamView, db: float) -> void:
	for i in 3:
		v.get_tree().create_timer(0.2 + i * 0.5 + randf() * 0.3).timeout.connect(func():
			v.amb.shot("copper/crow_%d" % (randi() % 3), db - 6.0, randf_range(1.35, 1.55)))

## a canary's phrase (past the muffling bus: the song is nearly all above 2 kHz)
static func song(v: SeamView, db: float) -> void:
	v.amb.shot_clear("seam/canary_%d" % (randi() % 6), db, randf_range(0.97, 1.03))

func tick(v: SeamView) -> void:
	var a := v.amb
	var J := v.J
	var sp := v._shown_places
	var sky := float(J.sky)
	# the river under the cape, the furnace's roar while it is built
	a.hum("sea/lap", RIVER_DB + v._far(sky + 1700.0))
	if J.has("fanwheel") and int(sp.get("fan", 0)) >= 3:
		a.hum("copper/furnace", FURNACE_DB + v._far(float((J.fanwheel.c as Array)[1])))
	# the canaries: a phrase now and then from the nearest singing cage (silent ones keep quiet)
	if v.t > _song_at:
		_song_at = v.t + randf_range(2.5, 6.0)
		var best := -99.0
		for b in v._bands:
			var k := int(b.k)
			if String(v._shown_bands.get(k, b.state)) == "closed" or v._quiet.has(k) or not J.has("cages"):
				continue
			if not J.cages.has(str(int(b.d))) or (int(b.d) == 9 and String(v._shown_bands.get(k, "")) != "done"):
				continue
			best = maxf(best, v._far(float(b.y) + 250.0))
		if J.has("lamphouse") and int(sp.get("lamps", 0)) >= 3:
			best = maxf(best, v._far(float((J.lamphouse as Array)[1])) - 4.0)
		if best > -20.0:
			song(v, CANARY_DB + best)
	# the cart rumbling on the incline while it runs
	var st := v._cart_state()
	if st.y < 0.5 and v.t > _rumble_at:
		_rumble_at = v.t + 2.2
		a.shot("cart_%d" % (randi() % 2), -16.0 + v._far(v._at_len(st.x).y), 0.85)
	if v.t > _cat_at and int(sp.get("lamps", 0)) >= 3:
		_cat_at = v.t + randf_range(30.0, 60.0)
		a.shot("copper/meow", -18.0 + v._far(sky + 1300.0), 1.0)
