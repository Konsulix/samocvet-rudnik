class_name BossView
extends Control
## The boss over the board, pixel art on the 1-pt grid (pictures baked by art/boss/export.py into assets/boss/<id>/).
## Every mood comes in a few line-boil variants that take turns, faster and wilder the angrier it is; whole new poses
## come in with a pixel dissolve; hits flash it white and shake it; the defeat is a scream, a fall with stones
## breaking off and the head hitting the coils in a cloud of dust. Rules know nothing of this: LevelBoss drives it.
## A boss may change with the boards (the Mistress turns into a lizard): phase 2's moods are p2_<mood>, phase 3's
## p3_<mood>; a mood a phase lacks comes from the phase before, and a new phase dissolves in like a new pose.

const FPS := 8.0
const DISSOLVE := 3.0 / FPS            # a new pose takes three frames to come in
## moods patched over the idle picture (only the eye or a few chips change): they swap without a dissolve
const PATCHES := ["blink", "hurt"]

var dir := ""
var meta: Dictionary
var tex := {}                # mood -> [variants]
var spr: TextureRect
var dust: ColorRect
var stones: Node2D           # the pebbles off the neck, while it sags
## its body going on below the picture's flat-cut bottom (art/boss/export_below.py: `<phase prefix>below.png`, drawn on
## by the generator, sinking into the dark at its foot): hung under the sprite, moving and shaking with it. Where the
## board's cut-away corners leave no frame bar over the sprite's bottom, it is seen instead of the cut
var below: TextureRect
var below_tex := {}          # phase -> texture
var mood := "idle"
var phase := 0               # the board of the fight: which phase's pictures
var _shown := ""             # the pictures on screen: the mood with its phase's prefix
var rest := "idle"           # what it goes back to: idle, or rage on the last board
var _t := 0.0
var _boil_t := 0.0
var _boil := 0
var _until := 0.0            # a passing mood lasts until then, then back to rest
var _blink_at := 2.5
var _shake := []             # offsets still to play, one per frame
var _shake_t := 0.0
var _flash := 0.0
var _dust_age := -1.0
var _pebbles_age := -1.0
var _lock := false           # the defeat plays to the end, nothing interrupts it

static func load_for(id: String) -> BossView:
	var v := BossView.new()
	v.dir = "res://assets/boss/%s/" % id
	v.meta = JSON.parse_string(FileAccess.get_file_as_string(v.dir + "boss.json"))
	for m: String in v.meta.moods:
		var list := []
		for b in int(v.meta.boil):
			list.append(load(v.dir + "%s_%d.png" % [m, b]))
		v.tex[m] = list
	return v

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sz := Vector2(meta.size[0], meta.size[1])
	size = sz
	spr = TextureRect.new()
	spr.size = sz
	_shown = _key("idle")
	spr.texture = tex[_shown][0]
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/boss_sprite.gdshader")
	m.set_shader_parameter("from_tex", spr.texture)
	spr.material = m
	add_child(spr)
	for ph in int(meta.get("phases", 1)):
		var bp := dir + ("" if ph == 0 else "p%d_" % (ph + 1)) + "below.png"
		if ResourceLoader.exists(bp): below_tex[ph] = load(bp)
	if not below_tex.is_empty():
		below = TextureRect.new()
		below.texture = below_tex.get(0, below_tex.values()[0])
		# it starts a little up over the sprite's bottom, covering the picture's own dark cut edge (export_below.py UP)
		below.position = Vector2(0, sz.y - float(meta.get("below_up", 8)))
		below.size = below.texture.get_size()
		below.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		below.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spr.add_child(below)
	stones = Node2D.new()
	stones.draw.connect(_draw_stones)
	add_child(stones)
	dust = ColorRect.new()
	dust.size = sz
	dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://shaders/boss_dust.gdshader")
	dm.set_shader_parameter("rect_size", sz)
	dm.set_shader_parameter("origin", Vector2(meta.dust_at[0], meta.dust_at[1]))
	dust.material = dm
	dust.visible = false
	add_child(dust)

## where no bar of the frame hides its flat-cut bottom: per column of the picture, 1 exposed .. 0 hidden.
## There its bottom `band` px sink into the dark and dither away (shaders/boss_sprite.gdshader)
func set_exposed(cols: PackedFloat32Array, band: float) -> void:
	var img := Image.create(cols.size(), 1, false, Image.FORMAT_L8)
	for x in cols.size(): img.set_pixel(x, 0, Color(cols[x], cols[x], cols[x]))
	var sm: ShaderMaterial = spr.material
	sm.set_shader_parameter("exposed", ImageTexture.create_from_image(img))
	sm.set_shader_parameter("sink_band", band)

## the point on screen the speech bubble points at
func head_global() -> Vector2:
	return global_position + Vector2(meta.head_at[0], meta.head_at[1])

# ---------------------------------------------------------------- moods

## a mood's pictures in this phase: its own, else the nearest phase before that has them
func _key(m: String) -> String:
	for ph in range(phase, 0, -1):
		var k := "p%d_%s" % [ph + 1, m]
		if tex.has(k): return k
	return m

func _go(m: String) -> void:
	var k := _key(m)
	if m == mood and k == _shown: return
	# blink and flinch are drawn over the idle picture: between them no dissolve is needed
	var whole := k.trim_suffix(m) != _shown.trim_suffix(mood) 		or not ((m in PATCHES and mood == "idle") or (mood in PATCHES and m == "idle"))
	var sm: ShaderMaterial = spr.material
	if whole:
		sm.set_shader_parameter("from_tex", spr.texture)
		sm.set_shader_parameter("fade", 0.0)
		var tw := create_tween()
		tw.tween_method(func(v: float): sm.set_shader_parameter("fade", snappedf(v, 0.25)), 0.0, 1.0, DISSOLVE)
	mood = m
	_shown = k
	_boil_t = 999.0

## the fight's board `i`: that phase's pictures, dissolving in
func set_phase(i: int) -> void:
	if i == phase: return
	phase = i
	# its body below goes with the phase's picture: its own, else the nearest phase before that has one
	if below:
		for ph in range(i, -1, -1):
			if below_tex.has(ph):
				below.texture = below_tex[ph]
				break
	if not _lock: _go(mood)

## show a mood for a while, then back to rest
func show_for(m: String, sec: float) -> void:
	if _lock: return
	_go(m)
	_until = _t + sec

## the last board: it stays enraged
func set_rest(m: String) -> void:
	rest = m
	if not _lock and _until <= _t: _go(m)

## a hit: a flash and a shake always, the flinch when it really hurt
func hit(big: bool) -> void:
	if _lock: return
	_flash = 0.65 if big else 0.35
	_shake = [Vector2(3, 0), Vector2(-3, 1), Vector2(2, -1), Vector2(-1, 0)] if big else [Vector2(2, 0), Vector2(-1, 0)]
	_shake_t = 0.0
	if big: show_for("hurt", 0.5)

## it acts: jaws open, veins blaze
func cast() -> void:
	show_for("cast", 0.9)

## it lost a third of its health: a short scream, then whatever it rests in now
func lose_phase() -> void:
	if _lock: return
	_flash = 0.7
	_shake = [Vector2(3, 0), Vector2(-3, 1), Vector2(2, -1), Vector2(-3, 0), Vector2(3, 1), Vector2(-1, 0)]
	_shake_t = 0.0
	show_for("scream", 1.0)

## the end of the fight: scream, fall, lie in the dust
func defeat() -> void:
	_lock = true
	_until = 1e9
	_flash = 0.75
	_go("scream")
	_shake = []
	for i in 10: _shake.append([Vector2(3, 0), Vector2(-3, 1), Vector2(2, -1), Vector2(-1, 0)][i % 4])
	_shake_t = 0.0
	Sfx.play("boom")
	Sfx.buzz(60)
	await get_tree().create_timer(1.1).timeout
	# a boss of the sea (boss.json "drown"): no stones and dust - he dims and goes down under his water for good
	if bool(meta.get("drown", false)):
		_go("fall")
		var dt := create_tween()
		dt.tween_property(self, "position:y", position.y + size.y * 0.8, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await get_tree().create_timer(1.3).timeout
		_go("defeated")
		await get_tree().create_timer(2.2).timeout
		return
	_go("fall")
	_pebbles_age = 0.0
	var tw := create_tween()
	tw.tween_property(spr, "position:y", 3.0, 0.8)
	await get_tree().create_timer(0.9).timeout
	_go("defeated")
	spr.position.y = 0.0
	_shake = [Vector2(0, 2), Vector2(0, -1)]
	_shake_t = 0.0
	_dust_age = 0.0
	dust.visible = true
	Sfx.play("rock")
	Sfx.buzz(40)
	await get_tree().create_timer(1.6).timeout

# ---------------------------------------------------------------- frame by frame

func _process(dt: float) -> void:
	_t += dt
	# passing moods end; now and then it blinks
	if not _lock and _until > 0.0 and _t >= _until:
		_until = 0.0
		_go(rest)
	if not _lock and mood == "idle" and _t >= _blink_at:
		show_for("blink", 0.25)
		_blink_at = _t + randf_range(2.5, 5.5)
	# line boil: the mood's own pace
	var rate: float = float(meta.moods[_shown][1]) / FPS
	_boil_t += dt
	if _boil_t >= rate:
		_boil_t = 0.0
		_boil = (_boil + 1) % int(meta.boil)
		spr.texture = tex[_shown][_boil]
	# shake: one offset per frame of 1/8 s
	if not _shake.is_empty():
		_shake_t += dt
		if _shake_t >= 1.0 / FPS:
			_shake_t = 0.0
			var o: Vector2 = _shake.pop_front()
			spr.position.x = o.x
			if mood != "fall": spr.position.y = o.y
			if _shake.is_empty(): spr.position.x = 0.0
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 5.0)
		(spr.material as ShaderMaterial).set_shader_parameter("flash", snappedf(_flash, 0.15))
	if _dust_age >= 0.0:
		_dust_age += dt * FPS
		(dust.material as ShaderMaterial).set_shader_parameter("age", floorf(_dust_age))
		if _dust_age > 26.0:
			_dust_age = -1.0
			dust.visible = false
	if _pebbles_age >= 0.0:
		_pebbles_age += dt * FPS
		stones.queue_redraw()
		if _pebbles_age > 14.0: _pebbles_age = -1.0

## small stones breaking off the sagging neck, falling faster and faster
func _draw_stones() -> void:
	if _pebbles_age < 0.0: return
	var o := Vector2(meta.neck_at[0], meta.neck_at[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cols := [Color8(96, 80, 60), Color8(130, 110, 84), Color8(168, 146, 114)]
	if meta.has("pebbles"):
		cols = (meta.pebbles as Array).map(func(h: String) -> Color: return Color(h))
	for i in 16:
		var t0 := rng.randf_range(0.0, 3.0)
		var dx := rng.randf_range(-30.0, 30.0)
		var dy := rng.randf_range(-20.0, 10.0)
		var drift := rng.randf_range(-1.0, 1.0)
		var s := float(rng.randi_range(2, 3))
		var col: Color = cols[rng.randi_range(0, 2)]
		var t := floorf(_pebbles_age) - t0
		if t < 0.0: continue
		var p := (o + Vector2(dx + drift * t, dy + 0.6 * t * t)).floor()
		if p.y > size.y: continue
		stones.draw_rect(Rect2(p - Vector2.ONE, Vector2(s + 2, s + 2)), Color8(20, 15, 10))
		stones.draw_rect(Rect2(p, Vector2(s, s)), col)
