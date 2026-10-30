class_name SpecObsidian
extends RefCounted
## Obsidian, Etna's volcanic glass: a chunk broken with conchoidal fracture — smooth curved scoops meeting in sharp
## ridges — black and mirror-glossy. Its kinds (genes, on their own stream): plain black; snowflake (grey-white
## blossoms of cristobalite in it); mahogany (red-brown streaks through the black); rainbow (a sheen of colours in
## bands under the surface); and Apache tears — small rounded nodules, smoky brown against the light, still sitting
## in their pale grey perlite.

const U := preload("res://scripts/specimen/spec_util.gd")

const KINDS := [["black", 4.0], ["snowflake", 3.0], ["mahogany", 2.0], ["rainbow", 1.2], ["tears", 1.5]]
const NAMES := {snowflake = "snowflake obsidian", mahogany = "mahogany obsidian", rainbow = "rainbow sheen", tears = "Apache tears",
	black = "jet-black glass"}

static func genes(seed_v: int, o: Dictionary = {}) -> Dictionary:
	var rng := Rng32.new((seed_v * 2654435761 + 4049) % 4294967296)
	var g := {kind = Stones.pick_w(KINDS, rng), seed = int(rng.next() * 100000.0), scoops = 11 + int(rng.next() * 6)}
	# (tests pin it with "ob": the find's own "kind" is something else)
	if o.has("ob"): g.kind = o.ob
	if o.has("scoops"): g.scoops = o.scoops
	return g

static func accents(seed_v: int, o: Dictionary = {}) -> Array:
	return ["ob_" + String(genes(seed_v, o).kind)]

static func gene_name(id: String) -> String:
	return NAMES.get(id.trim_prefix("ob_"), "")

## a conchoidal chunk: a lumpy ellipsoid with spherical scoops broken out of it. Every triangle takes the normal of the
## surface it lies on (the scoop's sphere, or the old rind), so the scoops are smooth and the ridges between them sharp
static func chunk(rng: Rng32, r: float, n_scoops: int, sc: Vector3) -> Geo:
	var base := Geo.icosa(1.0, 5)
	var nz := FastNoiseLite.new()
	nz.seed = int(rng.next() * 100000.0)
	nz.frequency = 1.1
	for i in base.v.size():
		var p := base.v[i].normalized()
		base.v[i] = p * (1.0 + nz.get_noise_3dv(p * 1.5) * 0.18) * sc * r
	var scoops := []
	for k in n_scoops:
		var d := RockKit.rd(rng)
		var rs := r * (0.9 + rng.next() * 1.4)
		# the sphere's centre outside the chunk, so it bites a dish out of it — wide, deep enough for sharp ridges
		var bite := r * (0.22 + rng.next() * 0.38)
		scoops.append([d * (r * (sc.dot(d.abs()) / (d.abs().x + d.abs().y + d.abs().z)) * 1.0 + rs - bite) , rs])
	var owner := PackedInt32Array()
	owner.resize(base.v.size())
	for i in base.v.size():
		owner[i] = -1
		var p := base.v[i]
		var r0 := p.length()
		for k in scoops.size():
			var c: Vector3 = scoops[k][0]
			var rs: float = scoops[k][1]
			if p.distance_to(c) < rs:
				p = c + (p - c).normalized() * rs
				owner[i] = k
		# a scoop only takes away: nothing may stand out past the old surface (it swelled the find's box)
		if p.length() > r0: p = p.normalized() * r0
		base.v[i] = p
	# soup, each triangle with the normals of the surface it belongs to
	var g := Geo.new()
	g.set_meta("shape", [nz, scoops, sc, r])
	var nt := base.idx.size() if base.indexed() else base.v.size()
	for t in range(0, nt, 3):
		var ia := base.idx[t] if base.indexed() else t
		var ib := base.idx[t + 1] if base.indexed() else t + 1
		var ic := base.idx[t + 2] if base.indexed() else t + 2
		var o := owner[ia] if owner[ia] == owner[ib] or owner[ia] == owner[ic] else owner[ib]
		for vi in [ia, ib, ic]:
			var p := base.v[vi]
			g.v.append(p)
			if o >= 0:
				g.own_n.append(((scoops[o][0] as Vector3) - p).normalized())
			else:
				g.own_n.append((p / (sc * sc)).normalized())
	return g

## the chunk's surface in the direction d (the same as chunk() makes it): [point, outward normal]
static func surf(g: Geo, d: Vector3) -> Array:
	var sh: Array = g.get_meta("shape")
	var nz: FastNoiseLite = sh[0]
	var scoops: Array = sh[1]
	var sc: Vector3 = sh[2]
	var r: float = sh[3]
	var u := d.normalized()
	var p := u * (1.0 + nz.get_noise_3dv(u * 1.5) * 0.18) * sc * r
	var r0 := p.length()
	var n := (p / (sc * sc)).normalized()
	for k in scoops.size():
		var c: Vector3 = scoops[k][0]
		var rs: float = scoops[k][1]
		if p.distance_to(c) < rs:
			p = c + (p - c).normalized() * rs
			n = (c - p).normalized()
	if p.length() > r0: p = p.normalized() * r0
	return [p, n]

static func build(b: RefCounted, gene: Dictionary) -> MeshInstance3D:
	var f: Dictionary = gene.fossil
	var rng := Rng32.new(int(f.seed) * 7 + 3)
	var root: Node3D = b.root
	var gs: float = gene.scale
	var kind: String = f.kind
	if kind == "tears":
		return _tears(b, rng, gs)
	var g := chunk(rng, 1.0 * gs, int(f.scoops), Vector3(1.15, 0.95, 1.0))
	# its colour, vertex by vertex: black, with snowflakes or mahogany streaks
	var nz := FastNoiseLite.new()
	nz.seed = int(f.seed)
	nz.frequency = 1.3
	g.col.resize(g.v.size())
	# snowflakes: blossoms of cristobalite scattered through the glass, each a round grey-white spot with rays
	var flakes := []
	var sr := Rng32.new(int(f.seed) + 5)
	for k in 34:
		flakes.append([g.v[int(sr.next() * g.v.size())], (0.16 + sr.next() * 0.16) * gs, sr.next() * TAU])
	var black := Color(0.012, 0.012, 0.014)
	for i in g.v.size():
		var p := g.v[i]
		var c := black
		if kind == "mahogany":
			var band := nz.get_noise_3d(p.x * 1.2, p.y * 6.0 + nz.get_noise_3dv(p * 2.0) * 2.5, p.z * 1.2)
			# mahogany: red-brown clouds and streaks through the black, not all of it
			var blot := nz.get_noise_3dv(p * 1.4) + band * 0.5
			c = black.lerp(Color(0.085, 0.016, 0.005), smoothstep(0.0, 0.3, blot))
		g.col[i] = c
	var m := SpecMat.make({col = Color(1, 1, 1), rough = 0.02, coat = 0.3, coat_r = 0.01, env = 0.55, metal = 0.0,
		ir = 0.07 if kind == "rainbow" else 0.0, rf = 0.0})
	var mi := U.mesh(g, m, root, Vector3(0, 0.05, 0), Basis(Vector3.UP, rng.next() * TAU) * Basis(Vector3.RIGHT, (rng.next() - 0.5) * 0.5))
	mi.set_meta("col", true)
	if kind == "snowflake":
		# each a feathery blossom lying on the glass, following its curve: rays of their own lengths, grey-white in
		# the middle fading into the black, built on the surface itself (a flat decal sank under the scoops)
		var sg := Geo.new()
		for fl: Array in flakes:
			var at: Vector3 = fl[0]
			var u0 := at.normalized()
			var t1 := u0.cross(Vector3.UP if absf(u0.y) < 0.9 else Vector3.RIGHT).normalized().rotated(u0, float(fl[2]))
			var t2 := u0.cross(t1)
			var rr: float = float(fl[1]) / maxf(0.2, at.length())
			var nr := 20
			var rays := []
			for q in nr:
				rays.append((0.6 + 0.4 * sr.next()) if q % 2 == 0 else (0.5 + 0.25 * sr.next()))
			var mid := Color(0.66, 0.67, 0.68) * (0.8 + sr.next() * 0.25)
			var pt := func(a: float, f: float) -> Array:
				var sp: Array = surf(g, u0 + (t1 * cos(a) + t2 * sin(a)) * rr * f)
				return [(sp[0] as Vector3) + (sp[1] as Vector3) * 0.004, sp[1]]
			var cen: Array = pt.call(0.0, 0.0)
			for q in nr:
				var a0 := TAU * q / nr
				var a1 := TAU * (q + 1) / nr
				var f0: float = rays[q]
				var f1: float = rays[(q + 1) % nr]
				var m0: Array = pt.call(a0, f0 * 0.5)
				var m1: Array = pt.call(a1, f1 * 0.5)
				var e0: Array = pt.call(a0, f0)
				var e1: Array = pt.call(a1, f1)
				var cm := mid * 0.85
				for tri: Array in [[cen, mid, m0, cm, m1, cm], [m0, cm, e0, black, e1, black], [m0, cm, e1, black, m1, cm]]:
					for e in 3:
						var vv: Array = tri[e * 2]
						sg.v.append(vv[0])
						sg.col.append(tri[e * 2 + 1])
						sg.own_n.append(vv[1])
		var fm := SpecMat.make({col = Color(1, 1, 1), rough = 0.6, side = "double"})
		var fmi := U.mesh(sg, fm, mi)
		fmi.set_meta("col", true)
	# the callout: a spot of what it is, on the side facing the viewer
	var view := Basis(Vector3.UP, -0.6) * Vector3.BACK
	var best := 0
	var best_s := -9.0
	for i in range(0, g.v.size(), 7):
		var w := (mi.transform.basis * g.own_n[i]).normalized()
		var s := w.dot(view) + (g.col[i].r * 2.0 if kind == "snowflake" else g.col[i].r * 3.0 if kind == "mahogany" else 0.0)
		if s > best_s:
			best_s = s
			best = i
	b._mark("ob_" + kind, mi.transform * g.v[best], (mi.transform.basis * g.own_n[best]).normalized())
	return mi

## Apache tears: three to six small rounded nodules of glass, smoky brown where light goes through, on and half
## in a lump of pale grey, frothy perlite
static func _tears(b: RefCounted, rng: Rng32, gs: float) -> MeshInstance3D:
	var root: Node3D = b.root
	var Q := RockKit.lump(rng, {r = 0.55 * gs, sx = 1.35, sy = 0.7, sz = 1.05, wave = 0.2, bumps = [[8, 0.6, 0.1]], pits = [60, 0.08, 0.07], seg = 48})
	var qg: Geo = RockKit.tint_cav(Q[0], Q[1], 0.6, Color(0.42, 0.42, 0.41))
	var pm := SpecMat.make({col = Color(1, 1, 1), rough = 0.9, grain = 0.8, ao = 1.0, dirt = {h = 99.0, a = 0.3, col = SpecMat.lin(0x8e8e88), fr = 0.0}})
	var rock := U.mesh(qg, pm, root, Vector3(0, -0.15, 0))
	# the nodules: black glass, mirror-smooth, a smoky brown glow where the light comes through their edge
	var tm := SpecMat.make({col = SpecMat.lin(0x1a100a), rough = 0.04, coat = 0.3, coat_r = 0.01, env = 0.6, emis = SpecMat.lin(0x1a0a04) * 0.15})
	var qn := qg.normals()
	var first: MeshInstance3D = null
	var n := 3 + int(rng.next() * 4)
	for k in n:
		var vi := int(rng.next() * qg.v.size())
		for t in 40:
			if qg.v[vi].y > 0.05 * gs: break
			vi = int(rng.next() * qg.v.size())
		var s := (0.12 + rng.next() * 0.09) * gs * (1.3 if k == 0 else 1.0)
		var tg := Geo.icosa(s, 3).scale(1.0, 1.2 + rng.next() * 0.25, 0.9).jitter(s * 0.04, 3.0 / s, int(rng.next() * 100000))
		var mi := U.mesh(tg, tm, root, rock.position + qg.v[vi] - qn[vi] * s * 0.15, Basis(U.quat_to(Vector3.UP, qn[vi])) * Basis(Vector3.UP, rng.next() * TAU))
		mi.set_meta("col", true)
		if first == null:
			first = mi
			b._mark("ob_tears", mi.position + qn[vi] * s * 0.9, qn[vi])
	return first
