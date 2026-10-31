class_name FxLayer
extends Node2D
## Explosions, sparks, flying dynamite, lightning and goal icons, drawn above the board.
## Positions are in the board's local space; this layer sits exactly on top of the board.
## The screen's glow pass is off (it cost the phone a full-screen blur): light - flashes, sparks, fire, bolts, streaks -
## is drawn adding onto what is under it (add_material), so it glows by itself.

var board: BoardView
var shake := 0.0
var _rings := []     # {pos, rad, t0, dur, col}
var _zaps := []      # {a, b, t0, pts}
var _flash := []     # {pos, r, t0, col}
var _was_busy := false
var _streaks := []   # {a, dir, len, speed, t0, col, w}: a lit trail behind something flying along a line
static var _add: ShaderMaterial

## a soft round puff, white in the middle and gone at its rim: what fire and smoke particles are drawn with
static var _puff: ImageTexture
const PUFF_PX := 64.0
static func puff() -> ImageTexture:
	if _puff == null:
		var n := int(PUFF_PX)
		var im := Image.create(n, n, true, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a := clampf(1.0 - d, 0.0, 1.0)
				im.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		im.generate_mipmaps()
		_puff = ImageTexture.create_from_image(im)
	return _puff

## the game is closing: the cached puff and material go while the renderer is still up
static func release() -> void:
	_puff = null
	_add = null

static func add_material() -> ShaderMaterial:
	if _add == null:
		_add = ShaderMaterial.new()
		_add.shader = preload("res://shaders/add.gdshader")
	return _add

func _ready() -> void:
	material = add_material()   # what this layer draws itself is light

func cell(r: float, c: float) -> Vector2:
	return board.cell_center(r, c)

## the whole game holds still for a blink: a heavy blast lands harder for it
static var _stop_until := 0
func hitstop(sec: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _stop_until: return
	_stop_until = now + int(sec * 1000.0) + 120
	Engine.time_scale = 0.05
	get_tree().create_timer(sec, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _process(dt: float) -> void:
	# camera-style shake applied to the board and this layer together; at rest nothing is moved or redrawn
	if shake > 0.05:
		shake = maxf(0.0, shake * pow(0.02, dt))
		board.get_parent().position = Vector2(randf() - 0.5, randf() - 0.5) * shake
	elif shake > 0.0:
		shake = 0.0
		board.get_parent().position = Vector2.ZERO
	if _rings.size() or _flash.size() or _zaps.size() or _streaks.size() or _was_busy:
		queue_redraw()
	_was_busy = _rings.size() > 0 or _flash.size() > 0 or _zaps.size() > 0 or _streaks.size() > 0

func _draw() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_rings.size() - 1, -1, -1):
		var g: Dictionary = _rings[i]
		var k: float = (now - g.t0) / g.dur
		if k >= 1.0:
			_rings.remove_at(i)
			continue
		var r: float = (0.4 + g.rad * 1.15) * board.TS * (1.0 - pow(1.0 - k, 3.0))
		var fade := (1.0 - k) * (1.0 - k)
		# a shockwave: a bright thin front over a broad soft band behind it
		draw_arc(g.pos, r * 0.94, 0, TAU, 56, Color(g.col, fade * 0.25), board.TS * 0.5 * (1.0 - k) + 2.0, true)
		draw_arc(g.pos, r, 0, TAU, 56, Color(g.col, fade * 0.9), board.TS * 0.1 * (1.0 - k) + 1.5, true)
	for i in range(_flash.size() - 1, -1, -1):
		var f: Dictionary = _flash[i]
		var k: float = (now - f.t0) / float(f.get("dur", 0.26))
		if k >= 1.0:
			_flash.remove_at(i)
			continue
		var a := (1.0 - k) * (1.0 - k)
		GemArt.radial_disc(self, f.pos, f.r * (0.7 + k * 0.5), Color(f.col, a), Color(f.col, a * 0.35), Color(f.col, 0))
		# a hot white core, gone in the first third
		if k < 0.35: GemArt.radial_disc(self, f.pos, f.r * 0.35, Color(1, 1, 1, (1.0 - k / 0.35) * 0.9), Color(1, 0.95, 0.8, (1.0 - k / 0.35) * 0.3), Color(1, 1, 1, 0))
	for i in range(_streaks.size() - 1, -1, -1):
		var st: Dictionary = _streaks[i]
		var age: float = now - float(st.t0)
		var head: float = minf(float(st.len), age * float(st.speed))
		var tail_t := age - float(st.len) / float(st.speed)
		var fade := 1.0 - clampf(tail_t / 0.25, 0.0, 1.0)
		if fade <= 0.0:
			_streaks.remove_at(i)
			continue
		# the trail: brightest at the head, thinning back towards where it started
		var a0: Vector2 = st.a
		var dir: Vector2 = st.dir
		var n := 10
		for s in n:
			var u0 := float(s) / n
			var u1 := float(s + 1) / n
			var p0 := a0 + dir * head * u0
			var p1 := a0 + dir * head * u1
			var aa := u1 * u1 * fade
			draw_line(p0, p1, Color(st.col, aa * 0.5), float(st.w) * (0.6 + u1 * 0.9), true)
			draw_line(p0, p1, Color(1, 1, 1, aa * 0.6), float(st.w) * 0.25 * (0.5 + u1), true)
	for i in range(_zaps.size() - 1, -1, -1):
		var z: Dictionary = _zaps[i]
		var k: float = (now - z.t0) / 0.28
		if k >= 1.0:
			_zaps.remove_at(i)
			continue
		var pts := PackedVector2Array()
		var segs := 9
		for s in segs + 1:
			var p: Vector2 = z.a.lerp(z.b, s / float(segs))
			if s > 0 and s < segs:
				p += Vector2(randf() - 0.5, randf() - 0.5) * board.TS * 0.35
			pts.append(p)
		draw_polyline(pts, (Color(0.25, 0.75, 1.0, (1.0 - k) * 0.5) if BoardSprites.gem_style != "" else Color(0.8, 0.5, 1.0, (1.0 - k) * 0.5)), board.TS * 0.2, true)
		draw_polyline(pts, (Color(0.5, 0.95, 1.0, 1.0 - k) if BoardSprites.gem_style != "" else Color(0.9, 0.7, 1.0, 1.0 - k)), 3.0, true)
		draw_polyline(pts, Color(1, 1, 1, 1.0 - k), 1.2, true)

# ---------------------------------------------------------------- particles

## a one-shot burst of chips or sparks
func burst(pos: Vector2, col: Color, amount: int, speed := 160.0, gravity := 520.0, size_px := 4.0, sparkle := false, spin := 360.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.7 if sparkle else 0.55
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = size_px * 0.5
	p.scale_amount_max = size_px
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	var ramp := Gradient.new()
	if sparkle:
		# sparks are light: added onto the board, white-hot as they fly out
		ramp.set_color(0, Color(minf(1.0, col.r * 1.6), minf(1.0, col.g * 1.6), minf(1.0, col.b * 1.6), 1))
		ramp.set_color(1, Color(col, 0))
		p.material = add_material()
		# a soft glowing dot, not a square
		p.texture = puff()
		p.scale_amount_min = size_px * 2.4 / PUFF_PX
		p.scale_amount_max = size_px * 4.2 / PUFF_PX
	else:
		ramp.set_color(0, col)
		ramp.set_color(1, Color(col, 0))
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

## a blocker breaking: its own pieces (blocker_kit.py's shards) burst out, spin and fall away, then the dust
func shards(r: float, c: float, kind: String, col: Color) -> void:
	var at := cell(r, c)
	var ts := board.TS
	for k in 3:
		var s := Sprite2D.new()
		s.texture = BoardSprites.blocker("shards/%s_%d" % [kind, k])
		s.scale = Vector2.ONE * ts * BoardSprites.SPAN / float(s.texture.get_width())
		s.position = at
		s.material = BoardSprites.plain_material()
		add_child(s)
		var dir := Vector2.from_angle(-PI / 2 + (k - 1) * 1.1 + randf_range(-0.3, 0.3))
		var tw := create_tween().set_parallel()
		var dur := randf_range(0.45, 0.6)
		tw.tween_property(s, "position:x", at.x + dir.x * ts * 0.9, dur)
		tw.tween_property(s, "position:y", at.y + dir.y * ts * 0.45 + ts * 0.9, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "rotation", randf_range(-2.5, 2.5), dur)
		tw.tween_property(s, "scale", s.scale * 0.6, dur)
		tw.tween_property(s, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
		tw.chain().tween_callback(s.queue_free)
	debris(r, c, col, 6)

## a malachite crust cracking off its stone: the shell's own plates (art/malachite/parts_cut.py) fly out from the middle,
## turning, and fall away
func plates(r: float, c: float, look: int) -> void:
	var at := cell(r, c)
	var ts := board.TS
	var cen: Array = BoardSprites.malachite_info("crust").get(str(look), [])
	for j in cen.size():
		var s := Sprite2D.new()
		s.texture = BoardSprites.malachite("crust_%d_%d" % [look, j])
		var px := float(s.texture.get_width())
		var off := Vector2(float(cen[j][0]), float(cen[j][1]))      # the plate's middle from the cell's, in cells
		s.scale = Vector2.ONE * ts * BoardSprites.SPAN / px
		s.offset = -off / BoardSprites.SPAN * px                    # turn about the plate itself, not the shell
		s.position = at + off * ts
		s.material = BoardSprites.plain_material()
		add_child(s)
		var dir := off.normalized() if off.length() > 0.01 else Vector2.UP
		var tw := create_tween().set_parallel()
		var dur := randf_range(0.45, 0.6)
		tw.tween_property(s, "position:x", s.position.x + dir.x * ts * 0.8, dur)
		tw.tween_property(s, "position:y", s.position.y + dir.y * ts * 0.5 + ts * 0.8, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "rotation", (1.0 if dir.x >= 0 else -1.0) * randf_range(0.8, 1.8), dur)
		tw.tween_property(s, "scale", s.scale * 0.75, dur)
		tw.tween_property(s, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
		tw.chain().tween_callback(s.queue_free)
	debris(r, c, Color("#2f8a62"), 6)

## the stone flower losing a ring: its petals (flower_<ring>_<k>, placed as in the flower) fly off outward, turning
func petals(r: float, c: float, ring: String) -> void:
	var at := cell(r + 0.5, c + 0.5)
	var ts := board.TS
	var k := ts / 42.0
	var parts: Dictionary = BoardSprites.flower_info().get("parts", {})
	for name: String in parts:
		if not name.begins_with(ring + "_"): continue
		var off := Vector2(float(parts[name][0]), float(parts[name][1])) * k
		var s := Sprite2D.new()
		s.texture = BoardSprites.flower("flower_" + name)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * k
		s.offset = -off / k                     # turn about the petal itself
		s.position = at + off
		s.material = BoardSprites.plain_material()
		add_child(s)
		var dir := off.normalized() if off.length() > 0.01 else Vector2.UP
		var tw := create_tween().set_parallel()
		var dur := randf_range(0.5, 0.7)
		tw.tween_property(s, "position", s.position + dir * ts * 1.1 + Vector2(0, ts * 0.6), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "rotation", (1.0 if dir.x >= 0 else -1.0) * randf_range(0.6, 1.6), dur)
		tw.tween_property(s, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.5)
		tw.chain().tween_callback(s.queue_free)
	sparkle(r + 0.5, c + 0.5, Color("#5fe0a0"), 14)

## a booster's sprite (art/boosters) on a holder node, `cells` board cells across, its own material or the plain one
func _boost_sprite(name: String, cells: float, mat: Material = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = BoardSprites.tex(name)
	s.scale = Vector2.ONE * board.TS * cells / float(s.texture.get_width())
	s.material = mat if mat else BoardSprites.plain_material()
	return s

## a sprite UV (anchors.json) as an offset from the sprite's centre, for a sprite `size` px across
static func _uv_off(uv: Array, size: float) -> Vector2:
	return (Vector2(float(uv[0]), float(uv[1])) - Vector2(0.5, 0.5)) * size

## when the pickaxe's blade lands, from the start of its swing (s): Level waits this long before the hit
const PICK_HIT := 0.3

## the pickaxe booster: held by its handle's foot, it is raised behind, swung down hard onto the cell (two fading
## ghosts behind the blade), strikes with a flash, sparks and rock chips, bounces back a little and drops away
func pickaxe(r: int, c: int) -> void:
	var at := cell(r, c)
	var ts := board.TS
	var cells := BoardSprites.SPAN * 2.3
	var size := ts * cells
	var an := BoardSprites.booster_anchor("pick")
	var grip := _uv_off(an.get("grip", [0.18, 0.89]), size)
	var tip := _uv_off(an.get("tip", [0.82, 0.37]), size) - grip
	var hit := 0.35                      # the swing's angle as the blade bites (turned this far clockwise)
	var raised := hit - 1.6
	var pivot := Node2D.new()            # turns about the handle's foot, as a swing does
	pivot.position = at - tip.rotated(hit)
	pivot.z_index = 6
	add_child(pivot)
	var ghosts: Array[Sprite2D] = []
	for k in 3:
		var s := _boost_sprite("pick", cells)
		s.position = -grip
		var g := Node2D.new()
		g.add_child(s)
		pivot.add_child(g)
		if k > 0:
			s.modulate = Color(1, 1, 1, 0.0)
			ghosts.append(s)
	var main: Node2D = pivot.get_child(0)
	var swing := func(a: float):
		main.rotation = a
		# the ghosts trail the blade only while it comes down fast
		for k in ghosts.size():
			var g: Node2D = ghosts[k].get_parent()
			g.rotation = a - (k + 1) * 0.16
	pivot.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(pivot, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_method(swing, raised + 0.35, raised, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(PICK_HIT - 0.16 - 0.1)
	tw.tween_callback(func():
		for k in ghosts.size(): ghosts[k].modulate.a = 0.35 - k * 0.15)
	tw.tween_method(swing, raised, hit, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		for gs in ghosts: gs.modulate.a = 0.0
		shake = maxf(shake, 8.0)
		flash(r, c, Color(2.2, 1.8, 1.2), 1.0)
		ring(r, c, 0.2, Color(1.6, 1.3, 0.9))
		burst(at, Color("#b8a890"), 14, 260.0, 700.0, 5.0)
		burst(at, Color("#6e6050"), 8, 180.0, 800.0, 6.0)
		burst(at, Color(2.6, 2.0, 0.9), 10, 300.0, 300.0, 2.5, true))
	# the blade bounces off the rock, hangs a moment, then falls away fading
	tw.tween_method(swing, hit, hit - 0.3, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(swing, hit - 0.3, hit - 0.22, 0.12)
	tw.tween_property(pivot, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(pivot, "position", pivot.position + Vector2(0, ts * 0.4), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(pivot.queue_free)

## the drill boosters: the rock drill slides up to the board's edge (left, or the top), revs there shuddering with its
## auger spinning (shaders/booster_spin.gdshader), then bores through the whole row or column - its tip reaching
## cell k at `t_in + k * step` seconds, as the model's hits land - throwing sparks and grit back off the auger and
## leaving a scored groove that fades; out past the far edge it flies off
func bore(sp: String, r: int, c: int, t_in: float, step: float) -> void:
	var ts := board.TS
	var horiz := sp == "bore_h"
	var dir := Vector2.RIGHT if horiz else Vector2.DOWN
	var side := dir.orthogonal()
	var n: int = board.C if horiz else board.R
	var cells := BoardSprites.SPAN * 2.5
	var size := ts * cells
	var an := BoardSprites.booster_anchor(sp)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/booster_spin.gdshader")
	mat.set_shader_parameter("axis", dir)
	mat.set_shader_parameter("split", float(an.get("split", 0.55)))
	mat.set_shader_parameter("spin", 0.0)
	var s := _boost_sprite(sp, cells, mat)
	var tip := _uv_off(an.get("tip", [0.95, 0.53] if horiz else [0.53, 0.93]), size)
	var first := cell(r, 0) if horiz else cell(0, c)
	var last := cell(r, n - 1) if horiz else cell(n - 1, c)
	var edge := first - dir * ts * 0.62          # the board's rim just before the first cell
	var holder := Node2D.new()
	holder.z_index = 6
	holder.position = edge - dir * ts * 1.8 - tip
	holder.modulate.a = 0.0
	add_child(holder)
	holder.add_child(s)
	# the groove it scores along the line: dark, with a lit lip, growing behind the tip and fading after
	# (a wide soft scuff, the cut itself darker in it, its upper lip catching the light)
	var scuff := Line2D.new()
	scuff.width = ts * 0.5
	scuff.default_color = Color(0.1, 0.08, 0.06, 0.22)
	var groove := Line2D.new()
	groove.width = ts * 0.18
	groove.default_color = Color(0.05, 0.04, 0.03, 0.55)
	var lip := Line2D.new()
	lip.width = ts * 0.04
	lip.default_color = Color(1.0, 0.85, 0.6, 0.4)
	lip.position = side * ts * 0.1 if horiz else -side * ts * 0.1     # the lip towards the light, up or left
	for ln: Line2D in [scuff, groove, lip]:
		ln.begin_cap_mode = Line2D.LINE_CAP_ROUND
		ln.end_cap_mode = Line2D.LINE_CAP_ROUND
		ln.z_index = 5
		ln.add_point(edge)
		ln.add_point(edge)
		add_child(ln)
	# sparks off the bit (glowing, quick) and grit thrown back off the auger (falls)
	var sparks := CPUParticles2D.new()
	sparks.amount = 40
	sparks.lifetime = 0.28
	sparks.position = tip
	sparks.direction = -dir
	sparks.spread = 70
	sparks.gravity = Vector2(0, 500)
	sparks.initial_velocity_min = 160
	sparks.initial_velocity_max = 380
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = Color(2.6, 1.7, 0.6)
	sparks.emitting = false
	var grit := CPUParticles2D.new()
	grit.amount = 60
	grit.lifetime = 0.55
	grit.position = tip - dir * ts * 0.3
	grit.direction = -dir + side * 0.5
	grit.spread = 50
	grit.gravity = Vector2(0, 700)
	grit.initial_velocity_min = 80
	grit.initial_velocity_max = 260
	grit.scale_amount_min = 2.5
	grit.scale_amount_max = 5.5
	grit.angular_velocity_min = -300
	grit.angular_velocity_max = 300
	grit.color = Color("#a89478")
	grit.emitting = false
	holder.add_child(grit)
	holder.add_child(sparks)
	var shudder := create_tween().set_loops()
	shudder.tween_property(s, "position", -side * 1.8, 0.025)
	shudder.tween_property(s, "position", side * 1.8, 0.025)
	var spin := func(v: float): mat.set_shader_parameter("spin", v)
	var follow := func(p: Vector2):
		holder.position = p - tip
		# the groove runs from the rim to just behind the tip
		var end := p - dir * ts * 0.2
		if (end - edge).dot(dir) > 0.0:
			for ln: Line2D in [scuff, groove, lip]:
				if is_instance_valid(ln): ln.set_point_position(1, end)
	var come := t_in * 0.45
	var rev := t_in * 0.35
	var tw := create_tween()
	# slides up to the rim, spinning up
	tw.tween_property(holder, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_method(follow, edge - dir * ts * 1.8, edge - dir * ts * 0.1, come).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(spin, 0.0, 0.6, come)
	# revs at the rim: a kick back, sparks, the auger at full speed
	tw.tween_callback(func():
		sparks.emitting = true
		shake = maxf(shake, 3.0))
	tw.tween_method(follow, edge - dir * ts * 0.1, edge - dir * ts * 0.22, rev * 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_method(spin, 0.6, 1.0, rev)
	tw.tween_method(follow, edge - dir * ts * 0.22, edge, rev * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# bores through
	tw.tween_callback(func():
		grit.emitting = true
		shake = maxf(shake, 6.0)
		burst(edge, Color("#8a7a66"), 12, 200.0, 600.0, 5.0))
	tw.tween_method(follow, edge, first, t_in - come - rev)
	tw.tween_method(follow, first, last, step * (n - 1))
	tw.tween_callback(func():
		sparks.emitting = false
		grit.emitting = false
		burst(last + dir * ts * 0.62, Color("#8a7a66"), 14, 240.0, 600.0, 5.0)
		shake = maxf(shake, 5.0))
	# out past the far edge, winding down
	tw.tween_method(follow, last, last + dir * ts * 3.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.24).set_delay(0.08)
	tw.parallel().tween_method(spin, 1.0, 0.3, 0.24)
	tw.tween_callback(func():
		shudder.kill()
		holder.queue_free())
	var fade := create_tween()
	# it fades once the bit is through (the first fade waits out the whole bore, the others run alongside it)
	fade.tween_interval(t_in + step * (n - 1) + 0.4)
	fade.tween_property(scuff, "modulate:a", 0.0, 0.45)
	fade.parallel().tween_property(groove, "modulate:a", 0.0, 0.45)
	fade.parallel().tween_property(lip, "modulate:a", 0.0, 0.45)
	fade.tween_callback(func():
		for ln: Line2D in [scuff, groove, lip]: ln.queue_free())

## the gold pan booster: the pan drops over the middle of the board with a bounce, then is swirled - the pan wheeling
## round a small circle and rocking, its load of sand, gold and stones sloshing round inside it a beat behind, sand and
## gold flecks flung off the rim - and lifts away. Level starts the stones for their new places a moment into the
## swirl (this returns then); the pan finishes on its own.
func pan() -> void:
	var ts := board.TS
	var mid := (cell(0, 0) + cell(board.R - 1, board.C - 1)) / 2.0
	var cells := 6.2
	var size := ts * cells
	var holder := Node2D.new()
	holder.z_index = 40     # over the stones tossed round under it
	add_child(holder)
	var bowl := _boost_sprite("pan_bowl", cells)
	var heap := _boost_sprite("pan_load", cells)
	holder.add_child(bowl)
	holder.add_child(heap)
	var load_at := _uv_off(BoardSprites.booster_anchor("pan").get("load", [0.5, 0.58]), size)
	# the heap turns about its own middle
	heap.offset = -load_at / heap.scale.x
	heap.position = load_at
	holder.position = mid + Vector2(0, -ts * 3.0)
	holder.scale = Vector2(0.7, 0.7)
	holder.modulate.a = 0.0
	var rad := ts * 0.45
	var swirl := func(a: float):
		var k := clampf(minf(a, TAU * 2.25 - a) / 1.2, 0.0, 1.0)    # eases in and out of the circling
		holder.position = mid + Vector2(cos(a - PI / 2), sin(a - PI / 2) * 0.55) * rad * k
		holder.rotation = sin(a) * 0.12 * k
		holder.scale = Vector2(1.0 + sin(a * 2.0) * 0.02 * k, 1.0 - sin(a * 2.0) * 0.03 * k)
		# the heap lags the pan: it slides out towards where the pan was a beat ago and turns round with it
		var lag := a - 1.1
		# (only a little: the heap is an oval in an oval floor, and must stay inside the walls)
		heap.position = load_at + Vector2(cos(lag), sin(lag) * 0.5) * size * 0.022 * k
		heap.rotation = sin(lag) * 0.1 * k
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(holder, "position", mid, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(holder, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): shake = maxf(shake, 4.0))
	tw.tween_method(swirl, 0.0, TAU * 2.25, 1.0)
	tw.tween_property(holder, "position", mid + Vector2(0, -ts * 3.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.2).set_delay(0.08)
	tw.tween_callback(holder.queue_free)
	# flung off the rim as it goes round: sand, and now and then a glint of gold
	for k in 6:
		get_tree().create_timer(0.36 + k * 0.15).timeout.connect(func():
			var a := randf() * TAU
			var rim := holder.position + Vector2(cos(a), sin(a) * 0.6) * size * 0.42
			burst(rim, Color("#b39a70"), 10, 240.0, 700.0, 4.0)
			if k % 2 == 0: burst(rim, Color(2.4, 1.8, 0.6), 5, 200.0, 400.0, 3.0, true))
	await get_tree().create_timer(0.5).timeout

func debris(r: float, c: float, col: Color, amount := 10) -> void:
	burst(cell(r, c), col, amount, 170.0, 620.0, 4.5)

## a gem broken: grey-brown rock grit with only a hint of the stone's colour, barely turning, and a couple of
## glints of its colour (pure-coloured spinning squares read as confetti when a blast breaks many colours at once)
func gem_chips(r: float, c: float, col: Color) -> void:
	var rock := Color("#6e6050").lerp(col.darkened(0.35), 0.3)
	burst(cell(r, c), rock, 5, 170.0, 700.0, 3.5, false, 90.0)
	burst(cell(r, c), Color(col.lightened(0.3), 1.0), 3, 120.0, 200.0, 2.0, true, 0.0)

## a stone going into a cart: a small copy of it hops from its cell into the cart's mouth
func fly_gem(r: float, c: float, to: Vector2, colour: int) -> void:
	var n := Node2D.new()
	var S := board.TS * 0.62
	var tx := BoardSprites.gem(colour)
	n.draw.connect(func(): BoardSprites.draw(n, tx, Vector2.ZERO, S))
	n.material = BoardSprites.plain_material()
	n.position = cell(r, c)
	add_child(n)
	var p0 := n.position
	var mid := p0.lerp(to, 0.5) + Vector2(0, -board.TS * 0.9)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		n.position = p0.lerp(mid, t).lerp(mid.lerp(to, t), t)
		n.scale = Vector2.ONE * lerpf(1.0, 0.7, t)
		n.rotation = t * 2.5, 0.0, 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(n.queue_free)

## the ore bucket tips a nugget out: it arcs from the bucket onto the stone it lands on, which then is the nugget
func toss_nugget(r: float, c: float, tr: float, tc: float, on_land: Callable) -> void:
	var n := Node2D.new()
	var S := board.TS * 0.8
	n.draw.connect(func(): BoardSprites.draw(n, BoardSprites.tex("nug"), Vector2.ZERO, S))
	n.material = BoardSprites.plain_material()
	n.position = cell(r, c)
	add_child(n)
	var p0 := n.position
	var p1 := cell(tr, tc)
	var mid := p0.lerp(p1, 0.5) + Vector2((p1.x - p0.x) * 0.2, -board.TS * 1.2)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		n.position = p0.lerp(mid, t).lerp(mid.lerp(p1, t), t)
		n.rotation = t * 4.0, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(func():
		n.queue_free()
		on_land.call())

func sparkle(r: float, c: float, col: Color, amount := 24) -> void:
	burst(cell(r, c), col, amount, 230.0, 60.0, 3.0, true)

func flash(r: float, c: float, col: Color, size_cells := 1.6, dur := 0.26) -> void:
	_flash.append({pos = cell(r, c), r = board.TS * size_cells, t0 = Time.get_ticks_msec() / 1000.0, col = col, dur = dur})

## a lit trail along a line from a, `len` px long, its head going `speed` px/s
func streak(a: Vector2, dir: Vector2, len: float, speed: float, col: Color, w := 0.0) -> void:
	_streaks.append({a = a, dir = dir.normalized(), len = len, speed = speed, t0 = Time.get_ticks_msec() / 1000.0, col = col, w = w if w > 0.0 else board.TS * 0.22})

## a fireball: hot light swelling and rising, going red as it dies, then smoke rolling up slowly
func fireball(pos: Vector2, size_cells: float) -> void:
	var ts := board.TS
	var f := CPUParticles2D.new()
	f.position = pos
	f.one_shot = true
	f.explosiveness = 0.9
	f.amount = int(14 + size_cells * 8)
	f.lifetime = 0.55
	f.spread = 180.0
	f.direction = Vector2(0, -1)
	f.initial_velocity_min = ts * 0.6
	f.initial_velocity_max = ts * (1.4 + size_cells * 0.9)
	f.damping_min = ts * 2.0
	f.damping_max = ts * 3.0
	f.gravity = Vector2(0, -ts * 1.5)
	f.texture = puff()
	f.scale_amount_min = ts * 0.55 * (1.0 + size_cells * 0.25) / PUFF_PX
	f.scale_amount_max = ts * 1.0 * (1.0 + size_cells * 0.25) / PUFF_PX
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1, 0.6))
	f.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	ramp.add_point(0.3, Color(1.0, 0.6, 0.15, 0.85))
	ramp.set_color(1, Color(0.6, 0.12, 0.02, 0.0))
	f.color_ramp = ramp
	f.material = add_material()
	add_child(f)
	f.emitting = true
	get_tree().create_timer(0.9).timeout.connect(f.queue_free)
	var s := CPUParticles2D.new()
	s.position = pos
	s.one_shot = true
	s.explosiveness = 0.7
	s.amount = int(8 + size_cells * 4)
	s.lifetime = 1.1
	s.spread = 180.0
	s.initial_velocity_min = ts * 0.2
	s.initial_velocity_max = ts * (0.6 + size_cells * 0.4)
	s.damping_min = ts * 0.8
	s.damping_max = ts * 1.2
	s.gravity = Vector2(0, -ts * 0.9)
	s.texture = puff()
	s.scale_amount_min = ts * 0.8 / PUFF_PX
	s.scale_amount_max = ts * 1.3 / PUFF_PX
	var sc2 := Curve.new()
	sc2.add_point(Vector2(0, 0.5))
	sc2.add_point(Vector2(1, 1.3))
	s.scale_amount_curve = sc2
	var r2 := Gradient.new()
	r2.set_color(0, Color(0.25, 0.2, 0.17, 0.0))
	r2.add_point(0.15, Color(0.22, 0.18, 0.15, 0.55))
	r2.set_color(1, Color(0.15, 0.13, 0.12, 0.0))
	s.color_ramp = r2
	s.material = BoardSprites.plain_material()
	add_child(s)
	s.emitting = true
	get_tree().create_timer(1.4).timeout.connect(s.queue_free)

## a stone pops: a quick soft light of its colour where it was
func pop_glow(r: float, c: float, col: Color) -> void:
	flash(r, c, Color(col.lerp(Color.WHITE, 0.35), 0.55), 0.75, 0.2)

## the cascade's count, rising over where the latest match went: larger and warmer the longer it runs
func chain_text(at: Vector2, n: int) -> void:
	var l := Label.new()
	l.text = "x%d" % n
	var fs := 18 + mini(n, 8) * 3
	l.add_theme_font_override("font", UI.display)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1.0, 0.92 - mini(n, 8) * 0.05, 0.6 - mini(n, 8) * 0.06))
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.0, 0.95))
	l.add_theme_constant_override("outline_size", 7)
	l.size = Vector2(90, fs + 8)
	l.position = at - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.material = BoardSprites.plain_material()
	add_child(l)
	l.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - board.TS * 0.7, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

# ---------------------------------------------------------------- big effects

func ring(r: float, c: float, rad: float, col := Color(2.0, 1.4, 0.6)) -> void:
	_rings.append({pos = cell(r, c), rad = rad, t0 = Time.get_ticks_msec() / 1000.0, dur = 0.45 + rad * 0.05, col = col})

func boom(r: int, c: int, rad: int) -> void:
	ring(r, c, rad, Color(1.0, 0.75, 0.4))
	flash(r, c, Color(1.0, 0.7, 0.3), 1.6 + rad * 0.8, 0.34)
	fireball(cell(r, c), 0.8 + rad * 0.6)
	burst(cell(r, c), Color(1.0, 0.75, 0.35), 22 + rad * 8, board.TS * (5.0 + rad * 1.2), board.TS * 4.0, 3.5, true)
	burst(cell(r, c), Color("#6a5848"), 14 + rad * 4, board.TS * (3.5 + rad * 0.8), board.TS * 14.0, 5.0)
	shake = maxf(shake, 9.0 + rad * 3.0)
	if rad >= 2: hitstop(0.04 + rad * 0.012)

## dynamite shoots both ways along a row or column, with a fizzing trail
func rocket(sp: String, r: int, c: int) -> void:
	shake = maxf(shake, 5.0)
	flash(r, c, Color(1.0, 0.75, 0.35), 1.4, 0.22)
	# a burning line along the row or column, both ways, at the sticks' speed (BoardModel: a cell every 32 ms)
	for d2 in ([Vector2(1, 0), Vector2(-1, 0)] if sp == "rh" else [Vector2(0, 1), Vector2(0, -1)]):
		streak(cell(r, c), d2, board.TS * 10.0, board.TS / 0.032, Color(1.0, 0.62, 0.22), board.TS * 0.3)
	var dirs := [Vector2i(0, 1), Vector2i(0, -1)] if sp == "rh" else [Vector2i(1, 0), Vector2i(-1, 0)]
	for d in dirs:
		var n := Node2D.new()
		n.position = cell(r, c)
		if BoardSprites.gem_style != "":
			# the stick itself flies, spinning end over end along its line
			var spr := Sprite2D.new()
			spr.texture = BoardSprites.tex(sp)
			spr.scale = Vector2.ONE * board.TS * BoardSprites.SPAN * 0.85 / float(spr.texture.get_width())
			spr.material = BoardSprites.plain_material()
			n.add_child(spr)
			var spin := create_tween()
			spin.tween_property(spr, "rotation", TAU * 1.5 * (1 if d.y + d.x > 0 else -1), 0.3)
		else:
			n.rotation = 0.0 if d.x == 0 else PI / 2
			n.draw.connect(func():
				n.draw_colored_polygon(GemArt.rrect(Vector2(-board.TS * 0.3, -board.TS * 0.1), Vector2(board.TS * 0.6, board.TS * 0.2), board.TS * 0.08), Color("#e0302a"))
				n.draw_circle(Vector2(board.TS * 0.32 * (1 if d.y + d.x > 0 else -1), 0), board.TS * 0.09, Color(3.0, 2.2, 0.8)))
		add_child(n)
		var trail := CPUParticles2D.new()
		trail.amount = 40
		trail.lifetime = 0.35
		trail.gravity = Vector2.ZERO
		trail.spread = 25
		trail.direction = Vector2(-d.y, -d.x)
		trail.initial_velocity_min = 30
		trail.initial_velocity_max = 80
		trail.scale_amount_min = 2
		trail.scale_amount_max = 4
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.85, 0.45))
		ramp.set_color(1, Color(1, 0.3, 0.1, 0))
		trail.color_ramp = ramp
		trail.material = add_material()
		trail.texture = puff()
		trail.scale_amount_min = board.TS * 0.12 / PUFF_PX
		trail.scale_amount_max = board.TS * 0.26 / PUFF_PX
		n.add_child(trail)
		var far := 9.0
		var target := cell(r + d.x * far, c + d.y * far)
		var tw := create_tween()
		tw.tween_property(n, "position", target, far * 0.032 * 1.0).set_trans(Tween.TRANS_LINEAR)
		tw.finished.connect(n.queue_free)

func drill(r: int, c: int, tr: int, tc: int) -> void:
	var n := Node2D.new()
	n.position = cell(r, c)
	if BoardSprites.gem_style != "":
		# the auger flies point first towards its target, shuddering as it bores, throwing chips behind it
		var spr := Sprite2D.new()
		spr.texture = BoardSprites.tex("drill")
		spr.scale = Vector2.ONE * board.TS * BoardSprites.SPAN * 0.9 / float(spr.texture.get_width())
		spr.material = BoardSprites.plain_material()
		n.add_child(spr)
		n.rotation = (cell(tr, tc) - cell(r, c)).angle() - PI / 2     # the sprite points down: turn it to the target
		add_child(n)
		var shake := create_tween().set_loops(8)
		shake.tween_property(spr, "position:x", board.TS * 0.04, 0.025)
		shake.tween_property(spr, "position:x", -board.TS * 0.04, 0.025)
		var tw2 := create_tween()
		tw2.tween_property(n, "position", cell(tr, tc), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw2.tween_callback(func():
			shake.kill()
			burst(cell(tr, tc), Color("#8a8f99"), 10, 200.0, 600.0, 4.0)
			n.queue_free())
		return
	n.draw.connect(func():
		GemArt.begin(n, Transform2D(0.0, Vector2(0.8, 0.8), 0.0, Vector2.ZERO))
		GemArt.special(n, "drill", board.TS)
		GemArt.end(n))
	add_child(n)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position", cell(tr, tc), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(n, "rotation", TAU * 2, 0.42)
	tw.chain().tween_callback(n.queue_free)

func zap(r: int, c: int, tr: int, tc: int) -> void:
	_zaps.append({a = cell(r, c), b = cell(tr, tc), t0 = Time.get_ticks_msec() / 1000.0})
	flash(tr, tc, Color(0.45, 0.9, 1.0), 0.9, 0.22)
	sparkle(tr, tc, Color(0.45, 0.95, 1.0) if BoardSprites.gem_style != "" else Color(0.85, 0.65, 1.0), 6)

func pop_text(r: float, c: float, txt: String, col := Color("#ffb090")) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.position = cell(r, c) - Vector2(40, 12)
	l.size = Vector2(80, 24)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 46, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)

## an icon of what was collected flies into the goal panel (target in this layer's space)
## a round ore badge flying from a cell to the HUD
func fly_badge(r: float, c: float, target: Vector2, kind: String, on_land: Callable) -> void:
	var n := Node2D.new()
	var rad: float = board.TS * 0.26
	var it: Texture2D = Kit.res_icon(kind, 1).texture   # the kit's own ore, as in the HUD it flies to
	n.draw.connect(func(): n.draw_texture_rect(it, Rect2(-Vector2(rad, rad) * 1.2, Vector2(rad, rad) * 2.4), false))
	n.position = cell(r, c)
	add_child(n)
	var p0 := n.position
	var mid := p0.lerp(target, 0.5) + Vector2(randf_range(-40, 40), -60)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		n.position = p0.lerp(mid, t).lerp(mid.lerp(target, t), t)
		n.scale = Vector2.ONE * lerpf(1.2, 0.8, t), 0.0, 1.0, 0.5 + randf() * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(func():
		n.queue_free()
		on_land.call())

func fly_icon(r: float, c: float, target: Vector2, k: String, colour: int, glow: Color, on_land: Callable) -> void:
	var n := Node2D.new()
	var S := board.TS * 0.8
	n.position = cell(r, c)
	n.draw.connect(func():
		GemArt.begin(n, Transform2D.IDENTITY)
		GemArt.goal_icon(n, k, colour, S, glow))
	n.material = BoardSprites.plain_material()   # the stock shader draws no textures on iPhone (see Level)
	n.position -= Vector2(S, S) * 0.5
	add_child(n)
	var mid := n.position.lerp(target, 0.5) + Vector2(randf_range(-60, 60), -80)
	var tw := create_tween()
	var dur := 0.52 + randf() * 0.12
	tw.tween_method(func(t: float):
		n.position =(n.get_meta("p0") as Vector2).lerp(mid, t).lerp(mid.lerp(target - Vector2(S, S) * 0.5, t), t)
		n.scale = Vector2.ONE * lerpf(1.0, 0.6, t), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	n.set_meta("p0", n.position)
	tw.finished.connect(func():
		n.queue_free()
		on_land.call())
