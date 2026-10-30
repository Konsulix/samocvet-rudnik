class_name SpecSea
extends RefCounted
## The sea round a sea find (trilobites, pearls): sunlight through moving water over it (shaders/caustics.gdshader,
## a copy of each marked mesh drawn additively), bubbles rising, and small life in the current
## (shaders/sea_life.gdshader): sea lilies on their stalks, anemones, weed, starfish, an oyster's mantle.
## Everything moves in vertex shaders or a few nodes, cheap on a phone.

const U := preload("res://scripts/specimen/spec_util.gd")
const CAUSTIC := preload("res://shaders/caustics.gdshader")
const LIFE := preload("res://shaders/sea_life.gdshader")
const BUBBLE := preload("res://shaders/bubble.gdshader")

## the light through the water over every mesh marked "sea_light" under root (call once the meshes exist —
## the rock's mesh is made in the builder's last pass). The net is laid in the space of the sea floor (root's meta
## "sea_floor", a node whose y is up from the floor), so it falls the same on every part however the find is held
static func caustics(root: Node3D, strength := 0.32) -> void:
	var fl: Node3D = root.get_meta("sea_floor", root)
	var box := U.box_of(root)
	var to_root := U.rel_xform(fl, root).affine_inverse()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.has_meta("sea_light") or mi.mesh == null:
			continue
		var cm := ShaderMaterial.new()
		cm.shader = CAUSTIC
		cm.set_shader_parameter("strength", strength)
		cm.set_shader_parameter("scale", 16.0 / maxf(0.3, box.size.length()) * (U.rel_xform(fl, root).basis.get_scale().x))
		cm.set_shader_parameter("to_floor", to_root * U.rel_xform(mi, root))
		cm.render_priority = 50
		var o := MeshInstance3D.new()
		o.mesh = mi.mesh
		o.material_override = cm
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(o)

static func life_mat(mode: int, h: float, amp: float, speed := 1.0, rough := 0.6, rim := 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIFE
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("h", h)
	m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("rim_k", rim)
	return m

## a tapering tube along pts into g, its colour running c0 -> c1, its phase in the alpha
## radii: a radius per point (overrides r0 .. r1)
static func tube(g: Geo, pts: Array, r0: float, r1: float, c0: Color, c1: Color, ph: float, m := 6, radii: Array = []) -> void:
	var base := g.v.size()
	var n := pts.size()
	var side := Vector3.RIGHT
	for i in n:
		var p: Vector3 = pts[i]
		var t := ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var s2 := side - t * side.dot(t)
		if s2.length_squared() < 1e-6: s2 = t.cross(Vector3.FORWARD)
		side = s2.normalized()
		var up := t.cross(side)
		var f := float(i) / float(n - 1)
		var r: float = float(radii[i]) if radii.size() == n else lerpf(r0, r1, f)
		var c := c0.lerp(c1, f)
		c.a = ph
		for j in m + 1:
			var a := TAU * float(j) / m
			g.v.append(p + (side * cos(a) + up * sin(a)) * r)
			g.col.append(c)
	for i in n - 1:
		for j in m:
			var a := base + i * (m + 1) + j
			g.idx.append_array([a, a + m + 1, a + 1, a + 1, a + m + 1, a + m + 2])

## a sea lily (a crinoid): a thin jointed stalk — a string of beads, whorls of little cirri at its nodes — a plated cup,
## and ten arms forking into twenty, each a feather of pinnules, the crown open like a hand with its fingertips curled
## in (height h, base at the origin)
const LILY := [[0xc8b49a, 0xb87a86, 0xe8c8c0], [0xbca888, 0x8a5a9a, 0xd8b8e0], [0xd0c0a4, 0xc89058, 0xf0d8a8],
	[0xb09a80, 0x5a8a7a, 0xb8e0d0], [0xc4aa90, 0xb04a3a, 0xf0a890]]
static func lily(rng: Rng32, h: float) -> Geo:
	var g := Geo.new()
	var pal: Array = LILY[int(rng.next() * LILY.size())]
	var cs := Color.hex(int(pal[0]) << 8 | 0xff)
	var ca := Color.hex(int(pal[1]) << 8 | 0xff)
	var ct := Color.hex(int(pal[2]) << 8 | 0xff)
	var ph := rng.next()
	# the stalk: leaning back, away from the viewer (the caller turns it only a little), a gentle S
	var bend := Vector3((rng.next() - 0.5) * 0.3, 0, -0.2 - rng.next() * 0.2) * h
	var sh := h * 0.6
	var stalk := []
	var rads := []
	var nn := 44
	for i in nn + 1:
		var t := float(i) / nn
		stalk.append(Vector3(sin(t * PI) * h * 0.03, t * sh, 0) + bend * t * t)
		# columnals: a bead at every joint, thinning upwards
		rads.append(h * (0.011 - 0.003 * t) * (1.0 + 0.35 * pow(absf(sin(float(i) * PI * 0.5)), 4.0)))
	var c0 := g.v.size()
	tube(g, stalk, 0.0, 0.0, cs.darkened(0.2), cs, ph, 7, rads)
	# the joints a shade darker
	for i in range(c0, g.v.size()):
		if int(float(i - c0) / 8.0) % 2 == 1: g.col[i] = g.col[i].darkened(0.12)
	# whorls of cirri at a few nodes: five little hooked threads
	for i in [10, 20, 30]:
		var p: Vector3 = stalk[i]
		for k in 5:
			var a := TAU * float(k) / 5.0 + float(i)
			var o := Vector3(cos(a), 0, sin(a))
			tube(g, [p, p + o * h * 0.035 + Vector3(0, -h * 0.005, 0), p + o * h * 0.055 + Vector3(0, -h * 0.025, 0)], h * 0.004, h * 0.0015, cs, cs.lightened(0.2), ph, 3)
	# the cup: a little plated cone widening upwards
	var top: Vector3 = stalk[stalk.size() - 1]
	var cup_h := h * 0.06
	var cup := []
	var cr := []
	for i in 6:
		var t := float(i) / 5.0
		cup.append(top + Vector3(0, t * cup_h, 0))
		cr.append(h * (0.012 + 0.03 * pow(t, 0.8)))
	var k0 := g.v.size()
	tube(g, cup, 0.0, 0.0, cs, ca, ph, 10, cr)
	# its plates: pentagonal panels, the seams darker
	for i in range(k0, g.v.size()):
		if (i - k0) % 11 % 2 == 0: g.col[i] = g.col[i].darkened(0.15)
	var rim: Vector3 = cup[cup.size() - 1]
	var rim_r: float = cr[cr.size() - 1]
	# ten arms, each forking once just above the cup: twenty feathers
	var open := 0.7 + rng.next() * 0.4
	for k in 10:
		var a := TAU * float(k) / 10.0 + rng.next() * 0.1
		for fork: float in [-1.0, 1.0]:
			var af := a + fork * 0.13
			var out := Vector3(cos(af), 0, sin(af))
			var base := rim + Vector3(cos(a), 0, sin(a)) * rim_r * 0.9
			var arm := []
			var ar := []
			var na := 18
			var ln := h * (0.36 + rng.next() * 0.06)
			for i in na + 1:
				var t := float(i) / na
				# up and out, opening like a hand; the last third curls back in and down
				var curl := smoothstep(0.6, 1.0, t)
				var up := sin(t * PI * 0.5) * (1.0 - curl * 0.55)
				var outk := sin(t * PI * 0.62) * open + curl * 0.15
				arm.append(base + out * ln * 0.55 * outk + Vector3(0, ln * up, 0) - out * ln * 0.18 * curl * curl)
				ar.append(h * 0.007 * (1.0 - 0.65 * t))
			tube(g, arm, 0.0, 0.0, ca, ca.lerp(ct, 0.6), ph, 5, ar)
			# pinnules: thin, alternating sides, angled up along the arm — the feather
			var sd0 := out.cross(Vector3.UP).normalized()
			for i in range(1, na):
				var p: Vector3 = arm[i]
				var dir := ((arm[i + 1] as Vector3) - (arm[i - 1] as Vector3)).normalized()
				var t := float(i) / na
				var s := 1.0 if i % 2 == 0 else -1.0
				var pl := h * 0.075 * (1.0 - 0.6 * t) * (0.8 + 0.4 * rng.next())
				var pd := (sd0 * s * 0.75 + dir * 0.55 + Vector3(0, 0.15, 0)).normalized()
				tube(g, [p, p + pd * pl * 0.55 + dir * pl * 0.05, p + pd * pl + dir * pl * 0.2], h * 0.0028, h * 0.0008, ca.lerp(ct, 0.4), ct, ph, 3)
	return g

## an anemone: a short column, a crown of tentacles waving
const ANEMONE := [[0xb0563c, 0xf09aa8], [0x5a7a3a, 0xc8e070], [0x8a3a6a, 0xf0b0e0], [0xc87a2a, 0xffd890]]
static func anemone(rng: Rng32, h: float) -> Geo:
	var g := Geo.new()
	var pal: Array = ANEMONE[int(rng.next() * ANEMONE.size())]
	var cc := Color.hex(int(pal[0]) << 8 | 0xff)
	var ct := Color.hex(int(pal[1]) << 8 | 0xff)
	var ph := rng.next()
	tube(g, [Vector3.ZERO, Vector3(0, h * 0.25, 0), Vector3(0, h * 0.35, 0)], h * 0.16, h * 0.13, cc.darkened(0.2), cc, ph, 14)
	var n := 22 + int(rng.next() * 12.0)
	for k in n:
		var a := TAU * float(k) / n
		var ring := 0.6 + 0.4 * float(k % 2)
		var o := Vector3(cos(a), 0, sin(a))
		var p0 := Vector3(0, h * 0.35, 0) + o * h * 0.12 * ring
		var pts := []
		for i in 7:
			var t := float(i) / 6.0
			pts.append(p0 + o * h * 0.3 * t * ring + Vector3(0, h * 0.5 * t * (1.2 - ring * 0.4) - h * 0.12 * t * t, 0))
		tube(g, pts, h * 0.022, h * 0.006, ct.darkened(0.15), ct.lightened(0.4), ph + rng.next() * 0.3, 4)
	return g

## a ribbon of weed standing up in the water
static func weed(rng: Rng32, h: float) -> Geo:
	var g := Geo.new()
	var cc := Color.hex(int([0x6a6a2a, 0x4a6a3a, 0x8a5a2a][int(rng.next() * 3.0)]) << 8 | 0xff)
	var ph := rng.next()
	var tw := rng.next() * TAU
	var n := 20
	for i in n + 1:
		var t := float(i) / n
		var w := h * 0.07 * sin(t * PI * 0.9 + 0.15) * (1.0 + 0.25 * sin(t * 23.0))
		var a := tw + t * 2.2
		var side := Vector3(cos(a), 0, sin(a)) * w
		var p := Vector3(sin(t * 3.0) * h * 0.06, t * h, 0)
		for s: float in [-1.0, 1.0]:
			g.v.append(p + side * s)
			var c := cc.lightened(0.25 * t)
			c.a = ph
			g.col.append(c)
	for i in n:
		var a := i * 2
		g.idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	return g

## a starfish: five arms, domed, lying flat (radius r)
const STAR := [0xd8642a, 0x9a3a6a, 0xe0a030, 0xb83a2a]
static func starfish(rng: Rng32, r: float) -> Geo:
	var g := Geo.new()
	var c := Color.hex(int(STAR[int(rng.next() * STAR.size())]) << 8 | 0xff)
	var na := 80
	var nr := 10
	var tw := rng.next() * TAU
	g.v.append(Vector3(0, r * 0.22, 0))
	g.col.append(c.lightened(0.1))
	for i in range(1, nr + 1):
		var t := float(i) / nr
		for j in na:
			var a := TAU * float(j) / na
			var arm := pow(absf(cos((a + tw) * 2.5)), 1.6)
			var rr := r * t * (0.32 + 0.68 * arm)
			var y := r * 0.22 * (1.0 - t * t) * (0.5 + 0.5 * arm) + r * 0.02
			g.v.append(Vector3(cos(a) * rr, y, sin(a) * rr))
			g.col.append(c.darkened(0.25 * t))
	for j in na:
		g.idx.append_array([0, 1 + (j + 1) % na, 1 + j])
	for i in nr - 1:
		for j in na:
			var a := 1 + i * na + j
			var b := 1 + i * na + (j + 1) % na
			g.idx.append_array([a, b, a + na, a + na, b, b + na])
	return g

## bubbles rising from a few spots (parent space), each wobbling as it goes, popping at `top` above its spot
static func bubbles(parent: Node3D, spots: Array, up: Vector3, top: float, size: float, n := 7) -> Bubbles:
	var bm := ShaderMaterial.new()
	bm.shader = BUBBLE
	bm.render_priority = 60
	var bg := Geo.sphere(1.0, 10, 7)
	var mesh := bg.to_mesh()
	var bb := Bubbles.new()
	parent.add_child(bb)
	bb.spots = spots
	bb.up = up.normalized()
	bb.top = top
	bb.size = size
	for k in n:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bb.add_child(mi)
		bb.items.append([mi, float(k) / n * top, float(k) * 1.7, k % spots.size()])
	return bb

class Bubbles extends Node3D:
	var spots: Array = []
	var up := Vector3.UP
	var top := 1.0
	var size := 0.02
	var items: Array = []
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var side2 := up.cross(side)
		for it: Array in items:
			var mi: MeshInstance3D = it[0]
			var y: float = it[1] + dt * top * (0.22 + 0.06 * sin(float(it[2])))
			if y > top:
				y = 0.0
				it[3] = (int(it[3]) + 1 + int(t * 7.0)) % spots.size()
			it[1] = y
			var ph: float = it[2]
			var p: Vector3 = spots[int(it[3])]
			var s := size * (0.5 + 0.5 * fposmod(ph * 0.37, 1.0)) * (1.0 + y / top * 0.6)
			mi.position = p + up * y + (side * sin(t * 4.0 + ph) + side2 * cos(t * 3.3 + ph)) * size * 0.8
			mi.scale = Vector3.ONE * s * (1.0 if y < top * 0.96 else 1.6)
			mi.visible = y < top * 0.985
