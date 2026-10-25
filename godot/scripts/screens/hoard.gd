class_name Hoard
extends Control
## The boss's reward: its hoard. The serpent coiled round a boulder of the mine's rock with gold in its cracks,
## nine geodes, druses of white quartz and pyrite grown into it — a pixel turntable rendered in Blender
## (prototype/tools/blender/hoard_kit.py, then art/boss/hoard_px.py onto the bosses' 1 pt grid). Drag to turn it,
## tap a geode (found through the mask, so one hidden behind the serpent can't be picked), crack the one you keep;
## the other eight stay with the serpent. The Geologist's lens (gear, `lens`) lights the rarity of one geode per level.
## Hoard.pick(area) opens it on a card and returns the stone chosen.

signal selected(i: int)
signal picked(stone: Dictionary)

## how lucky each of the nine is (Stones.roll): one fine stone, a few good ones, the rest ordinary
const LUCK := [3.5, 2.6, 2.0, 1.6, 1.3, 1.1, 1.0, 0.9, 0.8]
const DIR := "res://assets/boss/%s/"
## pt of drag per frame; frames a second while it turns by itself
const DRAG := 7.0
const IDLE_FPS := 5.0

var stones := []
var lit := {}           # geode index (0..8) -> its rarity tier, for the ones the lens shows
var sel := -1
var meta := {}
var tex: Texture2D
var mask: Image
var mat := ShaderMaterial.new()
var frame := 0.0
var _touched := false
var _down := false
var _moved := 0.0
var _vel := 0.0
var _busy := false

## the card: the hoard turning, a line on the lens, the button; awaits the choice and returns the stone
static func pick(area: int) -> Dictionary:
	var B: Dictionary = Data.AREAS[area].get("boss", {})
	var v := Ov.card(360)
	v.add_child(UI.title("The hoard of %s" % String(B.get("n", "the boss")), 21))
	v.add_child(Ov.text("Turn it, pick one geode. The rest stay with the serpent.", 13))
	var h := Hoard.new()
	h.setup(area, String(B.get("id", "poloz")))
	var wrap := CenterContainer.new()
	wrap.add_child(h)
	v.add_child(wrap)
	var lv: int = int(Save.d.eq.get("lens", 0))
	v.add_child(Ov.text("The Geologist's lens shows %d of them." % lv if lv else "A Geologist's lens (Machines → Gear) would show what lies inside.", 12, UI.GOLD if lv else UI.MUTED))
	var btn := Ov.btn("Pick a geode", "gold", func(): h.crack(), false)
	v.add_child(btn)
	h.selected.connect(func(i: int):
		btn.disabled = false
		btn.text = "Crack this geode" + (" · %s" % String(Data.RAR[h.lit[i]]) if h.lit.has(i) else ""))
	var st: Dictionary = await h.picked
	return st

func setup(area: int, id: String) -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string((DIR % id) + "hoard.json"))
	tex = load((DIR % id) + "hoard_color.png")
	var mt: Texture2D = load((DIR % id) + "hoard_mask.png")
	mask = mt.get_image()
	var S: int = int(meta.size)
	custom_minimum_size = Vector2(S, S)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mat.shader = preload("res://shaders/hoard_pick.gdshader")
	mat.set_shader_parameter("mask_tex", mt)
	material = mat
	for i in LUCK.size():
		stones.append(Stones.roll(Save.next_uid(), area, LUCK[i], Data.depths(area).size()))
	stones.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(stones[0].id)
	var order := range(stones.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]; order[i] = order[j]; order[j] = tmp
	for k in mini(int(Save.d.eq.get("lens", 0)), stones.size()):
		lit[order[k]] = int(stones[order[k]].tier)
	var cols := PackedVector4Array()
	cols.resize(10)
	for i in lit:
		var c := Data.rarity_color(int(lit[i]))
		cols[i + 1] = Vector4(c.r, c.g, c.b, 1.0)
	mat.set_shader_parameter("lit", cols)
	# a soft shadow under it, drawn by a child with the stones' shader (the stock one draws nothing on iPhone)
	var shadow := Control.new()
	shadow.show_behind_parent = true
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.material = BoardSprites.plain_material()
	shadow.draw.connect(func():
		for k in 6:
			var w := S * (0.42 - k * 0.04)
			shadow.draw_colored_polygon(GemArt.ellipse_pts(Vector2(S * 0.5, S * 0.86), w, w * 0.16, 0, 32), Color(0, 0, 0, 0.12)))
	add_child(shadow)

func _n() -> int:
	return int(meta.frames)

func _cell(f: int) -> Rect2:
	var S: int = int(meta.size)
	var cols: int = int(meta.cols)
	return Rect2((f % cols) * S, (f / cols) * S, S, S)

func _draw() -> void:
	var S: float = float(meta.size)
	draw_texture_rect_region(tex, Rect2(0, 0, S, S), _cell(posmod(int(floor(frame)), _n())))

func _gui_input(e: InputEvent) -> void:
	if _busy: return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_touched = true
			_moved = 0.0
			_vel = 0.0
		else:
			_down = false
			if _moved < 8.0: _pick(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _down:
		var dx: float = e.relative.x
		_moved += absf(dx) + absf(e.relative.y)
		_vel = dx
		frame -= dx / DRAG
		queue_redraw()
		accept_event()

func _process(dt: float) -> void:
	var was := int(floor(frame))
	if not _touched:
		frame += IDLE_FPS * dt
	elif not _down and absf(_vel) > 0.2:
		_vel *= 0.9
		frame -= _vel / DRAG
	if int(floor(frame)) != was: queue_redraw()

## the geode under the finger: its number in the mask of the frame on show
func _pick(at: Vector2) -> void:
	var S: int = int(meta.size)
	var x := clampi(int(at.x), 0, S - 1)
	var y := clampi(int(at.y), 0, S - 1)
	var r := _cell(posmod(int(floor(frame)), _n()))
	var id := roundi(mask.get_pixel(int(r.position.x) + x, int(r.position.y) + y).r8 / 20.0)
	if id <= 0 or id > stones.size() or id - 1 == sel: return
	sel = id - 1
	mat.set_shader_parameter("sel", id)
	Sfx.play("click")
	Sfx.buzz(10)
	selected.emit(sel)

## where the chosen geode is on the frame on show (the middle of its pixels), for the burst
func _centre() -> Vector2:
	var S: int = int(meta.size)
	var r := _cell(posmod(int(floor(frame)), _n()))
	var sum := Vector2.ZERO
	var n := 0
	for y in range(0, S, 2):
		for x in range(0, S, 2):
			if roundi(mask.get_pixel(int(r.position.x) + x, int(r.position.y) + y).r8 / 20.0) == sel + 1:
				sum += Vector2(x, y)
				n += 1
	return sum / n if n else Vector2(S, S) * 0.5

## the chosen one cracks: the hoard shakes three times, the geode flares white and bursts in rock chips
func crack() -> void:
	if sel < 0 or _busy: return
	_busy = true
	var base := position
	for k in 3:
		Sfx.play("crack", k + 1)
		Sfx.buzz(20)
		var tw := create_tween()
		for q in 3:
			tw.tween_property(self, "position", base + Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.035)
		tw.tween_property(self, "position", base, 0.04)
		tw.parallel().tween_method(func(f: float): mat.set_shader_parameter("flash", f), 0.0, 0.25 * (k + 1), 0.15)
		await tw.finished
		await get_tree().create_timer(0.16).timeout
	var tw2 := create_tween()
	tw2.tween_method(func(f: float): mat.set_shader_parameter("flash", f), 0.75, 1.0, 0.1)
	await tw2.finished
	_burst(_centre())
	await get_tree().create_timer(0.45).timeout
	picked.emit(stones[sel])

func _burst(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 40
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.initial_velocity_min = 80
	p.initial_velocity_max = 220
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 2
	p.scale_amount_max = 4
	var g := Gradient.new()
	g.set_color(0, Color("#fff2c0"))
	g.add_point(0.4, Color("#c89a5a"))
	g.set_color(g.get_point_count() - 1, Color("#5a4030"))
	p.color_initial_ramp = g
	p.material = BoardSprites.plain_material()
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
