class_name SpecTrilobite
extends RefCounted
## Trilobite: the shield of a sea creature, three lobes along its length (an axis and two pleural fields) and three
## parts across it (head, segmented thorax, tail). Six kinds, each its own outline and ornament:
##   elrathia    — small, flat, a fringe of short pleural tips; black on grey shale (Utah)
##   phacops     — a swollen, granular head with big eyes of separate lenses; often rolled up in a ball
##   asaphus     — smooth, its eyes up on long stalks (St Petersburg)
##   dicranurus  — ram's horns curling back off the head, long spines down its sides
##   walliserops — a trident on its snout, a row of spines along its back, eyes on towers (Morocco)
##   isotelus    — big and smooth, head and tail alike, worn flat
## The body is one grid laid over its outline (heights from its lobes, rings and furrows); spines are tapering tubes;
## eyes are domes of lenses (shaders/trilobite.gdshader part 1) that glint one by one as the find turns.
## Shown lying on its slab, prepared out standing on a pedestal of its rock, rolled up, or as a plate of several
## that died together. Kept as black shell, calcite (tan, grey, honey), cream, or pyrite. Rare: its moult beside it,
## a healed bite out of its side, its legs and antennae kept in pyrite. Legendary "awakened": the pyrite legs walk.

const U := preload("res://scripts/specimen/spec_util.gd")
const SHADER := preload("res://shaders/trilobite.gdshader")
const PLATE := preload("res://shaders/matrix_plate.gdshader")

## half: half-width for the length; seg: thorax segments; ceph/pyg: share of the length in head and tail; H: how high
## it stands; ax: the axis's half-width for the half-width; glab: how swollen the head's middle; tip: pleural tips;
## eff: how worn smooth the furrows are; tub: granules; eye: crescent | lens | stalk | tower
const GENUS := {
	elrathia = {n = "Elrathia", half = 0.33, seg = 13, ceph = 0.27, pyg = 0.1, H = 0.07, ax = 0.3, glab = 0.55, tip = 0.12, eff = 1.0, tub = 0.0,
		eye = "crescent", eye_r = 0.045, gspine = 0.14, pal = [[0, 7.0], [2, 1.0], [4, 0.6]], w = 4.0},
	phacops = {n = "Phacops", half = 0.31, seg = 11, ceph = 0.37, pyg = 0.2, H = 0.17, ax = 0.36, glab = 1.5, tip = 0.0, eff = 1.0, tub = 1.0,
		eye = "lens", eye_r = 0.065, gspine = 0.0, pal = [[1, 3.0], [2, 3.0], [3, 1.0], [4, 1.0], [5, 1.0]], w = 4.0},
	asaphus = {n = "Asaphus", half = 0.35, seg = 8, ceph = 0.34, pyg = 0.34, H = 0.15, ax = 0.3, glab = 0.8, tip = 0.0, eff = 0.35, tub = 0.0,
		eye = "stalk", eye_r = 0.045, stalk = 0.3, gspine = 0.0, pal = [[3, 5.0], [1, 1.0]], w = 1.2},
	dicranurus = {n = "Dicranurus", half = 0.27, seg = 10, ceph = 0.34, pyg = 0.14, H = 0.15, ax = 0.4, glab = 1.0, tip = 0.05, eff = 0.9, tub = 0.6,
		eye = "lens", eye_r = 0.055, gspine = 0.32, pspine = 0.42, horns = true, pygs = 0.3, pal = [[1, 4.0], [2, 2.0], [4, 0.5]], w = 1.0},
	walliserops = {n = "Walliserops", half = 0.27, seg = 11, ceph = 0.33, pyg = 0.15, H = 0.14, ax = 0.36, glab = 1.0, tip = 0.05, eff = 0.9, tub = 0.4,
		eye = "tower", eye_r = 0.055, gspine = 0.55, pspine = 0.22, dorsal = 0.12, trident = 0.6, pal = [[1, 4.0], [2, 2.0]], w = 0.8},
	isotelus = {n = "Isotelus", half = 0.37, seg = 8, ceph = 0.34, pyg = 0.36, H = 0.11, ax = 0.32, glab = 0.5, tip = 0.0, eff = 0.3, tub = 0.0,
		eye = "crescent", eye_r = 0.05, gspine = 0.1, pal = [[2, 4.0], [1, 2.0], [5, 2.0]], w = 2.0},
}
## how it was kept: shell colour, the dark in its furrows, metal, roughness, the tarnish film (pyrite)
const PAL := [
	{n = "black shell", base = 0x2c2825, dark = 0x0d0b0a, metal = 0.05, rough = 0.34, film = 0.0, scan = "dark_rock", scan_k = 0.35},
	{n = "tan calcite", base = 0x8f6e4e, dark = 0x2c1d12, metal = 0.0, rough = 0.55, film = 0.0, scan = "marble_rock_03", scan_k = 0.7},
	{n = "grey calcite", base = 0x7a756e, dark = 0x262320, metal = 0.0, rough = 0.6, film = 0.0, scan = "rock_surface", scan_k = 0.7},
	{n = "honey calcite", base = 0x86552f, dark = 0x221006, metal = 0.05, rough = 0.36, film = 0.0, scan = "marble_rock_03", scan_k = 0.55},
	{n = "pyrite", base = 0xc8a050, dark = 0x3a2a10, metal = 0.9, rough = 0.22, film = 0.45, scan = "rock_surface", scan_k = 0.25},
	{n = "cream limestone", base = 0xbcae96, dark = 0x4a3e30, metal = 0.0, rough = 0.7, film = 0.0, scan = "marble_rock_02", scan_k = 0.75},
	# opal: the shell replaced by precious opal, its play of colour over a dark body (rare)
	{n = "opal", base = 0x26304a, dark = 0x0a0e1a, metal = 0.0, rough = 0.16, film = 0.0, scan = "dark_rock", scan_k = 0.15, opal = 1.0},
]
## the host rock's colour where it clings in the furrows and makes a pedestal
const ROCK_COL := {limestone = 0x9a9284, slate = 0x55555a, ironstone = 0x6e4a36}
const THICK := 0.03
const DEPTH_ON := 0.26     # how high a pearl oyster's hinge sits above the rock (valve units: its cupped lower valve)

static func genes(seed_v: int, tr: Array, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2654435761 + 61) % 4294967296)
	var g := {kind = "trilobite"}
	var gw := []
	for k: String in GENUS:
		gw.append([k, float(GENUS[k].w)])
	g.genus = Stones.pick_w(gw, rng)
	if o.has("genus"): g.genus = o.genus
	var c: Dictionary = GENUS[g.genus]
	g.pal = int(Stones.pick_w(c.pal, rng))
	var spiny: bool = c.has("pspine") or c.has("trident")
	# spiny ones are prepared out of their rock (who would leave the spines in it); phacops rolls up
	g.show = Stones.pick_w([["matrix", 5.0], ["prepared", 6.0 if spiny or g.genus == "asaphus" else 2.0],
		["enrolled", 0.0 if spiny or g.genus == "asaphus" else 4.0 if g.genus == "phacops" else 0.8],
		["mass", 3.0 if g.genus == "elrathia" else 0.0 if spiny else 0.8]], rng)
	# split out of a concretion: a nodule broken open on it, the trilobite in one half, its mould in the other
	var rng2 := Rng32.new((seed_v * 2246822519 + 13) % 4294967296)
	if not spiny and rng2.next() < 0.28: g.show = "nodule"
	if rng2.next() < 0.04: g.pal = 6
	# pearl oysters grown on the same sea floor, on its slab beside it, a pearl in each (its own pearl genes):
	# none mostly, else one to three; each lies open (now and then snapping shut) or shut (now and then gaping)
	g.oysters = 0 if rng2.next() < 0.82 else int(Stones.pick_w([[1, 5.5], [2, 3.0], [3, 1.5]], rng2))
	g.pearl_seed = int(rng2.next() * 100000.0) + 1
	g.seg = int(c.seg) + int(floorf(rng.next() * 3.0)) - 1
	g.spines = 0.8 + rng.next() * 0.5        # how long its spines grew
	g.seed = int(rng.next() * 100000.0)
	g.moult = rng.next() < 0.15               # its shed skin beside it, the head come apart
	g.bite = rng.next() < 0.08                # a healed bite out of one side
	g.soft = rng.next() < 0.03                # legs and antennae kept, in pyrite
	g.mass = 3 + int(rng.next() * 4.0)
	g.lens_tilt = rng.next()
	if "irid" in tr or "aurora" in tr: g.pal = 4
	for k in ["genus", "pal", "show", "seg", "spines", "moult", "bite", "soft", "mass", "oysters"]:
		if o.has(k): g[k] = o[k]
	# a legendary one keeps its legs and antennae (the awakening walks them)
	if o.get("legend", false): g.soft = true
	if g.soft:
		g.pal = 4
		if g.show == "enrolled" or g.show == "mass": g.show = "matrix"
	if g.show == "enrolled":
		g.moult = false
		g.bite = false
	if g.show != "matrix": g.moult = false
	if not (g.show in ["matrix", "mass"]): g.oysters = 0
	var ors := Rng32.new(int(g.pearl_seed) * 3 + 1)
	g.pearls = []
	for k in int(g.oysters):
		var pg := SpecPearl.genes(int(g.pearl_seed) + k * 7, [], {show = "shell", count = 1})
		pg.open = ors.next() < 0.6
		(g.pearls as Array).append(pg)
	if g.show == "nodule": g.bite = false
	# black shell lies in pale shale (Utah); pyrite legs in black shale (New York)
	if int(g.pal) == 0: g.rock = "limestone"
	if g.soft: g.rock = "slate"
	return g

static func accents(g: Dictionary) -> Array:
	var out := []
	var c: Dictionary = GENUS[g.genus]
	if c.eye == "lens" or c.eye == "tower": out.append("eyes")
	if c.eye == "stalk": out.append("stalks")
	if c.has("trident"): out.append("trident")
	if c.has("horns"): out.append("horns")
	elif c.has("pspine"): out.append("spines")
	if int(g.pal) == 4: out.append("pyrite")
	if int(g.pal) == 6: out.append("opal")
	if g.get("show", "") == "nodule": out.append("nodule")
	if g.get("show", "") in ["matrix", "mass"]: out.append("lilies")
	if int(g.get("oysters", 0)) > 0: out.append("oyster")
	if g.get("moult", false): out.append("moult")
	if g.get("bite", false): out.append("bite")
	if g.get("soft", false): out.append("soft")
	if g.get("show", "") == "mass": out.append("mass")
	if g.get("show", "") == "enrolled": out.append("enrolled")
	return out

static func gene_name(id: String, g: Dictionary) -> String:
	match id:
		"eyes": return "eyes of %d lenses" % _lens_count(g)
		"stalks": return "stalked eyes"
		"trident": return "trident"
		"horns": return "ram's horns"
		"spines": return "spines"
		"pyrite": return "pyritized"
		"moult": return "its moult"
		"bite": return "healed bite"
		"soft": return "legs and antennae"
		"mass": return "a plate of %d" % int(g.mass)
		"enrolled": return "rolled up"
		"opal": return "opalized"
		"nodule": return "split nodule"
		"lilies": return "sea lilies"
		"oyster":
			var ps: Array = g.get("pearls", [])
			if ps.size() > 1: return "%d pearl oysters" % ps.size()
			var pg: Dictionary = ps[0] if ps.size() else {}
			return "%s pearl in its oyster" % SpecPearl.BODY.get(pg.get("body", "akoya"), {n = "a"}).n
	return ""

static func _lens_count(g: Dictionary) -> int:
	return 80 + int(g.get("seed", 0)) % 160

# ---------------------------------------------------------------- the body

## half-width of the outline at u (0 snout .. 1 tail end), on one side (s: -1 left, 1 right)
static func _w(f: Dictionary, c: Dictionary, u: float, s: float) -> float:
	var half: float = c.half
	var ce: float = c.ceph
	var py: float = c.pyg
	var th := 1.0 - ce - py
	var w := 0.0
	if u < ce:
		var t := (ce - u) / ce
		w = half * 1.04 * sqrt(maxf(0.0, 1.0 - t * t)) * (1.0 - 0.12 * t)
	elif u < ce + th:
		var q := (u - ce) / th * float(f.seg)
		var fr := q - floorf(q)
		w = half * (1.0 - 0.16 * (u - ce) / th) * (1.0 + float(c.tip) * fr * fr)
	else:
		var t := (u - ce - th) / py
		w = half * 0.84 * pow(maxf(0.0, 1.0 - pow(t, 2.2)), 0.55)
	# a healed bite: a W-shaped notch out of the right side, just behind the head
	if f.get("bite", false) and s > 0.0:
		var b0 := ce + th * 0.25
		var x := (u - b0) / (th * 0.28)
		if x > 0.0 and x < 1.0:
			w *= 1.0 - 0.22 * sin(x * PI) * (0.7 + 0.3 * absf(sin(x * TAU)))
	return w

## height of the shell at (u, x) over the outline (w the half-width there); returns [height, axis, groove, glabella]
static func _h(f: Dictionary, c: Dictionary, u: float, x: float, w: float) -> Array:
	var H: float = c.H
	var half: float = c.half
	var ce: float = c.ceph
	var py: float = c.pyg
	var th := 1.0 - ce - py
	var eff: float = c.eff
	var ax: float = c.ax * half
	var axw := ax
	var glab := 0.0
	if u < ce:
		# the glabella widens forward on a swollen head
		axw = ax * (1.0 + 0.35 * float(c.glab) * (1.0 - u / ce)) * (0.9 if u > ce - 0.06 else 1.0)
		glab = 1.0
	elif u > ce + th:
		axw = ax * (1.0 - 0.85 * (u - ce - th) / py)
	var xa := absf(x)
	var xn := clampf(xa / maxf(w, 0.001), 0.0, 1.0)
	var on_ax := 1.0 - smoothstep(axw * 0.8, axw * 1.15, xa)
	# the pleural fields slope down to the edge; the axis stands up rounded
	var fulc := smoothstep(0.62, 1.0, xn)
	var h := H * 0.5 * (1.0 - 0.15 * xn - 0.85 * fulc * fulc)
	h += H * 0.55 * on_ax * sqrt(maxf(0.0, 1.0 - pow(xa / maxf(axw * 1.15, 0.001), 2.0)))
	var groove := 0.0
	var fur := exp(-pow((xa - axw * 1.05) / 0.018, 2.0))
	h -= H * 0.12 * fur * eff
	groove = maxf(groove, fur * eff)
	if u < ce:
		# the swollen glabella; its furrow round the back (the occipital ring behind it)
		h += H * 0.3 * float(c.glab) * on_ax * smoothstep(0.0, 0.14, u) * (1.0 - smoothstep(ce - 0.12, ce - 0.04, u))
		var occ := exp(-pow((u - (ce - 0.065)) / 0.012, 2.0)) * on_ax
		h -= H * 0.25 * occ * eff
		groove = maxf(groove, occ * eff)
		# a raised border round the head, a furrow inside it
		var rim := exp(-pow((xn - 0.93) / 0.035, 2.0)) * (1.0 - on_ax)
		var bf := exp(-pow((xn - 0.84) / 0.035, 2.0)) * (1.0 - on_ax)
		h += H * 0.12 * rim - H * 0.1 * bf * eff
		groove = maxf(groove, bf * eff * 0.7)
		# the cheeks fall away steeply at the front
		# the head slopes down to its front border, the glabella a dome over it (no cliff at the snout)
		h *= 0.22 + 0.78 * smoothstep(0.0, ce * 0.75, u)
	elif u < ce + th:
		# thorax rings: the axial rings and, slanting back across the pleurae, the pleural furrows
		var q := (u - ce) / th * float(f.seg) + maxf(0.0, xa - axw) * 1.4 * (1.0 - on_ax)
		var fr := q - floorf(q)
		var ring := sin(PI * fr)
		h += H * 0.2 * (ring - 0.65) * eff
		var gr := (1.0 - smoothstep(0.0, 0.25, ring)) * eff
		# the pleural furrow halfway along each pleura
		var pf := exp(-pow((fr - 0.5) / 0.08, 2.0)) * (1.0 - on_ax) * smoothstep(0.2, 0.5, xn)
		h -= H * 0.06 * pf * eff
		groove = maxf(groove, maxf(gr, pf * 0.6))
	else:
		# the tail: rings fading towards its end, a smooth border
		var t := (u - ce - th) / py
		var q := t * maxf(3.0, py * 30.0) + maxf(0.0, xa - axw) * 1.2
		var ring := sin(PI * (q - floorf(q)))
		h += H * 0.15 * (ring - 0.65) * eff * (1.0 - t)
		groove = maxf(groove, (1.0 - smoothstep(0.0, 0.25, ring)) * eff * (1.0 - t))
		var bf := exp(-pow((xn - 0.82) / 0.05, 2.0)) * (1.0 - on_ax)
		h -= H * 0.05 * bf * eff
	return [h, on_ax, clampf(groove, 0.0, 1.0), glab * on_ax]

## curl along the length (enrolled): z (snout +) wraps round a circle below; k 0 flat .. 1 rolled into a ball
static func _bend(p: Vector3, k: float) -> Vector3:
	if k <= 0.0:
		return p
	var R := 1.0 / (TAU * k * 0.93)
	# the pleurae curl down round the sides too (arc length kept), closing the ball's flanks
	var rs := R / 0.55
	var ph := p.x / rs
	var q := Vector3((rs + p.y) * sin(ph), (rs + p.y) * cos(ph) - rs, p.z)
	var a := q.z / R
	return Vector3(q.x, (R + q.y) * cos(a) - R, (R + q.y) * sin(a))

## the body as one grid over its outline (u0..u1 of its length: a moult's head is apart from it), its edge
## turned under to a thin rim; a flat underside closes it. Body space: length 1 along z (snout +), y up.
static func body_geo(f: Dictionary, c: Dictionary, u0: float, u1: float, k: float) -> Geo:
	# One sheet round the whole shield, as the real one is: a thin curved shell. Across the top (|v| <= 1), its edge
	# rolling under in a rounded lip (the doublure, 1 .. 1.3), then back in under the dome (1.3 .. 2.3) — the hollow
	# underneath, here filled with the rock that set inside it (COLOR.a 0: the shader paints it as matrix)
	var g := Geo.new()
	var nu := int(150.0 * (u1 - u0)) + 20
	var nv := 104
	var vmax := 2.3
	var lip := 0.03         # the rolled rim's radius (body units)
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed)
	nz.frequency = 9.0
	for i in nu + 1:
		var u := lerpf(u0, u1, float(i) / nu)
		var env := smoothstep(0.0, 0.025, u - u0 + (0.025 if u0 <= 0.0 else 0.0)) * smoothstep(0.0, 0.025, u1 - u + (0.025 if u1 >= 1.0 else 0.0))
		if u0 <= 0.0: env = smoothstep(0.0, 0.03, u) if u < 0.03 else env
		if u1 >= 1.0 and u > 0.97: env = smoothstep(1.0, 0.97, u)
		for j in nv + 1:
			var v := -vmax + 2.0 * vmax * float(j) / nv
			var s := signf(v) if v != 0.0 else 1.0
			var av := absf(v)
			var w := _w(f, c, u, s)
			var x := 0.0
			var y := 0.0
			var hh := _h(f, c, u, s * minf(av, 1.0) * w, w)
			var top: float = float(hh[0]) * env + 0.004 * nz.get_noise_2d(u * 3.0, s * minf(av, 1.0) * w * 3.0)
			var under := 1.0
			if av <= 1.0:
				x = s * av * w
				y = top
			elif av <= 1.3:
				# the lip: out a hair, round and under, ending a little way in
				var ph := (av - 1.0) / 0.3 * PI
				x = s * (w + lip * 0.5 * sin(ph) - lip * 0.8 * (1.0 - cos(ph)) * 0.5)
				y = top - lip * (1.0 - cos(ph))
			else:
				# under the dome, back in to the middle line: following the shield's curve, a shell's thickness below it
				var t := (av - 1.3) / (vmax - 1.3)
				var xi := w - lip * 0.8
				x = s * xi * (1.0 - t)
				var hu := _h(f, c, u, x, w)
				y = (float(hu[0]) * env) * 0.55 - lip * 2.0 * (1.0 - t * 0.5)
				under = 0.0
			# (the ends of the body: the whole section closes down to the rim)
			if env < 1.0:
				y = lerpf(-lip * 2.0, y, env)
			var p := Vector3(x, y, 0.5 - u)
			g.v.append(_bend(p, k))
			# UV: the flat body position (granules, lenses keep their size); UV2.x: along the body
			g.rp.append(Vector3(x, 0.5 - u, u))
			if under > 0.5:
				g.col.append(Color(float(hh[1]), float(hh[2]), float(hh[3]), 1.0))
			else:
				g.col.append(Color(0, 0, 0, 0.0))
	_grid(g, 0, nu, nv)
	return g

## indices of a grid (rows of nv+1 points from base), wound to face +y (Geo's normals: (c-b) x (a-b))
static func _grid(g: Geo, base: int, nu: int, nv: int) -> void:
	for i in nu:
		for j in nv:
			var a := base + i * (nv + 1) + j
			var b := a + 1
			var cc := a + nv + 1
			var d := cc + 1
			g.idx.append_array([a, b, cc, cc, b, d])

## a tapering tube along pts (radius r0 at the start to r1 at the end), its far end closed in a point
static func spine_geo(pts: Array, r0: float, r1: float, m := 7) -> Geo:
	var g := Geo.new()
	var n := pts.size()
	var prev_side := Vector3.RIGHT
	for i in n:
		var p: Vector3 = pts[i]
		var t := ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var side := prev_side - t * prev_side.dot(t)
		if side.length_squared() < 1e-6: side = t.cross(Vector3.UP)
		side = side.normalized()
		prev_side = side
		var up := t.cross(side)
		var r := lerpf(r0, r1, pow(float(i) / (n - 1), 0.8))
		if i == n - 1: r = 0.0
		for j in m + 1:
			var a := TAU * float(j) / m
			g.v.append(p + (side * cos(a) + up * sin(a)) * r)
			g.rp.append(Vector3(p.x, p.z, 0.5))
			g.col.append(Color(0.6, 0.0, 0.0, 1.0))
	for i in n - 1:
		for j in m:
			var a := i * (m + 1) + j
			g.idx.append_array([a, a + m + 1, a + 1, a + 1, a + m + 1, a + m + 2])
	return g

## an eye, closed all round and sunk into the cheek at its foot (no gap under it): a kidney-shaped dome, longer
## along the body than across it — tall for schizochroal eyes (lens / tower), low for holochroal ones (crescent) —
## or a round bulb on a stalk's tip (bulb). Body space, round `at`, its outer side towards s. UV.x runs round it
## (the outer side is 0.29 .. 0.71: the shader lays the lenses only there), UV.y up it.
static func eye_geo(c: Dictionary, at: Vector3, s: float, kind: String) -> Geo:
	var g := Geo.new()
	var r: float = c.eye_r
	var na := 28
	var ne := 12
	var dims := Vector3(0.75, 1.15, 1.5)
	var el0 := -0.35
	match kind:
		"crescent": dims = Vector3(0.7, 0.75, 1.55)
		"bulb":
			dims = Vector3(1.0, 0.95, 1.1)
			el0 = -PI * 0.5
	for i in ne + 1:
		var el := lerpf(el0, PI * 0.5, float(i) / ne)
		for j in na + 1:
			var a := -PI + TAU * float(j) / na
			var p := Vector3(s * cos(a) * cos(el) * r * dims.x, sin(el) * r * dims.y, sin(a) * cos(el) * r * dims.z)
			g.v.append(at + p)
			g.rp.append(Vector3(float(j) / na, float(i) / ne, 1.0))
			g.col.append(Color(0, 0, 0, 1))
	for i in ne:
		for j in na:
			var a := i * (na + 1) + j
			var b := a + 1
			var cc := a + na + 1
			var d := cc + 1
			if s > 0.0: g.idx.append_array([a, cc, b, b, cc, d])
			else: g.idx.append_array([a, b, cc, cc, b, d])
	return g

## the material: part 0 shell, 1 eye, 2 the rock of a pedestal
static func mat(f: Dictionary, part: int, rock: String) -> ShaderMaterial:
	var pal: Dictionary = PAL[int(f.pal)]
	var c: Dictionary = GENUS[f.genus]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("part", part)
	m.set_shader_parameter("base_col", Color.hex(int(pal.base) << 8 | 0xff))
	m.set_shader_parameter("dark_col", Color.hex(int(pal.dark) << 8 | 0xff))
	m.set_shader_parameter("metal_k", pal.metal)
	m.set_shader_parameter("rough_k", pal.rough)
	m.set_shader_parameter("film_k", pal.film)
	m.set_shader_parameter("opal_k", pal.get("opal", 0.0))
	m.set_shader_parameter("opal_h", float(int(f.seed) % 7) / 7.0)
	m.set_shader_parameter("tub_k", c.tub)
	m.set_shader_parameter("lens_on", 1.0)
	# (lenses round the whole of UV.x; only its outer 0.42 carries them)
	m.set_shader_parameter("lens_n", Vector2(44.0, 9.0) if c.eye in ["lens", "tower"] else Vector2(90.0, 14.0))
	m.set_shader_parameter("rock_col", Color.hex(int(ROCK_COL.get(rock, 0x777068)) << 8 | 0xff))
	m.set_shader_parameter("dirt_k", 0.45 if f.show in ["matrix", "mass", "prepared"] else 0.2)
	m.set_shader_parameter("seed", float(int(f.seed) % 991) * 0.13)
	var sn: String = pal.scan
	m.set_shader_parameter("scan_tex", load("res://assets/textures/%s/%s_diff_1k.jpg" % [sn, sn]))
	m.set_shader_parameter("scan_k", pal.scan_k)
	var rn: String = SpecMat.SCANS[RockKit.SCAN_OF.get(rock, 0)]
	m.set_shader_parameter("rock_tex", load("res://assets/textures/%s/%s_diff_1k.jpg" % [rn, rn]))
	return m

# ---------------------------------------------------------------- building

## one whole trilobite under `parent`, in body space (length 1); its parts' points come back for callouts
static func animal(f: Dictionary, parent: Node3D, sm: ShaderMaterial, em: ShaderMaterial, k: float, u0 := 0.0, u1 := 1.0) -> Dictionary:
	var c: Dictionary = GENUS[f.genus]
	var rng := Rng32.new(int(f.seed) * 13 + 5)
	var out := {}
	var body := U.mesh(body_geo(f, c, u0, u1, k), sm, parent)
	body.set_meta("col", true)
	body.set_meta("sea_light", true)
	# an unseen block under it, down into the rock: what the builder grows on the rock afterwards (puffs, lichen,
	# flowers) keeps out of the crystals' boxes, and this makes the trilobite one
	if u0 <= 0.0 and k <= 0.0:
		var ko := U.mesh(Geo.box(float(c.half) * 2.2, 0.36, 1.08), sm, parent, Vector3(0, -0.14, 0))
		ko.visible = false
		ko.set_meta("col", true)
	out.body = body
	if u0 > 0.0:
		return out
	var ce: float = c.ceph
	var half: float = c.half
	var H: float = c.H
	var sp: float = f.spines
	var spines: Array = []
	var ax: float = float(c.ax) * half
	# the eyes, at the sides of the glabella
	var ue := ce * 0.55
	var eye_pts := []
	for s: float in [-1.0, 1.0]:
		var xe := s * minf(ax * 1.45 + float(c.eye_r) * 0.5, _w(f, c, ue, s) * 0.7)
		var hh := _h(f, c, ue, xe, _w(f, c, ue, s))
		var at := Vector3(xe, float(hh[0]) - float(c.eye_r) * 0.2, 0.5 - ue)
		match String(c.eye):
			"stalk", "tower":
				var ln: float = float(c.get("stalk", 0.06)) * (1.0 if c.eye == "stalk" else 1.0)
				var pts := []
				for q in 7:
					var t := float(q) / 6.0
					pts.append(at + Vector3(s * t * ln * 0.18, t * ln, -t * t * ln * 0.12))
				# (its open foot buried in the head, swelling out of it)
				pts.insert(0, at - Vector3(0, float(c.eye_r) * 0.8, 0))
				spines.append(spine_geo(pts, float(c.eye_r) * 0.75, float(c.eye_r) * 0.4, 8))
				var top: Vector3 = pts[pts.size() - 1]
				var e := eye_geo(c, top + Vector3(0, float(c.eye_r) * 0.35, 0), s, "lens" if c.eye == "tower" else "bulb")
				eye_pts.append(top)
				_add_bent(e, em, parent, k)
			_:
				_add_bent(eye_geo(c, at, s, String(c.eye)), em, parent, k)
				eye_pts.append(at + Vector3(s * float(c.eye_r) * 0.6, float(c.eye_r) * 0.6, 0))
	out.eyes = eye_pts
	var tips := []
	# genal spines from the head's back corners, swept back along the sides
	if float(c.gspine) > 0.0:
		for s: float in [-1.0, 1.0]:
			var w := _w(f, c, ce - 0.01, s)
			var p0 := Vector3(s * w * 0.97, 0.0, 0.5 - ce + 0.03)
			var ln: float = float(c.gspine) * sp
			var pts := []
			for q in 8:
				var t := float(q) / 7.0
				pts.append(p0 + Vector3(s * (0.04 * t - 0.02 * t * t) * ln * 2.0, -0.01 * t, -t * ln))
			spines.append(spine_geo(pts, 0.022, 0.004))
			tips.append(pts[pts.size() - 1])
	# pleural spines: long, out and back and curving down
	if c.has("pspine"):
		var th := 1.0 - ce - float(c.pyg)
		for i in int(f.seg):
			var u := ce + th * (float(i) + 0.95) / float(f.seg)
			for s: float in [-1.0, 1.0]:
				var w := _w(f, c, u, s)
				var p0 := Vector3(s * w * 0.95, -0.005, 0.5 - u)
				var ln: float = float(c.pspine) * sp * (0.75 + 0.35 * sin(PI * float(i) / float(f.seg)) + (rng.next() - 0.5) * 0.12)
				var pts := []
				for q in 7:
					var t := float(q) / 6.0
					pts.append(p0 + Vector3(s * (0.75 * t - 0.25 * t * t) * ln, -0.55 * t * t * ln, -(0.25 * t + 0.35 * t * t) * ln))
				spines.append(spine_geo(pts, 0.012, 0.003, 6))
				if i == int(f.seg) / 2: tips.append(pts[pts.size() - 1])
	# a row of spines up the axis
	if c.has("dorsal"):
		var th := 1.0 - ce - float(c.pyg)
		for i in int(f.seg) + 1:
			var u := ce - 0.04 + th * float(i) / float(f.seg)
			var hh := _h(f, c, u, 0.0, _w(f, c, u, 1.0))
			var p0 := Vector3(0, float(hh[0]) - 0.01, 0.5 - u)
			var ln: float = float(c.dorsal) * sp * (0.8 + 0.4 * rng.next())
			spines.append(spine_geo([p0, p0 + Vector3(0, 0.55, -0.12) * ln, p0 + Vector3(0, 1.0, -0.35) * ln], 0.01, 0.002, 6))
	# the trident: a rod forward off the snout, splitting into three tines
	if c.has("trident"):
		var hh := _h(f, c, 0.06, 0.0, _w(f, c, 0.06, 1.0))
		var p0 := Vector3(0, float(hh[0]) * 0.8, 0.44)
		var ln: float = float(c.trident) * sp
		var rod := []
		for q in 6:
			var t := float(q) / 5.0
			rod.append(p0 + Vector3(0, (0.25 * t + 0.1 * t * t) * ln, 0.6 * t * ln))
		spines.append(spine_geo(rod, 0.016, 0.012))
		var fork: Vector3 = rod[rod.size() - 1]
		for s: float in [-1.0, 0.0, 1.0]:
			var pts := [fork]
			for q in range(1, 6):
				var t := float(q) / 5.0
				pts.append(fork + Vector3(s * 0.14 * sin(t * 1.4) * ln, (0.12 * t - 0.05 * t * t) * ln, (0.35 * t - absf(s) * 0.08 * t * t) * ln))
			spines.append(spine_geo(pts, 0.011, 0.003))
		tips.append(fork)
		out.trident = fork
	# ram's horns off the back of the head, curling back and down beside the thorax
	if c.has("horns"):
		for s: float in [-1.0, 1.0]:
			var hu := ce - 0.07
			var hw := _w(f, c, hu, s)
			var p0 := Vector3(s * ax * 0.7, float(_h(f, c, hu, s * ax * 0.7, hw)[0]) - 0.012, 0.5 - hu)
			var pts := []
			for q in 14:
				var t := float(q) / 13.0
				var ph := t * PI * 1.55
				var rr := 0.17 * sp * (1.0 - 0.4 * t)
				# the curl's plane leans out over the side, so the horn comes down beside the thorax
				var up := Vector3(s * 0.75, 0.65, 0.0)
				pts.append(p0 + Vector3(s * (0.02 + 0.06 * t) * sp, 0, 0) + up * rr * sin(ph) + Vector3(0, 0, -rr * (1.0 - cos(ph)) * 0.9))
			spines.append(spine_geo(pts, 0.032, 0.006, 8))
			tips.append(pts[7])
		out.horns = tips[tips.size() - 1]
	# two long spines off the tail
	if c.has("pygs"):
		for s: float in [-1.0, 1.0]:
			var p0 := Vector3(s * half * 0.35, -0.005, -0.5 + float(c.pyg) * 0.4)
			var ln: float = float(c.pygs) * sp
			spines.append(spine_geo([p0, p0 + Vector3(s * 0.25, -0.05, -0.5) * ln, p0 + Vector3(s * 0.35, -0.2, -1.0) * ln], 0.016, 0.003))
	for sg: Geo in spines:
		_add_bent(sg, sm, parent, k)
	out.tips = tips
	return out

static func _add_bent(g: Geo, m: Material, parent: Node3D, k: float) -> MeshInstance3D:
	if k > 0.0:
		for i in g.v.size():
			g.v[i] = _bend(g.v[i], k)
	var mi := U.mesh(g, m, parent)
	mi.set_meta("col", true)
	return mi

## its legs and antennae, kept in pyrite: each on its own pivot (the legendary awakening swings them)
static func legs(f: Dictionary, parent: Node3D, sm: ShaderMaterial) -> Array:
	var c: Dictionary = GENUS[f.genus]
	var ce: float = c.ceph
	var th := 1.0 - ce - float(c.pyg)
	var pivots := []
	var n := int(f.seg) + 4
	for i in n:
		var u := ce * 0.55 + (th + ce * 0.45 + float(c.pyg) * 0.5) * (float(i) + 0.5) / float(n)
		for s: float in [-1.0, 1.0]:
			var w := _w(f, c, u, s)
			var piv := Node3D.new()
			piv.position = Vector3(s * w * 0.55, -THICK * 0.6, 0.5 - u)
			parent.add_child(piv)
			var ln := w * 0.55 + 0.05
			var pts := []
			for q in 6:
				var t := float(q) / 5.0
				pts.append(Vector3(s * t * ln, -0.008 * t - 0.02 * t * t, -0.05 * t * t))
			var lm := U.mesh(spine_geo(pts, 0.007, 0.0025, 5), sm, piv)
			lm.set_meta("col", true)
			pivots.append([piv, float(i), s, false])
	for s: float in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(s * 0.04, -THICK * 0.5, 0.47)
		parent.add_child(piv)
		var pts := []
		for q in 12:
			var t := float(q) / 11.0
			pts.append(Vector3(s * (0.08 * t + 0.12 * t * t), -0.01 * t, 0.42 * t))
		var am := U.mesh(spine_geo(pts, 0.006, 0.0015, 5), sm, piv)
		am.set_meta("col", true)
		pivots.append([piv, 0.0, s, true])
	return pivots

static func build(b: RefCounted, gene: Dictionary, use_rock: Callable) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 7 + 3)
	var root: Node3D = b.root
	var gs: float = gene.scale
	var rock: String = gene.rock
	var sm := mat(f, 0, rock)
	var em := mat(f, 1, rock)
	var show: String = f.show
	var holder := Node3D.new()
	root.add_child(holder)
	var main: Dictionary = {}
	var walkers := []
	var marks := {}
	match show:
		"matrix", "mass":
			var rk: MeshInstance3D = use_rock.call("slab")
			rk.set_meta("sea_light", true)
			var rb: AABB = rk.transform * (rk.get_meta("geo") as Geo).aabb()
			var top := rb.end.y - rb.size.y * 0.1
			var span := minf(rb.size.x, rb.size.z)
			var n := int(f.mass) if show == "mass" else 1
			var placed := []
			var bodies: Array[Node3D] = []
			for q in n:
				var s := span * (0.82 if n == 1 else 0.3 + rng.next() * 0.28)
				if f.get("moult", false) and n == 1: s = span * 0.6
				# room for the oyster: the trilobite a little smaller, to one side
				if int(f.get("oysters", 0)) > 0 and n == 1: s = span * (0.66 - 0.04 * int(f.oysters))
				var at := Vector3(rb.get_center().x, top, rb.get_center().z)
				if n > 1:
					for tries in 20:
						at = Vector3(rb.get_center().x + (rng.next() - 0.5) * rb.size.x * 0.62, top, rb.get_center().z + (rng.next() - 0.5) * rb.size.z * 0.62)
						var ok := true
						for p: Array in placed:
							if Vector2(at.x - (p[0] as Vector3).x, at.z - (p[0] as Vector3).z).length() < (s + float(p[1])) * 0.36: ok = false
						if ok: break
				if f.get("moult", false): at.x -= span * 0.14
				if int(f.get("oysters", 0)) > 0 and n == 1: at.x -= span * 0.12
				placed.append([at, s])
				var nd := Node3D.new()
				holder.add_child(nd)
				# lying on its rock, head away from the viewer, a little sunk in
				# on the rock's own surface under it (a bulge would swallow its sides, a hollow leave it floating)
				at.y = _ground(rk, at, s * 0.3) + 0.02 * s
				nd.transform = Transform3D(Basis(Vector3.UP, PI + (rng.next() - 0.5) * (0.6 if n == 1 else TAU)) * Basis.from_scale(Vector3.ONE * s), at)
				bodies.append(nd)
				var fq := f.duplicate()
				if q > 0: fq.seed = int(f.seed) + q * 31
				var a := animal(fq, nd, sm, em, 0.0)
				if q == 0:
					main = a
					main.node = nd
					if f.get("soft", false):
						walkers = legs(f, nd, sm)
						marks.soft = nd
				elif q == 1:
					marks.mass = nd
			# the moult beside it: the thorax and tail it shed, the head come away and turned over
			if f.get("moult", false):
				var md := Node3D.new()
				holder.add_child(md)
				var ms := span * 0.52
				md.transform = Transform3D(Basis(Vector3.UP, PI + 0.5 + rng.next() * 0.6) * Basis.from_scale(Vector3.ONE * ms), Vector3(rb.get_center().x + span * 0.24, top - THICK * ms * 0.5, rb.get_center().z + span * 0.08))
				var c: Dictionary = GENUS[f.genus]
				var fm := f.duplicate()
				fm.bite = false
				animal(fm, md, sm, em, 0.0, float(c.ceph) - 0.02, 1.0)
				var hd := Node3D.new()
				holder.add_child(hd)
				hd.transform = Transform3D(Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * ms), Vector3(rb.get_center().x + span * 0.3, top, rb.get_center().z - span * 0.22))
				animal(fm, hd, sm, em, 0.0, 0.0, float(c.ceph) - 0.03)
				marks.moult = md
			# the sea floor it lay on. What lies on the slab keeps its room: the trilobites (a chain of discs along each),
			# then the oysters, then the sea lilies, each put only on the slab's top where nothing is yet
			var lrng := Rng32.new(int(f.seed) * 17 + 5)
			var c: Dictionary = GENUS[f.genus]
			var occ := []
			for nd: Node3D in bodies:
				var sc := nd.transform.basis.get_scale().x
				var reach := float(c.half) * 1.1 + float(c.get("pspine", 0.0)) * 0.5
				for u: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
					var p := nd.transform * Vector3(0, 0, 0.5 - u)
					occ.append([Vector2(p.x, p.z), reach * sc])
			if f.get("moult", false):
				occ.append([Vector2(rb.get_center().x + span * 0.26, rb.get_center().z), span * 0.25])
			var cands := _top_spots(rk, rb)
			var spots := []
			# pearl oysters: open ones breathe and now and then snap shut; shut ones now and then gape, the pearl inside
			var oys_n := 0
			for fp: Dictionary in f.get("pearls", []):
				var os := span * (0.15 + lrng.next() * 0.04)
				# a few free spots (a crowded slab gets smaller oysters rather than none); of them the one where the
				# oyster sits flattest: seated so its cupped valve clears every bump of the rock under it
				var yaw := PI + (lrng.next() - 0.5) * 0.9
				var best: Array = []
				for shrink: float in [1.0, 0.8, 0.62]:
					for tries in 8:
						var spot: Variant = _free_spot(cands, occ, os * shrink * 1.15, lrng)
						if spot == null: break
						var seat := _seat(rk, spot as Vector3, yaw, os * shrink)
						if best.is_empty() or float(seat[1]) < float(best[1]):
							best = [spot, seat[1], seat[0], shrink]
					if not best.is_empty(): break
				if best.is_empty(): continue
				os *= float(best[3])
				var oat: Vector3 = best[0]
				oat.y = float(best[2])
				var on := Node3D.new()
				holder.add_child(on)
				on.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * os), oat)
				var ppm := SpecPearl.mat(fp, 0)
				# the legendary moon pearl: the pearls glow, the first lights its oyster and the slab
				if gene.fx == "moon": ppm.set_shader_parameter("moon_k", 1.0)
				# (a moon pearl's oyster lies open: its light is the point)
				var opened: bool = fp.get("open", true) or (gene.fx == "moon" and oys_n == 0)
				var oys := SpecPearl.oyster(on, fp, ppm, SpecPearl.pearl_geo(String(fp.shape), int(fp.seed)), lrng, true, 0.72, opened)
				if gene.fx == "moon":
					SpecPearl.moon_glow(root, on, (oys.pearls as Array)[0] as Node3D, span * (0.9 if oys_n == 0 else 0.5))
				var oc := oat + Basis(Vector3.UP, yaw) * Vector3(0, 0, -0.25 * os)
				occ.append([Vector2(oc.x, oc.z), os * 1.15])
				if oys_n == 0: marks.oyster = (oys.pearls as Array)[0]
				spots.append(oat + Vector3(0, os * 0.15, 0))
				oys_n += 1
			# sea lilies swaying on their stalks
			var lm := SpecSea.life_mat(0, span * 0.45, span * 0.03, 0.8, 0.55, 0.4)
			for k in 2 + int(lrng.next() * 3.0):
				var spot: Variant = _free_spot(cands, occ, span * 0.06, lrng, rb.get_center().z - rb.size.z * 0.05)
				if spot == null: break
				var at: Vector3 = spot
				at.y = _ground(rk, at, span * 0.05) - span * 0.01
				var li := U.mesh(SpecSea.lily(lrng, span * (0.35 + lrng.next() * 0.2)), lm, holder, at, Basis(Vector3.UP, (lrng.next() - 0.5) * 0.8))
				li.set_meta("col", true)
				occ.append([Vector2(at.x, at.z), span * 0.06])
				spots.append(at)
				if k == 0: marks.lilies = li
			if spots.size():
				SpecSea.bubbles(holder, spots, Vector3.UP, span * 1.2, span * 0.012, 5)
		"prepared":
			# prepared the Moroccan way: standing proud on an oval of its matrix, the matrix round it carved down
			# with an air-pen — a pale plate covered in wormy tool marks
			var s := gs * 2.2
			var nd := Node3D.new()
			holder.add_child(nd)
			nd.transform = Transform3D(Basis(Vector3.UP, PI + (rng.next() - 0.5) * 0.5) * Basis.from_scale(Vector3.ONE * s), Vector3.ZERO)
			main = animal(f, nd, sm, em, 0.0)
			main.node = nd
			var pm := ShaderMaterial.new()
			pm.shader = PLATE
			pm.set_shader_parameter("rock_col", Color.hex(0x8c806eff))
			pm.set_shader_parameter("seed", float(int(f.seed) % 97))
			var rn: String = SpecMat.SCANS[RockKit.SCAN_OF.get(rock, 0)]
			pm.set_shader_parameter("rock_tex", load("res://assets/textures/%s/%s_diff_1k.jpg" % [rn, rn]))
			var pi := U.mesh(_plate(f), pm, nd)
			pi.set_meta("col", true)
		"nodule":
			# a concretion split open: the trilobite in one half, its mould in the other, both faces showing the
			# rings of the nodule and its septarian veins; calcite crystals grown in a pocket of the mould half
			var s := gs * 1.25
			var c: Dictionary = GENUS[f.genus]
			var rx: float = float(c.half) + 0.22
			var rz := 0.68
			var fm := ShaderMaterial.new()
			fm.shader = PLATE
			fm.set_shader_parameter("mode", 2)
			fm.set_shader_parameter("rock_col", Color.hex(0x8a6c4cff))
			fm.set_shader_parameter("seed", float(int(f.seed) % 97))
			var dm := mat(f, 2, "ironstone")
			for half in 2:
				var hn := Node3D.new()
				holder.add_child(hn)
				var side := -1.0 if half == 0 else 1.0
				hn.transform = Transform3D(Basis(Vector3.UP, PI + side * 0.1) * Basis(Vector3.BACK, -side * 0.12) * Basis.from_scale(Vector3.ONE * s), Vector3(side * s * (rx + 0.06), 0, 0))
				var face := U.mesh(_nodule_face(f, c, rx, rz, half == 1), fm, hn)
				face.set_meta("col", true)
				face.set_meta("sea_light", true)
				var dome := U.mesh(_nodule_dome(f, rx, rz), dm, hn)
				dome.set_meta("col", true)
				if half == 0:
					var nd := Node3D.new()
					hn.add_child(nd)
					nd.position = Vector3(0, 0.004, 0)
					main = animal(f, nd, sm, em, 0.0)
					main.node = nd
				else:
					_pocket(b, f, hn, Vector3(rx * 0.35, 0.0, -rz * 0.62))
					marks.nodule = hn
		"enrolled":
			var nd := Node3D.new()
			holder.add_child(nd)
			nd.transform = Transform3D(Basis(Vector3.UP, 0.5 + (rng.next() - 0.5) * 0.6) * Basis(Vector3.RIGHT, -0.35) * Basis.from_scale(Vector3.ONE * gs * 2.6), Vector3.ZERO)
			main = animal(f, nd, sm, em, 1.08)
			main.node = nd
			marks.enrolled = nd
		_:
			pass
	# the legendary awakening: the pyrite legs walk in a wave down the body, the antennae feel about
	if gene.fx == "awaken" and main.has("node"):
		if walkers.is_empty():
			walkers = legs(f, main.node as Node3D, sm)
		var wk := Walker.new()
		wk.pivots = walkers
		holder.add_child(wk)
		# and it crawls: to and fro across its rock, turning a little as it goes
		if show in ["matrix", "mass", "prepared"]:
			wk.body = main.node
			wk.base = (main.node as Node3D).transform
	var nd0: Node3D = main.node
	var xf := U.rel_xform(nd0, root)
	for p: Vector3 in main.get("eyes", []):
		if "eyes" in gene.accents: b._mark("eyes", xf * p, (xf.basis * Vector3(signf(p.x), 1, 0)).normalized())
		if "stalks" in gene.accents: b._mark("stalks", xf * p, (xf.basis * Vector3.UP).normalized())
	var tips: Array = main.get("tips", [])
	if tips.size():
		if "spines" in gene.accents: b._mark("spines", xf * (tips[tips.size() - 1] as Vector3), (xf.basis * Vector3.UP).normalized())
		if "trident" in gene.accents and main.has("trident"): b._mark("trident", xf * (main.trident as Vector3), (xf.basis * Vector3.UP).normalized())
		if "horns" in gene.accents and main.has("horns"): b._mark("horns", xf * (main.horns as Vector3), (xf.basis * Vector3.UP).normalized())
	if "pyrite" in gene.accents: b._mark("pyrite", xf * Vector3(0, 0.1, 0.0), (xf.basis * Vector3.UP).normalized())
	if "bite" in gene.accents:
		var c: Dictionary = GENUS[f.genus]
		var u := float(c.ceph) + (1.0 - float(c.ceph) - float(c.pyg)) * 0.39
		b._mark("bite", xf * Vector3(_w(f, c, u, 1.0), 0.02, 0.5 - u), (xf.basis * Vector3(1, 1, 0)).normalized())
	if marks.has("lilies") and "lilies" in gene.accents:
		var lx := U.rel_xform(marks.lilies as Node3D, root)
		b._mark("lilies", lx * Vector3(0, 0.3, 0), (lx.basis * Vector3.UP).normalized())
	marks.erase("lilies")
	if marks.has("oyster") and "oyster" in gene.accents:
		var ox := U.rel_xform(marks.oyster as Node3D, root)
		b._mark("oyster", ox * Vector3(0, 0.8, 0.4), (ox.basis * Vector3.UP).normalized())
	marks.erase("oyster")
	if "opal" in gene.accents: b._mark("opal", xf * Vector3(0.12, 0.1, -0.05), (xf.basis * Vector3.UP).normalized())
	for id: String in ["moult", "mass", "enrolled", "soft", "nodule"]:
		if marks.has(id):
			var mx := U.rel_xform(marks[id] as Node3D, root)
			var p := Vector3(0, 0.12, 0) if id != "soft" else Vector3(0.45, 0.0, 0.1)
			b._mark(id, mx * p, (mx.basis * Vector3.UP).normalized())
	return main.body

## the height of the rock's top round (at.x, at.z) within r: high, but not its highest knob
static func _ground(rk: MeshInstance3D, at: Vector3, r: float) -> float:
	var g: Geo = rk.get_meta("geo")
	var ys: Array[float] = []
	for v in g.v:
		var w := rk.transform * v
		if Vector2(w.x - at.x, w.z - at.z).length() < r:
			ys.append(w.y)
	if ys.size() < 4:
		return at.y
	ys.sort()
	return ys[int(ys.size() * 0.8)]

## where a pearl oyster (hinge at `at`, turned `yaw`, size os) must sit so its cupped lower valve clears the rock:
## for each rock point under it, the height that puts the valve's underside just above it; returns [that height,
## how far it then floats above the rock on average — smaller is flatter]
static func _seat(rk: MeshInstance3D, at: Vector3, yaw: float, os: float) -> Array:
	var g: Geo = rk.get_meta("geo")
	var inv := Basis(Vector3.UP, yaw).inverse()
	var top := -INF
	var need: Array[float] = []
	for v in g.v:
		var w := rk.transform * v
		var l := inv * (w - Vector3(at.x, 0, at.z)) / os
		if Vector2(l.x, l.z).length() > 1.15 or l.z > SpecPearl.ZH:
			continue
		# the valve's underside there is outer_y below the hinge
		var h := w.y + SpecPearl._outer_y(l.x, l.z) * os
		need.append(h)
		top = maxf(top, h)
	if need.is_empty():
		return [_ground(rk, at, os * 0.8) + DEPTH_ON * os, 1e9]
	var gap := 0.0
	for h in need: gap += top - h
	return [top + 0.01 * os, gap / need.size()]

## spots on the slab's top to set things on: the rock's own vertices up on its top, away from its edge
static func _top_spots(rk: MeshInstance3D, rb: AABB, inner := 0.4) -> Array:
	var out := []
	var g: Geo = rk.get_meta("geo")
	var cx := rb.get_center()
	for v in g.v:
		var w := rk.transform * v
		if w.y < rb.end.y - rb.size.y * 0.35:
			continue
		if pow((w.x - cx.x) / (rb.size.x * inner), 2.0) + pow((w.z - cx.z) / (rb.size.z * inner), 2.0) > 1.0:
			continue
		out.append(w)
	return out

## a spot from cands with a disc of radius r clear of every disc in occ ([centre (x, z), radius]), or null
## behind: only spots behind z (further from the viewer: tall things there rise clear of the trilobite, not over it)
static func _free_spot(cands: Array, occ: Array, r: float, rng: Rng32, behind := INF) -> Variant:
	if cands.is_empty():
		return null
	for tries in 60:
		var p: Vector3 = cands[int(rng.next() * cands.size())]
		var ok := p.z < behind
		for o: Array in occ:
			if Vector2(p.x, p.z).distance_to(o[0] as Vector2) < r + float(o[1]):
				ok = false
				break
		if ok:
			return p
	return null

## the camera looks nearly level: a flat slab would be seen edge on. Hold the whole find up to the viewer
## (its rock, what grew on it, the callouts' points) like a plate on a stand
static func lean(b: RefCounted, gene: Dictionary) -> void:
	var f: Dictionary = gene.fossil
	var a: float = {matrix = 0.95, mass = 1.0, prepared = 0.85, nodule = 0.85}.get(f.show, 0.0)
	if a == 0.0:
		b.root.set_meta("sea", true)
		return
	var root: Node3D = b.root
	root.set_meta("face", true)
	root.set_meta("sea", true)
	var pv := Node3D.new()
	var kids := root.get_children()
	root.add_child(pv)
	pv.basis = Basis(Vector3.RIGHT, a)
	root.set_meta("sea_floor", pv)
	for k: Node in kids:
		k.reparent(pv, false)
	var grown: Dictionary = b.grown
	for id: String in grown:
		for m: Array in grown[id]:
			m[0] = pv.basis * (m[0] as Vector3)
			m[1] = pv.basis * (m[1] as Vector3)

## the oval plate of matrix under a prepared trilobite (body space): its top a little below the shell's rim, rising
## to meet it under the body, its edge rounded down; UV the flat position (the shader carves the tool marks by it)
static func _plate(f: Dictionary) -> Geo:
	var c: Dictionary = GENUS[f.genus]
	var g := Geo.new()
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed) + 9
	nz.frequency = 2.5
	var nb := FastNoiseLite.new()
	nb.seed = int(f.seed) + 19
	nb.frequency = 7.0
	var na := 72
	var nr := 36        # the carved top, out to its rounded edge
	var ns := 7         # the broken side going down
	var nd := 8         # the underside back in to the middle
	var depth := 0.3
	var ra := 0.5 + float(c.get("gspine", 0.0)) * 0.3 + 0.16
	var rb := float(c.half) + float(c.get("pspine", 0.0)) * 0.6 + 0.16
	for i in nr + ns + nd + 1:
		for j in na + 1:
			var a := TAU * float(j) / na
			var wob := 1.0 + 0.07 * nz.get_noise_1d(a * 2.0)
			var x := 0.0
			var z := 0.0
			var y := 0.0
			var rough := 0.0
			if i <= nr:
				var t := float(i) / nr
				var e := minf(t / 0.88, 1.0)
				x = sin(a) * rb * e * wob
				z = cos(a) * ra * e * wob
				# under the body it rises to the shell's underside; out on the plate it lies lower; at the edge it rounds over
				var u := clampf(0.5 - z, 0.0, 1.0)
				var inside := 1.0 - smoothstep(0.85, 1.25, absf(x) / maxf(_w(f, c, u, signf(x) if x != 0.0 else 1.0), 0.01)) if z > -0.5 and z < 0.5 else 0.0
				y = -THICK * 1.1 - 0.035 * (1.0 - inside) + 0.01 * nz.get_noise_2d(x * 6.0, z * 6.0)
				if t > 0.88:
					var r := (t - 0.88) / 0.12
					y -= 0.05 * (1.0 - cos(r * PI * 0.5))
					x *= 1.0 + 0.03 * r
					z *= 1.0 + 0.03 * r
				var near := 1.0 - smoothstep(0.95, 1.5, absf(x) / maxf(_w(f, c, u, signf(x) if x != 0.0 else 1.0), 0.01)) if z > -0.55 and z < 0.55 else 0.0
				g.col.append(Color(near, 0, 0, 1))
			elif i <= nr + ns:
				# the side: broken stone, bulging and stepping in and out as it goes down, a little wider at the foot
				var t := float(i - nr) / ns
				var k := 1.03 + 0.05 * t + 0.07 * nb.get_noise_2d(a * 4.0, t * 3.0) + 0.04 * nb.get_noise_2d(a * 13.0, t * 9.0)
				x = sin(a) * rb * wob * k
				z = cos(a) * ra * wob * k
				y = -THICK * 1.1 - 0.035 - 0.05 - t * (depth - 0.085) + 0.02 * nb.get_noise_2d(a * 6.0, 7.0) * t
				rough = 1.0
				g.col.append(Color(0, 0, 1, 1))
			else:
				# the underside: uneven, lumpy, back in to the middle
				var t := 1.0 - float(i - nr - ns) / nd
				var k := (1.08 + 0.07 * nb.get_noise_2d(a * 4.0, 3.0)) * t
				x = sin(a) * rb * wob * k
				z = cos(a) * ra * wob * k
				y = -THICK * 1.1 - depth - 0.03 * nb.get_noise_2d(x * 5.0, z * 5.0) - 0.02 * (1.0 - t)
				g.col.append(Color(0, 0, 1, 1))
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(x, z, rough))
	_grid(g, 0, nr + ns + nd, na)
	return g

## a split face of the nodule (ellipse rx by rz, face up at y 0): its mould half pressed with the trilobite's
## impression (the body's own heights, sunk in); COLOR.r the shade under the body, COLOR.g the mould
static func _nodule_face(f: Dictionary, c: Dictionary, rx: float, rz: float, mould: bool) -> Geo:
	var g := Geo.new()
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed) + 77
	nz.frequency = 4.0
	var nx := 72
	var nzn := 90
	for i in nzn + 1:
		for j in nx + 1:
			var x := lerpf(-rx, rx, float(j) / nx)
			var z := lerpf(-rz, rz, float(i) / nzn)
			var e := sqrt(pow(x / rx, 2.0) + pow(z / rz, 2.0))
			if e > 1.0:
				x /= e
				z /= e
			var y := 0.004 * nz.get_noise_2d(x, z)
			var u := 0.5 - z
			var on := 0.0
			if u > 0.0 and u < 1.0:
				var w := _w(f, c, u, signf(x) if x != 0.0 else 1.0)
				if absf(x) < w * 1.04:
					on = 1.0 - smoothstep(0.92, 1.04, absf(x) / maxf(w, 0.001))
					if mould:
						var hh := _h(f, c, u, -x, w)
						y -= (float(hh[0]) * 1.4 + THICK) * on
			g.v.append(Vector3(x, y, z))
			g.rp.append(Vector3(x, z, 0.0))
			g.col.append(Color(0.0 if mould else on, on * 0.7 if mould else 0.0, 0, 1))
	for i in nzn:
		for j in nx:
			var a := i * (nx + 1) + j
			var d := a + nx + 1
			g.idx.append_array([a, d, a + 1, a + 1, d, d + 1])
	return g

## the outside of a half nodule: a rough dome under the face's ellipse
static func _nodule_dome(f: Dictionary, rx: float, rz: float) -> Geo:
	var g := Geo.new()
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed) + 78
	nz.frequency = 3.0
	var na := 64
	var nr := 14
	for i in nr + 1:
		var ph := PI * 0.5 * float(i) / nr
		for j in na + 1:
			var a := TAU * float(j) / na
			var k := 1.0 + 0.05 * nz.get_noise_2d(a * 2.0, ph * 3.0) * sin(ph * 2.0)
			var p := Vector3(sin(a) * rx * cos(ph) * k, -0.36 * sin(ph) * k - 0.002, cos(a) * rz * cos(ph) * k)
			g.v.append(p)
			g.rp.append(Vector3(p.x, p.z, 0.0))
			g.col.append(Color(0, 0, 0, 1))
	for i in nr:
		for j in na:
			var a := i * (na + 1) + j
			var d := a + na + 1
			g.idx.append_array([a, d, a + 1, a + 1, d, d + 1])
	return g

## a pocket in the mould half of a nodule lined with honey calcite: dogtooth crystals from the generator's own maker
static func _pocket(b: RefCounted, f: Dictionary, parent: Node3D, at: Vector3) -> void:
	var rng := Rng32.new(int(f.seed) * 29 + 7)
	var gl := SpecMat.make({col = Color(1, 1, 1), flat = true, glass = true, ir = 0.07, rf = 0.3, holo = 0.2, frost = 0.1, thick = 1.3, seed = 5.0})
	var col := SpecMat.lin(0xe8b070)
	var dark := Geo.sphere(1.0, 16, 8, 0.0, TAU, PI * 0.5, PI * 0.5)
	var hole := U.mesh(dark, SpecMat.make({col = SpecMat.lin(0x2a2018), rough = 0.9}), parent, at + Vector3(0, 0.006, 0), Basis.from_scale(Vector3(0.2, 0.08, 0.15)))
	hole.set_meta("col", true)
	for k in 15:
		var p := at + Vector3((rng.next() - 0.5) * 0.26, -0.02, (rng.next() - 0.5) * 0.2)
		var d := (Vector3.UP + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 1.2).normalized()
		var s := 0.08 + pow(rng.next(), 2.0) * 0.09
		var geo := RockKit.crystal("scaleno", rng, {h = 0.8 + rng.next() * 0.5, detail = 1, cA = col.lerp(Color(1, 1, 1), 0.3), cB = col, zk = 0.6})
		var cm := U.mesh(geo, gl, parent, p, Basis(U.quat_to(Vector3.UP, d)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s))
		cm.set_meta("col", true)
	b._mark("crystals", U.rel_xform(parent, b.root) * (at + Vector3(0, 0.08, 0)), Vector3.UP)

## a pedestal of rock under a prepared trilobite: its outline drawn in and roughened, carried down into the block
static func _pedestal(f: Dictionary, h: float) -> Geo:
	var c: Dictionary = GENUS[f.genus]
	var g := Geo.new()
	var na := 48
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed) + 5
	nz.frequency = 3.0
	var rings := [[-THICK * 0.5, 0.8], [-h * 0.5, 0.84], [-h, 1.0]]
	for r: Array in rings:
		for i in na + 1:
			var a := TAU * float(i) / na
			# walk round the outline: u from the angle along the length, the side from its sign
			var u := 0.5 - 0.5 * cos(a)
			var s := signf(sin(a)) if sin(a) != 0.0 else 1.0
			var w := _w(f, c, clampf(u, 0.02, 0.98), s)
			var k: float = float(r[1]) * (1.0 + 0.12 * nz.get_noise_2d(a * 3.0, float(r[0]) * 20.0))
			var p := Vector3(s * w * k, float(r[0]), (0.5 - u) * k * 0.92)
			g.v.append(p)
			g.rp.append(Vector3(p.x, p.z, 0.0))
			g.col.append(Color(0, 0, 0, 1))
	for ri in rings.size() - 1:
		for i in na:
			var a := ri * (na + 1) + i
			g.idx.append_array([a, a + 1, a + na + 1, a + na + 1, a + 1, a + na + 2])
	return g

## the legendary awakening: swings each leg on its pivot, a wave running down the body; the antennae sweep slowly
class Walker extends Node3D:
	var pivots: Array = []
	var body: Node3D
	var base := Transform3D.IDENTITY
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		if body:
			var go := sin(t * 0.32)
			var fwd := base.basis.z
			body.transform = Transform3D(base.basis.rotated(base.basis.y.normalized(), 0.12 * sin(t * 0.32 + 1.1)), base.origin + fwd * go * 0.16)
		for p: Array in pivots:
			var nd: Node3D = p[0]
			var i: float = p[1]
			var s: float = p[2]
			if p[3]:
				nd.basis = Basis(Vector3.UP, s * 0.22 * sin(t * 0.9 + s)) * Basis(Vector3.RIGHT, 0.08 * sin(t * 1.3 + s * 2.0))
			else:
				var ph := t * 3.2 - i * 0.55 + (0.0 if s > 0.0 else PI)
				# a step: forward with the foot lifted, back along the ground
				nd.basis = Basis(Vector3.UP, s * 0.32 * sin(ph)) * Basis(Vector3.BACK, s * 0.18 * maxf(0.0, cos(ph)))
