class_name BoardSprites
extends RefCounted
## Pre-rendered pieces for the board (Blender, see prototype/tools/blender/gem_sprites.py and
## board_sprites.py). Each sprite covers 1.15 cells: the stone plus its soft shadow.

const SPAN := 1.15
const GEMS := ["ruby", "sapphire", "emerald", "citrine", "amethyst", "diamond"]
static var _tex := {}
## the looks the player picks from in a level (Level._show_looks), all kept in the save:
## gem sets: Blender-rendered (gem_kit.py) or drawn (PNG sheets, art/board); "" = the original cut stones, by command line only
const GEM_STYLES := {natural = "Natural", faceted = "Faceted", drawn_natural = "Natural · drawn", drawn_faceted = "Faceted · drawn"}
const GEM_DIRS := {natural = "res://assets/board/gems_kit/natural", faceted = "res://assets/board/gems_kit/faceted",
	drawn_natural = "res://assets/board/gems_natural", drawn_faceted = "res://assets/board/gems_shaped"}
# the drawn sheets fill their sprite more: shown smaller, to stand as tall as the rendered ones
const GEM_SCALE := {drawn_natural = 0.82, drawn_faceted = 0.82}
## how an ore-bearing stone shows its ore: rendered into it (the Blender sets only; drawn sets fall back to
## veins), veins painted over any gem by a shader, or a small badge at its corner
const ORE_LOOKS := {rendered = "Inside", veins = "Veins", badge = "Badge"}
## timber locks: rendered (special_kit.py), drawn (PNG), or the first board's
const LOCK_STYLES := {rendered = "Rendered", drawn = "Drawn", classic = "Classic"}
static var gem_style := "natural"
static var ore_look := "rendered"
static var lock_style := "rendered"
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
	# the gem sets come with their own specials and timber (special_kit.py) and gold nugget (gem_kit.py, items/gold.png)
	if gem_style != "" and name in ["rh", "rv", "bomb", "drill", "orb", "pick"]: path = "res://assets/board/special_kit/%s.png" % name
	if name == "lock" and gem_style != "":
		path = {rendered = "res://assets/board/special_kit/lock.png", drawn = "res://assets/board/blockers_natural/lock.png"}.get(lock_style, path)
	# the gem sets come with their own gold nugget (gem_kit.py, items/gold.png)
	if name == "nug" and gem_style != "": path = "res://assets/board/gems_kit/items/gold.png"
	if not _tex.has(path):
		_tex[path] = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(path)
	return _tex[path]

## ore-bearing stones are not in the rules yet: for a look, `-- ore=0,3 iron=1` shows every third stone of those
## colours holding the mine's own ore ("ore": glowing veins) or iron ("iron": steel cubes); colour -> kind.
## gem_kit.py renders <name>_<kind>.png and <name>_<kind>_glow.png
static var ore_demo := {}

static func gem_ore(t: int, kind: String) -> Texture2D:
	return tex(GEMS[t % GEMS.size()] + "_" + kind)

static func gem_ore_glow(t: int, kind: String) -> Texture2D:
	return tex(GEMS[t % GEMS.size()] + "_" + kind + "_glow")

## the blockers that go with the gem sets (blocker_kit.py): "" when the cut-stone set is shown
static func blocker(name: String) -> Texture2D:
	if gem_style == "": return tex(name)
	var path := "res://assets/board/blockers_kit/%s.png" % name
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

## where on a special's sprite the game draws its live touches (special_kit.py's anchors.json): fuse sparks, the radar
static var _anchors := {}
static func anchors(name: String) -> Dictionary:
	if _anchors.is_empty():
		var f := FileAccess.open("res://assets/board/special_kit/anchors.json", FileAccess.READ)
		if f: _anchors = JSON.parse_string(f.get_as_text())
	return _anchors.get(name, {})

static func gem_path(name: String, style := "-") -> String:
	if style == "-": style = gem_style
	return "res://assets/board/gems/%s.png" % name if style == "" else "%s/%s.png" % [GEM_DIRS.get(style, GEM_DIRS.natural), name]

static func gem_in_style(t: int, style: String) -> Texture2D:
	var path := gem_path(GEMS[t % GEMS.size()], style)
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

static func gem_scale(style := "-") -> float:
	return GEM_SCALE.get(gem_style if style == "-" else style, 1.0)

## the ore look actually used: a drawn set has no ore rendered into it
static func ore_look_now() -> String:
	return "veins" if ore_look == "rendered" and not gem_style in ["natural", "faceted"] else ore_look

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
