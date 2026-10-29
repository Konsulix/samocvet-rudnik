class_name SpecGenome
extends RefCounted
## The recipe a specimen is grown from. Every find is a mix of a handful of genes:
## the host rock and its colour, the crystal form, the crystal colour and size, and the rare traits
## (silver rims, eaten edges, gold flecks, bubbles, a twin, an anomaly, moss...).
## The genes are read from the find's seed and traits, so the same find always grows the same way,
## and the reveal card can tell the player what they got.

const ROCK_N := {basalt = "basalt", slate = "black slate", ironstone = "ironstone", limestone = "limestone", quartzite = "quartzite"}
const FORM_N := {single = "single crystal", cluster = "cluster", columnar = "columnar", radial = "radial spray", rosette = "rosette",
	floater = "floater", slabs = "slabs", hopper = "hopper cubes", pile = "rubble pile", hexplates = "hex plates",
	geode = "geode", nugget = "nugget", botryoid = "botryoidal", vein = "vein in quartz", petrified_wood = "petrified wood", fulgurite = "fulgurite", flower_quartz = "flower in stone", amber = "amber", trilobite = "trilobite", pearl = "pearl"}
const SIZE_N := ["small", "medium", "large", "giant"]
const ACC_N := {pompom = "fibre puffs", straw = "golden strands", lichen = "lichen", needles = "needles", crust = "crystal crust",
	dust = "hematite dust", inkspots = "dark inclusions", clouds = "colour clouds", fronds = "fern fronds", flowers = "tiny flowers", mushrooms = "mushrooms",
	nacre = "ammolite nacre", sutures = "suture lines", ch_calcite = "honey calcite fill", ch_white = "white calcite fill",
	ch_pyrite = "pyrite fill", ch_agate = "agate fill", ch_ammolite = "ammolite mosaic fill",
	rings = "growth rings", opal = "opal", bark = "bark", checks_quartz = "quartz-healed cracks", checks_opal = "opal-healed cracks",
	checks_empty = "open cracks", heart_amethyst = "amethyst heart", heart_quartz = "quartz heart", heart_citrine = "citrine heart",
	glow_core = "glowing crystal heart", grain = "twisted grain", fungi = "jelly fungus", sand = "fused sand crust", glass = "lightning glass",
	flower = "flower", stone = "clear quartz", gold_dust = "gold dust", insect = "insect", leaves = "leaves", fern = "fern frond", feather = "feather"}

## extra traits the 3D port adds to the prototype's list (looks that change the price)
const EXTRA_TRAITS := [
	{id = "silver", n = "silver rim", p = 0.1, m = 1.35},
	{id = "eroded", n = "etched", p = 0.06, m = 1.3},
	{id = "goldfleck", n = "gold flecks", p = 0.07, m = 1.7},
	{id = "anomaly", n = "anomalous", p = 0.03, m = 2.5},
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
	var fossil := SpecFossil.genes(seed_v, sid, tr, o) if habit == "fossil" else {}
	if habit == "fossil": form = sid
	elif kind == "geode": form = "geode"
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
	elif habit == "fossil" and fossil.has("rock"): rock = fossil.rock
	elif habit == "fossil": rock = "slate" if fossil.get("crushed", false) else Stones.pick_w([["limestone", 4.0], ["slate", 3.0], ["ironstone", 1.5]], rng)
	else: rock = Stones.pick_w([["basalt", 3.0], ["slate", 2.5], ["ironstone", 1.5], ["limestone", 1.5], ["quartzite", 1.0]], rng)
	# lustre: most crystals are glassy; some grow dark and oily, like hematite-coated quartz or tourmaline
	var lustre := "metal" if metal else "fossil" if habit == "fossil" else "glass"
	if not metal and not (form in ["geode", "nugget", "botryoid"]) and rng.next() < 0.2 and habit != "fossil":
		lustre = "dark"
	var dark_cols := [Color(0.012, 0.045, 0.045), Color(0.015, 0.035, 0.02), Color(0.012, 0.018, 0.045), Color(0.04, 0.026, 0.018), Color(0.02, 0.02, 0.022)]
	var dark_col: Color = dark_cols[int(rng.next() * dark_cols.size())]
	if form == "nugget" and rng.next() < 0.7:
		form = "vein"
	# accents: the small things that make it interesting, two or three at most, each with its own colours
	var acc := []
	var apool := [["pompom", 0.8], ["straw", 0.8], ["lichen", 0.9], ["needles", 0.55], ["crust", 0.55], ["dust", 0.35], ["fronds", 0.6], ["flowers", 0.45]]
	if lustre == "glass" and not (form in ["geode", "nugget", "botryoid", "vein"]):
		apool.append_array([["inkspots", 0.9], ["clouds", 1.0]])
	if form in ["geode", "botryoid"]:
		apool = [["pompom", 0.6], ["straw", 0.5]]
	# a fossil without its slab of rock has nowhere for things to grow
	if habit == "fossil" and fossil.get("show", "") != "matrix":
		apool = []
	# a trilobite's slab holds the sea's own life: big puffs and sprays would bury the animal
	if sid == "trilobite":
		apool = apool.filter(func(a: Array) -> bool: return not (a[0] in ["pompom", "straw", "needles"]))
	for k in int(Stones.pick_w([[0, 2.0], [1, 4.0], [2, 3.0], [3, 1.2]], rng)):
		if apool.is_empty(): break
		var a: String = Stones.pick_w(apool, rng)
		if not a in acc: acc.append(a)
	acc.append_array(SpecFossil.accents(fossil))
	var palette := {
		pompom = int(rng.next() * SpecAccents.POMPOM.size()),
		straw = int(rng.next() * SpecAccents.STRAW.size()),
		lichen = int(rng.next() * SpecAccents.LICHEN.size()),
		clouds = int(rng.next() * SpecAccents.CLOUDS.size()),
		moss = int(Stones.pick_w([[0, 4.0], [1, 2.0], [2, 1.0], [3, 1.5], [4, 0.8]], rng)),
		frond = int(Stones.pick_w([[0, 3.0], [1, 2.0], [2, 1.0]], rng)),
		flower = int(rng.next() * SpecAccents.FLOWER.size()),
	}
	# tests and showcases may pin a gene
	form = o.get("form", form)
	lustre = o.get("lustre", lustre)
	# a legendary find always carries one living effect, one that suits its body
	var fx := ""
	if o.get("legend", false):
		var fpool := ["fluor", "levitate", "jellyfish"]
		if not (form in ["floater", "radial", "geode", "botryoid", "vein", "nugget"]): fpool.append("lava")
		if habit == "fossil": fpool = ["dragonfire", "jellyfish"]
		# a fulgurite's own: the lightning that made it runs through it still
		if sid == "fulgurite": fpool = ["discharge", "jellyfish"]
		# a trilobite's pyrite legs walk again; a pearl glows like the moon
		if sid == "trilobite": fpool = ["awaken", "jellyfish"] + (["moon", "moon"] if int(fossil.get("oysters", 0)) > 0 else [])
		if sid == "pearl": fpool = ["moon", "jellyfish"]
		if lustre == "glass" and not (form in ["geode", "botryoid", "vein", "nugget"]):
			fpool.append_array(["heart", "chameleon", "lightning", "starry", "opal", "kintsugi"])
		fx = fpool[int(rng.next() * fpool.size())]
	fx = o.get("fx", fx)
	# mushrooms on the host rock: decided on their own random stream, so adding this gene changed
	# no other gene of any stone that already existed
	var shroom: int = o.get("shroom", SpecFungi.roll(seed_v))
	if shroom >= 0 and not (form in ["floater", "geode", "nugget", "vein", "botryoid"]) and not "mushrooms" in acc \
			and not (habit == "fossil" and fossil.get("show", "") != "matrix"):
		acc.append("mushrooms")
	else:
		shroom = -1
	var size_k := int(Stones.pick_w([[0, 2.0], [1, 4.0], [2, 2.5], [3, 0.6]], rng))
	var anomaly := "anomaly" in tr
	return {
		form = form,
		fossil = fossil,
		lustre = lustre,
		fx = fx,
		fx_v = rng.next(),
		accents = o.get("accents", acc),
		# where moss, lichen and little plants settle: over the rock, or only in its pits and pockets
		nest = o.get("nest", "hollows" if rng.next() < 0.5 else "surface"),
		# a crumbling, spongy host rock
		loose = o.get("loose", 0.45 + rng.next() * 0.55 if rng.next() < 0.28 else 0.0),
		palette = palette,
		shroom = shroom,
		shroom_seed = seed_v,
		dark_col = dark_col,
		rock = rock,
		size = size_k,
		scale = [0.8, 1.0, 1.18, 1.4][size_k],
		silv = 0.8 + rng.next() * 0.5 if "silver" in tr else 0.0,   # native silver along the rock's ridges
		eroded = 0.55 + rng.next() * 0.45 if "eroded" in tr else 0.0,
		gold = "goldfleck" in tr,
		anomaly = anomaly,
		hue = (0.25 + rng.next() * 0.5) * (1.0 if rng.next() < 0.5 else -1.0) if anomaly else 0.0,
		holo = 1.6 if "aurora" in tr else 0.9 if "irid" in tr else 1.0 if anomaly else 0.15 + rng.next() * 0.25,
	}

## the lines for the reveal card: what the find is made of
static func describe(g: Dictionary) -> Array:
	var lus := {glass = "vitreous", dark = "dark, oily", metal = "metallic"}
	var out := [["Form", FORM_N.get(g.form, g.form)], ["Lustre", lus.get(g.lustre, "")], ["Rock", ROCK_N.get(g.rock, g.rock) + (", crumbly" if float(g.loose) > 0.0 else "")], ["Size", SIZE_N[int(g.size)]]]
	if g.fx != "":
		out.push_front(["Legendary effect", SpecLegend.FX_N.get(g.fx, g.fx)])
	if g.accents.size():
		var names := []
		for a in g.accents: names.append(ACC_N.get(a, a))
		out.append(["Growths", ", ".join(names)])
	return out
