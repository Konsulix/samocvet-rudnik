class_name ForgeView
extends Node2D
## Fire Horizon on the board (its levels and Brontes' fight; docs/obstacles.md): the crucibles (Royal Match's Honey
## Pot), the molten metal over stones (Honey) and the billets fixed to the board's edge (Metal Tube), and how they move.
## Painted pieces by GPT in separate layers (art/forge_kit: gen_layers.sh, cut_layers.py -> assets/board/forge/), all
## drawn through shaders/molten.gdshader: whatever is hot glows and flows.
##   crucible: the empty pot, its molten surface churning in the hollow (bubbles rise and pop); knocked - it jolts and
##     chips, cracks; broken - its shards fly, a splash, and blobs of metal arc onto the stones round it and splat there
##   metal: an opaque skin over the stone (the stone under it is hidden, BoardView._ink_gems); it lands with a splat
##     and cracks off in curled flakes
##   billet: a bar from its base bracket at the board's edge to its glowing tip; struck, the tip melts back towards the
##     base, dripping, its new end flaring white

const PX := 128.0         # the pieces are cut at this many pixels a cell
const SPILL_FLY := 0.32   # a blob of spilt metal in the air
const SPILL_STEP := 0.05  # the blobs leave one after another
const SPLAT := 0.28       # metal landing on a stone
const MELT := 0.45        # a billet's tip melting back a cell
const FLAKE := 0.75       # flakes of a metal skin flying off
const BAR_K := 1.3        # a billet drawn this much thicker than cut (a cell long, ~0.6 of a cell high)

var bv: BoardView
var _anchor := {}          # the pot's hollow in its picture (cut_layers.py): {hollow: [cx, cy, w, h] as fractions}
var metal_at := {}         # cell key -> when its metal lands (it shows from then, with a splat)
var pot_at := {}           # cell key -> when the crucible there was knocked
var melt := {}             # billet index -> {t0}: its tip melting back a cell
var slide := {}            # billet index -> when it was laid: it slides in from its base
var drop := {}             # cell key -> when a crucible was set down there: it drops in and bounces
var fx := []               # the loose bits in the air: {k: shard|flake|drop|blob|splash, t0, dur, ...}
var _bub := []             # bubbles on the crucibles' metal: {key, t0, x, y, s}
var _live := false

func setup(view: BoardView) -> void:
	bv = view
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/molten.gdshader")
	material = m
	if _anchor.is_empty():
		var f := FileAccess.open("res://assets/board/forge/anchors.json", FileAccess.READ)
		if f: _anchor = JSON.parse_string(f.get_as_text())
	reset()

func reset() -> void:
	metal_at = {}
	pot_at = {}
	melt = {}
	slide = {}
	drop = {}
	fx = []
	_bub = []

static func tex(name: String) -> Texture2D:
	return BoardSprites.forge(name)

## a goal's or an action's sign in a box: "pot" - a crucible full of metal; "tube" - a billet on its bracket
static func icon(ci: CanvasItem, kind: String, box: Rect2) -> void:
	if kind == "pot":
		var body := tex("pot")
		var sz := Vector2(body.get_size())
		var k := minf(box.size.x / sz.x, box.size.y / sz.y)
		var r := Rect2(box.get_center() - sz * k * 0.5, sz * k)
		ci.draw_texture_rect(body, r, false)
		var hol := [0.539, 0.247, 0.861, 0.394]
		var f := FileAccess.open("res://assets/board/forge/anchors.json", FileAccess.READ)
		if f: hol = (JSON.parse_string(f.get_as_text()) as Dictionary).get("hollow", hol)
		var hs := Vector2(float(hol[2]) * r.size.x, float(hol[3]) * r.size.y)
		var hc := r.position + Vector2(float(hol[0]) * r.size.x, float(hol[1]) * r.size.y)
		ci.draw_texture_rect(tex("pot_melt"), Rect2(hc - hs * 0.5, hs), false)
	else:
		var b := tex("bar_base")
		var t := tex("bar_tip")
		var w := box.size.x * 0.5
		var hb := w * float(b.get_height()) / float(b.get_width())
		var ht := w * float(t.get_height()) / float(t.get_width())
		var cy := box.get_center().y
		ci.draw_texture_rect(t, Rect2(Vector2(box.position.x + w * 0.95, cy - ht * 0.5), Vector2(w, ht)), false)
		ci.draw_texture_rect(b, Rect2(Vector2(box.position.x, cy - hb * 0.5), Vector2(w, hb)), false)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _process(_dt: float) -> void:
	if bv == null or bv.model == null: return
	(material as ShaderMaterial).set_shader_parameter("cell_px", bv.TS)
	var m := bv.model
	var any := not fx.is_empty() or not melt.is_empty() or not slide.is_empty() or not drop.is_empty()
	if not any:
		for r in m.R:
			for c in m.C:
				if m.LOCK[r][c] == 6 or m.POT[r][c] or m.TUBE[r][c] >= 0: any = true
	if any or _live:
		_live = any
		queue_redraw()

# ---------------------------------------------------------------- what the level calls

## a crucible knocked (left: knocks it can still take; 0 - it breaks)
func knock(r: int, c: int, left: int) -> void:
	var t := _now()
	pot_at[r * bv.model.C + c] = t
	var ctr := bv.cell_center(r, c)
	var n := 2 if left > 0 else 6
	for i in n:
		var a := randf_range(-PI, 0.0) if left > 0 else TAU * i / n + randf_range(-0.3, 0.3)
		var sp := randf_range(0.9, 1.6) * bv.TS * (2.2 if left > 0 else 3.4)
		fx.append({k = "shard", t0 = t, dur = randf_range(0.6, 0.85), p = ctr + Vector2(cos(a), sin(a)) * bv.TS * 0.15,
			v = Vector2(cos(a), sin(a) - 0.6) * sp, rot = randf() * TAU, spin = randf_range(-9.0, 9.0),
			s = randf_range(0.32, 0.5) * (0.6 if left > 0 else 1.0), tex = "shard_%d" % ((i + r + c) % 6)})
	if left == 0:
		fx.append({k = "splash", t0 = t, dur = 0.45, p = ctr})
	queue_redraw()

## the broken crucible's metal flies onto the stones round it: a blob arcs to each and splats there
func spill(r: int, c: int, cells: Array) -> void:
	var t := _now()
	var from := bv.cell_center(r, c)
	for i in cells.size():
		var q: Vector2i = cells[i]
		var t0 := t + i * SPILL_STEP
		fx.append({k = "blob", t0 = t0, dur = SPILL_FLY, a = from, b = bv.cell_center(q.x, q.y)})
		metal_at[q.x * bv.model.C + q.y] = t0 + SPILL_FLY
	queue_redraw()

## metal poured onto these stones from a point (his hammer, his bolt): blobs from there, splats
func pour(cells: Array, from: Vector2, step := 0.035, fly := 0.22) -> void:
	var t := _now()
	for i in cells.size():
		var q: Vector2i = cells[i]
		var t0 := t + i * step
		fx.append({k = "blob", t0 = t0, dur = fly, a = from, b = bv.cell_center(q.x, q.y), small = true})
		metal_at[q.x * bv.model.C + q.y] = t0 + fly
	queue_redraw()

## the metal skin over a stone cracks off: curled flakes fly, a puff of heat
func crack_off(r: int, c: int) -> void:
	var t := _now()
	var ctr := bv.cell_center(r, c)
	metal_at.erase(r * bv.model.C + c)
	for i in 4:
		var a := TAU * i / 4.0 + randf_range(-0.5, 0.5) + 0.4
		fx.append({k = "flake", t0 = t, dur = FLAKE * randf_range(0.8, 1.1), p = ctr + Vector2(cos(a), sin(a)) * bv.TS * 0.18,
			v = Vector2(cos(a), sin(a) * 0.7 - 0.9) * bv.TS * randf_range(2.0, 3.2), rot = randf() * TAU,
			spin = randf_range(-8.0, 8.0), s = randf_range(0.36, 0.5), tex = "flake_%d" % ((i + r * 2 + c) % 6)})
	for i in 3:
		fx.append({k = "drop", t0 = t + 0.04 * i, dur = 0.55, p = ctr + Vector2(randf_range(-0.2, 0.2), 0.1) * bv.TS,
			v = Vector2(randf_range(-0.8, 0.8), randf_range(-2.2, -1.2)) * bv.TS, s = randf_range(0.14, 0.2), tex = "drop_%d" % (i % 4)})
	queue_redraw()

## a billet's tip melts back a cell towards its base; drops of it run off
func melt_tip(ti: int, r: int, c: int, dir: Vector2i) -> void:
	var t := _now()
	melt[ti] = {t0 = t}
	var tip := bv.cell_center(r, c) + Vector2(dir.y, dir.x) * bv.TS * 0.5
	for i in 5:
		fx.append({k = "drop", t0 = t + i * 0.06, dur = randf_range(0.55, 0.8), p = tip + Vector2(randf_range(-0.25, 0.25), randf_range(-0.15, 0.15)) * bv.TS,
			v = (Vector2(dir.y, dir.x) * randf_range(0.4, 1.4) + Vector2(randf_range(-0.5, 0.5), randf_range(-1.6, -0.4))) * bv.TS,
			s = randf_range(0.13, 0.22), tex = "drop_%d" % (i % 4)})
	queue_redraw()

## crucibles set down on these cells (Brontes): each drops in from above and bounces
func set_down(cells: Array) -> void:
	var t := _now()
	for i in cells.size():
		var q: Vector2i = cells[i]
		drop[q.x * bv.model.C + q.y] = t + i * 0.12
	queue_redraw()

## a billet laid (Brontes): it slides out from its base at the edge
func lay(ti: int) -> void:
	slide[ti] = _now()
	queue_redraw()

## is the stone here under metal that has landed (BoardView hides it)
func covers(r: int, c: int) -> bool:
	if bv.cell("LOCK", r, c) != 6: return false
	return _now() >= float(metal_at.get(r * bv.model.C + c, 0.0)) + SPLAT * 0.3

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if bv == null or bv.model == null: return
	var m := bv.model
	var now := _now()
	var TS := bv.TS
	var k := TS / PX
	# the billets first (they lie in their cells), then the crucibles, then the metal over the stones
	for ti in m.tubes.size(): _draw_tube(ti, now, k)
	for r in m.R:
		for c in m.C:
			if m.playable(r, c) and bv.cell("POT", r, c) > 0: _draw_pot(r, c, bv.cell("POT", r, c), now, k)
	for r in m.R:
		for c in m.C:
			if m.playable(r, c) and bv.cell("LOCK", r, c) == 6: _draw_metal(r, c, now, k)
	_draw_fx(now, k)

func _sprite(t: Texture2D, ctr: Vector2, k: float, rot := 0.0, sc := Vector2.ONE, col := Color.WHITE) -> void:
	if t == null: return
	var sz := Vector2(t.get_size()) * k
	draw_set_transform(ctr, rot, sc)
	draw_texture_rect(t, Rect2(-sz * 0.5, sz), false, col)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_pot(r: int, c: int, hp: int, now: float, k: float) -> void:
	var key := r * bv.model.C + c
	var ctr := bv.cell_center(r, c)
	if drop.has(key):
		# dropped in: falls from above the board, squashes on landing, bounces once
		var dq := (now - float(drop[key])) / 0.5
		if dq < 0.0: return
		if dq >= 1.0: drop.erase(key)
		else:
			var fall := clampf(dq / 0.55, 0.0, 1.0)
			var y := -(1.0 - fall * fall) * bv.TS * 3.0
			if dq > 0.55: y = -sin((dq - 0.55) / 0.45 * PI) * bv.TS * 0.18
			ctr += Vector2(0, y)
			if dq > 0.5 and dq < 0.62: pot_at[key] = now
	var since := now - float(pot_at.get(key, -10.0))
	# knocked: a jolt that rings out, the pot squashing a little
	var j := clampf(1.0 - since / 0.35, 0.0, 1.0)
	var off := Vector2(sin(since * 55.0) * bv.TS * 0.06 * j, -absf(sin(since * 18.0)) * bv.TS * 0.05 * j)
	var sq := Vector2(1.0 + 0.08 * j * sin(since * 30.0), 1.0 - 0.08 * j * sin(since * 30.0))
	# a warm glow on the board round it, breathing
	var br := 0.5 + 0.5 * sin(now * 2.2 + r * 0.9 + c * 1.7)
	GemArt.radial_disc(self, ctr + Vector2(0, -bv.TS * 0.18), bv.TS * 0.55, Color(1.0, 0.5, 0.15, 0.16 + 0.12 * br), Color(1.0, 0.45, 0.1, 0.06), Color(1.0, 0.45, 0.1, 0))
	var body := tex("pot" if hp >= 2 else "pot_cracked")
	_sprite(body, ctr + off, k, 0.0, sq)
	# the metal in its hollow, churning (the shader), a bubble rising and popping now and then
	var hol: Array = _anchor.get("hollow", [0.5, 0.22, 0.7, 0.26])
	var bsz := Vector2(body.get_size()) * k if body else Vector2(bv.TS, bv.TS)
	var hc := ctr + off + Vector2((float(hol[0]) - 0.5) * bsz.x, (float(hol[1]) - 0.5) * bsz.y) * sq
	var surf := tex("pot_melt")
	if surf:
		var want := Vector2(float(hol[2]) * bsz.x, float(hol[3]) * bsz.y)
		var ssz := Vector2(surf.get_size()) * k
		var bob := 1.0 + 0.03 * sin(now * 3.1 + key)
		_sprite(surf, hc, k, 0.0, Vector2(want.x / ssz.x, want.y / ssz.y * bob) * sq)
	# bubbles: each lives 0.7 s, swells and pops with a ring
	var seed_t := floorf(now * 1.6 + key * 0.37)
	var ph := fmod(now * 1.6 + key * 0.37, 1.0)
	var bx := (fmod(sin(seed_t * 12.9898 + key) * 43758.5453, 1.0)) * 0.6
	var bp := hc + Vector2(bx * float(hol[2]) * bsz.x * 0.6, (fmod(sin(seed_t * 7.13 + key) * 9631.7, 1.0) - 0.5) * float(hol[3]) * bsz.y * 0.4)
	if ph < 0.75:
		draw_circle(bp, bv.TS * 0.035 * (0.4 + ph), Color(1.0, 0.85, 0.4, 0.9))
	else:
		var q := (ph - 0.75) / 0.25
		draw_arc(bp, bv.TS * (0.04 + 0.06 * q), 0, TAU, 12, Color(1.0, 0.9, 0.5, 1.0 - q), maxf(1.0, bv.TS * 0.02), true)

func _draw_metal(r: int, c: int, now: float, k: float) -> void:
	var key := r * bv.model.C + c
	var at := float(metal_at.get(key, -10.0))
	if now < at: return
	var q := clampf((now - at) / SPLAT, 0.0, 1.0)
	# a splat: lands wide and flat, settles with a little wobble
	var sc := Vector2.ONE
	if q < 1.0:
		var e := 1.0 - pow(1.0 - q, 3.0)
		sc = Vector2(lerpf(0.4, 1.0, e) + 0.12 * sin(q * PI), lerpf(0.25, 1.0, e) - 0.06 * sin(q * PI))
	var t := tex("metal_%d" % ((r * 3 + c) % 2))
	if t: _sprite(t, bv.cell_center(r, c), bv.TS * 0.98 / float(t.get_width()), 0.0, sc)
	if q < 1.0:
		GemArt.radial_disc(self, bv.cell_center(r, c), bv.TS * 0.7, Color(1.0, 0.7, 0.3, 0.5 * (1.0 - q)), Color(1.0, 0.5, 0.15, 0.2 * (1.0 - q)), Color(1.0, 0.5, 0.15, 0))

## a billet: from the outer edge of its base cell along its way, base bracket, middles, the tip; while its tip melts
## back, the bar is that much longer and the melting end glows white
func _draw_tube(ti: int, now: float, k: float) -> void:
	var m := bv.model
	var T: Dictionary = m.tubes[ti]
	var base: Vector2i = T.base
	var dir: Vector2i = T.dir
	# its cells as shown (held cells count: a blow's cell stays till the blow lands)
	var n := 0
	var p := base
	while m.playable(p.x, p.y) and bv.cell("TUBE", p.x, p.y) == ti:
		n += 1
		p += dir
	var mel: Dictionary = melt.get(ti, {})
	var extra := 0.0
	var grow := 1.0
	if slide.has(ti):
		var sq := clampf((now - float(slide[ti])) / 0.5, 0.0, 1.0)
		grow = 1.0 - pow(1.0 - sq, 3.0)
		if sq >= 1.0: slide.erase(ti)
	if not mel.is_empty():
		var q := clampf((now - float(mel.t0)) / MELT, 0.0, 1.0)
		extra = 1.0 - q * q * (3.0 - 2.0 * q)
		if q >= 1.0: melt.erase(ti)
	var ln := (float(n) + extra) * grow
	if ln <= 0.01: return
	var TS := bv.TS
	var dv := Vector2(dir.y, dir.x)
	var origin := bv.cell_center(base.x, base.y) - dv * TS * 0.5
	# (pointing left: the pieces mirrored, so the light still comes from the top)
	if dir == Vector2i(0, -1): draw_set_transform(origin, 0.0, Vector2(-1.0, 1.0))
	else: draw_set_transform(origin, dv.angle(), Vector2.ONE)
	var tb := tex("bar_base")
	var tm := tex("bar_mid")
	var tt := tex("bar_tip")
	# pieces along x from 0 to ln cells; each piece is a cell long, the bar's height its own
	var piece := func(t: Texture2D, x0: float, x1: float, u0 := 0.0) -> void:
		if t == null or x1 <= x0: return
		var sz := Vector2(t.get_size())
		var h := sz.y * k * BAR_K
		var w := (x1 - x0) * TS
		var src := Rect2(u0 * sz.x, 0, (x1 - x0) * sz.x, sz.y)
		draw_texture_rect_region(t, Rect2(Vector2(x0 * TS, -h * 0.5), Vector2(w + 0.6, h)), src)
	if ln <= 1.0:
		# the base cell itself melting: the bracket stays, the stub glows
		piece.call(tb, 0.0, ln)
	else:
		piece.call(tb, 0.0, 1.0)
		var x := 1.0
		while x < ln - 1.0:
			var x1 := minf(x + 1.0, ln - 1.0)
			piece.call(tm, x, x1)
			x = x1
		piece.call(tt, ln - 1.0, ln)
	# the glowing end: hotter while it melts
	var hot := 0.5 + 0.5 * sin(now * 3.4 + ti * 1.7)
	var white := 1.0 if extra > 0.0 else 0.0
	GemArt.radial_disc(self, Vector2(ln * TS, 0), TS * (0.34 + 0.12 * white), Color(1.0, 0.75 + 0.2 * white, 0.35 + 0.4 * white, 0.3 + 0.2 * hot + 0.3 * white), Color(1.0, 0.45, 0.12, 0.1), Color(1.0, 0.45, 0.12, 0))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_fx(now: float, k: float) -> void:
	var keep := []
	var TS := bv.TS
	for e: Dictionary in fx:
		var t := now - float(e.t0)
		if t < 0.0:
			keep.append(e)
			continue
		var q := t / float(e.dur)
		if q >= 1.0: continue
		keep.append(e)
		match String(e.k):
			"shard", "flake", "drop":
				var g := TS * (9.0 if e.k != "flake" else 6.0)
				var pos: Vector2 = (e.p as Vector2) + (e.v as Vector2) * t + Vector2(0, 0.5 * g * t * t)
				var a := 1.0 - smoothstep(0.65, 1.0, q)
				var tx := tex(String(e.tex))
				var sc := float(e.s)
				if e.k == "drop":
					# a drop stretches as it falls
					var vy := float((e.v as Vector2).y) + g * t
					_sprite(tx, pos, k * sc / 0.25, 0.0, Vector2(1.0, 1.0 + clampf(vy / (TS * 8.0), 0.0, 0.8)), Color(1, 1, 1, a))
				else:
					_sprite(tx, pos, k * sc / 0.45, float(e.rot) + float(e.spin) * t, Vector2.ONE, Color(1, 1, 1, a))
			"blob":
				# an arc from the crucible to the stone, a glowing lump trailing drops
				var a2: Vector2 = e.a
				var b2: Vector2 = e.b
				var e2 := q * q * (3.0 - 2.0 * q)
				var pos2 := a2.lerp(b2, e2) + Vector2(0, -sin(q * PI) * TS * (0.35 if e.get("small", false) else 0.6))
				var tx2 := tex("drop_0")
				var s2 := 0.3 if e.get("small", false) else 0.42
				var dirv := (b2 - a2).normalized()
				_sprite(tx2, pos2, k * s2 / 0.25, dirv.angle() + PI / 2.0, Vector2(1.0, 1.25))
				GemArt.radial_disc(self, pos2, TS * 0.28, Color(1.0, 0.65, 0.25, 0.4), Color(1.0, 0.5, 0.15, 0.12), Color(1.0, 0.5, 0.15, 0))
			"splash":
				var tx3 := tex("splash")
				var e3 := 1.0 - pow(1.0 - q, 2.0)
				_sprite(tx3, e.p, k * (0.6 + 0.8 * e3), q * 0.6, Vector2.ONE, Color(1, 1, 1, 1.0 - q * q))
	fx = keep
