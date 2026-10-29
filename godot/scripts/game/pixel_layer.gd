class_name PixelLayer
extends Control
## Something drawn live (a bent strip, a curve) on the boss' 1-pt grid: drawn into a small SubViewport the size of the
## layer in points, smoothly sampled there, and shown with nearest filtering - so on a 3x screen it is chunky pixels
## like the boss' own pictures, and a strip bent hard stays clean pixels instead of a nearest-sampled mess.
## The caller draws in its own coordinates: `origin` is where its (0, 0) lies in the layer.

var vp: SubViewport
var canvas: Node2D

static func make(sz: Vector2, draw: Callable, origin := Vector2.ZERO) -> PixelLayer:
	var l := PixelLayer.new()
	l.size = sz
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vp = SubViewport.new()
	l.vp.size = Vector2i(ceili(sz.x), ceili(sz.y))
	l.vp.transparent_bg = true
	l.vp.disable_3d = true
	l.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	l.vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	l.canvas = Node2D.new()
	l.canvas.position = origin
	l.canvas.draw.connect(draw.bind(l.canvas))
	l.vp.add_child(l.canvas)
	l.add_child(l.vp)
	var view := TextureRect.new()
	view.texture = l.vp.get_texture()
	view.size = sz
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.add_child(view)
	return l

func redraw() -> void:
	canvas.queue_redraw()
