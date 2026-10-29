class_name BossSea
extends Node2D
## The Kraken's sea over the bottom of his stage (LevelBoss mounts it right over BossView, under the board): a band of
## dark water from just above the frame's top bar down to the frame itself - into the board's cut-away top corners too -
## so where another boss' flat-cut bottom sank into a black box, his body goes on under the water, darker and darker.
## And his arms (`arm_strip.png`, one straight drawing bent live, Bend): on the last board two rise from behind him over
## the fight's top bar, sway, grope and now and then slap down across the boss' name plate. Each arm is drawn twice
## along the same curve: once behind his sprite (where it grows out of his body) and once over the top bar, clipped to
## above his stage, so the two meet without a seam. The close button, the moves and the bubble stay over them.

const WAVE := 4.0            # the surface's swell, pt
const OVER := 16.0           # the surface stands this far over the frame's top bar
const DEEP_FADE := 46.0      # beside the board, past its sides, the water fades out over this much

var lv: Level
var view: BossView
var arm_tex: Texture2D
var arm_root := 34.0
var surface := 0.0           # the water line, in the level's coordinates
var bottom := PackedFloat32Array()   # per x of the screen: how far down the water goes
var arms_on := false         # the last board: the arms are up
var back: Node2D             # the arms behind his sprite
var front: Control           # the arms over the top bar
var _t := 0.0
var _splash := -10.0         # when he last rose out of the water: spray and rings
var _slap := -10.0           # when an arm last slapped down over the name plate
## the gulls asleep on the island (on phase 1's picture, where `gulls` in boss.json says): as he wakes they start up
## off his head and fly away, beating their wings (`gull_fly_<k>.png`, a GPT sheet of a wing-beat). [{at, t0, dir, ph}]
var _gulls := []
var _gull_tex: Array[Texture2D] = []
var _next_slap := 4.0

static func load_for(level: Level, v: BossView) -> BossSea:
	var s := BossSea.new()
	s.lv = level
	s.view = v
	s.arm_tex = load(v.dir + "arm_strip.png")
	s.arm_root = float(v.meta.get("arm_root", 34))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = BoardSprites.plain_material()
	return s

func _ready() -> void:
	back = Node2D.new()
	back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	back.material = BoardSprites.plain_material()
	back.draw.connect(func(): _draw_arms(back))
	lv.add_child(back)
	lv.move_child(back, view.get_index())
	front = Control.new()
	front.clip_contents = true
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.material = BoardSprites.plain_material()
	var arms := Node2D.new()
	arms.draw.connect(func(): _draw_arms(arms))
	front.add_child(arms)
	var h := LevelBoss.hud(lv)
	h.add_child(front)
	# over the name plate, under the moves, the bubble and the close button
	h.move_child(front, h.moves_box.get_index())
	h.move_child(h.close_btn, -1)

## the water's outline for the board as it is now (LevelBoss.place)
func fit() -> void:
	var b := lv.board
	var m := lv.model
	var f := LevelBoss.frame(lv)
	var vp := lv.get_viewport_rect().size
	var top_line := lv.holder.position.y + f.top_line()
	surface = top_line - OVER
	var reach := b.TS * (float(f.meta.offset) + 0.3)
	var gx0 := lv.holder.position.x + b.PAD
	bottom.resize(int(vp.x) + 1)
	for x in bottom.size():
		var gx := x - gx0
		var top := INF
		var near := INF
		for c in m.C:
			var d := maxf(c * b.TS - reach - gx, gx - (c + 1) * b.TS - reach)
			for r in m.R:
				if m.playable(r, c):
					var y := lv.holder.position.y + b.PAD + r * b.TS - reach
					if d <= 0.0: top = minf(top, y)
					else: near = minf(near, y + d * 0.6)
					break
		# over a bar: down to it; past the board's sides: a little lower, fading
		bottom[x] = top + 2.0 if top < INF else minf(near, top_line + DEEP_FADE) if near < INF else top_line + DEEP_FADE
	front.position = Vector2.ZERO
	front.size = Vector2(vp.x, view.position.y)
	queue_redraw()

## he rises (a new board): the water bursts up along his body and falls back
func splash() -> void:
	_splash = _t

## he wakes: the gulls on his head (where his sprite stood, `from`) take off
func gulls_off(from: Vector2) -> void:
	if _gull_tex.is_empty():
		for k in 6:
			if ResourceLoader.exists(view.dir + "gull_fly_%d.png" % k): _gull_tex.append(load(view.dir + "gull_fly_%d.png" % k))
	if _gull_tex.is_empty(): return
	var list: Array = view.meta.get("gulls", [])
	for i in list.size():
		var p: Array = list[i]
		var at := from + Vector2(float(p[0]), float(p[1]))
		# each flees to its own side, a beat apart
		var dir := -1.0 if at.x < view.position.x + view.size.x * 0.45 else 1.0
		_gulls.append({at = at, t0 = _t + i * 0.12, dir = dir, ph = i * 2})

func set_board(i: int) -> void:
	arms_on = i >= 2

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()
	if arms_on:
		if _t > _next_slap:
			_slap = _t
			_next_slap = _t + randf_range(5.0, 9.0)
		back.queue_redraw()
		if front.get_child_count(): (front.get_child(0) as Node2D).queue_redraw()
	if _t - _slap > 0.25 and _t - _slap < 0.3:
		var h := LevelBoss.hud(lv)
		if h: _thump(h)

func _thump(h: BossHud) -> void:
	var tw := h.create_tween()
	for k in 3: tw.tween_property(h, "offset_top", randf_range(-2, 3), 0.04)
	tw.tween_property(h, "offset_top", 0.0, 0.05)

# ---------------------------------------------------------------- the sea

func _draw() -> void:
	if bottom.is_empty(): return
	var w := bottom.size()
	var tex := view.spr.texture
	var vx := view.position.x
	var vb := view.position.y + view.size.y
	var th := float(tex.get_height())
	# his body under the water: the sprite's last rows drawn on downwards, darkening into the deep
	var x := 0
	while x < w - 1:
		var x1 := mini(w - 1, x + 3)
		var deep: float = bottom[x]
		if deep > vb and x - vx >= 0.0 and x - vx < view.size.x:
			var src := Rect2(x - vx, th - 6.0, float(x1 - x), 6.0)
			draw_texture_rect_region(tex, Rect2(x, vb - 1.0, x1 - x, deep - vb + 1.0), src, Color(0.42, 0.42, 0.5))
		x = x1
	# the water itself: a dark sea-green body, lighter just under the surface, its surface swelling
	var wave := func(px: float) -> float:
		return surface + sin(px * 0.045 + _t * 1.6) * WAVE * 0.6 + sin(px * 0.11 - _t * 2.3) * WAVE * 0.4
	x = 0
	while x < w - 1:
		var x1 := mini(w - 1, x + 2)
		var y0: float = wave.call(float(x))
		var y1: float = bottom[x]
		if y1 > y0:
			draw_rect(Rect2(x, y0, x1 - x, y1 - y0), Color(0.03, 0.09, 0.11, 0.78))
			draw_rect(Rect2(x, y0, x1 - x, minf(10.0, y1 - y0)), Color(0.18, 0.32, 0.34, 0.45))
			# past the board's sides the water thins away instead of ending in a line
			var fade := clampf((y1 - y0 - 12.0) / DEEP_FADE, 0.0, 1.0)
			draw_rect(Rect2(x, y1 - 10.0, x1 - x, 10.0), Color(0.03, 0.09, 0.11, 0.25 * fade))
		x = x1
	var line := PackedVector2Array()
	for i in range(0, w, 3): line.append(Vector2(i, wave.call(float(i))))
	draw_polyline(line, Color(0.72, 0.86, 0.84, 0.75), 1.5)
	# the gulls flying off: a steep start, then away to their side and a little up, the wings beating fast at first
	for g: Dictionary in _gulls:
		var gt := _t - float(g.t0)
		if gt < 0.0 or gt > 2.6: continue
		var dir := float(g.dir)
		var at: Vector2 = g.at + Vector2(dir * (130.0 * gt * gt / (gt + 0.35)), -110.0 * gt + 25.0 * gt * gt)
		var fps := 16.0 if gt < 0.8 else 11.0
		var gtex: Texture2D = _gull_tex[(int(gt * fps) + int(g.ph)) % _gull_tex.size()]
		var sz := Vector2(gtex.get_size())
		var a := clampf((2.6 - gt) / 0.5, 0.0, 1.0)
		# the sheet flies right: mirrored for those fleeing left
		draw_set_transform((at - sz * 0.5).round() + Vector2(sz.x if dir < 0.0 else 0.0, 0), 0.0, Vector2(dir, 1.0))
		draw_texture(gtex, Vector2.ZERO, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the spray as he rises: drops thrown up from the surface along his width, falling back
	var ss := _t - _splash
	if ss < 1.8:
		var rnd := RandomNumberGenerator.new()
		rnd.seed = 77
		for k in 70:
			var x0 := view.position.x + rnd.randf() * view.size.x
			var vy := rnd.randf_range(90.0, 240.0)
			var dvx := rnd.randf_range(-30.0, 30.0)
			var st := ss - rnd.randf() * 0.5
			if st < 0.0: continue
			var p := Vector2(x0 + dvx * st, surface - vy * st + 260.0 * st * st)
			if p.y > surface + 4.0: continue
			var sz := 1.0 + float(k % 3)
			draw_rect(Rect2(p.round(), Vector2(sz, sz)), Color(0.8, 0.9, 0.9, 0.85 * clampf(1.6 - ss, 0.0, 1.0)))
	# foam: short bright dashes riding the swell
	for k in 14:
		var fx := fposmod(k * 61.0 + _t * (8.0 + k % 3 * 5.0), float(w))
		var fy: float = wave.call(fx)
		draw_line(Vector2(fx, fy + 1.0), Vector2(fx + 5.0 + k % 4 * 2.0, fy + 1.0), Color(0.9, 0.95, 0.92, 0.55), 1.0)

# ---------------------------------------------------------------- his arms

## an arm's curve: from its root behind his body up over the top bar; it sways, its tip gropes and curls; now and then
## one slaps down across the name plate and lifts again
func _arm(i: int) -> PackedVector2Array:
	var sx := 1.0 if i == 0 else -1.0
	var root := view.position + Vector2(view.size.x * (0.12 if i == 0 else 0.9), view.size.y * 0.5)
	var length := view.size.y * (1.25 if i == 0 else 1.0)
	var s := _t - _slap
	var slap := 0.0
	if i == int(_slap * 7.0) % 2 and s < 1.6:
		slap = sin(clampf(s / 0.3, 0.0, 1.0) * PI * 0.5) * (1.0 - clampf((s - 0.6) / 1.0, 0.0, 1.0))
	var ph := _t * (0.9 + i * 0.17) + i * 2.0
	return Bend.chain(root, length, 36, func(q: float) -> float:
		var a := -PI * 0.5 - sx * (0.12 + 0.1 * sin(ph))
		a += sx * q * (0.45 * sin(ph * 1.3 - q * 3.0)) + sx * pow(q, 2.2) * (1.6 + 0.6 * sin(ph * 0.7))
		a += sx * slap * q * 2.4
		return a)

func _draw_arms(ci: CanvasItem) -> void:
	if not arms_on or arm_tex == null: return
	var aspect := float(arm_tex.get_width()) / float(arm_tex.get_height())
	for i in 2:
		var pts := _arm(i)
		var L := Bend.length(pts)
		# the drawing tapers by itself: laid whole along the arm, as thick as its length keeps its proportions
		var half := L / aspect * 0.5
		Bend.draw(ci, pts, func(_q: float) -> float: return half, arm_tex, 0.0, 1.0, i == 1)
