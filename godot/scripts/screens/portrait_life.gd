class_name PortraitLife
extends Node2D
## The live touch on the top bar's portrait frame, the mine's boss in small, as on his fight's own frame: the Poloz'
## tail hangs out from under the frame's lower left corner, its tip curling; one of the Mistress' lizards runs round
## the frame, stops, looks about and runs on; the Kraken's arm lies along the top bar from the frame's left edge and
## hangs down the right bar, groping. Each is its boss' own drawing bent live (Bend), gentle bends only.

var id := ""
var f := 72.0                # the frame's size, pt
var strip: Texture2D
var _t := 0.0

static func make(boss: String, size: float) -> PortraitLife:
	var p := PortraitLife.new()
	p.id = boss
	p.f = size
	var path: String = {poloz = "res://assets/boss/poloz/kit/straight_h.png",
		mistress = "res://assets/boss/mistress/lizard_strip.png",
		kraken = "res://assets/boss/kraken/arm_xs.png"}.get(boss, "")
	if path != "" and ResourceLoader.exists(path): p.strip = load(path)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.material = BoardSprites.plain_material()
	return p

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

func _draw() -> void:
	if strip == null: return
	match id:
		"poloz": _tail()
		"mistress": _lizard()
		"kraken": _arm()

## the frame's bars' middle line, a square loop clockwise from the top left; `s` along it (pt) -> point and direction
func _loop(s: float) -> Array:
	var m := f * 0.13
	var side := f - 2.0 * m
	s = fposmod(s, side * 4.0)
	var k := mini(int(s / side), 3)
	var e := s - k * side
	var corners := [Vector2(m, m), Vector2(f - m, m), Vector2(f - m, f - m), Vector2(m, f - m)]
	var dirs := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	return [corners[k] + dirs[k] * e, dirs[k]]

## the serpent's tail: out from under the lower left corner, hanging down below the frame and swaying, its tip
## curling in under it and uncurling (outside the frame: on it, it would melt into the serpent the frame is made of)
func _tail() -> void:
	var m := f * 0.13
	var ph := _t * 0.8
	var curl := 0.5 + 0.5 * sin(ph)
	var pts := Bend.chain(Vector2(m * 1.3, f - m * 1.3), f * 0.55, 24, func(q: float) -> float:
		return PI * 0.58 + 0.15 * sin(ph * 0.6) - pow(q, 1.5) * (1.0 + 2.0 * curl) + 0.1 * q * sin(ph * 2.3 - q * 4.0))
	# the kit's bar has its body in the middle of its height: only those rows, so the width is the body's
	var hw := f * 0.1
	Bend.draw(self, pts, func(q: float) -> float: return hw * (1.0 - 0.7 * q), strip, 0.0, 0.16, false, Color.WHITE, 11.0 / 42.0, 31.0 / 42.0)

## a lizard running round the frame: a dash, a stop with its head turning, a dash; its body waves as it runs
func _lizard() -> void:
	var cycle := 5.0
	var c := fposmod(_t, cycle)
	var run := c < 3.2
	var s := (floorf(_t / cycle) * 3.2 + minf(c, 3.2)) * f * 0.42
	var ln := f * 0.4
	var body := PackedVector2Array()
	for i in 9:
		body.append(_loop(s - ln + ln * i / 8.0)[0])
	var wave := (1.0 if run else 0.25) * f * 0.02
	var ph := _t * (14.0 if run else 3.0)
	for i in body.size():
		var q := i / 8.0
		var d := (body[mini(i + 1, 8)] - body[maxi(i - 1, 0)]).normalized()
		body[i] += d.orthogonal() * wave * sin(q * TAU * 1.1 - ph) * (1.0 - q * 0.5)
	var hw := ln * float(strip.get_height()) / float(strip.get_width()) * 0.5
	var shadow := PackedVector2Array()
	for p in body: shadow.append(p + Vector2(1, 1))
	Bend.draw(self, shadow, func(_q: float) -> float: return hw, strip, 0.0, 1.0, false, Color(0.02, 0.04, 0.03, 0.5))
	Bend.draw(self, body, func(_q: float) -> float: return hw, strip)

## his arm along the whole top bar - its cut root end on the frame's left edge, as if it comes round from behind -
## over the upper right corner and down beside the frame, off its right bar, reaching and drawing back, its tip groping
func _arm() -> void:
	# the frame picture (kraken_frame.py avatar): 108 pt with 30 of room round a 48-pt window, its bars 14 thick
	# (AVATAR_BAR) - the outer edge 16 pt in, the bars' middle 23 pt in
	var edge := f * 16.0 / 108.0
	var mid := f * 23.0 / 108.0
	# along the top a little over the bar's middle; round the corner it goes off the frame and hangs beside it
	var top := mid - f * 0.06
	var out_x := f - edge + f * 0.09
	var ctrl := PackedVector2Array([Vector2(edge, top), Vector2(f * 0.45, top), Vector2(f - edge, top + 1.0),
		Vector2(out_x, f * 0.3), Vector2(out_x + f * 0.01, f * 0.62), Vector2(out_x + f * 0.05, f * 0.95)])
	var line := Bend.smooth(ctrl, 8)
	var full := Bend.length(line)
	# the root stays at the edge; only the hanging end reaches and draws back
	var out := full * (0.9 + 0.07 * sin(_t * 0.6) + 0.03 * sin(_t * 1.7))
	var pts := Bend.sample(line, 0.0, out, 36)
	var n := pts.size()
	for i in n:
		var q := i / float(n - 1)
		var d := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var hang := smoothstep(0.55, 1.0, q)
		pts[i] += d.orthogonal() * (sin(q * 7.0 - _t * 2.0) * f * 0.012 * hang + pow(q, 3.0) * f * 0.05 * sin(_t * 1.1))
	# his arm's own drawing, laid on the grid at this size (art/boss/export_kraken.py: arm_xs), stretched along the bar
	var hw := float(strip.get_height()) * 0.5 * f / 72.0
	Bend.draw(self, pts, func(_q: float) -> float: return hw, strip, 0.0, out / full)
