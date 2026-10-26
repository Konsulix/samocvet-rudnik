class_name SpecCallouts
extends Control
## Callouts over a live specimen, drawn like a museum label: the gene's name in small spaced letters on a hairline
## rule, a fine tick closing the rule's outer end, and a thread from its inner end to where that gene grew on the stone
## (the builder's meta "grown"), ending in a tiny ringed dot. The labels are laid out once as they open, half above
## the stone's outline and half below, at the left and right edges, the genes given the places that keep the threads
## short and uncrossed; then they stay still while the threads and dots follow the stone as it moves. A point turning away fades, and a gene grown in
## several places moves its thread to the one facing the camera. Every line is the same light ink; the picked gene's
## name turns gold.
## Appear: the dot pops with a ring, the thread draws out to the rule, the rule runs out under where the name will be,
## the tick drops, the name types itself in. Hide: the same backwards, quicker.

signal plate_tapped(id: String)

const M := 18.0         # labels' gap to the frame's edge
const PAD := 5.0        # the rule runs this far past the name on the thread's side
const INSET := 5.0      # and the name keeps this far off the tick at the rule's closed end
const ROW := 24.0       # least height between two labels in a column
const CLEAR := 12.0     # a label's gap to the stone's outline
const IN_T := 0.85      # one label's appear, s
const OUT_T := 0.32
const STAGGER := 0.08
const BEND := 7.0       # radius of the turn where a thread becomes its rule
const INK := Color(0.95, 0.92, 0.86)
const FONT_PX := 9

static var freeze := 1.0   # screenshots of the appear: every label stops at this much of it (`callouts_at=`)

var view: SpecView
var items: Array[Dictionary] = []
var open := false
var sel := ""
var _t := 0.0
var _font: FontVariation
var _hull: PackedVector3Array   # a sample of the stone's vertices, for its outline on screen
var _box := Rect2()             # that outline
var _repick := false            # as the labels open each gene points at its best spot afresh
var _occ: Array = []            # the crystals as triangles, in the specimen's space: [{box, tris}], to tell what they hide

static func attach(v: SpecView) -> SpecCallouts:
	var c := SpecCallouts.new()
	c.view = v
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(c)
	c.set_process(false)
	return c

## genes: [{id, name, pts: [[point, normal], ...]}] — points in the specimen's own space
func setup(genes: Array) -> void:
	# a museum label's letters: small, a little apart
	_font = UI.body_bold.duplicate() as FontVariation
	_font.spacing_glyph = 1
	for g: Dictionary in genes:
		var l := UI.label(g.name, FONT_PX, _font, INK)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		l.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		var id: String = g.id
		l.gui_input.connect(func(e: InputEvent) -> void:
			if open and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				accept_event()
				plate_tapped.emit(id))
		add_child(l)
		items.append({id = id, pts = g.pts, label = l, cur = 0, side = 1.0, y = 0.0, p = 0.0, delay = 0.0,
			h = 0.0, dim = 0.0, a = Vector2.ZERO, face = 1.0, ring = -1.0})

## open with `id` picked out (or none)
func show_all(id := "") -> void:
	if not view.live or items.is_empty():
		return
	open = true
	sel = id
	view.hold = true
	set_process(true)
	_t = 0.0
	_sample()
	_look()
	_repick = true
	_project()
	_layout()
	var order := items.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.a as Vector2).y < (b.a as Vector2).y)
	# the picked one first, the rest top to bottom; one caught half hidden carries on from where it is
	var k := 1 if id != "" else 0
	for it: Dictionary in order:
		it.delay = (0.0 if it.id == id else STAGGER * k) - float(it.p) * IN_T
		if it.id != id: k += 1
		it.ring = -1.0
		(it.label as Control).visible = true
		(it.label as Control).mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func select(id: String) -> void:
	sel = id
	for it in items:
		if it.id == id:
			it.ring = 0.0

func hide_all() -> void:
	if not open:
		return
	open = false
	sel = ""
	view.hold = false
	_t = 0.0
	var order := items.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.a as Vector2).y > (b.a as Vector2).y)
	for k in order.size():
		var it: Dictionary = order[k]
		it.delay = STAGGER * 0.4 * k
		(it.label as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	var busy := open
	_t += dt
	for it in items:
		var p: float = it.p
		if open:
			if _t >= float(it.delay): p = minf(freeze, p + dt / IN_T)
		elif _t >= float(it.delay):
			p = maxf(0.0, p - dt / OUT_T)
		it.p = p
		busy = busy or p > 0.0
		it.h = lerpf(it.h, 1.0 if it.id == sel else 0.0, minf(1.0, dt * 10.0))
		it.dim = lerpf(it.dim, 1.0 if sel != "" and it.id != sel else 0.0, minf(1.0, dt * 8.0))
		if float(it.ring) >= 0.0:
			it.ring = float(it.ring) + dt
			if float(it.ring) > 0.9: it.ring = -1.0
	if not busy:
		for it in items:
			(it.label as Control).visible = false
		set_process(false)
		queue_redraw()
		return
	if not view.live:
		return
	_project()
	_place()
	queue_redraw()

# ---------------------------------------------------------------- where things are

## each gene's anchor on screen and how much it faces the camera; a gene grown in several places
## points at the one facing the camera best (and keeps it until it turns away)
func _project() -> void:
	var g := view.live.get_child(0) as Node3D if view.live.get_child_count() else view.live
	var cam := view.studio.cam
	var k := size / Vector2(maxi(1, view.studio.vp.size.x), maxi(1, view.studio.vp.size.y))
	var eye := cam.global_position
	for it in items:
		var pts: Array = it.pts
		var seen: Array = it.get("seen", [])
		var best := 0
		var best_f := -2.0
		var faces := []
		for i in pts.size():
			var w: Vector3 = g.global_transform * (pts[i][0] as Vector3)
			var n: Vector3 = pts[i][1]
			var f := 1.0
			if n != Vector3.ZERO:
				f = (g.global_transform.basis * n).normalized().dot((eye - w).normalized())
			# a spot behind a crystal counts as turned away
			if i < seen.size() and not seen[i]:
				f -= 2.0
			faces.append(f)
			if f > best_f:
				best_f = f
				best = i
		var cur: int = it.cur
		if cur >= pts.size() or _repick or (float(faces[cur]) < 0.05 and best_f > 0.25):
			cur = best
		it.cur = cur
		var wc: Vector3 = g.global_transform * (pts[cur][0] as Vector3)
		it.a = cam.unproject_position(wc) * k
		it.face = smoothstep(-0.15, 0.3, float(faces[cur]))
	_repick = false
	# the stone's outline on screen
	var lo := Vector2(INF, INF)
	var hi := -lo
	for v in _hull:
		var q := cam.unproject_position(g.global_transform * v) * k
		lo = lo.min(q)
		hi = hi.max(q)
	_box = Rect2(lo, hi - lo) if _hull.size() else Rect2(size * 0.3, size * 0.4)

## a few dozen vertices of every crystal and rock (growths aside), in the specimen's own space;
## and every crystal's triangles, to tell which spots they hide
func _sample() -> void:
	if _hull.size() or not view.live:
		return
	var g := view.live.get_child(0) as Node3D if view.live.get_child_count() else view.live
	for n: Node in g.find_children("*", "MeshInstance3D", true, false):
		if not n.has_meta("geo"):
			continue
		var geo: Geo = n.get_meta("geo")
		var xf := SpecUtil.rel_xform(n as Node3D, g)
		var step := maxi(1, geo.v.size() / 60)
		for i in range(0, geo.v.size(), step):
			_hull.append(xf * geo.v[i])
		# only crystals and metal hide things (their materials carry the rock line, "dirt"): the rock hides only
		# what is on its far side, which the normals tell, and moss or lichen must not hide the spot under them
		var m := (n as MeshInstance3D).material_override
		if not m or m.has_meta("rock") or not m.get_meta("dirt", false):
			continue
		var tris := PackedVector3Array()
		for k in geo.tri_count():
			for v: Vector3 in geo.tri(k):
				tris.append(xf * v)
		_occ.append({box = xf * geo.aabb(), tris = tris})

## which of each gene's spots the camera can see past the crystals (spots inside a crystal count as seen):
## worked out as the labels open, the stone hardly turns while they are up
func _look() -> void:
	var g := view.live.get_child(0) as Node3D if view.live.get_child_count() else view.live
	var eye := g.global_transform.affine_inverse() * view.studio.cam.global_position
	for it in items:
		var seen := []
		for pn: Array in it.pts:
			var p: Vector3 = pn[0]
			seen.append((pn[1] as Vector3) == Vector3.ZERO or not _hidden(p + (eye - p).normalized() * 0.03, eye))
		it.seen = seen

func _hidden(from: Vector3, to: Vector3) -> bool:
	for o: Dictionary in _occ:
		if not (o.box as AABB).intersects_segment(from, to):
			continue
		var t: PackedVector3Array = o.tris
		for k in range(0, t.size(), 3):
			if Geometry3D.segment_intersects_triangle(from, to, t[k], t[k + 1], t[k + 2]) != null:
				return true
	return false

## the name's width and height as drawn (the rule runs under all of it)
func _text(it: Dictionary) -> Vector2:
	return (it.label as Label).get_combined_minimum_size()

## where the labels stand, settled once when they open and then left still (only the threads follow the stone):
## half above the stone's outline and half below, each band split between the left and the right edge, stacked
## outwards from the stone. Which gene takes which place is the arrangement with the shortest threads and no crossings.
func _layout() -> void:
	for it in items:
		# a long name steps its letters down a size rather than reach past the frame's middle
		var l: Label = it.label
		while _text(it).x > size.x * 0.5 - M - 10.0 and l.get_theme_font_size("font_size") > FONT_PX - 1:
			l.add_theme_font_size_override("font_size", l.get_theme_font_size("font_size") - 1)
	var th := _text(items[0]).y
	var lo := M + th + 2.0        # the highest a rule may stand
	var hi := size.y - M - 6.0    # the lowest
	var top0 := clampf(_box.position.y - CLEAR, lo, hi)
	var bot0 := clampf(_box.end.y + CLEAR + th, lo, hi)
	# how many fit in one column above and below the stone
	var cap_t := floori((top0 - lo) / ROW) + 1
	var cap_b := floori((hi - bot0) / ROW) + 1
	var n := items.size()
	var nt := clampi(ceili(n / 2.0), maxi(0, n - 2 * cap_b), mini(n, 2 * cap_t))
	var best_cost := INF
	var best_order: Array = []
	var best_slots: Array = []
	# an odd band can give its extra label to either side: try each
	for lt: int in _splits(nt):
		for lb: int in _splits(n - nt):
			var slots := _band(lt, nt - lt, top0, -1.0, lo, hi) + _band(lb, n - nt - lb, bot0, 1.0, lo, hi)
			var r := _assign(slots)
			if float(r[0]) < best_cost:
				best_cost = r[0]
				best_order = r[1]
				best_slots = slots
	for i in best_order.size():
		var it: Dictionary = best_order[i]
		it.side = best_slots[i].side
		it.y = best_slots[i].y

## how many of k labels go left: half, or either half when k is odd
func _splits(k: int) -> Array:
	return [k / 2] if k % 2 == 0 else [k / 2 + 1, k / 2]

## a band's places: `nl` on the left and `nr` on the right, the first at `y0`, the rest stepping away from the stone
## (`dir` -1 up, 1 down); a stack that runs out of the frame slides back in
func _band(nl: int, nr: int, y0: float, dir: float, lo: float, hi: float) -> Array:
	var out := []
	for side_n: Array in [[-1.0, nl], [1.0, nr]]:
		var m: int = side_n[1]
		var far := y0 + dir * (m - 1) * ROW
		var shift := (lo - far) if far < lo else (hi - far) if far > hi else 0.0
		for i in m:
			out.append({side = side_n[0], y = y0 + dir * i * ROW + shift})
	return out

## the best way to give `slots` to the genes: [cost, genes in slot order]. Every order for a few labels,
## for more a start bettered by swapping pairs
func _assign(slots: Array) -> Array:
	var n := items.size()
	var idx := range(n)
	var best := idx.duplicate()
	var best_c := _cost(idx, slots)
	if n <= 6:
		# Heap's algorithm: every order once
		var c := []
		c.resize(n)
		c.fill(0)
		var i := 0
		while i < n:
			if int(c[i]) < i:
				var j: int = 0 if i % 2 == 0 else int(c[i])
				var t: int = idx[j]
				idx[j] = idx[i]
				idx[i] = t
				var cc := _cost(idx, slots)
				if cc < best_c:
					best_c = cc
					best = idx.duplicate()
				c[i] = int(c[i]) + 1
				i = 0
			else:
				c[i] = 0
				i += 1
	else:
		var better := true
		while better:
			better = false
			for a in n:
				for b in range(a + 1, n):
					var t: int = best[a]
					best[a] = best[b]
					best[b] = t
					var cc := _cost(best, slots)
					if cc < best_c - 0.01:
						best_c = cc
						better = true
					else:
						best[b] = best[a]
						best[a] = t
	var order := []
	for k: int in best: order.append(items[k])
	return [best_c, order]

## the threads' total length, plus a heavy price for each thread crossing another or running through a name's rule
func _cost(order: Array, slots: Array) -> float:
	var segs := []
	var rules := []
	var total := 0.0
	for i in order.size():
		var it: Dictionary = items[order[i]]
		var r := _rule_at(_text(it).x, slots[i].side, slots[i].y)
		var a: Vector2 = it.a
		segs.append([a, r[0]])
		rules.append(r)
		total += a.distance_to(r[0])
	for i in segs.size():
		for j in range(i + 1, segs.size()):
			if Geometry2D.segment_intersects_segment(segs[i][0], segs[i][1], segs[j][0], segs[j][1]) != null:
				total += 600.0
		for j in rules.size():
			if j != i and Geometry2D.segment_intersects_segment(segs[i][0], segs[i][1], rules[j][0], rules[j][1]) != null:
				total += 600.0
	return total

func _place() -> void:
	for it in items:
		var l: Label = it.label
		var ts := _text(it)
		l.size = ts
		var x := M + INSET if it.side < 0.0 else size.x - M - INSET - ts.x
		l.position = Vector2(x, float(it.y) - ts.y - 1.0)
		# the name types itself in once its rule is out, and rises a hair as it comes
		var e := _seg(float(it.p), 0.55, 1.0)
		l.visible_ratio = e
		l.position.y += (1.0 - _ease(e)) * 3.0
		l.modulate.a = minf(1.0, e * 3.0) * lerpf(1.0, 0.7, it.dim)
		l.add_theme_color_override("font_color", INK.lerp(UI.GOLD, it.h))

## a label's rule: from where the thread comes in (`inner`) to the closed end (`outer`), at the rule's height
func _rule(it: Dictionary) -> Array:
	return _rule_at(_text(it).x, it.side, it.y)

func _rule_at(w: float, side: float, y: float) -> Array:
	if side < 0.0:
		return [Vector2(M + INSET + w + PAD, y), Vector2(M, y)]
	return [Vector2(size.x - M - INSET - w - PAD, y), Vector2(size.x - M, y)]

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	for it in items:
		var p: float = it.p
		if p <= 0.0:
			continue
		var a: Vector2 = it.a
		var r: Array = _rule(it)
		var inner: Vector2 = r[0]
		var outer: Vector2 = r[1]
		var alpha := lerpf(1.0, 0.6, it.dim)
		var ink := Color(INK, alpha * lerpf(0.5, 0.9, float(it.face)))
		var shade := Color(0, 0, 0, 0.3 * alpha)
		# one unbroken line: out of the dot's ring, a soft turn into the rule, along under the name; drawn out in one go
		var t1 := _ease(_seg(p, 0.08, 0.62))
		if t1 > 0.0:
			_path(_lead(a, inner, outer), t1, ink, shade)
		# a tick closes the rule
		var t3 := _back(_seg(p, 0.58, 0.72))
		if t3 > 0.0:
			_path(PackedVector2Array([outer + Vector2(0, -3.0 * t3), outer + Vector2(0, 3.0 * t3)]), 1.0, ink, shade)
		# the dot: a tiny ring round a point, popping in with a ripple; the picked one keeps a slow ripple going
		var d := _back(_seg(p, 0.0, 0.16))
		if d > 0.0:
			var pop := _seg(p, 0.0, 0.4)
			if pop < 1.0:
				draw_arc(a, 2.5 + pop * 9.0, 0.0, TAU, 32, Color(INK, (1.0 - pop) * 0.6 * alpha), 0.7, true)
			var hl: float = it.h
			if hl > 0.05:
				var b := fposmod(_t * 0.8, 1.0)
				draw_arc(a, 3.0 + b * 6.0, 0.0, TAU, 32, Color(INK, (1.0 - b) * 0.45 * hl * alpha), 0.7, true)
			var rg: float = it.ring
			if rg >= 0.0:
				var q := rg / 0.9
				draw_arc(a, 3.0 + q * 10.0, 0.0, TAU, 32, Color(INK, (1.0 - q) * 0.8 * alpha), 0.8, true)
			draw_arc(a, 2.4 * d, 0.0, TAU, 24, shade, 2.0, true)
			draw_arc(a, 2.4 * d, 0.0, TAU, 24, ink, 0.8, true)
			draw_circle(a, 0.9 * d, ink, true, -1.0, true)

## the thread and its rule as one line: from the edge of the dot's ring to the bend, round it, out to the rule's end
func _lead(a: Vector2, inner: Vector2, outer: Vector2) -> PackedVector2Array:
	var d := (inner - a).normalized()
	var u := (outer - inner).normalized()
	var r := minf(BEND, minf(a.distance_to(inner), inner.distance_to(outer)) * 0.4)
	var p1 := inner - d * r
	var p2 := inner + u * r
	var pts := PackedVector2Array([a + d * 2.6])
	for i in 9:
		var t := float(i) / 8.0
		pts.append(p1.lerp(inner, t).lerp(inner.lerp(p2, t), t))
	pts.append(outer)
	return pts

## the first `t` of a line's length, as a hairline with a faint dark halo (so it reads over a bright crystal too)
func _path(pts: PackedVector2Array, t: float, ink: Color, shade: Color) -> void:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var left := total * t
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var seg := pts[i - 1].distance_to(pts[i])
		if seg >= left:
			out.append(pts[i - 1].lerp(pts[i], left / maxf(seg, 0.001)))
			break
		out.append(pts[i])
		left -= seg
	if out.size() < 2:
		return
	draw_polyline(out, shade, 1.8, true)
	draw_polyline(out, ink, 0.7, true)

static func _seg(p: float, a: float, b: float) -> float:
	return clampf((p - a) / (b - a), 0.0, 1.0)

static func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

static func _back(t: float) -> float:
	var c := 1.9
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)
