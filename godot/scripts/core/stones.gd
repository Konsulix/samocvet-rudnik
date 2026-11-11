class_name Stones
extends RefCounted
## Rolling a mineral find: species from the mine's pool, kind, quality, rare traits, weight and price.
## Same formulas and seeds as the prototype.

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
## a mine of animal skulls (none yet — a future mine says here which beasts it holds): area → {chance (of its finds that
## become one), beasts [[id, weight], ...]}; the crystal stays the find's species, the skin its own draw (BEAST_SKIN)
const BEAST_AREAS := {}
const BEAST_SKIN := [["bone", 6.0], ["lapis", 1.0], ["feathers", 0.9], ["sugar", 1.2], ["rhodo", 0.9], ["gilt", 1.0], ["nacre", 1.0],
	["kintsugi", 0.7], ["agate", 0.6], ["opal", 0.4], ["gold", 0.35], ["silver", 0.2], ["copper", 0.15]]
const SKULL_AREAS := {6: 0.36}   # (of the finds that can be one: about every fourth find in all)
const SKULL_SP := ["vivianite", "apatite", "morion", "pyrope", "venom"]   # (prisms and garnets grow a crown; not the needle)
const SKULL_SKINS := ["bone", "pyrite", "agate", "nacre", "gilt", "geode", "kintsugi", "opal", "glass", "gold", "silver", "copper"]
const SKULL_N := {bone = "Bone Skull", nacre = "Nacre Skull", gilt = "Gilded Skull", kintsugi = "Kintsugi Skull", glass = "Crystal Skull",
	gold = "Golden Skull", silver = "Silver Skull", copper = "Copper Skull", agate = "Agate Skull", opal = "Opal Skull", pyrite = "Pyrite Skull",
	geode = "Geode Skull", lapis = "Lapis Skull", feathers = "Feathered Skull", sugar = "Sugared Skull", rhodo = "Rhodochrosite Skull"}
const SKULL_V := {agate = 2.8, opal = 4.2, pyrite = 2.2, geode = 3.0, bone = 1.6, nacre = 2.4, gilt = 2.6, kintsugi = 3.2, glass = 3.8, gold = 5.5, silver = 4.5, copper = 4.0,
	lapis = 3.6, feathers = 3.0, sugar = 2.6, rhodo = 2.9}
const SKULL_TIER := {agate = 2, opal = 3, pyrite = 2, geode = 3, bone = 1, nacre = 2, gilt = 2, kintsugi = 3, glass = 3, gold = 3, silver = 3, copper = 3, lapis = 3, feathers = 3, sugar = 2, rhodo = 2}
const SKULL_COL := {bone = Color("#cfc2a4"), nacre = Color("#9fb6c9"), gilt = Color("#d9b25a"), kintsugi = Color("#c9744f"),
	glass = Color("#bfe3ef"), gold = Color("#e8c35a"), silver = Color("#d8dbe2"), copper = Color("#d0805a"), agate = Color("#c27a45"),
	opal = Color("#6f7fd0"), pyrite = Color("#bfa452"), geode = Color("#8a62c4"), lapis = Color("#3a5fc8"), feathers = Color("#3f9a6a"),
	sugar = Color("#9fd36a"), rhodo = Color("#e07a9c")}
## the skins at each depth of the barrow (index = depth): [skin, weight]
const SKULL_AT := [
	[["bone", 1.0]], [["bone", 1.0]],
	[["bone", 70.0], ["pyrite", 8.0], ["agate", 6.0], ["nacre", 10.0], ["gilt", 6.0]],
	[["bone", 65.0], ["pyrite", 6.0], ["agate", 8.0], ["nacre", 12.0], ["gilt", 8.0], ["kintsugi", 4.0]],
	[["bone", 62.0], ["pyrite", 6.0], ["agate", 8.0], ["nacre", 12.0], ["gilt", 8.0], ["kintsugi", 4.0], ["geode", 3.0]],
	[["bone", 55.0], ["nacre", 10.0], ["gilt", 6.0], ["kintsugi", 4.0], ["glass", 15.0], ["geode", 6.0], ["agate", 4.0]],
	[["bone", 55.0], ["nacre", 12.0], ["gilt", 10.0], ["kintsugi", 7.0], ["geode", 8.0], ["opal", 4.0]],
	[["bone", 50.0], ["nacre", 10.0], ["gilt", 15.0], ["kintsugi", 8.0], ["gold", 8.0], ["silver", 5.0], ["copper", 4.0]],
	[["bone", 55.0], ["nacre", 12.0], ["gilt", 8.0], ["kintsugi", 8.0], ["glass", 7.0], ["opal", 6.0], ["geode", 4.0]]]

## the very first find in a mine with skulls is one picked by eye (the seed and genes as `spec_gallery -- area=6
## sp=pyrope form=skull base=700 skin=bone moss=cap tree_kind=blossom stream=1 wine=1` draws its second): a dark skull,
## a crown of pyrope, moss, a scarlet spring from the eye, three blue butterflies — the mine shows what it holds at once. Null if already found.
const FIRST_SKULL := {6: {seed = 708, sid = "pyrope", gi = 3, skin = "bone", moss = "cap", tree_kind = "blossom", stream = true, wine = true, flies = 3, fly_kind = "bluetiger"}}
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
	for k in ["skin", "moss", "tree_kind", "stream", "wine", "flies", "fly_kind"]: st[k] = f[k]
	st.value = roundi(Worth.body(f.sid) * VALUE_K * float(SKULL_V[f.skin]) * 1.4 * 1.3)
	st.tier = maxi(tier_of(st.sid, st.gi, false), int(SKULL_TIER[f.skin]))
	st.first_of = area
	return st

## a find's name: the species, or for a skull its kind ("Gilded Skull")
static func name_of(s: Dictionary) -> String:
	# an animal's: "Wolf Skull", "Gilded Stag Skull" (its crystal shows on the card)
	if String(s.get("form", "")) == "skull" and String(s.get("beast", "")) != "":
		var bn := String(SpecSkull.BEAST_N.get(String(s.beast), "Beast"))
		var skin := String(s.get("skin", "bone"))
		# (feathers are a gene on its card, not a kind of skull: "Mouflon Skull")
		if skin in ["bone", "feathers"]: return "%s Skull" % bn
		return String(SKULL_N.get(skin, "Skull")).replace("Skull", bn + " Skull")
	if String(s.get("form", "")) == "skull" and s.has("skin"):
		# (a plain bone one is named by its crystal: "Pyrope Skull"; the rest by what they are: "Gilded Skull")
		if s.skin == "bone": return "%s Skull" % Data.SP[s.sid].n
		return String(SKULL_N.get(s.skin, "Skull"))
	return String(Data.SP[s.sid].n)

## the page of the atlas (and the pile in the inventory) a find belongs to: its species, or skull_<kind>
static func atlas_id(s: Dictionary) -> String:
	# (an animal's skull: one page / pile per animal, whatever it is dressed in)
	if String(s.get("form", "")) == "skull" and String(s.get("beast", "")) != "": return "beast_" + String(s.beast)
	if String(s.get("form", "")) == "skull" and s.has("skin"): return "skull_" + String(s.skin)
	return String(s.sid)

## the Fire Maiden's gift (Level._maiden_end): native gold where she danced, glowing like embers - a legendary with
## the lava effect, from the first seed past `seed_id` that rolls gold in Old Adit
static func maiden_gold(seed_id: int) -> Dictionary:
	for i in 2000:
		var s := roll(seed_id + i * 7919, 0, 3.0, 5)
		if String(s.sid) != "gold": continue
		s.legend = true
		s.fx = "lava"
		s.value = roundi(float(s.value) + Worth.fx_value("lava") * 1.3 * (1.0 + 5 * 0.25))
		s.tier = tier_of(String(s.sid), int(s.gi), true)
		s.maiden = true
		return s
	return roll(seed_id, 0, 3.0, 5)

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
	# the species' say over the shared traits (SpecLooks.AFFINITY): the loved ones rolled again on their own stream,
	# and none it never takes — nor any its body cannot show (a phantom in gold, a twin on an ammonite)
	var lv := SpecLooks.love(sid)
	if lv.size():
		var lr := Rng32.new((seed_id * 3266489917 + 303) % 4294967296)
		for t: Dictionary in Data.TRAITS:
			if lv.has(t.id):
				if lr.next() < float(t.p) * (float(lv[t.id]) - 1.0) and not t.id in traits and traits.size() < 4:
					traits.append(t.id)
	var nv := SpecLooks.never(sid)
	traits = traits.filter(func(t: String) -> bool: return not t in nv)
	# now and then a layout not the species' own (SpecLooks.odd), its own stream: a little rarity for the collector,
	# and where the generator's lesser-used shapes live on
	if kind in ["crystal", "druse"] and SpecLooks.odd(sid).size() and not "floater" in traits:
		if Rng32.new((seed_id * 2654435761 + 409) % 4294967296).next() < SpecLooks.ATYPICAL_P:
			traits.append("atypical")
	var base_g := 400.0 if kind == "druse" else 900.0 if kind == "geode" else 20.0 if kind == "nugget" else 250.0 if kind == "fossil" else 60.0
	if sid == "pearl": base_g = 30.0   # its oyster, mostly
	var g := roundi(base_g * pow(6.0, rng.next()) * (3.0 if legend else 1.0) * (1.0 + dl * 0.35))
	var kind_m := 1.4 if kind == "druse" else 1.6 if kind == "geode" else 1.0
	# a fossil's own worth (ammolite, a rare form, a pair, opal...): a multiplier, turned into points below
	var fm := 1.0
	if kind == "fossil":
		# a shell nearly all ammolite is worth many plain ones
		var fg := SpecFossil.genes(seed_id, sid, traits)
		fm *= 1.0 + 8.0 * pow(float(fg.get("nacre", 0.0)), 3.0)
		# and blue or violet fire is rarer, so dearer — the more nacre there is to show it
		var fire_m: float = {red = 1.0, green = 1.3, blue = 2.0, violet = 2.6}.get(fg.get("fire", "red"), 1.0)
		fm *= 1.0 + (fire_m - 1.0) * float(fg.get("nacre", 0.0))
		# a matched pair, a brood on one slab, a rare uncoiled form
		if fg.get("pair", false): fm *= 1.6
		fm *= 1.0 + 0.25 * int(fg.get("brood", 0))
		if String(fg.get("hetero", "")) != "": fm *= 3.0
		# wood: opal in it, a crystal heart
		fm *= 1.0 + 6.0 * pow(float(fg.get("opal", 0.0)), 2.0)
		if String(fg.get("heart", "")) != "": fm *= 1.8
		# trilobites: spiny kinds are rare and hard to prepare; pyrite, legs, a moult, a bite, a whole plate
		if sid == "trilobite":
			fm *= {dicranurus = 2.5, walliserops = 3.0, asaphus = 1.8, phacops = 1.2}.get(fg.get("genus", ""), 1.0)
			if int(fg.get("pal", 0)) == 4: fm *= 1.6
			if fg.get("soft", false): fm *= 4.0
			if fg.get("moult", false): fm *= 1.4
			if fg.get("bite", false): fm *= 1.3
			if fg.get("show", "") == "mass": fm *= 1.0 + 0.2 * int(fg.get("mass", 1))
			if fg.get("show", "") == "nodule": fm *= 1.5
			if int(fg.get("pal", 0)) == 6: fm *= 5.0
			fm *= 1.0 + 0.8 * int(fg.get("oysters", 0))
			# and how well it kept
			fm *= 0.4 + 0.8 * float(fg.get("keep", 1.0))
		# fossil leaves: gold or silver film, both halves of the split, a ginkgo
		if sid == "fern":
			fm *= [1.0, 1.9, 1.4, 1.1, 1.0, 1.3, 1.2, 2.4, 2.8][int(fg.get("film", 0))]
			if String(fg.get("crystals", "")) != "": fm *= 1.5
			if fg.get("pair", false): fm *= 1.6
			fm *= {ginkgo = 1.2, palm = 1.4, annularia = 1.1, lepido = 1.1}.get(fg.get("plant", ""), 1.0)
			# a split ironstone nodule; a dragonfly or a fish on the same slab
			if fg.get("show", "") == "nodule": fm *= 1.3
			fm *= {dragonfly = 2.2, fish = 1.8}.get(fg.get("guest", ""), 1.0)
		# pearls: the body (conch and melo are the rarest), roundness, luster, more than one
		if sid == "pearl":
			fm *= {tahitian = 1.5, golden = 1.4, south_sea = 1.3, conch = 3.0, melo = 2.5}.get(fg.get("body", ""), 1.0)
			fm *= {round = 1.3, baroque = 0.8, circled = 0.8}.get(fg.get("shape", ""), 1.0)
			fm *= 0.6 + float(fg.get("luster", 0.5))
			if int(fg.get("count", 1)) > 1: fm *= 1.5
	# the barrow: now and then a skull (see SKULL_AREAS)
	var skull := ""
	if SKULL_AREAS.has(area) and sid in SKULL_SP and not legend:
		var sr := Rng32.new((seed_id * 2654435761 + 7) % 4294967296)
		if sr.next() < float(SKULL_AREAS[area]):
			var at: Array = SKULL_AT[clampi(dl, 0, SKULL_AT.size() - 1)]
			skull = pick_w(at, sr)
			kind = "druse"
			kind_m *= float(SKULL_V[skull])
			traits.erase("atypical")   # (a skull is its own form)
			g = roundi(900.0 * (1.0 + sr.next() * 0.8))
	var beast := ""
	if BEAST_AREAS.has(area) and skull == "" and not legend and not kind in ["nugget", "fossil"]:
		var br := Rng32.new((seed_id * 2246822519 + 13) % 4294967296)
		var ba: Dictionary = BEAST_AREAS[area]
		if br.next() < float(ba.chance):
			beast = pick_w(ba.beasts, br)
			skull = pick_w(BEAST_SKIN, br)
			kind = "druse"
			kind_m *= float(SKULL_V[skull]) * 1.15
			traits.erase("atypical")
			g = roundi(700.0 * (1.0 + br.next() * 1.4))
	# the price is its beauty (Worth): the body by species, squeezed, and every gene's points on top — the same on any
	# body, so a common stone rich in genes outprices a plain rare one. The genes are read as the builder will grow them.
	var go := {seed = seed_id, sid = sid, kind = kind, gi = gi, traits = traits, legend = legend}
	if skull != "":
		go.form = "skull"
		go.skin = skull
		if beast != "": go.beast = beast
	var gene := SpecGenome.of(go)
	var pts := Worth.gene_points(traits, gene) + 2.0 * log(maxf(fm, 1.0))
	var value: float = (Worth.body(sid) * kind_m + Worth.UNIT * pts) * VALUE_K
	# a living effect: its own worth by spectacle, added on any body
	if legend:
		value += Worth.fx_value(String(gene.fx))
	value *= 1.3 * (1.0 + dl * 0.25) * Worth.PRICE
	value = capped(value, area)
	var out := {id = seed_id, sid = sid, kind = kind, gi = gi, traits = traits, legend = legend, g = g, value = roundi(value), tier = tier_of(sid, gi, legend)}
	if skull != "":
		out.form = "skull"
		out.skin = skull
		if beast != "": out.beast = beast
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
