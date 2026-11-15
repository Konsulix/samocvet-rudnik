class_name BossMedal
extends Control
## the boss's medallion in the window before its fight (Home._boss_panel): its sign as the atlas draws it once beaten
## (AtlasBoard._emblem), three sockets round it, a ruby in each difficulty beaten (AtlasBoard.rubies), the empty
## ones flaring red now and then — a ruby still to be won (as AtlasPages.Medallion)

const SIGNS := {0: "poloz", 1: "mistress", 2: "kraken", 3: "brontes", 7: "shubin"}
const FLASH_EVERY := 5.0
var a: int
var t := 0.0

func _init(area: int) -> void:
	a = area
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)
	var sign: String = SIGNS.get(a, "empty")
	if not ResourceLoader.exists("res://assets/atlas/emblem_%s.png" % sign) and not ResourceLoader.exists("res://assets/atlas/board/emblem_%s.png" % sign):
		sign = "empty"
	draw_texture_rect(AtlasBoard._emblem(sign), Rect2(o, Vector2(s, s)), false)
	var sg := s / 2.0
	var n := AtlasBoard.rubies(a)
	var h := sg * AtlasBoard.RUBY_S
	for i in 3:
		var an := -PI / 2.0 + TAU * i / 3.0
		var c := o + Vector2(sg, sg) + Vector2(cos(an), sin(an)) * sg * AtlasBoard.RUBY_R
		var tex := "res://assets/atlas/board/ruby_%d.png" % AtlasBoard.RUBY_CUT if i < n else "res://assets/atlas/board/socket.png"
		draw_texture_rect(AtlasBoard._pic(tex, 96), Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), false)
		if i >= n:
			var ft := fposmod(t + float(i) * 1.9 + 0.6, FLASH_EVERY)
			var f := smoothstep(0.0, 0.18, ft) * (1.0 - smoothstep(0.18, 1.1, ft))
			if f > 0.001:
				var pf := FxLayer.puff()
				var r1 := h * 2.2
				draw_texture_rect(pf, Rect2(c - Vector2(r1, r1), Vector2(r1, r1) * 2.0), false, Color(0.95, 0.12, 0.1, 0.55 * f))
				var r2 := h * 0.9
				draw_texture_rect(pf, Rect2(c - Vector2(r2, r2), Vector2(r2, r2) * 2.0), false, Color(1.0, 0.45, 0.4, 0.75 * f))
