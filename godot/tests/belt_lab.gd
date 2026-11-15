extends Node2D
## Conveyor lab (branch `obstacles`, docs/obstacles.md §5): the Royal Match conveyor in the Copper Mountain look,
## animated on its own before it goes into the board. A 1x5 wooden chute; malachite baskets ride a slot along after
## every move; two matches beside a basket break it; the last one gone, the chute falls apart and the gems drop in.
##   "$G" --path godot --resolution 585x1266 res://tests/belt_lab.tscn -- [rec=<abs dir>]
## rec: every frame saved as f_0000.png… (run with --fixed-fps 30), quits at the end.

const CS := 50.0
const COLS := 7
const ROWS := 5
const ORG := Vector2(20, 150)
const BELT_ROW := 2
const BELT_C0 := 1
const N := 5
const GEMS := ["ruby", "sapphire", "emerald", "citrine", "amethyst"]
const SHIFT_S := 0.55
const KIT := "res://assets/board/conveyor/"
const CAP_CUT := 72.0     # px of the end cap's drum left off: the post stays inside its cell

var tex := {}
var gem_tex: Array[Texture2D] = []
var tiles: Array[Texture2D] = []
var gems := []            # [r][c]: {t, y, vy, s, pop}  (y: offset in px, pop: <0 alive, >=0 dying for that long)
var items := []           # {slot, hp, punch}
var belt_on := true
var move_t := -1.0        # time the belt began its turn, -1 still
var rollers := 0.0
var shake := 0.0
var parts := []           # flying bits
var glows := []           # additive lights
var flyers := []          # malachite on its way to the goal
var goal_left := 5
var goal_pop := 0.0
var now := 0.0
var events := []          # [time, Callable]
var rec := ""
var frame := 0
var end_t := 1e9
var break_t := -1.0
var cracks := []
var stop_t := -9.0
var fx: Node2D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("rec="): rec = a.substr(4)
	for nm in ["cap_l", "cap_r", "slot", "basket", "basket_cracked", "sealed", "chunk_0", "chunk_1", "chunk_2", "chunk_3", "chunk_4",
			"wick_0", "wick_1", "wick_2", "wick_3", "tarp_0", "tarp_1", "tarp_2", "rope"]:
		var im := Image.load_from_file(ProjectSettings.globalize_path(KIT + nm + ".png"))
		im.generate_mipmaps()
		tex[nm] = ImageTexture.create_from_image(im)
	for g: String in GEMS: gem_tex.append(load("res://assets/board/gems_kit/natural/%s.png" % g))
	for i in 3: tiles.append(load("res://assets/board/kit/slate_f/tile%d.png" % i))
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append(_gem(-1))
		gems.append(row)
	for s in N: items.append({slot = s, hp = 2 if s % 2 else 1, sealed = s % 2 == 1, punch = -1.0})
	fx = Node2D.new()
	fx.material = FxLayer.add_material()
	fx.draw.connect(_draw_fx)
	add_child(fx)
	_plan()

func _gem(t: int) -> Dictionary:
	return {t = t if t >= 0 else rng.randi_range(0, GEMS.size() - 1), y = 0.0, vy = 0.0, pop = -1.0}

# ---------------------------------------------------------------- the script of the show

func _plan() -> void:
	var t := 0.8
	for i in 7:
		var at := t
		events.append([at - 0.38, _prep])
		events.append([at, _move])
		t += 1.95
	end_t = t + 2.6

func _target() -> Dictionary:
	var tgt: Dictionary = {}
	for it: Dictionary in items:
		if int(it.hp) > 0 and (tgt.is_empty() or int(it.hp) < int(tgt.hp)): tgt = it
	return tgt

## before the move: a trio lined up, its middle stone still a row up, then swiped down into place
func _prep() -> void:
	var tgt := _target()
	if tgt.is_empty(): return
	var c0 := clampi(BELT_C0 + int(tgt.slot) - 1, 0, COLS - 3)
	var x: int = rng.randi_range(0, GEMS.size() - 1)
	gems[BELT_ROW - 1][c0].t = x
	gems[BELT_ROW - 1][c0 + 2].t = x
	gems[BELT_ROW - 2][c0 + 1].t = x
	events.append([now + 0.15, _swap.bind(c0 + 1)])

func _swap(c: int) -> void:
	var a: Dictionary = gems[BELT_ROW - 2][c]
	var b: Dictionary = gems[BELT_ROW - 1][c]
	gems[BELT_ROW - 2][c] = b
	gems[BELT_ROW - 1][c] = a
	a.sw = -CS; a.swt = now
	b.sw = CS; b.swt = now

## a move: a match of three right above the basket that is most broken, then the belt turns
func _move() -> void:
	var tgt := _target()
	if tgt.is_empty(): return
	var c: int = BELT_C0 + int(tgt.slot)
	var c0 := clampi(c - 1, 0, COLS - 3)
	for cc in range(c0, c0 + 3):
		gems[BELT_ROW - 1][cc].pop = 0.0
		_glow(_cell(BELT_ROW - 1, cc), CS * 0.7, Color(0.6, 0.9, 0.7), 0.35)
	events.append([now + 0.16, _hit.bind(tgt)])
	events.append([now + 0.32, _refill.bind(c0)])
	events.append([now + 0.9, _turn])

func _hit(it: Dictionary) -> void:
	it.hp = int(it.hp) - 1
	it.punch = now
	var p := _item_pos(it)
	if int(it.hp) >= 1:
		# the tarp torn off: its rags and the rope fly, the open basket under it
		_glow(p, CS * 0.7, Color(1.0, 0.85, 0.5), 0.25)
		for i in 3: _bit("tarp_%d" % i, p + Vector2(0, -CS * 0.12), 0.34 - i * 0.06, 1.1)
		_bit("rope", p, 0.18, 1.0)
		_dust(p, 3)
	else:
		# a crack runs through it, a blink later it bursts
		it.crack = now
		events.append([now + 0.08, _burst_now.bind(it)])

func _burst_now(it: Dictionary) -> void:
	_burst(it, _item_pos(it))
	items.erase(it)
	goal_left -= 1
	if items.is_empty(): events.append([now + 1.35, _break])

func _refill(c0: int) -> void:
	for cc in range(c0, c0 + 3):
		for r in range(BELT_ROW - 1, 0, -1):
			gems[r][cc] = gems[r - 1][cc]
			gems[r][cc].y -= CS
		gems[0][cc] = _gem(-1)
		gems[0][cc].y = -CS * (1.0 + (cc - c0) * 0.25)
		for r in BELT_ROW:
			gems[r][cc].pop = -1.0 if gems[r][cc].pop < 0.0 else gems[r][cc].pop

func _turn() -> void:
	if not belt_on: return
	move_t = now

# ---------------------------------------------------------------- per frame

func _process(dt: float) -> void:
	now += dt
	while not events.is_empty():
		events.sort_custom(func(a, b): return a[0] < b[0])
		if float(events[0][0]) > now: break
		var e: Array = events.pop_front()
		(e[1] as Callable).call()
	# the belt's turn: when it ends every basket sits a slot further on
	if move_t >= 0.0:
		var k := (now - move_t) / SHIFT_S
		rollers += dt * 9.0
		if k >= 1.0:
			move_t = -1.0
			for it: Dictionary in items: it.slot = (int(it.slot) + 1) % N
			shake = 0.1
			stop_t = now
	shake = maxf(0.0, shake - dt)
	# gems falling into place
	for r in ROWS:
		for c in COLS:
			var g: Dictionary = gems[r][c]
			if g.pop >= 0.0: g.pop += dt
			if g.y < 0.0:
				g.vy += 2600.0 * dt
				g.y = minf(0.0, g.y + g.vy * dt)
				if g.y == 0.0: g.vy = 0.0
	for b: Dictionary in parts:
		b.life += dt
		b.v.y += float(b.get("g", 1500.0)) * dt
		b.p += b.v * dt
		b.rot += b.w * dt
	parts = parts.filter(func(b): return b.life < b.max)
	for gl: Dictionary in glows: gl.life += dt
	glows = glows.filter(func(gl): return gl.life < gl.max)
	for f: Dictionary in flyers:
		f.life += dt
		if f.life >= f.max and not f.get("done", false):
			f.done = true
			goal_pop = now
			_glow(_goal_pos() + Vector2(CS * 0.1, 0), CS * 0.5, Color(0.3, 0.7, 0.4), 0.3)
	flyers = flyers.filter(func(f): return f.life < f.max)
	queue_redraw()
	fx.queue_redraw()
	if rec != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [rec, frame])
		frame += 1
	if now > end_t: get_tree().quit()

# ---------------------------------------------------------------- where things are

func _cell(r: float, c: float) -> Vector2:
	return ORG + Vector2((c + 0.5) * CS, (r + 0.5) * CS)

func _belt_x(slot: float) -> float:
	return ORG.x + (BELT_C0 + slot + 0.5) * CS

func _slot_f(it: Dictionary) -> float:
	var s := float(it.slot)
	if move_t >= 0.0: s += _ease((now - move_t) / SHIFT_S)
	return s

## anticipation, a quick pull, a little overshoot that settles
func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c2 := 1.2 * 1.525
	if x < 0.5: return pow(2.0 * x, 2.0) * ((c2 + 1.0) * 2.0 * x - c2) * 0.5
	return (pow(2.0 * x - 2.0, 2.0) * ((c2 + 1.0) * (2.0 * x - 2.0) + c2) + 2.0) * 0.5

func _item_pos(it: Dictionary) -> Vector2:
	var s := fposmod(_slot_f(it), float(N))
	return Vector2(_belt_x(s), _cell(BELT_ROW, 0).y)

func _goal_pos() -> Vector2:
	return Vector2(ORG.x + CS * 1.1, ORG.y - CS * 1.2)

# ---------------------------------------------------------------- effects

func _glow(p: Vector2, r: float, col: Color, life: float) -> void:
	glows.append({p = p, r = r, col = col, life = 0.0, max = life})

## a bit flung off: a texture, its size in cells, how hard
func _bit(nm: String, p: Vector2, size: float, force: float) -> void:
	var t: Texture2D = tex[nm]
	var a := rng.randf_range(-PI * 0.85, -PI * 0.15)
	var sp := rng.randf_range(160.0, 330.0) * force
	parts.append({tex = t, p = p + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 4)), v = Vector2.from_angle(a) * sp,
		rot = rng.randf() * TAU, w = rng.randf_range(-9.0, 9.0), life = 0.0, max = rng.randf_range(0.55, 0.85),
		s = size * CS / maxf(t.get_width(), t.get_height())})

func _dust(p: Vector2, n: int) -> void:
	for i in n:
		parts.append({dust = true, p = p + Vector2(rng.randf_range(-12, 12), rng.randf_range(0, 10)),
			v = Vector2(rng.randf_range(-60, 60), rng.randf_range(-70, -20)), g = -40.0, rot = 0.0, w = 0.0,
			life = 0.0, max = rng.randf_range(0.5, 0.8), r = rng.randf_range(8.0, 14.0)})

## the basket bursts: its picture shatters into shards that fly apart, splinters and malachite with them,
## and the malachite flies off to the goal
func _burst(it: Dictionary, p: Vector2) -> void:
	var t: Texture2D = tex.basket_cracked
	_shatter(t, Vector2(t.get_size()) * _item_scale(), p - Vector2(0, CS * 0.03), 6, Vector2(150, 280), Vector2(0, -230), 0.85)
	for i in 4: _bit("wick_%d" % i, p, 0.2, 1.3)
	for i in 3: _bit("chunk_%d" % rng.randi_range(2, 4), p, 0.18, 1.2)
	_dust(p, 8)
	_glow(p, CS * 0.9, Color(1.0, 0.85, 0.55), 0.3)
	_glow(p, CS * 0.6, Color(0.35, 0.9, 0.55), 0.5)
	shake = 0.18
	# the malachite goes off to the goal, a chunk after a chunk
	for i in 3:
		flyers.append({tex = tex["chunk_%d" % i], from = p + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 4)),
			bend = Vector2(rng.randf_range(-60, 60), rng.randf_range(-120, -60)), life = -0.08 * i - 0.12, max = 0.62 + 0.08 * i,
			w = rng.randf_range(-8, 8)})

## a picture broken into n shards (Voronoi cells of its rect), each flying off from the middle
func _shatter(t: Texture2D, sz: Vector2, p: Vector2, n: int, speed: Vector2, up: Vector2, life: float) -> void:
	var rect := Rect2(-sz * 0.5, sz)
	var seeds := []
	for i in n: seeds.append(rect.position + Vector2(rng.randf_range(0.1, 0.9), rng.randf_range(0.1, 0.9)) * rect.size)
	for i in seeds.size():
		var poly := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
		for j in seeds.size():
			if i == j: continue
			poly = _clip(poly, seeds[i], seeds[j])
			if poly.size() < 3: break
		if poly.size() < 3: continue
		var ctr := Vector2.ZERO
		for q in poly: ctr += q
		ctr /= poly.size()
		var local := PackedVector2Array()
		var uv := PackedVector2Array()
		for q in poly:
			local.append(q - ctr)
			uv.append((q - rect.position) / rect.size)
		var dir := ctr.normalized() if ctr.length() > 0.5 else Vector2.UP
		parts.append({poly = local, uv = uv, tex = t, p = p + ctr, v = dir * rng.randf_range(speed.x, speed.y) + up,
			rot = 0.0, w = rng.randf_range(-6.0, 6.0), life = 0.0, max = life * rng.randf_range(0.85, 1.1)})

## the half of a polygon nearer to a than to b
func _clip(poly: PackedVector2Array, a: Vector2, b: Vector2) -> PackedVector2Array:
	var n := b - a
	var m := (a + b) * 0.5
	var out := PackedVector2Array()
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var dp := (p - m).dot(n)
		var dq := (q - m).dot(n)
		if dp <= 0.0: out.append(p)
		if (dp <= 0.0) != (dq <= 0.0):
			out.append(p + (q - p) * (dp / (dp - dq)))
	return out

## the last basket gone: the chute shakes, falls apart into its planks, and the gems above drop into its cells
func _break() -> void:
	shake = 0.5
	break_t = now
	cracks = []
	var yc := _cell(BELT_ROW, 0).y
	for s in N:
		var x := _belt_x(s) + rng.randf_range(-0.2, 0.2) * CS
		var pts := PackedVector2Array([Vector2(x, yc - CS * 0.5)])
		var y := pts[0].y
		while y < yc + CS * 0.5:
			y += rng.randf_range(0.1, 0.18) * CS
			x += rng.randf_range(-0.12, 0.12) * CS
			pts.append(Vector2(x, minf(y, yc + CS * 0.5)))
		cracks.append(pts)
	events.append([now + 0.5, _fall_apart])

func _fall_apart() -> void:
	belt_on = false
	var y := _cell(BELT_ROW, 0).y
	for s in N:
		var p := Vector2(_belt_x(s), y)
		_shatter(tex.slot, Vector2(CS, CS), p, 3, Vector2(60, 160), Vector2(0, -170), 0.95)
		_dust(p, 3)
	for e in 2:
		var t: Texture2D = tex.cap_l if e == 0 else tex.cap_r
		var cw := CS * t.get_width() / t.get_height()
		var p := Vector2(_belt_x(-0.5) + cw * 0.5 if e == 0 else _belt_x(N - 0.5) - cw * 0.5, y)
		parts.append({tex = t, p = p, v = Vector2(-120 if e == 0 else 120, -220), rot = 0.0, w = -4.0 if e == 0 else 4.0,
			life = 0.0, max = 0.9, s = CS / t.get_height()})
	_glow(Vector2(_belt_x(N * 0.5 - 0.5), y), CS * 3.0, Color(1.0, 0.85, 0.55), 0.4)
	# the cells under it fill from above
	for c in range(BELT_C0, BELT_C0 + N):
		for r in range(BELT_ROW, 0, -1):
			gems[r][c] = gems[r - 1][c]
			gems[r][c].y -= CS
		gems[0][c] = _gem(-1)
		gems[0][c].y = -CS * 1.2
		for r in BELT_ROW + 1:
			gems[r][c].y -= CS * 0.15 * (c - BELT_C0)   # a ripple along the row

func _item_scale() -> float:
	return CS * 0.8 / float((tex.basket as Texture2D).get_width())

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(390, 844)), Color(0.07, 0.08, 0.1))
	# the board: slate cells
	for r in ROWS:
		for c in COLS:
			var t := tiles[(r * 7 + c * 3) % 3]
			draw_texture_rect(t, Rect2(ORG + Vector2(c, r) * CS, Vector2(CS, CS)), false)
	var jit := Vector2(sin(now * 95.0), cos(now * 83.0)) * shake * 10.0 if shake > 0.0 else Vector2.ZERO
	# gems (those of the belt's cells only once it is gone)
	for r in ROWS:
		for c in COLS:
			if belt_on and r == BELT_ROW and c >= BELT_C0 and c < BELT_C0 + N: continue
			var g: Dictionary = gems[r][c]
			var p := _cell(r, c) + Vector2(0, g.y)
			if g.has("sw"):
				var k := clampf((now - float(g.swt)) / 0.22, 0.0, 1.0)
				p.y += float(g.sw) * (1.0 - k * k * (3.0 - 2.0 * k))
			if p.y < ORG.y - CS * 0.3: continue
			var s := 1.0
			if g.pop >= 0.0:
				s = 1.0 - clampf(g.pop / 0.18, 0.0, 1.0)
				if s <= 0.0: continue
			_draw_gem(int(g.t), p, s)
	if belt_on: _draw_belt(jit)
	# flying bits over everything
	for b: Dictionary in parts:
		var a := clampf((b.max - b.life) / 0.25, 0.0, 1.0)
		if b.has("dust"):
			var k: float = b.life / b.max
			draw_texture_rect(FxLayer.puff(), Rect2(b.p - Vector2.ONE * b.r * (1.0 + k), Vector2.ONE * b.r * 2.0 * (1.0 + k)), false,
				Color(0.55, 0.45, 0.35, 0.45 * (1.0 - k)))
			continue
		draw_set_transform(b.p, b.rot, Vector2.ONE)
		if b.has("poly"):
			draw_polygon(b.poly, PackedColorArray([Color(1, 1, 1, a)]), b.uv, b.tex)
		else:
			var t: Texture2D = b.tex
			var sz := Vector2(t.get_size()) * float(b.s)
			draw_texture_rect(t, Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)
	for f: Dictionary in flyers:
		if f.life < 0.0: continue
		var k: float = clampf(f.life / (f.max), 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a0: Vector2 = f.from
		var a2 := _goal_pos()
		var a1: Vector2 = (a0 + a2) * 0.5 + f.bend
		var p := a0.lerp(a1, e).lerp(a1.lerp(a2, e), e)
		var t: Texture2D = f.tex
		var sc := CS * 0.34 * (1.0 - 0.45 * e) / t.get_width()
		draw_set_transform(p, f.life * f.w, Vector2.ONE)
		draw_texture_rect(t, Rect2(-Vector2(t.get_size()) * sc * 0.5, Vector2(t.get_size()) * sc), false)
		draw_set_transform(Vector2.ZERO)
	_draw_goal()

func _draw_gem(t: int, p: Vector2, s: float) -> void:
	var tx := gem_tex[t]
	var h := CS * 0.78 * s
	var w := h * tx.get_width() / tx.get_height()
	draw_texture_rect(tx, Rect2(p - Vector2(w, h) * 0.5, Vector2(w, h)), false)

func _draw_belt(jit: Vector2) -> void:
	var y := _cell(BELT_ROW, 0).y + jit.y
	var L := _belt_x(-0.5) + jit.x
	var R := _belt_x(N - 0.5) + jit.x
	var st: Texture2D = tex.slot
	# the slots, each a cell; the dark inside a little bigger than the art's own
	for s in N:
		var x := _belt_x(s) + jit.x
		draw_texture_rect(st, Rect2(Vector2(x - CS * 0.5, y - CS * 0.5), Vector2(CS, CS)), false)
	var ct: Texture2D = tex.cap_l
	var cap_w := CS * (ct.get_width() - CAP_CUT) / ct.get_height()
	# the baskets, clipped to the chute: the one leaving its far end comes in at the near one, under the end posts
	for it: Dictionary in items:
		var s := fposmod(_slot_f(it), float(N))
		var hop := 0.0
		if move_t >= 0.0: hop = sin(clampf((now - move_t) / SHIFT_S, 0.0, 1.0) * PI) * CS * 0.06
		for wrap in [0.0, -float(N), float(N)]:
			var x := _belt_x(s + wrap) + jit.x
			if x < L - CS or x > R + CS: continue
			_draw_basket(it, Vector2(x, y - hop), L + cap_w * 0.4, R - cap_w * 0.4, _tilt())
	# the end caps over the ends of the chute (what rides out goes under them)
	for e in 2:
		var t: Texture2D = tex.cap_l if e == 0 else tex.cap_r
		var x := L if e == 0 else R - cap_w
		var src := Rect2(CAP_CUT if e == 0 else 0.0, 0, t.get_width() - CAP_CUT, t.get_height())
		draw_texture_rect_region(t, Rect2(Vector2(x, y - CS * 0.5), Vector2(cap_w, CS)), src)
	# cracks running through it before it falls apart
	if break_t >= 0.0:
		var k := clampf((now - break_t) / 0.4, 0.0, 1.0)
		for pts: PackedVector2Array in cracks:
			var n := maxi(2, int(ceil(pts.size() * k)))
			var seg := pts.slice(0, n)
			for i in seg.size(): seg[i] += jit
			draw_polyline(seg, Color(0.06, 0.03, 0.02, 0.95), maxf(1.5, CS * 0.05))
			for i in seg.size(): seg[i] += Vector2(1, 0)
			draw_polyline(seg, Color(1.0, 0.85, 0.5, 0.5), 1.0)

## the baskets lean back as the belt pulls them off and forward as it stops, then rock to rest
func _tilt() -> float:
	if move_t >= 0.0:
		var k := (now - move_t) / SHIFT_S
		var acc := _ease(k + 0.04) - 2.0 * _ease(k) + _ease(k - 0.04)
		return clampf(-acc * 9.0, -0.3, 0.3)
	var since := now - stop_t
	return -0.16 * exp(-since * 6.0) * sin(since * 22.0) if since < 1.0 else 0.0

func _draw_basket(it: Dictionary, p: Vector2, x0: float, x1: float, tilt := 0.0) -> void:
	var t: Texture2D = tex.sealed if int(it.hp) >= 2 else tex.basket
	if it.has("crack"): t = tex.basket_cracked
	var sc := _item_scale()
	var sx := 1.0
	var sy := 1.0
	if float(it.punch) >= 0.0:
		var k := now - float(it.punch)
		var a := exp(-k * 7.0) * sin(k * 34.0) * 0.22
		sx += a
		sy -= a
	var sz := Vector2(t.get_size()) * sc * Vector2(sx, sy)
	# pivot at the basket's foot; clipped to [x0, x1] in its own frame (near enough for a small lean)
	var foot := p + Vector2(0, sz.y * 0.42)
	var r := Rect2(Vector2(-sz.x * 0.5, -sz.y * 0.97), sz)
	var a0 := maxf(r.position.x, x0 - foot.x)
	var a1 := minf(r.end.x, x1 - foot.x)
	if a1 <= a0: return
	var u0 := (a0 - r.position.x) / r.size.x
	var u1 := (a1 - r.position.x) / r.size.x
	var src := Rect2(u0 * t.get_width(), 0, (u1 - u0) * t.get_width(), t.get_height())
	draw_set_transform(foot, tilt, Vector2.ONE)
	draw_texture_rect_region(t, Rect2(a0, r.position.y, a1 - a0, r.size.y), src)
	draw_set_transform(Vector2.ZERO)

## the goal: a basket and how many are left
func _draw_goal() -> void:
	var p := _goal_pos()
	var box := Rect2(p - Vector2(CS * 0.75, CS * 0.7), Vector2(CS * 2.6, CS * 1.4))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.14, 0.17)
	sb.border_color = Color(0.55, 0.47, 0.33)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, box)
	var t: Texture2D = tex.basket
	var k := 1.0
	if goal_pop > 0.0:
		var d := now - goal_pop
		k += exp(-d * 8.0) * sin(d * 30.0) * 0.25
	var h := CS * 0.9 * k
	var w := h * t.get_width() / t.get_height()
	draw_texture_rect(t, Rect2(p - Vector2(w, h) * 0.5, Vector2(w, h)), false)
	var f := ThemeDB.fallback_font
	draw_string(f, p + Vector2(CS * 0.65, CS * 0.22), str(maxi(goal_left, 0)) if goal_left > 0 else "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, int(CS * 0.62 * k), Color(0.95, 0.9, 0.8))

func _draw_fx() -> void:
	for gl: Dictionary in glows:
		var k: float = gl.life / gl.max
		var r: float = gl.r * (0.6 + 0.6 * k)
		fx.draw_texture_rect(FxLayer.puff(), Rect2(gl.p - Vector2.ONE * r, Vector2.ONE * r * 2.0), false,
			Color(gl.col.r, gl.col.g, gl.col.b, (1.0 - k) * 0.9))
	for f: Dictionary in flyers:
		if f.life < 0.0: continue
		var k: float = clampf(f.life / f.max, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var a0: Vector2 = f.from
		var a2 := _goal_pos()
		var a1: Vector2 = (a0 + a2) * 0.5 + f.bend
		var p := a0.lerp(a1, e).lerp(a1.lerp(a2, e), e)
		fx.draw_texture_rect(FxLayer.puff(), Rect2(p - Vector2.ONE * 12.0, Vector2.ONE * 24.0), false, Color(0.3, 0.9, 0.5, 0.5))
