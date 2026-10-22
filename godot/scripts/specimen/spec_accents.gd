class_name SpecAccents
extends RefCounted
## Small things that make a specimen interesting, picked by its genes: fluffy pom-poms of fine fibres,
## straw-gold hairs, lichen crusts, dark spots and coloured clouds inside the glass.
## Fibres are thin tapered ribbons on a MultiMesh: hundreds per tuft for a few draw calls.

static var _strand := {}
static var _mat: ShaderMaterial

## a tapered ribbon (two, crossed), base at the origin, one unit long, bending sideways by `bend`
static func strand_mesh(bend: float) -> ArrayMesh:
	var key := snappedf(bend, 0.1)
	if _strand.has(key):
		return _strand[key]
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var segs := 6
	for plane in 2:
		var side := Vector3.RIGHT if plane == 0 else Vector3.BACK
		var o := v.size()
		for i in segs + 1:
			var t := i / float(segs)
			var w := 0.5 * pow(1.0 - t, 0.8) + 0.02
			var ctr := Vector3(bend * t * t, t, 0)
			v.append(ctr - side * w)
			v.append(ctr + side * w)
			var k := lerpf(0.3, 1.0, pow(t, 0.7))
			c.append(Color(k, k, k))
			c.append(Color(k, k, k))
		for i in segs:
			var a := o + i * 2
			idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var g := Geo.new()
	g.v = v
	g.idx = idx
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = g.normals()
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_strand[key] = m
	return m

static func fibre_mat() -> ShaderMaterial:
	if not _mat:
		_mat = SpecMat.make({col = Color(1, 1, 1), rough = 0.5, side = "double", spec = 0.4})
	return _mat

## a burst of fibres from `p` around direction `n`
## area > 0 spreads the roots over a patch (tangled hair) instead of one point (a pom-pom)
static func tuft(parent: Node3D, rng: Rng32, p: Vector3, n: Vector3, count: int, length: float, thick: float, spread: float, bend: float, cols: Array, area := 0.0) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = strand_mesh(bend)
	mm.instance_count = count
	var T := n.cross(Vector3.FORWARD if absf(n.y) > 0.9 else Vector3.UP).normalized()
	var B := n.cross(T)
	for k in count:
		var d := (n + Vector3(rng.next() - 0.5, rng.next() - 0.5, rng.next() - 0.5) * 2.0 * spread).normalized()
		var ln := length * (0.45 + rng.next() * 0.7)
		var b := Basis(SpecUtil.quat_to(Vector3.UP, d)) * Basis(Vector3.UP, rng.next() * TAU) * Basis.from_scale(Vector3(thick, ln, thick))
		var root := p + (T * (rng.next() - 0.5) + B * (rng.next() - 0.5)) * area * 2.0
		mm.set_instance_transform(k, Transform3D(b, root + d * rng.next() * length * 0.08))
		var cc: Color = cols[int(rng.next() * cols.size())]
		var v := 0.75 + rng.next() * 0.5
		mm.set_instance_color(k, Color(cc.r * v, cc.g * v, cc.b * v))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = fibre_mat()
	parent.add_child(mi)

## palettes the genes choose from (linear colours; a touch over 1 blooms)
const POMPOM := [
	[Color(1.25, 0.12, 0.42), Color(1.0, 0.3, 0.6), Color(0.6, 0.02, 0.15)],   # hot pink
	[Color(1.2, 0.08, 0.04), Color(1.0, 0.35, 0.08), Color(0.45, 0.02, 0.02)],  # scarlet
	[Color(1.2, 0.5, 0.06), Color(1.1, 0.8, 0.2), Color(0.6, 0.18, 0.02)],      # orange
	[Color(1.1, 0.95, 0.3), Color(1.0, 1.0, 0.75), Color(0.6, 0.45, 0.08)],     # sulphur yellow
	[Color(0.95, 0.93, 0.9), Color(0.8, 0.85, 0.95), Color(0.6, 0.6, 0.62)],    # white
	[Color(0.55, 0.15, 1.1), Color(0.85, 0.5, 1.2), Color(0.2, 0.04, 0.45)],    # violet
]
const STRAW := [
	[Color(0.85, 0.6, 0.22), Color(1.0, 0.82, 0.45), Color(0.55, 0.35, 0.12)],  # straw gold
	[Color(0.7, 0.4, 0.15), Color(0.9, 0.55, 0.25), Color(0.4, 0.2, 0.06)],     # rusty
	[Color(0.85, 0.85, 0.8), Color(0.65, 0.7, 0.72), Color(1.0, 0.95, 0.85)],   # silky white
]
const LICHEN := [Color(0.8, 0.95, 0.75), Color(1.4, 0.65, 0.22), Color(0.95, 0.95, 0.9), Color(1.2, 1.1, 0.35), Color(0.75, 0.9, 1.0)]
const CLOUDS := [Color(1.0, 0.75, 0.1), Color(1.0, 0.25, 0.08), Color(1.0, 0.2, 0.55), Color(0.35, 0.2, 1.0), Color(0.2, 0.9, 0.6)]
const MOSS := [Color(1, 1, 1), Color(1.25, 1.15, 0.6), Color(1.35, 0.6, 0.35), Color(0.8, 0.85, 0.55), Color(0.75, 0.95, 1.05)]

## dark rounded spots trapped inside a crystal
static func inkspots(main: MeshInstance3D, rng: Rng32, count: int) -> void:
	var bb: AABB = (main.get_meta("geo") as Geo).aabb()
	var m := SpecMat.make({col = Color(0.02, 0.018, 0.02), rough = 0.6, grain = 0.4})
	for k in count:
		var g := Geo.icosa(1, 1).jitter(0.18, 2.0, int(rng.next() * 100000))
		var s := (0.025 + pow(rng.next(), 1.5) * 0.06) * minf(bb.size.x, bb.size.z) * 2.0
		var p := bb.position + Vector3(0.2 + rng.next() * 0.6, 0.25 + rng.next() * 0.65, 0.2 + rng.next() * 0.6) * bb.size
		SpecUtil.mesh(g, m, main, p, SpecUtil.eul(rng.next() * 6, rng.next() * 6, rng.next() * 6) * Basis.from_scale(Vector3(s, s * (0.7 + rng.next() * 0.5), s)))
