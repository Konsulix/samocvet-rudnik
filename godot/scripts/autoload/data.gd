extends Node
## The game's tables (levels, minerals, mines, equipment, jewellery), exported from the prototype
## by tools/export_data.js. Read-only at runtime.

var SP: Dictionary          # mineral id -> {n, c, v, r}
var GR: Array               # quality grades C..AAA
var LEVELS: Array
var AREAS: Array
var CHEST: Array
var SETS: Array
var DEPTHS: Array
var DMODS: Array
var DSHORT: Array
var EQUIP: Array
var JEWELS: Array
var CUTS: Array
var CUTN: Dictionary
var PRE: Array
var BOOSTS: Array
var GEMS: Array             # the board's stone colours
var RAR: Array
var RC: Array
var HABIT: Dictionary
var TRAITS: Array
var TR: Dictionary          # trait id -> trait

const NUGGETY := ["gold", "nativecu"]

func _init() -> void:
	var f := FileAccess.open("res://data/game_data.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	for k in d:
		set(k, d[k])
	TRAITS.append_array(SpecGenome.EXTRA_TRAITS)
	for t in TRAITS:
		TR[t.id] = t

func sp_color(id: String) -> Color:
	return Color.html(SP[id].c)

func rarity_color(tier: int) -> Color:
	return Color.html(RC[clampi(tier, 0, 4)])

## a level past the hand-made ones remixes a layout, a little tighter each time
func level_def(n: int) -> Dictionary:
	if n <= LEVELS.size():
		return LEVELS[n - 1]
	var base: Dictionary = LEVELS[3 + (n * 7) % (LEVELS.size() - 3)].duplicate()
	base.moves = maxi(18, int(base.moves) - (n - LEVELS.size()) / 3)
	base.hard = n % 8 == 0
	return base

func depth_cost(area: int, k: int) -> int:
	return int(round(DEPTHS[k].cost * (1.0 + area * 0.8) / 50.0)) * 50

func depth_pay(dl: int) -> float:
	return 1.0 + dl * 0.5

## species that can actually turn up in some mine
func minable() -> Array:
	var out := []
	for id in SP:
		for a in AREAS:
			if a.pool.has(id):
				out.append(id)
				break
	return out

## pre-boosters a win streak gives for free
func streak_free(streak: int) -> Array:
	var out := []
	if streak >= 2: out.append("rocket")
	if streak >= 4: out.append("bomb")
	if streak >= 6: out.append("orb")
	return out

func streak_text(streak: int) -> String:
	var f := streak_free(streak)
	if f.is_empty():
		return "Ещё победа — и динамит на старте бесплатно."
	var names := []
	for p in PRE:
		if p.id in f: names.append(String(p.n).to_lower())
	return "Бесплатно на старте: %s." % ", ".join(names)
