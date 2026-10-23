class_name SpecFoliage
extends RefCounted
## Moss and little ferns that grow on the host rock: thousands of crossed cards with painted
## blades or fronds, cut out by alpha, lit from behind so the light glows through the leaves.

const SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	// leaves face the sky more than the card does, so tufts shade softly like a cushion
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.55));
	BACKLIGHT = t.rgb * COLOR.rgb * 0.8;
	// darker deep inside the tuft
	ALBEDO *= mix(0.35, 1.0, smoothstep(0.0, 0.7, 1.0 - UV.y));
}
"""

static var _tex := {}
static var _mesh: ArrayMesh
static var _mat := {}

## two crossed cards, base at the origin, one unit tall
static func card_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nrm := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in 3:
		var a := k * PI / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * 0.5
		var o := v.size()
		v.append_array([-d, d, d + Vector3.UP, -d + Vector3.UP])
		uv.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		var n := Vector3(-sin(a), 0, cos(a))
		nrm.append_array([n, n, n, n])
		idx.append_array([o, o + 2, o + 1, o, o + 3, o + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _mesh

static func material(kind: String) -> ShaderMaterial:
	if _mat.has(kind):
		return _mat[kind]
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	m.shader = sh
	m.set_shader_parameter("tex", texture(kind))
	_mat[kind] = m
	return m

static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var S := img.get_width()
	for y in range(maxi(0, int(c.y - r - 1)), mini(S, int(c.y + r + 2))):
		for x in range(maxi(0, int(c.x - r - 1)), mini(S, int(c.x + r + 2))):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r + 0.5:
				var a := clampf(r + 0.5 - d, 0.0, 1.0)
				var old := img.get_pixel(x, y)
				var k := a * col.a
				img.set_pixel(x, y, Color(lerpf(old.r, col.r, k), lerpf(old.g, col.g, k), lerpf(old.b, col.b, k), maxf(old.a, k)))

static func _stroke(img: Image, pts: Array, w0: float, w1: float, c0: Color, c1: Color) -> void:
	var n := pts.size()
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := maxi(1, int(a.distance_to(b) * 1.5))
		for s in steps:
			var t := (i + s / float(steps)) / float(n - 1)
			_disc(img, a.lerp(b, s / float(steps)), lerpf(w0, w1, t), c0.lerp(c1, t))

## painted leaves: "moss" is a cushion of fine blades with spore stalks, "fern" a single frond
static func texture(kind: String) -> ImageTexture:
	if _tex.has(kind):
		return _tex[kind]
	var S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.35, 0.1, 0.0))
	var rng := Rng32.new(1234 if kind == "moss" else 4321)
	if kind == "fern":
		var stem := []
		for i in 13:
			var t := i / 12.0
			stem.append(Vector2(64 + sin(t * 2.2) * 10 * t, 126 - t * 120))
		_stroke(img, stem, 2.2, 0.8, Color("#4a6a22"), Color("#8ab83a"))
		for i in range(1, 12):
			var t := i / 12.0
			var p: Vector2 = stem[i]
			var len := (1.0 - t) * 34 + 6
			for side in [-1.0, 1.0]:
				var leaf := []
				for q in 6:
					var u := q / 5.0
					leaf.append(p + Vector2(side * len * u, -len * 0.35 * u - sin(u * PI) * 3))
				_stroke(img, leaf, 3.2 * (1.0 - t * 0.5), 0.6, Color("#3f7a20"), Color("#a8d84a"))
	else:
		for k in 46:
			var bx := 64 + (rng.next() - 0.5) * 70
			var h := 50 + rng.next() * 70
			var lean := (rng.next() - 0.5) * 50
			var pts := []
			for i in 7:
				var t := i / 6.0
				pts.append(Vector2(bx + lean * t * t, 127 - h * t))
			var dark := Color("#2a4a14").lerp(Color("#4a6a1c"), rng.next())
			var light := Color("#9ad040").lerp(Color("#d8e870"), rng.next())
			_stroke(img, pts, 2.4, 0.7, dark, light)
			if rng.next() < 0.3:
				_disc(img, pts[-1], 2.2, Color("#c87a30"))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t

## a patch of tufts around `center` on a surface whose points are `pool` ([pos, normal] pairs)
static func patch(parent: Node3D, rng: Rng32, pool: Array, center: Vector3, radius: float, count: int, kind := "moss", size := 0.05) -> void:
	var near := []
	for pn in pool:
		if (pn[0] as Vector3).distance_to(center) < radius:
			near.append(pn)
	if near.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = card_mesh()
	mm.instance_count = count
	var buf := SpecUtil.mm_buf(count)
	for k in count:
		var pn: Array = near[int(rng.next() * near.size())]
		var p: Vector3 = pn[0]
		var n: Vector3 = (pn[1] as Vector3).lerp(Vector3.UP, 0.5).normalized()
		var d := p.distance_to(center) / radius
		var s := size * (0.5 + rng.next() * 0.8) * (1.15 - d * 0.6)
		var b := Basis(SpecUtil.quat_to(Vector3.UP, (n + Vector3(rng.next() - 0.5, 0, rng.next() - 0.5) * 0.5).normalized())) * Basis(Vector3.UP, rng.next() * TAU)
		b = b * Basis.from_scale(Vector3(s * (1.4 if kind == "fern" else 1.0), s * (1.0 + rng.next() * 0.6), s * (1.4 if kind == "fern" else 1.0)))
		var xf := Transform3D(b, p - n * s * 0.12)
		var c := Color(0.42 + rng.next() * 0.3, 0.55 + rng.next() * 0.3, 0.3 + rng.next() * 0.2)
		if rng.next() < 0.12: c = Color(0.9, 0.75, 0.35)
		SpecUtil.put(buf, k, xf, c)
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
