class_name SpecButterfly
extends RefCounted
## Butterflies and moths on a find (Koschei's skulls, docs/skulls.md). The wings are museum specimens photographed
## from above (Wikimedia Commons, CC BY-SA — assets/specimen/butterflies/CREDITS.md), cut out by
## prototype/tools/skull/cut_butterfly.py; the body, antennae and the way each one moves are ours.
## A butterfly either rests on the find (opening and closing its wings) or flies round it — each kind in its own way.

const SHADER := preload("res://shaders/butterfly.gdshader")
const SHADER_GLASS := preload("res://shaders/butterfly_glass.gdshader")
const DIR := "res://assets/specimen/butterflies/"

## id: [wing file, span (x), body colour, band colour (0 none), body thickness, abdomen length, how it flies,
##      iridescent, see-through, weight, can perch]
## how it flies:
##   float — big slow beats and long glides on wide loops (morpho, apollo)
##   glide — a few strong beats, then a sail (monarch, mourning cloak)
##   flit  — quick, small and jerky, close round the find, hopping (the blues)
##   hover — fast buzzing beats, darts and hangs in the air (the hawkmoth; its real 26 a second would strobe at 60
##           frames — wing and frame almost in step — so it beats at 14, short strokes)
##   drift — slow heavy beats, the long tails trailing, gentle wide loops (the comet moth)
##   weave — fluttering, wandering this way and that (the glasswing)
const KINDS := {
	morpho = ["morpho", 1.25, Color(0.06, 0.05, 0.05), Color(0, 0, 0, 0), 1.0, 1.0, "float", 1.0, 0.0, 3.0],
	apollo = ["apollo", 1.0, Color(0.15, 0.14, 0.13), Color(0, 0, 0, 0), 1.2, 0.9, "float", 0.0, 0.0, 2.5],
	monarch = ["monarch", 1.05, Color(0.04, 0.03, 0.03), Color(0, 0, 0, 0), 1.0, 1.0, "glide", 0.0, 0.0, 2.5],
	deathshead = ["deathshead", 1.1, Color(0.1, 0.08, 0.06), Color(0.85, 0.65, 0.12, 1.0), 2.2, 1.2, "hover", 0.0, 0.0, 1.5],
	glasswing = ["glasswing", 0.8, Color(0.12, 0.08, 0.06), Color(0, 0, 0, 0), 0.8, 0.95, "weave", 0.0, 1.0, 1.5],
	comet = ["comet", 1.5, Color(0.75, 0.42, 0.12), Color(0.55, 0.25, 0.08, 0.4), 1.6, 1.0, "drift", 0.0, 0.0, 1.2],
	mourning = ["mourning", 1.0, Color(0.06, 0.04, 0.04), Color(0, 0, 0, 0), 1.1, 0.95, "glide", 0.0, 0.0, 2.0],
	blue = ["blue", 0.55, Color(0.18, 0.18, 0.2), Color(0, 0, 0, 0), 0.8, 0.85, "flit", 0.0, 0.0, 2.5],
}

## their names on the card (a callout, one per kind: "Apollo ×2")
const NAME := {morpho = "blue morpho", apollo = "Apollo", monarch = "monarch", deathshead = "death's-head moth",
	glasswing = "glasswing", comet = "comet moth", mourning = "mourning cloak", blue = "mazarine blue"}
## which of them live by each mine (its area): Old Adit's meadows, the Alpine Apollo of the copper mountain, the hawkmoth
## of the Sicilian sulphur and of the coal seam, the Japanese valley's comet and glasswing; the barrow's skulls have all of
## them (SpecSkull). The sea cove and the polar pit: none.
const AREA_KINDS := {0: ["mourning", "blue"], 1: ["apollo"], 3: ["deathshead"], 5: ["comet", "glasswing"],
	6: ["morpho", "apollo", "monarch", "deathshead", "glasswing", "comet", "mourning", "blue"], 7: ["deathshead"]}
## how often a find (not a skull: those decide their own) has butterflies on it
const FIND_P := 0.06

static func label(kind: String, n: int) -> String:
	return String(NAME.get(kind, kind)) + (" ×%d" % n if n > 1 else "")

static var _area := {}
## the mine a species is found in (each species belongs to one mine's pool); -1 none
static func area_of(sid: String) -> int:
	if _area.is_empty():
		for i in Data.AREAS.size():
			for s: String in (Data.AREAS[i] as Dictionary).get("pool", {}): _area[s] = i
	return int(_area.get(sid, -1))

## the butterflies on a find (its species' mine decides which), on their own random stream so no other gene moves;
## pinned from outside: flies=N (0 none), fly_kind=<kind>
static func for_find(seed_v: int, sid: String, o: Dictionary) -> Array:
	var ks: Array = AREA_KINDS.get(area_of(sid), [])
	if o.has("fly_kind") and String(o.fly_kind) != "": ks = [String(o.fly_kind)]
	if ks.is_empty(): return []
	var r := Rng32.new((seed_v * 2654435761 + 433) % 4294967296)
	var n := 0 if r.next() >= FIND_P else 1 + int(pow(r.next(), 1.6) * 3.0)
	if o.has("flies"): n = int(o.flies)
	var out: Array = []
	var one := String(_pick_of(r, ks)) if r.next() < 0.7 else ""
	for k in n: out.append(one if one != "" else _pick_of(r, ks))
	return out

static func _pick_of(r: Rng32, ks: Array) -> String:
	return Stones.pick_w(ks.map(func(k: String) -> Array: return [k, float(KINDS[k][9])]), r)

static var _cards := {}
static var _tex := {}

static func pick(rng: Rng32) -> String:
	return Stones.pick_w(KINDS.keys().map(func(k: String) -> Array: return [k, float(KINDS[k][9])]), rng)

## the wing cards of a kind: both sides, a grid so the wing can bend; the body axis is x (head +), the wing joins at x 0
static func _card(id: String) -> Array:
	if _cards.has(id):
		return _cards[id]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + String(KINDS[id][0]) + ".json"))
	var asp := float(meta.aspect)
	var root := float(meta.root)
	var nu := 10
	var nv := 12
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nm := PackedVector3Array()
	var idx := PackedInt32Array()
	for side: float in [1.0, -1.0]:
		var b := v.size()
		for j in nv + 1:
			for i in nu + 1:
				var u := float(i) / nu
				var w := float(j) / nv
				v.append(Vector3((root - w) * 1.0, 0.0, u * asp * side))
				uv.append(Vector2(u, w))
				nm.append(Vector3.UP)
		for j in nv:
			for i in nu:
				var a := b + j * (nu + 1) + i
				var c := a + nu + 1
				if side > 0: idx.append_array([a, c, a + 1, a + 1, c, c + 1])
				else: idx.append_array([a, a + 1, c, a + 1, c + 1, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# (the card's length along the body is 1; its reach out is the aspect)
	_cards[id] = [m, asp, root]
	return _cards[id]

## a butterfly on a find: starting perched at `at` on normal `n`, or flying round it; perches: [point, normal] where it
## may land (in the parent's space); span: its wingspan in find units before the kind's own size
static func put(parent: Node3D, rng: Rng32, id: String, at: Vector3, n: Vector3, span: float, flying: bool, perches := []) -> Node3D:
	var k: Array = KINDS[id]
	# a kind with a whole animated model (MODELS): that, its own flight, landing, perching and take-off
	if MODELS.has(id) and ResourceLoader.exists(String(MODELS[id][0])):
		var fb := Fly.new()
		parent.add_child(fb)
		var model := (load(String(MODELS[id][0])) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * span * float(k[1]) / float(MODELS[id][1])
		fb.add_child(model)
		fb.ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		fb.anim = MODELS[id][2]
		var s0 := span * float(k[1]) / 2.0
		fb.setup(rng, null, String(k[6]), flying, at, n, perches if perches.size() else [[at, n]], s0)
		return fb
	var card: Array = _card(id)
	var asp: float = card[1]
	var b := Fly.new()
	parent.add_child(b)
	# the card is 1 long, 2·aspect across: scale it to the span
	var s := span * float(k[1]) / (2.0 * asp)
	var m := ShaderMaterial.new()
	# a glasswing is blended (its clear panes), drawn after the find's own glass so that does not paint over it
	var glassy := float(k[8]) > 0.0
	m.shader = SHADER_GLASS if glassy else SHADER
	if glassy: m.render_priority = 90
	if not _tex.has(id): _tex[id] = load(DIR + String(k[0]) + ".png")
	m.set_shader_parameter("wing", _tex[id])
	m.set_shader_parameter("iri", float(k[7]))
	m.set_shader_parameter("seed", rng.next() * 50.0)
	m.set_shader_parameter("curve", 0.15 + rng.next() * 0.2)
	m.set_shader_parameter("root", float(card[2]))
	var wings := Node3D.new()
	wings.scale = Vector3.ONE * s
	b.add_child(wings)
	var w := MeshInstance3D.new()
	w.mesh = card[0]
	w.material_override = m
	w.position = Vector3(0, 0.035, 0)
	wings.add_child(w)
	# (the body goes by the span, not by the card: a comet's card is long with its tails)
	var body := Node3D.new()
	body.scale = Vector3.ONE * span * float(k[1]) * 0.5 / (1.5 if String(k[0]) == "comet" else 1.0)
	b.add_child(body)
	b.body_mat = _body(body, k, id)
	b.setup(rng, m, String(k[6]), flying, at, n, perches if perches.size() else [[at, n]], s)
	return b

## kinds with a whole animated model instead of a wing card: [file, its wingspan in its own units, its animations by state:
## fly, glide, land, sit, off] (the head along +x, up +y, as the cards). The monarch: "Monarch Butterfly (Danaus plexippus)
## - Animated" by animalanimator, CC BY 4.0 (assets/specimen/CREDITS.md)
const MODELS := {
	monarch = ["res://assets/specimen/butterflies/monarch.glb", 2.6, {fly = "Danaus_plexippus_Flight", glide = "Danaus_plexippus_Pose_Wings_Spread",
		land = "Danaus_plexippus_Landing_InPlace", sit = "Danaus_plexippus_Perched_Idle", off = "Danaus_plexippus_Takeoff_InPlace"}],
}

## the body's look, by kind: the fur colour (the hair catching the light at the edges), the pattern (0 plain, 1 white
## dots — the monarch's, 2 the death's-head's skull on the back and its blue-grey stripe down the banded abdomen),
## how furry, and the antennae (club: a butterfly's; feather: a silk moth's combs; spindle: a hawkmoth's)
const BODY := {
	morpho = {fur = Color(0.3, 0.24, 0.18), pat = 0, hair = 0.7, ant = "club"},
	apollo = {fur = Color(0.62, 0.62, 0.6), pat = 0, hair = 1.0, ant = "club"},
	monarch = {fur = Color(0.25, 0.2, 0.18), pat = 1, hair = 0.5, ant = "club"},
	deathshead = {fur = Color(0.55, 0.42, 0.25), pat = 2, hair = 0.9, ant = "spindle"},
	glasswing = {fur = Color(0.45, 0.3, 0.18), pat = 0, hair = 0.5, ant = "club"},
	comet = {fur = Color(1.0, 0.85, 0.45), pat = 0, hair = 1.0, ant = "feather"},
	mourning = {fur = Color(0.35, 0.26, 0.2), pat = 0, hair = 0.9, ant = "club"},
	blue = {fur = Color(0.55, 0.62, 0.85), pat = 0, hair = 1.0, ant = "club"},
}
const BODY_SHADER := preload("res://shaders/butterfly_body.gdshader")
static var _bodies := {}
static var _body_lock := Mutex.new()

## the whole body as one mesh (one draw, where its dozen spheres and tubes were a dozen): abdomen, thorax and head
## turned on one profile, the eyes, six legs folded under, the antennae and the coiled tongue. UV.x along the part,
## UV.y round it (0 the back), UV2.x the part: 0 abdomen, 1 thorax, 2 head, 3 legs, 4 antennae and tongue, 5 eyes,
## 6 a feathered antenna's comb (a flat strip the shader cuts into barbs)
static func _body(hold: Node3D, k: Array, id: String) -> ShaderMaterial:
	var bm := ShaderMaterial.new()
	bm.shader = BODY_SHADER
	var bd: Dictionary = BODY.get(id, BODY.morpho)
	var col: Color = k[2]
	var band: Color = k[3]
	bm.set_shader_parameter("c_body", col)
	bm.set_shader_parameter("c_fur", bd.fur)
	bm.set_shader_parameter("c_band", Color(band.r, band.g, band.b))
	bm.set_shader_parameter("band_k", band.a)
	bm.set_shader_parameter("pat", int(bd.pat))
	bm.set_shader_parameter("hair", float(bd.hair))
	# (the abdomen swings from the waist: SpecButterfly.Fly sets "swing")
	bm.set_shader_parameter("waist", -0.045 * float(k[4]) * 0.9)
	var mi := MeshInstance3D.new()
	mi.mesh = _body_mesh(id, k, String(bd.ant))
	mi.material_override = bm
	hold.add_child(mi)
	return bm

static func _body_mesh(id: String, k: Array, ant: String) -> ArrayMesh:
	_body_lock.lock()
	var got: ArrayMesh = _bodies.get(id)
	_body_lock.unlock()
	if got: return got
	var th := 0.045 * float(k[4])
	var ln := 0.55 * float(k[5])
	var y0 := 0.03
	var g := Geo.new()
	# the profile tail to head: [x, radius, part, u along the part]
	var prof := []
	var tail := -th * 1.0 - ln
	var na := 24
	for i in na + 1:
		var f := float(i) / na
		# the abdomen: fat near the waist, tapering to a blunt tip; each segment swells a little
		var x := lerpf(tail, -th * 0.9, f)
		var r := th * (0.2 + 0.8 * pow(sin(minf(1.0, f * 1.25) * PI * 0.5), 0.6)) * 0.9
		r *= 1.0 + 0.06 * cos(f * 6.0 * TAU)
		prof.append([x, r if i > 0 else 0.0, 0, f])
	# the waist, then the thorax: a plump furry barrel
	var nt := 12
	for i in nt + 1:
		var f := float(i) / nt
		var x := lerpf(-th * 0.9, th * 1.0, f)
		var r := th * 0.25 + th * 0.9 * sqrt(maxf(0.0, 1.0 - pow(f * 2.0 - 1.0, 2.0)))
		prof.append([x, r, 1, f])
	# the neck and the head
	var nh := 10
	for i in nh + 1:
		var f := float(i) / nh
		var x := lerpf(th * 1.0, th * 2.15, f)
		var r := th * 0.72 * sqrt(maxf(0.0, 1.0 - pow(f * 2.0 - 1.0, 2.0)))
		prof.append([x, maxf(r, th * 0.3) if i < nh else 0.0, 2, f])
	_revolve(g, prof, 20, Vector3(0, y0, 0))
	# the fur: a looser shell round the thorax, the head and the abdomen's first segments, which the shader cuts
	# into tufts — the body's outline goes soft and hairy (part 7)
	var shell := []
	for q: Array in prof:
		var pt: int = q[2]
		var fu: float = q[3]
		if pt == 0 and fu < 0.55: continue
		var r: float = q[1]
		var grow := 1.35 if pt == 1 else 1.22 if pt == 2 else 1.18
		shell.append([q[0], r * grow + th * 0.04 if r > 0.0 else 0.0, 7, (float(q[0]) - tail) / (th * 2.15 - tail)])
	_revolve(g, shell, 20, Vector3(0, y0, 0))
	# the eyes: big domes on the head's sides
	var hx := th * 1.6
	for sd: float in [1.0, -1.0]:
		var e := Geo.sphere(th * 0.4, 10, 8)
		var c := Vector3(hx + th * 0.12, y0 + th * 0.08, sd * th * 0.48)
		var b := g.v.size()
		for i in e.v.size():
			var n := e.v[i].normalized()
			g.v.append(c + e.v[i])
			g.own_n.append(n)
			g.rp.append(Vector3(0.5 + n.x * 0.5, 0.5 + n.y * 0.5, 5.0))
		for j in e.idx: g.idx.append(b + j)
	# six legs from under the thorax, out and down, the feet below the body (it stands on them)
	for li in 3:
		var xs := th * (0.6 - 0.6 * li)
		var fw := 0.5 - li * 0.5
		for sd: float in [1.0, -1.0]:
			# (short and folded close: long thin ones read as a spider's)
			var p0 := Vector3(xs, y0 - th * 0.6, sd * th * 0.3)
			var p1 := Vector3(xs + th * fw * 0.7, y0 - th * 0.35, sd * th * 1.25)
			var p2 := Vector3(xs + th * fw * 1.4, y0 - th * 1.05, sd * th * 1.7)
			var p3 := Vector3(xs + th * fw * 1.7, y0 - th * 1.4, sd * th * 1.85)
			_strand(g, [p0, p1, p2, p3], [th * 0.14, th * 0.12, th * 0.09, th * 0.06], 3.0)
	# the antennae: from the top of the head, forward and apart, a gentle curve
	var hp := Vector3(th * 1.85, y0 + th * 0.55, 0.0)
	var al := 0.2 if ant != "spindle" else 0.1
	for sd: float in [1.0, -1.0]:
		var pts := []
		var rad := []
		for j in 9:
			var f := float(j) / 8.0
			pts.append(hp + Vector3(f * al, f * al * 0.35 + f * f * al * 0.15, sd * (0.01 + f * al * 0.4)))
			match ant:
				"club": rad.append(0.0045 + 0.009 * smoothstep(0.7, 0.95, f) * (1.0 - smoothstep(0.97, 1.0, f) * 0.6))
				"spindle": rad.append(0.004 + 0.007 * sin(f * PI))
				_: rad.append(0.004 * (1.0 - f * 0.6))
		_strand(g, pts, rad, 4.0)
		if ant == "feather":
			# the silk moth's combs: a flat strip either side of the shaft, widest in the middle
			_comb(g, pts, al * 0.22)
	# the tongue, coiled like a watch spring under the head (not on the hawkmoth)
	if ant != "spindle":
		var sp := []
		var srad := []
		for j in 22:
			var f := float(j) / 21.0
			var w := f * TAU * 2.2
			var rr := th * 0.42 * (1.0 - f * 0.8)
			sp.append(Vector3(th * 2.2 + rr * sin(w), y0 - th * 0.45 - rr * (1.0 - cos(w)) * 0.9, 0.0))
			srad.append(th * 0.05)
		_strand(g, sp, srad, 4.0)
	var m := g.to_mesh()
	_body_lock.lock()
	_bodies[id] = m
	_body_lock.unlock()
	return m

## a profile turned round the x axis: prof [x, radius, part, u]; normals worked from the profile's slope
static func _revolve(g: Geo, prof: Array, seg: int, at: Vector3) -> void:
	var n := prof.size()
	var b := g.v.size()
	for i in seg + 1:
		var ph := float(i) / seg * TAU
		var cy := cos(ph)
		var sz := sin(ph)
		for j in n:
			var q: Array = prof[j]
			var x: float = q[0]
			var r: float = q[1]
			var a: Array = prof[maxi(j - 1, 0)]
			var c: Array = prof[mini(j + 1, n - 1)]
			var dx := float(c[0]) - float(a[0])
			var dr := (float(c[1]) - float(a[1])) / dx if absf(dx) > 1e-6 else 0.0
			# (the two ends, where the radius closes to 0, point along the axis)
			var nr := Vector3(-dr, cy, sz).normalized()
			if r <= 0.0: nr = Vector3(-1.0 if j == 0 else 1.0, 0, 0)
			g.v.append(at + Vector3(x, r * cy, r * sz))
			g.own_n.append(nr)
			g.rp.append(Vector3(float(q[3]), float(i) / seg, float(q[2])))
	for i in seg:
		for j in n - 1:
			var a0 := b + i * n + j
			var a1 := a0 + n
			g.idx.append_array([a0, a0 + 1, a1, a1, a0 + 1, a1 + 1])

## a thin tube down a few points (legs, antennae, the tongue), its radius at each point
static func _strand(g: Geo, pts: Array, rad: Array, part: float) -> void:
	var rs := 5
	var path := []
	var rr := []
	var sub := 3
	for i in pts.size() - 1:
		for s2 in sub:
			var f := float(s2) / sub
			var p0: Vector3 = pts[maxi(i - 1, 0)]
			var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
			path.append((pts[i] as Vector3).cubic_interpolate(pts[i + 1], p0, p3, f))
			rr.append(lerpf(float(rad[i]), float(rad[i + 1]), f))
	path.append(pts[pts.size() - 1])
	rr.append(rad[rad.size() - 1])
	var b := g.v.size()
	var nm := Vector3.UP
	var cnt := path.size()
	for k in cnt:
		var tg := ((path[mini(k + 1, cnt - 1)] as Vector3) - (path[maxi(k - 1, 0)] as Vector3)).normalized()
		nm = (nm - tg * nm.dot(tg)).normalized()
		if nm.length_squared() < 0.5: nm = tg.cross(Vector3.FORWARD).normalized()
		var bi := tg.cross(nm)
		for j in rs + 1:
			var w := float(j) / rs * TAU
			var d := nm * cos(w) + bi * sin(w)
			g.v.append((path[k] as Vector3) + d * float(rr[k]))
			g.own_n.append(d)
			g.rp.append(Vector3(float(k) / (cnt - 1), float(j) / rs, part))
	for k in cnt - 1:
		for j in rs:
			var a0 := b + k * (rs + 1) + j
			var a1 := a0 + rs + 1
			g.idx.append_array([a0, a1, a0 + 1, a1, a1 + 1, a0 + 1])

## a feathered antenna's comb: a strip either side of the shaft, tilted down; the shader cuts it into barbs
static func _comb(g: Geo, pts: Array, w: float) -> void:
	var b := g.v.size()
	var n := pts.size()
	for k in n:
		var f := float(k) / (n - 1)
		var p: Vector3 = pts[k]
		var tg := ((pts[mini(k + 1, n - 1)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var out := tg.cross(Vector3.UP).normalized()
		var ww := w * sin(clampf(f * 1.1, 0.0, 1.0) * PI) + w * 0.05
		var dn := Vector3(0, -0.45, 0)
		var nm := tg.cross(out).normalized()
		for sd: float in [-1.0, 1.0]:
			g.v.append(p + (out * sd + dn).normalized() * ww)
			g.own_n.append(nm)
			g.rp.append(Vector3(f, 0.5 + sd * 0.5, 6.0))
		g.v.append(p)
		g.own_n.append(nm)
		g.rp.append(Vector3(f, 0.5, 6.0))
	for k in n - 1:
		var a0 := b + k * 3
		var a1 := a0 + 3
		g.idx.append_array([a0, a1, a0 + 2, a0 + 2, a1, a1 + 2])
		g.idx.append_array([a0 + 2, a1 + 2, a0 + 1, a0 + 1, a1 + 2, a1 + 1])

## how each way of flying moves: wingbeats a second, the stroke (top and bottom root angle), cruising speed (in spans
## a second), how often it sails with the wings held out, how jerky its path, how long it flies and sits (s),
## how often it opens its wings to the sun when it sits, and its resting wings (closed up, or a moth's flat roof)
const STYLE := {
	float = {hz = 3.2, up = 1.5, dn = -0.55, speed = 1.3, glide = 0.45, jerk = 0.2, fly = [5.0, 9.0], sit = [3.0, 7.0], sun = 0.7, rest = 1.5},
	glide = {hz = 4.5, up = 1.5, dn = -0.5, speed = 1.6, glide = 0.35, jerk = 0.25, fly = [4.0, 8.0], sit = [2.5, 6.0], sun = 0.5, rest = 1.5},
	flit = {hz = 9.0, up = 1.45, dn = -0.4, speed = 1.8, glide = 0.0, jerk = 1.0, fly = [2.0, 4.5], sit = [1.5, 3.5], sun = 0.6, rest = 1.5},
	hover = {hz = 14.0, up = 0.85, dn = -0.35, speed = 2.6, glide = 0.0, jerk = 0.5, fly = [6.0, 11.0], sit = [4.0, 8.0], sun = 0.0, rest = -0.08},
	drift = {hz = 2.0, up = 1.35, dn = -0.5, speed = 0.9, glide = 0.15, jerk = 0.1, fly = [6.0, 10.0], sit = [4.0, 8.0], sun = 0.0, rest = 0.2},
	weave = {hz = 6.0, up = 1.45, dn = -0.45, speed = 1.2, glide = 0.05, jerk = 0.7, fly = [3.0, 6.0], sit = [2.0, 4.5], sun = 0.3, rest = 1.5},
}

## the butterfly's life, all in the find's own space: it flies round the find (wingbeats, sails, bobbing on each
## stroke, banking into turns), picks a spot on the find, comes in, lands and folds its wings, sits (now and then opening
## them to the sun, or a slow clap), and takes off again. The wings' angles go to the shader (ang, flex).
class Fly extends Node3D:
	enum { FLY, LAND, SIT, OFF }
	var mat: ShaderMaterial
	var body_mat: ShaderMaterial
	var pitch := 0.0        # nose up (+) — tips with each stroke in the air
	var bob := 0.0          # the body's rise and fall on each stroke, in spans
	var st: Dictionary
	var rng: Rng32
	var size := 0.2
	var state := FLY
	var timer := 0.0
	var phase := 0.0        # wingbeat phase
	var gliding := 0.0      # 0 flapping .. 1 sailing
	var glide_t := 0.0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var target := Vector3.ZERO
	var retarget := 0.0
	var bank := 0.0
	var heading := Vector3.FORWARD
	var perch := []         # [point, normal] on the find where it may land
	var spot: Array = []    # the one it is landing on / sitting on
	var land_from := Vector3.ZERO
	var sun := 0.0          # sitting: 0 wings closed .. 1 opened to the sun
	var sun_to := 0.0
	var sun_t := 0.0
	var start_at := Vector3.ZERO
	var start_n := Vector3.UP
	var start_fly := true
	# the find: its box (the studio frames it) and its pieces to keep out of (ellipsoids)
	var top_n: Node3D
	var box := AABB()
	var obst := []
	var stand: Array[AABB] = []
	var looked := false
	# a whole animated model (SpecButterfly.MODELS): its player and its animations by state
	var ap: AnimationPlayer
	var anim := {}
	var _playing := ""

	func setup(r: Rng32, m: ShaderMaterial, how: String, fly: bool, at: Vector3, n: Vector3, perches: Array, s: float) -> void:
		rng = r
		mat = m
		st = SpecButterfly.STYLE[how]
		size = s
		start_fly = fly
		start_at = at
		start_n = n
		perch = perches
		phase = rng.next() * TAU
		# a first pose before the find is looked round (in the parent's space: where it was put)
		transform = Transform3D(Basis(SpecUtil.quat_to(Vector3.UP, n)), at)
		_wings(1.5, 0.0)

	func _rnd(a: Array) -> float:
		return lerpf(float(a[0]), float(a[1]), rng.next())

	## the find, once it is built: its box and its pieces (the skull, the crystals, the rock), in the find's space
	func _look_round() -> void:
		looked = true
		top_n = self
		var p := get_parent()
		while p is Node3D:
			top_n = p
			if p.has_meta("grown"): break
			p = p.get_parent()
		var first := true
		var stack: Array[Node] = [top_n]
		while stack.size():
			var n: Node = stack.pop_back()
			if n is Fly: continue
			stack.append_array(n.get_children())
			if not (n is MeshInstance3D) or not n.has_meta("geo"): continue
			var g: Geo = n.get_meta("geo")
			var bb: AABB = SpecUtil.rel_xform(n as Node3D, top_n) * g.aabb()
			if bb.size.length() < 0.04: continue
			box = bb if first else box.merge(bb)
			first = false
			obst.append([bb.get_center(), bb.size * 0.5 + Vector3.ONE * size * 0.3])
			# the things standing up off the bone (crystals, trees, moss, mushrooms): a wing must not open into them
			if n.has_meta("col") or n.has_meta("local") or (n.get_parent() != top_n and not n.get_parent() is Fly):
				stand.append(bb.grow(size * 0.45))
		# the perches and the start, into the find's space
		var pt := SpecUtil.rel_xform(get_parent() as Node3D, top_n) if get_parent() != top_n else Transform3D.IDENTITY
		perch = perch.map(func(q: Array) -> Array: return [pt * (q[0] as Vector3), (pt.basis * (q[1] as Vector3)).normalized()])
		# only where the wings have room: no crystal or tree within a span, and fairly level
		var free := perch.filter(func(q: Array) -> bool:
			if (q[1] as Vector3).y < 0.55: return false
			for bb: AABB in stand:
				if bb.has_point(q[0]): return false
			return true)
		if free.size(): perch = free
		if start_fly:
			pos = _shell()
			vel = Vector3(rng.next() - 0.5, 0.1, rng.next() - 0.5).normalized() * size * float(st.speed)
			target = _shell()
			state = FLY
			timer = _rnd(st.fly) * 0.45   # (the first landing soon: a card is not looked at for long)
		else:
			# a spot of its own (they all started on the first spot of the list, one on top of the other)
			var pick := _free_spot() if perch.size() else []
			if pick.is_empty():
				# nowhere to sit: it flies instead
				start_fly = true
				pos = _shell()
				target = _shell()
				state = FLY
				timer = _rnd(st.fly)
				return
			spot = pick
			_claim(spot[0], true)
			pos = (spot[0] as Vector3) + (spot[1] as Vector3) * size * 0.08
			heading = (Vector3(rng.next() - 0.5, 0, rng.next() - 0.5)).normalized()
			state = SIT
			timer = _rnd(st.sit) * (0.3 + rng.next() * 0.7)

	## a point to fly towards: on a shell round the find, inside the frame
	func _shell() -> Vector3:
		if box.size == Vector3.ZERO: return Vector3(0, 0.5, 0)
		var c := box.get_center()
		var h := box.size * 0.5
		var a := rng.next() * TAU
		return Vector3(c.x + cos(a) * (h.x * 0.92 + size * 0.15), box.position.y + box.size.y * (0.4 + rng.next() * 0.45),
			c.z + sin(a) * (h.z + size * 0.5))

	func _process(dt: float) -> void:
		if not looked:
			_look_round()
		dt = minf(dt, 0.05)
		timer -= dt
		match state:
			FLY: _fly(dt)
			LAND: _land(dt)
			SIT: _sit(dt)
			_: _off(dt)
		_place()
		if ap: _animate()

	## the model's own animation for what it is doing (a landing and a take-off played once, the rest looped)
	func _animate() -> void:
		var want := "fly"
		match state:
			FLY: want = "glide" if gliding > 0.5 else "fly"
			LAND: want = "land" if timer > 0.0 else "fly"
			SIT: want = "sit"
			_: want = "off"
		if want == _playing: return
		_playing = want
		var nm := String(anim.get(want, ""))
		if nm == "" or not ap.has_animation(nm): return
		var a := ap.get_animation(nm)
		if want in ["fly", "sit"]: a.loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = 1.0 if want != "land" else 1.4
		ap.play(nm, 0.15)
		if want == "sit": ap.seek(rng.next() * a.length, true)

	## a wingbeat: the stroke between the top (wings almost meeting over the back) and the bottom (below the body),
	## the tip lagging the root; returns the lift of this moment (the body rises on the downstroke)
	func _flap(dt: float, hz: float, k := 1.0) -> float:
		phase += dt * hz * TAU
		var up := float(st.up)
		var dn := float(st.dn)
		var mid := (up + dn) * 0.5
		var amp := (up - dn) * 0.5 * k
		# the downstroke a little faster than the upstroke
		var c := cos(phase + 0.25 * sin(phase))
		var a := mid + amp * c
		# the tip trails the stroke: bent up going down, bent down going up
		_wings(a, sin(phase) * 0.55 * k)
		# the body answers each stroke: it jumps on the downstroke and drops on the up, the nose tips up and down,
		# the abdomen swinging behind, a beat late (a butterfly's flight is all bounce)
		pitch = (0.14 + sin(phase) * 0.12) * k
		bob = sin(phase) * 0.05 * k
		_swing(-sin(phase - 0.9) * 0.45 * k)
		return maxf(0.0, sin(phase)) * k

	func _swing(v: float) -> void:
		if body_mat: body_mat.set_shader_parameter("swing", v)

	func _wings(a: float, f: float) -> void:
		if mat == null: return
		mat.set_shader_parameter("ang", a)
		mat.set_shader_parameter("flex", f)

	func _fly(dt: float) -> void:
		var hz: float = float(st.hz)
		# now and then it sails, wings held out a little above flat
		glide_t -= dt
		if glide_t <= 0.0:
			var sail := rng.next() < float(st.glide)
			glide_t = (0.5 + rng.next() * 0.9) if sail else (0.6 + rng.next() * 1.2)
			gliding = 1.0 if sail else 0.0
		var g := 0.0
		if gliding > 0.5:
			_wings(0.12 + 0.05 * sin(phase), 0.0)
			phase += dt * 2.0
			pitch = lerpf(pitch, 0.04, minf(1.0, dt * 3.0))
			bob = lerpf(bob, 0.0, minf(1.0, dt * 3.0))
			_swing(sin(phase) * 0.06)
		else:
			g = _flap(dt, hz)
		# steer for the target; a jerky one changes its mind often
		retarget -= dt
		if pos.distance_to(target) < size * 1.5 or retarget <= 0.0:
			target = _shell()
			retarget = (0.3 + rng.next() * 0.5) / maxf(0.2, float(st.jerk)) if float(st.jerk) > 0.6 else 1.5 + rng.next() * 2.0
		var speed := size * float(st.speed) * (0.85 if gliding > 0.5 else 1.0)
		var want := (target - pos).normalized() * speed
		var turn := 2.0 + float(st.jerk) * 6.0
		var old := vel
		vel = vel.lerp(want, minf(1.0, dt * turn))
		# each downstroke lifts it, a sail sinks it
		vel.y += (g * 1.6 - 0.55) * size * dt * (1.0 if gliding < 0.5 else 0.4)
		pos += vel * dt
		_keep_out()
		# and out of each other's way
		for n: Node in get_parent().get_children():
			if n != self and n is Fly:
				var o := (n as Fly).pos
				var dd := pos.distance_to(o)
				if dd < size * 1.2 and dd > 1e-4: pos += (pos - o).normalized() * (size * 1.2 - dd) * 0.5
		var lat := (vel - old).cross(Vector3.UP).y if dt > 0.0 else 0.0
		bank = lerpf(bank, clampf(-lat * 20.0 / maxf(size, 0.01), -0.7, 0.7), minf(1.0, dt * 4.0))
		if vel.length() > 1e-4:
			heading = Vector3(vel.x, vel.y * 0.6, vel.z).normalized()
		# time to land: pick a spot on the find
		if timer <= 0.0 and perch.size():
			var pick := _free_spot()
			if pick.is_empty():
				timer = 1.0 + rng.next()
				return
			spot = pick
			_claim(spot[0], true)
			state = LAND
			land_from = pos
			timer = 0.0
			retarget = 0.0

	## the flies on this find share their landing spots: a spot one has taken (or is coming in to) is no one else's
	func _taken() -> Array:
		if not top_n.has_meta("fly_taken"): top_n.set_meta("fly_taken", [])
		return top_n.get_meta("fly_taken")

	func _claim(p: Vector3, on: bool) -> void:
		var t := _taken()
		if on: t.append(p)
		else: t.erase(p)

	## a landing spot with room: none taken by another fly within a span, its hovering point clear of crystals and trees
	func _free_spot() -> Array:
		var t := _taken()
		for k in 8:
			var q: Array = perch[int(rng.next() * perch.size())]
			var p: Vector3 = q[0]
			var ok := true
			for o: Vector3 in t:
				if o.distance_to(p) < size * 1.3: ok = false
			var hover := p + (q[1] as Vector3) * size * 0.8
			for bb: AABB in stand:
				if bb.has_point(hover): ok = false
			if ok: return q
		return []

	## coming in: flies at the spot from above it, slowing, wings fluttering, then folds them as the feet touch
	func _land(dt: float) -> void:
		var p: Vector3 = spot[0]
		var n: Vector3 = spot[1]
		var hover := p + n * size * 0.8
		var d := pos.distance_to(hover)
		retarget -= dt
		if d > size * 0.25 and retarget > -4.0:
			var speed := size * float(st.speed) * clampf(d / size, 0.4, 1.0)
			vel = vel.lerp((hover - pos).normalized() * speed, minf(1.0, dt * 4.0))
			pos += vel * dt
			_keep_out(p)
			heading = Vector3(vel.x, 0.0, vel.z).normalized() if Vector2(vel.x, vel.z).length() > 1e-4 else heading
			_flap(dt, float(st.hz) * 1.15)
			bank = lerpf(bank, 0.0, minf(1.0, dt * 4.0))
		else:
			# settle down onto the spot over half a second, a few short beats
			timer += dt
			var f := clampf(timer / 0.5, 0.0, 1.0)
			if timer <= dt: land_from = pos
			pos = land_from.lerp(p + n * size * 0.08, f * f)
			_flap(dt, float(st.hz) * 0.8, 1.0 - f * 0.7)
			if f >= 1.0:
				state = SIT
				timer = _rnd(st.sit)
				sun = 0.0
				sun_t = 0.5 + rng.next()

	## sitting: wings closed over the back (a moth's flat roof), opened to the sun for a while, a slow clap now and then
	func _sit(dt: float) -> void:
		var rest := float(st.rest)
		sun_t -= dt
		if sun_t <= 0.0:
			sun_to = 1.0 if rng.next() < float(st.sun) and sun_to < 0.5 else 0.0
			sun_t = 1.2 + rng.next() * 2.5
		sun = move_toward(sun, sun_to, dt * 1.6)
		# opened to the sun only to a V, never flat: flat wings dipped into the curve of the bone
		var open := lerpf(rest, 0.5, smoothstep(0.0, 1.0, sun))
		# a slow clap while open, a shiver while closed
		var clap := sin(timer * 2.2) * 0.12 * sun + sin(timer * 17.0) * 0.015
		_wings(open + clap, 0.0)
		bank = 0.0
		pitch = 0.0
		bob = 0.0
		# (breathing: the abdomen rises and falls a little)
		_swing(sin(timer * 1.7) * 0.08)
		if timer <= 0.0:
			state = OFF
			timer = 0.6
			vel = (spot[1] as Vector3) * size * float(st.speed) * 0.8
			_claim(spot[0], false)

	## taking off: a few strong beats straight up off the spot, then away
	func _off(dt: float) -> void:
		var g := _flap(dt, float(st.hz) * 1.2, 1.1)
		vel = vel.lerp(((spot[1] as Vector3) + Vector3.UP).normalized() * size * float(st.speed) * 1.2, minf(1.0, dt * 3.0))
		vel.y += g * size * dt
		pos += vel * dt
		if timer <= 0.0:
			state = FLY
			timer = _rnd(st.fly)
			target = _shell()
			gliding = 0.0
			glide_t = 0.6

	## keep out of every piece of the find (but for the one being landed on, near its spot)
	func _keep_out(near := Vector3.INF) -> void:
		for o: Array in obst:
			var oc: Vector3 = o[0]
			var oh: Vector3 = o[1]
			var q := (pos - oc) / oh
			var l := q.length()
			if l < 1.0:
				# (coming in to land: the piece it lands on — any piece whose shell holds the spot — lets it through)
				if near != Vector3.INF and (((near - oc) / oh).length() < 1.0 or pos.distance_to(near) < size * 1.2): continue
				if l < 1e-4: q = Vector3.UP
				var out := oc + q.normalized() * oh
				var nrm := (out - oc).normalized()
				pos = out
				vel -= nrm * minf(0.0, vel.dot(nrm))

	func _place() -> void:
		if not looked: return
		var up := Vector3.UP
		var fwd := heading
		if state == SIT or (state == LAND and timer > 0.0):
			up = spot[1]
			fwd = (heading - up * heading.dot(up)).normalized()
			if fwd.length() < 1e-3: fwd = up.cross(Vector3.RIGHT).normalized()
		var side := fwd.cross(up).normalized()
		up = side.cross(fwd).normalized()
		var bas := Basis(side, up, -fwd).orthonormalized()
		# the card's head is +x: turn it to face along fwd; bank into the turn
		# (a model bounces in its own animation: our stroke's pitch and bob are the wing cards')
		if ap:
			pitch = 0.0
			bob = 0.0
		bas = bas * Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, bank) * Basis(Vector3.BACK, pitch)
		var into := SpecUtil.rel_xform(get_parent() as Node3D, top_n).affine_inverse() if get_parent() != top_n else Transform3D.IDENTITY
		transform = into * Transform3D(bas, pos + up * bob * size)
