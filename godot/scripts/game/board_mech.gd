class_name BoardMech
extends RefCounted
## How the gallery's works look on the board (BoardModel: carts, kegs, the ore bucket, belts, the dark and its
## lanterns), drawn into BoardView's layers. Pieces are GPT paintings in the board's style (art/board_mech/gen.sh,
## cut.py -> assets/board/mech/); the belt, the badges, sparks and glows are drawn here.

const DIR := "res://assets/board/mech/"
const CART_GO_S := 1.1       # a full cart rolling off the board
const LIGHT_S := 0.55        # a cell of the dark being lit
static var _tex := {}

## the game is closing: let the cached pictures go while the renderer is still up
static func release() -> void:
	_tex.clear()

static func tex(nm: String) -> Texture2D:
	if not _tex.has(nm):
		_tex[nm] = load(DIR + nm + ".png") if ResourceLoader.exists(DIR + nm + ".png") else null
	return _tex[nm]

## a piece standing on its cell's floor, `h` cells tall (narrower ones keep their shape)
static func _stand(ci: CanvasItem, t: Texture2D, bottom_mid: Vector2, h: float, max_w: float, mod := Color.WHITE, squash := 1.0) -> Rect2:
	var sz := Vector2(t.get_size())
	var k := minf(h / sz.y, max_w / sz.x)
	var s := Vector2(sz.x * k * (2.0 - squash), sz.y * k * squash)
	var r := Rect2(bottom_mid - Vector2(s.x * 0.5, s.y), s)
	ci.draw_texture_rect(t, r, false, mod)
	return r

## a number on a dark round-ended plate, as the goals show theirs
static func badge(ci: CanvasItem, at: Vector2, ts: float, text: String, col: Color, icon: Texture2D = null) -> void:
	var fs := int(round(ts * 0.44))
	var font: Font = UI.display
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var iw := ts * 0.36 if icon else 0.0
	var w := tw + iw + ts * 0.22
	var h := ts * 0.48
	var rect := Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.06, 0.88)
	sb.set_corner_radius_all(int(h * 0.5))
	sb.border_color = Color(0.85, 0.7, 0.42, 0.9)
	sb.set_border_width_all(maxi(1, int(ts * 0.03)))
	ci.draw_style_box(sb, rect)
	var x := rect.position.x + ts * 0.11
	if icon:
		ci.draw_texture_rect(icon, Rect2(Vector2(x - ts * 0.02, at.y - iw * 0.55), Vector2(iw, iw) * 1.1), false)
		x += iw
	var base := Vector2(x, at.y + fs * 0.36)
	ci.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(ts * 0.06)), Color(0, 0, 0, 0.8))
	ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

# ---------------------------------------------------------------- carts, kegs, buckets

static func draw_mech(v: BoardView, ci: CanvasItem, now: float) -> bool:
	var m := v.model
	var TS := v.TS
	var live := false
	for ci_i in m.carts.size():
		var ct: Dictionary = m.carts[ci_i]
		var go := now - float(v.cart_go_at.get(ci_i, -100.0))
		if ct.done and go > CART_GO_S: continue
		live = live or go < CART_GO_S + 0.1
		var bump := clampf(1.0 - (now - float(v.cart_bump.get(ci_i, -10.0))) / 0.25, 0.0, 1.0)
		var squash := 1.0 - 0.09 * sin(bump * PI)
		live = live or bump > 0.0
		var e := clampf(go / CART_GO_S, 0.0, 1.0) if ct.done else 0.0
		var off := Vector2(e * e * (v.C + 2) * TS, -absf(sin(e * 18.0)) * TS * 0.04)
		var bottom := Vector2(v.PAD + (float(ct.c) + 1.0) * TS, v.PAD + (float(ct.r) + 1.0) * TS + TS * 0.04) + off
		var t := tex("cart_full") if ct.done else tex("cart_wide")
		var rect := _stand(ci, t, bottom, TS * 1.3, TS * 2.15, Color.WHITE, squash)
		if ct.done: continue
		# what has gone in so far, heaped in its mouth
		var got: int = int(ct.need) - int(ct.left)
		var show := mini(7, int(ceil(got * 7.0 / maxf(1.0, float(ct.need)))))
		var gt := BoardSprites.gem(int(ct.t))
		for i in show:
			var row := 0 if i < 4 else 1
			var k := (i if row == 0 else i - 4)
			var nrow := 4 if row == 0 else 3
			var x := rect.position.x + rect.size.x * (0.22 + 0.56 * (k + 0.5) / nrow)
			var y := rect.position.y + rect.size.y * (0.3 - row * 0.12) + (0.04 * TS if k % 2 else 0.0)
			BoardSprites.draw(ci, gt, Vector2(x, y), TS * 0.5)
		if not ct.done:
			badge(ci, Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.66), TS, str(int(ct.left)), Color("#f3e6c8"), gt)
	for r in v.R:
		for c in v.C:
			if not m.playable(r, c): continue
			var k := r * v.C + c
			if m.KEG[r][c]:
				live = true
				var hit := now - float(v.keg_hit.get(k, -10.0))
				var left: int = m.KEG[r][c]
				var jit := Vector2.ZERO
				if hit < 0.25: jit.x = sin(hit * 70.0) * TS * 0.05
				if left == 1: jit += Vector2(sin(now * 41.0), cos(now * 37.0)) * TS * 0.012
				var bottom := Vector2(v.PAD + (c + 0.5) * TS, v.PAD + (r + 1.0) * TS - TS * 0.04) + jit
				var rect := _stand(ci, tex("keg"), bottom, TS * 0.98, TS)
				# the fuse: shorter, and burning harder, with each hit taken
				var tip := Vector2(rect.position.x + rect.size.x * 0.43, rect.position.y + rect.size.y * (0.03 + (3 - left) * 0.05))
				if left < BoardModel.KEG_FUSES:
					var heat := 1.0 if left == 1 else 0.55
					var pulse := 0.75 + 0.25 * sin(now * 23.0 + k)
					GemArt.radial_disc(ci, tip, TS * 0.28 * heat * pulse, Color(1.0, 0.85, 0.4, 0.85), Color(1.0, 0.45, 0.1, 0.35), Color(1.0, 0.3, 0.05, 0.0))
					for s in 6:
						var a := hash_f(k * 7 + s + int(now * 14.0)) * TAU
						var d := TS * (0.08 + 0.16 * hash_f(k * 13 + s * 3 + int(now * 14.0))) * heat
						ci.draw_line(tip, tip + Vector2.from_angle(a) * d, Color(1.0, 0.9, 0.5, 0.9), maxf(1.0, TS * 0.025))
				# fuses left, as pips on the keg's foot
				for i in BoardModel.KEG_FUSES:
					var p := Vector2(bottom.x + (i - 1) * TS * 0.17, bottom.y - TS * 0.07)
					ci.draw_circle(p, TS * 0.06, Color(0.05, 0.04, 0.03, 0.85))
					if i < left: ci.draw_circle(p, TS * 0.042, Color(1.0, 0.72, 0.28))
			if m.BUCKET[r][c]:
				var hit := now - float(v.bucket_hit.get(k, -10.0))
				var tilt := sin(clampf(hit / 0.4, 0.0, 1.0) * PI) * 0.35
				live = live or hit < 0.5
				var ctr := Vector2(v.PAD + (c + 0.5) * TS, v.PAD + (r + 0.5) * TS)
				ci.draw_set_transform(ctr, tilt, Vector2.ONE)
				_stand(ci, tex("bucket"), Vector2(0, TS * 0.46), TS * 0.98, TS * 1.05)
				ci.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
				badge(ci, ctr + Vector2(TS * 0.3, TS * 0.3), TS, str(int(m.BUCKET[r][c])), Color("#ffd86a"))
	return live

static func hash_f(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)

# ---------------------------------------------------------------- belts

## a belt under its stones: a band of dark rubber round two rollers, its cleats running the way the stones ride, a
## chevron a cell showing which way that is
static func draw_belts(v: BoardView, ci: CanvasItem) -> void:
	var m := v.model
	var TS := v.TS
	for loop: Array in m.belts:
		if loop.is_empty(): continue
		var r0 := 99
		var r1 := -1
		var c0 := 99
		var c1 := -1
		for p: Vector2i in loop:
			r0 = mini(r0, p.x); r1 = maxi(r1, p.x); c0 = mini(c0, p.y); c1 = maxi(c1, p.y)
		var top := v.PAD + r0 * TS
		var bot := v.PAD + (r1 + 1) * TS
		var x0 := v.PAD + c0 * TS
		var x1 := v.PAD + (c1 + 1) * TS
		var h := bot - top
		# the frame under it, then the band: a stadium
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0.16, 0.14, 0.13, 0.95)
		frame.set_corner_radius_all(int(h * 0.5))
		frame.border_color = Color(0.42, 0.36, 0.3, 0.9)
		frame.set_border_width_all(maxi(1, int(TS * 0.05)))
		ci.draw_style_box(frame, Rect2(x0 + TS * 0.02, top + TS * 0.04, x1 - x0 - TS * 0.04, h - TS * 0.08))
		var band := StyleBoxFlat.new()
		band.bg_color = Color(0.09, 0.085, 0.08, 1.0)
		band.set_corner_radius_all(int(h * 0.42))
		ci.draw_style_box(band, Rect2(x0 + TS * 0.1, top + TS * 0.12, x1 - x0 - TS * 0.2, h - TS * 0.24))
		var mid_y := (top + bot) * 0.5
		ci.draw_line(Vector2(x0 + h * 0.5, mid_y), Vector2(x1 - h * 0.5, mid_y), Color(0.32, 0.28, 0.24, 0.9), maxf(1.5, TS * 0.06))
		# cleats and chevrons on both runs: the top one runs right, the bottom one left
		var ph := fposmod(v.belt_phase, 1.0)
		for run in 2:
			var y0 := top + TS * 0.14 if run == 0 else mid_y + TS * 0.05
			var y1 := mid_y - TS * 0.05 if run == 0 else bot - TS * 0.14
			var dir := 1.0 if run == 0 else -1.0
			var n := int((x1 - x0) / (TS * 0.5)) + 2
			for i in n:
				var x := x0 + fposmod((i * 0.5 + ph * dir) * TS, (x1 - x0))
				if x < x0 + h * 0.36 or x > x1 - h * 0.36: continue
				ci.draw_line(Vector2(x, y0), Vector2(x, y1), Color(0.3, 0.27, 0.24, 1.0), maxf(1.5, TS * 0.06))
				ci.draw_line(Vector2(x - TS * 0.025, y0), Vector2(x - TS * 0.025, y1), Color(0.5, 0.45, 0.38, 0.5), maxf(1.0, TS * 0.02))
			for i in (c1 - c0 + 1):
				var cx := x0 + fposmod((i + 0.5 + ph * dir) * TS, (x1 - x0))
				if cx < x0 + h * 0.4 or cx > x1 - h * 0.4: continue
				var cy := (y0 + y1) * 0.5
				var s := TS * 0.11
				ci.draw_polyline(PackedVector2Array([Vector2(cx - s * dir, cy - s * 1.2), Vector2(cx + s * dir, cy), Vector2(cx - s * dir, cy + s * 1.2)]),
					Color(0.95, 0.72, 0.3, 0.55), maxf(1.5, TS * 0.05))
		# the rollers at the ends, turning with it
		for e in 2:
			var ctr := Vector2(x0 + h * 0.5 if e == 0 else x1 - h * 0.5, mid_y)
			var rad := h * 0.36
			ci.draw_circle(ctr, rad, Color(0.22, 0.2, 0.18))
			ci.draw_arc(ctr, rad, 0, TAU, 28, Color(0.55, 0.48, 0.38), maxf(1.5, TS * 0.05), true)
			var turn := v.belt_phase * TS / rad
			for s in 4:
				var a := turn + s * PI * 0.5
				ci.draw_line(ctr, ctr + Vector2.from_angle(a) * rad * 0.85, Color(0.5, 0.44, 0.36), maxf(1.5, TS * 0.045))
			ci.draw_circle(ctr, rad * 0.22, Color(0.7, 0.6, 0.42))

## over the stones: the belt's frame rails along its outer edges and between its runs, brass chevrons on them running
## with it, its drums' rims at the ends - so the belt is seen however full of stones it is
static func draw_belt_rails(v: BoardView, ci: CanvasItem) -> void:
	var m := v.model
	var TS := v.TS
	var ph := fposmod(v.belt_phase, 1.0)
	for loop: Array in m.belts:
		if loop.is_empty(): continue
		var r0 := 99
		var r1 := -1
		var c0 := 99
		var c1 := -1
		for p: Vector2i in loop:
			r0 = mini(r0, p.x); r1 = maxi(r1, p.x); c0 = mini(c0, p.y); c1 = maxi(c1, p.y)
		var top := v.PAD + r0 * TS
		var bot := v.PAD + (r1 + 1) * TS
		var x0 := v.PAD + c0 * TS + TS * 0.08
		var x1 := v.PAD + (c1 + 1) * TS - TS * 0.08
		var mid := (top + bot) * 0.5
		var w := maxf(2.0, TS * 0.07)
		for y in [top + w * 0.5, bot - w * 0.5]:
			ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.12, 0.1, 0.08, 0.9), w + 2.0)
			ci.draw_line(Vector2(x0, y), Vector2(x1, y), Color(0.62, 0.52, 0.36), w)
		# small chevrons on the rails, running: right along the top, left along the bottom, and on the middle seam
		for run in 2:
			var y: float = top + w * 0.5 if run == 0 else bot - w * 0.5
			var dir := 1.0 if run == 0 else -1.0
			for i in (c1 - c0 + 1) * 2:
				var x := x0 + fposmod((i * 0.5 + ph * dir) * TS, x1 - x0)
				var s := TS * 0.09
				ci.draw_colored_polygon(PackedVector2Array([Vector2(x - s * dir, y - s), Vector2(x + s * dir, y), Vector2(x - s * dir, y + s)]), Color(1.0, 0.78, 0.35, 0.95))
		ci.draw_line(Vector2(x0 + TS * 0.4, mid), Vector2(x1 - TS * 0.4, mid), Color(0.35, 0.3, 0.24, 0.55), maxf(1.5, TS * 0.04))
		# the drums' rims at both ends, turning
		for e in 2:
			var ctr := Vector2(x0 + TS * 0.02 if e == 0 else x1 - TS * 0.02, mid)
			var rad := (bot - top) * 0.5 - w
			var a0 := PI * 0.5 if e == 0 else -PI * 0.5
			ci.draw_arc(ctr, rad, a0, a0 + PI, 20, Color(0.12, 0.1, 0.08, 0.9), w + 2.0)
			ci.draw_arc(ctr, rad, a0, a0 + PI, 20, Color(0.62, 0.52, 0.36), w)
			var turn := v.belt_phase * TS / rad
			for s in 3:
				var a := a0 + fposmod(turn + s * PI / 3.0, PI)
				ci.draw_circle(ctr + Vector2.from_angle(a) * rad, w * 0.9, Color(1.0, 0.78, 0.35))

# ---------------------------------------------------------------- the dark

## the dark's mask for its shader: a texel a cell, a cell of margin round the board (the edge cells repeated); a cell
## being lit fades out over LIGHT_S. Returns whether anything is still fading
static func dark_mask(v: BoardView, now: float) -> bool:
	var m := v.model
	var fading := false
	var img := Image.create(v.C + 2, v.R + 2, false, Image.FORMAT_L8)
	var any := false
	for y in v.R + 2:
		for x in v.C + 2:
			var r := y - 1
			var c := x - 1
			var val := 0.0
			if m.playable(r, c):
				if m.DARK[r][c]:
					val = 1.0
				elif v.lit_at.has(r * v.C + c):
					var k := clampf((now - float(v.lit_at[r * v.C + c])) / LIGHT_S, 0.0, 1.0)
					if k < 1.0: fading = true
					val = 1.0 - k * k * (3.0 - 2.0 * k)
			if val > 0.0: any = true
			img.set_pixel(x, y, Color(val, val, val))
	v.dark_any = any
	if v._dark_mask == null or v._dark_mask.get_width() != v.C + 2 or v._dark_mask.get_height() != v.R + 2:
		v._dark_mask = ImageTexture.create_from_image(img)
	else:
		v._dark_mask.update(img)
	return fading

static func draw_dark(v: BoardView, ci: CanvasItem) -> void:
	if not v.dark_any: return
	var sm := ci.material as ShaderMaterial
	sm.set_shader_parameter("mask", v._dark_mask)
	sm.set_shader_parameter("cells", Vector2(v.C + 2, v.R + 2))
	ci.draw_texture_rect(v.white(), Rect2(Vector2(v.PAD - v.TS, v.PAD - v.TS), Vector2(v.C + 2, v.R + 2) * v.TS), false)

## the lanterns the dark's pools of light start from, standing in their own cells, their flames flickering
static func draw_lamps(v: BoardView, ci: CanvasItem, now: float) -> void:
	var TS := v.TS
	var t := tex("lantern")
	for r in v.R:
		for c in v.C:
			if not v.model.playable(r, c) or not v.model.LAMP[r][c]: continue
			var i := r * v.C + c
			var ctr := v.cell_center(r, c)
			var fl := 0.85 + 0.1 * sin(now * 9.0 + i * 2.0) + 0.05 * sin(now * 23.0 + i)
			GemArt.radial_disc(ci, ctr + Vector2(0, -TS * 0.05), TS * 1.4 * fl, Color(1.0, 0.78, 0.38, 0.35), Color(1.0, 0.6, 0.2, 0.12), Color(1.0, 0.5, 0.1, 0.0))
			if t: _stand(ci, t, ctr + Vector2(0, TS * 0.47), TS * 0.95, TS)
