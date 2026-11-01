class_name SpecPolar
extends RefCounted
## Proval's own legendary effects, from the polar night over the coal measures:
## "northern lights" — a curtain of aurora hanging round the find, its folds drifting, green below and violet above,
## its light on the stone; "frost bloom" — frost growing over every crystal like ferns on a winter window, holding,
## melting and growing again.

const U := preload("res://scripts/specimen/spec_util.gd")
const AURORA := preload("res://shaders/borealis.gdshader")
const FROST := preload("res://shaders/frost_bloom.gdshader")

## the curtain: a ring of quads round the find, open at one side, its hem a little below the top of the stone
static func borealis(root: Node3D, rng: Rng32) -> void:
	var bb := U.box_of(root)
	var c := bb.get_center()
	var R := Vector2(bb.size.x, bb.size.z).length() * 0.46
	var H := maxf(bb.size.y, R * 0.5) * 0.75
	var y0 := bb.position.y + bb.size.y * 0.5
	var a0 := rng.next() * TAU
	var span := TAU * (0.78 + rng.next() * 0.15)
	var cols := 120
	var rows := 10
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in cols + 1:
		var u := float(i) / cols
		var a := a0 + u * span
		# a loose oval, not a circle
		var r := R * (1.0 + 0.16 * sin(a * 2.0 + a0))
		for j in rows + 1:
			var w := float(j) / rows
			v.append(Vector3(c.x + cos(a) * r, y0 + w * H, c.z + sin(a) * r))
			uv.append(Vector2(u, w))
	for i in cols:
		for j in rows:
			var p := i * (rows + 1) + j
			var q := p + rows + 1
			idx.append_array([p, p + 1, q, q, p + 1, q + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	for p in v:
		normals.append(Vector3(p.x - c.x, 0, p.z - c.z).normalized())
	arr[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = AURORA
	mat.set_shader_parameter("center", c)
	mat.set_shader_parameter("radius", R)
	mat.set_shader_parameter("seed", rng.next() * 10.0)
	mat.render_priority = 100
	# (no "geo" meta: the view frames the stone, not the sky over it)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# its light on the stone: green from above, violet from the far side
	for k in 2:
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.35, 1.0, 0.55) if k == 0 else Color(0.6, 0.35, 1.0)
		lt.light_energy = 0.6 if k == 0 else 0.45
		lt.omni_range = R * 2.6
		lt.omni_attenuation = 1.2
		lt.position = c + (Vector3(0, H * 0.45, 0) if k == 0 else Vector3(cos(a0 + span * 0.5) * R, H * 0.6, sin(a0 + span * 0.5) * R))
		root.add_child(lt)
	root.set_meta("dark", true)

## frost over every crystal: the crystal's mesh again under a frost skin (call after the builder's _finish)
static func frost(root: Node3D, rng: Rng32) -> void:
	var bb := U.box_of(root)
	var k := 2.6 / maxf(0.2, bb.size.length())
	var ph := rng.next()
	var per := 13.0 + rng.next() * 5.0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var gm := mi.material_override as ShaderMaterial
		if mi.mesh == null or not gm or not gm.has_meta("dirt") or gm.has_meta("rock"):
			continue
		var fm := ShaderMaterial.new()
		fm.shader = FROST
		# a fern or two to a crystal: on a small crystal the ferns are as small, but never finer than on the stone
		var cs := mi.mesh.get_aabb().size.length() * U.rel_xform(mi, root).basis.get_scale().x
		fm.set_shader_parameter("k", maxf(k, 1.5 / maxf(0.02, cs)))
		fm.set_shader_parameter("lift", bb.size.length() * 0.0025 / maxf(0.01, U.rel_xform(mi, root).basis.get_scale().x))
		fm.set_shader_parameter("y0", bb.position.y)
		fm.set_shader_parameter("hgt", bb.size.y)
		fm.set_shader_parameter("phase", ph)
		fm.set_shader_parameter("period", per)
		fm.set_shader_parameter("to_root", U.rel_xform(mi, root))
		fm.render_priority = 60
		var o := MeshInstance3D.new()
		o.mesh = mi.mesh
		o.material_override = fm
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(o)
	# a cold pale light from above
	var lt := OmniLight3D.new()
	lt.light_color = Color(0.7, 0.85, 1.0)
	lt.light_energy = 0.8
	lt.omni_range = bb.size.length() * 1.5
	lt.position = bb.get_center() + Vector3(0, bb.size.y * 0.9, 0)
	root.add_child(lt)
	root.set_meta("dim", true)
