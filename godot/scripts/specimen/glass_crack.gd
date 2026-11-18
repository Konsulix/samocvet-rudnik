class_name GlassCrack
extends Control
## The card's "glass" struck from inside (a big swimmer of the old seas rams it: SpecReef.Swim, pass 7): it breaks as
## glass does — straight cracks run out from the blow to the card's frame, straight chords join them into a web of
## plates, close and crushed at the blow, wide at the frame. The plates are glass: each shows what is behind it a
## little out of place (the stone's own picture, drawn again shifted: no shader), a few catch the light, and every
## crack glints along its pieces, each in its own time.
## It heals where it lies — nothing is drawn back in: plates settle into place and the cracks dim out piece by piece,
## from the blow outwards, one side of the web before another; gone in LIFE seconds.
## A soft one (an ichthyosaur's curious poke) cracks nothing: the glass only mists over where the snout touched.

const LIFE := 5.0
const GROW := 0.2    # (seconds the cracks take to run out to the frame)
const HOLD := 1.2    # (then it heals, from the blow outwards)
const FADE := 0.9    # (a piece's own dimming)

var at := Vector2.ZERO
var soft := false
var reach := 100.0
var far := 1.0       # (the furthest corner of the card from the blow)
var tex: Texture2D   # (what is behind the glass: the stone's view)
var _t := 0.0
## each piece of a crack: its ends, width, brightness, glint's phase, when it starts to dim, its ends' distances from
## the blow, whether it catches the light
var _segs: Array = []
## the plates, in triangles: the points, and for each triangle how far it shows its picture out of place, when it
## settles, its glare, its distance from the blow
var _tri_p := PackedVector2Array()
var _tris: Array = []
static var _blob: GradientTexture2D

static func strike(on: Control, p: Vector2, soft_k := false, behind: Texture2D = null) -> GlassCrack:
	var g := GlassCrack.new()
	g.at = p
	g.soft = soft_k
	g.tex = behind
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
	for c: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		far = maxf(far, at.distance_to(c))
	# the rings' distances: close together at the blow, wider and wider out to the frame
	var radii: Array = []
	var rr := reach * 0.07
	while rr < far * 1.15 and radii.size() < 14:
		radii.append(rr)
		rr *= r.randf_range(1.4, 1.65)
	var nk := radii.size()
	# when a place starts to heal: later the further from the blow, and one side of the web before another
	var p1 := r.randf() * TAU
	var p2 := r.randf() * TAU
	var heal := func(p: Vector2) -> float:
		var th := (p - at).angle()
		var late := clampf(0.5 + 0.34 * sin(th + p1) + 0.2 * sin(2.0 * th + p2), 0.0, 1.0)
		return HOLD + late * 1.1 + clampf(p.distance_to(at) / far, 0.0, 1.0) * 1.6 + r.randf_range(-0.2, 0.2)
	var seg := func(a: Vector2, b: Vector2, w: float) -> void:
		_segs.append([a, b, w, r.randf_range(0.4, 1.0), r.randf() * TAU, float(heal.call((a + b) * 0.5)), a.distance_to(at), b.distance_to(at), r.randf() < 0.16])
	# the rays: nearly straight, a small kink now and then; most run to the frame, a few stop at a ring
	var n := r.randi_range(12, 16)
	var a0 := r.randf() * TAU
	var knots: Array = []
	for i in n:
		var a := a0 + TAU * (i + r.randf_range(-0.28, 0.28)) / n
		var last := nk if r.randf() < 0.75 else r.randi_range(3, maxi(3, nk - 2))
		var ks := PackedVector2Array()
		var prev := at
		for k in last:
			a += r.randf_range(-0.04, 0.04) + (r.randf_range(-0.16, 0.16) if r.randf() < 0.12 else 0.0)
			var p := at + Vector2(cos(a), sin(a)) * float(radii[k]) * r.randf_range(0.88, 1.12)
			seg.call(prev, p, 1.5 if k < 2 else 1.15 if k < 5 else 0.9)
			# a hairline splits off, at a sharp angle
			if k >= 2 and r.randf() < 0.3:
				var ba := a + r.randf_range(0.3, 0.65) * (1.0 if r.randf() < 0.5 else -1.0)
				var bp := p
				for b in r.randi_range(1, 2):
					var bq := bp + Vector2(cos(ba), sin(ba)) * float(radii[k]) * r.randf_range(0.2, 0.4)
					seg.call(bp, bq, 0.7)
					bp = bq
					ba += r.randf_range(-0.2, 0.2)
			ks.append(p)
			prev = p
		knots.append(ks)
	# the chords from ray to ray (nearly all of them at the blow, few at the frame), and the plates between
	for i in n:
		var ka: PackedVector2Array = knots[i]
		var kb: PackedVector2Array = knots[(i + 1) % n]
		var both := mini(ka.size(), kb.size())
		for k in both:
			if r.randf() < maxf(0.13, 0.97 - 0.14 * k):
				seg.call(ka[k], kb[k], 1.0 if k < 3 else 0.8)
		_plate(r, heal, [at, ka[0], kb[0]], 0)
		for k in mini(both - 1, 6):
			_plate(r, heal, [ka[k], ka[k + 1], kb[k + 1], kb[k]], k + 1)

## a plate of the broken glass (three or four corners, ring k): shifted a little, the more the nearer the blow
func _plate(r: RandomNumberGenerator, heal: Callable, c: Array, k: int) -> void:
	var mid := Vector2.ZERO
	for p: Vector2 in c:
		mid += p / c.size()
	var off := Vector2.from_angle(r.randf() * TAU) * lerpf(6.0, 1.5, clampf(k / 6.0, 0.0, 1.0)) * r.randf_range(0.5, 1.0)
	var it := [off, float(heal.call(mid)), r.randf_range(0.05, 0.14) if r.randf() < 0.3 else 0.0, mid.distance_to(at)]
	for t in c.size() - 2:
		_tri_p.append_array(PackedVector2Array([c[0], c[t + 1], c[t + 2]]))
		_tris.append(it)

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
	# (the cracks run out from the blow: what is nearer than `front` is there)
	var front := far * 1.1 * clampf(_t / GROW, 0.0, 1.0)
	# the plates: the stone's picture again, each a little out of place; some catch the light
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var gp := PackedVector2Array()
	var gc := PackedColorArray()
	for i in _tris.size():
		var it: Array = _tris[i]
		if float(it[3]) > front:
			continue
		var h := 1.0 - smoothstep(float(it[1]), float(it[1]) + FADE, _t)
		if h <= 0.0:
			continue
		var off: Vector2 = it[0]
		for j in 3:
			var p := _tri_p[i * 3 + j]
			pts.append(p)
			cols.append(Color(1, 1, 1, h))
			uvs.append((p + off * h) / size)
			if float(it[2]) > 0.0:
				gp.append(p)
				gc.append(Color(0.85, 0.93, 1.0, float(it[2]) * h))
	if tex and pts.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(range(pts.size())), pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
	if gp.size() >= 3:
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(range(gp.size())), gp, gc)
	# the blow's flash, and the crushed glass at its middle
	var fl := 1.0 - smoothstep(0.0, 0.3, _t)
	if fl > 0.0:
		var fr := reach * 0.6
		draw_texture_rect(blob(), Rect2(at - Vector2(fr, fr), Vector2(fr, fr) * 2.0), false, Color(1, 1, 1, 0.55 * fl))
	var cr := minf(reach * 0.12, front)
	draw_texture_rect(blob(), Rect2(at - Vector2(cr, cr), Vector2(cr, cr) * 2.0), false, Color(0.9, 0.96, 1.0, 0.35 * (1.0 - smoothstep(HOLD, HOLD + FADE, _t))))
	# the cracks, piece by piece: each its own brightness, glinting, dimming out in its own time
	for sg: Array in _segs:
		var d0 := float(sg[6])
		if d0 > front:
			continue
		var h := 1.0 - smoothstep(float(sg[5]), float(sg[5]) + FADE, _t)
		if h <= 0.0:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var d1 := float(sg[7])
		if d1 > front: b = a.lerp(b, clampf((front - d0) / maxf(0.01, d1 - d0), 0.0, 1.0))
		var w := float(sg[2])
		var al := float(sg[3]) * h * (0.78 + 0.22 * sin(_t * 2.6 + float(sg[4])))
		draw_line(a + Vector2(0.7, 0.9), b + Vector2(0.7, 0.9), Color(0, 0, 0, 0.45 * al), w + 0.4, true)
		if sg[8]:
			# (this piece catches the light: a soft bright edge to it, flickering)
			draw_line(a, b, Color(0.8, 0.92, 1.0, 0.3 * h * (0.5 + 0.5 * sin(_t * 3.4 + float(sg[4]) * 2.0))), w + 2.2, true)
		draw_line(a, b, Color(0.92, 0.97, 1.0, al), w, true)
