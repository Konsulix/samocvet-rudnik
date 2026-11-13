class_name AwardsRail
extends Control
## The awards waiting to be claimed, at the edge of the mine screen (as a match-three keeps its events down the sides
## of its home) — only those: one still being gathered is not shown, and with none waiting the rail is empty. The
## whole list stays where it was, behind the cups in the cabinet.
## Each is its icon in a brass ring, nothing else — no caption, no badge. Every icon is fitted into the ring's
## window by its own outline (fit), so a wide one and a tall one sit in it alike.
## One thing moves: a soft halo behind the ring, breathing. (Rays, a hopping icon, a sway and a glint together were
## too much: one or the other.) They slide in when the screen opens.
## A tap opens that award's sheet over the mine screen (Home._open_award): what it was for, what it gives, Claim.
## Claimed, the medallion leaves.

signal claim(name: String)

const D := 56.0               # a medallion across
const HOLE := 0.36            # the ring's window, its radius in medallions
const PITCH := 66.0
const SLOTS := 4

static var _fit := {}         # picture -> [its outline's middle (px), the outline's reach from it (px)]
var _medals := {}             # award -> Medal
var _fresh := true            # the first fill: they slide in one after another

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## what is shown now: new medallions come, the claimed ones leave, the rest move up
func refresh() -> void:
	var want: Array = []
	var es := {}
	for e: Dictionary in Awards.rail(SLOTS):
		want.append(String(e.n))
		es[String(e.n)] = e
	for nm: String in _medals.keys():
		if not nm in want:
			(_medals[nm] as Medal).leave()
			_medals.erase(nm)
	for k in want.size():
		var nm: String = want[k]
		var at := Vector2(0, k * PITCH)
		var m: Medal = _medals.get(nm)
		if m == null:
			m = Medal.new()
			m.setup(es[nm])
			m.position = at
			add_child(m)
			_medals[nm] = m
			m.pressed.connect(func(): claim.emit(nm))
			m.enter(0.3 + 0.1 * k if _fresh else 0.15)
		else:
			m.move_to(at)
	_fresh = false
	size = Vector2(D, want.size() * PITCH)

## where a picture's drawing is and how far it reaches: the middle of its outline's box and the farthest inked point
## from it — by these it is scaled to touch the ring's window and no more
static func fit(tex: Texture2D) -> Array:
	if not _fit.has(tex):
		var im := tex.get_image()
		var w := im.get_width()
		var h := im.get_height()
		var step := maxi(1, mini(w, h) / 64)
		var lo := Vector2(w, h)
		var hi := Vector2.ZERO
		var pts := PackedVector2Array()
		for y in range(0, h, step):
			for x in range(0, w, step):
				if im.get_pixel(x, y).a > 0.35:
					var p := Vector2(x, y)
					lo = lo.min(p)
					hi = hi.max(p)
					pts.append(p)
		var mid := (lo + hi) / 2.0 if pts.size() else Vector2(w, h) / 2.0
		var reach := 1.0
		for p in pts: reach = maxf(reach, p.distance_to(mid))
		_fit[tex] = [mid, reach + step]
	return _fit[tex]

## one award waiting for its claim
class Medal extends Control:
	signal pressed

	var e := {}
	var burst := 0.0        # the seal's flash, 1 → 0
	var t := 0.0
	var ph := 0.0
	var body: Control
	var glow: Control
	var _gone := false
	var _done := false      # sealed

	func setup(of: Dictionary) -> void:
		e = of
		ph = randf() * TAU
		size = Vector2(D, D)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		body = Control.new()
		body.size = size
		body.pivot_offset = size / 2.0
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(body)
		# the halo behind it: light added onto the mine
		glow = Control.new()
		glow.material = FxLayer.add_material()
		glow.size = size
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.draw.connect(_draw_glow)
		body.add_child(glow)
		var ring := TextureRect.new()
		ring.texture = Kit.tex("ring")
		ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ring.stretch_mode = TextureRect.STRETCH_SCALE
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		ring.size = size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(ring)
		# the icon, its drawing fitted into the ring's window: its outline's middle on the medallion's, its farthest
		# point just inside the brass
		var tex := Kit.tex_at(Awards.DIR + String(e.icon) + ".png")
		var f := AwardsRail.fit(tex)
		var k := D * HOLE * 0.96 / float(f[1])
		var pic := TextureRect.new()
		pic.texture = tex
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		pic.size = tex.get_size() * k
		pic.position = size / 2.0 - (f[0] as Vector2) * k
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(pic)
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.size = size
		b.button_down.connect(func(): _squeeze(0.9))
		b.button_up.connect(func(): _squeeze(1.0))
		b.pressed.connect(func():
			if not _done and not _gone: pressed.emit())
		add_child(b)

	var _sq: Tween
	func _squeeze(to: float) -> void:
		if _done: return
		if _sq: _sq.kill()
		_sq = create_tween()
		_sq.tween_property(body, "scale", Vector2.ONE * to, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	## in from beyond the screen's edge
	func enter(wait: float) -> void:
		var x := position.x
		position.x = x + 96.0
		modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(wait)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(self, "position:x", x, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func move_to(at: Vector2) -> void:
		if position.distance_to(at) < 0.5 or _gone: return
		# (once the claimed one above has left)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(self, "position", at, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func leave() -> void:
		_gone = true
		var tw := create_tween()
		tw.tween_property(self, "position:x", position.x + 96.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(queue_free)

	func _process(dt: float) -> void:
		t += dt
		glow.queue_redraw()

	## the halo: a soft light behind the ring, breathing (gone under the seal, but for the seal's own flash)
	func _draw_glow() -> void:
		var c := size / 2.0
		if not _done:
			var pulse := 0.5 + 0.5 * sin(t * 2.2 + ph)
			var r := D * (0.98 + 0.1 * pulse)
			glow.draw_texture_rect(FxLayer.puff(), Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.76, 0.3, 0.45 + 0.4 * pulse))
		if burst > 0.0:
			var r2 := D * (0.7 + 0.7 * (1.0 - burst))
			glow.draw_texture_rect(FxLayer.puff(), Rect2(c - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1.0, 0.9, 0.6, burst))
