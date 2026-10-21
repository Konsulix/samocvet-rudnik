class_name GemNode
extends Node2D
## One stone, special or nugget on the board. Draws itself with GemArt; moves and pops are tweened by BoardView.

const GLINT := preload("res://shaders/gem_glint.gdshader")
static var _mat_plain: ShaderMaterial
static var _mat_special: ShaderMaterial

var id := 0
var t := 0
var sp := ""
var item := ""
var S := 46.0

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
	id = gem.id
	t = gem.t
	sp = gem.sp
	item = gem.item
	S = size
	material = _mat_special if sp != "" else _mat_plain
	queue_redraw()
	return self

func become(new_sp: String) -> void:
	sp = new_sp
	material = _mat_special
	queue_redraw()

func _draw() -> void:
	GemArt.begin(self, Transform2D.IDENTITY)
	if item == "nug":
		GemArt.nugget(self, S)
	elif sp != "":
		GemArt.special(self, sp, S)
	elif t >= 0:
		GemArt.gem(self, t, S)
