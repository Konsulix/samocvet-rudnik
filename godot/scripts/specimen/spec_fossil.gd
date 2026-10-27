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
const PLATE := Vector2(10.0 / TAU, 4.5 / TAU)   # nacre plates per radian: along the coil, round the tube

## the fossil's own genes, from its seed: how it is shown, how well it kept, its shell
## o: the find; showcases may pin `show`, `nacre`, `fire`, `pal`, `fill`
static func genes(seed_v: int, sid: String, tr: Array, o: Dictionary = {}) -> Dictionary:
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
			for k in ["show", "nacre", "fire", "pal", "fill"]:
				if o.has(k): g[k] = o[k]
	return g

## the accents a fossil shows (named on the card, marked for its callouts)
static func accents(g: Dictionary) -> Array:
	var out := []
	if g.get("kind", "") == "ammonite":
		if float(g.nacre) >= 0.03: out.append("nacre")
		if float(g.nacre) < 0.85 and g.show != "split": out.append("sutures")
		if g.show == "split": out.append("ch_" + String(g.fill))
	return out

## the card's name for a fossil gene that carries a number (the nacre's share)
static func gene_name(id: String, g: Dictionary) -> String:
	if id == "nacre":
		return "%sammolite %d%%" % [FIRE_N.get(g.get("fire", "red"), ""), roundi(float(g.nacre) * 100.0)]
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

## a point of the shell's surface (without ribs) and its outward direction
static func _surf(f: Dictionary, a: float, b: float, th: float, ph: float) -> Array:
	var w: Array = _whorl(f, a, b, th)
	var er := Vector3(cos(th), sin(th), 0)
	var sp := sin(ph)
	var p := er * (float(w[1]) + float(w[2]) * cos(ph)) + Vector3(0, 0, float(w[3]) * signf(sp) * pow(absf(sp), 0.75))
	return [p, (er * cos(ph) + Vector3(0, 0, sp)).normalized()]

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
			var cy := y - 1
			var on := nacre > 0.0 and _h(cx, cy, s + 13) < nacre
			var jx := _h(cx, cy, s)
			var jy := _h(cx, cy, s + 7)
			img.set_pixel(x, y, Color(1.0 if on else 0.0, _h(cx, cy, s + 29), jx, jy))
			if on:
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
			var m: float = w[1]
			var rr: float = w[2]
			var rz: float = w[3]
			var er := Vector3(cos(th), sin(th), 0)
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
			var pos := er * (m + rr * cp * k + rr * kl) + Vector3(0, 0, rz * signf(sp) * pow(absf(sp), 0.75) * k)
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
	var back := Vector3(-sin(mid), cos(mid), 0) * float(wl[2]) * (0.15 if half else 0.7)
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
	return m

## builds the ammonite into the builder's root; use_rock(shape) lays the host rock and returns its mesh
static func ammonite(b: RefCounted, gene: Dictionary, use_rock: Callable) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
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
			var s := minf(rb.size.x, rb.size.z) * 0.5
			var tip := 0.35 + rng.next() * 0.3
			var bs := Basis(Vector3.UP, rng.next() * TAU) * Basis(Vector3.RIGHT, -PI / 2 + tip) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * s)
			shell = U.mesh(shell_geo(f, false), sm, root, Vector3(rb.get_center().x, rb.end.y - rb.size.y * 0.12 + s * sin(tip) * 0.55, rb.get_center().z), bs)
		"loose":
			var bs := Basis(Vector3.UP, (rng.next() - 0.5) * 0.8) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * gs)
			shell = U.mesh(shell_geo(f, false), sm, root, Vector3.ZERO, bs)
		"split":
			# sawn in half and polished: the half stands on its edge, the cut towards the viewer, leaning back a little
			var bs := Basis(Vector3.RIGHT, -0.25) * Basis(Vector3.BACK, rng.next() * TAU) * Basis.from_scale(Vector3.ONE * gs)
			shell = U.mesh(shell_geo(f, true), sm, root, Vector3.ZERO, bs)
			var fm := _mat(f, 1, true, plates)
			var face := U.mesh(face_geo(f), fm, shell)
			var fx := U.rel_xform(face, root)
			b._mark("ch_" + String(f.fill), fx * Vector3(0.45, 0.1, 0.0), (fx.basis * Vector3(0, 0, 1)).normalized())
	shell.set_meta("col", true)
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
