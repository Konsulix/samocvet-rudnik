class_name AlbumCard
extends Control
## A species card in the atlas album (AtlasPages): face up - the specimen card in small (stone on a ground of its colour,
## name, rarity rule, a rim of rarity and brass, a soft glow round rare ones); face down - the card's back with the
## mine's medallion and where the species turns up. flip() turns it over (narrows to its edge, swaps, opens out, a
## flash of light). Drawn here; the stone is a picture from Atlas.cutout.

var id := ""
var open := true
var area := 0
var dl := 0
var got := false
var gone := false
var face := true
var stone: Texture2D
var _col := Color.WHITE
var _tier := 0
var _flash := 0.0
const BONES_RY := 0.46       # the bones back's recess, its middle down the card
static var _back: Texture2D
static var _bones: Texture2D   # a beast's skull: its own back, bones round the recess (art/ui_redesign/collection/gen_bone_back.sh)

func setup(sid: String, sz: Vector2, o: bool, a: int, d: int, g: bool, sold: bool) -> void:
	id = sid
	size = sz
	pivot_offset = sz / 2.0
	open = o
	area = a
	dl = d
	got = g
	gone = sold
	face = g
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e: Dictionary = Save.d.atlas.get(id, {})
	var bone := id.begins_with("beast_")
	_col = Color(0.55, 0.54, 0.52) if gone else (Stones.SKULL_COL.get(String(e.best.get("skin", "bone")) if got else "bone", Stones.SKULL_COL.bone) as Color) if bone else Data.sp_color(id)
	_tier = int(e.best.tier) if got else 2 if bone else int(Data.SP[id].r)

## a card's name: the species, or a beast's skull ("Wolf Skull")
static func name_of(id: String) -> String:
	if id.begins_with("beast_"): return "%s Skull" % String(SpecSkull.BEAST_N.get(id.substr(6), "Beast"))
	return String(Data.SP[id].n)

func set_stone(t: Texture2D) -> void:
	stone = t
	queue_redraw()

func flip() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		face = true
		_flash = 1.0
		Sfx.play("reveal_%d" % clampi(_tier, 0, 4))
		queue_redraw())
	tw.tween_property(self, "scale:x", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float):
		_flash = v
		queue_redraw(), 1.0, 0.0, 0.6)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if face: _face(r)
	else: _back_side(r)
	if _flash > 0.0:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 0.95, 0.85, 0.5 * _flash)
		st.set_corner_radius_all(9)
		draw_style_box(st, r)

func _face(r: Rect2) -> void:
	var rc := Data.rarity_color(_tier)
	# a soft glow of its rarity round a rare card
	if _tier >= 2 and not gone:
		for k in 4:
			var g := StyleBoxFlat.new()
			g.bg_color = Color(0, 0, 0, 0)
			g.border_color = Color(rc, 0.18 - k * 0.04)
			g.set_border_width_all(2)
			g.set_corner_radius_all(10 + k * 2)
			g.anti_aliasing = true
			draw_style_box(g, r.grow(2 + k * 2))
	var st := StyleBoxFlat.new()
	st.bg_color = _col.darkened(0.84)
	st.border_color = Color(rc.lerp(Kit.AMBER, 0.5), 0.85)
	st.set_border_width_all(2 if _tier >= 2 else 1)
	st.set_corner_radius_all(9)
	st.anti_aliasing = true
	draw_style_box(st, r)
	GemArt.radial_disc(self, size * Vector2(0.5, 0.58), size.x * 0.6, Color(_col, 0.32), Color(_col, 0.1), Color(_col, 0.0))
	if stone:
		var box := Rect2(Vector2(5, 22), size - Vector2(10, 27))
		var k := minf(box.size.x / stone.get_width(), box.size.y / stone.get_height())
		var s := stone.get_size() * k
		draw_texture_rect(stone, Rect2(box.get_center() - s / 2.0, s), false, Color(0.62, 0.62, 0.62) if gone else Color.WHITE)
	var f: Font = UI.body_bold
	var nm := name_of(id)
	var fs := 10
	while nm.length() > 3 and f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 12:
		nm = nm.substr(0, nm.length() - 2) + "…"
	draw_string(f, Vector2(7, 15), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.7))
	draw_string(f, Vector2(6, 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Kit.CREAM)
	draw_rect(Rect2(6, 18, 14, 1.5), rc.lightened(0.15))
	if gone:
		var t := "sold"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(f, Vector2((size.x - w) / 2.0, size.y - 6), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Kit.DIM)

func _back_side(r: Rect2) -> void:
	var bone := id.begins_with("beast_")
	if _back == null:
		var p := "res://assets/atlas/album/back.png"
		_back = load(p) if ResourceLoader.exists(p) else null
		_bones = load("res://assets/atlas/album/back_bones.png")
	var a := 1.0 if open else 0.55
	var bk := _bones if bone else _back
	if bk:
		draw_texture_rect(bk, r, false, Color(1, 1, 1, a))
	else:
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#16171b")
		st.border_color = Color(Kit.AMBER, 0.35)
		st.set_border_width_all(1)
		st.set_corner_radius_all(9)
		st.anti_aliasing = true
		draw_style_box(st, r)
	# the mine's medallion in the back's middle recess
	var em := AtlasBoard._emblem(Atlas._sign(area, open) if open else "lock")
	# in the back's round recess (its middle at 0.445 of the height, 0.54 of the width across)
	var d := size.x * 0.46
	var ry := BONES_RY if bone else 0.445
	draw_texture_rect(em, Rect2(Vector2((size.x - d) / 2.0, size.y * ry - d / 2.0), Vector2(d, d)), false, Color(1, 1, 1, 0.7 * a))
	if open:
		var f: Font = UI.body_bold
		var t := "from %d m" % Data.depth_m(area, dl)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(f, Vector2((size.x - w) / 2.0 + 1, size.y - 13), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2((size.x - w) / 2.0, size.y - 14), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Kit.AMBER, 0.85))
