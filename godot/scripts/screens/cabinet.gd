class_name Cabinet
extends Control
## The inventory tab as a room (art/ui_redesign/cabinet, GPT: the empty room bg_g4 and each object cut off its own sheet):
## three niches for the artifacts at the top, the bosses' trophies on the shelf under them, the cups in the display
## cabinet on the right (achievements), the workbench on the rug (workshop), crates and a chest in the corner (the stones).
## Every object is a button that opens its own window. The room keeps its picture's proportions: it fills the height
## between the bars and is cropped at the sides, a little to the left, so the display cabinet stays in view.

signal go(screen: String)

const DIR := "res://assets/cabinet/"
const ANCHOR_X := 0.58     # where the room is cropped across: 0 shows its left edge, 1 its right
const ZOOM := 1.04          # the room a little bigger than the space: the empty floor at the bottom goes off screen
const ANCHOR_Y := 0.25     # and the extra height is cut mostly at the bottom
## the objects in the room's picture: [file, centre x, bottom y (shares of the picture), width (share of its height)]
const ITEMS := {
	crates = ["crates", 0.215, 0.726, 0.124],
	chest = ["chest", 0.27, 0.86, 0.127],
	bench = ["bench", 0.472, 0.824, 0.37],
	cups_hi = ["cups", 0.9, 0.45, 0.065],
	cups_lo = ["cups", 0.9, 0.55, 0.065],
	serpent = ["serpent", 0.3, 0.437, 0.059],
	casket = ["casket", 0.567, 0.437, 0.08],
}
const NICHES := [Vector2(0.24, 0.35), Vector2(0.44, 0.35), Vector2(0.65, 0.35)]   # the artifacts' stands
## what each object opens, and the plaque under it
const ZONES := {crates = ["stones", "Stones"], chest = ["stones", ""], bench = ["workshop", "Workshop"],
	cups_hi = ["awards", "Awards"], cups_lo = ["awards", ""], serpent = ["trophy", ""], casket = ["trophy", ""]}

var room: Control
var nodes := {}

func _ready() -> void:
	size = get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color("#120e0b")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var root := VBoxContainer.new()
	root.size = size
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10 + int(UI.safe_top()))
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.z_index = 1
	pad.add_child(Chrome.top_bar())
	root.add_child(pad)
	room = Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.clip_contents = true
	room.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room.draw.connect(_draw_room)
	room.resized.connect(_layout)
	root.add_child(room)
	root.add_child(Chrome.nav_bar("museum", func(id: String): go.emit(id)))
	_build()

## the picture's size in the room and how far it is shifted left and up
func _fit() -> Array:
	var tx := Kit.tex_at(DIR + "room.png")
	var h := room.size.y * ZOOM
	var w := tx.get_width() * h / tx.get_height()
	return [w, h, (w - room.size.x) * ANCHOR_X, (h - room.size.y) * ANCHOR_Y]

func _at(fx: float, fy: float) -> Vector2:
	var f := _fit()
	return Vector2(fx * float(f[0]) - float(f[2]), fy * float(f[1]) - float(f[3]))

func _draw_room() -> void:
	var f := _fit()
	room.draw_texture_rect(Kit.tex_at(DIR + "room.png"), Rect2(-float(f[2]), -float(f[3]), float(f[0]), float(f[1])), false)
	# the room sinks into the dark at the top (under the bar) and at the bottom
	for i in 24:
		var k := 1.0 - i / 24.0
		room.draw_rect(Rect2(0, i, room.size.x, 1), Color(0.07, 0.055, 0.04, 0.85 * k * k))
		room.draw_rect(Rect2(0, room.size.y - 1 - i, room.size.x, 1), Color(0.07, 0.055, 0.04, 0.9 * k * k))

func _build() -> void:
	var won: Array = Save.d.boss_won
	for id in ITEMS:
		if id == "serpent" and not bool(won[0]): continue
		if id == "casket" and not bool(won[1]): continue
		var it: Array = ITEMS[id]
		var t := TextureRect.new()
		t.texture = Kit.tex_at(DIR + String(it[0]) + ".png")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		var z: Array = ZONES[id]
		t.gui_input.connect(func(e: InputEvent): _press(t, e, String(z[0])))
		room.add_child(t)
		nodes[id] = t
		if String(z[1]) != "":
			var p := _plaque(String(z[1]))
			room.add_child(p)
			nodes[id + "_plaque"] = p
	# the artifact niches: empty for now, a faint + on each stand
	for i in NICHES.size():
		var n := Button.new()
		n.flat = true
		n.text = "+"
		n.add_theme_font_override("font", UI.display)
		n.add_theme_font_size_override("font_size", 22)
		n.add_theme_color_override("font_color", Color(Kit.AMBER, 0.45))
		n.add_theme_color_override("font_hover_color", Color(Kit.AMBER, 0.8))
		n.pressed.connect(func(): _open("artifacts"))
		room.add_child(n)
		nodes["niche_%d" % i] = n
	var ap := _plaque("Artifacts")
	room.add_child(ap)
	nodes["artifacts_plaque"] = ap

func _layout() -> void:
	var h := room.size.y * ZOOM
	for id in ITEMS:
		if not nodes.has(id): continue
		var it: Array = ITEMS[id]
		var t: TextureRect = nodes[id]
		var w := float(it[3]) * h
		var sz := Vector2(w, w * t.texture.get_height() / t.texture.get_width())
		var foot := _at(float(it[1]), float(it[2]))
		t.size = sz
		t.position = foot - Vector2(sz.x / 2.0, sz.y)
		if nodes.has(id + "_plaque"):
			var p: Control = nodes[id + "_plaque"]
			p.reset_size()
			# kept on screen: the room is cropped at the sides
			p.position = Vector2(clampf(foot.x - p.size.x / 2.0, 6.0, room.size.x - p.size.x - 6.0), foot.y - 4.0)
	for i in NICHES.size():
		var n: Button = nodes["niche_%d" % i]
		var c := _at(NICHES[i].x, NICHES[i].y)
		n.size = Vector2(0.11, 0.13) * h
		n.position = c - Vector2(n.size.x / 2.0, n.size.y * 0.95)
	var ap: Control = nodes["artifacts_plaque"]
	ap.reset_size()
	var mid := _at(NICHES[1].x, NICHES[1].y)
	ap.position = Vector2(mid.x - ap.size.x / 2.0, mid.y + 4.0)
	room.queue_redraw()

## a small dark plaque with a brass edge and the zone's name
func _plaque(t: String) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.075, 0.06, 0.9)
	st.border_color = Color(Kit.AMBER, 0.7)
	st.set_border_width_all(1)
	st.set_corner_radius_all(5)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 1
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 1      # over the furniture that stands in front
	var l := Kit.label(t.to_upper(), 10, UI.body_bold, Kit.CREAM)
	p.add_child(l)
	return p

## a tap: the object brightens while pressed, opens its window on release
func _press(t: TextureRect, e: InputEvent, what: String) -> void:
	var down: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	var up: bool = (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed) or (e is InputEventScreenTouch and not e.pressed)
	if down:
		t.modulate = Color(1.25, 1.18, 1.05)
	elif up:
		t.modulate = Color.WHITE
		_open(what)

func _open(what: String) -> void:
	Sfx.buzz(8)
	match what:
		"stones":
			Sfx.play("tab")
			Museum.start_tab = "spc"
			go.emit("stones")
		"workshop":
			Sfx.play("tab")
			Museum.start_tab = "jw"
			go.emit("stones")
		"awards": _awards()
		"trophy": Ov.toast("A trophy of a beaten boss")
		_: _artifacts()

## achievements, for now the atlas's seals mine by mine
func _awards() -> void:
	Sfx.play("open")
	var v := Ov.card(330)
	v.add_child(UI.title("Awards", 22))
	for a in Data.AREAS.size():
		if not Atlas.is_open(a): continue
		var pool: Dictionary = Data.AREAS[a].pool
		var legend := false
		for id in pool:
			if Save.d.atlas.has(id) and bool(Save.d.atlas[id].get("legend", false)): legend = true
		var lit := [Atlas.found_in(a) == pool.size(), a < Save.d.boss_won.size() and bool(Save.d.boss_won[a]), legend]
		var n := 0
		for x in lit: if x: n += 1
		v.add_child(Ov.text("%s · %d/3 seals" % [Data.AREAS[a].n, n], 14))
	v.add_child(Ov.text("Every species of a mine, its boss beaten, a legendary find.", 12, Kit.DIM))
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))

func _artifacts() -> void:
	Sfx.play("open")
	var v := Ov.card(330)
	v.add_child(UI.title("Artifacts", 22))
	v.add_child(Ov.text("Three stands for the finds you take below. A stone's genes will work on the board: golden veins, gas bubbles, a rainbow film. Coming soon.", 13))
	v.add_child(Ov.btn("Close", "glass", func(): Ov.close()))
