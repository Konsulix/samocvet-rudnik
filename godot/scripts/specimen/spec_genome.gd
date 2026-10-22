class_name SpecGenome
extends RefCounted
## The recipe a specimen is grown from. Every find is a mix of a handful of genes:
## the host rock and its colour, the crystal form, the crystal colour and size, and the rare traits
## (silver rims, eaten edges, gold flecks, bubbles, a twin, an anomaly, moss...).
## The genes are read from the find's seed and traits, so the same find always grows the same way,
## and the reveal card can tell the player what they got.

const ROCK_N := {basalt = "базальт", slate = "чёрный сланец", ironstone = "железняк", limestone = "известняк", quartzite = "кварцит"}
const FORM_N := {single = "одиночный кристалл", cluster = "друза", columnar = "столбчатый", radial = "ёж", rosette = "розетка",
	floater = "плавающий кристалл", slabs = "пластины", hopper = "скелетные кубы", pile = "россыпь глыб", hexplates = "таблички",
	geode = "жеода", nugget = "самородок", botryoid = "натёчный"}
const SIZE_N := ["мелкий", "средний", "крупный", "гигант"]

## extra traits the 3D port adds to the prototype's list (looks that change the price)
const EXTRA_TRAITS := [
	{id = "silver", n = "серебряный кант", p = 0.1, m = 1.35},
	{id = "eroded", n = "изъеденный", p = 0.1, m = 1.3},
	{id = "goldfleck", n = "вкрапления золота", p = 0.07, m = 1.7},
	{id = "anomaly", n = "аномальный", p = 0.03, m = 2.5},
]

static func of(o: Dictionary) -> Dictionary:
	var seed_v: int = maxi(1, int(o.get("seed", 1)))
	var rng := Rng32.new((seed_v * 40503 + 977) % 4294967296)
	var sid: String = o.get("sid", "quartz")
	var habit: String = Data.HABIT.get(sid, "prism")
	var kind: String = o.get("kind", "crystal")
	var tr: Array = o.get("traits", [])
	var metal := habit == "nugget" or sid == "pyrite"
	var elongated := habit in ["prism", "blade", "barrel", "scaleno"]
	var druse := kind == "druse"
	var form := ""
	if kind == "geode": form = "geode"
	elif habit == "nugget": form = "nugget"
	elif habit == "botryoid": form = "botryoid"
	elif "floater" in tr and elongated: form = "floater"
	else:
		var opts := []
		match habit:
			"prism", "barrel":
				opts = [["single", 2.0], ["columnar", 3.0], ["cluster", 5.0 if druse else 1.0], ["slabs", 2.0], ["radial", 1.0 if druse else 0.4],
					["hexplates", 2.0 if habit == "barrel" else 0.6], ["pile", 1.0]]
			"blade":
				opts = [["rosette", 3.0], ["slabs", 3.0], ["cluster", 4.0 if druse else 0.5], ["single", 1.0], ["hexplates", 0.8]]
			"scaleno":
				opts = [["single", 2.0], ["cluster", 4.0 if druse else 0.8], ["columnar", 1.0], ["pile", 2.0], ["slabs", 1.0]]
			"cube":
				if metal: opts = [["cluster", 3.0], ["single", 2.0], ["columnar", 1.0], ["pile", 1.0]]
				else: opts = [["hopper", 3.0], ["cluster", 3.0 if druse else 0.8], ["single", 1.5], ["pile", 2.0]]
			_:
				opts = [["single", 3.0], ["cluster", 4.0 if druse else 1.0], ["pile", 3.0]]
		form = Stones.pick_w(opts, rng)
	if ("moss" in tr or "coral" in tr) and form in ["floater", "radial"]:
		form = "cluster" if druse else "single"
	var rock: String
	if form == "nugget": rock = "quartzite" if rng.next() < 0.6 else "basalt"
	else: rock = Stones.pick_w([["basalt", 3.0], ["slate", 2.5], ["ironstone", 1.5], ["limestone", 1.5], ["quartzite", 1.0]], rng)
	var size_k := int(Stones.pick_w([[0, 2.0], [1, 4.0], [2, 2.5], [3, 0.6]], rng))
	var anomaly := "anomaly" in tr
	return {
		form = form,
		rock = rock,
		size = size_k,
		scale = [0.8, 1.0, 1.18, 1.4][size_k],
		rim = 0.8 + rng.next() * 0.5 if "silver" in tr else 0.0,
		eroded = 0.55 + rng.next() * 0.45 if "eroded" in tr else 0.0,
		gold = "goldfleck" in tr,
		anomaly = anomaly,
		hue = (0.25 + rng.next() * 0.5) * (1.0 if rng.next() < 0.5 else -1.0) if anomaly else 0.0,
		holo = 1.6 if "aurora" in tr else 0.9 if "irid" in tr else 1.0 if anomaly else 0.15 + rng.next() * 0.25,
	}

## the lines for the reveal card: what the find is made of
static func describe(g: Dictionary) -> Array:
	return [["Форма", FORM_N.get(g.form, g.form)], ["Порода", ROCK_N.get(g.rock, g.rock)], ["Размер", SIZE_N[int(g.size)]]]
