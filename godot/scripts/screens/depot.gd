class_name Depot
extends Control
## The depot: machines that dig deeper in this mine, and kit that helps in every mine.
## The chosen machine stands on a lit stage, running; a strip of photos below picks another.

signal go(screen: String)

const DMACH := ["", "hammer", "rig", "tbm", "deep"]

var tab := "depth"
var sel := ""
var view: SpecView
var body: VBoxContainer

func _ready() -> void:
	size = get_viewport_rect().size
	var bg := DepotBg.new()
	bg.size = size
	add_child(bg)
	render()

func ai() -> int:
	return Save.area()

func items() -> Array:
	var a := ai()
	var d: int = Save.d.depth[a]
	var out := []
	if tab == "depth":
		for k in range(1, Data.DEPTHS.size()):
			var t: Dictionary = Data.DEPTHS[k]
			var fx := []
			for x in Data.DSHORT.slice(1, k + 1): fx.append(["bad", x])
			fx.append(["good", "coins ×%s" % str(Data.depth_pay(k))])
			fx.append(["good", "stones worth more"])
			out.append({key = "d%d" % k, machine = DMACH[k], n = t.tool, sub = "%d → %d m" % [int(Data.DEPTHS[k - 1].m), int(t.m)], own = d >= k, next = k == d + 1,
				cost = Data.depth_cost(a, k), fx = fx, k = k,
				desc = "Opens workings down to %d m." % int(t.m) if d >= k else "Breaks through rock to %d m. At the new depth: %s." % [int(t.m), Data.DMODS[k]]})
	else:
		for e in Data.EQUIP:
			var lv: int = Save.d.eq[e.id]
			var mx: int = e.cost.size()
			out.append({key = e.id, machine = e.id, n = e.n, sub = "level %d/%d" % [lv, mx], own = lv >= mx, next = lv < mx, cost = int(e.cost[lv]) if lv < mx else 0,
				lv = lv, max = mx, fx = [["good", e.d]], desc = "Works in every mine. Level %d of %d." % [lv, mx] if lv else "Works in every mine at once."})
	return out

func render() -> void:
	for ch in get_children():
		if ch is DepotBg: continue
		ch.queue_free()
	var list := items()
	var it: Dictionary = {}
	for x in list:
		if x.key == sel: it = x
	if it.is_empty():
		for x in list:
			if x.next:
				it = x
				break
	if it.is_empty(): it = list[-1]
	sel = it.key
	var prev: Dictionary = list[list.find(it) - 1] if list.find(it) > 0 else {}
	var root := VBoxContainer.new()
	root.size = size
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(pad)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	pad.add_child(body)
	body.add_child(Chrome.pills())
	body.add_child(UI.title("Depot", 22))
	var a := ai()
	var sub := Ov.text(("%s: digging to %d m" % [Data.AREAS[a].n, int(Data.DEPTHS[int(Save.d.depth[a])].m)] if tab == "depth" else "Gear works in every mine") + " · you have " + UI.coins(Save.d.coins), 13, Color("#d8e0ee"))
	body.add_child(sub)
	body.add_child(tabs([["depth", "Sinking · %d/4" % int(Save.d.depth[a])], ["eq", "Gear"]], tab, func(id: String):
		tab = id
		sel = ""
		render()))
	# the stage: the machine turning under a warm work light
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 180)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	view = SpecView.new(512, true)
	stage.add_child(view)
	stage.resized.connect(func():
		var s := minf(stage.size.x, stage.size.y)
		view.size = Vector2(s, s)
		view.position = Vector2((stage.size.x - s) / 2, (stage.size.y - s) / 2))
	view.show_spec({machine = it.machine})
	if it.own:
		var owned := Reveal.chip("✓ in the depot")
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#1f6a2a")
		st.set_corner_radius_all(10)
		st.content_margin_left = 10
		st.content_margin_right = 10
		st.content_margin_top = 3
		st.content_margin_bottom = 3
		owned.add_theme_stylebox_override("normal", st)
		owned.position = Vector2(16, 14)
		stage.add_child(owned)
	body.add_child(_info(it, prev))
	body.add_child(_strip(list, it))
	root.add_child(Chrome.nav_bar("depot", func(id: String): go.emit(id)))

func _info(it: Dictionary, prev: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.glass(16, 0.66))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var tn := HBoxContainer.new()
	var name_l := UI.label(it.n, 17, UI.display, Color("#ffe08a"))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tn.add_child(name_l)
	tn.add_child(UI.label(it.sub, 12, UI.body, Color("#c8b090")))
	v.add_child(tn)
	if it.has("max"):
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 5)
		for q in int(it.max):
			var on: bool = q < int(it.lv)
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(22, 8)
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color("#e3a51e") if on else Color("#2a2a24")
			ps.border_color = Color("#ffe08a") if on else Color("#4a4a3a")
			ps.set_border_width_all(1)
			ps.set_corner_radius_all(4)
			pip.add_theme_stylebox_override("panel", ps)
			pips.add_child(pip)
		v.add_child(pips)
	var d := UI.label(it.desc, 13, UI.body, Color("#d8d0c0"))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var fx := HFlowContainer.new()
	fx.add_theme_constant_override("h_separation", 5)
	fx.add_theme_constant_override("v_separation", 5)
	for f in it.fx:
		var good: bool = f[0] == "good"
		var l := UI.label(f[1], 11, UI.body_bold, Color("#b0ffb0") if good else Color("#ffb0a0"))
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		st.border_color = Color("#3a6a3a") if good else Color("#7a3a2a")
		st.set_border_width_all(1)
		st.set_corner_radius_all(10)
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 1
		st.content_margin_bottom = 2
		l.add_theme_stylebox_override("normal", st)
		fx.add_child(l)
	v.add_child(fx)
	var btn: Button
	if it.own:
		btn = UI.button("✓ In use" if tab == "depth" else "✓ Maxed", "glass", 16)
		btn.disabled = true
	elif not it.next:
		btn = UI.button("First: " + (String(prev.n).to_lower() if not prev.is_empty() else ""), "glass", 15)
		btn.disabled = true
	elif Save.d.coins >= int(it.cost):
		btn = UI.button(("Upgrade" if it.get("lv", 0) else "Buy") + " · " + UI.coins(int(it.cost)), "gold", 17)
		btn.pressed.connect(func(): _buy(it))
	else:
		btn = UI.button("Need " + UI.coins(int(it.cost) - Save.d.coins), "glass", 15)
		btn.disabled = true
	btn.custom_minimum_size = Vector2(0, 50)
	v.add_child(btn)
	p.add_child(v)
	return p

func _buy(it: Dictionary) -> void:
	if Save.d.coins < int(it.cost): return
	Save.d.coins -= int(it.cost)
	var msg := ""
	if tab == "depth":
		var k: int = it.k
		Save.d.depth[ai()] = k
		Save.d.depth_sel[ai()] = k
		msg = "%s: depth %d m opened" % [it.n, int(Data.DEPTHS[k].m)]
	else:
		Save.d.eq[it.key] += 1
		msg = "%s: level %d" % [it.n, int(Save.d.eq[it.key])]
	Save.persist()
	Sfx.play("build")
	Sfx.buzz(50)
	render()
	_sparks()
	Ov.toast(msg)

func _sparks() -> void:
	var p := CPUParticles2D.new()
	p.position = view.get_global_rect().get_center()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 80
	p.lifetime = 1.3
	p.spread = 180
	p.initial_velocity_min = 100
	p.initial_velocity_max = 320
	p.gravity = Vector2(0, 420)
	p.scale_amount_min = 2
	p.scale_amount_max = 5
	var g := Gradient.new()
	g.set_color(0, Color(2.2, 1.7, 0.6))
	g.set_color(1, Color(1, 0.6, 0.2, 0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)

func _strip(list: Array, it: Dictionary) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 146)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	sc.add_child(h)
	for x in list:
		h.add_child(_card(x, x.key == it.key))
	return sc

func _card(x: Dictionary, on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(98, 144)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0.45)
	st.border_color = Color("#e3a51e") if on else Color("#2e2e28")
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	if on:
		st.shadow_color = Color(0.89, 0.65, 0.12, 0.3)
		st.shadow_size = 6
	for s in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(s, st)
	var v := VBoxContainer.new()
	v.position = Vector2(6, 6)
	v.size = Vector2(86, 132)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := TextureRect.new()
	img.custom_minimum_size = Vector2(86, 80)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not x.own and not x.next:
		img.modulate = Color(0.45, 0.45, 0.45)
	Spec.thumb({machine = x.machine}, func(t: Texture2D): if is_instance_valid(img): img.texture = t)
	v.add_child(img)
	var n := UI.label(x.n, 11, UI.body_bold)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(86, 28)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(n)
	var tag := UI.label("✓" if x.own else UI.fmt(int(x.cost)) if x.next else "locked", 11, UI.body_bold,
		Color("#c8ffc8") if x.own else Color("#2a1a04") if x.next else Color("#8a8270"))
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color("#1f5a24") if x.own else Color("#e3a51e") if x.next else Color("#2a2a24")
	ts.set_corner_radius_all(9)
	ts.content_margin_left = 8
	ts.content_margin_right = 8
	tag.add_theme_stylebox_override("normal", ts)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tag)
	b.add_child(v)
	var key: String = x.key
	b.pressed.connect(func():
		sel = key
		Sfx.play("swap")
		render())
	return b

## a row of tabs on a glass bar
static func tabs(list: Array, active: String, on_pick: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var st := UI.glass(14, 0.62)
	st.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for t in list:
		var id: String = t[0]
		var on := id == active
		var b := Button.new()
		b.text = t[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_override("font", UI.body_bold)
		b.add_theme_font_size_override("font_size", 13)
		var bs := StyleBoxFlat.new()
		bs.set_corner_radius_all(11)
		bs.bg_color = Color("#e3a51e") if on else Color(0, 0, 0, 0)
		for s in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(s, bs)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, Color("#2a1a04") if on else UI.MUTED)
		b.pressed.connect(func(): if not on: on_pick.call(id))
		h.add_child(b)
	p.add_child(h)
	return p

## the workshop wall behind the stage: dark steel, a faint grid, a warm light from above
class DepotBg extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
			PackedColorArray([Color("#1a1e24"), Color("#1a1e24"), Color("#0c0e12"), Color("#0c0e12")]))
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.025), 1)
			x += 34
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.025), 1)
			y += 34
		GemArt.radial_disc(self, Vector2(size.x / 2, size.y * 0.36), size.x * 0.75, Color(0.95, 0.69, 0.12, 0.16), Color(0.95, 0.69, 0.12, 0.06), Color(0.95, 0.69, 0.12, 0), 0.5, 40)
		GemArt.radial_disc(self, Vector2(size.x / 2, 0), size.x * 0.8, Color(0.95, 0.69, 0.12, 0.14), Color(0.95, 0.69, 0.12, 0.04), Color(0.95, 0.69, 0.12, 0), 0.5, 40)
