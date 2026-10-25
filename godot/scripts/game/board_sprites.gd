class_name BoardSprites
extends RefCounted
## Pre-rendered pieces for the board (Blender, see prototype/tools/blender/gem_sprites.py and
## board_sprites.py). Each sprite covers 1.15 cells: the stone plus its soft shadow.

const SPAN := 1.15
const GEMS := ["ruby", "sapphire", "emerald", "citrine", "amethyst", "diamond"]
static var _tex := {}
## which set of gems the board shows: "" the cut stones (assets/board/gems), or a style rendered by
## prototype/tools/blender/gem_kit.py into assets/board/gems_kit/<style>/ ("natural", "faceted")
static var gem_style := ""
static var _plain_material: ShaderMaterial

## Use the board's explicit shader for sprites that must survive iOS shader baking.
static func plain_material() -> ShaderMaterial:
	if _plain_material == null:
		_plain_material = ShaderMaterial.new()
		_plain_material.shader = preload("res://shaders/gem_glint.gdshader")
		_plain_material.set_shader_parameter("strength", 0.0)
	return _plain_material

static func tex(name: String) -> Texture2D:
	var path := gem_path(name) if name.get_slice("_", 0) in GEMS else "res://assets/board/pieces/%s.png" % name
	if not _tex.has(path):
		_tex[path] = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(path)
	return _tex[path]

## ore-bearing stones are not in the rules yet: for a look, `-- ore=0,2` shows every third stone of those
## colours holding ore (gem_kit.py renders <name>_ore.png)
static var ore_demo := {}

static func gem_ore(t: int) -> Texture2D:
	return tex(GEMS[t % GEMS.size()] + "_ore")

static func gem_ore_glow(t: int) -> Texture2D:
	return tex(GEMS[t % GEMS.size()] + "_ore_glow")

static func gem_path(name: String) -> String:
	return "res://assets/board/gems/%s.png" % name if gem_style == "" else "res://assets/board/gems_kit/%s/%s.png" % [gem_style, name]

## start loading every board sprite on background threads, so the first level does not read them from disk
## mid-frame; tex() then picks up the finished ones
static func preload_all() -> void:
	for p in paths():
		ResourceLoader.load_threaded_request(p)

static func paths() -> Array:
	var out := []
	for name in GEMS:
		out.append(gem_path(name))
	for f in ResourceLoader.list_directory("res://assets/board/pieces/"):
		if f.ends_with(".png"):
			out.append("res://assets/board/pieces/" + f)
	return out

static func gem(t: int) -> Texture2D:
	return tex(GEMS[t % GEMS.size()])

## draw a sprite centred on `c`, one cell `S` wide
static func draw(ci: CanvasItem, t: Texture2D, c: Vector2, S: float, mod := Color.WHITE) -> void:
	var w := S * SPAN
	ci.draw_texture_rect(t, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false, mod)
