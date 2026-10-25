class_name GemNode
extends Node2D
## One stone, special or nugget on the board, drawn from its pre-rendered sprite; moves and pops are tweened by BoardView.

const GLINT := preload("res://shaders/gem_glint.gdshader")
const ORE_GLINT := preload("res://shaders/ore_glint.gdshader")
static var _mat_plain: ShaderMaterial
static var _mat_special: ShaderMaterial
static var _mat_ore: ShaderMaterial
static var _mat_iron: ShaderMaterial

var id := 0
var t := 0
var sp := ""
var item := ""
var S := 46.0
var b3: Board3D               # when set, plain stones are drawn as 3D gems that follow this node
var stone: MeshInstance3D
var ore_glow: Sprite2D        # an ore-bearing stone's veins, shimmering on top of it

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

func setup(gem: BoardModel.Gem, size: float) -> GemNode:
	materials()
	light_mask = 0
	id = gem.id
	t = gem.t
	sp = gem.sp
	item = gem.item
	S = size
	material = _mat_special if sp != "" else _mat_plain
	if b3 and Board3D.STYLE >= 99 and sp == "" and item != "nug" and t >= 0:
		stone = b3.make_stone(t)
		_sync()
	set_process(stone != null)
	_ore_glow(ore_kind())
	queue_redraw()
	return self

## "ore" (the mine's own), "iron" (the common ore), or "" for a plain stone
func ore_kind() -> String:
	if sp != "" or item != "" or t < 0 or id % 3 != 0: return ""
	return BoardSprites.ore_demo.get(t, "")

func _ore_glow(kind: String) -> void:
	if kind == "":
		if ore_glow: ore_glow.queue_free()
		ore_glow = null
		return
	if ore_glow == null:
		ore_glow = Sprite2D.new()
		ore_glow.material = _mat_iron if kind == "iron" else _mat_ore
		ore_glow.light_mask = 0
		add_child(ore_glow)
	ore_glow.texture = BoardSprites.gem_ore_glow(t, kind)
	ore_glow.scale = Vector2.ONE * S * BoardSprites.SPAN / float(ore_glow.texture.get_width())

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
		BoardSprites.draw(self, BoardSprites.gem_ore(t, kind) if kind != "" else BoardSprites.gem(t), Vector2.ZERO, S)
