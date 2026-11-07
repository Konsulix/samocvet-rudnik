class_name Stones
extends RefCounted
## Rolling a mineral find: species from the mine's pool, kind, quality, rare traits, weight and price.
## Same formulas and seeds as the prototype.

const LEGEND_V := 1300.0 # a living effect's own worth, before depth
const LEGEND_K := 1.5    # and the stone under it counts this much more
const LEGEND_P := 0.002  # how often a find is legendary, × (1 + luck): a jackpot, kept, but rare (was 0.02, playtest 31.10)
const VALUE_K := 1.9     # the grade's old average worth, folded into every price when the grade went (playtest 31.10)

## how well it came out of the rock (BoardModel.find.integ, 0..100): the only quality there is now - the old random
## grade is gone (it was a letter nobody could read). [least integrity, name, worth]
const CONDITION := [[100, "Pristine", 1.15], [80, "Fine", 1.0], [50, "Chipped", 0.7], [0, "Damaged", 0.45]]
static func condition(integ: int) -> Array:
	for c: Array in CONDITION:
		if integ >= int(c[0]): return c
	return CONDITION[-1]

static func pick_w(entries: Array, rng: Rng32) -> Variant:
	var total := 0.0
	for e in entries:
		total += e[1]
	var r := rng.next() * total
	for e in entries:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return entries[-1][0]

## rare traits: each one changes the look and the price
static func roll_traits(id: int, legend: bool, gi: int) -> Array:
	var rng := Rng32.new(id * 7919 + 13)
	var luck: float = 1.3 + Save.d.lab * 0.1 + (1.2 if legend else 0.0)
	var out := []
	for t in Data.TRAITS:
		if rng.next() < t.p * luck:
			out.append(t.id)
	return out.slice(0, 4)

## a find's price above a mine's ceiling grows slowly (a soft cap): the jackpot stays, but one stone no longer buys a
## whole mine (playtest 31.10: 14 602 for an emerald when a drill cost 1–2 thousand)
const CAP := 2500.0       # the first mine's; each next one ×(1 + CAP_AREA × mine)
const CAP_AREA := 0.6
static func capped(v: float, area: int) -> float:
	var c := CAP * (1.0 + CAP_AREA * area)
	return v if v <= c else c * (1.0 + log(v / c))

## the depth each species of a mine starts to turn up at (playtest 31.10: every species from the first level filled the
## atlas in two depths): the commonest three from the top, then one more each depth, the rarest (r 2+) not before the
## last two; they add up, the old ones stay
static func opens_at(area: int) -> Dictionary:
	var A: Dictionary = Data.AREAS[mini(area, Data.AREAS.size() - 1)]
	var pool: Dictionary = A.pool
	var ids: Array = pool.keys()
	ids.sort_custom(func(x, y): return int(Data.SP[x].r) < int(Data.SP[y].r) or (int(Data.SP[x].r) == int(Data.SP[y].r) and float(pool[x]) > float(pool[y])))
	var last := maxi(0, Data.depths(area).size() - 1)
	var out := {}
	var mid := ids.size() - 4          # between the first three and the rarest: spread over depths 1 .. last-2
	for i in ids.size():
		var d := 0
		if i == ids.size() - 1 and ids.size() > 3: d = maxi(1, last - 1)
		elif i >= 3: d = 1 + (roundi(float(i - 3) * float(maxi(0, last - 3)) / float(maxi(1, mid - 1))) if mid > 1 else 0)
		out[ids[i]] = mini(d, last)
	return out

## a mine's species that can turn up at depth dl, [id, weight]: the one new here twice as often, so it is met
static func pool_at(area: int, dl: int) -> Array:
	var pool: Dictionary = Data.AREAS[mini(area, Data.AREAS.size() - 1)].pool
	var at := opens_at(area)
	var out := []
	for s in pool:
		if int(at[s]) <= dl:
			out.append([s, float(pool[s]) * (2.0 if int(at[s]) == dl and dl > 0 else 1.0)])
	return out

## Skulls of Koschei's barrow (SpecSkull, docs/skulls.md): there about every fourth find is a skull, the barrow's
## crystal growing out of it. What it is cast in, by depth (the tale's layers): plain bone near the top, nacre, gold leaf
## and the mosaic further down, glass by the duck's lake, cast gold, silver and copper only in the hoard — rare, so a
## golden skull stays an event. Its own random stream: the rest of the find rolls as before.
const SKULL_AREAS := {6: 0.36}   # (of the finds that can be one: about every fourth find in all)
const SKULL_SP := ["vivianite", "apatite", "morion", "pyrope", "venom"]   # (prisms and garnets grow a crown; not the needle)
const SKULL_SKINS := ["bone", "nacre", "gilt", "kintsugi", "glass", "gold", "silver", "copper"]
const SKULL_N := {bone = "Bone Skull", nacre = "Nacre Skull", gilt = "Gilded Skull", kintsugi = "Kintsugi Skull", glass = "Crystal Skull",
	gold = "Golden Skull", silver = "Silver Skull", copper = "Copper Skull"}
const SKULL_V := {bone = 1.6, nacre = 2.4, gilt = 2.6, kintsugi = 3.2, glass = 3.8, gold = 5.5, silver = 4.5, copper = 4.0}
const SKULL_TIER := {bone = 1, nacre = 2, gilt = 2, kintsugi = 3, glass = 3, gold = 3, silver = 3, copper = 3}
const SKULL_COL := {bone = Color("#cfc2a4"), nacre = Color("#9fb6c9"), gilt = Color("#d9b25a"), kintsugi = Color("#c9744f"),
	glass = Color("#bfe3ef"), gold = Color("#e8c35a"), silver = Color("#d8dbe2"), copper = Color("#d0805a")}
## the skins at each depth of the barrow (index = depth): [skin, weight]
const SKULL_AT := [
	[["bone", 1.0]], [["bone", 1.0]],
	[["bone", 70.0], ["nacre", 15.0], ["gilt", 10.0], ["kintsugi", 5.0]],
	[["bone", 70.0], ["nacre", 15.0], ["gilt", 10.0], ["kintsugi", 5.0]],
	[["bone", 70.0], ["nacre", 15.0], ["gilt", 10.0], ["kintsugi", 5.0]],
	[["bone", 60.0], ["nacre", 12.0], ["gilt", 8.0], ["kintsugi", 5.0], ["glass", 15.0]],
	[["bone", 65.0], ["nacre", 15.0], ["gilt", 12.0], ["kintsugi", 8.0]],
	[["bone", 50.0], ["nacre", 10.0], ["gilt", 15.0], ["kintsugi", 8.0], ["gold", 8.0], ["silver", 5.0], ["copper", 4.0]],
	[["bone", 60.0], ["nacre", 15.0], ["gilt", 10.0], ["kintsugi", 8.0], ["glass", 7.0]]]

## the very first find in a mine with skulls is one picked by eye (the seed and genes as `spec_gallery -- area=6
## sp=pyrope form=skull base=700 skin=bone moss=cap tree_kind=blossom stream=1 wine=1` draws its second): a dark skull,
## a crown of pyrope, moss, a scarlet spring from the eye — the mine shows what it holds at once. Null if already found.
const FIRST_SKULL := {6: {seed = 708, sid = "pyrope", gi = 3, skin = "bone", moss = "cap", tree_kind = "blossom", stream = true, wine = true, flies = 0}}
static func first_find(area: int, luck: float, dl: int) -> Variant:
	if not FIRST_SKULL.has(area) or Save.told("first_find_%d" % area): return null
	var f: Dictionary = FIRST_SKULL[area]
	var st := roll(int(f.seed), area, luck, dl)
	st.id = int(f.seed)
	st.sid = f.sid
	st.kind = "druse"
	st.gi = int(f.gi)
	st.traits = []
	st.legend = false
	st.erase("fx")
	st.form = "skull"
	for k in ["skin", "moss", "tree_kind", "stream", "wine", "flies"]: st[k] = f[k]
	st.value = roundi(float(Data.SP[f.sid].v) * VALUE_K * float(SKULL_V[f.skin]) * 1.4 * 1.3)
	st.tier = maxi(tier_of(st.sid, st.gi, false), int(SKULL_TIER[f.skin]))
	st.first_of = area
	return st

## a find's name: the species, or for a skull its kind ("Gilded Skull")
static func name_of(s: Dictionary) -> String:
	if String(s.get("form", "")) == "skull" and s.has("skin"):
		# (a plain bone one is named by its crystal: "Pyrope Skull"; the rest by what they are: "Gilded Skull")
		if s.skin == "bone": return "%s Skull" % Data.SP[s.sid].n
		return String(SKULL_N.get(s.skin, "Skull"))
	return String(Data.SP[s.sid].n)

## the page of the atlas (and the pile in the inventory) a find belongs to: its species, or skull_<kind>
static func atlas_id(s: Dictionary) -> String:
	if String(s.get("form", "")) == "skull" and s.has("skin"): return "skull_" + String(s.skin)
	return String(s.sid)

static func roll(seed_id: int, area: int, luck: float, dl: int = 0) -> Dictionary:
	var rng := Rng32.new((seed_id * 2246822519) % 4294967296)
	var entries := []
	for e: Array in pool_at(area, dl):
		entries.append([e[0], float(e[1]) * pow(1.0 + luck * 0.8, Data.SP[e[0]].r)])
	var sid: String = pick_w(entries, rng)
	var kind: String = "nugget" if sid in Data.NUGGETY else "fossil" if Data.HABIT.get(sid, "") == "fossil" else pick_w(SpecLooks.kinds(sid), rng)
	var ge := []
	for k in Data.GR.size():
		ge.append([k, Data.GR[k].w * pow(1.0 + luck * 0.5, k * 0.6)])
	var gi: int = pick_w(ge, rng)
	# `gi` is now only how clear the stone is (SpecimenBuilder: milkier below 2), rolled as the grade was so the
	# stones look as they did; it no longer touches the price or the rarity
	var legend := rng.next() < LEGEND_P * (1.0 + luck)
	var traits := roll_traits(seed_id, legend, gi)
	# the traits a species rolls more often (amethyst's sceptres, rock crystal's phantoms): their own stream
	var more: Dictionary = SpecLooks.of(sid).get("more", {})
	if more.size():
		var mr := Rng32.new((seed_id * 3266489917 + 101) % 4294967296)
		for t: String in more:
			if mr.next() < float(more[t]) and not t in traits and traits.size() < 4:
				traits.append(t)
	# the traits add up (multiplied, three rare ones made a jackpot of a common stone)
	var tm := 1.0
	for t in traits:
		tm += float(Data.TR[t].m) - 1.0
	var base_g := 400.0 if kind == "druse" else 900.0 if kind == "geode" else 20.0 if kind == "nugget" else 250.0 if kind == "fossil" else 60.0
	if sid == "pearl": base_g = 30.0   # its oyster, mostly
	var g := roundi(base_g * pow(6.0, rng.next()) * (3.0 if legend else 1.0) * (1.0 + dl * 0.35))
	var kind_m := 1.4 if kind == "druse" else 1.6 if kind == "geode" else 1.0
	if kind == "fossil":
		# a shell nearly all ammolite is worth many plain ones
		var fg := SpecFossil.genes(seed_id, sid, traits)
		kind_m *= 1.0 + 8.0 * pow(float(fg.get("nacre", 0.0)), 3.0)
		# and blue or violet fire is rarer, so dearer — the more nacre there is to show it
		var fire_m: float = {red = 1.0, green = 1.3, blue = 2.0, violet = 2.6}.get(fg.get("fire", "red"), 1.0)
		kind_m *= 1.0 + (fire_m - 1.0) * float(fg.get("nacre", 0.0))
		# a matched pair, a brood on one slab, a rare uncoiled form
		if fg.get("pair", false): kind_m *= 1.6
		kind_m *= 1.0 + 0.25 * int(fg.get("brood", 0))
		if String(fg.get("hetero", "")) != "": kind_m *= 3.0
		# wood: opal in it, a crystal heart
		kind_m *= 1.0 + 6.0 * pow(float(fg.get("opal", 0.0)), 2.0)
		if String(fg.get("heart", "")) != "": kind_m *= 1.8
		# trilobites: spiny kinds are rare and hard to prepare; pyrite, legs, a moult, a bite, a whole plate
		if sid == "trilobite":
			kind_m *= {dicranurus = 2.5, walliserops = 3.0, asaphus = 1.8, phacops = 1.2}.get(fg.get("genus", ""), 1.0)
			if int(fg.get("pal", 0)) == 4: kind_m *= 1.6
			if fg.get("soft", false): kind_m *= 4.0
			if fg.get("moult", false): kind_m *= 1.4
			if fg.get("bite", false): kind_m *= 1.3
			if fg.get("show", "") == "mass": kind_m *= 1.0 + 0.2 * int(fg.get("mass", 1))
			if fg.get("show", "") == "nodule": kind_m *= 1.5
			if int(fg.get("pal", 0)) == 6: kind_m *= 5.0
			kind_m *= 1.0 + 0.8 * int(fg.get("oysters", 0))
			# and how well it kept
			kind_m *= 0.4 + 0.8 * float(fg.get("keep", 1.0))
		# fossil leaves: gold or silver film, both halves of the split, a ginkgo
		if sid == "fern":
			kind_m *= [1.0, 1.9, 1.4, 1.1, 1.0, 1.3, 1.2, 2.4, 2.8][int(fg.get("film", 0))]
			if String(fg.get("crystals", "")) != "": kind_m *= 1.5
			if fg.get("pair", false): kind_m *= 1.6
			kind_m *= {ginkgo = 1.2, palm = 1.4, annularia = 1.1, lepido = 1.1}.get(fg.get("plant", ""), 1.0)
			# a split ironstone nodule; a dragonfly or a fish on the same slab
			if fg.get("show", "") == "nodule": kind_m *= 1.3
			kind_m *= {dragonfly = 2.2, fish = 1.8}.get(fg.get("guest", ""), 1.0)
		# pearls: the body (conch and melo are the rarest), roundness, luster, more than one
		if sid == "pearl":
			kind_m *= {tahitian = 1.5, golden = 1.4, south_sea = 1.3, conch = 3.0, melo = 2.5}.get(fg.get("body", ""), 1.0)
			kind_m *= {round = 1.3, baroque = 0.8, circled = 0.8}.get(fg.get("shape", ""), 1.0)
			kind_m *= 0.6 + float(fg.get("luster", 0.5))
			if int(fg.get("count", 1)) > 1: kind_m *= 1.5
	# the barrow: now and then a skull (see SKULL_AREAS)
	var skull := ""
	if SKULL_AREAS.has(area) and sid in SKULL_SP and not legend:
		var sr := Rng32.new((seed_id * 2654435761 + 7) % 4294967296)
		if sr.next() < float(SKULL_AREAS[area]):
			var at: Array = SKULL_AT[clampi(dl, 0, SKULL_AT.size() - 1)]
			skull = pick_w(at, sr)
			kind = "druse"
			kind_m *= float(SKULL_V[skull])
			g = roundi(900.0 * (1.0 + sr.next() * 0.8))
	var value: float = float(Data.SP[sid].v) * VALUE_K * tm * kind_m
	# a living effect is worth the same on any body: added, not multiplied, so a legendary pyrite
	# outprices a plain emerald (it is about as rare); the stone itself still counts a little more
	if legend:
		value = value * LEGEND_K + LEGEND_V
	value *= 1.3 * (1.0 + dl * 0.25)
	value = capped(value, area)
	var out := {id = seed_id, sid = sid, kind = kind, gi = gi, traits = traits, legend = legend, g = g, value = roundi(value), tier = tier_of(sid, gi, legend)}
	if skull != "":
		out.form = "skull"
		out.skin = skull
		out.tier = maxi(int(out.tier), int(SKULL_TIER[skull]))
	return out

## a legendary find is always the top tier, whatever its body
static func tier_of(sid: String, gi: int, legend: bool) -> int:
	if legend:
		return 4
	return mini(4, int(Data.SP[sid].r))

static func fmt_weight(g: int) -> String:
	if g >= 1000:
		return "%.2f kg" % (g / 1000.0)
	return "%d g" % g
