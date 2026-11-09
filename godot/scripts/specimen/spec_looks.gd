class_name SpecLooks
extends RefCounted
## Each species' own look, so a new species feels new (docs/species-looks.md): the layouts it grows in and the kinds
## of find it comes as, its proportions, the rock it likes, how often it rolls the dark lustre, and the one detail it
## always has. Whatever is not set here is as before; the common layer (growths, mushrooms, moss, rare traits,
## legendary effects) still comes to any species. A layout the real mineral never takes is sometimes allowed, so
## nothing the generator can do is lost (hopper cubes on fluorite, hex plates on aquamarine).
##
## forms   [[layout, weight]] for crystal and druse finds (a druse weighs "cluster" up)
## kinds   [[crystal | druse | geode, weight]]
## rock    [[rock, weight]]
## dark    the chance of the dark opaque lustre (5% when not set)
## hk, wk  height and thickness of the crystals; short ones, like amethyst's points, are low hk
## blunt   flat-ended prisms (the beryls), no point
## zone    always zoned: [mode, strength, hue shift] — mode 0 pale base, coloured tip; 1 dark base; 2 two colours
## sig     traits it always has (not named on the card: they are what the species is)
## more    traits it rolls more often: {trait: extra chance}
## core    a cube of another colour inside each crystal (fluorite's phantom cubes), [hex colour, size 0..1]
## palette the species' colours, picked per find on its own stream: [[body hex, core hex, weight], ...] (the core colour
##         replaces core's)
## rose    the rosette as a desert rose: frosted, sand-coloured petals, [hex colour from, hex colour to]
## with    companions: [[blades | crust, hex colour, chance, gene id], ...] — another mineral on the same rock
## opaque  no glass: a waxy or resinous lit surface {rough, coat, grain}
## ir      how much rainbow film / holographic sheen the species takes (1 as before)
## metal_col  a metal species' own colour (hematite's dark steel)
## tarnish the rainbow tarnish over the metal (hematite's iridescent "rainbow hematite"), 0.5 when not set
## rose_metal  the rosette's blades in steel (hematite's iron rose)
## dense   how many crystals a druse packs (x)
## flat_top  its columns end flat or bevelled, never in a point (barite's tablets)
## growths the chance anything of the common layer (growths, mushrooms) grows on it at all
## no_acc  accents it never takes (dark inclusions in sulphur's glass)
## rose_n, rose_s  the rose's blade count and size (x): hematite's are many and small
## stria   the faces' striations [strength, mode]: 0 across the crystal (quartz), 1 along it (the beryls, stibnite), 2 crossed
##         face to face (pyrite); 0 strength — smooth faces
## habits  its crystal by turns, per find: [[habit, weight], ...] (calcite: rhombs, nailheads, dogteeth)
## mica    the rock glitters with mica flakes round the crystals (almandine in its schist)
## glass   {frost: a milky body, 0..1; dark: how dark the glass body is (smoky quartz), tint: how much the body glows in the species' own colour
##         rather than showing the room through it (garnet, azurite), 0..1}

const LOOK := {
	# Old Adit
	quartz = {stria = [1.5, 0.0], forms = [["single", 3.0], ["cluster", 4.0], ["floater", 0.6], ["columnar", 0.8]], kinds = [["crystal", 5.0], ["druse", 4.0], ["geode", 0.4]],
		rock = [["quartzite", 4.0], ["basalt", 1.0], ["slate", 1.0]], hk = 1.25, wk = 0.85, more = {phantom = 0.12}},
	amethyst = {forms = [["cluster", 5.0], ["single", 0.6]], kinds = [["geode", 4.0], ["druse", 4.0], ["crystal", 0.8]],
		rock = [["basalt", 5.0], ["ironstone", 1.0]], hk = 0.4, wk = 1.15, zone = [0, 1.0, 0.0], sig = ["zoned"], more = {scepter = 0.08}},
	smoky = {forms = [["single", 4.0], ["columnar", 3.0], ["cluster", 1.0], ["gwindel", 1.5]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], hk = 1.05, wk = 1.35, dark = 0.3, glass = {dark = 0.7}},
	calcite = {habits = [["rhomb", 3.0], ["nailhead", 2.0], ["scaleno", 1.0]], forms = [["cluster", 5.0], ["single", 2.0], ["pile", 0.6]], kinds = [["druse", 5.0], ["crystal", 3.0]],
		rock = [["limestone", 5.0], ["basalt", 1.0]]},
	fluorite = {stria = [0.0, 0.0], forms = [["cluster", 5.0], ["single", 2.0], ["hopper", 0.7]], kinds = [["druse", 5.0], ["crystal", 3.0]],
		core = [0x5a2e9a, 0.42], palette = [[0x4fae6a, 0x5a2e9a, 4.0], [0x8a5ad0, 0x3a1a6a, 4.0], [0x5aa8d8, 0x2a3a8a, 2.0],
			[0xe0c040, 0x6a3aa0, 2.0], [0xdcdcd8, 0x7a4ab8, 1.5], [0xe8a0b8, 0x9a4a8a, 0.8]], glass = {tint = 0.55}},
	pyrite = {habits = [["cube", 3.0], ["pyritohedron", 2.0]], stria = [1.2, 2.0], forms = [["cluster", 4.0], ["single", 2.0], ["pile", 1.0]], kinds = [["druse", 4.0], ["crystal", 4.0]],
		rock = [["slate", 5.0], ["ironstone", 1.0]]},
	garnet = {mica = true, stria = [0.0, 0.0], forms = [["pile", 4.0], ["single", 2.0], ["cluster", 1.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["slate", 6.0], ["quartzite", 1.0]], dark = 0.0, glass = {tint = 0.65}},
	# Copper Mountain
	azurite = {forms = [["radial", 6.0], ["cluster", 1.0]], kinds = [["crystal", 5.0], ["druse", 2.0]],
		rock = [["ironstone", 3.0], ["limestone", 1.0]], hk = 0.6, wk = 1.1, dark = 0.0, glass = {dark = 0.35, tint = 0.8}},
	beryl = {stria = [1.8, 1.0], forms = [["single", 3.0], ["columnar", 4.0]], kinds = [["crystal", 6.0], ["druse", 1.0]], rock = [["quartzite", 2.0], ["slate", 1.0]],
		blunt = true, wk = 1.2},
	cuprite = {forms = [["pile", 4.0], ["cluster", 3.0]], kinds = [["druse", 4.0], ["crystal", 4.0]], rock = [["ironstone", 4.0], ["basalt", 1.0]], dark = 0.35,
		glass = {tint = 0.6}},
	aquamarine = {stria = [1.5, 1.0], forms = [["single", 4.0], ["columnar", 3.0], ["hexplates", 0.6]], kinds = [["crystal", 6.0], ["druse", 1.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], blunt = true, hk = 1.3, wk = 0.9, dark = 0.0},
	emerald = {stria = [0.8, 1.0], forms = [["single", 5.0], ["columnar", 2.0]], kinds = [["crystal", 6.0], ["druse", 1.0]], rock = [["slate", 6.0]], blunt = true, dark = 0.0},
	# Whalebone Cove
	gypsum = {forms = [["slabs", 3.0], ["rosette", 4.0], ["radial", 1.0], ["single", 1.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["limestone", 3.0], ["slate", 1.0]], hk = 1.3, wk = 0.7, dark = 0.0, rose = [0x7a5a3c, 0xa4865e], more = {twin = 0.12}},
	# Fire Horizon (Sicily's sulphur mines and Etna)
	sulphur = {zone = [0, 0.0, 0.0], foot_frost = false, rock_shape = "slab", forms = [["spray", 1.0]], kinds = [["druse", 7.0], ["crystal", 2.0]],
		rock = [["gypsum", 4.0], ["limestone", 1.0]], dark = 0.0, glass = {tint = 0.7, frost = 0.2, glow = 0.36}, ir = 0.3, hk = 0.85, wk = 1.3,
		dense = 1.9, no_acc = ["inkspots", "clouds"], with = [["blades", 0xa8c8ec, 0.3, "celestine"]]},
	aragonite = {zone = [0, 0.0, 0.0], forms = [["spray", 1.0]], glass = {tint = 0.5, frost = 0.6, glow = 0.2},
		palette = [[0xf2e8d6, 0xf2e8d6, 4.0], [0xeab868, 0xeab868, 3.0], [0xb8a0e0, 0xb8a0e0, 1.2], [0x9ad0c8, 0x9ad0c8, 1.0]],
		kinds = [["druse", 5.0], ["crystal", 3.0]], rock = [["gypsum", 3.0], ["limestone", 1.0]], dark = 0.0, ir = 0.35,
		with = [["crust", 0xf0d020, 0.55, "sulphur"]]},
	realgar = {zone = [0, 0.0, 0.0], foot_frost = false, forms = [["cluster", 1.0]], kinds = [["druse", 1.0]], dense = 0.7,
		rock = [["slate", 3.0], ["lava", 2.0]], hk = 0.7, wk = 1.05, dark = 0.0, glass = {tint = 0.9, dark = 0.2, frost = 0.12, glow = 0.32},
		ir = 0.2, blunt = true, no_acc = ["inkspots", "clouds"], with = [["crust", 0xd8681a, 0.85, "orpiment"]]},
	hematite = {forms = [["rosette", 4.0], ["platestack", 4.0]], kinds = [["crystal", 5.0], ["druse", 2.0]], rock = [["quartzite", 2.0], ["lava", 1.0]],
		rose = [0x1c1612, 0x3a3028], rose_metal = true, rose_n = 2.4, rose_s = 0.6, metal_col = 0x4c5060, tarnish = 0.8,
		with = [["blades", 0xeef2f6, 0.2, "rockcrystal"]]},
	olivine = {zone = [0, 0.0, 0.0], forms = [["xenolith", 1.0]], kinds = [["crystal", 1.0]], rock = [["lava", 1.0]], dark = 0.0,
		glass = {tint = 0.95, frost = 0.05, glow = 0.2}, ir = 0.2},
	obsidian = {kinds = [["crystal", 1.0]]},
	# Proval (Svalbard's coal measures): the vein minerals of the coal and the shale, and agate from the old lavas —
	# shown at their prettiest: glowing honey rhombs, blue and golden barite, mirror galena, fiery ruby jack,
	# blue agate, and the raspberry rhodochrosite as its jewel
	siderite = {zone = [0, 0.0, 0.0], forms = [["cluster", 5.0], ["single", 1.0]], kinds = [["druse", 5.0], ["crystal", 3.0]], rock = [["slate", 4.0], ["ironstone", 2.0]],
		saddle = 1.0, rh = -0.22, wk = 1.3, hk = 1.2, dark = 0.0, opaque = {rough = 0.22, coat = 0.8, grain = 0.04}, ir = 0.25, dense = 1.0,
		palette = [[0x6a3e16, 0x6a3e16, 4.0], [0x8a5820, 0x8a5820, 3.0], [0x46280e, 0x46280e, 1.5]],
		with = [["blades", 0xeef2f6, 0.25, "rockcrystal"]]},
	barite = {zone = [0, 0.0, 0.0], flat_top = true, forms = [["rosette", 1.5], ["cluster", 5.0]], kinds = [["druse", 4.0], ["crystal", 4.0]],
		rock = [["slate", 3.0], ["limestone", 1.0]], hk = 0.6, wk = 1.6, dark = 0.0, glass = {tint = 0.85, frost = 0.08, glow = 0.3}, ir = 0.4,
		rose = [0xa86a30, 0xe8b868], rose_n = 1.4,
		palette = [[0xd89428, 0xd89428, 3.0], [0x5a94e0, 0x5a94e0, 3.0], [0xeae2d2, 0xeae2d2, 1.5], [0xd07040, 0xd07040, 1.0]]},
	galena = {forms = [["cluster", 4.0], ["pile", 2.0], ["single", 1.0]], kinds = [["druse", 4.0], ["crystal", 4.0]], steps = true,
		rock = [["slate", 3.0], ["quartzite", 2.0]], metal_col = 0x8a929e, mrough = 0.22, menv = 2.0, tarnish = 0.1, growths = 0.15,
		with = [["blades", 0xe6d6b4, 0.3, "barite"]]},
	sphalerite = {zone = [0, 0.0, 0.0], forms = [["cluster", 4.0], ["pile", 3.0]], kinds = [["druse", 4.0], ["crystal", 3.0]], rock = [["slate", 4.0], ["limestone", 1.0]],
		wk = 1.3, hk = 1.3, dark = 0.0, glass = {tint = 1.0, dark = 0.7, frost = 0.02, glow = 0.36}, ir = 0.15,
		palette = [[0x8a1404, 0xa81a06, 4.0], [0xc84a0c, 0xc84a0c, 3.0], [0xc08a18, 0xc08a18, 1.5], [0x581206, 0x581206, 1.0]]},
	chalcedony = {kinds = [["geode", 5.0], ["druse", 3.0]], rock = [["basalt", 4.0], ["lava", 1.0]], dark = 0.0, growths = 0.3,
		agate = [0x5a7ab0, 0xa8c4e8, 0xe8eef6, 0x34507e],
		palette = [[0x8ab0e0, 0x8ab0e0, 4.0], [0xb0c8ec, 0xb0c8ec, 2.0], [0x6a88c8, 0x6a88c8, 1.5]]},
	rhodochrosite = {zone = [0, 0.0, 0.0], forms = [["cluster", 4.0], ["sawn", 1.0]], kinds = [["druse", 5.0], ["crystal", 3.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], rh = 0.1, dark = 0.0, glass = {tint = 1.0, dark = 0.2, frost = 0.04, glow = 0.45}, ir = 0.45, dense = 0.8,
		palette = [[0xc81838, 0xc81838, 4.0], [0xe03a58, 0xe03a58, 2.0], [0xa00c2c, 0xa00c2c, 2.0]],
		with = [["blades", 0xeef2f6, 0.45, "rockcrystal"]]},
	# a fossil leaf on its split rock: lichen, moss and mushrooms on the weathered rim, never the big puffs
	fern = {rock = [["slate", 1.0]], growths = 0.8, no_acc = ["pompom", "straw", "needles"]},
	# boulder opal: seams of it in brown ironstone
	opal = {rock = [["ironstone", 5.0], ["basalt", 1.0]], kinds = [["crystal", 5.0], ["geode", 0.6]], growths = 0.4},
	celestine = {forms = [["cluster", 5.0], ["slabs", 1.0]], kinds = [["geode", 4.0], ["druse", 4.0], ["crystal", 1.0]],
		rock = [["limestone", 4.0], ["basalt", 1.0]], hk = 0.75, dark = 0.0},
	# Spider Hollow (an Edo silver mine in a cedar valley, the Tsuchigumo; docs/mine6-tsuchigumo.md §8): "silver and
	# silk" - steel needles and swords of stibnite, silky white needle sprays, peacock brass, the heart-shaped quartz
	# twins of Japan, lead-black silver ore, cinnabar on white rock, jade, and ruby silver as its jewel
	stibnite = {stria = [1.4, 1.0], forms = [["radial", 4.0], ["cluster", 3.0], ["single", 1.0]], kinds = [["druse", 4.0], ["crystal", 5.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], hk = 2.2, wk = 0.35, metal_col = 0x9aa2b0, mrough = 0.16, menv = 2.2, tarnish = 0.35,
		growths = 0.35, with = [["blades", 0xeef2f6, 0.25, "rockcrystal"]]},
	natrolite = {stria = [0.7, 1.0], zone = [0, 0.0, 0.0], forms = [["radial", 5.0], ["cluster", 2.0]], kinds = [["druse", 4.0], ["crystal", 3.0], ["geode", 1.0]],
		rock = [["basalt", 5.0]], hk = 2.6, wk = 0.25, dark = 0.0, glass = {frost = 0.3, tint = 0.15, glow = 0.12}, dense = 1.6, ir = 0.25},
	chalcopyrite = {forms = [["cluster", 4.0], ["pile", 2.0]], kinds = [["druse", 5.0], ["crystal", 3.0]], rock = [["quartzite", 3.0], ["limestone", 1.0]],
		metal_col = 0xc8a23a, mrough = 0.25, menv = 2.0, tarnish = 1.0, with = [["blades", 0xeef2f6, 0.35, "rockcrystal"]]},
	japan_quartz = {forms = [["single", 4.0], ["cluster", 2.0]], kinds = [["crystal", 6.0], ["druse", 2.0]], rock = [["quartzite", 3.0], ["slate", 1.0]],
		hk = 1.0, wk = 1.15, dark = 0.0, sig = ["twin"], glass = {frost = 0.04}},
	acanthite = {forms = [["cluster", 4.0], ["pile", 2.0]], kinds = [["druse", 4.0], ["crystal", 3.0]], rock = [["quartzite", 3.0], ["slate", 1.0]],
		metal_col = 0x5c6068, mrough = 0.3, menv = 1.8, tarnish = 0.25, growths = 0.3, with = [["blades", 0xeef2f6, 0.3, "rockcrystal"]]},
	cinnabar = {zone = [0, 0.0, 0.0], forms = [["cluster", 4.0], ["single", 1.0]], kinds = [["druse", 5.0], ["crystal", 2.0]],
		rock = [["gypsum", 3.0], ["limestone", 3.0]], rh = 0.15, dark = 0.0, glass = {tint = 0.95, dark = 0.25, frost = 0.05, glow = 0.32}, ir = 0.15,
		palette = [[0xc01c14, 0xc01c14, 4.0], [0xa0100c, 0xa0100c, 2.0], [0xd8402a, 0xd8402a, 1.0]]},
	jadeite = {kinds = [["crystal", 1.0]], growths = 0.0, rock = [["slate", 3.0], ["quartzite", 1.0]], dark = 0.0, opaque = {rough = 0.28, coat = 0.9, grain = 0.05},
		palette = [[0x2e8a4e, 0x2e8a4e, 4.0], [0x5aae6e, 0x5aae6e, 2.0], [0x9a86c0, 0x9a86c0, 1.0], [0xd8e4d0, 0xd8e4d0, 1.0]]},
	proustite = {zone = [0, 0.0, 0.0], forms = [["cluster", 3.0], ["single", 2.0]], kinds = [["druse", 3.0], ["crystal", 4.0]],
		rock = [["quartzite", 3.0], ["slate", 1.0]], hk = 1.4, wk = 0.8, dark = 0.0, glass = {tint = 1.0, dark = 0.35, frost = 0.02, glow = 0.45}, ir = 0.3,
		palette = [[0x9a0812, 0x9a0812, 4.0], [0xc0141e, 0xc0141e, 2.0]], with = [["blades", 0xeef2f6, 0.4, "rockcrystal"]]},
	# Koschei's mine (docs/skulls.md): a poison-lime quartz, glowing in its own colour, cloudy
	venom = {zone = [0, 0.0, 0.0], forms = [["cluster", 4.0], ["single", 1.0]], kinds = [["druse", 5.0], ["crystal", 2.0]],
		rock = [["slate", 3.0], ["basalt", 1.0]], dark = 0.0, glass = {tint = 0.85, frost = 0.35, glow = 0.45}, ir = 0.15, hk = 0.8, wk = 1.3,
		palette = [[0x8ee838, 0x8ee838, 4.0], [0xa8f43c, 0xa8f43c, 2.0], [0x6cd034, 0x6cd034, 1.0]]},
	# Deathless Barrow (mine 7, docs/mine7-koschei.md §8): "the bog, the bones and the barrow's gold" - vivianite that grows
	# on buried bones in bogs, black bog-iron, apatite (the mineral bone is made of), black morion (the stone of the dead),
	# blood-red pyrope of Scythian inlays, carnelian beads, and Koschei's needle as its jewel
	vivianite = {stria = [0.9, 1.0], zone = [0, 0.0, 0.0], forms = [["radial", 4.0], ["cluster", 3.0], ["single", 1.0]], kinds = [["druse", 4.0], ["crystal", 4.0]],
		rock = [["ironstone", 3.0], ["slate", 2.0]], hk = 1.8, wk = 0.5, dark = 0.0, glass = {tint = 0.9, dark = 0.45, glow = 0.15}, ir = 0.15,
		palette = [[0x15505a, 0x15505a, 4.0], [0x1f5e46, 0x1f5e46, 2.0], [0x16365e, 0x16365e, 1.0]]},
	goethite = {kinds = [["crystal", 1.0]], rock = [["ironstone", 4.0], ["slate", 1.0]], dark = 0.0, opaque = {rough = 0.1, coat = 1.0, grain = 0.02},
		palette = [[0x2a1c14, 0x2a1c14, 4.0], [0x4a2a16, 0x4a2a16, 2.0], [0x161210, 0x161210, 1.0]]},
	apatite = {zone = [0, 0.0, 0.0], forms = [["single", 3.0], ["cluster", 3.0]], kinds = [["crystal", 5.0], ["druse", 3.0]], blunt = true,
		rock = [["limestone", 3.0], ["slate", 1.0]], hk = 0.9, wk = 1.1, dark = 0.0, glass = {tint = 0.6, glow = 0.2},
		palette = [[0x9ac86a, 0x9ac86a, 4.0], [0x3a8ab0, 0x3a8ab0, 2.0], [0xd8c040, 0xd8c040, 1.5], [0x7a5ab0, 0x7a5ab0, 0.7]]},
	morion = {forms = [["single", 4.0], ["columnar", 3.0], ["cluster", 2.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["slate", 3.0], ["basalt", 1.0]], hk = 1.1, wk = 1.3, dark = 0.4, glass = {dark = 0.95}, ir = 0.08},
	pyrope = {habits = [["grain", 3.0], ["dodeca", 1.0]], stria = [0.0, 0.0], zone = [0, 0.0, 0.0], ir = 0.15, forms = [["pile", 4.0], ["single", 2.0], ["cluster", 1.0]], kinds = [["crystal", 6.0], ["druse", 2.0]],
		rock = [["slate", 4.0], ["basalt", 2.0]], dark = 0.0, glass = {tint = 0.9, dark = 0.3, glow = 0.3},
		palette = [[0x8e0c18, 0x8e0c18, 4.0], [0xa8121c, 0xa8121c, 2.0]]},
	carnelian = {kinds = [["crystal", 1.0]], growths = 0.0, rock = [["limestone", 2.0], ["slate", 1.0]], dark = 0.0, opaque = {rough = 0.18, coat = 0.95, grain = 0.04},
		palette = [[0xc8502a, 0xc8502a, 4.0], [0xa83a1e, 0xa83a1e, 2.0], [0xe07a3a, 0xe07a3a, 1.0]]},
	needle = {zone = [0, 0.0, 0.0], forms = [["single", 5.0]], kinds = [["crystal", 6.0], ["druse", 1.0]],
		rock = [["slate", 3.0], ["ironstone", 1.0]], hk = 2.4, wk = 0.42, dark = 0.0, glass = {tint = 0.75, frost = 0.15, glow = 0.85}, ir = 0.3,
		palette = [[0x9fd0ff, 0x9fd0ff, 4.0], [0xffd88a, 0xffd88a, 1.0]]},
	# Whispering Seam (mine 8, docs/mine8-shubin.md §5): "coal under the chalk, and the breath of the earth" - black flint out
	# of the chalk, honey dogtooth spar of the chalk caves, brassy marcasite of the coal seams, green wavellite balls,
	# hyalite (glassy opal, it glows green), whewellite (a mineral born in coal), enhydro quartz with water and gas sealed
	# in it, and Shubin's ember - the colour of a firedamp flame - as its jewel
	flintstone = {kinds = [["crystal", 1.0]], growths = 0.0, rock = [["limestone", 4.0], ["slate", 1.0]], dark = 0.0, opaque = {rough = 0.1, coat = 0.95, grain = 0.03},
		palette = [[0x1c1c22, 0x1c1c22, 4.0], [0x2e2c30, 0x2e2c30, 2.0], [0x3c342c, 0x3c342c, 1.0]]},
	dogtooth = {zone = [0, 0.0, 0.0], forms = [["cluster", 5.0], ["single", 1.0]], kinds = [["druse", 5.0], ["crystal", 3.0], ["geode", 1.0]],
		rock = [["limestone", 4.0]], dark = 0.0, glass = {tint = 0.5, glow = 0.15}, ir = 0.2,
		palette = [[0xd8a050, 0xd8a050, 4.0], [0xf0d090, 0xf0d090, 2.0], [0xf4f0e8, 0xf4f0e8, 1.0]]},
	marcasite = {forms = [["cluster", 5.0], ["radial", 2.0]], kinds = [["druse", 5.0], ["crystal", 3.0]], rock = [["slate", 3.0], ["limestone", 1.0]],
		dark = 0.0, metal_col = 0xb8a870, tarnish = 0.4, hk = 0.8, wk = 1.2},
	wavellite = {zone = [0, 0.0, 0.0], forms = [["radial", 6.0], ["cluster", 1.0]], kinds = [["druse", 5.0], ["crystal", 2.0]],
		rock = [["slate", 3.0], ["limestone", 1.0]], hk = 1.6, wk = 0.4, dark = 0.0, glass = {tint = 0.6, frost = 0.3, glow = 0.2}, ir = 0.15,
		palette = [[0xa8d870, 0xa8d870, 4.0], [0xd0e890, 0xd0e890, 2.0], [0x70b860, 0x70b860, 1.0]]},
	hyalite = {kinds = [["crystal", 1.0]], rock = [["basalt", 2.0], ["slate", 1.0]], dark = 0.0, glass = {tint = 0.5, frost = 0.1, glow = 0.55}, ir = 0.3,
		palette = [[0xd8f8c8, 0xd8f8c8, 4.0], [0xb8f0b0, 0xb8f0b0, 2.0]]},
	whewellite = {zone = [0, 0.0, 0.0], forms = [["cluster", 3.0], ["single", 3.0]], kinds = [["crystal", 5.0], ["druse", 3.0]],
		rock = [["slate", 4.0]], hk = 0.9, wk = 1.2, dark = 0.0, glass = {frost = 0.4}, ir = 0.2,
		palette = [[0xf4f0e6, 0xf4f0e6, 4.0], [0xe8dcc0, 0xe8dcc0, 2.0]]},
	enhydro = {forms = [["single", 4.0], ["floater", 2.0], ["cluster", 1.0]], kinds = [["crystal", 6.0], ["druse", 1.0]],
		rock = [["quartzite", 2.0], ["slate", 1.0]], hk = 1.3, wk = 0.9, dark = 0.0, glass = {frost = 0.12}, more = {phantom = 0.3}},
	ember = {zone = [0, 0.0, 0.0], forms = [["single", 4.0], ["cluster", 2.0]], kinds = [["crystal", 6.0], ["druse", 1.0]],
		rock = [["slate", 3.0]], hk = 1.5, wk = 0.7, dark = 0.0, glass = {tint = 0.8, frost = 0.1, glow = 0.9}, ir = 0.25,
		palette = [[0x6fe8d0, 0x6fe8d0, 4.0], [0x5ab8ff, 0x5ab8ff, 1.5]]},
}

## the species' say over the shared genes (docs/species-genes.md §4): `love` — {gene id: ×chance}, a rare trait
## (TRAITS) rolled again on its own stream, an accent (ACC) weighted up; `never` — never on this species. Gene ids are
## the traits' (irid, phantom, rutile…) and the accents' (pompom, crust, mushrooms…). What a body cannot show at all
## (a phantom in metal, a twin on a fossil) is ruled out by `never()` itself.
const AFFINITY := {
	quartz = {love = {phantom = 2.0, rutile = 3.0, scepter = 3.0, floater = 3.0, enhydro = 3.0}, never = ["coral", "pompom"]},
	calcite = {love = {zoned = 3.0, phantom = 3.0, enhydro = 2.0}, never = ["rutile", "scepter"]},
	pyrite = {love = {irid = 4.0}, never = ["bubbles", "floater"]},
	fluorite = {love = {twin = 3.0, druzy = 3.0, enhydro = 3.0}, never = ["rutile", "scepter"]},
	amethyst = {love = {scepter = 3.0, phantom = 3.0, dust = 4.0}, never = ["irid", "coral"]},
	smoky = {love = {rutile = 4.0, phantom = 2.0, enhydro = 3.0}, never = ["coral", "moss"]},
	garnet = {love = {eroded = 4.0, silver = 3.0}, never = ["floater", "phantom", "bubbles", "coral", "scepter"]},
	gold = {love = {crust = 3.0}},
	malachite = {love = {crust = 3.0}, never = ["irid", "bubbles", "clouds"]},
	azurite = {love = {druzy = 3.0}, never = ["phantom", "rutile", "floater", "moss"]},
	chrysocolla = {love = {crust = 3.0}},
	nativecu = {love = {crust = 3.0, eroded = 3.0}},
	beryl = {love = {eroded = 5.0, phantom = 3.0}, never = ["coral", "moss", "pompom"]},
	cuprite = {love = {crust = 4.0}, never = ["phantom", "rutile", "floater", "bubbles"]},
	aquamarine = {love = {floater = 4.0}, never = ["moss", "coral", "pompom"]},
	emerald = {love = {inkspots = 3.0, clouds = 3.0, crust = 3.0}, never = ["irid", "bubbles", "floater", "pompom", "straw"]},
	gypsum = {love = {inkspots = 3.0, bubbles = 3.0, enhydro = 3.0}, never = ["rutile", "irid"]},
	celestine = {love = {druzy = 3.0, zoned = 3.0}, never = ["rutile", "moss"]},
	opal = {never = ["bubbles", "pompom", "straw", "needles"]},
	sulphur = {love = {bubbles = 3.0}, never = ["moss", "mushrooms", "lichen", "fronds", "flowers"]},
	aragonite = {never = ["rutile", "phantom"]},
	olivine = {never = ["moss", "mushrooms", "coral", "rutile", "phantom"]},
	realgar = {never = ["moss", "lichen", "rutile"]},
	hematite = {love = {irid = 3.0}, never = ["moss"]},
	siderite = {love = {irid = 3.0}, never = ["phantom", "rutile", "floater"]},
	barite = {love = {zoned = 3.0}, never = ["rutile", "scepter"]},
	galena = {never = ["irid"]},
	sphalerite = {never = ["rutile", "moss"]},
	chalcedony = {never = ["rutile", "scepter", "twin"]},
	rhodochrosite = {never = ["rutile", "moss"]},
	stibnite = {never = ["moss"]},
	natrolite = {love = {druzy = 3.0}, never = ["rutile", "scepter", "phantom"]},
	japan_quartz = {love = {enhydro = 2.0}, never = ["coral", "floater"]},
	cinnabar = {love = {crust = 3.0, twin = 4.0}, never = ["moss", "rutile"]},
	proustite = {never = ["rutile", "moss"]},
	vivianite = {love = {mushrooms = 3.0, moss = 3.0}, never = ["rutile"]},
	goethite = {love = {irid = 4.0}},
	apatite = {love = {zoned = 3.0}, never = ["rutile"]},
	morion = {love = {phantom = 3.0}, never = ["irid", "coral"]},
	pyrope = {never = ["twin", "scepter", "floater"]},
	venom = {love = {clouds = 3.0}, never = ["irid"]},
	# Koschei's needle stands alone: nothing of the shared layer on it, only its own glow
	needle = {never = ["pompom", "straw", "lichen", "needles", "crust", "dust", "fronds", "flowers", "mushrooms", "inkspots", "clouds",
		"moss", "coral", "twin", "druzy", "bubbles", "rutile", "phantom"]},
	dogtooth = {love = {zoned = 3.0}, never = ["rutile"]},
	marcasite = {love = {irid = 3.0}},
	wavellite = {love = {druzy = 3.0}, never = ["rutile"]},
	hyalite = {never = ["rutile"]},
	whewellite = {love = {twin = 3.0}, never = ["rutile"]},
	ember = {never = ["irid"]},
}

## the traits that live in clear glass, and those that need crystals grown out of a rock
const IN_GLASS := ["phantom", "rutile", "inkspots", "clouds", "enhydro"]
const ON_CRYSTALS := ["phantom", "rutile", "scepter", "twin", "floater", "zoned", "eroded", "moss", "coral", "druzy", "enhydro"]
## what a fossil's own builder reads of the shared traits (ammolite, pyrite trilobites, gold in amber, bubbles on rock)
const FOSSIL_KEEPS := ["irid", "aurora", "goldfleck", "bubbles"]

static func of(sid: String) -> Dictionary:
	return LOOK.get(sid, {})

static func love(sid: String) -> Dictionary:
	return AFFINITY.get(sid, {}).get("love", {})

## every shared gene this species never takes: its own word, its old no_acc, and what its body cannot show
static func never(sid: String) -> Array:
	var look := of(sid)
	var out: Array = (AFFINITY.get(sid, {}).get("never", []) as Array).duplicate()
	out.append_array(look.get("no_acc", []))
	var habit: String = Data.HABIT.get(sid, "prism")
	if habit in ["fossil", "obsidian"]:
		for t: Dictionary in Data.TRAITS:
			if not t.id in FOSSIL_KEEPS: out.append(t.id)
	elif habit in ["botryoid", "nugget"]:
		out.append_array(ON_CRYSTALS)
	elif sid in ["pyrite", "hematite", "galena"] or look.has("metal_col"):
		out.append_array(IN_GLASS)
	elif look.has("opaque"):
		out.append_array(IN_GLASS)
	return out

## "atypical habit" (docs/species-genes.md §7.2): now and then a species grows a layout not its own — from the rest
## of what the generator can do, so nothing it does is lost (hex plates, plate stacks, the barrel, hopper cubes).
## (hex plates and plate stacks only where they suit: flat-on, on a prism of quartz, they read as a blank hexagon.)
## The body stays the species' (metal, colour, glass); a find's form, and sometimes its crystal ([layout, weight, habit]).
const ATYPICAL_P := 0.06
const ODD := {
	quartz = [["radial", 2.0], ["slabs", 1.0], ["pile", 1.0]],
	beryl = [["single", 2.0, "barrel"], ["hexplates", 1.5], ["pile", 1.0]],
	apatite = [["single", 2.0, "barrel"], ["columnar", 1.0, "barrel"], ["hexplates", 1.0]],
	barite = [["platestack", 2.0], ["slabs", 1.0], ["hexplates", 1.0]],
	fluorite = [["single", 1.0, "octa"], ["pile", 1.0, "octa"], ["columnar", 0.5]],
	sulphur = [["single", 2.0], ["pile", 1.0]],
	aragonite = [["radial", 2.0], ["columnar", 1.0]],
	hematite = [["hexplates", 2.0], ["slabs", 1.0]],
	celestine = [["rosette", 1.5], ["radial", 1.0]],
	gypsum = [["pile", 1.0], ["columnar", 1.0]],
	olivine = [], needle = [],
}
const ODD_BY_HABIT := {
	prism = [["radial", 1.0], ["slabs", 1.0], ["floater", 0.7], ["columnar", 1.0], ["pile", 0.7]],
	blade = [["slabs", 1.0], ["rosette", 1.0], ["radial", 1.0]],
	scaleno = [["pile", 1.0], ["columnar", 1.0], ["slabs", 0.7], ["radial", 0.7]],
	cube = [["hopper", 1.0], ["pile", 1.0], ["columnar", 1.0]],
	rhomb = [["single", 1.0], ["pile", 1.0], ["columnar", 0.7]],
	tetra = [["single", 1.0], ["pile", 1.0], ["columnar", 0.7]],
	octa = [["single", 1.0], ["pile", 1.0], ["columnar", 0.7]],
	dodeca = [["single", 1.0], ["pile", 1.0], ["cluster", 1.0]],
	dipyr = [["single", 1.0], ["pile", 1.0]],
}

## the atypical layouts open to a species: its own list, or what its crystal can take that it does not grow already
static func odd(sid: String) -> Array:
	if ODD.has(sid): return ODD[sid]
	var habit: String = Data.HABIT.get(sid, "prism")
	var look := of(sid)
	var metal := sid in ["pyrite", "hematite", "galena"] or look.has("metal_col")
	var own := {}
	for f: Array in look.get("forms", []): own[f[0]] = true
	var out := []
	for f: Array in ODD_BY_HABIT.get(habit, []):
		if own.has(f[0]): continue
		if metal and f[0] in ["hopper", "floater"]: continue
		out.append(f)
	return out

## the kind of find for a species (Stones.roll): its own weights, or the old ones
static func kinds(sid: String) -> Array:
	return of(sid).get("kinds", [["crystal", 5.0], ["druse", 4.0], ["geode", 1.4]])
