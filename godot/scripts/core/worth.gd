class_name Worth
extends RefCounted
## What makes a find dear: beauty, not the species' name (11.11). The species gives the body a price, squeezed (a plain
## emerald is ~5× a plain calcite, not 40×); every gene adds its own points, the same on any body — how rare it is ×
## how much of the stone it changes (tests/gene_audit: chlorite phantom barely shows, an anomalous colour repaints it).
## The life on a stone counts too: moss, mushrooms, butterflies by kind. A legendary effect is worth its spectacle
## (three tiers), not one flat sum. The card's badges are these same points, dearest first (Reveal.stone_card):
## what the player sees named is what they were paid for.

const UNIT := 60.0   # one point, in coins before the depth (≈ a plain amethyst)
## the whole price scaled so a mine's finds earn on average what they did before (tests/worth_sample: the mean over the
## five mines kept), only shared out by beauty
const PRICE := 0.45

## the body: the species' value squeezed — 60 stays 60, 15 → 30, 600 → 190, 2000 → 346
static func body(sid: String) -> float:
	return 60.0 * sqrt(float(Data.SP[sid].v) / 60.0)

## shared traits (Data.TRAITS): rarity × how visible
const TRAIT := {irid = 0.8, aurora = 4.0, zoned = 1.6, phantom = 0.8, chlorite = 0.3, anomaly = 4.0, twin = 1.0, druzy = 0.6,
	bubbles = 0.7, enhydro = 2.2, rutile = 1.3, goldfleck = 1.3, floater = 2.0, scepter = 2.2, eroded = 0.8, silver = 0.9,
	limonite = 0.3, moss = 1.6, coral = 1.5, atypical = 1.6}

## what grows on it or with it (SpecGenome accents)
const ACC := {pompom = 0.6, straw = 0.7, lichen = 0.4, needles = 0.4, crust = 0.5, dust = 0.2, inkspots = 0.4, clouds = 0.8,
	fronds = 0.9, flowers = 1.0, mushrooms = 1.3, trapiche = 4.0, celestine = 0.8, sulphur = 0.6, orpiment = 0.6, rockcrystal = 0.6,
	barite = 0.6, pararealgar = 0.3, mimetite = 0.6,
	# a tourmaline's colours (SpecForms.TOURM): the plain ones little, a neon or a blue cap much; a polished slice
	tm_verdelite = 0.4, tm_rubellite = 0.8, tm_indicolite = 1.0, tm_bicolour = 1.0, tm_watermelon = 1.3, tm_tricolour = 1.7, tm_blue_cap = 1.8,
	tm_paraiba = 3.2, tm_slice = 2.0, ob_black = 0.0, ob_snowflake = 0.9, ob_mahogany = 0.6, ob_rainbow = 2.2, ob_tears = 1.0,
	# a skull's own (its skin is its body: SKULL_V)
	sk_crown = 1.4, sk_eyes = 1.2, sk_fangs = 0.9, sk_stream = 1.8, sk_moss = 1.1, sk_trees = 1.6, sk_roots = 0.6, sk_coins = 1.6,
	sk_diadem = 2.6, sk_maw = 1.6, sk_horn = 1.2, sk_bloom = 1.2, sk_frost = 0.4, sk_wax = 0.4, sk_lantern = 1.2, sk_pile = 1.0,
	sk_broken = -0.4, sk_chipped = -0.2, sk_grave = 0.0, sk_ash = 0.3}

## butterflies by kind (SpecButterfly.KINDS: the commoner meadow ones less, the rare and showy more); each one more of
## a kind +0.3
const FLY := {peacock = 1.0, swallowtail = 1.1, monarch = 1.2, apollo = 1.3, bluetiger = 1.6, hawkmoth = 1.8, birdwing = 2.4,
	glasswing = 2.4}

## a skull's skin is what it is: named by the card's title, but first among its badges
const SKINS := ["sk_gilt", "sk_gold", "sk_silver", "sk_copper", "sk_kintsugi", "sk_glass", "sk_agate", "sk_opal", "sk_pyrite",
	"sk_geode", "sk_nacre", "sk_lapis", "sk_feathers", "sk_sugar", "sk_rhodo"]

## legendary effects by spectacle: 1 a glow on the stone, 2 something alive on it, 3 a scene round it
const FX_TIER := {fluor = 1, levitate = 1, glow = 1, frost = 1, kintsugi = 1, chameleon = 1, candle = 1, watching = 1,
	lava = 2, heart = 2, lightning = 2, starry = 2, opal = 2, spring = 2, moon = 2, borealis = 2, fireflies = 2, discharge = 2,
	awaken = 2, yaga = 2, blossom = 2, starhorn = 2, thunder = 2, foxfire = 2, wolfmoon = 2, breath = 2, raveneye = 2,
	lavaborn = 2, amberdrop = 2,
	jellyfish = 3, dragonfire = 3, hunter = 3, deathless = 3, flutter = 3, phoenix = 3, ghost = 3}
const FX_V := [0.0, 1100.0, 1700.0, 2600.0]

static func fx_value(fx: String) -> float:
	return FX_V[int(FX_TIER.get(fx, 2))]

## a fossil's own genes are priced by Stones.roll's fossil multiplier (ammolite, rare forms, pairs...): turned into
## points there; here only how high they stand among the badges
const FOSSIL_RANK := {nacre = 2.5, hetero = 3.0, pair = 2.0, brood = 1.5, ch_ammolite = 2.5, ch_agate = 1.6, ch_pyrite = 1.4,
	druse_ch = 2.0, pyrite_sh = 1.6, opal = 2.5, glow_core = 2.5, heart_amethyst = 2.0, heart_citrine = 2.0, heart_quartz = 1.6,
	lilies = 1.2, crushed = 0.2, sutures = 0.3, rings = 0.3, bark = 0.2, grain = 0.4, sand = 0.3, glass = 1.0, checks = 0.6,
	sea = 0.8, film = 1.5, plant = 0.8, guest = 2.5, dendrites = 0.8, litter = 0.5, nodule = 1.2, fungi = 1.0}

## a fossil's genes its multiplier does not count (the others are in Stones.roll's fossil block): a fresh lightning
## strike, an insect or flower in amber, a glowing heart in driftwood
const FOSSIL_PTS := {hot = 2.5, froth = 0.6, iron = 0.8, glow_core = 2.5, staple = 0.6, pebble = 0.6, galleries = 0.5,
	foxfire = 2.0, lichen_w = 0.4, insect = 2.2, flower = 2.2, fern = 1.6, feather = 1.6, leaves = 0.6, spangles = 0.6,
	gold_dust = 0.8, lilies = 0.6, guest = 0.0}

## the points a gene adds to the price (0 for what the body or a fossil's own multiplier already counts)
static func points(id: String, gene: Dictionary) -> float:
	if TRAIT.has(id): return float(TRAIT[id])
	if ACC.has(id): return float(ACC[id])
	if id.begins_with("fly_"):
		var k := id.substr(4)
		return float(FLY.get(k, 1.4)) + 0.3 * maxi(0, (gene.get("fly_kinds", []) as Array).count(k) - 1)
	# a pseudomorph; an association, the more for a rarer second species
	if id == "pseudo": return 2.4
	if id == "assoc":
		var mate := String(gene.get("assoc", ""))
		return 1.4 + 0.5 * float((Data.SP.get(mate, {}) as Dictionary).get("r", 0))
	return float(FOSSIL_PTS.get(id, 0.0))

## all the points of a find: its traits and what grew on it
static func gene_points(traits: Array, gene: Dictionary) -> float:
	var p := 0.0
	var lost: Array = gene.get("lost", [])
	for t: String in traits:
		if not t in lost: p += points(t, gene)
	for a: String in gene.get("accents", []):
		if not a in traits: p += points(a, gene)
	return p

## how high a gene stands among the card's badges: the living effect first, a skull's skin, then by points
static func rank(id: String, gene: Dictionary) -> float:
	if id == "fx": return 100.0 + float(FX_TIER.get(String(gene.get("fx", "")), 2))
	if id in SKINS: return 50.0
	if id == "nacre": return 1.0 + 4.0 * float((gene.get("fossil", {}) as Dictionary).get("nacre", 0.0))
	if FOSSIL_RANK.has(id): return float(FOSSIL_RANK[id])
	if FOSSIL_PTS.has(id) and float(FOSSIL_PTS[id]) > 0.0: return float(FOSSIL_PTS[id])
	if id.begins_with("ch_") or id.begins_with("heart_"): return 1.5
	if TRAIT.has(id) or ACC.has(id) or id.begins_with("fly_") or id in ["pseudo", "assoc"]: return points(id, gene)
	return 0.5

## whether a gene earns a badge at all: what the find is (its effect, traits, skin, a fossil's own) always may; the life
## and small things on it only when they are worth something (moss, mushrooms, a butterfly — not a speck of dust)
static func badge(id: String, traits: Array) -> bool:
	if id == "fx" or id in traits or id in SKINS: return true
	if TRAIT.has(id) or ACC.has(id) or id.begins_with("fly_"): return points(id, {}) >= 1.0
	return true
