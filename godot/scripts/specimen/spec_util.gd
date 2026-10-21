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

static func inst(geo: Geo, mat: Material, n: int, place: Callable, parent: Node3D) -> MultiMeshInstance3D:
	if n <= 0:
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = geo.to_mesh()
	mm.instance_count = n
	for k in n:
		var r: Array = place.call(k)
		mm.set_instance_transform(k, r[0])
		mm.set_instance_color(k, r[1])
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

