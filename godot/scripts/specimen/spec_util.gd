class_name SpecUtil
extends RefCounted
## Helpers shared by the specimen, jewellery and machine builders: three.js-style rotations and node making.

static func raw(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xFF)

static func quat_to(a: Vector3, b: Vector3) -> Quaternion:
	# three.js setFromUnitVectors: well defined for opposite vectors too
	var r := a.dot(b) + 1.0
	var q: Quaternion
	if r < 1e-6:
		if absf(a.x) > absf(a.z):
			q = Quaternion(-a.y, a.x, 0, 0)
		else:
			q = Quaternion(0, -a.z, a.y, 0)
	else:
		var c := a.cross(b)
		q = Quaternion(c.x, c.y, c.z, r)
	return q.normalized()

static func eul(x: float, y: float, z: float) -> Basis:
	return Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y) * Basis(Vector3.BACK, z)

static func eul_zxy(x: float, y: float, z: float) -> Basis:
	return Basis(Vector3.BACK, z) * Basis(Vector3.RIGHT, x) * Basis(Vector3.UP, y)

static func mesh(geo: Geo, mat: Material, parent: Node3D, at := Vector3.ZERO, basis := Basis.IDENTITY) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.set_meta("geo", geo)
	m.material_override = mat
	m.transform = Transform3D(basis, at)
	if not (mat is ShaderMaterial and mat.get_meta("dirt", false)):
		m.mesh = geo.to_mesh()
	parent.add_child(m)
	return m

## MultiMesh data in one go: a whole buffer is a single call to the renderer, where per-instance setters
## are thousands of calls from the build thread that the render thread (on a phone, a visible hitch) must chew through.
## Layout for TRANSFORM_3D with colours: 12 floats of the transform (basis rows with origin), then RGBA.
static func mm_buf(n: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(n * 16)
	return buf

static func put(buf: PackedFloat32Array, k: int, t: Transform3D, c: Color) -> void:
	var i := k * 16
	var b := t.basis
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = t.origin.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = t.origin.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = t.origin.z
	buf[i + 12] = c.r; buf[i + 13] = c.g; buf[i + 14] = c.b; buf[i + 15] = c.a

static func inst(geo: Geo, mat: Material, n: int, place: Callable, parent: Node3D) -> MultiMeshInstance3D:
	if n <= 0:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = geo.to_mesh()
	mm.instance_count = n
	var buf := mm_buf(n)
	for k in n:
		var r: Array = place.call(k)
		put(buf, k, r[0], r[1])
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## the transform of `n` in the space of `top`
static func rel_xform(n: Node3D, top: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent() as Node3D
	while p and p != top:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t

## bounding box of real geometry (instanced growths don't count), in `top` space
static func box_of(top: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [top]
	while stack.size():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.has_meta("geo"):
			var g: Geo = n.get_meta("geo")
			var t := Transform3D.IDENTITY if n == top else rel_xform(n, top)
			var b := t * g.aabb()
			if first:
				out = b
				first = false
			else:
				out = out.merge(b)
	return out

