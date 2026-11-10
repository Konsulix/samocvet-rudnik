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

## a copy of a shader material, as duplicate() makes it, without asking the renderer: duplicate() lists the shader's
## parameters through it, and on the build thread that waits for the renderer (a quarter of a second a copy). The
## names come from the shader's own text (its #includes too), the values from the material.
static var _uniforms := {}
static var _uni_lock := Mutex.new()
static var _uni_re: RegEx
static func mat_copy(m: ShaderMaterial) -> ShaderMaterial:
	var c := ShaderMaterial.new()
	c.shader = m.shader
	c.render_priority = m.render_priority
	c.next_pass = m.next_pass
	for k in m.get_meta_list(): c.set_meta(k, m.get_meta(k))
	if m.shader:
		for p: String in uniforms(m.shader):
			var v: Variant = m.get_shader_parameter(p)
			if v != null: c.set_shader_parameter(p, v)
	return c

static func uniforms(sh: Shader) -> PackedStringArray:
	_uni_lock.lock()
	var got: Variant = _uniforms.get(sh)
	if got == null:
		if _uni_re == null:
			_uni_re = RegEx.create_from_string("(?m)^\\s*uniform\\s+(?:(?:highp|mediump|lowp)\\s+)?\\w+\\s+(\\w+)")
		var names := PackedStringArray()
		_scan(sh.code, names, {})
		_uniforms[sh] = names
		got = names
	_uni_lock.unlock()
	return got

static func _scan(code: String, names: PackedStringArray, seen: Dictionary) -> void:
	for r in _uni_re.search_all(code):
		if not r.get_string(1) in names: names.append(r.get_string(1))
	for line in code.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("#include"):
			var path := t.get_slice("\"", 1)
			if seen.has(path) or not ResourceLoader.exists(path): continue
			seen[path] = true
			_scan((load(path) as ShaderInclude).code, names, seen)

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
			# (a batch of pieces keeps the box its pieces had, so the find is framed the same)
			var b: AABB = t * (n.get_meta("box") as AABB) if n.has_meta("box") else t * g.aabb()
			if first:
				out = b
				first = false
			else:
				out = out.merge(b)
	return out


## false: finds built as before 7.11 — no batching, the old bone shader, soil crumbs at full detail (admin "Skull speedups", to measure on a phone)
static var fast := true

## Many little pieces drawn as few. On a phone every object costs a draw call in each pass (shadows, depth, colour), and a
## skull with a few hundred soil crumbs and moss sprigs ran to thousands a frame. So, at the end of a build:
## - siblings sharing one plain opaque StandardMaterial3D (the soil at crystals' feet), 4 or more, become one mesh —
##   each piece moved by its own transform on the CPU, normals worked out per piece as before;
## - plant multimeshes (SpecPlants.scatter, meta "mmbuf") of the same mesh and material under one parent become one.
## Nothing moves and no shader sees a difference (neither the soil nor the plants look at their object's own space), so
## the picture is the same. Left alone: nodes under a script (it may move its children), nodes with children, the animated
## (root meta "anim"), and crystals — their shader draws zones and bands in each crystal's own space.
static func batch(root: Node3D) -> void:
	if not fast: return
	var skip := {}
	for a in root.get_meta("anim", []):
		if a is Array and (a as Array).size() and a[0] is Node: skip[a[0]] = true
		elif a is Node: skip[a] = true
	_batch(root, skip)

static func _batch(n: Node, skip: Dictionary) -> void:
	for c in n.get_children():
		if c.get_script() == null and c.get_child_count() > 0: _batch(c, skip)
	var pieces := {}
	var plants := {}
	for c in n.get_children():
		if c.get_script() != null or c.get_child_count() > 0 or skip.has(c) or not (c as Node3D) or not (c as Node3D).visible: continue
		if c is MultiMeshInstance3D and c.has_meta("mmbuf"):
			var mi := c as MultiMeshInstance3D
			var mm := mi.multimesh
			if mm.transform_format != MultiMesh.TRANSFORM_3D or not mm.use_colors or mm.use_custom_data: continue
			var k := "%d %d %d %d" % [mm.mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override else 0, mi.cast_shadow, mi.layers]
			if not plants.has(k): plants[k] = []
			plants[k].append(mi)
		elif c is MeshInstance3D and c.has_meta("geo") and c.get_meta_list().size() == 1:
			var m := c as MeshInstance3D
			var mat := m.material_override as StandardMaterial3D
			if not mat or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.mesh == null: continue
			var g: Geo = m.get_meta("geo")
			if g.rp.size() or g.bary.size() or g.own_n.size(): continue
			var k := "%d %d %d %d %d" % [mat.get_instance_id(), m.cast_shadow, m.layers, int(g.indexed()), int(g.col.size() == g.v.size())]
			if not pieces.has(k): pieces[k] = []
			pieces[k].append(m)
	for k: String in pieces:
		var list: Array = pieces[k]
		if list.size() < 4: continue
		var all := Geo.new()
		var box := AABB()
		for i in list.size():
			var m: MeshInstance3D = list[i]
			var g: Geo = m.get_meta("geo")
			var t := m.transform
			var b := t * g.aabb()
			box = b if i == 0 else box.merge(b)
			# the piece's normals as it had them (worked out on its own), turned with it
			var nr := g.normals()
			var base := all.v.size()
			for j in g.v.size():
				all.v.append(t * g.v[j])
				all.own_n.append((t.basis * nr[j]).normalized())
			if g.col.size() == g.v.size(): all.col.append_array(g.col)
			for j in g.idx: all.idx.append(base + j)
		var first: MeshInstance3D = list[0]
		var out := MeshInstance3D.new()
		out.material_override = first.material_override
		out.cast_shadow = first.cast_shadow
		out.layers = first.layers
		out.mesh = all.to_mesh()
		out.set_meta("geo", all)
		out.set_meta("box", box)
		n.add_child(out)
		n.move_child(out, first.get_index())
		for m: MeshInstance3D in list:
			n.remove_child(m)
			m.free()
	for k: String in plants:
		var list: Array = plants[k]
		if list.size() < 2: continue
		var buf := PackedFloat32Array()
		var count := 0
		for mi: MultiMeshInstance3D in list:
			var b: PackedFloat32Array = mi.get_meta("mmbuf")
			var t := mi.transform
			if t != Transform3D.IDENTITY:
				b = b.duplicate()
				for i in b.size() / 16:
					var o := i * 16
					var x := Transform3D(Basis(Vector3(b[o], b[o + 4], b[o + 8]), Vector3(b[o + 1], b[o + 5], b[o + 9]), Vector3(b[o + 2], b[o + 6], b[o + 10])), Vector3(b[o + 3], b[o + 7], b[o + 11]))
					put(b, i, t * x, Color(b[o + 12], b[o + 13], b[o + 14], b[o + 15]))
			buf.append_array(b)
			count += b.size() / 16
		var first: MultiMeshInstance3D = list[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = first.multimesh.mesh
		mm.instance_count = count
		mm.buffer = buf
		var out := MultiMeshInstance3D.new()
		out.multimesh = mm
		out.material_override = first.material_override
		out.cast_shadow = first.cast_shadow
		out.layers = first.layers
		out.set_meta("mmbuf", buf)
		n.add_child(out)
		n.move_child(out, first.get_index())
		for mi: MultiMeshInstance3D in list:
			n.remove_child(mi)
			mi.free()
