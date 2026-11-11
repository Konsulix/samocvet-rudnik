extends Node
## The game's tables (levels, minerals, mines, equipment, jewellery), exported from the prototype
## by tools/export_data.js. Read-only at runtime.

var SP: Dictionary          # mineral id -> {n, c, v, r}
var GR: Array               # quality grades C..AAA
var LEVELS: Array
var AREAS: Array
var CHEST: Array
var SETS: Array
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

## a mine's depths, top first: {m, fe, au (the veins' stock), tool, machine, drill = [iron, coins] to dig down to it}
func depths(area: int) -> Array:
	return AREAS[mini(area, AREAS.size() - 1)].depths

func depth(area: int, k: int) -> Dictionary:
	var ds := depths(area)
	return ds[clampi(k, 0, ds.size() - 1)]

func depth_m(area: int, k: int) -> int:
	return int(depth(area, k).m)

## a booster opens once the first mine is dug down to its depth (`at`, a depth index); past the first mine all are open
func boost_open(bo: Dictionary) -> bool:
	return Save.reached() > 0 or bool(Save.d.boss_won[0]) or int(Save.d.depth[0]) >= int(bo.get("at", 0))

## the mine's own ore: {n, c, iron (colour holding iron), local (colour holding it)}
func ore(area: int) -> Dictionary:
	return AREAS[mini(area, AREAS.size() - 1)].ore

func depth_pay(dl: int) -> float:
	return 1.0 + dl * 0.2

## species that can actually turn up in some mine
func minable() -> Array:
	var out := []
	for id in SP:
		for a in AREAS:
			if a.pool.has(id):
				out.append(id)
				break
	return out

## five more moves when they run out, the k-th time in this level (k from 0): dearer every time and in every mine;
## from the second on it brings a stick of dynamite too, as in Royal Match. To be tuned by playing (playtest 31.10)
const CONTINUE_BASE := 400        # coins, the first time, in the first mine
const CONTINUE_STEP := 2.5        # each next time in the same level costs this much more
const CONTINUE_AREA := 0.5        # each next mine: the base × (1 + this × mine)
func continue_price(k: int, area: int) -> int:
	return roundi(CONTINUE_BASE * (1.0 + CONTINUE_AREA * area) * pow(CONTINUE_STEP, k) / 50.0) * 50

## pre-boosters a win streak gives for free, as Royal Match's Butler's Gift: from the third win in a row, a step more
## later, kept till a level is lost. The levels are tuned WITHOUT them (LevelGen.WORK, 10.11): with all three (dynamite,
## bundle, resonator from the 7th win) the smart bot won 95% of hard levels and the next loss reset it to nothing, so
## the bundle comes a win later and the resonator only on a long streak, from the 10th win
const STREAK_AT := {rocket = 3, bomb = 6, orb = 10}
func streak_free(streak: int) -> Array:
	var out := []
	for k: String in STREAK_AT:
		if streak >= int(STREAK_AT[k]): out.append(k)
	return out
