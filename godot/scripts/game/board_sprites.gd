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
## the big blocks (geodes, the sealed find): rendered by zone_kit.py in two looks, or the first board's drawing
const ZONE_STYLES := {hewn = "Hewn", pillow = "Pillow", classic = "Classic"}
static var zone_style := "hewn"
## the level's sealed find as "<w>x<h>": its goal icon is that very block (Level sets it)
static var find_shape := "2x2"
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
	# the boosters: painted by GPT in the drawn board's look (art/boosters: gen.sh, cut.py), the same for every set
	if name in ["pick", "bore_h", "bore_v", "pan", "pan_bowl", "pan_load"]: path = "res://assets/board/boosters/%s.png" % name
	if name == "lock" and gem_style != "":
		path = {rendered = "res://assets/board/special_kit/lock.png", drawn = "res://assets/board/blockers_natural/lock.png"}.get(lock_style, path)
	# the gem sets come with their own gold nugget (gem_kit.py, items/gold.png)
	if name == "nug" and gem_style != "": path = "res://assets/board/gems_kit/items/gold.png"
	if not _tex.has(path):
		_tex[path] = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else load(path)
	return _tex[path]

## ore-bearing stones (BoardModel.Gem.ore) hold the mine's own ore ("ore": glowing veins) or iron ("iron": steel cubes);
## gem_kit.py renders <name>_<kind>.png and <name>_<kind>_glow.png

static func gem_ore(t: int, kind: String) -> Texture2D:
	return tex(GEMS[t % GEMS.size()] + "_" + kind)

static func gem_ore_glow(t: int, kind: String) -> Texture2D:
	return tex(GEMS[t % GEMS.size()] + "_" + kind + "_glow")

## the two-hit rock of a mine, by Data.AREAS order: Copper Mountain's is serpentine with malachite and copper
## (art/malachite/block_cut.py), the others granite
const AREA_GRANITE := {1: "serpentine"}
static func granite() -> String:
	return AREA_GRANITE.get(Save.area(), "granite")

## the light of this mine's ore, for its shimmer and its painted veins: the data's "hot", or gold's
static func ore_hot() -> Vector3:
	var c := Color.html(String(Data.ore(Save.area()).get("hot", "#ffc75c")))
	return Vector3(c.r, c.g, c.b)

## a big block's small square icon (prototype/tools/zone_icons.py): "find_2x2", "geode_2x2"... in this look.
## The interface never draws the board's own block sprites: on iPhone those came out as plain white squares there
static func zone_icon(name: String, look := "") -> Texture2D:
	var path := "res://assets/board/zones/%s/icon/%s.png" % [zone_style if look == "" else look, name]
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

## the blockers that go with the gem sets (blocker_kit.py): "" when the cut-stone set is shown
static func blocker(name: String) -> Texture2D:
	if gem_style == "": return tex(name)
	var path := "res://assets/board/blockers_kit/%s.png" % name
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

## Copper Mountain's malachite (GPT drawings cut up by art/malachite/parts_cut.py and nodule_pack.py): the crust over a
## stone, whole and plate by plate, and the nodule's three stages, bubble by bubble. Three looks of each; a cell keeps one
static func malachite(name: String) -> Texture2D:
	var path := "res://assets/board/malachite/%s.png" % name
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

## the Mistress' stone flower and its petals (art/boss/stone_flower.py, pixel art): flower_s1..3, flower_<ring>_<k>
static func flower(name: String) -> Texture2D:
	var path := "res://assets/boss/mistress/%s.png" % name
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

static var _flower_info := {}
static func flower_info() -> Dictionary:
	if _flower_info.is_empty():
		var f := FileAccess.open("res://assets/boss/mistress/flower.json", FileAccess.READ)
		if f: _flower_info = JSON.parse_string(f.get_as_text())
	return _flower_info

## crust.json / nodule.json: where each plate or bubble sits from the sprite's middle (cells), and the nodule's stages
static var _mal_info := {}
static func malachite_info(name: String) -> Dictionary:
	if not _mal_info.has(name):
		var f := FileAccess.open("res://assets/board/malachite/%s.json" % name, FileAccess.READ)
		_mal_info[name] = JSON.parse_string(f.get_as_text()) if f else {}
	return _mal_info[name]

static func malachite_look(r: int, c: int) -> int:
	return (r * 5 + c * 3) % 3

## where on a special's sprite the game draws its live touches (special_kit.py's anchors.json): fuse sparks, the radar
static var _anchors := {}
static func anchors(name: String) -> Dictionary:
	if _anchors.is_empty():
		var f := FileAccess.open("res://assets/board/special_kit/anchors.json", FileAccess.READ)
		if f: _anchors = JSON.parse_string(f.get_as_text())
	return _anchors.get(name, {})

## the points the boosters are animated by (art/boosters/cut.py's anchors.json), as sprite UVs: the pick's grip and
## blade tip, where a drill's auger begins and its tip, the middle of the pan's load
static var _boost := {}
static func booster_anchor(name: String) -> Dictionary:
	if _boost.is_empty():
		var f := FileAccess.open("res://assets/board/boosters/anchors.json", FileAccess.READ)
		if f: _boost = JSON.parse_string(f.get_as_text())
	return _boost.get(name, {})

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
