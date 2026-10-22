class_name SpecMat
extends RefCounted
## Materials for the 3D specimens. One shader source (spec.gdshaderinc), compiled into variants on demand.
## A material is described by a Dictionary, the same knobs as the prototype's three.js materials:
##   col, a (opacity), rough, metal, emis, coat, coat_r, env (reflection strength), grain,
##   flat, transp, side ("front" | "double" | "back"), unshaded, add (additive),
##   ir, rf, st, bd (rainbow film, refraction, striations, banding), dirt {h, a, col, fr, is, fb}, prio
## Colours are linear. A see-through double-sided material draws its back faces first, then its front.

static var _shaders := {}

static func _shader(flat: bool, transp: bool, cull: String, irid: bool, dirt: bool, unshaded: bool, add: bool, glass := false) -> Shader:
	var key := "%s%s%s%s%s%s%s%s" % [int(flat), int(transp), cull, int(irid), int(dirt), int(unshaded), int(add), int(glass)]
	if _shaders.has(key):
		return _shaders[key]
	var modes := ["cull_" + cull]
	if unshaded: modes.append("unshaded")
	if add: modes.append("blend_add")
	if glass: modes.append("depth_draw_always")
	elif transp: modes.append("depth_draw_opaque")
	var code := "shader_type spatial;\nrender_mode %s;\n" % ", ".join(modes)
	if flat: code += "#define FLAT\n"
	if transp: code += "#define TRANSP\n"
	if irid: code += "#define IRID\n"
	if dirt: code += "#define DIRT\n"
	if unshaded: code += "#define UNSHADED\n"
	if glass: code += "#define GLASS\n"
	code += "#include \"res://shaders/spec.gdshaderinc\"\n"
	var sh := Shader.new()
	sh.code = code
	_shaders[key] = sh
	return sh

static func make(o: Dictionary) -> ShaderMaterial:
	var transp: bool = o.get("transp", false) or o.get("add", false)
	var side: String = o.get("side", "front")
	var irid: bool = o.get("ir", 0.0) > 0.0 or o.get("rf", 0.0) > 0.0 or o.get("st", 0.0) > 0.0 or o.get("bd", 0.0) > 0.0
	var dirt: bool = o.has("dirt") and o.dirt != null
	var flat: bool = o.get("flat", false)
	var unshaded: bool = o.get("unshaded", false)
	var add: bool = o.get("add", false)
	var prio: int = o.get("prio", 0)
	if o.get("glass", false):
		var g := _one(o, _shader(flat, true, "disabled", true, dirt, false, false, true))
		g.render_priority = prio * 2 + 1
		g.set_meta("dirt", dirt)
		g.set_shader_parameter("frost_k", o.get("frost", 0.0))
		g.set_shader_parameter("smoke_k", o.get("smoke", 0.0))
		var sc: Color = o.get("smoke_col", Color(0.2, 0.15, 0.1))
		g.set_shader_parameter("smoke_col", Vector3(sc.r, sc.g, sc.b))
		g.set_shader_parameter("thick", o.get("thick", 1.0))
		g.set_shader_parameter("g_seed", o.get("seed", 0.0))
		g.set_shader_parameter("rim_k", o.get("rim", 0.0))
		g.set_shader_parameter("holo_k", o.get("holo", 0.0))
		return g
	if transp and side == "double":
		var back := _one(o, _shader(flat, true, "front", irid, dirt, unshaded, add))
		back.render_priority = prio * 2
		var front := _one(o, _shader(flat, true, "back", irid, dirt, unshaded, add))
		front.render_priority = prio * 2 + 1
		back.next_pass = front
		back.set_meta("dirt", dirt)
		return back
	var cull := "disabled" if side == "double" else "front" if side == "back" else "back"
	var m := _one(o, _shader(flat, transp, cull, irid, dirt, unshaded, add))
	m.render_priority = prio * 2 + 1
	m.set_meta("dirt", dirt)
	return m

static func _one(o: Dictionary, sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	var c: Color = o.get("col", Color(1, 1, 1))
	m.set_shader_parameter("albedo", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("opacity", o.get("a", 1.0))
	m.set_shader_parameter("rough", o.get("rough", 0.5))
	m.set_shader_parameter("metal", o.get("metal", 0.0))
	var e: Color = o.get("emis", Color(0, 0, 0))
	m.set_shader_parameter("emis", Vector3(e.r, e.g, e.b))
	m.set_shader_parameter("coat", o.get("coat", 0.0))
	m.set_shader_parameter("coat_rough", o.get("coat_r", 0.05))
	m.set_shader_parameter("spec", clampf(0.5 * float(o.get("env", 1.0)), 0.0, 1.0))
	m.set_shader_parameter("grain", o.get("grain", 0.0))
	m.set_shader_parameter("ir_k", o.get("ir", 0.0))
	m.set_shader_parameter("rf_k", o.get("rf", 0.0))
	m.set_shader_parameter("st_k", o.get("st", 0.0))
	m.set_shader_parameter("bd_k", o.get("bd", 0.0))
	m.set_shader_parameter("d_ao", o.get("ao", 0.0))
	m.set_shader_parameter("oil_k", o.get("oil", 0.0))
	m.set_shader_parameter("rough_var", o.get("rough_var", 0.0))
	if o.has("dirt") and o.dirt != null:
		var d: Dictionary = o.dirt
		var dc: Color = d.get("col", Color(0.1, 0.1, 0.1))
		m.set_shader_parameter("d_h", d.get("h", -99.0))
		m.set_shader_parameter("d_a", d.get("a", 0.4))
		m.set_shader_parameter("d_col", Vector3(dc.r, dc.g, dc.b))
		m.set_shader_parameter("d_fr", d.get("fr", 0.0))
		m.set_shader_parameter("d_is", d.get("isl", 0.0))
		m.set_shader_parameter("d_fb", d.get("fb", 1.0))
		if d.has("scan"): set_scan(m, int(d.scan))
	return m

## photo-scanned rocks (Poly Haven, CC0): pitted sandstone, cracked boulder, dark cliff, lichen-covered stone
const SCANS := ["rock_pitted_mossy", "rock_boulder_cracked", "rock_face_03", "lichen_rock"]
static var _scan_tex := {}

static func scan_tex(i: int, kind: String) -> Texture2D:
	var key := "%d%s" % [i, kind]
	if not _scan_tex.has(key):
		var nm: String = SCANS[i]
		_scan_tex[key] = load("res://assets/textures/%s/%s_%s_1k.jpg" % [nm, nm, kind])
	return _scan_tex[key]

static func set_scan(m: ShaderMaterial, i: int) -> void:
	var p: ShaderMaterial = m
	while p:
		p.set_shader_parameter("scan_diff", scan_tex(i, "diff"))
		p.set_shader_parameter("scan_nrm", scan_tex(i, "nor_gl"))
		p.set_shader_parameter("scan_rough", scan_tex(i, "rough"))
		p.set_shader_parameter("scan_k", 1.0)
		p = p.next_pass as ShaderMaterial

## the dirt line can only be set once the specimen is built (the rock it grew from is chosen late)
static func set_dirt(m: ShaderMaterial, d: Dictionary) -> void:
	var dc: Color = d.get("col", Color(0.1, 0.1, 0.1))
	var p: ShaderMaterial = m
	while p:
		p.set_shader_parameter("d_h", d.get("h", -99.0))
		p.set_shader_parameter("d_a", d.get("a", 0.4))
		p.set_shader_parameter("d_col", Vector3(dc.r, dc.g, dc.b))
		p.set_shader_parameter("d_fr", d.get("fr", 0.0))
		p.set_shader_parameter("d_is", d.get("isl", 0.0))
		p.set_shader_parameter("d_fb", d.get("fb", 1.0))
		if d.has("scan"):
			p.set_shader_parameter("scan_diff", scan_tex(int(d.scan), "diff"))
			p.set_shader_parameter("scan_nrm", scan_tex(int(d.scan), "nor_gl"))
			p.set_shader_parameter("scan_rough", scan_tex(int(d.scan), "rough"))
			p.set_shader_parameter("scan_k", 1.0)
		p = p.next_pass as ShaderMaterial

## colour helpers that behave like three.js (HSL on raw values, sRGB <-> linear)
static func lin(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xFF).srgb_to_linear()

static func lin_s(s: String) -> Color:
	return Color(s).srgb_to_linear()

static func get_hsl(c: Color) -> Vector3:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var l := (mn + mx) / 2.0
	if mn == mx:
		return Vector3(0, 0, l)
	var d := mx - mn
	var s := d / (mx + mn) if l <= 0.5 else d / (2.0 - mx - mn)
	var h := 0.0
	if mx == c.r: h = (c.g - c.b) / d + (6.0 if c.g < c.b else 0.0)
	elif mx == c.g: h = (c.b - c.r) / d + 2.0
	else: h = (c.r - c.g) / d + 4.0
	return Vector3(h / 6.0, s, l)

static func _hue2rgb(p: float, q: float, t: float) -> float:
	if t < 0.0: t += 1.0
	if t > 1.0: t -= 1.0
	if t < 1.0 / 6.0: return p + (q - p) * 6.0 * t
	if t < 0.5: return q
	if t < 2.0 / 3.0: return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
	return p

static func hsl(h: float, s: float, l: float) -> Color:
	h = fposmod(h, 1.0)
	s = clampf(s, 0.0, 1.0)
	l = clampf(l, 0.0, 1.0)
	if s == 0.0:
		return Color(l, l, l)
	var p := l * (1.0 + s) if l <= 0.5 else l + s - l * s
	var q := 2.0 * l - p
	return Color(_hue2rgb(q, p, h + 1.0 / 3.0), _hue2rgb(q, p, h), _hue2rgb(q, p, h - 1.0 / 3.0))

static func offset_hsl(c: Color, dh: float, ds: float, dl: float) -> Color:
	var v := get_hsl(c)
	return hsl(v.x + dh, v.y + ds, v.z + dl)

static func srgb_to_lin(c: Color) -> Color:
	return c.srgb_to_linear()
