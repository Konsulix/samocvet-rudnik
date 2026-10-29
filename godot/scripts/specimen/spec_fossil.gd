class_name SpecFossil
extends RefCounted
## Fossils: a class of finds that are not crystals. Each kind has its own body and its own genes, kept here
## (genes()) on their own random stream so the crystals' genes stay as they were.
##   ammonite — a coiled shell: a tube on a logarithmic spiral, ribbed, sometimes keeled. Its surface is drawn pixel by
##              pixel by shaders/fossil.gdshader from the shell's own coordinates (the mesh carries them as UV): fine
##              ribs, weathering, the suture lines where the shell wore, and nacre — ammolite — laid in plates.
##              Shown lying on a slab of its rock, loose, or sawn in half and polished: then the chambers show, filled
##              with honey calcite, white calcite, pyrite, banded agate or dark amber set with chips of ammolite.

const U := preload("res://scripts/specimen/spec_util.gd")
const SHADER := preload("res://shaders/fossil.gdshader")

## the bare shell: colour, dark (hollows, sutures), metal, roughness, a faint film over it all, and the photo scan
## of stone laid over it (how much) — scans unlike any host rock (lichen, cracked boulder, dark cliff, pitted
## sandstone), so a shell on its slab never melts into it
const PAL := [
	{base = 0xbcae96, dark = 0x4e4234, metal = 0.0, rough = 0.62, film = 0.0, scan = "marble_rock_02", scan_k = 0.85},  # limestone, cream with fine veins
	{base = 0x94694a, dark = 0x34200f, metal = 0.12, rough = 0.36, film = 0.0, scan = "marble_rock_03", scan_k = 0.85}, # brown calcite shell
	{base = 0x857c72, dark = 0x2a2522, metal = 0.08, rough = 0.7, film = 0.0, scan = "rock_surface", scan_k = 0.8},     # grey, from shale
	{base = 0x8c6b4c, dark = 0x2e2216, metal = 0.75, rough = 0.32, film = 0.6, scan = "rock_surface", scan_k = 0.25},   # pyrite, bronze with a sheen
	{base = 0x5a554e, dark = 0x1a1612, metal = 0.08, rough = 0.58, film = 0.06, scan = "dark_rock", scan_k = 0.85},     # dark, from black shale
]
const FILL_I := {calcite = 0, white = 1, pyrite = 2, agate = 3, ammolite = 4}
## each fire: [the middle of its hues on the shader's colour wheel, how far the plates stray from it]
const FIRE := {red = [0.04, 0.05], green = [0.3, 0.07], blue = [0.6, 0.05], violet = [0.76, 0.04]}
const FIRE_N := {red = "", green = "green ", blue = "blue ", violet = "violet "}
const SEPT := TAU / 13.0        # the angle between chamber walls
const PLATE := Vector2(10.0 / TAU, 5.0 / TAU)   # nacre plates per radian: along the coil, round the tube (5 rows, wrapping)

## the fossil's own genes, from its seed: how it is shown, how well it kept, its shell
## o: the find; showcases may pin `show`, `nacre`, `fire`, `pal`, `fill`
static func genes(seed_v: int, sid: String, tr: Array, o: Dictionary = {}) -> Dictionary:
	if sid == "petrified_wood":
		return SpecWood.genes(seed_v, tr, o)
	if sid == "fulgurite":
		return SpecFulgurite.genes(seed_v, tr, o)
	if sid in ["flower_quartz", "amber"]:
		return SpecFlower.genes(seed_v, sid, tr, o)
	if sid == "trilobite":
		return SpecTrilobite.genes(seed_v, tr, o)
	if sid == "pearl":
		return SpecPearl.genes(seed_v, tr, o)
	var rng := Rng32.new((seed_v * 2891336453 + 11) % 4294967296)
	var g := {kind = sid}
	match sid:
		"ammonite":
			g.show = Stones.pick_w([["matrix", 5.0], ["loose", 2.0], ["split", 3.0]], rng)
			# how much of the shell kept its nacre, as ammolite plates: most none, a few a little, a rare one nearly all;
			# the rainbow-film trait raises it. Its fire: red and orange are common, green less, blue and violet rare
			g.nacre = 0.0 if rng.next() < 0.5 else 0.03 + pow(rng.next(), 2.2) * 0.97
			if "irid" in tr or "aurora" in tr:
				g.nacre = maxf(float(g.nacre), 0.45 + pow(rng.next(), 0.8) * 0.55)
			g.fire = Stones.pick_w([["red", 45.0], ["green", 30.0], ["blue", 15.0], ["violet", 10.0]], rng)
			g.plates = int(rng.next() * 100000.0)
			g.pal = int(Stones.pick_w([[0, 3.0], [1, 3.0], [2, 2.0], [3, 2.0], [4, 1.0]], rng))
			g.fill = Stones.pick_w([["calcite", 4.0], ["white", 2.0], ["pyrite", 1.5], ["agate", 1.0], ["ammolite", 1.0]], rng)
			g.turns = 3.2 + rng.next() * 1.4
			g.grow = 1.75 + rng.next() * 0.7         # how much wider each turn is than the one inside it
			g.ribs = 14.0 + floor(rng.next() * 18.0)  # ribs per turn, in the shape
			g.fine = 34.0 + floor(rng.next() * 40.0)  # fine ribs per turn, drawn
			g.rib_k = 0.0 if rng.next() < 0.2 else 0.03 + rng.next() * 0.07
			g.keel = 0.12 if rng.next() < 0.35 else 0.0
			g.flat = 0.85 + rng.next() * 0.4          # how thick each turn is for its width (some are inflated)
			g.ov = 0.08 + rng.next() * 0.25           # how far each turn wraps over the one inside
			g.frill = 0.6 + rng.next() * 0.8          # how lacy the suture lines are
			# rare uncoiled forms (heteromorphs): an open coil, a turreted helix, a hook — never sawn
			g.hetero = Stones.pick_w([["", 94.0], ["open", 2.5], ["helix", 2.0], ["hook", 1.5]], rng)
			# a sawn shell may come as its matched pair; some of its chambers hollow, lined with crystals
			g.pair = rng.next() < 0.4
			g.hollow = 0.25 + rng.next() * 0.45 if rng.next() < 0.5 else 0.0
			# on a slab: young ones beside it (a brood), or the shell crushed flat in shale
			g.brood = 1 + int(rng.next() * 3) if rng.next() < 0.3 else 0
			g.crushed = rng.next() < 0.15
			for k in ["show", "nacre", "fire", "pal", "fill", "hetero", "pair", "hollow", "brood", "crushed"]:
				if o.has(k): g[k] = o[k]
			if g.hetero != "" and g.show == "split": g.show = "loose"
			if g.show != "split":
				g.pair = false
				g.hollow = 0.0
			if g.show != "matrix":
				g.brood = 0
				g.crushed = false
			if g.hetero != "": g.crushed = false
			if g.hetero == "open":
				g.ov = -0.35
				g.turns = minf(float(g.turns), 3.6)
			# the legendary dragon fire wants nacre to burn in
			if o.get("legend", false): g.nacre = maxf(float(g.nacre), 0.6)
	return g

## the accents a fossil shows (named on the card, marked for its callouts)
static func accents(g: Dictionary) -> Array:
	if g.get("kind", "") == "petrified_wood":
		return SpecWood.accents(g)
	if g.get("kind", "") == "fulgurite":
		return SpecFulgurite.accents(g)
	if g.get("kind", "") in ["flower_quartz", "amber"]:
		return SpecFlower.accents(g)
	if g.get("kind", "") == "trilobite":
		return SpecTrilobite.accents(g)
	if g.get("kind", "") == "pearl":
		return SpecPearl.accents(g)
	var out := []
	if g.get("kind", "") == "ammonite":
		if float(g.nacre) >= 0.03: out.append("nacre")
		if float(g.nacre) < 0.85 and g.show != "split": out.append("sutures")
		if g.show == "split": out.append("ch_" + String(g.fill))
		if g.get("hollow", 0.0) > 0.0: out.append("druse_ch")
		if g.get("pair", false): out.append("pair")
		if int(g.get("brood", 0)) > 0: out.append("brood")
		if g.get("crushed", false): out.append("crushed")
		if String(g.get("hetero", "")) != "": out.append("hetero")
		if g.show == "matrix": out.append("lilies")
	return out

## the card's name for a fossil gene that carries a number (the nacre's share)
static func gene_name(id: String, g: Dictionary) -> String:
	if g.get("kind", "") == "petrified_wood":
		return SpecWood.gene_name(id, g)
	if g.get("kind", "") == "fulgurite":
		return SpecFulgurite.gene_name(id, g)
	if g.get("kind", "") in ["flower_quartz", "amber"]:
		return SpecFlower.gene_name(id, g)
	if g.get("kind", "") == "trilobite":
		return SpecTrilobite.gene_name(id, g)
	if g.get("kind", "") == "pearl":
		return SpecPearl.gene_name(id, g)
	match id:
		"nacre": return "%sammolite %d%%" % [FIRE_N.get(g.get("fire", "red"), ""), roundi(float(g.nacre) * 100.0)]
		"druse_ch": return "crystal-lined chambers"
		"pair": return "matched pair"
		"brood": return "brood of %d" % (int(g.brood) + 1)
		"crushed": return "crushed in shale"
		"hetero": return {open = "open coil", helix = "turreted coil", hook = "hooked shell"}.get(g.hetero, "uncoiled")
		"lilies": return "sea lilies"
	return ""

# ---------------------------------------------------------------- ammonite

static func _h(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0

## the spiral at angle th: its outer edge r, the tube's middle m, its half-width across (rr) and through (rz)
static func _whorl(f: Dictionary, a: float, b: float, th: float) -> Array:
	var r := a * exp(b * th)
	var inner := r / float(f.grow)
	var rr := (r - inner) * 0.5 * (1.0 + float(f.ov))
	return [r, r - rr, rr, rr * float(f.flat)]

## where the tube runs at th: [its middle, the outward direction across it, its axis through] — a flat coil, or a
## heteromorph: a turreted helix (the small turns climb), or a hook (the last part leaves the coil, runs straight
## and bends back)
static func _path(f: Dictionary, a: float, b: float, th: float) -> Array:
	var w: Array = _whorl(f, a, b, th)
	var er := Vector3(cos(th), sin(th), 0)
	var c := er * float(w[1])
	var het: String = f.get("hetero", "")
	if het == "helix":
		var tmax := float(f.turns) * TAU
		c += Vector3(0, 0, (a * exp(b * tmax) - float(w[0])) * 1.7)
	elif het == "hook":
		var tmax := float(f.turns) * TAU
		var th_h := tmax - 1.6 * PI
		if th > th_h:
			var wh: Array = _whorl(f, a, b, th_h)
			var eh := Vector3(cos(th_h), sin(th_h), 0)
			var tg := Vector3(-sin(th_h), cos(th_h), 0)
			var u := (th - th_h) / (tmax - th_h)
			var r_h: float = wh[0]
			var c_s := eh * float(wh[1]) + tg * r_h * 1.3 * minf(u / 0.55, 1.0)
			if u <= 0.55:
				return [c_s, eh, Vector3.BACK]
			var al := PI * (u - 0.55) / 0.45
			var rad := r_h * 0.55
			var o := c_s - eh * rad
			var nn := eh * cos(al) + tg * sin(al)
			return [o + nn * rad, nn, Vector3.BACK]
	return [c, er, Vector3.BACK]

## the tube's direction at th (towards the open end)
static func _tangent(f: Dictionary, a: float, b: float, th: float) -> Vector3:
	var p0: Vector3 = _path(f, a, b, th - 0.01)[0]
	var p1: Vector3 = _path(f, a, b, th)[0]
	return (p1 - p0).normalized()

## a point of the shell's surface (without ribs) and its outward direction
static func _surf(f: Dictionary, a: float, b: float, th: float, ph: float) -> Array:
	var w: Array = _whorl(f, a, b, th)
	var pa: Array = _path(f, a, b, th)
	var n: Vector3 = pa[1]
	var sp := sin(ph)
	var p: Vector3 = (pa[0] as Vector3) + n * float(w[2]) * cos(ph) + Vector3(0, 0, float(w[3]) * signf(sp) * pow(absf(sp), 0.75))
	return [p, (n * cos(ph) + Vector3(0, 0, sp)).normalized()]

## the nacre plates, decided here and handed to the shader as a small texture (one texel per plate: nacre or bare,
## its hue offset, its centre's jitter) — so the callouts point where the shader draws them.
## Returns [texture, size, [[th, ph], ...] of the nacre plates' centres]
static func _plates(f: Dictionary, tmax: float) -> Array:
	var nu := ceili(tmax * PLATE.x) + 1
	var nv := ceili(TAU * PLATE.y) + 1
	var w := nu + 2
	var h := nv + 2
	var nacre: float = f.nacre
	var s: int = f.plates
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var centres := []
	for y in h:
		for x in w:
			var cx := x - 1
			var cy := posmod(y - 1, 5)   # round the tube the rows wrap: the row below the first is the last
			var on := nacre > 0.0 and _h(cx, cy, s + 13) < nacre
			var jx := _h(cx, cy, s)
			var jy := _h(cx, cy, s + 7)
			img.set_pixel(x, y, Color(1.0 if on else 0.0, _h(cx, cy, s + 29), jx, jy))
			if on and y >= 1 and y <= 5:
				centres.append([(cx + 0.15 + 0.7 * jx) / PLATE.x, (cy + 0.15 + 0.7 * jy) / PLATE.y])
	return [ImageTexture.create_from_image(img), Vector2(w, h), centres]

## how far (radians) a sawn shell's broken end bites back at x (0 the inner edge of the turn .. 1 the outer):
## one ragged line for the shell and its polished face, so their ends meet
static func _bite(f: Dictionary, x: float) -> float:
	var s := float(int(f.plates) % 97) * 0.37
	# a few broad, rounded bays: no sharp teeth
	var n := 0.5 + 0.32 * sin(x * 4.6 + s) + 0.12 * sin(x * 9.1 + s * 1.7)
	return 0.45 * (0.15 + 0.9 * n)

## the shell's mesh: UV = (along the coil, round the tube), UV2.x = the coil's radius; sawn: only the half behind the
## cut, broken off at its end and closed there with the stone that filled it (vertex alpha 0: drawn as a fracture)
static func shell_geo(f: Dictionary, half: bool) -> Geo:
	var turns: float = f.turns
	var tmax := turns * TAU
	var b := log(float(f.grow)) / TAU
	var a := 1.0 / exp(b * tmax)
	var ribs: float = f.ribs
	# two more tiny turns inside, so the coil closes at its centre instead of leaving a hole
	var th0 := -2.0 * TAU
	var n_th := int((turns + 2.0) * 120.0)
	var n_ph := 28
	var ph0 := PI if half else 0.0
	var g := Geo.new()
	# wear and damage: chips knocked off the outer edge and the ribs, gouges, little dents — the shell is a stone that
	# lay in the ground for ages, not a cast. Chipped spots carry vertex red < 1 and are drawn as a fresh break
	var chips := FastNoiseLite.new()
	chips.seed = int(f.plates)
	chips.frequency = 4.5
	chips.fractal_octaves = 2
	var dents := FastNoiseLite.new()
	dents.seed = int(f.plates) + 7
	dents.noise_type = FastNoiseLite.TYPE_CELLULAR
	dents.frequency = 16.0
	dents.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	# where each line round the tube ends: at the aperture, or along the broken edge of a sawn shell
	var ends := PackedFloat32Array()
	for j in n_ph + 1:
		var ph := ph0 + (PI if half else TAU) * float(j) / n_ph
		ends.append(tmax - (_bite(f, cos(ph) * 0.5 + 0.5) if half else 0.0))
	for i in n_th + 1:
		for j in n_ph + 1:
			var th := th0 + (ends[j] - th0) * float(i) / n_th
			var w: Array = _whorl(f, a, b, th)
			var rr: float = w[2]
			var rz: float = w[3]
			var pa: Array = _path(f, a, b, th)
			var er: Vector3 = pa[1]
			# ribs fade towards the tiny first turns
			var rib := pow(maxf(0.0, sin(th * ribs)), 3.0) * float(f.rib_k) * smoothstep(0.5, 2.0, th / TAU)
			var ph := ph0 + (PI if half else TAU) * float(j) / n_ph
			var cp := cos(ph)
			var sp := sin(ph)
			var out := smoothstep(-0.3, 0.7, cp)   # ribs and keel stand on the outer side
			var k := 1.0 + rib * out
			# the keel: a soft, worn ridge along the outer edge, its height and line wandering a little
			var kd := (ph if ph < PI else ph - TAU) + chips.get_noise_2d(th * 3.0, 50.0) * 0.12
			var kl := float(f.keel) * exp(-kd * kd / 0.09) * (0.75 + 0.5 * (dents.get_noise_2d(th * 2.0, 3.0) * 0.5 + 0.5)) * 0.8
			var pos: Vector3 = (pa[0] as Vector3) + er * (rr * cp * k + rr * kl) + Vector3(0, 0, rz * signf(sp) * pow(absf(sp), 0.75) * k)
			# chips: flat-bottomed bites with a steep edge, on the outer edge of the outer turns and near the end
			var where := smoothstep(0.1, 0.8, cp) * smoothstep(TAU, 2.5 * TAU, th) + smoothstep(ends[j] - 0.7, ends[j], th) * 0.8
			var cn := chips.get_noise_3dv(pos * 1.0) * 0.5 + 0.5
			var chip := smoothstep(0.66, 0.71, cn + where * 0.08) * minf(1.0, where)
			# a sawn half keeps its edge whole along the cut, so the polished face never sticks out past the shell
			if half:
				chip *= smoothstep(0.15, 0.5, absf(sp))
			# dents: shallow round hollows anywhere on the bigger turns
			var dn := dents.get_noise_3dv(pos) * 0.5 + 0.5
			var dent := (smoothstep(0.15, 0.5, absf(sp)) if half else 1.0) * (1.0 - smoothstep(0.0, 0.3, dn)) * smoothstep(0.5, 0.8, chips.get_noise_3dv(pos * 2.3 + Vector3(9, 0, 0)) * 0.5 + 0.5) * smoothstep(TAU, 2.0 * TAU, th)
			var inward := (er * cp + Vector3(0, 0, sp)).normalized()
			pos -= inward * rr * (chip * 0.16 + dent * 0.05)
			g.v.append(pos)
			g.rp.append(Vector3(th, ph, float(w[0])))
			g.col.append(Color(1.0 - chip, 1, 1, 1))
	var row := n_ph + 1
	for i in n_th:
		for j in n_ph:
			var p0 := i * row + j
			g.idx.append_array([p0, p0 + row, p0 + 1, p0 + 1, p0 + row, p0 + row + 1])
	# the end closed: the aperture with rock, or the break with the stone inside (its own copy of the edge, alpha 0,
	# so the fracture's look does not bleed onto the shell); both windings, seen whichever way the tube is turned
	# the break's outline: the shell's ragged end and, on a sawn half, back along the polished face's own broken
	# edge — one closed loop, filled from its middle pulled a little back into the tube, so it neither gapes nor sticks out
	var loop := []
	for j in n_ph + 1:
		loop.append(n_th * row + j)
	var extra := PackedVector3Array()
	if half:
		for q in range(11, 0, -1):
			var t := float(q) / 12.0
			var te := tmax - _bite(f, t)
			var re := a * exp(b * te)
			extra.append(Vector3(cos(te), sin(te), 0) * lerpf(re / float(f.grow), re, t))
	var ctr_p := Vector3.ZERO
	for k in loop: ctr_p += g.v[k]
	for e in extra: ctr_p += e
	ctr_p /= loop.size() + extra.size()
	var mid := INF
	for e in ends: mid = minf(mid, e)
	var wl: Array = _whorl(f, a, b, mid)
	# a whole shell's aperture: the mud it filled with, sunk well into the tube (vertex alpha 0.25: drawn as rock)
	var back := _tangent(f, a, b, mid) * float(wl[2]) * (0.15 if half else 0.7)
	var cc := Color(1, 1, 1, 0 if half else 0.25)
	# the surface: rings from the outline in to the middle, each pushed into the tube by a dip that deepens towards the
	# middle, plus a broken-stone relief — flat facets (cellular noise) with a rolling unevenness over them —
	# fading out at the outline so the edge stays where it is
	var edge := []
	for k in loop: edge.append(g.v[k])
	for e in extra: edge.append(e)
	var n_loop := edge.size()
	var into := back.normalized()
	var rr0 := float(wl[2])
	var fac := FastNoiseLite.new()
	fac.seed = int(f.plates) + 31
	fac.noise_type = FastNoiseLite.TYPE_CELLULAR
	fac.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	fac.frequency = 7.0
	var roll := FastNoiseLite.new()
	roll.seed = int(f.plates) + 37
	roll.frequency = 5.0
	roll.fractal_octaves = 3
	var rings := 8
	var base := g.v.size()
	for r in rings + 1:
		var sr := float(r) / (rings + 1)
		var dip := back.length() * (1.0 - pow(1.0 - sr, 2.0))
		var keep := smoothstep(0.0, 0.35, sr)   # the outline itself does not move
		for q in n_loop:
			var p0: Vector3 = (edge[q] as Vector3).lerp(ctr_p, sr)
			var bump := (fac.get_noise_3dv(p0) * 0.6 + roll.get_noise_3dv(p0) * 0.5) * rr0 * (0.3 if half else 0.4) * keep
			g.v.append(p0 - into * (dip + bump))
			g.rp.append(Vector3(mid, PI, float(wl[0])))
			g.col.append(cc)
	var ctr := g.v.size()
	g.v.append(ctr_p - back - into * roll.get_noise_3dv(ctr_p) * rr0 * 0.2)
	g.rp.append(Vector3(mid, PI, float(wl[0])))
	g.col.append(cc)
	var segs := n_loop if half else n_loop - 1
	for r in rings:
		for q in segs:
			var q2 := (q + 1) % n_loop
			var a0 := base + r * n_loop + q
			var a1 := base + r * n_loop + q2
			var b0 := base + (r + 1) * n_loop + q
			var b1 := base + (r + 1) * n_loop + q2
			# one winding: the shader draws both sides (two would fight for the same pixels)
			g.idx.append_array([a0, b0, a1, a1, b0, b1])
	var last := base + rings * n_loop
	for q in segs:
		var q2 := (q + 1) % n_loop
		g.idx.append_array([ctr, last + q, last + q2])
	return g

## the sawn face (z = 0): the spiral band of every turn; UV = (along the coil, 0 inner .. 1 outer edge), UV2.x radius
static func face_geo(f: Dictionary) -> Geo:
	var turns: float = f.turns
	var tmax := turns * TAU
	var b := log(float(f.grow)) / TAU
	var a := 1.0 / exp(b * tmax)
	var th0 := -2.0 * TAU
	var n_th := int((turns + 2.0) * 120.0)
	var n_t := 24
	var g := Geo.new()
	# the same noises as the shell's, to find where its outer edge lies along the cut (its ribs and keel stand past r)
	var chips := FastNoiseLite.new()
	chips.seed = int(f.plates)
	chips.frequency = 4.5
	chips.fractal_octaves = 2
	var dents := FastNoiseLite.new()
	dents.seed = int(f.plates) + 7
	dents.noise_type = FastNoiseLite.TYPE_CELLULAR
	dents.frequency = 16.0
	dents.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	for i in n_th + 1:
		for j in n_t + 1:
			var t := float(j) / n_t
			# the broken end, the same ragged line as the shell's
			var th := th0 + (tmax - _bite(f, t) - th0) * float(i) / n_th
			var r := a * exp(b * th)
			var inner := r / float(f.grow)
			var er := Vector3(cos(th), sin(th), 0)
			# the outer edge follows the shell's own edge on the cut exactly — ribs, keel and all — so no gap shows
			var tt := t
			if j == n_t:
				var w: Array = _whorl(f, a, b, th)
				var rib := pow(maxf(0.0, sin(th * float(f.ribs))), 3.0) * float(f.rib_k) * smoothstep(0.5, 2.0, th / TAU)
				var kd := chips.get_noise_2d(th * 3.0, 50.0) * 0.12
				var kl := float(f.keel) * exp(-kd * kd / 0.09) * (0.75 + 0.5 * (dents.get_noise_2d(th * 2.0, 3.0) * 0.5 + 0.5)) * 0.8
				var edge := float(w[1]) + float(w[2]) * (1.0 + rib + kl)
				tt = (edge - inner) / (r - inner)
			g.v.append(er * lerpf(inner, r, tt))
			g.rp.append(Vector3(th, tt, r))
			g.col.append(Color(1, 1, 1, 1))
	var row := n_t + 1
	for i in n_th:
		for j in n_t:
			var p0 := i * row + j
			g.idx.append_array([p0, p0 + 1, p0 + row, p0 + 1, p0 + row + 1, p0 + row])
	return g

## the material: one shader, its part (0 shell, 1 sawn face) and the shell's own numbers
static func _mat(f: Dictionary, part: int, half: bool, plates: Array) -> ShaderMaterial:
	var tmax: float = float(f.turns) * TAU
	var pal: Dictionary = PAL[int(f.pal)]
	var nacre: float = f.nacre
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("part", part)
	# under ammolite the shell is the dull brown it grew on
	var base := Color.hex(int(pal.base) << 8 | 0xff).lerp(Color.hex(0x4a3424ff), clampf(nacre * 3.0, 0.0, 0.8))
	m.set_shader_parameter("base_col", base)
	m.set_shader_parameter("dark_col", Color.hex(int(pal.dark) << 8 | 0xff))
	m.set_shader_parameter("metal_k", pal.metal)
	m.set_shader_parameter("rough_k", pal.rough)
	m.set_shader_parameter("film_all", pal.film)
	m.set_shader_parameter("fire_h", FIRE[f.fire][0])
	m.set_shader_parameter("ribs_fine", f.fine)
	m.set_shader_parameter("rib_amp", 0.6 + float(f.rib_k) * 6.0)
	m.set_shader_parameter("b_log", log(float(f.grow)) / TAU)
	m.set_shader_parameter("t_end", tmax)
	# a sawn shell is shown without its body chamber: cut off at the last chamber wall, every chamber filled
	m.set_shader_parameter("body", 0.0 if half else 0.6 * TAU)
	m.set_shader_parameter("sept", SEPT)
	m.set_shader_parameter("frill", f.frill)
	m.set_shader_parameter("tube_k", (1.0 - 1.0 / float(f.grow)) * 0.5 * (1.0 + float(f.ov)))
	m.set_shader_parameter("sut_k", 1.0 - clampf(nacre * 1.2, 0.0, 1.0) * 0.5)
	m.set_shader_parameter("cells", plates[0])
	m.set_shader_parameter("cells_n", plates[1])
	m.set_shader_parameter("plate_k", PLATE)
	m.set_shader_parameter("nacre_from", TAU * 0.6)
	m.set_shader_parameter("fill", FILL_I.get(f.fill, 0))
	m.set_shader_parameter("rock_col", Color.hex(0x4a443cff))
	var sn: String = pal.scan
	m.set_shader_parameter("scan_diff", load("res://assets/textures/%s/%s_diff_1k.jpg" % [sn, sn]))
	m.set_shader_parameter("scan_rough", load("res://assets/textures/%s/%s_rough_1k.jpg" % [sn, sn]))
	m.set_shader_parameter("scan_k", pal.scan_k)
	m.set_shader_parameter("hollow_tex", _hollow_tex(f))
	var rn: String = SpecMat.SCANS[RockKit.SCAN_OF.get(f.get("rock", "limestone"), 0)]
	m.set_shader_parameter("mud_diff", load("res://assets/textures/%s/%s_diff_1k.jpg" % [rn, rn]))
	return m

## which chambers of a sawn shell are hollow (lined with crystals): a strip of texels, chamber c at c + 64
static func _hollow_tex(f: Dictionary) -> ImageTexture:
	var img := Image.create(256, 1, false, Image.FORMAT_R8)
	var tmax := float(f.turns) * TAU
	for c in _hollow(f):
		img.set_pixel(int(c) + 64, 0, Color(1, 0, 0))
	return ImageTexture.create_from_image(img)

## the hollow chambers: only in the last turn and a half, where they are big enough to hold crystals
static func _hollow(f: Dictionary) -> Array:
	var out := []
	var share: float = f.get("hollow", 0.0)
	if share <= 0.0:
		return out
	var tmax := float(f.turns) * TAU
	for c in range(int(floor((tmax - 1.5 * TAU) / SEPT)), int(floor((tmax - 0.9) / SEPT))):
		if _h(c, 0, int(f.plates) + 51) < share:
			out.append(c)
	return out

## the chamber walls' S-curve, as the shader draws it (they must agree)
static func _wall_w(f: Dictionary, th: float, t: float) -> float:
	var tube_k := (1.0 - 1.0 / float(f.grow)) * 0.5 * (1.0 + float(f.ov))
	return (0.30 * (1.0 - t) * (1.0 - t) - 0.11 * sin(PI * t) + 0.02 * sin(t * 11.0 + th * 0.7) * float(f.frill)) * tube_k * 2.2

## a hollow chamber, open under the polished face: its two walls going down into the half shell, and crystals
## lining it. The shell's own inside is its floor
static func _druse(b: RefCounted, f: Dictionary, parent: Node3D, c: int, gl: ShaderMaterial, wm: ShaderMaterial) -> void:
	var tmax := float(f.turns) * TAU
	var bl := log(float(f.grow)) / TAU
	var a := 1.0 / exp(bl * tmax)
	var rng := Rng32.new((int(f.plates) * 7 + c * 131) % 4294967296 + 1)
	# the walls: a quad strip each, from the face down to the inside of the tube
	var g := Geo.new()
	for side in 2:
		var b0 := g.v.size()
		for i in 13:
			var t := 0.02 + 0.96 * float(i) / 12.0
			var th := float(c + side) * SEPT + _wall_w(f, float(c + side) * SEPT, t)
			var w: Array = _whorl(f, a, bl, th)
			var r: float = w[0]
			var x := lerpf(r / float(f.grow), r, t)
			var cp := clampf((x - float(w[1])) / float(w[2]), -1.0, 1.0)
			var z := -float(w[3]) * pow(sqrt(1.0 - cp * cp), 0.75) * 0.97
			var er := Vector3(cos(th), sin(th), 0)
			g.v.append(er * x)
			g.v.append(er * x + Vector3(0, 0, z))
			# lit at the top, in shadow down in the chamber
			g.col.append(Color(1, 1, 1, 1))
			g.col.append(Color(0.2, 0.2, 0.2, 1))
		for i in 12:
			var p0 := b0 + i * 2
			g.idx.append_array([p0, p0 + 1, p0 + 2, p0 + 2, p0 + 1, p0 + 3])
	U.mesh(g, wm, parent)
	# crystals on the floor and the walls, pointing in towards the chamber's middle
	var pts := []
	var thm := (float(c) + 0.5) * SEPT
	var wm_: Array = _whorl(f, a, bl, thm)
	var mid := Vector3(cos(thm), sin(thm), 0) * float(wm_[1]) + Vector3(0, 0, -float(wm_[3]) * 0.35)
	for k in 9:
		# on the floor, away from the rim, so none pokes out of the cut or the shell
		var t := 0.18 + rng.next() * 0.64
		var th := (float(c) + 0.08 + rng.next() * 0.84) * SEPT + _wall_w(f, float(c) * SEPT, t)
		var w: Array = _whorl(f, a, bl, th)
		var r: float = w[0]
		var x := lerpf(r / float(f.grow), r, t)
		var cp := clampf((x - float(w[1])) / float(w[2]), -1.0, 1.0)
		var z := -float(w[3]) * pow(sqrt(1.0 - cp * cp), 0.75) * 0.93
		pts.append([Vector3(cos(th), sin(th), 0) * x + Vector3(0, 0, z), float(w[2])])
	# a few calcite crystals out of the crust, grown by the same crystal maker as every other find (dogtooth
	# scalenohedra, their colour zoned base to tip), glass like theirs; the crust itself is drawn by the shader
	var col: Color = gl.get_meta("tint", Color(0.95, 0.72, 0.4))
	for k in pts.size():
		var p: Vector3 = pts[k][0]
		var rr: float = pts[k][1]
		var d := ((mid - p).normalized() + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5) * 0.7).normalized()
		var s := rr * (0.16 + pow(rng.next(), 2.0) * 0.14)
		var geo := RockKit.crystal("scaleno", rng, {h = 0.7 + rng.next() * 0.5, detail = 1, cA = col.lerp(Color(1, 1, 1), 0.3), cB = col, zk = 0.6})
		U.mesh(geo, gl, parent, p - d * s * 0.15, Basis(U.quat_to(Vector3.UP, d)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s))
	if c == _hollow(f)[0]:
		var to_root := U.rel_xform(parent, b.root)
		b._mark("druse_ch", to_root * mid, (to_root.basis * Vector3.BACK).normalized())

## builds the ammonite into the builder's root; use_rock(shape) lays the host rock and returns its mesh
static func ammonite(b: RefCounted, gene: Dictionary, use_rock: Callable) -> MeshInstance3D:
	var f: Dictionary = (gene.fossil as Dictionary).duplicate()
	f.rock = gene.rock   # the mud in its aperture is its own host rock
	var rng: Rng32 = b.rng
	var root: Node3D = b.root
	var tmax: float = float(f.turns) * TAU
	var plates := _plates(f, tmax)
	var half: bool = f.show == "split"
	var sm := _mat(f, 0, half, plates)
	var shell: MeshInstance3D
	var gs: float = gene.scale
	match f.show:
		"matrix":
			# lying on a slab of its rock, a third of it still in the stone, tipped up to show its coil
			var rk: MeshInstance3D = use_rock.call("slab")
			var rb: AABB = rk.transform * (rk.get_meta("geo") as Geo).aabb()
			var crushed: bool = f.get("crushed", false)
			var brood := int(f.get("brood", 0))
			var s := minf(rb.size.x, rb.size.z) * (0.4 if brood > 0 else 0.5)
			# crushed: lying flat in the shale, squashed to a third of its thickness, barely standing out of it
			var tip := 0.04 if crushed else 0.35 + rng.next() * 0.3
			var sz := s * (0.3 if crushed else 1.0)
			var bs := Basis(Vector3.UP, rng.next() * TAU) * Basis(Vector3.RIGHT, -PI / 2 + tip) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3(s, s, sz))
			var at := Vector3(rb.get_center().x, rb.end.y - rb.size.y * 0.12 + s * sin(tip) * 0.55, rb.get_center().z)
			if crushed: at.y = rb.end.y - rb.size.y * 0.06
			if brood > 0: at += Vector3(-rb.size.x * 0.12, 0, 0)
			shell = U.mesh(shell_geo(f, false), sm, root, at, bs)
			if crushed:
				b._mark("crushed", at + Vector3(0, s * 0.08, 0), Vector3.UP)
			# the brood: young ones about it, half in the stone
			var occ := []
			var br := Rng32.new(int(f.plates) * 3 + 17)
			for k in brood:
				var f2 := f.duplicate()
				f2.plates = int(f.plates) + 13 * (k + 1)
				f2.turns = float(f.turns) - 0.5 - br.next() * 0.7
				var s2 := s * (0.3 + br.next() * 0.22)
				var ang := br.next() * TAU
				var p2 := Vector3(rb.get_center().x + rb.size.x * (0.18 + 0.12 * k) * cos(ang), rb.end.y - rb.size.y * 0.1 + s2 * 0.25, rb.get_center().z + rb.size.z * 0.28 * sin(ang))
				var t2 := 0.2 + br.next() * 0.5
				var b2 := Basis(Vector3.UP, br.next() * TAU) * Basis(Vector3.RIGHT, -PI / 2 + t2) * Basis(Vector3.BACK, br.next() * TAU) * Basis.from_scale(Vector3.ONE * s2)
				var young := U.mesh(shell_geo(f2, false), _mat(f2, 0, false, _plates(f2, float(f2.turns) * TAU)), root, p2, b2)
				young.set_meta("col", true)
				if k == 0: b._mark("brood", p2 + Vector3(0, s2 * 0.4, 0), Vector3.UP)
				young.set_meta("sea_light", true)
				occ.append([Vector2(p2.x, p2.z), s2 * 1.0])
			# the sea floor it lay on: sunlight through the water over it, sea lilies swaying behind it (where they
			# rise clear of the shell), bubbles from the rock — the same sea as the trilobites' (SpecSea)
			root.set_meta("sea", true)
			rk.set_meta("sea_light", true)
			shell.set_meta("sea_light", true)
			# (tipped up on its edge, the shell takes less of the slab than its size)
			occ.append([Vector2(at.x, at.z), s * (0.8 if not f.get("crushed", false) else 1.0)])
			var lrng := Rng32.new(int(f.plates) * 5 + 23)
			var span := minf(rb.size.x, rb.size.z)
			# (out to the slab's edge: the shell fills its middle)
			var cands := SpecTrilobite._top_spots(rk, rb, 0.48)
			var lm := SpecSea.life_mat(0, span * 0.45, span * 0.03, 0.8, 0.55, 0.4)
			var spots := []
			for k in 2 + int(lrng.next() * 3.0):
				var spot: Variant = SpecTrilobite._free_spot(cands, occ, span * 0.05, lrng, rb.get_center().z + rb.size.z * 0.12)
				if spot == null: break
				var lp: Vector3 = spot
				lp.y = SpecTrilobite._ground(rk, lp, span * 0.05) - span * 0.01
				var li := U.mesh(SpecSea.lily(lrng, span * (0.35 + lrng.next() * 0.2)), lm, root, lp, Basis(Vector3.UP, (lrng.next() - 0.5) * 0.8))
				li.set_meta("col", true)
				occ.append([Vector2(lp.x, lp.z), span * 0.06])
				spots.append(lp)
				if k == 0: b._mark("lilies", lp + Vector3(0, span * 0.3, 0), Vector3.UP)
			if spots.size():
				SpecSea.bubbles(root, spots, Vector3.UP, span * 1.2, span * 0.012, 5)
		"loose":
			var bs := Basis(Vector3.UP, (rng.next() - 0.5) * 0.8) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * gs)
			shell = U.mesh(shell_geo(f, false), sm, root, Vector3.ZERO, bs)
		"split":
			# sawn in half and polished: the half stands on its edge, the cut towards the viewer, leaning back a little
			var spin := rng.next() * TAU
			var pair: bool = f.get("pair", false)
			var bs := Basis(Vector3.RIGHT, -0.25) * Basis(Vector3.BACK, spin) * Basis.from_scale(Vector3.ONE * gs)
			var sg := shell_geo(f, true)
			var fg := face_geo(f)
			var fm := _mat(f, 1, true, plates)
			var at := Vector3.ZERO
			if pair:
				# its matched pair: the other half, mirrored, beside it — both cut faces to the viewer, turned a little apart
				at = Vector3(-gs * 0.82, 0, 0)
				var bs2 := Basis(Vector3.UP, -0.3) * Basis(Vector3.RIGHT, -0.25) * Basis(Vector3.BACK, -spin) * Basis.from_scale(Vector3(-gs, gs, gs))
				bs = Basis(Vector3.UP, 0.3) * bs
				var other := U.mesh(sg, sm, root, Vector3(gs * 0.82, 0, 0), bs2)
				other.set_meta("col", true)
				U.mesh(fg, fm, other)
				b._mark("pair", U.rel_xform(other, root) * Vector3(0.3, 0.3, 0.0), Vector3.BACK)
			shell = U.mesh(sg, sm, root, at, bs)
			var face := U.mesh(fg, fm, shell)
			var fx := U.rel_xform(face, root)
			b._mark("ch_" + String(f.fill), fx * Vector3(0.45, 0.1, 0.0), (fx.basis * Vector3(0, 0, 1)).normalized())
			# hollow chambers: walls going down and crystals inside (in this half only — the pair shows its twin's face)
			var hol := _hollow(f)
			if hol.size():
				# calcite crystals: honey-coloured, glossy, faceted (clear glass would mirror the whole studio in rainbows)
				# glass as the generator's own crystals use it (white body: the colour is in the crystal's vertices)
				var gl := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.07, rf = 0.3, holo = 0.2,
					frost = 0.12, thick = 1.3, seed = 5.0})
				gl.set_meta("tint", SpecMat.lin(0xe8b070) if f.fill != "white" else SpecMat.lin(0xeee8dc))
				var wmat := _mat(f, 1, true, plates)
				wmat.set_shader_parameter("as_wall", 1.0)
				for c in hol:
					_druse(b, f, shell, int(c), gl, wmat)
	shell.set_meta("col", true)
	if gene.fx == "dragonfire":
		root.set_meta("dim", true)
		# the legendary dragon fire: the nacre's colours flow across the plates; a sawn face's chambers glow in turn
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var mm := mi.material_override as ShaderMaterial
			if mm and mm.shader == SHADER:
				mm.set_shader_parameter("flow_k", 1.0)
	var xf := U.rel_xform(shell, root)
	var b_log := log(float(f.grow)) / TAU
	var a := 1.0 / exp(b_log * tmax)
	# the nacre: a few plate centres it really covers (on a sawn half, only the half that is there)
	var centres: Array = plates[2]
	var picked := 0
	for k in centres.size():
		var c: Array = centres[(k * 7919) % centres.size()]
		var th: float = c[0]
		var ph: float = fposmod(float(c[1]), TAU)
		if th < TAU * 0.6 or th > tmax or (half and ph < PI):
			continue
		var sp: Array = _surf(f, a, b_log, th, ph)
		b._mark("nacre", xf * (sp[0] as Vector3), (xf.basis * (sp[1] as Vector3)).normalized())
		picked += 1
		if picked >= 10:
			break
	if "sutures" in gene.accents:
		for k in 3:
			var th := tmax - 0.9 * TAU - k * 0.15 * TAU
			var sp: Array = _surf(f, a, b_log, th, 1.2)
			b._mark("sutures", xf * (sp[0] as Vector3), (xf.basis * (sp[1] as Vector3)).normalized())
	return shell
