class_name GemNode
extends Node2D
## One stone, special or nugget on the board, drawn from its pre-rendered sprite; moves and pops are tweened by BoardView.

const GLINT := preload("res://shaders/gem_glint.gdshader")
static var _mat_plain: ShaderMaterial
static var _mat_special: ShaderMaterial

var id := 0
var t := 0
var sp := ""
var item := ""
var S := 46.0
var b3: Board3D               # when set, plain stones are drawn as 3D gems that follow this node
var stone: MeshInstance3D

static func materials() -> void:
	if _mat_plain: return
	_mat_plain = ShaderMaterial.new()
	_mat_plain.shader = GLINT
	_mat_special = ShaderMaterial.new()
	_mat_special.shader = GLINT
	_mat_special.set_shader_parameter("boost", 1.25)
	_mat_special.set_shader_parameter("strength", 0.9)

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
	queue_redraw()
	return self

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
	material = _mat_special
	if stone:
		stone.queue_free()
		stone = null
	queue_redraw()

func _draw() -> void:
	if item == "nug":
		BoardSprites.draw(self, BoardSprites.tex("nug"), Vector2.ZERO, S)
	elif sp != "":
		BoardSprites.draw(self, BoardSprites.tex(sp), Vector2.ZERO, S)
	elif t >= 0 and not stone:
		BoardSprites.draw(self, BoardSprites.gem(t), Vector2.ZERO, S)
