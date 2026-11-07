class_name SpecBloom
extends RefCounted
## Flowers built petal by petal (docs/skulls.md): chrysanthemum (rings of narrow cupped petals), hydrangea (a ball of
## four-petalled florets), cosmos (broad notched petals round a dark eye with stamens), buds, gypsophila wires with
## beads. Petals are curved strips (bent along and cupped across), shaded darker at the base and lit through from
## behind; gold flowers are metal. Used for the skull's bouquet and, small, for the shared layer's little flowers.

const U := preload("res://scripts/specimen/spec_util.gd")
const PETAL := preload("res://shaders/petal_soft.gdshader")

## colour sets: [main, second, gold-or-accent, centre]
const PALETTES := [
	[Color(0.36, 0.02, 0.05), Color(0.5, 0.04, 0.07), Color(1.0, 0.72, 0.28), Color(0.95, 0.68, 0.25)],   # crimson and gold
	[Color(0.95, 0.93, 0.9), Color(0.75, 0.62, 0.9), Color(0.85, 0.85, 0.88), Color(0.85, 0.7, 0.2)],    # white and lilac, silver
	[Color(0.95, 0.6, 0.7), Color(1.0, 0.85, 0.7), Color(0.95, 0.66, 0.25), Color(0.6, 0.3, 0.1)],      # pink and cream, gold
	[Color(0.25, 0.3, 0.75), Color(0.55, 0.65, 0.95), Color(0.85, 0.85, 0.88), Color(0.15, 0.1, 0.2)],   # blue, silver
	[Color(0.95, 0.5, 0.12), Color(0.95, 0.8, 0.2), Color(0.55, 0.06, 0.1), Color(0.3, 0.12, 0.04)],    # orange and yellow
]

static var _meshes := {}

## a petal: a strip along +Y from the base, `w` wide (of its length 1), bent forward along its length (`bend`, its tip
## toward +Z) and cupped across (`cup`); the tip pointed, round or notched. Vertex colour: red = darker to the base
static func petal(w: float, bend: float, cup: float, tip: String) -> ArrayMesh:
	var key := "%.2f|%.2f|%.2f|%s" % [w, bend, cup, tip]
	if _meshes.has(key): return _meshes[key]
	var nl := 10
	var nw := 6
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in nl + 1:
		var t := float(i) / nl
		var prof := sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0))
		if tip == "point": prof = pow(prof, 0.8) * (1.0 - pow(t, 4.0) * 0.3)
		elif tip == "round": prof = pow(sin(PI * clampf(t * 0.8 + 0.1, 0.0, 1.0)), 0.5)
		var hw := w * 0.5 * prof * (0.55 + 0.45 * t)
		var y := t
		var z := bend * t * t
		for j in nw + 1:
			var s := float(j) / nw * 2.0 - 1.0
			var x := s * hw
			# the notch: the tip's middle cut back
			var yy := y
			if tip == "notch" and t > 0.85: yy -= (1.0 - absf(s)) * 0.08 * (t - 0.85) / 0.15
			v.append(Vector3(x, yy, z + (s * s) * cup * hw * 2.0))
			c.append(Color(1, 1, 1))
			uv.append(Vector2(s, t))
	for i in nl:
		for j in nw:
			var a := i * (nw + 1) + j
			var b := a + nw + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	var g := Geo.new()
	g.v = v
	g.idx = idx
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = g.normals()
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_meshes[key] = m
	return m

static func _ball() -> ArrayMesh:
	if not _meshes.has("ball"):
		var g := Geo.sphere(1.0, 8, 6)
		g.fill_color(Color(1, 1, 1))
		_meshes.ball = g.to_mesh()
	return _meshes.ball

static func _rod() -> ArrayMesh:
	if not _meshes.has("rod"):
		var g := Geo.cylinder(1.0, 1.0, 1.0, 5, 1, true)
		g.translate(0, 0.5, 0)
		g.fill_color(Color(1, 1, 1))
		_meshes.rod = g.to_mesh()
	return _meshes.rod

## a set of instances to draw: mesh key → [mesh, transforms, colours, metal]
static func batch() -> Dictionary:
	return {}

static func _put(bt: Dictionary, key: String, mesh: Mesh, xf: Transform3D, col: Color, metal := false) -> void:
	var k := key + ("|m" if metal else "")
	if not bt.has(k): bt[k] = [mesh, [], [], metal]
	(bt[k][1] as Array).append(xf)
	(bt[k][2] as Array).append(col)

## a frame at `at` facing `face` (its +Z), spun round it
static func _frame(face: Vector3, spin: float) -> Basis:
	var ref := face.cross(Vector3.RIGHT if absf(face.x) < 0.9 else Vector3.FORWARD).normalized()
	var x := ref.rotated(face, spin)
	var y := face.cross(x)
	return Basis(x, y, face)

## one flower head: kind mum | hydrangea | cosmos | bud | sprig, `s` across, its colour, gold (metal) or not
static func head(bt: Dictionary, r: Rng32, kind: String, at: Vector3, face: Vector3, s: float, col: Color, accent: Color, metal := false) -> void:
	var fr := _frame(face, r.next() * TAU)
	match kind:
		"mum":
			# rings of narrow petals: the outer ones lying open and long, the inner shorter and rising to a cup
			var rings := 5
			for ri in rings:
				var f := float(ri) / (rings - 1)
				var n := int(lerpf(22.0, 10.0, f))
				var ln := s * lerpf(0.5, 0.22, f)
				var rise := lerpf(0.25, 1.15, f)
				var pm := petal(0.22, lerpf(0.15, 0.5, f), 0.35, "point")
				for k in n:
					var a := (float(k) + ri * 0.5) / n * TAU
					var out := fr * Vector3(cos(a), sin(a), 0.0)
					var side := out.cross(fr.z).normalized()
					var b := Basis(side, out, side.cross(out)) * Basis(Vector3.RIGHT, rise)
					var cc := col.lerp(accent, f * 0.3) * (0.85 + r.next() * 0.25)
					_put(bt, "p_mum%d" % ri, pm, Transform3D(b * Basis.from_scale(Vector3.ONE * ln), at + fr.z * s * 0.02 * ri), cc, metal)
		"hydrangea":
			# a dense dome of florets, each four rounded petals round a tiny eye, overlapping, no gaps
			var nf := 70 + int(r.next() * 20)
			var pm := petal(0.85, 0.12, 0.2, "round")
			for k in nf:
				var u := Vector3(r.next() - 0.5, r.next() - 0.5, r.next() * 0.9 + 0.05).normalized()
				var d := (fr * u).normalized()
				var p := at + d * s * (0.38 + r.next() * 0.04)
				var ff := _frame(d, r.next() * TAU)
				var ps := s * (0.15 + r.next() * 0.04)
				var cc := col * (0.75 + r.next() * 0.4)
				for j in 4:
					var out := ff * Vector3(cos(j * TAU / 4.0), sin(j * TAU / 4.0), 0.0)
					var side := out.cross(d).normalized()
					var b := Basis(side, out, side.cross(out)) * Basis(Vector3.RIGHT, -0.15)
					_put(bt, "p_hyd", pm, Transform3D(b * Basis.from_scale(Vector3.ONE * ps), p), cc, metal)
				_put(bt, "ball", _ball(), Transform3D(Basis.from_scale(Vector3.ONE * ps * 0.07), p + d * ps * 0.04), accent if accent.get_luminance() < 0.5 else col.lightened(0.3))
			# the inside of the dome dark, so no hole shows through
			_put(bt, "ball", _ball(), Transform3D(fr * Basis.from_scale(Vector3(s * 0.36, s * 0.36, s * 0.3)), at + fr.z * s * 0.05), col.darkened(0.6))
		"cosmos":
			var n := 7 + int(r.next() * 3)
			var pm := petal(0.5, 0.18, 0.2, "notch")
			for k in n:
				var a := float(k) / n * TAU + r.next() * 0.1
				var out := fr * Vector3(cos(a), sin(a), 0.0)
				var side := out.cross(fr.z).normalized()
				var b := Basis(side, out, side.cross(out)) * Basis(Vector3.RIGHT, -0.3 - r.next() * 0.2)
				_put(bt, "p_cos", pm, Transform3D(b * Basis.from_scale(Vector3.ONE * s * 0.5), at), col * (0.9 + r.next() * 0.2), metal)
			# the dark eye and a ring of stamens
			_put(bt, "ball", _ball(), Transform3D(fr * Basis.from_scale(Vector3(s * 0.1, s * 0.1, s * 0.05)), at + fr.z * s * 0.03), accent)
			for k in 12:
				var a := float(k) / 12.0 * TAU
				var p := at + fr * Vector3(cos(a) * s * 0.08, sin(a) * s * 0.08, s * 0.08)
				_put(bt, "ball", _ball(), Transform3D(Basis.from_scale(Vector3.ONE * s * 0.018), p), Color(0.95, 0.75, 0.2))
		"bud":
			_put(bt, "ball", _ball(), Transform3D(fr * Basis.from_scale(Vector3(s * 0.16, s * 0.16, s * 0.26)), at + fr.z * s * 0.15), col.darkened(0.2), metal)
			var pm := petal(0.45, -0.25, 0.4, "point")
			for k in 4:
				var out := fr * Vector3(cos(k * TAU / 4.0), sin(k * TAU / 4.0), 0.0)
				var side := out.cross(fr.z).normalized()
				var b := Basis(side, out, side.cross(out)) * Basis(Vector3.RIGHT, -1.2)
				_put(bt, "p_bud", pm, Transform3D(b * Basis.from_scale(Vector3.ONE * s * 0.3), at), Color(0.25, 0.4, 0.15))
		"sprig":
			# gypsophila / stamen wires: fine stems fanning out, a bead on each
			for k in 7 + int(r.next() * 6):
				var d := (face + Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * 1.1).normalized()
				var ln := s * (0.5 + r.next() * 0.7)
				_put(bt, "rod", _rod(), Transform3D(Basis(U.quat_to(Vector3.UP, d)) * Basis.from_scale(Vector3(s * 0.006, ln, s * 0.006)), at), accent, metal)
				_put(bt, "ball", _ball(), Transform3D(Basis.from_scale(Vector3.ONE * s * 0.025), at + d * ln), accent, metal)

## a stem from `root` up to a head (a fine green tube), with a leaf or two
static func stem(bt: Dictionary, r: Rng32, root: Vector3, tip: Vector3, s: float) -> void:
	var d := tip - root
	_put(bt, "rod", _rod(), Transform3D(Basis(U.quat_to(Vector3.UP, d.normalized())) * Basis.from_scale(Vector3(s, d.length(), s)), root), Color(0.18, 0.32, 0.1))
	if r.next() < 0.6:
		var p := root + d * (0.3 + r.next() * 0.4)
		var out := d.normalized().cross(Vector3(r.next() - 0.5, 0, r.next() - 0.5)).normalized()
		var side := out.cross(d.normalized()).normalized()
		var b := Basis(side, (out + d.normalized() * 0.4).normalized(), side.cross(out)) * Basis(Vector3.RIGHT, -0.4)
		_put(bt, "p_leaf", petal(0.35, 0.2, 0.3, "point"), Transform3D(b.orthonormalized() * Basis.from_scale(Vector3.ONE * d.length() * 0.45), p), Color(0.22, 0.4, 0.13))

## draws a batch: one MultiMesh per mesh, petals soft and lit through from behind, metal ones polished gold
static func flush(bt: Dictionary, parent: Node3D) -> void:
	var soft := ShaderMaterial.new()
	soft.shader = PETAL
	var leafm := ShaderMaterial.new()
	leafm.shader = PETAL
	leafm.set_shader_parameter("mode", 1)
	var gold := ShaderMaterial.new()
	gold.shader = PETAL
	gold.set_shader_parameter("mode", 2)
	# stems, eyes, beads: plain
	var plain := StandardMaterial3D.new()
	plain.vertex_color_use_as_albedo = true
	plain.roughness = 0.7
	var plain_gold := StandardMaterial3D.new()
	plain_gold.vertex_color_use_as_albedo = true
	plain_gold.metallic = 1.0
	plain_gold.roughness = 0.25
	for k: String in bt:
		var e: Array = bt[k]
		var xs: Array = e[1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = e[0]
		mm.instance_count = xs.size()
		var buf := SpecUtil.mm_buf(xs.size())
		for i in xs.size():
			var c: Color = (e[2] as Array)[i]
			SpecUtil.put(buf, i, xs[i], c.srgb_to_linear())
		mm.buffer = buf
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var flat := k.begins_with("ball") or k.begins_with("rod")
		if flat: mi.material_override = plain_gold if e[3] else plain
		elif e[3]: mi.material_override = gold
		elif k.begins_with("p_leaf") or k.begins_with("leaf") or k.begins_with("lobe") or k.begins_with("pinna") or k.begins_with("p_bud"): mi.material_override = leafm
		else: mi.material_override = soft
		parent.add_child(mi)
