class_name Atlas
extends Control
## The atlas of the world (docs/collection.md): what you know, not what you own. Three vertical screens:
## the mines as banners grouped by world → one mine: its header (boss trophy, legend, progress, seals) and a grid
## of its species → a species: the best find of it ever, live, with a fact and the records. A species not found
## yet is the black silhouette of its own shape. Stones are drawn in a small transparent studio (like the mine's
## niches), so a tile can put any stone on its own tinted ground, or black it out.

signal go(screen: String)
## the beaten boss of mine `a` fought again (Main switches the mine for the fight)
signal replay(a: int)

## which screen opens: -1 the mines, N a mine; -2 decides (straight into the mine while only one is open)
static var start_area := -2
## a banner's width to its height
const BANNER_K := 3.9

## a line of legend under each mine's name
const LEGEND := [
	"Where the Great Poloz crawls, the gold lies after him",
	"The Mistress of the Copper Mountain wears a dress of malachite",
	"Something vast sleeps under the whalers' bones",
]
## one real line about each species
const FACTS := {
	quartz = "SiO₂ · hardness 7 · the Urals' miners took clear crystals for ice that never melts",
	calcite = "CaCO₃ · hardness 3 · fizzes in acid and doubles whatever you look at through it",
	pyrite = "FeS₂ · hardness 6–6.5 · fool's gold: it strikes sparks off steel, real gold never does",
	fluorite = "CaF₂ · hardness 4 · gave its name to fluorescence: it glows under ultraviolet",
	amethyst = "SiO₂ with iron · hardness 7 · the Greeks drank from it so as not to get drunk",
	smoky = "SiO₂ · hardness 7 · darkened by the natural radiation of the granite it grew in",
	garnet = "Fe₃Al₂(SiO₄)₃ · hardness 7–7.5 · the Ural almandine grows as twelve-sided balls",
	gold = "Au · hardness 2.5–3 · the Urals' first gold was found in 1745 by a peasant, Yerofei Markov",
	malachite = "Cu₂(CO₃)(OH)₂ · hardness 3.5–4 · whole halls of the Winter Palace are faced with Ural malachite",
	azurite = "Cu₃(CO₃)₂(OH)₂ · hardness 3.5–4 · ground into blue paint for centuries; turns into malachite with time",
	chrysocolla = "copper silicate · hardness 2–4 · its Greek name means 'gold glue': used to solder gold",
	nativecu = "Cu · hardness 2.5–3 · pure copper grown into branching trees in the rock",
	beryl = "Be₃Al₂Si₆O₁₈ · hardness 7.5–8 · the stone that becomes emerald, aquamarine or heliodor",
	cuprite = "Cu₂O · hardness 3.5–4 · deep red copper oxide; turns dull in light",
	aquamarine = "beryl with iron · hardness 7.5–8 · 'sea water': sailors carried it against storms",
	emerald = "beryl with chromium · hardness 7.5–8 · the Ural emerald mines were found in 1830 under a tree root",
	ammonite = "a shell of the Mesozoic seas · they vanished with the dinosaurs, 66 million years ago",
	gypsum = "CaSO₄·2H₂O · hardness 2 · selenite: moon-stone, you can scratch it with a fingernail",
	celestine = "SrSO₄ · hardness 3–3.5 · sky-blue; strontium in it burns red in fireworks",
	petrified_wood = "wood turned to stone · silica took the place of every cell, rings and all",
	amber = "fossil resin · 40 million years old in the Baltic · rubbed on wool it pulls at straws",
	opal = "SiO₂·nH₂O · hardness 5.5–6.5 · its fire is light bent by tiny spheres of silica",
	fulgurite = "fused sand · a lightning strike's path frozen into glass",
	flower_quartz = "a flower caught in quartz",
	ruby = "Al₂O₃ with chromium · hardness 9 · corundum: only diamond is harder",
	sapphire = "Al₂O₃ · hardness 9 · corundum of every colour but red",
	diamond = "C · hardness 10 · the hardest thing in nature",
}

var area := -1
var content: VBoxContainer
var scroll: ScrollContainer

static var _cut := {}          # stone key -> its picture on a transparent ground
static var _studio: SpecStudio
static var _queue := []
static var _busy := false

func _ready() -> void:
	size = get_viewport_rect().size
	area = start_area
	if area == -2:
		area = Save.area() if Save.area() == 0 else -1
	start_area = -2
	var bg := SlateBg.new()
	bg.size = size
	add_child(bg)
	render()
	Coach.note(self, "c_atlas", "The Scholar's atlas. Every kind of stone you find gets a page - your best one, the records, where it lies. Grey shapes are still to find.")

func render() -> void:
	for ch in get_children():
		if ch is SlateBg: continue
		ch.queue_free()
	var root := VBoxContainer.new()
	root.size = size
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10 + int(UI.safe_top()))
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)
	col.add_child(Chrome.top_bar())
	scroll = UI.scroller()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	if area < 0:
		_mines()
	else:
		_mine(area)
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(0, 16)
	content.add_child(tail)
	root.add_child(Chrome.nav_bar("atlas", func(id: String): go.emit(id)))

static func found_in(a: int) -> int:
	var n := 0
	for id in Data.AREAS[a].pool:
		if Save.d.atlas.has(id): n += 1
	return n

static func is_open(a: int) -> bool:
	return a <= Save.area()

# ---------------------------------------------------------------- the mines

func _mines() -> void:
	var have := 0
	var all := 0
	for a in Data.AREAS.size():
		have += found_in(a)
		all += Data.AREAS[a].pool.size()
	content.add_child(_section("EARTH", "%d/%d species" % [have, all]))
	# the banners close together, one shelf: the mines in the game (a closed one by name, dark, locked), then one still to come
	var shelf := VBoxContainer.new()
	shelf.add_theme_constant_override("separation", 5)
	for a in Data.AREAS.size():
		shelf.add_child(_banner(a))
	shelf.add_child(_banner(-1))
	content.add_child(shelf)
	content.add_child(_section("???", "another world"))
	content.add_child(_banner(-1))

func _section(t: String, sub: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Kit.label(t, 15, UI.display, Kit.AMBER))
	h.add_child(Kit.label("· " + sub, 12, UI.body_bold, Kit.DIM))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 6)
	m.add_child(h)
	return m

## a mine as a strip of its own picture: name, progress, the boss's trophy (or an empty socket); a = -1: unknown
func _banner(a: int) -> Control:
	var open := a >= 0 and is_open(a)
	var b := _picture_box(a, (size.x - 24.0) / BANNER_K, 0.0 if open else 0.45)
	var over := Control.new()
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(over)
	var t := VBoxContainer.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	t.grow_vertical = Control.GROW_DIRECTION_BEGIN
	t.offset_left = 11
	t.offset_bottom = -7
	t.add_theme_constant_override("separation", 1)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(t)
	if open:
		var nm := _shadowed(String(Data.AREAS[a].n), 19)
		t.add_child(nm)
		var n := found_in(a)
		var all: int = Data.AREAS[a].pool.size()
		t.add_child(_progress("%d/%d" % [n, all], float(n) / maxf(1.0, all), (size.x - 24.0) * 0.3, 11))
	elif a >= 0:
		t.add_child(_shadowed(String(Data.AREAS[a].n), 19, Kit.DIM))
	else:
		t.add_child(_shadowed("???", 19, Kit.DIM))
	var em := _emblem(_sign(a, open), 0.66, b)
	over.add_child(em)
	if open and Data.AREAS[a].has("boss"):
		em.mouse_filter = Control.MOUSE_FILTER_STOP
		em.gui_input.connect(func(e: InputEvent): if _tapped(e):
			em.accept_event()
			_boss_card(a))
	if open:
		b.gui_input.connect(func(e: InputEvent): if _tapped(e):
			Sfx.play("tab")
			area = a
			render())
	return b

static func _tapped(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and not e.pressed)

## a rounded box with a slice of the mine's picture (a = -1: bare rock), darkened to the left for text, a brass rim
func _picture_box(a: int, h: float, dark: float) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, h)
	box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	# the picture is clipped to the frame's opening (a little inside its rim, rounded like it), so none of it shows past the brass
	var hole := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: hole.add_theme_constant_override("margin_" + side, 2)
	hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#15110d")
	st.set_corner_radius_all(13)
	st.anti_aliasing = true
	inner.add_theme_stylebox_override("panel", st)
	inner.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hole.add_child(inner)
	box.add_child(hole)
	var pic := Control.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tx: Texture2D = load("res://assets/atlas/banner_%d.png" % a) if a >= 0 and ResourceLoader.exists("res://assets/atlas/banner_%d.png" % a) else load("res://assets/atlas/banner_unknown.png")
	pic.draw.connect(func():
		var s := pic.size
		var src := _cover(tx.get_size(), s)
		pic.draw_texture_rect_region(tx, Rect2(Vector2.ZERO, s), src, Color(1, 1, 1) if dark < 0.3 else Color(0.62, 0.62, 0.64))
		# a shade low on the left under the name
		var l := Color(0.03, 0.02, 0.015, 0.75)
		var r := Color(0.03, 0.02, 0.015, 0.0)
		pic.draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.35), Vector2(s.x * 0.6, s.y * 0.35), Vector2(s.x * 0.6, s.y), Vector2(0, s.y)]), PackedColorArray([r, r, r, l]))
		# a vignette: the edges sink into the frame
		var e := Color(0.02, 0.015, 0.01, 0.5)
		var o := Color(0.02, 0.015, 0.01, 0.0)
		var vx := s.x * 0.12
		var vy := s.y * 0.3
		pic.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vx, 0), Vector2(vx, s.y), Vector2(0, s.y)]), PackedColorArray([e, o, o, e]))
		pic.draw_polygon(PackedVector2Array([Vector2(s.x - vx, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x - vx, s.y)]), PackedColorArray([o, e, e, o]))
		pic.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, vy), Vector2(0, vy)]), PackedColorArray([e, e, o, o]))
		pic.draw_polygon(PackedVector2Array([Vector2(0, s.y - vy), Vector2(s.x, s.y - vy), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([o, o, e, e]))
		if dark > 0.0:
			pic.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.015, 0.01, dark)))
	inner.add_child(pic)
	# the rim: the kit's window frame (calm brass, riveted corner brackets), drawn smaller than on a window
	var rim := Panel.new()
	var rs := KitBox.new()
	rs.tex = load("res://assets/atlas/banner_frame.png")   # the window frame without its inner slate shade (looked like fog on a picture)
	rs.margin = Vector4(86, 86, 86, 86)
	rs.s = 4.4
	rs.tile = false
	rs.modulate = Color.WHITE if a >= 0 else Color(0.6, 0.58, 0.55)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rim)
	return box

## the part of a picture of size `ts` that covers `s` (cropped at the sides or top and bottom; fy: where vertically)
static func _cover(ts: Vector2, s: Vector2, fy := 0.5) -> Rect2:
	if ts.x / ts.y > s.x / s.y:
		var w := ts.y * s.x / s.y
		return Rect2((ts.x - w) / 2.0, 0, w, ts.y)
	var h := ts.x * s.y / s.x
	return Rect2(0, (ts.y - h) * fy, ts.x, h)

static func _mine_dir(a: int) -> String:
	return ["old_adit", "copper_mountain", "whalebone_cove"][clampi(a, 0, 2)]

## the banner's emblem: the beaten boss's sign, an empty socket while the boss stands, a lock on a mine not reached
static func _sign(a: int, open: bool) -> String:
	if a < 0 or not open: return "lock"
	if a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]):
		return ["poloz", "mistress", "kraken", "brontes"][clampi(a, 0, 3)]
	return "empty"

## the boss's sign tapped: fight a beaten boss again (no hoard this time), or a word on where it waits
func _boss_card(a: int) -> void:
	var B: Dictionary = Data.AREAS[a].boss
	Sfx.play("open")
	if not bool(Save.d.boss_won[a]):
		Ov.toast("%s waits below %s" % [B.n, Data.AREAS[a].n])
		return
	var v := Ov.card(330)
	v.add_child(UI.title(String(B.n), 22))
	v.add_child(Ov.text("Fight again? A life, like any level. Coins for the win, but the hoard was yours the first time.", 13))
	v.add_child(Ov.btn("Fight again", "red", func():
		Ov.close()
		replay.emit(a)))
	v.add_child(Ov.btn("Not now", "glass", func(): Ov.close()))

## the emblem (assets/atlas/emblem_<sign>.png, drawn by GPT) at the right of `box`, `k` of its height
func _emblem(sign: String, k: float, box: Control) -> Control:
	var e := TextureRect.new()
	e.texture = load("res://assets/atlas/emblem_%s.png" % sign)
	e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.resized.connect(func():
		var d := box.size.y * k
		e.size = Vector2(d, d)
		e.position = Vector2(box.size.x - d - box.size.y * 0.16, (box.size.y - d) / 2.0))
	return e

static func _shadowed(t: String, sz: int, col := Kit.CREAM) -> Label:
	var l := Kit.label(t, sz, UI.display, col)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

## "4/8" and a thin brass line
static func _progress(t: String, k: float, w: float, fs := 13) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Kit.label(t, fs, UI.body_bold, Kit.CREAM))
	var bh := 5.0
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(w, bh)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.02, 0.015, 0.01, 0.7)
	track.border_color = Color(Kit.AMBER, 0.25)
	track.set_border_width_all(1)
	track.set_corner_radius_all(int(bh))
	track.anti_aliasing = true
	var fill := StyleBoxFlat.new()
	fill.bg_color = Kit.AMBER
	fill.set_corner_radius_all(int(bh))
	fill.anti_aliasing = true
	bar.draw.connect(func():
		bar.draw_style_box(track, Rect2(-1, -1, w + 2, bh + 2))
		if k > 0.0:
			bar.draw_style_box(fill, Rect2(0, 0, maxf(bh, w * clampf(k, 0, 1)), bh)))
	h.add_child(bar)
	return h

# ---------------------------------------------------------------- one mine

func _mine(a: int) -> void:
	var A: Dictionary = Data.AREAS[a]
	content.add_child(_stage(a))
	var leg := Kit.label(LEGEND[a] if a < LEGEND.size() else "", 13, UI.body, Color(Kit.CREAM, 0.85))
	leg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(leg)
	var n := found_in(a)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(_progress("%d/%d species" % [n, A.pool.size()], float(n) / maxf(1.0, A.pool.size()), 120))
	row.add_child(_seals(a))
	content.add_child(row)
	# the species of this mine, the common ones first
	var ids: Array = A.pool.keys()
	ids.sort_custom(func(x, y): return int(Data.SP[x].r) < int(Data.SP[y].r) or (int(Data.SP[x].r) == int(Data.SP[y].r) and float(A.pool[x]) > float(A.pool[y])))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var w := (size.x - 24 - 16) / 3.0
	for id in ids:
		grid.add_child(_tile(String(id), w))
	content.add_child(grid)

## the stage for the boss's trophy (the same for every mine), fading into the slate; on it the name and the way back
const STAGE_H := 236.0
const STAGE_RING := Vector2(0.5, 0.6)   # the ring's middle in the stage picture (share of its size)
func _stage(a: int) -> Control:
	var st := Control.new()
	st.custom_minimum_size = Vector2(0, STAGE_H)
	var boss: Dictionary = Data.AREAS[a].get("boss", {})
	var won: bool = a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]) and boss.size() > 0
	# one stage for every mine (GPT, art/ui_redesign/collection/gen_stage.sh): the ring dark and cold while the boss
	# stands, lit gold with the trophy on it once beaten
	var tx: Texture2D = load("res://assets/atlas/stage_lit.png" if won else "res://assets/atlas/stage_dim.png")
	var trophy: Texture2D = load("res://assets/boss/%s/idle_0.png" % boss.id) if won and ResourceLoader.exists("res://assets/boss/%s/idle_0.png" % boss.id) else null
	st.draw.connect(func():
		var s2 := st.size
		var ts := tx.get_size()
		var cv := _cover(ts, s2)
		# the picture as a grid whose corners carry the fade: no shader, every phone draws it the same
		const NX := 8
		const NY := 10
		for iy in NY:
			for ix in NX:
				var pts := PackedVector2Array()
				var uvs := PackedVector2Array()
				var cols := PackedColorArray()
				for q in [Vector2(ix, iy), Vector2(ix + 1, iy), Vector2(ix + 1, iy + 1), Vector2(ix, iy + 1)]:
					var u := Vector2(q.x / NX, q.y / NY)
					pts.append(u * s2)
					uvs.append((cv.position + u * cv.size) / ts)
					var fade := smoothstep(1.0, 0.7, u.y) * smoothstep(0.0, 0.08, u.y) * smoothstep(0.0, 0.08, u.x) * smoothstep(1.0, 0.92, u.x)
					cols.append(Color(1, 1, 1, fade))
				st.draw_polygon(pts, cols, uvs, tx)
		# the trophy stands in the middle of the ring
		if trophy:
			var tsz := trophy.get_size() * (150.0 / trophy.get_size().x)
			var foot := (STAGE_RING * ts - cv.position) / cv.size * s2
			# the fight's picture is cut off at its edges: they fade, so it rises out of the ring's light
			var tr := Rect2(foot - Vector2(tsz.x / 2.0, tsz.y * 0.8), tsz)
			for iy in 6:
				for ix in 6:
					var pts := PackedVector2Array()
					var uvs := PackedVector2Array()
					var cols := PackedColorArray()
					for q in [Vector2(ix, iy), Vector2(ix + 1, iy), Vector2(ix + 1, iy + 1), Vector2(ix, iy + 1)]:
						var u: Vector2 = q / 6.0
						pts.append(tr.position + u * tr.size)
						uvs.append(u)
						cols.append(Color(1, 1, 1, smoothstep(1.0, 0.6, u.y) * smoothstep(0.0, 0.12, u.x) * smoothstep(1.0, 0.88, u.x)))
					st.draw_polygon(pts, cols, uvs, trophy))
	st.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var back := Kit.button("", "sq_dark", 16, 2.0)
	back.custom_minimum_size = Vector2(38, 38)
	back.position = Vector2(6, 8)
	back.size = Vector2(38, 38)
	var chev := Control.new()
	chev.set_anchors_preset(Control.PRESET_FULL_RECT)
	chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chev.draw.connect(func():
		var cc := chev.size / 2.0 + Vector2(-1, 0)
		chev.draw_polyline(PackedVector2Array([cc + Vector2(4, -8), cc + Vector2(-4, 0), cc + Vector2(4, 8)]), Kit.CREAM, 3.0, true))
	back.add_child(chev)
	back.pressed.connect(func():
		Sfx.play("tab")
		area = -1
		render())
	st.add_child(back)
	var nm := _shadowed(String(Data.AREAS[a].n), 26)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	nm.offset_top = 10
	nm.offset_left = 48
	nm.offset_right = -48
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(nm)
	return st

## the mine's seals: every species found, the boss beaten, a legendary found
func _seals(a: int) -> Control:
	var pool: Dictionary = Data.AREAS[a].pool
	var legend := false
	for id in pool:
		if Save.d.atlas.has(id) and bool(Save.d.atlas[id].get("legend", false)): legend = true
	var lit := [found_in(a) == pool.size(), a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]), legend]
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var on: bool = lit[i]
		var s := Control.new()
		s.custom_minimum_size = Vector2(24, 24)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.draw.connect(func():
			var c := Vector2(12, 12)
			var col := Kit.AMBER if on else Color(0.45, 0.42, 0.38)
			s.draw_circle(c, 11, Color(0.2, 0.14, 0.06, 0.9) if on else Color(0.06, 0.05, 0.04, 0.85))
			s.draw_arc(c, 11, 0, TAU, 32, Color(col, 0.9 if on else 0.5), 1.5, true)
			var g := Color(col, 1.0 if on else 0.45)
			if i == 0:   # a crystal: every species
				s.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4.5, -1), c + Vector2(0, 6), c + Vector2(-4.5, -1)]), g)
			elif i == 1:   # a crown: the boss
				s.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 4), c + Vector2(-6, -3), c + Vector2(-3, 0), c + Vector2(0, -5),
					c + Vector2(3, 0), c + Vector2(6, -3), c + Vector2(6, 4)]), g)
			else:   # a star: a legendary
				var pts := PackedVector2Array()
				for k in 10:
					var an := -PI / 2 + k * PI / 5
					pts.append(c + Vector2(cos(an), sin(an)) * (6.5 if k % 2 == 0 else 2.8))
				s.draw_colored_polygon(pts, g))
		h.add_child(s)
	return h

## a species: its best stone on its own tinted ground, or the black silhouette of its shape
func _tile(id: String, w: float) -> Control:
	var e: Dictionary = Save.d.atlas.get(id, {})
	var got := e.has("best")
	var tier: int = int(e.best.tier) if got else int(Data.SP[id].r)
	var rc := Data.rarity_color(tier)
	var b := PanelContainer.new()
	b.custom_minimum_size = Vector2(w, w * 1.08)
	var spc := Data.sp_color(id)
	var st := StyleBoxFlat.new()
	st.bg_color = spc.darkened(0.82) if got else Color("#1d1914")
	st.border_color = Color(rc.lerp(Kit.AMBER, 0.5), 0.75) if got else Color("#3a332a")
	st.set_border_width_all(2 if got else 1)
	st.set_corner_radius_all(10)
	st.anti_aliasing = true
	b.add_theme_stylebox_override("panel", st)
	b.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var glow := Control.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.draw.connect(func():
		var c := glow.size * Vector2(0.5, 0.58)
		var tint := spc if got else Color(0.55, 0.5, 0.42)
		GemArt.radial_disc(glow, c, glow.size.x * 0.62, Color(tint, 0.3 if got else 0.12), Color(tint, 0.1 if got else 0.04), Color(tint, 0.0)))
	b.add_child(glow)
	var img := TextureRect.new()
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not got:
		img.modulate = Color(0.015, 0.012, 0.01)
	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_top", int(w * 0.24))
	pm.add_theme_constant_override("margin_bottom", int(w * (0.04 if got else 0.18)))
	for side in ["left", "right"]: pm.add_theme_constant_override("margin_" + side, int(w * 0.08))
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pm.add_child(img)
	b.add_child(pm)
	cutout(Spec.of_stone(e.best) if got else _sample(id), func(t: Texture2D): if is_instance_valid(img): img.texture = t)
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", 2)
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 9)
	tm.add_theme_constant_override("margin_top", 7)
	tm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tm.add_child(txt)
	if got:
		var nl := Kit.label(String(Data.SP[id].n), 12, UI.body_bold, Kit.CREAM)
		nl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		nl.add_theme_constant_override("shadow_offset_y", 1)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size = Vector2(w - 18, 0)
		txt.add_child(nl)
		var rule := ColorRect.new()
		rule.color = rc.lightened(0.15)
		rule.custom_minimum_size = Vector2(18, 1.5)
		rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		txt.add_child(rule)
	b.add_child(tm)
	if not got:
		var hint := Kit.label(String(Data.RAR[tier]), 10, UI.body_bold, Color(rc.lerp(Kit.DIM, 0.55), 0.85))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hm := Control.new()
		hm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hm.add_child(hint)
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_top = -22
		hint.offset_bottom = -6
		b.add_child(hm)
	b.gui_input.connect(func(ev: InputEvent): if _tapped(ev):
		if got:
			Sfx.play("open")
			_open_species(id)
		else:
			Ov.toast("Not found yet · %s" % Data.RAR[tier]))
	return b

## a stand-in stone of the species for its silhouette: the same one every time
static func _sample(id: String) -> Dictionary:
	var kind := "nugget" if id in Data.NUGGETY else "fossil" if Data.HABIT.get(id, "") == "fossil" else "crystal"
	return {seed = 7001 + absi(hash(id)) % 9000, sid = id, kind = kind, gi = 2, traits = [], legend = false, cut = ""}

# ---------------------------------------------------------------- a species

func _open_species(id: String) -> void:
	var e: Dictionary = Save.d.atlas[id]
	var best: Dictionary = e.best
	var v := Ov.card(350, Data.rarity_color(int(best.tier)))
	Reveal.stone_card(v, best, 380, func(): Ov.close())
	if FACTS.has(id):
		var f := Kit.label(FACTS[id], 12, UI.body, Kit.DIM)
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(f)
	var kept := 0
	var still := false
	for s in Save.d.coll:
		if s.sid == id: kept += 1
		if int(s.id) == int(best.id): still = true
	var ba := int(best.get("area", 0))
	var where := "Best found in %s, %d m" % [Data.AREAS[ba].n, Data.depth_m(ba, int(best.get("dl", 0)))]
	if not still: where += " · sold"
	var wl := Kit.label(where, 12, UI.body_bold, Kit.CREAM)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(wl)
	v.add_child(Kit.rule(260))
	var rec := HBoxContainer.new()
	rec.add_theme_constant_override("separation", 8)
	Reveal._stat(rec, "Found", str(int(e.n)))
	Reveal._stat(rec, "Heaviest", Stones.fmt_weight(int(e.max_g)))
	Reveal._stat(rec, "Most valuable", UI.fmt(int(e.max_v)), UI.GOLD)
	v.add_child(rec)
	var inv := Kit.button(("You have %d · Inventory ›" % kept) if kept else "None kept · Inventory ›", "btn_dark", 15, 4.0)
	inv.custom_minimum_size = Vector2(0, 44)
	inv.pressed.connect(func():
		Ov.close()
		go.emit("museum"))
	v.add_child(inv)

## for screenshots: ui=replay_first fights the first mine's boss again
func _replay_first() -> void:
	replay.emit(0)

## for screenshots: ui=open_best opens the first species found in the open mine
func _open_best() -> void:
	for id in Data.AREAS[maxi(area, 0)].pool:
		if Save.d.atlas.has(id):
			_open_species(String(id))
			return

# ---------------------------------------------------------------- pictures

## a stone rendered once on a transparent ground, cropped to it
static func cutout(o: Dictionary, cb: Callable) -> void:
	var key := Spec.key_of(o)
	if _cut.has(key):
		cb.call(_cut[key])
		return
	_queue.append([o, cb])
	if not _busy:
		_pump()

static func _pump() -> void:
	_busy = true
	if _studio == null:
		_studio = SpecStudio.make(256, Viewport.MSAA_4X, true)
		_studio.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		Spec.add_child(_studio.vp)
	while _queue.size():
		var item: Array = _queue.pop_front()
		var o: Dictionary = item[0]
		var cb: Callable = item[1]
		var key := Spec.key_of(o)
		if not _cut.has(key):
			var p: Node3D = await _studio.show_async(o)
			if p == null:
				continue
			p.rotation = Vector3(0.12, 0.6, 0)
			for i in 2:
				_studio.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				await RenderingServer.frame_post_draw
			var img := _studio.vp.get_texture().get_image()
			var used := img.get_used_rect()
			_studio.clear()
			if used.size.x < 3:
				continue
			_cut[key] = ImageTexture.create_from_image(img.get_region(used))
		if cb.is_valid():
			cb.call(_cut[key])
	_busy = false

## the game is closing: drop the pictures and the studio while the renderer is still up
static func release() -> void:
	_cut.clear()
	_queue.clear()
	if _studio:
		_studio.vp.queue_free()
		_studio = null

## the atlas's ground: the slate of the specimen card's info panel, tiled at its own scale, darkened toward the edges
class SlateBg extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# one big slate picture over the whole screen (GPT, art/ui_kit/gen_slate_big.sh; drawn dark at once, no filtering):
		# the 200 px tile repeated every 55 pt read as rows of stripes
		var pic := TextureRect.new()
		pic.texture = load("res://assets/ui/kit/slate_big.png")
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.modulate = Color(0.8, 0.78, 0.76)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.show_behind_parent = true
		add_child(pic)
	func _draw() -> void:
		var e := Color(0, 0, 0, 0.55)
		var m := Color(0, 0, 0, 0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x * 0.18, 0), Vector2(size.x * 0.18, size.y), Vector2(0, size.y)]), PackedColorArray([e, m, m, e]))
		draw_polygon(PackedVector2Array([Vector2(size.x * 0.82, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(size.x * 0.82, size.y)]), PackedColorArray([m, e, e, m]))
