class_name BossShubin
extends RefCounted
## Shubin's fight on screen (mine 8, docs/mine8-shubin.md §7): the BALANCE SCALE standing on the frame's top bar in place
## of a health bar, and the CANARY in its cage on the board. Both drawn here from GPT's separate parts
## (art/boss/export_shubin.py -> assets/boss/shubin/scale/, canary/), moved by code:
##   the scale - the beam turns as a damped pendulum towards the heavier pan (the song left, the gas right), the needle on
##   it sweeps the dial behind (song / gas, the two notches of his moods), the pans hang plumb on their chains, their
##   heaps grow and shrink with the notes and the gas; a note flies from the cage to the song's pan each time the bird
##   sings, a puff of gas to the other pan when gas comes out; a jolt when the gas jumps;
##   the canary - back half of the cage, the perch, the bird, the front bars over it: it sings (small notes rising), falls
##   silent and fluffs up while gas is in its ring, sings the lullaby when he sleeps, falls on its back when he wakes.

const DIR := "res://assets/boss/shubin/"
const INK := Color(0.05, 0.04, 0.04)

class Scale extends Node2D:
	var lv: Level
	var tex := {}
	var ang := 0.0              # the beam's turn now (radians, + : the gas side down) and its speed
	var vel := 0.0
	var _flights := []          # [from (screen), to (pan: 0 song, 1 gas), t0, kind]
	var _t := 0.0
	var px := 3.0
	func _init(level: Level) -> void:
		lv = level
		for n in ["post", "beam", "pan", "chain", "needle", "song_1", "song_2", "song_3", "song_4", "gas_1", "gas_2", "gas_3", "gas_4"]:
			tex[n] = load(DIR + "scale/%s.png" % n)
	const K := 0.86             # the parts' size on screen (exported for 390-pt width)
	func _size(n: String) -> Vector2:
		return (tex[n] as Texture2D).get_size() / px * K
	## where the post stands: its foot on the frame's top bar, in the middle of the board
	func foot() -> Vector2:
		var h := LevelBoss.hud(lv)
		# right of his head (it is in the stage's left half), on the frame's top bar
		return Vector2(lv.get_viewport_rect().size.x - 124.0, h.hp_rect.get_center().y + 6.0)
	func pivot() -> Vector2:
		var ps := _size("post")
		return foot() + Vector2(0, -ps.y * 0.705)
	func target() -> float:
		var m := lv.model
		var t := m.scale_tilt()
		var B: Dictionary = m.boss.B.scale
		var k := -t / float(B.win) if t > 0.0 else -t / -float(B.lose)
		return clampf(k, -1.0, 1.0) * deg_to_rad(22.0)
	func pan_at(side: int) -> Vector2:
		var arm := _size("beam").x * 0.5 - 5.0
		return pivot() + Vector2(side * arm * cos(ang), side * arm * sin(ang)) + Vector2(0, 24)
	func note_to(from: Vector2) -> void:
		_flights.append([from, 0, _t, "note"])
	func puff_to(from: Vector2) -> void:
		_flights.append([from, 1, _t, "puff"])
	func jolt(k := 1.0) -> void:
		vel += 0.9 * k
	func _process(dt: float) -> void:
		_t += dt
		var want := target()
		vel += ((want - ang) * 14.0 - vel * 3.2) * dt
		ang += vel * dt
		queue_redraw()
	func _heap(kind: String) -> int:
		var m := lv.model
		if kind == "song":
			var n := int(m.boss.song.notes)
			return 1 if n <= 6 else 2 if n <= 13 else 3 if n <= 20 else 4
		var g := m.gas_count()
		return 0 if g == 0 else 1 if g <= 2 else 2 if g <= 4 else 3 if g <= 7 else 4
	func _draw() -> void:
		if lv.model == null or not lv.model.scale_on(): return
		var ps := _size("post")
		var f := foot()
		draw_texture_rect(tex.post, Rect2(f - Vector2(ps.x * 0.5, ps.y), ps), false)
		var pv := pivot()
		# the needle stands up from the pivot over the dial, fixed to the beam
		var ns := _size("needle")
		draw_set_transform(pv, ang, Vector2.ONE)
		draw_texture_rect(tex.needle, Rect2(Vector2(-ns.x * 0.5, -ns.y + ns.x * 0.5), ns), false)
		var bs := _size("beam")
		draw_texture_rect(tex.beam, Rect2(-bs * 0.5, bs), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var arm := bs.x * 0.5 - 6.0
		for side in [-1, 1]:
			var end := pv + Vector2(side * arm * cos(ang), side * arm * sin(ang))
			var pn := _size("pan")
			var rim := end + Vector2(sin(_t * 1.3 + side) * 0.6, 22.0)
			var cs := _size("chain")
			draw_texture_rect(tex.chain, Rect2(Vector2(end.x - cs.x * 0.5, end.y + 2), Vector2(cs.x, rim.y - end.y)), false)
			draw_texture_rect(tex.pan, Rect2(Vector2(rim.x - pn.x * 0.5, rim.y), pn), false)
			var hk := "song" if side < 0 else "gas"
			var i := _heap(hk)
			if i > 0:
				var hs := _size("%s_%d" % [hk, i]) * 0.62
				var bob := sin(_t * 3.0) * 1.0 if hk == "gas" else 0.0
				draw_texture_rect(tex["%s_%d" % [hk, i]], Rect2(Vector2(rim.x - hs.x * 0.5, rim.y + pn.y * 0.62 - hs.y + bob), hs), false)
		# notes and puffs flying into the pans
		for fl in _flights.duplicate():
			var u := (_t - float(fl[2])) / 0.75
			if u >= 1.0:
				_flights.erase(fl)
				if int(fl[1]) == 0: vel -= 0.25
				else: vel += 0.25
				continue
			var from: Vector2 = get_global_transform_with_canvas().affine_inverse() * (fl[0] as Vector2)
			var to := pan_at(-1 if int(fl[1]) == 0 else 1)
			var e := u * u * (3.0 - 2.0 * u)
			var p := from.lerp(to, e) + Vector2(0, -60.0 * sin(PI * u))
			if String(fl[3]) == "note":
				_note(p, 1.0 - 0.3 * u, Color(1.0, 0.85, 0.3, 1.0))
			else:
				draw_circle(p, 9.0 * (1.0 - 0.4 * u), Color(0.62, 0.74, 0.6, 0.55))
				draw_circle(p + Vector2(5, -3), 6.0 * (1.0 - 0.4 * u), Color(0.7, 0.82, 0.68, 0.45))
	func _note(p: Vector2, s: float, col: Color) -> void:
		draw_circle(p, 4.0 * s, INK)
		draw_circle(p, 3.0 * s, col)
		draw_line(p + Vector2(2.6, 0) * s, p + Vector2(2.6, -11) * s, INK, 2.6 * s)
		draw_line(p + Vector2(2.6, -11) * s, p + Vector2(7, -8) * s, INK, 2.6 * s)
		draw_line(p + Vector2(2.6, 0) * s, p + Vector2(2.6, -11) * s, col, 1.2 * s)

class Cage extends Node2D:
	var lv: Level
	var J: Dictionary
	var tex := {}
	var state := "sing"         # sing | quiet | fall | win
	var since := 0.0
	var _t := 0.0
	var _notes := []            # small notes rising from the cage: [x, t0]
	var _next_note := 0.0
	var _next_song := 0.8        # the bird's own phrases while it sings (not only on a move)
	var px := 3.0
	func _init(level: Level) -> void:
		lv = level
		J = JSON.parse_string(FileAccess.get_file_as_string(DIR + "canary/canary.json"))
		px = float(J.px)
		for n in ["cage_back", "perch", "cage_front"]:
			tex[n] = load(DIR + "canary/%s.png" % n)
		for st in ["sing", "quiet", "win", "fall"]:
			var a := []
			for i in int(J.bird[st]): a.append(load(DIR + "canary/%s/%02d.png" % [st, i]))
			tex[st] = a
	func set_state(s: String) -> void:
		if s == state: return
		state = s
		since = _t
	func top_left() -> Vector2:
		var m := lv.model
		var b := lv.board
		var k := b.TS / 37.0
		var cs := Vector2(J.cage[0], J.cage[1]) * k
		# standing on its 2x2: the bottom of the cage on the bottom of the cells, in their middle
		var bottom := b.cell_center(int(m.cage.r) + 1, int(m.cage.c) + 0.5) + Vector2(0, b.TS * 0.5 - 2.0)
		return bottom - Vector2(cs.x * 0.5, cs.y)
	func scale_k() -> float:
		return lv.board.TS / 37.0 / px
	func mouth() -> Vector2:
		var k := lv.board.TS / 37.0
		return get_global_transform_with_canvas() * (top_left() + Vector2(float(J.cage[0]) * 0.55, float(J.perch) - 12.0) * k)
	func _process(dt: float) -> void:
		_t += dt
		if state == "sing" and _t > _next_note:
			_next_note = _t + randf_range(0.5, 1.1)
			_notes.append([randf_range(-6.0, 10.0), _t])
		if state == "sing" and _t > _next_song:
			_next_song = _t + randf_range(2.0, 4.5)
			Sfx.play("sh_song")
		queue_redraw()
	func _frame() -> Array:
		## [texture, offset of its bottom-centre from the perch's line (pt), lying]
		var s := _t - since
		match state:
			"sing":
				return [tex.sing[int(_t * 8.0) % tex.sing.size()], 0.0]
			"quiet":
				return [tex.quiet[int(_t * 5.0) % tex.quiet.size()], 0.0]
			"win":
				return [tex.win[mini(int(s * 5.0), tex.win.size() - 1)], 0.0]
			"fall":
				# 0-3 on the perch (a last wing beat), 4-9 down to the floor on its back, 10-11 lying there
				var fr: Array = tex.fall
				var t0 := 4 / 6.0
				if s < t0: return [fr[int(s * 6.0)], 0.0]
				var q := (s - t0) / 0.55
				if q < 1.0: return [fr[4 + mini(5, int(q * 6.0))], (float(J.floor) - float(J.perch)) * q * q]
				return [fr[10 + (1 if fmod(s, 2.4) < 0.3 else 0)], float(J.floor) - float(J.perch)]
		return [tex.sing[0], 0.0]
	func _draw() -> void:
		if lv.model == null or lv.model.cage.is_empty(): return
		var k := lv.board.TS / 37.0
		var tl := top_left()
		var cs := Vector2(J.cage[0], J.cage[1]) * k
		draw_texture_rect(tex.cage_back, Rect2(tl, cs), false)
		draw_texture_rect(tex.perch, Rect2(tl, cs), false)
		var f := _frame()
		var t: Texture2D = f[0]
		var bs := t.get_size() / px * k
		var foot := tl + Vector2(cs.x * 0.5, (float(J.perch) + float(f[1])) * k + bs.y * 0.18)
		if state == "fall" and float(f[1]) >= float(J.floor) - float(J.perch) - 0.5:
			foot.y = tl.y + float(J.floor) * k + 4.0 * k
		var sway := sin(_t * 1.6) * 0.03 if state == "quiet" else 0.0
		draw_set_transform(foot, sway, Vector2.ONE)
		draw_texture_rect(t, Rect2(Vector2(-bs.x * 0.5, -bs.y), bs), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(tex.cage_front, Rect2(tl, cs), false)
		for nt in _notes.duplicate():
			var u := (_t - float(nt[1])) / 1.4
			if u >= 1.0:
				_notes.erase(nt)
				continue
			var p := tl + Vector2(cs.x * 0.62 + float(nt[0]) + sin(u * 6.0) * 4.0, float(J.perch) * k - 10.0 - 34.0 * u)
			var a := sin(PI * u)
			draw_circle(p, 2.6, Color(INK, a))
			draw_circle(p, 1.9, Color(1.0, 0.86, 0.3, a))
			draw_line(p + Vector2(1.8, 0), p + Vector2(1.8, -7), Color(INK, a), 1.6)

static func scale_of(lv: Level) -> Scale: return LevelBoss.hud(lv).get_node_or_null("ShubinScale") as Scale
static func cage_of(lv: Level) -> Cage: return lv.board.get_node_or_null("ShubinCage") as Cage

## put the scale and the cage on screen (LevelBoss.mount)
## the flames of the lamps and the candle on his frame (kit/stage0.json "lamps": [x, y, strength] in the frame picture's
## pt): they flicker; as the gas rises (his mood) they go pale and then burn blue, like a miner's lamp in firedamp
class Lamps extends Node2D:
	var lv: Level
	var fr: BossFrame
	var _t := 0.0
	var _col := Color(1.0, 0.72, 0.32)
	func _init(level: Level, frame: BossFrame) -> void:
		lv = level
		fr = frame
		material = FxLayer.add_material()
	func _process(dt: float) -> void:
		_t += dt
		var md := lv.model.shubin_mood() if lv.model and lv.model.boss_on() else 0
		var want: Color = [Color(1.0, 0.72, 0.32), Color(0.95, 0.88, 0.55), Color(0.42, 0.72, 1.0)][md]
		_col = _col.lerp(want, minf(1.0, dt * 1.5))
		queue_redraw()
	func _draw() -> void:
		if fr.whole == null or not fr.whole_meta.has("lamps"): return
		var kw := fr.ts / float(fr.whole_meta.cell_pt)
		var o := (fr.origin - Vector2(fr.whole_meta.cells_top_left[0], fr.whole_meta.cells_top_left[1]) * kw).round()
		var puff := FxLayer.puff()
		var i := 0
		for L: Array in fr.whole_meta.lamps:
			var p := o + Vector2(float(L[0]), float(L[1])) * kw
			var k := float(L[2])
			# a flicker: two slow waves and a quick shiver, each flame its own
			var f := 0.78 + 0.12 * sin(_t * 7.3 + i * 2.1) + 0.07 * sin(_t * 17.0 + i) + 0.05 * sin(_t * 31.0 + i * 5.0)
			var r := 15.0 * kw * k * (0.9 + 0.2 * f)
			draw_texture_rect(puff, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(_col, 0.32 * f * k))
			var r2 := r * 0.35
			draw_texture_rect(puff, Rect2(p - Vector2(r2, r2 * 1.3), Vector2(r2 * 2.0, r2 * 2.6)), false, Color(_col.lightened(0.4), 0.7 * f))
			i += 1

static func mount(lv: Level) -> void:
	var h := LevelBoss.hud(lv)
	h.no_hp = true
	var s := Scale.new(lv)
	s.name = "ShubinScale"
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	h.add_child(s)
	h.move_child(s, 0)
	var c := Cage.new(lv)
	c.name = "ShubinCage"
	c.z_index = 3
	lv.board.add_child(c)
	c.set_state("quiet" if lv.model.canary_quiet() else "sing")
	s.ang = s.target()
	var fr := LevelBoss.frame(lv)
	if fr and fr.get_node_or_null("ShubinLamps") == null:
		var l := Lamps.new(lv, fr)
		l.name = "ShubinLamps"
		fr.add_child(l)

## the canary sang (or not) after the player's move: its state, a note into the song's pan
static func sang(lv: Level, res: Dictionary) -> void:
	var c := cage_of(lv)
	var s := scale_of(lv)
	if c:
		c.set_state("sing" if bool(res.sang) else "quiet")
		if bool(res.sang) and s: s.note_to(c.mouth())
	if not bool(res.sang) and not lv.has_meta("quiet_told"):
		lv.set_meta("quiet_told", true)
		LevelBoss.line(lv, "quiet")

## gas came out of these cells: a puff from each into the gas pan, the beam jolts
static func gas_out(lv: Level, cells: Array) -> void:
	var s := scale_of(lv)
	if not s: return
	for p: Vector2i in cells:
		s.puff_to(lv.board.get_global_transform_with_canvas() * lv.board.cell_center(p.x, p.y))
	s.jolt(0.4 + 0.15 * cells.size())

static func update_bird(lv: Level) -> void:
	var c := cage_of(lv)
	if c and c.state in ["sing", "quiet"]: c.set_state("quiet" if lv.model.canary_quiet() else "sing")

static func lullaby(lv: Level) -> void:
	var c := cage_of(lv)
	if c: c.set_state("win")

static func fall(lv: Level) -> void:
	var c := cage_of(lv)
	if c: c.set_state("fall")
