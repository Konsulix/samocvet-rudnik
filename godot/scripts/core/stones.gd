class_name Stones
extends RefCounted
## Rolling a mineral find: species from the mine's pool, kind, quality, rare traits, weight and price.
## Same formulas and seeds as the prototype.

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
	var luck: float = 1.0 + gi * 0.15 + Save.d.lab * 0.1 + (1.2 if legend else 0.0)
	var out := []
	for t in Data.TRAITS:
		if rng.next() < t.p * luck:
			out.append(t.id)
	return out.slice(0, 4)

static func roll(seed_id: int, area: int, luck: float, dl: int = 0) -> Dictionary:
	var rng := Rng32.new((seed_id * 2246822519) % 4294967296)
	var pool: Dictionary = Data.AREAS[mini(area, Data.AREAS.size() - 1)].pool
	var entries := []
	for s in pool:
		entries.append([s, pool[s] * pow(1.0 + luck * 0.8, Data.SP[s].r)])
	var sid: String = pick_w(entries, rng)
	var kind: String = "nugget" if sid in Data.NUGGETY else "fossil" if Data.HABIT.get(sid, "") == "fossil" else pick_w([["crystal", 5.0], ["druse", 4.0], ["geode", 1.4]], rng)
	var ge := []
	for k in Data.GR.size():
		ge.append([k, Data.GR[k].w * pow(1.0 + luck * 0.5, k * 0.6)])
	var gi: int = pick_w(ge, rng)
	var legend := rng.next() < 0.02 * (1.0 + luck)
	var traits := roll_traits(seed_id, legend, gi)
	var tm := 1.0
	for t in traits:
		tm *= Data.TR[t].m
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
		# pearls: the body (conch and melo are the rarest), roundness, luster, more than one
		if sid == "pearl":
			kind_m *= {tahitian = 1.5, golden = 1.4, south_sea = 1.3, conch = 3.0, melo = 2.5}.get(fg.get("body", ""), 1.0)
			kind_m *= {round = 1.3, baroque = 0.8, circled = 0.8}.get(fg.get("shape", ""), 1.0)
			kind_m *= 0.6 + float(fg.get("luster", 0.5))
			if int(fg.get("count", 1)) > 1: kind_m *= 1.5
	var value := roundi(Data.SP[sid].v * Data.GR[gi].m * tm * (3.0 if legend else 1.0) * kind_m * 1.3 * (1.0 + dl * 0.25))
	return {id = seed_id, sid = sid, kind = kind, gi = gi, traits = traits, legend = legend, g = g, value = value, tier = tier_of(sid, gi, legend)}

static func tier_of(sid: String, gi: int, legend: bool) -> int:
	return mini(4, int(Data.SP[sid].r) + (1 if gi >= 3 else 0) + (1 if legend else 0))

static func fmt_weight(g: int) -> String:
	if g >= 1000:
		return "%.2f kg" % (g / 1000.0)
	return "%d g" % g
