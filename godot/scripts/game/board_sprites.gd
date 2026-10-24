class_name BoardSprites
extends RefCounted
## Pre-rendered pieces for the board (Blender, see prototype/tools/blender/gem_sprites.py and
## board_sprites.py). Each sprite covers 1.15 cells: the stone plus its soft shadow.

const SPAN := 1.15
const GEMS := ["ruby", "sapphire", "emerald", "citrine", "amethyst", "diamond"]
# Natural stone playtest; the original cut sprites remain in assets/board/gems.
const GEM_DIR := "res://assets/board/gems_natural"
const GEM_STYLES := {"natural": "Natural", "shaped": "Faceted"}
const GEM_DIRS := {"natural": GEM_DIR, "shaped": "res://assets/board/gems_shaped"}
static var gem_style := "natural"
const COLLECTION_DIR := "res://assets/board/mineral_collection"
const DEPOSIT_DIR := "res://assets/board/deposits"
const DEPOSIT_CORE := Rect2(64, 64, 384, 384)
const BLOCKER_DIR := "res://assets/board/blockers_natural"
const BLOCKERS := ["mud", "rock1", "rock2", "rock_cracked", "gas", "lock"]
const NUG_SKINS := ["gold", "dark", "opal", "green", "rose"]
static var nug_skin := "gold"
static var _tex := {}
static var _plain_material: ShaderMaterial

## Use the board's explicit shader for sprites that must survive iOS shader baking.
static func plain_material() -> ShaderMaterial:
	if _plain_material == null:
		_plain_material = ShaderMaterial.new()
		_plain_material.shader = preload("res://shaders/gem_glint.gdshader")
		_plain_material.set_shader_parameter("strength", 0.0)
	return _plain_material

static func tex(name: String) -> Texture2D:
	return _texture(_path(name))

static func _texture(path: String) -> Texture2D:
	# Cache by resolved path so switching skins never returns the previous style.
	if not _tex.has(path):
		_tex[path] = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(path)
	return _tex[path]

static func gem_in_style(t: int, style: String) -> Texture2D:
	return _texture("%s/%s.png" % [GEM_DIRS.get(style, GEM_DIR), GEMS[t % GEMS.size()]])

static func _path(name: String) -> String:
	if name in BLOCKERS:
		return "%s/%s.png" % [BLOCKER_DIR, name]
	if name.begins_with("deposit_"):
		return "%s/%s.png" % [DEPOSIT_DIR, name]
	if name in GEMS:
		return "%s/%s.png" % [GEM_DIRS.get(gem_style, GEM_DIR), name]
	if name == "nug":
		var skin: String = nug_skin if nug_skin in NUG_SKINS else "gold"
		return "%s/%s.png" % [COLLECTION_DIR, skin]
	return "res://assets/board/pieces/%s.png" % name

## start loading every board sprite on background threads, so the first level does not read them from disk
## mid-frame; tex() then picks up the finished ones
static func preload_all() -> void:
	for p in paths():
		ResourceLoader.load_threaded_request(p)

static func paths() -> Array:
	var out := []
	for name in BLOCKERS:
		out.append(_path(name))
	for kind in ["geode", "mineral"]:
		for stage in 5:
			out.append(_path("deposit_%s_%d" % [kind, stage]))
	for directory in GEM_DIRS.values():
		for name in GEMS:
			out.append("%s/%s.png" % [directory, name])
	for f in ResourceLoader.list_directory("res://assets/board/pieces/"):
		if f.ends_with(".png"):
			var path := _path(f.get_basename())
			if path not in out: out.append(path)
	return out

static func rock_name(hp: int, strong: bool) -> String:
	return "rock2" if hp >= 2 else ("rock_cracked" if strong else "rock1")

static func gem(t: int) -> Texture2D:
	return tex(GEMS[t % GEMS.size()])

## draw a sprite centred on `c`, one cell `S` wide
static func draw(ci: CanvasItem, t: Texture2D, c: Vector2, S: float, mod := Color.WHITE) -> void:
	var w := S * SPAN
	ci.draw_texture_rect(t, Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w)), false, mod)
