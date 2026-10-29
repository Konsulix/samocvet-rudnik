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
static func tube(g: Geo, pts: Array, r0: float, r1: float, c0: Color, c1: Color, ph: float, m := 6) -> void:
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
		var r := lerpf(r0, r1, f)
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

## a sea lily: a jointed stalk, a cup, feathery arms opening from it (height h, base at the origin)
const LILY := [[0xd8c2a8, 0xb07a8a], [0xc8b090, 0x8a5a9a], [0xe0d0b8, 0xc89058], [0xb8a088, 0x6a8a7a]]
static func lily(rng: Rng32, h: float) -> Geo:
	var g := Geo.new()
	var pal: Array = LILY[int(rng.next() * LILY.size())]
	var cs := Color.hex(int(pal[0]) << 8 | 0xff)
	var ca := Color.hex(int(pal[1]) << 8 | 0xff)
	var ph := rng.next()
	var bend := Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * h * 0.35
	var stalk := []
	for i in 16:
		var t := float(i) / 15.0
		stalk.append(Vector3(0, t * h * 0.62, 0) + bend * t * t)
	tube(g, stalk, h * 0.022, h * 0.018, cs.darkened(0.15), cs, ph, 6)
	var top: Vector3 = stalk[stalk.size() - 1]
	# the cup
	tube(g, [top, top + Vector3(0, h * 0.06, 0)], h * 0.03, h * 0.05, cs, ca, ph, 8)
	var cup := top + Vector3(0, h * 0.06, 0)
	var na := 5 + int(rng.next() * 2.0) * 5
	for k in na:
		var a := TAU * float(k) / na + rng.next() * 0.2
		var out := Vector3(cos(a), 0, sin(a))
		var arm := []
		for i in 10:
			var t := float(i) / 9.0
			# up and out, the tip curling back in
			arm.append(cup + out * h * 0.3 * sin(t * 2.2) + Vector3(0, h * 0.38 * t - h * 0.08 * t * t * t, 0))
		tube(g, arm, h * 0.012, h * 0.004, ca, ca.lightened(0.35), ph, 4)
		# pinnules: little side branches down the arm
		for i in range(2, 9):
			var p: Vector3 = arm[i]
			var dir := ((arm[i + 1] as Vector3) - (arm[i - 1] as Vector3)).normalized()
			var sd := dir.cross(Vector3.UP).normalized()
			for s: float in [-1.0, 1.0]:
				tube(g, [p, p + (sd * s + dir * 0.4).normalized() * h * 0.06], h * 0.004, h * 0.0015, ca, ca.lightened(0.4), ph, 3)
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
