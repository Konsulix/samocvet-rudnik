class_name GlassCrack
extends Control
## The card's "glass" struck from inside (a big swimmer of the old seas rams it: SpecReef.Swim, pass 7): a web of
## cracks runs out from the blow to the card's frame — jagged rays, rings between them — holds a little, and heals
## from the frame back in to the blow, gone in LIFE seconds.
## A soft one (an ichthyosaur's curious poke) cracks nothing: the glass only mists over where the snout touched.
## Drawn in lines over the stone's view (a child of SpecView), no shader of its own.

const LIFE := 5.0
const GROW := 0.2    # (seconds the cracks take to run out to the frame)
const HOLD := 1.6    # (then they heal, from the frame back to the blow, till LIFE)

var at := Vector2.ZERO
var soft := false
var reach := 100.0
var far := 1.0       # (the furthest corner of the card from the blow)
var _t := 0.0
## each line: its points (outwards from the blow), its width
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
	var n := r.randi_range(11, 15)
	var step := reach * 0.075
	var box := Rect2(Vector2.ZERO, size).grow(step)
	for c in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		far = maxf(far, at.distance_to(c))
	var rays: Array = []
	var a0 := r.randf() * TAU
	for i in n:
		var a := a0 + TAU * (i + r.randf_range(-0.3, 0.3)) / n
		# most run all the way out to the card's frame; a few die on the way
		var max_len := INF if r.randf() < 0.78 else reach * r.randf_range(0.5, 1.1)
		var pts := PackedVector2Array([at])
		var p := at
		while pts.size() < 90 and box.has_point(p) and p.distance_to(at) < max_len:
			a += r.randf_range(-0.13, 0.13)
			# (it keeps on outwards: no curling back)
			a = lerp_angle(a, (p - at).angle() if pts.size() > 1 else a, 0.25)
			p += Vector2(cos(a), sin(a)) * step * r.randf_range(0.7, 1.3)
			pts.append(p)
		rays.append(pts)
		_lines.append([pts, r.randf_range(1.1, 1.8)])
		var cnt := pts.size() - 1
		# branches off it
		for bk in 2:
			if r.randf() < 0.6 and cnt > 5:
				var from := r.randi_range(2, cnt - 2)
				var ba := (pts[from + 1] - pts[from]).angle() + (0.5 if r.randf() < 0.5 else -0.5) + r.randf_range(-0.15, 0.15)
				var bp: Vector2 = pts[from]
				var bpts := PackedVector2Array([bp])
				for k in r.randi_range(2, 6):
					ba += r.randf_range(-0.2, 0.2)
					bp += Vector2(cos(ba), sin(ba)) * step * r.randf_range(0.6, 1.1)
					bpts.append(bp)
				_lines.append([bpts, 1.0])
	# the rings: short cracks from ray to ray, closer together near the blow
	var rings := [[2, 0.85], [4, 0.65], [7, 0.4], [11, 0.25], [16, 0.14]]
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
			_lines.append([PackedVector2Array([pa[ia], m, pb[ib]]), 1.0])

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
	# the cracks run out from the blow to the frame, hold, and heal from the frame back in to the blow: all that is
	# nearer the blow than `front` shows
	var front := far * 1.05 * minf(clampf(_t / GROW, 0.0, 1.0), 1.0 - smoothstep(HOLD, LIFE, _t))
	var a := 1.0 - smoothstep(LIFE - 0.6, LIFE, _t)
	# the blow's flash, and the crushed glass at its middle
	var fl := 1.0 - smoothstep(0.0, 0.3, _t)
	if fl > 0.0:
		var fr := reach * 0.6
		draw_texture_rect(blob(), Rect2(at - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 1, 1, 0.55 * fl))
	var cr := minf(reach * 0.14, front)
	draw_texture_rect(blob(), Rect2(at - Vector2(cr, cr), Vector2(cr, cr) * 2.0), false, Color(0.9, 0.96, 1.0, 0.4 * a))
	var dark := Color(0, 0, 0, 0.4 * a)
	var light := Color(0.9, 0.96, 1.0, 0.85 * a)
	for ln: Array in _lines:
		var pts: PackedVector2Array = ln[0]
		var show := PackedVector2Array()
		for k in pts.size():
			var d := pts[k].distance_to(at)
			if d > front:
				# (cut at the front itself, not at the last whole piece: it creeps, it does not hop)
				if k > 0:
					var d0 := pts[k - 1].distance_to(at)
					show.append(pts[k - 1].lerp(pts[k], clampf((front - d0) / maxf(0.01, d - d0), 0.0, 1.0)))
				break
			show.append(pts[k])
		if show.size() < 2:
			continue
		var w := float(ln[1])
		var sh := PackedVector2Array()
		for p in show:
			sh.append(p + Vector2(0.8, 1.0))
		draw_polyline(sh, dark, w + 0.5, true)
		# (a crack thins out to its end)
		var half := maxi(2, (show.size() + 1) / 2)
		draw_polyline(show.slice(0, half), light, w, true)
		if show.size() > half:
			draw_polyline(show.slice(half - 1), Color(light, light.a * 0.75), w * 0.65, true)
