class_name GemNode
extends Node2D
## One stone, special or nugget on the board, drawn from its pre-rendered sprite; moves and pops are tweened by BoardView.

const GLINT := preload("res://shaders/gem_glint.gdshader")
const ORE_GLINT := preload("res://shaders/ore_glint.gdshader")
const SPECIAL_FX := preload("res://shaders/special_fx.gdshader")
const ORE_OVERLAY := preload("res://shaders/ore_overlay.gdshader")
static var _mat_veins: ShaderMaterial
static var _mat_cubes: ShaderMaterial
static var _fx_mats := {}
static var _white: Texture2D
static var _mat_plain: ShaderMaterial
static var _mat_special: ShaderMaterial
static var _mat_ore: ShaderMaterial
static var _mat_iron: ShaderMaterial

var id := 0
var t := 0
var sp := ""
var item := ""
var ore := ""                 # the model stone's ore: "", iron, ore
var S := 46.0
var b3: Board3D               # when set, plain stones are drawn as 3D gems that follow this node
var stone: MeshInstance3D
var ore_glow: Sprite2D        # an ore-bearing stone's veins, shimmering on top of it
var live_fx: Array[Sprite2D] = []   # a special's live touches: its fuse sparking, its radar sweeping

static func materials() -> void:
	if _mat_special: return
	# both through the gem shader with its glint switched off: plain stones drawn with the engine's own
	# canvas shader went missing on the iPhone once shaders were baked at export (specials never did)
	_mat_plain = BoardSprites.plain_material()
	_mat_special = ShaderMaterial.new()
	_mat_special.shader = GLINT
	_mat_special.set_shader_parameter("boost", 1.25)
	_mat_special.set_shader_parameter("strength", 0.0)
	_mat_ore = ShaderMaterial.new()
	_mat_ore.shader = ORE_GLINT
	# iron: a cold light that flashes off one cube face at a time, instead of the veins' slow breath
	_mat_iron = ShaderMaterial.new()
	_mat_iron.shader = ORE_GLINT
	_mat_iron.set_shader_parameter("tint", Vector3(0.7, 0.88, 1.0))
	_mat_iron.set_shader_parameter("sparkle", 1.0)
	_mat_veins = ShaderMaterial.new()
	_mat_veins.shader = ORE_OVERLAY
	_mat_cubes = ShaderMaterial.new()
	_mat_cubes.shader = ORE_OVERLAY
	_mat_cubes.set_shader_parameter("mode", 1)

func setup(gem: BoardModel.Gem, size: float) -> GemNode:
	materials()
	light_mask = 0
	id = gem.id
	t = gem.t
	sp = gem.sp
	item = gem.item
	ore = gem.ore
	S = size
	material = _mat_special if sp != "" else _mat_plain
	if b3 and Board3D.STYLE >= 99 and sp == "" and item != "nug" and t >= 0:
		stone = b3.make_stone(t)
		_sync()
	set_process(stone != null)
	_ore_glow(ore_kind())
	_special_fx()
	queue_redraw()
	return self

## a quad over the sprite per live touch, drawn by special_fx.gdshader at the anchor gem_kit rendered
func _special_fx() -> void:
	for n in live_fx: n.queue_free()
	live_fx.clear()
	if sp == "" or BoardSprites.gem_style == "": return
	var an := BoardSprites.anchors(sp)
	var spots := []
	for p in an.get("spark", []): spots.append([0, Vector2(p[0], p[1]), 0.0])
	if an.has("screen"): spots.append([1, Vector2(an.screen[0], an.screen[1]), float(an.radius)])
	if _white == null:
		var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(im)
	for s in spots:
		var key := "%s%s" % [sp, s[1]]
		if not _fx_mats.has(key):
			var m := ShaderMaterial.new()
			m.shader = SPECIAL_FX
			m.set_shader_parameter("mode", s[0])
			m.set_shader_parameter("at", s[1])
			m.set_shader_parameter("rad", s[2])
			_fx_mats[key] = m
		var q := Sprite2D.new()
		q.texture = _white
		q.material = _fx_mats[key]
		q.light_mask = 0
		q.scale = Vector2.ONE * S * BoardSprites.SPAN / 4.0
		add_child(q)
		live_fx.append(q)

## "ore" (the mine's own), "iron" (the common ore), or "" for a plain stone
func ore_kind() -> String:
	if sp != "" or item != "" or t < 0: return ""
	return ore

## the live part of the ore: the rendered sets' glow mask shimmering over the stone, or the stone redrawn with veins
## or cubes painted over it (ore_overlay.gdshader); the badge look is drawn in _draw
func _ore_glow(kind: String) -> void:
	var look := BoardSprites.ore_look_now()
	if kind == "" or look == "badge":
		if ore_glow: ore_glow.queue_free()
		ore_glow = null
		return
	if ore_glow == null:
		ore_glow = Sprite2D.new()
		ore_glow.light_mask = 0
		add_child(ore_glow)
	var k := 1.0
	if look == "rendered":
		ore_glow.material = _mat_iron if kind == "iron" else _mat_ore
		ore_glow.texture = BoardSprites.gem_ore_glow(t, kind)
	else:
		ore_glow.material = _mat_cubes if kind == "iron" else _mat_veins
		ore_glow.texture = BoardSprites.gem(t)
		k = BoardSprites.gem_scale()
	ore_glow.scale = Vector2.ONE * S * BoardSprites.SPAN * k / float(ore_glow.texture.get_width())

## re-read the board's looks: gem set, ore look, timber
func restyle() -> void:
	_ore_glow(ore_kind())
	queue_redraw()

func _process(_dt: float) -> void:
	if stone: _sync()

## carry the 3D stone along: position, squash-and-stretch, fading
func _sync() -> void:
	var p := get_parent() as Node2D
	var at := position if p == null else p.position + position
	stone.position = b3.to_world(at)
	var s := scale
	stone.scale = Vector3(s.x, (s.x + s.y) * 0.5, s.y) * (S / b3.TS)
	stone.rotation.y = -rotation
	stone.transparency = clampf(1.0 - modulate.a * self_modulate.a, 0.0, 1.0)
	stone.visible = visible and modulate.a > 0.01

func _exit_tree() -> void:
	if stone:
		stone.queue_free()
		stone = null

func become(new_sp: String) -> void:
	sp = new_sp
	_ore_glow("")
	_special_fx()
	material = _mat_special
	if stone:
		stone.queue_free()
		stone = null
	set_process(false)
	queue_redraw()

func _draw() -> void:
	if item == "nug":
		BoardSprites.draw(self, BoardSprites.tex("nug"), Vector2.ZERO, S)
	elif sp != "":
		BoardSprites.draw(self, BoardSprites.tex(sp), Vector2.ZERO, S)
	elif t >= 0 and not stone:
		var kind := ore_kind()
		var look := BoardSprites.ore_look_now()
		var tx := BoardSprites.gem_ore(t, kind) if kind != "" and look == "rendered" else BoardSprites.gem(t)
		BoardSprites.draw(self, tx, Vector2.ZERO, S * BoardSprites.gem_scale())
		if kind != "" and look == "badge":
			# a coin at the stone's lower right: a gold nugget for the mine's ore, the same in steel for iron
			var at := Vector2(S * 0.27, S * 0.26)
			var ring := Color(1.0, 0.75, 0.3) if kind == "ore" else Color(0.65, 0.85, 1.0)
			draw_circle(at, S * 0.17, Color(0.06, 0.05, 0.04, 0.92))
			draw_arc(at, S * 0.17, 0, TAU, 24, ring, maxf(1.5, S * 0.035), true)
			BoardSprites.draw(self, BoardSprites.tex("nug"), at, S * 0.27, Color.WHITE if kind == "ore" else Color(0.55, 0.62, 0.72))
