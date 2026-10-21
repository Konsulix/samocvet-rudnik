class_name SpecJewels
extends RefCounted
## Jewellery: gold work set with faceted stones; j = {rid, cols: ["#rrggbb", ...]}. Port of buildJewel.

const B := preload("res://scripts/specimen/spec_util.gd")

var root := Node3D.new()
var gold: ShaderMaterial
var cols: Array
var _mats := {}

static func build(seed_v: int, j: Dictionary) -> Node3D:
	var s := SpecJewels.new()
	return s._build(seed_v, j)

func gem_mat(hex: String) -> ShaderMaterial:
	if _mats.has(hex):
		return _mats[hex]
	var c := SpecMat.lin_s(hex)
	var m := SpecMat.make({col = c, emis = c * 0.1, rough = 0.02, metal = 0.05, coat = 1.0, flat = true, env = 2.8,
		transp = true, a = 0.88, side = "double", ir = 0.3, rf = 0.9, prio = 2})
	_mats[hex] = m
	return m

func col(k: int) -> String:
	return cols[k % cols.size()]

func G(geo: Geo, at := Vector3.ZERO, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	return B.mesh(geo, gold, parent if parent else root, at, B.eul(rot.x, rot.y, rot.z))

func bead(r: float, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	return G(Geo.sphere(r, 16, 12), at, Vector3.ZERO, parent)

## a faceted stone, table pointing along `dir`, sitting in a little gold collet
func stone(hex: String, size: float, at: Vector3, dir := Vector3(0, 0, 1), cut := "facet", parent: Node3D = null) -> Node3D:
	var g := Node3D.new()
	(parent if parent else root).add_child(g)
	g.transform = Transform3D(Basis(B.quat_to(Vector3.UP, dir.normalized())), at)
	var geo := RockKit.gem(cut).translate(0, -0.5, 0)
	B.mesh(geo, gem_mat(hex), g, Vector3.ZERO, Basis.from_scale(Vector3.ONE * size))
	B.mesh(Geo.torus(size * 0.6, size * 0.06, 8, 32), gold, g, Vector3.ZERO, Basis(Vector3.RIGHT, PI / 2))
	for k in 4:
		var a := k / 4.0 * 6.283 + 0.4
		B.mesh(Geo.cylinder(size * 0.035, size * 0.05, size * 0.32, 6), gold, g, Vector3(cos(a) * size * 0.6, size * 0.1, sin(a) * size * 0.6), B.eul(sin(a) * 0.5, 0, -cos(a) * 0.5))
	return g

## a pear-shaped drop, faceted
func drop_geo() -> Geo:
	var pts := []
	for k in 9:
		var t := k / 8.0
		pts.append(Vector2(sin(t * PI) * (0.5 - t * 0.22) * 0.9, -t * 1.4))
	return Geo.lathe(pts, 10)

func _build(seed_v: int, j: Dictionary) -> Node3D:
	cols = j.get("cols", [])
	if cols.is_empty():
		cols = ["#9fb4d0"]
	gold = SpecMat.make({col = SpecMat.lin(0xf2c35a), metal = 1.0, rough = 0.16, coat = 0.7, coat_r = 0.08, env = 1.9})
	var rid: String = j.get("rid", "ring")
	match rid:
		"ring":
			var sh := G(Geo.torus(0.5, 0.07, 20, 72))
			sh.scale = Vector3(1, 1, 1.6)
			G(Geo.cylinder(0.16, 0.1, 0.14, 24), Vector3(0, 0.55, 0))
			stone(col(0), 0.42, Vector3(0, 0.7, 0), Vector3(0, 1, 0), "master")
			for sx in [-1.0, 1.0]:
				bead(0.035, Vector3(sx * 0.2, 0.52, 0.06))
				bead(0.035, Vector3(sx * 0.2, 0.52, -0.06))
		"ear":
			for k in 2:
				var sx := -1.0 if k == 0 else 1.0
				var e := Node3D.new()
				e.position.x = sx * 0.38
				root.add_child(e)
				G(Geo.torus(0.13, 0.016, 8, 40, PI * 1.4), Vector3(0, 0.66, 0), Vector3(0, 0, -0.3), e)
				bead(0.045, Vector3(0, 0.5, 0), e)
				G(Geo.cylinder(0.012, 0.012, 0.14, 6), Vector3(0, 0.4, 0), Vector3.ZERO, e)
				B.mesh(drop_geo(), gem_mat(col(k)), e, Vector3(0, 0.32, 0), Basis.from_scale(Vector3.ONE * 0.36))
				var cap := G(Geo.sphere(0.07, 16, 8, 0, 6.283, 0, 1.2), Vector3(0, 0.34, 0), Vector3.ZERO, e)
				cap.scale.y = 0.7
		"pend":
			# a fine chain hanging in a curve
			var link := Geo.torus(0.028, 0.007, 6, 12)
			for k in 41:
				var t := k / 40.0 * 2.0 - 1.0
				G(link, Vector3(t * 0.78, 0.95 - (1.0 - t * t) * 0.62, 0), Vector3(0, PI / 2 if k % 2 else 0.0, atan2(-0.62 * 2.0 * t * -1.0, 1.0)))
			G(Geo.torus(0.06, 0.014, 8, 24), Vector3(0, 0.28, 0), Vector3(0, PI / 2, 0))
			stone(col(0), 0.5, Vector3(0, -0.06, 0), Vector3(0, 0, 1), "master")
			G(Geo.torus(0.34, 0.03, 10, 48), Vector3(0, -0.06, -0.02))
			stone(col(1), 0.16, Vector3(0, -0.5, 0), Vector3(0, 0, 1))
			bead(0.03, Vector3(0, -0.38, 0))
		"brooch":
			# a gold flower: petals, a ring of beads, the stones set face-up
			for k in 7:
				var a := k / 7.0 * 6.283
				var pe := G(Geo.sphere(1, 20, 12), Vector3(cos(a) * 0.3, sin(a) * 0.3, -0.04), Vector3(0, 0, a))
				pe.scale = Vector3(0.27, 0.14, 0.05)
			for k in 14:
				var a := k / 14.0 * 6.283
				bead(0.028, Vector3(cos(a) * 0.22, sin(a) * 0.22, 0.03))
			stone(col(0), 0.34, Vector3(0, 0, 0.06), Vector3(0, 0, 1), "master")
			stone(col(1), 0.15, Vector3(cos(0.45) * 0.5, sin(0.45) * 0.5, 0.04), Vector3(0, 0, 1))
			stone(col(2), 0.15, Vector3(cos(3.6) * 0.5, sin(3.6) * 0.5, 0.04), Vector3(0, 0, 1))
			for a in [1.6, 5.0]:
				var lf := G(Geo.sphere(1, 16, 10), Vector3(cos(a) * 0.52, sin(a) * 0.52, -0.06), Vector3(0, 0, a))
				lf.scale = Vector3(0.2, 0.08, 0.03)
		"diadem":
			# a curved band with rising scrolls, tallest in the middle
			var bandm := G(Geo.torus(0.8, 0.045, 10, 80, PI * 0.9), Vector3.ZERO, Vector3(PI / 2, 0, PI * 0.05))
			bandm.scale.z = 2.0
			var at := func(a: float) -> Vector3: return Vector3(cos(a) * 0.8, 0, sin(a) * 0.8)
			for k in 9:
				var a := PI * (0.12 + k * 0.085)
				var h := 0.2 + sin(k / 8.0 * PI) * 0.45
				var b: Vector3 = at.call(a)
				G(Geo.cone(0.035, h, 6), Vector3(b.x, h / 2, b.z))
				bead(0.03, Vector3(b.x, h + 0.02, b.z))
				if k % 2 == 0:
					G(Geo.torus(0.07, 0.012, 6, 20), Vector3(b.x, h * 0.55, b.z), Vector3(0, -a + PI / 2, 0))
			var cb: Vector3 = at.call(PI / 2)
			stone(col(0), 0.38, Vector3(cb.x, 0.42, cb.z + 0.04), Vector3(0, 0, 1), "master")
			var q := 0
			for fk in [[0.3, 1], [0.7, 2], [0.38, 3]]:
				var a := PI * (0.62 if q == 2 else float(fk[0]))
				var b: Vector3 = at.call(a)
				stone(col(fk[1]), 0.2, Vector3(b.x * 1.04, 0.05, b.z * 1.04), Vector3(b.x, 0, b.z))
				q += 1
		_:
			# the crown: band, rims, pointed fleurons with pearls, arches, an orb, a velvet cap, stones all round
			var bm := SpecMat.make({col = SpecMat.lin(0xf2c35a), metal = 1.0, rough = 0.16, coat = 0.7, coat_r = 0.08, env = 1.9, side = "double"})
			B.mesh(Geo.cylinder(0.56, 0.5, 0.34, 64, 1, true), bm, root)
			G(Geo.torus(0.5, 0.035, 10, 64), Vector3(0, -0.17, 0), Vector3(PI / 2, 0, 0))
			G(Geo.torus(0.56, 0.035, 10, 64), Vector3(0, 0.17, 0), Vector3(PI / 2, 0, 0))
			var pearl := SpecMat.make({col = B.raw(0xf4efe6), rough = 0.25, coat = 1.0, env = 1.4})
			for k in 8:
				var a := k / 8.0 * 6.283
				var x := cos(a) * 0.56
				var z := sin(a) * 0.56
				G(Geo.cone(0.09, 0.32, 4), Vector3(x, 0.33, z), Vector3(0, -a, 0))
				B.mesh(Geo.sphere(0.045, 16, 10), pearl, root, Vector3(x, 0.52, z))
			for r in [0.0, PI / 2]:
				var ar := G(Geo.torus(0.54, 0.03, 8, 48, PI), Vector3(0, 0.17, 0), Vector3(0, r, 0))
				ar.scale.y = 0.9
			bead(0.08, Vector3(0, 0.7, 0))
			G(Geo.box(0.03, 0.16, 0.03), Vector3(0, 0.83, 0))
			G(Geo.box(0.1, 0.03, 0.03), Vector3(0, 0.85, 0))
			var cap := B.mesh(Geo.sphere(0.52, 32, 16, 0, 6.283, 0, PI / 2), SpecMat.make({col = SpecMat.lin(0x8a1020), rough = 0.9}), root, Vector3(0, 0.12, 0))
			cap.scale.y = 0.8
			for k in 10:
				var a := k / 10.0 * 6.283
				var d := Vector3(cos(a), 0, sin(a))
				stone(col(4 if k % 2 else (k / 2) % 4), 0.1 if k % 2 else 0.16, d * 0.56, d)
	root.rotation.x = 0.25 if rid == "ring" else 0.3 if rid == "crown" or rid == "diadem" else 0.0
	root.set_meta("glow", B.raw(0xe4ae39))
	return root
