class_name GlassCrack
extends Control
## The card's "glass" struck from inside (a big swimmer of the old seas rams it: SpecReef.Swim, pass 7): a web of
## cracks runs out from the blow — jagged rays, rings between them — holds a little, and heals away in LIFE seconds.
## A soft one (an ichthyosaur's curious poke) cracks nothing: the glass only mists over where the snout touched.
## Drawn in lines over the stone's view (a child of SpecView), no shader of its own.

const LIFE := 5.0
const GROW := 0.14   # (seconds the cracks take to run out)

var at := Vector2.ZERO
var soft := false
var reach := 100.0
var _t := 0.0
## each line: its points, its width, when it starts (0..1 of GROW), whether it grows along itself (a ray) or comes whole
var _lines: Array = []
static var _blob: GradientTexture2D

static func strike(on: Control, p: Vector2, soft_k := false) -> GlassCrack:
	var g := GlassCrack.new()
	g.at = p
	g.soft = soft_k
	g.reach = on.size.x * 0.5
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.clip_contents = true
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	on.add_child(g)
	return g

static func blob() -> GradientTexture2D:
	if _blob == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		_blob = GradientTexture2D.new()
		_blob.gradient = gr
		_blob.fill = GradientTexture2D.FILL_RADIAL
		_blob.fill_from = Vector2(0.5, 0.5)
		_blob.fill_to = Vector2(1.0, 0.5)
		_blob.width = 128
		_blob.height = 128
	return _blob

func _ready() -> void:
	if soft:
		return
	var r := RandomNumberGenerator.new()
	r.randomize()
	var n := r.randi_range(10, 14)
	var step := reach * 0.07
	var rays: Array = []
	var a0 := r.randf() * TAU
	for i in n:
		var a := a0 + TAU * (i + r.randf_range(-0.3, 0.3)) / n
		var len_k := r.randf_range(0.4, 1.0)
		# (a few long ones: a web is not a circle)
		if r.randf() < 0.25: len_k *= 1.35
		var cnt := maxi(3, int(reach * len_k / step))
		var pts := PackedVector2Array([at])
		var p := at
		for k in cnt:
			a += r.randf_range(-0.16, 0.16)
			p += Vector2(cos(a), sin(a)) * step * r.randf_range(0.7, 1.3)
			pts.append(p)
		rays.append(pts)
		_lines.append([pts, r.randf_range(1.1, 1.7), 0.0, true])
		# a branch off it
		if r.randf() < 0.55 and cnt > 4:
			var from := r.randi_range(2, cnt - 2)
			var ba := a + (0.45 if r.randf() < 0.5 else -0.45) + r.randf_range(-0.15, 0.15)
			var bp: Vector2 = pts[from]
			var bpts := PackedVector2Array([bp])
			for k in r.randi_range(2, 4):
				ba += r.randf_range(-0.2, 0.2)
				bp += Vector2(cos(ba), sin(ba)) * step * r.randf_range(0.6, 1.1)
				bpts.append(bp)
			_lines.append([bpts, 1.0, float(from) / cnt, true])
	# the rings: short cracks from ray to ray, closer together near the blow
	var rings := [[2, 0.85], [4, 0.6], [7, 0.35], [10, 0.2]]
	for rg: Array in rings:
		for i in n:
			var pa: PackedVector2Array = rays[i]
			var pb: PackedVector2Array = rays[(i + 1) % n]
			var ia: int = int(rg[0]) + r.randi_range(-1, 1)
			var ib: int = int(rg[0]) + r.randi_range(-1, 1)
			if r.randf() > float(rg[1]) or ia < 1 or ib < 1 or ia >= pa.size() or ib >= pb.size():
				continue
			var m := (pa[ia] + pb[ib]) * 0.5
			# (a ring's piece sags a little towards the blow)
			m = m.lerp(at, r.randf_range(0.02, 0.1))
			_lines.append([PackedVector2Array([pa[ia], m, pb[ib]]), 1.0, minf(0.95, float(rg[0]) * step / reach), false])

func _process(dt: float) -> void:
	_t += dt
	if _t > LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if soft:
		# the glass misted where the snout touched: it spreads a little, and clears
		var k := smoothstep(0.0, 0.5, _t) * (1.0 - smoothstep(1.4, 3.6, _t))
		var rr := reach * lerpf(0.26, 0.46, smoothstep(0.0, 1.2, _t))
		draw_texture_rect(blob(), Rect2(at - Vector2(rr, rr * 0.85), Vector2(rr, rr * 0.85) * 2.0), false, Color(0.86, 0.95, 1.0, 0.8 * k))
		var r2 := rr * 0.3
		draw_texture_rect(blob(), Rect2(at - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1, 1, 1, 0.5 * k))
		return
	var g := clampf(_t / GROW, 0.0, 1.0)
	var a := 1.0 - smoothstep(2.0, LIFE, _t)
	# the blow's flash, and the crushed glass at its middle
	var fl := 1.0 - smoothstep(0.0, 0.3, _t)
	if fl > 0.0:
		var fr := reach * 0.55
		draw_texture_rect(blob(), Rect2(at - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 1, 1, 0.55 * fl))
	var cr := reach * 0.13
	draw_texture_rect(blob(), Rect2(at - Vector2(cr, cr), Vector2(cr, cr) * 2.0), false, Color(0.9, 0.96, 1.0, 0.4 * a))
	var dark := Color(0, 0, 0, 0.4 * a)
	var light := Color(0.9, 0.96, 1.0, 0.85 * a)
	for ln: Array in _lines:
		var pts: PackedVector2Array = ln[0]
		var st := float(ln[2])
		if g <= st:
			continue
		var show := pts
		if ln[3]:
			var k2 := clampf((g - st) / maxf(0.05, 1.0 - st), 0.0, 1.0)
			var cnt := clampi(int(ceil(k2 * (pts.size() - 1))) + 1, 2, pts.size())
			show = pts.slice(0, cnt)
		var w := float(ln[1])
		var sh := PackedVector2Array()
		for p in show:
			sh.append(p + Vector2(0.8, 1.0))
		draw_polyline(sh, dark, w + 0.5, true)
		# (a crack thins out to its end)
		var half := maxi(2, (show.size() + 1) / 2)
		draw_polyline(show.slice(0, half), light, w, true)
		if show.size() > half:
			draw_polyline(show.slice(half - 1), Color(light, light.a * 0.7), w * 0.6, true)
