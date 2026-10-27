class_name KitLantern
extends Control
## The old miner's lantern hanging inside a window's top-left corner: a brass hook on the frame's rim, a short chain,
## the lantern swinging under it like a pendulum nudged by draughts. The flame flickers: the glass brightens and dims
## unevenly, a warm halo breathes round it and a faint pool of light on the slate follows the swing.

const LINKS := 4
const LINK := 5.0          # one chain link, points
var height := 60.0
var _t := randf() * 10.0
var _tex: Texture2D
var _glow: Texture2D

func _init(h := 60.0) -> void:
	height = h
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tex = Kit.tex("icons/lantern")
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.3, Color(1, 1, 1, 0.42))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 128
	gt.height = 128
	_glow = gt

func _process(dt: float) -> void:
	_t += dt
	queue_redraw()

## how bright the flame is now, ~0.7..1: slow breathing, a quicker waver and now and then a short dip
func _flame() -> float:
	var f := 0.86 + 0.07 * sin(_t * 2.3) + 0.05 * sin(_t * 7.1 + 1.3) + 0.03 * sin(_t * 13.7)
	var dip := maxf(0.0, sin(_t * 0.9 + 2.0)) ** 24
	return f - 0.18 * dip

func _draw() -> void:
	# the swing: a slow pendulum and a smaller second beat, as if a draught catches it
	var a := 0.075 * sin(_t * 1.7) + 0.03 * sin(_t * 2.9 + 0.7)
	var f := _flame()
	var w := height * _tex.get_width() / _tex.get_height()
	var chain := LINKS * LINK
	var rot := Transform2D(a, Vector2.ZERO)
	# the lantern's ring sits at 0.66 of its width; its glass and flame at (0.60, 0.56)
	var top := Vector2(-w * 0.66, chain)
	var glass := rot * (top + Vector2(w * 0.6, height * 0.56))
	# the pool of light on the slate, then the hook, the chain and the lantern swinging from the hook
	draw_texture_rect(_glow, Rect2(glass - Vector2(150, 150), Vector2(300, 300)), false, Color(1.0, 0.7, 0.32, 0.2 * f))
	var brass := Color("#c99a4a")
	var dark := Color("#2a1a08")
	draw_arc(Vector2(0, -1), 3.2, PI * 0.05, PI * 0.95, 10, dark, 2.6, true)
	draw_arc(Vector2(0, -1), 3.2, PI * 0.05, PI * 0.95, 10, brass, 1.4, true)
	draw_set_transform_matrix(rot)
	for i in LINKS:
		var c := Vector2(0, i * LINK + LINK * 0.5)
		var r := Vector2(1.6, LINK * 0.62) if i % 2 == 0 else Vector2(0.7, LINK * 0.62)
		_ellipse(c, r + Vector2(0.8, 0.8), dark, 1.6)
		_ellipse(c, r, brass, 1.0)
	draw_texture_rect(_glow, Rect2(top + Vector2(w * 0.6, height * 0.56) - Vector2(height, height) * 0.7, Vector2(height, height) * 1.4), false, Color(1.0, 0.78, 0.4, 0.55 * f))
	draw_texture_rect(_tex, Rect2(top, Vector2(w, height)), false, Color(0.82 + 0.18 * f, 0.8 + 0.16 * f, 0.76 + 0.1 * f))
	# the flame itself brightening and dimming behind the glass
	draw_texture_rect(_glow, Rect2(top + Vector2(w * 0.6, height * 0.56) - Vector2(9, 12), Vector2(18, 24)), false, Color(1.0, 0.86, 0.5, 0.75 * f))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _ellipse(c: Vector2, r: Vector2, col: Color, wd: float) -> void:
	var pts := PackedVector2Array()
	for k in 13:
		var t := TAU * k / 12.0
		pts.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	draw_polyline(pts, col, wd, true)
