class_name SpecObsidian
extends RefCounted
## Obsidian, Etna's volcanic glass: a chunk broken with conchoidal fracture — smooth curved scoops meeting in sharp
## ridges — black and mirror-glossy. Its kinds (genes, on their own stream): plain black; snowflake (grey-white
## blossoms of cristobalite in it); mahogany (red-brown streaks through the black); rainbow (a sheen of colours in
## bands under the surface); and Apache tears — small rounded nodules, smoky brown against the light, still sitting
## in their pale grey perlite.

const U := preload("res://scripts/specimen/spec_util.gd")

const KINDS := [["black", 3.0], ["snowflake", 3.0], ["mahogany", 2.0], ["rainbow", 2.4], ["tears", 1.5]]
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
static func chunk(rng: Rng32, r: float, n_scoops: int, sc: Vector3, detail := 5, bite_k := 1.0) -> Geo:
	var base := Geo.icosa(1.0, detail)
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
		var bite := r * (0.22 + rng.next() * 0.38) * bite_k
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
	var m := SpecMat.make({col = Color(1, 1, 1), rough = 0.02, coat = 0.3, coat_r = 0.01, env = 1.1, metal = 0.0,
		ir = 0.15 if kind == "rainbow" else 0.0, oil = 0.6 if kind == "rainbow" else 0.0, rf = 0.0})
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

## Apache tears: rounded nodules of black glass, half sunk in a lump of pale grey, frothy perlite (they weather out
## of it). The perlite is the generator's own rock (relief and photo scan of vesicular lava, grey); a tear is a lumpy
## egg whose old skin is dull, pitted, grey-black, with a scoop or two broken off it showing the mirror-black glass
static func _tears(b: RefCounted, rng: Rng32, gs: float) -> MeshInstance3D:
	var root: Node3D = b.root
	var R := RockKit.rock(rng, "gypsum", "chunk", 32, 0.0)
	var rg: Geo = R.geo
	for i in rg.v.size():
		rg.v[i] *= gs
	# finer on top, where the tears sit and the perlite cracks in rings round them
	rg.subdivide(1, Vector3.DOWN, 0.0).weld()
	var grey := SpecMat.hsl(0.6 + rng.next() * 0.05, 0.04 + rng.next() * 0.03, 0.42 + rng.next() * 0.08).srgb_to_linear()
	var pm := SpecMat.make({col = Color(1, 1, 1), rough = 0.95, grain = 0.5, ao = 1.0,
		dirt = {h = 99.0, a = 0.3, col = grey, fr = 0.0, scan = RockKit.SCAN_OF["gypsum"]}})
	pm.set_meta("rock", true)
	pm.set_shader_parameter("ir_k", 0.0)
	var rock := U.mesh(rg, pm, root, Vector3(0, -0.1 * gs, 0))
	rock.set_meta("base", grey)
	# the tears: on the top and the upper sides, the side towards the viewer first, never touching each other
	var rn := rg.normals()
	var view := Basis(Vector3.UP, -0.6) * Vector3.BACK
	var cand := []
	for i in range(0, rg.v.size(), 3):
		if rn[i].y > 0.15 and rg.v[i].y > 0.0:
			cand.append(i)
	# the old skin dull and pitted, the broken scoops mirror-black
	var skin_m := SpecMat.make({col = Color(1, 1, 1), rough = 0.5, coat = 0.15, coat_r = 0.3, env = 0.7, grain = 0.9})
	var glass_m := SpecMat.make({col = Color(1, 1, 1), rough = 0.03, coat = 0.4, coat_r = 0.01, env = 1.1})
	var first: Node3D = null
	var placed := []
	var n := 6 + int(rng.next() * 5)
	for k in n:
		var s := (0.08 + rng.next() * 0.07) * gs if k else (0.22 + rng.next() * 0.04) * gs
		var best := -1
		var best_s := -99.0
		for t in 24:
			var vi: int = cand[int(rng.next() * cand.size())]
			var p := rg.v[vi]
			var ok := true
			for q: Array in placed:
				if p.distance_to(q[0]) < (s + float(q[1])) * 0.95:
					ok = false
					break
			if not ok: continue
			var sc := rn[vi].dot(view) * (2.0 if k == 0 else 0.3) + rn[vi].y * 0.5 + rng.next() * 0.3
			if sc > best_s:
				best_s = sc
				best = vi
		if best < 0: continue
		var at := rg.v[best]
		var nr := rn[best]
		placed.append([at, s])
		# sunk in to nearly half its height, leaning with the rock
		var mi := Node3D.new()
		root.add_child(mi)
		mi.transform = Transform3D(Basis(U.quat_to(Vector3.UP, nr.lerp(Vector3.UP, 0.4).normalized())) * Basis(Vector3.UP, rng.next() * TAU),
			rock.position + at - nr * s * (0.32 if k == 0 else 0.45))
		var skin := Color(0.03, 0.026, 0.024) * (0.7 + rng.next() * 0.5)
		var parts := [Geo.new(), Geo.new(), Geo.new()]
		var w := Vector3.UP
		var cut := 0.0
		var shift := Vector3.ZERO
		if k == 0:
			# the lantern: a big tear with a window polished on it towards the viewer — smoky brown glass the
			# light comes through, glowing like tea held to the sun; the rest of it in its dull skin
			# (two smooth chips broken off its skin, glossy black — never where the window goes)
			var tg := chunk(rng, s, 2, Vector3(1.05, 1.0, 0.95), 4, 0.55)
			var tsc: Vector3 = (tg.get_meta("shape") as Array)[2]
			var chip := PackedByteArray()
			chip.resize(tg.v.size())
			for i in tg.v.size():
				chip[i] = 0 if tg.own_n[i].dot((tg.v[i] / (tsc * tsc)).normalized()) > 0.9995 else 1
			w = (mi.transform.basis.inverse() * (view * 0.6 + nr * 0.6)).normalized()
			var dmax := -9.0
			for p in tg.v: dmax = maxf(dmax, p.dot(w))
			# a polished window: a low dome, its outline uneven and lopsided (a hand did it, not a machine), the skin
			# sloping softly down into it; the glass itself in broad uneven facets
			cut = dmax - s * 0.55
			var rr := s * 1.7
			var cc := w * (cut + s * 0.12 - rr)
			var rc := 9.0
			for t in range(0, tg.v.size(), 3):
				# where the skin's surface crosses the cut: the window can be no wider
				for e in 3:
					var a0 := tg.v[t + e]
					var a1 := tg.v[t + (e + 1) % 3]
					var h0 := a0.dot(w) - cut
					var h1 := a1.dot(w) - cut
					if h0 * h1 < 0.0:
						var x := a0.lerp(a1, h0 / (h0 - h1))
						rc = minf(rc, (x - w * x.dot(w)).length())
			var t1 := w.cross(Vector3.UP if absf(w.y) < 0.9 else Vector3.RIGHT).normalized()
			var t2 := w.cross(t1)
			var wn := FastNoiseLite.new()
			wn.seed = int(rng.next() * 100000.0)
			wn.frequency = 0.9
			shift = (t1 * (rng.next() - 0.5) + t2 * (rng.next() - 0.5)) * rc * 0.22
			# the outline: its radius at each angle
			var rim := func(a: float) -> float:
				return rc * (0.74 + 0.18 * wn.get_noise_2d(cos(a) * 1.6, sin(a) * 1.6) + 0.06 * sin(a * 2.0 + 1.3))
			var dome := func(off: Vector3) -> Vector3:
				return cc + off + w * sqrt(maxf(0.0, rr * rr - off.length_squared()))
			for i in tg.v.size():
				var h := tg.v[i].dot(w) - cut
				var off := tg.v[i] - w * tg.v[i].dot(w)
				var o2 := off - shift
				var ra: float = rim.call(atan2(o2.dot(t2), o2.dot(t1)))
				var dd := o2.length() / ra
				# the skin near the window: worn down towards the dome, softly (a lip, not a cliff)
				var dv: Vector3 = dome.call(off)
				var lip := 1.0 - smoothstep(1.0, 1.7, dd)
				if lip > 0.0 and tg.v[i].dot(w) > dv.dot(w) - s * 0.02:
					tg.v[i] = tg.v[i].lerp(dv - w * s * 0.015 * (1.0 - lip), lip)
					tg.own_n[i] = tg.own_n[i].lerp((tg.v[i] - cc).normalized(), lip).normalized()
			for t in range(0, tg.v.size(), 3):
				var inside := 0
				for e in 3:
					var p := tg.v[t + e]
					var o2 := p - w * p.dot(w) - shift
					if o2.length() < float(rim.call(atan2(o2.dot(t2), o2.dot(t1)))) * 0.96: inside += 1
				if inside == 3: continue
				var nch := chip[t] + chip[t + 1] + chip[t + 2]
				var pg: Geo = parts[1 if nch >= 2 else 0]
				for e in 3:
					pg.v.append(tg.v[t + e])
					pg.own_n.append(tg.own_n[t + e])
					pg.col.append(Color(0.006, 0.005, 0.005) if nch >= 2 else skin)
			# the glass: a coarse, jittered net over the outline, each triangle flat — broad polished facets
			var NR := 6
			var NS := 22
			var fz := FastNoiseLite.new()
			fz.seed = wn.seed + 7
			fz.frequency = 3.0 / s
			var pts := []
			for ri in NR + 1:
				var row := []
				for si in NS:
					var a := TAU * (si + (0.5 * (ri % 2))) / NS + (rng.next() - 0.5) * 0.12 * float(ri > 0 and ri < NR)
					var f := float(ri) / NR
					if ri > 0 and ri < NR: f += (rng.next() - 0.5) * 0.08
					var off := shift + (t1 * cos(a) + t2 * sin(a)) * float(rim.call(a)) * 1.02 * f
					var q: Vector3 = dome.call(off)
					# bumps of the polish, none at the edge (it meets the lip)
					q += w * fz.get_noise_3dv(off) * s * 0.035 * (1.0 - f * f)
					row.append(q + w * 0.0015 * gs)
				pts.append(row)
			var dg: Geo = parts[2]
			var tri := func(a: Vector3, b2: Vector3, c: Vector3) -> void:
				var fnrm := (b2 - a).cross(c - a).normalized()
				if fnrm.dot(w) < 0.0:
					fnrm = -fnrm
					var tmp := b2
					b2 = c
					c = tmp
				var sm := ((a + b2 + c) / 3.0 - cc).normalized()
				var nn := sm.lerp(fnrm, 0.75).normalized()
				for pv in [a, b2, c]:
					dg.v.append(pv)
					dg.own_n.append(nn)
					dg.col.append(Color(1, 1, 1))
			for ri in NR:
				for si in NS:
					var a0: Vector3 = pts[ri][si]
					var a1: Vector3 = pts[ri][(si + 1) % NS]
					var b0: Vector3 = pts[ri + 1][si]
					var b1: Vector3 = pts[ri + 1][(si + 1) % NS]
					tri.call(a0, b0, b1)
					tri.call(a0, b1, a1)
		else:
			var tg := chunk(rng, s, 1 + int(rng.next() * 3), Vector3(1.0 + rng.next() * 0.3, 0.8 + rng.next() * 0.3, 0.8 + rng.next() * 0.2), 3, 0.6)
			var sc3: Vector3 = (tg.get_meta("shape") as Array)[2]
			for t in range(0, tg.v.size(), 3):
				var on := 0
				for e in 3:
					if tg.own_n[t + e].dot((tg.v[t + e] / (sc3 * sc3)).normalized()) > 0.9995: on += 1
				var pg: Geo = parts[0 if on >= 2 else 1]
				for e in 3:
					pg.v.append(tg.v[t + e])
					pg.own_n.append(tg.own_n[t + e])
					pg.col.append(skin if on >= 2 else Color(0.006, 0.005, 0.005))
		for pi in 3:
			if (parts[pi] as Geo).v.size():
				var pm2: Material = [skin_m, glass_m, null][pi]
				if pi == 2:
					# the window: lit through like amber — the dark tea of the glass deepening with the way through it,
					# a little smoke, a bubble or two, the studio's lamps bent through it
					var am := ShaderMaterial.new()
					am.shader = SpecFlower.AMBER
					am.set_shader_parameter("sigma", Vector3(0.42, 0.9, 2.2) / (s * 2.2))
					am.set_shader_parameter("axes", Vector3(1.05, 1.0, 0.95) * s * 1.02)
					am.set_shader_parameter("hold_k", 0.0)
					am.set_shader_parameter("back_k", 1.25)
					am.set_shader_parameter("base_k", 0.55)
					am.set_shader_parameter("flow_k", 0.45)
					am.set_shader_parameter("dirt_k", 0.6)
					am.set_shader_parameter("debris_k", 0.3)
					am.set_shader_parameter("bubble_k", 0.4)
					am.set_shader_parameter("crust_k", 0.0)
					am.set_shader_parameter("light_col", Vector3(1.0, 0.8, 0.55))
					am.set_shader_parameter("seed", rng.next() * 60.0)
					pm2 = am
				U.mesh(parts[pi], pm2, mi).set_meta("col", true)
		if k == 0:
			# the light inside: warm, as if the sun stood behind it — it reaches the perlite round it too
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.68, 0.36)
			lamp.light_energy = 1.4
			lamp.omni_range = s * 3.2
			lamp.shadow_enabled = false
			lamp.position = Vector3(0, s * 0.15, 0)
			mi.add_child(lamp)
		if first == null:
			first = mi
			b._mark("ob_tears", mi.position + nr * s * 0.6, nr)
	# one tear has weathered out: an empty socket on top, the tear itself rolled down onto a ledge below
	var pit_at := Vector3.ZERO
	var pit_r := 0.0
	var ps := (0.09 + rng.next() * 0.04) * gs
	var pit_s := -99.0
	for t in 40:
		var vi: int = cand[int(rng.next() * cand.size())]
		var ok := true
		for q: Array in placed:
			if rg.v[vi].distance_to(q[0]) < (ps + float(q[1])) * 1.15:
				ok = false
				break
		var sc := rn[vi].dot(view) + rng.next() * 0.3
		if ok and sc > pit_s:
			pit_s = sc
			pit_at = rg.v[vi]
			pit_r = ps
	# the loose tear: rolled just out of its socket, resting on the socket's lip on the side towards the viewer
	var ledge := -1
	if pit_r > 0.0:
		var want := pit_at + view.slide(Vector3.UP).normalized() * pit_r * 1.25
		var bd := 99.0
		for i in rg.v.size():
			var dd := rg.v[i].distance_to(want)
			if dd < bd:
				bd = dd
				ledge = i
	if ledge >= 0:
		var lr := ps * 0.95
		var lt := chunk(rng, lr, 2 + int(rng.next() * 2), Vector3(1.15, 0.85, 0.95), 3, 0.7)
		var lsc: Vector3 = (lt.get_meta("shape") as Array)[2]
		var lp := [Geo.new(), Geo.new()]
		var lskin := Color(0.03, 0.026, 0.024)
		for t in range(0, lt.v.size(), 3):
			var on := 0
			for e in 3:
				if lt.own_n[t + e].dot((lt.v[t + e] / (lsc * lsc)).normalized()) > 0.9995: on += 1
			var pg: Geo = lp[0 if on >= 2 else 1]
			for e in 3:
				pg.v.append(lt.v[t + e])
				pg.own_n.append(lt.own_n[t + e])
				pg.col.append(lskin if on >= 2 else Color(0.006, 0.005, 0.005))
		var ln := Node3D.new()
		root.add_child(ln)
		ln.transform = Transform3D(Basis(U.quat_to(Vector3.UP, rn[ledge])) * Basis(Vector3.UP, rng.next() * TAU) * Basis(Vector3.RIGHT, 1.2),
			rock.position + rg.v[ledge] + rn[ledge] * lr * 0.55)
		for pi in 2:
			if (lp[pi] as Geo).v.size():
				U.mesh(lp[pi], [skin_m, glass_m][pi], ln).set_meta("col", true)
	# perlite cracks round each tear in rings, like the skins of an onion (it shrank round the glass as it hydrated);
	# a little wavering and broken, not drawn with compasses
	var rnz := FastNoiseLite.new()
	rnz.seed = int(rng.next() * 100000.0)
	rnz.frequency = 2.5 / gs
	var rn2 := rg.normals()
	if pit_r > 0.0:
		placed.append([pit_at, pit_r])
	for i in rg.v.size():
		var dark := 0.0
		# the socket: a smooth round cup where the tear sat, darker inside
		if pit_r > 0.0:
			var pd := rg.v[i].distance_to(pit_at) / pit_r
			if pd < 1.25:
				var cup := 1.0 - smoothstep(0.0, 1.25, pd)
				rg.v[i] -= rn2[i] * cup * cup * pit_r * 0.9
				var c0 := rg.col[i]
				rg.col[i] = Color(c0.r * (1.0 - 0.45 * cup), c0.g, c0.b * (1.0 - 0.45 * cup))
		for q: Array in placed:
			var r0: float = q[1]
			var d := rg.v[i].distance_to(q[0]) - r0 * 0.75 + rnz.get_noise_3dv(rg.v[i]) * r0 * 0.12
			if d <= 0.0 or d > r0 * 2.4: continue
			var ph := d / (r0 * 0.42)
			var line := 1.0 - smoothstep(0.0, 0.22, absf(ph - roundf(ph)))
			# broken here and there
			line *= smoothstep(-0.65, -0.2, rnz.get_noise_3dv(rg.v[i] * 0.6 + Vector3(9, 0, 0)))
			dark = maxf(dark, line * (1.0 - d / (r0 * 2.4)))
		if dark > 0.0:
			rg.v[i] -= rn2[i] * dark * 0.016 * gs
			var c := rg.col[i]
			rg.col[i] = Color(c.r * (1.0 - 0.8 * dark), c.g, c.b * (1.0 - 0.8 * dark))
	return rock
